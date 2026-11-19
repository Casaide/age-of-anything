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
import hooks.economy
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
let used = mods_use([ "steading" ])
check(used.length == 1, "the mod loads ({map(mods_refused.get_keys()) id: id + ": " + mods_refused.get(id, "")})")
let rules = load_rules("steading")
let races = map([ "villagers", "villagers" ]) p: generate(p, rules, 0)
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
    let plank0 = stock[pl][0]
    let workers = mine()
    let tx = start_x[0] / TILE
    let ty = start_y[0] / TILE
    gather_near(workers.slice(0, 2), "wood")
    gather_near(workers.slice(2, 1), "stone")
    var laid = 0
    var h = 0
    var sites_ok = true
    for(MINUTES * 60 * TICK_HZ) t:
        if t == 40 and lay("lumber_camp", tx + 6, ty - 4, workers[3]): laid++
        if t == 60 and lay("sawmill", tx - 6, ty + 3, workers[4]): laid++
        if t == 80 and lay("mining_camp", tx + 5, ty + 6, workers[5]): laid++
        if t == 100 and lay("house", tx - 5, ty - 6, workers[6]): laid++
        if t > 0 and t % 2400 == 0: gather_near(workers.slice(0, 2), "wood")  // (back to the trees once a hut is up)
        wstep()
        for(b_id.length) b:
            if b_site[b].length and b_done[b] == 0 and b_progress[b] * 1000 > bt_build_ticks[b_kind[b]] * site_permille(b) + bt_build_ticks[b_kind[b]]: sites_ok = false
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    var built = 0
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and b_kind[b] != btype_index("town_center"): built++
    print "steading: {MINUTES} min, {laid} laid, {built} built, {born_alive()} born; planks {plank0} -> {stock[pl][0]} (sawn {produced[pl][0]}), wood {stock[w][0]}, stone {stock[st][0]} in store"
    check(laid == 4 and built == 4, "steading: the hut, the sawmill, the quarry and a house are built ({built} of {laid})")
    let born = born_alive()
    check(born > 0 and born <= 2, "steading: children are born in the house, no more than its beds ({born})")
    check(sites_ok, "steading: no site was built ahead of its goods")
    check(produced[pl][0] > 0 and stock[pl][0] > plank0, "steading: the sawmill makes planks, more than the town started with ({plank0} -> {stock[pl][0]})")
    return h

def store_planks() -> int:
    var n = 0
    for(b_id.length) b:
        if is_store(b, 0): n += b_hold[b][res("plank")]
    return n

let h1 = play()
let h2 = play()
check(h1 == h2, "steading: the same town twice, the same hash")
lib_packs = [ lib_packs[0] ]
id_load(lib_root)
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
