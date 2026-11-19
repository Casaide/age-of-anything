import from "../creel/src"
import std
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
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import hooks.economy
import hooks.hunger
import gen.scenario_out
import gen.reset
import gen.save

// Saving and loading a match (gen/save.lobster): two bots play, the match is saved part way, play
// goes on and every tick's hash is kept; then the world is reset, the save loaded and the same ticks
// played again: every hash must match (the bots' minds come back with it).
// Run from src:  lobster save_check.lobster -- [map] [ticks before] [ticks after]
let args = command_line_arguments()
let map_id = if args.length > 0: args[0] else: "reed_meadow"
let before = if args.length > 1: string_to_int(args[1]) else: 6000
let after = if args.length > 2: string_to_int(args[2]) else: 3000
let path = "save_check.sav"  // (Lobster writes only under its own folders)
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
set(rules, "animals", jbool(true))
let races = map([ "sewer rats with cheese hammers", "frogs with spears" ]) p: generate(p, rules, 0)
setup_match(20261010, map_id, races, rules, [])
events_on = true
var bots = map(num_players) p: new_bot(p)
def play(n:int) -> [int]:
    let hashes = []::int
    for(n):
        for(bots) bot: full_bot_think(bot)
        step()
        hashes.push(state_hash())
    return hashes
play(before)
let t0 = seconds_elapsed()
assert save_world(path, bots)
let save_ms = (seconds_elapsed() - t0) * 1000.0
let want = play(after)
let units_then = u_id.length
reset_world()
let t1 = seconds_elapsed()
bots = load_world(path)
let load_ms = (seconds_elapsed() - t1) * 1000.0
assert bots.length == num_players
let got = play(after)
var same = 0
var first = -1
for(want) h, n:
    if got[n] == h: same++
    elif first < 0: first = n
let size = (read_file(path, true) or "").length
print "{map_id}: saved at tick {before} ({save_ms} ms, {size / 1024} KB), loaded in {load_ms} ms; {same} of {after} ticks after it match, {u_id.length} units (were {units_then})"
delete_file(path)
if same != after: print "FAILED: first differs {first} ticks after the load"
