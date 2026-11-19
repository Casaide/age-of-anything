// A 2v2 between four bots on a four-start map (tests/test_2v2.gd, ported): the teams come from the map
// (`teams`: starts 0 and 2 against 1 and 3). Checks that it runs, that teammates never hit each other
// while the teams fight (a catapult's stone splashing its own side aside), and that the match ends;
// reports how long it took and the tick time.
// Run from src:  lobster test_2v2.lobster -- [map_id] [minutes]   (reed_meadow_2v2, 45)
// Prints "N passed, M failed" and exits 1 on a failure.
// A hit counts as splash when it follows a stone's (or a charge's) landing by the same thrower in the
// tick's events (siege.lobster lists the landing, then what it hurt), where GDScript flags the hit.

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
import gen.reset
import testkit.kit

let SEED = 2026
let PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites" ]

// The team of a unit or building id (-1 for animals, bridges or the gone).
def team_of(id:int) -> int:
    let i = index_of(id)
    if i >= 0:
        if u_owner[i] >= 4 or t_animal[u_kind[i]] != 0: return -1  // wild, or a herd animal
        return teams[u_owner[i]]
    let b = b_index_of(id)
    return if b >= 0: teams[b_owner[b]] else: -1

let args = plain_args(command_line_arguments())
let map_id = if args.length > 0: args[0] else: "reed_meadow_2v2"
let minutes = if args.length > 1: string_to_int(args[1]) else: 45
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let races = map(PROMPTS) p: generate(p, rules, 0)
let map_teams = map(glist(load_json("../data/maps/" + map_id + ".json"), "teams")) v: as_int(v)
check(map_teams.length == 4 and equal(map_teams, [ 0, 1, 0, 1 ]), "{map_id} has four starts in two teams ({map_teams})")
new_world(SEED, map_id, races, rules, map_teams)
let sides = map(4) p: full_side(p)
var friendly = 0
var splashed = 0
var across = 0
let kills = [ 0, 0 ]  // units each team killed
var spent = 0.0
var worst = 0.0
print "2v2 on {map_id}: " + concat_string(map(4) p: "P{p} " + rstr(races[p], "name") + " (team {teams[p]})", ", ")
while tick < minutes * 1200 and winner < 0:
    think_all(sides)
    let t0 = seconds_elapsed()
    wstep()
    let dt = seconds_elapsed() - t0
    spent += dt
    worst = max(worst, dt)
    var splash_by = -1
    for(events) e:
        if e.kind == EV_SPLASH: splash_by = e.a
        elif e.kind == EV_HIT:
            let a = team_of(e.a)
            let b = team_of(e.b)
            if a >= 0 and b >= 0:
                if a == b and e.a == splash_by: splashed++  // a catapult's stone hurts its own side too (rules splash_friend_pct)
                elif a == b: friendly++
                else: across++
        else:
            splash_by = -1
            if e.kind == EV_DIE and e.b == 0:
                let o = owner_of_id(e.a)
                if o >= 0 and o < 4: kills[1 - teams[o]]++
    if tick % (1200 * 5) == 0:
        var line = "  " + clock(tick)
        for(4) p:
            var army = 0
            var workers = 0
            for(u_owner) o, i:
                if o == p:
                    if t_worker[u_kind[i]]: workers++ else: army++
            line += "  | P{p} age {ages[p]} {workers}w {army}s lost {lost[p]}" + (if defeated[p] > 0: " OUT" else: "")
        print line
let avg_ms = spent * 1000.0 / max(1, tick)
print "ended at {clock(tick)}, winner team {winner}; units killed by team 0: {kills[0]}, by team 1: {kills[1]}; hits across teams {across}, between teammates {friendly}; tick " +
    fixed_str(avg_ms, 2) + " ms avg, " + fixed_str(worst * 1000.0, 1) + " worst"
check(friendly == 0, "teammates never strike each other, splash aside ({friendly} blows; {splashed} splashed)")
check(across > 0 and kills[0] > 0 and kills[1] > 0, "the teams fight each other ({across} hits)")
check(winner >= 0, "the 2v2 ends with a winner (team {winner} at {clock(tick)})")
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
