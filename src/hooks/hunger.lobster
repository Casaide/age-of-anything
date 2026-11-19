// ------------------------------------------------------------------ eating, as hooks (#47)
// A rule mods/steading switches on in its data, off in every other match. With rules economy.hunger.every set, units of
// the eater slots (economy.hunger.eaters) count the ticks since they last ate. Once hungry, at a pause in their work
// (at_a_pause) they go and eat: at home (hooks/economy) if its larder has food, else at the nearest of their side's
// buildings that serve (buildings.json "serves": an inn), else at a store. A meal at home or a store is a whole food; an
// inn opens one food into "serves" meals, so it feeds a town for less. Then they go back to the job they left.
// A hungry unit that isn't eating works only economy.hunger.starving_pct of the time, and not at all once it has gone
// twice "every" without a meal. Serving buildings keep their holds of economy.hunger.foods topped up, by carriers.

let T_EAT = 100    // a hook's own task: going to eat (Creel's tasks end at T_CARRY, and its work() leaves others be)
let T_FAINT = 101  // a hook's own task: a hungry unit resting this tick from its job (it takes it up again next tick)

var hu_seen = jobj()        // the rules the hu_ values were read from
var hu_ticks = 0            // rules economy.hunger.every, in ticks (0: nobody eats)
var hu_eaters = []::string  // rules economy.hunger.eaters: the roster slots whose units eat
var hu_starving = 100       // rules economy.hunger.starving_pct
var hu_foods = []::int      // rules economy.hunger.foods: what a meal is made of
var hu_serves = []::int     // per building type: the meals one food makes there, 0 if it doesn't serve
var hu_eats = []::int       // per unit type: 1 if it eats (filled as types come)
var col_meal = -1           // unit column: ticks since it last ate (up to twice "every")
var col_was = -1            // unit column: the job it left to eat, target * 16 + task, 0 for none
var col_rest = -1           // unit column: while resting (T_FAINT), 1 + the task it rests from
var col_portions = -1       // building column: an inn's meals left of the food it opened

def hunger_declare():
    hook_declare_unit("meal")
    hook_declare_unit("was")
    hook_declare_unit("rest")
    hook_declare_building("portions")
    hunger_load()

def hunger_load():
    hu_seen = su_rules
    let hc = gobj(rules_part("economy"), "hunger")
    hu_ticks = gint(hc, "every", 0) * TICK_HZ
    hu_eaters = gstrs(hc, "eaters")
    hu_starving = gint(hc, "starving_pct", 100)
    hu_foods = map(gstrs(hc, "foods")) f: find(resource_names): _ == f
    for(hu_foods) r: assert r >= 0
    assert hu_ticks == 0 or hu_foods.length
    hu_serves = map(su_btypes) b: gint(b, "serves", 0)
    hu_eats = []
    col_meal = find(hook_unit_names): _ == "meal"
    col_was = find(hook_unit_names): _ == "was"
    col_rest = find(hook_unit_names): _ == "rest"
    col_portions = find(hook_building_names): _ == "portions"

def hunger_fresh():
    if hu_seen != su_rules: hunger_load()
    while hu_eats.length < t_slot.length:
        let s = t_slot[hu_eats.length]
        let at = find(hu_eaters): _ == s
        hu_eats.push(if at >= 0: 1 else: 0)

def eats(k:int) -> bool: return hu_eats[k] != 0
def serves(k:int) -> int: return if k < hu_serves.length: hu_serves[k] else: 0
def meal_of(i:int) -> int: return hook_unit_get(col_meal, i)

def food_offered(b:int) -> int:
    for(hu_foods) r:
        if offered(b, r) > 0: return r
    return -1

def has_meal(b:int) -> bool: return (serves(b_kind[b]) != 0 and hook_building_get(col_portions, b) > 0) or food_offered(b) >= 0

def take_meal(b:int):
    let n = serves(b_kind[b])
    let left = hook_building_get(col_portions, b)
    if n != 0 and left > 0:
        hook_building_set(col_portions, b, left - 1)
        return
    hold_take(b, food_offered(b), 1)
    if n != 0: hook_building_set(col_portions, b, n - 1)

// Where unit i eats: its home if that has food, else the nearest finished building of its side that serves a meal (an
// inn), else the nearest of its side's stores with food (a whole food a meal, as at home); -1 if there's none.
def eat_place(i:int) -> int:
    let hid = hook_unit_get(col_house, i)
    let home = if hid != 0: b_index_of(hid) else: -1
    if home >= 0 and b_done[home] != 0 and food_offered(home) >= 0: return home
    let inn = nearest_meal(i, false)
    return if inn >= 0: inn else: nearest_meal(i, true)

def nearest_meal(i:int, stores:bool) -> int:
    var best = -1
    var best_d2 = 1 << 62
    for(b_id.length) b:
        let k = b_kind[b]
        if (if stores: bt_store[k] != 0 else: serves(k) != 0) and b_owner[b] == u_owner[i] and b_done[b] != 0 and has_meal(b):
            let d2 = mid_dist2(b, u_x[i], u_y[i])
            if d2 < best_d2:
                best_d2 = d2
                best = b
    return best

// A pause in its work: idle, building, gathering with nothing in hand, or carrying with nothing in hand yet (a carrier
// that leaves such a job gives it back to the queue: lib/carry drops a job whose carrier went).
def at_a_pause(i:int) -> bool:
    let task = u_task[i]
    return task == T_NONE or task == BUILD or ((task == GATHER or task == T_CARRY) and u_carry[i] == 0)

def go_eat(i:int, b:int):
    let task = u_task[i]
    hook_unit_set(col_was, i, if task == T_NONE or task == T_CARRY: 0 else: u_target[i] * 16 + task)
    u_task[i] = T_EAT
    u_target[i] = b_id[b]
    u_work[i] = 0
    u_stuck[i] = 0
    approach_building(i, b)

// Back to the job it left to eat, if that's still there.
def back_from_meal(i:int):
    let was = hook_unit_get(col_was, i)
    hook_unit_set(col_was, i, 0)
    let task = was % 16
    let target = was / 16
    u_task[i] = T_NONE
    u_target[i] = -1
    u_stuck[i] = 0  // (a crowd at the inn isn't the job's: a builder stuck there would give its site up, #70)
    if task == GATHER:
        let kind = u_carry_kind[i]
        let c = if res_at(target) == kind and amount[target] > 0: target else: nearest_resource(target % W * TILE + TILE / 2, target / W * TILE + TILE / 2, kind, i, false, false, true)
        if kind > 0 and c >= 0: start_gather(i, c, kind)
        else: clear_task(i)
    elif task == BUILD:
        let b = b_index_of(target)
        if b >= 0 and b_done[b] != 1: start_build(i, target)
        else: clear_task(i)
    else:
        clear_task(i)

def eat(i:int):
    let b = b_index_of(u_target[i])
    if b < 0 or not has_meal(b):  // gone, or eaten bare on the way: somewhere else, or back to work hungry
        let other = eat_place(i)
        if other >= 0: go_eat(i, other)
        else: back_from_meal(i)
        return
    let x0, y0, x1, y1 = building_rect(b)
    if in_reach(i, x0, y0, x1, y1):
        u_moving[i] = 0
        take_meal(b)
        hook_unit_set(col_meal, i, 0)
        back_from_meal(i)
    elif u_moving[i] == 0:
        if u_stuck[i] >= GIVE_UP: back_from_meal(i)
        else: approach_building(i, b)

// A hungry unit rests this tick: past twice "every" always, before that outside starving_pct of each 100 ticks. From
// gathering, carrying back, building, standing idle (a resting carrier takes no job), or a carrier's job with nothing
// in hand yet (given back to the queue: it rests from idle). One carrying goods works on.
def rests(i:int, meal:int) -> bool:
    let task = u_task[i]
    if task != T_NONE and task != GATHER and task != T_RETURN and task != BUILD and not (task == T_CARRY and u_carry[i] == 0): return false
    return meal >= 2 * hu_ticks or tick % 100 >= hu_starving

def stock_inn(b:int):
    let k = b_kind[b]
    for(hu_foods) r:
        let lack = bt_hold[k][r] - b_hold[b][r] - b_want[b][r] - b_coming[b][r]
        if lack > 0: want(b, r, lack)

// Once a tick, after the economy's steps (so a rest set here is the next tick's work skipped).
def hunger_tick():
    hunger_fresh()
    if not r_stocked or hu_ticks <= 0: return
    if tick % HOME_LOOK == 0:
        for(b_id.length) b:
            if b_done[b] != 0 and serves(b_kind[b]) != 0: stock_inn(b)
    for(u_x.length) i:
        if eats(u_kind[i]):
            if u_task[i] == T_FAINT:
                u_task[i] = hook_unit_get(col_rest, i) - 1
                hook_unit_set(col_rest, i, 0)
            let meal = meal_of(i)
            if meal < 2 * hu_ticks: hook_unit_set(col_meal, i, meal + 1)
            if u_task[i] == T_EAT: eat(i)
            elif meal >= hu_ticks:
                let b = if (tick + i) % HOME_LOOK == 0 and at_a_pause(i): eat_place(i) else: -1
                if b >= 0: go_eat(i, b)
                elif rests(i, meal):
                    hook_unit_set(col_rest, i, 1 + (if u_task[i] == T_CARRY: T_NONE else: u_task[i]))
                    u_task[i] = T_FAINT

// What the panel says a worker is doing, for the hook's own tasks ("" for the engine's).
def hunger_task_name(i:int) -> string:
    return if u_task[i] == T_EAT: "Going to eat" elif u_task[i] == T_FAINT: "Hungry" else: ""
