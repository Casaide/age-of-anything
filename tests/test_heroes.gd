extends SceneTree
## Heroes in the sim (milestone 14 step 9; src/sim/heroes.gd; D-138): several per race, each trained
## once at the Town Center from age 2 (one of each out at a time, all of them together allowed); an aura
## on nearby friends (not foes, not itself, not far ones) in the damage, several heroes' auras not
## adding up; healing slowly; revived after a wait for a share of its price when it falls; deterministic.
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


func _spawn(w: World, p: int, slot: String, x: int, y: int, n: int, hero := "") -> Array:
	var before := w.next_id
	var a := {"slot": slot, "count": n, "x": x, "y": y}
	if hero != "":
		a.hero = hero
	w.issue(p, Commands.SPAWN, a)
	while w.next_id == before:
		w.step()
	return range(before, w.next_id)


func _heroes_of(w: World, p: int) -> int:
	var n := 0
	for i in w.units.count():
		if w.units.owner[i] == p and w.types[w.units.kind[i]].hero:
			n += 1
	return n


## Each hero once, at the Town Center, from age 2, for its price; several heroes out together.
func _test_train() -> void:
	var w := _world(["romans", "sewer rats"])
	var ks := Heroes.types_of(w, 0)
	check(ks.size() >= 3 and ks.all(func(k): return w.types[k].hero and not w.types[k].aura.is_empty()), "romans have several hero types with auras (%d)" % ks.size())
	check(Heroes.types_of(w, 1).size() >= 3 and Heroes.types_of(w, 1).all(func(k): return not k in ks), "so do the rats, their own")
	check("hero" in w.btypes[Economy.btype_of(w, "town_center")].trains, "the Town Center trains heroes")
	var k: int = ks[0]
	var k2: int = ks[1]
	var sid: String = w.types[k].recipe.hero
	var tc0 := _tc(w, 0)
	var tc1 := _tc(w, 1)
	var food := w.resources.find("food")
	for r in w.resources.size():
		w.stock[r][1] = 5000
	w.issue(1, Commands.TRAIN, {"building": tc1, "slot": "hero"})   # age 1: not yet
	_rich(w, 0, 2)
	var f0: int = w.stock[food][0]
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero", "hero": sid})
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero", "hero": sid})   # the same one again: refused
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero"})   # none named: the next one
	for t in 16:
		w.step()
	var b0: int = w.buildings.index_of(tc0)
	check(w.buildings.queue[b0].count(k) == 1 and w.buildings.queue[b0].count(k2) == 1, "two heroes in the queue, each once (%s)" % [w.buildings.queue[b0]])
	check(w.stock[food][0] == f0 - w.types[k].cost[food] - w.types[k2].cost[food], "paid each price once (%d -> %d)" % [f0, w.stock[food][0]])
	check(w.buildings.queue[w.buildings.index_of(tc1)].is_empty(), "no hero in age 1")
	check(Heroes.why_not(w, 0, k) == "on the way" and Heroes.why_not(w, 0, ks[2]) == "", "queued: not again; the third still may come (%s)" % Heroes.why_not(w, 0, k))
	for t in w.types[k].train_ticks + w.types[k2].train_ticks + 40:
		w.step()
	check(w.hero_id[k] != 0 and w.hero_id[k2] != 0 and _heroes_of(w, 0) == 2, "both heroes came out and are known (%d, %d)" % [w.hero_id[k], w.hero_id[k2]])
	check(w.types[w.units.kind[w.units.index_of(w.hero_id[k])]].recipe.hero == sid, "the one named is the one that came")
	w.issue(0, Commands.TRAIN, {"building": tc0, "slot": "hero", "hero": sid})
	for t in 16:
		w.step()
	check(not k in w.buildings.queue[b0] and Heroes.why_not(w, 0, k) == "out already", "out: not a second of the same")
	check(Heroes.type_of(w, 0) == ks[2], "none named: the one not out yet")
	# It heals slowly.
	var i: int = w.units.index_of(w.hero_id[k])
	w.units.hp[i] = 50
	for t in int(w.hero_cfg.regen) * 5:
		w.step()
	i = w.units.index_of(w.hero_id[k])
	check(w.units.hp[i] >= 54 and w.units.hp[i] <= 56, "it heals a hit point every %d ticks (50 -> %d)" % [w.hero_cfg.regen, w.units.hp[i]])


## The aura: friends within its reach, of the kind it names; not foes, not far friends, not itself;
## in the damage. Two heroes' auras of one stat don't add up.
func _test_aura() -> void:
	var w := _world(["swamp frogs", "sewer rats"], _bare())   # the Drowned and the Loud: both +1 attack
	var hk := Heroes.type_of(w, 0, "drowned")
	check(hk >= 0 and Heroes.type_of(w, 0, "loud") >= 0, "swamp frogs have the Drowned and the Loud")
	var h: int = _spawn(w, 0, "hero", 20000, 20000, 1, "drowned")[0]
	var near: int = _spawn(w, 0, "spear", 22000, 20000, 1)[0]
	var far: int = _spawn(w, 0, "spear", 40000, 20000, 1)[0]
	var foe: int = _spawn(w, 1, "spear", 20000, 22500, 1)[0]
	w.issue(0, Commands.STANCE, {"ids": [h, near, far], "stance": "passive"})
	w.issue(1, Commands.STANCE, {"ids": [foe], "stance": "passive"})
	for t in 16:
		w.step()
	check(w.hero_id[hk] == h, "a spawned hero is that hero")
	var fx: Dictionary = w.types[hk].aura[0]
	var at := Heroes.STATS.find(fx.stat)
	var aura := func(uid: int) -> int: return w.aura_now[w.units.index_of(uid) * Heroes.AURA + at]
	check(aura.call(near) == int(fx.add), "a friend nearby gets the aura (%s +%d: %d)" % [fx.stat, fx.add, aura.call(near)])
	check(aura.call(far) == 0 and aura.call(foe) == 0 and aura.call(h) == 0, "not far friends, foes or the hero itself")
	var h2: int = _spawn(w, 0, "hero", 21000, 21000, 1, "loud")[0]
	w.issue(0, Commands.STANCE, {"ids": [h2], "stance": "passive"})
	for t in 4:
		w.step()
	check(w.hero_id[Heroes.type_of(w, 0, "loud")] == h2 and aura.call(near) == int(fx.add), "two heroes' attack auras don't add up (%d)" % aura.call(near))
	check(aura.call(h) == int(fx.add), "each hero is in the other's aura")
	var buf := PackedInt32Array([1, 0, 0, 0, 1, 2])   # slot 0: +1 attack; slot 1: +1 melee, +2 pierce armour
	check(Heroes.boost(buf, 0, 1, "melee", 5, 1) == 5 and Heroes.boost(buf, 0, 1, "pierce", 5, 1) == 4 and Heroes.boost(buf, 0, -1, "melee", 5, 1) == 6 \
		and Heroes.boost(buf, -1, 1, "pierce", 2, 1) == 1, "in the damage: attack adds, armour takes off, never under the floor")
	# Walk away: the aura goes with the heroes.
	w.issue(0, Commands.MOVE, {"ids": [h, h2], "x": 40000, "y": 22000})
	for t in 700:
		w.step()
	check(aura.call(near) == 0 and aura.call(far) == int(fx.add), "the aura goes with the hero")


## When one falls: known as fallen, a wait, then revived at the Town Center for a share of its price;
## the race's other heroes go on as they were.
func _test_revive() -> void:
	var w := _world(["spooky spiders", "imperial humans"])
	_rich(w, 0, 2)
	_rich(w, 1, 2)
	var ks := Heroes.types_of(w, 0)
	var k: int = ks[0]
	var sid: String = w.types[k].recipe.hero
	var h: int = _spawn(w, 0, "hero", 20000, 20000, 1, sid)[0]
	var other: int = _spawn(w, 0, "hero", 50000, 50000, 1, w.types[ks[1]].recipe.hero)[0]
	var foes := _spawn(w, 1, "infantry", 21500, 20000, 12)
	w.units.hp[w.units.index_of(h)] = 5
	w.issue(1, Commands.ATTACK, {"ids": foes, "target": h})
	var fell := false
	for t in 400:
		w.step()
		for e in w.events:
			fell = fell or (e.type == "hero_fell" and e.player == 0 and e.kind == k)
		if fell:
			break
	check(fell and w.hero_id[k] == 0 and w.hero_fell[k] > 0, "the hero fell, and the sim knows (%d)" % w.hero_fell[k])
	check(w.hero_id[ks[1]] == other and w.hero_fell[ks[1]] == 0, "the other hero is still out")
	for id in foes:   # (out of the way of what comes next)
		var j: int = w.units.index_of(id)
		if j >= 0:
			w.units.x[j] = 60000
	var tc := _tc(w, 0)
	var gold := w.resources.find("gold")
	var g0: int = w.stock[gold][0]
	w.issue(0, Commands.TRAIN, {"building": tc, "slot": "hero", "hero": sid})
	for t in 16:
		w.step()
	check(w.stock[gold][0] == g0 and Heroes.why_not(w, 0, k).begins_with("revives in"), "it can't be revived at once (%s)" % Heroes.why_not(w, 0, k))
	while Heroes.revive_left(w, k) > 0:
		w.step()
	var price: int = w.types[k].cost[gold]
	var revive: int = Heroes.cost(w, 0, k)[gold]
	check(revive == price * int(w.hero_cfg.revive_pct) / 100 and revive < price, "a revival costs %d%% of its price (%d of %d gold)" % [w.hero_cfg.revive_pct, revive, price])
	check(Heroes.cost(w, 0, ks[1])[gold] == w.types[ks[1]].cost[gold], "only the fallen one's price drops")
	w.issue(0, Commands.TRAIN, {"building": tc, "slot": "hero", "hero": sid})
	var back := false
	for t in w.types[k].train_ticks + 60:
		w.step()
		for e in w.events:
			back = back or (e.type == "hero_up" and e.player == 0 and e.kind == k and e.revived)
	check(w.stock[gold][0] == g0 - revive, "paid the revival (%d -> %d)" % [g0, w.stock[gold][0]])
	check(back and w.hero_id[k] != 0 and _heroes_of(w, 0) == 2, "revived at the Town Center, beside the other")


## The same commands give the same hashes, heroes and auras included.
func _test_determinism() -> void:
	var hashes := []
	for run in 2:
		var w := _world(["romans", "sewer rats"])
		_rich(w, 0, 2)
		_rich(w, 1, 2)
		for n in 2:
			w.issue(0, Commands.TRAIN, {"building": _tc(w, 0), "slot": "hero"})
			w.issue(1, Commands.TRAIN, {"building": _tc(w, 1), "slot": "hero"})
		_spawn(w, 0, "spear", 30000, 30000, 4)
		_spawn(w, 1, "spear", 31000, 30000, 4)
		for t in 1200:
			w.step()
		hashes.append(w.hashes.duplicate())
	check(hashes[0] == hashes[1] and not hashes[0].is_empty(), "heroes: same commands, same hashes")
