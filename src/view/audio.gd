extends Node
## The game's sounds and music, from the files in assets/audio (rendered by
## tools/audio/render.py; names and mixing in data/audio.json). One node for the whole game,
## kept under the tree's root so music carries on across scenes: Audio.of(get_tree()).
##
## - play(name): a sound effect, round-robin over its takes with a little pitch jitter, rate
##   limited per name so a big fight isn't a wall of noise; play_in() for one that lands later.
## - say(voice, kind): a creature's voice (select / ack / die), one at a time.
## - music(mix) and battle(on): the theme's stems, faded between mixes (by age, the lobby, off).
## - ambience(on): the meadow loop under a match.
## View side only; cosmetic randomness is fine here.

const DataLib := preload("res://src/data_lib.gd")
const SILENT := -60.0
const POOL := 24

static var instance: Node

var cfg: Dictionary
var takes := {}         # sound name -> [AudioStreamWAV]
var voices := {}        # "<voice>_<kind>" -> [AudioStreamWAV]
var next_take := {}
var last_at := {}
var players: Array[AudioStreamPlayer] = []
var voice_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var stems: AudioStreamSynchronized
var stem_names: Array = []
var stem_db := {}       # current, faded
var stem_target := {}
var mix_name := "off"
var battle_on := false
var music_enabled := true
var ambience_wanted := false


## The one audio node, made on first use. It joins the root a frame later (a scene's _ready
## can't add to the root at once); calls made before then are deferred to when it has.
static func of(tree: SceneTree) -> Node:
	if instance == null:
		instance = load("res://src/view/audio.gd").new()
		instance.name = "Audio"
		tree.root.add_child.call_deferred(instance)
	return instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # fades carry on while the match is paused
	cfg = DataLib.load_json("res://data/audio.json")
	for bus in cfg.buses:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(i, cfg.buses[bus])
	for n in cfg.sounds:
		takes[n] = []
		for k in int(cfg.sounds[n].takes):
			takes[n].append(_wav("res://assets/audio/sfx/%s_%d.wav" % [n, k + 1]))
	for k in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Ambience"
	var meadow: AudioStreamWAV = takes.meadow[0]
	meadow.loop_mode = AudioStreamWAV.LOOP_FORWARD
	meadow.loop_end = meadow.data.size() / 2
	ambience_player.stream = meadow
	add_child(ambience_player)
	stems = AudioStreamSynchronized.new()
	stem_names = cfg.music.stems
	stems.stream_count = stem_names.size()
	for i in stem_names.size():
		var ogg := AudioStreamOggVorbis.load_from_file("res://assets/audio/music/theme_%s.ogg" % stem_names[i])
		assert(ogg != null, "missing music stem " + stem_names[i])
		ogg.loop = true
		stems.set_sync_stream(i, ogg)
		stems.set_sync_stream_volume(i, SILENT)
		stem_db[stem_names[i]] = SILENT
		stem_target[stem_names[i]] = SILENT
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.stream = stems
	add_child(music_player)


func _ready() -> void:
	_retarget()   # a mix asked for before the node was in the tree
	if ambience_wanted:
		ambience_player.play()


static func _wav(path: String) -> AudioStreamWAV:
	var w := AudioStreamWAV.load_from_file(path)
	assert(w != null, "missing sound " + path)
	return w


## A sound effect; volume_db on top of its bus. Skipped when the same sound played a moment
## ago, or when its voices are all busy, or when every player is.
func play(name: String, volume_db := 0.0) -> void:
	if not is_inside_tree():
		play.call_deferred(name, volume_db)
		return
	var s: Dictionary = cfg.sounds[name]
	var now := Time.get_ticks_msec()
	if now - int(last_at.get(name, -100000)) < int(s.gap_ms):
		return
	var busy := 0
	var free: AudioStreamPlayer = null
	for p in players:
		if p.playing:
			if p.get_meta("sound", "") == name:
				busy += 1
		elif free == null:
			free = p
	if free == null or busy >= int(s.voices):
		return
	last_at[name] = now
	var list: Array = takes[name]
	var k := int(next_take.get(name, 0)) % list.size()
	next_take[name] = k + 1
	free.stream = list[k]
	free.bus = s.bus
	free.pitch_scale = randf_range(0.94, 1.06) if list.size() > 1 else 1.0
	free.volume_db = volume_db
	free.set_meta("sound", name)
	free.play()


## A sound that lands after `delay` seconds (an arrow arriving).
func play_in(name: String, delay: float, volume_db := 0.0) -> void:
	get_tree().create_timer(delay).timeout.connect(func(): play(name, volume_db))


## A creature's voice: kind is "select", "ack" or "die". One voice at a time; a cry (die)
## doesn't interrupt another cry, and nothing interrupts a cry.
func say(voice: String, kind: String, volume_db := 0.0) -> void:
	if not is_inside_tree():
		say.call_deferred(voice, kind, volume_db)
		return
	var key := "%s_%s" % [voice, kind]
	if not voices.has(key):
		var list := []
		for k in int(cfg.voices.kinds[kind]):
			var path := "res://assets/audio/voice/%s_%d.wav" % [key, k + 1]
			if FileAccess.file_exists(path):
				list.append(_wav(path))
		voices[key] = list
	var list: Array = voices[key]
	if list.is_empty():
		return
	var now := Time.get_ticks_msec()
	var gap := int(cfg.voices.die_gap_ms if kind == "die" else cfg.voices.gap_ms)
	if now - int(last_at.get("voice", -100000)) < gap:
		return
	if voice_player.playing and voice_player.get_meta("kind", "") == "die" and kind != "die":
		return
	last_at["voice"] = now
	var k := int(next_take.get(key, 0)) % list.size()
	next_take[key] = k + 1
	voice_player.stream = list[k]
	voice_player.pitch_scale = randf_range(0.93, 1.07)
	voice_player.volume_db = volume_db
	voice_player.set_meta("kind", kind)
	voice_player.play()


## The theme in one of data/audio.json's mixes ("lobby", "age1".."age4", "off"); stems
## fade in and out over fade_s.
func music(mix: String) -> void:
	mix_name = mix
	_retarget()


func music_age(age: int) -> void:
	music("age%d" % clampi(age, 1, 4))


## The battle layer, while there's fighting near the camera.
func battle(on: bool) -> void:
	if on != battle_on:
		battle_on = on
		_retarget()


func toggle_music() -> bool:
	music_enabled = not music_enabled
	_retarget()
	return music_enabled


func ambience(on: bool) -> void:
	ambience_wanted = on
	if not is_inside_tree():
		return
	if on and not ambience_player.playing:
		ambience_player.play()
	elif not on:
		ambience_player.stop()


func _retarget() -> void:
	var levels: Dictionary = cfg.music.mixes[mix_name]
	for n in stem_names:
		var db := float(levels.get(n, SILENT))
		if n == "battle":
			db = float(cfg.music.battle_db) if battle_on and mix_name != "off" and mix_name != "lobby" else SILENT
		stem_target[n] = db if music_enabled else SILENT
	var any := stem_target.values().any(func(v): return v > SILENT)
	if any and is_inside_tree() and not music_player.playing:
		music_player.play()


func _process(delta: float) -> void:
	if not music_player.playing:
		return
	var step := (0.0 - SILENT) * delta / float(cfg.music.fade_s)
	var all_silent := true
	for i in stem_names.size():
		var n: String = stem_names[i]
		var cur: float = stem_db[n]
		var want: float = stem_target[n]
		if cur != want:
			cur = move_toward(cur, want, step)
			stem_db[n] = cur
			stems.set_sync_stream_volume(i, cur)
		if cur > SILENT:
			all_silent = false
	if all_silent:
		music_player.stop()   # restarts from the top next time it's wanted
