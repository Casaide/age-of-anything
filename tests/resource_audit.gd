extends SceneTree
## Resource audit for a map (milestone 15): what's on it, and how long it lasts.
## 1. A count: each resource within RADIUS tiles of each start (food from wild bushes and the
##    animals placed there), and in contested ground (near no start).
## 2. Matches, each up to MINUTES game minutes (or a winner), printed per minute per side:
##    what was gathered that minute, what's left near home, idle workers, workers gathering far
##    from home (beyond RADIUS); then when each resource ran out near each start.
##    - bot vs bot (src/ai/bot.gd, normal);
##    - bot vs passive (the bot against an EcoBot that only runs an economy);
##    - peace: two bots that never attack, so the economy runs the whole time through the ages.
## Run: godot --headless --path . --script res://tests/resource_audit.gd -- <map_id> [minutes] [radius] [bots,passive,peace]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Economy := preload("res://src/sim/economy.gd")
const Bot := preload("res://src/ai/bot.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")

const SEED := 7
const MIN := 1200   # ticks in a minute

var radius := 16
var lib
var gen
var rules: Dictionary


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "flat_test"
	var minutes := int(args[1]) if args.size() > 1 else 40
	radius = int(args[2]) if args.size() > 2 else 16
	var runs: Array = (args[3] if args.size() > 3 else "bots,passive,peace").split(",")
	lib = DataLib.new()
	gen = Generator.new(lib)
	rules = DataLib.load_json("res://data/rules/default.json")
	var frogs: Dictionary = gen.generate("angry swamp frogs with reed spears", rules)
	var rats: Dictionary = gen.generate("sewer rats with cheese hammers", rules)
	_count(map_id, [frogs, rats])
	var peaceful := Bot.load_config().duplicate(true)
	for wv in peaceful.military.waves:
		wv.at = 1 << 30
	peaceful.military.repeat_every = 1 << 30
	if "bots" in runs:
		_play(map_id, minutes, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot")
	if "passive" in runs:
		_play(map_id, minutes, [rats, frogs], [Bot.new(0), EcoBot.new(1)], "bot vs passive")
	if "peace" in runs:
		_play(map_id, minutes, [frogs, rats], [Bot.new(0, peaceful), Bot.new(1, peaceful)], "peace (bots that never attack)")
	quit(0)


## Which start a cell belongs to (within radius tiles), or -1 for contested ground.
func _owner_of(m, x: int, y: int) -> int:
	for p in m.starts.size():
		var dx: int = x - m.starts[p][0] / SimMap.TILE
		var dy: int = y - m.starts[p][1] / SimMap.TILE
		if dx * dx + dy * dy <= radius * radius:
			return p
	return -1


## Resources left per region (starts..., contested) per resource, from the map's cells (farms
## left out: they're bought, not found) and the animals still walking about.
func _left(w) -> Array:
	var m = w.map
	var out := []
	for k in m.starts.size() + 1:
		var row := PackedInt32Array()
		row.resize(w.resources.size())
		out.append(row)
	for c in m.resource_cells:
		if m.pool[c] >= 0 or m.amount[c] <= 0:
			continue
		var kind: int = Economy.kind_of(w, m.resource_at(c))
		if kind <= 0:
			continue
		var o := _owner_of(m, c % m.width, c / m.width)
		out[o if o >= 0 else m.starts.size()][kind - 1] += m.amount[c]
	var food: int = Economy.kind_of(w, "food") - 1
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.has("animal"):
			var o := _owner_of(m, w.units.x[i] / SimMap.TILE, w.units.y[i] / SimMap.TILE)
			out[o if o >= 0 else m.starts.size()][food] += int(t.food)
	return out


func _count(map_id: String, races: Array) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	var m = w.map
	print("== %s: %d x %d, %d starts, home radius %d tiles" % [map_id, m.width, m.height, m.starts.size(), radius])
	var left := _left(w)
	var cells := []   # per region, per resource: tiles (animals counted apart)
	for k in m.starts.size() + 1:
		cells.append({})
	for c in m.resource_cells:
		var t: String = m.terrain_at(c)
		var o := _owner_of(m, c % m.width, c / m.width)
		var d: Dictionary = cells[o if o >= 0 else m.starts.size()]
		d[t] = d.get(t, 0) + 1
	var animals := []
	for k in m.starts.size() + 1:
		animals.append({})
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		if t.has("animal"):
			var o := _owner_of(m, w.units.x[i] / SimMap.TILE, w.units.y[i] / SimMap.TILE)
			var d: Dictionary = animals[o if o >= 0 else m.starts.size()]
			d[t.animal] = d.get(t.animal, 0) + 1
	var total := PackedInt32Array()
	total.resize(w.resources.size())
	for k in m.starts.size() + 1:
		var label := "start %d %s" % [k, str(m.starts[k].map(func(v): return v / SimMap.TILE))] if k < m.starts.size() else "contested"
		var parts := []
		for r in w.resources.size():
			parts.append("%s %d" % [w.resources[r], left[k][r]])
			total[r] += left[k][r]
		print("  %-18s %s   tiles %s   animals %s" % [label, ", ".join(parts), _sorted(cells[k]), _sorted(animals[k])])
	var parts := []
	for r in w.resources.size():
		parts.append("%s %d" % [w.resources[r], total[r]])
	print("  %-18s %s" % ["map total", ", ".join(parts)])


func _sorted(d: Dictionary) -> String:
	var ks := d.keys()
	ks.sort()
	return "{" + ", ".join(ks.map(func(k): return "%s %d" % [k, d[k]])) + "}"


func _play(map_id: String, minutes: int, races: Array, bots: Array, title: String) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	var m = w.map
	var n := w.resources.size()
	var players := races.size()
	print("\n== %s on %s (%s vs %s), up to %d minutes" % [title, map_id, races[0].name, races[1].name, minutes])
	print("  per side: age, workers, idle, far (gathering beyond %d tiles), gathered this minute F/W/S/G, left near home F/W/S/G" % radius)
	var start_left := _left(w)
	var ran_out := []   # per player, per resource: the tick it ran out near home, or -1
	for p in players:
		var row := PackedInt32Array()
		row.resize(n)
		row.fill(-1)
		ran_out.append(row)
	var last := []
	for p in players:
		last.append(_gathered(w, p))
	var aged := [[-1, -1], [-1, -1]]   # when each side reached ages 2 and 3
	var idle_sum := PackedInt32Array()
	idle_sum.resize(players)
	var far_sum := PackedInt32Array()
	far_sum.resize(players)
	var ticks := 0
	var step_us := 0
	var bot_us := 0
	var worst_us := 0
	while w.tick < minutes * MIN and w.winner < 0:
		var t0 := Time.get_ticks_usec()
		for bot in bots:
			bot.think(w)
		var t1 := Time.get_ticks_usec()
		w.step()
		var t2 := Time.get_ticks_usec()
		step_us += t2 - t1
		bot_us += t1 - t0
		worst_us = maxi(worst_us, t2 - t1)
		for p in players:
			for a in 2:
				if aged[p][a] < 0 and w.ages[p] >= a + 2:
					aged[p][a] = w.tick
		if w.tick % 200 == 0:   # every 10 s: idle and far workers, and what's run out
			ticks += 1
			var left := _left(w)
			for p in players:
				var wk := _workers(w, p)
				idle_sum[p] += wk.idle
				far_sum[p] += wk.far
				for r in n:
					if ran_out[p][r] < 0 and start_left[p][r] > 0 and left[p][r] <= 0:
						ran_out[p][r] = w.tick
		if w.tick % MIN == 0:
			var left := _left(w)
			var line := "  %2d:00" % (w.tick / MIN)
			for p in players:
				var g := _gathered(w, p)
				var got := []
				for r in n:
					got.append(str(g[r] - last[p][r]))
				last[p] = g
				var wk := _workers(w, p)
				line += "  | P%d a%d %2dw %2di %2df  +%s  left %s" % [p, w.ages[p], wk.count, wk.idle, wk.far, "/".join(got), "/".join(Array(left[p]).map(str))]
			line += "  | mid %s" % "/".join(Array(left[players]).map(str))
			print(line)
	print("  ended %s, winner %d; sim tick avg %.2f ms (worst %.1f ms), bots %.2f ms a tick" % [_clock(w.tick), w.winner,
		step_us / 1000.0 / maxi(1, w.tick), worst_us / 1000.0, bot_us / 1000.0 / maxi(1, w.tick)])
	for p in players:
		var outs := []
		for r in n:
			outs.append("%s %s" % [w.resources[r], _clock(ran_out[p][r]) if ran_out[p][r] >= 0 else ("never" if start_left[p][r] > 0 else "none there")])
		var g := _gathered(w, p)
		print("  P%d: age 2 at %s, age 3 at %s; gathered %s; units lost %d; avg idle %.1f, avg far %.1f; ran out near home: %s" % [p,
			_clock(aged[p][0]), _clock(aged[p][1]), "/".join(Array(g).map(str)), w.lost[p],
			float(idle_sum[p]) / maxi(1, ticks), float(far_sum[p]) / maxi(1, ticks), ", ".join(outs)])


func _gathered(w, p: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in w.resources.size():
		out.append(w.gathered[r][p])
	return out


## Player p's workers: how many, idle (no task, not hunting, standing), and far (gathering or
## carrying from a tile beyond the home radius of their start).
func _workers(w, p: int) -> Dictionary:
	var u = w.units
	var m = w.map
	var out := {"count": 0, "idle": 0, "far": 0}
	for i in u.count():
		if u.owner[i] != p or not w.types[u.kind[i]].worker:
			continue
		out.count += 1
		if u.task[i] == Economy.NONE and u.foe[i] == 0 and u.moving[i] == 0:
			out.idle += 1
		elif (u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN) and u.home[i] >= 0:
			var h: int = u.home[i]
			if _owner_of(m, h % m.width, h / m.width) != p:
				out.far += 1
	return out


func _clock(tick: int) -> String:
	if tick < 0:
		return "-"
	return "%d:%02d" % [tick / MIN, tick / 20 % 60]
