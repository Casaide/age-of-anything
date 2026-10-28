// ------------------------------------------------------------------ the units the placement checks cover (tests/placement/cases.gd)
// Every unit of these races at every age of its line (so every body, head, leg, hold and piece of gear in play),
// the scouts, mounted archers and unique units of more races, every rider on every mount, winged mounts, every newt
// skin and cat coat, the animals and the siege engines with their crews, every hero look on every playable body,
// the Norse kit, the off-hand and back gear and the bears' gear on every body, the creature-kit concepts, the
// composites, and the mods' units. [label, recipe] pairs.

class Case:
    label:string
    recipe:JV

// Races whose every unit is checked (between them: every playable body, every hold, back parts, wings, a fused
// centaur, siege crews).
let PROMPTS = ["romans", "swamp frogs", "sewer rats", "rats", "forest beetles", "spooky spiders",
    "flying greeks with wings", "centaur romans", "winged frogs", "vikings", "bears", "polar bears", "moonbears", "viking bears"]
// More races for milestone 13's new lines only (scouts, mounted archers, unique units...).
let LINE_PROMPTS = ["greeks", "royal humans", "mongols", "aztecs", "egyptians", "han", "sewer rats with cheese hammers",
    "tiny vikings", "swamp humans", "forest humans", "sewer humans", "spooky humans", "forest bears", "romans riding bears",
    "rats riding bears", "giant bears"]
let NEW_LINES = ["scout", "mounted_archer", "unique", "large", "trader", "great_sling", "war_beast"]
// Riders (a race's spear unit, put on each mount) and the mounts.
let RIDERS = ["romans", "swamp frogs", "sewer rats", "spooky spiders", "forest beetles"]
let MOUNTS = ["pony", "beetle", "spider", "capybara", "newt", "hummingbird", "cat", "bear", "bear_black"]
// The race whose units carry each playable creature's hero looks, Norse kit and gear.
let HERO_BASE = [["frog", "swamp frogs"], ["rat", "sewer rats"], ["human", "romans"], ["spider", "spooky spiders"],
    ["beetle", "forest beetles"], ["centaur", "centaur romans"], ["bear", "bears"], ["bear_black", "moonbears"], ["bear_polar", "polar bears"]]
let NORSE_HELMS = ["helm.norse_fur", "helm.norse_conical", "helm.norse_spectacle", "helm.horned"]
let NORSE_AXES = ["weapon.axe.bearded", "weapon.axe.broad"]
let BEARS = ["bear", "bear_black", "bear_polar"]

def hero_base(cid:string) -> string:
    for(HERO_BASE) kv:
        if kv[0] == cid: return kv[1]
    assert false   // (hero cases: a race in PROMPTS for every playable creature)
    return ""

let case_races = dictionary<string, JV>(63)
def race_for(prompt:string, rules_id:string) -> JV:
    let k = prompt + "|" + rules_id
    let have = case_races.get(k)
    if have: return have
    let r = generate(prompt, load_rules(rules_id), 0)
    case_races.set(k, r)
    return r

def slot_unit(race:JV, s:string) -> JV:
    for(glist(race, "units")) u:
        if rstr(at(u, "recipe"), "slot") == s: return u
    assert false
    return jobj()

def last_step(u:JV) -> JV:
    let line = glist(u, "line")
    return if line.length: line[line.length - 1] else: u

// A unit put on a mount (only its own recipe: a unit's age line would bake instead of it).
def ride(u:JV, mount:string, skin:string, parts:JV) -> JV:
    let r = deep_copy(at(u, "recipe"))
    let m = jobj()
    set(m, "creature", jstr(mount))
    set(m, "fused", jbool(false))
    set(m, "parts", parts)
    set(m, "skin", jstr(skin))
    set(r, "mount", m)
    return r

def with_parts(recipe:JV, parts:[[string]]) -> JV:
    let r = deep_copy(recipe)
    for(parts) kv: set(at(r, "parts"), kv[0], jstr(kv[1]))
    return r

def in_play_creatures() -> [string]:
    let raw = load_json(lib_root + "/creatures.json")
    return filter(creature_ids("playable")) c: has(raw, c)

def line_key(recipe:JV) -> string: return if has(recipe, "hero"): "{rstr(recipe, "slot")}.{rstr(recipe, "hero")}" else: rstr(recipe, "slot")

// lines: also every later age of each unit line (their own armour, helmets, weapons).
def all_cases(with_lines:bool) -> [Case]:
    let cases = []::Case
    for(PROMPTS) p:
        for(glist(race_for(p, "default"), "units")) u:
            let rec = at(u, "recipe")
            let lk = line_key(rec)
            cases.push(Case { "{p} {lk}", rec })
            if with_lines:
                let steps = glist(u, "line")
                var i = 1
                while i < steps.length:
                    let s = steps[i]
                    if stringify(at(s, "recipe")) != stringify(rec): cases.push(Case { "{p} {lk} age {gint(s, "age", i + 1)}", at(s, "recipe") })
                    i++
    // The swordsman's age-3 kit for the cultures PROMPTS leaves out, and the plain iron sword, the fallback, which
    // royal humans get under the bronze rules.
    for([["greeks", "default"], ["mongols", "default"], ["han", "default"], ["royal humans", "bronze"]]) s:
        for(glist(slot_unit(race_for(s[0], s[1]), "infantry"), "line")) l:
            if gint(l, "age", 1) >= 2:
                cases.push(Case { "{s[0]} swordsman age {gint(l, "age", 1)}" + (if s[1] != "default": " (bronze rules)" else: ""), at(l, "recipe") })
    for(LINE_PROMPTS) p:
        for(glist(race_for(p, "default"), "units")) u:
            let rec = at(u, "recipe")
            if has_s(NEW_LINES, rstr(rec, "slot")):
                cases.push(Case { "{p} {rstr(rec, "slot")}", rec })
                let line = glist(u, "line")
                if with_lines and line.length > 1 and stringify(at(line[line.length - 1], "recipe")) != stringify(rec):
                    cases.push(Case { "{p} {rstr(rec, "slot")} age {gint(line[line.length - 1], "age", 1)}", at(line[line.length - 1], "recipe") })
    for(RIDERS) p:
        let spear = slot_unit(race_for(p, "default"), "spear")
        for(MOUNTS) m:
            cases.push(Case { "{rstr(at(spear, "recipe"), "creature")} on {m}", ride(spear, m, as_str(glist(creature(m), "skins")[0]), shallow_copy(gobj(creature(m), "parts"))) })   // (with what the mount always has: a hummingbird's wings)
    let human = slot_unit(race_for("romans", "default"), "spear")
    for(["pony", "beetle", "spider"]) m:   // (winged mounts, a "pegasus": the mount's wings at its withers)
        let wp = jobj()
        set(wp, "back", jstr("wings.feather"))
        cases.push(Case { "human on winged {m}", ride(human, m, as_str(glist(creature(m), "skins")[0]), wp) })
    let frog = slot_unit(race_for("swamp frogs", "default"), "spear")
    for(gstrs(creature("newt"), "skins")) skin: cases.push(Case { "frog on {skin}", ride(frog, "newt", skin, jobj()) })
    let rat = slot_unit(race_for("sewer rats", "default"), "spear")
    for(gstrs(creature("cat"), "skins")) skin: cases.push(Case { "rat on {skin}", ride(rat, "cat", skin, jobj()) })
    let animals = load_json(lib_root + "/animals.json")
    let an = gobj(animals, "animals")
    for(sorted_strs(an.keys)) id:
        let rec = at(at(an, id), "recipe")
        cases.push(Case { "animal {rstr(rec, "body")}", rec })
    append_into(cases, hero_cases())
    append_into(cases, norse_cases())
    append_into(cases, gear_cases())
    append_into(cases, bear_cases())
    append_into(cases, kit_cases())
    append_into(cases, composite_cases())
    append_into(cases, mod_cases())
    return cases

// Heroes: any culture's hero can come to any playable creature, and a creature's own to it, so every such look is
// checked over that creature's age-3 swordsman (the hero's last step), its replaced kit kept as in play.
def hero_cases() -> [Case]:
    let out = []::Case
    let rules = load_rules("default")
    let sigs = at(lib_heroes, "hero_signatures")
    let sd = hero_slot_def(rules)
    for(in_play_creatures()) cid:
        let step = last_step(slot_unit(race_for(hero_base(cid), "default"), "infantry"))
        for(sorted_strs(sigs.keys)) sid:
            let s = at(sigs, sid)
            let who = gobj(s, "who")
            if has_str(glist(who, "creature"), cid) or glist(who, "family").length:
                out.push(Case { "hero: {cid} as {sid}", hero_dress(at(step, "recipe"), sid, s, sid, if sd: gint(sd, "tier", 1) else: 1) })
    return out

// The Norse culture's kit: any creature can be Norse, so each Norse part goes on every playable body.
def norse_cases() -> [Case]:
    let out = []::Case
    for(in_play_creatures()) cid:
        let race = race_for(hero_base(cid), "default")
        let sword = at(last_step(slot_unit(race, "infantry")), "recipe")
        for(NORSE_HELMS) h: out.push(Case { "norse: {cid} swordsman with {h}", with_parts(sword, [["head_gear", h]]) })
        for(NORSE_AXES) a: out.push(Case { "norse: {cid} swordsman with {a}", with_parts(sword, [["hand_r", a]]) })
        if cid != "centaur" and not has_str(glist(creature("pony"), "not_ridden_by"), cid):   // (bears don't ride)
            let rider = ride(slot_unit(race, "spear"), "pony", as_str(glist(creature("pony"), "skins")[0]), jobj())
            out.push(Case { "norse: {cid} rider with weapon.axe.bearded and helm.norse_conical", with_parts(rider, [["hand_r", "weapon.axe.bearded"], ["head_gear", "helm.norse_conical"]]) })
        out.push(Case { "norse: {cid} scout with weapon.axe.bearded and helm.norse_fur", with_parts(at(slot_unit(race, "scout"), "recipe"), [["hand_r", "weapon.axe.bearded"], ["head_gear", "helm.norse_fur"]]) })
        out.push(Case { "norse: {cid} healer with tool.staff.rune", with_parts(at(slot_unit(race, "healer"), "recipe"), [["hand_r", "tool.staff.rune"]]) })
    return out

// Off-hand and back gear on every body: every shield, cape and banner on each playable body's age-3 swordsman,
// every quiver on its archer, every healer's bag in its healer's off hand.
def gear_cases() -> [Case]:
    let out = []::Case
    let ids = sorted_strs(lib_parts.keys)
    for(in_play_creatures()) cid:
        let race = race_for(hero_base(cid), "default")
        let units = [at(last_step(slot_unit(race, "infantry")), "recipe"), at(last_step(slot_unit(race, "archer")), "recipe"), at(slot_unit(race, "healer"), "recipe")]
        for(ids) id:
            let p = part(id)
            let tags = gstrs(p, "tags")
            let ps = rstr(p, "slot")
            if (ps == "hand_l" or ps == "back") and not has_str(glist(p, "only_if"), "hero_only") and not has_s(tags, "flying"):
                let who = if has_s(tags, "heal"): 2 elif has_s(tags, "quiver"): 1 else: 0
                if not has_str(glist(p, "not_worn_by"), rstr(units[who], "body")):   // (parts.json not_worn_by: never on this body)
                    out.push(Case { "gear: {cid} {["infantry", "archer", "healer"][who]} with {id}", with_parts(units[who], [[ps, id]]) })
    return out

// The bears: every helmet, hat, body armour and held piece of the game (not a hero's, a siege engine's or a
// concept's) on each bear body, over the unit of its race that would wear or hold it.
def bear_cases() -> [Case]:
    let out = []::Case
    let ids = sorted_strs(lib_parts.keys)
    let whos = ["infantry", "spear", "archer", "skirmisher", "healer", "worker"]
    for(BEARS) cid:
        let race = race_for(hero_base(cid), "default")
        let units = map(whos) w: at(if w == "healer" or w == "worker": slot_unit(race, w) else: last_step(slot_unit(race, w)), "recipe")
        for(ids) id:
            let p = part(id)
            let tags = gstrs(p, "tags")
            let ps = rstr(p, "slot")
            let only = gstrs(p, "only_if")
            if (ps == "head_gear" or ps == "torso" or ps == "hand_r") and not has_s(only, "hero_only") and not has_s(only, "concept_only") and
               not has_s(tags, "siege") and not has_s(tags, "sapper") and not has_s(tags, "war_beast") and not has_s(tags, "load"):
                var who = "infantry"
                if ps == "hand_r":
                    if has_s(tags, "heal"): who = "healer"
                    elif has_s(tags, "worker") or has_s(tags, "tool") or has_s(tags, "load") or has_s(tags, "job"): who = "worker"
                    elif has_s(tags, "skirmish"): who = "skirmisher"
                    elif has_s(tags, "ranged"): who = "archer"
                    elif has_s(tags, "spear") or has_s(tags, "lance"): who = "spear"
                let u = units[find(whos) w: w == who]
                if not has_str(glist(p, "not_worn_by"), rstr(u, "body")):
                    out.push(Case { "bear: {cid} {who} with {id}", with_parts(u, [[ps, id]]) })
    return out

// Creature-kit creatures: the cat rebuilt through the kit under a rat, and the bears' concept rows.
let BEAR_CASES = [
    ["brown bear spear", "bear greeks", "spear", "\{\"skin\": \"bear_brown\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_crest\"\}\}"],
    ["brown bear stock helm", "bear greeks", "spear", "\{\"skin\": \"bear_brown\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bronze\"\}\}"],
    ["brown bear open helm", "bear greeks", "spear", "\{\"skin\": \"bear_brown\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_open\"\}\}"],
    ["brown bear worker", "bear greeks", "worker", "\{\"skin\": \"bear_brown\"\}"],
    ["brown bear infantry", "bear greeks", "infantry", "\{\"skin\": \"bear_brown\"\}"],
    ["black bear spear", "bear greeks", "spear", "\{\"creature\": \"bear_black\", \"body\": \"body.bear_black\", \"head\": \"head.bear_black\", \"skin\": \"bear_black\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_crest\"\}\}"],
    ["polar bear spear", "bear greeks", "spear", "\{\"creature\": \"bear_polar\", \"body\": \"body.bear_polar\", \"head\": \"head.bear_polar\", \"skin\": \"bear_polar\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_crest\"\}\}"],
    ["giant polar bear", "giant bear greeks", "large", "\{\"creature\": \"bear_polar\", \"body\": \"body.bear_polar\", \"head\": \"head.bear_polar\", \"skin\": \"bear_polar\", \"parts\": \{\"hand_r\": \"weapon.dory\", \"hand_l\": \"shield.hoplon\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_crest\"\}\}"],
    ["giant old bear", "giant bear greeks", "large", "\{\"skin\": \"bear_grizzled\", \"parts\": \{\"hand_r\": \"weapon.sword.xiphos\", \"torso\": \"armour.bronze\", \"head_gear\": \"helm.bear_crest\"\}\}"],
]

def kit_cases() -> [Case]:
    stage_file("res://data/creature_kit.json")
    let cases = []::Case
    let rat = slot_unit(race_for("sewer rats", "default"), "spear")
    for(["kitcat", "kitcat_built"]) m: cases.push(Case { "kit: rat on {m}", ride(rat, m, as_str(glist(creature(m), "skins")[0]), shallow_copy(gobj(creature(m), "parts"))) })
    for(BEAR_CASES) b:
        let r = deep_copy(at(slot_unit(race_for(b[1], "default"), b[2]), "recipe"))
        let over = parse_json(b[3])
        for(over.keys) k, n: set(r, k, over.a[n])   // (Dictionary.merge with overwrite: whole values replaced)
        cases.push(Case { "kit: " + b[0], r })
    let human = slot_unit(race_for("romans", "default"), "spear")
    for(gstrs(creature("bear"), "skins")) skin: cases.push(Case { "kit: human on bear {skin}", ride(human, "bear", skin, jobj()) })
    cases.push(Case { "kit: rat on bear", ride(rat, "bear", "bear_brown", jobj()) })
    cases.push(Case { "kit: human on black bear", ride(human, "bear_black", "bear_black", jobj()) })
    return cases

// Concept composites (staged from data/later/): the trade carts of round TC1, each beast in its draught harness;
// the great sling packed and throwing; what a worker pushes home.
let COMPOSITE_CASES = [
    ["romans", "concept.tc1_a_timber", "pony", "pony_bay"], ["swamp frogs", "concept.tc1_a_frog", "newt", "newt_fire"],
    ["sewer rats", "concept.tc1_a_junk", "cat", "cat_ginger"], ["forest beetles", "concept.tc1_a_forest", "beetle", "beetle_stag"],
    ["spooky spiders", "concept.tc1_a_spooky", "spider", "spider_black"], ["romans", "concept.tc1_c_timber", "pony", "pony_grey"],
]

def composite_cases() -> [Case]:
    stage_file("res://data/later/trade_carts.json")
    let cases = []::Case
    for(COMPOSITE_CASES) c:
        let u = slot_unit(race_for(c[0], "default"), "trader")
        let r = deep_copy(at(last_step(u), "recipe"))
        set(r, "body", jstr(c[1]))
        let h = parse_json("\{\"creature\": \"{c[2]}\", \"skin\": \"{c[3]}\", \"parts\": \{\"torso\": \"harness.draught\"\}\}")
        set(r, "haul", h)
        cases.push(Case { "composite: {c[0]} {c[1].substring(8, c[1].length - 8)} hauled by a {c[2]}", r })
    for(["romans", "sewer rats", "forest beetles", "spooky spiders", "centaur romans", "swamp frogs", "winged frogs"]) p:
        let u = slot_unit(race_for(p, "default"), "great_sling")
        for(["packed", "throw"]) look:
            let shown = gstr(part(rstr(at(u, "recipe"), "body")), look, "")
            if shown != "":
                let r = deep_copy(at(u, "recipe"))
                set(r, "body", jstr(shown))
                cases.push(Case { "composite: {p} great sling " + (if look == "packed": "packed" else: "throwing"), r })
    for(["sewer rats", "sewer rats with cheese hammers"]) p:
        let w = at(slot_unit(race_for(p, "default"), "worker"), "recipe")
        let pushes = gobj(creature(rstr(w, "creature")), "push_home")
        for(pushes.keys) res, n: cases.push(Case { "composite: {p} worker pushing {res} home", push_recipe(w, as_str(pushes.a[n])) })
    return cases

// The mods in use: every unit, at every age of its line, of each prompt the mod's manifest lists under "check"
// that wears or holds one of the mod's parts.
def mod_cases() -> [Case]:
    let out = []::Case
    for(mods_active) rec:
        let chk = gobj(rec.manifest, "check")
        let rid = gstr(chk, "rules", "default")
        let pj = get(rec.data, "parts.json")
        let own = if pj: map(pj.a) q: rstr(q, "id") else: []::string
        for(gstrs(chk, "prompts")) p:
            for(glist(race_for(p, rid), "units")) u:
                let seen = []::string
                let line = glist(u, "line")
                for(if line.length: line else: [u]) s:
                    let rec2 = at(s, "recipe")
                    let sig = stringify(at(rec2, "parts"))
                    var mine = false
                    for(at(rec2, "parts").a) v:
                        if v.kind == J_STR and has_s(own, v.s): mine = true
                    if not has_s(seen, sig) and mine:
                        seen.push(sig)
                        out.push(Case { "mod {rec.id}: {p} {rstr(rec2, "slot")} age {gint(rec2, "age", gint(rec2, "tier", 1))}", rec2 })
    return out
