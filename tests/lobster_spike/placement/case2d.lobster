// ------------------------------------------------------------------ one unit through the 2D check (projection_check.gd check_case,
// composite_2d.gd, work_2d.gd)
// Each unit composed in every facing and pose, its parts baked first where they aren't (the composer reads the bakes'
// rigs while it builds), then the layering and truth rules (placement/projection.lobster), and:
//   B6 walk steps: walking, each hip's leg is drawn, in the walk step the 3D rig has for that phase.
//   every drawn part is checked: each sprite in the view belongs to the unit, a member the checks composed, or the
//      engine.
//   C4 depth order (an engine): where the composite's 3D truth (one flat id per member) shows a member, no other
//      member's sprite is drawn over it.
//   K1-K5 a fused mount's kneel at work (work_2d.gd): the fore legs fold, the shins lie back along the ground and
//      hang from their knees, the hind hooves stay planted, nothing below the ground line.

// The parts a view wears that aren't baked: baked now. Whether any were.
def bake_view(n:VNode) -> bool:
    var made = false
    let parts = []::VNode
    part_nodes2(n, parts)
    for(parts) pn:
        let key = bake_key(pn.part_id, pn.pshapes, pn.cols)
        let cols = pn.cols
        if cols and not bakes.get(key):
            step2("  bake {pn.part_id}")
            if bake_model_part(pn.part_id, key, cols): made = true
    return made

def part_nodes2(n:VNode, out:[VNode]) -> void:
    if n.part and n.part_id != "": out.push(n)
    for(n.kids) k: part_nodes2(k, out)

// A unit composed in facing k and posed (its parts baked first: then composed again, on their rigs).
def compose(r:JV, k:int, pose:Pose2) -> UV:
    step2("compose f{k} {pose.name}")
    var v = compose_once(r, k, pose)
    step2("  composed")
    var tries = 0
    while bake_view(v.node) and tries < 4:   // (a part baked can bring others: its rig sets what the composer picks)
        step2("  baked")
        free_tree(v.node)
        v = compose_once(r, k, pose)
        tries++
    return v

def compose_once(r:JV, k:int, pose:Pose2) -> UV:
    let v = uv_new()
    v.facing_k = k
    if pose.body_pose != "": v.body_pose = pose.body_pose
    uv_build(v, r, check_team, 10)
    v.idle_wait = 1000.0
    if is_work(pose): v.job = pose.name
    v.walking = pose.walking
    v.phase = pose.phase
    uv_process(v, 0.0)
    v.walking = false
    return v

def is_work(pose:Pose2) -> bool: return exists(WORK_POSES) w: w.name == pose.name

// Composes one unit in every facing and pose and checks it. tweak (fixtures): which old configuration to put back
// on each view after it's composed (-1: none).
var case_tweak = -1
var debug2d = false   // (each unit's parts, facing 0 standing; and a trail of each step in /tmp/aoa_placement_trail.txt)
var trail2 = ""
def step2(s:string):
    if debug2d:
        trail2 += s + "\n"
        write_file("/tmp/aoa_placement_trail.txt", trail2, 0, 1)

def check_case2d(label:string, r:JV) -> void:
    write_file("/tmp/aoa_placement_at.txt", label + "\n", 0, 1)   // (the unit being checked: where a crash was)
    let poses = copy(POSES2)
    if not has(r, "crew") and not has(r, "mount") and gstr(get(lib_creatures, gstr(r, "creature", "")) or jobj(), "gait", "") == "hop":
        append_into(poses, HOP_POSES)   // (a hopper on the ground: crouched to leap, squashed landing)
    if gstr(r, "slot", "") == "worker" and not has(r, "crew"): append_into(poses, WORK_POSES)
    if not has(r, "crew"):
        var walker = rstr(r, "body")
        if has(r, "mount"):
            let mc = at(lib_creatures, rstr(at(r, "mount"), "creature"))
            walker = if gbool(at(r, "mount"), "fused", false): gstr(mc, "fused_body", rstr(mc, "body")) else: gstr(mc, "mount_body", rstr(mc, "body"))
        for(idle_poses_of(r, walker)) bp:
            let p = Pose2 { bp, false, 0.0 }
            p.body_pose = bp
            poses.push(p)
    for(8) k:
        let stands = dictionary<string, dictionary<string, IMap>>(7)   // per member ("" the unit): rig -> its legs' standing lows
        let stand = dictionary<string, IMap>(7)
        stands.set("", stand)
        for(poses) pose:
            let v = compose(r, k, pose)
            if case_tweak >= 0:
                tweak2(case_tweak, v, pose.name)
                sort_layers(v.node)
            step2("  checking")
            if has(r, "crew"):
                if not pose.walking: check_crew(v, label, "f{k}")
                check_engine_view(v, label, k, r, stands, pose)
            else:
                let view = "f{k} {pose.name}"
                if debug2d and k == 0 and pose.name == "stand":
                    for(parts2(v)) p: print "  {label} {view}: {p.kind} {p.rig} {p.id} {p.cells.keys.length} px" + (if p.unbaked: " UNBAKED" else: "")
                check_view(v, label, view, k, r, stand)
                if is_work(pose): check_work(v, label, view, k)
                if pose.walking: walk_legs(v, label, view, r, pose.phase)
                coverage(v, label, view)
            free_tree(v.node)
    rig_clear()
    if has(r, "crew") and has(part(rstr(r, "body")), "legs"): check_case2d(label, beast_recipe(r))   // (a war beast walks: its legs and head as any creature's)

// A composite (engine) view: its members posed like the engine (walking with it, but those riding on top), checked
// as units, then the depth order.
def check_engine_view(v:UV, label:string, k:int, r:JV, stands:dictionary<string, dictionary<string, IMap>>, pose:Pose2):
    let view = "f{k} {pose.name}"
    for(v.crew) m:
        m.walking = pose.walking and not m.crew_top
        m.phase = pose.phase
        uv_process(m, 0.0)
        m.walking = false
    bake_view(v.node)   // (the members' walk steps: legs the standing compose didn't wear)
    for(v.crew) m:
        let key = "member " + m.crew_socket
        var st = stands.get(key)
        if not st:
            let first = dictionary<string, IMap>(7)
            stands.set(key, first)
            st = first
        let mst = st
        if mst: check_view(m, label, "f{k} {m.crew_socket} {pose.name}", m.facing_k, m.recipe, mst)
        if pose.walking and not m.crew_top: walk_legs(m, label, "f{k} {m.crew_socket} {pose.name}", m.recipe, pose.phase)
    if not pose.walking: depth_order(v, label, view, k, r)
    coverage(v, label, view)

// B6 walk steps: each hip's leg drawn, in the 3D rig's walk step for this phase.
def walk_legs(v:UV, label:string, view:string, r:JV, phase:float):
    if v.flying or v.gait.hops: return
    let rp = RigPose {}
    rp.walk = phase
    let a = rig_unit(r, rp)
    let want = filter(a.pieces) p: p.kind == "leg" and p.rig == a.walker
    insertion_sort(want) x, y: x.anchor < y.anchor
    let got = filter(v.legs) l: not l.cling and not under(v.seat_node, l.node)
    let bad = []::string
    if want.length != got.length: bad.push("{got.length} legs drawn, {want.length} hips")
    for(min(want.length, got.length)) i:
        let n = got[i].node
        let id = tokenize(n.part_id, "~", "")[0]
        if id != want[i].id: bad.push("hip {i}: {id} drawn, {want[i].id} in 3D")
        if not n.visible or n.alpha < 0.5 or not bakes.get(draw_key(n)): bad.push("hip {i}: {id} not drawn")
    rig_clear()
    note("B6 every hip\'s leg in every walk step", label, view, bad.length > 0, concat_string(bad.slice(0, min(3, bad.length)), "; "))

// Whether n is under a (a is an ancestor of n).
def under(a:VNode?, n:VNode) -> bool:
    var p = n.parent
    while p:
        if p == a: return true
        p = p.parent
    return false

// Every sprite in the view is the unit's own, a composed member's, or the engine's.
def coverage(v:UV, label:string, view:string):
    let members = if has(v.recipe, "crew"): map(v.crew) m: m.node else: []::VNode
    let stray = []::string
    coverage_walk(v, v.node, members, stray)
    note("every drawn part is checked", label, view, stray.length > 0, "unchecked: " + concat_string(stray.slice(0, min(3, stray.length)), ", "))

def coverage_walk(v:UV, n:VNode, members:[VNode], stray:[string]) -> void:
    for(n.kids) c:
        if c.visible:
            // (a part's view: the nearest member above it, else the unit's own; nothing else composes views)
            if c.part and not under(v.node, c): stray.push(c.part_id)
            coverage_walk(v, c, members, stray)

// C4: who is in front, against the composite's 3D truth (one flat id per member).
let C4_SLACK = 6
let C4_SHARE = 0.08

def depth_order(v:UV, label:string, view:string, k:int, r:JV):
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), check_team)
    let es = rig_spec(rstr(r, "body"), colours)
    if not es: return
    let ms = members(r, es.sockets)
    let pieces = [TPiece { es.node, XF_ID, 0 }]
    if has(part(rstr(r, "body")), "legs"):   // (a war beast's legs and head, baked apart: the beast's too)
        for(rig_unit(beast_recipe(r), RigPose {}).pieces) p:
            if p.kind != "body": pieces.push(TPiece { p.node, p.xf, 0 })
    for(ms) m, i:
        let rp = RigPose {}
        rp.hold = m.hold
        // (a creature drawn smaller than it's built, on foot: creatures.json draw_scale, the look only)
        let cr = get(lib_creatures, gstr(m.recipe, "creature", ""))
        let ds = if cr and not has(m.recipe, "mount"): float(gint(cr, "draw_scale", 100)) / 100.0 else: 1.0
        let mt = Xform { bscaled_global(m.t.b, float3_1 * ds), m.t.o }
        for(rig_unit(m.recipe, rp).pieces) p: pieces.push(TPiece { p.node, xmul(mt, p.xf), i + 1 })
    rig_clear()
    let truth, size = truth_render(pieces, k)
    let sizes = map(ms.length + 1): 0
    for(truth.keys) c: sizes[iget(truth, c, 0)]++
    // The drawn composite: each cell's topmost member (draw order is tree order), shadows left out.
    let index = dictionary<string, int>(15)
    for(ms) m, i: index.set(m.name, i + 1)
    let top = new_imap()
    draw_cells(v, v.node, XF_ID2, 0, index, top)
    if debug2d: dump_owners(truth, top, "/tmp/aoa_c4_f{k}.ppm")
    let over = dictionary<string, int>(31)
    let over_keys = []::string
    for(truth.keys) c:
        let want = iget(truth, c, -1)
        if ihas(top, c) and iget(top, c, -1) != want:
            let u = cunkey(c)
            var inner = true
            for([int2 { 1, 0 }, int2 { -1, 0 }, int2 { 0, 1 }, int2 { 0, -1 }, int2 { 2, 0 }, int2 { -2, 0 }, int2 { 0, 2 }, int2 { 0, -2 }]) d:
                inner = inner and iget(truth, ckey(u.x + d.x, u.y + d.y), -1) == want
            if inner:
                let key = "{iget(top, c, -1)}>{want}"
                if over.get(key, -1) < 0: over_keys.push(key)
                over.set(key, over.get(key, 0) + 1)
    let names = append(["the engine"], map(ms) m: m.name)
    let bad = []::string
    for(over_keys) key:
        let ab = tokenize(key, ">", "")
        let drawn = string_to_int(ab[0])
        let shown = string_to_int(ab[1])
        // (inside the frame, behind the engine by design: the engine is one sprite, so its far side covers them too)
        if not (drawn == 0 and shown > 0 and ends_with(ms[shown - 1].name, "_in")) and over.get(key, 0) > max(C4_SLACK, int(C4_SHARE * float(sizes[shown]))):
            bad.push("{names[drawn]} drawn over {names[shown]} by {over.get(key, 0)} px")
    note("C4 composite members drawn in depth order", label, view, bad.length > 0, concat_string(bad, "; "))

def draw_cells(v:UV, n:VNode, t:[float], owner:int, index:dictionary<string, int>, top:IMap) -> void:
    for(n.kids) c:
        if c.visible:
            let ct = xf_mul(t, xf_local(c))
            var o = owner
            if n == v.bob:
                for(v.crew) m:
                    if m.node == c: o = index.get(m.crew_socket, 0)
            if c.part and not (c == v.shadow or exists(v.crew) m: m.shadow == c):
                let key = draw_key(c)
                let b = bakes.get(key)
                if b:
                    for(pixels_of(key).pts) q:
                        let p = xf_apply(ct, q)
                        iset(top, ckey(int(floor(p.x * b.scale)), int(floor(p.y * b.scale))), o)
            draw_cells(v, c, ct, o, index, top)

// ---- at work: a fused mount's kneel (work_2d.gd)

let KNEEL_LEGS = 4   // a body kneels on four or more legs

def check_work(v:UV, label:string, view:string, k:int):
    let r = v.recipe
    if not (has(r, "mount") and gbool(at(r, "mount"), "fused", false) and v.legs.length >= KNEEL_LEGS and v.kneel > 0.0): return
    let cam = camera(k)
    let back = -project(float3 { 20.0, 0.0, 0.0 }, cam)   // (the model's tail end, from its middle, on screen)
    let mc = at(lib_creatures, rstr(at(r, "mount"), "creature"))
    let body_id = gstr(mc, "fused_body", rstr(mc, "body"))
    let colours = colours_for(rstr(at(r, "mount"), "skin"), rstr(r, "family"), check_team)
    let bs = rig_spec(body_id, colours)
    if not bs: return
    let hips = map(bs.anchors) a: a.pos
    var mid = 0.0
    for(hips) h: mid += h.x / float(hips.length)
    var ground = -1000000.0   // (the standing ground line: the lowest leg's lowest pixel, standing)
    let stand_low = map(v.legs) leg: lowest_at(cells_xf(leg.node, standing_xf(v, leg)))
    for(stand_low) s: ground = max(ground, s.y)
    for(v.legs) leg, li:
        let hip = hip_of(v, leg, k, hips)
        let fore = hip.x > mid
        let shin = leg.shin
        let folded = shin != nil and (shin or leg.node).visible
        note("K1 a kneel folds the fore legs", label, view, folded != fore,
             (if fore: "fore" else: "hind") + " leg (hip x {f1(hip.x)}) " + (if folded: "folded" else: "straight"))
        let cells = cells_xf(leg.node, xf_mul(to_unit(leg.node, v), xf_local(leg.node)))
        if shin and folded:
            let st = cells_xf(shin, xf_mul(to_unit(shin, v), xf_local(shin)))
            let t = xf_mul(to_unit(shin, v), xf_local(shin))
            let along = float2 { t[2], t[3] }   // (the shin's own length, knee to hoof: its y axis on screen)
            note("K2 a folded shin lies back along the ground", label, view, dot(normalize(along), normalize(back)) < 0.3,
                 "shin {normalize(along)}, back {normalize(back)}")
            let gap = cells_gap(cells, st)
            note("K3 a shin hangs from its knee", label, view, gap > 1.5, "{f1(gap)} px from its leg")
            for(st.keys) c: iset(cells, c, 1)
        else:
            let low = lowest_at(cells)
            note("K4 kneeling, the hind hooves stay planted", label, view, magnitude(low - stand_low[li]) > float(FOOT_PX),
                 "{leg.node.part_id} lowest pixel {low}, standing {stand_low[li]}")
        note("K5 kneeling, nothing below the ground", label, view, lowest_at(cells).y > ground + float(FOOT_PX),
             "{leg.node.part_id} down to {int(lowest_at(cells).y)}, the ground line {int(ground)}")

// Where a leg stands: the unit's own transform with the bob at rest and the leg straight, at its reach.
def standing_xf(v:UV, leg:Leg) -> [float]:
    let root = leg.node.parent
    let t = [leg.node.scl.x, 0.0, 0.0, leg.reach, leg.rest.x, leg.rest.y]
    return xf_mul(xf_mul(xf_local(v.visual), if root: xf_local(root) else: XF_ID2), t)

// The 3D hip a leg is drawn at: the facing's projected anchor at its rest position (the bake's own order).
def hip_of(v:UV, leg:Leg, k:int, hips:[float3]) -> float3:
    let root = leg.node.parent
    if root:
        for(root.kids) c:
            if c.part and not c.front and gstr(part(base_id(c.part_id)), "slot", "") == "body":
                let anchors = glist(rig(c.part_id + facing_suffix(k)), "anchors")
                for(anchors) a, i:
                    if magnitude(float2 { as_float(a.a[0]), as_float(a.a[1]) } - leg.rest) < 0.01 and i < hips.length: return hips[i]
    assert false   // (work2d: no anchor at the leg's rest)
    return float3_0

def cells_xf(n:VNode, t:[float]) -> IMap:
    let cells = new_imap()
    let key = draw_key(n)
    let b = bakes.get(key)
    if b:
        for(pixels_of(key).pts) q:
            let p = xf_apply(t, q)
            iset(cells, ckey(int(floor(p.x * b.scale)), int(floor(p.y * b.scale))), 1)
    return cells

// The lowest cell (the middle of the lowest row).
def lowest_at(cells:IMap) -> float2:
    var y = -(1 << 20)
    for(cells.keys) c: y = max(y, cunkey(c).y)
    var xs = 0.0
    var n = 0
    for(cells.keys) c:
        if cunkey(c).y == y:
            xs += float(cunkey(c).x)
            n++
    return float2 { xs / max(float(n), 1.0), float(y) }

def cells_gap(a:IMap, b:IMap) -> float:
    var best = 1000000.0
    for(b.keys) p:
        for(a.keys) q:
            best = min(best, magnitude(float(cunkey(p)) - float(cunkey(q))))
            if best <= 1.0: return best
    return best

// Fixtures' tweaks (placement/fixtures2d.lobster).
def tweak2(which:int, v:UV, pose:string) -> void:
    fixture2_tweak(which, v, pose)

// (debug: the 3D truth's owners left, the drawn owners right, as a picture)
def dump_owners(truth:IMap, top:IMap, file:string):
    var lo = int2 { 1000000, 1000000 }
    var hi = int2 { -1000000, -1000000 }
    for(append(truth.keys, top.keys)) c:
        let u = cunkey(c)
        lo = min(lo, u)
        hi = max(hi, u)
    let w = hi.x - lo.x + 1
    let h = hi.y - lo.y + 1
    let pal = [[40, 40, 40], [230, 60, 60], [60, 200, 60], [60, 90, 230], [230, 200, 40], [200, 60, 200], [60, 200, 200], [255, 255, 255]]
    var out = "P3\n{w * 2 + 4} {h}\n255\n"
    for(h) y:
        for(w * 2 + 4) x:
            let side = if x < w: truth elif x >= w + 4: top else: nil
            if side:
                let c = ckey(lo.x + (if x < w: x else: x - w - 4), lo.y + y)
                let o = iget(side, c, -1)
                let col = if o < 0: [0, 0, 0] else: pal[min(o + 1, 7)]
                out += "{col[0]} {col[1]} {col[2]} "
            else: out += "128 128 128 "
        out += "\n"
    write_file(file, out, 0, 1)
