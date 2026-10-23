extends StaticBody3D
class_name CountrysideFishingSpot

const AudioSynth = preload("res://scripts/audio_synth.gd")

enum State {
	IDLE,
	CASTING,
	WAITING,
	BITE,
	REELING
}

var is_interactable: bool = true
var interact_prompt: String = "Fish with Bamboo Rod (ស្ទូចត្រី) [E]"

var fishing_state: State = State.IDLE
var player_ref: Node = null

var bite_timer: float = 0.0
var bite_window: float = 0.0
var anim_time: float = 0.0

# Visual nodes
var stand_mesh: MeshInstance3D
var rod_pivot: Node3D
var rod_mesh: MeshInstance3D
var bobber: Node3D
var bobber_sphere: MeshInstance3D
var ripple_ring: MeshInstance3D
var line_mesh: MeshInstance3D
var hint_label_3d: Label3D

var water_target_pos: Vector3 = Vector3(0, 0.05, 3.8)
var bobber_rest_pos: Vector3 = Vector3(0.15, 0.85, 1.4)
var water_level_y: float = 0.04

const FISH_SPECIES = [
	{"name": "Walking Catfish (ត្រីអណ្តែង)", "weight": "1.2 kg"},
	{"name": "Giant Gourami (ត្រីកំភ្លាញ)", "weight": "0.9 kg"},
	{"name": "Striped Snakehead (ត្រីរ៉ស់)", "weight": "1.5 kg"}
]

func _ready() -> void:
	add_to_group("interactables")
	_build_visuals()


func _build_visuals() -> void:
	# 1. Wooden Dock Post / Stand in ground
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.10
	post_mesh.bottom_radius = 0.12
	post_mesh.height = 1.1
	stand_mesh = MeshInstance3D.new()
	stand_mesh.mesh = post_mesh
	stand_mesh.position = Vector3(0, 0.55, 0)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.25, 0.16)
	wood_mat.roughness = 0.9
	stand_mesh.material_override = wood_mat
	add_child(stand_mesh)

	# Cross plank / rod rest
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(0.5, 0.08, 0.18)
	var plank := MeshInstance3D.new()
	plank.mesh = plank_mesh
	plank.position = Vector3(0, 1.05, 0)
	plank.material_override = wood_mat
	add_child(plank)

	# 2. Slanted Bamboo Fishing Rod (approx 3.2m long)
	rod_pivot = Node3D.new()
	rod_pivot.name = "RodPivot"
	rod_pivot.position = Vector3(0, 1.05, 0)
	add_child(rod_pivot)

	var rod_cyl := CylinderMesh.new()
	rod_cyl.top_radius = 0.015
	rod_cyl.bottom_radius = 0.038
	rod_cyl.height = 3.2
	rod_mesh = MeshInstance3D.new()
	rod_mesh.mesh = rod_cyl
	# Slant rod forward pointing toward water
	rod_mesh.position = Vector3(0, 0.8, 1.2)
	rod_mesh.rotation_degrees.x = 42.0
	var bamboo_mat := StandardMaterial3D.new()
	bamboo_mat.albedo_color = Color(0.78, 0.65, 0.32) # Sun-cured golden bamboo
	bamboo_mat.roughness = 0.75
	rod_mesh.material_override = bamboo_mat
	rod_pivot.add_child(rod_mesh)

	# 3. Bobber (Cork float with red top and white bottom)
	bobber = Node3D.new()
	bobber.name = "Bobber"
	bobber.position = bobber_rest_pos
	add_child(bobber)

	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.08
	s_mesh.height = 0.16
	bobber_sphere = MeshInstance3D.new()
	bobber_sphere.mesh = s_mesh
	var bobber_mat := StandardMaterial3D.new()
	bobber_mat.albedo_color = Color(0.92, 0.22, 0.18) # Red fishing float
	bobber_mat.roughness = 0.4
	bobber_sphere.material_override = bobber_mat
	bobber.add_child(bobber_sphere)

	# Water ripple ring around bobber
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.12
	ring_mesh.outer_radius = 0.24
	ripple_ring = MeshInstance3D.new()
	ripple_ring.mesh = ring_mesh
	ripple_ring.position = Vector3(0, -0.04, 0)
	ripple_ring.rotation_degrees.x = 90.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.roughness = 0.2
	ripple_ring.material_override = ring_mat
	ripple_ring.visible = false
	bobber.add_child(ripple_ring)

	# 4. Floating 3D status hint label above water
	hint_label_3d = Label3D.new()
	hint_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_label_3d.font_size = 28
	hint_label_3d.outline_size = 8
	hint_label_3d.modulate = Color(1.0, 0.92, 0.45)
	hint_label_3d.position = water_target_pos + Vector3(0, 0.8, 0)
	hint_label_3d.visible = false
	add_child(hint_label_3d)

	# 5. Collision box for interaction detection
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.8, 1.6)
	col.shape = box
	col.position = Vector3(0, 0.8, 0)
	add_child(col)


func interact(player: Node) -> void:
	if fishing_state == State.IDLE:
		_start_fishing(player)
	elif fishing_state == State.BITE:
		_catch_fish()
	elif fishing_state == State.WAITING:
		# Reel in too early!
		_early_pull()


func _start_fishing(player: Node) -> void:
	if not player:
		return
	if "is_customizing" in player and player.is_customizing:
		return
	if "is_cooking" in player and player.is_cooking:
		return

	player_ref = player
	if "is_fishing" in player_ref:
		player_ref.is_fishing = true

	fishing_state = State.CASTING
	anim_time = 0.0

	# Swish cast sound
	AudioSynth.play("cast", 2.2)

	# Animate rod swish
	var tw = create_tween()
	tw.tween_property(rod_pivot, "rotation_degrees:x", -25.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rod_pivot, "rotation_degrees:x", 12.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rod_pivot, "rotation_degrees:x", 0.0, 0.20)

	# Animate bobber landing into water target
	var b_tw = create_tween()
	b_tw.tween_property(bobber, "position", water_target_pos + Vector3(0, 1.2, 0), 0.2)
	b_tw.tween_property(bobber, "position", water_target_pos, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	b_tw.tween_callback(func():
		AudioSynth.play("splash", 1.8)
		if ripple_ring:
			ripple_ring.visible = true
		fishing_state = State.WAITING
		bite_timer = randf_range(3.2, 6.0)
		_show_hint("Waiting for a bite... (រង់ចាំត្រីស៊ី)", Color(0.9, 0.9, 0.9))
	)


func _process(delta: float) -> void:
	anim_time += delta

	# Check player distance or cancellation
	if player_ref != null and is_instance_valid(player_ref):
		var dist = global_position.distance_to(player_ref.global_position)
		if dist > 3.5:
			_cancel_fishing("Moved too far! Fishing cancelled.")
			return
		if "is_fishing" in player_ref and not player_ref.is_fishing:
			_cancel_fishing("")
			return

	match fishing_state:
		State.WAITING:
			# Gentle water bobbing
			bobber.position.y = water_level_y + sin(anim_time * 3.5) * 0.02
			if ripple_ring:
				ripple_ring.scale = Vector3.ONE * (0.8 + sin(anim_time * 4.0) * 0.2)

			bite_timer -= delta
			if bite_timer <= 0.0:
				_trigger_bite()

		State.BITE:
			# Plunged down and shaking
			bobber.position.y = water_level_y - 0.14 + sin(anim_time * 26.0) * 0.04
			if ripple_ring:
				ripple_ring.scale = Vector3.ONE * (1.3 + sin(anim_time * 26.0) * 0.4)

			# Pulsing alert hint
			hint_label_3d.modulate = Color(1.0, 0.2, 0.2) if int(anim_time * 8.0) % 2 == 0 else Color(1.0, 0.9, 0.2)

			# Keyboard space or E triggers reel
			if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
				_catch_fish()
				return

			bite_window -= delta
			if bite_window <= 0.0:
				_fish_escaped()


func _trigger_bite() -> void:
	fishing_state = State.BITE
	bite_window = 2.4 # 2.4s reaction window
	AudioSynth.play("splash", 2.5)
	_show_hint("[ Space / E ] REEL IN! (ទាញឡើង!)", Color(1.0, 0.3, 0.2), 36)


func _early_pull() -> void:
	_show_hint("Pulled too early! No bite yet. (ទាញលឿនពេក)", Color(1.0, 0.6, 0.4))
	_cancel_fishing("")


func _catch_fish() -> void:
	fishing_state = State.REELING
	AudioSynth.play("splash", 2.2)
	AudioSynth.play("pickup", 2.2)

	var fish = FISH_SPECIES.pick_random()

	# Give to player inventory
	if player_ref and player_ref.has_method("add_inventory"):
		player_ref.add_inventory("fish", 1)

	# Success banner
	var catch_msg = "+1 Fresh Fish! Caught " + fish.name + " (" + fish.weight + ")"
	_show_hint(catch_msg, Color(0.5, 1.0, 0.4), 32)

	if player_ref and "custom_ui" in player_ref and player_ref.custom_ui:
		var banner = Label.new()
		banner.text = catch_msg
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 18)
		banner.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
		banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		banner.add_theme_constant_override("shadow_offset_x", 1)
		banner.add_theme_constant_override("shadow_offset_y", 1)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.anchor_left = 0.2
		banner.anchor_right = 0.8
		banner.anchor_top = 0.16
		player_ref.custom_ui.add_child(banner)

		var tw = player_ref.custom_ui.create_tween()
		tw.tween_interval(3.5)
		tw.tween_property(banner, "modulate:a", 0.0, 0.8)
		tw.tween_callback(banner.queue_free)

	# Reset after small delay
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		_reset_to_idle()
	)


func _fish_escaped() -> void:
	fishing_state = State.REELING
	_show_hint("The fish got away! (ត្រីរបូតបាត់ហើយ)", Color(1.0, 0.4, 0.3))
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		_reset_to_idle()
	)


func _cancel_fishing(reason: String) -> void:
	if reason != "":
		_show_hint(reason, Color(1.0, 0.8, 0.4))
	_reset_to_idle()


func _reset_to_idle() -> void:
	if player_ref:
		if "is_fishing" in player_ref:
			player_ref.is_fishing = false
		player_ref = null

	fishing_state = State.IDLE
	bobber.position = bobber_rest_pos
	rod_pivot.rotation_degrees = Vector3.ZERO
	if ripple_ring:
		ripple_ring.visible = false

	# Hide hint after short fade
	if hint_label_3d:
		var tw = create_tween()
		tw.tween_property(hint_label_3d, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func():
			hint_label_3d.visible = false
			hint_label_3d.modulate.a = 1.0
		)


func _show_hint(text: String, col: Color, font_sz: int = 28) -> void:
	if not hint_label_3d:
		return
	hint_label_3d.text = text
	hint_label_3d.modulate = col
	hint_label_3d.font_size = font_sz
	hint_label_3d.visible = true
