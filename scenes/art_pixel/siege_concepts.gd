extends "res://scenes/art_pixel/unit_models.gd"
## Siege engine concepts (milestone 13, D-080: options first). Nothing here is in play.
## Ids: "siege.<engine>.<direction>.<family>", e.g. "siege.ram.a.timber":
##   engine     ram, catapult, bolt
##   direction  a: the engine alone (its crew hidden or implied, it moves as one thing)
##              b: the crew shows (the race's own units push, pull or aim it: the sockets
##                 "crew0".."crew3" say where they stand; the forest ram is pushed by a beetle)
##   family     timber (every human culture, trimmed in its cloth), swamp (frogs), sewer (rats),
##              forest (beetles), spooky (spiders)
## Same frame as the unit parts: part units, x forward, y up, z towards the viewer's side,
## standing on y = 0. A soldier is about 35 tall; a ram about 46 long.

const ROPE := Color("#c8b48a")
const DARK_WOOD := Color(0.45, 0.38, 0.36)


func has(id: String) -> bool:
	return id.begins_with("siege.") or super.has(id)


func build(id: String, colours: Dictionary) -> Dictionary:
	if not id.begins_with("siege."):
		return super.build(id, colours)
	var p := id.split(".")
	var s := _style(p[3], colours)
	# The engines are built at a soldier's scale and grown to their size here (sockets too).
	return _scaled(call("_%s_%s" % [p[1], p[2]], s, colours), {"ram": 1.0, "catapult": 1.5, "bolt": 1.6}[p[1]])


# ------------------------------------------------------------------ the family's materials

func _style(fam: String, c: Dictionary) -> Dictionary:
	var s := {"fam": fam, "team": surf("cloth", c.team, 3.0), "rope": plain(ROPE)}
	match fam:
		"timber":
			s.wood = surf("wood_grain", Color.WHITE, 8.0)
			s.dark = surf("wood_grain", Color(0.7, 0.62, 0.55), 6.0)
			s.metal = surf("iron", Color.WHITE, 4.0)
			s.roof = surf("hide", Color(0.72, 0.56, 0.42), 6.0)
			s.trim = surf("cloth", c.cloth, 3.0)
			s.ammo = surf("rock", Color.WHITE, 4.0)
		"swamp":
			s.wood = surf("reed_stalk", Color.WHITE, 5.0)
			s.dark = surf("bark_plate", Color(0.8, 0.85, 0.7), 6.0)
			s.metal = surf("rock", Color(0.8, 0.85, 0.8), 4.0)
			s.roof = surf("lily_pad", Color.WHITE, 30.0)
			s.trim = surf("reed_leaf", Color.WHITE, 4.0)
			s.ammo = surf("frog_belly", Color("#6a7a3a"), 4.0)   # a ball of swamp mud
		"sewer":
			s.wood = surf("wood_grain", Color(1.0, 0.92, 0.8), 6.0)
			s.dark = surf("wood_grain", Color(0.75, 0.65, 0.55), 6.0)
			s.metal = surf("bld_tin", Color(0.85, 0.87, 0.92), 10.0)
			s.roof = plain(Color("#7d838c"))
			s.roof.metallic = 0.0
			s.roof.roughness = 0.55
			s.trim = surf("bronze", Color.WHITE, 3.0)   # bottle caps
			s.ammo = surf("cheese", Color.WHITE, 4.0)
		"forest":
			s.wood = surf("bark_plate", Color(0.95, 0.9, 0.8), 6.0)
			s.dark = surf("wood_grain", Color(0.8, 0.7, 0.6), 6.0)
			s.metal = surf("chitin", Color("#4a3a5a"), 4.0)
			s.roof = surf("foliage", Color(0.95, 1.05, 0.85), 7.0)
			s.trim = surf("acorn_cap", Color.WHITE, 3.0)
			s.ammo = surf("acorn_cap", Color(1.1, 1.0, 0.9), 3.0)
		"spooky":
			s.wood = surf("wood_grain", DARK_WOOD, 7.0)
			s.dark = surf("wood_grain", Color(0.3, 0.26, 0.28), 6.0)
			s.metal = surf("bone", Color.WHITE, 3.0)
			s.roof = surf("hide", Color(0.38, 0.33, 0.4), 6.0)
			s.trim = surf("bone", Color.WHITE, 3.0)
			s.ammo = surf("bone", Color(0.9, 0.95, 1.0), 3.0)
	return s


# ------------------------------------------------------------------ helpers

## A squared timber from a to b, `w` wide and `h` deep.
func beam(a: Vector3, b: Vector3, w: float, h: float, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(a.distance_to(b), h, w)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.RIGHT, d)) if not d.is_equal_approx(Vector3.LEFT) else Basis(Vector3.UP, PI)
	return mi


## A wheel on an axle along z, centred at `at`.
func wheel(n: Node3D, at: Vector3, r: float, thick: float, s: Dictionary) -> void:
	match s.fam:
		"sewer":   # a bottle cap: a crimped bronze rim round a flat face
			n.add_child(cone(r, r, thick, s.trim, at, Vector3(90, 0, 0), 14))
			n.add_child(cone(r * 0.75, r * 0.75, thick + 0.3, plain(Color("#d8d0b8")), at, Vector3(90, 0, 0), 20))
		"forest":   # a slice of log, rings showing
			n.add_child(cone(r, r, thick, s.wood, at, Vector3(90, 0, 0), 16))
			n.add_child(cone(r * 0.85, r * 0.85, thick + 0.3, plain(Color("#c8a070")), at, Vector3(90, 0, 0), 16))
			n.add_child(cone(r * 0.4, r * 0.4, thick + 0.5, plain(Color("#a07848")), at, Vector3(90, 0, 0), 12))
		"spooky":   # a dark rim with bone spokes
			n.add_child(ring(r * 0.78, r, s.wood, at, Vector3(90, 0, 0), Vector3(1, thick * 1.2, 1)))
			for k in 6:
				var a := TAU * k / 6.0 + 0.3
				n.add_child(rod(at, at + Vector3(cos(a), sin(a), 0) * r * 0.85, 0.35, 0.3, s.metal, false))
			n.add_child(blob(Vector3.ONE * r * 0.22, s.metal, at))
		_:   # spoked timber with an iron tyre
			n.add_child(ring(r * 0.8, r, s.metal if s.fam == "timber" else s.wood, at, Vector3(90, 0, 0), Vector3(1, thick * 1.2, 1)))
			for k in 6:
				var a := TAU * k / 6.0
				n.add_child(rod(at, at + Vector3(cos(a), sin(a), 0) * r * 0.85, 0.45, 0.4, s.wood, false))
			n.add_child(cone(r * 0.25, r * 0.25, thick + 0.6, s.dark, at, Vector3(90, 0, 0), 10))


## Four wheels (or a sledge's runners, for the frogs) under a chassis `len` long and `wide` across.
func undercarriage(n: Node3D, s: Dictionary, len: float, wide: float, r: float, x0 := 0.0) -> void:
	if s.fam == "swamp":
		# A lily-pad sledge: two reed runners curling up at the front, a pad laid over them.
		for side in [1, -1]:
			var z: float = wide * 0.5 * side
			n.add_child(rod(Vector3(x0 - len * 0.5, 1.0, z), Vector3(x0 + len * 0.4, 1.0, z), 1.0, 1.0, s.wood, false))
			n.add_child(rod(Vector3(x0 + len * 0.4, 1.0, z), Vector3(x0 + len * 0.55, 3.5, z), 1.0, 0.8, s.wood))
		var pad := cone(len * 0.42, len * 0.42, 0.8, plain(Color("#4f9d4a")), Vector3(x0, 2.4, 0), Vector3.ZERO, 28)
		pad.scale = Vector3(1, 1, wide / len * 1.5)
		n.add_child(pad)
		return
	for fx in [-1, 1]:
		for side in [1, -1]:
			wheel(n, Vector3(x0 + fx * len * 0.3, r, (wide * 0.5 + 1.2) * side), r, 1.6, s)
	for fx in [-1, 1]:
		n.add_child(rod(Vector3(x0 + fx * len * 0.3, r, -wide * 0.5 - 1.0), Vector3(x0 + fx * len * 0.3, r, wide * 0.5 + 1.0), 0.6, 0.6, s.dark, false))


## A small flag on a pole (team colour), `h` tall from `at`.
func pennant(n: Node3D, s: Dictionary, at: Vector3, h: float, size := 4.0) -> void:
	n.add_child(rod(at, at + Vector3(0, h, 0), 0.35, 0.3, s.dark if s.fam != "swamp" else s.wood))
	var top := at + Vector3(0, h - 0.3, 0)
	var flag := slab([Vector2(0, 0), Vector2(-size * 1.3, -size * 0.25), Vector2(-size * 1.1, -size * 0.6), Vector2(0, -size * 0.75)], 0.3, s.team, top)
	n.add_child(flag)


## The ram's business end, at `tip`, pointing +x, per family.
func ram_head(n: Node3D, s: Dictionary, tip: Vector3, r: float) -> void:
	match s.fam:
		"timber":   # an iron cap with a ring behind it
			n.add_child(cone(r * 0.35, r * 1.15, 5.0, s.metal, tip + Vector3(2.5, 0, 0), Vector3(0, 0, -90)))
			n.add_child(ring(r * 0.9, r * 1.3, s.metal, tip + Vector3(-1.0, 0, 0), Vector3(0, 0, 90)))
			n.add_child(ring(r * 0.9, r * 1.3, s.metal, tip + Vector3(-12.0, 0, 0), Vector3(0, 0, 90)))
		"swamp":   # a river stone lashed on with reed
			n.add_child(blob(Vector3(4.2, 3.6, 3.6), s.metal, tip + Vector3(3.0, 0, 0)))
			n.add_child(ring(r * 0.9, r * 1.25, s.trim, tip + Vector3(-0.5, 0, 0), Vector3(0, 0, 90)))
		"sewer":   # a pencil, sharpened
			n.add_child(cone(0.25, r * 1.0, 5.5, plain(Color("#e8c890")), tip + Vector3(2.7, 0, 0), Vector3(0, 0, -90), 6))
			n.add_child(cone(0.1, 0.6, 1.6, plain(Color("#3a3a40")), tip + Vector3(5.6, 0, 0), Vector3(0, 0, -90), 6))
		"forest":   # a rhinoceros beetle's horn, curving up
			var pts := [tip, tip + Vector3(4.5, 0.6, 0), tip + Vector3(8, 2.8, 0), tip + Vector3(9.5, 6.0, 0)]
			var rr := [r * 1.0, r * 0.75, r * 0.45, 0.3]
			for k in range(1, pts.size()):
				n.add_child(rod(pts[k - 1], pts[k], rr[k - 1], rr[k], s.metal))
		"spooky":   # a great skull
			n.add_child(blob(Vector3(4.6, 4.2, 4.0), s.metal, tip + Vector3(2.6, 0.8, 0)))
			n.add_child(blob(Vector3(2.8, 1.6, 3.0), s.metal, tip + Vector3(5.0, -2.2, 0)))
			for side in [1, -1]:
				n.add_child(blob(Vector3(1.1, 1.3, 1.0), plain(Color("#141018")), tip + Vector3(6.0, 1.2, 1.7 * side)))


## The ram's log from x0 to x1 at height y, with its head.
func ram_log(n: Node3D, s: Dictionary, x0: float, x1: float, y: float, r: float) -> void:
	if s.fam == "sewer":   # the pencil's painted hexagonal barrel
		var p := cone(r, r, x1 - x0, plain(Color("#e8b830")), Vector3((x0 + x1) * 0.5, y, 0), Vector3(0, 0, -90), 6)
		n.add_child(p)
		n.add_child(cone(r * 1.02, r * 1.02, 2.0, plain(Color("#e89aa0")), Vector3(x0 - 1.0, y, 0), Vector3(0, 0, -90), 12))   # the rubber
		n.add_child(cone(r * 1.06, r * 1.06, 1.6, s.metal, Vector3(x0 + 0.6, y, 0), Vector3(0, 0, -90), 12))
	elif s.fam == "swamp":   # a bundle of reeds bound tight
		for k in 5:
			var a := TAU * k / 5.0
			var o := Vector3(0, cos(a), sin(a)) * r * 0.55
			n.add_child(rod(Vector3(x0, y, 0) + o, Vector3(x1, y, 0) + o, r * 0.5, r * 0.5, s.wood, false))
		for x in [x0 + 4.0, (x0 + x1) * 0.5, x1 - 3.0]:
			n.add_child(ring(r * 0.9, r * 1.2, s.trim, Vector3(x, y, 0), Vector3(0, 0, 90)))
	else:
		n.add_child(rod(Vector3(x0, y, 0), Vector3(x1, y, 0), r, r * 0.95, s.wood if s.fam != "timber" else s.dark))
	ram_head(n, s, Vector3(x1, y, 0), r)


# ------------------------------------------------------------------ ram

## A: a covered ram. A low roofed shed on wheels (a sledge for frogs), its eaves nearly to
## the ground like a tortoise's shell, the log's head out in front; the crew is inside, never
## seen. Team colour: a cloth over the roof's ridge (a rag, a leaf banner...).
func _ram_a(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 44.0
	var W := 16.0
	var wr := 4.2
	undercarriage(n, s, L * 0.9, W, wr)
	var base := wr + 1.0 if s.fam != "swamp" else 3.0
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5 * side), Vector3(L * 0.5, base, W * 0.5 * side), 1.6, 1.6, s.dark))
	ram_log(n, s, -L * 0.5 - 1.0, L * 0.5 + 13.0, base + 5.0, 3.6)
	var eave := base + 3.0
	var ridge := base + 19.0
	match s.fam:
		"swamp":   # reed posts under three great lily pads, overlapping like scales
			for x in [-L * 0.4, 0.0, L * 0.4]:
				for side in [1, -1]:
					n.add_child(rod(Vector3(x, base, W * 0.45 * side), Vector3(x, ridge - 4.0, W * 0.2 * side), 0.8, 0.7, s.wood))
			for k in 3:
				var pad := dome(Vector3(L * 0.3, 11.0 - k * 1.0, W * 0.75), s.roof, Vector3(-L * 0.3 + k * L * 0.28, base + 2.0 + k * 0.8, 0))
				n.add_child(pad)
			n.add_child(blob(Vector3(3.0, 0.8, 2.6), s.team, Vector3(-L * 0.28, base + 13.4, 0)))
			pennant(n, s, Vector3(-L * 0.42, base + 8.0, 0), 13.0)
			return {"node": n}
		"sewer":   # an upturned sardine tin for a shell, the key-rolled lid curled up at the back
			n.add_child(_box(Vector3(L, 12.0, W + 3.0), s.roof, Vector3(0, base + 7.0, 0)))
			n.add_child(_box(Vector3(L - 1.5, 0.6, W + 1.6), plain(Color("#d8d8dc")), Vector3(0, base + 13.2, 0)))
			for k in 4:   # the tin's pressed ribs
				n.add_child(_box(Vector3(0.6, 12.4, W + 3.4), s.roof, Vector3(-L * 0.36 + k * L * 0.24, base + 7.0, 0)))
			n.add_child(_box(Vector3(L * 0.5, 5.0, W + 3.6), plain(Color("#c8a040")), Vector3(L * 0.05, base + 6.5, 0)))   # the printed label
			n.add_child(_box(Vector3(L * 0.3, 2.0, W + 3.8), plain(Color("#8a2a24")), Vector3(L * 0.05, base + 6.5, 0)))
			n.add_child(ring(2.0, 3.0, s.roof, Vector3(-L * 0.5 - 1.0, base + 14.5, 0), Vector3(90, 0, 0), Vector3(1, W * 0.5, 1)))
			n.add_child(_box(Vector3(L * 0.14, 0.5, W * 0.45), s.team, Vector3(L * 0.22, base + 13.7, 0), Vector3(0, 8, 0)))   # a rag laid on top
			return {"node": n}
	var half := W * 0.5 + 3.0
	var ang := atan2(ridge - eave, half)
	var slope := sqrt(half * half + (ridge - eave) * (ridge - eave))
	for side in [1, -1]:
		var panel := _box(Vector3(L + 2.0, 1.2, slope), s.roof, Vector3(0, (eave + ridge) * 0.5, half * 0.5 * side))
		panel.rotation.x = ang * side
		n.add_child(panel)
	# A point on the roof's outside: `along` 0 at the ridge to 1 at the eave, `d` out from it.
	var out := func(side: int, along: float, d: float) -> Vector3:
		return Vector3(0, ridge - (ridge - eave) * along + cos(ang) * d, half * along * side + sin(ang) * d * side)
	match s.fam:
		"timber":
			n.add_child(beam(Vector3(-L * 0.5 - 1.0, ridge + 0.6, 0), Vector3(L * 0.5 + 1.0, ridge + 0.6, 0), 1.6, 1.6, s.dark))
			for x in [-L * 0.3, 0.0, L * 0.3]:   # battens holding the hides down
				for side in [1, -1]:
					n.add_child(beam(Vector3(x, 0, 0) + out.call(side, 0.0, 0.7), Vector3(x, 0, 0) + out.call(side, 1.0, 0.7), 0.9, 0.9, s.dark))
			for side in [1, -1]:   # a hem in the culture's cloth along the eaves, a team cloth over the ridge
				n.add_child(beam(Vector3(-L * 0.5 - 1.0, 0, 0) + out.call(side, 0.95, 0.5), Vector3(L * 0.5 + 1.0, 0, 0) + out.call(side, 0.95, 0.5), 1.6, 1.0, s.trim))
				var drape := _box(Vector3(5.0, 0.5, slope * 0.4), s.team, Vector3(-L * 0.18, 0, 0) + out.call(side, 0.25, 0.8))
				drape.rotation.x = ang * side
				n.add_child(drape)
		"forest":   # overlapping leaves over twig ribs, an acorn cap at each end of the ridge
			var tints := [Color(0.85, 1.0, 0.8), Color(1.0, 1.05, 0.75), Color(0.75, 0.92, 0.7)]
			for row in 1:   # a fringe of big leaves along the eaves
				for k in 5:
					var x := -L * 0.42 + k * L * 0.21 + row * L * 0.1
					for side in [1, -1]:
						var at: Vector3 = Vector3(x, 0, 0) + out.call(side, 0.86, 0.9)
						n.add_child(blob(Vector3(5.5, 0.6, slope * 0.22), surf("leaf", tints[(k + row) % 3] * 1.25, 8.0), at, Vector3(rad_to_deg(ang) * side, (k % 2) * 14 - 7, 0)))
			n.add_child(beam(Vector3(-L * 0.5 - 1.0, ridge + 1.0, 0), Vector3(L * 0.5 + 1.0, ridge + 1.0, 0), 1.6, 1.6, s.wood))
			for x in [-L * 0.5 - 1.0, L * 0.5 + 1.0]:
				n.add_child(dome(Vector3(2.0, 1.4, 2.0), s.trim, Vector3(x, ridge + 1.6, 0)))
			n.add_child(blob(Vector3(3.6, 0.8, 2.2), s.team, Vector3(-L * 0.2, ridge + 1.9, 0)))
		"spooky":   # bone ribs over a dark hide, a tattered banner hung from the back
			for k in 6:
				var x := -L * 0.46 + k * L * 0.184
				for side in [1, -1]:
					n.add_child(rod(Vector3(x, 0, 0) + out.call(side, 1.05, 0.6), Vector3(x, ridge + 1.4, 0), 0.6, 0.5, s.metal, false))
			n.add_child(beam(Vector3(-L * 0.5 - 1.0, ridge + 1.0, 0), Vector3(L * 0.5 + 1.0, ridge + 1.0, 0), 1.2, 1.2, s.metal))
			var tatter := slab([Vector2(0, 0), Vector2(-5, 0), Vector2(-5, -6), Vector2(-3.8, -4.5), Vector2(-2.6, -7), Vector2(-1.2, -5), Vector2(0, -6.5)], 0.3, s.team, Vector3(-L * 0.5 - 1.4, ridge - 1.0, 2.5))
			tatter.rotation_degrees.y = 90
			n.add_child(tatter)
	return {"node": n}


## B: an open ram. The log hangs on ropes from two A-frames on wheels, and the race's own
## units walk beside it (crew sockets). The forest ram is pushed by a beetle instead.
func _ram_b(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 42.0
	var W := 12.0
	var wr := 4.2
	var top := 25.0
	var sockets := {}
	if s.fam == "forest":
		# A log on a wheeled cradle, a rhinoceros beetle in harness pushing it from behind.
		undercarriage(n, s, L * 0.8, W, wr)
		for x in [-L * 0.3, L * 0.3]:
			n.add_child(beam(Vector3(x, wr, 0), Vector3(x, wr + 4.0, 0), 1.2, W, s.dark))
		ram_log(n, s, -L * 0.5, L * 0.5 + 4.0, wr + 6.0, 2.8)
		var beetle := _creature("beetle", c)
		beetle.position = Vector3(-L * 0.5 - 15.0, 0, 0)
		n.add_child(beetle)
		n.add_child(rod(Vector3(-L * 0.5 - 2.0, wr + 6.0, 0), Vector3(-L * 0.5 - 5.0, 12.0, 0), 0.5, 0.5, s.rope))
		return {"node": n, "sockets": {}}
	undercarriage(n, s, L, W, wr)
	var base := wr + 1.0 if s.fam != "swamp" else 3.0
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5 * side), Vector3(L * 0.5, base, W * 0.5 * side), 1.4, 1.4, s.dark))
	for x in [-L * 0.32, L * 0.32]:   # the A-frames
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, base, W * 0.5 * side), Vector3(x, top, 0), 0.8, 0.7, s.wood if s.fam != "sewer" else s.dark))
	n.add_child(beam(Vector3(-L * 0.4, top, 0), Vector3(L * 0.4, top, 0), 1.3, 1.3, s.dark))
	var y := top - 9.0
	for x in [-L * 0.25, L * 0.25]:
		n.add_child(rod(Vector3(x, top, 0), Vector3(x, y + 2.0, 0), 0.35, 0.35, s.rope, false))
	ram_log(n, s, -L * 0.55, L * 0.5 + 8.0, y, 3.0)
	match s.fam:
		"timber":
			n.add_child(_box(Vector3(5.0, 3.5, 0.4), s.team, Vector3(0, top - 2.6, 0.9)))   # a team cloth hung from the ridge
			n.add_child(_box(Vector3(5.0, 3.5, 0.4), s.team, Vector3(0, top - 2.6, -0.9)))
		"spooky":
			n.add_child(blob(Vector3(1.6, 1.8, 1.6), s.metal, Vector3(L * 0.4 + 1.0, top + 0.5, 0)))   # a skull on the ridge
			n.add_child(_box(Vector3(4.0, 4.0, 0.3), s.team, Vector3(0, top - 2.6, 0.9)))
			n.add_child(_box(Vector3(4.0, 4.0, 0.3), s.team, Vector3(0, top - 2.6, -0.9)))
		_:
			pennant(n, s, Vector3(-L * 0.42, top - 2.0, 0), 8.0)
	# Two of the race's units: one each side, staggered so neither hides the ram.
	sockets.crew0 = Vector3(-L * 0.22, 0, W * 0.5 + 8.0)
	sockets.crew1 = Vector3(L * 0.15, 0, -W * 0.5 - 8.0)
	return {"node": n, "sockets": sockets}


## A whole creature (body, head, legs) standing, for an engine that a beast pulls or pushes.
func _creature(kind: String, c: Dictionary) -> Node3D:
	var cc := c.duplicate()
	cc.skin = Color("#3c2f4a")
	cc.skin2 = Color("#6a4a7a")
	var n := Node3D.new()
	var body: Dictionary = build("body." + kind, cc)
	n.add_child(body.node)
	var head: Dictionary = build("head." + kind, cc)
	head.node.position = body.sockets.head
	head.node.rotation_degrees.z = -18   # head down, horn into the log
	n.add_child(head.node)
	for a in body.anchors:
		var leg: Dictionary = build("leg.insect", cc)
		leg.node.position = a[0]
		if a[2] < 0:
			leg.node.scale = Vector3(1, 1, -1)
		n.add_child(leg.node)
	return n


# ------------------------------------------------------------------ catapult

## The throwing arm: from the pivot up to the cup, with the cup and its load.
func throw_arm(n: Node3D, s: Dictionary, pivot: Vector3, tip: Vector3) -> void:
	match s.fam:
		"sewer":   # a big spoon, the bowl for the cup, a lump of cheese in it
			n.add_child(rod(pivot, tip, 0.9, 0.7, s.metal))
			var bowl := dome(Vector3(3.2, 1.6, 2.6), s.metal, tip + Vector3(0.6, 0.4, 0))
			bowl.rotation_degrees.z = 180 - 70
			n.add_child(bowl)
			n.add_child(_box(Vector3(2.4, 2.0, 2.4), s.ammo, tip + Vector3(-0.6, 1.4, 0), Vector3(0, 30, 20)))
		"forest":   # a bent twig, an acorn cup with acorns in it
			var mid := pivot.lerp(tip, 0.5) + Vector3(-1.5, 0, 0)
			n.add_child(rod(pivot, mid, 1.1, 0.9, s.dark))
			n.add_child(rod(mid, tip, 0.9, 0.7, s.dark))
			n.add_child(dome(Vector3(3.0, 1.6, 3.0), s.trim, tip + Vector3(0, -0.3, 0)))
			n.add_child(blob(Vector3(1.4, 1.8, 1.4), plain(Color("#a8743a")), tip + Vector3(0, 1.4, 0)))
		"spooky":   # a long bone, a skull cupped at its end, a ball of web
			n.add_child(rod(pivot, tip, 0.9, 0.9, s.metal))
			n.add_child(blob(Vector3(1.4, 1.2, 1.4), s.metal, pivot))
			n.add_child(dome(Vector3(2.8, 2.2, 2.6), s.metal, tip + Vector3(0, -0.6, 0)))
			n.add_child(blob(Vector3.ONE * 2.0, surf("cloth", Color("#e8e4f0"), 2.0), tip + Vector3(0, 1.4, 0)))
		"swamp":   # a springy reed, a snail shell for the cup, a mud ball
			n.add_child(rod(pivot, tip, 0.9, 0.7, s.wood))
			n.add_child(dome(Vector3(2.8, 1.8, 2.8), surf("acorn_cap", Color(1.0, 0.9, 0.75), 2.0), tip + Vector3(0, -0.6, 0)))
			n.add_child(blob(Vector3.ONE * 1.9, s.ammo, tip + Vector3(0, 1.2, 0)))
		_:   # timber: a stout arm, an iron-bound cup, a stone
			n.add_child(beam(pivot, tip, 1.6, 1.6, s.wood))
			n.add_child(dome(Vector3(2.8, 1.8, 2.8), s.dark, tip + Vector3(0, -0.6, 0)))
			n.add_child(ring(2.4, 2.9, s.metal, tip + Vector3(0, -0.4, 0)))
			n.add_child(blob(Vector3.ONE * 2.0, s.ammo, tip + Vector3(0, 1.2, 0)))


## A: an arm-and-cup engine on wheels (a lily-pad sledge for frogs): a low frame, the arm
## standing up against a padded crossbar, its cup loaded. Team colour: the crossbar's pad.
func _catapult_a(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 30.0
	var W := 11.0
	var wr := 3.8
	undercarriage(n, s, L, W, wr)
	var base := wr + 1.0 if s.fam != "swamp" else 3.0
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5 * side), Vector3(L * 0.5, base, W * 0.5 * side), 1.6, 1.6, s.dark))
	for x in [-L * 0.42, -L * 0.1, L * 0.42]:
		n.add_child(beam(Vector3(x, base, -W * 0.5), Vector3(x, base, W * 0.5), 1.4, 1.4, s.dark))
	var bar := base + 12.0
	for side in [1, -1]:   # the uprights, braced back
		n.add_child(beam(Vector3(L * 0.12, base, W * 0.5 * side), Vector3(L * 0.12, bar, W * 0.5 * side), 1.4, 1.4, s.wood if s.fam != "swamp" else s.dark))
		n.add_child(rod(Vector3(L * 0.4, base, W * 0.5 * side), Vector3(L * 0.12, bar - 3.0, W * 0.5 * side), 0.6, 0.6, s.dark))
	n.add_child(beam(Vector3(L * 0.12, bar, -W * 0.5 - 1.0), Vector3(L * 0.12, bar, W * 0.5 + 1.0), 1.6, 1.6, s.dark))
	n.add_child(rod(Vector3(L * 0.12 - 1.2, bar, -W * 0.3), Vector3(L * 0.12 - 1.2, bar, W * 0.3), 1.3, 1.3, s.team))   # the pad
	var pivot := Vector3(-L * 0.25, base + 1.2, 0)
	n.add_child(rod(pivot + Vector3(0, 0, -W * 0.5), pivot + Vector3(0, 0, W * 0.5), 1.6, 1.6, s.rope))   # the twisted skein
	var tip := Vector3(L * 0.12 - 0.5, base + 22.0, 0)
	throw_arm(n, s, pivot, tip)
	# A winch at the back.
	n.add_child(rod(Vector3(-L * 0.45, base + 1.6, -W * 0.5), Vector3(-L * 0.45, base + 1.6, W * 0.5), 1.0, 1.0, s.dark))
	for side in [1, -1]:
		n.add_child(rod(Vector3(-L * 0.45, base + 1.6, W * 0.5 * side), Vector3(-L * 0.45 - 2.0, base + 4.0, W * 0.5 * side), 0.4, 0.4, s.dark))
	if s.fam == "spooky":
		n.add_child(blob(Vector3(1.8, 2.0, 1.8), s.metal, Vector3(L * 0.5, base + 2.2, 0)))   # a skull on the prow
	return {"node": n}


## B: a pole flinger pulled by its crew. A tall trestle, a long beam on top: its short end
## over the front, ropes hanging down to the crew's hands; its long end behind, the sling
## lying on the ground with its shot. Team colour: a cloth on the trestle.
func _catapult_b(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var W := 10.0
	var top := 22.0
	var base := 1.0
	if s.fam == "swamp":
		undercarriage(n, s, 22.0, W, 3.0)
		base = 3.0
	else:
		for side in [1, -1]:   # a ground frame
			n.add_child(beam(Vector3(-10, base, W * 0.5 * side), Vector3(10, base, W * 0.5 * side), 1.6, 1.6, s.dark))
		for x in [-9.0, 9.0]:
			n.add_child(beam(Vector3(x, base, -W * 0.5), Vector3(x, base, W * 0.5), 1.4, 1.4, s.dark))
	for side in [1, -1]:   # two trestles
		for x in [-7.0, 7.0]:
			n.add_child(rod(Vector3(x, base, W * 0.5 * side), Vector3(0, top, W * 0.3 * side), 0.8, 0.7, s.wood))
	n.add_child(rod(Vector3(0, top, -W * 0.45), Vector3(0, top, W * 0.45), 0.8, 0.8, s.dark))
	# The beam: short end up over the front, long end down behind (ready to pull).
	var front := Vector3(9.0, top + 7.0, 0)
	var back := Vector3(-24.0, 6.0, 0)
	var arm_mat: Material = s.wood
	if s.fam == "spooky":
		arm_mat = s.metal
	n.add_child(rod(back, front, 0.9, 1.3, arm_mat))
	var sockets := {}
	for k in [0, 2]:   # pulling ropes, from the front end down to the crew
		var z: float = (k - 1) * 5.0
		var hand := Vector3(19.0, 14.0, z * 1.4)
		n.add_child(rod(front + Vector3(0.5, 0, 0), hand, 0.22, 0.22, s.rope, false))
		sockets["crew%d" % k] = Vector3(hand.x + 3.5, 0, hand.z)
	# The sling: two cords from the long end down to a pouch on the ground with its shot.
	var pouch := Vector3(-20.0, 1.4, 0)
	n.add_child(rod(back, pouch + Vector3(0.8, 0, 0.6), 0.2, 0.2, s.rope, false))
	n.add_child(rod(back, pouch + Vector3(0.8, 0, -0.6), 0.2, 0.2, s.rope, false))
	if s.fam == "sewer":   # a bottle cap for the pouch
		n.add_child(cone(2.4, 2.4, 0.9, s.trim, pouch, Vector3.ZERO, 14))
		n.add_child(_box(Vector3(2.2, 1.8, 2.2), s.ammo, pouch + Vector3(0, 1.3, 0), Vector3(0, 30, 0)))
	else:
		n.add_child(dome(Vector3(2.4, 1.0, 2.0), surf("leather", Color.WHITE, 3.0), pouch + Vector3(0, -0.6, 0)))
		n.add_child(blob(Vector3.ONE * 1.9, s.ammo, pouch + Vector3(0, 1.0, 0)))
	n.add_child(_box(Vector3(0.3, 4.5, 4.0), s.team, Vector3(-3.0, top - 5.0, W * 0.38)))   # team cloth on the near trestle
	if s.fam == "forest":
		n.add_child(blob(Vector3(2.4, 2.0, 2.4), s.trim, front + Vector3(0.6, 0.6, 0)))   # an acorn cap on the beam's end
	return {"node": n, "sockets": sockets}


# ------------------------------------------------------------------ bolt thrower

## The bow, stock and bolt, the stock lying along +x at height y from x0 to x1.
func bow_and_bolt(n: Node3D, s: Dictionary, x0: float, x1: float, y: float, span: float) -> void:
	n.add_child(beam(Vector3(x0, y, 0), Vector3(x1, y, 0), 2.2, 1.6, s.dark))
	var bx := x1 - 3.0
	var bow_mat: Material = s.wood
	match s.fam:
		"timber":
			bow_mat = s.dark
			n.add_child(_box(Vector3(3.0, 3.0, 3.6), s.metal, Vector3(bx, y + 0.4, 0)))   # the iron frame holding the arms
		"spooky", "sewer":
			bow_mat = s.metal
		"forest":
			bow_mat = surf("wood_grain", Color(0.8, 0.7, 0.55), 5.0)
	for side in [1, -1]:   # the arms sweep out and back
		var mid := Vector3(bx - 1.0, y + 0.5, span * 0.55 * side)
		var end := Vector3(bx - 4.5, y + 0.5, span * side)
		n.add_child(rod(Vector3(bx, y + 0.5, 1.4 * side), mid, 0.8, 0.65, bow_mat))
		n.add_child(rod(mid, end, 0.65, 0.4, bow_mat))
		n.add_child(rod(end, Vector3(x0 + 4.0, y + 0.9, 0), 0.14, 0.14, s.rope if s.fam != "spooky" else plain(Color("#e8e4f0")), false))
	# The bolt, laid on the stock, its head past the bow.
	var head := Vector3(x1 + 5.0, y + 1.3, 0)
	match s.fam:
		"sewer":   # a knitting needle
			n.add_child(rod(Vector3(x0 + 4.0, y + 1.3, 0), head, 0.35, 0.2, s.metal))
			n.add_child(blob(Vector3.ONE * 0.9, plain(Color("#d04848")), Vector3(x0 + 3.6, y + 1.3, 0)))
		"swamp", "forest":   # a thorn
			n.add_child(rod(Vector3(x0 + 4.0, y + 1.3, 0), head - Vector3(3, 0, 0), 0.4, 0.4, s.wood))
			n.add_child(cone(0.05, 0.7, 3.5, plain(Color("#6a4a2a")), head - Vector3(1.3, 0, 0), Vector3(0, 0, -90), 8))
		_:
			n.add_child(rod(Vector3(x0 + 4.0, y + 1.3, 0), head - Vector3(1.5, 0, 0), 0.35, 0.35, s.wood if s.fam != "spooky" else s.metal))
			n.add_child(cone(0.05, 0.75, 2.4, s.metal if s.fam != "timber" else surf("iron", Color(0.7, 0.7, 0.75), 3.0), head, Vector3(0, 0, -90), 8))
			for side in [1, -1]:
				n.add_child(slab([Vector2(0, 0), Vector2(2.4, 0), Vector2(0.4, 1.2 * side)], 0.2, s.team, Vector3(x0 + 4.0, y + 1.3, 0)))


## A: a bolt thrower on a two-wheeled carriage with a trail, like a field gun (a sledge for
## frogs). Team colour: a cloth on the trail.
func _bolt_a(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wr := 5.0
	var y := 13.0
	if s.fam == "swamp":
		undercarriage(n, s, 22.0, 10.0, 3.0)
		for side in [1, -1]:
			n.add_child(rod(Vector3(-4, 3.0, 3.0 * side), Vector3(0, y - 1.0, 0), 0.8, 0.7, s.dark))
			n.add_child(rod(Vector3(6, 3.0, 3.0 * side), Vector3(0, y - 1.0, 0), 0.8, 0.7, s.dark))
	else:
		for side in [1, -1]:
			wheel(n, Vector3(0, wr, 6.5 * side), wr, 1.6, s)
		n.add_child(rod(Vector3(0, wr, -7.5), Vector3(0, wr, 7.5), 0.7, 0.7, s.dark, false))
		for side in [1, -1]:   # the trail, down to the ground behind
			n.add_child(beam(Vector3(1.5, wr + 0.5, 3.0 * side), Vector3(-17, 0.8, 0.8 * side), 1.4, 1.4, s.dark))
		n.add_child(beam(Vector3(0, wr, 0), Vector3(0, y - 1.0, 0), 2.0, 2.0, s.dark))
		n.add_child(_box(Vector3(6.0, 0.4, 2.8), s.team, Vector3(-10.5, 3.6, 0), Vector3(0, 0, 18)))
	bow_and_bolt(n, s, -10.0, 10.0, y, 9.0)
	if s.fam == "swamp":
		pennant(n, s, Vector3(-9.0, 3.0, 0), 13.0, 3.5)
	return {"node": n}


## B: a lighter bolt thrower on a tripod, a crew member behind it aiming (sockets).
## Team colour: a cloth hung under the stock.
func _bolt_b(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var y := 15.0
	var head := Vector3(0, y - 1.5, 0)
	var feet := [Vector3(7, 0, 0), Vector3(-5, 0, 6), Vector3(-5, 0, -6)]
	for f in feet:
		n.add_child(rod(f, head, 0.6, 0.7, s.dark if s.fam != "spooky" else s.metal))
	n.add_child(blob(Vector3(1.4, 1.2, 1.4), s.dark, head))
	bow_and_bolt(n, s, -9.0, 8.0, y, 7.5)
	n.add_child(_box(Vector3(5.0, 3.5, 0.3), s.team, Vector3(-1.0, y - 2.6, 1.3)))
	if s.fam == "swamp":
		var pad := cone(5.5, 5.5, 0.5, plain(Color("#4f9d4a")), Vector3(-4.0, 0.3, 0), Vector3.ZERO, 24)   # standing on a lily pad
		n.add_child(pad)
	return {"node": n, "sockets": {"crew0": Vector3(-15.0, 0, 0)}}
