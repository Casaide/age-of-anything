extends RefCounted
## The simulation. Pure data, integer maths, fixed 20 Hz ticks, driven only by
## the command stream. Views read it; nothing outside writes to it except
## through commands. Same seed + map + races + commands = same state hashes.
##
## One tick: run this turn's commands -> move -> separate -> (every 30) hash.
## Movement: each unit steers at a waypoint taken from the flow field of its
## target cell, re-planned every few ticks; groups settle when they bump a
## groupmate that has already arrived. At most one new flow field is solved per
## tick (queued in order); until a unit's field is ready it heads straight on.

const Fixed := preload("res://src/sim/fixed.gd")
const Rng := preload("res://src/rng.gd")
const Commands := preload("res://src/sim/commands.gd")
const Units := preload("res://src/sim/units.gd")
const Spatial := preload("res://src/sim/spatial.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Flow := preload("res://src/sim/flow.gd")

const TICK_HZ := 20
const HASH_EVERY := 30
const SPEED_SCALE := 5         # speed stat 10 -> 50 milli-tiles a tick = 1 tile a second
const BASE_RADIUS := 300       # milli-tiles at recipe scale 100
const MOUNTED_RADIUS := 420
const MAX_RADIUS := 500        # spatial cells are one tile; see spatial.gd
const SPAWN_JITTER := 400
const ARRIVE_STEP := 300       # group arrival radius = ARRIVE_STEP * isqrt(n) - ARRIVE_BASE
const ARRIVE_BASE := 180
const SEPARATION_DIV := 4      # each unit of an overlapping pair moves overlap / 4 per tick
const REPLAN_EVERY := 8        # ticks between waypoint re-plans (staggered by unit id)
const LOOKAHEAD := 6           # field cells to look down for the furthest clear waypoint
const DIRECT_COST := 160       # field cost under which we try a straight line to the target
const SETTLE_FACTOR := 4       # bumping a stopped groupmate within arrive * this counts as arrived
const STUCK_LIMIT := 60        # ticks without progress before a unit gives up (3 s)
const RETURN_SLACK := 1000     # shoved this far beyond its settle radius, a stopped unit walks back
const FIELD_CACHE := 16        # flow fields kept (oldest dropped first)

var seed_value: int
var tick := 0
var rng: Rng
var map: SimMap
var races: Array               # race dicts, one per player
var types: Array = []          # unit types: {player, slot, name, recipe, speed, radius, hp}
var units: Units = Units.new()
var spatial: Spatial
var commands: Commands = Commands.new()
var history: Array = []          # every command that ran, in run order
var hashes: Array = []         # [[tick, hash]] every HASH_EVERY ticks
var next_id := 1
var next_group := 1
var fields := {}               # target cell -> Flow; looked up by key, never iterated
var field_order: Array = []    # cached target cells, oldest first, for eviction
var field_queue: Array = []    # target cells waiting for a solve, in request order


func _init(p_seed: int, p_map: SimMap, p_races: Array) -> void:
	seed_value = p_seed
	rng = Rng.new(p_seed)
	map = p_map
	races = p_races
	spatial = Spatial.new(map.width, map.height)
	for p in races.size():
		for u in races[p].units:
			types.append(_make_type(p, u))


func _make_type(player: int, u: Dictionary) -> Dictionary:
	var r: Dictionary = u.recipe
	var e: Dictionary = u.eval
	for k in ["speed", "hp"]:
		assert(typeof(e[k]) == TYPE_INT, "Unit stat %s must be an int" % k)
	var radius: int = BASE_RADIUS * int(r.scale) / 100
	if r.has("mount"):
		radius = maxi(radius, MOUNTED_RADIUS)
	return {
		"player": player, "slot": r.slot, "name": r.get("name", r.slot), "recipe": r,
		"speed": int(e.speed) * SPEED_SCALE, "radius": mini(radius, MAX_RADIUS), "hp": int(e.hp),
	}


## Unit type index for a player's roster slot, or -1.
func type_of(player: int, slot: String) -> int:
	for k in types.size():
		if types[k].player == player and types[k].slot == slot:
			return k
	return -1


func turn() -> int:
	return Commands.turn_of(tick)


## Issue a command for a player in the current turn (player UI and AI).
func issue(player: int, type: String, args: Dictionary) -> Dictionary:
	return commands.issue(turn(), player, type, args)


func step() -> void:
	if tick % Commands.TICKS_PER_TURN == 0:
		for cmd in commands.take(turn()):
			_run(cmd)
			history.append(cmd)
	units.save_prev()
	if not field_queue.is_empty():
		_solve(field_queue.pop_front())
	_move()
	spatial.build(units.x, units.y)
	_separate()
	tick += 1
	if tick % HASH_EVERY == 0:
		hashes.append([tick, state_hash()])


func _run(cmd: Dictionary) -> void:
	var a: Dictionary = cmd.args
	match cmd.type:
		Commands.MOVE:
			var slots := []
			for uid in a.ids:
				var i := units.index_of(uid)
				if i >= 0 and units.owner[i] == cmd.player:
					slots.append(i)
			if slots.is_empty():
				return
			var x: int = clampi(a.x, 0, map.width * SimMap.TILE - 1)
			var y: int = clampi(a.y, 0, map.height * SimMap.TILE - 1)
			var cell := (y / SimMap.TILE) * map.width + x / SimMap.TILE
			if map.walk[cell] == 0:
				cell = Flow.nearest_walkable(map, cell)
				var c := Flow.centre(map, cell)
				x = c.x
				y = c.y
			field_for(cell)   # queues the solve
			var arrive := ARRIVE_STEP * Fixed.isqrt(slots.size()) - ARRIVE_BASE
			for i in slots:
				units.tx[i] = x
				units.ty[i] = y
				units.moving[i] = 1
				units.arrive[i] = arrive
				units.group[i] = next_group
				units.stuck[i] = 0
				var w := _plan(units.x[i], units.y[i], x, y)
				units.wx[i] = w.x if w.x >= 0 else units.x[i]
				units.wy[i] = w.y if w.x >= 0 else units.y[i]
			next_group += 1
		Commands.SPAWN:
			var k := type_of(cmd.player, a.slot)
			assert(k >= 0, "Player %d has no unit for slot %s" % [cmd.player, a.slot])
			var t: Dictionary = types[k]
			for n in a.count:
				var x: int = a.x + rng.range_int(-SPAWN_JITTER, SPAWN_JITTER)
				var y: int = a.y + rng.range_int(-SPAWN_JITTER, SPAWN_JITTER)
				if not map.walkable(x, y):
					x = a.x
					y = a.y
				units.add(next_id, cmd.player, k, x, y, t.speed, t.radius, t.hp)
				next_id += 1


func _move() -> void:
	var xs := units.x
	var ys := units.y
	var mv := units.moving
	var st := units.stuck
	var wxs := units.wx
	var wys := units.wy
	var txs := units.tx
	var tys := units.ty
	var ar := units.arrive
	var sp := units.speed
	var ids := units.id
	var grp := units.group
	for i in xs.size():
		if mv[i] == 0:
			# Shoved well off its spot by passing units? Walk back (checked on re-plan ticks).
			if grp[i] == 0 or st[i] >= STUCK_LIMIT or (tick + ids[i]) % REPLAN_EVERY != 0:
				continue
			var back := ar[i] * SETTLE_FACTOR + RETURN_SLACK
			if Fixed.dist2(xs[i], ys[i], txs[i], tys[i]) <= back * back:
				continue
			mv[i] = 1
		var x := xs[i]
		var y := ys[i]
		var dx := txs[i] - x
		var dy := tys[i] - y
		if dx * dx + dy * dy <= ar[i] * ar[i]:
			mv[i] = 0
			continue
		var s := sp[i]
		if (tick + ids[i]) % REPLAN_EVERY == 0 or Fixed.dist2(x, y, wxs[i], wys[i]) <= s * s:
			var w := _plan(x, y, txs[i], tys[i])
			if w.x < 0:
				mv[i] = 0   # unreachable from here
				continue
			wxs[i] = w.x
			wys[i] = w.y
		dx = wxs[i] - x
		dy = wys[i] - y
		var d := Fixed.isqrt(dx * dx + dy * dy)
		var nx := x
		var ny := y
		if d > 0:
			nx = x + dx * mini(s, d) / d
			ny = y + dy * mini(s, d) / d
		if map.walkable(nx, ny):
			pass
		elif map.walkable(nx, y):
			ny = y
		elif map.walkable(x, ny):
			nx = x
		else:
			nx = x
			ny = y
		if nx == x and ny == y:
			st[i] += 1
			if st[i] >= STUCK_LIMIT:
				mv[i] = 0   # give up; the tests count these
			else:
				var w := _plan(x, y, txs[i], tys[i])
				wxs[i] = w.x if w.x >= 0 else x
				wys[i] = w.y if w.x >= 0 else y
			continue
		st[i] = 0
		xs[i] = nx
		ys[i] = ny
	units.x = xs
	units.y = ys
	units.moving = mv
	units.stuck = st
	units.wx = wxs
	units.wy = wys


## The next waypoint from (x, y) towards target (tx, ty): the target itself if
## the way is clear, else the furthest clear cell a few steps down the flow field.
## (-1, -1) if the target can't be reached from here.
func _plan(x: int, y: int, tx: int, ty: int) -> Vector2i:
	var goal := (ty / SimMap.TILE) * map.width + tx / SimMap.TILE
	var f = field_for(goal)
	if f == null:
		return Vector2i(tx, ty)   # field not solved yet: head straight for now
	var cell := (y / SimMap.TILE) * map.width + x / SimMap.TILE
	var cost: int = f.dist[cell]
	if cost >= Flow.INF:
		return Vector2i(-1, -1)
	if cell == goal or (cost <= DIRECT_COST and Flow.clear_line(map, x, y, tx, ty)):
		return Vector2i(tx, ty)
	var best := cell
	var k: int = f.next[cell]
	for step in LOOKAHEAD:
		if k < 0:
			break
		var c := Flow.centre(map, k)
		if not Flow.clear_line(map, x, y, c.x, c.y):
			break
		best = k
		if k == goal:
			break
		k = f.next[k]
	return Flow.centre(map, best)


## The flow field towards a cell, or null (and queued) if it isn't solved yet.
func field_for(cell: int) -> RefCounted:
	if fields.has(cell):
		return fields[cell]
	if not cell in field_queue:
		field_queue.append(cell)
	return null


func _solve(cell: int) -> void:
	if fields.has(cell):
		return
	fields[cell] = Flow.solve(map, cell)
	field_order.append(cell)
	if field_order.size() > FIELD_CACHE:
		fields.erase(field_order.pop_front())


## Push overlapping pairs apart. Reads positions from before any pushes this
## tick, so the result doesn't depend on which unit of a pair comes first.
## A moving unit touching a stopped groupmate near the target settles too, and
## units get pushed out of blocked neighbour tiles.
func _separate() -> void:
	var n := units.count()
	var xs := units.x
	var ys := units.y
	var rs := units.radius
	var ids := units.id
	var mv := units.moving
	var grp := units.group
	var txs := units.tx
	var tys := units.ty
	var ar := units.arrive
	var settle := PackedByteArray()
	settle.resize(n)
	var start := spatial.start
	var items := spatial.items
	var cells := spatial.cell
	var w := spatial.width
	var h := spatial.height
	var pushx := PackedInt32Array()
	var pushy := PackedInt32Array()
	pushx.resize(n)
	pushy.resize(n)
	for i in n:
		var cx := cells[i] % w
		var cy := cells[i] / w
		for yy in range(maxi(cy - 1, 0), mini(cy + 2, h)):
			for xx in range(maxi(cx - 1, 0), mini(cx + 2, w)):
				var c := yy * w + xx
				for k in range(start[c], start[c + 1]):
					var j := items[k]
					if j <= i:
						continue
					var rr := rs[i] + rs[j]
					var dx := xs[j] - xs[i]
					var dy := ys[j] - ys[i]
					if dx >= rr or dx <= -rr or dy >= rr or dy <= -rr:
						continue
					var d2 := dx * dx + dy * dy
					if d2 >= rr * rr:
						continue
					if grp[i] == grp[j] and grp[i] > 0 and mv[i] != mv[j]:
						var m := i if mv[i] == 1 else j
						var near := ar[m] * SETTLE_FACTOR
						if Fixed.dist2(xs[m], ys[m], txs[m], tys[m]) <= near * near:
							settle[m] = 1
					var d := Fixed.isqrt(d2)
					var ux: int
					var uy: int
					if d == 0:
						var ang := (ids[i] * 31 + ids[j] * 17) & 255
						ux = Fixed.cos_a(ang)
						uy = Fixed.sin_a(ang)
					else:
						ux = dx * Fixed.ONE / d
						uy = dy * Fixed.ONE / d
					var push := (rr - d) / SEPARATION_DIV + 1
					var px := ux * push / Fixed.ONE
					var py := uy * push / Fixed.ONE
					pushx[i] -= px
					pushy[i] -= py
					pushx[j] += px
					pushy[j] += py
	var t := SimMap.TILE
	for i in n:
		if settle[i] == 1:
			mv[i] = 0
		if pushx[i] != 0 and map.walkable(xs[i] + pushx[i], ys[i]):
			xs[i] += pushx[i]
		if pushy[i] != 0 and map.walkable(xs[i], ys[i] + pushy[i]):
			ys[i] += pushy[i]
		# Keep the body (not just the centre) off blocked neighbour tiles.
		var cx := xs[i] / t
		var cy := ys[i] / t
		var r := rs[i]
		if xs[i] - cx * t < r and not map.cell_walkable(cx - 1, cy):
			xs[i] = cx * t + r
		elif (cx + 1) * t - xs[i] < r and not map.cell_walkable(cx + 1, cy):
			xs[i] = (cx + 1) * t - r
		if ys[i] - cy * t < r and not map.cell_walkable(cx, cy - 1):
			ys[i] = cy * t + r
		elif (cy + 1) * t - ys[i] < r and not map.cell_walkable(cx, cy + 1):
			ys[i] = (cy + 1) * t - r
	units.x = xs
	units.y = ys
	units.moving = mv


## Hash of everything that matters, in id order.
func state_hash() -> int:
	var h := Fixed.FNV_START
	for v in [tick, rng.state, next_id, next_group, units.count()]:
		h = Fixed.mix(h, v)
	# Which fields are solved or pending changes how units steer, so it's state too.
	for c in field_order:
		h = Fixed.mix(h, c)
	h = Fixed.mix(h, -1)
	for c in field_queue:
		h = Fixed.mix(h, c)
	var u := units
	for i in u.count():
		h = Fixed.mix(h, u.id[i])
		h = Fixed.mix(h, u.owner[i])
		h = Fixed.mix(h, u.kind[i])
		h = Fixed.mix(h, u.x[i])
		h = Fixed.mix(h, u.y[i])
		h = Fixed.mix(h, u.tx[i])
		h = Fixed.mix(h, u.ty[i])
		h = Fixed.mix(h, u.moving[i])
		h = Fixed.mix(h, u.arrive[i])
		h = Fixed.mix(h, u.wx[i])
		h = Fixed.mix(h, u.wy[i])
		h = Fixed.mix(h, u.group[i])
		h = Fixed.mix(h, u.stuck[i])
		h = Fixed.mix(h, u.hp[i])
	return h
