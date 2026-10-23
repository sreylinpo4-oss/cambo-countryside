extends CharacterBody3D

const AudioSynth = preload("res://scripts/audio_synth.gd")
const CountrysideBicycle = preload("res://scripts/bicycle.gd")
const CambodianWaterBuffalo = preload("res://scripts/buffalo.gd")
const CountrysideHammock = preload("res://scripts/hammock.gd")

@export var move_speed: float = 6.0
@export var sprint_speed: float = 12.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.0025

var gravity: float = 14.0
var pivot: Node3D
var camera: Camera3D

# Visual body parts for walk animation & customization
var visual_root: Node3D
var head_mesh: MeshInstance3D
var body_mesh: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var walk_time: float = 0.0
var is_first_person: bool = false

# Customization Accessories
var hat_nodes: Array[Node3D] = []
var krama_nodes: Array[Node3D] = []
var krama_materials: Array[StandardMaterial3D] = []

# Customization Data
const HATS = [
	"None",
	"Conical Palm Hat (មួកស្លឹកត្នោត)",
	"Red Krama Wrap (ក្រមារុំក្បាល)",
	"Blue Krama Wrap (ក្រមាខៀវ)",
	"Straw Sun Cap"
]

const KRAMAS = [
	"None",
	"Classic Red Krama (ក្រមាក្រហម)",
	"Indigo Blue Krama (ក្រមាខៀវ)",
	"Golden Harvest Krama (ក្រមាពណ៌មាស)",
	"Paddy Green Krama (ក្រមាពណ៌បៃតង)"
]

const SHIRT_COLORS = [
	{"name": "Rice Green", "color": Color(0.22, 0.48, 0.28)},
	{"name": "Indigo Blue", "color": Color(0.20, 0.35, 0.65)},
	{"name": "Terracotta Red", "color": Color(0.72, 0.35, 0.22)},
	{"name": "Cotton White", "color": Color(0.88, 0.85, 0.78)},
	{"name": "Lotus Crimson", "color": Color(0.68, 0.22, 0.32)},
	{"name": "Golden Ochre", "color": Color(0.82, 0.62, 0.22)},
	{"name": "Charcoal Black", "color": Color(0.20, 0.20, 0.22)}
]

const PANTS_COLORS = [
	{"name": "Dark Navy", "color": Color(0.18, 0.22, 0.32)},
	{"name": "Earth Brown", "color": Color(0.38, 0.26, 0.18)},
	{"name": "Forest Olive", "color": Color(0.25, 0.32, 0.20)},
	{"name": "Charcoal", "color": Color(0.15, 0.15, 0.18)},
	{"name": "Deep Maroon", "color": Color(0.36, 0.18, 0.22)}
]

const SKIN_COLORS = [
	{"name": "Sun-Kissed Tan", "color": Color(0.85, 0.65, 0.48)},
	{"name": "Golden Honey", "color": Color(0.78, 0.58, 0.40)},
	{"name": "Rich Bronze", "color": Color(0.65, 0.46, 0.32)},
	{"name": "Fair Sand", "color": Color(0.92, 0.74, 0.58)}
]

var costume := {
	"hat": 1,
	"krama": 1,
	"shirt": 0,
	"pants": 0,
	"skin": 0
}

# Customization Menu State & UI References
var is_customizing: bool = false
var custom_ui: CanvasLayer
var custom_panel: PanelContainer
var lbl_hat: Label
var lbl_krama: Label
var lbl_shirt: Label
var lbl_pants: Label
var lbl_skin: Label
var is_dragging_preview: bool = false

# Vehicle & Hammock Mounting State
var current_vehicle: Node = null
var vehicle_seat: Node3D = null
var collision_node: CollisionShape3D

# Interaction System
var closest_interactable: Node = null
var interaction_panel: PanelContainer
var interaction_label: Label

# Item Inventory
var inventory := {
	"coconut": 0,
	"banana": 0,
	"lotus": 0,
	"fish": 0
}
var lbl_coconuts: Label
var lbl_bananas: Label
var lbl_lotus: Label
var lbl_fish: Label

# Active Food Buffs, Fishing & Cooking State
var is_cooking: bool = false
var is_fishing: bool = false
var is_photo_mode: bool = false
var photo_ui: CanvasLayer = null
var photo_zoom_label: Label = null
var saved_camera_fov: float = 75.0
var speed_buff_timer: float = 0.0
var speed_buff_mult: float = 1.0
var jump_buff_timer: float = 0.0
var jump_buff_mult: float = 1.0
var buff_label: Label

# Footstep Audio Timer
var footstep_timer: float = 0.0

func capture_mouse() -> void:
	if not is_customizing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not is_customizing:
			call_deferred("capture_mouse")

func _ready() -> void:
	capture_mouse()
	call_deferred("capture_mouse")
	_capture_mouse_safely()

	# Container for visible body parts
	visual_root = Node3D.new()
	visual_root.name = "VisualModel"
	add_child(visual_root)

	# Build Character Model
	build_character_model()

	# Solid player collision capsule
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.9
	collision.shape = shape
	collision.position.y = 0.95
	add_child(collision)
	collision_node = collision

	# Camera pivot
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0, 1.5, 0)
	add_child(pivot)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.position = Vector3(0, 0.8, 4.2)
	camera.rotation_degrees.x = -8.0
	pivot.add_child(camera)
	camera.make_current()

	# Load saved costume if available
	load_costume()
	apply_costume()

	# Create Customization UI overlay & Interaction / Inventory HUD
	create_customization_ui()
	create_interaction_hud()
	create_inventory_hud()

func _capture_mouse_safely() -> void:
	await get_tree().process_frame
	capture_mouse()

func build_character_model() -> void:
	# 1. Torso
	body_mesh = make_box_part("Body", Vector3(0, 1.1, 0), Vector3(0.65, 0.85, 0.35), SHIRT_COLORS[0].color)

	# 2. Head
	head_mesh = make_box_part("Head", Vector3(0, 1.85, 0), Vector3(0.42, 0.42, 0.42), SKIN_COLORS[0].color)

	# 3. Limbs
	left_arm = make_box_part("LeftArm", Vector3(-0.48, 1.12, 0), Vector3(0.2, 0.7, 0.22), SKIN_COLORS[0].color)
	right_arm = make_box_part("RightArm", Vector3(0.48, 1.12, 0), Vector3(0.2, 0.7, 0.22), SKIN_COLORS[0].color)

	left_leg = make_box_part("LeftLeg", Vector3(-0.18, 0.42, 0), Vector3(0.23, 0.75, 0.27), PANTS_COLORS[0].color)
	right_leg = make_box_part("RightLeg", Vector3(0.18, 0.42, 0), Vector3(0.23, 0.75, 0.27), PANTS_COLORS[0].color)

	# 4. HATS / HEADWEAR
	# Hat 0: None
	var h0 := Node3D.new()
	h0.name = "Hat_None"
	visual_root.add_child(h0)
	hat_nodes.append(h0)

	# Hat 1: Traditional Conical Palm Leaf Hat (មួកស្លឹកត្នោត)
	var h1 := Node3D.new()
	h1.name = "Hat_Conical"
	visual_root.add_child(h1)
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.04
	cone_mesh.bottom_radius = 0.58
	cone_mesh.height = 0.28
	var cone_inst := MeshInstance3D.new()
	cone_inst.mesh = cone_mesh
	cone_inst.position = Vector3(0, 2.14, 0)
	var mat_straw := StandardMaterial3D.new()
	mat_straw.albedo_color = Color(0.82, 0.72, 0.48)
	mat_straw.roughness = 0.85
	cone_inst.material_override = mat_straw
	h1.add_child(cone_inst)

	# Rim band on conical hat
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.58
	rim_mesh.bottom_radius = 0.58
	rim_mesh.height = 0.03
	var rim_inst := MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.position = Vector3(0, 2.01, 0)
	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color(0.68, 0.26, 0.22)
	rim_inst.material_override = mat_rim
	h1.add_child(rim_inst)
	hat_nodes.append(h1)

	# Hat 2: Red Krama Headwrap (ក្រមារុំក្បាល)
	var h2 := Node3D.new()
	h2.name = "Hat_RedKramaWrap"
	visual_root.add_child(h2)
	var wrap_box := BoxMesh.new()
	wrap_box.size = Vector3(0.48, 0.12, 0.48)
	var wrap_inst := MeshInstance3D.new()
	wrap_inst.mesh = wrap_box
	wrap_inst.position = Vector3(0, 1.95, 0)
	var mat_red_wrap := StandardMaterial3D.new()
	mat_red_wrap.albedo_color = Color(0.85, 0.24, 0.24)
	wrap_inst.material_override = mat_red_wrap
	h2.add_child(wrap_inst)
	# Knot
	var knot := MeshInstance3D.new()
	var knot_mesh := BoxMesh.new()
	knot_mesh.size = Vector3(0.12, 0.18, 0.12)
	knot.mesh = knot_mesh
	knot.position = Vector3(0.22, 1.95, -0.20)
	knot.material_override = mat_red_wrap
	h2.add_child(knot)
	hat_nodes.append(h2)

	# Hat 3: Blue Krama Headwrap
	var h3 := Node3D.new()
	h3.name = "Hat_BlueKramaWrap"
	visual_root.add_child(h3)
	var b_wrap_inst := MeshInstance3D.new()
	b_wrap_inst.mesh = wrap_box
	b_wrap_inst.position = Vector3(0, 1.95, 0)
	var mat_blue_wrap := StandardMaterial3D.new()
	mat_blue_wrap.albedo_color = Color(0.22, 0.45, 0.85)
	b_wrap_inst.material_override = mat_blue_wrap
	h3.add_child(b_wrap_inst)
	var b_knot := MeshInstance3D.new()
	b_knot.mesh = knot_mesh
	b_knot.position = Vector3(0.22, 1.95, -0.20)
	b_knot.material_override = mat_blue_wrap
	h3.add_child(b_knot)
	hat_nodes.append(h3)

	# Hat 4: Straw Sun Cap
	var h4 := Node3D.new()
	h4.name = "Hat_StrawCap"
	visual_root.add_child(h4)
	var cap_inst := MeshInstance3D.new()
	var cap_sph := SphereMesh.new()
	cap_sph.radius = 0.23
	cap_sph.height = 0.28
	cap_inst.mesh = cap_sph
	cap_inst.position = Vector3(0, 2.02, 0)
	cap_inst.material_override = mat_straw
	h4.add_child(cap_inst)
	var visor := MeshInstance3D.new()
	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(0.38, 0.03, 0.20)
	visor.mesh = visor_box
	visor.position = Vector3(0, 1.96, 0.24)
	visor.material_override = mat_straw
	h4.add_child(visor)
	hat_nodes.append(h4)

	# 5. KHMER KRAMA SCARVES (ក្រមា)
	# Krama 0: None
	var k0 := Node3D.new()
	k0.name = "Krama_None"
	visual_root.add_child(k0)
	krama_nodes.append(k0)

	var krama_palette = [
		Color(0.85, 0.24, 0.24), # Classic Red Krama
		Color(0.24, 0.46, 0.85), # Indigo Blue Krama
		Color(0.88, 0.68, 0.22), # Golden Harvest Krama
		Color(0.24, 0.58, 0.28)  # Paddy Green Krama
	]

	for i in range(krama_palette.size()):
		var kn := Node3D.new()
		kn.name = "Krama_%d" % (i + 1)
		visual_root.add_child(kn)

		var k_mat := StandardMaterial3D.new()
		k_mat.albedo_color = krama_palette[i]
		k_mat.roughness = 0.8
		krama_materials.append(k_mat)

		# Neck collar wrap
		var collar := MeshInstance3D.new()
		var col_mesh := BoxMesh.new()
		col_mesh.size = Vector3(0.70, 0.16, 0.42)
		collar.mesh = col_mesh
		collar.position = Vector3(0, 1.48, 0)
		collar.material_override = k_mat
		kn.add_child(collar)

		# Front hanging drape left
		var drape_l := MeshInstance3D.new()
		var dl_mesh := BoxMesh.new()
		dl_mesh.size = Vector3(0.18, 0.52, 0.08)
		drape_l.mesh = dl_mesh
		drape_l.position = Vector3(-0.14, 1.18, 0.22)
		drape_l.material_override = k_mat
		kn.add_child(drape_l)

		# Front hanging drape right
		var drape_r := MeshInstance3D.new()
		var dr_mesh := BoxMesh.new()
		dr_mesh.size = Vector3(0.18, 0.38, 0.08)
		drape_r.mesh = dr_mesh
		drape_r.position = Vector3(0.14, 1.25, 0.22)
		drape_r.material_override = k_mat
		kn.add_child(drape_r)

		krama_nodes.append(kn)

func make_box_part(part_name: String, part_position: Vector3,
	part_size: Vector3, part_color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = part_position

	var mat := StandardMaterial3D.new()
	mat.albedo_color = part_color
	mat.roughness = 0.85
	part.material_override = mat

	visual_root.add_child(part)
	return part

# Apply current costume settings to meshes
func apply_costume() -> void:
	# 1. Shirt Color
	if body_mesh and body_mesh.material_override:
		(body_mesh.material_override as StandardMaterial3D).albedo_color = SHIRT_COLORS[costume.shirt].color

	# 2. Pants Color
	var p_color: Color = PANTS_COLORS[costume.pants].color
	if left_leg and left_leg.material_override:
		(left_leg.material_override as StandardMaterial3D).albedo_color = p_color
	if right_leg and right_leg.material_override:
		(right_leg.material_override as StandardMaterial3D).albedo_color = p_color

	# 3. Skin Color
	var s_color: Color = SKIN_COLORS[costume.skin].color
	if head_mesh and head_mesh.material_override:
		(head_mesh.material_override as StandardMaterial3D).albedo_color = s_color
	if left_arm and left_arm.material_override:
		(left_arm.material_override as StandardMaterial3D).albedo_color = s_color
	if right_arm and right_arm.material_override:
		(right_arm.material_override as StandardMaterial3D).albedo_color = s_color

	# 4. Hats
	for i in range(hat_nodes.size()):
		hat_nodes[i].visible = (i == costume.hat)

	# 5. Kramas
	for i in range(krama_nodes.size()):
		krama_nodes[i].visible = (i == costume.krama)

	# Update labels if UI exists
	update_ui_labels()

func update_ui_labels() -> void:
	if lbl_hat:
		lbl_hat.text = HATS[costume.hat]
	if lbl_krama:
		lbl_krama.text = KRAMAS[costume.krama]
	if lbl_shirt:
		lbl_shirt.text = SHIRT_COLORS[costume.shirt].name
	if lbl_pants:
		lbl_pants.text = PANTS_COLORS[costume.pants].name
	if lbl_skin:
		lbl_skin.text = SKIN_COLORS[costume.skin].name

# Persistent Storage
func save_costume() -> void:
	var f = FileAccess.open("user://player_costume.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(costume))
		f.close()

func load_costume() -> void:
	if not FileAccess.file_exists("user://player_costume.json"):
		return
	var f = FileAccess.open("user://player_costume.json", FileAccess.READ)
	if f:
		var json_str = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			if parsed.has("hat"): costume.hat = int(parsed["hat"]) % HATS.size()
			if parsed.has("krama"): costume.krama = int(parsed["krama"]) % KRAMAS.size()
			if parsed.has("shirt"): costume.shirt = int(parsed["shirt"]) % SHIRT_COLORS.size()
			if parsed.has("pants"): costume.pants = int(parsed["pants"]) % PANTS_COLORS.size()
			if parsed.has("skin"): costume.skin = int(parsed["skin"]) % SKIN_COLORS.size()

# -------------------------------------------------------------
# CUSTOMIZATION UI BUILDER
# -------------------------------------------------------------
func create_customization_ui() -> void:
	custom_ui = CanvasLayer.new()
	custom_ui.name = "CustomizationOverlay"
	add_child(custom_ui)

	# 1. Quick HUD Button to open customization anytime
	var hud_btn := Button.new()
	hud_btn.name = "QuickCustomizeButton"
	hud_btn.text = " Customize (C) "
	hud_btn.position = Vector2(24, 75)
	hud_btn.add_theme_font_size_override("font_size", 14)
	hud_btn.pressed.connect(toggle_customization)
	custom_ui.add_child(hud_btn)

	# 2. Main Customization Panel (Docked on Right)
	custom_panel = PanelContainer.new()
	custom_panel.name = "CustomPanel"
	custom_panel.visible = false
	
	# Modern semi-transparent dark wooden/glass card
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.65, 0.35, 0.8)
	custom_panel.add_theme_stylebox_override("panel", style)

	custom_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	custom_panel.anchor_left = 0.64
	custom_panel.anchor_top = 0.05
	custom_panel.anchor_right = 0.97
	custom_panel.anchor_bottom = 0.95
	custom_ui.add_child(custom_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Header Title
	var title := Label.new()
	title.text = "CUSTOMIZE CHARACTER\nកែប្រែតួអង្គរបស់អ្នក"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Selector Rows
	lbl_hat = add_option_row(vbox, "Headwear / មួក",
		func(): cycle_option("hat", -1, HATS.size()),
		func(): cycle_option("hat", 1, HATS.size()))

	lbl_krama = add_option_row(vbox, "Khmer Krama / ក្រមា",
		func(): cycle_option("krama", -1, KRAMAS.size()),
		func(): cycle_option("krama", 1, KRAMAS.size()))

	lbl_shirt = add_option_row(vbox, "Shirt / អាវ",
		func(): cycle_option("shirt", -1, SHIRT_COLORS.size()),
		func(): cycle_option("shirt", 1, SHIRT_COLORS.size()))

	lbl_pants = add_option_row(vbox, "Pants / ខោ",
		func(): cycle_option("pants", -1, PANTS_COLORS.size()),
		func(): cycle_option("pants", 1, PANTS_COLORS.size()))

	lbl_skin = add_option_row(vbox, "Skin Tone / ពណ៌សម្បុរ",
		func(): cycle_option("skin", -1, SKIN_COLORS.size()),
		func(): cycle_option("skin", 1, SKIN_COLORS.size()))

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Action Buttons (Randomize & Save)
	var btn_rand := Button.new()
	btn_rand.text = "Randomize Outfit (ចៃដន្យ)"
	btn_rand.pressed.connect(randomize_costume)
	vbox.add_child(btn_rand)

	var btn_save := Button.new()
	btn_save.text = "Save & Resume (រក្សាទុក)"
	btn_save.add_theme_font_size_override("font_size", 16)
	btn_save.pressed.connect(func(): toggle_customization())
	vbox.add_child(btn_save)

	var hint := Label.new()
	hint.text = "Tip: Drag mouse in preview to spin character.\nPress 'C' anytime to open/close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.75, 0.8))
	vbox.add_child(hint)

	update_ui_labels()

func add_option_row(parent: VBoxContainer, category_name: String, on_prev: Callable, on_next: Callable) -> Label:
	var cat_lbl := Label.new()
	cat_lbl.text = category_name
	cat_lbl.add_theme_font_size_override("font_size", 13)
	cat_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	parent.add_child(cat_lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var btn_prev := Button.new()
	btn_prev.text = " ◀ "
	btn_prev.pressed.connect(on_prev)
	hbox.add_child(btn_prev)

	var val_lbl := Label.new()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	hbox.add_child(val_lbl)

	var btn_next := Button.new()
	btn_next.text = " ▶ "
	btn_next.pressed.connect(on_next)
	hbox.add_child(btn_next)

	return val_lbl

func cycle_option(key: String, step: int, max_count: int) -> void:
	costume[key] = (costume[key] + step + max_count) % max_count
	apply_costume()

func randomize_costume() -> void:
	costume.hat = randi() % HATS.size()
	costume.krama = randi() % KRAMAS.size()
	costume.shirt = randi() % SHIRT_COLORS.size()
	costume.pants = randi() % PANTS_COLORS.size()
	costume.skin = randi() % SKIN_COLORS.size()
	apply_costume()

func toggle_customization() -> void:
	is_customizing = not is_customizing
	custom_panel.visible = is_customizing

	if is_customizing:
		release_mouse()
		# Position camera in front of character for clear preview
		if pivot:
			pivot.rotation_degrees = Vector3(-6.0, 160.0, 0)
		if camera:
			camera.position = Vector3(0, 0.6, 2.8)
			camera.rotation_degrees.x = 0
		if visual_root:
			visual_root.visible = true
	else:
		save_costume()
		capture_mouse()
		# Reset camera to exploration view
		if pivot:
			pivot.rotation_degrees = Vector3.ZERO
		if camera:
			camera.position = Vector3(0, 0.8, 4.2)
			camera.rotation_degrees.x = -8.0

func _process(_delta: float) -> void:
	if is_customizing:
		if interaction_panel:
			interaction_panel.visible = false
		return

	# If currently riding or resting, allow dismount prompt
	if current_vehicle != null:
		if interaction_label and interaction_panel:
			if current_vehicle is CountrysideBicycle:
				interaction_label.text = "[ E ] Dismount Bicycle (ចុះពីលើកង់)  |  [ Space / F ] Ring Bell"
			elif current_vehicle is CambodianWaterBuffalo:
				interaction_label.text = "[ E ] Dismount Buffalo (ចុះពីលើក្របី)"
			elif current_vehicle is CountrysideHammock:
				interaction_label.text = "[ E ] Get Up from Hammock (ក្រោកឈរ)"
			else:
				interaction_label.text = "[ E ] Dismount / Exit"
			interaction_panel.visible = true
		return

	# Search for closest interactable in group "interactables"
	var interactables = get_tree().get_nodes_in_group("interactables")
	var nearest: Node = null
	var min_dist: float = 3.2

	for item in interactables:
		if item is Node3D and is_instance_valid(item):
			var dist = global_position.distance_to(item.global_position)
			if dist < min_dist and item.get("is_interactable") == true:
				min_dist = dist
				nearest = item

	closest_interactable = nearest

	if interaction_panel and interaction_label:
		if closest_interactable != null:
			interaction_label.text = "[ E ]  " + str(closest_interactable.get("interact_prompt"))
			interaction_panel.visible = true
		else:
			interaction_panel.visible = false


func _input(event: InputEvent) -> void:
	# Clicking anywhere in the window while in exploration mode captures the mouse
	if event is InputEventMouseButton and event.pressed:
		if not is_customizing and not is_cooking and not is_fishing and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# If user clicked on the QuickCustomizeButton, let the button handle it
			if custom_ui != null:
				var hud_btn = custom_ui.get_node_or_null("QuickCustomizeButton") as Button
				if hud_btn != null and hud_btn.visible and hud_btn.get_global_rect().has_point(event.position):
					return
			capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	# UI cancel (Escape key): close customization, close cooking, cancel fishing, or release mouse
	if event.is_action_pressed("ui_cancel"):
		if is_customizing:
			toggle_customization()
			return
		elif is_cooking:
			var stations = get_tree().get_nodes_in_group("cooking_stations")
			for st in stations:
				if st.has_method("_close_cooking_menu"):
					st._close_cooking_menu()
			is_cooking = false
			capture_mouse()
			return
		elif is_fishing:
			is_fishing = false
			if right_arm: right_arm.rotation = Vector3.ZERO
			if left_arm: left_arm.rotation = Vector3.ZERO
			return
		else:
			release_mouse()
			return

	# Photo Mode Input Handling
	if is_photo_mode:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.fov = clampf(camera.fov - 4.0, 25.0, 95.0)
				_update_photo_zoom_ui()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.fov = clampf(camera.fov + 4.0, 25.0, 95.0)
				_update_photo_zoom_ui()
				return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_P or event.is_action_pressed("ui_cancel"):
				toggle_photo_mode()
				return
			elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				take_photo_snapshot()
				return

	# C key to toggle customization menu
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle_customization()
			return
		elif event.keycode == KEY_P:
			toggle_photo_mode()
			return
		elif event.keycode == KEY_E:
			# Interact or Dismount
			if current_vehicle != null:
				dismount_vehicle()
			elif closest_interactable != null:
				closest_interactable.interact(self)
			return
		elif event.keycode == KEY_T:
			# Advance time of day
			var parent_node = get_parent()
			if parent_node and parent_node.get("day_night") != null:
				parent_node.day_night.advance_time(3.5)
			return
		elif event.keycode == KEY_R:
			# Cycle weather (Clear -> Overcast -> Monsoon Rain -> Thunderstorm)
			var parent_node = get_parent()
			if parent_node and parent_node.get("weather") != null:
				parent_node.weather.cycle_weather()
			return

	# When customizing, mouse drag spins the character
	if is_customizing:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_dragging_preview = event.pressed
		elif event is InputEventMouseMotion and is_dragging_preview:
			if visual_root:
				visual_root.rotate_y(event.relative.x * 0.01)
		return

	# Exploration mouse capture on click
	if event is InputEventMouseButton and event.pressed:
		capture_mouse()

	# Mouse look during exploration
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if pivot:
			pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-70.0), deg_to_rad(55.0))

	# V key to toggle 1st person / 3rd person view
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			is_first_person = not is_first_person
			if is_first_person:
				camera.position = Vector3(0, 0.35, -0.2)
				camera.rotation_degrees.x = 0
				if visual_root:
					visual_root.visible = false
			else:
				camera.position = Vector3(0, 0.8, 4.2)
				camera.rotation_degrees.x = -8.0
				if visual_root:
					visual_root.visible = true


func _physics_process(delta: float) -> void:
	# When customizing, cooking, or fishing, freeze movement
	if is_customizing or is_cooking or is_fishing:
		velocity = Vector3.ZERO
		if is_fishing:
			if right_arm:
				right_arm.rotation_degrees.x = -62.0
			if left_arm:
				left_arm.rotation_degrees.x = -32.0
		return

	# Handle active food buffs
	var active_buff_strings = []
	if speed_buff_timer > 0.0:
		speed_buff_timer -= delta
		active_buff_strings.append("Speed +" + str(int((speed_buff_mult - 1.0) * 100)) + "% (" + str(int(speed_buff_timer)) + "s)")
	else:
		speed_buff_mult = 1.0

	if jump_buff_timer > 0.0:
		jump_buff_timer -= delta
		active_buff_strings.append("Jump +" + str(int((jump_buff_mult - 1.0) * 100)) + "% (" + str(int(jump_buff_timer)) + "s)")
	else:
		jump_buff_mult = 1.0

	if buff_label:
		if active_buff_strings.size() > 0:
			buff_label.text = "Buff: " + " | ".join(active_buff_strings)
			buff_label.visible = true
		else:
			buff_label.visible = false

	# 1. MOUNTED ON VEHICLE OR IN HAMMOCK
	if current_vehicle != null and is_instance_valid(current_vehicle):
		velocity = Vector3.ZERO
		if vehicle_seat and is_instance_valid(vehicle_seat):
			global_position = vehicle_seat.global_position
			rotation.y = vehicle_seat.global_rotation.y

		# Vehicle specific player posing
		if current_vehicle is CountrysideBicycle:
			if left_arm and right_arm:
				left_arm.rotation_degrees.x = -55.0
				right_arm.rotation_degrees.x = -55.0
			var pedal_phase = Time.get_ticks_msec() * 0.008
			if absf(current_vehicle.current_speed) > 0.1:
				if left_leg and right_leg:
					left_leg.rotation_degrees.x = -40.0 + sin(pedal_phase) * 20.0
					right_leg.rotation_degrees.x = -40.0 - sin(pedal_phase) * 20.0
			else:
				if left_leg and right_leg:
					left_leg.rotation_degrees.x = -35.0
					right_leg.rotation_degrees.x = -35.0
		elif current_vehicle is CambodianWaterBuffalo:
			if left_leg and right_leg:
				left_leg.rotation_degrees.z = 32.0
				right_leg.rotation_degrees.z = -32.0
				left_leg.rotation_degrees.x = -22.0
				right_leg.rotation_degrees.x = -22.0
			if left_arm and right_arm:
				left_arm.rotation_degrees.x = -30.0
				right_arm.rotation_degrees.x = -30.0
		elif current_vehicle is CountrysideHammock:
			if visual_root:
				visual_root.rotation_degrees.x = -85.0
		return

	# 2. STANDARD ON-FOOT EXPLORATION
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0
		# Jump (Spacebar)
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity * jump_buff_mult

	# Sprint (Shift)
	var current_speed = move_speed * speed_buff_mult
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	if is_sprinting:
		current_speed = sprint_speed * speed_buff_mult

	# Input movement (WASD + Arrows)
	var input_x: float = 0.0
	var input_z: float = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_z += 1.0

	var move_input = Vector2(input_x, input_z).normalized()
	var direction := (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()

	if direction.length() > 0:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		# Walking animation swing
		walk_time += delta * (current_speed * 2.2)
		var swing = sin(walk_time) * 0.4
		if left_leg and right_leg:
			left_leg.rotation.x = swing
			right_leg.rotation.x = -swing
		if left_arm and right_arm:
			left_arm.rotation.x = -swing
			right_arm.rotation.x = swing

		# Footstep sound effects
		if is_on_floor():
			footstep_timer += delta * (current_speed * 0.4)
			if footstep_timer >= 1.0:
				footstep_timer = 0.0
				if global_position.y > 1.8:
					AudioSynth.play("step_wood", -9.0)
				else:
					AudioSynth.play("step_grass", -8.0)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

		# Return limbs to rest
		if left_leg: left_leg.rotation.x = move_toward(left_leg.rotation.x, 0, delta * 4.0)
		if right_leg: right_leg.rotation.x = move_toward(right_leg.rotation.x, 0, delta * 4.0)
		if left_arm: left_arm.rotation.x = move_toward(left_arm.rotation.x, 0, delta * 4.0)
		if right_arm: right_arm.rotation.x = move_toward(right_arm.rotation.x, 0, delta * 4.0)

	move_and_slide()


# -------------------------------------------------------------
# INTERACTION & INVENTORY HUD
# -------------------------------------------------------------
func create_interaction_hud() -> void:
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionBadge"
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.14, 0.9)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.82, 0.35, 0.9)
	interaction_panel.add_theme_stylebox_override("panel", style)

	interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_panel.anchor_top = 0.84
	interaction_panel.anchor_bottom = 0.90
	interaction_panel.anchor_left = 0.2
	interaction_panel.anchor_right = 0.8
	interaction_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	interaction_label = Label.new()
	interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 16)
	interaction_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	interaction_panel.add_child(interaction_label)

	custom_ui.add_child(interaction_panel)


func create_inventory_hud() -> void:
	var inv_panel = PanelContainer.new()
	inv_panel.name = "InventoryTray"
	inv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.85)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.65, 0.35, 0.6)
	inv_panel.add_theme_stylebox_override("panel", style)

	inv_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_panel.anchor_left = 0.50
	inv_panel.anchor_right = 0.98
	inv_panel.anchor_top = 0.02
	inv_panel.anchor_bottom = 0.075

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	inv_panel.add_child(hbox)

	lbl_coconuts = Label.new()
	lbl_coconuts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_coconuts.text = "Coconuts: 0"
	lbl_coconuts.add_theme_font_size_override("font_size", 15)
	lbl_coconuts.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hbox.add_child(lbl_coconuts)

	lbl_bananas = Label.new()
	lbl_bananas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bananas.text = "Bananas: 0"
	lbl_bananas.add_theme_font_size_override("font_size", 15)
	lbl_bananas.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hbox.add_child(lbl_bananas)

	lbl_lotus = Label.new()
	lbl_lotus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_lotus.text = "Lotus: 0"
	lbl_lotus.add_theme_font_size_override("font_size", 15)
	lbl_lotus.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hbox.add_child(lbl_lotus)

	lbl_fish = Label.new()
	lbl_fish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_fish.text = "Fish: 0"
	lbl_fish.add_theme_font_size_override("font_size", 15)
	lbl_fish.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hbox.add_child(lbl_fish)

	# Active Buff Display Badge
	buff_label = Label.new()
	buff_label.name = "BuffStatus"
	buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_label.text = ""
	buff_label.visible = false
	buff_label.add_theme_font_size_override("font_size", 14)
	buff_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.55))
	buff_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	buff_label.add_theme_constant_override("shadow_offset_x", 1)
	buff_label.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(buff_label)

	custom_ui.add_child(inv_panel)


func add_inventory(item: String, amount: int) -> void:
	if inventory.has(item):
		inventory[item] += amount
		update_inventory_ui()


func has_item(item: String, amount: int = 1) -> bool:
	return inventory.has(item) and inventory[item] >= amount


func remove_inventory(item: String, amount: int = 1) -> bool:
	if has_item(item, amount):
		inventory[item] -= amount
		update_inventory_ui()
		return true
	return false


func apply_food_buff(buff_name: String, duration: float, mult: float, desc: String) -> void:
	if buff_name == "speed":
		speed_buff_mult = mult
		speed_buff_timer = duration
	elif buff_name == "jump":
		jump_buff_mult = mult
		jump_buff_timer = duration
	elif buff_name == "serenity":
		speed_buff_mult = 1.30
		jump_buff_mult = 1.30
		speed_buff_timer = duration
		jump_buff_timer = duration
	elif buff_name == "strength":
		speed_buff_mult = 1.50
		jump_buff_mult = 1.50
		speed_buff_timer = duration
		jump_buff_timer = duration

	AudioSynth.play("eat", 2.0)

	if custom_ui:
		var banner = Label.new()
		banner.text = desc
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 18)
		banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		banner.add_theme_constant_override("shadow_offset_x", 1)
		banner.add_theme_constant_override("shadow_offset_y", 1)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.anchor_left = 0.2
		banner.anchor_right = 0.8
		banner.anchor_top = 0.16
		custom_ui.add_child(banner)

		var tw = custom_ui.create_tween()
		tw.tween_interval(3.2)
		tw.tween_property(banner, "modulate:a", 0.0, 1.0)
		tw.tween_callback(banner.queue_free)


func update_inventory_ui() -> void:
	if lbl_coconuts:
		lbl_coconuts.text = "Coconuts: " + str(inventory["coconut"])
	if lbl_bananas:
		lbl_bananas.text = "Bananas: " + str(inventory["banana"])
	if lbl_lotus:
		lbl_lotus.text = "Lotus: " + str(inventory["lotus"])
	if lbl_fish:
		lbl_fish.text = "Fish: " + str(inventory["fish"])


# -------------------------------------------------------------
# MOUNTING & VEHICLE HANDLERS
# -------------------------------------------------------------
func mount_bicycle(bike: Node, seat: Node3D) -> void:
	current_vehicle = bike
	vehicle_seat = seat
	if collision_node:
		collision_node.disabled = true
	if camera:
		camera.position = Vector3(0, 1.3, 5.2)


func mount_buffalo(buffalo: Node, seat: Node3D) -> void:
	current_vehicle = buffalo
	vehicle_seat = seat
	if collision_node:
		collision_node.disabled = true
	if camera:
		camera.position = Vector3(0, 1.6, 5.6)


func enter_hammock(hammock: Node, rest: Node3D) -> void:
	current_vehicle = hammock
	vehicle_seat = rest
	if collision_node:
		collision_node.disabled = true
	if visual_root:
		visual_root.rotation_degrees.x = -85.0
	if camera:
		camera.position = Vector3(0, 1.1, 3.4)
		camera.rotation_degrees.x = 12.0


func dismount_vehicle() -> void:
	var old_veh = current_vehicle
	if old_veh and old_veh.has_method("dismount"):
		old_veh.dismount()
	current_vehicle = null
	vehicle_seat = null

	if collision_node:
		collision_node.disabled = false
	if visual_root:
		visual_root.rotation_degrees = Vector3.ZERO

	# Reset limb rotations
	if left_arm: left_arm.rotation = Vector3.ZERO
	if right_arm: right_arm.rotation = Vector3.ZERO
	if left_leg: left_leg.rotation = Vector3.ZERO
	if right_leg: right_leg.rotation = Vector3.ZERO

	if camera:
		camera.position = Vector3(0, 0.8, 4.2)
		camera.rotation_degrees.x = -8.0

	# Offset player to side of vehicle on ground
	if old_veh is Node3D:
		global_position = old_veh.global_position + old_veh.transform.basis.x * 1.5
		global_position.y = maxf(global_position.y, 0.5)


# -------------------------------------------------------------
# COUNTRYSIDE PHOTO / POSTCARD MODE (THOT ROUB / ថតរូប)
# -------------------------------------------------------------
func toggle_photo_mode() -> void:
	is_photo_mode = not is_photo_mode

	if is_photo_mode:
		saved_camera_fov = camera.fov

		# Hide player customization UI
		if custom_ui:
			custom_ui.visible = false

		# Hide world HUD
		var parent_node = get_parent()
		if parent_node:
			var hud = parent_node.get_node_or_null("HUD")
			if hud:
				hud.visible = false

		_create_photo_postcard_overlay()
	else:
		if photo_ui:
			photo_ui.queue_free()
			photo_ui = null

		if custom_ui:
			custom_ui.visible = true

		var parent_node = get_parent()
		if parent_node:
			var hud = parent_node.get_node_or_null("HUD")
			if hud:
				hud.visible = true

		if camera:
			camera.fov = saved_camera_fov


func _create_photo_postcard_overlay() -> void:
	if photo_ui:
		photo_ui.queue_free()

	photo_ui = CanvasLayer.new()
	photo_ui.name = "PhotoPostcardOverlay"
	add_child(photo_ui)

	# Golden Postcard Inset Border
	var border := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.92, 0.78, 0.45, 0.85) # Royal gold border
	style.set_corner_radius_all(12)
	border.add_theme_stylebox_override("panel", style)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.anchor_left = 0.03
	border.anchor_right = 0.97
	border.anchor_top = 0.04
	border.anchor_bottom = 0.96
	photo_ui.add_child(border)

	# Top Center: Postcard Header
	var title_vbox := VBoxContainer.new()
	title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_vbox.anchor_left = 0.2
	title_vbox.anchor_right = 0.8
	title_vbox.anchor_top = 0.06
	photo_ui.add_child(title_vbox)

	var title := Label.new()
	title.text = "GREETINGS FROM CAMBO COUNTRYSIDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "អនុស្សាវរីយ៍ស្រុកស្រែខ្មែរ"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.88, 0.75))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title_vbox.add_child(subtitle)

	# Top Right: Postcard Stamp
	var stamp := PanelContainer.new()
	var stamp_style := StyleBoxFlat.new()
	stamp_style.bg_color = Color(0.18, 0.16, 0.14, 0.85)
	stamp_style.border_width_left = 1
	stamp_style.border_width_top = 1
	stamp_style.border_width_right = 1
	stamp_style.border_width_bottom = 1
	stamp_style.border_color = Color(0.9, 0.7, 0.35, 0.9)
	stamp_style.set_content_margin_all(8)
	stamp.add_theme_stylebox_override("panel", stamp_style)
	stamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stamp.anchor_left = 0.86
	stamp.anchor_right = 0.95
	stamp.anchor_top = 0.06
	stamp.anchor_bottom = 0.14
	photo_ui.add_child(stamp)

	var stamp_lbl := Label.new()
	stamp_lbl.text = "POST\n1500 R"
	stamp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_lbl.add_theme_font_size_override("font_size", 12)
	stamp_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	stamp.add_child(stamp_lbl)

	# Bottom Center: Instruction & Zoom Bar
	photo_zoom_label = Label.new()
	photo_zoom_label.name = "PhotoControlsLabel"
	photo_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	photo_zoom_label.add_theme_font_size_override("font_size", 14)
	photo_zoom_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	photo_zoom_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	photo_zoom_label.add_theme_constant_override("shadow_offset_x", 1)
	photo_zoom_label.add_theme_constant_override("shadow_offset_y", 1)
	photo_zoom_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	photo_zoom_label.anchor_left = 0.15
	photo_zoom_label.anchor_right = 0.85
	photo_zoom_label.anchor_bottom = 0.93
	photo_ui.add_child(photo_zoom_label)

	_update_photo_zoom_ui()


func _update_photo_zoom_ui() -> void:
	if photo_zoom_label:
		photo_zoom_label.text = "[ Space / Enter ] Snap Postcard | [ Mouse Wheel ] Zoom: %d deg | [ P / Esc ] Exit Photo Mode" % int(camera.fov)


func take_photo_snapshot() -> void:
	AudioSynth.play("shutter", 3.0)

	if not photo_ui:
		return

	# Camera flash effect
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.88)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo_ui.add_child(flash)

	var tw = photo_ui.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

	# Snapshot confirmation toast
	var toast := Label.new()
	toast.text = "Postcard Snapshot Captured! (បានថតរូបអនុស្សាវរីយ៍)"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color(0.65, 1.0, 0.55))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 1)
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.anchor_left = 0.2
	toast.anchor_right = 0.8
	toast.anchor_top = 0.45
	photo_ui.add_child(toast)

	var t_tw = photo_ui.create_tween()
	t_tw.tween_interval(2.5)
	t_tw.tween_property(toast, "modulate:a", 0.0, 0.8)
	t_tw.tween_callback(toast.queue_free)
