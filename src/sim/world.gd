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
const Abilities := preload("res://src/sim/abilities.gd")
const Heroes := preload("res://src/sim/heroes.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const Shots := preload("res://src/sim/shots.gd")
const Trade := preload("res://src/sim/trade.gd")
const Walls := preload("res://src/sim/walls.gd")
const Repair := preload("res://src/sim/repair.gd")
const Modes := preload("res://src/sim/modes.gd")

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
const FIELD_CACHE := 24        # flow fields kept per player (oldest dropped first; at least 24): bots working camps, posts and scouts at once thrashed 12 (milestone 15 phase 7)
const SOLVE_BUDGET := 1500     # flow-field cells settled per tick: one full solve, or a few near ones
const PATCH_BUDGET := 3000     # flow-field cells settled per tick patching cached fields for map changes (then they're dropped)
const NEAR_CUTOFF := 160       # cost cutoff for "near" fields (16 tiles): short work trips
const SEP_DX := [0, 1, -1, 0, 1]   # _separate's tiles round a unit's: its own, then the four after it
const SEP_DY := [0, 0, 1, 1, 1]
# Places of their own (Dominic's playtest, 2026-10-13: a group's units pushed each other about
# at the end of a move, workers got stuck on each other, a crowd fought the pathing at a wall).
const FORM_GAP := 160          # milli-tiles between neighbouring bodies in a formation, or round a building
const SLOT_ARRIVE := 60        # a unit making for its own place (a formation slot, a spot by a building) stops this close
const SLOT_SLACK := 400        # shoved this far beyond that, a stopped unit in a formation walks back to its slot
const QUEUE_GAP := 300         # a unit of its side walking its way this close ahead (body to body): it's in a queue, not stuck (_queued)
const RETURN_YIELD := 2000     # walking back into its slot from this close, a unit gives way to its side's other groups passing (_separate)
const SPOT_GAP := 100          # a worker's chosen spot beside its rect: this gap between its body and the rect
const SPOT_BUSY := 3          # this many spot checks finding no free spot and the worker gives the place up

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
## High ground (rules.high_ground, milestone 15): what a level up is worth to shooters and sight.
var high := {}
var classes: Array = []        # armour/attack class names (see Combat.setup)
var tech: Dictionary          # ages and research (data/tech.json, see tech.gd)
var ages := PackedInt32Array()     # per player: the age it's in (1 at the start)
var researched: Array = []         # per player: PackedByteArray over tech.research
var market_price := PackedInt32Array()   # gold per lot of each resource, shared by everyone (market.gd)
var gather_ticks: Array = []       # per player: ticks per unit of each resource gathered (research cuts them)
var bmods: Array = []              # per player, per building type: research on it {add, pct, hp, arm} (Tech.refresh)
var ident: Array = []              # per player: the race's bonuses, own research and lacks (src/identity.gd; Tech.setup); derived from data
var webs := PackedInt32Array()     # race abilities (abilities.gd): webs on the ground, flat [owner, x, y, r, ends, slow_pct]
var ability_ready := {}            # unit id -> the tick it may use its ability again
var slowed := {}                   # unit id -> the tick a sticky hit wears off
var slow_now := {}                 # unit id -> its speed pct this tick (webs, sticky hits); derived each tick
var hero_id := PackedInt32Array()      # per unit type: its living hero's unit id (sheltering too), 0 with none (heroes.gd)
var hero_fell := PackedInt32Array()    # per unit type: the tick + 1 its hero last fell, 0 if never
var hero_types := PackedInt32Array()   # the unit types that are heroes, in order (derived at setup)
var hero_cfg := {}                     # data/heroes.json rules as ints (heroes.gd)
var aura_now := PackedInt32Array()     # per unit slot: the heroes' auras on it this tick (heroes.gd); derived each tick
var move_pct: Array = []       # per movement class, per terrain index: speed percent (rules.movement)
var events: Array = []         # this tick's hits and deaths, for views (not state, not hashed)
var types: Array = []          # unit types, per player per roster slot (see _make_type)
var btypes: Array = []         # building types (see Economy.load_btypes)
var units: Units = Units.new()
var _ost := PackedInt32Array()  # units.stuck at the tick's start (_queued)
var _ox := PackedInt32Array()   # units.x, .y, .moving as they were when the tick's moves began (_move, _sidestep)
var _oy := PackedInt32Array()
var _om := PackedInt32Array()
var _owx := PackedInt32Array()  # and the rest _sidestep reads, looked up once a tick
var _owy := PackedInt32Array()
var _orad := PackedInt32Array()
var _og := PackedInt32Array()
var _oo := PackedInt32Array()
var _sstart := PackedInt32Array()
var _send := PackedInt32Array()
var _sitems := PackedInt32Array()
var buildings: Buildings = Buildings.new()
var shots: Shots = Shots.new()   # shots in flight (shots.gd, combat.gd)
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
var gather_spots := PackedByteArray()   # per resource: 1 if gatherers stand at spots round its tiles (Economy.spotted)
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
var fog_watch := PackedByteArray()        # per cell: 1 if it held a resource or ever changed (fog.gd)
var fog_watch_cells := PackedInt32Array() # those cells, in the order they were first watched
var fog_sight := {}            # (cell * 64 + radius) -> PackedInt32Array: the cells a sight circle with line of sight sees (fog.gd); derived
var fog_sight_version := -1    # map.opaque_version that fog_sight was worked out for
var fields := {}               # field key -> Flow; looked up by key, never iterated
var field_order: Array = []    # cached field keys, oldest first (eviction, invalidation)
var field_queue: Array = []    # field keys waiting for a solve, in request order
var bridge_cfg: Dictionary     # data/bridges.json, as vectors (bridges.gd)
var trail_cfg: Dictionary      # rules.trails as ints (trails.gd)
var garrison_cfg: Dictionary   # buildings.json garrison: heal_every, call_range, not (garrison.gd)
var walk_cfg: Dictionary       # buildings.json walkway and breach, as ints (walls.gd)
var repair_cfg: Dictionary     # buildings.json repair: speed_pct, cost_pct (repair.gd)
var wall_cache := {}           # walkway cell -> its network's steps from it, for this tick (walls.gd); derived
var wall_cache_tick := -1
var rubble := {}               # breach cell -> [terrain it was, owner, building type, x, y, along] (walls.gd)
var mode := ""                 # the game mode (rules.mode, data/modes.json; "": the usual match), modes.gd
var mode_cfg := {}             # its data, numbers as ints
var pour_at := {}              # gatehouse or wall tower id -> the tick it may pour again (combat.gd _pour)
var wear := PackedByteArray()  # per cell: how worn the ground is by walkers (trails.gd)
var bridge_id := PackedInt32Array()   # per map bridge: its id (from next_id), and the rest of its state (bridges.gd)
var bridge_cells: Array = []          # PackedInt32Array of its deck cells
var bridge_rect: Array = []           # Rect2i in milli-tiles (inclusive end, as Economy's rects)
var bridge_hp := PackedInt32Array()
var bridge_up := PackedByteArray()    # 1 standing, 0 broken
var bridge_work := PackedInt32Array() # rebuild ticks put in
var bridge_payer := PackedInt32Array()   # the player who paid for the rebuild under way, or -1

const HIGH_DEFAULTS := {"reach": 1000, "uphill_damage_pct": 75, "sight_unit": 1, "sight_building": 2}


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
	high = _ints(rules.get("high_ground", {}))
	for k in HIGH_DEFAULTS:
		high[k] = int(high.get(k, HIGH_DEFAULTS[k]))
	var ts: Dictionary = rules.get("movement", {}).get("terrain_speed", {})
	for c in SimMap.CLASSES:
		var row := PackedInt32Array()
		for t in map.terrain_ids:
			row.append(int(ts.get(c, {}).get(t, 100)))
		move_pct.append(row)
	spatial = Spatial.new(map.width, map.height)
	resources = Economy.load_resources()
	gather_spots = Economy.load_gather_spots()
	btypes = Economy.load_btypes(resources)
	tech = Tech.load_tech(resources, btypes)
	for p in races.size():
		for u in races[p].units:
			types.append(_make_type(p, u))
	var animals: Dictionary = Animals.load_data()
	Animals.add_types(self, animals)
	Combat.setup(self)
	Tech.setup(self)
	Garrison.setup(self)
	Walls.setup(self)
	Repair.setup(self)
	Market.setup(self)
	Economy.setup(self)
	Modes.setup(self)
	lost.append(0)   # gaia's
	if bool(rules.get("animals", false)):   # a host rule (on by default); some tests turn it off
		Animals.place(self, animals.spawn)
	Match.setup(self)
	Bridges.setup(self)
	Trails.setup(self)
	Abilities.setup(self)
	Heroes.setup(self)
	Fog.setup(self)
	map.fresh.clear()
	map.fresh_closed.clear()
	map.fresh_was.clear()


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
	if int(e.get("radius", 0)) > 0:
		radius = int(e.radius)   # a body with its own size (siege engines)
	return {
		"player": player, "slot": r.slot, "name": r.get("name", r.slot), "recipe": r,
		"speed": int(e.speed) * SPEED_SCALE, "radius": mini(radius, MAX_RADIUS), "hp": int(e.hp),
		"pop": int(e.pop), "cost": Economy.cost_vector(resources, e.cost),
		"train_ticks": int(e.train_time) * TICK_HZ, "worker": "worker" in e.tags, "eval": e,
		"healer": int(e.get("heal", 0)) > 0,   # heals, never fights (heal.gd); spawns passive
		"trader": "trade" in e.tags,   # a trade cart (trade.gd): never fights, as harmless as a sheep
		"harmless": "trade" in e.tags or e.get("targets", "") == "none",   # never fights (a trade cart; a siege tower, walls.gd): walks along with an attack-move
		"posture": Combat.PASSIVE if int(e.get("heal", 0)) > 0 or "trade" in e.tags else Combat.AGGRESSIVE,
		"mclass": _movement_class(e.tags),
		"docks": "docks" in e.tags,                    # a siege tower: stopped by an enemy wall, a way up for its side (walls.gd)
		"sight_add": 0, "carry_add": 0, "build_pct": 0,   # research on the type (Tech.retype)
		"heal_pct": 0, "kill_gold": 0, "wade": 0, "slow_on_hit": 0,   # (and the race's bonuses, milestone 14)
		"form_gap": 0,   # added to FORM_GAP in its formation band (a Norse shield wall closes up: _formation)
		"line": u.get("line", [{"age": int(r.tier), "recipe": r, "eval": e}]),   # the unit through the ages (age-ups re-price from it)
		"hero": r.has("hero"), "aura": [],   # the race's hero (heroes.gd): one at a time, its aura on its friends
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


## The unit type a TRAIN or SPAWN means: its slot's, the hero it names on the hero line (heroes.gd).
func type_for(player: int, a: Dictionary) -> int:
	if a.slot == "hero":
		return Heroes.type_of(self, player, a.get("hero", ""))
	return type_of(player, a.slot)


## Unit type index for a player's roster slot, or -1 (the hero line: its first hero).
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
	Trade.tick(self)
	_pack()
	Repair.tick(self)
	Garrison.tick(self)
	Walls.tick(self)
	Animals.tick(self)
	spatial.build(units.x, units.y)
	var alive := units.changes
	Heal.tick(self)
	Combat.tick(self)
	Heroes.tick(self)
	Match.tick(self)
	Fog.tick(self)
	Trails.tick(self)
	Abilities.tick(self)
	if units.changes != alive:
		spatial.build(units.x, units.y)   # the dead are gone (and the sheltered spilled out): moves look round at who's left (World._spot)
	_next_orders()
	_sync_map()
	_solve_queued()
	_move()
	spatial.build(units.x, units.y)
	_separate()
	tick += 1
	if tick % HASH_EVERY == 0:
		hashes.append([tick, state_hash()])


## Engines that pack and unpack (the great sling: its weapon's `unpack` and `pack`, in ticks). Standing
## still it unpacks, units.ready counting up to its unpack (then it may throw: combat.gd); told to
## move once set up, it packs up first, ready going to -pack and counting back up to 0 while it stands
## (its speed held at 0, its stuck count too: packing isn't being stuck); then it rolls, ready 0. One
## moved before it was set up just stops unpacking.
func _pack() -> void:
	var u := units
	for i in u.count():
		var t: Dictionary = types[u.kind[i]]
		if t.unpack == 0:
			continue
		var r: int = u.ready[i]
		if r < 0:
			r += 1
			u.speed[i] = 0 if r < 0 else int(t.speed)
			u.stuck[i] = 0
			u.prog[i] = -1
		elif u.moving[i] == 1:
			if r >= t.unpack and t.pack > 0:
				r = -t.pack
				u.speed[i] = 0
			else:
				r = 0
		else:
			r = mini(r + 1, t.unpack)
		u.ready[i] = r


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
	if cmd.type in WALL_ORDERS and a.has("ids"):
		a = _wall_orders(cmd)   # onto a wall, up to a foe on one, or down off one first (walls.gd)
		if a.ids.is_empty() and not cmd.args.ids.is_empty():
			return   # (every unit dealt with there; an order for nobody, like a farm's reseed, still runs)
		cmd = {"turn": cmd.turn, "player": cmd.player, "seq": cmd.seq, "type": cmd.type, "args": a}
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
			var k := type_for(cmd.player, a)
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
				if t.hero and hero_id[k] == 0:
					Heroes.spawned(self, slot)   # (a spawned hero is that hero, if it isn't out already)
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
		Commands.GARRISON:
			_clear_combat(cmd.player, a.ids)
			Garrison.cmd_garrison(self, cmd.player, a)
		Commands.REPAIR:
			_clear_combat(cmd.player, a.ids)
			Repair.cmd_repair(self, cmd.player, a)
		Commands.UNGARRISON:
			Garrison.cmd_ungarrison(self, cmd.player, a)
		Commands.CALL_TO_ARMS:
			Garrison.cmd_call_to_arms(self, cmd.player, a)
		Commands.BACK_TO_WORK:
			Garrison.cmd_back_to_work(self, cmd.player, a)
		Commands.ROUTE:
			Trade.cmd_route(self, cmd.player, a)
		Commands.ABILITY:
			Abilities.cmd_ability(self, cmd.player, a)
		Commands.STOP:
			for uid in a.ids:
				var i := units.index_of(uid)
				if i >= 0 and units.owner[i] == cmd.player:
					Economy.clear_task(self, i)
					Combat.clear(self, i)
					units.orders[i].clear()
					units.moving[i] = 0
					Walls.stop(self, i)


# ------------------------------------------------------------------ orders

## Unit orders that meet walls you stand on (walls.gd).
const WALL_ORDERS := [Commands.MOVE, Commands.ATTACK, Commands.ATTACK_MOVE, Commands.GATHER, Commands.BUILD, Commands.HELP_BUILD,
	Commands.DROP_OFF, Commands.GARRISON, Commands.PEN, Commands.RESEED, Commands.REPAIR]


## Walls you stand on, before an order runs: a MOVE onto a walkway sends those who may climb up
## there (walls.gd); an ATTACK on a foe up on a wall sends melee who may climb up to it, then at it;
## a unit up on a wall given anything else climbs down first (the order waits in its queue). Those
## dealt with here leave the order's ids; the rest go on as usual. Shift-queued orders for busy
## units are left alone (they come back here when their turn comes).
func _wall_orders(cmd: Dictionary) -> Dictionary:
	var a: Dictionary = cmd.args.duplicate()
	var queued: bool = int(a.get("queue", 0)) == 1
	var p: int = cmd.player
	var now := []
	for uid in a.ids:
		var i := units.index_of(uid)
		if i >= 0 and units.owner[i] == p and not (queued and busy(i)):
			now.append(uid)
	var done := {}
	if cmd.type == Commands.MOVE:
		var goal := Walls.walkway_at(self, int(a.get("sx", a.x)), int(a.get("sy", a.y)))
		if goal >= 0:
			for uid in Walls.order_onto(self, p, now, goal):
				done[uid] = true
				if not queued:
					units.orders[units.index_of(uid)].clear()
	var foe := units.index_of(a.target) if cmd.type == Commands.ATTACK else -1
	if foe >= 0 and units.perch[foe] != 0:
		var climbers := now.filter(func(uid): return units.perch[units.index_of(uid)] == 0 and not types[units.kind[units.index_of(uid)]].ranged)
		for uid in Walls.order_onto(self, p, climbers, units.perch[foe] - 1):
			done[uid] = true
			units.orders[units.index_of(uid)] = [{"type": Commands.ATTACK, "args": {"ids": [uid], "target": a.target}}]
	for uid in now:
		var i := units.index_of(uid)
		if done.has(uid) or units.perch[i] == 0:
			continue
		if cmd.type == Commands.ATTACK and (types[units.kind[i]].ranged or (foe >= 0 and units.perch[foe] != 0
				and Walls.dist_from(self, units.perch[i] - 1).has(units.perch[foe] - 1))):
			continue   # it shoots from up here, or fights along the walkway
		done[uid] = true
		var at := _order_point(cmd.type, a)
		if at.x < 0 or not Walls.leave(self, i, at.x, at.y):
			continue   # no way down from here: it stays
		if not queued:
			units.orders[i].clear()
		if cmd.type != Commands.MOVE:   # (a move is where it walks once down)
			var one := a.duplicate()
			one.ids = [uid]
			one.erase("queue")
			units.orders[i].push_front({"type": cmd.type, "args": one})
	if not done.is_empty():
		a.ids = a.ids.filter(func(uid): return not done.has(uid))
	return a


## Where an order sends a unit (milli-tiles), for climbing down towards it; (-1, -1) if nowhere.
func _order_point(type: String, a: Dictionary) -> Vector2i:
	match type:
		Commands.MOVE, Commands.ATTACK_MOVE:
			return Vector2i(int(a.get("sx", a.x)), int(a.get("sy", a.y)))
		Commands.GATHER:
			return Flow.centre(map, int(a.cell))
		Commands.BUILD:
			return Vector2i(int(a.cx) * SimMap.TILE + SimMap.TILE / 2, int(a.cy) * SimMap.TILE + SimMap.TILE / 2)
	var id: int = int(a.get("target", a.get("building", 0)))
	var j := units.index_of(id)
	if j >= 0:
		return Vector2i(units.x[j], units.y[j])
	var b := buildings.index_of(id)
	if b >= 0:
		return Vector2i(buildings.cx[b] * SimMap.TILE + buildings.sx[b] * SimMap.TILE / 2, buildings.cy[b] * SimMap.TILE + buildings.sy[b] * SimMap.TILE / 2)
	return Vector2i(-1, -1)


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
	return units.task[i] != Economy.NONE or units.moving[i] == 1 or units.foe[i] != 0 or units.patient[i] != 0 or Walls.busy(self, i)


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
			var ordered := Economy.btype_of(self, o.args.building)
			if b >= 0 and buildings.owner[b] == p and buildings.done[b] == 0 and ordered >= 0 and buildings.kind[b] == Economy.upgraded(self, p, ordered):
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
## `near`: a near field (a short walk, as to a worker's gather spot).
func order_move(i: int, x: int, y: int, arrive: int, group: int, fx := -1, fy := -1, pace := 0, near := false) -> void:
	if units.perch[i] != 0:
		return   # on a wall: it walks the walkway (walls.gd), never the ground
	var ln := lane(i)
	var p := _snap(x, y, ln)
	var cell := map.cell_of(p.x, p.y)
	if fx >= 0:
		var c := _snap(fx, fy, ln)
		cell = map.cell_of(c.x, c.y)
	units.tx[i] = p.x
	units.ty[i] = p.y
	units.reach[i] = 0
	units.fkey[i] = cell_field(cell, near, ln)
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
	if units.perch[i] != 0:
		return   # on a wall: it walks the walkway (walls.gd), never the ground
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


## A group move's formation (milestone 22), centred on the click, facing the way the group goes. The
## group is dealt into bands by role: foot soldiers in the front rows, shooters behind them, engines,
## healers and the harmless (carts, towers) at the back, each band rows as wide as the centre (about
## twice its depth), neighbours the band's biggest body plus FORM_GAP apart (plus the band's
## form_gap, the loosest of its types: a Norse shield wall closes up). Mounted units, shooting or
## not, stand on the flanks: two wings beside the centre, as deep as its front and shooters. With no
## foot beside them they form the centre themselves. Units are dealt slots by where they are now:
## in each band (each wing), the ones furthest ahead take the front rows and, along each row, left
## to right as they stand, so the group closes up without units crossing. A slot that is blocked,
## or that can't be walked to in a straight line from the click, moves half-way in, else onto the
## click. Returns the args with slots (uid -> Vector2i), the group, its centre (fx, fy) and pace
## (slowest speed).
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
	for i in idx:
		sx += units.x[i]
		sy += units.y[i]
		pace = mini(pace, units.speed[i])
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
	var bands := [[], [], []]   # front, shooters, rear
	var flank := []
	for i in idx:
		var role := _form_role(i)
		if role == 3:
			flank.append(i)
		else:
			bands[role].append(i)
	if bands[0].is_empty() and bands[1].is_empty():
		bands[0] = flank   # all riders (and engines): they are the front
		flank = []
	var ahead := {}
	var side := {}
	for i in idx:
		ahead[i] = (units.x[i] - cx) * ux + (units.y[i] - cy) * uy
		side[i] = (units.y[i] - cy) * ux - (units.x[i] - cx) * uy
	var by_ahead := func(p, q): return ahead[p] > ahead[q] or (ahead[p] == ahead[q] and p < q)
	var by_side := func(p, q): return side[p] < side[q] or (side[p] == side[q] and p < q)
	var nc: int = bands[0].size() + bands[1].size() + bands[2].size()
	var cols := clampi(Fixed.isqrt(2 * nc), 1, nc)
	var total := 0      # the centre's depth, front row to back
	var half := 0       # the centre's half width, to its outermost body's edge
	var deep := 0       # the front and shooters' rows: the wings stand beside them
	for k in 3:
		if bands[k].is_empty():
			continue
		var rows: int = (bands[k].size() + cols - 1) / cols
		var sp := _form_space(bands[k])
		total += rows * sp
		half = maxi(half, (mini(cols, bands[k].size()) - 1) * sp / 2 + _form_rmax(bands[k]))
		if k < 2:
			deep += rows
	var put := func(i: int, along: int, across: int) -> void:
		var px := x + (ux * along - uy * across) / Fixed.ONE
		var py := y + (uy * along + ux * across) / Fixed.ONE
		out.slots[units.id[i]] = _slot_ok(i, px, py, x, y)
	var top := total / 2
	for part in bands:
		if part.is_empty():
			continue
		var sp := _form_space(part)
		part.sort_custom(by_ahead)
		for first in range(0, part.size(), cols):
			var line: Array = part.slice(first, first + cols)
			line.sort_custom(by_side)
			var k := line.size()
			for c in k:
				put.call(line[c], top - sp / 2, (2 * c - (k - 1)) * sp / 2)
			top -= sp
	if not flank.is_empty():
		flank.sort_custom(by_side)
		var nl := (flank.size() + 1) / 2
		var sp := _form_space(flank)
		var inner := half + FORM_GAP + _form_rmax(flank)
		for wing in [flank.slice(0, nl), flank.slice(nl)]:
			if wing.is_empty():
				continue
			var left: bool = wing[0] == flank[0]
			var depth := clampi(deep, 1, wing.size())
			var wc: int = (wing.size() + depth - 1) / depth
			wing.sort_custom(by_ahead)
			var along := total / 2 - sp / 2
			for first in range(0, wing.size(), wc):
				var line: Array = wing.slice(first, first + wc)
				line.sort_custom(by_side)
				var k := line.size()
				for c in k:
					put.call(line[c], along, -(inner + (k - 1 - c) * sp) if left else inner + c * sp)
				along -= sp
	if n > 1:
		out.pace = pace
	return out


## Unit i's band in a formation: 0 foot soldiers, 1 shooters, 2 the rear (engines, healers, carts,
## towers), 3 the flanks (mounted).
func _form_role(i: int) -> int:
	var t: Dictionary = types[units.kind[i]]
	var tags: Array = t.eval.tags
	if t.healer or t.harmless or "machine" in tags:
		return 2
	if "mounted" in tags:
		return 3
	return 1 if t.get("ranged", false) else 0


func _form_rmax(part: Array) -> int:
	var r := 0
	for i in part:
		r = maxi(r, units.radius[i])
	return r


## The distance between neighbours in a band: its biggest body plus FORM_GAP plus its loosest
## type's form_gap (0 but for a shield wall's negative one).
func _form_space(part: Array) -> int:
	var g := -(1 << 20)
	for i in part:
		g = maxi(g, int(types[units.kind[i]].form_gap))
	return 2 * _form_rmax(part) + maxi(FORM_GAP + g, 0)


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
	if units.perch[i] != 0:
		return   # on a wall: it walks the walkway (walls.gd), never the ground
	units.tx[i] = x
	units.ty[i] = y
	units.reach[i] = 0
	units.fkey[i] = -1
	units.arrive[i] = 0
	units.group[i] = 0
	_start(i)


## Head for "next to" a rect of milli-tiles (inclusive), following field `key`.
func order_reach(i: int, r: Rect2i, key: int) -> void:
	if units.perch[i] != 0:
		return   # on a wall: it walks the walkway (walls.gd), never the ground
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
	var foes := units.foe
	var mcls := units.mclass
	var t := SimMap.TILE
	var mw := map.width
	var mh := map.height
	var terr := map.terrain
	var trails_on: bool = trail_cfg.speed_pct != 0
	# The tick's start, for _sidestep (the copies above are written as units move; these aren't).
	_ox = units.x
	_oy = units.y
	_om = units.moving
	_ost = units.stuck
	_owx = units.wx
	_owy = units.wy
	_orad = units.radius
	_og = units.group
	_oo = units.owner
	_sstart = spatial.start
	_send = spatial.end
	_sitems = spatial.items
	for i in xs.size():
		if mv[i] == 0:
			# Shoved well off its spot by passing units? Walk back (checked on re-plan ticks).
			# Not while fighting: a stopped shooter's tx is still its (attack-)move's end, and
			# walking "back" there a step every re-plan crept it towards the foe (Dominic's crossbows).
			if grp[i] == 0 or foes[i] != 0 or (tick + ids[i]) % REPLAN_EVERY != 0:
				continue
			var back := ar[i] * SETTLE_FACTOR + (SLOT_SLACK if ar[i] == SLOT_ARRIVE else RETURN_SLACK)
			if Fixed.dist2(xs[i], ys[i], txs[i], tys[i]) <= back * back:
				# Home after all: one that gave up walking back (other groups passing kept shoving it
				# off, as it gives way to them: _separate) and stands by its slot now isn't stuck.
				st[i] = 0
				continue
			if st[i] >= STUCK_LIMIT:
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
		var mci := mcls[i]
		var mc := lane_base[owners[i]] + mci   # the walk grid (lane); speed goes by class
		var here := map.cell_of(x, y)
		var pct: int = move_pct[mci][terr[here]]
		if pct < 100 and types[units.kind[i]].wade > 0:
			pct = 100   # the swamp folk's bonus: no terrain slows them (Tech.retype)
		if not slow_now.is_empty() and slow_now.has(ids[i]):
			pct = pct * int(slow_now[ids[i]]) / 100   # in an enemy web, or hit by sticky silk (abilities.gd)
		if pct != 100:
			s = s * pct / 100   # amphibians are quicker in the swamp (rules.movement.terrain_speed)
		if trails_on and mci != SimMap.FLYING:
			s = s * Trails.speed_pct(self, here) / 100   # quicker on a worn trail (rules.trails, off by default)
		if (tick + ids[i]) % PROGRESS_EVERY == 0 and foes[i] == 0:
			# Net progress, after the pushes: a unit that walks into a planted worker or a wall
			# and is shoved straight back moves every tick but gets nowhere. Measured along the
			# field (its cost falls by a cell per cell walked, detours included), else as the
			# crow flies. No ground gained in two seconds counts as half a give-up.
			var p := _progress(i, x, y)
			if units.prog[i] >= 0 and p.x > units.prog[i] - p.y and grp[i] > 0 and rch[i] == 0 and (_queued(i, x, y) or _passed(i, x, y)):
				pass   # in a queue that's moving (its side walking its way just ahead), or giving way to its side's other groups going through: it waits its turn
			elif units.prog[i] >= 0 and p.x > units.prog[i] - p.y:
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
		if d > rs[i] and foes[i] == 0:   # (a group in formation passes through its own: _sidestep)
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
		var wk: PackedByteArray = map.walks[mc]   # (map.walkable written out: three looks a unit, every tick)
		var ok_xy := nx >= 0 and ny >= 0 and nx / t < mw and ny / t < mh and wk[ny / t * mw + nx / t] == 1
		var ok_x := nx >= 0 and y >= 0 and nx / t < mw and y / t < mh and wk[y / t * mw + nx / t] == 1
		var ok_y := x >= 0 and ny >= 0 and x / t < mw and ny / t < mh and wk[ny / t * mw + x / t] == 1
		if ok_xy and (nx / t == x / t or ny / t == y / t or (ok_x and ok_y)):
			pass   # a step into a diagonal neighbour cell needs both cells beside it open: no slipping between two corners
		elif ok_x:
			ny = y
		elif ok_y:
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
	var none := PackedInt32Array()   # let go of the tick's start (held, they'd cost a copy at the next write)
	_ox = none
	_oy = none
	_om = none
	_ost = none
	_owx = none
	_owy = none
	_orad = none
	_og = none
	_oo = none
	_sstart = none
	_send = none
	_sitems = none


## Is unit i in a moving queue: a unit of its side walking its way (heading within a right angle
## of i's) just ahead of it and gaining ground (not stuck at its last progress look), in the tick's
## start state? Then no ground gained isn't stuck: the tenth
## group through a gap waited longer than the patience (a giant at the back of the queue on
## choke_test gave up). A queue whose head can't go on stops moving, and then the rest give up as before.
func _queued(i: int, x: int, y: int) -> bool:
	var ux := _owx[i] - x
	var uy := _owy[i] - y
	var near := units.arrive[i] * SETTLE_FACTOR + RETURN_SLACK
	if (ux == 0 and uy == 0) or Fixed.dist2(x, y, units.tx[i], units.ty[i]) <= near * near:
		return false   # (arriving: the crowd at its place is no queue; close counts as there, as before)
	var sw := spatial.width
	var cx := x / SimMap.TILE
	var cy := y / SimMap.TILE
	var oi: int = _oo[i]
	var ri: int = _orad[i]
	for yy in range(maxi(cy - 1, 0), mini(cy + 2, spatial.height)):
		for xx in range(maxi(cx - 1, 0), mini(cx + 2, sw)):
			var c := yy * sw + xx
			for k in range(_sstart[c], _send[c]):
				var j: int = _sitems[k]
				if j == i or _om[j] == 0 or _oo[j] != oi or (units.tx[j] == units.tx[i] and units.ty[j] == units.ty[i]):
					continue   # (ones making for the very same point jostle round it: no queue)
				var rx: int = _ox[j] - x
				var ry: int = _oy[j] - y
				var reach: int = ri + _orad[j] + QUEUE_GAP
				if rx * ux + ry * uy <= 0 or rx * rx + ry * ry > reach * reach:
					continue   # behind or beside, or not close
				if _ost[j] == 0 and (_owx[j] - _ox[j]) * ux + (_owy[j] - _oy[j]) * uy > 0:
					return true   # ahead, going our way, and gaining ground at its last look (the queue moves)
	return false


## Is unit i walking back into its formation slot (within RETURN_YIELD) while one of its side's
## other groups walks through it? It gives way to them (_separate), so no ground gained isn't stuck:
## eight groups through a gap shoved a spearman off its slot for longer than the patience, and it
## gave up two tiles from home.
func _passed(i: int, x: int, y: int) -> bool:
	if units.arrive[i] != SLOT_ARRIVE or Fixed.dist2(x, y, units.tx[i], units.ty[i]) > RETURN_YIELD * RETURN_YIELD:
		return false
	var sw := spatial.width
	var cx := x / SimMap.TILE
	var cy := y / SimMap.TILE
	var oi: int = _oo[i]
	var gi: int = _og[i]
	var ri: int = _orad[i]
	for yy in range(maxi(cy - 1, 0), mini(cy + 2, spatial.height)):
		for xx in range(maxi(cx - 1, 0), mini(cx + 2, sw)):
			var c := yy * sw + xx
			for k in range(_sstart[c], _send[c]):
				var j: int = _sitems[k]
				if j == i or _om[j] == 0 or _oo[j] != oi or _og[j] == gi or _og[j] == 0:
					continue
				var reach: int = ri + _orad[j] + QUEUE_GAP
				if Fixed.dist2(_ox[j], _oy[j], x, y) <= reach * reach:
					return true
	return false


## Local avoidance (Dominic, 2026-10-13: "scavengers getting stuck on each other too easily"):
## a unit heading (ux, uy) (scaled by Fixed.ONE) with a standing body just ahead in its way
## steps half aside, round the side the body isn't on; a walker of its side coming the other
## way it passes keeping to the right (nose to nose they stalled, worst along a cliff or a
## wall). Walkers going its way are left to separation, which slides them past each other.
## A unit in a group move passes its own group (they part for it) and dodges only its own
## side (enemies are met, not dodged): another group already standing in its formation across
## a narrow way (the plateau on hill_test) was a wall it shoved at until it gave up three
## tiles short. Positions and waypoints are the tick's start (_move writes its own copies), so
## the order units move in doesn't matter. (0, 0): nothing in the way.
func _sidestep(i: int, x: int, y: int, ux: int, uy: int, s: int) -> Vector2i:
	var ox := _ox   # the tick's start: _move writes its own copy
	var oy := _oy
	var om := _om
	var orad := _orad
	var start := _sstart
	var ends := _send
	var items := _sitems
	var sw := spatial.width
	var cx := x / SimMap.TILE
	var cy := y / SimMap.TILE
	var best := -1
	var best_ahead := 1 << 30
	var best_side := 0
	var ri := orad[i]
	var og := _og
	var gi: int = og[i]
	var oo := _oo
	var oi: int = oo[i]
	var wxs := _owx   # where walkers are heading
	var wys := _owy
	# Only the cells ahead: heading well east (or west, north, south), the column (row) behind
	# seldom holds a body in the way, and skipping it saves a third of the looking.
	var x0 := cx if ux > Fixed.ONE / 2 else cx - 1
	var x1 := cx if ux < -Fixed.ONE / 2 else cx + 1
	var y0 := cy if uy > Fixed.ONE / 2 else cy - 1
	var y1 := cy if uy < -Fixed.ONE / 2 else cy + 1
	for yy in range(maxi(y0, 0), mini(y1 + 1, spatial.height)):
		for xx in range(maxi(x0, 0), mini(x1 + 1, sw)):
			var c := yy * sw + xx
			for k in range(start[c], ends[c]):
				var j: int = items[k]
				if j == i or (gi > 0 and (og[j] == gi or oo[j] != oi)):
					continue   # groupmates part for each other; a group's units dodge only their own side
				var head_on := false
				if om[j] == 1:
					if oo[j] != oi:
						continue
					# A walker going our way is left to separation (it slides past); one coming at us
					# is passed keeping to the right, both of us (shoved nose to nose they stalled,
					# worst along a cliff or a wall, where separation can't slide them apart).
					if (wxs[j] - ox[j]) * ux + (wys[j] - oy[j]) * uy >= 0:
						continue
					head_on = true
				var rx: int = ox[j] - x
				var ry: int = oy[j] - y
				var rr: int = ri + orad[j]
				var ahead := (rx * ux + ry * uy) / Fixed.ONE
				if ahead <= 0 or ahead > rr + (4 if head_on else 2) * s or ahead >= best_ahead:
					continue
				var side := (rx * uy - ry * ux) / Fixed.ONE   # > 0: j is on our left
				if side >= rr or side <= -rr:
					continue
				if head_on:
					side = 1   # aside to the right, whichever side it's on
				elif side == 0:
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
			return _drop_spot(i, x, y) if units.task[i] == Economy.RETURN and units.gspot[i] >= 0 else _spot(i, x, y)
	elif cost == 0 or (cost <= DIRECT_COST and units.stuck[i] < STUCK_LIMIT / 2 and Flow.clear_path(map, x, y, tx, ty, units.radius[i], lane(i))):
		return Vector2i(tx, ty)
	elif units.reach[i] == 2 and cost <= 4 * Flow.STRAIGHT:
		var c := _round_corner(i, x, y, tx, ty)   # its place is round the far side of the building
		if c.x >= 0:
			return c
	# Half-way to giving up, follow the field a cell at a time (the retry): no shortcuts.
	var best := Flow.ahead(map, f, cell, x, y, 1 if units.stuck[i] >= STUCK_LIMIT / 2 else LOOKAHEAD, units.radius[i], lane(i))
	if best < 0:
		if units.reach[i] == 0:
			return Vector2i(tx, ty)   # the next cell is the target's
		best = -2 - best
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
			for k in range(spatial.start[c], spatial.end[c]):
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


## Where a worker carrying home (task RETURN) makes for round its drop-off: the point of the ring a
## body's width out from the rect nearest what it gathers (its home tile, else itself), moved round
## the ring by a lane of its own (by id), so a stream of carriers from one bush spreads along the
## wall instead of meeting at one corner. They drop off on coming in reach and walk on (nobody stops
## there); a lane that's blocked or not straight ahead falls back to _spot.
func _drop_spot(i: int, x: int, y: int) -> Vector2i:
	var r := units.radius[i]
	var o := r + SPOT_GAP
	var x0 := units.rx0[i] - o
	var y0 := units.ry0[i] - o
	var x1 := units.rx1[i] + o
	var y1 := units.ry1[i] + o
	var ax := x
	var ay := y
	if units.home[i] >= 0:
		ax = (units.home[i] % map.width) * SimMap.TILE + SimMap.TILE / 2
		ay = (units.home[i] / map.width) * SimMap.TILE + SimMap.TILE / 2
	var px := clampi(ax, x0, x1)
	var py := clampi(ay, y0, y1)
	if px > x0 and px < x1 and py > y0 and py < y1:   # inside the ring: out to its nearest side
		var d := mini(mini(px - x0, x1 - px), mini(py - y0, y1 - py))
		if d == px - x0:
			px = x0
		elif d == x1 - px:
			px = x1
		elif d == py - y0:
			py = y0
		else:
			py = y1
	# Round the ring clockwise from its top-left corner: top, right, bottom, left.
	var wd := x1 - x0
	var ht := y1 - y0
	var perim := 2 * (wd + ht)
	var along := 0
	if py == y0:
		along = px - x0
	elif px == x1:
		along = wd + py - y0
	elif py == y1:
		along = wd + ht + x1 - px
	else:
		along = 2 * wd + ht + y1 - py
	along = posmod(along + (units.id[i] * 7 % 5 - 2) * r / 2, perim)
	var p: Vector2i
	if along < wd:
		p = Vector2i(x0 + along, y0)
	elif along < wd + ht:
		p = Vector2i(x1, y0 + along - wd)
	elif along < 2 * wd + ht:
		p = Vector2i(x1 - (along - wd - ht), y1)
	else:
		p = Vector2i(x0, y1 - (along - 2 * wd - ht))
	# Off a corner the ring is out of reach: in along the diagonal until it isn't.
	var c := (r + Economy.REACH - 50) * 707 / 1000
	if (p.x < units.rx0[i] or p.x > units.rx1[i]) and (p.y < units.ry0[i] or p.y > units.ry1[i]):
		p = Vector2i(clampi(p.x, units.rx0[i] - c, units.rx1[i] + c), clampi(p.y, units.ry0[i] - c, units.ry1[i] + c))
	var ln := lane(i)
	if not map.walkable(p.x, p.y, ln) or not Flow.clear_path(map, x, y, p.x, p.y, r, ln):
		return _spot(i, x, y)
	return p


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


## The map changed this tick (a building placed, a resource used up, a tree felled, a bridge
## rebuilt): patch the cached fields the change touches instead of dropping them (Flow.patch_closed
## and patch_opened: the costs come out as a fresh solve's), newest first while this tick's patch
## budget lasts (each patch gets at most a quarter of the map's cells); past it, or where a
## source cell itself changed, the field is dropped (units
## re-request it and _solve_queued spreads the solves over ticks). Only lanes whose walk grid
## really changed at a cell count: a building shuts nothing for flyers, a team's gate nothing for
## that team. Compares each cell's walk values before the tick's first change with now.
func _sync_map() -> void:
	if map.fresh.is_empty():
		return
	var cells: Array = map.fresh_was.keys()
	cells.sort()
	var opened := {}   # lane -> Array of cells, ascending
	var closed := {}
	for c in cells:
		var was: PackedByteArray = map.fresh_was[c]
		for k in mini(was.size(), map.walks.size()):   # (a lane made this tick has no fields yet)
			var now: int = map.walks[k][c]
			if now == was[k]:
				continue
			var into: Dictionary = opened if now == 1 else closed
			if not into.has(k):
				into[k] = []
			into[k].append(c)
	var budget := PATCH_BUDGET
	var keep := []
	for n in range(field_order.size() - 1, -1, -1):
		var key: int = field_order[n]
		var f = fields[key]
		var ln := key % LANES
		var op := PackedInt32Array()
		var cl := PackedInt32Array()
		var stale := false
		for c in opened.get(ln, []):
			if f.touches(map, c):
				stale = stale or c in f.sources
				op.append(c)
		for c in closed.get(ln, []):
			if f.touches(map, c):
				stale = stale or c in f.sources
				cl.append(c)
		if not stale and not (op.is_empty() and cl.is_empty()):
			# A patch past its share is given up (the field dropped): a big one costs more than a solve.
			var limit := mini(budget, map.width * map.height / 4)
			stale = limit <= 0
			if not stale and not cl.is_empty():
				var spent: int = f.patch_closed(map, cl, ln, limit)
				stale = spent < 0
				budget -= limit if stale else spent
				limit = mini(budget, limit - maxi(spent, 0))
			if not stale and not op.is_empty():
				stale = limit <= 0
				if not stale:
					var spent: int = f.patch_opened(map, op, ln, limit)
					stale = spent < 0
					budget -= limit if stale else spent
		if stale:
			fields.erase(key)
		else:
			keep.append(key)
	keep.reverse()
	field_order = keep
	map.fresh.clear()
	map.fresh_closed.clear()
	map.fresh_was.clear()


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
	var ends := spatial.end
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
	var rch := units.reach
	# Who gives way to one of its side's other groups walking through: a unit standing in its
	# formation slot, and one walking the last stretch back into it (shoved off by a passer, it
	# walked straight back into the passer's way: two big riders, a returner and a passer, shoved
	# nose to nose for ten seconds until the passer gave up, five tiles short; test_sim crossings).
	var yields := PackedByteArray()
	yields.resize(n)
	var foes0 := units.foe
	for i in n:
		if grp[i] > 0 and ar[i] == SLOT_ARRIVE and rch[i] == 0:
			if mv[i] == 0:
				stood[i] = 1
				yields[i] = 1
			elif foes0[i] == 0 and Fixed.dist2(xs[i], ys[i], txs[i], tys[i]) <= RETURN_YIELD * RETURN_YIELD:
				yields[i] = 1
	var tasks := units.task
	var foes := units.foe
	var owners := units.owner
	var gsp := units.gspot
	var role := PackedByteArray()   # 1: standing idle (gives way), 2: walking to or from a job, 3: one passing through (below)
	role.resize(n)
	for i in n:
		if mv[i] == 0 and tasks[i] == Economy.NONE and foes[i] == 0 and stood[i] == 0:
			role[i] = 1
		elif mv[i] == 1 and gsp[i] >= 0 and (tasks[i] == Economy.GATHER or tasks[i] == Economy.RETURN):
			role[i] = 3   # making for its own gather spot, or carrying home from it: it won't stop in the crowd
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
	# Each pair once: a unit's own tile (slots after it) and the four tiles after it (right, and
	# the row below), so every pair of neighbouring tiles is looked at from one side only. The
	# pair's sums don't depend on which side found it (i is the lower slot, as before).
	var pr := units.perch   # units on walls stand apart from the crowd below (walls.gd)
	for u in n:
		if pr[u] != 0:
			continue
		var cx := cells[u] % w
		var cy := cells[u] / w
		var xu := xs[u]
		var yu := ys[u]
		var ru := rs[u]
		for q in 5:
			var nx: int = cx + SEP_DX[q]
			var ny: int = cy + SEP_DY[q]
			if nx < 0 or nx >= w or ny >= h:
				continue
			var c := ny * w + nx
			for k in range(start[c], ends[c]):
				var v := items[k]
				if (q == 0 and v <= u) or pr[v] != 0:
					continue
				var rr := ru + rs[v]
				var dx := xs[v] - xu
				var dy := ys[v] - yu
				if dx >= rr or dx <= -rr or dy >= rr or dy <= -rr:
					continue
				var d2 := dx * dx + dy * dy
				if d2 >= rr * rr:
					continue
				var i := u
				var j := v
				if v < u:
					i = v
					j = u
					dx = -dx
					dy = -dy
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
				if owners[i] == owners[j] and grp[i] != grp[j] and ((stood[i] == 1 and yields[j] == 1 and mv[j] == 1) or (stood[j] == 1 and yields[i] == 1 and mv[i] == 1)):
					continue   # ...nor between one in its slot and one of the other group walking back into its own (they knocked each other off overlapping slots for good: test_sim's choke crossing with an eleventh group)
				# A worker on its way to or from a job walks on; anyone standing idle in its way gives way.
				# So does a unit standing in its formation for one of its side's other groups walking
				# through (it walks back to its slot after): two groups' formations filling a narrow way
				# (the plateau on hill_test) made a wall the later group shoved at until it gave up.
				var hi := planted[i] == 1 or (role[i] >= 2 and role[j] == 1) \
						or (yields[j] == 1 and mv[i] == 1 and grp[i] > 0 and grp[i] != grp[j] and owners[i] == owners[j])
				var hj := planted[j] == 1 or (role[j] >= 2 and role[i] == 1) \
						or (yields[i] == 1 and mv[j] == 1 and grp[j] > 0 and grp[j] != grp[i] and owners[i] == owners[j])
				if hi and hj:
					continue
				# One of the side's own at work and a gatherer making for its spot or carrying home
				# from it (role 3: it won't stop here): the walker slips past (stepping round standing
				# bodies as it comes, _sidestep), overlapping for a moment at most. (Workers without
				# spots, woodcutters, are still shoved: let through, they stacked up in the woodlines.) Shoved off a gatherer's back it bounced to and fro (the jitter round
				# the bushes and the drop-off); easing it round at half the give was worse still
				# (hunters gave up on their carcass, a quarter less food).
				if owners[i] == owners[j] and ((planted[i] == 1 and role[j] == 3) or (planted[j] == 1 and role[i] == 3)):
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
	var mw := map.width
	var mh := map.height
	var mcls := units.mclass
	for i in n:
		if settle[i] == 1:
			mv[i] = 0
		if pr[i] != 0:
			continue
		var mc := lane_base[owners[i]] + mcls[i]
		var wk: PackedByteArray = map.walks[mc]
		var x0 := xs[i]
		var y0 := ys[i]
		if x0 < 0 or y0 < 0 or x0 / t >= mw or y0 / t >= mh or wk[y0 / t * mw + x0 / t] == 0:   # (map.walkable, inline)
			# Its centre is on blocked ground (a foundation laid on it, or a spawn): step out
			# to the nearest open neighbour's edge, the least move that makes it walkable;
			# with no open neighbour (deep in a footprint) the nearest open cell, outright.
			var p := _step_out(xs[i], ys[i], mc)
			xs[i] = p.x
			ys[i] = p.y
			continue
		if pushx[i] != 0:
			var nx := x0 + pushx[i]
			if nx >= 0 and nx / t < mw and wk[y0 / t * mw + nx / t] == 1:
				xs[i] = nx
		if pushy[i] != 0:
			var ny := y0 + pushy[i]
			if ny >= 0 and ny / t < mh and wk[ny / t * mw + xs[i] / t] == 1:
				ys[i] = ny
		# Keep the body (not just the centre) off blocked neighbour tiles, easing it off by at
		# most CORRECT_MAX a tick: a shove into a wall slides back out, never pops a tile.
		var cx := xs[i] / t
		var cy := ys[i] / t
		var r := rs[i]
		var c := cy * mw + cx
		if xs[i] - cx * t < r and (cx == 0 or wk[c - 1] == 0):
			xs[i] = mini(cx * t + r, xs[i] + CORRECT_MAX)
		elif (cx + 1) * t - xs[i] < r and (cx + 1 >= mw or wk[c + 1] == 0):
			xs[i] = maxi((cx + 1) * t - r, xs[i] - CORRECT_MAX)
		if ys[i] - cy * t < r and (cy == 0 or wk[c - mw] == 0):
			ys[i] = mini(cy * t + r, ys[i] + CORRECT_MAX)
		elif (cy + 1) * t - ys[i] < r and (cy + 1 >= mh or wk[c + mw] == 0):
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


## A save from before stone walls stopped flyers (D-158): the walls standing in it block them now.
func after_load(_missing: Array) -> void:
	for b in buildings.count():
		if btypes[buildings.kind[b]].get("blocks_flyers", false):   # (get: a save that keeps its own tables has none)
			for c in buildings.footprint(b, map.width):
				if map.high[c] == 0:
					map.high[c] = 1
					map._refresh(c)


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
	h = Abilities.hash_into(self, h)
	h = Heroes.hash_into(self, h)
	h = Walls.hash_into(self, h)
	h = Fixed.mix(h, shots.count())
	for v in shots.data:
		h = Fixed.mix(h, v)
	var worn := 0
	for c in wear.size():
		worn += wear[c] * (c % 251 + 1)
	h = Fixed.mix(h, worn)
	var u := units
	for i in u.count():
		for v in [u.id[i], u.owner[i], u.kind[i], u.x[i], u.y[i], u.tx[i], u.ty[i], u.moving[i],
				u.arrive[i], u.wx[i], u.wy[i], u.group[i], u.stuck[i], u.prog[i], u.hp[i], u.fkey[i], u.reach[i],
				u.task[i], u.target[i], u.home[i], u.gspot[i], u.carry_kind[i], u.carry[i], u.work[i],
				u.foe[i], u.cooldown[i], u.stance[i], u.posture[i], u.gx[i], u.gy[i], u.amx[i], u.amy[i], u.orders[i].size(), u.mclass[i], u.patient[i], u.pace[i], u.amc[i], u.route[i], u.ready[i]]:
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
		h = Fixed.mix(h, b.inside[i].size())
		for rec in b.inside[i]:   # those sheltering inside (garrison.gd)
			for v in rec:
				h = Fixed.mix(h, v)
	return h
