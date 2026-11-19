// Milestone 14's race identity in the sim (tests/test_race_identity.gd): each race's bonuses (mixed from
// its group, creature and culture), its own research, what it lacks, and its ability, all as data
// (gen/identity.lobster, lib/tech.lobster, lib/abilities.lobster). "N checks, M failed" at the end,
// exit code 1 on a failure.
// Run from src:  lobster test_race_identity.lobster [-- part:i/n]
//
// As in GDScript, with the Lobster sim's own shapes: the Lobster sim says whether something may be done
// (tech_barred, build_barred, trade_barred: yes or no), not why; GDScript's reasons are checked as the
// state behind them: NOT_IN_TREE is research the race doesn't have (Research.open, after the earlier
// reasons pass: why_not's order), a lacked building (bm_lacks) or trade (trade_lacked); "needs ..." an
// age-up barred by a missing building. Tech.bpct's building percents are read where the sim keeps them
// (bm_research_time, bm_age_time, a farm's food in bm_food). SPAWN (a debug command the Lobster sim
// doesn't have) is the same jittered placing done by the test at the tick the command would run.
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

let SEED = 20261013
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

def races_of(prompts:[string]) -> [JV]: return map(prompts) pr: generate(pr, base_rules, 0)

def new_world(prompts:[string], r:JV):
    reset_world()
    setup_match(SEED, "flat_test", races_of(prompts), r, [])

def new_world_2v2(prompts:[string]):
    reset_world()
    setup_match(SEED, "reed_meadow_2v2", races_of(prompts), base_rules, [ 0, 0, 1, 1 ])

def bare() -> JV:
    let r = deep_copy(base_rules)
    let st = at(at(r, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))
    return r

def res(name:string) -> int: return str_index(resource_names, name)
def bk(id:string) -> int: return btype_index(id)

def steps(n:int):
    for(n): step()

def rich_at(p:int, age:int):
    ages[p] = age
    for(num_resources) r: stock[r][p] = 5000

// A finished building of type id for p at (cx, cy); its slot.
def put(p:int, id:string, cx:int, cy:int) -> int:
    let k = bk(id)
    let b = place(p, k, cx, cy)
    b_done[b] = 1
    b_hp[b] = bm_hp[p][k]
    return b

def near_start(p:int, d:int) -> int, int: return start_x[p] / 1000 + d, start_y[p] / 1000 + d

def bcost_of(p:int, id:string, r:string) -> int: return bm_cost[p][bk(id)][res(r)]

// Tech.why_not == NOT_IN_TREE: research r at building slot b isn't in p's tree, the earlier reasons
// (not here, researched, a track or line step first, nothing to upgrade, a later age) passing first.
def not_in_tree(p:int, b:int, id:string) -> bool:
    let r = research_index(id)
    if r < 0 or b < 0 or b_owner[b] != p or b_done[b] == 0: return false
    let item = research[r]
    if item.building != b_kind[b] or researched[p][r] == 1: return false
    if item.after >= 0 and researched[p][item.after] == 0: return false
    if not item.line_has[p]: return false
    if item.before[p] >= 0 and researched[p][item.before[p]] == 0: return false
    if ages[p] < item.age: return false
    return item.open[p] == 0

def can_research(p:int, b:int, id:string) -> bool: return not tech_barred(p, b, research_index(id))

// The SPAWN command as World runs it: at the start of the turn after next, n units of the slot jittered
// round (x, y) on open ground in their lane. Their ids.
def spawn(p:int, slot:string, x0:int, y0:int, n:int) -> [int]:
    let k = type_of_slot(p, slot)
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
        ids.push(u_id[add_unit(p, k, x, y)])
    grow_scratch()
    step()
    return ids

def slowed_now(uid:int) -> bool: return ids_get(slow_ids, slow_pcts, uid, 100) < 100
def stuck_now(uid:int) -> bool: return ids_get(slowed_ids, slowed_until, uid, 0) > 0

// Building bonuses: bugs' cheap houses, spiders' cheap walls, imperial buildings, Han walls, rodents'
// bigger houses, beetles' wood, folk research.
def g_buildings():
    new_world([ "forest beetles", "sewer rats" ], base_rules)
    let r0 = su_races[0]
    expect(rstr(r0, "creature") == "beetle" and rstr(r0, "family") == "forest", "the prompt gives forest beetles ({rstr(r0, "creature")}/{rstr(r0, "family")})")
    expect(bcost_of(0, "house", "wood") == 21 and bcost_of(1, "house", "wood") == 30, "bugs: houses cost 30% less ({bcost_of(0, "house", "wood")}, rats {bcost_of(1, "house", "wood")})")
    let wood = res("wood")
    expect(gather_ticks[0][wood] == base_gather_ticks[wood] * 85 / 100, "beetles: wood gathered 15% faster (bark borers; the forest\'s wood bonus takes its alt) ({gather_ticks[0][wood]} ticks)")
    let bugs_research = bm_research_time[0][bk("armoury")]
    // Rodents: a house holds 6.
    let cap0 = pop_cap[1]
    let hx, hy = near_start(1, 4)
    put(1, "house", hx, hy)
    update_pop()
    expect(pop_cap[1] - cap0 == 6, "rodents: a house holds 6 ({pop_cap[1] - cap0})")
    // Spiders' silk walls; imperial buildings; Han walls.
    new_world([ "spooky spiders", "imperial humans" ], base_rules)
    expect(bcost_of(0, "wall", "stone") == 2 and bcost_of(0, "palisade", "wood") == 1, "spiders: walls cost half ({bcost_of(0, "wall", "stone")} stone, {bcost_of(0, "palisade", "wood")} wood)")
    expect(bcost_of(1, "barracks", "wood") == 135, "imperial: buildings 10% cheaper ({bcost_of(1, "barracks", "wood")})")
    expect(bcost_of(1, "house", "wood") == 27, "imperial: ...houses too ({bcost_of(1, "house", "wood")})")
    new_world([ "han humans", "royal humans" ], base_rules)
    let wk = bk("wall")
    expect(bm_hp[0][wk] == bt_hp_base[wk] * 120 / 100 and bm_hp[1][wk] == bt_hp_base[wk], "han: walls +20% hit points ({bm_hp[0][wk]})")
    // Folk: research 15% faster at every building.
    expect(bm_research_time[0][bk("armoury")] == -15, "folk: research 15% faster")
    expect(bugs_research == 0, "...bugs not")

// Unit bonuses: those in the eval are priced (beetles' shells), the rest are the sim's (centaurs carry,
// spooky sight, swamp wading, rats' price).
def g_units():
    new_world([ "steppe centaurs", "spooky beetles" ], base_rules)
    let cw = type_of_slot(0, "worker")
    expect(t_carry_add[cw] == r_carry * 60 / 100, "centaurs: workers carry 60% more (+{t_carry_add[cw]})")
    let bs = type_of_slot(1, "spear")
    expect(t_sight_add[bs] == 2, "spooky: units +2 sight ({t_sight_add[bs]})")
    let bp = as_int(at(at(su_units[bs], "armour"), "pierce"))
    expect(bp >= 1, "beetles: +1 pierce armour on the spear\'s eval ({bp})")
    new_world([ "swamp humans", "swamp frogs" ], base_rules)
    expect(t_wade[type_of_slot(0, "spear")] == 1, "swamp folk: no slowdown in the swamp or fords")
    expect(t_wade[type_of_slot(1, "spear")] == 0, "swamp frogs: amphibious already, so the swamp\'s bonus takes its alt")
    let food = res("food")
    let farm = bk("farm")
    expect(bm_food[1][farm] == bt_food_base[farm] * 120 / 100, "swamp frogs: ...farms hold 20% more food (rich mud)")
    expect(gather_ticks[1][food] == base_gather_ticks[food] * 80 / 100, "frogs: food gathered 20% faster ({gather_ticks[1][food]})")
    // Team bonuses reach allies (the Nile's granary: 100 more food at the start, for an ally too, not a foe).
    new_world_2v2([ "nile humans", "imperial humans", "imperial humans", "forest humans" ])
    let start_food = as_int(at(at(at(base_rules, "economy"), "start"), "food"))
    expect(stock[food][0] == start_food + 100 and stock[food][1] == start_food + 100 and stock[food][2] == start_food,
           "team: the Nile\'s granary feeds its ally, not its foes ({stock[food][0]} {stock[food][1]} {stock[food][2]})")
    let fk = bk("farm")
    def farm_pct(p:int) -> int: return if bt_food_base[fk] * (100 + 30) / 100 == bm_food[p][fk]: 30 elif bt_food_base[fk] * 110 / 100 == bm_food[p][fk]: 10 else: -1
    expect(farm_pct(0) == 30 and farm_pct(1) == 10 and farm_pct(3) == 10,
           "team: imperial granaries (farms +10%) for themselves and their allies, on top of the Nile\'s own +20%")
    expect(bm_age_time[0][bk("town_center")] == -20, "nile: ages advance 20% faster")
    // The rats' "units 10% cheaper": the rat's line against its own recipe priced as a creature with no such bonus
    // (not against another race's line: calibrated prices, D-195, price a rat body and a human one apart).
    let rat = generate("forest rats", base_rules, 0)
    let rat_line = glist(rat, "units")[1]
    let as_human = deep_copy(at(rat_line, "recipe"))
    set(as_human, "creature", jstr("human"))
    def total(e:JV) -> int:
        var t = 0
        for(at(e, "cost").a) v: t += as_int(v)
        return t
    let discounted = total(at(rat_line, "eval"))
    let full = total(evaluate(as_human, base_rules, 1))
    expect(discounted < full and discounted >= full * 85 / 100, "rats: units 10% cheaper ({discounted} against {full} undiscounted)")

// The Norse culture (D-151): "vikings" are Norse; seafarers wade (allies too), plunder pays for kills,
// shield-bearers take arrows better, no archers' age-3 step, Berserkergang their own research.
def g_norse():
    let v = generate("vikings", base_rules, 0)
    expect(rstr(v, "family") == "norse", "vikings: the Norse culture ({rstr(v, "family")})")
    let ident = identity_of(rstr(v, "creature"), rstr(v, "family"))
    expect(has_s(gstrs(ident, "research"), "berserkergang") and has_s(gstrs(ident, "lacks"), "line.archer.3"), "norse: Berserkergang, no archers\' age-3 step")
    new_world_2v2([ "vikings", "forest humans", "imperial humans", "imperial humans" ])
    expect(t_wade[type_of_slot(0, "spear")] == 1 and t_wade[type_of_slot(1, "spear")] == 1 and t_wade[type_of_slot(2, "spear")] == 0,
           "norse seafarers: no slowdown in fords, for an ally too, not a foe")
    expect(t_kill_gold[type_of_slot(0, "spear")] == 3 and t_kill_gold[type_of_slot(0, "worker")] == 0, "norse plunder: every kill brings in 3 gold (not a worker\'s)")
    let spear = (filter(glist(v, "units")) u: rstr(at(u, "recipe"), "slot") == "spear")[0]
    let sp = as_int(at(at(at(spear, "eval"), "armour"), "pierce"))
    expect(gstr(at(at(spear, "recipe"), "parts"), "hand_l", "") != "shield.round" or sp >= 3, "norse: a round shield +1 pierce on top of its own 2 ({sp})")
    for(2) p: rich_at(p, 3)
    let ax, ay = near_start(0, 4)
    let ar = put(0, "archery_range", ax, ay)
    researched[0][research_index("line.archer.2")] = 1
    expect(not_in_tree(0, ar, "line.archer.3") and not can_research(0, ar, "line.archer.3"), "norse: no archers\' age-3 step")

// Lacks: research, buildings, lines, a line's step and the market's trade stay shut; the host's full
// tech tree opens them.
def g_lacks():
    new_world([ "spooky spiders", "royal humans" ], base_rules)
    for(2) p: rich_at(p, 3)
    expect(bm_lacks[0][bk("stable")] == 1 and build_barred(0, bk("stable")), "spiders: no Stable")
    expect(ident_lacks(0, "scout") and ident_lacks(0, "large"), "spiders: ...nor its lines")
    let mx, my = near_start(0, 4)
    let m = put(0, "market", mx, my)
    expect(trade_lacked[0] == 1 and trade_barred(0, m, res("food"), true), "spooky: no market trade")
    let ax, ay = near_start(1, 4)
    let ar = put(1, "archery_range", ax, ay)
    researched[1][research_index("line.skirmisher.2")] = 1
    expect(not_in_tree(1, ar, "line.skirmisher.3"), "royal: no skirmisher age-3 step")
    expect(not not_in_tree(1, ar, "line.archer.3"), "royal: ...other line upgrades as usual")
    // Age 3 asks for a Stable; a race without one needs an Archery Range instead.
    new_world([ "spooky spiders", "royal humans" ], base_rules)
    for(2) p: rich_at(p, 2)
    expect(tech_barred(0, 0, -1), "spiders: age 3 needs something first")
    let a2x, a2y = near_start(0, 4)
    put(0, "archery_range", a2x, a2y)
    expect(not tech_barred(0, 0, -1), "spiders: ...an Archery Range opens age 3, as they have no Stable")
    // A lacked line can't be trained even with its building standing (the full tree off).
    let free_rules = deep_copy(base_rules)
    set(free_rules, "full_tech_tree", jbool(true))
    new_world([ "spooky spiders", "royal humans" ], free_rules)
    expect(bm_lacks[0][bk("stable")] == 0, "full tech tree: spiders may build a Stable")
    expect(not ident_lacks(0, "scout"), "full tech tree: ...and train its lines")
    new_world([ "forest beetles", "steppe centaurs" ], base_rules)
    for(2) p: rich_at(p, 3)
    let rx, ry = near_start(0, 4)
    let ra = put(0, "archery_range", rx, ry)
    expect(not_in_tree(0, ra, "quick_draw"), "beetles: no Quick Draw")
    expect(bm_lacks[1][bk("palisade")] == 0 and bm_lacks[1][bk("wall")] == 0 and not build_barred(1, bk("wall")), "centaurs: basic walls, as every race (Dominic)")
    let ux0, uy0 = near_start(0, 7)
    let ux1, uy1 = near_start(1, 7)
    let u0 = put(0, "university", ux0, uy0)
    let u1 = put(1, "university", ux1, uy1)
    expect(can_research(0, u0, "fortified_walls"), "beetles: Fortified Walls at the University in the last age")
    expect(not_in_tree(1, u1, "fortified_walls"), "centaurs: no Fortified Walls")
    let bid = b_id[ra]
    let k = type_of_slot(0, "mounted_archer")
    if k >= 0: issue_cmd(0, CMD_TRAIN, [], bid, k, 1, 0)
    steps(12)
    expect(k < 0 or not contains(b_queue[b_index_of(bid)], k), "beetles: no mounted archers trained")

// Own research: each race's, at the Castle in age 3; never another's.
def g_own_research():
    new_world([ "sewer rats", "hellenic humans" ], base_rules)
    for(2) p: rich_at(p, 3)
    let x0, y0 = near_start(0, 3)
    let x1, y1 = near_start(1, 3)
    let c0 = put(0, "castle", x0, y0)
    let c1 = put(1, "castle", x1, y1)
    for([ "gnawing_teeth", "rust_spikes" ]) id:
        expect(can_research(0, c0, id), "sewer rats: {id} at the Castle")
        expect(not_in_tree(1, c1, id), "hellenic humans: not {id}")
    for([ "clever_hands", "long_spears" ]) id: expect(can_research(1, c1, id), "hellenic humans: {id}")
    let sp = type_of_slot(0, "spear")
    let b_cls = str_index(su_classes, "building")
    let before = t_atk[sp][b_cls]
    issue_cmd(0, CMD_RESEARCH, [], b_id[c0], research_index("gnawing_teeth"), 0, 0)
    let hs = type_of_slot(1, "spear")
    let reach0 = t_reach[hs]
    issue_cmd(1, CMD_RESEARCH, [], b_id[c1], research_index("long_spears"), 0, 0)
    steps(1200)
    expect(t_atk[sp][b_cls] == before + 2, "gnawing teeth: soldiers +2 against buildings ({before} -> {t_atk[sp][b_cls]})")
    expect(t_reach[hs] == reach0 + 350 and not t_ranged[hs], "long spears: spears reach further, still melee ({reach0} -> {t_reach[hs]})")

// Aztec kills bring in gold.
def g_kills():
    new_world([ "aztec humans", "imperial humans" ], bare())
    let a = type_of_slot(0, "infantry")
    expect(t_kill_gold[a] == 5, "aztec: kills bring in 5 gold ({t_kill_gold[a]})")
    let gold = res("gold")
    let g0 = stock[gold][0]
    let ids = spawn(0, "infantry", 20000, 20000, 3)
    spawn(1, "worker", 21500, 20000, 1)
    issue_cmd(0, CMD_ATTACK_MOVE, ids, 22000, 20000, 0, 0)
    steps(400)
    expect(lost[1] == 1 and stock[gold][0] == g0 + 5, "aztec: a kill brought in 5 gold (lost {lost[1]}, gold {g0} -> {stock[gold][0]})")

// The walk through the web, in ticks: long enough to cross all of it (the web is 3 tiles across, 4.5 tiles ahead).
let WEB_WALK = 200

// The same walk (as in g_web) with no web: how far it gets in WEB_WALK ticks.
def walk_without_web() -> int:
    new_world([ "forest spiders", "forest humans" ], bare())
    let walker = spawn(1, "spear", 14500, 14000, 1)[0]
    issue_cmd(1, CMD_STANCE, [ walker ], PASSIVE, 0, 0, 0)
    steps(36)
    issue_cmd(1, CMD_MOVE, [ walker ], 14500, 26000, 0, 0)
    steps(WEB_WALK)
    return u_y[index_of(walker)] - 14000

def web_run() -> [int]:
    new_world([ "forest spiders", "forest humans" ], bare())
    let c = spawn(0, "spear", 10000, 20000, 3)
    let e = spawn(1, "spear", 16000, 20000, 3)
    issue_cmd(0, CMD_ABILITY, c, 15000, 20000, 0, 0)
    issue_cmd(1, CMD_ATTACK_MOVE, e, 9000, 20000, 0, 0)
    let hashes = []::int
    for(600):
        step()
        if tick % 30 == 0: hashes.push(state_hash())
    return hashes

// Spiders' web: a slowing patch where it's thrown, in range, once per cooldown; it wears off; the
// counter: shooters outside it aren't slowed, and it's gone in 15 s. Deterministic.
def g_web():
    let df = walk_without_web()
    new_world([ "forest spiders", "forest humans" ], bare())
    let ab = gobj(su_sides[0], "ability")
    expect(gstr(ab, "kind", "") == "web", "spiders: their ability is the web")
    expect(gobj(su_sides[1], "ability").keys.length == 0, "humans: no ability (their culture\'s, later)")
    let sp = type_of_slot(0, "spear")
    expect(t_ability[sp] == 1 and t_ability[type_of_slot(0, "worker")] == 0, "web: spider soldiers throw it, workers not")
    let caster = spawn(0, "spear", 10000, 20000, 1)[0]
    let walker = spawn(1, "spear", 14500, 14000, 1)[0]
    let free_one = spawn(1, "spear", 26000, 14000, 1)[0]
    issue_cmd(0, CMD_STANCE, [ caster ], PASSIVE, 0, 0, 0)
    issue_cmd(1, CMD_STANCE, [ walker, free_one ], PASSIVE, 0, 0, 0)
    issue_cmd(0, CMD_ABILITY, [ caster ], 30000, 20000, 0, 0)  // out of range: nothing
    steps(12)
    expect(webs.length == 0, "web: not past its range")
    issue_cmd(0, CMD_ABILITY, [ caster ], 14000, 20000, 0, 0)
    steps(12)
    expect(webs.length == WEB, "web: thrown where asked ({webs.length / WEB})")
    issue_cmd(0, CMD_ABILITY, [ caster ], 13000, 20000, 0, 0)
    steps(12)
    expect(webs.length == WEB, "web: one per cooldown")
    issue_cmd(1, CMD_MOVE, [ walker ], 14500, 26000, 0, 0)    // straight through the web
    issue_cmd(1, CMD_MOVE, [ free_one ], 26000, 26000, 0, 0)  // the same walk in the open
    var slowed = false
    for(WEB_WALK):
        step()
        slowed = slowed or slowed_now(walker)
    let dw = u_y[index_of(walker)] - 14000
    expect(slowed and dw < df * 90 / 100, "web: an enemy walking through it is slowed ({dw} vs {df} milli-tiles without the web)")
    expect(not slowed_now(caster), "web: never its own side")
    steps(as_int(at(ab, "lasts")))
    expect(webs.length == 0, "web: wears off")
    // Sticky Silk (the spiders' own research): their shots slow what they hit.
    new_world([ "forest spiders", "forest humans" ], bare())
    researched[0][research_index("sticky_silk")] = 1
    retype(0)
    tech_refresh(0)
    expect(t_slow_on_hit[type_of_slot(0, "archer")] > 0 and t_slow_on_hit[type_of_slot(0, "spear")] == 0, "sticky silk: on the shooters only")
    let arch = spawn(0, "archer", 10000, 20000, 2)
    let tgt = spawn(1, "spear", 14000, 20000, 1)[0]
    issue_cmd(1, CMD_STANCE, [ tgt ], PASSIVE, 0, 0, 0)
    issue_cmd(0, CMD_ATTACK, arch, tgt, 0, 0, 0)
    var stuck = false
    for(300):
        step()
        stuck = stuck or stuck_now(tgt)
    expect(stuck, "sticky silk: a hit slows the target")
    // The same commands, the same world: the same hashes.
    let a = web_run()
    let b = web_run()
    var same = a.length == b.length and a.length > 0
    for(a) v, i:
        if same and v != b[i]: same = false
    expect(same, "web: deterministic ({a.length} checkpoints)")

let GROUPS = [ "buildings", "units", "lacks", "own_research", "kills", "web", "norse" ]

def run_group(name:string):
    switch name:
        case "buildings": g_buildings()
        case "units": g_units()
        case "lacks": g_lacks()
        case "own_research": g_own_research()
        case "kills": g_kills()
        case "web": g_web()
        case "norse": g_norse()
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
