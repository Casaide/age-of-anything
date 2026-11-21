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
for(glist(race, "units")) unit:
    let u = at(glist(unit, "line")[0], "recipe")
    let slot = gstr(u, "slot", "")
    let kit = gobj(gobj(gobj(family("steading"), "kits"), slot), "1")
    let ps = gobj(u, "parts")
    for(kit.keys) s, i: expect(gstr(ps, s, "") == as_str(kit.a[i]), "the {slot} wears its {s}, {as_str(kit.a[i])}: {gstr(ps, s, "")}")
    let look = "{gstr(ps, "head_gear", "")} {gstr(ps, "torso", "")} {gstr(ps, "hand_r", "")}"
    expect((find(looks) l: l == look) < 0, "the {slot} looks like no other trade: {look}")
    looks.push(look)
expect(looks.length == 13, "the serf and 12 trades: {looks.length}")
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
print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
