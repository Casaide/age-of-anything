// Walking feet against the ground (#422; Dominic, 2026-11-10: "not all units their velocity matches their walking
// animation"). The walk steps by the ground a unit covers, a cycle (vx_walk_cycle) to its 8 steps, so a planted foot
// stays put only if it goes back by just that much. For every legged body bare, and every mount under every rider
// (the rider sets the mount's size), from the real foot pose (vx_foot) through the cycle:
//   cycle    a planted foot goes back as far as the ground goes by: within CYCLE_OFF of the look's cycle
//   slide    from one baked step to the next, a planted foot moves against the ground by at most SLIDE_OFF of the
//            ground covered in a step (a foot that speeds up and slows down skates, even at the right cycle)
//   lobster walk_check.lobster -- [report]   (report: the numbers only, no failing)
import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.vox
import view.voxel

let CYCLE_OFF = 0.05
let SLIDE_OFF = 0.1
let MT_A_UNIT = 1000.0 / 62.0  // milli-tiles a body unit along the ground, at size 1 (as vx_walk_cycle)
let SAMPLES = 720              // through a cycle

vx_load([ "../data/voxel" ])
let args = command_line_arguments()
let report = args.length and args[0] == "report"
var fails = 0
var checked = 0

def fail(what:string):
    print "FAIL: " + what
    fails++

def unit(body:string, mount:string) -> vx_unit_def:
    return vx_unit_def { body, body, float3_0, float3_0, float3_0, [], mount, false, float3_0, float3_0, float3_0, nil }

// Is a foot on the ground here (its ankle at its rest height)?
def planted(rest:float3, at:float3) -> bool: return at.z - rest.z < 0.02

// A walker (the body whose legs walk) drawn at size, for a unit def u: every leg on both sides, against its cycle.
def walk(name:string, u:vx_unit_def, w:vx_body_spec, size:float):
    let cycle = vx_walk_cycle(u)
    let k = size * MT_A_UNIT  // milli-tiles a body unit of the walker, on the ground
    vx_stand = false
    vx_act = ""
    for(w.legs) l, li:
        for([ 1.0, -1.0 ]) side:
            let rest = l.foot * float3 { side, 1.0, 1.0 }
            // the ground a planted foot covers in a cycle: its speed back, planted, over the whole cycle
            var back = 0.0
            var held = 0
            for(SAMPLES) s:
                let ph0 = float(s) * 360.0 / float(SAMPLES)
                let ph1 = float(s + 1) * 360.0 / float(SAMPLES)
                let a = vx_foot(w, l, side, ph0)
                let b = vx_foot(w, l, side, ph1)
                if planted(rest, a) and planted(rest, b):
                    back += a.y - b.y
                    held++
            assert held > 0
            let covers = back / float(held) * float(SAMPLES) * k
            let ratio = covers / cycle
            // baked steps: between two planted ones, the foot against the ground (which moves a cycle's eighth a step)
            var worst = 0.0
            for(8) st:
                let a = vx_foot(w, l, side, float(st) * 45.0)
                let b = vx_foot(w, l, side, float(st + 1) * 45.0)
                if planted(rest, a) and planted(rest, b):
                    let slid = abs((b.y - a.y) * k + cycle / 8.0) / (cycle / 8.0)
                    worst = max(worst, slid)
            checked++
            if report and side > 0.0: print "{name} leg {li}: stride {l.stride} at size {size}: feet cover {int(covers)} of a {int(cycle)} milli-tile cycle ({int(ratio * 100.0 + 0.5)}%), worst step slide {int(worst * 100.0 + 0.5)}%"
            if not report and side > 0.0 and abs(ratio - 1.0) > CYCLE_OFF:
                fail("{name} leg {li}: a planted foot covers {int(ratio * 100.0 + 0.5)}% of the ground walked in a cycle ({int(covers)} of {int(cycle)} milli-tiles; within {int(CYCLE_OFF * 100.0)}%)")
            if not report and side > 0.0 and worst > SLIDE_OFF:
                fail("{name} leg {li}: a planted foot slides {int(worst * 100.0 + 0.5)}% of a step against the ground between baked steps (at most {int(SLIDE_OFF * 100.0)}%)")

let bodies = filter(sorted_strs(assert scan_folder("../data/voxel/bodies", false))) n: ends_with(n, ".json")
let ids = map(bodies) n: substring(n, 0, n.length - 5)
// every legged body walking bare
for(ids) id:
    let b = vx_body_of(id)
    if b.legs.length and vx_track_cycle(b) <= 0.0: walk(id, unit(id, ""), b, b.size)
// every legged mount under every rider that isn't an engine or a beast (the rider's height sets the mount's size)
let mounts = filter(gobj(parse_json(assert read_file("../data/voxel/sizes.json")), "mounts").keys) m: vx_body_of(m).legs.length > 0
for(ids) r:
    if find_string(r, "siege.") != 0 and vx_body_of(r).h > 0.0:
        for(mounts) m:
            if m != r:
                let rb = vx_body_of(r)
                let mb = vx_body_of(m)
                walk("{r} on {m}", unit(r, m), mb, vx_mount_size(rb, mb))

if not report and fails == 0: print "walks hold: {checked} feet keep to the ground"
if not report: assert fails == 0
