// The lobby's army stages stand on grass (#191): the turf drawn in a fresh window, before any match has drawn the
// ground, covers its whole stage in opaque ground. (It once set only a few of the terrain shader's uniforms, so on the
// first setup page after a launch tile_h was 0 and every pixel fell off the map.)
//   lobster turf_check.lobster
import from "../creel/src"
import game.deps
import view.atmosphere
import game.relief
import game.fog_look
import game.ground
import game.turf

fatal(gl.window("turf_check", 64, 64, gl.window_init_no_vsync))
fatal(gl.load_materials(SPRITE_SHADERS, true))
fatal(gl.load_materials(TERRAIN_SHADERS, true))
data_load()

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

let N = 128
for(2) side:
    let tex = gl.create_blank_texture(int3 { N, N, 0 }, texture_format_nomipmap | texture_format_clamp)
    gl.switch_to_framebuffer(tex)
    gl.ortho()
    gl.clear(float4_0)
    fe_turf(float2_0, float2_1 * float(N), 2.0, side)
    gl.switch_to_framebuffer(nil)
    gl.ortho()
    let px = gl.read_texture(tex) or ""
    expect(px.length == N * N * 4, "side {side}: the turf\'s pixels read back")
    var ground = 0
    var green = 0
    for(N * N) i:
        if px.length == N * N * 4 and px[i * 4 + 3] > 250:
            ground++
            if px[i * 4 + 1] > px[i * 4 + 2]: green++  // (grass, not water)
    expect(ground == N * N, "side {side}: the turf covers its stage ({ground} of {N * N} px drawn)")
    expect(green * 10 >= N * N * 9, "side {side}: the turf is grass ({green} of {N * N} px green over blue)")

print "turf_check: {n_checks} checks, {n_failed} failed"
if n_failed > 0: set_exit_code(1)
