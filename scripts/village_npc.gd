extends StaticBody3D
class_name VillageNPC

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Countryside Villagers (អ្នកភូមិខ្មែរ)
@export var npc_name: String = "Ta Sok (តាសុខ)"
@export var npc_role: String = "Village Elder (ចាស់ទុំភូមិ)"
@export var greeting_text: String = "Peace and good health to you, grandchild. (ជម្រាបសួរចៅ)"
@export var quest_text: String = "The monks are walking their morning alms round. Could you bring 1 fresh Coconut or Lotus to help with the village offering?"
@export var quest_item: String = "coconut" # coconut, fish, lotus, banana
@export var quest_item_amount: int = 1
@export var reward_item: String = "banana"
@export var reward_amount: int = 2
@export var completed_text: String = "Sadhu! May the merits of this offering bring peace and prosperity to your path. (សូមឲ្យបានសេចក្តីសុខ)"

@export var shirt_color: Color = Color(0.88, 0.86, 0.80) # Cotton white
@export var pants_color: Color = Color(0.20, 0.22, 0.26) # Dark charcoal
@export var krama_color: Color = Color(0.85, 0.24, 0.24) # Classic red krama
@export var skin_color: Color = Color(0.78, 0.58, 0.40)  # Tan skin

var is_interactable: bool = true
var interact_prompt: String = "Talk to %s [E]"

var is_quest_completed: bool = false
var has_accepted_quest: bool = false

var dialogue_ui: CanvasLayer = null
var current_player: Node = null

# Visual Mesh Nodes
var head: MeshInstance3D
var body: MeshInstance3D
var krama: MeshInstance3D

func _ready() -> void:
	add_to_group("interactables")
	interact_prompt = "Talk to " + npc_name + " [E]"
	_build_villager_model()


func _build_villager_model() -> void:
	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = skin_color
	mat_skin.roughness = 0.85

	var mat_shirt := StandardMaterial3D.new()
	mat_shirt.albedo_color = shirt_color
	mat_shirt.roughness = 0.8

	var mat_pants := StandardMaterial3D.new()
	mat_pants.albedo_color = pants_color
	mat_pants.roughness = 0.8

	var mat_krama := StandardMaterial3D.new()
	mat_krama.albedo_color = krama_color
	mat_krama.roughness = 0.75

	# 1. Torso / Shirt
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.55, 0.75, 0.32)
	body = MeshInstance3D.new()
	body.mesh = b_mesh
	body.position = Vector3(0, 1.05, 0)
	body.material_override = mat_shirt
	add_child(body)

	# 2. Traditional Krama draped across shoulder or neck
	var k_mesh := BoxMesh.new()
	k_mesh.size = Vector3(0.58, 0.14, 0.36)
	krama = MeshInstance3D.new()
	krama.mesh = k_mesh
	krama.position = Vector3(0, 1.38, 0)
	krama.material_override = mat_krama
	add_child(krama)

	# Krama tail hanging down
	var kt_mesh := BoxMesh.new()
	kt_mesh.size = Vector3(0.14, 0.42, 0.08)
	var krama_tail := MeshInstance3D.new()
	krama_tail.mesh = kt_mesh
	krama_tail.position = Vector3(-0.16, 1.15, 0.16)
	krama_tail.material_override = mat_krama
	add_child(krama_tail)

	# 3. Head
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.36, 0.36, 0.36)
	head = MeshInstance3D.new()
	head.mesh = h_mesh
	head.position = Vector3(0, 1.62, 0)
	head.material_override = mat_skin
	add_child(head)

	# 4. Arms
	for side in [-1.0, 1.0]:
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.16, 0.65, 0.18)
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.36, 1.05, 0)
		arm.material_override = mat_shirt
		add_child(arm)

	# 5. Legs / Sampot / Pants
	for side in [-1.0, 1.0]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.20, 0.70, 0.22)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.14, 0.35, 0)
		leg.material_override = mat_pants
		add_child(leg)

	# 6. Interaction collision shape
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	add_child(col)


func interact(player: Node) -> void:
	current_player = player
	_open_dialogue()


func _open_dialogue() -> void:
	if not current_player:
		return

	if current_player.has_method("release_mouse"):
		current_player.release_mouse()

	if dialogue_ui:
		dialogue_ui.queue_free()

	dialogue_ui = CanvasLayer.new()
	dialogue_ui.name = "NPCDialogueOverlay"
	add_child(dialogue_ui)

	# Dialogue Box Panel Container at Bottom
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.90, 0.75, 0.45, 0.9) # Gold Khmer border
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)

	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.68
	panel.anchor_bottom = 0.95
	dialogue_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header: NPC Name & Role
	var lbl_name := Label.new()
	lbl_name.text = npc_name + " - " + npc_role
	lbl_name.add_theme_font_size_override("font_size", 18)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	vbox.add_child(lbl_name)

	# Dialogue Content
	var lbl_speech := Label.new()
	lbl_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_speech.add_theme_font_size_override("font_size", 15)
	lbl_speech.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(lbl_speech)

	var hbox_btns := HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_END
	hbox_btns.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox_btns)

	if is_quest_completed:
		lbl_speech.text = completed_text
		var btn_close := Button.new()
		btn_close.text = "Goodbye (លាហើយ)"
		btn_close.add_theme_font_size_override("font_size", 14)
		btn_close.pressed.connect(_close_dialogue)
		hbox_btns.add_child(btn_close)
		return

	# Check if player has the quest item
	var has_item = current_player.has_method("has_item") and current_player.has_item(quest_item, quest_item_amount)

	if has_accepted_quest:
		if has_item:
			lbl_speech.text = "Ah! You have the %s! Thank you so much! (អរគុណច្រើន)" % quest_item.capitalize()
			var btn_give := Button.new()
			btn_give.text = "Deliver %s (ជូន%s)" % [quest_item.capitalize(), quest_item]
			btn_give.add_theme_font_size_override("font_size", 14)
			btn_give.pressed.connect(_complete_quest)
			hbox_btns.add_child(btn_give)
		else:
			lbl_speech.text = "Please bring %d %s when you can. (សូមជួយរក%s)" % [quest_item_amount, quest_item.capitalize(), quest_item]
	else:
		lbl_speech.text = greeting_text + "\n\n" + quest_text
		var btn_accept := Button.new()
		btn_accept.text = "I will help! (ខ្ញុំនឹងជួយ) [Accept]"
		btn_accept.add_theme_font_size_override("font_size", 14)
		btn_accept.pressed.connect(func():
			has_accepted_quest = true
			_close_dialogue()
			_show_toast("Accepted Errand: " + quest_item.capitalize() + " for " + npc_name)
		)
		hbox_btns.add_child(btn_accept)

	var btn_leave := Button.new()
	btn_leave.text = "Farewell (លាហើយ)"
	btn_leave.add_theme_font_size_override("font_size", 14)
	btn_leave.pressed.connect(_close_dialogue)
	hbox_btns.add_child(btn_leave)


func _complete_quest() -> void:
	if not current_player:
		return

	# Deduct item
	if current_player.has_method("remove_inventory"):
		current_player.remove_inventory(quest_item, quest_item_amount)

	# Give reward
	if current_player.has_method("add_inventory"):
		current_player.add_inventory(reward_item, reward_amount)

	is_quest_completed = true
	AudioSynth.play("pickup", 2.2)

	# Grant gratitude buff
	if current_player.has_method("apply_food_buff"):
		current_player.apply_food_buff(
			"strength",
			90.0,
			1.40,
			"Completed Errand for " + npc_name + "! Received +" + str(reward_amount) + " " + reward_item.capitalize()
		)

	_show_toast("Errand Completed! Received +" + str(reward_amount) + " " + reward_item.capitalize())
	_close_dialogue()


func _close_dialogue() -> void:
	if current_player and current_player.has_method("capture_mouse"):
		current_player.capture_mouse()

	if dialogue_ui:
		dialogue_ui.queue_free()
		dialogue_ui = null


func _show_toast(msg: String) -> void:
	var label = Label3D.new()
	label.text = msg
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.65, 1.0, 0.55)
	label.position = global_position + Vector3(0, 2.1, 0)
	get_parent().add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.2, 1.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.6)
	tw.tween_callback(label.queue_free)
