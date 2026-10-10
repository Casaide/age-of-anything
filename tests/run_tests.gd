extends SceneTree
## Headless checks for the race generator and composer.
## Run: godot --headless --path . --script res://tests/run_tests.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")

const PROMPTS := [
	"angry swamp frogs with reed spears",
	"sewer rats with cheese hammers",
	"centaur romans",
	"flying greeks with wings",
	"ww2 americans riding mongolian ponies",
	"giant spiders",
	"tiny vikings",
	"spooky beetle knights",
	"pegasus riding spartans",
	"",
	"blorp zang wibble",
]

var failures := 0
var checks := 0


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules := {}
	for id in ["default", "bronze", "anything"]:
		rules[id] = DataLib.load_json("res://data/rules/%s.json" % id)

	_test_data(lib)
	_test_determinism(gen, rules.default)
	_test_bounds(lib, gen, rules)
	_test_prompts(gen, rules)
	_test_composer(lib, gen, rules.default)

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _test_data(lib) -> void:
	for id in lib.parts:
		var p: Dictionary = lib.parts[id]
		check(p.has("slot") and p.has("shapes"), "part %s has slot and shapes" % id)
		if p.slot == "body" and p.has("legs"):
			check(lib.parts.has(p.legs.part), "body %s leg part exists" % id)
	for id in lib.creatures:
		var c: Dictionary = lib.creatures[id]
		check(lib.parts.has(c.body) and lib.parts.has(c.head), "creature %s body/head exist" % id)
		for s in c.skins:
			check(lib.palettes.skins.has(s), "creature %s skin %s exists" % [id, s])
		for f in c.families:
			check(lib.families.has(f), "creature %s family %s exists" % [id, f])
	for w in lib.lexicon:
		var e: Dictionary = lib.lexicon[w]
		if e.has("creature"):
			check(lib.creatures.has(e.creature), "lexicon %s creature exists" % w)
		if e.has("family"):
			check(lib.families.has(e.family), "lexicon %s family exists" % w)
		if e.has("mount_wings"):
			check(lib.parts.has(e.mount_wings), "lexicon %s wings part exists" % w)


func _test_determinism(gen, rules: Dictionary) -> void:
	for prompt in PROMPTS:
		var a: Dictionary = gen.generate(prompt, rules, 0)
		var b: Dictionary = gen.generate(prompt, rules, 0)
		check(a.key == b.key, "same prompt gives same key: '%s'" % prompt)
		check(JSON.stringify(a, "", true) == JSON.stringify(b, "", true), "same prompt gives identical race: '%s'" % prompt)
	var keys := {}
	for reroll in 8:
		keys[gen.generate("angry swamp frogs", rules, reroll).key] = true
	check(keys.size() >= 6, "rerolls give different races (%d/8 distinct)" % keys.size())
	check(gen.generate("Angry  SWAMP frogs!", rules).key == gen.generate("angry swamp frogs", rules).key, "prompt normalisation")


func _test_bounds(lib, gen, rules: Dictionary) -> void:
	for rid in rules:
		var r: Dictionary = rules[rid]
		for prompt in PROMPTS:
			for reroll in 6:
				var race: Dictionary = gen.generate(prompt, r, reroll)
				check(race.units.size() == r.roster.size(), "roster size %s/%s" % [rid, prompt])
				for u in race.units:
					var rec: Dictionary = u.recipe
					for slot in rec.parts:
						var p: Dictionary = lib.part(rec.parts[slot])
						check(DataLib.era_ok(p, r.era), "%s: %s allowed in %s" % [rec.name, p.id, rid])
						check(p.slot == slot, "%s in matching slot" % p.id)
					var need: String = Generator.ROLE_NEEDS[rec.role]
					check(need in lib.part(rec.parts.hand_r).tags, "%s primary has %s" % [rec.name, need])
					check(u.eval.cost.food + u.eval.cost.wood > 0, "%s has a cost" % rec.name)
					if rec.role == "skirmisher":
						check(not ("bow" in lib.part(rec.parts.hand_r).tags), "%s skirmisher has no bow" % rec.name)


func _test_prompts(gen, rules: Dictionary) -> void:
	var d: Dictionary = rules.default
	check(gen.generate("swamp frogs", d).creature == "frog", "frogs are frogs")
	check(gen.generate("sewer rats", d).creature == "rat", "rats are rats")
	var centaurs: Dictionary = gen.generate("centaur romans", d)
	check(centaurs.creature == "centaur" and centaurs.family == "imperial", "centaur romans")
	for u in centaurs.units:
		check(u.recipe.has("mount") and u.recipe.mount.fused, "every centaur is fused to a pony")
	var greeks: Dictionary = gen.generate("flying greeks with wings", d)
	check(greeks.family == "hellenic", "greeks are hellenic")
	var winged := 0
	for u in greeks.units:
		var mount_wings: String = u.recipe.mount.parts.get("back", "") if u.recipe.has("mount") else ""
		if u.recipe.parts.get("back", "").begins_with("wings.") or mount_wings.begins_with("wings."):
			winged += 1
		if u.recipe.has("mount") and not u.recipe.mount.fused:
			check(not u.recipe.parts.get("back", "").begins_with("wings."), "riders don't wear wings; their mount does")
	check(winged >= 4, "winged greeks mostly fly (%d/5)" % winged)
	var ww2: Dictionary = gen.generate("ww2 americans riding mongolian ponies", d)
	check(ww2.notes.any(func(n): return "saucepan" in n.to_lower()), "ww2 blocked with a saucepan note")
	check(_unit(ww2, "large").recipe.has("mount"), "mongolian large unit is mounted")
	check(_unit(ww2, "archer").recipe.has("mount"), "mongolian archers are horse archers")
	for reroll in 20:
		for prompt in ["romans", "centaur romans", "flying greeks"]:
			for rid in ["default", "bronze"]:
				var r: Dictionary = gen.generate(prompt, rules[rid], reroll)
				for u in r.units:
					check(u.recipe.parts.hand_r != "weapon.cheese_hammer", "no cheese hammers for %s unless asked" % prompt)
					check(u.recipe.scale < Generator.GIANT_SCALE, "no giant %s unless asked" % prompt)
	var gibberish: Dictionary = gen.generate("blorp zang wibble", d)
	check(gibberish.notes.size() >= 2, "gibberish gets volunteer + ignored notes")
	var guns: Dictionary = gen.generate("rats with guns", rules.anything)
	check(_unit(guns, "skirmisher").recipe.parts.hand_r == "weapon.musket", "anything-goes rats get muskets")
	var no_guns: Dictionary = gen.generate("rats with guns", d)
	check(_unit(no_guns, "skirmisher").recipe.parts.hand_r != "weapon.musket", "default rules block muskets")


func _test_composer(lib, gen, rules: Dictionary) -> void:
	for prompt in PROMPTS:
		var race: Dictionary = gen.generate(prompt, rules)
		for u in race.units:
			var view = UnitView.new()
			view.build(u.recipe, lib, Color.BLUE, u.eval.speed)
			check(view.get_child_count() >= 2, "composed %s" % u.recipe.name)
			view.free()


func _unit(race: Dictionary, role: String) -> Dictionary:
	for u in race.units:
		if u.recipe.role == role:
			return u
	assert(false, "no %s unit" % role)
	return {}
