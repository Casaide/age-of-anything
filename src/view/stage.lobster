// ------------------------------------------------------------------ staged data (scenes/art_pixel/creature_kit.gd stage)
// A data file staged into the lib for checks and concept sheets (data/later/*.json, data/creature_kit.json): its
// kits, its parts (a kit body completed), creatures, skins and words. Nothing staged is in play.

def res_path(p:string) -> string: return if starts_with(p, "res://"): "../" + p.substring(6, p.length - 6) else: p

// The staged files' GDScript models with no Lobster model (their parts draw only if a Lobster model has them).
let staged_unmodelled = []::string

def stage_file(path:string):
    let d = load_json(res_path(path))
    let all = gobj(d, "kits")
    for(all.keys) name: kit_register(name, kit_resolved(name, all))
    for(glist(d, "parts")) p:
        let q = deep_copy(p)
        if has(q, "kit"): kit_stubs(q)
        set(lib_parts, rstr(q, "id"), q)
    let cs = gobj(d, "creatures")
    for(cs.keys) id, n: set(lib_creatures, id, cs.a[n])
    let skins = gobj(d, "skins")
    for(skins.keys) s, n: set(at(lib_palettes, "skins"), s, skins.a[n])
    let words = gobj(d, "words")
    for(words.keys) w, n: set(lib_lexicon, w, words.a[n])
    for(gstrs(d, "models")) m:
        if not has_s(staged_unmodelled, m): staged_unmodelled.push(m)
    lib_part_ids = sorted_strs(lib_parts.keys)

// A kit body completed (kit_complete), with the head and leg parts it names made first if the lib lacks them
// (CreatureKit.complete's extras).
def kit_stubs(body:JV):
    let k = kit_kits.get(rstr(body, "kit"))
    if not k: return
    let parts = at(k, "parts")
    for([["head", "head"], ["leg", "leg"], ["hind", "leg"]]) rs:
        if has(parts, rs[0]) and (rs[0] != "head" or has(k, "head")):
            let id = rstr(parts, rs[0])
            if not has(lib_parts, id):
                let p = jobj()
                set(p, "id", jstr(id))
                set(p, "slot", jstr(rs[1]))
                set(p, "tags", jarr([]))
                set(p, "stats", jobj())
                set(p, "points", jint(0))
                set(lib_parts, id, p)
    kit_complete(body)
