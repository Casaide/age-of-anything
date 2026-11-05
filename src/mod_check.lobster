// A mod loaded, or why not; the races its manifest's check prompts make (under its check rules), and which of their
// units wear its parts. Exit 1 on a refusal. (Its parts' looks are the voxel kit's, by data/voxel/'s rules; its
// prices: calibrate.lobster mod <id>.)
//   ./mod_check.sh <mod id>
import game.deps

let args = command_line_arguments()
let id = args[0]
data_load()
let used = mods_use([ id ])
let refused = mods_refused.get(id, "")
if refused != "" or not has_s(map(used) u: tokenize(u, "@", "")[0], id):
    print "mod {id}: refused: " + (if refused != "": refused else: "not found")
    set_exit_code(1)
else:
    print "mod {id}: loaded ({used})"
    let manifest = load_json("../mods/{id}/pack.json")
    let check = gobj(manifest, "check")
    let rules_id = gstr(check, "rules", "default")
    let rules = load_rules(rules_id)
    let own = []::string                                        // the mod's own part ids
    let parts_text = read_file("../mods/{id}/data/parts.json")  // (a mod may bring no parts: voxel bodies, sounds, rules)
    if parts_text:
        let mod_parts = parse_json(parts_text)
        if mod_parts.kind == J_ARR:
            for(mod_parts.a) p: own.push(rstr(p, "id"))
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
