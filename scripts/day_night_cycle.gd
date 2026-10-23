extends Node
class_name DayNightCycle

const AudioSynth = preload("res://scripts/audio_synth.gd")

@export var time_of_day: float = 9.5 # 0.0 to 24.0 (9:30 AM morning)
@export var day_speed: float = 0.08 # Hours per real-world second (~5 min full day)
@export var is_paused: bool = false

var directional_light: DirectionalLight3D
var world_environment: WorldEnvironment
var house_lanterns: Array[OmniLight3D] = []
var firefly_particles: Array[GPUParticles3D] = []

var current_sky_mat: ProceduralSkyMaterial
var is_night_factor: float = 0.0 # 0.0 = day, 1.0 = night

signal time_changed(time_str: String, is_night: bool)

func setup(p_light: DirectionalLight3D, p_env: WorldEnvironment) -> void:
	directional_light = p_light
	world_environment = p_env
	
	if world_environment and world_environment.environment and world_environment.environment.sky:
		current_sky_mat = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		
	# Create porch lanterns on the house
	_create_house_lanterns()
	
	# Create firefly clusters over paddies and pond
	_create_fireflies()
	
	_update_lighting(0.0)


func _process(delta: float) -> void:
	if not is_paused:
		var old_h = time_of_day
		time_of_day += day_speed * delta
		if time_of_day >= 24.0:
			time_of_day -= 24.0
		_check_pagoda_bell(old_h, time_of_day)
			
	_update_lighting(delta)


func advance_time(hours: float = 4.0) -> void:
	var old_h = time_of_day
	time_of_day = fmod(time_of_day + hours, 24.0)
	_check_pagoda_bell(old_h, time_of_day)
	_update_lighting(0.0)


func _check_pagoda_bell(old_hour: float, new_hour: float) -> void:
	# Check crossing 6.0 AM (Dawn)
	if (old_hour < 6.0 and new_hour >= 6.0) or (old_hour > 20.0 and new_hour >= 6.0 and new_hour < 7.0):
		_ring_pagoda_bell("Dawn Pagoda Bell (ជួងវត្តពេលព្រឹក)")
	# Check crossing 18.0 (6:00 PM Dusk)
	elif (old_hour < 18.0 and new_hour >= 18.0):
		_ring_pagoda_bell("Dusk Pagoda Bell (ជួងវត្តពេលល្ងាច)")


func _ring_pagoda_bell(title: String) -> void:
	AudioSynth.play("pagoda_bell", 2.0, 1.0)
	var parent_world = get_parent()
	if parent_world:
		var hud = parent_world.get_node_or_null("HUD")
		if hud:
			var banner = Label.new()
			banner.text = title
			banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			banner.add_theme_font_size_override("font_size", 18)
			banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
			banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			banner.add_theme_constant_override("shadow_offset_x", 1)
			banner.add_theme_constant_override("shadow_offset_y", 1)
			banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
			banner.anchor_left = 0.3
			banner.anchor_right = 0.7
			banner.anchor_top = 0.12
			hud.add_child(banner)
			
			var tw = hud.create_tween()
			tw.tween_interval(3.5)
			tw.tween_property(banner, "modulate:a", 0.0, 1.2)
			tw.tween_callback(banner.queue_free)


func get_time_string() -> String:
	var hours = int(time_of_day)
	var mins = int(fmod(time_of_day * 60.0, 60.0))
	var period = "AM"
	var display_h = hours
	if display_h >= 12:
		period = "PM"
	if display_h > 12:
		display_h -= 12
	elif display_h == 0:
		display_h = 12
		
	var phase_name = ""
	if time_of_day >= 5.0 and time_of_day < 7.5:
		phase_name = "Sunrise (ព្រឹកព្រហាម)"
	elif time_of_day >= 7.5 and time_of_day < 11.5:
		phase_name = "Morning (ពេលព្រឹក)"
	elif time_of_day >= 11.5 and time_of_day < 14.5:
		phase_name = "Midday (ថ្ងៃត្រង់)"
	elif time_of_day >= 14.5 and time_of_day < 17.5:
		phase_name = "Afternoon (រសៀល)"
	elif time_of_day >= 17.5 and time_of_day < 19.5:
		phase_name = "Golden Dusk (សន្ធ្យា)"
	else:
		phase_name = "Starry Night (ពេលយប់)"
		
	return "%02d:%02d %s | %s" % [display_h, mins, period, phase_name]


func _update_lighting(delta: float) -> void:
	# Calculate sun angle: 0h = midnight (-90 deg), 6h = sunrise (0 deg), 12h = noon (90 deg), 18h = sunset (180 deg)
	var sun_progress = (time_of_day - 6.0) / 24.0
	var sun_pitch = sin(sun_progress * TAU) * 75.0
	var sun_yaw = cos(sun_progress * TAU) * 60.0 - 45.0
	
	if directional_light:
		directional_light.rotation_degrees = Vector3(-sun_pitch, sun_yaw, 0.0)
		
	# Determine day phase factor
	# Daytime is roughly 6:00 to 18:00
	var day_factor: float = 0.0
	if time_of_day >= 5.5 and time_of_day <= 18.5:
		# Midday peak around 12.0
		var dist_from_noon = absf(time_of_day - 12.0)
		day_factor = clampf(1.0 - (dist_from_noon / 6.5), 0.0, 1.0)
	
	is_night_factor = 1.0 - day_factor
	
	# Light colors and sky interpolations
	var light_col: Color
	var light_energy: float
	var sky_top: Color
	var sky_horizon: Color
	var ground_horizon: Color
	
	if time_of_day >= 5.0 and time_of_day < 7.5: # Sunrise
		var t = (time_of_day - 5.0) / 2.5
		light_col = Color(0.98, 0.65, 0.42).lerp(Color(1.0, 0.94, 0.85), t)
		light_energy = lerp(0.5, 1.3, t)
		sky_top = Color(0.12, 0.25, 0.55).lerp(Color(0.22, 0.52, 0.88), t)
		sky_horizon = Color(0.96, 0.58, 0.38).lerp(Color(0.74, 0.84, 0.90), t)
		ground_horizon = Color(0.48, 0.38, 0.24).lerp(Color(0.58, 0.68, 0.48), t)
	elif time_of_day >= 7.5 and time_of_day < 16.5: # Full Day
		light_col = Color(1.0, 0.96, 0.88)
		light_energy = 1.35
		sky_top = Color(0.20, 0.52, 0.90)
		sky_horizon = Color(0.74, 0.84, 0.90)
		ground_horizon = Color(0.58, 0.68, 0.48)
	elif time_of_day >= 16.5 and time_of_day < 19.0: # Sunset / Dusk
		var t = (time_of_day - 16.5) / 2.5
		light_col = Color(1.0, 0.94, 0.85).lerp(Color(0.98, 0.45, 0.22), t)
		light_energy = lerp(1.3, 0.4, t)
		sky_top = Color(0.20, 0.52, 0.90).lerp(Color(0.16, 0.12, 0.35), t)
		sky_horizon = Color(0.74, 0.84, 0.90).lerp(Color(0.95, 0.42, 0.20), t)
		ground_horizon = Color(0.58, 0.68, 0.48).lerp(Color(0.40, 0.30, 0.18), t)
	else: # Night
		light_col = Color(0.45, 0.58, 0.88) # Moon light
		light_energy = 0.32
		sky_top = Color(0.03, 0.04, 0.10)
		sky_horizon = Color(0.08, 0.12, 0.22)
		ground_horizon = Color(0.06, 0.08, 0.14)
		
	if directional_light:
		directional_light.light_color = light_col
		directional_light.light_energy = light_energy
		
	if current_sky_mat:
		current_sky_mat.sky_top_color = sky_top
		current_sky_mat.sky_horizon_color = sky_horizon
		current_sky_mat.ground_horizon_color = ground_horizon
		
	# House lanterns activation
	var lantern_active = is_night_factor > 0.45
	for lantern in house_lanterns:
		lantern.visible = lantern_active
		if lantern_active:
			# Gentle kerosene flame flicker
			lantern.light_energy = 1.4 + randf_range(-0.12, 0.12)
			
	# Fireflies activation
	for firefly in firefly_particles:
		firefly.emitting = is_night_factor > 0.4
		
	# Update Audio Ambience crossfade
	AudioSynth.update_ambience(is_night_factor)
	
	emit_signal("time_changed", get_time_string(), is_night_factor > 0.5)


func _create_house_lanterns() -> void:
	# Add warm kerosene lanterns at the stilt house veranda and resting platform
	var positions = [
		Vector3(-20.0, 3.6, 5.0),   # Veranda entrance
		Vector3(-18.5, 3.6, 7.5),   # Veranda corner
		Vector3(-20.0, 1.8, 5.0)    # Under-house krea resting platform
	]
	
	for pos in positions:
		var lantern = OmniLight3D.new()
		lantern.position = pos
		lantern.light_color = Color(1.0, 0.72, 0.38) # Warm golden kerosene glow
		lantern.light_energy = 1.5
		lantern.omni_range = 8.5
		lantern.omni_attenuation = 1.2
		lantern.shadow_enabled = true
		lantern.visible = false
		get_parent().add_child(lantern)
		house_lanterns.append(lantern)
		
		# Add a visual lantern mesh hanging there
		var lantern_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.22, 0.35, 0.22)
		lantern_mesh.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.6, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.3)
		mat.emission_energy_multiplier = 2.0
		lantern_mesh.material_override = mat
		lantern.add_child(lantern_mesh)


func _create_fireflies() -> void:
	# Firefly clusters over east rice paddy, south rice paddy, and lotus pond
	var cluster_positions = [
		Vector3(26.0, 1.2, 10.0),   # East paddy
		Vector3(24.0, 1.2, -26.0),  # South paddy
		Vector3(-25.0, 0.9, -18.0)  # Lotus pond
	]
	
	for center in cluster_positions:
		var particles = GPUParticles3D.new()
		particles.position = center
		particles.amount = 35
		particles.lifetime = 4.5
		particles.explosiveness = 0.0
		particles.randomness = 0.8
		
		var pmat = ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pmat.emission_box_extents = Vector3(12.0, 1.5, 12.0)
		pmat.gravity = Vector3(0.0, 0.15, 0.0) # Slowly drift upward
		pmat.direction = Vector3(0, 1, 0)
		pmat.initial_velocity_min = 0.2
		pmat.initial_velocity_max = 0.6
		pmat.color = Color(0.85, 1.0, 0.35, 0.95) # Glowing chartreuse / firefly gold-green
		particles.process_material = pmat
		
		var draw_pass = SphereMesh.new()
		draw_pass.radius = 0.06
		draw_pass.height = 0.12
		var s_mat = StandardMaterial3D.new()
		s_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(0.9, 1.0, 0.4)
		draw_pass.material = s_mat
		particles.draw_pass_1 = draw_pass
		
		particles.emitting = false
		get_parent().add_child(particles)
		firefly_particles.append(particles)
