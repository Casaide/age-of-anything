// ------------------------------------------------------------------ the economy mod's rules, as hooks (#62)
// Two rules mods/steading switches on in its data, off in every other match. doors_on_roads (rules economy): a
// building goes up only with the tile in front of its door on a road or its owner's road plan. Homes: in a stocked
// economy with rules economy.homes.born_every set, a building with beds (buildings.json "beds") keeps the foods its
// holds have room for topped up (want, like a recipe's inputs), and while it has a free bed, food in its larder and room
// under its owner's cap it counts down; at the end it takes one food and a worker is born at its door. Creel has the
// pieces (the stocked economy, want, hold_take, trained); these are the rules (they were in Creel: Casaide/creel#78).

let HOME_LOOK = 20  // ticks between an idle home's looks at its beds and larder (a second)

var eco_seen = jobj()    // the rules the eco_ values were read from: a new match or a loaded save reads them again
var eco_doors = false    // rules economy.doors_on_roads
var eco_born_ticks = 0   // rules economy.homes.born_every, in ticks (0: no births)
var eco_foods = []::int  // rules economy.homes.foods: the resources a larder keeps and a birth takes one of
var eco_beds = []::int   // per building type: its beds (a home has some)
var col_house = -1       // unit column: the id of the home it was born in, 0 for none
var col_born = -1        // building column: a home's ticks to its next birth, 0 while it isn't counting

def eco_declare():
    hook_declare_unit("house")
    hook_declare_building("born")
    eco_load()

def eco_load():
    eco_seen = su_rules
    let ec = rules_part("economy")
    eco_doors = gbool(ec, "doors_on_roads", false)
    let hc = gobj(ec, "homes")
    eco_born_ticks = gint(hc, "born_every", 0) * TICK_HZ
    eco_foods = map(gstrs(hc, "foods")) f: find(resource_names): _ == f
    for(eco_foods) r: assert r >= 0
    eco_beds = map(su_btypes) b: gint(b, "beds", 0)
    col_house = find(hook_unit_names): _ == "house"
    col_born = find(hook_building_names): _ == "born"

def eco_fresh():
    if eco_seen != su_rules: eco_load()

// The tile in front of a building's door (below its bottom edge's middle) is road, or the player's road plan. Roads
// themselves, walls and gates, and ladders have no door.
def door_on_road(player:int, k:int, cx:int, cy:int, sx:int, sy:int) -> bool:
    if bt_road[k] >= 0 or bt_line[k] or bt_ladder[k]: return true
    let dx = cx + sx / 2
    let dy = cy + sy
    if dy >= H: return false
    let c = dy * W + dx
    if road.length and road[c] > 0: return true
    let b = b_index_of(occupied[c])
    return b >= 0 and b_owner[b] == player and bt_road[b_kind[b]] >= 0

def eco_can_place(player:int, k:int, cx:int, cy:int, sx:int, sy:int) -> bool:
    eco_fresh()
    return not eco_doors or door_on_road(player, k, cx, cy, sx, sy)

// The units born in building b that are still alive.
def residents(b:int) -> int:
    var n = 0
    for(u_id.length) i:
        if hook_unit_get(col_house, i) == b_id[b]: n++
    return n

def larder_food(b:int) -> int:
    for(eco_foods) r:
        if b_hold[b][r] > 0: return r
    return -1

def stock_larder(b:int):
    let k = b_kind[b]
    for(eco_foods) r:
        let lack = bt_hold[k][r] - b_hold[b][r] - b_want[b][r] - b_coming[b][r]
        if lack > 0: want(b, r, lack)

def beds(k:int) -> int: return if k < eco_beds.length: eco_beds[k] else: 0

def can_be_born(b:int) -> bool:
    let p = b_owner[b]
    let k = worker_type(p)
    return k >= 0 and larder_food(b) >= 0 and pop[p] + t_pop[k] <= pop_cap[p] and residents(b) < beds(b_kind[b])

def born(b:int):
    let k = worker_type(b_owner[b])
    hold_take(b, larder_food(b), 1)
    let i = trained(b, k)
    hook_unit_set(col_house, i, b_id[b])
    pop[b_owner[b]] += t_pop[k]

def homes_tick():
    eco_fresh()
    if not r_stocked or eco_born_ticks <= 0: return
    let second = tick % HOME_LOOK == 0
    for(b_id.length) b:
        if b_done[b] != 0 and beds(b_kind[b]) > 0:
            let left = hook_building_get(col_born, b)
            if left > 0:
                hook_building_set(col_born, b, left - 1)
                if left == 1 and can_be_born(b): born(b)
            elif second:
                stock_larder(b)
                if can_be_born(b): hook_building_set(col_born, b, eco_born_ticks)

// How many living units were born in a home.
def born_alive() -> int:
    var n = 0
    for(u_id.length) i:
        if hook_unit_get(col_house, i) != 0: n++
    return n
