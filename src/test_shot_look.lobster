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
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
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
import gen.setup
import gen.modes
import gen.start
import gen.reset
import testkit.kit
import view.shot_look

// Shots look faster, and land when they always did (#175). Headless and seeded: archers fight, and every shot's landing
// tick is the sim's flight; the drawn flight is shorter and ends exactly then; the sim never reads the look.
// Run from src:  lobster test_shot_look.lobster
// It prints the run's state hash and landings hash: the same before and after a change to how shots look.

let SEED = 2026
let MAP = "open_field"

def archers(p:int, n:int, x:int, y:int) -> [int]:
    let kind = find(t_slot.length) k: t_player[k] == p and t_ranged[k] != 0 and t_shot_speed[k] > 0 and not has(su_type_recipe[k], "crew")
    let ids = []::int
    for(n) a: ids.push(u_id[add_unit(p, kind, x + (a % 8) * 700, y + (a / 8) * 700)])
    return ids

lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let races = map([ "norse frogs", "centaurs" ]) p: generate(p, rules, 0)
new_world(SEED, MAP, races, rules, [])
let mid_x = (start_x[0] + start_x[1]) / 2
let mid_y = (start_y[0] + start_y[1]) / 2
let mine = archers(0, 32, mid_x - 9000, mid_y)
let foes = archers(1, 32, mid_x + 3000, mid_y)
issue_cmd(0, CMD_ATTACK_MOVE, mine, mid_x, mid_y, 0, 0)
issue_cmd(1, CMD_ATTACK_MOVE, foes, mid_x, mid_y, 0, 0)
let seen = dictionary<int, int>(1024)
var lands_hash = 0
var shots_seen = 0
var off_flight = 0
var longest = 0
while tick < 1200:
    wstep()
    let n = shots.length / SHOT_STRIDE
    for(n) k:
        let o = k * SHOT_STRIDE
        let key = shots[o + SHOT_BY] * 65536 + shots[o + SHOT_LAND] % 65536
        if seen.get(key, -1) < 0:
            seen.set(key, 1)
            shots_seen++
            let land = shots[o + SHOT_LAND]
            lands_hash = (lands_hash * 31 + land) % 1000000007
            let src = shots[o + SHOT_SRC]
            if src >= 0:
                let f = flight(shots[o + SHOT_X0], shots[o + SHOT_Y0], shots[o + SHOT_X], shots[o + SHOT_Y], t_shot_speed[src])
                longest = max(longest, f)
                if land != tick - 1 + f and land != tick + f: off_flight++
print "shots: {shots_seen}, longest flight {longest} ticks; landings hash {lands_hash}; state hash {state_hash()}"
check(shots_seen > 50, "archers fight ({shots_seen} shots)")
check(off_flight == 0, "every shot lands on the flight the sim gave it ({off_flight} off)")

// The look, over a long shot and a short one.
let long_shot = float(longest) / 20.0
check(long_shot >= 0.5, "a long shot to look at ({long_shot} s)")
let seen_for = shot_drawn_time(long_shot)
print "a {fixed_str(long_shot, 2)} s flight is seen for {fixed_str(seen_for, 2)} s: {fixed_str(long_shot / seen_for, 2)} times as fast"
check(seen_for <= long_shot * 0.6, "a long shot looks faster ({seen_for} s of {long_shot} s)")
check(shot_drawn_u(long_shot, long_shot) == 1.0, "it lands on the tick the sim says, not before or after")
check(shot_drawn_u(long_shot - 0.05, long_shot) < 1.0, "and is not there a tick early")
check(shot_drawn_u(0.0, long_shot) <= 0.0, "it leaves late, not early")
let short_shot = 0.1
check(shot_drawn_time(short_shot) == short_shot, "a shot quicker than the least we show flies its whole way")

// The game draws through it; the sim never reads it.
let game = read_file("game.lobster") or ""
let fx = read_file("game/fx.lobster") or ""
check(find_string(game, "shot_drawn_u(") >= 0, "the game draws plain shots by it")
check(find_string(fx, "shot_drawn_time(") >= 0, "and tracers")
for([ "lib/combat.lobster", "lib/siege.lobster", "lib/world.lobster", "lib/movement.lobster", "lib/orders.lobster" ]) f:
    check(find_string(read_file(f) or "", "shot_drawn") < 0, "{f} does not read the look")
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
