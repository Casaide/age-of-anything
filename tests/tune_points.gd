extends SceneTree
## Price by simulation, step one: nudge part points until the equal-cost round robin is flat.
## Rosters are generated once and kept; each step finds the part whose units are furthest off
## the mean win rate (on average), moves its points one step (winners' parts dearer, losers'
## cheaper), re-prices every unit and fights again. Prints the changes to make in
## data/parts.json; it never writes data itself. Deterministic.
## Run: godot --headless --path . --script res://tests/tune_points.gd [-- age steps]  (minutes)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Pricing := preload("res://src/pricing.gd")
const RoundRobin := preload("res://tests/round_robin.gd")

const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights"]
const TOLERANCE := 20
const MIN_COUNTERS := 75   # a step may not make counters win less often than this


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var age := int(args[0]) if args.size() > 0 else 2
	var steps := int(args[1]) if args.size() > 1 else 12
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races: Array = PROMPTS.map(func(p): return gen.generate(p, rules))
	var start := {}       # part id -> its points before tuning
	var last_move := {}   # part id -> +1 / -1, so a part isn't bounced straight back
	var best := {"off": 1 << 30, "points": {}}
	var banned := {}      # "part+1" / "part-1": moves that broke the counters
	var pick_last := ""
	for step in steps + 1:
		var rr: Dictionary = RoundRobin.run(races, rules, age)
		var off := 0
		var dev_sum := {}
		var dev_n := {}
		for k in rr.units.size():
			var dev: int = (rr.rates[k] - rr.mean) * 100 / maxi(1, rr.mean)
			if absi(dev) > TOLERANCE:
				off += 1
			for id in _parts(lib, RoundRobin.recipe_at(rr.units[k][0], rr.units[k][1], age).recipe):
				dev_sum[id] = dev_sum.get(id, 0) + dev
				dev_n[id] = dev_n.get(id, 0) + 1
		print("step %d: %d of %d units more than %d%% off the mean, counters %d%%" % [step, off, rr.units.size(), TOLERANCE, rr.counters])
		if rr.counters < MIN_COUNTERS and pick_last != "":
			# That step broke the counters: undo it and never move that part that way again.
			lib.parts[pick_last].points = int(lib.parts[pick_last].points) - last_move[pick_last]
			banned[pick_last + str(last_move[pick_last])] = true
			print("  undone: counters fell below %d%%" % MIN_COUNTERS)
			_reprice(lib, races, rules)
			pick_last = ""
			continue
		if off < best.off:
			best = {"off": off, "points": _snapshot(lib, start)}
		if off == 0 or step == steps:
			break
		# The part whose units are furthest off on average, shared by at most half the units
		# (bodies and heads that everyone has can't fix one unit's price).
		var ids := dev_sum.keys()
		ids.sort()
		var pick := ""
		var pick_dev := 0
		for id in ids:
			if dev_n[id] > rr.units.size() / 2:
				continue
			var d: int = dev_sum[id] / dev_n[id]
			var dir := 1 if d > 0 else -1
			if last_move.get(id, 0) == -dir or (dir < 0 and int(lib.parts[id].points) <= 1) or banned.has(id + str(dir)):
				continue
			if absi(d) > absi(pick_dev):
				pick = id
				pick_dev = d
		if pick == "" or absi(pick_dev) <= TOLERANCE / 2:
			break
		var dir := 1 if pick_dev > 0 else -1
		if not start.has(pick):
			start[pick] = int(lib.parts[pick].points)
		lib.parts[pick].points = int(lib.parts[pick].points) + dir
		last_move[pick] = dir
		pick_last = pick
		print("  %s: %+d%% on average, points %d -> %d" % [pick, pick_dev, int(lib.parts[pick].points) - dir, int(lib.parts[pick].points)])
		_reprice(lib, races, rules)
	print("\nBest: %d units off. Changes for data/parts.json:" % best.off)
	var keys: Array = best.points.keys()
	keys.sort()
	for id in keys:
		if best.points[id] != start[id]:
			print("  %s points %d -> %d" % [id, start[id], best.points[id]])
	quit()


## Every part a recipe is built from (body, head, gear, the mount's body).
func _parts(lib, recipe: Dictionary) -> Array:
	var ids := [recipe.body, recipe.head]
	ids.append_array(recipe.parts.values())
	if recipe.has("mount"):
		ids.append(lib.creatures[recipe.mount.creature].get("mount_body", lib.creatures[recipe.mount.creature].body))
	return ids


func _snapshot(lib, start: Dictionary) -> Dictionary:
	var out := {}
	for id in start:
		out[id] = int(lib.parts[id].points)
	return out


## New prices for every step of every unit line (stats don't change, only cost).
func _reprice(lib, races: Array, rules: Dictionary) -> void:
	for r in races:
		for u in r.units:
			for l in u.line:
				l.eval = Pricing.evaluate(l.recipe, lib, rules, int(l.age))
			u.eval = u.line[0].eval
