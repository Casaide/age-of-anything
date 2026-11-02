// What the game makes, as text for the golden files (golden.sh holds it to golden/<section>.txt, "update" records it):
//   starts   the match start (World's setup) for a few maps, modes and races, as its scenario's tokens
//   models   every part's model (parts.json, its walk steps, worn armour on each body that has its own), a digest of
//            its triangles: corners, normals, colours, uvs, materials
//   buildings  every building type in every architecture, a digest of its model
//   effects  every research's effects in words (the tech tree's text)
// They were held to Godot's (start_check, model_check, building_check, effect_words_check) until Godot went; these
// digests keep what those checks proved.
//   lobster golden.lobster -- <section>
import placement.deps
import gen.scenario_out
import gen.effect_words
import model.buildings
import model.buildings2
import gen.reset

let args = command_line_arguments()
fatal(gl.window("golden", 64, 64, gl.window_init_no_vsync))  // (models load their textures)
placement_load()

def r4(x:float) -> string: return string(int(round(x * 10000.0)))
def v4(v:float3) -> string: return r4(v.x) + "," + r4(v.y) + "," + r4(v.z)

// A model's digest: its triangles in order, each corner rounded to 1e-4.
def digest(n:MNode) -> string:
    var s = ""
    for(model_tris(n)) t:
        s += "{t.mat}:"
        for(3) k: s += v4(t.p[k]) + "/" + v4(t.n[k]) + "/" + v4(t.c[k]) + "/" + r4(t.uv[k].x) + "," + r4(t.uv[k].y) + ";"
    return sha256_text(s).substring(0, 16)

let section = args[0]
if section == "starts":
    for([ [ "flat_test", "", "sewer rats with cheese hammers", "romans" ], [ "reed_meadow", "", "angry swamp frogs", "moonbears" ],
          [ "siege_vale", "siege", "centaur romans", "tiny vikings" ], [ "reed_meadow_2v2", "", "spiders", "aztecs" ] ]) m:
        reset_world()
        let rules = load_rules("default")
        if m[1] != "": set(rules, "mode", jstr(m[1]))
        set(rules, "animals", jbool(true))
        let races = map(m.slice(2, -1)) p: generate(p, rules, 0)
        setup_world(20261010, m[0], races, rules, [])
        print "{m[0]} {m[1]} {m[2]} | {m[3]}: " + sha256_text(concat_string(scenario_tokens(), " ")).substring(0, 16) + " " + sha256_text(concat_string(ai_tokens, " ")).substring(0, 16)
elif section == "models":
    let cols = colours_for("rat_grey", "sewer", float3_1)
    let ids = []::string
    for(lib_part_ids) id:
        ids.push(id)
        let p = part(id)
        let legs = get(p, "legs")
        let steps = gint(p, "body_steps", 0)
        for(steps) k: ids.push(id + "@w{k}_{steps}")
        if legs:
            let poses = gint(legs, "poses", 0)
            for([ rstr(legs, "part"), gstr(legs, "hind", "") ]) leg:
                if leg != "":
                    for(poses) k: ids.push(leg + "@w{k}_{poses}")
    for(ids) id:
        let s = build_model(id, cols)
        print id + " " + (if s: digest(s.node) else: "none")
elif section == "buildings":
    let bt = gobj(load_json("../data/buildings.json"), "buildings")
    for([ "stone", "thatch", "junk", "tent", "reed", "mound" ]) arch:
        for(sorted_strs(bt.keys)) type:
            let s = building_spec(arch, type, float3 { 1.0, 0.0, 1.0 })
            print arch + ":" + type + " " + (if s: digest(s.body) else: "none")
elif section == "effects":
    let tech = load_json("../data/tech.json")
    for(glist(tech, "research")) r: print rstr(r, "id") + ": " + effect_text(glist(r, "effects"))
else:
    print "golden: no section {section}"
    set_exit_code(1)
