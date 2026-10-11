extends RefCounted
## The unit card: what a unit is and does, in a few short lines (the panel, the counter quiz).
## "Strong vs" and "weak vs" come from the real bonus damage against the enemy's actual roster:
## a foe is listed when one side's bonus classes match the other's tags.

const MAX_NAMES := 3


## t: a unit type (world.types entry, or anything with name + eval); foes: the enemy's types.
static func text(t: Dictionary, foes: Array) -> String:
	var e: Dictionary = t.eval
	var reach := "" if int(e.range) <= 1 else ", range %d" % int(e.range)
	var lines := ["Attack %d %s%s    HP %d" % [int(e.attack), e.damage, reach, int(e.hp)]]
	var armour := "Armour %d melee / %d pierce" % [int(e.armour.get("melee", 0)), int(e.armour.get("pierce", 0))]
	for k in _sorted_keys(e.armour):
		if k != "melee" and k != "pierce" and int(e.armour[k]) != 0:
			armour += ", %+d vs %s" % [int(e.armour[k]), k]
	lines.append(armour + "    Speed %d" % int(e.speed))
	var bonus := []
	for k in _sorted_keys(e.bonus):
		if int(e.bonus[k]) > 0:
			bonus.append("+%d vs %s" % [int(e.bonus[k]), k])
	if not bonus.is_empty():
		lines.append("Bonus " + ", ".join(bonus))
	var strong := []
	var weak := []
	for f in foes:
		var fe: Dictionary = f.eval
		if fe.tags.any(func(tag): return int(e.bonus.get(tag, 0)) > 0) and not f.name in strong:
			strong.append(f.name)
		if e.tags.any(func(tag): return int(fe.bonus.get(tag, 0)) > 0) and not f.name in weak:
			weak.append(f.name)
	if not strong.is_empty():
		lines.append("Strong vs: " + _names(strong))
	if not weak.is_empty():
		lines.append("Weak vs: " + _names(weak))
	return "\n".join(lines)


static func _names(names: Array) -> String:
	var shown := ", ".join(names.slice(0, MAX_NAMES))
	return shown + (" +%d more" % (names.size() - MAX_NAMES) if names.size() > MAX_NAMES else "")


static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys
