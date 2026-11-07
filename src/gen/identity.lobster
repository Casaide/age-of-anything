// ------------------------------------------------------------------ Identity (src/identity.gd)
// A race's bonuses, own research and lacks, from its creature's group, its creature and its culture.

let PRICED_ADD = [ "hp", "attack", "speed", "range" ]
let PRICED_PCT = [ "speed", "cost", "train_time" ]

var id_groups = jobj()
var id_buildings = jobj()
var id_cache = dictionary<string, JV>(31)

def id_load(root:string):
    id_groups = at(load_json(root + "/groups.json"), "groups")
    id_buildings = at(lib_data("buildings.json"), "buildings")
    id_cache = dictionary<string, JV>(31)

// Godot's String.capitalize for a snake_case id ("nile" -> "Nile", "sea_folk" -> "Sea Folk").
def capitalize(s:string) -> string:
    let words = filter(tokenize(s, "_", " ")) w: w.length > 0
    return concat_string(map(words) w: uppercase(substring(w, 0, 1)) + lowercase(substring(w, 1, w.length - 1)), " ")

def kind_of(b:JV) -> string:
    if has(b, "kind"): return as_str(at(b, "kind"))
    let parts = []::string
    for(glist(b, "effects")) fx:
        if has(fx, "gather"): parts.push("gather:" + as_str(at(fx, "gather")))
        elif has(fx, "start"): parts.push("start:" + as_str(at(fx, "start")))
        elif has(fx, "tag"): parts.push("tag:" + as_str(at(fx, "tag")) + "/" + as_str(at(fx, "stat")))
        else: parts.push("building:" + jv_str(at(fx, "building")) + "/" + as_str(at(fx, "stat")))
    return concat_string(sorted_strs(parts), ",")

// str() of a value, as GDScript's str() writes it (strings bare, arrays as [a, b]).
def jv_str(v:JV) -> string:
    if v.kind == J_STR: return v.s
    if v.kind == J_ARR:
        let parts = []::string
        for(v.a) x: parts.push(if x.kind == J_STR: "\"" + x.s + "\"" else: jv_str(x))
        return "[" + concat_string(parts, ", ") + "]"
    return stringify(v)

def priced(fx:JV) -> bool:
    if not has(fx, "tag"): return false
    let stat = as_str(at(fx, "stat"))
    if has(fx, "pct"): return has_s(PRICED_PCT, stat)
    return has_s(PRICED_ADD, stat) or starts_with(stat, "armour.") or starts_with(stat, "bonus.")

def identity_of(cid:string, fid:string) -> JV:
    let key = cid + "|" + fid
    let hit = id_cache.get(key)
    if hit: return hit
    let c = creature(cid)
    let f = family(fid)
    let layer_names = []::string
    let layer_from = []::string
    let layer_bonuses = []::[JV]
    let group = gstr(c, "group", "")
    if group != "":
        let g = at(id_groups, group)
        assert glist(g, "bonuses").length == 1
        layer_names.push("group")
        layer_from.push(as_str(at(g, "name")))
        layer_bonuses.push(glist(g, "bonuses"))
    assert glist(c, "bonuses").length == (if group != "": 2 else: 3)
    layer_names.push("creature")
    layer_from.push(as_str(at(c, "plural")))
    layer_bonuses.push(glist(c, "bonuses"))
    layer_names.push("culture")
    layer_from.push(capitalize(fid))
    layer_bonuses.push(glist(f, "bonuses"))
    let bonuses = []::JV
    let kinds = []::string
    for(layer_names) lname, n:
        for(layer_bonuses[n]) b:
            var pick = b
            if has_s(kinds, kind_of(b)):
                assert has(b, "alt")
                pick = at(b, "alt")
            assert not has_s(kinds, kind_of(pick))
            kinds.push(kind_of(pick))
            let o = jobj()
            set(o, "from", jstr(layer_from[n]))
            set(o, "layer", jstr(lname))
            set(o, "text", at(pick, "text"))
            set(o, "effects", jarr(glist(pick, "effects")))
            set(o, "kind", jstr(kind_of(pick)))
            set(o, "price_points", jint(gint(pick, "price_points", 0)))
            set(o, "team", jbool(gbool(b, "team", false)))
            bonuses.push(o)
    let own_research = gstrs(c, "research")
    for(gstrs(f, "research")) r: own_research.push(r)
    let lacks = []::string
    let all_lacks = gstrs(c, "lacks")
    for(gstrs(f, "lacks")) x: all_lacks.push(x)
    for(all_lacks) x:
        if not has_s(lacks, x): lacks.push(x)
    let slots = []::string
    for(lacks) x:
        let b = get(id_buildings, x)
        if b:
            for(gstrs(b, "trains")) s:
                if not has_s(slots, s): slots.push(s)
        elif not has_char(x, '.') and x != "trade": slots.push(x)
    let out = jobj()
    set(out, "bonuses", jarr(bonuses))
    set(out, "research", jstrs(own_research))
    set(out, "lacks", jstrs(lacks))
    set(out, "lacks_slots", jstrs(slots))
    set(out, "ability", gobj(c, "ability"))
    id_cache.set(key, out)
    return out
