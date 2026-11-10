// The frame's glows for the atmosphere (#411, view/atmosphere.lobster): where the fires already burning in the game
// are, and lit windows and flashes, each as its source in data/atmosphere.json says. View only. (Glowing shots add
// theirs as they're drawn: game/fx.lobster's draw_bolt.)

def collect_glows():
    let fire = atmo_source("building_fire")
    let ruin = atmo_source("ruin_fire")
    let window = atmo_source("window")
    for(b_id.length) b:
        if b_done[b] == 1 and b_owner[b] < arch_of.length:
            let cell = b_cy[b] * W + b_cx[b]
            let seen = fog[ME][cell] == 2
            if seen or teams[b_owner[b]] == teams[ME]:
                let look = building_look(b)
                let at = building_anchor(b)
                let full = bm_hp[b_owner[b]][b_kind[b]]
                let damage = if full > 0: 1.0 - float(b_hp[b]) / float(full) else: 0.0
                if damage >= DAMAGE_FIRE:  // (as building_fx_tick sets them burning, game/town.lobster)
                    let spots = fire_spots(b, look)
                    let burning = min(spots.length, 1 + int((damage - DAMAGE_FIRE) / (1.0 - DAMAGE_FIRE) * 3.0))
                    for(burning) k: atmo_glow(fire, at + spots[k] + float2 { 0.0, -4.0 }, float3_1, 1.0, float(b_id[b] * 7 + k * 3))
                if seen:
                    let fx = bfx.get(look)
                    if fx:
                        for(fx.lights) l, n: atmo_glow(window, at + l, float3_1, 1.0, float(b_id[b] * 13 + n * 7))
    for(fx_ruins) r:
        if clock_s - r.t0 < RUIN_BURN:
            let spots = fire_spots_on(r.id, r.body)
            let fade = 1.0 - (clock_s - r.t0) / RUIN_BURN
            for(min(r.fires, spots.length)) k: atmo_glow(ruin, r.at / 1.5 + spots[k], float3_1, min(1.0, fade * 2.0), float(r.id * 7 + k * 3))
    let flash = atmo_source("flash")
    for(fx_flashes) f:
        if not f.ring: atmo_glow(flash, f.pos, f.col.xyz, (1.0 - f.t / f.life) * min(1.0, f.r / 4.0), f.r * 31.0)
