// The placement check (tests/placement_check.gd, docs/rendering.md "Placement rules"): one command that must pass
// before any unit, mount, gear or pose change is shown. Numbers, not pictures:
//   1. 3D (placement/geometry.lobster): every unit put together from its models in every pose the game draws,
//      measured on its meshes: ground contact, attachment, interpenetration, stance, the dead, composites.
//   2. 2D (placement/projection.lobster, case2d.lobster): every unit composed from its bakes in all 8 facings,
//      standing, walking and at work: the layering rules, feet on their ground points, legs and head where the 3D
//      truth shows them, riders' legs on the near flank, composites in depth order.
//   3. The regression fixtures (placement/fixtures3d.lobster, fixtures2d.lobster): every placement bug Dominic
//      caught, put back, must fail its rule; as the unit is now, it must pass.
// FAIL lines per rule and unit, a summary, exit 1 on any failure.
//   lobster placement_check.lobster -- [filter] [3d|2d] [all] [nofixtures | fixtures]   (fixtures: those alone)
//   lobster placement_check.lobster -- parity2d <placement_dump2d.gd's json> [filter]   (the 2D results against Godot's)
//   lobster placement_check.lobster -- parity <placement_dump.gd's json> [filter]   (the cases and 3D results
//       against Godot's: the same cases, recipes, and failing views per rule)
// filter: only cases whose label holds it (and no fixtures). all: every failing view.

import placement.deps
import view.stage
import view.corpse
import placement.geometry
import placement.composite
import placement.cases
import placement.fixtures3d
import placement.projection
import placement.case2d
import placement.fixtures2d

let args = command_line_arguments()
fatal(gl.window("placement check", 64, 64, gl.window_init_no_vsync))
fatal(gl.load_materials(BAKE_SHADERS, true))   // (parts not in the bake cache are baked as they're composed)
placement_load()
let parity = args.length > 1 and args[0] == "parity"
let parity2 = args.length > 1 and args[0] == "parity2d"
let want = if parity or parity2: load_json(args[1]) else: jobj()
var only = ""
for(args) a, i:
    if not ((parity or parity2) and i < 2) and not has_s(["all", "nofixtures", "fixtures", "3d", "2d", "debug2d"], a): only = a
let fixtures_only = has_s(args, "fixtures")
let do3 = not has_s(args, "2d") and not parity2
debug2d = has_s(args, "debug2d")
let do2 = not has_s(args, "3d") and not parity

let t0 = seconds_elapsed()
let cases = filter(all_cases(true)) c: only == "" or find_string(c.label, only) >= 0
var failed = 0

if parity:
    // The cases: the same labels, in order, with the same recipes.
    let gc = glist(want, "cases")
    var case_diffs = 0
    if gc.length != cases.length:
        print "DIFF cases: {cases.length} here, {gc.length} in Godot"
        case_diffs++
    for(min(gc.length, cases.length)) i:
        let g = gc[i]
        if as_str(g.a[0]) != cases[i].label:
            if case_diffs < 10: print "DIFF case {i}: {cases[i].label}, Godot {as_str(g.a[0])}"
            case_diffs++
        elif not jequal(g.a[1], cases[i].recipe):
            if case_diffs < 10: print "DIFF case {cases[i].label}: recipe {stringify(cases[i].recipe)}\n  Godot {stringify(g.a[1])}"
            case_diffs++
    print "cases: {cases.length}, {case_diffs} differ from Godot\'s"
    failed += case_diffs

// 3D: units the same in 3D (an age step with the same parts, a race's colours) once.
let seen = []::string
for(if fixtures_only or not do3: []::Case else: cases) c:
    let r = c.recipe
    let sig = stringify(jarr([at(r, "body"), get(r, "head") or jstr(""), at(r, "parts"), get(r, "mount") or jobj(), get(r, "crew") or jobj(),
                              get(r, "haul") or jobj(), get(r, "slot") or jstr(""), at(r, "skin")]))
    if not has_s(seen, sig):
        seen.push(sig)
        check_unit(c.label, r)

def view_name(s:string) -> string:
    let k = find_string(s, " (")
    return if k >= 0: s.substring(0, k) else: s

var f3 = 0
var differ = 0
for(check_order) key:
    let fails = check_results.get(key) or []::string
    if fails.length:
        f3++
        let parts = tokenize(key, "|", "")
        let shown = if has_s(args, "all"): fails else: fails.slice(0, min(6, fails.length))
        print "FAIL {parts[1]}: {parts[0]} in {fails.length} views: {concat_string(shown, "; ")}" + (if fails.length > shown.length: " ..." else: "")
    if parity:
        let gr = get(at(want, "results"), key)
        let gviews = if gr: map(gr.a) v: view_name(as_str(v)) else: []::string
        let lviews = map(fails) v: view_name(v)
        if stringify(jstrs(gviews)) != stringify(jstrs(lviews)):
            differ++
            if differ <= 20: print "PARITY {key}: here {lviews}, Godot {gviews}"
if parity:
    let gres = at(want, "results")
    for(gres.keys) key:
        if not check_results.get(key):   // (a rule Godot checks and this doesn't, failing or not)
            differ++
            if differ <= 20: print "PARITY {key}: not checked here; Godot fails {gres.a[find(gres.keys) k: k == key].a.length} views"
    print "parity: {differ} rules differ from Godot\'s"
    failed += differ
failed += f3
print "3D: {check_order.length} checks, {f3} failed ({cases.length} units, {seen.length} distinct, {seconds_elapsed() - t0} s)"
// The regression fixtures (every placement bug Dominic caught, put back: each must still fail its rule).
var fixtures_ok = true
if do3 and only == "" and not has_s(args, "nofixtures"):
    let fx_ok, fx_lines = fixtures_3d(cases)
    fixtures_ok = fx_ok
    for(fx_lines) l: print l
// 2D: each recipe once, its parts baked as it's composed.
if do2:
    let t1 = seconds_elapsed()
    check_team = rgb_of(hex_of(as_str(glist(lib_palettes, "teams")[0])))
    let mark = check_order.length
    let done = []::string
    for(if fixtures_only: []::Case else: cases) c:
        let sig = stringify(c.recipe)
        if not has_s(done, sig):
            done.push(sig)
            check_case2d(c.label, c.recipe)
            clear_pixel_caches()
    var f2 = 0
    var k2 = mark
    while k2 < check_order.length:
        let key = check_order[k2]
        let fails = check_results.get(key) or []::string
        if fails.length:
            f2++
            let kp = tokenize(key, "|", "")
            let shown = if has_s(args, "all"): fails else: fails.slice(0, min(6, fails.length))
            print "FAIL {kp[1]}: {kp[0]} in {fails.length} of its views: {concat_string(shown, ", ")}" + (if fails.length > shown.length: " ..." else: "")
        k2++
    failed += f2
    print "2D: {check_order.length - mark} checks, {f2} failed ({done.length} units; {seconds_elapsed() - t1} s)"
    if parity2:   // the same rules checked, failing in the same views, as Godot's
        let gres = at(want, "results")
        var d2 = 0
        var k3 = mark
        while k3 < check_order.length:
            let key = check_order[k3]
            let fails = check_results.get(key) or []::string
            let gr = get(gres, key)
            let gviews = if gr: map(gr.a) v: view_name(as_str(v)) else: []::string
            let lviews = map(fails) v: view_name(v)
            if not gr or stringify(jstrs(gviews)) != stringify(jstrs(lviews)):
                d2++
                if d2 <= 30: print "PARITY {key}: here {lviews}, Godot " + (if gr: "{gviews}" else: "not checked")
            k3++
        for(gres.keys) key:
            if not check_results.get(key):
                d2++
                if d2 <= 30: print "PARITY {key}: not checked here"
        print "parity 2D: {d2} rules differ from Godot\'s"
        failed += d2
    if only == "" and not has_s(args, "nofixtures"):
        let fx_ok, fx_lines = fixtures_2d(cases)
        fixtures_ok = fixtures_ok and fx_ok
        for(fx_lines) l: print l
print "placement: {failed} failed, fixtures " + (if fixtures_ok: "all caught" else: "BROKEN")
if failed or not fixtures_ok: set_exit_code(1)
