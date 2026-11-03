// The procedural voxel units on a sheet (view/voxel.lobster): every unit in 8 facings, walks and attacks, at a
// voxel a baked pixel (the game draws them at 0.55 world px a pixel).
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter box -resize 55% out.png)
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.voxel

class row:
    u:vx_unit_def
    mode:string  // stand (8 facings), walk or attack (8 steps in profile, facing right), die (its fall, two facings)
    wear:string  // the team on a creature: scarf or vest
    shade:bool   // shadows (on the body and the ground)
    look:int     // a human's look (vx_set_look)

vx_load([ "../data/voxel" ])
let ROMAN = float3 { 0.48, 0.29, 0.16 }  // (human_dark, as the romans)
let ROMAN2 = float3 { 0.35, 0.20, 0.13 }
let RAT = float3 { 0.48, 0.35, 0.25 }  // (rat_brown)
let RAT2 = float3 { 0.78, 0.66, 0.58 }
def unit(label:string, body:string, skin:float3, pale:float3, gear:[string], mount:string, coat:float3) -> vx_unit_def:
    return vx_unit_def { label, body, skin, pale, float3_0, gear, mount, false, coat, coat * 0.45, float3_0, nil }
let units = [
    unit("rat worker", "rat", RAT, RAT2, [ "axe", "cap" ], "", float3_0),
    unit("rat spear", "rat", RAT, RAT2, [ "spear", "shield", "cap" ], "", float3_0),
    unit("rat on a cat", "rat", RAT, RAT2, [ "spear", "shield", "cap" ], "cat", float3_0),
    unit("frog spear", "frog", float3_0, float3_0, [ "spear", "shield", "cap" ], "", float3_0),
    unit("roman legionary (age 3)", "human", ROMAN, ROMAN2, [ "gladius", "scutum", "galea", "lorica" ], "", float3_0),
    unit("roman spearbearer (age 1)", "human", ROMAN, ROMAN2, [ "spear", "leather" ], "", float3_0),
    unit("roman clubber (age 1)", "human", ROMAN, ROMAN2, [ "club", "cap", "leather" ], "", float3_0),
    unit("roman archer (age 2)", "human", ROMAN, ROMAN2, [ "bow", "galea", "leather", "quiver" ], "", float3_0),
    unit("roman pilum-thrower (age 2)", "human", ROMAN, ROMAN2, [ "pilum", "scutum", "galea", "leather" ], "", float3_0),
    unit("roman lancer on a pony (age 2)", "human", ROMAN, ROMAN2, [ "spear", "scutum", "galea", "bronze" ], "pony", float3 { 0.66, 0.66, 0.63 }),
    unit("roman healer", "human", ROMAN, ROMAN2, [ "staff" ], "", float3_0),
    unit("roman scavenger", "human", ROMAN, ROMAN2, [ "axe" ], "", float3_0),
    unit("roman legionary (age 2)", "human", ROMAN, ROMAN2, [ "gladius", "scutum", "galea", "bronze" ], "", float3_0),
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
// `creatures`: every creature as a soldier, and every mount ridden
if args.length > 1 and args[1] == "creatures":
    while rows.length: rows.pop()
    let kit = [ "spear", "shield", "cap" ]
    for([ "human", "rat", "frog", "bear", "spider", "beetle_rear" ]) b: rows.push(row { unit(b, b, float3_0, float3_0, kit, "", float3_0), "stand", "scarf", true, 0 })
    let centaur = unit("centaur", "human", float3_0, float3_0, [ "spear", "shield" ], "pony", float3 { 0.66, 0.66, 0.63 })
    centaur.fused = true
    rows.push(row { centaur, "stand", "scarf", true, 0 })
    for([ [ "rat", "cat" ], [ "human", "pony" ], [ "frog", "newt" ], [ "rat", "capybara" ], [ "human", "bear_mount" ], [ "rat", "beetle" ], [ "frog", "spider" ], [ "rat", "hummingbird" ] ]) pr:
        rows.push(row { unit("{pr[0]} on a {pr[1]}", pr[0], float3_0, float3_0, kit, pr[1], float3_0), "stand", "scarf", true, 0 })
    rows.push(row { unit("spider", "spider", float3_0, float3_0, kit, "", float3_0), "walk", "scarf", true, 0 })
// `deaths`: falling dead and lying, in two facings
if args.length > 1 and args[1] == "deaths":
    while rows.length: rows.pop()
    for([ units[1], units[4], units[9], units[0], unit("spider", "spider", float3_0, float3_0, [ "spear", "shield", "cap" ], "", float3_0),
          unit("sheep", "sheep", float3_0, float3_0, [], "", float3_0) ]) u: rows.push(row { u, "die", "scarf", true, 0 })
// `animals`: the wild and herded ones, standing, and the deer walking
if args.length > 1 and args[1] == "animals":
    while rows.length: rows.pop()
    for([ "deer", "boar", "sheep" ]) b: rows.push(row { unit(b, b, float3_0, float3_0, [], "", float3_0), "stand", "scarf", true, 0 })
    rows.push(row { unit("deer", "deer", float3_0, float3_0, [], "", float3_0), "walk", "scarf", true, 0 })
// `legs <body>`: a body standing (8 facings), walking and attacking (8 steps), in its first look, for a close look at its legs
if args.length > 2 and args[1] == "legs":
    while rows.length: rows.pop()
    let b = args[2]
    let kit = if args.length > 3: tokenize(args[3], ",", "") else: [ "spear", "shield", "cap" ]  // (legs <body> [gear,gear])
    let u = if args.length > 3: unit(b, b, float3_0, float3_0, kit, "", float3_0) elif b == "human": units[1] elif b == "rat": units[1 - 1] elif b == "cat": units[2] elif b == "pony": units[9] else: unit(b, b, float3_0, float3_0, kit, "", float3_0)
    let lu = if b == "rat" and args.length <= 3: units[1] elif b == "human" and args.length <= 3: units[5] else: u
    for([ "stand", "walk", "attack" ]) m: rows.push(row { lu, m, "scarf", true, 0 })
// `skins`: a worker in each human palette, each look (no skin may clip to white)
if args.length > 1 and args[1] == "skins":
    while rows.length: rows.pop()
    for([ float3 { 0.94, 0.78, 0.63 }, float3 { 0.78, 0.57, 0.35 }, ROMAN ]) c:
        let u = unit("worker", "human", c, c * 0.8, [ "axe", "cap" ], "", float3_0)
        for(vx_looks_of(u)) v: rows.push(row { u, "stand", "scarf", true, v })
// `looks`: the early Romans and the legionary in each of the three looks
if args.length > 1 and args[1] == "looks":
    while rows.length: rows.pop()
    for([ units[5], units[6], units[11], units[12] ]) u: for(vx_looks_of(u)) v: rows.push(row { u, "stand", "scarf", true, v })
let step = vx_CELL.x * 3 / 2  // a column (room for the shadows)
// `check`: every unit in every facing, standing and in each walk step, stands in its shadow (vx_contact_gap); exit 1 if not
if args.length > 1 and args[1] == "check":
    var bad = 0
    var n = 0
    let all = copy(units)
    let kit = [ "spear", "shield", "cap" ]
    for([ "bear", "spider", "beetle_rear" ]) b: all.push(unit(b, b, float3_0, float3_0, kit, "", float3_0))
    for([ "deer", "boar", "sheep" ]) b: all.push(unit(b, b, float3_0, float3_0, [], "", float3_0))
    for([ [ "frog", "newt" ], [ "rat", "capybara" ], [ "human", "bear_mount" ], [ "rat", "beetle" ], [ "frog", "spider" ] ]) pr: all.push(unit("{pr[0]} on a {pr[1]}", pr[0], float3_0, float3_0, kit, pr[1], float3_0))
    for(filter(all) u: not vx_flies(u)) u:  // (a flier's shadow is on the ground under it)
        vx_set_look(u, 0)
        vx_act = ""
        for(9) st:
            vx_stand = st == 0  // (step 0: standing, as the game's idle frames, every foot planted; then the walk)
            let g = vx_fill(vx_unit_prims(u, float(max(0, st - 1)) * 45.0), vx_size_of(u), vx_flies(u))
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
        vx_set_look(u, rw.look)
        vx_team_wear = rw.wear
        vx_shadows = rw.shade
        vx_act = if rw.mode == "attack": "attack" else: ""
        vx_stand = rw.mode != "walk"
        if rw.mode == "stand":
            let t = seconds_elapsed()
            let stand = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_flies(u))
            fills += seconds_elapsed() - t
            for(8) c: vx_draw(stand, (c + 3) % 8, img, iw, c * step, r * vx_CELL.y)  // (columns as the composed sheet's)
        elif rw.mode == "die":                                                       // (as the game bakes it: 6 steps; the first four facing right, then lying in two more)
            for(8) k:
                let st = min(k, 5)
                let g = vx_fill(vx_fallen(vx_unit_prims(u, 0.0), float(st + 1) / 6.0), vx_size_of(u), false)
                vx_draw(g, if k < 6: 2 else: (if k == 6: 0 else: 5), img, iw, k * step, r * vx_CELL.y)
        else:
            for(8) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 45.0), vx_size_of(u), vx_flies(u)), 2, img, iw, k * step, r * vx_CELL.y)
        print "{u.label} ({rw.mode}): drawn"
    print "{rows.length} rows in {seconds_elapsed() - t0} s ({fills} s filling the standing ones)"
    let ppm = "P6\n{iw} {ih}\n255\n"
    let bytes = []::int
    for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
    write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
    print "wrote {out_path}"
