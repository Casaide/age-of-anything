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


// The creature kit's bodies completed in Lobster (model/kit_bodies.lobster kit_complete) against Godot's
// (CreatureKit.complete, as the library pack's kit_parts.json holds it), value for value.
//   lobster kitparts_check.lobster

def same(a:JV, b:JV, path:string) -> string:
    if (a.kind == J_INT or a.kind == J_FLOAT) and (b.kind == J_INT or b.kind == J_FLOAT):
        return if abs(as_float(a) - as_float(b)) < 0.011: "" else: "{path}: {as_float(a)} vs {as_float(b)}"
    if a.kind != b.kind: return "{path}: kinds {a.kind} vs {b.kind}"
    if a.kind == J_ARR:
        if a.a.length != b.a.length: return "{path}: {a.a.length} items vs {b.a.length}"
        for(a.a) x, i:
            let d = same(x, b.a[i], "{path}[{i}]")
            if d != "": return d
        return ""
    if a.kind == J_OBJ:
        for(b.keys) k, i:
            let x = get(a, k)
            if not x: return "{path}.{k}: missing"
            let d = same(x, b.a[i], "{path}.{k}")
            if d != "": return d
        return ""
    return if stringify(a) == stringify(b): "" else: "{path}: {stringify(a)} vs {stringify(b)}"

lib_load("../../data")
complete_kit_parts()
let godot = parse_json(read_file("library/kit_parts.json") or "\{\}")
var failed = 0
for(godot.keys) id, n:
    let mine = get(lib_parts, id)
    let d = if mine: same(mine, godot.a[n], id) else: "{id}: not made"
    if d != "": failed++
    print "{if d == "": "PASS" else: "FAIL"} {id}{if d == "": "" else: ": " + d}"
print "{failed} failed"
