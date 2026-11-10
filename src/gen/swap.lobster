// ------------------------------------------------------------------ a new race mid-match (Lobster only: the generator in play)
// A player's people become another race while the match runs, at its own prices (calibrated offline,
// D-195: no fights), and each of the player's unit lines takes the new race's line of the same slot
// (its looks, stats, prices, the age it's in, research it has), as do its bonuses and its buildings'
// style. Units alive change
// in place (their share of health kept). A line the new race lacks stays as it was.
// Attack classes the match didn't know (a tag no race at the start had) count as the last class,
// as in GDScript's _class.

// Type k takes another recipe and line (World._make_type's fields; retype does the rest).
def retarget_type(k:int, e:JV):
    let tags = unit_tags(e)
    let heal = gint(e, "heal", 0)
    let trader = has_s(tags, "trade")
    t_radius[k] = min(as_int(at(e, "radius")), MAX_RADIUS)
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
    t_age[k] = as_int(at(e, "age"))
    let no_heal = gstrs(at(su_rules, "combat"), "heal_not")
    t_no_heal[k] = if any_in(tags, no_heal): 1 else: 0
    su_units[k] = e
    lines[k] = map(glist(e, "line")) l: line_step_of(t_slot[k], l)
    for(u_kind) uk, i:
        if uk == k:
            u_radius[i] = t_radius[k]
            u_mclass[i] = t_mclass[k]

def swap_race(p:int, race:JV):
    let ident = race_to_side(race)
    for(t_slot.length) k:
        if t_player[k] == p:
            for(glist(ident, "units")) u:
                if rstr(u, "slot") == t_slot[k]: retarget_type(k, u)
    su_races[p] = race
    su_sides[p] = ident
    let fxs = filter(glist(ident, "effects")) fx: not has(fx, "start")
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
            t_ability[k] = if on and has(ab, "tag") and reaches(ab, unit_tags(su_units[k])): 1 else: 0
    retype(p)
    tech_refresh(p)
    type_gen++
