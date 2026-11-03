// Procedural voxel units, built from data (data/voxel/: materials, gear, bodies/<id>.json; docs/rendering.md,
// "Voxel units"): a body is named points on a skeleton, two-bone legs that walk, arms that hold, and shapes
// (capsules, balls, discs, boxes, chains, rings) on its points; gear is shapes in a hand's hold or fitted to a body.
// Filled into a voxel grid at a voxel a baked pixel and drawn in the game's 3/4 view in 8 facings: each surface voxel
// splatted with a depth test, banded light and self-shadows, fur flecked by a hash of the voxel, a dark outline, a
// ground shadow of its own. game/voxel_units.lobster bakes a match's units; voxel_proto.lobster draws a sheet.

let vx_ELEV = 30.0                                                      // the camera's elevation, degrees
let vx_RES = 2.0                                                        // voxels a body unit (a body unit is about a world pixel; a voxel a baked pixel)
let vx_CELL = int2 { int(52.0 * vx_RES), int(74.0 * vx_RES) }           // a sprite cell
let vx_ANCHOR = int2 { vx_CELL.x / 2, vx_CELL.y - int(14.0 * vx_RES) }  // the ground under the unit, in its cell
let vx_BLEND = 0.8                                                      // how far body parts melt into each other, body units (round 1's 2.2 made muscles)

class vx_prim:
    a:float3
    b:float3
    ra:float
    rb:float
    mat:int
    hard:bool   // gear and fine details: no melting into the body
    disc:bool   // a disc round a, facing along b - a, ra across and rb thick
    box:float3  // not zero: a box round a, these half sizes (across, thick, up), facing along b - a, edges rounded by ra

def vx_dist(p:float3, s:vx_prim) -> float:
    let ba = s.b - s.a
    if s.box.x > 0.0:
        let n = normalize(ba)
        let x = normalize(cross(n, float3 { 0.0, 0.0, 1.0 }))
        let z = cross(x, n)
        let q = p - s.a
        let d = abs(float3 { dot(q, x), dot(q, n), dot(q, z) }) - s.box
        return magnitude(max(d, float3_0)) + min(max(d.x, max(d.y, d.z)), 0.0) - s.ra
    if s.disc:
        let n = normalize(ba)
        let q = p - s.a
        let h = dot(q, n)
        let w = float2 { magnitude(q - n * h) - s.ra, abs(h) - s.rb }
        return magnitude(max(w, float2_0)) + min(max(w.x, w.y), 0.0)
    let l2 = dot(ba, ba)
    let h = if l2 > 0.0: clamp(dot(p - s.a, ba) / l2, 0.0, 1.0) else: 0.0
    return magnitude(p - s.a - ba * h) - (s.ra + (s.rb - s.ra) * h)

def vx_smin(a:float, b:float, k:float) -> float:
    let h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25

def vx_cap(a:float3, b:float3, ra:float, rb:float, m:int) -> vx_prim: return vx_prim { a, b, ra, rb, m, false, false, float3_0 }
def vx_hard(a:float3, b:float3, ra:float, rb:float, m:int) -> vx_prim: return vx_prim { a, b, ra, rb, m, true, false, float3_0 }
def vx_ball(c:float3, r:float, m:int) -> vx_prim: return vx_prim { c, c, r, r, m, false, false, float3_0 }
def vx_bead(c:float3, r:float, m:int) -> vx_prim: return vx_prim { c, c, r, r, m, true, false, float3_0 }
def vx_disc(c:float3, n:float3, r:float, thick:float, m:int) -> vx_prim: return vx_prim { c, c + n, r, thick, m, true, true, float3_0 }
def vx_box(c:float3, n:float3, half:float3, round:float, m:int) -> vx_prim: return vx_prim { c, c + n, round, round, m, true, false, half }

// Two bones from a towards t (lengths l1, l2), the joint bent towards pole: the joint and where the end lands.
def vx_ik(a:float3, t:float3, l1:float, l2:float, pole:float3) -> float3, float3:
    let d = t - a
    let n = normalize(d)
    let dist = min(magnitude(d), (l1 + l2) * 0.999)
    let x = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    let h = sqrt(max(l1 * l1 - x * x, 0.0))
    let side = normalize(pole - n * dot(pole, n))
    let joint = a + n * x + side * h
    return joint, joint + normalize(t - joint) * l2

// ---- the data: materials, shapes, bodies, gear (data/voxel/, read once by vx_load)

let vx_mat_names = []::string
let vx_MAT_BASE = []::float3
var vx_mat_cols = []::float3
let vx_MAT_FUR = []::int  // per material: flecked like fur
var vx_mat_team = 0       // the team colour's material (the sprite shader's key)
var vx_fur = 0.07         // how strongly fur is flecked (the body's)

def vx_mat(name:string) -> int:
    let m = find(vx_mat_names) n: n == name
    assert m >= 0
    return m

def vx_hex(h:string) -> float3:
    let s = if h.length and h[0] == '#': h.substring(1, h.length - 1) else: h
    def byte(i:int) -> float: return float(string_to_int(s.substring(i, 2), 16)) / 255.0
    return float3 { byte(0), byte(2), byte(4) }

enum vx_kind:
    vx_k_cap, vx_k_ball, vx_k_disc, vx_k_box, vx_k_chain, vx_k_ring, vx_k_helm, vx_k_fit

// A shape as data: on named points with offsets (in the body's frame, or a hold's for held gear).
class vx_spec:
    kind:int
    hard:bool
    mirror:bool
    pa:string
    a:float3
    pb:string
    b:float3
    ra:float
    rb:float
    mat:int
    mat2:int      // a chain's later links
    n:float3      // a disc's or box's facing
    half:float3   // a box's half sizes
    pts:[string]  // a chain's points
    offs:[float3]
    step:float  // a chain's radius: from ra by step a link, down to rb, each link tapering by taper
    taper:float
    need:[string]  // flags that must be there (if) and mustn't (unless)
    avoid:[string]

def vx_v3(v:JV) -> float3: return float3 { as_float(v.a[0]), as_float(v.a[1]), as_float(v.a[2]) }
def vx_pt(v:JV) -> string, float3: return as_str(v.a[0]), float3 { as_float(v.a[1]), as_float(v.a[2]), as_float(v.a[3]) }

// (hard_by_default: gear's shapes don't melt into the body unless they say so)
def vx_parse_shape(o:JV, hard_by_default:bool) -> vx_spec:
    let s = vx_spec { vx_k_cap, gbool(o, "hard", hard_by_default), gbool(o, "mirror", false), "", float3_0, "", float3_0, 0.0, 0.0,
                      if has(o, "mat"): vx_mat(as_str(at(o, "mat"))) else: 0, 0, float3_0, float3_0, [], [], 0.0, 0.0,
                      gstrs(o, "if"), gstrs(o, "unless") }
    let rr = if has(o, "r"): at(o, "r") else: jnull()
    let r0 = if rr.kind == J_ARR: as_float(rr.a[0]) elif rr.kind != J_NULL: as_float(rr) else: 0.0
    let r1 = if rr.kind == J_ARR: as_float(rr.a[1]) else: r0
    if has(o, "cap"):
        s.pa, s.a = vx_pt(at(o, "cap"))
        s.pb, s.b = vx_pt(at(o, "to"))
        s.ra, s.rb = r0, r1
    elif has(o, "ball") or has(o, "bead"):
        s.kind = vx_k_ball
        s.pa, s.a = vx_pt(at(o, if has(o, "ball"): "ball" else: "bead"))
        s.ra, s.rb = r0, r0
        if has(o, "bead"): s.hard = true
    elif has(o, "disc"):
        s.kind = vx_k_disc
        s.pa, s.a = vx_pt(at(o, "disc"))
        s.n = normalize(vx_v3(at(o, "n")))
        s.ra, s.rb = r0, r1
        s.hard = true
    elif has(o, "box"):
        s.kind = vx_k_box
        s.pa, s.a = vx_pt(at(o, "box"))
        s.n = normalize(vx_v3(at(o, "n")))
        s.half = vx_v3(at(o, "half"))
        s.ra = as_float(at(o, "round"))
        s.hard = true
    elif has(o, "chain"):
        s.kind = vx_k_chain
        for(glist(o, "chain")) p:
            let pn, po = vx_pt(p)
            s.pts.push(pn)
            s.offs.push(po)
        s.ra, s.step, s.rb, s.taper = as_float(rr.a[0]), as_float(rr.a[1]), as_float(rr.a[2]), as_float(rr.a[3])
        let ms = gstrs(o, "mats")
        s.mat, s.mat2 = vx_mat(ms[0]), vx_mat(ms[1])
    elif has(o, "ring"):
        s.kind = vx_k_ring
        s.pa, s.a = vx_pt(at(o, "ring"))
        s.ra, s.rb = r0, r1  // the ring's radius and its tilt
        s.hard = true
    elif has(o, "helm"):
        s.kind = vx_k_helm
        s.ra = as_float(at(o, "helm"))
        s.hard = true
    elif has(o, "fit"):
        s.kind = vx_k_fit
        s.ra = as_float(at(o, "fit"))
        s.hard = true
    else: assert false
    return s

def vx_parse_shapes(l:[JV]) -> [vx_spec]: return map(l) o: vx_parse_shape(o, false)
def vx_parse_gear_shapes(l:[JV]) -> [vx_spec]: return map(l) o: vx_parse_shape(o, true)

class vx_leg_spec:  // a pair of legs, the one given on the right, mirrored on the left
    pa:string
    a:float3
    foot:float3   // where its foot stands at rest (the right one's)
    stride:float  // how far a foot moves forward and back in a walk
    lift:float    // how high it lifts swinging forward
    phase:float   // degrees ahead in the walk (a back pair 180 from a front)
    l1:float      // the bones
    l2:float
    pole:float3  // where its middle joint bends (the right one's)
    r:[float]    // the thigh's two radii, the shin's
    mats:[int]
    shapes:[vx_spec]  // on hip, knee, ankle

class vx_body_spec:
    id:string
    size:float
    fur:float
    skin_scale:float
    reach:float
    skin:float3  // its colours when the race gives none
    pale:float3
    mark:float3    // a third: markings, a muzzle (palettes' third colour)
    flies:float    // how high it flies (0: it walks; its points are set at that height)
    pflap:[float]  // per point: how far it flaps up and down (wings) as it moves
    harness:bool   // no hands: what it holds rides in a harness at these points (right, left)
    hr_pt:string
    hr:float3
    hr_dir:float3
    hl_pt:string
    hl:float3
    fused_pt:string  // a mount a rider grows out of (a centaur's horse): where its rider's hip is
    fused:float3
    pnames:[string]
    pat:[float3]
    pbob:[float]
    legs:[vx_leg_spec]
    shapes:[vx_spec]
    arms:bool
    sh_pt:string  // the right shoulder (mirrored on the left)
    sh:float3
    arm:float  // each arm bone
    thick:float
    sleeve:int
    hand:int
    helm_pt:string  // a helmet's centre and radius: the skull's, a little more
    helm:float3
    helm_r:float
    fit_pa:string  // armour's spot: a capsule over the trunk
    fit_a:float3
    fit_pb:string
    fit_b:float3
    fit_r:float2
    seat_z:float  // a rider: its seat's height in its own frame, and its legs astride: thigh, shin, foot
    astride:[int]
    seat:float3  // a mount: where its rider sits, how far out its rider's knees go
    wide:float
    looks:[float]  // per look: the skin shade
    hair:[float3]  // and hair colour

class vx_hold_spec:
    rest:float3
    dir:float3
    swing:float
    wind:float3
    wind_dir:float3
    hit:float3
    hit_dir:float3
    act:bool      // wind and hit given
    raise:float3  // a bow: raised, and drawn by the other hand
    draw:float3
    draws:bool

class vx_gear_spec:
    id:string
    hand:int  // 1 right, -1 left, 0 worn
    hold:string
    dir:float3   // a hold's direction for this gear (zero: the hold's)
    face:float3  // a left-hand item's facing
    shapes:[vx_spec]
    fit_ids:[string]
    fits:[[vx_spec]]
    flags:[string]

class vx_rule:
    part:string
    tag:string
    slot:string
    gear:string

let vx_bodies = dictionary<string, vx_body_spec>(64)
let vx_gears = dictionary<string, vx_gear_spec>(128)
let vx_holds = dictionary<string, vx_hold_spec>(32)
var vx_rules = []::vx_rule
var vx_loaded = false
var vx_data_dirs = []::string

def vx_parse_body(id:string, o:JV) -> vx_body_spec:
    let b = vx_body_spec { id, gfloat(o, "size", 1.0), gfloat(o, "fur", 0.0), gfloat(o, "skin_scale", 1.0), gfloat(o, "reach", 4.0),
                           vx_hex(gstr(o, "skin", "#dba880")), vx_hex(gstr(o, "pale", "#ebbf99")), vx_hex(gstr(o, "mark", "#f0ebe0")),
                           gfloat(o, "flies", 0.0), [], false, "", float3_0, float3_0, "", float3_0, "", float3_0,
                           [], [], [], [], [], false, "", float3_0, 0.0, 0.0, 0, 0, "", float3_0, 0.0, "", float3_0, "", float3_0, float2_0,
                           0.0, [], float3_0, 0.0, [ 1.0 ], [ vx_MAT_BASE[vx_mat("hair")] ] }
    let pts = gobj(o, "points")
    for(pts.keys) name, k:
        b.pnames.push(name)
        b.pat.push(vx_v3(at(pts.a[k], "at")))
        b.pbob.push(gfloat(pts.a[k], "bob", 0.0))
        b.pflap.push(gfloat(pts.a[k], "flap", 0.0))
    for(glist(o, "legs")) l:
        let pa, a = vx_pt(at(l, "hip"))
        let rs = map(glist(l, "r")) v: as_float(v)
        b.legs.push(vx_leg_spec { pa, a, vx_v3(at(l, "foot")), gfloat(l, "stride", 0.0), gfloat(l, "lift", 0.0), gfloat(l, "phase", 0.0),
                                  as_float(glist(l, "bones")[0]), as_float(glist(l, "bones")[1]), vx_v3(at(l, "pole")), rs,
                                  map(gstrs(l, "mats")) m: vx_mat(m), vx_parse_shapes(glist(l, "shapes")) })
    b.shapes = vx_parse_shapes(glist(o, "shapes"))
    if has(o, "arms"):
        let ar = at(o, "arms")
        b.arms = true
        b.sh_pt, b.sh = vx_pt(at(ar, "shoulder"))
        b.arm, b.thick = as_float(at(ar, "bone")), as_float(at(ar, "thick"))
        b.sleeve, b.hand = vx_mat(gstr(ar, "sleeve", "skin")), vx_mat(gstr(ar, "hand", "skin"))
    if has(o, "harness"):
        let ho = at(o, "harness")
        b.harness = true
        b.hr_pt, b.hr = vx_pt(at(ho, "right"))
        b.hr_dir = vx_v3(at(ho, "dir"))
        b.hl_pt, b.hl = vx_pt(at(ho, "left"))
    if has(o, "fused"): b.fused_pt, b.fused = vx_pt(at(o, "fused"))
    if has(o, "helm"):
        b.helm_pt, b.helm = vx_pt(at(at(o, "helm"), "at"))
        b.helm_r = as_float(at(at(o, "helm"), "r"))
    if has(o, "armour"):
        let fo = at(o, "armour")
        b.fit_pa, b.fit_a = vx_pt(at(fo, "a"))
        b.fit_pb, b.fit_b = vx_pt(at(fo, "b"))
        b.fit_r = float2 { as_float(glist(fo, "r")[0]), as_float(glist(fo, "r")[1]) }
    if has(o, "seat"):
        let so = at(o, "seat")
        b.seat_z = gfloat(so, "z", 0.0)
        b.astride = map(gstrs(so, "astride")) m: vx_mat(m)
        if has(so, "at"): b.seat = vx_v3(at(so, "at"))
        b.wide = gfloat(so, "wide", 0.0)
    if has(o, "looks"):
        b.looks = map(glist(o, "looks")) l: gfloat(l, "skin", 1.0)
        b.hair = map(glist(o, "looks")) l: vx_hex(gstr(l, "hair", "#1f1714"))
    return b

def gfloat(o:JV, k:string, fallback:float) -> float: return if has(o, k): as_float(at(o, k)) else: fallback

def vx_v3_or(o:JV, k:string) -> float3: return if has(o, k): vx_v3(at(o, k)) else: float3_0

// Reads data/voxel/ (and a mod's, which add or replace by id) once.
def vx_load(dirs:[string]):
    if vx_loaded: return
    vx_loaded = true
    vx_data_dirs = dirs
    for(dirs) d:
        let mo = parse_json(read_file(d + "/materials.json") or "\{\}")
        for(mo.keys) name, k:
            if name[0] != '_':
                var m = find(vx_mat_names) n: n == name
                if m < 0:
                    vx_mat_names.push(name)
                    vx_MAT_BASE.push(float3_0)
                    vx_MAT_FUR.push(0)
                    m = vx_mat_names.length - 1
                vx_MAT_BASE[m] = vx_hex(gstr(mo.a[k], "rgb", "#ff00ff"))
                vx_MAT_FUR[m] = if gbool(mo.a[k], "fur", false): 1 else: 0
    vx_mat_cols = copy(vx_MAT_BASE)
    vx_mat_team = vx_mat("team")
    for(dirs) d:
        let go = parse_json(read_file(d + "/gear.json") or "\{\}")
        if has(go, "holds"):
            let ho = at(go, "holds")
            for(ho.keys) name, k:
                let h = ho.a[k]
                vx_holds.set(name, vx_hold_spec { vx_v3(at(h, "rest")), vx_v3_or(h, "dir"), gfloat(h, "swing", 0.0), vx_v3_or(h, "wind"),
                                                  vx_v3_or(h, "wind_dir"), vx_v3_or(h, "hit"), vx_v3_or(h, "hit_dir"), has(h, "hit"),
                                                  vx_v3_or(h, "raise"), vx_v3_or(h, "draw"), has(h, "draw") })
        if has(go, "gear"):
            let gs = at(go, "gear")
            for(gs.keys) name, k:
                let g = gs.a[k]
                let hand = gstr(g, "hand", "")
                let fits = gobj(g, "fits")
                vx_gears.set(name, vx_gear_spec { name, if hand == "right": 1 elif hand == "left": -1 else: 0, gstr(g, "hold", ""),
                                                  vx_v3_or(g, "dir"), normalize(if has(g, "face"): vx_v3(at(g, "face")) else: float3 { 0.0, 1.0, 0.0 }),
                                                  vx_parse_gear_shapes(glist(g, "shapes")), copy(fits.keys), map(fits.a) l: vx_parse_gear_shapes(l.a),
                                                  gstrs(g, "flags") })
        if has(go, "parts"):  // a mod's rules go first: they're more particular
            let rs = map(glist(go, "parts")) r: vx_rule { gstr(r, "part", ""), gstr(r, "tag", ""), gstr(r, "slot", ""), gstr(r, "gear", "") }
            for(vx_rules) r: rs.push(r)
            vx_rules = rs
        let names = scan_folder(d + "/bodies", false)
        if names:
            for(sorted_strs(names)) n:
                if ends_with(n, ".json"):
                    let id = substring(n, 0, n.length - 5)
                    let o = parse_json(assert read_file(d + "/bodies/" + n))
                    let b = vx_parse_body(id, o)
                    vx_bodies.set(id, b)
                    for(gstrs(o, "also")) a: vx_bodies.set(a, b)  // (other body ids drawn the same, their palettes apart)

// The data's text (every file read): part of the bake cache's key, so a change to the data bakes again.
def vx_data_text() -> string:
    var t = ""
    for(vx_data_dirs) d:
        t += (read_file(d + "/materials.json") or "") + (read_file(d + "/gear.json") or "")
        let names = scan_folder(d + "/bodies", false)
        if names: for(sorted_strs(names)) n: t += read_file(d + "/bodies/" + n) or ""
    return t

def vx_body_of(id:string) -> vx_body_spec:
    let b = vx_bodies.get(id)
    assert b
    return b

// The gear for a recipe's part in a slot (the rules' first match), or "".
def vx_gear_for(part_id:string, tags:[string], slot:string) -> string:
    for(vx_rules) r:
        let by_part = r.part != "" and (part_id == r.part or starts_with(part_id, r.part + "."))
        let by_tag = r.tag != "" and (find(tags) t: t == r.tag) >= 0
        let by_slot = r.part == "" and r.tag == "" and r.slot != "" and r.slot == slot
        if (by_part or by_tag or by_slot) and (r.slot == "" or r.slot == slot or by_slot): return r.gear
    return ""

// ---- units

class vx_unit_def:
    label:string
    body:string  // bodies/<id>.json
    skin:float3  // the race's colours (palettes.json; zero: the body's)
    pale:float3
    mark:float3
    gear:[string]  // gear.json's
    mount:string   // a mount's body, or ""
    fused:bool     // the rider grows out of its mount (a centaur): at the mount body's `fused` point
    coat:float3    // the mount's colours (zero: its body's)
    mane:float3
    coat_mark:float3

var vx_variant = 0          // the look being built
var vx_seated = false       // a rider being built: no legs of its own (shapes with `unless: seated` left off)
var vx_team_wear = "scarf"  // where a creature without a tunic wears the team: scarf or vest (a concept option)
var vx_act = ""             // the pose being drawn: "" (standing or walking) or "attack", at a step through it

def vx_looks_of(u:vx_unit_def) -> int: return vx_body_of(u.body).looks.length

// The materials for unit u in look v (its mount's coat too).
def vx_set_look(u:vx_unit_def, v:int):
    let b = vx_body_of(u.body)
    vx_variant = v
    let skin = if u.skin != float3_0: u.skin else: b.skin
    vx_mat_cols[vx_mat("skin")] = min(skin * b.skin_scale * b.looks[v], float3_1)
    vx_mat_cols[vx_mat("pale")] = if u.pale != float3_0: u.pale else: b.pale
    vx_mat_cols[vx_mat("mark")] = if u.mark != float3_0: u.mark else: b.mark
    vx_mat_cols[vx_mat("hair")] = b.hair[v]
    vx_fur = b.fur
    if u.mount != "":
        let mb = vx_body_of(u.mount)
        vx_mat_cols[vx_mat("coat")] = if u.coat != float3_0: u.coat else: mb.skin
        vx_mat_cols[vx_mat("mane")] = if u.mane != float3_0: u.mane else: mb.pale
        vx_mat_cols[vx_mat("coat_mark")] = if u.coat_mark != float3_0: u.coat_mark else: mb.mark

// How far into its blow an attack is at t: a wind-up, a fast strike, a hold, back.
def vx_blow(t:float) -> float:
    return if t < 0.45: 0.0 elif t < 0.6: (t - 0.45) / 0.15 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25

def vx_raise(t:float) -> float:  // raised through the wind-up, held, lowered
    return if t < 0.45: t / 0.45 elif t < 0.75: 1.0 else: 1.0 - (t - 0.75) / 0.25

def vx_mix(a:float3, b:float3, k:float) -> float3: return a + (b - a) * k

// Points a shape can stand on: named, with where each is now.
class vx_points:
    names:[string]
    at:[float3]

def vx_where(p:vx_points, name:string) -> float3:
    let k = find(p.names) n: n == name
    assert k >= 0
    return p.at[k]

def vx_flagged(flags:[string], s:vx_spec) -> bool:
    for(s.need) f: if (find(flags) g: g == f) < 0: return false
    for(s.avoid) f: if (find(flags) g: g == f) >= 0: return false
    return true

// A shape's prims at the points, its offsets turned by the frame (along, out, side; the body's own: x, y, z unturned).
def vx_emit(out:[vx_prim], s:vx_spec, p:vx_points, fx:float3, fy:float3, fz:float3, flags:[string], body:vx_body_spec?):
    if not vx_flagged(flags, s): return
    for(if s.mirror: 2 else: 1) side:
        let m = if side == 1: float3 { -1.0, 1.0, 1.0 } else: float3_1
        let tr = fn(o:float3) -> float3: fx * (o.x * m.x) + fy * o.y + fz * o.z
        switch s.kind:
            case vx_k_cap: out.push(vx_prim { vx_where(p, s.pa) + tr(s.a), vx_where(p, s.pb) + tr(s.b), s.ra, s.rb, s.mat, s.hard, false, float3_0 })
            case vx_k_ball: out.push(vx_prim { vx_where(p, s.pa) + tr(s.a), vx_where(p, s.pa) + tr(s.a), s.ra, s.ra, s.mat, s.hard, false, float3_0 })
            case vx_k_disc:
                let c = vx_where(p, s.pa) + tr(s.a)
                out.push(vx_disc(c, normalize(tr(s.n)), s.ra, s.rb, s.mat))
            case vx_k_box:
                let c = vx_where(p, s.pa) + tr(s.a)
                out.push(vx_box(c, normalize(tr(s.n)), s.half, s.ra, s.mat))
            case vx_k_chain:
                var r = s.ra
                for(s.pts.length - 1) k:
                    let a = vx_where(p, s.pts[k]) + tr(s.offs[k])
                    let b = vx_where(p, s.pts[k + 1]) + tr(s.offs[k + 1])
                    out.push(vx_prim { a, b, r, r - s.taper, if k == 0: s.mat else: s.mat2, s.hard, false, float3_0 })
                    r = max(s.rb, r + s.step)
            case vx_k_ring:  // a scarf: a ring round a point, tipped down at the front, its knot hanging
                let c = vx_where(p, s.pa) + tr(s.a)
                var last = float3_0
                for(9) k:
                    let a = float(k) * 45.0
                    let q = c + float3 { sin(a) * s.ra, cos(a) * s.ra, -cos(a) * s.rb }
                    if k > 0: out.push(vx_hard(last, q, 0.9, 0.9, s.mat))
                    last = q
                out.push(vx_hard(c + float3 { 0.6, s.ra, -s.rb }, c + float3 { 1.0, s.ra + 0.6, -s.rb - 2.6 }, 0.9, 0.6, s.mat))
            case vx_k_helm:
                let b = body
                if b:
                    let c = vx_where(p, b.helm_pt) + b.helm
                    out.push(vx_hard(c, c + float3 { 0.0, -0.15, 0.15 }, b.helm_r + s.ra, b.helm_r + s.ra, s.mat))
            case vx_k_fit:
                let b = body
                if b: out.push(vx_hard(vx_where(p, b.fit_pa) + b.fit_a, vx_where(p, b.fit_pb) + b.fit_b, b.fit_r.x + s.ra, b.fit_r.y + s.ra, s.mat))
            default: assert false

let vx_X = float3 { 1.0, 0.0, 0.0 }
let vx_Y = float3 { 0.0, 1.0, 0.0 }
let vx_Z = float3 { 0.0, 0.0, 1.0 }

// The flags a unit's shapes check (if / unless): its gear's, its look, seated, how it wears the team.
def vx_flags_of(u:vx_unit_def) -> [string]:
    let f = [ "look:{vx_variant}", "wear:{vx_team_wear}" ]
    if vx_seated: f.push("seated")
    for(u.gear) g:
        let gs = vx_gears.get(g)
        assert gs
        f.push("has:" + g)
        for(gs.flags) x: f.push(x)
    return f

// A body's points at walk phase ph (its bob), raised by lift.
// A body that would have to stretch a leg past its bones to reach its foot (a long stride on short legs) is lowered
// until every foot is in reach, with a little bend left (the hips dip at full stride, as a walker's do); else the
// leg stays straight and the foot drags short of where it should be.
def vx_body_points(b:vx_body_spec, ph:float, lift:float3) -> vx_points:
    let bob = abs(sin(ph * 2.0))
    let flap = sin(ph * 4.0)
    let p = vx_points { copy(b.pnames), map(b.pat) a, k: a + float3 { 0.0, 0.0, b.pbob[k] * bob + b.pflap[k] * flap } + lift }
    if vx_seated: return p  // (a rider's legs are its seat's)
    var drop = 0.0
    for(b.legs) l:
        for([ 1.0, -1.0 ]) side:
            let m = float3 { side, 1.0, 1.0 }
            let w = ph + l.phase
            let hip = vx_where(p, l.pa) + l.a * m
            let foot = l.foot * m + float3 { 0.0, sin(w) * side * l.stride, max(0.0, cos(w) * side) * l.lift }
            let d = hip - foot
            let reach = (l.l1 + l.l2) * 0.97
            let across = d.x * d.x + d.y * d.y
            if across < reach * reach and d.z > 0.0: drop = max(drop, d.z - sqrt(reach * reach - across))
    if drop > 0.0: p.at = map(p.at) a: a - float3 { 0.0, 0.0, drop }
    return p

// The legs, walking at ph: each foot planted where it rests, moved along by sin(ph + its phase) * stride, lifted as
// it swings forward; the knee (or a front leg's elbow) bent towards the pole.
def vx_legs(out:[vx_prim], b:vx_body_spec, p:vx_points, ph:float, flags:[string]):
    for(b.legs) l:
        for([ 1.0, -1.0 ]) side:
            let m = float3 { side, 1.0, 1.0 }
            let w = ph + l.phase
            let st = sin(w) * side * l.stride
            let up = max(0.0, cos(w) * side) * l.lift
            let hip = vx_where(p, l.pa) + l.a * m
            let foot = l.foot * m + float3 { 0.0, st, up }
            let knee, ankle = vx_ik(hip, foot, l.l1, l.l2, l.pole * m)
            out.push(vx_cap(hip, knee, l.r[0], l.r[1], l.mats[0]))
            out.push(vx_cap(knee, ankle, l.r[2], l.r[3], l.mats[1]))
            let lp = vx_points { [ "hip", "knee", "ankle" ], [ hip, knee, ankle ] }
            for(l.shapes) s:
                let s2 = s  // (the left one mirrored: its offsets' x turned)
                if side > 0.0: vx_emit(out, s2, lp, vx_X, vx_Y, vx_Z, flags, nil)
                else: vx_emit(out, vx_mirrored(s2), lp, vx_X, vx_Y, vx_Z, flags, nil)

def vx_mirrored(s:vx_spec) -> vx_spec:
    let m = float3 { -1.0, 1.0, 1.0 }
    return vx_spec { s.kind, s.hard, false, s.pa, s.a * m, s.pb, s.b * m, s.ra, s.rb, s.mat, s.mat2, s.n * m, s.half,
                     s.pts, map(s.offs) o: o * m, s.step, s.taper, s.need, s.avoid }

def vx_worn_gear(g:string) -> bool:
    let gs = vx_gears.get(g)
    return gs and gs.hand == 0

def vx_held(u:vx_unit_def, hand:int) -> vx_gear_spec?:
    for(u.gear) g:
        let gs = vx_gears.get(g)
        if gs and gs.hand == hand: return gs
    return nil

// The arms and what's in the hands, posed by the holds and the act. L: an arm bone's length (the reach is 2L).
def vx_arms(out:[vx_prim], u:vx_unit_def, b:vx_body_spec, p:vx_points, swing:float, t:float, flags:[string]):
    let L = b.arm * 2.0
    let k = vx_blow(t)
    let up = vx_raise(t)
    let attack = vx_act == "attack"
    let sh_r = vx_where(p, b.sh_pt) + b.sh
    let sh_l = vx_where(p, b.sh_pt) + b.sh * float3 { -1.0, 1.0, 1.0 }
    let hang = vx_holds.get("hang")
    assert hang
    var hr = sh_r + (hang.rest + float3 { 0.0, swing * hang.swing, 0.0 }) * L  // hanging, swung
    var dr = hang.dir
    var hl = sh_l + (hang.rest * float3 { -1.0, 1.0, 1.0 } - float3 { 0.0, swing * hang.swing, 0.0 }) * L
    var drawn = false
    let right = vx_held(u, 1)
    let left = vx_held(u, -1)
    if right:
        let h = vx_holds.get(right.hold)
        assert h
        hr = sh_r + h.rest * L
        dr = if right.dir != float3_0: right.dir else: h.dir
        if attack and h.act:
            hr = vx_mix(vx_mix(hr, sh_r + h.wind * L, up), sh_r + h.hit * L, k)
            dr = vx_mix(vx_mix(dr, h.wind_dir, up), h.hit_dir, k)
    if left:
        let h = vx_holds.get(left.hold)
        assert h
        hl = sh_l + h.rest * L
        if attack and h.draws:
            hl = vx_mix(hl, sh_l + h.raise * L, up)
            hr = vx_mix(hr, sh_r + h.draw * L, up * (1.0 - k))
            drawn = up * (1.0 - k) > 0.5
    for([ 1.0, -1.0 ]) side:
        let sh = if side > 0.0: sh_r else: sh_l
        let target = if side > 0.0: hr else: hl
        let elbow, hand = vx_ik(sh, target, b.arm, b.arm, float3 { side * 0.5, -1.0, -0.4 })
        out.push(vx_cap(sh, elbow, b.thick, b.thick * 0.8, b.sleeve))
        out.push(vx_cap(elbow, hand, b.thick * 0.75, b.thick * 0.6, b.hand))
        out.push(vx_ball(hand, b.thick * 0.8, b.hand))
        if side > 0.0: hr = hand
        else: hl = hand
    if right:  // its frame: along the held direction, out of its front, to the right
        let d = normalize(dr)
        let o = cross(vx_X, d)
        let gp = vx_points { [ "hand", "draw" ], [ hr, hr ] }
        for(right.shapes) s: vx_emit(out, s, gp, d, o, vx_X, flags, nil)
    if left:  // up, out of its face, to the side
        let o = left.face
        let sd = normalize(cross(o, vx_Z))
        let gp = vx_points { [ "hand", "draw" ], [ hl, if drawn: hr else: hl - o * 0.4 ] }
        for(left.shapes) s: vx_emit(out, s, gp, vx_Z, o, sd, flags, nil)

// What a body with no hands holds, in its harness: the right item along the harness's direction (lowered into a thrust
// in a blow), the left on its side.
def vx_harness(out:[vx_prim], u:vx_unit_def, b:vx_body_spec, p:vx_points, t:float, flags:[string]):
    let right = vx_held(u, 1)
    let left = vx_held(u, -1)
    if right:
        let k = if vx_act == "attack": vx_blow(t) else: 0.0
        let d = normalize(vx_mix(b.hr_dir, float3 { 0.0, 1.0, 0.1 }, k))
        let hr = vx_where(p, b.hr_pt) + b.hr + float3 { 0.0, 3.0 * k, 0.0 }
        let gp = vx_points { [ "hand", "draw" ], [ hr, hr ] }
        for(right.shapes) s: vx_emit(out, s, gp, d, cross(vx_X, d), vx_X, flags, nil)
    if left:
        let hl = vx_where(p, b.hl_pt) + b.hl
        let o = normalize(float3 { -1.0, 0.25, 0.0 })  // (out to the side)
        let gp = vx_points { [ "hand", "draw" ], [ hl, hl - o * 0.4 ] }
        for(left.shapes) s: vx_emit(out, s, gp, vx_Z, o, normalize(cross(o, vx_Z)), flags, nil)

// Worn gear on a body (its fit for the body, or for any).
def vx_worn(out:[vx_prim], u:vx_unit_def, b:vx_body_spec, p:vx_points, flags:[string]):
    for(u.gear) g:
        let gs = vx_gears.get(g)
        assert gs
        if gs.hand == 0:
            var k = find(gs.fit_ids) i: i == b.id
            if k < 0: k = find(gs.fit_ids) i: i == "*"
            if k >= 0: for(gs.fits[k]) s: vx_emit(out, s, p, vx_X, vx_Y, vx_Z, flags, b)

// A body with its worn gear and arms (when it has them) at points p.
def vx_whole_body(out:[vx_prim], u:vx_unit_def, b:vx_body_spec, p:vx_points, ph:float, t:float, flags:[string]):
    if not vx_seated: vx_legs(out, b, p, ph, flags)
    for(b.shapes) s: vx_emit(out, s, p, vx_X, vx_Y, vx_Z, flags, b)
    vx_worn(out, u, b, p, flags)
    if b.arms: vx_arms(out, u, b, p, if vx_seated: 0.0 else: sin(ph), t, flags)
    elif b.harness: vx_harness(out, u, b, p, t, flags)

// A whole unit's parts, walking at phase ph0 (degrees) or, when acting, at ph0 / 360 through the act.
def vx_unit_prims(u:vx_unit_def, ph0:float) -> [vx_prim]:
    let out = []::vx_prim
    let ph = if vx_act == "": ph0 else: 0.0
    let t = ph0 / 360.0
    let b = vx_body_of(u.body)
    if u.mount == "":
        vx_whole_body(out, u, b, vx_body_points(b, ph, float3_0), ph, t, vx_flags_of(u))
        return out
    // a rider: the mount walks (in its own colours, at its own size), the rider sits astride, legs down its sides;
    // on a fused mount (a centaur) the rider's body grows out of it
    let mb = vx_body_of(u.mount)
    let mount = []::vx_prim
    let mu = vx_unit_def { u.label, u.mount, float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0 }
    let fused = u.fused
    assert not fused or mb.fused_pt != ""
    let mp = vx_body_points(mb, ph, float3_0)
    vx_whole_body(mount, mu, mb, mp, ph, t, if fused: [ "fused" ] else: [])
    let ms = mb.size / b.size
    let skin = vx_mat("skin")
    let pale = vx_mat("pale")
    let mark = vx_mat("mark")
    for(mount) q:  // (the mount's own colours: its skin is the coat)
        let m = if q.mat == skin: vx_mat("coat") elif q.mat == pale: vx_mat("mane") elif q.mat == mark: vx_mat("coat_mark") else: q.mat
        out.push(vx_prim { q.a * ms, q.b * ms, q.ra * ms, q.rb * ms, m, q.hard, q.disc, q.box * ms })
    vx_seated = true
    let flags = vx_flags_of(u)
    if fused:
        let hip = (vx_where(mp, mb.fused_pt) + mb.fused) * ms
        vx_whole_body(out, u, b, vx_body_points(b, 0.0, hip - float3 { 0.0, 0.0, b.seat_z }), 0.0, t, flags)
        vx_seated = false
        return out
    let seat = mb.seat * ms
    vx_whole_body(out, u, b, vx_body_points(b, 0.0, seat - float3 { 0.0, 0.0, b.seat_z }), 0.0, t, flags)
    vx_seated = false
    let wide = mb.wide * ms
    for([ -1.0, 1.0 ]) side:
        let hip = seat + float3 { side * 2.0, 0.0, 0.6 }
        let knee = seat + float3 { side * wide, 3.4, -3.6 }
        let ankle = knee + float3 { 0.0, -0.8, -5.0 }
        out.push(vx_cap(hip, knee, 2.0, 1.7, b.astride[0]))
        out.push(vx_cap(knee, ankle, 1.4, 1.1, b.astride[1]))
        out.push(vx_cap(ankle, ankle + float3 { 0.0, 2.0, -0.4 }, 1.1, 1.0, b.astride[2]))
    return out

// A unit falling dead, at t (0 standing .. 1 lying): every part turned onto its right side about the body's long
// axis through its middle (vx_fill sets its lowest point back on the ground), toppling slowly then fast. It stops
// short of flat (84 degrees): a box facing sideways would turn straight up, where it has no across.
let vx_FALL = 84.0
def vx_fallen(parts:[vx_prim], t:float) -> [vx_prim]:
    var lo = 1000.0
    var hi = -1000.0
    for(parts) p:
        if not p.hard:
            let a, b = vx_bounds(p)
            lo = min(lo, a.z)
            hi = max(hi, b.z)
    let mid = (lo + hi) * 0.5
    let a = vx_FALL * t * t
    let c = cos(a)
    let s = sin(a)
    def turn(q:float3) -> float3: return float3 { q.x * c + (q.z - mid) * s, q.y, -q.x * s + (q.z - mid) * c + mid }
    return map(parts) p: vx_prim { turn(p.a), turn(p.b), p.ra, p.rb, p.mat, p.hard, p.disc, p.box }

// Does the unit fly (its body's, or its mount's)? Its ground isn't under its lowest point.
def vx_flies(u:vx_unit_def) -> bool: return vx_body_of(u.body).flies > 0.0 or (u.mount != "" and vx_body_of(u.mount).flies > 0.0)

// The unit's size: its body's (a mount is scaled to it).
def vx_size_of(u:vx_unit_def) -> float: return vx_body_of(u.body).size

// ---- the voxel grid

class vx_shape:  // a filled grid's surface: the voxels with air beside them (none of the rest can show)
    pos:[int3]   // voxels from the unit's ground point
    mats:[int]
    normals:[float3]  // the shape's smooth normal (the grid's stairs would speckle the shading)
    occl:[float]      // how hemmed in (0 open to 1 deep in a crease): ambient occlusion
    lo:int3           // the grid (for shadows): its corner, size, and per voxel a material or -1
    dims:int3
    grid:[int]

def vx_scaled(p:vx_prim, s:float, lift:float) -> vx_prim:
    let up = float3 { 0.0, 0.0, lift }
    return vx_prim { (p.a + up) * s, (p.b + up) * s, p.ra * s, p.rb * s, p.mat, p.hard, p.disc, p.box * s }

def vx_bounds(p:vx_prim) -> float3, float3:
    let r = max(p.ra, p.rb) + (if p.disc: p.ra else: 0.0) + magnitude(p.box)
    return min(p.a, p.b) - float3_1 * r, max(p.a, p.b) + float3_1 * r

// The shape's distance at p from the parts in `near`, and the material of the part nearest it. (Capsules, most of
// the parts, measured inline: this is the bake's hot loop.)
def vx_field(ps:[vx_prim], near:[int], p:float3, k:float) -> float, int:
    var body = 1000.0
    var gear = 1000.0
    var best = 1000.0
    var m = -1
    for(near) i:
        let s = ps[i]
        var d = 0.0
        if s.disc or s.box.x > 0.0: d = vx_dist(p, s)
        else:
            let ba = s.b - s.a
            let pa = p - s.a
            let l2 = dot(ba, ba)
            let h = if l2 > 0.0: clamp(dot(pa, ba) / l2, 0.0, 1.0) else: 0.0
            d = magnitude(pa - ba * h) - (s.ra + (s.rb - s.ra) * h)
        if s.hard: gear = min(gear, d)
        else:
            let e = max(k - abs(body - d), 0.0) / k
            body = min(body, d) - e * e * k * 0.25
        if d < best:
            best = d
            m = s.mat
    return min(body, gear - 0.5), m  // (gear thickened half a voxel: a shaft thinner than a voxel would break up)

let vx_AO_TAPS = [ int3 { 2, 0, 0 }, int3 { -2, 0, 0 }, int3 { 0, 2, 0 }, int3 { 0, -2, 0 }, int3 { 0, 0, 2 }, int3 { 0, 0, -2 },
                   int3 { 2, 2, 2 }, int3 { -2, 2, 2 }, int3 { 2, -2, 2 }, int3 { -2, -2, 2 },
                   int3 { 2, 2, -2 }, int3 { -2, 2, -2 }, int3 { 2, -2, -2 }, int3 { -2, -2, -2 } ]

def vx_solid_at(grid:[int], lo:int3, dims:int3, v:int3) -> bool:
    let q = v - lo
    if q.z < 0: return true  // (the ground)
    if q.x < 0 or q.y < 0 or q.x >= dims.x or q.y >= dims.y or q.z >= dims.z: return false
    return grid[(q.z * dims.y + q.y) * dims.x + q.x] >= 0

// The parts filled into a grid at a voxel a baked pixel (the unit's size scaled in). The grid is cut in blocks of 4
// voxels; each part is listed in the blocks its bounds touch, so a voxel only measures the parts near it. A block
// is tested at its centre first: clearly outside is skipped, clearly inside filled whole (none of it shows);
// only blocks the surface crosses are measured voxel by voxel. The blocks are filled a slice at a time
// (vx_fill_more), so a bake in play can spread one over frames.
class vx_filling:
    ps:[vx_prim]
    k:float
    lo:int3
    nb:int3
    dims:int3
    blocks:[[int]]
    mats:[int]
    field:[float]  // the distance where it was measured (air elsewhere, -1 deep inside), for normals
    next:int       // the next block to fill

def vx_fill_begin(parts:[vx_prim], unit_size:float, flies:bool) -> vx_filling:
    let s = unit_size * vx_RES
    var low = if flies: 0.0 else: 1000.0  // (a flier's ground is the builder's z 0, not under its lowest point)  // the ground: under the body's lowest point (gear reaching lower, a spear's butt, is cut off
    for(parts) p:                         // by it: a frog's spear set it on the ground and lifted the frog off it)
        if not p.hard and not flies:
            let a = vx_bounds(p)  // (its low corner; the high one isn't needed)
            low = min(low, a.z)
    let ps = map(parts) p: vx_scaled(p, s, -low)
    let k = vx_BLEND * s
    var a = float3_1 * 1000.0
    var b = float3_1 * -1000.0
    for(ps) p:
        let pa, pb = vx_bounds(p)
        a = min(a, pa)
        b = max(b, pb)
    let lo = int3 { int(floor(a.x)) - 2, int(floor(a.y)) - 2, 0 }
    let nb = (int3 { int(-floor(-b.x)) + 2, int(-floor(-b.y)) + 2, int(-floor(-b.z)) + 2 } - lo + int3_1 * 3) / 4
    let dims = nb * 4
    let blocks = map(nb.x * nb.y * nb.z): []::int
    let margin = k + 4.0
    for(ps) p, i:
        let pa, pb = vx_bounds(p)
        let qa = max(int3_0, (int3 { int(floor(pa.x - margin)), int(floor(pa.y - margin)), int(floor(pa.z - margin)) } - lo) / 4)
        let qb = min(nb - int3_1, (int3 { int(floor(pb.x + margin)), int(floor(pb.y + margin)), int(floor(pb.z + margin)) } - lo) / 4)
        for(qb.z - qa.z + 1) z: for(qb.y - qa.y + 1) y: for(qb.x - qa.x + 1) x:
            blocks[((qa.z + z) * nb.y + qa.y + y) * nb.x + qa.x + x].push(i)
    let n = dims.x * dims.y * dims.z
    return vx_filling { ps, k, lo, nb, dims, blocks, map(n): -1, map(n): 1.0, 0 }

// Fills blocks until the clock passes `until` (seconds_elapsed): true when they're all filled.
def vx_fill_more(fl:vx_filling, until:float) -> bool:
    let ps = fl.ps
    let k = fl.k
    let nb = fl.nb
    let dims = fl.dims
    let mats = fl.mats
    let field = fl.field
    let base = float(fl.lo) + float3_1 * 0.5
    let reach = 3.5  // a block's half diagonal, voxels
    while fl.next < fl.blocks.length:
        let bi = fl.next
        fl.next++
        let near = fl.blocks[bi]
        if near.length:
            let b0 = int3 { bi % nb.x, (bi / nb.x) % nb.y, bi / (nb.x * nb.y) } * 4
            let pc = base + float(b0) + float3_1 * 1.5
            // the block's centre, and the parts close enough to matter anywhere in it (the bins are loose boxes)
            let close = []::int
            var body = 1000.0
            var gear = 1000.0
            var best = 1000.0
            var mc = -1
            for(near) j:
                let pj = ps[j]
                let d = vx_dist(pc, pj)
                if pj.hard: gear = min(gear, d)
                else: body = vx_smin(body, d, k)
                if d < best:
                    best = d
                    mc = pj.mat
                if d < reach + k + 3.0: close.push(j)
            let dc = min(body, gear - 0.5)
            if dc < reach:
                for(4) z: for(4) y: for(4) x:
                    let v = b0 + int3 { x, y, z }
                    let i = (v.z * dims.y + v.y) * dims.x + v.x
                    if dc < -reach:
                        mats[i] = mc
                        field[i] = -1.0
                    else:
                        let d, m = vx_field(ps, close, base + float(v), k)
                        field[i] = d
                        if d <= 0.0: mats[i] = m
            if (bi & 15) == 0 and seconds_elapsed() >= until: return fl.next >= fl.blocks.length
    return true

def vx_fill(parts:[vx_prim], unit_size:float, flies:bool = false) -> vx_shape:
    let fl = vx_fill_begin(parts, unit_size, flies)
    vx_fill_more(fl, 1000000000.0)
    return vx_fill_end(fl)

// The filled grid's surface: each surface voxel, its normal and how hemmed in it is.
def vx_fill_end(fl:vx_filling) -> vx_shape:
    let lo = fl.lo
    let dims = fl.dims
    let mats = fl.mats
    let field = fl.field
    // the surface, each voxel's normal from the distances around it
    let pos = []::int3
    let smat = []::int
    let nrm = []::float3
    let sy = dims.x
    let sz = dims.x * dims.y
    for(dims.z - 2) z0: for(dims.y - 2) y0: for(dims.x - 2) x0:
        let i = ((z0 + 1) * dims.y + y0 + 1) * dims.x + x0 + 1
        let m = mats[i]
        if m >= 0 and (mats[i - 1] < 0 or mats[i + 1] < 0 or mats[i - sy] < 0 or mats[i + sy] < 0 or mats[i - sz] < 0 or mats[i + sz] < 0):
            pos.push(lo + int3 { x0 + 1, y0 + 1, z0 + 1 })
            smat.push(m)
            nrm.push(normalize(float3 { field[i + 1] - field[i - 1], field[i + sy] - field[i - sy], field[i + sz] - field[i - sz] }))
    // ambient occlusion: how many of 14 voxels round it (2 out along the axes and the diagonals) are solid; an open
    // flat surface has about half
    let occl = map(pos) v:
        var hit = 0
        for(vx_AO_TAPS) t: if vx_solid_at(mats, lo, dims, v + t): hit++
        clamp((float(hit) / 14.0 - 0.45) / 0.35, 0.0, 1.0)
    return vx_shape { pos, smat, nrm, occl, lo, dims, mats }

// ---- drawing: each surface voxel splatted into the cell over the pixels its cube covers, the nearest kept

def vx_hash(v:int3) -> int:
    var h = v.x * 73856093 ^ v.y * 19349663 ^ v.z * 83492791
    h = (h ^ (h >> 13)) * 1274126177
    return (h ^ (h >> 16)) & 1023

let vx_LIGHT = normalize(float3 { -0.65, 0.1, 0.75 })  // the body's key light, as the camera sees it: high on the sun's side
var vx_shadows = true                                  // shadows on the body (its own, and occlusion in creases), and on the ground
let vx_SUN = normalize(float3 { -0.55, 0.45, 1.0 })    // towards the sun, as the camera sees it: upper left (the world's)
var vx_depth = []::float                               // the cell being drawn (reused: only the last one's box is cleared)
var vx_cols = []::float3
var vx_mat = []::int
var vx_out = []::float4
var vx_box = int4_0  // the last cell's box, outline included: x0, y0, x1, y1

// One facing of a shape as a sprite cell (alpha 0 around it; drawn in vx_box): the cell is reused by the next call,
// so copy what's wanted first. The team colour's key (magenta) survives the shading, so the game's sprite shader can
// recolour it.
def vx_cell(sh:vx_shape, facing:int) -> [float4]: return vx_cell_in(sh, facing, vx_CELL.x, vx_CELL.y, vx_ANCHOR)

// The same, in a cell cw x ch with the ground point at anchor (buildings and props are bigger than units).
def vx_cell_in(sh:vx_shape, facing:int, cw:int, ch:int, anchor:int2) -> [float4]:
    let yaw = float(facing) * 45.0
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let ru = rot(float3 { 1.0, 0.0, 0.0 })
    let rv = rot(float3 { 0.0, sin(vx_ELEV), cos(vx_ELEV) })
    let rd = rot(float3 { 0.0, cos(vx_ELEV), -sin(vx_ELEV) })
    let light = rot(vx_LIGHT)
    let hx = 0.5 * (abs(ru.x) + abs(ru.y) + abs(ru.z))  // the cube's half extent on screen
    let hy = 0.5 * (abs(rv.x) + abs(rv.y) + abs(rv.z))
    if vx_depth.length != cw * ch:
        vx_depth = map(cw * ch): 1000000.0
        vx_cols = map(cw * ch): float3_0
        vx_mat = map(cw * ch): -1
        vx_out = map(cw * ch): float4_0
    else:  // the last cell's box cleared
        for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
            let j = (vx_box.y + yy) * cw + vx_box.x + xx
            vx_depth[j] = 1000000.0
            vx_mat[j] = -1
            vx_out[j] = float4_0
    var box = int4 { cw, ch, -1, -1 }
    for(sh.pos) v, i:
        let m = sh.mats[i]
        let p = float(v) + float3_1 * 0.5
        let u = dot(p, ru)
        let w = dot(p, rv)
        let d = dot(p, rd)
        var k = dot(sh.normals[i], light) * 0.5 + 0.5
        if vx_shadows:
            // in its own shadow? a few steps towards the light through the grid
            var q = p + sh.normals[i] * 1.2 + light * 1.0
            for(8):
                if k > 0.42 and vx_solid_at(sh.grid, sh.lo, sh.dims, int3 { int(floor(q.x)), int(floor(q.y)), int(floor(q.z)) }) and q.z > 0.0:
                    k = 0.3
                q += light * 1.7
            k -= sh.occl[i] * 0.3
        var c = vx_mat_cols[m] * (if k > 0.8: 1.08 elif k > 0.62: 0.94 elif k > 0.45: 0.76 elif k > 0.28: 0.6 else: 0.47)
        if vx_MAT_FUR[m] != 0: c *= 1.0 + vx_fur * (float(vx_hash(v)) / 511.5 - 1.0)
        c = min(c, float3_1)  // (over 1 wraps round in the game's texture: a bright pink came out cyan)
        let x0 = max(1, int(-floor(-(float(anchor.x) + u - hx - 0.5))))
        let x1 = min(cw - 2, int(floor(float(anchor.x) + u + hx - 0.5)))
        let y0 = max(1, int(-floor(-(float(anchor.y) - w - hy - 0.5))))
        let y1 = min(ch - 2, int(floor(float(anchor.y) - w + hy - 0.5)))
        box = int4 { min(box.x, x0), min(box.y, y0), max(box.z, x1), max(box.w, y1) }
        for(y1 - y0 + 1) yy: for(x1 - x0 + 1) xx:
            let j = (y0 + yy) * cw + x0 + xx
            if d < vx_depth[j]:
                vx_depth[j] = d
                vx_cols[j] = c
                vx_mat[j] = m
    vx_box = int4 { box.x - 1, box.y - 1, box.z + 1, box.w + 1 }  // (the outline round it)
    for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
        let px = vx_box.x + xx
        let py = vx_box.y + yy
        let j = py * cw + px
        if vx_mat[j] >= 0:
            // a softer line where this pixel stands well in front of the one beside it (a limb across the body)
            var c = vx_cols[j]
            for([ 1, -1, cw, -cw ]) dj:
                if vx_mat[j + dj] >= 0 and vx_depth[j + dj] > vx_depth[j] + 5.0: c = vx_cols[j] * 0.72
            vx_out[j] = float4 { c.x, c.y, c.z, 1.0 }
        else:
            for([ 1, -1, cw, -cw ]) dj:
                let q = j + dj
                if q >= 0 and q < cw * ch and vx_mat[q] >= 0:
                    let m = vx_mat[q]
                    let c = if m == vx_mat_team: float3 { 0.22, 0.07, 0.06 } else: vx_mat_cols[m] * 0.3
                    vx_out[j] = float4 { c.x, c.y, c.z, 1.0 }
    return vx_out

// One facing's shadow on the ground (the sun's, as the world's props and buildings cast it): a cell of its own, drawn
// under every unit. vx_SCELL wide and high round vx_SANCHOR; drawn in vx_sbox; reused by the next call.
let vx_SCELL = int2 { vx_CELL.x * 2, vx_CELL.y }
let vx_SANCHOR = int2 { vx_SCELL.x / 2 - int(14.0 * vx_RES), vx_SCELL.y - int(30.0 * vx_RES) }
let vx_SHADOW = float4 { 0.05, 0.04, 0.02, 0.5 }
var vx_sout = []::float4
var vx_sbox = int4_0

def vx_ground_shadow(sh:vx_shape, facing:int) -> [float4]: return vx_ground_shadow_in(sh, facing, vx_SCELL.x, vx_SCELL.y, vx_SANCHOR)

def vx_ground_shadow_in(sh:vx_shape, facing:int, cw:int, ch:int, anchor:int2) -> [float4]:
    let yaw = float(facing) * 45.0
    let rot = fn(v:float3) -> float3: float3 { v.x * cos(yaw) - v.y * sin(yaw), v.x * sin(yaw) + v.y * cos(yaw), v.z }
    let ru = rot(float3 { 1.0, 0.0, 0.0 })
    let rv = rot(float3 { 0.0, sin(vx_ELEV), cos(vx_ELEV) })
    let sun = rot(vx_SUN)
    if vx_sout.length != cw * ch: vx_sout = map(cw * ch): float4_0
    else:
        for(vx_sbox.w - vx_sbox.y + 1) yy: for(vx_sbox.z - vx_sbox.x + 1) xx: vx_sout[(vx_sbox.y + yy) * cw + vx_sbox.x + xx] = float4_0
    var box = int4 { cw, ch, -1, -1 }
    for(sh.pos) v:
        let p = float(v) + float3_1 * 0.5
        if p.z < 3.0:  // a contact shadow under what touches the ground, a few px thick: the game draws a baked px
            // at 0.55 world px, nearest sampled, so a sliver under the soles vanished and units read as floating
            let u0 = dot(float3 { p.x, p.y, 0.0 }, ru)
            let w0 = dot(float3 { p.x, p.y, 0.0 }, rv)
            for(7) yy: for(13) xx:
                let dx = float(xx - 6)
                let dy = float(yy - 2)
                if dx * dx / 36.0 + (dy - 1.0) * (dy - 1.0) / 9.0 <= 1.0:
                    let x = int(floor(float(anchor.x) + u0 + dx))
                    let y = int(floor(float(anchor.y) - w0 + dy))
                    if x >= 0 and y >= 0 and x < cw and y < ch:
                        vx_sout[y * cw + x] = vx_SHADOW
                        box = int4 { min(box.x, x), min(box.y, y), max(box.z, x), max(box.w, y) }
        let g = p - sun * (p.z / sun.z)
        let u = dot(g, ru)
        let w = dot(g, rv)
        let x0 = max(0, int(floor(float(anchor.x) + u - 0.7)))
        let y0 = max(0, int(floor(float(anchor.y) - w - 0.7)))
        let x1 = min(cw - 1, x0 + 1)
        let y1 = min(ch - 1, y0 + 1)
        box = int4 { min(box.x, x0), min(box.y, y0), max(box.z, x1), max(box.w, y1) }
        for(y1 - y0 + 1) yy: for(x1 - x0 + 1) xx: vx_sout[(y0 + yy) * cw + x0 + xx] = vx_SHADOW
    vx_sbox = box
    return vx_sout

// A facing drawn into an image at (cx, cy), its ground shadow under it when shadows are on.
// Does the unit stand in its shadow, as the game draws it (a baked px at k world px, nearest sampled, the anchor at a
// sub-pixel offset ph)? A unit over a gap reads as floating (Dominic, 2026-11-01: "they're floating"). Standing (every
// foot planted): at least half its soles (its pixels with nothing under them in its lowest 2 rows) have shadow showing
// straight under them. Walking (a foot may swing free): some sole in its lowest 6 rows does.
def vx_stands(cell:[float4], sc:[float4], k:float, ph:float, standing:bool) -> bool:
    let n = 70  // world px round the anchor each way
    let um = map(n * 2 * n * 2): false
    let sm = map(n * 2 * n * 2): false
    for(n * 2) j: for(n * 2) i:
        let bx = int(floor(float(vx_ANCHOR.x) + (float(i - n) + 0.5 - ph) / k))
        let by = int(floor(float(vx_ANCHOR.y) + (float(j - n) + 0.5 - ph) / k))
        if bx >= 0 and by >= 0 and bx < vx_CELL.x and by < vx_CELL.y: um[j * n * 2 + i] = cell[by * vx_CELL.x + bx].w > 0.0
        let sx = bx - vx_ANCHOR.x + vx_SANCHOR.x
        let sy = by - vx_ANCHOR.y + vx_SANCHOR.y
        if sx >= 0 and sy >= 0 and sx < vx_SCELL.x and sy < vx_SCELL.y: sm[j * n * 2 + i] = sc[sy * vx_SCELL.x + sx].w > 0.0
    var low = -1
    for(n * 2) j: for(n * 2) i: if um[j * n * 2 + i]: low = max(low, j)
    var soles = 0
    var shaded = 0
    for(if standing: 2 else: 6) r: for(n * 2) i:
        let j = low - r
        if j >= 0 and j + 2 < n * 2 and um[j * n * 2 + i] and not um[(j + 1) * n * 2 + i]:
            soles++
            if sm[(j + 1) * n * 2 + i] or (sm[(j + 2) * n * 2 + i] and not um[(j + 2) * n * 2 + i]): shaded++
    return if standing: soles > 0 and shaded * 2 >= soles else: shaded > 0

def vx_draw(sh:vx_shape, facing:int, img:[float3], iw:int, cx:int, cy:int):
    if vx_shadows:
        let sc = vx_ground_shadow(sh, facing)
        let ox = cx + vx_ANCHOR.x - vx_SANCHOR.x
        let oy = cy + vx_ANCHOR.y - vx_SANCHOR.y
        for(vx_sbox.w - vx_sbox.y + 1) yy: for(vx_sbox.z - vx_sbox.x + 1) xx:
            let c = sc[(vx_sbox.y + yy) * vx_SCELL.x + vx_sbox.x + xx]
            let x = ox + vx_sbox.x + xx
            let y = oy + vx_sbox.y + yy
            if c.w > 0.0 and x >= 0 and x < iw and y >= 0 and y * iw < img.length:
                let j = y * iw + x
                img[j] = img[j] * (1.0 - c.w) + xyz(c) * c.w
    let cell = vx_cell(sh, facing)
    for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
        let c = cell[(vx_box.y + yy) * vx_CELL.x + vx_box.x + xx]
        if c.w > 0.0: img[(cy + vx_box.y + yy) * iw + cx + vx_box.x + xx] = xyz(c)
