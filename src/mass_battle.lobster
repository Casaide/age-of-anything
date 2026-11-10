// Mass battles at equal cost (tests/mass_battle.gd, ported): about 30 against 30, mixed armies, both
// sides attack-moving on an open map, every match fought twice with the sides swapped. For each race of
// the balance prompts, in one age (unit lines upgraded to it): archers against cavalry, skirmishers and
// spears; spears and skirmishers against cavalry; mixed armies; swordsmen; mounted archers and scouts; with
// heroes from age 2; siege engines, the unique unit and war beasts in age 3. Prints win rates and the value
// each side has left. Deterministic.
// Run from src:
//   lobster mass_battle.lobster -- [age] [budget] [combat_rule=value ...] [beasts] [heroes] [shard:<i>/<n>]
//   shards.sh mass_battle.lobster [age] [budget] ... [jobs=N]        the matches side by side, printed in order
// (age 2 and budget 1500 by default; beasts / heroes: just those matches)

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
import testkit.kit

let RACES = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights" ]

class MB:
    label:string
    a:[string]
    b:[string]

// [label, side A slots, side B slots]: the budget is split evenly over a side's slots.
let MATCHES = [
    MB { "archers v cavalry", [ "archer" ], [ "large" ] },
    MB { "archers v skirmishers", [ "archer" ], [ "skirmisher" ] },
    MB { "archers v spears", [ "archer" ], [ "spear" ] },
    MB { "spears v cavalry", [ "spear" ], [ "large" ] },
    MB { "skirmishers v cavalry", [ "skirmisher" ], [ "large" ] },
    MB { "spear+archer v spear+cavalry", [ "spear", "archer" ], [ "spear", "large" ] },
    MB { "archers v mixed", [ "archer" ], [ "spear", "skirmisher", "large" ] },
    MB { "archers v spear+archer", [ "archer" ], [ "spear", "archer" ] },
    MB { "swords v spears", [ "infantry" ], [ "spear" ] },
    MB { "swords v skirmishers", [ "infantry" ], [ "skirmisher" ] },
    MB { "archers v swords", [ "archer" ], [ "infantry" ] },
    MB { "swords v cavalry", [ "infantry" ], [ "large" ] },
    MB { "sword+archer v spear+cavalry", [ "infantry", "archer" ], [ "spear", "large" ] },
    MB { "horse archers v swords", [ "mounted_archer" ], [ "infantry" ] },
    MB { "horse archers v spears", [ "mounted_archer" ], [ "spear" ] },
    MB { "skirmishers v horse archers", [ "skirmisher" ], [ "mounted_archer" ] },
    MB { "cavalry v horse archers", [ "large" ], [ "mounted_archer" ] },
    MB { "horse archers v archers", [ "mounted_archer" ], [ "archer" ] },
    MB { "scouts v skirmishers", [ "scout" ], [ "skirmisher" ] },
    MB { "scouts v archers", [ "scout" ], [ "archer" ] },
    MB { "spears v scouts", [ "spear" ], [ "scout" ] },
    MB { "cavalry v scouts", [ "large" ], [ "scout" ] } ]
// The Castle's unique unit (age 3) against the lines of its own race, at equal cost.
let UNIQUE_MATCHES = [
    MB { "unique v spears", [ "unique" ], [ "spear" ] },
    MB { "unique v swords", [ "unique" ], [ "infantry" ] },
    MB { "unique v archers", [ "unique" ], [ "archer" ] },
    MB { "unique v cavalry", [ "unique" ], [ "large" ] },
    MB { "unique v spear+archer", [ "unique" ], [ "spear", "archer" ] } ]
// Siege (age 3): engines behind a screen of spears against what they should beat and what should beat them.
let SIEGE_MATCHES = [
    MB { "catapult+spear v archers", [ "catapult", "spear" ], [ "archer" ] },
    MB { "catapult+spear v spear+archer", [ "catapult", "spear" ], [ "spear", "archer" ] },
    MB { "bolt+spear v spears", [ "bolt_thrower", "spear" ], [ "spear" ] },
    MB { "bolt+spear v spear+cavalry", [ "bolt_thrower", "spear" ], [ "spear", "large" ] },
    MB { "catapults v cavalry", [ "catapult" ], [ "large" ] },
    MB { "bolt throwers v cavalry", [ "bolt_thrower" ], [ "large" ] } ]
// War beasts (age 3): they should beat foot soldiers and lose to spears, skirmishers and bolt throwers.
let BEAST_MATCHES = [
    MB { "beasts v swords", [ "war_beast" ], [ "infantry" ] },
    MB { "beasts v archers", [ "war_beast" ], [ "archer" ] },
    MB { "beasts v cavalry", [ "war_beast" ], [ "large" ] },
    MB { "spears v beasts", [ "spear" ], [ "war_beast" ] },
    MB { "skirmishers v beasts", [ "skirmisher" ], [ "war_beast" ] },
    MB { "bolt+spear v beasts", [ "bolt_thrower", "spear" ], [ "war_beast" ] },
    MB { "beast+archer v spear+archer", [ "war_beast", "archer" ], [ "spear", "archer" ] } ]
// Heroes (age 2 and on): every hero of the race once, the rest of the budget in soldiers, against soldiers
// at equal cost (twice the budget).
let HERO_MATCHES = [
    MB { "heroes+spears v spears", [ "hero", "spear" ], [ "spear" ] },
    MB { "heroes+swords v swords", [ "hero", "infantry" ], [ "infantry" ] },
    MB { "heroes+archers v archers", [ "hero", "archer" ], [ "archer" ] },
    MB { "heroes+swords v spear+archer", [ "hero", "infantry" ], [ "spear", "archer" ] },
    MB { "heroes+spears v cavalry", [ "hero", "spear" ], [ "large" ] },
    MB { "heroes+archers v swords", [ "hero", "archer" ], [ "infantry" ] } ]
let MB_LIMIT = 4000           // ticks (3:20)
let FRONT = [ 22000, 42000 ]  // x of each side's front line
let MID_Y = 32000
let GAP = 900  // between bodies in the starting blocks
let RANKS = [ "large", "ram", "unique", "scout", "infantry", "spear", "skirmisher", "mounted_archer", "archer", "bolt_thrower", "catapult" ]

class Fight:
    result:int  // +1 A won, -1 B won, 0 a draw (by value left)
    n:[int]     // units A, B
    left_pct:[int]
    ticks:int
    shots:int
    missed:int
    total:[int]

def has_line(race:JV, slot:string) -> bool: return exists(glist(race, "units")) u: rstr(at(u, "recipe"), "slot") == slot

def rank(slot:string) -> int: return find_index(RANKS, slot)

// One battle: side A (player 0, or player 1 when `swap`) fields `sa`, side B `sb`, each with `budget` split
// evenly over its slots.
def fight(rules:JV, age:int, budget:int, race:JV, sa:[string], sb:[string], swap:bool) -> Fight:
    let bare = deep_copy(rules)
    let st = at(at(bare, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))
    set(bare, "animals", jbool(false))
    new_world(1, "flat_test", [ race, race ], bare, [])
    for(2) p: rr_in_age(p, age)
    let sides = if swap: [ sb, sa ] else: [ sa, sb ]
    let cost = map(t_cost.length) k: sum_of(t_cost[k])
    let total = [ 0, 0 ]
    let n = [ 0, 0 ]
    for(2) p:
        let slots = sides[p]
        let dir = if p == 0: 1 else: -1
        var row = 0
        // Melee in front, shooters behind: the cheap blocks first.
        let order = copy(slots)
        insertion_sort(order) x, y: rank(x) < rank(y)
        var spent = 0
        for(order) slot:
            if slot == "hero":  // every hero of the race, once
                for(hero_types) hk:
                    if t_player[hk] == p:
                        spawn_kind(p, hk, 1, FRONT[p] - dir * row * GAP, MID_Y + (n[p] % 8 - 4) * GAP + GAP / 2)
                        spent += cost[hk]
                        total[p] += cost[hk]
                        n[p]++
                row++
            else:
                let k = type_of_slot(p, slot)
                assert k >= 0
                let c = cost[k]
                let lines_n = slots.length - (if find_index(slots, "hero") >= 0: 1 else: 0)
                let count = max(1, ((budget - spent) / lines_n + c / 2) / c)
                for(count) q:
                    spawn_kind(p, k, 1, FRONT[p] - dir * (row + q / 8) * GAP, MID_Y + (q % 8 - 4) * GAP + GAP / 2)
                row += (count + 7) / 8
                total[p] += count * c
                n[p] += count
    wstep()
    while u_id.length < n[0] + n[1]: wstep()
    for(2) p:
        let ids = []::int
        for(u_owner) o, i:
            if o == p: ids.push(u_id[i])
        issue_cmd(p, CMD_ATTACK_MOVE, ids, FRONT[1 - p], MID_Y, 0, 0)
    var left = [ 0, 0 ]
    var shots_n = 0
    var missed = 0
    while tick < MB_LIMIT:
        wstep()
        for(events) e:
            if e.kind == EV_SHOT: shots_n++
            elif e.kind == EV_MISS: missed++
        left = [ 0, 0 ]
        for(u_owner) o, i: left[o] += cost[u_kind[i]]
        if left[0] == 0 or left[1] == 0: break
    let a = if swap: 1 else: 0
    let pct = [ left[a] * 100 / total[a], left[1 - a] * 100 / total[1 - a] ]
    return Fight { if pct[0] > pct[1]: 1 elif pct[1] > pct[0]: -1 else: 0, [ n[a], n[1 - a] ], pct, tick, shots_n, missed, [ total[a], total[1 - a] ] }

let args0 = command_line_arguments()
let all_args = plain_args(args0)
let combine_at = find_index(all_args, "combine")
let own_args = if combine_at >= 0: all_args.slice(0, combine_at) else: all_args
let beasts = find_index(own_args, "beasts") >= 0
let heroes_only = find_index(own_args, "heroes") >= 0
let args = filter(own_args) a: a != "serial" and a != "beasts" and a != "heroes"
let age = if args.length > 0: string_to_int(args[0]) else: 2
let budget = if args.length > 1: string_to_int(args[1]) else: 1500
var matches = copy(MATCHES)
if age >= 2: for(HERO_MATCHES) m: matches.push(m)
if age >= 3: for([ SIEGE_MATCHES, UNIQUE_MATCHES, BEAST_MATCHES ]) ms: for(ms) m: matches.push(m)
if beasts: matches = BEAST_MATCHES
if heroes_only: matches = HERO_MATCHES
let shard, shards = shard_of(args0)
let t0 = seconds_elapsed()

if combine_at >= 0:
    // The shards' blocks ("@@ <match> <line>"), in match order.
    let keyed = []::string
    for(all_args.slice(combine_at + 1, -1)) path:
        for(tokenize(read_file(path) or "", "\n", "")) line:
            if starts_with(line, "@@ "): keyed.push(line)
    def key_of(l:string) -> int: return string_to_int(tokenize(l, " ", "")[1])
    let order = map(keyed.length) k: k
    insertion_sort(order) x, y: key_of(keyed[x]) * 100000 + x < key_of(keyed[y]) * 100000 + y
    print "Mass battles, age {age}, budget {budget} a side, each fought both ways round"
    for(order) k:
        let l = keyed[k]
        let sp = find_string(l, " ", 3)
        print l.substring(sp + 1, l.length - sp - 1)
else:
    lib_load("../data")
    id_load("../data")
    let rules = load_rules("default")
    for(args.slice(min(2, args.length), -1)) arg:
        let key, val = split_string(arg, "=")
        set(at(rules, "combat"), key, jint(string_to_int(val)))
        if shard == 0: print "trying combat.{key} = {val}"
    let races = map(RACES) p: generate(p, rules, 0)
    if shards == 1: print "Mass battles, age {age}, budget {budget} a side, each fought both ways round"
    for(matches) m, mk:
        if mk % shards == shard:
            var wins = 0
            var losses = 0
            var left_a = 0
            var left_b = 0
            var fights = 0
            let rows = []::string
            for(races) r:
                var ok = true
                for([ m.a, m.b ]) side: for(side) slot: if slot != "hero" and not has_line(r, slot): ok = false
                if ok:  // (a race may lack a line: centaurs have no mounted archers)
                    let doubled = find_index(m.a, "hero") >= 0 or find_index(m.b, "hero") >= 0
                    for(2) swap:
                        let res = fight(rules, age, budget * (if doubled: 2 else: 1), r, m.a, m.b, swap == 1)
                        fights++
                        left_a += res.left_pct[0]
                        left_b += res.left_pct[1]
                        if res.result > 0: wins++
                        elif res.result < 0: losses++
                        let name = rstr(r, "name")
                        rows.push("    " + pad_right(name.substring(0, min(26, name.length)), 26) + " {res.n[0]} v {res.n[1]}  " +
                                  (if res.result > 0: "A" elif res.result < 0: "B" else: "=") + "  left " + pad_left(string(res.left_pct[0]), 3) + "% v " +
                                  pad_left(string(res.left_pct[1]), 3) + "%  ({res.ticks / 20}s)  shots {res.shots}, {res.missed * 100 / max(1, res.shots)}% missed  value {res.total[0]} v {res.total[1]}")
            let head = "\n" + pad_right(m.label, 30) + " A wins " + pad_left(string(wins), 2) + " of {fights} (B {losses})   value left: A " +
                pad_left(string(left_a / max(1, fights)), 3) + "%  B " + pad_left(string(left_b / max(1, fights)), 3) + "%"
            if shards > 1:
                for(tokenize(head, "\n", "")) l: print "@@ {mk} " + l
                for(rows) l: print "@@ {mk} " + l
            else:
                print head
                for(rows) l: print l
    print "\n({int(seconds_elapsed() - t0)} s)"
