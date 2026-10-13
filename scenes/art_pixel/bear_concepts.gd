extends "res://scenes/art_pixel/unit_models.gd"
## Bear concepts (round B1, 2026-10-13): gear made for the creature kit's bear head, staged with
## data/later/bears.json (its "models"), shown by tests/sheets/bears_*.json. Nothing here is in play.
## Head gear sits on the bear head's "top" socket, scaled by its gear_scale (0.9): in this frame the
## skull's centre is about (0.2, -6.0, 0), radius ~4.8; the eyes about (4.2, -5.3, +-2.3) under a brow
## whose top is at -4.2; the ears at (-1.1, -2.4, +-3.2).


## A bronze helmet for a bear: a deep bowl over the skull with two round ear cups standing up where
## the ears are (so it still reads as a bear's head), cheek guards behind the eyes leaving the muzzle
## free, a neck guard, and a tall team crest on a stand (the Attic helmet's, for the dignity).
func _helm_bear_crest(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var bright := surf("bronze", Color(1.15, 1.1, 0.95), 2.0)
	n.add_child(dome(Vector3(4.9, 4.5, 4.8), bronze, Vector3(0.0, -3.5, 0)))
	n.add_child(ring(4.7, 5.3, bright, Vector3(0.0, -3.4, 0)))   # the brow band
	n.add_child(blob(Vector3(1.8, 0.5, 4.0), bronze, Vector3(4.6, -2.8, 0), Vector3(0, 0, -14)))   # the brow peak
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.3, 1.6, 1.0), bright, Vector3(-0.8, 0.0, 3.5 * side), Vector3(18 * side, 0, 0)))   # an ear cup
		n.add_child(blob(Vector3(1.8, 2.8, 0.6), bronze, Vector3(0.2, -5.8, 4.7 * side), Vector3(0, 0, 10)))   # a cheek guard
	n.add_child(blob(Vector3(3.0, 2.8, 4.6), bronze, Vector3(-3.4, -5.4, 0)))   # the neck guard
	n.add_child(rod(Vector3(-0.2, 1.0, 0), Vector3(-0.5, 4.0, 0), 0.55, 0.55, bronze))   # the crest stand
	crest(n, c.team, Vector3(-1.5, 4.4, 0), 13.0, 7.0)
	return {"node": n}


## Round B2: an open-faced bronze cap for a bear, so the small soldiers show more bear. A shallower
## bowl set a little back (the brow, eyes and the whole face bare), no cheek guards, the bear's own
## round ears standing out through holes in the bowl (fur in the wearer's coat, each in a bronze
## collar), a short neck guard and the same tall team crest.
func _helm_bear_open(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var bright := surf("bronze", Color(1.15, 1.1, 0.95), 2.0)
	var fur := surf("hide", c.skin, 4.0)
	var ear_in := plain(Color("#3a2a24"))
	n.add_child(dome(Vector3(4.8, 4.2, 4.7), bronze, Vector3(-0.4, -3.2, 0)))
	n.add_child(ring(4.6, 5.1, bright, Vector3(-0.4, -3.1, 0)))   # the brow band
	for side in [1, -1]:
		var at := Vector3(-0.9, 1.0, 3.5 * side)
		n.add_child(blob(Vector3(1.6, 0.5, 1.5), bright, at + Vector3(0, -1.2, 0), Vector3(22 * side, 0, 0)))   # the ear hole's collar
		n.add_child(blob(Vector3(1.3, 2.0, 1.7), fur, at, Vector3(22 * side, 0, -10)))   # the ear, out through it
		n.add_child(blob(Vector3(0.6, 1.25, 1.0), ear_in, at + Vector3(0.75, 0.0, 0.15 * side), Vector3(22 * side, 0, -10)))
	n.add_child(blob(Vector3(2.6, 2.2, 4.2), bronze, Vector3(-3.6, -4.8, 0)))   # the neck guard
	n.add_child(rod(Vector3(-0.4, 1.0, 0), Vector3(-0.7, 4.0, 0), 0.55, 0.55, bronze))   # the crest stand
	crest(n, c.team, Vector3(-1.7, 4.4, 0), 13.0, 7.0)
	return {"node": n}


## Round B3 (D-126: helmets by rank): the same two helmets at the later ages, so a bear line keeps
## its own helmet as it ages (better armour in the data, the same model).
func _helm_bear_open_2(c: Dictionary) -> Dictionary:
	return _helm_bear_open(c)


func _helm_bear_open_3(c: Dictionary) -> Dictionary:
	return _helm_bear_open(c)


func _helm_bear_crest_3(c: Dictionary) -> Dictionary:
	return _helm_bear_crest(c)
