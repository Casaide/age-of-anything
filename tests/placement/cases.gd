extends RefCounted
## The units the placement checks cover (tests/placement_check.gd, tests/layer_check.gd): every unit
## of these races at every age of its line (so every body, head, leg, hold and piece of gear in
## play), the scouts, mounted archers and unique units of more races (every unique theme), every rider on
## every mount, winged mounts, every newt skin and cat coat, the animals and the siege
## engines with their crews. [label, unit] pairs; a unit is {recipe, eval}.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")

## Races whose every unit is checked (between them: every playable body, every hold, back parts,
## wings, a fused centaur, siege crews).
const PROMPTS := ["romans", "swamp frogs", "sewer rats", "forest beetles", "spooky spiders",
	"flying greeks with wings", "centaur romans", "winged frogs"]
## More races for milestone 13's new lines only (scouts, mounted archers, unique units): with PROMPTS,
## every unique theme in data/uniques.json, a foot scout, the steppe raider on its pony.
const LINE_PROMPTS := ["greeks", "royal humans", "mongols", "aztecs", "egyptians", "han", "sewer rats with cheese hammers",
	"tiny vikings", "swamp humans", "forest humans", "sewer humans", "spooky humans"]
const NEW_LINES := ["scout", "mounted_archer", "unique", "large"]   # (and the cavalry, which rides the same mounts)
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
			cases.append(["%s %s" % [p, u.recipe.slot], u])
			if not lines:
				continue
			var steps: Array = u.get("line", [])
			for i in range(1, steps.size()):
				var s: Dictionary = steps[i]
				if s.recipe.hash() != u.recipe.hash():
					cases.append(["%s %s age %d" % [p, u.recipe.slot, s.get("age", i + 1)], {"recipe": s.recipe, "eval": s.eval}])
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
	cases += kit_cases(lib)
	return cases


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
