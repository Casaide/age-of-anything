extends RefCounted
## The units the placement checks cover (tests/placement_check.gd, tests/layer_check.gd): every unit
## of these races at every age of its line (so every body, head, leg, hold and piece of gear in
## play), the scouts, mounted archers and unique units of more races (every unique theme), every rider on
## every mount, winged mounts, every newt skin and cat coat, the animals and the siege
## engines with their crews, and every hero look on every playable body it can come to (hero_cases).
## [label, unit] pairs; a unit is {recipe, eval}.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Heroes := preload("res://src/heroes.gd")
const Pricing := preload("res://src/pricing.gd")

## Races whose every unit is checked (between them: every playable body, every hold, back parts,
## wings, a fused centaur, siege crews).
const PROMPTS := ["romans", "swamp frogs", "sewer rats", "rats", "forest beetles", "spooky spiders",
	"flying greeks with wings", "centaur romans", "winged frogs", "vikings"]
## More races for milestone 13's new lines only (scouts, mounted archers, unique units): with PROMPTS,
## every unique theme in data/uniques.json, a foot scout, the steppe raider on its pony; the sapper, trade cart and great sling.
const LINE_PROMPTS := ["greeks", "royal humans", "mongols", "aztecs", "egyptians", "han", "sewer rats with cheese hammers",
	"tiny vikings", "swamp humans", "forest humans", "sewer humans", "spooky humans"]
const NEW_LINES := ["scout", "mounted_archer", "unique", "large", "trader", "great_sling", "war_beast"]   # (and the cavalry, which rides the same mounts; the sapper in every culture's cap, the cart and the great sling of every take, every war beast with its riders)
## Riders (a race's spear unit, put on each mount) and the mounts.
const RIDERS := ["romans", "swamp frogs", "sewer rats", "spooky spiders", "forest beetles"]
const MOUNTS := ["pony", "beetle", "spider", "capybara", "newt", "hummingbird", "cat"]


## lines: also every later age of each unit line (their own armour, helmets, weapons).
static func all(lib, lines := true) -> Array:
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var cases := []
	for p in PROMPTS:
		var race: Dictionary = gen.generate(p, rules)
		for u in race.units:
			var lk := Heroes.line_key(u.recipe)   # (a race's heroes share the hero line: each by its signature)
			cases.append(["%s %s" % [p, lk], u])
			if not lines:
				continue
			var steps: Array = u.get("line", [])
			for i in range(1, steps.size()):
				var s: Dictionary = steps[i]
				if s.recipe.hash() != u.recipe.hash():
					cases.append(["%s %s age %d" % [p, lk, s.get("age", i + 1)], {"recipe": s.recipe, "eval": s.eval}])
	# The swordsman's age-3 kit (D-125) for the cultures PROMPTS leaves out (the frogs' mace, the
	# beetles' chitin blade and the spiders' hook come in with their races above), and the plain
	# iron sword, the fallback, which royal humans get under the bronze rules (no royal iron there).
	var swords := [["greeks", rules], ["mongols", rules], ["han", rules], ["royal humans", DataLib.load_json("res://data/rules/bronze.json")]]
	for s in swords:
		var line: Array = slot(gen.generate(s[0], s[1]), "infantry").line
		for l in line:
			if int(l.age) >= 2:
				cases.append(["%s swordsman age %d%s" % [s[0], l.age, " (bronze rules)" if s[1] != rules else ""], {"recipe": l.recipe, "eval": l.eval}])
	for p in LINE_PROMPTS:
		for u in gen.generate(p, rules).units:
			if u.recipe.slot in NEW_LINES:
				cases.append(["%s %s" % [p, u.recipe.slot], u])
				if lines and u.line.size() > 1 and u.line[-1].recipe.hash() != u.recipe.hash():
					cases.append(["%s %s age %d" % [p, u.recipe.slot, u.line[-1].age], {"recipe": u.line[-1].recipe, "eval": u.line[-1].eval}])
	for p in RIDERS:
		var spear: Dictionary = slot(gen.generate(p, rules), "spear")
		for m in MOUNTS:
			cases.append(["%s on %s" % [spear.recipe.creature, m], ride(spear, m, lib.creatures[m].skins[0], {})])
	var human: Dictionary = slot(gen.generate("romans", rules), "spear")
	for m in ["pony", "beetle", "spider"]:   # winged mounts (a "pegasus": the mount's wings at its withers)
		cases.append(["human on winged %s" % m, ride(human, m, lib.creatures[m].skins[0], {"back": "wings.feather"})])
	var frog: Dictionary = slot(gen.generate("swamp frogs", rules), "spear")
	for skin in lib.creatures.newt.skins:   # every newt (the crested ones carry a crest)
		cases.append(["frog on %s" % skin, ride(frog, "newt", skin, {})])
	var rat: Dictionary = slot(gen.generate("sewer rats", rules), "spear")
	for skin in lib.creatures.cat.skins:   # every cat coat under the rats (D-124; it sits when idle)
		cases.append(["rat on %s" % skin, ride(rat, "cat", skin, {})])
	var animals: Dictionary = ArtKit.animal_race()
	for u in animals.units:
		cases.append(["animal %s" % u.recipe.body, u])
	cases += hero_cases(lib, gen, rules)
	cases += norse_cases(lib, gen, rules)
	cases += gear_cases(lib, gen, rules)
	cases += kit_cases(lib)
	cases += composite_cases(lib)
	cases += mod_cases(lib)
	return cases


## Heroes (D-138): any culture's hero can come to any playable creature, and a creature's own to it,
## so every such look is checked over that creature's age-3 swordsman (the hero's last step) from its
## race in PROMPTS (HERO_BASE: kit already checked above), its replaced kit kept as in play
## (src/heroes.gd dress). Labels "hero: <creature> as <signature>".
const HERO_BASE := {"frog": "swamp frogs", "rat": "sewer rats", "human": "romans", "spider": "spooky spiders",
	"beetle": "forest beetles", "centaur": "centaur romans"}


static func hero_cases(lib, gen, rules: Dictionary) -> Array:
	var out := []
	var sigs: Array = lib.heroes.hero_signatures.keys()
	sigs.sort()
	var in_play: Dictionary = DataLib.load_json("res://data/creatures.json")   # (not creatures staged from data/later/: the bears)
	for cid in lib.creature_ids("playable"):
		if not in_play.has(cid):
			continue
		assert(HERO_BASE.has(cid), "hero cases: a race in PROMPTS for %s (HERO_BASE)" % cid)
		var race: Dictionary = gen.generate(HERO_BASE[cid], rules)
		var sword: Dictionary = slot(race, "infantry")
		var step: Dictionary = sword.line[-1]
		for sid in sigs:
			var s: Dictionary = lib.heroes.hero_signatures[sid]
			if not (cid in s.who.get("creature", []) or not s.who.get("family", []).is_empty()):
				continue
			var r := Heroes.dress(step.recipe, sid, s, sid, int(Heroes.slot_def(rules).tier))
			out.append(["hero: %s as %s" % [cid, sid], {"recipe": r, "eval": Pricing.evaluate(r, lib, rules)}])   # (its own tags: how it holds its weapon)
	return out


## The Norse culture's kit (2026-10-17, D-151): any creature can be Norse ("viking frogs"), so each
## Norse part is put on every playable body, over the unit of HERO_BASE's race (its kit already
## checked above) that would wear or hold it: helmets on the age-3 swordsman and the spear rider, the
## axes in the swordsman's, rider's and scout's hands, the rune staff in the healer's. The horned
## helmet (an older part the Norse wear everywhere) comes too; shields: gear_cases. Labels
## "norse: <creature> <unit> with <part>".
const NORSE_HELMS := ["helm.norse_fur", "helm.norse_conical", "helm.norse_spectacle", "helm.horned"]
const NORSE_AXES := ["weapon.axe.bearded", "weapon.axe.broad"]


static func norse_cases(lib, gen, rules: Dictionary) -> Array:
	var out := []
	var in_play: Dictionary = DataLib.load_json("res://data/creatures.json")
	for cid in lib.creature_ids("playable"):
		if not in_play.has(cid):
			continue
		var race: Dictionary = gen.generate(HERO_BASE[cid], rules)
		var sword: Dictionary = slot(race, "infantry").line[-1]
		var put := func(label: String, base: Dictionary, parts: Dictionary) -> void:
			var r: Dictionary = base.recipe.duplicate(true)
			r.parts.merge(parts, true)
			out.append(["norse: %s %s" % [cid, label], {"recipe": r, "eval": Pricing.evaluate(r, lib, rules)}])
		for h in NORSE_HELMS:
			put.call("swordsman with %s" % h, sword, {"head_gear": h})
		for a in NORSE_AXES:
			put.call("swordsman with %s" % a, sword, {"hand_r": a})
		var rider: Dictionary = ride(slot(race, "spear"), "pony", lib.creatures.pony.skins[0], {})
		if cid != "centaur":
			put.call("rider with weapon.axe.bearded and helm.norse_conical", rider, {"hand_r": "weapon.axe.bearded", "head_gear": "helm.norse_conical"})
		var scout: Dictionary = slot(race, "scout")
		put.call("scout with weapon.axe.bearded and helm.norse_fur", scout, {"hand_r": "weapon.axe.bearded", "head_gear": "helm.norse_fur"})
		put.call("healer with tool.staff.rune", slot(race, "healer"), {"hand_r": "tool.staff.rune"})
	return out


## Off-hand and back gear on every body (2026-10-17, Dominic: "fix the shields etc for spiders and bugs"):
## a culture can come to any creature ("viking spiders", "aztec beetles"), so every shield and every cape
## and banner goes on each playable body's age-3 swordsman (HERO_BASE's race), every quiver on its archer
## and every healer's bag in its healer's off hand. Labels "gear: <creature> <unit> with <part>".
static func gear_cases(lib, gen, rules: Dictionary) -> Array:
	var out := []
	var in_play: Dictionary = DataLib.load_json("res://data/creatures.json")
	var ids: Array = lib.parts.keys()
	ids.sort()
	for cid in lib.creature_ids("playable"):
		if not in_play.has(cid):
			continue
		var race: Dictionary = gen.generate(HERO_BASE[cid], rules)
		var units := {"infantry": slot(race, "infantry").line[-1], "archer": slot(race, "archer").line[-1], "healer": slot(race, "healer")}
		for id in ids:
			var p: Dictionary = lib.part(id)
			if p.slot != "hand_l" and p.slot != "back" or "hero_only" in p.get("only_if", []) or "flying" in p.tags:
				continue
			var who := "healer" if "heal" in p.tags else ("archer" if "quiver" in p.tags else "infantry")
			if units[who].recipe.body in p.get("not_worn_by", []):
				continue   # (the generator never puts it on this body: parts.json not_worn_by)
			var r: Dictionary = units[who].recipe.duplicate(true)
			r.parts[p.slot] = id
			out.append(["gear: %s %s with %s" % [cid, who, id], {"recipe": r, "eval": Pricing.evaluate(r, lib, rules)}])
	return out


## Concept composites (staged from data/later/): the trade carts of round TC1 whose beasts haul them,
## each in its draught harness, a handler beside it (A, every family) and the covered wagon (two ponies,
## a driver on top). Dominic caught TC1 A for rats ("this is bugged, did the tests not catch it?"): its
## fixtures (fixtures_3d.gd, fixtures_2d.gd) put that cart back. Labels "composite: ...".
const COMPOSITE_FILES := ["res://data/later/trade_carts.json"]
const COMPOSITE_CASES := [
	["romans", "concept.tc1_a_timber", "pony", "pony_bay"], ["swamp frogs", "concept.tc1_a_frog", "newt", "newt_fire"],
	["sewer rats", "concept.tc1_a_junk", "cat", "cat_ginger"], ["forest beetles", "concept.tc1_a_forest", "beetle", "beetle_stag"],
	["spooky spiders", "concept.tc1_a_spooky", "spider", "spider_black"], ["romans", "concept.tc1_c_timber", "pony", "pony_grey"],
]


static func composite_cases(lib) -> Array:
	for f in COMPOSITE_FILES:
		CreatureKit.stage(lib, f)
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var cases := []
	for c in COMPOSITE_CASES:
		var u: Dictionary = slot(gen.generate(c[0], rules), "trader")
		var step: Dictionary = u.line[-1] if u.line.size() > 1 else {"recipe": u.recipe, "eval": u.eval}
		var r: Dictionary = step.recipe.duplicate(true)
		r.body = c[1]
		r.haul = {"creature": c[2], "skin": c[3], "parts": {"torso": "harness.draught"}}
		cases.append(["composite: %s %s hauled by a %s" % [c[0], c[1].trim_prefix("concept."), c[2]], {"recipe": r, "eval": step.eval}])
	# In play: the great sling packed on its wagon while it moves (D-129, UnitView.set_packed), every take that has it,
	# and the frogs' as it throws (D-131, UnitView.loose: the bullfrog landed on the pad).
	for p in ["romans", "sewer rats", "forest beetles", "spooky spiders", "centaur romans", "swamp frogs", "winged frogs"]:
		var u: Dictionary = slot(gen.generate(p, rules), "great_sling")
		for look in ["packed", "throw"]:
			var shown: String = lib.part(u.recipe.body).get(look, "")
			if shown != "":
				var r: Dictionary = u.recipe.duplicate(true)
				r.body = shown
				cases.append(["composite: %s great sling %s" % [p, "packed" if look == "packed" else "throwing"], {"recipe": r, "eval": u.eval}])
	# In play: what a worker pushes home (D-127: the rats' scrap barrow with stone, handcart with gold).
	for p in ["sewer rats", "sewer rats with cheese hammers"]:
		var w: Dictionary = slot(gen.generate(p, rules), "worker")
		var pushes: Dictionary = lib.creatures[w.recipe.creature].get("push_home", {})
		for res in pushes:
			cases.append(["composite: %s worker pushing %s home" % [p, res], {"recipe": UnitView.push_recipe(w.recipe, pushes[res]), "eval": w.eval}])
	return cases


## The mods in use (src/mods.gd; AOW_MODS=scifi_test): every unit, at every age of its line, of each
## prompt the mod's manifest lists under "check" (under its rules) that wears or holds one of the mod's
## parts (the rest is the game's own kit, checked above), labelled "mod <id>: ...".
static func mod_cases(lib) -> Array:
	var gen = Generator.new(lib)
	var out := []
	for rec in DataLib.Mods.active:
		var chk: Dictionary = rec.manifest.get("check", {})
		var rules = DataLib.load_rules(chk.get("rules", "default"))
		var own: Array = rec.data.get("parts.json", []).map(func(q): return q.id)
		for p in chk.get("prompts", []):
			for u in gen.generate(p, rules).units:
				var seen := {}
				for s in u.get("line", [{"recipe": u.recipe, "eval": u.eval}]):
					var sig := JSON.stringify(s.recipe.parts, "", true)
					if not seen.has(sig) and s.recipe.parts.values().any(func(id): return id in own):
						seen[sig] = true
						out.append(["mod %s: %s %s age %d" % [rec.id, p, s.recipe.slot, int(s.recipe.get("age", s.recipe.tier))], {"recipe": s.recipe, "eval": s.eval}])
	return out


## Creature-kit creatures (scenes/art_pixel/creature_kit.gd), staged from their data files: the cat
## rebuilt through the kit under a rat, and the bear concepts (data/later/bears.json: bipeds of three
## builds, a worker, the giant, the mount under a human and a rat). Placement holds by construction.
const KIT_FILES := ["res://data/creature_kit.json", "res://data/later/bears.json"]


static func kit_cases(lib) -> Array:
	for f in KIT_FILES:
		CreatureKit.stage(lib, f)
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var cases := []
	var rat: Dictionary = slot(gen.generate("sewer rats", rules), "spear")
	for m in ["kitcat", "kitcat_built"]:
		cases.append(["kit: rat on %s" % m, ride(rat, m, lib.creatures[m].skins[0], {})])
	for b in BEAR_CASES:
		var race: Dictionary = gen.generate(b[1], rules)
		var u: Dictionary = slot(race, b[2]).duplicate(true)
		u.recipe.merge(b[3], true)
		u.erase("line")   # (else its age line, not the overridden recipe, is what bakes)
		cases.append(["kit: " + b[0], u])
	var human: Dictionary = slot(gen.generate("romans", rules), "spear")
	for skin in lib.creatures.bear.skins:
		cases.append(["kit: human on bear %s" % skin, ride(human, "bear", skin, {})])
	cases.append(["kit: rat on bear", ride(rat, "bear", "bear_brown", {})])
	cases.append(["kit: human on black bear", ride(human, "bear_black", "bear_black", {})])
	return cases


## [label, prompt, slot, recipe overrides]: the bear concepts' units (docs/concepts/bears).
const BEAR_CASES := [
	["brown bear spear", "bear greeks", "spear", {"skin": "bear_brown", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bear_crest"}}],
	["brown bear stock helm", "bear greeks", "spear", {"skin": "bear_brown", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bronze"}}],
	["brown bear open helm", "bear greeks", "spear", {"skin": "bear_brown", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bear_open"}}],
	["brown bear worker", "bear greeks", "worker", {"skin": "bear_brown"}],
	["brown bear infantry", "bear greeks", "infantry", {"skin": "bear_brown"}],
	["black bear spear", "bear greeks", "spear", {"creature": "bear_black", "body": "body.bear_black", "head": "head.bear_black", "skin": "bear_black", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bear_crest"}}],
	["polar bear spear", "bear greeks", "spear", {"creature": "bear_polar", "body": "body.bear_polar", "head": "head.bear_polar", "skin": "bear_polar", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bear_crest"}}],
	["giant polar bear", "giant bear greeks", "large", {"creature": "bear_polar", "body": "body.bear_polar", "head": "head.bear_polar", "skin": "bear_polar", "parts": {"hand_r": "weapon.dory", "hand_l": "shield.hoplon", "torso": "armour.bronze", "head_gear": "helm.bear_crest"}}],
	["giant old bear", "giant bear greeks", "large", {"skin": "bear_grizzled", "parts": {"hand_r": "weapon.sword.xiphos", "torso": "armour.bronze", "head_gear": "helm.bear_crest"}}],
]


static func slot(race: Dictionary, s: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == s:
			return u
	assert(false, "no %s unit" % s)
	return {}


## A unit put on a mount (only its own recipe: a unit's age line would bake instead of it).
static func ride(unit: Dictionary, mount: String, skin: String, parts: Dictionary) -> Dictionary:
	var r: Dictionary = unit.recipe.duplicate(true)
	r.mount = {"creature": mount, "fused": false, "parts": parts, "skin": skin}
	return {"recipe": r, "eval": unit.eval}
