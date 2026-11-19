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
import testkit.hooks_deploy
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import gen.reset
import testkit.kit
import gen.save

// Every hook point at work, from rules in place of hooks/active.lobster (testkit/hooks_deploy): a bot match to the end,
// the same twice, saved and loaded with the hooks' declared state, in the table's plain data.
// Run from src:  lobster test_hooks.lobster -- [map_id]   (reed_meadow)
// Prints "N passed, M failed" and exits 1 on a failure.

let args = plain_args(command_line_arguments())
let map_id = if args.length > 0: args[0] else: "reed_meadow"
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let sides = at(load_json("../tests/units/plain.json"), "sides").a
for(sides) side:
    for(glist(side, "units")) u:
        if rstr(u, "slot") == "infantry": set(u, "tick", jbool(true))

def play_match() -> int:
    reset_world()
    setup_world(2026, map_id, sides, rules, [])
    events_on = true
    let bots = map(num_players) p: new_bot(p)
    var h = 0
    while tick < 45 * 1200 and winner < 0:
        for(bots) bot: full_bot_think(bot)
        step()
        if tick % 30 == 0: h = (h * 31 + state_hash()) & ((1 << 40) - 1)
    return h

let h1 = play_match()
print "hooks on {map_id}: winner {winner} at {clock(tick)}, orders {hook_orders_run}, halved hits {hook_hits_halved}, dead {hook_player_cols[col_dead]}, lost {lost[0]} {lost[1]}"
check(winner >= 0, "the match ends with a winner")
check(hook_orders_run > 0, "unit_tick and on_order: units deployed by a pack order")
check(hook_hits_halved > 0, "on_hit: deployed units took less")
check(hook_player_cols[col_dead][0] + hook_player_cols[col_dead][1] > 0, "on_death: the declared state counted the dead")
check(hook_player_cols[col_dead][0] == lost[0] and hook_player_cols[col_dead][1] == lost[1], "on_death ran once for each unit lost")
let h2 = play_match()
check(h1 == h2, "the same match again ({h1}, {h2})")

// Declared state is saved, loaded and hashed.
reset_world()
setup_world(2026, map_id, sides, rules, [])
events_on = true
var bots = map(num_players) p: new_bot(p)
def run_ticks(n:int) -> [int]:
    return map(n):
        for(bots) bot: full_bot_think(bot)
        step()
        state_hash()
run_ticks(13000)
let deployed_then = copy(hook_unit_cols[col_deployed])
check(exists(deployed_then) v: v != 0, "some are deployed at the save")
let path = "test_hooks.sav"
check(save_world(path, bots), "the match saves")
let want = run_ticks(800)
reset_world()
bots = load_world(path)
delete_file(path)
check(hook_unit_cols.length == 1 and equal(hook_unit_cols[0], deployed_then), "the column came back ({hook_unit_cols.length})")
let got = run_ticks(800)
check(equal(want, got), "800 ticks after a load match")
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
