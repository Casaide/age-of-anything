extends "res://scenes/art_pixel/siege_models.gd"
## Siege engine concepts (milestone 13, D-080: options first), for the concept sheets
## (tests/siege_concept_sheet.gd, _r2.gd, _r3.gd, _r4.gd). The builders live in siege_models.gd with the
## picked engines in play; this only keeps the concept rounds' ids.
## Ids: "siege.<engine>.<direction>.<family>", e.g. "siege.ram.a.timber":
##   engine     ram, catapult, bolt; tower (milestone 16's siege tower, round T1: hide, open, belfry, beast)
##   direction  a: the engine alone (its crew hidden or implied, it moves as one thing)
##              b: the crew shows (the race's own units push, pull or aim it: the sockets
##                 "crew0".."crew3" say where they stand; the forest ram is pushed by a beetle)
##              round 2: c (crewed), shed, ridden, led, mount (see ROUND2_SCALE)
##              round 3 (the frogs): reed, beast, river (see ROUND3); round 4: snail, toad, turtle, haul
##   family     timber (every human culture, trimmed in its cloth), swamp (frogs), sewer (rats),
##              forest (beetles), spooky (spiders), junk (round 2's rats), frog (round 3)


func has(id: String) -> bool:
	return id.begins_with("siege.") or super.has(id)


func build(id: String, colours: Dictionary) -> Dictionary:
	if not id.begins_with("siege.") or _engine_id(id):
		return super.build(id, colours)
	var p := id.split(".")
	var s := _style(p[3], colours)
	# The engines are built at a soldier's scale and grown to their size here (sockets too).
	# Round 2 (crewed, D-118) grows them to their crew: a ram's log at chest height, a
	# catapult's frame to the crew's shoulder; frog engines more, for the crouched frog.
	var k: float = {"ram": 1.0, "catapult": 1.5, "bolt": 1.6, "tower": 1.0}[p[1]]
	if p[2] in ROUND2_SCALE:
		k = ROUND2_SCALE[p[2]][p[1]] * (1.25 if p[3] == "swamp" else 1.0)
	if p[2] in ROUND3 or p[2] in ROUND4 or p[2] in ROUND5:   # round 3 and 4's frog engines, and the siege towers (milestone 16), are built at their true size
		k = 1.0
	return _scaled(call("_%s_%s" % [p[1], p[2]], s, colours), k)
