// The props built in Lobster (model/props, trees, town_props, bridges) against the same props as Godot builds them
// (prop_export.gd), triangle for triangle: the same corners, normals and colours. A case is the builder's name and its
// arguments, ":" between ("reed_clump:12:1.0:2", "tree:5:pine:1:0"); its files are <dir>/<case, ":" as "_">.mesh/.bin.
//   godot --headless --path . --script res://tests/lobster_spike/prop_export.gd -- /tmp/p <case>...
//   lobster prop_check.lobster -- /tmp/p <case>...

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
import .model.props
import .model.trees
import .model.town_props
import .model.bridges

let args = command_line_arguments()

def arg_i(a:[string], i:int, d:int) -> int: return if a.length > i: string_to_int(a[i]) else: d
def arg_f(a:[string], i:int, d:float) -> float: return if a.length > i: string_to_float(a[i]) else: d
def arg_s(a:[string], i:int, d:string) -> string: return if a.length > i: a[i] else: d

def build_prop(cs:string) -> MNode?:
    let a = tokenize(cs, ":", "")
    switch a[0]:
        case "reed_clump": return reed_clump(arg_i(a, 1, 0), arg_f(a, 2, 1.0), arg_i(a, 3, 0))
        case "bug_bush": return bug_bush(arg_i(a, 1, 0), arg_i(a, 2, 0))
        case "grass_tuft": return grass_tuft(arg_i(a, 1, 0))
        case "field_stones": return field_stones(arg_i(a, 1, 0))
        case "lily_pads": return lily_pads(arg_i(a, 1, 0))
        case "stone_mesh": return mesh_node(stone_mesh(arg_i(a, 1, 0), arg_i(a, 2, 0) == 1), plain(float3_1))
        case "boulders": return boulders(arg_i(a, 1, 0))
        case "quarry": return quarry(arg_i(a, 1, 0), arg_i(a, 2, 0), arg_s(a, 3, "stone"))
        case "carcass": return carcass(arg_i(a, 1, 0), arg_i(a, 2, 0))
        case "crops": return crops(arg_i(a, 1, 0))
        case "paddy": return paddy(arg_i(a, 1, 0))
        case "tree": return tree(arg_i(a, 1, 0), arg_s(a, 2, "broadleaf"), arg_i(a, 3, 0), arg_i(a, 4, 0))
        case "pile": return pile(arg_s(a, 1, "food"), arg_i(a, 2, 1), arg_s(a, 3, "a"))
        case "yard": return yard(arg_i(a, 1, 1), arg_i(a, 2, 0))
        case "garden": return garden(arg_i(a, 1, 1), arg_i(a, 2, 0))
        case "tether_post": return tether_post()
        case "bridge": return bridge(arg_i(a, 1, 0), arg_i(a, 2, 1), arg_i(a, 3, 0), arg_i(a, 4, 0), arg_i(a, 5, 1))
        default: return nil

def file_of(cs:string) -> string: return concat_string(tokenize(cs, ":", ""), "_")

let dir = args[0]
fatal(gl.window("prop check", 64, 64, gl.window_init_no_vsync))
var failed = 0
for(args.slice(1, -1)) cs:
    let theirs = load_mesh(dir + "/" + file_of(cs) + ".mesh")
    let built = build_prop(cs)
    if not built:
        failed++
        print "FAIL {cs}: no such prop here"
        continue
    let mine = model_tris(built)
    if theirs.length == 0 and mine.length == 0 and read_file(dir + "/" + file_of(cs) + ".mesh"):
        print "PASS {cs}: empty, as Godot\'s"
        continue
    if theirs.length == 0:
        failed++
        print "FAIL {cs}: Godot\'s mesh not exported ({mine.length} triangles here)"
        continue
    var dp = 0.0
    var dn = 0.0
    var dc = 0.0
    var worst = -1
    var worst_n = -1
    if mine.length == theirs.length:
        for(mine) t, i:
            for(3) k:
                let p = magnitude(t.p[k] - theirs[i].p[k])
                if p > dp:
                    dp = p
                    worst = i
                let nd = magnitude(t.n[k] - theirs[i].n[k])
                if nd > dn:
                    dn = nd
                    worst_n = i
                dc = max(dc, magnitude(t.c[k] - theirs[i].c[k]))
    if mine.length == theirs.length and dp < 0.01 and dn < 0.02 and dc < 0.01:
        print "PASS {cs}: {mine.length} triangles (corners within {dp}, normals {dn}, colours {dc})"
    else:
        failed++
        var at = ""
        if worst >= 0 and dp >= 0.01: at = "; worst corners at triangle {worst}: {mine[worst].p} vs {theirs[worst].p}"
        if worst_n >= 0 and dn >= 0.02: at += "; worst normals at triangle {worst_n}: {mine[worst_n].n} vs {theirs[worst_n].n}"
        print "FAIL {cs}: {mine.length} triangles vs Godot {theirs.length}; corners {dp}, normals {dn}, colours {dc}{at}"
print "{failed} failed"
