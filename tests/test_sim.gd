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
	check(w.units.count() == 2 * (5 * PER_SLOT + int(start.workers) + 2), "armies, starting workers and 2 trained each (%d units)" % w.units.count())
	var built := 0
	for b in w.buildings.count():
		built += w.buildings.done[b]
	check(built == 4, "both Town Centers and both houses stand (%d built)" % built)
	check(w.food[0] > int(start.food) and w.food[1] > int(start.food), "both sides gathered food (%d, %d)" % [w.food[0], w.food[1]])
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
					w.gathered_food[p], w.gathered_wood[p], w.food[p], w.wood[p]])
	var gave_up := 0
	for i in w.units.count():
		if w.units.stuck[i] >= World.STUCK_LIMIT and w.units.task[i] != Economy.NONE:
			gave_up += 1
	check(stalls == 0, "opening: no worker sits idle for 5 s (%d stalls)" % stalls)
	check(over_cap == 0, "opening: pop never goes over the cap")
	check(gave_up == 0, "opening: no worker is stuck on a job (%d)" % gave_up)
	for p in races.size():
		var total: int = w.gathered_food[p] + w.gathered_wood[p]
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
