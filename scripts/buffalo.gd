extends CharacterBody3D
class_name CambodianWaterBuffalo

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Water Buffalo (ក្របី)
enum State { WALLOW, GRAZE, WANDER, RIDDEN }

@export var move_speed: float = 1.4
@export var ridden_speed: float = 3.2
@export var wander_radius: float = 12.0

var current_state: State = State.WALLOW
var state_timer: float = 5.0
var target_pos: Vector3
var home_pos: Vector3

# Procedural animation nodes
var visual_root: Node3D
var neck_pivot: Node3D
var head_pivot: Node3D
var tail_pivot: Node3D
var leg_fl: Node3D
var leg_fr: Node3D
var leg_bl: Node3D
var leg_br: Node3D
var rider_seat: Node3D

var walk_time: float = 0.0
var ear_swish: float = 0.0
var rider: Node = null

var plow_pivot: Node3D = null
var is_plowing: bool = false
var plow_mud_timer: float = 0.0

# Interaction
var is_interactable: bool = true
var interact_prompt: String = "Ride Buffalo (ជិះក្របី)"

func _ready() -> void:
	add_to_group("interactables")
	home_pos = global_position
	target_pos = home_pos
	
	_build_buffalo_mesh()
	
	# Solid collision
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 1.7, 2.7)
	col.shape = box
	col.position.y = 1.05
	add_child(col)


func interact(player: Node) -> void:
	if rider == null:
		# Mount the buffalo!
		rider = player
		current_state = State.RIDDEN
		interact_prompt = "Dismount [E] | Toggle Rice Plow [F] (ភ្ជួរស្រែ)"
		if player.has_method("mount_buffalo"):
			player.mount_buffalo(self, rider_seat)
		AudioSynth.play("moo", -2.0, 0.82)
	else:
		# Dismount
		dismount()


func dismount() -> void:
	if is_plowing:
		toggle_plow()
	if rider and rider.has_method("dismount_vehicle"):
		rider.dismount_vehicle()
	rider = null
	current_state = State.GRAZE
	state_timer = 5.0
	interact_prompt = "Ride Buffalo (ជិះក្របី)"


func _physics_process(delta: float) -> void:
	if current_state == State.RIDDEN and rider != null:
		_handle_ridden(delta)
	else:
		state_timer -= delta
		if state_timer <= 0.0:
			_pick_new_state()
			
		match current_state:
			State.WANDER:
				_handle_wander(delta)
			State.GRAZE:
				_handle_graze(delta)
			State.WALLOW:
				_handle_wallow(delta)
				
	_animate_tail_and_ears(delta)


func _handle_ridden(delta: float) -> void:
	# Explicit WASD + Arrow Keys
	var forward_input := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		forward_input += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		forward_input -= 1.0

	var steer_input := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		steer_input += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		steer_input -= 1.0

	# Steer whenever turning input is active
	if absf(steer_input) > 0.1:
		rotate_y(steer_input * 2.2 * delta)

	if absf(forward_input) > 0.1:
		var speed = ridden_speed if forward_input > 0 else (ridden_speed * 0.45)
		var forward = -transform.basis.z * forward_input
		velocity.x = forward.x * speed
		velocity.z = forward.z * speed

		walk_time += delta * 6.0
		leg_fl.rotation_degrees.x = sin(walk_time) * 25.0
		leg_fr.rotation_degrees.x = -sin(walk_time) * 25.0
		leg_bl.rotation_degrees.x = -sin(walk_time) * 22.0
		leg_br.rotation_degrees.x = sin(walk_time) * 22.0
		neck_pivot.rotation_degrees.x = sin(walk_time * 2.0) * 5.0

		# Squelch mud if plowing
		if is_plowing:
			plow_mud_timer += delta
			if plow_mud_timer >= 0.42:
				plow_mud_timer = 0.0
				AudioSynth.play("mud", -1.0, randf_range(0.92, 1.15))
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 4.0)
		velocity.z = move_toward(velocity.z, 0, delta * 4.0)
		leg_fl.rotation_degrees.x = lerp(leg_fl.rotation_degrees.x, 0.0, delta * 5.0)
		leg_fr.rotation_degrees.x = lerp(leg_fr.rotation_degrees.x, 0.0, delta * 5.0)
		leg_bl.rotation_degrees.x = lerp(leg_bl.rotation_degrees.x, 0.0, delta * 5.0)
		leg_br.rotation_degrees.x = lerp(leg_br.rotation_degrees.x, 0.0, delta * 5.0)
		
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.RIDDEN and rider != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
			toggle_plow()


func toggle_plow() -> void:
	is_plowing = not is_plowing
	if plow_pivot:
		var tw = create_tween()
		if is_plowing:
			AudioSynth.play("mud", 2.0)
			tw.tween_property(plow_pivot, "rotation_degrees:x", 16.0, 0.3)
			ridden_speed = 2.2 # Heavy pulling in flooded paddy
			_show_toast("Lowered Rice Plow! Plowing the field (ភ្ជួរស្រែ)")
		else:
			tw.tween_property(plow_pivot, "rotation_degrees:x", -15.0, 0.3)
			ridden_speed = 3.2
			_show_toast("Raised Rice Plow")


func _show_toast(msg: String) -> void:
	var label = Label3D.new()
	label.text = msg
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = global_position + Vector3(0, 2.2, 0)
	get_parent().add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.0, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)


func _pick_new_state() -> void:
	var roll = randf()
	if roll < 0.45:
		current_state = State.WALLOW
		state_timer = randf_range(6.0, 12.0)
	elif roll < 0.75:
		current_state = State.GRAZE
		state_timer = randf_range(5.0, 9.0)
	else:
		current_state = State.WANDER
		state_timer = randf_range(4.0, 7.0)
		var offset = Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
		target_pos = home_pos + offset


func _handle_wander(delta: float) -> void:
	var dir = (target_pos - global_position)
	dir.y = 0.0
	
	if dir.length() > 0.8:
		var move_dir = dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 3.5)
		
		walk_time += delta * 4.5
		leg_fl.rotation_degrees.x = sin(walk_time) * 22.0
		leg_fr.rotation_degrees.x = -sin(walk_time) * 22.0
		leg_bl.rotation_degrees.x = -sin(walk_time) * 18.0
		leg_br.rotation_degrees.x = sin(walk_time) * 18.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		current_state = State.WALLOW
		state_timer = randf_range(5.0, 10.0)
		
	move_and_slide()


func _handle_graze(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	neck_pivot.rotation_degrees.x = lerp(neck_pivot.rotation_degrees.x, -32.0, delta * 2.5)


func _handle_wallow(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	neck_pivot.rotation_degrees.x = lerp(neck_pivot.rotation_degrees.x, -12.0 + sin(Time.get_ticks_msec() * 0.002) * 4.0, delta * 2.0)


func _animate_tail_and_ears(delta: float) -> void:
	ear_swish += delta * 3.0
	if tail_pivot:
		tail_pivot.rotation_degrees.z = sin(ear_swish * 1.5) * 20.0
		tail_pivot.rotation_degrees.x = 18.0 + sin(ear_swish * 2.0) * 8.0


func _build_buffalo_mesh() -> void:
	visual_root = Node3D.new()
	visual_root.name = "BuffaloModel"
	add_child(visual_root)
	
	# Materials
	var mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.24, 0.25, 0.27) # Dark slate water buffalo skin
	mat_skin.roughness = 0.92
	
	var mat_mud = StandardMaterial3D.new()
	mat_mud.albedo_color = Color(0.32, 0.28, 0.22) # Dried mud patches
	mat_mud.roughness = 0.95
	
	var mat_horn = StandardMaterial3D.new()
	mat_horn.albedo_color = Color(0.18, 0.17, 0.16) # Black ribbed horns
	mat_horn.roughness = 0.7
	
	var mat_rope = StandardMaterial3D.new()
	mat_rope.albedo_color = Color(0.78, 0.65, 0.42) # Jute nose rope
	
	# Solid Torso
	var torso = MeshInstance3D.new()
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(1.35, 1.3, 2.3)
	torso.mesh = torso_mesh
	torso.material_override = mat_skin
	torso.position = Vector3(0, 1.25, 0)
	visual_root.add_child(torso)
	
	# Mud splash patch on side
	var mud_patch = MeshInstance3D.new()
	var mp_mesh = BoxMesh.new()
	mp_mesh.size = Vector3(1.38, 0.7, 1.2)
	mud_patch.mesh = mp_mesh
	mud_patch.material_override = mat_mud
	mud_patch.position = Vector3(0, -0.15, 0.1)
	torso.add_child(mud_patch)
	
	# Rider seat point (for player to sit atop buffalo)
	rider_seat = Node3D.new()
	rider_seat.name = "RiderSeat"
	rider_seat.position = Vector3(0, 0.85, 0.1)
	torso.add_child(rider_seat)
	
	# Neck Pivot
	neck_pivot = Node3D.new()
	neck_pivot.position = Vector3(0, 0.2, 1.15)
	torso.add_child(neck_pivot)
	
	var neck_mesh = MeshInstance3D.new()
	var nm = BoxMesh.new()
	nm.size = Vector3(0.72, 0.8, 0.85)
	neck_mesh.mesh = nm
	neck_mesh.material_override = mat_skin
	neck_mesh.position = Vector3(0, 0.15, 0.35)
	neck_pivot.add_child(neck_mesh)
	
	# Head Pivot
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.2, 0.75)
	neck_pivot.add_child(head_pivot)
	
	var head_main = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.68, 0.6, 0.75)
	head_main.mesh = hm
	head_main.material_override = mat_skin
	head_pivot.add_child(head_main)
	
	# Broad Snout
	var snout = MeshInstance3D.new()
	var sm = BoxMesh.new()
	sm.size = Vector3(0.58, 0.42, 0.5)
	snout.mesh = sm
	snout.material_override = mat_skin
	snout.position = Vector3(0, -0.14, 0.5)
	head_pivot.add_child(snout)
	
	# Nose Rope Ring
	var nose_rope = MeshInstance3D.new()
	var nrm = TorusMesh.new()
	nrm.inner_radius = 0.08
	nrm.outer_radius = 0.14
	nose_rope.mesh = nrm
	nose_rope.material_override = mat_rope
	nose_rope.position = Vector3(0, -0.22, 0.68)
	nose_rope.rotation_degrees.x = 90.0
	head_pivot.add_child(nose_rope)
	
	# Iconic Swept-Back Crescent Horns
	for side in [-1.0, 1.0]:
		var horn_base = Node3D.new()
		horn_base.position = Vector3(side * 0.35, 0.3, -0.1)
		head_pivot.add_child(horn_base)
		
		# Segment 1: curves out
		var h1 = MeshInstance3D.new()
		var h1_mesh = CylinderMesh.new()
		h1_mesh.top_radius = 0.09
		h1_mesh.bottom_radius = 0.13
		h1_mesh.height = 0.65
		h1.mesh = h1_mesh
		h1.material_override = mat_horn
		h1.position = Vector3(side * 0.32, 0.12, -0.1)
		h1.rotation_degrees = Vector3(15.0, side * 30.0, side * -70.0)
		horn_base.add_child(h1)
		
		# Segment 2: curves back inward
		var h2 = MeshInstance3D.new()
		var h2_mesh = CylinderMesh.new()
		h2_mesh.top_radius = 0.03
		h2_mesh.bottom_radius = 0.09
		h2_mesh.height = 0.55
		h2.mesh = h2_mesh
		h2.material_override = mat_horn
		h2.position = Vector3(side * 0.68, 0.28, -0.42)
		h2.rotation_degrees = Vector3(35.0, side * 75.0, side * -35.0)
		horn_base.add_child(h2)
		
		# Drooping Ears below horns
		var ear = MeshInstance3D.new()
		var em = BoxMesh.new()
		em.size = Vector3(0.4, 0.1, 0.18)
		ear.mesh = em
		ear.material_override = mat_skin
		ear.position = Vector3(side * 0.45, -0.05, -0.15)
		ear.rotation_degrees.z = side * -20.0
		head_pivot.add_child(ear)
		
	# Tail
	tail_pivot = Node3D.new()
	tail_pivot.position = Vector3(0, 0.45, -1.15)
	torso.add_child(tail_pivot)
	var tm = MeshInstance3D.new()
	var t_cyl = CylinderMesh.new()
	t_cyl.top_radius = 0.04
	t_cyl.bottom_radius = 0.05
	t_cyl.height = 0.75
	tm.mesh = t_cyl
	tm.material_override = mat_skin
	tm.position = Vector3(0, -0.38, 0)
	tail_pivot.add_child(tm)

	# Traditional Cambodian Wooden Rice Plow (Angkoal / អង្គល់)
	plow_pivot = Node3D.new()
	plow_pivot.name = "PlowPivot"
	plow_pivot.position = Vector3(0, 0.35, -1.25)
	plow_pivot.rotation_degrees.x = -15.0 # Raised by default
	torso.add_child(plow_pivot)

	var mat_plow_wood := StandardMaterial3D.new()
	mat_plow_wood.albedo_color = Color(0.42, 0.28, 0.16)
	mat_plow_wood.roughness = 0.85

	var mat_iron_blade := StandardMaterial3D.new()
	mat_iron_blade.albedo_color = Color(0.22, 0.22, 0.25)
	mat_iron_blade.roughness = 0.55

	# Long angled beam extending backward
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.12, 0.12, 1.6)
	beam.mesh = beam_mesh
	beam.position = Vector3(0, -0.28, -0.7)
	beam.rotation_degrees.x = -12.0
	beam.material_override = mat_plow_wood
	plow_pivot.add_child(beam)

	# Iron plowshare blade at the bottom
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.35, 0.26, 0.45)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.65, -1.35)
	blade.rotation_degrees.x = 22.0
	blade.material_override = mat_iron_blade
	plow_pivot.add_child(blade)

	# Dual farmer control handles
	for side in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var h_mesh := CylinderMesh.new()
		h_mesh.top_radius = 0.025
		h_mesh.bottom_radius = 0.035
		h_mesh.height = 0.95
		handle.mesh = h_mesh
		handle.position = Vector3(side * 0.25, -0.15, -1.3)
		handle.rotation_degrees = Vector3(28.0, 0, side * 15.0)
		handle.material_override = mat_plow_wood
		plow_pivot.add_child(handle)
	
	# 4 Sturdy Legs
	leg_fl = _make_sturdy_leg(Vector3(-0.48, 0.7, 0.75), mat_skin, mat_horn)
	leg_fr = _make_sturdy_leg(Vector3(0.48, 0.7, 0.75), mat_skin, mat_horn)
	leg_bl = _make_sturdy_leg(Vector3(-0.48, 0.7, -0.75), mat_skin, mat_horn)
	leg_br = _make_sturdy_leg(Vector3(0.48, 0.7, -0.75), mat_skin, mat_horn)
	
	visual_root.add_child(leg_fl)
	visual_root.add_child(leg_fr)
	visual_root.add_child(leg_bl)
	visual_root.add_child(leg_br)


func _make_sturdy_leg(pos: Vector3, skin_mat: Material, hoof_mat: Material) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = pos
	
	var leg_mesh = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(0.24, 0.8, 0.24)
	leg_mesh.mesh = lm
	leg_mesh.material_override = skin_mat
	leg_mesh.position = Vector3(0, -0.38, 0)
	pivot.add_child(leg_mesh)
	
	var hoof = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.26, 0.14, 0.28)
	hoof.mesh = hm
	hoof.material_override = hoof_mat
	hoof.position = Vector3(0, -0.78, 0.02)
	pivot.add_child(hoof)
	
	return pivot
