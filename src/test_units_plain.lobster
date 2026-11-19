import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
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
import gen.modes
import gen.start

// A match from a table of unit types in data, with no generator in the program (the sim's side of the seam, #195):
// the bots play it to a winner.
// Run from src:  lobster test_units_plain.lobster -- [map_id]   (reed_meadow)
// Prints "N passed, M failed" and exits 1 on a failure.

var passes = 0
var failures = 0
def check(ok:bool, what:string):
    if ok: passes++
    else:
        failures++
        print "FAIL: " + what

let args = command_line_arguments()
let map_id = if args.length > 0: args[0] else: "reed_meadow"
lib_load("../data")
let rules = load_rules("default")
let sides = at(load_json("../tests/units/plain.json"), "sides").a
setup_world(2026, map_id, sides, rules, [])
events_on = true
let bots = map(num_players) p: new_bot(p)
check(t_slot.length >= 5, "each side has its lines ({t_slot.length} types)")
var most_army = 0
while tick < 45 * 1200 and winner < 0:
    for(bots) bot: full_bot_think(bot)
    step()
    var army = 0
    for(u_kind) k: if not t_worker[k] and t_animal[k] == 0: army++
    most_army = max(most_army, army)
print "plain table on {map_id}: winner {winner} at {tick / 1200} min, the most soldiers at once {most_army}, lost {lost[0]} and {lost[1]}"
check(winner >= 0, "the match ends with a winner")
check(most_army > 0 and lost[0] + lost[1] > 0, "the sides train soldiers and fight")
print "\n{passes} passed, {failures} failed"
if failures > 0: set_exit_code(1)
