extends Node3D
class_name HarvestableItem

const AudioSynth = preload("res://scripts/audio_synth.gd")

enum ItemType { COCONUT, BANANA, LOTUS }

@export var item_type: ItemType = ItemType.COCONUT
@export var respawn_time: float = 20.0

var is_available: bool = true
var respawn_timer: float = 0.0

var visual_node: Node3D
var is_interactable: bool = true
var interact_prompt: String = "Harvest Item"

func _ready() -> void:
	add_to_group("interactables")
	_build_item_mesh()
	
	match item_type:
		ItemType.COCONUT:
			interact_prompt = "Pick Coconut (បេះផ្លែដូង)"
		ItemType.BANANA:
			interact_prompt = "Harvest Bananas (បេះចេក)"
		ItemType.LOTUS:
			interact_prompt = "Pick Sacred Lotus (បេះផ្កាឈូក)"


func interact(player: Node) -> void:
	if not is_available:
		return
		
	is_available = false
	is_interactable = false
	respawn_timer = respawn_time
	visual_node.visible = false
	
	AudioSynth.play("pickup", -2.0)
	
	var item_name = ""
	match item_type:
		ItemType.COCONUT:
			item_name = "Fresh Coconut"
			if player.has_method("add_inventory"):
				player.add_inventory("coconut", 1)
		ItemType.BANANA:
			item_name = "Sweet Bananas"
			if player.has_method("add_inventory"):
				player.add_inventory("banana", 1)
		ItemType.LOTUS:
			item_name = "Sacred Lotus"
			if player.has_method("add_inventory"):
				player.add_inventory("lotus", 1)
				
	# Floating notification label
	var label = Label3D.new()
	label.text = "+1 " + item_name
	label.font_size = 36
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = global_position + Vector3(0, 0.8, 0)
	get_parent().add_child(label)
	
	var tw = create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.2, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)


func _process(delta: float) -> void:
	if not is_available:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			is_available = true
			is_interactable = true
			visual_node.visible = true
			# Pop-in bounce animation
			visual_node.scale = Vector3.ZERO
			var tw = create_tween()
			tw.tween_property(visual_node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Gentle idle float/bob
		visual_node.position.y = sin(Time.get_ticks_msec() * 0.003 + global_position.x) * 0.05
		visual_node.rotate_y(delta * 0.8)


func _build_item_mesh() -> void:
	visual_node = Node3D.new()
	visual_node.name = "ItemVisual"
	add_child(visual_node)
	
	match item_type:
		ItemType.COCONUT:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.42, 0.28, 0.16) # Brown ripe coconut
			mat.roughness = 0.95
			
			var mesh = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.5
			mesh.mesh = sm
			mesh.material_override = mat
			visual_node.add_child(mesh)
			
		ItemType.BANANA:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.96, 0.84, 0.20) # Bright yellow banana bunch
			
			# Cluster of 4 curved bananas
			for i in range(4):
				var b = MeshInstance3D.new()
				var bm = CylinderMesh.new()
				bm.top_radius = 0.04
				bm.bottom_radius = 0.05
				bm.height = 0.36
				b.mesh = bm
				b.material_override = mat
				b.position = Vector3(cos(i * PI * 0.5) * 0.12, 0, sin(i * PI * 0.5) * 0.12)
				b.rotation_degrees = Vector3(15.0, i * 90.0, 0)
				visual_node.add_child(b)
				
		ItemType.LOTUS:
			# Lily pad leaf
			var mat_pad = StandardMaterial3D.new()
			mat_pad.albedo_color = Color(0.18, 0.52, 0.24)
			mat_pad.roughness = 0.4
			
			var pad = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.45
			pm.bottom_radius = 0.45
			pm.height = 0.02
			pad.mesh = pm
			pad.material_override = mat_pad
			visual_node.add_child(pad)
			
			# Pink lotus flower
			var mat_petal = StandardMaterial3D.new()
			mat_petal.albedo_color = Color(0.96, 0.52, 0.72) # Pink sacred lotus
			
			var flower = MeshInstance3D.new()
			var fm = SphereMesh.new()
			fm.radius = 0.16
			fm.height = 0.24
			flower.mesh = fm
			flower.material_override = mat_petal
			flower.position = Vector3(0, 0.14, 0)
			visual_node.add_child(flower)
