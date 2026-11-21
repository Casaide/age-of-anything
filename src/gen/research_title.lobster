// A research's name for side p: its own was data, else for a unit-line upgrade (Creel's line.<slot>.<age>, which has
// none) the unit it gives that side, so the panel never shows a raw id (#162).

def research_title(p:int, r:int) -> string:
    let item = su_research[r]
    let id = rstr(item, "id")
    if has(item, "name"): return rstr(item, "name")
    if not has(item, "line"): return id
    let slot = rstr(item, "line")
    let age = as_int(at(item, "line_age"))
    let k = type_of_slot(p, slot)
    if k >= 0:
        for(glist(su_units[k], "line")) l:
            if as_int(at(l, "age")) == age:
                let name = gstr(at(l, "look"), "name", "")
                if name != "": return "Upgrade to " + name
    var word = capitalize(slot)
    for(glist(su_rules, "roster")) sd:
        if gstr(sd, "slot", "") == slot: word = gstr(sd, "name", word)
    return "{word} line, age {age}"

let STAT_WORDS = [ "HP", "Attack", "Melee armour", "Pierce armour", "Range", "Speed" ]

def stat_row(e:JV) -> [int]:
    let arm = gobj(e, "armour")
    return [ gint(e, "hp", 0), gint(e, "attack", 0), gint(arm, "melee", 0), gint(arm, "pierce", 0), gint(e, "range", 0), gint(e, "speed", 0) ]

// What a research gives side p, in words for its hover card: its effects, or for a line upgrade the unit it turns the
// line into and the numbers that change (#168).
def research_gains(p:int, r:int) -> [string]:
    let item = su_research[r]
    if not has(item, "line"):
        let fx = effect_text(glist(item, "effects"))
        return if fx != "": [ fx ] else: []
    let k = type_of_slot(p, rstr(item, "line"))
    if k < 0: return []
    let age = as_int(at(item, "line_age"))
    var was:JV? = nil
    var now:JV? = nil
    for(glist(su_units[k], "line")) l:
        let a = as_int(at(l, "age"))
        if a == age: now = l
        elif a < age and (not was or as_int(at(was, "age")) < a): was = l
    if not now or not was: return []
    let out = [ "{gstr(at(was, "look"), "name", "")} becomes {gstr(at(now, "look"), "name", "")}" ]
    let v0 = stat_row(was)
    let v1 = stat_row(now)
    let changes = []::string
    for(STAT_WORDS) name, n:
        if v1[n] != v0[n]: changes.push("{name} {v0[n]} to {v1[n]}")
    if changes.length: out.push(concat_string(changes, ", "))
    return out
