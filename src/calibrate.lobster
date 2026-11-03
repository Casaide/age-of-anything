// Prices calibrated offline (D-195): what a part is worth, from fights, once, not per match. Run from src:
//   ./shards.sh calibrate.lobster lines <age> <races> [jobs=4]
//       <races> races from the lexicon's words (training prompts, the lobby's dice made deterministic); each of
//       their lines in <age> is fought against a fixed panel (every line of a few random races) at equal cost, its
//       price moved until its score is what the counter chain expects (D-196: half of its neutral fights, 80% where
//       it has a counter's edge, 20% where the other has): its fair price. The combine writes the samples to
//       ../build/calibrate/.
//   lobster calibrate.lobster -- fit [lambda:<n>] [write]
//       each sample's fair price -> its target points (the cost curve's inverse), then every part's
//       price_points by regularized least squares (a unit's points are the sum of its parts'); prints what
//       moved, and with write puts them in ../build/calibrate/prices.json for tools/balance/write_prices.py.
//   ./shards.sh calibrate.lobster measure [pool] [neutral|expect] [check:<n>] [oracle] [jobs=4]
//       held-out races and the setup's defaults in groups, each group's round robin at the prices as they are
//       (no fights at load): how many lines are more than 10 points off the mean of their group. check:<n> fails
//       (exit 1) when more than n percent of all lines are (tests/batch.sh: a new part can't slip in unpriced).
//       pool: every held-out line in one round robin (some 140 fights a line, not 13: far less noise).
//       neutral: only the fights where neither side has a counter's edge. expect: each line's wins over what the
//       counter chain expects of its fights, around 50 (D-196: what the prices are fitted to).
//       oracle: each line at its own fair price against the panel instead (./shards.sh calibrate.lobster oracle
//       first): the best pricing by panel can do, fit or no fit.
//   lobster calibrate.lobster -- mod <id>
//       a mod's new parts priced (mod_check.sh): its check prompts' lines that wear them fought against the panel in
//       ages 2 and 3, then only its parts fitted, the base prices held; prints each part's price_points to set.
// Under D-193 this belongs with the generator in the race-generation toolkit module (modules/racegen), not the engine.
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
import gen.mods
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
import gen.balance

let PANEL_RACES = 3  // the panel: every line of a few races from the dice (seed "panel"; no creature or culture twice)
let PRICE_LO = 40    // percent of the generator's price: the search's bracket
let PRICE_HI = 250
let STEPS = 4       // halvings of the bracket (in ratio): about 6% at the end
let TOLERANCE = 10  // win-rate points off the group's mean
let OUT_DIR = "../build/calibrate"

let args0 = command_line_arguments()
def shard_arg(xs:[string]) -> int, int:
    for(xs) a:
        if starts_with(a, "shard:"):
            let i, n = split_string(a.substring(6, a.length - 6), "/")
            return string_to_int(i), string_to_int(n)
    return 0, 1
def combine_index(xs:[string]) -> int:
    for(xs) a, n:
        if a == "combine": return n
    return -1
def opt(xs:[string], name:string, fallback:string) -> string:
    for(xs) a:
        if starts_with(a, name + ":"): return a.substring(name.length + 1, a.length - name.length - 1)
    return fallback
let shard, shards = shard_arg(args0)
let combine_at = combine_index(args0)
let logs = if combine_at >= 0: args0.slice(combine_at + 1, -1) else: []::string
let args = filter(if combine_at >= 0: args0.slice(0, combine_at) else: args0) a: not starts_with(a, "shard:")
lib_load("../data")
id_load("../data")
let mod_id = if args0.length > 1 and args0[0] == "mod": args0[1] else: ""
if mod_id != "": assert mods_use([ mod_id ]).length == 1
let rules = load_rules(if mod_id != "": gstr(gobj(mods_active[0].manifest, "check"), "rules", "default") else: "default")
let bare = bare_rules(rules)

// ---- prompts: the lobby's dice (fe_random_words), from a seed

def lexicon_words(even:bool) -> [string], [string], [string], [string]:
    let creatures = []::string
    let cultures = []::string
    let kit = []::string
    let sizes = []::string
    for(lib_lexicon.keys) w, n:
        let e = lib_lexicon.a[n]
        if has(e, "creature") and ends_with(w, "s") and gbool(gobj(lib_creatures, gstr(e, "creature", "")), "playable", false): creatures.push(w)
        elif has(e, "family") and not has(e, "creature"): cultures.push(w)
        elif e.keys.length == 1 and has(e, "tags"): kit.push(w)
        elif e.keys.length == 1 and has(e, "size"): sizes.push(w)
    if not even: return sorted_strs(creatures), sorted_strs(cultures), sorted_strs(kit), sorted_strs(sizes)
    // even: one word a creature (its first), so every creature is as likely as any other, however many words it has
    let firsts = []::string
    let seen = []::string
    for(sorted_strs(creatures)) w:
        let cr = gstr(at(lib_lexicon, w), "creature", "")
        if find_index(seen, cr) < 0:
            seen.push(cr)
            firsts.push(w)
    return firsts, sorted_strs(cultures), sorted_strs(kit), sorted_strs(sizes)

def random_prompts(seed:string, count:int) -> [string]:
    let cr, cu, ki, si = lexicon_words(seed != "held")  // (the held-out prompts as first measured: the lobby's odds)
    let r = new_rng(hash_text(seed))
    return map(count):
        let words = []::string
        if chance(r, 25): words.push(rpick(r, si))
        if chance(r, 70): words.push(rpick(r, cu))
        words.push(rpick(r, cr))
        if chance(r, 65):
            words.push("with " + rpick(r, ki))
            if chance(r, 35): words.push("and " + rpick(r, ki))
        concat_string(words, " ")

def panel_of() -> [JV]:
    let out = []::JV
    for(random_prompts("panel", 60)) p:
        let r = generate(p, rules, 0)
        let seen = filter(out) o: rstr(o, "creature") == rstr(r, "creature") or rstr(o, "family") == rstr(r, "family")
        if out.length < PANEL_RACES and not seen.length: out.push(r)
    return out

// ---- a line's parts (as evaluate adds them up) and the rest of its points

def line_parts(recipe:JV) -> [string]:
    let out = [ as_str(at(recipe, "body")) ]
    if gstr(recipe, "head", "") != "": out.push(as_str(at(recipe, "head")))
    for(at(recipe, "parts").a) v: out.push(as_str(v))
    for(gobj(recipe, "kit").a) v: out.push(as_str(v))
    let mount = get(recipe, "mount")
    if mount:
        let mc = creature(as_str(at(mount, "creature")))
        out.push(if gbool(mount, "fused", false): gstr(mc, "fused_body", as_str(at(mc, "body"))) else: gstr(mc, "mount_body", as_str(at(mc, "body"))))
        for(at(mount, "parts").a) v: out.push(as_str(v))
    return out

def step_at(u:JV, age:int) -> JV:
    var step = glist(u, "line")[0]
    for(glist(u, "line")) l:
        if as_int(at(l, "age")) <= age: step = l
    return step

def step_of(race:JV, slot:string, age:int) -> JV:
    for(glist(race, "units")) u:
        if rstr(at(u, "recipe"), "slot") == slot: return step_at(u, age)
    assert false
    return jobj()

def spaced(s:string) -> string: return concat_string(tokenize(s, "_", ""), " ")
def unspaced(s:string) -> string: return concat_string(tokenize(s, " ", ""), "_")

// ---- lines: fair prices against the panel

// Percent of the panel's fights it wins (a draw half), its line at pct of its price.
def unit_eval(races:[JV], u:RRUnit, age:int) -> JV: return at(step_of(races[u.race], u.slot, age), "eval")

// a has a counter's edge over b: one of its attack bonuses is for a class b has (its tags: type_vectors).
def edge(a:JV, b:JV) -> bool:
    let tags = eval_tags(b)
    let bonus = at(a, "bonus")
    for(bonus.keys) k, n:
        if as_int(bonus.a[n]) > 0 and has_s(tags, k): return true
    return false

// Neither has a counter's edge over the other (D-196).
def neutral(races:[JV], age:int, a:RRUnit, b:RRUnit) -> bool:
    let ea = unit_eval(races, a, age)
    let eb = unit_eval(races, b, age)
    return not edge(ea, eb) and not edge(eb, ea)

def panel_score(races:[JV], age:int, unit:RRUnit, panel:[RRUnit], pct:int) -> int:
    rr_price_pct.set(price_key(races, unit), pct)
    var score = 0
    for(panel) p:
        let r = rr_fight(races, bare, age, unit, p)
        score += if r > 0: 2 elif r == 0: 1 else: 0
    rr_price_pct.set(price_key(races, unit), 100)
    return score * 50 / panel.length

// What a fight with b should give a, by the counter chain (D-196): a counter's edge wins, a neutral fight is even.
let EDGE_SCORE = 80
def expected(races:[JV], age:int, a:RRUnit, b:RRUnit) -> int:
    let ea = unit_eval(races, a, age)
    let eb = unit_eval(races, b, age)
    let ab = edge(ea, eb)
    let ba = edge(eb, ea)
    return if ab and not ba: EDGE_SCORE elif ba and not ab: 100 - EDGE_SCORE else: 50

// Its fair price, percent of its price: where its score against the panel is what the counter chain expects of it, so
// a counter keeps its edge instead of paying for it (D-196; with only neutral fights, where it wins half).
def fair_pct(races:[JV], age:int, unit:RRUnit, panel:[RRUnit]) -> int:
    var want = 0
    for(panel) p: want += expected(races, age, unit, p)
    want /= panel.length
    var lo = PRICE_LO
    var hi = PRICE_HI
    for(STEPS):
        let mid = isqrt(lo * hi)
        if panel_score(races, age, unit, panel, mid) > want: lo = mid else: hi = mid
    return isqrt(lo * hi)

def run_lines(age:int, count:int):
    let panel_races = panel_of()
    let panel = rr_units(panel_races, age)
    if shard == 0: print "panel ({panel.length} lines): " + concat_string(map(panel) u: u.label, ", ")
    let prompts = random_prompts("train", count)
    var k = 0
    for(prompts) prompt, n:
        let races = copy(panel_races)
        races.push(generate(prompt, rules, n % 4))
        for(rr_units(races, age)) u:
            if u.race == races.length - 1:
                if k % shards == shard:
                    let pct = fair_pct(races, age, u, panel)
                    let e = at(step_of(races[u.race], u.slot, age), "eval")
                    let parts = line_parts(at(step_of(races[u.race], u.slot, age), "recipe"))
                    var sum = 0
                    for(parts) id: sum += price_of(part(id))
                    let points = as_int(at(e, "points"))
                    let tags = eval_tags(e)
                    let size = if has_s(tags, "giant"): "giant" elif has_s(tags, "tiny"): "tiny" else: "-"
                    print "@@ {age} {u.slot} {pct} {points} {points - sum} {concat_string(parts, ",")} {unspaced(u.label)} {size}"
                k++

// ---- fit: price points from the samples

class Sample:
    age:int
    slot:string
    pct:int
    points:int
    fixed:int
    parts:[string]
    label:string
    size:string  // giant, tiny or -

def read_samples(paths:[string]) -> [Sample]:
    let out = []::Sample
    for(paths) path:
        for(tokenize(read_file(path) or "", "\n", "")) line:
            let w = tokenize(line, " ", "")
            if w.length == 9 and w[0] == "@@":
                out.push(Sample { string_to_int(w[1]), w[2], string_to_int(w[3]), string_to_int(w[4]), string_to_int(w[5]), tokenize(w[6], ",", ""), spaced(w[7]), w[8] })
    return out

// The points (real) whose curve value is c: the cost curve's inverse, between its steps.
def curve_inverse(id:string, c:float) -> float:
    let t = lib_curves.get(id)
    assert t
    for(t.length - 1) i:
        if float(t[i + 1]) >= c: return float(i) + (c - float(t[i])) / float(t[i + 1] - t[i])
    return float(t.length - 1)

// A sample's target points: its fair price over its age's typical one (the geometric mean, so the panel's own
// price level doesn't move every price), through the curve's inverse.
// normalize false: against the panel as it stands (a mod's lines, once the base data is calibrated: its lines' mean is
// the panel's, about 100%).
def targets(samples:[Sample], normalize:bool) -> [float]:
    let cid = as_str(at(at(rules, "cost"), "curve"))
    let mean_log = map(5): 0.0
    let n_age = map(5): 0
    for(samples) s:
        mean_log[s.age] += log(float(s.pct))
        n_age[s.age]++
    for(5) a:
        if n_age[a] > 0: mean_log[a] /= float(n_age[a])
    return map(samples) s:
        let m = float(s.pct) / (if normalize: pow(2.718281828, mean_log[s.age]) else: 100.0)
        curve_inverse(cid, float(curve(cid, s.points)) * m)

def writable_parts() -> [string]:
    return sorted_strs(map(load_json("../data/parts.json").a) p: as_str(at(p, "id")))

// What a giant adds to the price, and a tiny one takes off (rules.cost), fitted as "size:giant" and "size:tiny".
def size_points(size:string) -> int:
    let c = at(rules, "cost")
    return if size == "giant": gint(c, "giant_price_points", GIANT_POINTS) elif size == "tiny": -gint(c, "tiny_price_points", 1) else: 0

// A line's own price points (the rules' roster: what its slot's stats add), fitted with the parts as "slot:<slot>".
def roster_points(slot:string) -> int:
    for(glist(rules, "roster")) sd:
        if as_str(at(sd, "slot")) == slot: return gint(sd, "price_points", 0)
    return 0

// The base data's prices: every part in parts.json, the lines' and the sizes' points.
def base_ids() -> [string]:
    let ids = writable_parts()
    for(RR_SLOTS) slot: ids.push("slot:" + slot)
    for(RR_SLOTS_AGE3) slot: ids.push("slot:" + slot)
    ids.push("size:giant")
    ids.push("size:tiny")
    return ids

// The fitted price points of ids (everything else held at its price), from the samples. Returns {id: points}.
def run_fit(samples:[Sample], ids:[string], lambda:float, normalize:bool) -> JV:
    assert samples.length
    let t = targets(samples, normalize)
    let index = dictionary<string, int>(ids.length * 2)
    for(ids) id, n: index.set(id, n)
    let x0 = map(ids) id: float(if starts_with(id, "slot:"): roster_points(id.substring(5, id.length - 5)) elif starts_with(id, "size:"): size_points(id.substring(5, id.length - 5)) else: price_of(part(id)))
    let rows = map(samples) s:
        let r = filter(map(s.parts) id: index.get(id, -1)) n: n >= 0
        if index.get("slot:" + s.slot, -1) >= 0: r.push(index.get("slot:" + s.slot, -1))
        if index.get("size:" + s.size, -1) >= 0: r.push(index.get("size:" + s.size, -1))
        r
    // what the samples want of the parts and lines: target - fixed points - the parts it holds that aren't fitted
    let want = map(samples) s, k:
        var rest = float(s.fixed)
        if index.get("slot:" + s.slot, -1) >= 0: rest -= float(roster_points(s.slot))
        if index.get("size:" + s.size, -1) >= 0: rest -= float(size_points(s.size))
        for(s.parts) id:
            if index.get(id, -1) < 0: rest += float(price_of(part(id)))
        t[k] - rest
    // each line's misses weighed by what a point does to its price (a point is a quarter of a cheap line's price,
    // a twentieth of a dear one's): the curve's slope over its value, squared, scaled to 1 at 12 points
    let cid = as_str(at(at(rules, "cost"), "curve"))
    def rel_slope(p:float) -> float:
        let i = clamp(int(p), 1, 90)
        return float(curve(cid, i + 1) - curve(cid, i - 1)) / 2.0 / float(curve(cid, i))
    let ref = rel_slope(12.0)
    let weight = map(t) p: (rel_slope(p) / ref) * (rel_slope(p) / ref)
    // Gauss-Seidel on (lambda I + X'X) x = lambda x0 + X'y; the parts no sample holds stay as they are
    let uses = map(ids): []::int
    for(rows) r, k:
        for(r) n: uses[n].push(k)
    let x = copy(x0)
    let pred = map(rows) r:
        var s = 0.0
        for(r) n: s += x[n]
        s
    def objective(xs:[float]) -> float:
        var e = 0.0
        for(rows) r, k:
            var s = 0.0
            for(r) n: s += xs[n]
            e += weight[k] * (want[k] - s) * (want[k] - s)
        for(xs) v, n: e += lambda * (v - x0[n]) * (v - x0[n])
        return e
    for(300):
        for(ids.length) n:
            if uses[n].length:
                var num = lambda * x0[n]
                var den = lambda
                for(uses[n]) k:
                    num += weight[k] * (want[k] - (pred[k] - x[n]))
                    den += weight[k]
                let v = if starts_with(ids[n], "slot:") or ids[n] == "size:tiny": num / den else: max(0.0, num / den)
                for(uses[n]) k: pred[k] += v - x[n]
                x[n] = v
    // to whole points, then one point at a time while it helps
    let xi = map(x) v: float(floor(v + 0.5))
    for(4):
        for(ids.length) n:
            if uses[n].length:
                let here = objective(xi)
                xi[n] += 1.0
                if objective(xi) >= here:
                    xi[n] -= 2.0
                    if (xi[n] < 0.0 and not starts_with(ids[n], "slot:") and ids[n] != "size:tiny") or objective(xi) >= here: xi[n] += 1.0
    // the report: how far the lines' points are from their targets, before and after
    def misses(xs:[float]) -> float, int:
        var e = 0.0
        var far = 0
        for(rows) r, k:
            var s = 0.0
            for(r) n: s += xs[n]
            let pct = abs(want[k] - s) * rel_slope(t[k]) * 100.0
            e += pct
            if pct > 15.0: far++
        return e / float(rows.length), far
    let m0, f0 = misses(x0)
    let m1, f1 = misses(xi)
    let mr, fr = misses(x)
    print "unrounded: {mr}%, {fr} more than 15% off"
    print "{samples.length} samples; mean miss {m0}% -> {m1}% of the price; more than 15% off: {f0} -> {f1}"
    // what's left by line and by tag: where adding up parts still misses
    let groups = dictionary<string, [float]>(64)
    for(rows) r, k:
        var s = 0.0
        for(r) n: s += xi[n]
        let keys = [ samples[k].slot ]
        for(samples[k].parts) id:
            for(gstrs(part(id), "tags")) tg: keys.push("tag " + tg)
        for(keys) g:
            let acc = groups.get(g, [ 0.0, 0.0 ])
            groups.set(g, [ acc[0] + want[k] - s, acc[1] + 1.0 ])
    for(sorted_strs(groups.get_keys())) g:
        let acc = groups.get(g, [ 0.0, 0.0 ])
        if normalize and acc[1] >= 10.0 and abs(acc[0] / acc[1]) > 0.5: print "  left on {g}: {acc[0] / acc[1]} points ({int(acc[1])} lines)"
    let prices = jobj()
    var moved = 0
    for(ids) id, n:
        if xi[n] != x0[n]:
            moved++
            print "  {id}: {int(x0[n])} -> {int(xi[n])} ({uses[n].length} samples, fit {x[n]})"
        if uses[n].length: set(prices, id, jint(int(xi[n])))
    print "{moved} parts moved"
    return prices

// A mod's new parts priced: each line of its check prompts that wears one, in ages 2 and 3, fought against the panel;
// then only its parts fitted, every base price held (mod_check.sh). Prints what each of its parts' price_points
// should be; prices.json is not touched.
def run_mod(id:string):
    let own = map(load_json(mods_active[0].dir + "/" + gstr(mods_active[0].manifest, "data", "data") + "/parts.json").a) p: as_str(at(p, "id"))
    let samples = []::Sample
    for([ 2, 3 ]) age:
        let panel_races = panel_of()
        let panel = rr_units(panel_races, age)
        for(gstrs(gobj(mods_active[0].manifest, "check"), "prompts")) prompt:
            let races = copy(panel_races)
            races.push(generate(prompt, rules, 0))
            for(rr_units(races, age)) u:
                if u.race == races.length - 1:
                    let step = step_of(races[u.race], u.slot, age)
                    let parts = line_parts(at(step, "recipe"))
                    if (filter(parts) pid: has_s(own, pid)).length:
                        let e = at(step, "eval")
                        var sum = 0
                        for(parts) pid: sum += price_of(part(pid))
                        let tags = eval_tags(e)
                        let size = if has_s(tags, "giant"): "giant" elif has_s(tags, "tiny"): "tiny" else: "-"
                        let pct = fair_pct(races, age, u, panel)
                        print "  age {age}: {u.label}: fair at {pct}% of its price"
                        if pct > 0: samples.push(Sample { age, u.slot, pct, as_int(at(e, "points")), as_int(at(e, "points")) - sum, parts, u.label, size })
    if not samples.length:
        print "mod {id}: no line of its check prompts wears its parts (nothing to price)"
        return
    let fitted = run_fit(samples, filter(own) pid: has(lib_parts, pid), 3.0, false)
    for(own) pid:
        if has(fitted, pid):
            let p = part(pid)
            print "  {pid}: price_points {as_int(at(fitted, pid))} (points {as_int(at(p, "points"))}" + (if has(p, "price_points"): ", now {price_of(p)})" else: ")")

// ---- measure: round robins of held-out groups at the prices as they are

def measure_groups() -> [[string]]:
    let held = random_prompts("held", 16)
    let groups = [ [ "sewer rats with cheese hammers", "angry swamp frogs with reed spears" ],
                   [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites", "spooky beetle knights" ] ]
    for(4) g: groups.push([ held[g * 2], held[g * 2 + 1] ])
    for(2) g: groups.push([ held[8 + g * 4], held[9 + g * 4], held[10 + g * 4], held[11 + g * 4] ])
    return groups

// The method's best: every held-out line at its own fair price against the panel (no fit), for measure oracle.
def run_oracle():
    let panel_races = panel_of()
    let panel = rr_units(panel_races, 2)
    var k = 0
    for(measure_groups()) g:
        for(g) prompt:
            let races = copy(panel_races)
            races.push(generate(prompt, rules, 0))
            for(rr_units(races, 2)) u:
                if u.race == races.length - 1:
                    if k % shards == shard: print "@@ {price_key(races, u)} {fair_pct(races, 2, u, panel)}"
                    k++

// Every held-out race in one group: some 140 fights a line, so its win rate is good to a few points (a group of
// 2 races gives a line 13 fights: one fight is 8 points, and coin flips alone put half the lines 10 off).
def pool_group() -> [[string]]:
    let out = []::string
    for(measure_groups()) g:
        for(g) p:
            if find_index(out, p) < 0: out.push(p)
    return [ out ]

// only_neutral: only the fights where neither side has a counter's edge count (what the prices are fitted to).
// against_expected: a line's rate is 50 + its wins over what the counter chain expects of its fights (D-196: what
// the prices are fitted to; 50 is priced right, whoever it met).
def run_measure(check:int, oracle:bool, one_pool:bool, only_neutral:bool, against_expected:bool):
    let groups = if one_pool: pool_group() else: measure_groups()
    let group_races = map(groups) g: map(g) p: generate(p, rules, 0)
    let group_units = map(group_races) rs: rr_units(rs, 2)
    if oracle:
        for(tokenize(read_file(OUT_DIR + "/oracle.txt") or "", "\n", "")) line:
            let w = tokenize(line, " ", "")
            if w.length == 3 and string_to_int(w[2]) > 0: rr_price_pct.set(w[1], string_to_int(w[2]))
    let results = map(groups) g, n: map(group_units[n].length * group_units[n].length): 0
    if combine_at >= 0:
        for(logs) path:
            for(tokenize(read_file(path) or "", "\n", "")) line:
                let w = tokenize(line, " ", "")
                if w.length == 5 and w[0] == "@@":
                    let g = string_to_int(w[1])
                    results[g][string_to_int(w[2]) * group_units[g].length + string_to_int(w[3])] = string_to_int(w[4])
    else:
        var k = 0
        for(groups.length) n:
            let units = group_units[n]
            for(units.length) i:
                var j = i + 1
                while j < units.length:
                    if k % shards == shard and (not only_neutral or neutral(group_races[n], 2, units[i], units[j])):
                        let r = rr_fight(group_races[n], bare, 2, units[i], units[j])
                        results[n][i * units.length + j] = r
                        print "@@ {n} {i} {j} {r}"
                    k++
                    j++
        if shards > 1: return
    var off_all = 0
    var lines_all = 0
    for(groups) g, n:
        let units = group_units[n]
        let wins = map(units.length): 0
        let played = map(units.length): 0
        let expect = map(units.length): 0
        for(units.length) i:
            var j = i + 1
            while j < units.length:
                let r = results[n][i * units.length + j]
                if r != 0 and (not only_neutral or neutral(group_races[n], 2, units[i], units[j])):
                    played[i]++
                    played[j]++
                    if r > 0: wins[i]++ else: wins[j]++
                    if against_expected:
                        let x = expected(group_races[n], 2, units[i], units[j])
                        expect[i] += x
                        expect[j] += 100 - x
                j++
        let rates = map(units.length) i: (wins[i] * 100 - (if against_expected: expect[i] - 50 * played[i] else: 0)) / max(1, played[i])
        var total = 0
        for(rates) r: total += r
        let mean = total / max(1, units.length)
        var off = 0
        for(rates) r:
            if abs(r - mean) > TOLERANCE: off++
        print "\n{off} of {units.length} lines more than {TOLERANCE} points off the mean ({mean}%): " + (if one_pool: "the pool" else: concat_string(g, " | "))
        let order = map(units.length) i: i
        insertion_sort(order) a, b: abs(rates[a] - mean) > abs(rates[b] - mean)
        for(order) i:
            let e = at(step_of(group_races[n][units[i].race], units[i].slot, 2), "eval")
            var cost = 0
            for(at(e, "cost").a) v: cost += as_int(v)
            print "  {rates[i]}%  {units[i].label}  cost {cost}" + (if abs(rates[i] - mean) > TOLERANCE: "  OFF" else: "")
        off_all += off
        lines_all += units.length
    print "\nIn all: {off_all} of {lines_all} lines more than {TOLERANCE} points off the mean of their group ({off_all * 100 / max(1, lines_all)}%)"
    if check >= 0 and off_all * 100 > check * lines_all:
        print "FAIL: more than {check}% of the lines are off (a part priced wrong? ./shards.sh calibrate.lobster lines ...)"
        set_exit_code(1)

let mode = args[0]
if mode == "lines":
    let age = string_to_int(args[1])
    if combine_at >= 0:
        let text = []::string
        for(logs) path:
            for(tokenize(read_file(path) or "", "\n", "")) line:
                if starts_with(line, "@@ "): text.push(line)
        write_file(OUT_DIR + "/age{age}.txt", concat_string(text, "\n") + "\n")
        print "{text.length} samples in {OUT_DIR}/age{age}.txt"
    else:
        run_lines(age, string_to_int(args[2]))
elif mode == "fit":
    let prices = run_fit(read_samples([ OUT_DIR + "/age2.txt", OUT_DIR + "/age3.txt" ]), base_ids(), string_to_float(opt(args, "lambda", "1")), true)
    if find_index(args, "write") >= 0:
        write_file(OUT_DIR + "/prices.json", stringify(prices))
        print "wrote " + OUT_DIR + "/prices.json"
elif mode == "mod":
    run_mod(mod_id)
elif mode == "measure":
    run_measure(string_to_int(opt(args, "check", "-1")), find_index(args, "oracle") >= 0, find_index(args, "pool") >= 0, find_index(args, "neutral") >= 0, find_index(args, "expect") >= 0)
elif mode == "oracle":
    if combine_at >= 0:
        let text = []::string
        for(logs) path:
            for(tokenize(read_file(path) or "", "\n", "")) line:
                if starts_with(line, "@@ "): text.push(line)
        write_file(OUT_DIR + "/oracle.txt", concat_string(text, "\n") + "\n")
        print "{text.length} fair prices in {OUT_DIR}/oracle.txt"
    else:
        run_oracle()
else:
    print "calibrate.lobster: lines <age> <races> | fit [lambda:<n>] [write] | measure [pool] [check:<n>] [oracle] | oracle | mod <id>"
    assert false
