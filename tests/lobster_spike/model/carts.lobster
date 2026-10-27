// ------------------------------------------------------------------ trade cart concepts, round TC1 (scenes/art_pixel/cart_concepts.gd)
// Staged by data/later/trade_carts.json, drawn by the concept sheets and checked by the placement check's
// composites; nothing here is in play. Part ids "concept.tc1_<option>_<take>":
//   a  the race's own mount pulls a two-wheeled cart in a draught harness (the cart in play, D-127)
//   b  the handcart in play until D-127, pushed by a worker
//   c  each family its own: timber a covered wagon behind two ponies; frog a giant snail with panniers; junk a
//      scrap barrow; forest a ball of goods rolled by a beetle; spooky a silk-wrapped bundle on a bone sledge
// Same frame as the engines: x forward, y up, z towards the viewer's side, standing on y = 0.

// Round TC1 as first drawn (a_v1, kept for the placement fixture): where each mount stood in front of the cart,
// where its chest was from there (the rope traces ran to it), the handler.
class CartBeast:
    x:float
    chest:float3
    lead:float

def tc1_beast(name:string) -> CartBeast:
    switch name:
        case "pony": return CartBeast { 38.0, float3 { 9.0, 18.0, 8.0 }, 15.0 }
        case "newt": return CartBeast { 44.0, float3 { 11.0, 9.0, 11.0 }, 20.0 }
        case "cat": return CartBeast { 36.0, float3 { 8.0, 13.0, 7.5 }, 14.0 }
        case "beetle": return CartBeast { 36.0, float3 { 9.0, 11.0, 9.5 }, 16.0 }
        default: return CartBeast { 38.0, float3 { 3.0, 12.0, 10.0 }, 22.0 }   // (the spider)

def take_beast(take:string) -> string:
    switch take:
        case "timber": return "pony"
        case "frog": return "newt"
        case "junk": return "cat"
        case "forest": return "beetle"
        default: return "spider"

def build_carts(base:string, c:Colours) -> Spec?:
    if not starts_with(base, "concept.tc1_"): return nil
    let w = tokenize(base.substring(12, base.length - 12), "_", "")
    if w.length != 2: return nil
    let take = w[1]
    switch w[0]:
        case "a": return hauled_cart(take_beast(take), siege_style(take, c), c, if take == "frog": 1.25 else: 1.0)
        case "b":
            let s = handcart(siege_style(take, c), true)
            return if take == "frog": scaled(s, 1.25) else: s
        case "c":
            switch take:
                case "timber": return cart_wagon(siege_style(take, c), c)
                case "frog": return snail_packs(siege_style(take, c))
                case "junk": return scrap_barrow(siege_style(take, c), "goods")
                case "forest": return goods_ball(siege_style(take, c))
                case "spooky": return silk_sledge(siege_style(take, c))
                default: return nil
        default: return nil

// TC1 A as first drawn (2026-10-13), kept so the placement fixture can put it back and must fail it (Dominic:
// "this is bugged, did the tests not catch it?"): rope traces from a swingletree to points in the air by the
// beast's chest, no harness, the cart floating behind, the handler in the cat's flank.
def cart_a_v1(take:string, c:Colours) -> Spec:
    let s = siege_style(take, c)
    let b = tc1_beast(take_beast(take))
    let n = mnode()
    let wr = 6.5
    let y = wr + 1.6
    for([1.0, -1.0]) side: siege_wheel(n, float3 { 0.0, wr, 8.6 * side }, wr, 1.6, s)
    add_child(n, rod(float3 { 0.0, wr, -9.6 }, float3 { 0.0, wr, 9.6 }, 0.6, 0.6, s.dark, false))
    let plank = if take != "spooky": surf("wood_grain", float3_1, 8.0) else: s.wood
    add_child(n, box(float3 { 24.0, 1.2, 13.0 }, plank, float3 { 0.0, y, 0.0 }))
    for([1.0, -1.0]) side: add_child(n, box(float3 { 24.0, 3.6, 0.8 }, plank, float3 { 0.0, y + 2.3, 6.3 * side }))
    for([-11.6, 11.6]) x: add_child(n, box(float3 { 0.8, 3.6, 13.0 }, plank, float3 { x, y + 2.3, 0.0 }))
    cart_load(n, s, float3 { 0.0, y, 0.0 })
    // (a prop at the back, it tips back without the beast, and the swingletree at the front)
    add_child(n, rod(float3 { -11.0, y, 0.0 }, float3 { -13.0, 0.3, 0.0 }, 0.5, 0.5, s.dark))
    add_child(n, siege_beam(float3 { 13.5, y + 1.0, -7.5 }, float3 { 13.5, y + 1.0, 7.5 }, 1.2, 1.2, s.dark))
    let chest = float3 { b.x, 0.0, 0.0 } + b.chest
    for([1.0, -1.0]) side:   // (the traces, to the beast's chest on either side of it)
        add_child(n, rod(float3 { 13.5, y + 1.0, 7.0 * side }, float3 { chest.x, chest.y, chest.z * side }, 0.35, 0.35, s.rope, false))
    let spec = spec_of(n)
    sock(spec, "haul0_f0", float3 { b.x, 0.0, 0.0 })
    sock(spec, "crew0_f0", float3 { b.x + 2.0, 0.0, b.lead })
    return if take == "frog": scaled(spec, 1.25) else: spec

// Timber: a covered wagon on four wheels, hooped canvas with a team stripe, goods at the tail; two ponies side by
// side in draught harness, a pole forward to an evener bar behind them, the driver on the bench.
let WAGON_POLE = 6.0

def cart_wagon(s:SStyle, c:Colours) -> Spec:
    let n = mnode()
    let wr = 6.0
    let y = wr + 2.0
    for([-10.0, 10.0]) x:
        for([1.0, -1.0]) side: siege_wheel(n, float3 { x, wr, 9.6 * side }, wr, 1.6, s)
        add_child(n, rod(float3 { x, wr, -10.6 }, float3 { x, wr, 10.6 }, 0.6, 0.6, s.dark, false))
    let plank = surf("wood_grain", float3_1, 8.0)
    add_child(n, box(float3 { 32.0, 1.4, 15.0 }, plank, float3 { 0.0, y, 0.0 }))
    for([1.0, -1.0]) side: add_child(n, box(float3 { 32.0, 3.0, 0.8 }, plank, float3 { 0.0, y + 2.0, 7.3 * side }))
    // The cover: hoops and canvas over the back two thirds, a team stripe along it.
    let canvas = surf("cloth", html("#e4d8bc"), 3.0)
    for(5) k: add_child(n, ring(7.2, 7.8, s.dark, float3 { -14.0 + float(k) * 5.5, y + 7.5, 0.0 }, float3 { 90.0, 90.0, 0.0 }, float3 { 1.0, 1.2, 1.0 }))
    add_child(n, blob(float3 { 13.0, 8.0, 7.6 }, canvas, float3 { -3.0, y + 7.6, 0.0 }))
    add_child(n, box(float3 { 26.0, 0.4, 15.6 }, canvas, float3 { -3.0, y + 3.2, 0.0 }))
    for([1.0, -1.0]) side: add_child(n, box(float3 { 24.0, 2.0, 0.4 }, s.team, float3 { -3.0, y + 6.0, 7.75 * side }))
    add_child(n, box(float3 { 2.0, 6.0, 1.0 }, s.dark, float3 { 12.5, y + 3.0, 0.0 }))    // the bench's back
    add_child(n, box(float3 { 4.0, 0.8, 12.0 }, plank, float3 { 13.0, y + 3.4, 0.0 }))    // the bench
    let lay = harness_layout("body.pony", c)
    let te = lay.ends[0]
    let hx = 16.0 + WAGON_POLE + 3.0   // (the hitches' x: the bar 3 behind them)
    let spec = spec_of(n)
    sock(spec, "crew0_f0_reach_top", float3 { 12.5, y + 3.8, 0.0 })
    let bar = hx - 3.0
    add_child(n, siege_beam(float3 { 16.0, y, 0.0 }, float3 { bar, te.y, 0.0 }, 1.2, 1.2, s.dark))
    add_child(n, siege_beam(float3 { bar, te.y, -(9.0 + te.z) - 0.5 }, float3 { bar, te.y, 9.0 + te.z + 0.5 }, 1.2, 1.2, s.dark))
    for(2) i:
        let pz = if i == 0: 9.0 else: -9.0
        sock(spec, "haul{i}_f0", float3 { hx - te.x, 0.0, pz })
        for([1.0, -1.0]) side:
            let hitch = float3 { hx, te.y, pz + te.z * side }
            add_child(n, rod(float3 { bar, te.y, hitch.z }, hitch, 0.4, 0.4, s.rope))
            sock(spec, "hitch{i}_" + (if side > 0.0: "near" else: "far"), hitch)
    return spec

// Frogs: a smaller giant snail with wicker panniers over its shell and a team cloth, a frog riding with a goad.
def snail_packs(s:SStyle) -> Spec:
    let n = mnode()
    let beast = add_child(n, mnode())
    beast.scl = float3_1 * 0.62
    let top = swamp_snail(beast, s) * 0.62
    let x0 = -5.0
    for([1.0, -1.0]) side:
        add_child(n, cone(4.6, 3.6, 9.0, s.wicker, float3 { x0, 12.0, 11.0 * side }))   // a pannier each side
        add_child(n, blob(float3 { 3.8, 2.2, 3.8 }, surf("cloth", html("#c8b48a"), 3.0), float3 { x0, 17.0, 11.0 * side }))
        add_child(n, rod(float3 { x0, top - 1.0, 4.0 * side }, float3 { x0, 16.0, 10.0 * side }, 0.4, 0.4, s.rope, false))
        add_child(n, box(float3 { 10.0, 5.0, 0.4 }, s.team, float3 { x0 - 6.0, top - 6.0, 9.5 * side }, float3 { 30.0 * side, 0.0, 0.0 }))
    add_child(n, box(float3 { 12.0, 1.2, 9.0 }, s.dark, float3 { x0 - 2.0, top - 0.4, 0.0 }))   // a little deck on the shell
    return sock(spec_of(n), "crew0_f0_reach_top", float3 { x0 - 2.0, top + 0.2, 0.0 })

// Forest beetles: goods packed into a ball of earth bound with twine and leaves, rolled by a beetle behind.
def goods_ball(s:SStyle) -> Spec:
    let n = mnode()
    let r = 11.0
    let at = float3 { 4.0, r, 0.0 }
    let earth = surf("bld_daub", float3 { 0.62, 0.48, 0.34 }, 6.0)
    add_child(n, blob(float3_1 * r, earth, at))
    for(3) k: add_child(n, ring(r * 0.98, r * 1.04, s.rope, at, float3 { 0.0, float(k) * 60.0, 90.0 }))   // twine bands
    add_child(n, ring(r * 0.98, r * 1.04, s.team, at, float3 { 90.0, 0.0, 0.0 }))   // a team band
    for(7) k:   // (leaves pressed in)
        let a = float(k) * 2.39996
        let d = normalize(float3 { cos(rad(a)) * 0.7, 0.55 + 0.4 * sin(rad(a * 1.7)), sin(rad(a)) * 0.7 })
        add_child(n, blob(float3 { 3.0, 0.5, 1.8 }, s.roof, at + d * r * 0.98, float3 { 0.0, rad(a), 30.0 }))
    add_child(n, cone(0.8, 1.6, 4.0, surf("bld_daub", float3 { 1.05, 0.62, 0.42 }, 6.0), at + float3 { 2.0, r - 0.5, 3.0 }, float3 { 0.0, 0.0, -20.0 }))   // a jar's neck
    add_child(n, blob(float3 { 2.6, 2.0, 2.4 }, surf("cloth", html("#c8b48a"), 3.0), at + float3 { -5.0, r * 0.7, -5.0 }))   // a sack
    return sock(spec_of(n), "crew0_f0_reach", float3 { -12.5, 0.0, 0.0 })

// Spooky spiders: a big bundle wrapped in silk on a bone sledge, dragged on a silk line by a spider in front.
def silk_sledge(s:SStyle) -> Spec:
    let n = mnode()
    for([1.0, -1.0]) side:   // (bone runners, curled at the front)
        add_child(n, rod(float3 { -13.0, 1.0, 5.5 * side }, float3 { 10.0, 1.0, 5.5 * side }, 0.9, 0.9, s.metal))
        add_child(n, rod(float3 { 10.0, 1.0, 5.5 * side }, float3 { 14.0, 4.0, 5.5 * side }, 0.9, 0.6, s.metal))
    for([-9.0, -1.0, 7.0]) x: add_child(n, rod(float3 { x, 1.8, -6.5 }, float3 { x, 1.8, 6.5 }, 0.7, 0.7, s.wood))
    add_child(n, rod(float3 { 14.0, 4.0, -5.5 }, float3 { 14.0, 4.0, 5.5 }, 0.6, 0.6, s.metal))   // a bone across the runners' tips, the line tied to it
    let silk = surf("cloth", html("#ece8f2"), 2.0)
    add_child(n, blob(float3 { 11.0, 7.0, 6.5 }, silk, float3 { -1.0, 8.5, 0.0 }))
    for(6) k: add_child(n, ring(6.4, 6.9, plain(html("#d8d2e4")), float3 { -9.0 + float(k) * 3.2, 8.5, 0.0 }, float3 { 90.0, 90.0, 0.0 }, float3 { 1.0, 1.05, 1.0 }))
    add_child(n, box(float3 { 8.0, 0.4, 7.2 }, s.team, float3 { -1.0, 15.4, 0.0 }))
    let line = surf("cloth", html("#ece8f2"), 2.0)
    line.rope = true   // (tied at both ends: the placement check, C3)
    add_child(n, rod(float3 { 14.0, 4.0, 0.0 }, float3 { 26.0, 8.0, 0.0 }, 0.2, 0.2, line, false))   // the drag line
    return sock(spec_of(n), "crew0_f0", float3 { 30.0, 0.0, 0.0 })
