extends RefCounted
## Recipe -> stats, tags and cost. Balance comes from here: every part carries
## points, and cost grows superlinearly with points, so a 10ft spider is
## possible but expensive. Later this gets a "price by simulated fights" pass.
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
	var reach := 1
	var bonus := {}
	_add_classes(bonus, body.stats.get("bonus", {}))
	var damage := "melee"
	var tags := {}
	var points := int(body.points)
	var mix := {"food": 0, "wood": 0}
	_add_mix(mix, body, DEFAULT_MIX)
	for t in body.tags:
		tags[t] = true

	for p in gear:
		var s: Dictionary = p.stats
		hp += int(s.get("hp", 0))
		_add_classes(armour, s.get("armour", {}))
		speed += int(s.get("speed", 0))
		attack += int(s.get("attack", 0))
		reach = maxi(reach, int(s.get("range", 1)))
		if s.has("damage"):
			damage = s.damage
		_add_classes(bonus, s.get("bonus", {}))
		for t in p.tags:
			tags[t] = true
		points += int(p.points)
		_add_mix(mix, p, DEFAULT_MIX)

	if recipe.has("mount"):
		var mount_body: Dictionary = lib.part(lib.creatures[recipe.mount.creature].body)
		var ms: Dictionary = mount_body.stats
		hp += int(ms.get("hp", 0))
		_add_classes(armour, ms.get("armour", {}))
		_add_classes(bonus, ms.get("bonus", {}))
		speed += int(ms.get("speed", 10)) - int(body.stats.get("speed", 10))
		points += int(mount_body.points)
		_add_mix(mix, mount_body, MOUNT_MIX)
		for t in mount_body.tags:
			if t != "mount":
				tags[t] = true
		for slot in recipe.mount.parts:
			var mp: Dictionary = lib.part(recipe.mount.parts[slot])
			hp += int(mp.stats.get("hp", 0))
			speed += int(mp.stats.get("speed", 0))
			points += int(mp.points)
			_add_mix(mix, mp, MOUNT_MIX)
			for t in mp.tags:
				tags[t] = true
		tags["mounted"] = true
		tags["large"] = true

	var scale := int(recipe.scale)
	if scale >= 140:
		hp *= 2
		attack += 3
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
	total = total * int(econ.get("cost_pct", 100)) / 100
	var mix_total := maxi(1, mix.food + mix.wood)
	var food := _round5(total * mix.food / mix_total)
	var wood := _round5(total - food)

	var tag_list := tags.keys()
	tag_list.sort()
	return {
		"hp": maxi(1, hp),
		"attack": maxi(1, attack),
		"damage": damage,
		"armour": armour,
		"range": reach,
		"speed": maxi(4, speed),
		"bonus": bonus,
		"tags": tag_list,
		"points": points,
		"cost": {"food": food, "wood": wood},
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
	mix.food += int(m.food) * pts
	mix.wood += int(m.wood) * pts


static func _round5(n: int) -> int:
	return maxi(0, (n + 2) / 5 * 5)
