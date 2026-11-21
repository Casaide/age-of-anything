// Steading's looks (#125): every good a serf or a trade carries is seen carried. Each resource the mod has (and the
// game's wood, stone and gold it uses) has a load in the mod's voxel gear, its gear exists, and no two goods share one.
// And every trade looks its own: the race is the steading culture, each slot wears its kit, no two alike. And every
// building the mod keeps has its own model in the steading architecture (model/steading.lobster's steading_building).
//   lobster steading_look_check.lobster
import from "../creel/src"
import std
import vec
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import lua.parse
import gen.mods
import view.vox
import view.voxel

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

lib_load("../data")
id_load("../data")
let used = mods_use([ "steading" ])
expect(used.length == 1 and used[0] == "steading", "the mod loads ({mods_refused.get("steading", "")})")
vx_load(map(lib_packs) p: p.root + "/voxel")
let carried = filter(lib_resources) r: r != "food"  // (the game's food: nothing in Steading gathers it)
expect(carried.length >= 14, "the goods: {carried}")
let gears = []::string
for(carried) r:
    expect((find(vx_load_names) n: n == r) >= 0, "{r} has a load (carry mode)")
    let g = vx_load_gear("human", r)
    expect(g != "", "{r} is carried in the hands, not pushed or unseen")
    expect(vx_gears.get(g) != nil, "the load gear of {r}, {g}, exists")
    expect((find(gears) x: x == g) < 0, "{r} has its own load, not {g} shared")
    gears.push(g)
let race = generate("serfs", load_rules("steading"), 0)
expect(gstr(race, "family", "") == "steading", "serfs are the steading culture: {gstr(race, "family", "")}")
let looks = []::string
let kit_slots = []::string  // (#156) each trade's slot, head gear and dress
let kit_heads = []::string
let kit_torsos = []::string
for(glist(race, "units")) unit:
    let u = at(glist(unit, "line")[0], "recipe")
    let slot = gstr(u, "slot", "")
    let kit = gobj(gobj(gobj(family("steading"), "kits"), slot), "1")
    let ps = gobj(u, "parts")
    for(kit.keys) s, i: expect(gstr(ps, s, "") == as_str(kit.a[i]), "the {slot} wears its {s}, {as_str(kit.a[i])}: {gstr(ps, s, "")}")
    let look = "{gstr(ps, "head_gear", "")} {gstr(ps, "torso", "")} {gstr(ps, "hand_r", "")}"
    expect((find(looks) l: l == look) < 0, "the {slot} looks like no other trade: {look}")
    looks.push(look)
    kit_slots.push(slot)
    kit_heads.push(gstr(ps, "head_gear", ""))
    kit_torsos.push(gstr(ps, "torso", ""))
expect(looks.length == 13, "the serf and 12 trades: {looks.length}")
// (#156) At game size a trade reads by the colour of its clothes and its hat: each wears a colour of its own (its dress's
// first shape, what covers the body), the serf alone the team's, and no two hats share theirs. The serf goes bare-headed.
let gear_json = parse_json(read_file("../mods/steading/data/voxel/gear.json") or "\{\}")
let part_gear = map(glist(gear_json, "parts")) p: [ gstr(p, "part", ""), gstr(p, "gear", "") ]
def main_mat(part:string) -> string:  // the material of a part's gear's first shape, "" for none
    let pg = find(part_gear) p: p[0] == part
    if pg < 0: return ""
    let g = gobj(gobj(gear_json, "gear"), part_gear[pg][1])
    let fits = glist(gobj(g, "fits"), "*")
    let shapes = if fits.length > 0: fits else: glist(g, "shapes")
    return if shapes.length > 0: gstr(shapes[0], "mat", "") else: ""
let dress_mats = []::string
let hat_mats = []::string
for(kit_slots) slot, i:
    let dm = main_mat(kit_torsos[i])
    let hm = main_mat(kit_heads[i])
    expect(dm != "" and (find(dress_mats) m: m == dm) < 0, "the {slot} wears a colour no other trade does: {dm}")
    expect((dm == "team") == (slot == "worker"), "only the serf is dressed in the team\'s colour ({slot}: {dm})")
    if hm != "": expect((find(hat_mats) m: m == hm) < 0, "the {slot}\'s hat is a colour no other hat is: {hm}")
    if slot == "worker": expect(kit_heads[i] == "", "the serf goes bare-headed: {kit_heads[i]}")
    dress_mats.push(dm)
    if hm != "": hat_mats.push(hm)
expect(gstr(family("steading"), "architecture", "") == "steading", "the culture builds its own set")
let src = read_file("model/steading.lobster")
expect(src != nil, "model/steading.lobster is there")
let made = []::string
for(tokenize(src or "", "\n", "")) line:
    let t = tokenize(line, "\"", "")
    if find_string(line, "        case \"") == 0 and t.length >= 3:
        let r = find_string(line, "return ")
        if r >= 0: made.push("{t[1]} {line.substring(r + 7, -1)}")
let buildings = gobj(lib_data("buildings.json"), "buildings")
let models = []::string
for(buildings.keys) b, i:
    let o = buildings.a[i]
    if b != "_doc" and not gbool(o, "remove", false) and gstr(o, "road", "") == "" and not gbool(o, "drag", false):  // (a road or a field plan has no model: game/roads)
        let m = find(made) x: starts_with(x, b + " ")
        expect(m >= 0, "{b} has a model of its own in the steading set")
        if m >= 0:
            let call = made[m].substring(b.length + 1, -1)
            expect((find(models) x: x == call) < 0, "{b} is drawn by its own model, not {call} shared")
            models.push(call)
// Each stage of a field and a vine row has a prop of its own (#154), none of them the meadow's (a tuft, a bush, the
// base set's crops), so tilled, sown, ripe and reaped can be told apart from each other and from the grass.
let field_terrain = gobj(lib_data("terrain.json"), "terrain")
let field_props = []::string
for([ "tilled", "wheat_sown", "wheat_ripe", "vines_young", "vines_ripe" ]) t:
    let pr = gstr(gobj(field_terrain, t), "prop", "")
    expect(pr != "" and pr != "tuft" and pr != "bush" and pr != "crops", "{t} has a field prop of its own, not the meadow\'s ({pr})")
    expect((find(field_props) x: x == pr) < 0, "{t}\'s prop {pr} is no other stage\'s")
    field_props.push(pr)
// Each workshop that sounds busy names a building of the mod and a loop it brings (#121): its sound in audio.json and
// the rendered WAV in the mod's audio.
let work_sounds = gobj(lib_data("audio.json"), "buildings")
expect(work_sounds.keys.length >= 5, "workshops have their working sounds ({work_sounds.keys.length})")
for(work_sounds.keys) b, i:
    let snd = gstr(work_sounds, b, "")
    expect((find(buildings.keys) x: x == b) >= 0, "{b}, which sounds busy, is a building of the mod")
    expect(gobj(gobj(lib_data("audio.json"), "sounds"), snd).keys.length > 0, "{b}\'s sound {snd} is in audio.json")
    expect(read_file("../mods/steading/audio/sfx/{snd}_1.wav") != nil, "{b}\'s sound {snd} is rendered into the mod")
print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
