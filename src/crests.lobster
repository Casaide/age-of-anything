// Writes the UI's crests: the small embossed ornament each culture's panels and banners wear
// (assets/art/ui/crest_<motif>.svg). Each is drawn once in shapes without colour; the SVG then stamps it as a shadow,
// in metal (a gradient from L light through M to D dark, filled in by icons.sh with the culture's metal) and
// with a fine dark edge, so it reads as something cast or carved, not a flat sticker. Run: lobster crests.lobster
import std

set_print_decimals(1)

def f1(x:float) -> string: return "{x}"

def point(x:float, y:float) -> string: return "{f1(x)},{f1(y)}"

// A pointed leaf (two arcs) centred at cx, cy, pointing along angle (degrees).
def leaf(cx:float, cy:float, length:float, width:float, angle:float) -> string:
    let dx = cos(angle) * length / 2.0
    let dy = sin(angle) * length / 2.0
    let nx = -sin(angle) * width
    let ny = cos(angle) * width
    let start = point(cx - dx, cy - dy)
    return "<path d=\"M{start} Q{point(cx + nx, cy + ny)} {point(cx + dx, cy + dy)} " +
        "Q{point(cx - nx, cy - ny)} {start}Z\"/>"

// A laurel branch from the bottom middle, curving out and up to one side (+1 right, -1 left).
def branch(side:float) -> string:
    let xs = []::float
    let ys = []::float
    for(9) k:
        let t = k / 8.0
        xs.push(100.0 + side * (10.0 + 70.0 * t))
        ys.push(50.0 - 34.0 * sin(t * 180.0 * 0.62) + 6.0 * t)
    let d = concat_string(map(9) k: point(xs[k], ys[k]), " L")
    var out = "<path d=\"M{d}\" fill=\"none\" stroke-width=\"2.6\" stroke-linecap=\"round\" class=\"stem\"/>"
    for(8) i:
        let k = i + 1
        let ang = atan2(float2 { xs[k] - xs[k - 1], ys[k] - ys[k - 1] })
        let size = 15.0 - k * 0.8
        let ox = -sin(ang) * 5.0
        let oy = cos(ang) * 5.0
        out += leaf(xs[k] + ox, ys[k] + oy, size, 3.4, ang + 35.0)
        out += leaf(xs[k] - ox, ys[k] - oy, size, 3.4, ang - 35.0)
    return out

// A tapered bar across the crest: the base most crests sit on.
def bar(y:int, half:int, thick:int) -> string:
    let h2 = half * 0.5
    return "<path d=\"M{100 - half},{y} Q{100.0 - h2},{y - thick} 100,{y - thick} " +
        "Q{100.0 + h2},{y - thick} {100 + half},{y} Q{100.0 + h2},{y + thick} 100,{y + thick} " +
        "Q{100.0 - h2},{y + thick} {100 - half},{y}Z\"/>"

def disc(cx, cy, r) -> string: return "<circle cx=\"{cx}\" cy=\"{cy}\" r=\"{r}\"/>"

def sun() -> string:
    var out = bar(30, 90, 4)
    for(16) k:
        let a = 360.0 * k / 16.0
        let r1 = if k % 2 == 0: 24.0 else: 19.0
        let w = 9.16732  // 0.16 radians
        out += "<path d=\"M{point(100.0 + cos(a - w) * 13.0, 30.0 + sin(a - w) * 13.0)} " +
            "L{point(100.0 + cos(a) * r1, 30.0 + sin(a) * r1)} " +
            "L{point(100.0 + cos(a + w) * 13.0, 30.0 + sin(a + w) * 13.0)}Z\"/>"
    return out + disc(100, 30, 12)

def laurel() -> string: return branch(1.0) + branch(-1.0) + disc(100, 47, 7)

// A key pattern band with a medallion.
def meander() -> string:
    var out = "<rect x=\"14\" y=\"20\" width=\"172\" height=\"3\"/><rect x=\"14\" y=\"38\" width=\"172\" height=\"3\"/>"
    var x = 16
    while x + 16 <= 186:
        if abs(x + 8 - 100) > 18:
            out += "<path d=\"M{x},36 L{x},26 L{x + 12},26 L{x + 12},33 L{x + 6},33 L{x + 6},30 L{x + 9},30 " +
                "L{x + 9},29 L{x + 3},29 L{x + 3},36Z\"/>"
        x += 16
    return out + disc(100, 30, 15)

def reeds() -> string:
    var out = ""
    for([ int3 { 84, 40, -6 }, int3 { 92, 50, -2 }, int3 { 100, 54, 0 }, int3 { 108, 48, 3 }, int3 { 116, 38, 7 } ]) r, k:
        let x = r.x
        let h = r.y
        let lean = r.z
        let top = 56 - h
        out += "<path d=\"M{x - 1.6},56 Q{x + lean * 0.3},{top + h * 0.5} {x + lean},{top} " +
            "Q{x + lean * 0.3 + 2.0},{top + h * 0.5} {x + 1.6},56Z\"/>"
        if k >= 1 and k <= 3:
            out += "<rect x=\"{f1(x + lean * 0.75 - 2.4)}\" y=\"{top + 4}\" width=\"4.8\" height=\"13\" rx=\"2.4\"/>"
    for([ int2 { 60, 1 }, int2 { 140, -1 } ]) p:
        let x = p.x
        let tip = x + 20 * p.y
        out += "<path d=\"M{x},50 m-22,0 a22,7 0 1,0 44,0 a22,7 0 1,0 -44,0 M{x},50 L{tip},47 L{tip},53Z\" fill-rule=\"evenodd\"/>"
    return out + "<path d=\"M30,56 L170,56 L164,58 L36,58Z\"/>"

def rivets() -> string:
    var out = "<rect x=\"36\" y=\"14\" width=\"128\" height=\"32\" rx=\"4\"/>"
    let cap = map(21) k:
        let a = 360.0 * k / 21.0
        let r = if k % 2 == 0: 15.0 else: 13.0
        point(100.0 + cos(a) * r, 30.0 + sin(a) * r)
    out += "<polygon points=\"{concat_string(cap, " ")}\" class=\"raise\"/>"
    out += "<circle cx=\"100\" cy=\"30\" r=\"9\" class=\"raise\"/>"
    for([ 44, 66, 134, 156 ]) x:
        out += "<circle cx=\"{x}\" cy=\"30\" r=\"4\" class=\"raise\"/>"
    return out

def stitch() -> string:
    var out = bar(30, 40, 2)
    out += "<path d=\"M100,6 L130,30 L100,54 L70,30Z\"/><path d=\"M100,16 L118,30 L100,44 L82,30Z\" class=\"raise\"/>"
    for([ int2 { 56, -1 }, int2 { 144, 1 } ]) p:
        let x = p.x
        let flip = p.y
        out += "<path d=\"M{x - 14 * flip},28 L{x + 14 * flip},28 L{x + 14 * flip},32 L{x - 14 * flip},32Z\"/>"
        for(5) k:
            out += "<path d=\"M{x + flip * 14 - 1},31 Q{x + flip * (16 + k)},{42 + k * 2} " +
                "{x + flip * (12 + k * 2)},{52 + k}\" fill=\"none\" stroke-width=\"1.8\" class=\"stem\"/>"
    return out

// An oak leaf: a leaf with three bumps a side.
def oak(cx:float, cy:float, length:float, angle:float) -> string:
    let ux = cos(angle)
    let uy = sin(angle)
    let pts = []::string
    for(26) i:
        let k = if i < 13: i else: 25 - i
        let side = if i < 13: 1.0 else: -1.0
        let t = k / 12.0
        let w = sin(t * 180.0) * (5.5 + 2.2 * sin(t * 180.0 * 6.0)) * length / 28.0
        pts.push(point(cx + ux * (t - 0.5) * length - uy * w * side, cy + uy * (t - 0.5) * length + ux * w * side))
    return "<polygon points=\"{concat_string(pts, " ")}\"/>"

def leaves() -> string:
    var out = ""
    for([ 1, -1 ]) side:
        for([ int3 { 20, -6, -20 }, int3 { 36, 2, 10 }, int3 { 16, 10, 40 } ]) o, k:
            let ang = if side > 0: o.z else: 180 - o.z
            out += oak(100.0 + side * o.x, 30.0 + o.y, [ 30.0, 26.0, 22.0 ][k], float(ang))
    return out + "<ellipse cx=\"100\" cy=\"35\" rx=\"8\" ry=\"10\"/><path d=\"M90,30 Q100,18 110,30Z\" class=\"raise\"/>"

def crown() -> string:
    return bar(48, 60, 3) + "<path d=\"M72,46 L68,18 L84,32 L100,10 L116,32 L132,18 L128,46Z\"/>" + disc(68, 16, 4) +
        disc(100, 8, 4.5) + disc(132, 16, 4) + "<rect x=\"74\" y=\"38\" width=\"52\" height=\"5\" class=\"raise\"/>"

def bones() -> string:
    var out = ""
    for([ 22.0, -22.0 ]) ang:
        let ux = cos(ang) * 40.0
        let uy = sin(ang) * 40.0
        let nx = -sin(ang) * 3.2
        let ny = cos(ang) * 3.2
        out += "<polygon points=\"{point(100.0 - ux + nx, 30.0 - uy + ny)} {point(100.0 + ux + nx, 30.0 + uy + ny)} " +
            "{point(100.0 + ux - nx, 30.0 + uy - ny)} {point(100.0 - ux - nx, 30.0 - uy - ny)}\"/>"
        for([ 1.0, -1.0 ]) s:
            let ex = 100.0 + s * ux
            let ey = 30.0 + s * uy
            out += disc(ex - uy * 0.12, ey + ux * 0.12, 5.5)
            out += disc(ex + uy * 0.12, ey - ux * 0.12, 5.5)
    return out + disc(100, 30, 9)

def lotus() -> string:
    var out = bar(52, 70, 3)
    for([ float2 { -90.0, 40.0 }, float2 { -62.0, 36.0 }, float2 { -118.0, 36.0 }, float2 { -36.0, 30.0 }, float2 { -144.0, 30.0 } ]) p, k:
        out += leaf(100.0 + cos(p.x) * p.y * 0.5, 50.0 + sin(p.x) * p.y * 0.5, p.y, if k == 0: 7.0 else: 6.0, p.x)
    return out

def spiral(cx:float, cy:float, side:float, s:float) -> string:
    let pts = map(40) k:
        let t = k / 39.0
        let a = side * (t * 360.0 * 1.6)
        let r = (3.0 + 13.0 * t) * s
        point(cx + cos(a) * r, cy + sin(a) * r)
    return "<polyline points=\"{concat_string(pts, " ")}\" fill=\"none\" stroke-width=\"{f1(4.5 * s)}\" " +
        "stroke-linecap=\"round\" class=\"stem\"/>"

def cloud() -> string:
    var out = bar(40, 90, 3)
    for([ 1.0, -1.0 ]) side:
        let cx = 100.0 + side * 40.0
        out += spiral(cx, 30.0, side, 1.0)
        out += spiral(cx + side * 30.0, 36.0, side, 0.6)
    return out + disc(100, 30, 10)

// A stepped fret: blocks rising towards a temple door in the middle.
def step() -> string:
    var out = ""
    for([ 1, -1 ]) side:
        var pts = "{100 + side * 20},52"
        for(5) k:
            let x0 = 100 + side * (20 + k * 14)
            let top = 18 + k * 7
            pts += " {x0},{top} {x0 + side * 14},{top}"
        out += "<polygon points=\"{pts} {100 + side * 90},52\"/>"
    return out + "<rect x=\"84\" y=\"10\" width=\"32\" height=\"42\"/><rect x=\"93\" y=\"24\" width=\"14\" height=\"28\" class=\"raise\"/>"

// A longship: a low hull, prow and stern curling up into spirals, round shields along its side, a striped sail.
def longship() -> string:
    var out = "<rect x=\"98\" y=\"2\" width=\"4\" height=\"36\"/><path d=\"M76,6 L124,6 Q128,17 124,28 L76,28 Q72,17 76,6Z\"/>"
    for([ "84", "97.5", "111" ]) x:
        out += "<rect x=\"{x}\" y=\"7\" width=\"5\" height=\"20\" class=\"raise\"/>"
    out += "<path d=\"M22,30 Q40,50 100,50 Q160,50 178,30 L170,30 Q150,40 100,40 Q50,40 30,30Z\"/>"
    out += "<path d=\"M22,30 Q18,24 22,16\" fill=\"none\" stroke-width=\"4\" stroke-linecap=\"round\" class=\"stem\"/>"
    out += "<path d=\"M178,30 Q182,24 178,16\" fill=\"none\" stroke-width=\"4\" stroke-linecap=\"round\" class=\"stem\"/>"
    out += spiral(28.0, 18.0, -1.0, 0.7) + spiral(172.0, 18.0, 1.0, 0.7)
    for(5) k: out += disc(58 + k * 21, 38, 7)
    for(5) k: out += "<circle cx=\"{58 + k * 21}\" cy=\"38\" r=\"2.2\" class=\"raise\"/>"
    return out

def write_crest(name:string, shape:string):
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"200\" height=\"60\" viewBox=\"0 0 200 60\">\n" +
        "<defs>\n<linearGradient id=\"metal\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">\n" +
        "<stop offset=\"0\" stop-color=\"\{L\}\"/><stop offset=\"0.5\" stop-color=\"\{M\}\"/><stop offset=\"1\" stop-color=\"\{D\}\"/>\n" +
        "</linearGradient>\n</defs>\n" +
        "<g transform=\"translate(1.6,2.4)\" fill=\"#000\" stroke=\"#000\" opacity=\"0.55\">{shape}</g>\n" +
        "<g fill=\"url(#metal)\" stroke=\"\{D\}\" stroke-width=\"1.1\" stroke-linejoin=\"round\">{shape}</g>\n" +
        "<g fill=\"none\" stroke=\"\{L\}\" stroke-width=\"0.7\" opacity=\"0.6\" transform=\"translate(-0.5,-0.6)\">{shape}</g>\n</svg>\n"
    assert write_file("../assets/art/ui/crest_{name}.svg", svg)
    print "wrote {name}"

write_crest("sun", sun())
write_crest("laurel", laurel())
write_crest("meander", meander())
write_crest("reeds", reeds())
write_crest("rivets", rivets())
write_crest("stitch", stitch())
write_crest("leaves", leaves())
write_crest("crown", crown())
write_crest("bones", bones())
write_crest("lotus", lotus())
write_crest("cloud", cloud())
write_crest("step", step())
write_crest("longship", longship())
