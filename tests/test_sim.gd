extends SceneTree
## Determinism and speed checks for the sim. Slower than run_tests.gd (about a
## minute): it plays a scripted 10-minute, 200-unit match several times.
## Run: godot --headless --path . --script res://tests/test_sim.gd [-- serial | part:<name>[,<name>...] | jobs=N]
## (by default its parts run side by side in a few processes, see GROUPS)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Pricing := preload("res://src/pricing.gd")
const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Replay := preload("res://src/sim/replay.gd")
const SaveGame := preload("res://src/save_game.gd")
const Bot := preload("res://src/ai/bot.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")
const Combat := preload("res://src/sim/combat.gd")
const Animals := preload("res://src/sim/animals.gd")
const Pens := preload("res://src/sim/pens.gd")
const Tech := preload("res://src/sim/tech.gd")
const Fog := preload("res://src/sim/fog.gd")
const Market := preload("res://src/sim/market.gd")
const Match := preload("res://src/sim/match.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const TechTreeModel := preload("res://src/view/tech_tree_model.gd")
const BuildingArt := preload("res://src/view/art/building_art.gd")
const Par := preload("res://tests/par.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const SEED := 20261010
const TICKS := 12000               # 10 minutes at 20 Hz
const PER_PLAYER := 99             # soldiers a side, shared over its roster slots (healers and siege too): about 200 units, however many lines
const ORDERS_EVERY := 10           # turns between each player's orders (2 s)
const TICK_BUDGET_USEC := 3000
const CROSS_UNITS := 10            # per roster slot: 60 units, in 6 groups of 10
const CROSS_ENGINES := 3           # siege engines cross on their own: three of each, one slow, big-bodied group
const CROSS_LIMIT := 2400          # ticks (2 minutes) to get everyone across
const OPENING_TICKS := 3600        # the 3-minute opening
const STALL_TICKS := 100           # a worker idle this long (5 s) has stalled
## Counter fights: [counter, countered, the tag the countered unit needs for this to be
## the counter], fought at equal cost by the same race. Where the countered unit lacks the
## tag (centaur spearmen are large, not infantry), the relation doesn't apply: skipped.
const COUNTERS := [["spear", "large", "large"], ["large", "archer", "ranged"], ["archer", "spear", "infantry"], ["skirmisher", "archer", "archer"],
	["infantry", "spear", "spear"], ["archer", "infantry", "infantry"]]
const COUNTER_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "royal knights", "viking beetle riders"]
const FIGHT_BUDGET := 600          # food + wood per side
const FIGHT_LIMIT := 3000          # ticks (2.5 minutes)
const FIGHT_FROM := [[11000, 20500], [21000, 20500]]   # open ground on flat_test, 10 tiles apart

## The parts in each process when run side by side ([name, parts...], by their time alone from
## "@@ ms.<part>"; the three plays of the scripted match apart, about 25-50 s each).
const GROUPS := [
	["scenarios_a", "crossing_flat", "opening", "gates", "diagonal_gates", "pen", "combat"],
	["scenarios_b", "fixed", "command_order", "source_lint", "flow", "crossing_choke", "crossing_engines", "age_timing", "queue", "movement_classes", "farms", "fog_memory", "land", "hills", "flow_patch", "flow_patch_mixed", "tech", "research_queue", "effects", "university_castle", "market", "build_queue", "builder_moves_on", "diagonal_wall", "camp_gather", "drop_off", "animals", "sheep_spot", "garrison", "towers", "shots", "engines", "trade", "sapper_sling", "bot_hunts", "wonder", "walls", "siege_ways", "modes"],
	["match", "match"], ["match_b", "match_b"], ["save_load", "save_load"], ["match_flipped", "match_flipped"],
]

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

	var parts := {
		"fixed": func(): _test_fixed(),
		"command_order": func(): _test_command_order(),
		"source_lint": func(): _test_source_lint(),
		"flow": func(): _test_flow(map),
		"crossing_flat": func(): _test_crossing(races, "flat_test"),
		"crossing_choke": func(): _test_crossing(races, "choke_test"),
		"crossing_engines": func():
			for m in ["flat_test", "choke_test", "hill_test"]:
				_test_crossing(races, m, true),
		"opening": func(): _test_opening(races),
		"age_timing": func(): _test_age_timing(races),
		"queue": func(): _test_queue(races),
		"movement_classes": func(): _test_movement_classes(),
		"farms": func(): _test_farms(races),
		"fog_memory": func(): _test_fog_memory(races),
		"land": func(): _test_land(),
		"hills": func(): _test_hills(races),
		"flow_patch": func(): _test_flow_patch(),
		"flow_patch_mixed": func(): _test_flow_patch_mixed(),
		"tech": func(): _test_tech(races),
		"research_queue": func(): _test_research_queue(races),
		"effects": func(): _test_effects(races),
		"university_castle": func(): _test_university_castle(races),
		"market": func(): _test_market(races),
		"build_queue": func(): _test_build_queue(races),
		"builder_moves_on": func(): _test_builder_moves_on(races),
		"builder_back_to_work": func(): _test_builder_back_to_work(races),
		"no_dark_picks": func(): _test_no_dark_picks(races),
		"wood_spots": func(): _test_wood_spots(races),
		"gates": func(): _test_gates(races),
		"diagonal_wall": func(): _test_diagonal_wall(races),
		"diagonal_gates": func(): _test_diagonal_gates(races),
		"camp_gather": func(): _test_camp_gather(races),
		"drop_off": func(): _test_drop_off(races),
		"animals": func(): _test_animals(races),
		"sheep_spot": func(): _test_sheep_spot(races),
		"pen": func(): _test_pen(races),
		"garrison": func(): _test_garrison(races),
		"towers": func(): _test_towers(races),
		"shots": func(): _test_shots(races),
		"engines": func(): _test_engines(races),
		"trade": func(): _test_trade(races),
		"sapper_sling": func(): _test_sapper_sling(races),
		"bot_hunts": func(): _test_bot_hunts(races),
		"wonder": func(): _test_wonder(races),
		"walls": func(): _test_walls(races),
		"siege_ways": func(): _test_siege_ways(races),
		"modes": func(): _test_modes(races, gen),
		"combat": func(): _test_combat(gen),
		"save_load": func(): _test_save_load(lib, gen),
		"match": func(): _test_match(map, races, lib, rules),
		"match_b": func(): _test_match_b(map, races),
		"match_flipped": func(): _test_match_flipped(map, races, lib, rules),
	}
	var args := Par.plain(OS.get_cmdline_user_args())
	var mode: String = args[0] if args.size() > 0 else ""
	if mode == "serial" or mode.begins_with("part:"):
		var names: Array = parts.keys() if not mode.begins_with("part:") else Array(mode.trim_prefix("part:").split(","))
		for name in names:
			var t0 := Time.get_ticks_msec()
			part = name
			parts[name].call()
			print("@@ ms.%s %d" % [name, Time.get_ticks_msec() - t0])
		_combine(stats)
	else:
		assert(mode == "", "test_sim: unknown mode %s" % mode)
		var results := Par.run(jobs(), Par.jobs_wanted(OS.get_cmdline_user_args()))
		Par.print_logs(results)
		var all := {}
		for r in results:
			checks += maxi(0, r.checks)
			failures += maxi(0, r.failed) + (0 if Par.ok(r) or r.failed > 0 else 1)
			for name in r.args[0].trim_prefix("part:").split(","):
				all[name] = r.stats
		_combine(all)
		print("\n== parts")
		for r in results:
			print("  %-16s %6.1fs  %s" % [r.name, r.secs, Par.summary(r)])
			for f in r.fails:
				print("    ", f)
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The scripted 10-minute, 200-unit match: played twice (same hashes), then with every race dict
## rebuilt in reversed key order and the commands shuffled; replays, float leaks, tick time.
func _test_match(map: SimMap, races: Array, lib, rules: Dictionary) -> void:
	var script := _script(map, races)
	print("script: %d commands over %d ticks" % [script.size(), TICKS])
	var timing := {}
	var a := _play(map, races, script, false, timing)
	check(a.hashes.size() == TICKS / World.HASH_EVERY, "a checkpoint every %d ticks" % World.HASH_EVERY)
	_test_moved(a)
	_test_replay(a, lib)
	_test_float_leaks(a, script)
	_report_timing(timing)
	_stat("hashes", a.hashes)


## The same match again (its hashes go to _combine: the same as the first run's).
func _test_match_b(map: SimMap, races: Array) -> void:
	_stat("hashes", _play(map, races, _script(map, races), false, {}).hashes)


## Dictionary-order leaks: every race dict rebuilt with reversed key order, stats re-priced from
## the reversed recipes, commands queued in shuffled order (its hashes go to _combine).
func _test_match_flipped(map: SimMap, races: Array, lib, rules: Dictionary) -> void:
	var flipped := []
	for r in races:
		var fr = _reversed(r)
		for i in fr.units.size():
			var e: Dictionary = Pricing.evaluate(fr.units[i].recipe, lib, rules, int(r.units[i].line[0].age))
			check(e == r.units[i].eval, "pricing ignores key order (%s)" % r.units[i].recipe.name)
			fr.units[i].eval = e
		flipped.append(fr)
	_stat("hashes", _play(map, flipped, _script(map, races), true, {}).hashes)


var stats := {}   # part -> {key: value} (printed as "@@ key json" for a parent run)
var part := ""


func _stat(key: String, value) -> void:
	if not stats.has(part):
		stats[part] = {}
	stats[part][key] = value
	print("@@ %s %s" % [key, JSON.stringify(value)])


## The checks across parts: the match played again, and flipped, gives the same hashes.
func _combine(all: Dictionary) -> void:
	if not all.has("match"):
		return
	var a: Array = all.match.hashes
	for k in [["match_b", "second run"], ["match_flipped", "reversed dicts + shuffled commands"]]:
		if not all.has(k[0]):
			continue
		var b: Array = all[k[0]].hashes
		var n := mini(a.size(), b.size())
		var differs := -1
		for i in n:
			if int(a[i][1]) != int(b[i][1]) or int(a[i][0]) != int(b[i][0]):
				differs = int(a[i][0])
				break
		check(differs < 0 and n == a.size() and n == b.size(), "%s: same hashes, same number of checkpoints (first differs at tick %d; %d and %d checkpoints)" % [k[1], differs, a.size(), b.size()])
		print("%s: %d checkpoints match" % [k[1], n] if differs < 0 else "%s: hash differs at tick %d" % [k[1], differs])


## The pieces when run side by side (the default): groups of parts of about the same length.
static func jobs() -> Array:
	return GROUPS.map(func(g): return Par.job("sim/" + g[0], "res://tests/test_sim.gd", ["part:" + ",".join(g.slice(1))], 50 if g[0] == "match" else 25))


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
	var per_slot: int = PER_PLAYER / races[0].units.size()   # (more lines, fewer of each: the tick budget is for about 200 units)
	var per_player: int = per_slot * races[0].units.size()
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
			cmd.call(150, p, Commands.SPAWN, {"slot": u.recipe.slot, "count": per_slot, "x": map.starts[p][0], "y": map.starts[p][1]})
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
	check(w.units.count() + lost == 2 * (w.races[0].units.size() * (PER_PLAYER / w.races[0].units.size()) + int(start.workers) + 2), "armies, starting workers and 2 trained each, alive or lost (%d alive, %d lost)" % [w.units.count(), lost])
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
	_test_deep_river()
	_test_flyers_and_walls(flyers, rats)


## Stone walls stop flyers; palisades don't (Dominic, 2026-10-17, D-158). A wall line across the
## whole of flat_test keeps a flyer on its side; a palisade line it flies over. A save from before
## (the walls standing, not marked) gets them marked on load (World.after_load).
func _test_flyers_and_walls(flyers: Dictionary, rats: Dictionary) -> void:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	for kind in ["wall", "palisade"]:
		var w := World.new(SEED, SimMap.load_id("flat_test"), [flyers, rats], bare, [0, 1])
		w.ages[1] = 3
		var m = w.map
		var k := Economy.btype_of(w, kind)
		var y := 20
		for x in m.width:
			Economy.place(w, 1, k, x, y)
		var fly: int = SimMap.FLYING
		var closed := range(m.width).filter(func(x): return m.walks[fly][y * m.width + x] == 0).size()
		if kind == "wall":
			check(closed == m.width, "flyers and walls: a stone wall is closed to flyers (%d of %d cells)" % [closed, m.width])
			for x in m.width:   # as a save from before D-158 has them: standing, not marked
				m.high[y * m.width + x] = 0
				m._refresh(y * m.width + x)
			w.after_load([])
			closed = range(m.width).filter(func(x): return m.walks[fly][y * m.width + x] == 0).size()
			check(closed == m.width, "flyers and walls: an older save's walls are closed to flyers once loaded (%d of %d)" % [closed, m.width])
		else:
			check(closed == 0, "flyers and walls: a palisade is open to flyers (%d of %d closed)" % [closed, m.width])
		w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 1, "x": 30500, "y": 15500})
		while w.units.count() < 1:
			w.step()
		w.issue(0, Commands.MOVE, {"ids": [w.units.id[0]], "x": 30500, "y": 26500})
		for t in 600:
			w.step()
		var past: bool = w.units.y[0] > (y + 1) * 1000
		check(past == (kind == "palisade"), "flyers and walls: the flyer %s the %s (y %d)" % ["crosses" if past else "stays behind", kind, w.units.y[0]])


## Reed Meadow's rivers have a deep middle (Dominic, 2026-10-17: frog races swam the river anywhere):
## no class gets across but at a ford or a bridge, and no flyer crosses a tree. Flood fills over each
## class's walk grid (8-way, no corner cutting), with the fords and without (bridge decks aren't laid
## on a bare SimMap).
func _test_deep_river() -> void:
	for id in ["reed_meadow", "reed_meadow_2v2"]:
		var m: SimMap = SimMap.load_id(id)
		var ford: int = m.terrain_ids.find("ford")
		var tree: int = m.terrain_ids.find("tree")
		var deep: int = m.terrain_ids.find("deep_river")
		check(m.terrain_move[tree] == 0 and m.terrain_move[deep] == 0, "%s: nobody crosses trees or the deep river" % id)
		var a: int = m.cell_of(m.starts[0][0], m.starts[0][1])
		var b: int = m.cell_of(m.starts[1][0], m.starts[1][1])
		for mc in SimMap.CLASSES.size():
			var cut := _flood(m, mc, a, ford)
			var joined := _flood(m, mc, a, -1)
			check(cut[b] == 0 and joined[b] == 1, "%s: %s units cross the river only at a ford (cut %d, with fords %d)" % [id, SimMap.CLASSES[mc], cut[b], joined[b]])


func _flood(m: SimMap, mc: int, from: int, skip: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(m.width * m.height)
	var ok := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= m.width or y >= m.height:
			return false
		var c: int = y * m.width + x
		return m.walks[mc][c] == 1 and m.terrain[c] != skip
	seen[from] = 1
	var todo := [from]
	while not todo.is_empty():
		var c: int = todo.pop_back()
		var x: int = c % m.width
		var y: int = c / m.width
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: int = (y + d.y) * m.width + x + d.x
			if not ok.call(x + d.x, y + d.y) or seen[n] == 1:
				continue
			if d.x != 0 and d.y != 0 and not (ok.call(x + d.x, y) and ok.call(x, y + d.y)):
				continue
			seen[n] = 1
			todo.append(n)
	return seen


# --- the land: trees, rivers, fords, bridges (milestone 15) --------------------------

## On river_test: trees block sight (the first tree is seen, not what's behind it) and
## movement until felled, then leave a walkable stump; walkers cross the river only at the
## ford or the bridge, a frog swims it anywhere; a bridge broken by attack is gone for
## walkers until workers rebuild it (paying wood).
func _test_land() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rats: Dictionary = gen.generate(PROMPTS[1], rules_)
	var frogs: Dictionary = gen.generate(PROMPTS[0], rules_)
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("river_test"), [rats, frogs], bare, [0, 0])   # allies: nobody fights
	var m = w.map
	var tree: int = m.terrain_ids.find("tree")
	var river: int = m.terrain_ids.find("river")
	var ford: int = m.terrain_ids.find("ford")
	check(m.opaque[10 * m.width + 8] == 1, "land: a tree blocks sight")
	# Sight: a rat west of the forest (x 8-10, y 9-14) sees the first tree, not past the forest.
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 1, "x": 5500, "y": 11500})
	while w.units.count() < 1:
		w.step()
	var rat: int = w.units.id[0]
	var ri := w.units.index_of(rat)
	w.units.x[ri] = 5500
	w.units.y[ri] = 11500
	for t in 8:
		w.step()
	check(w.fog[0][11 * m.width + 8] == Fog.VISIBLE, "land: the first tree of the forest is seen")
	check(w.fog[0][11 * m.width + 12] != Fog.VISIBLE, "land: the ground behind the forest isn't")
	check(w.fog[0][8 * m.width + 5] == Fog.VISIBLE, "land: open ground round it is")
	# Crossing: the rat walks from the west bank to the east; every river cell it stands on is
	# the ford or the bridge's deck.
	var cheat := false
	w.issue(0, Commands.MOVE, {"ids": [rat], "x": 30500, "y": 11500})
	var t0 := w.tick
	while w.tick < t0 + 1600:
		w.step()
		ri = w.units.index_of(rat)
		var c: int = m.cell_of(w.units.x[ri], w.units.y[ri])
		if m.terrain[c] == river and m.deck[c] == 0:
			cheat = true
		if w.units.moving[ri] == 0 and w.tick > t0 + 20:
			break
	ri = w.units.index_of(rat)
	check(not cheat, "land: the rat never stands in the river")
	check(w.units.x[ri] > 26000, "land: the rat got across (x %d)" % w.units.x[ri])
	# A frog swims straight over.
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 1, "x": 15500, "y": 11500})
	while w.units.count() < 2:
		w.step()
	var frog: int = w.units.id[1]
	w.issue(1, Commands.MOVE, {"ids": [frog], "x": 25500, "y": 11500})
	var swam := false
	t0 = w.tick
	while w.tick < t0 + 600:
		w.step()
		var fi := w.units.index_of(frog)
		if m.terrain[m.cell_of(w.units.x[fi], w.units.y[fi])] == river:
			swam = true
	check(swam, "land: the frog swims the river")
	check(w.units.x[w.units.index_of(frog)] > 24000, "land: and gets across")
	# Break the bridge: rats attack it till it falls; then walkers can't use it.
	var bridge: int = w.bridge_id[0]
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 6, "x": 24500, "y": 16500})
	while w.units.count() < 8:
		w.step()
	var hitters := []
	for i in w.units.count():
		if w.units.owner[i] == 0:
			hitters.append(w.units.id[i])
	w.issue(0, Commands.ATTACK, {"ids": hitters, "target": bridge})
	t0 = w.tick
	while w.tick < t0 + 6000 and w.bridge_up[0] == 1:
		w.step()
	check(w.bridge_up[0] == 0, "land: the bridge falls (after %d ticks)" % (w.tick - t0))
	var deck: int = 16 * m.width + 20
	check(m.walks[0][deck] == 0, "land: its deck is gone for walkers")
	check(m.walks[1][deck] == 1, "land: amphibians still swim there")
	# Rebuild: workers pay and build; the deck is back.
	w.issue(0, Commands.SPAWN, {"slot": "worker", "count": 2, "x": 24500, "y": 15500})
	while w.units.count() < 10:
		w.step()
	var builders := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			builders.append(w.units.id[i])
	var wood: int = w.resources.find("wood")
	w.stock[wood][0] = 200
	w.issue(0, Commands.HELP_BUILD, {"ids": builders, "target": bridge})
	t0 = w.tick
	while w.tick < t0 + 3000 and w.bridge_up[0] == 0:
		w.step()
	check(w.stock[wood][0] == 50, "land: the rebuild cost 150 wood (%d left)" % w.stock[wood][0])
	check(w.bridge_up[0] == 1 and m.walks[0][deck] == 1, "land: the workers rebuilt the bridge (in %d ticks)" % (w.tick - t0))
	# Felling: a worker cuts the forest's first tree: wood, a stump, sight and a way through.
	var tc: int = 11 * m.width + 8
	m.amount[tc] = 3
	w.issue(0, Commands.GATHER, {"ids": [builders[0]], "cell": tc})
	t0 = w.tick
	while w.tick < t0 + 2000 and m.terrain[tc] == tree:
		w.step()
	check(m.terrain_ids[m.terrain[tc]] == "stump" and m.walks[0][tc] == 1 and m.opaque[tc] == 0, "land: the felled tree is a walkable stump that doesn't block sight")
	check(m.terrain[5 * m.width + 20] == ford, "land: the map has its ford")


## On hill_test (milestone 15, high ground): cliffs block walkers but not flyers and can't be
## built on; walkers climb only by the ramp; shooters reach a level further down a hill and a
## level less far up it (and hit for less); from below you see a hill's rim, not its top;
## from on top you see further; the same match twice gives the same hashes.
func _test_hills(races: Array) -> void:
	var m0: SimMap = SimMap.load_id("hill_test")
	var at := func(x: int, y: int) -> int: return y * m0.width + x
	check(m0.has_heights and m0.level[at.call(15, 9)] == 1 and m0.level[at.call(19, 8)] == 2, "hills: levels load")
	check(m0.cliff[at.call(13, 9)] == 1 and m0.walks[0][at.call(13, 9)] == 0, "hills: the foot of the west face is a cliff, closed to walkers")
	check(m0.walks[2][at.call(13, 9)] == 1, "hills: flyers cross the cliff")
	check(m0.ramp[at.call(13, 12)] == 1 and m0.walks[0][at.call(13, 12)] == 1 and m0.cliff[at.call(13, 12)] == 0, "hills: the ramp is open")
	check(m0.cliff[at.call(17, 7)] == 1 and m0.cliff[at.call(17, 8)] == 0, "hills: the knoll's face is a cliff, its ramp isn't")
	check(not m0.can_build(12, 8, 2) and not m0.can_build(13, 11, 1), "hills: nothing built on a cliff or a ramp")
	check(m0.can_build(15, 12, 2) and not m0.can_build(16, 9, 3), "hills: buildings stand on one level")
	var flat_hash: int = SimMap.load_id("hill_test").map_hash
	check(flat_hash == m0.map_hash, "hills: the map hash is stable")

	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	# Climbing: a walker below the west face goes onto the plateau by the ramp, never on a cliff.
	var w := World.new(SEED, SimMap.load_id("hill_test"), races, bare)
	var m = w.map
	var u := _lone(w, 0, "spear", 9500, 6500, "passive")
	w.issue(0, Commands.MOVE, {"ids": [u], "x": 16500, "y": 6500})
	var on_cliff := false
	var by_ramp := false
	var t0 := w.tick
	while w.tick < t0 + 1200:
		w.step()
		var i := w.units.index_of(u)
		var c: int = m.cell_of(w.units.x[i], w.units.y[i])
		on_cliff = on_cliff or m.cliff[c] == 1
		by_ramp = by_ramp or m.ramp[c] == 1
		if w.units.moving[i] == 0 and w.tick > t0 + 20:
			break
	var p := _at(w, u)
	check(not on_cliff, "hills: the walker never stands on a cliff")
	check(by_ramp, "hills: it went up by the ramp")
	check(m.level_at(p[0], p[1]) == 1 and absi(p[0] - 16500) < 1200, "hills: it got onto the plateau (%d,%d)" % [p[0], p[1]])

	# Sight: from below at (11, 9) the rim (14, 9) is seen, the plateau beyond (16, 9) isn't;
	# from on top at (16, 9) the low ground 7 tiles off is (sight 6 + 1 for the level).
	var i := w.units.index_of(u)
	w.units.x[i] = 11500
	w.units.y[i] = 9500
	for t in 8:
		w.step()
	check(w.fog[0][at.call(14, 9)] == Fog.VISIBLE, "hills: from below, the rim is seen")
	check(w.fog[0][at.call(16, 9)] != Fog.VISIBLE, "hills: from below, the top beyond the rim isn't")
	check(w.fog[0][at.call(11, 15)] == Fog.VISIBLE, "hills: open low ground round it is")
	w.units.x[i] = 16500
	w.units.y[i] = 9500
	for t in 8:
		w.step()
	check(w.fog[0][at.call(9, 9)] == Fog.VISIBLE, "hills: from on top you see further (7 tiles)")

	# Range: an archer reaches a level further down, a level less far up; uphill hits are weaker.
	var arch: Dictionary = {}
	for k in w.types.size():
		if w.types[k].player == 0 and w.types[k].slot == "archer":
			arch = w.types[k]
	var reach: int = arch.reach
	var down := _shoot(races, bare, 14800, -(reach + 600))   # archer on top, target below, beyond its flat reach
	var up := _shoot(races, bare, 12600, reach - 400)        # archer below, target on top, inside its flat reach
	var flat := _shoot(races, bare, 9500, reach + 600, 16500) # on the low ground, beyond reach
	check(down.hit and down.far < 200, "hills: shooting down, it hits from %d beyond its reach without moving (moved %d)" % [600, down.far])
	check(up.hit and up.far > 300, "hills: shooting up, it must close in first (moved %d)" % up.far)
	check(flat.hit and flat.far > 300, "hills: on the flat, the same gap needs closing (moved %d)" % flat.far)
	check(up.damage < flat.damage, "hills: an uphill shot hits for less (%d vs %d)" % [up.damage, flat.damage])
	check(Combat.uphill(w, 8) == 6 and Combat.uphill(w, 1) == 1, "hills: uphill damage is 75%%, at least 1")

	# Determinism: the walkers' crossing onto the plateau, twice.
	_test_crossing(races, "hill_test")
	var a := _hill_match(races, bare)
	var b := _hill_match(races, bare)
	_same_hashes(a, b, "hill_test fight")


## An archer of side 0 at (ax, ay) and a passive spear of side 1 `gap` milli-tiles (edge to
## edge) off along x; until the first shot lands: did it, how far the archer walked first, how hard.
func _shoot(races: Array, bare: Dictionary, ax: int, gap: int, ay := 6500) -> Dictionary:
	var w := World.new(SEED, SimMap.load_id("hill_test"), races, bare)
	var a := _lone(w, 0, "archer", ax, ay, "aggressive")
	var ai := w.units.index_of(a)
	var t := _lone(w, 1, "spear", ax, ay + 4000, "passive")
	var ti := w.units.index_of(t)
	ai = w.units.index_of(a)
	var r: int = w.units.radius[ai] + w.units.radius[ti]
	w.units.x[ai] = ax
	w.units.y[ai] = ay
	w.units.x[ti] = ax + signi(gap) * (absi(gap) + r) if gap < 0 else ax + gap + r
	w.units.y[ti] = ay
	w.issue(0, Commands.ATTACK, {"ids": [a], "target": t})
	var out := {"hit": false, "far": 0, "damage": 0}
	for k in 400:
		w.step()
		ai = w.units.index_of(a)
		out.far = maxi(out.far, absi(w.units.x[ai] - ax) + absi(w.units.y[ai] - ay))
		for e in w.events:
			if e.type == "hit" and e.by == a:
				out.hit = true
				out.damage = e.damage
		if out.hit:
			break
	return out


## Two small armies fight over the hill's ramp (attack-moves both ways).
func _hill_match(races: Array, bare: Dictionary) -> World:
	var w := World.new(SEED, SimMap.load_id("hill_test"), races, bare)
	w.issue(0, Commands.SPAWN, {"slot": "archer", "count": 4, "x": 6500, "y": 12500})
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 6500, "y": 13500})
	w.issue(1, Commands.SPAWN, {"slot": "archer", "count": 4, "x": 16500, "y": 12500})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 4, "x": 16500, "y": 13500})
	for k in 20:
		w.step()
	var mine := []
	var theirs := []
	for i in w.units.count():
		(mine if w.units.owner[i] == 0 else theirs).append(w.units.id[i])
	w.issue(0, Commands.ATTACK_MOVE, {"ids": mine, "x": 18500, "y": 12500})
	w.issue(1, Commands.ATTACK_MOVE, {"ids": theirs, "x": 5500, "y": 12500})
	for k in 1200:
		w.step()
	return w


## A field patched for opened cells (trees felled, one by one and side by side) has the same
## costs as one solved from scratch on the changed map.
func _test_flow_patch() -> void:
	var m: SimMap = SimMap.load_id("river_test")
	var target: int = 12 * m.width + 4
	var full = Flow.solve(m, PackedInt32Array([target]))
	var near = Flow.solve(m, PackedInt32Array([target]), World.NEAR_CUTOFF)
	var fell := [11 * m.width + 8, 11 * m.width + 9, 12 * m.width + 9, 10 * m.width + 10, 11 * m.width + 10]
	for c in fell:
		m.fresh.clear()
		while m.amount[c] > 0:
			m.take(c)
		for f in m.fresh:
			full.patch(m, f)
			near.patch(m, f)
	var fresh = Flow.solve(m, PackedInt32Array([target]))
	var fresh_near = Flow.solve(m, PackedInt32Array([target]), World.NEAR_CUTOFF)
	var same := 0
	var same_near := 0
	for c in m.width * m.height:
		if full.dist[c] == fresh.dist[c]:
			same += 1
		if (near.dist[c] <= World.NEAR_CUTOFF) == (fresh_near.dist[c] <= World.NEAR_CUTOFF) and (near.dist[c] > World.NEAR_CUTOFF or near.dist[c] == fresh_near.dist[c]):
			same_near += 1
	check(same == m.width * m.height, "flow patch: a patched field matches a fresh solve (%d of %d cells)" % [same, m.width * m.height])
	check(same_near == m.width * m.height, "flow patch: a patched near field matches within its cutoff (%d of %d)" % [same_near, m.width * m.height])
	for c in m.width * m.height:   # every step leads downhill to the target
		if full.dist[c] > 0 and full.dist[c] < Flow.INF:
			if full.dist[full.next[c]] >= full.dist[c]:
				check(false, "flow patch: next of cell %d goes uphill" % c)
				break


## Fields patched for cells closing and opening together (buildings put up and pulled down,
## trees felled, over a big map) keep a fresh solve's costs, and every step still leads downhill.
func _test_flow_patch_mixed() -> void:
	var m: SimMap = SimMap.load_id("reed_meadow_2v2")
	var targets := [40 * m.width + 44, 10 * m.width + 12, 70 * m.width + 20]
	var fs := []
	for t in targets:
		fs.append([Flow.solve(m, PackedInt32Array([t])), Flow.INF])
		fs.append([Flow.solve(m, PackedInt32Array([t]), World.NEAR_CUTOFF), World.NEAR_CUTOFF])
	var rng := Rng.new(77)
	var up := []   # footprints standing
	var bad := 0
	var work := 0
	for step in 60:
		var before: PackedByteArray = m.walks[0].duplicate()
		for change in 3:
			var roll := rng.range_int(0, 3 - 1)
			if roll == 0 or up.is_empty():
				var cx := 2 + rng.range_int(0, m.width - 6 - 1)
				var cy := 2 + rng.range_int(0, m.height - 6 - 1)
				var cells := PackedInt32Array()
				for y in range(cy, cy + 3):
					for x in range(cx, cx + 3):
						var c := y * m.width + x
						if not c in targets and m.occupied[c] == 0:
							cells.append(c)
				m.occupy(cells, 900 + step)
				up.append(cells)
			elif roll == 1:
				m.occupy(up.pop_front(), 0)
			else:
				var c: int = m.resource_cells[rng.range_int(0, m.resource_cells.size() - 1)]
				while m.amount[c] > 0:
					m.take(c)
		var opened := PackedInt32Array()
		var closed := PackedInt32Array()
		for c in m.width * m.height:
			if before[c] != m.walks[0][c]:
				(opened if m.walks[0][c] == 1 else closed).append(c)
		for e in fs:
			work += e[0].patch_closed(m, closed) if not closed.is_empty() else 0
			work += e[0].patch_opened(m, opened) if not opened.is_empty() else 0
	for k in fs.size():
		var f = fs[k][0]
		var cut: int = fs[k][1]
		var fresh = Flow.solve(m, PackedInt32Array([targets[k / 2]]), cut)
		for c in m.width * m.height:
			var a: int = f.dist[c]
			var b: int = fresh.dist[c]
			if (a <= cut or b <= cut) and a != b:
				bad += 1
			elif a > 0 and a <= cut and f.next[c] >= 0 and f.dist[f.next[c]] >= a:
				bad += 1
	check(bad == 0, "flow patch: fields patched through 180 closings and openings on the 2v2 map match fresh solves (%d cells off; %d cells of work)" % [bad, work])


# --- farms and placement -------------------------------------------------------

## One farmer per farm (data: the farm's "workers"): a second worker sent to a worked farm
## takes a free farm nearby (else other food, else waits by it); a farm its farmer leaves is
## picked up again, by a new order or by a worker waiting there.
func _test_one_farmer(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[1][0] = 1000
	var s: Array = w.map.starts[0]
	var tc := -1
	for b in w.buildings.count():
		if w.buildings.owner[b] == 0:
			tc = b
	for n in 3:
		Economy.spawn_at(w, tc, w.type_of(0, "worker"))
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0:
			ids.append(w.units.id[i])
	var field: int = w.map.terrain_ids.find("field")
	var a: int = (s[1] / 1000 + 2) * w.map.width + s[0] / 1000 + 3
	var b2 := -1   # a second farm beside it (3-5 tiles over, wherever there's room)
	var fk: int = Economy.btype_of(w, "farm")
	for d in [3, 4, 5, -3, -4, -5]:
		for c in [a + d, a + d * w.map.width]:
			if b2 < 0 and Economy.can_place(w, 0, fk, c % w.map.width, c / w.map.width):
				b2 = c
	check(b2 >= 0 and Economy.can_place(w, 0, fk, a % w.map.width, a / w.map.width), "one farmer: room for two farms")
	w.issue(0, Commands.BUILD, {"ids": [ids[0]], "building": "farm", "cx": a % w.map.width, "cy": a / w.map.width})
	while w.tick < 1600 and w.map.terrain[a] != field:
		w.step()
	w.issue(0, Commands.BUILD, {"ids": [ids[1]], "building": "farm", "cx": b2 % w.map.width, "cy": b2 / w.map.width})
	while w.tick < 3200 and w.map.terrain[b2] != field:
		w.step()
	check(w.map.terrain[a] == field and w.map.terrain[b2] == field, "one farmer: both farms are sown")
	var on := func(id: int, farm: int) -> bool:
		var i := w.units.index_of(id)
		var h: int = w.units.home[i]
		return w.units.task[i] in [Economy.GATHER, Economy.RETURN] and h >= 0 and w.map.pool[h] == farm
	check(on.call(ids[0], a) and on.call(ids[1], b2), "one farmer: each farm's builder farms it")
	var rival := -1
	for i in w.units.count():
		if rival < 0 and w.units.owner[i] == 1 and w.types[w.units.kind[i]].worker:
			rival = i
	check(Economy.taken(w, a, rival), "farms: a rival's worker can't work your farm")
	check(Economy.taken(w, a) and Economy.taken(w, a + 1), "one farmer: a worked farm is taken (any of its tiles)")
	# A third worker sent to the first farm doesn't join its farmer.
	w.issue(0, Commands.GATHER, {"ids": [ids[2]], "cell": a + 1})
	for t in 20:
		w.step()
	var i2 := w.units.index_of(ids[2])
	check(not on.call(ids[2], a) and not on.call(ids[2], b2) and w.units.task[i2] == Economy.GATHER,
		"one farmer: a second worker sent to a worked farm goes elsewhere (home %d)" % w.units.home[i2])
	# The second farmer walks off: the next worker sent to the first farm takes the freed one.
	w.issue(0, Commands.MOVE, {"ids": [ids[1]], "x": s[0] - 3000, "y": s[1]})
	w.issue(0, Commands.GATHER, {"ids": [ids[3]], "cell": a})
	for t in 20:
		w.step()
	check(on.call(ids[3], b2), "one farmer: a farm its farmer left is picked up by the next worker sent near it")
	check(on.call(ids[0], a), "one farmer: the first farm keeps its farmer")
	# With no free farm and no other food about, a worker waits by a full farm and takes it
	# once its farmer goes.
	var food: int = Economy.kind_of(w, "food")
	for c in w.map.resource_cells:
		if w.map.pool[c] < 0 and Economy.kind_of(w, w.map.resource_at(c)) == food:
			w.map.amount[c] = 0
	var i4 := w.units.index_of(ids[4])
	w.units.task[i4] = Economy.GATHER
	w.units.carry_kind[i4] = Economy.kind_of(w, "food")
	w.units.target[i4] = a
	w.units.home[i4] = -1
	for t in 40:
		w.step()
	check(not on.call(ids[4], a), "one farmer: a worker waiting by a worked farm doesn't join its farmer")
	w.issue(0, Commands.MOVE, {"ids": [ids[0]], "x": s[0] - 3000, "y": s[1] + 2000})
	for t in 40:
		w.step()
	check(on.call(ids[4], a), "one farmer: a worker waiting by a farm takes it when its farmer leaves")


## Auto-reseed (Dominic, 2026-10-13): on by default, a worked-out farm is sown again at once
## (for its reseed cost) and its farmer farms on; without the wood the farmer waits by it and it
## reseeds when the wood comes in; with it off, the farmer moves to a free farm nearby. Never off
## to other work. Every time, a farm_done event (the sound and the line).
func _test_auto_reseed(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[1][0] = 1000
	var s: Array = w.map.starts[0]
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0:
			ids.append(w.units.id[i])
	var field: int = w.map.terrain_ids.find("field")
	var fallow: int = w.map.terrain_ids.find("fallow")
	var a: int = (s[1] / 1000 + 2) * w.map.width + s[0] / 1000 + 3
	var fk: int = Economy.btype_of(w, "farm")
	var b2 := -1
	for d in [3, 4, 5, -3, -4, -5]:
		for c in [a + d, a + d * w.map.width]:
			if b2 < 0 and Economy.can_place(w, 0, fk, c % w.map.width, c / w.map.width):
				b2 = c
	w.issue(0, Commands.BUILD, {"ids": [ids[0]], "building": "farm", "cx": a % w.map.width, "cy": a / w.map.width})
	while w.tick < 1600 and w.map.terrain[a] != field:
		w.step()
	check(w.auto_reseed[0] == 1, "auto-reseed: on by default")
	var on := func(id: int, farm: int) -> bool:
		var i := w.units.index_of(id)
		var h: int = w.units.home[i]
		return w.units.task[i] in [Economy.GATHER, Economy.RETURN] and h >= 0 and w.map.pool[h] == farm
	var drain := func() -> Dictionary:   # nearly out; step until the farm_done event
		w.map.amount[a] = 1
		var t0 := w.tick
		while w.tick < t0 + 600:
			w.step()
			for e in w.events:
				if e.type == "farm_done":
					return e
		return {}
	var wood: int = w.stock[1][0]
	var e: Dictionary = drain.call()
	check(not e.is_empty() and e.player == 0 and e.building == w.map.occupied[a], "auto-reseed: a farm worked out sends a farm_done event")
	check(e.get("reseeded", false) and w.map.terrain[a] == field and w.map.left_at(a) > 0, "auto-reseed: the farm is sown again at once (%d food)" % w.map.left_at(a))
	check(wood - w.stock[1][0] == w.btypes[fk].reseed[1], "auto-reseed: it costs the reseed (%d wood)" % (wood - w.stock[1][0]))
	for t in 100:
		w.step()
	check(on.call(ids[0], a), "auto-reseed: the farmer farms on")
	# No wood: it lies fallow and the farmer waits by it (bugs close by or not), then the wood comes in.
	w.stock[1][0] = 0
	e = drain.call()
	check(not e.is_empty() and not e.reseeded and w.map.terrain[a] == fallow, "auto-reseed: without the wood it lies fallow")
	for t in 300:
		w.step()
	var i0 := w.units.index_of(ids[0])
	var near_farm: bool = absi(w.units.x[i0] / 1000 - a % w.map.width) <= 3 and absi(w.units.y[i0] / 1000 - a / w.map.width) <= 3
	check(on.call(ids[0], a) and w.units.carry[i0] == 0 and near_farm, "auto-reseed: its farmer waits by it, not off to other work (at %d,%d)" % [w.units.x[i0] / 1000, w.units.y[i0] / 1000])
	w.stock[1][0] = 100
	for t in Economy.WAIT_TICKS + 2:
		w.step()
	check(w.map.terrain[a] == field and w.stock[1][0] == 100 - w.btypes[fk].reseed[1], "auto-reseed: with the wood in, it's sown again")
	var food: int = w.stock[0][0]
	for t in 600:
		w.step()
	check(on.call(ids[0], a) and w.stock[0][0] > food, "auto-reseed: ...and farmed (%d -> %d food)" % [food, w.stock[0][0]])
	# Off, with a free farm nearby: the farmer moves over to it.
	w.issue(0, Commands.BUILD, {"ids": [ids[1]], "building": "farm", "cx": b2 % w.map.width, "cy": b2 / w.map.width})
	while w.tick < 6000 and w.map.terrain[b2] != field:
		w.step()
	w.issue(0, Commands.MOVE, {"ids": [ids[1]], "x": s[0] - 4000, "y": s[1]})
	w.issue(0, Commands.AUTO_RESEED, {"on": 0})
	for t in 12:
		w.step()
	check(w.auto_reseed[0] == 0, "auto-reseed: the player turns it off")
	e = drain.call()
	check(not e.is_empty() and not e.reseeded, "auto-reseed: off, the farm lies fallow")
	for t in 200:
		w.step()
	check(on.call(ids[0], b2), "auto-reseed: off, its farmer takes the free farm nearby")


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
	w.issue(0, Commands.AUTO_RESEED, {"on": 0})   # by hand here; auto-reseed has its own test
	for t in 12:
		w.step()
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
	_test_one_farmer(races)
	_test_auto_reseed(races)
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


## Fog memory: an enemy farm sown in the dark stays grass to you; once seen it's a field, and
## when you look away it stays as you last saw it (worked out, or torn down) until you look again.
func _test_fog_memory(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[1][1] = 1000
	var s: Array = w.map.starts[1]
	var worker := -1
	var scout := -1
	for i in w.units.count():
		if worker < 0 and w.units.owner[i] == 1:
			worker = w.units.id[i]
		if scout < 0 and w.units.owner[i] == 0:
			scout = w.units.id[i]
	var cx: int = s[0] / 1000 - 5
	var cy: int = s[1] / 1000 + 2
	var c: int = cy * w.map.width + cx
	var grass: int = w.map.terrain[c]
	w.issue(1, Commands.BUILD, {"ids": [worker], "building": "farm", "cx": cx, "cy": cy})
	var field: int = w.map.terrain_ids.find("field")
	while w.tick < 1600 and w.map.terrain[c] != field:
		w.step()
	for t in 5:
		w.step()   # the next fog update (every 4 ticks) sees the new crops
	var farm_id: int = w.map.occupied[c]
	check(w.map.terrain[c] == field, "fog memory: player 1's farm became a field")
	check(w.fog[0][c] == Fog.UNSEEN and w.fog_ground[0][c] == grass, "fog memory: player 0 hasn't seen it, so it's grass to them")
	check(not w.fog_seen[0].has(farm_id), "fog memory: nor does player 0 know the farm")
	check(w.fog_ground[1][c] == field and w.fog_left[1][c] > 0, "fog memory: its owner sees its crops")
	var home: Array = _at(w, scout)
	var si := w.units.index_of(scout)
	w.units.x[si] = cx * 1000 - 2000   # player 0's worker looks in
	w.units.y[si] = cy * 1000
	for t in 8:
		w.step()
	check(w.fog_ground[0][c] == field and w.fog_left[0][c] == w.map.left_at(c), "fog memory: seen, it's a field with its crops")
	check(w.fog_seen[0].has(farm_id), "fog memory: seen, player 0 knows the farm")
	si = w.units.index_of(scout)
	w.units.x[si] = home[0]   # and goes home
	w.units.y[si] = home[1]
	w.units.px[si] = home[0]
	w.units.py[si] = home[1]
	w.units.moving[si] = 0
	for t in 8:
		w.step()
	check(w.fog[0][c] == Fog.EXPLORED, "fog memory: away again, the farm is under explored fog")
	var seen_left: int = w.fog_left[0][c]
	w.auto_reseed[1] = 0   # left fallow (auto-reseed would sow it again at once)
	w.map.amount[c] = 1   # nearly worked out
	while w.tick < 6000 and w.map.left_at(c) > 0:
		w.step()
	var fallow: int = w.map.terrain_ids.find("fallow")
	check(w.map.terrain[c] == fallow, "fog memory: the farm is worked out")
	check(w.fog_ground[0][c] == field and w.fog_left[0][c] == seen_left, "fog memory: player 0 still remembers it full of crops")
	var b := w.buildings.index_of(farm_id)   # torn down out of sight
	Economy.clear_farm(w, b)
	w.map.occupy(w.buildings.footprint(b, w.map.width), 0)
	w.buildings.remove_at(b)
	for t in 8:
		w.step()
	check(w.fog_seen[0].has(farm_id) and w.fog_ground[0][c] == field, "fog memory: gone out of sight, player 0 still remembers the farm")
	si = w.units.index_of(scout)
	w.units.x[si] = cx * 1000 - 2000
	w.units.y[si] = cy * 1000
	for t in 8:
		w.step()
	check(not w.fog_seen[0].has(farm_id) and w.fog_ground[0][c] == grass, "fog memory: seen again, it's gone and the ground is grass")


# --- ages and research ----------------------------------------------------------

## Milestone 7's exit criterion: with the economy bot playing, the age-up lands at
## minutes 4-6 for both frogs and rats; 4-7 (ticks 4800-8400) since workers cost at
## least 50 food (rules.cost.roles), which put the frogs' at ~6:15 (from ~5:30).
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
		check(at[p] >= 4800 and at[p] <= 8400, "age-up at minutes 4-7: %s at tick %d" % [w.races[p].name, at[p]])

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


## Claimed sheep (Dominic's playtest, 2026-10-13): each walks to one pen by its owner's Town
## Center and stops there for good, forgetting what its old owner told it; a sheep takes no
## fighting orders (no attack, no stance; an attack-move just walks it); a worker slaughters
## one in a few blows, a deer still takes a few more and a boar gets no such help.
func _test_sheep_spot(races: Array) -> void:
	var rules := rules_.duplicate(true)
	rules.animals = true
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	var s0: Array = w.map.starts[0]
	var sheep := []
	var worker := -1
	for i in w.units.count():
		if w.units.owner[i] == w.gaia and w.types[w.units.kind[i]].animal == "sheep" and absi(w.units.x[i] - s0[0]) + absi(w.units.y[i] - s0[1]) < 15000:
			sheep.append(w.units.id[i])
		if worker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			worker = w.units.id[i]
	var first := w.units.index_of(sheep[0])
	w.units.orders[first] = [{"type": Commands.MOVE, "args": {"x": 1000, "y": 1000}}]   # an order left over from before
	for id in sheep:
		var si := w.units.index_of(id)
		w.issue(0, Commands.MOVE, {"ids": [worker], "x": w.units.x[si], "y": w.units.y[si], "queue": 1})
	for t in 2400:
		w.step()
	var tc := -1
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0 and w.btypes[w.buildings.kind[b]].id == "town_center":
			tc = b
	var pen: Array = w.herd_spots.get(w.buildings.id[tc], [])
	var penned := 0
	var still := 0
	var forgot := true
	for id in sheep:
		var si := w.units.index_of(id)
		if si >= 0 and w.units.owner[si] == 0 and not pen.is_empty() and Fixed.dist2(w.units.x[si], w.units.y[si], pen[0], pen[1]) <= 1800 * 1800:
			penned += 1
		if si >= 0 and w.units.moving[si] == 0:
			still += 1
		if si >= 0 and not w.units.orders[si].is_empty():
			forgot = false
	check(sheep.size() == 4 and penned == 4, "sheep: with no pen, every claimed sheep gathers at one spot by the Town Center (%d of %d)" % [penned, sheep.size()])
	check(still == 4 and forgot, "sheep: ... and stands there, its old owner's orders forgotten")
	var bx: int = w.buildings.cx[tc] * 1000 + 1500
	var by: int = w.buildings.cy[tc] * 1000 + 1500
	check(not pen.is_empty() and maxi(absi(pen[0] - bx), absi(pen[1] - by)) >= 3000, "sheep: the pen is beside the Town Center, not inside it")
	var x0: int = w.units.x[first]
	var y0: int = w.units.y[first]
	for t in 1200:
		w.step()
	check(w.units.x[first] == x0 and w.units.y[first] == y0, "sheep: ... for good (no wandering a minute later)")
	# No fighting orders for a sheep: an attack and a stance do nothing, an attack-move only walks it.
	var foe := -1
	for i in w.units.count():
		if foe < 0 and w.units.owner[i] == 1:
			foe = w.units.id[i]
	w.issue(0, Commands.ATTACK, {"ids": [sheep[0]], "target": foe})
	w.issue(0, Commands.STANCE, {"ids": [sheep[0]], "stance": "passive"})
	for t in 20:
		w.step()
	first = w.units.index_of(sheep[0])
	check(w.units.foe[first] == 0 and w.units.posture[first] == Combat.AGGRESSIVE, "sheep: no attack orders, no stances")
	w.issue(0, Commands.ATTACK_MOVE, {"ids": [sheep[0]], "x": x0 + 3000, "y": y0})
	for t in 20:
		w.step()
	first = w.units.index_of(sheep[0])
	check(w.units.stance[first] == Combat.NONE and w.units.moving[first] == 1, "sheep: an attack-move just walks it")
	# One worker slaughters a sheep in a few blows.
	var blows := 0
	w.issue(0, Commands.ATTACK, {"ids": [worker], "target": sheep[1]})
	for t in 1200:
		w.step()
		for e in w.events:
			if e.type == "hit" and e.to == sheep[1]:
				blows += 1
		if w.units.index_of(sheep[1]) < 0:
			break
	check(w.units.index_of(sheep[1]) < 0 and blows <= 3, "sheep: a worker slaughters one in a few blows (%d)" % blows)
	# A deer takes more (it's harmless too, but bigger); a boar fights at full armour.
	var deer_t: Dictionary = w.types[Animals.type_of(w, "deer")]
	var boar_t: Dictionary = w.types[Animals.type_of(w, "boar")]
	var wt: Dictionary = w.types[w.units.kind[w.units.index_of(worker)]]
	var c: Dictionary = w.combat
	var to_deer := Combat.damage(wt.atk, deer_t.arm, deer_t.cls, maxi(int(c.min_damage), deer_t.min_damage))
	check(deer_t.hp / to_deer >= 5, "sheep: a deer still takes a worker %d blows" % (deer_t.hp / to_deer))
	check(boar_t.min_damage == 0 and not boar_t.harmless, "sheep: a boar gets no slaughter rule and fights back")


## Pens (Dominic, 2026-10-13: the long-term alternative to slaughter): claimed sheep go into
## their owner's pen; penned ones add food with no worker (exactly pen.food per animal every
## pen.food_every s, up to the cap), two or more breed up to the cap, a rival outside the pen
## can't steal them but takes them once it's torn down, and Release walks them out.
func _test_pen(races: Array) -> void:
	var rules := rules_.duplicate(true)
	rules.animals = true
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	var s0: Array = w.map.starts[0]
	var tc := -1
	for b in w.buildings.count():
		if tc < 0 and w.buildings.owner[b] == 0:
			tc = b
	var k: int = Economy.btype_of(w, "pen")
	var p: Dictionary = w.btypes[k].pen
	var spot := _pen_spot(w, tc)
	var pb := Economy.place(w, 0, k, spot.x, spot.y, 0)
	w.buildings.done[pb] = 1
	w.buildings.hp[pb] = w.btypes[k].hp
	Pens.opened(w, pb)
	var pen_id: int = w.buildings.id[pb]
	var sheep := []
	var worker := -1
	for i in w.units.count():
		if w.units.owner[i] == w.gaia and w.types[w.units.kind[i]].animal == "sheep" and absi(w.units.x[i] - s0[0]) + absi(w.units.y[i] - s0[1]) < 15000:
			sheep.append(w.units.id[i])
		if worker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			worker = w.units.id[i]
	for id in sheep:
		var si := w.units.index_of(id)
		w.issue(0, Commands.MOVE, {"ids": [worker], "x": w.units.x[si], "y": w.units.y[si], "queue": 1})
	for t in 2400:
		w.step()
	pb = w.buildings.index_of(pen_id)
	var penned := Pens.animals(w, pb, true).size()
	check(penned == 4, "pen: claimed sheep walk into their owner's pen (%d of 4)" % penned)
	# The trickle: exactly food per animal every food_ticks, with nobody gathering.
	var food: int = w.resources.find("food")
	var t0: int = w.tick
	var before: int = w.stock[food][0]
	for t in 1200:
		w.step()
	var want: int = 4 * int(p.food) * ((w.tick - 1) / int(p.food_ticks) - (t0 - 1) / int(p.food_ticks))
	check(w.stock[food][0] - before == want, "pen: 4 penned sheep bring in %d food a minute (%d)" % [want, w.stock[food][0] - before])
	# Breeding: by the next breeding beat there's a lamb.
	while w.tick % int(p.breed_ticks) != 1:
		w.step()
	pb = w.buildings.index_of(pen_id)
	check(Pens.animals(w, pb).size() == 5, "pen: two or more breed (%d now)" % Pens.animals(w, pb).size())
	# The cap: more than it holds are there, but only the cap is paid for, and none are born.
	for n in 6:
		Pens._born(w, pb, Pens.animals(w, pb)[0])
	for t in 600:
		w.step()
	pb = w.buildings.index_of(pen_id)
	var inside: int = Pens.animals(w, pb, true).size()
	t0 = w.tick
	before = w.stock[food][0]
	for t in int(p.food_ticks):
		w.step()
	check(inside > int(p.animals) and w.stock[food][0] - before == int(p.animals) * int(p.food) and not Pens.room(w, pb),
		"pen: it pays for its cap (%d) and no more (%d inside, +%d food)" % [p.animals, inside, w.stock[food][0] - before])
	# Release: they walk out and stand in front of it.
	var w2 := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	# (the rest on this world) A rival next to the pen, outside it, steals nothing while it stands...
	for i in w.units.count():
		if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].has("animal"):
			w.units.x[i] = 2000
			w.units.y[i] = 2000
			w.units.moving[i] = 0
			w.units.task[i] = Economy.NONE
	var c := Pens.centre(w, pb)
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 4, "x": c[0], "y": c[1] - 2600})
	for t in 200:
		w.step()
	var theirs := func() -> int:
		var n := 0
		for i in w.units.count():
			if w.units.owner[i] == 1 and w.types[w.units.kind[i]].get("animal", "") == "sheep":
				n += 1
		return n
	check(theirs.call() == 0, "pen: a rival outside the pen steals nothing")
	# ...but tear it down and the sheep spill out to them.
	var spears := []
	for i in w.units.count():
		if w.units.owner[i] == 1 and w.types[w.units.kind[i]].slot == "spear":
			spears.append(w.units.id[i])
	w.issue(1, Commands.ATTACK, {"ids": spears, "target": pen_id})
	for t in 3000:
		w.step()
		if w.buildings.index_of(pen_id) < 0 and theirs.call() > 0:
			break
	check(w.buildings.index_of(pen_id) < 0 and theirs.call() > 0, "pen: torn down, its sheep are stolen (%d)" % theirs.call())
	check(w.map.walk_over[w.map.cell_of(c[0], c[1])] == 0, "pen: torn down, its ground is plain again")
	# Release on a fresh world: a pen, a sheep in it, then Release: it walks out.
	var tc2 := -1
	for b in w2.buildings.count():
		if tc2 < 0 and w2.buildings.owner[b] == 0:
			tc2 = b
	var spot2 := _pen_spot(w2, tc2)
	var pb2 := Economy.place(w2, 0, k, spot2.x, spot2.y, 0)
	w2.buildings.done[pb2] = 1
	Pens.opened(w2, pb2)
	var one := -1
	for i in w2.units.count():
		if one < 0 and w2.units.owner[i] == w2.gaia and w2.types[w2.units.kind[i]].get("animal", "") == "sheep":
			one = w2.units.id[i]
			w2.units.owner[i] = 0
	w2.issue(0, Commands.PEN, {"ids": [one], "building": w2.buildings.id[pb2]})
	for t in 1600:
		w2.step()
	var in_before := Pens.animals(w2, w2.buildings.index_of(w2.buildings.id[pb2]), true).size()
	w2.issue(0, Commands.RELEASE, {"building": w2.buildings.id[pb2]})
	for t in 600:
		w2.step()
	check(in_before == 1 and Pens.animals(w2, pb2, true).is_empty() and Pens.pen_at(w2, w2.units.index_of(one)) < 0,
		"pen: Release walks its animals out (%d in, then %d)" % [in_before, Pens.animals(w2, pb2, true).size()])


## Somewhere a pen may go near Town Center building tc: the first open 3 x 3 (with a tile of
## room round it) west of it, then further out.
## Garrisons (milestone 12 phase 3): workers go into their Town Center, out of the units arrays
## (pop still counts them), heal, and each adds an arrow (the Town Center shoots only with people
## inside); ungarrison brings them back with their ids and health; the call to arms and back to
## work; a building that falls spills its people out; the same commands give the same hashes.
func _test_garrison(races: Array) -> void:
	var a := _garrison_run(races, true)
	var b := _garrison_run(races, false)
	check(a.state_hash() == b.state_hash(), "garrison: the same commands give the same state hash")


## The garrison checks, run on a fresh world; `checks_on`: make the checks (else just play the same).
func _garrison_run(races: Array, checks_on: bool) -> World:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var tc_id: int = w.buildings.id[0]
	var tc := w.buildings.index_of(tc_id)
	var s: Array = w.map.starts[0]
	var workers := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			workers.append(w.units.id[i])
	var c := func(ok: bool, what: String) -> void:
		if checks_on:
			check(ok, what)
	# An enemy spearman beside the Town Center, told never to fight.
	var foe := _spawn_at(w, 1, "spear", s[0] + 2600, s[1])
	w.issue(1, Commands.STANCE, {"ids": [foe], "stance": "passive"})
	var shots := func(ticks: int) -> Array:   # hits by the Town Center per volley, over some ticks
		var out := []
		for t in ticks:
			w.step()
			var n := 0
			for e in w.events:
				if e.type == "shot" and e.by == tc_id:
					n += 1
			if n > 0:
				out.append(n)
		return out
	c.call(shots.call(120).is_empty(), "garrison: an empty Town Center doesn't shoot")
	var pop: int = w.pop[0]
	w.issue(0, Commands.GARRISON, {"ids": workers.slice(0, 3), "building": tc_id})
	for t in 300:
		w.step()
		if w.buildings.inside[tc].size() == 3:
			break
	c.call(w.buildings.inside[tc].size() == 3, "garrison: three workers go into the Town Center (%d)" % w.buildings.inside[tc].size())
	c.call(workers.slice(0, 3).all(func(id): return w.units.index_of(id) < 0), "garrison: those inside are out of the units (no sight, no target)")
	w.step()
	c.call(w.pop[0] == pop, "garrison: pop still counts them (%d, was %d)" % [w.pop[0], pop])
	var volleys: Array = shots.call(200)
	c.call(not volleys.is_empty() and volleys.all(func(n): return n == 3), "garrison: three inside, three arrows a volley (%s)" % [volleys])
	# Healing inside: 1 hp every heal_every ticks.
	var rec: PackedInt32Array = w.buildings.inside[tc][0]
	rec[Garrison.REC_HP] = 5
	w.buildings.inside[tc][0] = rec
	for t in 200:
		w.step()
	var healed: int = w.buildings.inside[tc][0][Garrison.REC_HP]
	c.call(healed >= 5 + 200 / int(w.garrison_cfg.heal_every) - 1, "garrison: those inside heal slowly (5 -> %d)" % healed)
	# Ungarrison: out again, the same ids and health, beside the Town Center.
	var hurt_id: int = w.buildings.inside[tc][0][Garrison.REC_ID]
	w.issue(0, Commands.UNGARRISON, {"building": tc_id})
	for t in 12:
		w.step()
	c.call(w.buildings.inside[tc].is_empty() and workers.slice(0, 3).all(func(id): return w.units.index_of(id) >= 0),
		"garrison: ungarrison brings everyone out under their own ids")
	var hi := w.units.index_of(hurt_id)
	c.call(hi >= 0 and absi(w.units.hp[hi] - healed) <= 1, "garrison: ... with the health they had inside (%d)" % (w.units.hp[hi] if hi >= 0 else -1))
	var r := Economy._building_rect(w, tc)
	var gap := maxi(maxi(r.position.x - w.units.x[hi], w.units.x[hi] - r.end.x), maxi(r.position.y - w.units.y[hi], w.units.y[hi] - r.end.y)) if hi >= 0 else 9999
	c.call(gap < 1500, "garrison: ... standing beside it (%d from its wall)" % gap)
	# Call to arms: every worker near the Town Center goes in (gathering first, so back to work has a job).
	var bush := _nearest_resource(w.map, s, "food")
	var kind := Economy.kind_of(w, "food")
	w.issue(0, Commands.GATHER, {"ids": workers, "cell": bush})
	for t in 300:
		w.step()
	w.issue(0, Commands.CALL_TO_ARMS, {"building": tc_id})
	for t in 600:
		w.step()
		if w.buildings.inside[tc].size() == workers.size():
			break
	c.call(w.buildings.inside[tc].size() == workers.size(), "garrison: the call to arms sends every worker nearby inside (%d of %d)" % [w.buildings.inside[tc].size(), workers.size()])
	w.issue(0, Commands.BACK_TO_WORK, {})
	for t in 12:
		w.step()
	var back := workers.filter(func(id):
		var i := w.units.index_of(id)
		return i >= 0 and (w.units.task[i] == Economy.GATHER or w.units.task[i] == Economy.RETURN) and w.units.carry_kind[i] == kind)
	c.call(back.size() == workers.size(), "garrison: back to work: every worker out and gathering again (%d of %d)" % [back.size(), workers.size()])
	# A tower that falls spills its people out (and holds no more than it takes).
	var more := _spawn_at(w, 0, "worker", s[0] + 3000, s[1] - 3000)
	for n in 3:
		workers.append(_spawn_at(w, 0, "worker", s[0] + 3000, s[1] - 3000))
	workers.append(more)
	var ts := _free_spot(w, Economy.btype_of(w, "watchtower"), Vector2i(s[0] / 1000 + 5, s[1] / 1000 - 5))
	var tower := _put(w, 0, "watchtower", ts.x, ts.y)
	w.issue(0, Commands.GARRISON, {"ids": workers.slice(0, 2), "building": tower})
	for t in 400:
		w.step()
		if w.buildings.inside[w.buildings.index_of(tower)].size() == 2:
			break
	var tb := w.buildings.index_of(tower)
	c.call(w.buildings.inside[tb].size() == 2, "garrison: two workers go into a watchtower (%d)" % w.buildings.inside[tb].size())
	w.issue(0, Commands.GARRISON, {"ids": workers.slice(2), "building": tower})
	for t in 400:
		w.step()
	tb = w.buildings.index_of(tower)
	var cap: int = w.btypes[w.buildings.kind[tb]].garrison
	c.call(w.buildings.inside[tb].size() == cap, "garrison: a watchtower holds %d, no more (%d)" % [cap, w.buildings.inside[tb].size()])
	var held: Array = w.buildings.inside[tb].map(func(r): return r[Garrison.REC_ID])
	w.buildings.hp[tb] = 1
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 6, "x": (ts.x + 3) * 1000, "y": ts.y * 1000 + 500})
	for t in 12:
		w.step()
	var killers := []
	for i in w.units.count():
		if w.units.owner[i] == 1 and w.types[w.units.kind[i]].slot == "spear":
			killers.append(w.units.id[i])
	w.issue(1, Commands.ATTACK, {"ids": killers, "target": tower})
	for t in 400:
		w.step()
		if w.buildings.index_of(tower) < 0:
			break
	c.call(w.buildings.index_of(tower) < 0, "garrison: the enemy knocks the tower down")
	c.call(held.all(func(id): return w.units.index_of(id) >= 0), "garrison: ... and its people spill out alive")
	return w


## Towers (milestone 12 phase 3): the Outpost sees further than a house and doesn't shoot; the
## Bastion research turns every Watchtower into a Bastion in place, keeping its share of health
## and its people; after it a Watchtower ordered is a Bastion; a second Town Center from age 3.
func _test_towers(races: Array) -> void:
	var w := _bare_world(races)
	_put(w, 0, "house", 10, 10)
	w.step()
	var seen_house := _visible_cells(w, 0)
	var w2 := _bare_world(races)
	_put(w2, 0, "outpost", 10, 10)
	w2.step()
	check(_visible_cells(w2, 0) > seen_house * 5 / 2, "towers: an outpost sees far (%d cells, a house %d; swamp frogs' buildings see 2 further)" % [_visible_cells(w2, 0), seen_house])
	check(w2.btypes[Economy.btype_of(w2, "outpost")].attack.is_empty() and w2.btypes[Economy.btype_of(w2, "outpost")].garrison == 0,
		"towers: an outpost doesn't shoot, and nobody goes in")

	w = World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in w.resources.size():
		w.stock[r][0] = 5000
	var s: Array = w.map.starts[0]
	var wt := Economy.btype_of(w, "watchtower")
	var bk := Economy.btype_of(w, "bastion")
	var t1 := _put(w, 0, "watchtower", s[0] / 1000 + 5, s[1] / 1000 - 5)
	var t2 := _put(w, 1, "watchtower", s[0] / 1000 + 7, s[1] / 1000 - 5)   # the rival's stays a watchtower
	var b1 := w.buildings.index_of(t1)
	w.buildings.hp[b1] = w.btypes[wt].hp / 2
	w.buildings.inside[b1].append(PackedInt32Array([999999, w.type_of(0, "worker"), 10, 0, 0, 0, -1]))
	_give(w, 0, "bastion")
	b1 = w.buildings.index_of(t1)
	check(w.buildings.kind[b1] == bk, "towers: the Bastion research makes the watchtower a bastion where it stands")
	check(absi(w.buildings.hp[b1] - w.btypes[bk].hp / 2) <= 1, "towers: ... keeping its share of health (%d of %d)" % [w.buildings.hp[b1], w.btypes[bk].hp])
	check(w.buildings.inside[b1].size() == 1, "towers: ... and the people inside")
	check(w.buildings.kind[w.buildings.index_of(t2)] == wt, "towers: a rival's watchtower stays one")
	check(w.btypes[bk].hp > w.btypes[wt].hp and int(w.btypes[bk].attack.attack) > int(w.btypes[wt].attack.attack)
		and int(w.btypes[bk].attack.range) > int(w.btypes[wt].attack.range), "towers: a bastion has more health, attack and range")
	w.buildings.inside[b1].clear()
	w.ages[0] = 3
	var worker := -1
	for i in w.units.count():
		if worker < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			worker = w.units.id[i]
	var spot := _free_spot(w, bk, Vector2i(s[0] / 1000 - 5, s[1] / 1000 + 5))
	w.issue(0, Commands.BUILD, {"ids": [worker], "building": "watchtower", "cx": spot.x, "cy": spot.y})
	for t in 12:
		w.step()
	var nb := w.buildings.index_of(w.map.occupied[spot.y * w.map.width + spot.x])
	check(nb >= 0 and w.buildings.kind[nb] == bk, "towers: after the research a watchtower ordered is a bastion")
	# More Town Centers: not in age 1 while one stands; from age 3, for wood and stone.
	var tck := Economy.btype_of(w, "town_center")
	w.ages[0] = 1
	check(Economy.why_not_build(w, 0, tck) != "", "towers: no second Town Center in age 1")
	w.ages[0] = 3
	check(Economy.why_not_build(w, 0, tck) == "", "towers: a second Town Center from age 3")
	check(w.btypes[tck].cost[w.resources.find("stone")] > 0 and w.btypes[tck].cost[w.resources.find("wood")] > 0, "towers: it costs wood and stone")
	var stone: int = w.stock[w.resources.find("stone")][0]
	var tspot := _free_spot(w, tck, Vector2i(s[0] / 1000 + 6, s[1] / 1000 + 4))
	w.issue(0, Commands.BUILD, {"ids": [worker], "building": "town_center", "cx": tspot.x, "cy": tspot.y})
	for t in 12:
		w.step()
	check(w.stock[w.resources.find("stone")][0] < stone, "towers: ... and one is laid down, paid in stone")


## The open spot for a building of type k nearest `at` (rings outwards), for test setups.
func _free_spot(w: World, k: int, at: Vector2i) -> Vector2i:
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and Economy.can_place(w, 0, k, at.x + dx, at.y + dy):
					return at + Vector2i(dx, dy)
	assert(false, "No room near %s" % at)
	return at


func _pen_spot(w, tc: int) -> Vector2i:
	var cx: int = w.buildings.cx[tc]
	var cy: int = w.buildings.cy[tc]
	for r in range(5, 12):
		for dy in range(-r, r + 1):
			if w.map.can_build(cx - r - 1, cy + dy - 1, 5):
				return Vector2i(cx - r, cy + dy)
	assert(false, "no room for a pen")
	return Vector2i(-1, -1)


## The economy bot herds and hunts (Dominic: "bot should hunt too"): it claims its sheep and
## pens them (a pen it builds for them; it keeps penned sheep rather than slaughter them), hunts
## a deer that's near home and takes on a boar once it has workers to spare; the hunters gather
## the meat.
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
	var penned := 0
	for b in w.buildings.count():
		if w.buildings.owner[b] == 0 and Pens.is_pen(w, b) and w.buildings.done[b] == 1:
			penned += Pens.animals(w, b, true).size()
	print("  bot hunting, first 7 minutes: %s, the last of each at %s; %d sheep penned" % [killed, when, penned])
	check(penned >= 2 and killed.get("sheep", 0) >= 1, "bot hunts: it slaughters its first sheep, then builds a pen and pens the rest (%d slaughtered, %d penned)" % [killed.get("sheep", 0), penned])
	check(killed.get("deer", 0) >= 1, "bot hunts: ... a deer near home (%d)" % killed.get("deer", 0))
	check(killed.get("boar", 0) >= 1, "bot hunts: ... and its boar, with a big party (%d)" % killed.get("boar", 0))
	# (three since pens: with no sheep to butcher the bot takes the boar on two minutes sooner, and one more hunter may fall)
	check(w.lost[0] <= 3, "bot hunts: ... losing no more than a few hunters to it (%d lost)" % w.lost[0])
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


## Builders never wander off (Dominic: "one of my builders disappeared into the fog of war"): a
## gatherer sent to build goes back to what it gathered when done, not to a foundation of yours
## across the map; a builder with nothing to go back to stays by its building.
func _test_builder_back_to_work(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[w.resources.find("wood")][0] = 1000
	var ws := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			ws.append(w.units.id[i])
	var s: Array = w.map.starts[0]
	var wood := Economy.kind_of(w, "wood")
	var a: int = w.units.index_of(ws[0])
	var tree := Economy.nearest_resource(w, w.units.x[a], w.units.y[a], wood, a)
	w.issue(0, Commands.GATHER, {"ids": [ws[0]], "cell": tree})
	for t in 200:
		w.step()
	a = w.units.index_of(ws[0])
	var home: int = w.units.home[a]
	check(home >= 0 and w.units.task[a] in [Economy.GATHER, Economy.RETURN], "builders: a woodcutter at work before building (task %d)" % w.units.task[a])
	var hk := Economy.btype_of(w, "house")
	var near := Vector2i(-1, -1)   # a house near the woodcutter's tree
	var tx: int = home % w.map.width
	var ty: int = home / w.map.width
	for r in range(2, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if near.x < 0 and Economy.can_place(w, 0, hk, tx + dx, ty + dy):
					near = Vector2i(tx + dx, ty + dy)
	var far := Vector2i(-1, -1)    # and one beyond NEXT_BUILD_TILES of it
	for r in range(Economy.NEXT_BUILD_TILES + 3, Economy.NEXT_BUILD_TILES + 9):
		for dx in [-r, r]:
			if far.x < 0 and Economy.can_place(w, 0, hk, near.x + dx, near.y):
				far = Vector2i(near.x + dx, near.y)
	check(near.x >= 0 and far.x >= 0, "builders: room for the test's houses")
	w.issue(0, Commands.BUILD, {"ids": [ws[0]], "building": "house", "cx": near.x, "cy": near.y})
	w.issue(0, Commands.BUILD, {"ids": [ws[1]], "building": "house", "cx": far.x, "cy": far.y})
	for t in 16:
		w.step()
	w.issue(0, Commands.MOVE, {"ids": [ws[1]], "x": s[0], "y": s[1]})   # walks off: the far house stays a foundation
	var done := false
	for t in 2000:
		w.step()
		done = _house_done(w, near)
		if done:
			break
	for t in 40:
		w.step()
	a = w.units.index_of(ws[0])
	check(done, "builders: the house near the woodcutter goes up")
	check(w.units.task[a] in [Economy.GATHER, Economy.RETURN] and w.units.carry_kind[a] == wood,
		"builders: done, the woodcutter goes back to its wood (task %d), not to the foundation %d tiles off" % [w.units.task[a], absi(far.x - near.x)])
	# A builder with nothing gathered before, done far from any foundation: it stays by the building.
	w.issue(0, Commands.STOP, {"ids": [ws[2]]})
	for t in 12:
		w.step()
	var spot2 := Vector2i(-1, -1)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			if spot2.x < 0 and absi(dx) + absi(dy) >= 4 and absi(s[0] / 1000 + dx - far.x) > Economy.NEXT_BUILD_TILES + 2 \
					and Economy.can_place(w, 0, hk, s[0] / 1000 + dx, s[1] / 1000 + dy):
				spot2 = Vector2i(s[0] / 1000 + dx, s[1] / 1000 + dy)
	w.issue(0, Commands.BUILD, {"ids": [ws[2]], "building": "house", "cx": spot2.x, "cy": spot2.y})
	var finished := -1
	for t in 2500:
		w.step()
		if finished < 0 and _house_done(w, spot2):
			finished = w.tick
		elif finished >= 0 and w.tick > finished + 200:
			break
	var c: int = w.units.index_of(ws[2])
	var d: int = Fixed.isqrt(Fixed.dist2(w.units.x[c], w.units.y[c], spot2.x * 1000 + 1000, spot2.y * 1000 + 1000))
	check(finished >= 0 and w.units.task[c] == Economy.NONE and d < 3000,
		"builders: with nothing to go back to and no foundation near, it stays by the building (task %d, %d milli-tiles off)" % [w.units.task[c], d])


func _house_done(w: World, at: Vector2i) -> bool:
	for b in w.buildings.count():
		if w.buildings.owner[b] == 0 and w.buildings.cx[b] == at.x and w.buildings.cy[b] == at.y:
			return w.buildings.done[b] == 1
	return false


## A worker's own picks (another tree when its tree falls, the nearest wood after a camp) are
## only ever tiles its owner has seen: it never walks off into the unexplored on its own.
func _test_no_dark_picks(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	var wi := -1
	for i in w.units.count():
		if wi < 0 and w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			wi = i
	var wood := Economy.kind_of(w, "wood")
	var x: int = w.units.x[wi]
	var y: int = w.units.y[wi]
	var seen := Economy.nearest_resource(w, x, y, wood, wi, false, false, true)
	check(seen >= 0 and w.fog[0][seen] != 0, "dark picks: the nearest wood a worker picks is on explored ground")
	var anywhere := Economy.nearest_resource(w, x, y, wood)
	for c in w.map.width * w.map.height:   # forget everything
		w.fog[0][c] = 0
	var got := Economy.nearest_resource(w, x, y, wood, wi, false, false, true)
	check(got == -1, "dark picks: with nothing explored, no wood is picked (%d)" % got)
	check(anywhere >= 0 and Economy.nearest_resource(w, x, y, wood, wi) == anywhere, "dark picks: ... while a pick near where it was sent may still be there (the player sent it)")


## Woodcutters stand at the forest edge, a tree and a side spot each (Dominic: three on one spot,
## one reaching for a tree behind another): sent together to one tree, they spread along the edge,
## each beside its own tree on open ground, never at a tree with no open side.
func _test_wood_spots(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("old_forest"), races, rules_)
	var worker: int = w.type_of(0, "worker")
	var ids := []
	while ids.size() < 7:
		ids = []
		for i in w.units.count():
			if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
				ids.append(w.units.id[i])
		if ids.size() < 7:
			Economy.spawn_at(w, 0, worker)
	var m := w.map
	var tree := 13 * m.width + 29   # the west edge of the wood east of the start
	check(m.resource_at(tree) == "wood", "wood spots: the test's tree is a tree (%s)" % m.resource_at(tree))
	w.issue(0, Commands.GATHER, {"ids": ids, "cell": tree})
	var bad := 0
	var shared := 0
	var at_work := 0
	for t in 1200:
		w.step()
		if t < 300 or t % 20 != 0:
			continue
		var held := {}
		for id in ids:
			var i: int = w.units.index_of(id)
			var h: int = w.units.home[i]
			if h < 0 or w.units.task[i] != Economy.GATHER:
				continue
			var open := false
			for k in [[0, -1], [1, 0], [0, 1], [-1, 0]]:
				open = open or m.cell_walkable(h % m.width + k[0], h / m.width + k[1], w.lane(i))
			if not open or w.units.gspot[i] % 2 == 1:
				bad += 1   # a tree with no open side, or a corner spot: reaching past a tree
			var key: int = h * 8 + w.units.gspot[i]
			if w.units.gspot[i] >= 0 and held.has(key):
				shared += 1
			held[key] = true
			if w.units.moving[i] == 0:
				at_work += 1
	var got: int = w.gathered[w.resources.find("wood")][0]
	check(bad == 0, "wood spots: woodcutters only work trees with an open side, from a side (%d bad samples)" % bad)
	check(shared == 0, "wood spots: no two woodcutters hold the same spot (%d)" % shared)
	check(at_work > 0 and got >= 60, "wood spots: they get to work (%d samples) and wood comes in (%d)" % [at_work, got])


## A long shift-queue of builds (a dragged wall) all goes up: taking the next order from a
## unit's queue must not wipe the rest of it (it did: only two of seven walls were built).
func _test_build_queue(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	w.stock[w.resources.find("stone")][0] = 500
	w.ages[0] = 2   # (a palisade: the swamp folk build no stone walls, milestone 14)
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0:
			ids.append(w.units.id[i])
	var s: Array = w.map.starts[0]
	for k in 7:
		w.issue(0, Commands.BUILD, {"ids": ids, "building": "palisade", "cx": s[0] / 1000 + 3, "cy": s[1] / 1000 - 3 + k, "queue": 1 if k > 0 else 0})
	for t in 16:   # past the command delay: every queued foundation is down already, so you see the plan
		w.step()
	var laid := 0
	for b in w.buildings.count():
		if w.btypes[w.buildings.kind[b]].id == "palisade":
			laid += 1
	check(laid == 7, "shift-queued builds: all 7 foundations are laid at once (%d)" % laid)
	for t in 3000:
		w.step()
	var done := 0
	for b in w.buildings.count():
		if w.btypes[w.buildings.kind[b]].id == "palisade":
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
func _put(w: World, p: int, id: String, cx: int, cy: int, along := 0) -> int:
	var k := Economy.btype_of(w, id)
	var b := Economy.place(w, p, k, cx, cy, along)
	w.buildings.done[b] = 1
	w.buildings.hp[b] = w.btypes[k].hp
	return w.buildings.id[b]


## A closed square of palisade on flat_test (tiles 12..20 by 18..26) with player 0's gate in
## its east side, three tiles along y at (20, 21..23). Inside is 13..19 by 19..25. Returns [world, gate id].
func _gate_world(races: Array, teams := []) -> Array:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, bare, teams)
	for k in range(12, 21):
		for c in [Vector2i(k, 18), Vector2i(k, 26), Vector2i(12, k + 6), Vector2i(20, k + 6)]:
			if w.map.occupied[c.y * w.map.width + c.x] == 0 and not (c.x == 20 and c.y >= 21 and c.y <= 23):
				_put(w, 0, "palisade", c.x, c.y)
	check(w.map.walks.size() == 3, "gates: without a gate the map keeps one walk grid per movement class (%d)" % w.map.walks.size())
	var gate := _put(w, 0, "palisade_gate", 20, 21, 1)
	var gb := w.buildings.index_of(gate)
	check(w.buildings.sx[gb] == 1 and w.buildings.sy[gb] == 3, "gates: a gate along y is 1 x 3 tiles (%d x %d)" % [w.buildings.sx[gb], w.buildings.sy[gb]])
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
	var wall_ids := []
	for x in range(15, 18):
		wall_ids.append(w.map.occupied[18 * w.map.width + x])
	var k := Economy.btype_of(w, "palisade_gate")
	check(Economy.can_place(w, 0, k, 15, 18) and not Economy.can_place(w, 1, k, 15, 18), "gates: a gate goes on your own wall, not on a rival's")
	check(not Economy.can_place(w, 0, Economy.btype_of(w, "stone_gate"), 15, 18), "gates: a stone gate doesn't go on a palisade")
	w.issue(0, Commands.BUILD, {"ids": [builder], "building": "palisade_gate", "cx": 15, "cy": 18})
	for t in 900:
		w.step()
	var nb: int = w.map.occupied[18 * w.map.width + 16]
	var b := w.buildings.index_of(nb)
	var gone := wall_ids.all(func(id): return w.buildings.index_of(id) < 0)
	check(gone and b >= 0 and w.btypes[w.buildings.kind[b]].id == "palisade_gate" and w.buildings.done[b] == 1
		and w.map.occupied[18 * w.map.width + 15] == nb and w.map.occupied[18 * w.map.width + 17] == nb,
		"gates: dropped on a palisade line, a gate takes the place of the three tiles under it and is built")

	# The gate's open look (the view) is for its own side only: an enemy beside it never opens it.
	g = _gate_world(races)
	w = g[0]
	gate = g[1]
	var gb := w.buildings.index_of(gate)
	check(not BuildingArt.gate_open(w, gb), "gate look: shut with nobody there")
	var foe2 := _spawn_at(w, 1, "spear", 21500, 22500)
	check(not BuildingArt.gate_open(w, gb), "gate look: an enemy beside it doesn't open it")
	var friend := _spawn_at(w, 0, "worker", 19500, 22500)
	check(not BuildingArt.gate_open(w, gb), "gate look: ... nor does a friend at it while the enemy stands there")
	w.units.remove_at(w.units.index_of(foe2))
	check(BuildingArt.gate_open(w, gb), "gate look: the friend alone opens it")
	check(friend > 0, "gate look: spawned")


## One unit of a slot for player p at (x, y) milli-tiles; its id once it's there.
func _spawn_at(w: World, p: int, slot: String, x: int, y: int) -> int:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": 1, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	return before


## A wall drawn diagonally (tiles touching only at their corners) still holds (Dominic: walls
## must read and work as walls whichever way they run). A diamond of palisade round (16, 24),
## every tile corner to corner with the next; a crowd inside is sent out past it and must
## stay in: the fields find no way out, and nobody slips between two corners on the move.
func _test_diagonal_wall(races: Array) -> void:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, bare)
	var r := 6
	for k in 4 * r:
		var q := k % r
		var c: Vector2i = [Vector2i(16 + q, 18 + q), Vector2i(22 - q, 24 + q), Vector2i(16 - q, 30 - q), Vector2i(10 + q, 24 - q)][k / r]
		_put(w, 1, "palisade", c.x, c.y)
	var inside := func(i: int) -> bool:
		return absi(w.units.x[i] / 1000 - 16) + absi(w.units.y[i] / 1000 - 24) < r
	var f = Flow.solve(w.map, PackedInt32Array([24 * w.map.width + 16]))
	check(f.dist[24 * w.map.width + 26] >= Flow.INF, "diagonal wall: no flow field reaches out of the diamond")
	var ids := []
	for n in 12:
		ids.append(_spawn_at(w, 0, ["spear", "worker", "large"][n % 3], 15000 + (n % 4) * 700, 23000 + (n / 4) * 700))
	for corner in [Vector2i(16500, 15500), Vector2i(25500, 24500), Vector2i(16500, 33500), Vector2i(6500, 24500)]:
		w.issue(0, Commands.MOVE, {"ids": ids, "x": corner.x, "y": corner.y})
		for t in 400:
			w.step()
	var out := 0
	for id in ids:
		var i := w.units.index_of(id)
		if i < 0 or not inside.call(i):
			out += 1
	check(out == 0, "diagonal wall: a crowd pushed at every side of a corner-to-corner wall stays in (%d got out)" % out)
	# The movement rule on its own: a unit right at the corner between two wall tiles, stepping
	# diagonally through the gap point, is stopped (no field to help it).
	var i := w.units.index_of(ids[0])
	w.units.x[i] = 21960   # in tile (21, 24), inside, by the point where wall tiles (21, 23) and (22, 24) touch
	w.units.y[i] = 24040
	w.order_direct(i, 22600, 23400)   # straight through that point (22000, 24000) into tile (22, 23), outside
	for t in 40:
		w.step()
	check(inside.call(w.units.index_of(ids[0])), "diagonal wall: a unit steered straight at the corner gap doesn't slip through")


## Diagonal gates (Dominic: "diagonal gates missing?"): a gate dropped into a diagonal wall run
## lies on it corner to corner, three cells (along 2: x and y grow together, straight down the
## screen; along 3: across it). Its own side walks through; the enemy doesn't, neither through
## it nor between its ends and the wall pieces they touch at a corner; the cells beside it stay
## open ground. The diamond of side 1's palisade from _test_diagonal_wall, round (16, 24), with a
## gate dropped into its upper-right side (along 2) and its lower-right side (along 3).
func _test_diagonal_gates(races: Array) -> void:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, bare)
	var r := 6
	for k in 4 * r:
		var q := k % r
		var c: Vector2i = [Vector2i(16 + q, 18 + q), Vector2i(22 - q, 24 + q), Vector2i(16 - q, 30 - q), Vector2i(10 + q, 24 - q)][k / r]
		_put(w, 1, "palisade", c.x, c.y)
	var inside := func(i: int) -> bool:
		return absi(w.units.x[i] / 1000 - 16) + absi(w.units.y[i] / 1000 - 24) < r
	var mw: int = w.map.width
	var k := Economy.btype_of(w, "palisade_gate")
	# Placement: on your own wall of the kind it replaces, three cells corner to corner.
	check(Economy.dims(w.btypes[k], 2) == Vector2i(3, 3) and Economy.dims(w.btypes[k], 3) == Vector2i(3, 3), "diagonal gates: a diagonal gate spans a 3 x 3 square")
	check(Economy.can_place(w, 1, k, 17, 19, 2) and Economy.can_place(w, 1, k, 19, 25, 3), "diagonal gates: one goes on each diagonal of your own wall")
	check(not Economy.can_place(w, 0, k, 17, 19, 2), "diagonal gates: ... not on a rival's")
	check(not Economy.can_place(w, 1, Economy.btype_of(w, "stone_gate"), 17, 19, 2), "diagonal gates: a stone gate doesn't go on a palisade")
	check(not Economy.can_place(w, 1, k, 62, 30, 2) and not Economy.can_place(w, 1, k, -1, 30, 3), "diagonal gates: not off the map's edge")
	_put(w, 1, "house", 34, 10)
	check(not Economy.can_place(w, 1, k, 33, 9, 2) and not Economy.can_place(w, 1, k, 33, 9, 3), "diagonal gates: not over another building")
	check(Economy.can_place(w, 1, k, 32, 8, 3), "diagonal gates: only its diagonal counts (its square's corner may overlap a house)")
	# Built by a worker from inside, with BUILD clicks (along 2, then along 3).
	var builder := _spawn_at(w, 1, "worker", 16500, 24500)
	w.stock[w.resources.find("wood")][1] = 500
	var walls := []
	for q in range(1, 4):
		walls.append(w.map.occupied[(18 + q) * mw + 16 + q])
	w.issue(1, Commands.BUILD, {"ids": [builder], "building": "palisade_gate", "cx": 17, "cy": 19, "along": 2})
	w.issue(1, Commands.BUILD, {"ids": [builder], "building": "palisade_gate", "cx": 19, "cy": 25, "along": 3, "queue": 1})
	for t in 3000:
		w.step()
		var a: int = w.buildings.index_of(w.map.occupied[20 * mw + 18])
		var b: int = w.buildings.index_of(w.map.occupied[26 * mw + 20])
		if a >= 0 and b >= 0 and w.buildings.done[a] == 1 and w.buildings.done[b] == 1 and w.btypes[w.buildings.kind[b]].gate:
			break
	var g1: int = w.map.occupied[20 * mw + 18]
	var g2: int = w.map.occupied[26 * mw + 20]
	var b1 := w.buildings.index_of(g1)
	var b2 := w.buildings.index_of(g2)
	check(b1 >= 0 and w.btypes[w.buildings.kind[b1]].gate and w.buildings.done[b1] == 1 and w.buildings.diag[b1] == 1, "diagonal gates: built down the screen (along 2)")
	check(b2 >= 0 and w.btypes[w.buildings.kind[b2]].gate and w.buildings.done[b2] == 1 and w.buildings.diag[b2] == 2, "diagonal gates: ... and across it (along 3)")
	check(walls.all(func(id): return w.buildings.index_of(id) < 0), "diagonal gates: the three wall tiles under it are gone")
	check(w.map.occupied[19 * mw + 17] == g1 and w.map.occupied[21 * mw + 19] == g1 and w.map.occupied[25 * mw + 21] == g2 and w.map.occupied[27 * mw + 19] == g2,
		"diagonal gates: each holds the three cells of its diagonal")
	var open := [Vector2i(18, 19), Vector2i(19, 19), Vector2i(17, 20), Vector2i(17, 21), Vector2i(20, 25), Vector2i(19, 26), Vector2i(21, 26)]
	check(open.all(func(c): return w.map.occupied[c.y * mw + c.x] == 0 and w.map.walks[0][c.y * mw + c.x] == 1), "diagonal gates: the rest of its square is open ground")
	# Fields: none out of the diamond for side 0; out for side 1, through the gates.
	var mine := w.lane_base[1]
	var theirs := w.lane_base[0]
	var f0 = Flow.solve(w.map, PackedInt32Array([24 * mw + 16]), Flow.INF, theirs)
	check(f0.dist[24 * mw + 26] >= Flow.INF, "diagonal gates: no field leads the enemy out (no corner slipped at the gates' ends)")
	var f1 = Flow.solve(w.map, PackedInt32Array([24 * mw + 16]), Flow.INF, mine)
	check(f1.dist[18 * mw + 21] < Flow.INF and f1.dist[29 * mw + 22] < Flow.INF, "diagonal gates: the owner's field goes out through both")
	# Side 1 walks out through each gate and back in; side 0's crowd pushed at them stays in.
	var friends := []
	for n in 3:
		friends.append(_spawn_at(w, 1, ["spear", "worker", "large"][n], 15500 + n * 700, 23500))
	for dest in [Vector2i(21000, 18000), Vector2i(23000, 29000)]:
		w.issue(1, Commands.MOVE, {"ids": friends, "x": dest.x, "y": dest.y})
		for t in 700:
			w.step()
		var out := 0
		for id in friends:
			var i := w.units.index_of(id)
			if i >= 0 and Fixed.dist2(w.units.x[i], w.units.y[i], dest.x, dest.y) < 2000 * 2000:
				out += 1
		check(out == friends.size(), "diagonal gates: side 1 walks out through its gate to (%d, %d) (%d of %d)" % [dest.x, dest.y, out, friends.size()])
		w.issue(1, Commands.MOVE, {"ids": friends, "x": 16500, "y": 24500})
		for t in 700:
			w.step()
		check(friends.all(func(id): return inside.call(w.units.index_of(id))), "diagonal gates: ... and back in")
	for id in friends + [builder]:   # (side 0 would fight them)
		if w.units.index_of(id) >= 0:
			w.units.remove_at(w.units.index_of(id))
	var crowd := []
	for n in 9:
		crowd.append(_spawn_at(w, 0, ["spear", "worker", "large"][n % 3], 15000 + (n % 3) * 700, 25000 + (n / 3) * 700))
	for dest in [Vector2i(21000, 18000), Vector2i(23000, 29000)]:
		w.issue(0, Commands.MOVE, {"ids": crowd, "x": dest.x, "y": dest.y})
		for t in 700:
			w.step()
	var esc := 0
	for id in crowd:
		if not inside.call(w.units.index_of(id)):
			esc += 1
	check(esc == 0, "diagonal gates: the enemy crowd pushed at both gates stays in (%d got out)" % esc)
	# Right at the corner where the gate's end meets the next wall tile (16, 18) and (17, 19) touch
	# at (17000, 19000)), stepping straight through the point: stopped.
	var i := w.units.index_of(crowd[0])
	w.units.x[i] = 16960
	w.units.y[i] = 19040
	w.order_direct(i, 17600, 18400)
	for t in 40:
		w.step()
	check(inside.call(w.units.index_of(crowd[0])), "diagonal gates: no slipping between the gate's end and the wall at their corner")
	# Its look opens for a friend at its cells, not one off in its square's open corner.
	for id in crowd:
		w.units.remove_at(w.units.index_of(id))
	b1 = w.buildings.index_of(g1)
	var by := _spawn_at(w, 1, "worker", 19800, 19200)   # in the square's corner cell (19, 19), over a tile from the gate's cells
	check(not BuildingArt.gate_open(w, b1), "diagonal gates: a friend off in its square's corner doesn't open it")
	w.units.x[w.units.index_of(by)] = 18600   # beside the middle cell
	w.units.y[w.units.index_of(by)] = 19400
	check(BuildingArt.gate_open(w, b1), "diagonal gates: a friend beside it does")
	w.units.remove_at(w.units.index_of(by))
	# The enemy knocks it down from outside, and the way is open.
	var foe := _spawn_at(w, 0, "spear", 21000, 18000)
	w.issue(0, Commands.ATTACK, {"ids": [foe], "target": g1})
	var t0 := w.tick
	while w.tick < t0 + 12000 and w.buildings.index_of(g1) >= 0:
		w.step()
	check(w.buildings.index_of(g1) < 0, "diagonal gates: an enemy spearman knocks one down (%d ticks)" % (w.tick - t0))
	check(w.map.walks[w.lane_base[0]][20 * mw + 18] == 1, "diagonal gates: ... and its cells are open to everyone")

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


## Mark research `id` (from data) or a made-up one with these effects done for player p, as if
## it had just finished (milestone 12: effect kinds no built research uses yet get tested too).
func _give(w: World, p: int, id: String, effects := []) -> void:
	var r := Tech.research_index(w, id)
	if r < 0:
		for fx in effects:
			Tech._check(fx, id)
		w.tech.research.append({"id": id, "name": id, "desc": "", "cost": Economy.cost_vector(w.resources, {}), "ticks": 20,
			"building": "town_center", "age": 1, "effects": effects, "only": [], "after": ""})
		for q in w.researched.size():
			w.researched[q].resize(w.tech.research.size())
		r = w.tech.research.size() - 1
	w.researched[p][r] = 1
	Tech.retype(w, p)
	Tech.refresh(w, p)


func _visible_cells(w: World, p: int) -> int:
	return w.fog[p].count(Fog.VISIBLE)


## Every research effect kind (milestone 12 phase 2), one check or two each: it lands on the
## units or buildings it names, on those already out and those made later, and nowhere else.
func _test_effects(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in w.resources.size():
		w.stock[r][0] = 5000
	var wk: int = w.type_of(0, "worker")
	var sp: int = w.type_of(0, "spear")
	var melee: int = w.classes.find("melee")
	# {tag, stat, add}, armour inside a stat: Thick Skins, researched at the Town Center in age 1.
	var hp0: int = w.types[wk].hp
	var arm0: int = w.types[wk].arm[melee]
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[0], "id": "thick_skins"})
	while w.tick < 1000 and w.researched[0][Tech.research_index(w, "thick_skins")] == 0:
		w.step()
	check(w.types[wk].hp == hp0 + 15 and w.types[wk].arm[melee] == arm0 + 1, "effects: Thick Skins gives workers +15 hp, +1 melee armour (%d -> %d, %d -> %d)" % [hp0, w.types[wk].hp, arm0, w.types[wk].arm[melee]])
	var full := true
	for i in w.units.count():
		if w.units.kind[i] == wk:
			full = full and w.units.hp[i] == w.types[wk].hp
	check(full, "effects: workers already out are at their new full health")
	check(w.types[sp].hp == int(w.types[sp].eval.hp) and int(w.types[sp].eval.hp) == int(w.types[sp].line[0].eval.hp), "effects: Thick Skins leaves spears alone")
	# A track's next step needs the one before.
	w.ages[0] = 3
	var ak := Economy.btype_of(w, "armoury")
	var s: Array = w.map.starts[0]
	var arm: int = w.buildings.index_of(_put(w, 0, "armoury", s[0] / 1000 + 4, s[1] / 1000 + 3))
	check(Tech.why_not(w, 0, arm, "bronze_edges") == "needs Sharp Sticks first", "effects: Bronze Edges needs Sharp Sticks first (%s)" % Tech.why_not(w, 0, arm, "bronze_edges"))
	_give(w, 0, "sharp_sticks")
	check(Tech.why_not(w, 0, arm, "bronze_edges") == "", "effects: after Sharp Sticks, Bronze Edges can be researched")
	check(ak >= 0, "effects: the armoury is built")
	# speed pct and carry add: Big Pockets.
	var speed0: int = w.types[wk].speed
	_give(w, 0, "big_pockets")
	var wi := -1
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.units.kind[i] == wk:
			wi = i
			break
	check(w.types[wk].speed == speed0 * 110 / 100 and w.units.speed[wi] == w.types[wk].speed, "effects: Big Pockets makes workers 10%% faster, those out too (%d -> %d)" % [speed0, w.types[wk].speed])
	check(w.types[wk].carry_add == 3, "effects: Big Pockets adds 3 to what a worker carries")
	var carry_max: int = int(w.econ.carry) + int(w.types[wk].carry_add)
	var wid: int = w.units.id[wi]
	w.issue(0, Commands.GATHER, {"ids": [wid], "cell": _nearest_resource(w.map, s, "wood")})
	var most := 0
	for t in 1500:
		w.step()
		most = maxi(most, w.units.carry[w.units.index_of(wid)])
	check(most == carry_max, "effects: a worker now carries %d before going back (%d)" % [carry_max, most])
	# speed pct with `not`: Marching Drums, foot melee only.
	var foot := -1
	var mounted := -1
	for k in w.types.size():
		if w.types[k].player == 0 and not w.types[k].worker:
			var tags: Array = w.types[k].eval.tags
			if "melee" in tags and not "mounted" in tags and foot < 0:
				foot = k
			if "mounted" in tags and mounted < 0:
				mounted = k
	var fs: int = w.types[foot].speed
	var ms: int = w.types[mounted].speed if mounted >= 0 else 0
	_give(w, 0, "marching_drums")
	check(w.types[foot].speed == fs * 110 / 100, "effects: Marching Drums makes foot melee 10%% faster (%d -> %d)" % [fs, w.types[foot].speed])
	check(mounted < 0 or w.types[mounted].speed == ms, "effects: ...but not mounted units")
	# reload pct: Quick Draw.
	var rk := -1
	for k in w.types.size():
		if w.types[k].player == 0 and w.types[k].ranged and rk < 0:
			rk = k
	var reload0: int = w.types[rk].reload
	_give(w, 0, "quick_draw")
	check(w.types[rk].reload == reload0 * 85 / 100 and w.types[rk].reload < reload0, "effects: Quick Draw reloads 15%% sooner (%d -> %d ticks)" % [reload0, w.types[rk].reload])
	check(w.types[sp].reload == int(w.combat.melee_reload), "effects: ...and leaves melee units alone")
	# cost pct and train_time pct (no research uses them yet: race bonuses, War Drums).
	var cost0: PackedInt32Array = w.types[sp].cost
	var train0: int = w.types[sp].train_ticks
	var wtrain0: int = w.types[wk].train_ticks
	_give(w, 0, "test.cheaper", [{"tag": "all", "stat": "cost", "pct": -10}, {"tag": "all", "not": ["worker"], "stat": "train_time", "pct": -30}])
	var cheaper := true
	for c in cost0.size():
		cheaper = cheaper and w.types[sp].cost[c] == cost0[c] * 90 / 100
	check(cheaper, "effects: cost -10%% makes spears 10%% cheaper (%s -> %s)" % [cost0, w.types[sp].cost])
	check(w.types[sp].train_ticks == train0 * 70 / 100 and w.types[wk].train_ticks == wtrain0, "effects: train_time -30%% trains spears faster, workers as before (%d -> %d)" % [train0, w.types[sp].train_ticks])
	# Unit sight: a lone spear sees further.
	var b := _bare_world(races)
	_spawn_at(b, 0, "spear", 16500, 22500)
	for t in 8:
		b.step()
	var seen0 := _visible_cells(b, 0)
	_give(b, 0, "test.sight", [{"tag": "all", "stat": "sight", "add": 3}])
	for t in 8:
		b.step()
	check(_visible_cells(b, 0) > seen0, "effects: unit sight +3 shows more of the map (%d -> %d cells)" % [seen0, _visible_cells(b, 0)])
	# Building sight: Lookouts, on a lone house.
	var bw := _bare_world(races)
	var house := _put(bw, 0, "house", 16, 22)
	for t in 8:
		bw.step()
	seen0 = _visible_cells(bw, 0)
	_give(bw, 0, "lookouts")
	for t in 8:
		bw.step()
	check(_visible_cells(bw, 0) > seen0, "effects: Lookouts give buildings +3 sight (%d -> %d cells)" % [seen0, _visible_cells(bw, 0)])
	# Building hp pct and armour: a standing house keeps its share of health; hits do less.
	var hb := bw.buildings.index_of(house)
	var hk: int = bw.buildings.kind[hb]
	var hp_full: int = bw.btypes[hk].hp
	bw.buildings.hp[hb] = hp_full / 2
	var atk := PackedInt32Array()
	atk.resize(bw.classes.size())
	atk[bw.classes.find("melee")] = 10
	var d0 := Combat.damage(atk, bw.bmods[0][hk].arm, bw.btypes[hk].cls, 1)
	_give(bw, 0, "test.stone", [{"building": "all", "stat": "hp", "pct": 10}, {"building": "all", "stat": "armour.melee", "add": 2}])
	check(bw.bmods[0][hk].hp == hp_full * 110 / 100 and bw.buildings.hp[hb] == hp_full / 2 * bw.bmods[0][hk].hp / hp_full, "effects: buildings +10%% hp, a half-hurt house stays half (%d of %d)" % [bw.buildings.hp[hb], bw.bmods[0][hk].hp])
	check(Combat.damage(atk, bw.bmods[0][hk].arm, bw.btypes[hk].cls, 1) == d0 - 2, "effects: buildings +2 melee armour take 2 less from a blow (%d -> %d)" % [d0, Combat.damage(atk, bw.bmods[0][hk].arm, bw.btypes[hk].cls, 1)])
	check(bw.bmods[1][hk].hp == hp_full, "effects: ...only the researching player's buildings")
	# Build speed: a worker who builds 100% faster finishes a house in about half the time.
	var times := []
	for pct in [0, 100]:
		var cw := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
		cw.stock[1][0] = 1000
		if pct > 0:
			_give(cw, 0, "test.frames", [{"tag": "worker", "stat": "build_speed", "pct": pct}])
		var builder := -1
		for i in cw.units.count():
			if cw.units.owner[i] == 0:
				builder = cw.units.id[i]
				break
		var cs: Array = cw.map.starts[0]
		cw.issue(0, Commands.BUILD, {"ids": [builder], "building": "house", "cx": cs[0] / 1000 + 4, "cy": cs[1] / 1000 + 3})
		var started := -1
		var done := -1
		while cw.tick < 3000 and done < 0:
			cw.step()
			for k in cw.buildings.count():
				if cw.buildings.owner[k] == 0 and cw.btypes[cw.buildings.kind[k]].id == "house":
					if started < 0 and cw.buildings.progress[k] > 0:
						started = cw.tick
					if cw.buildings.done[k] == 1:
						done = cw.tick
		times.append(done - started)
	var house_ticks: int = w.btypes[Economy.btype_of(w, "house")].build_ticks
	check(times[1] > 0 and absi(times[1] - house_ticks / 2) <= 3 and absi(times[0] - house_ticks) <= 3, "effects: build_speed +100%% builds a house in half the time (%s ticks, alone %d)" % [times, house_ticks])
	# Research time: a building whose research goes 50% faster.
	var rw := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in rw.resources.size():
		rw.stock[r][0] = 5000
	_give(rw, 0, "test.scholars", [{"building": "town_center", "stat": "research_time", "pct": -50}])
	rw.issue(0, Commands.RESEARCH, {"building": rw.buildings.id[0], "id": "thick_skins"})
	for t in 12:
		rw.step()
	var base_ticks: int = rw.tech.research[Tech.research_index(rw, "thick_skins")].ticks
	check(Tech.head_ticks(rw, 0) == base_ticks / 2, "effects: research_time -50%% halves a research's time (%d of %d ticks)" % [Tech.head_ticks(rw, 0), base_ticks])
	var t0 := rw.tick
	while rw.tick < 2000 and rw.researched[0][Tech.research_index(rw, "thick_skins")] == 0:
		rw.step()
	check(rw.tick - t0 <= base_ticks / 2, "effects: ...and it's done in that time (%d ticks)" % (rw.tick - t0))
	# Farm food pct: Fallow Fields, sown and reseeded.
	var fk := Economy.btype_of(w, "farm")
	var food0: int = w.btypes[fk].food
	check(Economy.farm_food(w, 1, fk) == food0, "effects: farms hold %d food without Fallow Fields" % food0)
	var race_pct := Tech.bpct(w, 0, fk, "food")   # (player 0's race may have a farm bonus of its own: swamp frogs' rich mud)
	_give(w, 0, "fallow_fields")
	check(Economy.farm_food(w, 0, fk) == food0 * (150 + race_pct) / 100, "effects: Fallow Fields: farms hold 50%% more (%d)" % Economy.farm_food(w, 0, fk))
	var fw := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	fw.stock[1][0] = 1000
	_give(fw, 0, "fallow_fields")
	fw.auto_reseed[0] = 0   # reseeded by hand below
	var farmer := -1
	for i in fw.units.count():
		if fw.units.owner[i] == 0:
			farmer = fw.units.id[i]
			break
	var fs0: Array = fw.map.starts[0]
	var fcx: int = fs0[0] / 1000 + 3
	var fcy: int = fs0[1] / 1000 + 2
	fw.issue(0, Commands.BUILD, {"ids": [farmer], "building": "farm", "cx": fcx, "cy": fcy})
	var cell: int = fcy * fw.map.width + fcx
	while fw.tick < 1600 and fw.map.pool[cell] < 0:
		fw.step()
	check(fw.map.left_at(cell) >= food0 * (150 + race_pct) / 100 - 5, "effects: a farm sown after Fallow Fields holds %d (%d)" % [food0 * (150 + race_pct) / 100, fw.map.left_at(cell)])
	fw.map.amount[fw.map.pool[cell]] = 1
	while fw.tick < 3000 and fw.map.left_at(cell) > 0:
		fw.step()
	fw.issue(0, Commands.RESEED, {"ids": [farmer], "building": fw.map.occupied[cell]})
	for t in 12:
		fw.step()
	check(fw.map.left_at(cell) >= food0 * (150 + race_pct) / 100 - 5, "effects: ...and so does a reseeded one (%d)" % fw.map.left_at(cell))
	# Trade fee: Haggling, selling pays more for the player who has it.
	var f: int = w.resources.find("food")
	var sell0 := Market.quote(w, 0, f, false)   # (a race may have a fee bonus of its own: sewer rats' black market)
	_give(w, 0, "haggling")
	check(Market.quote(w, 0, f, false) == sell0 + w.market_price[f] * 10 / 100,
		"effects: Haggling cuts the fee by 10 points (sells for %d, not %d)" % [Market.quote(w, 0, f, false), sell0])
	check(Market.quote(w, 0, f, true) == Market.quote(w, 1, f, true), "effects: ...buying costs the same")
	# Every built research's effects say something in words.
	for r in w.tech.research:
		if not r.has("line") and not String(r.id).begins_with("test."):
			check(TechTreeModel.effect_text(r.effects) != "", "effects: %s says what it does (%s)" % [r.id, TechTreeModel.effect_text(r.effects)])


## The University's research and the Castle (milestone 12 phases 4 and 5): each effect lands
## where it says and nowhere else, and the Castle looses a volley of arrows, one at each of the
## nearest foes in turn.
func _test_university_castle(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in w.resources.size():
		w.stock[r][0] = 9000
	var uk := Economy.btype_of(w, "university")
	var ck := Economy.btype_of(w, "castle")
	check(uk >= 0 and ck >= 0, "university/castle: both are built types (not planned)")
	check(int(w.btypes[uk].age) == 3 and int(w.btypes[ck].age) == 3 and w.btypes[ck].size == 4, "university/castle: age 3; the castle is 4 x 4")
	var bdata: Dictionary = DataLib.load_json("res://data/buildings.json").buildings
	check(int(bdata.castle.get("garrison", 0)) > 0 and int(bdata.castle.attack.get("arrows", 1)) > 1, "castle: a garrison and several arrows in data")
	check(int(bdata.castle.cost.get("stone", 0)) > int(bdata.castle.cost.get("wood", 0)), "castle: stone-heavy")
	# Research at the University: needs age 3, then it's bought and done there.
	var s: Array = w.map.starts[0]
	var ub: int = w.buildings.index_of(_put(w, 0, "university", s[0] / 1000 + 4, s[1] / 1000 + 3))
	w.ages[0] = 2
	check(Tech.why_not(w, 0, ub, "stonecutting") == "needs a later age", "university: research needs age 3 (%s)" % Tech.why_not(w, 0, ub, "stonecutting"))
	w.ages[0] = 3
	for id in ["stonecutting", "lifting_frames", "slit_windows", "thick_walls", "siege_wrights"]:
		check(Tech.why_not(w, 0, ub, id) == "", "university: %s can be researched there (%s)" % [id, Tech.why_not(w, 0, ub, id)])
	var hk := Economy.btype_of(w, "house")
	var hp_house: int = w.bmods[0][hk].hp
	var arm_house: PackedInt32Array = w.bmods[0][hk].arm.duplicate()
	w.issue(0, Commands.RESEARCH, {"building": w.buildings.id[ub], "id": "stonecutting"})
	var sc := Tech.research_index(w, "stonecutting")
	while w.tick < 2000 and w.researched[0][sc] == 0:
		w.step()
	var melee: int = w.classes.find("melee")
	var pierce: int = w.classes.find("pierce")
	check(w.researched[0][sc] == 1, "stonecutting: researched at the University")
	check(w.bmods[0][hk].hp == hp_house * 110 / 100 and w.bmods[0][hk].arm[melee] == arm_house[melee] + 1 and w.bmods[0][hk].arm[pierce] == arm_house[pierce] + 1,
		"stonecutting: buildings +10%% HP, +1/+1 armour (house %d -> %d hp)" % [hp_house, w.bmods[0][hk].hp])
	check(w.bmods[1][hk].hp == hp_house, "stonecutting: ...only the researcher's")
	# Lifting Frames: workers build 20% faster.
	var wk: int = w.type_of(0, "worker")
	_give(w, 0, "lifting_frames")
	check(w.types[wk].build_pct == 20, "lifting frames: workers build 20%% faster (%d)" % w.types[wk].build_pct)
	# Thick Walls: walls and gates double, houses don't.
	var before := {}
	for id in ["palisade", "palisade_gate", "wall", "stone_gate", "house"]:
		before[id] = w.bmods[0][Economy.btype_of(w, id)].hp
	_give(w, 0, "thick_walls")
	for id in ["palisade", "palisade_gate", "wall", "stone_gate"]:
		var base_hp: int = w.btypes[Economy.btype_of(w, id)].hp
		check(w.bmods[0][Economy.btype_of(w, id)].hp == base_hp * 210 / 100, "thick walls (after Stonecutting): %s +100%% HP (%d -> %d)" % [id, before[id], w.bmods[0][Economy.btype_of(w, id)].hp])
	check(w.bmods[0][hk].hp == before.house, "thick walls: ...houses as they were")
	# Siege Wrights: +1 range for siege (none yet: a ranged line stands in, tagged siege).
	var rk := -1
	for k in w.types.size():
		if w.types[k].player == 0 and w.types[k].ranged and rk < 0:
			rk = k
	var sp: int = w.type_of(0, "spear")
	var range0: int = int(w.types[rk].eval.range)
	var sp_range0: int = int(w.types[sp].eval.range)
	w.types[rk].line = w.types[rk].line.duplicate(true)   # (the race's own line is shared with the other tests)
	for l in w.types[rk].line:
		l.eval.tags = l.eval.tags + ["siege"]
	_give(w, 0, "siege_wrights")
	check(int(w.types[rk].eval.range) == range0 + 1, "siege wrights: siege +1 range (%d -> %d)" % [range0, int(w.types[rk].eval.range)])
	check(int(w.types[sp].eval.range) == sp_range0, "siege wrights: ...spears as they were")
	# The Castle's research: War Drums and the two race slots.
	var cb: int = w.buildings.index_of(_put(w, 0, "castle", s[0] / 1000 - 2, s[1] / 1000 + 8))
	for id in ["war_drums", "bog_poultice"]:   # (player 0 is swamp frogs: the swamp's own research is at the Castle, milestone 14)
		check(Tech.why_not(w, 0, cb, id) == "", "castle: %s can be researched there (%s)" % [id, Tech.why_not(w, 0, cb, id)])
	check(Tech.why_not(w, 0, cb, "gnawing_teeth") == Tech.NOT_IN_TREE, "castle: ...not another race's own (the rats' Gnawing Teeth)")
	var hl: int = w.type_of(0, "healer")
	var train_sp: int = w.types[sp].train_ticks
	var train_wk: int = w.types[wk].train_ticks
	var train_hl: int = w.types[hl].train_ticks if hl >= 0 else 0
	_give(w, 0, "war_drums")
	check(w.types[sp].train_ticks == train_sp * 70 / 100, "war drums: soldiers train 30%% faster (%d -> %d ticks)" % [train_sp, w.types[sp].train_ticks])
	check(w.types[wk].train_ticks == train_wk and (hl < 0 or w.types[hl].train_ticks == train_hl), "war drums: ...workers and healers as before")
	_give(w, 0, "bog_poultice")
	check(hl < 0 or w.types[hl].heal_pct == 30, "own research: Bog Poultice, healers heal 30%% more (%d)" % (w.types[hl].heal_pct if hl >= 0 else 0))
	# The Castle's arrows: a volley of `arrows`, one at each of the nearest foes in turn.
	var arrows: int = int(bdata.castle.attack.arrows)
	for n in [1, arrows + 2]:
		var g := _bare_world(races)
		var gid := _put(g, 1, "castle", 14, 14)   # centre (16, 16)
		g.issue(0, Commands.SPAWN, {"slot": "spear", "count": n, "x": 20500, "y": 16000})
		var first := []   # the first volley's targets
		for t in 40:
			g.step()
			for e in g.events:
				if e.type == "shot" and e.by == gid:
					first.append(e.to)
			if not first.is_empty():
				break
		var distinct := {}
		for id in first:
			distinct[id] = true
		check(first.size() == arrows, "castle: a volley is %d arrows (%d, %d foes)" % [arrows, first.size(), n])
		check(distinct.size() == mini(n, arrows), "castle: the arrows go to %d different foes (%d foes in reach: %d hit)" % [mini(n, arrows), n, distinct.size()])
	# Slit Windows: +1 tile of reach for the Castle (and towers, Town Centers).
	var reach := []
	for slit in [false, true]:
		var g := _bare_world(races)
		var gid := _put(g, 1, "castle", 14, 14)
		if slit:
			_give(g, 1, "slit_windows")
		g.issue(0, Commands.SPAWN, {"slot": "spear", "count": 1, "x": 16000 + 10500, "y": 16000})   # just past 8 tiles (+ half the castle)
		var shot := 0
		for t in 60:
			g.step()
			for e in g.events:
				if e.type == "hit" and e.by == gid:
					shot += 1
		reach.append(shot)
	check(reach[0] == 0 and reach[1] > 0, "slit windows: a foe just out of the castle's reach is shot once it has them (%s)" % [reach])
	var gk := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	_give(gk, 0, "slit_windows")
	for id in ["watchtower", "castle", "town_center"]:
		check(Tech.badd(gk, 0, Economy.btype_of(gk, id), "range") == 1, "slit windows: %s +1 range" % id)
	check(Tech.badd(gk, 0, Economy.btype_of(gk, "house"), "range") == 0, "slit windows: ...houses nothing")

## Research and the age-up queue with units, the genre's way: in the order clicked, paid when
## queued, refunded on cancel, never queued twice.
func _test_research_queue(races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for r in w.resources.size():
		w.stock[r][0] = 5000
	w.ages[0] = 2   # player 0 is frogs: Strong Legs is theirs
	var s: Array = w.map.starts[0]
	var bk := Economy.btype_of(w, "barracks")
	var b: int = Economy.place(w, 0, bk, s[0] / 1000 + 4, s[1] / 1000 - 6)
	w.buildings.done[b] = 1
	w.buildings.hp[b] = w.btypes[bk].hp
	var sk := Economy.btype_of(w, "stable")   # what the age-3 age-up asks for
	var si: int = Economy.place(w, 0, sk, s[0] / 1000 - 7, s[1] / 1000 - 6)
	w.buildings.done[si] = 1
	w.buildings.hp[si] = w.btypes[sk].hp
	var bid: int = w.buildings.id[b]
	var up := Tech.research_index(w, "line.spear.2")
	var leap := Tech.research_index(w, "frog_leap")
	var k: int = w.type_of(0, "spear")
	var food: int = w.stock[0][0]
	w.issue(0, Commands.RESEARCH, {"building": bid, "id": "line.spear.2"})
	w.issue(0, Commands.RESEARCH, {"building": bid, "id": "frog_leap"})
	w.issue(0, Commands.TRAIN, {"building": bid, "slot": "spear"})
	w.issue(0, Commands.RESEARCH, {"building": bid, "id": "frog_leap"})   # a second click: refused
	for t in 12:
		w.step()
	b = w.buildings.index_of(bid)
	check(w.buildings.queue[b] == [Tech.entry(up), Tech.entry(leap), k], "research queue: two research then a spear, in the order clicked (%s)" % [w.buildings.queue[b]])
	var paid: int = int(w.tech.research[up].cost[0]) + int(w.tech.research[leap].cost[0]) + int(w.types[k].cost[0])
	check(w.stock[0][0] == food - paid, "research queue: each paid when queued (food %d -> %d, %d)" % [food, w.stock[0][0], paid])
	check(Tech.why_not(w, 0, b, "frog_leap") == "already being researched", "research queue: a queued research can't be queued again")
	# The age-up queues too; a second one is refused; cancelling refunds it.
	var tc: int = w.buildings.id[0]
	var before := w.stock.map(func(row): return row[0])
	w.issue(0, Commands.AGE_UP, {"building": tc})
	w.issue(0, Commands.AGE_UP, {"building": tc})
	for t in 12:
		w.step()
	check(w.buildings.queue[0].count(Tech.entry(Tech.AGE_UP)) == 1 and Tech.why_not(w, 0, 0, "") == "already ageing up", "research queue: one age-up queued, the second refused")
	w.issue(0, Commands.CANCEL, {"building": tc, "index": w.buildings.queue[0].find(Tech.entry(Tech.AGE_UP))})
	for t in 12:
		w.step()
	check(w.stock.map(func(row): return row[0]) == before and not Tech.queued(w, 0, Tech.AGE_UP), "research queue: cancelling the age-up refunds it")
	w.issue(0, Commands.CANCEL, {"building": bid, "index": 1})   # frog_leap, and then queue it again
	for t in 12:
		w.step()
	check(w.stock[0][0] == food - paid + int(w.tech.research[leap].cost[0]) and w.buildings.queue[w.buildings.index_of(bid)] == [Tech.entry(up), k],
		"research queue: cancelling a queued research refunds it")
	w.issue(0, Commands.RESEARCH, {"building": bid, "id": "frog_leap"})
	for t in 12:
		w.step()
	# Run it: the spear line's upgrade, then the spear, then Strong Legs (queued last now).
	var done := {}
	var spears := func(): return range(w.units.count()).filter(func(i): return w.units.kind[i] == k).size()
	var n0: int = spears.call()
	while w.tick < 4000 and done.size() < 3:
		w.step()
		for e in w.events:
			if e.type == "research" and e.player == 0 and not done.has(e.id):
				done[e.id] = w.tick
		if not done.has("spear") and spears.call() > n0:
			done["spear"] = w.tick
	check(done.size() == 3 and done["line.spear.2"] < done["spear"] and done["spear"] < done["frog_leap"],
		"research queue: they finish in queue order (%s)" % [done])
	check(done.get("spear", 0) - done.get("line.spear.2", 0) >= w.types[k].train_ticks, "research queue: the spear waited for the research ahead of it")


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
	var offsets := {"barracks": Vector2i(4, -6), "stable": Vector2i(-7, -6), "armoury": Vector2i(4, 3), "house": Vector2i(-6, 3)}
	for need in ["barracks", "stable", "armoury", "house"]:   # what each age-up asks for, the armoury, and room for the worker, already standing
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
	check(Tech.head(w, 0) == Tech.AGE_UP, "tech: the Town Center is ageing up")
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
	for t in w.types[w.type_of(0, "worker")].train_ticks + 8:
		w.step()
	check(w.units.count() == units_then + 1, "tech: the worker queued behind the age-up trains once it's done")
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
	var up2 := Tech.research_index(w, "line.spear.2")   # a line's age-3 upgrade waits for its age-2 one (Dominic, 2026-10-13)
	w.researched[0][up2] = 0
	check(Tech.why_not(w, 0, barracks, "line.spear.3").begins_with("needs "), "tech: the spears' age-3 upgrade waits for the age-2 one (%s)" % Tech.why_not(w, 0, barracks, "line.spear.3"))
	w.researched[0][up2] = 1
	check(Tech.why_not(w, 0, barracks, "line.spear.3") == "", "tech: ...and is there once it's done (%s)" % Tech.why_not(w, 0, barracks, "line.spear.3"))
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
				if w.buildings.owner[b] == 0 and w.buildings.done[b] == 1 and w.buildings.sx[b] == 2:
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
	_test_heal(gen)
	_test_damage()
	_test_idle_fight(gen)
	_test_spread(gen)
	_test_teams(gen)
	_test_siege(gen)
	_test_surround(gen)
	_test_formation(gen)
	_test_role_formation(gen)
	_test_counter_pick(gen)
	_test_shield_wall(gen)
	_test_stances(gen)
	_test_ranged_holds(gen)
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


## Healers (Dominic, 2026-10-12: a healer at the Town Center): one heals a wounded friend in
## range to full, walks to one further off, never heals an enemy, and never fights, not even
## when told to or when struck.
func _test_heal(gen) -> void:
	var race: Dictionary = gen.generate("romans", rules_)
	var w := _bare_world([race, race])
	var healer := _spawn_at(w, 0, "healer", 15000, 20500)
	var near := _spawn_at(w, 0, "spear", 17000, 20500)
	var far := _spawn_at(w, 0, "spear", 15000, 25500)   # 5 tiles off: within sight, out of range
	var foe := _spawn_at(w, 1, "spear", 13500, 21500)
	w.issue(0, Commands.STANCE, {"ids": [near, far], "stance": "passive"})
	w.issue(1, Commands.STANCE, {"ids": [foe], "stance": "passive"})
	var hi := w.units.index_of(healer)
	check(w.units.posture[hi] == Combat.PASSIVE, "heal: a healer spawns with the no-attack stance")
	check(int(w.types[w.units.kind[hi]].eval.attack) == 0, "heal: a healer has no attack")
	w.issue(0, Commands.ATTACK, {"ids": [healer], "target": foe})
	for t in 8:
		w.step()
	var full: int = w.types[w.units.kind[w.units.index_of(near)]].hp
	for id in [near, far, foe]:
		w.units.hp[w.units.index_of(id)] = 4
	var heals := 0
	var healed := {}
	var healer_hits := 0
	var fought := false
	var near_full_at := -1
	for t in 2400:
		w.step()
		for e in w.events:
			if e.type == "heal":
				heals += 1
				healed[e.to] = true
			elif e.type == "hit" and e.by == healer:
				healer_hits += 1
		fought = fought or w.units.foe[w.units.index_of(healer)] != 0
		if near_full_at < 0 and w.units.hp[w.units.index_of(near)] == full:
			near_full_at = t
	check(near_full_at > 0, "heal: the wounded friend in range is healed to full (tick %d, %d heals)" % [near_full_at, heals])
	check(w.units.hp[w.units.index_of(far)] == full, "heal: a wounded friend 5 tiles off is walked to and healed (%d/%d hp)" % [w.units.hp[w.units.index_of(far)], full])
	check(w.units.hp[w.units.index_of(foe)] == 4 and not healed.has(foe), "heal: never an enemy (%d hp)" % w.units.hp[w.units.index_of(foe)])
	check(not healed.has(healer), "heal: not itself")
	check(healer_hits == 0 and not fought, "heal: told to attack, it doesn't (%d hits)" % healer_hits)
	var c: Dictionary = w.combat
	var per_heal: int = int(c.heal_amount)
	check(heals <= (full - 4) * 2 / per_heal + 2, "heal: %d hp a heal, no more heals than the wounds need (%d)" % [per_heal, heals])
	# Struck by an aggressive enemy, it doesn't strike back (and heals nobody who isn't hurt).
	var w2 := _bare_world([race, race])
	var h2 := _spawn_at(w2, 0, "healer", 15000, 20500)
	w2.issue(0, Commands.STANCE, {"ids": [h2], "stance": "aggressive"})
	var attacker := _spawn_at(w2, 1, "spear", 16500, 20500)
	var hits_back := 0
	var heals2 := 0
	for t in 600:
		w2.step()
		for e in w2.events:
			if e.type == "hit" and e.by == h2:
				hits_back += 1
			elif e.type == "heal":
				heals2 += 1
	check(w2.units.index_of(h2) < 0, "heal: an enemy spearman kills a lone healer")
	check(hits_back == 0 and heals2 == 0, "heal: even on aggressive it never fights back (%d hits), and heals no one unhurt or itself (%d)" % [hits_back, heals2])
	check(w2.units.index_of(attacker) >= 0 and w2.units.hp[w2.units.index_of(attacker)] == w2.types[w2.units.kind[w2.units.index_of(attacker)]].hp,
		"heal: the attacker is untouched and unhealed")


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


## Shots fly: an arrow lands a flight after it is loosed and only then hurts; one at a target that
## has stepped off the spot falls in the ground; one at a building always lands.
func _test_shots(races: Array) -> void:
	var w := _bare_world(races)
	var a := _lone(w, 0, "archer", 15000, 20500, "stand")
	var t := _lone(w, 1, "spear", 19000, 20500, "passive")
	w.issue(0, Commands.ATTACK, {"ids": [a], "target": t})
	var shot := {}
	var fired := 0
	for k in 200:
		w.step()
		for e in w.events:
			if e.type == "shot" and e.by == a:
				shot = e
		if not shot.is_empty():
			fired = w.tick - 1   # the tick it was loosed in
			break
	check(not shot.is_empty() and shot.to == t and shot.ticks > 1, "shots: an archer looses a shot that takes a while to land (%s)" % [shot])
	check(w.shots.count() == 1, "shots: one in the air (%d)" % w.shots.count())
	var hp: int = w.units.hp[w.units.index_of(t)]
	var landed := -1
	var hit := {}
	for k in 60:
		w.step()
		for e in w.events:
			if e.type == "hit" and e.by == a:
				hit = e
		if not hit.is_empty():
			landed = w.tick - 1
			break
		check(w.units.hp[w.units.index_of(t)] == hp, "shots: no harm before it lands (tick %d)" % w.tick)
	check(landed == fired + int(shot.get("ticks", 0)), "shots: it lands its flight after loosing (%d, loosed %d, %d ticks)" % [landed, fired, shot.get("ticks", 0)])
	check(not hit.is_empty() and w.units.hp[w.units.index_of(t)] == hp - int(hit.damage), "shots: a standing target is hit (%s)" % [hit])
	# The next shot: the target steps a tile and a half aside while it flies.
	var miss := {}
	var aside := false
	var aim := {}
	for k in 200:
		w.step()
		for e in w.events:
			if e.type == "shot" and e.by == a and not aside:
				var ti := w.units.index_of(t)
				w.units.y[ti] += 1500
				aside = true
				aim = e
			elif e.type == "miss" and e.by == a:
				miss = e
		if not miss.is_empty():
			break
	hp = w.units.hp[w.units.index_of(t)]
	check(not miss.is_empty() and miss.to == t and miss.x == aim.x and miss.y == aim.y, "shots: a target that stepped away is missed, the shot lands where it stood (%s)" % [miss])
	check(w.units.hp[w.units.index_of(t)] == hp and w.lost[1] == 0, "shots: a miss does no harm")
	# A building never dodges.
	var g := _bare_world(races)
	var house := _put(g, 1, "house", 18, 20)
	var hb := g.buildings.index_of(house)
	var bhp: int = g.buildings.hp[hb]
	var s2 := _lone(g, 0, "archer", 15000, 20500, "stand")
	g.issue(0, Commands.ATTACK, {"ids": [s2], "target": house})
	var shots := 0
	var hits := 0
	for k in 300:
		g.step()
		for e in g.events:
			if e.by == s2 and e.type == "shot":
				shots += 1
			elif e.by == s2 and e.type == "hit":
				hits += 1
	check(hits > 2 and hits >= shots - 1 and g.buildings.hp[g.buildings.index_of(house)] < bhp, "shots: every shot at a house lands (%d of %d)" % [hits, shots])


## Siege engines (milestone 13): a catapult's stone hurts everyone round where it lands, less
## further out, friends at half; it can't hit what is under its nose and steps back; a ram goes
## for buildings only, hits them very hard and shrugs off arrows; a bolt goes through a line.
func _test_engines(races: Array) -> void:
	# Splash: four foes and a friend round the catapult's target.
	var w := _bare_world(races)
	var cat := _lone(w, 0, "catapult", 9000, 20500, "stand")
	var foes := []
	for o in [[0, 0], [700, 0], [0, 700], [0, -700]]:
		foes.append(_lone(w, 1, "spear", 17000 + o[0], 20500 + o[1], "passive"))
	var friend := _lone(w, 0, "spear", 16400, 20500, "passive")
	for k in foes.size():
		var i := w.units.index_of(foes[k])
		w.units.x[i] = 17000 + [0, 700, 0, 0][k]
		w.units.y[i] = 20500 + [0, 0, 700, -700][k]
	var fi := w.units.index_of(friend)
	w.units.x[fi] = 16400
	w.units.y[fi] = 20500
	w.issue(0, Commands.ATTACK, {"ids": [cat], "target": foes[0]})
	var splash := {}
	var hits := {}
	for k in 400:
		w.step()
		for e in w.events:
			if e.type == "splash" and e.by == cat:
				splash = e
			elif e.type == "hit" and e.by == cat:
				hits[e.to] = e.damage
		if not splash.is_empty():
			break
	var on_foes := foes.filter(func(f): return hits.has(f))
	check(not splash.is_empty() and on_foes.size() >= 3, "catapult: its stone lands and hurts %d of 4 foes round the spot (%s)" % [on_foes.size(), hits])
	check(hits.get(foes[0], 0) > hits.get(foes[1], 0) and hits.get(foes[1], 0) > 0, "catapult: the target takes the most, a body further out less (%s)" % [hits])
	check(hits.has(friend) and hits[friend] < hits.get(foes[1], 0) + 1, "catapult: a friend in the splash is hurt too, at half (%d)" % hits.get(friend, 0))
	# Minimum range: a foe a tile and a half off isn't shot at; the catapult steps back, then shoots.
	var m := _bare_world(races)
	var c2 := _lone(m, 0, "catapult", 12000, 20500, "aggressive")
	var near := _lone(m, 1, "spear", 13900, 20500, "passive")
	var ni := m.units.index_of(near)
	m.units.x[ni] = 13900
	m.units.y[ni] = 20500
	m.issue(0, Commands.ATTACK, {"ids": [c2], "target": near})
	var close_shot := false
	var shot_at := -1
	for k in 600:
		m.step()
		var ci := m.units.index_of(c2)
		ni = m.units.index_of(near)
		var gap: int = Combat._gap(m, ci, ni, -1)
		for e in m.events:
			if e.type == "shot" and e.by == c2:
				if gap < 3000:
					close_shot = true
				shot_at = gap
		if shot_at >= 0:
			break
	check(not close_shot and shot_at >= 3000, "catapult: no shot inside its minimum range; it steps back and shoots from %d milli-tiles" % shot_at)
	# The ram: ordered at a soldier, it won't; left be, it finds the house and hits it very hard.
	var r := _bare_world(races)
	var house := _put(r, 1, "house", 18, 20)
	var ram := _lone(r, 0, "ram", 15500, 22500, "aggressive")
	var guard := _lone(r, 1, "spear", 15500, 24000, "passive")
	r.issue(0, Commands.ATTACK, {"ids": [ram], "target": guard})
	var blow := 0
	var on_guard := 0
	for k in 400:
		r.step()
		for e in r.events:
			if e.type == "hit" and e.by == ram:
				if e.to == house:
					blow = maxi(blow, e.damage)
				elif e.to == guard:
					on_guard += 1
		if blow > 0:
			break
	check(on_guard == 0 and blow >= 30, "ram: never hits soldiers, hits a house hard (%d a blow)" % blow)
	var archer := _lone(r, 1, "archer", 14000, 24500, "stand")
	r.issue(1, Commands.ATTACK, {"ids": [archer], "target": ram})
	var arrow := 0
	for k in 300:
		r.step()
		for e in r.events:
			if e.type == "hit" and e.by == archer and e.to == ram:
				arrow = e.damage
		if arrow > 0:
			break
	check(arrow == 1, "ram: arrows barely scratch it (%d)" % arrow)
	var rk: int = r.type_of(0, "ram")
	var heals_ok := r.types.filter(func(t): return t.eval.tags.has("siege")).all(func(t): return t.no_heal == t.eval.tags.has("machine"))
	check(heals_ok and r.types[rk].buildings_only, "engines: machines aren't healed (beasts are), rams go for buildings")
	# A bolt through a line: aimed at the far one, it hits those in its way too.
	var b := _bare_world(races)
	var bolt := _lone(b, 0, "bolt_thrower", 8000, 20500, "stand")
	var line := []
	for x in [14500, 15500, 16500]:
		var id := _lone(b, 1, "spear", x, 20500, "passive")
		var li := b.units.index_of(id)
		b.units.x[li] = x
		b.units.y[li] = 20500
		line.append(id)
	b.issue(0, Commands.ATTACK, {"ids": [bolt], "target": line[2]})
	var struck := {}
	for k in 400:
		b.step()
		for e in b.events:
			if e.type == "hit" and e.by == bolt:
				struck[e.to] = true
		if not struck.is_empty():
			break
	check(struck.size() == 3, "bolt thrower: a bolt goes through a line of three (%d hit)" % struck.size())


## Trade carts (milestone 13 step 6, trade.gd): a cart sent from its market to another 30 tiles off
## walks there, loads the trip's gold and is paid on coming home; gold per trip grows faster than the
## distance; markets too close, unfinished or an enemy's aren't traded with; one killed on the way
## home loses its load; it carries on round after round.
func _test_trade(races: Array) -> void:
	var Trade = load("res://src/sim/trade.gd")
	var w := _bare_world(races)
	var g: int = w.resources.find("gold")
	var home := _put(w, 0, "market", 12, 30)
	var far := _put(w, 0, "market", 42, 30)
	var hb := w.buildings.index_of(home)
	var fb := w.buildings.index_of(far)
	var d: int = Trade.tiles(w, hb, fb)
	var pay: int = Trade.trip_gold(w, hb, fb)
	check(d == 30 and pay == 30 * 30 / 50 + 30 * 50 / 100, "trade: 30 tiles apart, a round trip pays d*d/50 + d/2 = %d (%d tiles)" % [pay, d])
	var near := _put(w, 0, "market", 24, 30)
	check(Trade.trip_gold(w, hb, w.buildings.index_of(near)) * 30 < pay * 12 , "trade: half as far pays well under half as much")
	check(Trade.why_not(w, 0, hb, w.buildings.index_of(near)) != "", "trade: markets 12 tiles apart are too close")
	var cart := _spawn_at(w, 0, "trader", 15500, 31500)
	var k: int = w.type_of(0, "trader")
	check(w.types[k].trader and w.types[k].harmless and w.types[k].posture == Combat.PASSIVE, "trade: carts are traders, harmless and passive")
	var gold: int = w.stock[g][0]
	w.issue(0, Commands.ROUTE, {"ids": [cart], "building": far})
	var loaded := -1
	var paid := -1
	for t in 3000:
		w.step()
		for e in w.events:
			if e.type == "trade" and e.id == cart:
				if e.has("load"):
					loaded = w.tick
				elif e.has("paid") and paid < 0:
					paid = w.tick
		if paid >= 0:
			break
	check(loaded > 0 and paid > loaded, "trade: the cart loads at the far market (%d) and is paid at home (%d)" % [loaded, paid])
	check(w.stock[g][0] == gold + pay, "trade: one round trip brings home %d gold (%d)" % [pay, w.stock[g][0] - gold])
	check(paid > 20 * 2 * 25 and paid < 20 * 2 * 60, "trade: a 60-tile round trip at a cart's pace takes about a minute (%d ticks)" % paid)
	var ci := w.units.index_of(cart)
	check(ci >= 0 and w.units.task[ci] == Economy.TRADE and w.units.work[ci] == Trade.OUT, "trade: it sets out again")
	# A second round, then kill it on its way home: the load is lost.
	for t in 3000:
		w.step()
		ci = w.units.index_of(cart)
		if w.units.carry[ci] > 0 and w.units.work[ci] == Trade.HOME:
			break
	gold = w.stock[g][0]
	w.units.hp[ci] = 1
	var foe := _spawn_at(w, 1, "spear", w.units.x[ci], w.units.y[ci])
	w.issue(1, Commands.ATTACK, {"ids": [foe], "target": cart})
	for t in 400:
		w.step()
		if w.units.index_of(cart) < 0:
			break
	check(w.units.index_of(cart) < 0 and w.stock[g][0] == gold, "trade: a cart killed on its way home loses its load")
	# Unfinished and enemy markets aren't traded with.
	var e := _bare_world(races)
	var eh := _put(e, 0, "market", 12, 30)
	var ef := _put(e, 1, "market", 42, 30)
	var c2 := _spawn_at(e, 0, "trader", 15500, 31500)
	e.issue(0, Commands.ROUTE, {"ids": [c2], "building": ef})
	for t in 40:
		e.step()
	check(e.units.task[e.units.index_of(c2)] == Economy.NONE, "trade: no route to an enemy's market")
	var a := World.new(SEED, SimMap.load_id("flat_test"), races, _bare_rules(), [0, 0])
	_put(a, 0, "market", 12, 30)
	var af := _put(a, 1, "market", 42, 30)
	var c3 := _spawn_at(a, 0, "trader", 15500, 31500)
	a.issue(0, Commands.ROUTE, {"ids": [c3], "building": af})
	for t in 40:
		a.step()
	check(a.units.task[a.units.index_of(c3)] == Economy.TRADE, "trade: an ally's market is traded with")
	var cart_eval: Dictionary = w.types[k].eval
	check(int(cart_eval.cost.gold) > 0 and int(cart_eval.cost.wood) > 0 and int(cart_eval.pop) == 1, "trade: a cart costs wood and gold, 1 pop (%s)" % [cart_eval.cost])


## The great sling (milestone 13 step 4): buildings only, from 12 tiles; it unpacks for a while
## after it stops before its first throw, and packs up before it can move again.
## The sapper: it walks up to a building and blows up, a stone wall tile outright, the wall beside
## it hurt, itself gone; a house goes in one blast.
func _test_sapper_sling(races: Array) -> void:
	var w := _bare_world(races)
	var k: int = w.type_of(0, "great_sling")
	var house := _put(w, 1, "house", 30, 20)
	var sl := _lone(w, 0, "great_sling", 15000, 21000, "aggressive")
	var guard := _lone(w, 1, "spear", 26000, 21000, "passive")
	w.issue(0, Commands.ATTACK, {"ids": [sl], "target": house})
	var stopped := -1
	var thrown := -1
	var at_guard := false
	for t in 1200:
		w.step()
		var i := w.units.index_of(sl)
		if stopped < 0 and w.units.moving[i] == 0 and w.units.ready[i] == 1:
			stopped = w.tick
		for e in w.events:
			if e.type == "shot" and e.by == sl:
				thrown = w.tick if thrown < 0 else thrown
				at_guard = at_guard or e.to == guard
		if thrown >= 0:
			break
	var ti := w.units.index_of(sl)
	var reach: int = Combat._gap(w, ti, -1, w.buildings.index_of(house))
	check(thrown > 0 and stopped > 0 and thrown - stopped >= int(w.types[k].unpack) - 1, "great sling: it stops, unpacks (%d ticks) and throws (stopped %d, threw %d)" % [w.types[k].unpack, stopped, thrown])
	check(reach > 8000 and not at_guard, "great sling: throws at the house from %d milli-tiles, never at the soldier" % reach)
	var x0: int = w.units.x[ti]
	w.issue(0, Commands.MOVE, {"ids": [sl], "x": 8000, "y": 21000})
	var left := -1
	for t in 200:
		w.step()
		if left < 0 and w.units.x[w.units.index_of(sl)] != x0:
			left = t
	check(left >= int(w.types[k].pack), "great sling: it packs up (%d ticks) before it rolls (%d)" % [w.types[k].pack, left])
	# The sapper and a stone wall: one blast takes a tile out, the next one is hurt, the sapper is gone.
	# (The sapper is parked, D-128: its slot is planned, so there's none to test until it comes back.)
	if w.type_of(0, "sapper") < 0:
		return
	var s := _bare_world(races)
	var walls := []
	for y in range(18, 25):
		walls.append(_put(s, 1, "wall", 24, y))
	var sp := _lone(s, 0, "sapper", 18000, 21500, "aggressive")
	s.issue(0, Commands.ATTACK, {"ids": [sp], "target": walls[3]})
	var blast := false
	for t in 800:
		s.step()
		for e in s.events:
			blast = blast or (e.type == "blast" and e.by == sp)
		if blast:
			break
	for t in 3:
		s.step()
	var next := s.buildings.index_of(walls[2])
	check(blast and s.buildings.index_of(walls[3]) < 0, "sapper: one blast takes a stone wall tile out")
	check(next >= 0 and s.buildings.hp[next] < s.btypes[s.buildings.kind[next]].hp, "sapper: the wall beside it is hurt too")
	check(s.units.index_of(sp) < 0, "sapper: it goes up with its charge")
	var h := _bare_world(races)
	var hs := _put(h, 1, "house", 24, 20)
	var sp2 := _lone(h, 0, "sapper", 18000, 21000, "aggressive")
	h.issue(0, Commands.ATTACK, {"ids": [sp2], "target": hs})
	for t in 800:
		h.step()
		if h.buildings.index_of(hs) < 0:
			break
	check(h.buildings.index_of(hs) < 0 and h.units.index_of(sp2) < 0, "sapper: a house goes in one blast")
	var tc := _put(h, 1, "town_center", 24, 26)
	var tb := h.buildings.index_of(tc)
	var sp3 := _lone(h, 0, "sapper", 18000, 27000, "aggressive")
	h.issue(0, Commands.ATTACK, {"ids": [sp3], "target": tc})
	for t in 800:
		h.step()
		if h.units.index_of(sp3) < 0:
			break
	tb = h.buildings.index_of(tc)
	var left_hp: int = h.buildings.hp[tb] if tb >= 0 else 0
	var full: int = h.btypes[h.buildings.kind[tb]].hp if tb >= 0 else 1
	check(tb >= 0 and left_hp * 100 / full >= 40 and left_hp * 100 / full <= 75, "sapper: a Town Center loses a good share but stands (%d of %d hp left)" % [left_hp, full])


func _bare_rules() -> Dictionary:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	return bare


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


## Wonder victory (src/sim/match.gd, rules.wonder): a finished Wonder that stands for the hold
## time wins for its owner's team, the countdown in the hash; one knocked down stops its
## countdown (and another starts from the top); with the host switch off it's just a building.
func _test_wonder(races: Array) -> void:
	var hold := 30   # seconds, so the test is quick
	var r := rules_.duplicate(true)
	r.wonder.hold_seconds = hold
	# 1. It stands: the countdown wins, not a second early.
	var w := _wonder_world(races, r)
	var wid: int = _put_wonder(w, 0)
	var built := []
	var won := {}
	while w.tick < (hold + 3) * 20 and w.winner < 0:
		w.step()
		for e in w.events:
			if e.type == "wonder":
				built.append(e.what)
			elif e.type == "won":
				won = e
		if w.tick == (hold - 2) * 20:
			check(w.winner < 0 and w.wonder_ids.size() == 1 and Match.ticks_left(w, 0) > 0,
				"wonder: no win while the countdown runs (%d ticks left)" % (Match.ticks_left(w, 0) if w.wonder_ids.size() > 0 else -1))
	check(built == ["built"], "wonder: everyone hears it's finished (%s)" % [built])
	check(w.winner == w.teams[0] and won.get("wonder", 0) == wid, "wonder: standing %d s wins for its team (winner %d at tick %d)" % [hold, w.winner, w.tick])
	check(w.tick <= (hold + 2) * 20, "wonder: it wins on time (tick %d)" % w.tick)
	var again := _wonder_world(races, r)
	_put_wonder(again, 0)
	while again.tick < w.tick:
		again.step()
	check(again.state_hash() == w.state_hash() and again.winner == w.winner, "wonder: the same match twice, the same hash and winner")
	# 2. It falls: the countdown stops, and a new one starts from the top.
	w = _wonder_world(races, r)
	wid = _put_wonder(w, 0)
	for t in 10 * 20:
		w.step()
	var b := w.buildings.index_of(wid)
	w.buildings.hp[b] = 40   # nearly down: spearmen finish it
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 6, "x": w.buildings.cx[b] * 1000 - 1500, "y": w.buildings.cy[b] * 1000 + 2500})
	var spawned := false
	var fell := false
	while w.tick < (hold + 10) * 20 and not fell:
		w.step()
		if not spawned:
			var mine := []
			for i in w.units.count():
				if w.units.owner[i] == 1 and not w.types[w.units.kind[i]].worker:
					mine.append(w.units.id[i])
			if mine.size() == 6:
				w.issue(1, Commands.ATTACK, {"ids": mine, "target": wid})
				spawned = true
		for e in w.events:
			fell = fell or (e.type == "wonder" and e.what == "fell" and e.id == wid)
	check(fell and w.buildings.index_of(wid) < 0 and w.wonder_ids.is_empty(), "wonder: knocked down, its countdown stops (tick %d)" % w.tick)
	var second: int = _put_wonder(w, 0)
	var started := w.tick
	while w.tick < started + (hold + 3) * 20 and w.winner < 0:
		w.step()
		if w.tick == (hold + 12) * 20:
			check(w.winner < 0, "wonder: the fallen one's time doesn't count for the next")
	check(w.winner == w.teams[0] and w.tick - started >= hold * 20, "wonder: a new one counts from the top (won %d s after it went up)" % ((w.tick - started) / 20))
	check(second != wid, "wonder: (a different building)")
	# 3. The switch off: no countdown, no win.
	var off := r.duplicate(true)
	off.wonder.victory = false
	w = _wonder_world(races, off)
	_put_wonder(w, 0)
	for t in (hold + 5) * 20:
		w.step()
	check(w.winner < 0 and w.wonder_ids.is_empty() and Match.hold_ticks(w) == 0, "wonder: with Wonder victory off it never wins")


## Two players on flat_test with their Town Centers and no workers to wander about.
func _wonder_world(races: Array, r: Dictionary) -> World:
	var rr := r.duplicate(true)
	rr.economy.start.workers = 0
	return World.new(SEED, SimMap.load_id("flat_test"), [races[0], races[1]], rr)


## A finished Wonder for player p, a few tiles beside their Town Center; its id.
func _put_wonder(w: World, p: int) -> int:
	var k := Economy.btype_of(w, "wonder")
	var s: Array = w.map.starts[p]
	var at := Vector2i(s[0] / 1000 + 4, s[1] / 1000 - 2)
	while not w.map.can_build(at.x, at.y, 5):
		at.y += 1
	var b := Economy.place(w, p, k, at.x, at.y)
	w.buildings.done[b] = 1
	w.buildings.hp[b] = w.bmods[p][k].hp
	return w.buildings.id[b]


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


## Twenty melee units on a Town Center (Dominic, 2026-10-13: "attacking buildings turns into
## fighting the pathfinding"): they spread round its walls, most of them strike within half a
## minute, from every side, and nobody hitting it is shoved about.
func _test_surround(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var r := rules_.duplicate(true)
	r.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("flat_test"), [race, race], r)
	var b := 1
	var tc: int = w.buildings.id[b]
	var ids := _spawn_n(w, "spear", 20, w.buildings.cx[b] * 1000 - 5000, w.buildings.cy[b] * 1000 - 5000)
	w.issue(0, Commands.ATTACK, {"ids": ids, "target": tc})
	var struck := {}
	var shoved := 0
	var sides := {}
	var mx: int = w.buildings.cx[b] * 1000 + w.buildings.sx[b] * 500
	var my: int = w.buildings.cy[b] * 1000 + w.buildings.sy[b] * 500
	var start := w.tick
	while w.tick < start + 600 and w.buildings.index_of(tc) >= 0:
		var held := {}
		for i in w.units.count():
			if w.units.foe[i] == tc and w.units.moving[i] == 0 and Combat._gap(w, i, -1, b) <= int(rules_.combat.melee_reach):
				held[w.units.id[i]] = Vector2i(w.units.x[i], w.units.y[i])
		w.step()
		for uid in held:
			var i := w.units.index_of(uid)
			shoved = maxi(shoved, absi(w.units.x[i] - held[uid].x) + absi(w.units.y[i] - held[uid].y))
		for e in w.events:
			if e.type == "hit" and e.to == tc and not struck.has(e.by):
				struck[e.by] = true
				var i := w.units.index_of(e.by)
				var dx: int = w.units.x[i] - mx
				var dy: int = w.units.y[i] - my
				sides[(0 if dx > 0 else 1) if absi(dx) > absi(dy) else (2 if dy > 0 else 3)] = true
	check(struck.size() >= 15, "surround: %d of 20 melee units strike a Town Center within 30 s" % struck.size())
	check(sides.size() == 4, "surround: they hit it from all sides (%d)" % sides.size())
	check(shoved <= 10, "surround: a unit hitting the wall isn't shoved (most in a tick %d milli-tiles)" % shoved)


## A group move ends in a formation (Dominic, 2026-10-13: "they should adopt a basic formation
## just to keep it from looking buggy"): every unit stands in a slot of its own, nobody
## overlaps, the archers stand behind the spearmen, units already in their slots aren't
## shoved about by the rest coming in, and it all holds still afterwards. An attack-move and a
## shift-queued move keep the formation too.
func _test_formation(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	for kind in [Commands.MOVE, Commands.ATTACK_MOVE, "queued"]:
		var w := _bare_world([race, race])
		var spears := _spawn_n(w, "spear", 20, 12000, 14000)
		var archers := _spawn_n(w, "archer", 10, 12000, 16000)
		var ids := spears + archers
		if kind == "queued":
			w.issue(0, Commands.MOVE, {"ids": ids, "x": 30000, "y": 22000})
			w.issue(0, Commands.MOVE, {"ids": ids, "x": 40000, "y": 40000, "queue": 1})
		else:
			w.issue(0, kind, {"ids": ids, "x": 40000, "y": 40000})
		var shoved := 0
		var settled := -1
		while w.tick < 4000 and settled < 0:
			var qx := w.units.x.duplicate()
			var qy := w.units.y.duplicate()
			var qm := w.units.moving.duplicate()
			w.step()
			for i in w.units.count():
				if qm[i] == 0 and w.units.moving[i] == 0 and w.tick > 60:
					shoved += absi(w.units.x[i] - qx[i]) + absi(w.units.y[i] - qy[i])
			if w.tick % 20 == 0 and w.tick > 200 and not 1 in w.units.moving and w.units.orders.all(func(o): return o.is_empty()):
				settled = w.tick
		var what := "formation (%s)" % kind
		check(settled > 0, "%s: settles (tick %d)" % [what, settled])
		var x0 := w.units.x.duplicate()
		var y0 := w.units.y.duplicate()
		for t in 200:
			w.step()
		var still := true
		var overlaps := 0
		var off_slot := 0
		var slots := {}
		var front := 1 << 30
		var back := -(1 << 30)
		for i in w.units.count():
			still = still and w.units.x[i] == x0[i] and w.units.y[i] == y0[i]
			slots[Vector2i(w.units.tx[i], w.units.ty[i])] = true
			if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.tx[i], w.units.ty[i]) > 400 * 400:
				off_slot += 1
			for j in range(i + 1, w.units.count()):
				var rr: int = w.units.radius[i] + w.units.radius[j]
				if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) < rr * rr * 81 / 100:
					overlaps += 1
			var ahead: int = w.units.x[i] + w.units.y[i]   # along the way they went: down and right
			if w.units.id[i] in archers:
				back = maxi(back, ahead)
			else:
				front = mini(front, ahead)
		check(slots.size() == ids.size(), "%s: %d slots for %d units" % [what, slots.size(), ids.size()])
		check(off_slot <= 2, "%s: everyone stands in its slot (%d off)" % [what, off_slot])
		check(overlaps == 0, "%s: no one overlaps (%d pairs)" % [what, overlaps])
		check(back < front, "%s: the archers stand behind the spearmen" % what)
		check(shoved < 2000, "%s: arrivals aren't shoved about (%d milli-tiles in all)" % [what, shoved])
		check(still, "%s: it holds still afterwards" % what)


## A mixed group's formation goes by role (milestone 22): foot soldiers in front, shooters behind
## them, healers at the back, and the riders on both flanks, outside the centre's width; it settles
## without overlaps and holds still.
func _test_role_formation(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	var w := _bare_world([race, race])
	var spears := _spawn_n(w, "spear", 12, 12000, 14000)
	var archers := _spawn_n(w, "archer", 8, 12000, 16000)
	var riders := _spawn_n(w, "large", 6, 14000, 15000)
	var healers := _spawn_n(w, "healer", 2, 11000, 15000)
	var mounted := riders.all(func(id): return "mounted" in w.types[w.units.kind[w.units.index_of(id)]].eval.tags)
	check(mounted, "role formation: the large slot rides")
	var ids: Array = spears + archers + riders + healers
	w.issue(0, Commands.MOVE, {"ids": ids, "x": 40000, "y": 40000})
	var settled := -1
	while w.tick < 4000 and settled < 0:
		w.step()
		if w.tick % 20 == 0 and w.tick > 200 and not 1 in w.units.moving:
			settled = w.tick
	check(settled > 0, "role formation: settles (tick %d)" % settled)
	var x0 := w.units.x.duplicate()
	var y0 := w.units.y.duplicate()
	for t in 200:
		w.step()
	var ahead := func(id): return w.units.tx[w.units.index_of(id)] + w.units.ty[w.units.index_of(id)]   # down and right
	var across := func(id): return w.units.tx[w.units.index_of(id)] - w.units.ty[w.units.index_of(id)]
	var lo := func(l: Array, f: Callable): return l.map(f).min()
	var hi := func(l: Array, f: Callable): return l.map(f).max()
	check(lo.call(spears, ahead) > hi.call(archers, ahead), "role formation: the spearmen stand ahead of the archers")
	check(lo.call(archers, ahead) > hi.call(healers, ahead), "role formation: the healers stand behind the archers")
	var foot: Array = spears + archers + healers
	var mid: int = (lo.call(foot, across) + hi.call(foot, across)) / 2
	var left := 0
	var right := 0
	for id in riders:
		var a: int = across.call(id)
		if a < lo.call(foot, across):
			left += 1
		elif a > hi.call(foot, across):
			right += 1
	check(left + right == riders.size() and left > 0 and right > 0,
		"role formation: the riders stand on both flanks (%d left, %d right of %d; centre %d)" % [left, right, riders.size(), mid])
	var overlaps := 0
	var still := true
	for i in w.units.count():
		still = still and w.units.x[i] == x0[i] and w.units.y[i] == y0[i]
		for j in range(i + 1, w.units.count()):
			var rr: int = w.units.radius[i] + w.units.radius[j]
			if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) < rr * rr * 81 / 100:
				overlaps += 1
	check(overlaps == 0, "role formation: no one overlaps (%d pairs)" % overlaps)
	check(still, "role formation: it holds still afterwards")


## Counter-aware targeting (milestone 22): a spearman with a footman and a rider ahead, the rider a
## little further, goes for the rider (its attack has a bonus against mounted or large); with
## counter_pull 0 it goes for the nearest, the footman.
func _test_counter_pick(gen) -> void:
	var race: Dictionary = gen.generate(PROMPTS[0], rules_)
	for pull in [-1, 0]:
		var w := _bare_world([race, race])
		if pull == 0:
			w.combat.counter_pull = 0
		var foot := _lone(w, 1, "infantry", 17000, 20500, "passive")
		var rider := _lone(w, 1, "large", 18000, 20500, "passive")
		var me := _lone(w, 0, "spear", 15000, 20500, "passive")
		var i := w.units.index_of(me)
		var d_foot := Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], _at(w, foot)[0], _at(w, foot)[1]))
		var d_rider := Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], _at(w, rider)[0], _at(w, rider)[1]))
		check(d_foot < d_rider and d_rider - d_foot < int(rules_.combat.counter_pull),
			"counter pick: the rider is a little further than the footman (%d v %d)" % [d_rider, d_foot])
		w.issue(0, Commands.STANCE, {"ids": [me], "stance": "aggressive"})
		for t in 60:
			w.step()
		var want := foot if pull == 0 else rider
		check(w.units.foe[w.units.index_of(me)] == want, "counter pick (pull %s): the spearman goes for the %s (foe %d; footman %d, rider %d)"
			% ["rules" if pull < 0 else "0", "footman" if pull == 0 else "rider", w.units.foe[w.units.index_of(me)], foot, rider])


## The Norse shield wall (milestone 22, Dominic: "super extra tight"): Norse shield infantry march
## shoulder to shoulder (Linden shields: form_gap), their riders don't, and a Greek phalanx with
## shields of its own keeps the usual gap. Neighbours' slots, side by side in the front row.
func _test_shield_wall(gen) -> void:
	var gaps := {}
	for prompt in ["vikings", PROMPTS[0]]:
		var race: Dictionary = gen.generate(prompt, rules_)
		var w := _bare_world([race, race])
		var spears := _spawn_n(w, "spear", 12, 12000, 14000)
		var i := w.units.index_of(spears[0])
		var t: Dictionary = w.types[w.units.kind[i]]
		if prompt == "vikings":
			check("shield" in t.eval.tags, "shield wall: Norse spearmen carry shields")
		w.issue(0, Commands.MOVE, {"ids": spears, "x": 40000, "y": 40000})
		w.step()
		while w.tick < 4000 and (w.tick < 200 or 1 in w.units.moving):
			w.step()
		var best := 1 << 30
		for a in spears:
			for b in spears:
				if a < b:
					var ia := w.units.index_of(a)
					var ib := w.units.index_of(b)
					best = mini(best, Fixed.isqrt(Fixed.dist2(w.units.x[ia], w.units.y[ia], w.units.x[ib], w.units.y[ib])))
		gaps[prompt] = best - 2 * w.units.radius[i]
		if prompt == "vikings":
			var riders := _spawn_n(w, "large", 1, 12000, 16000)
			var r: Dictionary = w.types[w.units.kind[w.units.index_of(riders[0])]]
			check(int(t.form_gap) < 0 and ("mounted" not in r.eval.tags or int(r.form_gap) == 0),
				"shield wall: the Norse foot close up (form_gap %d), their riders don't (%d)" % [t.form_gap, r.form_gap])
	check(absi(gaps["vikings"]) <= World.SLOT_ARRIVE and gaps[PROMPTS[0]] >= World.FORM_GAP - World.SLOT_ARRIVE,   # (each stops within SLOT_ARRIVE of its slot)
		"shield wall: Norse spearmen stand %d milli-tiles apart (body to body), frogs %d" % [gaps["vikings"], gaps[PROMPTS[0]]])


func _spawn_n(w: World, slot: String, n: int, x: int, y: int) -> Array:
	var before := w.next_id
	w.issue(0, Commands.SPAWN, {"slot": slot, "count": n, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	return range(before, w.next_id)


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


## Shooters stand still while their target is in reach (Dominic: "my crossbows are slowly
## moving forward on each shot"); one out of reach walks just into reach and stops.
func _test_ranged_holds(gen) -> void:
	var race: Dictionary = gen.generate("sewer rats with crossbows", rules_)
	var y := 20500
	var w := _bare_world([race, race])
	var k := w.type_of(0, "archer")
	var reach: int = w.types[k].reach
	var shots := 20 * int(w.types[k].reload)
	# Ordered, in reach: 20 shots without a step.
	var me := _lone(w, 0, "archer", 15000, y, "aggressive")
	var foe := _lone(w, 1, "large", 15000 + reach - 1000, y, "passive")
	w.units.hp[w.units.index_of(foe)] = 1 << 24
	w.issue(0, Commands.ATTACK, {"ids": [me], "target": foe})
	var r := _watch(w, shots, me)
	check(r.far == 0 and r.hits[0] >= 19, "an archer in reach doesn't move over 20 shots (went %d, %d hits)" % [r.far, r.hits[0]])
	# Ordered, out of reach: walks just into reach, then stands.
	w = _bare_world([race, race])
	me = _lone(w, 0, "archer", 15000, y, "aggressive")
	foe = _lone(w, 1, "large", 15000 + reach + 3000, y, "passive")
	w.units.hp[w.units.index_of(foe)] = 1 << 24
	w.issue(0, Commands.ATTACK, {"ids": [me], "target": foe})
	_watch(w, 200, me)
	var i := w.units.index_of(me)
	var gap := Combat._gap(w, i, w.units.index_of(foe), -1)
	r = _watch(w, shots, me)
	check(gap <= reach and gap > reach - 2 * w.units.speed[i] and r.far == 0 and r.hits[0] >= 19,
		"an archer out of reach walks just into it and stands (gap %d of reach %d, then went %d, %d hits)" % [gap, reach, r.far, r.hits[0]])
	# Attack-move, a line of shooters: the walk-back to the move's end no longer drags them on.
	w = _bare_world([race, race])
	foe = _lone(w, 1, "large", 24000, y, "passive")
	w.units.hp[w.units.index_of(foe)] = 1 << 24
	w.issue(0, Commands.SPAWN, {"slot": "archer", "count": 8, "x": 14000, "y": y})
	while w.units.count() < 9:
		w.step()
	var mine := []
	for j in w.units.count():
		if w.units.owner[j] == 0:
			mine.append(w.units.id[j])
	w.issue(0, Commands.ATTACK_MOVE, {"ids": mine, "x": 40000, "y": y})
	for t in 400:
		w.step()
	var at := {}
	for id in mine:
		at[id] = _at(w, id)
	var hits := 0
	for t in shots:
		w.step()
		for e in w.events:
			if e.type == "hit" and mine.has(e.by):
				hits += 1
	var crept := 0
	for id in mine:
		var now := _at(w, id)
		crept = maxi(crept, Fixed.isqrt(Fixed.dist2(now[0], now[1], at[id][0], at[id][1])))
	check(crept < 100 and hits >= 8 * 19, "8 attack-moving archers hold their line over 20 shots (most moved %d, %d hits)" % [crept, hits])


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
func _test_crossing(races: Array, map_id: String, engines := false) -> void:
	var map: SimMap = SimMap.load_id(map_id)
	var bare := rules_.duplicate(true)   # movement only: no town centres or starting workers
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, map, races, bare)
	var src: Array = map.starts[0]
	var dst: Array = map.starts[1]
	for u in races[0].units:   # the foot and horse lines, or (engines) the siege engines on their own
		if u.recipe.has("crew") == engines:
			w.issue(0, Commands.SPAWN, {"slot": u.recipe.slot, "count": CROSS_ENGINES if engines else CROSS_UNITS, "x": src[0], "y": src[1]})
	while w.units.count() == 0:
		w.step()
	var ids := Array(w.units.id)
	var groups := (ids.size() + CROSS_UNITS - 1) / CROSS_UNITS   # (the engines: one group, last)
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
	for i in w.units.count():
		if w.units.moving[i] == 1:
			print("  moving: #%d %s at %d,%d target %d,%d group %d stuck %d" % [w.units.id[i], w.types[w.units.kind[i]].slot, w.units.x[i], w.units.y[i], w.units.tx[i], w.units.ty[i], w.units.group[i], w.units.stuck[i]])
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


# --- save and load ------------------------------------------------------------

## A match against two bots, saved at 4 minutes (a person's order still waiting to run), written
## to JSON, loaded (re-run headless to the saved tick) and played on to 7 minutes: the same
## hashes as the match never stopped, so the bots came back as they were (D-140).
func _test_save_load(lib, gen) -> void:
	const AT := 4800
	const TO := 8400
	var rules = DataLib.load_rules("default")
	var races := []
	for p in PROMPTS:
		races.append(gen.generate(p, rules))
	var world := World.new(SEED, SimMap.load_id("reed_meadow"), races, rules)
	var seats := [{"player": 1, "level": "hard", "from_seq": world.commands.next_seq.get(1, 0)}]
	var you := EcoBot.new(0)   # "you": what it orders is stored like a person's clicks
	var bot := Bot.new(1, {}, "hard")
	while world.tick < AT:
		you.think(world)
		bot.think(world)
		world.step()
	var tc: int = world.buildings.id[0]
	world.issue(0, Commands.RALLY, {"building": tc, "x": 9000, "y": 9000})   # issued, not run yet
	var t0 := Time.get_ticks_msec()
	var path := "user://test_saves/save_load.save"
	SaveGame.save(SaveGame.record(world, seats, [bot], {"active": 0}), path)
	var save_ms := Time.get_ticks_msec() - t0
	var you_after := EcoBot.new(0)   # after the save "you" plays on the same way in both matches
	while world.tick < TO:
		you_after.think(world)
		bot.think(world)
		world.step()

	t0 = Time.get_ticks_msec()
	var rep := SaveGame.load_file(path)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	DirAccess.remove_absolute(path)
	check(rep.commands.all(func(c): return c.player == 0), "a save keeps your orders, not the bot's")
	check(SaveGame.problem(rep, lib) == "", "the save loads in this version")
	var ld := SaveGame.begin(rep, lib)
	var unit_ids: PackedInt32Array = rep.snapshot.world.units.id.duplicate()
	var world_types_hp: Array = ld.world.types.map(func(t): return t.hp)   # (this build's stats, as at the save)
	var load_ms := Time.get_ticks_msec() - t0
	check(ld.same and ld.changed.is_empty() and ld.migrated, "this build's save loads as it was, on this build's stats (changed: %s)" % [ld.changed])
	var b: World = ld.world
	var you_b := EcoBot.new(0)
	while b.tick < TO:
		you_b.think(b)
		ld.bots[0].think(b)
		b.step()
	check(b.hashes == world.hashes, "played on from the save, the match matches one never stopped")
	check(b.state_hash() == world.state_hash(), "and ends at the same state")

	check(rep.snapshot.world.units.id == unit_ids, "playing on from a save leaves the save as it was")

	# A save from a build with other stats: the match goes on with this build's, every unit keeping
	# its share of health; one whose tables no longer line up keeps its own.
	var weak := rep.duplicate(true)
	for t in weak.snapshot.world.types:
		t.hp = maxi(1, t.hp / 2)
	for bt in weak.snapshot.world.btypes:
		bt.hp = maxi(1, bt.hp / 2)
	var ld_w := SaveGame.begin(weak, lib)
	var ww: World = ld_w.world
	var su: Dictionary = weak.snapshot.world.units
	var share_ok := true
	for i in ww.units.count():
		var k: int = ww.units.kind[i]
		if ww.types[k].player != ww.gaia and absi(ww.units.hp[i] * 100 / ww.types[k].hp - su.hp[i] * 100 / weak.snapshot.world.types[k].hp) > 4:
			share_ok = false
	check(ld_w.migrated and ww.types.size() == ld.world.types.size(), "a save from a build with other stats migrates")
	check(range(ww.types.size()).all(func(k): return ww.types[k].hp == world_types_hp[k]), "its unit types take this build's health")
	check(share_ok, "its units keep their share of health")
	var frozen := rep.duplicate(true)
	frozen.snapshot.world.btypes.pop_back()   # a building this build added: the tables don't line up
	var ld_f := SaveGame.begin(frozen, lib)
	check(not ld_f.migrated and ld_f.world.btypes.size() == frozen.snapshot.world.btypes.size(), "one whose tables no longer line up keeps its own")

	# A save from an older build: a unit field, a world variable and a bot variable it didn't have
	# yet, one it had that this build dropped, a data key this build added, and a class it replaced.
	var old := rep.duplicate(true)
	var sw: Dictionary = old.snapshot.world
	sw.units.erase("wtime")
	sw.erase("pour_at")
	old.snapshot.bots[0].erase("_resting")
	sw.units["a_field_since_dropped"] = PackedInt32Array([1, 2, 3])
	for bt in sw.btypes:
		bt.erase("hp")
	sw.shots[SaveGame.SCRIPT] = "res://src/sim/gone_since.gd"
	var ld_old := SaveGame.begin(old, lib)
	var o: World = ld_old.world
	check(o.units.wtime.size() == o.units.count(), "the new per-unit field is padded to every unit")
	check(o.btypes.all(func(bt): return bt.has("hp")), "data keys this build added come in")
	check(ld_old.changed.size() >= 5, "and the load says what changed: %s" % [ld_old.changed])
	var units_before := o.units.count()
	for i in 1200:
		ld_old.bots[0].think(o)
		o.step()
	check(o.tick == AT + 1200 and o.units.count() > units_before / 2, "the old save plays on a minute with its bot (%d units)" % o.units.count())
	check(world.units.count() > 40, "it was a real match (%d units)" % world.units.count())
	print("save/load: %d KB, %d commands; save %d ms, load %d ms" % [bytes / 1024, rep.commands.size(), save_ms, load_ms])


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


# --- walls you stand on (milestone 16) ---------------------------------------

## Walls you stand on: the rats (player 0) in a stone ring round their start with gatehouses north
## and south and wall towers; archers sent onto the east wall climb up by a way up and spread over
## its standing places; up there they aren't pushed about, shoot a tile further, and melee below
## can't touch them; sent into the town they climb down; a wall tile knocked down becomes rubble
## (those on it fall) that a worker rebuilds for less. Run twice: the same hash.
func _test_walls(races: Array) -> void:
	var rats_first := [races[1], races[0]]   # (the frogs build no stone walls of their own: milestone 14's lacks)
	var a := _walls_run(rats_first, true)
	var b := _walls_run(rats_first, false)
	check(a.state_hash() == b.state_hash(), "walls: the same commands give the same state hash")
	_test_wall_over_hill(races)


## Walls run straight over a hill (Dominic, 2026-10-17, D-154): every wall and palisade piece of a
## line across Reed Meadow's team hill can go down, cliffs and ramps included; a gate never stands
## on a cliff (it would open the cliff to its side), but still goes over a wall on flat ground.
func _test_wall_over_hill(races: Array) -> void:
	var bare := rules_.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	var w := World.new(SEED, SimMap.load_id("reed_meadow_2v2"), [races[1], races[0], races[1], races[0]], bare, [0, 1, 0, 1])
	w.ages[0] = 3
	var m = w.map
	var y := 18
	var slopes := 0
	for kind in ["wall", "palisade"]:
		var k := Economy.btype_of(w, kind)
		var refused := []
		for x in range(10, 29):
			if not Economy.can_place(w, 0, k, x, y):
				refused.append(x)
			if kind == "wall" and (m.cliff[y * m.width + x] == 1 or m.ramp[y * m.width + x] == 1):
				slopes += 1
		check(refused.is_empty(), "wall over a hill: every %s piece of a line across the hill can go down (refused at x %s)" % [kind, refused])
	check(slopes >= 4, "wall over a hill: the line crosses cliffs and ramps (%d cells)" % slopes)
	var wk := Economy.btype_of(w, "wall")
	for x in range(10, 29):
		Fortify._put(w, 0, wk, x, y, 0)
	var gk := Economy.btype_of(w, "stone_gate")
	var cliff_x := -1
	for x in range(11, 27):
		if m.cliff[y * m.width + x] == 1:
			cliff_x = x
			break
	check(cliff_x > 0 and not Economy.can_place(w, 0, gk, cliff_x - 1, y, 0) and not Economy.can_place(w, 0, gk, cliff_x, y, 0),
		"wall over a hill: no gate over the wall on a cliff (x %d)" % cliff_x)
	check(Economy.can_place(w, 0, gk, 25, y, 0), "wall over a hill: a gate still goes over the wall on flat ground")


const Fortify := preload("res://src/sim/fortify.gd")
const Walls := preload("res://src/sim/walls.gd")
const Repair := preload("res://src/sim/repair.gd")
const Modes := preload("res://src/sim/modes.gd")


func _walls_run(races: Array, checks_on: bool) -> World:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for p in 2:
		w.ages[p] = 3
		Tech.retype(w, p)
		Tech.refresh(w, p)
	var c := func(ok: bool, what: String) -> void:
		if checks_on:
			check(ok, what)
	var ring := Fortify.ring(w, 0, 12, 12, 6, {"wall": "wall", "gate": "stone_gate", "tower": "wall_tower", "tower_every": 4, "gates": ["n", "s"]})
	c.call(ring.size() > 30, "walls: a ring goes up (%d pieces)" % ring.size())
	var tk := Economy.btype_of(w, "wall_tower")
	c.call(Economy.can_place(w, 0, tk, 18, 9) and not Economy.can_place(w, 1, tk, 18, 9), "walls: a wall tower drops onto its owner's wall tile")
	var archers := _spawn_n(w, "archer", 6, 12500, 12500)
	var east := Vector2i(18500, 8500)
	w.issue(0, Commands.MOVE, {"ids": archers, "x": east.x, "y": east.y})
	var up := func() -> int:
		var n := 0
		for id in archers:
			var i := w.units.index_of(id)
			if i >= 0 and w.units.perch[i] != 0 and w.units.wgoal[i] == 0:
				n += 1
		return n
	var climbed := false
	for t in 900:
		w.step()
		for e in w.events:
			if e.type == "climb" and e.up:
				climbed = true
		if up.call() == archers.size():
			break
	c.call(climbed and up.call() == archers.size(), "walls: six archers climb onto the east wall (%d up)" % up.call())
	var per := {}
	var on_walk := true
	for id in archers:
		var i := w.units.index_of(id)
		var cell: int = w.units.perch[i] - 1
		per[cell] = int(per.get(cell, 0)) + 1
		on_walk = on_walk and Walls.places(w, cell) > 0 and w.map.cell_of(w.units.x[i], w.units.y[i]) == cell
		on_walk = on_walk and absi(w.units.x[i] / 1000 - 18) <= 1
	c.call(on_walk, "walls: they stand on walkway cells of the east wall")
	c.call(per.keys().all(func(k): return per[k] <= Walls.places(w, k)), "walls: no more on a cell than its places (%s)" % [per])
	# Still up there (once on their places): nobody shoves them about.
	for t in 40:
		w.step()
	var at := {}
	for id in archers:
		var i := w.units.index_of(id)
		at[id] = Vector2i(w.units.x[i], w.units.y[i])
	for t in 40:
		w.step()
	c.call(archers.all(func(id): var i := w.units.index_of(id); return Vector2i(w.units.x[i], w.units.y[i]) == at[id]), "walls: up there they stand still")
	# A foe a tile beyond an archer's reach, out in the field east of the wall: shot from up there.
	var a0 := w.units.index_of(archers[0])
	var t0: Dictionary = w.types[w.units.kind[a0]]
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 1, "x": w.units.x[a0] + t0.reach + 700 + w.units.radius[a0] + 300, "y": w.units.y[a0]})
	var far_shot := false   # a shot from up on the wall at a foe further off than the archer's reach on the ground
	for t in 200:
		w.step()
		for e in w.events:
			if e.type == "shot" and e.by in archers and Fixed.isqrt(Fixed.dist2(e.x0, e.y0, e.x, e.y)) > t0.reach + 2 * w.units.radius[a0] + 200:
				far_shot = true
	c.call(far_shot, "walls: from the wall an archer reaches a tile further")
	# Spears under the wall can't hit those on it.
	var spears := []
	for k in 4:
		spears.append(_lone(w, 1, "spear", 19700, 7000 + k * 600, "aggressive"))
	var melee_hits := 0
	for t in 300:
		w.step()
		for e in w.events:
			if e.type == "hit" and e.to in archers and e.by in spears:
				melee_hits += 1
	c.call(melee_hits == 0, "walls: spears below can't reach those on the wall (%d hits)" % melee_hits)
	for id in spears:
		var i := w.units.index_of(id)
		if i >= 0:
			w.issue(1, Commands.STOP, {"ids": [id]})
	# Down into the town.
	var stay: int = archers[5]
	w.issue(0, Commands.MOVE, {"ids": archers.slice(0, 5), "x": 12500, "y": 12000})
	for t in 900:
		w.step()
		if archers.slice(0, 5).all(func(id): var i := w.units.index_of(id); return i < 0 or (w.units.perch[i] == 0 and w.units.moving[i] == 0)):
			break
	var inside := 0
	for id in archers.slice(0, 5):
		var i := w.units.index_of(id)
		if i >= 0 and w.units.perch[i] == 0 and w.units.x[i] > 6999 and w.units.x[i] < 18000 and w.units.y[i] > 6999 and w.units.y[i] < 18000:
			inside += 1
	c.call(inside == 5, "walls: sent into the town, they climb down inside (%d of 5)" % inside)
	# A wall tile knocked down: rubble, and the one standing on it falls.
	var si := w.units.index_of(stay)
	var cell: int = w.units.perch[si] - 1
	var b := w.buildings.index_of(w.map.occupied[cell])
	var bhurt := PackedInt32Array()
	bhurt.resize(w.buildings.count())
	bhurt[b] = 99999
	var hurt := PackedInt32Array()
	hurt.resize(w.units.count())
	Combat._apply(w, hurt, hurt.duplicate(), bhurt)
	var fell := false
	for t in 3:
		w.step()
		for e in w.events:
			if e.type == "fall" and e.id == stay:
				fell = true
	si = w.units.index_of(stay)
	c.call(fell and si >= 0 and w.units.perch[si] == 0, "walls: the archer on a fallen wall tile falls (and lives)")
	c.call(w.map.terrain_at(cell) == "wall_rubble" and w.map.walk[cell] == 1 and w.rubble.has(cell), "walls: a fallen wall tile is walkable rubble")
	var rebuild := Walls.rebuild_of(w, 0, cell)
	c.call(rebuild.get("building", "") == "wall", "walls: its owner may rebuild the wall there")
	var worker := _spawn_at(w, 0, "worker", 16500, 12500)
	w.stock[w.resources.find("stone")][0] = 100
	var stone: int = w.stock[w.resources.find("stone")][0]
	w.issue(0, Commands.BUILD, {"ids": [worker], "building": "wall", "cx": cell % w.map.width, "cy": cell / w.map.width})
	for t in 600:
		w.step()
		var nb := w.buildings.index_of(w.map.occupied[cell])
		if nb >= 0 and w.buildings.done[nb] == 1:
			break
	var paid: int = stone - w.stock[w.resources.find("stone")][0]
	var full: int = w.btypes[Economy.btype_of(w, "wall")].cost[w.resources.find("stone")]
	c.call(paid == full * int(w.walk_cfg.repair_pct) / 100, "walls: rebuilding a breach costs %d%% (%d of %d stone)" % [w.walk_cfg.repair_pct, paid, full])
	var nb2 := w.buildings.index_of(w.map.occupied[cell])
	c.call(nb2 >= 0 and w.buildings.done[nb2] == 1 and w.map.terrain_at(cell) != "wall_rubble" and not w.rubble.has(cell), "walls: the breach is walled up again, the rubble gone")
	# Repair: a wall at half health mended by the worker (paying some stone), and a ram.
	var wb: int = w.buildings.index_of(w.map.occupied[cell + w.map.width])
	var full_hp: int = w.bmods[0][w.buildings.kind[wb]].hp
	w.buildings.hp[wb] = full_hp / 2
	stone = w.stock[w.resources.find("stone")][0]
	w.issue(0, Commands.REPAIR, {"ids": [worker], "target": w.buildings.id[wb]})
	for t in 2400:
		w.step()
		if w.buildings.hp[wb] >= full_hp:
			break
	c.call(w.buildings.hp[wb] == full_hp, "walls: a worker mends a damaged wall (%d of %d hp)" % [w.buildings.hp[wb], full_hp])
	c.call(w.stock[w.resources.find("stone")][0] < stone or full * int(w.repair_cfg.cost_pct) / 100 / 20 == 0, "walls: mending costs a little stone")
	# The frogs' ram is a beast (healers mend it, not carpenters); the rats' is a machine their workers mend.
	var turtle := _lone(w, 1, "ram", 40500, 40500, "passive")
	w.units.hp[w.units.index_of(turtle)] = 40
	c.call(not Repair.can_mend(w, 1, turtle), "walls: a beast ram isn't for mending")
	var ram := _lone(w, 0, "ram", 16500, 13500, "passive")
	var ri := w.units.index_of(ram)
	w.units.hp[ri] = 40
	w.stock[w.resources.find("wood")][0] = 500
	w.stock[w.resources.find("gold")][0] = 500
	w.issue(0, Commands.REPAIR, {"ids": [worker], "target": ram})
	for t in 600:
		w.step()
	ri = w.units.index_of(ram)
	c.call(w.units.hp[ri] > 60, "walls: a worker mends a machine ram (40 -> %d hp)" % w.units.hp[ri])
	return w


## Ways over a wall (milestone 16): the rats (player 1) besiege the frogs' stone ring (gatehouses, no wall towers). A rat worker
## raises a ladder against the east wall (only against an enemy walkway); rat spears climb it onto
## the frogs' wall; a frog archer settling at its top with no rat there pushes it off. A siege
## tower pushed up to the south wall docks; rat swordsmen climb through it, and sent into the town
## they come down the frogs' own stairs inside. Twice: the same hash.
func _test_siege_ways(races: Array) -> void:
	var a := _ways_run(races, true)
	var b := _ways_run(races, false)
	check(a.state_hash() == b.state_hash(), "siege ways: the same commands give the same state hash")


func _ways_run(races: Array, checks_on: bool) -> World:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules_)
	for p in 2:
		w.ages[p] = 3
		Tech.retype(w, p)
		Tech.refresh(w, p)
		w.stock[w.resources.find("wood")][p] = 2000
		w.stock[w.resources.find("gold")][p] = 2000
	var c := func(ok: bool, what: String) -> void:
		if checks_on:
			check(ok, what)
	Fortify.ring(w, 0, 12, 12, 6, {"wall": "wall", "gate": "stone_gate", "tower": "", "gates": ["n", "s"]})   # (no wall towers: they would shoot the rats)
	var lk := Economy.btype_of(w, "ladder")
	c.call(Economy.can_place(w, 1, lk, 19, 9) and not Economy.can_place(w, 0, lk, 19, 9) and not Economy.can_place(w, 1, lk, 21, 9),
		"siege ways: a ladder goes only against an enemy wall")
	var rat := _lone(w, 1, "worker", 22500, 9500, "passive")
	w.issue(1, Commands.BUILD, {"ids": [rat], "building": "ladder", "cx": 19, "cy": 9})
	var ladder := 0
	for t in 600:
		w.step()
		var b := w.buildings.index_of(w.map.occupied[9 * w.map.width + 19])
		if b >= 0 and w.buildings.done[b] == 1:
			ladder = w.buildings.id[b]
			break
	c.call(ladder != 0 and w.map.walk[9 * w.map.width + 19] == 1, "siege ways: the ladder goes up (walked over at the wall's foot)")
	var spears := []
	for k in 3:
		spears.append(_lone(w, 1, "spear", 23500, 8500 + k * 700, "stand"))
	w.issue(1, Commands.MOVE, {"ids": spears, "x": 18500, "y": 9500})
	var up := func(ids: Array) -> int:
		var n := 0
		for id in ids:
			var i := w.units.index_of(id)
			if i >= 0 and w.units.perch[i] != 0:
				n += 1
		return n
	for t in 600:
		w.step()
		if up.call(spears) == spears.size():
			break
	c.call(up.call(spears) == spears.size(), "siege ways: rat spears climb the ladder onto the frogs' wall (%d up)" % up.call(spears))
	# Down off the wall again by their ladder, then a frog archer takes the ladder's top: pushed off.
	w.issue(1, Commands.MOVE, {"ids": spears, "x": 23500, "y": 9500})
	for t in 400:
		w.step()
		if up.call(spears) == 0:
			break
	c.call(up.call(spears) == 0, "siege ways: they climb down their ladder")
	var archer := _lone(w, 0, "archer", 15500, 9500, "stand")
	w.issue(0, Commands.MOVE, {"ids": [archer], "x": 18500, "y": 9500})
	var pushed := false
	for t in 600:
		w.step()
		for e in w.events:
			if e.type == "die" and e.id == ladder:
				pushed = true
		if pushed:
			break
	c.call(pushed and w.map.walk[9 * w.map.width + 19] == 1 and w.map.walk_over[9 * w.map.width + 19] == 0, "siege ways: a defender at its top pushes the ladder off")
	# A siege tower up to the south wall; swordsmen go up through it and down into the town.
	var tower := _lone(w, 1, "siege_tower", 15500, 23500, "passive")
	w.issue(1, Commands.MOVE, {"ids": [tower], "x": 15500, "y": 18500})
	var docked := false
	for t in 600:
		w.step()
		var ti := w.units.index_of(tower)
		if Walls.docked_at(w, ti) >= 0:
			docked = true
			break
	c.call(docked, "siege ways: the siege tower docks against the south wall")
	var swords := []
	for k in 3:
		swords.append(_lone(w, 1, "infantry", 14500 + k * 700, 24500, "stand"))
	w.issue(1, Commands.MOVE, {"ids": swords, "x": 15500, "y": 18500})
	for t in 600:
		w.step()
		if up.call(swords) == swords.size():
			break
	c.call(up.call(swords) == swords.size(), "siege ways: swordsmen climb through the tower onto the wall (%d up)" % up.call(swords))
	w.issue(1, Commands.MOVE, {"ids": swords, "x": 11500, "y": 14500})
	for t in 900:
		w.step()
		if up.call(swords) == 0:
			break
	var inside := 0
	for id in swords:
		var i := w.units.index_of(id)
		if i >= 0 and w.units.perch[i] == 0 and w.units.x[i] > 6999 and w.units.x[i] < 18000 and w.units.y[i] > 6999 and w.units.y[i] < 18000:
			inside += 1
	c.call(inside == swords.size(), "siege ways: sent into the town, they come down the frogs' stairs inside (%d of %d)" % [inside, swords.size()])
	# The defenders' tools: a frog on the north gatehouse pours on a rat ram at the gate.
	var guard := _lone(w, 0, "spear", 12500, 9500, "stand")
	w.issue(0, Commands.MOVE, {"ids": [guard], "x": 12500, "y": 6500})
	var ram := _lone(w, 1, "ram", 12500, 3000, "passive")
	w.issue(1, Commands.ATTACK, {"ids": [ram], "target": w.map.occupied[6 * w.map.width + 12]})
	var pours := 0
	var scalded := 0
	for t in 600:
		w.step()
		for e in w.events:
			if e.type == "pour":
				pours += 1
			if e.type == "hit" and e.get("pour", false) and e.to == ram:
				scalded += int(e.damage)
	c.call(pours >= 2 and scalded > 0, "siege ways: a manned gatehouse pours on the ram at its gate (%d pours, %d damage)" % [pours, scalded])
	return w


## Game modes (milestone 16, src/sim/modes.gd) on Siege Vale. Fortress: both sides in age 2 behind
## a stone ring with their garrison up on it, the stockpile set. Siege: player 0 walled in age 3,
## player 1 with an army and engines and no town; the attackers are out when the hold timer runs
## out (the defenders win), or when they've nothing left. The same setup twice: the same hash.
func _test_modes(races: Array, gen) -> void:
	var walled := func(w: World, p: int) -> int:
		var n := 0
		for b in w.buildings.count():
			if w.buildings.owner[b] == p and w.btypes[w.buildings.kind[b]].walkway > 0:
				n += 1
		return n
	var up := func(w: World, p: int) -> int:
		var n := 0
		for i in w.units.count():
			if w.units.owner[i] == p and w.units.perch[i] != 0:
				n += 1
		return n
	var fr := rules_.duplicate(true)
	fr.mode = "fortress"
	var f := World.new(SEED, SimMap.load_id("siege_vale"), races, fr)
	var fm: Dictionary = Modes.load_modes().fortress
	for p in 2:
		check(f.ages[p] == 2 and walled.call(f, p) >= 50, "modes: Fortress walls side %d in, in age 2 (%d pieces)" % [p, walled.call(f, p)])
		check(up.call(f, p) == int(fm.garrison.archer) + int(fm.garrison.skirmisher), "modes: Fortress garrison side %d up on its wall (%d)" % [p, up.call(f, p)])
		check(f.stock[f.resources.find("stone")][p] == int(fm.stock.stone), "modes: Fortress stockpile")
	var sr := rules_.duplicate(true)
	sr.mode = "siege"
	var s := World.new(SEED, SimMap.load_id("siege_vale"), races, sr)
	var s2 := World.new(SEED, SimMap.load_id("siege_vale"), races, sr)
	check(s.state_hash() == s2.state_hash(), "modes: the same mode sets up the same")
	check(s.started_with_town[0] == 1 and s.started_with_town[1] == 0 and walled.call(s, 0) >= 50 and walled.call(s, 1) == 0, "modes: Siege walls the defenders in, the attackers have no town")
	var engines := 0
	for i in s.units.count():
		if s.units.owner[i] == 1 and s.types[s.units.kind[i]].slot in ["ram", "catapult", "siege_tower"]:
			engines += 1
	check(engines >= 5 and s.ages[1] == 3, "modes: the attackers bring engines (%d)" % engines)
	for t in 60:
		s.step()
	check(s.winner < 0 and s.defeated[1] == 0, "modes: an attacker with an army is in the game")
	s.tick = int(s.mode_cfg.hold_minutes) * 1200 - 40
	for t in 80:
		s.step()
	check(s.winner == s.teams[0], "modes: the defenders win when the hold timer runs out")
	for i in range(s2.units.count() - 1, -1, -1):
		if s2.units.owner[i] == 1:
			s2.units.remove_at(i)
	for t in 40:
		s2.step()
	check(s2.winner == s2.teams[0], "modes: an attacker with nothing left is out")
	_test_modes_lift_lacks(gen)


## The modes fill the gap (Dominic, 2026-10-13: "just in siege mode we fill the gap"): a race that
## lacks walls (the centaurs) can't build or mend them in a normal match; in Siege and Fortress
## every side can (data/modes.json lift_lacks), defenders and attackers alike, and rebuild a breach.
func _test_modes_lift_lacks(gen) -> void:
	var centaurs: Dictionary = gen.generate("centaur romans", rules_)
	var both := [centaurs, centaurs]
	var std := World.new(SEED, SimMap.load_id("siege_vale"), both, rules_)
	var ids := ["wall", "stone_gate", "wall_tower", "palisade"]
	check(Economy.lacks(std, 0, "wall"), "modes: the centaurs lack stone walls in a normal match (the case this tests)")
	for id in ["wall", "stone_gate", "palisade"]:   # (what the centaurs lack; a wall tower drops onto a wall they can't build)
		check(Economy.why_not_build(std, 0, Economy.btype_of(std, id)) == "not in this race's tech tree", "modes: no %s for centaurs in a normal match" % id)
	var wk := Economy.btype_of(std, "wall")
	var nb := Fortify._put(std, 0, wk, 5, 5, 0)   # (one handed to them all the same)
	var bi := std.buildings.index_of(nb)
	std.buildings.hp[bi] -= 100
	check(not Repair.can_mend(std, 0, nb), "modes: centaurs can't mend a stone wall in a normal match")
	for mode in ["siege", "fortress"]:
		var r := rules_.duplicate(true)
		r.mode = mode
		var w := World.new(SEED, SimMap.load_id("siege_vale"), both, r)
		for p in 2:
			for id in ids:
				check(Economy.why_not_build(w, p, Economy.btype_of(w, id)) == "", "modes: %s side %d (centaurs) may build a %s" % [mode, p, id])
		var wall := -1
		for b in w.buildings.count():
			if w.buildings.owner[b] == 0 and w.btypes[w.buildings.kind[b]].id == "wall":
				wall = b
				break
		check(wall >= 0, "modes: %s walls the centaurs in" % mode)
		var id: int = w.buildings.id[wall]
		w.buildings.hp[wall] -= 100
		check(Repair.can_mend(w, 0, id), "modes: %s centaurs may mend their stone wall" % mode)
		var cell: int = w.buildings.cy[wall] * w.map.width + w.buildings.cx[wall]
		var bhurt := PackedInt32Array()
		bhurt.resize(w.buildings.count())
		bhurt[wall] = 99999
		var hurt := PackedInt32Array()
		hurt.resize(w.units.count())
		Combat._apply(w, hurt, hurt.duplicate(), bhurt)
		w.step()
		check(Walls.rebuild_of(w, 0, cell).get("building", "") == "wall", "modes: %s centaurs may rebuild a breach in their wall" % mode)
	var after := World.new(SEED, SimMap.load_id("siege_vale"), both, rules_)
	check(Economy.lacks(after, 0, "wall"), "modes: a mode's lift doesn't reach a later normal match's centaurs (Identity's shared copy untouched)")
