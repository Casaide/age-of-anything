// The unit composer (view/unit_view.lobster) against Godot's UnitView: art_pack.gd's states played
// for every unit type in 8 directions, each frame's draw list (bake, transform, alpha) compared with
// the one Godot dumped (art_pack.gd ... dump). Run from tests/lobster_spike:
//   lobster view_check.lobster -- <pack dir>
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
import view.node
import view.art
import view.unit_view

let DT = 1.0 / 8.0
let ART_SCALE = 1.5
let UNIT_SCALE = 0.85
let KEY = float3 { 1.0, 0.0, 1.0 }
let JOBS = [["forage", "tool.basket"], ["chop", "tool.axe"], ["mine", "tool.pick"], ["build", "tool.hammer"]]
let LOADS = [["food", "tool.basket"], ["wood", "load.reeds"], ["stone", "load.stone"], ["gold", "load.gold"]]

class Rec:
    x:float
    y:float
    rows:[string]

let args = command_line_arguments()
let dir = args[0]
let index = assert read_file(dir + "/index.txt")
var map_id = ""
let prompts = []::string
for(tokenize(index, "\n", "")) line:
    let t = filter(tokenize(line, " ", "")): _.length > 0
    if t.length >= 2 and t[0] == "match": map_id = t[1]
    if t.length >= 3 and t[0] == "prompt": prompts.push(concat_string(tokenize(t[2], "_", ""), " "))
lib_load("../../data")
id_load("../../data")
let rules = load_rules("default")
set(rules, "animals", jbool(false))
setup_world(20261010, map_id, map(prompts) p: generate(p, rules, 0), rules, [])
load_part_data(dir)
print "{t_slot.length} unit types, {bakes.get_keys().length} bakes"

// The dumps: "d <type> <state> <dir> <frame> <n> <x> <y>", then n rows.
let recs = dictionary<string, Rec>(32768)
let lines_ = tokenize(assert read_file(dir + "/dumps.txt"), "\n", "")
var li = 0
while li < lines_.length:
    let t = tokenize(lines_[li], " ", "")
    if t.length >= 8 and t[0] == "d":
        let n = string_to_int(t[5])
        recs.set(t[1] + " " + t[2] + " " + t[3] + " " + t[4], Rec { string_to_float(t[6]), string_to_float(t[7]), lines_.slice(li + 1, n) })
        li += 1 + n
    else: li++
print "{recs.get_keys().length} dumped frames"

let stage_xf = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
let stage = VNode {}
stage.scl = float2_1 * ART_SCALE
var frames_same = 0
var frames_diff = 0
var shown = 0
let diff_kinds = dictionary<string, int>(64)

def near(a:float, b:float, tol:float) -> bool: return abs(a - b) <= tol

def compare(head:string, v:UV):
    let rec = recs.get(head)
    if not rec: return
    let got = draw_list(v, xf_local(stage))
    var ok = got.length == rec.rows.length
    var why = if ok: "" else: "count {got.length} v {rec.rows.length}"
    if ok:
        for(got) d, i:
            if ok:
                let t = tokenize(rec.rows[i], " ", "")
                if t[0] != d.key:
                    ok = false
                    why = "part {i}: {d.key} v {t[0]}"
                elif t.length >= 8:
                    for(6) j:
                        if ok and not near(d.xf[j], string_to_float(t[1 + j]), if j >= 4: 0.02 else: 0.002):
                            ok = false
                            why = "part {i} {d.key}: xf[{j}] {d.xf[j]} v {t[1 + j]}"
                    if ok and not near(d.alpha, string_to_float(t[7]), 0.002):
                        ok = false
                        why = "part {i} {d.key}: alpha {d.alpha} v {t[7]}"
    if ok: frames_same++
    else:
        frames_diff++
        let st = tokenize(head, " ", "")[1]
        diff_kinds.set(st, diff_kinds.get(st, 0) + 1)
        if shown < 25:
            shown++
            print "DIFF {head}: {why}"

def crew_process(v:UV) -> void:
    for(v.crew) c:
        uv_process(c, DT)
        crew_process(c)

for(t_slot.length) k:
    for(8) d:
        let r0 = recs.get("{k} idle {d} 0")
        if r0:
            let v = uv_new()
            add_child(stage, v.node)
            uv_build(v, su_type_recipe[k], KEY, t_speed[k] / 5)
            v.node.scl = float2_1 * UNIT_SCALE
            v.pose_steps = 8
            v.art_px = ART_SCALE
            v.time = 0.0
            v.node.pos = float2 { r0.x, r0.y } / ART_SCALE
            let dv = rot2(float2 { 1.0, 0.0 }, float(d) * PI / 4.0)
            face_vec(v, dv)
            face_vec(v, dv)
            let worker = t_worker[k] != 0
            let engine = has(su_type_recipe[k], "crew")
            def state(name:string, count:int, moves:bool, on:bool, prep):
                if on:
                    for(count) f:
                        prep(f)
                        var step = float2_0
                        if moves:
                            step = dv * v.speed_px * DT
                            v.node.pos += step
                        uv_process(v, DT)
                        crew_process(v)
                        if moves:
                            v.node.pos -= step
                            if v.has_hop_last: v.hop_last -= step
                        compare("{k} {name} {d} {f}", v)
            state("idle", 1, false, true) f: pass()
            state("walk", 16, true, true) f: v.walking = true
            v.walking = false
            state("attack", 8, false, true) f:
                if f == 0:
                    if t_ranged[k] != 0 or engine: loose(v) else: flourish(v)
            for(JOBS) j:
                state("work_" + j[0], 8, false, worker) f:
                    if f == 0:
                        set_tool(v, j[1])
                        v.job = j[0]
            v.job = ""
            for(LOADS) l:
                state("carry_" + l[0], 16, true, worker) f:
                    if f == 0:
                        set_tool(v, l[1])
                        v.walking = true
            v.walking = false
            if worker: set_tool(v, gstr(at(su_type_recipe[k], "parts"), "hand_r", "tool.basket"))
            state("die", 18, false, true) f:
                if f == 0: die(v, 1.0)

print "frames the same: {frames_same}, differing: {frames_diff}"
for(diff_kinds.get_keys()) s: print "  {s}: {diff_kinds.get(s, 0)}"
