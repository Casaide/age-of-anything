// Voxel buildings and props, an experiment (Dominic, 2026-11-03: "test a few buildings, see how close we can make
// them using voxels"): data/voxel/buildings/ (written by src/voxel_buildings_gen.lobster) drawn by the voxel builder, a
// facing a column, at a voxel a baked pixel (as the units) or finer. The game doesn't draw them.
//   lobster voxel_buildings.lobster -- <out.ppm> [res] [facing|all]   (res: voxels a body unit, 2 as the units)
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.vox
import view.voxel

let NAMES = [ "roman_house", "roman_tc", "rat_shack", "rat_silo", "cypress", "broadleaf", "rock" ]

vx_load([ "../data/voxel", "../data/voxel/buildings" ])
let args = command_line_arguments()
let out_path = if args.length: args[0] else: "voxel_buildings.ppm"
let res = if args.length > 1: string_to_float(args[1]) else: 2.0
let all = args.length > 2 and args[2] == "all"
let facings = if all: [ 0, 1, 2, 3, 4, 5, 6, 7 ] elif args.length > 2: [ string_to_int(args[2]) ] else: [ 1 ]
let cell = int2 { int(220.0 * res), int(170.0 * res) }  // (the Town Center is the biggest: 3 tiles)
let anchor = int2 { cell.x / 2, cell.y - int(45.0 * res) }
let scell = int2 { cell.x * 3 / 2, cell.y }
let sanchor = int2 { scell.x / 2 - int(30.0 * res), anchor.y }
let iw = scell.x * facings.length
let ih = cell.y * NAMES.length
let img = map(iw * ih): float3 { 86.0, 120.0, 46.0 } / 255.0
let t0 = seconds_elapsed()
for(NAMES) name, r:
    let b = vx_body_of(name)
    let u = vx_unit_def { name, name, float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0, nil }
    vx_set_look(u, 0)
    let parts = []::vx_prim
    vx_whole_body(parts, u, b, vx_body_points(b, 0.0, float3_0), 0.0, 0.0, vx_flags_of(u))
    let t = seconds_elapsed()
    vx_pat_scale = b.size * res
    let g = vx_fill(parts, b.size * res / vx_RES, true)  // (the ground at z 0: walls are hard, nothing melts down to it)
    let tf = seconds_elapsed() - t
    for(facings) f, c:
        let t2 = seconds_elapsed()
        let sc = copy(vx_ground_shadow_in(g, f, scell.x, scell.y, sanchor))
        let px = vx_cell_in(g, f, cell.x, cell.y, anchor)
        let ox = c * scell.x
        let oy = r * cell.y
        for(scell.y) y: for(scell.x) x:
            let s = sc[y * scell.x + x]
            if s.w > 0.0:
                let j = (oy + y) * iw + ox + x
                img[j] = img[j] * (1.0 - s.w) + xyz(s) * s.w
        for(cell.y) y: for(cell.x) x:
            let p = px[y * cell.x + x]
            if p.w > 0.0:
                let j = (oy + y) * iw + ox + x + (sanchor.x - anchor.x)
                img[j] = img[j] * (1.0 - p.w) + xyz(p) * p.w
        if c == 0: print "{name}: {parts.length} parts, {g.pos.length} surface voxels, filled in {int(tf * 1000.0)} ms, a facing in {int((seconds_elapsed() - t2) * 1000.0)} ms"
print "all in {seconds_elapsed() - t0} s"
let bytes = []::int
for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
write_file(out_path, "P6\n{iw} {ih}\n255\n" + vector_to_buffer(bytes, 1), 0, 1)
print "wrote {out_path}"
