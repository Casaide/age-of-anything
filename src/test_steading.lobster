import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import lua.parse
import gen.mods
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
import lib.steering
import lib.fog
import lib.map
import lib.economy
import lib.tech
import lib.combat
import lib.siege
import lib.eco_bot
import lib.garrison
import lib.heal
import lib.heroes
import lib.match
import lib.trade
import lib.recipes
import lib.carry
import lib.animals
import lib.bridges
import lib.walls
import lib.abilities
import lib.trails
import lib.commands
import lib.ai_cfg
import lib.scout
import lib.land
import lib.expand
import lib.bot
import lib.walls_ai
import lib.world
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import lua.lua
import lua.api
import gen.reset
import gen.save
import testkit.kit
import game.model_type

// The economy mod's first slice (mods/steading, #524): a stocked town of wood, planks and stone, played headless for
// 15 minutes by a script (no bot, no enemy). Woodcutters and stone cutters gather, a woodcutter's hut, a sawmill and a
// quarry go up (paid by carrying planks and stone to their sites), and the sawmill turns logs into planks.
// Run from src:  lobster test_steading.lobster
lib_load("../data")
id_load("../data")

let MINUTES = 15
let MAP = "reed_meadow"
let T_EAT = 100  // (the mod's hunger.lua: its own task, going to eat)
let used = mods_use([ "steading" ])
check(used.length == 1, "the mod loads ({map(mods_refused.get_keys()) id: id + ": " + mods_refused.get(id, "")})")
let rules = load_rules("steading")
let races = map([ "villagers", "sewer rats" ]) p: generate(p, rules, 0)
// Every side plays villagers, whatever was typed (rules "race", #70).
let typed_rats = gstr(races[1], "creature", "")
check(gstr(races[0], "creature", "") == "human" and typed_rats == "human", "steading: every side is villagers, whatever was typed ({typed_rats})")
// Every building is drawn with a model the game has: its own, or the one it extends (#58: the sawmill had none, and the
// game stopped baking it at the start).
let game_buildings = at(parse_json(read_file("../data/buildings.json") or ""), "buildings")
let merged_buildings = at(lib_data("buildings.json"), "buildings")
for(merged_buildings.keys) id:
    let mt = model_type(merged_buildings, id)
    check(has(game_buildings, mt), "steading: {id} is drawn with a model the game has (it gets {mt})")

def res(name:string) -> int: return str_index(resource_names, name)

def mine() -> [int]: return map(filter(u_x.length) i: u_owner[i] == 0 and t_worker[u_kind[i]] != 0) i: u_id[i]

def all_of(r:int) -> int:  // player 0's r: in its buildings and in its units' hands
    var n = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_hold[b].length: n += b_hold[b][r]
    for(u_x.length) i:
        if u_owner[i] == 0 and u_carry_kind[i] == r + 1: n += u_carry[i]
    return n

// Lay building `id` for player 0 near (x, y) in tiles, from the town (no worker named): the first place it fits, spiralling out.
def lay(id:string, x:int, y:int) -> bool:
    let k = btype_index(id)
    assert k >= 0
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let dx = ex - d
                let dy = ey - d
                if max(abs(dx), abs(dy)) == d and can_place(0, k, x + dx, y + dy, 0):
                    issue_cmd(0, CMD_BUILD, []::int, k, x + dx, y + dy, 0)
                    return true
    return false

// A road dragged along a row near x, y, a plan a cell as the road tool lays it (game/roads, #68): the first row of n free
// cells, built in order. How many plans were laid.
def lay_road(x:int, y:int, n:int) -> int:
    let k = btype_index("road")
    for(12) d:
        for([ y + d, y - d ]) ry:
            var free = true
            for(n) j: free = free and can_place(0, k, x + j, ry, 0)
            if free:
                for(n) j: issue_cmd(0, CMD_BUILD, []::int, k, x + j, ry, 0, if j > 0: 1 else: 0)
                return n
    return 0

def road_cells() -> int:
    var n = 0
    for(road) r:
        if r > 0: n++
    return n

// The id of player 0's finished building of type `id`, 0 if there's none yet.
def done_of(id:string) -> int:
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == id: return b_id[b]
    return 0

def play() -> int:
    new_world(2026, MAP, races, rules, [])
    let w = res("wood")
    let pl = res("plank")
    let st = res("stone")
    check(r_stocked == 1 and pl >= 0 and t_carrier[u_kind[index_of(mine()[0])]] == 1, "steading: a stocked economy, planks, workers who carry")
    let tc = 0
    check(b_owner[tc] == 0 and b_kind[tc] == btype_index("town_center") and pop[0] == 5 and pop[0] <= pop_cap[0] and btype_index("house") < 0,
          "steading: the town starts with a storehouse and 5 villagers, room for them, and no houses ({pop[0]} of {pop_cap[0]})")
    var by_tc = 0
    for(u_x.length) i:
        if u_owner[i] == 0 and abs(u_x[i] / TILE - (b_cx[tc] + 1)) <= 3 and abs(u_y[i] / TILE - (b_cy[tc] + 1)) <= 3: by_tc++
    check(by_tc == 5, "steading: the villagers start round the storehouse ({by_tc} of 5)")
    let plank0 = stock[pl][0]
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    var laid = 0
    var h = 0
    var sites_ok = true
    let ate = []::int  // the workers that went to eat
    var planned = 0
    var most_builders = 0    // the most villagers building one site at once
    var site_walked = false  // someone stood on a site's cells while it went up
    var trained = false
    var gatherers_ok = true                                   // nobody but a woodcutter or a stone cutter ever gathered
    let col_work = find(hook_unit_names) n: n == "workplace"  // (the mod's jobs.lua: the hut a specialist works at)
    for(MINUTES * 60 * TICK_HZ) t:
        if t == 20 and lay("school", tx - 2, ty - 6): laid++
        if t == 40 and lay("lumber_camp", tx + 6, ty - 4): laid++
        if t == 60 and lay("sawmill", tx - 6, ty + 3): laid++
        if t == 80 and lay("mining_camp", tx + 5, ty + 6): laid++
        if t == 2400 and lay("inn", tx + 7, ty + 1): laid++  // (once the sawmill is going: planks for it first)
        if t == 140: planned = lay_road(tx - 2, ty + 4, 5)
        let school = done_of("school")
        if school != 0 and not trained:
            for([ "woodcutter", "stonecutter", "worker", "worker", "worker" ]) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
            trained = true
        for(u_x.length) i:
            if u_owner[i] == 0 and u_task[i] == T_EAT and not contains(ate, u_id[i]): ate.push(u_id[i])
            if u_task[i] == GATHER and t_slot[u_kind[i]] != "woodcutter" and t_slot[u_kind[i]] != "stonecutter": gatherers_ok = false
        wstep()
        for(b_id.length) b:
            if b_site[b].length and b_done[b] == 0 and b_progress[b] * 1000 > bt_build_ticks[b_kind[b]] * site_permille(b) + bt_build_ticks[b_kind[b]]: sites_ok = false
        if tick % 20 == 0:
            for(b_id.length) b:
                if b_owner[b] == 0 and b_done[b] == 0 and bt_road[b_kind[b]] < 0:
                    var n = 0
                    for(u_x.length) i:
                        if u_task[i] == BUILD and u_target[i] == b_id[b]: n++
                        if occupied[cell_of(u_x[i], u_y[i])] == b_id[b]: site_walked = true
                    most_builders = max(most_builders, n)
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    var built = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] != btype_index("town_center"): built++
    var staffed = 0  // specialists at a hut of their own trade
    for(u_x.length) i:
        let at_ = b_index_of(hook_unit_get(col_work, i))
        if u_owner[i] == 0 and at_ >= 0:
            let job = t_slot[u_kind[i]]
            if (job == "woodcutter" and bt_name[b_kind[at_]] == "lumber_camp") or (job == "stonecutter" and bt_name[b_kind[at_]] == "mining_camp"): staffed++
    print "steading: {MINUTES} min, {laid} laid, {built} built, {staffed} staffed, {most_builders} at most on a site, {ate.length} ate, {road_cells()} road; planks {plank0} -> {stock[pl][0]} (sawn {produced[pl][0]}), wood {stock[w][0]} (cut {gathered[w][0]}), stone {stock[st][0]} (cut {gathered[st][0]}) in store"
    check(laid == 5 and built == 5, "steading: the school, the hut, the sawmill, the quarry and an inn are built ({built} of {laid})")
    check(staffed == 2, "steading: a woodcutter and a stone cutter trained at the school each went to work at its hut ({staffed} of 2)")
    check(gatherers_ok and gathered[w][0] > 0 and gathered[st][0] > 0, "steading: wood and stone come in, cut only by the specialists ({gathered[w][0]} wood, {gathered[st][0]} stone)")
    check(planned == 5 and road_cells() == 5 and rd_names.length == 1, "steading: a road dragged 5 cells long is built, a road cell each ({road_cells()} of {planned})")
    check(most_builders >= 2 and most_builders <= 3, "steading: idle villagers help build a site, no more than 3 sent at once ({most_builders})")
    check(site_walked, "steading: villagers walk across a site while it goes up")
    check(ate.length >= 3, "steading: hungry workers go to eat ({ate.length} of them)")
    check(sites_ok, "steading: no site was built ahead of its goods")
    check(produced[pl][0] >= 20, "steading: the sawmill makes planks ({produced[pl][0]}; {plank0} -> {stock[pl][0]} in store)")
    return h

def store_planks() -> int:
    var n = 0
    for(b_id.length) b:
        if is_store(b, 0): n += b_hold[b][res("plank")]
    return n

// Through a save (#75): the mod's Lua loads again with the saved match, and its state comes back in the hook columns.
// A hut goes up and the villagers wait, carry and get hungry for 2 minutes; then 2 minutes more, once straight on and once from a save made
// there: the same hash every tick. Whether they matched, and whether anyone was hungry or ate by then.
// stop: the mod's rules stop before the save (as an error would stop them): they must stay stopped after the load.
def save_run(stop:bool) -> bool, bool:
    let path = "test_steading.sav"
    new_world(2026, MAP, races, rules, [])
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    for(2 * 60 * TICK_HZ) t:
        if t == 40: lay("lumber_camp", tx + 6, ty - 4)
        wstep()
    if stop:
        let pk = l_packs[find(l_packs) p: p.id == "steading"]
        pk.error = "stopped by the test"
        lx_note_stop(pk)
    assert save_world(path, [])
    let want = map(2 * 60 * TICK_HZ):
        wstep()
        state_hash()
    let cols = map(hook_unit_names) n: n
    var lively = false
    for(u_id.length) i:
        for([ "meal" ]) name:
            let c = find(cols) n: n == name
            if c >= 0 and hook_unit_get(c, i) != 0: lively = true
    reset_world()
    lua_reset()  // (as a game started fresh to load it has no Lua yet)
    lua_on = false
    lua_rules = jobj()
    load_world(path)
    delete_file(path)
    let got = map(2 * 60 * TICK_HZ):
        wstep()
        state_hash()
    let off = l_packs[find(l_packs) p: p.id == "steading"].error != ""
    return equal(want, got) and off == stop, lively

let h1 = play()
let h2 = play()
check(h1 == h2, "steading: the same town twice, the same hash")
let same, lively = save_run(false)
check(lively and same, "steading: through a save, the mod\'s rules and their state play on the same (lively {lively}, same {same})")
let same_off, _ = save_run(true)
check(same_off, "steading: rules that stopped before a save stay stopped after it, the same on every machine")
lib_packs = [ lib_packs[0] ]
id_load(lib_root)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
