extends RefCounted
## A race's heroes (milestone 14 step 9; D-127, D-131: HR2's characters as a pool; D-136: all of them).
## Each race gets every signature (data/heroes.json hero_signatures: a look, a temper, an aura) naming
## its creature or its culture; one with fewer than rules.min_heroes is topped up from its culture's
## `kin` (the kindred cultures' signatures, in the kin list's order), so every race has a few. Each
## hero's name is made from the creature's and culture's name lists and the signature's epithets, by
## src/rng.gd seeded from the race key and the signature. The heroes are derived from the key (and the
## data), like a unit's stats, so they are not part of the key: every existing race keeps its key and
## every other line's recipes, and a reroll renames them.
##
## The hero's line: the race's swordsman (else its spearman) of each age from the hero line's first
## age (rules roster role "hero"), with the signature's parts put on; the parts they replace stay in
## the recipe's `kit` (priced by pricing.gd, not drawn), so every hero fights with its race's kit plus
## the hero line's stats and price_points. Its scale is the signature's (a look only: size_is_look).

const Rng := preload("res://src/rng.gd")
const Pricing := preload("res://src/pricing.gd")

const BASE_SLOTS := ["infantry", "spear"]   # the line a hero is dressed over, first found


## The signatures naming a creature or a culture, sorted by id.
static func signatures_for(heroes: Dictionary, creature: String, family: String) -> Array:
	var out := []
	for id in heroes.hero_signatures:
		var who: Dictionary = heroes.hero_signatures[id].who
		if creature in who.get("creature", []) or family in who.get("family", []):
			out.append(id)
	out.sort()
	return out


## A race's heroes, in order: its creature's and culture's signatures (sorted by id), then, while it has
## fewer than rules.min_heroes, its culture's kin's (each kindred culture's signatures, sorted, in turn).
static func roster_for(heroes: Dictionary, creature: String, family: String) -> Array:
	var out := signatures_for(heroes, creature, family)
	for kin in heroes.kin.get(family, []):
		for sid in signatures_for(heroes, "", kin):
			if out.size() < int(heroes.rules.min_heroes) and not sid in out:
				out.append(sid)
	return out


## A hero's name {signature, name, given} as the race with this key calls it: each signature its own
## draw; its given name not one of `taken` (the race's heroes before it) while the lists have others.
static func pick(heroes: Dictionary, key: String, creature: String, family: String, sid: String, taken := []) -> Dictionary:
	var rng = Rng.new(Rng.hash_string(key + "|hero|" + sid))
	var s: Dictionary = heroes.hero_signatures[sid]
	var n: Dictionary = heroes.hero_names
	var pool: Array = n.creatures.get(creature, {}).get("names", []) + n.families.get(family, {}).get("names", [])
	var free: Array = pool.filter(func(x): return not x in taken)
	if free.is_empty():   # (the race's lists used up: a name from the hero's own culture, a kindred hero's home)
		for f in s.who.get("family", []):
			free += n.families.get(f, {}).get("names", []).filter(func(x): return not x in taken and not x in free)
	if not free.is_empty():
		pool = free
	var titles: Array = s.get("titles", n.creatures.get(creature, {}).get("titles", []) + n.families.get(family, {}).get("titles", []))
	var fmt: String = n.formats[rng.pick(s.formats)]
	var any := func(a: Array) -> String: return rng.pick(a) if not a.is_empty() else ""
	var given: String = any.call(pool)
	var name: String = fmt.format({"name": given, "epithet": any.call(s.epithets), "nickname": any.call(s.get("nicknames", [])),
		"title": any.call(titles), "ordinal": rng.pick(n.ordinals)})
	return {"signature": sid, "name": name.strip_edges(), "given": given if "{name}" in fmt else ""}


## The race's heroes as unit lines [{recipe, eval, line}] in roster_for's order, or [] (no hero line
## in the rules, no line to dress). Called once the race key is set.
static func make(lib, race: Dictionary, rules: Dictionary) -> Array:
	var sd := slot_def(rules)
	if sd.is_empty():
		return []
	var base: Dictionary = {}
	for slot in BASE_SLOTS:
		for u in race.units:
			if base.is_empty() and u.recipe.slot == slot:
				base = u
	if base.is_empty():
		return []
	var out := []
	var taken := []
	for sid in roster_for(lib.heroes, race.creature, race.family):
		var h := pick(lib.heroes, race.key, race.creature, race.family, sid, taken)
		taken.append(h.given)
		var s: Dictionary = lib.heroes.hero_signatures[sid]
		var line := []
		for age in range(int(sd.tier), int(rules.get("ages", 1)) + 1):
			var step: Dictionary = base.line[0]
			for l in base.line:
				if int(l.age) <= age:
					step = l
			var r := dress(step.recipe, sid, s, h.name, int(sd.tier))
			line.append({"age": age, "recipe": r, "eval": Pricing.evaluate(r, lib, rules)})
		out.append({"recipe": line[0].recipe, "eval": line[0].eval, "line": line})
	return out


## A unit's recipe dressed as the hero: the signature's parts on (the replaced ones kept in `kit`),
## its scale, the hero's slot, role and name. A look with no back piece stows the swordsman's back
## gear (a banner, a cape) in the kit too: the hero's hat or weapon is its silhouette (D-136).
static func dress(recipe: Dictionary, sid: String, s: Dictionary, name: String, tier: int) -> Dictionary:
	var r: Dictionary = recipe.duplicate(true)
	r.slot = "hero"
	r.role = "hero"
	r.tier = tier
	r.hero = sid
	r.name = name
	r.erase("noun")
	var kit := {}
	var parts := parts_on(s, String(r.creature))
	var slots: Array = parts.keys()
	slots.sort()
	for slot in slots:
		if r.parts.has(slot):
			kit[slot] = r.parts[slot]
		r.parts[slot] = parts[slot]
	if r.parts.has("back") and not parts.has("back"):
		kit.back = r.parts.back
		r.parts.erase("back")
	if not kit.is_empty():
		r.kit = kit
	r.scale = int(r.scale) * int(s.scale) / 100
	return r


## A signature's parts on a creature: its own, with its `fit` for that creature over them (a part in
## place of one, "" to keep the race's own there).
static func parts_on(s: Dictionary, creature: String) -> Dictionary:
	var out: Dictionary = s.parts.duplicate()
	var fit: Dictionary = s.get("fit", {}).get(creature, {})
	for slot in fit:
		if fit[slot] == "":
			out.erase(slot)
		else:
			out[slot] = fit[slot]
	return out


## A unit line's key in the views (portraits, the panel's icons): its slot; a hero's slot and
## signature ("hero.widow"), since a race's heroes share the hero line.
static func line_key(recipe: Dictionary) -> String:
	return "%s.%s" % [recipe.slot, recipe.hero] if recipe.has("hero") else String(recipe.slot)


## The rules' hero line ({} if the rules have none).
static func slot_def(rules: Dictionary) -> Dictionary:
	for sd in rules.roster:
		if sd.role == "hero":
			return sd
	return {}


## What the views show of a race's heroes: [{signature, name, temper, aura (its line)}] in order.
static func info(lib, race: Dictionary) -> Array:
	var out := []
	for u in race.units:
		if u.recipe.slot == "hero":
			var s: Dictionary = lib.heroes.hero_signatures[u.recipe.hero]
			out.append({"signature": u.recipe.hero, "name": u.recipe.name, "temper": s.temper, "aura": s.aura.text})
	return out
