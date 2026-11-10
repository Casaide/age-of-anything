// Milestone 14's balance check (tests/race_matches.gd, ported): a round robin of whole bot-vs-bot matches
// between races, each with its bonuses, own research, lacks and ability on; both seatings of every pair.
// Prints each match (winner, length, webs thrown, own research bought), each race's wins and the lengths.
// Run from src:
//   lobster race_matches.lobster -- [map_id] [prompt ...] [shard:<i>/<n>]     (reed_meadow; six races)
//   lobster race_matches.lobster -- match <map_id> "<prompt A>" "<prompt B>"   one match
//   shards.sh race_matches.lobster [map_id] [prompt ...] [jobs=N]           the matches side by side
// A prompt's underscores read as spaces (swamp_frogs), for shell scripts. With shard:<i>/<n> it plays every
// n-th match and prints them as "@@" lines; `combine <logs>` (shards.sh) makes the tables from them.

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
import testkit.kit

let SEED = 11
let LIMIT = 20 * 60 * 35  // 35 minutes, then a draw
let RACES = [ "swamp frogs", "sewer rats", "imperial humans", "spooky spiders", "forest beetles", "steppe centaurs" ]

class Played:
    a:string
    b:string
    winner:int
    end_tick:int
    webs:[int]
    own:[string]  // per side: its own research bought, "id m:ss, ..."

def spaced(s:string) -> string: return concat_string(tokenize(s, "_", ""), " ")

lib_load("../data")
id_load("../data")
let rules = load_rules("default")

def play_match(map_id:string, pa:string, pb:string) -> Played:
    let races = [ generate(pa, rules, 0), generate(pb, rules, 0) ]
    new_world(SEED, map_id, races, rules, [])
    let sides = [ full_side(0), full_side(1) ]
    let webs_n = [ 0, 0 ]
    let own = [ []::string, []::string ]
    let mine = map(2) p: gstrs(su_sides[p], "research")
    let wt = new_watch()
    while tick < LIMIT and winner < 0:
        think_all(sides)
        wstep()
        var n = 0
        while n < webs.length:
            let p = webs[n]
            if p < 2 and webs[n + 4] == tick - 1 + ab_lasts[p]: webs_n[p]++
            n += WEB
        let hp = watch_after(wt)
        for(hp.research_p) p, k:
            let id = research[hp.research_k[k]].id
            if p < 2 and find_index(mine[p], id) >= 0: own[p].push(id + " " + clock(tick))
    return Played { pa, pb, winner, tick, webs_n, map(own) o: concat_string(o, ", ") }

def line_of(m:Played) -> string:
    let result = if m.winner < 0: "draw" else: (if m.winner == 0: m.a else: m.b) + " wins"
    return "  " + pad_right(m.a + " vs " + m.b, 40) + "  {result} at {clock(m.end_tick)}   webs {m.webs}   own research [" + m.own[0] + "] [" + m.own[1] + "]"

// "@@" lines carry a match through a log: fields split by tabs.
def to_log(m:Played) -> string: return concat_string([ "@@", m.a, m.b, string(m.winner), string(m.end_tick), string(m.webs[0]), string(m.webs[1]), m.own[0], m.own[1] ], "\t")

def from_log(line:string) -> Played?:
    let f = tokenize(line, "\t", "")
    if f.length < 7 or f[0] != "@@": return nil
    return Played { f[1], f[2], string_to_int(f[3]), string_to_int(f[4]), [ string_to_int(f[5]), string_to_int(f[6]) ],
                    [ if f.length > 7: f[7] else: "", if f.length > 8: f[8] else: "" ] }

def tables(map_id:string, races:[string], played:[Played]):
    print "\n== matches ({map_id})"
    let wins = map(races.length): 0
    let games = map(races.length): 0
    var draws = 0
    let minutes = []::int
    for(played) m:
        let ia = find_index(races, m.a)
        let ib = find_index(races, m.b)
        if ia >= 0: games[ia]++
        if ib >= 0: games[ib]++
        if m.winner == 0 and ia >= 0: wins[ia]++
        elif m.winner == 1 and ib >= 0: wins[ib]++
        elif m.winner < 0: draws++
        minutes.push(m.end_tick / 1200)
        print line_of(m)
    print "\n== win rates"
    for(races) r, k:
        print "  " + pad_right(r, 20) + " " + pad_left(string(wins[k]), 2) + " / " + pad_left(string(games[k]), 2) + "  ({100 * wins[k] / max(1, games[k])}%)"
    insertion_sort(minutes) x, y: x < y
    print "draws {draws}; minutes {minutes}"

let args0 = command_line_arguments()
let args = plain_args(args0)
let t0 = seconds_elapsed()
if args.length and args[0] == "match":
    print line_of(play_match(args[1], spaced(args[2]), spaced(args[3])))
else:
    let combine_at = find_index(args, "combine")
    let own_args = if combine_at >= 0: args.slice(0, combine_at) else: args
    let map_id = if own_args.length: own_args[0] else: "reed_meadow"
    let races = if own_args.length > 1: map(own_args.slice(1, -1)) a: spaced(a) else: RACES
    let pairs = []::int2
    for(races.length) a:
        for(races.length) b:
            if a != b: pairs.push(int2 { a, b })
    let played = []::Played
    if combine_at >= 0:
        for(args.slice(combine_at + 1, -1)) path:
            for(tokenize(read_file(path) or "", "\n", "")) line:
                let m = from_log(line)
                if m: played.push(m)
        // in the round robin's order
        insertion_sort(played) x, y: find_index(races, x.a) * 100 + find_index(races, x.b) < find_index(races, y.a) * 100 + find_index(races, y.b)
        tables(map_id, races, played)
    else:
        let shard, shards = shard_of(args0)
        for(pairs) pr, n:
            if n % shards == shard:
                let m = play_match(map_id, races[pr.x], races[pr.y])
                played.push(m)
                if shards > 1: print to_log(m)
                print line_of(m) + "  ({int(seconds_elapsed() - t0)} s so far)"
        if shards == 1: tables(map_id, races, played)
    print "({int(seconds_elapsed() - t0)} s)"
