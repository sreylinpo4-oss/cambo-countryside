extends Node3D
class_name CountrysideSmokeFX

# Soft rising smoke particles for traditional countryside hearth
@export var max_puffs: int = 14
@export var spawn_rate: float = 0.35 # seconds between puffs
@export var smoke_color: Color = Color(0.85, 0.83, 0.80, 0.35)

class SmokePuff:
	var mesh_inst: MeshInstance3D
	var age: float = 0.0
	var lifetime: float = 3.8
	var velocity: Vector3 = Vector3.ZERO
	var active: bool = false
	var initial_scale: float = 0.22

var puffs: Array[SmokePuff] = []
var spawn_timer: float = 0.0
var smoke_mat: StandardMaterial3D

func _ready() -> void:
	smoke_mat = StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	smoke_mat.albedo_color = smoke_color
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.roughness = 0.95

	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 7
	sphere.rings = 5

	for i in range(max_puffs):
		var puff = SmokePuff.new()
		var inst = MeshInstance3D.new()
		inst.mesh = sphere
		inst.material_override = smoke_mat.duplicate()
		inst.visible = false
		add_child(inst)
		puff.mesh_inst = inst
		puffs.append(puff)


func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		_spawn_puff()

	for puff in puffs:
		if not puff.active:
			continue
		puff.age += delta
		if puff.age >= puff.lifetime:
			puff.active = false
			puff.mesh_inst.visible = false
			continue

		var progress = puff.age / puff.lifetime
		# Rise and drift sideways softly
		puff.mesh_inst.position += puff.velocity * delta
		# Add gentle wind turbulence
		puff.mesh_inst.position.x += sin(puff.age * 2.0) * 0.12 * delta

		# Expand as smoke cools and disperses
		var cur_scale = puff.initial_scale + progress * 1.6
		puff.mesh_inst.scale = Vector3.ONE * cur_scale

		# Fade out smoothly
		var mat = puff.mesh_inst.material_override as StandardMaterial3D
		if mat:
			var alpha_envelope = sin(progress * PI) * 0.32
			mat.albedo_color.a = alpha_envelope


func _spawn_puff() -> void:
	for puff in puffs:
		if not puff.active:
			puff.active = true
			puff.age = 0.0
			puff.lifetime = randf_range(3.2, 4.4)
			puff.mesh_inst.position = Vector3(
				randf_range(-0.15, 0.15),
				0.0,
				randf_range(-0.15, 0.15)
			)
			puff.initial_scale = randf_range(0.2, 0.3)
			puff.mesh_inst.scale = Vector3.ONE * puff.initial_scale
			puff.velocity = Vector3(
				randf_range(0.1, 0.35),   # gentle east wind drift
				randf_range(0.65, 0.95),  # rising heat
				randf_range(-0.15, 0.15)
			)
			puff.mesh_inst.visible = true
			break
