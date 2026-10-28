// ------------------------------------------------------------------ the 2D half of the placement check (tests/placement/projection_check.gd)
// Every unit is composed (view/unit_view.lobster) in all 8 facings, standing, at three walk phases and (a worker)
// at work, and each part's baked sprite laid onto a grid in the unit's own space, in draw order, so "A draws over
// B" is a count of pixels. The layering rules (docs/rendering.md) and these:
//   B5 ground: standing, every weight-bearing leg's lowest pixel on its foot's ground point (the 3D sole projected
//      by the bake camera) within FOOT_PX, and a near leg's foot in sight in the 3D truth; walking, the lowest
//      foot stays on the standing ground line and none goes below it.
//   B6 visibility: legs and head show where the 3D truth shows them; a rider's leg hangs down the flank that faces
//      the camera, and reaches down it.
// The 3D truth: the body's model with its legs at their hips and its head on its socket, drawn from the bake camera
// of the facing in flat colours (body, head, each leg its own), one pixel an art pixel (a small rasteriser here:
// pixel centres, a depth buffer).

class Pose2:
    name:string
    walking:bool
    phase:float
    body_pose = ""

let POSES2 = [Pose2 { "stand", false, 0.0 }, Pose2 { "walk0", true, 0.0 }, Pose2 { "walk1", true, 2.1 }, Pose2 { "walk2", true, 4.2 }]
// A hopper's walk on the ground (HOP_KEYS): deep in its crouch, squashed on landing.
let HOP_POSES = [Pose2 { "hop_crouch", true, 0.2 * 2.0 * 3.141592653589793 }, Pose2 { "hop_land", true, 0.82 * 2.0 * 3.141592653589793 }]
let WORK_POSES = [Pose2 { "forage", false, 0.0 }]   // drawn for every worker (placement/work2d.lobster)

// Thresholds (art pixels). Tolerant of a pixel or two of outline, strict enough for a leg on a back.
// Pixel tolerances were set at the art scale before D-173 (1.5); they keep their size on screen at a finer scale (at 2x a
// pixel is half as big, so the same slack is twice the pixels).
let PX_SCALE = BAKE_ART / (1.5 * 0.85)
let MODEL_SLACK = int(round(6.0 * PX_SCALE))   // pixels a leg or head may differ from the 3D model by (the outline, rounding)...
let MODEL_SHARE = 0.08         // ...or this share of the part's pixels
let HIDDEN_MIN = 3             // a weapon or shield shows at least this many pixels in every facing
let ARMOUR_SHARE = 0.8         // worn armour covers at most this share of its body (a whole copy of the body is 1)
let FACE_TEAM_SHARE = 0.3      // team cloth over at most this share of a head facing the camera
let FOOT_PX = int(round(2.0 * PX_SCALE))   // a standing foot's lowest pixel within this of its ground point; walking, of the standing line
let RIDER_REACH = 0.8          // a person riding: its leg reaches at least this share of the way from the seat to the girth...
let CLING_REACH = 0.1          // ...a clinging or folded-legged rider's at least onto the flank

var old_truth = false          // fixtures: the truth before 2026-10-13 (the first leg's part at every hip, unturned)
var check_team = float3 { 1.0, 0.0, 0.0 }

// ---- a sprite's pixels (read back from its sheet: the bake keeps them only on the GPU)

class Pixels:
    pts:[float2]               // opaque pixel centres in part units
    team:[bool]                // which are team colour

let pixel_cache = dictionary<string, Pixels>(4095)
let sheet_bytes = dictionary<int, string>(4095)

def pixels_of(key:string) -> Pixels:
    let have = pixel_cache.get(key)
    if have: return have
    let b = bakes.get(key)
    let out = Pixels { [], [] }
    let fi = frame_at.get("p:" + key, -1)
    if b and fi >= 0:
        let fr = frames[fi]
        var bytes = sheet_bytes.get(fr.sheet, "")
        if bytes == "":
            bytes = gl.read_texture(sheet_tex[fr.sheet]) or ""
            sheet_bytes.set(fr.sheet, bytes)
        let sw = int(sheet_dims[fr.sheet].x)
        if (fr.y + fr.h - 1) * sw * 4 + (fr.x + fr.w) * 4 > bytes.length:
            print "pixels_of {key}: frame {fr.x},{fr.y} {fr.w}x{fr.h} on sheet {fr.sheet} ({sheet_dims[fr.sheet]}, {bytes.length} bytes read)"
            pixel_cache.set(key, out)
            return out
        for(fr.h) y:
            for(fr.w) x:
                let i = ((fr.y + y) * sw + fr.x + x) * 4
                if bytes[i + 3] > 25:   // (alpha > 0.1)
                    out.pts.push((float2 { float(x), float(y) } + float2_1 * 0.5 - float2 { b.ox, b.oy }) / b.scale)
                    let r = float(bytes[i]) / 255.0
                    let g = float(bytes[i + 1]) / 255.0
                    let bl = float(bytes[i + 2]) / 255.0
                    out.team.push(min(r, bl) - g > 0.22 and abs(r - bl) < 0.3)
    pixel_cache.set(key, out)
    return out

def clear_pixel_caches():
    pixel_cache.clear()
    sheet_bytes.clear()

// ---- the composed parts


let XF_ID2 = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]   // (the 2D transforms' identity)

class P2:
    node:VNode
    id:string
    kind:string                // a part's slot, "arm" (a body's near-arm layer) or "shadow"
    rig:string                 // main, mount or rider
    cells:IMap                 // cell -> 1, or 0 where the pixel is team colour
    near = true
    team = 0
    unbaked = false

def base_id(id:string) -> string: return tokenize(tokenize(id, "~", "")[0], "@", "")[0]

def parts2(v:UV) -> [P2]:
    let out = []::P2
    collect2(v, v.node, XF_ID2, out)
    return out


def collect2(v:UV, n:VNode, t:[float], out:[P2]) -> void:
    for(n.kids) c:
        if c.visible:
            let ct = xf_mul(t, xf_local(c))
            if c.part: out.push(part2(v, c, ct))
            collect2(v, c, ct, out)

def part2(v:UV, ps:VNode, t:[float]) -> P2:
    let p = P2 { ps, ps.part_id, "", "main", new_imap() }
    if ps == v.shadow: p.kind = "shadow"
    else:
        p.kind = if ps.front: "arm" else: gstr(part(base_id(ps.part_id)), "slot", "")
        var a = ps.parent
        while a and a.parent != v.bob and a.parent != v.seat_node: a = a.parent
        if a and v.seat_node and a.parent == v.seat_node: p.rig = "rider"
        elif has(v.recipe, "mount"): p.rig = "mount"
    let key = draw_key(ps)
    let b = bakes.get(key)
    if not b:
        p.unbaked = true
        return p
    let px = pixels_of(key)
    for(px.pts) q, i:
        let w = xf_apply(t, q)
        let c = ckey(int(floor(w.x * b.scale)), int(floor(w.y * b.scale)))
        if px.team[i]:
            p.team++
            iset(p.cells, c, 0)
        else: iset(p.cells, c, 1)
    return p

// Pixels of a drawn over pixels of b (0 when a draws first).
def over2(parts:[P2], a:int, b:int) -> int:
    if a < b: return 0
    var n = 0
    for(parts[a].cells.keys) c:
        if ihas(parts[b].cells, c): n++
    return n

// Pixels of part i that no later part covers.
def visible2(parts:[P2], i:int) -> int:
    var n = 0
    for(parts[i].cells.keys) c:
        var hidden = false
        var j = i + 1
        while j < parts.length and not hidden:
            if parts[j].kind != "shadow" and parts[j].node.alpha > 0.9 and ihas(parts[j].cells, c): hidden = true
            j++
        if not hidden: n++
    return n

def find2(parts:[P2], rig:string, kind:string) -> [int]: return filter(parts.length) i: parts[i].rig == rig and parts[i].kind == kind

def jdepth(depth:JV, k:string) -> float: return jf(depth, k, 0.0)

def check_view(v:UV, label:string, view:string, k:int, r:JV, stand:dictionary<string, IMap>) -> void:
    let parts = parts2(v)
    // Every part drawn has its bake (else the game draws a magenta marker).
    let missing = map(filter(parts) p: p.unbaked and p.kind != "shadow") p: p.id
    note("every part drawn is baked", label, view, missing.length > 0, concat_string(missing, ", "))
    // Which legs are near (on the camera's side of the body), from the bake's anchors (3D truth).
    for(v.legs) leg:
        for(parts) p, i:
            if p.node == leg.node: p.near = anchor_near(parts, i, leg.rest, k)
    // Shadows under everything.
    let shadow = find2(parts, "main", "shadow")
    note("shadow first", label, view, shadow.length == 0 or shadow[0] != 0, "")
    for(["main", "mount", "rider"]) rg:
        let bodies = find2(parts, rg, "body")
        if bodies.length:
            let body = bodies[0]
            let body_rig = rig(parts[body].id + facing_suffix(k))
            let depth = gobj(body_rig, "depth")
            let under = gbool(body_rig, "legs_under", false)
            for(find2(parts, rg, "leg")) i:
                if not parts[i].near and find_string(parts[i].id, "~") < 0:   // (a leg cut by its body may draw over it: it holds only what shows)
                    note("far legs behind the body", label, view, over2(parts, i, body) > 0, "{over2(parts, i, body)} px")
                elif under: note("legs under a skirt", label, view, i > body, "")
            let heads = find2(parts, rg, "head")
            // Legs and head show where the 3D model shows them.
            if rg != "rider" and (ends_with(view, "stand") or v.body_pose != ""): check_model(v, parts, rg, body, label, view, k, r, stand)
            elif rg != "rider" and stand.get(rg) and v.job == "":   // (at work: work2d)
                let lows = stand.get(rg)
                if lows: check_walk2(v, parts, rg, label, view, lows)
            // Back parts: behind the body when the back faces away from the camera, over it when it faces it.
            for(find2(parts, rg, "back")) i:
                let d = jdepth(depth, if rg == "mount" and has(depth, "wings"): "wings" else: "back")
                if rg == "mount" and not has(get(lib_parts, base_id(parts[i].id)) or jobj(), "blur"):
                    // (a mount's wings rise from its withers: over its back, unless the withers are turned away;
                    // under the rider always; a wing blur draws like any back part instead)
                    note("a mount\'s wings over its back, behind it turned away", label, view, (i > body) != (k == 0 or d >= -0.5), "")
                    let rider = find2(parts, "rider", "body")
                    note("a mount\'s wings under the rider", label, view, rider.length > 0 and i > rider[0], "")
                elif k != 0 and d < -0.5: note("back parts behind the body facing the camera", label, view, over2(parts, i, body) > 0, "{over2(parts, i, body)} px")
                elif k != 0 and d > 0.5: note("back parts over the body facing away", label, view, over2(parts, body, i) > 0, "{over2(parts, body, i)} px")
            // What the near hand holds draws over the body; a weapon or shield never vanishes.
            for(["hand_r", "hand_l"]) slot:
                for(find2(parts, rg, slot)) i:
                    if find_string(parts[i].id, "@slung") >= 0:
                        // (a shield slung on the back: upright, drawn as back gear by its sling's depth; flat on top,
                        // over the body)
                        let ds = jdepth(depth, "sling")
                        if find_string(parts[i].id, "@slung_flat") >= 0: note("a shield slung flat over the body", label, view, over2(parts, body, i) > 0, "{over2(parts, body, i)} px")
                        elif k != 0 and ds < -0.5: note("back parts behind the body facing the camera", label, view, over2(parts, i, body) > 0, "{over2(parts, i, body)} px")
                        elif k != 0 and ds > 0.5: note("back parts over the body facing away", label, view, over2(parts, body, i) > 0, "{over2(parts, body, i)} px")
                    else:
                        if k != 0 and jdepth(depth, slot) >= 0.5: note("near hand over the body", label, view, over2(parts, body, i) > 0, "{over2(parts, body, i)} px")
                        if not (k != 0 and jdepth(depth, slot) < -0.5):   // (in the far hand: the body may hide it)
                            let seen = visible2(parts, i)
                            note("weapons and shields show", label, view, seen < min(HIDDEN_MIN, parts[i].cells.keys.length), "{parts[i].id} {seen} px seen")
            // Worn armour is baked on its body with the body cut away: it never carries a copy of the body.
            for(find2(parts, rg, "torso")) i:
                if find_string(parts[i].id, "~") >= 0:
                    let share = float(over2(parts, i, body)) / max(1.0, float(parts[body].cells.keys.length))
                    note("worn armour holds no body", label, view, share > ARMOUR_SHARE, "{f2(share)} of the body")
            // Team cloth never covers a face turned to the camera.
            let dir = if has(body_rig, "dir"): v2(at(body_rig, "dir")) else: float2 { 1.0, 0.0 }
            if heads.length and (k == 0 or dir.y > 0.2) and rg != "mount":
                let h = heads[0]
                var team = 0
                var j = h + 1
                while j < parts.length:
                    if parts[j].kind != "head_gear" and parts[j].kind != "shadow" and parts[j].rig == rg:
                        for(parts[j].cells.keys) c:
                            if iget(parts[j].cells, c, 1) == 0 and ihas(parts[h].cells, c): team++
                    j++
                let share = float(team) / max(1.0, float(parts[h].cells.keys.length))
                note("team cloth never over the face", label, view, share > FACE_TEAM_SHARE, "{f2(share)} of the head")
    // A rider sits over its mount: no mount part over the rider, its near leg down the flank shows.
    let mb = find2(parts, "mount", "body")
    if mb.length and find2(parts, "rider", "body").length:
        var bad = 0
        for(parts) p, i:
            if p.rig == "mount" and p.kind != "shadow":
                for(parts) q, j:
                    if q.rig == "rider": bad += over2(parts, i, j)
        note("rider over the mount", label, view, bad > 0, "{bad} px")
        for(find2(parts, "rider", "leg")) i: note("rider\'s near leg over the mount\'s flank", label, view, i < mb[0], "")
        if ends_with(view, "stand") or v.body_pose != "": check_rider_leg(v, parts, mb[0], label, view, k, r)

// A leg's side from its body's anchors in this facing: the anchor at the leg's rest position.
def anchor_near(parts:[P2], leg:int, rest:float2, k:int) -> bool:
    let root = parts[leg].node.parent
    if root:
        for(root.kids) c:
            if c.part and not c.front and gstr(part(base_id(c.part_id)), "slot", "") == "body":
                let rg = rig_or(c.part_id + facing_suffix(k), c.part_id)
                let anchors = if has(rg, "anchors"): glist(rg, "anchors") else: glist(gobj(part(tokenize(c.part_id, "@", "")[0]), "legs"), "anchors")
                for(anchors) a:
                    if magnitude(float2 { as_float(a.a[0]), as_float(a.a[1]) } - rest) < 0.01: return as_float(a.a[3]) > 0.0
    return parts[leg].node.z > 0.0

// The bake camera of facing k: screen right and screen up in 3D, and the way towards the camera.
def camera(k:int) -> [float3]:
    let az = BAKE_AZIMUTH + BAKE_FACING_STEP * float(k)
    let el = BAKE_ELEVATION
    let z = float3 { sin(az) * cos(el), sin(el), cos(az) * cos(el) }
    let x = normalize(cross(float3 { 0.0, 1.0, 0.0 }, z))
    let y = cross(z, x)
    return [x, y, z]

// A 3D point in a body's frame as the bake draws it: part units in the body sprite's 2D frame.
def project(p:float3, cam:[float3]) -> float2: return float2 { dot(p, cam[0]), -dot(p, cam[1]) }

// ---- the 3D truth (a flat-colour render from the bake camera: each pixel the nearest piece's id)

class TLeg:
    base:string
    basis:Basis
    hip:float2

class Truth:
    cells:IMap                 // cell -> 0 body, 1 head, 2 + i leg i
    feet:[Vox]                 // per leg: its cells
    legs:[TLeg]
    want_basis:[Basis]
    flipped:bool

let truth_cache = dictionary<string, Truth>(1023)

class TPiece:
    node:MNode
    t:Xform
    id:int

// Draws the pieces in flat ids from facing k's camera, one pixel an art pixel times the render's size rounding, as
// the bake's orthographic camera does: its box round them all, 2 units more, the camera at its middle.
def truth_render(pieces:[TPiece], k:int, at:float = 1.0) -> IMap, int2:   // (at: the size the parts are baked at, D-180)
    let cam = camera(k)
    var lo = float3_1 * 1000000.0
    var hi = float3_1 * -1000000.0
    let tris = []::float3
    let ids = []::int
    for(pieces) pc:
        let t0 = xmul(pc.t, node_xform(pc.node))
        truth_tris(pc.node, t0, pc.id, tris, ids)
        let blo, bhi = truth_box(pc.node, t0)
        lo = min(lo, blo)
        hi = max(hi, bhi)
    let r = magnitude(hi - lo) * 0.5 + 2.0
    let size = int(ceiling(2.0 * r * BAKE_ART * at))
    let ppu = float(size) / (2.0 * r)
    let mid = (lo + hi) * 0.5
    let sx0 = float(size) * 0.5 - dot(mid, cam[0]) * ppu
    let sy0 = float(size) * 0.5 + dot(mid, cam[1]) * ppu
    let origin = float2 { sx0, sy0 }   // (where the world's 0 lands: Camera3D.unproject_position)
    let depth = map(size * size): -1000000.0
    let idbuf = map(size * size): -1
    var t = 0
    while t < tris.length:
        let s = map(3) q: float2 { sx0 + dot(tris[t + q], cam[0]) * ppu, sy0 - dot(tris[t + q], cam[1]) * ppu }
        let d = map(3) q: dot(tris[t + q], cam[2])
        let area = (s[1].x - s[0].x) * (s[2].y - s[0].y) - (s[2].x - s[0].x) * (s[1].y - s[0].y)
        if abs(area) > 0.0000001:
            let x0 = max(0, int(floor(min(s[0].x, min(s[1].x, s[2].x)))))
            let x1 = min(size - 1, int(ceiling(max(s[0].x, max(s[1].x, s[2].x)))))
            let y0 = max(0, int(floor(min(s[0].y, min(s[1].y, s[2].y)))))
            let y1 = min(size - 1, int(ceiling(max(s[0].y, max(s[1].y, s[2].y)))))
            var y = y0
            while y <= y1:
                var x = x0
                while x <= x1:
                    let px = float(x) + 0.5
                    let py = float(y) + 0.5
                    let w0 = ((s[2].x - s[1].x) * (py - s[1].y) - (px - s[1].x) * (s[2].y - s[1].y)) / area
                    let w1 = ((s[0].x - s[2].x) * (py - s[2].y) - (px - s[2].x) * (s[0].y - s[2].y)) / area
                    let w2 = 1.0 - w0 - w1
                    if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
                        let z = w0 * d[0] + w1 * d[1] + w2 * d[2]
                        let i = y * size + x
                        if z > depth[i]:
                            depth[i] = z
                            idbuf[i] = ids[t / 3]
                    x++
                y++
        t += 3
    let cells = new_imap()
    for(size) y:
        for(size) x:
            let id = idbuf[y * size + x]
            if id >= 0: iset(cells, ckey(int(floor(float(x) + 0.5 - origin.x)), int(floor(float(y) + 0.5 - origin.y))), id)
    return cells, int2 { size, size }

// The box the bake frames them by (PartBaker._aabb): each mesh's own box turned with it, merged; hidden ones too.
def truth_box(n:MNode, t:Xform) -> float3, float3:
    var lo = float3_1 * 1000000.0
    var hi = float3_1 * -1000000.0
    let m = n.mesh
    if m:
        let mlo, msize = mesh_box([m])
        let a, sz = xf_box(t, mlo, msize)
        lo = min(lo, a)
        hi = max(hi, a + sz)
    for(n.kids) c:
        let clo, chi = truth_box(c, xmul(t, node_xform(c)))
        lo = min(lo, clo)
        hi = max(hi, chi)
    return lo, hi

def truth_tris(n:MNode, t:Xform, id:int, tris:[float3], ids:[int]) -> void:
    let m = n.mesh
    if m and n.visible:
        let w = map(m.p) p: xf(t, p)
        let count = if m.idx.length: m.idx.length / 3 else: m.p.length / 3
        for(count) f:
            for(3) q: tris.push(w[if m.idx.length: m.idx[f * 3 + q] else: f * 3 + q])
            ids.push(id)
    for(n.kids) c: truth_tris(c, xmul(t, node_xform(c)), id, tris, ids)

// The 3D truth of a body in facing k. Each hip gets the leg part the body puts there (its hind part at a hind hip)
// turned by leg_basis, as the bake turns it (old_truth: the first leg's part, unturned).
def truth_of(body:VNode, v:UV, heads:[VNode], k:int) -> Truth:
    let pose = if v.body_pose != "" and tokenize(body.part_id, "@", "")[0] == v.pose_body: "@" + v.body_pose else: ""
    let body_id = tokenize(body.part_id, "@", "")[0]
    let bdata = part(body_id)
    let cut = has_s(gstrs(bdata, "cut"), "legs")
    let head = if heads.length: heads[0] else: nil
    let key = bake_key(body.part_id, body.pshapes, body.cols, body.size) + "|" + (if head: head.part_id else: "") + "|{k}|{old_truth}"
    let have = truth_cache.get(key)
    if have: return have
    let cols = body.cols or colours_for("frog_green", "swamp", float3 { 1.0, 0.0, 1.0 })
    let spec = rig_spec(body.part_id, cols)
    let tr = Truth { new_imap(), [], [], [], false }
    if not spec:
        truth_cache.set(key, tr)
        return tr
    let pieces = [TPiece { spec.node, XF_ID, 0 }]
    let cam = camera(k)
    let legs = gobj(bdata, "legs")
    for(spec.anchors) a, i:
        let hind = a.more.length > 1 and a.more[1] != 0.0
        var leg_id = (if hind: gstr(legs, "hind", rstr(legs, "part")) else: rstr(legs, "part")) + pose
        var basis = leg_basis(a, cut)
        tr.want_basis.push(basis)
        if old_truth:
            leg_id = rstr(legs, "part") + pose
            basis = BASIS_ID
        if not cut and bdet(basis) < 0.0: tr.flipped = true   // (an uncut leg mirrored in 2D: its truth isn't one render)
        tr.legs.push(TLeg { tokenize(leg_id, "@", "")[0], basis, project(a.pos, cam) })
        let ls = rig_spec(leg_id, cols)
        if ls: pieces.push(TPiece { ls.node, Xform { basis, a.pos }, 2 + i })
    if head:
        let hs = rig_spec(tokenize(head.part_id, "~", "")[0], cols)
        if hs: pieces.push(TPiece { hs.node, Xform { BASIS_ID, spec.sockets.get("head", float3_0) - hs.node.pos }, 1 })   // (its position the socket: Godot sets it)
    let cells, size = truth_render(pieces, k, float(body.size) / 100.0)   // (on the parts' own grid: baked at the unit's size)
    tr.cells = cells
    tr.feet = map(spec.anchors.length): new_vox()
    for(cells.keys) c:
        let id = iget(cells, c, -1)
        if id >= 2 and id - 2 < tr.feet.length: vadd(tr.feet[id - 2], c)
    truth_cache.set(key, tr)
    return tr

def truth_kind(id:int) -> string: return if id == 0: "body" elif id == 1: "head" else: "leg"

// A part's opaque cells in its rig's space (its own transform only: legs, head, body are the rig root's children).
def cells_in_rig(n:VNode) -> IMap:
    let cells = new_imap()
    let key = draw_key(n)
    let b = bakes.get(key)
    if b:
        let t = xf_local(n)
        for(pixels_of(key).pts) q:
            let p = xf_apply(t, q)
            iset(cells, ckey(int(floor(p.x * b.scale)), int(floor(p.y * b.scale))), 1)
    return cells

def lowest_y(cells:IMap) -> float:
    var got = -1000000.0
    for(cells.keys) c: got = max(got, float(cunkey(c).y + 1))
    return got

// A truth pixel two pixels inside its region (the bake's outline and rounding stay out of the count).
def interior(cells:IMap, c:int, want:int) -> bool:
    let u = cunkey(c)
    for([int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }, int2 { 2, 0 }, int2 { -2, 0 }, int2 { 0, 2 }, int2 { 0, -2 }]) d:
        let w = iget(cells, ckey(u.x + d.x, u.y + d.y), -1)
        if (if want >= 2: w < 2 else: w != want): return false
    return true

// B6 and the layering rule 2: legs and head against the 3D truth. B5: feet on their ground points.
def check_model(v:UV, parts:[P2], rg:string, body:int, label:string, view:string, k:int, r:JV, stand:dictionary<string, IMap>):
    let legs = find2(parts, rg, "leg")
    let heads = find2(parts, rg, "head")
    let body_id = parts[body].id
    let bcols = parts[body].node.cols
    if not legs.length or not bcols or not rig_has(body_id, bcols): return
    let leg_nodes = map(legs) i: parts[i].node
    let gt = truth_of(parts[body].node, v, map(heads) i: parts[i].node, k)
    // The truth is built from the same parts as the unit: one leg per hip, each its own part and turn.
    let composed = filter(v.legs) leg: has_node(leg_nodes, leg.node) and not leg.cling
    var mismatch = gt.legs.length != composed.length
    for(min(gt.legs.length, composed.length)) i:
        let want = gt.legs[i]
        let wb = gt.want_basis[i]
        let same_basis = magnitude(want.basis.x - wb.x) + magnitude(want.basis.y - wb.y) + magnitude(want.basis.z - wb.z) < 0.000001
        mismatch = mismatch or want.base != tokenize(composed[i].base, "@", "")[0] or magnitude(want.hip - composed[i].rest) > 0.3 or not same_basis
    note("B6 the 3D truth has the unit\'s legs, one for one", label, view, mismatch,
         "truth {map(gt.legs) l: l.base}, composed {map(composed) l: l.base}")
    if gt.flipped: return
    // The composed unit in the rig's own space, at stand: each cell's topmost of body, legs, head.
    let top = new_imap()   // cell -> part index
    let order = append(append([body], legs), heads)
    insertion_sort(order) a, b: a < b
    let rig_cells = map(parts.length) i: if has_int(order, i): cells_in_rig(parts[i].node) else: new_imap()
    for(order) i:
        for(rig_cells[i].keys) c: iset(top, c, i)
    let over = map(parts.length): 0    // pixels drawn over the body where the model hides them
    let under = map(parts.length): 0   // pixels of it the body covers where the model shows them
    for(gt.cells.keys) c:
        let want = iget(gt.cells, c, -1)
        if interior(gt.cells, c, want) and ihas(top, c):
            let got = iget(top, c, -1)
            if want == 0 and got != body: over[got]++
            elif want != 0 and got == body:
                for(if want >= 2: legs else: heads) i:
                    if ihas(rig_cells[i], c):
                        under[i]++
                        break
    for(append(legs, heads)) i:
        let allowed = max(MODEL_SLACK, int(MODEL_SHARE * float(parts[i].cells.keys.length)))
        let what = "{rg} {parts[i].kind}" + (if parts[i].kind == "head": "" elif parts[i].near: " near" else: " far")
        note("legs and head over the body only where the model shows them", label, view, over[i] > allowed, "{what} {over[i]} px over the body, {allowed} allowed")
        note("legs and head not hidden where the model shows them", label, view, under[i] > allowed, "{what} {under[i]} px hidden, {allowed} allowed")
    // B5: each weight-bearing leg's lowest pixel on its foot's ground point; a near foot in sight.
    let walker = if has(r, "mount"): "mount" else: "main"
    if rg != walker or v.flying: return
    let cam = camera(k)
    let rp = RigPose {}
    rp.body_pose = v.body_pose
    let a3 = rig_unit(r, rp)
    let lows = new_imap()
    var n = 0
    for(v.legs) leg:
        if not leg.cling and has_node(leg_nodes, leg.node):
            let i = n
            n++
            var piece:Piece? = nil
            for(a3.pieces) p:
                if p.kind == "leg" and p.rig == a3.walker and p.anchor == i: piece = p
            if piece:
                let vs = vertices(piece.node, piece.xf)
                var lo = 1000000.0
                for(vs) q: lo = min(lo, q.y)
                var want = -1000000.0
                var sole = float2_0   // (the foot's ground point on screen)
                for(vs) q:
                    if q.y <= lo + 0.3 and project(q, cam).y > want:
                        want = project(q, cam).y
                        sole = project(q, cam)
                let got = lowest_y(cells_in_rig(leg.node))
                iset(lows, i, int(got))
                let sz = float(drawn_size(v)) / 100.0   // (the legs' own grid: baked at the unit's size, D-180)
                let foot = int(round(float(FOOT_PX) * sz))   // (its tolerance the same size on screen)
                let want_px = want * BAKE_ART * sz
                // (near: on the flank that faces the camera and on the camera's side of the middle)
                let flat = float3 { cam[2].x, 0.0, cam[2].z }
                let near = piece.hip.z * flat.z > 0.0 and dot(piece.joint, flat) > 0.0
                // (in sight: the 3D truth shows this leg's own pixels at its foot)
                var shown = 0
                let at_ = int2 { int(round(sole.x * BAKE_ART * sz)), int(round(sole.y * BAKE_ART * sz)) }
                if i < gt.feet.length:
                    for(2 * foot + 1) dx:
                        for(2 * foot + 2) dy:
                            if vhas(gt.feet[i], ckey(at_.x + dx - foot, at_.y + dy - foot - 1)): shown++
                let seen = shown > 0
                if near: note("B5 a near foot in sight", label, view, not seen, "{rg} {leg.node.part_id} foot hidden by its own body in 3D")
                // (a far leg's one-pixel sliver at the body's edge is where this CPU truth and Godot's GPU one round apart)
                if near or shown > 1:
                    note("B5 standing feet on the ground", label, view, abs(got - want_px) > float(foot),
                         "{rg} {leg.node.part_id} lowest pixel {int(got)}, its ground point {int(round(want_px))}")
    stand.set(rg, lows)

def has_int(xs:[int], v:int) -> bool: return exists(xs) x: x == v
def has_node(xs:[VNode], n:VNode) -> bool: return exists(xs) x: x == n

// A hopper's feet on the ground at this point of its hop (crouching or landed).
def hop_grounded(v:UV) -> bool:
    let f = v.phase / (2.0 * MPI)
    let p = f - floor(f)
    return hop_f(v, p) <= 0.0 or hop_f(v, p) >= 1.0

// B5 walking: the lowest foot stays on the standing ground line, and no foot goes below it.
def check_walk2(v:UV, parts:[P2], rg:string, label:string, view:string, lows:IMap):
    if v.flying or (v.gait.hops and not hop_grounded(v)) or not lows.keys.length: return
    var ref = -1000000.0
    for(lows.keys) i: ref = max(ref, float(iget(lows, i, 0)))
    let leg_nodes = map(find2(parts, rg, "leg")) i: parts[i].node
    var low = -1000000.0
    for(v.legs) leg:
        if not leg.cling and has_node(leg_nodes, leg.node): low = max(low, lowest_y(cells_now(leg.node, v)))
    note("B5 walking, the lowest foot on the ground line", label, view, abs(low - ref) > float(FOOT_PX), "lowest foot at {int(low)}, ground line {int(ref)}")

// A part's opaque cells in its rig's space with the walk's bob: its own transform and the bob's.
def cells_now(n:VNode, v:UV) -> IMap:
    let cells = new_imap()
    let key = draw_key(n)
    let b = bakes.get(key)
    let p = n.parent
    if b and p:
        let t = xf_mul(xf_mul([1.0, 0.0, 0.0, 1.0, v.bob.pos.x, v.bob.pos.y], xf_local(p)), xf_local(n))
        for(pixels_of(key).pts) q:
            let w = xf_apply(t, q)
            iset(cells, ckey(int(floor(w.x * b.scale)), int(floor(w.y * b.scale))), 1)
    return cells

// The transform from a part's parent's space to the unit's (as the part's pixels are laid out).
def to_unit(n:VNode, v:UV) -> [float]:
    var t = XF_ID2
    var p = n.parent
    while p and p != v.node:
        t = xf_mul(xf_local(p), t)
        p = p.parent
    return t

// B6: a rider's leg hangs down the flank that faces the camera, and reaches down it.
def check_rider_leg(v:UV, parts:[P2], mount_body:int, label:string, view:string, k:int, r:JV):
    if gbool(at(r, "mount"), "fused", false): return
    let cam = camera(k)
    let flat = float3 { cam[2].x, 0.0, cam[2].z }
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), check_team)
    let rp = at(r, "parts")
    let held = if has(rp, "hand_r"): hold_for(ptags_of(rstr(rp, "hand_r"))) else: "low"
    let spec = rig_spec(rstr(r, "body") + (if held == "low": "" else: "@" + held), colours)
    if not spec: return
    let two_legged = spec.anchors.length == 2   // (many-legged riders grip with several short legs)
    for(v.legs) leg:
        if leg.cling and spec.anchors.length:
            var hip = spec.anchors[0].pos
            for(spec.anchors) a:
                if magnitude(project(a.pos, cam) - leg.node.pos) < magnitude(project(hip, cam) - leg.node.pos): hip = a.pos
            note("B6 a rider\'s leg on the flank facing the camera", label, view, hip.z * flat.z < 0.0,
                 "the " + (if hip.z > 0.0: "right" else: "left") + " leg (hip z {f1(hip.z)}) shown with the camera on the " + (if flat.z > 0.0: "right" else: "left") + " side")
            // (it reaches down from the seat to the mount's girth, the bottom of the barrel under the seat)
            var leg_cells = new_imap()
            for(parts) p:
                if p.node == leg.node: leg_cells = p.cells
            let foot = lowest_y(leg_cells)
            let mrig = rig(parts[mount_body].id + facing_suffix(k))
            let ms = gobj(mrig, "sockets")
            if two_legged and has(ms, "girth"):
                let t = to_unit(parts[mount_body].node, v)
                let seat_y = xf_apply(t, v2(at(ms, "seat"))).y * BAKE_ART
                let girth_y = xf_apply(t, v2(at(ms, "girth"))).y * BAKE_ART
                let reach = (foot - seat_y) / max(girth_y - seat_y, 1.0)
                let want = if leg.reach > 1.0: RIDER_REACH else: CLING_REACH
                note("B6 a rider\'s leg reaches down the flank", label, view, reach < want, "{f2(reach)} of the way from the seat to the girth, {f2(want)} wanted")

// Siege crews by socket: "_in" behind the engine, "_top" over it, the rest by the socket's depth.
def check_crew(v:UV, label:string, view:string):
    if not v.body_nodes.length: return
    var engine = v.body_nodes[0]   // (the engine's sprite, or a war beast's rig)
    while engine.parent and engine.parent != v.bob:
        let up = engine.parent
        if up: engine = up
    let rg = rig(rstr(v.recipe, "body") + facing_suffix(v.facing_k))
    let socks = gobj(rg, "sockets")
    let depth = gobj(rg, "depth")
    let front = gobj(rg, "front")
    def index_in(n:VNode) -> int:
        for(v.bob.kids) c, i:
            if c == n: return i
        return -1
    for(v.crew) c:
        var name = ""
        for(socks.keys) s, n:
            if (starts_with(s, "crew") or starts_with(s, "haul")) and magnitude(v2(socks.a[n]) - c.node.pos) < 0.01: name = s
        let over = index_in(c.node) > index_in(engine)
        var want = if has(front, name): as_bool(at(front, name)) else: jf(depth, name, 0.0) > 0.0
        if ends_with(name, "_in"): want = false
        elif ends_with(name, "_top") or ends_with(name, "_box"): want = true
        note("siege crew by socket", label, view, over != want, name)
