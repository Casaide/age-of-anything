extends "res://scenes/art_pixel/siege_models.gd"
## Trade cart concepts, round TC1 (milestone 13 step 6, D-080: options first). Staged by
## data/later/trade_carts.json (its "models"), drawn by tests/sheets/trade_carts_tc1.json; nothing here
## is in play (the game shows the placeholder handcart, siege_models.gd _cart_placeholder, until
## Dominic picks). Notes and questions: docs/concepts/trade_carts/README.md.
## Part ids "concept.tc1_<option>_<take>" (method "_concept_tc1_<option>_<take>"):
##   a      the race's own mount pulls a two-wheeled cart (the recipe's `haul`: UnitView draws the bare
##          creature walking on the "haul0" socket) in a draught harness, the cart's shafts on its
##          traces' ends; a worker leads it at its head
##   b      the handcart that was in play until D-127, pushed by a worker
##   c      each family its own: timber a covered wagon behind two ponies; frog a giant snail with
##          panniers, a frog riding; junk a scrap barrow; forest a ball of goods rolled by a beetle;
##          spooky a silk-wrapped bundle on a bone sledge, dragged by a spider
## Same frame as the engines: x forward, y up, z towards the viewer's side, standing on y = 0.

## Round TC1 as first drawn (a_v1, kept for the placement fixture): where each mount stood in front of
## the cart (its socket's x), where its chest was from there (the rope traces ran to it), the handler.
const BEASTS := {
	"pony": {"x": 38.0, "chest": Vector3(9.0, 18.0, 8.0), "lead": 15.0},
	"newt": {"x": 44.0, "chest": Vector3(11.0, 9.0, 11.0), "lead": 20.0},
	"cat": {"x": 36.0, "chest": Vector3(8.0, 13.0, 7.5), "lead": 14.0},
	"beetle": {"x": 36.0, "chest": Vector3(9.0, 11.0, 9.5), "lead": 16.0},
	"spider": {"x": 38.0, "chest": Vector3(3.0, 12.0, 10.0), "lead": 22.0},
}
const TAKE_BEAST := {"timber": "pony", "frog": "newt", "junk": "cat", "forest": "beetle", "spooky": "spider"}


# ------------------------------------------------------------------ the parts

func _concept_tc1_a_timber(c: Dictionary) -> Dictionary: return _a("timber", c)
func _concept_tc1_a_frog(c: Dictionary) -> Dictionary: return _a("frog", c)
func _concept_tc1_a_junk(c: Dictionary) -> Dictionary: return _a("junk", c)
func _concept_tc1_a_forest(c: Dictionary) -> Dictionary: return _a("forest", c)
func _concept_tc1_a_spooky(c: Dictionary) -> Dictionary: return _a("spooky", c)
func _concept_tc1_b_timber(c: Dictionary) -> Dictionary: return _cart_placeholder(_style("timber", c), c)
func _concept_tc1_b_frog(c: Dictionary) -> Dictionary: return _cart_placeholder(_style("frog", c), c)
func _concept_tc1_b_junk(c: Dictionary) -> Dictionary: return _cart_placeholder(_style("junk", c), c)
func _concept_tc1_b_forest(c: Dictionary) -> Dictionary: return _cart_placeholder(_style("forest", c), c)
func _concept_tc1_b_spooky(c: Dictionary) -> Dictionary: return _cart_placeholder(_style("spooky", c), c)
func _concept_tc1_c_timber(c: Dictionary) -> Dictionary: return _wagon(_style("timber", c), c)
func _concept_tc1_c_frog(c: Dictionary) -> Dictionary: return _snail_packs(_style("frog", c))
func _concept_tc1_c_junk(c: Dictionary) -> Dictionary: return _barrow(_style("junk", c))
func _concept_tc1_c_forest(c: Dictionary) -> Dictionary: return _goods_ball(_style("forest", c))
func _concept_tc1_c_spooky(c: Dictionary) -> Dictionary: return _silk_sledge(_style("spooky", c))


# ------------------------------------------------------------------ A: the race's mount pulls

## The cart in play since D-127 (siege_models.gd hauled_cart), drawn here with each take's own mount
## (the frogs' newt, its cart drawn bigger: in play the frogs' snail pulls theirs).
func _a(take: String, c: Dictionary) -> Dictionary:
	return hauled_cart(TAKE_BEAST[take], _style(take, c), c, 1.25 if take == "frog" else 1.0)


## TC1 A as first drawn (2026-10-13), kept so the placement fixture can put it back and must fail it
## (Dominic: "this is bugged, did the tests not catch it?"): rope traces from a swingletree to points in
## the air by the beast's chest, no harness, the cart floating behind, the handler in the cat's flank.
func a_v1(take: String, c: Dictionary) -> Dictionary:
	var s := _style(take, c)
	var b: Dictionary = BEASTS[TAKE_BEAST[take]]
	var n := Node3D.new()
	var wr := 6.5
	var y := wr + 1.6
	for side in [1, -1]:
		wheel(n, Vector3(0.0, wr, 8.6 * side), wr, 1.6, s)
	n.add_child(rod(Vector3(0.0, wr, -9.6), Vector3(0.0, wr, 9.6), 0.6, 0.6, s.dark, false))
	var plank: Material = surf("wood_grain", Color.WHITE, 8.0) if take != "spooky" else s.wood
	n.add_child(_box(Vector3(24.0, 1.2, 13.0), plank, Vector3(0.0, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(24.0, 3.6, 0.8), plank, Vector3(0.0, y + 2.3, 6.3 * side)))
	for x in [-11.6, 11.6]:
		n.add_child(_box(Vector3(0.8, 3.6, 13.0), plank, Vector3(x, y + 2.3, 0)))
	cart_load(n, s, Vector3(0.0, y, 0))
	# A prop at the back (it tips back without the beast) and the swingletree at the front.
	n.add_child(rod(Vector3(-11.0, y, 0), Vector3(-13.0, 0.3, 0), 0.5, 0.5, s.dark))
	n.add_child(beam(Vector3(13.5, y + 1.0, -7.5), Vector3(13.5, y + 1.0, 7.5), 1.2, 1.2, s.dark))
	var chest: Vector3 = Vector3(float(b.x), 0, 0) + (b.chest as Vector3)
	for side in [1, -1]:   # the traces, to the beast's chest on either side of it
		n.add_child(rod(Vector3(13.5, y + 1.0, 7.0 * side), Vector3(chest.x, chest.y, chest.z * side), 0.35, 0.35, s.rope, false))
	var spec := {"node": n, "sockets": {"haul0_f0": Vector3(b.x, 0, 0), "crew0_f0": Vector3(b.x + 2.0, 0, b.lead)}}
	return _scaled(spec, 1.25) if take == "frog" else spec


# ------------------------------------------------------------------ C: each family's own

## Timber: a covered wagon on four wheels, hooped canvas with a team stripe, goods at the tail; two
## ponies side by side on traces, the driver on the bench.
const WAGON_POLE := 6.0   # the pole from the wagon's front to the evener bar behind the ponies


func _wagon(s: Dictionary, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wr := 6.0
	var y := wr + 2.0
	for x in [-10.0, 10.0]:
		for side in [1, -1]:
			wheel(n, Vector3(x, wr, 9.6 * side), wr, 1.6, s)
		n.add_child(rod(Vector3(x, wr, -10.6), Vector3(x, wr, 10.6), 0.6, 0.6, s.dark, false))
	var plank := surf("wood_grain", Color.WHITE, 8.0)
	n.add_child(_box(Vector3(32.0, 1.4, 15.0), plank, Vector3(0, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(32.0, 3.0, 0.8), plank, Vector3(0, y + 2.0, 7.3 * side)))
	# The cover: hoops and canvas over the back two thirds, a team stripe along it.
	var canvas := surf("cloth", Color("#e4d8bc"), 3.0)
	var top := y + 15.0
	for k in 5:
		var x := -14.0 + k * 5.5
		var hoop := ring(7.2, 7.8, s.dark, Vector3(x, y + 7.5, 0), Vector3(90, 90, 0), Vector3(1, 1.2, 1))
		n.add_child(hoop)
	var cover := blob(Vector3(13.0, 8.0, 7.6), canvas, Vector3(-3.0, y + 7.6, 0))
	n.add_child(cover)
	n.add_child(_box(Vector3(26.0, 0.4, 15.6), canvas, Vector3(-3.0, y + 3.2, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(24.0, 2.0, 0.4), s.team, Vector3(-3.0, y + 6.0, 7.75 * side)))
	n.add_child(_box(Vector3(2.0, 6.0, 1.0), s.dark, Vector3(12.5, y + 3.0, 0)))   # the bench's back
	n.add_child(_box(Vector3(4.0, 0.8, 12.0), plank, Vector3(13.0, y + 3.4, 0)))   # the bench
	# The ponies wear draught harness (as A); a pole forward from the wagon to an evener bar behind
	# them, a short rope from the bar to each trace end (the hitches: placement check C2).
	var lay := harness_layout(BEAST_BODY.pony, c)
	var te: Vector3 = lay.ends[0]
	var hx := 16.0 + WAGON_POLE + 3.0   # the hitches' x: the bar 3 behind them
	var sockets := {"crew0_f0_reach_top": Vector3(12.5, y + 3.8, 0)}
	var bar := hx - 3.0
	n.add_child(beam(Vector3(16.0, y, 0), Vector3(bar, te.y, 0), 1.2, 1.2, s.dark))
	n.add_child(beam(Vector3(bar, te.y, -(9.0 + te.z) - 0.5), Vector3(bar, te.y, 9.0 + te.z + 0.5), 1.2, 1.2, s.dark))
	for i in 2:
		var pz := 9.0 if i == 0 else -9.0
		sockets["haul%d_f0" % i] = Vector3(hx - te.x, 0, pz)
		for side in [1, -1]:
			var hitch := Vector3(hx, te.y, pz + te.z * side)
			n.add_child(rod(Vector3(bar, te.y, hitch.z), hitch, 0.4, 0.4, s.rope))
			sockets["hitch%d_%s" % [i, "near" if side > 0 else "far"]] = hitch
	return {"node": n, "sockets": sockets}


## Frogs: a smaller giant snail (the catapult's kin) with wicker panniers of goods slung over its
## shell and a team cloth, a frog riding on the shell with a goad.
func _snail_packs(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var beast := Node3D.new()
	beast.scale = Vector3.ONE * 0.62
	n.add_child(beast)
	var top := swamp_snail(beast, s) * 0.62
	var x0 := -5.0
	for side in [1, -1]:
		n.add_child(cone(4.6, 3.6, 9.0, s.wicker, Vector3(x0, 12.0, 11.0 * side)))   # a pannier each side
		n.add_child(blob(Vector3(3.8, 2.2, 3.8), surf("cloth", Color("#c8b48a"), 3.0), Vector3(x0, 17.0, 11.0 * side)))
		n.add_child(rod(Vector3(x0, top - 1.0, 4.0 * side), Vector3(x0, 16.0, 10.0 * side), 0.4, 0.4, s.rope, false))
		n.add_child(_box(Vector3(10.0, 5.0, 0.4), s.team, Vector3(x0 - 6.0, top - 6.0, 9.5 * side), Vector3(30 * side, 0, 0)))
	n.add_child(_box(Vector3(12.0, 1.2, 9.0), s.dark, Vector3(x0 - 2.0, top - 0.4, 0)))   # a little deck on the shell
	return {"node": n, "sockets": {"crew0_f0_reach_top": Vector3(x0 - 2.0, top + 0.2, 0)}}


## Rats: a barrow of sewer scrap at human scale (D-116), loaded with goods (siege_models.gd scrap_barrow:
## since D-127 the rats push it home with stone).
func _barrow(s: Dictionary) -> Dictionary:
	return scrap_barrow(s, "goods")


## Forest beetles: the dung beetle's way, goods packed into a ball of earth bound with twine and
## leaves (a jar's neck and a sack stick out), rolled by a beetle worker behind.
func _goods_ball(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var r := 11.0
	var at := Vector3(4.0, r, 0)
	var earth := surf("bld_daub", Color(0.62, 0.48, 0.34), 6.0)
	n.add_child(blob(Vector3.ONE * r, earth, at))
	for k in 3:   # twine bands round it
		n.add_child(ring(r * 0.98, r * 1.04, s.rope, at, Vector3(0, k * 60.0, 90)))
	n.add_child(ring(r * 0.98, r * 1.04, s.team, at, Vector3(90, 0, 0)))   # a team band
	for k in 7:   # leaves pressed in
		var a := k * 2.39996
		var d := Vector3(cos(a) * 0.7, 0.55 + 0.4 * sin(a * 1.7), sin(a) * 0.7).normalized()
		n.add_child(blob(Vector3(3.0, 0.5, 1.8), s.roof, at + d * r * 0.98, Vector3(0, rad_to_deg(a), 30)))
	n.add_child(cone(0.8, 1.6, 4.0, surf("bld_daub", Color(1.05, 0.62, 0.42), 6.0), at + Vector3(2.0, r - 0.5, 3.0), Vector3(0, 0, -20)))   # a jar's neck
	n.add_child(blob(Vector3(2.6, 2.0, 2.4), surf("cloth", Color("#c8b48a"), 3.0), at + Vector3(-5.0, r * 0.7, -5.0)))   # a sack
	return {"node": n, "sockets": {"crew0_f0_reach": Vector3(-12.5, 0, 0)}}


## Spooky spiders: a big bundle wrapped in silk, strands round it, on a bone sledge, dragged on a silk
## line by a spider out in front.
func _silk_sledge(s: Dictionary) -> Dictionary:
	var n := Node3D.new()
	for side in [1, -1]:   # bone runners, curled at the front
		n.add_child(rod(Vector3(-13.0, 1.0, 5.5 * side), Vector3(10.0, 1.0, 5.5 * side), 0.9, 0.9, s.metal))
		n.add_child(rod(Vector3(10.0, 1.0, 5.5 * side), Vector3(14.0, 4.0, 5.5 * side), 0.9, 0.6, s.metal))
	for x in [-9.0, -1.0, 7.0]:
		n.add_child(rod(Vector3(x, 1.8, -6.5), Vector3(x, 1.8, 6.5), 0.7, 0.7, s.wood))
	n.add_child(rod(Vector3(14.0, 4.0, -5.5), Vector3(14.0, 4.0, 5.5), 0.6, 0.6, s.metal))   # a bone across the runners' tips, the drag line tied to it (it began in the air: C3)
	var silk := surf("cloth", Color("#ece8f2"), 2.0)
	n.add_child(blob(Vector3(11.0, 7.0, 6.5), silk, Vector3(-1.0, 8.5, 0)))
	for k in 6:   # strands wound round it
		n.add_child(ring(6.4, 6.9, plain(Color("#d8d2e4")), Vector3(-9.0 + k * 3.2, 8.5, 0), Vector3(90, 90, 0), Vector3(1, 1.05, 1)))
	n.add_child(_box(Vector3(8.0, 0.4, 7.2), s.team, Vector3(-1.0, 15.4, 0)))
	var line := surf("cloth", Color("#ece8f2"), 2.0)
	line.set_meta("rope", true)   # tied at both ends (the placement check, C3)
	n.add_child(rod(Vector3(14.0, 4.0, 0), Vector3(26.0, 8.0, 0), 0.2, 0.2, line, false))   # the drag line
	return {"node": n, "sockets": {"crew0_f0": Vector3(30.0, 0, 0)}}
