// ------------------------------------------------------------------ state
// The World's arrays (world.gd, units.gd, sim_map.gd), as globals. Units are parallel int columns
// in slot order (ascending id); unit_columns() lists them for removal.

// A command (commands.gd): the tick it runs, its code (CMD_* in consts), the player, four ints and the
// unit ids. Shift-queued copies in a unit's queue (units.orders) keep their formation slot.
class Cmd:
    run_tick:int
    code:int
    player:int
    a:int
    b:int
    c:int
    d:int
    ids:[int]
    seq:int
    queue = 0       // 1: shift-queued
    slotted = 0     // 1: a queued MOVE / ATTACK_MOVE's copy, with its own slot and the group's
    sx = 0
    sy = 0
    group = 0
    fx = 0
    fy = 0
    pace = 0

var extras = dictionary<string, [int]>(64)   // the scenario's EXTRA section

// Map (sim_map.gd): walk grids per lane, terrain speed percent per movement class and cell.
var W = 0
var H = 0
var walks = []::[int]
var roomy = []::[int]          // per lane: 1 where the cell and its 8 neighbours are on the map and walkable
var tight = []::[int]          // per lane: cells not roomy per ROOM_CHUNK block
var room_cw = 0
var speed_pct = []::[int]
var opaque = []::int           // 1 where a cell blocks sight (trees)
var level = []::int            // ground level per cell
var num_players = 0
var lane_base = []::int        // per player
var teams = []::int            // per player
var lost = []::int             // per player: units killed so far

// Host rules the port reads (rules.combat, rules.high_ground, rules.fog).
var r_min_damage = 0
var r_acquire_every = 0
var r_defend_sight = 0
var r_counter_pull = 0
var r_leash = 0
var r_sight = 0
var r_shot_lead_pct = 0
var r_shot_strays = 0
var r_shot_slack = 0
var r_high_reach = 0
var r_uphill_pct = 0
var r_high_sight_unit = 0      // rules.high_ground.sight_unit: tiles more sight a level up
var has_heights = 0            // the map has hills
var r_fog_every = 0
var r_fog_unit = 0
var r_fog_worker = 0

// Unit types (World._make_type, Combat.type_vectors). Vectors are per armour class.
var num_classes = 0
var t_speed = []::int
var t_radius = []::int
var t_role = []::int           // formation band (World._form_role)
var t_gap = []::int            // form_gap
var t_worker = []::int
var t_harmless = []::int
var t_healer = []::int
var t_ranged = []::int
var t_reach = []::int
var t_reload = []::int
var t_shot_speed = []::int
var t_min_damage = []::int
var t_sight = []::int          // the line's own sight plus research
var t_mclass = []::int
var t_atk = []::[int]
var t_arm = []::[int]
var t_cls = []::[int]
var t_counters = []::[int]     // classes past the base three it has a bonus against

// Units (units.gd), slots sorted by id. reach, task, perch, patient, gspot are constant here.
var unit_changes = 0       // bumped on every unit added, put back or removed (units.changes)
var u_id = []::int
var u_owner = []::int
var u_kind = []::int
var u_x = []::int
var u_y = []::int
var u_tx = []::int
var u_ty = []::int
var u_moving = []::int
var u_arrive = []::int
var u_wx = []::int
var u_wy = []::int
var u_group = []::int
var u_stuck = []::int
var u_prog = []::int
var u_fkey = []::int
var u_speed = []::int
var u_radius = []::int
var u_mclass = []::int
var u_pace = []::int
var u_hp = []::int
var u_foe = []::int
var u_cooldown = []::int
var u_stance = []::int         // Combat NONE / ORDERED / AUTO / ATTACK_MOVE / RETURN
var u_posture = []::int        // Combat AGGRESSIVE / DEFENSIVE / STAND / PASSIVE
var u_gx = []::int
var u_gy = []::int
var u_amx = []::int
var u_amy = []::int
var u_amc = []::int
var u_task = []::int           // Economy NONE / GATHER / RETURN / BUILD
var u_target = []::int         // resource cell (GATHER) or building id (RETURN, BUILD)
var u_home = []::int           // resource cell to go back to after a drop-off, or -1
var u_gspot = []::int          // its standing spot round `home`, or -1
var u_carry_kind = []::int     // resource index + 1, or 0
var u_carry = []::int
var u_work = []::int           // ticks into the current gather (or build, or wait)
var u_reach = []::int          // 0: arrive at (tx, ty); 1: next to the rect below; 2: (tx, ty), its place beside the rect
var u_rx0 = []::int
var u_ry0 = []::int
var u_rx1 = []::int
var u_ry1 = []::int
var u_patient = []::int        // healers: the unit id being healed (or walked to), or 0
var u_route = []::int          // trade carts: the home market's id (target: the far one), or 0
var u_ready = []::int          // packing engines: ticks stood unpacking, or below 0 while packing up (World._pack)
var u_perch = []::int          // walls you stand on (walls.gd), cells + 1: the walkway cell it stands on (0: the ground)
var u_wgoal = []::int          // on a wall: the cell it walks to + 1; climbing: where it goes once up
var u_wnext = []::int          // on a wall: the next cell on its way + 1
var u_wexit = []::int          // on a wall: the way down it is leaving by (a building or siege tower id), or 0
var u_wtime = []::int          // on a wall: ticks left climbing down, or 0
var u_orders = []::[Cmd]       // per unit: shift-queued orders, oldest first (units.orders)

// The columns in unit_fields order (the hash, the scenario file), then the rest.
def unit_columns() -> [[int]]:
    return [u_id, u_x, u_y, u_tx, u_ty, u_moving, u_arrive, u_wx, u_wy, u_group, u_stuck, u_prog, u_fkey, u_pace,
            u_hp, u_foe, u_cooldown, u_stance, u_posture, u_gx, u_gy, u_amx, u_amy, u_amc,
            u_task, u_target, u_home, u_gspot, u_carry_kind, u_carry, u_work, u_reach, u_rx0, u_ry0, u_rx1, u_ry1, u_patient,
            u_route, u_ready, u_perch, u_wgoal, u_wnext, u_wexit, u_wtime,
            u_owner, u_kind, u_speed, u_radius, u_mclass]

let UNIT_HASHED = 44           // the columns hashed (unit_fields)
var t_tags = []::[int]         // per unit type: its eval's tags (class indexes), as its line stands
var t_damage = []::int         // per unit type: its attack's class (0 melee, 1 pierce, ...)

// This tick's events (World.events), for the bots: hits, deaths, shots. Not state.
let EV_HIT = 0                 // a: by, b: to, c: damage
let EV_DIE = 1                 // a: id, b: 1 for a building
let EV_SHOT = 2                // a: by, b: to
class Event:
    kind:int
    a:int
    b:int
    c:int
    x:int
    y:int
var events = []::Event
var events_on = false          // only the bots read them

let REC_ID = 0                 // a sheltering unit's record (garrison.gd)
let REC_KIND = 1
let REC_HP = 2
let REC_POSTURE = 3
let REC_CARRY_KIND = 4
let REC_CARRY = 5
let REC_HOME = 6
let REC_SIZE = 7

// Unit types' economy (World._make_type): pop, train time, cost vector, research and bonuses.
var t_pop = []::int
var t_train_ticks = []::int
var t_hp = []::int
var t_posture = []::int
var t_carry_add = []::int
var t_build_pct = []::int
var t_player = []::int
var t_age = []::int
var t_cost = []::[int]

// Buildings (buildings.gd), slots sorted by id; ids shared with units.
var b_id = []::int
var b_owner = []::int
var b_kind = []::int
var b_cx = []::int
var b_cy = []::int
var b_sx = []::int
var b_sy = []::int
var b_hp = []::int
var b_progress = []::int
var b_done = []::int
var b_train = []::int
var b_rally_x = []::int
var b_rally_y = []::int
var b_cooldown = []::int       // shooting buildings: ticks until the next volley
var b_queue = []::[int]        // unit type indexes, head first
var b_inside = []::[int]       // units sheltering inside (garrison.gd): REC_SIZE ints each, by id

def building_columns() -> [[int]]:
    return [b_id, b_owner, b_kind, b_cx, b_cy, b_sx, b_sy, b_hp, b_progress, b_done, b_train, b_rally_x, b_rally_y, b_cooldown]

// Shooting buildings and garrisons, per building type (buildings.json attack, garrison).
var bt_attacks = []::int       // 1 if it has an attack
var bt_atk_class = []::int
var bt_atk = []::int
var bt_range = []::int         // tiles
var bt_reload = []::int
var bt_arrows = []::int        // its own arrows (one more per unit inside)
var bt_garrison = []::int      // how many it holds
var bt_gate = []::int
var bt_wall = []::int          // a wall piece (`line`)
var bt_over_trees = []::int    // sees over trees (fog)
var r_fog_tower = 0
var r_garrison_heal_every = 0
var r_call_range = 0
var garrison_not = []::int     // tags (classes) that don't fit in a building (workers always do)

// Heroes (heroes.gd) and the match (match.gd).
var hero_types = []::int       // the unit types that are heroes, in order
var hero_id = []::int          // per hero type (alongside hero_types): its living hero's id, 0 with none
var hero_fell = []::int        // ... the tick + 1 it last fell, 0 if never
var r_aura = 0                 // milli-tiles
var r_regen = 0
var r_revive = 0
var r_revive_pct = 0
var winner = -1
var defeated = []::int
var started_with_town = []::int

// Building types (Economy.load_btypes), and per player what research and the race make of them.
var bt_size = []::int
var bt_build_ticks = []::int
var bt_pop = []::int
var bt_sight = []::int
var bt_age = []::int
var bt_more_from_age = []::int
var bt_water = []::int
var bt_line = []::int
var bt_tower = []::int
var bt_farm = []::int
var bt_land = []::int          // a farm: the terrain it becomes on land, in water
var bt_wet = []::int
var bt_workers = []::int       // a farm: how many work it at once
var bt_special = []::int       // pens, gates, ladders, walls you stand on: not in the spike
var bt_drop = []::[int]        // per resource: 1 if it takes it in
var bt_reseed = []::[int]
var bm_hp = []::[int]          // [player][type]
var bm_pop = []::[int]
var bm_sight = []::[int]
var bm_food = []::[int]        // a farm's food when sown (Economy.farm_food)
var bm_lacks = []::[int]
var bm_trains = []::[[int]]    // [player][type]: the unit types it trains
var bm_cost = []::[[int]]      // [player][type]: Economy.bcost

var bt_name = []::string
var bt_cost = []::[int]        // the price as listed (the bots check it for farms)
var map_version = 0            // bumped on every cell change (SimMap.version; the bots' reach relabels)

// Players' economy.
var num_resources = 0
var gather_spots = []::int     // per resource: 1 spots all round, 2 the four sides, 0 anywhere in reach
var ages = []::int
var auto_reseed = []::int
var pop = []::int
var pop_cap = []::int
var stock = []::[int]          // [resource][player]
var gathered = []::[int]
var gather_ticks = []::[int]   // [player][resource]
var next_id = 0
var r_carry = 0
var r_queue_max = 0
var r_pop_max = 0
var r_fog_building = 0
var r_high_sight_building = 0

def remove_unit(i:int):
    unit_changes++
    for(unit_columns()) col: col.remove(i)
    u_orders.remove(i)

var tick = 0
var next_group = 1

// Shots in flight (shots.gd): SHOT_STRIDE ints a shot, in loosing order.
var shots = []::int

// Fog (fog.gd): per player, a byte per cell (0 unseen, 1 explored, 2 visible), and the cells lit
// at its last update.
var fog = []::[int]
var fog_lit = []::[int]

// The tick's start, for _sidestep / _queued / _passed (World._move's _ox ...: in GDScript the live arrays).
var o_x = []::int
var o_y = []::int
var o_moving = []::int
var o_stuck = []::int
var o_wx = []::int
var o_wy = []::int

// Spatial buckets (spatial.gd): bucket c holds sp_items[sp_start[c] .. sp_end[c] - 1], slots ascending.
var sp_start = []::int
var sp_end = []::int
var sp_items = []::int
var sp_cell = []::int
var sp_cursor = []::int

// Formation scratch: each unit's slot, how far ahead / aside it stands.
var slot_x = []::int
var slot_y = []::int
var f_ahead = []::int
var f_side = []::int

// Separation scratch.
var s_pushx = []::int
var s_pushy = []::int
var s_settle = []::int
var s_stood = []::int
var s_yields = []::int
var s_role = []::int
var s_planted = []::int
def remove_building(b:int):
    for(building_columns()) col: col.remove(b)
    b_queue.remove(b)
    b_inside.remove(b)

// A unit back in the arrays under an id it had before (out of a building), in its place by id
// (Units.insert, with units.gd _put's defaults). Its slot.
def insert_unit(uid:int, owner:int, k:int, x:int, y:int, speed:int, radius:int, hp:int) -> int:
    let found, at = binary_search(u_id, uid)
    assert not found
    let v = [uid, x, y, x, y, 0, 0, x, y, 0, 0, -1, -1, 0,
             hp, 0, 0, 0, 0, x, y, 0, 0, -1,
             0, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0,
             owner, k, speed, radius, 0]
    unit_changes++
    for(unit_columns()) col, n: col.insert(at, v[n])
    u_orders.insert(at, [])
    return at

var t_hero = []::int           // per unit type: 1 for a hero
var t_heal = []::int           // per unit type: its eval's heal (0: not a healer's)
var fog_seen = []::[[int]]     // per player: enemy buildings remembered as last seen (fog.lobster remember)
var t_eval_attack = []::int     // per unit type: its eval attack with research (the counter-pick)
var t_bonus = []::[int]         // per unit type: its eval bonus vector with research
var t_slot = []::string         // per unit type: its roster slot
var t_trader = []::int
var resource_names = []::string
var tr_names = []::string
var start_x = []::int           // the map starts, milli-tiles
var start_y = []::int
var slot_names = []::string
var slots_lacked = []::[int]    // per player: slot indexes (slot_names) its race lacks
var trade_lacked = []::int

def slot_index(slot:string) -> int:
    for(slot_names) s, k:
        if s == slot: return k
    return -1

// Animals (animals.gd) and the rest of the types' flags, declared here: combat reads them.
let B_NONE = 0
let B_FLEE = 1
let B_FIGHT = 2
let B_HERD = 3
var gaia = -1
var claim_tiles = 4
var t_behave = []::int         // per unit type: B_NONE / FLEE / FIGHT / HERD
var t_flee = []::int           // per unit type: milli-tiles it bolts
var t_food = []::int           // per unit type: the carcass's food
var bt_pen_animals = []::int   // per building type (0: not a pen)
var bt_pen_food = []::int
var bt_pen_food_ticks = []::int
var bt_pen_breed_ticks = []::int
var herd_spots = dictionary<int, [int]>(16)   // Town Center id -> [x, y], chosen once
var t_no_heal = []::int
var t_animal = []::int

// Map bridges (bridges.gd): per bridge its id, deck cells, rect (milli-tiles, inclusive), state.
var br_id = []::int
var br_cells = []::[int]
var br_x0 = []::int
var br_y0 = []::int
var br_x1 = []::int
var br_y1 = []::int
var br_hp = []::int
var br_up = []::int
var br_work = []::int
var br_payer = []::int
var br_full_hp = 0
var br_ticks = 1
var br_cost = []::int
var br_arm = []::int
