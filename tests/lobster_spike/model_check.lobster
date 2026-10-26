// The parts built in Lobster (model/) against the same parts as Godot builds them (mesh_export.gd, race mode):
// triangle for triangle, the same corners, normals and colours. A part whose triangles come in another order
// (a .glb's, as Godot's importer lays them out) is compared as a whole: its box and its triangles' total area.
//   godot --headless --path . --script res://tests/lobster_spike/mesh_export.gd -- /tmp/m "<prompt>" <part id>...
//   lobster model_check.lobster -- /tmp/m "<prompt>" <part id>...

import std
import vec
import color
import gl
import texture
import dictionary
import .gen.json
import .gen.rng
import .gen.sha256
import .gen.datalib
import .gen.identity
import .gen.pricing
import .gen.heroes
import .gen.generator
import .view.node
import .view.art
import .view.baker
import .model.kit
import .model.base
import .model.flat
import .model.glb
import .model.units
import .model.units2
import .model.units3
import .model.units4
import .model.units5
import .model.kit_bodies
import .model.siege
import .model.heroes
import .model.bears
import .model.models

let args = command_line_arguments()
let dir = args[0]
fatal(gl.window("model check", 64, 64, gl.window_init_no_vsync))
lib_load("../../data")
id_load("../../data")
let race = generate(args[1], load_rules("default"), 0)
let r1 = at(glist(race, "units")[1], "recipe")
let cols = colours_for(rstr(r1, "skin"), rstr(race, "family"), float3 { 1.0, 0.0, 1.0 })
let ids = if args.length > 2: args.slice(2, -1) else: append([rstr(r1, "body"), rstr(r1, "head")], map(filter(gobj(r1, "parts").a) v: v.kind == J_STR) v: v.s)

def area(t:BakeTri) -> float: return magnitude(cross(t.p[1] - t.p[0], t.p[2] - t.p[0])) * 0.5

var failed = 0
for(ids) id:
    let theirs = load_mesh(dir + "/" + id + ".mesh")
    let spec = build_model(id, cols)
    if not spec:
        print "SKIP {id}: no model here"
        continue
    let s = spec
    let mine = model_tris(s.node)
    if theirs.length == 0:
        print "SKIP {id}: Godot\'s mesh not exported ({mine.length} triangles here)"
        continue
    var dp = 0.0
    var dn = 0.0
    var dc = 0.0
    if mine.length == theirs.length:
        for(mine) t, i:
            for(3) k:
                dp = max(dp, magnitude(t.p[k] - theirs[i].p[k]))
                dn = max(dn, magnitude(t.n[k] - theirs[i].n[k]))
                dc = max(dc, magnitude(t.c[k] - theirs[i].c[k]))
    let ok_order = mine.length == theirs.length and dp < 0.01 and dn < 0.02 and dc < 0.01
    if ok_order:
        print "PASS {id}: {mine.length} triangles (corners within {dp}, normals {dn}, colours {dc})"
    else:
        // as a whole: the box and the area
        var lo1 = float3_1 * 1000000.0
        var hi1 = float3_1 * -1000000.0
        var lo2 = lo1
        var hi2 = hi1
        var a1 = 0.0
        var a2 = 0.0
        for(mine) t:
            a1 += area(t)
            for(t.p) p:
                lo1 = min(lo1, p)
                hi1 = max(hi1, p)
        for(theirs) t:
            a2 += area(t)
            for(t.p) p:
                lo2 = min(lo2, p)
                hi2 = max(hi2, p)
        let whole = magnitude(lo1 - lo2) < 0.02 and magnitude(hi1 - hi2) < 0.02 and abs(a1 - a2) < 0.001 * a2
        if whole and mine.length == theirs.length:
            print "PASS {id}: {mine.length} triangles, as a whole (box and area; in another order, colours {dc})"
        else:
            failed++
            print "FAIL {id}: {mine.length} triangles vs Godot {theirs.length}; corners {dp}, normals {dn}, colours {dc}; box {lo1}..{hi1} vs {lo2}..{hi2}; area {a1} vs {a2}"
print "{failed} failed"
