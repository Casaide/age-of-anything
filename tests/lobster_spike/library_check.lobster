// Does the part library cover any race? Random prompts (lexicon words, seeded), each race's every
// unit (every age of its line, its hero) composed in 8 facings through idle, walk, attack, work,
// carrying and the fall: every part it draws looked up in the library. Prints the missing bakes.
// Run from tests/lobster_spike: lobster --mir library_check.lobster -- <library dir> [races] [seed]
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
import view.node
import view.art
import view.unit_view

let DT = 1.0 / 8.0
let KEY = float3 { 1.0, 0.0, 1.0 }
let JOB_TOOLS = [["forage", "tool.basket"], ["chop", "tool.axe"], ["mine", "tool.pick"], ["build", "tool.hammer"]]
let LOADS = ["tool.basket", "load.reeds", "load.stone", "load.gold"]

let args = command_line_arguments()
lib_load("../../data")
id_load("../../data")
load_part_data(args[0])
let n_races = if args.length > 1: string_to_int(args[1]) else: 50
let rng = new_rng(if args.length > 2: string_to_int(args[2]) else: 7)
let rules = load_rules("default")
let words = filter(sorted_strs(lib_lexicon.keys)) w: not has(at(lib_lexicon, w), "era")
let missing = dictionary<string, int>(1024)
let missing_by = dictionary<string, string>(1024)
var views_made = 0
var races_whole = 0

let stage = VNode {}
stage.scl = float2_1 * 1.5

def look(v:UV, who:string) -> int:
    var miss = 0
    for(draw_list(v, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])) d:
        if ends_with(d.key, " missing"):
            let k = substring(d.key, 0, d.key.length - 8)
            if not missing.get(k, 0): missing_by.set(k, who)
            missing.set(k, missing.get(k, 0) + 1)
            miss++
    for(v.crew) c: miss += look(c, who)
    return miss

def tick_all(v:UV) -> void:
    uv_process(v, DT)
    for(v.crew) c: tick_all(c)

def try_tool(v:UV, id:string, who:string) -> int:
    let w = v.weapon
    if not w or v.harnessed: return 0
    let key = bake_key(id, glist(part(id), "shapes"), w.cols)
    if bakes.get(key): return 0
    if not missing.get(key, 0): missing_by.set(key, who)
    missing.set(key, missing.get(key, 0) + 1)
    return 1

for(n_races) n:
    let nw = range_int(rng, 1, 4)
    let prompt = concat_string(map(nw): rpick(rng, words), " ")
    let race = generate(prompt, rules, 0)
    var miss = 0
    for(glist(race, "units")) u:
        let steps = glist(u, "line")
        for(steps) l:
            let r = at(l, "recipe")
            let e = at(l, "eval")
            let worker = rstr(r, "slot") == "worker"
            let who = prompt + ": " + gstr(r, "name", rstr(r, "slot"))
            for(8) d:
                let v = uv_new()
                add_child(stage, v.node)
                uv_build(v, r, KEY, as_int(at(e, "speed")))
                v.node.scl = float2_1 * 0.85
                v.pose_steps = 8
                v.art_px = 1.5
                let dv = rot2(float2 { 1.0, 0.0 }, float(d) * PI / 4.0)
                face_vec(v, dv)
                face_vec(v, dv)
                views_made++
                tick_all(v)
                miss += look(v, who)
                v.walking = true
                for(8):
                    tick_all(v)
                    miss += look(v, who)
                v.walking = false
                if as_int(at(e, "range")) > 1 or has(r, "crew"): loose(v) else: flourish(v)
                for(5):
                    tick_all(v)
                    miss += look(v, who)
                if worker:
                    for(JOB_TOOLS) j:
                        miss += try_tool(v, j[1], who)
                        set_tool(v, j[1])
                        v.job = j[0]
                        for(6):
                            tick_all(v)
                            miss += look(v, who)
                    v.job = ""
                    for(LOADS) t:
                        miss += try_tool(v, t, who)
                        set_tool(v, t)
                        v.walking = true
                        for(4):
                            tick_all(v)
                            miss += look(v, who)
                    v.walking = false
                die(v, 1.0)
                for(18):
                    tick_all(v)
                    miss += look(v, who)
                remove_child(stage, v.node)
                free_tree(v.node)
    if miss == 0: races_whole++
    else: print "{prompt}: {miss} missing draws"

print "{n_races} races, {views_made} views: {races_whole} drawn whole, {missing.get_keys().length} missing bakes"
let keys = sorted_strs(missing.get_keys())
for(keys) k:
    let first = missing_by.get(k) or ""
    print "  missing {k}  ({missing.get(k, 0)} draws; first: {first})"
