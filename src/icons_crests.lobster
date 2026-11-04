// Each culture crest's colours, a line per crest: <ornament> <light> <metal> <dark>. The look's metal, lightened 0.55
// and darkened 0.6. icons.sh casts them into the crests (assets/art/ui/crest_<ornament>.svg).
import std
import dictionary
import gen.json

def hexbyte(v:float) -> string: return number_to_string(round(clamp(v, 0.0, 1.0) * 255.0), 16, 2)

def channel(metal:string, i:int) -> float:
    let n, ok = string_to_int(substring(metal, 1 + i * 2, 2), 16)
    assert ok
    return n / 255.0

let ui = load_json("../data/ui.json")
let base = at(at(ui, "directions"), as_str(at(ui, "direction")))
let ornaments = [ as_str(at(base, "ornament")) ]
let metals = [ as_str(at(base, "metal")) ]
let families = load_json("../data/families.json")
for(families.keys) k:
    let look = at(families, k)
    if look.kind == J_OBJ and has(look, "ui") and has(at(look, "ui"), "ornament"):
        let lookui = at(look, "ui")
        let orn = as_str(at(lookui, "ornament"))
        let metal = gstr(lookui, "metal", metals[0])
        let i = find(ornaments): _ == orn
        if i >= 0:
            metals[i] = metal
        else:
            ornaments.push(orn)
            metals.push(metal)

for(ornaments) orn, i:
    var light = "#"
    var mid = "#"
    var dark = "#"
    for(3) c:
        let v = channel(metals[i], c)
        light += hexbyte(v + (1.0 - v) * 0.55)
        mid += hexbyte(v)
        dark += hexbyte(v * 0.4)
    print "{orn} {light} {mid} {dark}"
