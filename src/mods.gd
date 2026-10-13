extends RefCounted
## Mods (milestone 21, docs/milestones/m21-modability.md, docs/modding.md): a mod is a folder of more
## data (data/ overlays: parts, creatures, families, palettes, lexicon words, rules, maps, shot looks)
## plus the models its parts are built from (a model script extending unit_models.gd, or .glb files)
## and their textures, with a manifest (mod.json). No code hooks into the game: the only code a mod
## carries builds 3D models for the bake.
##
## Found in ROOTS (the dev folders in the project and user://mods), used only when asked for: the
## environment (AOW_MODS=a,b), the command line (--mods=a,b) or user://mods.json {"enabled": [...]}.
## Tests and sheets call use(). Every DataLib made after that has the mods merged over the base data,
## in load order (manifest load_order, then id: stable, so every machine merges the same way).
## A mod that fails its checks is refused with the reason (refused), and nothing of it is used.
## Static state, like UnitModels.extra: one mod set per process.

const GAME_VERSION := "0.21"
const ROOTS := ["user://mods", "res://mods", "res://mods_private"]   # (a later folder's copy of a mod wins: the dev folders over an installed one)
static var test_roots: Array = []   # more folders to look in (tests/mods: the refusal fixtures)
const SETTINGS := "user://mods.json"
## The data files a mod may overlay (more come as the game's data grows a merge rule for them).
const DATA_FILES := ["parts.json", "creatures.json", "families.json", "palettes.json", "lexicon.json", "shots.json"]
const DATA_DIRS := ["rules", "maps"]
const BASE_ERAS := ["bronze", "medieval", "gunpowder"]

static var active: Array = []    # mod records in load order: {id, dir, manifest, data: {file: parsed}, sig}
static var refused := {}         # id -> why it was refused
static var shots := {}           # shot looks added by mods (CombatFx: kind -> {tag, speed, arc, len, w, col, glow?})
static var glb_parts := {}       # part id -> absolute path of its .glb (UnitModels builds these)
static var _models: Array = []   # model script instances this module added to UnitModels.extra
static var _ready := false


## Every mod folder found: id -> {dir, manifest}. A folder without a mod.json is skipped; a mod in two
## folders is the later folder's (ROOTS order).
static func discover() -> Dictionary:
	var out := {}
	for root in ROOTS + test_roots:
		if not DirAccess.dir_exists_absolute(root):
			continue
		var dirs := Array(DirAccess.get_directories_at(root))
		dirs.sort()
		for d in dirs:
			var dir: String = root + "/" + d
			if not FileAccess.file_exists(dir + "/mod.json"):
				continue
			var m = JSON.parse_string(FileAccess.get_file_as_string(dir + "/mod.json"))
			var id: String = m.get("id", d) if m is Dictionary else d
			out[id] = {"dir": dir, "manifest": m}
	return out


## The mods asked for: AOW_MODS, then --mods=, then user://mods.json.
static func requested() -> Array:
	var env := OS.get_environment("AOW_MODS")
	if env != "":
		return Array(env.split(",", false))
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--mods="):
			return Array(a.trim_prefix("--mods=").split(",", false))
	if FileAccess.file_exists(SETTINGS):
		var s = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if s is Dictionary:
			return s.get("enabled", [])
	return []


## Use the requested mods, once per process (DataLib calls this).
static func ensure() -> void:
	if not _ready:
		use(requested())


## Use exactly these mods (by id; [] for none), checked against the base data in load order.
## Returns the ids in use.
static func use(ids: Array) -> Array:
	_ready = true
	_reset()
	var found := discover()
	var picked := []
	for id in ids:
		if not found.has(id):
			refused[id] = "not found in %s" % ", ".join(ROOTS)
			continue
		var why := _check_manifest(id, found[id].manifest)
		if why != "":
			refused[id] = why
			continue
		picked.append({"id": id, "dir": found[id].dir, "manifest": found[id].manifest})
	picked.sort_custom(func(a, b): return [int(a.manifest.get("load_order", 100)), a.id] < [int(b.manifest.get("load_order", 100)), b.id])
	var DataLib = load("res://src/data_lib.gd")
	var lib = DataLib.new("res://data", false)
	var eras: Array = BASE_ERAS.duplicate()
	for m in picked:
		for dep in m.manifest.get("depends", []):
			if not active.any(func(a): return a.id == dep):
				refused[m.id] = "needs the mod '%s' loaded before it" % dep
				break
		if refused.has(m.id):
			continue
		var rec := _read(m)
		if rec.has("error"):
			refused[m.id] = rec.error
			continue
		var with_own: Array = eras + m.manifest.get("eras", [])
		var models := _load_models(rec)
		var why := _check_data(rec, lib, with_own, models)
		if why != "":
			refused[m.id] = why
			_drop_models(models)
			continue
		eras = with_own
		_apply(lib, rec)
		active.append(rec)
	for id in refused:
		print("Mod '%s' refused: %s" % [id, refused[id]])
	return active.map(func(a): return a.id)


static func _reset() -> void:
	active = []
	refused = {}
	shots = {}
	glb_parts = {}
	_drop_models(_models)
	_models = []


static func _check_manifest(id: String, m) -> String:
	if not m is Dictionary:
		return "mod.json isn't a JSON object"
	for key in ["id", "name", "version", "game_version"]:
		if not m.has(key):
			return "mod.json has no '%s'" % key
	if m.id != id:
		return "mod.json's id '%s' isn't the folder's" % m.id
	var want: Array = Array(str(m.game_version).split("."))
	var have: Array = Array(GAME_VERSION.split("."))
	if want[0] != have[0] or int(want[1]) > int(have[1]):
		return "made for game version %s; this is %s" % [m.game_version, GAME_VERSION]
	return ""


## The mod's data files, parsed: {file: data} (rules/<id>.json and maps/<id>.json by their paths).
static func _read(m: Dictionary) -> Dictionary:
	var rec := m.duplicate()
	rec.data = {}
	var root: String = m.dir + "/" + str(m.manifest.get("data", "data"))
	if DirAccess.dir_exists_absolute(root):
		for f in _files(root, ""):
			if not (f in DATA_FILES or (f.get_base_dir() in DATA_DIRS and f.ends_with(".json"))):
				return {"error": "data/%s can't be modded yet (moddable: %s, rules/*.json, maps/*.json)" % [f, ", ".join(DATA_FILES)]}
			var d = JSON.parse_string(FileAccess.get_file_as_string(root + "/" + f))
			if d == null:
				return {"error": "data/%s isn't valid JSON" % f}
			rec.data[f] = d
	# The hash is of the parsed data, not the files' bytes (line endings differ between checkouts).
	rec.sig = "%s@%s#%s" % [m.id, m.manifest.version, JSON.stringify(rec.data, "", true).sha256_text().substr(0, 8)]
	return rec


static func _load_models(rec: Dictionary) -> Array:
	var UnitModels = load("res://scenes/art_pixel/unit_models.gd")
	var out := []
	for path in rec.manifest.get("models", []):
		if str(path).ends_with(".gd"):
			var script = load(rec.dir + "/" + path)
			assert(script != null, "Mod '%s': can't load %s" % [rec.id, path])
			var inst = script.new()
			UnitModels.extra.append(inst)
			out.append(inst)
	_models += out
	return out


static func _drop_models(models: Array) -> void:
	var UnitModels = load("res://scenes/art_pixel/unit_models.gd")
	for m in models:
		UnitModels.extra.erase(m)
		_models.erase(m)


## What's wrong with a mod's data against the data before it (the base and earlier mods), or "".
static func _check_data(rec: Dictionary, lib, eras: Array, models: Array) -> String:
	var d: Dictionary = rec.data
	var slots := {}
	for id in lib.parts:
		slots[lib.parts[id].slot] = true
	var replaces: Array = rec.manifest.get("replaces", [])
	var UnitModels = load("res://scenes/art_pixel/unit_models.gd")
	var um = UnitModels.new()
	var new_parts := {}
	for p in d.get("parts.json", []):
		if not p is Dictionary or not p.get("id") is String:
			return "parts.json: a part without an id"
		var at := "parts.json %s: " % p.id
		if lib.parts.has(p.id) and not p.id in replaces:
			return at + "already a part (list it in the manifest's 'replaces' to replace it)"
		if not slots.has(p.get("slot", "")):
			return at + "unknown slot '%s'" % p.get("slot", "")
		if not (p.get("points") is float or p.get("points") is int) or int(p.points) < 0:
			return at + "needs whole 'points' (its price comes from them)"
		if not p.get("tags", null) is Array:
			return at + "needs 'tags' (a list)"
		for e in p.get("era", []):
			if not e in eras:
				return at + "era '%s' isn't the game's or in the manifest's 'eras'" % e
		if int(p.get("tier", 1)) < 1 or int(p.get("tier", 1)) > 3:
			return at + "tier must be 1-3"
		if p.slot in ["body", "head"] and not p.has("sockets"):
			return at + "a %s needs its sockets" % p.slot
		if p.has("glb"):
			if not FileAccess.file_exists(rec.dir + "/" + p.glb):
				return at + "its model %s isn't in the mod" % p.glb
		elif not um.has(p.id):
			return at + "no model: add _%s(c) to a model script in the manifest's 'models', or a 'glb'" % p.id.replace(".", "_")
		new_parts[p.id] = p
	var has_part := func(id): return lib.parts.has(id) or new_parts.has(id)
	var creatures: Dictionary = d.get("creatures.json", {})
	var families: Dictionary = d.get("families.json", {})
	for id in creatures:
		if id.begins_with("_"):
			continue
		var c: Dictionary = creatures[id]
		if c.has("extends"):
			if not lib.creatures.has(c.extends):
				return "creatures.json %s: extends unknown creature '%s'" % [id, c.extends]
			c = merge(lib.creatures[c.extends], c)
		for key in ["body", "head"]:
			if not has_part.call(c.get(key, "")):
				return "creatures.json %s: its %s '%s' isn't a part" % [id, key, c.get(key, "")]
		for f in c.get("families", []):
			if not lib.families.has(f) and not families.has(f):
				return "creatures.json %s: unknown culture '%s'" % [id, f]
	for id in families:
		if not id.begins_with("_") and families[id].has("extends") and not lib.families.has(families[id].extends):
			return "families.json %s: extends unknown culture '%s'" % [id, families[id].extends]
	for w in d.get("lexicon.json", {}).get("words", {}):
		if w.begins_with("_"):
			continue
		var e: Dictionary = d["lexicon.json"].words[w]
		if e.has("creature") and not lib.creatures.has(e.creature) and not creatures.has(e.creature):
			return "lexicon.json '%s': unknown creature '%s'" % [w, e.creature]
		if e.has("family") and not lib.families.has(e.family) and not families.has(e.family):
			return "lexicon.json '%s': unknown culture '%s'" % [w, e.family]
		if e.has("era") and not e.era in eras:
			return "lexicon.json '%s': unknown era '%s'" % [w, e.era]
		if e.has("era") and not e.has("note"):
			return "lexicon.json '%s': an era word needs a 'note' for hosts that keep that era out" % w
	for f in d:
		if f.begins_with("rules/"):
			var base_path: String = "res://data/" + f
			var r: Dictionary = d[f]
			if not FileAccess.file_exists(base_path) and not r.has("extends") and not r.has("roster"):
				return "%s: neither a game rule to change, nor 'extends' one, nor a whole rule" % f
			for e in r.get("+era", []) + r.get("era", []):
				if not e in eras:
					return "%s: unknown era '%s'" % [f, e]
	for k in d.get("shots.json", {}):
		if k.begins_with("_"):
			continue
		var s: Dictionary = d["shots.json"][k]
		for key in ["tag", "speed", "col"]:
			if not s.has(key):
				return "shots.json %s: needs '%s'" % [k, key]
	return ""


## Merge a mod's data into a DataLib (base data first, then each mod in load order).
static func _apply(lib, rec: Dictionary) -> void:
	var d: Dictionary = rec.data
	for p in d.get("parts.json", []):
		var q: Dictionary = p.duplicate(true)
		lib.parts[q.id] = q
		if q.has("glb"):
			glb_parts[q.id] = rec.dir + "/" + q.glb
	var Identity = load("res://src/identity.gd")
	for id in d.get("creatures.json", {}):
		if id.begins_with("_"):
			continue
		var ec: Dictionary = _extended(lib.creatures, d["creatures.json"][id])
		lib.creatures[id] = ec
		Identity.files().creatures[id] = ec
	for id in d.get("families.json", {}):
		if id.begins_with("_"):
			continue
		var ef: Dictionary = _extended(lib.families, d["families.json"][id])
		lib.families[id] = ef
		Identity.files().families[id] = ef
	lib.palettes = merge(lib.palettes, d.get("palettes.json", {}))
	var lex: Dictionary = d.get("lexicon.json", {})
	for w in lex.get("words", {}):
		if w.begins_with("_"):
			continue
		lib.lexicon[w] = lex.words[w]
	for w in lex.get("stopwords", []):
		lib.stopwords[w] = true
	for k in d.get("shots.json", {}):
		if not k.begins_with("_"):   # ("_doc" notes are for people)
			shots[k] = d["shots.json"][k]
	lib.mods.append(rec.sig)


## A creature or culture that "extends" another (by id) is that one with its own keys over it.
static func _extended(all: Dictionary, e: Dictionary) -> Dictionary:
	if not e.has("extends"):
		return e
	var out := merge(all[e.extends], e)
	out.erase("extends")
	return out


## Called by DataLib: the mods in use merged over it.
static func apply(lib) -> void:
	ensure()
	for rec in active:
		_apply(lib, rec)


## A host rule (data/rules/<id>.json) with every mod's change to it, in load order. A mod's
## rules/<id>.json changes a game rule (a deep merge; "+key": [...] appends to that list), or adds a
## rule of its own ("extends": another rule's id, then changes; or a whole rule).
static func rules(id: String) -> Dictionary:
	ensure()
	var DataLib = load("res://src/data_lib.gd")
	var path := "res://data/rules/%s.json" % id
	var out: Dictionary = DataLib.load_json(path) if FileAccess.file_exists(path) else {}
	for rec in active:
		var r = rec.data.get("rules/%s.json" % id)
		if r == null:
			continue
		if out.is_empty() and r.has("extends"):
			out = rules(r.extends)
			out.id = id
		var change: Dictionary = r.duplicate(true)
		change.erase("extends")
		out = merge(out, change)
	assert(not out.is_empty(), "Unknown rules: %s" % id)
	return out


## Where a data file comes from: the last mod in load order that has it, else the game's.
## (Maps: "maps/<id>.json".)
static func data_path(rel: String) -> String:
	ensure()
	for i in range(active.size() - 1, -1, -1):
		var rec: Dictionary = active[i]
		if rec.data.has(rel):
			return rec.dir + "/" + str(rec.manifest.get("data", "data")) + "/" + rel
	return "res://data/" + rel


## The map ids the game and the mods in use offer, sorted.
static func map_ids() -> Array:
	ensure()
	var ids := {}
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.ends_with(".json"):
			ids[f.get_basename()] = true
	for rec in active:
		for f in rec.data:
			if f.begins_with("maps/"):
				ids[f.get_file().get_basename()] = true
	var out := ids.keys()
	out.sort()
	return out


## The mods in use as the race key holds them: "id@version#hash" in load order.
static func signature() -> Array:
	ensure()
	return active.map(func(a): return a.sig)


## The mods a race was made with that aren't in use here ([]: it can be played).
static func missing(race: Dictionary) -> Array:
	var have := signature()
	return race.get("mods", []).filter(func(s): return not s in have)


## Every file of every mod in use (for the bake cache's version: a changed model or texture bakes fresh).
static func files() -> Array:
	ensure()
	var out := []
	for rec in active:
		for f in _files(rec.dir, ""):
			out.append(rec.dir + "/" + f)
	return out


## Deep merge: b's keys over a's; dictionaries merge; "+key": [...] appends to a's list at key.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b:
		if key.begins_with("+"):
			var k: String = key.substr(1)
			var list: Array = out.get(k, []).duplicate()
			for v in b[key]:
				if not v in list:
					list.append(v)
			out[k] = list
		elif out.has(key) and out[key] is Dictionary and b[key] is Dictionary:
			out[key] = merge(out[key], b[key])
		else:
			out[key] = b[key].duplicate(true) if (b[key] is Dictionary or b[key] is Array) else b[key]
	return out


## Files under dir (relative paths, sorted; .import and .uid left out).
static func _files(dir: String, rel: String) -> Array:
	var out := []
	var here := dir if rel == "" else dir + "/" + rel
	var fs := Array(DirAccess.get_files_at(here))
	fs.sort()
	for f in fs:
		if not f.ends_with(".import") and not f.ends_with(".uid") and f != ".DS_Store":
			out.append(f if rel == "" else rel + "/" + f)
	var ds := Array(DirAccess.get_directories_at(here))
	ds.sort()
	for d in ds:
		out += _files(dir, d if rel == "" else rel + "/" + d)
	return out

