// ------------------------------------------------------------------ a modelled part baked into the pack (scenes/art_pixel/part_baker.gd _bake_model)
// A part's model (model/) in all eight facings, as the Godot part baker makes them: each facing's sprite and,
// for a body with a near arm, that layer as its own sprite ("#front"); a leg or head cut by its body
// ("leg.newt~body.newt^2") or armour worn on it ("armour.bark~body.rat") baked with that body there and cut
// away; and the facing's rig: the sockets on screen (part units from the origin), how deep each is, the hips,
// which way the model faces, its scales, the weapon's tip. What the composer (view/unit_view.lobster) reads.

// ---- unit_models.gd's fitting helpers

// How a leg model sits at its hip (anchor [hip, phase, side, flip, hind, fan]): a far-side leg mirrored across
// the body, a flipped rear leg mirrored fore and aft, turned out by its fan.
def leg_basis(a:Anchor, cut:bool) -> Basis:
    let flip = a.more.length > 0 and int(a.more[0]) == 1
    if not cut: return if flip: bscaled(BASIS_ID, float3 { -1.0, 1.0, 1.0 }) else: BASIS_ID
    let side = if a.pos.z < 0.0: -1.0 else: 1.0
    let fan = if a.more.length > 2: axis_angle(float3 { 0.0, 1.0, 0.0 }, a.more[2] * -side) else: BASIS_ID
    return bmul(fan, bscaled(BASIS_ID, float3 { if flip: -1.0 else: 1.0, 1.0, side }))

// Armour modelled for this body (assets/models/armour_<kind>_<creature>.glb), or nil to fit the generic one.
def fitted(armour_id:string, body_id:string, c:Colours) -> Spec?:
    if starts_with(armour_id, "harness."): return harness_fitted(armour_id, body_id, c)   // a draught harness, on its beast (model/siege.lobster)
    let kind = armour_id.substring(7, armour_id.length - 7)
    let name = "armour_{kind}_{body_id.substring(5, body_id.length - 5)}"
    if not read_file(models_dir + "/" + name + ".glb", true): return nil
    let main = if kind != "leather": surf(kind, float3_1, 4.0) else: surf("leather", float3_1, 5.0)
    return spec_of(glb(name, mats_of([main, surf("leather", html("#5a3a20"), 3.0)], [kind, "trim"])))

// ---- JSON for the rigs

def jnum(f:float) -> JV:
    let o = JV { J_FLOAT }
    o.f = f
    return o
def jv2(v:float2) -> JV: return jarr([jnum(v.x), jnum(v.y)])

// ---- the bake

let BAKE_FACINGS = 8
var baked_here = 0                   // facings baked in this game (bake_missing_parts counts them)

// A sprite's opaque box and 2 px round it (part_baker.gd's crop: used.grow(SS * 2)): the sprite cropped to it,
// the origin moved with it.
def crop_sprite(sprite:string, w:int, h:int, origin:float2) -> string, int, int, float2:
    var x0 = w
    var y0 = h
    var x1 = -1
    var y1 = -1
    for(h) y:
        for(w) x:
            if sprite[(y * w + x) * 4 + 3] != 0:
                x0 = min(x0, x)
                y0 = min(y0, y)
                x1 = max(x1, x)
                y1 = max(y1, y)
    if x1 < 0: return "", 0, 0, origin
    x0 = max(0, x0 - 2)
    y0 = max(0, y0 - 2)
    x1 = min(w - 1, x1 + 2)
    y1 = min(h - 1, y1 + 2)
    let cw = x1 - x0 + 1
    let ch = y1 - y0 + 1
    let out = ensure_size("", cw * ch * 4, 0)
    for(ch) y:
        for(cw * 4) i: write_int8_le(out, y * cw * 4 + i, sprite[((y + y0) * w + x0) * 4 + i])
    return out, cw, ch, origin - float2 { float(x0), float(y0) }

// One sprite into the pack: its own sheet, a frame, its bake (origin and scale for the composer).
def keep_sprite(full:string, sprite:string, w:int, h:int, origin:float2):
    if w == 0: return
    let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                            float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
    sheet_tex.push(gl.create_texture(rows, texture_format_clamp | texture_format_nomipmap))
    sheet_dims.push(float2 { float(w), float(h) })
    frame_at.set("p:" + full, frames.length)
    frames.push(Frame { sheet_tex.length - 1, 0, 0, w, h, int(origin.x + 0.5), int(origin.y + 0.5) })
    bakes.set(full, Bake { origin.x, origin.y, BAKE_ART })

// A leg's soles (each column's lowest opaque pixel) and span (its top and bottom rows' middles), part units.
def keep_soles(full:string, sprite:string, w:int, h:int, origin:float2):
    let soles = []::float2
    for(w) x:
        var y = h - 1
        while y >= 0:
            if sprite[(y * w + x) * 4 + 3] > 127:
                soles.push((float2 { float(x) + 0.5, float(y) + 1.0 } - origin) / BAKE_ART)
                break
            y--
    bake_soles.set(full, soles)
    let rows = []::float2
    for(h) y:
        var xs = 0.0
        var count = 0
        for(w) x:
            if sprite[(y * w + x) * 4 + 3] > 127:
                xs += float(x) + 0.5
                count++
        if count > 0: rows.push((float2 { xs / float(count), float(y) + 0.5 } - origin) / BAKE_ART)
    if rows.length: bake_spans.set(full, [rows[0], rows[rows.length - 1]])

// Where the drawn part reaches furthest from its grip (sprite px from the origin): a weapon's tip.
def sprite_tip(sprite:string, w:int, h:int, origin:float2) -> float2:
    var tip = float2_0
    for(h) y:
        for(w) x:
            if sprite[(y * w + x) * 4 + 3] > 229:
                let d = float2 { float(x), float(y) } - origin
                if magnitude(d) > magnitude(tip): tip = d
    return tip

// A facing's camera (Godot's ortho bake camera at 35 + 45k degrees round, 30 up): right, up, towards it.
def bake_camera(k:int) -> float3, float3, float3:
    let az = 35.0 + 45.0 * float(k)
    let el = 30.0
    let view = float3 { sin(az) * cos(el), sin(el), cos(az) * cos(el) }
    let cx, cy, _cz = looking_at(-view, float3 { 0.0, 1.0, 0.0 })
    return cx, cy, view

// A facing's rig (part_baker.gd _rig).
def bake_rig(s:Spec, k:int) -> JV:
    let cx, cy, view = bake_camera(k)
    def to2d(p:float3) -> float2: return float2 { dot(p, cx), -dot(p, cy) }
    let flat = normalize(float3 { view.x, 0.0, view.z })
    let r = jobj()
    let socks = jobj()
    let depth = jobj()
    for(sorted_strs(s.sockets.get_keys())) name:
        let p = s.sockets.get(name, float3_0)
        set(socks, name, jv2(to2d(p)))
        set(depth, name, jnum(dot(p, flat)))
    set(r, "sockets", socks)
    set(r, "depth", depth)
    set(r, "dir", jv2(normalize(to2d(float3 { 20.0, 0.0, 0.0 }))))
    if s.anchors.length:
        let hips = []::JV
        for(s.anchors) a:
            let v = to2d(a.pos)
            let side = if k == 0: a.side elif dot(a.pos, flat) > 0.0: 1 else: -1
            hips.push(jarr([jnum(v.x), jnum(v.y), jnum(a.phase), jint(side), jint(if a.more.length > 0: int(a.more[0]) else: 0),
                            jbool(a.more.length > 1 and a.more[1] > 0.5), jbool(a.pos.z * flat.z > 0.0)]))
        set(r, "anchors", jarr(hips))
    let none = float3 { -1000000000.0, 0.0, 0.0 }
    let ts = s.nums.get("torso_scale", none)
    if ts.x != none.x: set(r, "torso_scale", jv2(float2 { ts.x, ts.y }))
    let gs = s.nums.get("gear_scale", none)
    if gs.x != none.x: set(r, "gear_scale", jnum(gs.x))
    let carry = s.strs.get("carry")
    if carry: set(r, "carry", jstr(carry))
    if find_s(s.flags, "legs_under") >= 0: set(r, "legs_under", jbool(true))
    return r

def find_s(xs:[string], x:string) -> int:
    for(xs) v, i:
        if v == x: return i
    return -1

// Every facing of one part: its sprites, front layers, rigs, a leg's soles. `full` is its bake key (without the
// facing). Returns false when there is no model for it.
def bake_model_part(id:string, full:string, c:Colours) -> bool:
    let built = build_model(id, c)
    if not built: return false
    let s = built
    var hide = []::BakeTri
    var model = s.node
    var pivot = float3_0
    var join = float3_0              // a seam: where a neck runs into its head, and how far round it reaches
    var join_r = 0.0
    let tilde = find_string(id, "~")
    let after = if tilde >= 0: id.substring(tilde + 1, id.length - tilde - 1) else: ""
    let caret = find_string(after, "^")
    if caret >= 0:
        // a leg or head cut by its body, put on where the body wears it, the body hiding what it hides
        let body_id = after.substring(0, caret)
        let at = after.substring(caret + 1, after.length - caret - 1)
        let body = build_model(body_id, c)
        if not body: return false
        let b = body
        hide = model_tris(b.node)
        let wrap = mnode()
        add_child(wrap, model)
        if at == "head":
            pivot = b.sockets.get("head", float3_0)
            if b.strs.get("seam_head"):   // a head its neck runs into: no outline where the body hides it
                join = b.sockets.get("join", float3_0)
                join_r = b.nums.get("seam_r", float3_0).x
        else:
            let a = b.anchors[string_to_int(at)]
            pivot = a.pos
            set_basis(wrap, leg_basis(a, true))
        wrap.pos = pivot
        model = wrap
    elif after != "":
        // body armour worn on its wearer: fitted to it (its own model for this body, or the generic one put on
        // at the torso, scaled and tilted to it); the body hides what it hides
        let body = build_model(after, c)
        if not body: return false
        let b = body
        hide = model_tris(b.node)
        let f = fitted(id.substring(0, tilde), after, c)
        if f:
            model = f.node
        else:
            let ts = b.nums.get("torso_scale", float3 { 1.0, 1.0, 0.0 })
            let wrap = mnode()
            add_child(wrap, model)
            wrap.pos = b.sockets.get("torso", float3_0)
            wrap.scl = b.nums.get("torso_fit", float3 { ts.x, ts.y, ts.x })
            wrap.rot = float3 { 0.0, 0.0, b.nums.get("torso_tilt", float3_0).x }
            model = wrap
        s.sockets = dictionary<string, float3>(3)
    let seam_head = s.strs.get("seam_head")
    if seam_head and tilde < 0:
        // a body whose neck runs into its head: the head in place hides it, and they join without a line
        let head = build_model(seam_head, c)
        if head:
            let wrap = mnode()
            add_child(wrap, head.node)
            wrap.pos = s.sockets.get("head", float3_0)
            hide = model_tris(wrap)
            join = s.sockets.get("join", float3_0)
            join_r = s.nums.get("seam_r", float3_0).x
    let tris = model_tris(model)
    let front = s.front
    let ftris = if front: model_tris(front) else: []::BakeTri
    // the girth: the bottom of the barrel under the seat, where a rider's leg reaches down to
    let none = float3 { 0.0, -1000000000.0, 0.0 }
    let seat = s.sockets.get("seat", none)
    if seat.y != none.y and s.sockets.get("girth", none).y == none.y:
        var low = seat.y
        let boxes = []::[float3]
        mesh_boxes(s.node, XF_ID, boxes)
        for(boxes) b:
            if b[0].x <= seat.x and b[1].x >= seat.x and b[0].z <= 0.0 and b[1].z >= 0.0: low = min(low, b[0].y)
        s.sockets.set("girth", float3 { seat.x, low, 0.0 })
    for(BAKE_FACINGS) k:
        let suffix = facing_suffix(k)
        let sprite0, w0, h0, origin0 = bake_facing(tris, k, hide, join, join_r)
        // the origin is the pivot (a cut part's hip or neck) on the sprite
        let cx, cy, _view = bake_camera(k)
        let o0 = origin0 + float2 { dot(pivot, cx), -dot(pivot, cy) } * BAKE_ART
        let sprite, w, h, origin = crop_sprite(sprite0, w0, h0, o0)
        keep_sprite(full + suffix, sprite, w, h, origin)
        if starts_with(id, "leg."): keep_soles(full + suffix, sprite, w, h, origin)
        let rig_id = id + suffix
        let r = if s.sockets.get_keys().length: bake_rig(s, k) else: jobj()   // (a leg, worn armour: no rig but the tip)
        if ftris.length:
            let fs0, fw0, fh0, fo0 = bake_facing(ftris, k)
            let fs, fw, fh, fo = crop_sprite(fs0, fw0, fh0, fo0)
            keep_sprite(full + suffix + "#front", fs, fw, fh, fo)
            set(r, "front", jbool(true))
        set(r, "tip", jv2(sprite_tip(sprite, w, h, origin) / BAKE_ART))
        set(rigs, rig_id, r)
        baked_here++
    return true
