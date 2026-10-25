// ------------------------------------------------------------------ state
// The World's arrays (world.gd, units.gd, sim_map.gd), as globals. Units are parallel int columns
// in slot order (ascending id); unit_columns() lists them for removal.

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

def unit_columns() -> [[int]]:
    return [u_id, u_owner, u_kind, u_x, u_y, u_tx, u_ty, u_moving, u_arrive, u_wx, u_wy, u_group, u_stuck,
            u_prog, u_fkey, u_speed, u_radius, u_mclass, u_pace, u_hp, u_foe, u_cooldown, u_stance, u_posture,
            u_gx, u_gy, u_amx, u_amy, u_amc]

def remove_unit(i:int):
    for(unit_columns()) col: col.remove(i)

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
