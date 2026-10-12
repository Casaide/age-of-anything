extends SceneTree
## Where a tick goes: World.step's parts timed over a bot match (two peaceful bots on a 1v1 map,
## four normal bots in their teams on a four-start map). Milestone 15's tick-budget checks.
## Run: godot --headless --path . --script res://tests/sim_profile.gd -- [map_id] [minutes]

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
const Match := preload("res://src/sim/match.gd")
const Fog := preload("res://src/sim/fog.gd")
const Trails := preload("res://src/sim/trails.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "reed_meadow_2v2"
	var minutes := int(args[1]) if args.size() > 1 else 20
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules: Dictionary = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate("angry swamp frogs with reed spears", rules), gen.generate("sewer rats with cheese hammers", rules)]
	var peaceful := Bot.load_config().duplicate(true)
	for wv in peaceful.military.waves:
		wv.at = 1 << 30
	peaceful.military.repeat_every = 1 << 30
	var bots := [Bot.new(0, peaceful), Bot.new(1, peaceful)]
	var m4: SimMap = SimMap.load_id(map_id)
	if m4.starts.size() == 4:
		races = ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites"].map(func(p): return gen.generate(p, rules))
		bots = [Bot.new(0), Bot.new(1), Bot.new(2), Bot.new(3)]
	var w := World.new(2026, SimMap.load_id(map_id), races, rules, m4.start_teams)
	var names := ["cmd+train+tech+work+animals", "combat", "fog", "trails+orders", "sync_map", "solve", "move", "separate"]
	var t := PackedInt64Array()
	t.resize(names.size())
	var worst := PackedInt64Array()
	worst.resize(names.size())
	var solves := 0
	var drops := 0
	while w.tick < minutes * 1200 and w.winner < 0:
		for b in bots:
			b.think(w)
		var marks := []
		marks.append(Time.get_ticks_usec())
		w.units.save_prev()
		w.events.clear()
		if w.tick % Commands.TICKS_PER_TURN == 0:
			for cmd in w.commands.take(w.turn()):
				w._run(cmd)
				w.history.append(cmd)
		Economy.train(w)
		Tech.tick(w)
		Economy.work(w)
		Animals.tick(w)
		w.spatial.build(w.units.x, w.units.y)
		marks.append(Time.get_ticks_usec())
		Combat.tick(w)
		Match.tick(w)
		marks.append(Time.get_ticks_usec())
		Fog.tick(w)
		marks.append(Time.get_ticks_usec())
		Trails.tick(w)
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
		for k in names.size():
			var d: int = marks[k + 1] - marks[k]
			t[k] += d
			worst[k] = maxi(worst[k], d)
	var total := 0
	for k in names.size():
		total += t[k]
		print("%-28s avg %.3f ms  worst %.1f ms" % [names[k], t[k] / 1000.0 / w.tick, worst[k] / 1000.0])
	print("total avg %.3f ms over %d ticks, %d units at the end; fields solved %d, dropped by map changes %d" % [total / 1000.0 / w.tick, w.tick, w.units.count(), solves, drops])
	quit(0)
