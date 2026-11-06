// ------------------------------------------------------------------ constants

let TILE = 1000
let ONE = 1024
let MASK = 0xFFFFFFFF
let FNV_PRIME = 0x01000193
let FNV_START = 0x811C9DC5
let INF = 1 << 30
let STRAIGHT = 10
let DIAGONAL = 14
let RING = 15
let LINE_STEP = 333
let ROOM_CHUNK = 2

let TICKS_PER_TURN = 4
let ARRIVE_SETTLE = 4  // SETTLE_FACTOR
let SEPARATION_DIV = 4
let REPLAN_EVERY = 8
let LOOKAHEAD = 6
let DIRECT_COST = 160
let STUCK_LIMIT = 60
let PROGRESS_EVERY = 40
let CORRECT_MAX = 150
let RETURN_SLACK = 1000
let FIELD_CACHE = 24
let SOLVE_BUDGET = 1500
let LANES = 32
let FORM_GAP = 160
let SLOT_ARRIVE = 60
let BLOCK_FROM = 40   // an order for this many units marches in blocks
let BLOCK_MAX = 49    // units a block at most
let BLOCK_GAP = 1200  // milli-tiles between blocks
let BLOCK_FORMING = 1
let BLOCK_MARCHING = 2
let BLOCK_THERE = 3
let BLOCK_FORM_TICKS = 3000  // they march after this long at most, formed or not
let BLOCK_LEASH = 2000       // milli-tiles past its reach a block's unit goes for a foe
let BLOCK_FOE_NEAR = 40000   // milli-tiles: an enemy this near, and a big order is one formation, no blocks
let SLOT_SLACK = 400
let QUEUE_GAP = 300
let RETURN_YIELD = 2000
let STRAIGHT_PER_CHECK = 10
let FIELD_CELL = 0
let FIELD_CELL_NEAR = 1
let FIELD_BUILDING_NEAR = 2
let SEP_DX = [ 0, 1, -1, 0, 1 ]
let SEP_DY = [ 0, 0, 1, 1, 1 ]
let KEY_BITS = 21  // slot bits in a formation sort key

// combat.gd: units.stance (what it is doing) and units.posture (the player's stance).
let NONE = 0
let ORDERED = 1
let AUTO = 2
let ATTACK_MOVE = 3
let RETURN = 4
let AGGRESSIVE = 0
let DEFENSIVE = 1
let STAND = 2
let PASSIVE = 3
let SPREAD = 1500
let CROWDED = 2
let HOLD = 120

// economy.gd: units.task, and the gatherers' ways.
let T_NONE = 0
let GATHER = 1
let T_RETURN = 2
let BUILD = 3
let REACH = 250  // milli-tiles between a body's edge and what it works on
let SEARCH_TILES = 8
let SPREAD_TILES = 2
let BUSY_COST = 4000000
let GIVE_UP = 60
let NEXT_BUILD_TILES = 5
let BACK_TO_WORK_TILES = 10
let WAIT_TICKS = 20
let SPOTS = 8
let SIDES = 2
let SPOT_GAP = 100  // (World.SPOT_GAP too)
let SPOT_NEAR = 150
let SPOT_DX = [ 0, 1, 1, 1, 0, -1, -1, -1 ]
let SPOT_DY = [ -1, -1, 0, 1, 1, 1, 0, -1 ]
let SPOT_BUSY = 3
let NEAR_CUTOFF = 160
let FIELD_BUILDING = 3

// shots.gd: one record a shot.
let SHOT_LAND = 0
let SHOT_TO = 1
let SHOT_BY = 2
let SHOT_OWNER = 3
let SHOT_DAMAGE = 4
let SHOT_SRC = 5
let SHOT_UP = 6
let SHOT_X = 7
let SHOT_Y = 8
let SHOT_X0 = 9
let SHOT_Y0 = 10
let SHOT_STRIDE = 11

// fog.gd
let UNSEEN = 0
let EXPLORED = 1
let VISIBLE = 2
let CHUNK = 8

let SIN = [
    0, 25, 50, 75, 100, 125, 150, 175, 200, 224, 249, 273, 297, 321, 345, 369,
    392, 415, 438, 460, 483, 505, 526, 548, 569, 590, 610, 630, 650, 669, 688, 706,
    724, 742, 759, 775, 792, 807, 822, 837, 851, 865, 878, 891, 903, 915, 926, 936,
    946, 955, 964, 972, 980, 987, 993, 999, 1004, 1009, 1013, 1016, 1019, 1021, 1023, 1024,
    1024, 1024, 1023, 1021, 1019, 1016, 1013, 1009, 1004, 999, 993, 987, 980, 972, 964, 955,
    946, 936, 926, 915, 903, 891, 878, 865, 851, 837, 822, 807, 792, 775, 759, 742,
    724, 706, 688, 669, 650, 630, 610, 590, 569, 548, 526, 505, 483, 460, 438, 415,
    392, 369, 345, 321, 297, 273, 249, 224, 200, 175, 150, 125, 100, 75, 50, 25,
    0, -25, -50, -75, -100, -125, -150, -175, -200, -224, -249, -273, -297, -321, -345, -369,
    -392, -415, -438, -460, -483, -505, -526, -548, -569, -590, -610, -630, -650, -669, -688, -706,
    -724, -742, -759, -775, -792, -807, -822, -837, -851, -865, -878, -891, -903, -915, -926, -936,
    -946, -955, -964, -972, -980, -987, -993, -999, -1004, -1009, -1013, -1016, -1019, -1021, -1023, -1024,
    -1024, -1024, -1023, -1021, -1019, -1016, -1013, -1009, -1004, -999, -993, -987, -980, -972, -964, -955,
    -946, -936, -926, -915, -903, -891, -878, -865, -851, -837, -822, -807, -792, -775, -759, -742,
    -724, -706, -688, -669, -650, -630, -610, -590, -569, -548, -526, -505, -483, -460, -438, -415,
    -392, -369, -345, -321, -297, -273, -249, -224, -200, -175, -150, -125, -100, -75, -50, -25,
]

// commands.gd: the command codes (export.gd CMD_CODES).
let CMD_MOVE = 0
let CMD_ATTACK_MOVE = 1
let CMD_STANCE = 2
let CMD_GATHER = 3
let CMD_BUILD = 4
let CMD_HELP_BUILD = 5
let CMD_TRAIN = 6
let CMD_RALLY = 7
let CMD_RESEED = 8
let CMD_AGE_UP = 9
let CMD_RESEARCH = 10
let CMD_CALL_TO_ARMS = 11
let CMD_BACK_TO_WORK = 12
let CMD_ATTACK = 13
let CMD_STOP = 14
let CMD_CANCEL = 15
let CMD_DROP_OFF = 16
let CMD_SURRENDER = 17
let CMD_AUTO_RESEED = 18
let CMD_GARRISON = 19
let CMD_UNGARRISON = 20
let CMD_REPAIR = 21
let CMD_TRADE = 22
let CMD_ROUTE = 23
let CMD_PEN = 24
let CMD_RELEASE = 25
let CMD_ABILITY = 26
let HOOK_ORDER_BASE = 100  // a hook's own orders: command codes from here up (hook_on_order)
