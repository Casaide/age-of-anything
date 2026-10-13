extends SceneTree
## Milestone 14's race identity in the sim: each race's bonuses (mixed from its group, creature and
## culture), its own research, what it lacks, and its ability, all as data (src/identity.gd,
## src/sim/tech.gd, src/sim/abilities.gd). Headless, a few seconds.
## Run: godot --headless --path . --script res://tests/test_race_identity.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Market := preload("res://src/sim/market.gd")
const Combat := preload("res://src/sim/combat.gd")
const Identity := preload("res://src/identity.gd")
const Abilities := preload("res://src/sim/abilities.gd")

const SEED := 20261013

var gen
var rules: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	var lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	rules.animals = false
	_test_buildings()
	_test_units()
	_test_lacks()
	_test_own_research()
	_test_kills()
	_test_web()
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _world(prompts: Array, r := {}) -> World:
	var races := prompts.map(func(p): return gen.generate(p, rules))
	return World.new(SEED, SimMap.load_id("flat_test"), races, rules if r.is_empty() else r)


func _put(w: World, p: int, id: String, cx: int, cy: int) -> int:
	var k := Economy.btype_of(w, id)
	var b := Economy.place(w, p, k, cx, cy)
	w.buildings.done[b] = 1
	w.buildings.hp[b] = w.bmods[p][k].hp
	return b


func _cost(w: World, p: int, id: String, res: String) -> int:
	return Economy.bcost(w, p, Economy.btype_of(w, id))[w.resources.find(res)]


## Building bonuses: bugs' cheap houses, spiders' cheap walls, imperial buildings, Han walls,
## rodents' bigger houses, forest wood, folk research.
func _test_buildings() -> void:
	var w := _world(["forest beetles", "sewer rats"])
	check(w.races[0].creature == "beetle" and w.races[0].family == "forest", "the prompt gives forest beetles (%s/%s)" % [w.races[0].creature, w.races[0].family])
	check(_cost(w, 0, "house", "wood") == 21 and _cost(w, 1, "house", "wood") == 30, "bugs: houses cost 30%% less (%d, rats %d)" % [_cost(w, 0, "house", "wood"), _cost(w, 1, "house", "wood")])
	var wood := w.resources.find("wood")
	check(w.gather_ticks[0][wood] == int(w.econ.gather_ticks.wood) * 90 / 100, "forest: wood gathered 10%% faster (%d ticks)" % w.gather_ticks[0][wood])
	# Rodents: a house holds 6.
	var cap0: int = w.pop_cap[1]
	_put(w, 1, "house", w.map.starts[1][0] / 1000 + 4, w.map.starts[1][1] / 1000 + 4)
	Economy.update_pop(w)
	check(w.pop_cap[1] - cap0 == 6, "rodents: a house holds 6 (%d)" % (w.pop_cap[1] - cap0))
	# Spiders' silk walls; imperial buildings; Han walls.
	var s := _world(["spooky spiders", "imperial humans"])
	check(_cost(s, 0, "wall", "stone") == 2 and _cost(s, 0, "palisade", "wood") == 1, "spiders: walls cost half (%d stone, %d wood)" % [_cost(s, 0, "wall", "stone"), _cost(s, 0, "palisade", "wood")])
	check(_cost(s, 1, "barracks", "wood") == 135, "imperial: buildings 10%% cheaper (%d)" % _cost(s, 1, "barracks", "wood"))
	check(_cost(s, 1, "house", "wood") == 27, "imperial: ...houses too (%d)" % _cost(s, 1, "house", "wood"))
	var h := _world(["han humans", "royal humans"])
	var wk := Economy.btype_of(h, "wall")
	check(h.bmods[0][wk].hp == int(h.btypes[wk].hp) * 120 / 100 and h.bmods[1][wk].hp == int(h.btypes[wk].hp), "han: walls +20%% hit points (%d)" % h.bmods[0][wk].hp)
	# Folk: research 15% faster at every building.
	check(Tech.bpct(h, 0, Economy.btype_of(h, "armoury"), "research_time") == -15, "folk: research 15% faster")
	check(Tech.bpct(w, 0, Economy.btype_of(w, "armoury"), "research_time") == 0, "...bugs not")


## Unit bonuses: those in the eval are priced (beetles' shells), the rest are the sim's (centaurs
## carry, spooky sight, swamp wading, rats' price).
func _test_units() -> void:
	var w := _world(["steppe centaurs", "spooky beetles"])
	var cw: int = w.type_of(0, "worker")
	check(w.types[cw].carry_add == int(w.econ.carry) * 60 / 100, "centaurs: workers carry 60%% more (+%d)" % w.types[cw].carry_add)
	var bs: int = w.type_of(1, "spear")
	check(w.types[bs].sight_add == 2, "spooky: units +2 sight (%d)" % w.types[bs].sight_add)
	var plain: Dictionary = gen.generate("forest humans", rules)
	check(int(w.types[bs].eval.armour.pierce) >= 1, "beetles: +1 pierce armour on the spear's eval (%d)" % int(w.types[bs].eval.armour.pierce))
	var sw := _world(["swamp humans", "swamp frogs"])
	check(sw.types[sw.type_of(0, "spear")].wade == 1, "swamp folk: no slowdown in the swamp or fords")
	check(sw.types[sw.type_of(1, "spear")].wade == 0, "swamp frogs: amphibious already, so the swamp's bonus takes its alt")
	var food := sw.resources.find("food")
	check(sw.gather_ticks[1][food] == int(sw.econ.gather_ticks.food) * 90 / 100, "swamp frogs: ...food gathered 10%% faster (%d)" % sw.gather_ticks[1][food])
	var rat: Dictionary = gen.generate("forest rats", rules)
	var hum: Dictionary = plain
	check(int(rat.units[1].eval.cost.food) + int(rat.units[1].eval.cost.wood) < int(hum.units[1].eval.cost.food) + int(hum.units[1].eval.cost.wood), "rats: units cheaper")


## Lacks: research, buildings, lines, a line's step and the market's trade stay shut; the host's
## full tech tree opens them.
func _test_lacks() -> void:
	var w := _world(["spooky spiders", "royal humans"])
	for p in 2:
		w.ages[p] = 3
		for r in w.resources.size():
			w.stock[r][p] = 5000
	check(Economy.why_not_build(w, 0, Economy.btype_of(w, "stable")) == Tech.NOT_IN_TREE, "spiders: no Stable")
	check(Economy.lacks(w, 0, "scout") and Economy.lacks(w, 0, "large"), "spiders: ...nor its lines")
	var m := _put(w, 0, "market", w.map.starts[0][0] / 1000 + 4, w.map.starts[0][1] / 1000 + 4)
	check(Market.why_not(w, 0, m, w.resources.find("food"), true) == Tech.NOT_IN_TREE, "spooky: no market trade")
	var ar := _put(w, 1, "archery_range", w.map.starts[1][0] / 1000 + 4, w.map.starts[1][1] / 1000 + 4)
	w.researched[1][Tech.research_index(w, "line.skirmisher.2")] = 1
	check(Tech.why_not(w, 1, ar, "line.skirmisher.3") == Tech.NOT_IN_TREE, "royal: no skirmisher age-3 step (%s)" % Tech.why_not(w, 1, ar, "line.skirmisher.3"))
	check(Tech.why_not(w, 1, ar, "line.archer.3") != Tech.NOT_IN_TREE, "royal: ...other line upgrades as usual (%s)" % Tech.why_not(w, 1, ar, "line.archer.3"))
	# Age 3 asks for a Stable; a race without one needs an Archery Range instead.
	var a2 := _world(["spooky spiders", "royal humans"])
	for p in 2:
		a2.ages[p] = 2
		for r in a2.resources.size():
			a2.stock[r][p] = 5000
	check(Tech.why_not(a2, 0, 0, "").begins_with("needs"), "spiders: age 3 needs something first (%s)" % Tech.why_not(a2, 0, 0, ""))
	_put(a2, 0, "archery_range", a2.map.starts[0][0] / 1000 + 4, a2.map.starts[0][1] / 1000 + 4)
	check(Tech.why_not(a2, 0, 0, "") == "", "spiders: ...an Archery Range opens age 3, as they have no Stable (%s)" % Tech.why_not(a2, 0, 0, ""))
	# A lacked line can't be trained even with its building standing (the full tree off).
	var free := rules.duplicate(true)
	free.full_tech_tree = true
	var f := _world(["spooky spiders", "royal humans"], free)
	check(Economy.why_not_build(f, 0, Economy.btype_of(f, "stable")) == "" or Economy.why_not_build(f, 0, Economy.btype_of(f, "stable")).begins_with("needs age"), "full tech tree: spiders may build a Stable")
	check(not Economy.lacks(f, 0, "scout"), "full tech tree: ...and train its lines")
	var g := _world(["forest beetles", "steppe centaurs"])
	g.ages[0] = 3
	g.ages[1] = 3
	for r in g.resources.size():
		g.stock[r][0] = 5000
		g.stock[r][1] = 5000
	var ra := _put(g, 0, "archery_range", g.map.starts[0][0] / 1000 + 4, g.map.starts[0][1] / 1000 + 4)
	check(Tech.why_not(g, 0, ra, "quick_draw") == Tech.NOT_IN_TREE, "beetles: no Quick Draw")
	check(Economy.why_not_build(g, 1, Economy.btype_of(g, "palisade")) == Tech.NOT_IN_TREE, "centaurs: no walls (they roam)")
	var bid: int = g.buildings.id[ra]
	var k := g.type_of(0, "mounted_archer")
	g.issue(0, Commands.TRAIN, {"building": bid, "slot": "mounted_archer"})
	for t in 12:
		g.step()
	check(k < 0 or not k in g.buildings.queue[g.buildings.index_of(bid)], "beetles: no mounted archers trained")


## Own research: each race's, at the Castle in age 3; never another's.
func _test_own_research() -> void:
	var w := _world(["sewer rats", "hellenic humans"])
	for p in 2:
		w.ages[p] = 3
		for r in w.resources.size():
			w.stock[r][p] = 5000
	var c0 := _put(w, 0, "castle", w.map.starts[0][0] / 1000 + 3, w.map.starts[0][1] / 1000 + 3)
	var c1 := _put(w, 1, "castle", w.map.starts[1][0] / 1000 + 3, w.map.starts[1][1] / 1000 + 3)
	for id in ["gnawing_teeth", "rust_spikes"]:
		check(Tech.why_not(w, 0, c0, id) == "", "sewer rats: %s at the Castle (%s)" % [id, Tech.why_not(w, 0, c0, id)])
		check(Tech.why_not(w, 1, c1, id) == Tech.NOT_IN_TREE, "hellenic humans: not %s" % id)
	for id in ["clever_hands", "long_spears"]:
		check(Tech.why_not(w, 1, c1, id) == "", "hellenic humans: %s (%s)" % [id, Tech.why_not(w, 1, c1, id)])
	var sp: int = w.type_of(0, "spear")
	var b_cls: int = w.classes.find("building")
	var before: int = w.types[sp].atk[b_cls]
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[c0], "id": "gnawing_teeth"})
	var hs: int = w.type_of(1, "spear")
	var reach0: int = w.types[hs].reach
	w.issue(1, Commands.RESEARCH, {"building": w.buildings.id[c1], "id": "long_spears"})
	for t in 1200:
		w.step()
	check(w.types[sp].atk[b_cls] == before + 2, "gnawing teeth: soldiers +2 against buildings (%d -> %d)" % [before, w.types[sp].atk[b_cls]])
	check(w.types[hs].reach == reach0 + 350 and not w.types[hs].ranged, "long spears: spears reach further, still melee (%d -> %d)" % [reach0, w.types[hs].reach])


## Aztec kills bring in gold.
func _test_kills() -> void:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := _world(["aztec humans", "imperial humans"], bare)
	var a := w.type_of(0, "infantry")
	var v := w.type_of(1, "worker")
	check(w.types[a].kill_gold == 5, "aztec: kills bring in 5 gold (%d)" % w.types[a].kill_gold)
	var gold := w.resources.find("gold")
	var g0: int = w.stock[gold][0]
	var ids := _spawn(w, 0, "infantry", 20000, 20000, 3)
	_spawn(w, 1, "worker", 21500, 20000, 1)
	w.issue(0, Commands.ATTACK_MOVE, {"ids": ids, "x": 22000, "y": 20000})
	for t in 400:
		w.step()
	check(w.lost[1] == 1 and w.stock[gold][0] == g0 + 5, "aztec: a kill brought in 5 gold (lost %d, gold %d -> %d)" % [w.lost[1], g0, w.stock[gold][0]])


## Spiders' web: a slowing patch where it's thrown, in range, once per cooldown; it wears off;
## the counter: shooters outside it aren't slowed, and it's gone in 15 s. Deterministic.
func _test_web() -> void:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := _world(["forest spiders", "forest humans"], bare)
	var ab: Dictionary = w.ident[0].ability
	check(ab.get("kind", "") == "web", "spiders: their ability is the web")
	check(w.ident[1].ability.is_empty(), "humans: no ability (their culture's, later)")
	var sp := w.type_of(0, "spear")
	check(Abilities.can_use(w, sp) and not Abilities.can_use(w, w.type_of(0, "worker")), "web: spider soldiers throw it, workers not")
	var caster: int = _spawn(w, 0, "spear", 10000, 20000, 1)[0]
	var walker: int = _spawn(w, 1, "spear", 14500, 14000, 1)[0]
	var free: int = _spawn(w, 1, "spear", 26000, 14000, 1)[0]
	w.issue(0, Commands.STANCE, {"ids": [caster], "stance": "passive"})
	w.issue(1, Commands.STANCE, {"ids": [walker, free], "stance": "passive"})
	w.issue(0, Commands.ABILITY, {"ids": [caster], "x": 30000, "y": 20000})   # out of range: nothing
	for t in 12:
		w.step()
	check(w.webs.is_empty(), "web: not past its range")
	w.issue(0, Commands.ABILITY, {"ids": [caster], "x": 14000, "y": 20000})
	for t in 12:
		w.step()
	check(w.webs.size() == Abilities.WEB, "web: thrown where asked (%d)" % (w.webs.size() / Abilities.WEB))
	w.issue(0, Commands.ABILITY, {"ids": [caster], "x": 13000, "y": 20000})
	for t in 12:
		w.step()
	check(w.webs.size() == Abilities.WEB, "web: one per cooldown")
	w.issue(1, Commands.MOVE, {"ids": [walker], "x": 14500, "y": 26000})   # straight through the web
	w.issue(1, Commands.MOVE, {"ids": [free], "x": 26000, "y": 26000})     # the same walk in the open
	var i: int = w.units.index_of(walker)
	var slowed := false
	for t in 120:
		w.step()
		slowed = slowed or w.slow_now.has(walker)
	var dw: int = w.units.y[w.units.index_of(walker)] - 14000
	var df := _walk_without_web()
	check(slowed and dw < df * 90 / 100, "web: an enemy walking through it is slowed (%d vs %d milli-tiles without the web)" % [dw, df])
	check(not w.slow_now.has(caster), "web: never its own side")
	for t in int(ab.lasts):
		w.step()
	check(w.webs.is_empty(), "web: wears off")
	# Sticky Silk (the spiders' own research): their shots slow what they hit.
	var s := _world(["forest spiders", "forest humans"], bare)
	s.researched[0][Tech.research_index(s, "sticky_silk")] = 1
	Tech.retype(s, 0)
	check(s.types[s.type_of(0, "archer")].slow_on_hit > 0 and s.types[s.type_of(0, "spear")].slow_on_hit == 0, "sticky silk: on the shooters only")
	var arch: Array = _spawn(s, 0, "archer", 10000, 20000, 2)
	var tgt: int = _spawn(s, 1, "spear", 14000, 20000, 1)[0]
	s.issue(1, Commands.STANCE, {"ids": [tgt], "stance": "passive"})
	s.issue(0, Commands.ATTACK, {"ids": arch, "target": tgt})
	var stuck := false
	for t in 300:
		s.step()
		stuck = stuck or s.slowed.has(tgt)
	check(stuck, "sticky silk: a hit slows the target")
	# The same commands, the same world: the same hashes.
	var a := _web_run()
	var b := _web_run()
	check(a == b and not a.is_empty(), "web: deterministic (%d checkpoints)" % a.size())


## The same walk (as in _test_web) with no web: how far it gets in 120 ticks.
func _walk_without_web() -> int:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := _world(["forest spiders", "forest humans"], bare)
	var walker: int = _spawn(w, 1, "spear", 14500, 14000, 1)[0]
	w.issue(1, Commands.STANCE, {"ids": [walker], "stance": "passive"})
	for t in 36:
		w.step()
	w.issue(1, Commands.MOVE, {"ids": [walker], "x": 14500, "y": 26000})
	for t in 120:
		w.step()
	return w.units.y[w.units.index_of(walker)] - 14000


func _web_run() -> Array:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := _world(["forest spiders", "forest humans"], bare)
	var c: Array = _spawn(w, 0, "spear", 10000, 20000, 3)
	var e: Array = _spawn(w, 1, "spear", 16000, 20000, 3)
	w.issue(0, Commands.ABILITY, {"ids": c, "x": 15000, "y": 20000})
	w.issue(1, Commands.ATTACK_MOVE, {"ids": e, "x": 9000, "y": 20000})
	for t in 600:
		w.step()
	return w.hashes


## Put n units of a slot for player p at (x, y) (the SPAWN command); their ids.
func _spawn(w: World, p: int, slot: String, x: int, y: int, n: int) -> Array:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	return range(before, w.next_id)
