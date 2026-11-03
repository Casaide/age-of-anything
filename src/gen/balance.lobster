// ------------------------------------------------------------------ balance by simulation (tests/round_robin.gd, then pricing)
// Every soldier of the given races fights every other at equal cost (the same budget a side, both
// attack-moving, on flat_test, from the same spots), in one age; a unit's value is its win rate.
// The fights are the GDScript round robin's, tick for tick (its world's rng spawns them).
// Then the auto-balance: a unit winning more than the mean costs more next round, one losing
// less, until every win rate is within the tolerance of the mean: prices set by fights, at race
// creation (the lobby's load time), not by hand.

let RR_SLOTS = [ "spear", "infantry", "skirmisher", "archer", "large", "scout", "mounted_archer" ]
let RR_SLOTS_AGE3 = [ "unique" ]
let RR_BUDGET = 1200
let RR_LIMIT = 3000
let RR_FROM = [ int2 { 11000, 20500 }, int2 { 21000, 20500 } ]
let SPAWN_JITTER = 400

class RRUnit:
    race:int  // index into the races
    slot:string
    label:string

var rr_price_pct = dictionary<string, int>(64)  // "race|slot" -> its price, percent of the generator's
var rr_fights = 0
var rr_ticks = 0

def rr_units(races:[JV], age:int) -> [RRUnit]:
    let out = []::RRUnit
    for(races) r, k:
        let slots = copy(RR_SLOTS)
        if age >= 3: for(RR_SLOTS_AGE3) s: slots.push(s)
        for(slots) slot:
            for(glist(r, "units")) u:
                if rstr(at(u, "recipe"), "slot") == slot:
                    var step = glist(u, "line")[0]
                    for(glist(u, "line")) l:
                        if as_int(at(l, "age")) <= age: step = l
                    out.push(RRUnit { k, slot, rstr(at(step, "recipe"), "name") + " (" + rstr(r, "name") + ")" })
    return out

def price_key(races:[JV], u:RRUnit) -> string: return rstr(races[u.race], "key") + "|" + u.slot

// The soldiers' research every army has by an age (D-200): the armoury's, barracks', archery range's and stable's, not
// a culture's own (castle research is race identity: measured by calibrate.lobster, never fitted to).
let RR_RESEARCH_BUILDINGS = [ "armoury", "barracks", "archery_range", "stable" ]
var rr_generic = []::string  // their ids (data/tech.json), read on first use
var rr_skip = ""             // a research both sides go without (calibrate.lobster upgrades)
var rr_give = [ "", "" ]     // per side, a research it has besides (calibrate.lobster upgrades: one side's)
var rr_upgrades = true       // false: line upgrades only (calibrate.lobster pairs plain: the fights before D-200)

def rr_generic_ids() -> [string]:
    if not rr_generic.length:
        for(glist(load_json(lib_root + "/tech.json"), "research")) r:
            if has_s(RR_RESEARCH_BUILDINGS, gstr(r, "building", "")) and not has(r, "own"): rr_generic.push(rstr(r, "id"))
    return rr_generic

// Put a player in an age with every unit line upgraded up to it and the soldiers' research of that age and before.
def rr_in_age(p:int, age:int):
    ages[p] = age
    let generic = rr_generic_ids()
    for(research) r, k:
        if r.line_age > 0 and r.line_age <= age: researched[p][k] = 1
        elif rr_upgrades and r.line_age == 0 and r.age <= age and r.id != rr_skip and has_s(generic, r.id): researched[p][k] = 1
        elif r.id == rr_give[p]: researched[p][k] = 1
    retype(p)

def rr_left() -> int, int:
    var a = 0
    var b = 0
    for(u_owner) o, i:
        if t_animal[u_kind[i]] == 0:
            if o == 0: a++
            elif o == 1: b++
    return a, b

// +1 if a wins, -1 if b wins, 0 for a draw (by value left standing). trace prints the state hash every tick
// (rr_hash.gd's check), and the whole state at tick dumpat.
def rr_fight(races:[JV], rules:JV, age:int, a:RRUnit, b:RRUnit, trace = false, dumpat = -1) -> int:
    reset_world()
    setup_world(1, "flat_test", [ races[a.race], races[b.race] ], rules, [])
    for(2) p: rr_in_age(p, age)
    let value = []::int
    let kinds = []::int
    let counts = []::int
    for([ a, b ]) u, p:
        let k = type_of_slot(p, u.slot)
        assert k >= 0
        let pct = rr_price_pct.get(price_key(races, u), 100)
        if pct != 100: t_cost[k] = map(t_cost[k]) c: c * pct / 100
        var cost = 0
        for(t_cost[k]) c: cost += c
        value.push(cost)
        kinds.push(k)
        counts.push(max(1, (RR_BUDGET + cost / 2) / cost))
    while tick < 8:  // (the spawn ran at the start of turn 2: World.issue's delay)
        step()
        if trace: print "h {tick} {state_hash()}"
    for(2) p:
        let k = kinds[p]
        for(counts[p]):
            let x = RR_FROM[p].x + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
            let y = RR_FROM[p].y + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
            assert cell_walkable(x / TILE, y / TILE, lane_base[p] + t_mclass[k])
            add_unit(p, k, x, y)
    grow_scratch()
    step()
    if trace: print "h {tick} {state_hash()}"
    for(2) p:
        let ids = []::int
        for(u_owner) o, i:
            if o == p: ids.push(u_id[i])
        issue_cmd(p, CMD_ATTACK_MOVE, ids, RR_FROM[1 - p].x, RR_FROM[1 - p].y, 0, 0)
    var la = 1
    var lb = 1
    while tick < RR_LIMIT:
        step()
        if trace: print "h {tick} {state_hash()}"
        if tick == dumpat: print dump_state()
        la, lb = rr_left()
        if la == 0 or lb == 0: break
    rr_fights++
    rr_ticks += tick
    let va = la * value[0]
    let vb = lb * value[1]
    return if va > vb: 1 elif vb > va: -1 else: 0

// Every pair once; each unit's win rate (percent of its decided fights) and the mean.
def round_robin(races:[JV], rules:JV, age:int, units:[RRUnit]) -> [int], int:
    let wins = map(units.length): 0
    let played = map(units.length): 0
    for(units.length) i:
        var j = i + 1
        while j < units.length:
            let r = rr_fight(races, rules, age, units[i], units[j])
            if r != 0:
                played[i]++
                played[j]++
                if r > 0: wins[i]++ else: wins[j]++
            j++
    let rates = map(units.length) k: wins[k] * 100 / max(1, played[k])
    var total = 0
    for(rates) r: total += r
    return rates, total / max(1, units.length)

// The fights' rules: no town, no workers (the round robin's bare match; animals as the rules say).
def bare_rules(rules:JV) -> JV:
    let bare = deep_copy(rules)
    let st = at(at(bare, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))

    return bare

// Rounds of fights; between rounds each unit off the mean by more than the tolerance has its
// price moved towards fairness: a winner pays more, a loser less, by its win rate at first; once a
// price has been seen both too low (it won too much) and too high, the next is halfway between, so
// prices settle instead of swinging. Returns the last rates.
def auto_balance(races:[JV], rules:JV, age:int, rounds:int, tolerance:int, report) -> [int]:
    let bare = bare_rules(rules)
    let units = rr_units(races, age)
    let too_cheap = map(units.length): 0  // the dearest price it still won too much at (0: none seen)
    let too_dear = map(units.length): 0   // the cheapest price it lost too much at
    var rates = []::int
    for(rounds) round:
        let r, mean = round_robin(races, bare, age, units)
        rates = r
        var off = 0
        for(units.length) k:
            if abs(rates[k] - mean) > tolerance: off++
        report(round, units, rates, mean, off)
        if off == 0 or round == rounds - 1: return rates
        for(units) u, k:
            let key = price_key(races, u)
            let pct = rr_price_pct.get(key, 100)
            if rates[k] > mean + tolerance: too_cheap[k] = max(too_cheap[k], pct)
            if rates[k] < mean - tolerance: too_dear[k] = if too_dear[k] == 0: pct else: min(too_dear[k], pct)
            if abs(rates[k] - mean) > tolerance:
                var want = pct * (rates[k] + 25) / (mean + 25)  // the price follows the win rate
                want = clamp(want, pct * 3 / 4, pct * 4 / 3)
                if too_cheap[k] > 0 and too_dear[k] > 0: want = (too_cheap[k] + too_dear[k]) / 2
                rr_price_pct.set(key, max(10, want))
    return rates
