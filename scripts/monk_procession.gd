extends Node3D
class_name CountrysideMonkProcession

const AudioSynth = preload("res://scripts/audio_synth.gd")
const CountrysideSmokeFX = preload("res://scripts/smoke_fx.gd")

# Buddhist Monks' Morning Alms Round (បិណ្ឌបាត)
var is_interactable: bool = true
var interact_prompt: String = "Offer Alms to Monks (ដាក់បាត្រព្រះសង្ឃ) [E]"

var monk_nodes: Array[Node3D] = []
var bowls: Array[MeshInstance3D] = []
var walk_time: float = 0.0

# Waypoints along the village dirt road
var waypoints: Array[Vector3] = [
	Vector3(-2.0, 0.0, 32.0),   # South road towards Pagoda
	Vector3(-1.8, 0.0, 16.0),   # South village approach
	Vector3(-1.5, 0.0, 2.0),    # Main Crossroads
	Vector3(-12.0, 0.0, 3.5),   # Path towards Cambodian Stilt House
	Vector3(-17.5, 0.0, 4.0),   # Front of the house yard
	Vector3(-12.0, 0.0, 3.5),   # Turnaround back to crossroads
	Vector3(-1.5, 0.0, 2.0),    # Crossroads
	Vector3(-2.0, 0.0, 32.0)    # Return to Pagoda
]

var current_waypoint_idx: int = 0
var move_speed: float = 0.85 # Serene, meditative walking pace

var is_blessing: bool = false
var blessing_timer: float = 0.0

func _ready() -> void:
	add_to_group("interactables")
	_build_monk_procession()

	# Start near the crossroads
	global_position = waypoints[0]


func _build_monk_procession() -> void:
	# 3 Monks in Theravada single-file tradition
	var robe_colors = [
		Color(0.85, 0.42, 0.05), # Deep ochre saffron (Elder monk)
		Color(0.92, 0.50, 0.08), # Classic saffron (Mid monk)
		Color(0.96, 0.58, 0.12)  # Bright golden saffron (Novice)
	]

	for i in range(3):
		var monk = Node3D.new()
		monk.name = "Monk_" + str(i)
		# Spaced 1.4m behind one another
		monk.position = Vector3(0, 0, -float(i) * 1.4)
		add_child(monk)
		monk_nodes.append(monk)

		var mat_robe := StandardMaterial3D.new()
		mat_robe.albedo_color = robe_colors[i]
		mat_robe.roughness = 0.85

		var mat_skin := StandardMaterial3D.new()
		mat_skin.albedo_color = Color(0.82, 0.62, 0.45) # Sun-tanned Cambodian skin
		mat_skin.roughness = 0.8

		var mat_bowl := StandardMaterial3D.new()
		mat_bowl.albedo_color = Color(0.12, 0.12, 0.14) # Black lacquered alms bowl (Bat)
		mat_bowl.roughness = 0.35

		# 1. Shaven Head
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(0.36, 0.38, 0.36)
		var head := MeshInstance3D.new()
		head.mesh = head_mesh
		head.position = Vector3(0, 1.70, 0)
		head.material_override = mat_skin
		monk.add_child(head)

		# 2. Main Body / Saffron Robe (Civara)
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(0.55, 1.35, 0.40)
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.position = Vector3(0, 0.78, 0)
		body.material_override = mat_robe
		monk.add_child(body)

		# Shoulder wrap fold
		var fold_mesh := BoxMesh.new()
		fold_mesh.size = Vector3(0.24, 0.90, 0.44)
		var fold := MeshInstance3D.new()
		fold.mesh = fold_mesh
		fold.position = Vector3(-0.18, 0.95, 0)
		fold.material_override = mat_robe
		monk.add_child(fold)

		# 3. Alms Bowl (Bat / បាត) held with both hands
		var bowl_mesh := CylinderMesh.new()
		bowl_mesh.top_radius = 0.18
		bowl_mesh.bottom_radius = 0.14
		bowl_mesh.height = 0.22
		var bowl := MeshInstance3D.new()
		bowl.mesh = bowl_mesh
		bowl.position = Vector3(0, 1.05, 0.26)
		bowl.material_override = mat_bowl
		monk.add_child(bowl)
		bowls.append(bowl)

		# Hands supporting the bowl
		for side in [-1.0, 1.0]:
			var hand_mesh := BoxMesh.new()
			hand_mesh.size = Vector3(0.08, 0.08, 0.14)
			var hand := MeshInstance3D.new()
			hand.mesh = hand_mesh
			hand.position = Vector3(side * 0.19, 1.04, 0.22)
			hand.material_override = mat_skin
			monk.add_child(hand)

	# Interaction Collision Capsule around leading monk
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.0
	col.shape = cap
	col.position = Vector3(0, 1.0, 0)
	add_child(col)

	# Incense burner smoke near leader
	var smoke = CountrysideSmokeFX.new()
	smoke.position = Vector3(0, 0.3, 0.5)
	smoke.smoke_color = Color(0.9, 0.88, 0.8, 0.25)
	add_child(smoke)


func interact(player: Node) -> void:
	if is_blessing:
		return

	# Check player inventory for alms items (Lotus, Banana, Coconut, Fish)
	var offered_item = ""
	if player.has_method("has_item") and player.has_method("remove_inventory"):
		if player.has_item("lotus", 1):
			player.remove_inventory("lotus", 1)
			offered_item = "Sacred Lotus Blossom (ផ្កាឈូក)"
		elif player.has_item("banana", 1):
			player.remove_inventory("banana", 1)
			offered_item = "Sweet Countryside Banana (ចេកទុំ)"
		elif player.has_item("coconut", 1):
			player.remove_inventory("coconut", 1)
			offered_item = "Fresh Coconut (ដូងក្រអូប)"
		elif player.has_item("fish", 1):
			player.remove_inventory("fish", 1)
			offered_item = "Fresh Caught Fish (ត្រីស្រស់)"

	is_blessing = true
	blessing_timer = 3.5

	if offered_item != "":
		# Buddhist blessing chime
		AudioSynth.play("blessing", 3.0)

		# Grant Merit Serenity Buff
		if player.has_method("apply_food_buff"):
			player.apply_food_buff(
				"serenity",
				120.0,
				1.35,
				"Offered " + offered_item + "! Received Monk's Blessing (បានទទួលពរជ័យ)"
			)

		_show_floating_text("+Merit & Peace! (ទទួលបានបុណ្យកុសល)")
	else:
		# Kind greeting if no food
		AudioSynth.play("pagoda_bell", 1.0, 1.2)
		_show_floating_text("May you be peaceful and well (សូមឲ្យបានសេចក្តីសុខ)")


func _process(delta: float) -> void:
	walk_time += delta

	# Blessing pause and bow
	if is_blessing:
		blessing_timer -= delta
		for monk in monk_nodes:
			monk.rotation.x = sin(blessing_timer * 1.5) * 0.12 # Gentle bow
		if blessing_timer <= 0.0:
			is_blessing = false
			for monk in monk_nodes:
				monk.rotation.x = 0.0
		return

	# Peaceful walking along the road waypoints
	if waypoints.size() > 0:
		var target = waypoints[current_waypoint_idx]
		var diff = target - global_position
		diff.y = 0.0
		var dist = diff.length()

		if dist > 0.4:
			var dir = diff.normalized()
			var target_rot = atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_rot, delta * 3.0)
			global_position += dir * move_speed * delta

			# Gentle walking sway
			var step_sway = sin(walk_time * 2.5) * 0.03
			for i in range(monk_nodes.size()):
				monk_nodes[i].position.y = absf(sin(walk_time * 2.5 + float(i))) * 0.04
		else:
			# Advance to next waypoint
			current_waypoint_idx = (current_waypoint_idx + 1) % waypoints.size()


func _show_floating_text(msg: String) -> void:
	var label = Label3D.new()
	label.text = msg
	label.font_size = 30
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.92, 0.45)
	label.position = Vector3(0, 2.2, 0)
	add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", 3.0, 1.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.6)
	tw.tween_callback(label.queue_free)
