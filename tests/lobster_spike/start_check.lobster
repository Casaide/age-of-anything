// The match start made in Lobster against export.gd's (step 6a): the same races, map and rules give
// the same scenario, token by token (everything but the commands and hashes that follow it).
// Run from tests/lobster_spike:
//   lobster start_check.lobster -- roundtrip <scenario>     load a scenario and write it back (the writer's check)
//   lobster start_check.lobster -- setup <scenario> <map> [mode:<id>] [animals] "prompt A" "prompt B"
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
import gen.scenario_out

let SEED = 20261010

// The file's tokens up to the commands.
def file_tokens(path:string) -> [string]:
    let all = filter(tokenize(assert read_file(path), " \n", "")): _.length > 0
    for(all) t, n:
        if t == "CMDS": return all.slice(0, n)
    return all

def first_diff(a:[string], b:[string]) -> int:
    for(min(a.length, b.length)) n:
        if a[n] != b[n]: return n
    return if a.length == b.length: -1 else: min(a.length, b.length)

// The section a token belongs to (the last all-caps word before it), for the report.
def section_of(a:[string], n:int) -> string:
    var k = n
    while k >= 0:
        let t = a[k]
        if t.length >= 3 and t == uppercase(t) and t[0] >= 'A' and t[0] <= 'Z': return t + " (token " + string(n - k) + " in)"
        k--
    return "?"

def report(name:string, want:[string], got:[string]) -> bool:
    let d = first_diff(want, got)
    if d < 0:
        print name + ": the same, " + string(want.length) + " tokens"
        return true
    print name + ": DIFFERS (" + string(want.length) + " / " + string(got.length) + " tokens); the first difference in each section:"
    var last = ""
    var shown = 0
    for(min(want.length, got.length)) n:
        if want[n] != got[n] and shown < 12:
            let sec = section_of(want, n)
            let key = substring(sec, 0, find_string(sec, " "))
            if key != last:
                last = key
                shown++
                let lo = max(0, n - 4)
                print "  at " + string(n) + ", " + sec
                print "    file:  " + concat_string(want.slice(lo, min(10, want.length - lo)), " ")
                print "    ours:  " + concat_string(got.slice(lo, min(10, got.length - lo)), " ")
    return false

def split_ai(toks:[string]) -> [string], [string]:
    for(toks) t, n:
        if t == "AI": return toks.slice(0, n), toks.slice(n, -1)
    return toks, []

let args = command_line_arguments()
let want_all = file_tokens(args[1])
let want, want_ai = split_ai(want_all)
if args[0] == "roundtrip":
    start_world(args[1])
    report("scenario", want, scenario_tokens())
else:
    lib_load("../../data")
    id_load("../../data")
    let rules = load_rules("default")
    var rest = args.slice(3, -1)
    for(rest) x:
        if starts_with(x, "mode:"): set(rules, "mode", jstr(x.substring(5, x.length - 5)))
    rest = filter(rest) x: not starts_with(x, "mode:")
    let animals = rest.length and rest[0] == "animals"
    set(rules, "animals", jbool(animals))
    let prompts = if animals: rest.slice(1, -1) else: rest
    let races = map(prompts) p: generate(p, rules, 0)
    setup_world(SEED, args[2], races, rules, [])
    let ok1 = report("scenario", want, scenario_tokens())
    let ok2 = report("the bots\' config", want_ai, ai_tokens)
    if not (ok1 and ok2): print "FAILED"
