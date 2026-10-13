extends "res://scenes/art_pixel/siege_models.gd"
## Milestone 13 concept rounds (D-080: options first), staged by data/later/m13_concepts.json and drawn
## by tests/sheets/{war_beasts_wb1,sapper_sp1,great_sling_gs1}.json. Nothing here is in play: the
## sapper holds a placeholder charge, the great sling wears the catapult, war beasts aren't built.
## Notes and questions: docs/concepts/{war_beasts,sapper,great_sling}/README.md.
##   WB1  war beasts, two options a family, as one baked body with riders on top (the race's own
##        people on "crew<n>_top" sockets, as on the siege beasts): concept.wb1_<opt>_<take>
##   SP1  the sapper's charge, held in the hand: concept.sp1_<name> (slot hand_r)
##   GS1  the great sling, set up and packed: concept.gs1_<opt>_<take>
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
