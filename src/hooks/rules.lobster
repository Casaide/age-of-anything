// ------------------------------------------------------------------ the game's rules, as hooks
// What Age of Anything does at the engine's hook points (hooks/active.lobster). Rule code: it runs on every machine in
// lockstep, so integers and the sim's rng only, no clock, and any state it keeps is declared (hook_declare).

// Engines go round instead of by the counter-pick (Bot._siege_score).
def siege_score(p:int, slot:string, k:int) -> int:
    var at = -1
    for(cfg_list("military.siege.max_order")) s, n:
        if s == slot: at = n
    return 1000 - fielded(p, k) * 100 - at

def game_ai_train_score(p:int, slot:string, k:int, score:int) -> int:
    return if has_cfg("military.siege.max.{slot}"): siege_score(p, slot, k) else: score

// A sticky shot: what it hurt this tick is slowed.
def game_on_hurt(target:int, by:int):
    let byi = index_of(by)
    if byi >= 0 and t_slow_on_hit[u_kind[byi]] > 0: stick(target, t_slow_on_hit[u_kind[byi]])

// An animal died at slot i: its carcass lies on the nearest open cell, and its hunters gather it.
def animal_died(i:int):
    let k = u_kind[i]
    if t_food[k] <= 0: return
    let here = cell_of(u_x[i], u_y[i])
    var cell = -1
    for(3) r:
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                let x = here % W + dx
                let y = here / W + dy
                if cell < 0 and x >= 0 and y >= 0 and x < W and y < H:
                    let c = y * W + x
                    if walks[0][c] == 1 and occupied[c] == 0 and amount[c] == 0: cell = c
                dx++
            dy++
    if cell < 0: return
    set_terrain(cell, tr_index("carcass"))
    amount[cell] = t_food[k]
    let dead = u_id[i]
    for(u_x.length) j:
        if u_foe[j] == dead and t_worker[u_kind[j]]:
            u_foe[j] = 0
            start_gather(j, cell, resource_index("food") + 1)

def game_on_death(i:int, killer:int):
    if t_animal[u_kind[i]] != 0: animal_died(i)
