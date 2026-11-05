// ------------------------------------------------------------------ the match start (World._init and every system's setup)
// A match from races, a map and rules, straight into the sim's arrays, as the GDScript World sets
// itself up: the map (SimMap.load_id), the rules' numbers, unit types (World._make_type, the
// animals'), the attack classes (Combat.setup), building types, ages and research (Tech), every
// line's steps, the race's bonuses, then the starts (Economy.setup), animals (seeded), bridges,
// heroes, the match and the fog. What export.gd writes for the same match, scenario_text writes
// back (scenario_out.lobster), so the two can be compared token by token.

let TICK_HZ = 20
let SPEED_SCALE = 5
let MOUNTED_RADIUS = 420
let MAX_RADIUS = 500
let CLASS_NAMES = [ "ground", "amphibious", "flying" ]
let BASE_CLASSES = [ "melee", "pierce", "building" ]
let UNIT_EXTRA = [ "sight", "carry", "kill_gold", "wade", "reach", "slow_on_hit", "form_gap" ]
let UNIT_PCT = [ "speed", "reload", "cost", "train_time", "build_speed", "carry", "heal" ]
let BUILDING_ADD = [ "sight", "armour.melee", "armour.pierce", "trade_fee", "range", "pop" ]
let BUILDING_PCT = [ "hp", "food", "research_time", "cost", "research_cost", "age_time" ]
let EVAL_ADD = [ "attack", "hp", "range", "speed" ]

// What the setup keeps that the sim's arrays don't (the views and the lobby read some of it).
var su_races = []::JV
var su_rules = jobj()
var su_idents = []::JV  // per player: Identity.of, its lacks lifted by a mode
var su_classes = []::string
var su_btypes = []::JV  // buildings.json entries, sorted by id (planned left out)
var su_btype_ids = []::string
var su_research = []::JV  // tech.json research + line upgrades, as Tech.load_tech
var su_ages = []::JV
var su_type_eval = []::JV    // per unit type: its eval (the first step's)
var su_type_line = []::[JV]  // per unit type: its line [{age, recipe, eval}]
var su_type_recipe = []::JV
var su_type_animal = []::string
var su_map = jobj()
var su_bridge_rects = []::[int]
var su_rng = new_rng(1)
var su_fx = []::[JV]  // per player: the race\'s sim effects (start ones included)
var ai_tokens = []::string

def class_index(tag:string) -> int:  // export.gd _class: unknown tags index the last class
    for(su_classes) c, k:
        if c == tag: return k
    return su_classes.length - 1

def tag_or_none(tag:string) -> int:
    if tag == "all": return -1
    for(su_classes) c, k:
        if c == tag: return k
    return -2

def str_index(xs:[string], s:string) -> int:
    for(xs) x, k:
        if x == s: return k
    return -1

def btype_index(id:string) -> int: return str_index(su_btype_ids, id)

def cost_vec(cost:JV) -> [int]: return map(resource_names) r: gint(cost, r, 0)

def class_vec(d:JV) -> [int]:
    let v = map(su_classes.length): 0
    for(d.keys) k, n: v[class_index(k)] = as_int(d.a[n])
    return v

def type_of_slot(p:int, slot:string) -> int:
    for(t_slot) s, k:
        if t_player[k] == p and s == slot: return k
    return -1

def ident_lacks(p:int, id:string) -> bool:
    if gbool(su_rules, "full_tech_tree", false): return false
    let ident = su_idents[p]
    return has_str(glist(ident, "lacks"), id) or has_str(glist(ident, "lacks_slots"), id)

// ---- the map (SimMap.load_id)

def load_map(map_id:string):
    let d = load_json(data_path("maps/" + map_id + ".json"))
    assert gstr(d, "schema", "") == "aow.map/2" and gstr(d, "id", "") == map_id
    su_map = d
    let types = at(lib_data("terrain.json"), "terrain")
    tr_names = sorted_strs(types.keys)
    W = as_int(at(d, "width"))
    H = as_int(at(d, "height"))
    for(tr_names) t:
        let td = at(types, t)
        let walkable = as_bool(at(td, "walkable"))
        tr_walk.push(if walkable: 1 else: 0)
        let move = if has(td, "move"): gstrs(td, "move") elif walkable: CLASS_NAMES else: [ "flying" ]
        var mask = 0
        for(move) c: mask |= 1 << str_index(CLASS_NAMES, c)
        tr_move.push(mask)
        let res = gstr(td, "resource", "")
        tr_res.push(if res == "": 0 else: str_index(resource_names, res) + 1)
        tr_amount.push(gint(td, "amount", 0))
        tr_opaque.push(if gbool(td, "opaque", false): 1 else: 0)
    for(tr_names) t:
        let td = at(types, t)
        tr_depleted.push(str_index(tr_names, gstr(td, "depleted", "")))
        tr_reseed.push(str_index(tr_names, gstr(td, "reseed", "")))
        tr_cleared.push(str_index(tr_names, gstr(td, "cleared", "")))
    let legend = at(d, "legend")
    let index = map(256): -1
    for(legend.keys) ch, n: index[ch[0]] = str_index(tr_names, as_str(legend.a[n]))
    let rows = gstrs(d, "rows")
    assert rows.length == H
    let n = W * H
    terrain = zeros(n)
    for(NUM_CLASSES): walks.push(zeros(n))
    occupied = zeros(n)
    gate = zeros(n)
    amount = zeros(n)
    pool = map(n): -1
    walk_over = zeros(n)
    high = zeros(n)
    deck = zeros(n)
    opaque = zeros(n)
    for(H) y:
        let row = rows[y]
        assert row.length == W
        for(W) x:
            let k = index[row[x]]
            assert k >= 0
            let c = y * W + x
            terrain[c] = k
            for(NUM_CLASSES) mc: walks[mc][c] = if (tr_move[k] & (1 << mc)) != 0: 1 else: 0
            walks[0][c] = tr_walk[k]
            amount[c] = tr_amount[k]
            if tr_amount[k] > 0: resource_cells.push(c)
            if tr_opaque[k] != 0: opaque[c] = 1
    level = zeros(n)
    ramp = zeros(n)
    cliff = zeros(n)
    let heights = gstrs(d, "heights")
    has_heights = if heights.length: 1 else: 0
    if heights.length: load_heights(heights)
    for(glist(d, "starts")) s:
        start_x.push(as_int(s.a[0]) * TILE + TILE / 2)
        start_y.push(as_int(s.a[1]) * TILE + TILE / 2)
    for(glist(d, "bridges")) r: su_bridge_rects.push(map(r.a) v: as_int(v))

def load_heights(rows:[string]):
    assert rows.length == H
    for(H) y:
        let row = rows[y]
        for(W) x:
            let c = y * W + x
            let ch = row[x]
            if ch >= 'a' and ch <= 'c':
                level[c] = ch - 'a'
                ramp[c] = 1
            else:
                assert ch >= '0' and ch <= '3'
                level[c] = ch - '0'
    for(H) y:
        for(W) x:
            let c = y * W + x
            let top = level[c] + ramp[c]
            var dy = -1
            while dy <= 1:
                var dx = -1
                while dx <= 1:
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0 and ny >= 0 and nx < W and ny < H and level[ny * W + nx] > top: cliff[c] = 1
                    dx++
                dy++
            if cliff[c] == 1:
                for(NUM_CLASSES) k:
                    if k != FLYING: walks[k][c] = 0

// ---- unit types (World._make_type, Combat.type_vectors)

def eval_tags(e:JV) -> [string]: return gstrs(e, "tags")

def add_type(player:int, recipe:JV, e:JV, line:[JV]) -> int:
    let k = t_slot.length
    var radius = BASE_RADIUS * as_int(at(recipe, "scale")) / 100
    if has(recipe, "mount"): radius = max(radius, MOUNTED_RADIUS)
    if gint(e, "radius", 0) > 0: radius = as_int(at(e, "radius"))
    let tags = eval_tags(e)
    let heal = gint(e, "heal", 0)
    let trader = has_s(tags, "trade")
    t_player.push(player)
    t_slot.push(rstr(recipe, "slot"))
    t_speed.push(as_int(at(e, "speed")) * SPEED_SCALE)
    t_radius.push(min(radius, MAX_RADIUS))
    t_hp.push(as_int(at(e, "hp")))
    t_pop.push(as_int(at(e, "pop")))
    t_cost.push(cost_vec(at(e, "cost")))
    t_train_ticks.push(as_int(at(e, "train_time")) * TICK_HZ)
    t_worker.push(if has_s(tags, "worker"): 1 else: 0)
    t_healer.push(if heal > 0: 1 else: 0)
    t_trader.push(if trader: 1 else: 0)
    t_harmless.push(if trader or gstr(e, "targets", "") == "none": 1 else: 0)
    t_posture.push(if heal > 0 or trader: PASSIVE else: AGGRESSIVE)
    var mc = 0
    var found = false
    for(glist(gobj(su_rules, "movement"), "classes")) entry:
        if not found and has_s(tags, rstr(entry, "tag")):
            mc = str_index(CLASS_NAMES, rstr(entry, "class"))
            found = true
    t_mclass.push(mc)
    t_docks.push(if has_s(tags, "docks"): 1 else: 0)
    t_carry_add.push(0)
    t_build_pct.push(0)
    t_gap.push(0)
    t_hero.push(if has(recipe, "hero"): 1 else: 0)
    t_age.push(as_int(at(line[0], "age")))
    t_min_damage.push(0)
    t_animal.push(0)
    t_behave.push(0)
    t_flee.push(0)
    t_food.push(0)
    su_type_eval.push(e)
    su_type_line.push(line)
    su_type_recipe.push(recipe)
    su_type_animal.push("")
    return k

// The numbers Combat.type_vectors gives a type from its eval (the players' are redone by retype).
def type_vectors(k:int):
    let e = su_type_eval[k]
    let C = su_classes.length
    let atk = map(C): 0
    atk[class_index(rstr(e, "damage"))] = as_int(at(e, "attack"))
    let bonus = class_vec(at(e, "bonus"))
    for(C) c: atk[c] += bonus[c]
    t_atk.push(atk)
    t_counters.push(filter(map(C) c: c) c: c >= 3 and bonus[c] > 0)
    t_arm.push(class_vec(at(e, "armour")))
    let cls = map(C): 0
    cls[0] = 1
    cls[1] = 1
    for(eval_tags(e)) tg: cls[class_index(tg)] = 1
    t_cls.push(cls)
    let range = as_int(at(e, "range"))
    let ranged = range > 1
    t_ranged.push(if ranged: 1 else: 0)
    t_reach.push(if ranged: range * TILE else: r_melee_reach)
    var reload = if ranged: r_ranged_reload else: r_melee_reload
    var ss = r_shot_speed
    let speeds = gobj(at(su_rules, "combat"), "shot_speeds")
    var found = false
    for(eval_tags(e)) tg:
        if not found and has(speeds, tg):
            ss = as_int(at(speeds, tg))
            found = true
    t_shot_speed.push(ss)
    if gint(e, "reload", 0) > 0: reload = as_int(at(e, "reload"))
    t_reload.push(reload)
    let no_heal = gstrs(at(su_rules, "combat"), "heal_not")
    t_no_heal.push(if any_in(eval_tags(e), no_heal): 1 else: 0)
    t_sight.push(gint(e, "sight", 0))
    let combat = at(su_rules, "combat")
    t_role.push(if t_healer[k] or t_harmless[k] or has_s(eval_tags(e), rstr(combat, "band_machine")): 2 elif has_s(eval_tags(e), rstr(combat, "band_mounted")): 3 elif ranged: 1 else: 0)

// Animal types (Animals.add_types), owned by gaia, after the players'.
def add_animal_types(d:JV):
    claim_tiles = as_int(at(d, "claim_tiles"))
    let animals = at(d, "animals")
    for(sorted_strs(animals.keys)) id:
        let a = at(animals, id)
        let e = jobj()
        set(e, "hp", jint(as_int(at(a, "hp"))))
        set(e, "attack", jint(max(1, as_int(at(a, "attack")))))
        set(e, "damage", jstr("melee"))
        set(e, "armour", at(a, "armour"))
        set(e, "range", jint(1))
        set(e, "speed", jint(as_int(at(a, "speed"))))
        set(e, "bonus", jobj())
        set(e, "tags", jstrs([ "animal", id ]))
        set(e, "points", jint(0))
        set(e, "cost", jobj())
        set(e, "train_time", jint(1))
        set(e, "pop", jint(0))
        let r = at(a, "recipe")
        let k = add_type(gaia, r, e, [ line_step(as_int(at(r, "tier")), r, e) ])
        su_type_animal[k] = id
        t_animal[k] = 1
        t_food[k] = as_int(at(a, "food"))
        t_behave[k] = str_index([ "", "flee", "fight", "herd" ], rstr(a, "behaviour"))
        t_flee[k] = gint(a, "flee_tiles", 0) * TILE
        t_harmless[k] = if as_int(at(a, "attack")) == 0: 1 else: 0
        t_min_damage[k] = gint(a, "slaughter_damage", 0)

// ---- building types (Economy.load_btypes) and research (Tech.load_tech)

def load_btypes():
    let d = at(lib_data("buildings.json"), "buildings")
    su_btype_ids = sorted_strs(filter(d.keys) id: gstr(at(d, id), "status", "") != "planned")
    su_btypes = map(su_btype_ids) id: at(d, id)

def built(item:JV) -> bool: return gstr(item, "status", "") != "planned"

def load_tech_data():
    let d = lib_data("tech.json")
    su_ages = filter(glist(d, "ages")) a: built(a)
    // a creature's or culture's own research: only theirs (Identity.owners)
    let owners = jobj()
    for([ lib_creatures, lib_families ]) src:
        for(sorted_strs(src.keys)) id:
            for(gstrs(at(src, id), "research")) r:
                if not has(owners, r): set(owners, r, jarr([]))
                at(owners, r).a.push(jstr(id))
    su_research = []
    for(glist(d, "research")) r:
        if built(r) and (gstr(r, "building", "all") == "all" or has_s(su_btype_ids, gstr(r, "building", ""))):
            let o = shallow_copy(r)
            set(o, "only", if has(r, "only"): at(r, "only") else: gobj(owners, rstr(r, "id")))
            if not has(o, "only") or at(o, "only").kind != J_ARR: set(o, "only", jarr([]))
            set(o, "after", jstr(gstr(r, "after", "")))
            su_research.push(o)
    let ups = gobj(d, "line_upgrades")
    for(su_btypes) bt, k:
        for(gstrs(bt, "trains")) slot:
            if slot != "worker":
                for([ 2, 3 ]) age:
                    let up = gobj(ups, string(age))
                    if up.keys.length:
                        let o = jobj()
                        set(o, "id", jstr("line." + slot + "." + string(age)))
                        set(o, "cost", at(up, "cost"))
                        set(o, "time", at(up, "time"))
                        set(o, "building", jstr(su_btype_ids[k]))
                        set(o, "age", jint(age))
                        set(o, "effects", jarr([]))
                        set(o, "only", jarr([]))
                        set(o, "after", jstr(""))
                        set(o, "line", jstr(slot))
                        set(o, "line_age", jint(age))
                        su_research.push(o)
    for(su_research) r:  // a line upgrade's earlier ones, latest first
        if has(r, "line"):
            let earlier = jarr([])
            var age = as_int(at(r, "line_age")) - 1
            while age > 1:
                let id = "line." + rstr(r, "line") + "." + string(age)
                for(su_research) o, k:
                    if rstr(o, "id") == id: earlier.a.push(jint(k))
                age--
            set(r, "earlier", earlier)

def research_index(id:string) -> int:
    for(su_research) r, k:
        if rstr(r, "id") == id: return k
    return -1

// An effect as the sim's Effect (export.gd _effect).
def encode_effect(fx:JV) -> Effect:
    var kind = -1
    var stat = 0
    let value = gint(fx, "add", gint(fx, "pct", 0))
    if has(fx, "becomes"):
        let was = btype_index(rstr(fx, "building"))
        let to = btype_index(rstr(fx, "becomes"))
        return Effect { if was >= 0 and to >= 0: 8 else: -1, was, to, -2, [], [], [] }  // (-1: a mod took one out)
    if has(fx, "gather"):
        kind = 7
        stat = str_index(resource_names, rstr(fx, "gather"))
    elif has(fx, "start"): return Effect { 9, 0, 0, -2, [], [], [] }
    elif has(fx, "tag"):
        let s = rstr(fx, "stat")
        if has(fx, "pct"):
            kind = 4
            stat = str_index(UNIT_PCT, s)
        elif has_s(UNIT_EXTRA, s):
            kind = 3
            stat = str_index(UNIT_EXTRA, s)
        elif starts_with(s, "armour."):
            kind = 1
            stat = class_index(substring(s, 7, s.length - 7))
        elif starts_with(s, "bonus."):
            kind = 2
            stat = class_index(substring(s, 6, s.length - 6))
        else:
            kind = 0
            stat = str_index(EVAL_ADD, s)
        assert stat >= 0
    else:
        kind = if has(fx, "add"): 5 else: 6
        stat = str_index(if has(fx, "add"): BUILDING_ADD else: BUILDING_PCT, rstr(fx, "stat"))
        assert stat >= 0
    let ands = map(gstrs(fx, "and")) t: tag_or_none(t)
    let nots = map(gstrs(fx, "not")) t: tag_or_none(t)
    var blds = []::int
    if has(fx, "building"):
        let b = at(fx, "building")
        let ids = if b.kind == J_ARR: map(b.a) v: as_str(v) else: [ as_str(b) ]
        blds = if has_s(ids, "all"): [ -1 ] else: filter(map(ids) id: btype_index(id)) k: k >= 0
    return Effect { kind, stat, value, if has(fx, "tag"): tag_or_none(rstr(fx, "tag")) else: -2, ands, nots, blds }

// A line step's eval as the sim's LineStep (export.gd _write_tech).
def line_step_of(slot:string, l:JV) -> LineStep:
    let e = at(l, "eval")
    let age = as_int(at(l, "age"))
    let bonus = map(su_classes.length): 0
    let be = at(e, "bonus")
    for(be.keys) key, n: bonus[class_index(key)] = as_int(be.a[n])
    let arm = map(su_classes.length): 0
    let ae = at(e, "armour")
    for(ae.keys) key, n: arm[class_index(key)] = as_int(ae.a[n])
    return LineStep { age, research_index("line." + slot + "." + string(age)), as_int(at(e, "speed")), as_int(at(e, "hp")),
                      as_int(at(e, "pop")), as_int(at(e, "train_time")), cost_vec(at(e, "cost")),
                      class_index(rstr(e, "damage")), as_int(at(e, "attack")), bonus, arm, map(eval_tags(e)) t: class_index(t),
                      as_int(at(e, "range")), gint(e, "reload", 0), gint(e, "min_range", 0), gint(e, "splash", 0), gint(e, "pass", 0),
                      if gstr(e, "targets", "") == "buildings": 1 else: 0, gint(e, "unpack", 0), gint(e, "pack", 0),
                      gint(e, "blast", 0), gint(e, "blast_line_pct", 0), gint(e, "heal", 0), gint(e, "sight", 0) }

// Does this player's line have a step after its first at that age, with new kit (Tech._line_has)?
def line_has_kit(p:int, slot:string, age:int) -> bool:
    let k = type_of_slot(p, slot)
    if k < 0: return false
    let line = su_type_line[k]
    for(line) l, n:
        if n > 0 and as_int(at(l, "age")) == age:
            return not jequal(at(at(line[n], "recipe"), "parts"), at(at(line[n - 1], "recipe"), "parts"))
    return false

def line_before_of(p:int, item:JV) -> int:
    for(glist(item, "earlier")) v:
        let r = as_int(v)
        if line_has_kit(p, rstr(item, "line"), as_int(at(su_research[r], "line_age"))): return r
    return -1
