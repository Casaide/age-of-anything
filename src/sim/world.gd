extends RefCounted
## The simulation. Pure data, integer maths, fixed 20 Hz ticks, driven only by
## the command stream. Views read it; nothing outside writes to it except
## through commands. Same seed + map + races + commands = same state hashes.
##
## One tick: run this turn's commands -> move -> separate -> (every 30) hash.

const Fixed := preload("res://src/sim/fixed.gd")
const Rng := preload("res://src/rng.gd")
const Commands := preload("res://src/sim/commands.gd")
const Units := preload("res://src/sim/units.gd")
const Spatial := preload("res://src/sim/spatial.gd")
const SimMap := preload("res://src/sim/sim_map.gd")

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
			var arrive := ARRIVE_STEP * Fixed.isqrt(slots.size()) - ARRIVE_BASE
			for i in slots:
				units.tx[i] = a.x
				units.ty[i] = a.y
				units.moving[i] = 1
				units.arrive[i] = arrive
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
	var txs := units.tx
	var tys := units.ty
	var sp := units.speed
	var ar := units.arrive
	for i in xs.size():
		if mv[i] == 0:
			continue
		var x := xs[i]
		var y := ys[i]
		var dx := txs[i] - x
		var dy := tys[i] - y
		var d2 := dx * dx + dy * dy
		if d2 <= ar[i] * ar[i]:
			mv[i] = 0
			continue
		var d := Fixed.isqrt(d2)
		var s := mini(sp[i], d)
		var nx := x + dx * s / d
		var ny := y + dy * s / d
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
			mv[i] = 0   # walled in; pathfinding (milestone 2) will route around
			continue
		xs[i] = nx
		ys[i] = ny
	units.x = xs
	units.y = ys
	units.moving = mv


## Push overlapping pairs apart. Reads positions from before any pushes this
## tick, so the result doesn't depend on which unit of a pair comes first.
func _separate() -> void:
	var n := units.count()
	var xs := units.x
	var ys := units.y
	var rs := units.radius
	var ids := units.id
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
	for i in n:
		if pushx[i] != 0 and map.walkable(xs[i] + pushx[i], ys[i]):
			xs[i] += pushx[i]
		if pushy[i] != 0 and map.walkable(xs[i], ys[i] + pushy[i]):
			ys[i] += pushy[i]
	units.x = xs
	units.y = ys


## Hash of everything that matters, in id order.
func state_hash() -> int:
	var h := Fixed.FNV_START
	for v in [tick, rng.state, next_id, units.count()]:
		h = Fixed.mix(h, v)
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
		h = Fixed.mix(h, u.hp[i])
	return h


## Id of the unit nearest (x, y) within r milli-tiles, or 0. Read-only, for views.
func pick(x: int, y: int, r: int) -> int:
	var best := 0
	var best_d2 := r * r
	for i in units.count():
		var d2 := Fixed.dist2(x, y, units.x[i], units.y[i])
		if d2 < best_d2:
			best_d2 = d2
			best = units.id[i]
	return best
