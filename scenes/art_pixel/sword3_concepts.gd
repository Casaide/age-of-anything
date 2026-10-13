extends "res://scenes/art_pixel/unit_models.gd"
## The swordsman's age-3 kit, concept round S3 (2026-10-13, Dominic: "Swords looking great, need
## age 3"). The iron sword is the only tier-3 blade and it's royal (knight) kit, so the swamp,
## forest, hellenic, steppe, spooky and han swordsmen stay as they were in age 3. Two weapons per
## culture in its own look (and a helmet where it reads better), held in the swordsman's "low" hold
## like every sword: the origin is the grip, the blade runs along `TIP` (up and a little forward).
## Nothing here is in play: tests/sword3_concept_sheet.gd puts these ids into the loaded data only.
## Every option is longer, brighter or heavier than the age-2 bronze sword (14.4 long, 1.5 wide,
## dull bronze), so the step reads at game scale.

const TIP := Vector3(3, 14, 0)        # the bronze sword's line (the hold is the same)
const OBSIDIAN := Color("#2c2834")


## A blade outline bent along a curve: `length` along +x, the centre line rising `sag` (towards
## the back of the hand: a sabre's curve) at the tip, half-width w(t) from `widths` sampled at
## t = 0..1. `edge` 0 = both edges round the centre line; 1 = the spine stays on the centre line
## (a single-edged blade, the edge on -y).
func curved(length: float, sag: float, widths: Array, edge := 0.0, steps := 14) -> Array:
	var top := []
	var bottom := []
	for i in steps + 1:
		var t := float(i) / steps
		var w: float = _sample(widths, t)
		var cy := sag * t * t
		var x := length * t
		top.append(Vector2(x, cy + w * (1.0 - edge)))
		bottom.append(Vector2(x, cy - w * (1.0 + edge)))
	bottom.reverse()
	if top[-1].distance_to(bottom[0]) < 0.05:
		bottom.pop_front()
	return top + bottom


func _sample(ws: Array, t: float) -> float:
	var f := t * (ws.size() - 1)
	var i := mini(int(f), ws.size() - 2)
	return lerpf(ws[i], ws[i + 1], f - i)


## The grip end every concept shares: a wrapped grip down the line from the hand and a pommel.
func grip(n: Node3D, d: Vector3, wrap: Material, pommel: Material, length := 3.0) -> void:
	n.add_child(rod(Vector3.ZERO, -d * length, 0.6, 0.6, wrap, false))
	n.add_child(blob(Vector3(0.95, 0.95, 0.95), pommel, -d * (length + 0.6)))


## A tassel hanging from the pommel (team cloth): it swings out behind the hand.
func tassel(n: Node3D, d: Vector3, m: Material, length := 3.0) -> void:
	var at := -d * 3.8
	n.add_child(rod(at, at + Vector3(-1.2, -length, 0.4), 0.45, 0.8, m))
	n.add_child(blob(Vector3(0.7, 1.2, 0.7), m, at + Vector3(-1.3, -length - 0.6, 0.4)))


## Polished steel: the iron texture's grain over a pale tint, a little sheen (the plain iron
## tint bakes dark grey at game scale, as dark as the bronze it should outshine).
func _bright_iron(units := 3.0) -> StandardMaterial3D:
	var m := surf("iron", Color(2.2, 2.25, 2.4), units)
	m.metallic_specular = 0.7
	m.roughness = 0.55
	return m


# ------------------------------------------------------------------ hellenic

## A: the kopis, a heavy forward-curved chopper widening to a belly near the tip; bright iron,
## bronze fittings.
func _weapon_s3_kopis(c: Dictionary) -> Dictionary:
	var pts := [Vector2(0, -0.9), Vector2(5, -1.0), Vector2(9.5, -1.7), Vector2(13.5, -2.5), Vector2(16.2, -2.0),
		Vector2(17.6, -0.2), Vector2(16.6, 1.0), Vector2(12, 0.5), Vector2(7, 0.7), Vector2(3, 1.2), Vector2(0, 1.0)]
	var n := _sword(pts, TIP, _bright_iron(), surf("bronze", Color(1.2, 1.1, 0.85), 2.0))
	return {"node": n}


## B: a long leaf-bladed iron xiphos (worn with the Attic helmet below).
func _weapon_s3_xiphos(c: Dictionary) -> Dictionary:
	var pts := [Vector2(0, -0.9), Vector2(5, -1.0), Vector2(11.5, -1.9), Vector2(15.5, -1.2), Vector2(18.2, 0),
		Vector2(15.5, 1.2), Vector2(11.5, 1.9), Vector2(5, 1.0), Vector2(0, 0.9)]
	return {"node": _sword(pts, TIP, _bright_iron(), surf("bronze", Color(1.2, 1.1, 0.85), 2.0))}


## The Attic helmet: polished bronze, an open face with a brow peak, cheek pieces, and a tall
## crest held high on a stand in the team colour, so the age-3 Greek stands a head taller.
func _helm_s3_attic(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color(1.2, 1.1, 0.85), 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.5, surf("bronze", Color(1.35, 1.25, 1.0), 2.0), Vector3(0, -3.5, 0)))
	n.add_child(blob(Vector3(2.0, 0.5, 4.0), bronze, Vector3(4.4, -2.6, 0), Vector3(0, 0, -12)))   # the brow peak
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.0, 2.8, 0.6), bronze, Vector3(2.0, -6.0, 4.4 * side), Vector3(0, 0, 10)))
	n.add_child(blob(Vector3(2.8, 3.0, 4.4), bronze, Vector3(-2.8, -5.8, 0)))
	n.add_child(rod(Vector3(0, 1.0, 0), Vector3(-0.4, 4.2, 0), 0.55, 0.55, bronze))   # the crest stand
	crest(n, c.team, Vector3(-1.4, 4.6, 0), 14.0, 8.0)
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


## B: a heavier curved sword that flares wide before the point (a back-edge at the tip), a
## cross-guard, worn with the spiked helmet and mail neck-guard below.
func _weapon_s3_flared(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(17.0, 3.2, [1.1, 1.1, 1.2, 1.9, 2.0, 0.0], 0.3), 0.6, _bright_iron(), Vector3.ZERO, ang))
	var across := Vector3(-d.y, d.x, 0)
	var brass := surf("bronze", Color(1.2, 1.1, 0.8), 2.0)
	n.add_child(rod(-across * 2.8, across * 2.8, 0.6, 0.6, brass))
	grip(n, d, surf("leather", Color.WHITE, 2.0), brass)
	return {"node": n}


## The steppe helmet: a tall iron cone with a spike and a tuft, a mail curtain round the neck.
func _helm_s3_spike(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color(0.85, 0.85, 0.9), 3.0)   # brighter baked as a white blob
	n.add_child(cone(0.7, 5.1, 6.0, iron, Vector3(0, -0.8, 0)))
	n.add_child(ring(4.9, 5.6, surf("bronze", Color.WHITE, 2.0), Vector3(0, -3.7, 0)))
	n.add_child(rod(Vector3(0, 2.0, 0), Vector3(0, 6.5, 0), 0.7, 0.25, surf("bronze", Color(1.2, 1.1, 0.85), 2.0)))   # the spike
	n.add_child(blob(Vector3(1.1, 2.8, 1.1), plain(c.team), Vector3(-1.0, 5.2, 0), Vector3(0, 0, 35)))   # the tuft
	var mail := surf("mail", Color(0.7, 0.7, 0.75), 2.0)
	n.add_child(cone(5.2, 5.8, 3.6, mail, Vector3(-0.8, -5.6, 0)))   # the aventail
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


## B: a heavy river-stone mace: a pale driftwood haft and a big smooth grey stone lashed to it.
func _weapon_s3_stone_mace(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var wood := surf("wood_grain", Color(1.15, 1.05, 0.9), 3.0)
	n.add_child(rod(-d * 2.5, d * 12.5, 0.7, 0.9, wood))
	var stone := surf("rock", Color(0.95, 0.95, 0.92), 2.5)
	n.add_child(blob(Vector3(3.4, 2.6, 2.8), stone, d * 13.0 + Vector3(0.6, 0, 0), Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)))))
	var cord := surf("cloth", Color("#8a7a4a"), 2.0)
	for k in 2:   # the lashings round stone and haft
		n.add_child(ring(2.4, 2.9, cord, d * (11.6 + k * 2.6) + Vector3(0.4, 0, 0), Vector3(90, 0, rad_to_deg(atan2(d.y, d.x)) - 90), Vector3(1.0, 1.0, 1.1)))
	n.add_child(ring(0.8, 1.2, cord, -d * 0.4, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return {"node": n}


# ------------------------------------------------------------------ forest (beetles)

## A: a chitin-edged blade: a dark heartwood blade with overlapping shards of bright green-blue
## beetle shell along both edges, a shell guard.
func _weapon_s3_chitin_blade(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(16.5, 0.0, [1.0, 1.3, 1.3, 1.0, 0.0]), 0.8, surf("wood_grain", Color(0.6, 0.45, 0.32), 3.0), Vector3.ZERO, ang))
	var shell := surf("chitin", Color("#4fd0a0"), 2.0)
	var across := Vector3(-d.y, d.x, 0)
	for k in 6:
		var t := 2.0 + k * 2.4
		var w := 1.3 if k < 4 else 1.3 - (k - 3) * 0.4
		for side in [1, -1]:
			n.add_child(blade([Vector2(-1.4, 0), Vector2(0, -0.8), Vector2(1.6, 0), Vector2(0, 0.8)], 0.5, shell,
				d * t + across * side * w, ang + 0.25 * side))
	n.add_child(blade([Vector2(0, -1.0), Vector2(3.0, 0), Vector2(0, 1.0)], 0.6, shell, d * 16.0, ang))   # the point
	n.add_child(blob(Vector3(1.2, 3.2, 1.6), shell, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang))))   # the guard
	grip(n, d, surf("leather", Color.WHITE, 2.0), shell)
	return {"node": n}


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


## B: a hooked sickle blade: pale silvered iron, straight for most of its length, then a big hook
## curling forward; the grip wound in white web silk.
func _weapon_s3_hook(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	var steel := _bright_iron(2.5)
	var pts := [Vector2(0, -0.9), Vector2(11, -1.1), Vector2(14, -1.6), Vector2(16.4, -0.6), Vector2(17.4, 1.6), Vector2(16.4, 3.8),
		Vector2(14.2, 4.8), Vector2(13.4, 3.8), Vector2(15.0, 2.6), Vector2(15.2, 1.0), Vector2(13.6, 0.4), Vector2(11, 0.9), Vector2(0, 0.9)]
	for i in pts.size():   # the hook forward (the blade's -y is the front)
		pts[i] = Vector2(pts[i].x, -pts[i].y)
	pts.reverse()
	n.add_child(blade(pts, 0.6, steel, Vector3.ZERO, ang))
	var silk := surf("cloth", Color("#f2f0ea"), 2.0)
	for k in 4:
		n.add_child(ring(0.55, 0.95, silk, -d * (0.4 + k * 0.7), Vector3(0, 0, rad_to_deg(ang) - 90)))
	n.add_child(blob(Vector3(1.0, 1.0, 1.0), steel, -d * 3.4))
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(-across * 2.2, across * 2.2, 0.5, 0.5, steel))
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


## B: the dao: a broad single-edged sabre, curving gently and widest near the tip, a disc guard,
## a ring pommel with a crimson cloth.
func _weapon_s3_dao(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(16.5, 1.8, [1.1, 1.3, 1.6, 2.0, 1.6, 0.0], 0.5), 0.6, _bright_iron(), Vector3.ZERO, ang))
	var bronze := surf("bronze", Color(1.2, 1.1, 0.85), 2.0)
	n.add_child(cone(1.8, 1.8, 0.5, bronze, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang) - 90)))
	n.add_child(rod(Vector3.ZERO, -d * 3.4, 0.6, 0.6, surf("cloth", Color("#3a2a20"), 2.0), false))
	n.add_child(ring(0.7, 1.2, bronze, -d * 4.4, Vector3(90, 0, rad_to_deg(ang) - 90)))   # the ring pommel
	var red := surf("cloth", c.crimson, 2.0)
	n.add_child(rod(-d * 4.6, -d * 4.6 + Vector3(-1.4, -3.2, 0.4), 0.4, 1.0, red))
	return {"node": n}
