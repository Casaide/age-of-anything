// ------------------------------------------------------------------ the pack's tables from data (art_pack.gd _names_and_sounds, _ground, _buildings)
// What a match pack told the game besides its pictures, made here from data/ so a match needs no pack: the team
// colours, the sounds and their buses, the creature voices' takes, the building and research names, each
// terrain's two ground colours, which prop stands for which terrain, and each tree cell's species (swamp trees
// near wet ground, else pine or broadleaf by the map's noise: LandView.species_at, map_species.gd). Each table
// is filled only where the pack left it empty.

let PD_WET = [ "swamp", "shallows", "water", "river", "deep_river", "ford", "paddy", "fallow_paddy" ]
let PD_PROPS = [ [ "bugbush", "bush" ], [ "reeds", "reeds" ], [ "stone", "quarry" ], [ "gold", "gold" ], [ "carcass", "carcass" ],
                 [ "field", "crops" ], [ "paddy", "paddy" ], [ "tree", "tree" ] ]

// Godot's String.hash (djb2 over the characters, 32 bits), as a FastNoiseLite seed takes it (a signed int).
def godot_hash(s:string) -> int:
    var h = 5381
    for(s) c: h = ((h << 5) + h + c) & 0xFFFFFFFF
    return if h >= 0x80000000: h - 0x100000000 else: h

def pd_rgb(hex:string) -> float4:
    let c = html(hex)
    return float4 { c.x, c.y, c.z, 1.0 }

// Each tree (or stump) cell's species on the map now loaded (terrain, W, H), "-" elsewhere.
def species_from_map(map_id:string) -> [string]:
    let seed = godot_hash(map_id)
    return map(W * H) c:
        let name = tr_names[terrain[c]]
        if name != "tree" and name != "stump": "-"
        else:
            let cx = c % W
            let cy = c / W
            var kind = ""
            for(min(cy + 3, H) - max(cy - 2, 0)) dy:
                for(min(cx + 3, W) - max(cx - 2, 0)) dx:
                    let y = max(cy - 2, 0) + dy
                    let x = max(cx - 2, 0) + dx
                    if has_s(PD_WET, tr_names[terrain[y * W + x]]): kind = "tree_swamp"
            if kind == "": kind = if fnl_noise2(seed, 0.09, float(cx), float(cy)) > 0.08: "tree_pine" else: "tree_broadleaf"
            kind

// The team colours, if the pack gave none (the lobby draws in them before any match is set up).
def pack_teams():
    if not team_rgb.length:
        for(glist(lib_palettes, "teams")) t: team_rgb.push(pd_rgb(as_str(t)))

// The tables the pack lacks, from data (after the map and the match's types are set up).
def pack_from_data(map_id:string):
    pack_teams()
    let audio = load_json(lib_root + "/audio.json")
    if not sounds.get_keys().length:
        let snd = gobj(audio, "sounds")
        for(snd.keys) name, n:
            let s = snd.a[n]
            sounds.set(name, Sound { gint(s, "takes", 1), float(gint(s, "gap_ms", 0)) / 1000.0, gstr(s, "bus", "Sfx") })
        let bus = gobj(audio, "buses")
        for(bus.keys) name, n: buses.set(name, as_float(bus.a[n]))
        let kinds = gobj(gobj(audio, "voices"), "kinds")
        for(kinds.keys) name, n: voice_takes.set(name, as_int(kinds.a[n]))
    if not building_names.get_keys().length:
        for(bt_name) id, k: building_names.set(k, gstr(at(at(load_json(lib_root + "/buildings.json"), "buildings"), id), "name", id))
    if not research_names.get_keys().length:
        for(research) item, r: research_names.set(r, gstr(su_research[r], "name", item.id))
    if not ground_a.length:
        let tj = gobj(load_json(lib_root + "/terrain.json"), "terrain")
        for(tr_names) id:
            let d = at(tj, id)
            ground_a.push(pd_rgb(gstr(d, "colour", "#808080")))
            ground_b.push(pd_rgb(gstr(d, "colour2", gstr(d, "colour", "#808080"))))
    for(PD_PROPS) pp:
        if prop_of.get(pp[0], "") == "": prop_of.set(pp[0], pp[1])
    if not species.length: species = species_from_map(map_id)
