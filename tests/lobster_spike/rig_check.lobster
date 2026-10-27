// Units put together in 3D (view/rig3d.lobster) against Godot's rig3d.gd (rig_dump.gd): the same pieces, models,
// joints and transforms, and the same lowest point, for every unit of each race and its spear unit riding.
//   godot --headless --path . --script res://tests/lobster_spike/rig_dump.gd -- /tmp/r.json "<prompt>"...
//   lobster --mir rig_check.lobster -- /tmp/r.json "<prompt>"...

import placement.deps

let args = command_line_arguments()
fatal(gl.window("rig check", 64, 64, gl.window_init_no_vsync))
lib_load("../../data")
id_load("../../data")
complete_kit_parts()
let want = load_json(args[0]).a

def poses() -> [RigPose]:
    let raise = RigPose {}
    raise.hold = "raise"
    raise.turn = rad(1.2)
    let lev = RigPose {}
    lev.hold = "thrust"
    lev.level = true
    let w1 = RigPose {}
    w1.walk = 2.0 * MPI * 1.0 / 8.0
    let w5 = RigPose {}
    w5.walk = 2.0 * MPI * 5.0 / 8.0
    return [RigPose {}, raise, lev, w1, w5]

def recipes(prompts:[string]) -> [JV]:
    let out = []::JV
    for(prompts) p:
        let race = generate(p, load_rules("default"), 0)
        for(glist(race, "units")) u:
            if not has(at(u, "recipe"), "crew"): out.push(at(u, "recipe"))
        for(glist(race, "units")) u:
            let r0 = at(u, "recipe")
            if rstr(r0, "slot") == "spear":
                for(["pony", "cat"]) m:
                    let r = deep_copy(r0)
                    let mt = jobj()
                    set(mt, "creature", jstr(m))
                    set(mt, "skin", glist(at(lib_creatures, m), "skins")[0])
                    set(mt, "parts", jobj())
                    set(mt, "fused", jbool(false))
                    set(r, "mount", mt)
                    out.push(r)
    return out

def jf3(v:JV) -> float3: return float3 { as_float(v.a[0]), as_float(v.a[1]), as_float(v.a[2]) }

var views = 0
var same = 0
var bad = 0
var shown = 0
let rs = recipes(args.slice(1, -1))
var w = 0
for(rs) r:
    for(poses()) po:
        let g = want[w]
        w++
        let a = rig_unit(r, po)
        views++
        let gps = glist(g, "pieces")
        var why = ""
        if a.pieces.length != gps.length: why = "{a.pieces.length} pieces, Godot {gps.length}"
        else:
            for(a.pieces) p, k:
                let gp = gps[k]
                if why == "":
                    if p.name != rstr(gp, "name") or p.id != rstr(gp, "id") or p.parent != rstr(gp, "parent"): why = "{p.name} {p.id} < {p.parent}, Godot {rstr(gp, "name")} {rstr(gp, "id")} < {rstr(gp, "parent")}"
                    elif magnitude(p.joint - jf3(at(gp, "joint"))) > 0.01: why = "{p.name} joint {p.joint}, Godot {jf3(at(gp, "joint"))}"
                    elif magnitude(p.xf.o - jf3(at(gp, "o"))) > 0.01: why = "{p.name} at {p.xf.o}, Godot {jf3(at(gp, "o"))}"
                    else:
                        let gb = map(glist(gp, "b")) v: as_float(v)
                        let lb = [p.xf.b.x.x, p.xf.b.x.y, p.xf.b.x.z, p.xf.b.y.x, p.xf.b.y.y, p.xf.b.y.z, p.xf.b.z.x, p.xf.b.z.y, p.xf.b.z.z]
                        var db = 0.0
                        for(9) i: db = max(db, abs(gb[i] - lb[i]))
                        if db > 0.001: why = "{p.name} basis off by {db}: {lb} Godot {gb}"
                        else:
                            var lo = 1000000.0
                            for(vertices(p.node, p.xf)) v: lo = min(lo, v.y)
                            let glo = if at(gp, "low").kind == J_STR: 1000000.0 else: min(1000000.0, as_float(at(gp, "low")))   // (no vertices: Godot's inf)
                            if abs(lo - glo) > 0.02: why = "{p.name} lowest {lo}, Godot {glo}"
        if why == "" and a.walker != rstr(g, "walker"): why = "walker {a.walker}, Godot {rstr(g, "walker")}"
        if why == "" and a.flying != gbool(g, "flying", false): why = "flying {a.flying}"
        if why == "" and magnitude(a.seat - jf3(at(g, "seat"))) > 0.01: why = "seat {a.seat}, Godot {jf3(at(g, "seat"))}"
        if why == "": same++
        else:
            bad++
            if shown < 40:
                shown++
                print "DIFF {rstr(g, "label")} {rstr(g, "pose")}: {why}"
    rig_clear()
print "{same} of {views} views the same, {bad} differ"
