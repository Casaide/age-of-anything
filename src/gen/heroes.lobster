// ------------------------------------------------------------------ Heroes (src/heroes.gd)
// A race's one hero: the one its prompt names, else one of its hpool picked by its race key; dressed
// over its swordsman (else spearman) line.

let HERO_BASE_SLOTS = [ "infantry", "spear" ]

def signatures_for(cid:string, fid:string) -> [string]:
    let out = []::string
    let sigs = at(lib_heroes, "hero_signatures")
    for(sigs.keys) id, n:
        let who = at(sigs.a[n], "who")
        if has_s(gstrs(who, "creature"), cid) or has_s(gstrs(who, "family"), fid): out.push(id)
    return sorted_strs(out)

def roster_for(cid:string, fid:string) -> [string]:
    let out = signatures_for(cid, fid)
    let min_heroes = as_int(at(at(lib_heroes, "rules"), "min_heroes"))
    let kins = gstrs(at(lib_heroes, "kin"), fid)
    if has(lib_families, fid):
        for(gstrs(family(fid), "hero_kin")) k: kins.push(k)  // (a mod's culture names its own: heroes.json is the game's)
    for(kins) kin:
        for(signatures_for("", kin)) sid:
            if out.length < min_heroes and not has_s(out, sid): out.push(sid)
    return out

def heroes_asked(named:[string], cid:string, fid:string) -> [string]:
    let hpool = roster_for(cid, fid)
    return filter(named) sid: has_s(hpool, sid)

def hero_chosen(race:JV) -> string:
    if has(race, "hero_asked"): return as_str(at(race, "hero_asked"))
    let r = new_rng(hash_text(as_str(at(race, "key")) + "|hero"))
    return rpick(r, roster_for(as_str(at(race, "creature")), as_str(at(race, "family"))))

def strip_edges(s:string) -> string:
    var a = 0
    var b = s.length
    while a < b and s[a] <= ' ': a++
    while b > a and s[b - 1] <= ' ': b--
    return substring(s, a, b - a)

// {signature, name, given}
def hero_pick(key:string, cid:string, fid:string, sid:string) -> JV:
    let r = new_rng(hash_text(key + "|hero|" + sid))
    let s = at(at(lib_heroes, "hero_signatures"), sid)
    let n = at(lib_heroes, "hero_names")
    let cn = gobj(gobj(n, "creatures"), cid)
    let fn_ = gobj(gobj(n, "families"), fid)
    var hpool = gstrs(cn, "names")
    for(gstrs(fn_, "names")) x: hpool.push(x)
    let taken = []::string
    let free = filter(hpool) x: not has_s(taken, x)
    if not free.length:
        for(gstrs(at(s, "who"), "family")) f:
            for(gstrs(gobj(gobj(n, "families"), f), "names")) x:
                if not has_s(taken, x) and not has_s(free, x): free.push(x)
    if free.length: hpool = free
    var titles = []::string
    if has(s, "titles"): titles = gstrs(s, "titles")
    else:
        titles = gstrs(cn, "titles")
        for(gstrs(fn_, "titles")) x: titles.push(x)
    let fmt = as_str(at(at(n, "formats"), rpick(r, gstrs(s, "formats"))))
    let given = if hpool.length: rpick(r, hpool) else: ""
    let epis = gstrs(s, "epithets")
    let epithet = if epis.length: rpick(r, epis) else: ""
    let nicks = gstrs(s, "nicknames")
    let nickname = if nicks.length: rpick(r, nicks) else: ""
    let title = if titles.length: rpick(r, titles) else: ""
    let ordinal = rpick(r, gstrs(n, "ordinals"))
    var name = fmt
    name = replace_string(name, "\{name\}", given)
    name = replace_string(name, "\{epithet\}", epithet)
    name = replace_string(name, "\{nickname\}", nickname)
    name = replace_string(name, "\{title\}", title)
    name = replace_string(name, "\{ordinal\}", ordinal)
    let o = jobj()
    set(o, "signature", jstr(sid))
    set(o, "name", jstr(strip_edges(name)))
    set(o, "given", jstr(if find_string(fmt, "\{name\}") >= 0: given else: ""))
    return o

def hero_slot_def(rules:JV) -> JV?:
    for(glist(rules, "roster")) sd:
        if as_str(at(sd, "role")) == "hero": return sd
    return nil

def parts_on(s:JV, cid:string) -> JV:
    let out = shallow_copy(at(s, "parts"))
    let fit = gobj(gobj(s, "fit"), cid)
    for(fit.keys) slot, n:
        if as_str(fit.a[n]) == "": erase(out, slot)
        else: set(out, slot, fit.a[n])
    return out

def hero_dress(recipe:JV, sid:string, s:JV, name:string, tier:int) -> JV:
    let r = deep_copy(recipe)
    set(r, "slot", jstr("hero"))
    set(r, "role", jstr("hero"))
    set(r, "tier", jint(tier))
    set(r, "hero", jstr(sid))
    set(r, "name", jstr(name))
    erase(r, "noun")
    let kit = jobj()
    let ps = parts_on(s, as_str(at(r, "creature")))
    let rp = at(r, "parts")
    for(sorted_strs(ps.keys)) slot:
        if has(rp, slot): set(kit, slot, at(rp, slot))
        set(rp, slot, at(ps, slot))
    if has(rp, "back") and not has(ps, "back"):
        set(kit, "back", at(rp, "back"))
        erase(rp, "back")
    if kit.keys.length: set(r, "kit", kit)
    set(r, "scale", jint(as_int(at(r, "scale")) * as_int(at(s, "scale")) / 100))
    return r

def unit_entry(recipe:JV, eval:JV, line:[JV]) -> JV:
    let o = jobj()
    set(o, "recipe", recipe)
    set(o, "eval", eval)
    set(o, "line", jarr(line))
    return o

def line_step(age:int, recipe:JV, eval:JV) -> JV:
    let o = jobj()
    set(o, "age", jint(age))
    set(o, "recipe", recipe)
    set(o, "eval", eval)
    return o

def heroes_make(race:JV, rules:JV) -> [JV]:
    let sd = hero_slot_def(rules)
    if not sd: return []
    var base:JV? = nil
    for(HERO_BASE_SLOTS) slot:
        for(glist(race, "units")) u:
            if not base and as_str(at(at(u, "recipe"), "slot")) == slot: base = u
    if not base: return []
    let out = []::JV
    let sid = hero_chosen(race)
    let h = hero_pick(as_str(at(race, "key")), as_str(at(race, "creature")), as_str(at(race, "family")), sid)
    let s = at(at(lib_heroes, "hero_signatures"), sid)
    let line = []::JV
    let tier = as_int(at(sd, "tier"))
    var age = tier
    while age <= gint(rules, "ages", 1):
        let bl = glist(base, "line")
        var step = bl[0]
        for(bl) l:
            if as_int(at(l, "age")) <= age: step = l
        let r = hero_dress(at(step, "recipe"), sid, s, as_str(at(h, "name")), tier)
        line.push(line_step(age, r, evaluate(r, rules, age)))
        age++
    out.push(unit_entry(at(line[0], "recipe"), at(line[0], "eval"), line))
    return out

def heroes_info(race:JV) -> [JV]:
    let out = []::JV
    for(glist(race, "units")) u:
        let r = at(u, "recipe")
        if as_str(at(r, "slot")) == "hero":
            let s = at(at(lib_heroes, "hero_signatures"), as_str(at(r, "hero")))
            let o = jobj()
            set(o, "signature", at(r, "hero"))
            set(o, "name", at(r, "name"))
            set(o, "temper", at(s, "temper"))
            set(o, "aura", at(at(s, "aura"), "text"))
            out.push(o)
    return out
