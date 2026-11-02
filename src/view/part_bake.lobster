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
    if old_bugs.legs_unmirrored: return BASIS_ID
    if not cut: return if flip: bscaled(BASIS_ID, float3 { -1.0, 1.0, 1.0 }) else: BASIS_ID
    let side = if a.pos.z < 0.0: -1.0 else: 1.0
    let fan = if a.more.length > 2: axis_angle(float3 { 0.0, 1.0, 0.0 }, a.more[2] * -side) else: BASIS_ID
    return bmul(fan, bscaled(BASIS_ID, float3 { if flip: -1.0 else: 1.0, 1.0, side }))

// Armour modelled for this body (assets/models/armour_<kind>_<creature>.glb; the heroic human's armour_<kind>_human_heroic),
// or nil to fit the generic one.
// The materials a fitted armour's .glb names (tools/blender/human_armour.py, creature_armour.py): [texture, tint, size];
// no texture: plain.
let ARMOUR_MAT_NAMES = [ "leather", "trim", "bronze", "iron", "tin", "brass", "mail", "bark", "label" ]
let ARMOUR_MAT_TEX = [ "leather", "leather", "bronze", "iron", "iron", "bronze", "mail", "bark_plate", "" ]
let ARMOUR_MAT_TINT = [ "#ffffff", "#5a3a20", "#ffffff", "#ffffff", "#f2f6ff", "#fff0c8", "#ffffff", "#ffffff", "#c8a040" ]
let ARMOUR_MAT_SIZE = [ 5.0, 3.0, 4.0, 3.0, 2.0, 1.2, 2.5, 6.0, 0.0 ]

def fitted(armour_id:string, body_id:string, c:Colours) -> Spec?:
    if starts_with(armour_id, "harness."): return harness_fitted(armour_id, body_id, c)  // a draught harness, on its beast (model/siege.lobster)
    let kind = armour_id.substring(7, armour_id.length - 7)
    let name = "armour_{kind}_{body_id.substring(5, body_id.length - 5)}" + (if body_id == "body.human": HUMAN_LOOK else: "")
    if not read_file(models_dir + "/" + name + ".glb", true): return nil
    let mats = map(ARMOUR_MAT_NAMES.length) i:
        if ARMOUR_MAT_TEX[i] != "": surf(ARMOUR_MAT_TEX[i], html(ARMOUR_MAT_TINT[i]), ARMOUR_MAT_SIZE[i]) else: plain(html(ARMOUR_MAT_TINT[i]))
    return spec_of(glb(name, mats_of(mats, ARMOUR_MAT_NAMES)))

// The art px a part unit this bake is at: the art scale at the part's size (D-180: bake_art_k, its unit's draw size / 100).
def bake_art() -> float: return BAKE_ART * bake_art_k

// ---- JSON for the rigs

def jnum(f:float) -> JV:
    let o = JV { J_FLOAT }
    o.f = f
    return o
def jv2(v:float2) -> JV: return jarr([ jnum(v.x), jnum(v.y) ])

// ---- the bake

let BAKE_FACINGS = 8
var baked_here = 0  // facings baked in this game (bake_missing_parts counts them)

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

// ---- the bake cache: a part baked once is kept on disk (bake_cache/: a PNG a sprite, and a manifest of its
// sprites, soles, spans and rigs), so a later start loads it instead (a cut leg bakes with its whole body: a
// beast's legs in every walk step took most of a minute). BAKE_VERSION goes up when the models or the baker
// change, so old bakes aren't reused.

let BAKE_VERSION = 10              // (2: Godot's full PI in the models; 3: engines' members in front or behind; 4: whole-pixel frames as Godot's, 2026-10-27; 7: Godot's bicubic shrink in pixelize, in Godot's square frame; 8: the art at 2x (D-173), 2026-10-28; 9: the bears' neck leans with them, 2026-10-31; 10: the bears lofted (D-189))
var bake_cache_dir = "bake_cache"  // (play.sh makes it; Lobster can't make a folder)
var bake_shipped_dir = "baked"     // the buildings and props a build ships, baked by prebake.sh (read before bake_cache/)
var cache_lines = []::string       // the manifest of the part being baked
var cache_stem = ""                // its file names' stem ("" while not recording)
var bake_job_done = false          // bake_job made no job: true when the part was in the cache, false with no model

class BakeOpts:
    sprite_formats = texture_format_clamp | texture_format_nomipmap  // (the sheet tool draws them nearest: crisp close-ups)

let bake_opts = BakeOpts {}

def cache_stem_of(id:string, full:string) -> string:
    return bake_cache_dir + "/" + sha256_text("{BAKE_VERSION}|{id}|{full}").substring(0, 20)

def sprite_texture(name:string, sprite:string, w:int, h:int) -> resource<texture>:
    let rows = map(h) y: map(w) x: float4 { float(sprite[(y * w + x) * 4]) / 255.0, float(sprite[(y * w + x) * 4 + 1]) / 255.0,
                                            float(sprite[(y * w + x) * 4 + 2]) / 255.0, float(sprite[(y * w + x) * 4 + 3]) / 255.0 }
    if cache_stem != "":  // (kept for the next start)
        let file = "{cache_stem}_{cache_lines.length}.png"
        write_file(file, bmat_png(map(sprite.length) i: sprite[i], w, h))
        cache_lines.push("sprite {name} {file} {w} {h}")
    return gl.create_texture(rows, bake_opts.sprite_formats)

def add_frame(full:string, tex:resource<texture>, w:int, h:int, origin:float2):
    add_sheet(tex, float2 { float(w), float(h) })
    add_part_frame(full, w, h, origin)

def add_part_frame(full:string, w:int, h:int, origin:float2):
    frame_at.set("p:" + full, frames.length)
    frames.push(Frame { sheet_tex.length - 1, 0, 0, w, h, int(origin.x + 0.5), int(origin.y + 0.5), 1.0 })
    bakes.set(full, Bake { origin.x, origin.y, bake_art() })

// One sprite into the pack: its own sheet, a frame, its bake (origin and scale for the composer).
def keep_sprite(full:string, sprite:string, w:int, h:int, origin:float2):
    if w == 0:  // (nothing of it shows from here, a cut leg behind its body: baked all the same, as Godot keeps it, drawn as nothing)
        bakes.set(full, Bake { origin.x, origin.y, bake_art() })
        if cache_stem != "": cache_lines.push("empty {full} {origin.x} {origin.y}")
        return
    let tex = sprite_texture(full, sprite, w, h)
    if cache_stem != "": cache_lines[cache_lines.length - 1] += " {origin.x} {origin.y}"
    add_frame(full, tex, w, h, origin)

// A part's bakes from the cache, if they're there (true: nothing to bake).
def load_cached(id:string, full:string) -> bool:
    let text = read_file(cache_stem_of(id, full) + ".txt")
    if not text: return false
    for(tokenize(text, "\n", "")) line:
        let t = tokenize(line, " ", "")
        if t.length:
            switch t[0]:
                case "sprite":  // (its PNG loaded when it's first drawn)
                    add_sheet_later(t[2], float2 { string_to_float(t[3]), string_to_float(t[4]) }, bake_opts.sprite_formats)
                    add_part_frame(t[1], string_to_int(t[3]), string_to_int(t[4]), float2 { string_to_float(t[5]), string_to_float(t[6]) })
                case "empty": bakes.set(t[1], Bake { string_to_float(t[2]), string_to_float(t[3]), bake_art() })
                case "soles": bake_soles.set(t[1], map((t.length - 2) / 2) n: float2 { string_to_float(t[2 + n * 2]), string_to_float(t[3 + n * 2]) })
                case "span": bake_spans.set(t[1], [ float2 { string_to_float(t[2]), string_to_float(t[3]) }, float2 { string_to_float(t[4]), string_to_float(t[5]) } ])
                case "rig": set(rigs, t[1], parse_json(line.substring(5 + t[1].length, line.length - 5 - t[1].length)))
                default: pass()
    return true

// A leg's soles (each column's lowest opaque pixel) and span (its top and bottom rows' middles), part units.
def keep_soles(full:string, sprite:string, w:int, h:int, origin:float2):
    let soles = []::float2
    for(w) x:
        var y = h - 1
        while y >= 0:
            if sprite[(y * w + x) * 4 + 3] > 127:
                soles.push((float2 { float(x) + 0.5, float(y) + 1.0 } - origin) / bake_art())
                break
            y--
    bake_soles.set(full, soles)
    if cache_stem != "": cache_lines.push("soles {full} " + concat_string(map(soles) p: "{p.x} {p.y}", " "))
    let rows = []::float2
    for(h) y:
        var xs = 0.0
        var count = 0
        for(w) x:
            if sprite[(y * w + x) * 4 + 3] > 127:
                xs += float(x) + 0.5
                count++
        if count > 0: rows.push((float2 { xs / float(count), float(y) + 0.5 } - origin) / bake_art())
    if rows.length:
        bake_spans.set(full, [ rows[0], rows[rows.length - 1] ])
        if cache_stem != "": cache_lines.push("span {full} {rows[0].x} {rows[0].y} {rows[rows.length - 1].x} {rows[rows.length - 1].y}")

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

// An engine's members beside it (crew, haulers; not those inside its frame or riding on top) are drawn over it or
// under it by which is in front where they overlap on screen, not by the socket's depth alone (part_baker.gd
// _members_front, placement C4): for each, true when it stands in front of most of the engine it overlaps. The engine
// is sampled through its meshes' boxes on a 2-unit grid.
let MEMBER_COLUMN = [ 3.0, 8.0, 13.0, 18.0 ]  // a member standing on its socket: points up its middle...
let MEMBER_HALF = float2 { 4.0, 2.5 }         // ...each as wide and tall as this on screen (part units)

def member_samples(n:MNode, parent:Xform, right:float3, up:float3, view:float3, out:[float3]) -> void:
    let t = xmul(parent, node_xform(n))
    let mesh = n.mesh
    if n.visible and mesh and mesh.p.length:
        var lo = mesh.p[0]
        var hi = mesh.p[0]
        for(mesh.p) p:
            lo = min(lo, p)
            hi = max(hi, p)
        let size = hi - lo
        let c = max(int3 { int(ceiling(size.x / 2.0)), int(ceiling(size.y / 2.0)), int(ceiling(size.z / 2.0)) }, int3_1)
        for(c.x + 1) i:
            for(c.y + 1) j:
                for(c.z + 1) l:
                    let q = xf(t, lo + size * float3 { float(i) / float(c.x), float(j) / float(c.y), float(l) / float(c.z) })
                    out.push(float3 { dot(q, right), dot(q, up), dot(q, view) })
    for(n.kids) kid: member_samples(kid, t, right, up, view, out)

let MEMBER_AHEAD = [ float2 { 5.0, 10.0 }, float2 { 9.0, 12.0 } ]  // ...and ahead of it at chest height, [forward, up]: a body
// leaning into the work is mostly in front of its hips (C4)

// Two members' sample points close enough on screen that their bodies overlap.
def samples_meet(a:[float2], b:[float2]) -> bool:
    for(a) p:
        for(b) q:
            if abs(p.x - q.x) < MEMBER_HALF.x * 2.0 and abs(p.y - q.y) < MEMBER_HALF.y * 2.0: return true
    return false

def members_front(model:MNode, sockets:dictionary<string, float3>, names:[string], view:float3) -> JV:
    let right = normalize(cross(float3 { 0.0, 1.0, 0.0 }, view))
    let up = cross(view, right)
    let pts = []::float3
    member_samples(model, XF_ID, right, up, view, pts)
    let front = dictionary<string, int>(7)
    let cover = dictionary<string, int>(7)      // how much of the engine is in front of each member
    let seen = dictionary<string, [float2]>(7)  // each member's sample points on screen
    let apart = []::string                      // members the engine is neither in front of nor behind
    for(names) name:
        var nearer = 0
        var farther = 0
        let sock = sockets.get(name, float3_0)
        var turn = 0.0  // the member's facing on the engine ("crew2_f2_reach": two steps round from it)
        for(tokenize(name, "_", "")) t:
            if t.length == 2 and t[0] == 'f' and t[1] >= '0' and t[1] <= '9': turn = 45.0 * float(t[1] - '0')
        let fwd = float3 { cos(turn), 0.0, sin(turn) }
        let samples = map(MEMBER_COLUMN) h: float3 { 0.0, h, 0.0 }
        if find_string(name, "_reach") >= 0 or find_string(name, "_raise") >= 0:  // (leaning into the work; a rider sits upright)
            for(MEMBER_AHEAD) a: samples.push(fwd * a.x + float3 { 0.0, a.y, 0.0 })
        let mine = []::float2
        for(samples) o:
            let c = sock + o
            let sc = float2 { dot(c, right), dot(c, up) }
            mine.push(sc)
            let dc = dot(c, view)
            for(pts) q:
                if abs(q.x - sc.x) < MEMBER_HALF.x and abs(q.y - sc.y) < MEMBER_HALF.y:
                    if q.z > dc + 1.0: nearer++
                    elif q.z < dc - 1.0: farther++
        seen.set(name, mine)
        let is_front = if nearer + farther > 0: nearer <= farther else: dot(sock, float3 { view.x, 0.0, view.z }) > 0.0
        front.set(name, if is_front: 1 else: 0)
        cover.set(name, nearer)
        if nearer + farther == 0: apart.push(name)
    // A member nowhere in front of or behind the engine goes under it all the same when one nearer the camera than
    // it does (the great sling's file of haulers); the same for one drawn over the engine where a member nearer the
    // camera that's drawn under it covers it on screen; one nowhere against the engine goes over it with the member
    // it stands in front of (a siege tower's pusher); hunched bodies reaching into each other go both over or both
    // under, by which the engine hides less of (part_baker.gd _members_front).
    let order = copy(names)  // nearest the camera first, so it carries on down a file
    insertion_sort(order) a, b: dot(sockets.get(a, float3_0), view) > dot(sockets.get(b, float3_0), view)
    for(order) name:
        if front.get(name, 0) == 1:
            let sn = sockets.get(name, float3_0)
            let d = dot(sn, view)
            let sc = float2 { dot(sn, right), dot(sn, up) }
            for(names) other:
                let so3 = sockets.get(other, float3_0)
                let so = float2 { dot(so3, right), dot(so3, up) }
                let behind_under = front.get(other, 0) == 0 and dot(so3, view) > d
                let close = abs(so.x - sc.x) < MEMBER_HALF.x * 2.0 and abs(so.y - sc.y) < MEMBER_COLUMN[MEMBER_COLUMN.length - 1]
                if behind_under and has_s(apart, other) and not has_s(apart, name) and close:
                    front.set(other, 1)
                elif behind_under and (has_s(apart, name) or close):
                    front.set(name, 0)
                elif behind_under and samples_meet(seen.get(name, []::float2), seen.get(other, []::float2)):
                    if cover.get(other, 0) < cover.get(name, 0): front.set(other, 1)
                    else: front.set(name, 0)
    let out = jobj()
    for(names) name: set(out, name, jbool(front.get(name, 0) == 1))
    return out

// A facing's rig (part_baker.gd _rig).
def bake_rig(s:Spec, k:int) -> JV:
    let cx, cy, view = bake_camera(k)
    def to2d(p:float3) -> float2: return float2 { dot(p, cx), -dot(p, cy) } * bake_fit
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
    let members = filter(sorted_strs(s.sockets.get_keys())) n: (starts_with(n, "crew") or starts_with(n, "haul")) and not ends_with(n, "_in") and not ends_with(n, "_top")
    if members.length: set(r, "front", members_front(s.node, s.sockets, members, view))
    set(r, "dir", jv2(normalize(to2d(float3 { 20.0, 0.0, 0.0 }))))
    set(r, "ahead", jv2(to2d(float3 { 1.0, 0.0, 0.0 })))  // one unit forward on screen (part units): a crew member standing back from its place
    if s.anchors.length:
        let hips = []::JV
        for(s.anchors) a:
            let v = to2d(a.pos)
            let side = if k == 0: a.side elif dot(a.pos, flat) > 0.0: 1 else: -1
            hips.push(jarr([ jnum(v.x), jnum(v.y), jnum(a.phase), jint(side), jint(if a.more.length > 0: int(a.more[0]) else: 0),
                             jbool(a.more.length > 1 and a.more[1] > 0.5), jbool(a.pos.z * flat.z > 0.0) ]))
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
// While the art bakes (a first start with no cache: minutes), the window stays alive: a few times a second a frame
// says how far it is, and the window's events are read, so closing it (or Ctrl-C, which SDL makes a quit) stops the
// baking (bake_quit; the game then quits). The game turns it on; checks bake without it.
var bake_live = false
var bake_quit = false
var bake_done = 0  // things baked since the game began
// The progress drawn by the game's match loader while it's up (game.lobster sets it to fe_loader, game/lobby.lobster):
// its bar runs from bake_progress_from to bake_progress_to over this bake.
def bake_progress_fn(status:string, frac:float) -> void
var bake_progress:bake_progress_fn = fn(s, f): pass()
var bake_progress_on = false
var bake_progress_from = 0.0
var bake_progress_to = 1.0
var bake_what = ""  // what's baking (the game says: "the armies", "the town")
var bake_total = 0  // how many things this bake has to make (0: not counted), and how many it has
var bake_count = 0
var bake_said = 0.0

def bake_breath():
    bake_done++
    if not bake_live or bake_quit or seconds_elapsed() - bake_said < 0.25: return
    bake_said = seconds_elapsed()
    gl.switch_to_framebuffer(nil)
    gl.ortho()
    gl.clear(float4 { 0.07, 0.06, 0.05, 1.0 })
    gl.set_shader("color")
    let ws = float(gl.window_size())
    if bake_progress_on:  // the game's match loader, its bar this bake's share
        let done = if bake_total > 0: float(bake_count) / float(bake_total) else: 0.0
        bake_progress("Making {bake_what}", bake_progress_from + (bake_progress_to - bake_progress_from) * done)
        if not gl.frame(): bake_quit = true
        return
    gl.set_font_size(int(max(16.0, ws.y / 36.0)))
    gl.color(float4 { 0.92, 0.86, 0.7, 1.0 }):
        gl.translate(float2 { ws.x * 0.08, ws.y * 0.45 }):
            gl.text(if bake_total > 0: "Making {bake_what}: {bake_count} of {bake_total}" else: "Making {bake_what}: {bake_done} done")
    gl.color(float4 { 0.6, 0.56, 0.48, 1.0 }):
        gl.translate(float2 { ws.x * 0.08, ws.y * 0.45 + ws.y / 22.0 }):
            gl.text("The first start bakes every picture; later starts take them from bake_cache. Close the window to stop.")
    if not gl.frame(): bake_quit = true

// The unit's shadow (PartShape.bake_flat: UnitView.SHADOW_SHAPES, an ellipse in the buildings' shadow colour, at the
// size units are drawn): no model, a flat shape, baked here as Godot bakes it when it builds its atlas.
let SHADOW_CENTRE = float2 { 3.0, 1.0 }
let SHADOW_RADII = float2 { 15.0, 4.5 }
let SHADOW_RGBA = [ 15, 13, 8, 107 ]  // (Color(0.06, 0.05, 0.03, 0.42) in bytes)

def bake_flat_shadow(full:string):
    let r = SHADOW_RADII * bake_art()
    let w = int(ceiling(r.x * 2.0)) + 2
    let h = int(ceiling(r.y * 2.0)) + 2
    let sprite = ensure_size("", w * h * 4, 0)  // (the write_ functions write into it in place)
    for(h) y:
        for(w) x:
            let q = (float2 { float(x), float(y) } + float2_1 * 0.5 - float2_1 - r) / r
            if dot(q, q) <= 1.0:
                for(4) i: write_int8_le(sprite, (y * w + x) * 4 + i, SHADOW_RGBA[i])
    keep_sprite(full, sprite, w, h, float2_1 + r - SHADOW_CENTRE * bake_art())

// A part baked at a size (D-180): `size` percent of the art scale, its unit's recipe scale, so a unit drawn bigger
// or smaller keeps the art's own pixels; `full` is its bake key with the size in it ("%<size>", PartShape.bake_key).
// Its rigs, soles and spans stay in part units; its bakes' scale is the sized art scale.
def bake_model_part_at(id:string, full:string, c:Colours, size:int) -> bool:
    bake_art_k = float(size) / 100.0
    let ok = bake_model_part(id, full, c)
    bake_art_k = 1.0
    return ok

// The size a bake key asks for (its "%<size>": the percent of the art scale its unit is drawn at, D-180), or 100.
def key_size(full:string) -> int:
    let t = tokenize(full, "%", "")
    return if t.length > 1: string_to_int(t[t.length - 1]) else: 100

def bake_model_part(id:string, full:string, c:Colours) -> bool:
    if bake_quit: return false
    let sz = key_size(full)
    if sz != 100 and bake_art_k == 1.0: return bake_model_part_at(id, full, c, sz)  // (a sized key bakes at its size)
    if id == "unit_shadow":
        bake_flat_shadow(full)
        return true
    bake_breath()
    let j = bake_job(id, full, c)
    if not j: return bake_job_done
    while bake_job_step(j): pass()
    return true

def has_mesh(n:MNode) -> bool: return n.mesh != nil or exists(n.kids) k: has_mesh(k)

// A part's bake as a job: its model built and framed once, then one facing a step, so play can bake a part a facing
// a frame (game/bake_missing.lobster: the later ages' parts) without a stall. Its manifest goes to the cache when its
// last facing is done.
class BakeJob:
    id:string
    full:string
    s:Spec
    tris:[BakeTri]
    ftris:[BakeTri]
    hide:[BakeTri]
    join:float3
    join_r:float
    pivot:float3
    fit:float
    frame_r:float
    frame_c:float3
    art_k:float
    stem:string
    lines:[string]
    k:int  // the next facing

// The job for a part (nil: loaded from the cache, or nothing to bake: bake_job_done says which).
def bake_job(id:string, full:string, c:Colours) -> BakeJob?:
    bake_job_done = bake_cache_dir != "" and load_cached(id, full)
    if bake_job_done: return nil
    let built = build_model(id, c)
    if not built: return nil
    let s = built
    var hide = []::BakeTri
    var model = s.node
    var own = s.node         // the part's own model (Godot's `model`, measured in its own frame)
    var wearer:MNode? = nil  // the body that cuts or wears it
    var pivot = float3_0
    var join = float3_0  // a seam: where a neck runs into its head, and how far round it reaches
    var join_r = 0.0
    let tilde = find_string(id, "~")
    let after = if tilde >= 0: id.substring(tilde + 1, id.length - tilde - 1) else: ""
    let caret = find_string(after, "^")
    if caret >= 0:
        // a leg or head cut by its body, put on where the body wears it, the body hiding what it hides
        let body_id = after.substring(0, caret)
        let at = after.substring(caret + 1, after.length - caret - 1)
        let body = build_model(body_id, c)
        if not body: return nil
        let b = body
        hide = model_tris(b.node)
        wearer = b.node
        let wrap = mnode()
        add_child(wrap, model)
        if at == "head":
            pivot = b.sockets.get("head", float3_0)
            if b.strs.get("seam_head"):  // a head its neck runs into: no outline where the body hides it
                join = b.sockets.get("join", float3_0)
                join_r = b.nums.get("seam_r", float3_0).x
        else:
            let a = b.anchors[string_to_int(at)]
            pivot = a.pos
            set_basis(wrap, leg_basis(a, true))
            let seam_r = b.nums.get("seam_legs", float3_0).x
            if seam_r > 0.0:  // a leg growing out of its body: no outline where the body hides it, near the hip
                join = a.pos
                join_r = seam_r
        wrap.pos = pivot
        model = wrap
    elif after != "":
        // body armour worn on its wearer: fitted to it (its own model for this body, or the generic one put on
        // at the torso, scaled and tilted to it); the body hides what it hides
        let body = build_model(after, c)
        if not body: return nil
        let b = body
        hide = model_tris(b.node)
        wearer = b.node
        let f = fitted(id.substring(0, tilde), after, c)
        if f:
            model = f.node
            own = f.node
        else:
            let ts = b.nums.get("torso_scale", float3 { 1.0, 1.0, 0.0 })
            let wrap = mnode()
            add_child(wrap, model)
            wrap.pos = b.sockets.get("torso", float3_0)
            wrap.scl = b.nums.get("torso_fit", float3 { ts.x, ts.y, ts.x })
            wrap.rot = float3 { 0.0, 0.0, b.nums.get("torso_tilt", float3_0).x }
            model = wrap
        s.sockets = dictionary<string, float3>(3)
    if not has_mesh(model): return nil  // (a model with nothing in it, a harness off its wearer: nothing to bake)
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
    // Rendered as Godot's bake viewport is: a whole number of pixels across a square round the model, its wearer and its
    // near arm, so each part comes out a little larger than the art scale (by up to a pixel over its frame) and its rig
    // with it (part_baker.gd: size = ceil(2 r px), cam.size = 2 r).
    var blo = float3_1 * 1000000000.0
    var bhi = float3_1 * -1000000000.0
    let measured = [ own ]
    let wn = wearer
    if wn: measured.push(wn)
    if front: measured.push(front)
    for(measured) n:
        let lo, hi = local_box(n)
        blo = min(blo, lo)
        bhi = max(bhi, hi)
    let bpx = bake_art() * float(BAKE_SS)
    let br = if bhi.x >= blo.x: magnitude(bhi - blo) * 0.5 + 2.0 else: 2.0
    let fit = ceiling(2.0 * br * bpx) / (2.0 * br * bpx)
    return BakeJob { id, full, s, tris, ftris, hide, join, join_r, pivot, fit, br, (blo + bhi) * 0.5, bake_art_k,
                     if bake_cache_dir != "": cache_stem_of(id, full) else: "", [], 0 }

// A part's job at its key's size (nil: cached, a shadow made at once, or no model).
def bake_part_job(id:string, full:string, c:Colours) -> BakeJob?:
    let was = bake_art_k
    bake_art_k = float(key_size(full)) / 100.0
    var j:BakeJob? = nil
    if id == "unit_shadow": bake_flat_shadow(full)
    else: j = bake_job(id, full, c)
    bake_art_k = was
    return j

// One facing of a job (the baker's framing and the cache's manifest set from it, and put back after). True while
// facings are left.
def bake_job_step(j:BakeJob) -> bool:
    let was_k = bake_art_k
    bake_art_k = j.art_k
    bake_fit = j.fit
    bake_frame_r = j.frame_r
    bake_frame_c = j.frame_c
    cache_stem = j.stem
    cache_lines = j.lines
    let k = j.k
    let s = j.s
    let suffix = facing_suffix(k)
    let sprite0, w0, h0, origin0 = bake_facing(j.tris, k, j.hide, j.join, j.join_r)
    // the origin is the pivot (a cut part's hip or neck) on the sprite
    let cx, cy, _view = bake_camera(k)
    let o0 = origin0 + float2 { dot(j.pivot, cx), -dot(j.pivot, cy) } * bake_art() * bake_fit
    let sprite, w, h, origin = crop_sprite(sprite0, w0, h0, o0)
    keep_sprite(j.full + suffix, sprite, w, h, origin)
    if starts_with(j.id, "leg."): keep_soles(j.full + suffix, sprite, w, h, origin)
    let rig_id = j.id + suffix
    let r = if s.sockets.get_keys().length: bake_rig(s, k) else: jobj()  // (a leg, worn armour: no rig but the tip)
    if j.ftris.length:
        let fs0, fw0, fh0, fo0 = bake_facing(j.ftris, k)
        let fs, fw, fh, fo = crop_sprite(fs0, fw0, fh0, fo0)
        keep_sprite(j.full + suffix + "#front", fs, fw, fh, fo)
        set(r, "front", jbool(true))
    set(r, "tip", jv2(sprite_tip(sprite, w, h, origin) / bake_art()))
    set(rigs, rig_id, r)
    cache_lines.push("rig {rig_id} " + stringify(r))
    baked_here++
    j.k++
    if j.k == BAKE_FACINGS and j.stem != "": write_file(j.stem + ".txt", concat_string(j.lines, "\n") + "\n")
    cache_stem = ""
    cache_lines = []
    bake_fit = 1.0
    bake_frame_r = 0.0
    bake_art_k = was_k
    return j.k < BAKE_FACINGS

// A model's meshes' box in its own frame (its own transform left out, as part_baker.gd _aabb).
def local_box(n:MNode) -> float3, float3:
    let boxes = []::[float3]
    let mesh = n.mesh
    if mesh and mesh.p.length:
        var lo = mesh.p[0]
        var hi = mesh.p[0]
        for(mesh.p) p:
            lo = min(lo, p)
            hi = max(hi, p)
        boxes.push([ lo, hi ])
    for(n.kids) kid: mesh_boxes(kid, XF_ID, boxes)
    var lo = float3_1 * 1000000000.0
    var hi = float3_1 * -1000000000.0
    for(boxes) b:
        lo = min(lo, b[0])
        hi = max(hi, b[1])
    return lo, hi
