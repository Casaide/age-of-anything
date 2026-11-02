// The procedural voxel units on a sheet (view/voxel.lobster): every unit in 8 facings, walks and attacks, at a
// voxel a baked pixel (the game draws them at 0.55 world px a pixel).
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter box -resize 55% out.png)
import std
import vec
import view.voxel

class row:
    u:vx_unit_def
    mode:string  // stand (8 facings), walk or attack (8 steps in profile, facing right)
    wear:string  // the team on a creature: scarf or vest
    shade:bool   // shadows (on the body and the ground)
    look:int     // a human's look (vx_set_look)

let units = [
    vx_unit_def { "rat worker", vx_RAT, "axe", "", true, false, "", "", "", "", float3_0 },
    vx_unit_def { "rat spear", vx_RAT, "spear", "shield", true, false, "", "", "", "", float3_0 },
    vx_unit_def { "rat on a cat", vx_RAT, "spear", "shield", true, false, "cat", "", "", "", float3_0 },
    vx_unit_def { "frog spear", vx_FROG, "spear", "shield", true, false, "", "", "", "", float3_0 },
    vx_unit_def { "roman legionary (age 3)", vx_ROMAN, "gladius", "scutum", true, true, "", "galea", "lorica", "", float3_0 },
    vx_unit_def { "roman spearbearer (age 1)", vx_ROMAN, "spear", "", false, true, "", "", "leather", "", float3_0 },
    vx_unit_def { "roman clubber (age 1)", vx_ROMAN, "club", "", true, true, "", "", "leather", "", float3_0 },
    vx_unit_def { "roman archer (age 2)", vx_ROMAN, "", "bow", true, true, "", "galea", "leather", "quiver", float3_0 },
    vx_unit_def { "roman pilum-thrower (age 2)", vx_ROMAN, "pilum", "scutum", true, true, "", "galea", "leather", "", float3_0 },
    vx_unit_def { "roman lancer on a pony (age 2)", vx_ROMAN, "spear", "scutum", true, true, "horse", "galea", "bronze", "", float3 { 0.66, 0.66, 0.63 } },
    vx_unit_def { "roman healer", vx_ROMAN, "staff", "", false, false, "", "", "", "", float3_0 },
    vx_unit_def { "roman scavenger", vx_ROMAN, "axe", "", false, false, "", "", "", "", float3_0 },
    vx_unit_def { "roman legionary (age 2)", vx_ROMAN, "gladius", "scutum", true, true, "", "galea", "bronze", "", float3_0 },
]
let rows = []::row
for(units) u: rows.push(row { u, "stand", "scarf", true, 0 })
rows.push(row { units[1], "stand", "vest", true, 0 })
rows.push(row { units[1], "walk", "scarf", true, 0 })
rows.push(row { units[1], "attack", "scarf", true, 0 })
rows.push(row { units[0], "attack", "scarf", true, 0 })

let args = command_line_arguments()
let out_path = if args.length: args[0] else: "voxel_proto.ppm"
// `romans`: instead, the early Romans and the legionary (against the composed ones)
if args.length > 1 and args[1] == "romans":
    while rows.length: rows.pop()
    for([ units[5], units[6], units[11], units[12] ]) u: rows.push(row { u, "stand", "scarf", true, 0 })
// `looks`: the early Romans and the legionary in each of the three looks
if args.length > 1 and args[1] == "looks":
    while rows.length: rows.pop()
    for([ units[5], units[6], units[11], units[12] ]) u: for(vx_LOOKS) v: rows.push(row { u, "stand", "scarf", true, v })
let step = vx_CELL.x * 3 / 2  // a column (room for the shadows)
// `check`: every unit in every facing, standing and in each walk step, stands in its shadow (vx_contact_gap); exit 1 if not
if args.length > 1 and args[1] == "check":
    var bad = 0
    var n = 0
    for(units) u:
        vx_set_look(u.rc, 0)
        vx_act = ""
        for(9) st:
            let g = vx_fill(vx_unit_prims(u, float(st) * 45.0), u.rc.size)
            for(8) f:
                let cell = copy(vx_cell(g, f))
                let sc = vx_ground_shadow(g, f)
                n++
                var ok = true
                for([ 0.0, 0.35, 0.7 ]) ph: if not vx_stands(cell, sc, 0.55, ph, st == 0): ok = false
                if not ok:
                    bad++
                    print "FLOATS: {u.label}, step {st}, facing {f}: no shadow showing under its feet as the game draws it"
    print "contact: {n} frames, {bad} float"
    if bad: set_exit_code(1)
else:  // the sheet
    let iw = step * 8
    let ih = vx_CELL.y * rows.length
    let img = map(iw * ih): float3 { 86.0, 120.0, 46.0 } / 255.0
    let t0 = seconds_elapsed()
    var fills = 0.0
    for(rows) rw, r:
        let u = rw.u
        vx_set_look(u.rc, rw.look)
        vx_team_wear = rw.wear
        vx_shadows = rw.shade
        vx_act = if rw.mode == "attack": "attack" else: ""
        if rw.mode == "stand":
            let t = seconds_elapsed()
            let stand = vx_fill(vx_unit_prims(u, 0.0), u.rc.size)
            fills += seconds_elapsed() - t
            for(8) c: vx_draw(stand, (c + 3) % 8, img, iw, c * step, r * vx_CELL.y)  // (columns as the composed sheet's)
        else:
            for(8) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 45.0), u.rc.size), 2, img, iw, k * step, r * vx_CELL.y)
        print "{u.label} ({rw.mode}): drawn"
    print "{rows.length} rows in {seconds_elapsed() - t0} s ({fills} s filling the standing ones)"
    let ppm = "P6\n{iw} {ih}\n255\n"
    let bytes = []::int
    for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
    write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
    print "wrote {out_path}"
