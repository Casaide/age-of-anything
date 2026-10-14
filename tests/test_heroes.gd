extends SceneTree
## Heroes in the sim (milestone 14 step 9; src/sim/heroes.gd): one per player, trained at the Town
## Center from age 2; its aura on nearby friends (not foes, not itself, not far ones) in the damage;
## healing slowly; revived after a wait for a share of its price when it falls; deterministic.
## Headless, a few seconds. Run: godot --headless --path . --script res://tests/test_heroes.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Heroes := preload("res://src/sim/heroes.gd")

const SEED := 20261014

var gen
var rules: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	gen = Generator.new(DataLib.new())
	rules = DataLib.load_rules("default")
	rules.animals = false
	_test_train()
	_test_aura()
	_test_revive()
	_test_determinism()
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


func _bare() -> Dictionary:
	var bare := rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	return bare


func _rich(w: World, p: int, age: int) -> void:
	w.ages[p] = age
	Tech.retype(w, p)
	for r in w.resources.size():
		w.stock[r][p] = 5000


func _tc(w: World, p: int) -> int:
	for b in w.buildings.count():
		if w.buildings.owner[b] == p and w.btypes[w.buildings.kind[b]].id == "town_center":
			return w.buildings.id[b]
	return -1


func _spawn(w: World, p: int, slot: String, x: int, y: int, n: int) -> Array:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	return range(before, w.next_id)


func _heroes_of(w: World, p: int) -> int:
	var n := 0
	for i in w.units.count():
		if w.units.owner[i] == p and w.types[w.units.kind[i]].hero:
			n += 1
	return n


## One at a time, at the Town Center, from age 2, for its price.
func _test_train() -> void:
	var w := _world(["romans", "sewer rats"])
	var k := Heroes.type_of(w, 0)
	check(k >= 0 and w.types[k].hero and not w.types[k].aura.is_empty(), "romans have a hero type with an aura")
	check("hero" in w.btypes[Economy.btype_of(w, "town_center")].trains, "the Town Center trains the hero")
	var tc0 := _tc(w, 0)
	var tc1 := _tc(w, 1)
	var food := w.resources.find("food")
	for r in w.resources.size():
		w.stock[r][1] = 5000
	w.issue(1, Commands.TRAIN, {"building": tc1, "slot": "hero"})   # age 1: not yet
	_rich(w, 0, 2)
	var f0: int = w.stock[food][0]
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero"})
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero"})   # a second: refused
	for t in 16:
		w.step()
	var b0: int = w.buildings.index_of(tc0)
	check(w.buildings.queue[b0].count(k) == 1, "one hero in the queue, not two (%d)" % w.buildings.queue[b0].count(k))
	check(w.stock[food][0] == f0 - w.types[k].cost[food], "paid its price once (%d -> %d, price %d)" % [f0, w.stock[food][0], w.types[k].cost[food]])
	check(w.buildings.queue[w.buildings.index_of(tc1)].is_empty(), "no hero in age 1")
	check(Heroes.why_not(w, 0) != "", "queued: no other (%s)" % Heroes.why_not(w, 0))
	for t in w.types[k].train_ticks + 40:
		w.step()
	check(w.hero_id[0] != 0 and w.units.index_of(w.hero_id[0]) >= 0 and _heroes_of(w, 0) == 1, "the hero came out and is known (%d)" % w.hero_id[0])
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero"})
	for t in 16:
		w.step()
	check(not k in w.buildings.queue[b0] and Heroes.why_not(w, 0) == "the hero is out already", "out: no second hero")
	# It heals slowly.
	var i: int = w.units.index_of(w.hero_id[0])
	w.units.hp[i] = 50
	for t in int(w.hero_cfg.regen) * 5:
		w.step()
	i = w.units.index_of(w.hero_id[0])
	check(w.units.hp[i] >= 54 and w.units.hp[i] <= 56, "it heals a hit point every %d ticks (50 -> %d)" % [w.hero_cfg.regen, w.units.hp[i]])


## The aura: friends within its reach, of the kind it names; not foes, not far friends, not itself;
## in the damage.
func _test_aura() -> void:
	var w := _world(["romans", "sewer rats"], _bare())   # Lucius's kind: +1 pierce armour (Calm under arrows), or another
	var h: int = _spawn(w, 0, "hero", 20000, 20000, 1)[0]
	var near: int = _spawn(w, 0, "spear", 22000, 20000, 1)[0]
	var far: int = _spawn(w, 0, "spear", 40000, 20000, 1)[0]
	var foe: int = _spawn(w, 1, "spear", 20000, 22500, 1)[0]
	w.issue(0, Commands.STANCE, {"ids": [h, near, far], "stance": "passive"})
	w.issue(1, Commands.STANCE, {"ids": [foe], "stance": "passive"})
	for t in 16:
		w.step()
	check(w.hero_id[0] == h, "a spawned hero is the player's hero")
	var fx: Dictionary = w.types[Heroes.type_of(w, 0)].aura[0]
	var at := Heroes.STATS.find(fx.stat)
	var aura := func(uid: int) -> int: return w.aura_now[w.units.index_of(uid) * Heroes.AURA + at]
	check(aura.call(near) == int(fx.add), "a friend nearby gets the aura (%s +%d: %d)" % [fx.stat, fx.add, aura.call(near)])
	check(aura.call(far) == 0 and aura.call(foe) == 0 and aura.call(h) == 0, "not far friends, foes or the hero itself")
	var buf := PackedInt32Array([1, 0, 0, 0, 1, 2])   # slot 0: +1 attack; slot 1: +1 melee, +2 pierce armour
	check(Heroes.boost(buf, 0, 1, "melee", 5, 1) == 5 and Heroes.boost(buf, 0, 1, "pierce", 5, 1) == 4 and Heroes.boost(buf, 0, -1, "melee", 5, 1) == 6 \
		and Heroes.boost(buf, -1, 1, "pierce", 2, 1) == 1, "in the damage: attack adds, armour takes off, never under the floor")
	# Walk away: the aura goes with the hero.
	w.issue(0, Commands.MOVE, {"ids": [h], "x": 40000, "y": 22000})
	for t in 700:
		w.step()
	check(aura.call(near) == 0 and aura.call(far) == int(fx.add), "the aura goes with the hero")


## When it falls: known as fallen, a wait, then revived at the Town Center for a share of its price.
func _test_revive() -> void:
	var w := _world(["spooky spiders", "imperial humans"])
	_rich(w, 0, 2)
	_rich(w, 1, 2)
	var k := Heroes.type_of(w, 0)
	var h: int = _spawn(w, 0, "hero", 20000, 20000, 1)[0]
	var foes := _spawn(w, 1, "infantry", 21500, 20000, 12)
	w.units.hp[w.units.index_of(h)] = 5
	w.issue(1, Commands.ATTACK, {"ids": foes, "target": h})
	var fell := false
	for t in 400:
		w.step()
		for e in w.events:
			fell = fell or (e.type == "hero_fell" and e.player == 0)
		if fell:
			break
	check(fell and w.hero_id[0] == 0 and w.hero_fell[0] > 0, "the hero fell, and the sim knows (%d)" % w.hero_fell[0])
	for id in foes:   # (out of the way of what comes next)
		var j: int = w.units.index_of(id)
		if j >= 0:
			w.units.x[j] = 60000
	var tc := _tc(w, 0)
	var gold := w.resources.find("gold")
	var g0: int = w.stock[gold][0]
	w.issue(0, Commands.TRAIN, {"building": tc, "slot": "hero"})
	for t in 16:
		w.step()
	check(w.stock[gold][0] == g0 and Heroes.why_not(w, 0).begins_with("revives in"), "it can't be revived at once (%s)" % Heroes.why_not(w, 0))
	while Heroes.revive_left(w, 0) > 0:
		w.step()
	var price: int = w.types[k].cost[gold]
	var revive: int = Heroes.cost(w, 0, k)[gold]
	check(revive == price * int(w.hero_cfg.revive_pct) / 100 and revive < price, "a revival costs %d%% of its price (%d of %d gold)" % [w.hero_cfg.revive_pct, revive, price])
	w.issue(0, Commands.TRAIN, {"building": tc, "slot": "hero"})
	var back := false
	for t in w.types[k].train_ticks + 60:
		w.step()
		for e in w.events:
			back = back or (e.type == "hero_up" and e.player == 0 and e.revived)
	check(w.stock[gold][0] == g0 - revive, "paid the revival (%d -> %d)" % [g0, w.stock[gold][0]])
	check(back and w.hero_id[0] != 0 and _heroes_of(w, 0) == 1, "revived at the Town Center")


## The same commands give the same hashes, heroes and auras included.
func _test_determinism() -> void:
	var hashes := []
	for run in 2:
		var w := _world(["romans", "sewer rats"])
		_rich(w, 0, 2)
		_rich(w, 1, 2)
		w.issue(0, Commands.TRAIN, {"building": _tc(w, 0), "slot": "hero"})
		w.issue(1, Commands.TRAIN, {"building": _tc(w, 1), "slot": "hero"})
		_spawn(w, 0, "spear", 30000, 30000, 4)
		_spawn(w, 1, "spear", 31000, 30000, 4)
		for t in 900:
			w.step()
		hashes.append(w.hashes.duplicate())
	check(hashes[0] == hashes[1] and not hashes[0].is_empty(), "heroes: same commands, same hashes")
