extends RefCounted
## Loads the data contract (parts, creatures, families, palettes, lexicon).
## Everything the generator and composer know comes from these JSON files,
## so mods are just more JSON.

var parts := {}       # id -> part dict
var creatures := {}   # id -> creature dict
var families := {}    # id -> family dict
var palettes := {}    # skins, materials, teams
var lexicon := {}     # word -> entry
var stopwords := {}   # word -> true


static func load_json(path: String):
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data != null, "Bad or missing JSON: %s" % path)
	return data


func _init(root := "res://data") -> void:
	for p in load_json(root + "/parts.json"):
		parts[p.id] = p
	creatures = load_json(root + "/creatures.json")
	families = load_json(root + "/families.json")
	palettes = load_json(root + "/palettes.json")
	var lex = load_json(root + "/lexicon.json")
	lexicon = lex.words
	for w in lex.stopwords:
		stopwords[w] = true


func part(id: String) -> Dictionary:
	assert(parts.has(id), "Unknown part: %s" % id)
	return parts[id]


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
		if p.slot == slot and era_ok(p, eras):
			out.append(p)
	return out


## Creature ids in stable order, optionally filtered by a flag such as "playable" or "mount".
func creature_ids(flag := "") -> Array:
	var ids := creatures.keys()
	ids.sort()
	if flag == "":
		return ids
	return ids.filter(func(id): return creatures[id].get(flag, false))
