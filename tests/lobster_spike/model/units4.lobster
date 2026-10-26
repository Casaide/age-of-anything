// ------------------------------------------------------------------ unit parts IV (unit_models.gd 2234-3059: weapons, shields, helmets, armour, backs, tools, loads)
// Each builder is unit_models.gd's of the same name (`_weapon_dory` -> weapon_dory), line for line; its
// comments are there. _sword, curved, _sample, grip, tassel, _bright_iron, _box and _lift are base.lobster's
// sword, curved, sample_ws, grip, tassel, bright_iron, box and lift_kids.

// A list of points from x, y pairs.
def u4_pts(xy:[float]) -> [float2]: return map(xy.length / 2) i: float2 { xy[i * 2], xy[i * 2 + 1] }

// Godot's Color.lerp.
def u4_lerp(a:float3, b:float3, t:float) -> float3: return a + (b - a) * t

// A box mesh node turned by radians (Godot's `rotation =`), as the GDScript's inline BoxMeshes.
def u4_box_rad(size:float3, m:MMat, pos:float3, rot_rad:float3) -> MNode:
    return box(size, m, pos, float3 { rad(rot_rad.x), rad(rot_rad.y), rad(rot_rad.z) })

// ------------------------------------------------------------------ weapons

def pole(n:MNode, a:float3, b:float3, r:float, head:[float2], head_mat:MMat) -> float3:
    add_child(n, rod(a, b, r, r * 0.95, surf("wood_grain", float3_1, 8.0), false))
    let d = normalize(b - a)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(head, 0.8, head_mat, b, ang))
    add_child(n, ring(r * 0.8, r * 1.4, head_mat, b - d * 0.4, float3 { 0.0, 0.0, ang - 90.0 }))
    return d

def weapon_pike_iron(c:Colours) -> Spec:
    let n = mnode()
    pole(n, float3 { 5.0, -5.0, 0.0 }, float3 { -13.0, 27.0, 0.0 }, 0.85, u4_pts([0.0, -1.3, 8.0, 0.0, 0.0, 1.3, -1.0, 0.0]), surf("iron", float3_1, 3.0))
    return spec_of(n)

def weapon_dory(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3_1, 3.0)
    let d = pole(n, float3 { -8.0, -5.0, 0.0 }, float3 { 20.0, 11.0, 0.0 }, 0.85, u4_pts([0.0, -1.8, 3.0, -1.6, 7.0, 0.0, 3.0, 1.6, 0.0, 1.8, -1.2, 0.0]), bronze)
    add_child(n, rod(float3 { -8.0, -5.0, 0.0 }, float3 { -8.0, -5.0, 0.0 } - d * 3.0, 0.9, 0.3, bronze))
    return spec_of(n)

def weapon_pilum(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    let d = float3 { 0.62, 0.78, 0.0 }
    let a = -d * 4.0
    let b = d * 10.0
    add_child(n, rod(a, b, 0.55, 0.55, surf("wood_grain", float3_1, 6.0), false))
    let tip = b + d * 10.0
    add_child(n, rod(b, tip, 0.35, 0.3, iron, false))
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, ring(0.45, 0.7, iron, b, float3 { 0.0, 0.0, ang - 90.0 }))
    add_child(n, blade(u4_pts([0.0, -0.9, 2.6, 0.0, 0.0, 0.9]), 0.8, iron, tip, ang))
    return spec_of(n)

def weapon_lance(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -10.0, -2.0, 0.0 }
    let b = float3 { 26.0, 4.0, 0.0 }
    let d = normalize(b - a)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, rod(a, b, 1.3, 0.7, surf("wood_grain", float3_1, 8.0), false))
    add_child(n, cone(0.9, 3.0, 2.4, surf("iron", float3_1, 3.0), a + d * 12.0, float3 { 0.0, 0.0, ang + 90.0 }))
    add_child(n, blade(u4_pts([0.0, -0.9, 5.0, 0.0, 0.0, 0.9]), 1.0, surf("iron", float3_1, 3.0), b, ang))
    add_child(n, blade(u4_pts([0.0, 0.0, -6.5, -0.6, -4.5, -2.0, -6.5, -3.6, -0.5, -3.4]), 0.3, surf("cloth", c.team, 4.0), b - d * 2.5, ang))
    return spec_of(n)

def weapon_club_bone(c:Colours) -> Spec:
    let n = mnode()
    let bone = surf("bone", float3_1, 4.0)
    add_child(n, rod(float3 { -2.0, -2.0, 0.0 }, float3 { 6.0, 8.5, 0.0 }, 1.2, 1.8, bone))
    add_child(n, blob(float3 { 3.0, 3.2, 2.8 }, bone, float3 { 6.6, 10.0, 0.0 }))
    for(3) k:
        let a = rad(float(k) * 2.1)
        add_child(n, blob(float3 { 1.0, 1.0, 1.0 }, bone, float3 { 6.6, 10.0, 0.0 } + float3 { cos(a), sin(a), 0.6 } * 2.8))
    add_child(n, ring(1.2, 1.8, surf("leather", float3_1, 3.0), float3 { -0.8, -0.4, 0.0 }, float3 { 0.0, 0.0, -36.0 }))
    return spec_of(n)

def weapon_sword_bronze(c:Colours) -> Spec:
    let bronze = surf("bronze", float3_1, 3.0)
    return spec_of(sword(u4_pts([0.0, -1.0, 8.0, -1.5, 14.4, 0.0, 8.0, 1.5, 0.0, 1.0]), float3 { 3.0, 14.0, 0.0 }, bronze, surf("wood_grain", float3_1, 3.0)))

def weapon_sword_iron(c:Colours) -> Spec:
    let iron = surf("iron", float3_1, 3.0)
    return spec_of(sword(u4_pts([0.0, -1.1, 13.5, -0.9, 15.4, 0.0, 13.5, 0.9, 0.0, 1.1]), float3 { 3.0, 15.0, 0.0 }, iron, iron))

def weapon_gladius(c:Colours) -> Spec:
    return spec_of(sword(u4_pts([0.0, -1.4, 5.0, -1.2, 8.5, -1.4, 11.2, 0.0, 8.5, 1.4, 5.0, 1.2, 0.0, 1.4]),
        float3 { 2.0, 11.0, 0.0 }, surf("iron", float3_1, 3.0), surf("bronze", float3_1, 2.0)))

// ------------------------------------------------------------------ the swordsman's age-3 kit (S3, D-125)

let SWORD3_TIP = float3 { 3.0, 14.0, 0.0 }

def weapon_sword_iron_plain(c:Colours) -> Spec:
    return spec_of(sword(u4_pts([0.0, -1.1, 13.5, -0.9, 15.4, 0.0, 13.5, 0.9, 0.0, 1.1]),
        float3 { 3.0, 15.0, 0.0 }, bright_iron(), surf("iron", float3_1, 3.0)))

def weapon_sword_xiphos(c:Colours) -> Spec:
    let pts = u4_pts([0.0, -0.9, 5.0, -1.0, 11.5, -1.9, 15.5, -1.2, 18.2, 0.0,
        15.5, 1.2, 11.5, 1.9, 5.0, 1.0, 0.0, 0.9])
    return spec_of(sword(pts, SWORD3_TIP, bright_iron(), surf("bronze", float3 { 1.2, 1.1, 0.85 }, 2.0)))

def helm_attic(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3 { 1.2, 1.1, 0.85 }, 2.0)
    add_child(n, dome(float3 { 5.0, 5.0, 4.8 }, bronze, float3 { 0.0, -3.6, 0.0 }))
    add_child(n, ring(4.8, 5.5, surf("bronze", float3 { 1.35, 1.25, 1.0 }, 2.0), float3 { 0.0, -3.5, 0.0 }))
    add_child(n, blob(float3 { 2.0, 0.5, 4.0 }, bronze, float3 { 4.4, -2.6, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 2.0, 2.8, 0.6 }, bronze, float3 { 2.0, -6.0, 4.4 * side }, float3 { 0.0, 0.0, 10.0 }))
    add_child(n, blob(float3 { 2.8, 3.0, 4.4 }, bronze, float3 { -2.8, -5.8, 0.0 }))
    add_child(n, rod(float3 { 0.0, 1.0, 0.0 }, float3 { -0.4, 4.2, 0.0 }, 0.55, 0.55, bronze))
    crest(n, c.team, float3 { -1.4, 4.6, 0.0 }, 14.0, 8.0)
    lift_kids(n, 0.8)
    return spec_of(n)

def weapon_sword_flared_sabre(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(curved(17.0, 3.2, [1.1, 1.1, 1.2, 1.9, 2.0, 0.0], 0.3), 0.6, bright_iron(), float3_0, ang))
    let across = float3 { -d.y, d.x, 0.0 }
    let brass = surf("bronze", float3 { 1.2, 1.1, 0.8 }, 2.0)
    add_child(n, rod(-across * 2.8, across * 2.8, 0.6, 0.6, brass))
    grip(n, d, surf("leather", float3_1, 2.0), brass)
    return spec_of(n)

def helm_steppe_spike(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3 { 0.85, 0.85, 0.9 }, 3.0)
    add_child(n, cone(0.7, 5.1, 6.0, iron, float3 { 0.0, 0.1, 0.0 }))
    add_child(n, ring(4.9, 5.6, surf("bronze", float3_1, 2.0), float3 { 0.0, -2.8, 0.0 }))
    add_child(n, rod(float3 { 0.0, 2.9, 0.0 }, float3 { 0.0, 6.0, 0.0 }, 0.7, 0.25, surf("bronze", float3 { 1.2, 1.1, 0.85 }, 2.0)))
    add_child(n, blob(float3 { 1.1, 2.8, 1.1 }, plain(c.team), float3 { -2.0, 3.0, 0.0 }, float3 { 0.0, 0.0, 60.0 }))
    let mail = surf("mail", float3 { 0.7, 0.7, 0.75 }, 2.0)
    for([MPI * 0.55, MPI * 0.78, MPI * 1.22, MPI * 1.45]) a:
        let deg = rad(a)
        add_child(n, blob(float3 { 1.9, 2.6, 0.45 }, mail, float3 { cos(deg) * 5.0 - 0.6, -4.4, sin(deg) * 5.0 }, float3 { 0.0, -deg, 0.0 }))
    return spec_of(n)

def weapon_mace_river_stone(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let deg = atan2(float2 { d.x, d.y })
    add_child(n, rod(-d * 2.5, d * 12.5, 0.7, 0.9, surf("wood_grain", float3 { 1.15, 1.05, 0.9 }, 3.0)))
    add_child(n, blob(float3 { 3.0, 2.3, 2.4 }, surf("rock", float3 { 0.95, 0.95, 0.92 }, 2.5), d * 13.0 + float3 { 0.6, 0.0, 0.0 }, float3 { 0.0, 0.0, deg }))
    let cord = surf("cloth", html("#8a7a4a"), 2.0)
    for(2) k:
        add_child(n, ring(2.1, 2.5, cord, d * (11.6 + float(k) * 2.6) + float3 { 0.4, 0.0, 0.0 }, float3 { 90.0, 0.0, deg - 90.0 }, float3 { 1.0, 1.0, 1.1 }))
    add_child(n, ring(0.8, 1.2, cord, -d * 0.4, float3 { 0.0, 0.0, deg - 90.0 }))
    return spec_of(n)

def weapon_sword_chitin(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(curved(16.5, 0.0, [1.0, 1.3, 1.3, 1.0, 0.0]), 0.8, surf("wood_grain", float3 { 0.6, 0.45, 0.32 }, 3.0), float3_0, ang))
    let shell = surf("chitin", html("#4fd0a0"), 2.0)
    let across = float3 { -d.y, d.x, 0.0 }
    for(6) k:
        let t = 2.0 + float(k) * 2.4
        let w = if k < 4: 1.3 else: 1.3 - float(k - 3) * 0.4
        for([1.0, -1.0]) side:
            add_child(n, blade(u4_pts([-1.4, 0.0, 0.0, -0.8, 1.6, 0.0, 0.0, 0.8]), 0.5, shell,
                d * t + across * side * w, ang + rad(0.25) * side))
    add_child(n, blade(u4_pts([0.0, -1.0, 3.0, 0.0, 0.0, 1.0]), 0.6, shell, d * 16.0, ang))
    add_child(n, blob(float3 { 1.2, 3.2, 1.6 }, shell, float3_0, float3 { 0.0, 0.0, ang }))
    grip(n, d, surf("leather", float3_1, 2.0), shell)
    return spec_of(n)

def weapon_sword_hook(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    let steel = bright_iron(2.5)
    let raw = u4_pts([0.0, -0.9, 11.0, -1.1, 14.0, -1.6, 16.4, -0.6, 17.4, 1.6, 16.4, 3.8,
        14.2, 4.8, 13.4, 3.8, 15.0, 2.6, 15.2, 1.0, 13.6, 0.4, 11.0, 0.9, 0.0, 0.9])
    let pts = map(raw.length) i: float2 { raw[raw.length - 1 - i].x, -raw[raw.length - 1 - i].y }
    add_child(n, blade(pts, 0.6, steel, float3_0, ang))
    let silk = surf("cloth", html("#f2f0ea"), 2.0)
    for(4) k:
        add_child(n, ring(0.55, 0.95, silk, -d * (0.4 + float(k) * 0.7), float3 { 0.0, 0.0, ang - 90.0 }))
    add_child(n, blob(float3 { 1.0, 1.0, 1.0 }, steel, -d * 3.4))
    let across = float3 { -d.y, d.x, 0.0 }
    add_child(n, rod(-across * 2.2, across * 2.2, 0.5, 0.5, steel))
    return spec_of(n)

def weapon_sword_dao(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(curved(16.5, 1.8, [1.1, 1.3, 1.6, 2.0, 1.6, 0.0], 0.5), 0.6, bright_iron(), float3_0, ang))
    let bronze = surf("bronze", float3 { 1.2, 1.1, 0.85 }, 2.0)
    add_child(n, cone(1.8, 1.8, 0.5, bronze, float3_0, float3 { 0.0, 0.0, ang - 90.0 }))
    add_child(n, rod(float3_0, -d * 3.4, 0.6, 0.6, surf("cloth", html("#3a2a20"), 2.0), false))
    add_child(n, ring(0.7, 1.2, bronze, -d * 4.4, float3 { 90.0, 0.0, ang - 90.0 }))
    let red = surf("cloth", col(c, "crimson"), 2.0)
    add_child(n, rod(-d * 4.6, -d * 4.6 + float3 { -1.4, -3.2, 0.4 }, 0.4, 1.0, red))
    return spec_of(n)

def weapon_bow_short(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("wood_grain", html("#e8c48a"), 4.0)
    let g = float3 { 5.7, 0.0, 0.0 }
    let pts = [float3 { 3.8, -13.6, 0.0 }, float3 { 2.0, -12.0, 0.0 }, float3 { 5.5, -6.0, 0.0 }, float3 { 6.6, 0.0, 0.0 }, float3 { 5.5, 6.0, 0.0 }, float3 { 2.0, 12.0, 0.0 }, float3 { 3.8, 13.6, 0.0 }]
    var k = 1
    while k < pts.length:
        let r = if k == 3 or k == 4: 1.15 else: 0.85
        add_child(n, rod(pts[k - 1] - g, pts[k] - g, r, r, wood))
        k++
    let nock = float3 { -3.5, 0.0, 0.0 } - g
    add_child(n, rod(float3 { 2.0, -12.0, 0.0 } - g, nock, 0.25, 0.25, plain(html("#f8f2e0")), false))
    add_child(n, rod(nock, float3 { 2.0, 12.0, 0.0 } - g, 0.25, 0.25, plain(html("#f8f2e0")), false))
    add_child(n, rod(nock, float3 { 9.0, 0.0, 0.0 } - g, 0.3, 0.3, surf("wood_grain", float3_1, 2.0), false))
    add_child(n, cone(1.05, 1.05, 2.4, surf("leather", float3_1, 2.0), float3_0, float3 { 0.0, 0.0, 8.0 }))
    return spec_of(n)

def weapon_musket(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, slab(u4_pts([-5.0, -2.2, -4.0, 0.6, 14.0, 3.6, 14.0, 2.0, -1.0, -0.6, -2.0, -2.6]), 1.6, surf("wood_grain", float3_1, 5.0)))
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, rod(float3 { 5.0, 2.4, 0.0 }, float3 { 19.5, 5.3, 0.0 }, 0.75, 0.7, iron, false))
    add_child(n, ring(0.7, 1.0, iron, float3 { 18.6, 5.1, 0.0 }, float3 { 0.0, 0.0, -79.0 }))
    add_child(n, blob(float3 { 1.2, 0.8, 0.9 }, iron, float3 { 3.5, 2.0, 0.6 }))
    return spec_of(n)

def tool_sack(c:Colours) -> Spec:
    let n = mnode()
    let sack = surf("cloth", u4_lerp(col(c, "cloth2"), html("#c8b48a"), 0.55), 3.0)
    add_child(n, blob(float3 { 3.8, 4.6, 3.4 }, sack, float3 { 0.0, -2.6, 0.0 }))
    add_child(n, cone(0.9, 2.0, 1.8, sack, float3 { 0.0, 2.0, 0.0 }))
    add_child(n, ring(0.8, 1.3, surf("leather", float3_1, 2.0), float3 { 0.0, 2.2, 0.0 }))
    add_child(n, blob(float3 { 1.4, 0.9, 1.3 }, sack, float3 { 0.0, 3.3, 0.0 }))
    return spec_of(n)

def tool_charge(c:Colours) -> Spec: return scaled(tool_sack(c), 0.5)

// ------------------------------------------------------------------ shields

def shield_round(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.5, 1.5 }, SHIELD_FACE)
    let iron = surf("iron", float3_1, 3.0)
    add_child(h, disc(6.0, 1.0, surf("wood_grain", float3_1, 4.0), 0.0))
    add_child(h, disc(3.4, 0.3, plain(c.team), 0.55))
    add_child(h, ring(5.6, 6.5, iron, float3_0, float3 { 90.0, 0.0, 0.0 }))
    add_child(h, blob(float3 { 1.6, 1.6, 1.1 }, iron, float3 { 0.0, 0.0, 0.7 }))
    return spec_of(n)

def shield_kite(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.5, 1.5 }, SHIELD_FACE)
    let outline = u4_pts([-1.0, 8.0, 5.0, 6.0, 4.0, -4.0, 0.0, -9.0, -4.0, -4.0, -4.0, 6.0])
    let body = slab(outline, 0.8, plain(c.team))
    body.pos = float3 { -0.5, 0.0, 0.0 }
    add_child(h, body)
    let iron = surf("iron", float3_1, 3.0)
    for(outline.length) k:
        let a = outline[k]
        let b = outline[(k + 1) % outline.length]
        add_child(h, rod(float3 { a.x - 0.5, a.y, 0.3 }, float3 { b.x - 0.5, b.y, 0.3 }, 0.35, 0.35, iron))
    add_child(h, rod(float3 { 0.0, 7.0, 0.5 }, float3 { -0.5, -7.5, 0.5 }, 0.35, 0.35, iron))
    add_child(h, rod(float3 { -3.5, 3.0, 0.5 }, float3 { 4.0, 3.0, 0.5 }, 0.35, 0.35, iron))
    return spec_of(n)

def shield_scutum(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.0, 1.5 }, SHIELD_FACE)
    let bronze = surf("bronze", float3_1, 3.0)
    let team = plain(c.team)
    let R = 6.0
    for(5) i:
        let a = float(i - 2) * 17.0
        add_child(h, box(float3 { 1.85, 17.0, 0.6 }, team, float3 { sin(a) * R, 0.0, cos(a) * R - R }, float3 { 0.0, a, 0.0 }))
    for([8.5, -8.5]) y:
        for(5) i:
            let a = float(i - 2) * 17.0
            let lo = a - rad(0.15)
            let hi = a + rad(0.15)
            add_child(h, rod(float3 { sin(lo) * R, y, cos(lo) * R - R + 0.2 }, float3 { sin(hi) * R, y, cos(hi) * R - R + 0.2 }, 0.35, 0.35, bronze))
    add_child(h, blob(float3 { 1.7, 1.7, 1.1 }, bronze, float3 { 0.0, 0.0, 0.5 }))
    add_child(h, rod(float3 { 0.0, 7.8, 0.4 }, float3 { 0.0, 1.7, 0.4 }, 0.3, 0.3, bronze))
    add_child(h, rod(float3 { 0.0, -1.7, 0.4 }, float3 { 0.0, -7.8, 0.4 }, 0.3, 0.3, bronze))
    return spec_of(n)

def shield_hoplon(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.5, 1.5 }, SHIELD_FACE)
    let bronze = surf("bronze", float3_1, 3.0)
    add_child(h, disc(6.8, 1.4, bronze, 0.0))
    add_child(h, disc(4.6, 0.3, plain(c.team), 0.75))
    add_child(h, ring(6.3, 7.5, bronze, float3 { 0.0, 0.0, 0.3 }, float3 { 90.0, 0.0, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ helmets

def helm_bronze(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3_1, 3.0)
    add_child(n, dome(float3 { 5.0, 5.0, 4.8 }, bronze, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.7, 5.5, bronze, float3 { 0.0, -3.6, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.5, 2.4, 0.5 }, bronze, float3 { 2.0, -5.4, 4.3 * side }))
    add_child(n, rod(float3 { 0.0, 0.8, 0.0 }, float3 { 0.0, 2.0, 0.0 }, 0.5, 0.5, bronze))
    crest(n, c.team, float3 { -0.3, 1.6, 0.0 }, 8.0, 4.0)
    lift_kids(n, 1.05)
    return spec_of(n)

def helm_iron(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, cone(0.5, 5.2, 6.2, iron, float3 { 0.0, -0.9, 0.0 }))
    add_child(n, blob(float3 { 0.8, 0.6, 0.8 }, iron, float3 { 0.0, 2.3, 0.0 }))
    add_child(n, ring(5.0, 5.7, iron, float3 { 0.0, -3.9, 0.0 }))
    add_child(n, rod(float3 { 5.4, -3.6, 0.0 }, float3 { 5.6, -7.6, 0.0 }, 0.55, 0.45, iron))
    return spec_of(n)

def helm_horned(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    let bone = surf("bone", float3_1, 3.0)
    add_child(n, dome(float3 { 5.0, 5.2, 4.8 }, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.7, 5.5, iron, float3 { 0.0, -3.6, 0.0 }))
    add_child(n, rod(float3 { -5.0, -1.0, 0.0 }, float3 { 5.0, -1.0, 0.0 }, 0.5, 0.5, iron))
    for([1.0, -1.0]) side:
        let pts = [float3 { 0.5, -1.5, 4.4 * side }, float3 { 0.5, 0.5, 7.2 * side }, float3 { 0.2, 3.8, 8.4 * side }, float3 { -0.4, 6.4, 8.0 * side }]
        let r = [1.4, 1.1, 0.7, 0.3]
        var k = 1
        while k < pts.length:
            add_child(n, rod(pts[k - 1], pts[k], r[k - 1], r[k], bone))
            k++
    lift_kids(n, 1.05)
    return spec_of(n)

def helm_galea(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    let bronze = surf("bronze", float3_1, 2.0)
    add_child(n, dome(float3 { 5.0, 5.0, 4.8 }, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.8, 5.4, bronze, float3 { 0.3, -2.8, 0.0 }))
    add_child(n, blob(float3 { 3.0, 0.6, 5.0 }, iron, float3 { -4.0, -4.2, 0.0 }, float3 { 0.0, 0.0, -25.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.6, 2.6, 0.5 }, iron, float3 { 2.0, -5.6, 4.3 * side }))
    crest(n, col(c, "crimson"), float3 { -0.2, 1.0, 0.0 }, 9.0, 4.5)
    return spec_of(n)

def helm_corinthian(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3 { 0.82, 0.74, 0.62 }, 3.0)
    let bright = surf("bronze", float3_1, 2.0)
    add_child(n, dome(float3 { 5.0, 5.0, 4.8 }, bronze, float3 { 0.0, -3.6, 0.0 }))
    add_child(n, ring(4.8, 5.4, bright, float3 { 0.0, -3.5, 0.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 2.4, 3.6, 0.7 }, bronze, float3 { 2.4, -6.6, 4.2 * side }, float3 { 0.0, 0.0, 8.0 }))
    add_child(n, rod(float3 { 4.9, -3.4, 0.0 }, float3 { 5.2, -6.8, 0.0 }, 0.7, 0.55, bronze))
    add_child(n, blob(float3 { 3.0, 3.6, 4.4 }, bronze, float3 { -2.6, -6.2, 0.0 }))
    add_child(n, rod(float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, 2.0, 0.0 }, 0.5, 0.5, bright))
    crest(n, c.team, float3 { -0.4, 1.6, 0.0 }, 9.0, 4.5)
    return spec_of(n)

// ------------------------------------------------------------------ armour

def armour_leather(c:Colours) -> Spec:
    let n = mnode()
    let leather = surf("leather", float3_1, 5.0)
    add_child(n, blob(float3 { 8.8, 8.2, 10.4 }, leather, float3 { 1.5, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, ring(0.97, 1.1, surf("leather", html("#5a3a20"), 3.0), float3 { 1.4, -5.0, 0.0 }, float3 { 0.0, 0.0, -10.0 }, float3 { 6.6, 1.0, 7.8 }))
    return spec_of(n)

def armour_bronze(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3_1, 4.0)
    add_child(n, blob(float3 { 8.8, 8.2, 10.4 }, bronze, float3 { 1.5, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 3.2, 2.6, 3.8 }, bronze, float3 { 7.6, 2.6, 3.6 * side }))
    add_child(n, blob(float3 { 2.4, 3.6, 2.4 }, bronze, float3 { 8.4, -2.8, 0.0 }))
    let flaps = surf("leather", float3_1, 3.0)
    for(7) k:
        let a = -75.0 + float(k) * 25.0
        add_child(n, box(float3 { 0.6, 4.0, 2.6 }, flaps, float3 { cos(a) * 8.2 + 1.0, -8.5, sin(a) * 9.6 }, float3 { 0.0, -a, 0.0 }))
    return spec_of(n)

def armour_lorica(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 4.0)
    let dark = surf("iron", float3 { 0.62, 0.64, 0.68 }, 3.0)
    add_child(n, blob(float3 { 8.8, 8.2, 10.4 }, iron, float3 { 1.5, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    for([-5.0, -2.0, 1.0, 4.0]) y:
        let k = sqrt(1.0 - pow(y / 8.6, 2.0))
        add_child(n, ring(8.3 * k, 9.4 * k, dark, float3 { 1.5, y + 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }, float3 { 1.0, 1.0, 10.4 / 8.8 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 4.2, 2.0, 4.0 }, iron, float3 { 0.5, 7.0, 6.6 * side }, float3 { 20.0 * side, 0.0, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ backs

def cape_cloth(c:Colours) -> Spec:
    let n = mnode()
    let cloth = surf("cloth", c.team, 4.0)
    for([1.0, -1.0]) side:
        let panel = slab(u4_pts([2.0, 1.0, 3.0, -1.0, 0.5, -14.0, -2.5, -14.5, -4.0, -10.5, -1.5, 0.5]), 0.6, cloth)
        panel.pos = float3 { 0.0, 0.0, 3.0 * side }
        panel.rot = float3 { 0.0, -10.0 * side, 0.0 }
        add_child(n, panel)
    add_child(n, blob(float3 { 1.0, 1.0, 0.6 }, surf("bronze", float3_1, 2.0), float3 { 1.5, 0.0, 1.2 }))
    return spec_of(n)

def banner_team(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { 0.0, -4.0, 0.0 }, float3 { 0.0, 22.0, 0.0 }, 0.5, 0.45, surf("wood_grain", float3_1, 5.0), false))
    add_child(n, blob(float3 { 0.9, 1.2, 0.9 }, surf("bronze", float3_1, 2.0), float3 { 0.0, 22.8, 0.0 }))
    add_child(n, rod(float3 { -0.3, 21.2, 0.0 }, float3 { 9.6, 21.2, 0.0 }, 0.3, 0.3, surf("wood_grain", float3_1, 3.0)))
    add_child(n, slab(u4_pts([0.3, 21.0, 9.3, 21.0, 9.3, 13.2, 7.0, 15.4, 4.8, 13.2, 0.3, 14.4]), 0.4, surf("cloth", c.team, 4.0)))
    add_child(n, blob(float3 { 1.6, 1.6, 0.5 }, plain(html("#e8e4d8")), float3 { 4.8, 17.6, 0.3 }))
    return spec_of(n)

def quiver(c:Colours) -> Spec:
    let n = mnode()
    let leather = surf("leather", float3_1, 3.0)
    add_child(n, cone(2.0, 1.6, 12.0, leather, float3 { 0.0, 2.0, 0.0 }))
    add_child(n, ring(1.8, 2.4, surf("leather", html("#5a3a20"), 2.0), float3 { 0.0, 7.8, 0.0 }))
    add_child(n, ring(1.6, 2.1, surf("leather", html("#5a3a20"), 2.0), float3 { 0.0, -2.5, 0.0 }))
    let fletch = plain(html("#e8e2d0"))
    for(4) k:
        let a = rad(float(k) * 1.7)
        let off = float3 { cos(a) * 0.8, 0.0, sin(a) * 0.8 }
        let top = float3 { 0.0, 11.5 + float(k % 2) * 0.8, 0.0 } + off
        add_child(n, rod(float3 { 0.0, 7.0, 0.0 } + off, top, 0.2, 0.2, surf("wood_grain", float3_1, 2.0), false))
        add_child(n, blob(float3 { 0.3, 1.4, 0.7 }, fletch, top - float3 { 0.0, 0.9, 0.0 }))
    return spec_of(n)

def wings(texture:string, tint:float3) -> Spec:
    let n = mnode()
    n.scl = float3_1 * 0.8
    let x = normalize(float3 { 1.0, -0.3, -0.3 })
    let y = normalize(float3 { 0.3, 1.0, 0.0 })
    let root = float3 { 0.5, 3.0, -4.0 }
    add_child(n, decal(texture, 24.0, 24.0, root - x * 9.0 + y * 8.2, cross(x, y), true, y, darkened(tint, 0.3)))
    add_child(n, decal(texture, 26.0, 26.0, float3 { -10.7, 8.8, 2.0 }, float3 { -0.15, 0.15, 1.0 }, true, float3 { 0.0, 1.0, 0.0 }, tint))
    return spec_of(n)

def wings_feather(c:Colours) -> Spec: return wings("wing_feather", float3_1)
def wings_bat(c:Colours) -> Spec: return wings("wing_bat", float3_1)

// ------------------------------------------------------------------ job tools and carried loads

def tool_hammer(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 2.5, 8.5, 0.0 }, 0.7, 0.65, surf("wood_grain", float3_1, 6.0)))
    add_child(n, u4_box_rad(float3 { 4.6, 2.2, 2.2 }, surf("iron", float3_1, 3.0), float3 { 2.8, 9.2, 0.0 }, float3 { 0.0, 0.0, -0.28 }))
    return spec_of(n)

def tool_pick(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 2.5, 9.5, 0.0 }, 0.7, 0.65, surf("wood_grain", float3_1, 6.0)))
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, rod(float3 { 2.6, 9.6, 0.0 }, float3 { -2.2, 7.4, 0.0 }, 0.75, 0.3, iron))
    add_child(n, rod(float3 { 2.6, 9.6, 0.0 }, float3 { 7.4, 8.4, 0.0 }, 0.75, 0.35, iron))
    return spec_of(n)

def load_reeds(c:Colours) -> Spec:
    let n = mnode()
    let reed = surf("reed_stalk", float3 { 1.0, 0.92, 0.7 }, 5.0)
    let front = float3 { 3.0, 2.0, 0.0 }
    let back = float3 { -9.0, -10.0, 0.0 }
    let axis = normalize(back - front)
    let side = normalize(cross(axis, float3 { 0.0, 0.0, 1.0 }))
    for(13) k:
        let a = float(k) * 360.0 / 13.0
        let r = 1.0 + 1.1 * float(k % 3) / 2.0
        let off = side * cos(a) * r + float3 { 0.0, 0.0, 1.0 } * sin(a) * r
        let fan = off * 0.35
        add_child(n, rod(front + off * 0.8 - axis * 0.8, back + off + fan, 0.45, 0.35, reed, false))
    let tie = surf("leather", float3_1, 2.0)
    for([0.22, 0.6]) f:
        let at = front + (back - front) * f
        add_child(n, ring(1.9, 2.7, tie, at, float3 { 0.0, 0.0, atan2(float2 { axis.x, axis.y }) + 90.0 }))
    for(5) k:
        let a = float(k) * 360.0 / 5.0
        let off = side * cos(a) * 2.0 + float3 { 0.0, 0.0, 1.0 } * sin(a) * 2.0
        add_child(n, decal("reed_leaf", 1.2, 4.5, back + axis * 1.5 + off, float3 { 0.2, 0.3, 1.0 }, true, axis + normalize(off) * 0.5, float3_1))
    return spec_of(n)

def load_stone(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, u4_box_rad(float3 { 6.0, 4.2, 4.6 }, surf("rock", float3 { 0.85, 0.82, 0.76 }, 3.0), float3 { -2.4, -2.0, 0.0 }, float3 { 0.15, 0.4, 0.25 }))
    return spec_of(n)

def load_gold(c:Colours) -> Spec:
    let n = mnode()
    let sack = surf("cloth", html("#c8b48a"), 3.0)
    add_child(n, blob(float3 { 3.0, 3.6, 2.8 }, sack, float3 { -2.6, -3.6, 0.0 }, float3 { 0.0, 0.0, -30.0 }))
    add_child(n, rod(float3 { 0.2, 0.4, 0.0 }, float3 { -1.2, -1.0, 0.0 }, 0.8, 1.1, sack))
    let gold = plain(html("#f2c440"))
    for([float3 { -1.0, -1.6, 1.4 }, float3 { -2.2, -1.2, 1.2 }, float3 { -3.4, -2.2, 1.6 }, float3 { -1.8, -2.6, 2.2 }]) p:
        add_child(n, blob(float3 { 0.75, 0.6, 0.7 }, gold, p))
    return spec_of(n)

def load_meat(c:Colours) -> Spec:
    let n = mnode()
    let meat = plain(html("#a8443a"))
    add_child(n, blob(float3 { 2.4, 3.8, 2.6 }, meat, float3 { -2.2, -4.0, 0.0 }, float3 { 0.0, 0.0, -25.0 }))
    add_child(n, blob(float3 { 1.4, 2.6, 2.0 }, plain(html("#e8c8b0")), float3 { -3.2, -4.6, 0.6 }, float3 { 0.0, 0.0, -25.0 }))
    let bone = plain(html("#f0e8d8"))
    add_child(n, rod(float3 { -0.8, -0.8, 0.0 }, float3 { 0.6, 1.2, 0.0 }, 0.55, 0.5, bone))
    add_child(n, blob(float3 { 0.9, 0.8, 0.9 }, bone, float3 { 0.7, 1.4, 0.0 }))
    return spec_of(n)

def tool_broom(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("wood_grain", float3_1, 6.0)
    add_child(n, rod(float3 { -1.5, 8.0, 0.0 }, float3 { 2.0, -3.5, 0.0 }, 0.55, 0.55, wood))
    let twig = surf("reed_stalk", float3 { 0.85, 0.75, 0.5 }, 5.0)
    for(7) k:
        let z = float(k - 3) * 0.55
        add_child(n, rod(float3 { 2.0, -3.5, z * 0.4 }, float3 { 3.0 + float(k - 3) * 0.35, -7.5, z }, 0.4, 0.3, twig, false))
    add_child(n, ring(0.7, 1.2, surf("leather", float3_1, 2.0), float3 { 1.9, -3.1, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    return spec_of(n)

def tool_hoe(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, rod(float3 { -1.0, -3.5, 0.0 }, float3 { 2.5, 10.5, 0.0 }, 0.6, 0.55, surf("wood_grain", float3_1, 6.0)))
    add_child(n, u4_box_rad(float3 { 3.6, 0.4, 2.6 }, surf("iron", float3_1, 3.0), float3 { 4.0, 9.8, 0.0 }, float3 { 0.0, 0.0, -0.5 }))
    return spec_of(n)

// ------------------------------------------------------------------ first-age kit for everyone

def weapon_spear_wood(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -4.0, -8.0, 0.0 }
    let b = float3 { 6.0, 19.0, 0.0 }
    add_child(n, rod(a, b, 0.95, 0.85, surf("wood_grain", float3_1, 6.0), false))
    let d = normalize(b - a)
    add_child(n, rod(b, b + d * 4.0, 0.85, 0.1, surf("wood_grain", html("#3a2a1e"), 3.0), false))
    add_child(n, ring(0.7, 1.15, surf("leather", float3_1, 3.0), a + d * 9.0, float3 { 0.0, 0.0, atan2(float2 { d.x, d.y }) - 90.0 }))
    return spec_of(n)

def helm_cap(c:Colours) -> Spec:
    let n = mnode()
    let leather = surf("leather", float3 { 0.9, 0.82, 0.72 }, 3.0)
    add_child(n, dome(float3 { 4.9, 3.6, 4.7 }, leather, float3 { 0.0, -2.5, 0.0 }))
    add_child(n, ring(4.6, 5.1, surf("leather", float3 { 0.84, 0.76, 0.66 }, 2.0), float3 { 0.0, -2.5, 0.0 }))
    add_child(n, blob(float3 { 0.6, 0.6, 0.6 }, leather, float3 { 0.0, 1.2, 0.0 }))
    return spec_of(n)

// ------------------------------------------------------------------ the rats' junk kit, by age (RB2)

def helm_thimble(c:Colours) -> Spec:
    let n = mnode()
    let brass = surf("bronze", float3 { 1.1, 1.0, 0.75 }, 1.2)
    add_child(n, cone(1.7, 2.2, 3.0, brass, float3 { 0.6, -0.4, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    add_child(n, blob(float3 { 1.7, 0.6, 1.7 }, brass, float3 { 0.9, 1.1, 0.0 }))
    add_child(n, ring(2.1, 2.5, brass, float3 { 0.4, -1.8, 0.0 }, float3 { 0.0, 0.0, -12.0 }))
    return spec_of(n)

def helm_tin_cap(c:Colours) -> Spec:
    let n = mnode()
    let tin = surf("iron", float3 { 0.95, 0.95, 1.0 }, 2.0)
    add_child(n, dome(float3 { 4.0, 2.6, 2.5 }, tin, float3 { 0.6, -1.6, 0.0 }))
    add_child(n, ring(0.97, 1.08, plain(html("#6a6c66")), float3 { 0.6, -1.5, 0.0 }, float3_0, float3 { 4.0, 1.0, 2.5 }))
    add_child(n, blob(float3 { 0.7, 0.5, 0.7 }, tin, float3 { 0.6, 1.1, 0.0 }))
    return spec_of(n)

def helm_spoon(c:Colours) -> Spec:
    let n = mnode()
    let steel = surf("iron", float3_1, 2.0)
    add_child(n, dome(float3 { 4.4, 2.8, 2.6 }, steel, float3 { 0.8, -1.6, 0.0 }))
    add_child(n, rod(float3 { -3.2, -1.4, 0.0 }, float3 { -6.2, -5.2, 0.0 }, 0.55, 0.45, steel))
    add_child(n, rod(float3 { -1.6, 1.5, 0.0 }, float3 { 3.6, 1.5, 0.0 }, 0.35, 0.35, plain(html("#e8e0d0"))))
    add_child(n, box(float3 { 4.0, 1.6, 0.9 }, plain(col(c, "crimson")), float3 { 0.6, 2.6, 0.0 }))
    return spec_of(n)

def armour_sardine(c:Colours) -> Spec:
    let n = mnode()
    let tin = surf("iron", float3 { 0.95, 0.97, 1.0 }, 2.0)
    let label = plain(html("#c8a040"))
    let tilt = mnode()
    tilt.scl = float3_1 * 1.45
    add_child(n, tilt)
    for(4) k:
        let y = 4.0 - float(k) * 2.4
        add_child(tilt, cone(6.6 - float(k) * 0.35, 6.9 - float(k) * 0.35, 2.0, if k % 2 == 0: tin else: label, float3 { 0.6, y, 0.0 }, float3_0, 20))
    add_child(tilt, box(float3 { 1.2, 0.5, 3.2 }, plain(html("#6a6c66")), float3 { 7.0, 4.6, 0.0 }, float3 { 0.0, 0.0, -20.0 }))
    return spec_of(n)

def shield_can_scutum(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.0, 1.5 }, SHIELD_FACE)
    let tin = surf("iron", float3 { 0.95, 0.95, 1.0 }, 2.0)
    let R = 5.5
    for(5) i:
        let a = float(i - 2) * 17.0
        let mats = [tin, plain(c.team), tin]
        let tall = [6.0, 4.4, 4.2]
        let ys = [4.2, -1.0, -5.3]
        for(3) p:
            add_child(h, box(float3 { 1.75, tall[p], 0.5 }, mats[p], float3 { sin(a) * R, ys[p], cos(a) * R - R }, float3 { 0.0, a, 0.0 }))
    add_child(h, cone(1.2, 1.4, 0.6, surf("bronze", float3_1, 1.0), float3 { 0.0, 0.5, 0.4 }, float3 { 90.0, 0.0, 0.0 }, 14))
    return spec_of(n)

def armour_bottlecap(c:Colours) -> Spec:
    let spec = armour_leather(c)
    let n = spec.node
    let cap = surf("iron", float3 { 1.0, 0.92, 0.75 }, 1.0)
    let centre = float3 { 1.5, 0.5, 0.0 }
    let radii = float3 { 8.8, 8.2, 10.4 }
    for(3) row:
        for(5) k:
            let look = normalize(float3 { 1.0, 0.45 - float(row) * 0.4, float(k - 2) * 0.45 })
            let p = on_surface(centre, radii, look, 0.2)
            let d = cone(1.5, 1.7, 0.5, cap, p, float3_0, 12)
            set_basis(d, bmul(basis_looking_at(look, float3 { 0.0, 1.0, 0.0 }), axis_angle(float3 { 1.0, 0.0, 0.0 }, 90.0)))
            add_child(n, d)
    return spec

// ------------------------------------------------------------------ this file's parts by id
def build_units4(base:string, c:Colours) -> Spec?:
    switch base:
        case "weapon.pike.iron": return weapon_pike_iron(c)
        case "weapon.dory": return weapon_dory(c)
        case "weapon.pilum": return weapon_pilum(c)
        case "weapon.lance": return weapon_lance(c)
        case "weapon.club.bone": return weapon_club_bone(c)
        case "weapon.sword.bronze": return weapon_sword_bronze(c)
        case "weapon.sword.iron": return weapon_sword_iron(c)
        case "weapon.gladius": return weapon_gladius(c)
        case "weapon.sword.iron_plain": return weapon_sword_iron_plain(c)
        case "weapon.sword.xiphos": return weapon_sword_xiphos(c)
        case "helm.attic": return helm_attic(c)
        case "weapon.sword.flared_sabre": return weapon_sword_flared_sabre(c)
        case "helm.steppe_spike": return helm_steppe_spike(c)
        case "weapon.mace.river_stone": return weapon_mace_river_stone(c)
        case "weapon.sword.chitin": return weapon_sword_chitin(c)
        case "weapon.sword.hook": return weapon_sword_hook(c)
        case "weapon.sword.dao": return weapon_sword_dao(c)
        case "weapon.bow.short": return weapon_bow_short(c)
        case "weapon.musket": return weapon_musket(c)
        case "tool.sack": return tool_sack(c)
        case "tool.charge": return tool_charge(c)
        case "shield.round": return shield_round(c)
        case "shield.kite": return shield_kite(c)
        case "shield.scutum": return shield_scutum(c)
        case "shield.hoplon": return shield_hoplon(c)
        case "helm.bronze": return helm_bronze(c)
        case "helm.iron": return helm_iron(c)
        case "helm.horned": return helm_horned(c)
        case "helm.galea": return helm_galea(c)
        case "helm.corinthian": return helm_corinthian(c)
        case "armour.leather": return armour_leather(c)
        case "armour.bronze": return armour_bronze(c)
        case "armour.lorica": return armour_lorica(c)
        case "cape.cloth": return cape_cloth(c)
        case "banner.team": return banner_team(c)
        case "quiver": return quiver(c)
        case "wings.feather": return wings_feather(c)
        case "wings.bat": return wings_bat(c)
        case "tool.hammer": return tool_hammer(c)
        case "tool.pick": return tool_pick(c)
        case "load.reeds": return load_reeds(c)
        case "load.stone": return load_stone(c)
        case "load.gold": return load_gold(c)
        case "load.meat": return load_meat(c)
        case "tool.broom": return tool_broom(c)
        case "tool.hoe": return tool_hoe(c)
        case "weapon.spear.wood": return weapon_spear_wood(c)
        case "helm.cap": return helm_cap(c)
        case "helm.thimble": return helm_thimble(c)
        case "helm.tin_cap": return helm_tin_cap(c)
        case "helm.spoon": return helm_spoon(c)
        case "armour.sardine": return armour_sardine(c)
        case "shield.can_scutum": return shield_can_scutum(c)
        case "armour.bottlecap": return armour_bottlecap(c)
        default: return nil
