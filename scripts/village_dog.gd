extends CharacterBody3D
class_name VillageDog

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Village Dog (ឆ្កែស្រុក)
enum State {
	IDLE,
	WANDER,
	FOLLOW,
	SIT,
	CELEBRATE
}

@export var walk_speed: float = 3.2
@export var run_speed: float = 8.5

var current_state: State = State.IDLE
var is_following: bool = false
var state_timer: float = 3.0
var anim_time: float = 0.0

var player_ref: Node = null
var home_position: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO

# Visual Nodes
var visual_root: Node3D
var body_mesh: MeshInstance3D
var head_pivot: Node3D
var tail: Node3D
var leg_fl: Node3D
var leg_fr: Node3D
var leg_bl: Node3D
var leg_br: Node3D

var is_interactable: bool = true
var interact_prompt: String = "Pet or Command Village Dog (លេងជាមួយឆ្កែ) [E]"

func _ready() -> void:
	add_to_group("interactables")
	home_position = global_position
	target_pos = home_position

	_build_dog_model()


func _build_dog_model() -> void:
	visual_root = Node3D.new()
	visual_root.name = "DogVisual"
	add_child(visual_root)

	var coat_mat := StandardMaterial3D.new()
	coat_mat.albedo_color = Color(0.76, 0.48, 0.25) # Caramel tan Cambodian coat
	coat_mat.roughness = 0.85

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.18, 0.15, 0.14) # Black snout & claws

	# 1. Main Body Torso
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.38, 0.38, 0.72)
	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = b_box
	body_mesh.position = Vector3(0, 0.44, 0)
	body_mesh.material_override = coat_mat
	visual_root.add_child(body_mesh)

	# Red traditional collar
	var collar_box := BoxMesh.new()
	collar_box.size = Vector3(0.40, 0.06, 0.40)
	var collar := MeshInstance3D.new()
	collar.mesh = collar_box
	collar.position = Vector3(0, 0.48, 0.30)
	var col_mat := StandardMaterial3D.new()
	col_mat.albedo_color = Color(0.85, 0.20, 0.20)
	collar.material_override = col_mat
	visual_root.add_child(collar)

	# 2. Head Pivot & Head
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.58, 0.36)
	visual_root.add_child(head_pivot)

	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.28, 0.28, 0.32)
	var head := MeshInstance3D.new()
	head.mesh = h_box
	head.position = Vector3(0, 0.14, 0.10)
	head.material_override = coat_mat
	head_pivot.add_child(head)

	# Snout / Muzzle
	var m_box := BoxMesh.new()
	m_box.size = Vector3(0.18, 0.14, 0.22)
	var muzzle := MeshInstance3D.new()
	muzzle.mesh = m_box
	muzzle.position = Vector3(0, 0.10, 0.28)
	muzzle.material_override = dark_mat
	head_pivot.add_child(muzzle)

	# Floppy Ears
	for side in [-1.0, 1.0]:
		var ear_box := BoxMesh.new()
		ear_box.size = Vector3(0.07, 0.16, 0.12)
		var ear := MeshInstance3D.new()
		ear.mesh = ear_box
		ear.position = Vector3(side * 0.16, 0.20, 0.06)
		ear.rotation_degrees.z = side * -20.0
		ear.material_override = coat_mat
		head_pivot.add_child(ear)

	# 3. Wagging Tail
	tail = Node3D.new()
	tail.position = Vector3(0, 0.52, -0.36)
	visual_root.add_child(tail)

	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 0.02
	t_cyl.bottom_radius = 0.04
	t_cyl.height = 0.38
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.mesh = t_cyl
	tail_mesh.position = Vector3(0, 0.15, -0.12)
	tail_mesh.rotation_degrees.x = -45.0
	tail_mesh.material_override = coat_mat
	tail.add_child(tail_mesh)

	# 4. 4 Animated Legs
	leg_fl = _make_leg(Vector3(-0.16, 0.22, 0.24), coat_mat)
	leg_fr = _make_leg(Vector3(0.16, 0.22, 0.24), coat_mat)
	leg_bl = _make_leg(Vector3(-0.16, 0.22, -0.24), coat_mat)
	leg_br = _make_leg(Vector3(0.16, 0.22, -0.24), coat_mat)

	# 5. Collision Shape
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.8, 0.95)
	col.shape = box
	col.position = Vector3(0, 0.45, 0)
	add_child(col)


func _make_leg(pos: Vector3, mat: Material) -> Node3D:
	var leg_root := Node3D.new()
	leg_root.position = pos
	visual_root.add_child(leg_root)

	var l_mesh := CylinderMesh.new()
	l_mesh.top_radius = 0.055
	l_mesh.bottom_radius = 0.045
	l_mesh.height = 0.38
	var inst := MeshInstance3D.new()
	inst.mesh = l_mesh
	inst.position = Vector3(0, -0.10, 0)
	inst.material_override = mat
	leg_root.add_child(inst)

	return leg_root


func interact(player: Node) -> void:
	player_ref = player

	# Check if player has fish or food to feed
	var fed_food = false
	if player.has_method("has_item") and player.has_method("remove_inventory"):
		if player.has_item("fish", 1):
			player.remove_inventory("fish", 1)
			fed_food = true
		elif player.has_item("banana", 1):
			player.remove_inventory("banana", 1)
			fed_food = true

	AudioSynth.play("bark", 1.5, randf_range(0.95, 1.1))

	if fed_food:
		_show_floating_text("+Fed Delicious Food! Best Friends Forever")
		is_following = true
		current_state = State.CELEBRATE
		state_timer = 1.8
		return

	# Otherwise toggle follow / stay
	is_following = not is_following
	if is_following:
		current_state = State.FOLLOW
		_show_floating_text("Following you! (ឆ្កែដើរតាម)")
	else:
		current_state = State.SIT
		state_timer = 10.0
		_show_floating_text("Staying here (ឆ្កែសម្រាកនៅទីនេះ)")


func _physics_process(delta: float) -> void:
	anim_time += delta

	# Tail wagging animation
	if tail:
		var wag_speed = 18.0 if (is_following or current_state == State.CELEBRATE) else 5.0
		tail.rotation.y = sin(anim_time * wag_speed) * 0.45
		tail.rotation.x = sin(anim_time * (wag_speed * 0.5)) * 0.1

	if current_state == State.CELEBRATE:
		state_timer -= delta
		velocity = Vector3.ZERO
		# Happy spin jump
		visual_root.rotation.y += delta * 12.0
		if head_pivot:
			head_pivot.rotation.x = sin(anim_time * 15.0) * 0.3
		if state_timer <= 0.0:
			visual_root.rotation.y = 0.0
			current_state = State.FOLLOW
		move_and_slide()
		return

	if is_following:
		_handle_following(delta)
	else:
		_handle_autonomous(delta)

	move_and_slide()


func _handle_following(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		# Try to find player in tree
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]
		else:
			return

	var p_pos = player_ref.global_position
	var to_player = p_pos - global_position
	to_player.y = 0.0
	var dist = to_player.length()

	# Face towards player
	if dist > 0.4:
		var target_rot = atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 6.0)

	if dist > 2.6:
		var speed = run_speed if dist > 6.0 else walk_speed
		var move_dir = to_player.normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		_animate_legs(delta, speed)
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0, walk_speed * delta * 4.0)
		_reset_legs()


func _handle_autonomous(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_pick_autonomous_state()

	match current_state:
		State.WANDER:
			var to_target = target_pos - global_position
			to_target.y = 0.0
			var dist = to_target.length()
			if dist > 0.5:
				var move_dir = to_target.normalized()
				var target_rot = atan2(-move_dir.x, -move_dir.z)
				rotation.y = lerp_angle(rotation.y, target_rot, delta * 4.0)
				velocity.x = move_dir.x * walk_speed
				velocity.z = move_dir.z * walk_speed
				_animate_legs(delta, walk_speed)
			else:
				current_state = State.IDLE
				state_timer = randf_range(3.0, 6.0)
				_reset_legs()

		State.SIT, State.IDLE:
			velocity.x = 0
			velocity.z = 0
			_reset_legs()
			if head_pivot:
				head_pivot.rotation.x = sin(anim_time * 2.0) * 0.15


func _pick_autonomous_state() -> void:
	var roll = randf()
	if roll < 0.45:
		current_state = State.IDLE
		state_timer = randf_range(3.0, 7.0)
	elif roll < 0.85:
		current_state = State.WANDER
		state_timer = randf_range(4.0, 8.0)
		var angle = randf() * TAU
		var radius = randf_range(2.0, 8.0)
		target_pos = home_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	else:
		current_state = State.SIT
		state_timer = randf_range(5.0, 10.0)
		if randf() < 0.35:
			AudioSynth.play("bark", -3.0, randf_range(0.9, 1.15))


func _animate_legs(delta: float, speed: float) -> void:
	var swing = sin(anim_time * speed * 2.8) * 0.5
	if leg_fl and leg_fr and leg_bl and leg_br:
		leg_fl.rotation.x = swing
		leg_fr.rotation.x = -swing
		leg_bl.rotation.x = -swing
		leg_br.rotation.x = swing


func _reset_legs() -> void:
	if leg_fl: leg_fl.rotation.x = 0.0
	if leg_fr: leg_fr.rotation.x = 0.0
	if leg_bl: leg_bl.rotation.x = 0.0
	if leg_br: leg_br.rotation.x = 0.0


func _show_floating_text(msg: String) -> void:
	var label = Label3D.new()
	label.text = msg
	label.font_size = 30
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.1, 0)
	add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", 1.8, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)
