extends SceneTree
## Determinism and speed checks for the sim. Slower than run_tests.gd (about a
## minute): it plays a scripted 10-minute, 200-unit match several times.
## Run: godot --headless --path . --script res://tests/test_sim.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Pricing := preload("res://src/pricing.gd")
const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Replay := preload("res://src/sim/replay.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")
const Combat := preload("res://src/sim/combat.gd")
const Tech := preload("res://src/sim/tech.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const SEED := 20261010
const TICKS := 12000               # 10 minutes at 20 Hz
const PER_SLOT := 20               # x 5 roster slots x 2 players = 200 units
const ORDERS_EVERY := 10           # turns between each player's orders (2 s)
const TICK_BUDGET_USEC := 3000
const CROSS_UNITS := 10            # per roster slot: 50 units, in 5 groups of 10
const CROSS_LIMIT := 2400          # ticks (2 minutes) to get everyone across
const OPENING_TICKS := 3600        # the 3-minute opening
const STALL_TICKS := 100           # a worker idle this long (5 s) has stalled
## Counter fights: [counter, countered, the tag the countered unit needs for this to be
## the counter], fought at equal cost by the same race. Where the countered unit lacks the
## tag (centaur spearmen are large, not infantry), the relation doesn't apply: skipped.
const COUNTERS := [["spear", "large", "large"], ["large", "archer", "ranged"], ["archer", "spear", "infantry"], ["skirmisher", "archer", "archer"]]
const COUNTER_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "royal knights", "viking beetle riders"]
const FIGHT_BUDGET := 600          # food + wood per side
const FIGHT_LIMIT := 3000          # ticks (2.5 minutes)
const FIGHT_FROM := [[11000, 20500], [21000, 20500]]   # open ground on flat_test, 10 tiles apart

## Banned in src/sim/: floats, float maths, engine randomness, wall clocks, Nodes.
const BANNED := [
	"\\bfloat\\b", "\\d+\\.\\d+", "\\brandf", "\\brandi\\(", "RandomNumberGenerator",
	"\\bpow\\(", "\\bsqrt\\(", "\\bsin\\(", "\\bcos\\(", "\\batan2\\(", "\\blerp",
	"\\bTime\\.", "\\bOS\\.", "extends Node", "_physics_process", "Vector2\\b",
]

var rules_: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	for p in PROMPTS:
		races.append(gen.generate(p, rules))
	var map: SimMap = SimMap.load_id("flat_test")   # for reading only; every World loads its own
	rules_ = rules

	_test_fixed()
	_test_command_order()
	_test_source_lint()
	_test_flow(map)
	_test_crossing(races, "flat_test")
	_test_crossing(races, "choke_test")
	_test_opening(races)
	_test_queue(races)
	_test_movement_classes()
	_test_farms(races)
	_test_tech(races)
	_test_combat(gen)

	var script := _script(map, races)
	print("script: %d commands over %d ticks" % [script.size(), TICKS])

	var timing := {}
	var a := _play(map, races, script, false, timing)
	var b := _play(map, races, script, false, {})
	check(a.hashes.size() == TICKS / World.HASH_EVERY, "a checkpoint every %d ticks" % World.HASH_EVERY)
	_same_hashes(a, b, "second run")
	_test_moved(a)

	# Dictionary-order leaks: every race dict rebuilt with reversed key order,
	# stats re-priced from the reversed recipes, commands queued in shuffled order.
	var flipped := []
	for r in races:
		var fr = _reversed(r)
		for i in fr.units.size():
			var e: Dictionary = Pricing.evaluate(fr.units[i].recipe, lib, rules)
			check(e == r.units[i].eval, "pricing ignores key order (%s)" % r.units[i].recipe.name)
			fr.units[i].eval = e
		flipped.append(fr)
	_same_hashes(a, _play(map, flipped, script, true, {}), "reversed dicts + shuffled commands")

	_test_replay(a, lib)
	_test_float_leaks(a, script)
	_report_timing(timing)

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


# --- the scripted match -------------------------------------------------------

## Every command of the match, stamped in advance. Unit ids are predictable:
## spawns run in (player, seq) order, so player 0 gets 1..100 and player 1 101..200.
## Every command of the match, stamped in advance. Ids are predictable: the
## setup gives each player a Town Center then its starting workers (player 0
## first), and the armies spawn in (player, seq) order after that.
func _script(map: SimMap, races: Array) -> Array:
	var rng = Rng.new(SEED ^ 0x5C51)
	var out := []
	var seq := [0, 0]
	var start: Dictionary = rules_.economy.start
	var setup_ids: int = start.buildings.size() + int(start.workers)
	var per_player: int = PER_SLOT * races[0].units.size()
	var army_first: int = 1 + races.size() * setup_ids
	var cmd := func(turn: int, p: int, type: String, args: Dictionary) -> void:
		out.append({"turn": turn, "player": p, "seq": seq[p], "type": type, "args": args})
		seq[p] += 1
	# The economy: two workers on food, one on wood, two more trained, a house.
	for p in races.size():
		var tc := 1 + p * setup_ids
		var food_cell := _nearest_resource(map, map.starts[p], "food")
		var wood_cell := _nearest_resource(map, map.starts[p], "wood")
		cmd.call(0, p, Commands.GATHER, {"ids": [tc + 1, tc + 2], "cell": food_cell})
		cmd.call(0, p, Commands.GATHER, {"ids": [tc + 3], "cell": wood_cell})
		cmd.call(0, p, Commands.RALLY, {"building": tc, "x": (food_cell % map.width) * 1000 + 500, "y": (food_cell / map.width) * 1000 + 500})
		cmd.call(0, p, Commands.TRAIN, {"building": tc, "slot": "worker"})
		cmd.call(0, p, Commands.TRAIN, {"building": tc, "slot": "worker"})
		var spot := _house_spot(map, map.starts[p])
		cmd.call(60, p, Commands.BUILD, {"ids": [tc + 3], "building": "house", "cx": spot.x, "cy": spot.y})
	# The armies arrive at 30 s, then march about.
	for p in races.size():
		for u in races[p].units:
			cmd.call(150, p, Commands.SPAWN, {"slot": u.recipe.slot, "count": PER_SLOT, "x": map.starts[p][0], "y": map.starts[p][1]})
	for turn in range(150 + ORDERS_EVERY, TICKS / Commands.TICKS_PER_TURN - Commands.DELAY, ORDERS_EVERY):
		for p in races.size():
			var first := army_first + p * per_player
			var ids := []
			var mode := rng.range_int(0, 3)
			for uid in range(first, first + per_player):
				if mode == 0 or uid % 4 == mode:   # whole army, or one of three groups
					ids.append(uid)
			var target := _walkable_point(map, rng)
			cmd.call(turn, p, Commands.MOVE, {"ids": ids, "x": target[0], "y": target[1]})
	return out


## The resource cell of a kind nearest a point (ties: lower cell).
func _nearest_resource(map: SimMap, at: Array, kind: String) -> int:
	var best := -1
	var best_d2 := 1 << 62
	for c in map.resource_cells:
		if map.resource_at(c) != kind:
			continue
		var d2 := Fixed.dist2(at[0], at[1], (c % map.width) * 1000 + 500, (c / map.width) * 1000 + 500)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## A free 2x2 spot (with a tile of space around it) near a start, spiralling out.
func _house_spot(map: SimMap, at: Array) -> Vector2i:
	var cx: int = at[0] / 1000
	var cy: int = at[1] / 1000
	for r in range(4, 12):   # the Town Center covers the start +-1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and map.can_build(cx + dx - 1, cy + dy - 1, 4):
					return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)


func _walkable_point(map: SimMap, rng) -> Array:
	while true:
		var x: int = rng.range_int(1000, map.width * 1000 - 1000)
		var y: int = rng.range_int(1000, map.height * 1000 - 1000)
		if map.walkable(x, y):
			return [x, y]
	return []


func _play(map: SimMap, races: Array, script: Array, shuffle: bool, timing: Dictionary) -> World:
	var world := World.new(SEED, SimMap.load_id(map.id), races, rules_)
	var cmds := script.duplicate(true)
	if shuffle:
		cmds = Rng.new(99).shuffled(cmds)
	for c in cmds:
		world.commands.add(c)
	var worst := 0
	var t0 := Time.get_ticks_usec()
	var samples := PackedInt32Array()
	samples.resize(TICKS)
	for i in TICKS:
		var s := Time.get_ticks_usec()
		world.step()
		samples[i] = Time.get_ticks_usec() - s
	timing.total = Time.get_ticks_usec() - t0
	timing.samples = samples
	timing.units = world.units.count()
	return world


func _same_hashes(a: World, b: World, what: String) -> void:
	var n := mini(a.hashes.size(), b.hashes.size())
	for i in n:
		if a.hashes[i] != b.hashes[i]:
			check(false, "%s: hash differs at tick %d" % [what, a.hashes[i][0]])
			return
	check(n == a.hashes.size() and n == b.hashes.size(), "%s: same number of checkpoints" % what)
	print("%s: %d checkpoints match" % [what, n])


## Sanity: the script actually moves things, so matching hashes mean something.
func _test_moved(w: World) -> void:
	var distinct := {}
	for h in w.hashes:
		distinct[h[1]] = true
	check(distinct.size() > w.hashes.size() * 9 / 10, "state keeps changing (%d distinct hashes)" % distinct.size())
	var start: Dictionary = rules_.economy.start
	var lost: int = w.lost[0] + w.lost[1]
	check(w.units.count() + lost == 2 * (5 * PER_SLOT + int(start.workers) + 2), "armies, starting workers and 2 trained each, alive or lost (%d alive, %d lost)" % [w.units.count(), lost])
	check(lost > 0, "the armies fought (%d lost)" % lost)
	var built := 0
	for b in w.buildings.count():
		built += w.buildings.done[b]
	check(built == 4, "both Town Centers and both houses stand (%d built)" % built)
	check(w.stock[0][0] > int(start.food) and w.stock[0][1] > int(start.food), "both sides gathered food (%d, %d)" % [w.stock[0][0], w.stock[0][1]])
	check(w.map.version > 0, "the map changed during the match (houses, cut reeds): version %d" % w.map.version)


# --- economy --------------------------------------------------------------------

## The milestone 3 check: both sides play a 3-minute opening with the economy bot.
func _test_opening(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var bots := [EcoBot.new(0), EcoBot.new(1)]
	var idle_since := {}     # unit id -> tick it went idle; looked up by key only
	var stalls := 0
	var over_cap := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0
	while w.tick < OPENING_TICKS:
		for bot in bots:
			bot.think(w)
		var s := Time.get_ticks_usec()
		w.step()
		worst = maxi(worst, Time.get_ticks_usec() - s)
		for p in races.size():
			if w.pop[p] > w.pop_cap[p]:
				over_cap += 1
		for i in w.units.count():
			var id := w.units.id[i]
			if w.units.task[i] == Economy.NONE and w.units.moving[i] == 0:
				if not idle_since.has(id):
					idle_since[id] = w.tick
				elif w.tick - idle_since[id] == STALL_TICKS:
					stalls += 1
			else:
				idle_since.erase(id)
		if w.tick % 1200 == 0:
			for p in races.size():
				print("  opening %d:00  %-18s workers %2d  pop %2d/%2d  houses %d  gathered %4d food %4d wood  bank %4d/%4d" % [
					w.tick / 1200, w.races[p].name, _count_workers(w, p), w.pop[p], w.pop_cap[p], _count_houses(w, p),
					w.gathered[0][p], w.gathered[1][p], w.stock[0][p], w.stock[1][p]])
	var gave_up := 0
	for i in w.units.count():
		if w.units.stuck[i] >= World.STUCK_LIMIT and w.units.task[i] != Economy.NONE:
			gave_up += 1
	check(stalls == 0, "opening: no worker sits idle for 5 s (%d stalls)" % stalls)
	check(over_cap == 0, "opening: pop never goes over the cap")
	check(gave_up == 0, "opening: no worker is stuck on a job (%d)" % gave_up)
	for p in races.size():
		var total: int = w.gathered[0][p] + w.gathered[1][p]
		check(total >= 600 and total <= 3000, "opening: %s gathers a sensible amount in 3 min (%d)" % [w.races[p].name, total])
		check(_count_houses(w, p) >= 2, "opening: %s builds houses (%d)" % [w.races[p].name, _count_houses(w, p)])
	check(_count_workers(w, 1) > _count_workers(w, 0), "opening: rats (cheap, quick to train) out-breed frogs (%d vs %d)" % [_count_workers(w, 1), _count_workers(w, 0)])
	check(w.pop_cap[1] - 5 == 6 * _count_houses(w, 1), "opening: rat houses give 6 pop")
	print("opening: avg tick %.3f ms, worst %.3f ms" % [(Time.get_ticks_usec() - t0) / 1000.0 / OPENING_TICKS, worst / 1000.0])


func _count_workers(w: World, p: int) -> int:
	var n := 0
	for i in w.units.count():
		if w.units.owner[i] == p and w.types[w.units.kind[i]].worker:
			n += 1
	return n


func _count_houses(w: World, p: int) -> int:
	var house := Economy.btype_of(w, "house")
	var n := 0
	for b in w.buildings.count():
		if w.buildings.owner[b] == p and w.buildings.kind[b] == house and w.buildings.done[b] == 1:
			n += 1
	return n


# --- movement classes -------------------------------------------------------------

## Flyers cross the lake straight; walkers go round; amphibians wade the shallows.
func _test_movement_classes() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var flyers: Dictionary = gen.generate("flying greeks with wings", rules_)
	var rats: Dictionary = gen.generate(PROMPTS[1], rules_)
	var frogs: Dictionary = gen.generate(PROMPTS[0], rules_)
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), [flyers, rats, frogs], bare, [0, 0, 0])
	var from := [25500, 32500]
	var to := [39500, 32500]
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 1, "x": from[0], "y": from[1]})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 1, "x": from[0], "y": from[1] + 600})
	while w.units.count() < 2:
		w.step()
	check(w.units.mclass[0] == 2 and w.units.mclass[1] == 0, "winged hoplites fly, rats walk (%d, %d)" % [w.units.mclass[0], w.units.mclass[1]])
	w.issue(0, Commands.MOVE, {"ids": [w.units.id[0]], "x": to[0], "y": to[1]})
	w.issue(1, Commands.MOVE, {"ids": [w.units.id[1]], "x": to[0], "y": to[1] + 600})
	var arrived := [-1, -1]
	var walked := [0, 0]
	var last := [Vector2(w.units.x[0], w.units.y[0]), Vector2(w.units.x[1], w.units.y[1])]
	var over_water := false
	var water: int = w.map.terrain_ids.find("water")
	var t0 := w.tick
	while w.tick < t0 + 2400 and (arrived[0] < 0 or arrived[1] < 0):
		w.step()
		for i in 2:
			var now := Vector2(w.units.x[i], w.units.y[i])
			walked[i] += int(now.distance_to(last[i]))
			last[i] = now
			if arrived[i] < 0 and w.units.moving[i] == 0 and w.tick > t0 + 20:
				arrived[i] = w.tick - t0
		if w.map.terrain[w.map.cell_of(w.units.x[0], w.units.y[0])] == water:
			over_water = true
	check(over_water, "the flyer crossed over open water")
	var straight: int = to[0] - from[0]
	check(arrived[0] > 0 and walked[0] < straight * 11 / 10, "the flyer goes straight over the lake (%d for %d)" % [walked[0], straight])
	check(arrived[1] > 0 and walked[1] > straight * 115 / 100, "the walker goes round it (%d for %d)" % [walked[1], straight])
	# Amphibians wade the shallows; walkers stop at the edge.
	var shallows: int = w.map.terrain_ids.find("shallows")
	var cell := -1
	for c in w.map.width * w.map.height:
		if w.map.terrain[c] == shallows:
			cell = c
			break
	var at := [(cell % w.map.width) * 1000 + 500, (cell / w.map.width) * 1000 + 500]
	w.issue(2, Commands.SPAWN, {"slot": "spear", "count": 1, "x": from[0], "y": from[1]})
	while w.units.count() < 3:
		w.step()
	var frog := w.units.id[2]
	var rat := w.units.id[1]
	check(w.units.mclass[2] == 1, "frogs are amphibious")
	w.issue(2, Commands.MOVE, {"ids": [frog], "x": at[0], "y": at[1]})
	w.issue(1, Commands.MOVE, {"ids": [rat], "x": at[0], "y": at[1]})
	for t in 1600:
		w.step()
	var fi := w.units.index_of(frog)
	var ri := w.units.index_of(rat)
	check(w.map.terrain[w.map.cell_of(w.units.x[fi], w.units.y[fi])] == shallows, "the frog wades into the shallows")
	check(w.map.terrain[w.map.cell_of(w.units.x[ri], w.units.y[ri])] != shallows, "the rat stops at the water's edge")


# --- farms and placement -------------------------------------------------------

## A farm becomes a crop field its builder harvests; amphibians may farm the shallows
## (a rice paddy); other races can't build on water.
func _test_farms(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[1][0] = 1000
	w.stock[1][1] = 1000
	var s: Array = w.map.starts[0]
	var worker := -1
	for i in w.units.count():
		if w.units.owner[i] == 0:
			worker = w.units.id[i]
			break
	var cx: int = s[0] / 1000 + 3
	var cy: int = s[1] / 1000 + 2
	w.issue(0, Commands.BUILD, {"ids": [worker], "building": "farm", "cx": cx, "cy": cy})
	var field: int = w.map.terrain_ids.find("field")
	while w.tick < 1600 and w.map.terrain[cy * w.map.width + cx] != field:
		w.step()
	check(w.map.terrain[cy * w.map.width + cx] == field, "farm: the frogs' farm became a field")
	var food_before: int = w.stock[0][0]
	for t in 1200:
		w.step()
	var i := w.units.index_of(worker)
	check(w.units.carry_kind[i] == 1 and w.units.task[i] in [Economy.GATHER, Economy.RETURN], "farm: its builder farms it")
	check(w.stock[0][0] > food_before, "farm: food comes in from the field (%d -> %d)" % [food_before, w.stock[0][0]])
	# Water: find a 2x2 of shallows.
	var sh: int = w.map.terrain_ids.find("shallows")
	var spot := Vector2i(-1, -1)
	for y in w.map.height - 1:
		for x in w.map.width - 1:
			var ok := true
			for c in [y * w.map.width + x, y * w.map.width + x + 1, (y + 1) * w.map.width + x, (y + 1) * w.map.width + x + 1]:
				ok = ok and w.map.terrain[c] == sh
			if ok and spot.x < 0:
				spot = Vector2i(x, y)
	check(spot.x >= 0, "farm: the test map has a 2x2 of shallows")
	check(w.map.can_build(spot.x, spot.y, 2, Economy.builder_class(w, 0), true), "farm: frogs (amphibious) may farm the shallows")
	check(not w.map.can_build(spot.x, spot.y, 2, Economy.builder_class(w, 1), true), "farm: rats may not build on water")
	check(not w.map.can_build(spot.x, spot.y, 2, Economy.builder_class(w, 0), false), "farm: a building that doesn't allow water can't go there")
	# Stone: a worker mines the deposit by the start and carries it home.
	var stone_cell := _nearest_resource(w.map, s, "stone")
	var miner := -1
	for i2 in w.units.count():
		if w.units.owner[i2] == 0 and w.units.id[i2] != worker:
			miner = w.units.id[i2]
			break
	var stone_before: int = w.stock[2][0]
	w.issue(0, Commands.GATHER, {"ids": [miner], "cell": stone_cell})
	for t in 1200:
		w.step()
	check(w.stock[2][0] > stone_before, "stone: a worker mines the deposit (%d -> %d)" % [stone_before, w.stock[2][0]])


# --- ages and research ----------------------------------------------------------

## Ageing up moves a player's units along their lines; research adds to stats by tag.
func _test_tech(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in w.resources.size():
		w.stock[r][0] = 5000
	var tc: int = w.buildings.id[0]
	var s: Array = w.map.starts[0]
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 2, "x": s[0] + 3000, "y": s[1]})
	var k: int = w.type_of(0, "spear")
	var age1: Dictionary = w.types[k].recipe
	var food: int = w.stock[0][0]
	w.issue(0, Commands.AGE_UP, {"building": tc})
	w.issue(0, Commands.TRAIN, {"building": tc, "slot": "worker"})
	for t in 40:
		w.step()
	check(w.stock[0][0] < food, "tech: ageing up is paid for")
	check(w.buildings.research[0] == Tech.AGE_UP, "tech: the Town Center is ageing up")
	var units_then := w.units.count()
	var aged := -1
	while w.tick < 2000:
		w.step()
		for e in w.events:
			if e.type == "age" and e.player == 0:
				aged = w.tick
		if aged > 0:
			break
	check(aged > 0 and w.ages[0] == 2, "tech: player 0 reaches age 2 (tick %d)" % aged)
	check(w.units.count() == units_then, "tech: no worker trained while the Town Center was ageing up")
	var line: Array = w.types[k].line
	check(w.types[k].recipe == line[1].recipe and w.types[k].recipe != age1, "tech: spears move to their age-2 recipe (%s)" % [w.types[k].recipe.parts.values()])
	var full := true
	for i in w.units.count():
		if w.units.kind[i] == k:
			full = full and w.units.hp[i] == w.types[k].hp
	check(full, "tech: existing spearmen take the new kit at full health (%d hp)" % w.types[k].hp)
	var atk: int = int(w.types[k].eval.attack)
	w.issue(0, Commands.RESEARCH, {"building": tc, "id": "sharp_sticks"})
	while w.tick < 4000 and w.researched[0][Tech.research_index(w, "sharp_sticks")] == 0:
		w.step()
	check(int(w.types[k].eval.attack) == atk + 1, "tech: Sharp Sticks gives spears +1 attack (%d -> %d)" % [atk, w.types[k].eval.attack])
	w.issue(0, Commands.AGE_UP, {"building": tc})
	while w.tick < 7000 and w.ages[0] < 3:
		w.step()
	check(w.ages[0] == 3 and int(w.types[k].eval.attack) == int(line[2].eval.attack) + 1, "tech: research still counts after the next age-up")


# --- order queues ---------------------------------------------------------------

## Shift-queuing: a worker builds a house, then goes foraging, from one queued order.
func _test_queue(races: Array) -> void:
	var map: SimMap = SimMap.load_id("flat_test")
	var w := World.new(SEED, map, races, rules_)
	var worker := -1
	for i in w.units.count():
		if w.units.owner[i] == 0:
			worker = w.units.id[i]
			break
	var s: Array = map.starts[0]
	var food_cell := _nearest_resource(map, s, "food")
	w.issue(0, Commands.BUILD, {"ids": [worker], "building": "house", "cx": s[0] / 1000 + 3, "cy": s[1] / 1000 - 1})
	w.issue(0, Commands.GATHER, {"ids": [worker], "cell": food_cell, "queue": 1})
	for t in 12:   # orders run two turns (8 ticks) after they're issued
		w.step()
	var i := w.units.index_of(worker)
	check(w.units.task[i] == Economy.BUILD and w.units.orders[i].size() == 1, "queue: the worker builds first, the gather order waits")
	var house_done := -1
	while w.tick < 2400:
		w.step()
		i = w.units.index_of(worker)
		if house_done < 0:
			for b in w.buildings.count():
				if w.buildings.owner[b] == 0 and w.buildings.done[b] == 1 and w.buildings.size[b] == 2:
					house_done = w.tick
		elif w.units.task[i] == Economy.GATHER or w.units.task[i] == Economy.RETURN:
			break
	check(house_done > 0, "queue: the house got built (tick %d)" % house_done)
	check(w.units.task[i] in [Economy.GATHER, Economy.RETURN] and w.units.orders[i].is_empty(), "queue: then the worker went foraging, queue empty")
	w.issue(0, Commands.MOVE, {"ids": [worker], "x": s[0], "y": s[1]})
	w.issue(0, Commands.GATHER, {"ids": [worker], "cell": food_cell, "queue": 1})
	w.issue(0, Commands.MOVE, {"ids": [worker], "x": s[0] + 2000, "y": s[1]})
	for t in 12:
		w.step()
	i = w.units.index_of(worker)
	check(w.units.orders[i].is_empty(), "queue: a plain order empties the queue")


# --- combat ---------------------------------------------------------------------

func _test_combat(gen) -> void:
	_test_damage()
	_test_idle_fight(gen)
	_test_spread(gen)
	_test_teams(gen)
	_test_siege(gen)
	var wins := 0
	var fights := 0
	var t0 := Time.get_ticks_msec()
	for prompt in COUNTER_PROMPTS:
		var race: Dictionary = gen.generate(prompt, rules_)
		for pair in COUNTERS:
			if not pair[2] in _unit(race, pair[1]).eval.tags:
				print("  n/a: %s %s vs %s (the %s isn't %s)" % [race.name, pair[0], pair[1], pair[1], pair[2]])
				continue
			for flip in 2:
				var r := _fight(race, pair[0], pair[1], flip)
				fights += 1
				if r.won:
					wins += 1
				else:
					print("  counter lost: %s %s vs %s (side %d): %s" % [race.name, pair[0], pair[1], flip, r.note])
	print("counters: %d of %d equal-cost fights won by the counter (%d%%), %.1f s" % [wins, fights, wins * 100 / fights, (Time.get_ticks_msec() - t0) / 1000.0])
	check(wins * 100 >= fights * 75, "counters win at least 75%% of equal-cost fights (%d/%d)" % [wins, fights])


## The formula: base type, bonuses only against targets with the tag, class armour, the minimum.
func _test_damage() -> void:
	# classes: melee, pierce, building, large
	var atk := PackedInt32Array([5, 0, 0, 7])    # a spear: 5 melee, +7 vs large
	var arm := PackedInt32Array([2, 4, 0, 0])
	var plain := PackedByteArray([1, 1, 0, 0])
	var large := PackedByteArray([1, 1, 0, 1])
	check(Combat.damage(atk, arm, plain, 1) == 3, "melee 5 - armour 2 = 3")
	check(Combat.damage(atk, arm, large, 1) == 10, "the large bonus only lands on large targets (3 + 7)")
	check(Combat.damage(atk, PackedInt32Array([2, 4, 0, 3]), large, 1) == 7, "class armour blunts a bonus (3 + 7 - 3)")
	check(Combat.damage(PackedInt32Array([0, 4, 0, 0]), PackedInt32Array([0, 9, 0, 0]), plain, 1) == 1, "never less than the minimum")
	check(Combat.damage(PackedInt32Array([0, 6, 0, 0]), PackedInt32Array([9, 0, 0, 0]), plain, 1) == 6, "pierce ignores melee armour")


func _bare_world(races: Array) -> World:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	return World.new(SEED, SimMap.load_id("flat_test"), races, bare)


## Idle soldiers near enemies fight without being told to.
func _test_idle_fight(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var w := _bare_world([race, race])
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 5, "x": 15000, "y": 20500})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 5, "x": 18000, "y": 20500})
	for t in 1200:
		w.step()
	check(w.lost[0] + w.lost[1] > 0, "idle spearmen 3 tiles apart fight on their own (%d lost)" % (w.lost[0] + w.lost[1]))


## Attack-move spreads out: 10 spearmen against 10 make many duels, not a pile-on.
func _test_spread(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var w := _bare_world([race, race])
	for p in 2:
		w.issue(p, Commands.SPAWN, {"slot": "spear", "count": 10, "x": FIGHT_FROM[p][0], "y": FIGHT_FROM[p][1]})
	while w.units.count() < 20:
		w.step()
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": FIGHT_FROM[1 - p][0], "y": FIGHT_FROM[1 - p][1]})
	var most := 0
	for t in 600:
		w.step()
		var foes := {}
		for i in w.units.count():
			if w.units.owner[i] == 0 and w.units.foe[i] != 0:
				foes[w.units.foe[i]] = true
		most = maxi(most, foes.size())
	check(most >= 7, "attack-move spreads: up to %d different foes fought at once by 10 spearmen" % most)


## Two teams of two: allies stand side by side in peace; the teams fight each other.
func _test_teams(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), [race, race, race, race], bare, [0, 0, 1, 1])
	check(not w.is_enemy(0, 1) and w.is_enemy(1, 2) and not w.is_enemy(2, 3), "teams: 0+1 vs 2+3")
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 14000, "y": 20500})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 14500, "y": 21000})
	for t in 600:
		w.step()
	check(w.lost[0] + w.lost[1] == 0, "teams: allies side by side never fight")
	w.issue(2, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 17500, "y": 20500})
	w.issue(3, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 18000, "y": 21000})
	for t in 1500:
		w.step()
	check(w.lost[0] + w.lost[1] + w.lost[2] + w.lost[3] > 0, "teams: the two teams fight (%s lost)" % w.lost)


## Units can knock down a Town Center; its ground opens up again.
func _test_siege(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var w := World.new(SEED, SimMap.load_id("flat_test"), [race, race], rules_)
	var tc: int = w.buildings.id[1]
	var cells := w.buildings.footprint(1, w.map.width)
	var s: Array = w.map.starts[1]
	w.issue(0, Commands.SPAWN, {"slot": "large", "count": 12, "x": s[0] - 4000, "y": s[1]})
	while w.units.count() < 2 * int(rules_.economy.start.workers) + 12:
		w.step()
	var mine := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker:
			mine.append(w.units.id[i])
	w.issue(0, Commands.ATTACK, {"ids": mine, "target": tc})
	var hits := 0
	while w.tick < 6000 and w.buildings.index_of(tc) >= 0:
		w.step()
		for e in w.events:
			if e.type == "hit" and e.to == tc:
				hits += 1
	check(w.buildings.index_of(tc) < 0, "a dozen large units knock down a Town Center (%d hits by tick %d)" % [hits, w.tick])
	check(cells.size() > 0 and Array(cells).all(func(c): return w.map.occupied[c] == 0), "its footprint is free again")


## Equal-cost fight between two of a race's roster slots. `flip` swaps which side
## of the map the counter starts on (it's always the same race on both sides).
## Both sides attack-move at each other; the side with more value left wins.
func _fight(race: Dictionary, a_slot: String, b_slot: String, flip: int) -> Dictionary:
	var w := _bare_world([race, race])
	var slots := [a_slot, b_slot]
	var value := [0, 0]
	for side in 2:
		var p := side ^ flip
		var e: Dictionary = _unit(race, slots[side]).eval
		var cost: int = int(e.cost.food) + int(e.cost.wood)
		value[side] = cost
		var n := maxi(1, (FIGHT_BUDGET + cost / 2) / cost)
		w.issue(p, Commands.SPAWN, {"slot": slots[side], "count": n, "x": FIGHT_FROM[p][0], "y": FIGHT_FROM[p][1]})
	while w.units.count() == 0:
		w.step()
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": FIGHT_FROM[1 - p][0], "y": FIGHT_FROM[1 - p][1]})
	var left := [0, 0]
	while w.tick < FIGHT_LIMIT:
		w.step()
		left = [0, 0]
		for i in w.units.count():
			left[w.units.owner[i]] += 1
		if left[0] == 0 or left[1] == 0:
			break
	var a_left: int = left[flip] * value[0]
	var b_left: int = left[1 - flip] * value[1]
	return {"won": a_left > b_left, "note": "%d %s worth %d left vs %d %s worth %d, tick %d" % [left[flip], a_slot, a_left, left[1 - flip], b_slot, b_left, w.tick]}


func _unit(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	assert(false, "%s has no %s" % [race.name, slot])
	return {}


# --- movement -------------------------------------------------------------------

## The milestone 2 exit criterion: 50 units cross the map in groups, nobody stuck.
func _test_crossing(races: Array, map_id: String) -> void:
	var map: SimMap = SimMap.load_id(map_id)
	var bare := rules_.duplicate(true)   # movement only: no town centres or starting workers
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, map, races, bare)
	var src: Array = map.starts[0]
	var dst: Array = map.starts[1]
	for u in races[0].units:
		w.issue(0, Commands.SPAWN, {"slot": u.recipe.slot, "count": CROSS_UNITS, "x": src[0], "y": src[1]})
	while w.units.count() == 0:
		w.step()
	var ids := Array(w.units.id)
	var groups := ids.size() / CROSS_UNITS
	for g in groups:
		w.issue(0, Commands.MOVE, {"ids": ids.slice(g * CROSS_UNITS, (g + 1) * CROSS_UNITS),
			"x": dst[0] + (g - groups / 2) * 1500, "y": dst[1] + ((g % 2) * 2 - 1) * 1000})
	w.step()
	var settled := -1
	var worst := 0
	var t0 := Time.get_ticks_usec()
	var ticks := 0
	while w.tick < CROSS_LIMIT and settled < 0:
		var s := Time.get_ticks_usec()
		w.step()
		ticks += 1
		worst = maxi(worst, Time.get_ticks_usec() - s)
		if w.tick % 20 == 0 and w.tick > 40 and not 1 in w.units.moving:
			settled = w.tick
	for t in 200:
		w.step()
	check(not 1 in w.units.moving, "%s: still settled 10 s later (no endless jostling)" % map_id)
	var gave_up := 0
	var far := 0
	for i in w.units.count():
		if w.units.stuck[i] >= World.STUCK_LIMIT:
			gave_up += 1
		var near := w.units.arrive[i] * World.SETTLE_FACTOR + 1000
		if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.tx[i], w.units.ty[i]) > near * near:
			far += 1
			print("  far: #%d at %d,%d target %d,%d arrive %d group %d stuck %d" % [w.units.id[i], w.units.x[i], w.units.y[i], w.units.tx[i], w.units.ty[i], w.units.arrive[i], w.units.group[i], w.units.stuck[i]])
	check(settled > 0, "%s: all %d units settle within %d ticks" % [map_id, ids.size(), CROSS_LIMIT])
	check(gave_up == 0, "%s: nobody gives up stuck (%d did)" % [map_id, gave_up])
	check(far == 0, "%s: everyone ends near their own target (%d far)" % [map_id, far])
	print("%s crossing: %d units settled at tick %d (%.1f s), avg tick %.3f ms, worst %.3f ms" % [
		map_id, ids.size(), settled, settled / 20.0, (Time.get_ticks_usec() - t0) / 1000.0 / ticks, worst / 1000.0])


func _test_flow(map: SimMap) -> void:
	var target: int = map.starts[1][1] / 1000 * map.width + map.starts[1][0] / 1000
	var t0 := Time.get_ticks_usec()
	var a = Flow.solve(map, PackedInt32Array([target]))
	var us := Time.get_ticks_usec() - t0
	Flow.solve(map, PackedInt32Array([5 * map.width + 5]))
	var b = Flow.solve(map, PackedInt32Array([target]))
	check(a.dist == b.dist and a.next == b.next, "a flow field doesn't depend on what was solved before")
	var bad := 0
	for c in a.dist.size():
		var reachable: bool = a.dist[c] < Flow.INF
		if (map.walk[c] == 1) != reachable:
			bad += 1
		elif reachable and c != target and a.dist[a.next[c]] >= a.dist[c]:
			bad += 1
	check(bad == 0, "every walkable cell reaches the target downhill on flat_test (%d bad)" % bad)
	t0 = Time.get_ticks_usec()
	var near = Flow.solve(map, PackedInt32Array([target]), 160)
	var near_us := Time.get_ticks_usec() - t0
	var far := 0
	for c in near.dist.size():
		if near.dist[c] < Flow.INF and a.dist[c] > 160 + Flow.DIAGONAL:
			far += 1
	check(far == 0 and near.pops < a.pops / 2, "a near field stops at its cutoff (%d of %d cells)" % [near.pops, a.pops])
	print("flow field solve, %dx%d: %.2f ms full, %.2f ms within 16 tiles" % [map.width, map.height, us / 1000.0, near_us / 1000.0])


# --- replay -------------------------------------------------------------------

func _test_replay(a: World, lib: DataLib) -> void:
	var text := Replay.to_json(Replay.record(a))
	var rep := Replay.from_json(text)
	check(Replay.verify(rep, lib) == -1, "replay from JSON plays back hash-identical")

	# A replay is only as good as its sensitivity: nudge one MOVE by a milli-tile.
	var tampered := rep.duplicate(true)
	for c in tampered.commands:
		if c.type == Commands.MOVE:
			c.args.x += 1
			break
	check(Replay.verify(tampered, lib) > 0, "a one milli-tile change in a replay is caught")
	print("replay: %d bytes of JSON, round trip ok" % text.length())


# --- float leaks --------------------------------------------------------------

func _test_float_leaks(a: World, script: Array) -> void:
	for t in a.types:
		for k in ["speed", "radius", "hp", "player"]:
			check(typeof(t[k]) == TYPE_INT, "unit type %s.%s is an int" % [t.slot, k])
	var bad := 0
	for c in a.history:
		if Commands.problem(c) != "":
			bad += 1
	check(bad == 0, "every command that ran holds only ints and strings")
	check(a.history.size() == script.size(), "every scripted command ran")

	# Raw JSON turns ints into floats; the validator must refuse those.
	var raw = JSON.parse_string(JSON.stringify(script[0]))
	check(Commands.problem(raw) != "", "a command straight from JSON (floats) is refused")
	var nudged: Dictionary = script[-1].duplicate(true)
	nudged.args.x = 1.5
	check(Commands.problem(nudged) != "", "a float command arg is refused")


func _test_source_lint() -> void:
	var res := []
	for p in BANNED:
		var re := RegEx.new()
		re.compile(p)
		res.append(re)
	var files := 0
	for dir in ["res://src/sim/", "res://src/ai/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			files += 1
			var lines := FileAccess.get_file_as_string(dir + f).split("\n")
			for n in lines.size():
				var code := lines[n].get_slice("#", 0)
				for i in res.size():
					if res[i].search(code):
						check(false, "%s%s:%d uses banned '%s': %s" % [dir, f, n + 1, BANNED[i], lines[n].strip_edges()])
	check(files >= 9, "lint saw the sim and AI sources (%d files)" % files)


# --- small pieces ---------------------------------------------------------------

func _test_fixed() -> void:
	var ok := true
	for n in 70000:
		var r := Fixed.isqrt(n)
		if r * r > n or (r + 1) * (r + 1) <= n:
			ok = false
	for n in [1 << 31, (1 << 40) + 12345, 4000000000, 999999999999]:
		var r := Fixed.isqrt(n)
		ok = ok and r * r <= n and (r + 1) * (r + 1) > n
	check(ok, "isqrt is the exact floor square root")
	var sym := true
	for a in Fixed.ANGLES:
		sym = sym and Fixed.sin_a(a) == -Fixed.sin_a(a + 128) and Fixed.cos_a(a) == Fixed.sin_a(a + 64)
		var len2: int = Fixed.sin_a(a) * Fixed.sin_a(a) + Fixed.cos_a(a) * Fixed.cos_a(a)
		sym = sym and absi(len2 - Fixed.ONE * Fixed.ONE) < 2 * Fixed.ONE
	check(sym, "sin/cos table is symmetric and unit length")


func _test_command_order() -> void:
	var q := Commands.new()
	var cmds := []
	for player in [2, 0, 1]:
		for seq in 4:
			cmds.append({"turn": 3, "player": player, "seq": seq, "type": Commands.MOVE, "args": {"ids": [1], "x": 0, "y": 0}})
	for c in Rng.new(5).shuffled(cmds):
		q.add(c)
	var got := q.take(3 + Commands.DELAY)
	var order := got.map(func(c): return c.player * 10 + c.seq)
	check(order == [0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23], "commands run in (player, seq) order: %s" % [order])
	check(q.take(3 + Commands.DELAY).is_empty(), "commands run once")


## Deep copy with every Dictionary's keys inserted in reverse order.
func _reversed(v):
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.reverse()
		var out := {}
		for k in keys:
			out[k] = _reversed(v[k])
		return out
	if v is Array:
		return v.map(_reversed)
	return v


func _report_timing(t: Dictionary) -> void:
	var s: PackedInt32Array = t.samples
	var sorted := s.duplicate()
	sorted.sort()
	var avg: int = t.total / s.size()
	print("tick time, %d units over %d ticks: avg %.3f ms, p50 %.3f, p99 %.3f, max %.3f" % [
		t.units, s.size(), avg / 1000.0, sorted[s.size() / 2] / 1000.0,
		sorted[s.size() * 99 / 100] / 1000.0, sorted[-1] / 1000.0])
	check(avg <= TICK_BUDGET_USEC, "average tick within %d us (got %d)" % [TICK_BUDGET_USEC, avg])
