// ------------------------------------------------------------------ the 3D half of the placement check (tests/placement/geometry_check.gd)
// Every unit put together in 3D (view/rig3d.lobster) in every pose the game draws it in (standing in each hold it's
// baked in, the swings, the walk at eight phases, its resting poses), its meshes read in world space and voxelized
// (view/geom.lobster), and the rules asserted as numbers (docs/rendering.md, "Placement rules"):
//   A1 ground: standing, every foot on the ground; walking, a foot planted and none sunk; nothing below the
//      ground; the centre of mass over the feet.
//   A2 attachment: hips, neck and hands on their parent's surface (not floating, not buried deep); a leg and a
//      head mostly outside the body; head gear on the head, the eyes in sight, an open cap over the brow; worn
//      armour round the body's torso; a rider's seat on its mount's back; siege crews on the ground or the deck.
//   A2 head join (four or more legs): the top line from the withers to the head runs without a notch.
//   A3 interpenetration: pieces that aren't jointed don't share volume; jointed ones only near the joint.
//   A4 stance (parts.json legs.stance): a standing leg reaches down, its foot out to its own side.
//   D1, D2 the dead (placement/corpse checks): a corpse on the ground, what it dropped clear of the body.
// Results are {rule|case: [failing views]}.

// Tolerances (part units; one part unit is 1.275 art pixels at game size).
let ENGINE_SINK = 4.0     // an engine (a beast's belly) pressed into the ground at most this deep
let GROUND_TOL = 1.0      // a foot within this of the ground plane; nothing deeper than this below it
let SUPPORT_SLACK = 3.0   // the centre of mass within this of the feet's support polygon
let ATTACH_GAP = 1.0      // a joint at most this far outside its parent's surface (floating)
let BURY = 4.0            // ...and at most this deep inside it (data: legs.stance.bury)
let OUTSIDE = 0.5         // at least this share of a leg's or head's volume outside its parent
let JOINT_R = 4.0         // jointed pieces may share volume this near the joint (or 45% of the child's reach)
let PEN_VOX = 12          // shared voxels allowed anywhere (1.5 cubic units: rounding where surfaces touch)
let PEN_SHARE = 0.03      // ...plus this share of the smaller piece
let ARMOUR_OFF = 0.25     // at most this share of worn armour more than 1.5 units off its body
let ARMOUR_CENTRE = 1.5   // worn armour's middle at most this far (across) from the middle of the body it covers
let SEAT_SINK = 0.3       // at most this share of a rider's body inside its mount
let SEAT_GAP = 1.5        // a rider's lowest point at most this far over its mount's back
let DROP = 0.6            // a standing leg's drop (hip to foot) is at least this share of its reach (data: legs.stance.drop)
let SPRAWL = [-2.0, 6.0]  // a standing foot this far out to its own side of its hip (data: legs.stance.sprawl)
let WALK_PHASES = 8
let BROW_CLEAR = 0.5      // an open cap's lowest edge over the eyes at least this above the brow
let HEAD_NOTCH = 1.0      // the top line from the withers to the head dips at most this (data: legs.stance.notch)
let NOTCH_SPIKE = 3       // ...after spikes narrower than this many voxel columns are levelled
let EYE_CLEAR = 3.0       // nothing of the head gear this far out in front of an eye
let LIE = 3.0             // a corpse's body, legs and head this near the ground at most

// The results: per rule and case, the views that broke it (and how).
let check_results = dictionary<string, [string]>(1023)
let check_order = []::string

def note(rule:string, label:string, view:string, bad:bool, detail:string):
    let key = rule + "|" + label
    var fails = check_results.get(key)
    if not fails:
        let none_yet = []::string
        check_results.set(key, none_yet)
        check_order.push(key)
        fails = none_yet
    if bad and fails: fails.push(view + (if detail != "": " (" + detail + ")" else: ""))

// Voxels of a piece, kept per model and transform across a unit's poses (a mount's body voxelizes once for all its
// riders; cleared when it grows).
let vox_cache = dictionary<string, Vox>(1023)
var vox_cached = 0

def pvox(p:Piece) -> Vox:
    let k = "{p.geo}|{p.xf.o}|{p.xf.b.x}|{p.xf.b.y}|{p.xf.b.z}"
    let have = vox_cache.get(k)
    if have: return have
    let v = voxels(p.node, p.xf)
    vox_cache.set(k, v)
    vox_cached++
    return v

def pverts(p:Piece) -> [float3]: return vertices(p.node, p.xf)

def stance_of(body_id:string) -> JV: return gobj(gobj(part(body_id), "legs"), "stance")


def legs_of(a:Rigged) -> [Piece]: return filter(a.pieces) p: p.kind == "leg" and p.rig == a.walker

// Numbers in the notes as Godot's "%.1f" and "%.2f" write them.
def f1(f:float) -> string:
    let n = int(round(abs(f) * 10.0))
    let s = "{n / 10}.{n % 10}"
    return if f < 0.0 and n > 0: "-" + s else: s
def f2(f:float) -> string:
    let n = int(round(abs(f) * 100.0))
    let s = "{n / 100}." + (if n % 100 < 10: "0" else: "") + "{n % 100}"
    return if f < 0.0 and n > 0: "-" + s else: s

// The poses a unit's body is drawn in beyond walking: its own hold standing, and the holds it swings through (a
// worker's tool wound up and landing, a melee blow, a spear's thrust levelled and driven forward). Ranged units only
// loose (their own hold). [name, hold, the weapon's turn (2D radians, clockwise on screen), levelled]
class Swing:
    name:string
    hold:string
    turn:float
    level:bool

def check_poses(r:JV) -> [Swing]:
    let out = [Swing { "stand", "", 0.0, false }]
    if has(r, "mount") or has(r, "crew"): return out
    let cols = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    let bs = rig_spec(rstr(r, "body"), cols)
    if bs and bs.strs.get("carry", "") == "harness": return out
    let hand = gstr(at(r, "parts"), "hand_r", "")
    let tags = if hand != "": ptags_of(hand) else: []::string
    let slot = gstr(r, "slot", "")
    if slot == "worker" and has_s(tags, "gather"):
        // (a gatherer's own tool, a basket or a sack, only forages: reaching down, tipped 0.3 at most; swung like an
        // axe, a basket went through a human's body: a pose the game never draws)
        out.push(Swing { "work forage", "reach", 0.3, false })
    elif slot == "worker":
        out.push(Swing { "work wound up", "raise", -1.2, false })
        out.push(Swing { "work blow", "reach", 0.9, false })
    elif has_s(tags, "ranged") or slot == "archer" or slot == "skirmisher" or slot == "healer": pass()
    elif has_s(tags, "spear") or has_s(tags, "lance"): out.push(Swing { "thrust", "thrust", 0.0, true })
    elif hand != "":
        out.push(Swing { "blow wound up", "raise", -1.1, false })
        out.push(Swing { "blow lands", "reach", 0.9, false })
        out.push(Swing { "blow starts", "reach", -0.4, false })
    return out

def walk_pose(i:int) -> RigPose:
    let p = RigPose {}
    p.walk = 2.0 * MPI * float(i) / float(WALK_PHASES)
    return p

def check_unit(label:string, r:JV) -> void:
    if has(r, "crew"):
        check_engine(label, r)
        rig_clear()
        if has(part(rstr(r, "body")), "legs"): check_unit(label, beast_recipe(r))   // (a war beast walks: its body, legs and head as any creature's)
        return
    // The data's 2D anchors (drawn before the body is baked, and the count of legs asked to bake) are the model's
    // hips, one for one.
    let cols = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    var mbody = ""
    if has(r, "mount"):
        let mc = at(lib_creatures, rstr(at(r, "mount"), "creature"))
        mbody = gstr(mc, "mount_body", rstr(mc, "body"))
    for([rstr(r, "body"), mbody]) body_id:
        if body_id != "" and has(part(body_id), "legs"):
            let bs = rig_spec(body_id, cols)
            if bs:
                let n3 = bs.anchors.length
                let n2 = glist(at(part(body_id), "legs"), "anchors").length
                note("A2 the data\'s legs are the model\'s", label, body_id, n2 != n3, "{body_id}: {n2} anchors in parts.json, {n3} hips in the model")
    for(check_poses(r)) po:
        let rp = RigPose {}
        rp.hold = po.hold
        rp.turn = rad(-po.turn)
        rp.level = po.level
        check_pose(label, po.name, rig_unit(r, rp), po.name == "stand")
    for(WALK_PHASES) i:
        let a = rig_unit(r, walk_pose(i))
        check_walk(label, "walk {i}", a)
        if i % 2 == 0: check_pose(label, "walk {i}", a, false)
    // A body that rests in its own poses when it stands still (parts.json idle_poses: a cat sits down in steps) is
    // checked in each, as standing: every foot down, the weight over the feet.
    var walker_body = rstr(r, "body")
    if has(r, "mount"):
        let mc = at(lib_creatures, rstr(at(r, "mount"), "creature"))
        walker_body = if gbool(at(r, "mount"), "fused", false): gstr(mc, "fused_body", rstr(mc, "body")) else: gstr(mc, "mount_body", rstr(mc, "body"))
    for(idle_poses_of(r, walker_body)) bp:
        let rp = RigPose {}
        rp.body_pose = bp
        check_pose(label, bp, rig_unit(r, rp), true)
    check_corpse(label, r)
    rig_clear()
    if vox_cached > 600:   // (kept across units: a mount's body and legs voxelize once for all its riders)
        vox_cache.clear()
        vox_cached = 0

// Ground contact while standing, attachment, interpenetration, stance.
def check_pose(label:string, view:string, a:Rigged, standing:bool):
    let legs = legs_of(a)
    let body = rig_by(a, a.walker + ":body")
    if not body: return
    let body_id = tokenize(body.id, "@", "")[0]
    var st = stance_of(body_id)
    if a.body_pose != "":
        // (a resting pose may relax the stance, legs.stance.poses: a sitting cat's hind legs fold flat)
        let over = gobj(gobj(st, "poses"), a.body_pose)
        if over.keys.length:
            st = shallow_copy(st)
            for(over.keys) k, n: set(st, k, over.a[n])
    if standing and legs.length and not a.flying:
        // A1: every foot on the ground; nothing below it; the weight over the feet.
        let feet = []::float2
        var worst = 0.0
        var what = ""
        for(legs) l:
            let vs = pverts(l)
            var lo = 1000000.0
            for(vs) v: lo = min(lo, v.y)
            if abs(lo) > abs(worst):
                worst = lo
                what = l.name
            var sum = float2_0
            var n = 0
            for(vs) v:
                if v.y <= lo + 0.5:
                    sum += float2 { v.x, v.z }
                    n++
            feet.push(sum / float(max(n, 1)))
            // A4: the leg reaches down (not folded up) and its foot is out to its side by the sprawl.
            var reach = 0.0
            for(vs) v: reach = max(reach, magnitude(v - l.joint))
            let drop = (l.joint.y - lo) / max(reach, 0.01)
            let want_drop = num_or(st, "drop", DROP)
            note("A4 a standing leg reaches down", label, view, drop < want_drop, "{l.name} drop {f2(drop)} of its reach, {f2(want_drop)} wanted")
            let foot = feet[feet.length - 1]
            let out_by = if abs(l.hip.z) > 0.3: (foot.y - l.joint.z) * sign(l.hip.z) else: 0.0
            let sp = if has(st, "sprawl"): map(glist(st, "sprawl")) v: as_float(v) else: SPRAWL
            note("A4 feet out to their own side", label, view, abs(l.hip.z) > 0.3 and (out_by < sp[0] or out_by > sp[1]),
                 "{l.name} foot {f1(out_by)} out from its hip, [{sp[0]}, {sp[1]}] wanted")
        note("A1 standing feet on the ground", label, view, abs(worst) > GROUND_TOL, "{what} lowest point at {f2(worst)}")
        var com = float3_0
        var mass = 0
        for(a.pieces) p:
            for(pvox(p).keys) q:
                com += vcentre(q)
                mass++
        com /= float(max(mass, 1))
        let off = outside_polygon(feet, float2 { com.x, com.z })
        let slack = num_or(st, "support", SUPPORT_SLACK)
        note("A1 weight over the feet", label, view, off > slack, "centre of mass {f1(off)} outside the feet, {f1(slack)} allowed")
    if standing and legs.length:
        // A leg that isn't the same on both sides (it sprawls out to one side, or points back on a rear hip) must be
        // baked at each hip, turned to its side (parts.json "cut": ["legs"]): one sprite for every hip puts the far
        // legs' feet under the body or the rear legs facing forward.
        let cut = has_s(body.cut, "legs")
        for(legs) l:
            var lo = float3_1 * 1000000.0
            var hi = float3_1 * -1000000.0
            for(vertices(l.node, XF_ID)) v:
                lo = min(lo, v)
                hi = max(hi, v)
            let one_sided = abs((lo.z + hi.z) * 0.5) > 0.6
            note("A2 one-sided legs baked at each hip", label, view, not cut and (one_sided or l.flip),
                 "{l.name} " + (if one_sided: "sprawls to one side" else: "points back on a rear hip"))
    if not starts_with(view, "walk"):
        var lowest = 1000000.0
        var what = ""
        for(a.pieces) p:
            for(pverts(p)) v:
                if v.y < lowest:
                    lowest = v.y
                    what = p.name
        note("A1 nothing below the ground", label, view, lowest < -GROUND_TOL, "{what} at {f2(lowest)}")
    check_attachment(label, view, a, st)
    check_head_join(label, view, a, st)
    check_overlap(label, view, a)

// A2 head join (Dominic on the bear mount, round B2: "mounted bears I think have broken neck still"; the head sat
// low and forward with a step between the shoulder hump and the back of the skull). On a beast of four or more legs
// whose head is ahead of its fore legs, the side silhouette's top line (body and head together, the highest voxel
// of each column along x) from the withers (the fore hips) and a little behind them, to the head's middle must not
// dip: no column more than HEAD_NOTCH below the lower of the highest points behind and ahead of it.
def check_head_join(label:string, view:string, a:Rigged, st:JV):
    let legs = legs_of(a)
    let head = rig_by(a, a.walker + ":head")
    let body = rig_by(a, a.walker + ":body")
    if legs.length < 4 or not head or not body: return
    let hv = pvox(head)
    var fore = -1000000.0
    var hind = 1000000.0
    for(legs) l:
        fore = max(fore, l.joint.x)
        hind = min(hind, l.joint.x)
    let withers = fore - 0.25 * (fore - hind)   // (a hump or the withers can rise behind the fore hips)
    var hx = 0.0
    for(hv.keys) q: hx += vcentre(q).x
    hx /= float(max(vcount(hv), 1))
    if hx <= fore + 1.0: return
    let i0 = int(floor(withers / GEOM_RES))
    let i1 = int(floor(hx / GEOM_RES))
    let n = i1 - i0 + 1
    var t = map(n): -100000
    for([pvox(body), hv]) cells:
        for(cells.keys) q:
            let c = vunkey(q)
            if c.x >= i0 and c.x <= i1: t[c.x - i0] = max(t[c.x - i0], c.y)
    // Thin spikes (an ear's tip, a strap's buckle, a crest's spine) are no shoulder for the water to stand against:
    // open the profile by NOTCH_SPIKE columns first.
    let opened = map(n) i:
        var m = -100000
        var j = max(0, i - NOTCH_SPIKE + 1)
        while j <= i:
            if j + NOTCH_SPIKE <= n:
                var w = 100000
                for(NOTCH_SPIKE) q: w = min(w, t[j + q])
                m = max(m, w)
            j++
        if m > -100000: m else: t[i]
    t = opened
    let left = copy(t)
    let right = copy(t)
    for(n - 1) k: left[k + 1] = max(left[k + 1], left[k])
    var k = n - 2
    while k >= 0:
        right[k] = max(right[k], right[k + 1])
        k--
    var worst = 0
    var at_ = 0
    for(n) i:
        let d = min(left[i], right[i]) - t[i]
        if d > worst:
            worst = d
            at_ = i
    let depth = min(float(worst) * GEOM_RES, 99.0)
    let tol = num_or(st, "notch", HEAD_NOTCH)
    note("A2 head joins the neck without a notch", label, view, depth > tol,
         "the top line dips {f1(depth)} between the withers (x {f1(withers)}) and the head (x {f1(hx)}), at x {f1((float(i0 + at_) + 0.5) * GEOM_RES)}; {f1(tol)} allowed")

// A1 while walking: one foot planted at every phase, none through the ground.
def check_walk(label:string, view:string, a:Rigged):
    let legs = legs_of(a)
    let g = a.gait
    if not legs.length or a.flying or (g and g.hops): return
    var lowest = 1000000.0
    for(legs) l:
        for(pverts(l)) v: lowest = min(lowest, v.y)
    note("A1 walking, a foot planted", label, view, lowest > GROUND_TOL, "lowest foot {f2(lowest)} over the ground")
    note("A1 walking, no foot through the ground", label, view, lowest < -GROUND_TOL, "a foot {f2(-lowest)} under the ground")

// Distance from p to the convex polygon round the points (0 inside); a segment or a point for fewer (Godot's
// Geometry2D: the hull closed by its first point again).
def convex_hull(pts:[float2]) -> [float2]:
    let p = copy(pts)
    insertion_sort(p) a, b: a.x < b.x or (a.x == b.x and a.y < b.y)
    let n = p.length
    let h = []::float2
    def cross3(o:float2, a:float2, b:float2) -> float: return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    for(n) i:
        while h.length >= 2 and cross3(h[h.length - 2], h[h.length - 1], p[i]) <= 0.0: h.pop()
        h.push(p[i])
    let t = h.length + 1
    var i = n - 2
    while i >= 0:
        while h.length >= t and cross3(h[h.length - 2], h[h.length - 1], p[i]) <= 0.0: h.pop()
        h.push(p[i])
        i--
    return h

def point_in_polygon(p:float2, poly:[float2]) -> bool:
    var inside = false
    var j = poly.length - 1
    for(poly) a, i:
        let b = poly[j]
        if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x: inside = not inside
        j = i
    return inside

def closest_on_segment(p:float2, a:float2, b:float2) -> float2:
    let d = b - a
    let l2 = dot(d, d)
    if l2 == 0.0: return a
    let t = dot(p - a, d) / l2
    return if t <= 0.0: a elif t >= 1.0: b else: a + d * t

def outside_polygon(pts:[float2], p:float2) -> float:
    let hull = convex_hull(pts)
    if hull.length >= 4 and point_in_polygon(p, hull): return 0.0
    var best = 1000000.0
    for(hull) a, i: best = min(best, magnitude(p - closest_on_segment(p, a, hull[(i + 1) % hull.length])))
    return if hull.length: best else: 0.0

def check_attachment(label:string, view:string, a:Rigged, st:JV):
    for(a.pieces) p:
        let parent = if p.parent != "": rig_by(a, p.parent) else: nil
        if parent:
            var pv = pvox(parent)
            let arm = rig_by(a, p.rig + ":arm")
            if ends_with(p.parent, ":body") and arm and p.kind == "hand_r": pv = pvox(arm)
            switch p.kind:
                case "leg", "head":
                    // Attached: it touches its body (a thigh may rise above its hip into the body), and its joint is
                    // neither off the body nor buried deep in it.
                    let mine = pvox(p)
                    let d = vdepth(pv, p.joint, 8.0)
                    let bury = if p.kind == "leg": num_or(st, "bury", BURY) else: BURY
                    let touches = vshared(mine, pv) > 0
                    note("A2 {p.kind} joint on its body\'s surface", label, view, (d > ATTACH_GAP and not touches) or d > ATTACH_GAP + 2.0 or d < -bury,
                         "{p.name} joint {f1(d)} " + (if d > 0.0: "outside" else: "inside") + " the body" + (if touches: "" else: ", not touching it"))
                    let outside = new_vox()
                    for(mine.keys) q:
                        if not vhas(pv, q): vadd(outside, q)
                    if p.kind == "leg" and parent.legs_under:
                        // (under a skirt: the leg shows below the body's hem)
                        var hem = 1000000.0
                        for(pv.keys) q: hem = min(hem, vcentre(q).y)
                        var foot = 1000000.0
                        for(mine.keys) q: foot = min(foot, vcentre(q).y)
                        note("A2 a leg shows under its skirt", label, view, hem - foot < 3.0, "{p.name} {f1(hem - foot)} below the hem")
                    else:
                        let share = float(vcount(outside)) / float(max(vcount(mine), 1))
                        let want = 1.0 - num_or(st, if p.kind == "leg": "inside" else: "head_inside", 1.0 - OUTSIDE)
                        note("A2 a {p.kind} mostly outside its body", label, view, share < want, "{p.name} {f2(share)} outside, {f2(want)} wanted")
                    // A3: what's outside comes out of the body in one piece (a leg through the body and out of its back
                    // is two pieces).
                    let parts = vcomponents(outside)
                    var stray = 0
                    for(parts) sz, i:
                        if i > 0: stray += sz
                    note("A3 a {p.kind} comes out of its body in one piece", label, view, stray > PEN_VOX + int(PEN_SHARE * float(vcount(mine))),
                         "{p.name} {stray} voxels in {parts.length - 1} other pieces")
                case "hand_r", "hand_l":
                    if not p.harness:
                        if p.slung:   // (a shield slung across the back: on the back, as back gear)
                            let db = vdepth(pv, p.joint, 8.0)
                            note("A2 a slung shield on the back", label, view, db > ATTACH_GAP + 1.0 and vshared(pvox(p), pv) == 0, "{p.name} {f1(db)} off the back, not touching it")
                        else:
                            let d = vdepth(pv, p.joint, 8.0)
                            note("A2 held in the hand", label, view, d > ATTACH_GAP, "{p.name} {f1(d)} off the hand")
                case "head_gear":
                    let mine = pvox(p)
                    let touch = vshared(mine, pv) > 0 or vdepth(pv, p.joint, 4.0) <= ATTACH_GAP
                    note("A2 head gear on the head", label, view, not touch, p.name)
                    check_brow(label, view, p, parent)
                case "back":
                    let d = vdepth(pv, p.joint, 8.0)
                    note("A2 back gear on the back", label, view, d > ATTACH_GAP + 1.0 and vshared(pvox(p), pv) == 0, "{p.name} {f1(d)} off the back, not touching it")
                case "armour":
                    if p.harness: harness_on_body(label, view, p, parent)   // (not body armour: its own rule)
                    else: check_armour(label, view, p, parent)
                default: pass()
    // A rider sits on its mount's back: not sunk into it, not floating over it.
    let rb = rig_by(a, "rider:body")
    let mb = rig_by(a, "mount:body")
    if rb and mb and not a.fused:
        let rv = pvox(rb)
        let mv = pvox(mb)
        let sunk = float(vshared(rv, mv)) / float(max(vcount(rv), 1))
        note("A2 rider not sunk into its mount", label, view, sunk > SEAT_SINK, "{f2(sunk)} of the rider inside the mount")
        // (the seat, where the rider's hips go, is on the mount's back: the top of the mount there)
        let c = vunkey(vcell(a.seat))
        var top = -1000000.0
        var j = c.y - 40
        while j < c.y + 40:
            for([-1, 0, 1]) i:
                if vhas(mv, vkey(c.x + i, j, c.z)): top = max(top, float(j + 1) * GEOM_RES)
            j++
        note("A2 the seat on its mount\'s back", label, view, abs(a.seat.y - top) > SEAT_GAP,
             "seat {f1(abs(a.seat.y - top))} " + (if a.seat.y > top: "over" else: "under") + " the back")

// Head gear leaves the face clear: every eye seen from in front of it (nothing of the gear within EYE_CLEAR out
// along the eye's look), and on a head with a modelled brow, nothing of an open cap or hat (not "face": "covered"
// in parts.json, as a face-guard helmet is) lower than BROW_CLEAR above it over the eyes: a cap's brim across the
// brows read as a headband (Dominic).
def check_brow(label:string, view:string, gear:Piece, head:Piece):
    let eyes = features(head.node, "eye", head.xf)
    if not eyes.length: return
    let gv = pvox(gear)
    var mid = float3_0
    let hv = pvox(head)
    for(hv.keys) q: mid += vcentre(q)
    mid /= float(max(vcount(hv), 1))
    let face = gstr(part(gear.id), "face", "")
    if face == "sealed": return   // (a sealed helmet, a mod's visor: the whole face behind it, by design)
    var covered = 0
    for(eyes) e:
        let c = e[0] + e[1] * 0.5
        let look = normalize(c - mid)
        var t = 1
        while t <= int(EYE_CLEAR / GEOM_RES):
            if vhas(gv, vcell(c + look * (float(t) * GEOM_RES))):
                covered++
                break
            t++
    note("A2 head gear leaves the eyes in sight", label, view, covered > 0, "{gear.id} covers {covered} of {eyes.length} eyes")
    let brows = features(head.node, "brow", head.xf)
    if not brows.length or face == "covered": return
    var brow = -1000000.0
    for(brows) b: brow = max(brow, b[0].y + b[1].y)
    var low = 1000000.0
    let boxes = append(eyes, brows)
    for(pverts(gear)) v:
        for(boxes) e:
            let lo = e[0] - float3_1 * 0.5
            let hi = e[0] + e[1] + float3_1 * 0.5
            if v.x >= lo.x and v.x <= hi.x and v.z >= lo.z and v.z <= hi.z and v.y < brow + 3.0: low = min(low, v.y)
    note("A2 an open cap clear of the brow", label, view, low < brow + BROW_CLEAR, "{gear.id} comes {f2(low - brow)} above the brow, {f2(BROW_CLEAR)} wanted")

// Worn armour round its body's torso: most of it on or near the body (not off in front), its middle near the middle
// of the body it covers.
def coarse_key(c:float3) -> int: return vkey(int(floor(c.x / 1.5)), int(floor(c.y / 1.5)), int(floor(c.z / 1.5)))

def check_armour(label:string, view:string, p:Piece, body:Piece):
    let av = pvox(p)
    let bv = pvox(body)
    let coarse = new_vox()
    for(bv.keys) q: vadd(coarse, coarse_key(vcentre(q)))
    let near = new_vox()
    for(coarse.keys) c:
        let u = vunkey(c)
        for(27) n: vadd(near, vkey(u.x + n % 3 - 1, u.y + (n / 3) % 3 - 1, u.z + n / 9 - 1))
    var off = 0
    var mid = float3_0
    for(av.keys) q:
        let c = vcentre(q)
        mid += c
        if not vhas(near, coarse_key(c)): off++
    mid /= float(max(vcount(av), 1))
    let share = float(off) / float(max(vcount(av), 1))
    note("A2 worn armour on its body", label, view, share > ARMOUR_OFF, "{p.id} {f2(share)} of it off the body")
    var lo = mid
    var hi = mid
    for(av.keys) q:
        lo = min(lo, vcentre(q))
        hi = max(hi, vcentre(q))
    // (its middle over the middle of the body inside it, the part of the body it covers, not off to the front of it
    // with the head riding on it: Dominic, the rat's)
    var torso = float3_0
    var n = 0
    for(bv.keys) q:
        let c = vcentre(q)
        if c.x >= lo.x and c.y >= lo.y and c.z >= lo.z and c.x <= hi.x and c.y <= hi.y and c.z <= hi.z:
            torso += c
            n++
    torso /= float(max(n, 1))
    let d = magnitude(float2 { mid.x - torso.x, mid.z - torso.z })
    note("A2 worn armour centred on the torso", label, view, d > ARMOUR_CENTRE,
         "{p.id} middle {f1(d)} from the middle of the body it covers, {f1(ARMOUR_CENTRE)} allowed")

// Pairs that are free to overlap: an arm and its own body (the shoulder), armour and what it wraps, head gear and
// its head, a weapon and the arm that holds it.
let WRAPPED = ["leg", "head", "back", "hand_l"]
let HELD = ["hand_r", "hand_l"]
let FREE = [["arm", "body"], ["armour", "body"], ["armour", "arm"], ["head_gear", "head"], ["hand_r", "arm"]]

def check_overlap(label:string, view:string, a:Rigged):
    let ps = a.pieces
    for(ps.length) i:
        var j = i + 1
        while j < ps.length:
            let p = ps[i]
            let q = ps[j]
            j++
            let cross = (p.rig == "rider") != (q.rig == "rider")
            var skip = (p.rig != q.rig and not cross) or
                       (cross and p.kind == "body" and q.kind == "body") or   // (the seat: its own check)
                       (cross and a.fused and (p.kind == "body" or q.kind == "body"))   // (a centaur's tunic covers the join)
            if not skip and p.rig == q.rig:
                for(FREE) f:
                    if (p.kind == f[0] and q.kind == f[1]) or (p.kind == f[1] and q.kind == f[0]): skip = true
            if not skip and ((has_s(["leg", "head"], p.kind) and p.parent == q.name) or (has_s(["leg", "head"], q.kind) and q.parent == p.name)):
                skip = true   // (a leg or head in its own body: the attachment rules above)
            if not skip:
                let pv = pvox(p)
                let qv = pvox(q)
                var common = vintersect(pv, qv)
                if common.length:
                    // Jointed (one hangs from the other, or armour round a leg's or head's root): only near the joint.
                    // The near arm's layer (with its scarf) meets the head at the neck; armour meets what hangs from
                    // the body near its root; what a rider holds may rest on its mount near the hand.
                    var child:Piece? = nil
                    if p.parent == q.name or (q.kind == "armour" and has_s(WRAPPED, p.kind)) or (q.kind == "arm" and p.kind == "head") or
                       (cross and has_s(HELD, p.kind) and p.rig == "rider") or (p.mouth and q.kind == "head"): child = p
                    elif q.parent == p.name or (p.kind == "armour" and has_s(WRAPPED, q.kind)) or (p.kind == "arm" and q.kind == "head") or
                         (cross and has_s(HELD, q.kind) and q.rig == "rider") or (q.mouth and p.kind == "head"): child = q
                    if p.kind == "armour" or q.kind == "armour":
                        // (inside the body, armour and what it wraps are both hidden: only the rest counts)
                        let bp = rig_by(a, p.rig + ":body")
                        if bp:
                            let bv = pvox(bp)
                            common = filter(common) c: not vhas(bv, c)
                    var bad = common.length
                    let allowed = PEN_VOX + int(PEN_SHARE * float(min(vcount(pv), vcount(qv))))
                    var rule = "A3 no cutting through"
                    if child:
                        var reach = 0.0
                        for(pvox(child).keys) c: reach = max(reach, magnitude(vcentre(c) - child.joint))
                        let rr = max(JOINT_R, 0.45 * reach)
                        bad = (filter(common) c: magnitude(vcentre(c) - child.joint) > rr).length
                        rule = "A3 jointed parts overlap only at the joint"
                    var mid = float3_0
                    for(common) c: mid += vcentre(c)
                    mid /= float(max(common.length, 1))
                    note(rule, label, view, bad > allowed, "{p.name} and {q.name} share {bad} voxels, {allowed} allowed, round ({round(mid.x)}, {round(mid.y)}, {round(mid.z)})")

// D1, D2: the unit as it lies dead (the last frame of its corpse pose), if its body has one.
def check_corpse(label:string, r:JV):
    let pose = corpse_pose_of(r)
    if not pose: return
    let m = corpse_model(r, pose, 1.0)
    let body = m.kids[0]
    let up_high = []::string
    let body_vox = new_vox()
    for(body.kids) w:
        var lo = 1000000.0
        for(vertices(w, node_xform(body))) v: lo = min(lo, v.y)
        if (w.meta == "body" or w.meta == "leg" or w.meta == "head") and lo > LIE: up_high.push("{w.meta} {f1(lo)} up")
        voxels_into(w, node_xform(body), body_vox)
    note("D1 a corpse lies on the ground", label, "down", up_high.length > 0, concat_string(up_high, ", "))
    let bad = []::string
    for(m.kids) d:
        if d != body:
            var lo = 1000000.0
            for(corpse_verts(d)) v: lo = min(lo, v.y)
            let vox = voxels(d.kids[0], node_xform(d))
            let shared = (filter(vox.keys) k: vhas(body_vox, k)).length
            if lo > 1.0 or float(shared) > float(PEN_VOX) + PEN_SHARE * float(vcount(vox)): bad.push("{d.meta} {f1(lo)} up, {shared} voxels in the body")
    note("D2 dropped gear on the ground, clear of the body", label, "down", bad.length > 0, concat_string(bad, ", "))

// A siege engine's crew sockets: on the ground (or on the deck for those riding on top), and the crew member put
// there not cut through the engine; then the composite rules (placement/composite.lobster).
def check_engine(label:string, r:JV) -> void:
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    let es = rig_spec(rstr(r, "body"), colours)
    if not es: return
    let ev = engine_whole(r, es)
    let cr = deep_copy(at(r, "crew"))
    for([["creature", rstr(r, "creature")], ["family", rstr(r, "family")], ["slot", "worker"], ["role", "worker"], ["name", ""]]) kv:
        if not has(cr, kv[0]): set(cr, kv[0], jstr(kv[1]))   // (merged in: the crew's own words stay)
    if not has(cr, "tier"): set(cr, "tier", jint(1))
    // The engine itself (a war beast with nobody on it too: the tarantula) stands on the ground: its lowest point (a
    // wheel, a runner, a foot) on the ground plane, not floating; a soft belly may press into it a little.
    var low = 1000000.0
    for(ev.keys) q: low = min(low, float(vunkey(q).y) * GEOM_RES)
    if not has(part(rstr(r, "body")), "legs"):   // (a war beast's body stands on its legs, baked apart: checked as a creature's)
        note("A1 the engine stands on the ground", label, rstr(r, "body"), low > GROUND_TOL + GEOM_RES or low < -ENGINE_SINK, "its lowest point at {f1(low)}")
    let sj = jobj()
    for(es.sockets.get_keys()) k: set(sj, k, jint(1))
    for(engine_sockets(r, sj)) name:
        if starts_with(name, "crew"):
            let at_ = es.sockets.get(name, float3_0)
            if ends_with(name, "_top") or ends_with(name, "_box"):   // (_box: in a walled howdah, its legs not drawn, set into the floor)
                // (something to stand on just under the feet: a deck, a saddle, a basket's floor; not floating over it)
                let c = vunkey(vcell(at_))
                var gap = 1000000.0
                var j = c.y
                while j > c.y - 16:
                    for(9) n:
                        if gap == 1000000.0 and vhas(ev, vkey(c.x + n % 3 - 1, j, c.z + n / 3 - 1)): gap = float(c.y - j) * GEOM_RES
                    j--
                note("A2 crew on top stand on the deck", label, name, gap > ATTACH_GAP + 0.5, "{f1(gap)} over the deck")
            else: note("A2 crew stand on the ground", label, name, abs(at_.y) > GROUND_TOL, "socket at height {f1(at_.y)}")
            var held = "low"
            for(tokenize(name, "_", "")) w:
                if has_s(WORK_HOLDS, w): held = w
            let s = float(gint(cr, "scale", 100)) / 100.0
            let rp = RigPose {}
            rp.hold = held
            let a = rig_unit(cr, rp)
            var t = Xform { bscaled_global(axis_angle(float3 { 0.0, 1.0, 0.0 }, -45.0 * float(engine_turn(name))), float3_1 * s), at_ }
            if not (ends_with(name, "_top") or ends_with(name, "_box")):   // (standing back by its lean, as UnitView._build_engine puts it)
                t = Xform { t.b, t.o - bxf(t.b, float3 { float(gint(gobj(lib_creatures, gstr(cr, "creature", "")), "crew_back", 0)), 0.0, 0.0 }) }
            let crew_vox = new_vox()
            for(a.pieces) p: voxels_into(p.node, xmul(t, p.xf), crew_vox)
            let share = float(vshared(crew_vox, ev)) / float(max(vcount(crew_vox), 1))
            note("A3 crew not cut through their engine", label, name, share > 0.12, "{f2(share)} of the crew member inside the engine")
    for(es.sockets.get_keys()) name:
        if starts_with(name, "haul"):   // (a beast hauling it, a trade cart's pony, stands on the ground)
            let y = es.sockets.get(name, float3_0).y
            note("A2 crew stand on the ground", label, name, abs(y) > GROUND_TOL, "socket at height {f1(y)}")
    check_composite(label, r)
