extends RefCounted
## Regression fixtures for the 2D placement check (projection_check.gd): each puts back a layering,
## leg, rider or truth configuration Dominic caught and asserts the check FAILS it with the rule that
## names the bug, then that the unit as it is now passes that rule (the control). Run by
## tests/placement_check.gd (needs a window: some re-bake the old parts, with the disk cache off).

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const Cases := preload("res://tests/placement/cases.gd")


## [ok, lines]
static func run(pc, holder: Node2D, lib, kit) -> Array:
	var cases := {}
	for c in Cases.all(lib):
		cases[c[0]] = c[1]
	var list := [
		["a rider's tiny leg ending at the horse's spine (the leg at its standing length, not stretched down the barrel)",
			"human on pony", ["B6 a rider's leg reaches down the flank"], "", func(v, _pose): _short_rider_legs(v)],
		["a rider's leg seen from the far side (the leg a step ahead counted as near: Dominic, \"visible from all sides\")",
			"human on pony", ["B6 a rider's leg on the flank facing the camera"], "", func(v, _pose): _old_rider_leg(v)],
		["a mount's wings over its body in every facing (a hummingbird's blur read as a grey plate: Dominic)",
			"human on hummingbird", ["a mount's wings over its back, behind it turned away", "back parts behind the body facing the camera"], "", func(v, _pose): _wings_over(v)],
		["legs drawn over the body (the far legs on top)",
			"animal body.deer", ["far legs behind the body"], "", func(v, _pose): _far_legs_over(v)],
		["the frog's sword hidden behind its body facing forward",
			"swamp frogs infantry age 2", ["weapons and shields show"], "", func(v, pose): _weapon_under(v, pose)],
		["worn armour carrying a whole copy of its body (the body not cut out of the armour's bake)",
			"sewer rats spear age 2", ["worn armour holds no body"], "", func(v, _pose): _armour_with_body(v)],
		["a walk whose body rose as its legs spread (the feet off the ground mid-stride)",
			"romans spear", ["B5 walking, the lowest foot on the ground line"], "", func(v, pose): _old_bob(v, pose)],
		["a 3D truth with the first leg's part at every hip, unturned (a cat's hind legs as forelegs)",
			"frog on newt_fire", ["B6 the 3D truth has the unit's legs, one for one"], "old_truth", Callable()],
		["newt legs drawn whole over its body (the legs on its back: Dominic)",
			"frog on newt_fire", ["legs and head over the body only where the model shows them"], "uncut", Callable()],
		["newt legs folded up off the ground facing left (the legs not turned to their side: Dominic)",
			"frog on newt_fire", ["B5 a near foot in sight", "B5 standing feet on the ground"], "unturned", Callable()],
		["a centaur's kneel to forage picked by screen x and bent as if side-on (from behind: a flank's legs folded sideways, the hind end sunk: Dominic, 2026-10-17)",
			"centaur romans worker", ["K1 a kneel folds the fore legs", "K2 a folded shin lies back along the ground", "K4 kneeling, the hind hooves stay planted"], "", func(v, pose): _old_kneel(v, pose)],
	]
	list += composite_fixtures()
	await pc.bake(kit, list.map(func(f): return cases[f[1]]))
	var ok := true
	var lines := []
	for f in list:
		var u: Dictionary = cases[f[1]]
		var bad: Dictionary = await _rules(pc, holder, lib, f[1], u, f[3], f[4])
		var good: Dictionary = await _rules(pc, holder, lib, f[1], u, "", Callable())
		var caught: Array = f[2].filter(func(r): return bad.has(r))
		var still: Array = caught.filter(func(r): return good.has(r))
		var passed := not caught.is_empty() and still.is_empty()
		ok = ok and passed
		var msg: String = bad[caught[0]] if not caught.is_empty() else "no failure; it fails only " + str(bad.keys())
		lines.append("%s fixture: %s\n      FAILS %s (%s)%s" % ["PASS" if passed else "BROKEN", f[0], ", ".join(caught) if not caught.is_empty() else str(f[2]),
			msg, "" if still.is_empty() else "\n      but the control fails too: " + ", ".join(still)])
	return [ok, lines]


## The rules the unit fails (rule -> first failing view) with the fixture's setup and tweak.
static func _rules(pc, holder: Node2D, lib, label: String, u: Dictionary, setup: String, tweak: Callable) -> Dictionary:
	var keep := [pc.results, pc.order, pc.metrics]
	pc.results = {}
	pc.order = []
	pc.metrics = true
	match setup:
		"old_truth":
			pc.old_truth = true
		"uncut":
			lib.parts["body.newt"].cut = lib.parts["body.newt"].cut.filter(func(c): return c != "legs")
			await _rebake(pc, lib, u, "")
		"unturned":
			UnitModels.mirror_legs = false
			await _rebake(pc, lib, u, "leg.newt~")
	await pc.check_case(holder, label, u, tweak)
	match setup:
		"old_truth":
			pc.old_truth = false
		"uncut":
			lib.parts["body.newt"].cut.append("legs")
		"unturned":
			UnitModels.mirror_legs = true
			await _rebake(pc, lib, u, "leg.newt~")
	pc.clear_caches()
	var out := {}
	for key in pc.order:
		if not pc.results[key].is_empty():
			out[key.get_slice("|", 0)] = pc.results[key][0]
	pc.results = keep[0]
	pc.order = keep[1]
	pc.metrics = keep[2]
	return out


## Bakes the unit's parts again, those whose keys contain `fresh` from scratch (the disk cache off:
## an old configuration's bake has the same key as today's).
static func _rebake(pc, lib, u: Dictionary, fresh: String) -> void:
	if fresh != "":
		for k in PartShape.baked.keys():
			if fresh in k:
				PartShape.baked.erase(k)
	var was: bool = BakeCache.enabled
	BakeCache.enabled = fresh == ""
	var kit := ArtKit.new()   # (a kit bakes a job once: a new one bakes it again)
	kit.lib = lib
	pc.add_child(kit)
	await pc.get_tree().process_frame
	await pc.bake(kit, [u])
	kit.queue_free()
	BakeCache.enabled = was
	pc.clear_caches()


## The rider's leg at its standing length and the rider dropped a fixed 6 below the seat, as when
## Dominic saw "tiny legs".
static func _short_rider_legs(v) -> void:
	var rig: Dictionary = PartShape.rigs.get(v._facing_body + PartShape.facing_suffix(v.facing_k), {})
	if rig.has("sockets") and rig.sockets.has("seat"):
		v.seat_node.position = rig.sockets.seat + Vector2(0, 6)
	for leg in v.legs:
		if leg.cling:
			leg.node.scale.y = 0.6   # the leg before D-173 (11 long, the heroic one 18): at its standing length it ended at the spine


## Shows the rider's leg the old way: the one whose hip is nearer the camera (by depth, not by side).
static func _old_rider_leg(v) -> void:
	var rig: Dictionary = PartShape.rigs.get(v.recipe.body + v._hold_suffix + PartShape.facing_suffix(v.facing_k), {})
	for leg in v.legs:
		if not leg.cling:
			continue
		for a in rig.get("anchors", []):
			if float(a[3]) > 0.0:
				leg.node.position = Vector2(float(a[0]), float(a[1]))


static func _wings_over(v) -> void:
	if v.back_node != null:
		v.back_node.set_meta("z", 1.6)
	for c in v.bob.get_children():
		for n in c.get_children():
			if n is PartShape and n.has_meta("buzz"):
				n.set_meta("z", 1.6)


static func _far_legs_over(v) -> void:
	for leg in v.legs:
		if leg.node.get_meta("z", 0) < 0:
			leg.node.set_meta("z", 1)


static func _weapon_under(v, pose := "") -> void:
	if v.weapon != null:
		v.weapon.set_meta("z", -4)
	if pose == "walk0" and v.gait.get("hop", false):
		v.bob.rotation = -0.18   # the hop as it was then: nose up at the start of a hop (before 2026-10-13)


## Puts the body's own pixels into its worn armour's sprite, as the bake did before the body was
## painted as the holdout.
static func _armour_with_body(v) -> void:
	var body: PartShape = null
	var armour: PartShape = null
	for n in v.find_children("*", "Node2D", true, false):
		if n is PartShape and not n.front and n.part_id.begins_with("body."):
			body = n
		if n is PartShape and n.part_id.begins_with("armour.") and "~" in n.part_id:
			armour = n
	if body == null or armour == null:
		return
	var bb: Variant = body.bake_of()
	var ab: Variant = armour.bake_of()
	if bb == null or ab == null:
		return
	var key: String = armour.part_id.get_slice("~", 0) + "~fixture%d" % v.facing_k   # (its base part stays the armour)
	if not PartShape.baked.has(PartShape.bake_key(key, armour.shapes, PartShape.team_neutral(armour.colours))):
		var bi: Image = bb.img
		var ai: Image = ab.img
		var lo: Vector2 = -(bb.origin as Vector2).max(ab.origin)
		var hi: Vector2 = (Vector2(bi.get_size()) - bb.origin).max(Vector2(ai.get_size()) - ab.origin)
		var img := Image.create(ceili(hi.x - lo.x), ceili(hi.y - lo.y), false, Image.FORMAT_RGBA8)
		img.blit_rect(bi, Rect2i(Vector2i.ZERO, bi.get_size()), Vector2i(-lo - bb.origin))
		img.blend_rect(ai, Rect2i(Vector2i.ZERO, ai.get_size()), Vector2i(-lo - ab.origin))
		PartShape.baked[PartShape.bake_key(key, armour.shapes, PartShape.team_neutral(armour.colours))] = {"img": img, "origin": -lo, "scale": ab.scale}
	armour.part_id = key
	armour.facing = 0


static func _old_bob(v, pose: String) -> void:
	if pose.begins_with("walk"):
		v.bob.position.y = -absf(sin(v.phase)) * float(v.gait.bob)


## The fused mount's kneel as it was until 2026-10-17 (round C1, drawn side-on): the two legs furthest
## right on screen fold, their shins swing back as if the body faced right, and the body turns about
## the two legs furthest left. Put on a foraging view after UnitView's own kneel is taken off.
static func _old_kneel(v, pose: String) -> void:
	if pose != "forage" or v.kneel <= 0.0:
		return
	var kneel: float = v.kneel
	v.bob.rotation = 0.0
	v.bob.position.x = 0.0
	if v.seat_node != null and v.seat_node.has_meta("rest"):
		v.seat_node.position = v.seat_node.get_meta("rest")
	for leg in v.legs:
		leg.node.rotation = 0.0
		leg.node.scale.y = leg.reach
		if leg.has("shin"):
			leg.shin.visible = false
	var xs: Array = v.legs.map(func(l): return l.node.position.x)
	xs.sort()
	var mid: float = (xs[1] + xs[2]) * 0.5
	for leg in v.legs:
		if leg.node.position.x <= mid:
			continue
		var upper := 1.0 - 0.45 * kneel
		leg.node.scale.y = upper
		leg.node.rotation += 0.1 * kneel
		var shin: Node2D = leg.get("shin")
		if shin == null:
			shin = v._shape()
			shin.part_id = leg.node.part_id
			shin.facing = leg.node.facing
			shin.shade = leg.node.shade
			shin.setup(leg.node.shapes, leg.node.colours)
			shin.set_meta("z", leg.node.get_meta("z", 0))
			leg.node.add_sibling(shin)
			leg.shin = shin
		shin.visible = true
		shin.position = leg.node.position + Vector2(0.0, -leg.rest.y * upper).rotated(leg.node.rotation)
		shin.rotation = leg.node.rotation + 1.45 * kneel
		shin.scale = Vector2(leg.node.scale.x, 0.5)
	var a := 0.17 * kneel
	var pivot := Vector2((xs[0] + xs[1]) * 0.5, 0.0)
	v.bob.rotation += a
	v.bob.position += pivot - pivot.rotated(a)
	if v.seat_node != null:
		v.seat_node.rotation = -0.4 * kneel
		v.seat_node.position.x -= 1.5 * kneel


## Composites put back (tests/placement/composite_2d.gd): TC1 A for rats as Dominic saw it ("this is
## bugged, did the tests not catch it?"): the hauler's layer was its side's plus a little, over every crew
## member on that side, so the rat leading the cat drew under the cat and stood inside it.
static func composite_fixtures() -> Array:
	return [
		["a hand leading TC1 A's beast drawn under it (the hauler layered over every crew member on its side; first seen as the rats' cat: since the rats stand back by their hunch, crew_back, they no longer overlap it, so the Romans' pony carries the fixture)",
			"composite: romans tc1_a_timber hauled by a pony", ["C4 composite members drawn in depth order"], "", func(v, _pose): _hauler_over_crew(v)],
		["the hauling cat's near hind leg gone in its walk (a member's walk steps were never checked, nor baked)",
			"composite: sewer rats tc1_a_junk hauled by a cat", ["B6 every hip's leg in every walk step"], "", func(v, pose): _hauler_hind_leg_gone(v, pose)],
	]


## The layers as UnitView first gave them (round TC1): crew by their own order, a hauler over them all.
static func _hauler_over_crew(v) -> void:
	var n := 0
	for c in v.crew:
		var side := 1.0 if float(c.view.get_meta("z", 0.0)) > 0.0 else -1.0
		if c.socket.begins_with("haul"):
			c.view.set_meta("z", side + 0.005)
		else:
			c.view.set_meta("z", side + n * 0.01)
			n += 1


## The hauler's near hind leg not drawn while it walks.
static func _hauler_hind_leg_gone(v, pose: String) -> void:
	if not pose.begins_with("walk"):
		return
	for c in v.crew:
		if c.socket.begins_with("haul"):
			for leg in c.view.legs:
				if leg.walk_id.ends_with("_hind") and leg.node.get_meta("z", 0) > 0.6:
					leg.node.visible = false
