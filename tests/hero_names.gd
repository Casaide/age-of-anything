extends SceneTree
## Hero names (concept round HR2, 2026-10-13; D-127): the naming contract in data/later/heroes.json
## (hero_names, hero_signatures) run on real races. For each prompt: the race key, the hero the race
## would get (its signature picked from the ones its creature or culture may have), and the name each
## of those signatures would carry (the sheets' labels). Deterministic: src/rng.gd seeded from the race
## key. Nothing in play reads this yet. Run:
##   godot --headless --path . --script res://tests/hero_names.gd -- "sewer rats" "romans" ...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Rng := preload("res://src/rng.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")

const HEROES := "res://data/later/heroes.json"


func _init() -> void:
	var lib = DataLib.new()
	CreatureKit.stage(lib, "res://data/later/bears.json")
	var data: Dictionary = DataLib.load_json(HEROES)
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	for p in OS.get_cmdline_user_args():
		var race: Dictionary = gen.generate(p, rules)
		var sigs := signatures_for(data, race.creature, race.family)
		print("\n== \"%s\"  %s/%s  key %s" % [p, race.creature, race.family, race.key.substr(0, 12)])
		if sigs.is_empty():
			print("   (no signature for this creature or culture)")
			continue
		var h := hero(data, race.key, race.creature, race.family)
		print("   the race's hero: %s  [%s]  %s" % [h.name, h.signature, data.hero_signatures[h.signature].temper])
		for s in sigs:
			print("   as %-12s %s" % [s, hero(data, race.key, race.creature, race.family, s).name])
	quit()


## The signatures a race may have: those naming its creature or its culture, sorted by id.
static func signatures_for(data: Dictionary, creature: String, family: String) -> Array:
	var out := []
	for id in data.hero_signatures:
		var who: Dictionary = data.hero_signatures[id].who
		if creature in who.get("creature", []) or family in who.get("family", []):
			out.append(id)
	out.sort()
	return out


## A race's hero: {signature, name}. `force` names the signature (the sheets show each look a race
## could have, each with the name it would carry).
static func hero(data: Dictionary, key: String, creature: String, family: String, force := "") -> Dictionary:
	var rng = Rng.new(Rng.hash_string(key + "|hero"))
	var sigs := signatures_for(data, creature, family)
	var sid: String = rng.pick(sigs)
	if force != "" and force != sid:   # (another look than the race's own: its own draw)
		sid = force
		rng = Rng.new(Rng.hash_string(key + "|hero|" + force))
	var s: Dictionary = data.hero_signatures[sid]
	var n: Dictionary = data.hero_names
	var pool: Array = n.creatures.get(creature, {}).get("names", []) + n.families.get(family, {}).get("names", [])
	var titles: Array = s.get("titles", n.creatures.get(creature, {}).get("titles", []) + n.families.get(family, {}).get("titles", []))
	var fmt: String = n.formats[rng.pick(s.formats)]
	var any := func(a: Array) -> String: return rng.pick(a) if not a.is_empty() else ""
	var name: String = fmt.format({"name": any.call(pool), "epithet": any.call(s.epithets), "nickname": any.call(s.get("nicknames", [])),
		"title": any.call(titles), "ordinal": rng.pick(n.ordinals)})
	return {"signature": sid, "name": name}
