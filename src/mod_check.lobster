// A mod loaded, or why not; the races its manifest's check prompts make (under its check rules), which of their units
// wear its parts; and the 3D placement check on every unit of those races. Exit 1 on a refusal or a failure.
// Run through mod_check.sh, which brings the mod's Lobster models in first:  ./mod_check.sh <mod id>
import placement.deps
import view.stage
import view.corpse
import placement.geometry
import placement.composite
import placement.cases

let args = command_line_arguments()
let id = args[0]
fatal(gl.window("mod check", 64, 64, gl.window_init_no_vsync))  // (models load their textures)
placement_load()
let used = mods_use([ id ])
let refused = mods_refused.get(id, "")
if refused != "" or not has_s(map(used) u: tokenize(u, "@", "")[0], id):
    print "mod {id}: refused: " + (if refused != "": refused else: "not found")
    set_exit_code(1)
else:
    print "mod {id}: loaded ({used})"
    let manifest = load_json("../mods/{id}/mod.json")
    let check = gobj(manifest, "check")
    let rules_id = gstr(check, "rules", "default")
    let rules = load_rules(rules_id)
    let own = []::string  // the mod's own part ids
    let parts_text = read_file("../mods/{id}/data/parts.json")   // (a mod may bring no parts: voxel bodies, sounds, rules)
    if parts_text:
        let mod_parts = parse_json(parts_text)
        if mod_parts.kind == J_ARR:
            for(mod_parts.a) p: own.push(rstr(p, "id"))
    var units = 0
    for(gstrs(check, "prompts")) prompt:
        let race = generate(prompt, rules, 0)
        let race_name = rstr(race, "name")
        print "{prompt} ({rules_id}): {race_name}"
        for(glist(race, "units")) u:
            let r = at(u, "recipe")
            let rp = at(r, "parts")
            let mine = filter(map(rp.a) v: as_str(v)) pid: has_s(own, pid)
            let slot = rstr(r, "slot")
            let unit_name = rstr(r, "name")
            print "  {slot}: {unit_name}" + (if mine.length: "  <- " + concat_string(mine, ", ") else: "")
            check_unit(prompt + " " + slot, r)
            units++
    var failed = 0
    for(check_order) key:
        let fails = check_results.get(key) or []::string
        if fails.length:
            failed++
            print "FAIL {key}: {fails.length} views: " + concat_string(fails.slice(0, min(3, fails.length)), "; ")
    print "placement 3D: {check_order.length} checks, {failed} failed ({units} units)"
    if failed: set_exit_code(1)
