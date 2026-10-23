extends Node
class_name AudioSynth

# Sound effect library
static var sound_cache: Dictionary = {}
static var sfx_players: Array[AudioStreamPlayer] = []
static var ambient_day_player: AudioStreamPlayer
static var ambient_night_player: AudioStreamPlayer

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


static func update_ambience(is_night_factor: float) -> void:
	# is_night_factor: 0.0 = full day, 1.0 = full night
	if ambient_day_player:
		var day_db = lerp(-10.0, -60.0, is_night_factor)
		ambient_day_player.volume_db = day_db
	if ambient_night_player:
		var night_db = lerp(-60.0, -8.0, is_night_factor)
		ambient_night_player.volume_db = night_db


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
