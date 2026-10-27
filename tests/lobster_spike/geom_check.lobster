// The voxelizer (view/geom.lobster) against Godot's (src/view/art/geom.gd), part for part: the voxels of each
// modelled part a race's units wear, placed as built and moved (geom_dump.gd's second placing), its vertex
// count, and its eyes' and brows' boxes.
//   godot --headless --path . --script res://tests/lobster_spike/geom_dump.gd -- /tmp/g.json "<prompt>"
//   lobster geom_check.lobster -- /tmp/g.json "<prompt>"

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
import .model.grng
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
import .model.mods_active
import .model.models
import .view.geom

def show_hides(n:MNode) -> void:
    let cm = n.mesh
    if cm and cm.prim == PRIM_BOX and cm.pp.y == 0.5: print "hide rot {n.rot} bas {n.bas != nil} scl {n.scl}"
    for(n.kids) c: show_hides(c)

let args = command_line_arguments()
lib_load("../../data")
id_load("../../data")
complete_kit_parts()
let want = load_json(args[0])
let race = generate(args[1], load_rules("default"), 0)
let r1 = at(glist(race, "units")[1], "recipe")
let cols = colours_for(rstr(r1, "skin"), rstr(race, "family"), float3 { 1.0, 0.0, 1.0 })
let moved = Xform { bscaled_global(bmul(axis_angle(float3 { 0.0, 1.0, 0.0 }, 30.0), axis_angle(float3 { 1.0, 0.0, 0.0 }, 10.0)), float3_1 * 0.8),
                    float3 { 3.25, 7.5, -1.75 } }
var same = 0
var near = 0
var bad = 0
for(want.keys) id, n:
    let rec = want.a[n]
    let s = build_model(id, cols)
    if not s:
        print "MISSING {id}: no Lobster model"
        bad++
    else:
        var worst = 0.0
        var line = ""
        if args.length > 2 and args[2] == id:
            let counts = [0, 0, 0, 0, 0, 0]
            for(geom_meshes(s.node, XF_ID)) g: counts[g.ms[0].prim]++
            print "  meshes as none, sphere, cylinder, box, torus, flat: {counts}"
            let per = []::string
            for(geom_meshes(s.node, XF_ID)) g:
                let v = new_vox()
                geom_fill(g.ms, g.t, v)
                var sum = 0
                for(v.keys) q: sum = (sum + q * 7919) % 1000000007
                per.push(string(sum))
            print "  each mesh sum: {per}"
            let gm = geom_meshes(s.node, XF_ID)
            for([34, 61]) i:
                if i < gm.length: print "M{i} prim {gm[i].ms[0].prim} {gm[i].ms[0].pp} basis {gm[i].t.b}"
            show_hides(s.node)
        for(2) k:
            let got = voxels(s.node, if k == 0: XF_ID else: moved)
            let g = new_vox()
            for(glist(rec, "vox{k}")) v: vadd(g, as_int(v))
            let only_l = (filter(got.keys) q: not vhas(g, q)).length
            let only_g = (filter(g.keys) q: not vhas(got, q)).length
            if args.length > 2 and args[2] == id:   // (a part named after the prompt: where its differences are)
                for(filter(g.keys) q: not vhas(got, q)) q: print "  only there: {vcentre(q)}"
                for(filter(got.keys) q: not vhas(g, q)) q: print "  only here: {vcentre(q)}"
            let diff = float(only_l + only_g) / float(max(1, vcount(g)))
            worst = max(worst, diff)
            line += "  {if k == 0: "as built" else: "moved"}: {vcount(got)} voxels, Godot {vcount(g)}, {only_l} only here, {only_g} only there"
        let nv = vertices(s.node, XF_ID).length
        let ok_v = nv == gint(rec, "verts", -1)
        var feats = ""
        for(["eye", "brow"]) w:
            let fs = features(s.node, w, XF_ID)
            if fs.length != glist(rec, w).length: feats += " {w}s {fs.length} (Godot {glist(rec, w).length})"
        if worst == 0.0 and ok_v and feats == "": same++
        elif worst <= 0.01 and ok_v and feats == "":
            near++
            print "NEAR {id}:{line}"
        else:
            bad++
            print "DIFF {id}:{line}; vertices {nv} (Godot {gint(rec, "verts", -1)}){feats}"
print "{same} the same, {near} within 1%, {bad} off, of {want.keys.length} parts"
