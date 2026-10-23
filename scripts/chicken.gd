extends CharacterBody3D
class_name VillageChicken

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Village Chickens (មាន់ស្រុក)
enum State { PECK, WALK, SCATTER }

@export var move_speed: float = 1.8
@export var wander_radius: float = 8.0

var current_state: State = State.PECK
var state_timer: float = 3.0
var home_pos: Vector3
var target_pos: Vector3

var head_pivot: Node3D
var wing_l: Node3D
var wing_r: Node3D
var visual_root: Node3D
var chicks: Array[Node3D] = []

var peck_anim: float = 0.0
var walk_anim: float = 0.0

var is_interactable: bool = true
var interact_prompt: String = "Feed Chickens (ឲ្យចំណីមាន់)"

func _ready() -> void:
	add_to_group("interactables")
	home_pos = global_position
	target_pos = home_pos
	
	_build_chicken_model()
	_spawn_chicks()


func interact(player: Node) -> void:
	# Feed chickens
	AudioSynth.play("cluck", -3.0, 1.2)
	current_state = State.PECK
	state_timer = 6.0
	
	# Spawn feeding label
	var label = Label3D.new()
	label.text = "🌾 +Feeding Rice!"
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.8, 0)
	add_child(label)
	
	var tw = create_tween()
	tw.tween_property(label, "position:y", 1.5, 1.0)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tw.tween_callback(label.queue_free)


func _physics_process(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_pick_state()
		
	match current_state:
		State.WALK:
			_handle_walk(delta)
		State.PECK:
			_handle_peck(delta)
		State.SCATTER:
			_handle_scatter(delta)
			
	_update_chicks(delta)


func _pick_state() -> void:
	var roll = randf()
	if roll < 0.6:
		current_state = State.PECK
		state_timer = randf_range(2.0, 5.0)
		AudioSynth.play("cluck", -8.0, randf_range(0.9, 1.15))
	else:
		current_state = State.WALK
		state_timer = randf_range(1.5, 3.5)
		var offset = Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
		target_pos = home_pos + offset


func _handle_walk(delta: float) -> void:
	var dir = target_pos - global_position
	dir.y = 0.0
	
	if dir.length() > 0.4:
		var move_dir = dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 6.0)
		
		# Quick jerky head-bob
		walk_anim += delta * 12.0
		head_pivot.position.z = 0.2 + sin(walk_anim) * 0.08
	else:
		velocity.x = 0
		velocity.z = 0
		current_state = State.PECK
		state_timer = randf_range(2.0, 4.0)
		
	move_and_slide()


func _handle_peck(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	peck_anim += delta * 8.0
	var peck = maxf(0.0, sin(peck_anim))
	head_pivot.rotation_degrees.x = peck * -45.0
	head_pivot.position.y = 0.4 - peck * 0.15


func _handle_scatter(delta: float) -> void:
	_handle_walk(delta)
	# Flap wings when scattering
	wing_l.rotation_degrees.z = -35.0 + sin(Time.get_ticks_msec() * 0.03) * 25.0
	wing_r.rotation_degrees.z = 35.0 - sin(Time.get_ticks_msec() * 0.03) * 25.0


func _update_chicks(delta: float) -> void:
	var moving = velocity.length() > 0.1
	for i in range(chicks.size()):
		var chick = chicks[i]
		if moving:
			# Waddle side-to-side behind mother hen
			chick.position.x = sin(Time.get_ticks_msec() * 0.01 + i) * 0.15
			chick.position.y = absf(sin(Time.get_ticks_msec() * 0.018 + i)) * 0.04
			chick.rotation_degrees.x = 0.0
		else:
			# Little chicks pecking grass
			chick.position.y = 0.0
			chick.rotation_degrees.x = maxf(0.0, sin(Time.get_ticks_msec() * 0.008 + i * 2.0)) * -32.0


func _build_chicken_model() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ChickenModel"
	add_child(visual_root)
	
	# Materials
	var mat_feathers = StandardMaterial3D.new()
	mat_feathers.albedo_color = Color(0.78, 0.52, 0.28) # Warm golden-brown hen
	
	var mat_wing = StandardMaterial3D.new()
	mat_wing.albedo_color = Color(0.62, 0.38, 0.20) # Darker wing feathers
	
	var mat_comb = StandardMaterial3D.new()
	mat_comb.albedo_color = Color(0.85, 0.15, 0.15) # Red crest / comb
	
	var mat_beak = StandardMaterial3D.new()
	mat_beak.albedo_color = Color(0.95, 0.75, 0.15) # Yellow beak & legs
	
	# Body
	var body = MeshInstance3D.new()
	var bm = SphereMesh.new()
	bm.radius = 0.24
	bm.height = 0.42
	body.mesh = bm
	body.material_override = mat_feathers
	body.position = Vector3(0, 0.32, 0)
	visual_root.add_child(body)
	
	# Tail Feathers
	var tail = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(0.12, 0.25, 0.22)
	tail.mesh = tm
	tail.material_override = mat_wing
	tail.position = Vector3(0, 0.42, -0.22)
	tail.rotation_degrees.x = 35.0
	visual_root.add_child(tail)
	
	# Head Pivot
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.45, 0.18)
	visual_root.add_child(head_pivot)
	
	var head_mesh = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.2
	head_mesh.mesh = hm
	head_mesh.material_override = mat_feathers
	head_pivot.add_child(head_mesh)
	
	# Red Comb on top
	var comb = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(0.04, 0.12, 0.14)
	comb.mesh = cm
	comb.material_override = mat_comb
	comb.position = Vector3(0, 0.12, 0)
	head_pivot.add_child(comb)
	
	# Beak
	var beak = MeshInstance3D.new()
	var bkm = CylinderMesh.new()
	bkm.top_radius = 0.01
	bkm.bottom_radius = 0.04
	bkm.height = 0.1
	beak.mesh = bkm
	beak.material_override = mat_beak
	beak.position = Vector3(0, 0.0, 0.14)
	beak.rotation_degrees.x = 90.0
	head_pivot.add_child(beak)
	
	# Wings
	wing_l = Node3D.new()
	wing_l.position = Vector3(-0.2, 0.35, 0)
	visual_root.add_child(wing_l)
	var wlm = MeshInstance3D.new()
	var wm = BoxMesh.new()
	wm.size = Vector3(0.06, 0.2, 0.28)
	wlm.mesh = wm
	wlm.material_override = mat_wing
	wing_l.add_child(wlm)
	
	wing_r = Node3D.new()
	wing_r.position = Vector3(0.2, 0.35, 0)
	visual_root.add_child(wing_r)
	var wrm = MeshInstance3D.new()
	wrm.mesh = wm
	wrm.material_override = mat_wing
	wing_r.add_child(wrm)
	
	# 2 Thin Legs
	for side in [-1.0, 1.0]:
		var leg = MeshInstance3D.new()
		var lm = CylinderMesh.new()
		lm.top_radius = 0.02
		lm.bottom_radius = 0.02
		lm.height = 0.2
		leg.mesh = lm
		leg.material_override = mat_beak
		leg.position = Vector3(side * 0.09, 0.1, 0)
		visual_root.add_child(leg)


func _spawn_chicks() -> void:
	var mat_chick = StandardMaterial3D.new()
	mat_chick.albedo_color = Color(0.98, 0.88, 0.32) # Fluffy yellow chick
	
	var mat_beak = StandardMaterial3D.new()
	mat_beak.albedo_color = Color(0.95, 0.55, 0.15)
	
	for i in range(3):
		var chick = Node3D.new()
		chick.name = "Chick_" + str(i)
		
		var ball = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.15
		ball.mesh = sm
		ball.material_override = mat_chick
		ball.position.y = 0.1
		chick.add_child(ball)
		
		var cbk = MeshInstance3D.new()
		var bkm = CylinderMesh.new()
		bkm.top_radius = 0.01
		bkm.bottom_radius = 0.03
		bkm.height = 0.06
		cbk.mesh = bkm
		cbk.material_override = mat_beak
		cbk.position = Vector3(0, 0.1, 0.08)
		cbk.rotation_degrees.x = 90.0
		chick.add_child(cbk)
		
		chick.position = Vector3(randf_range(-0.15, 0.15), 0.0, -0.45 * (i + 1))
		add_child(chick)
		chicks.append(chick)
