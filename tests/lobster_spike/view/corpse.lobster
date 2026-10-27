// ------------------------------------------------------------------ the dead laid down in 3D (src/view/art/corpse.gd)
// A body with a `corpse` pose in parts.json (the frog's face-down sprawl) dies as a few baked frames: the whole unit
// put together in 3D (view/rig3d.lobster), laid down (the body pitched then rolled about its middle, each leg turned
// at its hip, body and legs swapped for their limp models, the head dropped at its neck), what it held dropped flat
// on the ground beside it. Each piece is named (meta) by its kind, for the placement check (D1, D2).
//
// The pose (parts.json body.<x>.corpse): frames (percent of the way down), pivot [x, y, z] (what the body turns
// about), pitch (about its side axis, degrees), roll (then about its long axis), body / legs ("limp": the limp
// models, from 30% down), leg_turn [out, about its side axis, spread] degrees, head (turned at the neck), helm (the
// helmet comes off and lies upturned), turn (per facing, for the bake). What it held leaves it from 60% down.

let LET_GO = 0.6     // from this far down its hands are empty
let LIMP_FROM = 0.3  // ...and from this far its body and legs are the limp models

// Where what it held lands, in the body's space: [x, z] and its turn on the ground (radians). Each clear of the body
// (D2): the banner behind, what the near hand held out past the flung arm.
def corpse_spot(kind:string) -> float3:
    switch kind:
        case "hand_r": return float3 { 6.0, 21.0, 0.35 }
        case "hand_l": return float3 { -4.0, -11.0, -0.5 }
        case "head_gear": return float3 { 14.0, 4.0, 0.0 }
        default: return float3 { -17.0, 6.0, 2.4 }   // (the back: a banner)

def about(at:float3, b:Basis) -> Xform: return xmul(Xform { b, at }, Xform { BASIS_ID, -at })

def borthonormalized(b:Basis) -> Basis:   // (Godot's Basis.orthonormalized: Gram-Schmidt, x first)
    let x = normalize(b.x)
    let y = normalize(b.y - x * dot(x, b.y))
    let z = normalize(b.z - x * dot(x, b.z) - y * dot(y, b.z))
    return Basis { x, y, z }

// The posed unit (body space: x forward, y up), its lowest point on the ground. Children: the "body" (the posed
// pieces, each named by its kind: body, arm, leg, head, armour, head_gear...) and one per dropped item
// ("dropped:<kind>", holding the item).
def corpse_model(r:JV, p:JV, f:float) -> MNode:
    let a = rig_unit(r, RigPose {})
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    let e = clamp(f, 0.0, 1.0)
    let pv = map(glist(p, "pivot")) v: as_float(v)
    let pivot = float3 { pv[0], pv[1], pv[2] }
    let turn = bmul(axis_angle(float3 { 1.0, 0.0, 0.0 }, num_or(p, "roll", 0.0) * e), axis_angle(float3 { 0.0, 0.0, 1.0 }, num_or(p, "pitch", 0.0) * e))
    let lay = xmul(Xform { turn, pivot }, Xform { BASIS_ID, -pivot })
    let root = mnode()
    let body = add_child(root, mnode())
    body.meta = "body"
    let limp = e > LIMP_FROM
    let dropped = []::Piece
    let dropped_w = []::MNode
    for(a.pieces) q:
        var node = q.node
        var t = q.xf
        if (q.kind == "body" or q.kind == "arm") and gstr(p, "body", "") != "" and limp:
            let bs = rig_spec(tokenize(q.id, "@", "")[0] + "@" + rstr(p, "body"), colours)
            if bs:
                if q.kind == "body": node = bs.node
                else:
                    let fr = bs.front
                    if fr: node = fr
        if has(p, "head") and (q.kind == "head" or ends_with(q.parent, ":head")):
            let hp = rig_by(a, if q.kind == "head": q.name else: q.parent)
            if hp: t = xmul(about(hp.joint, axis_angle(float3 { 0.0, 0.0, 1.0 }, num_or(p, "head", 0.0) * e)), t)
        if q.kind == "leg":
            if gstr(p, "legs", "") != "" and limp:
                let ls = rig_spec(tokenize(q.id, "@", "")[0] + "@" + rstr(p, "legs"), colours)
                if ls: node = ls.node
            let side = if q.hip.z > 0.0: 1.0 else: -1.0
            let lt = map(glist(p, "leg_turn")) v: as_float(v)
            let bend = bmul(bmul(axis_angle(float3 { 0.0, 1.0, 0.0 }, lt[2] * e * side), axis_angle(float3 { 1.0, 0.0, 0.0 }, lt[0] * e * side)),
                            axis_angle(float3 { 0.0, 0.0, 1.0 }, lt[1] * e))
            t = xmul(about(q.joint, bend), t)
        let w = mnode()
        w.meta = q.kind
        w.kids.push(node)
        let banner = q.kind == "back" and has_s(ptags_of(tokenize(q.id, "@", "")[0]), "banner")
        if (q.kind == "hand_r" or q.kind == "hand_l" or banner or (q.kind == "head_gear" and gbool(p, "helm", false))) and e >= LET_GO:
            dropped.push(q)
            dropped_w.push(w)
        else:
            set_xform(w, xmul(lay, t))
            body.kids.push(w)
    corpse_ground(body, 0.0)
    // What it held lands flat beside it: the weapon in front on its near side, the shield behind on its far side,
    // the banner behind it, a helmet upturned by its head.
    for(dropped) q, i:
        let w = dropped_w[i]
        let s = corpse_spot(q.kind)
        set_xform(w, Xform { bmul(bmul(corpse_flat(w.kids[0], s.z, q.kind == "head_gear"), binverse(borthonormalized(q.xf.b))), q.xf.b), float3_0 })
        let wrap = add_child(root, mnode())
        wrap.meta = "dropped:" + q.kind
        wrap.kids.push(w)
        corpse_ground(wrap, 0.2)
        let c = corpse_centre(wrap)
        wrap.pos += float3 { s.x - c.x, 0.0, s.y - c.z }
    return root

// A dropped item's turn to lie flat: its longest side along the ground (turned by yaw, radians), its thinnest
// straight up (a helmet: upside down, the crown on the ground).
def corpse_flat(n:MNode, yaw:float, upturned:bool) -> Basis:
    if upturned: return axis_angle(float3 { 1.0, 0.0, 0.0 }, 180.0)
    var vs = vertices(n, XF_ID)
    if not vs.length: vs = corpse_corners(n, XF_ID)
    var lo = vs[0]
    var hi = vs[0]
    for(vs) v:
        lo = min(lo, v)
        hi = max(hi, v)
    let size = hi - lo
    let axes = [float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }]
    let sizes = [size.x, size.y, size.z]
    let order = [0, 1, 2]
    insertion_sort(order) i, j: sizes[i] > sizes[j]
    let long = axes[order[0]]
    let thin = axes[order[2]]
    let along = float3 { cos(rad(yaw)), 0.0, sin(rad(yaw)) }
    let up = float3 { 0.0, 1.0, 0.0 }
    return bmul(Basis { along, up, cross(along, up) }, binverse(Basis { long, thin, cross(long, thin) }))

// Moves a node up or down so its lowest vertex is at height y.
def corpse_ground(n:MNode, y:float):
    var lo = 1000000.0
    for(corpse_verts(n)) v: lo = min(lo, v.y)
    n.pos += float3 { 0.0, y - lo, 0.0 }

def corpse_centre(n:MNode) -> float3:
    var sum = float3_0
    let vs = corpse_verts(n)
    for(vs) v: sum += v
    return sum / float(max(1, vs.length))

// Every vertex under n's children, in n's parent's space; an item with no solid mesh (only flat decals: geom skips
// them) by its meshes' box corners.
def corpse_verts(n:MNode) -> [float3]:
    let out = []::float3
    for(n.kids) c:
        let vs = vertices(c, node_xform(n))
        append_into(out, if vs.length: vs else: corpse_corners(c, node_xform(n)))
    return out

// The corners of every mesh's box under n (n included), placed by t and n's own transform.
def corpse_corners(n:MNode, t0:Xform) -> [float3]:
    let out = []::float3
    let t = xmul(t0, node_xform(n))
    let m = n.mesh
    if m:
        let lo, size = mesh_box([m])
        for(8) c: out.push(xf(t, lo + size * float3 { float(c & 1), float((c >> 1) & 1), float((c >> 2) & 1) }))
    for(n.kids) c: append_into(out, corpse_corners(c, t))
    return out
