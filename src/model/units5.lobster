// ------------------------------------------------------------------ unit parts V (unit_models.gd 3060-3822: mods' .glb parts, the Nile, Han, Aztec and Norse kits, the healers' staffs and bags)
// Each builder is unit_models.gd's of the same name (`_helm_nile_khat` -> helm_nile_khat), line for line;
// its comments are there. Angles the GDScript keeps in radians are turned to degrees where they're used.

// ---- a mod's .glb parts (unit_models.gd mod_materials; Mods.glb_parts)

let MOD_TEX_DIR = "../assets/art/textures"
var mod_tex_names:[string] = []
var mod_tex_scanned = false

def mod_has_texture(name:string) -> bool:
    if not mod_tex_scanned:
        mod_tex_scanned = true
        let names, _sizes = scan_folder(MOD_TEX_DIR, true)
        if names: mod_tex_names = names
    for(mod_tex_names) f:
        if f == name + ".svg": return true
    return false

def mod_materials(path:string, c:Colours) -> dictionary<string, MMat>:
    let out = dictionary<string, MMat>(11)
    let doc = glb_doc(path)
    for(glist(doc.j, "materials")) m:
        let n = gstr(m, "name", "")
        if n == "team" or n == "skin" or n == "skin2" or n == "cloth" or n == "cloth2":
            out.set(n, if starts_with(n, "cloth"): surf("cloth", col(c, n), 3.0) else: plain(col(c, n)))
        elif starts_with(n, "glow_"):
            out.set(n, glow(html(n.substring(5, n.length - 5))))
        elif mod_has_texture(n):
            out.set(n, surf(n, float3_1, 3.0))
    return out

// A mod's part modelled as a .glb (its parts.json entry has "glb": a path in the mod's folder): the last mod
// in load order that has it. The mod's folder is its data folder's parent (a manifest's "data" one folder deep).
def mod_glb_path(base:string) -> string:
    var k = lib_mod_data.length - 1
    while k >= 0:
        for(glist(lib_mod_data[k], "parts.json")) p:
            if gstr(p, "id", "") == base and has(p, "glb"):
                let d = lib_mod_dirs[k]
                var cut = d.length - 1
                while cut > 0 and d[cut] != '/': cut--
                return d.substring(0, cut) + "/" + gstr(p, "glb", "")
        k--
    return ""

def mod_part(base:string, c:Colours) -> Spec?:
    let path = mod_glb_path(base)
    if path == "": return nil
    return spec_of(glb_file(path, mod_materials(path, c)))

// ---- the Nile, Han and Aztec kits

let LINEN = html("#ece4d0")

def helm_nile_khat(c:Colours) -> Spec:
    let n = mnode()
    let linen = surf("cloth", LINEN, 3.0)
    add_child(n, dome(float3 { 5.1, 3.6, 5.0 }, linen, float3 { -0.2, -3.0, 0.0 }))
    add_child(n, blob(float3 { 2.2, 2.6, 2.4 }, linen, float3 { -4.6, -3.6, 0.0 }, float3 { 0.0, 0.0, 25.0 }))
    add_child(n, ring(4.9, 5.3, surf("cloth", html("#c8b890"), 2.0), float3 { 0.1, -3.0, 0.0 }))
    lift_kids(n, 0.20)
    return spec_of(n)

def helm_nile_headcloth(c:Colours) -> Spec:
    let n = mnode()
    let linen = surf("cloth", LINEN, 3.0)
    let team = plain(col(c, "team"))
    add_child(n, dome(float3 { 5.3, 3.8, 5.2 }, linen, float3 { -0.2, -3.0, 0.0 }))
    for(4) k:
        let y = 0.4 + float(k) * 0.85
        let r = 5.25 * sqrt(1.0 - pow(y / 3.8, 2.0))
        add_child(n, ring(r - 0.3, r + 0.15, team, float3 { -0.2, -3.0 + y, 0.0 }, float3_0, float3 { 1.0, 1.0, 0.98 }))
    for([ 1.0, -1.0 ]) side:
        add_child(n, blob(float3 { 1.6, 4.6, 1.1 }, linen, float3 { 0.6, -6.6, 4.6 * side }, float3 { 15.0 * side, 0.0, 0.0 }))
        add_child(n, blob(float3 { 1.65, 0.6, 1.15 }, team, float3 { 0.6, -7.6, 4.7 * side }, float3 { 15.0 * side, 0.0, 0.0 }))
    add_child(n, blob(float3 { 2.0, 4.0, 3.6 }, linen, float3 { -3.9, -5.2, 0.0 }))
    return spec_of(n)

def helm_nile_bronze(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3 { 0.95, 0.88, 0.66 }, 2.0)
    add_child(n, dome(float3 { 5.2, 4.4, 5.1 }, bronze, float3 { -0.2, -3.0, 0.0 }))
    add_child(n, rod(float3 { -4.2, -1.0, 0.0 }, float3 { 3.6, 1.0, 0.0 }, 0.6, 0.4, bronze))
    for([ 1.0, -1.0 ]) side:
        add_child(n, blob(float3 { 1.8, 2.6, 0.5 }, bronze, float3 { 1.6, -4.6, 4.6 * side }))
    add_child(n, blob(float3 { 2.0, 2.4, 3.6 }, surf("cloth", LINEN, 3.0), float3 { -4.2, -4.6, 0.0 }))
    add_child(n, ring(5.0, 5.5, plain(col(c, "team")), float3 { -0.2, -3.0, 0.0 }))
    lift_kids(n, 0.20)
    return spec_of(n)

def weapon_khopesh(c:Colours) -> Spec:
    let bronze = surf("bronze", float3 { 1.15, 1.05, 0.8 }, 3.0)
    let pts = [ float2 { 0.0, -0.8 }, float2 { 5.5, -0.8 }, float2 { 8.5, -2.8 }, float2 { 12.5, -3.0 }, float2 { 15.0, -0.8 },
                float2 { 15.2, 2.2 }, float2 { 13.6, 3.6 }, float2 { 13.0, 1.4 }, float2 { 11.6, -0.4 }, float2 { 9.0, -0.2 }, float2 { 5.5, 0.9 }, float2 { 0.0, 0.9 } ]
    return spec_of(sword(pts, float3 { 3.0, 14.0, 0.0 }, bronze, bronze))

def shield_cowhide(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.0, 1.5 }, SHIELD_FACE)
    let outline = [ float2 { -4.0, -8.0 }, float2 { 4.0, -8.0 }, float2 { 4.0, 4.0 } ]
    for(9) k:
        let a = 180.0 * float(k) / 8.0
        outline.push(float2 { cos(a) * 4.0, 4.0 + sin(a) * 4.2 })
    outline.push(float2 { -4.0, 4.0 })
    add_child(h, slab(outline, 0.9, plain(html("#e8cc98"))))
    let spot = plain(html("#9a5a32"))
    for([ float2 { -1.4, 3.0 }, float2 { 1.6, -3.4 } ]) p:
        add_child(h, blob(float3 { 2.2, 2.6, 0.3 }, spot, float3 { p.x, p.y, 0.45 }))
    for(outline.length) k:
        let a = outline[k]
        let b = outline[(k + 1) % outline.length]
        add_child(h, rod(float3 { a.x, a.y, 0.3 }, float3 { b.x, b.y, 0.3 }, 0.4, 0.4, plain(col(c, "team"))))
    return spec_of(n)

def helm_han_topknot(c:Colours) -> Spec:
    let n = mnode()
    let hair = surf("mane", html("#3a2e26"), 3.0)
    add_child(n, dome(float3 { 4.9, 2.8, 4.8 }, hair, float3 { -0.3, -2.6, 0.0 }))
    add_child(n, blob(float3 { 1.7, 1.9, 1.7 }, hair, float3 { -0.8, 1.0, 0.0 }))
    add_child(n, ring(1.3, 1.9, plain(col(c, "team")), float3 { -0.8, 0.0, 0.0 }))
    return spec_of(n)

def helm_han_cap(c:Colours) -> Spec:
    let n = mnode()
    let black = plain(html("#16141a"))
    add_child(n, dome(float3 { 5.1, 3.4, 5.0 }, black, float3 { -0.2, -2.8, 0.0 }))
    add_child(n, blob(float3 { 2.6, 3.0, 2.6 }, black, float3 { -1.2, 1.4, 0.0 }))
    for([ 1.0, -1.0 ]) side:
        add_child(n, rod(float3 { -3.6, -0.4, 1.2 * side }, float3 { -4.6, 0.2, 7.0 * side }, 0.45, 0.35, black))
    add_child(n, ring(4.8, 5.2, plain(col(c, "team")), float3 { -0.2, -2.8, 0.0 }))
    return spec_of(n)

def helm_han_lamellar(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3 { 0.62, 0.62, 0.66 }, 2.0)
    add_child(n, cone(1.2, 5.2, 4.6, iron, float3 { -0.2, -0.8, 0.0 }))
    for(12) k:
        let a = 360.0 * float(k) / 12.0
        add_child(n, rod(float3 { cos(a) * 5.25 - 0.2, -3.0, sin(a) * 5.25 }, float3 { cos(a) * 1.4 - 0.2, 1.4, sin(a) * 1.4 }, 0.22, 0.15, plain(html("#3a3a40"))))
    for(5) k:
        let a = 180.0 * 0.55 + 180.0 * 0.9 * float(k) / 4.0
        add_child(n, blob(float3 { 1.6, 2.4, 0.4 }, iron, float3 { cos(a) * 4.7 - 0.4, -4.8, sin(a) * 4.7 }, float3 { 0.0, -a, 0.0 }))
    add_child(n, rod(float3 { -0.2, 1.4, 0.0 }, float3 { -0.2, 3.0, 0.0 }, 0.3, 0.3, iron))
    add_child(n, blob(float3 { 1.4, 2.0, 1.4 }, plain(html("#c8302a")), float3 { -0.6, 3.6, 0.0 }))
    lift_kids(n, 0.25)
    return spec_of(n)

def weapon_ji(c:Colours) -> Spec:
    let n = weapon_spear_wood(c).node
    let a = float3 { -4.0, -8.0, 0.0 }
    let b = float3 { 6.0, 19.0, 0.0 }
    let d = normalize(b - a)
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, rod(b, b + d * 4.6, 0.9, 0.1, iron, false))
    add_child(n, blade([ float2 { 0.0, -0.6 }, float2 { 3.8, -1.4 }, float2 { 5.0, 0.6 }, float2 { 3.6, 0.4 }, float2 { 0.0, 0.6 } ], 0.5, iron,
                       b - d * 1.2, atan2(float2 { d.x, d.y }) + 90.0))
    add_child(n, blob(float3 { 0.9, 1.2, 0.9 }, plain(col(c, "team")), b - d * 2.6))
    return spec_of(n)

def shield_lacquer(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.0, 1.5 }, SHIELD_FACE)
    let outline = [ float2 { -3.8, -7.5 }, float2 { 3.8, -7.5 }, float2 { 3.8, 5.5 }, float2 { 0.0, 8.0 }, float2 { -3.8, 5.5 } ]
    add_child(h, slab(outline, 0.9, plain(html("#c8402a"))))
    for(outline.length) k:
        let a = outline[k]
        let b = outline[(k + 1) % outline.length]
        add_child(h, rod(float3 { a.x, a.y, 0.35 }, float3 { b.x, b.y, 0.35 }, 0.45, 0.45, plain(html("#1a1612"))))
    add_child(h, blob(float3 { 1.6, 1.6, 0.5 }, plain(col(c, "team")), float3 { 0.0, 0.5, 0.5 }))
    return spec_of(n)

def helm_aztec_band(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, dome(float3 { 4.9, 2.8, 4.8 }, surf("mane", html("#2a2420"), 3.0), float3 { -0.3, -2.6, 0.0 }))
    add_child(n, ring(4.5, 5.0, plain(col(c, "team")), float3 { -0.3, -2.6, 0.0 }))
    add_child(n, blob(float3 { 0.6, 3.6, 1.0 }, plain(html("#2a9a6a")), float3 { -4.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 12.0 }))
    return spec_of(n)

def helm_aztec_quilted(c:Colours) -> Spec:
    let n = mnode()
    let cotton = surf("cloth", html("#f0ead8"), 3.0)
    add_child(n, dome(float3 { 5.2, 3.6, 5.1 }, cotton, float3 { -0.2, -3.0, 0.0 }))
    for(3) k:
        let fk = float(k)
        add_child(n, ring(4.9 - fk * 1.2, 5.15 - fk * 1.2, surf("cloth", html("#c8bea4"), 2.0), float3 { -0.2, -2.4 + fk * 1.1, 0.0 }))
    let greens = [ html("#2a9a6a"), html("#e8c040"), html("#2a9a6a"), html("#c83a2a"), html("#2a9a6a") ]
    for(5) k:
        let z = -2.0 + float(k) * 1.0
        add_child(n, blob(float3 { 0.5, 3.0, 0.7 }, plain(greens[k]), float3 { -3.2, 1.6, z }, float3 { z * 6.0, 0.0, 20.0 }))
    add_child(n, ring(4.9, 5.4, plain(col(c, "team")), float3 { -0.2, -3.0, 0.0 }))
    lift_kids(n, 0.10)
    return spec_of(n)

def helm_aztec_eagle(c:Colours) -> Spec:
    let n = mnode()
    let feathers = surf("cloth", html("#6a4a2a"), 3.0)
    add_child(n, dome(float3 { 5.4, 4.6, 5.3 }, feathers, float3 { -0.4, -3.2, 0.0 }))
    let beak = plain(html("#e8b030"))
    add_child(n, cone(0.4, 2.4, 4.6, beak, float3 { 4.8, -1.0, 0.0 }, float3 { 0.0, 0.0, -100.0 }))
    for([ 1.0, -1.0 ]) side:
        add_child(n, blob(float3 { 0.7, 0.7, 0.4 }, plain(INK), float3 { 3.0, 0.4, 2.6 * side }))
        add_child(n, blob(float3 { 1.0, 2.6, 0.6 }, feathers, float3 { 1.2, -4.8, 4.8 * side }))
    for(4) k:
        let fk = float(k)
        add_child(n, blob(float3 { 0.6, 3.2, 0.8 }, plain(html("#f4f0e4")), float3 { -3.6 + fk * 0.2, 1.4, -1.5 + fk * 1.0 }, float3 { 0.0, 0.0, 30.0 }))
    add_child(n, ring(5.2, 5.6, plain(col(c, "team")), float3 { -0.4, -3.2, 0.0 }))
    return spec_of(n)

def weapon_macuahuitl(c:Colours) -> Spec:
    let n = mnode()
    let tip = float3 { 3.0, 14.0, 0.0 }
    let d = normalize(tip)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade([ float2 { 0.0, -1.0 }, float2 { 12.5, -1.7 }, float2 { 14.0, 0.0 }, float2 { 12.5, 1.7 }, float2 { 0.0, 1.0 } ], 0.8,
                       surf("wood_grain", html("#c89a60"), 3.0), float3_0, ang))
    let glass = surf("iron", html("#3a3640"), 1.5)
    let across = float3 { -d.y, d.x, 0.0 }
    for(6) k:
        let at = d * (3.0 + float(k) * 1.8)
        let w = 1.1 + float(k) * 0.1
        for([ 1.0, -1.0 ]) side:
            add_child(n, blob(float3 { 0.55, 0.7, 0.3 }, glass, at + across * side * (w + 0.5)))
    add_child(n, rod(float3_0, -d * 3.0, 0.6, 0.6, surf("leather", float3_1, 2.0), false))
    return spec_of(n)

def shield_chimalli(c:Colours) -> Spec:
    let n = mnode()
    let h = facing(n, float3 { 3.0, 0.5, 1.5 }, SHIELD_FACE)
    add_child(h, disc(5.6, 0.8, plain(col(c, "team")), 0.0))
    add_child(h, ring(2.6, 3.4, plain(html("#f4f0e4")), float3 { 0.0, 0.0, 0.45 }, float3 { 90.0, 0.0, 0.0 }))
    add_child(h, disc(1.2, 0.3, plain(html("#e8c040")), 0.5))
    let cols = [ html("#2a9a6a"), html("#e8c040"), html("#c83a2a") ]
    for(9) k:
        let x = -4.0 + float(k) * 1.0
        add_child(h, blob(float3 { 0.45, 2.0, 0.3 }, plain(cols[k % 3]), float3 { x, -6.0 - abs(x) * -0.25, 0.1 }))
    return spec_of(n)

// ---- Norse

def helm_norse_fur(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, dome(float3 { 5.0, 4.4, 4.8 }, surf("leather", float3 { 0.9, 0.85, 0.8 }, 2.0), float3 { -0.2, -3.8, 0.0 }))
    add_child(n, ring(4.6, 5.8, surf("rat_fur", html("#7a5a3c"), 2.0), float3 { 0.0, -3.6, 0.0 }))
    lift_kids(n, 1.7)
    return spec_of(n)

def helm_norse_conical(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3 { 0.85, 0.85, 0.9 }, 3.0)
    add_child(n, cone(0.3, 5.1, 5.6, iron, float3 { 0.0, -1.2, 0.0 }))
    add_child(n, ring(4.8, 5.4, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, rod(float3 { 0.0, 1.4, 0.0 }, float3 { -0.3, 3.2, 0.0 }, 0.45, 0.15, iron))
    add_child(n, rod(float3 { 5.0, -3.6, 0.0 }, float3 { 5.5, -7.0, 0.0 }, 0.6, 0.5, iron))
    lift_kids(n, 0.6)
    return spec_of(n)

def helm_norse_spectacle(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3 { 0.85, 0.85, 0.9 }, 3.0)
    add_child(n, dome(float3 { 5.0, 5.4, 4.8 }, iron, float3 { 0.0, -3.8, 0.0 }))
    add_child(n, ring(4.8, 5.4, iron, float3 { 0.0, -3.6, 0.0 }))
    add_child(n, rod(float3 { -5.0, -1.0, 0.0 }, float3 { 5.0, -1.0, 0.0 }, 0.5, 0.5, iron))
    for([ 1.0, -1.0 ]) side:
        add_child(n, ring(0.9, 1.5, iron, float3 { 4.6, -5.4, 1.7 * side }, float3 { 0.0, 0.0, 90.0 }))
    let mail = surf("mail", float3 { 0.7, 0.7, 0.75 }, 2.0)
    for([ 180.0 * 0.55, 180.0 * 0.78, 180.0 * 1.22, 180.0 * 1.45 ]) a:
        add_child(n, blob(float3 { 1.9, 2.4, 0.45 }, mail, float3 { cos(a) * 5.0 - 0.6, -4.6, sin(a) * 5.0 }, float3 { 0.0, -a, 0.0 }))
    add_child(n, ring(4.9, 5.3, plain(col(c, "team")), float3 { 0.0, -3.0, 0.0 }))
    return spec_of(n)

def axe_head(top:float, k:float) -> [float2]:
    let pts = [ float2 { 0.3, 1.0 }, float2 { 0.3, -1.4 }, float2 { 1.4, -6.0 }, float2 { -1.6, -6.8 }, float2 { -5.2, -6.0 },
                float2 { -3.0, -1.4 }, float2 { -3.0, 1.0 } ]
    return map(pts) p: float2 { top + p.x * k, p.y * k }

def weapon_axe_bearded(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, rod(-d * 3.4, d * 13.0, 0.6, 0.55, surf("wood_grain", float3 { 1.1, 1.0, 0.85 }, 4.0)))
    add_child(n, blade(axe_head(12.6, 1.0), 0.6, bright_iron(), float3_0, ang))
    add_child(n, ring(0.55, 0.95, surf("leather", float3_1, 2.0), -d * 1.2, float3 { 0.0, 0.0, ang - 90.0 }))
    return spec_of(n)

def weapon_axe_broad(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(SWORD3_TIP)
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, rod(-d * 4.0, d * 17.0, 0.65, 0.6, surf("wood_grain", float3 { 1.1, 1.0, 0.85 }, 4.0)))
    add_child(n, blade(axe_head(16.4, 1.35), 0.6, bright_iron(), float3_0, ang))
    add_child(n, ring(0.6, 1.05, plain(col(c, "team")), d * 11.0, float3 { 0.0, 0.0, ang - 90.0 }))
    add_child(n, ring(0.55, 0.95, surf("leather", float3_1, 2.0), -d * 1.2, float3 { 0.0, 0.0, ang - 90.0 }))
    return spec_of(n)

// ---- the healer's kit

let HERB = html("#8cc850")
let LINEN_PALE = html("#efe8d6")

def tool_staff_herbs(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("bone", html("#e2cc9c"), 6.0)
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 6.0, 31.0, 0.0 }
    add_child(n, rod(a, b, 1.0, 0.9, wood, false))
    add_child(n, rod(b, b + float3 { 3.0, 2.0, 0.0 }, 0.9, 0.7, wood))
    add_child(n, rod(b + float3 { 3.0, 2.0, 0.0 }, b + float3 { 4.2, 0.2, 0.0 }, 0.6, 0.5, wood))
    let herb = surf("leaf", HERB, 2.0)
    for(5) k:
        let ang = rad(-0.9 + float(k) * 0.45)
        add_child(n, blob(float3 { 0.8, 2.6, 0.8 }, herb, b + float3 { -0.6 + sin(ang) * 1.6, -2.4, cos(ang) * 0.8 }, float3 { 0.0, 0.0, ang * 0.6 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), b + float3 { 0.0, -0.6, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    return spec_of(n)

def tool_satchel(c:Colours) -> Spec:
    let n = mnode()
    let leather = surf("leather", float3 { 1.0, 0.92, 0.8 }, 3.0)
    add_child(n, box(float3 { 2.6, 4.4, 5.0 }, leather, float3 { 2.4, -2.6, 1.6 }))
    add_child(n, box(float3 { 2.8, 2.0, 5.2 }, surf("leather", float3 { 0.7, 0.55, 0.42 }, 3.0), float3 { 2.6, -0.8, 1.6 }))
    add_child(n, cone(1.0, 1.0, 3.2, plain(LINEN_PALE), float3 { 3.2, 0.6, 1.6 }, float3 { 90.0, 0.0, 0.0 }))
    return spec_of(n)

def tool_staff_cheese(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("bone", html("#e2cc9c"), 5.0)
    let a = float3 { -3.0, -9.0, 0.0 }
    let b = float3 { 2.0, 12.0, 0.0 }
    let t = float3 { 5.0, 29.0, 0.0 }
    add_child(n, rod(a, b, 1.0, 0.9, wood))
    add_child(n, rod(b, t, 0.9, 0.75, wood))
    add_child(n, slab([ float2 { -2.6, -1.6 }, float2 { 3.0, -1.6 }, float2 { -2.6, 2.6 } ], 2.6, surf("cheese", float3_1, 3.0), t + float3 { 0.4, 1.2, 0.0 }))
    add_child(n, ring(0.7, 1.1, plain(col(c, "team")), t + float3 { -0.2, -0.6, 0.0 }, float3 { 0.0, 0.0, -16.0 }))
    return spec_of(n)

def tool_satchel_cheese(c:Colours) -> Spec:
    let n = mnode()
    let sack = surf("cloth", html("#cdbb92"), 3.0)
    add_child(n, blob(float3 { 2.8, 3.4, 2.8 }, sack, float3 { 2.6, -2.4, 1.6 }))
    add_child(n, cone(0.7, 1.5, 1.4, sack, float3 { 2.6, 1.0, 1.6 }))
    add_child(n, ring(0.6, 1.0, plain(col(c, "team")), float3 { 2.6, 1.2, 1.6 }))
    add_child(n, slab([ float2 { 0.0, 0.0 }, float2 { 2.2, 0.6 }, float2 { 0.2, 1.8 } ], 1.2, surf("cheese", float3_1, 2.0), float3 { 3.6, -0.6, 3.6 }))
    return spec_of(n)

def tool_staff_lily(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 5.0, 25.0, 0.0 }
    add_child(n, rod(a, b, 1.1, 1.0, surf("reed_stalk", float3_1, 5.0), false))
    add_child(n, decal("water_lily", 7.0, 7.0, b + float3 { 0.0, 1.8, 0.4 }, float3 { 0.3, 0.6, 1.0 }))
    add_child(n, blob(float3 { 2.4, 0.6, 2.4 }, plain(col(c, "lily")), b + float3 { 0.0, -0.2, 0.0 }))
    return spec_of(n)

def tool_satchel_moss(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, blob(float3 { 2.8, 2.4, 3.0 }, surf("lily_pad", float3_1, 4.0), float3 { 2.6, -2.0, 1.6 }))
    add_child(n, blob(float3 { 1.8, 1.0, 2.0 }, plain(html("#6f8f3a")), float3 { 3.0, -0.2, 1.6 }))
    add_child(n, box(float3 { 5.8, 0.6, 0.6 }, plain(col(c, "team")), float3 { 2.6, -2.0, 4.5 }))
    return spec_of(n)

def leaves(n:MNode, a:float3, b:float3, count:int, size:float3, m:MMat, spread:float = 1.3):
    for(count) k:
        let t = float(k) / max(1.0, float(count) - 1.0)
        let side = if k % 2 == 0: 1.0 else: -1.0
        let ang = rad(t * 5.5)
        let p = lerp3(a, b, t) + float3 { cos(ang) * spread * side, 0.3, sin(ang) * spread }
        add_child(n, blob(size, m, p, float3 { sin(ang) * 30.0, 0.0, side * 50.0 }))

def tool_staff_laurel(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 5.0, 29.0, 0.0 }
    let d = normalize(b - a)
    let tilt = tilt_of(a, b)
    let bronze = surf("bronze", float3_1, 3.0)
    add_child(n, rod(a, b, 0.95, 0.9, surf("bone", html("#b48a5c"), 6.0)))
    add_child(n, cone(0.6, 1.2, 2.2, bronze, a + d * 1.0, float3 { 0.0, 0.0, tilt }))
    add_child(n, blob(float3 { 1.9, 1.9, 1.9 }, bronze, b + d * 1.6))
    add_child(n, ring(0.8, 1.3, bronze, b - d * 0.4, float3 { 0.0, 0.0, tilt }))
    let laurel = surf("leaf", html("#78b040"), 2.0)
    add_child(n, ring(1.4, 2.9, laurel, b - d * 1.6, float3 { 0.0, 0.0, tilt }, float3 { 1.0, 1.8, 1.0 }))
    leaves(n, lerp3(a, b, 0.45), b - d * 3.0, 7, float3 { 0.9, 2.0, 0.8 }, laurel, 1.4)
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), lerp3(a, b, 0.42), float3 { 0.0, 0.0, tilt }))
    return spec_of(n)

def tool_staff_olive(c:Colours) -> Spec:
    let n = mnode()
    let wood = surf("bone", html("#c4b494"), 5.0)
    let pts = [ float3 { -2.0, -9.0, 0.0 }, float3 { 1.2, 6.0, 0.4 }, float3 { 2.6, 18.0, -0.4 }, float3 { 5.4, 29.0, 0.0 } ]
    for(3) k:
        add_child(n, rod(pts[k], pts[k + 1], 1.05 - float(k) * 0.08, 0.95 - float(k) * 0.08, wood))
    add_child(n, blob(float3 { 1.4, 1.1, 1.3 }, wood, pts[1]))
    add_child(n, blob(float3 { 1.3, 1.0, 1.2 }, wood, pts[2]))
    let top = pts[3]
    add_child(n, rod(top, top + float3 { -2.2, 3.4, 0.3 }, 0.6, 0.45, wood))
    add_child(n, rod(top, top + float3 { 2.4, 3.0, -0.3 }, 0.6, 0.45, wood))
    let olive = surf("leaf", html("#b4c896"), 2.0)
    leaves(n, top + float3 { -2.2, 2.8, 0.0 }, top + float3 { 2.4, 3.6, 0.0 }, 10, float3 { 0.75, 2.1, 0.75 }, olive, 1.6)
    for(3) k:
        let fk = float(k)
        add_child(n, blob(float3 { 0.75, 0.9, 0.75 }, plain(html("#3a3a2a")), top + float3 { -0.8 + fk * 0.9, 1.4 - fk * 0.2, 1.0 - fk * 0.6 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), top + float3 { -0.3, -1.4, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    return spec_of(n)

def tool_satchel_flask(c:Colours) -> Spec:
    let n = mnode()
    let clay = surf("bld_brick", html("#e09a62"), 4.0)
    let at = float3 { 2.6, -2.6, 1.6 }
    add_child(n, blob(float3 { 2.5, 2.4, 2.5 }, clay, at))
    add_child(n, ring(2.1, 2.6, plain(html("#2a1e18")), at + float3 { 0.0, 0.4, 0.0 }, float3_0, float3 { 1.0, 1.6, 1.0 }))
    add_child(n, cone(0.8, 1.0, 1.8, clay, at + float3 { 0.0, 2.6, 0.0 }))
    add_child(n, cone(0.7, 0.7, 0.9, plain(html("#7a5a3a")), at + float3 { 0.0, 3.8, 0.0 }))
    add_child(n, rod(at + float3 { -1.2, 2.4, 0.0 }, float3 { 0.0, 1.2, 0.0 }, 0.35, 0.35, plain(col(c, "team"))))
    return spec_of(n)

def tool_staff_horsehair(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 5.0, 28.0, 0.0 }
    let d = normalize(b - a)
    let tilt = tilt_of(a, b)
    add_child(n, rod(a, b, 0.95, 0.85, surf("bone", html("#c8a070"), 6.0), false))
    let bronze = surf("bronze", float3_1, 3.0)
    add_child(n, blob(float3 { 1.4, 1.4, 1.4 }, bronze, b + d * 1.4))
    add_child(n, cone(1.6, 1.3, 1.0, bronze, b + d * 0.1, float3 { 0.0, 0.0, tilt }, 20))
    let hair = plain(html("#3e2a1e"))
    let tips = plain(html("#6a4a32"))
    for(10) k:
        let ang = float(k) * 360.0 / 10.0
        let out = float3 { cos(ang), 0.0, sin(ang) }
        let root = b + out * 1.1
        let tip = b + out * (2.6 + float(k % 3) * 0.5) + float3 { 0.0, -8.0 - float(k % 2) * 1.5, 0.0 }
        add_child(n, rod(root, tip, 0.55, 0.35, hair, false))
        add_child(n, blob(float3 { 0.45, 0.8, 0.45 }, tips, tip))
    add_child(n, blob(float3 { 1.9, 1.3, 1.9 }, hair, b + float3 { 0.0, -0.7, 0.0 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), b - d * 12.0, float3 { 0.0, 0.0, tilt }))
    return spec_of(n)

def tool_satchel_felt(c:Colours) -> Spec:
    let n = mnode()
    let felt = surf("bld_felt", html("#e8dcc0"), 3.0)
    add_child(n, blob(float3 { 2.7, 3.0, 2.6 }, felt, float3 { 2.6, -2.6, 1.6 }))
    add_child(n, cone(0.9, 1.5, 1.2, felt, float3 { 2.6, 0.4, 1.6 }))
    add_child(n, ring(1.9, 2.75, plain(col(c, "team")), float3 { 2.6, -2.0, 1.6 }, float3_0, float3 { 1.0, 1.4, 1.0 }))
    add_child(n, blob(float3 { 0.5, 0.9, 0.5 }, surf("bone", float3_1, 2.0), float3 { 2.6, 1.2, 3.0 }))
    return spec_of(n)

def tool_staff_papyrus(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 4.0, 25.0, 0.0 }
    add_child(n, rod(a, b, 1.05, 0.8, surf("reed_stalk", html("#9cc46a"), 5.0), false))
    add_child(n, cone(0.8, 1.6, 2.4, surf("reed_leaf", html("#c8b070"), 3.0), b + float3 { 0.0, 0.6, 0.0 }))
    let spray = plain(html("#6aa040"))
    let tips = plain(html("#c8d070"))
    for(11) k:
        let ang = float(k) * 360.0 / 11.0
        let tip = b + float3 { cos(ang) * 4.6, 4.4 - abs(sin(ang * 0.5)) * 0.8, sin(ang) * 4.6 }
        add_child(n, rod(b + float3 { 0.0, 1.6, 0.0 }, tip, 0.32, 0.32, spray, false))
        add_child(n, blob(float3 { 0.75, 0.6, 0.75 }, tips, tip))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), b + float3 { -0.9, -5.0, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    return spec_of(n)

def tool_satchel_linen(c:Colours) -> Spec:
    let n = mnode()
    let linen = surf("cloth", html("#f2ecd8"), 3.0)
    add_child(n, blob(float3 { 2.6, 3.2, 2.6 }, linen, float3 { 2.6, -2.6, 1.6 }))
    add_child(n, cone(0.6, 1.4, 1.6, linen, float3 { 2.6, 0.8, 1.6 }))
    add_child(n, ring(2.1, 2.7, plain(html("#2a5a9a")), float3 { 2.6, -3.4, 1.6 }, float3_0, float3 { 1.0, 1.5, 1.0 }))
    add_child(n, ring(0.6, 1.0, plain(col(c, "team")), float3 { 2.6, 0.4, 1.6 }))
    return spec_of(n)

def tool_staff_gourd(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 4.5, 25.0, 0.0 }
    let d = normalize(b - a)
    let tilt = tilt_of(a, b)
    add_child(n, rod(a, b, 1.0, 0.9, surf("reed_stalk", html("#d8c878"), 5.0)))
    for(5) k:
        add_child(n, ring(0.8, 1.25, surf("reed_stalk", html("#a89848"), 3.0), lerp3(a, b, 0.15 + float(k) * 0.19), float3 { 0.0, 0.0, tilt }))
    let gourd = surf("bone", html("#f2b84a"), 4.0)
    let g = b + d * 1.2 + float3 { 0.4, 0.0, 0.0 }
    add_child(n, blob(float3 { 2.6, 2.6, 2.6 }, gourd, g + float3 { 0.0, 1.6, 0.0 }))
    add_child(n, blob(float3 { 1.8, 1.8, 1.8 }, gourd, g + float3 { 0.0, 4.9, 0.0 }))
    add_child(n, ring(0.7, 1.2, plain(html("#c02a20")), g + float3 { 0.0, 3.5, 0.0 }))
    add_child(n, cone(0.5, 0.6, 1.2, plain(html("#5a3a20")), g + float3 { 0.0, 7.0, 0.0 }))
    add_child(n, blob(float3 { 0.7, 2.4, 0.7 }, plain(html("#c02a20")), b - d * 2.5 + float3 { 1.1, -2.0, 0.4 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), b - d * 1.2, float3 { 0.0, 0.0, tilt }))
    return spec_of(n)

def tool_staff_rune(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let m = float3 { 1.5, 9.0, 0.4 }
    let b = float3 { 4.0, 25.0, 0.0 }
    let ash = surf("wood_grain", float3 { 1.1, 1.0, 0.85 }, 5.0)
    add_child(n, rod(a, m, 1.0, 0.9, ash))
    add_child(n, rod(m, b, 0.9, 0.8, ash))
    let d = normalize(b - m)
    add_child(n, blob(float3 { 2.4, 3.0, 1.6 }, surf("rock", float3 { 0.9, 0.9, 0.86 }, 1.5), b + d * 2.4))
    for(3) k:
        add_child(n, blob(float3 { 0.25, 1.6, 0.2 }, plain(col(c, "team")), b + d * 2.4 + float3 { 0.6 * float(k - 1), 0.0, 1.5 }))
    for([ 1.0, -1.0 ]) side:
        add_child(n, blob(float3 { 0.9, 2.4, 0.9 }, surf("leaf", float3 { 0.7, 0.9, 0.55 }, 2.0), b - d * 1.0 + float3 { 0.4, -1.6, 1.3 * side }, float3 { 0.0, 0.0, 18.0 * side }))
    add_child(n, ring(0.7, 1.15, surf("leather", float3_1, 2.0), b - d * 0.2, float3 { 0.0, 0.0, tilt_of(m, b) }))
    return spec_of(n)

def tool_satchel_lacquer(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, box(float3 { 3.6, 3.8, 4.2 }, plain(html("#221816")), float3 { 2.6, -2.6, 1.6 }))
    add_child(n, box(float3 { 3.8, 0.7, 4.4 }, plain(html("#b82a20")), float3 { 2.6, -1.0, 1.6 }))
    add_child(n, box(float3 { 1.0, 1.0, 0.5 }, surf("bronze", float3_1, 2.0), float3 { 2.6, -2.2, 3.9 }))
    add_child(n, rod(float3 { 2.6, -0.6, 1.6 }, float3 { 0.0, 1.2, 0.0 }, 0.35, 0.35, plain(col(c, "team"))))
    return spec_of(n)

def tool_staff_feather(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 4.5, 25.0, 0.0 }
    let d = normalize(b - a)
    let tilt = tilt_of(a, b)
    add_child(n, rod(a, b, 0.95, 0.9, surf("bone", html("#c08a58"), 6.0)))
    let bands = [ html("#2a7a6a"), html("#e8c040"), html("#c83a2a") ]
    for(3) k:
        add_child(n, ring(0.75, 1.15, plain(bands[k]), b - d * (2.0 + float(k) * 1.3), float3 { 0.0, 0.0, tilt }))
    add_child(n, blob(float3 { 1.5, 1.2, 1.5 }, plain(html("#e8c040")), b + d * 0.6))
    let cols = [ html("#1f9a5a"), html("#c83a2a"), html("#1f9a5a"), html("#e8c040"), html("#1f9a5a"), html("#c83a2a"), html("#1f9a5a") ]
    for(7) k:
        let ang = rad(float(k - 3) * 0.32)
        let length = 5.8 - abs(float(k - 3)) * 0.6
        let p = b + d * 1.0 + float3 { sin(ang) * length * 0.75, cos(ang) * length, sin(ang) * length * 0.45 }
        add_child(n, blob(float3 { 0.75, length * 0.62, 0.75 }, plain(cols[k]), p, float3 { ang * 0.6, 0.0, -ang }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), lerp3(a, b, 0.5), float3 { 0.0, 0.0, tilt }))
    return spec_of(n)

def tool_satchel_woven(c:Colours) -> Spec:
    let n = mnode()
    add_child(n, box(float3 { 3.0, 4.2, 4.6 }, surf("wicker", html("#e0c080"), 2.5), float3 { 2.6, -2.6, 1.6 }))
    add_child(n, box(float3 { 3.1, 0.8, 4.7 }, plain(html("#2a7a6a")), float3 { 2.6, -1.9, 1.6 }))
    add_child(n, box(float3 { 3.1, 0.8, 4.7 }, plain(html("#c83a2a")), float3 { 2.6, -3.4, 1.6 }))
    add_child(n, ring(0.5, 0.9, plain(col(c, "team")), float3 { 2.6, -0.1, 1.6 }))
    add_child(n, blob(float3 { 0.5, 2.0, 0.35 }, plain(html("#1f9a5a")), float3 { 3.2, 1.2, 2.4 }, float3 { 0.0, 0.0, -20.0 }))
    return spec_of(n)

def tool_staff_lantern(c:Colours) -> Spec:
    let n = mnode()
    let a = float3 { -2.0, -9.0, 0.0 }
    let b = float3 { 4.0, 28.0, 0.0 }
    add_child(n, rod(a, b, 0.95, 0.85, surf("wood_grain", float3 { 0.55, 0.38, 0.26 }, 6.0)))
    let iron = surf("iron", float3 { 0.55, 0.55, 0.6 }, 3.0)
    add_child(n, rod(b, b + float3 { 2.4, 2.4, 0.0 }, 0.6, 0.55, iron))
    add_child(n, rod(b + float3 { 2.4, 2.4, 0.0 }, b + float3 { 4.6, 1.6, 0.0 }, 0.55, 0.5, iron))
    let lt = b + float3 { 4.6, -3.4, 0.0 }
    add_child(n, rod(b + float3 { 4.6, 1.6, 0.0 }, lt + float3 { 0.0, 2.8, 0.0 }, 0.3, 0.3, iron))
    add_child(n, box(float3 { 2.6, 3.2, 2.6 }, glow(html("#ffd060")), lt))
    for([ -1.3, 1.3 ]) x:
        for([ -1.3, 1.3 ]) z:
            add_child(n, box(float3 { 0.45, 3.4, 0.45 }, iron, lt + float3 { x, 0.0, z }))
    add_child(n, cone(0.4, 2.1, 1.6, iron, lt + float3 { 0.0, 2.3, 0.0 }))
    add_child(n, box(float3 { 2.9, 0.5, 2.9 }, iron, lt + float3 { 0.0, -1.8, 0.0 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), b + float3 { -0.6, -3.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    return spec_of(n)

def tool_staff_candle(c:Colours) -> Spec:
    let n = mnode()
    let bone = surf("bone", html("#ece4cc"), 4.0)
    let pts = [ float3 { -2.0, -9.0, 0.0 }, float3 { 1.8, 4.0, 0.5 }, float3 { 0.8, 13.0, -0.4 }, float3 { 4.2, 22.0, 0.3 }, float3 { 3.6, 26.0, 0.0 } ]
    for(4) k:
        add_child(n, rod(pts[k], pts[k + 1], 0.95, 0.85, bone))
        add_child(n, blob(float3 { 1.45, 1.2, 1.35 }, bone, pts[k + 1]))
    let top = pts[4]
    add_child(n, cone(2.6, 1.2, 2.0, bone, top + float3 { 0.0, 1.2, 0.0 }))
    let wax = plain(html("#f8f2e0"))
    add_child(n, cone(1.3, 1.3, 3.6, wax, top + float3 { 0.0, 3.8, 0.0 }))
    add_child(n, blob(float3 { 0.6, 1.3, 0.6 }, wax, top + float3 { 1.3, 3.0, 0.4 }))
    add_child(n, blob(float3 { 0.5, 1.0, 0.5 }, wax, top + float3 { -1.2, 3.4, 0.6 }))
    add_child(n, blob(float3 { 1.2, 2.1, 1.2 }, glow(html("#ff9a30")), top + float3 { 0.0, 7.4, 0.0 }))
    add_child(n, blob(float3 { 0.6, 1.1, 0.6 }, glow(html("#fff2b0")), top + float3 { 0.0, 7.0, 0.7 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), pts[3] + float3 { -0.6, -2.0, 0.0 }, float3 { 0.0, 0.0, -20.0 }))
    return spec_of(n)

def tool_satchel_bottle(c:Colours) -> Spec:
    let n = mnode()
    let at = float3 { 2.6, -2.8, 1.6 }
    let glass = plain(html("#4a2a6a"))
    add_child(n, blob(float3 { 2.3, 2.6, 2.3 }, glass, at))
    add_child(n, cone(0.7, 0.9, 2.2, glass, at + float3 { 0.0, 2.8, 0.0 }))
    add_child(n, cone(0.75, 0.6, 1.0, plain(html("#8a6a40")), at + float3 { 0.0, 4.2, 0.0 }))
    add_child(n, blob(float3 { 0.8, 0.9, 0.4 }, glow(html("#9ae070")), at + float3 { 0.9, 0.4, 2.0 }))
    add_child(n, ring(2.0, 2.5, plain(col(c, "team")), at + float3 { 0.0, 0.6, 0.0 }, float3_0, float3 { 1.0, 1.3, 1.0 }))
    return spec_of(n)

def tool_staff_branch(c:Colours) -> Spec:
    let n = mnode()
    let bark = surf("bark_plate", html("#b08a60"), 4.0)
    let pts = [ float3 { -2.0, -9.0, 0.0 }, float3 { 0.8, 5.0, -0.4 }, float3 { 3.4, 17.0, 0.4 }, float3 { 5.0, 26.0, 0.0 } ]
    for(3) k:
        add_child(n, rod(pts[k], pts[k + 1], 1.15 - float(k) * 0.12, 1.0 - float(k) * 0.12, bark))
    let top = pts[3]
    let leaf = surf("leaf", html("#80c850"), 2.0)
    let twigs = [ [ pts[2], pts[2] + float3 { -3.4, 3.2, 0.6 } ], [ top, top + float3 { -2.0, 3.6, -0.4 } ], [ top, top + float3 { 2.6, 3.0, 0.5 } ] ]
    for(twigs) t:
        add_child(n, rod(t[0], t[1], 0.5, 0.35, bark))
        add_child(n, blob(float3 { 1.4, 1.0, 1.2 }, leaf, t[1] + float3 { 0.0, 0.6, 0.0 }))
    for(6) k:
        let ang = float(k) * 360.0 / 6.0
        add_child(n, blob(float3 { 1.0, 2.0, 0.6 }, leaf, top + float3 { cos(ang) * 1.8, 2.0 + sin(ang * 2.0) * 0.6, sin(ang) * 1.8 }, float3 { sin(ang) * 40.0, 0.0, cos(ang) * 40.0 }))
    add_child(n, blob(float3 { 1.8, 1.6, 1.8 }, leaf, top + float3 { 0.0, 3.6, 0.0 }))
    add_child(n, ring(0.7, 1.15, plain(col(c, "team")), pts[1] + float3 { 0.9, 3.5, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    return spec_of(n)

def tool_satchel_leaf(c:Colours) -> Spec:
    let n = mnode()
    let at = float3 { 2.6, -2.4, 1.6 }
    add_child(n, blob(float3 { 2.6, 2.9, 2.6 }, surf("leaf", html("#6aa848"), 3.0), at))
    for(3) k:
        let ang = float(k) * 360.0 / 3.0
        add_child(n, blob(float3 { 1.0, 1.8, 0.5 }, surf("leaf", html("#4a8a38"), 2.0), at + float3 { cos(ang) * 1.2, 2.6, sin(ang) * 1.2 }, float3 { sin(ang) * 30.0, 0.0, cos(ang) * 30.0 }))
    add_child(n, ring(2.0, 2.7, plain(col(c, "team")), at + float3 { 0.0, 0.8, 0.0 }, float3_0, float3 { 1.0, 1.3, 1.0 }))
    return spec_of(n)

def build_units5(base:string, c:Colours) -> Spec?:
    switch base:
        case "helm.nile_khat": return helm_nile_khat(c)
        case "helm.nile_headcloth": return helm_nile_headcloth(c)
        case "helm.nile_bronze": return helm_nile_bronze(c)
        case "weapon.khopesh": return weapon_khopesh(c)
        case "shield.cowhide": return shield_cowhide(c)
        case "helm.han_topknot": return helm_han_topknot(c)
        case "helm.han_cap": return helm_han_cap(c)
        case "helm.han_lamellar": return helm_han_lamellar(c)
        case "weapon.ji", "weapon.ji.bronze", "weapon.ji.iron": return weapon_ji(c)
        case "shield.lacquer": return shield_lacquer(c)
        case "helm.aztec_band": return helm_aztec_band(c)
        case "helm.aztec_quilted": return helm_aztec_quilted(c)
        case "helm.aztec_eagle": return helm_aztec_eagle(c)
        case "weapon.macuahuitl": return weapon_macuahuitl(c)
        case "shield.chimalli": return shield_chimalli(c)
        case "helm.norse_fur": return helm_norse_fur(c)
        case "helm.norse_conical": return helm_norse_conical(c)
        case "helm.norse_spectacle": return helm_norse_spectacle(c)
        case "weapon.axe.bearded": return weapon_axe_bearded(c)
        case "weapon.axe.broad": return weapon_axe_broad(c)
        case "tool.staff.herbs": return tool_staff_herbs(c)
        case "tool.satchel": return tool_satchel(c)
        case "tool.staff.cheese": return tool_staff_cheese(c)
        case "tool.satchel.cheese": return tool_satchel_cheese(c)
        case "tool.staff.lily": return tool_staff_lily(c)
        case "tool.satchel.moss": return tool_satchel_moss(c)
        case "tool.staff.laurel": return tool_staff_laurel(c)
        case "tool.staff.olive": return tool_staff_olive(c)
        case "tool.satchel.flask": return tool_satchel_flask(c)
        case "tool.staff.horsehair": return tool_staff_horsehair(c)
        case "tool.satchel.felt": return tool_satchel_felt(c)
        case "tool.staff.papyrus": return tool_staff_papyrus(c)
        case "tool.satchel.linen": return tool_satchel_linen(c)
        case "tool.staff.gourd": return tool_staff_gourd(c)
        case "tool.staff.rune": return tool_staff_rune(c)
        case "tool.satchel.lacquer": return tool_satchel_lacquer(c)
        case "tool.staff.feather": return tool_staff_feather(c)
        case "tool.satchel.woven": return tool_satchel_woven(c)
        case "tool.staff.lantern": return tool_staff_lantern(c)
        case "tool.staff.candle": return tool_staff_candle(c)
        case "tool.satchel.bottle": return tool_satchel_bottle(c)
        case "tool.staff.branch": return tool_staff_branch(c)
        case "tool.satchel.leaf": return tool_satchel_leaf(c)
        default: return mod_part(base, c)  // a mod's .glb part (nil when no mod in use has it)
