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

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const SEED := 20261010
const TICKS := 12000               # 10 minutes at 20 Hz
const PER_SLOT := 20               # x 5 roster slots x 2 players = 200 units
const ORDERS_EVERY := 10           # turns between each player's orders (2 s)
const TICK_BUDGET_USEC := 3000
const CROSS_UNITS := 10            # per roster slot: 50 units, in 5 groups of 10
const CROSS_LIMIT := 2400          # ticks (2 minutes) to get everyone across

## Banned in src/sim/: floats, float maths, engine randomness, wall clocks, Nodes.
const BANNED := [
	"\\bfloat\\b", "\\d+\\.\\d+", "\\brandf", "\\brandi\\(", "RandomNumberGenerator",
	"\\bpow\\(", "\\bsqrt\\(", "\\bsin\\(", "\\bcos\\(", "\\batan2\\(", "\\blerp",
	"\\bTime\\.", "\\bOS\\.", "extends Node", "_physics_process", "Vector2\\b",
]

var failures := 0
var checks := 0


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := []
	for p in PROMPTS:
		races.append(gen.generate(p, rules))
	var map: SimMap = SimMap.load_id("flat_test")

	_test_fixed()
	_test_command_order()
	_test_source_lint()
	_test_flow(map)
	_test_crossing(races, "flat_test")
	_test_crossing(races, "choke_test")

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
func _script(map: SimMap, races: Array) -> Array:
	var rng = Rng.new(SEED ^ 0x5C51)
	var out := []
	var seq := [0, 0]
	var per_player: int = PER_SLOT * races[0].units.size()
	for p in races.size():
		for u in races[p].units:
			out.append({"turn": 0, "player": p, "seq": seq[p], "type": Commands.SPAWN,
				"args": {"slot": u.recipe.slot, "count": PER_SLOT, "x": map.starts[p][0], "y": map.starts[p][1]}})
			seq[p] += 1
	for turn in range(ORDERS_EVERY, TICKS / Commands.TICKS_PER_TURN - Commands.DELAY, ORDERS_EVERY):
		for p in races.size():
			var first := 1 + p * per_player
			var ids := []
			var mode := rng.range_int(0, 3)
			for uid in range(first, first + per_player):
				if mode == 0 or uid % 4 == mode:   # whole army, or one of three groups
					ids.append(uid)
			var target := _walkable_point(map, rng)
			out.append({"turn": turn, "player": p, "seq": seq[p], "type": Commands.MOVE,
				"args": {"ids": ids, "x": target[0], "y": target[1]}})
			seq[p] += 1
	return out


func _walkable_point(map: SimMap, rng) -> Array:
	while true:
		var x: int = rng.range_int(1000, map.width * 1000 - 1000)
		var y: int = rng.range_int(1000, map.height * 1000 - 1000)
		if map.walkable(x, y):
			return [x, y]
	return []


func _play(map: SimMap, races: Array, script: Array, shuffle: bool, timing: Dictionary) -> World:
	var world := World.new(SEED, map, races)
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
	check(w.units.count() == 2 * 5 * PER_SLOT, "all 200 units spawned")


# --- movement -------------------------------------------------------------------

## The milestone 2 exit criterion: 50 units cross the map in groups, nobody stuck.
func _test_crossing(races: Array, map_id: String) -> void:
	var map: SimMap = SimMap.load_id(map_id)
	var w := World.new(SEED, map, races)
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
	var a = Flow.solve(map, target)
	var us := Time.get_ticks_usec() - t0
	Flow.solve(map, 5 * map.width + 5)
	var b = Flow.solve(map, target)
	check(a.dist == b.dist and a.next == b.next, "a flow field doesn't depend on what was solved before")
	var bad := 0
	for c in a.dist.size():
		var reachable: bool = a.dist[c] < Flow.INF
		if (map.walk[c] == 1) != reachable:
			bad += 1
		elif reachable and c != target and a.dist[a.next[c]] >= a.dist[c]:
			bad += 1
	check(bad == 0, "every walkable cell reaches the target downhill on flat_test (%d bad)" % bad)
	print("flow field solve, %dx%d: %.2f ms" % [map.width, map.height, us / 1000.0])


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
	for f in DirAccess.get_files_at("res://src/sim"):
		if not f.ends_with(".gd"):
			continue
		files += 1
		var lines := FileAccess.get_file_as_string("res://src/sim/" + f).split("\n")
		for n in lines.size():
			var code := lines[n].get_slice("#", 0)
			for i in res.size():
				if res[i].search(code):
					check(false, "src/sim/%s:%d uses banned '%s': %s" % [f, n + 1, BANNED[i], lines[n].strip_edges()])
	check(files >= 6, "lint saw the sim sources (%d files)" % files)


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
