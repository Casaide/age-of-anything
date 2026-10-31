// ------------------------------------------------------------------ a unit put together in 3D (src/view/art/rig3d.gd)
// A unit put together in 3D the way the composer (view/unit_view.lobster) puts it together in 2D: the body's model,
// its legs at their hips (posed for a walk phase), its head on its socket, its gear on its sockets (worn armour
// fitted as the bake fits it), a rider on its mount's seat. Every piece keeps its model, its world transform, the
// joint it hangs from and its parent piece, for the placement check (placement/) and the dead laid down in 3D.
// 2D-only touches (a rider's near leg stretched down the flank, a pegasus's wings at the withers, a harness's
// couched weapon) are left to the projection checks.

let RIG_SCREEN_Y = 0.8660254         // one 3D unit straight up is this many screen units (elevation 30)

class Piece:
    name:string
    kind:string                      // body, arm, leg, head, armour, or the slot of the gear
    rig:string                       // main, mount or rider
    id:string                        // the model built (a hold or pose after "@")
    node:MNode
    geo:string                       // its model's cache key (voxels are kept per key and transform)
    xf:Xform
    joint:float3                     // where it hangs from, in the unit's space
    parent:string                    // the piece it hangs from ("" for a body)
    side = 0                         // a leg: +1 near, -1 far
    anchor = -1                      // a leg's hip in the body's anchors
    hip = float3_0
    flip = false
    legs_under = false               // a body whose legs show under a skirt
    cut = []::string                 // the body's parts.json cut (["legs"]: its legs baked at each hip)
    sockets = dictionary<string, float3>(5)   // fitted armour's own sockets (a harness's traces)
    harness = false
    slung = false
    mouth = false                    // held in the mouth (the body's hold is "mouth")

class Rigged:
    pieces = []::Piece
    flying = false
    body_pose = ""
    walker = "main"                  // the rig that stands on the ground
    gait:Gait? = nil
    seat = float3_0
    has_seat = false
    fused = false

class RigSide:                       // what _rig hands the gear: the body's sockets in the unit's space and more
    sockets:dictionary<string, float3>
    xf:Xform
    body:string
    modelled:bool
    spec:Spec? = nil
    gear_scale = 1.0
    rig = ""
    carry = ""
    drape_scale = 1.0
    hold = ""

// The models built so far (a part id and its colours' skins), and the fixtures' stand-ins.
let rig_specs = dictionary<string, Spec>(511)
let rig_keys = dictionary<string, string>(511)
let rig_none = dictionary<string, int>(127)
let rig_overrides = dictionary<string, Spec>(15)   // fixtures: a part id's old model, used in its place

let RIG_NONE = float3 { -1000000000.0, 0.0, 0.0 }   // (a socket or number a spec hasn't: a dictionary can't answer nil for a float3)
def shas(d:dictionary<string, float3>, k:string) -> bool: return d.get(k, RIG_NONE).x != RIG_NONE.x

def num_or(o:JV, k:string, d:float) -> float: return if has(o, k): as_float(at(o, k)) else: d

def rig_colour_key(c:Colours) -> string: return c.hex.get("skin", "") + c.hex.get("skin5", "")

// A part's model in these colours, built once (nil for a part with no model).
def rig_spec(id:string, c:Colours) -> Spec?:
    let k = id + "|" + rig_colour_key(c)
    let have = rig_specs.get(k)
    if have: return have
    if rig_none.get(k, 0): return nil
    let old = rig_overrides.get(id)
    let s = old or build_model(id, c)
    if s:
        rig_specs.set(k, s)
        rig_keys.set(k, k + (if old: "|old" else: ""))
    else: rig_none.set(k, 1)
    return s

def rig_key(id:string, c:Colours) -> string: return rig_keys.get(id + "|" + rig_colour_key(c), "")

def rig_has(id:string, c:Colours) -> bool: return rig_spec(id, c) != nil

def rig_clear():
    rig_specs.clear()
    rig_keys.clear()
    rig_none.clear()

def spec_v2(s:Spec, k:string, d:float2) -> float2:
    let v = s.nums.get(k, RIG_NONE)
    return if v.x != RIG_NONE.x: float2 { v.x, v.y } else: d

// unit_models.gd hips: where a rider's hips are on its own body (its sit socket, else the middle of its hips).
def spec_hips(s:Spec) -> float3:
    if shas(s.sockets, "sit"): return s.sockets.get("sit", float3_0)
    var sum = float3_0
    for(s.anchors) a: sum += a.pos
    return sum / max(1.0, float(s.anchors.length))

def rig_by(a:Rigged, name:string) -> Piece?:
    for(a.pieces) p:
        if p.name == name: return p
    return nil

// The pose: hold ("" for the unit's own), the walk phase (radians, as the composer's; -1 standing), a resting body
// pose, and the turn of what's held about z (degrees) or levelled forward (a spear's thrust).
class RigPose:
    hold = ""
    walk = -1.0
    body_pose = ""
    turn = 0.0
    level = false

def rig_unit(r:JV, pose:RigPose) -> Rigged:
    let out = Rigged {}
    out.body_pose = pose.body_pose
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    let walk = pose.walk
    let rp = at(r, "parts")
    if has(r, "mount"):
        let m = at(r, "mount")
        let mc = at(lib_creatures, rstr(m, "creature"))
        let fused = gbool(m, "fused", false)
        let mcol = colours_for(rstr(m, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
        let mbody = if fused: gstr(mc, "fused_body", rstr(mc, "body")) else: gstr(mc, "mount_body", rstr(mc, "body"))
        let g = rig_gait(mbody, false)
        out.gait = g
        let lift = rig_bob(g, walk)
        let mrig = rig_side(out, "mount", mbody, if fused: "" else: gstr(mc, "mount_head", rstr(mc, "head")), "", mcol,
                            Xform { BASIS_ID, float3 { 0.0, lift, 0.0 } }, true, walk, g, out.body_pose)
        let mp = at(m, "parts")
        for(mp.keys) slot, n:
            if slot == "back" and has_s(ptags_of(as_str(mp.a[n])), "flying"): out.flying = true   // (a pegasus's wings sit at the withers in 2D only)
            else: rig_gear(out, mrig, slot, as_str(mp.a[n]), mcol, RigPose {})
        let seat = mrig.sockets.get("seat", float3 { 0.0, 20.0, 0.0 })
        let rs = rig_spec(rstr(r, "body"), colours)
        let clinging = not fused and rs != nil and (rs.strs.get("carry", "") == "harness")
        var s = if fused: 1.0 elif clinging: 0.6 else: 0.8
        s *= float(gint(gobj(mc, "rider_scale"), rstr(r, "creature"), 100)) / 100.0
        // (UnitView.seat_offset: the rider's hips on the seat; a fused rider grows out of its mount)
        var at_ = if fused or not rs: seat else: seat - spec_hips(rs) * s
        if old_bugs.seat_dropped and not fused:
            let drop = if clinging: float2 { -1.0, 9.0 } else: float2 { 0.0, 6.0 }
            at_ = seat + float3 { drop.x, -drop.y / RIG_SCREEN_Y, 0.0 }
        let rrig = rig_side(out, "rider", rstr(r, "body"), rstr(r, "head"), rig_hold(r, pose), colours,
                            Xform { bscaled(BASIS_ID, float3_1 * s), at_ }, false, -1.0, nil, "")
        out.seat = seat
        out.has_seat = true
        for(rp.keys) slot, n: rig_gear(out, rrig, slot, as_str(rp.a[n]), colours, pose)
        out.walker = "mount"
        out.fused = fused
    else:
        let flies = has(rp, "back") and has_s(ptags_of(rstr(rp, "back")), "flying")
        out.flying = flies
        var g = rig_gait(rstr(r, "body"), flies)
        if gstr(get(lib_creatures, gstr(r, "creature", "")) or jobj(), "gait", "") == "hop" and not flies: g = Gait { 0.0, 1.0, 0.0, 0.0, 1.0, true }
        out.gait = g
        let lift = rig_bob(g, walk)
        let rg = rig_side(out, "main", rstr(r, "body"), rstr(r, "head"), rig_hold(r, pose), colours,
                          Xform { BASIS_ID, float3 { 0.0, lift, 0.0 } }, true, walk, g, out.body_pose)
        for(rp.keys) slot, n: rig_gear(out, rg, slot, as_str(rp.a[n]), colours, pose)
        out.walker = "main"
    let og = out.gait
    if walk >= 0.0 and not old_bugs.bob_before_foot and not (og and og.hops) and not out.flying:
        // (UnitView keeps the lowest foot where it stands: the body rides on its planted foot)
        let sp = RigPose {}
        sp.hold = pose.hold
        let stand = rig_unit(r, sp)
        let d = rig_lowest_foot(stand) - rig_lowest_foot(out)
        for(out.pieces) p:
            p.xf = Xform { p.xf.b, p.xf.o + float3 { 0.0, d, 0.0 } }
            p.joint += float3 { 0.0, d, 0.0 }
        if out.has_seat: out.seat += float3 { 0.0, d, 0.0 }
    return out

def rig_lowest_foot(a:Rigged) -> float:
    var lo = 1000000.0
    for(a.pieces) p:
        if p.kind == "leg" and p.rig == a.walker:
            for(vertices(p.node, p.xf)) v: lo = min(lo, v.y)
    return if lo < 1000000.0: lo else: 0.0

def rig_hold(r:JV, pose:RigPose) -> string:
    if pose.hold != "": return pose.hold
    let hand = gstr(at(r, "parts"), "hand_r", "")
    return if hand != "": hold_for(ptags_of(hand)) else: "low"

// The walk cycle the composer gives this body (swing, bob), from its leg count and its own numbers.
def rig_gait(body_id:string, flies:bool) -> Gait:
    let body = part(body_id)
    let legs = get(body, "legs")
    let g = gait_for(if legs: glist(legs, "anchors").length else: 0, flies)
    return if legs and has(legs, "gait"): gait_with(g, at(legs, "gait")) else: g

// How high the body rides at this walk phase (the old bob, before the planted foot: fixtures only).
def rig_bob(g:Gait, walk:float) -> float:
    if walk < 0.0 or g.hops or not old_bugs.bob_before_foot: return 0.0
    return abs(sin(rad(walk))) * max(g.bob, gait_for(2, false).bob) / RIG_SCREEN_Y   // (the bob a stiff-legged walker had: a keyed walk's own is small)

// A leg's turn at a walk phase (UnitView: sin(phase + leg phase) * swing, screen clockwise; phases in radians), as a
// turn about the body's lateral axis (+z), in degrees.
def rig_swing(g:Gait?, walk:float, leg_phase:float) -> float:
    if walk < 0.0 or not g or g.hops: return 0.0
    return rad(-sin(rad(walk + leg_phase)) * g.swing)

def rig_side(out:Rigged, rig:string, body_id:string, head_id:string, held:string, colours:Colours, t:Xform, with_legs:bool, walk:float, g:Gait?, body_pose:string) -> RigSide:
    var model_id = body_id + (if held == "low" or held == "": "" else: "@" + held)
    if body_pose != "": model_id = body_id + "@" + body_pose   // (a resting pose is the whole body baked in it)
    let body_n = gint(part(body_id), "body_steps", 0)
    if body_pose == "" and walk >= 0.0 and body_n > 0 and (held == "low" or held == ""):   // the walk step the composer draws (UnitView.body_steps)
        model_id = "{body_id}@w{int(fposmod(walk / (2.0 * MPI), 1.0) * float(body_n)) % body_n}_{body_n}"
    let bs = rig_spec(model_id, colours)
    if not rig_has(body_id, colours) or not bs: return RigSide { dictionary<string, float3>(3), t, body_id, false }
    let body = part(body_id)
    let bname = rig + ":body"
    let bp = Piece { bname, "body", rig, model_id, bs.node, rig_key(model_id, colours), t, t.o, "" }
    bp.legs_under = has_s(bs.flags, "legs_under")
    bp.cut = gstrs(body, "cut")
    out.pieces.push(bp)
    let front = bs.front
    if front:
        let ap = Piece { rig + ":arm", "arm", rig, model_id, front, rig_key(model_id, colours) + ":front", t, xf(t, bs.sockets.get("hand_r", float3_0)), bname }
        ap.side = 1
        out.pieces.push(ap)
    let sockets = dictionary<string, float3>(17)
    for(bs.sockets.get_keys()) k: sockets.set(k, xf(t, bs.sockets.get(k, float3_0)))
    let legs = get(body, "legs")
    if with_legs and legs:
        let cut = has_s(gstrs(body, "cut"), "legs")
        for(bs.anchors) a, i:
            let hind = a.more.length > 1 and a.more[1] != 0.0
            let leg_id = if hind: gstr(legs, "hind", rstr(legs, "part")) else: rstr(legs, "part")
            if rig_has(leg_id, colours):
                // (posed legs, parts.json legs.poses: a cat's walk baked in steps, its legs in a resting pose; the
                // step the composer picks for this phase)
                let n_steps = gint(legs, "poses", 0)
                var leg_model = leg_id
                if body_pose != "": leg_model = leg_id + "@" + body_pose
                elif n_steps > 0 and walk >= 0.0:
                    let f = (walk + a.phase) / (2.0 * MPI)
                    leg_model = "{leg_id}@w{int((f - floor(f)) * float(n_steps)) % n_steps}_{n_steps}"
                let ls = rig_spec(leg_model, colours)
                if ls:
                    let turn = axis_angle(float3 { 0.0, 0.0, 1.0 }, rig_swing(g, walk, a.phase))
                    let lxf = xmul(t, Xform { bmul(turn, leg_basis(a, cut)), a.pos })
                    let lp = Piece { "{rig}:leg{i}", "leg", rig, leg_model, ls.node, rig_key(leg_model, colours), lxf, xf(t, a.pos), bname }
                    lp.side = if a.pos.z > 0.0: 1 else: -1
                    lp.anchor = i
                    lp.hip = a.pos
                    lp.flip = a.more.length > 0 and int(a.more[0]) == 1
                    out.pieces.push(lp)
    var gear_scale = 1.0
    if head_id != "" and shas(bs.sockets, "head"):
        let hsock = bs.sockets.get("head", float3_0)
        let hs = rig_spec(head_id, colours)
        if hs:
            let hxf = xmul(t, Xform { BASIS_ID, hsock })
            out.pieces.push(Piece { rig + ":head", "head", rig, head_id, hs.node, rig_key(head_id, colours), hxf, sockets.get("head", float3_0), bname })
            gear_scale = hs.nums.get("gear_scale", float3_1).x
            let top = hs.sockets.get("top", float3 { 0.0, 8.0, 0.0 })
            sockets.set("top", xf(hxf, top))
            sockets.set("top_local", top)
    let rs = RigSide { sockets, t, body_id, true }
    rs.spec = bs
    rs.gear_scale = gear_scale
    rs.rig = rig
    rs.carry = bs.strs.get("carry", "")
    rs.drape_scale = float(gint(body, "drape_scale", 100)) / 100.0
    rs.hold = held
    return rs

// The turn about z (degrees) that points a held item's tip (its farthest point from the grip) along dir.
def rig_level(n:MNode, dir:float2) -> float:
    var tip = float2_0
    for(vertices(n, XF_ID)) v:
        if magnitude(float2 { v.x, v.y }) > magnitude(tip): tip = float2 { v.x, v.y }
    return if tip == float2_0: 0.0 else: atan2(dir) - atan2(tip)

def rig_gear(out:Rigged, rg:RigSide, slot:string, part_id0:string, colours:Colours, pose:RigPose):
    if not rg.modelled: return
    var part_id = part_id0
    var sock = socket_for(slot)
    let tags = ptags_of(part_id)
    if slot == "back" and shas(rg.sockets, part_id): sock = part_id   // (the body's own place for this piece, a bear's "cape.cloth")
    elif slot == "back" and has_s(tags, "drape") and shas(rg.sockets, "drape"): sock = "drape"
    if slot == "back" and has_s(tags, "banner") and not has_s(tags, "hero") and shas(rg.sockets, "banner"): sock = "banner"
    let sl = slung_on(rg.body, slot, part_id)
    if sl != "":
        sock = "sling"   // (a shield slung on the back, baked "<shield>@slung")
        part_id += sl
    let r = rg.rig
    let t = rg.xf
    let bs = rg.spec
    if slot == "torso":
        if not rig_has(part_id, colours) or not bs: return
        let fitted_s = fitted(part_id, rg.body, colours)
        var node = mnode()
        var axf = t
        var geo = part_id + "~" + rg.body
        if fitted_s:
            node = fitted_s.node
            geo += "|fitted"
        else:
            let gs = rig_spec(part_id, colours)
            if not gs: return
            node = gs.node
            let ts = spec_v2(bs, "torso_scale", float2_1)
            let fit = bs.nums.get("torso_fit", float3 { ts.x, ts.y, ts.x })
            let b = bscaled(euler(float3 { 0.0, 0.0, bs.nums.get("torso_tilt", float3_0).x }), fit)
            axf = xmul(t, Xform { b, bs.sockets.get("torso", float3_0) })
        let ap = Piece { r + ":armour", "armour", r, part_id, node, geo, axf, xf(t, bs.sockets.get("torso", float3_0)), r + ":body" }
        if fitted_s: ap.sockets = fitted_s.sockets
        ap.harness = has_s(tags, "harness")   // (a draught harness: its trace ends)
        out.pieces.push(ap)
        return
    if not shas(rg.sockets, sock) or not rig_has(part_id, colours): return
    let at_ = rg.sockets.get(sock, float3_0)
    let gs = rig_spec(part_id, colours)
    if not gs: return
    var gxf = Xform { t.b, at_ }
    var parent = r + ":body"
    if slot == "head_gear":
        gxf = Xform { bscaled(t.b, float3_1 * rg.gear_scale), at_ }
        parent = r + ":head"
    elif slot == "back" and (has_s(tags, "drape") or sock == part_id):
        gxf = Xform { bscaled(t.b, float3_1 * rg.drape_scale), at_ }   // (a cape sized to its back, or to the body's own place for it)
    if slot == "hand_r":
        // What the near hand holds turns with the swing (UnitView's attack and work), or lies levelled forward (a
        // spear's thrust; couched on a harness, a tool leant at 0.25).
        var turn = pose.turn
        if pose.level:
            turn = rig_level(gs.node, float2 { 1.0, 0.05 })
            gxf = Xform { gxf.b, gxf.o + bxf(t.b, float3 { 9.0, 0.0, 0.0 }) }
        elif rg.carry == "harness":
            turn = if starts_with(part_id, "tool."): rad(-0.25) else: rig_level(gs.node, float2 { 1.0, 0.3 })
        gxf = Xform { bmul(gxf.b, axis_angle(float3 { 0.0, 0.0, 1.0 }, turn)), gxf.o }
    if slot == "hand_r" and bs and bs.front: parent = r + ":arm"
    let p = Piece { r + ":" + slot, slot, r, part_id, gs.node, rig_key(part_id, colours), gxf, at_, parent }
    p.harness = rg.carry == "harness" and (slot == "hand_r" or slot == "hand_l")
    p.slung = sl != ""
    p.mouth = slot == "hand_r" and rg.hold == "mouth"
    out.pieces.push(p)
