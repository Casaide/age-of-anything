extends RefCounted
## Recipe -> stats, tags and cost. Balance comes from here: every part carries
## points, and cost grows superlinearly with points, so a 10ft spider is
## possible but expensive. A part's `price_points` (when it has them) set its price
## apart from the budget `points` the generator spends. Later this gets a "price by
## simulated fights" pass.
##
## Integer maths only. The superlinear cost curve is a fixed-point table
## (data/cost_curves.json, made by tests/gen_cost_curve.gd), so costs are
## bit-exact on every machine. Stats are never part of the race key.

const Identity := preload("res://src/identity.gd")

const GIANT_POINTS := 6
const DEFAULT_MIX := {"food": 50, "wood": 50}
const MOUNT_MIX := {"food": 70, "wood": 30}


## `age`: the age the unit is trained in (0: unknown), for what that age can pay in (rules.cost.early).
static func evaluate(recipe: Dictionary, lib, rules: Dictionary, age := 0) -> Dictionary:
	var body: Dictionary = lib.part(recipe.body)
	var gear := [lib.part(recipe.head)] if recipe.head != "" else []   # an engine has no head of its own
	for slot in recipe.parts:
		gear.append(lib.part(recipe.parts[slot]))
	for slot in recipe.get("kit", {}):   # a hero's kit under its look (src/heroes.gd): priced and fought with, not drawn
		gear.append(lib.part(recipe.kit[slot]))

	var hp := int(body.stats.get("hp", 0))
	var armour := {"melee": 0, "pierce": 0}   # armour per class (see rules.combat)
	_add_classes(armour, body.stats.get("armour", {}))
	var speed := int(body.stats.get("speed", 10))
	var attack := 0
	var heal := 0   # healers (parts' "heal" stat): they mend, never strike, and are priced by their kit's points
	var reach := 1
	var bonus := {}
	_add_classes(bonus, body.stats.get("bonus", {}))
	var damage := "melee"
	# Siege weapons (milestone 13): their own reload (ticks), a minimum range (tiles), splash and
	# pass-through (milli-tiles), and what they go for ("buildings": rams). 0 / "": the rules' usual.
	# The great sling unpacks (ticks standing before it throws) and packs (ticks before it moves);
	# the sapper's charge blasts (milli-tiles round it, a wall's share of hp it takes outright).
	var weapon := {"reload": 0, "min_range": 0, "splash": 0, "pass": 0, "targets": "", "unpack": 0, "pack": 0, "blast": 0, "blast_line_pct": 0}
	var tags := {}
	var points := _price(body)
	var mix := {}
	_add_mix(mix, body, DEFAULT_MIX)
	for t in body.tags:
		tags[t] = true

	for p in gear:
		var s: Dictionary = p.stats
		hp += int(s.get("hp", 0))
		_add_classes(armour, s.get("armour", {}))
		speed += int(s.get("speed", 0))
		attack += int(s.get("attack", 0))
		heal += int(s.get("heal", 0))
		reach = maxi(reach, int(s.get("range", 1)))
		if s.has("damage"):
			damage = s.damage
		for k in weapon:
			if s.has(k):
				weapon[k] = s[k] if k == "targets" else int(s[k])
		_add_classes(bonus, s.get("bonus", {}))
		for t in p.tags:
			tags[t] = true
		points += _price(p)
		_add_mix(mix, p, DEFAULT_MIX)

	if recipe.has("mount"):
		var mc: Dictionary = lib.creatures[recipe.mount.creature]
		# A fused mount (a centaur's horse half) is priced as its own body (fused_body), as it's drawn (unit_view.gd).
		var mount_body: Dictionary = lib.part(mc.get("fused_body", mc.body) if recipe.mount.get("fused", false) else mc.get("mount_body", mc.body))
		var ms: Dictionary = mount_body.stats
		hp += int(ms.get("hp", 0))
		_add_classes(armour, ms.get("armour", {}))
		_add_classes(bonus, ms.get("bonus", {}))
		speed += int(ms.get("speed", 10)) - int(body.stats.get("speed", 10))
		points += _price(mount_body)
		_add_mix(mix, mount_body, MOUNT_MIX)
		for t in mount_body.tags:
			if t != "mount":
				tags[t] = true
		for t in mount_body.get("rider_loses", []):   # the rider's tags the mount takes away: cavalry isn't infantry
			tags.erase(t)
		for slot in recipe.mount.parts:
			var mp: Dictionary = lib.part(recipe.mount.parts[slot])
			hp += int(mp.stats.get("hp", 0))
			speed += int(mp.stats.get("speed", 0))
			points += _price(mp)
			_add_mix(mix, mp, MOUNT_MIX)
			for t in mp.tags:
				tags[t] = true
		tags["mounted"] = true
		if mount_body.get("large", true):   # (a centaur's own horse half isn't a big beast under a rider: body.pony_fused)
			tags["large"] = true

	# The line's own counters and stats (rules roster "bonus" and "stats": the swordsman's counters, the
	# scout's pace and sight; "stats_on_foot" for one with nothing to ride), whatever it holds, and a
	# unique unit's theme (data/uniques.json), each with the price_points they add.
	var extra := []
	var look_only := false   # (the hero line: its size is its look, not a giant's body)
	for sd in rules.roster:
		if sd.slot == recipe.get("slot", ""):
			look_only = sd.get("size_is_look", false)
			extra.append(sd)
			if not recipe.has("mount") and sd.has("stats_on_foot"):
				extra.append({"stats": sd.stats_on_foot})
	if recipe.has("unique"):
		extra.append(lib.uniques[recipe.unique])
	var sight := 0   # tiles over the rules' unit sight (fog.gd)
	for x in extra:
		_add_classes(bonus, x.get("bonus", {}))
		points += int(x.get("price_points", 0))
		var st: Dictionary = x.get("stats", {})
		_add_classes(armour, st.get("armour", {}))
		hp += int(st.get("hp", 0))
		attack += int(st.get("attack", 0))
		speed += int(st.get("speed", 0))
		reach += int(st.get("range", 0))
		sight += int(st.get("sight", 0))
		if st.has("reload"):
			weapon.reload = int(st.reload)
	for x in extra:   # `stats_pct`: hit points and attack in percent of what the unit has by then (the hero line: as tough for a rat as for a centaur)
		var sp: Dictionary = x.get("stats_pct", {})
		hp = hp * int(sp.get("hp", 100)) / 100
		attack = attack * int(sp.get("attack", 100)) / 100

	var scale := 100 if look_only else int(recipe.scale)
	if scale >= 140:
		hp *= 2
		attack += 3
		armour.pierce = int(armour.pierce) + 3   # big hides shrug off arrows (the genre's war elephants)
		speed -= 2
		points += GIANT_POINTS
		tags["large"] = true
		tags["giant"] = true
	elif scale <= 85:
		hp = hp * 8 / 10
		speed += 1
		points = maxi(1, points - 1)
		tags["tiny"] = true

	# The race's bonuses on unit stats (milestone 14, src/identity.gd: from its creature's group, its
	# creature and its culture), before the price: each bonus that reaches the unit adds its price_points.
	var cost_pct := 0
	var train_pct := 0
	var stats := {"hp": hp, "attack": attack, "speed": speed, "range": reach}
	var tags_now: Array = tags.keys()
	for b in Identity.of(recipe.creature, recipe.family).bonuses:
		var hit := false
		for fx in b.effects:
			if not Identity.priced(fx) or not Identity.reaches(fx, tags_now):
				continue
			hit = true
			if fx.has("pct"):
				match fx.stat:
					"cost": cost_pct += int(fx.pct)
					"train_time": train_pct += int(fx.pct)
					"speed": stats.speed = int(stats.speed) * (100 + int(fx.pct)) / 100
			elif fx.stat.begins_with("armour."):
				_add_classes(armour, {fx.stat.trim_prefix("armour."): int(fx.add)})
			elif fx.stat.begins_with("bonus."):
				_add_classes(bonus, {fx.stat.trim_prefix("bonus."): int(fx.add)})
			else:
				stats[fx.stat] = int(stats[fx.stat]) + int(fx.add)
		if hit:
			points += int(b.price_points)
	hp = stats.hp
	attack = stats.attack
	speed = stats.speed
	reach = stats["range"]

	var c: Dictionary = rules.cost
	var total: int = (int(c.base) * lib.curve(c.curve, points) + 500) / 1000
	# A role can have its own price terms (rules.cost.roles): a pct of the base price, a floor and a ceiling,
	# and a mix that replaces the parts' own (workers cost food, between the floor and the ceiling).
	var terms: Dictionary = c.get("roles", {}).get(recipe.get("role", ""), {})
	total = total * int(terms.get("pct", 100)) / 100   # a role priced off the common base (siege kept where it was)
	total = maxi(total, int(terms.get("floor", 0)))
	if terms.has("ceiling"):
		total = mini(total, int(terms.ceiling))   # a big body's worker (a centaur) dearer, not a horseman's price (D-078)
	if terms.has("mix"):
		mix = terms.mix.duplicate()   # every line its own mix (D-149): the parts set the total, the line what it's paid in
	var swaps: Dictionary = c.get("early", {}).get(str(age), {})
	for r in swaps:   # a resource this age can't gather yet goes on another (age 1: gold is food)
		if mix.has(r):
			mix[swaps[r]] = int(mix.get(swaps[r], 0)) + int(mix[r])
			mix.erase(r)
	total = total * (100 + cost_pct) / 100
	# Split the total over the resources in the mix, in the fixed resource order; the last
	# one used takes the remainder (so food/wood splits come out as they always did).
	var mix_total := 0
	for k in mix:
		mix_total += int(mix[k])
	mix_total = maxi(1, mix_total)
	var used: Array = lib.resources.filter(func(r): return int(mix.get(r, 0)) > 0)
	var cost := {}
	var left := total
	for r in lib.resources:
		cost[r] = 0
	for n in used.size():
		var r: String = used[n]
		cost[r] = _round10(left) if n == used.size() - 1 else _round10(total * int(mix[r]) / mix_total)
		left -= cost[r]

	var tag_list := tags.keys()
	tag_list.sort()
	var out := {
		"hp": maxi(1, hp),
		"attack": 0 if heal > 0 else maxi(1, attack),
		"heal": heal,
		"damage": damage,
		"armour": armour,
		"range": reach,
		"speed": maxi(4, speed),
		"bonus": bonus,
		"tags": tag_list,
		"points": points,
		"cost": cost,
		"train_time": maxi(3, (int(c.train_base) * lib.curve(c.train_curve, points) * (100 + train_pct) / 100 + 500) / 1000),
		"pop": int(terms.get("pop", 2 if tags.has("large") else 1)),   # a role can set its own (a worker is one head, even a centaur)
		"radius": int(body.stats.get("radius", 0)),
		"sight": sight,   # a body's own size in milli-tiles (engines); 0: by scale
	}
	out.merge(weapon)
	return out


## Sum per-class numbers (armour or bonus), e.g. {"melee": 1, "pierce": 2, "large": 3}.
static func _add_classes(into: Dictionary, add: Dictionary) -> void:
	for k in add:
		into[k] = int(into.get(k, 0)) + int(add[k])


static func _add_mix(mix: Dictionary, p: Dictionary, fallback: Dictionary) -> void:
	var m: Dictionary = p.get("cost_mix", fallback)
	var pts := int(p.points)
	for k in m:
		mix[k] = int(mix.get(k, 0)) + int(m[k]) * pts


## The points a part adds to the price: `price_points` when the part has them (what it is
## worth in a fight, measured by tests/balance.gd and tests/mass_battle.gd), else its
## `points` (what the generator's budget spends, so changing a price never changes a race).
static func _price(p: Dictionary) -> int:
	return int(p.get("price_points", p.points))


static func _round10(n: int) -> int:   # prices in tens: easy to read and compare (D-149)
	return maxi(0, (n + 5) / 10 * 10)
