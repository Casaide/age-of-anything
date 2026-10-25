extends SceneTree
## The Lobster sim spike (2026-10-25): scenarios for the port in sim.lobster, from the GDScript sim.
## Two armies (rats and frogs: ground and amphibious lanes, mounted flanks, shooters) spawn round
## their starts and settle, then play scripted orders picked from the state as it goes:
##   move:  allies (nobody fights); every 4 s each sends its army or a quarter of it somewhere.
##   fight: enemies; they attack-move at each other, and every 4 s each side attack-moves at the
##          other's army, moves a quarter somewhere, or sets a quarter's stance.
## Writes the state after the settle (map, terrain speeds, sight blockers, unit types with their
## combat vectors, every unit, shots in the air, fog), the orders as they ran, and a hash of the
## state after every tick (state_hash below), so the port can be checked tick by tick. Times
## World.step and a step of just the systems the port has (movement, combat, fog), and checks the
## two give the same hashes in the scenario.
## Run: godot --headless --path . --script res://tests/lobster_spike/export.gd -- <move|fight> <map> <units per player> <ticks> <out file> [dump:<tick>] [trace:<tick>]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Combat := preload("res://src/sim/combat.gd")
const Fog := preload("res://src/sim/fog.gd")
const Shots := preload("res://src/sim/shots.gd")

const SEED := 20261010
const PROMPTS := ["sewer rats with cheese hammers", "angry swamp frogs with reed spears"]
const SLOTS := ["spear", "skirmisher", "archer", "large", "worker"]
const SETTLE := 40            # ticks before the export (multiple of a turn)
const ORDERS_EVERY := 20      # turns between orders (4 s)
const CHUNK := 10             # units per spawn point
const CMD_CODES := {Commands.MOVE: 0, Commands.ATTACK_MOVE: 1, Commands.STANCE: 2}

var mode := "move"
var trace_tick := -1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0]
	assert(mode == "move" or mode == "fight")
	var map_id: String = args[1]
	var per_player := int(args[2])
	var ticks := int(args[3])
	var out_path: String = args[4]
	var dump_tick := -1
	for a in args.slice(5):
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
	var lite := _setup(map_id, races, rules, per_player)
	var start_units := full.units.count()

	var lines := PackedStringArray()
	_write_state(full, lines)
	var full_hashes := PackedInt64Array()
	var t_full := _play(full, ticks, false, full_hashes, -1, null)
	var lite_hashes := PackedInt64Array()
	var dump := PackedStringArray()
	var t_lite := _play(lite, ticks, true, lite_hashes, dump_tick, dump)
	var cmds := full.history.filter(func(c): return CMD_CODES.has(c.type))
	lines.append("CMDS %d" % cmds.size())
	for c in cmds:
		var a: Dictionary = c.args
		var stance: int = Combat.POSTURES.find(a.stance) if c.type == Commands.STANCE else 0
		var row := PackedStringArray([str((c.turn + Commands.DELAY) * Commands.TICKS_PER_TURN), str(CMD_CODES[c.type]), str(c.player),
			str(a.get("x", 0)), str(a.get("y", 0)), str(stance), str(a.ids.size())])
		for uid in a.ids:
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

	var first_diff := -1
	for k in ticks:
		if full_hashes[k] != lite_hashes[k]:
			first_diff = k
			break
	var left := [0, 0]
	for i in full.units.count():
		left[full.units.owner[i]] += 1
	print("%s on %s, %d units, %d ticks, %d orders; left at the end: %d v %d" % [mode, map_id, start_units, ticks, cmds.size(), left[0], left[1]])
	print("whole step:   %.3f ms a tick" % (t_full / 1000.0 / ticks))
	print("ported step:  %.3f ms a tick" % (t_lite / 1000.0 / ticks))
	print("ported step gives the whole step's hashes: %s%s" % [first_diff < 0, "" if first_diff < 0 else " (first diff at tick index %d)" % first_diff])
	quit(0 if first_diff < 0 else 1)


## A World with both armies spawned in chunks round their starts, settled for SETTLE ticks.
func _setup(map_id: String, races: Array, rules: Dictionary, per_player: int) -> World:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules, [0, 0] if mode == "move" else [0, 1])
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
		assert(not t.hero and not t.healer and t.unpack == 0 and t.wade == 0 and t.min_range == 0 and t.splash == 0
			and t.pass_len == 0 and t.blast == 0 and not t.buildings_only and int(t.kill_gold) == 0 and int(t.slow_on_hit) == 0,
			"The spike's units are plain soldiers")
	assert(w.field_order.is_empty() and w.field_queue.is_empty())
	assert(w.buildings.count() == 0 and w.webs.is_empty())
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


func _walkable_point(map: SimMap, rng) -> Vector2i:
	while true:
		var x: int = rng.range_int(1000, map.width * 1000 - 1000)
		var y: int = rng.range_int(1000, map.height * 1000 - 1000)
		if map.walkable(x, y):
			return Vector2i(x, y)
	return Vector2i.ZERO


## This turn's orders for the players, picked from the state now.
func _issue_orders(w: World, rng, first: bool) -> void:
	for p in 2:
		var mine := []
		var foes := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				mine.append(w.units.id[i])
			else:
				foes.append(i)
		if mine.is_empty():
			continue
		var quarter: int = rng.range_int(0, 3)
		var some := mine.filter(func(uid): return uid % 4 == quarter)
		if mode == "move":
			var target := _walkable_point(w.map, rng)
			w.issue(p, Commands.MOVE, {"ids": mine if rng.range_int(0, 1) == 0 else some, "x": target.x, "y": target.y})
			continue
		var at := Vector2i(int(w.map.starts[1 - p][0]), int(w.map.starts[1 - p][1]))
		if not foes.is_empty():
			var sx := 0
			var sy := 0
			for j in foes:
				sx += w.units.x[j]
				sy += w.units.y[j]
			at = Vector2i(sx / foes.size(), sy / foes.size())
		if first:
			w.issue(p, Commands.ATTACK_MOVE, {"ids": mine, "x": at.x, "y": at.y})
			continue
		var r: int = rng.range_int(0, 9)
		if r <= 4:
			w.issue(p, Commands.ATTACK_MOVE, {"ids": mine if r <= 2 else some, "x": at.x, "y": at.y})
		elif r <= 6:
			var target := _walkable_point(w.map, rng)
			if not some.is_empty():
				w.issue(p, Commands.MOVE, {"ids": some, "x": target.x, "y": target.y})
		elif r <= 8:
			if not some.is_empty():
				w.issue(p, Commands.STANCE, {"ids": some, "stance": Combat.POSTURES[rng.range_int(0, 3)]})


## Plays `ticks` ticks issuing orders, a hash after each; returns the time spent stepping (usec).
func _play(w: World, ticks: int, ported_only: bool, hashes: PackedInt64Array, dump_tick: int, dump) -> int:
	var rng = Rng.new(SEED ^ 0x5C51)
	var spent := 0
	var first := true
	for k in ticks:
		if w.tick % Commands.TICKS_PER_TURN == 0 and (w.turn() - SETTLE / Commands.TICKS_PER_TURN) % ORDERS_EVERY == 0:
			_issue_orders(w, rng, first)
			first = false
		var t0 := Time.get_ticks_usec()
		if ported_only:
			_ported_step(w)
		else:
			w.step()
		spent += Time.get_ticks_usec() - t0
		hashes.append(state_hash(w))
		if w.tick == dump_tick:
			_dump(w, dump)
	return spent


## World.step cut down to the systems the port has: commands, combat, fog, flow-field solves, moves, separation.
func _ported_step(w: World) -> void:
	w.units.save_prev()
	w.events.clear()
	if w.tick % Commands.TICKS_PER_TURN == 0:
		for cmd in w.commands.take(w.turn()):
			w._run(cmd)
			w.history.append(cmd)
	w.spatial.build(w.units.x, w.units.y)
	var alive := w.units.changes
	Combat.tick(w)
	Fog.tick(w)
	if w.units.changes != alive:
		w.spatial.build(w.units.x, w.units.y)
	var t := w.tick
	_trace(w, t, "start")
	w._solve_queued()
	w._move()
	_trace(w, t, "move")
	w.spatial.build(w.units.x, w.units.y)
	w._separate()
	_trace(w, t, "separate")
	w.tick += 1


## The per-unit fields both sims hash, in order.
static func unit_fields(u, i: int) -> Array:
	return [u.id[i], u.x[i], u.y[i], u.tx[i], u.ty[i], u.moving[i], u.arrive[i], u.wx[i], u.wy[i], u.group[i], u.stuck[i],
		u.prog[i], u.fkey[i], u.pace[i], u.hp[i], u.foe[i], u.cooldown[i], u.stance[i], u.posture[i], u.gx[i], u.gy[i],
		u.amx[i], u.amy[i], u.amc[i]]


## The state the port has: the tick, the next group, the cached and queued fields, every unit, the
## shots in the air, the losses.
static func state_hash(w: World) -> int:
	var h := Fixed.FNV_START
	h = Fixed.mix(h, w.tick)
	h = Fixed.mix(h, w.next_group)
	for key in w.field_order:
		h = Fixed.mix(h, key)
	h = Fixed.mix(h, -1)
	for key in w.field_queue:
		h = Fixed.mix(h, key)
	var u := w.units
	h = Fixed.mix(h, u.count())
	for i in u.count():
		for v in unit_fields(u, i):
			h = Fixed.mix(h, v)
	h = Fixed.mix(h, w.shots.count())
	for v in w.shots.data:
		h = Fixed.mix(h, v)
	for p in w.races.size():
		h = Fixed.mix(h, w.lost[p])
	return h


## With trace:<tick>: every unit's fields at the start of the tick's moves, after them and after separation.
func _trace(w: World, t: int, what: String) -> void:
	if t != trace_tick:
		return
	var rows := PackedStringArray()
	for i in w.units.count():
		rows.append(what + " " + " ".join(unit_fields(w.units, i).map(func(v): return str(v))))
	print("\n".join(rows))


static func _dump(w: World, out: PackedStringArray) -> void:
	out.append("tick %d next_group %d fields %s queue %s shots %s lost %s" % [w.tick, w.next_group, str(w.field_order), str(w.field_queue), str(w.shots.data), str(w.lost)])
	for i in w.units.count():
		out.append(" ".join(unit_fields(w.units, i).map(func(v): return str(v))))


static func _ints(a) -> String:
	return " ".join(Array(a).map(func(v): return str(int(v))))


## The map's walk grids, terrain speeds and sight blockers, the players, the rules the port reads,
## the unit types, every unit, the shots in the air and each player's fog.
static func _write_state(w: World, lines: PackedStringArray) -> void:
	var m := w.map
	var n := m.width * m.height
	lines.append("AOWSPIKE 2")
	lines.append("MAP %d %d %d" % [m.width, m.height, m.walks.size()])
	for k in m.walks.size():
		lines.append(_ints(m.walks[k]))
	lines.append("SPEED %d" % w.move_pct.size())
	for cls in w.move_pct.size():
		var row := PackedInt32Array()
		for c in n:
			row.append(w.move_pct[cls][m.terrain[c]])
		lines.append(_ints(row))
	lines.append("SIGHT")
	lines.append(_ints(m.opaque))
	lines.append(_ints(m.level))
	lines.append("PLAYERS %d" % w.races.size())
	lines.append(_ints(Array(w.lane_base).slice(0, w.races.size())))
	lines.append(_ints(Array(w.teams).slice(0, w.races.size())))
	var c: Dictionary = w.combat
	lines.append("RULES %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d" % [c.min_damage, c.acquire_every, c.defend_sight, c.counter_pull,
		c.leash, c.sight, c.shot_lead_pct, c.shot_strays, c.shot_slack, int(w.high.reach), int(w.high.uphill_damage_pct), int(w.high.sight_unit), int(w.map.has_heights),
		w.fog_cfg.every, w.fog_cfg.unit, w.fog_cfg.worker])
	lines.append("TYPES %d %d" % [w.types.size(), w.classes.size()])
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		lines.append("%d %d %d %d %d %d %d %d %d %d %d %d %d %d" % [t.speed, t.radius, _role(t), int(t.form_gap), int(t.worker),
			int(t.get("harmless", false)), int(t.healer), int(t.ranged), t.reach, t.reload, t.shot_speed, int(t.get("min_damage", 0)),
			int(t.eval.get("sight", 0)) + int(t.sight_add), int(t.mclass)])
		lines.append(_ints(t.atk))
		lines.append(_ints(t.arm))
		lines.append(_ints(t.cls))
		lines.append("%d %s" % [t.counters.size(), _ints(t.counters)])
	lines.append("TICK %d %d %d" % [w.tick, w.next_id, w.next_group])
	var u := w.units
	lines.append("UNITS %d" % u.count())
	for i in u.count():
		assert(u.reach[i] == 0 and u.task[i] == 0 and u.perch[i] == 0 and u.patient[i] == 0 and u.orders[i].is_empty())
		lines.append(_ints(unit_fields(u, i) + [u.owner[i], u.kind[i], u.speed[i], u.radius[i], u.mclass[i]]))
	lines.append("SHOTS %d" % w.shots.count())
	lines.append(_ints(w.shots.data))
	lines.append("LOST %s" % _ints(Array(w.lost).slice(0, w.races.size())))
	lines.append("FOG")
	for p in w.races.size():
		lines.append(_ints(w.fog[p]))


## World._form_role, by type.
static func _role(t: Dictionary) -> int:
	var tags: Array = t.eval.tags
	if t.healer or t.harmless or "machine" in tags:
		return 2
	if "mounted" in tags:
		return 3
	return 1 if t.get("ranged", false) else 0
