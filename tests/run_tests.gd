extends SceneTree
## Headless checks for the race generator and composer.
## Run: godot --headless --path . --script res://tests/run_tests.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const TreeModel := preload("res://src/view/tech_tree_model.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")

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
	_test_healers(lib, gen, rules)
	_test_composer(lib, gen, rules.default)
	_test_audio(lib)
	_test_tech_tree(lib, gen, rules)
	_test_scripts_parse()

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Every game and view script loads (a parse error in a scene script otherwise only shows when
## the game is run).
func _test_scripts_parse() -> void:
	for dir in ["res://scenes/", "res://scenes/art_pixel/", "res://src/view/", "res://src/view/art/bake/", "res://src/view/art/", "res://src/ai/", "res://src/sim/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var script: Script = load(dir + f)
				check(script != null and script.can_instantiate(), "script parses: " + dir + f)


## Every sound data/audio.json names has its takes on disk and loads; every creature's voice
## has its files; every music stem is there (all rendered by tools/audio/render.py).
func _test_audio(lib) -> void:
	var cfg = DataLib.load_json("res://data/audio.json")
	for n in cfg.sounds:
		var s: Dictionary = cfg.sounds[n]
		check(s.bus in cfg.buses, "sound %s is on a known bus" % n)
		for k in int(s.takes):
			var path := "res://assets/audio/sfx/%s_%d.wav" % [n, k + 1]
			var w := AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null
			check(w != null and w.get_length() > 0.01, "sound take loads: " + path)
	for id in lib.creatures:
		var voice: String = lib.creatures[id].voice
		for kind in cfg.voices.kinds:
			for k in int(cfg.voices.kinds[kind]):
				var path := "res://assets/audio/voice/%s_%s_%d.wav" % [voice, kind, k + 1]
				check(FileAccess.file_exists(path), "creature %s has its voice: %s" % [id, path])
	for stem in cfg.music.stems:
		var path := "res://assets/audio/music/theme_%s.ogg" % stem
		var o := AudioStreamOggVorbis.load_from_file(path) if FileAccess.file_exists(path) else null
		check(o != null and o.get_length() > 60.0, "music stem loads: " + path)
	for mix in cfg.music.mixes:
		for stem in cfg.music.mixes[mix]:
			check(stem in cfg.music.stems, "mix %s uses a known stem: %s" % [mix, stem])


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


## The tech tree page (milestone 12): every node comes from data (buildings.json, tech.json, the
## rules' roster), every item of the data is on the page, every planned item is named in the
## milestone file, and the game's loaders leave planned items out.
func _test_tech_tree(lib, gen, rules: Dictionary) -> void:
	var bdata: Dictionary = DataLib.load_json("res://data/buildings.json")
	var tdata: Dictionary = DataLib.load_json("res://data/tech.json")
	var plan := FileAccess.get_file_as_string("res://docs/milestones/m12-tech-tree.md")
	var research := {}
	for r in tdata.research:
		research[r.id] = r
	for rid in rules:
		var r: Dictionary = rules[rid]
		for race in [{}, gen.generate("angry swamp frogs with reed spears", r), gen.generate("sewer rats with cheese hammers", r)]:
			var m: Dictionary = TreeModel.build(race, r, lib)
			var seen := {}
			for n in m.nodes:
				check(not seen.has(n.key), "tree: one node per item (%s)" % n.key)
				seen[n.key] = true
				check(n.status in ["built", "planned"], "tree: %s has a status" % n.key)
				check(n.age >= int(bdata.buildings[n.building].age), "tree: %s opens no earlier than its building" % n.key)
				check(n.age >= 1 and n.age <= m.ages.size(), "tree: %s sits in an age row" % n.key)
				match n.kind:
					"building":
						check(bdata.buildings.has(n.id) and bdata.buildings[n.id].name == n.name, "tree: building %s from buildings.json" % n.id)
						check(n.status == bdata.buildings[n.id].get("status", "built"), "tree: building %s status from data" % n.id)
					"research":
						check(research.has(n.id) and research[n.id].building == n.building and int(research[n.id].age) == n.age,
							"tree: research %s from tech.json" % n.id)
						check(n.status == research[n.id].get("status", "built"), "tree: research %s status from data" % n.id)
					"unit":
						var sd: Array = r.roster.filter(func(s): return s.slot == n.slot)
						check(sd.size() == 1 and sd[0].building == n.building and n.age >= int(sd[0].tier), "tree: line step %s from the roster" % n.key)
						if not race.is_empty() and n.status == "built":
							var u: Array = race.units.filter(func(x): return x.recipe.slot == n.slot)
							check(u.size() == 1 and u[0].line.any(func(l): return int(l.age) == n.age and l.recipe.name == n.name),
								"tree: %s shows the race's own unit for that age (%s)" % [n.key, n.name])
					_:
						check(false, "tree: unknown node kind %s" % n.kind)
			for id in bdata.buildings:
				check(seen.has("b:" + id), "tree: building %s is on the page" % id)
			for id in research:
				check(seen.has("r:" + id), "tree: research %s is on the page" % id)
			for sd in r.roster:
				check(bdata.buildings.has(sd.get("building", "")), "roster %s names a building (%s)" % [sd.slot, rid])
				var first := maxi(int(sd.tier), int(bdata.buildings[sd.building].age))   # trained once its building stands
				check(seen.has("u:%s@%d" % [sd.slot, first]), "tree: line %s is on the page (%s)" % [sd.slot, rid])
				if sd.get("status", "") != "planned":
					check(sd.slot in bdata.buildings[sd.building].trains, "roster %s: its building trains it (%s)" % [sd.slot, rid])
			if not race.is_empty():
				check(not m.race.moves.is_empty(), "tree: the race panel says how %s moves" % race.name)
	# Planned items are in the plan (by name), and nothing in the game loads them.
	var planned := []
	for id in bdata.buildings:
		if bdata.buildings[id].get("status", "") == "planned":
			planned.append(bdata.buildings[id].name)
	for r in tdata.research:
		if r.get("status", "") == "planned" and not r.building == "castle":
			planned.append(r.name)
	for a in tdata.ages:
		if a.get("status", "") == "planned":
			planned.append(a.name)
	for sd in rules.default.roster:
		if sd.get("status", "") == "planned":
			planned.append("`%s`" % sd.slot)
	for name in planned:
		check(plan.contains(name), "planned item %s is in docs/milestones/m12-tech-tree.md" % name)
	var resources := ["food", "wood", "stone", "gold"]
	var btypes: Array = Economy.load_btypes(resources)
	check(btypes.all(func(b): return bdata.buildings[b.id].get("status", "") != "planned"), "the sim's building types skip planned ones")
	check(btypes.size() == bdata.buildings.keys().filter(func(id): return bdata.buildings[id].get("status", "") != "planned").size(),
		"the sim loads every built building")
	var tech: Dictionary = Tech.load_tech(resources, btypes)
	check(tech.ages.all(func(a): return int(a.age) <= 3) and tech.ages.size() == 3, "the sim's ages skip the planned fourth")
	for r in tech.research:
		check(r.has("line") or research[r.id].get("status", "") != "planned", "the sim's research skips planned %s" % r.id)
	for menu in bdata.menu.values():
		for id in menu:
			check(bdata.buildings[id].get("status", "") != "planned", "build menus hold no planned building (%s)" % id)
	for rid in rules:
		var race: Dictionary = gen.generate("centaur romans", rules[rid])
		check(race.units.all(func(u): return rules[rid].roster.any(func(s): return s.slot == u.recipe.slot and s.get("status", "") != "planned")),
			"the generator skips planned roster slots (%s)" % rid)


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
				check(race.units.size() == r.roster.filter(func(sd): return sd.get("status", "") != "planned").size(), "roster size %s/%s" % [rid, prompt])
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
	# Unit lines: a unit starts in its age's kit and upgrades within its kind and culture.
	for prompt in ["centaur romans", "angry swamp frogs", "royal knights", "sewer rats"]:
		for u in gen.generate(prompt, d).units:
			var ages: Array = u.line.map(func(l): return l.age)
			check(ages[0] == int(u.recipe.tier) and ages[-1] == int(d.ages), "%s: %s line runs from age %d to %d (%s)" % [prompt, u.recipe.slot, u.recipe.tier, d.ages, ages])
			for l in u.line:
				for id in l.recipe.parts.values():
					check(int(gen.lib.part(id).get("tier", 1)) <= l.age, "%s: %s at age %d holds no later kit (%s)" % [prompt, u.recipe.slot, l.age, id])
			check(u.line[0].recipe == u.recipe, "%s: the line starts with the unit's recipe" % prompt)
	# An upgrade never reads "X -> X": new kit gets a new name, no new kit keeps it (and isn't sold).
	for prompt in ["centaur romans", "centaur greeks", "angry swamp frogs", "royal knights", "sewer rats with cheese hammers", "aztec warriors", "han archers", "nile spiders"]:
		for reroll in 4:
			for u in gen.generate(prompt, d, reroll).units:
				if u.recipe.role == "worker":
					continue
				var names: Array = u.line.map(func(l): return l.recipe.name)
				for s in range(1, u.line.size()):
					var same_kit: bool = u.line[s].recipe.parts == u.line[s - 1].recipe.parts
					check(same_kit == (u.line[s].recipe.name in names.slice(0, s)), "%s (reroll %d): %s line step %d has its own name only when its kit is new (%s)" % [prompt, reroll, u.recipe.slot, s, names])
	# Another culture's signature kit never turns up uninvited (no acorns or knight's
	# helmets on Romans, no bat wings on Greeks), and a culture keeps its own.
	var foreign := {"centaur romans": ["knight", "woodland", "bat", "greek", "viking", "cheese"],
		"winged romans": ["knight", "woodland", "bat", "greek"], "flying greeks with wings": ["knight", "woodland", "bat", "roman"],
		"greek hoplites": ["knight", "woodland", "roman"], "royal knights": ["woodland", "roman", "greek", "bat"]}
	for prompt in foreign:
		for reroll in 6:
			for u in gen.generate(prompt, d, reroll).units:
				var ids: Array = []
				for l in u.line:
					ids.append_array(l.recipe.parts.values())
					if l.recipe.has("mount"):
						ids.append_array(l.recipe.mount.parts.values())
				for id in ids:
					var bad: Array = gen.lib.part(id).tags.filter(func(t): return t in foreign[prompt])
					check(bad.is_empty(), "%s (reroll %d): %s has foreign kit %s" % [prompt, reroll, id, bad])
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
	var open := d.duplicate(true)
	open.no_restrictions = true
	var foreign_ok := false
	for reroll in 12:
		for u in gen.generate("centaur romans", open, reroll).units:
			for l in u.line:
				for id in l.recipe.parts.values():
					foreign_ok = foreign_ok or gen.lib.part(id).tags.any(func(t): return t in ["woodland", "knight", "junk", "bat"])
	check(foreign_ok, "no_restrictions lets other cultures' kit through")
	var gibberish: Dictionary = gen.generate("blorp zang wibble", d)
	check(gibberish.notes.size() >= 2, "gibberish gets volunteer + ignored notes")
	var guns: Dictionary = gen.generate("rats with guns", rules.anything)
	check(_unit(guns, "skirmisher").line[-1].recipe.parts.hand_r == "weapon.musket", "anything-goes rats with guns get muskets once their age comes (%s)" % _unit(guns, "skirmisher").line[-1].recipe.parts.hand_r)
	var no_guns: Dictionary = gen.generate("rats with guns", d)
	check(_unit(no_guns, "skirmisher").recipe.parts.hand_r != "weapon.musket", "default rules block muskets")


## Every race gets a healer at the Town Center from age 2 (Dominic, 2026-10-12): it heals and
## never fights, goes light (no shield, no armour, a bag in the off hand), wears its culture's
## kit (cheese for rats, a lily for frogs), and adding it changed no other line's recipes.
func _test_healers(lib, gen, rules: Dictionary) -> void:
	for rid in rules:
		var r: Dictionary = rules[rid]
		for prompt in PROMPTS:
			for reroll in 3:
				var race: Dictionary = gen.generate(prompt, r, reroll)
				var h: Dictionary = _unit(race, "healer")
				check(int(h.recipe.tier) == 2, "%s: the healer opens in age 2" % prompt)
				for l in h.line:
					var e: Dictionary = l.eval
					check(int(e.heal) > 0 and int(e.attack) == 0, "%s/%s: %s heals and has no attack" % [rid, prompt, l.recipe.name])
					check(int(e.cost.get("gold", 0)) > 0, "%s: a healer costs gold" % l.recipe.name)
					for slot in l.recipe.parts:
						var p: Dictionary = lib.part(l.recipe.parts[slot])
						check(slot != "torso" and not ("shield" in p.tags) and not ("heavy" in p.tags), "%s: %s goes light (%s)" % [prompt, l.recipe.name, p.id])
						if slot == "hand_l":
							check("heal" in p.tags, "%s: the healer's off hand holds its bag (%s)" % [prompt, p.id])
				for u in race.units:
					if u.recipe.role != "healer":
						check(int(u.eval.get("heal", 0)) == 0 and not lib.part(u.recipe.parts.hand_r).tags.has("heal"), "%s: only healers heal (%s)" % [prompt, u.recipe.name])
	check(_unit(gen.generate("sewer rats", rules.default), "healer").recipe.parts.hand_r == "tool.staff.cheese", "rat healers carry a cheese staff")
	check(_unit(gen.generate("swamp frogs", rules.default), "healer").recipe.parts.hand_r == "tool.staff.lily", "frog healers carry a lily staff")
	check(_unit(gen.generate("romans", rules.default), "healer").recipe.parts.hand_r == "tool.staff.herbs", "roman healers carry the herb staff")
	# own_seed: the healer draws from its own stream, so every other line is as it was without it.
	var without: Dictionary = rules.default.duplicate(true)
	without.roster = without.roster.filter(func(sd): return sd.slot != "healer")
	for prompt in PROMPTS:
		var a: Array = gen.generate(prompt, rules.default).units.filter(func(u): return u.recipe.role != "healer")
		var b: Array = gen.generate(prompt, without).units
		check(JSON.stringify(a.map(func(u): return u.line.map(func(l): return l.recipe))) == JSON.stringify(b.map(func(u): return u.line.map(func(l): return l.recipe))),
			"'%s': adding the healer leaves the other lines' recipes as they were" % prompt)


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
