// Heroes in the sim (tests/test_heroes.gd; lib/heroes.lobster; D-159): one per race, trained once at the
// Town Center from age 2 (one out at a time); an aura on nearby friends (not foes, not itself, not far
// ones) in the damage; healing slowly; revived after a wait for a share of its price when it falls;
// deterministic. "N checks, M failed" at the end, exit code 1 on a failure.
// Run from src:  lobster test_heroes.lobster [-- part:i/n]
//
// As in GDScript, with the Lobster sim's own shapes: TRAIN names a unit type (no slot and hero name: the
// GDScript check of a TRAIN that names no hero is the same order here), SPAWN (a debug command the
// Lobster sim doesn't have) is the same jittered placing done by the test at the tick the command would
// run, Heroes.why_not's reasons are hero_barred (a yes or no) with the state behind each reason checked
// ("on the way": in a queue; "revives in": the revival wait), and the hero_fell / hero_up events (the
// Lobster sim has none for heroes) are read from hero_id and hero_fell.
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
import gen.reset

let SEED = 20261014
let SPAWN_JITTER = 400  // World.SPAWN_JITTER

var n_checks = 0
var n_failed = 0

def expect(ok:bool, what:string):
    n_checks++
    if not ok:
        n_failed++
        print "FAIL: " + what

lib_load("../data")
id_load("../data")
let base_rules = load_rules("default")
set(base_rules, "animals", jbool(false))

def new_world(prompts:[string], r:JV):
    let races = map(prompts) pr: generate(pr, base_rules, 0)
    reset_world()
    setup_match(SEED, "flat_test", races, r, [])

def bare() -> JV:
    let r = deep_copy(base_rules)
    let st = at(at(r, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))
    return r

def rich(p:int, age:int):
    ages[p] = age
    retype(p)
    tech_refresh(p)
    for(num_resources) r: stock[r][p] = 5000

def tc_of(p:int) -> int:
    let k = btype_index("town_center")
    for(b_id.length) b:
        if b_owner[b] == p and b_kind[b] == k: return b_id[b]
    return -1

def res(name:string) -> int: return str_index(resource_names, name)

def hero_types_of(p:int) -> [int]: return filter(hero_types) k: t_player[k] == p

def hero_type_named(p:int, sid:string) -> int:
    for(hero_types_of(p)) k:
        if rstr(su_units[k], "hero") == sid: return k
    return -1

def hero_sid(k:int) -> string: return rstr(su_units[k], "hero")
def out_id(k:int) -> int: return hero_id[hero_slot(k)]

def heroes_out(p:int) -> int:
    var n = 0
    for(u_x.length) i:
        if u_owner[i] == p and t_hero[u_kind[i]]: n++
    return n

def steps(n:int):
    for(n): step()

// The SPAWN command as World runs it: at the start of the turn after next, n units of the slot (the
// named hero for "hero") jittered round (x, y) on open ground in their lane. Their ids.
def spawn(p:int, slot:string, x0:int, y0:int, n:int, sid:string) -> [int]:
    let k = if slot == "hero": hero_type_named(p, sid) else: type_of_slot(p, slot)
    assert k >= 0
    let run_at = (tick / TICKS_PER_TURN + 2) * TICKS_PER_TURN
    while tick < run_at: step()
    let ids = []::int
    for(n):
        var x = x0 + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
        var y = y0 + range_int(su_rng, -SPAWN_JITTER, SPAWN_JITTER)
        let ln = lane_base[p] + t_mclass[k]
        if not walkable(x, y, ln):
            let cx, cy = centre(nearest_walkable(cell_of(x, y), ln))
            x = cx
            y = cy
        let i = add_unit(p, k, x, y)
        ids.push(u_id[i])
        if t_hero[k] and out_id(k) == 0: hero_spawned(i)  // (a spawned hero is that hero, if it isn't out already)
    grow_scratch()
    step()
    return ids

def order_train(p:int, bid:int, k:int): issue_cmd(p, CMD_TRAIN, [], bid, k, 1, 0)

// The hero once, at the Town Center, from age 2, for its price.
def g_train():
    new_world([ "romans", "sewer rats" ], base_rules)
    let ks = hero_types_of(0)
    expect(ks.length == 1 and t_hero[ks[0]] and hero_fx[hero_slot(ks[0])].length > 0, "romans have one hero, with an aura ({ks.length})")
    let ks1 = hero_types_of(1)
    expect(ks1.length == 1 and not contains(ks, ks1[0]), "so do the rats, their own")
    expect(has_s(gstrs(su_btypes[btype_index("town_center")], "trains"), "hero"), "the Town Center trains heroes")
    let k = ks[0]
    let sid = hero_sid(k)
    let tc0 = tc_of(0)
    let tc1 = tc_of(1)
    let food = res("food")
    for(num_resources) r: stock[r][1] = 5000
    order_train(1, tc1, ks1[0])  // age 1: not yet
    rich(0, 2)
    let f0 = stock[food][0]
    order_train(0, tc0, k)
    order_train(0, tc0, k)  // the same one again: refused
    order_train(0, tc0, k)  // (GDScript's third, naming no hero, is this same order here)
    steps(16)
    let b0 = b_index_of(tc0)
    let q = b_queue[b0]
    expect((filter(q) e: e == k).length == 1 and q.length == 1, "the hero in the queue, once ({q})")
    expect(stock[food][0] == f0 - t_cost[k][food], "paid its price once ({f0} -> {stock[food][0]})")
    expect(b_queue[b_index_of(tc1)].length == 0, "no hero in age 1")
    expect(hero_barred(0, k) and contains(b_queue[b0], k), "queued: not again")
    steps(t_train_ticks[k] + 40)
    expect(out_id(k) != 0 and heroes_out(0) == 1, "the hero came out and is known ({out_id(k)})")
    expect(hero_sid(u_kind[index_of(out_id(k))]) == sid, "the one named is the one that came")
    order_train(0, tc0, k)
    steps(16)
    expect(not contains(b_queue[b0], k) and hero_barred(0, k) and out_id(k) != 0, "out: not a second")
    // It heals slowly.
    u_hp[index_of(out_id(k))] = 50
    steps(r_regen * 5)
    let hp = u_hp[index_of(out_id(k))]
    expect(hp >= 54 and hp <= 56, "it heals a hit point every {r_regen} ticks (50 -> {hp})")

// The aura: friends within its reach, of the kind it names; not foes, not far friends, not itself; in
// the damage. Two heroes' auras of one stat don't add up.
def g_aura():
    new_world([ "swamp frogs drowned", "sewer rats" ], bare())  // the Drowned: +1 attack
    let hk = hero_type_named(0, "drowned")
    expect(hk >= 0 and hero_types_of(0).length == 1, "\'swamp frogs drowned\' have the Drowned, and only it")
    let h = spawn(0, "hero", 20000, 20000, 1, "drowned")[0]
    let near = spawn(0, "spear", 22000, 20000, 1, "")[0]
    let far = spawn(0, "spear", 40000, 20000, 1, "")[0]
    let foe = spawn(1, "spear", 20000, 22500, 1, "")[0]
    issue_cmd(0, CMD_STANCE, [ h, near, far ], PASSIVE, 0, 0, 0)
    issue_cmd(1, CMD_STANCE, [ foe ], PASSIVE, 0, 0, 0)
    steps(16)
    expect(out_id(hk) == h, "a spawned hero is that hero")
    let fx = hero_fx[hero_slot(hk)][0]
    let stat = if fx.kind == 0: 0 elif fx.stat == 0: 1 else: 2  // attack, melee armour, pierce armour
    def aura(uid:int) -> int: return if c_aura.length: c_aura[index_of(uid) * AURA + stat] else: 0
    expect(aura(near) == fx.value, "a friend nearby gets the aura (+{fx.value}: {aura(near)})")
    expect(aura(far) == 0 and aura(foe) == 0 and aura(h) == 0, "not far friends, foes or the hero itself")
    let kept = c_aura
    c_aura = [ 1, 0, 0, 0, 1, 2 ]  // slot 0: +1 attack; slot 1: +1 melee, +2 pierce armour
    expect(boost(0, 1, 0, 5, 1) == 5 and boost(0, 1, 1, 5, 1) == 4 and boost(0, -1, 0, 5, 1) == 6 and boost(-1, 1, 1, 2, 1) == 1,
           "in the damage: attack adds, armour takes off, never under the floor")
    c_aura = kept
    // Walk away: the aura goes with the heroes.
    issue_cmd(0, CMD_MOVE, [ h ], 40000, 22000, 0, 0)
    steps(700)
    expect(aura(near) == 0 and aura(far) == fx.value, "the aura goes with the hero")

// When it falls: known as fallen, a wait, then revived at the Town Center for a share of its price.
def g_revive():
    new_world([ "spooky spiders", "imperial humans" ], base_rules)
    rich(0, 2)
    rich(1, 2)
    let k = hero_types_of(0)[0]
    let sid = hero_sid(k)
    let n = hero_slot(k)
    let h = spawn(0, "hero", 20000, 20000, 1, sid)[0]
    let foes = spawn(1, "infantry", 21500, 20000, 12, "")
    u_hp[index_of(h)] = 5
    issue_cmd(1, CMD_ATTACK, foes, h, 0, 0, 0)
    var fell = false
    for(400):
        if not fell:
            step()
            fell = hero_fell[n] > 0
    expect(fell and hero_id[n] == 0 and hero_fell[n] > 0, "the hero fell, and the sim knows ({hero_fell[n]})")
    for(foes) id:  // (out of the way of what comes next)
        let j = index_of(id)
        if j >= 0: u_x[j] = 60000
    let tc = tc_of(0)
    let gold = res("gold")
    let g0 = stock[gold][0]
    def revive_left() -> int: return max(0, hero_fell[n] - 1 + r_revive - tick)
    order_train(0, tc, k)
    steps(16)
    expect(stock[gold][0] == g0 and hero_barred(0, k) and revive_left() > 0, "it can\'t be revived at once ({revive_left()} ticks to wait)")
    while revive_left() > 0: step()
    let price = t_cost[k][gold]
    let revive = unit_cost(k)[gold]
    expect(revive == price * r_revive_pct / 100 and revive < price, "a revival costs {r_revive_pct}% of its price ({revive} of {price} gold)")
    order_train(0, tc, k)
    var back = false
    for(t_train_ticks[k] + 60):
        step()
        back = back or hero_id[n] != 0
    expect(stock[gold][0] == g0 - revive, "paid the revival ({g0} -> {stock[gold][0]})")
    expect(back and hero_id[n] != 0 and heroes_out(0) == 1, "revived at the Town Center")

// The same commands give the same hashes, heroes and auras included.
def g_determinism():
    let runs = []::[int]
    for(2):
        new_world([ "romans", "sewer rats" ], base_rules)
        rich(0, 2)
        rich(1, 2)
        for(2):
            order_train(0, tc_of(0), hero_types_of(0)[0])
            order_train(1, tc_of(1), hero_types_of(1)[0])
        spawn(0, "spear", 30000, 30000, 4, "")
        spawn(1, "spear", 31000, 30000, 4, "")
        let hashes = []::int
        while tick < 1200:
            step()
            if tick % 30 == 0: hashes.push(state_hash())
        runs.push(hashes)
    var same = runs[0].length == runs[1].length and runs[0].length > 0
    for(runs[0]) v, i:
        if same and v != runs[1][i]: same = false
    expect(same, "heroes: same commands, same hashes")

let GROUPS = [ "train", "aura", "revive", "determinism" ]

def run_group(name:string):
    switch name:
        case "train": g_train()
        case "aura": g_aura()
        case "revive": g_revive()
        case "determinism": g_determinism()
        default: assert false

var shard = 0
var shards = 1
for(command_line_arguments()) arg:
    if starts_with(arg, "part:"):
        let ij = tokenize(substring(arg, 5, arg.length - 5), "/", "")
        shard = string_to_int(ij[0])
        shards = string_to_int(ij[1])
let t_start = seconds_elapsed()
for(GROUPS) name, k:
    if k % shards == shard:
        let t0 = seconds_elapsed()
        let before = n_checks
        run_group(name)
        print "-- {name}: {n_checks - before} checks, {int((seconds_elapsed() - t0) * 1000.0)} ms"
print "\n{n_checks} checks, {n_failed} failed ({int((seconds_elapsed() - t_start) * 1000.0)} ms)"
if n_failed > 0: set_exit_code(1)
