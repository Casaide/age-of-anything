extends RefCounted
## The 3D placement rules for composites (2026-10-13, after Dominic's "this is bugged, did the tests
## not catch it?" on TC1 A for rats: a cat pulling a cart, a rat beside it, all of it passed). A
## composite is more than one body drawn as one unit: a siege engine and its crew (the recipe's
## `crew`, UnitView composes one worker per crew socket), a cart and the beasts hauling it (the
## recipe's `haul`, one beast per haul socket), a rider on its mount (geometry_check.gd's own seat
## rules). Before this, an engine's members were checked only as a share of each inside the engine,
## standing: never against each other, never walking, a hauler never as a unit (its legs, feet, the
## harness it wears), its traces and the cart's shafts not at all. Now, at standing and at every walk
## step (crew and haulers walk while the engine rolls; crew riding on top don't):
##   C1 members apart: no member inside another (crew, haulers) beyond contact (PEN_VOX + 3% of the
##      smaller); a hauler not inside the engine, but where its harness meets the shafts (HITCH_R);
##      crew in their engine at most CREW_IN of themselves (they grip its frame: the old A3 rule).
##   C2 hitched: every haul<n> socket has its hitches (hitch<n>_near, hitch<n>_far) on the engine's
##      solid (the shafts reach them); the hauler wears a harness (a torso part tagged "harness") with
##      trace ends (trace_near, trace_far), and each trace end is on its hitch within HITCH_TOL.
##   C3 no loose ends: every rope of the engine (traces, lashings, drag lines, guy ropes: a rod whose
##      material carries the "rope" meta, siege_models.gd _style) ends on something at both ends: the
##      rest of the engine, a member, or the ground. (A pole's tip, an antenna, a goad are free to end.)
## And each member is checked as a unit in its own right (geometry_check.gd's A1 to A4: a hauler's
## feet, legs per hip in every walk step, its harness on its body), under the composite's label.
## Results go into the GeometryCheck's results (its note()), so the sheet tool and the placement
## check report them with the rest.

const Geom := preload("res://tests/placement/geom.gd")
const UnitView := preload("res://src/unit_view.gd")

const PEN_VOX := 12
const PEN_SHARE := 0.03
const CREW_IN := 0.12      # a crew member at most this share inside its engine (the old A3 crew rule)
const HITCH_TOL := 1.5     # a harness's trace end within this of its hitch on the cart (part units), standing...
const HITCH_WALK_TOL := 2.5   # ...and walking (the beast rides on its planted foot, the cart doesn't: the traces give a little)
const HITCH_R := 3.0       # a hauler may meet its engine only this near a hitch (the shaft's end on the trace)
const THIN := 0.6          # (a rope this thin or thinner: thicker is a pole)
const LOOSE_TOL := 1.0     # ...within this of it (beyond the rod's own radius)
const WALK_PHASES := 8


## Every member of an engine as UnitView composes it: [{name (socket), recipe, xf (on its socket,
## turned to its facing), hold, top, hauls}].
static func members(lib, r: Dictionary, sockets: Dictionary) -> Array:
	var out := []
	var names: Array = UnitView.engine_sockets(r, sockets)
	names.sort()
	for name in names:
		var hauls: bool = name.begins_with("haul")
		var turn := 0
		var hold := "low"
		var top := false
		for t in name.split("_"):
			if t.begins_with("f") and t.length() == 2:
				turn = int(t.substr(1))
			elif t in UnitView.WORK_HOLDS:
				hold = t
			elif t == "top":
				top = true
		var recipe := UnitView.haul_recipe(lib, r) if hauls else UnitView.crew_recipe(r)
		var s := float(recipe.get("scale", 100)) / 100.0   # (a tiny race's crew are drawn tiny)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-45.0 * turn)).scaled(Vector3.ONE * s), sockets[name])
		out.append({"name": name, "recipe": recipe, "xf": xf,
			"hold": "" if hauls else hold, "top": top, "hauls": hauls})
	return out


## Runs the composite rules on an engine recipe, into g's results.
static func check(g, label: String, r: Dictionary) -> void:
	var lib = g.lib
	var rig = g.rig
	var colours := UnitView.colours_for(lib, r.skin, r.family, Color.MAGENTA)
	var es: Dictionary = rig.spec(r.body, colours)
	var ev := Geom.voxels(es.node, Transform3D.IDENTITY)
	var sockets: Dictionary = es.get("sockets", {})
	var ms := members(lib, r, sockets)
	_loose_ends(g, label, es, ev, ms)
	for m in ms:
		if not m.hauls:
			continue
		var n: String = m.name.get_slice("_", 0).trim_prefix("haul")
		for side in ["near", "far"]:
			var h := "hitch%s_%s" % [n, side]
			g.note("C2 a hauler's hitches on the cart", label, m.name, not sockets.has(h), "no %s socket" % h)
			if sockets.has(h):
				var d := Geom.depth(ev, sockets[h], 4.0)
				g.note("C2 a hauler's hitches on the cart", label, m.name, d > 1.0, "%s %.1f off the cart (the shafts don't reach it)" % [h, d])
		var torso: String = m.recipe.parts.get("torso", "")
		g.note("C2 a hauler wears its harness", label, m.name, torso == "" or not "harness" in lib.part(torso).get("tags", []),
			"%s hauls with %s" % [m.recipe.creature, "nothing on" if torso == "" else torso])
	for i in WALK_PHASES + 1:
		var walk := -1.0 if i == 0 else TAU * (i - 1) / WALK_PHASES
		var view := "stand" if i == 0 else "walk %d" % (i - 1)
		_pose(g, label, view, walk, r, sockets, ev, ms)
	rig.clear()
	# Each member as a unit of its own (its legs, feet, gear, a hauler's harness), once per recipe.
	var seen := {}
	for m in ms:
		var sig := JSON.stringify(m.recipe, "", true)
		if not seen.has(sig):
			seen[sig] = true
			g.check(label, {"recipe": m.recipe, "eval": {"speed": 10}})


## One pose of the whole composite: members apart (C1), harness on hitch (C2).
static func _pose(g, label: String, view: String, walk: float, r: Dictionary, sockets: Dictionary, ev: Dictionary, ms: Array) -> void:
	var vox := []
	var hitches := []
	for h in sockets:
		if h.begins_with("hitch"):
			hitches.append(sockets[h])
	for m in ms:
		var w: float = walk if not m.top else -1.0
		var a: Dictionary = g.rig.unit(m.recipe, {"walk": w, "hold": m.hold} if w >= 0.0 else {"hold": m.hold})
		var v := {}
		for p in a.pieces:
			for q in Geom.voxels(p.node, m.xf * p.xf):
				v[q] = true
		vox.append(v)
		if m.hauls:
			var n: String = m.name.get_slice("_", 0).trim_prefix("haul")
			var harness := {}
			for p in a.pieces:
				if p.kind == "armour" and p.get("sockets", {}).has("trace_near"):
					harness = p
			for side in ["near", "far"]:
				var h := "hitch%s_%s" % [n, side]
				if harness.is_empty() or not sockets.has(h):
					continue   # (C2's other rules say so)
				var at: Vector3 = m.xf * harness.xf * (harness.sockets["trace_" + side] as Vector3)
				var d := at.distance_to(sockets[h])
				var tol := HITCH_TOL if walk < 0.0 else HITCH_WALK_TOL
				g.note("C2 the cart hitched to its hauler's harness", label, "%s %s" % [m.name, view], d > tol,
					"trace_%s %.1f from %s, %.1f allowed" % [side, d, h, tol])
			# The hauler clear of the cart, but where the harness meets the shafts.
			var bad := 0
			for q in v:
				if ev.has(q) and hitches.all(func(hp): return Geom.centre(q).distance_to(hp) > HITCH_R):
					bad += 1
			var allowed := PEN_VOX + int(PEN_SHARE * mini(v.size(), ev.size()))
			g.note("C1 a hauler clear of its cart", label, "%s %s" % [m.name, view], bad > allowed, "%s shares %d voxels with the cart away from its hitches, %d allowed" % [m.name, bad, allowed])
		else:
			var share := float(Geom.shared(v, ev)) / maxf(v.size(), 1)
			g.note("C1 crew not cut through their engine", label, "%s %s" % [m.name, view], share > CREW_IN, "%.2f of the crew member inside the engine" % share)
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			var common := Geom.shared(vox[i], vox[j])
			var allowed := PEN_VOX + int(PEN_SHARE * mini(vox[i].size(), vox[j].size()))
			g.note("C1 members of a composite apart", label, "%s/%s %s" % [ms[i].name, ms[j].name, view], common > allowed,
				"%s and %s share %d voxels, %d allowed" % [ms[i].name, ms[j].name, common, allowed])


## C2: a harness hugs its wearer (called from geometry_check.gd's attachment rules for a worn part
## tagged "harness"): at most HARNESS_OFF_SHARE of it more than HARNESS_OFF off the body, leaving out
## the trace tails behind the rump (they run back to the shafts).
const HARNESS_OFF := 1.5
const HARNESS_OFF_SHARE := 0.1


static func harness_on_body(g, label: String, view: String, p: Dictionary, body: Dictionary) -> void:
	var hv: Dictionary = g._vox(p)
	var bv: Dictionary = g._vox(body)
	var rear := INF
	var cells := {}   # the body on a HARNESS_OFF grid, then with the cells next to it (as geometry_check's armour rule)
	for q in bv:
		var c := Geom.centre(q)
		rear = minf(rear, c.x)
		cells[Vector3i(floori(c.x / HARNESS_OFF), floori(c.y / HARNESS_OFF), floori(c.z / HARNESS_OFF))] = true
	var coarse := {}
	for k in cells:
		for i in [-1, 0, 1]:
			for j in [-1, 0, 1]:
				for l in [-1, 0, 1]:
					coarse[k + Vector3i(i, j, l)] = true
	var n := 0
	var off := 0
	for q in hv:
		var c := Geom.centre(q)
		if c.x < rear:
			continue
		n += 1
		if not coarse.has(Vector3i(floori(c.x / HARNESS_OFF), floori(c.y / HARNESS_OFF), floori(c.z / HARNESS_OFF))):
			off += 1
	var share := float(off) / maxf(n, 1)
	g.note("C2 a harness on its hauler's body", label, view, share > HARNESS_OFF_SHARE, "%s %.2f of it off the body, %.2f allowed" % [p.id, share, HARNESS_OFF_SHARE])


## C3: every rope of the engine ends on something (the rest of the engine, a member standing, the ground).
static func _loose_ends(g, label: String, es: Dictionary, ev: Dictionary, ms: Array) -> void:
	var rods := []
	_rods(es.node, es.node.transform, rods)
	if rods.is_empty():
		return
	var mv := {}
	for m in ms:
		var a: Dictionary = g.rig.unit(m.recipe, {"hold": m.hold})
		for p in a.pieces:
			for q in Geom.voxels(p.node, m.xf * p.xf):
				mv[q] = true
	var loose := []
	for rd in rods:
		var own := Geom.voxels(rd.node, rd.xf)
		for end in [rd.a, rd.b]:
			if end.y <= LOOSE_TOL + rd.r:
				continue   # on the ground
			var reach: float = rd.r + LOOSE_TOL
			if _near(ev, own, end, reach) or _near(mv, {}, end, reach):
				continue
			loose.append("%s end at %s" % [rd.node.name if rd.node.name != "" else "rod", "(%.0f, %.0f, %.0f)" % [end.x, end.y, end.z]])
	g.note("C3 no loose ends", label, "stand", not loose.is_empty(), "%d ropes end in the air: %s" % [loose.size(), ", ".join(loose.slice(0, 3))])


## Something of `cells` (not of `own`) within reach of p.
static func _near(cells: Dictionary, own: Dictionary, p: Vector3, reach: float) -> bool:
	var c := Geom.unkey(Geom.cell(p))
	var n := ceili(reach / Geom.RES)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			for k in range(-n, n + 1):
				if Vector3(i, j, k).length() * Geom.RES > reach:
					continue
				var q := Geom.key(c.x + i, c.y + j, c.z + k)
				if cells.has(q) and not own.has(q):
					return true
	return false


## The ropes (a cylinder with a "rope" material, as UnitModels.rod builds them) under n:
## [{node, xf, a, b, r}] in the model's space.
static func _rods(n: Node, t: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var ct: Transform3D = t * (c as Node3D).transform
		var m: Material = (c as MeshInstance3D).material_override if c is MeshInstance3D else null
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh and c.visible and m != null and m.has_meta("rope"):
			var cm: CylinderMesh = (c as MeshInstance3D).mesh
			var r := maxf(cm.top_radius, cm.bottom_radius) * ct.basis.get_scale().x
			if r <= THIN and cm.height * ct.basis.get_scale().y > 4.0 * r:
				var half: Vector3 = ct.basis * Vector3(0, cm.height * 0.5, 0)
				# Its own voxels: the rod with its end caps (UnitModels.rod: a Node3D holding the cylinder
				# and two blobs), else the cylinder alone.
				var wrapped: bool = n.get_class() == "Node3D" and n.get_child_count() <= 3 and n.get_parent() != null
				out.append({"node": n if wrapped else c, "xf": t * (n as Node3D).transform.affine_inverse() if wrapped else t,
					"a": ct.origin - half, "b": ct.origin + half, "r": r})
		_rods(c, ct, out)
