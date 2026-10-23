extends Node
class_name AudioSynth

# Sound effect library
static var sound_cache: Dictionary = {}
static var sfx_players: Array[AudioStreamPlayer] = []
static var ambient_day_player: AudioStreamPlayer
static var ambient_night_player: AudioStreamPlayer
static var ambient_rain_player: AudioStreamPlayer
static var ambient_cicada_player: AudioStreamPlayer
static var folk_music_player: AudioStreamPlayer

const MIX_RATE: int = 22050

static func init_audio(parent: Node) -> void:
	if sound_cache.size() > 0:
		return
	
	# Generate sound waveforms in background or at start
	sound_cache["bell"] = _synth_bicycle_bell()
	sound_cache["pickup"] = _synth_pickup_chime()
	sound_cache["step_grass"] = _synth_footstep_grass()
	sound_cache["step_wood"] = _synth_footstep_wood()
	sound_cache["moo"] = _synth_cow_moo()
	sound_cache["cluck"] = _synth_chicken_cluck()
	sound_cache["hammock"] = _synth_hammock_creak()
	sound_cache["splash"] = _synth_splash()
	sound_cache["ambient_day"] = _synth_ambient_day()
	sound_cache["ambient_night"] = _synth_ambient_night()
	sound_cache["pagoda_bell"] = _synth_pagoda_bell()
	sound_cache["rain"] = _synth_rain()
	sound_cache["thunder"] = _synth_thunder()
	sound_cache["sizzle"] = _synth_sizzle()
	sound_cache["eat"] = _synth_eat()
	sound_cache["cast"] = _synth_cast()
	sound_cache["bark"] = _synth_dog_bark()
	sound_cache["blessing"] = _synth_blessing()
	sound_cache["mud"] = _synth_mud_plow()
	sound_cache["shutter"] = _synth_camera_shutter()
	sound_cache["roneat_high"] = _synth_roneat_note(587.33, 0.7)
	sound_cache["roneat_mid"] = _synth_roneat_note(392.0, 0.8)
	sound_cache["roneat_low"] = _synth_roneat_note(293.66, 0.9)
	sound_cache["folk_melody"] = _synth_roneat_melody()
	sound_cache["cicadas"] = _synth_cicadas()
	sound_cache["water_stream"] = _synth_water_stream()
	
	# Create pool of AudioStreamPlayers
	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.name = "SFX_Player_" + str(i)
		parent.add_child(p)
		sfx_players.append(p)
		
	# Ambient day player
	ambient_day_player = AudioStreamPlayer.new()
	ambient_day_player.name = "Ambient_Day"
	ambient_day_player.stream = sound_cache["ambient_day"]
	ambient_day_player.volume_db = -12.0
	parent.add_child(ambient_day_player)
	ambient_day_player.play()
	
	# Ambient night player
	ambient_night_player = AudioStreamPlayer.new()
	ambient_night_player.name = "Ambient_Night"
	ambient_night_player.stream = sound_cache["ambient_night"]
	ambient_night_player.volume_db = -80.0
	parent.add_child(ambient_night_player)
	ambient_night_player.play()

	# Ambient rain player
	ambient_rain_player = AudioStreamPlayer.new()
	ambient_rain_player.name = "Ambient_Rain"
	ambient_rain_player.stream = sound_cache["rain"]
	ambient_rain_player.volume_db = -80.0
	parent.add_child(ambient_rain_player)
	ambient_rain_player.play()

	# Folk music player (Roneat & Chapei traditional melodies)
	folk_music_player = AudioStreamPlayer.new()
	folk_music_player.name = "FolkMusicPlayer"
	folk_music_player.stream = sound_cache["folk_melody"]
	folk_music_player.volume_db = -11.0
	parent.add_child(folk_music_player)

	# Ambient cicadas player (hot afternoon heat chorus)
	ambient_cicada_player = AudioStreamPlayer.new()
	ambient_cicada_player.name = "Ambient_Cicadas"
	ambient_cicada_player.stream = sound_cache["cicadas"]
	ambient_cicada_player.volume_db = -60.0
	parent.add_child(ambient_cicada_player)
	ambient_cicada_player.play()


static func toggle_folk_music() -> bool:
	if folk_music_player:
		if folk_music_player.playing:
			folk_music_player.stop()
			return false
		else:
			folk_music_player.play()
			return true
	return false


static func is_folk_music_playing() -> bool:
	return folk_music_player != null and folk_music_player.playing


static func play(sound_name: String, volume_db: float = -4.0, pitch_scale: float = 1.0) -> void:
	if not sound_cache.has(sound_name):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sound_cache[sound_name]
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale + randf_range(-0.06, 0.06)
			p.play()
			return
	# If all busy, use first
	if sfx_players.size() > 0:
		var p = sfx_players[0]
		p.stream = sound_cache[sound_name]
		p.volume_db = volume_db
		p.pitch_scale = pitch_scale
		p.play()


static func update_ambience(is_night_factor: float, time_of_day: float = 12.0) -> void:
	# is_night_factor: 0.0 = full day, 1.0 = full night
	if ambient_day_player:
		var day_db = lerp(-10.0, -60.0, is_night_factor)
		ambient_day_player.volume_db = day_db
	if ambient_night_player:
		var night_db = lerp(-60.0, -8.0, is_night_factor)
		ambient_night_player.volume_db = night_db
	if ambient_cicada_player:
		# Cicadas swell during hot midday hours (10:00 to 17:00)
		var heat_factor = clampf(1.0 - absf(time_of_day - 13.5) / 3.8, 0.0, 1.0) * (1.0 - is_night_factor)
		var cicada_db = lerp(-60.0, -11.0, heat_factor)
		ambient_cicada_player.volume_db = cicada_db


static func update_rain(rain_factor: float) -> void:
	if ambient_rain_player:
		if rain_factor > 0.02:
			if not ambient_rain_player.playing:
				ambient_rain_player.play()
			ambient_rain_player.volume_db = lerp(-50.0, -8.0, rain_factor)
		else:
			ambient_rain_player.volume_db = -80.0


# --- Waveform Synthesizers ---

static func _build_wav(total_samples: int, loop: bool = false) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = total_samples
	return wav


static func _synth_bicycle_bell() -> AudioStreamWAV:
	var duration = 0.8
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0
		# Strike 1 at t=0
		if t < 0.7:
			var env1 = exp(-t * 9.0)
			val += (sin(2.0 * PI * 1820.0 * t) + 0.6 * sin(2.0 * PI * 2450.0 * t) + 0.3 * sin(2.0 * PI * 4200.0 * t)) * env1
		# Strike 2 at t=0.14
		if t >= 0.14:
			var t2 = t - 0.14
			var env2 = exp(-t2 * 8.0)
			val += (sin(2.0 * PI * 2150.0 * t2) + 0.7 * sin(2.0 * PI * 2890.0 * t2) + 0.3 * sin(2.0 * PI * 4800.0 * t2)) * env2
			
		val = clampf(val * 0.45, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_pickup_chime() -> AudioStreamWAV:
	# Rising sparkly arpeggio: C6 (1046Hz), E6 (1318Hz), G6 (1567Hz), C7 (2093Hz)
	var duration = 0.55
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	var freqs = [1046.5, 1318.5, 1567.9, 2093.0]
	var note_dur = 0.1
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var note_idx = clampi(int(t / note_dur), 0, freqs.size() - 1)
		var note_t = t - (note_idx * note_dur)
		var freq = freqs[note_idx]
		
		var env = exp(-note_t * 12.0)
		var val = (sin(2.0 * PI * freq * t) + 0.35 * sin(2.0 * PI * freq * 2.0 * t)) * env
		val = clampf(val * 0.5, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_footstep_grass() -> AudioStreamWAV:
	var duration = 0.16
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 30.0)
		var low_thud = sin(2.0 * PI * 75.0 * t) * exp(-t * 22.0)
		var noise = randf_range(-0.4, 0.4) * exp(-t * 38.0)
		var val = (low_thud * 0.7 + noise * 0.3) * env
		val = clampf(val * 0.6, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_footstep_wood() -> AudioStreamWAV:
	var duration = 0.14
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 40.0)
		var tap = sin(2.0 * PI * 340.0 * t) + 0.4 * sin(2.0 * PI * 580.0 * t)
		var val = tap * env * 0.65
		val = clampf(val, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_cow_moo() -> AudioStreamWAV:
	var duration = 1.3
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		# Warm gentle moo pitch envelope (starts at 145Hz, glides to 125Hz, then 105Hz)
		var freq = 145.0 - (t * 30.0)
		var env = (sin(PI * (t / duration)) ** 1.5)
		var harmonic1 = sin(2.0 * PI * freq * t)
		var harmonic2 = 0.5 * sin(2.0 * PI * (freq * 2.0) * t)
		var harmonic3 = 0.25 * sin(2.0 * PI * (freq * 3.0) * t)
		var val = (harmonic1 + harmonic2 + harmonic3) * env * 0.55
		val = clampf(val, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_chicken_cluck() -> AudioStreamWAV:
	var duration = 0.35
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0
		# Cluck 1
		if t < 0.14:
			var env = exp(-t * 32.0)
			val += sin(2.0 * PI * (820.0 - t * 1500.0) * t) * env
		# Cluck 2
		if t >= 0.12 and t < 0.28:
			var t2 = t - 0.12
			var env = exp(-t2 * 34.0)
			val += sin(2.0 * PI * (940.0 - t2 * 1800.0) * t2) * env
			
		val = clampf(val * 0.55, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_hammock_creak() -> AudioStreamWAV:
	var duration = 0.4
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 9.0)
		var creak = sin(2.0 * PI * (220.0 + sin(t * 70.0) * 40.0) * t)
		var val = creak * env * 0.4
		val = clampf(val, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_splash() -> AudioStreamWAV:
	var duration = 0.28
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 14.0)
		var bubble = sin(2.0 * PI * (320.0 + t * 400.0) * t) * 0.5
		var noise = randf_range(-0.4, 0.4) * exp(-t * 22.0)
		var val = (bubble + noise) * env * 0.5
		val = clampf(val, -1.0, 1.0)
		
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_ambient_day() -> AudioStreamWAV:
	# 4-second seamless looped ambient track with gentle breeze and sporadic bird whistles
	var duration = 4.0
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0
		# Gentle tropical breeze (low pink-ish noise)
		var breeze = sin(2.0 * PI * 0.3 * t) * 0.08 + randf_range(-0.04, 0.04)
		val += breeze
		
		# Bird chirp 1 around t=0.8
		if t >= 0.8 and t <= 1.15:
			var bt = t - 0.8
			var benv = sin(PI * (bt / 0.35))
			var bfreq = 2400.0 + sin(bt * 45.0) * 350.0
			val += sin(2.0 * PI * bfreq * bt) * benv * 0.22
			
		# Bird chirp 2 around t=2.6
		if t >= 2.6 and t <= 2.95:
			var bt = t - 2.6
			var benv = sin(PI * (bt / 0.35))
			var bfreq = 2800.0 + cos(bt * 55.0) * 450.0
			val += sin(2.0 * PI * bfreq * bt) * benv * 0.22
			
		val = clampf(val * 0.4, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples, true)
	wav.data = data
	return wav


static func _synth_ambient_night() -> AudioStreamWAV:
	# 4-second seamless looped night track with rhythmic crickets and deep bullfrog
	var duration = 4.0
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0
		
		# Crickets: rhythmic chirping pulses at ~4400Hz modulated at 4Hz
		var cricket_pulse = maxf(0.0, sin(2.0 * PI * 4.0 * t)) ** 3.0
		var cricket = sin(2.0 * PI * 4400.0 * t) * cricket_pulse * 0.16
		val += cricket
		
		# Distant secondary cricket at 5200Hz
		var cricket_pulse2 = maxf(0.0, sin(2.0 * PI * 2.5 * (t + 0.3))) ** 3.0
		val += sin(2.0 * PI * 5200.0 * t) * cricket_pulse2 * 0.1
		
		# Low bullfrog croak at t=1.8
		if t >= 1.8 and t <= 2.3:
			var ft = t - 1.8
			var fenv = sin(PI * (ft / 0.5))
			var frog = sin(2.0 * PI * 130.0 * ft) * (1.0 + sin(ft * 90.0) * 0.5)
			val += frog * fenv * 0.24
			
		val = clampf(val * 0.45, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF
		
	var wav = _build_wav(total_samples, true)
	wav.data = data
	return wav


static func _synth_pagoda_bell() -> AudioStreamWAV:
	# Deep, resonant bronze temple bell with rich harmonic decay
	var duration = 4.0
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 0.95)
		# Fundamental F3 (174.6Hz), octaves and non-harmonic bell partials
		var val = (
			sin(2.0 * PI * 174.6 * t) * 0.50 +
			sin(2.0 * PI * 349.2 * t) * 0.28 +
			sin(2.0 * PI * 524.0 * t) * 0.16 +
			sin(2.0 * PI * 873.0 * t) * 0.10 +
			sin(2.0 * PI * 1222.0 * t) * 0.05
		) * env
		val = clampf(val * 0.52, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_rain() -> AudioStreamWAV:
	# 4-second seamless looped tropical rain patter
	var duration = 4.0
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_val = 0.0
	for i in range(total_samples):
		# Low-pass pink noise filter for soft rainfall
		var white = randf_range(-1.0, 1.0)
		last_val = (last_val * 0.88) + (white * 0.12)

		# Droplet patter clicks
		var droplet = 0.0
		if (i % 340) == 0 and randf() > 0.45:
			droplet = randf_range(-0.4, 0.4)

		var val = clampf(last_val * 0.65 + droplet * 0.35, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples, true)
	wav.data = data
	return wav


static func _synth_thunder() -> AudioStreamWAV:
	# Deep, reverberating tropical thunder rumble
	var duration = 3.6
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var low_state = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 0.88)

		var white = randf_range(-1.0, 1.0)
		low_state = (low_state * 0.93) + (white * 0.07)

		# Sub-bass rumble frequencies (42Hz, 68Hz)
		var sub1 = sin(2.0 * PI * 42.0 * t + sin(t * 14.0) * 0.7) * 0.55
		var sub2 = sin(2.0 * PI * 68.0 * t) * 0.35

		var val = (low_state * 1.6 + sub1 + sub2) * env
		val = clampf(val * 0.62, -1.0, 1.0)
		var ival = clampi(int(val * 32000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_sizzle() -> AudioStreamWAV:
	# Sizzling hot charcoal / pan sound
	var duration = 1.3
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_val = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = sin(PI * (t / duration))
		var white = randf_range(-1.0, 1.0)
		var high = white - last_val
		last_val = white

		var pop = 0.0
		if (i % 220) == 0 and randf() > 0.4:
			pop = randf_range(-0.7, 0.7)

		var val = clampf((high * 0.45 + pop * 0.55) * env, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_eat() -> AudioStreamWAV:
	# Crisp bite and munch sound
	var duration = 0.65
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0
		if t < 0.28:
			var env = exp(-t * 22.0)
			val += randf_range(-0.7, 0.7) * env
		if t >= 0.22 and t < 0.55:
			var t2 = t - 0.22
			var env2 = exp(-t2 * 20.0)
			val += randf_range(-0.6, 0.6) * env2

		val = clampf(val * 0.75, -1.0, 1.0)
		var ival = clampi(int(val * 30000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_cast() -> AudioStreamWAV:
	# Bamboo rod swish through air
	var duration = 0.35
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_noise = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = sin(PI * (t / duration))
		var freq = 450.0 + sin(t * 12.0) * 180.0
		var tone = sin(2.0 * PI * freq * t) * 0.4
		var white = randf_range(-1.0, 1.0)
		last_noise = (last_noise * 0.8) + (white * 0.2)
		var val = (tone + last_noise * 0.5) * env * 0.45
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_dog_bark() -> AudioStreamWAV:
	# Friendly Cambodian village dog woof
	var duration = 0.28
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_noise = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var progress = t / duration
		var env = sin(PI * progress) * (1.0 - progress * 0.4)

		# Pitch contour: fast rise and fall
		var freq = 310.0 + sin(progress * PI) * 220.0
		var tone1 = sin(2.0 * PI * freq * t)
		var tone2 = sin(2.0 * PI * freq * 1.95 * t) * 0.35
		var white = randf_range(-1.0, 1.0)
		last_noise = (last_noise * 0.7) + (white * 0.3)

		var val = (tone1 * 0.55 + tone2 * 0.25 + last_noise * 0.20) * env * 0.6
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_blessing() -> AudioStreamWAV:
	# Resonant Buddhist meditation singing bowl & bronze prayer bell
	var duration = 3.6
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 0.85)

		# Warm meditation bowl harmonics with slow spiritual shimmer
		var f1 = 220.0 # A3 warm base
		var f2 = 442.0 # Gentle shimmer beat
		var f3 = 660.0 # Perfect fifth overtone
		var f4 = 1100.0 # Chime high harmonic

		var shimmer = 1.0 + 0.15 * sin(2.0 * PI * 1.8 * t)
		var val = (
			sin(2.0 * PI * f1 * t) * 0.45 * shimmer +
			sin(2.0 * PI * f2 * t) * 0.25 +
			sin(2.0 * PI * f3 * t) * 0.18 +
			sin(2.0 * PI * f4 * t) * 0.12 * exp(-t * 2.0)
		) * env * 0.5

		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_mud_plow() -> AudioStreamWAV:
	# Wet mud squelch and water churn of rice paddy plow
	var duration = 0.42
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_noise = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = sin(PI * (t / duration))
		var white = randf_range(-1.0, 1.0)
		last_noise = (last_noise * 0.88) + (white * 0.12)

		var bubble = sin(2.0 * PI * (90.0 + sin(t * 30.0) * 45.0) * t) * 0.35
		var val = (last_noise * 0.6 + bubble * 0.4) * env * 0.55
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_camera_shutter() -> AudioStreamWAV:
	# Dual-click mechanical camera shutter
	var duration = 0.22
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var val = 0.0

		# Click 1: Mirror flip (t = 0.0 to 0.04)
		if t < 0.04:
			var env1 = exp(-t * 120.0)
			val += sin(2.0 * PI * 1800.0 * t) * env1 * 0.65
			val += randf_range(-0.3, 0.3) * env1

		# Click 2: Shutter curtain (t = 0.07 to 0.14)
		if t >= 0.07 and t < 0.14:
			var dt = t - 0.07
			var env2 = exp(-dt * 90.0)
			val += sin(2.0 * PI * 2400.0 * dt) * env2 * 0.75
			val += randf_range(-0.35, 0.35) * env2

		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_roneat_note(freq: float, duration: float) -> AudioStreamWAV:
	# Authentic Cambodian Roneat Ek bamboo bar with padded mallet strike
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var env = exp(-t * 5.0)

		# Woody mallet strike click transient
		var click = 0.0
		if t < 0.025:
			var c_env = exp(-t * 160.0)
			click = sin(2.0 * PI * 1750.0 * t) * c_env * 0.45

		# Xylophone acoustic partials (f, 2.76f, 5.4f)
		var t1 = sin(2.0 * PI * freq * t)
		var t2 = sin(2.0 * PI * freq * 2.756 * t) * 0.32 * exp(-t * 7.5)
		var t3 = sin(2.0 * PI * freq * 5.404 * t) * 0.12 * exp(-t * 11.0)

		var val = (t1 * 0.65 + t2 + t3 + click) * env * 0.6
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.data = data
	return wav


static func _synth_roneat_melody() -> AudioStreamWAV:
	# 12.5-second traditional Cambodian countryside Mohaori pentatonic melody
	var duration = 12.5
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	# Traditional melody score: [start_time, freq, duration, is_accent]
	var notes = [
		[0.00, 293.66, 0.70, true],   # D4
		[0.75, 392.00, 0.70, false],  # G4
		[1.50, 440.00, 0.35, false],  # A4
		[1.88, 493.88, 0.35, false],  # B4
		[2.25, 587.33, 0.75, true],   # D5
		[3.00, 493.88, 0.35, false],  # B4
		[3.38, 440.00, 0.35, false],  # A4
		[3.75, 392.00, 1.10, true],   # G4

		[5.00, 329.63, 0.70, true],   # E4
		[5.75, 392.00, 0.70, false],  # G4
		[6.50, 440.00, 0.70, false],  # A4
		[7.25, 587.33, 0.35, false],  # D5
		[7.63, 659.25, 0.35, true],   # E5
		[8.00, 587.33, 0.75, true],   # D5
		[8.75, 493.88, 0.35, false],  # B4
		[9.13, 440.00, 0.35, false],  # A4
		[9.50, 392.00, 1.10, true],   # G4

		[10.80, 440.00, 0.50, false], # A4
		[11.35, 293.66, 1.05, true]   # D4
	]

	# Bass plucked Chapei strikes
	var bass_plucks = [
		[0.00, 146.83, 1.2], # Low D3
		[3.75, 196.00, 1.1], # Low G3
		[5.00, 164.81, 1.1], # Low E3
		[8.00, 146.83, 1.2], # Low D3
		[9.50, 196.00, 1.1], # Low G3
		[11.35, 146.83, 1.1] # Low D3
	]

	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var mix = 0.0

		# 1. Roneat notes
		for note in notes:
			var n_start: float = note[0]
			var n_freq: float = note[1]
			var n_dur: float = note[2]
			if t >= n_start and t < (n_start + n_dur + 0.3):
				var dt = t - n_start
				var env = exp(-dt * 4.4)
				var t1 = sin(2.0 * PI * n_freq * dt)
				var t2 = sin(2.0 * PI * n_freq * 2.756 * dt) * 0.28 * exp(-dt * 6.5)
				mix += (t1 * 0.55 + t2) * env * 0.42

		# 2. Warm Chapei plucked bass
		for b in bass_plucks:
			var b_start: float = b[0]
			var b_freq: float = b[1]
			var b_dur: float = b[2]
			if t >= b_start and t < (b_start + b_dur + 0.4):
				var dt = t - b_start
				var b_env = exp(-dt * 3.2)
				var b_tone = sin(2.0 * PI * b_freq * dt) * 0.5 + sin(2.0 * PI * b_freq * 2.0 * dt) * 0.25
				mix += b_tone * b_env * 0.32

		mix = clampf(mix, -1.0, 1.0)
		var ival = clampi(int(mix * 27000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	wav.data = data
	return wav


static func _synth_cicadas() -> AudioStreamWAV:
	# Rhythmic Cambodian afternoon cicada chorus (Chongreet)
	var duration = 3.6
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	for i in range(total_samples):
		var t = float(i) / MIX_RATE

		# High frequency buzz (5300 Hz carrier + 8000 Hz shimmer)
		var chirp = sin(2.0 * PI * 36.0 * t) * 0.4 + 0.6
		var swell = 0.65 + 0.35 * sin(2.0 * PI * 0.42 * t)
		var carrier1 = sin(2.0 * PI * 5250.0 * t)
		var carrier2 = sin(2.0 * PI * 8100.0 * t) * 0.35
		var white = randf_range(-0.15, 0.15)

		var val = (carrier1 * 0.65 + carrier2 + white) * chirp * swell * 0.32
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 26000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	wav.data = data
	return wav


static func _synth_water_stream() -> AudioStreamWAV:
	# Gentle bubbling and lapping of canal & lotus pond water
	var duration = 4.0
	var total_samples = int(MIX_RATE * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var last_val = 0.0
	for i in range(total_samples):
		var t = float(i) / MIX_RATE
		var white = randf_range(-1.0, 1.0)
		last_val = (last_val * 0.88) + (white * 0.12) # Pink/brownian water wash

		# Periodic water bubbles & surface pops
		var bubble = 0.0
		var b_cycle = fmod(t * 2.8, 1.0)
		if b_cycle < 0.15:
			var b_env = sin(PI * (b_cycle / 0.15))
			var b_freq = 320.0 + b_cycle * 1800.0 # Frequency rise on bubble pop
			bubble = sin(2.0 * PI * b_freq * t) * b_env * 0.45

		var val = (last_val * 0.65 + bubble * 0.35) * 0.45
		val = clampf(val, -1.0, 1.0)
		var ival = clampi(int(val * 28000.0), -32768, 32767)
		var uval = ival if ival >= 0 else ival + 65536
		data[i * 2] = uval & 0xFF
		data[i * 2 + 1] = (uval >> 8) & 0xFF

	var wav = _build_wav(total_samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	wav.data = data
	return wav








