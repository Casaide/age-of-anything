// The buildings built in Lobster (model/buildings.lobster, buildings2.lobster) against Godot's (building_export.gd):
// every part (body, banner, vane, open, icon, arms), mesh for mesh: the same triangles (corners within 0.01, normals
// 0.02), the same material (by name for mats.get_mat's, colour and emission within 0.01 for all), the same metadata
// (parapet, about, roof, gate parts), and the spec's points, lights and doorway. Cases as building_export.gd's.
//   lobster building_check.lobster -- <dir> <case>...

import std
import vec
import dictionary
import color
import gl
import texture
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
import .model.props
import .model.build_mats
import .model.buildings
import .model.buildings2
import .game.ruin

let args = command_line_arguments()
let TEAM = float3 { 0.85, 0.2, 0.6 }

class Rec:          // one mesh (or a node's metadata) in a part
    part:string
    kind:string     // "m" or "n"
    tris:int
    mat:string
    albedo:float3
    emission:float3
    meta:string
    p:[float3]
    n:[float3]

def file_of(cs:string) -> string: return concat_string(tokenize(cs, ":", ""), "_")

def fv(t:[string], i:int) -> float3: return float3 { string_to_float(t[i]), string_to_float(t[i + 1]), string_to_float(t[i + 2]) }

// ---- Lobster's side

def walk(n:MNode, parent:Xform, part:string, out:[Rec]) -> void:
    let t = xmul(parent, node_xform(n))
    let mesh = n.mesh
    let mat = n.mat
    if mesh and mat and not n.visible: pass()   // (broken off a ruin: Godot's export leaves it out too)
    elif mesh and mat:
        let nb = btransposed(binverse(t.b))
        let name = bm_name(mat)
        let r = Rec { part, "m", mesh.idx.length / 3, if name == "": "-" else: name, mat.albedo, mat.emission, n.meta, [], [] }
        for(mesh.idx) i:
            r.p.push(xf(t, mesh.p[i]))
            r.n.push(normalize(bxf(nb, mesh.n[i])))
        out.push(r)
    elif n.meta != "":
        out.push(Rec { part, "n", 0, "", float3_0, float3_0, n.meta, [], [] })
    for(n.kids) kid: walk(kid, t, part, out)

def mine(cs:string, out:[Rec], pts:[string]) -> bool:
    let a = tokenize(cs, ":", "")
    brng = grng(0)
    gate_span = 3.0
    wall_rescale = 1.0
    var ruin_at = -1
    let first = if a[0] == "look": 4 else: 3
    for(if a.length > first: a.slice(first, -1) else: []) o:
        if o == "diag": gate_span = 3.0 * sqrt(2.0)
        elif starts_with(o, "ruin"): ruin_at = string_to_int(o.substring(4, o.length - 4))
        elif starts_with(o, "r"): wall_rescale = string_to_float(o.substring(1, o.length - 1))
    var sp:BSpec? = nil
    switch a[0]:
        case "model":
            if a[1] == "flowers" or a[1] == "rally_flag" or a[1] == "waypoint_flag":
                let n = if a[1] == "flowers": flowers(string_to_int(a[2])) elif a[1] == "rally_flag": rally_flag(TEAM) else: waypoint_flag(TEAM)
                walk(n, XF_ID, "body", out)
                return true
            sp = model_by_name(a[1], TEAM)
        case "building": sp = building(a[1], a[2], TEAM)
        case "look": sp = look(a[1], a[2], a[3], TEAM)
        default: return false
    let s = sp
    if not s: return false
    if ruin_at >= 0: ruin_apply(s.body, ruin_at, hash_text("{a[2]}:{a[1]}"))
    walk(s.body, XF_ID, "body", out)
    let b = s.banner
    if b: walk(b, XF_ID, "banner", out)
    let v = s.vane
    if v: walk(v, XF_ID, "vane", out)
    let o = s.open
    if o: walk(o, XF_ID, "open", out)
    let ic = s.icon
    if ic: walk(ic, XF_ID, "icon", out)
    for(s.arms) arm, i: walk(arm, XF_ID, "arm{i}", out)
    for(s.pts.get_keys()) k:
        let p = s.pts.get(k, float3_0)
        pts.push("p {k} {p.x} {p.y} {p.z}")
    if s.has_team: pts.push("c team {s.team.x} {s.team.y} {s.team.z}")
    if s.lights.length or s.has_doorway or true:
        var row = "a lights"
        for(s.lights) p: row += " {p.x} {p.y} {p.z}"
        pts.push(row)
    if s.has_doorway:
        var row = "a doorway"
        for(s.doorway) p: row += " {p.x} {p.y} {p.z}"
        pts.push(row)
    return true

// ---- Godot's side

def theirs(cs:string, out:[Rec], pts:[string]) -> bool:
    let text = read_file(args[0] + "/" + file_of(cs) + ".txt")
    if not text: return false
    let bin = read_file(args[0] + "/" + file_of(cs) + ".bin", true) or ""
    var at = 0
    var part = "body"
    for(tokenize(text, "\n", "")) line:
        let t = tokenize(line, " ", "")
        if t.length == 0: continue
        switch t[0]:
            case "part": part = t[1]
            case "n": out.push(Rec { part, "n", 0, "", float3_0, float3_0, concat_string(t.slice(1, -1), " "), [], [] })
            case "m":
                let r = Rec { part, "m", string_to_int(t[1]), t[2], fv(t, 3), fv(t, 6), concat_string(t.slice(9, -1), " "), [], [] }
                for(r.tris * 3):
                    def f(k:int) -> float:
                        let x, _n = read_float32_le(bin, at + k * 4)
                        return x
                    r.p.push(float3 { f(0), f(1), f(2) })
                    r.n.push(float3 { f(3), f(4), f(5) })
                    at += 24
                out.push(r)
            default: pts.push(line)
    return true

// Two metadata strings alike: the same words, the numbers within 0.001.
def same_meta(a:string, b:string) -> bool:
    let x = tokenize(a, " ", "")
    let y = tokenize(b, " ", "")
    if x.length != y.length: return false
    for(x) w, i:
        let fx, okx = string_to_float(w)
        let fy, oky = string_to_float(y[i])
        if okx and oky:
            if abs(fx - fy) > 0.001: return false
        elif w != y[i]: return false
    return true

// The spec's points alike: each of Godot's lines has one here with the same key and numbers within 0.01.
def same_pts(m:[string], g:[string]) -> string:
    for(g) gl:
        let gt = tokenize(gl, " ", "")
        var found = false
        for(m) ml:
            let mt = tokenize(ml, " ", "")
            if mt[0] == gt[0] and mt[1] == gt[1]:
                found = true
                if mt.length != gt.length: return "{gl} vs {ml}"
                for(gt.length - 2) i:
                    if abs(string_to_float(mt[i + 2]) - string_to_float(gt[i + 2])) > 0.01: return "{gl} vs {ml}"
        if not found:
            if not (gt[1] == "lights" and gt.length == 2): return "{gl} missing here"
    for(m) ml:
        let mt = tokenize(ml, " ", "")
        var there = false
        for(g) gl:
            if starts_with(gl, mt[0] + " " + mt[1] + " ") or gl == mt[0] + " " + mt[1]: there = true
        if not there:
            if not (mt[1] == "lights" and mt.length == 2): return "{ml} here, not in Godot\'s"
    return ""

var failed = 0
for(args.slice(1, -1)) cs:
    let g = []::Rec
    let gp = []::string
    let m = []::Rec
    let mp = []::string
    if not theirs(cs, g, gp):
        failed++
        print "FAIL {cs}: Godot\'s not exported"
        continue
    if not mine(cs, m, mp):
        failed++
        print "FAIL {cs}: no such case here"
        continue
    var err = ""
    var dp = 0.0
    var dn = 0.0
    var tris = 0
    if m.length != g.length:
        err = "{m.length} meshes and nodes vs Godot {g.length}"
    for(min(m.length, g.length)) i:
        if err == "":
            let a = m[i]
            let b = g[i]
            if a.part != b.part or a.kind != b.kind: err = "record {i}: {a.part} {a.kind} vs {b.part} {b.kind}"
            elif a.kind == "n":
                if not same_meta(a.meta, b.meta): err = "node {i} in {a.part}: meta \"{a.meta}\" vs \"{b.meta}\""
            elif a.tris != b.tris: err = "mesh {i} in {a.part}: {a.tris} triangles vs {b.tris}"
            elif a.mat != b.mat: err = "mesh {i} in {a.part}: material {a.mat} vs {b.mat}"
            elif magnitude(a.albedo - b.albedo) > 0.01: err = "mesh {i} in {a.part}: colour {a.albedo} vs {b.albedo}"
            elif magnitude(a.emission - b.emission) > 0.01: err = "mesh {i} in {a.part}: emission {a.emission} vs {b.emission}"
            elif not same_meta(a.meta, b.meta): err = "mesh {i} in {a.part}: meta \"{a.meta}\" vs \"{b.meta}\""
            else:
                tris += a.tris
                for(a.p) p, k:
                    let d = magnitude(p - b.p[k])
                    if d > dp: dp = d
                    let e = magnitude(a.n[k] - b.n[k])
                    if e > dn: dn = e
                    if err == "" and (d >= 0.01 or e >= 0.02):
                        err = "mesh {i} in {a.part} (tri {k / 3}): corner {p} vs {b.p[k]}, normal {a.n[k]} vs {b.n[k]}"
    if err == "": err = same_pts(mp, gp)
    if err == "":
        print "PASS {cs}: {m.length} meshes, {tris} triangles (corners within {dp}, normals {dn})"
    else:
        failed++
        print "FAIL {cs}: {err}"
print "{failed} failed"
