// The voxel units' art checks (Dominic, 2026-11-03: "voxels should make it easier for us to deterministically create
// our models cleanly... need more tooling and tests?"): numbers for what he caught by eye, so a body that breaks them
// fails here before anyone sees it. Every creature a race can be, bare and in kit:
//   knees     standing, a leg bends no more than its body allows (a biped's straight: "legs bent")
//   skin      every palette of the creature, in every look: no channel clipped, its colour kept (not white, not grey)
//   kit       worn gear (helmets, armour) doesn't swell the silhouette (bears "lose their shape" in armour)
//   apart     no two creatures' silhouettes alike (beetles "look too much like spiders")
//   whole     the filled body is one piece (nothing floating free)
//   lobster voxel_check.lobster -- [report]   (report: the numbers only, no failing)
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
let palettes = at(parse_json(assert read_file("../data/palettes.json")), "skins")
var fails = 0

def fail(what:string):
    print "FAIL: " + what
    fails++

def unit(body:string, skin:float3, pale:float3, gear:[string]) -> vx_unit_def:
    return vx_unit_def { body, body, skin, pale, float3_0, gear, "", false, float3_0, float3_0, float3_0, nil }

def hexc(s:string) -> float3: return vx_hex(s)

// The bodies races are made of (a creature's own body), with their palettes.
let bodies = []::string
let body_skins = []::[string]
let ckeys = creatures.keys
for(ckeys.length) i:
    let c = creatures.a[i]
    if c.kind == J_OBJ and has(c, "body"):
        let b = gstr(c, "body", "").substring(5, max(0, gstr(c, "body", "").length - 5))
        if vx_bodies.get(b) and (find(bodies) x: x == b) < 0:
            bodies.push(b)
            body_skins.push(gstrs(c, "skins"))

// ---- knees: a standing leg's bend (180 - the knee's angle), degrees
def knee_bend(b:vx_body_spec) -> float:
    vx_stand = true
    let p = vx_body_points(b, 0.0, float3_0)
    var worst = 0.0
    for(b.legs) l:
        for([ 1.0, -1.0 ]) side:
            let m = float3 { side, 1.0, 1.0 }
            let hip = vx_where(p, l.pa) + l.a * m
            let foot = l.foot * m  // (standing: every foot where it rests)
            let d = min(magnitude(hip - foot), (l.l1 + l.l2) * 0.999)
            let inner = acos(clamp((l.l1 * l.l1 + l.l2 * l.l2 - d * d) / (2.0 * l.l1 * l.l2), -1.0, 1.0))
            worst = max(worst, 180.0 - inner)
    return worst

// ---- silhouettes: a facing's drawn pixels
def mask(u:vx_unit_def, f:int) -> [bool]:
    vx_set_look(u, 0)
    let g = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_flies(u))
    let cell = vx_cell(g, f)
    return map(cell) c: c.w > 0.0

def area(m:[bool]) -> int: return (filter(m) x: x).length

// A silhouette scaled into an n x n grid over its own box (so a big creature and a small one compare by shape).
def shape_of(m:[bool], n:int) -> [bool]:
    let cw = vx_CELL.x
    var box = int4 { cw, vx_CELL.y, -1, -1 }
    for(m) on, j:
        if on: box = int4 { min(box.x, j % cw), min(box.y, j / cw), max(box.z, j % cw), max(box.w, j / cw) }
    let w = float(box.z - box.x + 1)
    let h = float(box.w - box.y + 1)
    let s = max(w, h)
    return map(n * n) k:
        let x = box.x + int((float(k % n) + 0.5) / float(n) * s - (s - w) * 0.5)
        let y = box.y + int((float(k / n) + 0.5) / float(n) * s - (s - h))
        x >= box.x and x <= box.z and y >= box.y and y <= box.w and m[y * cw + x]

def overlap(a:[bool], b:[bool]) -> float:
    var both = 0
    var either = 0
    for(a) x, i:
        if x and b[i]: both++
        if x or b[i]: either++
    return if either > 0: float(both) / float(either) else: 0.0

// ---- whole: the filled grid's solid voxels in one piece (6 neighbours)
var at_ = []::int
def pieces(u:vx_unit_def) -> [int]:
    vx_set_look(u, 0)
    let g = vx_fill(vx_unit_prims(u, 0.0), vx_size_of(u), vx_flies(u))
    let d = g.dims
    let seen = map(g.grid.length): false
    let sizes = []::int
    for(g.grid) m, i:
        if m >= 0 and not seen[i]:
            sizes.push(0)
            at_ = []
            let todo = [ i ]
            seen[i] = true
            while todo.length:
                let j = todo.pop()
                sizes[sizes.length - 1]++
                at_.push(j)
                let x = j % d.x
                let y = (j / d.x) % d.y
                let z = j / (d.x * d.y)
                for([ int3 { 1, 0, 0 }, int3 { -1, 0, 0 }, int3 { 0, 1, 0 }, int3 { 0, -1, 0 }, int3 { 0, 0, 1 }, int3 { 0, 0, -1 } ]) o:
                    let q = int3 { x, y, z } + o
                    if q.x >= 0 and q.y >= 0 and q.z >= 0 and q.x < d.x and q.y < d.y and q.z < d.z:
                        let k = (q.z * d.y + q.y) * d.x + q.x
                        if g.grid[k] >= 0 and not seen[k]:
                            seen[k] = true
                            todo.push(k)
            if at_.length < 20:
                for(at_) j: print "  {u.body}: a speck of {at_.length}: {vx_mat_names[g.grid[j]]} at {int3 { j % d.x, (j / d.x) % d.y, j / (d.x * d.y) } + g.lo} (voxels)"
    return sizes

// A body's own limit for a check (its file's "check", for a build that's meant: a frog's folded legs), else the rule's.
def vx_check_limit(id:string, k:string, rule:float) -> float:
    let o = parse_json(read_file("../data/voxel/bodies/" + vx_body_of(id).id + ".json") or "\{\}")
    return if has(o, "check") and has(at(o, "check"), k): as_float(at(at(o, "check"), k)) else: rule

def sat(c:float3) -> float:
    let hi = max(c.x, max(c.y, c.z))
    let lo = min(c.x, min(c.y, c.z))
    return if hi > 0.0: (hi - lo) / hi else: 0.0

let KIT = [ "galea", "lorica" ]  // the heaviest worn kit

let OWN = [ "skin", "pale", "mark", "hair", "eye", "mouth", "pink", "tail" ]  // a creature's own materials
let shapes = []::[bool]
let shapes3 = []::[bool]  // three quarters on
for(bodies) id, bi:
    let b = vx_body_of(id)
    let biped = b.arms and b.legs.length == 1
    // knees
    let bend = knee_bend(b)
    let most = vx_check_limit(id, "knees", if biped: 12.0 else: 40.0)
    print "{id}: knees {int(bend)} degrees standing (at most {int(most)})"
    if bend > most and not report: fail("{id}: a standing knee bends {int(bend)} degrees, more than {int(most)}")
    // skin: each palette, each look
    for(body_skins[bi]) pid:
        if has(palettes, pid):
            let cs = gstrs(palettes, pid)
            let raw = hexc(cs[0])
            for(b.looks) look, v:
                // as drawn: the lit band (1.08 of it) under white in every channel, its colour (saturation) kept
                let shown = vx_lifted(raw, b.skin_scale, look)
                let lit = shown * 1.08
                let kept = if sat(raw) > 0.08: sat(shown) / sat(raw) else: 1.0  // (a grey palette is grey)
                if max(lit.x, max(lit.y, lit.z)) > 1.0 or kept < 0.85:
                    print "{id} {pid} look {v}: skin drawn {shown} (lit {lit}, colour kept {int(kept * 100.0)}%)"
                    if not report: fail("{id}: palette {pid} in look {v} clips white in the light or loses its colour")
    // kit: worn gear's silhouette over the bare body's, the worst facing
    if b.arms or b.harness:
        let bare = unit(id, float3_0, float3_0, [])
        let kit = unit(id, float3_0, float3_0, KIT)
        var worst = 0.0
        for([ 0, 2, 4, 6 ]) f: worst = max(worst, float(area(mask(kit, f))) / float(max(1, area(mask(bare, f)))))
        print "{id}: in {KIT} its silhouette is {int(worst * 100.0)}% of its own"
        if worst > 1.3 and not report: fail("{id}: worn kit swells its silhouette to {int(worst * 100.0)}% (at most 130%)")
        // and the creature still shows through it: its own materials' share of what's drawn, the worst facing
        var shows = 1.0
        for([ 1, 3, 5, 7 ]) f:
            mask(kit, f)
            var own = 0
            var all = 0
            for(vx_box.w - vx_box.y + 1) yy: for(vx_box.z - vx_box.x + 1) xx:
                let m = vx_mat[(vx_box.y + yy) * vx_CELL.x + vx_box.x + xx]
                if m >= 0:
                    all++
                    if (find(OWN) n: vx_mat(n) == m) >= 0: own++
            shows = min(shows, float(own) / float(max(1, all)))
        print "{id}: in {KIT} {int(shows * 100.0)}% of it is still the creature"
        let least = vx_check_limit(id, "shows", 0.45)
        if shows < least and not report: fail("{id}: in kit only {int(shows * 100.0)}% of it shows (at least {int(least * 100.0)}%): it loses its shape")
        let ps = pieces(kit)
        if ps.length != 1:
            print "{id}: in kit it fills as {ps.length} pieces, of {ps} voxels"
            if not report: fail("{id}: in kit it is {ps.length} pieces, not one")
        shapes.push(shape_of(mask(bare, 2), 24))
        shapes3.push(shape_of(mask(bare, 3), 24))
    else:
        shapes.push([])
        shapes3.push([])
// apart: each pair of race bodies, side on
for(bodies) a, i:
    for(bodies) b, j:
        if j > i and shapes[i].length and shapes[j].length and vx_body_of(a).id != vx_body_of(b).id:  // (one body in other colours)
            let o = max(overlap(shapes[i], shapes[j]), overlap(shapes3[i], shapes3[j]))
            if o > 0.7:
                print "{a} and {b}: silhouettes {int(o * 100.0)}% alike"
                if o > 0.8 and not report: fail("{a} and {b} look alike side on ({int(o * 100.0)}%, at most 80%)")
print "voxel_check: {bodies.length} bodies, {fails} failed"
if fails: set_exit_code(1)
