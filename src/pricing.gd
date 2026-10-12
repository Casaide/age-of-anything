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

const GIANT_POINTS := 6
const DEFAULT_MIX := {"food": 50, "wood": 50}
const MOUNT_MIX := {"food": 70, "wood": 30}


static func evaluate(recipe: Dictionary, lib, rules: Dictionary) -> Dictionary:
	var body: Dictionary = lib.part(recipe.body)
	var gear := [lib.part(recipe.head)]
	for slot in recipe.parts:
		gear.append(lib.part(recipe.parts[slot]))

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
		_add_classes(bonus, s.get("bonus", {}))
		for t in p.tags:
			tags[t] = true
		points += _price(p)
		_add_mix(mix, p, DEFAULT_MIX)

	if recipe.has("mount"):
		var mount_body: Dictionary = lib.part(lib.creatures[recipe.mount.creature].get("mount_body", lib.creatures[recipe.mount.creature].body))
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
		tags["large"] = true

	var scale := int(recipe.scale)
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

	var c: Dictionary = rules.cost
	var econ: Dictionary = lib.creatures[recipe.creature].get("economy", {})
	var total: int = (int(c.base) * lib.curve(c.curve, points) + 500) / 1000
	# A role can have its own price terms (rules.cost.roles): a floor, and a mix that
	# replaces the parts' own (workers cost food, and at least the floor).
	var terms: Dictionary = c.get("roles", {}).get(recipe.get("role", ""), {})
	total = maxi(total, int(terms.get("floor", 0)))
	if terms.has("mix"):
		mix = terms.mix.duplicate()
	total = total * int(econ.get("cost_pct", 100)) / 100
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
		cost[r] = _round5(left) if n == used.size() - 1 else _round5(total * int(mix[r]) / mix_total)
		left -= cost[r]

	var tag_list := tags.keys()
	tag_list.sort()
	return {
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
		"train_time": maxi(3, (int(c.train_base) * lib.curve(c.train_curve, points) * int(econ.get("train_time_pct", 100)) / 100 + 500) / 1000),
		"pop": 2 if tags.has("large") else 1,
	}


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


static func _round5(n: int) -> int:
	return maxi(0, (n + 2) / 5 * 5)
