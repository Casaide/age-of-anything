// ------------------------------------------------------------------ a new race mid-match (Lobster only: the generator in play)
// A player's people become another race while the match runs: the new race is balanced against
// the others by fights (the running world stashed meanwhile, then brought back exactly), and each
// of the player's unit lines takes the new race's line of the same slot (its looks, stats, prices,
// the age it's in, research it has), as do its bonuses and its buildings' style. Units alive change
// in place (their share of health kept). A line the new race lacks stays as it was.
// Attack classes the match didn't know (a tag no race at the start had) count as the last class,
// as in GDScript's _class.

var type_gen = 0  // bumped when any type changes look (the views rebuild)

def line_of(u:JV) -> [JV]:
    if has(u, "line"): return glist(u, "line")
    let r = at(u, "recipe")
    return [ line_step(as_int(at(r, "tier")), r, at(u, "eval")) ]

// Type k takes another recipe and line (World._make_type's fields; retype does the rest).
def retarget_type(k:int, r:JV, e:JV, line:[JV]):
    var radius = BASE_RADIUS * as_int(at(r, "scale")) / 100
    if has(r, "mount"): radius = max(radius, MOUNTED_RADIUS)
    if gint(e, "radius", 0) > 0: radius = as_int(at(e, "radius"))
    let tags = eval_tags(e)
    let heal = gint(e, "heal", 0)
    let trader = has_s(tags, "trade")
    t_radius[k] = min(radius, MAX_RADIUS)
    t_worker[k] = if has_s(tags, "worker"): 1 else: 0
    t_healer[k] = if heal > 0: 1 else: 0
    t_trader[k] = if trader: 1 else: 0
    t_harmless[k] = if trader or gstr(e, "targets", "") == "none": 1 else: 0
    t_posture[k] = if heal > 0 or trader: PASSIVE else: AGGRESSIVE
    var mc = 0
    var found = false
    for(glist(gobj(su_rules, "movement"), "classes")) entry:
        if not found and has_s(tags, rstr(entry, "tag")):
            mc = str_index(CLASS_NAMES, rstr(entry, "class"))
            found = true
    t_mclass[k] = mc
    t_docks[k] = if has_s(tags, "docks"): 1 else: 0
    t_age[k] = as_int(at(line[0], "age"))
    let no_heal = gstrs(at(su_rules, "combat"), "heal_not")
    t_no_heal[k] = if any_in(tags, no_heal): 1 else: 0
    su_type_eval[k] = e
    su_type_line[k] = line
    su_type_recipe[k] = r
    lines[k] = map(line) l: line_step_of(t_slot[k], l)
    for(u_kind) uk, i:
        if uk == k:
            u_radius[i] = t_radius[k]
            u_mclass[i] = t_mclass[k]

def swap_race(p:int, race:JV):
    let units = glist(race, "units")
    for(t_slot.length) k:
        if t_player[k] == p:
            for(units) u:
                if rstr(at(u, "recipe"), "slot") == t_slot[k]:
                    retarget_type(k, at(u, "recipe"), at(u, "eval"), line_of(u))
    su_races[p] = race
    let ident = shallow_copy(identity_of(rstr(race, "creature"), rstr(race, "family")))
    su_idents[p] = ident
    let fxs = []::JV
    for(glist(ident, "bonuses")) b:
        for(glist(b, "effects")) fx:
            if not priced(fx) and not has(fx, "start"): fxs.push(fx)
    race_fx[p] = map(fxs) fx: encode_effect(fx)
    let ab = gobj(ident, "ability")
    let on = ab.keys.length > 0
    ab_kind[p] = if on: 1 else: 0
    ab_range[p] = if on: as_int(at(ab, "range")) else: 0
    ab_radius[p] = if on: as_int(at(ab, "radius")) else: 0
    ab_lasts[p] = if on: as_int(at(ab, "lasts")) else: 0
    ab_slow[p] = if on: as_int(at(ab, "slow_pct")) else: 0
    ab_cooldown[p] = if on: as_int(at(ab, "cooldown")) else: 0
    for(t_slot.length) k:
        if t_player[k] == p:
            t_ability[k] = if on and has(ab, "tag") and reaches_tags(ab, eval_tags(su_type_eval[k])): 1 else: 0
    retype(p)
    tech_refresh(p)
    type_gen++

// Balance a newcomer against the others by fights (the running world stashed, then back), and
// put the prices on it. Returns the rounds' report.
def balance_newcomer(race:JV, others:[JV], rounds:int, report_fn) -> void:
    let rules = su_rules
    stash_world()
    reset_world()
    let races = [ race ]
    for(others) o: races.push(o)
    auto_balance(races, rules, 2, rounds, 10) round, units, rates, mean, off:
        report_fn(round, units, rates, mean, off)
    unstash_world()
    for(glist(race, "units")) un:
        let slot = rstr(at(un, "recipe"), "slot")
        let pct = rr_price_pct.get(rstr(race, "key") + "|" + slot, 100)
        if pct != 100:
            for(line_of(un)) l:
                let c = at(at(l, "eval"), "cost")
                for(c.a) v, n: c.a[n] = jint(round10(as_int(v) * pct / 100))
