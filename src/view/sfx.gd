extends Node
## Placeholder sound effects, synthesised at start-up (no sound files yet): a thwack for melee
## hits, a whoosh for shots, a falling tone for deaths, a fanfare for an age-up and for winning.
## Played from the sim's events when they happen on screen, a few at a time so a big battle
## doesn't turn into noise. View side only (cosmetic randomness is fine here).

const RATE := 22050
const VOICES := 10
const GAP := 0.05   # seconds between two sounds of one kind

var streams := {}
var players: Array = []
var last := {}


func _ready() -> void:
	streams.hit = _noise(0.07, 2200.0, 40.0)
	streams.shoot = _noise(0.14, 900.0, 18.0)
	streams.die = _sweep(0.28, 420.0, 140.0)
	streams.age = _notes([392.0, 494.0, 587.0, 784.0], 0.12)
	streams.won = _notes([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.14)
	streams.lost = _notes([392.0, 330.0, 262.0], 0.22)
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		add_child(p)
		players.append(p)


func play(kind: String, volume_db := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(kind, -1.0)) < GAP:
		return
	last[kind] = now
	for p in players:
		if not p.playing:
			p.stream = streams[kind]
			p.pitch_scale = randf_range(0.9, 1.12)
			p.volume_db = -10.0 + volume_db
			p.play()
			return


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## Noise through a one-pole low-pass at `cutoff`, decaying fast.
static func _noise(dur: float, cutoff: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in n:
		y += a * (randf_range(-1.0, 1.0) - y)
		out[i] = y * exp(-decay * float(i) / RATE) * 1.6
	return _wav(out)


static func _sweep(dur: float, f0: float, f1: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * lerpf(f0, f1, t) / RATE
		out[i] = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.2) * (1.0 - t) * 0.7
	return _wav(out)


static func _notes(freqs: Array, each: float) -> AudioStreamWAV:
	var per := int(each * RATE)
	var out := PackedFloat32Array()
	out.resize(per * freqs.size())
	for k in freqs.size():
		for i in per:
			var t := float(i) / RATE
			var env := minf(1.0, t * 80.0) * exp(-t * 6.0)
			out[k * per + i] = (sin(TAU * freqs[k] * t) * 0.5 + sin(TAU * freqs[k] * 2.0 * t) * 0.15) * env
	return _wav(out)
