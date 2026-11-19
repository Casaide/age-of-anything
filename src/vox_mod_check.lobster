// The example .vox mod (#381, #313): mods/vox_example loads (a MagicaVoxel model is mod data), its word gives its
// creature, and its body comes from the .vox: every limb drawn, the head and chest pieces on their points, and
// the mod's key holds the model (a changed .vox is a different mod).
//   lobster vox_mod_check.lobster
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
let used = mods_use([ "vox_example" ])
expect(used.length == 1 and used[0] == "vox_example", "the mod loads ({mods_refused.get_keys()}: {mods_refused.get("vox_example", "")})")
let race = generate("haiduts", load_rules("anything"), 0)
expect(gstr(race, "creature", "") == "haidut", "haiduts are the haidut: {gstr(race, "creature", "")}")
expect(lib_mods.length == 1 and find_string(lib_mods[0], "vox_example@") == 0, "the race holds the mod: {lib_mods}")
vx_load(map(lib_packs) p: p.root + "/voxel")
let b = vx_body_of("haidut")
for([ "thigh", "shin", "upper_arm", "forearm" ]) bone: expect((find(b.vox_bones) n: n == bone) >= 0, "the .vox draws the {bone}")
expect(b.leg_r.length == 3 and b.leg_l.length == 3 and b.arm_r.length == 3 and b.arm_l.length == 3, "each limb has its three pieces, the left mirrored")
expect(b.shapes.length == 3, "head, chest and hip ride their points: {b.shapes.length}")
for([ "haidut", "haidut_fleece", "haidut_yamurluk" ]) id:
    let rb = vx_body_of(id)
    expect(rb.seat_z > 0.0 and rb.astride.length == 3, "{id} can ride (a lancer sits a pony): seat {rb.seat_z}, legs astride {rb.astride.length}")
print "{n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
