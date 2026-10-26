// ------------------------------------------------------------------ the bears' helmets (bear_models.gd: "helm.bear_*")
// Each builder is bear_models.gd's of the same name (`_helm_bear_crest` -> helm_bear_crest), line for line;
// its comments are there.

let BEAR_TOP_DROP = 0.8 / 0.9

def helm_bear_crest(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3_1, 3.0)
    let bright = surf("bronze", float3 { 1.15, 1.1, 0.95 }, 2.0)
    add_child(n, dome(float3 { 4.9, 4.5, 4.8 }, bronze, float3 { 0.0, -3.5, 0.0 }))
    add_child(n, ring(4.7, 5.3, bright, float3 { 0.0, -3.4, 0.0 }))
    add_child(n, blob(float3 { 1.8, 0.5, 4.0 }, bronze, float3 { 4.6, -2.8, 0.0 }, float3 { 0.0, 0.0, -14.0 }))
    for([1.0, -1.0]) side:
        add_child(n, blob(float3 { 1.3, 1.6, 1.0 }, bright, float3 { -0.8, 0.0, 3.5 * side }, float3 { 18.0 * side, 0.0, 0.0 }))
        add_child(n, blob(float3 { 1.8, 2.8, 0.6 }, bronze, float3 { 0.2, -5.8, 4.7 * side }, float3 { 0.0, 0.0, 10.0 }))
    add_child(n, blob(float3 { 3.0, 2.8, 4.6 }, bronze, float3 { -3.4, -5.4, 0.0 }))
    add_child(n, rod(float3 { -0.2, 1.0, 0.0 }, float3 { -0.5, 4.0, 0.0 }, 0.55, 0.55, bronze))
    crest(n, col(c, "team"), float3 { -1.5, 4.4, 0.0 }, 13.0, 7.0)
    lift_kids(n, BEAR_TOP_DROP)
    return spec_of(n)

def helm_bear_open(c:Colours) -> Spec:
    let n = mnode()
    let bronze = surf("bronze", float3_1, 3.0)
    let bright = surf("bronze", float3 { 1.15, 1.1, 0.95 }, 2.0)
    let fur = surf("hide", col(c, "skin"), 4.0)
    let ear_in = plain(html("#3a2a24"))
    add_child(n, dome(float3 { 4.8, 4.2, 4.7 }, bronze, float3 { -0.4, -3.2, 0.0 }))
    add_child(n, ring(4.6, 5.1, bright, float3 { -0.4, -3.1, 0.0 }))
    for([1.0, -1.0]) side:
        let at = float3 { -0.9, 1.0, 3.5 * side }
        add_child(n, blob(float3 { 1.6, 0.5, 1.5 }, bright, at + float3 { 0.0, -1.2, 0.0 }, float3 { 22.0 * side, 0.0, 0.0 }))
        add_child(n, blob(float3 { 1.3, 2.0, 1.7 }, fur, at, float3 { 22.0 * side, 0.0, -10.0 }))
        add_child(n, blob(float3 { 0.6, 1.25, 1.0 }, ear_in, at + float3 { 0.75, 0.0, 0.15 * side }, float3 { 22.0 * side, 0.0, -10.0 }))
    add_child(n, blob(float3 { 2.6, 2.2, 4.2 }, bronze, float3 { -3.6, -4.8, 0.0 }))
    add_child(n, rod(float3 { -0.4, 1.0, 0.0 }, float3 { -0.7, 4.0, 0.0 }, 0.55, 0.55, bronze))
    crest(n, col(c, "team"), float3 { -1.7, 4.4, 0.0 }, 13.0, 7.0)
    lift_kids(n, BEAR_TOP_DROP)
    return spec_of(n)

// ------------------------------------------------------------------ this file's parts by id
def build_bears(base:string, c:Colours) -> Spec?:
    switch base:
        case "helm.bear_crest", "helm.bear_crest_3": return helm_bear_crest(c)
        case "helm.bear_open", "helm.bear_open_2", "helm.bear_open_3": return helm_bear_open(c)
        default: return nil
