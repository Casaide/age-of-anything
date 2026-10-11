extends SceneTree
## A pathing audit: bot vs bot on each map, watching every unit every tick for the ways
## movement goes wrong, and where: give-ups (stuck for STUCK_LIMIT ticks), snaps (moved
## further in a tick than it can walk: pushed off blocked ground), jitter (reversing
## direction many times in a short window while moving), and treading (moving but going
## nowhere for a while). Prints counts per map and a few examples each with the cell, the
## terrain there and what the unit was doing. Diagnostic, not a pass/fail test.
## Run: godot --headless --path . --script res://tests/path_audit.gd -- [minutes] [map ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")
const Economy := preload("res://src/sim/economy.gd")

const SEED := 7
const WINDOW := 20          # ticks of history per unit for jitter and treading
const EXAMPLES := 8


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := int(args[0]) if args.size() > 0 else 8
	var maps: Array = args.slice(1) if args.size() > 1 else ["flat_test", "choke_test"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate("angry swamp frogs with reed spears", rules), gen.generate("centaur romans", rules)]
	for map_id in maps:
		_audit(map_id, races, rules, minutes)
	quit()


func _audit(map_id: String, races: Array, rules: Dictionary, minutes: int) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	var bots := [Bot.new(0), Bot.new(1)]
	var hist := {}        # id -> [[x, y, moving], ...] last WINDOW ticks
	var stuck_seen := {}  # id -> tick of the last counted give-up
	var tread_seen := {}
	var jitter_seen := {}
	var counts := {"give_up": 0, "snap": 0, "jitter": 0, "tread": 0, "moves": 0}
	var examples := {"give_up": [], "snap": [], "jitter": [], "tread": []}
	var limit := 20 * 60 * minutes
	while w.tick < limit and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		var u := w.units
		for i in u.count():
			var id: int = u.id[i]
			var h: Array = hist.get(id, [])
			var rec := [u.x[i], u.y[i], u.moving[i]]
			if not h.is_empty():
				var last: Array = h[-1]
				var dx: int = u.x[i] - last[0]
				var dy: int = u.y[i] - last[1]
				var s: int = u.speed[i]
				if dx * dx + dy * dy > (3 * s + 60) * (3 * s + 60):
					counts.snap += 1
					_example(examples.snap, w, i, "jumped %d milli-tiles" % Fixed_isqrt(dx * dx + dy * dy))
				if u.moving[i] == 1:
					counts.moves += 1
				if u.stuck[i] >= World.STUCK_LIMIT and u.moving[i] == 0 and w.tick - int(stuck_seen.get(id, -1000)) > 100:
					stuck_seen[id] = w.tick
					counts.give_up += 1
					_example(examples.give_up, w, i, "gave up towards cell %d" % w.map.cell_of(u.tx[i], u.ty[i]))
			h.append(rec)
			if h.size() > WINDOW:
				h.pop_front()
			hist[id] = h
			if h.size() == WINDOW and h.all(func(r): return r[2] == 1):
				var fx: int = h[0][0]
				var fy: int = h[0][1]
				var dd: int = (u.x[i] - fx) * (u.x[i] - fx) + (u.y[i] - fy) * (u.y[i] - fy)
				var s: int = u.speed[i]
				if dd < s * s * 4 and w.tick - int(tread_seen.get(id, -1000)) > WINDOW * 3:
					tread_seen[id] = w.tick
					counts.tread += 1
					_example(examples.tread, w, i, "moving for %d ticks, went %d milli-tiles" % [WINDOW, Fixed_isqrt(dd)])
				var flips := 0
				for k in range(2, WINDOW):
					var ax: int = h[k - 1][0] - h[k - 2][0]
					var ay: int = h[k - 1][1] - h[k - 2][1]
					var bx: int = h[k][0] - h[k - 1][0]
					var by: int = h[k][1] - h[k - 1][1]
					if ax * bx + ay * by < 0:
						flips += 1
				if flips >= 6 and w.tick - int(jitter_seen.get(id, -1000)) > WINDOW * 3:
					jitter_seen[id] = w.tick
					counts.jitter += 1
					_example(examples.jitter, w, i, "%d direction reversals in %d ticks" % [flips, WINDOW])
	print("\n== %s, %d:%02d of match, winner %d" % [map_id, w.tick / 1200, (w.tick / 20) % 60, w.winner])
	print("unit-ticks moving %d; give-ups %d, snaps %d, jitter %d, treading %d" % [counts.moves, counts.give_up, counts.snap, counts.jitter, counts.tread])
	for kind in ["give_up", "snap", "jitter", "tread"]:
		for e in examples[kind]:
			print("  %-8s %s" % [kind, e])


func _example(list: Array, w: World, i: int, what: String) -> void:
	if list.size() >= EXAMPLES:
		return
	var u := w.units
	var c := w.map.cell_of(u.x[i], u.y[i])
	var t: Dictionary = w.types[u.kind[i]]
	var task: String = {Economy.NONE: "idle", Economy.GATHER: "gather", Economy.RETURN: "return", Economy.BUILD: "build"}.get(u.task[i], str(u.task[i]))
	var around := ""
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			around += "#" if not w.map.cell_walkable(c % w.map.width + dx, c / w.map.width + dy, u.mclass[i]) else "."
		around += "/"
	var f = w.fields.get(u.fkey[i])
	if u.reach[i] == 1:
		var ex: int = maxi(maxi(u.rx0[i] - u.x[i], 0), u.x[i] - u.rx1[i])
		var ey: int = maxi(maxi(u.ry0[i] - u.y[i], 0), u.y[i] - u.ry1[i])
		what += " [rect gap %d,%d reach %d]" % [ex, ey, u.radius[i] + Economy.REACH]
	var field := "no field" if f == null else "dist %d next %d" % [f.dist[c], f.next[c]]
	list.append("%s: %s (P%d %s, %s, foe %d, group %d) at (%d,%d) cell %d (%d,%d) %s; wp (%d,%d) target (%d,%d) reach %d arrive %d stuck %d; %s" % [
		"%d:%02d" % [w.tick / 1200, (w.tick / 20) % 60], what, u.owner[i], t.name, task, u.foe[i], u.group[i], u.x[i], u.y[i], c, c % w.map.width, c / w.map.width,
		around, u.wx[i], u.wy[i], u.tx[i], u.ty[i], u.reach[i], u.arrive[i], u.stuck[i], field])


static func Fixed_isqrt(v: int) -> int:
	var r := int(sqrt(float(v)))
	return r
