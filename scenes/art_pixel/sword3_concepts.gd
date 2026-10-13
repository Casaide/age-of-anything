extends "res://scenes/art_pixel/unit_models.gd"
## The swordsman's age-3 kit, concept round S3 (2026-10-13, Dominic: "Swords looking great, need
## age 3"). The iron sword is the only tier-3 blade and it's royal (knight) kit, so the swamp,
## forest, hellenic, steppe, spooky and han swordsmen stay as they were in age 3. Two weapons per
## culture in its own look (and a helmet where it reads better), held in the swordsman's "low" hold
## like every sword: the origin is the grip, the blade runs along `TIP` (up and a little forward).
## Dominic picked (D-125) hellenic B, steppe B, han B, swamp B, forest A and spooky B: those are in
## unit_models.gd now (the helpers too); the options left here are the ones not picked, kept for later
## (the reed saw as a raider or unique weapon). Nothing here is in play.
## Every option is longer, brighter or heavier than the age-2 bronze sword (14.4 long, 1.5 wide,
## dull bronze), so the step reads at game scale.

const TIP := Vector3(3, 14, 0)        # the bronze sword's line (the hold is the same)
const OBSIDIAN := Color("#2c2834")


# ------------------------------------------------------------------ hellenic

## A: the kopis, a heavy forward-curved chopper widening to a belly near the tip; bright iron,
## bronze fittings.
func _weapon_s3_kopis(c: Dictionary) -> Dictionary:
	var pts := [Vector2(0, -0.9), Vector2(5, -1.0), Vector2(9.5, -1.7), Vector2(13.5, -2.5), Vector2(16.2, -2.0),
		Vector2(17.6, -0.2), Vector2(16.6, 1.0), Vector2(12, 0.5), Vector2(7, 0.7), Vector2(3, 1.2), Vector2(0, 1.0)]
	var n := _sword(pts, TIP, _bright_iron(), surf("bronze", Color(1.2, 1.1, 0.85), 2.0))
	return {"node": n}


# ------------------------------------------------------------------ steppe

## A: a long slim sabre, bright iron, curving back from the hand, a disc guard and a team tassel.
func _weapon_s3_sabre(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(18.0, 2.6, [1.6, 1.5, 1.35, 1.0, 0.0], 0.6), 0.7, _bright_iron(), Vector3.ZERO, ang))
	n.add_child(cone(1.6, 1.6, 0.5, surf("bronze", Color.WHITE, 2.0), Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang) - 90)))
	grip(n, d, surf("leather", Color.WHITE, 2.0), surf("iron", Color.WHITE, 2.0))
	tassel(n, d, surf("cloth", c.team, 2.0))
	return {"node": n}


# ------------------------------------------------------------------ swamp (frogs)

## A: a reed saw: a long flattened reed blade, pale and bright, with black obsidian teeth set
## along its edge and a knapped obsidian point, bound to the grip with cord.
func _weapon_s3_reed_saw(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	var reed := surf("reed_stalk", Color(1.25, 1.2, 0.9), 3.0)
	n.add_child(blade(curved(15.0, 1.0, [1.3, 1.6, 1.6, 1.3]), 0.9, reed, Vector3.ZERO, ang))
	var glass := surf("iron", OBSIDIAN, 1.5)
	var across := Vector3(-d.y, d.x, 0)
	for k in 6:   # the teeth along the front edge, pointing to the tip
		var at := d * (3.0 + k * 2.0) - across * (1.3 + 0.2)
		n.add_child(blade([Vector2(0, -0.7), Vector2(1.6, 0.0), Vector2(0, 0.7)], 0.4, glass, at - across * 0.3, ang - 0.6))
	n.add_child(blade([Vector2(0, -1.3), Vector2(3.4, 0), Vector2(0, 1.3)], 0.6, glass, d * 14.6 + across * 0.25, ang + 0.05))   # the point
	for k in 3:
		n.add_child(ring(0.7, 1.1, surf("cloth", Color("#8a7a4a"), 2.0), d * (0.8 + k * 0.7), Vector3(0, 0, rad_to_deg(ang) - 90)))
	grip(n, d, surf("reed_stalk", Color.WHITE, 2.0), surf("rock", Color(0.9, 0.9, 0.85), 2.0), 2.6)
	return {"node": n}


# ------------------------------------------------------------------ forest (beetles)

## B: a thorn sword: a long bramble stem with big pale thorns down both sides, a thorn point and
## a leaf at the hand.
func _weapon_s3_thorn(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	var stem := surf("wood_grain", Color("#b0603a"), 3.0)   # a red-brown bramble: green vanished on the grass
	n.add_child(rod(Vector3.ZERO, d * 15.5, 1.3, 0.6, stem))
	var thorn := surf("bone", Color(1.1, 1.05, 0.9), 2.0)
	var across := Vector3(-d.y, d.x, 0)
	for k in 6:
		var t := 2.5 + k * 2.2
		var side := 1 if k % 2 == 0 else -1
		n.add_child(blade([Vector2(0, -0.8), Vector2(3.6, 0.0), Vector2(0, 0.8)], 0.6, thorn, d * t + across * side * 0.8, ang + 0.9 * side))
	n.add_child(blade([Vector2(0, -0.7), Vector2(3.4, 0), Vector2(0, 0.7)], 0.6, thorn, d * 15.2, ang))
	n.add_child(blade([Vector2(0, 0), Vector2(1.6, -1.4), Vector2(4.0, -1.6), Vector2(5.0, 0), Vector2(3.0, 1.0)], 0.3,
		surf("leaf", Color.WHITE, 2.0), d * 0.4, ang - 1.6))   # the leaf at the hand
	grip(n, d, surf("leather", Color.WHITE, 2.0), stem)
	return {"node": n}


# ------------------------------------------------------------------ spooky (spiders)

## A: a bone scythe-sword: a long pale blade sweeping back into a hook, a grip of vertebrae.
func _weapon_s3_bone_scythe(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	var bone := surf("bone", Color(1.2, 1.18, 1.1), 2.5)
	n.add_child(blade(curved(17.0, 5.5, [1.0, 1.2, 1.5, 1.3, 0.0], 0.5, 18), 0.8, bone, Vector3.ZERO, ang))
	for k in 3:   # vertebrae down the grip
		n.add_child(blob(Vector3(0.9, 0.6, 0.9), bone, -d * (0.6 + k * 1.1)))
	n.add_child(blob(Vector3(1.3, 1.1, 1.3), bone, -d * 3.9))
	n.add_child(blob(Vector3(1.0, 2.2, 1.0), bone, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang))))   # the knuckle guard
	return {"node": n}


# ------------------------------------------------------------------ han

## A: the jian: a long straight slim double-edged blade, bright iron with a raised ridge, a
## bronze guard turned towards the blade, and a tassel in the team colour.
func _weapon_s3_jian(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade([Vector2(0, -1.4), Vector2(16.6, -1.2), Vector2(18.8, 0), Vector2(16.6, 1.2), Vector2(0, 1.4)], 0.6, _bright_iron(), Vector3.ZERO, ang))
	n.add_child(rod(d * 0.5, d * 16.5, 0.25, 0.12, _bright_iron(2.0), false))   # the ridge (dark iron greyed the slim blade out)
	var bronze := surf("bronze", Color(1.2, 1.1, 0.85), 2.0)
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(blob(Vector3(1.0, 2.6, 1.2), bronze, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang))))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.6, 0.6, 0.8), bronze, across * side * 2.4 + d * 0.6))
	grip(n, d, surf("cloth", Color("#3a2a20"), 2.0), bronze, 3.2)
	tassel(n, d, surf("cloth", c.team, 2.0), 3.6)
	return {"node": n}