extends RefCounted
## Saving and loading a match (D-140, D-141). A save is a snapshot: every script variable of the
## World and of each bot, sub-objects and all (ints, packed int arrays, data dicts: no Nodes, no
## callables). Loading builds the match as at its start, so every constructor runs, then pours the
## snapshot over it: about 0.1 s however long the match ran. It never replays the match.
## A save from another build still loads:
## - the races, the rules and the data tables built from data files (unit types, buildings, tech,
##   the bots' config: DATA) keep the save's values, and gain any key this build added;
## - a variable this build added keeps the value its constructor gave it; units and buildings pad
##   their per-unit arrays to their count (0, or [] for lists); a class whose new variable needs
##   something better says so in `after_load(missing)`;
## - a variable this build dropped is ignored.
## The save also keeps the match as a replay (races as prompt + rules + reroll + key, map, seed,
## teams, every command a person gave) for watching back and debugging, not for loading.
## A save needs only its map's file to be there.

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


## Why this save can't be loaded in this build, or "".
static func problem(rep: Dictionary, _lib: DataLib) -> String:
	if not FileAccess.file_exists("res://data/maps/%s.json" % rep.map):
		return "Its map, %s, is gone." % rep.map
	return ""


## The match as it was saved: {world, bots, rep, same, changed}. same: the state hash is the saved
## one (a save from this build always is); changed: the variables a build changed since, by path.
static func begin(rep: Dictionary, lib: DataLib) -> Dictionary:
	var snap: Dictionary = rep.snapshot
	var gen := Generator.new(lib)
	var races := []
	for i in rep.races.size():
		var r: Dictionary = rep.races[i]
		var saved: Dictionary = snap.world.races[i]
		if FileAccess.file_exists("res://data/rules/%s.json" % r.rules):   # this build's take, for any field it added
			saved = merge(gen.generate(r.prompt, DataLib.load_rules(r.rules), r.reroll), saved)
		races.append(saved)
	var rules = rep.rules_data
	if FileAccess.file_exists("res://data/rules/%s.json" % rep.rules):
		rules = merge(DataLib.load_rules(rep.rules), rules)
	var world := World.new(rep.seed, SimMap.load_id(rep.map), races, rules, rep.teams)
	var bots := []
	for s in rep.bots:
		bots.append(Bot.new(s.player, {}, s.level))
	_changed = []
	_pour(world, snap.world, "world")
	for i in bots.size():
		_pour(bots[i], snap.bots[i], "bot%d" % i)
	assert(world.tick == rep.ticks, "the snapshot is at the saved tick")
	return {"world": world, "bots": bots, "rep": rep, "same": world.state_hash() == rep.hash, "changed": _changed.duplicate()}


# ------------------------------------------------------------------ the snapshot

## An object as a dict of its script variables (sub-objects the same way); everything copied (packed
## arrays too: they are passed by reference, so a save would change as the match plays on).
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
	return _copy(v)


## Data a World or bot is built from (DATA): merged, the save's values over this build's.
const DATA := {
	"res://src/sim/world.gd": ["races", "rules", "econ", "combat", "high", "classes", "tech", "types", "btypes", "resources",
		"gather_spots", "hero_cfg", "move_pct", "fog_cfg", "bridge_cfg", "trail_cfg", "garrison_cfg", "walk_cfg", "repair_cfg",
		"mode_cfg", "ident", "claim_tiles"],
	"res://src/ai/bot.gd": ["cfg"],
}

static var _changed: Array = []   # what a load found changed, by path ("world.units.wtime: new")


## Pour an encoded object's variables into obj, then let it fix up what the save didn't have.
static func _pour(obj: Object, enc: Dictionary, path: String) -> void:
	var path_s: String = obj.get_script().resource_path
	var data: Array = DATA.get(path_s, [])
	var declared := {}
	for p in obj.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared[p.name] = p.type
	var missing := []
	for name in declared:
		if not enc.has(name):
			missing.append(name)
			_changed.append("%s.%s: new" % [path, name])
			continue
		var cur = obj.get(name)
		var v = merge(cur, enc[name]) if name in data else _decode(cur, enc[name], "%s.%s" % [path, name])
		if declared[name] != TYPE_NIL and typeof(v) != declared[name]:
			missing.append(name)   # its type changed: this build's value stays
			_changed.append("%s.%s: retyped" % [path, name])
			continue
		obj.set(name, v)
	for name in enc:
		if name != SCRIPT and not declared.has(name):
			_changed.append("%s.%s: gone" % [path, name])
	if not missing.is_empty() and obj.has_method("count"):   # units, buildings: per-unit arrays
		var n: int = obj.count()
		for name in missing:
			var v = obj.get(name)
			if typeof(v) >= TYPE_ARRAY and typeof(v) != TYPE_DICTIONARY and v.size() != n:
				if v is Array:
					var was: int = v.size()
					v.resize(n)
					for i in range(was, n):
						v[i] = []
				else:
					v.resize(n)
				obj.set(name, v)
	if obj.has_method("after_load"):
		obj.after_load(missing)


## A value back from its encoding; an object goes into the one already there when it has the same
## script (its constructor ran with the right arguments), else into a new one (no-argument
## constructors only). A class this build replaced keeps this build's object.
static func _decode(cur, enc, path: String):
	match typeof(enc):
		TYPE_DICTIONARY:
			if enc.has(SCRIPT):
				if cur is Object and cur.get_script() != null and cur.get_script().resource_path == enc[SCRIPT]:
					_pour(cur, enc, path)
					return cur
				if cur is Object or not ResourceLoader.exists(enc[SCRIPT]):
					_changed.append("%s: replaced" % path)
					return cur
				var obj = load(enc[SCRIPT]).new()
				_pour(obj, enc, path)
				return obj
			var out := {}
			var had: Dictionary = cur if cur is Dictionary else {}
			for k in enc:
				out[k] = _decode(had.get(k), enc[k], path)
			return out
		TYPE_ARRAY:
			var had: Array = cur if cur is Array else []
			var out := []
			out.resize(enc.size())
			for i in enc.size():
				out[i] = _decode(had[i] if i < had.size() else null, enc[i], path)
			return out
	return _copy(enc)


## Data merged: the saved values (b) over this build's (a); keys only this build has come in.
## Lists of dicts pair up by id (or slot and tier), else by place.
static func merge(a, b):
	if a is Dictionary and b is Dictionary:
		var out := {}
		for k in b:
			out[k] = merge(a[k], b[k]) if a.has(k) else _copy(b[k])
		for k in a:
			if not out.has(k):
				out[k] = a[k]
		return out
	if a is Array and b is Array:
		var by := _keyed(a)
		var out := []
		for i in b.size():
			var k := _key(b[i])
			var m = by[k] if k != "" and by.has(k) else (a[i] if by.is_empty() and i < a.size() else null)
			out.append(_copy(b[i]) if m == null else merge(m, b[i]))
		return out
	return _copy(b)


## Its own copy (the match plays on with it; the save it came from must not change).
static func _copy(v):
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v.duplicate() if typeof(v) >= TYPE_PACKED_BYTE_ARRAY else v


static func _key(e) -> String:
	if not e is Dictionary:
		return ""
	if e.has("id"):
		return "id:%s" % e.id
	if e.has("slot"):
		return "slot:%s/%s/%s/%s" % [e.slot, e.get("tier", ""), e.get("unique", ""), e.get("name", "")]
	return ""


## Keyed entries of a list, or {} when they don't key uniquely (then entries pair by place).
static func _keyed(a: Array) -> Dictionary:
	var by := {}
	for e in a:
		var k := _key(e)
		if k == "" or by.has(k):
			return {}
		by[k] = e
	return by


static func _vars(obj: Object) -> Array:
	var out := []
	for p in obj.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p.name)
	return out
