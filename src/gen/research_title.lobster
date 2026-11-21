// A research's name for side p: its own from data, else for a unit-line upgrade (Creel's line.<slot>.<age>, which has
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
