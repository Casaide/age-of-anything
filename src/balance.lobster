// Balance by simulation in Lobster (gen/balance.lobster). Run from src:
//   lobster balance.lobster -- rr <age> [combat_rule=value ...] ["+prompt" ...] ["prompt" ...] [shard:<i>/<n>]
//       the equal-cost round robin, tests/balance.gd's table: each unit's win rate, how far off the mean
//       (OUT past 20%), its cost, hp and attack; how often counters won their same-race counter fights.
//       A rule override (kite_gap=1500) sets rules.combat; "+prompt" adds a race to the five, a bare prompt
//       replaces them. shard:<i>/<n>: every n-th fight, printed as "@@ i,j result" for
//       `shards.sh balance.lobster rr <age> ... [jobs=N]` to put the table together (combine <logs>).
//   lobster balance.lobster -- auto <age> <rounds> ["prompt" ...]   auto-balance: prices from the fights
// With no prompts: tests/balance.gd's five races.
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
import gen.balance

let PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights" ]

let TOLERANCE = 20  // percent off the mean
// Within one race, who should beat whom at equal cost (the genre's counters).
let COUNTERS = [ [ "spear", "large" ], [ "large", "archer" ], [ "skirmisher", "archer" ], [ "archer", "spear" ],
                 [ "infantry", "spear" ], [ "infantry", "skirmisher" ], [ "archer", "infantry" ],
                 [ "mounted_archer", "infantry" ], [ "skirmisher", "mounted_archer" ], [ "spear", "mounted_archer" ], [ "scout", "skirmisher" ], [ "spear", "scout" ] ]

let args0 = command_line_arguments()
def shard_arg(xs:[string]) -> int, int:
    for(xs) a:
        if starts_with(a, "shard:"):
            let i, n = split_string(a.substring(6, a.length - 6), "/")
            return string_to_int(i), string_to_int(n)
    return 0, 1
def combine_index(xs:[string]) -> int:
    for(xs) a, n:
        if a == "combine": return n
    return -1
let shard, shards = shard_arg(args0)
let combine_at = combine_index(args0)
let logs = if combine_at >= 0: args0.slice(combine_at + 1, -1) else: []::string
let args = filter(if combine_at >= 0: args0.slice(0, combine_at) else: args0) a: not starts_with(a, "shard:")
lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let mode = args[0]
let age = string_to_int(args[1])
let first = if mode == "auto": 3 elif mode == "hash": 99 else: 2
let extra = if args.length > first: args.slice(first, -1) else: []::string
let overrides = filter(extra) a: find_string(a, "=") >= 0
let plus = map(filter(extra) a: starts_with(a, "+")) a: a.substring(1, a.length - 1)
let bare_prompts = filter(extra) a: find_string(a, "=") < 0 and not starts_with(a, "+")
let prompts = copy(if bare_prompts.length: bare_prompts else: PROMPTS)
for(plus) p: prompts.push(p)
for(overrides) o:
    let key, val = split_string(o, "=")
    set(at(rules, "combat"), key, jint(string_to_int(val)))
    if shard == 0 and combine_at < 0: print "trying combat.{key} = {val}"
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
if mode == "hash":  // one fight's state hash every tick: hash <age> <a> <b> [dump tick]
    let units = rr_units(races, age)
    let dumpat = if args.length > 4: string_to_int(args[4]) else: -1
    rr_fight(races, bare_rules(rules), age, units[string_to_int(args[2])], units[string_to_int(args[3])], true, dumpat)
elif mode == "pairs":  // every fight's result, one line a pair (rr_dump.gd's format)
    let units = rr_units(races, age)
    let bare = bare_rules(rules)
    for(units.length) i:
        var j = i + 1
        while j < units.length:
            print "{i},{j} {rr_fight(races, bare, age, units[i], units[j])}"
            j++
elif mode == "rr":
    let units = rr_units(races, age)
    // Every pair's result: fought here (every shards-th pair from shard), or read from the shards' logs.
    let results = map(units.length * units.length): 0
    if combine_at >= 0:
        for(logs) path:
            for(tokenize(read_file(path) or "", "\n", "")) line:
                let ws = tokenize(line, " ", "")
                if ws.length == 3 and ws[0] == "@@":
                    let i, j = split_string(ws[1], ",")
                    results[string_to_int(i) * units.length + string_to_int(j)] = string_to_int(ws[2])
    else:
        let bare = bare_rules(rules)
        var k = 0
        for(units.length) i:
            var j = i + 1
            while j < units.length:
                if k % shards == shard:
                    let r = rr_fight(races, bare, age, units[i], units[j])
                    results[i * units.length + j] = r
                    if shards > 1: print "@@ {i},{j} {r}"
                k++
                j++
    if shards == 1:
        // The tally (round_robin.gd's): win rates, the mean, counters won.
        let wins = map(units.length): 0
        let played = map(units.length): 0
        var counter_won = 0
        var counter_fights = 0
        for(units.length) i:
            var j = i + 1
            while j < units.length:
                let r = results[i * units.length + j]
                if units[i].race == units[j].race:
                    for(COUNTERS) pair:
                        if (units[i].slot == pair[0] and units[j].slot == pair[1]) or (units[j].slot == pair[0] and units[i].slot == pair[1]):
                            counter_fights++
                            let i_counters = units[i].slot == pair[0]
                            if (r > 0 and i_counters) or (r < 0 and not i_counters): counter_won++
                if r != 0:
                    played[i]++
                    played[j]++
                    if r > 0: wins[i]++ else: wins[j]++
                j++
        let rates = map(units.length) k: wins[k] * 100 / max(1, played[k])
        var total = 0
        for(rates) r: total += r
        let mean = total / max(1, units.length)
        let order = map(units.length) k: k
        insertion_sort(order) x, y: abs(rates[x] - mean) > abs(rates[y] - mean)
        var off = 0
        print "\nAge {age}, {units.length} units, {units.length - 1} fights each, mean win rate {mean}% ({int(seconds_elapsed() - t0)} s)"
        def pad(s:string, n:int, left:bool) -> string:
            var out = s
            while out.length < n: out = if left: " " + out else: out + " "
            return out
        for(order) k:
            let u = units[k]
            let dev = (rates[k] - mean) * 100 / max(1, mean)
            let flag = if abs(dev) > TOLERANCE: "  OUT" else: ""
            if flag != "": off++
            // The eval of the line step it fields in this age (round_robin.gd recipe_at).
            var e = jobj()
            for(glist(races[u.race], "units")) ru:
                if rstr(at(ru, "recipe"), "slot") == u.slot:
                    var st = glist(ru, "line")[0]
                    for(glist(ru, "line")) l:
                        if as_int(at(l, "age")) <= age: st = l
                    e = at(st, "eval")
            let c = gobj(e, "cost")
            let cost = gint(c, "food", 0) + gint(c, "wood", 0) + gint(c, "stone", 0)
            let dmg = get(e, "damage")
            let pct = rr_price_pct.get(price_key(races, u), 100)
            print pad("{rates[k]}%", 5, true) + "  " + pad((if dev >= 0: "+" else: "") + "{dev}%", 5, true) + "  " + pad(u.label, 48, false) + " cost " + pad(string(cost), 3, true) +
                "  hp " + pad(string(gint(e, "hp", 0)), 3, true) + "  atk " + pad(string(gint(e, "attack", 0)), 2, true) + " " + (if dmg: jv_plain(dmg) else: "") + flag +
                (if pct != 100: "  (price {pct}%)" else: "")
        print "\n{off} of {units.length} units more than {TOLERANCE}% off the mean; counters won {counter_won * 100 / max(1, counter_fights)}% of same-race counter fights"
else:
    let rounds = string_to_int(args[2])
    auto_balance(races, rules, age, rounds, 10) round, units, rates, mean, off:
        print "Round {round + 1}: mean {mean}%, {off} of {units.length} off by more than 10 ({seconds_elapsed() - t0} s so far, {rr_fights} fights)"
        table(units, rates, mean)
