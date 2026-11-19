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
import testkit.kit
import view.shot_look

// Shots look faster, and land when they always did (#175). Headless and seeded: archers fight, and every shot's landing
// tick is the sim's flight; the drawn flight is shorter and ends exactly then; the sim never reads the look.
// Run from src:  lobster test_shot_look.lobster
// It prints the run's state hash and landings hash: the same before and after a change to how shots look.

let SEED = 2026
let MAP = "open_field"

def archers(p:int, n:int, x:int, y:int) -> [int]:
    let kind = find(t_slot.length) k: t_player[k] == p and t_ranged[k] != 0 and t_shot_speed[k] > 0 and not has(gobj(su_units[k], "look"), "crew")
    let ids = []::int
    for(n) a: ids.push(u_id[add_unit(p, kind, x + (a % 8) * 700, y + (a / 8) * 700)])
    return ids

lib_load("../data")
id_load("../data")
mods_use([ "big_battle" ])
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
check(shot_drawn_u(0.0, long_shot, true) == 0.0, "a gun\'s shell shows from the flash (#265)")
check(shot_drawn_u(long_shot, long_shot, true) == 1.0, "and lands on the same tick")
let short_shot = 0.1
check(shot_drawn_time(short_shot) == short_shot, "a shot quicker than the least we show flies its whole way")

// An arrow: a thin dark shaft, no ball on the end, small fletching; in flight a head that narrows to its point (#325).
def hex_of_knob(o:JV, k:string) -> float4:
    let h = gstr(o, k, "#ffffff")
    def byte(i:int) -> float: return float(string_to_int(h.substring(i, 2), 16)) / 255.0
    return float4 { byte(1), byte(3), byte(5), 1.0 }
def lum(c:float4) -> float: return 0.3 * c.x + 0.6 * c.y + 0.1 * c.z
let ARROW_W_MAX = 0.8     // canvas units, the widest line of its shaft
let SHAFT_LUM_MAX = 0.35  // dark against the grass
let shots_data = load_json("../data/shots.json")
for([ "arrow", "bolt" ]) kind:
    let m = at(shots_data, kind)
    let w = as_float(at(m, "w"))
    let parts = arrow_lines(float2_0, float2 { 0.0, -6.0 }, w, hex_of_knob(m, "shaft"), hex_of_knob(m, "head"), hex_of_knob(m, "fletch"), false)
    let widest = parts[0].w  // (the shaft; the fletching has its own bound below)
    var balls = 0
    for(parts) l:
        if l.ball: balls++
    check(widest <= ARROW_W_MAX, "{kind} stuck in the ground: {widest} wide, at most {ARROW_W_MAX}")
    check(balls == 0, "{kind} stuck in the ground: {balls} round ends, none wanted")
    check(has(m, "shaft") and lum(hex_of_knob(m, "shaft")) <= SHAFT_LUM_MAX, "{kind} has a dark shaft (luminance {lum(hex_of_knob(m, "shaft"))}, at most {SHAFT_LUM_MAX})")
    check(has(m, "fletch"), "{kind} has fletching")
    let flying = arrow_lines(float2_0, float2 { 0.0, -6.0 }, w, hex_of_knob(m, "shaft"), hex_of_knob(m, "head"), hex_of_knob(m, "fletch"), true)
    let tip = flying[flying.length - 1]
    check(tip.w < flying[flying.length - 2].w and tip.a == float2_0, "{kind}\'s head narrows to its point ({tip.w} at the tip, {flying[flying.length - 2].w} behind)")
    check(magnitude(flying[1].b - flying[1].a) <= 1.8, "{kind}\'s fletching is small")
    check(flying[1].w <= 1.6, "{kind}\'s fletching is narrow ({flying[1].w})")

// Whatever else stands in the ground (a javelin, a dart) is no peg either.
let STUCK_W_MAX = 1.3
for(shots_data.keys) kind, n:
    let m = shots_data.a[n]
    if kind != "_doc" and not has(m, "shaft") and has(m, "len") and as_float(at(m, "len")) > 0.0:
        let plain = stuck_lines(float2_0, float2 { 0.0, -6.0 }, as_float(at(m, "w")), hex_of_knob(m, "col"), 1.0)
        var plain_w = 0.0
        var plain_balls = 0
        for(plain) l:
            plain_w = max(plain_w, l.w)
            if l.ball: plain_balls++
        check(plain_w <= STUCK_W_MAX and plain_balls == 0, "{kind} stuck in the ground: {plain_w} wide (at most {STUCK_W_MAX}), {plain_balls} round ends")

// The game draws through it; the sim never reads it.
let game = (read_file("game.lobster") or "") + (read_file("game/world_draw.lobster") or "") + (read_file("game/controls.lobster") or "")  // (the view: ours and Creel's, #433)
let fx = read_file("game/fx.lobster") or ""
check(find_string(game, "shot_drawn_u(") >= 0, "the game draws plain shots by it")
check(find_string(fx, "shot_drawn_time(") >= 0, "and tracers")
for([ "lib/combat.lobster", "lib/siege.lobster", "lib/world.lobster", "lib/movement.lobster", "lib/orders.lobster" ]) f:
    check(find_string(read_file(f) or "", "shot_drawn") < 0, "{f} does not read the look")
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
