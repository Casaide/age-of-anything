extends "res://scenes/art_pixel/unit_models.gd"
## Heroes' signature gear (milestone 14 step 9; HR2's characters, D-127, D-131), in play: the parts
## "hero.*" (data/parts.json, only_if hero_only) that data/heroes.json's signatures put on over a
## race's swordsman. unit_models.gd builds them from here (loaded when first asked for, like siege
## engines). Concept notes: docs/concepts/heroes/README.md.
## Frames as the game's gear: head gear on the head's "top" socket (the skull's dome about y -3.8,
## radius 5; scaled by the head's gear_scale), back gear from the back socket (down is -y, behind is
## -x), held items with the grip at the origin ("low": the business end up and forward; "shoulder":
## up and back over the shoulder, as the pike: parts tagged "shouldered"), shields built flat and
## turned by SHIELD_FACE.
## Low-slung variants ("hero.<hat>_low", D-138): the same hat for a head that sits low in its shoulders
## or wears its eyes on top (frogs, beetles, spiders: data/heroes.json signature `fit`), with nothing
## hanging down behind or beside the head (a mane, a pelt, cheek guards) and set a little higher and
## further back, a size smaller (`low` while one builds).

var low := false
const LOW_K := 0.8   # a low-slung hat's size (a spider's eyes ring the top of its head)


## A low-slung variant of hat `fn`: built with `low` set, then raised and set back.
func _low(fn: String, c: Dictionary) -> Dictionary:
	low = true
	var out: Dictionary = call(fn, c)
	low = false
	for ch in out.node.get_children():
		ch.position = ch.position * LOW_K + Vector3(-2.0, 1.0, 0)
		ch.scale *= LOW_K
	return out


func _hero_lion_hood_low(c: Dictionary) -> Dictionary: return _low("_hero_lion_hood", c)
func _hero_wolf_hat_low(c: Dictionary) -> Dictionary: return _low("_hero_wolf_hat", c)
func _hero_jaguar_helm_low(c: Dictionary) -> Dictionary: return _low("_hero_jaguar_helm", c)
func _hero_helm_transverse_low(c: Dictionary) -> Dictionary: return _low("_hero_helm_transverse", c)
func _hero_tricorn_low(c: Dictionary) -> Dictionary: return _low("_hero_tricorn", c)
func _hero_top_hat_low(c: Dictionary) -> Dictionary: return _low("_hero_top_hat", c)


func gold(k := 1.0) -> StandardMaterial3D:
	var m := plain(Color(0.98, 0.78, 0.25) * k)   # (bright: the bronze texture tinted read as brown at game scale)
	m.roughness = 0.35
	m.metallic_specular = 0.9
	return m


## A chain of rods through `pts`, radii `r` (one per point).
func chain_rods(n: Node3D, pts: Array, r: Array, m: Material) -> void:
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], m))


## A crown band round the skull from y0 to y0 + h, radius r, with `points` points rising `ph` above.
func crown(n: Node3D, m: Material, y0: float, h: float, r: float, points: int, ph: float, skip := -1) -> void:
	n.add_child(cone(r, r * 0.95, h, m, Vector3(0, y0 + h * 0.5, 0), Vector3.ZERO, 24))
	n.add_child(cone(r - 0.6, r - 0.65, h + 0.1, plain(Color("#2a1a12")), Vector3(0, y0 + h * 0.5 + 0.05, 0), Vector3.ZERO, 24))   # (hollow)
	for k in points:
		if k == skip:
			continue
		var a := TAU * k / points
		var at := Vector3(cos(a) * r * 0.97, y0 + h, sin(a) * r * 0.97)
		n.add_child(cone(0.05, 1.2, ph, m, at + Vector3(0, ph * 0.5, 0), Vector3.ZERO, 6))
		n.add_child(blob(Vector3.ONE * 0.55, plain(Color("#c02030") if k % 2 == 0 else Color("#2050c0")), at + Vector3(0, ph + 0.2, 0)))


# ================================================================== head gear

## Rats, the Gnawer: an oversized gold crown with a bite out of it (the gap, the tooth marks).
func _hero_crown_gnawed(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	crown(n, gold(), -1.6, 3.4, 5.6, 7, 4.2, 2)
	var dent := plain(Color("#6a5020"))
	for k in 3:   # tooth marks round the bite
		var a := TAU * 2.0 / 7.0 + (k - 1) * 0.22
		n.add_child(blob(Vector3(0.6, 1.0, 0.6), dent, Vector3(cos(a) * 5.5, 1.4, sin(a) * 5.5)))
	return {"node": n}


## Rats, the 10000th of His Name: a tiny crown perched on the very top, far too small, tilted.
func _hero_crown_tiny(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var w := Node3D.new()
	w.position = Vector3(-0.5, 0.6, 0)
	w.rotation_degrees = Vector3(12, 0, 10)
	crown(w, gold(1.1), 0.0, 1.6, 2.2, 5, 1.8)
	n.add_child(w)
	n.add_child(blob(Vector3(2.4, 0.6, 2.4), plain(Color("#8a1a2a")), Vector3(-0.5, 0.9, 0)))   # the velvet cushion inside
	return {"node": n}


## Rats, the Unkillable: a battered tricorn with a bite out of its brim, a bandage under it.
func _hero_tricorn(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("bld_felt", Color(0.35, 0.3, 0.28), 4.0)
	n.add_child(dome(Vector3(4.6, 3.6, 4.6), felt, Vector3(-0.3, -1.2, 0)))
	for k in 3:   # three brims turned up
		var a := TAU * k / 3.0 + PI
		var at := Vector3(cos(a) * 4.8, -0.2, sin(a) * 4.8)
		n.add_child(_box(Vector3(1.0, 3.2, 7.6), felt, at, Vector3(0, -rad_to_deg(a), 18)))
	n.add_child(ring(4.5, 5.2, plain(Color("#e8e0cc")), Vector3(0.2, -2.4, 0), Vector3(0, 0, -8)))   # the bandage
	n.add_child(blob(Vector3(0.8, 0.8, 0.6), plain(Color("#a02020")), Vector3(1.5, -2.2, 5.0)))
	if not low:
		n.add_child(blob(Vector3(0.8, 2.6, 0.6), plain(Color("#e8e0cc")), Vector3(-4.0, -3.4, 2.6), Vector3(0, 0, 20)))   # its knot's tail
	_lift(n, 0.25)   # its brims clear of the brow (placement check, A2)
	return {"node": n}


## Frogs, Twice-Drowned: a crown of waterweed and a fish bone, dripping down the back.
func _hero_weed_crown(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var weed := surf("reed_leaf", Color(0.55, 0.75, 0.45), 4.0)
	n.add_child(ring(4.4, 5.6, weed, Vector3(0, -1.6, 0)))
	for k in 7:
		var a := PI * 0.55 + k * PI * 0.15
		var at := Vector3(cos(a) * 5.0, -1.6, sin(a) * 5.0)
		chain_rods(n, [at, at + Vector3(-1.2, -3.0, 0), at + Vector3(-1.6, -6.5 - (k % 3), 0)], [0.6, 0.5, 0.3], weed)
	chain_rods(n, [Vector3(-1.0, 0.6, 0), Vector3(1.0, 4.0, 1.0), Vector3(0.0, 7.0, 0.5)], [0.4, 0.35, 0.2], plain(Color("#e8e4d4")))   # a fish bone
	for k in 3:
		n.add_child(rod(Vector3(0.6 - k * 0.4, 3.0 + k * 1.3, 0.8), Vector3(2.2 - k * 0.3, 3.6 + k * 1.3, 0.8), 0.15, 0.1, plain(Color("#e8e4d4"))))
	return {"node": n}


## Frogs, the Loud: a ridiculous pink water-lily hat, petals out wide, a tall reed plume.
func _hero_lily_hat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var petal := plain(Color("#f0a0c0"))
	n.add_child(cone(5.0, 5.2, 1.0, plain(Color("#4f9d4a")), Vector3(0, -0.6, 0), Vector3.ZERO, 24))
	for k in 9:
		var a := TAU * k / 9.0
		n.add_child(blob(Vector3(4.2, 0.9, 1.8), petal, Vector3(cos(a) * 5.6, 0.6 + (k % 2) * 0.8, sin(a) * 5.6), Vector3(0, -rad_to_deg(a), 25)))
	n.add_child(blob(Vector3(2.0, 1.6, 2.0), plain(Color("#f0d040")), Vector3(0, 1.4, 0)))
	chain_rods(n, [Vector3(-0.5, 2.0, 0), Vector3(-2.0, 9.0, 0), Vector3(-5.0, 14.0, 0)], [0.4, 0.3, 0.2], surf("reed_stalk", Color.WHITE, 4.0))
	n.add_child(blob(Vector3(1.2, 3.0, 1.2), plain(Color("#6a4a2a")), Vector3(-5.2, 15.5, 0), Vector3(0, 0, 30)))   # a bulrush head
	return {"node": n}


## Imperial (and centaur) heroes: a helmet with an enormous transverse crest, side to side, crimson.
func _hero_helm_transverse(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bronze := gold(0.9)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.8, 5.4, bronze, Vector3(0.3, -2.8, 0)))
	if not low:   # the neck guard and cheek pieces
		n.add_child(blob(Vector3(3.0, 0.6, 5.0), iron, Vector3(-4.0, -4.2, 0), Vector3(0, 0, -25)))
		for side in [1, -1]:
			n.add_child(blob(Vector3(1.6, 2.6, 0.5), iron, Vector3(2.0, -5.6, 4.3 * side)))
	n.add_child(_box(Vector3(1.0, 1.6, 9.0), bronze, Vector3(-0.2, 1.4, 0)))
	n.add_child(decal("plume", 22.0, 9.0, Vector3(-0.2, 6.6, 0), Vector3(1, 0, 0), true, Vector3.UP, c.crimson))
	n.add_child(decal("plume", 22.0, 9.0, Vector3(-0.4, 6.6, 0), Vector3(-1, 0, 0), true, Vector3.UP, c.crimson))
	return {"node": n}


## Hellenic, Lionheart: a lion's scalp worn as a hood over the helmet, its upper jaw over the brow,
## the mane round the shoulders.
func _hero_lion_hood(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var pelt := surf("hide", Color(0.95, 0.72, 0.42), 5.0)
	var mane := surf("mane", Color(0.62, 0.4, 0.22), 3.0)
	n.add_child(dome(Vector3(5.6, 5.6, 5.4), pelt, Vector3(-0.4, -3.4, 0)))
	var jaw := Vector3(1.0, 1.8, 0) if low else Vector3.ZERO   # (low: the jaw up off eyes worn on top of the head)
	n.add_child(blob(Vector3(4.0, 2.2, 3.6), pelt, Vector3(4.2, -1.0, 0) + jaw))   # the lion's muzzle over the brow
	n.add_child(blob(Vector3(1.4, 1.0, 2.0), plain(Color("#3a2418")), Vector3(7.8, -1.2, 0) + jaw))
	for side in [1, -1]:
		n.add_child(cone(0.1, 0.6, 2.0, plain(Color("#f0ead8")), Vector3(6.4, -2.6, 1.6 * side) + jaw, Vector3(0, 0, 180), 6))   # fangs
		n.add_child(blob(Vector3(1.2, 1.4, 0.7), pelt, Vector3(0.5, 2.2, 3.6 * side)))   # its ears
		n.add_child(blob(Vector3(0.6, 0.4, 0.5), plain(Color("#c89020")), Vector3(5.6, 0.6, 2.2 * side)))
	for k in (0 if low else 9):   # the mane, down the back of the head
		var a := PI * 0.6 + k * PI * 0.1
		n.add_child(blob(Vector3(2.6, 4.0, 2.4), mane, Vector3(cos(a) * 5.4 - 0.6, -4.2, sin(a) * 5.4)))
	_lift(n, 0.4)   # the lion's jaw clear of the brow (placement check, A2)
	return {"node": n}


## Royal, the Overdressed: an open bascinet crowned with a tower of ostrich plumes, three colours.
func _hero_helm_plume(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var steel := surf("iron", Color(1.1, 1.1, 1.15), 3.0)
	n.add_child(dome(Vector3(5.0, 6.4, 4.8), steel, Vector3(-0.4, -3.6, 0)))
	n.add_child(ring(4.8, 5.4, gold(), Vector3(-0.2, -2.8, 0)))
	n.add_child(cone(0.6, 1.0, 2.0, gold(), Vector3(-0.6, 3.6, 0)))
	var cols := [c.team, Color("#f4f0e4"), Color("#d8b030"), c.team, Color("#f4f0e4")]
	for k in 5:
		var a := (k - 2) * 0.32
		n.add_child(decal("plume", 7.0, 15.0, Vector3(-2.0 - absf(k - 2) * 1.0, 11.0 - absf(k - 2) * 1.4, sin(a) * 4.0), Vector3(sin(a) * 0.4, 0, cos(a)), true, Vector3(-0.5, 1, sin(a)).normalized(), cols[k]))
	_lift(n, 0.5)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Steppe, Wolfbrother: a wolf's head worn as a hat, ears up, its pelt down the back.
func _hero_wolf_hat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color(0.62, 0.6, 0.58), 4.0)
	var dark := surf("rat_fur", Color(0.35, 0.33, 0.32), 4.0)
	n.add_child(dome(Vector3(5.4, 5.0, 5.2), fur, Vector3(-0.4, -3.0, 0)))
	var jaw := Vector3(0.6, 1.6, 0) if low else Vector3.ZERO   # (low: the snout up off eyes worn on top of the head)
	n.add_child(rod(Vector3(2.5, 0.0, 0) + jaw, Vector3(8.0, -0.8, 0) + jaw, 2.4, 1.3, fur))   # the snout over the brow
	n.add_child(blob(Vector3(0.9, 0.7, 0.9), plain(Color("#1a1412")), Vector3(8.8, -0.6, 0) + jaw))
	for side in [1, -1]:
		n.add_child(cone(0.1, 1.5, 3.6, dark, Vector3(0.6, 2.8, 2.4 * side), Vector3(10 * side, 0, -8), 6))
		n.add_child(blob(Vector3(0.5, 0.4, 0.4), plain(Color("#e0c040")), Vector3(4.2, 0.9, 1.8 * side)))
	if not low:
		n.add_child(blob(Vector3(2.6, 4.0, 3.8), fur, Vector3(-4.0, -5.0, 0), Vector3(0, 0, -12)))   # the pelt down the back
	return {"node": n}


## Nile, the Golden: a tall double crown with two gold plumes, a cobra at the brow.
func _hero_double_crown(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var white := plain(Color("#f2eee2"))
	n.add_child(cone(4.6, 5.2, 4.0, plain(Color("#b02828")), Vector3(-0.3, -1.2, 0), Vector3.ZERO, 24))
	n.add_child(cone(1.6, 3.6, 7.0, white, Vector3(-0.6, 4.2, 0), Vector3.ZERO, 20))
	n.add_child(blob(Vector3(1.8, 1.8, 1.8), white, Vector3(-0.6, 7.8, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.4, 8.0, 0.5), gold(), Vector3(-1.6, 9.0, 1.2 * side), Vector3(0, 0, 8)))
	chain_rods(n, [Vector3(4.6, -1.0, 0), Vector3(5.4, 0.6, 0), Vector3(5.0, 2.0, 0)], [0.6, 0.5, 0.7], gold())   # the cobra
	_lift(n, 0.2)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Aztec, Jaguar-Heart: the warrior's face in a jaguar's open jaws, the spotted head over the skull.
func _hero_jaguar_helm(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var pelt := surf("hide", Color(1.0, 0.75, 0.32), 4.0)
	var spot := plain(Color("#2a1c12"))
	n.add_child(dome(Vector3(5.6, 5.4, 5.4), pelt, Vector3(-0.4, -3.2, 0)))
	var jaw := Vector3(1.0, 1.8, 0) if low else Vector3.ZERO   # (low: the jaw up off eyes worn on top of the head)
	n.add_child(blob(Vector3(4.2, 2.6, 4.2), pelt, Vector3(4.0, -0.8, 0) + jaw))   # the upper jaw over the brow
	n.add_child(blob(Vector3(1.4, 1.0, 2.0), spot, Vector3(8.0, -0.4, 0) + jaw))
	for side in [1, -1]:
		n.add_child(cone(0.1, 0.7, 2.6, plain(Color("#f4eedc")), Vector3(6.6, -2.8, 2.2 * side) + jaw, Vector3(0, 0, 180), 6))
		n.add_child(blob(Vector3(1.2, 1.3, 0.7), pelt, Vector3(-0.2, 2.4, 3.6 * side)))
		n.add_child(blob(Vector3(0.6, 0.5, 0.5), plain(Color("#d8c020")), Vector3(5.6, 1.0, 2.4 * side)))
		if not low:
			n.add_child(blob(Vector3(2.4, 4.2, 1.2), pelt, Vector3(1.0, -8.6, 5.0 * side), Vector3(0, 0, 10)))   # the jaw's sides down the cheeks
	for k in 12:
		var a := k * 2.39996
		n.add_child(blob(Vector3.ONE * 0.55, spot, on_surface(Vector3(-0.4, -3.2, 0), Vector3(5.6, 5.4, 5.4), Vector3(cos(a) * 0.8 - 0.3, 0.4 + fmod(k * 0.37, 0.6), sin(a)), 0.05)))
	for k in 3:   # feathers at the crown
		n.add_child(blob(Vector3(0.6, 4.0, 1.2), plain([Color("#20a060"), Color("#e8c030"), Color("#2060c0")][k]), Vector3(-2.0 - k * 0.8, 3.8, (k - 1) * 1.6), Vector3(0, 0, 24)))
	_lift(n, 0.35)   # its jaw clear of the brow (placement check, A2)
	return {"node": n}


## Forest beetles, the Polished: an acorn-cup helmet twice the size it should be, a tall gold plume.
func _hero_acorn_plume(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cap := gold()   # (gilded: the beetles' own acorn caps are brown, so a brown one read as the soldier's)
	n.add_child(dome(Vector3(6.4, 5.6, 6.2), cap, Vector3(-0.3, -2.4, 0)))
	n.add_child(ring(6.0, 7.0, gold(), Vector3(-0.3, -2.2, 0)))
	n.add_child(rod(Vector3(-0.6, 3.0, 0), Vector3(-0.8, 5.0, 0), 0.6, 0.4, gold()))
	n.add_child(decal("plume", 8.0, 16.0, Vector3(-3.0, 12.0, 0), Vector3(0, 0, 1), true, Vector3(-0.3, 1, 0), Color("#e8c040")))
	return {"node": n}


## Spiders, Eight-Eyes: a tall black top hat with a team band, a little crooked.
func _hero_top_hat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("bld_felt", Color(0.16, 0.15, 0.17), 3.0)
	var w := Node3D.new()
	w.rotation_degrees = Vector3(8, 0, -8)
	w.scale = Vector3.ONE * (1.1 if low else 1.4)   # (a spider's head is small: at 1x it read as a speck; low: under a beetle's raised cane)
	w.position = Vector3(-3.2, 1.2, 0)   # (set back behind the eyes on top: over them, it hid four of eight)
	n.add_child(w)
	w.add_child(cone(5.6, 5.6, 0.6, felt, Vector3(0, -0.4, 0), Vector3.ZERO, 24))   # the brim
	w.add_child(cone(3.9, 3.4, 9.0, felt, Vector3(0, 4.4, 0), Vector3.ZERO, 20))
	w.add_child(cone(3.55, 3.45, 1.4, plain(c.team), Vector3(0, 0.8, 0), Vector3.ZERO, 20))
	return {"node": n}


## Spiders, the Widow: a tall black lace hat, a veil hanging behind, a bone pin.
func _hero_widow_hat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var lace := surf("cloth", Color(0.14, 0.12, 0.16), 3.0)
	n.add_child(cone(1.2, 4.0, 8.0, lace, Vector3(-0.8, 2.6, 0), Vector3(0, 0, 14), 16))
	n.add_child(cone(5.4, 5.4, 0.5, lace, Vector3(0, -1.0, 0), Vector3.ZERO, 24))
	for side in [1, -1]:
		n.add_child(_box(Vector3(0.3, 9.0, 4.0), lace, Vector3(-4.6, -5.2, 2.0 * side), Vector3(0, 20 * side, -6)))   # the veil behind
	n.add_child(rod(Vector3(1.0, 1.0, 3.0), Vector3(-2.0, 6.0, -1.0), 0.3, 0.3, surf("bone", Color.WHITE, 2.0)))
	n.add_child(blob(Vector3.ONE * 0.9, surf("bone", Color.WHITE, 2.0), Vector3(-2.0, 6.0, -1.0)))
	return {"node": n}


## Centaurs, Thunderhoof (and anyone the gods smiled on): a gold laurel wreath.
func _hero_laurel_gold(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(ring(4.6, 5.2, gold(), Vector3(0, -1.8, 0)))
	for k in 14:
		var a := PI * 0.2 + k * PI * 0.115
		for side in [1, -1]:
			var at := Vector3(cos(a) * 5.0, -1.5 + 0.35 * sin(k * 1.3), sin(a) * 5.0 * side)
			n.add_child(blob(Vector3(1.4, 0.4, 0.7), gold(1.05), at + Vector3(0, 0.6, 0), Vector3(0, -rad_to_deg(a) * side, 35)))
	return {"node": n}


## Bears, Honeypaw: a crown of honeycomb dripping honey down the brow (not over the eyes).
func _hero_honey_crown(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var comb := plain(Color("#e8b030"))
	var honey := plain(Color("#d88a10"))
	honey.roughness = 0.2
	honey.metallic_specular = 0.8
	n.add_child(cone(4.6, 5.0, 3.6, comb, Vector3(-0.4, -0.6, 0), Vector3.ZERO, 6))
	for k in 6:
		var a := TAU * k / 6.0 + 0.5
		n.add_child(cone(0.1, 1.4, 3.0, comb, Vector3(cos(a) * 4.4 - 0.4, 2.6, sin(a) * 4.4), Vector3.ZERO, 6))
	for k in 5:
		var a := PI * 0.7 + k * 0.3
		n.add_child(blob(Vector3(0.6, 1.6, 0.6), honey, Vector3(cos(a) * 4.9 - 0.4, -2.6, sin(a) * 4.9)))
	n.add_child(blob(Vector3(0.9, 0.9, 0.9), plain(Color("#f0d040")), Vector3(-0.8, 4.6, 1.0)))   # a bee
	n.add_child(blob(Vector3(0.5, 0.5, 0.5), plain(Color("#2a2010")), Vector3(-0.2, 4.7, 1.2)))
	return {"node": n}


## Bears, the Unwoken: a long striped nightcap flopping down the back, a pompom at its end.
func _hero_nightcap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := plain(Color("#e8e0f0"))
	var b := plain(Color("#4a5ab0"))
	n.add_child(ring(4.5, 5.2, a, Vector3(-0.5, -1.6, 0)))
	var pts := [Vector3(-0.5, -1.0, 0), Vector3(0.2, 3.0, 0.6), Vector3(-0.6, 5.6, 3.2), Vector3(-2.2, 5.0, 6.2), Vector3(-3.4, 2.0, 7.8)]   # (flopping to the side: down the back it ran into a banner pole)
	var r := [4.6, 3.4, 2.4, 1.5, 0.8]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], a if k % 2 == 0 else b))
	n.add_child(blob(Vector3.ONE * 1.6, plain(Color("#f4f0e8")), Vector3(-3.6, 0.8, 8.2)))
	return {"node": n}


# ================================================================== back gear

## Rats, the 10000th: an ermine-trimmed robe of state in team velvet, dragging on the ground behind.
func _hero_cape_ermine(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var velvet := surf("cloth", c.team, 4.0)
	var ermine := plain(Color("#f4f0e8"))
	for side in [1, -1]:
		var panel := slab([Vector2(2, 1), Vector2(3, -1), Vector2(-2, -15), Vector2(-14, -16.5), Vector2(-15, -14), Vector2(-1.5, 0.5)], 0.7, velvet)
		panel.position = Vector3(0, 0, 3.2 * side)
		panel.rotation_degrees = Vector3(0, -8 * side, 0)
		n.add_child(panel)
	n.add_child(ring(3.6, 4.8, ermine, Vector3(0.6, 0.6, 0), Vector3(0, 0, 10), Vector3(1, 1.6, 1.2)))   # the ermine collar
	for k in 6:
		n.add_child(blob(Vector3(2.0, 1.0, 1.4), ermine, Vector3(-3.0 - k * 2.2, -14.8 - k * 0.25, (k % 2 - 0.5) * 5.0)))   # the trim on the train
		n.add_child(blob(Vector3(0.3, 0.6, 0.3), plain(Color("#141010")), Vector3(-3.0 - k * 2.2, -14.3 - k * 0.25, (k % 2 - 0.5) * 5.0 + 1.3)))
	return {"node": n}


## Rats, the Unkillable: a pet cockroach riding his shoulder on a little harness.
func _hero_roach_pet(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := root
	var shell := surf("chitin", Color("#6a3a1a"), 3.0)
	shell.roughness = 0.3
	# (on the far shoulder: the cleaver rides the near one)
	n.add_child(rod(Vector3(-1.0, -4.0, 0), Vector3(1.0, 3.4, -4.0), 0.4, 0.4, surf("leather", Color.WHITE, 2.0)))   # the strap
	n.add_child(blob(Vector3(2.4, 0.8, 2.0), surf("leather", Color.WHITE, 2.0), Vector3(1.0, 3.6, -4.4)))   # its saddle pad
	var at := Vector3(1.0, 4.6, -4.4)
	var big := Node3D.new()   # (a cockroach the size of a cat: smaller, nobody saw Gerald)
	big.position = at
	big.scale = Vector3.ONE * 1.5
	n.add_child(big)
	n = big
	at = Vector3.ZERO
	n.add_child(blob(Vector3(3.0, 1.4, 2.0), shell, at))
	n.add_child(blob(Vector3(1.0, 0.9, 1.2), plain(Color("#2a1a10")), at + Vector3(3.0, 0, 0)))
	for side in [1, -1]:
		chain_rods(n, [at + Vector3(3.6, 0.4, 0.5 * side), at + Vector3(7.0, 3.0, 2.0 * side), at + Vector3(9.0, 2.0, 3.0 * side)], [0.15, 0.12, 0.1], plain(Color("#2a1a10")))
		for k in 3:
			n.add_child(rod(at + Vector3(1.5 - k * 1.5, -0.6, 1.2 * side), at + Vector3(2.0 - k * 2.0, -1.6, 2.6 * side), 0.18, 0.12, plain(Color("#2a1a10"))))
	return {"node": root}


## Frogs, Old Mossback: a mound of moss over the shoulders, toadstools and a fern growing in it.
func _hero_moss_mantle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var moss := surf("foliage", Color(0.7, 0.9, 0.45), 5.0)
	n.add_child(blob(Vector3(4.0, 3.6, 6.0), moss, Vector3(-4.6, 0.5, 0)))
	n.add_child(blob(Vector3(3.0, 4.0, 5.0), moss, Vector3(-6.4, -4.0, 0)))
	for k in 3:
		var at := Vector3(-5.6 + k * 1.2, 3.4 - k * 0.5, (k - 1) * 3.0)
		n.add_child(rod(at, at + Vector3(0, 2.2, 0), 0.5, 0.45, plain(Color("#f0e8d0")), false))
		n.add_child(dome(Vector3(1.8, 1.3, 1.8), plain(Color("#c83a2a")), at + Vector3(0, 2.2, 0)))
	for k in 4:   # a fern
		var a := -0.6 + k * 0.4
		chain_rods(n, [Vector3(-6.0, 2.0, -2.0), Vector3(-8.0, 6.0, -2.0 + sin(a) * 2.0), Vector3(-11.0, 8.0 + k * 0.5, -2.0 + sin(a) * 4.0)], [0.4, 0.5, 0.2], surf("reed_leaf", Color(0.6, 0.85, 0.4), 3.0))
	return {"node": n}


## Frogs, the Loud: a great conch war horn slung on his back, its mouth over his shoulder.
func _hero_conch_horn(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("bone", Color(1.05, 0.88, 0.75), 3.0)
	var pink := plain(Color("#f0a090"))
	n.add_child(rod(Vector3(-1.0, -2.0, -2.0), Vector3(-1.0, -2.0, 2.0), 0.4, 0.4, surf("leather", Color.WHITE, 2.0)))
	n.add_child(cone(0.3, 3.4, 13.0, shell, Vector3(-3.0, 1.0, 0), Vector3(0, 0, 55), 14))
	n.add_child(blob(Vector3(3.8, 3.8, 3.4), shell, Vector3(-7.4, -2.6, 0)))
	for k in 3:
		n.add_child(cone(0.1, 0.9, 2.4, shell, Vector3(-7.4 + k * 1.6, 1.0 - k * 0.6, 2.4), Vector3(0, 0, -20), 6))
	n.add_child(cone(3.5, 3.6, 0.6, pink, Vector3(-8.4, -4.0, 0), Vector3(0, 0, 55), 14))
	return {"node": n}


## Imperial, the Unbothered: a long crimson cloak (crimson, not team: his own colour), dragging.
func _hero_cape_long(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cloth := surf("cloth", c.crimson, 4.0)
	for side in [1, -1]:
		var panel := slab([Vector2(2, 1), Vector2(3, -1), Vector2(-5, -15), Vector2(-13, -16), Vector2(-13.5, -12), Vector2(-1.5, 0.5)], 0.6, cloth)
		panel.position = Vector3(0, 0, 3.0 * side)
		panel.rotation_degrees = Vector3(0, -10 * side, 0)
		n.add_child(panel)
	n.add_child(blob(Vector3(1.2, 1.2, 0.7), gold(), Vector3(1.5, 0, 1.4)))
	return {"node": n}


## Hellenic, Lionheart: the lion's pelt down his back, paws knotted at the chest, tail hanging.
func _hero_lion_pelt(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var pelt := surf("hide", Color(0.95, 0.72, 0.42), 5.0)
	n.add_child(slab([Vector2(2, 1), Vector2(2, -2), Vector2(-1, -15), Vector2(-6, -16), Vector2(-7, -12), Vector2(-2, 1)], 1.4, pelt, Vector3(0, 0, 0)))
	for side in [1, -1]:
		chain_rods(n, [Vector3(0.5, 0, 3.0 * side), Vector3(3.0, -2.0, 3.6 * side)], [1.2, 1.0], pelt)   # the forepaws over the shoulders
	chain_rods(n, [Vector3(-5.0, -15.0, 0), Vector3(-8.0, -17.0, 0), Vector3(-9.5, -18.0, 0)], [0.6, 0.5, 0.4], pelt)
	n.add_child(blob(Vector3(1.0, 1.6, 1.0), surf("mane", Color(0.5, 0.3, 0.18), 2.0), Vector3(-10.0, -18.4, 0)))
	return {"node": n}


## Royal, the Overdressed: a heraldic cape quartered in team colour and gold, ermine-free (just).
func _hero_cape_heraldic(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var team := surf("cloth", c.team, 4.0)
	var gold_cloth := surf("cloth", Color("#d8b030"), 4.0)
	for side in [1, -1]:
		for half in 2:
			var top := 1.0 if half == 0 else -7.0
			var back := half * 1.5   # (the lower quarters flare back as it falls, clear of a crouched body's haunches)
			var pts := [Vector2(2 - back, top), Vector2(2.5 - back, top - 1), Vector2(0.5 - half * 1.5 - back * 2.0, top - 8.5), Vector2(-4.5 - half * 3.0 - back * 2.0, top - 9), Vector2(-4 - half * 1.5 - back, top - 1)]
			var panel := slab(pts, 0.6, team if (half + (side + 1) / 2) % 2 == 0 else gold_cloth)
			panel.position = Vector3(0, 0, 3.0 * side)
			panel.rotation_degrees = Vector3(0, -10 * side, 0)
			n.add_child(panel)
	return {"node": n}


## Steppe, Wolfbrother: a horsetail standard (a pole crowned with a gold trident, tails hanging).
func _hero_horsetail_standard(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, -4, 0), Vector3(0, 26, 0), 0.5, 0.45, surf("wood_grain", Color.WHITE, 5.0), false))
	n.add_child(ring(1.0, 2.6, gold(), Vector3(0, 24.0, 0)))
	for k in 3:
		n.add_child(cone(0.05, 0.5, 4.0, gold(), Vector3(0, 28.0, (k - 1) * 1.6), Vector3(0, 0, 0), 6))
	for k in 7:
		var a := TAU * k / 7.0
		chain_rods(n, [Vector3(cos(a) * 1.8, 23.6, sin(a) * 1.8), Vector3(cos(a) * 2.4, 18.0, sin(a) * 2.4), Vector3(cos(a) * 2.0, 13.0 + (k % 2), sin(a) * 2.0)], [0.6, 0.6, 0.3], surf("mane", Color(0.85, 0.82, 0.75) if k % 2 == 0 else Color(0.25, 0.2, 0.18), 2.0))
	return {"node": n}


## Nile, the Golden: a temple cat riding on his shoulder, gold earring and collar.
func _hero_cat_pet(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := root
	var fur := surf("rat_fur", Color(0.8, 0.66, 0.45), 3.0)
	n.add_child(rod(Vector3(-1.0, -4.0, 0), Vector3(0.5, 2.6, -6.0), 0.4, 0.4, surf("leather", Color.WHITE, 2.0)))   # its cushion's strap
	n = Node3D.new()   # (bigger, on the far shoulder: smaller, the crown hid it; on the near one, the sword arm swung through it)
	n.position = Vector3(0.5, 3.0, -6.4)
	n.scale = Vector3.ONE * 1.4
	root.add_child(n)
	var at := Vector3(0.0, 0.6, 0)
	n.add_child(blob(Vector3(2.0, 0.6, 2.0), plain(Color("#2050a0")), at + Vector3(0, -0.6, 0)))
	n.add_child(blob(Vector3(2.0, 2.8, 1.8), fur, at + Vector3(-0.4, 2.0, 0)))   # sitting up
	n.add_child(blob(Vector3(1.5, 1.4, 1.4), fur, at + Vector3(0.8, 5.0, 0)))
	n.add_child(ring(1.2, 1.7, gold(), at + Vector3(0.2, 3.6, 0)))
	for side in [1, -1]:
		n.add_child(cone(0.05, 0.6, 1.6, fur, at + Vector3(0.6, 6.6, 0.8 * side), Vector3(0, 0, -8), 6))
		n.add_child(blob(Vector3(0.3, 0.35, 0.25), plain(Color("#30a040")), at + Vector3(2.0, 5.3, 0.6 * side)))
	chain_rods(n, [at + Vector3(-1.8, 0.4, 0), at + Vector3(-3.4, -1.6, -0.6), at + Vector3(-3.0, -4.2, -1.0)], [0.4, 0.35, 0.3], fur)
	return {"node": root}


## Han, the Unmoved: four triangular flags on poles from his back (a general's back flags).
func _hero_back_flags(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("wood_grain", Color(0.6, 0.35, 0.25), 4.0)
	n.add_child(_box(Vector3(1.6, 4.0, 5.0), surf("leather", Color(0.5, 0.3, 0.2), 2.0), Vector3(-0.8, -1.0, 0)))
	for k in 4:
		var z := (k - 1.5) * 1.6
		var tilt := (k - 1.5) * 9.0
		var foot := Vector3(-1.0, -2.0, z)
		var top := foot + Vector3(-1.5, 17.0, z * 2.4)
		n.add_child(rod(foot, top, 0.3, 0.25, wood, false))
		var flag := slab([Vector2(0, 0), Vector2(0, -7), Vector2(-5, -0.5)], 0.3, surf("cloth", c.team if k % 2 == 0 else Color("#e8d040"), 3.0), top + Vector3(0, -0.5, 0))
		flag.rotation_degrees = Vector3(tilt, 0, 0)
		n.add_child(flag)
	return {"node": n}


## Aztec, Jaguar-Heart: a great fan of quetzal feathers rising behind him.
func _hero_quetzal_fan(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(_box(Vector3(1.4, 4.0, 5.0), surf("wicker", Color.WHITE, 3.0), Vector3(-0.8, -0.6, 0)))
	var cols := [Color("#1aa060"), Color("#18c080"), Color("#e8c030"), Color("#c02828")]
	for k in 9:
		var a := (k - 4) * 0.28
		var tip := Vector3(-4.0, 14.0 * cos(a) + 2.0, 14.0 * sin(a))
		n.add_child(decal("plume", 4.0, 15.0, Vector3(-2.4, 1.0, 0).lerp(tip, 0.55), Vector3(1, 0, 0), true, (tip - Vector3(-2.4, 1.0, 0)).normalized(), cols[k % 4]))
	return {"node": n}


## Forest beetles, Old Barkhide: a living sapling growing out of the moss on his back.
func _hero_sapling(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bark := surf("bark_plate", Color(0.8, 0.7, 0.6), 4.0)
	var moss := surf("foliage", Color(0.7, 0.9, 0.45), 5.0)
	var leaves := surf("foliage", Color(0.85, 1.05, 0.6), 6.0)
	n.add_child(blob(Vector3(3.6, 3.0, 5.4), moss, Vector3(-2.0, -1.0, 0)))
	chain_rods(n, [Vector3(-2.0, 0.0, 0), Vector3(-3.0, 8.0, 0), Vector3(-2.0, 16.0, 0)], [1.2, 0.9, 0.6], bark)
	chain_rods(n, [Vector3(-3.0, 8.0, 0), Vector3(-6.0, 12.0, 2.0)], [0.6, 0.4], bark)
	n.add_child(blob(Vector3(5.0, 4.4, 5.0), leaves, Vector3(-2.0, 18.0, 0)))
	n.add_child(blob(Vector3(3.2, 3.0, 3.2), leaves, Vector3(-6.4, 13.6, 2.4)))
	n.add_child(blob(Vector3(0.7, 0.7, 0.7), plain(Color("#c83a2a")), Vector3(0.0, 17.0, 4.0)))   # a crab apple
	return {"node": n}


## Spiders, the Widow: a cartwheel of web on a bone hoop on her back, a spiderling in it.
func _hero_web_wheel(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bone := surf("bone", Color.WHITE, 2.0)
	var silk := plain(Color("#e4e0ec"))
	var at := Vector3(-3.0, 8.0, 0)
	n.add_child(rod(Vector3(-0.6, -2.0, 0), at, 0.4, 0.4, bone))
	n.add_child(ring(7.4, 8.2, bone, at, Vector3(0, 0, 90)))
	for k in 8:
		var a := TAU * k / 8.0
		n.add_child(rod(at, at + Vector3(0, cos(a) * 7.6, sin(a) * 7.6), 0.12, 0.12, silk, false))
	for r in [2.6, 5.0]:
		n.add_child(ring(r - 0.1, r + 0.1, silk, at, Vector3(0, 0, 90)))
	n.add_child(blob(Vector3(1.0, 1.0, 1.0), plain(Color("#1a1418")), at + Vector3(0.2, 2.0, 2.4)))
	return {"node": n}


## Centaurs, the Proud: a gold eagle standard on a pole, a team plaque under the eagle.
func _hero_aquila(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, -4, 0), Vector3(0, 24, 0), 0.5, 0.45, surf("wood_grain", Color.WHITE, 5.0), false))
	n.add_child(_box(Vector3(0.5, 5.0, 4.0), surf("cloth", c.team, 3.0), Vector3(0.4, 19.0, 0)))
	n.add_child(_box(Vector3(0.7, 0.6, 4.4), gold(), Vector3(0.4, 21.6, 0)))
	n.add_child(blob(Vector3(1.6, 1.4, 1.2), gold(), Vector3(0.4, 25.2, 0)))   # the eagle
	n.add_child(blob(Vector3(0.9, 0.8, 0.7), gold(), Vector3(1.8, 26.4, 0)))
	n.add_child(cone(0.05, 0.4, 1.0, gold(), Vector3(2.8, 26.2, 0), Vector3(0, 0, -100), 6))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.0, 3.0, 2.6), gold(), Vector3(-0.2, 27.0, 2.6 * side), Vector3(30 * side, 0, 0)))   # wings up
	n.add_child(ring(1.4, 2.2, gold(), Vector3(0, 23.6, 0)))
	return {"node": n}


## Bears, Honeypaw: a beehive strapped on his back, bees about it.
func _hero_beehive(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var straw := surf("thatch", Color(1.0, 0.9, 0.7), 3.0)
	for k in 5:
		n.add_child(ring(1.0, 1.25, straw, Vector3(-4.0, -2.0 + k * 2.0, 0), Vector3.ZERO, Vector3(4.6 - absf(k - 1.5) * 0.7, 2.2, 4.6 - absf(k - 1.5) * 0.7)))
	n.add_child(dome(Vector3(3.2, 2.4, 3.2), straw, Vector3(-4.0, 7.4, 0)))
	n.add_child(blob(Vector3(0.8, 1.0, 0.6), plain(Color("#1a1208")), Vector3(-4.0, -0.6, 4.6)))   # the door
	n.add_child(rod(Vector3(0.5, 2.0, -3.0), Vector3(0.5, 2.0, 3.0), 0.4, 0.4, surf("leather", Color.WHITE, 2.0)))
	for k in 4:
		var at := Vector3(-6.0 + k * 2.4, 6.0 + (k % 2) * 3.0, 5.0 - k * 2.6)
		n.add_child(blob(Vector3.ONE * 0.6, plain(Color("#f0d040")), at))
	return {"node": n}


## Bears, the Unwoken: his pillow, strapped on his back for later (it replaces the race's banner,
## whose pole went up through the nightcap).
func _hero_pillow(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var linen := surf("cloth", Color(0.92, 0.9, 0.96), 4.0)
	n.add_child(blob(Vector3(2.4, 6.0, 5.4), linen, Vector3(-2.8, -2.0, 0), Vector3(0, 0, 8)))
	for corner in [Vector3(-2.6, 3.6, 4.6), Vector3(-2.6, 3.6, -4.6), Vector3(-3.4, -7.4, 4.4), Vector3(-3.4, -7.4, -4.4)]:
		n.add_child(blob(Vector3(1.0, 1.0, 1.0), linen, corner))
	n.add_child(ring(5.0, 5.6, surf("leather", Color.WHITE, 2.0), Vector3(-1.6, -2.0, 0), Vector3(90, 0, 0), Vector3(0.6, 1, 1.2)))   # the strap
	for k in 3:
		n.add_child(blob(Vector3(0.4, 0.8, 0.4), plain(Color("#4a5ab0")), Vector3(-5.1, 1.0 - k * 3.0, (k - 1) * 2.4)))   # little blue stars
	return {"node": n}


# ================================================================== held

## Rats, the 10000th: a sceptre topped with a wedge of cheese in a gold cup.
func _hero_sceptre_cheese(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -4, 0), Vector3(3, 14, 0), 0.6, 0.6, gold()))
	n.add_child(ring(0.6, 1.2, gold(), Vector3(1.2, 6.0, 0), Vector3(0, 0, -12)))
	n.add_child(cone(2.4, 0.8, 2.0, gold(), Vector3(3.2, 15.0, 0), Vector3(0, 0, -12)))
	n.add_child(slab([Vector2(-2.5, 0), Vector2(3.0, 0), Vector2(0.5, 4.5)], 3.0, surf("cheese", Color.WHITE, 3.0), Vector3(3.4, 16.0, 0)))
	return {"node": n}


## Rats, the Unkillable: a butcher's cleaver the size of a door, rusted, over his shoulder.
func _hero_cleaver(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var rust := surf("iron", Color(1.15, 1.05, 1.0), 3.0)   # (bright steel: rusted, it read as a plank)
	n.add_child(rod(Vector3(4, -4, 0), Vector3(-2, 7, 0), 0.8, 0.8, surf("wood_grain", Color.WHITE, 3.0)))
	var b := slab([Vector2(0, 0), Vector2(15, 0), Vector2(16, 8), Vector2(1, 8)], 0.7, rust)
	b.position = Vector3(-2, 7, 0)
	b.rotation.z = deg_to_rad(118)
	n.add_child(b)
	n.add_child(blob(Vector3(1.0, 1.0, 0.6), plain(Color("#2a2420")), Vector3(-4.6, 10.0, 0.4)))   # the hanging hole
	return {"node": n}


## Frogs, Old Mossback: a gnarled staff, a lantern of fireflies hanging from its crook.
func _hero_lantern_staff(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("bark_plate", Color(0.75, 0.65, 0.55), 3.0)
	chain_rods(n, [Vector3(-1, -8, 0), Vector3(1, 6, 0), Vector3(3, 16, 0), Vector3(7, 19, 0), Vector3(8, 17, 0)], [0.8, 0.75, 0.7, 0.6, 0.5], wood)
	n.add_child(rod(Vector3(8, 17, 0), Vector3(8, 14.5, 0), 0.15, 0.15, plain(ROPE_HERO), false))
	n.add_child(cone(1.2, 1.6, 3.0, surf("wicker", Color.WHITE, 2.0), Vector3(8, 13.0, 0)))
	n.add_child(blob(Vector3(1.1, 1.3, 1.1), glow(Color("#d8f060")), Vector3(8, 13.0, 0)))
	return {"node": n}

const ROPE_HERO := Color("#c8b48a")


## Frogs, Twice-Drowned: a ship's anchor, rusted and weedy, over the shoulder.
func _hero_anchor(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var rust := surf("iron", Color(0.7, 0.55, 0.45), 3.0)
	var a := Vector3(5, -5, 0)
	var b := Vector3(-8, 18, 0)
	n.add_child(rod(a, b, 0.9, 0.9, rust))
	var d := (b - a).normalized()
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(b - across * 3.5, b + across * 3.5, 0.6, 0.6, rust))   # the stock
	n.add_child(ring(1.0, 1.7, rust, b + d * 1.6, Vector3(90, 0, 0)))
	for side in [1, -1]:   # the arms at the crown, curling up
		chain_rods(n, [a, a + across * 3.5 * side - d * 1.0, a + across * 5.0 * side + d * 2.5], [0.9, 0.8, 0.4], rust)
	chain_rods(n, [b + d * 0.5, b - across * 2.0 - d * 4.0, b + across * 1.0 - d * 8.0], [0.4, 0.3, 0.2], surf("reed_leaf", Color(0.55, 0.75, 0.45), 3.0))
	return {"node": n}


## Han, the Unmoved: a guandao (a long glaive, a curved blade with a notch), over the shoulder.
func _hero_guandao(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(6, -7, 0)
	var b := Vector3(-11, 22, 0)
	n.add_child(rod(a, b, 0.75, 0.7, surf("wood_grain", Color(0.7, 0.35, 0.25), 4.0), false))
	var d := (b - a).normalized()
	var blade_n := blade([Vector2(0, -1.0), Vector2(5, -2.6), Vector2(10, -2.4), Vector2(12.5, 0.5), Vector2(9, 1.2), Vector2(7, 2.6), Vector2(6, 1.2), Vector2(0, 1.4)], 0.6, surf("iron", Color(1.1, 1.1, 1.15), 3.0), b, atan2(d.y, d.x))
	n.add_child(blade_n)
	n.add_child(ring(0.7, 1.4, gold(), b - d * 0.3, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	n.add_child(blob(Vector3(1.0, 1.6, 1.0), plain(Color("#c02828")), b - d * 1.6))   # the red tassel
	return {"node": n}


## Forest beetles, Old Barkhide: a club of gnarled root, still sprouting, over the shoulder.
func _hero_root_club(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bark := surf("bark_plate", Color(0.8, 0.7, 0.6), 3.0)
	chain_rods(n, [Vector3(1.5, -1.5, 0), Vector3(-3, 5, 1.5), Vector3(-10, 12, 3.5)], [0.9, 1.3, 2.4], bark)
	n.add_child(blob(Vector3(3.2, 2.8, 2.8), bark, Vector3(-11.5, 13.5, 3.5)))
	for k in 3:
		var a := k * 2.1
		chain_rods(n, [Vector3(-11.5, 13.5, 3.5), Vector3(-11.5 + cos(a) * 3.5, 16.0 + sin(a) * 2.0, 3.5 + sin(a) * 2.5)], [1.0, 0.4], bark)
	n.add_child(blob(Vector3(1.4, 0.5, 1.0), surf("leaf", Color(0.7, 1.0, 0.5), 3.0), Vector3(-9, 16.5, 5.0), Vector3(0, 0, 30)))
	return {"node": n}


## Spiders, Eight-Eyes: a black cane with a silver skull for a knob.
func _hero_cane(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, 1, 0), Vector3(1, -11, 0), 0.4, 0.35, plain(Color("#141216"))))
	n.add_child(blob(Vector3(1.3, 1.4, 1.2), surf("iron", Color(1.2, 1.2, 1.25), 2.0), Vector3(0, 1.8, 0)))
	n.add_child(blob(Vector3(0.6, 0.5, 0.4), surf("iron", Color(1.2, 1.2, 1.25), 2.0), Vector3(0.9, 1.0, 0)))
	return {"node": n}


## Centaurs, Thunderhoof: a whole young tree trunk as a club, over the shoulder.
func _hero_trunk_club(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bark := surf("bark_plate", Color(0.85, 0.75, 0.62), 4.0)
	chain_rods(n, [Vector3(5, -5, 0), Vector3(-4, 9, 0), Vector3(-11, 21, 0)], [1.2, 1.9, 2.8], bark)
	n.add_child(cone(2.6, 2.6, 0.6, plain(Color("#d8b888")), Vector3(-11.3, 21.5, 0), Vector3(0, 0, 30), 14))
	chain_rods(n, [Vector3(-6, 12, 0), Vector3(-3, 16, 1.6)], [0.6, 0.3], bark)
	return {"node": n}


## Bears, the Unwoken: a log for a club, a bit of bedding still stuck to it.
func _hero_log_club(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bark := surf("bark_plate", Color(0.7, 0.6, 0.5), 4.0)
	chain_rods(n, [Vector3(-1, -3, 0), Vector3(2, 6, 0), Vector3(5, 16, 0)], [1.1, 1.8, 2.6], bark)
	n.add_child(cone(2.5, 2.5, 0.5, plain(Color("#d8b888")), Vector3(5.2, 16.6, 0), Vector3(0, 0, -16), 14))
	n.add_child(blob(Vector3(2.0, 1.0, 1.6), plain(Color("#c8d0f0")), Vector3(3.2, 10.0, 1.8), Vector3(0, 0, 20)))
	return {"node": n}


# ------------------------------------------------------------------ shields

## Rats, the Gnawer: a whole cheese wheel for a shield, a wedge bitten out, holes in it.
func _hero_cheese_wheel(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(4.6, 0.5, 0.4), SHIELD_FACE)
	var cheese := surf("cheese", Color.WHITE, 4.0)
	var rind := plain(Color("#c89a30"))
	h.add_child(disc(7.2, 2.4, rind, 0))
	h.add_child(disc(6.7, 2.6, cheese, 0))
	for k in 5:
		var a := k * 2.39996
		var hole := disc(0.6 + fmod(k * 0.37, 0.6), 0.4, plain(Color("#b08420")), 1.35)
		hole.position = Vector3(cos(a) * (1.8 + k * 0.8), sin(a) * (1.8 + k * 0.8), 1.35)
		h.add_child(hole)
	var bite := slab([Vector2(0, 0), Vector2(7.4, 2.3), Vector2(7.4, -2.3)], 2.8, plain(Color("#3a2a1a")))   # the bite, dark inside
	bite.rotation.z = 0.9
	h.add_child(bite)
	return {"node": n}


## Forest beetles, the Polished: a gilded leaf shield, polished to a shine.
func _hero_gold_shield(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(4.4, 0.5, 0.4), SHIELD_FACE)
	var outline := [Vector2(0, 9), Vector2(4, 5), Vector2(5, -1), Vector2(3, -6), Vector2(0, -9), Vector2(-3, -6), Vector2(-5, -1), Vector2(-4, 5)]
	h.add_child(slab(outline, 0.8, gold(1.1)))
	h.add_child(rod(Vector3(0, 8.5, 0.5), Vector3(0, -8.5, 0.5), 0.35, 0.35, gold(0.8)))
	for k in 3:
		h.add_child(rod(Vector3(0, 4.0 - k * 4.0, 0.5), Vector3(3.5, 6.0 - k * 4.0, 0.5), 0.25, 0.2, gold(0.8)))
		h.add_child(rod(Vector3(0, 4.0 - k * 4.0, 0.5), Vector3(-3.5, 6.0 - k * 4.0, 0.5), 0.25, 0.2, gold(0.8)))
	h.add_child(disc(1.8, 0.6, plain(c.team), 0.6))
	return {"node": n}
