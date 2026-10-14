extends RefCounted
## A race's hero (milestone 14 step 9; D-127, D-131: HR2's characters as a pool). Each race gets one:
## a signature (data/heroes.json hero_signatures: a look, a temper, an aura) picked from those naming
## its creature or its culture, and a name made from the creature's and culture's name lists and the
## signature's epithets, every pick by src/rng.gd seeded from the race key. The hero is derived from
## the key (and the data), like a unit's stats, so it is not part of the key: every existing race keeps
## its key and every other line's recipes, and a reroll gives a new hero.
##
## The hero's line: the race's swordsman (else its spearman) of each age from the hero line's first
## age (rules roster role "hero"), with the signature's parts put on; the parts they replace stay in
## the recipe's `kit` (priced by pricing.gd, not drawn), so every hero fights with its race's kit plus
## the hero line's stats and price_points. Its scale is the signature's (a look only: size_is_look).

const Rng := preload("res://src/rng.gd")
const Pricing := preload("res://src/pricing.gd")

const BASE_SLOTS := ["infantry", "spear"]   # the line a hero is dressed over, first found


## The signatures a race may have: those naming its creature or its culture, sorted by id.
static func signatures_for(heroes: Dictionary, creature: String, family: String) -> Array:
	var out := []
	for id in heroes.hero_signatures:
		var who: Dictionary = heroes.hero_signatures[id].who
		if creature in who.get("creature", []) or family in who.get("family", []):
			out.append(id)
	out.sort()
	return out


## A race's hero: {signature, name}, or {} with no signature for its creature or culture. `force`
## names the signature (sheets show each look a race could have, each with the name it would carry).
static func pick(heroes: Dictionary, key: String, creature: String, family: String, force := "") -> Dictionary:
	var sigs := signatures_for(heroes, creature, family)
	if sigs.is_empty() and force == "":
		return {}
	var rng = Rng.new(Rng.hash_string(key + "|hero"))
	var sid: String = rng.pick(sigs) if not sigs.is_empty() else force
	if force != "" and force != sid:   # (another look than the race's own: its own draw)
		sid = force
		rng = Rng.new(Rng.hash_string(key + "|hero|" + force))
	var s: Dictionary = heroes.hero_signatures[sid]
	var n: Dictionary = heroes.hero_names
	var pool: Array = n.creatures.get(creature, {}).get("names", []) + n.families.get(family, {}).get("names", [])
	var titles: Array = s.get("titles", n.creatures.get(creature, {}).get("titles", []) + n.families.get(family, {}).get("titles", []))
	var fmt: String = n.formats[rng.pick(s.formats)]
	var any := func(a: Array) -> String: return rng.pick(a) if not a.is_empty() else ""
	var name: String = fmt.format({"name": any.call(pool), "epithet": any.call(s.epithets), "nickname": any.call(s.get("nicknames", [])),
		"title": any.call(titles), "ordinal": rng.pick(n.ordinals)})
	return {"signature": sid, "name": name.strip_edges()}


## The race's hero as a unit line {recipe, eval, line}, or {} (no hero line in the rules, no
## signature for the race, no line to dress). Called once the race key is set.
static func make(lib, race: Dictionary, rules: Dictionary) -> Dictionary:
	var sd := slot_def(rules)
	if sd.is_empty():
		return {}
	var h := pick(lib.heroes, race.key, race.creature, race.family)
	if h.is_empty():
		return {}
	var base: Dictionary = {}
	for slot in BASE_SLOTS:
		for u in race.units:
			if base.is_empty() and u.recipe.slot == slot:
				base = u
	if base.is_empty():
		return {}
	var s: Dictionary = lib.heroes.hero_signatures[h.signature]
	var line := []
	for age in range(int(sd.tier), int(rules.get("ages", 1)) + 1):
		var step: Dictionary = base.line[0]
		for l in base.line:
			if int(l.age) <= age:
				step = l
		var r := dress(step.recipe, h.signature, s, h.name, int(sd.tier))
		line.append({"age": age, "recipe": r, "eval": Pricing.evaluate(r, lib, rules)})
	return {"recipe": line[0].recipe, "eval": line[0].eval, "line": line}


## A unit's recipe dressed as the hero: the signature's parts on (the replaced ones kept in `kit`),
## its scale, the hero's slot, role and name.
static func dress(recipe: Dictionary, sid: String, s: Dictionary, name: String, tier: int) -> Dictionary:
	var r: Dictionary = recipe.duplicate(true)
	r.slot = "hero"
	r.role = "hero"
	r.tier = tier
	r.hero = sid
	r.name = name
	r.erase("noun")
	var kit := {}
	var slots: Array = s.parts.keys()
	slots.sort()
	for slot in slots:
		if r.parts.has(slot):
			kit[slot] = r.parts[slot]
		r.parts[slot] = s.parts[slot]
	if not kit.is_empty():
		r.kit = kit
	r.scale = int(r.scale) * int(s.scale) / 100
	return r


## The rules' hero line ({} if the rules have none).
static func slot_def(rules: Dictionary) -> Dictionary:
	for sd in rules.roster:
		if sd.role == "hero":
			return sd
	return {}


## What the views show of a race's hero: {signature, name, temper, aura (its line)} ({} with none).
static func info(lib, race: Dictionary) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == "hero":
			var s: Dictionary = lib.heroes.hero_signatures[u.recipe.hero]
			return {"signature": u.recipe.hero, "name": u.recipe.name, "temper": s.temper, "aura": s.aura.text}
	return {}
