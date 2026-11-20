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
import game.steading_lay

// A Steading town for pictures (#104): the bot doesn't build the economy's chains, so this lays one out by script on
// Steading Vale, plays it headless and saves it, to be loaded in the game for a capture:
//   lobster steading_town.lobster -- [minutes, 30]    (from src; writes saves/steading-town.sav)
//   ./play.sh lobby mods:steading rules:steading page:saves loadfirst mute shot:/tmp/town.png at:4 look:<x>,<y>
// (A loaded match shows no tips or goals: they're only for a match played from the start.)
lib_load("../data")
id_load("../data")

let used = mods_use([ "steading" ])
assert used.length == 1
let rules = load_rules("steading")
let races = map([ "villagers", "villagers" ]) p: generate(p, rules, 0)
let args = command_line_arguments()
var minutes = 30
if args.length:
    let n, ok = string_to_int(args[0])
    assert ok
    minutes = n

// Lay building `id` for player 0 near (x, y) in tiles, with a road to its door (game/steading_lay).
def lay(id:string, x:int, y:int):
    if not lay_with_road(id, x, y): print "steading_town: no room for {id} near {x},{y}"

def done_of(id:string) -> int:
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == id: return b_id[b]
    return 0

def res(name:string) -> int: return str_index(resource_names, name)

// The cells of resource r within d tiles of (x, y), in cell order.
def seam_cells(r:int, x:int, y:int, d:int) -> [int]:
    return filter(W * H) c: res_at(c) == r + 1 and abs(c % W - x) <= d and abs(c / W - y) <= d

// Each trade and the building it works at (buildings.json "staff"): one trained for each finished building.
let JOBS = [ [ "woodcutter", "lumber_camp" ], [ "stonecutter", "mining_camp" ], [ "sawyer", "sawmill" ], [ "farmer", "farm" ],
             [ "miner", "gold_mine" ], [ "smelter", "gold_smelter" ], [ "miller", "mill" ], [ "baker", "bakery" ],
             [ "miner", "coal_mine" ], [ "miner", "iron_mine" ], [ "smelter", "iron_smelter" ], [ "smith", "armoury" ],
             [ "swineherd", "pig_farm" ], [ "butcher", "butcher" ] ]
let VILLAGERS = 22  // carriers and builders at most: the 8 the town starts with, and more only while sites wait for one

def done_count(id:string) -> int:
    return (filter(b_id.length) b: b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == id).length

def slot_count(slot:string) -> int:
    return (filter(u_x.length) i: u_owner[i] == 0 and t_slot[u_kind[i]] == slot).length

// Who the school trains next: a trade for a finished building that has no one yet, else a villager if a site waits
// with every villager busy; "" for no one.
def next_trainee() -> string:
    for(JOBS) jb:
        var need = 0
        for(JOBS) o:
            if o[0] == jb[0]: need += done_count(o[1])
        if slot_count(jb[0]) < need: return jb[0]
    let idle = filter(u_x.length) i: u_owner[i] == 0 and t_carrier[u_kind[i]] != 0 and u_task[i] == T_NONE and not u_orders[i].length
    let sites = filter(b_id.length) b: b_owner[b] == 0 and b_done[b] == 0
    if slot_count("worker") < VILLAGERS and not idle.length and sites.length: return "worker"
    return ""

new_world(2026, "steading_vale", races, rules, [])
let tx = start_x[0] / TILE
let ty = start_y[0] / TILE
let seam = seam_cells(res("coal"), tx, ty, 12)
let sx = seam[0] % W
let sy = seam[0] / W
let au = res("gold")
// what goes up when (tick, building, near x, near y: from the town's middle; the mines by the coal seam, early, while the seams
// are clear of the camps' doors and roads)
class Lay:
    t:int
    id:string
    x:int
    y:int

let plan = [ Lay { 20, "school", tx - 2, ty - 6 }, Lay { 40, "lumber_camp", tx + 6, ty - 4 }, Lay { 60, "sawmill", tx - 6, ty + 3 },
             Lay { 80, "mining_camp", tx + 5, ty + 6 }, Lay { 90, "coal_mine", sx - 1, sy + 3 }, Lay { 100, "iron_mine", sx + 3, sy }, Lay { 600, "farm", tx - 8, ty - 4 }, Lay { 700, "mill", tx - 5, ty - 9 },
             Lay { 800, "bakery", tx + 2, ty + 8 }, Lay { 900, "gold_mine", tx + 16, ty - 2 }, Lay { 1000, "gold_smelter", tx + 13, ty + 9 },
             Lay { 2400, "inn", tx + 7, ty - 1 }, Lay { 2600, "sawmill", tx - 9, ty + 3 }, Lay { 2700, "lumber_camp", tx + 12, ty - 3 },
             Lay { 3400, "armoury", tx + 9, ty - 6 },
             Lay { 3600, "pig_farm", tx - 8, ty + 8 }, Lay { 3800, "butcher", tx - 3, ty + 11 } ]
var iron_laid = false
var asked = false
var asked_at = 0
var next_pop = 0
for(minutes * 60 * TICK_HZ) t:
    for(plan) p:
        if t == p.t: lay(p.id, p.x, p.y)
    if not iron_laid and done_of("gold_smelter") != 0:  // (once the gold smelter is up, so the first smelter goes there: it pays the school)
        iron_laid = true
        lay("iron_smelter", tx + 17, ty + 9)
    // the school trains one at a time, each paid in gold, as the town needs them
    let school = done_of("school")
    if school != 0 and t % 20 == 0:
        let q = b_queue[b_index_of(school)].length
        if asked and pop[0] >= next_pop: asked = false
        elif asked and q == 0 and t > asked_at + 60: asked = false
        if not asked and q == 0 and stock[au][0] >= 10:
            let who = next_trainee()
            if who != "":
                issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, who), 1, 0)
                asked = true
                asked_at = t
                next_pop = pop[0] + 1
    wstep()
var built = 0
for(b_id.length) b:
    if b_owner[b] == 0 and b_done[b] != 0 and bt_road[b_kind[b]] < 0 and b_kind[b] != btype_index("town_center"): built++
let unbuilt = map(filter(b_id.length) b: b_owner[b] == 0 and b_done[b] == 0) b: bt_name[b_kind[b]]
var roads = 0
for(road) r:
    if r > 0: roads++
launch_subprocess([ "/bin/mkdir", "-p", "saves" ])
let path = "saves/steading-town.sav"
assert save_world(path, [ new_bot(1) ])  // (the other side's bot: a save with none is read as a failed load)
print "steading_town: {minutes} min, {built} of {plan.length + 1} buildings, {roads} road cells, {pop[0]} people ({slot_count("worker")} villagers), gold {stock[au][0]}, unbuilt {unbuilt}, saved to {path}"
assert not unbuilt.length
