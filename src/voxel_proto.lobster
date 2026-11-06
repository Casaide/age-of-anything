// The procedural voxel units on a sheet (view/voxel.lobster): every unit in 8 facings, walks and attacks, at a
// voxel a baked pixel (the game draws them at 0.55 world px a pixel).
//   lobster voxel_proto.lobster -- <out.ppm>   (then: magick out.ppm -filter box -resize 55% out.png)
//   lobster voxel_proto.lobster -- <out.ppm> solo <body> [gear,...]   (one body alone at 3x: make it from scratch)
//   lobster voxel_proto.lobster -- <out.ppm or -> parts <body> [voxels:<dir>]   (hull facing by part facing, 8 x 8; checks the part sits on the hull)
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

let PARTS_OFF_PCT = 1.5     // (the outlines where a part meets its hull differ a little)
let FLIER_LIFT_SHARE = 0.5  // how much of its flying height a flier's lowest pixel must be off the ground (its wings hang below its middle)
let AIM_STEPS = 8
let AIM_DROP = 0.5      // body units its muzzle may rise or fall through the firing cycle
let AIM_KICK_MIN = 0.5  // body units the recoil throws it back
let AIM_KICK_MAX = 2.5
let WRECK_KEEPS_PCT = 90  // how much of its standing outline a knocked-out vehicle covers (its turret is knocked askew)
let vx_dirs = [ "../data/voxel" ]
for(command_line_arguments()) a:
    if starts_with(a, "voxels:"): vx_dirs.push(a.substring(7, a.length - 7))  // (more data, a mod's)
vx_load(vx_dirs)
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
// `loads <body>`: a worker walking home with each resource, and picking fruit
if args.length > 2 and args[1] == "loads":
    while rows.length: rows.pop()
    for([ "food", "wood", "stone", "gold" ]) res:
        let tool = vx_load_gear(args[2], res)
        rows.push(row { unit(args[2], args[2], float3_0, float3_0, if tool != "": [ tool, "cap" ] else: [ "cap" ], "", float3_0), "carry_" + res, "scarf", true, 0 })
    rows.push(row { unit(args[2], args[2], float3_0, float3_0, [ "basket", "cap" ], "", float3_0), "attack", "scarf", true, 0 })
// `skins`: a worker in each human palette, each look (no skin may clip to white)
if args.length > 1 and args[1] == "skins":
    while rows.length: rows.pop()
    for([ float3 { 0.94, 0.78, 0.63 }, float3 { 0.78, 0.57, 0.35 }, ROMAN ]) c:
        let u = unit("worker", "human", c, c * 0.8, [ "axe", "cap" ], "", float3_0)
        for(vx_looks_of(u)) v: rows.push(row { u, "stand", "scarf", true, v })
// `engines`: every engine and war beast with its crew (Romans, a rat, a frog), in its first style
def engine(id:string, crew:vx_unit_def) -> vx_unit_def:
    let b = vx_body_of(id)
    return vx_unit_def { id, id, b.style_cols[0], b.style_cols[1], b.style_cols[2], [], "", false, float3_0, float3_0, float3_0, crew }
if args.length > 1 and args[1] == "engines":
    while rows.length: rows.pop()
    let worker = unit("crew", "human", ROMAN, ROMAN2, [ "axe", "cap" ], "", float3_0)
    let pike = unit("pike", "human", ROMAN, ROMAN2, [ "pike", "scutum", "galea", "lorica" ], "", float3_0)
    let rat = unit("rat crew", "rat", RAT, RAT2, [ "axe", "cap" ], "", float3_0)
    for([ "siege.ram", "siege.catapult", "siege.bolt", "siege.tower", "siege.sling", "siege.cart" ]) id, k: rows.push(row { engine(id, if k % 2 == 0: worker else: rat), "stand", "scarf", true, 0 })
    for([ "siege.beast.elephant", "siege.beast.boar", "siege.beast.heron", "siege.beast.mantis", "siege.beast.tarantula" ]) id: rows.push(row { engine(id, pike), "stand", "scarf", true, 0 })
    rows.push(row { engine("siege.ram", worker), "walk", "scarf", true, 0 })
    rows.push(row { engine("siege.beast.elephant", pike), "walk", "scarf", true, 0 })
// `looks`: the early Romans and the legionary in each of the three looks
if args.length > 1 and args[1] == "looks":
    while rows.length: rows.pop()
    for([ units[5], units[6], units[11], units[12] ]) u: for(vx_looks_of(u)) v: rows.push(row { u, "stand", "scarf", true, v })
let step = vx_CELL.x * 3 / 2  // a column (room for the shadows)
// `check`: every unit in every facing, standing and in each walk step, stands in its shadow (vx_contact_gap); exit 1 if not
// What's wrong with a body's parts and running gear: the number of faults. out: a sheet of every pair of facings, or "-".
def parts_faults(id:string, out:string) -> int:
    let b = vx_body_of(id)
    assert b.parts.length
    let u = unit(id, id, float3_0, float3_0, [], "", float3_0)
    vx_set_look(u, 0)
    vx_team_wear = "scarf"
    vx_shadows = true
    vx_act = ""
    vx_stand = true
    let hull = vx_fill(vx_unit_prims(unit(b.hull, b.hull, float3_0, float3_0, [], "", float3_0), 0.0), b.size, true)
    let pieces = map(b.parts) p: vx_fill(vx_unit_prims(unit(p.body, p.body, float3_0, float3_0, [], "", float3_0), 0.0), b.size, true)
    var bad = 0
    for(8) f:
        let cell = copy(vx_cell(hull, f))
        for(b.parts) p:
            let o = vx_pivot_px(b, p, f)
            let at = (vx_ANCHOR.y + int(floor(o.y + 0.5))) * vx_CELL.x + vx_ANCHOR.x + int(floor(o.x + 0.5))
            if cell[at].w <= 0.0:
                print "parts: the pivot of {p.name} is off the hull in facing {f}"
                bad++
    // A belt or wheels: a cycle on is the same picture (no seam), and half a cycle on isn't (they do move).
    if b.track or b.wheels.length:
        let hu = unit(b.hull, b.hull, float3_0, float3_0, [], "", float3_0)
        def colours(ph:float) -> [float4]: return copy(vx_cell(vx_fill(vx_unit_prims(hu, ph), b.size, true), 2))
        let at0, at360, at180 = colours(0.0), colours(360.0), colours(180.0)
        var seam, moved = 0, 0
        for(at0) c, j:
            if magnitude(c - at360[j]) > 0.02: seam++
            if magnitude(c - at180[j]) > 0.02: moved++
        print "parts: running gear: {seam} pixels differ a cycle on, {moved} half a cycle on"
        if seam > 0 or moved == 0:
            print "parts: the running gear does not loop"
            bad++
    // With every part facing as the hull does, the stack must be the whole figure: right place, nothing lost.
    let whole = vx_fill(vx_unit_prims(u, 0.0), b.size, true)
    var worst = 0.0
    for(8) f:
        let want = copy(vx_cell(whole, f))
        let got = map(copy(vx_cell(hull, f))) c: c.w > 0.0
        for(pieces) sh, n:
            let o = vx_pivot_px(b, b.parts[n], f)
            let dx, dy = int(floor(o.x + 0.5)), int(floor(o.y + 0.5))
            let pc = vx_cell(sh, f)
            for(vx_CELL.y) y: for(vx_CELL.x) x:
                if pc[y * vx_CELL.x + x].w > 0.0 and y + dy >= 0 and y + dy < vx_CELL.y and x + dx >= 0 and x + dx < vx_CELL.x:
                    got[(y + dy) * vx_CELL.x + x + dx] = true
        var area, off = 0, 0
        for(want) c, j:
            if c.w > 0.0: area++
            if (c.w > 0.0) != got[j]: off++
        let pct = float(off) * 100.0 / float(max(1, area))
        worst = max(worst, pct)
        if pct > PARTS_OFF_PCT:
            print "parts: stacked in facing {f}, {pct}% of the figure is off the whole one"
            bad++
    for(pieces) sh, n: for(8) f:
        vx_cell(sh, f)
        if vx_box.z < vx_box.x:
            print "parts: {b.parts[n].name} is empty in facing {f}"
            bad++
    // A part's named points are on what's drawn of it, in every facing.
    for(pieces) sh, n: for(b.parts[n].point_names) name, k: for(8) f:
        let c = vx_cell(sh, f)
        let at = vx_part_point_px(b, b.parts[n], k, f)
        let cx, cy = vx_ANCHOR.x + int(floor(at.x + 0.5)), vx_ANCHOR.y + int(floor(at.y + 0.5))
        var on = false
        for(5) dy: for(5) dx:
            if c[(cy + dy - 2) * vx_CELL.x + cx + dx - 2].w > 0.0: on = true
        if not on:
            print "parts: {name} on {b.parts[n].name} is off the picture in facing {f}"
            bad++
    if out != "-":
        let ih = vx_CELL.y * 3 / 4
        let iw = step * 8
        let bg = float3 { 86.0, 120.0, 46.0 } / 255.0
        let img = map(iw * ih * 8): bg
        for(8) hf: for(8) pf:
            vx_draw(hull, hf, img, iw, pf * step, hf * ih - vx_CELL.y / 4)
            for(pieces) sh, n:
                let o = vx_pivot_px(b, b.parts[n], hf)
                vx_draw(sh, pf, img, iw, pf * step + int(floor(o.x + 0.5)), hf * ih - vx_CELL.y / 4 + int(floor(o.y + 0.5)))
            let at, found = vx_point_px(b, "muzzle", "", hf, pf)
            if found:  // (marked in white, to look at)
                let mx, my = pf * step + vx_ANCHOR.x + int(floor(at.x + 0.5)), hf * ih - vx_CELL.y / 4 + vx_ANCHOR.y + int(floor(at.y + 0.5))
                for(3) dy: for(3) dx:
                    let j = (my + dy - 1) * iw + mx + dx - 1
                    if j >= 0 and j < img.length: img[j] = float3_1
        let bytes = []::int
        for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
        write_file(out, "P6\n{iw} {ih * 8}\n255\n" + vector_to_buffer(bytes, 1), 0, 1)
    print "parts: {id}: {64 * b.parts.length} stacked, at worst {worst}% off the whole figure, {bad} faults"
    return bad

if args.length > 1 and args[1] == "check":
    var bad = 0
    var n = 0
    let all = copy(units)
    let kit = [ "spear", "shield", "cap" ]
    for([ "bear", "spider", "beetle_rear" ]) b: all.push(unit(b, b, float3_0, float3_0, kit, "", float3_0))
    for([ "deer", "boar", "sheep" ]) b: all.push(unit(b, b, float3_0, float3_0, [], "", float3_0))
    let crew = unit("crew", "human", ROMAN, ROMAN2, [ "axe", "cap" ], "", float3_0)
    for([ "siege.ram", "siege.catapult", "siege.bolt", "siege.tower", "siege.sling", "siege.cart", "siege.beast.elephant", "siege.beast.boar", "siege.beast.heron", "siege.beast.mantis",
          "siege.beast.tarantula" ]) id: all.push(engine(id, crew))
    for([ [ "frog", "newt" ], [ "rat", "capybara" ], [ "human", "bear_mount" ], [ "rat", "beetle" ], [ "frog", "spider" ] ]) pr: all.push(unit("{pr[0]} on a {pr[1]}", pr[0], float3_0, float3_0, kit, pr[1], float3_0))
    for(filter(all) u: not vx_flies(u)) u:  // (a flier's shadow is on the ground under it)
        vx_set_look(u, 0)
        vx_act = ""
        for(9) st:
            vx_stand = st == 0  // (step 0: standing, as the game's idle frames, every foot planted; then the walk)
            let g = vx_fill(vx_unit_prims(u, float(max(0, st - 1)) * 45.0), vx_size_of(u), vx_on_zero(u, false))
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
elif args.length > 2 and args[1] == "parts":  // `parts <body>`: every hull facing (rows) with every part facing (columns)
    assert parts_faults(args[2], out_path) == 0
elif args.length > 1 and args[1] == "aim":  // `aim`: every rifle on every body that carries it: the gun stays up through the firing cycle, kicks, and comes back (#261)
    var bad = 0
    let crew = unit("rifleman", "gi_1944", ROMAN, ROMAN2, [ "ww2_rifle" ], "", float3_0)
    vx_set_look(crew, 0)
    vx_act = "attack"
    vx_stand = true
    def muzzle(ph:float) -> float3:
        var best = float3 { 0.0, -1000.0, 0.0 }
        for(vx_unit_prims(crew, ph)) p:
            if p.hard and p.b.y > best.y: best = p.b
        return best
    let at0 = muzzle(0.0)
    var lo, hi, back = at0.z, at0.z, at0.y
    let steps = []::float3
    for(AIM_STEPS) i:
        let m = muzzle(float(i) * 360.0 / float(AIM_STEPS))
        steps.push(m)
        lo = min(lo, m.z)
        hi = max(hi, m.z)
        back = min(back, m.y)
    let held = muzzle(float(AIM_STEPS - 1) * 360.0 / float(AIM_STEPS))
    let kick = held.y - back
    print "aim: muzzle height {lo} to {hi} through the cycle (moves {hi - lo}, at most {AIM_DROP} allowed); kick back {kick} (between {AIM_KICK_MIN} and {AIM_KICK_MAX})"
    if hi - lo > AIM_DROP:
        print "aim: the gun drops through the firing cycle"
        bad++
    if kick < AIM_KICK_MIN or kick > AIM_KICK_MAX:
        print "aim: no kick from the gun"
        bad++
    print "aim: between shots a rifleman draws {vx_between_shots(true, false)}, a bowman {vx_between_shots(false, false)}"
    if vx_between_shots(true, false) != "attack" or vx_between_shots(true, true) == "attack" or vx_between_shots(false, false) == "attack":
        print "aim: a rifleman lowers the gun between shots"
        bad++
    assert bad == 0
elif args.length > 1 and args[1] == "bodies":  // `bodies`: every body loaded (the game's, and any voxels: dirs), fliers too
    var bad = 0
    var n = 0
    assert vx_dist(float3 { 5.0, 0.0, 0.0 }, vx_box(float3_0, float3 { 0.0, 0.0, 1.0 }, float3 { 1.0, 1.0, 0.1 }, 0.0, 0)) > 0.0  // (a box facing straight up has edges)
    for(sorted_strs(vx_bodies.get_keys())) id:
        if find_string(id, "#") < 0:
            n++
            let b = vx_body_of(id)
            let u = unit(id, id, float3_0, float3_0, [], "", float3_0)
            vx_set_look(u, 0)
            vx_act = ""
            vx_stand = true
            let g = vx_fill(vx_unit_prims(u, 0.0), b.size, vx_on_zero(u, false))
            for(8) f:
                vx_cell(g, f)
                if vx_box.z < vx_box.x:
                    print "bodies: {id} draws nothing in facing {f}"
                    bad++
            if b.flies > 0.0:  // (built the way the game builds it, an engine with its crew if it has styles)
                let worker = unit("crew", "human", ROMAN, ROMAN2, [ "axe" ], "", float3_0)
                let fu = if b.style_names.length: engine(id, worker) else: u
                vx_set_look(fu, 0)
                let fg = vx_fill(vx_unit_prims(fu, 0.0), b.size, vx_on_zero(fu, false))
                let want = int(b.flies * cos(vx_ELEV) * vx_RES * b.size * FLIER_LIFT_SHARE)
                var least = 1000000
                for(8) f:
                    vx_cell(fg, f)
                    least = min(least, vx_ANCHOR.y - vx_box.w)
                print "bodies: {id} flies at {b.flies}: lowest pixel {least} above its ground point, at least {want} wanted"
                if least < want:
                    print "bodies: {id} is drawn on the ground"
                    bad++
            if b.death == "knocked_out":  // (it stays where it stood: nearly the same outline as standing, and the old fall isn't)
                let up = map(copy(vx_cell(g, 2))) c: c.w > 0.0
                let wreck = vx_fill(vx_knocked_out(u, b), b.size, vx_on_zero(u, true))
                let fell = vx_fill(vx_fallen(vx_unit_prims(u, 0.0), 1.0), b.size, vx_on_zero(u, true))
                def kept(sh:vx_shape) -> int:
                    var hit, all = 0, 0
                    for(vx_cell(sh, 2)) c, j:
                        if up[j]: all++
                        if up[j] and c.w > 0.0: hit++
                    return hit * 100 / max(1, all)
                let as_wreck, as_fallen = kept(wreck), kept(fell)
                print "bodies: {id} knocked out keeps {as_wreck}% of its outline (the old fall keeps {as_fallen}%), {WRECK_KEEPS_PCT}% wanted"
                if as_wreck < WRECK_KEEPS_PCT:
                    print "bodies: {id} does not stay where it stood"
                    bad++
            if b.parts.length: bad += parts_faults(id, "-")
    print "bodies: {n} bodies, {bad} faults"
    assert bad == 0
elif args.length > 2 and args[1] == "solo":  // `solo <body> [gear,...]`: one body alone, 3x, four facings standing then four walk steps (for making it from scratch)
    let kit = if args.length > 3 and not starts_with(args[3], "voxels:"): tokenize(args[3], ",", "") else: []
    let u = unit(args[2], args[2], float3_0, float3_0, kit, "", float3_0)
    vx_set_look(u, 0)
    vx_team_wear = "scarf"
    vx_shadows = true
    vx_act = ""
    let iw = step * 8
    let ih = vx_CELL.y
    let bg = float3 { 86.0, 120.0, 46.0 } / 255.0
    let img = map(iw * ih): bg
    vx_stand = true
    let stand = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_on_zero(u, false))
    for(4) c: vx_draw(stand, (c * 2 + 3) % 8, img, iw, c * step, 0)
    vx_stand = false
    for(4) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 90.0), vx_size_of(u), vx_on_zero(u, false)), 2, img, iw, (k + 4) * step, 0)
    var x0, y0, x1, y1 = step, ih, 0, 0  // one box round the figure, the same in every cell (relative to the cell)
    for(ih) y: for(iw) x:
        if img[y * iw + x] != bg:
            x0 = min(x0, x % step)
            y0 = min(y0, y)
            x1 = max(x1, x % step)
            y1 = max(y1, y)
    x0, y0 = max(0, x0 - 3), max(0, y0 - 3)
    x1, y1 = min(step - 1, x1 + 3), min(ih - 1, y1 + 3)
    let Z = 3
    let cw = x1 - x0 + 1
    let ow, oh = cw * 8 * Z, (y1 - y0 + 1) * Z
    let bytes = []::int
    for(oh) y: for(ow) x:
        let cx = x / Z
        let c = img[(y0 + y / Z) * iw + (cx / cw) * step + x0 + cx % cw]
        for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
    write_file(out_path, "P6\n{ow} {oh}\n255\n" + vector_to_buffer(bytes, 1), 0, 1)
    print "wrote {out_path} ({args[2]} alone, 3x: four facings standing, four walk steps)"
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
        let carrying = find_string(rw.mode, "carry_") == 0
        vx_carried = if carrying: rw.mode.substring(6, rw.mode.length - 6) else: ""
        vx_stand = rw.mode != "walk" and not carrying
        if rw.mode == "stand":
            let t = seconds_elapsed()
            let stand = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_on_zero(u, false))
            fills += seconds_elapsed() - t
            for(8) c: vx_draw(stand, (c + 3) % 8, img, iw, c * step, r * vx_CELL.y)  // (columns as the composed sheet's)
        elif rw.mode == "die":                                                       // (as the game bakes it: 6 steps; the first four facing right, then lying in two more)
            for(8) k:
                let st = min(k, 5)
                let g = vx_fill(vx_fallen(vx_unit_prims(u, 0.0), float(st + 1) / 6.0), vx_size_of(u), false)
                vx_draw(g, if k < 6: 2 else: (if k == 6: 0 else: 5), img, iw, k * step, r * vx_CELL.y)
        else:
            for(8) k: vx_draw(vx_fill(vx_unit_prims(u, float(k) * 45.0), vx_size_of(u), vx_on_zero(u, false)), 2, img, iw, k * step, r * vx_CELL.y)
        print "{u.label} ({rw.mode}): drawn"
    print "{rows.length} rows in {seconds_elapsed() - t0} s ({fills} s filling the standing ones)"
    let ppm = "P6\n{iw} {ih}\n255\n"
    let bytes = []::int
    for(img) c: for(3) ch: bytes.push(clamp(int(c[ch] * 255.0), 0, 255))
    write_file(out_path, ppm + vector_to_buffer(bytes, 1), 0, 1)
    print "wrote {out_path}"
