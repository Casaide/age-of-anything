// ------------------------------------------------------------------ a composed unit (src/unit_view.gd)
// recipe -> a tree of baked parts on sockets, and the procedural animation: walk cycles by body
// (two, four, six or eight legs; posed leg steps; flyers hover and flap; frogs hop), work per job,
// chores, idle fidgets and poses, the attack lunge and the archer's release, deaths by body shape
// (and the frog's baked fall), riders on mounts, engines with their crews and the beasts hauling
// them, war beasts. Cosmetic: nothing here feeds the sim. Ported line by line; its draw list is
// checked against Godot's (view_check.lobster). Left out: wandering (the Race Lab) and concept poses.

let SOCKET_FOR_SLOT = ["hand_r", "hand_r", "hand_l", "hand_l", "head_gear", "top", "torso", "torso", "back", "back"]
def socket_for(slot:string) -> string:
    var k = 0
    while k < SOCKET_FOR_SLOT.length:
        if SOCKET_FOR_SLOT[k] == slot: return SOCKET_FOR_SLOT[k + 1]
        k += 2
    return slot
def z_for(slot:string) -> float:
    switch slot:
        case "back": return -3.0
        case "torso": return 1.0
        case "head_gear": return 3.0
        case "hand_l": return 4.0
        default: return 5.0
let PERCH_SHADOW = 0.45
let CLING_TURN = 0.35
let COUCH = float2 { 1.0, -0.3 }
let HOP_HEIGHT = 9.0
let HOP_LENGTH = 40.0
let HOP_UP = 0.25
let HOP_DOWN = 0.75
let HOP_KEYS = [[0.0, 1.0, 0.0], [0.15, 0.7, 0.0], [0.25, 0.7, 0.0], [0.36, 1.15, -0.7], [0.52, 0.75, -0.25],
                [0.66, 0.9, 0.3], [0.75, 1.0, 0.0], [0.82, 0.72, 0.0], [1.0, 1.0, 0.0]]
let HOP_SETTLE = 25.0
let WITHERS_DROP = float2 { 2.0, 5.0 }
let WITHERS_TILT = -0.5
let WITHERS_SCALE = 2.0
let STEP_FPS = 8.0
let FACINGS = 8
let FACING_HOLD = 0.12
let ENGINE_SHADOW = 210.0
let BEAST_STRIKE = 0.6
let BEAST_HIT = 0.35
let THROW_TIME = 0.9
let LOAD_Z = 1.2
let WORK_HOLDS = ["reach", "raise"]
let CORPSE_AT = [0.12, 0.24, 0.36]
let KNEEL_DIP = 3.0
let SIT_AFTER_LO = 3.0
let SIT_AFTER_HI = 6.0
let POSE_DOWN = 0.22
let POSE_UP = 0.08
let CHORES = ["sweep", "sit", "chat", "graze"]
// part_baker.gd's bake camera
let BAKE_AZIMUTH = 35.0
let BAKE_FACING_STEP = 45.0
let BAKE_ELEVATION = 30.0

let shadow_shape = parse_json("\{\"t\": \"ellipse\", \"c\": [3, 1], \"r\": [15, 4.5], \"ch\": \"shadow\"\}")

class Gait:
    swing:float
    cadence:float
    bob:float
    rock:float
    rock_rate:float
    hops:bool

class Leg:
    node:VNode
    phase:float
    cling:bool
    reach:float
    rest:float2
    fore:bool
    base:string
    walk_id:string
    cut:string
    steps:int
    shin:VNode? = nil
    span:[float2]? = nil

class Rig:
    root:VNode
    sockets:Socks
    torso_scale:float2
    carry:string
    gear_scale:float
    drape_scale:float
    depth:JV
    body:string
    modelled:bool

class UV:
    node = VNode {}             // the UnitView itself
    recipe = jobj()
    visual = VNode {}
    bob = VNode {}
    shadow = VNode {}
    lift = 0.0
    ground_shadow = float2_0
    perched = false
    legs:[Leg] = []
    breathing:[VNode] = []
    weapon:VNode? = nil
    weapon_rest = float2_0
    weapon_rot = 0.0
    hold_suffix = ""
    cling_reach = 1.0
    rider_reach = 1.7
    girth_drop = 0.0
    clinging = false
    harnessed = false
    hop_off = float2_0
    hop_aim = float2_0
    hop_last = float2_0
    has_hop_last = false
    hop_rate = 0.0
    head_node:VNode? = nil
    seat_node:VNode? = nil
    back_node:VNode? = nil
    job = ""
    struck = false
    work_p = 0.0
    gait = Gait { 0.5, 1.0, 1.5, 0.0, 1.0, false }
    idle_kind = ""
    idle_left = 0.0
    idle_wait = 2.0
    flying = false
    unit_scale = 1.0
    pose_steps = 0
    art_px = 0.0
    facing = 1.0
    facing_k = 0
    facing_body = ""
    built = false
    team = float3_1
    speed = 10
    noise = Pcg {}
    time = 0.0
    phase = 0.0
    walking = false
    attack_t = 0.0
    attack_kind = "blow"
    thrusts = false
    dying = false
    die_t = 0.0
    die_tip = 1.0
    die_offset = float2_0
    speed_px = 30.0
    crew:[UV] = []             // an engine's crew and the beasts hauling it, each a view of its own
    crew_top = false            // (as one of them: riding on top)
    crew_socket = ""
    thrown = false              // (thrown off a fallen war beast, from here)
    thrown_at = float2_0
    rest_hold = "low"
    beast_head_rest = float2_0
    own_recipe:JV? = nil
    set_up_body = ""
    throw_t = 0.0
    thrown_from = ""
    carry_hold = ""
    work_hold = "low"
    body_nodes:[VNode] = []
    hand_rest = float2_0
    corpse:VNode? = nil
    corpse_pose:JV? = nil
    kneel = 0.0
    kneel_want = 0.0
    kneel_from = 0.0
    kneel_at = 0.0
    kneel_seen = false
    body_pose = ""
    pose_body = ""
    idle_poses:[string] = []
    still = 0.0
    sit_after = -1.0
    pose_t = 0.0
    hop_bias_for = -1
    hop_bias_v = 0.0

// Whether a part has a hand-built model (UnitModelsCheck.has): the pack's list says so; with no pack, the models do
// (asked once a part).
def is_modelled(id:string) -> bool:
    let known = modelled.get(id, -1)
    if known >= 0 or modelled_listed: return known == 1
    let has = build_model(id, colours_for("rat_grey", "sewer", float3_1)) != nil
    modelled.set(id, if has: 1 else: 0)
    return has

def ptags_of(id:string) -> [string]: return gstrs(part(id), "tags")
def pshapes_of(id:string) -> [JV]: return glist(part(id), "shapes")
def jstr_hash(s:string) -> int:   // Godot's String.hash (djb2 over the characters)
    var h = 5381
    let cs = string_to_unicode(s)
    if cs:
        for(cs) c: h = ((h << 5) + h + c) & 0xFFFFFFFF
    return h

def uv_part(v:UV, id:string, shapes:[JV], cols:Colours) -> VNode:
    let n = new_part(id)
    n.facing = v.facing_k
    part_setup(n, shapes, cols)
    return n

// ---- building

def uv_new() -> UV: return UV {}

def uv_build(v:UV, r:JV, team:float3, speed:int) -> void:
    v.built = true
    v.recipe = r
    v.team = team
    v.speed = speed
    v.noise = pcg_seed(hash_text(stringify(r)))
    v.time = randf(v.noise) * 10.0
    v.unit_scale = float(as_int(at(r, "scale"))) / 100.0
    if not has(r, "mount") and not has(r, "crew"):   // a creature drawn smaller than it's built, on foot (creatures.json draw_scale: the look only)
        let cr = get(lib_creatures, gstr(r, "creature", ""))
        if cr: v.unit_scale *= float(gint(cr, "draw_scale", 100)) / 100.0
    v.speed_px = float(speed) * 3.0
    v.perched = false
    v.ground_shadow = float2_0
    let shadow = new_part("unit_shadow")
    let sc = Colours { dictionary<string, string>(3), float3_1 }
    sc.hex.set("shadow", "0f0d08")
    part_setup(shadow, [shadow_shape], sc)
    add_child(v.node, shadow)
    v.shadow = shadow
    v.visual = VNode {}
    add_child(v.node, v.visual)
    v.bob = VNode {}
    add_child(v.visual, v.bob)
    let colours = colours_for(rstr(r, "skin"), rstr(r, "family"), team)
    let rp = at(r, "parts")
    if has(r, "crew"): build_engine(v, r, colours)
    elif has(r, "mount"):
        let m = at(r, "mount")
        let mc = creature(rstr(m, "creature"))
        let fused = gbool(m, "fused", false)
        let mount_colours = colours_for(rstr(m, "skin"), rstr(r, "family"), team)
        let mount_body = if fused: gstr(mc, "fused_body", rstr(mc, "body")) else: gstr(mc, "mount_body", rstr(mc, "body"))
        v.pose_body = mount_body
        let mount_rig = make_rig(v, mount_body, if fused: "" else: gstr(mc, "mount_head", rstr(mc, "head")), mount_colours, v.bob, true, "")
        v.facing_body = mount_body
        let mp = at(m, "parts")
        for(mp.keys) slot, n: attach(v, mount_rig, slot, as_str(mp.a[n]), mount_colours)
        let seat = VNode {}
        seat.z = 2.0
        v.clinging = not fused and gstr(rig(rstr(r, "body")), "carry", "") == "harness"
        let seat_at = sget(mount_rig.sockets, "seat", float2 { 0.0, -20.0 })
        if fused: seat.pos = seat_at
        elif v.clinging:
            seat.pos = seat_at + float2 { -1.0, 9.0 }
            seat.scl = float2 { 0.6, 0.6 }
        else:
            seat.pos = seat_at + float2 { 0.0, 6.0 }
            seat.scl = float2 { 0.8, 0.8 }
        seat.scl *= float(gint(gobj(mc, "rider_scale"), rstr(r, "creature"), 100)) / 100.0
        let rc = get(lib_creatures, rstr(r, "creature")) or jobj()
        if not fused:
            let hips, has_hips = sit_point(v, r)
            if has_hips:
                seat.pos = seat_at - hips * seat.scl
                if shas(mount_rig.sockets, "girth") and not v.clinging and hips.y < 0.0 and gstr(rc, "rider_legs", "") != "folded":
                    let girth = sget(mount_rig.sockets, "girth", float2_0)
                    v.girth_drop = (girth.y - sget(mount_rig.sockets, "seat", float2_0).y) / seat.scl.y
                    v.rider_reach = clampf(v.girth_drop / (-hips.y * rcos(CLING_TURN)), 1.0, 2.6)
        add_child(v.bob, seat)
        v.seat_node = seat
        v.cling_reach = if v.clinging or gstr(rc, "rider_legs", "") == "folded": 1.0 else: v.rider_reach
        v.clinging = not fused
        let rider = make_rig(v, rstr(r, "body"), rstr(r, "head"), colours, seat, v.clinging, gstr(rp, "hand_r", ""))
        v.clinging = false
        for(rp.keys) slot, n: attach(v, rider, slot, as_str(rp.a[n]), colours)
        v.flying = has(mp, "back") and has_s(ptags_of(rstr(mp, "back")), "flying")
    else:
        v.pose_body = rstr(r, "body")
        let rg = make_rig(v, rstr(r, "body"), rstr(r, "head"), colours, v.bob, true, gstr(rp, "hand_r", ""))
        v.facing_body = rstr(r, "body") + v.hold_suffix
        for(rp.keys) slot, n: attach(v, rg, slot, as_str(rp.a[n]), colours)
    let rides_unwinged = has(r, "mount") and not gbool(at(r, "mount"), "fused", false)
    if not rides_unwinged and has(rp, "back") and has_s(ptags_of(rstr(rp, "back")), "flying"): v.flying = true
    let ss = v.unit_scale * (if v.flying: 0.8 else: 1.0) * (if has(r, "mount") or v.legs.length > 2: 1.0 else: 0.65)
    shadow.scl = float2 { ss, ss }
    v.gait = gait_for(v.legs.length, v.flying)
    if not has(r, "mount") and not has(r, "crew") and not v.flying and gstr(get(lib_creatures, gstr(r, "creature", "")) or jobj(), "gait", "") == "hop":
        v.gait = Gait { 0.0, 0.55, 0.0, 0.0, 1.0, true }
    if has(r, "crew"):
        let rad = jf(gobj(part(rstr(r, "body")), "stats"), "radius", 300.0)
        shadow.scl = float2_1 * rad / ENGINE_SHADOW
        if not v.legs.length: v.gait = Gait { 0.0, 1.0, 0.0, 0.012, 3.0, false }
    v.idle_poses = []
    if v.pose_body != "" and not v.flying:
        let pb = part(v.pose_body)
        let pl = get(pb, "legs")
        if pl and has(pl, "gait"): v.gait = gait_with(v.gait, at(pl, "gait"))
        v.idle_poses = idle_poses_of(r, v.pose_body)
    if v.sit_after < 0.0 and v.idle_poses.length: v.sit_after = randf_range(v.noise, SIT_AFTER_LO, SIT_AFTER_HI)
    v.idle_wait = randf_range(v.noise, 1.0, 5.0)
    sort_layers(v.node)
    face_dir(v, v.facing)


def sit_point(v:UV, r:JV) -> float2, bool:
    let rp = at(r, "parts")
    let hold = if has(rp, "hand_r"): hold_for(ptags_of(rstr(rp, "hand_r"))) else: "low"
    let id = rstr(r, "body") + (if hold == "low": "" else: "@" + hold)
    let rg = rig(id + facing_suffix(v.facing_k))
    let socks = gobj(rg, "sockets")
    if has(socks, "sit"): return v2(at(socks, "sit")), true
    let anchors = glist(rg, "anchors")
    if not anchors.length: return float2_0, false
    var sum = float2_0
    for(anchors) a: sum += float2 { as_float(a.a[0]), as_float(a.a[1]) }
    return sum / float(anchors.length), true

def set_perched(v:UV, on:bool):
    if on == v.perched: return
    if v.ground_shadow == float2_0: v.ground_shadow = v.shadow.scl
    v.perched = on
    v.shadow.scl = v.ground_shadow * (if on: PERCH_SHADOW else: 1.0)

def build_engine(v:UV, r:JV, colours:Colours) -> void:
    let bid = rstr(r, "body")
    let p = part(bid)
    v.facing_body = bid
    if has(p, "legs"):
        v.pose_body = bid
        make_rig(v, bid, rstr(at(p, "beast"), "head"), colours, v.bob, true, "")
    else:
        let engine = uv_part(v, bid, glist(p, "shapes"), colours)
        add_child(v.bob, engine)
        v.body_nodes.push(engine)
    let rg = rig_or(bid + facing_suffix(v.facing_k), bid)
    let sockets = gobj(rg, "sockets")
    let depth = gobj(rg, "depth")
    let names = engine_sockets(r, sockets)
    insertion_sort(names) a, b: as_float(at(depth, a)) < as_float(at(depth, b)) or (as_float(at(depth, a)) == as_float(at(depth, b)) and a < b)
    let cr = crew_recipe(r)
    let hr = if has(r, "haul"): haul_recipe(r) else: jobj()
    let front = get(rg, "front")
    for(names) name, n:
        let hauls = starts_with(name, "haul")
        var face = v.facing_k
        var hold = "low"
        var infront = as_float(at(depth, name)) > 0.0
        if front and front.kind == J_OBJ and has(front, name): infront = as_bool(at(front, name))
        var z = if infront: 1.0 else: -1.0
        var top = false
        for(tokenize(name, "_", "")) t:
            if starts_with(t, "f") and t.length == 2: face = (v.facing_k + string_to_int(substring(t, 1, 1))) % FACINGS
            elif has_s(WORK_HOLDS, t): hold = t
            elif t == "in": z = -1.0
            elif t == "top":
                z = 1.0
                top = true
        let c = uv_new()
        c.facing_k = face
        uv_build(c, if hauls: hr else: cr, v.team, v.speed)
        c.node.pos = v2(at(sockets, name))
        c.node.z = z + float(n) * 0.01
        if not hauls:
            c.rest_hold = hold
            set_hold(c, hold)
        c.phase = if hauls: 0.4 else: 0.7 * float(n)
        add_child(v.bob, c.node)
        c.crew_top = top
        c.crew_socket = name
        v.crew.push(c)
    let hn = v.head_node
    if hn:
        var at_ = 0
        for(names) m:
            if as_float(at(depth, m)) < jf(depth, "head", 0.0): at_++
        let hp = hn.parent
        if hp: remove_child(hp, hn)
        hn.z = 1.0 + float(at_) * 0.01 - 0.005
        add_child(v.bob, hn)
        v.beast_head_rest = hn.pos

def idle_poses_of(r:JV, body_id:string) -> [string]:
    if gint(r, "idle", 1) == 0: return []
    let pb = part(body_id)
    if has(r, "mount") and not gbool(at(r, "mount"), "fused", false) and has(pb, "ridden_idle_poses"): return gstrs(pb, "ridden_idle_poses")
    return gstrs(pb, "idle_poses")

def engine_sockets(r:JV, sockets:JV) -> [string]:
    let cr = at(r, "crew")
    let wide = has(cr, "mount") or gint(cr, "wide", 0) != 0
    let out = filter(sockets.keys) s: starts_with(s, "crew") and not (wide and ends_with(s, "_narrow")) and
        (ends_with(s, "_wide") == wide or (wide and not has(sockets, trim_suffix(trim_suffix(s, "_in"), "_top") + "_wide") and not ends_with(s, "_in")))
    if has(r, "haul"):
        for(sockets.keys) s:
            if starts_with(s, "haul"): out.push(s)
    return out

def trim_suffix(s:string, suf:string) -> string: return if ends_with(s, suf): substring(s, 0, s.length - suf.length) else: s

def crew_recipe(r:JV) -> JV:
    let cr = deep_copy(at(r, "crew"))
    for([["creature", rstr(r, "creature")], ["family", rstr(r, "family")], ["slot", "worker"], ["role", "worker"], ["name", ""]]) kv:
        if not has(cr, kv[0]): set(cr, kv[0], jstr(kv[1]))
    if not has(cr, "tier"): set(cr, "tier", jint(1))
    return cr

// A war beast's own body walking (the engine's body with its legs and its head, nobody on it).
def beast_recipe(r:JV) -> JV:
    let o = jobj()
    set(o, "slot", jstr("beast"))
    set(o, "role", jstr("beast"))
    set(o, "tier", jint(1))
    set(o, "creature", jstr(""))
    set(o, "family", at(r, "family"))
    set(o, "skin", at(r, "skin"))
    set(o, "body", at(r, "body"))
    set(o, "head", at(gobj(part(rstr(r, "body")), "beast"), "head"))
    set(o, "parts", jobj())
    set(o, "scale", jint(100))
    set(o, "name", jstr(""))
    set(o, "idle", jint(0))
    return o

def haul_recipe(r:JV) -> JV:
    let h = at(r, "haul")
    let hc = creature(rstr(h, "creature"))
    let o = jobj()
    set(o, "slot", jstr("beast"))
    set(o, "role", jstr("beast"))
    set(o, "tier", jint(1))
    set(o, "creature", at(h, "creature"))
    set(o, "family", at(r, "family"))
    set(o, "skin", at(h, "skin"))
    set(o, "body", jstr(gstr(hc, "mount_body", rstr(hc, "body"))))
    set(o, "head", at(hc, "head"))
    set(o, "parts", deep_copy(gobj(h, "parts")))
    set(o, "scale", jint(100))
    set(o, "name", jstr(""))
    set(o, "idle", jint(0))
    return o

def hold_for(tags:[string]) -> string:
    if has_s(tags, "javelin"): return "throw"
    if has_s(tags, "poison") and has_s(tags, "ranged"): return "mouth"
    if has_s(tags, "sling"): return "overhead"
    if has_s(tags, "gun") or (has_s(tags, "bow") and has_s(tags, "heavy")): return "aim"
    if has_s(tags, "bow"): return "draw"
    if (has_s(tags, "spear") and has_s(tags, "heavy")) or has_s(tags, "shouldered"): return "shoulder"
    return "low"

def make_rig(v:UV, body_id:string, head_id:string, colours:Colours, parent:VNode, with_legs:bool, hand_r:string) -> Rig:
    let hold = if hand_r != "": hold_for(ptags_of(hand_r)) else: "low"
    v.hold_suffix = if hold == "low": "" else: "@" + hold
    let body = part(body_id)
    let root = VNode {}
    add_child(parent, root)
    let pose = if v.body_pose != "" and body_id == v.pose_body: "@" + v.body_pose else: ""
    let rg = rig_or(body_id + v.hold_suffix + pose + facing_suffix(v.facing_k), body_id + v.hold_suffix + pose)
    let sockets = Socks {}
    let src = if has(rg, "sockets"): at(rg, "sockets") else: gobj(body, "sockets")
    for(src.keys) k, n: sset(sockets, k, v2(src.a[n]))
    return make_rig_rest(v, body_id, head_id, body, colours, root, with_legs, rg, pose, sockets, has(rg, "sockets"))

def make_rig_rest(v:UV, body_id:string, head_id:string, body:JV, colours:Colours, root:VNode, with_legs:bool, rg:JV, pose:string,
                  sockets:Socks, modelled_rig:bool) -> Rig:
    let bl = get(body, "legs")
    if with_legs and bl:
        let anchors = if has(rg, "anchors"): glist(rg, "anchors") else: glist(bl, "anchors")
        let cut = has_s(gstrs(body, "cut"), "legs")
        let data_anchors = glist(bl, "anchors")
        var fsum = 0.0
        for(data_anchors) b: fsum += as_float(b.a[0])
        let fore_mid = fsum / max(1.0, float(data_anchors.length))
        for(anchors) a, i:
            let skip = v.clinging and (if a.a.length > 6: not as_bool(a.a[6]) else: as_float(a.a[3]) < 0.0)
            if not skip:
                let hind = a.a.length > 5 and as_bool(a.a[5])
                let leg_id = if hind: gstr(bl, "hind", rstr(bl, "part")) else: rstr(bl, "part")
                let leg_part = part(leg_id)
                let leg = uv_part(v, leg_id + pose + (if cut: "~" + body_id + pose + "^" + string(i) else: ""), glist(leg_part, "shapes"), colours)
                leg.pos = float2 { as_float(a.a[0]), as_float(a.a[1]) }
                let under = gbool(rg, "legs_under", false)
                let a3 = as_float(a.a[3])
                leg.z = if under and a3 > 0.0: -1.0 elif a3 > 0.0: 1.0 else: -2.0
                if cut: leg.z = if a3 > 0.0: 1.0 else: 0.5
                if a.a.length > 4 and as_int(a.a[4]) == 1 and not cut: leg.scl = float2 { -1.0, leg.scl.y }
                if has(rg, "anchors") and a3 < 0.0: leg.shade = 0.78
                add_child(root, leg)
                var reach = if v.clinging: v.cling_reach else: 1.0
                if v.clinging and v.girth_drop > 0.0 and v.cling_reach > 1.0 and has_bake_of(leg, ""):
                    var low = 0.0
                    for(soles_of(leg, "")) p: low = max(low, p.y)
                    if low > 0.0: reach = clampf(v.girth_drop / (low * rcos(CLING_TURN)), 1.0, 2.6)
                v.legs.push(Leg { leg, as_float(a.a[2]), v.clinging, reach, leg.pos, as_float(data_anchors[i].a[0]) > fore_mid,
                                  leg_id + pose, leg_id, if cut: "~" + body_id + "^" + string(i) else: "",
                                  if pose == "": gint(bl, "poses", 0) else: 0 })
    let body_node = uv_part(v, body_id + v.hold_suffix + pose, glist(body, "shapes"), colours)
    add_child(root, body_node)
    v.breathing.push(body_node)
    if body_id == rstr(v.recipe, "body"): v.body_nodes.push(body_node)
    let fr = get(rg, "front")
    if fr and fr.kind == J_BOOL and fr.i != 0:
        let arm = uv_part(v, body_id + v.hold_suffix, glist(body, "shapes"), colours)
        arm.front = true
        arm.z = if v.facing_k == 0 or jf(gobj(rg, "depth"), "hand_r", 1.0) >= -0.5: 1.5 else: -1.0
        add_child(root, arm)
        if body_id == rstr(v.recipe, "body"): v.body_nodes.push(arm)
    var gear_scale = 1.0
    if head_id != "":
        let head = part(head_id)
        let hid = head_id + (if has_s(gstrs(body, "cut"), "head"): "~" + body_id + pose + "^head" else: "")
        let hn = uv_part(v, hid, glist(head, "shapes"), colours)
        hn.pos = sget(sockets, "head", float2_0)
        hn.z = 2.0
        add_child(root, hn)
        v.head_node = hn
        let hr = rig_or(hid + facing_suffix(v.facing_k), hid)
        let top = if has(hr, "sockets"): v2(at(at(hr, "sockets"), "top")) else: v2(at(at(head, "sockets"), "top"))
        sset(sockets, "top", hn.pos + top)
        gear_scale = jf(hr, "gear_scale", 1.0)
    let ts = if has(rg, "torso_scale"): v2(at(rg, "torso_scale")) elif has(body, "torso_scale"): v2(at(body, "torso_scale")) else: float2_1
    return Rig { root, sockets, ts, gstr(rg, "carry", ""), gear_scale, jf(body, "drape_scale", 100.0) / 100.0, gobj(rg, "depth"), body_id, modelled_rig }

def attach(v:UV, rg:Rig, slot:string, part_id:string, colours:Colours) -> void:
    var socket = socket_for(slot)
    let p = part(part_id)
    let tags = gstrs(p, "tags")
    let withers = slot == "back" and has_s(tags, "flying") and shas(rg.sockets, "wings")
    if withers: socket = "wings"
    if slot == "back" and shas(rg.sockets, part_id): socket = part_id
    elif slot == "back" and has_s(tags, "drape") and shas(rg.sockets, "drape"): socket = "drape"
    if slot == "back" and has_s(tags, "banner") and not has_s(tags, "hero") and shas(rg.sockets, "banner"): socket = "banner"
    let slung = slung_on(rg.body, slot, part_id)
    if slung != "": socket = if shas(rg.sockets, "sling"): "sling" else: "back"
    if not shas(rg.sockets, socket): return
    let sp = sget(rg.sockets, socket, float2_0)
    let node = uv_part(v, part_id + slung, glist(p, "shapes"), colours)
    let worn = slot == "torso" and is_modelled(rg.body) and is_modelled(part_id)   // (the body's model, not its bake)
    if worn: node.part_id = part_id + "~" + rg.body
    node.pos = if worn: float2_0 else: sp
    if withers:
        node.pos += WITHERS_DROP
        node.rot = WITHERS_TILT
        node.scl = float2_1 * WITHERS_SCALE
        node.rest = WITHERS_TILT
        node.rest_scale = WITHERS_SCALE
    var z = if withers: 0.5 else: z_for(slot)
    if v.facing_k != 0 and (slot == "hand_l" or slot == "hand_r" or slot == "back") and has(rg.depth, socket):
        let near = as_float(at(rg.depth, socket)) >= -0.5
        z = if near: (if slot == "back": 1.6 else: abs(z)) else: (if slot == "back": -3.0 else: -abs(z))
    if slung == "@slung_flat": z = 1.6
    elif slung != "":
        z = if v.facing_k != 0 and has(rg.depth, socket) and as_float(at(rg.depth, socket)) > 0.5: 1.6 else: -3.0
    if has(p, "blur"):
        node.alpha = as_float(at(p, "blur")) / 100.0
        node.buzz = true
    node.z = z
    if slot == "torso" and not worn: node.scl = rg.torso_scale
    elif slot == "head_gear": node.scl = float2_1 * rg.gear_scale
    elif slot == "back" and has_s(tags, "drape"): node.scl = float2_1 * rg.drape_scale
    add_child(rg.root, node)
    if rg.carry == "harness" and slot == "hand_r":
        let tr = rig(part_id)
        let tip = if has(tr, "tip"): v2(at(tr, "tip")) else: float2_0
        node.rot = if starts_with(part_id, "tool.") or tip == float2_0: 0.25 else: vangle(COUCH) - vangle(tip)
    if rg.carry == "harness" and slot == "hand_l": node.scl = float2 { 0.7, 0.85 }
    if slot == "hand_r":
        v.weapon = node
        v.weapon_rest = node.pos
        v.hand_rest = node.pos
        v.weapon_rot = node.rot
        v.harnessed = rg.carry == "harness"
        v.thrusts = has_s(tags, "spear") or has_s(tags, "lance")
    if slot == "back": v.back_node = node

def slung_on(body_id:string, slot:string, part_id:string) -> string:
    let how = gstr(part(body_id), "shield", "")
    return if slot == "hand_l" and how != "" and has_s(ptags_of(part_id), "shield"): "@" + how else: ""

def face_dir(v:UV, dir:float):
    v.facing = if v.facing_k == 0: dir else: 1.0
    v.visual.scl = float2 { v.unit_scale * v.facing, v.unit_scale }

def face(v:UV, dir:float): face_vec(v, float2 { if dir >= 0.0: 1.0 else: -1.0, 0.35 })

def face_vec(v:UV, d:float2) -> void:
    if d == float2_0: return
    if not v.built or not has_rig(v.facing_body + facing_suffix(1)):
        face_dir(v, if d.x >= 0.0: 1.0 else: -1.0)
        return
    let want = vnorm(d)
    var best = v.facing_k
    var best_fit = -2.0
    var now_fit = -2.0
    for(FACINGS) k:
        let rg = rig(v.facing_body + facing_suffix(k))
        if has(rg, "dir"):
            let fit = vdot(v2(at(rg, "dir")), want)
            if k == v.facing_k: now_fit = fit
            if fit > best_fit:
                best_fit = fit
                best = k
    if best != v.facing_k and best_fit > now_fit + FACING_HOLD:
        v.facing_k = best
        rebuild(v)

def rebuild(v:UV) -> void:
    let keep_time = v.time
    let keep_phase = v.phase
    let w = v.weapon
    let tool = if w: w.part_id else: ""
    for(v.node.kids) c: free_tree(c)
    v.node.kids = []
    let hold = v.work_hold
    v.legs = []
    v.breathing = []
    v.crew = []
    v.weapon = nil
    v.head_node = nil
    v.back_node = nil
    v.seat_node = nil
    v.body_nodes = []
    v.work_hold = "low"
    v.flying = false
    v.facing = 1.0
    uv_build(v, v.recipe, v.team, v.speed)
    v.time = keep_time
    v.phase = keep_phase
    let w2 = v.weapon
    if tool != "" and w2 and tool != w2.part_id: set_tool(v, tool)
    set_hold(v, hold)

def with_body(r:JV, body:string) -> JV:
    let o = shallow_copy(r)
    o.index = nil
    set(o, "body", jstr(body))
    return o

def push_engine(v:UV, engine_id:string) -> void:
    let own = v.own_recipe
    if engine_id == "":
        if own: v.recipe = own
        v.own_recipe = nil
    elif not has_rig(engine_id + facing_suffix(v.facing_k)) and not has_rig(engine_id): return
    elif not own:
        v.own_recipe = v.recipe
        v.recipe = push_recipe(v.recipe, engine_id)
    elif rstr(v.recipe, "body") != engine_id: v.recipe = push_recipe(own, engine_id)
    else: return
    rebuild(v)

def set_packed(v:UV, on:bool) -> void:
    if on and v.thrown_from != "":
        v.recipe = with_body(v.recipe, v.thrown_from)
        v.thrown_from = ""
        v.throw_t = 0.0
    let r = v.recipe
    var to = ""
    if on and v.set_up_body == "":
        to = gstr(part(rstr(r, "body")), "packed", "")
        if to == "" or not (has_rig(to + facing_suffix(v.facing_k)) or has_rig(to)): return
        v.set_up_body = rstr(r, "body")
    elif not on and v.set_up_body != "":
        to = v.set_up_body
        v.set_up_body = ""
    else: return
    v.recipe = with_body(r, to)
    rebuild(v)

def throw_look(v:UV) -> void:
    if v.thrown_from != "":
        v.throw_t = THROW_TIME
        return
    let r = v.recipe
    let to = gstr(part(rstr(r, "body")), "throw", "")
    if to == "" or not (has_rig(to + facing_suffix(v.facing_k)) or has_rig(to)): return
    v.thrown_from = rstr(r, "body")
    v.throw_t = THROW_TIME
    v.recipe = with_body(r, to)
    rebuild(v)

def throw_process(v:UV, dt:float) -> void:
    v.throw_t -= dt
    if v.throw_t <= 0.0:
        v.recipe = with_body(v.recipe, v.thrown_from)
        v.thrown_from = ""
        rebuild(v)

def push_recipe(r:JV, engine_id:string) -> JV:
    let crew = jobj()
    set(crew, "body", at(r, "body"))
    set(crew, "head", at(r, "head"))
    set(crew, "skin", at(r, "skin"))
    let ps = shallow_copy(at(r, "parts"))
    erase(ps, "hand_r")
    set(crew, "parts", ps)
    set(crew, "scale", get(r, "scale") or jint(100))
    let o = jobj()
    set(o, "slot", at(r, "slot"))
    set(o, "role", get(r, "role") or at(r, "slot"))
    set(o, "tier", get(r, "tier") or jint(1))
    set(o, "creature", at(r, "creature"))
    set(o, "family", at(r, "family"))
    set(o, "skin", at(r, "skin"))
    set(o, "body", jstr(engine_id))
    set(o, "head", jstr(""))
    set(o, "parts", jobj())
    set(o, "scale", jint(100))
    set(o, "name", get(r, "name") or jstr(""))
    set(o, "crew", crew)
    return o

def set_tool(v:UV, part_id:string) -> void:
    if starts_with(part_id, "push:"):
        push_engine(v, substring(part_id, 5, part_id.length - 5))
        return
    if v.own_recipe: push_engine(v, "")
    let w = v.weapon
    if not w or v.harnessed or w.part_id == part_id: return
    let p = part(part_id)
    if not bakes.get(bake_key(part_id, glist(p, "shapes"), w.cols)): return
    w.part_id = part_id
    w.pshapes = glist(p, "shapes")
    v.carry_hold = if has_s(gstrs(p, "tags"), "shoulder"): "raise" else: ""
    if not w.has_tool_z:
        w.has_tool_z = true
        w.tool_z = w.z
    let z = if has_s(gstrs(p, "tags"), "load"): (if w.tool_z > 0.0: LOAD_Z else: -LOAD_Z) else: w.tool_z
    if z != w.z:
        w.z = z
        let wp = w.parent
        if wp: sort_layers(wp)

def flourish(v:UV) -> void:
    v.attack_t = if has(v.recipe, "crew") and v.legs.length: BEAST_STRIKE else: 0.35
    v.attack_kind = "blow"
    for(v.crew) c: flourish(c)

def loose(v:UV) -> void:
    if has(v.recipe, "crew"): throw_look(v)
    v.attack_t = 0.35
    v.attack_kind = "loose"
    for(v.crew) c: loose(c)

def corpse_pose_of(r:JV) -> JV?:
    let rp = at(r, "parts")
    if has(r, "mount") or has(r, "crew") or (has(rp, "back") and has_s(ptags_of(rstr(rp, "back")), "flying")): return nil
    return get(part(rstr(r, "body")), "corpse")

def corpse_id(r:JV, pose:JV, f:int) -> string:
    return "corpse@" + string(f) + "#" + string(jstr_hash(stringify(r))) + "#" + string(jstr_hash(stringify(pose)))

def die(v:UV, tip:float) -> void:
    v.dying = true
    v.die_t = 0.0
    v.die_tip = tip
    v.walking = false
    v.job = ""
    v.attack_t = 0.0
    var pose = corpse_pose_of(v.recipe)
    if pose:   // (a library may not hold this recipe's fall: it falls the usual way then)
        let f0 = as_int(glist(pose, "frames")[0])
        if not bakes.get(corpse_id(v.recipe, pose, f0) + ":" + facing_suffix(v.facing_k)): pose = nil
    if pose:
        v.corpse_pose = pose
        let c = new_part("")
        c.facing = v.facing_k
        part_setup(c, [], colours_for(rstr(v.recipe, "skin"), rstr(v.recipe, "family"), v.team))
        c.visible = false
        add_child(v.visual, c)
        v.corpse = c
    for(v.crew) c:
        if c.crew_top and v.legs.length:
            let cat = c.node.pos + v.bob.pos
            let cp = c.node.parent
            if cp: remove_child(cp, c.node)
            add_child(v.visual, c.node)
            c.node.pos = cat
            c.thrown = true
            c.thrown_at = cat
        die(c, if c.node.pos.x < 0.0: -tip else: tip)

def set_hold(v:UV, hold:string) -> void:
    if hold == v.work_hold: return
    if has(v.recipe, "mount") and not gbool(at(v.recipe, "mount"), "fused", false): return
    let natural = rstr(v.recipe, "body") + v.hold_suffix
    let id = if hold == "low": natural else: rstr(v.recipe, "body") + "@" + hold
    let rg = rig_or(id + facing_suffix(v.facing_k), id)
    if hold != "low":
        if not rg.keys.length or not v.body_nodes.length: return
        let b0 = v.body_nodes[0]
        if not bakes.get(bake_key(id, b0.pshapes, b0.cols) + facing_suffix(v.facing_k)): return
    for(v.body_nodes) ps: ps.part_id = id
    v.work_hold = hold
    let w = v.weapon
    if w:
        let rs = gobj(rg, "sockets")
        w.pos = if hold != "low" and has(rs, "hand_r"): v2(at(rs, "hand_r")) else: v.hand_rest
        v.weapon_rest = w.pos
        let dp = gobj(rg, "depth")
        if v.facing_k != 0 and not v.harnessed and has(dp, "hand_r"):
            let side = if as_float(at(dp, "hand_r")) >= -0.5: 1.0 else: -1.0
            let tool_z = if w.has_tool_z: w.tool_z else: w.z
            w.has_tool_z = true
            w.tool_z = abs(tool_z) * side
            let cur = w.z
            if abs(cur) * side != cur:
                w.z = abs(cur) * side
                let wp = w.parent
                if wp: sort_layers(wp)

// ---- the frame

def forward(v:UV) -> float2:
    if v.facing_k == 0: return vnorm(COUCH)
    let rg = rig(v.facing_body + facing_suffix(v.facing_k))
    return if has(rg, "dir"): vnorm(v2(at(rg, "dir"))) else: float2 { 1.0, 0.0 }

def sgn(v:UV) -> float: return if forward(v).x >= 0.0: 1.0 else: -1.0

def hip_height(v:UV) -> float:
    var h = 6.0
    for(v.legs) l: h = max(h, -l.rest.y)
    return h

def leg_len(v:UV) -> float:
    var hip = 0.0
    for(v.legs) l: hip = max(hip, -l.rest.y)
    return hip

// A gait with a body's own numbers over it (parts.json legs.gait).
def gait_with(g0:Gait, g:JV) -> Gait:
    let ng = Gait { g0.swing, g0.cadence, g0.bob, g0.rock, g0.rock_rate, g0.hops }
    for(g.keys) k, n:
        let x = g.a[n]
        switch k:
            case "swing": ng.swing = as_float(x)
            case "cadence": ng.cadence = as_float(x)
            case "bob": ng.bob = as_float(x)
            case "rock": ng.rock = as_float(x)
            case "rock_rate": ng.rock_rate = as_float(x)
            case "hop": ng.hops = as_bool(x)
            default: pass()
    return ng

def gait_for(n:int, flies:bool) -> Gait:
    if flies: return Gait { 0.12, 0.8, 0.0, 0.04, 1.0, false }
    if n >= 8: return Gait { 0.26, 1.9, 0.25, 0.0, 2.0, false }
    if n >= 6: return Gait { 0.32, 1.6, 0.3, 0.015, 2.0, false }
    if n >= 4: return Gait { 0.42, 1.0, 0.9, 0.035, 1.0, false }
    return Gait { 0.5, 1.0, 1.5, 0.0, 1.0, false }

def ahead_on_screen(k:int) -> float2:
    let az = BAKE_AZIMUTH + BAKE_FACING_STEP * float(k)
    return float2 { cos(az), sin(BAKE_ELEVATION) * sin(az) }   // (degrees: Lobster's trig)

def side_on(k:int) -> float: return clampf(ahead_on_screen(k).x / ahead_on_screen(0).x, -1.0, 1.0)

// The node's global position and its transform's y scale (for snapping to whole art pixels).
def snap_offset(v:UV, extra:float2) -> float2:
    let g = xf_global(v.node)
    let gs = xf_scale(g)
    let gp = float2 { g[4], g[5] } + extra * gs.y
    let px = 1.0 / v.art_px
    let snapped = float2 { roundf(gp.x / px) * px, roundf(gp.y / px) * px }
    return (snapped - gp) / max(gs.x, 0.0001)

def uv_process(v:UV, dt:float) -> void:
    if has(v.recipe, "crew"):
        engine_process(v, dt)
        return
    v.time += dt
    v.struck = false
    pose_tick(v, dt)
    let stepped = v.pose_steps > 0
    let t = if stepped: floor(v.time * STEP_FPS) / STEP_FPS else: v.time
    var stride = if v.walking: 1.0 else: 0.0
    v.bob.pos = float2 { 0.0, v.bob.pos.y }
    let hops = v.gait.hops
    if hops:
        hop_advance(v, dt)
        stride = if v.walking or v.phase != 0.0: 1.0 else: 0.0
    elif v.walking: v.phase += dt * v.speed_px * 0.25 * v.gait.cadence
    var ph = v.phase
    if stepped:
        let step = TAU / float(v.pose_steps)
        ph = floor(v.phase / step) * step
    if hops: hop(v, ph, stride)
    else:
        for(v.legs) l:
            l.node.rot = if l.cling: CLING_TURN else: rsin(ph + l.phase) * v.gait.swing * stride
            l.node.scl = float2 { l.node.scl.x, l.reach }
            if l.steps > 0:
                var id = l.base + l.cut
                if v.walking:
                    let k = int(fposmod((v.phase + l.phase) / TAU, 1.0) * float(l.steps)) % l.steps
                    id = l.walk_id + "@w" + string(k) + "_" + string(l.steps) + l.cut
                if id != l.node.part_id: l.node.part_id = id
        var hover = 0.0
        if v.flying: hover = -9.0 + rsin(t * 3.0) * 2.0
        var plant = 0.0
        var has_plant = true
        if stride > 0.0 and not v.flying:
            plant, has_plant = planted(v, false)
        v.bob.pos = float2 { v.bob.pos.x, hover + (if has_plant: plant else: -abs(rsin(ph)) * v.gait.bob * stride) }
        v.bob.rot = rsin(ph * v.gait.rock_rate) * v.gait.rock * stride
    let hn = v.head_node
    if hn: hn.rot = 0.0
    let bn = v.back_node
    if bn and v.flying:
        var f = rsin(t * (if v.walking: 11.0 else: 7.0))
        if bn.buzz: f = [0.0, 1.0, -0.6][int(v.time * 24.0) % 3]
        bn.rot = bn.rest - 0.12 * f
        let rs = bn.rest_scale
        bn.scl = float2 { rs, rs * (1.0 + 0.1 * f) }
    if stepped:
        if fmodf(t, 4.0) < 0.5 and stride == 0.0 and v.job == "": v.bob.pos -= float2 { 0.0, 1.0 / max(v.art_px, 1.0) }
    else:
        let breath = 1.0 + rsin(v.time * 2.4) * 0.03
        for(v.breathing) b: b.scl = float2 { b.scl.x, breath }
    let w = v.weapon
    if w:
        w.pos = v.weapon_rest
        w.rot = v.weapon_rot
    if v.dying:
        v.die_t += dt
        die_pose(v)
    elif v.attack_t > 0.0:
        v.attack_t -= dt
        var a = 1.0 - max(v.attack_t, 0.0) / 0.35
        if stepped: a = floor(a * 5.0) / 5.0
        attack(v, a)
    elif v.job != "" and not v.walking: work(v, t, stepped)
    elif not v.walking: idle(v, dt)
    let rest = if v.carry_hold != "": v.carry_hold else: v.rest_hold
    if v.attack_t <= 0.0 and (v.job == "" or v.walking) and v.work_hold != rest: set_hold(v, rest)
    kneel_tick(v, dt)
    v.visual.pos = v.die_offset - float2 { 0.0, v.lift } + v.hop_off
    v.shadow.pos = v.hop_off - float2 { 0.0, v.lift }
    if stepped and v.art_px > 0.0: v.visual.pos += snap_offset(v, v.hop_off - float2 { 0.0, v.lift })

def engine_process(v:UV, dt:float) -> void:
    if v.legs.length:
        beast(v, dt)
        return
    v.time += dt
    if v.thrown_from != "": throw_process(v, dt)
    v.bob.pos = float2_0
    v.bob.rot = if v.walking: rsin(v.time * v.gait.rock_rate * 3.0) * v.gait.rock else: 0.0
    for(v.crew) c: c.walking = v.walking and not c.crew_top
    if v.dying:
        v.die_t += dt
        let e = min(v.die_t / 0.5, 1.0)
        v.visual.rot = v.die_tip * 0.1 * e
        v.die_offset = float2 { 0.0, 2.5 * e }
    elif v.attack_t > 0.0:
        v.attack_t -= dt
        let k = rsin((1.0 - max(v.attack_t, 0.0) / 0.35) * PI)
        v.bob.pos += forward(v) * (if v.attack_kind == "loose": -2.5 else: 6.0) * k
    v.visual.pos = v.die_offset - float2 { 0.0, v.lift }
    v.shadow.pos = float2 { v.shadow.pos.x, -v.lift }
    if v.pose_steps > 0 and v.art_px > 0.0: v.visual.pos += snap_offset(v, float2 { 0.0, -v.lift })

def beast(v:UV, dt:float) -> void:
    v.time += dt
    let stepped = v.pose_steps > 0
    let t = if stepped: floor(v.time * STEP_FPS) / STEP_FPS else: v.time
    for(v.crew) c: c.walking = v.walking and not c.crew_top
    if v.walking: v.phase += dt * v.speed_px * 0.25 * v.gait.cadence
    var ph = v.phase
    if stepped: ph = floor(v.phase / (TAU / float(v.pose_steps))) * (TAU / float(v.pose_steps))
    let stride = if v.walking: 1.0 else: 0.0
    for(v.legs) l:
        l.node.rot = rsin(ph + l.phase) * v.gait.swing * stride
        l.node.scl = float2 { l.node.scl.x, 1.0 }
        if l.steps > 0:
            var id = l.base + l.cut
            if v.walking:
                let k = int(fposmod((ph + l.phase) / TAU, 1.0) * float(l.steps)) % l.steps
                id = l.walk_id + "@w" + string(k) + "_" + string(l.steps) + l.cut
            if id != l.node.part_id: l.node.part_id = id
    var plant = 0.0
    var has_plant = true
    if stride > 0.0: plant, has_plant = planted(v, false)
    v.bob.pos = float2 { 0.0, if has_plant: plant else: -abs(rsin(ph)) * v.gait.bob * stride }
    v.bob.rot = rsin(ph * v.gait.rock_rate) * v.gait.rock * stride
    let hn = v.head_node
    if hn:
        hn.pos = v.beast_head_rest
        hn.rot = (if v.walking: rsin(ph * 2.0) * 0.04 else: rsin(t * 0.9) * 0.025) * sgn(v)
    v.die_offset = float2_0
    v.visual.rot = 0.0
    let b = at(part(rstr(v.recipe, "body")), "beast")
    if v.dying:
        v.die_t += dt
        beast_fall(v, rstr(b, "fall"), v.die_t)
    elif v.attack_t > 0.0:
        v.attack_t -= dt
        var a = 1.0 - max(v.attack_t, 0.0) / BEAST_STRIKE
        if stepped: a = floor(a * 8.0) / 8.0
        beast_attack(v, rstr(b, "attack"), a)
    v.visual.pos = v.die_offset - float2 { 0.0, v.lift }
    v.shadow.pos = float2 { v.shadow.pos.x, -v.lift }
    if stepped and v.art_px > 0.0: v.visual.pos += snap_offset(v, float2 { 0.0, -v.lift })

def pitch(v:UV, angle:float, rise:float):
    let f = forward(v)
    let r = -angle * sgn(v) * abs(f.x)
    var back = 0.0
    var front = 0.0
    for(v.legs) l:
        back = min(back, vdot(l.rest, f))
        front = max(front, vdot(l.rest, f))
    let p = float2 { (f * back).x, 0.0 }
    v.bob.pos += p - rot2(p, r) + float2 { 0.0, -angle * (front - back) * abs(f.y) * rise }
    v.bob.rot += r

def lift_legs(v:UV, turn:float, hind:float):
    let f = forward(v)
    for(v.legs) l:
        let fore = vdot(l.rest, f) > 0.0
        l.node.rot += -(if fore: turn else: hind) * sgn(v) * max(abs(f.x), 0.3)

def strike_curve(a:float) -> float:
    if a < BEAST_HIT: return rsin(a / BEAST_HIT * PI * 0.5)
    if a < BEAST_HIT + 0.15: return lerpf(1.0, -1.0, smoothstep(0.0, 1.0, (a - BEAST_HIT) / 0.15))
    return lerpf(-1.0, 0.0, smoothstep(0.0, 1.0, (a - BEAST_HIT - 0.15) / (0.85 - BEAST_HIT)))

def beast_attack(v:UV, kind:string, a:float):
    let k = strike_curve(a)
    let up = max(k, 0.0)
    let out = max(-k, 0.0)
    let f = forward(v)
    let sg = sgn(v)
    var hd = float2_0
    var hr = 0.0
    switch kind:
        case "tusks":
            pitch(v, 0.2 * up - 0.05 * out, 0.6)
            lift_legs(v, 0.55 * up, 0.0)
            v.bob.pos += f * 7.0 * out
            hr = -0.4 * up + 0.45 * out
            hd = f * 5.0 * out
        case "gore":
            pitch(v, -0.06 * up + 0.08 * out, 0.6)
            v.bob.pos += f * (-3.0 * up + 10.0 * out)
            lift_legs(v, -0.15 * up + 0.3 * out, 0.25 * out)
            hr = 0.3 * up - 0.55 * out
            hd = f * 4.0 * out + float2 { 0.0, 3.0 * up }
        case "bite":
            pitch(v, 0.16 * up - 0.04 * out, 0.6)
            lift_legs(v, 0.7 * up, 0.0)
            v.bob.pos += f * 5.0 * out
            hr = -0.3 * up + 0.4 * out
            hd = f * 6.0 * out + float2 { 0.0, 2.0 * out }
        case "stab":
            pitch(v, 0.05 * up - 0.1 * out, 0.6)
            v.bob.pos += f * 2.0 * out
            hr = -0.4 * up + 0.75 * out
            hd = -f * 1.5 * up + (f * 2.5 + float2 { 0.0, 1.5 }) * out
        case "strike":
            pitch(v, 0.1 * up - 0.06 * out, 0.6)
            v.bob.pos += f * 4.0 * out
            hr = -0.35 * up + 0.8 * out
            hd = -f * 1.0 * up + f * 2.5 * out
        default: pass()
    let hn = v.head_node
    if hn:
        hn.rot += hr * sg * max(abs(f.x), 0.35)
        hn.pos += hd

def beast_fall(v:UV, kind:string, t:float):
    let sg = sgn(v)
    let h = hip_height(v)
    let sink = smoothstep(0.0, 0.35, t)
    let fly = smoothstep(0.15, 0.75, t)
    for(v.crew) c:
        if c.thrown:
            let to = float2 { c.thrown_at.x + v.die_tip * (abs(c.thrown_at.y) * 1.2 + 14.0), 4.0 }
            c.node.pos = c.thrown_at + (to - c.thrown_at) * fly + float2 { 0.0, -rsin(fly * PI) * 10.0 }
    let hn = v.head_node
    switch kind:
        case "side":
            for(v.legs) l: l.node.scl = float2 { l.node.scl.x, 1.0 - 0.25 * sink }
            v.bob.pos += float2 { 0.0, h * 0.22 * sink }
            var e = clampf((t - 0.3) / 0.55, 0.0, 1.0)
            e = e * e
            let settle = 0.07 * rsin(clampf((t - 0.85) / 0.3, 0.0, 1.0) * PI)
            v.bob.rot += v.die_tip * (1.4 * e - settle)
            for(v.legs) l: l.node.rot += v.die_tip * 0.35 * e * (if l.phase < PI * 0.5: 1.0 else: -0.6)
            if hn: hn.rot += 0.35 * sink * sg
        case "curl":
            v.bob.pos += float2 { 0.0, h * 0.75 * sink }
            let c = smoothstep(0.15, 0.65, t)
            let twitch = rsin(t * 38.0) * 0.12 * clampf((t - 0.6) / 0.1, 0.0, 1.0) * (1.0 - clampf((t - 0.95) / 0.25, 0.0, 1.0))
            for(v.legs) l:
                let outward = if abs(l.node.pos.x) > 1.0: signf(l.node.pos.x) else: sg
                l.node.rot = -outward * (1.15 * c + twitch)
                l.node.scl = float2 { l.node.scl.x, 1.0 - 0.45 * c }
            if hn: hn.rot += 0.4 * sink * sg
            v.bob.rot += v.die_tip * 0.08 * c
        case "topple":
            for(v.legs) l:
                l.node.scl = float2 { l.node.scl.x, 1.0 - 0.45 * sink }
                l.node.rot += (if l.phase < 1.0: 0.5 else: -0.4) * sink * sg
            v.bob.pos += float2 { 0.0, h * 0.4 * sink }
            pitch(v, -0.25 * sink, 0.6)
            let e = clampf((t - 0.3) / 0.45, 0.0, 1.0)
            v.bob.rot += v.die_tip * 1.35 * e * e
            if hn: hn.rot += 0.9 * smoothstep(0.1, 0.7, t) * sg
        case "fold":
            for(v.legs) l:
                l.node.scl = float2 { l.node.scl.x, 1.0 - 0.6 * sink }
                l.node.rot += signf(if abs(l.node.pos.x) > 1.0: l.node.pos.x else: sg) * 0.5 * sink
            v.bob.pos += float2 { 0.0, h * 0.55 * sink }
            if hn: hn.rot += 0.8 * smoothstep(0.15, 0.7, t) * sg
            v.bob.rot += v.die_tip * 0.2 * smoothstep(0.3, 0.8, t)
        default: pass()

// How far to move the body so its lowest foot stays where it stands (the walk rides on its planted
// foot); false before the legs are baked.
def planted(v:UV, full_length:bool) -> float, bool:
    var rest_low = -1000000000.0
    var now_low = -1000000000.0
    for(v.legs) l:
        if not l.cling:
            let n = l.node
            if not has_bake_of(n, ""): return 0.0, false
            if l.steps > 0 and not has_bake_of(n, l.base + l.cut): return 0.0, false
            let now = soles_of(n, "")
            let rest = if l.steps > 0: soles_of(n, l.base + l.cut) else: now
            let t = xf_local(n)
            let n0 = VNode {}
            n0.pos = n.pos
            n0.scl = if full_length: float2 { n.scl.x, l.reach } else: n.scl
            let t0 = xf_local(n0)
            for(now) p: now_low = max(now_low, xf_apply(t, p).y)
            for(rest) p: rest_low = max(rest_low, xf_apply(t0, p).y)
    if now_low == -1000000000.0: return 0.0, false
    return rest_low - now_low, true

def attack(v:UV, a:float):
    let k = rsin(a * PI)
    let fwd = forward(v)
    let w = v.weapon
    if v.attack_kind == "loose":
        v.bob.rot += 0.12 * (1.0 - a) * signf(if fwd.x != 0.0: fwd.x else: 1.0)
        v.bob.pos += fwd * 3.0 * (1.0 - a)
        if w:
            w.rot = v.weapon_rot + 0.2 * (1.0 - a)
            w.pos = v.weapon_rest + fwd * 2.0 * (1.0 - a)
        return
    v.bob.pos += fwd * 6.0 * k
    v.bob.rot += 0.14 * k * signf(if fwd.x != 0.0: fwd.x else: 1.0)
    if v.legs.length == 2:
        v.legs[0].node.rot += -0.5 * k
        v.legs[1].node.rot += 0.3 * k
    elif v.legs.length >= 4:
        for(v.legs) l: l.node.rot += (if l.node.pos.x > 0.0: 0.25 else: -0.2) * k
    if v.harnessed:
        let hn = v.head_node
        if hn: hn.rot = 0.6 * k
        return
    if not w: return
    if v.thrusts:
        let out = clampf((a - 0.2) / 0.25, 0.0, 1.0) * (1.0 - clampf((a - 0.75) / 0.25, 0.0, 1.0))
        set_hold(v, if out > 0.0: "thrust" else: "low")
        let w2 = v.weapon
        if not w2: return
        let tr = rig_or(w2.part_id + facing_suffix(v.facing_k), w2.part_id)
        let tip = if has(tr, "tip"): v2(at(tr, "tip")) else: float2_0
        let lvl = if tip == float2_0: v.weapon_rot else: vangle(fwd) - vangle(tip)
        w2.rot = lerp_angle(v.weapon_rot, lvl, out)
        w2.pos = v.weapon_rest + fwd * 9.0 * out
        return
    if a < 0.35:
        set_hold(v, "raise")
        w.rot = v.weapon_rot - 1.1 * (a / 0.35)
    elif a < 0.8:
        set_hold(v, "reach")
        w.rot = v.weapon_rot + lerpf(-0.4, 0.9, (a - 0.35) / 0.45)
    else:
        set_hold(v, "low")
        w.rot = v.weapon_rot + lerpf(0.9, 0.0, (a - 0.8) / 0.2)

def die_pose(v:UV):
    let t = v.die_t
    v.die_offset = float2_0
    if v.corpse: corpse_fall(v, t)
    elif v.flying:
        let drop = min(t / 0.3, 1.0)
        v.bob.pos = float2 { v.bob.pos.x, lerpf(v.bob.pos.y, 0.0, drop) }
        let a = clampf((t - 0.3) / 0.35, 0.0, 1.0)
        v.visual.rot = v.die_tip * a * a * 1.45
    elif v.legs.length >= 4:
        let a = min(t / 0.4, 1.0)
        let e = a * a * (3.0 - 2.0 * a)
        for(v.legs) l: l.node.scl = float2 { l.node.scl.x, 1.0 - 0.7 * e }
        v.bob.pos += float2 { 0.0, hip_height(v) * 0.7 * e }
        v.bob.rot += 0.3 * e
        let hn = v.head_node
        if hn: hn.rot = 0.6 * e
        let sn = v.seat_node
        if sn: sn.rot = 0.7 * e
    else:
        let a = min(t / 0.4, 1.0)
        let e = 1.0 - (1.0 - a) * (1.0 - a)
        v.visual.rot = -1.45 * e + 0.12 * rsin(clampf((t - 0.4) / 0.25, 0.0, 1.0) * PI)
        if v.legs.length == 2:
            v.legs[0].node.rot += -0.4 * e
            v.legs[1].node.rot += 0.2 * e

def corpse_fall(v:UV, t:float):
    let up = clampf(t / CORPSE_AT[CORPSE_AT.length - 1], 0.0, 1.0)
    v.die_offset = float2 { 0.0, -rsin(up * PI) * HOP_HEIGHT * 0.6 }
    let cp = v.corpse_pose
    let c = v.corpse
    if not cp or not c: return
    let frames = glist(cp, "frames")
    var shown = -1
    for(frames) f, i:
        if i < CORPSE_AT.length and t >= CORPSE_AT[i]: shown = i
    if shown < 0: return
    let id = corpse_id(v.recipe, cp, as_int(frames[shown]))
    if c.part_id == id: return
    c.part_id = id
    c.visible = true
    for(v.visual.kids) k: k.visible = k == c
    if shown == frames.length - 1:
        v.shadow.part_id = id + "~shadow"
        v.shadow.facing = v.facing_k
        part_setup(v.shadow, [], Colours { dictionary<string, string>(3), float3_1 })
        v.shadow.scl = float2 { v.unit_scale * v.facing, v.unit_scale }

def hop(v:UV, ph:float, stride:float):
    let p = if stride > 0.0: fposmod(ph / TAU, 1.0) else: 0.0
    var s = 1.0
    var d = 0.0
    var i = 1
    while i < HOP_KEYS.length:
        if p <= HOP_KEYS[i][0]:
            let a = HOP_KEYS[i - 1]
            let b = HOP_KEYS[i]
            let w = smoothstep(a[0], b[0], p)
            s = lerpf(a[1], b[1], w)
            d = lerpf(a[2], b[2], w)
            break
        i++
    let fwd = forward(v)
    var depth = 0.0
    let reach = map(v.legs) l:
        var low = 0.0
        if has_bake_of(l.node, ""):
            for(soles_of(l.node, "")) q: low = max(low, q.y)
        low * l.reach
    for(reach) r: depth = max(depth, r)
    for(v.legs) l, n:
        let h = reach[n]
        let k = if h > 0.0: max(1.0 - (1.0 - s) * depth / h, 0.2) else: s
        l.node.rot = -rasin(clampf(d * fwd.x, -0.9, 0.9))
        l.node.scl = float2 { l.node.scl.x, l.reach * (k + d * fwd.y) }
    var lift = 0.0
    var tilt = 0.0
    if p > HOP_UP and p < HOP_DOWN:
        let q = (p - HOP_UP) / (HOP_DOWN - HOP_UP)
        lift = rsin(q * PI) * HOP_HEIGHT
        tilt = -0.2 * rsin(q * TAU) * fwd.x
    let plant, ok = planted(v, true)
    v.bob.pos = float2 { v.bob.pos.x, (if ok: plant else: 0.0) - lift }
    v.bob.rot = tilt

def hop_f(v:UV, p0:float) -> float:
    var p = p0
    if v.pose_steps > 0: p = floor(p * float(v.pose_steps)) / float(v.pose_steps)
    let q = clampf((p - HOP_UP) / (HOP_DOWN - HOP_UP), 0.0, 1.0)
    return lerpf(q, q * q * (3.0 - 2.0 * q), 0.5)

def hop_advance(v:UV, dt:float):
    let D = HOP_LENGTH * sqrt(v.unit_scale)
    var m = float2_0
    if v.has_hop_last: m = (v.node.pos - v.hop_last) / max(v.node.scl.x, 0.0001)
    v.hop_last = v.node.pos
    v.has_hop_last = true
    var ground = vlen(float2 { m.x, m.y * 2.0 })
    if ground > D:
        m = float2_0
        ground = 0.0
        v.hop_off = float2_0
    let p0 = fposmod(v.phase / TAU, 1.0)
    let moving = v.walking and ground > 0.0
    var dp = 0.0
    if moving:
        dp = ground / D
        v.hop_aim = m / dp
        v.hop_rate = if dt > 0.0: dp / dt else: v.hop_rate
    elif v.walking: dp = dt * v.speed_px / D
    elif p0 != 0.0:
        dp = dt * (if v.hop_rate > 0.0: v.hop_rate else: v.speed_px / D)
        if p0 < HOP_UP and vlen(v.hop_off) < 1.0:
            v.hop_off = vmove_toward(v.hop_off, float2_0, HOP_SETTLE * v.unit_scale * dt)
            v.phase = max(p0 - dp, 0.0) * TAU
            return
    var p1 = p0 + dp
    let f0 = hop_f(v, p0)
    let f1 = if p1 < 1.0: hop_f(v, p1) else: 1.0 + hop_f(v, p1 - 1.0)
    let aim = if moving: v.hop_aim else: float2_0
    let c = hop_bias(v)
    if f1 > f0 and f0 < 1.0:
        let left = v.hop_off - aim * (f0 - p0 + c)
        v.hop_off = aim * (f1 - p1 + c) + left * (1.0 - min(f1, 1.0)) / (1.0 - f0)
    elif moving: v.hop_off -= m
    elif not v.walking and (f0 >= 1.0 or p0 == 0.0): v.hop_off = vmove_toward(v.hop_off, float2_0, HOP_SETTLE * v.unit_scale * dt)
    if not v.walking and p1 >= 1.0: p1 = 0.0
    v.phase = fposmod(p1, 1.0) * TAU

def hop_bias(v:UV) -> float:
    if v.hop_bias_for != v.pose_steps:
        var sum = 0.0
        for(1000) i:
            let p = (float(i) + 0.5) / 1000.0
            sum += p - hop_f(v, p)
        v.hop_bias_for = v.pose_steps
        v.hop_bias_v = sum / 1000.0
    return v.hop_bias_v

def work(v:UV, t:float, stepped:bool):
    if has_s(CHORES, v.job):
        chore(v, t, stepped)
        return
    let period = switch v.job:
        case "forage": 1.1
        case "chop": 0.9
        case "mine": 1.0
        case "build": 0.5
        default: 1.3
    var p = fmodf(t / period + float(v.noise.seed % 7) * 0.13, 1.0)
    if stepped: p = floor(p * 6.0) / 6.0
    let land = if v.job == "forage": 0.5 else: 0.72
    v.struck = (v.work_p < land and p >= land) or (p < v.work_p and (v.work_p < land or p >= land))
    v.work_p = p
    var swing = 0.0
    var lean = 0.0
    var crouch = 0.0
    var hold = "low"
    var head = 0.0
    let w = v.weapon
    if v.job == "forage":
        let k = rsin(p * TAU) * 0.5 + 0.5
        hold = if p < 0.5: "reach" else: "low"
        lean = 0.04 + 0.12 * k
        crouch = 2.0 * k
        swing = 0.3 * k - 0.1 * (1.0 - k)
        head = 0.7 * k
        if w and v.work_hold == "low": w.pos = v.weapon_rest + float2 { 3.0, 4.0 } * k
    else:
        let up = if v.job == "build": 0.9 elif v.job == "till": 0.7 else: 1.2
        let wind = if v.job != "build": 0.6 else: 0.5
        let hit = if v.job != "build": 0.75 else: 0.65
        if p < wind:
            hold = "raise"
            let q = p / wind
            swing = -up * (0.7 + 0.3 * q)
            lean = -0.06 - 0.02 * q
            head = -0.5 - 0.2 * q
            crouch = if v.harnessed: -1.0 * q else: 0.0
        elif p < hit:
            let q = (p - wind) / (hit - wind)
            hold = if p < land: "low" else: "reach"
            swing = lerpf(-up * 0.4, if v.job != "build": 0.9 else: 0.5, q)
            lean = lerpf(0.02, 0.14, q)
            head = lerpf(0.3, 0.8, q)
            crouch = lerpf(0.5, 1.5, q)
        else:
            let q = (p - hit) / (1.0 - hit)
            hold = if p < 0.9: "reach" else: "low"
            swing = lerpf(if v.job != "build": 0.9 else: 0.5, 0.0, q)
            lean = lerpf(0.14, 0.0, q)
            head = lerpf(0.8, 0.0, q)
            crouch = lerpf(1.5, 0.0, q)
    if v.harnessed:
        lean = lean * 1.6
        crouch = crouch * 1.4
        swing = 0.0
        let hn = v.head_node
        if hn: hn.rot = head
        let w2 = v.weapon
        if w2: w2.pos = v.weapon_rest
    else:
        set_hold(v, hold)
        crouch *= 0.5
    let w3 = v.weapon
    if w3: w3.rot = v.weapon_rot + swing
    if has(v.recipe, "mount") and gbool(at(v.recipe, "mount"), "fused", false) and v.job == "forage": return
    v.bob.rot += lean * side_on(v.facing_k)
    v.bob.pos += float2 { 0.0, crouch }

def chore(v:UV, t:float, stepped:bool):
    v.struck = false
    let period = switch v.job:
        case "sweep": 1.2
        case "sit": 5.0
        case "chat": 2.6
        default: 4.0
    var p = fmodf(t / period + float(v.noise.seed % 5) * 0.21, 1.0)
    if stepped: p = floor(p * 8.0) / 8.0
    let hn = v.head_node
    let w = v.weapon
    switch v.job:
        case "sweep":
            let k = rsin(p * TAU)
            if not v.harnessed: set_hold(v, "reach")
            let w2 = v.weapon
            if w2: w2.rot = v.weapon_rot + 0.35 + 0.3 * k
            v.bob.rot += 0.1 + 0.03 * abs(k)
            v.bob.pos += float2 { 0.0, 0.5 }
            if hn: hn.rot = 0.35
        case "sit":
            if v.gait.hops:
                v.bob.pos += float2 { 0.0, 1.5 }
                if hn: hn.rot = if p < 0.5: -0.15 else: 0.1
            elif v.legs.length >= 4 or v.harnessed:
                for(v.legs) l: l.node.scl = float2 { l.node.scl.x, 0.45 }
                v.bob.pos += float2 { 0.0, leg_len(v) * 0.55 }
                if hn: hn.rot = if p > 0.6: 0.25 else: 0.0
            else:
                for(v.legs) l: l.node.rot = -1.35 + 0.08 * l.phase
                v.bob.pos += float2 { 0.0, leg_len(v) * 0.8 }
                v.bob.rot -= 0.08
                if hn: hn.rot = if p < 0.7: -0.1 else: 0.12
        case "chat":
            let talk = p < 0.55
            if hn: hn.rot = if talk: 0.12 * rsin(p * TAU * 6.0) else: -0.08
            v.bob.rot += 0.03 * rsin(p * TAU)
            if talk and w and not v.harnessed and p > 0.2 and p < 0.4:
                w.rot = v.weapon_rot - 0.35
                w.pos = v.weapon_rest + float2 { 1.0, -2.0 }
        default:
            let down = p < 0.7
            if hn: hn.rot = if down: 0.95 else: 0.05
            v.bob.rot += if down: 0.08 else: 0.0

def span_of(n:VNode) -> [float2]:
    let s = bake_spans.get(bake_key_of(n, ""))
    if s: return s
    return [float2_0, float2 { 0.0, -n.pos.y }]

def kneel_tick(v:UV, dt:float):
    let want = if v.job == "forage" and not v.walking and has(v.recipe, "mount") and gbool(at(v.recipe, "mount"), "fused", false): 1.0 else: 0.0
    if not v.kneel_seen:
        v.kneel_seen = true
        v.kneel_want = want
        v.kneel_from = want
        v.kneel_at = v.time
    if want != v.kneel_want:
        v.kneel_want = want
        v.kneel_from = v.kneel
        v.kneel_at = v.time
    v.kneel = move_toward(v.kneel_from, want, max(0.0, v.time - v.kneel_at) * 3.0)
    let sn = v.seat_node
    if v.kneel <= 0.0 or v.legs.length < 4:
        for(v.legs) l:
            let sh = l.shin
            if sh: sh.visible = false
        if sn and sn.has_seat_rest:
            sn.rot = 0.0
            sn.pos = sn.seat_rest
        return
    if sn and not sn.has_seat_rest:
        sn.has_seat_rest = true
        sn.seat_rest = sn.pos
    let ahead = ahead_on_screen(v.facing_k)
    let side = side_on(v.facing_k)
    let hind_x = []::float
    for(v.legs) l:
        if not l.fore: hind_x.push(l.rest.x)
        else:
            let upper = 1.0 - 0.45 * v.kneel
            l.node.scl = float2 { l.node.scl.x, upper }
            l.node.rot += 0.1 * v.kneel * side
            var shin = l.shin
            if not shin:
                let s = new_part(l.node.part_id)
                s.facing = l.node.facing
                s.shade = l.node.shade
                part_setup(s, l.node.pshapes, l.node.cols or SHADOW_COLOURS)
                s.z = l.node.z
                add_sibling(l.node, s)
                l.shin = s
                shin = s
            if shin:
                shin.visible = v.kneel > 0.03
                if not l.span: l.span = span_of(l.node)
                let sp = l.span or []::float2
                let top = sp[0]
                let low = sp[1]
                let sx = l.node.scl.x
                let knee = l.node.pos + rot2(float2 { low.x * sx, low.y * upper }, l.node.rot)
                let fold = -ahead * 0.5 + float2 { 0.0, 0.06 }
                shin.rot = lerp_angle(0.0, ratan2(-fold.x, fold.y), v.kneel)
                shin.scl = float2 { sx, vlen(fold) * low.y / max(low.y - top.y, 1.0) }
                shin.pos = knee - rot2(float2 { top.x * sx, top.y * shin.scl.y }, shin.rot)
                let z = l.node.z
                let want_z = if ahead.y > 0.2: -2.5 else: z
                if shin.z != want_z:
                    shin.z = want_z
                    let sp2 = shin.parent
                    if sp2: sort_layers(sp2)
    let a = 0.17 * v.kneel * side
    var px = 0.0
    if hind_x.length:
        for(hind_x) x: px += x
        px /= float(hind_x.length)
    let pivot = float2 { px, 0.0 }
    v.bob.rot += a
    v.bob.pos += pivot - rot2(pivot, a)
    if sn:
        sn.rot = -0.4 * v.kneel * side
        sn.pos = sn.seat_rest - ahead * 1.5 * v.kneel + float2 { 0.0, KNEEL_DIP * v.kneel * (1.0 - abs(side)) }

def pose_tick(v:UV, dt:float):
    if not v.idle_poses.length: return
    let busy = v.walking or v.attack_t > 0.0 or v.dying or v.job != ""
    v.still = if busy: 0.0 else: v.still + dt
    let steps = [""]
    for(v.idle_poses) p: steps.push(p)
    var now = 0
    for(steps) s, i:
        if s == v.body_pose: now = i
    let want = if v.still >= v.sit_after: steps.length - 1 else: 0
    v.pose_t += dt
    if now == want:
        v.pose_t = 0.0
        return
    if v.pose_t < (if want > now: POSE_DOWN else: POSE_UP) and not (busy and now == steps.length - 1): return
    v.pose_t = 0.0
    v.body_pose = steps[now + (if want > now: 1 else: -1)]
    rebuild(v)

def idle(v:UV, dt:float):
    if v.idle_left > 0.0:
        v.idle_left -= dt
        switch v.idle_kind:
            case "shift":
                v.bob.pos += float2 { 0.0, 1.0 / max(v.art_px, 1.0) }
                v.bob.rot += 0.03
            case "look":
                let hn = v.head_node
                if hn: hn.rot = -0.18
            case "lift":
                let w = v.weapon
                if w and not v.harnessed:
                    w.rot = -0.3
                    w.pos = v.weapon_rest + float2 { 0.0, -1.5 }
            case "settle": v.bob.rot -= 0.04
            default: pass()
        return
    v.idle_wait -= dt
    if v.idle_wait <= 0.0:
        v.idle_kind = ["shift", "look", "lift", "settle"][randi(v.noise) % 4]
        v.idle_left = randf_range(v.noise, 0.5, 1.2)
        v.idle_wait = randf_range(v.noise, 2.5, 7.0)

// ---- drawing: every part in draw order, its bake key, its transform from texture px, its alpha

class Draw:
    key:string
    xf:[float]
    alpha:float

def draw_list(v:UV, root_xf:[float]) -> [Draw]:
    let out = []::Draw
    draw_walk(v.node, xf_mul(root_xf, xf_local(v.node)), 1.0, out)
    return out

def draw_walk(n:VNode, g:[float], alpha:float, out:[Draw]) -> void:
    if not n.visible: return
    let a = alpha * n.alpha
    if n.part:
        let key = draw_key(n)
        let b = bakes.get(key)
        if b:
            let s = 1.0 / b.scale
            out.push(Draw { key, xf_mul(g, [s, 0.0, 0.0, s, -b.ox * s, -b.oy * s]), a * n.shade })
        else: out.push(Draw { key + " missing", g, a })
    for(n.kids) c: draw_walk(c, xf_mul(g, xf_local(c)), a, out)
