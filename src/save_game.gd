extends RefCounted
## Saving and loading a match (D-140). A save holds two things:
## - the snapshot: every script variable of the World and of each bot, sub-objects and all (they
##   are ints, packed int arrays and data dicts: no Nodes, no callables). Loading builds the match
##   as at its start (so every constructor runs), pours the snapshot over it and checks the state
##   hash. That takes a moment, however long the match ran.
## - the match as a replay up to now (races as prompt + rules + reroll + key, map, rules, seed,
##   teams, every command a person gave, those that ran and those still waiting) plus who the bots
##   are. When the snapshot doesn't fit this build (a sim or AI variable came or went, or the hash
##   is off), loading plays the match forward from its start instead, headless, the bots thinking
##   as they did (deterministic: same world, same commands); slow for a long match, and a build
##   whose sim plays differently goes on from wherever its re-run got to (`drift` says where).
## Bots' own commands are not stored: they give them again on the way.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Replay := preload("res://src/sim/replay.gd")
const Bot := preload("res://src/ai/bot.gd")

const SCHEMA := "aow.save/1"
static var dir := "user://saves"   # (tests/save_check.gd points it elsewhere)
const EXT := "save"
const SCRIPT := "__script"   # an encoded object's script path (the rest of its dict are its variables)


## seats: [{player, level, from_seq}] for each bot (from_seq: the player's next seq when its bot
## took over; the commands before it, e.g. a test army, are the player's own). bots: those bots,
## in seat order. view: what the match screen needs to come back (the side you command, the AI
## levels, the prompts...).
static func record(world: World, seats: Array, bots: Array, view := {}) -> Dictionary:
	assert(seats.size() == bots.size(), "a seat per bot")
	var rep := Replay.record(world)
	rep.schema = SCHEMA
	var bot_from := {}
	for s in seats:
		bot_from[s.player] = s.from_seq
	var keep := func(c): return not bot_from.has(c.player) or c.seq < bot_from[c.player]
	rep.commands = rep.commands.filter(keep)
	var waiting := []
	for run in world.commands.pending:
		waiting.append_array(world.commands.pending[run])
	waiting.sort_custom(func(a, b): return [a.turn, a.player, a.seq] < [b.turn, b.player, b.seq])
	rep.commands.append_array(waiting.filter(keep).map(func(c): return c.duplicate(true)))
	rep.bots = seats.duplicate(true)
	rep.hash = world.state_hash()
	rep.view = view.duplicate(true)
	rep.saved_at = Time.get_datetime_string_from_system()
	rep.snapshot = {"world": encode(world), "bots": bots.map(encode)}
	return rep


static func save(rep: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var(rep)
	f.close()


static func load_file(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var d = f.get_var()
	assert(d is Dictionary and d.get("schema") == SCHEMA, "Not a saved match: %s" % path)
	return d


## The saves on disk, newest first: [{path, saved_at, ticks, view}].
static func list() -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == EXT:
			var rep := load_file(dir.path_join(f))
			out.append({"path": dir.path_join(f), "saved_at": rep.saved_at, "ticks": rep.ticks, "view": rep.view})
	out.sort_custom(func(a, b): return a.saved_at > b.saved_at)
	return out


## A new file name for a save made now (named by the time; never overwrites one).
static func new_path() -> String:
	var t := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := dir.path_join("%s.%s" % [t, EXT])
	var n := 2
	while FileAccess.file_exists(path):
		path = dir.path_join("%s_%d.%s" % [t, n, EXT])
		n += 1
	return path


## Why this save can't be rebuilt in this build (a race, map or rules changed), or "".
static func problem(rep: Dictionary, lib: DataLib) -> String:
	var gen := Generator.new(lib)
	for r in rep.races:
		if gen.generate(r.prompt, DataLib.load_rules(r.rules), r.reroll).key != r.key:
			return "The race \"%s\" comes out differently in this version." % r.prompt
	if not FileAccess.file_exists("res://data/maps/%s.json" % rep.map):
		return "The map %s is gone." % rep.map
	if SimMap.load_id(rep.map).map_hash != rep.map_hash:
		return "The map %s has changed since the save." % rep.map
	if Replay.rules_hash(rep.rules_data) != rep.rules_hash:
		return "The save's rules are damaged."
	return ""


## The match as it was saved: {world, bots, rep, fast}. fast: the snapshot fitted and the world
## is already at the saved tick; otherwise it is at tick 0 and `run` plays it there.
static func begin(rep: Dictionary, lib: DataLib) -> Dictionary:
	var ld := _fresh(rep, lib)
	if rep.has("snapshot") and _restore(ld, rep.snapshot) and ld.world.tick == rep.ticks and ld.world.state_hash() == rep.hash:
		ld.fast = true
		return ld
	return _fresh(rep, lib)   # (a half-poured snapshot is thrown away)


## The match at tick 0, every command a person gave queued, the bots seated.
static func _fresh(rep: Dictionary, lib: DataLib) -> Dictionary:
	var world: World = Replay.build_world(rep, lib)
	var bots := []
	for s in rep.bots:
		bots.append(Bot.new(s.player, {}, s.level))
	return {"world": world, "bots": bots, "rep": rep, "fast": false}


static func _restore(ld: Dictionary, snap: Dictionary) -> bool:
	if snap.bots.size() != ld.bots.size() or not pour(ld.world, snap.world):
		return false
	for i in ld.bots.size():
		if not pour(ld.bots[i], snap.bots[i]):
			return false
	return true


## Play on towards the saved tick for at most `budget_usec` (0: all the way). True once there.
static func run(ld: Dictionary, budget_usec := 0) -> bool:
	var world: World = ld.world
	var end: int = ld.rep.ticks
	var t0 := Time.get_ticks_usec()
	while world.tick < end:
		for bot in ld.bots:
			bot.think(world)
		world.step()
		if budget_usec > 0 and Time.get_ticks_usec() - t0 > budget_usec:
			break
	return world.tick >= end


## The tick where the loaded match first differs from the saved one, or -1 (it matches).
static func drift(ld: Dictionary) -> int:
	var world: World = ld.world
	var want := {}
	for c in ld.rep.checkpoints:
		want[c[0]] = c[1]
	for h in world.hashes:
		if want.has(h[0]) and want[h[0]] != h[1]:
			return h[0]
	return -1 if world.state_hash() == ld.rep.hash else world.tick


## How far a load has got (0..1).
static func progress(ld: Dictionary) -> float:
	return float(ld.world.tick) / maxf(1.0, ld.rep.ticks)


# ------------------------------------------------------------------ the snapshot

## An object as a dict of its script variables (sub-objects the same way, arrays and dicts copied
## deep); everything else is a plain value (packed arrays are copied on write).
static func encode(v):
	match typeof(v):
		TYPE_OBJECT:
			assert(v != null and v.get_script() != null, "Only script objects go in a save")
			var out := {SCRIPT: v.get_script().resource_path}
			for name in _vars(v):
				out[name] = encode(v.get(name))
			return out
		TYPE_ARRAY:
			return v.map(encode)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = encode(v[k])
			return out
		TYPE_CALLABLE, TYPE_SIGNAL:
			assert(false, "A callable can't go in a save")
	return v


## Pour an encoded object's variables into obj (the same script). False when they don't match
## this build's variables (one came or went, here or in a sub-object).
static func pour(obj: Object, enc: Dictionary) -> bool:
	_misfit = false
	_pour(obj, enc)
	return not _misfit


static var _misfit := false


static func _pour(obj: Object, enc: Dictionary) -> void:
	var names := _vars(obj)
	if obj.get_script().resource_path != enc[SCRIPT] or names.size() != enc.size() - 1 or not names.all(func(n): return enc.has(n)):
		_misfit = true
		return
	for name in names:
		obj.set(name, _decode(obj.get(name), enc[name]))


## A value back from its encoding; an object goes into the one already there when it has the same
## script (its constructor ran with the right arguments), else into a new one (no-argument
## constructors only).
static func _decode(cur, enc):
	match typeof(enc):
		TYPE_DICTIONARY:
			if enc.has(SCRIPT):
				var same: bool = cur is Object and cur.get_script() != null and cur.get_script().resource_path == enc[SCRIPT]
				var obj = cur if same else load(enc[SCRIPT]).new()
				_pour(obj, enc)
				return obj
			var out := {}
			var had: Dictionary = cur if cur is Dictionary else {}
			for k in enc:
				out[k] = _decode(had.get(k), enc[k])
			return out
		TYPE_ARRAY:
			var had: Array = cur if cur is Array else []
			var out := []
			out.resize(enc.size())
			for i in enc.size():
				out[i] = _decode(had[i] if i < had.size() else null, enc[i])
			return out
	return enc


static func _vars(obj: Object) -> Array:
	var out := []
	for p in obj.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p.name)
	return out
