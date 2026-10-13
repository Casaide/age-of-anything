extends RefCounted
## A race's identity (milestone 14): its bonuses, its own research and what it lacks, mixed
## from its creature's group (data/groups.json), its creature (creatures.json) and its culture
## (families.json). Derived from the creature and culture alone, never from the recipes, so race
## keys don't change. Deterministic: fixed layer order, data order inside a layer.
##
## Bonuses: one from each layer (a creature with no group gives two of its own). A later layer's
## bonus of a kind the race already has (the same scope and stat in its effects, or the same
## `kind`) takes its `alt`, so no race doubles up. Effects are research effects (D-111,
## src/sim/tech.gd). Unit stat effects that live in a unit's eval are "priced": pricing.gd adds
## them before the price, with the bonus's `price_points` on every unit they reach (cost is the
## balancer). Everything else is applied by the sim, at setup, like research the race was born
## with (Tech._effects).
##
## Lacks: research ids, building ids, roster slots, line upgrades ("line.skirmisher.3") and
## "trade" (the market's buying and selling). A lacked building takes the lines it trains with
## it. The host's full_tech_tree rule lifts them (and opens every race's own research).

const PRICED_ADD := ["hp", "attack", "speed", "range"]   # plus armour.* and bonus.*
const PRICED_PCT := ["speed", "cost", "train_time"]
const TRADE := "trade"

static var _files := {}
static var _cache := {}


## The data files the sim reads (the generator and pricing pass the DataLib's own).
static func files() -> Dictionary:
	if _files.is_empty():
		_files = {
			"groups": _load("res://data/groups.json").groups,
			"creatures": _load("res://data/creatures.json"),
			"families": _load("res://data/families.json"),
			"buildings": _load("res://data/buildings.json").buildings,
		}
	return _files


static func _load(path: String):
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(d != null, "Bad or missing %s" % path)
	return d


## {bonuses: [{from, layer, text, effects, price_points}], research: [ids], lacks: [ids],
## lacks_slots: [slots, the lacked buildings' lines too]} for a creature and culture.
static func of(creature: String, family: String, d := {}) -> Dictionary:
	if d.is_empty():
		d = files()
	var key := "%s|%s" % [creature, family]   # (one data set per run: data/ is the contract)
	if _cache.has(key):
		return _cache[key]
	var c: Dictionary = d.creatures[creature]
	var f: Dictionary = d.families[family]
	var layers := []   # [layer, from, bonuses]
	var group: String = c.get("group", "")
	if group != "":
		var g: Dictionary = d.groups[group]
		assert(g.bonuses.size() == 1, "Group %s needs one bonus" % group)
		layers.append(["group", g.name, g.bonuses])
	assert(c.get("bonuses", []).size() == (1 if group != "" else 2), "Creature %s needs %s bonus(es)" % [creature, "one" if group != "" else "two"])
	layers.append(["creature", c.plural, c.bonuses])
	assert(f.get("bonuses", []).size() == 1, "Culture %s needs one bonus" % family)
	layers.append(["culture", String(family).capitalize(), f.bonuses])
	var bonuses := []
	var kinds := {}
	for layer in layers:
		for b in layer[2]:
			var pick: Dictionary = b
			if kinds.has(kind_of(b)):
				assert(b.has("alt"), "%s's bonus \"%s\" doubles another and has no alt" % [layer[1], b.text])
				pick = b.alt
			assert(not kinds.has(kind_of(pick)), "%s's alt \"%s\" doubles another too" % [layer[1], pick.text])
			kinds[kind_of(pick)] = true
			bonuses.append({"from": layer[1], "layer": layer[0], "text": pick.text, "effects": pick.get("effects", []), "kind": kind_of(pick),
				"price_points": int(pick.get("price_points", 0))})
	var research: Array = c.get("research", []) + f.get("research", [])
	var lacks := []
	for id in c.get("lacks", []) + f.get("lacks", []):
		if not id in lacks:
			lacks.append(id)
	var slots := []
	for id in lacks:
		if d.buildings.has(id):
			for s in d.buildings[id].get("trains", []):
				if not s in slots:
					slots.append(s)
		elif not "." in id and id != TRADE:
			slots.append(id)   # (anything else that isn't a building or research the checks resolve as a slot)
	var out := {"bonuses": bonuses, "research": research, "lacks": lacks, "lacks_slots": slots,
		"ability": c.get("ability", {})}   # the race's signature ability (src/sim/abilities.gd): its creature's, for now
	_cache[key] = out
	return out


## What makes two bonuses the same kind: an explicit `kind`, else the scopes and stats of its effects.
static func kind_of(b: Dictionary) -> String:
	if b.has("kind"):
		return b.kind
	var parts := []
	for fx in b.get("effects", []):
		if fx.has("gather"):
			parts.append("gather:%s" % fx.gather)
		elif fx.has("tag"):
			parts.append("tag:%s/%s" % [fx.tag, fx.stat])
		else:
			parts.append("building:%s/%s" % [str(fx.building), fx.stat])
	parts.sort()
	return ",".join(parts)


## Is this a unit effect pricing applies (a stat in the unit's eval), not the sim?
static func priced(fx: Dictionary) -> bool:
	if not fx.has("tag"):
		return false
	if fx.has("pct"):
		return fx.stat in PRICED_PCT
	return fx.stat in PRICED_ADD or fx.stat.begins_with("armour.") or fx.stat.begins_with("bonus.")


## The effects the sim applies for a race (everything pricing doesn't), in bonus order.
static func sim_effects(ident: Dictionary) -> Array:
	var out := []
	for b in ident.bonuses:
		for fx in b.effects:
			if not priced(fx):
				out.append(fx)
	return out


## Does a unit effect reach a type with these tags? (`tag`, "all" for every unit; every tag in
## `and` too; none of `not`.)
static func reaches(fx: Dictionary, tags: Array) -> bool:
	if not fx.has("tag") or not (fx.tag == "all" or fx.tag in tags):
		return false
	for t in fx.get("and", []):
		if not t in tags:
			return false
	for t in fx.get("not", []):
		if t in tags:
			return false
	return true


## Which creatures and cultures name each research as their own: {research id: [ids]}.
static func owners(d := {}) -> Dictionary:
	if d.is_empty():
		d = files()
	var out := {}
	for src in [d.creatures, d.families]:
		var ids: Array = src.keys()
		ids.sort()
		for id in ids:
			for r in src[id].get("research", []):
				if not out.has(r):
					out[r] = []
				out[r].append(id)
	return out


## Does the race lack this item (a research id, building id, slot or "trade")? Off under full_tech_tree.
static func lacks(ident: Dictionary, id: String, rules: Dictionary) -> bool:
	if bool(rules.get("full_tech_tree", false)):
		return false
	return id in ident.lacks or id in ident.lacks_slots
