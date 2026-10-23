extends StaticBody3D
class_name CountrysideRoneatEk

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Traditional Cambodian Roneat Ek (រនាតឯក - Bamboo Xylophone)
var is_interactable: bool = true
var interact_prompt: String = "Play Roneat Ek Xylophone (លេងរនាតឯក) [E]"

var trough_mesh: MeshInstance3D
var bamboo_bars: Array[MeshInstance3D] = []
var mallet_l: Node3D
var mallet_r: Node3D
var play_index: int = 0

func _ready() -> void:
	add_to_group("interactables")
	_build_roneat_model()


func _build_roneat_model() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.22, 0.12) # Deep teakwood boat body
	wood_mat.roughness = 0.75

	var bamboo_mat := StandardMaterial3D.new()
	bamboo_mat.albedo_color = Color(0.84, 0.70, 0.38) # Honey bamboo keys
	bamboo_mat.roughness = 0.65

	var mallet_mat := StandardMaterial3D.new()
	mallet_mat.albedo_color = Color(0.92, 0.88, 0.80) # Felt padded mallet heads

	# 1. Boat-shaped Resonating Base (Sna)
	# Center base block
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.2, 0.22, 0.45)
	trough_mesh = MeshInstance3D.new()
	trough_mesh.mesh = base_mesh
	trough_mesh.position = Vector3(0, 0.15, 0)
	trough_mesh.material_override = wood_mat
	add_child(trough_mesh)

	# Curved upward boat ends (prow & stern)
	for side in [-1.0, 1.0]:
		var end_mesh := BoxMesh.new()
		end_mesh.size = Vector3(0.24, 0.36, 0.42)
		var end_inst := MeshInstance3D.new()
		end_inst.mesh = end_mesh
		end_inst.position = Vector3(side * 0.65, 0.26, 0)
		end_inst.rotation_degrees.z = side * -25.0
		end_inst.material_override = wood_mat
		add_child(end_inst)

	# Support pedestal stand
	var stand_mesh := CylinderMesh.new()
	stand_mesh.top_radius = 0.18
	stand_mesh.bottom_radius = 0.24
	stand_mesh.height = 0.20
	var stand := MeshInstance3D.new()
	stand.mesh = stand_mesh
	stand.position = Vector3(0, 0.08, 0)
	stand.material_override = wood_mat
	add_child(stand)

	# 2. Suspended Bamboo Keys (14 tuned bars)
	for i in range(14):
		var ratio = float(i) / 13.0
		var key_len = lerpf(0.52, 0.34, ratio) # Lower notes are longer
		var key_x = lerpf(-0.55, 0.55, ratio)
		var key_y = 0.30 - sin(ratio * PI) * 0.05 # Suspended catenary curve

		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.065, 0.024, key_len)
		var bar_inst := MeshInstance3D.new()
		bar_inst.mesh = bar_mesh
		bar_inst.position = Vector3(key_x, key_y, 0)
		bar_inst.material_override = bamboo_mat
		add_child(bar_inst)
		bamboo_bars.append(bar_inst)

	# 3. Two Padded Mallets (Mekhlok)
	mallet_l = _create_mallet(Vector3(-0.15, 0.35, 0.22), wood_mat, mallet_mat)
	mallet_r = _create_mallet(Vector3(0.15, 0.35, 0.22), wood_mat, mallet_mat)
	add_child(mallet_l)
	add_child(mallet_r)

	# 4. Collision box for player interaction
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.8, 0.8)
	col.shape = box
	col.position = Vector3(0, 0.35, 0)
	add_child(col)


func _create_mallet(pos: Vector3, stick_mat: Material, head_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos

	# Stick
	var s_mesh := CylinderMesh.new()
	s_mesh.top_radius = 0.012
	s_mesh.bottom_radius = 0.012
	s_mesh.height = 0.36
	var stick := MeshInstance3D.new()
	stick.mesh = s_mesh
	stick.position = Vector3(0, 0, -0.15)
	stick.rotation_degrees.x = 90.0
	stick.material_override = stick_mat
	root.add_child(stick)

	# Padded disk head
	var h_mesh := CylinderMesh.new()
	h_mesh.top_radius = 0.04
	h_mesh.bottom_radius = 0.04
	h_mesh.height = 0.03
	var head := MeshInstance3D.new()
	head.mesh = h_mesh
	head.position = Vector3(0, 0, -0.32)
	head.material_override = head_mat
	root.add_child(head)

	return root


func interact(player: Node) -> void:
	play_index = (play_index + 1) % 3
	var sound_keys = ["roneat_low", "roneat_mid", "roneat_high"]
	AudioSynth.play(sound_keys[play_index], 2.0)

	# Also toggle background folk melody
	var is_playing = AudioSynth.toggle_folk_music()

	# Animate striking mallets
	var active_mallet = mallet_l if play_index % 2 == 0 else mallet_r
	if active_mallet:
		var tw = create_tween()
		tw.tween_property(active_mallet, "rotation_degrees:x", -25.0, 0.08)
		tw.tween_property(active_mallet, "rotation_degrees:x", 0.0, 0.12)

	# Animate struck bamboo key
	var key_idx = int(lerpf(2, 12, float(play_index) / 2.0))
	if key_idx < bamboo_bars.size():
		var key = bamboo_bars[key_idx]
		var orig_y = key.position.y
		var k_tw = create_tween()
		k_tw.tween_property(key, "position:y", orig_y - 0.02, 0.05)
		k_tw.tween_property(key, "position:y", orig_y, 0.15)

	# Floating notification
	var banner_text = "Playing Roneat Ek Folk Melody (រនាតឯក) [M to Stop]" if is_playing else "Played Roneat Strike (រនាតឯក)"
	_show_floating_text(banner_text)

	# Grant player Inspired Harmony Serenity buff
	if player and player.has_method("apply_food_buff"):
		player.apply_food_buff("serenity", 60.0, 1.25, "Inspired Harmony! Speed & Jump +25% (60s)")


func _show_floating_text(msg: String) -> void:
	var label = Label3D.new()
	label.text = msg
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.65)
	label.position = Vector3(0, 0.85, 0)
	add_child(label)

	var tw = create_tween()
	tw.tween_property(label, "position:y", 1.6, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)
