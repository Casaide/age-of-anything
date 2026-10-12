extends RefCounted
## The unit card: what a unit is and does, in a few short lines (the panel, the counter quiz).
## "Strong vs" and "weak vs" come from the real bonus damage against the enemy's actual roster:
## a foe is listed when one side's bonus classes match the other's tags.

const MAX_NAMES := 3


## t: a unit type (world.types entry, or anything with name + eval); foes: the enemy's types;
## combat: the rules' combat numbers (world.combat), for what a healer heals.
static func text(t: Dictionary, foes: Array, combat := {}) -> String:
	var e: Dictionary = t.eval
	var reach := "" if int(e.range) <= 1 else ", range %d" % int(e.range)
	var lines := ["Attack %d %s%s    HP %d" % [int(e.attack), e.damage, reach, int(e.hp)]]
	if int(e.get("heal", 0)) > 0:
		lines = [heal_text(e, combat) + "    HP %d" % int(e.hp), "Never fights"]
	var siege := siege_text(e)
	if siege != "":
		lines.append(siege)
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


## The card's first two lines only, for the panel: the rest (bonus, strong and weak vs) shows on
## hover there, so the panel stays one row tall (Dominic).
static func short(t: Dictionary, combat := {}) -> String:
	var lines: PackedStringArray = text(t, [], combat).split("\n")
	return "\n".join(lines.slice(0, 2))


## "Heals 3 hp every 1.5 s, range 2.5" (rules combat heal_*), or a plain line without the rules.
static func heal_text(e: Dictionary, combat: Dictionary) -> String:
	if not combat.has("heal_amount"):
		return "Heals wounded friends"
	var every := int(combat.heal_reload) * 10 / 20   # ticks at 20 Hz, in tenths of a second
	var reach := int(combat.heal_range) / 100   # milli-tiles, in tenths of a tile
	return "Heals %d hp every %s s, range %s" % [int(combat.heal_amount) * int(e.heal), _tenths(every), _tenths(reach)]


## What a siege weapon does beyond a plain attack: "Hits buildings only", "Splash 1.1 tiles,
## friends too", "Not within 3 tiles", "Goes through a line", "Every 5 s". "" for everyone else.
static func siege_text(e: Dictionary) -> String:
	var bits := []
	if e.get("targets", "") == "buildings":
		bits.append("Hits buildings only")
	if int(e.get("splash", 0)) > 0:
		bits.append("Splash %s tiles, friends too" % _tenths(int(e.splash) / 100))
	if int(e.get("pass", 0)) > 0:
		bits.append("Goes through a line")
	if int(e.get("min_range", 0)) > 0:
		bits.append("Not within %d tiles" % int(e.min_range))
	if int(e.get("reload", 0)) > 0:
		bits.append("Every %s s" % _tenths(int(e.reload) / 2))
	return ", ".join(bits)


static func _tenths(n: int) -> String:
	return str(n / 10) if n % 10 == 0 else "%d.%d" % [n / 10, n % 10]


static func _names(names: Array) -> String:
	var shown := ", ".join(names.slice(0, MAX_NAMES))
	return shown + (" +%d more" % (names.size() - MAX_NAMES) if names.size() > MAX_NAMES else "")


static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys
