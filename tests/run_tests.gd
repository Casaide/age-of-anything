extends SceneTree
## Headless checks for the race generator and composer.
## Run: godot --headless --path . --script res://tests/run_tests.gd [-- placement]
## The 3D placement check (~40 s) only with "placement"; tests/batch.sh runs it (placement_check.gd 3d).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const TreeModel := preload("res://src/view/tech_tree_model.gd")
const Identity := preload("res://src/identity.gd")
const Heroes := preload("res://src/heroes.gd")
const Pricing := preload("res://src/pricing.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const GeometryRun := preload("res://tests/geometry_check.gd")
const Fixtures3D := preload("res://tests/placement/fixtures_3d.gd")
const CombatFx := preload("res://src/view/combat_fx.gd")

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
	_test_siege(lib, gen, rules.default)
	_test_swordsmen(lib, gen, rules)
	_test_new_lines(lib, gen, rules)
	_test_composer(lib, gen, rules.default)
	_test_audio(lib)
	_test_paths()
	_test_tech_tree(lib, gen, rules)
	_test_identity(lib, gen, rules.default)
	_test_heroes(lib, gen, rules)
	_test_scripts_parse()
	_test_mods(lib, rules)
	if "placement" in OS.get_cmdline_user_args():   # (the batch runs it as placement_check.gd 3d, side by side)
		_test_placement(lib)

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The 3D placement check (tests/placement/geometry_check.gd, docs/rendering.md "Placement rules"):
## every unit, mount, rider, animal and crew in every pose, on its meshes, and the fixtures of the
## bugs it must catch. The 2D half needs a window: tests/placement_check.gd runs both.
func _test_placement(lib) -> void:
	var g = GeometryCheck.new(lib)
	g.metrics = true
	GeometryRun.run(g, Cases.all(lib))
	for key in g.order:
		var fails: Array = g.results[key]
		check(fails.is_empty(), "placement %s: %s" % [key.replace("|", ": "), "" if fails.is_empty() else fails[0]])
	var fx: Array = Fixtures3D.run(lib)
	for line in fx[1]:
		check(line.begins_with("PASS"), "placement " + line.replace("\n", " "))


## Milestone 21's mods (src/mods.gd): the example mod merges in load order, its parts only come when
## asked for and allowed, the race key holds the mod set (and a race without mods keeps its key),
## its .glb part builds, and every broken fixture in tests/mods is refused with its reason.
func _test_mods(base_lib, rules: Dictionary) -> void:
	var Mods = DataLib.Mods
	var UnitModels = load("res://scenes/art_pixel/unit_models.gd")
	var plain_key: String = Generator.new(base_lib).generate("future soldiers", rules.anything).key
	check(not base_lib.parts.has("weapon.pulse_rifle") or not Mods.active.is_empty(), "mods: none used unless asked for")
	check(Mods.use(["scifi_test"]) == ["scifi_test"], "mods: the example mod loads (%s)" % Mods.refused)
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var anything: Dictionary = DataLib.load_rules("anything")
	check("scifi" in anything.era and not "scifi" in DataLib.load_rules("bronze").era, "mods: the rules overlay opens the scifi era where it says")
	var race: Dictionary = gen.generate("future soldiers", anything)
	var sk: Dictionary = race.units.filter(func(u): return u.recipe.slot == "skirmisher")[0]
	check(sk.recipe.parts.hand_r == "weapon.pulse_rifle", "mods: future soldiers carry the pulse rifle (%s)" % sk.recipe.parts.hand_r)
	check(sk.line[-1].recipe.parts.get("head_gear", "") in ["", "helm.visor_sealed"], "mods: an era pack's helmet only gives way to its own (upgrade_within)")
	check(race.get("mods", []) == Mods.signature() and race.key != plain_key, "mods: the race key holds the mod set")
	check(gen.generate("future soldiers", anything).key == race.key, "mods: the same prompt gives the same key with the mod")
	check(Mods.missing(race).is_empty() and Mods.missing({"mods": ["other@1#x"]}) == ["other@1#x"], "mods: a race made with mods we don't have is spotted")
	var romans: Dictionary = gen.generate("romans", rules.default)
	check(not romans.units.any(func(u): return u.line.any(func(l): return l.recipe.parts.values().any(func(id): return lib.parts[id].has("only_if") and "scifi" in lib.parts[id].only_if))), "mods: nobody gets future kit unasked")
	var bronze: Dictionary = gen.generate("future soldiers", DataLib.load_rules("bronze"))
	check(bronze.notes.any(func(n): return "future" in n.to_lower()), "mods: a host without the era says so (a note)")
	var buckler: Dictionary = UnitModels.new().build("shield.arc_buckler", UnitView.colours_for(lib, "human_tan", "imperial", Color.RED))
	check(UnitModels.new().has("shield.arc_buckler") and buckler.node.find_children("*", "MeshInstance3D", true, false).size() > 0, "mods: a .glb part builds")
	buckler.node.free()
	check(CombatFx.shot_kind(sk.eval.tags) == "pulse", "mods: the pulse rifle fires the mod's shot")
	Mods.test_roots = ["res://tests/mods"]
	var bad := ["no_model", "bad_era", "needs_other", "future_game", "bad_file", "clash"]
	check(Mods.use(bad + ["scifi_test"]) == ["scifi_test"], "mods: broken mods refused, a good one beside them still loads")
	for id in bad:
		check(Mods.refused.has(id), "mods: %s refused (%s)" % [id, Mods.refused.get(id, "not refused")])
	Mods.test_roots = []
	Mods.use([])
	check(Generator.new(DataLib.new()).generate("future soldiers", rules.anything).key == plain_key, "mods: off again, the race is as before")


## Milestone 14's race identity (src/identity.gd): every playable creature with every culture mixes
## six bonuses (group 1, creature 2, culture 3 with a team one), no kind twice; every effect has the research shape; own research
## and lacks name real things; a race's identity comes from its creature and culture alone (the
## recipes and race key don't see it), and its stat bonuses are paid for.
## Heroes (milestone 14 step 9, src/heroes.gd, data/heroes.json; D-136): every playable creature with
## every culture has at least rules.min_heroes, its own creature's and culture's all among them, none
## twice; every signature is someone's; each name carries its signature's epithet or nickname; the
## heroes are derived from the key (not in it), the same every time, dressed over the swordsman with
## the replaced kit kept; priced dearer and tougher than the swordsman; their parts are only theirs.
func _test_heroes(lib, gen, rules: Dictionary) -> void:
	var fams: Array = lib.families.keys()
	fams.sort()
	var seen := {}
	var least := 99
	for cid in lib.creature_ids("playable"):
		for fid in fams:
			var sigs := Heroes.roster_for(lib.heroes, cid, fid)
			least = mini(least, sigs.size())
			var own := Heroes.signatures_for(lib.heroes, cid, fid)
			check(sigs.size() >= int(lib.heroes.rules.min_heroes) and sigs.slice(0, own.size()) == own, "heroes: %s/%s have all their own and at least %d (%s)" % [cid, fid, lib.heroes.rules.min_heroes, sigs])
			var once := {}
			for sid in sigs:
				check(not once.has(sid), "heroes: %s/%s: %s once" % [cid, fid, sid])
				once[sid] = true
				seen[sid] = true
				var h := Heroes.pick(lib.heroes, "key%d" % cid.length(), cid, fid, sid)
				var s: Dictionary = lib.heroes.hero_signatures[sid]
				var words: Array = s.epithets + s.get("nicknames", [])
				check(words.any(func(e): return e in h.name) or "of His Name" in h.name, "heroes: %s's name carries its look (%s)" % [sid, h.name])
	for fid in lib.heroes.kin:
		check(lib.families.has(fid) and lib.heroes.kin[fid].all(func(f): return lib.families.has(f) and f != fid), "heroes: %s's kin are other cultures" % fid)
	for sid in lib.heroes.hero_signatures:
		var s: Dictionary = lib.heroes.hero_signatures[sid]
		var playable: bool = s.who.get("creature", []).any(func(c): return lib.creatures.has(c) and lib.creatures[c].get("playable", false)) or not s.who.get("family", []).is_empty()
		check(seen.has(sid) or not playable, "heroes: %s is someone's hero" % sid)
		for slot in s.parts:
			check(lib.parts.has(s.parts[slot]) and lib.part(s.parts[slot]).slot == slot, "heroes: %s's %s is a %s part" % [sid, s.parts[slot], slot])
		for cid in s.get("fit", {}):
			check(lib.creatures.has(cid), "heroes: %s's fit names a creature (%s)" % [sid, cid])
			for slot in s.fit[cid]:
				var fid: String = s.fit[cid][slot]
				check(s.parts.has(slot) and (fid == "" or (lib.parts.has(fid) and lib.part(fid).slot == slot)), "heroes: %s's fit for %s: a %s part in place of its own (%s)" % [sid, cid, slot, fid])
		check(s.aura.effects.size() > 0 and s.aura.text != "", "heroes: %s has an aura" % sid)
	for prompt in ["sewer rats with cheese hammers", "romans", "spooky spiders", "centaur romans", "egyptians", "swamp frogs", "forest beetles"]:
		for reroll in 2:
			var race: Dictionary = gen.generate(prompt, rules.default, reroll)
			var heroes: Array = race.units.filter(func(u): return u.recipe.slot == "hero")
			var want := Heroes.roster_for(lib.heroes, race.creature, race.family)
			check(heroes.map(func(u): return u.recipe.hero) == want and race.units.slice(-heroes.size()) == heroes and race.heroes.size() == heroes.size(),
				"heroes: '%s' has all its heroes, the last of its units (%s)" % [prompt, want])
			check(Generator.race_key(race) == race.key, "heroes: '%s': the key leaves the heroes out" % prompt)
			check(JSON.stringify(gen.generate(prompt, rules.default, reroll).heroes) == JSON.stringify(race.heroes), "heroes: '%s': the same heroes every time" % prompt)
			var names := {}
			for h in race.heroes:
				names[h.name] = true
			check(names.size() == race.heroes.size(), "heroes: '%s': each its own name (%s)" % [prompt, race.heroes.map(func(h): return h.name)])
			var sword: Dictionary = race.units.filter(func(u): return u.recipe.slot == "infantry")[0]
			for hero in heroes:
				var s: Dictionary = lib.heroes.hero_signatures[hero.recipe.hero]
				var worn := Heroes.parts_on(s, race.creature)
				for l in hero.line:
					var r: Dictionary = l.recipe
					for slot in worn:
						check(r.parts[slot] == worn[slot], "heroes: '%s' wears its %s" % [prompt, worn[slot]])
					for slot in r.get("kit", {}):
						check(lib.part(r.kit[slot]).slot == slot and not lib.part(r.kit[slot]).has("only_if") or not "hero_only" in lib.part(r.kit[slot]).get("only_if", []), "heroes: '%s' keeps its %s kit" % [prompt, slot])
					var sw: Dictionary = sword.line.filter(func(x): return int(x.age) <= int(l.age))[-1]
					var total := func(c: Dictionary) -> int: return c.values().reduce(func(a, b): return a + b, 0)
					check(int(l.eval.hp) >= int(sw.eval.hp) + 100 and total.call(l.eval.cost) * 2 > total.call(sw.eval.cost) * 3, "heroes: '%s' age %d: tougher and dearer than its swordsman (%d hp, %d)" % [prompt, l.age, l.eval.hp, total.call(l.eval.cost)])
					check(not "giant" in l.eval.tags, "heroes: '%s': its size is its look, not a giant's" % prompt)
	for prompt in PROMPTS:
		for u in gen.generate(prompt, rules.default).units:
			if u.recipe.slot != "hero":
				for l in u.line:
					check(not l.recipe.parts.values().any(func(id): return "hero_only" in lib.part(id).get("only_if", [])), "heroes: '%s' %s wears no hero's kit" % [prompt, u.recipe.slot])


func _test_identity(lib, gen, rules: Dictionary) -> void:
	var tdata: Dictionary = DataLib.load_json("res://data/tech.json")
	var bdata: Dictionary = DataLib.load_json("res://data/buildings.json").buildings
	var research := {}
	for r in tdata.research:
		research[r.id] = r
	var slots: Array = rules.roster.map(func(sd): return sd.slot)
	var fams: Array = lib.families.keys()
	fams.sort()
	for cid in lib.creature_ids("playable"):
		for fid in fams:
			var ident := Identity.of(cid, fid)
			check(ident.bonuses.size() == 6, "identity %s/%s: six bonuses (%d)" % [cid, fid, ident.bonuses.size()])
			var kinds := {}
			for b in ident.bonuses:
				kinds[Identity.kind_of(b)] = true
				for fx in b.effects:
					Tech._check(fx, "%s/%s bonus" % [cid, fid])   # (asserts on a bad shape)
				var priced: bool = b.effects.any(func(fx): return Identity.priced(fx) and not fx.stat in ["cost", "train_time"])
				check(priced == (b.price_points > 0), "identity %s/%s: \"%s\" is paid for if it adds to unit stats" % [cid, fid, b.text])
			check(kinds.size() == ident.bonuses.size(), "identity %s/%s: no kind of bonus twice" % [cid, fid])
	for src in [lib.creatures, lib.families]:
		for id in src:
			var layer := "creature" if src == lib.creatures else "culture"
			for r in src[id].get("research", []):
				check(research.has(r) and research[r].get("own", "") == layer, "identity: %s's own research %s is a %s research in tech.json" % [id, r, layer])
			for l in src[id].get("lacks", []):
				var known: bool = research.has(l) or bdata.has(l) or l in slots or l == Identity.TRADE
				if l.begins_with("line."):
					known = l.split(".")[1] in slots
				check(known, "identity: %s lacks something real (%s)" % [id, l])
	# Same creature and culture, any prompt: the same identity; the race key never sees it.
	var a: Dictionary = gen.generate("hellenic beetles", rules)
	var b: Dictionary = gen.generate("hellenic beetles with big shields", rules, 3)
	check(Identity.of(a.creature, a.family) == Identity.of(b.creature, b.family), "identity: from creature and culture alone")
	var copy: Dictionary = a.duplicate(true)
	for u in copy.units:
		for l in u.line:
			l.eval.armour.pierce = 99
	check(Generator.race_key(copy) == a.key, "identity: the race key hashes recipes, not the stats bonuses change")
	# Beetles' shells: +1 pierce armour on every unit, paid for (a point on the price).
	var bt: Dictionary = gen.generate("hellenic beetles", rules)
	var spear: Dictionary = bt.units.filter(func(u): return u.recipe.slot == "spear")[0]
	var plain: Dictionary = Pricing.evaluate(spear.recipe.merged({"family": "forest"}, true), lib, rules)   # (forest: no spear bonus)
	check(int(spear.eval.armour.pierce) == int(plain.armour.pierce) and int(spear.eval.armour.melee) == int(plain.armour.melee) + 1,
		"identity: hellenic spears +1 melee armour on the eval (%d vs %d)" % [int(spear.eval.armour.melee), int(plain.armour.melee)])
	check(int(spear.eval.points) == int(plain.points) + 1, "identity: ...and pay a point for it")


## Every game and view script loads (a parse error in a scene script otherwise only shows when
## the game is run).
func _test_scripts_parse() -> void:
	for dir in ["res://scenes/", "res://scenes/art_pixel/", "res://src/view/", "res://src/view/art/bake/", "res://src/view/art/", "res://src/ai/", "res://src/sim/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var script: Script = load(dir + f)
				check(script != null and script.can_instantiate(), "script parses: " + dir + f)


## Culture paths grow, they don't move: planned again with a new building (and the targets in
## another order), every stretch laid before is still there, point for point.
func _test_paths() -> void:
	var Paths = load("res://scenes/art_pixel/paths.gd")
	var blocked := func(t: Vector2) -> bool: return t.x < 0.2 or t.y < 0.2 or t.x > 23.8 or t.y > 23.8 or (t.x > 8.0 and t.x < 9.0 and t.y < 14.0)
	var memo := {}
	var hub := Vector2(5, 5)
	var first: Array = Paths.plan(24, 24, blocked, [{"style": "trail", "width": 0.4, "hub": hub, "targets": [Vector2(12, 6), Vector2(4, 12)]}], memo)
	var before: Array = first.map(func(p): return p.points)
	var later: Array = Paths.plan(24, 24, blocked, [{"style": "trail", "width": 0.4, "hub": hub, "targets": [Vector2(1, 9), Vector2(4, 12), Vector2(12, 6)]}], memo)
	check(later.size() > before.size(), "paths: a new building adds a branch")
	for k in before.size():
		check(later[k].points == before[k], "paths: stretch %d stays put when a building is added" % k)


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
							var u: Array = race.units.filter(func(x): return x.recipe.slot == n.slot and x.recipe.get("hero", "") == n.get("hero", ""))   # (each hero its own node)
							check(u.size() == 1 and u[0].line.any(func(l): return int(l.age) == n.age and l.recipe.name == n.name),
								"tree: %s shows the race's own unit for that age (%s)" % [n.key, n.name])
					_:
						check(false, "tree: unknown node kind %s" % n.kind)
			for id in bdata.buildings:
				check(seen.has("b:" + id), "tree: building %s is on the page" % id)
			for id in research:
				var others: bool = research[id].has("own") and not race.is_empty() and not bool(r.get("full_tech_tree", false)) \
					and not id in Identity.of(race.creature, race.family).research   # another race's own research: not on this race's page
				check(seen.has("r:" + id) != others, "tree: research %s is on the page%s" % [id, " (not: another race's own)" if others else ""])
			for sd in r.roster:
				check(bdata.buildings.has(sd.get("building", "")), "roster %s names a building (%s)" % [sd.slot, rid])
				var first := maxi(int(sd.tier), int(bdata.buildings[sd.building].age))   # trained once its building stands
				var heroes: Array = race.get("heroes", []) if sd.role == "hero" else []   # (each hero its own node, D-136)
				check(seen.has("u:%s@%d" % [sd.slot, first]) if heroes.is_empty() else heroes.all(func(h): return seen.has("u:%s.%s@%d" % [sd.slot, h.signature, first])),
					"tree: line %s is on the page (%s)" % [sd.slot, rid])
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
		for s in c.skins:   # a skin never reads as a team colour (a red frog on the blue side looked like the enemy: Dominic)
			for t in lib.palettes.teams:
				var d := _lab_distance(Color(lib.palettes.skins[s][0]), Color(t))
				check(d >= SKIN_TEAM_GAP, "creature %s skin %s is no team colour (%s: distance %d, needs %d)" % [id, s, t, d, SKIN_TEAM_GAP])
	for w in lib.lexicon:
		var e: Dictionary = lib.lexicon[w]
		if e.has("creature"):
			check(lib.creatures.has(e.creature), "lexicon %s creature exists" % w)
		if e.has("family"):
			check(lib.families.has(e.family), "lexicon %s family exists" % w)
		if e.has("mount_wings"):
			check(lib.parts.has(e.mount_wings), "lexicon %s wings part exists" % w)
	# The UI's looks (src/view/ui/theme.gd): every culture wears one; its materials, crest and cut exist.
	var mats := ["wood", "bronze", "gold", "iron", "marble", "stone", "sandstone", "parchment", "felt", "leather", "reed", "lacquer", "bone"]
	var cuts := ["square", "fringe", "swallowtail", "pointed", "notched", "tongues", "ragged", "scalloped"]
	var ui: Dictionary = DataLib.load_json("res://data/ui.json")
	var looks := []
	for d in ui.directions:
		looks.append(["direction " + d, ui.directions[d]])
	for f in lib.families:
		check(lib.families[f].has("ui"), "family %s has a ui block" % f)
		looks.append(["family " + f, lib.families[f].get("ui", {})])
	for l in looks:
		for k in ["frame", "panel", "button", "primary"]:
			if l[1].has(k):
				check(l[1][k] in mats, "%s: %s material %s is known" % [l[0], k, l[1][k]])
		if l[1].has("banner"):
			check(l[1].banner in cuts, "%s: banner cut %s is known" % [l[0], l[1].banner])
		if l[1].has("ornament"):
			check(FileAccess.file_exists("res://assets/art/ui/crest_%s.svg" % l[1].ornament), "%s: crest %s exists" % [l[0], l[1].ornament])
	check(ui.directions.has(ui.direction), "the UI direction in use exists")


const SKIN_TEAM_GAP := 30   # CIE76 distance between a skin's main colour and every team colour


## CIE76 distance between two colours (sRGB, D65).
static func _lab_distance(a: Color, b: Color) -> float:
	var la := _lab(a)
	var lb := _lab(b)
	return la.distance_to(lb)


static func _lab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	var x := (0.4124 * l.r + 0.3576 * l.g + 0.1805 * l.b) / 0.95047
	var y := 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	var z := (0.0193 * l.r + 0.1192 * l.g + 0.9505 * l.b) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z)))


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
				var lines: Array = race.units.filter(func(u): return u.recipe.slot != "hero")   # (the heroes: one line, several units; _test_heroes)
				var has_hero: int = 1 if lines.size() < race.units.size() else 0
				check(lines.size() + has_hero + race.lacks.size() == r.roster.filter(func(sd): return sd.get("status", "") != "planned").size(), "roster size %s/%s" % [rid, prompt])
				for u in race.units:
					var rec: Dictionary = u.recipe
					for slot in rec.parts:
						var p: Dictionary = lib.part(rec.parts[slot])
						check(DataLib.era_ok(p, r.era), "%s: %s allowed in %s" % [rec.name, p.id, rid])
						check(p.slot == slot, "%s in matching slot" % p.id)
					if rec.role == "trader":   # an unarmed engine line (rules `armed`: false): no weapon at all
						check(rec.parts.is_empty() and rec.has("crew"), "%s: a trade cart carries no weapon, its crew pushes" % rec.name)
						continue
					if rec.role == "hero":   # (its look over its swordsman's kit: _test_heroes)
						continue
					var need: String = Generator.ROLE_NEEDS[lib.uniques[rec.unique].role if rec.has("unique") else rec.role]
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
				if u.recipe.role in ["worker", "hero"]:
					continue   # (a hero keeps its name through the ages)
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
		var who: Dictionary = u.recipe.get("crew", u.recipe)   # an engine's centaurs are its crew
		check(who.has("mount") and who.mount.fused, "every centaur is fused to a pony")
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
					check(u.recipe.parts.get("hand_r", "") != "weapon.cheese_hammer", "no cheese hammers for %s unless asked" % prompt)
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
						check(int(u.eval.get("heal", 0)) == 0 and not (u.recipe.parts.has("hand_r") and lib.part(u.recipe.parts.hand_r).tags.has("heal")), "%s: only healers heal (%s)" % [prompt, u.recipe.name])
	check(_unit(gen.generate("sewer rats", rules.default), "healer").recipe.parts.hand_r == "tool.staff.cheese", "rat healers carry a cheese staff")
	check(_unit(gen.generate("swamp frogs", rules.default), "healer").recipe.parts.hand_r == "tool.staff.lily", "frog healers carry a lily staff")
	# Every culture its own staff (Dominic, 2026-10-12: "different staffs for each"), from data
	# (only_if + favour), and the bag to match where it has one.
	var kits := {"romans": ["tool.staff.laurel", "tool.satchel"], "greeks": ["tool.staff.olive", "tool.satchel.flask"],
		"royal humans": ["tool.staff.lantern", "tool.satchel"], "mongols": ["tool.staff.horsehair", "tool.satchel.felt"],
		"spooky spiders": ["tool.staff.candle", "tool.satchel.bottle"], "forest beetles": ["tool.staff.branch", "tool.satchel.leaf"],
		"egyptians": ["tool.staff.papyrus", "tool.satchel.linen"], "han": ["tool.staff.gourd", "tool.satchel.lacquer"],
		"aztecs": ["tool.staff.feather", "tool.satchel.woven"]}
	for prompt in kits:
		var parts: Dictionary = _unit(gen.generate(prompt, rules.default), "healer").recipe.parts
		check(parts.hand_r == kits[prompt][0] and parts.get("hand_l", "") == kits[prompt][1], "%s healers carry their culture's kit (%s, %s)" % [prompt, parts.hand_r, parts.get("hand_l", "")])
	var models = preload("res://scenes/art_pixel/unit_models.gd").new()
	for id in lib.parts:
		if "heal" in lib.parts[id].tags:
			check(models.has(id), "%s has a model" % id)
	# own_seed: the healer draws from its own stream, so every other line is as it was without it.
	var without: Dictionary = rules.default.duplicate(true)
	without.roster = without.roster.filter(func(sd): return sd.slot != "healer")
	for prompt in PROMPTS:
		var a: Array = gen.generate(prompt, rules.default).units.filter(func(u): return not u.recipe.role in ["healer", "hero"])   # (the hero comes from the race key: src/heroes.gd)
		var b: Array = gen.generate(prompt, without).units.filter(func(u): return u.recipe.role != "hero")
		check(JSON.stringify(a.map(func(u): return u.line.map(func(l): return l.recipe))) == JSON.stringify(b.map(func(u): return u.line.map(func(l): return l.recipe))),
			"'%s': adding the healer leaves the other lines' recipes as they were" % prompt)


## Siege engines (milestone 13): every race gets a ram, catapult and bolt thrower in its take (a
## creature's own `siege`, else its culture's), crewed by its worker, priced with wood and gold;
## every engine part has a model.
func _test_siege(lib, gen, rules: Dictionary) -> void:
	var models = preload("res://scenes/art_pixel/unit_models.gd").new()
	for id in lib.parts:
		if lib.parts[id].slot == "engine":
			check(models.has(id), "%s has a model" % id)
	for f in lib.families:
		for e in ["ram", "catapult", "bolt"]:
			check(lib.parts.has("siege.%s.%s" % [e, lib.families[f].siege]), "family %s's take builds a %s" % [f, e])
	var takes := {"romans": "timber", "sewer rats": "junk", "forest beetles": "forest", "spooky spiders": "spooky", "swamp frogs": "frog", "forest frogs": "frog", "swamp beetles": "timber", "mongols": "timber"}
	for prompt in takes:
		var race: Dictionary = gen.generate(prompt, rules)
		for role in ["ram", "catapult", "bolt_thrower"]:
			var u: Dictionary = _unit(race, role)
			check(u.recipe.body.ends_with("." + takes[prompt]) and u.recipe.crew.body == race.units[0].recipe.body,
				"%s: the %s is the %s take, crewed by its workers (%s)" % [prompt, role, takes[prompt], u.recipe.body])
			check(int(u.recipe.tier) == 3 and u.line.size() == 1 and int(u.eval.cost.gold) > 0 and int(u.eval.cost.wood) > 0,
				"%s: the %s opens in age 3 and costs wood and gold (%s)" % [prompt, role, u.eval.cost])
	var ram: Dictionary = _unit(gen.generate("romans", rules), "ram").eval
	check(ram.targets == "buildings" and int(ram.armour.pierce) > int(ram.armour.melee), "the ram hits buildings only, shrugs off arrows, not blows")


## The swordsman line at the Barracks (milestone 13): from age 1, a melee weapon that's no spear
## or lance in every age, a bone club becoming a sword, the culture's own blade where it has one,
## the line's bonus against spears, skirmishers and buildings; and adding it changed no other
## line's recipes (own_seed).
func _test_swordsmen(lib, gen, rules: Dictionary) -> void:
	for rid in rules:
		for prompt in PROMPTS:
			for reroll in 3:
				var s: Dictionary = _unit(gen.generate(prompt, rules[rid], reroll), "infantry")
				check(int(s.recipe.tier) == 1 and s.line.size() == 3, "%s/%s: the swordsman line runs ages 1-3" % [rid, prompt])
				for l in s.line:
					var tags: Array = lib.part(l.recipe.parts.hand_r).tags
					check("melee" in tags and not "spear" in tags and not "lance" in tags, "%s/%s: %s holds a blade or a club (%s)" % [rid, prompt, l.recipe.name, l.recipe.parts.hand_r])
					check(int(l.eval.bonus.get("spear", 0)) > 0 and int(l.eval.bonus.get("skirmish", 0)) > 0 and int(l.eval.bonus.get("building", 0)) > 0,
						"%s: %s beats spears, skirmishers and buildings" % [prompt, l.recipe.name])
	var weapons := {"sewer rats": "weapon.cheese_hammer", "romans": "weapon.gladius", "egyptians": "weapon.khopesh",
		"aztecs": "weapon.macuahuitl", "greeks": "weapon.sword.xiphos", "royal humans": "weapon.sword.iron",
		"mongols": "weapon.sword.flared_sabre", "han": "weapon.sword.dao", "swamp frogs": "weapon.mace.river_stone",
		"forest beetles": "weapon.sword.chitin", "spooky spiders": "weapon.sword.hook"}
	for prompt in weapons:
		var s: Dictionary = _unit(gen.generate(prompt, rules.default), "infantry")
		check(s.line[-1].recipe.parts.hand_r == weapons[prompt], "%s swordsmen end with %s (%s)" % [prompt, weapons[prompt], s.line[-1].recipe.parts.hand_r])
	# The age-3 kit (D-125): the helmets come with it; the plain iron sword is the fallback, for a
	# blade with no other way up (royal humans under the bronze rules), never over a culture's own.
	check(_unit(gen.generate("greeks", rules.default), "infantry").line[-1].recipe.parts.head_gear == "helm.attic", "greek swordsmen wear the Attic helmet in age 3")
	check(_unit(gen.generate("mongols", rules.default), "infantry").line[-1].recipe.parts.head_gear == "helm.steppe_spike", "steppe swordsmen wear the spiked helmet in age 3")
	check(_unit(gen.generate("royal humans", rules.bronze), "infantry").line[-1].recipe.parts.hand_r == "weapon.sword.iron_plain", "royal humans under the bronze rules fall back on the plain iron sword")
	for prompt in ["egyptians", "aztecs", "romans"]:
		check(_unit(gen.generate(prompt, rules.bronze), "infantry").line[-1].recipe.parts.hand_r != "weapon.sword.iron_plain", "%s keep their own blade in age 3" % prompt)
	check(_unit(gen.generate("greeks", rules.default), "infantry").recipe.parts.hand_r == "weapon.club.bone", "age 1 swordsmen start with a club")
	var without: Dictionary = rules.default.duplicate(true)
	without.roster = without.roster.filter(func(sd): return sd.slot != "infantry")
	for prompt in PROMPTS:
		var a: Dictionary = gen.generate(prompt, rules.default)
		var b: Dictionary = gen.generate(prompt, without)
		var lines := func(race): return JSON.stringify(race.units.filter(func(u): return not u.recipe.slot in ["infantry", "hero"]).map(func(u): return u.line.map(func(l): return l.recipe)))
		check(lines.call(a) == lines.call(b) and a.name == b.name, "'%s': adding the swordsman leaves the other lines' recipes as they were" % prompt)


## The scout (Stable), the mounted archer (Archery Range) and the unique unit (Castle), milestone 13:
## scouts light, fast and far-sighted, on foot where nothing carries them; mounted archers ride a bow,
## and a race lacks them when its archers already ride or nothing carries them; the unique unit's
## theme from the prompt, the creature or the culture (data/uniques.json); and adding the three changed
## no other line's recipes, nor the race's name (own_seed).
func _test_new_lines(lib, gen, rules: Dictionary) -> void:
	var prompts: Array = PROMPTS + ["romans", "aztecs", "spooky spiders", "mongols", "swamp frogs", "sewer rats", "egyptians", "han", "forest beetles"]
	for rid in rules:
		for prompt in prompts:
			for reroll in 2:
				var race: Dictionary = gen.generate(prompt, rules[rid], reroll)
				var spear: Dictionary = _unit(race, "spear")
				var s: Dictionary = _unit(race, "scout")
				check(int(s.recipe.tier) == 2 and s.line.size() == 2, "%s/%s: the scout line runs ages 2-3" % [rid, prompt])
				for l in s.line:
					var w: Array = lib.part(l.recipe.parts.hand_r).tags
					check("melee" in w and not w.any(func(t): return t in ["spear", "lance", "heavy"]), "%s: %s holds a light weapon (%s)" % [prompt, l.recipe.name, l.recipe.parts.hand_r])
					for slot in l.recipe.parts:
						var p: Dictionary = lib.part(l.recipe.parts[slot])
						check(slot == "hand_r" or "wings" in p.tags or (not "heavy" in p.tags and int(p.points) <= 2), "%s: %s goes light (%s)" % [prompt, l.recipe.name, p.id])
					check(int(l.eval.sight) > 0 and int(l.eval.bonus.get("skirmish", 0)) > 0, "%s: %s sees far and beats skirmishers" % [prompt, l.recipe.name])
				check(int(s.eval.speed) > int(spear.eval.speed), "%s: the scout (%d) outruns the spear (%d)" % [prompt, int(s.eval.speed), int(spear.eval.speed)])
				var ma: Array = race.units.filter(func(u): return u.recipe.slot == "mounted_archer")
				var archer: Dictionary = _unit(race, "archer")
				check(ma.is_empty() == ("mounted_archer" in race.lacks), "%s: a missing mounted archer is listed as lacking" % prompt)
				if not ma.is_empty():
					check(ma[0].recipe.has("mount") and "bow" in lib.part(ma[0].recipe.parts.hand_r).tags and "mounted" in ma[0].eval.tags \
						and not "infantry" in ma[0].eval.tags, "%s: %s rides with a bow, not infantry" % [prompt, ma[0].recipe.name])
				else:
					check(archer.recipe.has("mount") or not s.recipe.has("mount") or lib.creatures[race.creature].get("harness", false), "%s: no mounted archers only when its archers ride, nothing carries it, or it has no hands" % prompt)
				var un: Dictionary = _unit(race, "unique")
				check(int(un.recipe.tier) == 3 and un.line.size() == 1 and lib.uniques.has(un.recipe.unique), "%s: one unique unit in age 3 (%s)" % [prompt, un.recipe.name])
				var need: String = Generator.ROLE_NEEDS[lib.uniques[un.recipe.unique].role]
				check(need in lib.part(un.recipe.parts.hand_r).tags, "%s: %s holds its theme's weapon" % [prompt, un.recipe.name])
	var d: Dictionary = rules.default
	check(_unit(gen.generate("centaur romans", d), "archer").recipe.has("mount") and "mounted_archer" in gen.generate("centaur romans", d).lacks, "centaurs' archers are their mounted archers")
	check("mounted_archer" in gen.generate("aztecs", d).lacks and not _unit(gen.generate("aztecs", d), "scout").recipe.has("mount"), "aztecs: no mounted archers, scouts on foot")
	check(_unit(gen.generate("greeks", d), "mounted_archer").recipe.mount.creature == "pony", "greeks' mounted archers ride ponies")
	var themes := {"romans": "testudo", "roman frogs": "testudo", "sewer rats": "gutter_raider", "sewer rats with cheese hammers": "big_cheese",
		"greeks": "phalanx", "aztecs": "obsidian", "swamp frogs": "bullfrog", "mongols": "steppe_raider", "royal knights": "sworn_knight",
		"spooky beetle knights": "sworn_knight", "egyptians": "nile_bowguard", "han": "repeater", "tiny vikings": "horned_raider",
		"forest beetles": "stag_colossus", "spooky spiders": "web_lurker"}
	for prompt in themes:
		var got: String = _unit(gen.generate(prompt, d), "unique").recipe.unique
		check(got == themes[prompt], "%s: unique theme %s (%s)" % [prompt, themes[prompt], got])
	check(int(_unit(gen.generate("swamp frogs", d), "unique").recipe.scale) >= Generator.GIANT_SCALE, "the Great Bullfrog is a giant")
	check(_unit(gen.generate("mongols", d), "unique").recipe.has("mount"), "the Steppe Raider rides")
	var testudo: Dictionary = _unit(gen.generate("romans", d), "unique")
	check(testudo.recipe.parts.hand_l == "shield.scutum" and int(testudo.eval.armour.pierce) >= 7, "the Testudo Guard locks its scutum")
	for rid in rules:
		var without: Dictionary = rules[rid].duplicate(true)
		without.roster = without.roster.filter(func(sd): return not sd.slot in ["scout", "mounted_archer", "unique"])
		for prompt in prompts:
			for reroll in 2:
				var a: Dictionary = gen.generate(prompt, rules[rid], reroll)
				var b: Dictionary = gen.generate(prompt, without, reroll)
				var lines := func(race): return JSON.stringify(race.units.filter(func(u): return not u.recipe.slot in ["scout", "mounted_archer", "unique", "hero"]).map(func(u): return u.line.map(func(l): return l.recipe)))
				check(lines.call(a) == lines.call(b) and a.name == b.name, "%s/'%s': the new lines leave the others' recipes and the name as they were" % [rid, prompt])


func _test_composer(lib, gen, rules: Dictionary) -> void:
	for prompt in PROMPTS:
		var race: Dictionary = gen.generate(prompt, rules)
		for u in race.units:
			var view = UnitView.new()
			view.build(u.recipe, lib, Color.BLUE, u.eval.speed)
			check(view.get_child_count() >= 2, "composed %s" % u.recipe.name)
			view.free()
	_test_cat_poses(gen, rules)


## The rats' alley cat (C2, D-124): rats ride cats, a capybara only when asked for; its walk picks
## baked leg steps, and standing still it sits down through its idle poses and gets up again when
## it moves (view only).
func _test_cat_poses(gen, rules: Dictionary) -> void:
	var lib = DataLib.new()
	var u: Dictionary = _unit(gen.generate("sewer rats with crossbows", rules), "large")
	check(u.recipe.has("mount") and u.recipe.mount.creature == "cat", "rats ride cats (D-124)")
	var capy: Dictionary = _unit(gen.generate("sewer rats riding capybaras", rules), "large")
	check(capy.recipe.has("mount") and capy.recipe.mount.creature == "capybara", "a capybara when asked for")
	var asked: Dictionary = _unit(gen.generate("romans on cats", rules), "large")
	check(asked.recipe.has("mount") and asked.recipe.mount.creature == "cat", "'cats' asks for the cat mount")
	check(UnitView.pose_parts(lib, u.recipe).size() == 3 * (1 + 1 + 4) + 4 * 8, "cat: its three sit poses (body, head and four cut legs each) and 8 walk steps per cut leg to bake")
	var view = UnitView.new()
	view.build(u.recipe, lib, Color.BLUE, u.eval.speed)
	view.walking = true
	for f in 5:
		view._process(0.05)
	check(view.legs.any(func(l): return "@w" in l.node.part_id), "cat: walking shows baked walk steps")
	view.walking = false
	for f in 40:
		view._process(0.25)
	check(view.body_pose == "sit", "cat: sits after standing still (%s)" % view.body_pose)
	check(view.legs.filter(func(l): return l.node.part_id.begins_with("leg.cat")).all(func(l): return l.node.part_id == l.node.part_id.get_slice("~", 0) + "~body.cat@sit^" + l.node.part_id.get_slice("^", 1) and l.node.part_id.get_slice("~", 0).ends_with("@sit")), "cat: its legs sit too (cut by the sitting body)")
	view.walking = true
	for f in 4:
		view._process(0.1)
	check(view.body_pose == "", "cat: stands up to walk (%s)" % view.body_pose)
	view.free()


func _unit(race: Dictionary, role: String) -> Dictionary:
	for u in race.units:
		if u.recipe.role == role:
			return u
	assert(false, "no %s unit" % role)
	return {}
