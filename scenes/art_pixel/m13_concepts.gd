extends "res://scenes/art_pixel/siege_models.gd"
## Milestone 13 concept rounds (D-080: options first), staged by data/later/m13_concepts.json and drawn
## by tests/sheets/{war_beasts_wb1,sapper_sp1,great_sling_gs1,war_beasts_wb2,great_sling_gs2,great_sling_fs1}.json. The picks
## (D-129: the howdah elephant, the war boar, the tarantula, the heron, the mantis, GS2's sling and its wagon) moved to
## siege_models.gd and are in play from there; these wrappers keep drawing the rounds as they were shown.
## Notes and questions: docs/concepts/{war_beasts,sapper,great_sling}/README.md.
##   WB1  war beasts, two options a family, as one baked body with riders on top (the race's own
##        people on "crew<n>_top" sockets, as on the siege beasts): concept.wb1_<opt>_<take>
##   SP1  the sapper's charge, held in the hand: concept.sp1_<name> (slot hand_r)
##   GS1  the great sling, set up and packed: concept.gs1_<opt>_<take>
##   WB2  war beasts round 2 (D-127): the rats' war boar, the spiders' tarantula alone, a crayfish and a
##        heron for the frogs, a mantis and a centipede for the beetles: concept.wb2_<beast>
##   GS2  the great sling round 2 (D-127), siege-weight, every take: concept.gs2_<take>
##   FS1  the frogs' great sling (D-129): a bullfrog leaper, a stilt sling, a crayfish winder: concept.fs1_<a|b|c>
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


## Frogs: the giant toad (the bolt thrower's), a howdah on its back with a rider (two frogs don't fit).
func _toad_howdah(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	giant_toad(n, s)
	var sk := howdah(n, s, Vector3(-4.0, 34.0, 0), 18.0, 16.0, 1)
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
		return {"node": n, "sockets": howdah(n, s, seat + Vector3(-2.0, 1.0, 0), 18.0, 15.0, 1 if kind == "spider" else 2)}
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
		var at := Vector3(24.0 + (k % 2) * 11.0, 0, (k - 1) * 15.0)   # (at 3 and 6.5 apart the haulers stood in each other: placement C1)
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


## Frogs: a giant crayfish from the swamp's mud, red-brown and armoured, two great claws held up and
## out; a howdah on its carapace, two frogs. Nothing like a frog, a turtle, a snail or a toad.
func _crayfish(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	crayfish_body(n, s)
	var y := deck(n, s, Vector3(2.0, 27.5, 0), 18.0, 16.0)
	n.add_child(_box(Vector3(22.0, 0.6, 24.0), s.wicker, Vector3(2.0, 26.4, 0)))
	pennant(n, s, Vector3(-6.4, y, -7.0), 12.0, 4.0)
	return {"node": n, "sockets": {"crew0_f0_top": Vector3(6.5, y + 0.7, 2.5), "crew1_f0_top": Vector3(-3.0, y + 0.7, -3.0)}}


## The giant crayfish alone (WB2 A's, FS1 C's winder): red-brown plates, claws up and open, feelers.
func crayfish_body(n: Node3D, s: Dictionary) -> void:
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



# ================================================================== FS1: the frogs' great sling
# D-129 (Dominic): GS2's frogs: "the tortoise one is wrong, and the plain one probably too boring". Three swamp
# ideas that repeat none of their beasts so far (the turtle ram, the snail catapult, the toad bolt thrower, the
# heron war beast, newt cavalry). Until Dominic picks, the frogs' great sling in play wears their snail catapult.
#   A  the bullfrog leaper: a counterweight sling whose weight is a giant bullfrog, crouched on a reed
#      tower behind it, leaping down onto the padded short arm to fling the stone
#   B  the stilt sling: the GS2 frame smaller on a deck high on bundled-reed stilts over a sledge (a swamp
#      house on the move), four haulers up on the deck, a loader below
#   C  the crayfish winder: the GS2 frame hauled down by a giant crayfish gripping the pull ropes in its
#      claws, a frog driving it from its back, a loader at the stones

func _concept_fs1_a(c: Dictionary) -> Dictionary: return _fs1_bullfrog(_style("frog", c))
func _concept_fs1_b(c: Dictionary) -> Dictionary: return _fs1_stilts(_style("frog", c))
func _concept_fs1_c(c: Dictionary) -> Dictionary: return _fs1_crayfish(_style("frog", c))


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


## A: the counterweight sling worked by a bullfrog. The arm the other way from the traction sling: its long
## end down in front with the pouch on the ground, its short end up high behind with a padded landing pad;
## a reed tower behind it, the bullfrog crouched on top to leap onto the pad. Two frogs load the pouch, one
## minds the tower.
func _fs1_bullfrog(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var k := 0.9
	var top := sling_towers(n, s, 0.0, k)
	var short := Vector3(-15.0, top + 15.0, 0)
	var long := Vector3(40.0, 10.0, 0)
	sling_arm(n, s, short, long, k, Vector3(6.0, -5.0, 0))
	n.add_child(_box(Vector3(13.0, 2.0, 13.0), s.wicker, short + Vector3(-1.0, 2.2, 0)))   # the landing pad
	n.add_child(_box(Vector3(11.0, 0.6, 11.0), s.team, short + Vector3(-1.0, 3.5, 0)))
	# The tower: four bundled reed posts, braced, a plank top.
	var tx := -40.0
	var th := 62.0
	for x in [tx - 6.0, tx + 6.0]:
		for z in [-6.0, 6.0]:
			bundle(n, Vector3(x, 0, z), Vector3(x, th, z * 0.9), 1.6, s, 4, 1.3)
	for y in [20.0, 42.0]:
		for z in [-6.0, 6.0]:
			n.add_child(rod(Vector3(tx - 6.0, y, z), Vector3(tx + 6.0, y + 8.0, z), 0.6, 0.6, s.lash))
	n.add_child(_box(Vector3(16.0, 2.0, 16.0), s.plank, Vector3(tx, th + 1.0, 0)))
	bullfrog(n, Vector3(tx - 2.0, th + 2.0, 0), 1.05)
	for kk in 5:   # stones by the pouch
		var a := kk * 2.4
		n.add_child(blob(Vector3.ONE * (2.6 - (kk % 3) * 0.4), s.ammo, Vector3(52.0 + cos(a) * 3.0, 2.2, 20.0 + sin(a) * 2.6)))
	pennant(n, s, Vector3(tx + 6.0, th + 2.0, -6.0), 12.0, 4.5)
	return {"node": n, "sockets": {"crew0_f4_reach": Vector3(58.0, 0, 11.0), "crew1_f4_reach": Vector3(52.0, 0, -13.0), "crew2_f0": Vector3(-24.0, 0, 20.0)}}


## B: the stilt sling. A sledge on the ground, bundled-reed stilts up to a long deck, the GS2 frame smaller on
## it; the pull ropes run down to cleats at the deck's front, four frogs hauling beside them up on the deck,
## one loading from the stones on the ground behind.
func _fs1_stilts(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var dy := 34.0
	sledge(n, s, 84.0, 32.0, 9.0)
	for x in [-24.0, 9.0, 42.0]:
		for z in [-13.0, 13.0]:
			bundle(n, Vector3(x, 3.6, z), Vector3(x, dy - 1.5, z), 1.8, s, 3, 1.5)
		n.add_child(rod(Vector3(x, 6.0, -13.0), Vector3(x, dy - 3.0, 13.0), 0.6, 0.6, s.lash))   # cross lashing
		n.add_child(rod(Vector3(x, 6.0, 13.0), Vector3(x, dy - 3.0, -13.0), 0.6, 0.6, s.lash))
	n.add_child(_box(Vector3(84.0, 2.0, 32.0), s.plank, Vector3(9.0, dy - 1.0, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(66.0, 6.0, 0.4), s.team, Vector3(9.0, dy - 4.5, 16.4 * side)))
	var ends := sling_frame(n, s, dy, 0.7)
	var short: Vector3 = ends[0]
	var sockets := {}
	for side in [1, -1]:
		var cleat := Vector3(48.0, dy, 4.0 * side)
		n.add_child(rod(short + Vector3(0, 0, 5.0 * side), cleat + Vector3(0, 1.2, 0), 0.4, 0.4, s.rope, false))
		n.add_child(_box(Vector3(3.0, 2.4, 2.0), s.dark, cleat + Vector3(0, 1.2, 0)))
	for kk in 4:
		var side := 1.0 if kk < 2 else -1.0
		sockets["crew%d_f4_raise_top" % kk] = Vector3(20.0 + (kk % 2) * 21.0, dy + 0.1, 11.0 * side)
	for kk in 6:
		var a := kk * 2.4
		n.add_child(blob(Vector3.ONE * (2.6 - (kk % 3) * 0.4), s.ammo, Vector3(-40.0 + cos(a) * 3.0, 2.2, 24.0 + sin(a) * 2.6)))
	sockets["crew4_f6_reach"] = Vector3(-40.0, 0, 15.0)
	return {"node": n, "sockets": sockets}


## C: the crayfish winder. The GS2 frame a little smaller, its pull ropes run forward to a giant crayfish
## that grips them in its claws and backs away to haul the arm down; a frog rides it, another loads from
## the stones behind the frame.
func _fs1_crayfish(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var k := 0.85
	var ends := sling_frame(n, s, 0.0, k)
	var short: Vector3 = ends[0]
	var cray := Node3D.new()
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.8), Vector3(84.0, 0, 0))
	cray.transform = xf
	crayfish_body(cray, s)
	n.add_child(cray)
	for side in [1, -1]:   # each rope from the crossbar into a claw (between its fingers)
		var claw: Vector3 = xf * Vector3(46.0, 26.5, 17.0 * side)
		n.add_child(rod(short + Vector3(0, 0, 6.0 * side), claw, 0.45, 0.45, s.rope, false))
	var seat: Vector3 = xf * Vector3(4.0, 26.0, 0)
	n.add_child(_box(Vector3(9.0, 1.4, 10.0), s.team, seat + Vector3(0, 0.2, 0)))
	n.add_child(_box(Vector3(7.0, 1.2, 7.0), s.wicker, seat + Vector3(0, 1.4, 0)))
	for kk in 7:
		var a := kk * 2.4
		n.add_child(blob(Vector3.ONE * (2.6 - (kk % 3) * 0.4), s.ammo, Vector3(-32.0 + cos(a) * 3.2, 2.2, 20.0 + sin(a) * 2.8)))
	pennant(n, s, Vector3(0, 43.0, -9.0), 11.0, 4.5)
	return {"node": n, "sockets": {"crew0_f4_top": seat + Vector3(0, 2.1, 0), "crew1_f6_reach": Vector3(-32.0, 0, 11.0)}}
