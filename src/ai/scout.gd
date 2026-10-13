extends RefCounted
## Scouting and what the bot remembers (milestone 15 phase 7). Early on a worker walks a tour
## for a while (the scout line isn't built yet): round the enemy's start at a safe distance, the
## crossings, the middle of the map, then home and back to work. From age 2 the fastest idle
## soldier at home walks the tour again now and then. Hit, it runs home (a scout that fights is
## a dead scout). What it sees stays seen: the fog's memory holds the ground and the enemy
## buildings (fog.gd fog_seen), and this remembers the enemy soldiers it saw, so the bot picks
## counters to the army it scouted, not just to what stands in sight this second.
## Data: data/ai.json "scout". Commands only; integers; deterministic.

const Fog := preload("res://src/sim/fog.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")

var cfg: Dictionary
var id := 0                  # the scout out now (unit id), 0: none
var worker := false          # ... a worker (held from work while it scouts)
var route: Array = []        # Vector2i points in milli-tiles, home last
var leg := 0
var until := 0               # it comes home by this tick
var hp := 0                  # its health when it set out (hit: home)
var tours := 0
var next_tour := 0
var seen := {}               # enemy soldier id -> [kind, tick, x, y]: soldiers we saw (what they field, where)


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


## Soldiers we remember that died this tick are forgotten (every tick: deaths are events).
func forget_dead(w) -> void:
	for e in w.events:
		if e.type == "die" and seen.has(e.id):
			seen.erase(e.id)


## Remember the enemy soldiers in sight now (kept `memory` seconds after last seen).
func remember(w, player: int) -> void:
	var u = w.units
	for i in u.count():
		if not w.is_foe(player, u.owner[i]) or not Fog.visible(w, player, u.x[i], u.y[i]):
			continue
		var t: Dictionary = w.types[u.kind[i]]
		if t.worker or t.has("animal") or t.healer:
			continue
		seen[u.id[i]] = [u.kind[i], w.tick, u.x[i], u.y[i]]
	var old := []
	var keep: int = int(cfg.get("memory", 180)) * 20
	for k in seen:
		if w.tick - int(seen[k][1]) > keep:
			old.append(k)
	for k in old:
		seen.erase(k)


## The remembered enemy soldiers, oldest id first: [kind, tick, x, y] each.
func soldiers() -> Array:
	var ids: Array = seen.keys()
	ids.sort()
	return ids.map(func(k): return seen[k])


func think(w, bot, workers: Array, army: Array, hx: int, hy: int) -> void:
	if id != 0:
		_drive(w, bot, hx, hy)
		return
	if w.tick < next_tour:
		return
	if tours == 0:
		if workers.size() < int(cfg.worker_at) or w.tick > int(cfg.worker_before) * 20:
			if w.tick > int(cfg.worker_before) * 20:
				tours = 1   # too late for a worker: the soldiers' tours from age 2
			return
		_start(w, bot, _free_worker(w, bot, workers, hx, hy), true, hx, hy)
		return
	if w.ages[bot.player] < int(cfg.soldier_age) or not bot._threats.is_empty() or army.size() < int(cfg.soldier_army):
		return
	var best := -1
	for i in army:   # the fastest idle soldier near home (lowest id on ties)
		if w.units.foe[i] != 0 or w.units.moving[i] != 0 or Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i]) > 400 * 1000000 \
				or w.types[w.units.kind[i]].has("animal"):
			continue
		if best < 0 or w.types[w.units.kind[i]].speed > w.types[w.units.kind[best]].speed:
			best = i
	_start(w, bot, best, false, hx, hy)


## A worker for the tour: a wood or food gatherer near home, not one building.
func _free_worker(w, bot, workers: Array, hx: int, hy: int) -> int:
	var best := -1
	var best_d2 := 1 << 62
	for i in workers:
		if w.units.task[i] == 3 or int(bot.eco.held.get(w.units.id[i], 0)) > w.tick:
			continue   # (building, or kept for something)
		var d2 := Fixed.dist2(hx, hy, w.units.x[i], w.units.y[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


func _start(w, bot, i: int, is_worker: bool, hx: int, hy: int) -> void:
	if i < 0:
		return
	route = _tour(w, bot, i, hx, hy)
	if route.size() < 2:
		next_tour = w.tick + int(cfg.every) * 20
		return
	id = w.units.id[i]
	worker = is_worker
	leg = 0
	hp = w.units.hp[i]
	until = w.tick + int(cfg.worker_seconds if is_worker else cfg.soldier_seconds) * 20
	tours += 1
	if worker:
		bot.eco.held[id] = until
	w.issue(bot.player, Commands.MOVE, {"ids": [id], "x": route[0].x, "y": route[0].y})


## The tour: round the enemy starts first (at `enemy_tiles`, facing us and a sixth of a turn each
## way), then the crossings and the middle of the map (up to `points`), nearest next from where it
## is, on ground it can get to; home last.
func _tour(w, bot, i: int, hx: int, hy: int) -> Array:
	var reach = bot.eco.reach
	var ln: int = w.lane(i)
	var area: int = reach.area_of_unit(w, i)
	var theirs := []
	var r: int = int(cfg.enemy_tiles) * 1000
	for p in w.races.size():
		if not w.is_enemy(bot.player, p) or p >= w.map.starts.size() or w.defeated[p] != 0:
			continue
		var ex: int = int(w.map.starts[p][0])
		var ey: int = int(w.map.starts[p][1])
		var d := maxi(1, Fixed.isqrt(Fixed.dist2(ex, ey, hx, hy)))
		var ux: int = (hx - ex) * 1000 / d   # towards us, per mille
		var uy: int = (hy - ey) * 1000 / d
		for turn in [[1000, 0], [500, 866], [500, -866]]:
			var vx: int = (ux * turn[0] - uy * turn[1]) / 1000
			var vy: int = (ux * turn[1] + uy * turn[0]) / 1000
			theirs.append(Vector2i(ex + vx * r / 1000, ey + vy * r / 1000))
	var rest := []
	for c in bot.land.crossings(w):
		rest.append(Vector2i(c[1] % w.map.width * 1000 + 500, c[1] / w.map.width * 1000 + 500))
	rest.append(Vector2i(w.map.width * 500, w.map.height * 500))
	var ordered := []
	var at := Vector2i(w.units.x[i], w.units.y[i])
	for pts in [_on_ground(w, reach, ln, area, theirs), _on_ground(w, reach, ln, area, rest)]:
		var n := 0
		while not pts.is_empty() and n < int(cfg.points):
			var best := 0
			for k in pts.size():
				if Fixed.dist2(at.x, at.y, pts[k].x, pts[k].y) < Fixed.dist2(at.x, at.y, pts[best].x, pts[best].y):
					best = k
			at = pts[best]
			ordered.append(at)
			pts.remove_at(best)
			n += 1
	ordered.append(Vector2i(hx, hy))
	return ordered


## The points moved onto ground of `area` (the nearest cell of it), ones with none dropped.
static func _on_ground(w, reach, ln: int, area: int, pts: Array) -> Array:
	var out := []
	for p in pts:
		var at: Vector2i = Vector2i(clampi(p.x, 500, w.map.width * 1000 - 500), clampi(p.y, 500, w.map.height * 1000 - 500))
		if reach.area_at(w, ln, at.x, at.y) != area:
			var near: Vector2i = reach.nearest_in(w, ln, area, at.x, at.y)
			if near.x < 0:
				continue
			at = near
		out.append(at)
	return out


func _drive(w, bot, hx: int, hy: int) -> void:
	var i: int = w.units.index_of(id)
	if i < 0:
		_end(w, bot, false)
		return
	var hurt: bool = w.units.hp[i] < hp
	if (hurt or w.tick >= until) and leg < route.size() - 1:
		leg = route.size() - 1   # hit, or out long enough: home
		w.issue(bot.player, Commands.MOVE, {"ids": [id], "x": hx, "y": hy})
		if worker:
			bot.eco.held[id] = w.tick + 400
		return
	if w.units.moving[i] != 0:
		return
	leg += 1
	if leg >= route.size():
		_end(w, bot, true)
		return
	w.issue(bot.player, Commands.MOVE, {"ids": [id], "x": route[leg].x, "y": route[leg].y})


func _end(w, bot, back: bool) -> void:
	if worker and back:
		bot.eco.held.erase(id)   # idle at home: the economy puts it to work
	id = 0
	next_tour = w.tick + int(cfg.every) * 20
