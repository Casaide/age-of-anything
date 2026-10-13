extends RefCounted
## The units the placement checks cover (tests/placement_check.gd, tests/layer_check.gd): every unit
## of these races at every age of its line (so every body, head, leg, hold and piece of gear in
## play), every rider on every mount, winged mounts, every newt skin, the animals and the siege
## engines with their crews. [label, unit] pairs; a unit is {recipe, eval}.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

## Races whose every unit is checked (between them: every playable body, every hold, back parts,
## wings, a fused centaur, siege crews).
const PROMPTS := ["romans", "swamp frogs", "sewer rats", "forest beetles", "spooky spiders",
	"flying greeks with wings", "centaur romans", "winged frogs"]
## Riders (a race's spear unit, put on each mount) and the mounts.
const RIDERS := ["romans", "swamp frogs", "sewer rats", "spooky spiders", "forest beetles"]
const MOUNTS := ["pony", "beetle", "spider", "capybara", "newt", "hummingbird"]


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
	var animals: Dictionary = ArtKit.animal_race()
	for u in animals.units:
		cases.append(["animal %s" % u.recipe.body, u])
	return cases


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
