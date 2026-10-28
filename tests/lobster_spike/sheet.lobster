// The concept sheet tool in Lobster (tests/sheet.gd): one tool for every art round. A small spec
// (tests/sheets/<name>.json, its whole format in sheet.gd's header) lists the rows, the columns, size
// references, zooms and labels; every unit is composed by the Lobster composer (view/unit_view.lobster)
// from parts baked here on demand (view/part_bake.lobster, the bake cache), laid out on a labelled sheet per
// spec sheet and zoom. Each row goes through sheet_row_check (the placement check's place: PASS/FAIL per
// row, a failing row framed red with the rules it broke, exit 1 if any fails). Run through sheet.sh:
//   tests/lobster_spike/sheet.sh tests/sheets/<spec>.json <out dir> [sheet,...|all] [zoom,...|all] [nocheck] [cache:<dir>]
// Writes <out dir>/<spec name>_<sheet>_<zoom>x.png (zoom 1 is the game's scale, 3 a close-up).
// What has no Lobster side yet is said ("not yet: ...") and left out, not a crash.

import std
import vec
import color
import gl
import texture
import dictionary
import .gen.json
import .gen.rng
import .gen.sha256
import .gen.datalib
import .gen.identity
import .gen.effect_words
import .gen.mods
import .gen.pricing
import .gen.heroes
import .gen.generator
import .view.node
import .view.art
import .view.unit_view
import .game.audio
import .game.pack
def ui() -> float: return 1.0   // (the UI's scale, which game/ui.lobster asks the game for)
import .game.ui
import .game.fx
import .view.baker
import .model.kit
import .model.grng
import .model.base
import .model.flat
import .model.glb
import .model.props
import .model.build_mats
import .model.units
import .model.units2
import .model.units3
import .model.units4
import .model.units5
import .model.kit_bodies
import .model.siege
import .model.heroes
import .model.bears
import .model.mods_active
import .model.models
import .view.part_bake
import .view.geom
import .view.rig3d
import .view.stage
import .view.corpse
import .placement.geometry
import .placement.composite
import .placement.cases
import .placement.fixtures3d
import .placement.projection
import .placement.case2d
import .placement.fixtures2d

let BG = float4 { 0.337, 0.471, 0.180, 1.0 }    // #56782e
let STRIKE_MS = [0, 120, 210, 280, 340, 450]     // frames of a blow (UnitView.flourish)
let FALL_MS = [0, 200, 400, 600, 850, 1200]      // frames of a death (UnitView.die)
let FACING_NAMES = ["f0 right", "f1", "f2 towards", "f3", "f4 left", "f5", "f6 away", "f7"]
let ART_SCALE = 1.5
let UNIT_SCALE = 0.85
let TEXT_SCALE = 1.25                            // (Godot's labels look this much bigger at the same font size)
let TEXT = float4 { 0.957, 0.945, 0.910, 1.0 }   // #f4f1e8

// A unit on the sheet: a recipe and its eval, or one lone part with its colours.
class SUnit:
    recipe:JV
    eval:JV
    concept:JV
    tip:float
    part:string
    colours:Colours?

class SRow:
    label:string
    unit:SUnit
    other:SUnit?
    h:float
    expect:[string]

// A column: [facing, pose (stand, walk, hold, an idle pose, strike, fall, loose, corpse), step, steps, hold, other, label].
class SCol:
    facing:int
    pose:string
    step:int
    steps:int
    hold:string
    other:bool
    label:string

let args = command_line_arguments()
assert args.length >= 2
let spec_path = if read_file(args[0]): args[0] else: "../../" + args[0]
let spec = load_json(spec_path)
let out_dir = args[1]
let only = if args.length > 2 and args[2] != "all" and args[2] != "nocheck" and find_string(args[2], ":") < 0: tokenize(args[2], ",", " ") else: []::string
let zoom_arg = if args.length > 3 and args[3] != "all" and args[3] != "nocheck" and find_string(args[3], ":") < 0: tokenize(args[3], ",", " ") else: []::string
let check_rows = not has_s(args, "nocheck")
for(args) a:   // cache:<dir>: keep the bakes there (a folder under tests/lobster_spike that exists) instead of bake_cache
    if starts_with(a, "cache:"): bake_cache_dir = a.substring(6, a.length - 6)
let not_yet = []::string             // what the Lobster side can't draw yet, said once each

def say_not_yet(s:string):
    if not has_s(not_yet, s):
        not_yet.push(s)
        print "not yet: {s}"

def spec_name() -> string:
    if has(spec, "name"): return rstr(spec, "name")
    let leaf = tokenize(spec_path, "/", "")
    let f = leaf[leaf.length - 1]
    return f.substring(0, f.length - 5)

fatal(gl.window("sheet", 320, 200, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(BAKE_SHADERS, true))
check(gl.set_font_name("data/fonts/Droid_Sans/DroidSans.ttf"), "no font")
lib_load("../../data")
if has(spec, "mods"):
    let used = mods_use(gstrs(spec, "mods"))
    print "mods: {used}"
id_load("../../data")
complete_kit_parts()
kit_load()
let team_hex = hex_of(as_str(glist(lib_palettes, "teams")[0]))
let team = rgb_of(team_hex)
let rules_id = gstr(spec, "rules", "default")

// ------------------------------------------------------------------ staging (CreatureKit.stage)

// A data file staged into the lib first (view/stage.lobster): kits, kit parts completed, creatures, skins, words.
def stage(path:string):
    stage_file(path)
    for(staged_unmodelled) m: say_not_yet("the staged GDScript model {m} (its parts draw only if a Lobster model has them)")

for(gstrs(spec, "stage")) f: stage(f)

// ------------------------------------------------------------------ rows and units

let races = dictionary<string, JV>(31)
def race_of(prompt:string, rid:string) -> JV:
    let key = prompt + "|" + rid
    let have = races.get(key)
    if have: return have
    let r = generate(prompt, load_rules(rid), 0)
    races.set(key, r)
    return r

def ref_rules(ref:JV) -> string: return gstr(ref, "rules", rules_id)

def has_slot(ref:JV) -> bool:
    return exists(glist(race_of(rstr(ref, "prompt"), ref_rules(ref)), "units")) u: rstr(at(u, "recipe"), "slot") == rstr(ref, "slot")

// A creature-kit creature with some of its kit's parameters changed (sheet.gd _variant): a kit of its own
// (new part ids), its body part completed from it, a creature copy wearing it.
let variants = dictionary<string, string>(15)
def variant(ref:JV) -> string:
    let sig = stringify(jarr([at(ref, "kit"), at(ref, "params"), jstr(gstr(ref, "creature", ""))]))
    let have = variants.get(sig)
    if have: return have
    let tag = "_v" + sha256_text(sig).substring(0, 6)
    let kname = rstr(ref, "kit")
    let base = kit_kits.get(kname)
    assert base
    let k = kit_merge(base, at(ref, "params"))
    let kp = at(k, "parts")
    for(kp.keys) role, n: kp.a[n] = jstr(as_str(at(at(base, "parts"), role)) + tag)
    kit_register(kname + tag, k)
    let body = deep_copy(part(rstr(at(base, "parts"), "body")))
    set(body, "id", at(kp, "body"))
    set(body, "kit", jstr(kname + tag))
    kit_stubs(body)
    set(lib_parts, rstr(body, "id"), body)
    lib_part_ids = sorted_strs(lib_parts.keys)
    let cid = rstr(ref, "creature")
    let c = deep_copy(creature(cid))
    let mb = gbool(ref, "mount_body", false)
    set(c, if mb: "mount_body" else: "body", at(body, "id"))
    if has(k, "head") and has(base, "head"): set(c, if mb: "mount_head" else: "head", at(kp, "head"))
    set(lib_creatures, cid + tag, c)
    variants.set(sig, cid + tag)
    return cid + tag

// Which of a recipe's parts have a 3D model (UnitModelsCheck.has: body armour is worn on a modelled body);
// with no pack to say so, asked of the models here.
def mark_modelled(r:JV):
    let ids = [gstr(r, "body", "")]
    let rp = gobj(r, "parts")
    for(rp.a) v: if v.kind == J_STR: ids.push(v.s)
    for(ids) id:
        if id != "" and not modelled.get(id, 0) and build_model(id, colours_for("human_tan", "hellenic", team)): modelled.set(id, 1)
    if has(r, "mount"):
        let mc = creature(rstr(at(r, "mount"), "creature"))
        for([gstr(mc, "mount_body", rstr(mc, "body")), gstr(mc, "fused_body", "")]) id:
            if id != "" and not modelled.get(id, 0) and build_model(id, colours_for("human_tan", "hellenic", team)): modelled.set(id, 1)

// A unit ref -> a unit (sheet.gd _unit).
def unit_of(ref:JV) -> SUnit:
    if has(ref, "part"):
        let cols = colours_for(gstr(ref, "skin", "human_tan"), gstr(ref, "family", "hellenic"), team)
        return SUnit { jobj(), jobj(), jobj(), 1.0, rstr(ref, "part"), cols }
    var recipe = jobj()
    var eval = jobj()
    if has(ref, "prompt"):
        let race = race_of(rstr(ref, "prompt"), ref_rules(ref))
        let found = filter(glist(race, "units")) x:
            rstr(at(x, "recipe"), "slot") == rstr(ref, "slot") and (not has(ref, "hero") or gstr(at(x, "recipe"), "hero", "") == rstr(ref, "hero"))
        if not found.length: print "sheet: " + rstr(ref, "prompt") + " has no " + rstr(ref, "slot") + " line"
        assert found.length
        let line = glist(found[0], "line")
        var step = line[0]
        for(line) l:
            if as_int(at(l, "age")) <= gint(ref, "age", 1): step = l
        recipe = deep_copy(at(step, "recipe"))
        eval = at(step, "eval")
    else:
        let cid = if has(ref, "kit"): variant(ref) else: rstr(ref, "creature")
        let c = creature(cid)
        let mb = gbool(ref, "mount_body", false)
        set(recipe, "slot", jstr("beast"))
        set(recipe, "role", jstr("beast"))
        set(recipe, "tier", jint(1))
        set(recipe, "creature", jstr(cid))
        set(recipe, "family", glist(c, "families")[0])
        set(recipe, "skin", jstr(gstr(ref, "skin", as_str(glist(c, "skins")[0]))))
        set(recipe, "body", jstr(if mb: gstr(c, "mount_body", rstr(c, "body")) else: rstr(c, "body")))
        set(recipe, "head", jstr(if mb: gstr(c, "mount_head", rstr(c, "head")) else: rstr(c, "head")))
        set(recipe, "parts", jobj())
        set(recipe, "scale", jint(100))
        set(recipe, "name", at(c, "noun"))
        set(eval, "speed", jint(10))
    let sets = gobj(ref, "set")
    for(sets.keys) k, n: set(recipe, k, deep_copy(sets.a[n]))
    if has(ref, "push"): recipe = push_recipe(recipe, rstr(ref, "push"))
    if has(ref, "prompt") and has(ref, "kit"):   // the race's unit on a kit variant of its creature
        let vc = variant(ref)
        set(recipe, "creature", jstr(vc))
        set(recipe, "body", at(creature(vc), "body"))
        set(recipe, "head", at(creature(vc), "head"))
    let adds = gobj(ref, "add_parts")
    for(adds.keys) k, n: set(at(recipe, "parts"), k, deep_copy(adds.a[n]))
    if has(ref, "mount"):
        let m = at(ref, "mount")
        var mcid = gstr(m, "creature", "")
        if has(m, "kit"):
            let mm = deep_copy(m)
            set(mm, "mount_body", jbool(true))
            mcid = variant(mm)
        let mo = jobj()
        set(mo, "creature", jstr(mcid))
        set(mo, "fused", jbool(false))
        set(mo, "parts", deep_copy(gobj(m, "parts")))
        set(mo, "skin", jstr(gstr(m, "skin", as_str(glist(creature(mcid), "skins")[0]))))
        set(recipe, "mount", mo)
    let concept = gobj(ref, "concept")
    mark_modelled(recipe)
    return SUnit { recipe, eval, concept, if has(ref, "tip"): as_float(at(ref, "tip")) else: 1.0, "", nil }

// Text with "{prompt}", "{slot}", "{name}" filled in.
def fill(s:string, keys:[string], vals:[string]) -> string:
    var out = s
    for(keys) k, i:
        var at_ = find_string(out, k)
        while at_ >= 0:
            out = out.substring(0, at_) + vals[i] + out.substring(at_ + k.length, out.length - at_ - k.length)
            at_ = find_string(out, k, at_ + vals[i].length)
    return out

def spec_rows() -> [SRow]:
    let out = []::SRow
    for(glist(spec, "rows")) r:
        if has(r, "each"):
            let each = at(r, "each")
            for(gstrs(each, "prompt")) p:
                let slots = []::string
                for(gstrs(each, "slot")) s:   // "heroes": each of the race's heroes, one row each
                    if s == "heroes":
                        for(heroes_info(race_of(p, rules_id))) h: slots.push("hero." + rstr(h, "signature"))
                    else: slots.push(s)
                for(slots) s:
                    let ref = jobj()
                    set(ref, "prompt", jstr(p))
                    set(ref, "slot", jstr(if starts_with(s, "hero."): "hero" else: s))
                    if starts_with(s, "hero."): set(ref, "hero", jstr(s.substring(5, s.length - 5)))
                    set(ref, "age", jint(gint(r, "age", 1)))
                    if not has_slot(ref):
                        print "  (no {s} line for {p})"
                        continue
                    let u = unit_of(ref)
                    let label = fill(gstr(r, "label", "\{prompt\}\n\{name\}"), ["\{prompt\}", "\{slot\}", "\{name\}"], [p, s, gstr(u.recipe, "name", "")])
                    out.push(SRow { label, u, nil, if has(r, "h"): as_float(at(r, "h")) else: 1.0, [] })
            continue
        let other = if has(r, "other"): unit_of(at(r, "other")) else: nil
        out.push(SRow { rstr(r, "label"), unit_of(at(r, "unit")), other, if has(r, "h"): as_float(at(r, "h")) else: 1.0, gstrs(r, "expect") })
    return out

// ------------------------------------------------------------------ placement

// The placement check's verdict on a row's units (placement/: the 3D and the 2D halves, each distinct unit once): the
// rules they fail, "<rule> (<n> views: <the first two>)" (empty: a pass). No silent passes: a unit neither half ran a
// rule on fails its row.
let row_checked = dictionary<string, [string]>(63)   // recipe -> what it failed

def sheet_row_check(label:string, recipes:[JV]) -> [string]:
    check_team = rgb_of(hex_of(as_str(glist(lib_palettes, "teams")[0])))
    let out = []::string
    for(recipes) r, i:
        let sig = stringify(r)
        var got = row_checked.get(sig)
        if not got:
            let lab = "{label}#{i}"
            let fails = []::string
            let mark = check_order.length
            check_unit(lab, r)
            let mid = check_order.length
            check_case2d(lab, r)
            clear_pixel_caches()
            var k = mark
            while k < check_order.length:
                let key = check_order[k]
                let views = check_results.get(key) or []::string
                if views.length: fails.push(tokenize(key, "|", "")[0] + " ({views.length} views: " + concat_string(views.slice(0, min(2, views.length)), ", ") + ")")
                k++
            if mid == mark: fails.push("not covered by the placement check (3D: no rule ran on it)")
            if check_order.length == mid: fails.push("not covered by the placement check (2D: no rule ran on it)")
            row_checked.set(sig, fails)
            got = fails
        for(got or []::string) f: out.push(f)
    return out

// A failure's rule ("ground contact (3 views: ...)" -> "ground contact").
def rule_of(f:string) -> string:
    let at_ = find_string(f, " (")
    return if at_ >= 0: f.substring(0, at_) else: f

// ------------------------------------------------------------------ columns

def columns(sh:JV) -> [SCol]:
    let c = at(sh, "columns")
    if c.kind == J_ARR:
        return map(c.a) o: SCol { gint(o, "facing", 0), gstr(o, "pose", "stand"), gint(o, "step", 0), gint(o, "steps", 8),
                                  gstr(o, "hold", ""), gbool(o, "other", false), gstr(o, "label", "") }
    let s = as_str(c)
    let colon = find_string(s, ":")
    let head = if colon >= 0: s.substring(0, colon) else: s
    let tail = if colon >= 0: s.substring(colon + 1, s.length - colon - 1) else: ""
    let out = []::SCol
    switch head:
        case "facings":
            for(8) k: out.push(SCol { k, "stand", 0, 8, "", false, FACING_NAMES[k] })
        case "idle":
            for(8) k: out.push(SCol { k, if tail == "": "idle" else: tail, 0, 8, "", false, FACING_NAMES[k] })
        case "walk":
            for(tokenize(tail, ",", " ")) k:
                for(4) st: out.push(SCol { string_to_int(k), "walk", st * 2, 8, "", false, "f{k} step {st * 2}" })
        case "cycle":
            for(8) st: out.push(SCol { string_to_int(tail), "walk", st, 8, "", false, "step {st}" })
        case "strike", "fall":
            for(if head == "strike": STRIKE_MS else: FALL_MS) ms:
                let secs = number_to_string(ms / 1000, 10, 1) + "." + number_to_string((ms % 1000) / 10, 10, 2)
                out.push(SCol { string_to_int(tail), head, ms, 1000, "", false, "{head} {secs} s" })
        case "corpse":
            for(8) k: out.push(SCol { k, "corpse", 100, 100, "", false, FACING_NAMES[k] + " down" })
        case "corpse_fall":
            for([0, 25, 50, 75, 100]) f: out.push(SCol { string_to_int(tail), "corpse", f, 100, "", false, "f{tail} {f}%" })
        case "shots":
            for(8) k: out.push(SCol { k, "loose", 0, 8, "", false, FACING_NAMES[k] + " firing" })
        case "holds":
            for(tokenize(tail, ",", " ")) h:
                for([0, 1]) k: out.push(SCol { k, "hold", 0, 8, h, false, "f{k} {h}" })
        default: say_not_yet("the column kind \"{head}\"")
    return out

// ------------------------------------------------------------------ composing units

let no_model = dictionary<string, int>(63)

// The parts under a view (its whole tree) that have no bake yet, baked; how many facings were baked.
def bake_parts(n:VNode) -> int:
    var baked = 0
    if n.part and n.part_id != "" and n.part_id != "unit_shadow":
        let cols = n.cols
        let key = bake_key(n.part_id, n.pshapes, cols, n.size)
        if cols and not bakes.get(key) and not no_model.get(key, 0):
            let before = baked_here
            if bake_model_part(n.part_id, key, cols): baked += baked_here - before + 1
            else:
                no_model.set(key, 1)
                say_not_yet("a Lobster model for {n.part_id} (drawn without it)")
    for(n.kids) k: baked += bake_parts(k)
    return baked

// The unit shadow as Godot bakes it flat (PartShape.bake_flat): a pixel ellipse in the shadow colour.
def bake_shadow():
    let sc = Colours { dictionary<string, string>(3), float3_1 }
    sc.hex.set("shadow", "0f0d08")
    let key = bake_key("unit_shadow", [shadow_shape], sc)
    let r = float2 { 15.0, 4.5 } * BAKE_ART
    let c = float2 { 3.0, 1.0 }
    let w = int(ceiling(r.x * 2.0)) + 2
    let h = int(ceiling(r.y * 2.0)) + 2
    let rows = map(h) y: map(w) x:
        let q = (float2 { float(x), float(y) } + float2_1 * 0.5 - float2_1 - r) / r
        if dot(q, q) <= 1.0: float4 { 0.06, 0.05, 0.03, 0.42 } else: float4_0
    let o = float2_1 + r - c * BAKE_ART
    add_frame(key, gl.create_texture(rows, sprite_formats), w, h, o)

def tick_tree(v:UV, dt:float) -> void:
    uv_process(v, dt)
    for(v.crew) c: tick_tree(c, dt)

// The idle poses the sheet picks from (the body's, or its mount's).
def sheet_idle_poses(r:JV) -> [string]:
    if has(r, "crew"): return []
    var body = rstr(r, "body")
    if has(r, "mount"):
        let mc = creature(rstr(at(r, "mount"), "creature"))
        body = if gbool(at(r, "mount"), "fused", false): gstr(mc, "fused_body", rstr(mc, "body")) else: gstr(mc, "mount_body", rstr(mc, "body"))
    return gstrs(part(body), "idle_poses")

// A concept pose on top of the animation (UnitView._apply_concept): kneel (0..1: the front legs fold, the chest
// dips), pitch (radians, nose down), drop (part units down), head (radians), tool (radians on the hand, tool_dx, tool_dy).
def apply_concept(v:UV, c:JV):
    if not c.keys.length: return
    let kneel = if has(c, "kneel"): as_float(at(c, "kneel")) else: 0.0
    if kneel > 0.0 and v.legs.length >= 4:
        let xs = map(v.legs) l: l.node.pos.x
        qsort_in_place(xs) a, b: a < b
        let mid = (xs[1] + xs[2]) * 0.5
        for(v.legs) l:
            if l.node.pos.x > mid:
                l.node.scl = float2 { l.node.scl.x, 1.0 - 0.55 * kneel }
                l.node.rot = 0.35 * kneel
        v.bob.rot += 0.26 * kneel
        v.bob.pos += float2 { 0.0, 2.5 * kneel }
    if has(c, "pitch"): v.bob.rot += as_float(at(c, "pitch"))
    if has(c, "drop"): v.bob.pos += float2 { 0.0, as_float(at(c, "drop")) }
    let hn = v.head_node
    if hn and has(c, "head"): hn.rot = as_float(at(c, "head"))
    let w = v.weapon
    if w and has(c, "tool"):
        w.rot = v.weapon_rot + as_float(at(c, "tool"))
        w.pos = v.weapon_rest + float2 { if has(c, "tool_dx"): as_float(at(c, "tool_dx")) else: 0.0, if has(c, "tool_dy"): as_float(at(c, "tool_dy")) else: 0.0 }

// One unit in a column's facing and pose, at `at` (sheet world units), as sheet.gd _draw sets it up.
def pose_view(u:SUnit, col:SCol, at_:float2) -> UV:
    let v = uv_new()
    v.facing_k = col.facing
    var pose = col.pose
    let idle = sheet_idle_poses(u.recipe)
    if pose == "idle": pose = if idle.length: idle[idle.length - 1] else: "stand"
    if has_s(idle, pose): v.body_pose = pose
    uv_build(v, u.recipe, team, gint(u.eval, "speed", 10))
    v.node.scl = float2_1 * UNIT_SCALE
    v.node.pos = at_
    v.idle_wait = 1000.0   // (not stepped, no pixel snapping: as sheet.gd draws them)
    v.walking = pose == "walk"
    v.phase = if pose == "walk": TAU * float(col.step) / float(col.steps) else: 0.0
    tick_tree(v, 0.0)
    if pose == "hold" and col.hold != "" and v.body_nodes.length:
        let b0 = v.body_nodes[0]
        let id = rstr(u.recipe, "body") + "@" + col.hold
        let cols = b0.cols
        if cols and not bakes.get(bake_key(id, b0.pshapes, cols, b0.size)): bake_model_part(id, bake_key(id, b0.pshapes, cols, b0.size), cols)
        set_hold(v, col.hold)
    if pose == "strike" or pose == "fall":   // played through the composer's own path, in 60ths of a second
        if pose == "strike": flourish(v) else: die(v, u.tip)
        for(int(float(col.step) * 0.06 + 0.5)): tick_tree(v, 1.0 / 60.0)
    if pose == "loose":
        loose(v)
        uv_process(v, 0.06)
    apply_concept(v, u.concept)
    return v

// The view, built again until every part it draws has been baked (a bake brings the rig its sockets come from).
def compose(u:SUnit, col:SCol, at_:float2) -> UV:
    var v = pose_view(u, col, at_)
    for(4):
        if bake_parts(v.node) == 0: return v
        v = pose_view(u, col, at_)
    return v

// CombatFx.shot_kind (game.lobster shot_kind_of).
def sheet_shot_kind(tags:[string]) -> string:
    for(sorted_strs(mod_shots.keys)) k:
        if has_s(tags, gstr(at(mod_shots, k), "tag", "")): return k
    if has_s(tags, "great_sling"): return "sling_stone"
    if has_s(tags, "catapult"): return "boulder"
    if has_s(tags, "bolt_thrower"): return "siege_bolt"
    if has_s(tags, "javelin"): return "javelin"
    if has_s(tags, "sling"): return "stone"
    if has_s(tags, "poison"): return "dart"
    if has_s(tags, "gun"): return "ball"
    if has_s(tags, "heavy") and has_s(tags, "bow"): return "bolt"
    return "arrow"

// ------------------------------------------------------------------ drawing (meshes: gl.rect and gl.line go astray after a custom shader)

def fill_rect(at_:float2, size:float2, col:float4):
    if size.x <= 0.0 or size.y <= 0.0: return
    gl.set_shader("color_attr")
    gl.render_mesh(gl.new_mesh("PC", [float3 { at_.x, at_.y, 0.0 }, float3 { at_.x + size.x, at_.y, 0.0 }, float3 { at_.x + size.x, at_.y + size.y, 0.0 },
                                      float3 { at_.x, at_.y + size.y, 0.0 }], [col, col, col, col], []::float3, []::float2, []::float2, [0, 2, 1, 0, 3, 2]))

def line_quad(a:float2, b:float2, w:float, col:float4):
    let d = b - a
    let l = magnitude(d)
    if l <= 0.0001: return
    let n = float2 { -d.y, d.x } / l * (w * 0.5)
    gl.set_shader("color_attr")
    gl.render_mesh(gl.new_mesh("PC", [float3 { a.x + n.x, a.y + n.y, 0.0 }, float3 { b.x + n.x, b.y + n.y, 0.0 }, float3 { b.x - n.x, b.y - n.y, 0.0 },
                                      float3 { a.x - n.x, a.y - n.y, 0.0 }], [col, col, col, col], []::float3, []::float2, []::float2, [0, 2, 1, 0, 3, 2]))

def dot_at(c:float2, r:float, col:float4):
    let pts = [float3 { c.x, c.y, 0.0 }]
    for(12) i: pts.push(float3 { c.x + cos(float(i) * 30.0) * r, c.y + sin(float(i) * 30.0) * r, 0.0 })
    let idx = []::int
    for(12) i:
        idx.push(0)
        idx.push(1 + (i + 1) % 12)
        idx.push(1 + i)
    gl.set_shader("color_attr")
    gl.render_mesh(gl.new_mesh("PC", pts, map(pts.length): col, []::float3, []::float2, []::float2, idx))

class SText:
    at:float2
    s:string
    size:int
    col:float4

var texts = []::SText
def label(s:string, at_:float2, size:int, col:float4): texts.push(SText { at_, s, size, col })

// The labels last (a shape drawn after text comes out wrong in this build), outlined, a line at a time.
def flush_texts():
    gl.set_shader("color")
    for(texts) t:
        let px = int(float(t.size) * TEXT_SCALE)
        gl.set_font_size(px)
        for(tokenize(t.s, "\n", "")) line, n:
            let p = t.at + float2 { 0.0, float(n) * float(px) * 1.2 }
            for([float2 { -1.0, 0.0 }, float2 { 1.0, 0.0 }, float2 { 0.0, -1.0 }, float2 { 0.0, 1.0 }]) d:
                gl.color(float4 { 0.0, 0.0, 0.0, 0.7 }): gl.translate(p + d): gl.text(line)
            gl.color(t.col): gl.translate(p): gl.text(line)
    texts = []

// One unit (or lone part) drawn in a column's facing and pose: its sprites, and a loosed shot in flight.
def draw_unit(world:[float], u:SUnit, at_:float2, col:SCol):
    if u.part != "":
        let n = new_part(u.part)
        n.facing = col.facing
        part_setup(n, pshapes_of(u.part), u.colours or colours_for("human_tan", "hellenic", team))
        n.pos = at_ + float2 { 0.0, -12.0 }
        n.scl = float2_1 * UNIT_SCALE * 1.5
        bake_parts(n)
        let out = []::Draw
        draw_walk(n, xf_mul(world, xf_local(n)), 1.0, out)
        draw_list_sprites(out)
        return
    if col.pose == "fall" and corpse_pose_of(u.recipe):
        say_not_yet("the corpse pose in fall columns (the body\'s parts.json corpse: Godot bakes it in 3D; here it falls the plain way)")
    if col.pose == "corpse":
        say_not_yet("corpse columns (a body laid down in 3D: src/view/art/corpse.gd, no Lobster bake of corpse poses)")
        return
    let v = compose(u, col, at_)
    draw_list_sprites(draw_list(v, world))
    let w = v.weapon
    if col.pose == "loose" and w and has_s(gstrs(u.eval, "tags"), "ranged"):
        let rg = rig(v.facing_body + facing_suffix(col.facing))
        let dir = vnorm(if has(rg, "dir"): v2(at(rg, "dir")) else: float2 { 1.0, 0.0 })
        let g = xf_global(w)
        let src = float2 { g[4], g[5] } + dir * 9.0
        let to = src + dir * 60.0
        let st = shot_style(sheet_shot_kind(gstrs(u.eval, "tags")))
        let h = magnitude(to - src) * st.arc
        def arc(k:float) -> float2: return src + (to - src) * k - float2 { 0.0, h * 4.0 * k * (1.0 - k) }
        let p = arc(0.2)
        let d = vnorm(arc(0.23) - p)
        flush_sprites()
        let s = world[0]
        def scr(q:float2) -> float2: return xf_apply(world, q)
        if st.len > 0.0: line_quad(scr(p - d * st.len * 0.5), scr(p + d * st.len * 0.5), st.w * s, st.col)
        else: dot_at(scr(p), st.w * s, st.col)
        dot_at(scr(p + float2 { 0.0, h * 4.0 * 0.2 * 0.8 + 1.0 }), 0.8 * s, float4 { 0.0, 0.0, 0.0, 0.25 })   // its speck of shadow
    remove_shots_view(v)

def remove_shots_view(v:UV): free_tree(v.node)

def draw_list_sprites(ds:[Draw]):
    for(ds) d:
        let f = frame_index("p:" + d.key)
        if f >= 0: sprite_xf(f, d.xf, float4 { team.x, team.y, team.z, d.alpha })

// ------------------------------------------------------------------ a sheet

// A sheet, drawn into a texture and saved; `dry`: only composed, so every bake is made first (a bake renders
// through framebuffers of its own, which would cut the sheet's short).
def sheet(sh:JV, rows:[SRow], size_units:[SUnit], zoom:float, verdicts:dictionary<string, [string]>, path:string, expected:dictionary<string, [string]>, dry:bool):
    let cols = columns(sh)
    let cl = glist(spec, "cell")
    let cell = if cl.length == 2: float2 { as_float(cl[0]), as_float(cl[1]) } else: float2 { 66.0, 64.0 }
    let size_w = cell.x * 0.75 * float(size_units.length)
    let big = zoom > 2.0
    let label_w = if big: 230.0 else: 140.0
    let head_h = if big: 56.0 else: 44.0
    let fs = if big: 14 else: 10
    let heights = map(rows) r: cell.y * r.h * zoom
    var total_h = head_h
    for(heights) h: total_h += h
    let size = int2 { int(label_w + (size_w + cell.x * float(cols.length)) * zoom) + 8, int(total_h) + 4 }
    let tex = gl.create_blank_texture(int3 { if dry: 1 else: size.x, if dry: 1 else: size.y, 0 }, texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min | texture_format_clamp)
    if not dry: gl.switch_to_framebuffer(tex)
    gl.ortho()
    gl.clear(BG)
    gl.blend(1)
    b_sheet = -1
    if size_w > 0.0:
        fill_rect(float2 { label_w, 0.0 }, float2 { size_w * zoom, float(size.y) }, float4 { 0.0, 0.0, 0.0, 0.07 })
        label("for size", float2 { label_w + 6.0, head_h - float(fs) - 8.0 }, fs, TEXT)
    let title = gstr(spec, "title", "") + (if has(spec, "title") and has(sh, "title"): "  |  " else: "") + gstr(sh, "title", "")
    label(title, float2 { 8.0, 6.0 }, fs + 2, TEXT)
    let x0 = label_w + size_w * zoom
    for(cols) c, i: label(c.label, float2 { x0 + float(i) * cell.x * zoom + 4.0, head_h - float(fs) - 8.0 }, if big: fs - 2 else: fs - 1, TEXT)
    let world = [zoom, 0.0, 0.0, zoom, label_w, 0.0]
    var y = head_h
    for(rows) row, r:
        let h = heights[r]
        let fails = verdicts.get(row.label) or []::string
        if fails.length:   // a red frame round a failing row
            let red = float4 { 1.0, 0.19, 0.19, 1.0 }
            let a = float2 { 2.0, y + 2.0 }
            let s = float2 { float(size.x) - 4.0, h - 4.0 }
            fill_rect(a, float2 { s.x, 3.0 }, red)
            fill_rect(a + float2 { 0.0, s.y - 3.0 }, float2 { s.x, 3.0 }, red)
            fill_rect(a, float2 { 3.0, s.y }, red)
            fill_rect(a + float2 { s.x - 3.0, 0.0 }, float2 { 3.0, s.y }, red)
        label(row.label, float2 { 8.0, y + h * 0.3 }, fs, TEXT)
        if verdicts.get_keys().length and row.unit.part == "":
            let exp = expected.get(row.label)
            var verdict = if fails.length: "placement: FAIL\n" + concat_string(map(fails) f: rule_of(f), "\n") else: "placement: PASS"
            if not fails.length and exp: verdict = "placement: fails, as expected:\n" + concat_string(exp, "\n")
            let vcol = if fails.length: float4 { 1.0, 0.69, 0.63, 1.0 } elif exp: float4 { 0.94, 0.85, 0.56, 1.0 } else: float4 { 0.78, 0.94, 0.63, 1.0 }
            let lines = tokenize(row.label, "\n", "").length
            label(verdict, float2 { 8.0, y + h * 0.3 + float(fs + 4) * (float(lines) + 0.2) }, if big: fs - 3 else: fs - 2, vcol)
        let base_y = (y + h * 0.82) / zoom
        for(size_units) su, i: draw_unit(world, su, float2 { cell.x * 0.75 * (float(i) + 0.5), base_y }, SCol { 0, "stand", 0, 8, "", false, "" })
        for(cols) c, i:
            let ou = row.other
            let u = if c.other and ou: ou else: row.unit
            draw_unit(world, u, float2 { size_w + (float(i) + 0.5) * cell.x, base_y }, c)
        y += h
    if dry:
        b_pos = []
        b_col = []
        b_tc = []
        b_idx = []
        texts = []
        return
    flush_sprites()
    flush_texts()
    gl.blend(blend_add_alpha)   // (opaque: what was blended in left the sheet's alpha below 1)
    fill_rect(float2_0, float(size), float4 { 0.0, 0.0, 0.0, 1.0 })
    gl.blend(blend_alpha)
    gl.switch_to_framebuffer(nil)
    gl.ortho()
    if gl.save_texture(tex, path, true): print "saved {path}"
    else: print "sheet: could not save {path}"

// ------------------------------------------------------------------ main

let rows = spec_rows()
let size_units = map(glist(spec, "size")) r: unit_of(r)
let zooms = if zoom_arg.length: map(zoom_arg) z: string_to_float(z) else: map(if has(spec, "zooms"): glist(spec, "zooms") else: [jint(3), jint(1)]) z: as_float(z)
let verdicts = dictionary<string, [string]>(63)
let expected = dictionary<string, [string]>(15)
var bad = 0
var frame_n = 0
while gl.frame() and frame_n < 1:   // (bakes and framebuffers inside a frame)
    frame_n++
    sprite_formats = texture_format_clamp | texture_format_nomipmap | texture_format_nearest_mag | texture_format_nearest_min
    bake_shadow()
    // Placement per row; a row may expect to fail named rules: it passes when it fails those and nothing else.
    for(rows) r:
        if check_rows and r.unit.part == "":
            let recipes = [r.unit.recipe]
            let o = r.other
            if o: recipes.push(o.recipe)
            var v = sheet_row_check(r.label, recipes)
            if r.expect.length:
                let rest = filter(v) f: not has_s(r.expect, rule_of(f))
                for(r.expect) rule:
                    let failed = exists(v) f: rule_of(f) == rule
                    if not failed: rest.push("expected to fail {rule}, but passes it")
                v = rest
                expected.set(r.label, r.expect)
            if v.length or r.expect.length: verdicts.set(r.label, v)
    for(rows) r:
        let v = verdicts.get(r.label) or []::string
        let flat = concat_string(tokenize(r.label, "\n", ""), " ")
        if not check_rows or r.unit.part != "": print "  -   {flat}"
        elif not v.length: print "PASS  {flat}" + (if r.expect.length: " (fails " + concat_string(r.expect, ", ") + ", as expected)" else: "")
        else:
            bad++
            print "FAIL  {flat}: " + concat_string(v, "; ")
    for(glist(spec, "sheets")) sh:
        if only.length and not has_s(only, rstr(sh, "name")): continue
        for(zooms) z:
            let zs = if z == floor(z): string(int(z)) else: string(z)
            let path = out_dir + "/" + spec_name() + "_" + rstr(sh, "name") + "_" + zs + "x.png"
            sheet(sh, rows, size_units, z * ART_SCALE, verdicts, path, expected, true)
            sheet(sh, rows, size_units, z * ART_SCALE, verdicts, path, expected, false)
print "sheet: {rows.length} rows, {bad} failed placement"
if not_yet.length:
    print "not yet ({not_yet.length}):"
    for(not_yet) s: print "  {s}"
set_exit_code(if bad > 0: 1 else: 0)
