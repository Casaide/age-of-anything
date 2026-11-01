// The procedural voxel units on a sheet (view/voxel.lobster): every unit in 8 facings, walks and attacks, at a
// voxel a baked pixel (the game draws them at 0.55 world px a pixel).
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter box -resize 55% out.png)
import std
import vec
import view.voxel

class row:
    u:vx_unit_def
    mode:string   // stand (8 facings), walk or attack (8 steps in profile, facing right)
    wear:string   // the team on a creature: scarf or vest
    shade:bool    // shadows (on the body and the ground)

let units = [
    vx_unit_def { "rat worker", vx_RAT, "axe", "", true, false, "" },
    vx_unit_def { "rat spear", vx_RAT, "spear", "shield", true, false, "" },
    vx_unit_def { "rat on a cat", vx_RAT, "spear", "shield", true, false, "cat" },
    vx_unit_def { "frog spear", vx_FROG, "spear", "shield", true, false, "" },
    vx_unit_def { "human legionary", vx_HUMAN, "sword", "shield", true, true, "" },
]
let rows = []::row
for(units) u:
    rows.push(row { u, "stand", "scarf", false })
    rows.push(row { u, "stand", "scarf", true })
rows.push(row { units[1], "stand", "vest", true })
rows.push(row { units[1], "walk", "scarf", true })
rows.push(row { units[1], "attack", "scarf", true })
rows.push(row { units[0], "attack", "scarf", true })

let out_path = if command_line_arguments().length: command_line_arguments()[0] else: "voxel_proto.ppm"
let iw = vx_CELL.x * 8
let ih = vx_CELL.y * rows.length
let img = map(iw * ih): float3 { 86.0, 120.0, 46.0 } / 255.0
let t0 = seconds_elapsed()
var fills = 0.0
for(rows) rw, r:
    let u = rw.u
    vx_mat_cols[vx_mat_skin] = u.rc.skin
    vx_mat_cols[vx_mat_pale] = u.rc.pale
    vx_fur = u.rc.fur
    vx_team_wear = rw.wear
    vx_shadows = rw.shade
    vx_act = if rw.mode == "attack": "attack" else: ""
    if rw.mode == "stand":
        let t = seconds_elapsed()
        let stand = vx_fill(vx_unit_prims(u, 0.0), u.rc.size)
        fills += seconds_elapsed() - t
        for(8) c: vx_draw(stand, (c + 3) % 8, img, iw, c * vx_CELL.x, r * vx_CELL.y)   // (columns as the composed sheet's)
    else:
        for(8) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 45.0), u.rc.size), 2, img, iw, k * vx_CELL.x, r * vx_CELL.y)
    print "{u.label} ({rw.mode}): drawn"
print "{rows.length} rows in {seconds_elapsed() - t0} s ({fills} s filling the standing ones)"
let ppm = "P6\n{iw} {ih}\n255\n"
let bytes = []::int
for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
print "wrote {out_path}"
