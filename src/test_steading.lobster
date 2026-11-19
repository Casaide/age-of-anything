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

// Lay building `id` for player 0 near (x, y) in tiles, with `builder`: the first place it fits, spiralling out.
def lay(id:string, x:int, y:int, builder:int) -> bool:
    let k = btype_index(id)
    assert k >= 0
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let dx = ex - d
                let dy = ey - d
                if max(abs(dx), abs(dy)) == d and can_place(0, k, x + dx, y + dy, 0):
                    issue_cmd(0, CMD_BUILD, [ builder ], k, x + dx, y + dy, 0)
                    return true
    return false

// A road dragged along a row near x, y, a plan a cell as the road tool lays it (game/roads, #68): the first row of n free
// cells, built in order by `builder`. How many plans were laid.
def lay_road(x:int, y:int, n:int, builder:int) -> int:
    let k = btype_index("road")
    for(12) d:
        for([ y + d, y - d ]) ry:
            var free = true
            for(n) j: free = free and can_place(0, k, x + j, ry, 0)
            if free:
                for(n) j: issue_cmd(0, CMD_BUILD, [ builder ], k, x + j, ry, 0, if j > 0: 1 else: 0)
                return n
    return 0

def road_cells() -> int:
    var n = 0
    for(road) r:
        if r > 0: n++
    return n

def gather_near(ids:[int], name:string):
    for(ids) uid:
        let i = index_of(uid)
        issue_cmd(0, CMD_GATHER, [ uid ], nearest_resource(u_x[i], u_y[i], res(name) + 1, -1, false, false, false), 0, 0, 0)

def play() -> int:
    new_world(2026, MAP, races, rules, [])
    let w = res("wood")
    let pl = res("plank")
    let st = res("stone")
    check(r_stocked == 1 and pl >= 0 and t_carrier[u_kind[index_of(mine()[0])]] == 1, "steading: a stocked economy, planks, workers who carry")
    var homes0 = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] == btype_index("house"): homes0++
    check(homes0 == 1 and pop[0] <= pop_cap[0], "steading: the town starts with a house, room for its workers ({pop[0]} of {pop_cap[0]})")
    var start_house = -1  // (its cell: the town's own, not one the test laid)
    var apart = 0         // the start house's gap to the town centre, in cells (creel#80: it was laid on top of it)
    let tc = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_kind[b] == btype_index("house"):
            start_house = b_cy[b] * W + b_cx[b]
            let gx = max(b_cx[tc] - (b_cx[b] + bt_size[b_kind[b]]), b_cx[b] - (b_cx[tc] + bt_size[b_kind[tc]]))
            let gy = max(b_cy[tc] - (b_cy[b] + bt_size[b_kind[b]]), b_cy[b] - (b_cy[tc] + bt_size[b_kind[tc]]))
            apart = max(gx, gy)
    check(b_owner[tc] == 0 and b_kind[tc] == btype_index("town_center") and apart >= 1, "steading: the start house stands apart from the town centre, a clear cell between ({apart})")
    var by_tc = 0
    for(u_x.length) i:
        if u_owner[i] == 0 and abs(u_x[i] / TILE - (b_cx[tc] + 1)) <= 3 and abs(u_y[i] / TILE - (b_cy[tc] + 1)) <= 3: by_tc++
    check(by_tc == 8, "steading: the workers start round the town centre ({by_tc} of 8)")
    let plank0 = stock[pl][0]
    let workers = mine()
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    gather_near(workers.slice(0, 2), "wood")
    gather_near(workers.slice(2, 1), "stone")
    var laid = 0
    var h = 0
    var sites_ok = true
    let ate = []::int  // the workers that went to eat
    var planned = 0
    for(MINUTES * 60 * TICK_HZ) t:
        if t == 40 and lay("lumber_camp", tx + 6, ty - 4, workers[3]): laid++
        if t == 60 and lay("sawmill", tx - 6, ty + 3, workers[4]): laid++
        if t == 80 and lay("mining_camp", tx + 5, ty + 6, workers[5]): laid++
        if t == 100 and lay("house", tx - 5, ty - 6, workers[6]): laid++
        if t == 2400 and lay("inn", tx + 7, ty + 1, workers[7]): laid++  // (once the sawmill is going: planks for it first)
        if t == 140: planned = lay_road(tx - 2, ty + 4, 5, workers[2])
        for(u_x.length) i:
            if u_owner[i] == 0 and u_task[i] == T_EAT and not contains(ate, u_id[i]): ate.push(u_id[i])
        if t > 0 and t % 2400 == 0: gather_near(workers.slice(0, 2), "wood")  // (back to the trees once a hut is up)
        wstep()
        for(b_id.length) b:
            if b_site[b].length and b_done[b] == 0 and b_progress[b] * 1000 > bt_build_ticks[b_kind[b]] * site_permille(b) + bt_build_ticks[b_kind[b]]: sites_ok = false
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    var built = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] != btype_index("town_center") and b_cy[b] * W + b_cx[b] != start_house: built++
    let col_house = find(hook_unit_names) n: n == "house"  // (the mod's Lua: the home a worker was born in)
    var born = 0
    for(u_id.length) i:
        if u_owner[i] == 0 and hook_unit_get(col_house, i) != 0: born++
    var born_all = 0
    for(u_id.length) i:
        if hook_unit_get(col_house, i) != 0: born_all++
    print "steading: {MINUTES} min, {laid} laid, {built} built, {born_all} born, {ate.length} ate, {road_cells()} road; planks {plank0} -> {stock[pl][0]} (sawn {produced[pl][0]}), wood {stock[w][0]}, stone {stock[st][0]} in store"
    check(laid == 5 and built == 5, "steading: the hut, the sawmill, the quarry, a house and an inn are built ({built} of {laid})")
    check(planned == 5 and road_cells() == 5 and rd_names.length == 1, "steading: a road dragged 5 cells long is built, a road cell each ({road_cells()} of {planned})")
    check(ate.length >= 4, "steading: hungry workers go to eat ({ate.length} of them)")
    check(born > 0 and born <= 4, "steading: children are born in the two houses, no more than their beds ({born})")
    check(sites_ok, "steading: no site was built ahead of its goods")
    check(produced[pl][0] > 0 and stock[pl][0] > plank0, "steading: the sawmill makes planks, more than the town started with ({plank0} -> {stock[pl][0]})")
    return h

def store_planks() -> int:
    var n = 0
    for(b_id.length) b:
        if is_store(b, 0): n += b_hold[b][res("plank")]
    return n

// Through a save (#75): the mod's Lua loads again with the saved match, and its state comes back in the hook columns.
// A house goes up and workers cut wood for 2 minutes; then 2 minutes more, once straight on and once from a save made
// there: the same hash every tick. Whether they matched, and whether anyone was hungry, ate or was born by then.
// stop: the mod's rules stop before the save (as an error would stop them): they must stay stopped after the load.
def save_run(stop:bool) -> bool, bool:
    let path = "test_steading.sav"
    new_world(2026, MAP, races, rules, [])
    let workers = mine()
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    gather_near(workers.slice(0, 4), "wood")
    for(2 * 60 * TICK_HZ) t:
        if t == 40: lay("house", tx - 5, ty - 6, workers[6])
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
        for([ "meal", "house" ]) name:
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
