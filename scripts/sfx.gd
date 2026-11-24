class_name Sfx
extends Node
## Placeholder sound effects synthesised at startup, so the prototype has
## impact sounds without any audio assets. Swap for real samples later.
## Audio is not slowed by Engine.time_scale, so hits still sound during hit-stop.

const RATE := 22050
const POOL := 8

var _sounds := {}  # name -> [AudioStreamWAV, volume_db]
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_sounds["hit"] = [_tone(0.18, 150.0, 0.55, 28.0), 0.0]
	_sounds["hit_heavy"] = [_tone(0.32, 85.0, 0.5, 16.0), 2.0]
	_sounds["block"] = [_tone(0.12, 260.0, 0.8, 45.0), -4.0]
	_sounds["tell"] = [_tone(0.1, 950.0, 0.15, 30.0, 0.0), -10.0]
	_sounds["whoosh"] = [_whoosh(0.14), -12.0]
	_sounds["bell"] = [_bell(1.4), -4.0]
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch_jitter := 0.08) -> void:
	if not _sounds.has(sound):
		return
	var entry: Array = _sounds[sound]
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = entry[0]
	p.volume_db = entry[1]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


# A thump: decaying sine with a fast pitch drop, mixed with noise.
func _tone(dur: float, freq: float, noise: float, decay: float, sweep := 2.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq * (1.0 + sweep * exp(-t * 40.0))
		phase += TAU * f / RATE
		var s := (sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise) * exp(-t * decay)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _whoosh(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.25)  # crude low-pass
		var s := lp * sin(PI * t) * 1.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _bell(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := (sin(TAU * 740.0 * t) + 0.5 * sin(TAU * 1480.0 * t) + 0.3 * sin(TAU * 2030.0 * t)) * 0.45 * exp(-t * 2.5)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
