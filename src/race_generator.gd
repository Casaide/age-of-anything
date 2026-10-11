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

const ROLE_NEEDS := {"worker": "worker", "spear": "spear", "skirmisher": "ranged", "archer": "bow", "large": "melee"}
## Tags a role's primary must not have (skirmishers are the non-bow ranged units).
const ROLE_EXCLUDES := {"skirmisher": ["bow"]}
const ROLE_BIAS := {
	"worker": {},
	"spear": {"reach": 1},
	"skirmisher": {"skirmish": 2},
	"archer": {},
	"large": {"charge": 3, "heavy": 2, "lance": 3},
}
## Signature gear (a culture's kit, cheese hammers...) is only favoured when the prompt,
## family or creature asks for it. No cheese hammers for Romans unless someone says cheese.
const SIGNATURE_TAGS := ["roman", "greek", "viking", "cheese", "woodland", "knight", "bat", "crossbow", "junk", "saucepan", "nile", "han", "aztec"]   # woodland: acorn caps, leaves, bark (swamp/forest); knight: iron helm, kite, mail (royal); bat wings (spooky/sewer); crossbows (royal, sewer rats); junk: bottle caps (sewer); saucepan: only when asked (ww2)
## Extra wants for "Heavy" large units (armoured elites instead of giants).
const HEAVY_BOOST := {"heavy": 3, "armour": 3, "helmet": 2, "shield": 1}   # no "knight": knight kit is the royal culture's signature
const OPTIONAL_SLOTS := ["hand_l", "head_gear", "torso", "back"]
## What kind of thing a part is: an upgrade keeps the kind (a cape stays a cape, a
## spear stays a spear), so a unit line stays recognisably the same unit.
const KIND_TAGS := ["spear", "lance", "blade", "blunt", "bow", "sling", "javelin", "poison", "gun", "worker",
	"shield", "helmet", "hat", "armour", "cape", "banner", "wings", "quiver"]
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
		"creature": creature, "family": family, "skin": rng.pick(_skins(c, family)),
	}
	# Each roster slot is a unit line through the ages (D-057): first the unit at the age
	# its slot opens, in that age's kit; then, in a second pass (so the first recipes don't
	# depend on the later ones), the same unit upgraded for every later age.
	var units := []
	for slot_def in rules.roster:
		ctx.age = int(slot_def.tier)
		var recipe := _make_unit(slot_def, ctx)
		var first := {"age": ctx.age, "recipe": recipe, "eval": Pricing.evaluate(recipe, lib, rules)}
		units.append({"recipe": recipe, "eval": first.eval, "line": [first]})
	for k in units.size():
		var slot_def: Dictionary = rules.roster[k]
		for age in range(int(slot_def.tier) + 1, int(rules.get("ages", 1)) + 1):
			ctx.age = age
			var up := _upgrade(units[k].line[-1].recipe, slot_def, ctx)
			units[k].line.append({"age": age, "recipe": up, "eval": Pricing.evaluate(up, lib, rules)})

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
		"economy": c.get("economy", {}).duplicate(),   # race-wide modifiers; derived, not in the key
	}
	race.key = race_key(race)
	return race


## Hash of the shareable content only (names + recipes), not derived stats.
static func race_key(race: Dictionary) -> String:
	var shareable := {
		"schema": race.schema, "name": race.name, "creature": race.creature, "family": race.family,
		"recipes": race.units.map(func(u): return u.line.map(func(l): return l.recipe) if u.has("line") else [u.recipe]),
	}
	return JSON.stringify(shareable, "", true).sha256_text()


func _race_name(rng, c: Dictionary, family: String) -> String:
	var f: Dictionary = lib.families[family]
	if rng.chance(30):
		return "%s %s" % [f.adjective, c.plural]
	return rng.pick(f.prefixes) + rng.pick(f.suffixes)


# ------------------------------------------------------------------ units

func _make_unit(slot_def: Dictionary, ctx: Dictionary) -> Dictionary:
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
		recipe.mount = _mount_for(c.fused_mount, true, rng, brief)
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
			recipe.mount = _mount_for(mount, false, rng, brief)
			spent += _mount_points(recipe.mount)
		elif giant_ok:
			recipe.scale = GIANT_SCALE
			spent += Pricing.GIANT_POINTS
		else:
			heavy = true
	elif role == "archer" and int(ctx.tags.get("mounted", 0)) >= 2:
		var mount := _choose_mount(ctx)
		if mount != "":
			var m := _mount_for(mount, false, rng, brief)
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
	recipe.name = _unit_name(recipe, primary, c)

	# Optional gear: most-wanted slot first, while the budget lasts
	var slots: Array = WORKER_SLOTS if role == "worker" else OPTIONAL_SLOTS
	var picks := []
	for slot in rng.shuffled(slots):
		if slot == "hand_l" and primary.get("two_handed", false):
			continue
		var cands: Array = _cands(slot, ctx).filter(func(p): return _allowed(p, role, unit_tags))
		if ridden and not _winged(unit_tags):
			cands = cands.filter(func(p): return not ("wings" in p.tags))
		if role == "worker":
			cands = cands.filter(func(p): return int(p.points) <= 1)
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


func _allowed(p: Dictionary, role: String, tags: Dictionary) -> bool:
	if p.has("requires_role") and p.requires_role != role:
		return false
	if p.has("only_if"):
		return p.only_if.any(func(t): return int(tags.get(t, 0)) > 0)
	return true


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
		if m != ctx.creature:
			return m
	if _winged(ctx.tags):
		return ""   # a winged race flies; it rides only when asked to (Dominic, D-059)
	var own: Array = lib.creatures[ctx.creature].get("mounts", [])   # the creature's own (rats ride capybaras)
	if not own.is_empty() and (always or ctx.rng.chance(85)):
		return ctx.rng.pick(own)
	var family_mounts: Array = lib.families[ctx.family].mounts.filter(func(m): return m != ctx.creature)
	if family_mounts.is_empty() or not (always or ctx.rng.chance(65)):
		return ""
	return ctx.rng.pick(family_mounts)


## Did the prompt ask for a winged (flying) race?
func _winged(tags: Dictionary) -> bool:
	return int(tags.get("wings", 0)) > 0


## The creature's skins, narrowed to the ones its culture prefers when it names some
## (families.json "skins": Aztec and Nile people tan or dark, Han light or tan).
func _skins(c: Dictionary, family: String) -> Array:
	var prefer: Array = lib.families[family].get("skins", [])
	var both: Array = c.skins.filter(func(s): return s in prefer)
	return both if not both.is_empty() else c.skins


func _mount_for(creature: String, fused: bool, rng, brief: Dictionary) -> Dictionary:
	var mc: Dictionary = lib.creatures[creature]
	var m := {"creature": creature, "skin": rng.pick(mc.skins), "fused": fused, "parts": {}}
	if brief.mount_wings != "" and not fused:
		m.parts.back = brief.mount_wings
	return m


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
	var role: String = slot_def.role
	var budget := int(rules.budget[str(age)])
	var unit_tags: Dictionary = ctx.tags.duplicate()
	if r.get("elite", "") == "heavy":
		for t in HEAVY_BOOST:
			unit_tags[t] = int(unit_tags.get(t, 0)) + HEAVY_BOOST[t]
	var spent := _recipe_points(r)
	var ridden: bool = r.has("mount") and not r.mount.fused
	var slots: Array = r.parts.keys()
	slots.sort()
	if role == "worker":
		slots = slots.filter(func(s): return s == "head_gear")   # workers only get a better hat
	for slot in slots:
		var cur: Dictionary = lib.part(r.parts[slot])
		var kinds: Array = cur.tags.filter(func(t): return t in KIND_TAGS)
		var cands: Array = _cands(slot, ctx).filter(func(p): return int(p.get("tier", 1)) > int(cur.get("tier", 1)) \
			and _allowed(p, role, unit_tags) and not _off_theme(p, unit_tags) \
			and (p.tags.any(func(t): return t in kinds) or _want(p, ctx.brief.tags) > 0))   # same kind, or asked for (rats with guns)
		if role == "worker":   # a worker's hat gets better, but never a war helmet (no crests, horns, heavy)
			cands = cands.filter(func(p): return int(p.points) <= 2 and not p.tags.any(func(t): return t in ["crest", "horns", "heavy"]))
		if slot == "hand_r":
			var need: String = ROLE_NEEDS[role]
			var excluded: Array = ROLE_EXCLUDES.get(role, [])
			cands = cands.filter(func(p): return need in p.tags and not p.tags.any(func(t): return t in excluded))
		if cands.is_empty():
			continue
		var keep := {}
		for t in cur.tags:
			keep[t] = 2
		var best: Dictionary = _best(cands, unit_tags, keep, rng)
		if spent - int(cur.points) + int(best.points) <= budget:
			spent += int(best.points) - int(cur.points)
			r.parts[slot] = best.id
	var open_slots: Array = ([] if role == "worker" else OPTIONAL_SLOTS).filter(func(s): return not r.parts.has(s))
	for slot in open_slots:
		if slot == "hand_l" and lib.part(r.parts.hand_r).get("two_handed", false):
			continue
		var cands: Array = _cands(slot, ctx).filter(func(p): return _allowed(p, role, unit_tags) and not _off_theme(p, unit_tags))
		if ridden or role == "worker":
			cands = cands.filter(func(p): return not ("wings" in p.tags))
		if role == "worker":
			cands = cands.filter(func(p): return int(p.points) <= 1)
		if cands.is_empty():
			continue
		var best: Dictionary = _best(cands, unit_tags, {}, rng)
		if spent + int(best.points) <= budget:
			spent += int(best.points)
			r.parts[slot] = best.id
	r.name = _unit_name(r, lib.part(r.parts.hand_r), lib.creatures[r.creature])
	return r


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
	var noun: String = primary.noun
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
		if recipe.mount.parts.has("back"):
			mount_noun = "Pegasus" if recipe.mount.creature == "pony" else "Winged " + mount_noun
		name += " on a " + mount_noun
	return name
