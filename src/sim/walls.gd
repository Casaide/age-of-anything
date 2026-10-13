extends RefCounted
## Walls you stand on (milestone 16). A finished building type with "walkway": N (data/buildings.json:
## stone walls, gatehouses, wall towers) has N standing places per cell along its top. Foot units
## ordered onto it walk to a way up (an access): their team's stairs (a gatehouse or wall tower with
## "stairs"), their side's ladder against the wall, or their side's siege tower docked beside it;
## they climb for walkway.climb seconds and stand on the walkway: the walkway cells of one team that
## touch (8-way, so diagonal lines join) are one network, walked cell to cell at walkway.speed_pct of
## a unit's speed. On a wall a unit is a level up for the high-ground rules (combat.gd _height_step:
## shooters reach further, shots up at it fall short; fog.gd: it sees further); melee from the ground
## can't reach it nor it the ground (combat.gd), and it never chases off the wall. Ordered anywhere
## else, it walks to the best way down (any stairs on its network, whoever's: the enemy's gatehouse
## stairs lead into their town; or its side's ladders and towers) and climbs down beside it, then
## goes on with the order. A unit whose cell stops being a walkway (the wall fell) falls.
##
## Breaches: a wall piece of a type in buildings.json breach.from destroyed leaves its cells as
## walkable rubble (breach.terrain) its owner can rebuild cheaply (Economy.lay_foundation).
##
## A unit on a wall stays in the units arrays (it's seen, hit and selected like anyone) with
## units.perch = its cell + 1; it's left out of movement and separation (world.gd). Climbers are
## an ordinary job (Economy.CLIMB: target = the access id; work counts the climb). Static functions
## over the World `w`, integers only, slot order, no Nodes.

const SimMap := preload("res://src/sim/sim_map.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")

## The 8 ways from a cell: orthogonal first (paths prefer straight steps).
const N8 := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
const DOCK := 1600   # a siege tower stopped with its centre this close to a walkway cell's centre is docked there
const AWAY := 40000  # a way down whose landing has no straight walk to the destination counts this much further (milli-tiles)


static func setup(w) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	var c: Dictionary = d.get("walkway", {})
	var br: Dictionary = d.get("breach", {})
	w.walk_cfg = {"climb": int(c.get("climb", 2)) * w.TICK_HZ, "fall": int(c.get("fall_damage", 10)), "speed_pct": int(c.get("speed_pct", 80)),
		"not": c.get("not", []).duplicate(), "rubble": w.map.terrain_ids.find(br.get("terrain", "")), "from": br.get("from", []).duplicate(),
		"repair_pct": int(br.get("repair_pct", 100)), "push": int(c.get("push", 2))}


# ------------------------------------------------------------------ the walkway

## Standing places on cell c: its finished walkway building's per-cell places, else 0.
static func places(w, c: int) -> int:
	var id: int = w.map.occupied[c]
	if id == 0:
		return 0
	var b: int = w.buildings.index_of(id)
	if b < 0 or w.buildings.done[b] == 0:
		return 0
	return w.btypes[w.buildings.kind[b]].walkway


## The team whose walkway cell c is (call only on a walkway cell).
static func team_at(w, c: int) -> int:
	return w.teams[w.buildings.owner[w.buildings.index_of(w.map.occupied[c])]]


## May unit i go up onto walls at all? Foot soldiers (amphibians too): no workers, animals, flyers (they fly over), siege
## towers or anything with a tag in walkway.not (riders and giants: "large").
static func can_climb(w, i: int) -> bool:
	var t: Dictionary = w.types[w.units.kind[i]]
	if t.has("animal") or t.worker or t.mclass == SimMap.FLYING or t.get("docks", false):
		return false
	for tag in w.walk_cfg.not:
		if tag in t.eval.tags:
			return false
	return true


## Steps from cell `from` to every walkway cell of its network (cell -> steps), breadth first in
## N8 order. Kept for the tick: everyone walking to one cell shares it.
static func dist_from(w, from: int) -> Dictionary:
	if w.wall_cache_tick != w.tick:
		w.wall_cache = {}
		w.wall_cache_tick = w.tick
	if w.wall_cache.has(from):
		return w.wall_cache[from]
	var d := {}
	if places(w, from) > 0:
		var team := team_at(w, from)
		var mw: int = w.map.width
		var mh: int = w.map.height
		d[from] = 0
		var q := [from]
		var k := 0
		while k < q.size():
			var c: int = q[k]
			k += 1
			var cx: int = c % mw
			var cy: int = c / mw
			for n in N8:
				var x: int = cx + n.x
				var y: int = cy + n.y
				if x < 0 or y < 0 or x >= mw or y >= mh:
					continue
				var nc: int = y * mw + x
				if d.has(nc) or places(w, nc) == 0 or team_at(w, nc) != team:
					continue
				d[nc] = d[c] + 1
				q.append(nc)
	w.wall_cache[from] = d
	return d


## Which way cell c's wall runs, for spreading its standing places along it: 0 along sim x, 1
## along y, 2 along (1, 1), 3 along (1, -1).
static func _run_of(w, c: int) -> int:
	var mw: int = w.map.width
	var x: int = c % mw
	var y: int = c / mw
	var on := func(dx: int, dy: int) -> bool:
		var nx := x + dx
		var ny := y + dy
		return nx >= 0 and ny >= 0 and nx < mw and ny < w.map.height and places(w, ny * mw + nx) > 0
	if on.call(1, 0) or on.call(-1, 0):
		return 0
	if on.call(0, 1) or on.call(0, -1):
		return 1
	if on.call(1, 1) or on.call(-1, -1):
		return 2
	if on.call(1, -1) or on.call(-1, 1):
		return 3
	return 0


## Standing place k of p on cell c (milli-tiles): evenly along the wall's run.
static func spot(w, c: int, k: int, p: int) -> Vector2i:
	var mw: int = w.map.width
	var cx: int = (c % mw) * SimMap.TILE + SimMap.TILE / 2
	var cy: int = (c / mw) * SimMap.TILE + SimMap.TILE / 2
	var off: int = (2 * k + 1) * SimMap.TILE / (2 * maxi(p, 1)) - SimMap.TILE / 2
	match _run_of(w, c):
		1:
			return Vector2i(cx, cy + off)
		2:
			return Vector2i(cx + off * 707 / 1000, cy + off * 707 / 1000)
		3:
			return Vector2i(cx + off * 707 / 1000, cy - off * 707 / 1000)
	return Vector2i(cx + off, cy)


static func _centre(w, c: int) -> Vector2i:
	return Vector2i((c % w.map.width) * SimMap.TILE + SimMap.TILE / 2, (c / w.map.width) * SimMap.TILE + SimMap.TILE / 2)


# ------------------------------------------------------------------ ways up and down

## The walkway cell access `acc` (a building or unit id) leads to for a unit of `team` standing
## at (x, y), or -1 if it isn't a way up for that team now: its own stairs (the cell of the stairs
## building nearest), its ladder (the walkway cell it leans on), its docked siege tower (the
## walkway cell it's docked at). `down`: a way down instead, where anyone's stairs will do.
static func top_of(w, acc: int, team: int, x: int, y: int, down := false) -> int:
	var b: int = w.buildings.index_of(acc)
	if b >= 0:
		var bs = w.buildings
		var bt: Dictionary = w.btypes[bs.kind[b]]
		if bs.done[b] == 0:
			return -1
		if bt.stairs and bt.walkway > 0 and (down or w.teams[bs.owner[b]] == team):
			var best := -1
			var best_d := 1 << 62
			for c in bs.footprint(b, w.map.width):
				var p := _centre(w, c)
				var d := Fixed.dist2(x, y, p.x, p.y)
				if d < best_d:
					best_d = d
					best = c
			return best
		if bt.ladder and w.teams[bs.owner[b]] == team:
			return ladder_top(w, bs.cy[b] * w.map.width + bs.cx[b])
		return -1
	var j: int = w.units.index_of(acc)
	if j >= 0 and w.teams[w.units.owner[j]] == team and w.types[w.units.kind[j]].get("docks", false):
		return docked_at(w, j)
	return -1


## The walkway cell a ladder standing on cell c leans on: the first walkway neighbour, N E S W.
static func ladder_top(w, c: int) -> int:
	var mw: int = w.map.width
	var x: int = c % mw
	var y: int = c / mw
	for n in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx: int = x + n.x
		var ny: int = y + n.y
		if nx >= 0 and ny >= 0 and nx < mw and ny < w.map.height and places(w, ny * mw + nx) > 0:
			return ny * mw + nx
	return -1


## The walkway cell siege tower j is docked at (stopped, its centre within DOCK of the cell's
## centre; the nearest such), or -1.
static func docked_at(w, j: int) -> int:
	var u = w.units
	if u.moving[j] == 1:
		return -1
	var mw: int = w.map.width
	var cx: int = u.x[j] / SimMap.TILE
	var cy: int = u.y[j] / SimMap.TILE
	var best := -1
	var best_d := DOCK * DOCK + 1
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= mw or y >= w.map.height:
				continue
			var c := y * mw + x
			if places(w, c) == 0:
				continue
			var p := _centre(w, c)
			var d := Fixed.dist2(u.x[j], u.y[j], p.x, p.y)
			if d < best_d:
				best_d = d
				best = c
	return best


## Every way onto the network of walkway cell `goal` for a unit of `team` (ids, ascending) with the
## cell each leads to: [[id, top cell], ...].
static func ways_up(w, team: int, goal: int, down := false) -> Array:
	var net := dist_from(w, goal)
	var out := []
	if net.is_empty():
		return out
	var bs = w.buildings
	for b in bs.count():
		var bt: Dictionary = w.btypes[bs.kind[b]]
		if not (bt.stairs or bt.ladder) or bs.done[b] == 0:
			continue
		var c: int = bs.cy[b] * w.map.width + bs.cx[b]
		var top := top_of(w, bs.id[b], team, (c % w.map.width) * SimMap.TILE + 500, (c / w.map.width) * SimMap.TILE + 500, down)
		if top >= 0 and net.has(top):
			out.append([bs.id[b], top])
	var u = w.units
	for j in u.count():
		if w.types[u.kind[j]].get("docks", false) and w.teams[u.owner[j]] == team:
			var top := docked_at(w, j)
			if top >= 0 and net.has(top):
				out.append([u.id[j], top])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## Where access `acc` stands (milli-tiles): a building's middle, a unit's centre.
static func _where(w, acc: int) -> Vector2i:
	var b: int = w.buildings.index_of(acc)
	if b >= 0:
		var bs = w.buildings
		return Vector2i(bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2)
	var j: int = w.units.index_of(acc)
	return Vector2i(w.units.x[j], w.units.y[j])


# ------------------------------------------------------------------ orders

## Is (x, y) a spot on a walkway (the cell's places > 0)? The cell, or -1.
static func walkway_at(w, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w.map.width * SimMap.TILE or y >= w.map.height * SimMap.TILE:
		return -1
	var c: int = w.map.cell_of(x, y)
	return c if places(w, c) > 0 else -1


## A MOVE onto walkway cell `goal`: each unit that may climb goes to a standing place on the
## network round it (the nearest with room, filled in id order: a group spreads along the wall),
## walking along the walkway if it's already on that network, else to its nearest way up. Returns
## the ids it took (the rest move as usual: they can't climb, or their side has no way up there).
static func order_onto(w, player: int, ids: Array, goal: int) -> Array:
	var u = w.units
	var team: int = w.teams[player]
	var net := dist_from(w, goal)
	if net.is_empty():
		return []
	var mine := []   # slots of the units this order takes
	for uid in ids:
		var i: int = u.index_of(uid)
		if i >= 0 and u.owner[i] == player and can_climb(w, i):
			mine.append(i)
	if mine.is_empty():
		return []
	var ups := ways_up(w, team, goal)
	var held := _held(w, mine)
	var order: Array = net.keys()
	order.sort_custom(func(a, b): return net[a] < net[b] or (net[a] == net[b] and a < b))
	var taken := []
	var k := 0
	for i in mine:
		var on_net: bool = u.perch[i] != 0 and net.has(u.perch[i] - 1)
		if u.perch[i] != 0 and not on_net:
			continue   # up on another wall: it climbs down first (World._wall_orders)
		var acc := 0
		if not on_net:
			acc = _nearest_way(w, i, ups)
			if acc == 0:
				continue   # no way up for its side: it walks to the foot of the wall instead
		while k < order.size() and int(held.get(order[k], 0)) >= places(w, order[k]):
			k += 1
		var cell: int = order[k] if k < order.size() else goal
		held[cell] = int(held.get(cell, 0)) + 1
		taken.append(u.id[i])
		if on_net:
			_walk(w, i, cell)
		else:
			_climb_via(w, i, acc, cell)
	return taken


## The nearest of these ways up to unit i (straight-line; lowest id on ties), or 0.
static func _nearest_way(w, i: int, ups: Array) -> int:
	var best := 0
	var best_d := 1 << 62
	for e in ups:
		var p := _where(w, e[0])
		var d := Fixed.dist2(w.units.x[i], w.units.y[i], p.x, p.y)
		if d < best_d:
			best_d = d
			best = e[0]
	return best


## Unit i (on the ground) goes up by access `acc`, then to walkway cell `cell`.
static func _climb_via(w, i: int, acc: int, cell: int) -> void:
	var u = w.units
	_off_wall_fields(w, i)
	Economy.clear_task(w, i)
	u.foe[i] = 0
	u.stance[i] = 0
	u.patient[i] = 0
	u.task[i] = Economy.CLIMB
	u.target[i] = acc
	u.wgoal[i] = cell + 1
	_approach(w, i, acc)


static func _approach(w, i: int, acc: int) -> void:
	var b: int = w.buildings.index_of(acc)
	if b >= 0:
		Economy._approach_building(w, i, b)
		return
	var j: int = w.units.index_of(acc)
	w.order_move(i, w.units.x[j], w.units.y[j], w.units.radius[j] + Economy.REACH, 0)


## Is unit i close enough to access `acc` to climb it?
static func _at(w, i: int, acc: int) -> bool:
	var b: int = w.buildings.index_of(acc)
	if b >= 0:
		return Economy._in_reach(w, i, Economy._building_rect(w, b))
	var j: int = w.units.index_of(acc)
	var r: int = w.units.radius[i] + w.units.radius[j] + Economy.REACH
	return Fixed.dist2(w.units.x[i], w.units.y[i], w.units.x[j], w.units.y[j]) <= r * r


## Unit i on a wall walks to walkway cell `cell` of its network (staying up there).
static func _walk(w, i: int, cell: int) -> void:
	var u = w.units
	u.wgoal[i] = cell + 1
	u.wnext[i] = 0
	u.wexit[i] = 0
	u.wtime[i] = 0
	u.foe[i] = 0
	u.stance[i] = 0


## Unit i on a wall leaves it for (x, y): the way down of its network that lands nearest there
## (steps along the wall count a tile each), then on the ground it walks to (x, y). False if its
## network has no way down for it (it stays).
static func leave(w, i: int, x: int, y: int) -> bool:
	var u = w.units
	var at: int = u.perch[i] - 1
	var downs := ways_up(w, w.teams[u.owner[i]], at, true)
	var net := dist_from(w, at)
	var best := 0
	var best_top := -1
	var best_d := 1 << 62
	for e in downs:
		var land := _landing(w, i, e[0], e[1], x, y)
		if land < 0:
			continue
		var p := _centre(w, land)
		var d: int = Fixed.isqrt(Fixed.dist2(p.x, p.y, x, y)) + int(net.get(e[1], 0)) * SimMap.TILE
		if not Flow.clear_line(w.map, p.x, p.y, x, y, w.lane(i)):
			d += AWAY   # a wall (or anything) between the landing and where it's going: the wrong side, likely
		if d < best_d:
			best_d = d
			best = e[0]
			best_top = e[1]
	if best == 0:
		return false
	u.wexit[i] = best
	u.wgoal[i] = best_top + 1
	u.wnext[i] = 0
	u.wtime[i] = 0
	u.tx[i] = x
	u.ty[i] = y
	u.foe[i] = 0
	u.stance[i] = 0
	return true


## Where unit i lands climbing down by access `acc` (from walkway cell `top`) heading for (x, y):
## the open ground cell (in its lane) beside the access nearest (x, y); -1 if none.
static func _landing(w, i: int, acc: int, top: int, x: int, y: int) -> int:
	var cells := PackedInt32Array()
	var b: int = w.buildings.index_of(acc)
	if b >= 0:
		cells = w.buildings.footprint(b, w.map.width)
		if w.btypes[w.buildings.kind[b]].ladder:
			cells.append(top)
	else:
		var j: int = w.units.index_of(acc)
		cells.append(w.map.cell_of(w.units.x[j], w.units.y[j]))
	var ln: int = w.lane(i)
	var mw: int = w.map.width
	var best := -1
	var best_d := 1 << 62
	for c in cells:
		for n in [Vector2i(0, 0)] + N8:
			var cx: int = c % mw + n.x
			var cy: int = c / mw + n.y
			if cx < 0 or cy < 0 or cx >= mw or cy >= w.map.height:
				continue
			var nc: int = cy * mw + cx
			if w.map.walks[ln][nc] == 0:
				continue
			var p := _centre(w, nc)
			var d := Fixed.dist2(p.x, p.y, x, y)
			if d < best_d or (d == best_d and nc < best):
				best_d = d
				best = nc
	return best


## Put unit i straight up on walkway cell c, settled (a mode's garrison at the start: modes.gd).
static func set_on(w, i: int, c: int) -> void:
	var u = w.units
	_off_wall_fields(w, i)
	u.perch[i] = c + 1
	var p := _centre(w, c)
	u.x[i] = p.x
	u.y[i] = p.y
	u.px[i] = p.x
	u.py[i] = p.y
	u.moving[i] = 0


## Units on their way up or along a wall (or climbing down) count as busy for queued orders.
static func busy(w, i: int) -> bool:
	return w.units.perch[i] != 0 and (w.units.wgoal[i] != 0 or w.units.wtime[i] != 0)


## A STOP: a unit on a wall stops where it is (a climb down under way finishes).
static func stop(w, i: int) -> void:
	var u = w.units
	if u.perch[i] != 0 and u.wtime[i] == 0:
		u.wgoal[i] = 0
		u.wnext[i] = 0
		u.wexit[i] = 0


static func _off_wall_fields(w, i: int) -> void:
	var u = w.units
	u.perch[i] = 0
	u.wgoal[i] = 0
	u.wnext[i] = 0
	u.wexit[i] = 0
	u.wtime[i] = 0


# ------------------------------------------------------------------ tick

## One tick: climbers walk to their way up and climb; units on walls walk along them, settle on
## their standing places, climb down, or fall. Runs after the garrison, before the spatial buckets.
static func tick(w) -> void:
	var u = w.units
	var n: int = u.count()
	var pr: PackedInt32Array = u.perch
	var tasks: PackedInt32Array = u.task
	var any := false
	for i in n:
		if pr[i] != 0 or tasks[i] == Economy.CLIMB:
			any = true
			break
	if not any:
		return
	var climb: int = w.walk_cfg.climb
	for i in n:
		if u.task[i] != Economy.CLIMB:
			continue
		var acc: int = u.target[i]
		var top := top_of(w, acc, w.teams[u.owner[i]], u.x[i], u.y[i])
		if top < 0:   # its way up is gone (or a ladder's wall fell)
			Economy.clear_task(w, i)
			u.wgoal[i] = 0
			u.moving[i] = 0
			continue
		if u.work[i] > 0:
			u.work[i] += 1
			if u.work[i] >= climb:
				_up(w, i, top)
		elif _at(w, i, acc):
			u.moving[i] = 0
			u.work[i] = 1
			w.events.append({"type": "climb", "id": u.id[i], "up": true})
		elif u.moving[i] == 0:
			if u.stuck[i] >= Economy.GIVE_UP:
				Economy.clear_task(w, i)
				u.wgoal[i] = 0
			else:
				_approach(w, i, acc)
	_push_ladders(w)
	var held := {}       # walkway cell -> units on it or making for it (_held), worked out when a cell is found full
	var settled := {}   # cell -> units settled there so far this tick (ascending ids)
	for i in n:
		if u.perch[i] == 0:
			continue
		var c: int = u.perch[i] - 1
		if places(w, c) == 0:
			_fall(w, i)
			continue
		if u.wtime[i] > 0:
			u.wtime[i] -= 1
			if u.wtime[i] == 0:
				_down(w, i)
			continue
		if u.wgoal[i] != 0:
			_step(w, i)
			continue
		var p := places(w, c)
		var k: int = settled.get(c, 0)
		if k >= p:   # no room here (a crowd came up the same stairs): the nearest cell with room
			if held.is_empty():
				held = _held(w, [])
			var net := dist_from(w, c)
			var best := -1
			var best_d := 1 << 30
			for nc in net:
				if int(held.get(nc, 0)) < places(w, nc) and (net[nc] < best_d or (net[nc] == best_d and nc < best)):
					best_d = net[nc]
					best = nc
			if best >= 0:
				held[best] = int(held.get(best, 0)) + 1
				held[c] = int(held.get(c, 1)) - 1
				_walk(w, i, best)
				continue
		settled[c] = k + 1
		if u.wnext[i] == k + 1:
			continue   # on its place already (settled: wnext is its place + 1)
		var s := spot(w, c, mini(k, p - 1), p)
		if _toward(w, i, s.x, s.y):
			u.wnext[i] = k + 1


## Defenders push ladders off: a finished ladder whose walkway cell has a defender settled on it
## (a unit up there whose team the wall is, not the ladder's) and no attacker loses walkway.push hp
## a tick; at none it falls (a "die" event, like a building knocked down).
static func _push_ladders(w) -> void:
	var bs = w.buildings
	var u = w.units
	var push: int = int(w.walk_cfg.push)
	for b in range(bs.count() - 1, -1, -1):
		if not w.btypes[bs.kind[b]].ladder or bs.done[b] == 0:
			continue
		var top := ladder_top(w, bs.cy[b] * w.map.width + bs.cx[b])
		if top < 0:
			continue
		var team: int = w.teams[bs.owner[b]]
		var defenders := 0
		var attackers := 0
		for i in u.count():
			if u.perch[i] == top + 1:
				if w.teams[u.owner[i]] == team:
					attackers += 1
				elif u.wgoal[i] == 0:
					defenders += 1
		if defenders == 0 or attackers > 0:
			continue
		bs.hp[b] -= push * defenders
		if bs.hp[b] <= 0:
			w.events.append({"type": "die", "id": bs.id[b], "x": bs.cx[b] * SimMap.TILE + SimMap.TILE / 2, "y": bs.cy[b] * SimMap.TILE + SimMap.TILE / 2,
				"owner": bs.owner[b], "kind": bs.kind[b], "building": true, "pushed": true})
			breach(w, b)
			w.map.occupy(bs.footprint(b, w.map.width), 0)
			bs.remove_at(b)


## Units of a building's own team settled on each walkway cell (cell -> count): who mans what.
static func manned(w) -> Dictionary:
	var u = w.units
	var out := {}
	for i in u.count():
		if u.perch[i] != 0 and u.wgoal[i] == 0 and u.wtime[i] == 0:
			var c: int = u.perch[i] - 1
			if team_at(w, c) == w.teams[u.owner[i]]:
				out[c] = int(out.get(c, 0)) + 1
	return out


## Units standing on (or making for) each walkway cell, leaving out the slots in `except`.
static func _held(w, except: Array) -> Dictionary:
	var u = w.units
	var held := {}
	for i in u.count():
		if except.has(i):
			continue
		var c := -1
		if u.perch[i] != 0 and u.wexit[i] == 0:
			c = (u.wgoal[i] if u.wgoal[i] != 0 else u.perch[i]) - 1
		elif u.task[i] == Economy.CLIMB and u.wgoal[i] != 0:
			c = u.wgoal[i] - 1
		if c >= 0:
			held[c] = int(held.get(c, 0)) + 1
	return held


## Climbed up: unit i stands on walkway cell `top`, then walks to its goal.
static func _up(w, i: int, top: int) -> void:
	var u = w.units
	var goal: int = u.wgoal[i]
	Economy.clear_task(w, i)
	u.moving[i] = 0
	u.perch[i] = top + 1
	var p := _centre(w, top)
	u.x[i] = p.x
	u.y[i] = p.y
	u.wgoal[i] = goal if goal != 0 and dist_from(w, top).has(goal - 1) else top + 1
	u.wnext[i] = 0
	u.stuck[i] = 0
	u.foe[i] = 0
	u.stance[i] = 0


## One step of unit i along the walkway towards its goal (and, at its way down, the climb down).
static func _step(w, i: int) -> void:
	var u = w.units
	var c: int = u.perch[i] - 1
	var goal: int = u.wgoal[i] - 1
	if c == goal:
		var p := _centre(w, c)
		if u.wexit[i] != 0:
			if _toward(w, i, p.x, p.y):
				u.wgoal[i] = 0
				u.wtime[i] = w.walk_cfg.climb
				w.events.append({"type": "climb", "id": u.id[i], "up": false})
			return
		u.wgoal[i] = 0   # there: it settles on a standing place next tick
		u.wnext[i] = 0
		return
	if u.wnext[i] == 0:
		var d := dist_from(w, goal)
		if not d.has(c):   # cut off (a piece fell between): it stays
			u.wgoal[i] = 0
			u.wexit[i] = 0
			return
		var mw: int = w.map.width
		var nxt := -1
		for nb in N8:
			var x: int = c % mw + nb.x
			var y: int = c / mw + nb.y
			var nc: int = y * mw + x
			if x >= 0 and y >= 0 and x < mw and y < w.map.height and d.has(nc) and d[nc] == d[c] - 1:
				nxt = nc
				break
		u.wnext[i] = nxt + 1
	var to: int = u.wnext[i] - 1
	if places(w, to) == 0:
		u.wnext[i] = 0
		return
	var q := _centre(w, to)
	var from := _centre(w, c)
	_toward(w, i, q.x, q.y)
	# Over the line between the two cells: it stands on the next one.
	if Fixed.dist2(u.x[i], u.y[i], q.x, q.y) <= Fixed.dist2(u.x[i], u.y[i], from.x, from.y):
		u.perch[i] = to + 1
		u.wnext[i] = 0


## Move unit i straight towards (x, y) at its walkway pace; true once there.
static func _toward(w, i: int, x: int, y: int) -> bool:
	var u = w.units
	var dx: int = x - u.x[i]
	var dy: int = y - u.y[i]
	var len := Fixed.isqrt(dx * dx + dy * dy)
	var s: int = maxi(1, u.speed[i] * int(w.walk_cfg.speed_pct) / 100)
	if len <= s:
		u.x[i] = x
		u.y[i] = y
		return true
	u.x[i] += dx * s / len
	u.y[i] += dy * s / len
	return false


## Climbed down: unit i stands on the ground beside its way down, then walks on to where it was going.
static func _down(w, i: int) -> void:
	var u = w.units
	var land := _landing(w, i, u.wexit[i], u.perch[i] - 1, u.tx[i], u.ty[i])
	if land < 0:
		land = Flow.nearest_walkable(w.map, u.perch[i] - 1, w.lane(i))
	var x: int = u.tx[i]
	var y: int = u.ty[i]
	_off_wall_fields(w, i)
	var p := _centre(w, land)
	u.x[i] = p.x
	u.y[i] = p.y
	u.px[i] = p.x
	u.py[i] = p.y
	if Fixed.dist2(p.x, p.y, x, y) > SimMap.TILE * SimMap.TILE / 4:
		w.order_move(i, x, y, w.SLOT_ARRIVE, 0)


## The wall under unit i is gone: it drops to the nearest open ground, hurt by the fall (never to
## below 1 hp).
static func _fall(w, i: int) -> void:
	var u = w.units
	var c: int = u.perch[i] - 1
	_off_wall_fields(w, i)
	var p := Flow.centre(w.map, Flow.nearest_walkable(w.map, c, w.lane(i)))
	u.x[i] = p.x
	u.y[i] = p.y
	u.moving[i] = 0
	u.foe[i] = 0
	u.stance[i] = 0
	u.hp[i] = maxi(1, u.hp[i] - int(w.walk_cfg.fall))
	w.events.append({"type": "fall", "id": u.id[i], "x": p.x, "y": p.y})


# ------------------------------------------------------------------ breaches

## Wall piece b is falling (destroyed): if its type leaves rubble, its cells become breach
## terrain owned by its player, remembering what stood there (w.rubble: cell -> [terrain it was,
## owner, building type, top-left x, y, along]). Call before the building is removed.
static func breach(w, b: int) -> void:
	var bs = w.buildings
	var bt: Dictionary = w.btypes[bs.kind[b]]
	if bt.ladder:
		w.map.set_walk_over(bs.footprint(b, w.map.width), false)
	var rub: int = w.walk_cfg.rubble
	if rub < 0 or not bt.id in w.walk_cfg.from or bs.done[b] == 0:
		return
	var along := 0
	if bs.diag[b] != 0:
		along = bs.diag[b] + 1
	elif bs.sy[b] > bs.sx[b]:
		along = 1
	for c in bs.footprint(b, w.map.width):
		if w.rubble.has(c):
			continue
		w.rubble[c] = PackedInt32Array([w.map.terrain[c], bs.owner[b], bs.kind[b], bs.cx[b], bs.cy[b], along])
		w.map.set_terrain(c, rub)


## A building goes up over these cells: any rubble there is cleared (the ground it was comes back).
static func clear_rubble(w, cells: PackedInt32Array) -> void:
	if w.rubble.is_empty():
		return
	for c in cells:
		if w.rubble.has(c):
			var rec: PackedInt32Array = w.rubble[c]
			w.rubble.erase(c)
			w.map.set_terrain(c, rec[0])


## The rubble on cell c if `player` may rebuild there: {building: type id, cx, cy, along}, else {}.
static func rebuild_of(w, player: int, c: int) -> Dictionary:
	if not w.rubble.has(c):
		return {}
	var rec: PackedInt32Array = w.rubble[c]
	if rec[1] != player or Economy.why_not_build(w, player, rec[2]) != "":
		return {}   # (not its rubble, or a piece its race doesn't build: milestone 14's lacks)
	return {"building": w.btypes[rec[2]].id, "cx": rec[3], "cy": rec[4], "along": rec[5]}


## Is every cell of this footprint rubble of `player`'s (a breach being rebuilt: it costs less)?
static func all_rubble(w, player: int, cells: PackedInt32Array) -> bool:
	if w.rubble.is_empty() or cells.is_empty():
		return false
	for c in cells:
		if not w.rubble.has(c) or w.rubble[c][1] != player:
			return false
	return true


## Mix the walls' state into a hash: units on walls or climbing, and the rubble. Nothing at all
## when nobody has been up and nothing has fallen, so hashes of matches without them don't move.
static func hash_into(w, h: int) -> int:
	var u = w.units
	for i in u.count():
		if u.perch[i] != 0 or u.wgoal[i] != 0:
			for v in [u.id[i], u.perch[i], u.wgoal[i], u.wnext[i], u.wexit[i], u.wtime[i]]:
				h = Fixed.mix(h, v)
	if not w.pour_at.is_empty():
		var ids: Array = w.pour_at.keys()
		ids.sort()
		for id in ids:
			h = Fixed.mix(Fixed.mix(h, id), w.pour_at[id])
	if not w.rubble.is_empty():
		var cells: Array = w.rubble.keys()
		cells.sort()
		for c in cells:
			h = Fixed.mix(h, c)
			for v in w.rubble[c]:
				h = Fixed.mix(h, v)
	return h
