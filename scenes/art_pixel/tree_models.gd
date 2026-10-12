extends RefCounted
## Trees for the pixel bake (milestone 15, phase 2), in world units (1 = a tile), built like
## the bug bushes and reed beds: authored texture cards (leaves, needles) over simple 3D
## bodies, with a bark-textured trunk. Three species, each in a few concept looks
## (`style`), for Dominic's pick (D-080):
##   broadleaf  0 leaf-card crown (the bushes' look, grown up)  1 painted lobes (foliage
##              texture, cards only at the edge)  2 slim birch
##   pine       0 tiers of needle cards  1 stacked textured cones  2 tall pine, flat crown
##   swamp      0 bald cypress (flared foot, knees, feathery spire)  1 weeping willow
##              2 stilt-rooted swamp gum
## `stage` 0-3 is how far it's been cut (the wood left): 0 standing; 1 felled, the trunk
## lying beside its stump with the crown's branches; 2 the log half sawn up; 3 the stump.
## Seeded (cosmetic RNG, view side): each seed is a different shape, size and turn.

const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")

const SPECIES := ["broadleaf", "pine", "swamp"]
const VIEW_UP := Vector3(0.25, 0.8, 0.45)   # needle cards lie mostly flat, tipped to the camera

var um := UnitModels.new()
var rng := RandomNumberGenerator.new()
var _mats := {}   # card + quantised tint -> material (thousands of cards share a few dozen)


func tree(seed_value: int, species: String, style := 0, stage := 0) -> Node3D:
	rng.seed = seed_value * 31 + SPECIES.find(species) * 7 + style
	var size := rng.randf_range(0.88, 1.12)
	var lean := Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
	var fall := rng.randf() * TAU   # where it falls when felled
	var n := Node3D.new()
	var look := _look(species, style)
	var h: float = look.height * size
	if stage == 0:
		n.add_child(_standing(species, style, size, lean, look))
	else:
		n.add_child(_stump(look, size))
		if stage < 3:
			n.add_child(_felled(look, size, h, fall, stage))
	return n


## Shared numbers per species and look: height, trunk radius and bark colour.
func _look(species: String, style: int) -> Dictionary:
	match species:
		"pine":
			return {"height": [2.3, 2.2, 2.6][style], "trunk": 0.085, "bark": [Color(1.0, 1.0, 1.15), Color(0.9, 0.95, 1.1), Color(1.25, 1.0, 0.9)][style],
				"leaf": Color(0.32, 0.46, 0.34)}
		"swamp":
			return {"height": [2.4, 1.9, 2.0][style], "trunk": [0.11, 0.1, 0.09][style], "bark": [Color(1.2, 1.15, 1.25), Color(1.0, 1.05, 1.2), Color(1.35, 1.4, 1.5)][style],
				"leaf": [Color(0.7, 0.72, 0.4), Color(0.6, 0.72, 0.4), Color(0.45, 0.56, 0.36)][style]}
	return {"height": [2.1, 2.1, 2.3][style], "trunk": [0.1, 0.1, 0.06][style], "bark": [Color(1.05, 1.1, 1.3), Color(1.05, 1.1, 1.3), Color("#e8e2d4")][style], "plain": style == 2,
		"leaf": [Color(0.5, 0.6, 0.38), Color(0.5, 0.6, 0.38), Color(0.66, 0.74, 0.4)][style]}


func _bark(look: Dictionary) -> Material:
	return um.plain(look.bark) if look.get("plain", false) else um.surf("bark_plate", look.bark, 2.0)


func _standing(species: String, style: int, size: float, lean: Vector3, look: Dictionary) -> Node3D:
	var n := Node3D.new()
	var h: float = look.height * size
	var bark := _bark(look)
	var r: float = look.trunk * size
	match species + str(style):
		"broadleaf0", "broadleaf1":
			var top := Vector3(0, h * 0.5, 0) + lean * h
			_trunk(n, Vector3.ZERO, top, r, bark)
			for k in 3:   # boughs into the crown
				var a := rng.randf() * TAU
				n.add_child(um.rod(top * 0.85, top + Vector3(cos(a) * 0.3, rng.randf_range(0.15, 0.35), sin(a) * 0.3) * size, r * 0.6, r * 0.3, bark, false))
			var lobes := _lobes(top + Vector3(0, 0.5 * size, 0), 0.4 * size, 0.42 * size, rng.randi_range(6, 8))
			if style == 0:
				_card_crown(n, lobes, "leaf", 0.12 * size, 1500, look.leaf)
			else:
				_painted_crown(n, lobes, look.leaf, 0.13 * size)
		"broadleaf2":   # a birch, often two stems
			for k in rng.randi_range(1, 2):
				var off := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14)) * k
				var top := off + Vector3(0, h * 0.8, 0) + lean * h * (1.0 + k)
				_trunk(n, off, top, r, bark)
				for j in 6:   # dark marks on the white bark
					var t := rng.randf_range(0.1, 0.8)
					var p := off.lerp(top, t)
					n.add_child(um.blob(Vector3(r * 1.04, 0.012, r * 1.04), um.plain(Color("#2a2420")), p))
				var lobes := _lobes(off.lerp(top, 0.8), 0.22 * size, 0.3 * size, 6)
				_card_crown(n, lobes, "leaf", 0.09 * size, 900, look.leaf)
		"pine0":
			_trunk(n, Vector3.ZERO, Vector3(0, h * 0.82, 0) + lean * h, r, bark)
			var tiers := 10
			for t in tiers:
				var f := float(t) / tiers
				var y := lerpf(0.35, 0.95, f) * h
				var spread := lerpf(0.62, 0.1, f) * size
				var at := Vector3(0, y, 0) + lean * y
				var cards := int(lerpf(90, 18, f))
				for k in cards:
					var a := float(k) / cards * TAU + rng.randf_range(-0.2, 0.2)
					var out := Vector3(cos(a), 0, sin(a))
					var len := spread * rng.randf_range(0.8, 1.15)
					var down := (out + Vector3(0, -0.45, 0)).normalized()
					var mid := at + down * len * 0.5
					var shade := clampf(f * 0.6 + (0.5 + 0.5 * out.dot(Vector3(-0.6, 0, 0.8))) * 0.4, 0.0, 1.0)
					var tint: Color = Color(0.22, 0.32, 0.24).lerp(Color(0.62, 0.78, 0.55), shade)
					n.add_child(_card("reed_leaf", 0.16 * size, len, mid, VIEW_UP, true, down, tint))
				n.add_child(um.cone(0.02, spread * 0.55, spread * 0.4, um.plain(Color("#1a2a1c")), at + Vector3(0, -spread * 0.12, 0)))
		"pine1":
			_trunk(n, Vector3.ZERO, Vector3(0, h * 0.5, 0), r, bark)
			var fol := um.surf("foliage", Color(0.62, 0.78, 0.62), 0.6)
			for t in 4:
				var f := float(t) / 4.0
				var rb := lerpf(0.6, 0.22, f) * size
				var ch := lerpf(0.75, 0.55, f) * size
				var y := lerpf(0.3, 1.45, f) * size + ch * 0.5
				var c := um.cone(0.0, rb, ch, fol, Vector3(0, y, 0) + lean * y, Vector3(0, rng.randf() * 90, 0), 9)
				n.add_child(c)
				for k in 26:   # ragged edge: needle cards round each cone's skirt
					var a := rng.randf() * TAU
					var out := Vector3(cos(a), 0, sin(a))
					var down := (out + Vector3(0, -0.6, 0)).normalized()
					var at := Vector3(0, y - ch * 0.4, 0) + out * rb * 0.85 + lean * y
					n.add_child(_card("reed_leaf", 0.14 * size, 0.22 * size, at, VIEW_UP, true, down, Color(0.3, 0.42, 0.3).lerp(Color(0.6, 0.75, 0.55), rng.randf())))
		"pine2":   # tall, bare below, a flat crown of needle clumps up top
			var top := Vector3(0, h * 0.88, 0) + lean * h
			_trunk(n, Vector3.ZERO, top, r, bark)
			for k in 5:
				var a := rng.randf() * TAU
				var y := rng.randf_range(0.7, 0.95) * h
				var tip := Vector3(cos(a) * 0.38, y + 0.08, sin(a) * 0.38) * Vector3(size, 1, size) + lean * y
				n.add_child(um.rod(Vector3(0, y - 0.1, 0) + lean * y, tip, r * 0.45, r * 0.2, bark, false))
				var lobes := _lobes(tip + Vector3(0, 0.05, 0), 0.08 * size, 0.22 * size, 2, 0.35)
				_card_crown(n, lobes, "reed_leaf", 0.12 * size, 260, look.leaf, 0.3)
			_card_crown(n, _lobes(top + Vector3(0, 0.12, 0), 0.05, 0.24 * size, 2, 0.4), "reed_leaf", 0.12 * size, 260, look.leaf, 0.3)
		"swamp0":   # bald cypress: flared buttress foot, knees, a narrow feathery spire
			var top := Vector3(0, h * 0.92, 0) + lean * h
			_trunk(n, Vector3.ZERO, top, r * 0.8, bark)
			n.add_child(um.cone(r * 0.9, r * 2.6, 0.45 * size, bark, Vector3(0, 0.22 * size, 0), Vector3.ZERO, 9))
			for k in rng.randi_range(4, 7):   # cypress knees poking from the mud
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.28, 0.45)
				n.add_child(um.cone(0.008, 0.035, rng.randf_range(0.08, 0.16), bark, Vector3(cos(a) * d, 0.05, sin(a) * d)))
			var lobes := []
			for t in 5:
				var f := t / 5.0
				lobes.append([Vector3(0, lerpf(0.45, 0.88, f) * h, 0) + lean * h * f, Vector3(1, 0.7, 1) * lerpf(0.42, 0.16, f) * size])
			_card_crown(n, lobes, "reed_leaf", 0.12 * size, 1300, look.leaf, 0.3)
		"swamp1":   # weeping willow
			var top := Vector3(0, h * 0.55, 0) + lean * h
			_trunk(n, Vector3.ZERO, top, r, bark)
			var lobes := _lobes(top + Vector3(0, 0.3 * size, 0), 0.6 * size, 0.38 * size, 6)
			_card_crown(n, lobes, "leaf", 0.1 * size, 1100, look.leaf)
			for k in 420:   # the hanging curtain
				var l: Array = lobes[k % lobes.size()]
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.6), rng.randf_range(-1, 1)).normalized()
				var at := UnitModels.on_surface(l[0], l[1], d, -0.02)
				var len := rng.randf_range(0.4, 0.85) * size
				len = minf(len, at.y - 0.12)
				var out := Vector3(d.x, 0, d.z).normalized()
				var tint := Color(0.45, 0.55, 0.32).lerp(Color(0.9, 0.95, 0.6), rng.randf() * 0.5 + 0.3 * float(out.dot(Vector3(-0.6, 0, 0.8)) > 0))
				n.add_child(_card("reed_leaf", 0.06 * size, len, at + Vector3(0, -len * 0.5, 0), Vector3(0.5, 0, 1).normalized(), true, Vector3.UP, tint))
		"swamp2":   # stilt roots arching into the water, a rounded crown
			var top := Vector3(0, h * 0.55, 0) + lean * h
			var foot := Vector3(0, 0.38 * size, 0)
			_trunk(n, foot, top, r, bark)
			for k in 7:
				var a := float(k) / 7.0 * TAU + rng.randf_range(-0.3, 0.3)
				var ground := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.28, 0.42) * size
				var knee := foot.lerp(ground, 0.5) + Vector3(0, 0.16 * size, 0)
				n.add_child(um.rod(foot + Vector3(0, 0.05, 0), knee, r * 0.45, r * 0.35, bark, false))
				n.add_child(um.rod(knee, ground, r * 0.35, r * 0.3, bark, true))
			var lobes := _lobes(top + Vector3(0, 0.4 * size, 0), 0.55 * size, 0.36 * size, 7)
			_card_crown(n, lobes, "leaf", 0.12 * size, 1400, look.leaf)
	return n


## A trunk from a to b, flared a little at the foot, in bark.
func _trunk(n: Node3D, a: Vector3, b: Vector3, r: float, bark: Material) -> void:
	n.add_child(um.rod(a, b, r, r * 0.6, bark, false))
	n.add_child(um.cone(r * 1.0, r * 1.5, r * 2.0, bark, a + Vector3(0, r, 0), Vector3.ZERO, 10))


## Lobes of a crown round `centre`: [centre, radii].
func _lobes(centre: Vector3, spread: float, r: float, count: int, flat := 0.8) -> Array:
	var out := []
	for k in count:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 1.0) * spread
		var rr := r * rng.randf_range(0.8, 1.15)
		out.append([centre + Vector3(cos(a) * d, rng.randf_range(-0.6, 0.7) * r, sin(a) * d), Vector3(rr, rr * flat, rr)])
	return out


## A crown of cards (leaves or needles) over the lobes: a dark core you can't see through,
## lit on top and towards the light, the outline broken by single cards.
func _card_crown(n: Node3D, lobes: Array, card: String, w: float, count: int, tint: Color, aspect := 1.3) -> void:
	var lo := INF
	var hi := -INF
	var core := um.plain(Color(tint.r * 0.42, tint.g * 0.46, tint.b * 0.34))
	for l in lobes:
		lo = minf(lo, l[0].y - l[1].y)
		hi = maxf(hi, l[0].y + l[1].y)
		n.add_child(um.blob(l[1] * 0.86, core, l[0]))
	for k in count:
		var l: Array = lobes[k % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)).normalized()
		var depth := rng.randf_range(-0.06, 0.02)
		var face := (d + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		var at := UnitModels.on_surface(l[0], l[1], d, depth)
		var lit := clampf((at.y - lo) / maxf(hi - lo, 0.01), 0.0, 1.0) * 0.55 + clampf(d.dot(Vector3(-0.5, 0.5, 0.7)), 0.0, 1.0) * 0.3 + (depth + 0.06) / 0.08 * 0.15
		var c := Color(tint.r * 0.62, tint.g * 0.66, tint.b * 0.62).lerp(Color(minf(tint.r * 1.8, 1.0), minf(tint.g * 1.6, 1.0), minf(tint.b * 1.7, 1.0)), lit)
		n.add_child(_card(card, w, w * aspect, at, face, true, d, c))


## A painted crown: lobes in the foliage texture, a fringe of leaf cards to break the outline.
func _painted_crown(n: Node3D, lobes: Array, tint: Color, w: float) -> void:
	for l in lobes:
		var m := um.surf("foliage", Color(tint.r * 1.6, tint.g * 1.5, tint.b * 1.5), 0.45)
		n.add_child(um.blob(l[1], m, l[0], Vector3(0, rng.randf() * 180, 0)))
	for k in 180:
		var l: Array = lobes[k % lobes.size()]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		var at := UnitModels.on_surface(l[0], l[1], d, 0.0)
		var lit := clampf(d.y * 0.5 + 0.5, 0.0, 1.0)
		n.add_child(_card("leaf", w, w * 1.3, at, d, true, Vector3.UP, Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.8).lerp(Color(1.0, 1.0, 0.8), lit * 0.6)))


## What's left when a tree is cut: a stump with a pale cut face and a few chips.
func _stump(look: Dictionary, size: float) -> Node3D:
	var n := Node3D.new()
	var r: float = look.trunk * size * 1.25
	var sh := 0.13 * size
	var bark := _bark(look)
	n.add_child(um.cone(r * 0.95, r * 1.35, sh, bark, Vector3(0, sh * 0.5, 0), Vector3(0, 0, 0), 10))
	n.add_child(um.cone(r * 0.85, r * 0.9, 0.012, um.plain(Color("#d8b880")), Vector3(0, sh + 0.004, 0), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), 10))
	var chip := um.plain(Color("#c8a46a"))
	for k in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.12, 0.32)
		n.add_child(um.blob(Vector3(0.03, 0.008, 0.018), chip, Vector3(cos(a) * d, 0.006, sin(a) * d), Vector3(0, rng.randf() * 180, 0)))
	return n


## The felled trunk lying beside the stump (stage 1), or half of it sawn away (stage 2).
func _felled(look: Dictionary, size: float, h: float, fall: float, stage: int) -> Node3D:
	var n := Node3D.new()
	var r: float = look.trunk * size
	var dir := Vector3(cos(fall), 0, sin(fall))
	var len := (0.85 if stage == 1 else 0.45) * size
	var a := dir * 0.12 + Vector3(0, r, 0)
	var b := a + dir * len
	n.add_child(um.rod(a, b, r, r * 0.8, _bark(look), true))
	n.add_child(um.cone(r * 0.95, r * 0.95, 0.01, um.plain(Color("#d8b880")), a - dir * 0.005))
	n.get_child(-1).basis = Basis(Quaternion(Vector3.UP, dir))
	if stage == 1:   # the lopped crown's twigs at the far end
		var lobes := [[b + Vector3(0, 0.1, 0), Vector3(0.18, 0.1, 0.18) * size], [b + dir * 0.14 + Vector3(0, 0.08, 0), Vector3(0.14, 0.08, 0.14) * size]]
		var tint: Color = look.leaf * Color(1.1, 0.95, 0.75)
		_card_crown(n, lobes, "leaf", 0.09 * size, 90, tint)
	return n


## A card (an authored picture with crisp alpha on a quad), as UnitModels.decal but with the
## material shared between cards of about the same tint, so a crown of a thousand leaves bakes fast.
func _card(name: String, w: float, h: float, pos: Vector3, facing: Vector3, lit := true, up := Vector3.UP, tint := Color.WHITE) -> MeshInstance3D:
	var q := Color(snappedf(tint.r, 0.04), snappedf(tint.g, 0.04), snappedf(tint.b, 0.04))
	var key := "%s|%s" % [name, q.to_html(false)]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = um.tex(name)
		m.albedo_color = q
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mats[key] = m
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _mats[key]
	mi.position = pos
	var f := facing.normalized()
	var u := up if absf(f.dot(up.normalized())) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-f, u)
	return mi
