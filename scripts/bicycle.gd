extends CharacterBody3D
class_name CountrysideBicycle

const AudioSynth = preload("res://scripts/audio_synth.gd")

# Authentic Cambodian Countryside Roadster Bicycle (កង់ស្រុកស្រែ)
@export var max_speed: float = 14.0
@export var acceleration: float = 8.0
@export var braking: float = 12.0
@export var turn_speed: float = 2.4

var current_speed: float = 0.0
var rider: Node = null
var is_ridden: bool = false

# Visual nodes
var visual_root: Node3D
var front_fork: Node3D
var front_wheel: MeshInstance3D
var rear_wheel: MeshInstance3D
var pedal_crank: Node3D
var kickstand: MeshInstance3D
var rider_seat: Node3D
var basket_mesh: MeshInstance3D

var wheel_spin: float = 0.0
var steer_angle: float = 0.0
var lean_angle: float = 0.0

var is_interactable: bool = true
var interact_prompt: String = "Ride Bicycle (ជិះកង់)"

func _ready() -> void:
	add_to_group("interactables")
	_build_bicycle_mesh()
	
	# Solid collision
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.6, 1.2, 1.9)
	col.shape = box
	col.position.y = 0.6
	add_child(col)


func interact(player: Node) -> void:
	if not is_ridden:
		mount(player)
	else:
		dismount()


func mount(player: Node) -> void:
	rider = player
	is_ridden = true
	interact_prompt = "Dismount Bicycle (ចុះពីលើកង់)"
	kickstand.rotation_degrees.z = 0.0 # kickstand up
	AudioSynth.play("bell", -2.0)
	
	if player.has_method("mount_bicycle"):
		player.mount_bicycle(self, rider_seat)


func dismount() -> void:
	if rider and rider.has_method("dismount_vehicle"):
		rider.dismount_vehicle()
	rider = null
	is_ridden = false
	current_speed = 0.0
	interact_prompt = "Ride Bicycle (ជិះកង់)"
	kickstand.rotation_degrees.z = -28.0 # kickstand down
	visual_root.rotation_degrees.z = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if is_ridden:
		# Ring bell with Space or F
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_F):
			ring_bell()


func ring_bell() -> void:
	AudioSynth.play("bell", -1.0, randf_range(0.98, 1.02))
	# Floating bell label
	var label = Label3D.new()
	label.text = "Ring-Ring!"
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.4, 0.4)
	add_child(label)
	
	var tw = create_tween()
	tw.tween_property(label, "position:y", 2.2, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = 0.0

	if is_ridden and rider != null:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# Throttle forward / back
		if input_dir.y < -0.1: # Forward (W)
			current_speed = move_toward(current_speed, max_speed, acceleration * delta)
		elif input_dir.y > 0.1: # Brake / Reverse (S)
			current_speed = move_toward(current_speed, -max_speed * 0.35, braking * delta)
		else:
			# Coasting
			current_speed = move_toward(current_speed, 0.0, 2.5 * delta)
			
		# Steering (A / D)
		var target_steer = -input_dir.x * 0.65
		steer_angle = lerp(steer_angle, target_steer, delta * 8.0)
		
		if absf(current_speed) > 0.2:
			# Steer bicycle yaw
			var turn_factor = (current_speed / max_speed)
			rotate_y(steer_angle * turn_speed * delta * signf(current_speed))
			
			# Lean bike into turns
			var target_lean = -steer_angle * clampf(absf(current_speed) / 6.0, 0.0, 1.0) * 18.0
			lean_angle = lerp(lean_angle, target_lean, delta * 6.0)
		else:
			lean_angle = lerp(lean_angle, 0.0, delta * 6.0)
			
		visual_root.rotation_degrees.z = lean_angle
		front_fork.rotation_degrees.y = rad_to_deg(steer_angle)
		
		# Move velocity
		var forward = -transform.basis.z * current_speed
		velocity.x = forward.x
		velocity.z = forward.z
		
		# Wheel and pedal rotations
		wheel_spin += (current_speed / 0.38) * delta
		front_wheel.rotation_degrees.x = rad_to_deg(wheel_spin)
		rear_wheel.rotation_degrees.x = rad_to_deg(wheel_spin)
		pedal_crank.rotation_degrees.x = rad_to_deg(wheel_spin * 0.8)
	else:
		# Parked
		current_speed = 0.0
		velocity.x = move_toward(velocity.x, 0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, delta * 8.0)
		steer_angle = lerp(steer_angle, 0.0, delta * 4.0)
		front_fork.rotation_degrees.y = 0.0
		visual_root.rotation_degrees.z = 0.0
		
	move_and_slide()


func _build_bicycle_mesh() -> void:
	visual_root = Node3D.new()
	visual_root.name = "BikeVisual"
	add_child(visual_root)
	
	# Materials
	var mat_frame = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.18, 0.38, 0.24) # Vintage Khmer forest green
	mat_frame.metallic = 0.4
	mat_frame.roughness = 0.45
	
	var mat_chrome = StandardMaterial3D.new()
	mat_chrome.albedo_color = Color(0.85, 0.86, 0.88) # Chrome steel
	mat_chrome.metallic = 0.85
	mat_chrome.roughness = 0.2
	
	var mat_tire = StandardMaterial3D.new()
	mat_tire.albedo_color = Color(0.15, 0.15, 0.16) # Rubber black
	mat_tire.roughness = 0.95
	
	var mat_leather = StandardMaterial3D.new()
	mat_leather.albedo_color = Color(0.28, 0.18, 0.12) # Brown leather seat
	
	var mat_basket = StandardMaterial3D.new()
	mat_basket.albedo_color = Color(0.72, 0.60, 0.42) # Woven bamboo basket
	mat_basket.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Seat mount node for rider
	rider_seat = Node3D.new()
	rider_seat.name = "RiderSeat"
	rider_seat.position = Vector3(0, 0.95, -0.22)
	visual_root.add_child(rider_seat)
	
	# --- Rear Wheel (at z = -0.65) ---
	var rw_mount = Node3D.new()
	rw_mount.position = Vector3(0, 0.38, -0.65)
	visual_root.add_child(rw_mount)
	
	rear_wheel = MeshInstance3D.new()
	var wm = TorusMesh.new()
	wm.inner_radius = 0.32
	wm.outer_radius = 0.38
	rear_wheel.mesh = wm
	rear_wheel.material_override = mat_tire
	rear_wheel.rotation_degrees.z = 90.0
	rw_mount.add_child(rear_wheel)
	
	# Rear Hub & Rim
	var r_hub = MeshInstance3D.new()
	var hm = CylinderMesh.new()
	hm.top_radius = 0.05
	hm.bottom_radius = 0.05
	hm.height = 0.12
	r_hub.mesh = hm
	r_hub.material_override = mat_chrome
	r_hub.rotation_degrees.z = 90.0
	rw_mount.add_child(r_hub)
	
	# --- Front Fork & Steer Assembly (at z = 0.65) ---
	front_fork = Node3D.new()
	front_fork.position = Vector3(0, 0.82, 0.55)
	visual_root.add_child(front_fork)
	
	# Handlebars
	var handlebar = MeshInstance3D.new()
	var hbm = BoxMesh.new()
	hbm.size = Vector3(0.68, 0.04, 0.04)
	handlebar.mesh = hbm
	handlebar.material_override = mat_chrome
	handlebar.position = Vector3(0, 0.22, 0.04)
	front_fork.add_child(handlebar)
	
	# Grips
	for side in [-1.0, 1.0]:
		var grip = MeshInstance3D.new()
		var gm = BoxMesh.new()
		gm.size = Vector3(0.12, 0.06, 0.06)
		grip.mesh = gm
		grip.material_override = mat_tire
		grip.position = Vector3(side * 0.28, 0.22, 0.04)
		front_fork.add_child(grip)
		
	# Front Basket
	basket_mesh = MeshInstance3D.new()
	var bkm = BoxMesh.new()
	bkm.size = Vector3(0.38, 0.22, 0.26)
	basket_mesh.mesh = bkm
	basket_mesh.material_override = mat_basket
	basket_mesh.position = Vector3(0, 0.15, 0.22)
	front_fork.add_child(basket_mesh)
	
	# Fork Blades down to front axle
	for side in [-1.0, 1.0]:
		var blade = MeshInstance3D.new()
		var blm = CylinderMesh.new()
		blm.top_radius = 0.02
		blm.bottom_radius = 0.02
		blm.height = 0.52
		blade.mesh = blm
		blade.material_override = mat_frame
		blade.position = Vector3(side * 0.08, -0.22, 0.05)
		blade.rotation_degrees.x = -14.0
		front_fork.add_child(blade)
		
	# Front Wheel
	front_wheel = MeshInstance3D.new()
	front_wheel.mesh = wm
	front_wheel.material_override = mat_tire
	front_wheel.position = Vector3(0, -0.44, 0.1)
	front_wheel.rotation_degrees.z = 90.0
	front_fork.add_child(front_wheel)
	
	# --- Diamond Frame Tubes ---
	# Bottom bracket (pedal center) at (0, 0.38, -0.05)
	pedal_crank = Node3D.new()
	pedal_crank.position = Vector3(0, 0.38, -0.05)
	visual_root.add_child(pedal_crank)
	
	# Pedals
	for side in [-1.0, 1.0]:
		var crank_arm = MeshInstance3D.new()
		var cam = BoxMesh.new()
		cam.size = Vector3(0.03, 0.18, 0.03)
		crank_arm.mesh = cam
		crank_arm.material_override = mat_chrome
		crank_arm.position = Vector3(side * 0.12, side * 0.09, 0)
		pedal_crank.add_child(crank_arm)
		
		var pedal = MeshInstance3D.new()
		var pdm = BoxMesh.new()
		pdm.size = Vector3(0.09, 0.03, 0.1)
		pedal.mesh = pdm
		pedal.material_override = mat_tire
		pedal.position = Vector3(side * 0.15, side * 0.18, 0)
		pedal_crank.add_child(pedal)
		
	# Frame Tubes
	var seat_tube = _make_tube(Vector3(0, 0.38, -0.05), Vector3(0, 0.88, -0.22), mat_frame)
	visual_root.add_child(seat_tube)
	
	var down_tube = _make_tube(Vector3(0, 0.38, -0.05), Vector3(0, 0.82, 0.55), mat_frame)
	visual_root.add_child(down_tube)
	
	var top_tube = _make_tube(Vector3(0, 0.86, -0.20), Vector3(0, 0.82, 0.55), mat_frame)
	visual_root.add_child(top_tube)
	
	var chain_stay = _make_tube(Vector3(0, 0.38, -0.05), Vector3(0, 0.38, -0.65), mat_frame)
	visual_root.add_child(chain_stay)
	
	var seat_stay = _make_tube(Vector3(0, 0.86, -0.20), Vector3(0, 0.38, -0.65), mat_frame)
	visual_root.add_child(seat_stay)
	
	# Saddle
	var saddle = MeshInstance3D.new()
	var sdm = BoxMesh.new()
	sdm.size = Vector3(0.24, 0.06, 0.32)
	saddle.mesh = sdm
	saddle.material_override = mat_leather
	saddle.position = Vector3(0, 0.92, -0.22)
	visual_root.add_child(saddle)
	
	# Rear Luggage Rack (ឃ្លុបកង់)
	var rack = MeshInstance3D.new()
	var rkm = BoxMesh.new()
	rkm.size = Vector3(0.2, 0.03, 0.45)
	rack.mesh = rkm
	rack.material_override = mat_chrome
	rack.position = Vector3(0, 0.76, -0.55)
	visual_root.add_child(rack)
	
	# Kickstand
	kickstand = MeshInstance3D.new()
	var ksm = CylinderMesh.new()
	ksm.top_radius = 0.02
	ksm.bottom_radius = 0.02
	ksm.height = 0.38
	kickstand.mesh = ksm
	kickstand.material_override = mat_chrome
	kickstand.position = Vector3(-0.08, 0.22, -0.15)
	kickstand.rotation_degrees.z = -28.0 # Parked stand down
	visual_root.add_child(kickstand)


func _make_tube(p1: Vector3, p2: Vector3, mat: Material) -> MeshInstance3D:
	var tube = MeshInstance3D.new()
	var length = p1.distance_to(p2)
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = length
	tube.mesh = cyl
	tube.material_override = mat
	
	tube.position = (p1 + p2) * 0.5
	var y_axis = (p2 - p1).normalized()
	var ref_up = Vector3.UP
	if absf(y_axis.dot(ref_up)) > 0.99:
		ref_up = Vector3.RIGHT
	var x_axis = ref_up.cross(y_axis).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	tube.transform.basis = Basis(x_axis, y_axis, z_axis)
	return tube
