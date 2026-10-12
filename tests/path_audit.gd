extends SceneTree
## A pathing audit: bot vs bot on each map, watching every unit every tick for the ways
## movement goes wrong, and where: give-ups (stuck for STUCK_LIMIT ticks), snaps (moved
## further in a tick than it can walk: pushed off blocked ground), jitter (reversing
## direction many times in a short window while moving), treading (moving but going
## nowhere for a while) and crowding (two of a player's workers overlapping by more than a
## third of their bodies, counted per pair-tick; "stacked" when both are standing, not passing
## by). Prints counts per map and a few examples
## each with the cell, the terrain there and what the unit was doing. Diagnostic, not a
## pass/fail test.
## Gathering scenes on Reed Meadow, player 0 alone at work (no bots), with food gathered:
##   bushes  12 workers sent to one bug bush of the clump by the Town Center, a mill beside it
##   hunt    6 workers on one carcass (1,000 food) south of the Town Center
##   farms   6 workers each building a farm round the Town Center, then farming it
##   reeds   8 workers on the reed bed east of the Town Center (wood, for comparison)
## Run: godot --headless --path . --script res://tests/path_audit.gd -- [minutes] [map|bushes|hunt|farms ...]
## AUDIT_SEEDS=7,8,9 in the environment plays each map once per seed (one match is noisy).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")
const Economy := preload("res://src/sim/economy.gd")
const Commands := preload("res://src/sim/commands.gd")

const SEED := 7
const WINDOW := 20          # ticks of history per unit for jitter and treading
const EXAMPLES := 8
const SCENES := ["bushes", "hunt", "farms", "reeds"]

var hist := {}        # id -> [[x, y, moving], ...] last WINDOW ticks
var stuck_seen := {}  # id -> tick of the last counted give-up
var tread_seen := {}
var jitter_seen := {}
var counts := {}
var wcounts := {}     # workers only
var examples := {}
var by_job := {}      # "give_up"/"jitter"/"tread" -> worker's job ("gather food", "return wood", ...) -> count


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := int(args[0]) if args.size() > 0 else 8
	var maps: Array = args.slice(1) if args.size() > 1 else ["flat_test", "choke_test"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate("angry swamp frogs with reed spears", rules), gen.generate("centaur romans", rules)]
	for map_id in maps:
		for sd in OS.get_environment("AUDIT_SEEDS").split(",", false) if OS.get_environment("AUDIT_SEEDS") != "" else [str(SEED)]:
			_audit(map_id, races, rules, minutes, int(sd))
	quit()


func _audit(map_id: String, races: Array, rules: Dictionary, minutes: int, sd: int) -> void:
	var scene: bool = map_id in SCENES
	var w := World.new(sd, SimMap.load_id("reed_meadow" if scene else map_id), races, rules)
	var bots := [] if scene else [Bot.new(0), Bot.new(1)]
	if scene:
		_set_up(w, map_id)
	hist = {}
	stuck_seen = {}
	tread_seen = {}
	jitter_seen = {}
	counts = {"give_up": 0, "snap": 0, "jitter": 0, "tread": 0, "moves": 0, "crowd": 0, "stacked": 0}
	wcounts = counts.duplicate()
	examples = {"give_up": [], "snap": [], "jitter": [], "tread": [], "crowd": []}
	by_job = {"give_up": {}, "jitter": {}, "tread": {}}
	var limit := 20 * 60 * minutes
	var t0 := Time.get_ticks_usec()
	while w.tick < limit and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		_watch(w)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("\n== %s (seed %d), %d:%02d of match, winner %d, %.2f ms a tick" % [map_id, sd, w.tick / 1200, (w.tick / 20) % 60, w.winner, ms / maxi(w.tick, 1)])
	print("unit-ticks moving %d; give-ups %d, snaps %d, jitter %d, treading %d, crowding %d (stacked %d)" % [counts.moves, counts.give_up, counts.snap, counts.jitter, counts.tread, counts.crowd, counts.stacked])
	print("  workers: unit-ticks moving %d; give-ups %d, snaps %d, jitter %d, treading %d" % [wcounts.moves, wcounts.give_up, wcounts.snap, wcounts.jitter, wcounts.tread])
	for kind in by_job:
		var keys: Array = by_job[kind].keys()
		keys.sort()
		print("  workers' %s by job: %s" % [kind, ", ".join(keys.map(func(k): return "%s %d" % [k, by_job[kind][k]]))])
	if scene:
		var food: int = w.gathered[w.resources.find("food")][0]
		var wood: int = w.gathered[w.resources.find("wood")][0]
		print("  gathered by player 0: food %d (%d a minute), wood %d (%d a minute)" % [food, food * 1200 / maxi(w.tick, 1), wood, wood * 1200 / maxi(w.tick, 1)])
	for kind in ["give_up", "snap", "jitter", "tread", "crowd"]:
		for e in examples[kind]:
			print("  %-8s %s" % [kind, e])


## A gathering scene for player 0 on Reed Meadow (its Town Center at 11..13, 11..13; the bug
## bush clump at 17..18, 11..14).
func _set_up(w: World, scene: String) -> void:
	var tc := 0
	var worker: int = w.type_of(0, "worker")
	var want: int = {"bushes": 12, "hunt": 6, "farms": 6, "reeds": 8}[scene]
	while _workers(w, 0).size() < want:
		Economy.spawn_at(w, tc, worker)
	var ids := _workers(w, 0)
	var m := w.map
	match scene:
		"bushes":
			var mill: int = Economy.place(w, 0, Economy.btype_of(w, "mill"), 20, 12)
			w.buildings.done[mill] = 1
			w.buildings.hp[mill] = w.bmods[0][w.buildings.kind[mill]].hp
			w.issue(0, Commands.GATHER, {"ids": ids, "cell": 12 * m.width + 17})
		"reeds":
			w.issue(0, Commands.GATHER, {"ids": ids, "cell": 12 * m.width + 24})
		"hunt":
			var cell := 18 * m.width + 12
			m.set_terrain(cell, m.terrain_ids.find("carcass"))
			m.amount[cell] = 1000
			w.issue(0, Commands.GATHER, {"ids": ids, "cell": cell})
		"farms":
			var fk: int = Economy.btype_of(w, "farm")
			var n := 0
			for spot in [[8, 10], [8, 12], [8, 14], [11, 15], [13, 15], [11, 8], [13, 8], [15, 10], [15, 13]]:
				if n < ids.size() and Economy.can_place(w, 0, fk, spot[0], spot[1]):
					w.issue(0, Commands.BUILD, {"ids": [ids[n]], "building": "farm", "cx": spot[0], "cy": spot[1]})
					n += 1
			assert(n == ids.size(), "Room for only %d farms" % n)
	w.stock[w.resources.find("wood")][0] = 5000


func _workers(w: World, p: int) -> Array:
	var out := []
	for i in w.units.count():
		if w.units.owner[i] == p and w.types[w.units.kind[i]].worker:
			out.append(w.units.id[i])
	return out


func _watch(w: World) -> void:
	var u := w.units
	for i in u.count():
		var id: int = u.id[i]
		var wk: bool = w.types[u.kind[i]].worker
		var h: Array = hist.get(id, [])
		var rec := [u.x[i], u.y[i], u.moving[i]]
		if not h.is_empty():
			var last: Array = h[-1]
			var dx: int = u.x[i] - last[0]
			var dy: int = u.y[i] - last[1]
			var s: int = u.speed[i]
			if dx * dx + dy * dy > (3 * s + 60) * (3 * s + 60):
				_count("snap", wk)
				_example(examples.snap, w, i, "jumped %d milli-tiles" % Fixed_isqrt(dx * dx + dy * dy))
			if u.moving[i] == 1:
				_count("moves", wk)
			if u.stuck[i] >= World.STUCK_LIMIT and u.moving[i] == 0 and w.tick - int(stuck_seen.get(id, -1000)) > 100:
				stuck_seen[id] = w.tick
				_count("give_up", wk)
				_job(w, i, "give_up")
				_example(examples.give_up, w, i, "gave up towards cell %d" % w.map.cell_of(u.tx[i], u.ty[i]))
		h.append(rec)
		if h.size() > WINDOW:
			h.pop_front()
		hist[id] = h
		if wk:
			# Crowding: another of the player's workers deep inside this one's body.
			for j in range(i + 1, u.count()):
				if u.owner[j] != u.owner[i] or not w.types[u.kind[j]].worker:
					continue
				var rr: int = (u.radius[i] + u.radius[j]) * 2 / 3
				var ex: int = u.x[j] - u.x[i]
				var ey: int = u.y[j] - u.y[i]
				if ex * ex + ey * ey < rr * rr:
					_count("crowd", true)
					if u.moving[i] == 0 and u.moving[j] == 0 and w.tick > 20:
						_count("stacked", true)
						_example(examples.crowd, w, i, "stands in worker %d (%s at (%d,%d)) by %d" % [u.id[j], "gather" if u.task[j] == Economy.GATHER else str(u.task[j]), u.x[j], u.y[j], (u.radius[i] + u.radius[j]) - Fixed_isqrt(ex * ex + ey * ey)])
		if h.size() == WINDOW and h.all(func(r): return r[2] == 1):
			var fx: int = h[0][0]
			var fy: int = h[0][1]
			var dd: int = (u.x[i] - fx) * (u.x[i] - fx) + (u.y[i] - fy) * (u.y[i] - fy)
			var s: int = u.speed[i]
			if dd < s * s * 4 and w.tick - int(tread_seen.get(id, -1000)) > WINDOW * 3:
				tread_seen[id] = w.tick
				_count("tread", wk)
				_job(w, i, "tread")
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
				_count("jitter", wk)
				_job(w, i, "jitter")
				_example(examples.jitter, w, i, "%d direction reversals in %d ticks" % [flips, WINDOW])


## Tally a worker's trouble by what it was doing (and with which resource).
func _job(w: World, i: int, kind: String) -> void:
	var u := w.units
	if not w.types[u.kind[i]].worker:
		return
	var task: String = {Economy.NONE: "idle", Economy.GATHER: "gather", Economy.RETURN: "return", Economy.BUILD: "build"}.get(u.task[i], "other")
	if u.task[i] == Economy.GATHER or u.task[i] == Economy.RETURN:
		task += " " + (w.resources[u.carry_kind[i] - 1] if u.carry_kind[i] > 0 else "?")
	by_job[kind][task] = int(by_job[kind].get(task, 0)) + 1


func _count(kind: String, worker: bool) -> void:
	counts[kind] += 1
	if worker:
		wcounts[kind] += 1


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
