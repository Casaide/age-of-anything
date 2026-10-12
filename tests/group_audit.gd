extends SceneTree
## A group-movement audit (Dominic's playtest notes, 2026-10-13): how a group move ends, and
## how a crowd of melee units gets on with hitting a building. Diagnostic numbers, not
## pass/fail (test_sim.gd has the checks).
##   move:  30 units (20 spear, 10 archers) cross flat_test. Ticks until everyone stops, how
##          far the stopped units still get pushed in the next 10 s (jostle), overlapping pairs
##          at rest, how strung out the group is half-way.
##   siege: 20 melee units attack a Town Center. Ticks to the first blow, until 15 of them have
##          struck, the most distinct hitters in any 2 s, how far hitters get pushed while
##          hitting (jostle), and how long the building lasts.
## Run: godot --headless --path . --script res://tests/group_audit.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Fixed := preload("res://src/sim/fixed.gd")

const SEED := 7


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	rules.animals = false
	for prompt in ["angry swamp frogs with reed spears", "centaur romans"]:
		var race: Dictionary = gen.generate(prompt, rules)
		print("\n== %s" % prompt)
		_move(race, rules, false)
		_move(race, rules, true)
		_siege(race, rules)
	quit()


func _bare(race: Dictionary, rules: Dictionary, town := false) -> World:
	var r: Dictionary = rules.duplicate(true)
	if not town:
		r.economy.start.buildings = []
	r.economy.start.workers = 0
	return World.new(SEED, SimMap.load_id("flat_test"), [race, race], r)


func _spawn(w: World, p: int, slot: String, n: int, x: int, y: int) -> Array:
	var before := w.next_id
	w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": x, "y": y})
	while w.next_id == before:
		w.step()
	return range(before, w.next_id)


func _move(race: Dictionary, rules: Dictionary, attack: bool) -> void:
	var w := _bare(race, rules)
	var ids: Array = _spawn(w, 0, "spear", 20, 12000, 14000) + _spawn(w, 0, "archer", 10, 12000, 16000)
	for t in 40:
		w.step()
	w.issue(0, Commands.ATTACK_MOVE if attack else Commands.MOVE, {"ids": ids, "x": 40000, "y": 40000})
	var settled := -1
	var spread_mid := 0
	var shoved := 0   # milli-tiles stopped units were pushed while the group arrived
	var shoved_ticks := 0
	while w.tick < 3000 and settled < 0:
		var qx := w.units.x.duplicate()
		var qy := w.units.y.duplicate()
		var qm := w.units.moving.duplicate()
		w.step()
		for i in w.units.count():
			if qm[i] == 0 and w.units.moving[i] == 0 and w.tick > 60:
				var dd := absi(w.units.x[i] - qx[i]) + absi(w.units.y[i] - qy[i])
				if dd > 0:
					shoved += dd
					shoved_ticks += 1
		if w.tick % 20 == 0 and w.tick > 80 and not 1 in w.units.moving:
			settled = w.tick
		if spread_mid == 0 and _centroid_dist(w, 40000, 40000) < 14000:
			spread_mid = _spread(w)
	var x0 := w.units.x.duplicate()
	var y0 := w.units.y.duplicate()
	var jostle := 0
	var moves := 0
	for t in 200:
		var px := w.units.x.duplicate()
		var py := w.units.y.duplicate()
		w.step()
		for i in w.units.count():
			jostle += absi(w.units.x[i] - px[i]) + absi(w.units.y[i] - py[i])
			moves += w.units.moving[i]
	var drift := 0
	for i in w.units.count():
		drift = maxi(drift, Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], x0[i], y0[i])))
	var overlaps := 0
	var far := 0
	for i in w.units.count():
		far = maxi(far, Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], 40000, 40000)))
		for j in range(i + 1, w.units.count()):
			var rr: int = w.units.radius[i] + w.units.radius[j]
			if Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) < rr * rr * 81 / 100:
				overlaps += 1
	print("%s: settled at tick %d; arriving, stopped units shoved %d milli-tiles (%d unit-ticks); half-way spread %d; after: jostle %d milli-tiles over 10 s (%d unit-ticks moving), worst drift %d, overlapping pairs %d, furthest from the click %d" % [
		"attack-move" if attack else "move", settled, shoved, shoved_ticks, spread_mid, jostle, moves, drift, overlaps, far])


func _centroid_dist(w: World, x: int, y: int) -> int:
	var sx := 0
	var sy := 0
	for i in w.units.count():
		sx += w.units.x[i]
		sy += w.units.y[i]
	var n := maxi(w.units.count(), 1)
	return Fixed.isqrt(Fixed.dist2(sx / n, sy / n, x, y))


## The furthest any unit is from the group's centroid.
func _spread(w: World) -> int:
	var sx := 0
	var sy := 0
	var n := w.units.count()
	for i in n:
		sx += w.units.x[i]
		sy += w.units.y[i]
	var best := 0
	for i in n:
		best = maxi(best, Fixed.isqrt(Fixed.dist2(w.units.x[i], w.units.y[i], sx / n, sy / n)))
	return best


func _siege(race: Dictionary, rules: Dictionary) -> void:
	var w := _bare(race, rules, true)
	var b := -1
	for k in w.buildings.count():
		if w.buildings.owner[k] == 1:
			b = k
	var tc: int = w.buildings.id[b]
	var cx: int = w.buildings.cx[b] * 1000
	var cy: int = w.buildings.cy[b] * 1000
	var ids: Array = _spawn(w, 0, "spear", 20, cx - 5000, cy - 5000)
	for t in 40:
		w.step()
	w.issue(0, Commands.ATTACK, {"ids": ids, "target": tc})
	var start := w.tick
	var first := -1
	var fifteen := -1
	var struck := {}
	var window := []   # per tick: hitters
	var best_window := 0
	var jostle := 0
	var hitting_ticks := 0
	while w.tick < start + 6000 and w.buildings.index_of(tc) >= 0:
		var px := w.units.x.duplicate()
		var py := w.units.y.duplicate()
		var was := {}
		for i in w.units.count():
			if w.units.foe[i] == tc and w.units.moving[i] == 0:
				was[w.units.id[i]] = i
		w.step()
		var hitters := {}
		for e in w.events:
			if e.type == "hit" and e.to == tc:
				hitters[e.by] = true
				struck[e.by] = true
				if first < 0:
					first = w.tick - start
		if fifteen < 0 and struck.size() >= 15:
			fifteen = w.tick - start
		window.append(hitters.keys())
		if window.size() > 40:
			window.pop_front()
		var seen := {}
		for l in window:
			for h in l:
				seen[h] = true
		best_window = maxi(best_window, seen.size())
		for uid in was:
			var i: int = w.units.index_of(uid)
			if i >= 0 and i == was[uid]:
				jostle += absi(w.units.x[i] - px[i]) + absi(w.units.y[i] - py[i])
				hitting_ticks += 1
	print("siege (20 %s on a Town Center): first blow at %d ticks, 15 have struck at %d, most hitters in 2 s %d, jostle while stopped %d milli-tiles over %d unit-ticks, standing %s (tick %d)" % [
		race.units[1].recipe.get("name", "spear"), first, fifteen, best_window, jostle, hitting_ticks, "yes" if w.buildings.index_of(tc) >= 0 else "no", w.tick - start])
