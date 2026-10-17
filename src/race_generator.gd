extends RefCounted
## Prompt -> race. Fully deterministic: the same prompt, rules and reroll number
## always give the same race on every machine. No AI at runtime: words map to
## tags through data/lexicon.json, tags pick parts, parts become unit recipes.
##
## A race holds recipes (the shareable part) plus derived stats (recomputed by
## every peer from the recipes and the host rules). The race key hashes only
## the recipes, so it is what you would publish as a hyperblob later.

const Rng := preload("res://src/rng.gd")
const Pricing := preload("res://src/pricing.gd")
const Heroes := preload("res://src/heroes.gd")

const ROLE_NEEDS := {"worker": "worker", "spear": "spear", "skirmisher": "ranged", "archer": "bow", "large": "melee", "healer": "heal",
	"ram": "ram", "catapult": "catapult", "bolt_thrower": "bolt_thrower", "siege_tower": "docks", "infantry": "melee", "scout": "melee", "mounted_archer": "bow",
	"sapper": "sapper", "great_sling": "great_sling", "war_beast": "war_beast"}
## Tags a role's primary must not have (skirmishers are the non-bow ranged units; the swordsman
## line holds a blade or a club, never a spear or a lance).
## The scout holds a light weapon: no spear or lance (that would make it anti-cavalry), nothing heavy.
const ROLE_EXCLUDES := {"skirmisher": ["bow"], "infantry": ["spear", "lance"], "scout": ["spear", "lance", "heavy"]}
## Kinds a line's primitive weapon may give way to on an upgrade, besides its own: the swordsman's
## age 1 bone club becomes a sword (a cheese hammer isn't primitive, so rats keep theirs).
const ROLE_KINDS := {"infantry": ["blade"], "scout": ["blade"]}
const ROLE_BIAS := {
	"worker": {},
	"spear": {"reach": 1},
	"skirmisher": {"skirmish": 2},
	"archer": {},
	"large": {"charge": 3, "heavy": 2, "lance": 3},
	"healer": {},
	"infantry": {"blade": 1},
	"scout": {"blade": 1, "light": 2},
	"mounted_archer": {},
	"sapper": {},
}
## Lines that go light (the scout): no heavy kit, nothing over LIGHT_POINTS, in any age. A unique
## unit whose theme says "light" (the raiders) goes the same way.
const LIGHT_ROLES := ["scout", "sapper"]
const LIGHT_POINTS := 2
## Signature gear (a culture's kit, cheese hammers...) is only favoured when the prompt,
## family or creature asks for it. No cheese hammers for Romans unless someone says cheese.
const SIGNATURE_TAGS := ["roman", "greek", "viking", "cheese", "woodland", "knight", "bat", "crossbow", "junk", "saucepan", "nile", "han", "aztec", "norse"]   # woodland: acorn caps, leaves, bark (swamp/forest); knight: iron helm, kite, mail (royal); bat wings (spooky/sewer); crossbows (royal, sewer rats); junk: bottle caps (sewer); saucepan: only when asked (ww2)
## Extra wants for "Heavy" large units (armoured elites instead of giants).
const HEAVY_BOOST := {"heavy": 3, "armour": 3, "helmet": 2, "shield": 1}   # no "knight": knight kit is the royal culture's signature
const OPTIONAL_SLOTS := ["hand_l", "head_gear", "torso", "back"]
## Healers go light (Dominic, 2026-10-12: a healer at the Town Center): a bag in the off hand
## (parts tagged "heal"), a light hat at most, wings only on a winged race. No armour, no shield.
const HEALER_SLOTS := ["hand_l", "head_gear", "back"]
## Scouts ride light: a cap and a jerkin at most (no shield, banner or cape to pay for); a winged
## race's scouts keep their wings (the back slot holds nothing else for them: _light).
const SCOUT_SLOTS := ["head_gear", "torso", "back"]
const HEALER_WANTS := {"heal": 3}   # so the healer's bag is always packed
## Sappers carry their charge and a cap at most: they're spent in one blow (milestone 13).
const SAPPER_SLOTS := ["head_gear"]
## What kind of thing a part is: an upgrade keeps the kind (a cape stays a cape, a
## spear stays a spear), so a unit line stays recognisably the same unit.
const KIND_TAGS := ["spear", "lance", "blade", "blunt", "bow", "sling", "javelin", "poison", "gun", "worker",
	"shield", "helmet", "hat", "armour", "cape", "banner", "wings", "quiver"]
const EPITHET_SLOTS := ["hand_r", "torso"]   # a line step is named for its new weapon, then its new armour
const WORKER_SLOTS := ["head_gear"]   # workers wear a hat at most: no capes on builders (Dominic)
const GIANT_SCALE := 150
const TINY_SCALE := 80

var lib
var _no_restrictions := false   # host rule no_restrictions: theme guards off
var _affinity: Array = []   # creature + family of the race being generated


func _init(data_lib) -> void:
	lib = data_lib


# ------------------------------------------------------------------ prompt

static func normalize(prompt: String) -> String:
	var cleaned := ""
	for ch in prompt.to_lower():
		var letter := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		cleaned += ch if letter else " "
	return " ".join(cleaned.split(" ", false))


func lookup(word: String) -> String:
	if lib.lexicon.has(word):
		return word
	for ending in [["ies", "y"], ["es", ""], ["s", ""]]:
		if word.ends_with(ending[0]):
			var stem: String = word.substr(0, word.length() - ending[0].length()) + ending[1]
			if lib.lexicon.has(stem):
				return stem
	return ""


func interpret(prompt: String, rules: Dictionary) -> Dictionary:
	var brief := {
		"creatures": [], "default_creatures": [], "mounts": [], "mount_wings": "", "families": [],
		"tags": {}, "body_size": "", "notes": [], "unknown": [],
	}
	for raw in normalize(prompt).split(" ", false):
		if lib.stopwords.has(raw):
			continue
		var word := lookup(raw)
		if word == "":
			brief.unknown.append(raw)
			continue
		var entry: Dictionary = lib.lexicon[word]
		var tags: Dictionary = entry.get("tags", {})
		if entry.has("era") and not (entry.era in rules.era):
			if not (entry.note in brief.notes):
				brief.notes.append(entry.note)
			tags = entry.get("substitute", {})
		if entry.has("creature") and not (entry.creature in brief.creatures):
			brief.creatures.append(entry.creature)
		if entry.has("default_creature") and not (entry.default_creature in brief.default_creatures):
			brief.default_creatures.append(entry.default_creature)
		if entry.has("mount") and not (entry.mount in brief.mounts):
			brief.mounts.append(entry.mount)
		if entry.has("mount_wings"):
			brief.mount_wings = entry.mount_wings
		if entry.has("family") and not (entry.family in brief.families):
			brief.families.append(entry.family)
		if entry.has("size"):
			brief.body_size = entry["size"]
		for t in tags:
			brief.tags[t] = brief.tags.get(t, 0) + int(tags[t])
	return brief


# ------------------------------------------------------------------ race

func generate(prompt: String, rules: Dictionary, reroll := 0) -> Dictionary:
	var rng = Rng.new(Rng.hash_string("%s|%s|%d" % [normalize(prompt), rules.id, reroll]))
	var brief := interpret(prompt, rules)
	var notes: Array = brief.notes.duplicate()

	var creature: String
	if brief.creatures.size() > 0:
		creature = brief.creatures[0]
	elif brief.default_creatures.size() > 0:
		creature = brief.default_creatures[0]
	else:
		creature = rng.pick(lib.creature_ids("playable"))
		notes.append("Nobody said who, so the %s volunteered." % lib.creatures[creature].plural)
	var c: Dictionary = lib.creatures[creature]

	var family: String = brief.families[0] if brief.families.size() > 0 else rng.pick(c.families)
	_affinity = [creature, family]
	_no_restrictions = bool(rules.get("no_restrictions", false))
	var tags: Dictionary = brief.tags.duplicate()
	tags[family] = tags.get(family, 0) + 2
	tags[creature] = tags.get(creature, 0) + 2

	if brief.unknown.size() > 0:
		notes.append("No idea what %s means, so we ignored it." % ", ".join(brief.unknown.map(func(w): return "'%s'" % w)))

	var ctx := {
		"rng": rng, "rules": rules, "brief": brief, "tags": tags,
		"creature": creature, "family": family, "skin": rng.pick(_skins(c, family)), "notes": notes, "firsts": {},
	}
	# Each roster slot is a unit line through the ages (D-057): first the unit at the age
	# its slot opens, in that age's kit; then, in a second pass (so the first recipes don't
	# depend on the later ones), the same unit upgraded for every later age.
	var units := []
	var slots: Array = rules.roster.filter(func(sd): return not sd.get("status", "") in ["planned", "parked"] and sd.role != "hero")   # planned lines: tech tree page only; the hero: after the key (src/heroes.gd)
	# A slot with "own_seed" draws from its own stream, so a line added later (the healer)
	# leaves every other line's recipes as they were.
	var rngs := []
	for slot_def in slots:
		rngs.append(Rng.new(Rng.hash_string("%s|%s|%d|%s" % [normalize(prompt), rules.id, reroll, slot_def.slot])) if slot_def.get("own_seed", false) else rng)
	var lacks := []   # lines this race doesn't have (a mounted archer with nothing to ride)
	for k in slots.size():
		var slot_def: Dictionary = slots[k]
		ctx.age = int(slot_def.tier)
		ctx.rng = rngs[k]
		var why := _lacks(slot_def, units, ctx)
		var recipe := {} if why != "" else _make_unit(slot_def, ctx)
		if recipe.is_empty():   # (or _make_unit found no mount for a line that must ride)
			why = why if why != "" else "nothing will carry them"
			lacks.append(slot_def.slot)
			notes.append("No %s line: %s." % [slot_def.name, why])
			units.append({})
			continue
		if slot_def.slot == "worker":
			ctx.crew = recipe   # siege engines are crewed by the race's own workers
		ctx.firsts[slot_def.slot] = recipe   # (a war beast's riders: the spear line's unit)
		var first := {"age": ctx.age, "recipe": recipe, "eval": Pricing.evaluate(recipe, lib, rules)}
		units.append({"recipe": recipe, "eval": first.eval, "line": [first]})
	for k in units.size():
		var slot_def: Dictionary = slots[k]
		ctx.rng = rngs[k]
		if units[k].is_empty():
			continue
		for age in range(int(slot_def.tier) + 1, int(rules.get("ages", 1)) + 1):
			ctx.age = age
			# A line that doesn't upgrade (rules "upgrades": false, the healer: Dominic) stays as
			# it came; the tech tree shows no second tier.
			var up: Dictionary = units[k].line[-1].recipe if not slot_def.get("upgrades", true) else _upgrade(units[k].line[-1].recipe, slot_def, ctx)
			units[k].line.append({"age": age, "recipe": up, "eval": Pricing.evaluate(up, lib, rules)})
	ctx.rng = rng
	# An engine crewed by another line (rules roster `crew`: the war beast's riders, the spear line) carries
	# that line's unit as it is at the engine's first age (an age-3 beast, age-3 spearmen), in every age.
	for k in units.size():
		var cs: String = slots[k].get("crew", "")
		if units[k].is_empty() or cs == "":
			continue
		for j in units.size():
			if not units[j].is_empty() and slots[j].slot == cs:
				var by: Dictionary = units[j].line[0].recipe
				for l in units[j].line:
					if int(l.age) <= int(slots[k].tier):
						by = l.recipe
				var crew := _crew_from(by, true)
				for slot in slots[k].get("crew_drop", []):   # what riders stow (wings, capes, banners in a howdah)
					crew.parts.erase(slot)
				for l in units[k].line:
					l.recipe.crew = crew.duplicate(true)
	units = units.filter(func(u): return not u.is_empty())

	var race := {
		"schema": "aow.race/1",
		"name": _race_name(rng, c, family),
		"prompt": prompt,
		"rules": rules.id,
		"reroll": reroll,
		"creature": creature,
		"family": family,
		"notes": notes,
		"units": units,
		"lacks": lacks,   # derived (the slots left out), not in the key; what its creature and culture lack: src/identity.gd
	}
	if not lib.mods.is_empty():
		race.mods = lib.mods.duplicate()   # made with mods (src/mods.gd): a peer needs the same ones (in the key)
	race.key = race_key(race)
	# The race's heroes (src/heroes.gd): derived from the key, so not in it; the last of its units.
	var heroes := Heroes.make(lib, race, rules)
	if not heroes.is_empty():
		race.units.append_array(heroes)
		race.heroes = Heroes.info(lib, race)
	return race


## Hash of the shareable content only (names + recipes), not derived stats nor the heroes (derived from
## this key: src/heroes.gd).
static func race_key(race: Dictionary) -> String:
	var units: Array = race.units.filter(func(u): return u.recipe.slot != "hero")
	var shareable := {
		"schema": race.schema, "name": race.name, "creature": race.creature, "family": race.family,
		"recipes": units.map(func(u): return u.line.map(func(l): return l.recipe) if u.has("line") else [u.recipe]),
	}
	if race.has("mods"):   # (only then: a race made without mods keeps the key it always had)
		shareable.mods = race.mods
	return JSON.stringify(shareable, "", true).sha256_text()


func _race_name(rng, c: Dictionary, family: String) -> String:
	var f: Dictionary = lib.families[family]
	if rng.chance(30):
		return "%s %s" % [f.adjective, c.plural]
	return rng.pick(f.prefixes) + rng.pick(f.suffixes)


# ------------------------------------------------------------------ units

func _make_unit(slot_def: Dictionary, ctx: Dictionary) -> Dictionary:
	if slot_def.has("engine"):
		return _make_engine(slot_def, ctx)
	if slot_def.role == "unique":
		return _make_unique(slot_def, ctx)
	var rng = ctx.rng
	var rules: Dictionary = ctx.rules
	var brief: Dictionary = ctx.brief
	var role: String = slot_def.role
	var tier := int(slot_def.tier)
	var budget := int(rules.budget[str(maxi(tier, int(ctx.get("age", tier))))])
	var c: Dictionary = lib.creatures[ctx.creature]
	var body: Dictionary = lib.part(c.body)

	var recipe := {
		"slot": slot_def.slot, "role": role, "tier": tier,
		"creature": ctx.creature, "family": ctx.family, "skin": ctx.skin,
		"body": c.body, "head": c.head, "parts": {}, "scale": 100,
	}
	var spent := int(body.points)

	# Mounts and size
	# Large units: a mount if there is one, giant only for creatures where that reads well
	# (giant frogs yes, giant Romans no). Otherwise the unit goes "Heavy": same size, armoured up.
	var giant_ok: bool = c.get("giant_ok", true) or brief.body_size == "giant"
	var heavy := false
	if c.has("fused_mount"):
		recipe.mount = _mount_for(c.fused_mount, true, rng, brief, ctx.skin)
		spent += _mount_points(recipe.mount)
		if role == "large":
			if brief.body_size == "giant":
				recipe.scale = GIANT_SCALE
				spent += Pricing.GIANT_POINTS
			else:
				heavy = true
	elif role == "large":
		var mount := _choose_mount(ctx, not c.get("giant_ok", true))
		if mount != "" and brief.body_size != "giant":
			recipe.mount = _mount_for(mount, false, rng, brief, ctx.skin)
			spent += _mount_points(recipe.mount)
		elif giant_ok:
			recipe.scale = GIANT_SCALE
			spent += Pricing.GIANT_POINTS
		else:
			heavy = true
	elif slot_def.has("mount"):   # a line that rides (rules roster "mount"): the scout, the mounted archer
		var mount := _choose_mount(ctx, true)
		if mount != "":
			recipe.mount = _mount_for(mount, false, rng, brief, ctx.skin)
			spent += _mount_points(recipe.mount)
		elif slot_def.mount == "always":
			return {}   # nothing to ride (Aztec folk, spooky spiders, a winged race): the race lacks this line
	elif role == "archer" and int(ctx.tags.get("mounted", 0)) >= 2:
		var mount := _choose_mount(ctx)
		if mount != "":
			var m := _mount_for(mount, false, rng, brief, ctx.skin)
			if spent + _mount_points(m) + 4 <= budget:
				recipe.mount = m
				spent += _mount_points(m)
	if brief.body_size == "tiny" and recipe.scale == 100:
		recipe.scale = TINY_SCALE

	# Primary weapon or tool (required)
	var need: String = ROLE_NEEDS[role]
	var excluded: Array = ROLE_EXCLUDES.get(role, [])
	var options: Array = _cands("hand_r", ctx).filter(func(p): return need in p.tags and not p.tags.any(func(t): return t in excluded) and _allowed(p, role, ctx.tags))
	var affordable := options.filter(func(p): return spent + int(p.points) <= budget)
	if affordable.is_empty():
		affordable = [_cheapest(options)]
	var unit_tags: Dictionary = ctx.tags.duplicate()
	if heavy:
		recipe.elite = "heavy"
		for t in HEAVY_BOOST:
			unit_tags[t] = int(unit_tags.get(t, 0)) + HEAVY_BOOST[t]
	if role == "healer":
		for t in HEALER_WANTS:
			unit_tags[t] = int(unit_tags.get(t, 0)) + HEALER_WANTS[t]
	var primary: Dictionary = _best(affordable, unit_tags, ROLE_BIAS[role], rng)
	recipe.parts.hand_r = primary.id
	spent += int(primary.points)

	# Wings on a ridden unit go on the mount (a pegasus), never on the rider alone,
	# otherwise the rider hovers and drags a grounded mount along. A winged race that was
	# asked to ride keeps its own wings too: rider and mount both fly.
	var ridden: bool = recipe.has("mount") and not recipe.mount.fused
	if ridden and not recipe.mount.parts.has("back"):
		var wings: Array = _cands("back", ctx).filter(func(p): return "wings" in p.tags and _allowed(p, role, unit_tags))
		if not wings.is_empty():
			var w: Dictionary = _best(wings, unit_tags, {}, rng)
			if spent + int(w.points) <= budget:
				recipe.mount.parts.back = w.id
				spent += int(w.points)
	if slot_def.has("noun"):
		recipe.noun = slot_def.noun   # the line's own noun over the weapon's (a Scout, whatever it holds)
	recipe.name = _unit_name(recipe, primary, c)

	# Optional gear: most-wanted slot first, while the budget lasts
	var slots: Array = _gear_slots(role)
	var picks := []
	for slot in rng.shuffled(slots):
		if slot == "hand_l" and primary.get("two_handed", false):
			continue
		var cands: Array = _cands(slot, ctx).filter(func(p): return _allowed(p, role, unit_tags) and _fits_mount(p, recipe))
		if ridden and not _winged(unit_tags):
			cands = cands.filter(func(p): return not ("wings" in p.tags))
		if role == "worker":
			cands = cands.filter(func(p): return int(p.points) <= 1)
		if role == "healer":
			cands = cands.filter(func(p): return _healer_gear(p, unit_tags))
		if role in LIGHT_ROLES:
			cands = cands.filter(_light)
		# Optional gear can stay empty, so it never goes off theme (no acorn caps on Romans).
		cands = cands.filter(func(p): return not _off_theme(p, unit_tags))
		if cands.is_empty():
			continue
		var best: Dictionary = _best(cands, unit_tags, ROLE_BIAS[role], rng)
		picks.append({"slot": slot, "part": best, "score": _want(best, unit_tags)})
	picks.sort_custom(func(a, b): return a.score > b.score)
	for pick in picks:
		var p: Dictionary = pick.part
		if spent + int(p.points) > budget:
			continue
		if pick.score > 0 or rng.chance(45):
			recipe.parts[pick.slot] = p.id
			spent += int(p.points)
	return recipe


## A siege engine (milestone 13, D-119): the engine of its slot in the race's take (a creature's
## own `siege` take first, else its culture's: families.json), its weapon the engine part made for
## the role, crewed by the race's workers (the age-1 worker's recipe, drawn on the model's crew
## sockets). Engines aren't kitted out from the budget: the engine is the unit. A line with
## `armed`: false (the trade cart) has no weapon part.
func _make_engine(slot_def: Dictionary, ctx: Dictionary) -> Dictionary:
	var c: Dictionary = lib.creatures[ctx.creature]
	var field: String = slot_def.get("take", "siege")   # (the war beast's: `war_beast`)
	var take: String = c.get(field, lib.families[ctx.family][field])
	var body: Dictionary = lib.part("siege.%s.%s" % [slot_def.engine, take])
	var parts := {}
	if slot_def.get("armed", true):
		var weapons: Array = _cands("hand_r", ctx).filter(func(p): return p.has("requires_role") and _for_role(p, slot_def.role))
		assert(not weapons.is_empty(), "No engine weapon for %s" % slot_def.role)
		parts.hand_r = _best(weapons, ctx.tags, {}, ctx.rng).id
	var crew := _crew_from(ctx.firsts.get(slot_def.get("crew", "worker"), ctx.crew), slot_def.has("crew"))
	var engine := {
		"slot": slot_def.slot, "role": slot_def.role, "tier": int(slot_def.tier),
		"creature": ctx.creature, "family": ctx.family, "skin": ctx.skin,
		"body": body.id, "head": "", "parts": parts, "scale": 100, "name": body.noun, "crew": crew,
	}
	if body.has("haul"):   # a beast pulls it (the trade cart, D-127): {creature, skin, parts: its harness}
		engine.haul = body.haul.duplicate(true)
	return engine


## An engine's crew member from a unit's recipe: its body, head, skin, kit and size (and a centaur's horse
## half); `as_itself`: it keeps its line (a war beast's riding spearmen are drawn as spearmen, not workers).
func _crew_from(r: Dictionary, as_itself: bool) -> Dictionary:
	var crew: Dictionary = {"body": r.body, "head": r.head, "skin": r.skin, "parts": r.parts.duplicate(), "scale": r.scale}
	if r.has("mount"):
		crew.mount = r.mount.duplicate(true)   # a centaur's horse half
	if as_itself:
		crew.merge({"slot": r.slot, "role": r.role, "tier": int(r.tier), "name": r.get("name", "")})
	return crew


## Why this race has no such line ("" if it has): rules roster "unless_mounted" names a line that
## already rides for it (a centaur's or a horse people's archers are mounted archers already);
## "needs_hands": a creature that carries its weapons in a harness (creatures.json "harness":
## beetles, spiders) can't draw a bow while clinging to a mount.
func _lacks(slot_def: Dictionary, units: Array, ctx: Dictionary) -> String:
	if slot_def.get("needs_hands", false) and lib.creatures[ctx.creature].get("harness", false):
		return "the %s have no hands to draw a bow on a mount" % lib.creatures[ctx.creature].plural.to_lower()
	var other: String = slot_def.get("unless_mounted", "")
	for u in units:
		if not u.is_empty() and u.recipe.slot == other and u.recipe.has("mount"):
			return "the %s ride already as %ss" % [lib.creatures[ctx.creature].plural.to_lower(), String(other)]
	return ""


## Can a rider on this recipe's mount wear the part? (parts.json "not_ridden_on": a cloth cape hangs
## through a pony's back: the placement check, A3.)
func _fits_mount(p: Dictionary, recipe: Dictionary) -> bool:
	return not (recipe.has("mount") and not recipe.mount.fused and recipe.mount.creature in p.get("not_ridden_on", []))


## Light kit (scouts, raider themes): nothing heavy, nothing over LIGHT_POINTS; on the back only a
## winged race's wings (only_if keeps them to winged races), no cape or banner.
func _light(p: Dictionary) -> bool:
	if p.slot == "back":
		return "wings" in p.tags
	return not "heavy" in p.tags and int(p.points) <= LIGHT_POINTS


## The race's unique unit (the Castle, milestone 13 step 4): its theme (data/uniques.json) is the one
## the prompt asked for most by its `asked` tags (romans -> the testudo, cheese -> the Big Cheese,
## even on frogs), else the creature's own `unique`, else its culture's (families.json).
func _unique_theme(ctx: Dictionary) -> String:
	var best := ""
	var best_n := 0
	var ids: Array = lib.uniques.keys()
	ids.sort()
	for id in ids:
		var n := 0
		for t in lib.uniques[id].get("asked", []):
			n += int(ctx.brief.tags.get(t, 0))
		if n > best_n:
			best_n = n
			best = id
	if best != "":
		return best
	return lib.creatures[ctx.creature].get("unique", lib.families[ctx.family].unique)


## A unique unit: the theme's role picks its weapon (its `parts` first: the signature kit, where the
## age and era allow), the theme's `wants` lean its gear, `mount` "ride" puts it on the race's mount,
## `giant` makes it a giant where that reads (giant_ok), `light` keeps it light. A bigger budget
## (rules roster `budget_add`); priced like everything else, plus the theme's stats and price_points
## (pricing.gd reads them through the recipe's `unique`).
func _make_unique(slot_def: Dictionary, ctx: Dictionary) -> Dictionary:
	var id := _unique_theme(ctx)
	var th: Dictionary = lib.uniques[id]
	var rng = ctx.rng
	var role: String = th.role
	var budget := int(ctx.rules.budget[str(ctx.age)]) + int(slot_def.get("budget_add", 0))
	var c: Dictionary = lib.creatures[ctx.creature]
	var recipe := {
		"slot": slot_def.slot, "role": slot_def.role, "unique": id, "tier": int(slot_def.tier),
		"creature": ctx.creature, "family": ctx.family, "skin": ctx.skin,
		"body": c.body, "head": c.head, "parts": {}, "scale": 100,
	}
	var spent := int(lib.part(c.body).points)
	var unit_tags: Dictionary = ctx.tags.duplicate()
	for t in th.get("wants", {}):
		unit_tags[t] = int(unit_tags.get(t, 0)) + int(th.wants[t])
	if c.has("fused_mount"):
		recipe.mount = _mount_for(c.fused_mount, true, rng, ctx.brief, ctx.skin)
	elif th.get("mount", "") == "ride":
		var mount := _choose_mount(ctx, true)
		if mount != "":
			recipe.mount = _mount_for(mount, false, rng, ctx.brief, ctx.skin)
	if recipe.has("mount"):
		spent += _mount_points(recipe.mount)
	elif th.get("giant", false) and c.get("giant_ok", true):
		recipe.scale = GIANT_SCALE
		spent += Pricing.GIANT_POINTS
	if ctx.brief.body_size == "tiny" and recipe.scale == 100:
		recipe.scale = TINY_SCALE   # tiny vikings' raiders are tiny too
	var ok := func(p: Dictionary) -> bool: return not th.get("light", false) or _light(p)
	for pid in th.get("parts", []):   # the signature kit, where the age and era allow it
		var p: Dictionary = lib.part(pid)
		if recipe.parts.has(p.slot) or int(p.get("tier", 1)) > int(ctx.age) or not lib.era_ok(p, ctx.rules.era):
			continue
		if p.slot == "hand_l" and recipe.parts.has("hand_r") and lib.part(recipe.parts.hand_r).get("two_handed", false):
			continue
		recipe.parts[p.slot] = pid
		spent += int(p.points)
	if not recipe.parts.has("hand_r"):
		var need: String = ROLE_NEEDS[role]
		var excluded: Array = ROLE_EXCLUDES.get(role, [])
		var options: Array = _cands("hand_r", ctx).filter(func(p): return need in p.tags and not p.tags.any(func(t): return t in excluded) \
			and _allowed(p, role, unit_tags) and not (th.get("light", false) and "heavy" in p.tags))
		var affordable := options.filter(func(p): return spent + int(p.points) <= budget)
		var primary: Dictionary = _best(affordable if not affordable.is_empty() else [_cheapest(options)], unit_tags, ROLE_BIAS[role], rng)
		recipe.parts.hand_r = primary.id
		spent += int(primary.points)
	var ridden: bool = recipe.has("mount") and not recipe.mount.fused
	for slot in OPTIONAL_SLOTS:
		if recipe.parts.has(slot) or (slot == "hand_l" and lib.part(recipe.parts.hand_r).get("two_handed", false)):
			continue
		var cands: Array = _cands(slot, ctx).filter(func(p): return _allowed(p, role, unit_tags) and not _off_theme(p, unit_tags) and ok.call(p) \
			and not (ridden and "wings" in p.tags and not _winged(unit_tags)) and _fits_mount(p, recipe))
		cands = cands.filter(func(p): return spent + int(p.points) <= budget)
		if cands.is_empty():
			continue
		var best: Dictionary = _best(cands, unit_tags, ROLE_BIAS[role], rng)
		if _want(best, unit_tags) > 0 or rng.chance(45):
			recipe.parts[slot] = best.id
			spent += int(best.points)
	# Its name is the theme's: alone for folk and for the creatures it belongs to (`own`), else the creature's
	# noun first ("Frog Testudo Guard").
	recipe.name = th.noun if c.noun == "Folk" or ctx.creature in th.get("own", []) else "%s %s" % [c.noun, th.noun]
	return recipe


## The optional slots a role fills.
func _gear_slots(role: String) -> Array:
	return {"worker": WORKER_SLOTS, "healer": HEALER_SLOTS, "scout": SCOUT_SLOTS, "sapper": SAPPER_SLOTS}.get(role, OPTIONAL_SLOTS)


## A healer's kit: its bag (heal parts) in the off hand, a light hat (1 point, no crest,
## horns or heavy), wings only if the race flies. Nothing for fighting.
func _healer_gear(p: Dictionary, tags: Dictionary) -> bool:
	match p.slot:
		"hand_l":
			return "heal" in p.tags
		"head_gear":
			return int(p.points) <= 1 and not p.tags.any(func(t): return t in ["crest", "horns", "heavy"])
		"back":
			return "wings" in p.tags and _winged(tags)
	return false


func _allowed(p: Dictionary, role: String, tags: Dictionary) -> bool:
	if p.has("requires_role") and not _for_role(p, role):
		return false
	if p.has("only_if"):
		return p.only_if.any(func(t): return int(tags.get(t, 0)) > 0)
	return true


## The race's own part (favoured and of its creature or culture) or one the prompt asked for.
func _own(p: Dictionary, ctx: Dictionary) -> bool:
	return (p.has("favour") and p.tags.any(func(t): return t in _affinity)) or _want(p, ctx.brief.tags) > 0


## A part's `requires_role`: one role, or a list of them (the khopesh: large and infantry).
func _for_role(p: Dictionary, role: String) -> bool:
	return role in (p.requires_role if p.requires_role is Array else [p.requires_role])


## How much the prompt asked for this part (no randomness).
func _want(p: Dictionary, tags: Dictionary) -> int:
	var s := 0
	for t in p.tags:
		s += int(tags.get(t, 0))
	return s


func _best(cands: Array, tags: Dictionary, bias: Dictionary, rng) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1000000
	for p in cands:
		var s := 0
		for t in p.tags:
			s += 10 * int(tags.get(t, 0)) + 10 * int(bias.get(t, 0))
		if _off_theme(p, tags):
			s -= 100
		if p.has("favour") and p.tags.any(func(t): return t in _affinity):
			s += 10 * int(p.favour)   # a culture's own weapon, wanted over the role's usual pick (parts.json "favour")
		s += rng.range_int(0, 7)
		if s > best_score:
			best_score = s
			best = p
	return best


## Signature gear nobody asked for, and that isn't this race's own thing.
func _off_theme(p: Dictionary, tags: Dictionary) -> bool:
	if _no_restrictions:
		return false   # the host lifted the culture layer (D-070): anyone may have anything
	if p.tags.any(func(t): return t in _affinity):
		return false
	return p.tags.any(func(t): return t in SIGNATURE_TAGS and int(tags.get(t, 0)) == 0)


func _cheapest(cands: Array) -> Dictionary:
	var out: Dictionary = cands[0]
	for p in cands:
		if int(p.points) < int(out.points):
			out = p
	return out


func _choose_mount(ctx: Dictionary, always := false) -> String:
	var brief: Dictionary = ctx.brief
	for m in brief.mounts:
		if m != ctx.creature and _rides(m, ctx.creature):
			return m
		if m != ctx.creature:   # asked for, but it won't carry them (data: "not_ridden_by")
			var note := "%s won't carry %s, so they go on foot." % [lib.creatures[m].plural, lib.creatures[ctx.creature].plural.to_lower()]
			if not note in ctx.notes:
				ctx.notes.append(note)
	if _winged(ctx.tags):
		return ""   # a winged race flies; it rides only when asked to (Dominic, D-059)
	var own: Array = lib.creatures[ctx.creature].get("mounts", []).filter(func(m): return _rides(m, ctx.creature))   # the creature's own (rats ride cats)
	if not own.is_empty() and (always or ctx.rng.chance(85)):
		return ctx.rng.pick(own)
	var family_mounts: Array = lib.families[ctx.family].mounts.filter(func(m): return m != ctx.creature and _rides(m, ctx.creature))
	if family_mounts.is_empty() or not (always or ctx.rng.chance(65)):
		return ""
	return ctx.rng.pick(family_mounts)


## Will this mount carry this rider? (creatures.json "not_ridden_by": bugs on a hummingbird
## looked wrong, Dominic.)
func _rides(mount: String, rider: String) -> bool:
	return not rider in lib.creatures[mount].get("not_ridden_by", [])


## Did the prompt ask for a winged (flying) race?
func _winged(tags: Dictionary) -> bool:
	return int(tags.get("wings", 0)) > 0


## The creature's skins, narrowed to the ones its culture prefers when it names some
## (families.json "skins": Aztec and Nile people tan or dark, Han light or tan).
func _skins(c: Dictionary, family: String) -> Array:
	var prefer: Array = lib.families[family].get("skins", [])
	var both: Array = c.skins.filter(func(s): return s in prefer)
	return both if not both.is_empty() else c.skins


func _mount_for(creature: String, fused: bool, rng, brief: Dictionary, rider_skin: String) -> Dictionary:
	var mc: Dictionary = lib.creatures[creature]
	# A mount's own parts come with it (creatures.json "parts": a hummingbird's wings).
	var m := {"creature": creature, "skin": rng.pick(_mount_skins(mc, rider_skin)), "fused": fused, "parts": mc.get("parts", {}).duplicate()}
	if brief.mount_wings != "" and not fused and not m.parts.has("back"):
		m.parts.back = brief.mount_wings
	return m


## The skins a mount may wear under this rider, each listed as often as its weight (creatures.json
## "skin_weights": fire newts are the usual) and without those it never wears under the rider's
## skin ("skins_not_under": no red eft under a red frog). One pick either way, so a mount without
## these fields picks as it always did.
func _mount_skins(mc: Dictionary, rider_skin: String) -> Array:
	var out := []
	for s in mc.skins:
		if not rider_skin in mc.get("skins_not_under", {}).get(s, []):
			for k in int(mc.get("skin_weights", {}).get(s, 1)):
				out.append(s)
	assert(not out.is_empty(), "a mount with no skin left for its rider")
	return out


func _mount_points(m: Dictionary) -> int:
	var pts := int(lib.part(lib.creatures[m.creature].get("mount_body", lib.creatures[m.creature].body)).points)
	for slot in m.parts:
		pts += int(lib.part(m.parts[slot]).points)
	return pts


## Parts for a slot allowed by the era and by the age being built (parts' `tier`).
func _cands(slot: String, ctx: Dictionary) -> Array:
	var age := int(ctx.get("age", 99))
	return lib.candidates(slot, ctx.rules.era).filter(func(p): return int(p.get("tier", 1)) <= age)


## The same unit one age on: each part may give way to a better one of the new age, in
## the same slot and role, within the culture (no off-theme kit), preferring one that
## shares its tags (reed spear -> bronze spear -> iron pike) so the unit stays itself;
## then empty gear slots fill while the age's budget lasts.
func _upgrade(prev: Dictionary, slot_def: Dictionary, ctx: Dictionary) -> Dictionary:
	var rng = ctx.rng
	var rules: Dictionary = ctx.rules
	var age: int = ctx.age
	var r: Dictionary = prev.duplicate(true)
	r.age = age
	if slot_def.has("engine"):
		return r   # an engine is the same engine in every age (research makes it better)
	var role: String = slot_def.role
	var budget := int(rules.budget[str(age)])
	var unit_tags: Dictionary = ctx.tags.duplicate()
	if r.get("elite", "") == "heavy":
		for t in HEAVY_BOOST:
			unit_tags[t] = int(unit_tags.get(t, 0)) + HEAVY_BOOST[t]
	if role == "healer":
		for t in HEALER_WANTS:
			unit_tags[t] = int(unit_tags.get(t, 0)) + HEALER_WANTS[t]
	var spent := _recipe_points(r)
	var ridden: bool = r.has("mount") and not r.mount.fused
	var slots: Array = r.parts.keys()
	slots.sort()
	if role == "worker":
		slots = slots.filter(func(s): return s == "head_gear")   # workers only get a better hat
	for slot in slots:
		var cur: Dictionary = lib.part(r.parts[slot])
		var kinds: Array = cur.tags.filter(func(t): return t in KIND_TAGS)
		if slot == "hand_r" and "primitive" in cur.tags:
			kinds += ROLE_KINDS.get(role, [])
		var cands: Array = _cands(slot, ctx).filter(func(p): return int(p.get("tier", 1)) > int(cur.get("tier", 1)) \
			and _allowed(p, role, unit_tags) and not _off_theme(p, unit_tags) and _fits_mount(p, r) \
			and (p.tags.any(func(t): return t in kinds) or p.get("replaces", []).any(func(t): return t in kinds) \
				or _want(p, ctx.brief.tags) > 0))   # same kind (or a part that `replaces` it: the frogs' mace after their sword), or asked for (rats with guns)
		if cur.has("upgrade_within"):   # (parts.json: an era pack's kit gives way only to more of its own: no bronze helmet over a sealed visor)
			cands = cands.filter(func(p): return cur.upgrade_within in p.tags)
		if role == "worker":   # a worker's hat gets better, but never a war helmet (no crests, horns, heavy)
			cands = cands.filter(func(p): return int(p.points) <= 2 and not p.tags.any(func(t): return t in ["crest", "horns", "heavy"]))
		if role == "healer" and slot != "hand_r":
			cands = cands.filter(func(p): return _healer_gear(p, unit_tags))
		if role in LIGHT_ROLES and slot != "hand_r":
			cands = cands.filter(_light)
		if slot == "hand_r":
			var need: String = ROLE_NEEDS[role]
			var excluded: Array = ROLE_EXCLUDES.get(role, [])
			cands = cands.filter(func(p): return need in p.tags and not p.tags.any(func(t): return t in excluded))
			# A `fallback` weapon (the plain iron sword) is only the way up for a weapon with no
			# other, and never replaces the culture's own or one that was asked for (the khopesh).
			var others: Array = cands.filter(func(p): return not p.get("fallback", false))
			if not others.is_empty() or _own(cur, ctx):
				cands = others
		if cands.is_empty():
			continue
		var keep := {}
		for t in cur.tags:
			keep[t] = 2
		var best: Dictionary = _best(cands, unit_tags, keep, rng)
		if spent - int(cur.points) + int(best.points) <= budget:
			spent += int(best.points) - int(cur.points)
			r.parts[slot] = best.id
	var open_slots: Array = ([] if role == "worker" else _gear_slots(role)).filter(func(s): return not r.parts.has(s))
	for slot in open_slots:
		if slot == "hand_l" and lib.part(r.parts.hand_r).get("two_handed", false):
			continue
		var cands: Array = _cands(slot, ctx).filter(func(p): return _allowed(p, role, unit_tags) and not _off_theme(p, unit_tags) and _fits_mount(p, r))
		if ridden or role == "worker":
			cands = cands.filter(func(p): return not ("wings" in p.tags))
		if role == "worker":
			cands = cands.filter(func(p): return int(p.points) <= 1)
		if role == "healer":
			cands = cands.filter(func(p): return _healer_gear(p, unit_tags))
		if role in LIGHT_ROLES:
			cands = cands.filter(_light)
		if cands.is_empty():
			continue
		var best: Dictionary = _best(cands, unit_tags, {}, rng)
		if spent + int(best.points) <= budget:
			spent += int(best.points)
			r.parts[slot] = best.id
	r.name = _step_name(prev, r)
	return r


## A line step's name says what got better, so an upgrade never reads "X -> X": the kit's
## own name if the main weapon changed it (Spearbearer -> Pike); else the epithet (data:
## parts.json "epithet") of the best new piece, weapon first, then armour (Bronze
## Spearbearer, Plated Lancer); else the culture's rank word for this step (families.json
## "ranks": Veteran, Praetorian). Same kit keeps the same name: that step changes nothing.
## Workers follow the age without an upgrade, so they keep their plain name.
func _step_name(prev: Dictionary, r: Dictionary) -> String:
	var c: Dictionary = lib.creatures[r.creature]
	var plain := _unit_name(r, lib.part(r.parts.hand_r), c)
	if r.parts == prev.parts:
		return prev.name
	if r.role == "worker" or plain != _unit_name(prev, lib.part(prev.parts.hand_r), c):
		return plain
	for slot in EPITHET_SLOTS:
		var id: String = r.parts.get(slot, "")
		if id != "" and id != prev.parts.get(slot, ""):
			var epithet: String = lib.part(id).get("epithet", "")
			if epithet != "" and not prev.name.begins_with(epithet + " "):
				return "%s %s" % [epithet, plain]
	var ranks: Array = lib.families[r.family].ranks
	return "%s %s" % [ranks[mini(int(r.age) - int(r.tier) - 1, ranks.size() - 1)], plain]


## Points a recipe spends (body, head, mount and parts), as the budget counts them.
func _recipe_points(r: Dictionary) -> int:
	var pts := int(lib.part(r.body).points)
	for slot in r.parts:
		pts += int(lib.part(r.parts[slot]).points)
	if r.has("mount"):
		pts += _mount_points(r.mount)
	if int(r.scale) >= GIANT_SCALE:
		pts += Pricing.GIANT_POINTS
	return pts


func _unit_name(recipe: Dictionary, primary: Dictionary, c: Dictionary) -> String:
	var noun: String = recipe.get("noun", primary.noun)
	var who: String = c.noun
	var name := noun if who == "Folk" else "%s %s" % [noun, who]
	if recipe.scale >= GIANT_SCALE:
		name = "Giant " + name
	elif recipe.scale <= TINY_SCALE:
		name = "Tiny " + name
	elif recipe.get("elite", "") == "heavy":
		name = "Heavy " + name
	if recipe.has("mount") and not recipe.mount.fused:
		var mount_noun: String = lib.creatures[recipe.mount.creature].noun
		if recipe.mount.parts.has("back") and not lib.creatures[recipe.mount.creature].get("parts", {}).has("back"):   # its own wings go without saying
			mount_noun = "Pegasus" if recipe.mount.creature == "pony" else "Winged " + mount_noun
		name += " on a " + mount_noun
	return name
