extends StaticBody3D
class_name CountrysideCookingStation

const AudioSynth = preload("res://scripts/audio_synth.gd")
const CountrysideSmokeFX = preload("res://scripts/smoke_fx.gd")

var is_interactable: bool = true
var interact_prompt: String = "Cook at Clay Stove (ធ្វើម្ហូបនៅចង្ក្រាន)"

var current_player: Node = null
var cooking_ui: CanvasLayer = null
var cooking_panel: PanelContainer = null
var ingredients_label: Label = null
var btn_chek_ang: Button = null
var btn_kralan: Button = null
var btn_lotus_tea: Button = null

func _ready() -> void:
	add_to_group("interactables")
	_build_station_mesh()


func _build_station_mesh() -> void:
	# 1. Terracotta Clay Stove (Chhangkran)
	var stove_mesh := CylinderMesh.new()
	stove_mesh.top_radius = 0.36
	stove_mesh.bottom_radius = 0.40
	stove_mesh.height = 0.45
	var stove := MeshInstance3D.new()
	stove.mesh = stove_mesh
	stove.position = Vector3(0, 0.22, 0)
	var stove_mat := StandardMaterial3D.new()
	stove_mat.albedo_color = Color(0.72, 0.45, 0.30) # Terracotta clay
	stove_mat.roughness = 0.94
	stove.material_override = stove_mat
	add_child(stove)

	# Charcoal opening / mouth in stove
	var opening_mesh := BoxMesh.new()
	opening_mesh.size = Vector3(0.24, 0.20, 0.24)
	var opening := MeshInstance3D.new()
	opening.mesh = opening_mesh
	opening.position = Vector3(0, 0.18, 0.26)
	var charcoal_mat := StandardMaterial3D.new()
	charcoal_mat.albedo_color = Color(0.12, 0.10, 0.08)
	charcoal_mat.emission_enabled = true
	charcoal_mat.emission = Color(0.95, 0.40, 0.10) # Glowing charcoal embers
	charcoal_mat.emission_energy_multiplier = 1.8
	opening.material_override = charcoal_mat
	add_child(opening)

	# Charcoal ember light
	var ember_light := OmniLight3D.new()
	ember_light.light_color = Color(1.0, 0.55, 0.2)
	ember_light.light_energy = 0.9
	ember_light.omni_range = 2.5
	ember_light.position = Vector3(0, 0.25, 0.3)
	add_child(ember_light)

	# Clay cooking pot on top
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.30
	pot_mesh.bottom_radius = 0.24
	pot_mesh.height = 0.32
	var pot := MeshInstance3D.new()
	pot.mesh = pot_mesh
	pot.position = Vector3(0, 0.56, 0)
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.22, 0.19, 0.16) # Soot darkened cooking clay
	pot.material_override = pot_mat
	add_child(pot)

	# 2. Rustic Wooden Food Prep Table (Krea) beside stove
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(1.4, 0.65, 0.9)
	table.mesh = table_mesh
	table.position = Vector3(1.1, 0.32, 0)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.30, 0.18)
	wood_mat.roughness = 0.85
	table.material_override = wood_mat
	add_child(table)

	# Banana leaf plate on table
	var leaf := MeshInstance3D.new()
	var leaf_mesh := PlaneMesh.new()
	leaf_mesh.size = Vector2(0.65, 0.45)
	leaf.mesh = leaf_mesh
	leaf.position = Vector3(1.1, 0.66, 0)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.24, 0.55, 0.20)
	leaf_mat.roughness = 0.4
	leaf.material_override = leaf_mat
	add_child(leaf)

	# 3. Rising Cooking Smoke
	var smoke = CountrysideSmokeFX.new()
	smoke.position = Vector3(0, 0.72, 0)
	add_child(smoke)

	# 4. Collision shape
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 1.2, 1.5)
	col.shape = box
	col.position = Vector3(0.5, 0.6, 0)
	add_child(col)


func interact(player: Node) -> void:
	current_player = player
	_open_cooking_menu()


func _open_cooking_menu() -> void:
	if not current_player:
		return

	if current_player.has_method("release_mouse"):
		current_player.release_mouse()
	if "is_cooking" in current_player:
		current_player.is_cooking = true

	if cooking_ui:
		cooking_ui.queue_free()

	cooking_ui = CanvasLayer.new()
	cooking_ui.name = "CookingUIOverlay"
	add_child(cooking_ui)

	cooking_panel = PanelContainer.new()
	cooking_panel.name = "CookingPanel"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.95)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.65, 0.35, 0.85)
	cooking_panel.add_theme_stylebox_override("panel", style)

	cooking_panel.set_anchors_preset(Control.PRESET_CENTER)
	cooking_panel.anchor_left = 0.28
	cooking_panel.anchor_right = 0.72
	cooking_panel.anchor_top = 0.12
	cooking_panel.anchor_bottom = 0.88
	cooking_ui.add_child(cooking_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cooking_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Header Title
	var title := Label.new()
	title.text = "COUNTRYSIDE CLAY STOVE\nចង្ក្រានដីស្រុកស្រែ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	vbox.add_child(title)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Available Ingredients
	ingredients_label = Label.new()
	ingredients_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ingredients_label.add_theme_font_size_override("font_size", 14)
	ingredients_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.85))
	vbox.add_child(ingredients_label)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Recipe 1: Grilled Bananas (Chek Ang)
	btn_chek_ang = _create_recipe_row(
		vbox,
		"Grilled Bananas (ចេកអាំង)",
		"Ingredients: 2 Bananas, 1 Coconut\nBuff: Energy Boost (+40% Sprint Speed for 60s)",
		func(): _cook_dish("Chek Ang", {"banana": 2, "coconut": 1}, "speed", 60.0, 1.40, "Ate Grilled Bananas! Sprint Speed +40% (60s)")
	)

	# Recipe 2: Bamboo Sticky Rice (Kralan)
	btn_kralan = _create_recipe_row(
		vbox,
		"Bamboo Sticky Rice (ក្រឡាន)",
		"Ingredients: 2 Coconuts, 1 Banana\nBuff: Strong Legs (+50% Jump Height for 60s)",
		func(): _cook_dish("Kralan", {"coconut": 2, "banana": 1}, "jump", 60.0, 1.50, "Ate Bamboo Sticky Rice! Jump Height +50% (60s)")
	)

	# Recipe 3: Sacred Lotus Tea (Te Phka Chhouk)
	btn_lotus_tea = _create_recipe_row(
		vbox,
		"Sacred Lotus Petal Tea (តែផ្កាឈូក)",
		"Ingredients: 2 Lotus Blossoms\nBuff: Serenity (+30% Speed & Jump for 60s)",
		func(): _cook_dish("Lotus Tea", {"lotus": 2}, "serenity", 60.0, 1.30, "Drank Sacred Lotus Tea! Speed & Jump +30% (60s)")
	)

	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	# Close Button
	var btn_close := Button.new()
	btn_close.text = "Close Kitchen (បិទ)"
	btn_close.add_theme_font_size_override("font_size", 15)
	btn_close.pressed.connect(_close_cooking_menu)
	vbox.add_child(btn_close)

	_update_menu_state()


func _create_recipe_row(parent: VBoxContainer, recipe_title: String, recipe_desc: String, on_cook: Callable) -> Button:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.18, 0.20, 0.22, 0.9)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var lbl_name := Label.new()
	lbl_name.text = recipe_title
	lbl_name.add_theme_font_size_override("font_size", 15)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
	text_vbox.add_child(lbl_name)

	var lbl_info := Label.new()
	lbl_info.text = recipe_desc
	lbl_info.add_theme_font_size_override("font_size", 12)
	lbl_info.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	text_vbox.add_child(lbl_info)

	var cook_btn := Button.new()
	cook_btn.text = "Cook (ធ្វើ)"
	cook_btn.add_theme_font_size_override("font_size", 14)
	cook_btn.pressed.connect(on_cook)
	hbox.add_child(cook_btn)

	return cook_btn


func _update_menu_state() -> void:
	if not current_player:
		return

	var inv = current_player.get("inventory")
	if inv is Dictionary:
		var c = inv.get("coconut", 0)
		var b = inv.get("banana", 0)
		var l = inv.get("lotus", 0)
		if ingredients_label:
			ingredients_label.text = "Your Ingredients: Coconuts: %d | Bananas: %d | Lotus: %d" % [c, b, l]

		if btn_chek_ang:
			btn_chek_ang.disabled = not (b >= 2 and c >= 1)
		if btn_kralan:
			btn_kralan.disabled = not (c >= 2 and b >= 1)
		if btn_lotus_tea:
			btn_lotus_tea.disabled = not (l >= 2)


func _cook_dish(dish_name: String, cost: Dictionary, buff_type: String, duration: float, mult: float, toast_desc: String) -> void:
	if not current_player:
		return

	# Verify and consume
	for item in cost:
		if not current_player.has_item(item, cost[item]):
			return

	for item in cost:
		current_player.remove_inventory(item, cost[item])

	# Sound & effects
	AudioSynth.play("sizzle", 3.0)
	current_player.apply_food_buff(buff_type, duration, mult, toast_desc)

	# Floating notification above stove
	var label = Label3D.new()
	label.text = "Cooked " + dish_name + "!"
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = global_position + Vector3(0, 1.4, 0)
	get_parent().add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.0, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)

	_update_menu_state()


func _close_cooking_menu() -> void:
	if current_player:
		if "is_cooking" in current_player:
			current_player.is_cooking = false
		if current_player.has_method("capture_mouse"):
			current_player.capture_mouse()

	if cooking_ui:
		cooking_ui.queue_free()
		cooking_ui = null
