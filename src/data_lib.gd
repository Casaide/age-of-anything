extends RefCounted
## Loads the data contract (parts, creatures, families, palettes, lexicon).
## Everything the generator and composer know comes from these JSON files,
## so mods are just more JSON.

var parts := {}       # id -> part dict
var creatures := {}   # id -> creature dict
var families := {}    # id -> family dict
var uniques := {}     # unique-unit theme id -> theme (data/uniques.json, the Castle's unique units)
var heroes := {}      # data/heroes.json: rules, hero_names, hero_signatures (src/heroes.gd)
var palettes := {}    # skins, materials, teams
var lexicon := {}     # word -> entry
var stopwords := {}   # word -> true
var curves := {}      # cost curve id -> PackedInt32Array of per-mille multipliers by points
var resources: Array = []   # resource ids in their fixed order (data/resources.json)
var resource_info: Array = []   # the same order: {id, name, short, colour}
var mods: Array = []   # the mods merged in, "id@version#hash" in load order (src/mods.gd; the race key holds them)

const Mods := preload("res://src/mods.gd")


static func load_json(path: String):
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data != null, "Bad or missing JSON: %s" % path)
	return data


## with_mods: the mods in use (src/mods.gd) merged over the game's data, in load order.
func _init(root := "res://data", with_mods := true) -> void:
	for p in load_json(root + "/parts.json"):
		parts[p.id] = p
	creatures = load_json(root + "/creatures.json")
	families = load_json(root + "/families.json")
	uniques = load_json(root + "/uniques.json").themes
	heroes = load_json(root + "/heroes.json")
	palettes = load_json(root + "/palettes.json")
	var lex = load_json(root + "/lexicon.json")
	lexicon = lex.words
	for w in lex.stopwords:
		stopwords[w] = true
	for r in load_json(root + "/resources.json").resources:
		resources.append(r.id)
		resource_info.append(r)
	var cc: Dictionary = load_json(root + "/cost_curves.json")
	for id in cc:
		curves[id] = PackedInt32Array(cc[id].permille)
	if with_mods:
		Mods.apply(self)
	_kit_parts(root)


## Creature-kit bodies (parts.json "kit": a skeleton in data/creature_kit.json, the bears): their
## sockets, anchors, cut legs, walk and idle poses filled in from the skeleton, and their head and leg
## parts made (scenes/art_pixel/creature_kit.gd complete()). Sorted ids, so the order never varies.
func _kit_parts(root: String) -> void:
	if not FileAccess.file_exists(root + "/creature_kit.json"):
		return
	var CreatureKit = load("res://scenes/art_pixel/creature_kit.gd")   # (load, not preload: it preloads this file)
	CreatureKit.register_all(load_json(root + "/creature_kit.json").kits)
	var ids := parts.keys()
	ids.sort()
	for id in ids:
		if parts[id].has("kit"):
			for made in CreatureKit.complete(parts[id]):
				if not parts.has(made.id):
					parts[made.id] = made


## A host rule (data/rules/<id>.json) with the mods' changes to it.
static func load_rules(id: String) -> Dictionary:
	return Mods.rules(id)


func part(id: String) -> Dictionary:
	assert(parts.has(id), "Unknown part: %s" % id)
	return parts[id]


## Per-mille multiplier of a fixed-point cost curve at the given points.
func curve(id: String, points: int) -> int:
	assert(curves.has(id), "Unknown cost curve: %s" % id)
	var table: PackedInt32Array = curves[id]
	assert(points >= 0 and points < table.size(), "Points %d off the end of curve %s" % [points, id])
	return table[points]


static func era_ok(p: Dictionary, eras: Array) -> bool:
	if not p.has("era"):
		return true
	for e in p.era:
		if e in eras:
			return true
	return false


## Parts for a slot allowed in the given eras, in stable (sorted id) order.
func candidates(slot: String, eras: Array) -> Array:
	var ids := parts.keys()
	ids.sort()
	var out := []
	for id in ids:
		var p: Dictionary = parts[id]
		if p.slot == slot and era_ok(p, eras) and not p.get("innate", false):   # innate: grown, never picked (a hummingbird's wings)
			out.append(p)
	return out


## Creature ids in stable order, optionally filtered by a flag such as "playable" or "mount".
func creature_ids(flag := "") -> Array:
	var ids := creatures.keys()
	ids.sort()
	if flag == "":
		return ids
	return ids.filter(func(id): return creatures[id].get(flag, false))


## How a race builds: the creature's own architecture if it has one (frogs weave reed domes,
## bugs dig mounds), else its culture's.
func architecture(race: Dictionary) -> String:
	return creatures[race.creature].get("architecture", families[race.family].get("architecture", "thatch"))
