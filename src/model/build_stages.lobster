// A building under construction (ArtKit._hold_back), from its finished model: its four stages, parts held back by
// height and a scaffold round it. Kept apart from the baker (game/art_kit_buildings) so a check can build the stages
// without a window (site_stage_check, #155).
// Needs (imported before this file): model/kit, model/base, model/buildings (beam, bm).

let AKB_BUILD_STAGES = [ 0.15, 0.4, 0.45, 0.72 ]

class AkbBox:
    node:MNode
    lo:float3
    hi:float3

// A part's own mesh m as a world box (t: its transform).
def akb_box(node:MNode, m:MMesh, t:Xform) -> AkbBox:
    var lo = float3_1 * 1000000000.0
    var hi = float3_1 * -1000000000.0
    for(m.p) q:
        lo = min(lo, q)
        hi = max(hi, q)
    var blo = float3_1 * 1000000000.0
    var bhi = float3_1 * -1000000000.0
    for(8) c:
        let corner = xf(t, float3 { if c & 1: hi.x else: lo.x, if c & 2: hi.y else: lo.y, if c & 4: hi.z else: lo.z })
        blo = min(blo, corner)
        bhi = max(bhi, corner)
    return AkbBox { node, blo, bhi }

def akb_boxes(node:MNode, t:Xform, out:[AkbBox]) -> void:
    let m = node.mesh
    if m and m.p.length: out.push(akb_box(node, m, t))
    for(node.kids) k: akb_boxes(k, xmul(t, node_xform(k)), out)

// The parts drawn (a hidden part hides what hangs on it), as world boxes.
def akb_seen(node:MNode, t:Xform, out:[AkbBox]) -> void:
    if not node.visible: return
    let m = node.mesh
    if m and m.p.length: out.push(akb_box(node, m, t))
    for(node.kids) k: akb_seen(k, xmul(t, node_xform(k)), out)

def akb_touch_xz(a:AkbBox, b:AkbBox) -> bool:
    return a.lo.x < b.hi.x + 0.02 and b.lo.x < a.hi.x + 0.02 and a.lo.z < b.hi.z + 0.02 and b.lo.z < a.hi.z + 0.02

// Which parts are held up: standing on the ground, or touching a part that's held up, beside it or under it.
def akb_held(seen:[AkbBox], ground:float) -> [bool]:
    let held = map(seen) s: s.lo.y - ground <= 0.05
    var more = true
    while more:
        more = false
        for(seen) s, i:
            if not held[i]:
                for(seen) u, j:
                    if not held[i] and held[j] and u.lo.y <= s.lo.y + 0.01 and u.hi.y >= s.lo.y - 0.03 and akb_touch_xz(u, s):
                        held[i] = true
                        more = true
    return held

// A building under construction: parts held back by height (foundations first, the roof last); what's built reaches
// the height it returns.
def akb_hide(body:MNode, stage:int) -> float:
    let cut = AKB_BUILD_STAGES[stage]
    let boxes = []::AkbBox
    for(body.kids) k: akb_boxes(k, node_xform(k), boxes)
    var alo = float3_1 * 1000000000.0
    var ahi = float3_1 * -1000000000.0
    for(boxes) b:
        alo = min(alo, b.lo)
        ahi = max(ahi, b.hi)
    let h = ahi.y - alo.y
    // (the roof goes on last, the way a real site goes up: its parts, and anything from its eaves up, wait for the end)
    var eave = 1000000000.0
    for(boxes) b:
        if find_string(b.node.meta, "roof") >= 0: eave = min(eave, b.lo.y)
    var top = 0.0
    for(boxes) b:
        let at = (if stage < 2: b.hi.y else: (b.lo.y + b.hi.y) * 0.5) - alo.y
        // (before its walls: nothing that hangs on them, a lit window or a door's studs low enough to pass, floating)
        let m = b.node.mat
        let lit = m and (m.unshaded or m.emission != float3_0)
        let hangs = stage < 2 and (lit or (b.lo.y - alo.y > 0.15 * h and b.hi.y - b.lo.y < 0.25 * h))
        let roofed = find_string(b.node.meta, "roof") >= 0 or b.lo.y >= eave - 0.01
        if at > cut * h or hangs or roofed: b.node.visible = false
    // (and nothing left hanging in the air: a part whose support is held back waits too)
    var dropped = true
    while dropped:
        dropped = false
        let seen = []::AkbBox
        for(body.kids) k: akb_seen(k, node_xform(k), seen)
        let held = akb_held(seen, alo.y)
        for(seen) b, i:
            if not held[i]:
                b.node.visible = false
                dropped = true
    let seen = []::AkbBox
    for(body.kids) k: akb_seen(k, node_xform(k), seen)
    for(seen) b: top = max(top, b.hi.y)
    return top

// ...and a scaffold of poles and rails round the footprint up to just above what's built.
def akb_hold_back(body:MNode, stage:int):
    let top = akb_hide(body, stage)
    var alo = float3_1 * 1000000000.0
    var ahi = float3_1 * -1000000000.0
    let boxes = []::AkbBox
    for(body.kids) k: akb_boxes(k, node_xform(k), boxes)
    for(boxes) b:
        alo = min(alo, b.lo)
        ahi = max(ahi, b.hi)
    let wood = bm("wood")
    let lo = float3 { alo.x - 0.04, 0.0, alo.z - 0.04 }
    let hi = float3 { ahi.x + 0.04, 0.0, ahi.z + 0.04 }
    let pole_h = max(top + 0.08, 0.22)
    let posts = []::float3
    for([ 0.0, 0.5, 1.0 ]) fx:
        for([ 0.0, 0.5, 1.0 ]) fz:
            if not (fx == 0.5 and fz == 0.5):
                posts.push(float3 { lo.x + (hi.x - lo.x) * fx, 0.0, lo.z + (hi.z - lo.z) * fz })
    for(posts) q: add_child(body, beam(q, q + float3 { 0.0, pole_h, 0.0 }, 0.016, wood))
    let around = [ posts[0], posts[1], posts[2], posts[4], posts[7], posts[6], posts[5], posts[3] ]
    let levels = if pole_h > 0.3: [ pole_h * 0.5, pole_h - 0.03 ] else: [ pole_h - 0.03 ]
    for(levels) y:
        for(around) a, k:
            let c = around[(k + 1) % around.length]
            add_child(body, beam(a + float3 { 0.0, y, 0.0 }, c + float3 { 0.0, y, 0.0 }, 0.011, wood))
