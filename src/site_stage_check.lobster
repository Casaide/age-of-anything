// A building site goes up the way a real one does (#155): at every stage of every building, Steading's set and the
// base game's, nothing seen hangs in the air (each part stands on the ground or on a part seen under it), and no
// part of the roof shows before the building is finished.
//   lobster site_stage_check.lobster
import from "../creel/src"
import game.deps
import model.buildings
import model.future
import model.steading
import model.buildings2
import model.build_stages

fatal(gl.window("site_stage_check", 64, 64, gl.window_init_no_vsync))  // (models load their textures)
data_load()

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

def check_site(name:string, spec:BSpec, stage:int):
    akb_hide(spec.body, stage)
    let seen = []::AkbBox
    for(spec.body.kids) k: akb_seen(k, node_xform(k), seen)
    var ground = 1000000000.0
    for(seen) s: ground = min(ground, s.lo.y)
    for(seen) s: expect(find_string(s.node.meta, "roof") < 0, "{name} stage {stage}: a roof part shows before it is finished ({s.lo.y - ground})")
    let held = akb_held(seen, ground)
    for(seen) s, i:
        expect(held[i], "{name} stage {stage}: a part floats at {s.lo.y - ground} with nothing under it ({s.node.meta} {s.hi - s.lo} at {s.lo})")

let types = [ "town_center", "school", "lumber_camp", "mining_camp", "sawmill", "farm", "vineyard", "mill", "bakery", "inn",
              "pig_farm", "butcher", "coal_mine", "iron_mine", "gold_mine", "iron_smelter", "gold_smelter", "armoury" ]
let sites = []::string
for(types) t: sites.push("steading:" + t)
for([ "stone", "thatch" ]) arch:
    for([ "town_center", "house", "barracks", "farm" ]) t: sites.push(arch + ":" + t)
for(sites) site:
    let p = tokenize(site, ":", "")
    for(AKB_BUILD_STAGES.length) stage:
        let spec = building_spec(p[0], p[1], float3 { 1.0, 0.0, 1.0 })
        expect(spec != nil, "{site} has a model")
        if spec: check_site(site, spec, stage)
print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
