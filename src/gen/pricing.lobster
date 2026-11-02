// ------------------------------------------------------------------ Pricing (src/pricing.gd)
// Recipe -> stats, tags and cost. Integer maths; the superlinear curve is a fixed-point table.

let GIANT_POINTS = 6
let WEAPON_KEYS = [ "reload", "min_range", "splash", "pass", "targets", "unpack", "pack", "blast", "blast_line_pct" ]

// Small int maps in insertion order (armour, bonus, mixes), as JV objects of ints.
def iget(o:JV, k:string) -> int: return gint(o, k, 0)
def iadd(o:JV, k:string, n:int): set(o, k, jint(iget(o, k) + n))
def add_classes(into:JV, add:JV):
    for(add.keys) k, n: iadd(into, k, as_int(add.a[n]))

def mix_of(food:int, wood:int) -> JV:
    let o = jobj()
    set(o, "food", jint(food))
    set(o, "wood", jint(wood))
    return o

def add_mix(mix:JV, p:JV, food:int, wood:int):
    let m = get(p, "cost_mix") or mix_of(food, wood)
    let pts = as_int(at(p, "points"))
    for(m.keys) k, n: iadd(mix, k, as_int(m.a[n]) * pts)

def price_of(p:JV) -> int: return gint(p, "price_points", as_int(at(p, "points")))
def round10(n:int) -> int: return max(0, (n + 5) / 10 * 10)

// A set of tags in insertion order.
def tag_add(tags:[string], t:string):
    if not has_s(tags, t): tags.push(t)

def evaluate(recipe:JV, rules:JV, age:int) -> JV:
    let body = part(as_str(at(recipe, "body")))
    let gear = []::JV
    if gstr(recipe, "head", "") != "": gear.push(part(as_str(at(recipe, "head"))))
    let rparts = at(recipe, "parts")
    for(rparts.a) v: gear.push(part(as_str(v)))
    for(gobj(recipe, "kit").a) v: gear.push(part(as_str(v)))
    let bstats = at(body, "stats")
    var hp = gint(bstats, "hp", 0)
    let armour = jobj()
    set(armour, "melee", jint(0))
    set(armour, "pierce", jint(0))
    add_classes(armour, gobj(bstats, "armour"))
    var speed = gint(bstats, "speed", 10)
    var attack = 0
    var heal = 0
    var reach = 1
    let bonus = jobj()
    add_classes(bonus, gobj(bstats, "bonus"))
    var damage = "melee"
    let weapon = jobj()
    for(WEAPON_KEYS) k: set(weapon, k, if k == "targets": jstr("") else: jint(0))
    let tags = []::string
    var points = price_of(body)
    let mix = jobj()
    add_mix(mix, body, 50, 50)
    for(gstrs(body, "tags")) t: tag_add(tags, t)
    for(gear) p:
        let s = at(p, "stats")
        hp += gint(s, "hp", 0)
        add_classes(armour, gobj(s, "armour"))
        speed += gint(s, "speed", 0)
        attack += gint(s, "attack", 0)
        heal += gint(s, "heal", 0)
        reach = max(reach, gint(s, "range", 1))
        if has(s, "damage"): damage = as_str(at(s, "damage"))
        for(WEAPON_KEYS) k:
            if has(s, k): set(weapon, k, if k == "targets": at(s, k) else: jint(as_int(at(s, k))))
        add_classes(bonus, gobj(s, "bonus"))
        for(gstrs(p, "tags")) t: tag_add(tags, t)
        points += price_of(p)
        add_mix(mix, p, 50, 50)
    let mount = get(recipe, "mount")
    if mount:
        let mc = creature(as_str(at(mount, "creature")))
        let mbid = if gbool(mount, "fused", false): gstr(mc, "fused_body", as_str(at(mc, "body"))) else: gstr(mc, "mount_body", as_str(at(mc, "body")))
        let mount_body = part(mbid)
        let ms = at(mount_body, "stats")
        hp += gint(ms, "hp", 0)
        add_classes(armour, gobj(ms, "armour"))
        add_classes(bonus, gobj(ms, "bonus"))
        speed += gint(ms, "speed", 10) - gint(bstats, "speed", 10)
        points += price_of(mount_body)
        add_mix(mix, mount_body, 70, 30)
        for(gstrs(mount_body, "tags")) t:
            if t != "mount": tag_add(tags, t)
        for(gstrs(mount_body, "rider_loses")) t:
            let at_n = find_index(tags, t)
            if at_n >= 0: tags.remove(at_n)
        let mparts = at(mount, "parts")
        for(mparts.a) v:
            let mp = part(as_str(v))
            hp += gint(at(mp, "stats"), "hp", 0)
            speed += gint(at(mp, "stats"), "speed", 0)
            points += price_of(mp)
            add_mix(mix, mp, 70, 30)
            for(gstrs(mp, "tags")) t: tag_add(tags, t)
        tag_add(tags, "mounted")
        if gbool(mount_body, "large", true): tag_add(tags, "large")
    let extra = []::JV
    var look_only = false
    for(glist(rules, "roster")) sd:
        if as_str(at(sd, "slot")) == gstr(recipe, "slot", ""):
            look_only = gbool(sd, "size_is_look", false)
            extra.push(sd)
            if not mount and has(sd, "stats_on_foot"):
                let x = jobj()
                set(x, "stats", at(sd, "stats_on_foot"))
                extra.push(x)
    if has(recipe, "unique"): extra.push(at(lib_uniques, as_str(at(recipe, "unique"))))
    var sight = 0
    for(extra) x:
        add_classes(bonus, gobj(x, "bonus"))
        points += gint(x, "price_points", 0)
        let st = gobj(x, "stats")
        add_classes(armour, gobj(st, "armour"))
        hp += gint(st, "hp", 0)
        attack += gint(st, "attack", 0)
        speed += gint(st, "speed", 0)
        reach += gint(st, "range", 0)
        sight += gint(st, "sight", 0)
        if has(st, "reload"): set(weapon, "reload", jint(as_int(at(st, "reload"))))
    for(extra) x:
        let sp = gobj(x, "stats_pct")
        hp = hp * gint(sp, "hp", 100) / 100
        attack = attack * gint(sp, "attack", 100) / 100
    let scale = if look_only: 100 else: as_int(at(recipe, "scale"))
    if scale >= 140:
        hp *= 2
        attack += 3
        iadd(armour, "pierce", 3)
        speed -= 2
        points += gint(at(rules, "cost"), "giant_price_points", GIANT_POINTS)  // (calibrated: the generator spends GIANT_POINTS)
        tag_add(tags, "large")
        tag_add(tags, "giant")
    elif scale <= 85:
        hp = hp * 8 / 10
        speed += 1
        points = max(1, points - gint(at(rules, "cost"), "tiny_price_points", 1))
        tag_add(tags, "tiny")
    var cost_pct = 0
    var train_pct = 0
    for(glist(identity_of(as_str(at(recipe, "creature")), as_str(at(recipe, "family"))), "bonuses")) b:
        var hit = false
        for(glist(b, "effects")) fx:
            if priced(fx) and reaches(fx, tags):
                hit = true
                let stat = as_str(at(fx, "stat"))
                if has(fx, "pct"):
                    let pct = as_int(at(fx, "pct"))
                    if stat == "cost": cost_pct += pct
                    elif stat == "train_time": train_pct += pct
                    elif stat == "speed": speed = speed * (100 + pct) / 100
                elif starts_with(stat, "armour."): iadd(armour, substring(stat, 7, stat.length - 7), as_int(at(fx, "add")))
                elif starts_with(stat, "bonus."): iadd(bonus, substring(stat, 6, stat.length - 6), as_int(at(fx, "add")))
                else:
                    let add = as_int(at(fx, "add"))
                    if stat == "hp": hp += add
                    elif stat == "attack": attack += add
                    elif stat == "speed": speed += add
                    elif stat == "range": reach += add
                    else: assert false
        if hit: points += as_int(at(b, "price_points"))
    let c = at(rules, "cost")
    var total = (as_int(at(c, "base")) * curve(as_str(at(c, "curve")), points) + 500) / 1000
    let terms = gobj(gobj(c, "roles"), gstr(recipe, "role", ""))
    total = total * gint(terms, "pct", 100) / 100
    total = max(total, gint(terms, "floor", 0))
    if has(terms, "ceiling"): total = min(total, as_int(at(terms, "ceiling")))
    var use_mix = mix
    if has(terms, "mix"): use_mix = shallow_copy(at(terms, "mix"))
    let swaps = gobj(gobj(c, "early"), string(age))
    for(swaps.keys) r, n:
        if has(use_mix, r):
            let to = as_str(swaps.a[n])
            iadd(use_mix, to, iget(use_mix, r))
            erase(use_mix, r)
    total = total * (100 + cost_pct) / 100
    var mix_total = 0
    for(use_mix.a) v: mix_total += as_int(v)
    mix_total = max(1, mix_total)
    let used = filter(lib_resources) r: iget(use_mix, r) > 0
    let cost = jobj()
    var left = total
    for(lib_resources) r: set(cost, r, jint(0))
    for(used) r, n:
        let v = if n == used.length - 1: round10(left) else: round10(total * iget(use_mix, r) / mix_total)
        set(cost, r, jint(v))
        left -= v
    let out = jobj()
    set(out, "hp", jint(max(1, hp)))
    set(out, "attack", jint(if heal > 0: 0 else: max(1, attack)))
    set(out, "heal", jint(heal))
    set(out, "damage", jstr(damage))
    set(out, "armour", armour)
    set(out, "range", jint(reach))
    set(out, "speed", jint(max(4, speed)))
    set(out, "bonus", bonus)
    set(out, "tags", jstrs(sorted_strs(tags)))
    set(out, "points", jint(points))
    set(out, "cost", cost)
    set(out, "train_time", jint(max(3, (as_int(at(c, "train_base")) * curve(as_str(at(c, "train_curve")), points) * (100 + train_pct) / 100 + 500) / 1000)))
    set(out, "pop", jint(gint(terms, "pop", if has_s(tags, "large"): 2 else: 1)))
    set(out, "radius", jint(gint(bstats, "radius", 0)))
    set(out, "sight", jint(sight))
    for(weapon.keys) k, n:
        if not has(out, k): set(out, k, weapon.a[n])
    return out

def find_index(xs:[string], s:string) -> int:
    for(xs) x, n:
        if x == s: return n
    return -1
