// ------------------------------------------------------------------ a part's model by id (unit_models.gd build)
// Part ids may carry a hold after "@" (a body posed for its weapon: "body.frog@throw"; a third part, the
// pose it rests in), a sling ("shield.bottlecap@slung") and, after "~", the body it's worn on or cut by.
// Each model file has a build_<file>(base, colours) that knows its own parts (nil for the rest).

def sling_of(id:string) -> string:
    let at = find_string(id, "@")
    if at < 0: return ""
    let after = id.substring(at + 1, id.length - at - 1)
    let end = find_string(after, "@")
    let first = if end >= 0: after.substring(0, end) else: after
    return if starts_with(first, "slung"): "@" + first else: ""

def build_model(id:string, c:Colours) -> Spec?:
    let sl = sling_of(id)
    if sl != "":
        let inner = build_model(id.substring(0, find_string(id, "@")), c)
        if not inner: return nil
        return slung(inner, sl)
    let tilde = find_string(id, "~")
    let own = if tilde >= 0: id.substring(0, tilde) else: id
    let bits = tokenize(own, "@", "")
    hold = if bits.length > 1: bits[1] else: "low"
    rest = if bits.length > 2: bits[2] else: ""
    let base = bits[0]
    // each model file's parts (model/all.lobster imports them; a file answers nil for parts it doesn't have)
    return build_units(base, c) or build_units2(base, c) or build_units3(base, c) or build_units4(base, c) or build_units5(base, c) or
           build_kit(base, c) or build_siege(base, c) or build_heroes(base, c) or build_bears(base, c)

def has_model(id:string, c:Colours) -> bool: return build_model(id, c) != nil
