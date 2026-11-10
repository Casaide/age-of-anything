// ------------------------------------------------------------------ races to the sim's table
// The game's side of the unit type seam: the sim is built from plain sides (gen/setup, add_type), and this fills them
// from generated races. A unit is its stats as they are, plus slot, age, radius, its later ages (line) and its look:
// a recipe, here, which only the view reads.

let MOUNTED_RADIUS = 420
var su_races = []::JV

// One age of a line: its stats, its age, its look, and whether its kit is new since the age before.
def unit_step(l:JV, before:JV?) -> JV:
    let recipe = at(l, "recipe")
    let step = shallow_copy(at(l, "eval"))
    set(step, "age", at(l, "age"))
    set(step, "look", recipe)
    if before: set(step, "new_kit", jbool(not jequal(at(recipe, "parts"), at(at(before, "recipe"), "parts"))))
    return step

// A unit from a recipe, its eval and its line [{age, recipe, eval}].
def race_unit(recipe:JV, e:JV, line:[JV]) -> JV:
    let u = shallow_copy(e)
    var radius = BASE_RADIUS * as_int(at(recipe, "scale")) / 100
    if has(recipe, "mount"): radius = max(radius, MOUNTED_RADIUS)
    if gint(e, "radius", 0) > 0: radius = as_int(at(e, "radius"))
    set(u, "radius", jint(radius))
    set(u, "slot", at(recipe, "slot"))
    set(u, "age", at(line[0], "age"))
    set(u, "look", recipe)
    if has(recipe, "hero"):
        let sid = rstr(recipe, "hero")
        set(u, "hero", jstr(sid))
        set(u, "hero_aura", jarr(glist(at(at(at(lib_heroes, "hero_signatures"), sid), "aura"), "effects")))
    set(u, "line", jarr(map(line) l, n: unit_step(l, if n > 0: line[n - 1] else: nil)))
    return u

def race_line(u:JV) -> [JV]:
    if has(u, "line"): return glist(u, "line")
    let r = at(u, "recipe")
    return [ line_step(as_int(at(r, "tier")), r, at(u, "eval")) ]

// A side for the sim: the race's units and what Identity gives it (lacks, own research, its effects).
def race_to_side(race:JV) -> JV:
    let side = shallow_copy(identity_of(rstr(race, "creature"), rstr(race, "family")))
    set(side, "units", jarr(map(glist(race, "units")) u: race_unit(at(u, "recipe"), at(u, "eval"), race_line(u))))
    set(side, "owners", jstrs([ rstr(race, "creature"), rstr(race, "family") ]))
    let own = []::JV
    let team = []::JV
    for(glist(side, "bonuses")) b:
        for(glist(b, "effects")) fx:
            if not priced(fx): own.push(fx)
            if gbool(b, "team", false): team.push(fx)
    set(side, "effects", jarr(own))
    set(side, "team_effects", jarr(team))
    return side

// A match from races.
def setup_match(seed_value:int, map_id:string, races:[JV], rules:JV, team_ids:[int]):
    su_races = races
    setup_world(seed_value, map_id, map(races) r: race_to_side(r), rules, team_ids)
