extends Node3D

const AudioSynth = preload("res://scripts/audio_synth.gd")
const DayNightCycle = preload("res://scripts/day_night_cycle.gd")
const CambodianCow = preload("res://scripts/cow.gd")
const CambodianWaterBuffalo = preload("res://scripts/buffalo.gd")
const VillageChicken = preload("res://scripts/chicken.gd")
const CountrysideHammock = preload("res://scripts/hammock.gd")
const CountrysideBicycle = preload("res://scripts/bicycle.gd")
const HarvestableItem = preload("res://scripts/harvestable.gd")
const CountrysideFireflies = preload("res://scripts/fireflies.gd")
const CountrysideSmokeFX = preload("res://scripts/smoke_fx.gd")
const CountrysideSignpost = preload("res://scripts/signpost.gd")
const WeatherSystem = preload("res://scripts/weather_system.gd")
const CountrysideCookingStation = preload("res://scripts/cooking_station.gd")
const CountrysideFishingSpot = preload("res://scripts/fishing_spot.gd")
const VillageDog = preload("res://scripts/village_dog.gd")
const CountrysideMonkProcession = preload("res://scripts/monk_procession.gd")
const CountrysideRoneatEk = preload("res://scripts/roneat_instrument.gd")

# Cambo Countryside - Main World Controller
var day_night: DayNightCycle
var weather: WeatherSystem
var time_label: Label
var player_ref: Node

func _ready() -> void:
	# 1. Initialize Audio Synthesizer (SFX & Day/Night Ambiance)
	AudioSynth.init_audio(self)
	
	# 2. Setup Dynamic Day / Night Cycle & Tropical Weather
	_setup_day_night()
	_setup_weather()
	
	# 3. Setup World Entities
	_spawn_bicycle()
	_spawn_hammock()
	_spawn_cows()
	_spawn_water_buffaloes()
	_spawn_chickens()
	_spawn_harvestables()
	_spawn_fireflies()
	_spawn_cooking_station()
	_spawn_signposts()
	_spawn_fishing_spots()
	_spawn_village_dog()
	_spawn_monk_procession()
	_spawn_roneat()
	_setup_water_ambience()
	
	# 4. Enhance HUD with Time Display & Key Guides
	_setup_hud()


func _setup_day_night() -> void:
	day_night = DayNightCycle.new()
	day_night.name = "DayNightController"
	add_child(day_night)
	
	var dir_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	
	day_night.setup(dir_light, world_env)
	day_night.time_changed.connect(_on_time_changed)


func _setup_weather() -> void:
	weather = WeatherSystem.new()
	weather.name = "WeatherSystem"
	add_child(weather)

	var dir_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	weather.setup(dir_light, world_env)


func _on_time_changed(time_str: String, is_night: bool) -> void:
	if time_label:
		time_label.text = time_str


func _setup_hud() -> void:
	var hud = get_node_or_null("HUD")
	if not hud:
		return
		
	var margin = hud.get_node_or_null("Margin")
	if not margin:
		return
		
	var vbox = margin.get_node_or_null("VBox") as VBoxContainer
	if not vbox:
		return
		
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add Time & Ambiance Widget
	time_label = Label.new()
	time_label.name = "TimeDisplay"
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	time_label.add_theme_constant_override("shadow_offset_x", 1)
	time_label.add_theme_constant_override("shadow_offset_y", 1)
	time_label.text = day_night.get_time_string()
	vbox.add_child(time_label)
	
	# Update Title Label mouse filter
	var title = vbox.get_node_or_null("TitleLabel") as Label
	if title:
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Update Hint Label with full controls
	var hint = vbox.get_node_or_null("HintLabel") as Label
	if hint:
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.text = "Move: WASD | Jump: Space | Sprint: Shift | Interact/Ride/Play: E | Plow/Bell: F | Time: T | Weather: R | Music: M | Photo: P | Costume: C | View: V"


func _spawn_bicycle() -> void:
	var bike = CountrysideBicycle.new()
	bike.name = "CountrysideBicycle"
	bike.position = Vector3(-8.5, 0.05, 4.2)
	bike.rotation_degrees.y = 105.0
	add_child(bike)


func _spawn_hammock() -> void:
	# Positioned under the shady stilt house between pillars
	var hammock = CountrysideHammock.new()
	hammock.name = "HouseHammock"
	# Pillars are at X=-20, Y=0, Z=5; under the house krea resting platform
	hammock.position = Vector3(-19.5, 0.1, 2.5)
	hammock.rotation_degrees.y = 85.0
	add_child(hammock)


func _spawn_cows() -> void:
	# White Zebu Cow 1 grazing in west pasture
	var cow1 = CambodianCow.new()
	cow1.name = "Cow_White"
	cow1.position = Vector3(-14.0, 0.0, 18.0)
	cow1.rotation_degrees.y = 35.0
	add_child(cow1)
	
	# White Zebu Cow 2 grazing further north in meadow
	var cow2 = CambodianCow.new()
	cow2.name = "Cow_Cream"
	cow2.position = Vector3(-18.0, 0.0, 32.0)
	cow2.rotation_degrees.y = -60.0
	add_child(cow2)


func _spawn_water_buffaloes() -> void:
	# Buffalo 1: East rice paddy
	var buf1 = CambodianWaterBuffalo.new()
	buf1.name = "WaterBuffalo_Paddy"
	buf1.position = Vector3(22.0, 0.0, 8.0)
	buf1.rotation_degrees.y = -80.0
	add_child(buf1)
	
	# Buffalo 2: Near lotus pond
	var buf2 = CambodianWaterBuffalo.new()
	buf2.name = "WaterBuffalo_Pond"
	buf2.position = Vector3(-20.0, 0.0, -14.0)
	buf2.rotation_degrees.y = 120.0
	add_child(buf2)


func _spawn_chickens() -> void:
	# Mother hen & chicks foraging under and around stilt house
	var hen = VillageChicken.new()
	hen.name = "MotherHen"
	hen.position = Vector3(-15.5, 0.0, 6.5)
	add_child(hen)


func _spawn_harvestables() -> void:
	# Coconuts under palm trees
	var coconut_positions = [
		Vector3(9.0, 0.22, 24.0),
		Vector3(10.0, 0.22, 10.0),
		Vector3(8.0, 0.22, -18.0),
		Vector3(42.0, 0.22, -6.0)
	]
	for i in range(coconut_positions.size()):
		var item = HarvestableItem.new()
		item.name = "Coconut_" + str(i)
		item.item_type = HarvestableItem.ItemType.COCONUT
		item.position = coconut_positions[i]
		add_child(item)
		
	# Bananas in banana plant grove
	var banana_positions = [
		Vector3(-13.0, 1.3, -2.0),
		Vector3(-15.0, 1.3, -4.0),
		Vector3(-26.0, 1.3, 11.0)
	]
	for i in range(banana_positions.size()):
		var item = HarvestableItem.new()
		item.name = "Banana_" + str(i)
		item.item_type = HarvestableItem.ItemType.BANANA
		item.position = banana_positions[i]
		add_child(item)
		
	# Sacred lotus blossoms in pond
	var lotus_positions = [
		Vector3(-23.0, 0.04, -16.0),
		Vector3(-26.0, 0.04, -18.0),
		Vector3(-24.0, 0.04, -20.0),
		Vector3(-27.0, 0.04, -15.0)
	]
	for i in range(lotus_positions.size()):
		var item = HarvestableItem.new()
		item.name = "Lotus_" + str(i)
		item.item_type = HarvestableItem.ItemType.LOTUS
		item.position = lotus_positions[i]
		add_child(item)


func make_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _spawn_fireflies() -> void:
	# Swarm 1: Lotus pond
	var ff1 = CountrysideFireflies.new()
	ff1.name = "Fireflies_Pond"
	ff1.position = Vector3(-24.5, 0.3, -18.0)
	ff1.radius = 7.5
	ff1.firefly_count = 20
	add_child(ff1)

	# Swarm 2: East rice paddy
	var ff2 = CountrysideFireflies.new()
	ff2.name = "Fireflies_EastPaddy"
	ff2.position = Vector3(26.0, 0.4, 10.0)
	ff2.radius = 9.0
	ff2.firefly_count = 22
	add_child(ff2)

	# Swarm 3: South rice paddy & shade trees
	var ff3 = CountrysideFireflies.new()
	ff3.name = "Fireflies_SouthPaddy"
	ff3.position = Vector3(22.0, 0.4, -26.0)
	ff3.radius = 8.5
	ff3.firefly_count = 18
	add_child(ff3)

	# Swarm 4: Banana grove near stilt house
	var ff4 = CountrysideFireflies.new()
	ff4.name = "Fireflies_HouseGrove"
	ff4.position = Vector3(-16.0, 0.4, -3.0)
	ff4.radius = 6.0
	ff4.firefly_count = 15
	add_child(ff4)


func _spawn_cooking_station() -> void:
	# Traditional clay stove cooking station with prep table & smoke under stilt house
	var station = CountrysideCookingStation.new()
	station.name = "VillageCookingStation"
	station.position = Vector3(-21.8, 0.05, 8.2)
	station.rotation_degrees.y = 75.0
	add_child(station)


func _spawn_signposts() -> void:
	# Signpost 1: Crossroads where main dirt road branches toward the house
	var sign1 = CountrysideSignpost.new()
	sign1.name = "Signpost_MainFork"
	sign1.position = Vector3(-1.6, 0.0, 5.8)
	sign1.rotation_degrees.y = -20.0
	sign1.sign_title = "Village Crossroads"
	sign1.sign_khmer = "ផ្លូវបំបែកភូមិ"
	sign1.sign_directions = [
		"<- Stilt House (ផ្ទះខ្មែរ) | Lotus Pond (បឹងឈូក)",
		"Rice Fields (វាលស្រែ) -> | Pasture (វាលស្មៅ)"
	]
	add_child(sign1)

	# Signpost 2: Near trail fork to Sacred Lotus Pond & Granary
	var sign2 = CountrysideSignpost.new()
	sign2.name = "Signpost_PondTrail"
	sign2.position = Vector3(-18.5, 0.0, -8.0)
	sign2.rotation_degrees.y = 65.0
	sign2.sign_title = "Pond & Granary Trail"
	sign2.sign_khmer = "ផ្លូវទៅបឹងឈូក និង ជង្រុកស្រូវ"
	sign2.sign_directions = [
		"<- Sacred Lotus Pond (បឹងឈូក)",
		"Rice Granary (ជង្រុកស្រូវ) ->"
	]
	add_child(sign2)


func _spawn_fishing_spots() -> void:
	# Spot 1: On the bank of Sacred Lotus Pond
	var spot1 = CountrysideFishingSpot.new()
	spot1.name = "FishingSpot_LotusPond"
	spot1.position = Vector3(-20.8, 0.05, -13.2)
	spot1.rotation_degrees.y = 135.0
	add_child(spot1)

	# Spot 2: At irrigation canal by the East Rice Paddy
	var spot2 = CountrysideFishingSpot.new()
	spot2.name = "FishingSpot_EastPaddy"
	spot2.position = Vector3(17.8, 0.05, 8.2)
	spot2.rotation_degrees.y = -90.0
	add_child(spot2)


func _spawn_village_dog() -> void:
	# Friendly caramel-coated Cambodian village dog in front yard of stilt house
	var dog = VillageDog.new()
	dog.name = "CambodianVillageDog"
	dog.position = Vector3(-13.5, 0.1, 4.2)
	dog.rotation_degrees.y = -45.0
	add_child(dog)


func _spawn_monk_procession() -> void:
	# Morning Buddhist monks' alms procession in single file along village dirt road
	var monks = CountrysideMonkProcession.new()
	monks.name = "MonkProcession"
	add_child(monks)


func _spawn_roneat() -> void:
	# Traditional Cambodian Roneat Ek bamboo xylophone on resting platform under stilt house
	var roneat = CountrysideRoneatEk.new()
	roneat.name = "VillageRoneatEk"
	roneat.position = Vector3(-19.8, 0.65, 4.2)
	roneat.rotation_degrees.y = 80.0
	add_child(roneat)


func _setup_water_ambience() -> void:
	# Lotus Pond lapping water 3D audio
	var pond_audio := AudioStreamPlayer3D.new()
	pond_audio.name = "Audio_LotusPond"
	pond_audio.stream = AudioSynth.sound_cache.get("water_stream")
	pond_audio.position = Vector3(-24.5, 0.05, -17.5)
	pond_audio.max_distance = 24.0
	pond_audio.unit_size = 12.0
	pond_audio.volume_db = -6.0
	add_child(pond_audio)
	pond_audio.play()

	# Irrigation Canal water flow 3D audio
	var canal_audio := AudioStreamPlayer3D.new()
	canal_audio.name = "Audio_Canal"
	canal_audio.stream = AudioSynth.sound_cache.get("water_stream")
	canal_audio.position = Vector3(18.0, 0.05, 8.0)
	canal_audio.max_distance = 22.0
	canal_audio.unit_size = 10.0
	canal_audio.volume_db = -7.0
	add_child(canal_audio)
	canal_audio.play()



