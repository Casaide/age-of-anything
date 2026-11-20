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

// A Steading town for pictures (#104): the bot doesn't build the economy's chains, so this lays one out by script on
// Steading Vale, plays it headless and saves it, to be loaded in the game for a capture:
//   lobster steading_town.lobster -- [minutes]    (from src; writes saves/steading-town.sav)
//   ./play.sh lobby page:saves loadfirst mute shot:/tmp/town.png at:3 look:<x>,<y>
lib_load("../data")
id_load("../data")

let used = mods_use([ "steading" ])
assert used.length == 1
let rules = load_rules("steading")
let races = map([ "villagers", "villagers" ]) p: generate(p, rules, 0)
let args = command_line_arguments()
var minutes = 20
if args.length:
    let n, ok = string_to_int(args[0])
    assert ok
    minutes = n

// Lay building `id` for player 0 near (x, y) in tiles: the first place it fits, spiralling out.
def lay(id:string, x:int, y:int):
    let k = btype_index(id)
    assert k >= 0
    for(12) d:
        for(2 * d + 1) ey:
            for(2 * d + 1) ex:
                let dx = ex - d
                let dy = ey - d
                if max(abs(dx), abs(dy)) == d and can_place(0, k, x + dx, y + dy, 0):
                    issue_cmd(0, CMD_BUILD, []::int, k, x + dx, y + dy, 0)
                    return
    print "steading_town: no room for {id} near {x},{y}"

def done_of(id:string) -> int:
    for(b_id.length) b:
        if b_owner[b] == 0 and b_done[b] != 0 and bt_name[b_kind[b]] == id: return b_id[b]
    return 0

new_world(2026, "steading_vale", races, rules, [])
let tx = start_x[0] / TILE
let ty = start_y[0] / TILE
// what goes up when (tick, building, near x, near y: from the town's middle)
class Lay:
    t:int
    id:string
    x:int
    y:int

let plan = [ Lay { 20, "school", -2, -6 }, Lay { 40, "lumber_camp", 6, -4 }, Lay { 60, "sawmill", -6, 3 },
             Lay { 80, "mining_camp", 5, 6 }, Lay { 600, "farm", -8, -4 }, Lay { 700, "mill", -7, -9 },
             Lay { 800, "bakery", 2, 8 }, Lay { 2400, "inn", 2, -3 }, Lay { 2600, "sawmill", -9, 3 },
             Lay { 3000, "coal_mine", 8, 6 }, Lay { 3050, "iron_mine", 12, 3 }, Lay { 3100, "gold_mine", 16, -2 },
             Lay { 3200, "iron_smelter", 9, 9 }, Lay { 3300, "gold_smelter", 13, 9 }, Lay { 3400, "armoury", 9, -6 },
             Lay { 3600, "pig_farm", -8, 8 }, Lay { 3800, "butcher", -3, 11 } ]
let first = [ "woodcutter", "stonecutter", "sawyer", "farmer", "worker", "worker", "worker", "worker", "worker", "worker", "sawyer", "miner", "miner", "miner" ]
let second = [ "miller", "baker", "smelter", "smelter", "smith", "swineherd", "butcher", "worker", "worker", "worker", "worker", "worker", "worker" ]
var batch = 0
for(minutes * 60 * TICK_HZ) t:
    for(plan) p:
        if t == p.t: lay(p.id, tx + p.x, ty + p.y)
    let school = done_of("school")
    if school != 0 and batch < 2 and b_queue[b_index_of(school)].length == 0 and (batch == 0 or t > 3000):
        for(if batch == 0: first else: second) slot: issue_cmd(0, CMD_TRAIN, []::int, school, type_of_slot(0, slot), 1, 0)
        batch++
    wstep()
var built = 0
for(b_id.length) b:
    if b_owner[b] == 0 and b_done[b] != 0: built++
let path = "saves/steading-town.sav"
assert save_world(path, [])
print "steading_town: {minutes} min, {built} buildings, {pop[0]} people, saved to {path}"
