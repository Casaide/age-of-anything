// The game's headless checks (tests/run_tests.gd), on the Lobster generator, pricing, identity, heroes,
// mods and the sim's data loaders: data, determinism, bounds, prompts, healers, siege, swordsmen, the
// new lines, the cat mount, audio data, the tech tree's data, identity, heroes, mods. Same checks and
// messages where they carry over; "N checks, M failed" at the end, exit code 1 on a failure.
// Run from src:  lobster run_tests.lobster [-- part:i/n]
//   part:i/n runs only every n-th check group from the i-th (0-based), for running pieces side by side.
//
// Left out (Godot only, or the Lobster port has no such piece yet):
// - _test_scripts_parse: loads every .gd scene and view script; GDScript files, nothing to do with Lobster.
// - _test_placement, _test_composer and the view half of _test_cat_poses, "<part> has a model" and "mods: a .glb
//   part builds": the composed units are gone (voxel units: voxel_check.lobster and voxel_proto.lobster check them);
//   the generator half of the cat checks (who rides cats) is here.
// - _test_paths: game/paths.lobster plans on the running match's map (ground_blocked reads the sim's
//   cells) and is part of the game's drawing; there's no planner taking a blocked function to drive.
// - The tech tree page's node checks (TreeModel.build): game/techtree.lobster's build_tree is drawn by
//   the game (lobby_text, ui_*, the running match's su_* state); the data half of _test_tech_tree is
//   here (planned items in the plan, the sim's loaders skip them, rosters and buildings agree).
// - "mods: a race made with mods we don't have is spotted" (Mods.missing): no Lobster counterpart.
// - "mods: no_model refused": parts have no models (their looks are the voxel kit's); the broken fixtures are checked.
// - "mods: the pulse rifle fires the mod's shot" (CombatFx.shot_kind): shot_kind_of is in game.lobster;
//   checked here as the data it reads: the mod's shot "pulse" is called by a tag the rifle's eval has.
// - "sound take loads" / "music stem loads": the WAVs and OGGs are read from their headers (length in
//   seconds), not through Godot's AudioStream loaders.
import from "../creel/src"
import std
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import lua.parse
import gen.mods
import lib.consts
import lib.fixed
import lib.tokens
import lib.state
import lib.flow
import lib.spatial
import lib.orders
import lib.movement
import lib.steering
import lib.fog
import lib.map
import lib.economy
import lib.tech
import lib.combat
import lib.siege
import lib.eco_bot
import lib.garrison
import lib.heal
import lib.heroes
import lib.match
import lib.trade
import lib.recipes
import lib.carry
import lib.animals
import lib.bridges
import lib.walls
import lib.abilities
import lib.trails
import lib.commands
import lib.ai_cfg
import lib.scout
import lib.land
import lib.expand
import lib.bot
import lib.walls_ai
import lib.world
import hooks.active
import hooks.rules
import gen.setup
import gen.race_to_types
import gen.modes
import gen.start
import lua.lua
import lua.api
import gen.reset
import view.facing
import game.relief
import vec
import game.cursor_images
import gl
import game.window_mode
import game.topbar_fit
import game.text_field
import game.fog_look
import color
import texture
import view.atmosphere
import game.mood

let DATA = "../data"
let PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "flying greeks with wings",
                "ww2 americans riding mongolian ponies", "giant spiders", "tiny vikings", "spooky beetle knights",
                "pegasus riding spartans", "", "blorp zang wibble" ]
let RULE_IDS = [ "default", "bronze", "anything" ]
let SKIN_TEAM_GAP = 30  // CIE76 distance between a skin's main colour and every team colour

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

// ---- helpers

def all_of(xs, fun):
    for(xs) x:
        if not fun(x): return false
    return true

def strs_eq(a:[string], b:[string]) -> bool:
    if a.length != b.length: return false
    for(a) x, n:
        if x != b[n]: return false
    return true

def contains_text(s:string, sub:string) -> bool: return find_string(s, sub) >= 0

def units_of(race:JV) -> [JV]: return glist(race, "units")
def recipe_of(u:JV) -> JV: return at(u, "recipe")
def slot_of(u:JV) -> string: return rstr(recipe_of(u), "slot")
def role_of(u:JV) -> string: return rstr(recipe_of(u), "role")
def line_of(u:JV) -> [JV]: return glist(u, "line")
def last_step(u:JV) -> JV:
    let l = line_of(u)
    return l[l.length - 1]
def parts_of(r:JV) -> JV: return at(r, "parts")
def part_ids(r:JV) -> [string]: return map(parts_of(r).a) v: as_str(v)
def part_at(r:JV, slot:string) -> string: return gstr(parts_of(r), slot, "")
def tags_of(id:string) -> [string]: return gstrs(part(id), "tags")
def ival(o:JV, path:string) -> int:  // an int down a dotted path ("eval.armour.pierce" style keys)
    var v = o
    for(tokenize(path, ".", "")) k: v = at(v, k)
    return as_int(v)
def total_cost(c:JV) -> int:
    var t = 0
    for(c.a) v: t += as_int(v)
    return t
def notes_of(race:JV) -> [string]: return gstrs(race, "notes")
def lacks_of(race:JV) -> [string]: return gstrs(race, "lacks")

// The race's first unit of a role (_unit): asserts there is one.
def unit_of(race:JV, role:string) -> JV:
    for(units_of(race)) u:
        if role_of(u) == role: return u
    print "no {role} unit"
    assert false
    return jobj()

// Every line step's recipe of the units passing `keep`, as JSON (the "other lines as they were" checks).
def lines_json(race:JV, keep) -> string:
    let outer = []::string
    for(units_of(race)) u:
        if keep(u): outer.push("[" + concat_string(map(line_of(u)) l: stringify(at(l, "recipe")), ",") + "]")
    return "[" + concat_string(outer, ",") + "]"

def without_slots(rules:JV, slots:[string]) -> JV:
    let r = deep_copy(rules)
    set(r, "roster", jarr(filter(glist(r, "roster")) sd: not has_s(slots, rstr(sd, "slot"))))
    return r

def fresh_lib():
    lib_load(DATA)
    id_load(DATA)

// A world to read the sim's loaders from (World.new): one match set up on flat_test.
def fresh_world(races:[JV], rules:JV):
    reset_world()
    setup_match(20261013, "flat_test", races, rules, [])

// ---- colours (the skins against the team colours)

def hex_colour(s0:string) -> [float]:
    let s = if starts_with(s0, "#"): substring(s0, 1, s0.length - 1) else: s0
    return map(3) c:
        let v, ok = string_to_int(substring(s, c * 2, 2), 16)
        assert ok
        float(v) / 255.0

def srgb_linear(c:float) -> float: return if c < 0.04045: c / 12.92 else: pow((c + 0.055) / 1.055, 2.4)
def lab_f(t:float) -> float: return if t > 0.008856: pow(t, 1.0 / 3.0) else: 7.787 * t + 16.0 / 116.0

def lab(rgb:[float]) -> [float]:
    let l = map(rgb) c: srgb_linear(c)
    let x = (0.4124 * l[0] + 0.3576 * l[1] + 0.1805 * l[2]) / 0.95047
    let y = 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
    let z = (0.0193 * l[0] + 0.1192 * l[1] + 0.9505 * l[2]) / 1.08883
    return [ 116.0 * lab_f(y) - 16.0, 500.0 * (lab_f(x) - lab_f(y)), 200.0 * (lab_f(y) - lab_f(z)) ]

def lab_distance(a:string, b:string) -> float:
    let la = lab(hex_colour(a))
    let lb = lab(hex_colour(b))
    return sqrt((la[0] - lb[0]) * (la[0] - lb[0]) + (la[1] - lb[1]) * (la[1] - lb[1]) + (la[2] - lb[2]) * (la[2] - lb[2]))

// ---- sound files (their length in seconds, from the headers)

def le_int(s:string, at_:int, n:int) -> int:
    var v = 0
    var k = n - 1
    while k >= 0:
        v = (v << 8) | (s[at_ + k] & 255)
        k--
    return v

def wav_seconds(path:string) -> float:
    let s = read_file(path, true)
    if not s or s.length < 12 or substring(s, 0, 4) != "RIFF": return -1.0
    var at_ = 12
    var byte_rate = 0
    while at_ + 8 <= s.length:
        let id = substring(s, at_, 4)
        let size = le_int(s, at_ + 4, 4)
        if id == "fmt ": byte_rate = le_int(s, at_ + 16, 4)
        if id == "data" and byte_rate > 0: return float(size) / float(byte_rate)
        at_ += 8 + size + (size & 1)
    return -1.0

def ogg_seconds(path:string) -> float:
    let s = read_file(path, true)
    if not s or s.length < 64 or substring(s, 0, 4) != "OggS": return -1.0
    let v = find_string(s, "vorbis")
    if v < 0: return -1.0
    let rate = le_int(s, v + 11, 4)
    var k = s.length - 14
    while k >= 0 and substring(s, k, 4) != "OggS": k--
    if k < 0 or rate <= 0: return -1.0
    return float(le_int(s, k + 6, 8)) / float(rate)

// ------------------------------------------------------------------ the checks

def g_data():
    for(load_json(DATA + "/parts.json").a) p:  // (a creature-kit body gets its shapes from the kit: CreatureKit.complete, the view's)
        expect(has(p, "slot") and (has(p, "shapes") or has(p, "kit")), "part {gstr(p, "id", "?")} has slot and shapes")
    for(lib_part_ids) id:
        let p = at(lib_parts, id)
        expect(has(p, "slot"), "part {id} has a slot")  // (kit parts made by DataLib: the view's shapes are Godot's)
        if gstr(p, "slot", "") == "body" and has(p, "legs"): expect(has(lib_parts, rstr(at(p, "legs"), "part")), "body {id} leg part exists")
    let skins = at(lib_palettes, "skins")
    let team_cols = gstrs(lib_palettes, "teams")
    for(lib_creatures.keys) id:
        let c = at(lib_creatures, id)
        expect(has(lib_parts, rstr(c, "body")) and has(lib_parts, rstr(c, "head")), "creature {id} body/head exist")
        for(gstrs(c, "skins")) s: expect(has(skins, s), "creature {id} skin {s} exists")
        for(gstrs(c, "families")) f: expect(has(lib_families, f), "creature {id} family {f} exists")
        for(gstrs(c, "skins")) s:  // a skin never reads as a team colour (a red frog on the blue side looked like the enemy: Dominic)
            if has(skins, s):
                for(team_cols) t:
                    let d = lab_distance(as_str(at(skins, s).a[0]), t)
                    expect(d >= float(SKIN_TEAM_GAP), "creature {id} skin {s} is no team colour ({t}: distance {int(d)}, needs {SKIN_TEAM_GAP})")
    for(lib_lexicon.keys) w:
        let e = at(lib_lexicon, w)
        if has(e, "creature"): expect(has(lib_creatures, rstr(e, "creature")), "lexicon {w} creature exists")
        if has(e, "family"): expect(has(lib_families, rstr(e, "family")), "lexicon {w} family exists")
        if has(e, "mount_wings"): expect(has(lib_parts, rstr(e, "mount_wings")), "lexicon {w} wings part exists")
    // The UI's looks: every culture wears one; its materials, crest and cut exist.
    let mats = [ "wood", "bronze", "gold", "iron", "marble", "stone", "sandstone", "parchment", "felt", "leather", "reed", "lacquer", "bone" ]
    let cuts = [ "square", "fringe", "swallowtail", "pointed", "notched", "tongues", "ragged", "scalloped" ]
    let ui_d = load_json(DATA + "/ui.json")
    let dirs = at(ui_d, "directions")
    let look_names = []::string
    let looks = []::JV
    for(dirs.keys) d, n:
        look_names.push("direction " + d)
        looks.push(dirs.a[n])
    for(lib_families.keys) f:
        expect(has(at(lib_families, f), "ui"), "family {f} has a ui block")
        look_names.push("family " + f)
        looks.push(gobj(at(lib_families, f), "ui"))
    for(looks) l, n:
        for([ "frame", "panel", "button", "primary" ]) k:
            if has(l, k): expect(has_s(mats, rstr(l, k)), "{look_names[n]}: {k} material {rstr(l, k)} is known")
        if has(l, "banner"): expect(has_s(cuts, rstr(l, "banner")), "{look_names[n]}: banner cut {rstr(l, "banner")} is known")
        if has(l, "ornament"): expect(read_file("../assets/art/ui/crest_{rstr(l, "ornament")}.svg") != nil, "{look_names[n]}: crest {rstr(l, "ornament")} exists")
    expect(has(dirs, rstr(ui_d, "direction")), "the UI direction in use exists")

def g_determinism():
    let rules = load_rules("default")
    for(PROMPTS) prompt:
        let a = generate(prompt, rules, 0)
        let b = generate(prompt, rules, 0)
        expect(rstr(a, "key") == rstr(b, "key"), "same prompt gives same key: \'{prompt}\'")
        expect(stringify(a) == stringify(b), "same prompt gives identical race: \'{prompt}\'")
    let keys = []::string
    for(8) reroll: push_new(keys, rstr(generate("angry swamp frogs", rules, reroll), "key"))
    expect(keys.length >= 6, "rerolls give different races ({keys.length}/8 distinct)")
    expect(rstr(generate("Angry  SWAMP frogs!", rules, 0), "key") == rstr(generate("angry swamp frogs", rules, 0), "key"), "prompt normalisation")

def g_bounds():
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        let eras = gstrs(r, "era")
        let in_play = (filter(glist(r, "roster")) sd: not has_s([ "planned", "parked" ], gstr(sd, "status", ""))).length
        for(PROMPTS) prompt:
            for(6) reroll:
                let race = generate(prompt, r, reroll)
                let kept = filter(units_of(race)) u: slot_of(u) != "hero"  // (the heroes: g_heroes)
                let has_hero = if kept.length < units_of(race).length: 1 else: 0
                expect(kept.length + has_hero + lacks_of(race).length == in_play, "roster size {rid}/{prompt}")
                for(units_of(race)) u:
                    let rec = recipe_of(u)
                    let name = rstr(rec, "name")
                    let ps = parts_of(rec)
                    for(ps.keys) slot, n:
                        let p = part(as_str(ps.a[n]))
                        expect(era_ok(p, eras), "{name}: {rstr(p, "id")} allowed in {rid}")
                        expect(rstr(p, "slot") == slot, "{rstr(p, "id")} in matching slot")
                    let role = rstr(rec, "role")
                    if role == "trader":  // an unarmed engine line (rules `armed`: false): no weapon at all
                        expect(ps.keys.length == 0 and has(rec, "crew"), "{name}: a trade cart carries no weapon, its crew pushes")
                    elif role != "hero":  // (its look over its swordsman's kit: g_heroes)
                        let need = role_needs(if has(rec, "unique"): rstr(at(lib_uniques, rstr(rec, "unique")), "role") else: role)
                        expect(has_s(tags_of(part_at(rec, "hand_r")), need), "{name} primary has {need}")
                        expect(total_cost(at(at(u, "eval"), "cost")) > 0, "{name} has a cost")
                        if role == "skirmisher": expect(not has_s(tags_of(part_at(rec, "hand_r")), "bow"), "{name} skirmisher has no bow")

def g_prompts():
    let d = load_rules("default")
    let last_age = as_int(at(d, "ages"))
    // Unit lines: a unit starts in its age's kit and upgrades within its kind and culture.
    for([ "centaur romans", "angry swamp frogs", "royal knights", "sewer rats" ]) prompt:
        for(units_of(generate(prompt, d, 0))) u:
            let ages_ = map(line_of(u)) l: as_int(at(l, "age"))
            let tier = ival(recipe_of(u), "tier")
            expect(ages_[0] == tier and ages_[ages_.length - 1] == last_age, "{prompt}: {slot_of(u)} line runs from age {tier} to {last_age} ({ages_})")
            for(line_of(u)) l:
                let age = as_int(at(l, "age"))
                for(part_ids(at(l, "recipe"))) id:
                    expect(gint(part(id), "tier", 1) <= age, "{prompt}: {slot_of(u)} at age {age} holds no later kit ({id})")
            expect(jequal(at(line_of(u)[0], "recipe"), recipe_of(u)), "{prompt}: the line starts with the unit\'s recipe")
    // An upgrade never reads "X -> X": new kit gets a new name, no new kit keeps it (and isn't sold).
    for([ "centaur romans", "centaur greeks", "angry swamp frogs", "royal knights", "sewer rats with cheese hammers", "aztec warriors", "han archers", "nile spiders" ]) prompt:
        for(4) reroll:
            for(units_of(generate(prompt, d, reroll))) u:
                if not has_s([ "worker", "hero" ], role_of(u)):  // (a hero keeps its name through the ages)
                    let line = line_of(u)
                    let names = map(line) l: rstr(at(l, "recipe"), "name")
                    var s = 1
                    while s < line.length:
                        let same_kit = jequal(parts_of(at(line[s], "recipe")), parts_of(at(line[s - 1], "recipe")))
                        expect(same_kit == has_s(names.slice(0, s), names[s]), "{prompt} (reroll {reroll}): {slot_of(u)} line step {s} has its own name only when its kit is new ({names})")
                        s++
    // Another culture's signature kit never turns up uninvited, and a culture keeps its own.
    let fprompts = [ "centaur romans", "winged romans", "flying greeks with wings", "greek hoplites", "royal knights" ]
    let fbad = [ [ "knight", "woodland", "bat", "greek", "viking", "cheese" ], [ "knight", "woodland", "bat", "greek" ], [ "knight", "woodland", "bat", "roman" ],
                 [ "knight", "woodland", "roman" ], [ "woodland", "roman", "greek", "bat" ] ]
    for(fprompts) prompt, n:
        for(6) reroll:
            for(units_of(generate(prompt, d, reroll))) u:
                let ids = []::string
                for(line_of(u)) l:
                    let r = at(l, "recipe")
                    for(part_ids(r)) id: ids.push(id)
                    if has(r, "mount"):
                        for(part_ids(at(r, "mount"))) id: ids.push(id)
                for(ids) id:
                    let bad = filter(tags_of(id)) t: has_s(fbad[n], t)
                    expect(not bad.length, "{prompt} (reroll {reroll}): {id} has foreign kit {bad}")
    expect(rstr(generate("swamp frogs", d, 0), "creature") == "frog", "frogs are frogs")
    expect(rstr(generate("sewer rats", d, 0), "creature") == "rat", "rats are rats")
    let centaurs = generate("centaur romans", d, 0)
    expect(rstr(centaurs, "creature") == "centaur" and rstr(centaurs, "family") == "imperial", "centaur romans")
    for(units_of(centaurs)) u:
        let who = gobj(recipe_of(u), "crew")
        let w = if who.keys.length: who else: recipe_of(u)  // an engine's centaurs are its crew
        expect(has(w, "mount") and gbool(at(w, "mount"), "fused", false), "every centaur is fused to a pony")
    let greeks = generate("flying greeks with wings", d, 0)
    expect(rstr(greeks, "family") == "hellenic", "greeks are hellenic")
    var winged = 0
    for(units_of(greeks)) u:
        let r = recipe_of(u)
        let mount_wings = if has(r, "mount"): part_at(at(r, "mount"), "back") else: ""
        if starts_with(part_at(r, "back"), "wings.") or starts_with(mount_wings, "wings."): winged++
        if has(r, "mount") and not gbool(at(r, "mount"), "fused", false):
            expect(not starts_with(part_at(r, "back"), "wings."), "riders don\'t wear wings; their mount does")
    expect(winged >= 4, "winged greeks mostly fly ({winged}/5)")
    let ww2 = generate("ww2 americans riding mongolian ponies", d, 0)
    expect(exists(notes_of(ww2)) n: contains_text(lowercase(n), "saucepan"), "ww2 blocked with a saucepan note")
    expect(has(recipe_of(unit_of(ww2, "large")), "mount"), "mongolian large unit is mounted")
    expect(has(recipe_of(unit_of(ww2, "archer")), "mount"), "mongolian archers are horse archers")
    for(20) reroll:
        for([ "romans", "centaur romans", "flying greeks" ]) prompt:
            for([ "default", "bronze" ]) rid:
                for(units_of(generate(prompt, load_rules(rid), reroll))) u:
                    expect(part_at(recipe_of(u), "hand_r") != "weapon.cheese_hammer", "no cheese hammers for {prompt} unless asked")
                    expect(ival(recipe_of(u), "scale") < GIANT_SCALE, "no giant {prompt} unless asked")
    let open = deep_copy(d)
    set(open, "no_restrictions", jbool(true))
    var foreign_ok = false
    for(12) reroll:
        for(units_of(generate("centaur romans", open, reroll))) u:
            for(line_of(u)) l:
                for(part_ids(at(l, "recipe"))) id:
                    foreign_ok = foreign_ok or exists(tags_of(id)) t: has_s([ "woodland", "knight", "junk", "bat" ], t)
    expect(foreign_ok, "no_restrictions lets other cultures\' kit through")
    expect(notes_of(generate("blorp zang wibble", d, 0)).length >= 2, "gibberish gets volunteer + ignored notes")
    let guns = part_at(at(last_step(unit_of(generate("rats with guns", load_rules("anything"), 0), "skirmisher")), "recipe"), "hand_r")
    expect(guns == "weapon.musket", "anything-goes rats with guns get muskets once their age comes ({guns})")
    expect(part_at(recipe_of(unit_of(generate("rats with guns", d, 0), "skirmisher")), "hand_r") != "weapon.musket", "default rules block muskets")

// Every race gets a healer at the Town Center from age 2: it heals and never fights, goes light, wears
// its culture's kit, and adding it changed no other line's recipes.
def g_healers():
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        for(PROMPTS) prompt:
            for(3) reroll:
                let race = generate(prompt, r, reroll)
                let h = unit_of(race, "healer")
                expect(ival(recipe_of(h), "tier") == 2, "{prompt}: the healer opens in age 2")
                for(line_of(h)) l:
                    let e = at(l, "eval")
                    let lr = at(l, "recipe")
                    let name = rstr(lr, "name")
                    expect(gint(e, "heal", 0) > 0 and gint(e, "attack", 0) == 0, "{rid}/{prompt}: {name} heals and has no attack")
                    expect(gint(at(e, "cost"), "gold", 0) > 0, "{name}: a healer costs gold")
                    let ps = parts_of(lr)
                    for(ps.keys) slot, n:
                        let p = part(as_str(ps.a[n]))
                        let pt = gstrs(p, "tags")
                        expect(slot != "torso" and not has_s(pt, "shield") and not has_s(pt, "heavy"), "{prompt}: {name} goes light ({rstr(p, "id")})")
                        if slot == "hand_l": expect(has_s(pt, "heal"), "{prompt}: the healer\'s off hand holds its bag ({rstr(p, "id")})")
                for(units_of(race)) u:
                    if role_of(u) != "healer":
                        let rec = recipe_of(u)
                        let hand = part_at(rec, "hand_r")
                        expect(gint(at(u, "eval"), "heal", 0) == 0 and not (hand != "" and has_s(tags_of(hand), "heal")), "{prompt}: only healers heal ({rstr(rec, "name")})")
    let d = load_rules("default")
    expect(part_at(recipe_of(unit_of(generate("sewer rats", d, 0), "healer")), "hand_r") == "tool.staff.cheese", "rat healers carry a cheese staff")
    expect(part_at(recipe_of(unit_of(generate("swamp frogs", d, 0), "healer")), "hand_r") == "tool.staff.lily", "frog healers carry a lily staff")
    // Every culture its own staff, from data (only_if + favour), and the bag to match where it has one.
    let kp = [ "romans", "greeks", "royal humans", "mongols", "spooky spiders", "forest beetles", "egyptians", "han", "aztecs" ]
    let kits = [ [ "tool.staff.laurel", "tool.satchel" ], [ "tool.staff.olive", "tool.satchel.flask" ], [ "tool.staff.lantern", "tool.satchel" ],
                 [ "tool.staff.horsehair", "tool.satchel.felt" ], [ "tool.staff.candle", "tool.satchel.bottle" ], [ "tool.staff.branch", "tool.satchel.leaf" ],
                 [ "tool.staff.papyrus", "tool.satchel.linen" ], [ "tool.staff.gourd", "tool.satchel.lacquer" ], [ "tool.staff.feather", "tool.satchel.woven" ] ]
    for(kp) prompt, n:
        let rec = recipe_of(unit_of(generate(prompt, d, 0), "healer"))
        expect(part_at(rec, "hand_r") == kits[n][0] and part_at(rec, "hand_l") == kits[n][1], "{prompt} healers carry their culture\'s kit ({part_at(rec, "hand_r")}, {part_at(rec, "hand_l")})")
    // own_seed: the healer draws from its own stream, so every other line is as it was without it.
    let without = without_slots(d, [ "healer" ])
    for(PROMPTS) prompt:
        let a = lines_json(generate(prompt, d, 0)) u: not has_s([ "healer", "hero" ], role_of(u))  // (the hero comes from the race key)
        let b = lines_json(generate(prompt, without, 0)) u: role_of(u) != "hero"
        expect(a == b, "\'{prompt}\': adding the healer leaves the other lines\' recipes as they were")

// Siege engines (milestone 13): every race gets a ram, catapult and bolt thrower in its take, crewed by
// its worker, priced with wood and gold.
def g_siege():
    let d = load_rules("default")
    for(lib_families.keys) f:
        for([ "ram", "catapult", "bolt" ]) e:
            expect(has(lib_parts, "siege.{e}.{rstr(at(lib_families, f), "siege")}"), "family {f}\'s take builds a {e}")
    let tpr = [ "romans", "sewer rats", "forest beetles", "spooky spiders", "swamp frogs", "forest frogs", "swamp beetles", "mongols" ]
    let takes = [ "timber", "junk", "forest", "spooky", "frog", "frog", "timber", "timber" ]
    for(tpr) prompt, n:
        let race = generate(prompt, d, 0)
        for([ "ram", "catapult", "bolt_thrower" ]) role:
            let u = unit_of(race, role)
            let r = recipe_of(u)
            expect(ends_with(rstr(r, "body"), "." + takes[n]) and rstr(at(r, "crew"), "body") == rstr(recipe_of(units_of(race)[0]), "body"),
                   "{prompt}: the {role} is the {takes[n]} take, crewed by its workers ({rstr(r, "body")})")
            let cost = at(at(u, "eval"), "cost")
            expect(ival(r, "tier") == 3 and line_of(u).length == 1 and gint(cost, "gold", 0) > 0 and gint(cost, "wood", 0) > 0,
                   "{prompt}: the {role} opens in age 3 and costs wood and gold ({stringify(cost)})")
    let ram = at(unit_of(generate("romans", d, 0), "ram"), "eval")
    expect(gstr(ram, "targets", "") == "buildings" and ival(ram, "armour.pierce") > ival(ram, "armour.melee"), "the ram hits buildings only, shrugs off arrows, not blows")

// Culture kits (#444): a Roman line wears its culture's kit in every age, under every rules; a part the prompt asked for
// (cheese) keeps its slot.
def g_kits():
    let kits = gobj(family("imperial"), "kits")
    expect(kits.keys.length > 1, "imperial has culture kits")
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        for(3) reroll:
            let race = generate("romans", r, reroll)
            for(kits.keys) slot:
                if slot != "_doc":
                    for(line_of(unit_of(race, slot))) l:
                        let lr = at(l, "recipe")
                        var want = jobj()
                        for(gint(l, "age", 1)) a:
                            let k = get(at(kits, slot), string(a + 1))
                            if k: want = k
                        let rp = at(lr, "parts")
                        for(want.keys) s, i:
                            let id = as_str(want.a[i])
                            let ok = gint(part(id), "tier", 1) <= gint(l, "age", 1) and exists(candidates(s, gstrs(r, "era"))) p: rstr(p, "id") == id
                            if ok: expect(gstr(rp, s, "") == id, "{rid}/romans/{reroll}: {rstr(lr, "name")} (age {gint(l, "age", 1)}) wears its kit\'s {id} ({gstr(rp, s, "")})")
                        for(rp.keys) s: expect(has(want, s) or s == "hand_r", "{rid}/romans/{reroll}: {rstr(lr, "name")} wears only its kit ({s})")
    let cheese = recipe_of(unit_of(generate("cheese romans", load_rules("default"), 0), "infantry"))
    expect(part_at(cheese, "hand_r") == "weapon.cheese_hammer", "cheese romans keep the cheese hammer they asked for ({part_at(cheese, "hand_r")})")

// The swordsman line at the Barracks (milestone 13).
def g_swordsmen():
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        for(PROMPTS) prompt:
            for(3) reroll:
                let s = unit_of(generate(prompt, r, reroll), "infantry")
                expect(ival(recipe_of(s), "tier") == 1 and line_of(s).length == 3, "{rid}/{prompt}: the swordsman line runs ages 1-3")
                for(line_of(s)) l:
                    let lr = at(l, "recipe")
                    let tags = tags_of(part_at(lr, "hand_r"))
                    expect(has_s(tags, "melee") and not has_s(tags, "spear") and not has_s(tags, "lance"), "{rid}/{prompt}: {rstr(lr, "name")} holds a blade or a club ({part_at(lr, "hand_r")})")
                    let bonus = at(at(l, "eval"), "bonus")
                    expect(gint(bonus, "spear", 0) > 0 and gint(bonus, "skirmish", 0) > 0 and gint(bonus, "building", 0) > 0,
                           "{prompt}: {rstr(lr, "name")} beats spears, skirmishers and buildings")
    let d = load_rules("default")
    let b = load_rules("bronze")
    let wp = [ "sewer rats", "romans", "egyptians", "aztecs", "greeks", "royal humans", "mongols", "han", "swamp frogs", "forest beetles", "spooky spiders" ]
    let weapons = [ "weapon.cheese_hammer", "weapon.gladius", "weapon.khopesh", "weapon.macuahuitl", "weapon.sword.xiphos", "weapon.sword.iron",
                    "weapon.sword.flared_sabre", "weapon.sword.dao", "weapon.mace.river_stone", "weapon.sword.chitin", "weapon.sword.hook" ]
    for(wp) prompt, n:
        let got = part_at(at(last_step(unit_of(generate(prompt, d, 0), "infantry")), "recipe"), "hand_r")
        expect(got == weapons[n], "{prompt} swordsmen end with {weapons[n]} ({got})")
    // The age-3 kit (D-125): the helmets come with it; the plain iron sword is the fallback.
    def last_part(prompt:string, rules:JV, slot:string) -> string: return part_at(at(last_step(unit_of(generate(prompt, rules, 0), "infantry")), "recipe"), slot)
    expect(last_part("greeks", d, "head_gear") == "helm.attic", "greek swordsmen wear the Attic helmet in age 3")
    expect(last_part("mongols", d, "head_gear") == "helm.steppe_spike", "steppe swordsmen wear the spiked helmet in age 3")
    expect(last_part("royal humans", b, "hand_r") == "weapon.sword.iron_plain", "royal humans under the bronze rules fall back on the plain iron sword")
    for([ "egyptians", "aztecs", "romans" ]) prompt: expect(last_part(prompt, b, "hand_r") != "weapon.sword.iron_plain", "{prompt} keep their own blade in age 3")
    expect(part_at(recipe_of(unit_of(generate("greeks", d, 0), "infantry")), "hand_r") == "weapon.club.bone", "age 1 swordsmen start with a club")
    let without = without_slots(d, [ "infantry" ])
    for(PROMPTS) prompt:
        let a = generate(prompt, d, 0)
        let c = generate(prompt, without, 0)
        let la = lines_json(a) u: not has_s([ "infantry", "hero" ], slot_of(u))
        let lc = lines_json(c) u: not has_s([ "infantry", "hero" ], slot_of(u))
        expect(la == lc and rstr(a, "name") == rstr(c, "name"), "\'{prompt}\': adding the swordsman leaves the other lines\' recipes as they were")

// The scout, the mounted archer and the unique unit (milestone 13).
def g_new_lines():
    let prompts = append(PROMPTS, [ "romans", "aztecs", "spooky spiders", "mongols", "swamp frogs", "sewer rats", "egyptians", "han", "forest beetles" ])
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        for(prompts) prompt:
            for(2) reroll:
                let race = generate(prompt, r, reroll)
                let spear = unit_of(race, "spear")
                let s = unit_of(race, "scout")
                expect(ival(recipe_of(s), "tier") == 2 and line_of(s).length == 2, "{rid}/{prompt}: the scout line runs ages 2-3")
                for(line_of(s)) l:
                    let lr = at(l, "recipe")
                    let name = rstr(lr, "name")
                    let w = tags_of(part_at(lr, "hand_r"))
                    expect(has_s(w, "melee") and not exists(w) t: has_s([ "spear", "lance", "heavy" ], t), "{prompt}: {name} holds a light weapon ({part_at(lr, "hand_r")})")
                    let ps = parts_of(lr)
                    for(ps.keys) slot, n:
                        let p = part(as_str(ps.a[n]))
                        let pt = gstrs(p, "tags")
                        expect(slot == "hand_r" or has_s(pt, "wings") or (not has_s(pt, "heavy") and as_int(at(p, "points")) <= 2), "{prompt}: {name} goes light ({rstr(p, "id")})")
                    let e = at(l, "eval")
                    expect(gint(e, "sight", 0) > 0 and gint(at(e, "bonus"), "skirmish", 0) > 0, "{prompt}: {name} sees far and beats skirmishers")
                let ss = ival(at(s, "eval"), "speed")
                let sp = ival(at(spear, "eval"), "speed")
                expect(ss > sp, "{prompt}: the scout ({ss}) outruns the spear ({sp})")
                let ma = filter(units_of(race)) u: slot_of(u) == "mounted_archer"
                let archer = unit_of(race, "archer")
                expect((ma.length == 0) == has_s(lacks_of(race), "mounted_archer"), "{prompt}: a missing mounted archer is listed as lacking")
                if ma.length:
                    let mr = recipe_of(ma[0])
                    let mt = gstrs(at(ma[0], "eval"), "tags")
                    expect(has(mr, "mount") and has_s(tags_of(part_at(mr, "hand_r")), "bow") and has_s(mt, "mounted") and not has_s(mt, "infantry"),
                           "{prompt}: {rstr(mr, "name")} rides with a bow, not infantry")
                else:
                    expect(has(recipe_of(archer), "mount") or not has(recipe_of(s), "mount") or gbool(creature(rstr(race, "creature")), "harness", false),
                           "{prompt}: no mounted archers only when its archers ride, nothing carries it, or it has no hands")
                let un = unit_of(race, "unique")
                let ur = recipe_of(un)
                expect(ival(ur, "tier") == 3 and line_of(un).length == 1 and has(lib_uniques, gstr(ur, "unique", "")), "{prompt}: one unique unit in age 3 ({rstr(ur, "name")})")
                let need = role_needs(rstr(at(lib_uniques, rstr(ur, "unique")), "role"))
                expect(has_s(tags_of(part_at(ur, "hand_r")), need), "{prompt}: {rstr(ur, "name")} holds its theme\'s weapon")
    let d = load_rules("default")
    expect(has(recipe_of(unit_of(generate("centaur romans", d, 0), "archer")), "mount") and has_s(lacks_of(generate("centaur romans", d, 0)), "mounted_archer"), "centaurs\' archers are their mounted archers")
    let az = generate("aztecs", d, 0)
    expect(has_s(lacks_of(az), "mounted_archer") and not has(recipe_of(unit_of(az, "scout")), "mount"), "aztecs: no mounted archers, scouts on foot")
    expect(rstr(at(recipe_of(unit_of(generate("greeks", d, 0), "mounted_archer")), "mount"), "creature") == "pony", "greeks\' mounted archers ride ponies")
    let tpr = [ "romans", "roman frogs", "sewer rats", "sewer rats with cheese hammers", "greeks", "aztecs", "swamp frogs", "mongols", "royal knights",
                "spooky beetle knights", "egyptians", "han", "tiny vikings", "horned vikings", "forest beetles", "spooky spiders" ]
    let themes = [ "testudo", "testudo", "gutter_raider", "big_cheese", "phalanx", "obsidian", "bullfrog", "steppe_raider", "sworn_knight",
                   "sworn_knight", "nile_bowguard", "repeater", "berserker", "horned_raider", "stag_colossus", "web_lurker" ]
    for(tpr) prompt, n:
        let got = rstr(recipe_of(unit_of(generate(prompt, d, 0), "unique")), "unique")
        expect(got == themes[n], "{prompt}: unique theme {themes[n]} ({got})")
    expect(ival(recipe_of(unit_of(generate("swamp frogs", d, 0), "unique")), "scale") >= GIANT_SCALE, "the Great Bullfrog is a giant")
    expect(has(recipe_of(unit_of(generate("mongols", d, 0), "unique")), "mount"), "the Steppe Raider rides")
    let testudo = unit_of(generate("romans", d, 0), "unique")
    expect(part_at(recipe_of(testudo), "hand_l") == "shield.scutum" and ival(at(testudo, "eval"), "armour.pierce") >= 7, "the Testudo Guard locks its scutum")
    let new_slots = [ "scout", "mounted_archer", "unique", "hero" ]
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        let without = without_slots(r, [ "scout", "mounted_archer", "unique" ])
        for(prompts) prompt:
            for(2) reroll:
                let a = generate(prompt, r, reroll)
                let b = generate(prompt, without, reroll)
                let la = lines_json(a) u: not has_s(new_slots, slot_of(u))
                let lb = lines_json(b) u: not has_s(new_slots, slot_of(u))
                expect(la == lb and rstr(a, "name") == rstr(b, "name"), "{rid}/\'{prompt}\': the new lines leave the others\' recipes and the name as they were")

// The rats' alley cat (C2, D-124): rats ride cats, a capybara only when asked for (the generator's half;
// the cat's poses are the view's).
def g_cat():
    let d = load_rules("default")
    let u = recipe_of(unit_of(generate("sewer rats", d, 0), "large"))
    expect(has(u, "mount") and rstr(at(u, "mount"), "creature") == "cat", "rats ride cats (D-124)")
    let capy = recipe_of(unit_of(generate("sewer rats riding capybaras", d, 0), "large"))
    expect(has(capy, "mount") and rstr(at(capy, "mount"), "creature") == "capybara", "a capybara when asked for")
    let asked = recipe_of(unit_of(generate("romans on cats", d, 0), "large"))
    expect(has(asked, "mount") and rstr(at(asked, "mount"), "creature") == "cat", "\'cats\' asks for the cat mount")

// Every sound data/audio.json names has its takes on disk; every creature's voice has its files; every
// music piece has every stem, a loop long (all rendered by render_audio.sh).
def g_audio():
    let cfg = load_json(DATA + "/audio.json")
    let buses = at(cfg, "buses")
    let sounds = at(cfg, "sounds")
    for(sounds.keys) n, k:
        let s = sounds.a[k]
        let bus = rstr(s, "bus")
        expect(if buses.kind == J_OBJ: has(buses, bus) else: has_str(buses.a, bus), "sound {n} is on a known bus")
        for(as_int(at(s, "takes"))) t:
            let path = "../assets/audio/sfx/{n}_{t + 1}.wav"
            expect(wav_seconds(path) > 0.01, "sound take loads: " + path)
    let kinds = at(at(cfg, "voices"), "kinds")
    for(lib_creatures.keys) id:
        let voice = rstr(at(lib_creatures, id), "voice")
        for(kinds.keys) kind, k:
            for(as_int(kinds.a[k])) t:
                let path = "../assets/audio/voice/{voice}_{kind}_{t + 1}.wav"
                expect(read_file(path, true) != nil, "creature {id} has its voice: {path}")
    let music = at(cfg, "music")
    let stems = gstrs(music, "stems")
    let pieces = at(music, "pieces")
    for(pieces.keys) piece, k:
        for(stems) stem:
            let path = "../assets/audio/music/{piece}_{stem}.ogg"
            expect(abs(ogg_seconds(path) - as_float(pieces.a[k])) < 0.05, "music stem loads, a loop long: " + path)
    for(gstrs(music, "rotation")) piece: expect(has(pieces, piece), "music rotation plays a piece: {piece}")
    expect(has(pieces, gstr(music, "tense", "")), "the tense music is a piece")
    let mixes = at(music, "mixes")
    for(mixes.keys) mix, k:
        for(mixes.a[k].keys) stem: expect(has_s(stems, stem), "mix {mix} uses a known stem: {stem}")

// The tech tree's data (milestone 12): every planned item is named in the milestone file, the sim's
// loaders and the build menus leave planned items out, the rosters' buildings train them, and the
// generator skips planned roster slots. (The page's own nodes: see the header.)
def g_tech_tree():
    let bdata = load_json(DATA + "/buildings.json")
    let blds = at(bdata, "buildings")
    let tdata = load_json(DATA + "/tech.json")
    let plan = read_file("../docs/milestones/m12-tech-tree.md") or ""
    expect(plan != "", "docs/milestones/m12-tech-tree.md is there")
    for(RULE_IDS) rid:
        for(glist(load_rules(rid), "roster")) sd:
            let b = gstr(sd, "building", "")
            expect(has(blds, b), "roster {rstr(sd, "slot")} names a building ({rid})")
            if has(blds, b) and not has_s([ "planned", "parked" ], gstr(sd, "status", "")):
                expect(has_s(gstrs(at(blds, b), "trains"), rstr(sd, "slot")), "roster {rstr(sd, "slot")}: its building trains it ({rid})")
    // Planned items are in the plan (by name), and nothing in the game loads them.
    let planned = []::string
    for(blds.keys) id:
        if gstr(at(blds, id), "status", "") == "planned": planned.push(rstr(at(blds, id), "name"))
    for(glist(tdata, "research")) r:
        if gstr(r, "status", "") == "planned" and rstr(r, "building") != "castle": planned.push(rstr(r, "name"))
    for(glist(tdata, "ages")) a:
        if gstr(a, "status", "") == "planned": planned.push(rstr(a, "name"))
    for(glist(load_rules("default"), "roster")) sd:
        if gstr(sd, "status", "") == "planned": planned.push("`{rstr(sd, "slot")}`")
    for(planned) name: expect(contains_text(plan, name), "planned item {name} is in docs/milestones/m12-tech-tree.md")
    let d = load_rules("default")
    let race = generate("centaur romans", d, 0)
    fresh_world([ race, race ], d)
    expect(all_of(su_btypes) b: gstr(b, "status", "") != "planned", "the sim\'s building types skip planned ones")
    expect(su_btypes.length == (filter(blds.keys) id: gstr(at(blds, id), "status", "") != "planned").length, "the sim loads every built building")
    expect(su_ages.length == 3 and all_of(su_ages) a: as_int(at(a, "age")) <= 3, "the sim\'s ages skip the planned fourth")
    for(su_research) r: expect(has(r, "line") or gstr(r, "status", "") != "planned", "the sim\'s research skips planned {rstr(r, "id")}")
    let menu = at(bdata, "menu")
    for(menu.a) m:
        for(m.a) id: expect(gstr(at(blds, as_str(id)), "status", "") != "planned", "build menus hold no planned building ({as_str(id)})")
    for(RULE_IDS) rid:
        let r = load_rules(rid)
        let open_slots = map(filter(glist(r, "roster")) s: gstr(s, "status", "") != "planned") s: rstr(s, "slot")
        expect(all_of(units_of(generate("centaur romans", r, 0))) u: has_s(open_slots, slot_of(u)), "the generator skips planned roster slots ({rid})")

// Milestone 14's race identity (gen/identity.lobster): every playable creature with every culture mixes
// six bonuses, no kind twice; every effect has the research shape; own research and lacks name real
// things; a race's identity comes from its creature and culture alone, and its stat bonuses are paid for.
def g_identity():
    let d = load_rules("default")
    let tdata = load_json(DATA + "/tech.json")
    let bdata = at(load_json(DATA + "/buildings.json"), "buildings")
    let research_ = jobj()
    for(glist(tdata, "research")) r: set(research_, rstr(r, "id"), r)
    let slots = map(glist(d, "roster")) sd: rstr(sd, "slot")
    let fams = sorted_strs(lib_families.keys)
    let any_race = generate("romans", d, 0)
    fresh_world([ any_race, any_race ], d)  // (the sim's tables, for encode_effect: the effects' shape check)
    for(creature_ids("playable")) cid:
        for(fams) fid:
            let ident = identity_of(cid, fid)
            let bonuses = glist(ident, "bonuses")
            expect(bonuses.length == 6, "identity {cid}/{fid}: six bonuses ({bonuses.length})")
            let kinds = []::string
            for(bonuses) b:
                push_new(kinds, kind_of(b))
                for(glist(b, "effects")) fx: encode_effect(fx)  // (asserts on a bad shape)
                let paid = exists(glist(b, "effects")) fx: priced(fx) and not has_s([ "cost", "train_time" ], gstr(fx, "stat", ""))
                expect(paid == (gint(b, "price_points", 0) > 0), "identity {cid}/{fid}: \"{rstr(b, "text")}\" is paid for if it adds to unit stats")
            expect(kinds.length == bonuses.length, "identity {cid}/{fid}: no kind of bonus twice")
    for([ lib_creatures, lib_families ]) src, layer_n:
        let layer = if layer_n == 0: "creature" else: "culture"
        for(src.keys) id:
            for(gstrs(at(src, id), "research")) r:
                expect(has(research_, r) and gstr(at(research_, r), "own", "") == layer, "identity: {id}\'s own research {r} is a {layer} research in tech.json")
            for(gstrs(at(src, id), "lacks")) l:
                var known = has(research_, l) or has(bdata, l) or has_s(slots, l) or l == "trade"
                if starts_with(l, "line."): known = has_s(slots, tokenize(l, ".", "")[1])
                expect(known, "identity: {id} lacks something real ({l})")
    // Same creature and culture, any prompt: the same identity; the race key never sees it.
    let a = generate("hellenic beetles", d, 0)
    let b = generate("hellenic beetles with big shields", d, 3)
    expect(stringify(identity_of(rstr(a, "creature"), rstr(a, "family"))) == stringify(identity_of(rstr(b, "creature"), rstr(b, "family"))), "identity: from creature and culture alone")
    let cp = deep_copy(a)
    for(units_of(cp)) u:
        for(line_of(u)) l: set(at(at(l, "eval"), "armour"), "pierce", jint(99))
    expect(race_key(cp) == rstr(a, "key"), "identity: the race key hashes recipes, not the stats bonuses change")
    // Hellenic spears: +1 melee armour, paid for (a point on the price).
    let spear = (filter(units_of(a)) u: slot_of(u) == "spear")[0]
    let forest = deep_copy(recipe_of(spear))
    set(forest, "family", jstr("forest"))  // (forest: no spear bonus)
    let plain = evaluate(forest, d, 0)
    let se = at(spear, "eval")
    expect(ival(se, "armour.pierce") == ival(plain, "armour.pierce") and ival(se, "armour.melee") == ival(plain, "armour.melee") + 1,
           "identity: hellenic spears +1 melee armour on the eval ({ival(se, "armour.melee")} vs {ival(plain, "armour.melee")})")
    expect(ival(se, "points") == ival(plain, "points") + 1, "identity: ...and pay a point for it")

// Heroes (milestone 14 step 9, gen/heroes.lobster; D-138, D-159).
def g_heroes():
    let d = load_rules("default")
    let hs = lib_heroes
    let sigs_all = at(hs, "hero_signatures")
    let fams = sorted_strs(lib_families.keys)
    let titles = []::string
    let hn = at(hs, "hero_names")
    for([ at(hn, "creatures"), at(hn, "families"), sigs_all ]) src:
        for(src.a) v:
            for(gstrs(v, "titles")) t: titles.push(t)
    let min_heroes = as_int(at(at(hs, "rules"), "min_heroes"))
    let seen = []::string
    for(creature_ids("playable")) cid:
        for(fams) fid:
            let sigs = roster_for(cid, fid)
            let own = signatures_for(cid, fid)
            expect(sigs.length >= min_heroes and strs_eq(sigs.slice(0, min(own.length, sigs.length)), own), "heroes: {cid}/{fid} have all their own and at least {min_heroes} ({sigs})")
            let once = []::string
            for(sigs) sid:
                expect(not has_s(once, sid), "heroes: {cid}/{fid}: {sid} once")
                once.push(sid)
                push_new(seen, sid)
                let h = hero_pick("key{cid.length}", cid, fid, sid)
                let s = at(sigs_all, sid)
                let words = append(gstrs(s, "epithets"), gstrs(s, "nicknames"))
                let name = rstr(h, "name")
                expect(contains_text(name, "of His Name") or exists(words) e: contains_text(name, e), "heroes: {sid}\'s name carries its look ({name})")
    let kin = at(hs, "kin")
    for(kin.keys) fid, k:
        expect(has(lib_families, fid) and all_of(kin.a[k].a) f: has(lib_families, as_str(f)) and as_str(f) != fid, "heroes: {fid}\'s kin are other cultures")
    for(sigs_all.keys) sid, k:
        let s = sigs_all.a[k]
        let who = at(s, "who")
        let playable = exists(gstrs(who, "creature")) c: has(lib_creatures, c) and gbool(at(lib_creatures, c), "playable", false)
        expect(has_s(seen, sid) or not (playable or gstrs(who, "family").length > 0), "heroes: {sid} is someone\'s hero")
        let sp = at(s, "parts")
        for(sp.keys) slot, n:
            let id = as_str(sp.a[n])
            expect(has(lib_parts, id) and rstr(part(id), "slot") == slot, "heroes: {sid}\'s {id} is a {slot} part")
        let fit = gobj(s, "fit")
        for(fit.keys) cid, n:
            expect(has(lib_creatures, cid), "heroes: {sid}\'s fit names a creature ({cid})")
            let f = fit.a[n]
            for(f.keys) slot, m:
                let fid = as_str(f.a[m])
                expect(has(sp, slot) and (fid == "" or (has(lib_parts, fid) and rstr(part(fid), "slot") == slot)), "heroes: {sid}\'s fit for {cid}: a {slot} part in place of its own ({fid})")
        let aura = at(s, "aura")
        expect(glist(aura, "effects").length > 0 and gstr(aura, "text", "") != "", "heroes: {sid} has an aura")
    for(lib_lexicon.keys) word:
        let e = at(lib_lexicon, word)
        if has(e, "hero"): expect(has(sigs_all, rstr(e, "hero")), "heroes: the word \'{word}\' names a hero")
    // One hero a race (D-159): the first the prompt names from its pool, the same on every reroll; else one
    // of its pool by the key. A second named, or one not in its pool, gets a note.
    let cprompts = [ "spooky spider widow", "sewer rats with a crown", "proud centaur romans", "swamp frog mossback and the loud", "roman widow" ]
    let cwant = [ "widow", "regnal", "proud", "mossback", "" ]
    let cnote = [ false, false, false, true, true ]
    for(cprompts) prompt, n:
        let race = generate(prompt, d, 0)
        let got = map(filter(units_of(race)) u: slot_of(u) == "hero") u: rstr(recipe_of(u), "hero")
        let hpool = roster_for(rstr(race, "creature"), rstr(race, "family"))
        expect(got.length == 1 and (if cwant[n] != "": got[0] == cwant[n] else: has_s(hpool, got[0])), "heroes: \'{prompt}\' gets one hero, {cwant[n]} ({got})")
        if cwant[n] != "":
            let again = map(glist(generate(prompt, d, 1), "heroes")) h: rstr(h, "signature")
            expect(strs_eq(again, [ cwant[n] ]), "heroes: \'{prompt}\': the same hero on a reroll")
        expect(race_key(race) == rstr(race, "key") and has(race, "hero_asked") == (cwant[n] != ""), "heroes: \'{prompt}\': the key holds the hero asked for")
        expect(cnote[n] == exists(notes_of(race)) x: contains_text(x, "leads"), "heroes: \'{prompt}\': a note only for a hero that didn\'t come ({notes_of(race)})")
    let picks = []::string
    for(8) reroll: push_new(picks, rstr(glist(generate("spooky spiders", d, reroll), "heroes")[0], "signature"))
    expect(picks.length >= 2, "heroes: rerolls bring different heroes from the pool ({picks})")
    for([ "sewer rats with cheese hammers", "romans", "spooky spiders", "centaur romans", "egyptians", "swamp frogs", "forest beetles", "swamp humans", "sewer humans" ]) prompt:
        for(2) reroll:
            let race = generate(prompt, d, reroll)
            let all_units = units_of(race)
            let heroes = filter(all_units) u: slot_of(u) == "hero"
            let infos = glist(race, "heroes")
            let hpool = roster_for(rstr(race, "creature"), rstr(race, "family"))
            let hero_names = map(heroes) u: rstr(recipe_of(u), "hero")
            expect(heroes.length == 1 and has_s(hpool, hero_names[0]) and stringify(all_units[all_units.length - 1]) == stringify(heroes[0]) and infos.length == 1,
                   "heroes: \'{prompt}\' has one hero from its pool, the last of its units ({hero_names} of {hpool})")
            expect(race_key(race) == rstr(race, "key"), "heroes: \'{prompt}\': the key leaves the heroes out")
            expect(stringify(at(generate(prompt, d, reroll), "heroes")) == stringify(at(race, "heroes")), "heroes: \'{prompt}\': the same heroes every time")
            let names = []::string
            let firsts = []::string
            for(infos) h:
                let name = rstr(h, "name")
                push_new(names, name)
                let words = tokenize(name, " ", "")  // (the given name: past a title, "General" or "Sir", that two may share)
                push_new(firsts, if words.length > 1 and has_s(titles, words[0]): words[1] else: words[0])
            let all_names = map(infos) h: rstr(h, "name")
            expect(names.length == infos.length, "heroes: \'{prompt}\': each its own name ({all_names})")
            expect(firsts.length == infos.length, "heroes: \'{prompt}\': no two share a first name ({all_names})")
            let sword = unit_of(race, "infantry")
            for(heroes) hero:
                let s = at(sigs_all, rstr(recipe_of(hero), "hero"))
                let worn = parts_on(s, rstr(race, "creature"))
                for(line_of(hero)) l:
                    let r = at(l, "recipe")
                    let age = as_int(at(l, "age"))
                    for(worn.keys) slot, n: expect(part_at(r, slot) == as_str(worn.a[n]), "heroes: \'{prompt}\' wears its {as_str(worn.a[n])}")
                    let kit = gobj(r, "kit")
                    for(kit.keys) slot, n:
                        let kp = part(as_str(kit.a[n]))
                        expect((rstr(kp, "slot") == slot and not has(kp, "only_if")) or not has_s(gstrs(kp, "only_if"), "hero_only"), "heroes: \'{prompt}\' keeps its {slot} kit")
                    let sws = filter(line_of(sword)) x: as_int(at(x, "age")) <= age
                    let sw = at(sws[sws.length - 1], "eval")
                    let le = at(l, "eval")
                    expect(ival(le, "hp") >= ival(sw, "hp") * 2 and total_cost(at(le, "cost")) * 2 > total_cost(at(sw, "cost")) * 3,
                           "heroes: \'{prompt}\' age {age}: tougher and dearer than its swordsman ({ival(le, "hp")} hp, {total_cost(at(le, "cost"))})")
                    expect(not has_s(gstrs(le, "tags"), "giant"), "heroes: \'{prompt}\': its size is its look, not a giant\'s")
    for(PROMPTS) prompt:
        for(units_of(generate(prompt, d, 0))) u:
            if slot_of(u) != "hero":
                for(line_of(u)) l:
                    expect(not exists(part_ids(at(l, "recipe"))) id: has_s(gstrs(part(id), "only_if"), "hero_only"), "heroes: \'{prompt}\' {slot_of(u)} wears no hero\'s kit")

// Milestone 21's mods (gen/mods.lobster): the example mod merges in load order, its parts only come when
// asked for and allowed, the race key holds the mod set (and a race without mods keeps its key), and
// every broken fixture in tests/mods is refused with its reason.
def g_merge():
    let base = parse_json("\{\"a\":\{\"hp\":1,\"cost\":\{\"wood\":5\},\"trains\":[\"x\",\"y\"]\},\"b\":\{\"hp\":2\},\"list\":[\{\"id\":\"p\",\"t\":1\},\{\"id\":\"q\",\"t\":2\}],\"ages\":[\{\"age\":1\},\{\"age\":2\}],\"plain\":[1,2]\}")
    def merged(mod:string) -> JV: return data_merge(base, parse_json(mod))
    expect(stringify(merged("\{\}")) == stringify(base), "merge: nothing changes nothing")
    expect(stringify(at(at(merged("\{\"a\":\{\"cost\":\{\"food\":1\}\}\}"), "a"), "cost")) == stringify(parse_json("\{\"wood\":5,\"food\":1\}")), "merge: objects merge")
    expect(not has(merged("\{\"b\":\{\"remove\":true\}\}"), "b"), "merge: remove takes an entry out")
    expect(as_int(at(at(merged("\{\"c\":\{\"extends\":\"b\",\"size\":3\}\}"), "c"), "hp")) == 2, "merge: extends copies a sibling")
    expect(gstrs(at(merged("\{\"a\":\{\"+trains\":[\"z\"]\}\}"), "a"), "trains").length == 3, "merge: +key appends")
    expect(strs_eq(gstrs(at(merged("\{\"a\":\{\"-trains\":[\"x\"]\}\}"), "a"), "trains"), [ "y" ]), "merge: -key takes items out")
    let by_id = glist(merged("\{\"list\":[\{\"id\":\"q\",\"t\":9\},\{\"id\":\"p\",\"remove\":true\},\{\"id\":\"r\",\"t\":3\}]\}"), "list")
    expect(by_id.length == 2 and gstr(by_id[0], "id", "") == "q" and as_int(at(by_id[0], "t")) == 9 and gstr(by_id[1], "id", "") == "r", "merge: a list with ids merges item by item")
    expect(glist(merged("\{\"ages\":[\{\"age\":2,\"remove\":true\}]\}"), "ages").length == 1, "merge: ages by their age")
    expect(glist(merged("\{\"plain\":[3]\}"), "plain").length == 1, "merge: other lists are replaced whole")
    let two = data_merge(data_merge(base, parse_json("\{\"b\":\{\"hp\":7\}\}")), parse_json("\{\"b\":\{\"hp\":8\}\}"))
    expect(as_int(at(at(two, "b"), "hp")) == 8, "merge: the later mod wins")

def g_loop_share():
    expect(loop_share(0) == 0.0, "a loop nobody makes is silent")
    expect(loop_share(1) > 0.2, "one unit is heard")
    expect(loop_share(4) > loop_share(1) and loop_share(12) > loop_share(4), "more units are louder")
    expect(loop_share(12) == 1.0 and loop_share(40) == 1.0, "and a crowd adds nothing past the cap")

def g_mods():
    g_loop_share()
    g_merge()
    expect(lib_packs[0].id == "age_of_anything", "packs: the game is the first pack read")
    expect(has(lib_parts, "weapon.spear.wood"), "packs: its parts came through pack_apply")
    let looks = lib_data("shots.json")
    for(looks.keys) k:
        if not starts_with(k, "_"): expect(mod_check_shot(k, at(looks, k)) == "", "shots: the game\'s {k} is sound ({mod_check_shot(k, at(looks, k))})")
    let base_anything = load_rules("anything")
    let base_default = load_rules("default")
    let plain_key = rstr(generate("future soldiers", base_anything, 0), "key")
    expect(not has(lib_parts, "weapon.pulse_rifle") or pack_mods().length > 0, "mods: none used unless asked for")
    let used = mods_use([ "scifi_test" ])
    expect(strs_eq(used, [ "scifi_test" ]), "mods: the example mod loads ({mods_refused.get_keys()})")
    let anything = load_rules("anything")
    expect(has_s(gstrs(anything, "era"), "scifi") and not has_s(gstrs(load_rules("bronze"), "era"), "scifi"), "mods: the rules overlay opens the scifi era where it says")
    let race = generate("future soldiers", anything, 0)
    let sk = (filter(units_of(race)) u: slot_of(u) == "skirmisher")[0]
    expect(architecture(race) == "future", "mods: the future builds its own way (spacefarers: {architecture(race)})")
    expect(part_at(recipe_of(sk), "hand_r") == "weapon.pulse_rifle", "mods: future soldiers carry the pulse rifle ({part_at(recipe_of(sk), "hand_r")})")
    expect(has_s([ "", "helm.visor_sealed" ], part_at(at(last_step(sk), "recipe"), "head_gear")), "mods: an era pack\'s helmet only gives way to its own (upgrade_within)")
    expect(strs_eq(gstrs(race, "mods"), lib_mods) and rstr(race, "key") != plain_key, "mods: the race key holds the mod set")
    expect(rstr(generate("future soldiers", anything, 0), "key") == rstr(race, "key"), "mods: the same prompt gives the same key with the mod")
    let romans = generate("romans", base_default, 0)
    expect(not exists(units_of(romans)) u: exists(line_of(u)) l: exists(part_ids(at(l, "recipe"))) id: has_s(gstrs(part(id), "only_if"), "scifi"), "mods: nobody gets future kit unasked")
    let bronze = generate("future soldiers", load_rules("bronze"), 0)
    expect(exists(notes_of(bronze)) n: contains_text(lowercase(n), "future"), "mods: a host without the era says so (a note)")
    let tags = gstrs(at(sk, "eval"), "tags")
    let shot = gobj(mod_shots, "pulse")
    expect(has_s(tags, gstr(shot, "tag", "-")), "mods: the pulse rifle\'s tags call the mod\'s shot (pulse: {gstr(shot, "tag", "none")})")
    let bad = [ "bad_muzzle", "bad_era", "needs_other", "future_game", "no_game", "bad_file", "clash", "no_hub", "bad_trains", "bad_research", "bad_extends", "bad_age", "new_building", "no_takes", "bad_draw", "bad_knob", "bad_pulses", "bolt_hold", "bad_hit", "bad_hit_sound" ]
    fresh_lib()
    expect(strs_eq(mods_use(append(bad, [ "scifi_test" ]), append(mod_roots, [ "../tests/mods" ])), [ "scifi_test" ]), "mods: broken mods refused, a good one beside them still loads")
    for(bad) id:
        let why = mods_refused.get(id, "")
        expect(why != "" and not starts_with(why, "not found"), "mods: {id} refused for what\'s wrong with it ({why})")
    fresh_lib()
    mods_use([])
    expect(rstr(generate("future soldiers", load_rules("anything"), 0), "key") == plain_key, "mods: off again, the race is as before")

// Order lines lie on the ground (#221): over a hill between two points, every point of a drawn leg is at the ground's
// height there, nothing is drawn where the hill hides the ground, and a leg up it ends on top, where its flag stands.
def g_ground_path():
    let keep_w = W
    let keep_h = H
    let keep_level = level
    let keep_ramp = ramp
    W = 20
    H = 20
    level = map(W * H): 0
    ramp = map(W * H): 0
    for(H) y:
        for(W) x:
            if x >= 8 and x < 12 and y >= 6 and y < 14: level[y * W + x] = 2
    corner_heights()
    expect(lift_at(10000.0, 10000.0) == 40.0, "ground_path: the hill stands in the way")
    let ground_y = fn(m:float2): iso(m.x, m.y).y - lift_at(m.x, m.y) * 1.5
    let legs = [ [ float2 { 4500.0, 10300.0 }, float2 { 15700.0, 10300.0 } ], [ float2 { 4200.0, 4700.0 }, float2 { 15900.0, 15300.0 } ], [ float2 { 15700.0, 10300.0 }, float2 { 10000.0, 10000.0 } ] ]
    for(legs) leg, n:
        let a = leg[0]
        let b = leg[1]
        let start = iso(a.x, a.y)
        let end_at = iso(b.x, b.y)
        let sim_at = fn(p:float2): a + (b - a) * ((p.x - start.x) / (end_at.x - start.x))
        let runs = ground_path(a, b)
        var points = 0
        var at_points = 0.0
        var between = 0.0
        var hidden = 0
        for(runs) pts:
            points += pts.length
            for(pts) p, k:
                let m = sim_at(p)
                at_points = max(at_points, abs(p.y - ground_y(m)))
                if ground_hidden(m): hidden++
                if k + 1 < pts.length:
                    let m1 = sim_at(pts[k + 1])
                    if abs(lift_at(m.x, m.y) - lift_at(m1.x, m1.y)) < 15.0:  // (a step up a cliff face can't follow it: the ground jumps there)
                        for(8) s:
                            let q = p + (pts[k + 1] - p) * (float(s) / 8.0)
                            between = max(between, abs(q.y - ground_y(sim_at(q))))
        print "ground_path: leg {n}: {runs.length} runs, {points} points, off the ground by {at_points} px at them, {between} px between, {hidden} hidden"
        expect(at_points < 0.01, "ground_path: leg {n}: its points are on the ground, off by {at_points} px")
        expect(between < 4.0, "ground_path: leg {n} follows the ground between them, off by {between} px")
        expect(hidden == 0, "ground_path: leg {n} draws nothing behind the hill, {hidden} points are")
    expect(ground_hidden(float2 { 7700.0, 10000.0 }), "ground_path: low ground just behind the hill is hidden")
    expect(not ground_hidden(float2 { 9000.0, 10000.0 }), "ground_path: the hill top is not")
    expect(not ground_hidden(float2 { 12500.0, 10000.0 }), "ground_path: low ground in front of the hill is not")
    expect(ground_path(float2 { 4500.0, 10300.0 }, float2 { 15700.0, 10300.0 }).length == 2, "ground_path: a leg over the hill goes behind it, then comes out on top")
    W = keep_w
    H = keep_h
    level = keep_level
    ramp = keep_ramp
    relief = []
// ------------------------------------------------------------------ the mouse cursor (#222)

// A PNG's size, from its header.
def png_size(path:string) -> int2:
    let d = read_file(path, true)
    if not d: return int2_0
    def be(at:int) -> int: return (d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8) | d[at + 3]
    return int2 { be(16), be(20) }

def g_cursors():
    expect(CURSOR_KINDS.length == 8, "cursors: every order has its kind")
    for([ "pointer", "move", "attack", "wall", "chop", "mine", "forage", "build" ]) kind:
        expect((find(CURSOR_KINDS) k: k == kind) >= 0, "cursors: {kind} is a kind")
    for(CURSOR_KINDS) kind:
        let one = png_size(cursor_image(kind, 1))
        let two = png_size(cursor_image(kind, 2))
        expect(one.x > 0 and one == one.y * int2_1, "cursors: {kind} has a square image ({cursor_image(kind, 1)}: {one})")
        expect(two == one * 2, "cursors: {kind} has its Retina image at twice the size ({two})")
        let hot = cursor_hot(kind)
        expect(hot.x >= 0 and hot.y >= 0 and hot.x < 4 and hot.y < 4, "cursors: {kind}\'s hot spot is its tip, at the top left ({hot})")
    expect(cursor_hot("attack") == int2 { 2, 2 } and cursor_hot("move") == int2 { 2, 1 } and cursor_hot("chop") == int2 { 1, 1 }, "cursors: the hot spots are the art\'s, at the size it was drawn")
    // The OS draws it now: no virtual cursor adding up mouse deltas, nothing relative.
    for([ "game.lobster", "game/cursors.lobster", "game/pad.lobster" ]) f:
        let src = read_file(f)
        expect(src and find_string(src, "vc_") < 0, "cursors: {f} has no virtual cursor")
        expect(src and find_string(src, "gl.cursor(") < 0, "cursors: {f} doesn\'t use relative mode")
        expect(src and find_string(src, "draw_cursor") < 0, "cursors: {f} doesn\'t draw one")
    let ui_src = read_file("game/ui.lobster")
    expect(ui_src and find_string(ui_src, "def mouse_px() -> float2: return if fake_mouse.x >= 0.0: fake_mouse else: float(gl.mouse_pos(0))") >= 0, "cursors: mouse_px reads the OS\'s mouse")
// ------------------------------------------------------------------ fullscreen (#223)

def g_window():
    expect(starts_fullscreen([ "game.lobster", "none", "lobby" ], false), "window: the game starts fullscreen")
    expect(starts_fullscreen([ "none", "lobby", "races:a|b", "watch" ], false), "window: a match from the command line too")
    expect(not starts_fullscreen([ "none", "lobby", "windowed" ], false), "window: the windowed option keeps the window")
    expect(not starts_fullscreen([ "none", "lobby" ], true), "window: so does the setting")
    expect(starts_fullscreen([ "none", "lobby", "fullscreen" ], true), "window: the fullscreen option beats the setting")
    for([ "mute", "selftest", "padtest", "labtest", "prebake", "vbcheck", "propframes", "shot:/tmp/s.png", "perf:20", "reload:5", "record:/tmp/r", "lookframes:a,b" ]) tool:
        expect(not starts_fullscreen([ "none", "lobby", tool ], false), "window: {tool} is a tool: windowed")
    expect(starts_fullscreen([ "none", "lobby", "shot:/tmp/s.png", "fullscreen" ], false), "window: a capture may ask for fullscreen")
    expect(window_flags(false, false) == 0, "window: plain window flags")
    expect(window_flags(true, true) == (gl.window_init_no_vsync | gl.window_init_fullscreen), "window: the flags add up")
    let game = read_file("game.lobster")
    expect(game and find_string(game, "window_flags(no_vsync, window_fullscreen)") >= 0, "window: the game opens with those flags")

// ------------------------------------------------------------------ the fog's look (#334)

def g_fog_look():
    // One grey fog: land never seen looks like land seen before, never black.
    expect(fog_ground_shade(0) == fog_ground_shade(1), "fog: never-seen ground is as bright as ground seen before ({fog_ground_shade(0)} vs {fog_ground_shade(1)})")
    expect(fog_dark(0) == fog_dark(1), "fog: the fog over never-seen ground is the grey of seen-before ground ({fog_dark(0)} vs {fog_dark(1)})")
    expect(fog_prop_shade(0) == fog_prop_shade(1), "fog: resources never seen are as bright as ones seen before")
    expect(fog_ground_shade(2) > fog_ground_shade(1) and fog_dark(2) < fog_dark(1) and fog_prop_shade(2) > fog_prop_shade(1), "fog: what\'s in sight is brighter than what isn\'t")
    for([ 0, 1, 2 ]) f: expect(fog_shows_land(f), "fog: trees, gold, stone, bushes and doodads show under fog {f}")
    // The view uses them: no fog state of its own, no resource hidden by the fog.
    let game = (read_file("game.lobster") or "") + (read_file("game/world_view.lobster") or "") + (read_file("game/world_draw.lobster") or "")  // (the view: ours and Creel's, #433)
    let ground = read_file("game/ground.lobster")
    expect(game and find_string(game, "if fg[c] == 0: 0.12") < 0 and find_string(game, "fog_ground_shade(fg[c])") >= 0, "fog: the ground\'s shade is fog_ground_shade")
    expect(ground and find_string(ground, "if fg[c] == 0: 0.88") < 0 and find_string(ground, "fog_dark(fg[c])") >= 0, "fog: the fog mesh\'s darkness is fog_dark")
    expect(game and find_string(game, "tr_names[tt] == \"tree\") and") < 0, "fog: not just trees show where never seen")
    expect(game and find_string(game, "fog_shows_land(fog[ME][c])") >= 0, "fog: resources and doodads show by fog_shows_land")

// ------------------------------------------------------------------ the top bar fits the window (#370)

def g_topbar():
    let names = [ "Gutterkin", "Third Armored Division", "Fourth Armored Division of the Very Long Name Brigade" ]
    let age_txts = [ "Mud Age", "Mud Age  ->  Bronze Age  45%" ]
    let paces = [ "", "Paused", "x10.0" ]
    var tried = 0
    var off = 0
    var bad_name = 0
    var worst = ""
    for([ 640, 800, 1024, 1280, 1600, 1920, 2560, 3024, 3840 ]) ww:
        for([ 70, 100, 115, 150, 200 ]) hs:
            let ws = float2 { float(ww), float(ww) * 0.625 }
            let s = hud_scale(hs, ws)
            for(names) name:
                for(age_txts) age:
                    for(paces) pace:
                        let t = TbTexts { [ "99999", "99999", "99999", "99999" ], "200/200", name, "4", age, "59:59", pace }
                        let l = tb_layout(t, ws.x, s)
                        tried++
                        if l.w + 10.0 * l.s > ws.x - 10.0 * l.s:
                            off++
                            if worst == "": worst = "{ww} px, hud {hs}: {name} / {age} / {pace}: the bar ends at {l.w + 10.0 * l.s}"
                        let whole = l.title == name
                        let cut = l.title == "" or ends_with(l.title, "...") and starts_with(name, l.title.substring(0, l.title.length - 3))
                        if not (whole or cut) or tb_text_w(l.title, int(22.0 * l.s), 2) > l.title_w: bad_name++
    expect(off == 0, "top bar: inside the window ({off} of {tried} off it; {worst})")
    expect(bad_name == 0, "top bar: the name shown is the race\'s, whole or cut with ..., inside its room ({bad_name} of {tried})")
    // Where there's room the name isn't cut and the scale is the player's.
    let t = TbTexts { [ "300", "200", "0", "0" ], "3/5", "Third Armored Division", "1", "Mud Age  ->  Bronze Age  45%", "0:05", "x10.0" }
    let l = tb_layout(t, 2560.0, hud_scale(115, float2 { 2560.0, 1600.0 }))
    expect(l.title == "Third Armored Division" and l.s == 1.15, "top bar: a long name whole at 2560 px ({l.title}, {l.s})")
    // The plaques' lines in the middle of their insides (#376): clear of the frame, as much room over as under.
    var rows_bad = 0
    var rows_first = ""
    for(17) k:
        let s = 0.4 + 0.1 * float(k)
        for([ false, true ]) ageing:
            let r = tb_rows(s, ageing)
            let ph = 48.0 * s
            let fw = max(1.0, 2.0 * s)
            def ink2(a:float2, b:float2) -> float2: return float2 { min(a.x, b.x), max(a.y, b.y) }
            let icon = float2 { r.age_icon, r.age_icon + 26.0 * s }
            var age = ink2(icon, ink2(tb_ink(r.age_num, int(24.0 * s), 2), tb_ink(r.age_txt, int(17.0 * s), 1)))
            if ageing: age = ink2(age, float2 { r.age_bar, r.age_bar + 5.0 * s })
            let blocks = [ ink2(tb_ink(r.stock, int(20.0 * s), 1), tb_ink(r.work, int(15.0 * s), 1)), tb_ink(r.pop, int(20.0 * s), 1),
                           tb_ink(r.clock, int(18.0 * s), 1), tb_ink(r.pace, int(16.0 * s), 1), age ]
            let what = [ "stock and workers", "population", "clock", "pace", "age" ]
            for(blocks) b, i:
                let over = b.x - fw
                let under = ph - fw - b.y
                if over < 3.0 * s or abs(over - under) > 1.5:
                    rows_bad++
                    if rows_first == "": rows_first = "s {s}{if ageing: " ageing" else: ""}: {what[i]} {over} px over, {under} under"
            // The age's number and name on its icon's middle, the workers on the small worker's.
            let mid = (icon.x + icon.y) / 2.0
            let num = tb_ink(r.age_num, int(24.0 * s), 2)
            let txt = tb_ink(r.age_txt, int(17.0 * s), 1)
            let wk = tb_ink(r.work, int(15.0 * s), 1)
            for([ (num.x + num.y) / 2.0 - mid, (txt.x + txt.y) / 2.0 - mid, (wk.x + wk.y) / 2.0 - (r.work_icon + 7.0 * s) ]) d, i:
                if abs(d) > 1.5:
                    rows_bad++
                    if rows_first == "": rows_first = "s {s}: {[ "age number", "age name", "worker count" ][i]} {d} px off its icon\'s middle"
    expect(rows_bad == 0, "top bar: the plaques\' lines in their middles ({rows_bad} off; {rows_first})")

// ------------------------------------------------------------------ the run

// The atmosphere's data (#411, view/atmosphere.lobster): data/atmosphere.json loads, every mood and glow is sound and
// can be set, the default and the maps' moods are moods, an unknown mood is reported, a broken one is caught, the
// mood of zeros leaves the frame, and a mod's file merges over the game's.
def g_atmosphere():
    let j = lib_data("atmosphere.json")
    let problems = atmo_problems(j)
    expect(not problems.length, "atmosphere: the game\'s atmosphere.json is sound ({problems})")
    let moods = filter(sorted_strs(gobj(j, "moods").keys)) k: not starts_with(k, "_")
    expect(moods.length >= 3, "atmosphere: at least three moods ({moods})")
    for(moods) m: expect(atmo_set(j, m) == "" and atmo_on, "atmosphere: the mood {m} can be set ({atmo_set(j, m)})")
    expect(has_s(moods, atmo_mood_for(j, "flat_test", "")), "atmosphere: a map with no mood of its own gets the default")
    for(gobj(j, "maps").keys) id: expect(has_s(map_ids_on_disk(), id), "atmosphere: the map {id} it names exists")
    expect(atmo_mood_for(j, "flat_test", "") == "late_afternoon", "atmosphere: the default is late_afternoon (#419)")
    for(gobj(j, "maps").keys) id: expect(atmo_mood_for(j, id, "") != "none", "atmosphere: the map {id} isn\'t given none: it is for tests only")
    expect(atmo_mood_for(j, "flat_test", "") != "none", "atmosphere: the default isn\'t none")
    // Dominic (#419): no mood is flat; each has a shadow tint, a highlight tint, haze and bloom.
    for(moods) m:
        if m != "none":
            atmo_set(j, m)
            for([ "shadow", "highlight", "haze", "bloom" ]) knob:
                expect(atmo_nums[find(ATMO_NUMS) k: k == knob] > 0.0, "atmosphere: the mood {m} has some {knob}, not a flat frame")
    // The shade buffer (#481): every mood shades, lightly and cool, warms what's lit a little, and keeps its units
    // readable (Dominic: units must never get lost in shade); the knobs we haven't adopted stay off.
    for(moods) m:
        if m != "none":
            atmo_set(j, m)
            let shade = atmo_opt_num("sun_shade")
            expect(shade > 0.0 and atmo_shading(), "atmosphere: the mood {m} shades ({shade})")
            let sc = atmo_opt_cols[find(ATMO_OPT_COLS) k: k == "shade_colour"]
            // (how much light the shade leaves, as the pass works it out: lit * mix(1, shade_colour, sun_shade))
            let left = 1.0 - shade * (1.0 - (sc.x * 0.299 + sc.y * 0.587 + sc.z * 0.114))
            expect(left >= 0.55 and left <= 0.85, "atmosphere: the mood {m}\'s shade is light: it leaves {left} of the light")
            expect(sc.z > sc.x, "atmosphere: the mood {m}\'s shade is cool ({sc})")
            expect(atmo_opt_num("sun") > 0.0 and atmo_opt_num("sun") <= 0.3, "atmosphere: the mood {m}\'s sun warms a little ({atmo_opt_num("sun")})")
            expect(atmo_opt_num("unit_lift") >= 0.5 and atmo_opt_num("unit_rim") >= 0.3, "atmosphere: the mood {m} keeps its units readable in shade (lift {atmo_opt_num("unit_lift")}, rim {atmo_opt_num("unit_rim")})")
            for([ "paint", "shafts", "low_fog", "deep", "woods", "mist" ]) off:
                expect(atmo_opt_num(off) == 0.0, "atmosphere: the mood {m} leaves {off} off (not adopted, #481)")
    expect(atmo_set(j, "none") == "" and not atmo_shading(), "atmosphere: the mood none doesn\'t shade (the frame as drawn)")
    // Between two moods (atmo_set_between): its ends are the moods, its middle halfway between in every knob.
    atmo_set(j, "late_afternoon")
    let na, oa, ca = atmo_nums, atmo_opt, atmo_opt_cols
    atmo_set(j, "golden_evening")
    let nb, ob, cb = atmo_nums, atmo_opt, atmo_opt_cols
    expect(atmo_set_between(j, "late_afternoon", "golden_evening", 0.0) == "" and equal(atmo_nums, na) and equal(atmo_opt, oa), "atmosphere: between two moods at 0 is the first")
    expect(atmo_set_between(j, "late_afternoon", "golden_evening", 1.0) == "" and equal(atmo_nums, nb) and equal(atmo_opt, ob), "atmosphere: between two moods at 1 is the second")
    expect(atmo_set_between(j, "late_afternoon", "golden_evening", 0.5) == "" and atmo_on, "atmosphere: between two moods can be set")
    for(atmo_nums) v, i: expect(abs(v - (na[i] + nb[i]) / 2.0) < 0.0001, "atmosphere: halfway between two moods, {ATMO_NUMS[i]} is halfway ({v})")
    for(atmo_opt) v, i: expect(abs(v - (oa[i] + ob[i]) / 2.0) < 0.0001, "atmosphere: halfway between two moods, {ATMO_OPT[i]} is halfway ({v})")
    for(atmo_opt_cols) v, i: expect(magnitude(v - (ca[i] + cb[i]) / 2.0) < 0.0001, "atmosphere: halfway between two moods, {ATMO_OPT_COLS[i]} is halfway ({v})")
    let mid = atmo_opt
    expect(atmo_set_asked(j, "late_afternoon~golden_evening@0.5") == "" and equal(atmo_opt, mid), "atmosphere: atmosphere:<a>~<b>@<t> sets the light between two moods")
    expect(atmo_set_asked(j, "golden_evening") == "" and equal(atmo_opt, ob), "atmosphere: atmosphere:<mood> still sets a mood by name")
    let unknown_b = atmo_set_between(j, "late_afternoon", "purple_haze", 0.5)
    expect(contains_text(unknown_b, "no mood \'purple_haze\'"), "atmosphere: between a mood and an unknown one is reported ({unknown_b})")
    expect(atmo_mood_for(j, "reed_meadow", "misty_morning") == "misty_morning", "atmosphere: atmosphere:<mood> wins over the map\'s")
    let unknown = atmo_set(j, "purple_haze")
    expect(contains_text(unknown, "no mood \'purple_haze\'") and not atmo_on, "atmosphere: an unknown mood is reported ({unknown})")
    expect(atmo_set(j, "off") == "" and not atmo_on, "atmosphere: off sets no mood")
    expect(atmo_set(j, "none") == "" and all_of(atmo_nums) v: v == 0.0 or v == 1.0, "atmosphere: the mood none is all zeros (the frame as drawn)")
    let broken = parse_json("\{ \"moods\": \{ \"clear_noon\": \{ \"haze\": 3, \"sparkle\": 1 \} \}, \"default\": \"dusk\", \"glows\": \{ \"lava\": \{ \} \} \}")
    let found = atmo_problems(data_merge(j, broken))
    for([ "\'haze\' must be", "no knob \'sparkle\'", "the default \'dusk\'", "no glow source \'lava\'" ]) want:
        expect(exists(found) p: contains_text(p, want), "atmosphere: a broken file is caught: {want} ({found})")
    let modded = data_merge(j, parse_json("\{ \"moods\": \{ \"red_dusk\": \{ \"extends\": \"golden_evening\", \"highlight_tint\": \"#ff4020\" \} \}, \"default\": \"red_dusk\" \}"))
    expect(not atmo_problems(modded).length and atmo_mood_for(modded, "flat_test", "") == "red_dusk", "atmosphere: a mod\'s mood merges over the game\'s and becomes the default ({atmo_problems(modded)})")
    atmo_set(j, "off")

// ------------------------------------------------------------------ typing into a box (#431)

def g_text_field():
    expect(tf_drop_last("romans") == "roman", "text field: backspace takes the last letter off ({tf_drop_last("romans")})")
    expect(tf_drop_last("") == "", "text field: backspace on an empty box leaves it empty")
    expect(tf_drop_last("a") == "", "text field: backspace takes the only letter")
    expect(tf_drop_last("caf\xc3\xa9") == "caf", "text field: backspace takes a whole two-byte letter ({tf_drop_last("caf\xc3\xa9").length} bytes left)")
    expect(tf_drop_last("x\xe2\x82\xac") == "x", "text field: and a whole three-byte one")
    var s = "sewer rats"
    for(4): s = tf_drop_last(s)
    expect(s == "sewer ", "text field: four backspaces take four letters ({s})")
    // a held backspace: once on the press, nothing more until the delay, then repeating
    expect(tf_repeats(-1.0, 0.016) == 1, "text field: a key fires once when pressed ({tf_repeats(-1.0, 0.016)})")
    expect(tf_repeats(0.016, 0.032) == 0, "text field: a held key doesn\'t fire every frame")
    var fired = 0
    var held = -1.0
    for(60):  // a second at 60 fps
        let now = max(0.0, held) + 1.0 / 60.0
        fired += tf_repeats(held, now)
        held = now
    expect(fired >= 12 and fired <= 16, "text field: a second\'s hold takes about a dozen letters ({fired})")
    // the caret: lit straight after a click or a key, then blinking
    expect(tf_caret_on(0.0) and tf_caret_on(0.3), "text field: the caret is lit right after a click")
    var lit = 0
    for(40) k: if tf_caret_on(1.0 + float(k) * 0.05): lit++
    expect(lit > 10 and lit < 30, "text field: then it blinks ({lit} of 40 lit)")

def map_ids_on_disk() -> [string]:
    let names = scan_folder("../data/maps", false)
    return if names: map(filter(names) n: ends_with(n, ".json")) n: substring(n, 0, n.length - 5) else: []

let GROUPS = [ "data", "determinism", "bounds", "prompts", "healers", "siege", "swordsmen", "kits", "new_lines", "cat", "audio", "tech_tree", "identity", "heroes", "mods", "ground_path", "cursors", "window", "fog_look", "topbar", "atmosphere", "text_field" ]

def run_group(name:string):
    switch name:
        case "data": g_data()
        case "determinism": g_determinism()
        case "bounds": g_bounds()
        case "prompts": g_prompts()
        case "healers": g_healers()
        case "siege": g_siege()
        case "swordsmen": g_swordsmen()
        case "kits": g_kits()
        case "new_lines": g_new_lines()
        case "cat": g_cat()
        case "audio": g_audio()
        case "tech_tree": g_tech_tree()
        case "identity": g_identity()
        case "heroes": g_heroes()
        case "mods": g_mods()
        case "ground_path": g_ground_path()
        case "cursors": g_cursors()
        case "window": g_window()
        case "fog_look": g_fog_look()
        case "topbar": g_topbar()
        case "atmosphere": g_atmosphere()
        case "text_field": g_text_field()
        default: assert false

var shard = 0
var shards = 1
for(command_line_arguments()) arg:
    if starts_with(arg, "part:"):
        let ij = tokenize(substring(arg, 5, arg.length - 5), "/", "")
        shard = string_to_int(ij[0])
        shards = string_to_int(ij[1])
fresh_lib()
let t_start = seconds_elapsed()
for(GROUPS) name, k:
    if k % shards == shard:
        let t0 = seconds_elapsed()
        let before = n_checks
        run_group(name)
        print "-- {name}: {n_checks - before} checks, {int((seconds_elapsed() - t0) * 1000.0)} ms"
print "\n{n_checks} checks, {n_failed} failed ({int((seconds_elapsed() - t_start) * 1000.0)} ms)"
if n_failed > 0: set_exit_code(1)
