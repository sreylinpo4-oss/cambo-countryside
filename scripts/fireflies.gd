extends Node3D
class_name CountrysideFireflies

@export var firefly_count: int = 18
@export var radius: float = 8.0
@export var height_range: float = 2.2

class FireflyData:
	var mesh_inst: MeshInstance3D
	var base_pos: Vector3
	var offset_seed: float
	var speed: float
	var light: OmniLight3D = null

var fireflies: Array[FireflyData] = []
var day_night_ref: Node = null
var current_alpha: float = 0.0

func _ready() -> void:
	_create_fireflies()
	# Locate DayNightCycle if present
	var root = get_tree().current_scene
	if root and root.has_node("DayNightController"):
		day_night_ref = root.get_node("DayNightController")


func _create_fireflies() -> void:
	# Shared glowing material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.98, 0.35, 0.0) # Start transparent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.5

	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 6
	sphere.rings = 4

	for i in range(firefly_count):
		var fd = FireflyData.new()
		var inst = MeshInstance3D.new()
		inst.mesh = sphere
		# Unique material duplicate for independent pulsing
		var m_dup = mat.duplicate() as StandardMaterial3D
		inst.material_override = m_dup
		
		var angle = randf() * TAU
		var dist = randf_range(1.0, radius)
		fd.base_pos = Vector3(cos(angle) * dist, randf_range(0.4, height_range), sin(angle) * dist)
		fd.offset_seed = randf() * 100.0
		fd.speed = randf_range(0.6, 1.3)
		inst.position = fd.base_pos
		add_child(inst)
		fd.mesh_inst = inst

		# Add subtle soft light for 2 fireflies in each swarm for ambient night illumination
		if i < 2:
			var light = OmniLight3D.new()
			light.light_color = Color(0.85, 1.0, 0.4)
			light.light_energy = 0.0
			light.omni_range = 3.5
			inst.add_child(light)
			fd.light = light

		fireflies.append(fd)


func _process(delta: float) -> void:
	# Determine target visibility based on time of day
	var target_alpha = 0.0
	if day_night_ref and "time_of_day" in day_night_ref:
		var t = day_night_ref.time_of_day
		# Visible from 17.5h (dusk) to 5.5h (early dawn)
		if t >= 17.5 or t < 5.5:
			if t >= 17.5 and t < 19.5:
				target_alpha = (t - 17.5) / 2.0
			elif t >= 4.5 and t < 5.5:
				target_alpha = 1.0 - (t - 4.5)
			else:
				target_alpha = 1.0
	else:
		# Fallback if no day/night controller
		target_alpha = 0.85

	current_alpha = move_toward(current_alpha, target_alpha, delta * 0.8)
	if current_alpha <= 0.001:
		visible = false
		return
	visible = true

	var time_sec = Time.get_ticks_msec() * 0.001
	for fd in fireflies:
		var t = time_sec * fd.speed + fd.offset_seed
		# Organic 3D figure-8 and drifting trajectory
		var new_x = fd.base_pos.x + sin(t * 0.8) * 1.2 + cos(t * 0.3) * 0.6
		var new_y = fd.base_pos.y + sin(t * 1.4) * 0.45 + cos(t * 0.5) * 0.2
		var new_z = fd.base_pos.z + cos(t * 0.7) * 1.2 + sin(t * 0.4) * 0.6
		fd.mesh_inst.position = Vector3(new_x, maxf(new_y, 0.2), new_z)

		# Pulsing glow effect
		var pulse = (sin(t * 3.5) * 0.5 + 0.5) * current_alpha
		var mat = fd.mesh_inst.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = pulse * 0.95
			mat.emission_energy_multiplier = 1.5 + pulse * 4.0
		if fd.light:
			fd.light.light_energy = pulse * 0.8
