extends SceneTree
## The worn-trail speed question (milestone 15, phase 4): the same matches with the trail
## bonus off and on (rules.trails.speed_pct), side by side. Peace (two bots that never attack)
## for the economy: what each side gathered; bot vs bot for the fight: who won and when.
## Also how much of the map wore into trails, and the sim's tick time.
## Run: godot --headless --path . --script res://tests/trail_experiment.gd -- [map_id] [minutes] [pct]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")

const SEED := 7
const MIN := 1200


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "reed_meadow_large"
	var minutes := int(args[1]) if args.size() > 1 else 15
	var pct := int(args[2]) if args.size() > 2 else 12
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules: Dictionary = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate("angry swamp frogs with reed spears", rules), gen.generate("sewer rats with cheese hammers", rules)]
	var peaceful := Bot.load_config().duplicate(true)
	for wv in peaceful.military.waves:
		wv.at = 1 << 30
	peaceful.military.repeat_every = 1 << 30
	for p in [0, pct]:
		var r := rules.duplicate(true)
		r.trails.speed_pct = p
		_run("peace", map_id, minutes, races, r, [Bot.new(0, peaceful), Bot.new(1, peaceful)])
	for p in [0, pct]:
		var r := rules.duplicate(true)
		r.trails.speed_pct = p
		_run("bot vs bot", map_id, 40, races, r, [Bot.new(0), Bot.new(1)])
	quit(0)


func _run(title: String, map_id: String, minutes: int, races: Array, rules: Dictionary, bots: Array) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	var us := 0
	var worst := 0
	var trail_ticks := 0     # walker-ticks spent on a trail
	var walk_ticks := 0
	while w.tick < minutes * MIN and w.winner < 0:
		for b in bots:
			b.think(w)
		var t0 := Time.get_ticks_usec()
		w.step()
		var dt := Time.get_ticks_usec() - t0
		us += dt
		worst = maxi(worst, dt)
		if w.tick % 20 == 0:
			for i in w.units.count():
				if w.units.moving[i] == 1 and w.units.mclass[i] != SimMap.FLYING:
					walk_ticks += 1
					if w.wear[w.map.cell_of(w.units.x[i], w.units.y[i])] >= int(w.trail_cfg.trail):
						trail_ticks += 1
	var trails := 0
	for c in w.wear.size():
		if w.wear[c] >= int(w.trail_cfg.trail):
			trails += 1
	var got := []
	for p in races.size():
		var sum := 0
		var parts := []
		for k in w.resources.size():
			sum += w.gathered[k][p]
			parts.append(str(w.gathered[k][p]))
		got.append("P%d %d (%s) age %d pop %d" % [p, sum, "/".join(parts), w.ages[p], w.pop[p]])
	print("%-10s trail bonus %2d%%: %s at %d:%02d, winner %d | %s | trail cells %d (%.1f%% of the map), walking on trails %.0f%% | tick %.2f ms avg, %.1f worst" % [
		title, w.trail_cfg.speed_pct, map_id, w.tick / MIN, w.tick % MIN / 20, w.winner, " ; ".join(got),
		trails, 100.0 * trails / w.wear.size(), 100.0 * trail_ticks / maxi(1, walk_ticks), us / 1000.0 / maxi(1, w.tick), worst / 1000.0])
