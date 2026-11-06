// ------------------------------------------------------------------ the race generator (src/race_generator.gd)
// Prompt -> race, deterministic: the same prompt, rules and reroll give the same race everywhere.
// Words map to tags (data/lexicon.json), tags pick parts, parts become unit recipes. The race key
// hashes the recipes (sha256 of Godot's sorted JSON), so it matches the GDScript generator's.

let SIGNATURE_TAGS = [ "roman", "greek", "viking", "cheese", "woodland", "knight", "bat", "crossbow", "junk", "saucepan", "nile", "han", "aztec", "norse" ]
let KIND_TAGS = [ "spear", "lance", "blade", "blunt", "bow", "sling", "javelin", "poison", "gun", "worker",
                  "shield", "helmet", "hat", "armour", "cape", "banner", "wings", "quiver" ]
let OPTIONAL_SLOTS = [ "hand_l", "head_gear", "torso", "back" ]
let HEALER_SLOTS = [ "hand_l", "head_gear", "back" ]
let SCOUT_SLOTS = [ "head_gear", "torso", "back" ]
let SAPPER_SLOTS = [ "head_gear" ]
let WORKER_SLOTS = [ "head_gear" ]
let EPITHET_SLOTS = [ "hand_r", "torso" ]
let LIGHT_ROLES = [ "scout", "sapper" ]
let LIGHT_POINTS = 2
let GIANT_SCALE = 150
let TINY_SCALE = 80

def role_needs(role:string) -> string:
    switch role:
        case "worker": return "worker"
        case "spear": return "spear"
        case "skirmisher": return "ranged"
        case "archer", "mounted_archer": return "bow"
        case "large", "infantry", "scout": return "melee"
        case "healer": return "heal"
        case "siege_tower": return "docks"
        default: return role  // ram, catapult, bolt_thrower, sapper, great_sling, war_beast
def role_excludes(role:string) -> [string]:
    switch role:
        case "skirmisher": return [ "bow" ]
        case "infantry": return [ "spear", "lance" ]
        case "scout": return [ "spear", "lance", "heavy" ]
        default: return []
def role_kinds(role:string) -> [string]: return if role == "infantry" or role == "scout": [ "blade" ] else: []
def int_map(keys:[string], vals:[int]) -> JV:
    let o = jobj()
    for(keys) k, n: set(o, k, jint(vals[n]))
    return o
def role_bias(role:string) -> JV:
    switch role:
        case "spear": return int_map([ "reach" ], [ 1 ])
        case "skirmisher": return int_map([ "skirmish" ], [ 2 ])
        case "large": return int_map([ "charge", "heavy", "lance" ], [ 3, 2, 3 ])
        case "infantry": return int_map([ "blade" ], [ 1 ])
        case "scout": return int_map([ "blade", "light" ], [ 1, 2 ])
        default: return jobj()
let HEAVY_BOOST = int_map([ "heavy", "armour", "helmet", "shield" ], [ 3, 3, 2, 1 ])
let HEALER_WANTS = int_map([ "heal" ], [ 3 ])

// ---- the race being made (GDScript's ctx)

class Brief:
    creatures:[string] = []
    default_creatures:[string] = []
    mounts:[string] = []
    mount_wings = ""
    families:[string] = []
    tags = jobj()
    body_size = ""
    notes:[string] = []
    unknown:[string] = []
    heroes:[string] = []
    colours:[string] = []

var g_rng = new_rng(1)
var g_rules = jobj()
var g_eras:[string] = []
var g_brief = Brief {}
var g_tags = jobj()
var g_creature = ""
var g_family = ""
var g_skin = ""
var g_notes:[string] = []
var g_firsts = jobj()
var g_age = 99
var g_crew:JV? = nil
var g_affinity:[string] = []
var g_no_restrictions = false

def tget(o:JV, k:string) -> int: return gint(o, k, 0)
def tadd(o:JV, k:string, n:int): set(o, k, jint(tget(o, k) + n))
def ptags(p:JV) -> [string]: return gstrs(p, "tags")
def pts(p:JV) -> int: return as_int(at(p, "points"))
def ptier(p:JV) -> int: return gint(p, "tier", 1)
def rparts(r:JV) -> JV: return at(r, "parts")

// ---- the prompt

def normalize_prompt(prompt:string) -> string:
    let low = lowercase(prompt)
    var cleaned = ""
    for(low.length) n:
        let ch = low[n]
        cleaned += if (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9'): unicode_to_string([ ch ]) else: " "
    return concat_string(prompt_words(cleaned), " ")

def lookup(word:string) -> string:
    if has(lib_lexicon, word): return word
    let endings = [ [ "ies", "y" ], [ "es", "" ], [ "s", "" ] ]
    for(endings) e:
        if ends_with(word, e[0]):
            let stem = substring(word, 0, word.length - e[0].length) + e[1]
            if has(lib_lexicon, stem): return stem
    return ""

def interpret(prompt:string, rules:JV) -> Brief:
    let brief = Brief {}
    var riding = false
    let eras = gstrs(rules, "era")
    for(prompt_words(normalize_prompt(prompt))) raw:
        if not has_s(lib_stopwords, raw):
            let word = lookup(raw)
            if word == "":
                brief.unknown.push(raw)
            else:
                let entry = at(lib_lexicon, word)
                var tags = gobj(entry, "tags")
                if has(entry, "era") and not has_s(eras, rstr(entry, "era")):
                    push_new(brief.notes, rstr(entry, "note"))
                    tags = gobj(entry, "substitute")
                let as_mount = has(entry, "mount") and (riding or not has(entry, "creature"))
                if has(entry, "creature") and not as_mount: push_new(brief.creatures, rstr(entry, "creature"))
                if has(entry, "default_creature"): push_new(brief.default_creatures, rstr(entry, "default_creature"))
                if as_mount: push_new(brief.mounts, rstr(entry, "mount"))
                if tget(tags, "mounted") >= 2: riding = true
                if has(entry, "mount_wings"): brief.mount_wings = rstr(entry, "mount_wings")
                if has(entry, "family"): push_new(brief.families, rstr(entry, "family"))
                if has(entry, "size"): brief.body_size = rstr(entry, "size")
                if has(entry, "colour"): push_new(brief.colours, rstr(entry, "colour"))
                if has(entry, "hero"): push_new(brief.heroes, rstr(entry, "hero"))
                for(tags.keys) t, n: tadd(brief.tags, t, as_int(tags.a[n]))
    return brief

// ---- the race

def quoted(xs:[string], sep:string) -> string: return concat_string(map(xs) w: "\'" + w + "\'", sep)

def generate(prompt:string, rules:JV, reroll:int) -> JV:
    let norm = normalize_prompt(prompt)
    let rules_id = rstr(rules, "id")
    let rng = new_rng(hash_text(norm + "|" + rules_id + "|" + string(reroll)))
    let brief = interpret(prompt, rules)
    let notes = copy(brief.notes)
    var cid = ""
    if brief.creatures.length: cid = brief.creatures[0]
    elif brief.default_creatures.length: cid = brief.default_creatures[0]
    else:
        cid = rpick(rng, creature_ids("playable"))
        notes.push("Nobody said who, so the " + rstr(creature(cid), "plural") + " volunteered.")
    let c = creature(cid)
    let fid = if brief.families.length: brief.families[0] else: as_str(rpick(rng, glist(c, "families")))
    g_affinity = [ cid, fid ]
    g_no_restrictions = gbool(rules, "no_restrictions", false)
    let tags = shallow_copy(brief.tags)
    tadd(tags, fid, 2)
    tadd(tags, cid, 2)
    if brief.unknown.length: notes.push("No idea what " + quoted(brief.unknown, ", ") + " means, so we ignored it.")
    g_rng = rng
    g_rules = rules
    g_eras = gstrs(rules, "era")
    g_brief = brief
    g_tags = tags
    g_creature = cid
    g_family = fid
    g_notes = notes
    g_skin = rpick(rng, race_skins(c, fid, brief.colours, notes))
    g_firsts = jobj()
    g_crew = nil
    let slots = filter(glist(rules, "roster")) sd: not has_s([ "planned", "parked" ], gstr(sd, "status", "")) and rstr(sd, "role") != "hero"
    let rngs = map(slots) sd: if gbool(sd, "own_seed", false): new_rng(hash_text(norm + "|" + rules_id + "|" + string(reroll) + "|" + rstr(sd, "slot"))) else: rng
    let lacks = []::string
    let units = []::JV?
    for(slots) sd, k:
        g_age = as_int(at(sd, "tier"))
        g_rng = rngs[k]
        var why = lacks_why(sd, units)
        let recipe = if why != "": nil else: make_unit(sd)
        if not recipe:
            if why == "": why = "nothing will carry them"
            lacks.push(rstr(sd, "slot"))
            notes.push("No " + rstr(sd, "name") + " line: " + why + ".")
            units.push(nil)
        else:
            if rstr(sd, "slot") == "worker": g_crew = recipe
            set(g_firsts, rstr(sd, "slot"), recipe)
            let ev = evaluate(recipe, rules, g_age)
            units.push(unit_entry(recipe, ev, [ line_step(g_age, recipe, ev) ]))
    for(units) u, k:
        if u:
            let sd = slots[k]
            g_rng = rngs[k]
            var age = as_int(at(sd, "tier")) + 1
            while age <= gint(rules, "ages", 1):
                g_age = age
                let line = at(u, "line")
                let last = at(line.a[line.a.length - 1], "recipe")
                let up = if not gbool(sd, "upgrades", true): last else: upgrade(last, sd)
                line.a.push(line_step(age, up, evaluate(up, rules, age)))
                age++
    g_rng = rng
    for(units) u, k:
        let cs = gstr(slots[k], "crew", "")
        if u and cs != "":
            for(units) uj, j:
                if uj and rstr(slots[j], "slot") == cs:
                    let jl = glist(uj, "line")
                    var by = at(jl[0], "recipe")
                    for(jl) l:
                        if as_int(at(l, "age")) <= as_int(at(slots[k], "tier")): by = at(l, "recipe")
                    let crew = crew_from(by, true)
                    for(gstrs(slots[k], "crew_drop")) slot: erase(at(crew, "parts"), slot)
                    for(glist(u, "line")) l: set(at(l, "recipe"), "crew", deep_copy(crew))
    let kept = []::JV
    for(units) u:
        if u: kept.push(u)
    let race = jobj()
    set(race, "schema", jstr("aow.race/1"))
    set(race, "name", jstr(race_name(rng, c, fid)))
    set(race, "prompt", jstr(prompt))
    set(race, "rules", jstr(rules_id))
    set(race, "reroll", jint(reroll))
    set(race, "creature", jstr(cid))
    set(race, "family", jstr(fid))
    let notes_v = jarr([])
    set(race, "notes", notes_v)
    set(race, "units", jarr(kept))
    set(race, "lacks", jstrs(lacks))
    let asked = heroes_asked(brief.heroes, cid, fid)
    if asked.length: set(race, "hero_asked", jstr(asked[0]))
    if asked.length > 1:
        notes.push("Only one hero leads a race, so " + said_heroes(prompt, [ asked[0] ]) + " came and " + said_heroes(prompt, asked.slice(1, -1)) + " stayed home.")
    let strays = filter(brief.heroes) sid: not has_s(asked, sid)
    if strays.length:
        let who = lowercase(rstr(c, "plural"))
        notes.push(if not asked.length: "Nobody called " + said_heroes(prompt, strays) + " leads " + who + ", so one of their own came instead."
                   else: "Nobody called " + said_heroes(prompt, strays) + " leads " + who + ".")
    notes_v.a = map(notes) n: jstr(n)
    if lib_mods.length: set(race, "mods", jstrs(lib_mods))
    set(race, "key", jstr(race_key(race)))
    let heroes = heroes_make(race, rules)
    if heroes.length:
        for(heroes) h: at(race, "units").a.push(h)
        set(race, "heroes", jarr(heroes_info(race)))
    return race

// The hash of the shareable part only (names, recipes, the hero the prompt named).
def race_key(race:JV) -> string:
    let sh = jobj()
    set(sh, "schema", at(race, "schema"))
    set(sh, "name", at(race, "name"))
    set(sh, "creature", at(race, "creature"))
    set(sh, "family", at(race, "family"))
    let recipes = jarr([])
    for(glist(race, "units")) u:
        if rstr(at(u, "recipe"), "slot") != "hero":
            if has(u, "line"): recipes.a.push(jarr(map(glist(u, "line")) l: at(l, "recipe")))
            else: recipes.a.push(jarr([ at(u, "recipe") ]))
    set(sh, "recipes", recipes)
    if has(race, "hero_asked"): set(sh, "hero_asked", at(race, "hero_asked"))
    if has(race, "mods"): set(sh, "mods", at(race, "mods"))
    return sha256_text(stringify(sh))

def said_heroes(prompt:string, sids:[string]) -> string: return concat_string(map(sids) sid: "\'" + hero_word(prompt, sid) + "\'", " or ")

def hero_word(prompt:string, sid:string) -> string:
    for(prompt_words(normalize_prompt(prompt))) raw:
        let word = lookup(raw)
        if word != "" and gstr(at(lib_lexicon, word), "hero", "") == sid: return raw
    return sid

def race_name(rng:Rng, c:JV, fid:string) -> string:
    let f = family(fid)
    if chance(rng, 30): return rstr(f, "adjective") + " " + rstr(c, "plural")
    let pre = rpick(rng, gstrs(f, "prefixes"))
    return pre + rpick(rng, gstrs(f, "suffixes"))

// ---- units

def new_recipe(sd:JV, role:string) -> JV:
    let c = creature(g_creature)
    let r = jobj()
    set(r, "slot", at(sd, "slot"))
    set(r, "role", jstr(role))
    set(r, "tier", jint(as_int(at(sd, "tier"))))
    set(r, "creature", jstr(g_creature))
    set(r, "family", jstr(g_family))
    set(r, "skin", jstr(g_skin))
    set(r, "body", at(c, "body"))
    set(r, "head", at(c, "head"))
    set(r, "parts", jobj())
    set(r, "scale", jint(100))
    return r

def make_unit(sd:JV) -> JV?:
    if has(sd, "engine"): return make_engine(sd)
    if rstr(sd, "role") == "unique": return make_unique(sd)
    let rng = g_rng
    let brief = g_brief
    let role = rstr(sd, "role")
    let tier = as_int(at(sd, "tier"))
    let budget = as_int(at(at(g_rules, "budget"), string(max(tier, g_age))))
    let c = creature(g_creature)
    let body = part(rstr(c, "body"))
    let recipe = new_recipe(sd, role)
    var spent = pts(body)
    let giant_ok = gbool(c, "giant_ok", true) or brief.body_size == "giant"
    var heavy = false
    if has(c, "fused_mount"):
        set(recipe, "mount", mount_for(rstr(c, "fused_mount"), true, rng, brief, g_skin))
        spent += mount_points(at(recipe, "mount"))
        if role == "large":
            if brief.body_size == "giant":
                set(recipe, "scale", jint(GIANT_SCALE))
                spent += GIANT_POINTS
            else: heavy = true
    elif role == "large":
        let m = choose_mount(not gbool(c, "giant_ok", true))
        if m != "" and brief.body_size != "giant":
            set(recipe, "mount", mount_for(m, false, rng, brief, g_skin))
            spent += mount_points(at(recipe, "mount"))
        elif giant_ok:
            set(recipe, "scale", jint(GIANT_SCALE))
            spent += GIANT_POINTS
        else: heavy = true
    elif has(sd, "mount"):
        let m = choose_mount(true)
        if m != "":
            set(recipe, "mount", mount_for(m, false, rng, brief, g_skin))
            spent += mount_points(at(recipe, "mount"))
        elif rstr(sd, "mount") == "always": return nil
    elif role == "archer" and tget(g_tags, "mounted") >= 2:
        let m = choose_mount(false)
        if m != "":
            let mv = mount_for(m, false, rng, brief, g_skin)
            if spent + mount_points(mv) + 4 <= budget:
                set(recipe, "mount", mv)
                spent += mount_points(mv)
    if brief.body_size == "tiny" and as_int(at(recipe, "scale")) == 100: set(recipe, "scale", jint(TINY_SCALE))
    let need = role_needs(role)
    let excluded = role_excludes(role)
    let options = filter(cands("hand_r")) p: has_s(ptags(p), need) and not any_in(ptags(p), excluded) and allowed(p, role, g_tags)
    var affordable = filter(options) p: spent + pts(p) <= budget
    if not affordable.length: affordable = [ cheapest(options) ]
    let unit_tags = shallow_copy(g_tags)
    if heavy:
        set(recipe, "elite", jstr("heavy"))
        for(HEAVY_BOOST.keys) t, n: tadd(unit_tags, t, as_int(HEAVY_BOOST.a[n]))
    if role == "healer":
        for(HEALER_WANTS.keys) t, n: tadd(unit_tags, t, as_int(HEALER_WANTS.a[n]))
    let primary = best(affordable, unit_tags, role_bias(role), rng)
    set(rparts(recipe), "hand_r", at(primary, "id"))
    spent += pts(primary)
    let mount = get(recipe, "mount")
    let ridden = mount and not gbool(mount, "fused", false)
    if mount and ridden and not has(at(mount, "parts"), "back"):
        let wings = filter(cands("back")) p: has_s(ptags(p), "wings") and allowed(p, role, unit_tags)
        if wings.length:
            let w = best(wings, unit_tags, jobj(), rng)
            if spent + pts(w) <= budget:
                set(at(mount, "parts"), "back", at(w, "id"))
                spent += pts(w)
    if has(sd, "noun"): set(recipe, "noun", at(sd, "noun"))
    set(recipe, "name", jstr(unit_name(recipe, primary, c)))
    let picks_slot = []::string
    let picks_part = []::JV
    let picks_score = []::int
    for(shuffled(rng, gear_slots(role))) slot:
        if not (slot == "hand_l" and gbool(primary, "two_handed", false)):
            var cs = filter(cands(slot)) p: allowed(p, role, unit_tags) and fits_mount(p, recipe)
            if ridden and not winged(unit_tags): cs = filter(cs) p: not has_s(ptags(p), "wings")
            if role == "worker": cs = filter(cs) p: pts(p) <= 1
            if role == "healer": cs = filter(cs) p: healer_gear(p, unit_tags)
            if has_s(LIGHT_ROLES, role): cs = filter(cs) p: light(p)
            cs = filter(cs) p: not off_theme(p, unit_tags)
            if cs.length:
                let b = best(cs, unit_tags, role_bias(role), rng)
                picks_slot.push(slot)
                picks_part.push(b)
                picks_score.push(want(b, unit_tags))
    let order = map(picks_slot.length) n: n
    insertion_sort(order) a, b: picks_score[a] > picks_score[b]
    for(order) n:
        let p = picks_part[n]
        if spent + pts(p) <= budget:
            if picks_score[n] > 0 or chance(rng, 45):
                set(rparts(recipe), picks_slot[n], at(p, "id"))
                spent += pts(p)
    return recipe

// A siege engine: its culture's (or creature's) take on the engine, the weapon made for the role,
// crewed by the race's workers.
def make_engine(sd:JV) -> JV:
    let c = creature(g_creature)
    let field = gstr(sd, "take", "siege")
    let take = gstr(c, field, rstr(family(g_family), field))
    let body = part("siege." + rstr(sd, "engine") + "." + take)
    let ps = jobj()
    if gbool(sd, "armed", true):
        let weapons = filter(cands("hand_r")) p: has(p, "requires_role") and for_role(p, rstr(sd, "role"))
        assert weapons.length
        set(ps, "hand_r", at(best(weapons, g_tags, jobj(), g_rng), "id"))
    let source = get(g_firsts, gstr(sd, "crew", "worker")) or g_crew
    let crew = crew_from(source or jobj(), has(sd, "crew"))
    let e = jobj()
    set(e, "slot", at(sd, "slot"))
    set(e, "role", at(sd, "role"))
    set(e, "tier", jint(as_int(at(sd, "tier"))))
    set(e, "creature", jstr(g_creature))
    set(e, "family", jstr(g_family))
    set(e, "skin", jstr(g_skin))
    set(e, "body", at(body, "id"))
    set(e, "head", jstr(""))
    set(e, "parts", ps)
    set(e, "scale", jint(100))
    set(e, "name", at(body, "noun"))
    set(e, "crew", crew)
    if has(body, "haul"): set(e, "haul", deep_copy(at(body, "haul")))
    return e

def crew_from(r:JV, as_itself:bool) -> JV:
    let crew = jobj()
    set(crew, "body", at(r, "body"))
    set(crew, "head", at(r, "head"))
    set(crew, "skin", at(r, "skin"))
    set(crew, "parts", shallow_copy(at(r, "parts")))
    set(crew, "scale", at(r, "scale"))
    if has(r, "mount"): set(crew, "mount", deep_copy(at(r, "mount")))
    if gstr(part(rstr(r, "body")), "crew", "") == "wide": set(crew, "wide", jint(1))
    if as_itself:
        set(crew, "slot", at(r, "slot"))
        set(crew, "role", at(r, "role"))
        set(crew, "tier", jint(as_int(at(r, "tier"))))
        set(crew, "name", jstr(gstr(r, "name", "")))
    return crew

def lacks_why(sd:JV, units:[JV?]) -> string:
    let c = creature(g_creature)
    if gbool(sd, "needs_hands", false) and gbool(c, "harness", false):
        return "the " + lowercase(rstr(c, "plural")) + " have no hands to draw a bow on a mount"
    let other = gstr(sd, "unless_mounted", "")
    for(units) u:
        if u:
            let r = at(u, "recipe")
            if rstr(r, "slot") == other and has(r, "mount"): return "the " + lowercase(rstr(c, "plural")) + " ride already as " + other + "s"
    return ""

def fits_mount(p:JV, recipe:JV) -> bool:
    if has_s(gstrs(p, "not_worn_by"), rstr(recipe, "body")): return false
    let m = get(recipe, "mount")
    return not (m and not gbool(m, "fused", false) and has_s(gstrs(p, "not_ridden_on"), rstr(m, "creature")))

def light(p:JV) -> bool:
    if rstr(p, "slot") == "back": return has_s(ptags(p), "wings")
    return not has_s(ptags(p), "heavy") and pts(p) <= LIGHT_POINTS

def unique_theme() -> string:
    var best_id = ""
    var best_n = 0
    for(sorted_strs(lib_uniques.keys)) id:
        var n = 0
        for(gstrs(at(lib_uniques, id), "asked")) t: n += tget(g_brief.tags, t)
        if n > best_n:
            best_n = n
            best_id = id
    if best_id != "": return best_id
    return gstr(creature(g_creature), "unique", rstr(family(g_family), "unique"))

def make_unique(sd:JV) -> JV:
    let id = unique_theme()
    let th = at(lib_uniques, id)
    let rng = g_rng
    let role = rstr(th, "role")
    let budget = as_int(at(at(g_rules, "budget"), string(g_age))) + gint(sd, "budget_add", 0)
    let c = creature(g_creature)
    let recipe = jobj()
    set(recipe, "slot", at(sd, "slot"))
    set(recipe, "role", at(sd, "role"))
    set(recipe, "unique", jstr(id))
    set(recipe, "tier", jint(as_int(at(sd, "tier"))))
    set(recipe, "creature", jstr(g_creature))
    set(recipe, "family", jstr(g_family))
    set(recipe, "skin", jstr(g_skin))
    set(recipe, "body", at(c, "body"))
    set(recipe, "head", at(c, "head"))
    set(recipe, "parts", jobj())
    set(recipe, "scale", jint(100))
    let rp = rparts(recipe)
    var spent = pts(part(rstr(c, "body")))
    let unit_tags = shallow_copy(g_tags)
    let wants = gobj(th, "wants")
    for(wants.keys) t, n: tadd(unit_tags, t, as_int(wants.a[n]))
    if has(c, "fused_mount"): set(recipe, "mount", mount_for(rstr(c, "fused_mount"), true, rng, g_brief, g_skin))
    elif gstr(th, "mount", "") == "ride":
        let m = choose_mount(true)
        if m != "": set(recipe, "mount", mount_for(m, false, rng, g_brief, g_skin))
    if has(recipe, "mount"): spent += mount_points(at(recipe, "mount"))
    elif gbool(th, "giant", false) and gbool(c, "giant_ok", true):
        set(recipe, "scale", jint(GIANT_SCALE))
        spent += GIANT_POINTS
    if g_brief.body_size == "tiny" and as_int(at(recipe, "scale")) == 100: set(recipe, "scale", jint(TINY_SCALE))
    let is_light = gbool(th, "light", false)
    for(gstrs(th, "parts")) pid:
        let p = part(pid)
        let pslot = rstr(p, "slot")
        if not (has(rp, pslot) or ptier(p) > g_age or not era_ok(p, g_eras)):
            if not (pslot == "hand_l" and has(rp, "hand_r") and gbool(part(rstr(rp, "hand_r")), "two_handed", false)):
                set(rp, pslot, jstr(pid))
                spent += pts(p)
    if not has(rp, "hand_r"):
        let need = role_needs(role)
        let excluded = role_excludes(role)
        let options = filter(cands("hand_r")) p: has_s(ptags(p), need) and not any_in(ptags(p), excluded) and allowed(p, role, unit_tags) and not (is_light and has_s(ptags(p), "heavy"))
        let affordable = filter(options) p: spent + pts(p) <= budget
        let primary = best(if affordable.length: affordable else: [ cheapest(options) ], unit_tags, role_bias(role), rng)
        set(rp, "hand_r", at(primary, "id"))
        spent += pts(primary)
    let mount = get(recipe, "mount")
    let ridden = mount and not gbool(mount, "fused", false)
    for(OPTIONAL_SLOTS) slot:
        if not (has(rp, slot) or (slot == "hand_l" and gbool(part(rstr(rp, "hand_r")), "two_handed", false))):
            var cs = filter(cands(slot)) p: allowed(p, role, unit_tags) and not off_theme(p, unit_tags) and (not is_light or light(p)) and
                not (ridden and has_s(ptags(p), "wings") and not winged(unit_tags)) and fits_mount(p, recipe)
            cs = filter(cs) p: spent + pts(p) <= budget
            if cs.length:
                let b = best(cs, unit_tags, role_bias(role), rng)
                if want(b, unit_tags) > 0 or chance(rng, 45):
                    set(rp, slot, at(b, "id"))
                    spent += pts(b)
    let noun = rstr(th, "noun")
    set(recipe, "name", jstr(if rstr(c, "noun") == "Folk" or has_s(gstrs(th, "own"), g_creature): noun else: rstr(c, "noun") + " " + noun))
    return recipe

def gear_slots(role:string) -> [string]:
    switch role:
        case "worker": return WORKER_SLOTS
        case "healer": return HEALER_SLOTS
        case "scout": return SCOUT_SLOTS
        case "sapper": return SAPPER_SLOTS
        default: return OPTIONAL_SLOTS

def healer_gear(p:JV, tags:JV) -> bool:
    switch rstr(p, "slot"):
        case "hand_l": return has_s(ptags(p), "heal")
        case "head_gear": return pts(p) <= 1 and not any_in(ptags(p), [ "crest", "horns", "heavy" ])
        case "back": return has_s(ptags(p), "wings") and winged(tags)
        default: return false

def allowed(p:JV, role:string, tags:JV) -> bool:
    if has(p, "requires_role") and not for_role(p, role): return false
    if has(p, "only_if"): return exists(gstrs(p, "only_if")) t: tget(tags, t) > 0
    return true

def own_part(p:JV) -> bool:
    return (has(p, "favour") and any_in(ptags(p), g_affinity)) or want(p, g_brief.tags) > 0

def for_role(p:JV, role:string) -> bool:
    let rr = at(p, "requires_role")
    if rr.kind == J_ARR: return has_str(rr.a, role)
    return as_str(rr) == role

def want(p:JV, tags:JV) -> int:
    var s = 0
    for(ptags(p)) t: s += tget(tags, t)
    return s

def best(cs:[JV], tags:JV, bias:JV, rng:Rng) -> JV:
    var out = cs[0]
    var best_score = -1000000
    for(cs) p:
        var s = 0
        for(ptags(p)) t: s += 10 * tget(tags, t) + 10 * tget(bias, t)
        if off_theme(p, tags): s -= 100
        if has(p, "favour") and any_in(ptags(p), g_affinity): s += 10 * as_int(at(p, "favour"))
        s += range_int(rng, 0, 7)
        if s > best_score:
            best_score = s
            out = p
    return out

def off_theme(p:JV, tags:JV) -> bool:
    if g_no_restrictions: return false
    if any_in(ptags(p), g_affinity): return false
    return exists(ptags(p)) t: has_s(SIGNATURE_TAGS, t) and tget(tags, t) == 0

def cheapest(cs:[JV]) -> JV:
    var out = cs[0]
    for(cs) p:
        if pts(p) < pts(out): out = p
    return out

def choose_mount(always:bool) -> string:
    let cc = creature(g_creature)
    for(g_brief.mounts) m:
        if m != g_creature and rides(m, g_creature): return m
        if m != g_creature:
            let note = rstr(creature(m), "plural") + " won\'t carry " + lowercase(rstr(cc, "plural")) + ", so they go on foot."
            push_new(g_notes, note)
    if winged(g_tags): return ""
    let own = filter(gstrs(cc, "mounts")) m: rides(m, g_creature)
    if own.length and (always or chance(g_rng, 85)): return rpick(g_rng, own)
    let fam = filter(gstrs(family(g_family), "mounts")) m: m != g_creature and rides(m, g_creature)
    if not fam.length or not (always or chance(g_rng, 65)): return ""
    return rpick(g_rng, fam)

def rides(mount:string, rider:string) -> bool: return not has_s(gstrs(creature(mount), "not_ridden_by"), rider)
def winged(tags:JV) -> bool: return tget(tags, "wings") > 0

def race_skins(c:JV, fid:string, colours:[string], notes:[string]) -> [string]:
    var skins = gstrs(c, "skins")
    if colours.length:
        let sc = at(lib_palettes, "skin_colours")
        let coloured = filter(skins) s: any_in(gstrs(sc, s), colours)
        if not coloured.length: notes.push(rstr(c, "plural") + " don\'t come in " + concat_string(colours, " or ") + ", so they came in their own colours.")
        else: skins = coloured
    let prefer = gstrs(family(fid), "skins")
    let both = filter(skins) s: has_s(prefer, s)
    return if both.length: both else: skins

def mount_for(cid:string, fused:bool, rng:Rng, brief:Brief, rider_skin:string) -> JV:
    let mc = creature(cid)
    let m = jobj()
    set(m, "creature", jstr(cid))
    set(m, "skin", jstr(rpick(rng, mount_skins(mc, rider_skin))))
    set(m, "fused", jbool(fused))
    set(m, "parts", shallow_copy(gobj(mc, "parts")))
    if brief.mount_wings != "" and not fused and not has(at(m, "parts"), "back"): set(at(m, "parts"), "back", jstr(brief.mount_wings))
    return m

def mount_skins(mc:JV, rider_skin:string) -> [string]:
    let out = []::string
    let not_under = gobj(mc, "skins_not_under")
    let weights = gobj(mc, "skin_weights")
    for(gstrs(mc, "skins")) s:
        if not has_s(gstrs(not_under, s), rider_skin):
            for(gint(weights, s, 1)): out.push(s)
    assert out.length
    return out

def mount_points(m:JV) -> int:
    let mc = creature(rstr(m, "creature"))
    var p = pts(part(gstr(mc, "mount_body", rstr(mc, "body"))))
    for(at(m, "parts").a) v: p += pts(part(as_str(v)))
    return p

def cands(slot:string) -> [JV]: return filter(candidates(slot, g_eras)) p: ptier(p) <= g_age

// ---- a line through the ages

def upgrade(prev:JV, sd:JV) -> JV:
    let rng = g_rng
    let age = g_age
    let r = deep_copy(prev)
    set(r, "age", jint(age))
    if has(sd, "engine"): return r
    let role = rstr(sd, "role")
    let budget = as_int(at(at(g_rules, "budget"), string(age)))
    let unit_tags = shallow_copy(g_tags)
    if gstr(r, "elite", "") == "heavy":
        for(HEAVY_BOOST.keys) t, n: tadd(unit_tags, t, as_int(HEAVY_BOOST.a[n]))
    if role == "healer":
        for(HEALER_WANTS.keys) t, n: tadd(unit_tags, t, as_int(HEALER_WANTS.a[n]))
    var spent = recipe_points(r)
    let mount = get(r, "mount")
    let ridden = mount and not gbool(mount, "fused", false)
    let rp = rparts(r)
    var slots = sorted_strs(rp.keys)
    if role == "worker": slots = filter(slots) s: s == "head_gear"
    for(slots) slot:
        let cur = part(rstr(rp, slot))
        let kinds = filter(ptags(cur)) t: has_s(KIND_TAGS, t)
        if slot == "hand_r" and has_s(ptags(cur), "primitive"):
            for(role_kinds(role)) k: kinds.push(k)
        var cs = filter(cands(slot)) p: ptier(p) > ptier(cur) and allowed(p, role, unit_tags) and not off_theme(p, unit_tags) and fits_mount(p, r) and
            (any_in(ptags(p), kinds) or any_in(gstrs(p, "replaces"), kinds) or want(p, g_brief.tags) > 0)
        if has(cur, "upgrade_within"):
            let within = rstr(cur, "upgrade_within")
            cs = filter(cs) p: has_s(ptags(p), within)
        if role == "worker": cs = filter(cs) p: pts(p) <= 2 and not any_in(ptags(p), [ "crest", "horns", "heavy" ])
        if role == "healer" and slot != "hand_r": cs = filter(cs) p: healer_gear(p, unit_tags)
        if has_s(LIGHT_ROLES, role) and slot != "hand_r": cs = filter(cs) p: light(p)
        if slot == "hand_r":
            let need = role_needs(role)
            let excluded = role_excludes(role)
            cs = filter(cs) p: has_s(ptags(p), need) and not any_in(ptags(p), excluded)
            let others = filter(cs) p: not gbool(p, "fallback", false)
            if others.length or own_part(cur): cs = others
        if cs.length:
            let keep = jobj()
            for(ptags(cur)) t: set(keep, t, jint(2))
            let b = best(cs, unit_tags, keep, rng)
            if spent - pts(cur) + pts(b) <= budget:
                spent += pts(b) - pts(cur)
                set(rp, slot, at(b, "id"))
    let open_slots = filter(if role == "worker": []::string else: gear_slots(role)) s: not has(rp, s)
    for(open_slots) slot:
        if not (slot == "hand_l" and gbool(part(rstr(rp, "hand_r")), "two_handed", false)):
            var cs = filter(cands(slot)) p: allowed(p, role, unit_tags) and not off_theme(p, unit_tags) and fits_mount(p, r)
            if ridden or role == "worker": cs = filter(cs) p: not has_s(ptags(p), "wings")
            if role == "worker": cs = filter(cs) p: pts(p) <= 1
            if role == "healer": cs = filter(cs) p: healer_gear(p, unit_tags)
            if has_s(LIGHT_ROLES, role): cs = filter(cs) p: light(p)
            if cs.length:
                let b = best(cs, unit_tags, jobj(), rng)
                if spent + pts(b) <= budget:
                    spent += pts(b)
                    set(rp, slot, at(b, "id"))
    set(r, "name", jstr(step_name(prev, r)))
    return r

def step_name(prev:JV, r:JV) -> string:
    let c = creature(rstr(r, "creature"))
    let rp = rparts(r)
    let pp = rparts(prev)
    let plain = unit_name(r, part(rstr(rp, "hand_r")), c)
    if jequal(rp, pp): return rstr(prev, "name")
    if rstr(r, "role") == "worker" or plain != unit_name(prev, part(rstr(pp, "hand_r")), c): return plain
    for(EPITHET_SLOTS) slot:
        let id = gstr(rp, slot, "")
        if id != "" and id != gstr(pp, slot, ""):
            let epithet = gstr(part(id), "epithet", "")
            if epithet != "" and not starts_with(rstr(prev, "name"), epithet + " "): return epithet + " " + plain
    let ranks = gstrs(family(rstr(r, "family")), "ranks")
    return ranks[min(as_int(at(r, "age")) - as_int(at(r, "tier")) - 1, ranks.length - 1)] + " " + plain

def recipe_points(r:JV) -> int:
    var p = pts(part(rstr(r, "body")))
    for(rparts(r).a) v: p += pts(part(as_str(v)))
    let m = get(r, "mount")
    if m: p += mount_points(m)
    if as_int(at(r, "scale")) >= GIANT_SCALE: p += GIANT_POINTS
    return p

def unit_name(recipe:JV, primary:JV, c:JV) -> string:
    let noun = gstr(recipe, "noun", rstr(primary, "noun"))
    let who = rstr(c, "noun")
    var name = if who == "Folk": noun else: noun + " " + who
    let scale = as_int(at(recipe, "scale"))
    if scale >= GIANT_SCALE: name = "Giant " + name
    elif scale <= TINY_SCALE: name = "Tiny " + name
    elif gstr(recipe, "elite", "") == "heavy": name = "Heavy " + name
    let m = get(recipe, "mount")
    if m and not gbool(m, "fused", false):
        let mc = creature(rstr(m, "creature"))
        var mount_noun = rstr(mc, "noun")
        if has(at(m, "parts"), "back") and not has(gobj(mc, "parts"), "back"):
            mount_noun = if rstr(m, "creature") == "pony": "Pegasus" else: "Winged " + mount_noun
        name += " on a " + mount_noun
    return name
