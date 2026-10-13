extends "res://scenes/art_pixel/siege_models.gd"
## Milestone 13 concept rounds (D-080: options first), staged by data/later/m13_concepts.json and drawn
## by tests/sheets/{war_beasts_wb1,sapper_sp1,great_sling_gs1,war_beasts_wb2,great_sling_gs2}.json. Nothing here is in play: the
## sapper holds a placeholder charge, the great sling wears the catapult, war beasts aren't built.
## Notes and questions: docs/concepts/{war_beasts,sapper,great_sling}/README.md.
##   WB1  war beasts, two options a family, as one baked body with riders on top (the race's own
##        people on "crew<n>_top" sockets, as on the siege beasts): concept.wb1_<opt>_<take>
##   SP1  the sapper's charge, held in the hand: concept.sp1_<name> (slot hand_r)
##   GS1  the great sling, set up and packed: concept.gs1_<opt>_<take>
##   WB2  war beasts round 2 (D-127): the rats' war boar, the spiders' tarantula alone, a crayfish and a
##        heron for the frogs, a mantis and a centipede for the beetles: concept.wb2_<beast>
##   GS2  the great sling round 2 (D-127), siege-weight, every take: concept.gs2_<take>
## Same frame as the engines: x forward, y up, z towards the viewer's side, standing on y = 0.


# ================================================================== WB1: war beasts

func _concept_wb1_a_timber(c: Dictionary) -> Dictionary: return _elephant(_style("timber", c), true)
func _concept_wb1_b_timber(c: Dictionary) -> Dictionary: return _elephant(_style("timber", c), false)
func _concept_wb1_a_frog(c: Dictionary) -> Dictionary: return _toad_howdah(_style("frog", c))
func _concept_wb1_b_frog(c: Dictionary) -> Dictionary: return _toad_spiked(_style("frog", c))
func _concept_wb1_a_junk(c: Dictionary) -> Dictionary: return _big_beast(_style("junk", c), "capybara", 2.0, Color("#8a6a48"), Color("#5a4430"), true)
func _concept_wb1_b_junk(c: Dictionary) -> Dictionary: return _big_beast(_style("junk", c), "boar", 2.1, Color("#4a3a30"), Color("#2e241e"), false)
func _concept_wb1_a_forest(c: Dictionary) -> Dictionary: return _stag(_style("forest", c))
func _concept_wb1_b_forest(c: Dictionary) -> Dictionary: return _rhino(_style("forest", c))
func _concept_wb1_a_spooky(c: Dictionary) -> Dictionary: return _big_beast(_style("spooky", c), "spider", 2.1, Color("#4a3628"), Color("#c87a3a"), true)
func _concept_wb1_b_spooky(c: Dictionary) -> Dictionary: return _big_beast(_style("spooky", c), "spider", 2.1, Color("#22202a"), Color("#8a2a2a"), false)


## A howdah: a railed platform at `at` (its floor's middle), team cloths down both sides; returns the
## riders' sockets (two on top).
func howdah(n: Node3D, s: Dictionary, at: Vector3, L: float, W: float) -> Dictionary:
	n.add_child(_box(Vector3(L, 1.4, W), s.dark, at))
	for x in [-L * 0.5 + 0.6, L * 0.5 - 0.6]:
		for side in [1, -1]:
			n.add_child(rod(at + Vector3(x, 0, W * 0.5 * side), at + Vector3(x, 5.0, W * 0.5 * side), 0.45, 0.45, s.dark))
	for side in [1, -1]:
		n.add_child(rod(at + Vector3(-L * 0.5, 5.0, W * 0.5 * side), at + Vector3(L * 0.5, 5.0, W * 0.5 * side), 0.4, 0.4, s.dark))
		n.add_child(_box(Vector3(L * 0.8, 8.0, 0.4), s.team, at + Vector3(0, -4.0, (W * 0.5 + 0.3) * side), Vector3(10 * side, 0, 0)))
	for x in [-L * 0.5, L * 0.5]:
		n.add_child(rod(at + Vector3(x, 5.0, -W * 0.5), at + Vector3(x, 5.0, W * 0.5), 0.4, 0.4, s.dark))
	return {"crew0_f0_top": at + Vector3(L * 0.2, 0.7, W * 0.15), "crew1_f0_top": at + Vector3(-L * 0.25, 0.7, -W * 0.15)}


## Humans: a war elephant, grey and wrinkled, tusks capped in bronze, ears out. a: a howdah with two
## riders; b: armoured (a team-trimmed caparison, a brow plate), one rider on its neck.
func _elephant(s: Dictionary, with_howdah: bool) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", Color(0.62, 0.6, 0.58), 6.0)
	var dark := surf("hide", Color(0.45, 0.43, 0.42), 6.0)
	var ivory := plain(Color("#ece2c8"))
	var bronze := surf("bronze", Color.WHITE, 3.0)
	for leg in [[13.0, 1], [-13.0, 1]]:
		for side in [1, -1]:
			var x: float = leg[0] + (2.0 if side > 0 else -1.0)
			n.add_child(rod(Vector3(x, 30.0, 8.5 * side), Vector3(x, 2.0, 9.0 * side), 5.6, 5.0, hide))
			n.add_child(cone(5.6, 5.8, 2.4, dark, Vector3(x, 1.2, 9.0 * side)))   # the foot
	n.add_child(blob(Vector3(26.0, 16.0, 14.5), hide, Vector3(0, 36.0, 0)))
	n.add_child(blob(Vector3(10.0, 12.0, 12.0), hide, Vector3(18.0, 40.0, 0)))   # the shoulders
	n.add_child(blob(Vector3(10.0, 10.5, 9.5), hide, Vector3(28.0, 41.0, 0)))   # the head
	n.add_child(blob(Vector3(5.0, 4.0, 8.0), dark, Vector3(30.0, 49.0, 0)))   # the brow
	var trunk := [Vector3(35.0, 38.0, 0), Vector3(39.0, 30.0, 0), Vector3(40.5, 20.0, 0), Vector3(40.0, 11.0, 0), Vector3(42.5, 6.0, 0)]
	var tr := [4.2, 3.4, 2.8, 2.2, 1.6]
	for k in range(1, trunk.size()):
		n.add_child(rod(trunk[k - 1], trunk[k], tr[k - 1], tr[k], hide))
	for side in [1, -1]:
		var ear := cone(9.5, 9.5, 0.8, dark, Vector3(23.0, 42.0, 11.0 * side), Vector3(90, 0, 0), 20)
		ear.scale = Vector3(0.8, 1.0, 1.15)
		n.add_child(ear)
		n.add_child(rod(Vector3(34.0, 34.0, 4.0 * side), Vector3(43.0, 30.0, 6.0 * side), 1.4, 0.7, ivory))   # tusks
		n.add_child(cone(0.4, 1.2, 2.2, bronze, Vector3(43.5, 29.8, 6.1 * side), Vector3(0, 0, -75)))
		n.add_child(blob(Vector3(1.1, 1.1, 0.8), plain(Color("#1a1412")), Vector3(32.5, 44.0, 6.8 * side)))
	n.add_child(rod(Vector3(-25.0, 38.0, 0), Vector3(-29.0, 22.0, 0), 1.0, 0.6, hide))   # the tail
	if with_howdah:
		var sk := howdah(n, s, Vector3(-3.0, 52.5, 0), 22.0, 18.0)
		n.add_child(_box(Vector3(26.0, 0.6, 30.0), s.trim, Vector3(-3.0, 51.6, 0)))   # a saddle cloth in the culture's colour
		return {"node": n, "sockets": sk}
	# Armoured: a caparison down its flanks (team border), a bronze brow plate, a rider on the neck.
	for side in [1, -1]:
		n.add_child(_box(Vector3(30.0, 13.0, 0.5), s.trim, Vector3(-1.0, 40.0, 15.0 * side), Vector3(8 * side, 0, 0)))
		n.add_child(_box(Vector3(30.0, 1.8, 0.6), s.team, Vector3(-1.0, 33.5, 15.9 * side), Vector3(8 * side, 0, 0)))
	n.add_child(dome(Vector3(5.5, 3.0, 8.5), bronze, Vector3(30.5, 49.5, 0)))
	n.add_child(_box(Vector3(10.0, 1.0, 12.0), s.dark, Vector3(17.0, 51.5, 0)))
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(17.0, 52.2, 0)}}


## Frogs: the giant toad (the bolt thrower's), a howdah on its back with two riders.
func _toad_howdah(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	giant_toad(n, s)
	var sk := howdah(n, s, Vector3(-4.0, 34.0, 0), 18.0, 16.0)
	return {"node": n, "sockets": sk}


## Frogs, b: the giant toad in war harness: bark plates over its back with thorns, a team cloth, one
## rider with a goad.
func _toad_spiked(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	giant_toad(n, s)
	var bark := surf("bark_plate", Color(0.8, 0.7, 0.58), 6.0)
	for k in 3:
		n.add_child(dome(Vector3(7.0, 2.5, 13.0), bark, Vector3(-12.0 + k * 8.0, 31.5 - k * 0.5, 0)))
		for side in [1, -1]:
			n.add_child(cone(0.1, 1.2, 4.0, plain(Color("#3a2a1c")), Vector3(-12.0 + k * 8.0, 33.5, 6.0 * side), Vector3(25 * side, 0, 0), 8))
	for side in [1, -1]:
		n.add_child(_box(Vector3(14.0, 7.0, 0.4), s.team, Vector3(-4.0, 24.0, 17.5 * side), Vector3(25 * side, 0, 0)))
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(6.0, 33.0, 0)}}


## A creature from its game parts (body, head, legs at its hips), grown k times, in its own colours;
## for the rats' capybara and boar and the spiders' tarantula. Returns [node, seat height, half length].
func beast_parts(kind: String, k: float, skin: Color, skin2: Color, c: Dictionary) -> Array:
	var cc := c.duplicate()
	cc.skin = skin
	cc.skin2 = skin2
	var n := Node3D.new()
	n.scale = Vector3.ONE * k
	var body: Dictionary = build("body." + kind, cc)
	n.add_child(body.node)
	if body.has("front"):
		n.add_child(body.front)
	if kind != "spider":
		var head: Dictionary = build("head." + kind, cc)
		head.node.position = body.sockets.head
		n.add_child(head.node)
	for a in body.anchors:
		var leg: Dictionary = build("leg." + kind, cc)
		leg.node.position = a[0]
		leg.node.basis = leg_basis(a, true)
		n.add_child(leg.node)
	var seat: Vector3 = body.sockets.get("seat", Vector3(0, 20, 0))
	return [n, seat * k]


## Rats' capybara or boar, spiders' tarantula, grown into a war beast: a howdah with two riders (a),
## or a saddle and one rider (b).
func _big_beast(s: Dictionary, kind: String, k: float, skin: Color, skin2: Color, with_howdah: bool) -> Dictionary:
	var n := Node3D.new()
	var made := beast_parts(kind, k, skin, skin2, {"team": s.team.albedo_color, "cloth": Color("#8a6a48"), "cloth2": Color("#c8b48a")})
	n.add_child(made[0])
	var seat: Vector3 = made[1]
	if with_howdah:
		return {"node": n, "sockets": howdah(n, s, seat + Vector3(-2.0, 1.0, 0), 18.0, 15.0)}
	n.add_child(_box(Vector3(12.0, 0.8, 16.0), s.team, seat + Vector3(0, 0.2, 0)))
	n.add_child(_box(Vector3(8.0, 1.6, 9.0), s.dark, seat + Vector3(0, 1.0, 0)))
	return {"node": n, "sockets": {"crew0_f0_top": seat + Vector3(0, 1.9, 0)}}


## Forest beetles, a: a giant stag beetle (the ram's giant beetle with great antlered jaws instead of
## horns), a howdah on its wing cases.
func _stag(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var b := giant_beetle(n, s)
	var dark := surf("chitin", Color("#3a2016"), 4.0)
	for side in [1, -1]:   # the mandibles, out and forward, a tine each
		var pts := [Vector3(33, 18, 4.0 * side), Vector3(44, 21, 10.0 * side), Vector3(54, 23, 8.0 * side), Vector3(60, 22, 2.0 * side)]
		for k in range(1, pts.size()):
			b.add_child(rod(pts[k - 1], pts[k], 2.4 - k * 0.5, 2.2 - k * 0.55, dark))
		b.add_child(rod(Vector3(47, 22, 9.6 * side), Vector3(49, 27, 9.0 * side), 1.0, 0.4, dark))
	var sk := howdah(b, s, Vector3(-6.0, 37.6, 0), 20.0, 15.0)
	for name in sk:
		sk[name] += Vector3(0, -BEETLE_DROP, 0)
	return {"node": n, "sockets": sk}


## Forest beetles, b: the rhinoceros beetle of their ram, as a war beast: a howdah and two riders.
func _rhino(s: Dictionary) -> Dictionary:
	var spec := _ram_ridden(s, {"team": s.team.albedo_color})
	return spec


# ================================================================== SP1: the sapper's charge
# Each is held up in the fist, not hanging below it (a pot swinging at the hip cut through the body
# and a beetle's or spider's legs in the blow: the placement check).

func _held(n: Node3D) -> Dictionary:
	var w := Node3D.new()
	n.position.y = 4.0
	w.scale = Vector3.ONE * 0.8
	w.add_child(n)
	return {"node": w}

## A: a clay fire pot on a rope sling, a burning rag in its neck (pitch and naphtha: a bronze-age bomb).
func _concept_sp1_firepot(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var clay := surf("bld_daub", Color(1.05, 0.62, 0.42), 6.0)
	n.add_child(rod(Vector3(0, 0.5, 0), Vector3(0, -2.5, 0), 0.25, 0.25, plain(ROPE), false))
	n.add_child(blob(Vector3(3.0, 3.2, 3.0), clay, Vector3(0, -5.5, 0)))
	n.add_child(cone(0.9, 1.4, 1.6, clay, Vector3(0, -2.3, 0)))
	n.add_child(ring(1.2, 1.6, plain(ROPE), Vector3(0, -3.4, 0)))
	n.add_child(blob(Vector3(0.9, 1.2, 0.9), plain(Color("#c8b48a")), Vector3(0.4, -1.1, 0)))   # the rag
	n.add_child(blob(Vector3(1.0, 1.9, 1.0), glow(Color("#ff9a30")), Vector3(0.6, 0.6, 0)))   # its flame
	n.add_child(blob(Vector3(0.5, 1.0, 0.5), glow(Color("#ffe08a")), Vector3(0.6, 0.2, 0.3)))
	return _held(n)


## B: a leather satchel charge, bound with cord, a long fuse coiled at its neck, a smoking match.
func _concept_sp1_satchel(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(0.75, 0.55, 0.38), 3.0)
	n.add_child(rod(Vector3(0, 0.5, 0), Vector3(0, -1.8, 0), 0.3, 0.3, leather, false))
	n.add_child(_box(Vector3(4.6, 5.0, 3.0), leather, Vector3(0, -4.6, 0)))
	for y in [-3.2, -6.0]:
		n.add_child(_box(Vector3(4.8, 0.5, 3.2), plain(ROPE), Vector3(0, y, 0)))
	n.add_child(ring(0.8, 1.3, plain(Color("#3a2a1a")), Vector3(1.6, -1.8, 1.0), Vector3(90, 0, 0)))   # the coiled fuse
	n.add_child(rod(Vector3(2.0, -1.8, 1.6), Vector3(2.8, 0.6, 2.0), 0.18, 0.18, plain(Color("#3a2a1a")), false))
	n.add_child(blob(Vector3(0.5, 0.5, 0.5), glow(Color("#ffb040")), Vector3(2.8, 0.8, 2.0)))
	return _held(n)


## Frogs: a bundle of reed rockets (fireworks: roster-template's "frogs with fireworks"), paper caps,
## a lit fuse.
func _concept_sp1_rockets(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var reed := surf("reed_stalk", Color(0.95, 0.9, 0.7), 4.0)
	for k in 5:
		var a := TAU * k / 5.0
		var o := Vector3(cos(a) * 1.0, 0, sin(a) * 1.0)
		n.add_child(rod(Vector3(0, -6.0, 0) + o, Vector3(0, 3.0, 0) + o, 0.55, 0.55, reed))
		n.add_child(cone(0.1, 0.6, 1.4, plain([Color("#d04040"), Color("#e8c040"), Color("#4080d0")][k % 3]), Vector3(0, 3.9, 0) + o, Vector3.ZERO, 8))
	n.add_child(ring(1.4, 1.9, plain(Color("#4a3a2a")), Vector3(0, -1.0, 0)))
	n.add_child(rod(Vector3(0, -6.0, 0), Vector3(0.8, -8.0, 0.5), 0.15, 0.15, plain(Color("#3a2a1a")), false))
	n.add_child(blob(Vector3(0.5, 0.5, 0.5), glow(Color("#ffb040")), Vector3(0.8, -8.2, 0.5)))
	return _held(n)


## Rats (D-116, human scale): a rusty can of lamp oil with a rag stuffed in its spout, alight.
func _concept_sp1_oilcan(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("bld_tin", Color(0.72, 0.5, 0.36), 6.0)
	n.add_child(rod(Vector3(0, 0.5, 0), Vector3(0, -1.5, 0), 0.3, 0.3, surf("iron", Color(0.6, 0.6, 0.6), 3.0), false))   # the handle
	n.add_child(cone(2.4, 2.6, 5.2, tin, Vector3(0, -4.4, 0), Vector3.ZERO, 14))
	n.add_child(ring(2.3, 2.7, surf("iron", Color(0.55, 0.5, 0.45), 3.0), Vector3(0, -2.4, 0)))
	n.add_child(rod(Vector3(1.6, -2.4, 0), Vector3(3.2, -0.8, 0), 0.5, 0.35, tin))   # the spout
	n.add_child(blob(Vector3(0.7, 0.9, 0.7), plain(Color("#c8b48a")), Vector3(3.4, -0.4, 0)))
	n.add_child(blob(Vector3(0.9, 1.6, 0.9), glow(Color("#ff9a30")), Vector3(3.6, 0.9, 0)))
	return _held(n)


## Beetles: a bombardier's gland, a swollen amber sac of stinging brew sealed with wax, a wick.
func _concept_sp1_gland(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var sac := surf("chitin", Color("#d8a040"), 4.0)
	sac.roughness = 0.2
	n.add_child(rod(Vector3(0, 0.5, 0), Vector3(0, -1.6, 0), 0.25, 0.25, plain(ROPE), false))
	n.add_child(blob(Vector3(2.8, 3.6, 2.8), sac, Vector3(0, -5.0, 0)))
	n.add_child(blob(Vector3(1.2, 0.8, 1.2), plain(Color("#6a4a20")), Vector3(0, -1.6, 0)))   # the wax seal
	n.add_child(blob(Vector3(1.4, 2.0, 1.4), glow(Color("#c8e060")), Vector3(0.6, -5.4, 1.4)))   # it glows through
	return _held(n)


## Spiders: a black egg sac wound in silk, ticking with something inside, a silk wick.
func _concept_sp1_eggsac(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, 0.5, 0), Vector3(0, -1.6, 0), 0.2, 0.2, plain(Color("#e8e4f0")), false))
	n.add_child(blob(Vector3(3.0, 3.4, 3.0), plain(Color("#24202a")), Vector3(0, -4.8, 0)))
	for k in 3:
		n.add_child(ring(2.9, 3.2, plain(Color("#d8d2e4")), Vector3(0, -4.8, 0), Vector3(0, k * 60.0, 70)))
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), glow(Color("#a0f0c0")), Vector3(1.2, -2.0, 1.4)))
	return _held(n)


# ================================================================== GS1: the great sling

func _concept_gs1_a_timber(c: Dictionary) -> Dictionary: return _traction(_style("timber", c))
func _concept_gs1_a_frog(c: Dictionary) -> Dictionary: return _scaled(_traction(_style("frog", c)), 1.25)
func _concept_gs1_a_junk(c: Dictionary) -> Dictionary: return _traction(_style("junk", c))
func _concept_gs1_a_forest(c: Dictionary) -> Dictionary: return _traction(_style("forest", c))
func _concept_gs1_a_spooky(c: Dictionary) -> Dictionary: return _traction(_style("spooky", c))
func _concept_gs1_b_timber(c: Dictionary) -> Dictionary: return _counterweight(_style("timber", c))
func _concept_gs1_b_frog(c: Dictionary) -> Dictionary: return _scaled(_counterweight(_style("frog", c)), 1.25)
func _concept_gs1_b_junk(c: Dictionary) -> Dictionary: return _counterweight(_style("junk", c))
func _concept_gs1_b_forest(c: Dictionary) -> Dictionary: return _counterweight(_style("forest", c))
func _concept_gs1_b_spooky(c: Dictionary) -> Dictionary: return _counterweight(_style("spooky", c))
func _concept_gs1_a_packed_timber(c: Dictionary) -> Dictionary: return _packed(_style("timber", c), false)
func _concept_gs1_b_packed_timber(c: Dictionary) -> Dictionary: return _packed(_style("timber", c), true)


## A: a traction sling (the "great sling" of the old world: no counterweight): a tall A-frame tower,
## a long beam pivoting on top, the sling hanging from its long end with a stone in it, pull ropes
## from its short end down to three crew who haul together.
func _traction(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var top := 36.0
	for side in [1, -1]:   # the A-frames, on a timber base
		n.add_child(beam(Vector3(-12.0, 1.0, 9.0 * side), Vector3(14.0, 1.0, 9.0 * side), 2.4, 2.0, s.dark))
		n.add_child(beam(Vector3(-9.0, 1.0, 8.0 * side), Vector3(0, top, 4.0 * side), 2.0, 2.0, s.wood))
		n.add_child(beam(Vector3(9.0, 1.0, 8.0 * side), Vector3(0, top, 4.0 * side), 2.0, 2.0, s.wood))
	for x in [-10.0, 12.0]:
		n.add_child(beam(Vector3(x, 1.0, -10.0), Vector3(x, 1.0, 10.0), 2.0, 2.0, s.dark))
	n.add_child(rod(Vector3(0, top, -5.0), Vector3(0, top, 5.0), 1.0, 1.0, s.metal, false))   # the axle
	# The beam: short end forward-down (where the ropes are), long end back-up, cocked to throw.
	var short := Vector3(12.0, top - 7.0, 0)
	var long := Vector3(-30.0, top + 15.0, 0)
	n.add_child(beam(short, long, 2.2, 2.2, s.wood))
	for t in [0.3, 0.7]:
		n.add_child(ring(1.4, 1.9, s.metal, short.lerp(long, t), Vector3(0, 0, 90 - 27)))
	n.add_child(rod(long, long + Vector3(-2.0, -14.0, 0), 0.25, 0.25, s.rope, false))   # the sling's cords
	n.add_child(blob(Vector3(2.2, 1.6, 2.2), surf("leather", Color.WHITE, 2.0), long + Vector3(-2.0, -15.0, 0)))   # its pouch
	n.add_child(blob(Vector3.ONE * 1.9, s.ammo, long + Vector3(-2.0, -14.0, 0)))
	n.add_child(_box(Vector3(10.0, 0.4, 3.0), s.team, short.lerp(long, 0.55) + Vector3(0, 1.6, 0), Vector3(0, 0, -27)))
	var sockets := {}
	for k in 3:   # the pull ropes, down to the haulers
		var at := Vector3(24.0 + (k % 2) * 3.0, 0, (k - 1) * 6.5)
		n.add_child(rod(short, at + Vector3(-1.0, 13.0, 0), 0.3, 0.3, s.rope, false))
		sockets["crew%d_f4_raise" % k] = at
	return {"node": n, "sockets": sockets}


## B: a counterweight sling: the same tower on a wheeled base, a box of stones on the short end, the
## long arm drawn down to a windlass at the back where two crew wind it.
func _counterweight(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var top := 32.0
	undercarriage(n, s, 30.0, 18.0, 4.5)
	n.add_child(_box(Vector3(30.0, 1.6, 18.0), s.dark, Vector3(0, 9.0, 0)))
	for side in [1, -1]:
		n.add_child(beam(Vector3(-8.0, 9.0, 7.5 * side), Vector3(2.0, top, 5.0 * side), 2.0, 2.0, s.wood))
		n.add_child(beam(Vector3(10.0, 9.0, 7.5 * side), Vector3(2.0, top, 5.0 * side), 2.0, 2.0, s.wood))
	n.add_child(rod(Vector3(2.0, top, -6.0), Vector3(2.0, top, 6.0), 1.0, 1.0, s.metal, false))
	# The arm drawn down: long end low at the back, short end high at the front with the weight box.
	var short := Vector3(9.0, top + 6.0, 0)
	var long := Vector3(-24.0, 12.0, 0)
	n.add_child(beam(short, long, 2.2, 2.2, s.wood))
	n.add_child(_box(Vector3(7.0, 7.0, 8.0), s.dark, short + Vector3(1.0, -4.5, 0)))   # the counterweight box
	n.add_child(_box(Vector3(6.0, 1.2, 7.0), s.ammo, short + Vector3(1.0, -0.6, 0)))   # stones in it
	n.add_child(_box(Vector3(7.4, 2.0, 0.4), s.team, short + Vector3(1.0, -4.5, 4.2)))
	n.add_child(_box(Vector3(7.4, 2.0, 0.4), s.team, short + Vector3(1.0, -4.5, -4.2)))
	n.add_child(blob(Vector3(2.2, 1.6, 2.2), surf("leather", Color.WHITE, 2.0), long + Vector3(-1.0, -1.8, 0)))
	n.add_child(blob(Vector3.ONE * 1.8, s.ammo, long + Vector3(-1.0, -1.0, 0)))
	n.add_child(rod(Vector3(-13.0, 11.0, -6.0), Vector3(-13.0, 11.0, 6.0), 1.4, 1.4, s.dark, false))   # the windlass
	n.add_child(rod(Vector3(-13.0, 11.0, 0), long, 0.3, 0.3, s.rope, false))
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-20.0, 0, 13.0), "crew1_f0_reach": Vector3(-20.0, 0, -13.0)}}


## Packed for the march: the tower laid down on a long wagon, the beam along it, ropes coiled; b keeps
## the weight box (emptied) on its own axle at the tail. Two crew walk beside it.
func _packed(s: Dictionary, weight: bool) -> Dictionary:
	var n := Node3D.new()
	undercarriage(n, s, 36.0, 14.0, 4.5)
	n.add_child(_box(Vector3(38.0, 1.4, 14.0), s.dark, Vector3(0, 9.0, 0)))
	for side in [1, -1]:
		n.add_child(beam(Vector3(-16.0, 11.0, 4.5 * side), Vector3(16.0, 11.0, 4.5 * side), 2.0, 2.0, s.wood))
	n.add_child(beam(Vector3(-22.0, 13.5, 0), Vector3(24.0, 13.5, 0), 2.2, 2.2, s.wood))
	n.add_child(ring(2.0, 3.0, s.rope, Vector3(-8.0, 15.5, 0)))
	n.add_child(ring(2.0, 3.0, s.rope, Vector3(6.0, 15.5, 0)))
	n.add_child(_box(Vector3(14.0, 0.4, 15.0), s.team, Vector3(0, 12.6, 0)))
	if weight:
		n.add_child(_box(Vector3(7.0, 6.0, 8.0), s.dark, Vector3(-15.0, 15.0, 0)))
	return {"node": n, "sockets": {"crew0_f0": Vector3(4.0, 0, 13.0), "crew1_f0": Vector3(-10.0, 0, -13.0)}}


# ================================================================== WB2: war beasts, round 2
# D-127 (Dominic): "we're focusing on capybara too much, doesn't really fit. Boar is better but maybe
# too small. Spider riding a spider seems pointless, better just a tarantula." The elephant stays (WB1
# A). Rats: a war boar much bigger than a pony; spiders: a giant tarantula on its own; frogs and
# beetles: beasts that aren't their siege beasts (the frogs' turtle, snail and toad; the forest's
# rhinoceros beetle). Each is one baked body, its people on "crew<n>_..._top" sockets on a deck.

func _concept_wb2_boar_howdah(c: Dictionary) -> Dictionary: return _war_boar(_style("junk", c), true)
func _concept_wb2_boar_armoured(c: Dictionary) -> Dictionary: return _war_boar(_style("junk", c), false)
func _concept_wb2_tarantula(c: Dictionary) -> Dictionary: return _tarantula(_style("spooky", c), false)
func _concept_wb2_tarantula_crew(c: Dictionary) -> Dictionary: return _tarantula(_style("spooky", c), true)
func _concept_wb2_crayfish(c: Dictionary) -> Dictionary: return _crayfish(_style("frog", c))
func _concept_wb2_heron(c: Dictionary) -> Dictionary: return _heron(_style("frog", c))
func _concept_wb2_mantis(c: Dictionary) -> Dictionary: return _mantis(_style("forest", c))
func _concept_wb2_centipede(c: Dictionary) -> Dictionary: return _centipede(_style("forest", c))


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
func _war_boar(s: Dictionary, with_howdah: bool) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color(0.42, 0.33, 0.27), 5.0)
	var dark := surf("rat_fur", Color(0.26, 0.21, 0.18), 4.0)
	var bristle := surf("mane", Color(0.78, 0.68, 0.54), 3.0)   # grizzled, pale against the coat
	var hoof := plain(Color("#1e1814"))
	var ivory := plain(Color("#f0e6cc"))
	var snout := surf("skin", Color(0.62, 0.45, 0.4), 4.0)
	# Front-heavy on thin legs: the shoulders tower over a smaller rump, the legs taper to trotters.
	for leg in [[18.0, 1.0], [-19.0, -1.0]]:
		for side in [1, -1]:
			var x: float = leg[0]
			limb(n, [Vector3(x, 28.0, 9.0 * side), Vector3(x + 2.5 * leg[1], 12.0, 9.5 * side), Vector3(x + 1.0, 2.6, 9.5 * side)], [6.0, 3.2, 2.3], fur if x > 0 else dark)
			n.add_child(cone(1.8, 2.6, 2.8, hoof, Vector3(x + 1.5, 1.4, 9.5 * side)))
	n.add_child(blob(Vector3(26.0, 13.0, 13.0), fur, Vector3(-4.0, 30.0, 0)))   # the barrel
	n.add_child(blob(Vector3(16.0, 18.0, 15.0), fur, Vector3(12.0, 34.0, 0)))   # the shoulders' hump
	n.add_child(blob(Vector3(11.0, 10.0, 10.0), dark, Vector3(-20.0, 30.0, 0)))   # the rump
	# The head: a long wedge forward and a little down, the snout's disc, great tusks up out of the jaw.
	n.add_child(blob(Vector3(15.0, 10.5, 10.0), fur, Vector3(30.0, 31.0, 0), Vector3(0, 0, -14)))
	n.add_child(rod(Vector3(37.0, 28.0, 0), Vector3(51.0, 22.0, 0), 7.0, 4.6, fur))
	n.add_child(cone(4.8, 4.8, 1.6, snout, Vector3(52.0, 21.6, 0), Vector3(0, 0, -68), 16))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.7, 0.9, 0.6), hoof, Vector3(52.8, 22.0, 1.8 * side)))
		limb(n, [Vector3(45.0, 21.0, 4.5 * side), Vector3(51.0, 22.5, 8.5 * side), Vector3(54.5, 29.0, 9.5 * side), Vector3(52.0, 34.0, 8.5 * side)], [2.3, 1.9, 1.2, 0.4], ivory)
		n.add_child(blob(Vector3(1.3, 1.1, 0.9), plain(Color("#120c08")), Vector3(37.5, 33.0, 7.0 * side)))
		n.add_child(blob(Vector3(0.45, 0.45, 0.4), plain(Color("#d8a040")), Vector3(38.3, 33.4, 7.7 * side)))
		n.add_child(cone(0.4, 3.2, 7.0, dark, Vector3(27.0, 42.0, 6.0 * side), Vector3(25 * side, 0, 20), 8))   # an ear
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
	return {"node": n, "sockets": sockets}


## Spiders: a giant tarantula (legs across ~80 against the spider mount's ~30): a furred carapace and a
## heavy abdomen, eight thick legs with orange-banded knees, fangs and pedipalps, an eye cluster that
## glints. Nobody rides it. a: alone, a silk-and-bone harness and the team banner on its back; b: a
## small crew of two in a basket on its back.
func _tarantula(s: Dictionary, with_crew: bool) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", Color(0.28, 0.24, 0.24), 4.0)
	var dark := surf("rat_fur", Color(0.17, 0.15, 0.16), 3.5)
	var band := surf("rat_fur", Color(0.95, 0.55, 0.25), 3.0)
	var fang := plain(Color("#141012"))
	var eye := plain(Color("#0c0a0e"))
	eye.roughness = 0.15
	eye.metallic_specular = 0.9
	var C := Vector3(12.0, 18.0, 0)   # the carapace
	var A := Vector3(-16.0, 22.0, 0)   # the abdomen
	# Legs: four a side, the front pair reaching forward, the back pair back; knees high, feet wide.
	var legs := [[22.0, 30.0, 50.0], [16.0, 14.0, 20.0], [9.0, -2.0, -12.0], [3.0, -14.0, -34.0]]
	for leg in legs:
		for side in [1, -1]:
			var hip := Vector3(leg[0], 17.0, 9.0 * side)
			var knee := Vector3(leg[0] + (leg[1] - leg[0]) * 0.55, 34.0, 24.0 * side)
			var ankle := Vector3(leg[0] + (leg[2] - leg[0]) * 0.85, 12.0, 36.0 * side)
			var foot := Vector3(leg[2], 0.8, 39.0 * side)
			limb(n, [hip, knee], [3.4, 3.0], fur)
			n.add_child(blob(Vector3(3.2, 3.2, 3.2), band, knee))
			limb(n, [knee, ankle, foot], [2.8, 2.2, 1.4], dark)
	n.add_child(blob(Vector3(15.0, 8.0, 13.0), fur, C))
	n.add_child(blob(Vector3(19.0, 14.0, 16.0), fur, A, Vector3(0, 0, -10)))
	n.add_child(blob(Vector3(10.0, 6.0, 9.0), dark, A + Vector3(-12.0, -1.0, 0)))   # (the furred tip)
	for side in [1, -1]:   # chelicerae and fangs, pedipalps out front
		n.add_child(blob(Vector3(4.0, 5.0, 3.0), dark, Vector3(26.0, 14.0, 3.4 * side), Vector3(0, 0, -20)))
		n.add_child(cone(0.1, 1.2, 5.0, fang, Vector3(28.5, 9.0, 3.0 * side), Vector3(0, 0, -15), 8))
		limb(n, [Vector3(24.0, 15.0, 6.0 * side), Vector3(32.0, 18.0, 9.0 * side), Vector3(36.0, 6.0, 10.0 * side)], [1.8, 1.6, 1.4], fur)
	for k in 8:   # the eyes, a cluster on a turret at the carapace's front
		var a := TAU * k / 8.0
		n.add_child(blob(Vector3.ONE * (1.1 if k % 2 == 0 else 0.7), eye, Vector3(21.0 + cos(a) * 1.8, 25.5 + sin(a) * 0.8, sin(a) * 2.6)))
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
	return {"node": n, "sockets": sockets}


## Frogs: a giant crayfish from the swamp's mud, red-brown and armoured, two great claws held up and
## out; a howdah on its carapace, two frogs. Nothing like a frog, a turtle, a snail or a toad.
func _crayfish(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", Color("#8a3a22"), 5.0)
	shell.roughness = 0.5
	var dark := surf("chitin", Color("#5a2416"), 4.0)
	var pale := plain(Color("#d8a070"))
	for k in 4:   # walking legs, four a side, thin and jointed
		for side in [1, -1]:
			var x := 10.0 - k * 6.0
			limb(n, [Vector3(x, 12.0, 8.0 * side), Vector3(x + 1.0, 18.0, 18.0 * side), Vector3(x - 1.0, 0.8, 23.0 * side)], [1.4, 1.1, 0.6], dark)
	n.add_child(blob(Vector3(18.0, 10.0, 12.0), shell, Vector3(4.0, 16.0, 0)))   # the carapace
	n.add_child(rod(Vector3(20.0, 17.0, 0), Vector3(30.0, 16.0, 0), 4.5, 1.0, shell))   # the rostrum
	var tail := [[-14.0, 15.5, 10.0], [-22.0, 14.0, 9.0], [-29.0, 12.0, 7.6], [-35.0, 10.0, 6.2], [-40.0, 8.0, 5.0]]
	for i in tail.size():   # the tail in plates, curling down at the end into the fan
		var t: Array = tail[i]
		n.add_child(blob(Vector3(5.0, t[2] * 0.7, t[2]), shell if i % 2 == 0 else dark, Vector3(t[0], t[1], 0)))
	for k in 5:
		var a := deg_to_rad(-50.0 + k * 25.0)
		n.add_child(blob(Vector3(5.0, 1.0, 2.4), dark, Vector3(-46.0, 5.0, 0) + Vector3(-cos(a) * 2.0, 0, sin(a) * 5.0), Vector3(0, rad_to_deg(a), 20)))
	for side in [1, -1]:
		# The claws: an arm up and out, a great pincer at its end, the fingers open.
		limb(n, [Vector3(16.0, 14.0, 9.0 * side), Vector3(24.0, 20.0, 18.0 * side), Vector3(32.0, 24.0, 18.0 * side)], [2.6, 2.4, 2.4], shell)
		n.add_child(blob(Vector3(9.0, 5.5, 4.0), shell, Vector3(38.0, 25.0, 17.0 * side), Vector3(0, 0, 12)))
		limb(n, [Vector3(44.0, 28.0, 17.0 * side), Vector3(52.0, 31.0, 16.5 * side)], [2.6, 0.8], dark)
		limb(n, [Vector3(44.0, 24.0, 17.0 * side), Vector3(51.0, 22.0, 16.5 * side)], [2.0, 0.6], dark)
		for t in 4:
			n.add_child(blob(Vector3.ONE * 0.7, pale, Vector3(36.0 + t * 2.0, 29.5, 17.0 * side)))   # the claw's knobs
		limb(n, [Vector3(26.0, 18.0, 3.0 * side), Vector3(40.0, 30.0, 10.0 * side), Vector3(52.0, 36.0, 14.0 * side)], [0.6, 0.4, 0.2], dark)   # antennae
		n.add_child(blob(Vector3(1.4, 1.4, 1.4), plain(Color("#0c0806")), Vector3(23.0, 20.0, 4.0 * side)))   # eyes on stalks
	var y := deck(n, s, Vector3(2.0, 27.5, 0), 18.0, 16.0)
	n.add_child(_box(Vector3(22.0, 0.6, 24.0), s.wicker, Vector3(2.0, 26.4, 0)))
	pennant(n, s, Vector3(-6.4, y, -7.0), 12.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(6.5, y + 0.7, 2.5), "crew1_f0_top": Vector3(-3.0, y + 0.7, -3.0)}}


## Frogs, b: a giant grey heron, the frogs' oldest enemy, broken to the saddle: long legs, an S of a
## neck, a dagger of a beak, a black crest; one frog in a saddle between its wings.
func _heron(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var grey := surf("hide", Color(0.72, 0.74, 0.78), 6.0)
	var dark := plain(Color("#3a3c44"))
	var white := surf("hide", Color(0.95, 0.95, 0.93), 6.0)
	var leg := plain(Color("#8a7a4a"))
	var beak := plain(Color("#c8a040"))
	for side in [1, -1]:
		limb(n, [Vector3(0.0, 40.0, 5.0 * side), Vector3(2.0, 26.0, 6.0 * side), Vector3(-2.0, 12.0, 6.0 * side), Vector3(0.0, 1.0, 6.5 * side)], [2.4, 1.3, 1.2, 1.0], leg)
		for t in 3:
			n.add_child(rod(Vector3(0.0, 0.8, 6.5 * side), Vector3(6.0, 0.6, (6.5 + (t - 1) * 3.0) * side), 0.6, 0.4, leg))
		n.add_child(rod(Vector3(0.0, 0.8, 6.5 * side), Vector3(-4.0, 0.6, 6.5 * side), 0.6, 0.4, leg))
	n.add_child(blob(Vector3(17.0, 9.5, 10.0), grey, Vector3(-2.0, 46.0, 0), Vector3(0, 0, 12)))   # the body
	for side in [1, -1]:   # folded wings, darker at the tips, crossing over the tail
		n.add_child(blob(Vector3(17.0, 6.0, 3.0), grey, Vector3(-5.0, 47.0, 8.5 * side), Vector3(0, 0, 14)))
		n.add_child(blob(Vector3(10.0, 3.0, 2.4), dark, Vector3(-17.0, 43.5, 7.0 * side), Vector3(0, 0, 20)))
	limb(n, [Vector3(10.0, 50.0, 0), Vector3(16.0, 58.0, 0), Vector3(12.0, 66.0, 0), Vector3(16.0, 74.0, 0)], [4.0, 3.0, 2.8, 2.8], white)
	n.add_child(blob(Vector3(4.6, 3.6, 3.4), white, Vector3(18.0, 75.0, 0)))
	n.add_child(cone(0.2, 1.8, 14.0, beak, Vector3(28.0, 74.0, 0), Vector3(0, 0, -93), 10))
	limb(n, [Vector3(15.0, 77.0, 0), Vector3(6.0, 79.0, 0), Vector3(0.0, 77.0, 0)], [1.0, 0.7, 0.3], dark)   # the crest
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.9, 0.9, 0.6), plain(Color("#d8b020")), Vector3(20.0, 76.0, 3.0 * side)))
		n.add_child(rod(Vector3(17.0, 75.5, 3.4 * side), Vector3(22.0, 75.0, 2.4 * side), 0.4, 0.3, dark))
	n.add_child(_box(Vector3(11.0, 0.8, 18.0), s.team, Vector3(-3.0, 55.0, 0), Vector3(0, 0, 8)))
	n.add_child(_box(Vector3(8.0, 1.6, 9.0), s.dark, Vector3(-3.0, 56.0, 0)))
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(-3.0, 56.8, 0)}}


## Forest beetles: a giant praying mantis, leaf-green, its raptorial arms folded and spiked, the long
## neck up, wings folded along its abdomen; one beetle in a saddle on its back. A tall thin shape no
## other beast in the game has.
func _mantis(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var green := surf("chitin", Color("#6a9a3a"), 5.0)
	green.roughness = 0.5
	var dark := surf("chitin", Color("#4a7028"), 4.0)
	var wing := surf("leaf", Color(0.75, 0.9, 0.55), 10.0)
	var spike := plain(Color("#2a3a14"))
	for leg in [[2.0, 12.0], [-6.0, -16.0]]:   # two pairs of walking legs, long and thin
		for side in [1, -1]:
			limb(n, [Vector3(leg[0], 22.0, 4.0 * side), Vector3(leg[0] + (leg[1] - leg[0]) * 0.4, 34.0, 18.0 * side), Vector3(leg[1], 0.8, 24.0 * side)], [1.8, 1.4, 0.8], dark)
	n.add_child(blob(Vector3(22.0, 6.5, 7.5), green, Vector3(-20.0, 26.0, 0), Vector3(0, 0, 10)))   # the abdomen
	for side in [1, -1]:
		n.add_child(blob(Vector3(20.0, 2.0, 5.0), wing, Vector3(-18.0, 31.0, 3.0 * side), Vector3(0, 0, 10)))
	n.add_child(blob(Vector3(7.0, 5.0, 6.0), green, Vector3(0.0, 23.0, 0)))   # the thorax
	limb(n, [Vector3(4.0, 24.0, 0), Vector3(16.0, 42.0, 0)], [3.4, 2.6], green)   # the long prothorax
	n.add_child(blob(Vector3(3.6, 4.0, 5.6), green, Vector3(19.0, 46.0, 0)))   # the head
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.4, 2.6, 2.2), plain(Color("#c8d870")), Vector3(19.5, 48.0, 5.0 * side)))
		limb(n, [Vector3(20.0, 49.0, 1.5 * side), Vector3(26.0, 58.0, 5.0 * side), Vector3(32.0, 62.0, 8.0 * side)], [0.5, 0.35, 0.2], dark)
		# The raptorial arms: coxa down and forward, femur back up, spiked, the tibia folded under.
		var cox := Vector3(13.0, 37.0, 3.5 * side)
		var elbow := Vector3(20.0, 26.0, 6.0 * side)
		var wrist := Vector3(25.0, 40.0, 6.5 * side)
		limb(n, [cox, elbow, wrist], [2.2, 2.4, 1.8], green)
		limb(n, [wrist, Vector3(22.0, 31.0, 7.0 * side)], [1.6, 0.6], dark)
		for t in 4:
			n.add_child(cone(0.1, 0.5, 2.4, spike, elbow.lerp(wrist, 0.2 + t * 0.2) + Vector3(-1.4, 0, 0), Vector3(0, 0, 70), 6))
	n.add_child(_box(Vector3(12.0, 0.8, 16.0), s.team, Vector3(-8.0, 31.0, 0), Vector3(0, 0, 8)))
	n.add_child(_box(Vector3(9.0, 1.6, 8.0), s.dark, Vector3(-8.0, 32.2, 0), Vector3(0, 0, 8)))
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(-8.0, 33.4, 0)}}


## Forest beetles, b: a giant centipede, long and low, banded red-brown, yellow legs down its whole
## length, forcipules at its head; a long deck along its back, two beetles.
func _centipede(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var seg := surf("chitin", Color("#6a2a1a"), 4.0)
	seg.roughness = 0.45
	var seg2 := surf("chitin", Color("#3a1810"), 4.0)
	var leg := plain(Color("#d8a830"))
	for k in 11:
		var x := 30.0 - k * 6.5
		var y := 12.0 + sin(k * 0.7) * 1.2
		n.add_child(blob(Vector3(4.6, 5.0, 8.0), seg if k % 2 == 0 else seg2, Vector3(x, y, 0)))
		for side in [1, -1]:
			limb(n, [Vector3(x, y - 1.0, 6.5 * side), Vector3(x + 1.0, y + 2.0, 13.0 * side), Vector3(x - 1.0, 0.8, 16.0 * side)], [1.2, 0.9, 0.5], leg)
	n.add_child(blob(Vector3(6.0, 4.5, 7.0), seg, Vector3(38.0, 12.0, 0)))   # the head
	for side in [1, -1]:
		limb(n, [Vector3(42.0, 10.0, 4.0 * side), Vector3(47.0, 9.0, 5.0 * side), Vector3(48.0, 8.0, 1.0 * side)], [1.4, 1.0, 0.3], seg2)
		limb(n, [Vector3(42.0, 14.0, 3.0 * side), Vector3(52.0, 20.0, 8.0 * side), Vector3(58.0, 18.0, 12.0 * side)], [0.6, 0.4, 0.2], seg2)
		limb(n, [Vector3(-36.0, 12.0, 3.0 * side), Vector3(-44.0, 16.0, 6.0 * side), Vector3(-50.0, 15.0, 9.0 * side)], [0.8, 0.5, 0.3], leg)
	var y := deck(n, s, Vector3(2.0, 18.5, 0), 34.0, 13.0, 5.0)
	pennant(n, s, Vector3(-14.4, y, -5.5), 12.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(10.0, y + 0.7, 2.0), "crew1_f0_top": Vector3(-6.0, y + 0.7, -2.0)}}


# ================================================================== GS2: the great sling, round 2
# D-127 (Dominic): "pretty cool, but needs to be bigger and more robust looking: for siege! not thin and
# skinny." A siege-weight traction sling: a heavy squared-timber frame on sills (56 long against the
# catapult's ~40), braced towers, a thick iron-banded arm, a big sling and a pile of stones, six crew
# hauling ropes from the short end and one loading. Takes in each family's materials (D-116: the rats'
# from human-sized junk); the frogs' also on their snapping turtle (D-121, D-122).

func _concept_gs2_timber(c: Dictionary) -> Dictionary: return _great_sling(_style("timber", c))
func _concept_gs2_junk(c: Dictionary) -> Dictionary: return _great_sling(_style("junk", c))
func _concept_gs2_forest(c: Dictionary) -> Dictionary: return _great_sling(_style("forest", c))
func _concept_gs2_spooky(c: Dictionary) -> Dictionary: return _great_sling(_style("spooky", c))
func _concept_gs2_frog(c: Dictionary) -> Dictionary: return _great_sling(_style("frog", c))
func _concept_gs2_frog_turtle(c: Dictionary) -> Dictionary: return _sling_turtle(_style("frog", c))
func _concept_gs2_packed_timber(c: Dictionary) -> Dictionary: return _great_packed(_style("timber", c))


## The frame and arm on its sills at y = `base` (0, or a deck), `k` times the size; returns the short
## end (where the pull ropes hang) and the long end.
func sling_frame(n: Node3D, s: Dictionary, base := 0.0, k := 1.0) -> Array:
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
	# The arm, cocked: the short end forward and down, the long end back and high; thick at the axle,
	# tapering, bound with iron.
	var short := Vector3(18.0 * k, top - 10.0 * k, 0)
	var long := Vector3(-48.0 * k, top + 26.0 * k, 0)
	var mid := short.lerp(long, 0.3)
	n.add_child(beam(short, mid, 5.4 * k, 5.4 * k, s.wood))
	n.add_child(beam(mid, long, 3.6 * k, 3.6 * k, s.wood))
	var ang := rad_to_deg((long - short).angle_to(Vector3.RIGHT))
	for t in [0.08, 0.22, 0.42, 0.62]:
		n.add_child(ring(2.2 * k, 3.4 * k, s.metal, short.lerp(long, t), Vector3(0, 0, 90 + ang)))
	n.add_child(_box(Vector3(14.0 * k, 0.6, 5.8 * k), s.team, short.lerp(long, 0.48) + Vector3(0, 2.4 * k, 0), Vector3(0, 0, ang)))
	# The sling: two cords from the long end down to a big pouch with a boulder in it.
	var pouch := long + Vector3(-3.0, -20.0, 0) * k
	for z in [1.2, -1.2]:
		n.add_child(rod(long, pouch + Vector3(0, 1.0, z) * k, 0.35, 0.35, s.rope, false))
	n.add_child(blob(Vector3(3.6, 2.4, 3.6) * k, surf("leather", Color.WHITE, 2.0), pouch))
	n.add_child(blob(Vector3.ONE * 3.2 * k, s.ammo, pouch + Vector3(0, 1.4, 0) * k))
	# A crossbar at the short end, the pull ropes hanging from it.
	n.add_child(rod(short + Vector3(0, -2.0, -8.0) * k, short + Vector3(0, -2.0, 8.0) * k, 1.0 * k, 1.0 * k, s.dark))
	return [short + Vector3(0, -2.0, 0) * k, long]


## On its sills: six haulers in two ranks in front, one loader at the stone pile behind.
func _great_sling(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var ends := sling_frame(n, s)
	var short: Vector3 = ends[0]
	var sockets := {}
	for k in 6:
		var at := Vector3(36.0 + (k / 3) * 12.0, 0, (k % 3 - 1) * 11.0 + (k / 3) * 4.0)
		n.add_child(rod(short + Vector3(0, 0, clampf(at.z, -7.0, 7.0)), at + Vector3(-1.0, 13.0, 0), 0.4, 0.4, s.rope, false))
		sockets["crew%d_f4_raise" % k] = at
	for k in 7:   # the stone pile
		var a := k * 2.4
		n.add_child(blob(Vector3.ONE * (2.8 - (k % 3) * 0.4), s.ammo, Vector3(-36.0 + cos(a) * 3.5, 2.4 + (1.6 if k == 6 else 0.0), 22.0 + sin(a) * 3.0)))
	sockets["crew6_f6_reach"] = Vector3(-36.0, 0, 13.0)
	pennant(n, s, Vector3(0, 51.0, -10.0), 12.0, 5.0)
	if s.fam == "junk":   # patched with rusted plate, chain braces
		for side in [1, -1]:
			patch(n, s, Vector3(-8.0, 14.0, 15.6 * side), Vector2(7.0, 9.0), Vector3(0, 0, 32), s.plate)
			chain(n, Vector3(-26.0, 4.0, 15.0 * side), Vector3(0, 48.0, 7.0 * side), s.metal)
	return {"node": n, "sockets": sockets}


## The frogs, b: the same sling smaller on a deck lashed to the ram's snapping turtle; three frogs on
## the deck haul down on the ropes, one walks beside.
func _sling_turtle(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := snapping_turtle(n, s)
	var y := shell + 1.2
	n.add_child(_box(Vector3(40.0, 2.0, 30.0), s.plank, Vector3(-6.0, y - 1.0, 0)))
	for side in [1, -1]:
		n.add_child(rod(Vector3(-6.0, y - 1.0, 15.0 * side), Vector3(-6.0, 12.0, 24.0 * side), 0.5, 0.5, s.lash, false))
	var ends := sling_frame(n, s, y, 0.62)
	var short: Vector3 = ends[0]
	var sockets := {}
	for k in 3:
		var at := Vector3(10.0, y, (k - 1) * 8.0)
		n.add_child(rod(short + Vector3(0, 0, (k - 1) * 3.0), at + Vector3(0, 12.0, 0), 0.4, 0.4, s.rope, false))
		sockets["crew%d_f4_raise_top" % k] = at + Vector3(0, 0.1, 0)
	sockets["crew3_f0_reach"] = Vector3(-10.0, 0, 34.0)
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
