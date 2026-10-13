extends SceneTree
## Where a tick goes: World.step's parts (and the bots' thinking) timed over a bot match: two bots
## on a 1v1 map, four bots in their teams on a four-start map. Prints per system the average and
## worst, the tick's average, p99 and worst, what the ten worst ticks spent their time on, and the
## state hash at the end (two branches playing the same match must agree where behaviour didn't change).
## Milestone 15's tick-budget checks.
## Run: godot --headless --path . --script res://tests/sim_profile.gd -- [map_id] [minutes] [peace]
## The map "test_sim" plays test_sim.gd's timed match instead (flat_test, two armies of 99
## marching about by script, no bots): the 3 ms budget's own benchmark.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Animals := preload("res://src/sim/animals.gd")
const Combat := preload("res://src/sim/combat.gd")
const Heal := preload("res://src/sim/heal.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const Match := preload("res://src/sim/match.gd")
const Fog := preload("res://src/sim/fog.gd")
const Trails := preload("res://src/sim/trails.gd")

const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const SEED := 20261010
const TICKS := 12000
const PER_SLOT := 11
const ORDERS_EVERY := 10

var rules_: Dictionary

const NAMES := ["bots", "commands", "train+tech", "work", "garrison", "animals", "spatial", "heal", "combat",
	"match", "fog", "trails", "next_orders", "sync_map", "solve", "move", "separate", "hash"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "reed_meadow_2v2"
	var minutes := int(args[1]) if args.size() > 1 else 20
	var peace := args.size() > 2 and args[2] == "peace"
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules: Dictionary = DataLib.load_json("res://data/rules/default.json")
	var cfg := Bot.load_config().duplicate(true)
	if peace:
		for wv in cfg.military.waves:
			wv.at = 1 << 30
		cfg.military.repeat_every = 1 << 30
	var scripted := map_id == "test_sim"
	var m: SimMap = SimMap.load_id("flat_test" if scripted else map_id)
	var prompts := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites"]
	var n := 4 if m.starts.size() == 4 else 2
	var races := []
	var bots := []
	for p in n:
		races.append(gen.generate(prompts[p], rules))
		if not scripted:
			bots.append(Bot.new(p, cfg))
	var w: World
	if scripted:   # as test_sim.gd's timed match
		rules.animals = false
		rules_ = rules
		w = World.new(SEED, m, races, rules)
		for c in _script(SimMap.load_id("flat_test"), races):
			w.commands.add(c)
		minutes = TICKS / 1200
	else:
		w = World.new(2026, m, races, rules, m.start_teams)
	var t := PackedInt64Array()
	t.resize(NAMES.size())
	var worst := PackedInt64Array()
	worst.resize(NAMES.size())
	var ticks := PackedInt64Array()   # per tick: the whole tick (bots included)
	var worst_ticks := []             # [total, tick, units, per-system array] of the slowest ticks
	var solves := 0
	var drops := 0
	var max_units := 0
	while w.tick < minutes * 1200 and w.winner < 0:
		var marks := PackedInt64Array()
		marks.append(Time.get_ticks_usec())
		for b in bots:
			b.think(w)
		marks.append(Time.get_ticks_usec())
		w.units.save_prev()
		w.events.clear()
		if w.tick % Commands.TICKS_PER_TURN == 0:
			for cmd in w.commands.take(w.turn()):
				w._run(cmd)
				w.history.append(cmd)
		marks.append(Time.get_ticks_usec())
		Economy.train(w)
		Tech.tick(w)
		marks.append(Time.get_ticks_usec())
		Economy.work(w)
		marks.append(Time.get_ticks_usec())
		Garrison.tick(w)
		marks.append(Time.get_ticks_usec())
		Animals.tick(w)
		marks.append(Time.get_ticks_usec())
		w.spatial.build(w.units.x, w.units.y)
		var alive: int = w.units.changes
		marks.append(Time.get_ticks_usec())
		Heal.tick(w)
		marks.append(Time.get_ticks_usec())
		Combat.tick(w)
		marks.append(Time.get_ticks_usec())
		Match.tick(w)
		marks.append(Time.get_ticks_usec())
		Fog.tick(w)
		marks.append(Time.get_ticks_usec())
		Trails.tick(w)
		if w.units.changes != alive:
			w.spatial.build(w.units.x, w.units.y)
		marks.append(Time.get_ticks_usec())
		w._next_orders()
		marks.append(Time.get_ticks_usec())
		var before: int = w.field_order.size()
		var fresh: int = w.map.fresh.size()
		w._sync_map()
		if fresh > 0:
			drops += before - w.field_order.size()
		marks.append(Time.get_ticks_usec())
		var q: int = w.field_queue.size()
		w._solve_queued()
		solves += q - w.field_queue.size()
		marks.append(Time.get_ticks_usec())
		w._move()
		marks.append(Time.get_ticks_usec())
		w.spatial.build(w.units.x, w.units.y)
		w._separate()
		marks.append(Time.get_ticks_usec())
		w.tick += 1
		if w.tick % World.HASH_EVERY == 0:
			w.hashes.append([w.tick, w.state_hash()])
		marks.append(Time.get_ticks_usec())
		var per := PackedInt64Array()
		per.resize(NAMES.size())
		for k in NAMES.size():
			var d: int = marks[k + 1] - marks[k]
			per[k] = d
			t[k] += d
			worst[k] = maxi(worst[k], d)
		var total: int = marks[NAMES.size()] - marks[0]
		ticks.append(total)
		max_units = maxi(max_units, w.units.count())
		if worst_ticks.size() < 10 or total > worst_ticks[-1][0]:
			worst_ticks.append([total, w.tick - 1, w.units.count(), per])
			worst_ticks.sort_custom(func(a, b): return a[0] > b[0])
			if worst_ticks.size() > 10:
				worst_ticks.pop_back()
	var sum := 0
	for k in NAMES.size():
		sum += t[k]
		print("%-12s avg %.3f ms  worst %5.1f ms" % [NAMES[k], t[k] / 1000.0 / w.tick, worst[k] / 1000.0])
	var sorted := ticks.duplicate()
	sorted.sort()
	var sim_sum := sum - t[0]
	print("%s %s, %d players, %d ticks (%d:%02d), units at the end %d (most %d), winner %d" % [map_id, "peace" if peace else "bots",
		n, w.tick, w.tick / 1200, w.tick / 20 % 60, w.units.count(), max_units, w.winner])
	print("tick (bots included): avg %.3f ms  p99 %.2f ms  worst %.1f ms;  sim alone avg %.3f ms" % [sum / 1000.0 / w.tick,
		sorted[sorted.size() * 99 / 100] / 1000.0, sorted[-1] / 1000.0, sim_sum / 1000.0 / w.tick])
	print("fields solved %d, dropped by map changes %d; final hash %d" % [solves, drops, w.state_hash()])
	print("worst ticks:")
	for wt in worst_ticks:
		var parts := []
		for k in NAMES.size():
			if wt[3][k] >= 1000:
				parts.append("%s %.1f" % [NAMES[k], wt[3][k] / 1000.0])
		print("  tick %6d  %5.1f ms  %3d units  %s" % [wt[1], wt[0] / 1000.0, wt[2], ", ".join(parts)])
	quit(0)


# The timed match of test_sim.gd (copied: that file is a test run, not a library).

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
