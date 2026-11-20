// Steading's looks (#125): every good a serf or a trade carries is seen carried. Each resource the mod has (and the
// game's wood, stone and gold it uses) has a load in the mod's voxel gear, its gear exists, and no two goods share one.
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
print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
