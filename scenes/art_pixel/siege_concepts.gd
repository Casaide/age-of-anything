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
## Round 2's directions: "c" crewed (the open ram, the arm-and-cup catapult, the carriage bolt
## thrower, each with its crew's sockets), "shed" the rats' covered ram pushed from behind,
## "ridden" and "led" the forest's giant beetle (built at its own size).
## Crew socket names carry how the crew member stands: "crew<n>_f<k>[_reach|_raise][_in|_top]":
## f<k> turns them k facings from the engine's, reach/raise is the arm hold, "in" draws them
## behind the engine (inside its frame), "top" over it (riding).
const ROUND2_SCALE := {"c": {"ram": 1.5, "catapult": 1.8, "bolt": 2.1},
	"shed": {"ram": 1.45}, "ridden": {"ram": 1.0}, "led": {"ram": 1.0}, "mount": {"ram": 1.0}}


func has(id: String) -> bool:
	return id.begins_with("siege.") or super.has(id)


func build(id: String, colours: Dictionary) -> Dictionary:
	if not id.begins_with("siege."):
		return super.build(id, colours)
	var p := id.split(".")
	var s := _style(p[3], colours)
	# The engines are built at a soldier's scale and grown to their size here (sockets too).
	# Round 2 (crewed, D-118) grows them to their crew: a ram's log at chest height, a
	# catapult's frame to the crew's shoulder; frog engines more, for the crouched frog.
	var k: float = {"ram": 1.0, "catapult": 1.5, "bolt": 1.6}[p[1]]
	if p[2] in ROUND2_SCALE:
		k = ROUND2_SCALE[p[2]][p[1]] * (1.25 if p[3] == "swamp" else 1.0)
	if p[2] in ROUND3:   # round 3's frog engines are built at their true size
		k = 1.0
	return _scaled(call("_%s_%s" % [p[1], p[2]], s, colours), k)


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
		"frog":   # round 3's frogs: their own building culture (dark timber, golden reed, wicker, daub)
			s.wood = surf("wood_grain", Color(0.58, 0.44, 0.34), 7.0)     # the stilts' dark timber
			s.dark = surf("wood_grain", Color(0.42, 0.32, 0.26), 6.0)
			s.reed = surf("thatch", Color(1.0, 0.95, 0.82), 7.0)           # golden reed, bundled
			s.stalk = surf("reed_stalk", Color(0.95, 0.92, 0.75), 5.0)
			s.wicker = surf("wicker", Color(0.95, 0.88, 0.75), 6.0)
			s.daub = surf("bld_daub", Color(0.92, 0.82, 0.68), 9.0)        # sun-dried mud
			s.clay = surf("bld_daub", Color(1.05, 0.62, 0.42), 7.0)          # fired clay, terracotta
			s.stone = surf("rock", Color(0.72, 0.76, 0.7), 5.0)            # river stones
			s.lash = plain(Color("#4a3a2a"))                                # dark twisted-reed lashing
			s.plank = surf("wood_grain", Color(1.0, 0.86, 0.68), 8.0)       # a punt's planks
			s.net = surf("wicker", Color(0.72, 0.66, 0.5), 2.5)            # fine netting
			s.metal = s.stone
			s.trim = s.lash
			s.ammo = s.clay
		"junk":   # round 2's rats (D-116): human-sized engines from the sewer's own junk
			s.wood = surf("wood_grain", Color(0.78, 0.7, 0.6), 7.0)        # scrap timber, greyed
			s.wood2 = surf("bld_wood", Color(0.62, 0.5, 0.4), 8.0)         # a mismatched plank
			s.dark = surf("wood_grain", Color(0.52, 0.46, 0.42), 6.0)
			s.metal = surf("iron", Color(0.8, 0.56, 0.4), 4.0)             # rusted iron
			s.pipe = surf("iron", Color(0.58, 0.6, 0.58), 5.0)             # grey iron pipe
			s.plate = surf("bld_tin", Color(0.72, 0.5, 0.36), 9.0)         # rusted plate
			s.plate2 = surf("bld_tin", Color(0.5, 0.52, 0.5), 9.0)         # a greyer patch
			s.rivet = plain(Color("#3a302a"))
			s.trim = s.metal
			s.roof = s.plate
			s.ammo = surf("cheese", Color.WHITE, 4.0)
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
		"junk":   # mismatched cart wheels: spoked ones at the back, plank discs at the front
			if at.x > 0.0:
				n.add_child(cone(r, r, thick, s.wood2, at, Vector3(90, 0, 0), 16))
				n.add_child(ring(r * 0.88, r * 1.02, s.metal, at, Vector3(90, 0, 0), Vector3(1, thick * 1.1, 1)))
				n.add_child(_box(Vector3(r * 1.8, 0.5, thick + 0.4), s.rivet, at))   # the plank seam
			else:
				n.add_child(ring(r * 0.8, r, s.metal, at, Vector3(90, 0, 0), Vector3(1, thick * 1.2, 1)))
				for k in 8:
					var a := TAU * k / 8.0 + 0.2
					n.add_child(rod(at, at + Vector3(cos(a), sin(a), 0) * r * 0.85, 0.4, 0.35, s.dark, false))
				n.add_child(cone(r * 0.25, r * 0.25, thick + 0.6, s.metal, at, Vector3(90, 0, 0), 10))
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


# ================================================================== round 2 (2026-10-13)
# Dominic on round 1: crews on every engine (D-118), rats at human scale from the sewer's own
# junk (D-116), the forest ram a giant beetle (D-117). Sockets: see ROUND2_SCALE's note.

## A short chain from a to b: links alternating flat and edge-on.
func chain(n: Node3D, a: Vector3, b: Vector3, m: Material, link := 0.9) -> void:
	var count := maxi(2, int(a.distance_to(b) / (link * 1.6)))
	var d := (b - a).normalized()
	var tilt := rad_to_deg(atan2(d.x, d.y))
	for k in count:
		var at := a.lerp(b, (k + 0.5) / count)
		n.add_child(ring(link * 0.45, link * 0.8, m, at, Vector3(90 * (k % 2), 0, -tilt + 90), Vector3(1.4, 1, 1)))


## A sewer grate: an iron frame and bars, `w` wide and `h` tall, standing at `at` facing +x.
func grate(n: Node3D, s: Dictionary, at: Vector3, w: float, h: float, lean := 0.0) -> void:
	var g := Node3D.new()
	g.position = at
	g.rotation_degrees.z = lean
	var iron := surf("iron", Color(0.5, 0.48, 0.46), 4.0)
	for side in [1, -1]:
		g.add_child(_box(Vector3(1.0, h, 1.2), iron, Vector3(0, h * 0.5, w * 0.5 * side)))
		g.add_child(_box(Vector3(1.0, 1.2, w), iron, Vector3(0, h * 0.5 + (h * 0.5 - 0.6) * side, 0)))
	for k in range(1, 6):
		g.add_child(_box(Vector3(0.7, h, 0.6), iron, Vector3(0, h * 0.5, -w * 0.5 + w * k / 6.0)))
	g.add_child(_box(Vector3(0.7, 0.6, w), iron, Vector3(0, h * 0.5, 0)))
	g.add_child(_box(Vector3(0.9, h * 0.35, w * 0.3), s.metal, Vector3(0.3, h * 0.7, w * 0.15)))   # a rust bloom
	n.add_child(g)


## A rusted plate patched on, with rivets at its corners: size (x, y), lying in the xy plane
## at `at`, turned by `rot`.
func patch(n: Node3D, s: Dictionary, at: Vector3, size: Vector2, rot: Vector3, m: Material) -> void:
	var p := Node3D.new()
	p.position = at
	p.rotation_degrees = rot
	p.add_child(_box(Vector3(size.x, size.y, 0.5), m, Vector3.ZERO))
	for cx in [-1, 1]:
		for cy in [-1, 1]:
			p.add_child(blob(Vector3.ONE * 0.45, s.rivet, Vector3(cx * (size.x * 0.5 - 0.7), cy * (size.y * 0.5 - 0.7), 0.3)))
	n.add_child(p)


## The junk ram's head: a heavy iron pipe-end with a flange, bolted onto the beam.
func junk_head(n: Node3D, s: Dictionary, tip: Vector3, r: float) -> void:
	n.add_child(cone(r * 1.05, r * 1.05, 5.0, s.pipe, tip + Vector3(1.5, 0, 0), Vector3(0, 0, -90), 14))
	n.add_child(cone(r * 1.7, r * 1.7, 1.4, s.metal, tip + Vector3(4.6, 0, 0), Vector3(0, 0, -90), 16))   # the flange
	n.add_child(cone(r * 0.9, r * 1.4, 2.0, surf("iron", Color(0.45, 0.42, 0.4), 4.0), tip + Vector3(6.2, 0, 0), Vector3(0, 0, -90), 14))   # a cast cap
	for k in 6:
		var a := TAU * k / 6.0
		n.add_child(blob(Vector3.ONE * 0.5, s.rivet, tip + Vector3(5.3, cos(a) * r * 1.4, sin(a) * r * 1.4)))


## A scrap timber beam from x0 to x1 at height y, bound with barrel hoops, the junk head on it.
func junk_log(n: Node3D, s: Dictionary, x0: float, x1: float, y: float, r: float) -> void:
	n.add_child(beam(Vector3(x0, y, 0), Vector3(x1, y, 0), r * 1.8, r * 1.8, s.wood))
	n.add_child(beam(Vector3(x0 + 6.0, y + r * 0.95, 0.4), Vector3(x0 + 18.0, y + r * 0.95, 0.4), r * 1.2, 0.6, s.wood2))   # a plank nailed on
	for x in [x0 + 3.0, (x0 + x1) * 0.5, x1 - 3.0]:
		n.add_child(_box(Vector3(1.2, r * 2.1, r * 2.1), s.metal, Vector3(x, y, 0)))
	junk_head(n, s, Vector3(x1, y, 0), r)


## C: the open ram, crewed. Timber and frogs keep round 1's B frame; the rats build theirs
## from pipes, chains and scrap. Two of the crew swing the log from inside the frame, a third
## shoves at the back.
func _ram_c(s: Dictionary, c: Dictionary) -> Dictionary:
	var spec: Dictionary = _ram_b(s, c) if s.fam != "junk" else _ram_c_junk(s, c)
	var L := 42.0
	spec.sockets = {"crew0_f0_reach_in": Vector3(-L * 0.3, 0, -2.5), "crew1_f0_reach_in": Vector3(L * 0.1, 0, -2.5),
		"crew2_f0_reach": Vector3(-L * 0.5 - 5.0, 0, 5.0)}
	return spec


func _ram_c_junk(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 42.0
	var W := 12.0
	var wr := 4.2
	var top := 25.0
	undercarriage(n, s, L, W, wr)
	var base := wr + 1.0
	for side in [1, -1]:   # mismatched rails: a plank one side, a pipe the other
		if side > 0:
			n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5), Vector3(L * 0.5, base, W * 0.5), 1.6, 1.6, s.wood2))
		else:
			n.add_child(rod(Vector3(-L * 0.5, base, -W * 0.5), Vector3(L * 0.5, base, -W * 0.5), 0.8, 0.8, s.pipe))
	for x in [-L * 0.32, L * 0.32]:   # A-frames of iron pipe, an elbow joint at the top
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, base, W * 0.5 * side), Vector3(x, top, 0), 0.75, 0.75, s.pipe))
		n.add_child(blob(Vector3(1.4, 1.4, 1.6), s.metal, Vector3(x, top, 0)))
	n.add_child(rod(Vector3(-L * 0.4, top, 0), Vector3(L * 0.4, top, 0), 0.9, 0.9, s.pipe))
	var y := top - 9.0
	for x in [-L * 0.25, L * 0.25]:   # hung on chains
		chain(n, Vector3(x, top - 0.6, 0), Vector3(x, y + 2.0, 0), s.metal, 0.75)
	junk_log(n, s, -L * 0.55, L * 0.5 + 6.0, y, 2.6)
	# A rag tied round the top pipe for team colour.
	n.add_child(_box(Vector3(3.0, 4.0, 0.4), s.team, Vector3(-L * 0.12, top - 2.4, 1.0), Vector3(0, 0, 8)))
	n.add_child(ring(0.8, 1.4, s.team, Vector3(-L * 0.12, top, 0), Vector3(0, 0, 90)))
	return {"node": n, "sockets": {}}


## The rats' covered ram, crewed: a shed roofed like half a barrel (staves under iron hoops,
## rusted plates riveted over the holes), a sewer grate standing in front as a shield, the
## head poking out under it; the crew shove at the poles out the back.
func _ram_shed(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 40.0
	var W := 14.0
	var wr := 4.0
	undercarriage(n, s, L * 0.85, W, wr)
	var base := wr + 1.0
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5 * side), Vector3(L * 0.5, base, W * 0.5 * side), 1.6, 1.6, s.dark if side > 0 else s.wood2))
	junk_log(n, s, -L * 0.5, L * 0.5 + 7.0, base + 5.0, 2.6)
	# The barrel roof: staves round half a circle, hoops over them.
	var R := W * 0.5 + 2.5
	var cy := base + 4.0
	var mats := [s.wood, s.wood2, s.dark, s.wood, s.wood2, s.wood, s.dark, s.wood2, s.wood]
	var staves := 9
	for k in staves:
		var a := PI * (k + 0.5) / staves   # 0..PI, over the top
		var at := Vector3(0, cy + sin(a) * R, cos(a) * R)
		var st := _box(Vector3(L + 1.0, 1.0, PI * R / staves + 0.35), mats[k], at)
		st.rotation.x = a - PI * 0.5
		n.add_child(st)
	for x in [-L * 0.38, 0.0, L * 0.38]:
		n.add_child(ring(R + 0.1, R + 1.0, s.metal, Vector3(x, cy, 0), Vector3(0, 0, 90)))
	# Plates riveted over the gaps (rusted, one grey).
	patch(n, s, Vector3(-L * 0.2, cy + R * 0.82, R * 0.6), Vector2(9.0, 6.0), Vector3(-36, 0, 0), s.plate)
	patch(n, s, Vector3(L * 0.2, cy + R + 0.4, -1.0), Vector2(7.0, 5.5), Vector3(-90, 0, 4), s.plate2)
	patch(n, s, Vector3(L * 0.05, cy + R * 0.55, -R * 0.85), Vector2(8.0, 5.0), Vector3(-150, 0, 0), s.plate)
	# The sewer grate in front, leaning back over the head.
	grate(n, s, Vector3(L * 0.5 + 1.5, base + 7.5, 0), W + 2.0, 12.0, 14)
	# Poles out the back for the crew to shove, and a team rag on the roof.
	for side in [1, -1]:
		n.add_child(rod(Vector3(-L * 0.45, base + 2.0, W * 0.5 * side), Vector3(-L * 0.5 - 7.0, base + 9.0, (W * 0.5 + 2.0) * side), 0.55, 0.55, s.dark))
	n.add_child(_box(Vector3(5.0, 0.5, 4.5), s.team, Vector3(-L * 0.05, cy + R + 0.6, 2.5), Vector3(-25, 0, 6)))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-L * 0.5 - 9.0, 0, W * 0.5 + 3.0),
		"crew1_f0_reach": Vector3(-L * 0.5 - 9.0, 0, -W * 0.5 - 3.0)}}


## C: the arm-and-cup catapult (round 1's A), crewed: one winds the winch at the back, one
## loads from the far side. The rats' is junk-built: pipe uprights, a bucket for a cup, cheese.
func _catapult_c(s: Dictionary, c: Dictionary) -> Dictionary:
	var spec: Dictionary = _catapult_a(s, c) if s.fam != "junk" else _catapult_c_junk(s, c)
	var L := 30.0
	var W := 11.0
	spec.sockets = {"crew0_f0_raise": Vector3(-L * 0.5 - 6.0, 0, 0.0), "crew1_f0_reach": Vector3(-L * 0.3, 0, W * 0.5 + 7.0)}
	# A pile of ammunition by the loader.
	for k in 3:
		var at := Vector3(-L * 0.12 + (k % 2) * 2.4, 1.0 + (k / 2) * 1.6, W * 0.5 + 3.5 + (k % 2) * 1.2)
		if s.fam == "junk":
			spec.node.add_child(cone(1.6, 1.6, 1.4, s.ammo, at, Vector3.ZERO, 12))
		else:
			spec.node.add_child(blob(Vector3.ONE * 1.5, s.ammo, at))
	return spec


func _catapult_c_junk(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 30.0
	var W := 11.0
	var wr := 3.8
	undercarriage(n, s, L, W, wr)
	var base := wr + 1.0
	n.add_child(beam(Vector3(-L * 0.5, base, W * 0.5), Vector3(L * 0.5, base, W * 0.5), 1.6, 1.6, s.wood2))
	n.add_child(beam(Vector3(-L * 0.5, base, -W * 0.5), Vector3(L * 0.5, base, -W * 0.5), 1.8, 1.4, s.dark))
	for x in [-L * 0.42, -L * 0.1, L * 0.42]:
		n.add_child(beam(Vector3(x, base, -W * 0.5), Vector3(x, base, W * 0.5), 1.4, 1.4, s.wood if x < 0.0 else s.wood2))
	var bar := base + 12.0
	for side in [1, -1]:   # pipe uprights, braced with a strip of iron
		n.add_child(rod(Vector3(L * 0.12, base, W * 0.5 * side), Vector3(L * 0.12, bar, W * 0.5 * side), 0.8, 0.8, s.pipe))
		n.add_child(beam(Vector3(L * 0.4, base, W * 0.5 * side), Vector3(L * 0.12, bar - 3.0, W * 0.5 * side), 0.9, 0.4, s.metal))
	n.add_child(rod(Vector3(L * 0.12, bar, -W * 0.5 - 1.0), Vector3(L * 0.12, bar, W * 0.5 + 1.0), 0.9, 0.9, s.pipe))
	n.add_child(rod(Vector3(L * 0.12 - 1.2, bar, -W * 0.3), Vector3(L * 0.12 - 1.2, bar, W * 0.3), 1.3, 1.3, s.team))   # a rag for the pad
	var pivot := Vector3(-L * 0.25, base + 1.2, 0)
	n.add_child(rod(pivot + Vector3(0, 0, -W * 0.5), pivot + Vector3(0, 0, W * 0.5), 1.6, 1.6, s.rope))
	chain(n, pivot + Vector3(0, 1.7, -W * 0.45), pivot + Vector3(0, 1.7, W * 0.45), s.metal, 0.7)
	var tip := Vector3(L * 0.12 - 0.5, base + 22.0, 0)
	n.add_child(beam(pivot, tip, 1.7, 1.5, s.wood))
	for t in [0.3, 0.65]:
		n.add_child(_box(Vector3(2.0, 0.9, 2.0), s.metal, pivot.lerp(tip, t), Vector3(0, 0, rad_to_deg(atan2(tip.y - pivot.y, tip.x - pivot.x)))))
	# The cup: an iron bucket, a wheel of cheese in it.
	n.add_child(cone(2.8, 2.0, 3.2, s.metal, tip + Vector3(0, 0.4, 0), Vector3.ZERO, 14))
	n.add_child(ring(2.6, 3.0, s.rivet, tip + Vector3(0, 2.0, 0)))
	n.add_child(_box(Vector3(3.8, 2.8, 3.8), s.ammo, tip + Vector3(0, 3.0, 0), Vector3(0, 30, 12)))   # a big wedge of cheese
	# The winch: a pipe with a spoked hand wheel.
	n.add_child(rod(Vector3(-L * 0.45, base + 1.6, -W * 0.5), Vector3(-L * 0.45, base + 1.6, W * 0.5 + 1.0), 0.8, 0.8, s.pipe))
	n.add_child(ring(1.8, 2.4, s.metal, Vector3(-L * 0.45, base + 1.6, W * 0.5 + 1.2), Vector3(90, 0, 0)))
	return {"node": n}


## C: the bolt thrower on its carriage (round 1's A), crewed: one aims at the trail, one loads
## from the far side. The rats': cart wheels that don't match, a pipe trail, leaf-spring arms,
## an iron rod for a bolt and a sewer grate for a gun shield.
func _bolt_c(s: Dictionary, c: Dictionary) -> Dictionary:
	var spec: Dictionary = _bolt_a(s, c) if s.fam != "junk" else _bolt_c_junk(s, c)
	spec.sockets = {"crew0_f0_reach": Vector3(-19.0, 0, 3.5), "crew1_f0_reach": Vector3(-13.0, 0, -9.5)}
	return spec


func _bolt_c_junk(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wr := 5.0
	var y := 13.0
	wheel(n, Vector3(0.0, wr, 6.5), wr, 1.6, s)   # a spoked cart wheel...
	wheel(n, Vector3(0.01, wr * 0.92, -6.5), wr * 0.92, 1.8, s)   # ...and a plank one, a bit smaller
	n.add_child(rod(Vector3(0, wr, -7.5), Vector3(0, wr, 7.5), 0.7, 0.7, s.pipe, false))
	for side in [1, -1]:   # the trail: two pipes down to the ground behind
		n.add_child(rod(Vector3(1.5, wr + 0.5, 3.0 * side), Vector3(-17, 0.8, 0.8 * side), 0.75, 0.75, s.pipe))
	n.add_child(beam(Vector3(0, wr, 0), Vector3(0, y - 1.0, 0), 2.0, 2.0, s.wood2))
	n.add_child(_box(Vector3(6.0, 0.4, 2.8), s.team, Vector3(-10.5, 3.6, 0), Vector3(0, 0, 18)))
	grate(n, s, Vector3(3.0, wr - 2.0, 0), 11.0, 9.5, 8)   # the gun shield, below the bow
	n.add_child(beam(Vector3(-10, y, 0), Vector3(10, y, 0), 2.2, 1.6, s.wood))
	n.add_child(_box(Vector3(3.0, 3.0, 3.6), s.metal, Vector3(7.0, y + 0.4, 0)))
	for side in [1, -1]:   # leaf-spring arms: three flat strips stacked, swept back
		for leaf in 3:
			var a := Vector3(7.0, y + 0.5 - leaf * 0.5, 1.4 * side)
			var e := Vector3(3.0 + leaf * 1.2, y + 0.5 - leaf * 0.5, (11.0 - leaf * 2.6) * side)
			n.add_child(beam(a, e, 0.9, 0.45, s.metal if leaf != 1 else s.pipe))
		n.add_child(rod(Vector3(3.0, y + 0.5, 11.0 * side), Vector3(-6.0, y + 0.9, 0), 0.14, 0.14, s.rope, false))
	# The bolt: a sharpened iron rod with tin fins.
	n.add_child(rod(Vector3(-6.0, y + 1.3, 0), Vector3(13.5, y + 1.3, 0), 0.35, 0.35, s.pipe))
	n.add_child(cone(0.05, 0.6, 2.6, s.metal, Vector3(15.0, y + 1.3, 0), Vector3(0, 0, -90), 8))
	for side in [1, -1]:
		n.add_child(slab([Vector2(0, 0), Vector2(2.4, 0), Vector2(0.4, 1.2 * side)], 0.2, s.plate2, Vector3(-6.0, y + 1.3, 0)))
	return {"node": n}


# ------------------------------------------------------------------ the giant beetle (D-117)

const BEETLE_DROP := 5.0   # how far the giant's body sits lower than its first build (legs were stilts)


## A giant rhinoceros beetle, x forward, standing on y = 0: glossy mahogany wing cases, a
## bark-and-iron cap on its pronotum, a long head horn capped in iron for the walls and a
## thoracic horn over it like pincers. About 2.5 times a cavalry beetle's length.
func giant_beetle(n: Node3D, s: Dictionary) -> Node3D:
	var shell := surf("chitin", Color("#5a3424"), 5.0)
	shell.roughness = 0.45
	shell.metallic_specular = 0.6
	var dark := surf("chitin", Color("#2e1c16"), 4.0)
	var under := plain(Color("#24160f"))
	var iron := surf("iron", Color(0.72, 0.72, 0.76), 4.0)
	var bark := surf("bark_plate", Color(0.85, 0.75, 0.62), 6.0)
	var b := Node3D.new()   # the body, low on short splayed legs (it returns this, for what rides on it)
	b.position.y = -BEETLE_DROP
	n.add_child(b)
	for leg in [[14.0, 7.0, 15.0], [2.0, 1.0, 2.0], [-10.0, -6.0, -14.0]]:   # three pairs, thick and spread
		for side in [1, -1]:
			var hip := Vector3(leg[0], 16.0 - BEETLE_DROP, 9.0 * side)
			var knee := Vector3(leg[0] + leg[1], 20.0 - BEETLE_DROP, 21.0 * side)
			var foot := Vector3(leg[0] + leg[2], 0.8, 25.0 * side)
			n.add_child(rod(hip, knee, 3.2, 2.6, dark))
			n.add_child(rod(knee, foot, 2.5, 1.4, dark))
			n.add_child(rod(foot, foot + Vector3(2.0 * signf(leg[2] + 0.1), -0.5, 1.0 * side), 0.8, 0.5, dark))
	b.add_child(blob(Vector3(26, 7.5, 13), under, Vector3(-2, 17, 0)))
	for side in [1, -1]:   # the wing cases, meeting at a seam
		b.add_child(blob(Vector3(24, 12.5, 8.6), shell, Vector3(-8, 25, 7.4 * side), Vector3(0, 0, 4)))
	b.add_child(rod(Vector3(-31, 25, 0), Vector3(11, 37.5, 0), 0.5, 0.5, dark, false))
	# The pronotum, capped in bark plates with an iron rim and studs.
	b.add_child(blob(Vector3(11, 10.5, 14.5), shell, Vector3(16, 25, 0)))
	b.add_child(dome(Vector3(10.6, 8.0, 14.0), bark, Vector3(17.5, 27.5, 0)))
	b.add_child(ring(9.8, 11.2, iron, Vector3(17.5, 27.6, 0), Vector3.ZERO, Vector3(1, 1.2, 1.32)))
	for k in 5:
		var a := -0.9 + k * 0.45
		b.add_child(blob(Vector3.ONE * 0.9, iron, Vector3(17.5 + cos(a) * 9.5, 30.5, sin(a) * 12.0)))
	# The thoracic horn, curving forward and down over the head.
	var th := [Vector3(22, 33, 0), Vector3(31, 35.5, 0), Vector3(39, 33, 0), Vector3(43.5, 27.5, 0)]
	var tr := [3.0, 2.3, 1.6, 0.8]
	for k in range(1, th.size()):
		b.add_child(rod(th[k - 1], th[k], tr[k - 1], tr[k], dark))
	# The head, and its horn reaching forward for the wall, an iron cap on its end.
	b.add_child(blob(Vector3(7.5, 6.5, 8.5), shell, Vector3(29, 18, 0)))
	var hh := [Vector3(33, 17, 0), Vector3(43, 17, 0), Vector3(52, 18.5, 0), Vector3(58, 22, 0)]
	var hr := [4.4, 3.7, 3.0, 2.5]
	for k in range(1, hh.size()):
		b.add_child(rod(hh[k - 1], hh[k], hr[k - 1], hr[k], dark))
	b.add_child(ring(3.5, 4.6, iron, Vector3(43, 17, 0), Vector3(0, 0, 90)))
	b.add_child(cone(0.8, 3.6, 6.5, iron, Vector3(60.5, 24, 0), Vector3(0, 0, -50), 14))   # the iron cap
	for side in [1, -1]:
		b.add_child(blob(Vector3(1.6, 1.6, 1.2), plain(Color("#120c0a")), Vector3(31, 20, 6.8 * side)))
		b.add_child(blob(Vector3(0.5, 0.5, 0.4), plain(Color("#d8c8b8")), Vector3(31.8, 20.8, 7.6 * side)))
		b.add_child(rod(Vector3(34, 15, 4.5 * side), Vector3(39, 14, 7.5 * side), 0.35, 0.3, dark))   # a feeler
		b.add_child(blob(Vector3(1.0, 0.7, 1.0), dark, Vector3(39.5, 14, 7.8 * side)))
	# A leather girth strap round the middle.
	b.add_child(ring(0.9, 1.0, surf("leather", Color(0.6, 0.45, 0.32), 3.0), Vector3(2, 25, 0), Vector3(0, 0, 90), Vector3(14.5, 2.2, 17.5)))
	return b


## The giant beetle ridden: a howdah on its back with rails, a team cloth hanging over the
## sides, two of the race's own riders on it (one at the front driving).
func _ram_ridden(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var b := giant_beetle(n, s)
	var deck := 37.6
	var wood := surf("wood_grain", Color(0.75, 0.62, 0.5), 6.0)
	b.add_child(_box(Vector3(22, 1.4, 16), wood, Vector3(-6, deck, 0)))
	for x in [-16.5, 4.5]:
		for side in [1, -1]:
			b.add_child(rod(Vector3(x, deck, 7.6 * side), Vector3(x, deck + 4.5, 7.6 * side), 0.45, 0.45, s.dark))
	for side in [1, -1]:
		b.add_child(rod(Vector3(-16.5, deck + 4.5, 7.6 * side), Vector3(4.5, deck + 4.5, 7.6 * side), 0.4, 0.4, s.dark))
	b.add_child(rod(Vector3(-16.5, deck + 4.5, -7.6), Vector3(-16.5, deck + 4.5, 7.6), 0.4, 0.4, s.dark))
	for side in [1, -1]:   # the team cloth over both sides, and a little banner at the back
		b.add_child(_box(Vector3(12, 6.5, 0.4), s.team, Vector3(-6, deck - 3.0, 8.4 * side), Vector3(16 * side, 0, 0)))
	pennant(b, s, Vector3(-16.5, deck, -6.5), 11.0, 3.6)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(0.5, deck + 0.7 - BEETLE_DROP, 1.5), "crew1_f0_top": Vector3(-11.5, deck + 0.7 - BEETLE_DROP, -2.0)}}


## For size on the sheet: a cavalry beetle as the game builds it (body, head, legs), unridden.
func _ram_mount(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := _creature("beetle", c)
	n.get_child(1).rotation_degrees.z = 0   # head up: it's standing, not pushing
	return {"node": n}


## The giant beetle led: a saddle cloth in team colour, a lead rope from its head to a handler
## walking alongside, another behind with a goad.
func _ram_led(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var b := giant_beetle(n, s)
	b.add_child(_box(Vector3(14, 0.6, 22), s.team, Vector3(-3, 37.2, 0), Vector3(0, 0, -4)))
	for side in [1, -1]:
		b.add_child(_box(Vector3(10, 7.0, 0.4), s.team, Vector3(-3, 33.0, 10.6 * side), Vector3(22 * side, 0, 0)))
	# The lead rope, from the horn's base to the handler's hand (near side, ahead).
	b.add_child(ring(2.0, 2.6, s.rope, Vector3(36, 17.2, 0), Vector3(0, 0, 90)))
	n.add_child(rod(Vector3(36, 16 - BEETLE_DROP, 2.4), Vector3(30, 12, 20), 0.3, 0.3, s.rope, false))
	# A goad, from the handler behind to the beast's flank.
	n.add_child(rod(Vector3(-26, 12, 20), Vector3(-17, 22 - BEETLE_DROP, 11), 0.35, 0.3, s.dark))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(30, 0, 24), "crew1_f0_reach": Vector3(-30, 0, 22)}}


# ================================================================== round 3 (2026-10-13): the frogs
# Dominic on round 2's frog engines: "overusing lily pads and stuff, I think need to rethink
# direction" (D-119). Three directions, each with a ram, a catapult and a bolt thrower, crewed by the
# frog worker at true scale (built here at their full size, k = 1). Ids "siege.<engine>.<dir>.frog":
#   reed   A, reed and clay engineers: the frogs' own building culture (dark stilt timber, golden
#          reed bundles, wicker, daub, fired clay, river stones, twisted-reed lashing), on sledges
#   beast  B, living swamp beasts: a snapping turtle rams, a giant newt carries the catapult, a
#          giant toad the bolt thrower; frogs ride and work them
#   river  C, river engines: flat punts dragged through the shallows, fishing gear for tech (a
#          net-wrapped stone ram on crossed punt poles, a stone-basket swing beam slinging a net
#          of stones, a harpoon thrower with its line in a basket)
const ROUND3 := ["reed", "beast", "river"]


## A band of lashing round a rod running along `dir`, at `at`.
func band(n: Node3D, at: Vector3, dir: Vector3, r: float, m: Material) -> void:
	var t := ring(r * 0.92, r * 1.18, m, at)
	t.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	n.add_child(t)


## A bundle of reeds from a to b, `r` thick (`r2` at b), tied with `ties` bands of dark lashing.
func bundle(n: Node3D, a: Vector3, b: Vector3, r: float, s: Dictionary, ties := 3, r2 := -1.0) -> void:
	var rb := r if r2 < 0.0 else r2
	n.add_child(rod(a, b, r, rb, s.reed))
	for k in ties:
		var t := (k + 0.5) / ties
		band(n, a.lerp(b, t), b - a, lerpf(r, rb, t), s.lash)


## A heavy sledge: two dark timber runners, their fronts curled up, crossbars over them.
func sledge(n: Node3D, s: Dictionary, L: float, W: float, x0 := 0.0) -> void:
	for side in [1, -1]:
		var z: float = W * 0.5 * side
		n.add_child(beam(Vector3(x0 - L * 0.5, 1.4, z), Vector3(x0 + L * 0.38, 1.4, z), 2.6, 2.6, s.dark))
		n.add_child(rod(Vector3(x0 + L * 0.38, 1.4, z), Vector3(x0 + L * 0.48, 3.4, z), 1.3, 1.2, s.dark))
		n.add_child(rod(Vector3(x0 + L * 0.48, 3.4, z), Vector3(x0 + L * 0.5, 6.0, z), 1.2, 0.9, s.dark))
		band(n, Vector3(x0 + L * 0.48, 3.4, z), Vector3(0.4, 1, 0), 1.3, s.lash)
	for k in 4:
		var x := x0 - L * 0.42 + k * L * 0.26
		n.add_child(beam(Vector3(x, 3.2, -W * 0.5 - 1.0), Vector3(x, 3.2, W * 0.5 + 1.0), 2.0, 1.4, s.wood))


## A river boat `L` long, `W` across, `H` deep: a planked bowl pointed at both ends, a dark
## gunwale, thwarts, a stem post curling up at the bow and a lower one at the stern.
func punt(n: Node3D, s: Dictionary, L: float, W: float, H: float) -> void:
	var m: StandardMaterial3D = s.plank.duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bowl := dome(Vector3(L * 0.5, H, W * 0.5), m, Vector3(0, H, 0))
	bowl.rotation_degrees.x = 180.0   # upside down: a bowl, lit the right way up
	n.add_child(bowl)
	n.add_child(ring(0.955, 1.0, s.dark, Vector3(0, H, 0), Vector3.ZERO, Vector3(L * 0.5, 30.0, W * 0.5)))   # the gunwale
	n.add_child(_box(Vector3(L * 0.55, 0.8, W * 0.5), s.dark, Vector3(0, H * 0.3, 0)))   # the floor boards
	for x in [-L * 0.2, L * 0.2]:   # thwarts
		n.add_child(beam(Vector3(x, H * 0.85, -W * 0.44), Vector3(x, H * 0.85, W * 0.44), 2.0, 1.0, s.dark))
	n.add_child(rod(Vector3(L * 0.48, H * 0.8, 0), Vector3(L * 0.54, H + 4.0, 0), 1.3, 1.1, s.dark))   # the stem, curling up
	n.add_child(rod(Vector3(L * 0.54, H + 4.0, 0), Vector3(L * 0.53, H + 8.0, 0), 1.1, 0.8, s.dark))
	n.add_child(rod(Vector3(-L * 0.48, H * 0.8, 0), Vector3(-L * 0.53, H + 3.0, 0), 1.2, 0.9, s.dark))


## A wicker eel trap: a long cone, its mouth at `at`, lying along `dir`.
func eel_trap(n: Node3D, s: Dictionary, at: Vector3, dir: Vector3, len := 11.0, r := 2.6) -> void:
	var d := dir.normalized()
	n.add_child(rod(at, at + d * len, r, 0.5, s.wicker))
	for t in [0.0, 0.45]:
		band(n, at + d * len * t, d, r * (1.0 - t * 0.8), s.lash)


## A net hung over the gunwale from x0 to x1 on side z, with cork floats along its edge.
func draped_net(n: Node3D, s: Dictionary, x0: float, x1: float, top: float, z: float) -> void:
	var side := signf(z)
	n.add_child(_box(Vector3(x1 - x0, top * 0.75, 0.5), s.net, Vector3((x0 + x1) * 0.5, top * 0.6, z + 0.7 * side), Vector3(-8 * side, 0, 0)))
	for k in 4:
		n.add_child(blob(Vector3(1.0, 0.8, 0.8), plain(Color("#d8c8a0")), Vector3(lerpf(x0 + 2.0, x1 - 2.0, k / 3.0), top * 0.28, z + 1.6 * side)))


## A wicker cup or basket at `at` with a load of fired clay in it.
func clay_cup(n: Node3D, s: Dictionary, at: Vector3, r: float) -> void:
	n.add_child(cone(r, r * 0.68, r * 0.9, s.wicker, at, Vector3.ZERO, 16))
	n.add_child(ring(r * 0.9, r * 1.08, s.reed, at + Vector3(0, r * 0.45, 0)))
	n.add_child(blob(Vector3.ONE * r * 0.8, s.clay, at + Vector3(0, r * 0.8, 0)))


# ------------------------------------------------------------------ A: reed and clay engineers

## The ram: a fat reed-bundle log with a fired-clay head studded with river stones, hung on twisted
## reed from reed A-frames on a heavy sledge, a thatch cap over the ridge like their roofs.
func _ram_reed(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 72.0
	var W := 22.0
	var base := 4.0
	var top := 42.0
	sledge(n, s, L, W)
	for x in [-L * 0.3, L * 0.3]:
		for side in [1, -1]:
			bundle(n, Vector3(x, base, W * 0.5 * side), Vector3(x, top, 0), 1.8, s, 2)
		n.add_child(blob(Vector3.ONE * 2.6, s.lash, Vector3(x, top, 0)))
	bundle(n, Vector3(-L * 0.4, top, 0), Vector3(L * 0.4, top, 0), 1.8, s, 4)
	for side in [1, -1]:   # a little gabled thatch roof over the ridge, like their roofs
		n.add_child(_box(Vector3(L * 0.8, 2.4, 10.0), s.reed, Vector3(0, top + 3.0, 3.2 * side), Vector3(48 * side, 0, 0)))
	var y := top - 17.0
	for x in [-L * 0.25, L * 0.25]:
		n.add_child(rod(Vector3(x, top, 0), Vector3(x, y + 4.0, 0), 0.7, 0.7, s.lash, false))
	bundle(n, Vector3(-L * 0.55, y, 0), Vector3(L * 0.42, y, 0), 4.2, s, 6)
	var tip := Vector3(L * 0.42, y, 0)
	n.add_child(blob(Vector3(7.5, 6.3, 6.3), s.clay, tip + Vector3(5.5, 0, 0)))
	band(n, tip + Vector3(1.2, 0, 0), Vector3.RIGHT, 5.0, s.lash)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		n.add_child(blob(Vector3(1.8, 1.6, 1.6), s.stone, tip + Vector3(8.0, cos(a) * 4.4, sin(a) * 4.4)))
	n.add_child(blob(Vector3(2.6, 3.2, 3.2), s.stone, tip + Vector3(12.4, 0, 0)))
	for side in [1, -1]:   # team cloths hung from the ridge
		n.add_child(_box(Vector3(9.0, 7.5, 0.5), s.team, Vector3(-L * 0.12, top - 4.6, 2.4 * side)))
	return {"node": n, "sockets": {"crew0_f0_reach_in": Vector3(-L * 0.32, 0, -4.0), "crew1_f0_reach_in": Vector3(L * 0.08, 0, -4.0),
		"crew2_f0_reach": Vector3(-L * 0.5 - 12.0, 0, 9.0)}}


## The catapult: reed-bundle uprights on a sledge, a skein of twisted reed rope between two daub
## blocks, a tapered reed arm with a wicker cup holding a fired-clay ball.
func _catapult_reed(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 60.0
	var W := 26.0
	var base := 4.0
	sledge(n, s, L, W)
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L * 0.5, base + 1.0, W * 0.5 * side), Vector3(L * 0.45, base + 1.0, W * 0.5 * side), 2.2, 2.2, s.wood))
	var bar := base + 30.0
	var ux := 8.0
	for side in [1, -1]:
		bundle(n, Vector3(ux, base, W * 0.5 * side), Vector3(ux, bar, W * 0.5 * side), 2.3, s, 3)
		bundle(n, Vector3(L * 0.45, base, W * 0.5 * side), Vector3(ux, bar - 8.0, W * 0.5 * side), 1.4, s, 2)
	bundle(n, Vector3(ux, bar, -W * 0.5 - 2.0), Vector3(ux, bar, W * 0.5 + 2.0), 2.2, s, 4)
	n.add_child(rod(Vector3(ux - 2.6, bar, -W * 0.3), Vector3(ux - 2.6, bar, W * 0.3), 2.6, 2.6, s.team))   # the pad
	var pivot := Vector3(-16.0, base + 3.5, 0)
	for side in [1, -1]:   # daub blocks holding the skein
		n.add_child(_box(Vector3(7.0, 9.0, 4.0), s.daub, pivot + Vector3(0, 0.5, (W * 0.5 - 1.0) * side)))
	n.add_child(rod(pivot + Vector3(0, 0, -W * 0.45), pivot + Vector3(0, 0, W * 0.45), 3.0, 3.0, s.reed))
	for z in [-7.0, -2.5, 2.5, 7.0]:
		band(n, pivot + Vector3(0, 0, z), Vector3.BACK, 3.0, s.lash)
	var tip := Vector3(ux - 3.0, base + 50.0, 0)
	bundle(n, pivot, tip, 2.4, s, 4, 1.6)
	clay_cup(n, s, tip + Vector3(0, 1.0, 0), 4.6)
	n.add_child(rod(Vector3(-L * 0.45, base + 3.0, -W * 0.5), Vector3(-L * 0.45, base + 3.0, W * 0.5), 2.0, 2.0, s.dark))   # the winding log
	for side in [1, -1]:
		n.add_child(rod(Vector3(-L * 0.45, base + 3.0, W * 0.5 * side), Vector3(-L * 0.45 - 4.0, base + 8.0, W * 0.5 * side), 0.8, 0.8, s.dark))
	for k in 3:   # clay shot by the loader
		n.add_child(blob(Vector3.ONE * 3.2, s.clay, Vector3(-L * 0.2 + (k % 2) * 6.0, 3.0 + (k / 2) * 4.6, W * 0.5 + 6.0 + (k % 2) * 2.0)))
	return {"node": n, "sockets": {"crew0_f0_raise": Vector3(-L * 0.5 - 15.0, 0, 0), "crew1_f0_reach": Vector3(-L * 0.32, 0, W * 0.5 + 16.0)}}


## The bolt thrower: a heavy crossbow on a lashed trestle on a sledge, bow arms of bent reed bundles,
## a sharpened reed spear for a bolt, a woven wicker mantlet in front.
func _bolt_reed(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 50.0
	var W := 24.0
	var base := 4.0
	var y := 32.0
	sledge(n, s, L, W)
	for x in [-10.0, 10.0]:
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, base, 9.0 * side), Vector3(0, y - 2.0, 0), 1.2, 1.0, s.dark))
	n.add_child(blob(Vector3.ONE * 2.8, s.lash, Vector3(0, y - 2.0, 0)))
	n.add_child(beam(Vector3(-26, y, 0), Vector3(22, y, 0), 3.2, 2.6, s.dark))
	var bx := 18.0
	for side in [1, -1]:
		var mid := Vector3(bx - 2.0, y + 0.6, 14.0 * side)
		var end := Vector3(bx - 10.0, y + 0.6, 26.0 * side)
		bundle(n, Vector3(bx, y + 0.6, 2.0 * side), mid, 2.0, s, 2, 1.6)
		bundle(n, mid, end, 1.6, s, 1, 1.0)
		n.add_child(rod(end, Vector3(-16.0, y + 1.4, 0), 0.4, 0.4, s.lash, false))
	n.add_child(_box(Vector3(5.0, 4.4, 5.0), s.lash, Vector3(bx, y + 0.6, 0)))
	n.add_child(rod(Vector3(-16.0, y + 2.4, 0), Vector3(32.0, y + 2.4, 0), 1.0, 0.9, s.stalk))   # the reed spear
	n.add_child(cone(0.1, 1.2, 6.0, plain(Color("#3a2a1c")), Vector3(35.0, y + 2.4, 0), Vector3(0, 0, -90), 8))   # fire-hardened point
	for side in [1, -1]:
		n.add_child(slab([Vector2(0, 0), Vector2(5.0, 0), Vector2(1.0, 2.4 * side)], 0.3, surf("reed_leaf", Color.WHITE, 3.0), Vector3(-15.0, y + 2.4, 0)))
	# The wicker mantlet: a woven screen in three panels, leaning back.
	for k in [-1, 0, 1]:
		n.add_child(_box(Vector3(2.0, 22.0, 15.0), s.wicker, Vector3(17.0 - absf(k) * 3.0, base + 11.0, k * 13.5), Vector3(0, -k * 28, 12)))
	n.add_child(_box(Vector3(0.6, 8.0, 9.0), s.team, Vector3(19.6, base + 13.0, 0), Vector3(0, 0, 12)))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-48.0, 0, 10.0), "crew1_f0_reach": Vector3(-24.0, 0, -34.0)}}


# ------------------------------------------------------------------ B: living swamp beasts

## A giant snapping turtle: a high ridged shell, a long neck and hooked beak under a fired-clay
## casque, thick clawed legs, a spiked tail; two frogs ride in a wicker basket on its back.
func _ram_beast(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("hide", Color(0.4, 0.41, 0.36), 6.0)
	var shell := surf("chitin", Color("#5e5a32"), 8.0)
	shell.roughness = 0.6
	var keel := surf("chitin", Color("#4a4626"), 5.0)
	var horn := plain(Color("#2c2a20"))
	var C := Vector3(-4, 12, 0)
	var R := Vector3(33, 23, 25)
	for leg in [[16.0, 1], [16.0, -1], [-20.0, 1], [-20.0, -1]]:
		var x: float = leg[0]
		var side: float = leg[1]
		var hip := Vector3(x, 11.0, 18.0 * side)
		var foot := Vector3(x + 4.0, 1.2, 26.0 * side)
		n.add_child(rod(hip, foot, 6.0, 4.6, skin))
		n.add_child(blob(Vector3(5.5, 2.2, 5.0), skin, foot))
		for t in 3:
			n.add_child(cone(0.1, 0.9, 3.0, horn, foot + Vector3(5.5, -0.6, (t - 1) * 2.4), Vector3(0, 0, -90), 6))
	n.add_child(blob(Vector3(29, 6, 22), plain(Color("#8a7c52")), C + Vector3(0, -1.5, 0)))   # the plastron
	n.add_child(dome(R, shell, C))
	n.add_child(blob(Vector3(R.x + 1.0, 2.6, R.z + 1.0), keel, C))   # the shell's rim
	for k in 5:   # the rim saw-toothed at the back
		var a := PI * 0.6 + k * PI * 0.2
		n.add_child(cone(0.2, 2.4, 5.0, keel, C + Vector3(cos(a) * (R.x + 2.0), -0.5, sin(a) * (R.z + 2.0)), Vector3(0, -rad_to_deg(a), 90), 6))
	for z in [-12.0, 0.0, 12.0]:   # three keels of knobs
		for k in 6:
			var x := -28.0 + k * 9.0
			var q := 1.0 - pow((x - C.x) / R.x, 2) - pow(z / R.z, 2)
			if q > 0.05:
				n.add_child(blob(Vector3(4.4, 2.0, 2.4), keel, Vector3(x, C.y + R.y * sqrt(q) - 0.6, z)))
	# Neck, head, beak; a fired-clay casque studded with river stones for the walls.
	n.add_child(rod(Vector3(22, 16, 0), Vector3(38, 15, 0), 7.5, 6.2, skin))
	n.add_child(blob(Vector3(10, 7.5, 8.5), skin, Vector3(44, 15, 0)))
	n.add_child(blob(Vector3(4.5, 4.0, 5.0), horn, Vector3(52, 13.5, 0)))
	n.add_child(cone(0.3, 3.4, 6.0, horn, Vector3(55.5, 10.5, 0), Vector3(0, 0, -135), 10))
	n.add_child(dome(Vector3(6.4, 3.0, 6.0), s.stone, Vector3(45, 19.8, 0)))   # a stone brow plate
	for k in 4:
		n.add_child(blob(Vector3.ONE * 1.3, s.stone, Vector3(42.0 + k * 2.4, 22.6 - absf(k - 1.5) * 0.6, (k % 2) * 2.6 - 1.3)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.4, 1.4, 1.0), plain(Color("#c8a040")), Vector3(48, 17.5, 7.0 * side)))
		n.add_child(blob(Vector3(0.6, 0.8, 0.5), plain(Color("#141008")), Vector3(48.8, 17.6, 7.6 * side)))
	n.add_child(rod(Vector3(-33, 15, 0), Vector3(-46, 9, 0), 4.0, 2.4, skin))
	n.add_child(rod(Vector3(-46, 9, 0), Vector3(-56, 4, 0), 2.4, 0.6, skin))
	for k in 4:
		n.add_child(cone(0.1, 1.2, 2.6, keel, Vector3(-36.0 - k * 5.0, 17.5 - k * 2.4, 0), Vector3(0, 0, 20), 6))
	# The basket on its back, lashed down, team cloth over the shell's sides.
	var deck := C.y + R.y - 1.0
	n.add_child(cone(10.5, 9.0, 6.0, s.wicker, Vector3(-6, deck + 1.0, 0), Vector3.ZERO, 20))
	n.add_child(ring(10.0, 11.2, s.reed, Vector3(-6, deck + 4.0, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 0.6, 13.0), s.team, Vector3(-6, deck - 6.0, 15.5 * side), Vector3(48 * side, 0, 0)))
	pennant(n, s, Vector3(-15, deck + 2.0, -5), 14.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-4.0, deck + 0.5, 0.0), "crew1_f0_reach": Vector3(-46.0, 0, 22.0)}}


## A giant newt (black, an orange belly and yellow spots), a deck strapped to its back carrying a
## reed-armed catapult; one frog rides behind the arm winding, one walks beside loading.
func _catapult_beast(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", Color("#3c3a30"), 7.0)
	skin.roughness = 0.35
	var belly := surf("frog_belly", Color("#e08a2a"), 5.0)
	var spot := plain(Color("#e8b030"))
	for leg in [[18.0, 1], [18.0, -1], [-20.0, 1], [-20.0, -1]]:
		var x: float = leg[0]
		var z: float = leg[1]
		var hip := Vector3(x, 11.0, 8.0 * z)
		var elbow := Vector3(x + 3.0, 13.0, 18.0 * z)
		var foot := Vector3(x + 6.0, 0.8, 22.0 * z)
		n.add_child(rod(hip, elbow, 3.4, 2.8, skin))
		n.add_child(rod(elbow, foot, 2.8, 2.0, skin))
		for t in 4:
			n.add_child(rod(foot, foot + Vector3(3.2, -0.4, (t - 1.5) * 1.8), 0.7, 0.5, skin))
	for x in [-20.0, -6.0, 8.0]:
		n.add_child(blob(Vector3(14.0, 8.0, 10.5), skin, Vector3(x, 13.0, 0)))
	n.add_child(blob(Vector3(36.0, 4.5, 9.0), belly, Vector3(-5.0, 7.5, 0)))
	n.add_child(blob(Vector3(10.0, 5.0, 10.0), skin, Vector3(28.0, 12.5, 0)))   # the flat head
	n.add_child(blob(Vector3(7.5, 2.2, 8.0), belly, Vector3(29.0, 9.5, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.2, 2.0, 2.0), skin, Vector3(31.0, 16.0, 6.0 * side)))
		n.add_child(blob(Vector3(1.0, 1.0, 0.8), plain(Color("#c89830")), Vector3(32.4, 16.6, 7.2 * side)))
	n.add_child(rod(Vector3(-30, 12, 0), Vector3(-48, 9, 0), 6.5, 3.5, skin))
	n.add_child(rod(Vector3(-48, 9, 0), Vector3(-66, 5, 0), 3.5, 0.8, skin))
	var spots := [[-34, 15, 3], [-24, 20, -4], [-12, 21, 5], [-2, 20, -6], [14, 19, 4], [22, 16, -5], [-44, 12, -2], [28, 16.5, 2]]
	for p in spots:
		n.add_child(blob(Vector3(2.0, 1.0, 1.8), spot, Vector3(p[0], p[1], p[2])))
	# The deck on its back, strapped under the belly; the catapult on the deck.
	var d := 21.5
	n.add_child(_box(Vector3(36.0, 1.8, 20.0), s.dark, Vector3(-4.0, d, 0)))
	for x in [-14.0, 6.0]:
		n.add_child(ring(0.6, 0.9, s.lash, Vector3(x, 13.5, 0), Vector3(0, 0, 90), Vector3(9.0, 1, 11.0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(30.0, 6.0, 0.6), s.team, Vector3(-4.0, d - 3.5, 10.4 * side), Vector3(12 * side, 0, 0)))
	var bar := d + 24.0
	for side in [1, -1]:
		bundle(n, Vector3(6.0, d, 8.5 * side), Vector3(6.0, bar, 8.5 * side), 1.9, s, 2)
		bundle(n, Vector3(13.0, d, 8.5 * side), Vector3(6.0, bar - 7.0, 8.5 * side), 1.1, s, 1)
	bundle(n, Vector3(6.0, bar, -10.5), Vector3(6.0, bar, 10.5), 1.8, s, 3)
	n.add_child(rod(Vector3(3.8, bar, -6.0), Vector3(3.8, bar, 6.0), 2.2, 2.2, s.team))
	var pivot := Vector3(-12.0, d + 3.0, 0)
	n.add_child(rod(pivot + Vector3(0, 0, -8.0), pivot + Vector3(0, 0, 8.0), 2.6, 2.6, s.reed))
	var tip := Vector3(3.0, d + 42.0, 0)
	bundle(n, pivot, tip, 2.0, s, 3, 1.4)
	clay_cup(n, s, tip + Vector3(0, 0.8, 0), 4.0)
	return {"node": n, "sockets": {"crew0_f0_raise_top": Vector3(-20.0, d + 0.9, 0), "crew1_f0_reach": Vector3(-6.0, 0, 30.0)}}


## A giant toad (brown, warty, gold-eyed) with a bolt thrower on a saddle on its back: a frog
## aims from its rump, another loads from beside it.
func _bolt_beast(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("frog_skin", Color("#a08a52"), 6.0)
	skin.roughness = 0.6
	var wart := plain(Color("#5a4a26"))
	var belly := surf("frog_belly", Color("#b8a478"), 5.0)
	for side in [1, -1]:
		n.add_child(blob(Vector3(13.0, 8.5, 6.5), skin, Vector3(-12.0, 9.0, 15.0 * side), Vector3(0, 0, 18)))   # folded hind legs
		n.add_child(rod(Vector3(-4.0, 1.0, 18.0 * side), Vector3(6.0, 0.8, 21.0 * side), 2.4, 1.6, skin))
		n.add_child(rod(Vector3(12.0, 15.0, 11.0 * side), Vector3(17.0, 1.0, 16.0 * side), 3.6, 2.8, skin))   # front legs
		for t in 4:
			n.add_child(rod(Vector3(17.0, 1.0, 16.0 * side), Vector3(21.0, 0.6, (16.0 + (t - 1.5) * 1.8) * side), 0.8, 0.6, skin))
	n.add_child(blob(Vector3(21.0, 15.0, 19.0), skin, Vector3(-3.0, 18.0, 0), Vector3(0, 0, 12)))
	n.add_child(blob(Vector3(14.0, 6.0, 12.0), belly, Vector3(5.0, 9.0, 0)))
	n.add_child(blob(Vector3(11.0, 8.0, 14.0), skin, Vector3(16.0, 20.0, 0)))
	n.add_child(rod(Vector3(24.5, 17.5, -11.0), Vector3(26.6, 17.5, 0), 0.5, 0.5, plain(INK)))   # the wide mouth
	n.add_child(rod(Vector3(26.6, 17.5, 0), Vector3(24.5, 17.5, 11.0), 0.5, 0.5, plain(INK)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(3.2, 3.0, 3.0), skin, Vector3(18.0, 27.0, 8.0 * side)))
		n.add_child(blob(Vector3(1.8, 1.8, 1.4), plain(Color("#d8a830")), Vector3(20.0, 27.8, 9.4 * side)))
		n.add_child(blob(Vector3(0.6, 1.0, 0.5), plain(Color("#140c06")), Vector3(21.2, 28.0, 10.0 * side)))
		n.add_child(blob(Vector3(5.0, 2.4, 3.0), wart, Vector3(10.0, 27.0, 10.0 * side), Vector3(0, 0, -15)))   # the glands
	for k in 26:   # warts, spread by the golden angle over the upper back
		var a := k * 2.39996
		var b := fmod(k * 0.618034, 1.0) * 1.2
		var at := on_surface(Vector3(-3.0, 18.0, 0), Vector3(21.0, 15.0, 19.0), Vector3(cos(a) * sin(b), cos(b), sin(a) * sin(b)), -0.6)
		n.add_child(blob(Vector3.ONE * (1.0 + fmod(k * 0.37, 0.8)), wart, at))
	# The saddle (team cloth) and the bolt thrower on a short post.
	var top := 33.0
	n.add_child(_box(Vector3(20.0, 0.8, 24.0), s.team, Vector3(-4.0, top - 1.0, 0), Vector3(0, 0, 10)))
	n.add_child(_box(Vector3(10.0, 2.0, 10.0), s.dark, Vector3(-2.0, top, 0)))
	n.add_child(rod(Vector3(-2.0, top, 0), Vector3(-2.0, top + 6.0, 0), 1.6, 1.4, s.dark))
	var y := top + 7.0
	n.add_child(beam(Vector3(-20, y, 0), Vector3(18, y, 0), 2.8, 2.2, s.dark))
	var bx := 16.0
	for side in [1, -1]:
		var mid := Vector3(bx - 2.0, y + 0.5, 13.0 * side)
		var end := Vector3(bx - 9.0, y + 0.5, 24.0 * side)
		bundle(n, Vector3(bx, y + 0.5, 1.8 * side), mid, 2.0, s, 1, 1.6)
		bundle(n, mid, end, 1.6, s, 1, 1.0)
		n.add_child(rod(end, Vector3(-14.0, y + 1.2, 0), 0.4, 0.4, s.lash, false))
	n.add_child(_box(Vector3(4.6, 4.0, 4.6), s.lash, Vector3(bx, y + 0.5, 0)))
	n.add_child(rod(Vector3(-14.0, y + 2.2, 0), Vector3(32.0, y + 2.2, 0), 1.0, 0.9, s.stalk))
	n.add_child(cone(0.1, 1.2, 6.0, plain(Color("#3a2a1c")), Vector3(35.0, y + 2.2, 0), Vector3(0, 0, -90), 8))
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-20.0, 27.0, 0), "crew1_f0_reach": Vector3(-6.0, 0, -30.0)}}


# ------------------------------------------------------------------ C: river engines

## The ram: a punt dragged through the shallows, the log hung from crossed punt poles, its head a
## river stone in a net; eel traps and a net over the side.
func _ram_river(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 78.0
	var W := 22.0
	var H := 9.0
	punt(n, s, L, W, H)
	var top := 44.0
	for x in [-L * 0.28, L * 0.28]:   # shear legs: two poles crossing, their ends past the cross
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, 1.5, W * 0.45 * side), Vector3(x, top + 6.0, -2.0 * side), 0.9, 0.8, s.wood))
		band(n, Vector3(x, top, 0), Vector3.BACK, 1.6, s.lash)
	n.add_child(rod(Vector3(-L * 0.36, top, 0), Vector3(L * 0.36, top, 0), 1.2, 1.2, s.wood))
	var y := top - 18.0
	for x in [-L * 0.22, L * 0.22]:
		n.add_child(rod(Vector3(x, top, 0), Vector3(x, y + 3.6, 0), 0.6, 0.6, s.rope, false))
	n.add_child(rod(Vector3(-L * 0.55, y, 0), Vector3(L * 0.44, y, 0), 3.8, 3.5, surf("bark_plate", Color(0.9, 0.85, 0.75), 6.0)))
	for x in [-L * 0.45, 0.0, L * 0.38]:
		band(n, Vector3(x, y, 0), Vector3.RIGHT, 3.7, s.lash)
	var tip := Vector3(L * 0.44 + 6.0, y, 0)
	n.add_child(blob(Vector3(7.5, 6.0, 6.0), s.stone, tip))
	for a in [0.0, 60.0, 120.0]:   # the net round the stone
		n.add_child(ring(5.8, 6.4, s.rope, tip, Vector3(a, 0, 90), Vector3(1.25, 1, 1)))
	n.add_child(ring(6.6, 7.4, s.rope, tip + Vector3(-1.5, 0, 0), Vector3(0, 0, 90)))
	eel_trap(n, s, Vector3(-L * 0.42, 3.0, -5.0), Vector3(1, 0.1, 0.1))
	eel_trap(n, s, Vector3(-L * 0.4, 3.0, 4.0), Vector3(1, 0.15, -0.15), 9.0, 2.2)
	draped_net(n, s, -L * 0.1, L * 0.22, H + 2.0, W * 0.5)
	n.add_child(_box(Vector3(8.0, 6.0, 0.5), s.team, Vector3(-L * 0.05, top - 3.8, 1.6)))
	n.add_child(_box(Vector3(8.0, 6.0, 0.5), s.team, Vector3(-L * 0.05, top - 3.8, -1.6)))
	return {"node": n, "sockets": {"crew0_f0_reach_in": Vector3(-L * 0.3, 0, -3.0), "crew1_f0_reach_in": Vector3(L * 0.08, 0, -3.0),
		"crew2_f0_reach": Vector3(-L * 0.5 - 12.0, 0, 8.0)}}


## The catapult: a swing beam on a post in a punt, a wicker basket of river stones hung on its
## short end (raised), a net of stones at the long end lying in the stern, ready to sling.
func _catapult_river(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 64.0
	var W := 24.0
	var H := 8.0
	punt(n, s, L, W, H)
	var top := 40.0
	for side in [1, -1]:
		n.add_child(beam(Vector3(2.0, 1.2, 6.0 * side), Vector3(2.0, top, 6.0 * side), 2.6, 2.6, s.dark))
		n.add_child(rod(Vector3(-16.0, 1.5, W * 0.45 * side), Vector3(2.0, top - 8.0, 6.0 * side), 1.0, 0.9, s.wood))
		n.add_child(rod(Vector3(20.0, 1.5, W * 0.45 * side), Vector3(2.0, top - 8.0, 6.0 * side), 1.0, 0.9, s.wood))
	var pivot := Vector3(2.0, top, 0)
	n.add_child(rod(pivot + Vector3(0, 0, -8.0), pivot + Vector3(0, 0, 8.0), 1.2, 1.2, s.dark))
	var front := pivot + Vector3(12.0, 10.0, 0)
	var back := pivot + Vector3(-38.0, -25.0, 0)
	n.add_child(rod(back, front, 1.6, 2.8, s.wood))
	for t in [0.55, 0.85]:
		band(n, back.lerp(front, t), front - back, 1.9, s.lash)
	# The stone basket hanging from the raised short end.
	n.add_child(rod(front, front + Vector3(0.5, -9.0, 0), 0.5, 0.5, s.rope, false))
	n.add_child(cone(6.2, 4.8, 8.0, s.wicker, front + Vector3(0.5, -13.0, 0), Vector3.ZERO, 16))
	n.add_child(ring(5.8, 6.8, s.reed, front + Vector3(0.5, -9.2, 0)))
	for k in 5:
		var a := TAU * k / 5.0
		n.add_child(blob(Vector3(2.4, 2.0, 2.2), s.stone, front + Vector3(0.5 + cos(a) * 2.8, -8.6, sin(a) * 2.8)))
	# The net of stones in the stern, on two cords from the long end.
	var bag := Vector3(-24.0, 5.0, 0)
	for z in [-1.4, 1.4]:
		n.add_child(rod(back, bag + Vector3(1.0, 2.0, z), 0.35, 0.35, s.rope, false))
	for k in 4:
		n.add_child(blob(Vector3(2.4, 2.0, 2.2), s.stone, bag + Vector3((k % 2) * 3.0 - 1.5, (k / 2) * 2.2, (k % 3) * 1.6 - 1.6)))
	n.add_child(blob(Vector3(4.6, 3.2, 3.8), s.net, bag + Vector3(0, 0.6, 0)))
	n.add_child(_box(Vector3(0.5, 7.0, 6.0), s.team, Vector3(3.6, top - 8.0, 6.0)))
	pennant(n, s, Vector3(-L * 0.46, H + 1.5, -6.0), 15.0, 4.0)
	eel_trap(n, s, Vector3(14.0, 3.0, 5.0), Vector3(1, 0.12, -0.1), 9.0, 2.2)
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-L * 0.5 - 13.0, 0, 6.0), "crew1_f0_raise": Vector3(6.0, 0, W * 0.5 + 15.0)}}


## The bolt thrower: a harpoon thrower on a post at a punt's bow, a barbed bone harpoon, its line
## coiled in a basket; eel traps in the stern and a net over the side.
func _bolt_river(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 54.0
	var W := 20.0
	var H := 7.0
	punt(n, s, L, W, H)
	var y := 28.0
	n.add_child(rod(Vector3(6.0, 1.2, 0), Vector3(6.0, y - 2.0, 0), 2.2, 1.8, s.dark))
	for side in [1, -1]:
		n.add_child(rod(Vector3(14.0, 1.5, W * 0.4 * side), Vector3(6.0, y - 8.0, 0), 0.9, 0.8, s.wood))
	n.add_child(beam(Vector3(-22, y, 0), Vector3(20, y, 0), 3.0, 2.4, s.dark))
	var bx := 16.0
	for side in [1, -1]:
		var mid := Vector3(bx - 2.0, y + 0.6, 12.0 * side)
		var end := Vector3(bx - 9.0, y + 0.6, 22.0 * side)
		n.add_child(rod(Vector3(bx, y + 0.6, 1.8 * side), mid, 1.4, 1.1, s.wood))
		n.add_child(rod(mid, end, 1.1, 0.6, s.wood))
		n.add_child(rod(end, Vector3(-14.0, y + 1.4, 0), 0.35, 0.35, s.rope, false))
	n.add_child(_box(Vector3(4.4, 4.0, 4.6), s.lash, Vector3(bx, y + 0.6, 0)))
	var bone := plain(Color("#e6dcc4"))
	n.add_child(rod(Vector3(-14.0, y + 2.2, 0), Vector3(30.0, y + 2.2, 0), 0.9, 0.9, s.wood))
	n.add_child(cone(0.1, 1.3, 5.0, bone, Vector3(32.5, y + 2.2, 0), Vector3(0, 0, -90), 8))
	for side in [1, -1]:
		n.add_child(slab([Vector2(0, 0), Vector2(-3.4, 2.4 * side), Vector2(-1.4, 0)], 0.5, bone, Vector3(31.0, y + 2.2, 0)))
	# The line, from the harpoon's tail down to its basket.
	var coil := Vector3(-4.0, 3.0, 5.0)
	n.add_child(cone(4.0, 3.2, 5.0, s.wicker, coil, Vector3.ZERO, 14))
	n.add_child(ring(2.4, 3.6, s.rope, coil + Vector3(0, 2.6, 0)))
	n.add_child(rod(Vector3(-14.0, y + 2.2, 0), coil + Vector3(0, 3.0, 0), 0.3, 0.3, s.rope, false))
	eel_trap(n, s, Vector3(-L * 0.42, 3.0, -4.0), Vector3(1, 0.1, 0.1), 10.0, 2.4)
	draped_net(n, s, -L * 0.3, L * 0.05, H + 2.0, W * 0.5)
	pennant(n, s, Vector3(-L * 0.47, H + 1.0, -5.0), 14.0, 4.0)
	n.add_child(_box(Vector3(5.0, 0.4, 4.0), s.team, Vector3(-17.0, y + 1.4, 0)))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-46.0, 0, 8.0), "crew1_f0_reach": Vector3(-8.0, 0, -30.0)}}
