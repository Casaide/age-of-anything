// Riders and crews as they're drawn (Dominic, 2026-11-06): every pair a race can field, the rider showing above its
// mount or beast, one on a seat, and not lost against what it sits on.
//   visible   of the rider's pixels alone, how many still show on the whole figure (worst facing)
//   seats     how much of one crew member's body lies inside the next one's (two bears in one howdah)
//   ratio     a crew member's height against its beast's (a frog lost on a heron, a bear crushing a mantis)
//   rim       of 8 directions from a seat, how many meet the howdah's wall (a body rising from a solid crate looks stuck in it)
//   fit       how much of the crew hangs outside the deck the table gives (a bear on a howdah)
//   contrast  every skin a crew comes in against the deck under it (a brown rat on a brown crate)
//   bulk      a rider against its mount, in pixels drawn (a frog bigger than its newt)
//   lobster rider_check.lobster -- [report]   (report: the numbers only, no failing)
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.voxel

vx_load([ "../data/voxel" ])
let args = command_line_arguments()
let report = args.length and args[0] == "report"
let creatures = parse_json(assert read_file("../data/creatures.json"))
let families = parse_json(assert read_file("../data/families.json"))
let palettes = at(parse_json(assert read_file("../data/palettes.json")), "skins")
let MIN_VISIBLE = 0.55
let MAX_SHARED = 0.2
let CREW_BEAST = float2 { 0.35, 0.7 }  // a crew member's height against its beast's
let MIN_RIM = 6
let MAX_OVER = 0.1
let MIN_CONTRAST = 0.14
let MAX_BULK = 0.85
var fails = 0

def fail(what:string):
    print "FAIL: " + what
    fails++

def body_of(c:JV) -> string: return substring(gstr(c, "body", ""), 5, gstr(c, "body", "").length - 5)

def plain(body:string, mount:string) -> vx_unit_def:
    return vx_unit_def { body, body, float3_0, float3_0, float3_0, [], mount, false, float3_0, float3_0, float3_0, nil }

def still():
    vx_act = ""
    vx_stand = true
    vx_shadows = false

// The worst facing's share of the rider's pixels that show on the whole figure.
def visible(whole:vx_shape, rider:vx_shape) -> float:
    var worst = 1.0
    for(8) f:
        let r = copy(vx_cell(rider, f))
        let w = vx_cell(whole, f)
        var n, seen = 0, 0
        for(r) c, i:
            if c.w > 0.0:
                n++
                if w[i].w > 0.0 and magnitude(float3 { c.x - w[i].x, c.y - w[i].y, c.z - w[i].z }) < 0.15: seen++
        if n > 0: worst = min(worst, float(seen) / float(n))
    return worst

// Its pixels, summed over the facings.
def pixels(g:vx_shape) -> float:
    var n = 0
    for(8) f: for(vx_cell(g, f)) c: if c.w > 0.0: n++
    return float(n)

def mounted(name:string, rb:string, mb:string):
    still()
    let u = plain(rb, mb)
    vx_set_look(u, 0)
    let b = vx_body_of(rb)
    let all = vx_unit_prims(u, 0.0)
    let mu = plain(mb, "")
    let m = []::vx_prim
    vx_whole_body(m, mu, vx_body_of(mb), vx_body_points(vx_body_of(mb), 0.0, float3_0), 0.0, 0.0, [])
    let rider = all.slice(m.length, all.length - m.length)
    let v = visible(vx_fill(all, b.size, true), vx_fill(rider, b.size, true))
    let bulk = pixels(vx_fill(rider, b.size, true)) / pixels(vx_fill(all.slice(0, m.length), b.size, true))
    if report: print "ride {name} on {mb}: visible {v} bulk {bulk}"
    if not report and bulk > MAX_BULK: fail("{name} on {mb}: the rider is {int(bulk * 100.0)}% of its mount, drawn (at most {int(MAX_BULK * 100.0)}%; a rat on a capybara is 55%)")
    if not report and v < MIN_VISIBLE: fail("{name} on {mb}: only {int(v * 100.0)}% of the rider shows (at least {int(MIN_VISIBLE * 100.0)}%)")

def solid(g:vx_shape, x:int, y:int, z:int) -> bool:
    let p = int3 { x, y, z } - g.lo
    if p.x < 0 or p.y < 0 or p.z < 0 or p.x >= g.dims.x or p.y >= g.dims.y or p.z >= g.dims.z: return false
    return g.grid[(p.z * g.dims.y + p.y) * g.dims.x + p.x] >= 0

// Of 8 directions from the first seat, just above it, how many meet something solid within the deck's reach.
def rim_of(g:vx_shape, b:vx_body_spec) -> int:
    let s = vx_RES * b.size
    let at = b.seats[0] * s
    var n = 0
    for(8) d:
        var hit = false
        for(int(12.0 * s)) r:
            let x = int(floor(at.x + cos(float(d) * 45.0) * float(r + 2)))
            let y = int(floor(at.y + sin(float(d) * 45.0) * float(r + 2)))
            if solid(g, x, y, int(floor(at.z + 0.5 * s))): hit = true
        if hit: n++
    return n

// The share of the crew's voxels outside the deck's half sizes round its seats (the table's, body units).
def over_deck(g:vx_shape, b:vx_body_spec) -> float:
    if b.deck.x <= 0.0: return 0.0
    let s = vx_RES * b.size
    var total, out = 0, 0
    for(g.grid) m, i:
        if m >= 0:
            total++
            let p = g.lo + int3 { i % g.dims.x, (i / g.dims.x) % g.dims.y, i / (g.dims.x * g.dims.y) }
            let cy = b.seats[0].y * s
            if abs(float(p.x)) > b.deck.x * s or abs(float(p.y) - cy) > b.deck.y * s: out++
    return float(out) / float(max(total, 1))

def crewed(name:string, beast:string, cbody:string):
    still()
    let b = vx_body_of(beast)
    let c = plain(cbody, "")
    let u = vx_unit_def { beast, beast, b.style_cols[0], b.style_cols[1], b.style_cols[2], [], "", false, float3_0, float3_0, float3_0, c }
    vx_set_look(u, 0)
    let all = vx_unit_prims(u, 0.0)
    let crew = []::vx_prim
    vx_crew_prims(crew, u, c, 0.0)
    let v = visible(vx_fill(all, b.size, true), vx_fill(crew, b.size, true))
    // the seats, one at a time: how much of a crew member lies inside the next
    var shared = 0.0
    let seats = b.seats
    if seats.length > 1 and vx_body_of(cbody).crew_seats != 1:
        let grids = map(seats) at:
            b.seats = [ at ]
            let one = []::vx_prim
            vx_crew_prims(one, u, c, 0.0)
            vx_fill(one, b.size, true)
        b.seats = seats
        let g0, g1 = grids[0], grids[1]
        var inside, total = 0, 0
        for(g0.grid) m0, i:
            if m0 >= 0:
                total++
                let p = g0.lo + int3 { i % g0.dims.x, (i / g0.dims.x) % g0.dims.y, i / (g0.dims.x * g0.dims.y) } - g1.lo
                if p.x >= 0 and p.y >= 0 and p.z >= 0 and p.x < g1.dims.x and p.y < g1.dims.y and p.z < g1.dims.z:
                    if g1.grid[(p.z * g1.dims.y + p.y) * g1.dims.x + p.x] >= 0: inside++
        shared = float(inside) / float(max(total, 1))
    let ratio = vx_body_of(cbody).h * vx_body_of(cbody).crew_k / b.h
    let bg = vx_fill(vx_unit_prims(vx_unit_def { beast, beast, b.style_cols[0], b.style_cols[1], b.style_cols[2], [], "", false, float3_0, float3_0, float3_0, nil }, 0.0), b.size, true)
    let rim = rim_of(bg, b)
    let over = over_deck(vx_fill(crew, b.size, true), b)
    if report: print "crew {name} on {beast}: visible {v} ratio {ratio} shared {shared} rim {rim} over {over}"
    if not report:
        if ratio < CREW_BEAST.x or ratio > CREW_BEAST.y: fail("{name} on {beast}: crew {int(ratio * 100.0)}% of the height of its beast ({int(CREW_BEAST.x * 100.0)}-{int(CREW_BEAST.y * 100.0)}%)")
        if rim < MIN_RIM: fail("{name} on {beast}: {rim} of 8 directions meet a wall round the seat (at least {MIN_RIM})")
        if over > MAX_OVER: fail("{name} on {beast}: {int(over * 100.0)}% of the crew hangs outside the deck (at most {int(MAX_OVER * 100.0)}%)")
        if v < MIN_VISIBLE: fail("{name} on {beast}: only {int(v * 100.0)}% of the crew shows (at least {int(MIN_VISIBLE * 100.0)}%)")
        if shared > MAX_SHARED: fail("{name} on {beast}: two crew {int(shared * 100.0)}% inside each other (at most {int(MAX_SHARED * 100.0)}%)")

def contrast(name:string, beast:string, c:JV):
    let deck = vx_body_of(beast).style_cols[0]
    for(gstrs(c, "skins")) s:
        let d = magnitude(vx_hex(gstrs(palettes, s)[0]) - deck)
        if report: print "contrast {s} on {beast}: {d}"
        if not report and d < MIN_CONTRAST: fail("{name} ({s}) on {beast}: colour {int(d * 100.0)} from its deck (at least {int(MIN_CONTRAST * 100.0)})")

// Every pair a race can field: any mount a prompt can ask for, less those that won't carry it; its war beast.
for(creatures.keys) name, k:
    let c = creatures.a[k]
    if c.kind == J_OBJ and has(c, "body") and gbool(c, "playable", true):
        let rb = body_of(c)
        let ms = filter(creatures.keys) m: at(creatures, m).kind == J_OBJ and gbool(at(creatures, m), "mount", false)  // (a prompt can ask for any)
        if not has(c, "fused_mount"):
            for(ms) m:
                let mc = at(creatures, m)
                if m != name and (find(gstrs(mc, "not_ridden_by")) x: x == name) < 0:
                    mounted(name, rb, if has(mc, "mount_body"): substring(gstr(mc, "mount_body", ""), 5, gstr(mc, "mount_body", "").length - 5) else: m)
        let beasts = if has(c, "war_beast"): [ gstr(c, "war_beast", "") ] else: map(gstrs(c, "families")) f: gstr(at(families, f), "war_beast", "")
        for(beasts) w: crewed(name, "siege.beast." + w, if has(c, "fused_mount"): "human" else: rb)
        for(beasts) w: contrast(name, "siege.beast." + w, c)

if not report and fails == 0: print "riders hold"
if not report: assert fails == 0
