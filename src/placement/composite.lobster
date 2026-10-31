// ------------------------------------------------------------------ the 3D rules for composites (tests/placement/composite_3d.gd)
// A composite is more than one body drawn as one unit: a siege engine and its crew (the recipe's `crew`, one worker
// per crew socket), a cart and the beasts hauling it (the recipe's `haul`, one beast per haul socket). Standing and
// at every walk step (crew and haulers walk while the engine rolls; crew riding on top don't):
//   C1 members apart: no member inside another beyond contact; a hauler not inside the engine but where its harness
//      meets the shafts; crew in their engine at most CREW_IN of themselves.
//   C2 hitched: every haul<n> socket has its hitches (hitch<n>_near, hitch<n>_far) on the engine; the hauler wears a
//      harness with trace ends (trace_near, trace_far), each on its hitch within HITCH_TOL.
//   C3 no loose ends: every rope of the engine (a rod whose material is a rope) ends on something at both ends: the
//      rest of the engine, a member, or the ground.
// And each member is checked as a unit of its own (A1 to A4) under the composite's label.

let CREW_IN = 0.12         // a crew member at most this share inside its engine
let HITCH_TOL = 1.5        // a harness's trace end within this of its hitch on the cart, standing...
let HITCH_WALK_TOL = 2.5   // ...and walking (the beast rides on its planted foot, the cart doesn't)
let HITCH_R = 3.0          // a hauler may meet its engine only this near a hitch
let THIN = 0.6             // (a rope this thin or thinner: thicker is a pole)
let LOOSE_TOL = 1.0        // ...ends within this of something (beyond the rod's own radius)
let HARNESS_OFF = 1.5      // a harness hugs its wearer: at most HARNESS_OFF_SHARE of it more than HARNESS_OFF off the
let HARNESS_OFF_SHARE = 0.1   // body, leaving out the trace tails behind the rump

class Member:
    name:string                      // its socket
    recipe:JV
    t:Xform                          // on its socket, turned to its facing
    hold:string
    top:bool
    hauls:bool
    box:bool                         // in a walled howdah: its legs not drawn (D-176)

def engine_turn(name:string) -> int:
    var turn = 0
    for(tokenize(name, "_", "")) w:
        if starts_with(w, "f") and w.length == 2: turn = string_to_int(substring(w, 1, 1))
    return turn

// Every member of an engine as the composer puts it together.
def members(r:JV, sockets:dictionary<string, float3>) -> [Member]:
    let out = []::Member
    let sj = jobj()
    for(sockets.get_keys()) k: set(sj, k, jint(1))
    let names = sorted_strs(engine_sockets(r, sj))
    for(names) name:
        let hauls = starts_with(name, "haul")
        var held = "low"
        var top = false
        for(tokenize(name, "_", "")) w:
            if has_s(WORK_HOLDS, w): held = w
            elif w == "top" or w == "box": top = true
        let recipe = if hauls: haul_recipe(r) else: crew_recipe(r, held)
        let s = float(gint(recipe, "scale", 100)) / 100.0   // (a tiny race's crew are drawn tiny)
        var t = Xform { bscaled_global(axis_angle(float3 { 0.0, 1.0, 0.0 }, -45.0 * float(engine_turn(name))), float3_1 * s), sockets.get(name, float3_0) }
        if not top:   // (standing back by its lean, UnitView._build_engine: a frog crew, creatures.json crew_back)
            t = Xform { t.b, t.o - bxf(t.b, float3 { float(gint(gobj(lib_creatures, gstr(recipe, "creature", "")), "crew_back", 0)), 0.0, 0.0 }) }
        out.push(Member { name, recipe, t, if hauls: "" else: held, top, hauls, ends_with(name, "_box") })
    return out

// The engine's voxels, standing: a war beast's with its legs at its hips and its head on its neck (baked apart).
def engine_whole(r:JV, es:Spec) -> Vox:
    let ev = voxels(es.node, XF_ID)
    if has(part(rstr(r, "body")), "legs"):
        for(rig_unit(beast_recipe(r), RigPose {}).pieces) p:
            if p.kind != "body": voxels_into(p.node, p.xf, ev)
    return ev

def member_vox(m:Member, a:Rigged) -> Vox:
    let v = new_vox()
    for(a.pieces) p:
        if not (m.box and p.kind == "leg"): voxels_into(p.node, xmul(m.t, p.xf), v)
    return v

// Runs the composite rules on an engine recipe.
def check_composite(label:string, r:JV):
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), float3 { 1.0, 0.0, 1.0 })
    let es = rig_spec(rstr(r, "body"), colours)
    if not es: return
    let ev = engine_whole(r, es)
    let sockets = es.sockets
    let ms = members(r, sockets)
    loose_ends(label, es, ev, ms)
    for(ms) m:
        if m.hauls:
            let hn = tokenize(m.name, "_", "")[0]
            let n = substring(hn, 4, hn.length - 4)
            for(["near", "far"]) side:
                let h = "hitch{n}_{side}"
                note("C2 a hauler\'s hitches on the cart", label, m.name, not shas(sockets, h), "no {h} socket")
                if shas(sockets, h):
                    let d = vdepth(ev, sockets.get(h, float3_0), 4.0)
                    note("C2 a hauler\'s hitches on the cart", label, m.name, d > 1.0, "{h} {f1(d)} off the cart (the shafts don\'t reach it)")
            let torso = gstr(at(m.recipe, "parts"), "torso", "")
            note("C2 a hauler wears its harness", label, m.name, torso == "" or not has_s(ptags_of(torso), "harness"),
                 "{rstr(m.recipe, "creature")} hauls with " + (if torso == "": "nothing on" else: torso))
    for(WALK_PHASES + 1) i:
        let walk = if i == 0: -1.0 else: 2.0 * MPI * float(i - 1) / float(WALK_PHASES)
        composite_pose(label, if i == 0: "stand" else: "walk {i - 1}", walk, sockets, ev, ms)
    rig_clear()
    // Each member as a unit of its own (its legs, feet, gear, a hauler's harness), once per recipe.
    let seen = []::string
    for(ms) m:
        let sig = stringify(m.recipe)
        if not has_s(seen, sig):
            seen.push(sig)
            check_unit(label, m.recipe)

// One pose of the whole composite: members apart (C1), harness on hitch (C2).
def composite_pose(label:string, view:string, walk:float, sockets:dictionary<string, float3>, ev:Vox, ms:[Member]):
    let vox = []::Vox
    let hitches = []::float3
    for(sockets.get_keys()) h:
        if starts_with(h, "hitch"): hitches.push(sockets.get(h, float3_0))
    for(ms) m:
        let rp = RigPose {}
        rp.hold = m.hold
        if not m.top: rp.walk = walk
        let a = rig_unit(m.recipe, rp)
        let v = member_vox(m, a)
        vox.push(v)
        if m.hauls:
            let hn = tokenize(m.name, "_", "")[0]
            let n = substring(hn, 4, hn.length - 4)
            var harness:Piece? = nil
            for(a.pieces) p:
                if p.kind == "armour" and shas(p.sockets, "trace_near"): harness = p
            for(["near", "far"]) side:
                let h = "hitch{n}_{side}"
                if harness and shas(sockets, h):   // (else C2's other rules say so)
                    let at_ = xf(m.t, xf(harness.xf, harness.sockets.get("trace_" + side, float3_0)))
                    let d = magnitude(at_ - sockets.get(h, float3_0))
                    let tol = if walk < 0.0: HITCH_TOL else: HITCH_WALK_TOL
                    note("C2 the cart hitched to its hauler\'s harness", label, "{m.name} {view}", d > tol, "trace_{side} {f1(d)} from {h}, {f1(tol)} allowed")
            // The hauler clear of the cart, but where the harness meets the shafts.
            var bad = 0
            for(v.keys) q:
                if vhas(ev, q):
                    var far = true
                    for(hitches) hp:
                        if magnitude(vcentre(q) - hp) <= HITCH_R: far = false
                    if far: bad++
            let allowed = PEN_VOX + int(PEN_SHARE * float(min(vcount(v), vcount(ev))))
            note("C1 a hauler clear of its cart", label, "{m.name} {view}", bad > allowed, "{m.name} shares {bad} voxels with the cart away from its hitches, {allowed} allowed")
        else:
            let share = float(vshared(v, ev)) / float(max(vcount(v), 1))
            note("C1 crew not cut through their engine", label, "{m.name} {view}", share > CREW_IN, "{f2(share)} of the crew member inside the engine")
    for(ms.length) i:
        var j = i + 1
        while j < ms.length:
            let common = vshared(vox[i], vox[j])
            let allowed = PEN_VOX + int(PEN_SHARE * float(min(vcount(vox[i]), vcount(vox[j]))))
            note("C1 members of a composite apart", label, "{ms[i].name}/{ms[j].name} {view}", common > allowed,
                 "{ms[i].name} and {ms[j].name} share {common} voxels, {allowed} allowed")
            j++

// C2: a harness hugs its wearer (from the attachment rules for a worn part tagged "harness").
def harness_key(c:float3) -> int: return vkey(int(floor(c.x / HARNESS_OFF)), int(floor(c.y / HARNESS_OFF)), int(floor(c.z / HARNESS_OFF)))

def harness_on_body(label:string, view:string, p:Piece, body:Piece):
    let hv = pvox(p)
    let bv = pvox(body)
    var rear = 1000000.0
    let cells = new_vox()
    for(bv.keys) q:
        let c = vcentre(q)
        rear = min(rear, c.x)
        vadd(cells, harness_key(c))
    let coarse = new_vox()
    for(cells.keys) k:
        let u = vunkey(k)
        for(27) n: vadd(coarse, vkey(u.x + n % 3 - 1, u.y + (n / 3) % 3 - 1, u.z + n / 9 - 1))
    var n = 0
    var off = 0
    for(hv.keys) q:
        let c = vcentre(q)
        if c.x >= rear:
            n++
            if not vhas(coarse, harness_key(c)): off++
    let share = float(off) / float(max(n, 1))
    note("C2 a harness on its hauler\'s body", label, view, share > HARNESS_OFF_SHARE, "{p.id} {f2(share)} of it off the body, {f2(HARNESS_OFF_SHARE)} allowed")

// C3: every rope of the engine ends on something (the rest of the engine, a member standing, the ground).
class Rope:
    node:MNode
    t:Xform
    a:float3
    b:float3
    r:float

def loose_ends(label:string, es:Spec, ev:Vox, ms:[Member]):
    let rods = []::Rope
    find_ropes(es.node, node_xform(es.node), false, rods)
    if not rods.length: return
    let mv = new_vox()
    for(ms) m:
        let rp = RigPose {}
        rp.hold = m.hold
        for(rig_unit(m.recipe, rp).pieces) p: voxels_into(p.node, xmul(m.t, p.xf), mv)
    let loose = []::string
    for(rods) rd:
        let own = voxels(rd.node, rd.t)
        for([rd.a, rd.b]) e:
            let reach = rd.r + LOOSE_TOL
            if not (e.y <= LOOSE_TOL + rd.r or near_cells(ev, own, e, reach) or near_cells(mv, new_vox(), e, reach)):   // (on the ground, or touching)
                loose.push("{if rd.node.meta != "": rd.node.meta else: "rod"} end at ({round(e.x)}, {round(e.y)}, {round(e.z)})")
    note("C3 no loose ends", label, "stand", loose.length > 0, "{loose.length} ropes end in the air: {concat_string(loose.slice(0, min(3, loose.length)), ", ")}")

// Something of `cells` (not of `own`) within reach of p.
def near_cells(cells:Vox, own:Vox, p:float3, reach:float) -> bool:
    let c = vunkey(vcell(p))
    let n = int(ceiling(reach / GEOM_RES))
    var i = -n
    while i <= n:
        var j = -n
        while j <= n:
            var k = -n
            while k <= n:
                if sqrt(float(i * i + j * j + k * k)) * GEOM_RES <= reach:
                    let q = vkey(c.x + i, c.y + j, c.z + k)
                    if vhas(cells, q) and not vhas(own, q): return true
                k++
            j++
        i++
    return false

// The ropes (a cylinder in a rope material, as the models' rod builds them) under n, in the model's space; a rope
// with its end caps (a rod: a plain node holding the cylinder and two blobs) as the whole rod. t: n's own transform
// in the model's space.
def find_ropes(n:MNode, t:Xform, inner:bool, out:[Rope]) -> void:
    for(n.kids) c:
        let ct = xmul(t, node_xform(c))
        let cm = c.mesh
        let mat = c.mat
        if cm and cm.prim == PRIM_CYLINDER and c.visible and mat and mat.rope:
            let r = max(cm.pp.x, cm.pp.y) * magnitude(ct.b.x)
            if r <= THIN and cm.pp.z * magnitude(ct.b.y) > 4.0 * r:
                let half = bxf(ct.b, float3 { 0.0, cm.pp.z * 0.5, 0.0 })
                let wrapped = not n.mesh and n.kids.length <= 3 and inner
                out.push(Rope { if wrapped: n else: c, if wrapped: xmul(t, xinverse(node_xform(n))) else: t, ct.o - half, ct.o + half, r })
        find_ropes(c, ct, true, out)
