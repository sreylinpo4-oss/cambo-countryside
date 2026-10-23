extends CharacterBody3D
class_name CambodianCow

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Zebu Cow (គោខ្មែរ)
enum State { GRAZE, WANDER, IDLE }

@export var move_speed: float = 1.6
@export var wander_radius: float = 14.0

var current_state: State = State.GRAZE
var state_timer: float = 3.0
var target_pos: Vector3
var home_pos: Vector3

# Node references for procedural animation
var visual_root: Node3D
var neck_pivot: Node3D
var head_pivot: Node3D
var tail_pivot: Node3D
var leg_fl: Node3D
var leg_fr: Node3D
var leg_bl: Node3D
var leg_br: Node3D
var ear_l: Node3D
var ear_r: Node3D

var walk_time: float = 0.0
var chew_time: float = 0.0
var tail_swish: float = 0.0

# Interaction
var is_interactable: bool = true
var interact_prompt: String = "Pet White Cow (អង្អែលគោ)"

func _ready() -> void:
	add_to_group("interactables")
	home_pos = global_position
	target_pos = home_pos
	
	_build_cow_mesh()
	
	# Solid collision
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.2, 1.6, 2.4)
	col.shape = box
	col.position.y = 1.0
	add_child(col)


func interact(player: Node) -> void:
	# Pet the cow
	AudioSynth.play("moo", -2.0, randf_range(0.95, 1.05))
	current_state = State.IDLE
	state_timer = 4.0
	
	# Happy head tilt
	if head_pivot:
		head_pivot.rotation_degrees.z = 18.0
		
	# Floating heart / happy effect
	_spawn_heart_effect()


func _physics_process(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0.0:
		_pick_new_state()
		
	match current_state:
		State.WANDER:
			_handle_wander(delta)
		State.GRAZE:
			_handle_graze(delta)
		State.IDLE:
			_handle_idle(delta)
			
	_animate_tail_and_ears(delta)


func _pick_new_state() -> void:
	var roll = randf()
	if roll < 0.5:
		current_state = State.GRAZE
		state_timer = randf_range(4.0, 9.0)
	elif roll < 0.85:
		current_state = State.WANDER
		state_timer = randf_range(3.0, 6.0)
		var offset = Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
		target_pos = home_pos + offset
	else:
		current_state = State.IDLE
		state_timer = randf_range(2.0, 5.0)


func _handle_wander(delta: float) -> void:
	var dir = (target_pos - global_position)
	dir.y = 0.0
	
	if dir.length() > 0.8:
		var move_dir = dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		# Smoothly rotate toward movement direction
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 4.0)
		
		# Quadruped walk cycle
		walk_time += delta * 5.0
		leg_fl.rotation_degrees.x = sin(walk_time) * 22.0
		leg_fr.rotation_degrees.x = -sin(walk_time) * 22.0
		leg_bl.rotation_degrees.x = -sin(walk_time) * 20.0
		leg_br.rotation_degrees.x = sin(walk_time) * 20.0
		
		# Head bobbing
		neck_pivot.rotation_degrees.x = lerp(neck_pivot.rotation_degrees.x, -10.0 + sin(walk_time * 2.0) * 4.0, delta * 5.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		current_state = State.GRAZE
		state_timer = randf_range(3.0, 7.0)
		
	move_and_slide()


func _handle_graze(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	
	# Neck bent down towards grass
	neck_pivot.rotation_degrees.x = lerp(neck_pivot.rotation_degrees.x, -38.0, delta * 3.0)
	
	# Chewing cud animation (jaw side-to-side oscillation)
	chew_time += delta * 6.0
	head_pivot.rotation_degrees.y = sin(chew_time) * 6.0
	head_pivot.rotation_degrees.z = cos(chew_time) * 3.0
	
	# Reset legs
	leg_fl.rotation_degrees.x = lerp(leg_fl.rotation_degrees.x, 0.0, delta * 5.0)
	leg_fr.rotation_degrees.x = lerp(leg_fr.rotation_degrees.x, 0.0, delta * 5.0)
	leg_bl.rotation_degrees.x = lerp(leg_bl.rotation_degrees.x, 0.0, delta * 5.0)
	leg_br.rotation_degrees.x = lerp(leg_br.rotation_degrees.x, 0.0, delta * 5.0)


func _handle_idle(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	neck_pivot.rotation_degrees.x = lerp(neck_pivot.rotation_degrees.x, 0.0, delta * 3.0)
	head_pivot.rotation_degrees.y = lerp(head_pivot.rotation_degrees.y, 0.0, delta * 3.0)


func _animate_tail_and_ears(delta: float) -> void:
	tail_swish += delta * 4.0
	if tail_pivot:
		tail_pivot.rotation_degrees.z = sin(tail_swish) * 24.0
		tail_pivot.rotation_degrees.x = 15.0 + sin(tail_swish * 2.0) * 8.0
		
	# Ear twitches
	if ear_l and ear_r:
		ear_l.rotation_degrees.z = -25.0 + sin(tail_swish * 1.5) * 6.0
		ear_r.rotation_degrees.z = 25.0 - sin(tail_swish * 1.5) * 6.0


func _spawn_heart_effect() -> void:
	var label = Label3D.new()
	label.text = "គោខ្មែរ"
	label.font_size = 36
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.3, 0)
	add_child(label)
	
	var tw = create_tween()
	tw.tween_property(label, "position:y", 3.2, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)


func _build_cow_mesh() -> void:
	visual_root = Node3D.new()
	visual_root.name = "CowModel"
	add_child(visual_root)
	
	var mat_coat = StandardMaterial3D.new()
	mat_coat.albedo_color = Color(0.93, 0.91, 0.85) # Cream white
	mat_coat.roughness = 0.85
	
	var mat_muzzle = StandardMaterial3D.new()
	mat_muzzle.albedo_color = Color(0.42, 0.38, 0.34) # Greyish brown muzzle
	mat_muzzle.roughness = 0.9
	
	var mat_horn = StandardMaterial3D.new()
	mat_horn.albedo_color = Color(0.28, 0.24, 0.20) # Dark horn
	
	var mat_rope = StandardMaterial3D.new()
	mat_rope.albedo_color = Color(0.85, 0.22, 0.20) # Khmer red halter rope
	
	# Main Torso
	var torso = MeshInstance3D.new()
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(1.1, 1.15, 1.9)
	torso.mesh = torso_mesh
	torso.material_override = mat_coat
	torso.position = Vector3(0, 1.15, 0)
	visual_root.add_child(torso)
	
	# Thoracic Hump (iconic Khmer Zebu hump)
	var hump = MeshInstance3D.new()
	var hump_mesh = SphereMesh.new()
	hump_mesh.radius = 0.38
	hump_mesh.height = 0.65
	hump.mesh = hump_mesh
	hump.material_override = mat_coat
	hump.position = Vector3(0, 0.65, 0.45)
	torso.add_child(hump)
	
	# Dewlap (loose skin under neck)
	var dewlap = MeshInstance3D.new()
	var dewlap_mesh = BoxMesh.new()
	dewlap_mesh.size = Vector3(0.2, 0.45, 0.7)
	dewlap.mesh = dewlap_mesh
	dewlap.material_override = mat_coat
	dewlap.position = Vector3(0, -0.45, 0.7)
	torso.add_child(dewlap)
	
	# Neck Pivot
	neck_pivot = Node3D.new()
	neck_pivot.position = Vector3(0, 0.35, 0.95)
	torso.add_child(neck_pivot)
	
	var neck_mesh = MeshInstance3D.new()
	var n_mesh = BoxMesh.new()
	n_mesh.size = Vector3(0.55, 0.65, 0.75)
	neck_mesh.mesh = n_mesh
	neck_mesh.material_override = mat_coat
	neck_mesh.position = Vector3(0, 0.2, 0.3)
	neck_pivot.add_child(neck_mesh)
	
	# Red halter collar
	var collar = MeshInstance3D.new()
	var c_mesh = BoxMesh.new()
	c_mesh.size = Vector3(0.6, 0.7, 0.12)
	collar.mesh = c_mesh
	collar.material_override = mat_rope
	collar.position = Vector3(0, 0.2, 0.45)
	neck_pivot.add_child(collar)
	
	# Head Pivot
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.35, 0.65)
	neck_pivot.add_child(head_pivot)
	
	var head_main = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(0.52, 0.52, 0.65)
	head_main.mesh = h_mesh
	head_main.material_override = mat_coat
	head_pivot.add_child(head_main)
	
	# Snout / Muzzle
	var snout = MeshInstance3D.new()
	var s_mesh = BoxMesh.new()
	s_mesh.size = Vector3(0.44, 0.36, 0.45)
	snout.mesh = s_mesh
	snout.material_override = mat_muzzle
	snout.position = Vector3(0, -0.12, 0.45)
	head_pivot.add_child(snout)
	
	# Horns (Curved Upwards)
	for side in [-1.0, 1.0]:
		var horn = MeshInstance3D.new()
		var horn_mesh = CylinderMesh.new()
		horn_mesh.top_radius = 0.04
		horn_mesh.bottom_radius = 0.09
		horn_mesh.height = 0.5
		horn.mesh = horn_mesh
		horn.material_override = mat_horn
		horn.position = Vector3(side * 0.28, 0.38, -0.05)
		horn.rotation_degrees = Vector3(20.0, 0.0, side * -35.0)
		head_pivot.add_child(horn)
		
	# Drooping Ears
	ear_l = Node3D.new()
	ear_l.position = Vector3(-0.28, 0.15, -0.1)
	head_pivot.add_child(ear_l)
	var el_m = MeshInstance3D.new()
	var em = BoxMesh.new()
	em.size = Vector3(0.35, 0.1, 0.16)
	el_m.mesh = em
	el_m.material_override = mat_coat
	el_m.position.x = -0.18
	ear_l.add_child(el_m)
	
	ear_r = Node3D.new()
	ear_r.position = Vector3(0.28, 0.15, -0.1)
	head_pivot.add_child(ear_r)
	var er_m = MeshInstance3D.new()
	er_m.mesh = em
	er_m.material_override = mat_coat
	er_m.position.x = 0.18
	ear_r.add_child(er_m)
	
	# Dark eyes
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.06
		eye_mesh.height = 0.12
		eye.mesh = eye_mesh
		var eye_mat = StandardMaterial3D.new()
		eye_mat.albedo_color = Color(0.1, 0.08, 0.08)
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.28, 0.08, 0.15)
		head_pivot.add_child(eye)
		
	# Tail Pivot
	tail_pivot = Node3D.new()
	tail_pivot.position = Vector3(0, 0.45, -0.95)
	torso.add_child(tail_pivot)
	
	var tail_mesh = MeshInstance3D.new()
	var t_m = CylinderMesh.new()
	t_m.top_radius = 0.03
	t_m.bottom_radius = 0.04
	t_m.height = 0.8
	tail_mesh.mesh = t_m
	tail_mesh.material_override = mat_coat
	tail_mesh.position = Vector3(0, -0.4, 0)
	tail_pivot.add_child(tail_mesh)
	
	var tuft = MeshInstance3D.new()
	var tuft_m = SphereMesh.new()
	tuft_m.radius = 0.09
	tuft_m.height = 0.25
	tuft.mesh = tuft_m
	tuft.material_override = mat_horn
	tuft.position = Vector3(0, -0.8, 0)
	tail_pivot.add_child(tuft)
	
	# 4 Slender Legs
	leg_fl = _make_leg(Vector3(-0.38, 0.65, 0.65), mat_coat, mat_horn)
	leg_fr = _make_leg(Vector3(0.38, 0.65, 0.65), mat_coat, mat_horn)
	leg_bl = _make_leg(Vector3(-0.38, 0.65, -0.65), mat_coat, mat_horn)
	leg_br = _make_leg(Vector3(0.38, 0.65, -0.65), mat_coat, mat_horn)
	
	visual_root.add_child(leg_fl)
	visual_root.add_child(leg_fr)
	visual_root.add_child(leg_bl)
	visual_root.add_child(leg_br)


func _make_leg(pos: Vector3, coat_mat: Material, hoof_mat: Material) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = pos
	
	var leg_mesh = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(0.18, 0.75, 0.18)
	leg_mesh.mesh = lm
	leg_mesh.material_override = coat_mat
	leg_mesh.position = Vector3(0, -0.35, 0)
	pivot.add_child(leg_mesh)
	
	var hoof = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.2, 0.12, 0.22)
	hoof.mesh = hm
	hoof.material_override = hoof_mat
	hoof.position = Vector3(0, -0.72, 0.02)
	pivot.add_child(hoof)
	
	return pivot
