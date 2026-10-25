extends SceneTree
## The Lobster sim spike (2026-10-25): a movement-only scenario for the port in sim.lobster.
## Spawns two allied armies (nobody fights), lets them settle, then plays scripted group moves.
## Writes the state after the settle (map walk grids, terrain speeds, unit types, every unit), the
## MOVE commands as they ran, and a hash of the movement state after every tick, so the port can
## be checked tick by tick. Times World.step (the whole sim) and a movement-only step (the systems
## the port has), and checks the two give the same hashes in this scenario.
## Run: godot --headless --path . --script res://tests/lobster_spike/export.gd -- <map> <units per player> <ticks> <out file> [dump:<tick>]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")

const SEED := 20261010
const PROMPTS := ["sewer rats with cheese hammers", "angry swamp frogs with reed spears"]
const SLOTS := ["spear", "skirmisher", "archer", "large", "worker"]
const SETTLE := 40            # ticks before the export (multiple of a turn)
const ORDERS_EVERY := 20      # turns between orders (4 s)
const CHUNK := 10             # units per spawn point


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0]
	var per_player := int(args[1])
	var ticks := int(args[2])
	var out_path: String = args[3]
	var dump_tick := -1
	for a in args.slice(4):
		if a.begins_with("dump:"):
			dump_tick = int(a.substr(5))
		if a.begins_with("trace:"):
			trace_tick = int(a.substr(6))
	var rules = DataLib.load_json("res://data/rules/default.json")
	rules.animals = false
	rules.economy.start.buildings = []
	rules.economy.start.workers = 0
	var gen = Generator.new(DataLib.new())
	var races := []
	for p in PROMPTS:
		races.append(gen.generate(p, rules))

	var full := _setup(map_id, races, rules, per_player)
	var move := _setup(map_id, races, rules, per_player)
	var script := _orders(full, ticks)

	var lines := PackedStringArray()
	_write_state(full, lines)
	var full_hashes := PackedInt64Array()
	var t_full := _play(full, script, ticks, false, full_hashes, -1, null)
	var move_hashes := PackedInt64Array()
	var dump := PackedStringArray()
	var t_move := _play(move, script, ticks, true, move_hashes, dump_tick, dump)
	var cmds := full.history.filter(func(c): return c.type == Commands.MOVE)
	lines.append("CMDS %d" % cmds.size())
	for c in cmds:
		var row := PackedStringArray([str((c.turn + Commands.DELAY) * Commands.TICKS_PER_TURN), str(c.player), str(c.args.x), str(c.args.y), str(c.args.ids.size())])
		for uid in c.args.ids:
			row.append(str(uid))
		lines.append(" ".join(row))
	lines.append("HASHES %d" % ticks)
	for h in full_hashes:
		lines.append(str(h))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	if dump_tick >= 0:
		var d := FileAccess.open(out_path + ".dump", FileAccess.WRITE)
		d.store_string("\n".join(dump) + "\n")
		d.close()

	var same := full_hashes == move_hashes
	var first_diff := -1
	for k in ticks:
		if full_hashes[k] != move_hashes[k]:
			first_diff = k
			break
	print("map %s, %d units, %d ticks, %d moves" % [map_id, full.units.count(), ticks, cmds.size()])
	print("whole step:    %.3f ms a tick" % (t_full / 1000.0 / ticks))
	print("movement step: %.3f ms a tick" % (t_move / 1000.0 / ticks))
	print("movement step gives the whole step's hashes: %s%s" % [same, "" if same else " (first diff at tick index %d)" % first_diff])
	quit(0 if same else 1)


## A World with both armies spawned in chunks round their starts, allied, settled for SETTLE ticks.
func _setup(map_id: String, races: Array, rules: Dictionary, per_player: int) -> World:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules, [0, 0])
	var per_slot := per_player / SLOTS.size()
	for p in races.size():
		var s: Array = w.map.starts[p]
		var k := 0
		for slot in SLOTS:
			assert(w.type_of(p, slot) >= 0, "No %s for player %d" % [slot, p])
			var left := per_slot
			while left > 0:
				var n := mini(CHUNK, left)
				var at := _spiral(w.map, s, k)
				w.issue(p, Commands.SPAWN, {"slot": slot, "count": n, "x": at.x, "y": at.y})
				left -= n
				k += 1
	while w.tick < SETTLE:
		w.step()
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		assert(not t.hero and not t.healer and t.unpack == 0 and t.wade == 0, "The spike's units are plain walkers")
	assert(w.field_order.is_empty() and w.field_queue.is_empty())
	return w


## The k-th spawn point round a start: a square spiral, three tiles apart, on walkable ground.
func _spiral(map: SimMap, s: Array, k: int) -> Vector2i:
	var x := 0
	var y := 0
	var dx := 1
	var dy := 0
	var leg := 1
	var walked := 0
	var turns := 0
	for _n in k:
		x += dx
		y += dy
		walked += 1
		if walked == leg:
			walked = 0
			var t := dx
			dx = -dy
			dy = t
			turns += 1
			if turns % 2 == 0:
				leg += 1
	var px := clampi(int(s[0]) + x * 3000, 500, map.width * 1000 - 500)
	var py := clampi(int(s[1]) + y * 3000, 500, map.height * 1000 - 500)
	return Vector2i(px, py)


## The scripted moves (test_sim's pattern): every ORDERS_EVERY turns each player sends its whole
## army or a quarter of it to a random walkable point. [[turn, player, ids, x, y]]
func _orders(w: World, ticks: int) -> Array:
	var rng = Rng.new(SEED ^ 0x5C51)
	var out := []
	var first_turn := SETTLE / Commands.TICKS_PER_TURN
	var last_turn := (SETTLE + ticks) / Commands.TICKS_PER_TURN - Commands.DELAY
	for turn in range(first_turn, last_turn, ORDERS_EVERY):
		for p in 2:
			var ids := []
			var mode: int = rng.range_int(0, 3)
			for i in w.units.count():
				var uid := w.units.id[i]
				if w.units.owner[i] == p and (mode == 0 or uid % 4 == mode):
					ids.append(uid)
			var target := _walkable_point(w.map, rng)
			out.append([turn, p, ids, target.x, target.y])
	return out


func _walkable_point(map: SimMap, rng) -> Vector2i:
	while true:
		var x: int = rng.range_int(1000, map.width * 1000 - 1000)
		var y: int = rng.range_int(1000, map.height * 1000 - 1000)
		if map.walkable(x, y):
			return Vector2i(x, y)
	return Vector2i.ZERO


## Plays `ticks` ticks issuing the script, a hash after each; returns the time spent stepping (usec).
func _play(w: World, script: Array, ticks: int, movement_only: bool, hashes: PackedInt64Array, dump_tick: int, dump) -> int:
	var next := 0
	var spent := 0
	for k in ticks:
		while next < script.size() and script[next][0] == w.turn() and w.tick % Commands.TICKS_PER_TURN == 0:
			var o: Array = script[next]
			w.issue(o[1], Commands.MOVE, {"ids": o[2], "x": o[3], "y": o[4]})
			next += 1
		var t0 := Time.get_ticks_usec()
		if movement_only:
			_movement_step(w)
		else:
			w.step()
		spent += Time.get_ticks_usec() - t0
		hashes.append(_hash(w))
		if w.tick == dump_tick:
			_dump(w, dump)
	return spent


## World.step cut down to what this scenario uses: commands, flow-field solves, moves, separation.
func _movement_step(w: World) -> void:
	w.units.save_prev()
	if w.tick % Commands.TICKS_PER_TURN == 0:
		for cmd in w.commands.take(w.turn()):
			w._run(cmd)
			w.history.append(cmd)
	w.spatial.build(w.units.x, w.units.y)
	w._solve_queued()
	var t := w.tick
	w._move()
	_trace(w, t, "move")
	w.spatial.build(w.units.x, w.units.y)
	w._separate()
	_trace(w, t, "separate")
	w.tick += 1


var trace_tick := -1


## With trace:<tick>: every unit's position after the tick's moves and after separation.
func _trace(w: World, t: int, what: String) -> void:
	if t != trace_tick:
		return
	var rows := PackedStringArray()
	for i in w.units.count():
		rows.append("%s %d %d %d %d %d %d" % [what, w.units.id[i], w.units.x[i], w.units.y[i], w.units.wx[i], w.units.wy[i], w.units.moving[i]])
	print("\n".join(rows))


## The movement state: the tick, the next group, the cached and queued fields, every unit's movement fields.
static func _hash(w: World) -> int:
	var h := Fixed.FNV_START
	h = Fixed.mix(h, w.tick)
	h = Fixed.mix(h, w.next_group)
	for key in w.field_order:
		h = Fixed.mix(h, key)
	h = Fixed.mix(h, -1)
	for key in w.field_queue:
		h = Fixed.mix(h, key)
	var u := w.units
	for i in u.count():
		for v in [u.id[i], u.x[i], u.y[i], u.tx[i], u.ty[i], u.moving[i], u.arrive[i], u.wx[i], u.wy[i],
				u.group[i], u.stuck[i], u.prog[i], u.fkey[i], u.pace[i]]:
			h = Fixed.mix(h, v)
	return h


static func _dump(w: World, out: PackedStringArray) -> void:
	out.append("tick %d next_group %d fields %s queue %s" % [w.tick, w.next_group, str(w.field_order), str(w.field_queue)])
	var u := w.units
	for i in u.count():
		out.append("%d %d %d %d %d %d %d %d %d %d %d %d %d %d" % [u.id[i], u.x[i], u.y[i], u.tx[i], u.ty[i], u.moving[i],
			u.arrive[i], u.wx[i], u.wy[i], u.group[i], u.stuck[i], u.prog[i], u.fkey[i], u.pace[i]])


## The map's walk grids and terrain speeds, the players' lanes, the unit types, every unit.
static func _write_state(w: World, lines: PackedStringArray) -> void:
	var m := w.map
	var n := m.width * m.height
	lines.append("AOWSPIKE 1")
	lines.append("MAP %d %d %d" % [m.width, m.height, m.walks.size()])
	for k in m.walks.size():
		var row := PackedStringArray()
		for c in n:
			row.append(str(m.walks[k][c]))
		lines.append(" ".join(row))
	lines.append("SPEED %d" % w.move_pct.size())
	for cls in w.move_pct.size():
		var row := PackedStringArray()
		for c in n:
			row.append(str(w.move_pct[cls][m.terrain[c]]))
		lines.append(" ".join(row))
	lines.append("PLAYERS %d %s" % [w.races.size(), " ".join(Array(w.lane_base).slice(0, w.races.size()).map(func(v): return str(v)))])
	lines.append("TYPES %d" % w.types.size())
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		lines.append("%d %d %d %d" % [t.speed, t.radius, _role(t), int(t.form_gap)])
	lines.append("TICK %d %d %d" % [w.tick, w.next_id, w.next_group])
	var u := w.units
	lines.append("UNITS %d" % u.count())
	for i in u.count():
		assert(u.pace[i] == 0 and u.reach[i] == 0 and u.task[i] == 0 and u.foe[i] == 0 and u.perch[i] == 0 and u.orders[i].is_empty())
		lines.append("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d" % [u.id[i], u.owner[i], u.kind[i], u.x[i], u.y[i],
			u.tx[i], u.ty[i], u.moving[i], u.arrive[i], u.wx[i], u.wy[i], u.group[i], u.stuck[i], u.prog[i], u.fkey[i],
			u.speed[i], u.radius[i], u.mclass[i]])
	# (pace starts at 0 for all: nobody has moved as a group yet)


## World._form_role, by type.
static func _role(t: Dictionary) -> int:
	var tags: Array = t.eval.tags
	if t.healer or t.harmless or "machine" in tags:
		return 2
	if "mounted" in tags:
		return 3
	return 1 if t.get("ranged", false) else 0
