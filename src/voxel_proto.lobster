// The procedural voxel units on a sheet (view/voxel.lobster): every unit in 8 facings, walks and attacks.
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter point -resize 400% out.png)
import std
import vec
import view.voxel

// ---- the sheet: a row of 8 facings per unit (a walk in facing 1 where asked)

class row:
    u:vx_unit_def
    mode:string   // stand (8 facings), walk or attack (8 steps in facing 1)

let units = [
    vx_unit_def { "human worker", vx_HUMAN, "axe", "", false, false, "" },
    vx_unit_def { "human spearman", vx_HUMAN, "spear", "shield", false, false, "" },
    vx_unit_def { "human archer", vx_HUMAN, "", "bow", false, false, "" },
    vx_unit_def { "human swordsman", vx_HUMAN, "sword", "shield", true, true, "" },
    vx_unit_def { "human rider", vx_HUMAN, "spear", "shield", true, false, "horse" },
    vx_unit_def { "centaur", vx_HUMAN, "spear", "shield", false, false, "centaur" },
    vx_unit_def { "rat worker", vx_RAT, "axe", "", false, false, "" },
    vx_unit_def { "rat spearman", vx_RAT, "spear", "shield", false, false, "" },
    vx_unit_def { "rat on a cat", vx_RAT, "spear", "shield", true, false, "cat" },
    vx_unit_def { "frog spearman", vx_FROG, "spear", "shield", false, false, "" },
    vx_unit_def { "frog archer", vx_FROG, "", "bow", false, false, "" },
    vx_unit_def { "bear warrior", vx_BEAR, "axe", "shield", true, true, "" },
    vx_unit_def { "bear archer", vx_BEAR, "", "bow", false, false, "" },
]
let rows = []::row
for(units) u, k:
    rows.push(row { u, "stand" })
    if k == 4 or k == 8 or k == 11: rows.push(row { u, "walk" })
    if k == 0 or k == 1 or k == 7: rows.push(row { u, "attack" })

let out_path = if command_line_arguments().length: command_line_arguments()[0] else: "voxel_proto.ppm"
let iw = vx_CELL.x * 8
let ih = vx_CELL.y * rows.length
let img = map(iw * ih): float3 { 0.33, 0.47, 0.18 }
for(rows) rw, r:
    let u = rw.u
    vx_mat_cols[vx_mat_skin] = u.rc.skin
    vx_mat_cols[vx_mat_pale] = u.rc.pale
    vx_act = if rw.mode == "attack": "attack" else: ""
    if rw.mode == "stand":
        let stand = vx_fill(vx_unit_prims(u, 0.0), u.rc.size)
        for(8) f: vx_draw(stand, f, img, iw, f * vx_CELL.x, r * vx_CELL.y)
    else:
        for(8) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 45.0), u.rc.size), 1, img, iw, k * vx_CELL.x, r * vx_CELL.y)
    print "{u.label} ({rw.mode}): drawn"
let ppm = "P6\n{iw} {ih}\n255\n"
let bytes = []::int
for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
print "wrote {out_path}"
