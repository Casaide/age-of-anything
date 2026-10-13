extends RefCounted
## Regression fixtures for the 3D placement check (geometry_check.gd): each puts back a configuration
## Dominic caught (an old model, anchor, lean or rule) and asserts the check FAILS it with the rule
## that names the bug, then that the same unit passes that rule as it is now (the control). A fixture
## that doesn't fail is a check that has gone blind. Headless; run by tests/run_tests.gd and
## tests/placement_check.gd.

const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const Cases := preload("res://tests/placement/cases.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")


## [ok, lines]: ok when every fixture failed its rule and passed its control.
static func run(lib) -> Array:
	var cases := {}
	for c in Cases.all(lib):
		cases[c[0]] = c[1]
	var human: Dictionary = cases["romans spear"].duplicate(true)
	human.recipe.parts["head_gear"] = "helm.cap"
	var list := [
		["newt legs not reaching the ground facing left (legs not turned to their side: the far legs' feet under the belly)",
			"frog on newt_fire", ["A4 feet out to their own side", "A1 weight over the feet"],
			func(_g): UnitModels.mirror_legs = false, func(_g): UnitModels.mirror_legs = true, {}],
		["the rat's head floating ahead of its body with a gap at the neck (its body leaning back: Dominic's crossbowman)",
			"sewer rats archer", ["A2 head joint on its body's surface"],
			func(_g): UnitModels.rat_hunch = -15.0, func(_g): UnitModels.rat_hunch = 15.0, {}],
		["the rat's head on its armour, both in front of the body (the body leaning back out of its bottle-cap armour)",
			"sewer rats spear age 2", ["A2 worn armour centred on the torso", "A2 worn armour on its body"],
			func(_g): UnitModels.rat_hunch = -15.0, func(_g): UnitModels.rat_hunch = 15.0, {}],
		["a walk whose body rose as its legs spread (no foot on the ground mid-stride)",
			"romans spear", ["A1 walking, a foot planted"],
			func(g): g.rig.old_bob = true, func(g): g.rig.old_bob = false, {}],
		["a frog sunk into the hummingbird it rides (riders dropped a fixed amount below the seat)",
			"frog on hummingbird", ["A2 rider not sunk into its mount", "A2 the seat on its mount's back"],
			func(g): g.rig.old_seat = true, func(g): g.rig.old_seat = false, {}],
		["a beetle's legs as one sprite for every hip (far feet under the belly, rear legs facing forward)",
			"rat on beetle", ["A2 one-sided legs baked at each hip", "A4 feet out to their own side"],
			func(g): g.lib.parts["body.beetle"].cut = g.lib.parts["body.beetle"].cut.filter(func(c): return c != "legs"), func(g): g.lib.parts["body.beetle"].cut.append("legs"), {}],
		["the leather cap's brim across the brows like a headband (the cap before it sat higher)",
			"human in a leather cap", ["A2 an open cap clear of the brow"],
			func(g): g.rig.overrides["helm.cap"] = func(c): return _old_cap(g.rig.models, c), func(g): g.rig.overrides.erase("helm.cap"), human],
	]
	var ok := true
	var lines := []
	for f in list:
		var u: Dictionary = f[5] if not f[5].is_empty() else cases[f[1]]
		var bad := _rules(lib, f[1], u, f[3], f[4])
		var good := _rules(lib, f[1], u, Callable(), Callable())
		var caught: Array = f[2].filter(func(r): return bad.has(r))
		var still: Array = caught.filter(func(r): return good.has(r))
		var passed := not caught.is_empty() and still.is_empty()
		ok = ok and passed
		var msg: String = bad[caught[0]] if not caught.is_empty() else "no failure"
		lines.append("%s fixture: %s\n      FAILS %s (%s)%s" % ["PASS" if passed else "BROKEN", f[0], ", ".join(caught) if not caught.is_empty() else str(f[2]),
			msg, "" if still.is_empty() else "\n      but the control fails too: " + ", ".join(still)])
	return [ok, lines]


## The rules a unit fails (rule -> first failing view) with the fixture's setup applied.
static func _rules(lib, label: String, u: Dictionary, on: Callable, off: Callable) -> Dictionary:
	var g = GeometryCheck.new(lib)
	g.metrics = true
	if on.is_valid():
		on.call(g)
	g.check(label, u)
	if off.is_valid():
		off.call(g)
	var out := {}
	for key in g.order:
		if not g.results[key].is_empty():
			out[key.get_slice("|", 0)] = g.results[key][0]
	return out


## The leather cap before 2026-10-12 (commit 985cced): half a unit lower, its brim a darker band.
static func _old_cap(m, c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather = m.surf("leather", Color(0.9, 0.82, 0.72), 3.0)
	n.add_child(m.dome(Vector3(4.9, 3.6, 4.7), leather, Vector3(0, -3.0, 0)))
	n.add_child(m.ring(4.6, 5.3, m.surf("leather", Color(0.7, 0.6, 0.5), 2.0), Vector3(0, -3.0, 0)))
	n.add_child(m.blob(Vector3(0.6, 0.6, 0.6), leather, Vector3(0, 0.7, 0)))
	return {"node": n}
