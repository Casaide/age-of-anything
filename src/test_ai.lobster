// The AI's checks (tests/test_ai.gd, ported): the bot (lib/bot.lobster) and match flow (lib/match.lobster).
// Quick pieces are scenario checks (a few minutes of sim each): the counter-pick, the Wonder, answers to
// raids, sheltering, walled-off fords, rams, hills, guarding the crossing, age 3, surrender, Easy, siege
// engines, trade, walls. Slow pieces are whole bot matches: against a passive side, bot against bot
// (twice: the same hashes and winner), other races, Hard against Normal, walled bases, the land, the
// Siege mode, each level left alone. Prints each match's minute-by-minute timeline.
// Run from src:
//   lobster test_ai.lobster -- [map_id] [mode] [shard:<i>/<n>]
// Modes: none (every piece), quick, slow, piece:<name>[,<name>...], or a group (age3, levels, rams, walls,
// pick, hills, land, reach); combine <log>... reads shards' logs and makes the checks across pieces.
// shard:<i>/<n>: every n-th piece of the mode from the i-th (0-based), for n processes side by side
// (test_ai.sh, or shards.sh test_ai.lobster, does that). Prints "N passed, M failed" and exits 1 on a failure. flat_test by default.
//
// Differences from test_ai.gd:
// - SPAWN is the kit's (testkit/kit.lobster): the same units at the same turn, but run before the turn's
//   commands rather than among them.
// - GDScript's events for research, ages, heroes, trade and webs are read off the state (testkit's Watch);
//   the bots' commands are read as they're issued (their turn's tick), not from the history.
// - The bots' config is global in Lobster: a test's changes and a level go in before the bot is made, and
//   Hard against Normal swaps the level in before each side thinks.
// - Not reported: the land's per-study counts (Land has no stats here: roads, tours and the key are) and
//   the hill orders' count. Camps by far gatherers are counted as the camp BUILDs the bot issues on a
//   think where its camp timer was just reset (expand.camps), an approximation of expand.gd's stats.

import std
import vec
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
import gen.setup
import gen.modes
import gen.start
import gen.reset
import testkit.kit

let SEED = 7
let LIMIT = 20 * 60 * 30    // 30 minutes: a match must end, however slowly

// The pieces in test_ai.gd's order: name, tier.
let PIECES = ["pick", "wonder", "respond", "shelter", "walled_fords", "rams", "hills", "guard", "age3", "surrender",
              "easy", "siege_bot", "trade_bot", "walls_bot",
              "passive_frogs", "passive_rats", "bvb", "bvb_again", "centaurs_frogs", "rats_centaurs", "hard",
              "walled_palisade", "walled_wall", "walled_gap", "land", "siege_mode"]
let SLOW_FROM = 14          // PIECES from here on are slow
let GROUPS = [["age3", "age3"], ["levels", "levels_easy,levels_normal,levels_hard"], ["rams", "rams,siege_bot"],
              ["walls", "rams,walled_palisade,walled_wall,walled_gap,walls_bot"], ["pick", "pick"], ["hills", "hills,guard"],
              ["land", "land,guard,hills"], ["reach", "respond,shelter,walled_fords"]]

var map_id = "flat_test"
var piece = ""
let stats = dictionary<string, int>(64)   // "piece key" -> value (printed as "@@ piece key value")

def stat(key:string, v:int):
    stats.set(piece + " " + key, v)
    print "@@ {piece} {key} {v}"

lib_load("../data")
id_load("../data")
let rules = load_rules("default")
let frogs = generate("angry swamp frogs with reed spears", rules, 0)
let rats = generate("sewer rats with cheese hammers", rules, 0)

def rname(r:JV) -> string: return rstr(r, "name")

def world(races:[JV], r:JV): new_world(SEED, map_id, races, r, [])

def start_of(p:int) -> int, int: return start_x[p], start_y[p]

def stock_at_least(p:int, n:int):
    for(num_resources) r: stock[r][p] = max(stock[r][p], n)

def is_soldier(k:int) -> bool: return not t_worker[k] and not t_healer[k] and t_animal[k] == 0

// The commands a player issued since `seq` (still pending: issued this turn or the last).
def issued_since(p:int, seq:int) -> [Cmd]: return filter(pending) c: c.player == p and c.seq >= seq

// ------------------------------------------------------------------ whole matches

class MatchResult:
    winner:int
    end_tick:int
    hashes:int              // state hashes taken (every 30 ticks) ...
    hash:int                // ... and a hash of them
    most:[int]              // healers: the most each side had at once
    heals:[int]
    behind = 0
    samples = 0
    heroes_up:[int]
    revived:[int]
    fell:[int]
    kinds:[[int]]           // per side: hero slots it fielded

// Healers: the most each side had, and whether they keep behind their army: when soldiers are out (3 or
// more over 10 tiles from home), the healers' middle is nearer home than theirs. Soldiers posted with far
// gatherers (a bot's escorts) aren't the army the healers follow.
def watch_healers(r:MatchResult, sides:[Side]):
    for(2) p:
        let hx, hy = start_of(p)
        let n = [0, 0]
        let d = [0, 0]
        let f = sides[p].full
        for(u_id.length) i:
            let k = u_kind[i]
            if u_owner[i] == p and not t_worker[k] and t_animal[k] == 0 and not (f and is_escort(f.expand, u_id[i])):
                let h = if t_healer[k]: 1 else: 0
                let dist = int(sqrt(float(u_x[i] - hx) * float(u_x[i] - hx) + float(u_y[i] - hy) * float(u_y[i] - hy))) / 1000
                if h == 1 or dist > 10:
                    n[h]++
                    d[h] += dist
        r.most[p] = max(r.most[p], n[1])
        if n[0] >= 3 and n[1] > 0:
            r.samples++
            if d[1] / n[1] < d[0] / n[0]: r.behind++

def play(races:[JV], sides:[Side], title:string, quiet:bool) -> MatchResult:
    if not quiet: print "\n== " + title
    let res = MatchResult { -1, 0, 0, 0, [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [[], []] }
    let aged = [-1, -1]
    let bought = [[]::string, []::string]
    let wt = new_watch()
    var h = 0
    while tick < LIMIT and winner < 0:
        think_all(sides)
        watch_before(wt)
        wstep()
        let hp = watch_after(wt)
        for(hp.research_p) p, n:
            if p < 2: bought[p].push(research[hp.research_k[n]].id + " " + clock(tick))
        for(hp.hero_up_n) hn, n:
            let p = t_player[hero_types[hn]]
            if p < 2:
                if hp.hero_revived[n] != 0: res.revived[p]++ else: res.heroes_up[p]++
                if not contains(res.kinds[p], hn): res.kinds[p].push(hn)
        for(hp.hero_fell_n) hn:
            let p = t_player[hero_types[hn]]
            if p < 2: res.fell[p]++
        for(events) e:
            if e.kind == EV_HEAL:
                let hi = index_of(e.a)
                if hi >= 0 and u_owner[hi] < 2: res.heals[u_owner[hi]]++
        if tick % 30 == 0:
            h = mix(h, state_hash())
            res.hashes++
        if tick % 100 == 0: watch_healers(res, sides)
        for(2) p:
            if aged[p] < 0 and ages[p] >= 2: aged[p] = tick
        if tick % 1200 == 0 and not quiet:
            var line = clock(tick)
            for(races.length) p:
                var army = 0
                var workers = 0
                var healers = 0
                for(u_id.length) i:
                    if u_owner[i] == p:
                        let k = u_kind[i]
                        if t_worker[k]: workers++
                        elif t_healer[k]: healers++
                        elif t_animal[k] == 0: army++
                var blds = 0
                for(b_owner) o:
                    if o == p: blds++
                line += "   P{p} age {ages[p]}, {workers} workers, {army} soldiers, {healers} healers, {blds} buildings, {lost[p]} lost"
            print line
    res.winner = winner
    res.end_tick = tick
    res.hash = h
    if not quiet:
        print "winner: team {winner} at {clock(tick)}; age 2 at [{clock(aged[0])}, {clock(aged[1])}]"
        for(2) p: print "research P{p}: " + concat_string(bought[p], ", ")
        print "healers: most {res.most}, heals {res.heals}, behind their army in {res.behind} of {res.samples} looks"
        print "heroes: trained {res.heroes_up}, fell {res.fell}, revived {res.revived}"
    return res

def match_stats(r:MatchResult):
    stat("winner", r.winner)
    stat("tick", r.end_tick)
    stat("hashes", r.hashes)
    stat("hash", r.hash)
    stat("heals", r.heals[0] + r.heals[1])

def play_pair(races:[JV], title:string, quiet:bool) -> MatchResult:
    world(races, rules)
    return play(races, [full_side(0), full_side(1)], title, quiet)

def test_passive(a:JV, b:JV):
    world([a, b], rules)
    let r = play([a, b], [full_side(0), eco_side(1)], "bot {rname(a)} vs passive {rname(b)}", false)
    check(r.winner == 0, "the bot beats a passive {rname(b)} (winner {r.winner} at {clock(r.end_tick)})")

def test_bvb():
    let a = play_pair([frogs, rats], "bot vs bot", false)
    check(a.winner >= 0, "bot vs bot ends with a winner ({a.winner} at {clock(a.end_tick)})")
    // Healers (Dominic, 2026-10-12): a couple from age 2, kept behind the army, and they heal.
    let most = max(a.most[0], a.most[1])
    check(most >= 1 and most <= 3, "the bots train a couple of healers (most {a.most})")
    check(a.samples == 0 or a.behind * 100 >= a.samples * 70, "healers keep behind the army ({a.behind} of {a.samples} looks)")
    // Heroes (D-159): a bot with an economy fields its one hero, and only that one.
    check(max(a.kinds[0].length, a.kinds[1].length) == 1, "the bots field their hero, one kind each ({a.kinds[0].length}, {a.kinds[1].length} kinds; fell {a.fell}, revived {a.revived})")
    match_stats(a)

def test_races(pa:JV, pb:JV):
    let r = play_pair([pa, pb], "bot {rname(pa)} vs bot {rname(pb)}", false)
    check(r.winner >= 0, "{rname(pa)} vs {rname(pb)} ends with a winner")
    match_stats(r)

def test_hard():
    world([rats, frogs], rules)
    level_config("hard")
    let hard = full_side(0)
    hard.lv = level_now()
    level_config("normal")
    let normal = full_side(1)
    normal.lv = level_now()
    let r = play([rats, frogs], [hard, normal], "hard bot {rname(rats)} vs normal bot {rname(frogs)}", false)
    check(r.winner == 0, "hard beats normal (winner {r.winner} at {clock(r.end_tick)})")

// The checks across pieces: the same match twice is the same; the bots' healers heal someone over their
// matches; the match lengths (reported).
def combine():
    def g(k:string) -> int: return stats.get(k, -(1 << 40))
    if g("bvb hash") != -(1 << 40) and g("bvb_again hash") != -(1 << 40):
        check(g("bvb hash") == g("bvb_again hash") and g("bvb hashes") == g("bvb_again hashes") and g("bvb winner") == g("bvb_again winner"),
              "bot vs bot is deterministic")
    let ms = ["bvb", "centaurs_frogs", "rats_centaurs"]
    let missing = exists(ms) m: g(m + " tick") == -(1 << 40)
    if not missing:
        var heals = 0
        let lengths = []::int
        for(ms) m:
            heals += g(m + " heals")
            lengths.push(g(m + " tick"))
        check(heals > 0, "the bots\' healers heal someone in their matches ({heals} heals)")
        insertion_sort(lengths) x, y: x < y
        print "\nbot match lengths [" + concat_string(map(lengths) t: clock(t), ", ") + "], median {clock(lengths[1])} (target for players: 9-12 minutes)"

// ------------------------------------------------------------------ Easy, age 3, the levels

// Easy against a passive player: a small army, and the first loss no earlier than its first wave.
def test_easy(a:JV, b:JV):
    world([a, b], rules)
    level_config("easy")
    let sides = [full_side(0), eco_side(1)]
    var most = 0
    var first_loss = -1
    let hx, hy = start_of(0)
    let ex, ey = start_of(1)
    while tick < 20 * 60 * 14 and winner < 0:
        think_all(sides)
        wstep()
        var army = 0
        for(u_id.length) i:
            if u_owner[i] == 0 and not t_worker[u_kind[i]] and not t_healer[u_kind[i]]: army += t_pop[u_kind[i]]
        if tick <= 20 * 60 * 10: most = max(most, army)
        // A loss to the bot (one of its units close by) on the passive side's half of the map.
        for(events) e:
            if first_loss < 0 and e.kind == EV_DIE and e.b == 0 and owner_of_id(e.a) == 1 and dist2(e.x, e.y, ex, ey) < dist2(e.x, e.y, hx, hy):
                for(u_id.length) i:
                    if first_loss < 0 and u_owner[i] == 0 and abs(u_x[i] - e.x) + abs(u_y[i] - e.y) < 8000: first_loss = tick
    print "\n== easy: most soldiers in the first 10 minutes {most} (pop), first loss " + (if first_loss >= 0: clock(first_loss) else: "none")
    check(most <= 25, "easy keeps a modest army for the first ten minutes ({most} pop)")
    check(first_loss < 0 or first_loss >= 20 * 60 * 8, "easy doesn\'t strike before 8 minutes ({clock(first_loss)})")

// In age 3 the bot raises a University and a Castle and buys some of their research; it starts there with
// a full stock against a passive side, topped up each minute, for fifteen minutes.
def test_age_three(a:JV, b:JV):
    world([a, b], rules)
    ai_config("normal") c: no_waves(c)
    let sides = [full_side(0), eco_side(1)]
    ages[0] = 3
    let bought = []::string
    let wt = new_watch()
    while tick < 20 * 900:
        if tick % 1200 == 0: stock_at_least(0, 3000)
        think_all(sides)
        wstep()
        let hp = watch_after(wt)
        for(hp.research_p) p, n:
            if p == 0: bought.push(research[hp.research_k[n]].id)
    let done = []::string
    for(b_id.length) bi:
        if b_owner[bi] == 0 and b_done[bi] == 1 and not contains_str(done, bt_name[b_kind[bi]]): done.push(bt_name[b_kind[bi]])
    let theirs = filter(bought) id: contains_str(["stonecutting", "lifting_frames", "slit_windows", "thick_walls", "siege_wrights", "war_drums", "creature_research", "culture_research"], id)
    var workers = 0
    for(u_id.length) i:
        if u_owner[i] == 0 and t_worker[u_kind[i]]: workers++
    print "\n== age 3: {workers} workers, buildings {done}; University/Castle research {theirs}"
    check(contains_str(done, "university") and contains_str(done, "castle"), "age 3: the bot builds a University and a Castle")
    check(theirs.length >= 2, "age 3: ...and buys at least two of their research ({theirs})")

// Each level left to build up: waves off, against a passive side, 30 minutes. Targets: age 2 by 8 minutes
// (Normal, Hard), age 3 by 16 (Easy, Normal), by 20 minutes a University, a Castle, a tower and ten
// research (Easy, Normal); Normal's army still growing at 30.
def test_level(a:JV, b:JV, lvl:string):
    world([a, b], rules)
    ai_config(lvl) c: no_waves(c)
    let sides = [full_side(0), eco_side(1)]
    var a2 = -1
    var a3 = -1
    let bought = []::string
    let built_names = []::string
    let built_counts = []::int
    let army = map(31): 0
    let wt = new_watch()
    while tick < 20 * 60 * 30 and winner < 0:
        think_all(sides)
        wstep()
        let hp = watch_after(wt)
        for(hp.aged_p) p:
            if p == 0:
                if ages[0] == 2: a2 = tick
                if ages[0] == 3: a3 = tick
        for(hp.research_p) p, n:
            if p == 0 and tick <= 20 * 60 * 20: bought.push(research[hp.research_k[n]].id)
        if tick % 1200 == 0:
            var popn = 0
            var workers = 0
            for(u_id.length) i:
                let k = u_kind[i]
                if u_owner[i] == 0 and is_soldier(k): popn += t_pop[k]
                elif u_owner[i] == 0 and t_worker[k]: workers++
            army[tick / 1200] = popn
            if tick % 6000 == 0:
                let st = map(num_resources) r: stock[r][0]
                print "  {lvl} {clock(tick)}: age {ages[0]}, {workers} workers, {popn} soldier pop, stock {st}"
        if tick == 20 * 60 * 20:
            for(b_id.length) bi:
                if b_owner[bi] == 0 and b_done[bi] == 1:
                    let id = bt_name[b_kind[bi]]
                    let at_n = find_index(built_names, id)
                    if at_n < 0:
                        built_names.push(id)
                        built_counts.push(1)
                    else: built_counts[at_n]++
    def built(id:string) -> int:
        let n = find_index(built_names, id)
        return if n >= 0: built_counts[n] else: 0
    let towers = built("watchtower") + built("bastion")
    print "\n== {lvl}, left alone: age 2 at {clock(a2)}, age 3 at {clock(a3)}; by 20:00 built " + concat_string(map(built_names) id, n: "{id} {built_counts[n]}", ", ") +
          "; research by 20:00 ({bought.length}) {bought}; army pop at 10/20/30 min {army[10]}/{army[20]}/{army[30]}"
    if lvl != "easy":
        check(a2 >= 0 and a2 <= 20 * 60 * 8, "{lvl}: age 2 by 8:00 ({clock(a2)})")
    if lvl != "hard":
        check(a3 >= 0 and a3 <= 20 * 60 * 16, "{lvl}: age 3 by 16:00 ({clock(a3)})")
        check(built("university") > 0 and built("castle") > 0, "{lvl}: a University and a Castle by 20:00")
        check(towers >= 1, "{lvl}: a tower by 20:00")
        check(bought.length >= 10, "{lvl}: ten or more research by 20:00 ({bought.length})")
    if lvl == "normal":
        check(army[30] > army[20], "normal: its army keeps growing ({army[20]} at 20:00, {army[30]} at 30:00)")

// ------------------------------------------------------------------ the counter-pick, the Wonder

// The pick among slots (as Bot.pick): the slot, or "".
def pick_slot(bot:Bot, slots:[string], tags:[int], bonus:[int]) -> string:
    let trains = filter(map(slots) s: type_of_slot(bot.player, s)) k: k >= 0
    let k = pick(bot, trains, tags, bonus, []::int)
    return if k >= 0: t_slot[k] else: ""

// The foes' tags, as enemy_tags counts them, for 4 of one line of player 1's.
def seen_tags(slot:string) -> [int], [int]:
    let k1 = type_of_slot(1, slot)
    let tags = map(num_classes): 0
    let bonus = map(num_classes): 0
    if k1 >= 0:
        for(t_tags[k1]) c: tags[c] = 4
        for(t_bonus[k1]) v, c: bonus[c] = 4 * v
    return tags, bonus

// The Barracks' counter-pick: spears with nothing seen, and against cavalry; swords against spears and
// skirmishers. The Range's: mounted archers against swordsmen only. The Castle's great sling first.
def test_pick():
    for(["greeks", "swamp frogs", "sewer rats", "egyptians"]) prompt:
        let race = generate(prompt, rules, 0)
        world([race, race], rules)
        for([1, 2]) age:
            ages[0] = age
            let bot = new_bot(0)
            let barracks = ["spear", "infantry"]
            let none = map(num_classes): 0
            let lt, lb = seen_tags("large")
            let st, sb = seen_tags("spear")
            let kt, kb = seen_tags("skirmisher")
            let it, ib = seen_tags("infantry")
            check(pick_slot(bot, barracks, none, none) == "spear", "pick {prompt} age {age}: spears with nothing seen")
            check(pick_slot(bot, barracks, lt, lb) == "spear", "pick {prompt} age {age}: spears against cavalry")
            check(pick_slot(bot, barracks, st, sb) == "infantry", "pick {prompt} age {age}: swords against spears")
            check(pick_slot(bot, barracks, kt, kb) == "infantry", "pick {prompt} age {age}: swords against skirmishers")
            if age == 2:
                let range_lines = ["skirmisher", "archer", "mounted_archer"]
                check(pick_slot(bot, range_lines, none, none) != "mounted_archer", "pick {prompt}: archers, not mounted archers, with nothing seen")
                check(pick_slot(bot, range_lines, it, ib) == "mounted_archer", "pick {prompt}: mounted archers against swordsmen")
                check(pick_slot(bot, range_lines, st, sb) != "mounted_archer", "pick {prompt}: no mounted archers against spears")
                check(pick_slot(bot, ["large", "scout"], none, none) == "large", "pick {prompt}: the Stable\'s cavalry with nothing seen")
                ages[0] = 3
                let castle = ["unique", "great_sling"]
                let first = pick_slot(bot, castle, none, none)
                check(first == "great_sling", "pick {prompt}: the Castle\'s great sling first ({first})")
                check(pick_slot(bot, ["trader"], none, none) == "", "pick {prompt}: trade carts aren\'t picked as soldiers")
                ages[0] = 2
            if cfg("military.building_foes") > 0:
                bot.aim = 1
                let et, eb = enemy_tags(bot)
                check(pick_slot(bot, barracks, et, eb) == "infantry", "pick {prompt} age {age}: swords for a wall in the way")

// An enemy Wonder, finished, is the first thing its soldiers go for; a bot rich in age 3 builds its own.
def test_wonder(a:JV, b:JV):
    world([a, b], rules)
    let bot = full_side(0)
    let k = btype_index("wonder")
    var tc1 = -1
    for(b_id.length) bi:
        if b_owner[bi] == 1: tc1 = b_id[bi]
    let s1x, s1y = start_of(1)
    var spx = -1
    var spy = -1
    var r = 5
    while r < 13:
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                if spx < 0 and max(abs(dx), abs(dy)) == r and can_place(1, k, s1x / 1000 + dx, s1y / 1000 + dy):
                    spx = s1x / 1000 + dx
                    spy = s1y / 1000 + dy
                dx++
            dy++
        r++
    check(spx >= 0, "wonder bot: room for their Wonder")
    if spx < 0: return
    let wb = place(1, k, spx, spy)
    b_done[wb] = 1
    b_hp[wb] = bm_hp[1][k]
    let wid = b_id[wb]
    let s0x, s0y = start_of(0)
    spawn(0, "large", 6, s0x, s0y + 3500)
    var first = 0
    var tc_hit = 0
    while tick < 20 * 240 and first == 0:
        think(bot)
        wstep()
        for(events) e:
            if e.kind == EV_HIT and e.b == wid and first == 0: first = tick
            elif e.kind == EV_HIT and e.b == tc1 and tc_hit == 0: tc_hit = tick
    check(first > 0 and first < 20 * 200, "wonder bot: its soldiers go for a finished enemy Wonder at once (first blow at {clock(first)}, waves start at {wave_at[0]} s)")
    check(tc_hit == 0, "wonder bot: the Wonder before the Town Center (Town Center hit at " + (if tc_hit > 0: clock(tc_hit) else: "never") + ")")
    // Rich in age 3: it builds its own.
    world([a, b], rules)
    let bot2 = full_side(0)
    while tick < 20 * 60:
        think(bot2)
        wstep()
    ages[0] = 3
    for(num_resources) res: stock[res][0] = 3000
    var laid = 0
    while tick < 20 * 120 and laid == 0:
        think(bot2)
        wstep()
        for(b_id.length) bi:
            if b_owner[bi] == 0 and b_kind[bi] == k: laid = tick
    check(laid > 0, "wonder bot: rich in age 3, it lays a Wonder (at {clock(laid)})")

// ------------------------------------------------------------------ raids, shelter, walled-off fords

def builder_lane(p:int) -> int: return lane_base[p] + t_mclass[worker_type(p)]

// Raids anywhere get an answer (Dominic, 2026-10-13). The bot's lone lumber camp far from home, a worker
// beside it, and a few enemy soldiers hacking at both: within seconds the bot sends soldiers there, pulls
// the worker away, and its soldiers come to blows with the raiders.
def test_respond(a:JV, b:JV):
    world([a, b], rules)
    let side = full_side(1)
    while tick < 1200:
        think(side)
        wstep()
    let tc = town_center(1)
    let tx = b_cx[tc] + 1
    let ty = b_cy[tc] + 1
    let k = btype_index("lumber_camp")
    var spx = -1
    var spy = -1
    let rc = Reach {}
    let ln = builder_lane(1)
    let home = area_at(rc, ln, tx * 1000 + 500, ty * 1000 + 500)
    var r = 16
    while r < 23:
        var dy = -r
        while dy <= r:
            var dx = -r
            while dx <= r:
                if spx < 0 and max(abs(dx), abs(dy)) == r and can_place(1, k, tx + dx, ty + dy) and touches_area(rc, ln, home, tx + dx, ty + dy, 2, 2):
                    spx = tx + dx
                    spy = ty + dy
                dx++
            dy++
        r++
    check(spx >= 0, "respond: room for a lone camp")
    if spx < 0: return
    let camp = place(1, k, spx, spy)
    b_done[camp] = 1
    b_hp[camp] = bm_hp[1][k]
    let camp_id = b_id[camp]
    let cx = spx * 1000 + 1000
    let cy = spy * 1000 + 1000
    spawn(1, "spear", 4, tx * 1000 + 500, ty * 1000 + 3500)   // a home guard
    spawn(1, "worker", 1, cx + 2000, cy)
    spawn(0, "spear", 3, cx - 2500, cy)
    for(12):
        think(side)
        wstep()
    let raiders = []::int
    var worker = -1
    for(u_id.length) i:
        if u_owner[i] == 0 and not t_worker[u_kind[i]] and abs(u_x[i] - cx) < 5000 and abs(u_y[i] - cy) < 5000: raiders.push(u_id[i])
        if u_owner[i] == 1 and t_worker[u_kind[i]] and abs(u_x[i] - cx - 2000) < 1500 and abs(u_y[i] - cy) < 1500: worker = u_id[i]
    check(raiders.length == 3 and worker > 0, "respond: three raiders by the camp, a worker beside it")
    issue_cmd(0, CMD_ATTACK, raiders.slice(0, 2), camp_id, 0, 0, 0)
    issue_cmd(0, CMD_ATTACK, raiders.slice(2, -1), worker, 0, 0, 0)
    var first_hit = -1
    var sent = -1
    var pulled = -1
    var blows = 0
    while tick < 1200 + 20 * 60:
        let seq0 = next_seq[1]
        think(side)
        for(issued_since(1, seq0)) c:
            if sent < 0 and c.code == CMD_ATTACK_MOVE and abs(c.a - cx) < 6000 and abs(c.b - cy) < 6000: sent = c.run_tick
            if pulled < 0 and c.code == CMD_MOVE and contains(c.ids, worker): pulled = c.run_tick
        wstep()
        for(events) e:
            if e.kind == EV_HIT:
                if first_hit < 0 and contains(raiders, e.a): first_hit = tick
                if contains(raiders, e.b):
                    let bi = index_of(e.a)
                    if bi >= 0 and u_owner[bi] == 1: blows++
        if blows > 0 and sent >= 0 and pulled >= 0 and tick >= max(sent, pulled): break
    print "\n== respond: first blow {clock(first_hit)}, soldiers sent " + (if sent >= 0: clock(sent) else: "never") + ", worker pulled back " +
          (if pulled >= 0: clock(pulled) else: "never") + ", blows on the raiders {blows}"
    check(first_hit >= 0 and sent >= 0 and sent - first_hit <= 100, "respond: soldiers are sent to a raided camp within 5 s ({sent - first_hit} ticks)")
    check(pulled >= 0 and pulled - first_hit <= 100, "respond: the worker by it is pulled back within 5 s")
    check(blows > 0, "respond: the bot\'s soldiers fight the raiders")

// A big raid by the Town Center: the bot calls its workers to arms within seconds, and sends them back to
// work afterwards.
def test_shelter(a:JV, b:JV):
    world([a, b], rules)
    let side = full_side(1)
    while tick < 1200:
        think(side)
        wstep()
    let tc = town_center(1)
    let tx = b_cx[tc] * 1000 + 1500
    let ty = b_cy[tc] * 1000 + 1500
    spawn(0, "spear", 6, tx + 4500, ty)
    for(12):
        think(side)
        wstep()
    let raiders = []::int
    for(u_id.length) i:
        if u_owner[i] == 0 and not t_worker[u_kind[i]] and abs(u_x[i] - tx) < 8000 and abs(u_y[i] - ty) < 8000: raiders.push(u_id[i])
    issue_cmd(0, CMD_ATTACK_MOVE, raiders, tx, ty + 2500, 0, 0)
    let t_start = tick
    var called = -1
    var back = -1
    var inside = 0
    while tick < t_start + 20 * 90 and back < 0:
        let seq0 = next_seq[1]
        think(side)
        for(issued_since(1, seq0)) c:
            if c.code == CMD_CALL_TO_ARMS and called < 0: called = c.run_tick
            elif c.code == CMD_BACK_TO_WORK and called >= 0: back = c.run_tick
        wstep()
        inside = max(inside, sheltered(1))
    print "\n== shelter: {raiders.length} raiders; call to arms " + (if called >= 0: clock(called) else: "never") + ", most inside {inside}, back to work " +
          (if back >= 0: clock(back) else: "never")
    check(called >= 0 and called - t_start <= 20 * 10, "shelter: a raid on the Town Center calls the workers to arms within 10 s")
    check(inside >= 3, "shelter: ...and they go inside ({inside})")
    check(back >= 0, "shelter: ...and back to work afterwards")

// Walled-off fords (Dominic, 2026-10-13). On a river map, the passive side's walls on every ford and the
// bridge down: the bot's half is cut off. Its workers keep working, it builds and ages on its own side,
// and its army goes for the walls rather than standing about.
def test_walled_fords(a:JV, b:JV):
    world([a, b], rules)
    let ford = terrain_named("ford")
    let has_ford = exists(terrain) t: t == ford
    if ford < 0 or not has_ford:
        print "\n== walled fords: {map_id} has no fords, skipped"
        return
    let wk = btype_index("wall")
    var walls = 0
    for(W * H) c:
        if terrain[c] == ford and occupied[c] == 0:
            let bi = place(0, wk, c % W, c / W)
            b_done[bi] = 1
            b_hp[bi] = bm_hp[0][wk]
            walls++
    for(br_id.length) k: bridge_hurt(k, 1 << 20)
    let sides = [eco_side(0), full_side(1)]
    let reach = Reach {}
    let ln = builder_lane(1)
    let s0x, s0y = start_of(0)
    let s1x, s1y = start_of(1)
    let cut = area_at(reach, ln, s0x, s0y) != area_at(reach, ln, s1x, s1y)
    check(cut, "walled fords: {walls} walls and the bridge down cut the bot ({rname(b)}, movement class {t_mclass[worker_type(1)]}) off")
    // A barracks foundation the bot laid over the river before the walls went up: cut off now.
    let bk = btype_index("barracks")
    var far = -1
    var r = 6
    while r < 14:
        for([int2 { r, 0 }, int2 { 0, r }, int2 { r, r }]) d:
            if far < 0 and can_place(1, bk, s0x / 1000 + d.x, s0y / 1000 + d.y): far = place(1, bk, s0x / 1000 + d.x, s0y / 1000 + d.y)
        r++
    let far_id = if far >= 0: b_id[far] else: -1
    var stranded = 0
    let idle_for = dictionary<int, int>(64)
    var worst = 0
    var idle_looks = 0
    var looks = 0
    var cut_off = 0
    var wall_hits = 0
    var mended = -1
    while tick < 20 * 60 * 12 and winner < 0:
        think_all(sides)
        wstep()
        for(events) e:
            if e.kind == EV_HIT:
                let tb = b_index_of(e.b)
                if tb >= 0 and b_kind[tb] == wk and b_owner[tb] == 0: wall_hits++
        if mended < 0 and contains(br_up, 1): mended = tick
        if tick % 100 == 0 and tick >= 1200:
            let home = area_at(reach, ln, s1x, s1y)
            for(u_id.length) i:
                if u_owner[i] == 1 and t_worker[u_kind[i]]:
                    let id = u_id[i]
                    looks++
                    let idle = u_task[i] == 0 and u_moving[i] == 0 and u_foe[i] == 0
                    if u_task[i] == BUILD and u_target[i] == far_id and mended < 0: stranded++
                    idle_for.set(id, if idle: idle_for.get(id, 0) + 1 else: 0)
                    worst = max(worst, idle_for.get(id, 0))
                    if idle: idle_looks++
            for(b_id.length) bi:
                if b_id[bi] != far_id and b_owner[bi] == 1 and b_done[bi] == 0 and not touches_area(reach, ln, home, b_cx[bi], b_cy[bi], b_sx[bi], b_sy[bi]):
                    cut_off++
    var workers = 0
    var blds = 0
    var barracks = 0
    for(u_id.length) i:
        if u_owner[i] == 1 and t_worker[u_kind[i]]: workers++
    for(b_id.length) bi:
        if b_owner[bi] == 1:
            blds++
            if b_kind[bi] == bk and b_done[bi] == 1: barracks++
    print "\n== walled fords ({map_id}): at {clock(tick)} the bot has {workers} workers, {blds} buildings, age {ages[1]}; idle {idle_looks} of {looks} worker looks, longest idle {worst * 5} s; workers sent to the cut-off foundation {stranded} looks; barracks built {barracks}; new foundations it can\'t reach {cut_off}; blows on the walls {wall_hits}; a bridge mended " +
          (if mended >= 0: clock(mended) else: "never")
    check(cut_off == 0, "walled fords: the bot lays no foundation it can\'t reach")
    check(stranded == 0, "walled fords: nobody is sent to the foundation over the river ({stranded} looks)")
    check(barracks >= 1, "walled fords: it builds a barracks on its own side instead")
    check(idle_looks * 100 <= looks * 5, "walled fords: its workers keep working (idle {idle_looks} of {looks} looks)")
    check(worst <= 4, "walled fords: no worker stands idle for long (longest {worst * 5} s)")
    check(ages[1] >= 2 and (workers >= 20 or winner == teams[1]), "walled fords: the bot grows on its own side (age {ages[1]}, {workers} workers; or wins first)")
    check(wall_hits > 0 or mended >= 0, "walled fords: its army goes for the walls (or over a bridge it mended)")
    if map_id == "reed_meadow" and t_mclass[worker_type(1)] == 0:
        check(mended >= 0, "walled fords: it mends a broken bridge, its only way over")

// ------------------------------------------------------------------ the land, guarding, hills

// An early scout tours and sees round the enemy's start; then a Normal bot match to the end, reporting
// what each bot did with the land. Checks what the map calls for.
def test_land(a:JV, b:JV):
    world([b, a], rules)
    let sides = [full_side(0), eco_side(1)]
    while tick < 20 * 60 * 4:
        think_all(sides)
        wstep()
    let s1x, s1y = start_of(1)
    var seen = 0
    var cells = 0
    var dy = -8
    while dy <= 8:
        var dx = -8
        while dx <= 8:
            let x = s1x / 1000 + dx
            let y = s1y / 1000 + dy
            if x >= 0 and y >= 0 and x < W and y < H:
                cells++
                if fog[0][y * W + x] != 0: seen++
            dx++
        dy++
    let tours = (assert sides[0].full).scout.tours
    print "\n== land ({map_id}): scout tours {tours} by 4:00, ground round the enemy start seen {seen} of {cells} cells"
    check(tours >= 1, "land: a scout tours early")
    check(seen * 100 >= cells * 25, "land: ...and sees round the enemy\'s start ({seen} of {cells} cells)")
    // A whole Normal match: what the bots did with the land.
    world([a, b], rules)
    let pair = [full_side(0), full_side(1)]
    let camps_laid = [0, 0]
    let camp_kinds = []::int
    for(["food", "gold", "stone", "wood"]) res:
        let cl = cfg_list("expand.camps.{res}")
        if cl.length: camp_kinds.push(btype_index(cl[0]))
    while tick < LIMIT and winner < 0:
        for(pair) s:
            let p = s.player
            let seq0 = next_seq[p]
            think(s)
            let f = s.full
            if f and f.expand.next_camp == tick + cfg("expand.camp_every") * 20:
                var last_camp = false
                for(issued_since(p, seq0)) c:
                    if c.code == CMD_BUILD and contains(camp_kinds, c.a): last_camp = true
                if last_camp: camps_laid[p]++
        wstep()
    var camps_n = 0
    var roads = 0
    for(pair) s:
        let f = s.full
        if f:
            print "   P{s.player} {rname([a, b][s.player])}: tours {f.scout.tours}, roads {f.land.roads}, key {f.land.key}, camps {camps_laid[s.player]}, posts {f.expand.escort_ids.length} now"
            camps_n += camps_laid[s.player]
            roads += f.land.roads
    print "   match: winner {winner} at {clock(tick)}"
    check(camps_n >= 1, "land: camps go up by far gatherers ({camps_n})")
    if map_id == "old_forest":
        check(roads >= 1, "land: a road is felled through the thin woods ({roads})")
    check(winner >= 0, "land: the match ends ({clock(tick)})")

// A level that guards (Normal), on the back foot, left to build up against a passive side (its stock
// topped up from 6:00), puts a Watchtower on the key crossing by 16 minutes.
def test_guard(a:JV, b:JV):
    world([a, b], rules)
    ai_config("normal") c: no_waves(c)
    let sides = [full_side(0), eco_side(1)]
    let bot = assert sides[0].full
    bot.on_back_foot = true
    while tick < 20 * 60 * 16:
        if tick % 1200 == 0 and tick >= 20 * 60 * 6: stock_at_least(0, 1000)
        think_all(sides)
        wstep()
    let side_cell = bot.land.key_side
    let s0x, s0y = start_of(0)
    if bot.land.key < 0 or max(abs(side_cell % W - s0x / 1000), abs(side_cell / W - s0y / 1000)) > cfg("land.guard_range"):
        print "\n== guard: no key crossing near home on the enemy\'s way here ({map_id}), skipped"
        return
    var near = 99
    for(b_id.length) bi:
        let id = bt_name[b_kind[bi]]
        if b_owner[bi] == 0 and (id == "watchtower" or id == "bastion"):
            near = min(near, max(abs(b_cx[bi] - side_cell % W), abs(b_cy[bi] - side_cell / W)))
    print "\n== guard ({map_id}): key crossing {bot.land.key}, our side at ({side_cell % W}, {side_cell / W}); nearest tower of ours {near} tiles from it"
    check(near <= cfg("land.guard_tiles"), "guard: a Watchtower stands on the key crossing ({near} tiles)")

// High ground: four of our archers a few steps from a ramp up a hill, enemy soldiers coming at them: the
// bot sends the archers up.
def test_hills(a:JV, b:JV):
    world([a, b], rules)
    if has_heights == 0: return
    let side = full_side(0)
    let walk0 = walks[0]
    var foot = -1
    var far = -1
    for(W * H) c:
        if foot < 0 and ramp[c] != 0 and level[c] == 0:
            let steps = dictionary<int, int>(64)
            steps.set(c, 0)
            let queue = [c]
            var head = 0
            var f = -1
            var e = -1
            while head < queue.length:
                let here = queue[head]
                head++
                if steps.get(here, 0) == 3 and f < 0: f = here
                if steps.get(here, 0) == 8 and e < 0: e = here
                for([1, -1, W, -W]) d:
                    let n = here + d
                    if n >= 0 and n < walk0.length and walk0[n] == 1 and level[n] == 0 and ramp[n] == 0 and steps.get(n, -1) < 0 and abs(n % W - here % W) <= 1:
                        steps.set(n, steps.get(here, 0) + 1)
                        queue.push(n)
            if f >= 0 and e >= 0:
                foot = f
                far = e
    if foot < 0:
        print "\n== hills: no ramp with open ground before it on {map_id}, skipped"
        return
    let fx = foot % W * 1000 + 500
    let fy = foot / W * 1000 + 500
    spawn(0, "archer", 4, fx, fy)
    spawn(1, "spear", 4, far % W * 1000 + 500, far / W * 1000 + 500)
    for(12):
        think(side)
        wstep()
    let ours = []::int
    let theirs = []::int
    for(u_id.length) i:
        if u_owner[i] == 0 and t_slot[u_kind[i]] == "archer": ours.push(u_id[i])
        elif u_owner[i] == 1 and t_slot[u_kind[i]] == "spear": theirs.push(u_id[i])
    issue_cmd(1, CMD_STANCE, theirs, STAND, 0, 0, 0)   // (they wait, then come on)
    let below = (filter(ours) id: level[cell_of(u_x[index_of(id)], u_y[index_of(id)])] == 0).length
    var up = 0
    while tick < 20 * 25:
        if tick == 20 * 6: issue_cmd(1, CMD_ATTACK_MOVE, theirs, fx, fy, 0, 0)
        think(side)
        wstep()
        up = 0
        for(ours) id:
            let i = index_of(id)
            if i >= 0 and level[cell_of(u_x[i], u_y[i])] >= 1: up++
        if up >= 2: break
    print "\n== hills ({map_id}): archers at ({foot % W}, {foot / W}) by a hill; {up} of 4 up on it at {clock(tick)}"
    check(below == 4 and up >= 2, "hills: archers meeting an army climb the hill beside them ({below} of 4 below, {up} up)")

// ------------------------------------------------------------------ walls and engines

// A walled-in base (Dominic, 2026-10-13). On flat_test the passive side's Town Center is ringed by a wall
// line of `wall` with two of its gates in it, put up finished at the start. The bot must break a way in
// and win, its soldiers at the wall busy. With `gap`, a three-tile gap faces the bot instead of the south
// gate: the bot walks in through it and barely touches the wall.
def test_walled_base(a:JV, b:JV, wall:string, gap:bool):
    let title = "walled base ({wall}" + (if gap: ", gap" else: "") + ")"
    if map_id != "flat_test":
        print "\n== {title}: laid out for flat_test, skipped on {map_id}"
        return
    world([a, b], rules)
    let lox = 5
    let loy = 3
    let hix = 24
    let hiy = 21
    let wk = btype_index(wall)
    let gk = btype_index(if wall == "palisade": "palisade_gate" else: "stone_gate")
    var y = loy
    while y <= hiy:
        var x = lox
        while x <= hix:
            let edge = x == lox or x == hix or y == loy or y == hiy
            if edge and occupied[y * W + x] == 0 and can_build(x, y, 1, 0, false, false) and not (gap and y == hiy and x >= 12 and x <= 14):
                let bi = place(0, wk, x, y)
                b_done[bi] = 1
                b_hp[bi] = bm_hp[0][wk]
            x++
        y++
    let gates = if gap: [int3 { hix, 11, 1 }] else: [int3 { hix, 11, 1 }, int3 { 12, hiy, 0 }]   // east (along y), south (along x)
    for(gates) g:
        let sx, sy = dims(gk, g.z)
        for(cells_of(g.x, g.y, sx, sy, 0)) c:
            if occupied[c] != 0: demolish(b_index_of(occupied[c]))
        let bi = place(0, gk, g.x, g.y, g.z)
        b_done[bi] = 1
        b_hp[bi] = bm_hp[0][gk]
    ai_config("normal") c: erase(at(c, "military"), "hero")   // no heroes (D-138): with them the battle\'s timing shifts
    let sides = [eco_side(0), full_side(1)]
    let bot = assert sides[1].full
    let reach = Reach {}
    let ln = lane_base[1]
    let s0x, s0y = start_of(0)
    let s1x, s1y = start_of(1)
    def in_ring(ux:int, uy:int) -> bool: return ux > lox * 1000 + 999 and ux < hix * 1000 and uy > loy * 1000 + 999 and uy < hiy * 1000
    check(gap == (area_at(reach, ln, s0x, s0y) == area_at(reach, ln, s1x, s1y)), "{title}: the ring " + (if gap: "has its gap" else: "shuts the bot out"))
    let struck = dictionary<int, int>(64)
    let struck_ids = []::int
    var dealt = 0
    var ring_hits = 0
    var hits_before_in = -1
    var first_hit = -1
    var breach_at = -1
    var first_in = -1
    var looks = 0
    var idle = 0
    let stuck = dictionary<int, int>(64)
    var worst = 0
    while tick < 20 * 60 * 30 and winner < 0:
        think_all(sides)
        wstep()
        for(events) e:
            if e.kind == EV_HIT:
                let tb = b_index_of(e.b)
                if tb >= 0 and b_owner[tb] == 0 and (b_kind[tb] == wk or b_kind[tb] == gk):
                    ring_hits++
                    if struck.get(e.b, 0) == 0: struck_ids.push(e.b)
                    struck.set(e.b, struck.get(e.b, 0) + 1)
                    dealt += e.c
                    if first_hit < 0: first_hit = tick
        if tick % 100 == 0:
            if breach_at < 0 and not gap and area_at(reach, ln, s0x, s0y) == area_at(reach, ln, s1x, s1y): breach_at = tick
            for(u_id.length) i:
                let k = u_kind[i]
                if u_owner[i] == 1 and not t_worker[k] and not t_healer[k]:
                    let ux = u_x[i]
                    let uy = u_y[i]
                    if first_in < 0 and in_ring(ux, uy):
                        first_in = tick
                        hits_before_in = ring_hits
                    // Out by the ring (within 6 tiles of its outside), the Town Center not yet in reach.
                    let near = ux > (lox - 6) * 1000 and ux < (hix + 7) * 1000 and uy > (loy - 6) * 1000 and uy < (hiy + 7) * 1000 and not in_ring(ux, uy)
                    if near and bot.assault and not (breach_at >= 0 and not gap):
                        let id = u_id[i]
                        looks++
                        let still = u_foe[i] == 0 and u_moving[i] == 0
                        if still: idle++
                        stuck.set(id, if still: stuck.get(id, 0) + 1 else: 0)
                        worst = max(worst, stuck.get(id, 0))
    let hp_left = []::int
    for(b_id.length) bi:
        if b_owner[bi] == 0 and b_kind[bi] == gk: hp_left.push(b_hp[bi])
    let spread_l = map(struck_ids) id: struck.get(id, 0)
    insertion_sort(spread_l) x, z: x > z
    let top12 = spread_l.slice(0, min(12, spread_l.length))
    print "  blows per ring piece hit (most first) {top12}, damage dealt {dealt}"
    print "\n== {title}: winner {winner} at {clock(tick)}; first blow on the ring " + (if first_hit >= 0: clock(first_hit) else: "never") + ", {ring_hits} blows in all" +
          (if gap: "" else: ", the Town Center in reach from " + (if breach_at >= 0: clock(breach_at) else: "never")) +
          "; first bot soldier inside " + (if first_in >= 0: clock(first_in) else: "never") + " ({hits_before_in} blows on the ring by then); gates\' hp left {hp_left}; soldiers out by the ring idle {idle} of {looks} looks, longest {worst * 5} s"
    check(winner == 1, "{title}: the bot wins (winner {winner} at {clock(tick)})")
    check(first_in >= 0, "{title}: the bot\'s soldiers get inside the ring")
    check(looks == 0 or idle * 100 <= looks * 20, "{title}: soldiers out by the ring keep at it (idle {idle} of {looks} looks)")
    check(worst <= 6, "{title}: none of them stands about long (longest {worst * 5} s)")
    if gap:
        check(hits_before_in >= 0 and hits_before_in <= 20, "{title}: it walks in through the gap rather than smash the wall ({hits_before_in} blows first)")
    else:
        check(breach_at >= 0, "{title}: it breaks a way through the ring")
        check(spread_l.length > 0 and spread_l[0] * 2 >= ring_hits, "{title}: the blows go on one piece, not nicks on a dozen ({spread_l.slice(0, min(3, spread_l.length))} of {ring_hits})")

// Rams break walls: three rams against a stone gate and a stone wall piece, then the same cost in spears
// and cavalry: the rams break through several times faster; great slings break them from afar.
def test_rams(race:JV):
    let times = dictionary<string, int>(16)
    var spent = 0
    let r = deep_copy(rules)
    let st = at(at(r, "economy"), "start")
    set(st, "buildings", jarr([]))
    set(st, "workers", jint(0))
    set(r, "animals", jbool(false))
    for(["ram", "spear", "large", "great_sling"]) slot:
        for(["stone_gate", "wall"]) target:
            world([race, race], r)
            let k = type_of_slot(0, slot)
            assert k >= 0
            var cost = 0
            for(t_cost[k]) c: cost += c
            if slot == "ram": spent = cost * 3
            let n = if slot == "ram": 3 else: max(1, (spent + cost / 2) / cost)
            let bk = btype_index(target)
            let bi = place(1, bk, 20, 20, 0)
            b_done[bi] = 1
            b_hp[bi] = bm_hp[1][bk]
            let bid = b_id[bi]
            spawn(0, slot, n, 15000, 20500)
            while u_id.length < n: wstep()
            issue_cmd(0, CMD_ATTACK, copy(u_id), bid, 0, 0, 0)
            while b_index_of(bid) >= 0 and tick < 20 * 600: wstep()
            times.set(slot + ":" + target, tick)
            print "  {n} {unit_name(k)} ({cost} resources each) break a {target} in {clock(tick)}"
    for(["stone_gate", "wall"]) target:
        let ram = times.get("ram:" + target, 0)
        for(["spear", "large"]) slot:
            let t = times.get(slot + ":" + target, 0)
            check(ram * 3 <= t, "rams break a {target} at least 3 times faster than the same cost in {slot} ({clock(ram)} vs {clock(t)})")
        let gs = times.get("great_sling:" + target, 0)
        check(gs < 20 * 600, "great slings break a {target} from afar ({clock(gs)})")

// Siege: a bot already in age 3 with resources to spare, against a passive side: once it has a Siege
// Workshop it keeps a few engines, and its engines strike buildings.
def test_siege_bot(a:JV, b:JV):
    world([a, b], rules)
    ai_config("normal") c:
        for(glist(at(c, "military"), "waves")) wv: set(wv, "at", jint(as_int(at(wv, "at")) + 600))   // ten minutes to build up first
        set(c, "wonder", jobj())               // no Wonder
        erase(at(c, "military"), "hero")       // no heroes (D-138)
    let sides = [full_side(0), eco_side(1)]
    ages[0] = 3
    let slots = cfg_list("military.siege.max_order")
    let engine_kind = map(slots) s: type_of_slot(0, s)
    def slot_of_kind(k:int) -> int: return int_index(engine_kind, k)
    let peak = map(slots): -1
    let blows = map(slots): 0
    var rams_out = 0
    while tick < 20 * 1500 and winner < 0:
        if tick % 1200 == 0: stock_at_least(0, 2000)
        think_all(sides)
        wstep()
        for(events) e:
            if e.kind == EV_HIT and b_index_of(e.b) >= 0:
                let i = index_of(e.a)
                if i >= 0 and slot_of_kind(u_kind[i]) >= 0: blows[slot_of_kind(u_kind[i])]++
        if tick % 100 == 0:
            let n = map(slots): 0
            for(u_kind) k:
                if k >= 0 and slot_of_kind(k) >= 0: n[slot_of_kind(k)]++
            for(n) v, s:
                if v > 0:
                    if peak[s] < 0: print "  first {slots[s]} at {clock(tick)}"
                    peak[s] = max(peak[s], v)
    let s0x, s0y = start_of(0)
    for(u_id.length) i:
        let s = slot_of_kind(u_kind[i])
        if s >= 0:
            print "  {slots[s]} at {u_x[i] / 1000},{u_y[i] / 1000} foe {u_foe[i]} stance {u_stance[i]} moving {u_moving[i]}"
            if slots[s] == "ram" and dist2(u_x[i], u_y[i], s0x, s0y) > 15000 * 15000: rams_out++
    var shop = false
    for(b_id.length) bi:
        if b_owner[bi] == 0 and bt_name[b_kind[bi]] == "siege_workshop": shop = true
    let fielded_slots = filter(slots.length) s: peak[s] >= 0
    let peaks = concat_string(map(fielded_slots) s: "{slots[s]} {peak[s]}", ", ")
    let blows_s = concat_string(map(filter(slots.length) s: blows[s] > 0) s: "{slots[s]} {blows[s]}", ", ")
    print "\n== siege bot: winner {winner} at {clock(tick)}; workshop {shop}; most engines at once \{{peaks}\}; blows on buildings by engines \{{blows_s}\}"
    check(fielded_slots.length >= 2, "siege: the bot fields engines once it has a workshop (\{{peaks}\})")
    let caps = concat_string(map(slots) s: s + " " + string(cfg("military.siege.max." + s)), ", ")
    let over_cap = exists(fielded_slots) s: peak[s] > cfg("military.siege.max." + slots[s])
    check(not over_cap, "siege: ...a few, never more than its caps (\{{peaks}\} of \{{caps}\})")
    let ram_slot = find_index(slots, "ram")
    check((ram_slot >= 0 and blows[ram_slot] > 0) or rams_out > 0, "siege: its rams go out to the enemy or strike buildings ({rams_out} out, blows \{{blows_s}\})")

// Trade: a bot in age 2 with two markets of its own far enough apart trains a few trade carts and keeps
// them on the route, and they bring gold home; they never join its army.
def test_trade_bot(a:JV, b:JV):
    world([a, b], rules)
    ai_config("normal") c: no_waves(c)
    let sides = [full_side(0), eco_side(1)]
    ages[0] = 2
    let mk = btype_index("market")
    let sx = start_x[0] / 1000
    let sy = start_y[0] / 1000
    let placed = []::int   // market ids
    for([int2 { sx + 4, sy - 2 }, int2 { sx + 4, sy + 24 }, int2 { sx + 24, sy }]) want:
        if placed.length < 2:
            var r = 0
            var done = false
            while r < 8 and not done:
                var ax = -1
                var ay = -1
                var dy = -r
                while dy <= r:
                    var dx = -r
                    while dx <= r:
                        if ax < 0 and can_place(0, mk, want.x + dx, want.y + dy):
                            ax = want.x + dx
                            ay = want.y + dy
                        dx++
                    dy++
                if ax >= 0:
                    let mb = place(0, mk, ax, ay)
                    b_done[mb] = 1
                    b_hp[mb] = bt_hp_base[mk]
                    placed.push(b_id[mb])
                    done = true
                r++
    let k = type_of_slot(0, "trader")
    var paid = 0
    var most = 0
    var in_army = false
    let wt = new_watch()
    while tick < 20 * 300:
        if tick % 600 == 0: stock_at_least(0, 1500)
        think_all(sides)
        watch_before(wt)
        wstep()
        let hp = watch_after(wt)
        for(hp.paid) v: paid += v
        if tick % 100 == 0:
            var n = 0
            for(u_id.length) i:
                if u_owner[i] == 0 and u_kind[i] == k:
                    n++
                    in_army = in_army or u_stance[i] == ATTACK_MOVE
            most = max(most, n)
    let apart = if placed.length == 2: market_tiles(b_index_of(placed[0]), b_index_of(placed[1])) else: 0
    print "\n== trade bot: markets {apart} tiles apart; most carts at once {most}; gold brought home in 5 minutes {paid}"
    check(placed.length == 2 and apart >= r_trade_min, "trade bot: two markets far enough apart ({apart} tiles)")
    check(most >= 3 and most <= cfg("economy.carts.max"), "trade bot: it trains a few carts, no more than its cap ({most})")
    check(paid > 0 and not in_army, "trade bot: its carts bring gold home ({paid}) and never march with the army")

def ring_spec(gates:[string]) -> JV:
    let spec = jobj()
    set(spec, "wall", jstr("wall"))
    set(spec, "gate", jstr("stone_gate"))
    set(spec, "tower", jstr(""))
    set(spec, "gates", jstrs(gates))
    return spec

// Walls you stand on and the bot. Manning: the bot in a stone ring with shooters at home sends most of
// them up onto the wall facing enemy spears outside. Storming: a bot attacking a walled town pushes its
// siege tower to the wall and, once docked, its swordsmen go up through it and down inside.
def test_walls_bot(a:JV, b:JV):
    if map_id != "flat_test":
        print "\n== walls bot: laid out for flat_test, skipped on {map_id}"
        return
    let r = deep_copy(rules)
    set(r, "animals", jbool(false))
    world([a, b], r)
    for(2) p:
        ages[p] = 3
        retype(p)
        tech_refresh(p)
    let s0x, s0y = start_of(0)
    fortify_ring(0, s0x / 1000, s0y / 1000, 7, ring_spec(["n", "e", "s", "w"]))
    spawn(0, "archer", 10, s0x + 2000, s0y + 2000)
    spawn(1, "spear", 6, s0x + 13000, s0y + 13000)
    let side = full_side(0)
    while tick < 20 * 60:
        think(side)
        wstep()
    var up = 0
    for(u_id.length) i:
        if u_owner[i] == 0 and u_perch[i] != 0: up++
    print "\n== walls bot: {up} of 10 shooters up on the wall after a minute"
    check(up >= 4, "walls bot: the bot mans its wall facing the enemy ({up} of 10 up)")
    // Storming: player 1\'s swordsmen and a siege tower by the ring\'s south-east, attacking.
    world([a, b], r)
    for(2) p:
        ages[p] = 3
        retype(p)
        tech_refresh(p)
    fortify_ring(0, s0x / 1000, s0y / 1000, 7, ring_spec(["n", "w"]))
    spawn(1, "infantry", 8, s0x + 11000, s0y + 4000)
    spawn(1, "siege_tower", 1, s0x + 11000, s0y + 2000)
    for(12): wstep()
    let attacker = new_bot(1)
    attacker.assault = true
    let tx = s0x
    let ty = s0y + 3500
    var docked = -1
    var most_up = 0
    var inside = 0
    while tick < 20 * 150:
        let army = filter(u_id.length) i: u_owner[i] == 1
        storm_walls(attacker, army, tx, ty)
        wstep()
        var n = 0
        var ins = 0
        for(u_id.length) i:
            if u_owner[i] == 1:
                if u_perch[i] != 0: n++
                elif abs(u_x[i] - s0x) < 6500 and abs(u_y[i] - s0y) < 6500: ins++
                if docked < 0 and t_docks[u_kind[i]] and docked_at(i) >= 0: docked = tick
        most_up = max(most_up, n)
        inside = max(inside, ins)
    print "== walls bot: the tower docked at " + (if docked >= 0: clock(docked) else: "never") + "; at most {most_up} swordsmen up at once, {inside} inside"
    check(docked >= 0, "walls bot: its siege tower docks on the enemy wall")
    check(most_up >= 3 and inside >= 3, "walls bot: swordsmen go over the wall by the tower and into the town ({most_up} up, {inside} inside)")

// The Siege mode bot against bot on Siege Vale: player 0 holds the walled town, player 1 attacks. The
// match ends, the defenders man their walls, the attackers make breaches.
def test_siege_mode(a:JV, b:JV):
    let r = deep_copy(rules)
    set(r, "mode", jstr("siege"))
    new_world(SEED, "siege_vale", [a, b], r, [])
    let sides = [full_side(0), full_side(1)]
    var most_up = 0
    while tick < 20 * 60 * 21 and winner < 0:
        think_all(sides)
        wstep()
        if tick % 100 == 0:
            var up = 0
            for(u_id.length) i:
                if u_owner[i] == 0 and u_perch[i] != 0: up++
            most_up = max(most_up, up)
    print "\n== siege mode ({rname(a)} holds, {rname(b)} attacks): winner {winner} at {clock(tick)}; at most {most_up} defenders up, {rubble_cells.length} breach cells"
    check(winner >= 0, "siege mode: the match ends")
    check(most_up >= 6, "siege mode: the defenders man their walls ({most_up} up)")
    check(rubble_cells.length > 0, "siege mode: the attackers make breaches")

// ------------------------------------------------------------------ running the pieces

def run_piece(name:string):
    piece = name
    let t0 = seconds_elapsed()
    if name == "pick": test_pick()
    elif name == "wonder": test_wonder(rats, frogs)
    elif name == "passive_frogs": test_passive(frogs, rats)
    elif name == "passive_rats": test_passive(rats, frogs)
    elif name == "bvb": test_bvb()
    elif name == "bvb_again": match_stats(play_pair([frogs, rats], "bot vs bot, again", true))   // the same match again: same hashes, same winner
    elif name == "centaurs_frogs": test_races(generate("centaur romans", rules, 0), frogs)
    elif name == "rats_centaurs": test_races(rats, generate("centaur romans", rules, 0))
    elif name == "easy": test_easy(rats, frogs)
    elif name == "hard": test_hard()
    elif name == "respond": test_respond(rats, frogs)
    elif name == "shelter": test_shelter(rats, frogs)
    elif name == "walled_fords": test_walled_fords(frogs, rats)
    elif name == "rams": test_rams(frogs)
    elif name == "siege_bot": test_siege_bot(rats, frogs)
    elif name == "trade_bot": test_trade_bot(frogs, rats)
    elif name == "walls_bot": test_walls_bot(rats, frogs)
    elif name == "siege_mode": test_siege_mode(frogs, rats)
    elif name == "walled_palisade": test_walled_base(frogs, rats, "palisade", false)
    elif name == "walled_wall": test_walled_base(frogs, rats, "wall", false)
    elif name == "walled_gap": test_walled_base(frogs, rats, "wall", true)
    elif name == "age3": test_age_three(frogs, rats)
    elif name == "land": test_land(frogs, rats)
    elif name == "guard": test_guard(frogs, rats)
    elif name == "hills": test_hills(frogs, rats)
    elif name == "levels_easy": test_level(frogs, rats, "easy")
    elif name == "levels_normal": test_level(frogs, rats, "normal")
    elif name == "levels_hard": test_level(frogs, rats, "hard")
    elif name == "surrender":
        world([frogs, rats], rules)
        issue_cmd(1, CMD_SURRENDER, []::int, 0, 0, 0, 0)
        for(40): wstep()
        check(defeated[1] > 0 and winner == 0, "surrendering ends the match")
    else:
        print "test_ai: no piece {name}"
        failures++
    print "-- {name}: {int(seconds_elapsed() - t0)} s"

// The pieces a mode runs.
def pieces_of(mode:string) -> [string]:
    if mode == "": return PIECES
    if mode == "quick": return PIECES.slice(0, SLOW_FROM)
    if mode == "slow": return PIECES.slice(SLOW_FROM, -1)
    if starts_with(mode, "piece:"): return tokenize(mode.substring(6, mode.length - 6), ",", " ")
    for(GROUPS) g:
        if g[0] == mode: return tokenize(g[1], ",", " ")
    print "test_ai: unknown mode {mode}"
    return []

// Shards' logs: the stats ("@@ piece key value") and the check counts ("N passed, M failed").
def read_logs(paths:[string]):
    for(paths) path:
        let text = read_file(path) or ""
        var counted = false
        for(tokenize(text, "\n", "")) line:
            let ws = tokenize(line, " ", "")
            if ws.length == 4 and ws[0] == "@@":
                stats.set(ws[1] + " " + ws[2], string_to_int(ws[3]))
            elif ws.length == 4 and ws[1] == "passed," and ws[3] == "failed":
                let p = string_to_int(ws[0])
                let f = string_to_int(ws[2])
                checks += p + f
                failures += f
                counted = true
        if not counted:
            print "FAIL: {path} has no result (crashed or timed out?)"
            checks++
            failures++

let args0 = command_line_arguments()
let args = plain_args(args0)
let combine_at = find_index(args, "combine")
if combine_at >= 0:
    read_logs(args.slice(combine_at + 1, -1))
    combine()
else:
    var rest = args
    if rest.length and map_exists(rest[0]):
        map_id = rest[0]
        rest = rest.slice(1, -1)
    let mode = if rest.length: rest[0] else: ""
    let shard, shards = shard_of(args0)
    print "map: {map_id}" + (if shards > 1: ", shard {shard}/{shards}" else: "")
    let t0 = seconds_elapsed()
    let names = pieces_of(mode)
    for(names) name, n:
        if n % shards == shard: run_piece(name)
    if shards == 1: combine()
    print "\n({int(seconds_elapsed() - t0)} s)"
print "\n{checks - failures} passed, {failures} failed"
if failures > 0: set_exit_code(1)
