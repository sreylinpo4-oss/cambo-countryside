extends StaticBody3D
class_name CountrysideSignpost

@export var sign_title: String = "Village Crossroads"
@export var sign_khmer: String = "ផ្លូវបំបែកភូមិ"
@export var sign_directions: Array = [
	"<- Stilt House (ផ្ទះខ្មែរ) | Lotus Pond (បឹងឈូក)",
	"Rice Paddies (វាលស្រែ) -> | Pasture (វាលស្មៅ)"
]

var is_interactable: bool = true
var interact_prompt: String = "Read Signpost (អានស្លាកផ្លូវ)"

func _ready() -> void:
	add_to_group("interactables")
	_build_signpost_mesh()


func _build_signpost_mesh() -> void:
	# 1. Main vertical wooden post
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 2.1
	post.mesh = post_mesh
	post.position = Vector3(0, 1.05, 0)

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.38, 0.25, 0.16)
	mat_wood.roughness = 0.88
	post.material_override = mat_wood
	add_child(post)

	# 2. Collision Shape
	var col := CollisionShape3D.new()
	var col_shape := CylinderShape3D.new()
	col_shape.height = 2.1
	col_shape.radius = 0.25
	col.shape = col_shape
	col.position = Vector3(0, 1.05, 0)
	add_child(col)

	# 3. Wooden Direction Boards
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.55, 0.38, 0.24)
	plank_mat.roughness = 0.82

	for i in range(sign_directions.size()):
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(1.6, 0.26, 0.07)
		board.mesh = board_mesh
		var y_pos = 1.75 - i * 0.35
		board.position = Vector3(0, y_pos, 0.06 * (1 if i % 2 == 0 else -1))
		board.rotation_degrees.y = 10.0 if i % 2 == 0 else -15.0
		board.material_override = plank_mat
		add_child(board)

		# 3D Text on board
		var label := Label3D.new()
		label.text = sign_directions[i]
		label.font_size = 20
		label.outline_size = 4
		label.modulate = Color(1.0, 0.95, 0.8)
		label.position = Vector3(0, 0, 0.045)
		board.add_child(label)


func interact(player: Node) -> void:
	AudioSynth.play("pickup", -4.0, 0.85)

	# Show floating banner for 3.5 seconds
	var banner = Label3D.new()
	var lines_str = "\n".join(sign_directions)
	banner.text = sign_title + " (" + sign_khmer + ")\n" + lines_str
	banner.font_size = 32
	banner.outline_size = 6
	banner.outline_modulate = Color(0, 0, 0, 0.9)
	banner.modulate = Color(1.0, 0.92, 0.65)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.position = global_position + Vector3(0, 2.5, 0)
	get_parent().add_child(banner)

	var tw = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(banner, "modulate:a", 0.0, 1.0)
	tw.tween_callback(banner.queue_free)
