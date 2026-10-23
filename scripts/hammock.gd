extends Node3D
class_name CountrysideHammock

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Village Hammock (អង្រឹង)
var is_occupied: bool = false
var occupant: Node = null

var sway_time: float = 0.0
var hammock_body: Node3D
var rest_point: Node3D

var is_interactable: bool = true
var interact_prompt: String = "Lie in Hammock (គេងអង្រឹង)"

func _ready() -> void:
	add_to_group("interactables")
	_build_hammock_mesh()


func interact(player: Node) -> void:
	if not is_occupied:
		# Enter hammock
		is_occupied = true
		occupant = player
		interact_prompt = "Get Up from Hammock (ក្រោកឈរ)"
		AudioSynth.play("hammock", -2.0)
		if player.has_method("enter_hammock"):
			player.enter_hammock(self, rest_point)
	else:
		# Exit hammock
		dismount()


func dismount() -> void:
	if occupant and occupant.has_method("exit_hammock"):
		occupant.exit_hammock()
	is_occupied = false
	occupant = null
	interact_prompt = "Lie in Hammock (គេងអង្រឹង)"


func _process(delta: float) -> void:
	if is_occupied:
		sway_time += delta * 1.6
		hammock_body.rotation_degrees.z = sin(sway_time) * 12.0
		if int(sway_time * 10) % 35 == 0 and randf() < 0.25:
			AudioSynth.play("hammock", -10.0, randf_range(0.9, 1.1))
	else:
		# Slowly damp down sway
		hammock_body.rotation_degrees.z = lerp(hammock_body.rotation_degrees.z, 0.0, delta * 2.0)


func _build_hammock_mesh() -> void:
	hammock_body = Node3D.new()
	hammock_body.name = "HammockBody"
	hammock_body.position = Vector3(0, 1.3, 0)
	add_child(hammock_body)
	
	rest_point = Node3D.new()
	rest_point.name = "RestPoint"
	rest_point.position = Vector3(0, -0.45, 0)
	hammock_body.add_child(rest_point)
	
	var mat_fabric = StandardMaterial3D.new()
	mat_fabric.albedo_color = Color(0.22, 0.42, 0.65) # Khmer indigo mesh fabric
	mat_fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mat_rope = StandardMaterial3D.new()
	mat_rope.albedo_color = Color(0.72, 0.60, 0.42) # Jute rope
	
	# Curved Hammock Bed (segmented curved trough)
	var seg_count = 9
	var length = 2.4
	for i in range(seg_count):
		var frac = float(i) / (seg_count - 1)
		var z = lerp(-length * 0.5, length * 0.5, frac)
		# Parabolic sag: y is lowest at center
		var sag = -0.55 * (1.0 - (4.0 * (frac - 0.5) * (frac - 0.5)))
		
		var plank = MeshInstance3D.new()
		var p_mesh = BoxMesh.new()
		var width = lerp(0.35, 0.85, 1.0 - absf(frac - 0.5) * 2.0)
		p_mesh.size = Vector3(width, 0.05, length / seg_count * 1.05)
		plank.mesh = p_mesh
		plank.material_override = mat_fabric
		plank.position = Vector3(0, sag, z)
		# Tilt tangent to curve
		var slope = -4.0 * (frac - 0.5) * 0.55
		plank.rotation_degrees.x = rad_to_deg(atan(slope))
		hammock_body.add_child(plank)
		
	# Suspension Ropes at ends
	for side in [-1.0, 1.0]:
		var rope = MeshInstance3D.new()
		var rm = CylinderMesh.new()
		rm.top_radius = 0.02
		rm.bottom_radius = 0.02
		rm.height = 0.6
		rope.mesh = rm
		rope.material_override = mat_rope
		rope.position = Vector3(0, 0.15, side * (length * 0.55))
		rope.rotation_degrees.x = side * -40.0
		hammock_body.add_child(rope)
