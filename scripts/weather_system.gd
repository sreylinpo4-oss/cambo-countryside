extends Node3D
class_name WeatherSystem

enum WeatherState {
	CLEAR = 0,
	OVERCAST = 1,
	MONSOON_RAIN = 2,
	THUNDERSTORM = 3
}

const AudioSynth = preload("res://scripts/audio_synth.gd")

@export var current_weather: WeatherState = WeatherState.CLEAR
@export var auto_change_weather: bool = true
@export var change_interval: float = 180.0 # Change weather every ~3 mins automatically

var weather_timer: float = 0.0
var rain_intensity: float = 0.0 # 0.0 to 1.0 (smooth blend)
var rain_particles: GPUParticles3D
var splash_particles: GPUParticles3D
var lightning_timer: float = 0.0
var next_lightning_time: float = 8.0
var is_flashing: bool = false
var flash_timer: float = 0.0

var dir_light: DirectionalLight3D
var world_env: WorldEnvironment
var original_light_energy: float = 1.35
var original_light_color: Color = Color(1.0, 0.96, 0.88)

var player_node: Node = null

signal weather_changed(new_state: WeatherState, state_name: String)

func _ready() -> void:
	name = "WeatherSystem"
	_create_rain_particles()
	_create_splash_particles()


func setup(p_light: DirectionalLight3D, p_env: WorldEnvironment) -> void:
	dir_light = p_light
	world_env = p_env
	if dir_light:
		original_light_energy = dir_light.light_energy
		original_light_color = dir_light.light_color


func _create_rain_particles() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainStreaks"
	rain_particles.amount = 450
	rain_particles.lifetime = 1.2
	rain_particles.preprocess = 0.5
	rain_particles.speed_scale = 1.2
	rain_particles.explosiveness = 0.0
	rain_particles.randomness = 0.3

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	# Falling fast with wind angle (South-East drift)
	pmat.direction = Vector3(0.18, -1.0, 0.12).normalized()
	pmat.spread = 4.0
	pmat.initial_velocity_min = 22.0
	pmat.initial_velocity_max = 28.0
	pmat.color = Color(0.85, 0.92, 1.0, 0.55)
	rain_particles.process_material = pmat

	# Needle / streak mesh for realistic rain drops
	var drop_mesh := CylinderMesh.new()
	drop_mesh.top_radius = 0.012
	drop_mesh.bottom_radius = 0.012
	drop_mesh.height = 0.65
	drop_mesh.radial_segments = 4

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.92, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mesh.material = mat
	rain_particles.draw_pass_1 = drop_mesh

	rain_particles.emitting = false
	add_child(rain_particles)


func _create_splash_particles() -> void:
	splash_particles = GPUParticles3D.new()
	splash_particles.name = "RainSplashes"
	splash_particles.amount = 180
	splash_particles.lifetime = 0.35
	splash_particles.explosiveness = 0.0
	splash_particles.randomness = 0.5

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(20.0, 0.1, 20.0)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 1.2
	pmat.initial_velocity_max = 2.4
	pmat.gravity = Vector3(0, -9.8, 0)
	pmat.color = Color(0.88, 0.94, 1.0, 0.45)
	splash_particles.process_material = pmat

	var sp_mesh := SphereMesh.new()
	sp_mesh.radius = 0.03
	sp_mesh.height = 0.06
	sp_mesh.radial_segments = 4
	sp_mesh.rings = 3

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.88, 0.94, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp_mesh.material = mat
	splash_particles.draw_pass_1 = sp_mesh

	splash_particles.emitting = false
	add_child(splash_particles)


func _process(delta: float) -> void:
	# Keep rain volume centered around player camera
	if not player_node or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		if not player_node:
			var root = get_tree().current_scene
			if root and root.has_node("player"):
				player_node = root.get_node("player")

	if player_node and is_instance_valid(player_node):
		var target_pos = player_node.global_position
		if rain_particles:
			rain_particles.global_position = Vector3(target_pos.x, target_pos.y + 14.0, target_pos.z)
		if splash_particles:
			splash_particles.global_position = Vector3(target_pos.x, 0.05, target_pos.z)

	# Automatic weather cycle
	if auto_change_weather:
		weather_timer += delta
		if weather_timer >= change_interval:
			weather_timer = 0.0
			_next_random_weather()

	# Target rain intensity based on state
	var target_intensity = 0.0
	match current_weather:
		WeatherState.CLEAR:
			target_intensity = 0.0
		WeatherState.OVERCAST:
			target_intensity = 0.05
		WeatherState.MONSOON_RAIN:
			target_intensity = 0.75
		WeatherState.THUNDERSTORM:
			target_intensity = 1.0

	rain_intensity = move_toward(rain_intensity, target_intensity, delta * 0.45)

	# Update particle emissions
	var is_raining = rain_intensity > 0.15
	if rain_particles:
		rain_particles.emitting = is_raining
		var pmat = rain_particles.process_material as ParticleProcessMaterial
		if pmat:
			pmat.color.a = rain_intensity * 0.65
	if splash_particles:
		splash_particles.emitting = rain_intensity > 0.35

	# Update Audio
	AudioSynth.update_rain(rain_intensity)

	# Lightning & Thunder in Thunderstorm
	if current_weather == WeatherState.THUNDERSTORM:
		_process_thunderstorm(delta)

	# Lightning flash decay
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0.0:
			is_flashing = false
			_reset_lightning_flash()


func _process_thunderstorm(delta: float) -> void:
	lightning_timer += delta
	if lightning_timer >= next_lightning_time:
		lightning_timer = 0.0
		next_lightning_time = randf_range(7.0, 16.0)
		_trigger_lightning()


func _trigger_lightning() -> void:
	is_flashing = true
	flash_timer = randf_range(0.08, 0.18)

	# Intense blue-white sky and light burst
	if dir_light:
		dir_light.light_color = Color(0.9, 0.95, 1.0)
		dir_light.light_energy = 4.2

	# Delayed thunder boom based on distance (0.4s to 1.2s delay)
	var delay = randf_range(0.4, 1.2)
	var tw = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): AudioSynth.play("thunder", 4.0, randf_range(0.92, 1.08)))


func _reset_lightning_flash() -> void:
	if dir_light:
		# Return to stormy dimmed lighting
		dir_light.light_color = Color(0.68, 0.72, 0.82)
		dir_light.light_energy = 0.65


func cycle_weather() -> void:
	var next_val = (int(current_weather) + 1) % 4
	set_weather(WeatherState.values()[next_val])


func set_weather(new_state: WeatherState) -> void:
	current_weather = new_state
	weather_timer = 0.0
	
	var title = ""
	match current_weather:
		WeatherState.CLEAR:
			title = "Clear Countryside Skies (មេឃស្រឡះ)"
			if dir_light:
				dir_light.light_color = original_light_color
				dir_light.light_energy = original_light_energy
		WeatherState.OVERCAST:
			title = "Overcast Monsoon Clouds (មេឃអាប់អួ)"
			if dir_light:
				dir_light.light_color = Color(0.78, 0.80, 0.85)
				dir_light.light_energy = 0.95
		WeatherState.MONSOON_RAIN:
			title = "Tropical Monsoon Rain (ភ្លៀងរដូវវស្សា)"
			if dir_light:
				dir_light.light_color = Color(0.70, 0.74, 0.82)
				dir_light.light_energy = 0.75
		WeatherState.THUNDERSTORM:
			title = "Monsoon Thunderstorm (ផ្គររន្ទះ)"
			if dir_light:
				dir_light.light_color = Color(0.65, 0.70, 0.80)
				dir_light.light_energy = 0.65

	_show_weather_banner(title)
	weather_changed.emit(current_weather, title)


func _next_random_weather() -> void:
	var pool = [WeatherState.CLEAR, WeatherState.OVERCAST, WeatherState.MONSOON_RAIN, WeatherState.THUNDERSTORM]
	pool.shuffle()
	var pick = pool[0]
	if pick == current_weather:
		pick = pool[1]
	set_weather(pick)


func _show_weather_banner(title: String) -> void:
	var root = get_parent()
	if not root:
		return
	var hud = root.get_node_or_null("HUD")
	if not hud:
		return

	var banner = Label.new()
	banner.text = title
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 17)
	banner.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("shadow_offset_x", 1)
	banner.add_theme_constant_override("shadow_offset_y", 1)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_left = 0.25
	banner.anchor_right = 0.75
	banner.anchor_top = 0.08
	hud.add_child(banner)

	var tw = hud.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(banner, "modulate:a", 0.0, 1.2)
	tw.tween_callback(banner.queue_free)
