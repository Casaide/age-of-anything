extends RefCounted
## The simulation. Pure data, integer maths, fixed 20 Hz ticks, driven only by
## the command stream. Views read it; nothing outside writes to it except
## through commands. Same seed + map + races + rules + commands = same hashes.
##
## One tick: commands -> training -> worker jobs -> healing -> combat (targets, chasing, hits,
## deaths) -> map changes drop stale flow fields -> solve queued fields (budgeted)
## -> move -> separate -> hash. Combat lives in combat.gd.
##
## Movement: a unit either heads for a point (MOVE: groups settle when they bump
## an arrived groupmate) or for "next to a rect" (a reed tile, a building). It
## steers at a waypoint taken from a flow field, re-planned every few ticks.
## Fields are solved from a queue within a per-tick budget; until a unit's
## field is ready it heads straight on. The economy lives in economy.gd.

const Fixed := preload("res://src/sim/fixed.gd")
const Rng := preload("res://src/rng.gd")
const Commands := preload("res://src/sim/commands.gd")
const Units := preload("res://src/sim/units.gd")
const Buildings := preload("res://src/sim/buildings.gd")
const Spatial := preload("res://src/sim/spatial.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")
const Heal := preload("res://src/sim/heal.gd")
const Tech := preload("res://src/sim/tech.gd")
const Market := preload("res://src/sim/market.gd")
const Animals := preload("res://src/sim/animals.gd")
const Match := preload("res://src/sim/match.gd")
const Fog := preload("res://src/sim/fog.gd")
const Bridges := preload("res://src/sim/bridges.gd")
const Trails := preload("res://src/sim/trails.gd")

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
const PROGRESS_EVERY := 40     # ticks between net-progress checks (staggered by unit id)
const CORRECT_MAX := 150       # milli-tiles a tick a body is eased off blocked ground (no teleports)
const RETURN_SLACK := 1000     # shoved this far beyond its settle radius, a stopped unit walks back
const FIELD_CACHE := 12        # flow fields kept per player (oldest dropped first; at least 24)
const SOLVE_BUDGET := 1500     # flow-field cells settled per tick: one full solve, or a few near ones
const NEAR_CUTOFF := 160       # cost cutoff for "near" fields (16 tiles): short work trips
# Places of their own (Dominic's playtest, 2026-10-13: a group's units pushed each other about
# at the end of a move, workers got stuck on each other, a crowd fought the pathing at a wall).
const FORM_GAP := 160          # milli-tiles between neighbouring bodies in a formation, or round a building
const SLOT_ARRIVE := 60        # a unit making for its own place (a formation slot, a spot by a building) stops this close
const SLOT_SLACK := 400        # shoved this far beyond that, a stopped unit in a formation walks back to its slot
const SPOT_GAP := 100          # a worker's chosen spot beside its rect: this gap between its body and the rect
const SPOT_BUSY := 3           # this many spot checks finding no free spot and the worker gives the place up

# Field keys: (target * 4 + kind) * LANES + lane. Cell targets are cells; building targets are ids.
# A lane is a movement class, and the team for maps with gates (SimMap lanes).
const STRAIGHT_PER_CHECK := 10 # field cost a moving unit must shed per progress check (one cell)
const FIELD_CELL := 0          # full field towards a cell (MOVE, or a far resource)
const FIELD_CELL_NEAR := 1
const FIELD_BUILDING_NEAR := 2
const FIELD_BUILDING := 3
const LANES := 32              # lane slots in a field key: 3 classes x (everyone + up to 9 teams with gates)

var seed_value: int
var tick := 0
var rng: Rng
var map: SimMap
var races: Array               # race dicts, one per player
var rules: Dictionary          # host rules, as loaded
var econ: Dictionary           # rules.economy with numbers as ints
var combat: Dictionary         # rules.combat with numbers as ints
var classes: Array = []        # armour/attack class names (see Combat.setup)
var tech: Dictionary          # ages and research (data/tech.json, see tech.gd)
var ages := PackedInt32Array()     # per player: the age it's in (1 at the start)
var researched: Array = []         # per player: PackedByteArray over tech.research
var market_price := PackedInt32Array()   # gold per lot of each resource, shared by everyone (market.gd)
var gather_ticks: Array = []       # per player: ticks per unit of each resource gathered (research cuts them)
var bmods: Array = []              # per player, per building type: research on it {add, pct, hp, arm} (Tech.refresh)
var move_pct: Array = []       # per movement class, per terrain index: speed percent (rules.movement)
var events: Array = []         # this tick's hits and deaths, for views (not state, not hashed)
var types: Array = []          # unit types, per player per roster slot (see _make_type)
var btypes: Array = []         # building types (see Economy.load_btypes)
var units: Units = Units.new()
var buildings: Buildings = Buildings.new()
var spatial: Spatial
var commands: Commands = Commands.new()
var history: Array = []        # every command that ran, in run order
var hashes: Array = []         # [[tick, hash]] every HASH_EVERY ticks
var next_id := 1               # shared by units and buildings
var gaia := -1                # the owner of wild animals: one past the last player, on a team of its own
var claim_tiles := 4          # how close a player's unit must come to claim a herd animal (animals.json)
var herd_spots := {}          # Town Center id -> [x, y]: where its claimed sheep gather with no pen to go to, chosen once (animals.gd)
var next_group := 1
var resources: Array = []      # resource ids in their fixed order (data/resources.json)
var stock: Array = []          # per resource: PackedInt32Array per player
var gathered: Array = []       # per resource, per player: everything ever dropped off
var pop := PackedInt32Array()     # derived each tick (Economy.update_pop)
var lost := PackedInt32Array()    # per player: units killed so far
var teams := PackedInt32Array()   # per player: team id (players on one team are allies)
var lane_base := PackedInt32Array()   # per player (and gaia): first lane of its team's walk grids (refresh_lanes)
var pop_cap := PackedInt32Array()
var auto_reseed := PackedByteArray()   # per player: 1 if worked-out farms reseed themselves (Commands.AUTO_RESEED)
var defeated := PackedInt32Array()       # per player: the tick + 1 they were knocked out, or 0 (match.gd)
var started_with_town := PackedByteArray()
var winner := -1               # the winning team, once only one is left
var wonder_ids := PackedInt32Array()      # standing finished Wonders, in id order (match.gd)
var wonder_since := PackedInt32Array()    # the tick each was found finished: its countdown runs from there
var wonder_owners := PackedInt32Array()   # who owns each
var fog: Array = []            # per player: PackedByteArray per cell (fog.gd); derived, not hashed
var fog_cfg: Dictionary
var fog_ground: Array = []     # per player: PackedByteArray, the terrain index per cell as they last saw it (fog.gd)
var fog_left: Array = []       # per player: PackedInt32Array, what was left per cell as they last saw it
var fog_seen: Array = []       # per player: enemy building id -> its snapshot as last seen (fog.gd)
var fog_lit: Array = []        # per player: PackedInt32Array, the cells lit at the last update (fog.gd)
var fog_watch := {}            # cell -> true: cells that held a resource or ever changed (fog.gd)
var fields := {}               # field key -> Flow; looked up by key, never iterated
var field_order: Array = []    # cached field keys, oldest first (eviction, invalidation)
var field_queue: Array = []    # field keys waiting for a solve, in request order
var bridge_cfg: Dictionary     # data/bridges.json, as vectors (bridges.gd)
var trail_cfg: Dictionary      # rules.trails as ints (trails.gd)
var wear := PackedByteArray()  # per cell: how worn the ground is by walkers (trails.gd)
var bridge_id := PackedInt32Array()   # per map bridge: its id (from next_id), and the rest of its state (bridges.gd)
var bridge_cells: Array = []          # PackedInt32Array of its deck cells
var bridge_rect: Array = []           # Rect2i in milli-tiles (inclusive end, as Economy's rects)
var bridge_hp := PackedInt32Array()
var bridge_up := PackedByteArray()    # 1 standing, 0 broken
var bridge_work := PackedInt32Array() # rebuild ticks put in
var bridge_payer := PackedInt32Array()   # the player who paid for the rebuild under way, or -1


## p_teams: a team id per player; empty means everyone for themselves (team = player).
func _init(p_seed: int, p_map: SimMap, p_races: Array, p_rules: Dictionary, p_teams := []) -> void:
	assert(p_map.version == 0, "A World needs a freshly loaded map (maps change during a match)")
	seed_value = p_seed
	rng = Rng.new(p_seed)
	map = p_map
	races = p_races
	rules = p_rules
	for p in p_races.size():
		teams.append(int(p_teams[p]) if p < p_teams.size() else p)
	gaia = p_races.size()
	teams.append(-1)   # gaia: everyone's quarry, nobody's ally
	refresh_lanes()
	econ = _ints(rules.economy)
	combat = _ints(rules.combat)
	var ts: Dictionary = rules.get("movement", {}).get("terrain_speed", {})
	for c in SimMap.CLASSES:
		var row := PackedInt32Array()
		for t in map.terrain_ids:
			row.append(int(ts.get(c, {}).get(t, 100)))
		move_pct.append(row)
	spatial = Spatial.new(map.width, map.height)
	resources = Economy.load_resources()
	btypes = Economy.load_btypes(resources)
	tech = Tech.load_tech(resources, btypes)
	for p in races.size():
		for u in races[p].units:
			types.append(_make_type(p, u))
	var animals: Dictionary = Animals.load_data()
	Animals.add_types(self, animals)
	Combat.setup(self)
	Tech.setup(self)
	Market.setup(self)
	Economy.setup(self)
	lost.append(0)   # gaia's
	if bool(rules.get("animals", false)):   # a host rule (on by default); some tests turn it off
		Animals.place(self, animals.spawn)
	Match.setup(self)
	Bridges.setup(self)
	Trails.setup(self)
	Fog.setup(self)
	map.fresh.clear()
	map.fresh_closed.clear()


static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			assert(v == floorf(v), "Rules hold a fraction: %s" % v)
			return int(v)
		TYPE_ARRAY:
			return v.map(_ints)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints(v[k])
			return out
	return v


func _make_type(player: int, u: Dictionary) -> Dictionary:
	var r: Dictionary = u.recipe
	var e: Dictionary = u.eval
	for k in ["speed", "hp", "pop", "train_time"]:
		assert(typeof(e[k]) == TYPE_INT, "Unit stat %s must be an int" % k)
	var radius: int = BASE_RADIUS * int(r.scale) / 100
	if r.has("mount"):
		radius = maxi(radius, MOUNTED_RADIUS)
	return {
		"player": player, "slot": r.slot, "name": r.get("name", r.slot), "recipe": r,
		"speed": int(e.speed) * SPEED_SCALE, "radius": mini(radius, MAX_RADIUS), "hp": int(e.hp),
		"pop": int(e.pop), "cost": Economy.cost_vector(resources, e.cost),
		"train_ticks": int(e.train_time) * TICK_HZ, "worker": "worker" in e.tags, "eval": e,
		"healer": int(e.get("heal", 0)) > 0,   # heals, never fights (heal.gd); spawns passive
		"posture": Combat.PASSIVE if int(e.get("heal", 0)) > 0 else Combat.AGGRESSIVE,
		"mclass": _movement_class(e.tags),
		"sight_add": 0, "carry_add": 0, "build_pct": 0,   # research on the type (Tech.retype)
		"line": u.get("line", [{"age": int(r.tier), "recipe": r, "eval": e}]),   # the unit through the ages (age-ups re-price from it)
	}


## Each player's walk grids: its team's own once the team has a gate (SimMap.occupy makes them).
func refresh_lanes() -> void:
	lane_base.resize(teams.size())
	for p in teams.size():
		lane_base[p] = map.lane_group(teams[p]) * SimMap.CLASSES.size()
	assert(map.walks.size() <= LANES, "Too many teams with gates for the field keys")


## The walk grid unit i moves on (its movement class, in its team's lane).
func lane(i: int) -> int:
	return lane_base[units.owner[i]] + units.mclass[i]


## Should these two fight on their own (enemies, and neither is an animal nobody owns)?
## Attacking an animal is something you choose (hunting), not something soldiers do idly.
func is_foe(a: int, b: int) -> bool:
	return a != gaia and b != gaia and is_enemy(a, b)


## Are these two players enemies (on different teams)?
func is_enemy(a: int, b: int) -> bool:
	return teams[a] != teams[b]


## Can the player pay this cost vector (indexed like `resources`)?
func can_afford(player: int, cost: PackedInt32Array) -> bool:
	for r in cost.size():
		if stock[r][player] < cost[r]:
			return false
	return true


func pay(player: int, cost: PackedInt32Array) -> void:
	for r in cost.size():
		stock[r][player] -= cost[r]


func refund(player: int, cost: PackedInt32Array) -> void:
	for r in cost.size():
		stock[r][player] += cost[r]


## What a building's queue entry cost: a unit type, or research / the age-up (Tech.entry).
func queued_cost(player: int, e: int) -> PackedInt32Array:
	return Tech.entry_cost(self, player, e)


## Replace a unit type's recipe and stats (an age-up or research; see tech.gd). Its
## version goes up, so views rebuild the unit's look.
func set_type(k: int, recipe: Dictionary, e: Dictionary) -> void:
	var t: Dictionary = types[k]
	t.recipe = recipe
	t.eval = e
	t.name = recipe.get("name", recipe.slot)
	t.speed = int(e.speed) * SPEED_SCALE
	t.hp = int(e.hp)
	t.pop = int(e.pop)
	t.cost = Economy.cost_vector(resources, e.cost)
	t.train_ticks = int(e.train_time) * TICK_HZ
	t.version = int(t.get("version", 0)) + 1
	Combat.type_vectors(self, t)


## A unit's movement class from its tags (rules.movement.classes: tag -> class, first match wins).
func _movement_class(tags: Array) -> int:
	for entry in rules.get("movement", {}).get("classes", []):
		if entry.tag in tags:
			return SimMap.CLASSES.find(entry["class"])
	return 0


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
	units.save_prev()
	events.clear()
	if tick % Commands.TICKS_PER_TURN == 0:
		for cmd in commands.take(turn()):
			_run(cmd)
			history.append(cmd)
	Economy.train(self)
	Tech.tick(self)
	Economy.work(self)
	Animals.tick(self)
	spatial.build(units.x, units.y)
	var alive := units.count()
	Heal.tick(self)
	Combat.tick(self)
	Match.tick(self)
	Fog.tick(self)
	Trails.tick(self)
	if units.count() != alive:
		spatial.build(units.x, units.y)   # the dead are gone: moves look round at who's left (World._spot)
	_next_orders()
	_sync_map()
	_solve_queued()
	_move()
	spatial.build(units.x, units.y)
	_separate()
	tick += 1
	if tick % HASH_EVERY == 0:
		hashes.append([tick, state_hash()])


func _run(cmd: Dictionary) -> void:
	var a: Dictionary = cmd.args
	if cmd.type == Commands.BUILD and int(a.get("queue", 0)) == 1:
		# Shift-placed: the foundation goes down now; building it joins each unit's queue.
		var bid := Economy.lay_foundation(self, cmd.player, a)
		if bid == 0:
			return
		cmd = {"turn": cmd.turn, "player": cmd.player, "seq": cmd.seq, "type": Commands.HELP_BUILD,
			"args": {"ids": a.ids, "target": bid, "queue": 1}}
		a = cmd.args
	if (cmd.type == Commands.MOVE or cmd.type == Commands.ATTACK_MOVE) and not a.has("sx"):
		# A group move: every unit gets its own slot in a formation now, queued or not.
		a = _formation(cmd.player, a)
		cmd = {"turn": cmd.turn, "player": cmd.player, "seq": cmd.seq, "type": cmd.type, "args": a}
	if cmd.type in Commands.QUEUEABLE:
		a = _queue_or_clear(cmd)
		if a.ids.is_empty():
			return
	match cmd.type:
		Commands.MOVE:
			for uid in a.ids:
				var i := units.index_of(uid)
				if i >= 0 and units.owner[i] == cmd.player:
					Economy.clear_task(self, i)
					Combat.clear(self, i)
					var s := slot_of(a, uid)
					order_move(i, s.x, s.y, SLOT_ARRIVE, a.group, a.fx, a.fy, a.pace)
		Commands.SPAWN:
			var k := type_of(cmd.player, a.slot)
			assert(k >= 0, "Player %d has no unit for slot %s" % [cmd.player, a.slot])
			var t: Dictionary = types[k]
			for n in a.count:
				var x: int = a.x + rng.range_int(-SPAWN_JITTER, SPAWN_JITTER)
				var y: int = a.y + rng.range_int(-SPAWN_JITTER, SPAWN_JITTER)
				var ln: int = lane_base[cmd.player] + t.mclass
				if not map.walkable(x, y, ln):
					var c := Flow.centre(map, Flow.nearest_walkable(map, map.cell_of(x, y), ln))
					x = c.x
					y = c.y
				var slot := units.add(next_id, cmd.player, k, x, y, t.speed, t.radius, t.hp)
				units.mclass[slot] = t.mclass
				units.posture[slot] = t.posture
				next_id += 1
		Commands.GATHER:
			_clear_combat(cmd.player, a.ids)
			Economy.cmd_gather(self, cmd.player, a)
		Commands.BUILD:
			_clear_combat(cmd.player, a.ids)
			Economy.cmd_build(self, cmd.player, a)
		Commands.HELP_BUILD:
			_clear_combat(cmd.player, a.ids)
			Economy.cmd_help_build(self, cmd.player, a)
		Commands.DROP_OFF:
			_clear_combat(cmd.player, a.ids)
			Economy.cmd_drop_off(self, cmd.player, a)
		Commands.ATTACK:
			Combat.cmd_attack(self, cmd.player, a)
		Commands.ATTACK_MOVE:
			Combat.cmd_attack_move(self, cmd.player, a)
		Commands.AGE_UP:
			Tech.cmd_age_up(self, cmd.player, a)
		Commands.RESEARCH:
			Tech.cmd_research(self, cmd.player, a)
		Commands.SURRENDER:
			Match.cmd_surrender(self, cmd.player)
		Commands.RESEED:
			Economy.cmd_reseed(self, cmd.player, a)
		Commands.AUTO_RESEED:
			auto_reseed[cmd.player] = 1 if int(a.on) == 1 else 0
		Commands.TRAIN:
			Economy.cmd_train(self, cmd.player, a)
		Commands.CANCEL:
			Economy.cmd_cancel(self, cmd.player, a)
		Commands.RALLY:
			Economy.cmd_rally(self, cmd.player, a)
		Commands.TRADE:
			Market.cmd_trade(self, cmd.player, a)
		Commands.STANCE:
			Combat.cmd_stance(self, cmd.player, a)
		Commands.PEN:
			Economy.Pens.cmd_pen(self, cmd.player, a)
		Commands.RELEASE:
			Economy.Pens.cmd_release(self, cmd.player, a)
		Commands.STOP:
			for uid in a.ids:
				var i := units.index_of(uid)
				if i >= 0 and units.owner[i] == cmd.player:
					Economy.clear_task(self, i)
					Combat.clear(self, i)
					units.orders[i].clear()
					units.moving[i] = 0


# ------------------------------------------------------------------ orders

## Shift-queuing. A queued order goes into each busy unit's own queue and runs now
## for idle ones; a plain order empties the queues of the units it's for. Returns the
## args for the units that act now.
func _queue_or_clear(cmd: Dictionary) -> Dictionary:
	var a: Dictionary = cmd.args
	var queued: bool = int(a.get("queue", 0)) == 1
	var now := []
	var base := a.duplicate()
	base.erase("slots")   # each queued copy keeps only its own slot
	for uid in a.ids:
		var i := units.index_of(uid)
		if i < 0 or units.owner[i] != cmd.player:
			continue
		if queued and busy(i):
			var one := base.duplicate()
			one.ids = [uid]
			one.erase("queue")
			if a.has("slots"):
				var s := slot_of(a, uid)
				one.sx = s.x
				one.sy = s.y
			units.orders[i].append({"type": cmd.type, "args": one})
		else:
			if not queued:
				units.orders[i].clear()
			now.append(uid)
	var out := a.duplicate()
	out.ids = now
	return out


## Doing something: a job, a move, or a fight.
func busy(i: int) -> bool:
	return units.task[i] != Economy.NONE or units.moving[i] == 1 or units.foe[i] != 0 or units.patient[i] != 0


## Units that have finished what they were doing take their next queued order.
## A queued BUILD whose foundation another unit already laid becomes "help build".
func _next_orders() -> void:
	for i in units.count():
		if units.orders[i].is_empty() or busy(i):
			continue
		var o: Dictionary = units.orders[i].pop_front()
		var p: int = units.owner[i]
		if o.type == Commands.BUILD:
			var bid: int = map.occupied[o.args.cy * map.width + o.args.cx]
			var b := buildings.index_of(bid)
			if b >= 0 and buildings.owner[b] == p and buildings.done[b] == 0 and btypes[buildings.kind[b]].id == o.args.building:
				o = {"type": Commands.HELP_BUILD, "args": {"ids": o.args.ids, "target": bid}}
		var args: Dictionary = o.args.duplicate()
		args.queue = 1   # run now (the unit's free) without wiping the rest of its queue
		_run({"turn": turn(), "player": p, "seq": -1, "type": o.type, "args": args})


func _clear_combat(player: int, ids: Array) -> void:
	for uid in ids:
		var i := units.index_of(uid)
		if i >= 0 and units.owner[i] == player:
			Combat.clear(self, i)


## Head for a point (snapped to walkable ground) and stop within `arrive`. A unit in a group
## move heads for its own slot but follows the field of the group's centre (fx, fy), so a
## group shares one field, at the group's pace (its slowest member's speed; 0: its own).
func order_move(i: int, x: int, y: int, arrive: int, group: int, fx := -1, fy := -1, pace := 0) -> void:
	var ln := lane(i)
	var p := _snap(x, y, ln)
	var cell := map.cell_of(p.x, p.y)
	if fx >= 0:
		var c := _snap(fx, fy, ln)
		cell = map.cell_of(c.x, c.y)
	units.tx[i] = p.x
	units.ty[i] = p.y
	units.reach[i] = 0
	units.fkey[i] = cell_field(cell, false, ln)
	units.arrive[i] = arrive
	units.group[i] = group
	units.pace[i] = pace
	_start(i)


## The point clamped to the map, or the centre of the nearest walkable cell in this lane.
func _snap(x: int, y: int, ln: int) -> Vector2i:
	x = clampi(x, 0, map.width * SimMap.TILE - 1)
	y = clampi(y, 0, map.height * SimMap.TILE - 1)
	var cell := map.cell_of(x, y)
	if map.walks[ln][cell] == 0:
		return Flow.centre(map, Flow.nearest_walkable(map, cell, ln))
	return Vector2i(x, y)


## Back on an attack-move after a fight: to its own slot, by the group's field.
func resume_attack_move(i: int) -> void:
	var c := Vector2i(units.amx[i], units.amy[i]) if units.amc[i] < 0 else Flow.centre(map, units.amc[i])
	order_move(i, units.amx[i], units.amy[i], SLOT_ARRIVE, 0, c.x, c.y)


## Head for a point of its own beside a rect (a place round a building it attacks), following
## the rect's field `key` there and stepping round the rect's corners near it (see _plan).
func order_beside(i: int, x: int, y: int, r: Rect2i, key: int) -> void:
	units.tx[i] = x
	units.ty[i] = y
	units.reach[i] = 2
	units.rx0[i] = r.position.x
	units.ry0[i] = r.position.y
	units.rx1[i] = r.end.x
	units.ry1[i] = r.end.y
	units.fkey[i] = key
	units.arrive[i] = SLOT_ARRIVE
	units.group[i] = 0
	units.pace[i] = 0
	_start(i)


## Where unit `uid` goes in a group move's args: its formation slot (or, for an order that was
## queued, the slot it was given then).
func slot_of(a: Dictionary, uid) -> Vector2i:
	if a.has("slots"):
		return a.slots[int(uid)]
	return Vector2i(int(a.sx), int(a.sy))


## A group move's formation: a box facing the way the group goes, centred on the click, as wide
## as about twice its depth, neighbours a body's width plus FORM_GAP apart. Melee in the front
## rows, shooters (and healers) behind. Units are dealt slots by where they are now: the ones
## furthest ahead take the front rows and, along each row, left to right as they stand, so the
## group closes up without units crossing. A slot that is blocked, or that can't be walked to
## in a straight line from the click, moves half-way in, else onto the click. Returns the args
## with slots (uid -> Vector2i), the group, its centre (fx, fy) and pace (slowest speed).
func _formation(player: int, a: Dictionary) -> Dictionary:
	var out := a.duplicate()
	var idx := []
	for uid in a.ids:
		var i := units.index_of(int(uid))
		if i >= 0 and units.owner[i] == player:
			idx.append(i)
	out.group = next_group
	next_group += 1
	var x := clampi(int(a.x), 0, map.width * SimMap.TILE - 1)
	var y := clampi(int(a.y), 0, map.height * SimMap.TILE - 1)
	out.fx = x
	out.fy = y
	out.pace = 0
	out.slots = {}
	if idx.is_empty():
		return out
	var n := idx.size()
	var sx := 0
	var sy := 0
	var pace := 1 << 30
	var rmax := 0
	for i in idx:
		sx += units.x[i]
		sy += units.y[i]
		pace = mini(pace, units.speed[i])
		rmax = maxi(rmax, units.radius[i])
	var cx := sx / n
	var cy := sy / n
	var dx := x - cx
	var dy := y - cy
	var d := Fixed.isqrt(dx * dx + dy * dy)
	var ux := 0
	var uy := Fixed.ONE   # standing still: face down the map
	if d > 0:
		ux = dx * Fixed.ONE / d
		uy = dy * Fixed.ONE / d
	var front := []
	var back := []
	for i in idx:
		var t: Dictionary = types[units.kind[i]]
		if t.get("ranged", false) or t.get("healer", false):
			back.append(i)
		else:
			front.append(i)
	var cols := clampi(Fixed.isqrt(2 * n), 1, n)
	var space := 2 * rmax + FORM_GAP
	var rows := (front.size() + cols - 1) / cols + (back.size() + cols - 1) / cols
	var row := 0
	for part in [front, back]:
		var ahead := {}
		for i in part:
			ahead[i] = (units.x[i] - cx) * ux + (units.y[i] - cy) * uy
		part.sort_custom(func(p, q): return ahead[p] > ahead[q] or (ahead[p] == ahead[q] and p < q))
		for first in range(0, part.size(), cols):
			var line: Array = part.slice(first, first + cols)
			var side := {}
			for i in line:
				side[i] = (units.y[i] - cy) * ux - (units.x[i] - cx) * uy
			line.sort_custom(func(p, q): return side[p] < side[q] or (side[p] == side[q] and p < q))
			var k := line.size()
			var along := (rows - 1) * space / 2 - row * space
			for c in k:
				var across := (2 * c - (k - 1)) * space / 2
				var px := x + (ux * along - uy * across) / Fixed.ONE
				var py := y + (uy * along + ux * across) / Fixed.ONE
				out.slots[units.id[line[c]]] = _slot_ok(line[c], px, py, x, y)
			row += 1
	if n > 1:
		out.pace = pace
	return out


## A formation slot unit i can stand in: (px, py) if it's open ground (moved off any wall by
## the unit's body) and a straight walk from the group's centre reaches it; else half-way in;
## else the centre itself.
func _slot_ok(i: int, px: int, py: int, x: int, y: int) -> Vector2i:
	var ln := lane(i)
	var c := _snap(x, y, ln)
	for k in 2:
		var p := Vector2i(clampi(px, 0, map.width * SimMap.TILE - 1), clampi(py, 0, map.height * SimMap.TILE - 1))
		if map.walkable(p.x, p.y, ln):
			p = _off_walls(p.x, p.y, units.radius[i], ln)
			if Flow.clear_line(map, c.x, c.y, p.x, p.y, ln):
				return p
		px = (px + c.x) / 2
		py = (py + c.y) / 2
	return c


## A point on open ground moved just far enough that a body of radius r there clears the
## blocked tiles beside it (as _separate keeps bodies off them).
func _off_walls(x: int, y: int, r: int, ln: int) -> Vector2i:
	var t := SimMap.TILE
	var cx := x / t
	var cy := y / t
	if x - cx * t < r and not map.cell_walkable(cx - 1, cy, ln):
		x = cx * t + mini(r, t / 2)
	elif (cx + 1) * t - x < r and not map.cell_walkable(cx + 1, cy, ln):
		x = (cx + 1) * t - mini(r, t / 2)
	if y - cy * t < r and not map.cell_walkable(cx, cy - 1, ln):
		y = cy * t + mini(r, t / 2)
	elif (cy + 1) * t - y < r and not map.cell_walkable(cx, cy + 1, ln):
		y = (cy + 1) * t - mini(r, t / 2)
	return Vector2i(x, y)


## Head straight for a point with no flow field (the way there is known to be clear).
func order_direct(i: int, x: int, y: int) -> void:
	units.tx[i] = x
	units.ty[i] = y
	units.reach[i] = 0
	units.fkey[i] = -1
	units.arrive[i] = 0
	units.group[i] = 0
	_start(i)


## Head for "next to" a rect of milli-tiles (inclusive), following field `key`.
func order_reach(i: int, r: Rect2i, key: int) -> void:
	units.tx[i] = r.position.x + r.size.x / 2
	units.ty[i] = r.position.y + r.size.y / 2
	units.reach[i] = 1
	units.rx0[i] = r.position.x
	units.ry0[i] = r.position.y
	units.rx1[i] = r.end.x
	units.ry1[i] = r.end.y
	units.fkey[i] = key
	units.arrive[i] = 0
	units.group[i] = 0
	_start(i)


func _start(i: int) -> void:
	units.moving[i] = 1
	units.stuck[i] = 0
	units.prog[i] = -1
	var w := _plan(i, units.x[i], units.y[i])
	if w.x == -3:
		w = _rect_near(i, units.x[i], units.y[i])
	units.wx[i] = w.x if w.x >= 0 else units.x[i]
	units.wy[i] = w.y if w.x >= 0 else units.y[i]


## Field keys: ((target * 4 + kind) * LANES + lane). One field per lane (lane(i) for a unit).
func cell_field(cell: int, near: bool, ln := 0) -> int:
	return (cell * 4 + (FIELD_CELL_NEAR if near else FIELD_CELL)) * LANES + ln


func building_field(bid: int, near: bool, ln := 0) -> int:
	return (bid * 4 + (FIELD_BUILDING_NEAR if near else FIELD_BUILDING)) * LANES + ln


# ------------------------------------------------------------------ movement

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
	var rch := units.reach
	var rs := units.radius
	var rx0 := units.rx0
	var ry0 := units.ry0
	var rx1 := units.rx1
	var ry1 := units.ry1
	var owners := units.owner
	var pc := units.pace
	for i in xs.size():
		if mv[i] == 0:
			# Shoved well off its spot by passing units? Walk back (checked on re-plan ticks).
			# Not while fighting: a stopped shooter's tx is still its (attack-)move's end, and
			# walking "back" there a step every re-plan crept it towards the foe (Dominic's crossbows).
			if grp[i] == 0 or units.foe[i] != 0 or st[i] >= STUCK_LIMIT or (tick + ids[i]) % REPLAN_EVERY != 0:
				continue
			var back := ar[i] * SETTLE_FACTOR + (SLOT_SLACK if ar[i] == SLOT_ARRIVE else RETURN_SLACK)
			if Fixed.dist2(xs[i], ys[i], txs[i], tys[i]) <= back * back:
				continue
			mv[i] = 1
		var x := xs[i]
		var y := ys[i]
		if rch[i] == 1:
			var ex := maxi(maxi(rx0[i] - x, 0), x - rx1[i])
			var ey := maxi(maxi(ry0[i] - y, 0), y - ry1[i])
			var reach := rs[i] + Economy.REACH
			if ex * ex + ey * ey <= reach * reach:
				mv[i] = 0
				st[i] = 0   # there: a stale count would read as a give-up
				continue
		else:
			var gx := txs[i] - x
			var gy := tys[i] - y
			if gx * gx + gy * gy <= ar[i] * ar[i]:
				mv[i] = 0
				st[i] = 0
				continue
		var s := sp[i] if pc[i] == 0 else mini(sp[i], pc[i])   # a group keeps to its slowest member's pace
		var mc := lane_base[owners[i]] + units.mclass[i]   # the walk grid (lane); speed goes by class
		var here := map.cell_of(x, y)
		var pct: int = move_pct[units.mclass[i]][map.terrain[here]]
		if pct != 100:
			s = s * pct / 100   # amphibians are quicker in the swamp (rules.movement.terrain_speed)
		if trail_cfg.speed_pct != 0 and units.mclass[i] != SimMap.FLYING:
			s = s * Trails.speed_pct(self, here) / 100   # quicker on a worn trail (rules.trails, off by default)
		if (tick + ids[i]) % PROGRESS_EVERY == 0 and units.foe[i] == 0:
			# Net progress, after the pushes: a unit that walks into a planted worker or a wall
			# and is shoved straight back moves every tick but gets nowhere. Measured along the
			# field (its cost falls by a cell per cell walked, detours included), else as the
			# crow flies. No ground gained in two seconds counts as half a give-up.
			var p := _progress(i, x, y)
			if units.prog[i] >= 0 and p.x > units.prog[i] - p.y:
				# A group queued at a gap waits its turn (patient); a worker crowded off its
				# bush, or a sheep wedged by a builder, is better off trying elsewhere soon.
				st[i] += STUCK_LIMIT / (6 if grp[i] > 0 and rch[i] == 0 else 2)
				if st[i] >= STUCK_LIMIT:
					# Can't get there: close enough to a point counts as there; otherwise give up
					# (a gatherer crowded off its bush takes another tile; see Economy._gather).
					var near := ar[i] * SETTLE_FACTOR + RETURN_SLACK
					if rch[i] != 1 and Fixed.dist2(x, y, txs[i], tys[i]) <= near * near:
						st[i] = 0
					mv[i] = 0
					continue
			else:
				st[i] = 0   # ground gained: not stuck (a step that merely moved no longer clears it)
			units.prog[i] = p.x
		if (tick + ids[i]) % REPLAN_EVERY == 0 or Fixed.dist2(x, y, wxs[i], wys[i]) <= s * s:
			var w := _plan(i, x, y)
			if w.x == -2:
				# Past a near field's edge: switch to the full field, straight on meanwhile.
				var key := units.fkey[i]
				var base := key / LANES
				base = base - base % 4 + (FIELD_CELL if base % 4 == FIELD_CELL_NEAR else FIELD_BUILDING)
				units.fkey[i] = base * LANES + key % LANES
				w = Vector2i(txs[i], tys[i])
			elif w.x == -3:
				# Nowhere free round its rect: a few looks like that and it gives the place up
				# (a gatherer then takes another tile of the clump; see Economy._gather).
				st[i] += STUCK_LIMIT / SPOT_BUSY
				if st[i] >= STUCK_LIMIT:
					mv[i] = 0
					continue
				w = _rect_near(i, x, y)
			elif w.x < 0:
				mv[i] = 0   # unreachable from here
				st[i] = STUCK_LIMIT
				continue
			wxs[i] = w.x
			wys[i] = w.y
		var dx := wxs[i] - x
		var dy := wys[i] - y
		var d := Fixed.isqrt(dx * dx + dy * dy)
		if d > rs[i] and grp[i] == 0 and units.foe[i] == 0:   # a group in formation walks through its own
			var v := _sidestep(i, x, y, dx * Fixed.ONE / d, dy * Fixed.ONE / d, s)
			if v.x != 0 or v.y != 0:
				dx = v.x
				dy = v.y
				d = Fixed.isqrt(dx * dx + dy * dy)
		var nx := x
		var ny := y
		if d > 0:
			nx = x + dx * mini(s, d) / d
			ny = y + dy * mini(s, d) / d
		if map.walkable(nx, ny, mc) and (nx / SimMap.TILE == x / SimMap.TILE or ny / SimMap.TILE == y / SimMap.TILE
				or (map.walkable(nx, y, mc) and map.walkable(x, ny, mc))):
			pass   # a step into a diagonal neighbour cell needs both cells beside it open: no slipping between two corners
		elif map.walkable(nx, y, mc):
			ny = y
		elif map.walkable(x, ny, mc):
			nx = x
		else:
			nx = x
			ny = y
		if nx == x and ny == y:
			st[i] += 1
			if st[i] >= STUCK_LIMIT:
				mv[i] = 0   # give up; the tests count these
			else:
				var w := _plan(i, x, y)
				if w.x == -3:
					w = _rect_near(i, x, y)
				wxs[i] = w.x if w.x >= 0 else x
				wys[i] = w.y if w.x >= 0 else y
			continue
		xs[i] = nx
		ys[i] = ny
	units.x = xs
	units.y = ys
	units.moving = mv
	units.stuck = st
	units.wx = wxs
	units.wy = wys


## Local avoidance (Dominic, 2026-10-13: "scavengers getting stuck on each other too easily"):
## a unit on its own (a worker, mostly: a group move has its formation) heading (ux, uy)
## (scaled by Fixed.ONE) with a standing body just ahead in its way steps half aside, round
## the side the body isn't on. Walkers are left to separation, which slides them past each
## other. Positions are the tick's start (units.x), so the order units move in doesn't matter.
## (0, 0): nothing in the way.
func _sidestep(i: int, x: int, y: int, ux: int, uy: int, s: int) -> Vector2i:
	var ox := units.x   # the tick's start: _move writes its own copy
	var oy := units.y
	var om := units.moving
	var orad := units.radius
	var start := spatial.start
	var items := spatial.items
	var sw := spatial.width
	var cx := x / SimMap.TILE
	var cy := y / SimMap.TILE
	var best := -1
	var best_ahead := 1 << 30
	var best_side := 0
	var ri := orad[i]
	for yy in range(maxi(cy - 1, 0), mini(cy + 2, spatial.height)):
		for xx in range(maxi(cx - 1, 0), mini(cx + 2, sw)):
			var c := yy * sw + xx
			for k in range(start[c], start[c + 1]):
				var j: int = items[k]
				if j == i or om[j] == 1:
					continue   # walkers sort themselves out (separation slides them past)
				var rx: int = ox[j] - x
				var ry: int = oy[j] - y
				var rr: int = ri + orad[j]
				var ahead := (rx * ux + ry * uy) / Fixed.ONE
				if ahead <= 0 or ahead > rr + 2 * s or ahead >= best_ahead:
					continue
				var side := (rx * uy - ry * ux) / Fixed.ONE   # > 0: j is on our left
				if side >= rr or side <= -rr:
					continue
				if side == 0:
					side = 1 if (units.id[i] + units.id[j]) % 2 == 0 else -1
				best = j
				best_ahead = ahead
				best_side = side
	if best < 0:
		return Vector2i.ZERO
	# Ahead and half aside, away from it: about 27 degrees off the way.
	var sgn := 1 if best_side > 0 else -1   # it's on the left: aside to the right (+1), and the other way round
	var v := Vector2i(ux * 2 - sgn * uy, uy * 2 + sgn * ux)
	if not map.walkable(x + v.x * s / (2 * Fixed.ONE), y + v.y * s / (2 * Fixed.ONE), lane(i)):
		return Vector2i.ZERO   # no room that side: on as before
	return v


## Unit i's next waypoint from (x, y). Point moves aim at the target if the way
## is clear; reach moves aim at the nearest point of their rect once beside it;
## otherwise the furthest clear cell a few steps down the flow field.
## (-1, -1): unreachable. (-2, -2): outside a near field's cutoff (use the full field).
func _plan(i: int, x: int, y: int) -> Vector2i:
	var tx := units.tx[i]
	var ty := units.ty[i]
	if units.fkey[i] < 0:
		return Vector2i(tx, ty)   # steering straight at the target (a chase in the open)
	var f = field_for(units.fkey[i])
	if f == null:
		return Vector2i(tx, ty)   # field not solved yet: head straight for now
	var cell := map.cell_of(x, y)
	var cost: int = f.dist[cell]
	if cost >= Flow.INF:
		var kind := (units.fkey[i] / LANES) % 4
		if kind == FIELD_CELL_NEAR or kind == FIELD_BUILDING_NEAR:
			return Vector2i(-2, -2)
		return Vector2i(-1, -1)
	if units.reach[i] == 1:
		if cost <= 2 * Flow.DIAGONAL:   # within two cells: make for a free spot before meeting the crowd
			return _spot(i, x, y)
	elif cost == 0 or (cost <= DIRECT_COST and units.stuck[i] < STUCK_LIMIT / 2 and Flow.clear_path(map, x, y, tx, ty, units.radius[i], lane(i))):
		return Vector2i(tx, ty)
	elif units.reach[i] == 2 and cost <= 4 * Flow.STRAIGHT:
		var c := _round_corner(i, x, y, tx, ty)   # its place is round the far side of the building
		if c.x >= 0:
			return c
	var best := cell
	var k: int = f.next[cell]
	# Half-way to giving up, follow the field a cell at a time (the retry): no shortcuts.
	for step in (1 if units.stuck[i] >= STUCK_LIMIT / 2 else LOOKAHEAD):
		if k < 0:
			break
		if f.dist[k] == 0:
			if units.reach[i] == 0:
				return Vector2i(tx, ty)   # the next cell is the target's
			break
		var c := Flow.centre(map, k)
		if not Flow.clear_path(map, x, y, c.x, c.y, units.radius[i], lane(i)):
			break
		best = k
		k = f.next[k]
	return Flow.centre(map, best)


## Where a unit beside its rect (a resource tile, a building) steps to: the nearest free spot
## round the rect (a body's width from it, clear of every stopped unit there), so it walks up to
## a gap in the crowd instead of pushing into it; the same spot while it stays free. A spot only
## an idle body stands in comes after free ones (it gets shoved aside). (-3, -3) when every
## spot has a worker at work in it: the place is crowded.
func _spot(i: int, x: int, y: int) -> Vector2i:
	var r := units.radius[i]
	var ln := lane(i)
	var x0 := units.rx0[i]
	var y0 := units.ry0[i]
	var x1 := units.rx1[i] + 1
	var y1 := units.ry1[i] + 1
	var o := r + SPOT_GAP
	# Stopped bodies round the rect (positions from the start of the tick's moves).
	var near := []
	var t := SimMap.TILE
	for cy in range(maxi((y0 - o) / t - 1, 0), mini((y1 + o) / t + 2, spatial.height)):
		for cx in range(maxi((x0 - o) / t - 1, 0), mini((x1 + o) / t + 2, spatial.width)):
			var c := cy * spatial.width + cx
			for k in range(spatial.start[c], spatial.start[c + 1]):
				var j: int = spatial.items[k]
				if j != i and j < units.count() and units.moving[j] == 0:
					near.append(j)
	var space := 2 * r + SPOT_GAP / 2
	var wd := x1 - x0 + 2 * o
	var ht := y1 - y0 + 2 * o
	var perim := 2 * (wd + ht)
	var count := maxi(perim / space, 4)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 62
	for k in count:
		var along := k * perim / count
		var p: Vector2i
		if along < wd:
			p = Vector2i(x0 - o + along, y0 - o)
		elif along < wd + ht:
			p = Vector2i(x1 + o, y0 - o + along - wd)
		elif along < 2 * wd + ht:
			p = Vector2i(x1 + o - (along - wd - ht), y1 + o)
		else:
			p = Vector2i(x0 - o, y1 + o - (along - 2 * wd - ht))
		var ex := maxi(maxi(x0 - p.x, 0), p.x - x1)
		var ey := maxi(maxi(y0 - p.y, 0), p.y - y1)
		if ex * ex + ey * ey > (r + Economy.REACH - SPOT_GAP / 2) * (r + Economy.REACH - SPOT_GAP / 2) or not map.walkable(p.x, p.y, ln):
			continue   # round a corner it couldn't work from, or blocked
		p = _off_walls(p.x, p.y, r, ln)
		# Free; else only a body standing about there (it gets shoved aside); else a worker at work.
		var level := 0
		for j in near:
			var rr: int = r + units.radius[j] - SPOT_GAP / 2
			if Fixed.dist2(p.x, p.y, units.x[j], units.y[j]) < rr * rr:
				if units.task[j] == Economy.GATHER or units.task[j] == Economy.BUILD:
					level = 2
					break
				level = 1
		if level == 2:
			continue
		var d := Fixed.dist2(x, y, p.x, p.y) + level * (1 << 40)
		if p.x == units.wx[i] and p.y == units.wy[i]:
			d -= 1 << 39   # keep the spot it was making for
		if d < best_d:
			best_d = d
			best = p
	if best.x < 0:
		return Vector2i(-3, -3)   # every spot has a worker at work in it
	if Flow.clear_path(map, x, y, best.x, best.y, r, ln):
		return best
	return _rect_near(i, x, y)   # no straight way to it: in the old way (anywhere in reach will do)


## The nearest point of unit i's rect, the old way in when there's no spot to make for.
func _rect_near(i: int, x: int, y: int) -> Vector2i:
	return Vector2i(clampi(x, units.rx0[i], units.rx1[i]), clampi(y, units.ry0[i], units.ry1[i]))


## A corner of unit i's rect, stood off by a body and a row, to walk round it towards (tx, ty):
## of the corners it can walk straight to (not the one it's at), the one making the shortest
## way on. (-1, -1) if none.
func _round_corner(i: int, x: int, y: int, tx: int, ty: int) -> Vector2i:
	var e := 3 * units.radius[i] + FORM_GAP
	var ln := lane(i)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 62
	for c in [Vector2i(units.rx0[i] - e, units.ry0[i] - e), Vector2i(units.rx1[i] + e, units.ry0[i] - e),
			Vector2i(units.rx1[i] + e, units.ry1[i] + e), Vector2i(units.rx0[i] - e, units.ry1[i] + e)]:
		var d0 := Fixed.dist2(x, y, c.x, c.y)
		if d0 < 200 * 200 or not map.walkable(c.x, c.y, ln) or not Flow.clear_path(map, x, y, c.x, c.y, units.radius[i], ln):
			continue
		var d := Fixed.isqrt(d0) + Fixed.isqrt(Fixed.dist2(c.x, c.y, tx, ty))
		if d < best_d:
			best_d = d
			best = c
	return best


## How far unit i still has to go, and how much nearer it should be by the next check: its
## field's cost at (x, y) while it follows a solved field (falls a cell per cell walked, detours
## included) and a cell's worth; on the last cell, or with no field, the distance to its target
## as the crow flies and a quarter of what it can walk in the time.
func _progress(i: int, x: int, y: int) -> Vector2i:
	if units.fkey[i] >= 0 and fields.has(units.fkey[i]):
		var d: int = fields[units.fkey[i]].dist[map.cell_of(x, y)]
		# A unit making for its own place near the end (a slot off its group's centre, a spot
		# round a building) goes by the crow: its field's cost no longer falls as it walks.
		if d < Flow.INF and d > Flow.DIAGONAL and not (d <= DIRECT_COST and units.arrive[i] == SLOT_ARRIVE and units.reach[i] != 1):
			return Vector2i(d, STRAIGHT_PER_CHECK)
	return Vector2i(Fixed.isqrt(Fixed.dist2(x, y, units.tx[i], units.ty[i])), units.speed[i] * PROGRESS_EVERY / 4)


# ------------------------------------------------------------------ flow fields

## The flow field for a key, or null (and queued) if it isn't solved yet.
func field_for(key: int) -> RefCounted:
	if fields.has(key):
		return fields[key]
	if not key in field_queue:
		field_queue.append(key)
	return null


func _solve_queued() -> void:
	var spent := 0
	while not field_queue.is_empty() and (spent == 0 or spent < SOLVE_BUDGET):
		var key: int = field_queue.pop_front()
		if fields.has(key):
			continue
		var mc := key % LANES
		var target := key / (LANES * 4)
		var kind := (key / LANES) % 4
		var sources := PackedInt32Array()
		if kind == FIELD_CELL or kind == FIELD_CELL_NEAR:
			sources.append(target)
		else:
			var b := buildings.index_of(target)
			if b >= 0:
				sources = buildings.footprint(b, map.width)
			else:
				var br := Bridges.index_of(self, target)
				if br >= 0:
					sources = bridge_cells[br]
		var near := kind == FIELD_CELL_NEAR or kind == FIELD_BUILDING_NEAR
		var f = Flow.solve(map, sources, NEAR_CUTOFF if near else Flow.INF, mc)
		spent += maxi(f.pops, 1)
		fields[key] = f
		field_order.append(key)
		if field_order.size() > maxi(24, FIELD_CACHE * races.size()):
			fields.erase(field_order.pop_front())


## The map changed this tick (a building placed, a resource used up): drop every
## cached field a closing change could affect (units re-request what they need); where cells
## only opened (a tree felled, a bush picked bare, a bridge rebuilt) patch the field instead,
## unless the cell was one of its sources (Flow.patch). Felling a forest no longer re-solves
## every field that saw it.
func _sync_map() -> void:
	if map.fresh.is_empty():
		return
	var keep := []
	for key in field_order:
		var f = fields[key]
		var stale := false
		var opened := PackedInt32Array()
		for k in map.fresh.size():
			var c: int = map.fresh[k]
			if not f.touches(map, c):
				continue
			if map.fresh_closed[k] == 1 or c in f.sources:
				stale = true
				break
			opened.append(c)
		if stale:
			fields.erase(key)
			continue
		for c in opened:
			f.patch(map, c, key % LANES)
		keep.append(key)
	field_order = keep
	map.fresh.clear()
	map.fresh_closed.clear()


# ------------------------------------------------------------------ separation

## Push overlapping pairs apart. Reads positions from before any pushes this
## tick, so the result doesn't depend on which unit of a pair comes first.
## A moving unit touching a stopped groupmate near the target settles too;
## bodies are kept off blocked neighbour tiles, and a unit caught inside a new
## building's footprint steps out to the nearest open tile.
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
	# Workers standing at their job (gathering or building) are planted: two planted workers may
	# overlap (otherwise they shove each other out of reach and trade places for ever), and a
	# planted one isn't moved by anyone; the other unit gives way.
	var planted := PackedByteArray()
	planted.resize(n)
	var stood := PackedByteArray()
	stood.resize(n)
	for i in n:
		if mv[i] == 0 and grp[i] > 0 and ar[i] == SLOT_ARRIVE and units.reach[i] == 0:
			stood[i] = 1
	var tasks := units.task
	var foes := units.foe
	var role := PackedByteArray()   # 1: standing idle (gives way), 2: walking to or from a job
	role.resize(n)
	for i in n:
		if mv[i] == 0 and tasks[i] == Economy.NONE and foes[i] == 0 and stood[i] == 0:
			role[i] = 1
		elif mv[i] == 1 and tasks[i] != Economy.NONE:
			role[i] = 2
	for i in n:
		if mv[i] == 0 and (tasks[i] == Economy.GATHER or tasks[i] == Economy.BUILD):
			planted[i] = 1
		elif mv[i] == 0 and foes[i] != 0:
			# So is a unit hitting a building: the crowd round a wall walks round it, never
			# shoves a hitter out of reach (Dominic: "attacking buildings turns into fighting the pathfinding").
			var b := buildings.index_of(foes[i])
			if b >= 0 and Combat._gap(self, i, -1, b) <= types[units.kind[i]].reach + Combat.HOLD:
				planted[i] = 1
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
						var near := ar[m] * (2 if ar[m] == SLOT_ARRIVE else SETTLE_FACTOR)   # a slot is meant to be stood in
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
					# A unit standing in its formation slot isn't shoved by groupmates still coming
					# in: they slip past it to their own slots (the gaps are too narrow to walk
					# round, and shoving the ones already there about looked buggy).
					if grp[i] == grp[j] and ((stood[i] == 1 and mv[j] == 1) or (stood[j] == 1 and mv[i] == 1)):
						continue
					if stood[i] == 1 and stood[j] == 1:
						continue   # two groups' formations overlapping: no shoving match (and no walking back into it)
					# A worker on its way to or from a job walks on; anyone standing idle in its way gives way.
					var hi := planted[i] == 1 or (role[i] == 2 and role[j] == 1)
					var hj := planted[j] == 1 or (role[j] == 2 and role[i] == 1)
					if hi and hj:
						continue
					var push := (rr - d) / SEPARATION_DIV + 1
					var px := ux * push / Fixed.ONE
					var py := uy * push / Fixed.ONE
					if not hi:
						pushx[i] -= px * (2 if hj else 1)
						pushy[i] -= py * (2 if hj else 1)
					if not hj:
						pushx[j] += px * (2 if hi else 1)
						pushy[j] += py * (2 if hi else 1)
	var t := SimMap.TILE
	for i in n:
		if settle[i] == 1:
			mv[i] = 0
		var mc := lane(i)
		if not map.walkable(xs[i], ys[i], mc):
			# Its centre is on blocked ground (a foundation laid on it, or a spawn): step out
			# to the nearest open neighbour's edge, the least move that makes it walkable;
			# with no open neighbour (deep in a footprint) the nearest open cell, outright.
			var p := _step_out(xs[i], ys[i], mc)
			xs[i] = p.x
			ys[i] = p.y
			continue
		if pushx[i] != 0 and map.walkable(xs[i] + pushx[i], ys[i], mc):
			xs[i] += pushx[i]
		if pushy[i] != 0 and map.walkable(xs[i], ys[i] + pushy[i], mc):
			ys[i] += pushy[i]
		# Keep the body (not just the centre) off blocked neighbour tiles, easing it off by at
		# most CORRECT_MAX a tick: a shove into a wall slides back out, never pops a tile.
		var cx := xs[i] / t
		var cy := ys[i] / t
		var r := rs[i]
		if xs[i] - cx * t < r and not map.cell_walkable(cx - 1, cy, mc):
			xs[i] = mini(cx * t + r, xs[i] + CORRECT_MAX)
		elif (cx + 1) * t - xs[i] < r and not map.cell_walkable(cx + 1, cy, mc):
			xs[i] = maxi((cx + 1) * t - r, xs[i] - CORRECT_MAX)
		if ys[i] - cy * t < r and not map.cell_walkable(cx, cy - 1, mc):
			ys[i] = mini(cy * t + r, ys[i] + CORRECT_MAX)
		elif (cy + 1) * t - ys[i] < r and not map.cell_walkable(cx, cy + 1, mc):
			ys[i] = maxi((cy + 1) * t - r, ys[i] - CORRECT_MAX)
	units.x = xs
	units.y = ys
	units.moving = mv


## The nearest walkable point for a centre on blocked ground: just inside the closest open
## orthogonal neighbour, else the nearest open cell's centre.
func _step_out(x: int, y: int, mc: int) -> Vector2i:
	var t := SimMap.TILE
	var cx := x / t
	var cy := y / t
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for n in [[cx - 1, cy, cx * t - 1, y], [cx + 1, cy, (cx + 1) * t, y], [cx, cy - 1, x, cy * t - 1], [cx, cy + 1, x, (cy + 1) * t]]:
		if not map.cell_walkable(n[0], n[1], mc):
			continue
		var d := absi(n[2] - x) + absi(n[3] - y)
		if d < best_d:
			best_d = d
			best = Vector2i(n[2], n[3])
	if best.x >= 0:
		return best
	return Flow.centre(map, Flow.nearest_walkable(map, cy * map.width + cx, mc))


# ------------------------------------------------------------------ hash

## Hash of everything that matters, in id order.
func state_hash() -> int:
	var h := Fixed.FNV_START
	for v in [tick, rng.state, next_id, next_group, units.count(), buildings.count(), map.version, winner]:
		h = Fixed.mix(h, v)
	for p in races.size():
		for r in resources.size():
			h = Fixed.mix(h, stock[r][p])
			h = Fixed.mix(h, gathered[r][p])
		h = Fixed.mix(h, lost[p])
		h = Fixed.mix(h, teams[p])
		h = Fixed.mix(h, ages[p])
		h = Fixed.mix(h, defeated[p])
		h = Fixed.mix(h, auto_reseed[p])
		for v in researched[p]:
			h = Fixed.mix(h, v)
	for k in wonder_ids.size():
		h = Fixed.mix(Fixed.mix(h, wonder_ids[k]), wonder_since[k])
	for v in market_price:
		h = Fixed.mix(h, v)
	# Which fields are solved or pending changes how units steer, so it's state too.
	for key in field_order:
		h = Fixed.mix(h, key)
	h = Fixed.mix(h, -1)
	for key in field_queue:
		h = Fixed.mix(h, key)
	for c in map.resource_cells:
		h = Fixed.mix(h, map.amount[c])
	h = Bridges.hash_into(self, h)
	var worn := 0
	for c in wear.size():
		worn += wear[c] * (c % 251 + 1)
	h = Fixed.mix(h, worn)
	var u := units
	for i in u.count():
		for v in [u.id[i], u.owner[i], u.kind[i], u.x[i], u.y[i], u.tx[i], u.ty[i], u.moving[i],
				u.arrive[i], u.wx[i], u.wy[i], u.group[i], u.stuck[i], u.prog[i], u.hp[i], u.fkey[i], u.reach[i],
				u.task[i], u.target[i], u.home[i], u.carry_kind[i], u.carry[i], u.work[i],
				u.foe[i], u.cooldown[i], u.stance[i], u.posture[i], u.gx[i], u.gy[i], u.amx[i], u.amy[i], u.orders[i].size(), u.mclass[i], u.patient[i], u.pace[i], u.amc[i]]:
			h = Fixed.mix(h, v)
		for o in u.orders[i]:
			h = Fixed.mix(h, Rng.hash_string(JSON.stringify(o, "", true)))
	var b := buildings
	for i in b.count():
		for v in [b.id[i], b.owner[i], b.kind[i], b.cx[i], b.cy[i], b.hp[i], b.progress[i], b.done[i],
				b.train[i], b.rally_x[i], b.rally_y[i], b.queue[i].size(), b.cooldown[i]]:
			h = Fixed.mix(h, v)
		for k in b.queue[i]:
			h = Fixed.mix(h, k)
	return h
