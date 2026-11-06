// ------------------------------------------------------------------ the future's buildings (#214)
// The `future` architecture (the space mod's spacefarers): plated metal, dark glass, glowing strips, team bands. Its
// town centre, barracks, houses, tower, mill, mining and lumber camps and armoury have their own models (#248); the rest are stone's.

// The future's plating, its dark trim, glass, and the glow of its lights.
def fut_plate() -> MMat: return bflat(html("#d2d6dc"), 0.55, 0.25)
def fut_dark() -> MMat: return bflat(html("#4a505a"), 0.55, 0.35)
def fut_glass() -> MMat: return bflat(html("#3a7088"), 0.25, 0.4)
def fut_glow() -> MMat: return bglow(html("#56e6ff"), 2.2)

// A command hub: an eight-sided plated drum under a dark glass dome on a stepped deck, a ring of glowing windows, a
// team band, two side pods, and a mast with a beacon.
def future_town_center(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    let glow = fut_glow()
    add_child(body, bcyl(1.6, 1.7, 0.14, dark, bv(0.0, 0.07, 0.0), bv(0.0, 22.5, 0.0), 8))  // the deck
    add_child(body, bcyl(1.4, 1.5, 0.12, plate, bv(0.0, 0.2, 0.0), bv(0.0, 22.5, 0.0), 8))
    let base = 0.26
    let h = 1.05
    add_child(body, bcyl(1.0, 1.12, h, plate, bv(0.0, base + h / 2.0, 0.0), bv(0.0, 22.5, 0.0), 8))              // the drum
    add_child(body, bcyl(1.05, 1.05, 0.12, bcloth(team), bv(0.0, base + h - 0.08, 0.0), bv(0.0, 22.5, 0.0), 8))  // its team band
    let lights = []::float3
    for(8) k:  // a glowing window on each face
        let a = float(k) * 45.0
        let r = 1.07
        let at = bv(sin(a) * r, base + h * 0.45, cos(a) * r)
        if k == 1 or k == 2 or k == 7:  // (lit only where the camera sees them: a glow on a far face shows through)
            add_child(body, bbox(bv(0.34, 0.12, 0.03), glow, at, bv(0.0, a, 0.0)))
            lights.push(at)
    add_child(body, bdome(0.92, fut_glass(), bv(0.0, base + h, 0.0), bv(1.0, 0.8, 1.0)))  // the dome
    add_child(body, bring(0.05, 0.94, dark, bv(0.0, base + h + 0.02, 0.0)))               // (a torus lies flat)
    add_child(body, bball(0.14, glow, bv(0.0, base + h + 0.76, 0.0)))                     // the dome's crown light
    for([ -1.0, 1.0 ]) side:                                                              // the side pods
        let pod = bv(side * 1.25, base, -0.35)
        add_child(body, bbox(bv(0.55, 0.55, 0.8), plate, pod + bv(0.0, 0.275, 0.0)))
        add_child(body, bbox(bv(0.6, 0.08, 0.85), dark, pod + bv(0.0, 0.58, 0.0)))
        add_child(body, bbox(bv(0.03, 0.08, 0.5), glow, pod + bv(side * 0.29, 0.32, 0.0)))
    add_child(body, bbox(bv(0.5, 0.55, 0.2), dark, bv(0.0, base + 0.275, 1.08)))  // the door
    add_child(body, bbox(bv(0.38, 0.44, 0.02), bflat(html("#14181e"), 0.3, 0.4), bv(0.0, base + 0.24, 1.19)))
    add_child(body, bbox(bv(0.42, 0.04, 0.03), glow, bv(0.0, base + 0.5, 1.2)))
    let mast = bv(-1.25, base, 0.75)  // the mast and its beacon
    add_child(body, bcyl(0.04, 0.06, 2.3, dark, mast + bv(0.0, 1.15, 0.0), float3_0, 8))
    for([ 0.9, 1.6 ]) y: add_child(body, bcyl(0.16, 0.16, 0.03, plate, mast + bv(0.0, y, 0.0), float3_0, 8))
    let top = mast + bv(0.0, 2.35, 0.0)
    add_child(body, bball(0.09, bglow(html("#ff5a3a"), 2.5), top))
    lights.push(top)
    let sp = bspec(body)
    blights(sp, lights)
    return bdoorway(sp, bld_doorway(bv(0.0, base, 1.2), 0.38, 0.44))

// A drop barracks: a long plated hangar, half a drum on its side, on a deck; a wide door striped with light at the
// front, ribs over the roof, a team band, two pylons, and a drop pod standing ready in the yard.
def future_barracks(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    let glow = fut_glow()
    let w = 2.3
    let r = 0.72
    let zc = -0.45
    add_child(body, bbox(bv(w + 0.3, 0.12, 1.9), dark, bv(0.0, 0.06, zc + 0.15)))     // the deck
    add_child(body, bbox(bv(w, 0.62, 2.0 * r), plate, bv(0.0, 0.43, zc)))             // the hangar's walls, up to the drum's middle (no drum under the ground)
    add_child(body, bcyl(r, r, w, plate, bv(0.0, 0.74, zc), bv(0.0, 0.0, 90.0), 16))  // its roof: half a drum
    for([ -0.8, -0.27, 0.27, 0.8 ]) x:                                                // ribs over it
        add_child(body, bcyl(r + 0.02, r + 0.02, 0.05, dark, bv(x, 0.74, zc), bv(0.0, 0.0, 90.0), 16))
    add_child(body, bcyl(r + 0.02, r + 0.02, 0.14, bcloth(team), bv(0.0, 0.74, zc), bv(0.0, 0.0, 90.0), 16))  // the team band
    let front = zc + r
    add_child(body, bbox(bv(1.1, 0.75, 0.06), dark, bv(0.0, 0.5, front + 0.02)))  // the door
    let lights = []::float3
    for([ 0.3, 0.52, 0.74 ]) y:
        add_child(body, bbox(bv(0.9, 0.035, 0.02), glow, bv(0.0, y, front + 0.06)))
    lights.push(bv(0.0, 0.52, front + 0.08))
    for([ -1.0, 1.0 ]) side:  // the pylons at the hangar's ends
        let at = bv(side * (w / 2.0 + 0.05), 0.12, zc + r * 0.6)
        add_child(body, bbox(bv(0.18, 1.5, 0.18), dark, at + bv(0.0, 0.75, 0.0)))
        add_child(body, bbox(bv(0.2, 0.06, 0.2), glow, at + bv(0.0, 1.52, 0.0)))
        lights.push(at + bv(0.0, 1.52, 0.0))
    let pod = bv(0.85, 0.12, 0.95)  // a drop pod in the yard, its fins on the ground
    add_child(body, bcyl(0.12, 0.24, 0.55, plate, pod + bv(0.0, 0.32, 0.0), float3_0, 8))
    add_child(body, bball(0.24, plate, pod + bv(0.0, 0.08, 0.0), bv(1.0, 0.5, 1.0)))
    add_child(body, bcyl(0.13, 0.13, 0.08, bcloth(team), pod + bv(0.0, 0.42, 0.0), float3_0, 8))
    for(3) k:
        let a = float(k) * 120.0
        add_child(body, bbox(bv(0.04, 0.26, 0.2), dark, pod + bv(sin(a) * 0.22, 0.13, cos(a) * 0.22), bv(0.0, a, 0.0)))
    add_child(body, bbox(bv(0.05, 0.1, 0.03), glow, pod + bv(0.0, 0.38, 0.2)))
    for(5) k:  // the yard's edge lights
        let x = -1.2 + float(k) * 0.6
        add_child(body, bbox(bv(0.06, 0.04, 0.06), glow, bv(x, 0.14, 1.3)))
    let sp = bspec(body)
    blights(sp, lights)
    return bdoorway(sp, bld_doorway(bv(0.0, 0.12, front + 0.06), 0.9, 0.7))

// A habitat pod: a small plated drum under a glass cap, a glowing window, a team stripe.
def future_house(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    add_child(body, bcyl(0.55, 0.6, 0.08, fut_dark(), bv(0.0, 0.04, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bcyl(0.45, 0.5, 0.45, plate, bv(0.0, 0.3, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bcyl(0.47, 0.47, 0.07, bcloth(team), bv(0.0, 0.47, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bdome(0.42, fut_glass(), bv(0.0, 0.52, 0.0), bv(1.0, 0.55, 1.0)))
    let at = bv(0.0, 0.3, 0.49)
    add_child(body, bbox(bv(0.22, 0.1, 0.03), fut_glow(), at))
    let sp = bspec(body)
    blights(sp, [ at ])
    bpt(sp, "door", bv(0.0, 0.0, 1.0))
    return bdoorway(sp, bld_doorway(bv(0.3, 0.08, 0.4), 0.16, 0.3))

// A sensor pylon: a tapered plated mast on a deck, a gun pod and a dish near the top, glowing bands, a team band.
def future_tower(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    let glow = fut_glow()
    let top = 1.75
    add_child(body, bcyl(0.5, 0.55, 0.1, dark, bv(0.0, 0.05, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bcyl(0.2, 0.34, top, plate, bv(0.0, top / 2.0, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bcyl(0.3, 0.3, 0.1, bcloth(team), bv(0.0, 0.55, 0.0), bv(0.0, 22.5, 0.0), 8))
    for([ 0.95, 1.35 ]) y: add_child(body, bcyl(0.26, 0.26, 0.04, dark, bv(0.0, y, 0.0), bv(0.0, 22.5, 0.0), 8))
    add_child(body, bbox(bv(0.08, 0.5, 0.03), glow, bv(0.0, 0.3 + 0.55, 0.3)))  // a glowing strip down the front
    add_child(body, bbox(bv(0.46, 0.26, 0.38), dark, bv(0.0, top + 0.1, 0.0)))  // the gun pod
    add_child(body, bbox(bv(0.05, 0.05, 0.4), plate, bv(-0.1, top + 0.12, 0.35)))
    add_child(body, bbox(bv(0.05, 0.05, 0.4), plate, bv(0.1, top + 0.12, 0.35)))
    add_child(body, bbox(bv(0.3, 0.05, 0.02), glow, bv(0.0, top + 0.2, 0.2)))
    add_child(body, bcyl(0.2, 0.04, 0.06, plate, bv(0.0, top + 0.34, -0.05), bv(-30.0, 0.0, 0.0), 12))  // the dish
    let light = bv(0.0, top + 0.2, 0.21)
    let sp = bspec(body)
    blights(sp, [ light ])
    return bpt(sp, "lantern", light)

// A hydroponics bay: a long low plated tray under three glass arches, green rows glowing inside, a water tank and
// crates of produce.
def future_mill(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    add_child(body, bbox(bv(1.5, 0.12, 1.2), dark, bv(0.0, 0.06, -0.1)))
    add_child(body, bbox(bv(1.3, 0.2, 0.9), plate, bv(0.0, 0.22, -0.15)))
    let leaf = bflat(html("#5fae3a"), 0.8)
    for([ -0.4, 0.0, 0.4 ]) x:
        add_child(body, bcyl(0.38, 0.38, 0.32, fut_glass(), bv(x, 0.32, -0.15), bv(0.0, 0.0, 90.0), 12))  // a glass arch
        add_child(body, bring(0.02, 0.39, dark, bv(x + 0.15, 0.32, -0.15), bv(0.0, 0.0, 90.0)))
        for([ -0.35, 0.0 ]) z: add_child(body, bball(0.09, leaf, bv(x, 0.45, z - 0.1), bv(1.0, 0.7, 1.4)))
    add_child(body, bbox(bv(1.3, 0.06, 0.04), bcloth(team), bv(0.0, 0.3, 0.31)))      // a team band along the front
    add_child(body, bcyl(0.2, 0.2, 0.55, plate, bv(0.55, 0.38, 0.45), float3_0, 12))  // the water tank
    add_child(body, bcyl(0.21, 0.21, 0.05, dark, bv(0.55, 0.62, 0.45), float3_0, 12))
    let light = bv(0.55, 0.4, 0.66)
    add_child(body, bbox(bv(0.12, 0.03, 0.02), fut_glow(), light))
    let crate = bflat(html("#8a9098"), 0.6, 0.3)
    for([ bv(-0.5, 0.1, 0.5), bv(-0.22, 0.1, 0.55) ]) p:
        add_child(body, bbox(bv(0.24, 0.16, 0.2), crate, p))
        add_child(body, bball(0.06, bflat(html("#d8b44a"), 0.8), p + bv(0.0, 0.1, 0.0)))
    let sp = bspec(body)
    blights(sp, [ light ])
    return bpt(sp, "lantern", light)

// An ore extractor: a plated drill rig over a glowing bore, a hopper, and a cart of stone and gold.
def future_mining_camp(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    let glow = fut_glow()
    add_child(body, bbox(bv(1.4, 0.1, 1.2), dark, bv(0.0, 0.05, -0.05)))
    let bore = bv(0.3, 0.0, -0.15)
    add_child(body, bcyl(0.28, 0.28, 0.04, bglow(html("#ff8a3a"), 1.6), bore + bv(0.0, 0.11, 0.0), float3_0, 12))  // the bore, hot
    for([ -1.0, 1.0 ]) sx:                                                                                         // the rig's legs and its head
        for([ -1.0, 1.0 ]) sz:
            add_child(body, beam(bore + bv(sx * 0.4, 0.1, sz * 0.35), bore + bv(sx * 0.12, 1.15, sz * 0.1), 0.035, dark))
    add_child(body, bbox(bv(0.4, 0.3, 0.36), plate, bore + bv(0.0, 1.2, 0.0)))
    add_child(body, bbox(bv(0.42, 0.08, 0.38), bcloth(team), bore + bv(0.0, 1.0, 0.0)))
    add_child(body, bcyl(0.06, 0.06, 0.9, plate, bore + bv(0.0, 0.6, 0.0), float3_0, 8))  // the drill
    add_child(body, bbox(bv(0.2, 0.04, 0.02), glow, bore + bv(0.0, 1.25, 0.19)))
    add_child(body, bcyl(0.3, 0.16, 0.4, plate, bv(-0.45, 0.4, -0.35), float3_0, 8))  // the hopper
    add_child(body, bbox(bv(0.1, 0.2, 0.1), dark, bv(-0.45, 0.1, -0.35)))
    add_child(body, bbox(bv(0.5, 0.15, 0.3), plate, bv(-0.35, 0.2, 0.5)))  // the cart
    for([ -0.55, -0.15 ]) x: add_child(body, bcyl(0.08, 0.08, 0.04, dark, bv(x, 0.08, 0.66), bv(90.0, 0.0, 0.0), 12))
    let stone = bflat(html("#e6d4b0"), 0.9)
    let gold = bflat(html("#f2c440"), 0.3, 0.8)
    for(4) n: add_child(body, bball(0.07, if n % 2 == 0: stone else: gold, bv(-0.5 + float(n) * 0.1, 0.32, 0.5)))
    let light = bore + bv(0.0, 1.25, 0.2)
    let sp = bspec(body)
    blights(sp, [ light ])
    return bpt(sp, "lantern", light)

// A cutting bay: a plated shed open at the front, a cutting arm over a bench, stacked logs and a team tarp.
def future_lumber_camp(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    add_child(body, bbox(bv(1.4, 0.1, 1.1), dark, bv(0.0, 0.05, -0.05)))
    add_child(body, bbox(bv(1.2, 0.65, 0.08), plate, bv(0.0, 0.42, -0.5)))  // the shed: back, sides and roof
    for([ -0.6, 0.6 ]) x: add_child(body, bbox(bv(0.08, 0.65, 0.6), plate, bv(x, 0.42, -0.22)))
    add_child(body, bbox(bv(1.32, 0.08, 0.72), dark, bv(0.0, 0.78, -0.2), bv(-8.0, 0.0, 0.0)))
    add_child(body, bbox(bv(1.2, 0.06, 0.04), bcloth(team), bv(0.0, 0.7, 0.13)))
    add_child(body, bbox(bv(0.7, 0.25, 0.3), dark, bv(0.0, 0.22, -0.2)))  // the bench and its cutting arm
    add_child(body, bbox(bv(0.06, 0.06, 0.4), plate, bv(0.0, 0.62, -0.25)))
    add_child(body, bbox(bv(0.04, 0.2, 0.04), plate, bv(0.0, 0.5, -0.07)))
    let beam_at = bv(0.0, 0.36, -0.07)
    add_child(body, bbox(bv(0.02, 0.06, 0.02), fut_glow(), beam_at))
    let wood = bm("wood")
    for(3) n: add_child(body, bcyl(0.07, 0.07, 0.5, wood, bv(-0.3 + float(n) * 0.14, 0.17, 0.4), bv(0.0, 0.0, 90.0), 10))
    for(2) n: add_child(body, bcyl(0.07, 0.07, 0.5, wood, bv(-0.23 + float(n) * 0.14, 0.29, 0.4), bv(0.0, 0.0, 90.0), 10))
    let sp = bspec(body)
    blights(sp, [ beam_at ])
    return sp

// A fabricator: a squat plated block with a sloped dark roof, an arm over a glowing work bed at the front, a rack of
// rifles and a team band.
def future_armoury(team:float3) -> BSpec:
    let body = mnode()
    let plate = fut_plate()
    let dark = fut_dark()
    let glow = fut_glow()
    add_child(body, bbox(bv(1.5, 0.1, 1.3), dark, bv(0.0, 0.05, -0.05)))
    add_child(body, bbox(bv(1.1, 0.75, 0.8), plate, bv(-0.1, 0.47, -0.3)))
    add_child(body, bbox(bv(1.16, 0.1, 0.86), dark, bv(-0.1, 0.88, -0.3)))
    add_child(body, bbox(bv(1.12, 0.1, 0.82), bcloth(team), bv(-0.1, 0.68, -0.3)))
    add_child(body, bbox(bv(0.5, 0.45, 0.04), bflat(html("#14181e"), 0.3, 0.4), bv(-0.1, 0.33, 0.11)))  // the bay door
    let bed = bv(0.35, 0.0, 0.4)
    add_child(body, bbox(bv(0.5, 0.2, 0.36), dark, bed + bv(0.0, 0.2, 0.0)))
    add_child(body, bbox(bv(0.38, 0.02, 0.24), glow, bed + bv(0.0, 0.31, 0.0)))
    add_child(body, beam(bed + bv(0.2, 0.3, -0.15), bed + bv(0.15, 0.75, -0.05), 0.03, plate))  // the arm
    add_child(body, beam(bed + bv(0.15, 0.75, -0.05), bed + bv(-0.02, 0.45, 0.0), 0.025, plate))
    for(3) n:  // the rifle rack
        add_child(body, bbox(bv(0.04, 0.4, 0.04), dark, bv(-0.65 + float(n) * 0.12, 0.3, 0.3), bv(10.0, 0.0, 0.0)))
    add_child(body, bbox(bv(0.4, 0.04, 0.06), plate, bv(-0.53, 0.42, 0.28)))
    let light = bed + bv(0.0, 0.33, 0.0)
    let sp = bspec(body)
    blights(sp, [ light ])
    bpt(sp, "lantern", light)
    return bpt(sp, "smoke", bv(-0.4, 1.0, -0.5))
