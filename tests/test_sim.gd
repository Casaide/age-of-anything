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
	rules.animals = false   # these tests count and move every unit; animals have their own test
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
	_test_age_timing(races)
	_test_queue(races)
	_test_movement_classes()
	_test_farms(races)
	_test_tech(races)
	_test_market(races)
	_test_build_queue(races)
	_test_builder_moves_on(races)
	_test_gates(races)
	_test_camp_gather(races)
	_test_drop_off(races)
	_test_animals(races)
	_test_bot_hunts(races)
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
	# A quarter of each army on each stance, so replays and hashes cover them.
	for p in races.size():
		var first := army_first + p * per_player
		for k in range(1, 4):
			var ids := []
			for uid in range(first, first + per_player):
				if uid % 4 == k:
					ids.append(uid)
			cmd.call(151, p, Commands.STANCE, {"ids": ids, "stance": Combat.POSTURES[k]})
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
	# One farm, one pool: its four tiles share one amount, units walk across it, and worked out
	# it lies fallow until a worker reseeds it (for wood).
	var cells: Array = [cy * w.map.width + cx, cy * w.map.width + cx + 1, (cy + 1) * w.map.width + cx, (cy + 1) * w.map.width + cx + 1]
	check(cells.all(func(c): return w.map.left_at(c) == w.map.left_at(cells[0])), "farm: its tiles share one pool of food (%d)" % w.map.left_at(cells[0]))
	check(cells.all(func(c): return w.map.walk[c] == 1), "farm: units can walk across it")
	var farm_id: int = w.map.occupied[cells[0]]
	check(farm_id != 0, "farm: the farm stays standing after it's sown")
	w.map.amount[cells[0]] = 1   # nearly worked out
	while w.tick < 6000 and w.map.left_at(cells[0]) > 0:
		w.step()
	var fallow: int = w.map.terrain_ids.find("fallow")
	check(w.map.terrain[cells[0]] == fallow and w.map.occupied[cells[0]] == farm_id, "farm: worked out, it lies fallow (and is still a farm)")
	var wood_before: int = w.stock[1][0]
	w.issue(0, Commands.RESEED, {"ids": [worker], "building": farm_id})
	for t in 12:
		w.step()
	check(w.map.terrain[cells[0]] == field and w.map.left_at(cells[0]) > 0, "farm: reseeding brings the crops back")
	check(w.stock[1][0] < wood_before, "farm: reseeding costs wood (%d -> %d)" % [wood_before, w.stock[1][0]])
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

## Milestone 7's exit criterion: with the economy bot playing, the age-up lands at
## minutes 4-6 (ticks 4800-7200) for both frogs and rats.
func _test_age_timing(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var bots := [EcoBot.new(0), EcoBot.new(1)]
	var at := [-1, -1]
	while w.tick < 9600 and (at[0] < 0 or at[1] < 0):
		for bot in bots:
			bot.think(w)
		w.step()
		for p in 2:
			if at[p] < 0 and w.ages[p] >= 2:
				at[p] = w.tick
	for p in 2:
		print("  age 2: %-18s at %d:%02d (tick %d)" % [w.races[p].name, at[p] / 1200, at[p] % 1200 / 20, at[p]])
		check(at[p] >= 4800 and at[p] <= 7200, "age-up at minutes 4-6: %s at tick %d" % [w.races[p].name, at[p]])

## Animals: placed by each start and in the wild, nobody's at first; sheep go to the player
## who comes near; a deer runs when hurt; a killed animal leaves food the hunters gather.
func _test_animals(races: Array) -> void:
	var rules := rules_.duplicate(true)
	rules.animals = true
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	var count := {}
	for i in w.units.count():
		if w.units.owner[i] == w.gaia:
			var id: String = w.types[w.units.kind[i]].animal
			count[id] = count.get(id, 0) + 1
	check(count.get("sheep", 0) == 8 and count.get("boar", 0) == 2 and count.get("deer", 0) >= 6,
		"animals: 4 sheep and a boar per start, deer herds out in the wild (%s)" % count)
	var w2 := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	check(w2.state_hash() == w.state_hash(), "animals: the same seed puts them in the same places")
	# A worker walks to a sheep: it becomes ours.
	var sheep := -1
	var worker := -1
	for i in w.units.count():
		if sheep < 0 and w.units.owner[i] == w.gaia and w.types[w.units.kind[i]].animal == "sheep":
			sheep = w.units.id[i]
		if worker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			worker = w.units.id[i]
	var si := w.units.index_of(sheep)
	w.issue(0, Commands.MOVE, {"ids": [worker], "x": w.units.x[si], "y": w.units.y[si]})
	for t in 600:
		w.step()
	si = w.units.index_of(sheep)
	check(si >= 0 and w.units.owner[si] == 0, "animals: a sheep goes to the player who reaches it")
	# Slaughter it: its food lies on the ground and the worker gathers it.
	w.issue(0, Commands.ATTACK, {"ids": [worker], "target": sheep})
	var carcass := -1
	for t in 1200:
		w.step()
		if w.units.index_of(sheep) < 0:
			break
	for c in w.map.resource_cells:
		if w.map.terrain_ids[w.map.terrain[c]] == "carcass" and w.map.amount[c] > 0:
			carcass = c
	var wi := w.units.index_of(worker)
	check(w.units.index_of(sheep) < 0 and carcass >= 0, "animals: a slaughtered sheep leaves its carcass")
	check(wi >= 0 and w.units.task[wi] == Economy.GATHER, "animals: the worker gathers the carcass")
	# A deer bolts when hurt; idle soldiers don't hunt on their own.
	var deer := -1
	for i in w.units.count():
		if deer < 0 and w.units.owner[i] == w.gaia and w.types[w.units.kind[i]].animal == "deer":
			deer = i
	check(not w.is_foe(0, w.units.owner[deer]) and w.is_enemy(0, w.units.owner[deer]), "animals: hunted by choice, not fought by idle soldiers")
	# A rival's sheep, unguarded, is stolen by walking up to it (not killed).
	var w3 := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	var s3 := -1
	var wk3 := -1
	for i in w3.units.count():
		if s3 < 0 and w3.units.owner[i] == w3.gaia and w3.types[w3.units.kind[i]].animal == "sheep":
			s3 = w3.units.id[i]
		if wk3 < 0 and w3.units.owner[i] == 0 and w3.types[w3.units.kind[i]].worker:
			wk3 = w3.units.id[i]
	var i3 := w3.units.index_of(s3)
	w3.units.owner[i3] = 1
	w3.issue(0, Commands.MOVE, {"ids": [wk3], "x": w3.units.x[i3], "y": w3.units.y[i3]})
	for t in 600:
		w3.step()
	i3 = w3.units.index_of(s3)
	check(i3 >= 0 and w3.units.owner[i3] == 0, "animals: an unguarded rival sheep is stolen by walking up to it")


## The economy bot herds and hunts (Dominic: "bot should hunt too"): it claims and slaughters
## its sheep early, hunts a deer that's near home and takes on a boar once it has workers to
## spare; the hunters gather the meat.
func _test_bot_hunts(races: Array) -> void:
	var rules := rules_.duplicate(true)
	rules.animals = true
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	var tc := -1
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0:
			tc = b
	var hx: int = w.buildings.cx[tc] * 1000 + 1500
	var hy: int = w.buildings.cy[tc] * 1000 + 1500
	for i in w.units.count():   # this map's deer graze mid-map, far from home: bring one closer
		if w.types[w.units.kind[i]].get("animal", "") == "deer":
			w.units.x[i] = hx + 8000
			w.units.y[i] = hy + 2000
			break
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 2, "x": hx - 3000, "y": hy - 3000})   # a guard to lead the boar hunt
	var bot := EcoBot.new(0)
	var killed := {}
	var meat := 0
	var when := {}   # the last kill of each kind
	while w.tick < 20 * 60 * 7:
		bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "die" and not e.building and w.types[e.kind].has("animal") and (e.owner == 0 or e.owner == w.gaia):
				killed[w.types[e.kind].animal] = killed.get(w.types[e.kind].animal, 0) + 1
				when[w.types[e.kind].animal] = "%d:%02d" % [w.tick / 1200, w.tick / 20 % 60]
		for i in w.units.count():
			var h: int = w.units.home[i]
			if w.units.owner[i] == 0 and h >= 0 and w.map.terrain_ids[w.map.terrain[h]] == "carcass" and w.units.carry[i] > 0:
				meat = maxi(meat, 1)
	print("  bot hunting, first 7 minutes: %s, the last of each at %s" % [killed, when])
	check(killed.get("sheep", 0) >= 3, "bot hunts: it claims and slaughters its sheep (%d)" % killed.get("sheep", 0))
	check(killed.get("deer", 0) >= 1, "bot hunts: ... a deer near home (%d)" % killed.get("deer", 0))
	check(killed.get("boar", 0) >= 1, "bot hunts: ... and its boar, with a big party (%d)" % killed.get("boar", 0))
	check(w.lost[0] <= 2, "bot hunts: ... losing no more than a couple of hunters to it (%d lost)" % w.lost[0])
	check(meat > 0, "bot hunts: its workers gather the carcasses")


## A builder that finishes with nothing queued goes on to an unfinished building nearby (Dominic).
func _test_builder_moves_on(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[w.resources.find("wood")][0] = 1000
	var ws := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			ws.append(w.units.id[i])
	var s: Array = w.map.starts[0]
	var cx: int = s[0] / 1000
	var cy: int = s[1] / 1000
	var hk := Economy.btype_of(w, "house")
	var spots := []   # two free spots near the start, 3 tiles apart
	for dy in range(-6, 7):
		for dx in range(3, 8):
			if spots.size() < 2 and Economy.can_place(w, 0, hk, cx + dx, cy + dy) \
					and (spots.is_empty() or absi(spots[0].y - (cy + dy)) >= 3):
				spots.append(Vector2i(cx + dx, cy + dy))
	assert(spots.size() == 2)
	w.issue(0, Commands.BUILD, {"ids": [ws[0]], "building": "house", "cx": spots[0].x, "cy": spots[0].y})
	w.issue(0, Commands.BUILD, {"ids": [ws[1]], "building": "house", "cx": spots[1].x, "cy": spots[1].y})
	for t in 16:
		w.step()
	w.issue(0, Commands.MOVE, {"ids": [ws[1]], "x": s[0] - 6000, "y": s[1]})   # walks off: the second house is left a foundation
	var houses := []
	for t in 3000:
		w.step()
		houses = []
		for b in w.buildings.count():
			if w.buildings.owner[b] == 0 and w.btypes[w.buildings.kind[b]].id == "house":
				houses.append(w.buildings.done[b])
		if houses.size() == 2 and houses[0] == 1 and houses[1] == 1:
			break
	check(houses.size() == 2 and houses[0] == 1 and houses[1] == 1, "builders: done with one house, the builder goes on to finish the foundation nearby (%s)" % [houses])


## A long shift-queue of builds (a dragged wall) all goes up: taking the next order from a
## unit's queue must not wipe the rest of it (it did: only two of seven walls were built).
func _test_build_queue(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[w.resources.find("stone")][0] = 500
	w.ages[0] = 2   # stone walls come with age 2
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0:
			ids.append(w.units.id[i])
	var s: Array = w.map.starts[0]
	for k in 7:
		w.issue(0, Commands.BUILD, {"ids": ids, "building": "wall", "cx": s[0] / 1000 + 3, "cy": s[1] / 1000 - 3 + k, "queue": 1 if k > 0 else 0})
	for t in 16:   # past the command delay: every queued foundation is down already, so you see the plan
		w.step()
	var laid := 0
	for b in w.buildings.count():
		if w.btypes[w.buildings.kind[b]].id == "wall":
			laid += 1
	check(laid == 7, "shift-queued builds: all 7 foundations are laid at once (%d)" % laid)
	for t in 3000:
		w.step()
	var done := 0
	for b in w.buildings.count():
		if w.btypes[w.buildings.kind[b]].id == "wall":
			done += w.buildings.done[b]
	check(done == 7, "shift-queued builds: all 7 walls of a line go up (%d)" % done)


## Right-clicking your Town Center with a worker half-loaded: it takes the load in and goes
## back to the same patch (Dominic). A rally point set on a resource sits in the middle of its
## tile, and a worker trained to it gathers there.
func _test_drop_off(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var wi := -1
	var tc := -1
	for i in w.units.count():
		if wi < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			wi = i
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0:
			tc = b
	var wood := Economy.kind_of(w, "wood")
	var uid: int = w.units.id[wi]
	var cell := Economy.nearest_resource(w, w.units.x[wi], w.units.y[wi], wood)
	w.issue(0, Commands.GATHER, {"ids": [uid], "cell": cell})
	for t in 2000:
		w.step()
		wi = w.units.index_of(uid)
		if w.units.carry[wi] >= 2 and w.units.task[wi] == Economy.GATHER:
			break
	var home: int = w.units.home[wi]
	var load: int = w.units.carry[wi]
	var before: int = w.stock[wood - 1][0]
	w.issue(0, Commands.DROP_OFF, {"ids": [uid], "building": w.buildings.id[tc]})
	for t in 12:   # past the command delay: a load still on its back, on the way in
		w.step()
	wi = w.units.index_of(uid)
	check(w.units.task[wi] == Economy.RETURN and w.units.target[wi] == w.buildings.id[tc], "drop off: right-clicking the Town Center sends a loaded worker there")
	for t in 600:
		w.step()
		if w.stock[wood - 1][0] > before:
			break
	wi = w.units.index_of(uid)
	check(load >= 2 and w.stock[wood - 1][0] >= before + load, "drop off: the load (%d) is taken in (%d -> %d)" % [load, before, w.stock[wood - 1][0]])
	check(w.units.task[wi] == Economy.GATHER and w.units.home[wi] == home, "drop off: ... and the worker goes back to its patch")
	# Rally on a resource: the middle of its tile; a worker trained there gathers it.
	var food := Economy.kind_of(w, "food")
	var bush := Economy.nearest_resource(w, w.units.x[wi], w.units.y[wi], food)
	var bx: int = (bush % w.map.width) * SimMap.TILE
	var by: int = (bush / w.map.width) * SimMap.TILE
	w.issue(0, Commands.RALLY, {"building": w.buildings.id[tc], "x": bx + 120, "y": by + 860})
	w.issue(0, Commands.TRAIN, {"building": w.buildings.id[tc], "slot": "worker"})
	var n := w.units.count()
	for t in 12:
		w.step()
	check(w.buildings.rally_x[tc] == bx + 500 and w.buildings.rally_y[tc] == by + 500, "rally: set on a bush, it sits in the middle of the bush's tile")
	w.issue(0, Commands.RALLY, {"building": w.buildings.id[tc], "x": 20120, "y": 20860})   # open ground stays where clicked
	for t in 12:
		w.step()
	var open: bool = w.map.resource_at(w.map.cell_of(20120, 20860)) != "" or (w.buildings.rally_x[tc] == 20120 and w.buildings.rally_y[tc] == 20860)
	check(open, "rally: on open ground it stays where you clicked")
	w.issue(0, Commands.RALLY, {"building": w.buildings.id[tc], "x": bx + 120, "y": by + 860})
	for t in 1200:
		w.step()
		if w.units.count() > n:
			break
	var new_i := -1
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker and w.units.id[i] > uid and new_i < 0 and w.units.task[i] == Economy.GATHER:
			new_i = i
	check(new_i >= 0 and w.units.carry_kind[new_i] == food, "rally: a worker trained to a bush rally gathers food")

## A finished building of type `id` for player p at a cell.
func _put(w: World, p: int, id: String, cx: int, cy: int) -> int:
	var k := Economy.btype_of(w, id)
	var b := Economy.place(w, p, k, cx, cy)
	w.buildings.done[b] = 1
	w.buildings.hp[b] = w.btypes[k].hp
	return w.buildings.id[b]


## A closed square of palisade on flat_test (tiles 12..20 by 18..26) with player 0's gate in
## its east side at (20, 22). Inside is 13..19 by 19..25. Returns [world, gate id].
func _gate_world(races: Array, teams := []) -> Array:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, bare, teams)
	for k in range(12, 21):
		for c in [Vector2i(k, 18), Vector2i(k, 26), Vector2i(12, k + 6), Vector2i(20, k + 6)]:
			if w.map.occupied[c.y * w.map.width + c.x] == 0 and c != Vector2i(20, 22):
				_put(w, 0, "palisade", c.x, c.y)
	check(w.map.walks.size() == 3, "gates: without a gate the map keeps one walk grid per movement class (%d)" % w.map.walks.size())
	var gate := _put(w, 0, "palisade_gate", 20, 22)
	return [w, gate]


func _inside(w: World, uid: int) -> bool:
	var i := w.units.index_of(uid)
	return i >= 0 and w.units.x[i] < 20000 and w.units.x[i] >= 13000 and w.units.y[i] >= 19000 and w.units.y[i] < 26000


## Spawn one unit of a slot for player p inside the square; its id once it's there.
func _spawn_in(w: World, p: int, slot: String) -> int:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": 1, "x": 16500, "y": 22500})
	while w.next_id == before:
		w.step()
	return before


## Gates (milestone 12): a gate lets its own team through and nobody else; knocked down, it
## opens the way for everyone; dropped on a wall tile, it takes that tile's place.
func _test_gates(races: Array) -> void:
	var g := _gate_world(races)
	var w: World = g[0]
	var gate: int = g[1]
	var gc: int = 22 * w.map.width + 20
	check(w.map.walks.size() == 6, "gates: the gate's team gets walk grids of its own (%d)" % w.map.walks.size())
	check(w.map.walks[w.lane_base[0]][gc] == 1 and w.map.walks[w.lane_base[1]][gc] == 0, "gates: open to its owner, shut to the enemy")
	var mine := _spawn_in(w, 0, "worker")
	var theirs := _spawn_in(w, 1, "worker")
	for uid in [mine, theirs]:
		w.issue(w.units.owner[w.units.index_of(uid)], Commands.MOVE, {"ids": [uid], "x": 25500, "y": 22500})
	for t in 600:
		w.step()
	var i := w.units.index_of(mine)
	check(Fixed.dist2(w.units.x[i], w.units.y[i], 25500, 22500) < 1000 * 1000, "gates: a friendly unit walks out through its gate (%d, %d)" % [w.units.x[i], w.units.y[i]])
	check(_inside(w, theirs), "gates: an enemy shut in the square stays in")
	w.issue(0, Commands.MOVE, {"ids": [mine], "x": 16500, "y": 21500})
	for t in 600:
		w.step()
	check(_inside(w, mine), "gates: ... and back in again")

	# Allies share the gate; the enemy knocks it down, and then the way is open to it.
	g = _gate_world([races[0], races[1], races[0]], [0, 0, 1])
	w = g[0]
	gate = g[1]
	var ally := _spawn_in(w, 1, "worker")
	w.issue(1, Commands.MOVE, {"ids": [ally], "x": 25500, "y": 22500})
	var foe := _spawn_in(w, 2, "spear")
	w.issue(2, Commands.MOVE, {"ids": [foe], "x": 25500, "y": 22500})
	for t in 600:
		w.step()
	check(not _inside(w, ally), "gates: an ally walks through too")
	check(_inside(w, foe), "gates: the enemy spearman can't")
	w.issue(2, Commands.ATTACK, {"ids": [foe], "target": gate})
	while w.tick < 8000 and w.buildings.index_of(gate) >= 0:
		w.step()
	check(w.buildings.index_of(gate) < 0, "gates: the enemy knocks the gate down (tick %d)" % w.tick)
	check(w.map.walks[w.lane_base[2]][gc] == 1, "gates: its tile is open to everyone again")
	w.issue(2, Commands.MOVE, {"ids": [foe], "x": 25500, "y": 22500})
	for t in 600:
		w.step()
	i = w.units.index_of(foe)
	check(i >= 0 and Fixed.dist2(w.units.x[i], w.units.y[i], 25500, 22500) < 1000 * 1000, "gates: ... and walks out where it stood")

	# A gate dropped on a wall tile replaces it; the wrong wall or someone else's won't do.
	g = _gate_world(races)
	w = g[0]
	var builder := _spawn_in(w, 0, "worker")
	w.stock[w.resources.find("wood")][0] = 500
	var wall_id: int = w.map.occupied[18 * w.map.width + 16]
	var k := Economy.btype_of(w, "palisade_gate")
	check(Economy.can_place(w, 0, k, 16, 18) and not Economy.can_place(w, 1, k, 16, 18), "gates: a gate goes on your own wall, not on a rival's")
	check(not Economy.can_place(w, 0, Economy.btype_of(w, "stone_gate"), 16, 18), "gates: a stone gate doesn't go on a palisade")
	w.issue(0, Commands.BUILD, {"ids": [builder], "building": "palisade_gate", "cx": 16, "cy": 18})
	for t in 600:
		w.step()
	var nb: int = w.map.occupied[18 * w.map.width + 16]
	var b := w.buildings.index_of(nb)
	check(w.buildings.index_of(wall_id) < 0 and b >= 0 and w.btypes[w.buildings.kind[b]].id == "palisade_gate" and w.buildings.done[b] == 1,
		"gates: dropped on a palisade tile, a gate takes its place and is built")


## A worker who finishes a lumber camp goes and gathers wood (Dominic).
func _test_camp_gather(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var wi := -1
	for i in w.units.count():
		if wi < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			wi = i
	var wood := Economy.kind_of(w, "wood")
	var c := Economy.nearest_resource(w, w.units.x[wi], w.units.y[wi], wood)
	var k := Economy.btype_of(w, "lumber_camp")
	var spot := -1
	for r in range(2, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x: int = c % w.map.width + dx
				var y: int = c / w.map.width + dy
				if spot < 0 and w.map.can_build(x, y, w.btypes[k].size, Economy.builder_class(w, 0), w.btypes[k].water):
					spot = y * w.map.width + x
	w.issue(0, Commands.BUILD, {"ids": [w.units.id[wi]], "building": "lumber_camp", "cx": spot % w.map.width, "cy": spot / w.map.width})
	for t in 1500:
		w.step()
	wi = w.units.index_of(w.units.id[wi])
	check(w.units.task[wi] == Economy.GATHER or w.units.task[wi] == Economy.RETURN, "camps: the builder of a lumber camp goes to gather (task %d)" % w.units.task[wi])
	check(w.units.carry_kind[wi] == wood or w.units.task[wi] == Economy.GATHER and w.map.resource_at(w.units.target[wi]) == "wood",
		"camps: ... wood, what the camp takes in")


## The market: buying costs gold and raises the price, selling pays less and lowers it, and
## nobody trades without a finished market of their own.
func _test_market(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var g: int = w.resources.find("gold")
	var f: int = w.resources.find("food")
	w.stock[g][0] = 1000
	var s: Array = w.map.starts[0]
	var mk := Economy.btype_of(w, "market")
	var m: int = Economy.place(w, 0, mk, s[0] / 1000 + 4, s[1] / 1000 + 3)
	w.issue(0, Commands.TRADE, {"building": w.buildings.id[m], "resource": "food", "buy": 1})
	for t in 20:
		w.step()
	check(w.stock[g][0] == 1000, "market: no trade at an unfinished market")
	w.buildings.done[m] = 1
	var food: int = w.stock[f][0]
	var price: int = w.market_price[f]
	w.issue(0, Commands.TRADE, {"building": w.buildings.id[m], "resource": "food", "buy": 1})
	for t in 20:
		w.step()
	check(w.stock[f][0] == food + 100 and w.stock[g][0] == 1000 - price, "market: buying 100 food costs %d gold" % price)
	check(w.market_price[f] > price, "market: buying raises the price (%d -> %d)" % [price, w.market_price[f]])
	var gold: int = w.stock[g][0]
	var pay: int = w.market_price[f] * 75 / 100
	w.issue(0, Commands.TRADE, {"building": w.buildings.id[m], "resource": "food", "buy": 0})
	for t in 20:
		w.step()
	check(w.stock[g][0] == gold + pay and w.market_price[f] == price, "market: selling pays %d and brings the price back" % pay)
	w.issue(1, Commands.TRADE, {"building": w.buildings.id[m], "resource": "food", "buy": 1})
	var g1: int = w.stock[g][1]
	for t in 20:
		w.step()
	check(w.stock[g][1] == g1, "market: nobody trades at someone else's market")


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
	var offsets := {"barracks": Vector2i(4, -6), "stable": Vector2i(-7, -6), "armoury": Vector2i(4, 3)}
	for need in ["barracks", "stable", "armoury"]:   # what each age-up asks for, and the armoury, already standing
		var nk := Economy.btype_of(w, need)
		var ni: int = Economy.place(w, 0, nk, s[0] / 1000 + offsets[need].x, s[1] / 1000 + offsets[need].y)
		w.buildings.done[ni] = 1
		w.buildings.hp[ni] = w.btypes[nk].hp
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
	check(w.types[k].recipe == age1, "tech: the age-up alone doesn't change the spears (D-100)")
	var barracks := -1
	for b2 in w.buildings.count():
		if w.buildings.owner[b2] == 0 and w.btypes[w.buildings.kind[b2]].id == "barracks":
			barracks = b2
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[barracks], "id": "line.spear.2"})
	while w.tick < 3500 and w.researched[0][Tech.research_index(w, "line.spear.2")] == 0:
		w.step()
	check(w.types[k].recipe == line[1].recipe and w.types[k].recipe != age1, "tech: the spear line's upgrade moves spears to their age-2 recipe (%s)" % [w.types[k].recipe.parts.values()])
	var full := true
	for i in w.units.count():
		if w.units.kind[i] == k:
			full = full and w.units.hp[i] == w.types[k].hp
	check(full, "tech: existing spearmen take the new kit at full health (%d hp)" % w.types[k].hp)
	var atk: int = int(w.types[k].eval.attack)
	var bi: int = -1
	for b2 in w.buildings.count():
		if w.buildings.owner[b2] == 0 and w.btypes[w.buildings.kind[b2]].id == "armoury":
			bi = b2   # Sharp Sticks is researched at the Armoury (milestone 11)
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[bi], "id": "sharp_sticks"})
	while w.tick < 4000 and w.researched[0][Tech.research_index(w, "sharp_sticks")] == 0:
		w.step()
	check(int(w.types[k].eval.attack) == atk + 1, "tech: Sharp Sticks gives spears +1 attack (%d -> %d)" % [atk, w.types[k].eval.attack])
	w.issue(0, Commands.AGE_UP, {"building": tc})
	while w.tick < 7000 and w.ages[0] < 3:
		w.step()
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[barracks], "id": "line.spear.3"})
	while w.tick < 9000 and w.researched[0][Tech.research_index(w, "line.spear.3")] == 0:
		w.step()
	check(w.ages[0] == 3 and int(w.types[k].eval.attack) == int(line[2].eval.attack) + 1, "tech: research still counts after the next age-up")
	# Tech-tree layer: Strong Legs is frogs only (player 0 here is frogs, player 1 rats).
	var bk1 := Economy.btype_of(w, "barracks")
	var rb: int = Economy.place(w, 1, bk1, w.map.starts[1][0] / 1000 + 4, w.map.starts[1][1] / 1000 - 6)
	w.buildings.done[rb] = 1
	w.ages[1] = 2
	for r in w.resources.size():
		w.stock[r][1] = 5000
	check(Tech.why_not(w, 1, rb, "frog_leap") == "not in this race's tech tree", "tech tree: rats can't research the frogs' Strong Legs")
	w.rules = w.rules.duplicate(true)
	w.rules.full_tech_tree = true
	check(Tech.why_not(w, 1, rb, "frog_leap") == "", "tech tree: the host's full tech tree lifts it")
	# Age gates and towers, on a fresh world.
	var g := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in g.resources.size():
		g.stock[r][1] = 5000
	var gs: Array = g.map.starts[1]
	var w1 := -1
	for i in g.units.count():
		if g.units.owner[i] == 1:
			w1 = g.units.id[i]
	var before := g.buildings.count()
	g.issue(1, Commands.BUILD, {"ids": [w1], "building": "stable", "cx": gs[0] / 1000 - 6, "cy": gs[1] / 1000 - 6})
	for t in 12:
		g.step()
	check(g.buildings.count() == before, "gates: no Stable before age 2")
	var tk := Economy.btype_of(g, "watchtower")
	var ti: int = Economy.place(g, 1, tk, gs[0] / 1000 - 4, gs[1] / 1000)
	g.buildings.done[ti] = 1
	g.buildings.hp[ti] = g.btypes[tk].hp
	var tid: int = g.buildings.id[ti]
	# A lone enemy spear five tiles off (in range, not attacking anything): the tower hurts it.
	var ids_before := {}
	for i in g.units.count():
		ids_before[g.units.id[i]] = true
	g.issue(0, Commands.SPAWN, {"slot": "spear", "count": 1, "x": gs[0] - 8500, "y": gs[1] + 500})
	for t in 16:
		g.step()
	var foe := 0
	for i in g.units.count():
		if not ids_before.has(g.units.id[i]):
			foe = g.units.id[i]
	check(foe != 0, "towers: the target spawned")
	var hp0: int = g.units.hp[g.units.index_of(foe)]
	var shots := 0
	var dealt := 0
	for t in 120:
		g.step()
		for e in g.events:
			if e.type == "hit" and e.by == tid and e.to == foe:
				shots += 1
				dealt += int(e.damage)
	var fi: int = g.units.index_of(foe)
	var hp1: int = g.units.hp[fi] if fi >= 0 else 0
	check(shots >= 2 and dealt > 0 and hp1 <= hp0 - dealt, "towers: a finished watchtower damages an enemy unit in range (%d shots, %d damage, hp %d -> %d)" % [shots, dealt, hp0, hp1])


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
	_test_queue_after_build(races, "house")
	_test_queue_after_build(races, "farm")


## Dominic: build, then shift-told to go somewhere else. The builder finishes the building,
## then walks to the queued point: not on to another foundation nearby, and a farm's builder
## doesn't stay to work the field.
func _test_queue_after_build(races: Array, kind: String) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[w.resources.find("wood")][0] = 1000
	var ws := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			ws.append(w.units.id[i])
	var s: Array = w.map.starts[0]
	var bk := Economy.btype_of(w, kind)
	var hk := Economy.btype_of(w, "house")
	var spots := []   # where it goes, and a house foundation nearby that nobody builds
	for dy in range(-6, 7):
		for dx in range(3, 9):
			var c := Vector2i(s[0] / 1000 + dx, s[1] / 1000 + dy)
			if spots.is_empty() and Economy.can_place(w, 0, bk, c.x, c.y):
				spots.append(c)
			elif spots.size() == 1 and absi(spots[0].y - c.y) >= 4 and Economy.can_place(w, 0, hk, c.x, c.y):
				spots.append(c)
	assert(spots.size() == 2)
	w.issue(0, Commands.BUILD, {"ids": [ws[0]], "building": kind, "cx": spots[0].x, "cy": spots[0].y})
	w.issue(0, Commands.BUILD, {"ids": [ws[1]], "building": "house", "cx": spots[1].x, "cy": spots[1].y})
	var to := Vector2i(s[0] - 5000, s[1] + 3000)
	w.issue(0, Commands.MOVE, {"ids": [ws[0]], "x": to.x, "y": to.y, "queue": 1})
	for t in 16:
		w.step()
	w.issue(0, Commands.STOP, {"ids": [ws[1]]})   # the second house stays a foundation
	var built := -1
	var i := -1
	while w.tick < 4000:
		w.step()
		i = w.units.index_of(ws[0])
		var b: int = w.map.occupied[spots[0].y * w.map.width + spots[0].x]
		if built < 0 and b != 0 and w.buildings.done[w.buildings.index_of(b)] == 1:
			built = w.tick
		if built >= 0 and w.units.moving[i] == 0 and w.units.task[i] == Economy.NONE:
			break
	var d := Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], to.x, to.y))
	check(built > 0 and d < 1500 and w.units.task[i] == Economy.NONE,
		"queue: build a %s, then shift-move: built it (tick %d), then walked to the point (%d milli-tiles off, task %d)" % [kind, built, d, w.units.task[i]])


# --- combat ---------------------------------------------------------------------

func _test_combat(gen) -> void:
	_test_damage()
	_test_idle_fight(gen)
	_test_spread(gen)
	_test_teams(gen)
	_test_siege(gen)
	_test_stances(gen)
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


## One unit of `slot` for player p at (x, y) with a stance; returns its id once it exists.
func _lone(w: World, p: int, slot: String, x: int, y: int, stance: String) -> int:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": 1, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	w.issue(p, Commands.STANCE, {"ids": [before], "stance": stance})
	for t in Commands.TICKS_PER_TURN * (Commands.DELAY + 1):
		w.step()
	return before


## Where unit `id` is now.
func _at(w: World, id: int) -> Array:
	var i := w.units.index_of(id)
	return [w.units.x[i], w.units.y[i]]


## Steps a world, tracking how far unit `id` strays from `from` (default: where it is
## now) and the hits each side lands.
func _watch(w: World, ticks: int, id: int, from := []) -> Dictionary:
	var r := {"far": 0, "hits": [0, 0]}
	if from.is_empty():
		from = _at(w, id)
	var x: int = from[0]
	var y: int = from[1]
	for t in ticks:
		w.step()
		var i := w.units.index_of(id)
		if i >= 0:
			r.far = maxi(r.far, Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], x, y)))
		for e in w.events:
			if e.type == "hit":
				var by := w.units.index_of(e.by)
				if by >= 0:
					r.hits[w.units.owner[by]] += 1
	return r


## The four stances. Foes that should not fight back are passive, so each check sees one side's choice.
func _test_stances(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var c: Dictionary = rules_.combat
	var y := 20500
	# Aggressive (the default): chases a foe across most of its sight, and the passive foe never hits back.
	var w := _bare_world([race, race])
	var me := _lone(w, 0, "spear", 15000, y, "aggressive")
	_lone(w, 1, "spear", 20000, y, "passive")
	var r := _watch(w, 600, me)
	check(r.far > 1500 and r.hits[0] > 0, "aggressive: chases a foe 5 tiles off and hits it (went %d, %d hits)" % [r.far, r.hits[0]])
	check(r.hits[1] == 0, "passive: never hits back, even while being hit (%d hits)" % r.hits[1])
	# Defensive: ignores a foe 5 tiles off; goes for one that comes near, chases it no
	# further than the leash, then walks back to where it stood.
	w = _bare_world([race, race])
	me = _lone(w, 0, "spear", 15000, y, "defensive")
	var far := _lone(w, 1, "spear", 20000, y, "passive")
	var stood := _at(w, me)
	r = _watch(w, 200, me)
	check(r.far < 300 and r.hits[0] == 0, "defensive: ignores a foe 5 tiles off (went %d)" % r.far)
	w.issue(1, Commands.MOVE, {"ids": [far], "x": 16500, "y": y})
	r = _watch(w, 100, me)
	check(r.hits[0] > 0, "defensive: goes for a foe that comes near (%d hits)" % r.hits[0])
	w.issue(1, Commands.MOVE, {"ids": [far], "x": 40000, "y": y})
	r = _watch(w, 600, me, stood)
	var i := w.units.index_of(me)
	var home := Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], stood[0], stood[1]))
	check(r.far > 2000 and r.far < int(c.leash) + 1500, "defensive: chases a fleeing foe to the leash (went %d, leash %d)" % [r.far, int(c.leash)])
	check(home < 700 and w.units.foe[i] == 0 and w.units.moving[i] == 0, "defensive: then walks back to where it stood (%d off)" % home)
	# Stand ground, melee: never walks to a foe 2 tiles off, but fights one that comes to it.
	w = _bare_world([race, race])
	me = _lone(w, 0, "spear", 15000, y, "stand")
	_lone(w, 1, "spear", 17000, y, "passive")
	r = _watch(w, 300, me)
	check(r.far < 300 and r.hits[0] == 0, "stand ground: doesn't walk to a foe 2 tiles off (went %d, %d hits)" % [r.far, r.hits[0]])
	_lone(w, 1, "spear", 16000, y, "aggressive")
	r = _watch(w, 400, me)
	check(r.hits[0] > 0 and r.far < 700, "stand ground: fights a foe that comes to it, where it stands (went %d, %d hits)" % [r.far, r.hits[0]])
	# Stand ground, ranged: shoots what is in reach, never steps closer to what isn't.
	w = _bare_world([race, race])
	var reach: int = w.types[w.type_of(0, "archer")].reach
	me = _lone(w, 0, "archer", 15000, y, "stand")
	_lone(w, 1, "spear", 15000 + reach + 2500, y, "passive")
	r = _watch(w, 300, me)
	check(r.far < 300 and r.hits[0] == 0, "stand ground: an archer doesn't step towards a foe out of reach (went %d)" % r.far)
	_lone(w, 1, "spear", 15000 + reach - 500, y, "passive")
	r = _watch(w, 300, me)
	check(r.far < 300 and r.hits[0] > 0, "stand ground: an archer shoots a foe in reach without moving (%d hits)" % r.hits[0])
	# Passive: takes blows without answering; an explicit attack order still works.
	w = _bare_world([race, race])
	me = _lone(w, 0, "spear", 15000, y, "passive")
	var foe := _lone(w, 1, "spear", 15800, y, "aggressive")
	r = _watch(w, 80, me)
	check(r.hits[1] > 0 and r.hits[0] == 0, "passive: takes %d hits and answers none" % r.hits[1])
	w.issue(0, Commands.ATTACK, {"ids": [me], "target": foe})
	r = _watch(w, 100, me)
	check(r.hits[0] > 0, "passive: an ordered attack still fights (%d hits)" % r.hits[0])
	# Stand ground with an ordered target walks to it: orders beat stances.
	w = _bare_world([race, race])
	me = _lone(w, 0, "spear", 15000, y, "stand")
	foe = _lone(w, 1, "spear", 19000, y, "passive")
	w.issue(0, Commands.ATTACK, {"ids": [me], "target": foe})
	r = _watch(w, 400, me)
	check(r.far > 1500 and r.hits[0] > 0, "stand ground: an ordered attack walks to the target (went %d, %d hits)" % [r.far, r.hits[0]])


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
