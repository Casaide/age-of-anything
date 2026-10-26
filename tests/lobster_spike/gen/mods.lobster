// ------------------------------------------------------------------ mods (src/mods.gd, docs/modding.md)
// A mod is a folder of more data (parts, creatures, cultures, palettes, words, rules, maps, shot looks)
// plus models for the bake, with a manifest (mod.json). Used only when asked for (mods_use, from the
// game's mods:a,b option). Merged over the base data in load order (the manifest's load_order, then
// id), each checked first: a mod that fails is refused with the reason and none of it is used. Each
// mod's signature ("id@version#hash" of its parsed data) goes into the races made with it (the race
// key), as in GDScript. The models are the bake's (Godot's, until step 6c).

let MOD_GAME_VERSION = "0.21"
var mod_roots = ["../../mods", "../../mods_private"]   // (a later folder's copy of a mod wins)
let MOD_DATA_FILES = ["parts.json", "creatures.json", "families.json", "palettes.json", "lexicon.json", "shots.json"]
let MOD_DATA_DIRS = ["rules", "maps"]
let MOD_BASE_ERAS = ["bronze", "medieval", "gunpowder"]

class ModRec:
    id:string
    dir:string
    manifest:JV
    data:JV                      // relative path (parts.json, rules/<id>.json, maps/<id>.json) -> parsed
    sig = ""

var mods_active = []::ModRec
var mods_refused = dictionary<string, string>(8)
var mod_shots = jobj()           // shot looks the mods add (kind -> {tag, speed, arc, len, w, col, glow?})

// Every file under dir, relative, sorted (the bake's leftovers left out).
def mod_files(dir:string, rel:string) -> [string]:
    let out = []::string
    let here = if rel == "": dir else: dir + "/" + rel
    let names, sizes = scan_folder(here, true)
    if not names or not sizes: return out
    let files = []::string
    let dirs = []::string
    for(names) n, k:
        if sizes[k] < 0:
            if n != "." and n != "..": dirs.push(n)
        elif not ends_with(n, ".import") and not ends_with(n, ".uid") and n != ".DS_Store": files.push(n)
    for(sorted_strs(files)) f: out.push(if rel == "": f else: rel + "/" + f)
    for(sorted_strs(dirs)) d:
        for(mod_files(dir, if rel == "": d else: rel + "/" + d)) f: out.push(f)
    return out

def mods_discover() -> dictionary<string, ModRec>:
    let out = dictionary<string, ModRec>(8)
    for(mod_roots) root:
        let names, sizes = scan_folder(root, true)
        if names and sizes:
            let dirs = []::string
            for(names) n, k:
                if sizes[k] < 0 and n != "." and n != "..": dirs.push(n)
            for(sorted_strs(dirs)) d:
                let dir = root + "/" + d
                let text = read_file(dir + "/mod.json")
                if text:
                    let m = parse_json(text)
                    let id = if m.kind == J_OBJ: gstr(m, "id", d) else: d
                    out.set(id, ModRec { id, dir, m, jobj() })
    return out

def mod_check_manifest(id:string, m:JV) -> string:
    if m.kind != J_OBJ: return "mod.json isn\'t a JSON object"
    for(["id", "name", "version", "game_version"]) key:
        if not has(m, key): return "mod.json has no \'{key}\'"
    if gstr(m, "id", "") != id: return "mod.json\'s id \'{gstr(m, "id", "")}\' isn\'t the folder\'s"
    let gv = at(m, "game_version")
    let want = tokenize(if gv.kind == J_STR: gv.s else: godot_float(gv.f), ".", "")
    let have = tokenize(MOD_GAME_VERSION, ".", "")
    if want[0] != have[0] or string_to_int(want[1]) > string_to_int(have[1]): return "made for game version {concat_string(want, ".")}; this is {MOD_GAME_VERSION}"
    return ""

// The mod's data files, parsed; "" or why it can't be read.
def mod_read(rec:ModRec) -> string:
    let root = rec.dir + "/" + gstr(rec.manifest, "data", "data")
    for(mod_files(root, "")) f:
        let base = if has_char(f, '/'): substring(f, 0, find_string(f, "/")) else: ""
        if not (has_s(MOD_DATA_FILES, f) or (has_s(MOD_DATA_DIRS, base) and ends_with(f, ".json"))):
            return "data/{f} can\'t be modded yet (moddable: {concat_string(MOD_DATA_FILES, ", ")}, rules/*.json, maps/*.json)"
        let text = read_file(root + "/" + f)
        if not text: return "data/{f} can\'t be read"
        set(rec.data, f, parse_json(text))
    // (the hash is of the parsed data, not the files' bytes: line endings differ between checkouts)
    rec.sig = "{rec.id}@{gstr(rec.manifest, "version", "")}#{substring(sha256_text(stringify(rec.data)), 0, 8)}"
    return ""

// What's wrong with a mod's data against the data before it (the base and earlier mods), or "".
// (The models' own check, that each new part has a model, is the bake's: Godot's for now.)
def mod_check_data(rec:ModRec, eras:[string]) -> string:
    let d = rec.data
    let slots = []::string
    for(lib_parts.keys) id: push_new(slots, gstr(at(lib_parts, id), "slot", ""))
    let replaces = gstrs(rec.manifest, "replaces")
    let new_parts = []::string
    for(glist(d, "parts.json")) p:
        if p.kind != J_OBJ or gstr(p, "id", "") == "": return "parts.json: a part without an id"
        let id = gstr(p, "id", "")
        let at_ = "parts.json {id}: "
        if has(lib_parts, id) and not has_s(replaces, id): return at_ + "already a part (list it in the manifest\'s \'replaces\' to replace it)"
        if not has_s(slots, gstr(p, "slot", "")): return at_ + "unknown slot \'{gstr(p, "slot", "")}\'"
        let pts = get(p, "points")
        if not pts or (pts.kind != J_INT and pts.kind != J_FLOAT) or as_float(pts) < 0.0: return at_ + "needs whole \'points\' (its price comes from them)"
        let tags = get(p, "tags")
        if not tags or tags.kind != J_ARR: return at_ + "needs \'tags\' (a list)"
        for(gstrs(p, "era")) e:
            if not has_s(eras, e): return at_ + "era \'{e}\' isn\'t the game\'s or in the manifest\'s \'eras\'"
        let tier = gint(p, "tier", 1)
        if tier < 1 or tier > 3: return at_ + "tier must be 1-3"
        let slot = gstr(p, "slot", "")
        if (slot == "body" or slot == "head") and not has(p, "sockets"): return at_ + "a {slot} needs its sockets"
        new_parts.push(id)
    def has_part(id:string) -> bool: return has(lib_parts, id) or has_s(new_parts, id)
    let creatures = gobj(d, "creatures.json")
    let families = gobj(d, "families.json")
    for(creatures.keys) id:
        if not starts_with(id, "_"):
            var c = at(creatures, id)
            if has(c, "extends"):
                if not has(lib_creatures, gstr(c, "extends", "")): return "creatures.json {id}: extends unknown creature \'{gstr(c, "extends", "")}\'"
                c = mod_merge(at(lib_creatures, gstr(c, "extends", "")), c)
            for(["body", "head"]) key:
                if not has_part(gstr(c, key, "")): return "creatures.json {id}: its {key} \'{gstr(c, key, "")}\' isn\'t a part"
            for(gstrs(c, "families")) f:
                if not has(lib_families, f) and not has(families, f): return "creatures.json {id}: unknown culture \'{f}\'"
    for(families.keys) id:
        if not starts_with(id, "_") and has(at(families, id), "extends") and not has(lib_families, gstr(at(families, id), "extends", "")):
            return "families.json {id}: extends unknown culture \'{gstr(at(families, id), "extends", "")}\'"
    let words = gobj(gobj(d, "lexicon.json"), "words")
    for(words.keys) w:
        if not starts_with(w, "_"):
            let e = at(words, w)
            if has(e, "creature") and not has(lib_creatures, gstr(e, "creature", "")) and not has(creatures, gstr(e, "creature", "")):
                return "lexicon.json \'{w}\': unknown creature \'{gstr(e, "creature", "")}\'"
            if has(e, "family") and not has(lib_families, gstr(e, "family", "")) and not has(families, gstr(e, "family", "")):
                return "lexicon.json \'{w}\': unknown culture \'{gstr(e, "family", "")}\'"
            if has(e, "era") and not has_s(eras, gstr(e, "era", "")): return "lexicon.json \'{w}\': unknown era \'{gstr(e, "era", "")}\'"
            if has(e, "era") and not has(e, "note"): return "lexicon.json \'{w}\': an era word needs a \'note\' for hosts that keep that era out"
    for(d.keys) f:
        if starts_with(f, "rules/"):
            let r = at(d, f)
            if not read_file(lib_root + "/" + f) and not has(r, "extends") and not has(r, "roster"):
                return "{f}: neither a game rule to change, nor \'extends\' one, nor a whole rule"
            for(append(gstrs(r, "+era"), gstrs(r, "era"))) e:
                if not has_s(eras, e): return "{f}: unknown era \'{e}\'"
    let mshots = gobj(d, "shots.json")
    for(mshots.keys) k:
        if not starts_with(k, "_"):
            for(["tag", "speed", "col"]) key:
                if not has(at(mshots, k), key): return "shots.json {k}: needs \'{key}\'"
    return ""

def mod_extended(all:JV, e:JV) -> JV:
    if not has(e, "extends"): return e
    let out = mod_merge(at(all, gstr(e, "extends", "")), e)
    return jobj_without(out, "extends")

def mod_apply(rec:ModRec):
    let d = rec.data
    for(glist(d, "parts.json")) p: set(lib_parts, gstr(p, "id", ""), deep_copy(p))
    let cs = gobj(d, "creatures.json")
    for(cs.keys) id:
        if not starts_with(id, "_"): set(lib_creatures, id, mod_extended(lib_creatures, at(cs, id)))
    let fs = gobj(d, "families.json")
    for(fs.keys) id:
        if not starts_with(id, "_"): set(lib_families, id, mod_extended(lib_families, at(fs, id)))
    lib_palettes = mod_merge(lib_palettes, gobj(d, "palettes.json"))
    let lex = gobj(d, "lexicon.json")
    let words = gobj(lex, "words")
    for(words.keys) w:
        if not starts_with(w, "_"): set(lib_lexicon, w, at(words, w))
    for(gstrs(lex, "stopwords")) w: push_new(lib_stopwords, w)
    lib_stopwords = sorted_strs(lib_stopwords)
    let mshots = gobj(d, "shots.json")
    for(mshots.keys) k:
        if not starts_with(k, "_"): set(mod_shots, k, at(mshots, k))
    lib_mods.push(rec.sig)
    lib_part_ids = sorted_strs(lib_parts.keys)
    lib_cands = dictionary<string, [JV]>(31)

// Use exactly these mods (after lib_load): checked against the data before them, in load order.
// Returns the ids in use; mods_refused says why the others weren't.
def mods_use(ids:[string]) -> [string]:
    mods_active = []
    lib_mod_data = []
    lib_mod_dirs = []
    mods_refused = dictionary<string, string>(8)
    mod_shots = jobj()
    let found = mods_discover()
    let picked = []::ModRec
    for(ids) id:
        let rec = found.get(id)
        if not rec: mods_refused.set(id, "not found in {concat_string(mod_roots, ", ")}")
        else:
            let why = mod_check_manifest(id, rec.manifest)
            if why != "": mods_refused.set(id, why)
            else: picked.push(rec)
    insertion_sort(picked) a, b: gint(a.manifest, "load_order", 100) < gint(b.manifest, "load_order", 100) or
                                 (gint(a.manifest, "load_order", 100) == gint(b.manifest, "load_order", 100) and a.id < b.id)
    var eras = copy(MOD_BASE_ERAS)
    for(picked) rec:
        var why = ""
        for(gstrs(rec.manifest, "depends")) dep:
            if why == "" and not (filter(mods_active) a: a.id == dep).length: why = "needs the mod \'{dep}\' loaded before it"
        if why == "": why = mod_read(rec)
        let with_own = append(eras, gstrs(rec.manifest, "eras"))
        if why == "": why = mod_check_data(rec, with_own)
        if why != "": mods_refused.set(rec.id, why)
        else:
            eras = with_own
            mod_apply(rec)
            mods_active.push(rec)
            lib_mod_data.push(rec.data)
            lib_mod_dirs.push(rec.dir + "/" + gstr(rec.manifest, "data", "data"))
    for(mods_refused.get_keys()) id: print "Mod \'{id}\' refused: {mods_refused.get(id, "")}"
    return map(mods_active) a: a.id

