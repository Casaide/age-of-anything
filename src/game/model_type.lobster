// The building type whose model a building is drawn with: its own, or for a mod's new building the one it extends,
// along the chain (#58). `buildings` is the merged buildings.json's "buildings".
def model_type(buildings:JV, type:string) -> string:
    var t = type
    for(8):
        let e = gstr(gobj(buildings, t), "extends", "")
        if e == "" or e == t: return t
        t = e
    return t
