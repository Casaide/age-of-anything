// Balance by simulation in Lobster (gen/balance.lobster). Run from tests/lobster_spike:
//   lobster --mir balance.lobster -- rr <age> ["prompt" ...]          the equal-cost round robin (tests/balance.gd's table)
//   lobster --mir balance.lobster -- auto <age> <rounds> ["prompt" ...]   auto-balance: prices from the fights
// With no prompts: tests/balance.gd's five races.
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
import gen.balance

let PROMPTS = ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights"]

let args = command_line_arguments()
lib_load("../../data")
id_load("../../data")
let rules = load_rules("default")
let mode = args[0]
let age = string_to_int(args[1])
let first = if mode == "auto": 3 elif mode == "hash": 99 else: 2
let prompts = if args.length > first: args.slice(first, -1) else: PROMPTS
let t_gen = seconds_elapsed()
let races = map(prompts) p: generate(p, rules, 0)
print "{races.length} races in {(seconds_elapsed() - t_gen) * 1000.0} ms"

def table(units:[RRUnit], rates:[int], mean:int):
    let order = map(units.length) k: k
    insertion_sort(order) x, y: abs(rates[x] - mean) > abs(rates[y] - mean)
    for(order) k:
        let pct = rr_price_pct.get(price_key(races, units[k]), 100)
        print "  {rates[k]}%  {units[k].label}" + (if pct != 100: "  (price {pct}%)" else: "")

let t0 = seconds_elapsed()
if mode == "hash":   // one fight's state hash every tick: hash <age> <a> <b> [dump tick]
    rr_trace = true
    if args.length > 4: rr_dump_at = string_to_int(args[4])
    let units = rr_units(races, age)
    rr_fight(races, bare_rules(rules), age, units[string_to_int(args[2])], units[string_to_int(args[3])])
elif mode == "pairs":   // every fight's result, one line a pair (rr_dump.gd's format)
    let units = rr_units(races, age)
    let bare = bare_rules(rules)
    for(units.length) i:
        var j = i + 1
        while j < units.length:
            print "{i},{j} {rr_fight(races, bare, age, units[i], units[j])}"
            j++
elif mode == "rr":
    let units = rr_units(races, age)
    let rates, mean = round_robin(races, bare_rules(rules), age, units)
    print "Age {age}, {units.length} units, {units.length - 1} fights each, mean win rate {mean}% ({seconds_elapsed() - t0} s, {rr_fights} fights, {rr_ticks} ticks)"
    table(units, rates, mean)
else:
    let rounds = string_to_int(args[2])
    auto_balance(races, rules, age, rounds, 10) round, units, rates, mean, off:
        print "Round {round + 1}: mean {mean}%, {off} of {units.length} off by more than 10 ({seconds_elapsed() - t0} s so far, {rr_fights} fights)"
        table(units, rates, mean)
