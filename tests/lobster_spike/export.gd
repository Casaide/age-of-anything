extends SceneTree
## The Lobster sim spike (2026-10-25): scenarios for the port in sim.lobster, from the GDScript sim.
## Two races (rats and frogs: ground and amphibious lanes, mounted flanks, shooters):
##   move:  allied armies spawn round their starts and settle; every 4 s each sends its army or a
##          quarter of it somewhere (nobody fights).
##   fight: enemy armies; they attack-move at each other, and every 4 s each side attack-moves at
##          the other's army, moves a quarter somewhere, or sets a quarter's stance.
##   eco:   the match start (Town Centers, workers) played by two eco bots (src/ai/eco_bot.gd):
##          gathering, carrying, training, rallies, houses, farms, a barracks. Animals off.
## Writes the state at the start (map with its terrain tables and resources, sight blockers, rules,
## unit and building types, every unit and building, stocks, shots in the air, fog), the orders
## as they ran, and a hash of the state after every tick (state_hash below), so the port can be
## checked tick by tick. Times World.step and a step of just the systems the port has, and checks
## the two give the same hashes in the scenario.
## Run: godot --headless --path . --script res://tests/lobster_spike/export.gd -- <move|fight|eco> <map> <units per player (move, fight)> <ticks> <out file> [dump:<tick>] [trace:<tick>]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Rng := preload("res://src/rng.gd")
const Fixed := preload("res://src/sim/fixed.gd")
const Commands := preload("res://src/sim/commands.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Combat := preload("res://src/sim/combat.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Fog := preload("res://src/sim/fog.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const Heal := preload("res://src/sim/heal.gd")
const Heroes := preload("res://src/sim/heroes.gd")
const Match := preload("res://src/sim/match.gd")
const Bot := preload("res://src/ai/bot.gd")

const SEED := 20261010
const PROMPTS := ["sewer rats with cheese hammers", "angry swamp frogs with reed spears"]
const SLOTS := ["spear", "skirmisher", "archer", "large", "worker"]
const SETTLE := 40            # ticks before the export (multiple of a turn), move and fight
const ORDERS_EVERY := 20      # turns between orders (4 s)
const CHUNK := 10             # units per spawn point
const CMD_CODES := {Commands.MOVE: 0, Commands.ATTACK_MOVE: 1, Commands.STANCE: 2, Commands.GATHER: 3, Commands.BUILD: 4,
	Commands.HELP_BUILD: 5, Commands.TRAIN: 6, Commands.RALLY: 7, Commands.RESEED: 8, Commands.AGE_UP: 9, Commands.RESEARCH: 10,
	Commands.CALL_TO_ARMS: 11, Commands.BACK_TO_WORK: 12, Commands.ATTACK: 13}

var mode := "move"
var trace_tick := -1
var think_usec := 0   # the bots' thinking, both runs


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0]
	assert(mode in ["move", "fight", "eco", "match"])
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
	if mode == "move" or mode == "fight":
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
	var missing := {}
	for c in full.history:
		if not CMD_CODES.has(c.type):
			missing[c.type] = int(missing.get(c.type, 0)) + 1
	if not missing.is_empty():
		print("the port has no command for: %s (first at tick %d)" % [str(missing), (full.history.filter(func(c): return not CMD_CODES.has(c.type))[0].turn + Commands.DELAY) * Commands.TICKS_PER_TURN])
		quit(2)
		return
	lines.append("CMDS %d" % full.history.size())
	for c in full.history:
		lines.append(_cmd_row(full, c))
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
	print("%s on %s, %d units, %d ticks, %d orders; at the end: units %d v %d, buildings %d, gathered %s" % [mode, map_id, start_units, ticks,
		full.history.size(), left[0], left[1], full.buildings.count(), str(full.gathered)])
	print("whole step:   %.3f ms a tick" % (t_full / 1000.0 / ticks))
	print("bots thinking: %.3f ms a tick" % (think_usec / 2000.0 / ticks))
	print("ported step:  %.3f ms a tick" % (t_lite / 1000.0 / ticks))
	print("ported step gives the whole step's hashes: %s%s" % [first_diff < 0, "" if first_diff < 0 else " (first diff at tick index %d)" % first_diff])
	quit(0 if first_diff < 0 else 1)


## One command as it ran: run tick, code, player, four args, ids. The static checks (types, what a
## building trains, what the race lacks) are worked out here; the port checks the rest as it runs.
func _cmd_row(w: World, c: Dictionary) -> String:
	var a: Dictionary = c.args
	var p: int = c.player
	var v := [0, 0, 0, 0]
	match c.type:
		Commands.MOVE, Commands.ATTACK_MOVE:
			v = [a.x, a.y, 0, 0]
		Commands.STANCE:
			v = [Combat.POSTURES.find(a.stance), 0, 0, 0]
		Commands.GATHER:
			v = [a.cell, 0, 0, 0]
		Commands.BUILD:
			assert(int(a.get("queue", 0)) == 0 and int(a.get("along", 0)) == 0)
			var k := Economy.btype_of(w, a.building)
			v = [Economy.upgraded(w, p, k) if k >= 0 else -1, a.cx, a.cy, 0]
		Commands.HELP_BUILD:
			v = [a.target, 0, 0, 0]
		Commands.TRAIN:
			v = [a.building, w.type_for(p, a), 0 if Economy.lacks(w, p, a.slot) else 1, 0]
		Commands.RALLY:
			v = [a.building, a.x, a.y, 0]
		Commands.RESEED:
			v = [a.building, 0, 0, 0]
		Commands.AGE_UP:
			v = [a.building, 0, 0, 0]
		Commands.RESEARCH:
			v = [a.building, Tech.research_index(w, a.id), 0, 0]
		Commands.CALL_TO_ARMS:
			v = [a.building, 0, 0, 0]
		Commands.BACK_TO_WORK:
			v = [0, 0, 0, 0]
		Commands.ATTACK:
			v = [a.target, 0, 0, 0]
	var ids: Array = a.get("ids", [])
	return _ints([(c.turn + Commands.DELAY) * Commands.TICKS_PER_TURN, CMD_CODES[c.type], p] + v + [ids.size()] + ids)


## move and fight: both armies spawned in chunks round their starts, settled for SETTLE ticks.
## eco: the match start as made.
func _setup(map_id: String, races: Array, rules: Dictionary, per_player: int) -> World:
	if mode == "eco" or mode == "match":
		var e := World.new(SEED, SimMap.load_id(map_id), races, rules)
		e.set_meta("mode", mode)
		_check(e)
		return e
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules, [0, 0] if mode == "move" else [0, 1])
	w.set_meta("mode", mode)
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
	w.history.clear()   # (the spawns: done before the export)
	assert(w.buildings.count() == 0)
	_check(w)
	return w


## What the port leaves out isn't there.
func _check(w: World) -> void:
	for i in w.units.count():
		var t: Dictionary = w.types[w.units.kind[i]]
		assert(not t.hero and not t.healer and t.unpack == 0 and t.wade == 0 and t.min_range == 0 and t.splash == 0
			and t.pass_len == 0 and t.blast == 0 and not t.buildings_only and int(t.kill_gold) == 0 and int(t.slow_on_hit) == 0,
			"The spike's units are plain soldiers and workers")
	assert(w.field_order.is_empty() and w.field_queue.is_empty())
	assert(w.webs.is_empty() and w.map.lane_teams.size() == 1 and w.bridge_id.is_empty())


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


## This turn's orders for the players (move and fight), picked from the state now.
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


## Plays `ticks` ticks giving orders, a hash after each; returns the time spent stepping (usec).
func _play(w: World, ticks: int, ported_only: bool, hashes: PackedInt64Array, dump_tick: int, dump) -> int:
	var rng = Rng.new(SEED ^ 0x5C51)
	var bots := [EcoBot.new(0), EcoBot.new(1)] if mode == "eco" else [Bot.new(0, Bot.load_config()), Bot.new(1, Bot.load_config())] if mode == "match" else []
	var start := w.tick
	var spent := 0
	var first := true
	for k in ticks:
		if not bots.is_empty():
			var b0 := Time.get_ticks_usec()
			for bot in bots:
				bot.think(w)
			think_usec += Time.get_ticks_usec() - b0
		elif w.tick % Commands.TICKS_PER_TURN == 0 and (w.turn() - start / Commands.TICKS_PER_TURN) % ORDERS_EVERY == 0:
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


## World.step cut down to the systems the port has: commands, training, jobs, combat, fog, map
## changes, flow-field solves, moves, separation.
func _ported_step(w: World) -> void:
	w.units.save_prev()
	w.events.clear()
	if w.tick % Commands.TICKS_PER_TURN == 0:
		for cmd in w.commands.take(w.turn()):
			w._run(cmd)
			w.history.append(cmd)
	Economy.train(w)
	Tech.tick(w)
	Economy.work(w)
	Garrison.tick(w)
	w.spatial.build(w.units.x, w.units.y)
	var alive := w.units.changes
	Heal.tick(w)
	Combat.tick(w)
	Heroes.tick(w)
	Match.tick(w)
	Fog.tick(w)
	if w.units.changes != alive:
		w.spatial.build(w.units.x, w.units.y)
	w._next_orders()
	var t := w.tick
	_trace(w, t, "start")
	w._sync_map()
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
		u.amx[i], u.amy[i], u.amc[i], u.task[i], u.target[i], u.home[i], u.gspot[i], u.carry_kind[i], u.carry[i], u.work[i],
		u.reach[i], u.rx0[i], u.ry0[i], u.rx1[i], u.ry1[i], u.patient[i]]


## The per-building fields both sims hash, in order (then its queue).
static func building_fields(b, i: int) -> Array:
	return [b.id[i], b.owner[i], b.kind[i], b.cx[i], b.cy[i], b.sx[i], b.sy[i], b.hp[i], b.progress[i], b.done[i],
		b.train[i], b.rally_x[i], b.rally_y[i], b.cooldown[i]]


## The state the port has: the tick and counters, the cached and queued fields, every unit and
## building, the shots in the air, stocks, pop, losses, and what's left of every resource.
static func state_hash(w: World) -> int:
	var h := Fixed.FNV_START
	for v in [w.tick, w.next_id, w.next_group]:
		h = Fixed.mix(h, v)
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
	var b := w.buildings
	h = Fixed.mix(h, b.count())
	for i in b.count():
		for v in building_fields(b, i):
			h = Fixed.mix(h, v)
		h = Fixed.mix(h, b.queue[i].size())
		for k in b.queue[i]:
			h = Fixed.mix(h, k)
		h = Fixed.mix(h, b.inside[i].size())
		for rec in b.inside[i]:
			for v in rec:
				h = Fixed.mix(h, v)
	for k in w.hero_types:
		h = Fixed.mix(Fixed.mix(h, w.hero_id[k]), w.hero_fell[k])
	h = Fixed.mix(h, w.winner)
	h = Fixed.mix(h, w.shots.count())
	for v in w.shots.data:
		h = Fixed.mix(h, v)
	for p in w.races.size():
		h = Fixed.mix(h, w.lost[p])
		h = Fixed.mix(h, w.pop[p])
		h = Fixed.mix(h, w.pop_cap[p])
		h = Fixed.mix(h, w.ages[p])
		h = Fixed.mix(h, w.defeated[p])
		for v in w.researched[p]:
			h = Fixed.mix(h, v)
		for r in w.resources.size():
			h = Fixed.mix(h, w.stock[r][p])
			h = Fixed.mix(h, w.gathered[r][p])
	for c in w.map.resource_cells:
		h = Fixed.mix(h, w.map.amount[c])
		h = Fixed.mix(h, w.map.terrain[c])
	return h


## With trace:<tick>: every unit's fields at the start of the tick's moves, after them and after separation.
func _trace(w: World, t: int, what: String) -> void:
	if t != trace_tick:
		return
	var rows := PackedStringArray()
	for i in w.units.count():
		rows.append(what + " " + _ints(unit_fields(w.units, i)))
	print("\n".join(rows))


static func _dump(w: World, out: PackedStringArray) -> void:
	out.append("tick %d next_id %d next_group %d fields %s queue %s shots %s lost %s stock %s gathered %s pop %s cap %s" % [w.tick,
		w.next_id, w.next_group, str(w.field_order), str(w.field_queue), str(w.shots.data), str(w.lost), str(w.stock), str(w.gathered),
		str(w.pop), str(w.pop_cap)])
	for i in w.units.count():
		out.append(_ints(unit_fields(w.units, i)))
	for i in w.buildings.count():
		out.append("b " + _ints(building_fields(w.buildings, i)) + " q " + _ints(w.buildings.queue[i]))
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		out.append("type %d %s" % [k, _ints([t.hp, t.speed, t.reach, t.reload, t.pop, t.train_ticks, t.carry_add, t.build_pct, t.shot_speed, int(t.ranged), t.sight_add]
			+ Array(t.cost) + Array(t.atk) + Array(t.arm))])
	var left := PackedStringArray()
	for c in w.map.resource_cells:
		left.append("%d:%d/%d" % [c, w.map.amount[c], w.map.terrain[c]])
	out.append("left " + " ".join(left))


static func _ints(a) -> String:
	return " ".join(Array(a).map(func(v): return str(int(v))))


## The map (walk grids, terrain and its tables, resources, buildings' cells, sight blockers), the
## players, the rules the port reads, the unit and building types, every unit and building, the
## shots in the air and each player's fog.
static func _write_state(w: World, lines: PackedStringArray) -> void:
	var m := w.map
	var n := m.width * m.height
	lines.append("AOWSPIKE 3")
	lines.append("MODE " + (w.get_meta("mode") if w.has_meta("mode") else "eco"))
	lines.append("MAP %d %d %d %d" % [m.width, m.height, m.walks.size(), int(m.has_heights)])
	for k in m.walks.size():
		lines.append(_ints(m.walks[k]))
	for g in [m.terrain, m.amount, m.pool, m.occupied, m.walk_over, m.cliff, m.ramp, m.level, m.deck, m.high, m.opaque, m.gate]:
		lines.append(_ints(g))
	lines.append(_ints([m.resource_cells.size()] + Array(m.resource_cells)))
	lines.append("TERRAIN %d" % m.terrain_ids.size())
	for t in m.terrain_ids.size():
		lines.append(_ints([int(m.terrain_walk[t]), m.terrain_move[t], Economy.kind_of(w, m.terrain_resource[t]), m.terrain_amount[t],
			m.terrain_depleted[t], m.terrain_reseed[t], m.terrain_cleared[t], int(m.terrain_opaque[t])]))
	lines.append("SPEED %d" % w.move_pct.size())
	for cls in w.move_pct.size():
		var row := PackedInt32Array()
		for c in n:
			row.append(w.move_pct[cls][m.terrain[c]])
		lines.append(_ints(row))
	var np := w.races.size()
	lines.append("PLAYERS %d %d" % [np, w.resources.size()])
	lines.append(_ints(Array(w.lane_base).slice(0, np)))
	lines.append(_ints(Array(w.teams).slice(0, np)))
	lines.append(_ints(w.gather_spots))
	# Names and places the bots read: resources, terrains, the map's starts, each race's lacks.
	lines.append(" ".join(w.resources))
	lines.append(" ".join(m.terrain_ids))
	lines.append(_ints([m.starts.size()] + m.starts.reduce(func(acc, s): return acc + [int(s[0]), int(s[1])], [])))
	var slots := []
	for t in w.types:
		if not slots.has(t.slot):
			slots.append(t.slot)
	lines.append("%d %s" % [slots.size(), " ".join(slots)])
	for p in np:
		var lacked: Array = range(slots.size()).filter(func(s): return Economy.lacks(w, p, slots[s]))
		lines.append(_ints([int(Economy.lacks(w, p, "trade")), lacked.size()] + lacked))
	var c: Dictionary = w.combat
	var e: Dictionary = w.econ
	lines.append("RULES " + _ints([c.min_damage, c.acquire_every, c.defend_sight, c.counter_pull, c.leash, c.sight, c.shot_lead_pct,
		c.shot_strays, c.shot_slack, w.high.reach, w.high.uphill_damage_pct, w.high.sight_unit, w.high.sight_building,
		w.fog_cfg.every, w.fog_cfg.unit, w.fog_cfg.worker, w.fog_cfg.building, e.carry, e.queue_max, e.pop_max, w.fog_cfg.tower,
		w.garrison_cfg.heal_every, w.garrison_cfg.call_range]))
	lines.append(_ints([w.garrison_cfg.not.size()] + w.garrison_cfg.not.map(func(t): return _tag_or_none(w, t))))
	var heal_not: Array = c.get("heal_not", [])
	lines.append(_ints([c.heal_amount, c.heal_reload, c.heal_range, c.heal_sight, heal_not.size()] + heal_not.map(func(t): return _tag_or_none(w, t))))
	lines.append("TYPES %d %d" % [w.types.size(), w.classes.size()])
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		lines.append(_ints([t.speed, t.radius, _role(t), t.form_gap, int(t.worker), int(t.get("harmless", false)), int(t.healer),
			int(t.ranged), t.reach, t.reload, t.shot_speed, t.get("min_damage", 0), int(t.eval.get("sight", 0)) + int(t.sight_add),
			t.mclass, t.pop, t.train_ticks, t.hp, t.posture, int(t.carry_add), int(t.build_pct), t.player, int(t.line[0].age)]))
		lines.append("%s %d" % [t.slot, int(t.get("trader", false))])
		lines.append(_ints(t.cost))
		lines.append(_ints(t.atk))
		lines.append(_ints(t.arm))
		lines.append(_ints(t.cls))
		lines.append("%d %s" % [t.counters.size(), _ints(t.counters)])
	lines.append("BTYPES %d" % w.btypes.size())
	for k in w.btypes.size():
		var t: Dictionary = w.btypes[k]
		var tower: bool = not t.attack.is_empty() and t.arrows > 0
		var farm: bool = not t.becomes.is_empty()
		var land: int = m.terrain_ids.find(t.becomes.get("land", "")) if farm else -1
		var water: int = m.terrain_ids.find(t.becomes.get("water", "")) if farm else -1
		lines.append(_ints([t.size, t.build_ticks, t.pop, t.sight, t.age, t.more_from_age, int(t.water), int(t.line), int(tower),
			int(farm), land, water, t.workers, int(not t.pen.is_empty() or t.gate or t.ladder or t.walkway > 0 or t.blocks_flyers)]))
		lines.append(t.id)
		var at: Dictionary = t.attack
		lines.append(_ints([int(not at.is_empty()), _class(w, at.get("damage", "pierce")), int(at.get("attack", 0)), int(at.get("range", 0)),
			int(at.get("reload", 0)), t.arrows, t.garrison, int(t.gate), int(t.line), int(t.get("sees_over_trees", false))]))
		lines.append(_ints(t.cost))
		lines.append(_ints(t.drop))
		lines.append(_ints(t.reseed))
		for p in np:
			var mods: Dictionary = w.bmods[p][k]
			var trains := []
			for slot in t.trains:
				var tk := w.type_of(p, slot)
				if tk >= 0:
					trains.append(tk)
			lines.append(_ints([mods.hp, int(mods.add.get("pop", 0)), int(mods.add.get("sight", 0)), Economy.farm_food(w, p, k),
				int(Economy.lacks(w, p, t.id)), trains.size()] + trains))
			lines.append(_ints(Economy.bcost(w, p, k)))
	_write_tech(w, lines)
	lines.append("ECON")
	for p in np:
		var row := [w.ages[p], w.auto_reseed[p], w.pop[p], w.pop_cap[p], w.lost[p]]
		for r in w.resources.size():
			row += [w.stock[r][p], w.gathered[r][p], w.gather_ticks[p][r]]
		lines.append(_ints(row))
	lines.append("TICK %d %d %d" % [w.tick, w.next_id, w.next_group])
	var u := w.units
	lines.append("UNITS %d" % u.count())
	for i in u.count():
		assert(u.perch[i] == 0 and u.patient[i] == 0 and u.orders[i].is_empty())
		lines.append(_ints(unit_fields(u, i) + [u.owner[i], u.kind[i], u.speed[i], u.radius[i], u.mclass[i]]))
	var b := w.buildings
	lines.append("BUILDINGS %d" % b.count())
	for i in b.count():
		assert(b.diag[i] == 0 and b.inside[i].is_empty() and b.cooldown[i] == 0)
		lines.append(_ints(building_fields(b, i) + [b.queue[i].size()] + b.queue[i]))
	lines.append("SHOTS %d" % w.shots.count())
	lines.append(_ints(w.shots.data))
	lines.append("FOG")
	for p in np:
		lines.append(_ints(w.fog[p]))
		lines.append(_ints([w.fog_lit[p].size()] + Array(w.fog_lit[p])))
		# what it remembers of enemy buildings (fog_seen, in its order): id, kind owner cx cy sx done progress age sy diag
		var seen: Dictionary = w.fog_seen[p]
		lines.append(str(seen.size()))
		for id in seen:
			lines.append(_ints([id] + Array(seen[id])))
	_write_ai(lines)


## Ages and research (tech.gd) as data for the port: the ages (cost, time, where, what they need per
## player), every research item (its static checks per player worked out here: open to the race,
## a line with new kit that age, the line upgrade before it) with its effects, each race's own
## effects, the buildings' base numbers research works on, and every unit type's line: per age its
## eval, which Tech.retype and World.set_type turn into the type's numbers.
const EVAL_ADD := ["attack", "hp", "range", "speed"]


static func _class(w: World, tag: String) -> int:
	var k: int = w.classes.find(tag)
	return k if k >= 0 else w.classes.size() - 1   # (GDScript: find's -1 indexes the last class)


static func _tag_or_none(w: World, tag: String) -> int:
	return -1 if tag == "all" else w.classes.find(tag) if w.classes.has(tag) else -2


## One effect: kind, stat, value, tag (-1 all, -2 no such tag), and tags, not tags, buildings (-1 all).
static func _effect(w: World, fx: Dictionary) -> Array:
	var kind := -1
	var stat := 0
	var value := int(fx.get("add", fx.get("pct", 0)))
	if fx.has("becomes"):
		return [8, Economy.btype_of(w, fx.building), Economy.btype_of(w, fx.becomes), -2, 0, 0, 0]
	if fx.has("gather"):
		kind = 7
		stat = w.resources.find(fx.gather)
	elif fx.has("start"):
		return [9, 0, 0, -2, 0, 0, 0]
	elif fx.has("tag"):
		if fx.has("pct"):
			kind = 4
			stat = Tech.UNIT_PCT.find(fx.stat)
		elif fx.stat in Tech.UNIT_EXTRA:
			kind = 3
			stat = Tech.UNIT_EXTRA.find(fx.stat)
		elif fx.stat.begins_with("armour."):
			kind = 1
			stat = _class(w, fx.stat.substr(7))
		elif fx.stat.begins_with("bonus."):
			kind = 2
			stat = _class(w, fx.stat.substr(6))
		else:
			kind = 0
			stat = EVAL_ADD.find(fx.stat)
		assert(stat >= 0, "Unknown unit stat %s" % fx.stat)
	else:
		kind = 5 if fx.has("add") else 6
		stat = (Tech.BUILDING_ADD if fx.has("add") else Tech.BUILDING_PCT).find(fx.stat)
		assert(stat >= 0, "Unknown building stat %s" % fx.stat)
	var ands: Array = fx.get("and", []).map(func(t): return _tag_or_none(w, t))
	var nots: Array = fx.get("not", []).map(func(t): return _tag_or_none(w, t))
	var blds := []
	if fx.has("building"):
		var ids: Array = fx.building if fx.building is Array else [fx.building]
		blds = [-1] if ids.has("all") else ids.map(func(id): return Economy.btype_of(w, id))
	return [kind, stat, value, _tag_or_none(w, fx.get("tag", "all")) if fx.has("tag") else -2, ands.size()] + ands + [nots.size()] + nots + [blds.size()] + blds


static func _write_tech(w: World, lines: PackedStringArray) -> void:
	var np := w.races.size()
	var c: Dictionary = w.combat
	lines.append("TECH %d %d" % [w.tech.ages.size(), w.tech.research.size()])
	lines.append(_ints([c.melee_reach, c.melee_reload, c.ranged_reload, c.shot_speed, _tag_or_none(w, "machine"), _tag_or_none(w, "mounted")]))
	var speeds := PackedInt32Array()
	speeds.resize(w.classes.size())
	for tag in c.shot_speeds:
		if w.classes.has(tag):
			speeds[w.classes.find(tag)] = int(c.shot_speeds[tag])
	lines.append(_ints(speeds))
	lines.append(_ints(w.resources.map(func(r): return int(w.econ.gather_ticks[r]))))
	for a in w.tech.ages:
		lines.append(_ints([a.age, Economy.btype_of(w, a.building), a.ticks] + Array(a.cost)))
		for p in np:
			var needs := Tech.requires(w, p, a).map(func(id): return Economy.btype_of(w, id))
			lines.append(_ints([needs.size()] + needs))
	for r in w.tech.research.size():
		var item: Dictionary = w.tech.research[r]
		var after: int = Tech.research_index(w, item.after) if item.after != "" else -1
		lines.append(item.id)
		lines.append(_ints([Economy.btype_of(w, item.building), item.ticks, item.age, after, int(item.get("line_age", 0))] + Array(item.cost)))
		for p in np:
			var race: Dictionary = w.races[p]
			var open: bool = (item.only.is_empty() or bool(w.rules.get("full_tech_tree", false)) or race.creature in item.only or race.family in item.only) \
				and not Tech.lacks(w, p, item.id)
			var line_has: bool = Tech._line_has(w, p, item.line, item.line_age) if item.has("line") else true
			var before: int = Tech.line_before(w, p, item) if item.has("line") else -1
			lines.append(_ints([int(open), int(line_has), before]))
		lines.append(str(item.effects.size()))
		for fx in item.effects:
			lines.append(_ints(_effect(w, fx)))
	for p in np:
		lines.append(str(w.ident[p].fx.size()))
		for fx in w.ident[p].fx:
			lines.append(_ints(_effect(w, fx)))
	for k in w.btypes.size():
		var bt: Dictionary = w.btypes[k]
		lines.append(_ints([bt.hp, bt.food] + Array(bt.arm)))
	# Every unit type's line: per step its age, its line upgrade (a research index, -1 for none),
	# and its eval: speed hp pop train_time cost.. damage-class attack bonus.. armour.. tags.. range reload
	# min_range splash pass buildings-only unpack pack blast blast_line heal sight.
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		lines.append(_ints([int(t.hero), t.line.size()]))
		for l in t.line:
			var e: Dictionary = l.eval
			var up: int = Tech.research_index(w, "line.%s.%d" % [t.slot, int(l.age)])
			var bonus := PackedInt32Array()
			bonus.resize(w.classes.size())
			for key in e.bonus:
				bonus[_class(w, key)] = int(e.bonus[key])
			var arm := PackedInt32Array()
			arm.resize(w.classes.size())
			for key in e.armour:
				arm[_class(w, key)] = int(e.armour[key])
			var tags: Array = e.tags.map(func(tag): return _class(w, tag))
			lines.append(_ints([l.age, up, e.speed, e.hp, e.pop, e.train_time] + Array(Economy.cost_vector(w.resources, e.cost))
				+ [_class(w, e.damage), e.attack] + Array(bonus) + Array(arm) + [tags.size()] + tags
				+ [e["range"], e.get("reload", 0), e.get("min_range", 0), e.get("splash", 0), e.get("pass", 0), int(e.get("targets", "") == "buildings"),
				e.get("unpack", 0), e.get("pack", 0), e.get("blast", 0), e.get("blast_line_pct", 0), e.get("heal", 0), e.get("sight", 0)]))
	lines.append("RESEARCHED")
	for p in np:
		lines.append(_ints([w.ages[p]] + Array(w.researched[p])))
	# Heroes (heroes.gd): the rules, and per hero type its state and aura effects.
	var hc: Dictionary = w.hero_cfg
	lines.append("HEROES %d" % w.hero_types.size())
	lines.append(_ints([hc.aura, hc.regen, hc.revive, hc.revive_pct]))
	for k in w.hero_types:
		lines.append(_ints([k, w.hero_id[k], w.hero_fell[k], w.types[k].aura.size()]))
		for fx in w.types[k].aura:
			lines.append(_ints(_effect(w, fx)))
	# Winning and losing (match.gd).
	lines.append("MATCH")
	lines.append(_ints([w.winner] + Array(w.started_with_town) + Array(w.defeated).slice(0, np)))


## The full bot's config (data/ai.json with its level applied, as Bot.new leaves it): numbers as
## "path value", string lists as "path n s...", the build order and waves as rows, the level's fields.
static func _write_ai(lines: PackedStringArray) -> void:
	var bot = Bot.new(0, Bot.load_config())
	var nums := PackedStringArray()
	var strs := PackedStringArray()
	var walk := func(walk_fn: Callable, v, path: String) -> void:
		if path.ends_with("note") or path.contains("_doc") or path == "build_order" or path == "military.waves" or path == "levels":
			return
		match typeof(v):
			TYPE_DICTIONARY:
				var ks: Array = v.keys()
				ks.sort()
				for k in ks:
					walk_fn.call(walk_fn, v[k], k if path == "" else path + "." + str(k))
			TYPE_ARRAY:
				strs.append("%s %d %s" % [path, v.size(), " ".join(v.map(func(s): return str(s)))])
			TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
				nums.append("%s %d" % [path, int(v)])
			TYPE_STRING:
				strs.append("%s 1 %s" % [path, v])
	walk.call(walk, bot.cfg, "")
	lines.append("AI %d %d" % [nums.size(), strs.size()])
	lines.append_array(nums)
	lines.append_array(strs)
	var order: Array = bot.cfg.build_order
	lines.append("BUILD_ORDER %d" % order.size())
	for s in order:
		lines.append("%s %s %s" % [s.building, s.get("near", "-"), _ints([s.get("age", 1), s.workers, s.get("count", -1), s.get("builders", 2), s.get("away", 0),
			s.get("own_side", 0), s.get("guard", 0), s.get("save", 0), s.get("push", -1), s.get("expand_workers", -1)])])
	var waves: Array = bot.cfg.military.waves
	lines.append("WAVES %d" % waves.size())
	for wv in waves:
		lines.append(_ints([wv.at, wv.min_army]))
	lines.append("LEVEL " + _ints([bot.army_ratio, bot.wave_pct, int(bot.build_up), bot.age3_workers, bot.towers, bot.all_in, bot.shelter_pop,
		int(bot.guard_crossing), bot.raids, bot.raid_from]))


## World._form_role, by type.
static func _role(t: Dictionary) -> int:
	var tags: Array = t.eval.tags
	if t.healer or t.harmless or "machine" in tags:
		return 2
	if "mounted" in tags:
		return 3
	return 1 if t.get("ranged", false) else 0
