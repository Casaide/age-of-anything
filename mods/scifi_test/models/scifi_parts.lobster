// The scifi_test mod's parts for the Lobster game (scifi_parts.gd's, line for line): built from the game's model
// kit (tests/lobster_spike/model/: blob, rod, slab, dome, ring, cone, box, surf, plain, glow...). A mod's Lobster
// model file defines build_mod_<mod id>(base, colours) -> Spec? for its parts (nil for the rest); mod.json's
// "lobster_models" names it, and play.sh includes it when the mod is on. Same frames as the game's own parts.

let SCIFI_ENERGY = html("#7fe6ff")    // the light of the emitters and the visor
let SCIFI_SUIT = html("#2c3138")      // the dark undersuit and gun body
let SCIFI_PLATE = float3 { 0.72, 0.76, 0.8 }

def scifi_plate(units:float = 3.0) -> MMat: return surf("textures/scifi_test/plate", SCIFI_PLATE, units)
def scifi_gunmetal() -> MMat: return surf("iron", float3 { 0.42, 0.45, 0.5 }, 2.0)
def scifi_pts(xy:[float]) -> [float2]: return map(xy.length / 2) i: float2 { xy[i * 2], xy[i * 2 + 1] }

// ---- weapons

// The pulse rifle: along the musket's line, a stock and receiver in one outline, a shroud, a rail, a cell, a
// ring of light at the emitter.
def weapon_pulse_rifle(c:Colours) -> Spec:
    let n = mnode()
    let body = surf("iron", float3 { 0.3, 0.33, 0.37 }, 2.0)
    let plate = scifi_plate(2.0)
    let line = normalize(float3 { 14.0, 3.6, 0.0 })
    let frame = add_child(n, mnode())
    frame.rot = float3 { 0.0, 0.0, atan2(float2 { line.x, line.y }) }
    add_child(frame, slab(scifi_pts([-6.0, -1.8, -6.0, 1.2, -1.0, 1.6, 9.0, 1.8, 10.0, 0.6, 10.0, -1.0,
        2.0, -1.2, 1.0, -3.2, -0.6, -3.2, -0.8, -1.2, -3.5, -1.0]), 1.8, body))
    add_child(frame, box(float3 { 9.0, 1.6, 2.2 }, plate, float3 { 5.5, 1.4, 0.0 }))
    add_child(frame, box(float3 { 7.0, 0.5, 0.9 }, body, float3 { 5.0, 2.45, 0.0 }))
    add_child(frame, box(float3 { 1.0, 1.0, 1.0 }, plate, float3 { 2.5, 3.0, 0.0 }))
    add_child(frame, box(float3 { 6.0, 1.7, 1.8 }, body, float3 { 13.0, 0.9, 0.0 }))
    add_child(frame, box(float3 { 2.4, 0.5, 1.95 }, plain(col(c, "team")), float3 { 12.0, 1.8, 0.0 }))
    add_child(frame, cone(0.9, 1.15, 1.0, body, float3 { 16.4, 0.9, 0.0 }, float3 { 0.0, 0.0, -90.0 }))
    add_child(frame, ring(0.45, 0.85, glow(SCIFI_ENERGY), float3 { 17.0, 0.9, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    add_child(frame, blob(float3 { 0.45, 0.45, 0.45 }, glow(float3_1), float3 { 17.05, 0.9, 0.0 }))
    add_child(frame, box(float3 { 2.6, 1.3, 0.7 }, glow(darkened(SCIFI_ENERGY, 0.15)), float3 { 4.5, -0.2, 1.1 }))
    return spec_of(n)

// Age 3's heavy pulse rifle: a longer shroud (the emitter moves to its end), a scope and a second cell.
def weapon_pulse_rifle_heavy(c:Colours) -> Spec:
    let s = weapon_pulse_rifle(c)
    let frame = s.node.kids[0]
    let body = surf("iron", float3 { 0.3, 0.33, 0.37 }, 2.0)
    add_child(frame, box(float3 { 3.0, 1.5, 1.7 }, body, float3 { 17.4, 0.9, 0.0 }))
    for(frame.kids) k:
        if k.mesh and k.pos.x > 16.0 and k.pos.x < 17.2: k.pos += float3 { 2.6, 0.0, 0.0 }
    add_child(frame, rod(float3 { 2.0, 3.4, 0.0 }, float3 { 7.0, 3.4, 0.0 }, 0.6, 0.6, body))
    add_child(frame, ring(0.25, 0.55, glow(SCIFI_ENERGY), float3 { 7.05, 3.4, 0.0 }, float3 { 0.0, 0.0, 90.0 }))
    add_child(frame, box(float3 { 2.6, 1.3, 0.7 }, glow(darkened(SCIFI_ENERGY, 0.15)), float3 { 4.5, -0.2, -1.1 }))
    return s

// The arc blade: a blade of light with a white core on a dark hilt with a guard, held low like a sword.
def weapon_arc_blade(c:Colours) -> Spec:
    let n = mnode()
    let d = normalize(float3 { 3.0, 14.0, 0.0 })
    let ang = atan2(float2 { d.x, d.y })
    add_child(n, blade(scifi_pts([1.5, -0.8, 13.0, -0.7, 14.8, 0.0, 13.0, 0.7, 1.5, 0.8]), 0.7, glow(SCIFI_ENERGY), float3_0, ang))
    add_child(n, blade(scifi_pts([2.0, -0.35, 13.0, -0.3, 14.0, 0.0, 13.0, 0.3, 2.0, 0.35]), 0.9, glow(float3_1), float3_0, ang))
    let dark = scifi_gunmetal()
    let across = float3 { -d.y, d.x, 0.0 }
    add_child(n, rod(-across * 2.2 + d * 1.2, across * 2.2 + d * 1.2, 0.6, 0.6, dark))
    add_child(n, rod(d * 1.2, -d * 3.0, 0.75, 0.7, surf("leather", float3 { 0.35, 0.35, 0.38 }, 2.0), false))
    add_child(n, blob(float3 { 0.95, 0.95, 0.95 }, plain(col(c, "team")), -d * 3.5))
    return spec_of(n)

// ---- head gear

// The sealed helmet: a shell over the whole head, a face plate with a slit of light, a team stripe, an antenna.
def helm_visor_sealed(c:Colours) -> Spec:
    let n = mnode()
    let plate = scifi_plate(3.0)
    let dark = surf("iron", SCIFI_SUIT, 2.0)
    add_child(n, blob(float3 { 5.3, 4.8, 5.1 }, plate, float3 { -0.2, -4.0, 0.0 }))
    add_child(n, blob(float3 { 2.6, 3.0, 4.4 }, plate, float3 { 3.6, -6.0, 0.0 }))
    add_child(n, ring(3.6, 4.4, dark, float3 { 0.2, -8.2, 0.0 }, float3 { 0.0, 0.0, -6.0 }, float3 { 1.0, 0.8, 1.0 }))
    add_child(n, blob(float3 { 1.6, 1.4, 4.4 }, dark, float3 { 4.4, -4.4, 0.0 }))
    add_child(n, blob(float3 { 1.2, 0.75, 4.0 }, glow(SCIFI_ENERGY), float3 { 5.3, -4.3, 0.0 }))
    add_child(n, ring(5.35, 5.75, plain(col(c, "team")), float3 { -0.2, -4.4, 0.0 }, float3 { 90.0, 0.0, 0.0 }, float3 { 1.0, 1.0, 0.35 }))
    add_child(n, rod(float3 { -2.5, -1.2, -4.4 }, float3 { -3.5, 3.0, -4.6 }, 0.25, 0.18, dark, false))
    add_child(n, blob(float3 { 0.9, 1.4, 0.6 }, dark, float3 { -0.5, -5.2, 5.2 }))
    add_child(n, blob(float3 { 0.9, 1.4, 0.6 }, dark, float3 { -0.5, -5.2, -5.2 }))
    return spec_of(n)

// ---- armour (frog-sized: the body's torso_fit scales it)

def armour_plate_composite(c:Colours) -> Spec:
    let n = mnode()
    let plate = scifi_plate(4.0)
    add_child(n, blob(float3 { 8.8, 8.2, 10.4 }, surf("iron", SCIFI_SUIT, 3.0), float3 { 1.5, 0.5, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, blob(float3 { 5.2, 6.4, 9.0 }, plate, float3 { 5.2, 2.2, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, blob(float3 { 4.6, 6.8, 9.2 }, plate, float3 { -2.6, 2.0, 0.0 }, float3 { 0.0, 0.0, -10.0 }))
    add_child(n, ring(0.97, 1.06, plain(col(c, "team")), float3 { 1.6, -1.4, 0.0 }, float3 { 0.0, 0.0, -10.0 }, float3 { 8.9, 1.6, 10.5 }))
    add_child(n, blob(float3 { 0.9, 0.9, 0.9 }, glow(SCIFI_ENERGY), float3 { 10.0, 3.0, 0.0 }))
    add_child(n, ring(0.97, 1.08, surf("iron", SCIFI_SUIT, 2.0), float3 { 1.4, -5.6, 0.0 }, float3 { 0.0, 0.0, -10.0 }, float3 { 7.2, 1.2, 8.6 }))
    return spec_of(n)

// ---- back

def pack_power(c:Colours) -> Spec:
    let n = mnode()
    let plate = scifi_plate(2.0)
    let dark = surf("iron", SCIFI_SUIT, 2.0)
    add_child(n, box(float3 { 3.0, 7.0, 5.4 }, plate, float3 { -1.4, 0.5, 0.0 }))
    add_child(n, box(float3 { 2.6, 1.0, 4.8 }, dark, float3 { -1.4, 4.4, 0.0 }))
    for(3) k: add_child(n, box(float3 { 2.7, 0.25, 0.5 }, plain(html("#15181c")), float3 { -1.4, 4.95, -1.6 + float(k) * 1.6 }))
    add_child(n, box(float3 { 0.4, 4.4, 1.0 }, glow(SCIFI_ENERGY), float3 { -2.95, 0.6, 0.0 }))
    add_child(n, box(float3 { 3.1, 0.9, 5.5 }, plain(col(c, "team")), float3 { -1.4, -2.4, 0.0 }))
    return spec_of(n)

def build_mod_scifi_test(base:string, c:Colours) -> Spec?:
    switch base:
        case "weapon.pulse_rifle": return weapon_pulse_rifle(c)
        case "weapon.pulse_rifle.heavy": return weapon_pulse_rifle_heavy(c)
        case "weapon.arc_blade": return weapon_arc_blade(c)
        case "helm.visor_sealed": return helm_visor_sealed(c)
        case "armour.plate_composite": return armour_plate_composite(c)
        case "pack.power": return pack_power(c)
        default: return nil
