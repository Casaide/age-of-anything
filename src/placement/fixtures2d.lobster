// ------------------------------------------------------------------ regression fixtures for the 2D check (tests/placement/fixtures_2d.gd)
// Each puts back a layering, leg, rider or truth configuration Dominic caught and asserts the check FAILS it with
// the rule that names the bug, then that the unit as it is now passes that rule (the control).

class Fixture2:
    what:string
    label:string
    rules:[string]
    setup:string  // "", "old_truth", "uncut" or "unturned"
    tweak:int     // what fixture2_tweak puts back on each view (-1: nothing)

def fixture2_list() -> [Fixture2]:
    return [
        Fixture2 { "a rider\'s tiny leg ending at the horse\'s spine (the leg at its standing length, not stretched down the barrel)",
                   "human on pony", [ "B6 a rider\'s leg reaches down the flank" ], "", 0 },
        Fixture2 { "a rider\'s leg seen from the far side (the leg a step ahead counted as near: Dominic, \"visible from all sides\")",
                   "human on pony", [ "B6 a rider\'s leg on the flank facing the camera" ], "", 1 },
        Fixture2 { "a mount\'s wings over its body in every facing (a hummingbird\'s blur read as a grey plate: Dominic)",
                   "human on hummingbird", [ "a mount\'s wings over its back, behind it turned away", "back parts behind the body facing the camera" ], "", 2 },
        Fixture2 { "legs drawn over the body (the far legs on top)", "romans spear", [ "far legs behind the body" ], "", 3 },
        Fixture2 { "the frog\'s sword hidden behind its body facing forward", "swamp frogs infantry age 2", [ "weapons and shields show" ], "", 4 },
        Fixture2 { "worn armour carrying a whole copy of its body (the body not cut out of the armour\'s bake)",
                   "sewer rats spear age 2", [ "worn armour holds no body" ], "", 5 },
        Fixture2 { "a walk whose body rose as its legs spread (the feet off the ground mid-stride)",
                   "romans spear", [ "B5 walking, the planted foot on its ground line" ], "", 6 },
        Fixture2 { "a 3D truth with the first leg\'s part at every hip, unturned (a cat\'s hind legs as forelegs)",
                   "frog on newt_fire", [ "B6 the 3D truth has the unit\'s legs, one for one" ], "old_truth", -1 },
        Fixture2 { "newt legs drawn whole over its body (the legs on its back: Dominic)",
                   "frog on newt_fire", [ "legs and head over the body only where the model shows them" ], "uncut", -1 },
        Fixture2 { "newt legs folded up off the ground facing left (the legs not turned to their side: Dominic)",
                   "frog on newt_fire", [ "B5 a near foot in sight", "B5 standing feet on the ground" ], "unturned", -1 },
        Fixture2 { "a centaur\'s kneel to forage picked by screen x and bent as if side-on (from behind: a flank\'s legs folded sideways, the hind end sunk: Dominic, 2026-10-17)",
                   "centaur romans worker", [ "K1 a kneel folds the fore legs", "K2 a folded shin lies back along the ground", "K4 kneeling, the hind hooves stay planted" ], "", 7 },
        Fixture2 { "a hand leading TC1 A\'s beast drawn under it (the hauler layered over every crew member on its side; first the rats\' cat: since rats stand back by their hunch they no longer overlap it, so the forest beetles\' cart carries it)",
                   "composite: forest beetles tc1_a_forest hauled by a beetle", [ "C4 composite members drawn in depth order" ], "", 8 },
        Fixture2 { "the hauling cat\'s near hind leg gone in its walk (a member\'s walk steps were never checked, nor baked)",
                   "composite: sewer rats tc1_a_junk hauled by a cat", [ "B6 every hip\'s leg in every walk step" ], "", 9 },
    ]

// The rules the unit fails (rule -> first failing view) with the fixture's setup and tweak.
def fixture2_rules(f:Fixture2, r:JV, on:bool) -> dictionary<string, string>:
    check_results.clear()
    while check_order.length: check_order.pop()
    if on:
        switch f.setup:
            case "old_truth": old_truth = true
            case "uncut": set(part("body.newt"), "cut", jstrs(filter(gstrs(part("body.newt"), "cut")) c: c != "legs"))
            case "unturned":
                old_bugs.legs_unmirrored = true
                forget_bakes("leg.newt~")
            default: pass()
        case_tweak = f.tweak
    check_case2d(f.label, r)
    case_tweak = -1
    if on:
        switch f.setup:
            case "old_truth": old_truth = false
            case "uncut":
                let cut = gstrs(part("body.newt"), "cut")
                cut.push("legs")
                set(part("body.newt"), "cut", jstrs(cut))
            case "unturned":
                old_bugs.legs_unmirrored = false
                forget_bakes("leg.newt~")
            default: pass()
    truth_cache.clear()
    clear_pixel_caches()
    let out = dictionary<string, string>(63)
    for(check_order) key:
        let fails = check_results.get(key) or []::string
        if fails.length: out.set(tokenize(key, "|", "")[0], fails[0])
    return out

// Every bake whose key holds `word` forgotten, and baked afresh when next drawn (not from the disk cache: an old
// configuration's bake has the same key as today's).
def forget_bakes(word:string):
    for(bakes.get_keys()) k:
        if find_string(k, word) >= 0:
            bakes.del(k)
            frame_at.del("p:" + k)
    bake_cache_dir = ""
    clear_pixel_caches()
    truth_cache.clear()

// [all caught, lines]
def fixtures_2d(cases:[Case]) -> bool, [string]:
    def case_recipe(label:string) -> JV:
        for(cases) c:
            if c.label == label: return c.recipe
        assert false
        return jobj()
    let keep_cache = bake_cache_dir
    var ok = true
    let said = []::string
    for(fixture2_list()) f:
        let r = case_recipe(f.label)
        let bad = fixture2_rules(f, r, true)
        let good = fixture2_rules(f, r, false)
        let caught = filter(f.rules) rule: bad.get(rule) != nil
        let still = filter(caught) rule: good.get(rule) != nil
        let passed = caught.length > 0 and still.length == 0
        ok = ok and passed
        let msg = if caught.length: bad.get(caught[0]) or "" else: "no failure; it fails only {bad.get_keys()}"
        said.push((if passed: "PASS" else: "BROKEN") + " fixture: {f.what}\n      FAILS " + (if caught.length: concat_string(caught, ", ") else: "{f.rules}") +
                  " ({msg})" + (if still.length: "\n      but the control fails too: " + concat_string(still, ", ") else: ""))
    bake_cache_dir = keep_cache
    return ok, said

// ---- the old configurations, put on each composed view

def fixture2_tweak(which:int, v:UV, pose:string) -> void:
    switch which:
        case 0:  // the rider's leg at its standing length and the rider dropped a fixed 6 below the seat ("tiny legs")
            let rg = rig(v.facing_body + facing_suffix(v.facing_k))
            let ss = gobj(rg, "sockets")
            let seat = v.seat_node
            if seat and has(ss, "seat"): seat.pos = v2(at(ss, "seat")) + float2 { 0.0, 6.0 }
            for(v.legs) leg:
                if leg.cling: leg.node.scl = float2 { leg.node.scl.x, 0.6 }  // (the leg before D-173: 11 long, the heroic one 18)
        case 1:                                                              // the rider's leg the old way: the hip nearer the camera by depth, not by side
            let rg = rig(rstr(v.recipe, "body") + v.hold_suffix + facing_suffix(v.facing_k))
            for(v.legs) leg:
                if leg.cling:
                    for(glist(rg, "anchors")) a:
                        if as_float(a.a[3]) > 0.0: leg.node.pos = float2 { as_float(a.a[0]), as_float(a.a[1]) }
        case 2:  // a mount's wings over its body in every facing
            let bn = v.back_node
            if bn: bn.z = 1.6
            for(v.bob.kids) c:
                for(c.kids) n:
                    if n.part and n.buzz: n.z = 1.6
        case 3:  // the far legs on top
            for(v.legs) leg:
                if leg.node.z < 0.0: leg.node.z = 1.0
        case 4:  // the frog's sword behind its body
            let w = v.weapon
            if w: w.z = -4.0
            if pose == "walk0" and v.gait.hops: v.bob.rot = -0.18  // (the hop as it was then: nose up at its start)
        case 5: armour_with_body(v)
        case 6:
            if starts_with(pose, "walk"): v.bob.pos = float2 { v.bob.pos.x, -abs(rsin(v.phase)) * v.gait.bob }
        case 7: old_kneel(v, pose)
        case 8:  // crew by their own order, a hauler over them all (as first given, round TC1)
            var n = 0
            for(v.crew) c:
                let side = if c.node.z > 0.0: 1.0 else: -1.0
                if starts_with(c.crew_socket, "haul"): c.node.z = side + 0.005
                else:
                    c.node.z = side + float(n) * 0.01
                    n++
        case 9:  // the hauler's near hind leg not drawn while it walks
            if starts_with(pose, "walk"):
                for(v.crew) c:
                    if starts_with(c.crew_socket, "haul"):
                        for(c.legs) leg:
                            if ends_with(leg.walk_id, "_hind") and leg.node.z > 0.6: leg.node.visible = false
        default: pass()

// The body's own pixels in its worn armour's sprite, as the bake made it before the body was its holdout.
def armour_with_body(v:UV):
    let all = []::VNode
    part_nodes2(v.node, all)
    var body:VNode? = nil
    var armour:VNode? = nil
    for(all) n:
        if not n.front and starts_with(n.part_id, "body."): body = n
        if starts_with(n.part_id, "armour.") and find_string(n.part_id, "~") >= 0: armour = n
    if not body or not armour: return
    let bk = draw_key(body)
    let ak = draw_key(armour)
    let ab = bakes.get(ak)
    if not bakes.get(bk) or not ab: return
    let bp = pixels_of(bk)
    let ap = pixels_of(ak)
    armour.part_id = tokenize(armour.part_id, "~", "")[0] + "~fixture{v.facing_k}"  // (its base part stays the armour)
    armour.facing = 0
    let key = draw_key(armour)
    if not bakes.get(key):
        bakes.set(key, Bake { ab.ox, ab.oy, ab.scale })
        pixel_cache.set(key, Pixels { append(bp.pts, ap.pts), append(bp.team, ap.team) })

// The fused mount's kneel as it was until 2026-10-17 (drawn side-on): the two legs furthest right on screen fold,
// their shins swing back as if the body faced right, and the body turns about the two legs furthest left.
def old_kneel(v:UV, pose:string):
    if pose != "forage" or v.kneel <= 0.0: return
    let kneel = v.kneel
    v.bob.rot = 0.0
    v.bob.pos = float2 { 0.0, v.bob.pos.y }
    let seat = v.seat_node
    if seat and seat.has_seat_rest: seat.pos = seat.seat_rest
    for(v.legs) leg:
        leg.node.rot = 0.0
        leg.node.scl = float2 { leg.node.scl.x, leg.reach }
        let sh = leg.shin
        if sh: sh.visible = false
    let xs = map(v.legs) l: l.node.pos.x
    insertion_sort(xs) a, b: a < b
    let mid = (xs[1] + xs[2]) * 0.5
    for(v.legs) leg:
        if leg.node.pos.x > mid:
            let upper = 1.0 - 0.45 * kneel
            leg.node.scl = float2 { leg.node.scl.x, upper }
            leg.node.rot += 0.1 * kneel
            var shin = leg.shin
            if not shin:
                let made = new_part("")
                made.part_id = leg.node.part_id
                made.facing = leg.node.facing
                made.shade = leg.node.shade
                part_setup(made, leg.node.pshapes, leg.node.cols or SHADOW_COLOURS)
                made.z = leg.node.z
                add_sibling(leg.node, made)
                leg.shin = made
                shin = made
            let s = shin
            s.visible = true
            let off = float2 { 0.0, -leg.rest.y * upper }
            s.pos = leg.node.pos + float2 { off.x * rcos(leg.node.rot) - off.y * rsin(leg.node.rot), off.x * rsin(leg.node.rot) + off.y * rcos(leg.node.rot) }
            s.rot = leg.node.rot + 1.45 * kneel
            s.scl = float2 { leg.node.scl.x, 0.5 }
    let a = 0.17 * kneel
    let pivot = float2 { (xs[0] + xs[1]) * 0.5, 0.0 }
    v.bob.rot += a
    v.bob.pos += pivot - float2 { pivot.x * rcos(a) - pivot.y * rsin(a), pivot.x * rsin(a) + pivot.y * rcos(a) }
    if seat:
        seat.rot = -0.4 * kneel
        seat.pos = float2 { seat.pos.x - 1.5 * kneel, seat.pos.y }
