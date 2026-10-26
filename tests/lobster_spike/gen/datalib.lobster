// ------------------------------------------------------------------ DataLib (src/data_lib.gd)
// The data contract, read once: parts by id, creatures, cultures, uniques, heroes, palettes, the
// lexicon, resources, cost curves. Mods aren't read yet (src/mods.gd: later).

var lib_root = "data"
var lib_parts = jobj()
var lib_part_ids:[string] = []           // sorted
var lib_creatures = jobj()
var lib_families = jobj()
var lib_uniques = jobj()
var lib_heroes = jobj()
var lib_palettes = jobj()
var lib_lexicon = jobj()
var lib_stopwords:[string] = []          // sorted
var lib_resources:[string] = []
var lib_curves = dictionary<string, [int]>(17)
var lib_cands = dictionary<string, [JV]>(31)   // slot|eras -> candidates
var lib_mods:[string] = []

def has_s(xs:[string], s:string) -> bool:
    for(xs) x:
        if x == s: return true
    return false

def sorted_strs(xs:[string]) -> [string]:
    let out = copy(xs)
    insertion_sort(out) a, b: a < b
    return out

def lib_load(root:string):
    lib_root = root
    lib_parts = jobj()
    for(load_json(root + "/parts.json").a) p: set(lib_parts, as_str(at(p, "id")), p)
    lib_creatures = load_json(root + "/creatures.json")
    lib_families = load_json(root + "/families.json")
    lib_uniques = at(load_json(root + "/uniques.json"), "themes")
    lib_heroes = load_json(root + "/heroes.json")
    lib_palettes = load_json(root + "/palettes.json")
    let lex = load_json(root + "/lexicon.json")
    lib_lexicon = at(lex, "words")
    lib_stopwords = sorted_strs(gstrs(lex, "stopwords"))
    lib_resources = []
    for(at(load_json(root + "/resources.json"), "resources").a) r: lib_resources.push(as_str(at(r, "id")))
    let cc = load_json(root + "/cost_curves.json")
    for(cc.keys) id, n: lib_curves.set(id, map(at(cc.a[n], "permille").a) v: as_int(v))
    lib_kit_parts(root)
    lib_part_ids = sorted_strs(lib_parts.keys)

// Creature-kit bodies (the bears): their head and leg parts made, as CreatureKit.complete() makes
// them. (What it fills in on the body itself, sockets, legs and poses, is for the views: 6b.)
def lib_kit_parts(root:string):
    let text = read_file(root + "/creature_kit.json")
    if not text: return
    let kits = at(parse_json(text), "kits")
    for(sorted_strs(lib_parts.keys)) id:
        let p = at(lib_parts, id)
        if has(p, "kit"):
            let k = at(kits, as_str(at(p, "kit")))
            let kp = at(k, "parts")
            let made = []::JV
            if has(k, "head"): made.push(made_part(as_str(at(kp, "head")), "head"))
            made.push(made_part(as_str(at(kp, "leg")), "leg"))
            if has(kp, "hind"): made.push(made_part(as_str(at(kp, "hind")), "leg"))
            for(made) m:
                let mid = as_str(at(m, "id"))
                if not has(lib_parts, mid): set(lib_parts, mid, m)

def made_part(id:string, slot:string) -> JV:
    let o = jobj()
    set(o, "id", jstr(id))
    set(o, "slot", jstr(slot))
    set(o, "tags", jarr([]))
    set(o, "stats", jobj())
    set(o, "points", jint(0))
    return o

def load_rules(id:string) -> JV: return load_json(lib_root + "/rules/" + id + ".json")

def part(id:string) -> JV:
    let p = get(lib_parts, id)
    if not p:
        print "Unknown part: " + id
        assert false
    return p or jobj()

def creature(id:string) -> JV: return at(lib_creatures, id)
def family(id:string) -> JV: return at(lib_families, id)

def curve(id:string, points:int) -> int:
    let table = lib_curves.get(id)
    assert table
    if table:
        assert points >= 0 and points < table.length
        return table[points]
    return 0

def era_ok(p:JV, eras:[string]) -> bool:
    if not has(p, "era"): return true
    for(glist(p, "era")) e:
        if has_s(eras, as_str(e)): return true
    return false

// Parts for a slot allowed in the given eras, in sorted id order (innate parts are grown, never picked).
def candidates(slot:string, eras:[string]) -> [JV]:
    let key = slot + "|" + concat_string(eras, ",")
    let hit = lib_cands.get(key)
    if hit: return hit
    let out = []::JV
    for(lib_part_ids) id:
        let p = at(lib_parts, id)
        if gstr(p, "slot", "") == slot and era_ok(p, eras) and not gbool(p, "innate", false): out.push(p)
    lib_cands.set(key, out)
    return out

def creature_ids(flag:string) -> [string]:
    let ids = sorted_strs(lib_creatures.keys)
    if flag == "": return ids
    return filter(ids) id: gbool(at(lib_creatures, id), flag, false)

def architecture(race:JV) -> string:
    let c = creature(as_str(at(race, "creature")))
    let f = family(as_str(at(race, "family")))
    return gstr(c, "architecture", gstr(f, "architecture", "thatch"))
