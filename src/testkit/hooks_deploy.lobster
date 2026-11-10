// ------------------------------------------------------------------ a test's rules, through every hook point
// In place of hooks/active.lobster, for test_hooks: soldiers of a type that asks deploy by a pack's own order; deployed,
// they take half damage; a side counts its dead, bots favour one line. Each calls on to the game's rules where it has some.

let DEPLOY = HOOK_ORDER_BASE
var col_deployed = -1
var col_dead = -1
var hook_orders_run = 0
var hook_hits_halved = 0

def hook_declare():
    col_deployed = hook_declare_unit("deployed")
    col_dead = hook_declare_player("dead", num_players)

def hook_on_hit(by:int, target:int, damage:int) -> int:
    if hook_unit_get(col_deployed, target) == 0: return damage
    hook_hits_halved++
    return max(1, damage / 2)

def hook_on_hurt(target:int, by:int): game_on_hurt(target, by)

def hook_on_death(i:int, killer:int):
    if u_owner[i] < num_players and t_animal[u_kind[i]] == 0: hook_player_cols[col_dead][u_owner[i]]++
    game_on_death(i, killer)

def hook_unit_tick(i:int):
    if hook_unit_get(col_deployed, i) == 0 and tick % 200 == 0: issue_cmd(u_owner[i], DEPLOY, [ u_id[i] ], 0, 0, 0, 0)

def hook_on_order(code:int, p:int, ids:[int], x:int, y:int):
    assert code == DEPLOY and x == 0 and y == 0
    for(ids) id:
        let i = index_of(id)
        if i >= 0 and u_owner[i] == p:
            hook_unit_set(col_deployed, i, 1)
            hook_orders_run++

def hook_ai_train_score(p:int, slot:string, k:int, score:int) -> int:
    return game_ai_train_score(p, slot, k, score) + (if slot == "infantry": 500 else: 0)
