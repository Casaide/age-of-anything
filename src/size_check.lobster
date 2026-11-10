// One size table (data/voxel/sizes.json, a mod's own too): every body's size and its height as drawn, and every mount
// under its rider. This fails when the table and the drawings part: a body redrawn or resized, a mount without a ratio.
//   lobster size_check.lobster -- [report]   (report: the numbers only, no failing)
import std
import vec
import dictionary
import gen.json
import gen.rng
import gen.sha256
import gen.datalib
import gen.identity
import view.voxel

let dirs = [ "../data/voxel", "../mods/scifi_test/data/voxel", "../mods/ww2/data/voxel" ]
vx_load(dirs)
let args = command_line_arguments()
let report = args.length and args[0] == "report"
var fails = 0

def fail(what:string):
    print "FAIL: " + what
    fails++

def bare(body:string) -> vx_unit_def:
    return vx_unit_def { body, body, float3_0, float3_0, float3_0, [], "", false, float3_0, float3_0, float3_0, nil }

// Its height, its length from the side and its width from the front, voxels, standing, at this size.
def drawn(body:string, size:float) -> int, int, int:
    let u = bare(body)
    vx_set_look(u, 0)
    vx_act = ""
    vx_stand = true
    let g = vx_fill(vx_unit_prims(u, 0.0), size, vx_on_zero(u, false))
    var top, side, front = 0, 0, 0
    for(8) f:
        vx_cell(g, f)
        top = max(top, vx_ANCHOR.y - vx_box.y)
        if f == 2: side = vx_box.z - vx_box.x + 1
        if f == 0: front = vx_box.z - vx_box.x + 1
    return top, side, front

// Every body in the game's own data has a line in the table, and is drawn as tall as it says.
for(sorted_strs(assert scan_folder("../data/voxel/bodies", false))) n:
    if ends_with(n, ".json"):
        let id = substring(n, 0, n.length - 5)
        if vx_body_of(id).h <= 0.0: fail("{id}: not in sizes.json")

for(dirs) d:
    let t = parse_json(read_file(d + "/sizes.json") or "\{\}")
    let bs = gobj(t, "bodies")
    for(bs.keys) id, k:
        let b = vx_body_of(id)
        let top, side, front = drawn(id, b.size)
        if report: print "{id}: size {b.size} h {top} side {side} front {front}"
        if not report and has(bs.a[k], "wide") and abs(front - int(gfloat(bs.a[k], "wide", 0.0))) > 1: fail("{id}: {front} voxels wide from the front, the table says {gfloat(bs.a[k], "wide", 0.0)}")
        if not report and abs(float(top) - b.h) > 1.0: fail("{id}: drawn {top} voxels tall at size {b.size}, the table says {b.h}")
    let ms = gobj(t, "mounts")
    let human = vx_body_of("human")
    for(ms.keys) id, k:
        let m = vx_body_of(id)
        let o = ms.a[k]
        let _, side, front = drawn(id, m.ride)
        let seat = m.seat.z * 2.0 * m.ride / human.h
        let along = float(side) / human.h
        if has(o, "span"):
            let span = float(front) / float(side)
            if report: print "{id}: wings {span} of its length"
            if abs(span - gfloat(o, "span", 0.0)) > 0.05: fail("{id}: wings {span} of its length, the table says {gfloat(o, "span", 0.0)}")
        if report: print "{id}: ride {m.ride} seat {seat} length {along} heights of its rider"
        if has(o, "seat") and abs(seat - gfloat(o, "seat", 0.0)) > 0.03: fail("{id}: seat {seat} rider heights, the table says {gfloat(o, "seat", 0.0)}")
        if has(o, "length") and abs(along - gfloat(o, "length", 0.0)) > 0.03: fail("{id}: {along} rider heights long, the table says {gfloat(o, "length", 0.0)}")

// At a high-DPI screen's density (the game's art_density, #358: a Retina Mac's 2.4, its most) every body is its table's
// height in that density's voxels: within the base's one voxel (k of these: the same size in the world) and the one
// voxel of edge every density draws. (Thin tips the base loses come back here: the deer's tines are the most.)
vx_set_res(1.1 * 2.4)
let hi_k = vx_RES / 2.0
for(dirs) d:
    let bs = gobj(parse_json(read_file(d + "/sizes.json") or "\{\}"), "bodies")
    for(bs.keys) id:
        let b = vx_body_of(id)
        let top = drawn(id, b.size)
        let want = floor(b.h * hi_k + 0.5)
        if report: print "{id} at 2.4: h {top}, in the table {want}"
        if not report and abs(float(top) - want) > hi_k + 1.0: fail("{id}: drawn {top} voxels tall at density 2.4, the table says {want}")
vx_set_res(2.0)

// Every mount a race can ride has a ratio, and every creature that can ride has a height.
def mounts_of(c:JV) -> [string]:
    let out = gstrs(c, "mounts")
    let fams = parse_json(assert read_file("../data/families.json"))
    for(gstrs(c, "families")) f: if has(fams, f): for(gstrs(at(fams, f), "mounts")) m: out.push(m)
    return out

let creatures = parse_json(assert read_file("../data/creatures.json"))
for(creatures.keys) name, k:
    let c = creatures.a[k]
    if c.kind == J_OBJ and has(c, "body") and gbool(c, "playable", true):
        let rb = substring(gstr(c, "body", ""), 5, gstr(c, "body", "").length - 5)
        if vx_bodies.get(rb):
            if vx_body_of(rb).h <= 0.0: fail("{name}: {rb} has no height to size a mount from")
            for(mounts_of(c)) m:
                let mc = at(creatures, m)
                let mb = if has(mc, "mount_body"): substring(gstr(mc, "mount_body", ""), 5, gstr(mc, "mount_body", "").length - 5) else: m
                if vx_body_of(mb).ride <= 0.0: fail("{name} on {m}: {mb} has no ride ratio")

if not report and fails == 0: print "sizes hold"
if not report: assert fails == 0
