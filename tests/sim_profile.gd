extends SceneTree
## Where a tick goes: World.step's parts (and the bots' thinking) timed over a bot match: two bots
## on a 1v1 map, four bots in their teams on a four-start map. Prints per system the average and
## worst, the tick's average, p99 and worst, what the ten worst ticks spent their time on, and the
## state hash at the end (two branches playing the same match must agree where behaviour didn't change).
## Milestone 15's tick-budget checks.
## Run: godot --headless --path . --script res://tests/sim_profile.gd -- [map_id] [minutes] [peace]

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
	var m: SimMap = SimMap.load_id(map_id)
	var prompts := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites"]
	var n := 4 if m.starts.size() == 4 else 2
	var races := []
	var bots := []
	for p in n:
		races.append(gen.generate(prompts[p], rules))
		bots.append(Bot.new(p, cfg))
	var w := World.new(2026, m, races, rules, m.start_teams)
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
