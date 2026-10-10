extends RefCounted
## A replay is the command log plus everything needed to rebuild the start:
## seed, map id + content hash, and each race as prompt + rules + reroll + key.
## Races are regenerated on load and must reproduce their keys. Checkpoint
## hashes ride along so playback can say exactly where it drifted.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")

const SCHEMA := "aow.replay/1"


static func record(world: World) -> Dictionary:
	var races := []
	for r in world.races:
		races.append({"prompt": r.prompt, "rules": r.rules, "reroll": r.reroll, "key": r.key})
	return {
		"schema": SCHEMA,
		"seed": world.seed_value,
		"map": world.map.id,
		"map_hash": world.map.map_hash,
		"races": races,
		"ticks": world.tick,
		"commands": world.history.duplicate(true),
		"checkpoints": world.hashes.duplicate(true),
	}


static func to_json(rep: Dictionary) -> String:
	return JSON.stringify(rep, "", true)


## JSON numbers come back as floats; turn them back into ints (and refuse real fractions).
static func from_json(text: String) -> Dictionary:
	var d = JSON.parse_string(text)
	assert(d is Dictionary and d.schema == SCHEMA, "Not a replay")
	return _ints(d)


static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			assert(v == floorf(v), "Replay holds a fraction: %s" % v)
			return int(v)
		TYPE_ARRAY:
			return v.map(_ints)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints(v[k])
			return out
	return v


static func save(rep: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(to_json(rep))


static func load_file(path: String) -> Dictionary:
	return from_json(FileAccess.get_file_as_string(path))


## The world at tick 0 with every recorded command queued.
static func build_world(rep: Dictionary, lib: DataLib) -> World:
	var gen := Generator.new(lib)
	var races := []
	for r in rep.races:
		var rules = DataLib.load_json("res://data/rules/%s.json" % r.rules)
		var race: Dictionary = gen.generate(r.prompt, rules, r.reroll)
		assert(race.key == r.key, "Race '%s' regenerated with key %s, replay has %s" % [r.prompt, race.key, r.key])
		races.append(race)
	var map: SimMap = SimMap.load_id(rep.map)
	assert(map.map_hash == rep.map_hash, "Map %s has changed since the replay was recorded" % rep.map)
	var world := World.new(rep.seed, map, races)
	for cmd in rep.commands:
		world.commands.add(cmd)
	return world


## Play to the end. Returns the first tick whose hash differs from the recording, or -1.
static func verify(rep: Dictionary, lib: DataLib) -> int:
	var world := build_world(rep, lib)
	var want := {}
	for c in rep.checkpoints:
		want[c[0]] = c[1]
	while world.tick < rep.ticks:
		world.step()
		if want.has(world.tick) and want[world.tick] != world.hashes[-1][1]:
			return world.tick
	return -1
