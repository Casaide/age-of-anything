extends "res://scenes/art_pixel/unit_models.gd"
## Siege engines (milestone 13): the models in play, and the concept rounds they were picked from
## (SW1, D-116 to D-119; the concept ids are scenes/art_pixel/siege_concepts.gd's).
## In play: "siege.<engine>.<take>" (parts.json, slot "engine"), e.g. "siege.ram.timber":
##   engine  ram, catapult, bolt
##   take    timber (every human culture, trimmed in its cloth), junk (the rats' sewer junk at
##           human scale), forest (bark and acorns; the ram a giant beetle, ridden), spooky (dark
##           wood and bone): families.json `siege` says whose
## Picked (D-119): the open ram crewed (the forest's: the ridden giant beetle; the timber take's
## now roofed with hides, TIMBER_RAM_ROOF), the arm-and-cup
## catapult and the carriage bolt thrower, crewed; the crew are the race's own workers, drawn by
## UnitView on the sockets "crew<n>_f<k>[_reach|_raise][_in|_top]" (see ROUND2_SCALE's note).
## Same frame as the unit parts: part units, x forward, y up, z towards the viewer's side,
## standing on y = 0. A soldier is about 35 tall; a ram about 46 long.

## In-play take -> the concept family whose look it is.
const TAKE_STYLE := {"timber": "timber", "junk": "junk", "forest": "forest", "spooky": "spooky", "frog": "frog"}
## Engines a take builds from another direction than the crewed "c" (each at its own true size):
## the forest's ram is the ridden giant beetle (D-119); the frogs' engines are swamp beasts (D-121,
## D-122): a snapping turtle ram, a giant snail carrying the reed catapult, a toad-borne bolt thrower.
const OWN := {"ram.forest": "_ram_ridden", "ram.frog": "_ram_beast", "catapult.frog": "_catapult_snail", "bolt.frog": "_bolt_beast",
	"sling.timber": "_sling_in_play", "sling.junk": "_sling_in_play", "sling.forest": "_sling_in_play", "sling.spooky": "_sling_in_play",
	"sling_packed.timber": "_packed_in_play", "sling_packed.junk": "_packed_in_play", "sling_packed.forest": "_packed_in_play", "sling_packed.spooky": "_packed_in_play",
	"sling.frog": "_frog_sling_in_play", "sling_throw.frog": "_frog_throw_in_play", "sling_packed.frog": "_frog_packed_in_play"}
## War beasts in play (D-129): "siege.beast.<kind>" -> its builder and the materials of its howdah or harness.
## Which creature or culture gets which: creatures.json / families.json `war_beast`.
const BEAST := {"elephant": "_beast_elephant", "boar": "_beast_boar", "tarantula": "_beast_tarantula", "heron": "_beast_heron", "mantis": "_beast_mantis"}
const BEAST_STYLE := {"elephant": "timber", "boar": "junk", "tarantula": "spooky", "heron": "frog", "mantis": "forest"}
## A take whose engine isn't picked yet builds another take's look (the frogs wheeled out the timber
## catapult until D-122).
const STAND_IN := {}
## An engine whose own look isn't picked yet wears another engine's ("<engine>.<take>" -> engine): the frogs'
## great sling wore their snail catapult until D-131 (FS1 A, the bullfrog leaper: _frog_sling).
const ENGINE_STAND_IN := {}


func has(id: String) -> bool:
	return _engine_id(id) or _shot_id(id) or super.has(id)


func build(id: String, colours: Dictionary) -> Dictionary:
	if _shot_id(id):
		return shot_model(id, colours)
	if not _engine_id(id):
		return super.build(id, colours)
	var p := id.split(".")
	if p[1] == "cart":   # the trade cart (D-127): the take's beast pulls it, the frogs' snail
		return trade_cart(p[2], colours)
	if p[1] in ["barrow", "handcart"]:   # what a worker pushes home with stone or gold (D-127: the rats)
		return pushed_home(p[1], _style(TAKE_STYLE[p[2]], colours), colours)
	if p[1] == "beast":   # a war beast (D-129): its riders on top, or beside it for a crew too big to ride
		return _beside(call(BEAST[p[2]], _style(BEAST_STYLE[p[2]], colours)), p[2], colours)
	var engine: String = ENGINE_STAND_IN.get("%s.%s" % [p[1], p[2]], p[1])
	var key := "%s.%s" % [engine, p[2]]
	p[1] = engine
	var s := _style(STAND_IN.get(key, TAKE_STYLE[p[2]]), colours)
	var spec: Dictionary = call(OWN[key], s, colours) if OWN.has(key) else _scaled(call("_%s_c" % p[1], s, colours), ROUND2_SCALE.c[p[1]])
	# A crew too big for the frame (a centaur's horse half went through a ram's posts: the placement
	# check) works it from beside it: each "_in" socket has a "_wide" one out past the engine's side.
	for name in spec.get("sockets", {}).keys():
		if name.ends_with("_in"):
			var at: Vector3 = spec.sockets[name]
			spec.sockets[name.trim_suffix("_in") + "_wide"] = Vector3(at.x, at.y, (1.0 if at.z > 0.0 else -1.0) * WIDE_CREW)
	return spec


const WIDE_CREW := 17.0   # how far out from the middle a crew too big for the frame stands


## An engine in play: "siege.<engine>.<take>" (three parts; the concepts' ids have four).
static func _engine_id(id: String) -> bool:
	return id.begins_with("siege.") and id.count(".") == 2

const ROPE := Color("#c8b48a")
const DARK_WOOD := Color(0.45, 0.38, 0.36)
## Round 2's directions: "c" crewed (the open ram, the arm-and-cup catapult, the carriage bolt
## thrower, each with its crew's sockets), "shed" the rats' covered ram pushed from behind,
## "ridden" and "led" the forest's giant beetle (built at its own size).
## Crew socket names carry how the crew member stands: "crew<n>_f<k>[_reach|_raise][_in|_top]":
## f<k> turns them k facings from the engine's, reach/raise is the arm hold, "in" draws them
## behind the engine (inside its frame), "top" over it (riding).
const ROUND2_SCALE := {"c": {"ram": 1.5, "catapult": 1.8, "bolt": 2.1, "tower": 1.0},
	"shed": {"ram": 1.45}, "ridden": {"ram": 1.0}, "led": {"ram": 1.0}, "mount": {"ram": 1.0}}


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
	for k in ["rope", "lash"]:   # ropes are tied at both ends (the placement check, C3: no loose ends)
		if s.has(k):
			s[k].set_meta("rope", true)
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
	var spec: Dictionary
	if s.fam == "junk":
		spec = _ram_c_junk(s, c)
	elif s.fam == "timber" and TIMBER_RAM_ROOF != "":
		spec = _ram_covered(s, c, TIMBER_RAM_ROOF)
	else:
		spec = _ram_b(s, c)
	var L := 42.0
	spec.sockets = {"crew0_f0_reach_in": Vector3(-L * 0.3, 0, -2.5), "crew1_f0_reach_in": Vector3(L * 0.1, 0, -2.5),
		"crew2_f0_reach": Vector3(-L * 0.5 - 5.0, 0, 5.0),
		"crew2_f0_reach_wide": Vector3(-L * 0.5 - 12.0, 0, 5.0)}   # (a centaur's torso rose in front of the roof's eave at the back: placement C4)
	if s.fam == "timber" and TIMBER_RAM_ROOF != "":   # under a roof: one each side of the log, so one always shows
		spec.sockets.crew0_f0_reach_in = Vector3(-L * 0.3, 0, 3.0)
		spec.sockets.crew1_f0_reach_in = Vector3(L * 0.1, 0, -3.0)
	elif s.fam == "junk":   # the pipe frame is narrower at the log: walking, the rats' legs went into it at 2.5 (C1)
		spec.sockets.crew0_f0_reach_in.z = -3.2
		spec.sockets.crew1_f0_reach_in.z = -3.2
	return spec


## The human (timber) ram's roof (Dominic: "needs a roof to be more traditional"): "hides" wet
## hides lashed over a ridge pole, "planks" a plank roof with a short hide skirt, "" the open ram.
const TIMBER_RAM_ROOF := "hides"


## The covered ram: corner posts on the wheeled frame carry a pitched roof (hides or planks), the
## log hung from the ridge beam under it, iron head out the front. The sides stay open from the
## rails to the eaves so the crew show underneath swinging the log; a team cloth over the ridge.
func _ram_covered(s: Dictionary, c: Dictionary, roof: String) -> Dictionary:
	var n := Node3D.new()
	var L := 42.0
	var W := 12.0
	var wr := 4.2
	var base := wr + 1.0
	var eave := 23.0           # the top plates: the crew stand under them
	var ridge := 30.5
	var px := L * 0.36         # the posts, front and back
	undercarriage(n, s, L, W, wr)
	for side in [1, -1]:
		var z: float = W * 0.5 * side
		n.add_child(beam(Vector3(-L * 0.5, base, z), Vector3(L * 0.5, base, z), 1.4, 1.4, s.dark))   # the rails
		n.add_child(beam(Vector3(-px - 1.5, eave, z), Vector3(px + 1.5, eave, z), 1.2, 1.2, s.dark))   # the top plates
		for x in [-px, px]:
			n.add_child(beam(Vector3(x, base, z), Vector3(x, eave, z), 1.2, 1.2, s.wood))   # the posts
		n.add_child(rod(Vector3(-px, base + 0.5, z), Vector3(0.0, eave - 0.5, z), 0.4, 0.4, s.wood, false))   # a brace
	for x in [-px, px]:   # the gables: a tie beam, a king post, rafters up to the ridge
		n.add_child(beam(Vector3(x, eave, -W * 0.5), Vector3(x, eave, W * 0.5), 1.2, 1.2, s.dark))
		n.add_child(beam(Vector3(x, eave, 0), Vector3(x, ridge, 0), 1.0, 1.0, s.wood))
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, eave - 0.6, (W * 0.5 + 1.6) * side), Vector3(x, ridge, 0), 0.55, 0.5, s.wood, false))
	var rx := px + 3.5         # the roof's half length (a little over the gables)
	n.add_child(beam(Vector3(-rx, ridge, 0), Vector3(rx, ridge, 0), 1.3, 1.3, s.dark))
	var y := 17.0              # the log, hung from the ridge beam
	for x in [-L * 0.25, L * 0.25]:
		n.add_child(rod(Vector3(x, ridge, 0), Vector3(x, y + 2.0, 0), 0.35, 0.35, s.rope, false))
	ram_log(n, s, -L * 0.55, L * 0.5 + 8.0, y, 3.0)
	var ze := W * 0.5 + 1.8    # the eaves' overhang
	var ye := eave - 0.6
	if roof == "hides":
		_hide_roof(n, s, rx, ridge, ze, ye)
	else:
		_plank_roof(n, s, rx, ridge, ze, ye)
	# A team cloth laid over the ridge, short, near the back.
	var a := atan2(ridge - ye, ze)
	for side in [1, -1]:
		var d := 2.8
		var at := Vector3(-rx * 0.35, ridge + 0.75 - sin(a) * d * 0.5, cos(a) * d * 0.5 * side)
		n.add_child(_box(Vector3(7.0, 0.35, d), s.team, at, Vector3(rad_to_deg(a) * side, 0, 0)))
	return {"node": n, "sockets": {}}


## One slope of a roof: a box `len` long (along x) from the ridge down to the eave at z = ze*side.
func _slope(m: Material, x: float, len: float, ridge: float, ze: float, ye: float, side: int, thick: float, lift := 0.0) -> MeshInstance3D:
	var a := atan2(ridge - ye, ze)
	var d := Vector2(ze, ridge - ye).length()
	var mid := Vector3(x, (ridge + ye) * 0.5 + lift, ze * 0.5 * side)
	return _box(Vector3(len, thick, d), m, mid, Vector3(rad_to_deg(a) * side, 0, 0))


## Wet hides lashed over the rafters: big skins in three browns, each laid a little askew so
## their edges overlap unevenly and hang ragged below the eave, held down by ropes thrown over the
## ridge and tied off at the eaves (zigzag lashing), and a rope along each slope.
func _hide_roof(n: Node3D, s: Dictionary, rx: float, ridge: float, ze: float, ye: float) -> void:
	var hides := [surf("hide", Color(0.6, 0.44, 0.31), 6.0), s.roof, surf("hide", Color(0.48, 0.34, 0.24), 6.0)]
	var lash := plain(Color("#3e2e20"))
	var count := 3
	var w := rx * 2.0 / count
	for side in [1, -1]:
		var o := 1 if side < 0 else 0
		for k in count:
			var x := -rx + w * (k + 0.5) + (0.8 if (k + o) % 2 == 0 else -0.6)
			var drop: float = [0.4, 1.4, 0.8][(k + o) % 3]   # the skins hang unevenly
			var hide := _slope(hides[(k + o) % 3], x, w + 2.2, ridge + 0.5, ze + drop * 0.5, ye - drop, side, 0.5, 0.15 * ((k + o) % 2))
			hide.rotation_degrees.y = [4.0, -3.0, 5.0][(k + o) % 3]
			n.add_child(hide)
		for k in count * 2 + 1:   # the lashing zigzags from the ridge to the eave pegs
			var x0 := -rx + w * 0.5 * k
			var x1 := x0 + (w * 0.5 if k % 2 == 0 else -w * 0.5)
			if absf(x1) > rx + 0.1:
				continue
			n.add_child(rod(Vector3(x0, ridge + 1.0, 0), Vector3(x1, ye - 0.4, (ze + 0.4) * side), 0.3, 0.3, lash, false))
		var p := Vector3(0, ridge + 1.0 + (ye - ridge) * 0.55, ze * 0.55 * side)
		n.add_child(rod(p - Vector3(rx + 0.3, 0, 0), p + Vector3(rx + 0.3, 0, 0), 0.3, 0.3, lash, false))


## A plank roof: boards ridge to eave in two woods, battens along it, and a short hide skirt.
func _plank_roof(n: Node3D, s: Dictionary, rx: float, ridge: float, ze: float, ye: float) -> void:
	var count := 10
	var w := rx * 2.0 / count
	for side in [1, -1]:
		for k in count:
			var m: Material = s.wood if (k + (1 if side < 0 else 0)) % 3 != 0 else s.dark
			n.add_child(_slope(m, -rx + w * (k + 0.5), w - 0.25, ridge + 0.4, ze, ye, side, 0.6, 0.1 * (k % 2)))
		for t in [0.3, 0.8]:
			var p := Vector3(0, ridge + 0.9 + (ye - ridge) * t, ze * t * side)
			n.add_child(beam(p - Vector3(rx, 0, 0), p + Vector3(rx, 0, 0), 0.6, 0.5, s.dark))
		n.add_child(_box(Vector3(rx * 2.0, 2.6, 0.35), s.roof, Vector3(0, ye - 1.3, (ze + 0.1) * side), Vector3(-8 * side, 0, 0)))   # the hide skirt


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


## The siege tower (milestone 16; walls round 3, D-130: sized to the tall curtain). PLACEHOLDER for
## every take until Dominic picks a concept: a timber tower on four wheels, hide-hung on three sides,
## three storeys: the gangway's floor at the wall walk's height (WALL_WALK: Models.WALK_H.wall in part
## units, a stone wall's walk being 1.36 model units up), the fighting top a storey over it, so it stands
## clearly taller than the wall; the gangway raised against the front, hinged at the walk's height, its
## ropes tied to the top's parapet; the team's pennant on top; two of the race's workers push at the
## open back, apart.
const PART_PER_MODEL := 55.0   # part units per building model unit (a soldier about 35: two-thirds of one)
const WALL_WALK := 1.36 * PART_PER_MODEL


func _tower_c(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 34.0
	var W := 26.0
	var wr := 4.6
	undercarriage(n, s, L, W, wr)
	var base := wr + 1.2
	var deck := WALL_WALK + 1.0          # the gangway's floor, level with the walk
	var top := deck + 0.8 * PART_PER_MODEL   # the fighting top: a storey over the walk
	var taper := func(y: float) -> float: return 1.0 - (y - base) / (top - base) * 0.12
	for x in [-L * 0.45, L * 0.45]:
		for z in [-W * 0.45, W * 0.45]:
			n.add_child(beam(Vector3(x, base, z), Vector3(x * taper.call(top), top, z * taper.call(top)), 2.0, 2.0, s.wood))
	for y in [base, (base + deck) * 0.5, deck, top]:   # the floors' frames
		var k: float = taper.call(y)
		for z in [-W * 0.45 * k, W * 0.45 * k]:
			n.add_child(beam(Vector3(-L * 0.45 * k, y, z), Vector3(L * 0.45 * k, y, z), 1.4, 1.4, s.dark))
		for x in [-L * 0.45 * k, L * 0.45 * k]:
			n.add_child(beam(Vector3(x, y, -W * 0.45 * k), Vector3(x, y, W * 0.45 * k), 1.4, 1.4, s.dark))
	var hide: Material = s.get("roof", s.wood)
	for lo_hi in [[base + 2.0, deck - 1.0], [deck + 1.0, top - 1.0]]:   # hides down both sides and the front, a storey at a time
		var y0: float = lo_hi[0]
		var y1: float = lo_hi[1]
		var k: float = taper.call((y0 + y1) * 0.5)
		for z in [-W * 0.43 * k, W * 0.43 * k]:
			n.add_child(_box(Vector3(L * 0.84 * k, y1 - y0, 0.5), hide, Vector3(0, (y0 + y1) * 0.5, z)))
		n.add_child(_box(Vector3(0.5, y1 - y0, W * 0.84 * k), hide, Vector3(L * 0.43 * k, (y0 + y1) * 0.5, 0)))
	var kt: float = taper.call(top)
	n.add_child(_box(Vector3(L * 0.86 * kt, 1.2, W * 0.86 * kt), s.dark, Vector3(0, top, 0)))   # the top deck
	for z in [-W * 0.4 * kt, W * 0.4 * kt]:   # its parapet
		n.add_child(_box(Vector3(L * 0.8 * kt, 4.0, 1.0), s.wood, Vector3(0, top + 2.0, z)))
	n.add_child(_box(Vector3(1.0, 4.0, W * 0.8 * kt), s.wood, Vector3(L * 0.4 * kt, top + 2.0, 0)))
	# The gangway, raised: hinged at the walk's height on the front, standing up against the hides.
	var kd: float = taper.call(deck)
	var gx := L * 0.45 * kd + 1.4
	var g_len := 30.0
	n.add_child(_box(Vector3(1.2, g_len, W * 0.6), s.wood, Vector3(gx, deck + g_len * 0.5, 0)))
	for z in [-W * 0.26, W * 0.26]:   # its ropes, from its head back to the top's front parapet
		n.add_child(rod(Vector3(gx, deck + g_len - 1.0, z), Vector3(L * 0.4 * kt, top + 3.0, z), 0.3, 0.3, s.rope, false))
	pennant(n, s, Vector3(-L * 0.35 * kt, top + 1.0, -W * 0.35 * kt), 14.0, 6.0)
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-L * 0.5 - 9.0, 0, -10.0), "crew1_f0_reach": Vector3(-L * 0.5 - 15.0, 0, 10.0)}}


# ------------------------------------------------------------------ siege tower concepts (milestone 16)

## Round T1's directions for the siege tower (concept ids "siege.tower.<dir>.<family>"):
## hide (the placeholder in play: hides on three sides), open (a bare timber frame, its ladder and a
## climber showing, crew pushing), belfry (taller, plank-clad, the gangway let down, four pushing),
## beast (the frogs' way: a reed tower lashed on a snapping turtle).
const ROUND5 := ["hide", "open", "belfry", "beast"]


func _tower_hide(s: Dictionary, c: Dictionary) -> Dictionary:
	return _tower_c(s, c)


func _tower_open(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 24.0
	var W := 20.0
	undercarriage(n, s, L, W, 4.0)
	var base := 5.2
	var top := 46.0
	for x in [-L * 0.45, L * 0.45]:
		for z in [-W * 0.45, W * 0.45]:
			n.add_child(beam(Vector3(x, base, z), Vector3(x * 0.88, top, z * 0.88), 1.6, 1.6, s.wood))
	for y in [base, base + 13.0, base + 27.0, top]:
		var k: float = 1.0 - (y - base) / (top - base) * 0.12
		for z in [-W * 0.45 * k, W * 0.45 * k]:
			n.add_child(beam(Vector3(-L * 0.45 * k, y, z), Vector3(L * 0.45 * k, y, z), 1.1, 1.1, s.dark))
		for x in [-L * 0.45 * k, L * 0.45 * k]:
			n.add_child(beam(Vector3(x, y, -W * 0.45 * k), Vector3(x, y, W * 0.45 * k), 1.1, 1.1, s.dark))
	for side in [1, -1]:   # cross braces on the open sides
		n.add_child(rod(Vector3(-L * 0.45, base, W * 0.45 * side), Vector3(L * 0.4, base + 27.0, W * 0.4 * side), 0.5, 0.5, s.dark, false))
	# The ladder inside, from the floor to the deck.
	for z in [-2.5, 2.5]:
		n.add_child(rod(Vector3(-L * 0.25, base, z), Vector3(-L * 0.05, top, z), 0.4, 0.4, s.wood, false))
	for k in 9:
		var t := (k + 0.5) / 9.0
		n.add_child(rod(Vector3(-L * 0.25 + L * 0.2 * t, base + (top - base) * t, -2.5), Vector3(-L * 0.25 + L * 0.2 * t, base + (top - base) * t, 2.5), 0.3, 0.3, s.wood, false))
	n.add_child(_box(Vector3(L * 0.84, 1.0, W * 0.84), s.dark, Vector3(0, top, 0)))
	var hide: Material = s.get("roof", s.wood)
	n.add_child(_box(Vector3(0.6, 9.0, W * 0.8), hide, Vector3(L * 0.42, top + 4.5, 0)))   # a hide screen at the front of the deck
	pennant(n, s, Vector3(-L * 0.35, top + 1.0, -W * 0.35), 12.0, 5.0)
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-L * 0.5 - 5.0, 0, -4.5), "crew1_f0_reach": Vector3(-L * 0.5 - 5.0, 0, 4.5),
		"crew2_f0_raise_in": Vector3(-L * 0.14, base + 18.0, 0)}}


func _tower_belfry(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 30.0
	var W := 22.0
	undercarriage(n, s, L, W, 4.4)
	var base := 5.6
	var top := 56.0
	var plank: Material = s.get("wood2", s.wood)
	for x in [-L * 0.45, L * 0.45]:
		for z in [-W * 0.45, W * 0.45]:
			n.add_child(beam(Vector3(x, base, z), Vector3(x * 0.8, top, z * 0.8), 1.8, 1.8, s.dark))
	var mid := (base + top) * 0.5
	for side in [1, -1]:   # plank sides, tapering: two courses
		n.add_child(_box(Vector3(L * 0.86, (top - base) * 0.5, 0.7), plank, Vector3(0, base + (top - base) * 0.25, W * 0.44 * side)))
		n.add_child(_box(Vector3(L * 0.72, (top - base) * 0.5, 0.7), plank, Vector3(0, mid + (top - base) * 0.25, W * 0.37 * side)))
	n.add_child(_box(Vector3(0.7, (top - base) * 0.5, W * 0.86), plank, Vector3(L * 0.43, base + (top - base) * 0.25, 0)))
	n.add_child(_box(Vector3(0.7, (top - base) * 0.5, W * 0.74), plank, Vector3(L * 0.36, mid + (top - base) * 0.25, 0)))
	n.add_child(_box(Vector3(L * 0.74, 1.0, W * 0.78), s.dark, Vector3(0, top, 0)))
	for k in 5:   # merlons along the deck's front and sides
		n.add_child(_box(Vector3(2.4, 3.0, 2.4), s.wood, Vector3(L * 0.34, top + 1.5, -W * 0.34 + k * W * 0.17)))
	# The gangway let down, out over the front.
	n.add_child(_box(Vector3(14.0, 0.8, W * 0.5), s.wood, Vector3(L * 0.36 + 7.0, top - 2.0, 0), Vector3(0, 0, -12)))
	for z in [-W * 0.24, W * 0.24]:
		n.add_child(rod(Vector3(L * 0.36 + 13.0, top - 3.4, z), Vector3(L * 0.2, top + 8.0, z), 0.3, 0.3, s.rope, false))
	n.add_child(_box(Vector3(0.6, 12.0, 8.0), s.team, Vector3(L * 0.37, mid, 0)))   # a team banner hung on its face
	pennant(n, s, Vector3(-L * 0.3, top + 1.0, -W * 0.3), 14.0, 6.0)
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-L * 0.5 - 5.0, 0, -7.0), "crew1_f0_reach": Vector3(-L * 0.5 - 5.0, 0, 0.0),
		"crew2_f0_reach": Vector3(-L * 0.5 - 5.0, 0, 7.0), "crew3_f0_reach": Vector3(-L * 0.3, 0, W * 0.5 + 5.0)}}


func _tower_beast(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var deck := snapping_turtle(n, s)
	var reed: Material = s.get("reed", s.wood)
	var lash: Material = s.get("lash", s.rope)
	var h := 30.0
	for x in [-14.0, 6.0]:
		for z in [-8.0, 8.0]:
			n.add_child(rod(Vector3(x, deck - 2.0, z), Vector3(x * 0.85, deck + h, z * 0.85), 1.4, 1.2, reed))
	for y in [deck + 8.0, deck + 18.0]:
		for z in [-7.5, 7.5]:
			n.add_child(rod(Vector3(-13.0, y, z), Vector3(6.0, y, z), 0.5, 0.5, lash, false))
	n.add_child(_box(Vector3(22.0, 1.0, 17.0), s.wicker if s.has("wicker") else s.wood, Vector3(-4.0, deck + h, 0)))
	n.add_child(_box(Vector3(1.0, 7.0, 15.0), s.wicker if s.has("wicker") else s.wood, Vector3(6.0, deck + h + 3.5, 0)))
	pennant(n, s, Vector3(-13.0, deck + h + 1.0, -6.0), 12.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-4.0, deck + h + 0.5, 0.0), "crew1_f0_reach": Vector3(-46.0, 0, 22.0)}}


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
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(1.5, deck + 0.7 - BEETLE_DROP, 2.5), "crew1_f0_top": Vector3(-13.0, deck + 0.7 - BEETLE_DROP, -3.0)}}   # (14 apart: at 12 the two beetles stood in each other, C1)


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
	var deck := snapping_turtle(n, s)
	# The basket on its back, lashed down, team cloth over the shell's sides.
	n.add_child(cone(10.5, 9.0, 6.0, s.wicker, Vector3(-6, deck + 1.0, 0), Vector3.ZERO, 20))
	n.add_child(ring(10.0, 11.2, s.reed, Vector3(-6, deck + 4.0, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 0.6, 13.0), s.team, Vector3(-6, deck - 6.0, 15.5 * side), Vector3(48 * side, 0, 0)))
	pennant(n, s, Vector3(-15, deck + 2.0, -5), 14.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-4.0, deck + 0.5, 0.0), "crew1_f0_reach": Vector3(-46.0, 0, 22.0)}}


## The snapping turtle itself (round 3's ram, round 4's bolt thrower and catapults): a high ridged
## shell, a long neck, a hooked beak under a stone brow plate, thick clawed legs, a spiked tail.
## Returns the height of the top of its shell (where a load goes).
func snapping_turtle(n: Node3D, s: Dictionary) -> float:
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
	return C.y + R.y - 1.0


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
	deck_catapult(n, s, d, -4.0)
	return {"node": n, "sockets": {"crew0_f0_raise_top": Vector3(-20.0, d + 0.9, 0), "crew1_f0_reach": Vector3(-6.0, 0, 30.0)}}


## A reed-armed catapult standing on a deck at height `d`, the deck's middle at x0: two reed-bundle
## uprights and braces, a crossbar with the team's pad, a reed skein, the arm (`h` from deck to cup)
## standing against the bar with a clay ball in its wicker cup.
func deck_catapult(n: Node3D, s: Dictionary, d: float, x0: float, h := 42.0) -> void:
	var bar := d + h * 24.0 / 42.0
	for side in [1, -1]:
		bundle(n, Vector3(x0 + 10.0, d, 8.5 * side), Vector3(x0 + 10.0, bar, 8.5 * side), 1.9, s, 2)
		bundle(n, Vector3(x0 + 17.0, d, 8.5 * side), Vector3(x0 + 10.0, bar - 7.0, 8.5 * side), 1.1, s, 1)
	bundle(n, Vector3(x0 + 10.0, bar, -10.5), Vector3(x0 + 10.0, bar, 10.5), 1.8, s, 3)
	n.add_child(rod(Vector3(x0 + 7.8, bar, -6.0), Vector3(x0 + 7.8, bar, 6.0), 2.2, 2.2, s.team))
	var pivot := Vector3(x0 - 8.0, d + 3.0, 0)
	n.add_child(rod(pivot + Vector3(0, 0, -8.0), pivot + Vector3(0, 0, 8.0), 2.6, 2.6, s.reed))
	var tip := Vector3(x0 + 7.0, d + h, 0)
	bundle(n, pivot, tip, 2.0, s, 3, 1.4)
	clay_cup(n, s, tip + Vector3(0, 0.8, 0), 4.0)


## A giant toad (brown, warty, gold-eyed) with a bolt thrower on a saddle on its back: a frog
## aims from its rump, another loads from beside it.
func _bolt_beast(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	giant_toad(n, s)
	# The saddle (team cloth) and the bolt thrower on a short post.
	var top := 33.0
	n.add_child(_box(Vector3(20.0, 0.8, 24.0), s.team, Vector3(-4.0, top - 1.0, 0), Vector3(0, 0, 10)))
	post_bolt(n, s, top, -2.0)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-20.0, 25.2, 0), "crew1_f0_reach": Vector3(-6.0, 0, -30.0)}}   # (at 27 the rider stood 1.8 over the toad's back)


## A reed-bow bolt thrower on a short post standing on a pad at height `top`, the post at x0.
func post_bolt(n: Node3D, s: Dictionary, top: float, x0: float) -> void:
	n.add_child(_box(Vector3(10.0, 2.0, 10.0), s.dark, Vector3(x0, top, 0)))
	n.add_child(rod(Vector3(x0, top, 0), Vector3(x0, top + 6.0, 0), 1.6, 1.4, s.dark))
	var y := top + 7.0
	n.add_child(beam(Vector3(x0 - 18, y, 0), Vector3(x0 + 20, y, 0), 2.8, 2.2, s.dark))
	var bx := x0 + 18.0
	for side in [1, -1]:
		var mid := Vector3(bx - 2.0, y + 0.5, 13.0 * side)
		var end := Vector3(bx - 9.0, y + 0.5, 24.0 * side)
		bundle(n, Vector3(bx, y + 0.5, 1.8 * side), mid, 2.0, s, 1, 1.6)
		bundle(n, mid, end, 1.6, s, 1, 1.0)
		n.add_child(rod(end, Vector3(x0 - 12.0, y + 1.2, 0), 0.4, 0.4, s.lash, false))
	n.add_child(_box(Vector3(4.6, 4.0, 4.6), s.lash, Vector3(bx, y + 0.5, 0)))
	n.add_child(rod(Vector3(x0 - 12.0, y + 2.2, 0), Vector3(x0 + 34.0, y + 2.2, 0), 1.0, 0.9, s.stalk))
	n.add_child(cone(0.1, 1.2, 6.0, plain(Color("#3a2a1c")), Vector3(x0 + 37.0, y + 2.2, 0), Vector3(0, 0, -90), 8))


## The giant toad itself (round 3's bolt thrower carrier, round 4's catapult carrier): brown,
## warty, gold-eyed, wide-mouthed, crouched; its back about 33 high.
func giant_toad(n: Node3D, s: Dictionary) -> void:
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



# ================================================================== round 4 (2026-10-13): frog catapults
# Dominic picked round 3's swamp beasts (D-121) but wasn't sure of the newt as the catapult carrier
# ("I wonder if better for cavalry?"; the newt mount is built in unit_models.gd), then: "catapult on
# snail maybe?". Ids "siege.<engine>.<dir>.frog", built at their true size like round 3:
#   snail   catapult: a giant swamp snail, the catapult on a deck lashed over its coiled shell
#   toad    catapult: round 3's giant toad carrying the catapult instead of the bolt thrower...
#   turtle  ...and the snapping turtle carrying the bolt thrower (the swap); or the catapult on a
#           bigger snapping turtle
#   haul    catapult: round 3's reed and clay catapult on its sledge, hauled by the snapping turtle
const ROUND4 := ["snail", "toad", "turtle", "haul"]


## A giant swamp snail: a long, wet, slime-glossy foot, a head on a raised neck with two long eye
## stalks and two short feelers, a big shell coiled flat like a ram's horn (so its spiral shows
## from the side), amber with dark growth bands and a dark spiral line, a slime trail behind.
## Returns the height of the shell's top.
func swamp_snail(n: Node3D, s: Dictionary) -> float:
	var body := surf("frog_skin", Color("#8a7a5a"), 8.0)
	body.roughness = 0.12
	body.metallic_specular = 1.0
	var sole := surf("frog_belly", Color("#c8b892"), 5.0)
	sole.roughness = 0.2
	n.add_child(blob(Vector3(38.0, 5.5, 12.5), body, Vector3(-2.0, 5.0, 0)))   # the foot
	n.add_child(blob(Vector3(37.0, 1.6, 13.9), sole, Vector3(-2.0, 1.8, 0)))   # its frilled edge
	n.add_child(rod(Vector3(-30, 8.0, 0), Vector3(-52, 1.8, 0), 8.0, 1.6, body))   # the foot's tail behind the shell (its underside on the ground: placement A1)
	n.add_child(rod(Vector3(20, 6.0, 0), Vector3(37, 13.0, 0), 8.0, 6.4, body))   # the neck, raised
	n.add_child(blob(Vector3(8.0, 6.4, 7.4), body, Vector3(41.0, 14.0, 0)))
	n.add_child(rod(Vector3(46.5, 11.0, -3.5), Vector3(48.0, 11.2, 0), 0.4, 0.4, plain(INK)))   # the mouth
	n.add_child(rod(Vector3(48.0, 11.2, 0), Vector3(46.5, 11.0, 3.5), 0.4, 0.4, plain(INK)))
	var eye := plain(Color("#141210"))
	eye.roughness = 0.1
	eye.metallic_specular = 1.0
	for side in [1, -1]:
		n.add_child(rod(Vector3(43, 18, 3.0 * side), Vector3(52, 36, 7.5 * side), 2.4, 1.6, body))   # eye stalks
		n.add_child(blob(Vector3.ONE * 2.9, eye, Vector3(52.4, 37.0, 7.7 * side)))
		n.add_child(blob(Vector3.ONE * 0.8, plain(Color("#e8e4d8")), Vector3(53.6, 38.4, 8.6 * side)))   # the wet glint
		n.add_child(rod(Vector3(47, 12, 4.0 * side), Vector3(57, 7.0, 8.5 * side), 1.9, 0.8, body))   # feelers
	# The shell: a tube coiled in the side plane, starting at the aperture low at the front, over
	# the top, round the back and in; amber with dark growth bands, a dark line along the coil.
	# Each turn of the coil a shade darker towards the middle, so the turns part at a glance.
	var whorls := [Color("#c88a3c"), Color("#9a6428"), Color("#6e4420"), Color("#4e3018")]
	var band := surf("chitin", Color("#3a2410"), 6.0)
	var lip := plain(Color("#ecdcb4"))
	var R0 := 19.0
	var O := Vector3(-8.0, 29.0, 0)
	var top := 0.0
	for k in 70:
		var th := k * 0.16
		var R := R0 * exp(-0.12 * th)
		var r := R * 0.5
		var phi := deg_to_rad(-50.0) + th
		var at := O + Vector3(cos(phi) * R, sin(phi) * R, 0)
		var shell := surf("chitin", whorls[mini(int(th / TAU), 3)], 6.0)
		shell.roughness = 0.45
		n.add_child(blob(Vector3(r * 1.1, r * 1.1, r * 1.35), band if k % 8 == 4 else shell, at))
		top = maxf(top, at.y + r * 1.1)
		if k > 4:   # the dark seam where each turn meets the one inside it, on both flat sides
			var inward := Vector3(-cos(phi), -sin(phi), 0) * r * 0.8
			for side in [1, -1]:
				n.add_child(blob(Vector3.ONE * clampf(r * 0.28, 0.7, 2.0), band, at + inward + Vector3(0, 0, r * 1.05 * side)))
	var a0 := deg_to_rad(-50.0)
	n.add_child(ring(R0 * 0.42, R0 * 0.56, lip, O + Vector3(cos(a0) * R0 + 2.0, sin(a0) * R0, 0),
		Vector3(90, 0, 40), Vector3(1, 1, 1.3)))   # the aperture's pale lip
	return top


## The snail's catapult: a timber deck lashed over the shell's top, ropes down to the foot, the
## reed catapult standing on it; a frog rides behind the arm winding, a driver sits on the snail's
## neck with a goad, a loader walks beside with clay shot in a basket.
func _catapult_snail(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var top := swamp_snail(n, s)
	var x0 := -8.0
	var d := top + 1.0
	n.add_child(_box(Vector3(30.0, 2.0, 19.0), s.dark, Vector3(x0 - 3.0, d - 1.0, 0)))
	for x in [x0 - 15.0, x0 + 9.0]:   # crossbars, roped down to the foot on both sides
		n.add_child(beam(Vector3(x, d - 2.4, -10.5), Vector3(x, d - 2.4, 10.5), 2.4, 2.4, s.wood))
		for side in [1, -1]:
			n.add_child(rod(Vector3(x, d - 2.4, 10.0 * side), Vector3(x * 1.3, 7.0, (13.0 if x > 0.0 else 7.0) * side), 0.45, 0.45, s.rope, false))   # (behind, the foot narrows to its tail: at 13 the ropes ended in the air, C3)
	n.add_child(_box(Vector3(30.4, 2.4, 1.2), s.team, Vector3(x0 - 3.0, d - 1.0, 9.9)))   # team cloth along the deck's edges
	n.add_child(_box(Vector3(30.4, 2.4, 1.2), s.team, Vector3(x0 - 3.0, d - 1.0, -9.9)))
	deck_catapult(n, s, d, x0, 32.0)
	clay_cup(n, s, Vector3(x0 + 4.0, 4.0, -22.0), 4.0)   # shot by the loader
	return {"node": n, "sockets": {"crew0_f0_raise_top": Vector3(x0 - 17.0, d, 0), "crew1_f0_reach": Vector3(x0 - 8.0, 0, -30.0)}}


## The toad's catapult (the swap): round 3's giant toad, a team saddle cloth and a deck on its back,
## the reed catapult on the deck; a frog rides its rump winding, one loads from beside.
func _catapult_toad(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	giant_toad(n, s)
	var top := 33.0
	n.add_child(_box(Vector3(20.0, 0.8, 24.0), s.team, Vector3(-4.0, top - 1.0, 0), Vector3(0, 0, 10)))
	n.add_child(_box(Vector3(26.0, 1.8, 18.0), s.dark, Vector3(-2.0, top + 0.8, 0)))
	deck_catapult(n, s, top + 1.6, -2.0, 38.0)
	return {"node": n, "sockets": {"crew0_f0_raise_top": Vector3(-20.0, 27.0, 0), "crew1_f0_reach": Vector3(-6.0, 0, -30.0)}}


## The turtle's bolt thrower (the swap): the snapping turtle with team cloths over its shell and
## round 3's reed-bow bolt thrower on a post; a frog aims from the back of the shell, one loads.
func _bolt_turtle(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var deck := snapping_turtle(n, s)
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 0.6, 13.0), s.team, Vector3(-6, deck - 6.0, 15.5 * side), Vector3(48 * side, 0, 0)))
	post_bolt(n, s, deck, -4.0)
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(-24.0, 29.0, 0), "crew1_f0_reach": Vector3(-6.0, 0, 34.0)}}


## The catapult on a bigger snapping turtle (a quarter larger than the ram's): a deck on its shell,
## the reed catapult on it; a frog rides behind the arm, one loads from beside.
func _catapult_turtle(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var big := Node3D.new()
	big.scale = Vector3.ONE * 1.25
	n.add_child(big)
	var deck := snapping_turtle(big, s) * 1.25
	n.add_child(_box(Vector3(30.0, 2.0, 22.0), s.dark, Vector3(-6.0, deck, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(18.0, 0.6, 16.0), s.team, Vector3(-6, deck - 7.0, 19.0 * side), Vector3(48 * side, 0, 0)))
	deck_catapult(n, s, deck + 1.0, -4.0, 38.0)
	return {"node": n, "sockets": {"crew0_f0_raise_top": Vector3(-26.0, 39.0, 0), "crew1_f0_reach": Vector3(-6.0, 0, 38.0)}}


## Round 3's reed and clay catapult on its sledge, hauled by the snapping turtle on two traces; a
## driver rides the turtle, the catapult's own crew wind and load behind.
func _catapult_haul(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cat := _catapult_reed(s, c)
	var back := -49.0
	cat.node.position.x = back
	n.add_child(cat.node)
	var beast := Node3D.new()
	beast.position.x = 47.0
	n.add_child(beast)
	var deck := snapping_turtle(beast, s)
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 0.6, 13.0), s.team, Vector3(41, deck - 6.0, 15.5 * side), Vector3(48 * side, 0, 0)))
		n.add_child(rod(Vector3(back + 30.0, 5.0, 13.0 * side), Vector3(61.0, 14.0, 24.0 * side), 0.6, 0.6, s.rope, false))   # the traces
	n.add_child(beam(Vector3(61.0, 14.0, -24.0), Vector3(61.0, 14.0, 24.0), 1.6, 1.6, s.dark))   # the breast bar
	var sockets := {"crew2_f0_reach_top": Vector3(43.0, deck + 0.5, 0)}
	for k in cat.sockets:
		sockets[k] = cat.sockets[k] + Vector3(back, 0, 0)
	return {"node": n, "sockets": sockets}


# ================================================================== the trade cart (milestone 13 step 6)
# A PLACEHOLDER look, the same for every take, until Dominic picks from concept round TC1
# (docs/concepts/trade_carts/, models in scenes/art_pixel/cart_concepts.gd): a plain two-wheeled
# timber handcart with a load of crates, sacks and a jar under a team cloth, the race's worker
# pushing it from behind (crew socket). Frogs' carts are grown for the bigger frog worker.

func _cart_placeholder(s: Dictionary, c: Dictionary) -> Dictionary:
	var spec := handcart(s, c)
	return _scaled(spec, 1.25) if s.fam == "frog" else spec


## A two-wheeled handcart, its handles back to the pusher (socket crew0, reaching), loaded with trade
## goods (or empty: a load of its own goes on, pushed_home).
func handcart(s: Dictionary, c: Dictionary, loaded := true) -> Dictionary:
	var n := Node3D.new()
	var wr := 6.5
	var y := wr + 1.6   # the bed's floor
	for side in [1, -1]:
		wheel(n, Vector3(2.0, wr, 8.6 * side), wr, 1.6, s)
	n.add_child(rod(Vector3(2.0, wr, -9.6), Vector3(2.0, wr, 9.6), 0.6, 0.6, s.dark, false))
	var plank := surf("wood_grain", Color.WHITE, 8.0)
	n.add_child(_box(Vector3(22.0, 1.2, 13.0), plank, Vector3(2.0, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(22.0, 3.6, 0.8), plank, Vector3(2.0, y + 2.3, 6.3 * side)))
	for x in [-8.6, 12.6]:
		n.add_child(_box(Vector3(0.8, 3.6, 13.0), plank, Vector3(x, y + 2.3, 0)))
	for side in [1, -1]:   # the handles, back and up to the pusher's hands; a prop leg under each
		n.add_child(beam(Vector3(-8.0, y + 0.5, 4.6 * side), Vector3(-18.5, y + 3.6, 4.6 * side), 1.0, 1.0, s.dark))
		n.add_child(rod(Vector3(-7.0, y, 4.6 * side), Vector3(-7.6, 0.4, 4.6 * side), 0.45, 0.45, s.dark))
	if loaded:
		cart_load(n, s, Vector3(2.0, y, 0))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-24.5, 0, 0)}}


## Trade goods on a cart's bed (its floor's middle at `at`): two crates, sacks, a tall jar; a team
## cloth over the big crate.
func cart_load(n: Node3D, s: Dictionary, at: Vector3) -> void:
	var plank := surf("wood_grain", Color.WHITE, 8.0)
	n.add_child(_box(Vector3(7.5, 6.0, 7.5), s.dark, at + Vector3(4.5, 3.6, 1.8)))
	n.add_child(_box(Vector3(8.2, 0.5, 8.2), s.team, at + Vector3(4.5, 6.9, 1.8)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(5.0, 3.2, 0.4), s.team, at + Vector3(4.5, 5.2, 1.8 + 4.0 * side)))
	n.add_child(_box(Vector3(5.0, 4.0, 5.0), plank, at + Vector3(-5.0, 2.6, -3.0), Vector3(0, 20, 0)))
	var sack := surf("cloth", Color("#c8b48a"), 3.0)
	n.add_child(blob(Vector3(3.2, 2.4, 2.6), sack, at + Vector3(-5.5, 2.6, 3.4)))
	n.add_child(blob(Vector3(2.8, 2.2, 2.4), sack, at + Vector3(-2.5, 5.6, -2.6)))
	var jar := surf("bld_daub", Color(1.05, 0.62, 0.42), 6.0)
	n.add_child(cone(1.2, 2.6, 5.5, jar, at + Vector3(7.5, 3.0, -4.0)))
	n.add_child(cone(0.8, 1.2, 1.2, jar, at + Vector3(7.5, 6.2, -4.0)))


# ------------------------------------------------------------------ the trade cart (D-127)

## The trade cart in play (D-127, Dominic: "the race's own beast pulls a cart; for frogs a snail pulls
## it"; picked from concept round TC1, docs/concepts/trade_carts/): a two-wheeled cart pulled by the
## take's beast in its draught harness (the recipe's `haul`, from parts.json siege.cart.<take>), the
## frogs' by a snail built into the cart (no legs to walk: one baked part), a worker leading it.
## CART_BEAST must name the creature parts.json gives the cart's haul (the placement check, C2, holds
## the shafts to its harness).
const CART_BEAST := {"timber": "pony", "junk": "cat", "forest": "beetle", "spooky": "spider"}


func trade_cart(take: String, c: Dictionary) -> Dictionary:
	var s := _style(TAKE_STYLE[take], c)
	return _cart_snail(s, c) if take == "frog" else hauled_cart(CART_BEAST[take], s, c)


## A two-wheeled cart, its bed loaded, its two shafts forward to the beast's harness (the beast on
## "haul0" wears `harness.draught`, the recipe's haul.parts): each shaft ends where a trace ends
## (sockets hitch0_near / hitch0_far = the haul socket + the harness's trace_near / trace_far), and
## the placement check holds them together in every walk step (C2). A worker leads the beast at its
## head on the near side ("crew0_f0"), clear of its flank and the shafts.
## (Round TC1 as first drawn is kept for the placement fixture that must fail it: cart_concepts.gd a_v1.)
const SHAFT := 8.0        # the shafts' length from the cart's front to the hitch (x)
const CART_FRONT := 12.4  # the cart's front board (x), where the shafts start
const LEAD_GAP := 6.0     # the handler's middle this far out from the harness on the near side...
const LEAD_AHEAD := 16.0  # ...and this far ahead of its chest, at its head (beside the chest it stood in front of the beast in the three-quarter view)
const LEAD_LEGS := {"spider": 9.0, "newt": 3.0}   # ...and further out past legs that sprawl wide
const HITCH_DROP := {"newt": -1.2}   # the hitch this far under the standing trace end (over it: the newt rises as it strides; C2 walking)


## beast: the hauling creature (BEAST_BODY); k: the cart drawn this much bigger (the beast isn't).
func hauled_cart(beast: String, s: Dictionary, c: Dictionary, k := 1.0) -> Dictionary:
	var lay := harness_layout(BEAST_BODY[beast], c)
	var te: Vector3 = lay.ends[0] / k   # the near trace end, from the beast's socket, in the cart's frame
	var n := Node3D.new()
	var y := cart_body(n, s)
	var haul := Vector3(CART_FRONT + SHAFT - te.x, 0, 0)
	var sockets := {"haul0_f0": haul}
	for side in [1, -1]:   # the shafts, from the front corners forward to the trace ends
		var hitch := haul + Vector3(te.x, te.y - float(HITCH_DROP.get(beast, 0.0)) / k, te.z * side)
		n.add_child(beam(Vector3(CART_FRONT - 1.0, y + 1.0, 6.3 * side), hitch, 1.0, 1.0, s.dark))
		sockets["hitch0_%s" % ("near" if side > 0 else "far")] = hitch
	sockets["crew0_f0"] = haul + Vector3((lay.front_x + LEAD_AHEAD) / k, 0, (lay.half_width + LEAD_GAP + float(LEAD_LEGS.get(beast, 0.0))) / k)
	return _scaled({"node": n, "sockets": sockets}, k)


## The cart itself: two wheels, a loaded bed, a prop at the back; returns the bed's floor height.
func cart_body(n: Node3D, s: Dictionary) -> float:
	var wr := 6.5
	var y := wr + 1.6
	for side in [1, -1]:
		wheel(n, Vector3(0.0, wr, 8.6 * side), wr, 1.6, s)
	n.add_child(rod(Vector3(0.0, wr, -9.6), Vector3(0.0, wr, 9.6), 0.6, 0.6, s.dark, false))
	var plank: Material = surf("wood_grain", Color.WHITE, 8.0) if s.fam != "spooky" else s.wood
	n.add_child(_box(Vector3(24.0, 1.2, 13.0), plank, Vector3(0.0, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(24.0, 3.6, 0.8), plank, Vector3(0.0, y + 2.3, 6.3 * side)))
	for x in [-11.6, 11.6]:
		n.add_child(_box(Vector3(0.8, 3.6, 13.0), plank, Vector3(x, y + 2.3, 0)))
	cart_load(n, s, Vector3(0.0, y, 0))
	n.add_child(rod(Vector3(-11.0, y, 0), Vector3(-13.0, 0.3, 0), 0.5, 0.5, s.dark))   # a prop at the back
	return y


## The frogs' cart (D-127: "for frogs a snail pulls it"): a small giant snail (the catapult's kin)
## in front, a padded band over its foot behind the shell, the cart's shafts lashed to the band each
## side; a frog walks at the snail's head. The snail is part of the cart's bake (it has no legs to
## walk), the whole drawn bigger like the frogs' handcart.
const SNAIL_K := 0.55      # the snail's size against the catapult's
const SNAIL_BAND_X := -24.0   # the band round its foot, behind the shell (the snail's own frame)


func _cart_snail(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var y := cart_body(n, s)
	var beast := Node3D.new()
	beast.scale = Vector3.ONE * SNAIL_K
	var at := CART_FRONT + SHAFT + (-SNAIL_BAND_X + 3.0) * SNAIL_K   # the band SHAFT ahead of the cart's front
	beast.position = Vector3(at, 0, 0)
	n.add_child(beast)
	swamp_snail(beast, s)
	# The band over the foot: the foot's cross-section there (its blob: 38 x 5.5 x 12.5 round (-2, 5, 0)),
	# a little out from it, from one side over the top to the other.
	var f := sqrt(1.0 - pow((SNAIL_BAND_X + 2.0) / 38.0, 2.0))
	var pad := surf("leather", Color(0.42, 0.27, 0.16), 3.0)
	var pts := []
	for i in 9:
		var a := PI * i / 8.0
		pts.append(Vector3(SNAIL_BAND_X, 5.0 + (5.5 * f + 0.6) * sin(a), (12.5 * f + 0.6) * cos(a)) * SNAIL_K + beast.position)
	for i in 8:
		n.add_child(rod(pts[i], pts[i + 1], 0.55, 0.55, pad))
	var sockets := {}
	for side in [1, -1]:   # the shafts, to the band's ends low on each side of the foot
		var end: Vector3 = pts[0 if side > 0 else 8]
		n.add_child(beam(Vector3(CART_FRONT - 1.0, y + 1.0, 6.3 * side), end, 1.0, 1.0, s.dark))
		n.add_child(blob(Vector3.ONE * 0.9, surf("bronze", Color.WHITE, 3.0), end))
	sockets["crew0_f0"] = Vector3(at + 50.0 * SNAIL_K, 0, 12.5 * SNAIL_K + LEAD_GAP + 7.0)   # at its head, out past the feelers
	return _scaled({"node": n, "sockets": sockets}, 1.25)


# ------------------------------------------------------------------ the draught harness

## The body each hauler wears its harness on (UnitView.haul_recipe: the creature's mount body if any).
const BEAST_BODY := {"pony": "body.pony", "newt": "body.newt", "cat": "body.cat", "beetle": "body.beetle", "spider": "body.spider"}
const HARNESS_GAP := 0.5    # the straps this far off the hide
const TRACE_TAIL := 2.5     # the traces run this far behind the rump, where the shafts take them
var _layouts := {}   # body id -> its harness layout (the shape doesn't change with the colours)


## A draught harness (TC1 A, after Dominic's "this is bugged": the traces were loose lines and the
## cart floated behind): worn by the beast hauling (the haul's parts {"torso": "harness.draught"}),
## fitted on its body like worn armour (baked on it with the body cut out, so the far side hides):
## a band round the barrel at chest height (breast band in front, breeching behind), a band over
## the back behind the forelegs and one over the loins holding it up, and a trace along each flank
## from the band back past the rump. The trace ends are its sockets (trace_near, trace_far: the
## cart's hitches).
## (UnitModels.fitted hands it here; it has no model of its own off its wearer.)
func harness_fitted(part_id: String, body_id: String, c: Dictionary) -> Dictionary:
	assert(part_id == "harness.draught", "no harness %s" % part_id)
	var lay := harness_layout(body_id, c)
	var n := Node3D.new()
	var leather := surf("leather", Color(0.42, 0.27, 0.16), 3.0)   # dark, to read on a ginger cat or a bay pony
	for loop in [lay.band] + lay.backs + lay.traces:
		for i in loop.size() - 1:
			n.add_child(rod(loop[i], loop[i + 1], 0.55, 0.55, leather))
	var brass := surf("bronze", Color.WHITE, 3.0)
	for t in lay.traces:
		n.add_child(blob(Vector3.ONE * 0.85, brass, t[0]))   # a ring where each trace leaves the band
		n.add_child(blob(Vector3.ONE * 0.85, brass, t[-1]))   # and one at its end, on the shaft
	return {"node": n, "sockets": {"trace_near": lay.ends[0], "trace_far": lay.ends[1]}}


## Where a body's harness goes, measured on its model (body only: the legs hang below the band):
## {band: closed loop at chest height, backs: [loops over the back], trace_from, ends: [near, far],
## half_width, front_x}.
func harness_layout(body_id: String, c: Dictionary) -> Dictionary:
	if _layouts.has(body_id):
		return _layouts[body_id]
	var b: Dictionary = super.build(body_id, c)   # (the body's model: unit_models.gd, not an engine)
	var pts := _cloud(b.node)
	var anchors: Array = b.get("anchors", [])
	b.node.free()
	if b.get("front") != null:
		b.front.free()
	var fore := []
	var hind := []
	var hip_y := -INF
	for a in anchors:
		(hind if a.size() > 4 and bool(a[4]) else fore).append(float(a[0].x))
		hip_y = maxf(hip_y, float(a[0].y))
	var xf: float = fore.reduce(func(m, x): return maxf(m, x), -INF) if not fore.is_empty() else 0.0
	var xh: float = hind.reduce(func(m, x): return minf(m, x), INF) if not hind.is_empty() else xf - 10.0
	var xm := (xf + xh) * 0.5
	# Chest height: a little over halfway up the barrel at its middle, and over the hips.
	var lo := INF
	var hi := -INF
	for p in pts:
		if absf(p.x - xm) < 1.5:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	var y := lo + 0.55 * (hi - lo)
	if hip_y + 1.0 < hi - 1.0:
		y = maxf(y, hip_y + 1.0)
	# The breast band: round the front half of the barrel, flank to flank.
	var band := _contour(pts, Vector3(xm, y, 0), Vector3.UP, 0.0, PI, 12)
	var half := 0.0
	var front := -INF
	for p in band:
		half = maxf(half, absf(p.z))
		front = maxf(front, p.x)
	# The rump: the back of the barrel at band height (a tail, narrow, doesn't count: a newt's runs on).
	var rear := xh
	for p in pts:
		if absf(p.y - y) < 1.5 and absf(p.z) >= 0.4 * half:
			rear = minf(rear, p.x)
	var backs := []
	for x in [xf - 2.5, xh + 2.5]:
		backs.append(_contour(pts, Vector3(x, y, 0), Vector3.RIGHT, 0.0, PI, 9))
	# The traces: from the band's ends back along each flank, hugging it, and on past the rump.
	var traces := [[band[0]], [band[-1]]]
	var x := xm - 2.0
	while x > rear + 1.0:
		var w := 0.0
		for p in pts:
			if absf(p.y - y) < 1.0 and absf(p.x - x) < 0.8:
				w = maxf(w, absf(p.z))
		if w > 0.0:
			traces[0].append(Vector3(x, y, w + HARNESS_GAP))
			traces[1].append(Vector3(x, y, -w - HARNESS_GAP))
		x -= 2.0
	var ends := [Vector3(rear - TRACE_TAIL, y, traces[0][-1].z), Vector3(rear - TRACE_TAIL, y, traces[1][-1].z)]
	traces[0].append(ends[0])
	traces[1].append(ends[1])
	_layouts[body_id] = {"band": band, "backs": backs, "traces": traces, "ends": ends, "half_width": half, "front_x": front}
	return _layouts[body_id]


## A loop hugging the model's points round `centre`: in the plane across `axis` (UP: a horizontal
## band, its points within a unit of that height; RIGHT: over the back, within a unit of that x),
## from angle a0 to a1 in n steps, each the farthest point in its direction plus HARNESS_GAP.
func _contour(pts: PackedVector3Array, centre: Vector3, axis: Vector3, a0: float, a1: float, n: int) -> Array:
	var bins := []
	bins.resize(n + 1)
	bins.fill(0.0)
	var step := (a1 - a0) / float(n)
	for p in pts:
		var d := p - centre
		var u: float
		var v: float
		if axis == Vector3.UP:
			if absf(d.y) > 1.0:
				continue
			u = d.z   # angle 0 on the near side (+z), round by the front (+x)
			v = d.x
		else:
			if absf(d.x) > 1.0 or d.y < -1.0:
				continue
			u = d.z   # angle 0 on the near side, over the top
			v = d.y
		var ang := fposmod(atan2(v, u) - a0, TAU)
		var i := roundi(ang / step)
		if i >= 0 and i <= n:
			bins[i] = maxf(bins[i], Vector2(u, v).length())
	for i in n + 1:   # empty directions take their neighbours' reach
		if bins[i] == 0.0:
			bins[i] = maxf(bins[maxi(i - 1, 0)], bins[mini(i + 1, n)])
	var out := []
	for i in n + 1:
		var ang := a0 + step * i
		var r: float = bins[i] + HARNESS_GAP
		var u := cos(ang) * r
		var v := sin(ang) * r
		out.append(centre + (Vector3(v, 0, u) if axis == Vector3.UP else Vector3(0, v, u)))
	return out


## Every mesh vertex under n, in n's parent's space.
static func _cloud(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	_cloud_into(n, n.transform, out)
	return out


static func _cloud_into(n: Node, t: Transform3D, out: PackedVector3Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr: Array = (m as PrimitiveMesh).get_mesh_arrays() if m is PrimitiveMesh else m.surface_get_arrays(s)
			for v in arr[Mesh.ARRAY_VERTEX]:
				out.append(t * v)
	for c in n.get_children():
		if c is Node3D:
			_cloud_into(c, t * (c as Node3D).transform, out)


# ------------------------------------------------------------------ pushed home (D-127)

## What a worker pushes home with its load (D-127, Dominic: "the rats' scrap barrow and handcart
## become what rat workers push when they carry stone and gold home"; creatures.json push_home,
## UnitView.push_recipe: the worker is the engine's crew): "barrow" the scrap barrow (one wheel, a
## pipe frame) heaped with rubble, "handcart" the two-wheeled handcart with sacks of gold ore.
func pushed_home(kind: String, s: Dictionary, c: Dictionary) -> Dictionary:
	if kind == "barrow":
		return scrap_barrow(s, "stone")
	var spec := handcart(s, c, false)
	gold_load(spec.node, s, Vector3(2.0, 8.1, 0))
	return spec


## The rats' scrap barrow at human scale (D-116): one big wheel in front, a pipe frame, mismatched
## planks, two pipe handles back to the rat pushing it; heaped with `load` ("goods": a crate, a barrel
## and a wheel of cheese, TC1 C; "stone": rubble).
func scrap_barrow(s: Dictionary, load: String) -> Dictionary:
	var n := Node3D.new()
	var wr := 6.0
	wheel(n, Vector3(13.0, wr, 0), wr, 2.0, s)
	var y := 9.0
	for side in [1, -1]:   # the pipe frame from the axle back to the handles, legs under it
		n.add_child(rod(Vector3(13.0, wr, 1.8 * side), Vector3(-6.0, y, 5.5 * side), 0.7, 0.7, s.pipe))
		n.add_child(rod(Vector3(-6.0, y, 5.5 * side), Vector3(-18.0, y + 3.0, 5.0 * side), 0.7, 0.7, s.pipe))
		n.add_child(rod(Vector3(-4.0, y, 5.5 * side), Vector3(-5.0, 0.4, 5.5 * side), 0.6, 0.6, s.pipe))
	n.add_child(_box(Vector3(20.0, 1.0, 12.0), s.wood2, Vector3(2.0, y + 0.5, 0)))   # mismatched planks
	if load == "stone":
		var rock := surf("rock", Color(0.85, 0.82, 0.76), 3.0)
		for b in [[Vector3(-2.0, y + 3.0, 2.0), Vector3(3.6, 2.4, 3.0)], [Vector3(4.0, y + 2.8, -1.5), Vector3(3.2, 2.2, 3.4)],
				[Vector3(1.0, y + 5.0, 0.0), Vector3(2.8, 2.0, 2.6)], [Vector3(8.0, y + 2.2, 2.4), Vector3(2.4, 1.8, 2.2)]]:
			n.add_child(blob(b[1], rock, b[0], Vector3(0, b[0].x * 11.0, 12)))
		n.add_child(_box(Vector3(5.0, 0.4, 5.0), s.team, Vector3(-4.0, y + 1.2, -3.6), Vector3(0, 20, 8)))   # a team rag over the side
	else:
		n.add_child(_box(Vector3(6.0, 5.0, 6.0), s.wood, Vector3(-2.0, y + 3.5, 2.5)))   # a crate
		n.add_child(cone(2.6, 2.6, 6.0, s.plate, Vector3(6.0, y + 4.0, -2.5)))   # a barrel of rusted plate
		n.add_child(ring(2.4, 2.8, s.metal, Vector3(6.0, y + 5.5, -2.5)))
		n.add_child(cone(3.2, 3.2, 2.2, s.ammo, Vector3(2.0, y + 2.0, -3.0), Vector3(0, 0, 0), 14))   # a wheel of cheese
		n.add_child(_box(Vector3(6.4, 0.4, 6.4), s.team, Vector3(-2.0, y + 6.2, 2.5)))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-24.0, 0, 0)}}


## Sacks of gold ore on a cart's bed (its floor's middle at `at`), nuggets at their mouths.
func gold_load(n: Node3D, s: Dictionary, at: Vector3) -> void:
	var sack := surf("cloth", Color("#c8b48a"), 3.0)
	var gold := plain(Color("#f2c440"))
	for b in [Vector3(-3.0, 2.6, 2.2), Vector3(3.0, 2.4, -2.0), Vector3(0.0, 4.6, 0.4)]:
		n.add_child(blob(Vector3(3.2, 2.6, 3.0), sack, at + b))
		for k in 3:
			n.add_child(blob(Vector3(0.8, 0.65, 0.75), gold, at + b + Vector3(-0.8 + k * 0.8, 2.3, 0.6 - k * 0.5)))
	n.add_child(_box(Vector3(5.0, 0.4, 4.0), s.team, at + Vector3(4.5, 1.0, 3.4)))


# ================================================================== war beasts and the great sling (D-129)
# Picked from concept rounds WB1, WB2 and GS2 (docs/concepts/war_beasts/, great_sling/; the other options stay
# in m13_concepts.gd). War beasts: "siege.beast.<kind>" (elephant, boar, tarantula, heron, mantis): one baked
# body, its riders (the race's own soldiers, the recipe's crew) on "crew<n>_f0_top" sockets; a crew too big to
# ride (a centaur's horse half) walks beside it on the "_wide" ones (build). The great sling: "siege.sling.<take>"
# set up, and "siege.sling_packed.<take>" on its wagon (shown while it isn't set up: UnitView.set_packed).

## A howdah: a railed platform at `at` (its floor's middle), team cloths down both sides; returns the
## riders' sockets (two on top, corner to corner; one in the middle for a big crew, frogs and spiders:
## two of them sat in each other, placement C1).
func howdah(n: Node3D, s: Dictionary, at: Vector3, L: float, W: float, riders := 2) -> Dictionary:
	n.add_child(_box(Vector3(L, 1.4, W), s.dark, at))
	for x in [-L * 0.5 + 0.6, L * 0.5 - 0.6]:
		for side in [1, -1]:
			n.add_child(rod(at + Vector3(x, 0, W * 0.5 * side), at + Vector3(x, 5.0, W * 0.5 * side), 0.45, 0.45, s.dark))
	for side in [1, -1]:
		n.add_child(rod(at + Vector3(-L * 0.5, 5.0, W * 0.5 * side), at + Vector3(L * 0.5, 5.0, W * 0.5 * side), 0.4, 0.4, s.dark))
		n.add_child(_box(Vector3(L * 0.8, 8.0, 0.4), s.team, at + Vector3(0, -4.0, (W * 0.5 + 0.3) * side), Vector3(10 * side, 0, 0)))
	for x in [-L * 0.5, L * 0.5]:
		n.add_child(rod(at + Vector3(x, 5.0, -W * 0.5), at + Vector3(x, 5.0, W * 0.5), 0.4, 0.4, s.dark))
	if riders == 1:
		return {"crew0_f0_top": at + Vector3(0, 0.7, 0)}
	return {"crew0_f0_top": at + Vector3(L * 0.05, 0.7, W * 0.3), "crew1_f0_top": at + Vector3(-L * 0.05, 0.7, -W * 0.3)}


## Humans: a war elephant, grey and wrinkled, tusks capped in bronze, ears out. a: a howdah with two
## riders; b: armoured (a team-trimmed caparison, a brow plate), one rider on its neck.
## play (in play, 2026-10-16): the body alone, its legs and head baked apart (cut at each hip and at the
## neck: "leg.beast_elephant", "head.beast_elephant") so it walks and swings its tusks (UnitView._beast).
func _elephant(s: Dictionary, with_howdah: bool, play := false) -> Dictionary:
	var n := Node3D.new()
	var m := _elephant_mats()
	var hips := []
	for leg in [[13.0, 1], [-13.0, 1]]:
		for side in [1, -1]:
			var x: float = leg[0] + (2.0 if side > 0 else -1.0)
			var hip := Vector3(x, 30.0, 8.5 * side)
			if play:
				hips.append(hip)
			else:
				elephant_leg(n, hip, side, m)
	n.add_child(blob(Vector3(26.0, 16.0, 14.5), m.hide, Vector3(0, 36.0, 0)))
	n.add_child(blob(Vector3(12.0, 13.0, 12.0), m.hide, Vector3(18.0, 40.0, 0)))   # the shoulders
	if not play:
		elephant_head(n, ELEPHANT_NECK, m)
	n.add_child(rod(Vector3(-25.0, 38.0, 0), Vector3(-29.0, 22.0, 0), 1.0, 0.6, m.hide))   # the tail
	var out := {"node": n}
	if with_howdah:
		out.sockets = howdah(n, s, Vector3(-3.0, 52.5, 0), 22.0, 18.0)
		n.add_child(_box(Vector3(26.0, 0.6, 30.0), s.trim, Vector3(-3.0, 51.6, 0)))   # a saddle cloth in the culture's colour
	else:
		# Armoured: a caparison down its flanks (team border), a bronze brow plate, a rider on the neck.
		for side in [1, -1]:
			n.add_child(_box(Vector3(30.0, 13.0, 0.5), s.trim, Vector3(-1.0, 40.0, 15.0 * side), Vector3(8 * side, 0, 0)))
			n.add_child(_box(Vector3(30.0, 1.8, 0.6), s.team, Vector3(-1.0, 33.5, 15.9 * side), Vector3(8 * side, 0, 0)))
		n.add_child(dome(Vector3(5.5, 3.0, 8.5), m.bronze, Vector3(30.5, 49.5, 0)))
		n.add_child(_box(Vector3(10.0, 1.0, 12.0), s.dark, Vector3(17.0, 51.5, 0)))
		out.sockets = {"crew0_f0_top": Vector3(17.0, 52.2, 0)}
	if play:
		out.sockets.head = ELEPHANT_NECK
		out.anchors = beast_hips(hips)
	return out


const ELEPHANT_NECK := Vector3(28.5, 42.0, 0)   # where its head turns (in play: the head's origin)


func _elephant_mats() -> Dictionary:
	return {"hide": surf("hide", Color(0.62, 0.6, 0.58), 6.0), "dark": surf("hide", Color(0.45, 0.43, 0.42), 6.0),
		"ivory": plain(Color("#ece2c8")), "bronze": surf("bronze", Color.WHITE, 3.0)}


## A pillar of a leg from its hip down to its round foot, on the `side` flank (+1 near, -1 far).
func elephant_leg(n: Node3D, hip: Vector3, side: float, m: Dictionary) -> void:
	n.add_child(rod(hip, hip + Vector3(0, -25.0, 0.5 * side), 5.6, 5.0, m.hide))
	n.add_child(cone(5.6, 5.8, 2.4, m.dark, hip + Vector3(0, -28.8, 0.5 * side)))   # the foot
	for t in 3:   # toenails, pale, round the front of the foot
		var a := deg_to_rad(-40.0 + t * 40.0)
		n.add_child(blob(Vector3(1.2, 1.0, 1.0), m.ivory, hip + Vector3(5.2 * cos(a), -28.6, 0.5 * side + 5.2 * sin(a))))


## The head, its neck's turning point at `at`: brow, trunk, ears out, bronze-capped tusks, eyes.
func elephant_head(n: Node3D, at: Vector3, m: Dictionary) -> void:
	var o := at - ELEPHANT_NECK
	n.add_child(blob(Vector3(10.0, 10.5, 9.5), m.hide, o + Vector3(28.0, 41.0, 0)))   # the head
	n.add_child(blob(Vector3(5.0, 4.0, 8.0), m.dark, o + Vector3(30.0, 49.0, 0)))   # the brow
	var trunk := [Vector3(35.0, 38.0, 0), Vector3(39.0, 30.0, 0), Vector3(40.5, 20.0, 0), Vector3(40.0, 11.0, 0), Vector3(42.5, 6.0, 0)]
	var tr := [4.2, 3.4, 2.8, 2.2, 1.6]
	for k in range(1, trunk.size()):
		n.add_child(rod(o + trunk[k - 1], o + trunk[k], tr[k - 1], tr[k], m.hide))
	for side in [1, -1]:
		var ear := cone(9.5, 9.5, 0.8, m.dark, o + Vector3(24.0, 42.0, 9.0 * side), Vector3(90, 0, 0), 20)   # (on the head's sides: at 11 out they floated off it)
		ear.scale = Vector3(0.8, 1.0, 1.15)
		n.add_child(ear)
		n.add_child(rod(o + Vector3(34.0, 34.0, 4.0 * side), o + Vector3(43.0, 30.0, 6.0 * side), 1.4, 0.7, m.ivory))   # tusks
		n.add_child(cone(0.4, 1.2, 2.2, m.bronze, o + Vector3(43.5, 29.8, 6.1 * side), Vector3(0, 0, -75)))
		n.add_child(blob(Vector3(1.1, 1.1, 0.8), plain(Color("#1a1412")), o + Vector3(32.5, 44.0, 6.8 * side)))


## A beast's four hips (front near, back near, front far, back far: as given) as part anchors,
## [hip, walk phase, side, flip, hind, fan]: the diagonal pairs step together.
static func beast_hips(hips: Array, hind := false) -> Array:
	var out := []
	for h in hips:
		var front: bool = h.x > 0.0
		var near: bool = h.z > 0.0
		out.append([h, 0.0 if front == near else PI, 1 if near else -1, 0, hind and not front])
	return out


## A chain of rods through `pts`, radii `r` (one per point).
func limb(n: Node3D, pts: Array, r: Array, m: Material) -> void:
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], m))


## A deck for riders: planks with their top at `at`, rails at the corners, the team cloth down both
## sides. Returns its top height.
func deck(n: Node3D, s: Dictionary, at: Vector3, L: float, W: float, cloth := 7.0) -> float:
	n.add_child(_box(Vector3(L, 1.6, W), s.dark, at + Vector3(0, -0.8, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(L * 0.8, cloth, 0.4), s.team, at + Vector3(0, -cloth * 0.5 - 0.6, (W * 0.5 + 0.4) * side), Vector3(10 * side, 0, 0)))
		for x in [-L * 0.5 + 0.6, L * 0.5 - 0.6]:
			n.add_child(rod(at + Vector3(x, 0, W * 0.5 * side), at + Vector3(x, 4.5, W * 0.5 * side), 0.45, 0.45, s.dark))
		n.add_child(rod(at + Vector3(-L * 0.5, 4.5, W * 0.5 * side), at + Vector3(L * 0.5, 4.5, W * 0.5 * side), 0.4, 0.4, s.dark))
	return at.y


## Rats: a war boar the size of a cart horse and then some (shoulder ~48 against the pony's ~24): a
## crest of bristles along the spine, a long wedge of a head, tusks curving up, plates of rusted scrap
## riveted over its flanks. a: a junk howdah, two rats; b: barded in plate, a spiked face plate, one
## rider and a scrap standard.
func _war_boar(s: Dictionary, with_howdah: bool, play := false) -> Dictionary:
	var n := Node3D.new()
	var m := _boar_mats()
	# Front-heavy on thin legs: the shoulders tower over a smaller rump, the legs taper to trotters.
	var hips := []
	for x in [18.0, -19.0]:
		for side in [1, -1]:
			if play:   # (the fore hips back a little: at 18 the thighs ran into the head, baked apart)
				hips.append(Vector3(x - (4.0 if x > 0.0 else 0.0), 28.0, (11.0 if x > 0.0 else 9.5) * side))   # (and out on the hump's side: at 9.5 they sat 4 deep)
			else:
				boar_leg(n, Vector3(x, 28.0, 9.0 * side), side, x > 0.0, m)
	n.add_child(blob(Vector3(26.0, 13.0, 13.0), m.fur, Vector3(-4.0, 30.0, 0)))   # the barrel
	n.add_child(blob(Vector3(16.0, 18.0, 15.0), m.fur, Vector3(12.0, 34.0, 0)))   # the shoulders' hump
	n.add_child(blob(Vector3(11.0, 10.0, 10.0), m.dark, Vector3(-20.0, 30.0, 0)))   # the rump
	if not play:
		boar_head(n, BOAR_NECK, m)
	var fur: Material = m.fur
	var dark: Material = m.dark
	var bristle: Material = m.bristle
	# The bristles: a tall ragged crest over the neck and shoulders, shorter down the spine.
	for k in 14:
		var x := 28.0 - k * 4.0
		var top := 34.0 + 18.0 * sqrt(maxf(0.0, 1.0 - pow((x - 12.0) / 17.0, 2))) if x > -3.0 else 30.0 + 13.0 * sqrt(maxf(0.0, 1.0 - pow((x + 4.0) / 26.0, 2)))
		if x > 24.0:
			top = 40.0
		var h := (11.0 if x > 4.0 else 6.0) + (k % 3) * 1.5
		n.add_child(cone(0.2, 2.6, h, bristle, Vector3(x, top + h * 0.3, ((k % 2) - 0.5) * 1.6), Vector3(0, 0, 32), 6))
	limb(n, [Vector3(-30.0, 34.0, 0), Vector3(-33.0, 27.0, 0), Vector3(-32.0, 22.0, 0)], [1.0, 0.7, 0.5], dark)   # the tail
	n.add_child(blob(Vector3(1.2, 2.4, 1.2), bristle, Vector3(-32.0, 21.0, 0)))
	# Rusted scrap riveted over the flanks.
	for side in [1, -1]:
		for k in 3:
			var at := Vector3(10.0 - k * 11.0, 31.0 - absf(k - 0.5) * 1.0, (14.2 - absf(k - 1) * 0.6) * side)
			n.add_child(_box(Vector3(10.5, 12.0, 0.8), s.plate if k != 1 else s.plate2, at, Vector3(8 * side, 0, 4 - k * 4)))
			for r in [[-4.0, 5.0], [4.0, 5.0], [-4.0, -5.0], [4.0, -5.0]]:
				n.add_child(blob(Vector3.ONE * 0.6, s.rivet, at + Vector3(r[0], r[1], 0.6 * side)))
	var sockets := {}
	if with_howdah:
		# A junk howdah: a pallet deck lashed on with chain, rails, the team cloth.
		var y := deck(n, s, Vector3(-6.0, 46.5, 0), 22.0, 18.0)
		n.add_child(_box(Vector3(26.0, 0.8, 28.0), s.wood2, Vector3(-6.0, 45.3, 0)))
		for side in [1, -1]:
			chain(n, Vector3(-6.0, 45.0, 14.0 * side), Vector3(-6.0, 22.0, 12.5 * side), s.metal)
		pennant(n, s, Vector3(-16.4, y, -8.0), 14.0, 4.5)
		sockets = {"crew0_f0_top": Vector3(-0.5, y + 0.7, 3.0), "crew1_f0_top": Vector3(-11.0, y + 0.7, -3.0)}
	else:
		# Barded: a plate cover over the back, a face plate on the brow with a pipe spike, one rider on
		# a pad over the hump and a scrap standard behind him.
		n.add_child(dome(Vector3(18.0, 4.0, 15.0), s.plate, Vector3(-6.0, 42.5, 0)))
		n.add_child(dome(Vector3(8.0, 4.5, 9.0), s.plate2, Vector3(32.0, 38.5, 0)))
		n.add_child(cone(0.3, 1.8, 8.0, s.pipe, Vector3(34.5, 44.5, 0), Vector3(0, 0, -35), 10))
		n.add_child(_box(Vector3(12.0, 1.6, 12.0), s.team, Vector3(9.0, 52.4, 0)))
		n.add_child(_box(Vector3(9.0, 1.4, 9.0), s.dark, Vector3(9.0, 53.6, 0)))
		n.add_child(rod(Vector3(-8.0, 46.0, 0), Vector3(-8.0, 70.0, 0), 0.6, 0.5, s.pipe))
		n.add_child(slab([Vector2(0, 0), Vector2(-10, -1), Vector2(-9, -6), Vector2(-11, -11), Vector2(0, -10)], 0.4, s.team, Vector3(-8.2, 69.0, 0)))
		sockets = {"crew0_f0_top": Vector3(9.0, 54.3, 0)}
	if play:
		sockets.head = BOAR_NECK
		return {"node": n, "sockets": sockets, "anchors": beast_hips(hips, true)}
	return {"node": n, "sockets": sockets}


const BOAR_NECK := Vector3(24.0, 32.0, 0)   # where its head turns (in play: the head's origin)


func _boar_mats() -> Dictionary:
	return {"fur": surf("rat_fur", Color(0.42, 0.33, 0.27), 5.0), "dark": surf("rat_fur", Color(0.26, 0.21, 0.18), 4.0),
		"bristle": surf("mane", Color(0.78, 0.68, 0.54), 3.0),   # grizzled, pale against the coat
		"hoof": plain(Color("#1e1814")), "ivory": plain(Color("#f0e6cc")), "snout": surf("skin", Color(0.62, 0.45, 0.4), 4.0)}


## A leg from its hip to its trotter, on the `side` flank: the fore legs' knees forward, in the coat's
## colour, the hind legs' hocks back, darker.
func boar_leg(n: Node3D, hip: Vector3, side: float, fore: bool, m: Dictionary) -> void:
	var d := 1.0 if fore else -1.0
	limb(n, [hip, hip + Vector3(2.5 * d, -16.0, 0.5 * side), hip + Vector3(1.0, -25.4, 0.5 * side)], [6.0, 3.2, 2.3], m.fur if fore else m.dark)
	n.add_child(cone(1.8, 2.6, 2.8, m.hoof, hip + Vector3(1.5, -26.6, 0.5 * side)))


## The head, its neck's turning point at `at`: a long wedge forward and a little down, the snout's disc,
## great tusks up out of the jaw, small eyes, ears.
func boar_head(n: Node3D, at: Vector3, m: Dictionary) -> void:
	var o := at - BOAR_NECK
	n.add_child(blob(Vector3(13.0, 10.5, 9.0), m.fur, o + Vector3(32.0, 31.0, 0), Vector3(0, 0, -14)))
	n.add_child(rod(o + Vector3(37.0, 28.0, 0), o + Vector3(51.0, 22.0, 0), 7.0, 4.6, m.fur))
	n.add_child(cone(4.8, 4.8, 1.6, m.snout, o + Vector3(52.0, 21.6, 0), Vector3(0, 0, -68), 16))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.7, 0.9, 0.6), m.hoof, o + Vector3(52.8, 22.0, 1.8 * side)))
		limb(n, [o + Vector3(45.0, 21.0, 4.5 * side), o + Vector3(51.0, 22.5, 8.5 * side), o + Vector3(54.5, 29.0, 9.5 * side), o + Vector3(52.0, 34.0, 8.5 * side)], [2.3, 1.9, 1.2, 0.4], m.ivory)
		n.add_child(blob(Vector3(1.3, 1.1, 0.9), plain(Color("#120c08")), o + Vector3(37.5, 33.0, 7.0 * side)))
		n.add_child(blob(Vector3(0.45, 0.45, 0.4), plain(Color("#d8a040")), o + Vector3(38.3, 33.4, 7.7 * side)))
		n.add_child(cone(0.4, 3.2, 7.0, m.dark, o + Vector3(27.0, 42.0, 6.0 * side), Vector3(25 * side, 0, 20), 8))   # an ear


## Spiders: a giant tarantula (legs across ~80 against the spider mount's ~30): a furred carapace and a
## heavy abdomen, eight thick legs with orange-banded knees, fangs and pedipalps, an eye cluster that
## glints. Nobody rides it. a: alone, a silk-and-bone harness and the team banner on its back; b: a
## small crew of two in a basket on its back. `patterned` (in play, D-129: "too single-colour"): a pale rim
## and dark rays on a lighter carapace, pale chevrons down the abdomen, tufts of pale hair on its back and legs.
## play (in play, 2026-10-16): the legs and the jaws (chelicerae, fangs, pedipalps) baked apart, cut at each
## hip and at the mouth ("leg.beast_tarantula": one leg straight out, fanned forward or back at its hip by
## TARANTULA_FAN; "head.beast_tarantula"), so it scuttles and bites (UnitView._beast).
func _tarantula(s: Dictionary, with_crew: bool, patterned := false, play := false) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color(0.28, 0.24, 0.24), 4.0)
	var dark := surf("rat_fur", Color(0.17, 0.15, 0.16), 3.5)
	var band := surf("rat_fur", Color(0.95, 0.55, 0.25), 3.0)
	var eye := plain(Color("#0c0a0e"))
	eye.roughness = 0.15
	eye.metallic_specular = 0.9
	var C := Vector3(12.0, 18.0, 0)   # the carapace
	var A := Vector3(-16.0, 22.0, 0)   # the abdomen
	# Legs: four a side, the front pair reaching forward, the back pair back; knees high, feet wide.
	var legs := [[22.0, 30.0, 50.0], [16.0, 14.0, 20.0], [9.0, -2.0, -12.0], [3.0, -14.0, -34.0]]
	var hips := []
	for i in legs.size():
		for side in [1, -1]:
			# Alternating tetrapods: the near flank's 1st and 3rd step with the far flank's 2nd and 4th.
			# A wave down each flank, front to back, the far flank half a cycle behind (adjacent legs a quarter
			# apart: in step with each other, the back pairs fanned close crossed). Hips on the carapace's rim.
			hips.append([Vector3(legs[i][0], 17.0, TARANTULA_HIP_Z[i] * side), PI * 0.5 * i + (0.0 if side > 0 else PI), side, 0, false, TARANTULA_FAN[i]])
	for leg in ([] if play else legs):
		for side in [1, -1]:
			var hip := Vector3(leg[0], 17.0, 9.0 * side)
			var knee := Vector3(leg[0] + (leg[1] - leg[0]) * 0.55, 34.0, 24.0 * side)
			var ankle := Vector3(leg[0] + (leg[2] - leg[0]) * 0.85, 12.0, 36.0 * side)
			var foot := Vector3(leg[2], 0.8, 39.0 * side)
			limb(n, [hip, knee], [3.4, 3.0], fur)
			n.add_child(blob(Vector3(3.2, 3.2, 3.2), band, knee))
			limb(n, [knee, ankle, foot], [2.8, 2.2, 1.4], dark)
	n.add_child(blob(Vector3(15.0, 8.0, 13.0), fur, C))
	var coat := surf("rat_fur", Color(0.5, 0.27, 0.18), 4.0) if patterned else fur   # (patterned: a rust-red rump, the legs stay black)
	n.add_child(blob(Vector3(19.0, 14.0, 16.0), coat, A, Vector3(0, 0, -10)))
	n.add_child(blob(Vector3(10.0, 6.0, 9.0), dark, A + Vector3(-12.0, -1.0, 0)))   # (the furred tip)
	if not play:
		tarantula_jaws(n, TARANTULA_MOUTH, fur, dark)
	for k in 8:   # the eyes, a cluster on a turret at the carapace's front
		var a := TAU * k / 8.0
		n.add_child(blob(Vector3.ONE * (1.1 if k % 2 == 0 else 0.7), eye, Vector3(21.0 + cos(a) * 1.8, 25.5 + sin(a) * 0.8, sin(a) * 2.6)))
	if patterned:
		tarantula_pattern(n, C, A, [] if play else legs)
	var sockets := {}
	var top := A + Vector3(2.0, 13.6, 0)
	# A harness: a silk band round the abdomen, bone toggles, the team cloth over its back.
	n.add_child(ring(0.9, 1.0, surf("cloth", Color("#d8d2e4"), 3.0), A, Vector3(0, 0, 80), Vector3(17.0, 3.0, 17.0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 9.0, 0.4), s.team, A + Vector3(2.0, 3.0, 15.0 * side), Vector3(30 * side, 0, 0)))
		n.add_child(blob(Vector3(1.2, 1.2, 1.2), s.metal, A + Vector3(2.0, 9.0, 13.5 * side)))
	if with_crew:
		var y := deck(n, s, top + Vector3(0, 1.4, 0), 18.0, 14.0, 4.0)
		sockets = {"crew0_f0_top": Vector3(top.x + 4.5, y + 0.7, 2.5), "crew1_f0_top": Vector3(top.x - 4.5, y + 0.7, -2.5)}
	else:
		n.add_child(_box(Vector3(10.0, 1.4, 12.0), s.dark, top))
		n.add_child(rod(top, top + Vector3(-2.0, 30.0, 0), 0.6, 0.5, s.wood))
		n.add_child(blob(Vector3(1.6, 2.0, 1.6), s.metal, top + Vector3(-2.0, 31.2, 0)))   # a skull finial
		n.add_child(slab([Vector2(0, 0), Vector2(-12, 0), Vector2(-12, -10), Vector2(-9, -8), Vector2(-6, -11), Vector2(-3, -8), Vector2(0, -10)], 0.4, s.team, top + Vector3(-2.2, 29.0, 0)))
	if play:
		sockets.head = TARANTULA_MOUTH
		return {"node": n, "sockets": sockets, "anchors": hips}
	return {"node": n, "sockets": sockets}


const TARANTULA_MOUTH := Vector3(23.0, 15.0, 0)   # where its jaws hinge (in play: the head's origin)
## How far each pair of legs (front to back) turns from straight out (degrees, + back: UnitModels.leg_basis):
## where _tarantula's feet were, 50, 20, -12 and -34 along it.
const TARANTULA_FAN := [-45.0, -12.0, 25.0, 55.0]
const TARANTULA_HIP_Z := [9.0, 11.5, 11.5, 9.5]   # each pair's hips out on the carapace's rim (at 9 the middle ones sat 4 deep)


## The chelicerae with their fangs and the pedipalps out front, hinged at `at`.
func tarantula_jaws(n: Node3D, at: Vector3, fur: Material, dark: Material) -> void:
	var o := at - TARANTULA_MOUTH
	var fang := plain(Color("#141012"))
	n.add_child(blob(Vector3(3.0, 3.0, 6.5), dark, o + Vector3(24.0, 14.5, 0)))   # the mouth, the jaws and palps hinged on it
	for side in [1, -1]:
		n.add_child(blob(Vector3(4.0, 5.0, 3.0), dark, o + Vector3(26.0, 14.0, 3.4 * side), Vector3(0, 0, -20)))
		n.add_child(cone(0.1, 1.2, 5.0, fang, o + Vector3(28.5, 9.0, 3.0 * side), Vector3(0, 0, -15), 8))
		limb(n, [o + Vector3(24.0, 15.0, 6.0 * side), o + Vector3(32.0, 18.0, 9.0 * side), o + Vector3(36.0, 6.0, 10.0 * side)], [1.8, 1.6, 1.4], fur)


## One leg in play, from its hip at the origin straight out to the near side (+z) and down: the furred
## thigh up to the orange knee, the shin and foot dark; its pale tufts and shin band (the patterned coat).
func _leg_beast_tarantula(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color(0.28, 0.24, 0.24), 4.0)
	var dark := surf("rat_fur", Color(0.17, 0.15, 0.16), 3.5)
	var band := surf("rat_fur", Color(0.95, 0.55, 0.25), 3.0)
	var pale := plain(Color("#e6d2a4"))
	var knee := Vector3(0, 17.0, 15.0)
	var ankle := Vector3(0, -5.0, 27.0)
	limb(n, [Vector3.ZERO, knee], [3.4, 3.0], fur)
	n.add_child(blob(Vector3(3.2, 3.2, 3.2), band, knee))
	limb(n, [knee, ankle, Vector3(0, -16.2, 30.0)], [2.8, 2.2, 1.4], dark)
	for t in [0.35, 0.65]:
		var at: Vector3 = knee * t
		n.add_child(rod(at + Vector3(0, 2.6, 0), at + Vector3(-0.6, 5.4, 0.8), 0.6, 0.1, pale))
	n.add_child(blob(Vector3(2.7, 2.7, 2.7), pale, knee.lerp(ankle, 0.45)))
	return {"node": n}


func _head_beast_tarantula(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	tarantula_jaws(n, Vector3.ZERO, surf("rat_fur", Color(0.28, 0.24, 0.24), 4.0), surf("rat_fur", Color(0.17, 0.15, 0.16), 3.5))
	return {"node": n, "sockets": {"top": Vector3(6.0, 4.0, 0)}}


## Frogs, b: a giant grey heron, the frogs' oldest enemy, broken to the saddle: long legs, an S of a
## neck, a dagger of a beak, a black crest; one frog in a saddle between its wings.
## play (in play, 2026-10-16): the legs and the neck with its head baked apart, cut at each hip and where the
## neck leaves the body ("leg.beast_heron", "head.beast_heron"), so it strides and stabs (UnitView._beast).
func _heron(s: Dictionary, play := false) -> Dictionary:
	var n := Node3D.new()
	var grey := surf("hide", Color(0.72, 0.74, 0.78), 6.0)
	var dark := plain(Color("#3a3c44"))
	var hips := []
	for side in [1, -1]:
		if play:
			hips.append([Vector3(0.0, 40.0, 5.0 * side), 0.0 if side > 0 else PI, side, 0])
		else:
			heron_leg(n, Vector3(0.0, 40.0, 5.0 * side), side)
	n.add_child(blob(Vector3(17.0, 9.5, 10.0), grey, Vector3(-2.0, 46.0, 0), Vector3(0, 0, 12)))   # the body
	for side in [1, -1]:   # folded wings, darker at the tips, crossing over the tail
		n.add_child(blob(Vector3(17.0, 6.0, 3.0), grey, Vector3(-5.0, 47.0, 8.5 * side), Vector3(0, 0, 14)))
		n.add_child(blob(Vector3(10.0, 3.0, 2.4), dark, Vector3(-17.0, 43.5, 7.0 * side), Vector3(0, 0, 20)))
	if not play:
		heron_neck(n, HERON_NECK)
	n.add_child(_box(Vector3(11.0, 0.8, 18.0), s.team, Vector3(-7.0, 55.0, 0), Vector3(0, 0, 8)))
	n.add_child(_box(Vector3(8.0, 1.6, 9.0), s.dark, Vector3(-7.0, 56.0, 0)))
	var out := {"node": n, "sockets": {"crew0_f0_top": Vector3(-7.0, 56.8, 0)}}
	if play:
		out.sockets.head = HERON_NECK
		out.anchors = hips
	return out


const HERON_NECK := Vector3(12.5, 52.0, 0)   # where the neck leaves the body (in play: the head's origin)


## A stilt of a leg from its hip, the knee (the heel) bent back, three toes forward and one back.
func heron_leg(n: Node3D, hip: Vector3, side: float) -> void:
	var leg := plain(Color("#8a7a4a"))
	limb(n, [hip, hip + Vector3(2.0, -14.0, 1.0 * side), hip + Vector3(-2.0, -28.0, 1.0 * side), hip + Vector3(0.0, -39.0, 1.5 * side)], [2.4, 1.3, 1.2, 1.0], leg)
	var foot := hip + Vector3(0.0, -39.2, 1.5 * side)
	for t in 3:
		n.add_child(rod(foot, hip + Vector3(6.0, -39.4, (1.5 + (t - 1) * 3.0) * side), 0.6, 0.4, leg))
	n.add_child(rod(foot, hip + Vector3(-4.0, -39.4, 1.5 * side), 0.6, 0.4, leg))


## The S of a neck from where it leaves the body (`at`), the head, the dagger of a beak, the black crest.
func heron_neck(n: Node3D, at: Vector3) -> void:
	var o := at - HERON_NECK
	var white := surf("hide", Color(0.95, 0.95, 0.93), 6.0)
	var dark := plain(Color("#3a3c44"))
	limb(n, [o + Vector3(10.0, 50.0, 0), o + Vector3(16.0, 58.0, 0), o + Vector3(12.0, 66.0, 0), o + Vector3(16.0, 74.0, 0)], [4.0, 3.0, 2.8, 2.8], white)
	n.add_child(blob(Vector3(4.6, 3.6, 3.4), white, o + Vector3(18.0, 75.0, 0)))
	n.add_child(cone(0.2, 1.8, 14.0, plain(Color("#c8a040")), o + Vector3(28.0, 74.0, 0), Vector3(0, 0, -93), 10))
	limb(n, [o + Vector3(15.0, 77.0, 0), o + Vector3(6.0, 79.0, 0), o + Vector3(0.0, 77.0, 0)], [1.0, 0.7, 0.3], dark)   # the crest
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.9, 0.9, 0.6), plain(Color("#d8b020")), o + Vector3(20.0, 76.0, 3.0 * side)))
		n.add_child(rod(o + Vector3(17.0, 75.5, 3.4 * side), o + Vector3(22.0, 75.0, 2.4 * side), 0.4, 0.3, dark))


## Forest beetles: a giant praying mantis, leaf-green, its raptorial arms folded and spiked, the long
## neck up, wings folded along its abdomen; one beetle in a saddle on its back. A tall thin shape no
## other beast in the game has.
## play (in play, 2026-10-16): the four walking legs and the fore body (the long prothorax, the head, the
## raptorial arms) baked apart, cut at each hip and at the thorax ("leg.beast_mantis": one leg straight
## out, fanned forward or back by MANTIS_FAN; "head.beast_mantis"), so it walks and strikes (UnitView._beast).
func _mantis(s: Dictionary, play := false) -> Dictionary:
	var n := Node3D.new()
	var green := surf("chitin", Color("#6a9a3a"), 5.0)
	green.roughness = 0.5
	var dark := surf("chitin", Color("#4a7028"), 4.0)
	var wing := surf("leaf", Color(0.75, 0.9, 0.55), 10.0)
	var hips := []
	for leg in [[2.0, 12.0], [-6.0, -16.0]]:   # two pairs of walking legs, long and thin
		for side in [1, -1]:
			if play:
				var fore: bool = leg[0] > 0.0
				hips.append([Vector3(leg[0], 22.0, 4.0 * side), 0.0 if fore == (side > 0) else PI, side, 0, false, MANTIS_FAN[0 if fore else 1]])
			else:
				limb(n, [Vector3(leg[0], 22.0, 4.0 * side), Vector3(leg[0] + (leg[1] - leg[0]) * 0.4, 34.0, 18.0 * side), Vector3(leg[1], 0.8, 24.0 * side)], [1.8, 1.4, 0.8], dark)
	n.add_child(blob(Vector3(22.0, 6.5, 7.5), green, Vector3(-20.0, 26.0, 0), Vector3(0, 0, 10)))   # the abdomen
	for side in [1, -1]:
		n.add_child(blob(Vector3(20.0, 2.0, 5.0), wing, Vector3(-18.0, 31.0, 3.0 * side), Vector3(0, 0, 10)))
	n.add_child(blob(Vector3(7.0, 5.0, 6.0), green, Vector3(0.0, 23.0, 0)))   # the thorax
	if not play:
		mantis_fore(n, MANTIS_NECK, green, dark)
	n.add_child(_box(Vector3(12.0, 0.8, 16.0), s.team, Vector3(-8.0, 31.0, 0), Vector3(0, 0, 8)))
	n.add_child(_box(Vector3(9.0, 1.6, 8.0), s.dark, Vector3(-8.0, 32.2, 0), Vector3(0, 0, 8)))
	var out := {"node": n, "sockets": {"crew0_f0_top": Vector3(-8.0, 33.4, 0)}}
	if play:
		out.sockets.head = MANTIS_NECK
		out.anchors = hips
	return out


const MANTIS_NECK := Vector3(4.0, 24.0, 0)   # where the prothorax leaves the thorax (in play: the head's origin)
const MANTIS_FAN := [-27.0, 27.0]   # the walking legs turned forward (the fore pair) and back from straight out


## The fore body from the thorax (`at`): the long prothorax up, the head with its big eyes and antennae,
## the raptorial arms (coxa down and forward, femur back up, spiked, the tibia folded under).
func mantis_fore(n: Node3D, at: Vector3, green: Material, dark: Material) -> void:
	var o := at - MANTIS_NECK
	var spike := plain(Color("#2a3a14"))
	limb(n, [o + Vector3(4.0, 24.0, 0), o + Vector3(16.0, 42.0, 0)], [3.4, 2.6], green)   # the long prothorax
	n.add_child(blob(Vector3(3.6, 4.0, 5.6), green, o + Vector3(19.0, 46.0, 0)))   # the head
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.4, 2.6, 2.2), plain(Color("#c8d870")), o + Vector3(19.5, 48.0, 5.0 * side)))
		limb(n, [o + Vector3(20.0, 49.0, 1.5 * side), o + Vector3(26.0, 58.0, 5.0 * side), o + Vector3(32.0, 62.0, 8.0 * side)], [0.5, 0.35, 0.2], dark)
		var cox := o + Vector3(13.0, 37.0, 3.5 * side)
		var elbow := o + Vector3(20.0, 26.0, 6.0 * side)
		var wrist := o + Vector3(25.0, 40.0, 6.5 * side)
		limb(n, [cox, elbow, wrist], [2.2, 2.4, 1.8], green)
		limb(n, [wrist, o + Vector3(22.0, 31.0, 7.0 * side)], [1.6, 0.6], dark)
		for t in 4:
			n.add_child(cone(0.1, 0.5, 2.4, spike, elbow.lerp(wrist, 0.2 + t * 0.2) + Vector3(-1.4, 0, 0), Vector3(0, 0, 70), 6))


## The frame and arm on its sills at y = `base` (0, or a deck), `k` times the size; returns the short
## end (where the pull ropes hang) and the long end.
func sling_frame(n: Node3D, s: Dictionary, base := 0.0, k := 1.0) -> Array:
	var top := sling_towers(n, s, base, k)
	# The arm, cocked: the short end forward and down, the long end back and high.
	var short := Vector3(18.0 * k, top - 10.0 * k, 0)
	var long := Vector3(-48.0 * k, top + 26.0 * k, 0)
	sling_arm(n, s, short, long, k)
	# A crossbar at the short end, the pull ropes hanging from it.
	n.add_child(rod(short + Vector3(0, -2.0, -8.0) * k, short + Vector3(0, -2.0, 8.0) * k, 1.0 * k, 1.0 * k, s.dark))
	return [short + Vector3(0, -2.0, 0) * k, long]


## The sling's frame on its sills at y = `base`, `k` times the size: sills, braced towers, cross ties,
## raking struts, iron bearing caps and the axle. Returns the axle's height.
func sling_towers(n: Node3D, s: Dictionary, base := 0.0, k := 1.0) -> float:
	var T := 4.2 * k   # the timbers
	var top := base + 50.0 * k
	var L := 28.0 * k
	var W := 15.0 * k
	for side in [1, -1]:
		n.add_child(beam(Vector3(-L, base + T * 0.5, W * side), Vector3(L, base + T * 0.5, W * side), T, T, s.dark))   # the sills
		n.add_child(beam(Vector3(-16.0 * k, base + T, W * side), Vector3(0, top, 7.0 * k * side), T * 0.9, T * 0.9, s.wood))   # the tower's legs
		n.add_child(beam(Vector3(16.0 * k, base + T, W * side), Vector3(0, top, 7.0 * k * side), T * 0.9, T * 0.9, s.wood))
		n.add_child(beam(Vector3(-8.0 * k, base + 25.0 * k, 11.0 * k * side), Vector3(8.0 * k, base + 25.0 * k, 11.0 * k * side), T * 0.7, T * 0.7, s.dark))   # the cross tie
		n.add_child(beam(Vector3(-L + 2.0 * k, base + T, W * side), Vector3(-9.0 * k, base + 30.0 * k, 10.0 * k * side), T * 0.7, T * 0.7, s.dark))   # raking struts
		n.add_child(beam(Vector3(L - 2.0 * k, base + T, W * side), Vector3(9.0 * k, base + 30.0 * k, 10.0 * k * side), T * 0.7, T * 0.7, s.dark))
		n.add_child(_box(Vector3(T + 1.2, 2.2 * k, T + 1.2), s.metal, Vector3(0, top - 1.0 * k, 7.0 * k * side)))   # the bearing caps
	for x in [-L + 2.0 * k, 0.0, L - 2.0 * k]:
		n.add_child(beam(Vector3(x, base + T * 1.5, -W - 2.0 * k), Vector3(x, base + T * 1.5, W + 2.0 * k), T, T, s.dark))
	n.add_child(rod(Vector3(0, top, -10.0 * k), Vector3(0, top, 10.0 * k), 1.8 * k, 1.8 * k, s.metal, false))   # the axle
	return top


## The arm from its short end to its long end (through the axle): thick at the short end, tapering,
## bound with iron, a team cloth; the sling's two cords from the long end to a big pouch with a stone.
func sling_arm(n: Node3D, s: Dictionary, short: Vector3, long: Vector3, k := 1.0, pouch_drop := Vector3(-3.0, -20.0, 0), loaded := true) -> Vector3:
	var mid := short.lerp(long, 0.3)
	n.add_child(beam(short, mid, 5.4 * k, 5.4 * k, s.wood))
	n.add_child(beam(mid, long, 3.6 * k, 3.6 * k, s.wood))
	var ang := rad_to_deg((long - short).angle_to(Vector3.RIGHT))
	for t in [0.08, 0.22, 0.42, 0.62]:
		n.add_child(ring(2.2 * k, 3.4 * k, s.metal, short.lerp(long, t), Vector3(0, 0, 90 + ang)))
	n.add_child(_box(Vector3(14.0 * k, 0.6, 5.8 * k), s.team, short.lerp(long, 0.48) + Vector3(0, 2.4 * k, 0), Vector3(0, 0, ang)))
	# The sling: two cords from the long end down to a big pouch with a boulder in it.
	var pouch := long + pouch_drop * k
	for z in [1.2, -1.2]:
		n.add_child(rod(long, pouch + Vector3(0, 1.0, z) * k, 0.35, 0.35, s.rope, false))
	n.add_child(blob(Vector3(3.6, 2.4, 3.6) * k, surf("leather", Color.WHITE, 2.0), pouch))
	if loaded:
		n.add_child(blob(Vector3.ONE * 3.2 * k, s.ammo, pouch + Vector3(0, 1.4, 0) * k))
	return pouch


const SLING_FILE := Vector3(36.0, 18.0, 15.0)   # the haulers' files: the first at x, each next y further out, z either side


## On its sills: six haulers in front, a file of three beside each of two pull ropes (the ropes run from the
## short end's crossbar down to stakes in the ground ahead, so they're tied whoever hauls), one loader at
## the stone pile behind. A crew too big for the files (a centaur's horse half: UnitView.engine_sockets)
## hauls three abreast further out ("_wide"), the rest of the files ("_narrow") left out.
func _great_sling(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var ends := sling_frame(n, s)
	var short: Vector3 = ends[0]
	var sockets := {}
	for side in [1, -1]:
		var stake := Vector3(SLING_FILE.x + 2.0 * SLING_FILE.y + 12.0, 0, 9.0 * side)
		n.add_child(rod(short + Vector3(0, 0, 7.0 * side), stake + Vector3(0, 1.5, 0), 0.4, 0.4, s.rope, false))
		n.add_child(cone(0.25, 0.9, 5.0, s.dark, stake + Vector3(0, 1.5, 0), Vector3(0, 0, -20), 8))   # the stake
	for k in 6:
		var side := 1.0 if k < 3 else -1.0
		var at := Vector3(SLING_FILE.x + (k % 3) * SLING_FILE.y, 0, SLING_FILE.z * side)
		sockets["crew%d_f4_raise%s" % [k, "" if k in [0, 3] else "_narrow"]] = at
	sockets["crew0_f4_raise_wide"] = Vector3(46.0, 0, 26.0)
	sockets["crew3_f4_raise_wide"] = Vector3(46.0, 0, -26.0)
	for k in 7:   # the stone pile
		var a := k * 2.4
		n.add_child(blob(Vector3.ONE * (2.8 - (k % 3) * 0.4), s.ammo, Vector3(-36.0 + cos(a) * 3.5, 2.4 + (1.6 if k == 6 else 0.0), 22.0 + sin(a) * 3.0)))
	sockets["crew6_f6_reach"] = Vector3(-36.0, 0, 13.0)
	sockets["crew6_f6_reach_wide"] = Vector3(-38.0, 0, 34.0)
	pennant(n, s, Vector3(0, 51.0, -10.0), 12.0, 5.0)
	if s.fam == "junk":   # patched with rusted plate, chain braces
		for side in [1, -1]:
			patch(n, s, Vector3(-8.0, 14.0, 15.6 * side), Vector2(7.0, 9.0), Vector3(0, 0, 32), s.plate)
			chain(n, Vector3(-26.0, 4.0, 15.0 * side), Vector3(0, 48.0, 7.0 * side), s.metal)
	return {"node": n, "sockets": sockets}


## Packed to march: the frame's timbers and the arm laid on a long, heavy wagon, the sling and ropes
## coiled, two crew walking beside.
func _great_packed(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	undercarriage(n, s, 54.0, 20.0, 6.0)
	n.add_child(_box(Vector3(58.0, 2.4, 20.0), s.dark, Vector3(0, 12.0, 0)))
	for z in [-7.0, 0.0, 7.0]:
		n.add_child(beam(Vector3(-26.0, 15.4, z), Vector3(26.0, 15.4, z), 4.2, 4.2, s.wood))
	n.add_child(beam(Vector3(-34.0, 20.0, 0), Vector3(34.0, 20.0, 0), 5.0, 5.0, s.wood))
	for t in [-20.0, 0.0, 20.0]:
		n.add_child(ring(2.6, 3.8, s.metal, Vector3(t, 20.0, 0), Vector3(0, 0, 90)))
	n.add_child(ring(2.4, 3.6, s.rope, Vector3(-14.0, 23.2, 0)))
	n.add_child(ring(2.4, 3.6, s.rope, Vector3(12.0, 23.2, 0)))
	n.add_child(_box(Vector3(18.0, 0.5, 21.0), s.team, Vector3(0, 13.4, 0)))
	return {"node": n, "sockets": {"crew0_f0": Vector3(8.0, 0, 18.0), "crew1_f0": Vector3(-14.0, 0, -18.0)}}


# ------------------------------------------------------------------ the frogs' great sling (D-131: FS1 A, the bullfrog leaper)

## A giant bullfrog crouched, facing +x, its feet on y = 0 at `at`: olive back, yellow throat, gold eyes,
## the brown eardrum, hind legs folded high to spring.
func bullfrog(n: Node3D, at: Vector3, k := 1.0) -> void:
	var skin := surf("frog_skin", Color("#6a8a3a"), 6.0)
	skin.roughness = 0.45
	var dark := surf("frog_skin", Color("#3e5a24"), 5.0)
	var throat := surf("frog_belly", Color("#e0c860"), 5.0)
	var b := Node3D.new()
	b.position = at
	b.scale = Vector3.ONE * k
	n.add_child(b)
	b.add_child(blob(Vector3(13.0, 8.5, 10.5), skin, Vector3(-2.0, 9.5, 0), Vector3(0, 0, 22)))   # the back, sloping up to the head
	b.add_child(blob(Vector3(9.0, 4.5, 8.0), throat, Vector3(4.0, 6.0, 0), Vector3(0, 0, 22)))
	b.add_child(blob(Vector3(8.5, 6.0, 9.5), skin, Vector3(9.0, 13.5, 0)))   # the head
	b.add_child(blob(Vector3(7.0, 3.2, 8.4), throat, Vector3(10.0, 10.0, 0)))   # the throat
	b.add_child(rod(Vector3(16.6, 12.0, -6.0), Vector3(17.4, 12.0, 0), 0.4, 0.4, plain(INK)))   # the wide mouth
	b.add_child(rod(Vector3(17.4, 12.0, 0), Vector3(16.6, 12.0, 6.0), 0.4, 0.4, plain(INK)))
	for side in [1, -1]:
		b.add_child(blob(Vector3(2.8, 2.8, 2.6), skin, Vector3(10.0, 19.0, 5.0 * side)))   # the eyes
		b.add_child(blob(Vector3(1.6, 1.6, 1.2), plain(Color("#d8a830")), Vector3(11.6, 19.6, 6.0 * side)))
		b.add_child(blob(Vector3(0.5, 0.9, 0.4), plain(Color("#140c06")), Vector3(12.8, 19.8, 6.6 * side)))
		b.add_child(cone(2.2, 2.2, 0.5, plain(Color("#7a5a30")), Vector3(5.0, 15.0, 8.4 * side), Vector3(90, 0, 0), 14))   # the eardrum
		b.add_child(blob(Vector3(11.0, 6.0, 4.5), dark, Vector3(-8.0, 6.5, 9.5 * side), Vector3(0, 0, 25)))   # a folded hind leg
		b.add_child(rod(Vector3(-2.0, 1.0, 11.5 * side), Vector3(8.0, 0.8, 13.0 * side), 1.8, 1.2, dark))   # its long foot
		b.add_child(rod(Vector3(8.0, 10.0, 6.0 * side), Vector3(12.0, 0.8, 8.5 * side), 2.0, 1.5, skin))   # a front leg
		for t in 4:
			b.add_child(rod(Vector3(12.0, 0.8, 8.5 * side), Vector3(15.0, 0.6, (8.5 + (t - 1.5) * 1.4) * side), 0.6, 0.45, skin))
	for t in 10:   # dark blotches over the back
		var a := t * 2.39996
		b.add_child(blob(Vector3(2.4, 0.8, 1.8), dark, Vector3(-4.0 + cos(a) * 7.0, 15.0 + sin(a * 0.5) * 1.5, sin(a) * 6.0)))


const FROG_SLING_K := 0.9        # the frame against GS2's
const FROG_TOWER := Vector3(-48.0, 62.0, 6.0)   # the reed tower: its middle (x), its plank top (y), its posts' half spread (x and z)
const FROG_HAUL_STAKE := Vector3(106.0, 0, -7.0)   # where the re-cocking rope is staked ahead
## The arm's two ends about the axle: cocked (the long end down in front, the pouch on the ground, the short end
## and its pad up high behind) and thrown (swung through: the short end down behind with the bullfrog on it, the
## long end high in front, the sling whipped over it, empty).
const FROG_ARM := {"cocked": [Vector2(-15.0, 15.0), Vector2(40.0, -35.0)], "thrown": [Vector2(-12.2, -14.6), Vector2(34.7, 41.4)]}


## The frogs' great sling: a counterweight sling the other way round from the traction one, worked by a giant
## bullfrog. Set up (`thrown` false): the long arm down in front with the loaded pouch on the ground, the short arm
## up high behind with a padded landing pad, the bullfrog crouched on a reed tower behind it about to leap. Thrown:
## the bullfrog landed on the pad, the arm swung through, the sling whipped up and empty (UnitView shows it for a
## moment after each shot: the part's `throw`). Crew: a loader at the pouch with the stones beside it, two haulers on
## the re-cocking rope (from the long end to a stake ahead), one minding the tower.
func _frog_sling(s: Dictionary, thrown := false) -> Dictionary:
	var n := Node3D.new()
	var k := FROG_SLING_K
	var top := sling_towers(n, s, 0.0, k)
	var ends: Array = FROG_ARM["thrown" if thrown else "cocked"]
	var short := Vector3(ends[0].x, top + ends[0].y, 0)
	var long := Vector3(ends[1].x, top + ends[1].y, 0)
	sling_arm(n, s, short, long, k, Vector3(14.0, 10.0, 0) if thrown else Vector3(6.0, -5.0, 0), not thrown)
	# The landing pad, pinned level on the short end (it swings on the pin as the arm goes over).
	n.add_child(_box(Vector3(13.0, 2.0, 13.0), s.wicker, short + Vector3(-1.0, 2.2, 0)))
	n.add_child(_box(Vector3(11.0, 0.6, 11.0), s.team, short + Vector3(-1.0, 3.5, 0)))
	# The tower: four bundled reed posts, braced, a plank top.
	var T := FROG_TOWER
	for x in [T.x - T.z, T.x + T.z]:
		for z in [-T.z, T.z]:
			bundle(n, Vector3(x, 0, z), Vector3(x, T.y, z * 0.9), 1.6, s, 4, 1.3)
	for y in [20.0, 42.0]:
		for z in [-T.z, T.z]:
			n.add_child(rod(Vector3(T.x - T.z, y, z), Vector3(T.x + T.z, y + 8.0, z), 0.6, 0.6, s.lash))
	n.add_child(_box(Vector3(16.0, 2.0, 16.0), s.plank, Vector3(T.x, T.y + 1.0, 0)))
	if thrown:   # landed on the pad
		bullfrog(n, short + Vector3(-9.0, 3.8, 0), 1.0)
	else:
		bullfrog(n, Vector3(T.x - 2.0, T.y + 2.0, 0), 1.05)
	# The re-cocking rope, from the long end down to a stake ahead (tied at both ends whoever hauls); its loop slips
	# off the arm as it throws, and lies coiled by the stake till the haulers hook it back on.
	if thrown:
		n.add_child(ring(1.8, 3.0, s.rope, FROG_HAUL_STAKE + Vector3(-4.0, 0.6, 0), Vector3.ZERO, Vector3(1.0, 1.4, 1.0)))
	else:
		n.add_child(rod(long + Vector3(0, 0, -1.5), FROG_HAUL_STAKE + Vector3(0, 1.5, 0), 0.4, 0.4, s.rope, false))
	n.add_child(cone(0.25, 0.9, 5.0, s.dark, FROG_HAUL_STAKE + Vector3(0, 1.5, 0), Vector3(0, 0, -20), 8))
	for kk in 5:   # the stones by the pouch: clay pots and river stones
		var a := kk * 2.4
		n.add_child(blob(Vector3.ONE * (2.6 - (kk % 3) * 0.4), s.ammo if kk % 2 == 0 else s.stone, Vector3(60.0 + cos(a) * 3.0, 2.2, 24.0 + sin(a) * 2.6)))
	pennant(n, s, Vector3(T.x + T.z, T.y + 2.0, -T.z), 12.0, 4.5)
	return {"node": n, "sockets": {"crew0_f4_reach": Vector3(54.0, 0, 13.0), "crew1_f4_raise": Vector3(68.0, 0, -17.0),
		"crew2_f4_raise": Vector3(89.0, 0, -17.0), "crew3_f0": Vector3(-26.0, 0, 22.0)}}


## Packed to move: the tower's reed bundles, the frame's timbers and the arm lashed along a heavy sledge, the pad
## on top, the rope coiled; the bullfrog hauls it in a breast band, its traces tied to the runners' curled fronts;
## two frogs walk beside.
func _frog_packed(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var L := 64.0
	var W := 24.0
	var x0 := -8.0
	sledge(n, s, L, W, x0)
	for z in [-7.5, -2.5, 2.5, 7.5]:   # the tower's posts, laid down
		bundle(n, Vector3(x0 - 28.0, 5.6, z), Vector3(x0 + 22.0, 5.6, z), 1.8, s, 4, 1.6)
	for z in [-5.0, 5.0]:   # the frame's timbers over them
		n.add_child(beam(Vector3(x0 - 24.0, 9.6, z), Vector3(x0 + 20.0, 9.6, z), 3.8, 3.8, s.dark))
	n.add_child(beam(Vector3(x0 - 30.0, 13.8, 0), Vector3(x0 + 26.0, 13.8, 0), 4.6, 4.6, s.wood))   # the arm
	for x in [x0 - 18.0, x0, x0 + 16.0]:   # lashed down
		n.add_child(ring(2.4, 3.4, s.lash, Vector3(x, 13.8, 0), Vector3(0, 0, 90)))
		n.add_child(rod(Vector3(x, 3.2, -W * 0.5 - 0.4), Vector3(x, 11.0, -6.0), 0.35, 0.35, s.lash))
		n.add_child(rod(Vector3(x, 3.2, W * 0.5 + 0.4), Vector3(x, 11.0, 6.0), 0.35, 0.35, s.lash))
	n.add_child(_box(Vector3(12.0, 2.0, 12.0), s.wicker, Vector3(x0 - 20.0, 17.2, 0)))   # the pad
	n.add_child(_box(Vector3(10.0, 0.6, 10.0), s.team, Vector3(x0 - 20.0, 18.5, 0)))
	n.add_child(ring(2.4, 3.6, s.rope, Vector3(x0 + 8.0, 17.0, 0)))
	# The bullfrog in front, in a breast band; the traces from the runners' curled fronts to the band.
	var bx := x0 + L * 0.5 + 24.0
	var bk := 0.9
	bullfrog(n, Vector3(bx, 0, 0), bk)
	var band_at := Vector3(bx, 10.0 * bk, 0)
	n.add_child(ring(10.6 * bk, 11.6 * bk, s.lash, band_at, Vector3(0, 0, 90), Vector3(0.86, 1.0, 1.0)))
	for side in [1, -1]:
		n.add_child(rod(Vector3(x0 + L * 0.5, 6.0, W * 0.5 * side), band_at + Vector3(0, 0, 11.1 * bk * side), 0.4, 0.4, s.rope, false))
	pennant(n, s, Vector3(x0 - 34.0, 3.2, -W * 0.5), 14.0, 4.5)
	return {"node": n, "sockets": {"crew0_f0": Vector3(x0 + 6.0, 0, 21.0), "crew1_f0": Vector3(x0 - 18.0, 0, -21.0)}}


## The tarantula's markings (D-129, Dominic: its back was "too single-colour"): a pale rim round the carapace
## with dark rays from its middle, pale chevrons down the abdomen's back (front and rear of the harness band),
## and tufts of pale hair: along the abdomen's flanks and on each leg's upper segment. The orange knees stay.
func tarantula_pattern(n: Node3D, C: Vector3, A: Vector3, legs: Array) -> void:
	var pale := plain(Color("#e6d2a4"))
	var straw := surf("rat_fur", Color(1.1, 0.95, 0.7), 3.0)
	var ray := plain(Color("#141012"))
	# The carapace: a straw-coloured cap over the dark fur, its pale rim showing all round, dark rays.
	n.add_child(blob(Vector3(15.6, 6.8, 13.6), pale, C + Vector3(0, -1.0, 0)))
	n.add_child(blob(Vector3(12.0, 7.4, 10.4), straw, C + Vector3(0.5, 0.4, 0)))
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var tip := C + Vector3(cos(a) * 9.0, 4.6, sin(a) * 8.0)
		n.add_child(rod(C + Vector3(0.5, 7.9, 0), tip, 0.55, 0.3, ray))
	n.add_child(blob(Vector3(2.2, 0.8, 1.6), ray, C + Vector3(0.5, 7.8, 0)))   # the fovea
	# The abdomen (radii 19 x 14 x 16, tipped -10 degrees): a point on its skin, and its outward normal.
	var tilt := Basis(Vector3.BACK, deg_to_rad(-10.0))
	var R := Vector3(19.0, 14.0, 16.0)
	var skin := func(lx: float, lz: float, lift: float) -> Array:
		var ly := R.y * sqrt(maxf(0.0, 1.0 - pow(lx / R.x, 2) - pow(lz / R.z, 2)))
		var local := Vector3(lx, ly, lz)
		var nrm := Vector3(lx / (R.x * R.x), ly / (R.y * R.y), lz / (R.z * R.z)).normalized()
		return [A + tilt * (local + nrm * lift), (tilt * nrm).normalized()]
	# Chevrons: pale bars in a V pointing forward, ahead of the harness band and two behind it.
	for lx in [8.5, -7.5, -12.5]:
		for side in [1, -1]:
			var a: Array = skin.call(lx + 2.6, 0.6 * side, 0.3)
			var b: Array = skin.call(lx - 1.4, 7.0 * side, 0.3)
			n.add_child(rod(a[0], b[0], 1.4, 1.1, pale))
	# Bands: pale stripes right across the back, between the chevrons.
	for lx in [4.0, -3.5, -10.0]:
		var prev: Array = skin.call(lx, -13.0, 0.2)
		for t in range(1, 9):
			var nxt: Array = skin.call(lx, -13.0 + t * 26.0 / 8.0, 0.2)
			n.add_child(rod(prev[0], nxt[0], 0.75, 0.75, straw))
			prev = nxt
	var spine: Array = skin.call(-15.5, 0.0, 0.3)
	n.add_child(blob(Vector3(2.0, 0.6, 1.6), pale, spine[0]))   # a pale spot over the spinnerets
	# Hair: pale tufts bristling off the abdomen's flanks and back.
	for k in 18:
		var lx := 12.0 - (k % 9) * 3.0
		var lz := (10.0 + (k % 3) * 2.0) * (1 if k < 9 else -1)
		var at: Array = skin.call(lx, lz, 0.0)
		n.add_child(rod(at[0], at[0] + at[1] * 2.8 + Vector3(-0.8, 0.4, 0), 0.55, 0.1, pale if k % 2 == 0 else straw))
	# ...and on each leg's upper segment (hip to knee), standing out from it.
	for leg in legs:
		for side in [1, -1]:
			var hip := Vector3(leg[0], 17.0, 9.0 * side)
			var knee := Vector3(leg[0] + (leg[1] - leg[0]) * 0.55, 34.0, 24.0 * side)
			for t in [0.35, 0.65]:
				var at: Vector3 = hip.lerp(knee, t)
				n.add_child(rod(at + Vector3(0, 2.6, 0), at + Vector3(-0.6, 5.4, 0.8 * side), 0.6, 0.1, pale))
			# A pale band round the shin, below the orange knee (the lower leg as _tarantula draws it).
			var ankle := Vector3(leg[0] + (leg[2] - leg[0]) * 0.85, 12.0, 36.0 * side)
			n.add_child(blob(Vector3(2.7, 2.7, 2.7), pale, knee.lerp(ankle, 0.45)))


# ------------------------------------------------------------------ in play (D-129)

func _beast_elephant(s: Dictionary) -> Dictionary: return _elephant(s, true, true)
func _beast_boar(s: Dictionary) -> Dictionary: return _war_boar(s, true, true)
func _beast_tarantula(s: Dictionary) -> Dictionary: return _tarantula(s, false, true, true)
func _beast_heron(s: Dictionary) -> Dictionary: return _heron(s, true)
func _beast_mantis(s: Dictionary) -> Dictionary: return _mantis(s, true)

# A war beast's legs and head in play, baked cut by its body (parts.json siege.beast.<kind>: "cut", "legs",
# "beast": {"head"}): each leg built for the near side from its hip at the origin (UnitModels.leg_basis turns
# it to its own), each head from its turning point. UnitModels builds them here (UnitModels.build).
func _leg_beast_elephant(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	elephant_leg(n, Vector3.ZERO, 1.0, _elephant_mats())
	return {"node": n}
func _head_beast_elephant(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	elephant_head(n, Vector3.ZERO, _elephant_mats())
	return {"node": n, "sockets": {"top": Vector3(6.0, 9.0, 0)}}
func _leg_beast_boar(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	boar_leg(n, Vector3.ZERO, 1.0, true, _boar_mats())
	return {"node": n}
func _leg_beast_boar_hind(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	boar_leg(n, Vector3.ZERO, 1.0, false, _boar_mats())
	return {"node": n}
func _head_beast_boar(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	boar_head(n, Vector3.ZERO, _boar_mats())
	return {"node": n, "sockets": {"top": Vector3(6.0, 10.0, 0)}}
func _leg_beast_heron(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	heron_leg(n, Vector3.ZERO, 1.0)
	return {"node": n}
func _head_beast_heron(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	heron_neck(n, Vector3.ZERO)
	return {"node": n, "sockets": {"top": Vector3(10.0, 29.0, 0)}}
## A walking leg, from its hip at the origin straight out to the near side (+z): up to a high knee, down to the foot.
func _leg_beast_mantis(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	limb(n, [Vector3.ZERO, Vector3(0, 12.0, 14.0), Vector3(0, -21.2, 20.0)], [1.8, 1.4, 0.8], surf("chitin", Color("#4a7028"), 4.0))
	return {"node": n}
func _head_beast_mantis(_c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var green := surf("chitin", Color("#6a9a3a"), 5.0)
	green.roughness = 0.5
	mantis_fore(n, Vector3.ZERO, green, surf("chitin", Color("#4a7028"), 4.0))
	return {"node": n, "sockets": {"top": Vector3(15.0, 24.0, 0)}}
func _sling_in_play(s: Dictionary, _c: Dictionary) -> Dictionary: return _great_sling(s)
func _packed_in_play(s: Dictionary, _c: Dictionary) -> Dictionary: return _great_packed(s)
func _frog_sling_in_play(s: Dictionary, _c: Dictionary) -> Dictionary: return _frog_sling(s)
func _frog_throw_in_play(s: Dictionary, _c: Dictionary) -> Dictionary: return _frog_sling(s, true)
func _frog_packed_in_play(s: Dictionary, _c: Dictionary) -> Dictionary: return _frog_packed(s)


const BESIDE_GAP := 11.0   # a member walking beside a war beast: this far out past its widest point (a centaur's half width and some)


## A war beast's riders ride on top ("crew<n>_f0_top"); a crew too big to ride (a centaur: its horse half)
## walks beside it instead, on the "crew<n>_f0_wide" sockets this adds on the ground, out past the beast's
## widest point on the side its rider sat (the second of a pair on the far side). UnitView.engine_sockets.
## Its legs (baked apart in play) count: a leg part per hip, turned to its own side, put on for the measure.
func _beside(spec: Dictionary, kind: String, colours: Dictionary) -> Dictionary:
	var zmax := 0.0
	for q in _cloud(spec.node):
		zmax = maxf(zmax, absf(q.z))
	for a in spec.get("anchors", []):
		var leg: Node3D = call("_leg_beast_%s%s" % [kind, "_hind" if a.size() > 4 and a[4] else ""], colours).node
		leg.transform = Transform3D(leg_basis(a, true), a[0])
		for q in _cloud(leg):
			zmax = maxf(zmax, absf(q.z))   # (_cloud puts the leg on: its own transform)
		leg.free()
	var k := 0
	var names: Array = spec.sockets.keys()
	names.sort()
	for name in names:
		if not name.ends_with("_top"):
			continue
		var at: Vector3 = spec.sockets[name]
		var side := signf(at.z) if absf(at.z) > 0.5 else (1.0 if k % 2 == 0 else -1.0)
		spec.sockets[name.trim_suffix("_top") + "_wide"] = Vector3(at.x, 0, side * (zmax + BESIDE_GAP))
		k += 1
	return spec


# ------------------------------------------------------------------ siege shots (Dominic: "the rocks they throw look really bad")
# What the engines throw, baked like any part so combat_fx.gd draws them from the atlas: "shot.<look>"
# (data/siege_shots.json says which engine throws which, its spin, its impact). Built round their middle (they fly).
# The great sling's are the same things bigger. In part units: a soldier is about 35 tall.

const SHOT_SIZE := {"": 1.4, "big": 2.3}


static func _shot_id(id: String) -> bool:
	return id.begins_with("shot.")


func shot_model(id: String, colours: Dictionary) -> Dictionary:
	var name := id.trim_prefix("shot.")
	var big := name.ends_with("_big")
	var k: float = SHOT_SIZE["big" if big else ""]
	var n := Node3D.new()
	match name.trim_suffix("_big"):
		"boulder": shot_boulder(n, k)
		"cheese": shot_cheese(n, k)
		"acorn": shot_acorn(n, k)
		"bone": shot_bone(n, k)
		"clay": shot_clay(n, k)
		"bolt": shot_bolt(n)
		_: assert(false, "no shot model %s" % id)
	return {"node": n}


## A rough boulder: a lumpy core of grey stone, knobs and flat facets, a paler chipped face, moss in a crack.
func shot_boulder(n: Node3D, k: float) -> void:
	var rock := surf("rock", Color(0.92, 0.9, 0.84), 2.5)
	var dark := surf("rock", Color(0.6, 0.58, 0.54), 2.5)
	var pale := surf("rock", Color(1.15, 1.12, 1.05), 2.5)
	n.add_child(blob(Vector3(3.3, 2.9, 3.1) * k, rock, Vector3.ZERO, Vector3(10, 25, 15)))
	var knobs := [[Vector3(1.0, 0.6, 0.4), 1.8, rock], [Vector3(-0.8, 0.2, 0.9), 1.6, dark], [Vector3(0.1, -0.9, -0.6), 1.7, dark],
		[Vector3(-0.3, 0.9, -0.5), 1.5, pale], [Vector3(0.7, -0.4, -0.9), 1.3, rock]]
	for kn in knobs:
		n.add_child(blob(Vector3.ONE * float(kn[1]) * k, kn[2], (kn[0] as Vector3).normalized() * 2.2 * k))
	n.add_child(blob(Vector3(1.6, 0.4, 1.2) * k, plain(Color("#5a6a32")), Vector3(-0.6, 2.4, 1.6) * k))   # moss in a crack


## The rats' cheese: a fat wedge of yellow cheese, the rind darker, holes on its faces.
func shot_cheese(n: Node3D, k: float) -> void:
	var cheese := surf("cheese", Color.WHITE, 3.0)
	var rind := surf("cheese", Color(0.82, 0.62, 0.3), 3.0)
	n.add_child(slab([Vector2(-3.4, -2.0), Vector2(3.6, -2.0), Vector2(-3.4, 2.6)].map(func(v): return v * k), 4.2 * k, cheese))
	n.add_child(_box(Vector3(0.6, 4.6, 4.3) * k, rind, Vector3(-3.6, 0.3, 0) * k))   # the rind on its back
	var hole := plain(Color("#b88a28"))
	for h in [[Vector3(-1.2, -0.6, 2.15), 0.8], [Vector3(0.8, -1.2, 2.15), 0.6], [Vector3(-2.2, 1.0, 2.15), 0.55], [Vector3(-0.6, -0.8, -2.15), 0.75]]:
		n.add_child(blob(Vector3(h[1], h[1], 0.3) * k, hole, (h[0] as Vector3) * k))


## The forest's acorn: a glossy brown nut in its scaly cap, a stalk.
func shot_acorn(n: Node3D, k: float) -> void:
	n.add_child(blob(Vector3(2.6, 3.4, 2.6) * k, surf("wood_grain", Color(0.95, 0.68, 0.4), 3.0), Vector3(0, -0.8, 0) * k))
	n.add_child(blob(Vector3(0.6, 0.5, 0.6) * k, plain(Color("#4a3018")), Vector3(0, -4.0, 0) * k))   # the tip
	n.add_child(dome(Vector3(3.0, 2.0, 3.0) * k, surf("acorn_cap", Color.WHITE, 3.0), Vector3(0, 1.2, 0) * k))
	n.add_child(rod(Vector3(0, 3.0, 0) * k, Vector3(0.6, 4.4, 0) * k, 0.45 * k, 0.35 * k, plain(Color("#5a4028"))))


## The spiders' bone ball: a knot of old bones and a skull bound in grey silk.
func shot_bone(n: Node3D, k: float) -> void:
	var bone := surf("bone", Color.WHITE, 3.0)
	var silk := surf("cloth", Color("#cfc8d8"), 2.0)
	n.add_child(blob(Vector3.ONE * 2.6 * k, silk, Vector3.ZERO))
	for b in [[Vector3(-3.0, 0.6, 1.0), Vector3(3.0, -0.4, 1.4)], [Vector3(-1.0, -2.6, -1.6), Vector3(1.4, 2.8, -1.2)], [Vector3(0.6, 0.4, -3.0), Vector3(-0.4, -0.2, 3.0)]]:
		n.add_child(rod(b[0] * k, b[1] * k, 0.55 * k, 0.55 * k, bone))
		for end in b:
			n.add_child(blob(Vector3.ONE * 0.85 * k, bone, end * k))   # the knuckles
	n.add_child(blob(Vector3(1.7, 1.6, 1.5) * k, bone, Vector3(1.6, 1.4, 0.6) * k))   # a skull
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.4, 0.45, 0.3) * k, plain(Color("#1a1418")), Vector3(2.9, 1.6, 0.6 + 0.6 * side) * k))
	for rot in [Vector3(90, 0, 0), Vector3(0, 0, 90), Vector3(45, 45, 0)]:   # the silk binding
		n.add_child(ring(2.5 * k, 2.8 * k, silk, Vector3.ZERO, rot, Vector3(1, 0.5, 1)))


## The frogs' clay pot: a round fired-clay ball, cord tied round it in a cross, a stopper of reed.
func shot_clay(n: Node3D, k: float) -> void:
	var clay := surf("bld_daub", Color(1.05, 0.62, 0.42), 3.0)
	n.add_child(blob(Vector3(3.0, 2.8, 3.0) * k, clay, Vector3.ZERO))
	var cord := plain(Color("#4a3a2a"))
	n.add_child(ring(2.85 * k, 3.15 * k, cord, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 0.4, 1)))
	n.add_child(ring(2.85 * k, 3.15 * k, cord, Vector3.ZERO, Vector3(0, 0, 90), Vector3(1, 0.4, 1)))
	n.add_child(cone(0.7 * k, 0.9 * k, 1.2 * k, surf("thatch", Color.WHITE, 2.0), Vector3(0, 2.9, 0) * k))


## The bolt thrower's bolt: a long ash shaft (along x), a heavy iron head, three stiff vanes.
func shot_bolt(n: Node3D) -> void:
	var shaft := surf("wood_grain", Color(1.0, 0.9, 0.72), 4.0)
	n.add_child(rod(Vector3(-9.0, 0, 0), Vector3(7.0, 0, 0), 0.8, 0.8, shaft))
	n.add_child(cone(0.0, 1.5, 4.0, surf("iron", Color.WHITE, 2.0), Vector3(8.6, 0, 0), Vector3(0, 0, -90), 8))
	n.add_child(cone(0.7, 0.7, 0.8, surf("iron", Color(0.7, 0.7, 0.7), 2.0), Vector3(6.8, 0, 0), Vector3(0, 0, 90), 8))   # the socket
	var vane := surf("leather", Color(0.95, 0.88, 0.75), 2.0)
	for a in [0.0, 120.0, 240.0]:
		var d := Vector3(0, cos(deg_to_rad(a)), sin(deg_to_rad(a)))
		var v := slab([Vector2(0, 0), Vector2(-4.0, 0), Vector2(-4.6, 1.8), Vector2(-1.2, 1.2)], 0.25, vane)
		v.basis = Basis(Vector3.RIGHT, deg_to_rad(a))
		v.position = Vector3(-4.6, 0, 0) + d * 0.3
		n.add_child(v)
