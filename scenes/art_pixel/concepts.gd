extends "res://scenes/art_pixel/unit_models.gd"
## Concept variations: candidate designs, built with the same kit as the real parts, shown
## side by side on a unit by tests/concept_sheet.gd so Dominic can pick before anything is
## built for the game. Nothing here is used in play. Ids are "concept.<name>".
## Head gear sits on the head's "top" socket: the face looks along +x, the skull's centre is
## about (0.2, -5.8, 0) from the top, the jaw about (1.3, -8.4, 0).

const HAIR := Color("#5a3820")
const RED_HAIR := Color("#8a4a22")


func _concept_current_cap(c: Dictionary) -> Dictionary:
	return _helm_cap(c)


func _concept_current_horned(c: Dictionary) -> Dictionary:
	return _helm_horned(c)


func _concept_current_galea(c: Dictionary) -> Dictionary:
	return _helm_galea(c)


# ------------------------------------------------------------------ Roman, age 1 (recruits)

## A: bare-headed, hair cropped short; the soldier is told by the shield and cloak.
func _concept_roman_bare(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(dome(Vector3(4.7, 3.2, 4.5), surf("mane", HAIR, 2.0), Vector3(-0.3, -4.2, 0)))
	return {"node": n}


## B: a team-colour band tied round cropped hair.
func _concept_roman_fillet(c: Dictionary) -> Dictionary:
	var n: Node3D = _concept_roman_bare(c).node
	n.add_child(ring(4.5, 5.2, plain(c.team), Vector3(0.2, -3.9, 0), Vector3(0, 0, -8)))
	return {"node": n}


## C: a felt pileus, the rounded cone of a common soldier's cap.
func _concept_roman_pileus(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#ddd0b2"), 3.0)
	n.add_child(cone(2.4, 5.0, 4.4, felt, Vector3(-0.2, -1.6, 0)))
	n.add_child(blob(Vector3(2.5, 1.4, 2.5), felt, Vector3(-0.3, 0.6, 0)))
	n.add_child(ring(4.7, 5.3, surf("cloth", Color("#b8a888"), 2.0), Vector3(0, -3.8, 0)))
	return {"node": n}


## D: a leather cap with cheek flaps and a short neck lip: the galea's outline in leather,
## so age 2's iron helmet reads as the same soldier promoted.
func _concept_roman_leather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(1.0, 0.95, 0.9), 2.0)
	n.add_child(dome(Vector3(5.0, 4.6, 4.8), leather, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.3, surf("leather", Color(0.7, 0.6, 0.5), 2.0), Vector3(0.3, -3.0, 0)))
	n.add_child(blob(Vector3(2.6, 0.5, 4.4), leather, Vector3(-3.8, -4.0, 0), Vector3(0, 0, -25)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 2.4, 0.5), leather, Vector3(2.0, -5.6, 4.3 * side)))
	return {"node": n}


# ------------------------------------------------------------------ Viking, age 1 (and the horns question)

func _beard(n: Node3D, colour: Color, long := true) -> void:
	var hair := surf("mane", colour, 2.0)
	n.add_child(blob(Vector3(2.4, 3.0 if long else 2.0, 3.4), hair, Vector3(2.2, -9.4 if long else -8.8, 0)))
	n.add_child(blob(Vector3(1.4, 0.6, 2.4), hair, Vector3(3.8, -7.4, 0)))   # moustache


func _long_hair(n: Node3D, colour: Color) -> void:
	var hair := surf("mane", colour, 2.0)
	n.add_child(blob(Vector3(3.2, 5.0, 4.6), hair, Vector3(-2.4, -6.2, 0)))
	for side in [1, -1]:   # braids over the shoulders
		n.add_child(rod(Vector3(-1.0, -7.0, 4.2 * side), Vector3(-0.4, -12.0, 4.6 * side), 0.9, 0.6, hair))


## A: bare head, long hair in braids, a full beard: the silhouette does the work.
func _concept_viking_bare(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(dome(Vector3(4.8, 3.4, 4.6), surf("mane", RED_HAIR, 2.0), Vector3(-0.3, -4.0, 0)))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## B: a wool hood, pointed, falling over the shoulders, with a beard.
func _concept_viking_hood(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wool := surf("cloth", Color("#7e6e50"), 3.0)
	n.add_child(dome(Vector3(5.6, 5.6, 5.4), wool, Vector3(-0.4, -4.0, 0)))
	n.add_child(blob(Vector3(4.0, 3.6, 5.6), wool, Vector3(-2.2, -7.6, 0)))
	n.add_child(cone(0.2, 1.6, 4.0, wool, Vector3(-3.2, 1.0, 0), Vector3(0, 0, 50)))
	_beard(n, RED_HAIR)
	return {"node": n}


## C: a round fur cap with a thick brim, and a beard.
func _concept_viking_fur(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color("#7a5a3c"), 2.0)
	n.add_child(blob(Vector3(5.0, 3.4, 4.9), surf("leather", Color(0.9, 0.85, 0.8), 2.0), Vector3(-0.2, -2.6, 0)))
	n.add_child(ring(4.4, 6.0, fur, Vector3(0, -3.6, 0)))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## D: a plain conical iron cap with a nose guard (no horns), and a beard.
func _concept_viking_conical(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(cone(0.3, 5.1, 5.6, iron, Vector3(0, -1.2, 0)))
	n.add_child(ring(4.8, 5.4, iron, Vector3(0, -3.8, 0)))
	n.add_child(rod(Vector3(5.0, -3.6, 0), Vector3(5.5, -7.0, 0), 0.6, 0.5, iron))
	_long_hair(n, RED_HAIR)
	_beard(n, RED_HAIR)
	return {"node": n}


## E (later ages): a rounded iron helmet with a spectacle guard round the eyes.
func _concept_viking_spectacle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.4, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.8, 5.4, iron, Vector3(0, -3.6, 0)))
	n.add_child(rod(Vector3(-5, -1.0, 0), Vector3(5, -1.0, 0), 0.5, 0.5, iron))
	for side in [1, -1]:
		n.add_child(ring(0.9, 1.5, iron, Vector3(4.6, -5.4, 1.7 * side), Vector3(0, 0, 90)))
	_beard(n, RED_HAIR)
	return {"node": n}


# ------------------------------------------------------------------ Greek, age 1

## A: a conical felt pilos.
func _concept_greek_pilos(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#c8a878"), 3.0)
	n.add_child(cone(0.5, 5.0, 6.6, felt, Vector3(-0.2, -0.6, 0)))
	n.add_child(ring(4.7, 5.3, surf("cloth", Color("#a08458"), 2.0), Vector3(0, -3.8, 0)))
	return {"node": n}


## B: a wide-brimmed petasos sun hat.
func _concept_greek_petasos(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("cloth", Color("#d8c49a"), 3.0)
	n.add_child(dome(Vector3(4.9, 3.4, 4.7), felt, Vector3(0, -3.2, 0)))
	n.add_child(cone(7.4, 7.6, 0.5, felt, Vector3(0, -3.2, 0), Vector3(0, 0, -6), 28))
	return {"node": n}
