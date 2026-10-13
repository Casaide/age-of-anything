extends SceneTree
## The walls' join check (milestone 16; Dominic: the walls are "a bit buggy and overlappy"). Not a
## look: a measurement. For each fixture (a few wall pieces laid out as a player lays them: straight
## runs, corners, a T, diagonals, gatehouses, wall towers, units up on the walkway) it makes two id
## maps, one colour per piece and per unit:
##   truth     every piece's 3D model (post plus the arms its links give it, the tower, the gate turned
##             its way) in one scene, with a stand-in for each unit on the walkway at its piece's
##             height, baked once: what the camera really sees;
##   composed  the game's own sprites (ArtKit's wall looks, bodies and front layers) and the units'
##             stand-ins laid out as the game draws them: each at its anchor, in the y-sorted layer's
##             order (pieces by their footprint's centre, units on a walkway just after their piece
##             and before its near merlons: BuildingArt.perch_sort_y, FRONT_SORT_PX), lifted by the
##             piece's walk_px.
## Where the two disagree past a pixel's slack at edges, something overlaps that shouldn't (a piece
## drawn over one in front of it, an arm through a tower), a gap shows that the model doesn't have, or
## a unit is hidden, floating or sunk. Also checks each walkway's height (Models.WALK_H) against the
## top of its model, so units stand on the stone. Prints PASS/FAIL per fixture with the worst pairs;
## exit 1 on any failure. Needs a window (it bakes):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/wall_join_check.gd -- [filter] [arch] [debug]
## debug writes truth | composed | difference per fixture to /tmp/wall_join_<n>.png.

const ArtKit := preload("res://src/view/art/art_kit.gd")
const Models := preload("res://src/view/art/bake/models.gd")
const BuildingArt := preload("res://src/view/art/building_art.gd")
const Baker := preload("res://src/view/art/bake/baker.gd")
const Iso := preload("res://src/view/iso.gd")

## Pieces: [type, x, y] or ["stone_gate", x, y, along] (Economy.dims: 0 along x, 1 along y, 2 the
## (1, 1) diagonal, 3 the (1, -1) one); units: cells up on the walkway, [x, y] at the cell's middle or
## [x, y, fx, fy] at that point of it (the sim's standing places: walls.gd spot). `expect`: fixtures written for a
## bug not fixed yet (the design round decides): they report, but don't fail the run.
const FIXTURES := [
	{"name": "straight run along x, a tower in it", "pieces": [["wall", 0, 0], ["wall", 1, 0], ["wall_tower", 2, 0], ["wall", 3, 0], ["wall", 4, 0]],
		"units": [[1, 0], [2, 0], [3, 0]]},
	{"name": "straight run along y, a tower in it", "pieces": [["wall", 0, 0], ["wall", 0, 1], ["wall_tower", 0, 2], ["wall", 0, 3], ["wall", 0, 4]],
		"units": [[0, 1], [0, 2], [0, 3]]},
	{"name": "corner, plain", "pieces": [["wall", 0, 0], ["wall", 0, 1], ["wall", 0, 2], ["wall", 1, 2], ["wall", 2, 2]],
		"units": [[0, 1], [0, 2], [1, 2]]},
	{"name": "corner, a tower on it", "pieces": [["wall", 0, 0], ["wall", 0, 1], ["wall_tower", 0, 2], ["wall", 1, 2], ["wall", 2, 2]],
		"units": [[0, 1], [0, 2], [1, 2]]},
	{"name": "corner the other way", "pieces": [["wall", 0, 0], ["wall", 1, 0], ["wall", 2, 0], ["wall", 2, 1], ["wall", 2, 2]],
		"units": [[1, 0], [2, 0], [2, 1]]},
	{"name": "T junction", "pieces": [["wall", 0, 0], ["wall", 1, 0], ["wall", 2, 0], ["wall", 3, 0], ["wall", 4, 0], ["wall", 2, 1], ["wall", 2, 2]],
		"units": [[1, 0], [2, 0], [2, 1]]},
	{"name": "diagonal down the screen, a tower in it", "pieces": [["wall", 0, 0], ["wall", 1, 1], ["wall_tower", 2, 2], ["wall", 3, 3], ["wall", 4, 4]],
		"units": [[1, 1], [2, 2], [3, 3]]},
	{"name": "diagonal across the screen", "pieces": [["wall", 0, 4], ["wall", 1, 3], ["wall", 2, 2], ["wall", 3, 1], ["wall", 4, 0]],
		"units": [[1, 3], [2, 2], [3, 1]]},
	{"name": "gatehouse along x", "pieces": [["wall", 0, 0], ["stone_gate", 1, 0, 0], ["wall", 4, 0]],
		"units": [[0, 0], [1, 0], [2, 0], [3, 0, 0.25, 0.5]]},
	{"name": "gatehouse along y", "pieces": [["wall", 0, 0], ["stone_gate", 0, 1, 1], ["wall", 0, 4]],
		"units": [[0, 0], [0, 1], [0, 2], [0, 3, 0.5, 0.25]]},
	{"name": "gatehouse on the down-screen diagonal", "pieces": [["wall", 0, 0], ["stone_gate", 1, 1, 2], ["wall", 4, 4]],
		"units": [[0, 0], [1, 1, 0.323, 0.323], [2, 2], [3, 3, 0.323, 0.323]]},
	{"name": "gatehouse on the across diagonal", "pieces": [["wall", 4, 0], ["stone_gate", 1, 1, 3], ["wall", 0, 4]],
		"units": [[4, 0], [3, 1, 0.677, 0.323], [2, 2], [1, 3, 0.677, 0.323]]},
	{"name": "gatehouse floor over the passage, units across it", "pieces": [["wall", 0, 0], ["stone_gate", 1, 0, 0], ["wall", 4, 0]],
		"units": [[2, 0, 0.25, 0.5], [2, 0], [2, 0, 0.75, 0.5], [3, 0, 0.25, 0.5]]},
	{"name": "gatehouse beside a tower", "pieces": [["wall_tower", 0, 0], ["stone_gate", 1, 0, 0], ["wall_tower", 4, 0], ["wall", 5, 0]],
		"units": [[0, 0], [2, 0], [4, 0]]},
]

## Walkways whose model doesn't have the floor yet, waiting on a design round: reported, not failed.
## (Empty since walls round 3: the gatehouse has its floor over the passage.)
const KNOWN_HEIGHTS := {}

## One colour per id (0 is the background).
const IDS := [Color("#000000"), Color("#ff0000"), Color("#00ff00"), Color("#0000ff"), Color("#ffff00"), Color("#ff00ff"), Color("#00ffff"),
	Color("#ff8000"), Color("#8000ff"), Color("#00ff80"), Color("#ff0080"), Color("#80ff00"), Color("#0080ff"), Color("#804000"),
	Color("#ffffff"), Color("#408080"), Color("#808040"), Color("#c08080")]
const UNIT_BOX := Vector3(0.2, 0.6, 0.2)   # a unit's stand-in (model units)
const BLEND := 255        # a truth pixel that's a blend of colours at an edge: never counted
const SLACK := 1         # pixels of slack along every edge (each piece is pixelized on its own in the game)
const TOLERANCE := 8      # art pixels of one wrong pair past the slack before it fails

var kit
var baker
var models
var arch := "stone"
var failures := 0
var legacy := false   # "legacy": units laid out as the game did before the fix (22 px up, a tower 33, sorted on their own point, no front layer), to show the fixtures catch it


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var debug := "debug" in args
	legacy = "legacy" in args
	var filter := ""
	for a in args:
		if a in ["stone", "junk", "reed", "mound", "thatch", "tent"]:
			arch = a
		elif not a in ["debug", "legacy"]:
			filter = a
	kit = ArtKit.new()
	root.add_child(kit)
	await process_frame
	baker = await kit._hifi_baker()
	models = kit._models
	# A bigger frame than the building bakes: a fixture is several tiles.
	baker.size = Vector2i(4096, 4096)
	baker.cam.size = 4096.0 / (Baker.PX_PER_UNIT * ArtKit.ART_SCALE * ArtKit.SS)
	for t in ["wall", "wall_tower", "stone_gate"]:
		var suffixes := [""] if t != "stone_gate" else ArtKit.ALONG
		for suffix in suffixes:
			var e: Dictionary = await kit._bake_building(baker, models, arch, t, "", suffix)
			kit.bakes.merge(e.bakes, true)
			kit.buildings["%s:%s%s" % [arch, t, suffix]] = e.info
	_check_heights()
	var n := 0
	for f in FIXTURES:
		n += 1
		if filter != "" and not filter.to_lower() in f.name.to_lower():
			continue
		await _check(f, n, debug)
	print("\n%s: %d failed" % ["wall join check", failures])
	quit(1 if failures > 0 else 0)


## Each walkway type's WALK_H against its model: the highest top of the pieces under the tile's
## middle that aren't merlons (the walkway's floor), within a hundredth of a unit.
func _check_heights() -> void:
	for t in Models.WALK_H:
		var spec: Dictionary = kit._placed(models, arch, t, "", "")
		var top := _floor_top(spec.body, Transform3D.IDENTITY)
		if spec.has("arms"):
			for a in spec.arms:
				top = maxf(top, _floor_top(a, Transform3D.IDENTITY))
		var ok: bool = absf(top - Models.WALK_H[t]) < 0.011
		var known: bool = not ok and KNOWN_HEIGHTS.has(t)
		print("%s height: %s walkway %.2f, model top %.2f%s" % ["PASS" if ok else "KNOWN" if known else "FAIL", t, Models.WALK_H[t], top,
			"  (known: %s)" % KNOWN_HEIGHTS[t] if known else ""])
		if not ok and not known:
			failures += 1
		if t == "stone_gate":   # its flanking towers' floors: the wall tower's height
			for x in [-1.5 + Models.GATE_TOWER_W / 2, 1.5 - Models.GATE_TOWER_W / 2]:
				var tt := _floor_top(spec.body, Transform3D.IDENTITY, Vector2(x, 0))
				var tok: bool = absf(tt - Models.WALK_H.wall_tower) < 0.011
				print("%s height: stone_gate tower at x %.1f walkway %.2f, model top %.2f" % ["PASS" if tok else "FAIL", x, Models.WALK_H.wall_tower, tt])
				if not tok:
					failures += 1
		_free_spec(spec)


func _floor_top(node: Node3D, parent: Transform3D, at := Vector2.ZERO) -> float:
	var t := parent * node.transform
	var top := -1.0
	if node is MeshInstance3D and not node.has_meta("parapet") and not node.has_meta("roof") and node.visible:
		var box: AABB = t * (node as MeshInstance3D).get_aabb()
		if box.position.x <= at.x and box.end.x >= at.x and box.position.z <= at.y and box.end.z >= at.y:
			top = box.end.y
	for c in node.get_children():
		if c is Node3D:
			top = maxf(top, _floor_top(c, t, at))
	return top


func _free_spec(spec: Dictionary) -> void:
	for key in ["body", "open", "icon", "banner", "vane"]:
		if spec.has(key) and is_instance_valid(spec[key]):
			spec[key].free()
	for a in spec.get("arms", []):
		if is_instance_valid(a):
			a.free()


## A fixture's pieces: [{type, cx, cy, sx, sy, along, cells}] with their footprints.
func _pieces(f: Dictionary) -> Array:
	var out := []
	for p in f.pieces:
		var along: int = p[3] if p.size() > 3 else 0
		var cells := []
		var sx := 1
		var sy := 1
		if p[0] == "stone_gate":
			for k in 3:
				cells.append([Vector2i(p[1] + k, p[2]), Vector2i(p[1], p[2] + k), Vector2i(p[1] + k, p[2] + k), Vector2i(p[1] + 2 - k, p[2] + k)][along])
			sx = 1 if along == 1 else 3
			sy = 1 if along == 0 else 3
		else:
			cells.append(Vector2i(p[1], p[2]))
		out.append({"type": p[0], "cx": p[1], "cy": p[2], "sx": sx, "sy": sy, "along": along, "cells": cells})
	return out


func _check(f: Dictionary, n: int, debug: bool) -> void:
	var pieces := _pieces(f)
	var at := {}   # cell -> piece index
	for i in pieces.size():
		for c in pieces[i].cells:
			at[c] = i
	var lo := Vector2(1e9, 1e9)
	var hi := -lo
	for c in at:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x + 1), maxf(hi.y, c.y + 1))
	var mid := (lo + hi) * 0.5   # the fixture's middle sits on the bake's origin
	# The truth: every model in one scene, an id colour on each.
	var scene := Node3D.new()
	var anchors := []   # 3D points: each piece's footprint centre, then each unit's ground point
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var node := _model(p, at)
		var centre := Vector3(p.cx + p.sx * 0.5 - mid.x, 0, p.cy + p.sy * 0.5 - mid.y)
		node.position = centre
		_paint(node, IDS[1 + i])
		scene.add_child(node)
		anchors.append(centre)
	var gaps := _gaps(pieces, at, scene)
	var units := []   # [cell, piece index, id]
	for u in f.units:
		var c := Vector2i(u[0], u[1])
		var i: int = at[c]
		var id := 1 + pieces.size() + units.size()
		var sim := Vector2(c.x + (u[2] if u.size() > 2 else 0.5), c.y + (u[3] if u.size() > 3 else 0.5))   # sim tiles
		units.append([c, i, id, sim])
		var g := Vector3(sim.x - mid.x, 0, sim.y - mid.y)
		var stand := _unit_box(IDS[id])
		stand.position = g + Vector3(0, _walk_h(pieces[i], sim) + UNIT_BOX.y / 2, 0)
		scene.add_child(stand)
		anchors.append(g)
	_flat_env(true)
	baker.set_ground_shadow(false)
	var truth_bake: Dictionary = await baker.bake(scene, anchors)
	var proxy: Dictionary = await baker.bake(_unit_box(Color.WHITE), [Vector3.ZERO, Vector3(0, -UNIT_BOX.y / 2, 0)])
	_flat_env(false)
	var truth_img: Image = (truth_bake.tex as Texture2D).get_image()
	truth_img.convert(Image.FORMAT_RGBA8)
	var w := truth_img.get_width()
	var h := truth_img.get_height()
	var truth := _decode(truth_img)
	# The composed: the game's sprites in the game's order.
	var draws := []   # [sort y, order, image, top-left in the truth image, id]
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var screen: Vector2 = truth_bake.points[i]
		var sort_y := screen.y / ArtKit.ART_SCALE
		var look := _look(p, at)
		draws.append([sort_y, i, look.img, screen - look.origin, 1 + i])
		if look.has("front_img"):
			draws.append([sort_y + (0.0 if legacy else BuildingArt.FRONT_SORT_PX), i, look.front_img, screen - look.front_origin, 1 + i])
		for pt in look.get("parts", []):   # a gatehouse's towers with layers of their own, sorted on their middles
			var dy: float = Iso.to_screen(pt.at.x * 1000.0, pt.at.y * 1000.0).y
			draws.append([sort_y + dy, i, pt.img, screen - pt.origin, 1 + i])
			draws.append([sort_y + dy + BuildingArt.FRONT_SORT_PX, i, pt.front_img, screen - pt.front_origin, 1 + i])
	var walk := func(i: int, sim: Vector2) -> float:
		if legacy:
			return 33.0 if pieces[i].type == "wall_tower" else 22.0
		var bv := _view(pieces[i], 0.0)   # the game's own rule for how high a unit stands on this piece here
		var px: float = bv.walk_at(sim)
		_free_view(bv)
		return px
	var pimg: Image = (proxy.tex as Texture2D).get_image()
	pimg.convert(Image.FORMAT_RGBA8)
	var foot: Vector2 = proxy.points[1]   # the stand-in's feet in its own bake
	for k in units.size():
		var i: int = units[k][1]
		var ground: Vector2 = truth_bake.points[pieces.size() + k]
		var sort_y := ground.y / ArtKit.ART_SCALE if legacy else _perch_sort(pieces[i], truth_bake.points[i].y / ArtKit.ART_SCALE, units[k][3], ground.y / ArtKit.ART_SCALE)
		var feet := ground - Vector2(0, walk.call(i, units[k][3]) * ArtKit.ART_SCALE)
		draws.append([sort_y, 1000 + k, pimg, feet - foot, units[k][2]])
	draws.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var composed := PackedByteArray()
	composed.resize(w * h)
	for d in draws:
		var img: Image = d[2]
		var o := Vector2i((d[3] as Vector2).round())
		for y in img.get_height():
			for x in img.get_width():
				var px := o + Vector2i(x, y)
				if px.x < 0 or px.y < 0 or px.x >= w or px.y >= h:
					continue
				if img.get_pixel(x, y).a8 == 255:   # the art, not its shadow
					composed[px.y * w + px.x] = d[4]
	# Compare past the slack: a pixel counts when it and its neighbours agree within each map.
	var pairs := {}
	var diff := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(SLACK, h - SLACK):
		for x in range(SLACK, w - SLACK):
			var t: int = truth[y * w + x]
			var c: int = composed[y * w + x]
			if t == c or t == BLEND:
				continue
			if not _settled(truth, w, x, y) or not _settled(composed, w, x, y):
				continue
			var key := "%d>%d" % [t, c]
			pairs[key] = pairs.get(key, 0) + 1
			diff.set_pixel(x, y, Color.RED)
	var bad := []
	for key in pairs:
		if pairs[key] > TOLERANCE:
			bad.append([pairs[key], key])
	bad.sort()
	bad.reverse()
	var label := func(id: int) -> String:
		if id == 0:
			return "nothing"
		if id <= pieces.size():
			var p: Dictionary = pieces[id - 1]
			return "%s(%d,%d)" % [p.type, p.cx, p.cy]
		var us: Vector2 = units[id - 1 - pieces.size()][3]
		return "unit(%.2f,%.2f)" % [us.x, us.y]
	var lines := []
	for b in bad.slice(0, 4):
		var ids: PackedStringArray = String(b[1]).split(">")
		lines.append("%d px: truth shows %s, game draws %s" % [b[0], label.call(int(ids[0])), label.call(int(ids[1]))])
	lines.append_array(gaps)
	if not gaps.is_empty():
		bad.append([0, "gap"])
	var expected: bool = f.has("expect")
	var verdict := "PASS" if bad.is_empty() else ("KNOWN" if expected else "FAIL")
	print("%s %s%s" % [verdict, f.name, "" if bad.is_empty() else ": " + "; ".join(lines)])
	if expected and not bad.is_empty():
		print("      (known: %s)" % f.expect)
	if verdict == "FAIL":
		failures += 1
	if debug:
		var out := Image.create(w * 3, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var t: int = truth[y * w + x]
				out.set_pixel(x, y, IDS[t] if t != BLEND else Color(0.3, 0.3, 0.3))
				out.set_pixel(w + x, y, IDS[composed[y * w + x]])
				out.set_pixel(2 * w + x, y, diff.get_pixel(x, y) if diff.get_pixel(x, y).a > 0 else IDS[t].darkened(0.7) if t != BLEND else Color.BLACK)
		out.save_png("/tmp/wall_join_%d.png" % n)


## Joined pieces must meet: where two linked pieces share an edge (or a corner, on a diagonal), each
## has solid stone (not a merlon) within GAP of that point a little above the ground. (A wall tower
## 0.86 wide left a 0.07 gap to the arms meeting it: the truth bake had the gap too, so only this sees
## it.) Returns a line per gap.
const GAP := 0.02

func _gaps(pieces: Array, at: Dictionary, scene: Node3D) -> Array:
	var boxes := []   # per piece: world boxes of its solid meshes
	for n in scene.get_children():
		var list := []
		_boxes(n, Transform3D.IDENTITY, list)
		boxes.append(list)
	var out := []
	var seen := {}
	for c in at:
		var i: int = at[c]
		if pieces[i].type != "wall":
			continue
		var links := _links(pieces[i], at)
		for k in Models.LINKS.size():
			var d: Vector2i = Models.LINKS[k]
			if not links & (1 << k):
				continue
			var j: int = at[c + d]
			var key := "%d|%d|%s" % [mini(i, j), maxi(i, j), str(Vector2(c) + Vector2(d) * 0.5)]
			if seen.has(key):
				continue
			seen[key] = true
			var lo: Vector2 = Vector2(at.keys().reduce(func(a, b): return Vector2i(mini(a.x, b.x), mini(a.y, b.y))))
			var hi := lo
			for q in at:
				hi = Vector2(maxf(hi.x, q.x + 1), maxf(hi.y, q.y + 1))
			var mid := (lo + hi) * 0.5
			var p := Vector3(c.x + 0.5 + d.x * 0.5 - mid.x, 0.3, c.y + 0.5 + d.y * 0.5 - mid.y)
			for side in [i, j]:
				var near := 1e9
				for b in boxes[side]:
					var bb: AABB = b
					var q := Vector3(clampf(p.x, bb.position.x, bb.end.x), clampf(p.y, bb.position.y, bb.end.y), clampf(p.z, bb.position.z, bb.end.z))
					near = minf(near, q.distance_to(p))
				if near > GAP:
					var pc: Dictionary = pieces[side]
					out.append("gap: %s(%d,%d) stops %.2f short of the join at (%.1f, %.1f)" % [pc.type, pc.cx, pc.cy, near, c.x + 0.5 + d.x * 0.5, c.y + 0.5 + d.y * 0.5])
	return out


func _boxes(node: Node3D, parent: Transform3D, out: Array) -> void:
	var t := parent * node.transform
	if node is MeshInstance3D and not node.has_meta("parapet"):
		var mi := node as MeshInstance3D
		if mi.mesh is BoxMesh and absf(t.basis.get_euler().y) > 0.01:
			# A turned box (a diagonal arm): its middle line, sampled, stands in for it (its world
			# AABB would reach far past its corners).
			var sz: Vector3 = (mi.mesh as BoxMesh).size
			for s in 9:
				var f := -0.5 + s / 8.0
				var q := t * Vector3(f * sz.x, 0, 0)
				out.append(AABB(q - Vector3(0.01, sz.y * 0.5, 0.01), Vector3(0.02, sz.y, 0.02)))
		else:
			out.append(t * mi.get_aabb())
	for c in node.get_children():
		if c is Node3D:
			_boxes(c, t, out)


## Is (x, y) inside a patch of one id (its four neighbours the same) in this map?
func _settled(m: PackedByteArray, w: int, x: int, y: int) -> bool:
	var v := m[y * w + x]
	for d in [-1, 1, -w, w]:
		if m[y * w + x + d] != v:
			return false
	return true


## The id map of the truth bake: each pixel's nearest id colour, BLEND where it's a blend at an edge.
func _decode(img: Image) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(img.get_width() * img.get_height())
	var data := img.get_data()
	for i in out.size():
		if data[i * 4 + 3] < 255:
			out[i] = 0
			continue
		var c := Color8(data[i * 4], data[i * 4 + 1], data[i * 4 + 2])
		var best := 0
		var best_d := 1e9
		for k in range(1, IDS.size()):
			var d := Vector3(c.r - IDS[k].r, c.g - IDS[k].g, c.b - IDS[k].b).length_squared()
			if d < best_d:
				best_d = d
				best = k
		out[i] = best if best_d < 0.06 else BLEND
	return out


## A piece's 3D model as the game would bake it: a wall's post and the arms its links give it.
func _model(p: Dictionary, at: Dictionary) -> Node3D:
	var spec: Dictionary = kit._placed(models, arch, p.type, "", ArtKit.ALONG[p.along] if p.type == "stone_gate" else "")
	var node: Node3D = spec.body
	spec.erase("body")
	if spec.has("arms"):
		var links := _links(p, at)
		var holder := Node3D.new()
		holder.add_child(node)
		for k in spec.arms.size():
			if links & (1 << k):
				holder.add_child(spec.arms[k])
				spec.arms[k] = null
		spec.arms = spec.arms.filter(func(a): return a != null)
		node = holder
	_free_spec(spec)
	return node


## A stand-in for the game's view of piece p (BuildingArt's walkway fields and tower layers, as setup
## makes them), sorted at canvas y `sort_y`: for its rules on where units up on it stand and sort.
func _view(p: Dictionary, sort_y: float) -> BuildingArt:
	var bv := BuildingArt.new()
	var info: Dictionary = kit.buildings[_name(p)]
	bv.position = Vector2(0, sort_y)
	bv.walk_px = float(info.walk_px)
	bv.walk_tower_px = float(info.get("walk_tower_px", 0.0))
	bv.walk_tower_from = float(info.get("walk_tower_from", 0.0))
	bv.walk_centre = Vector2(p.cx + p.sx * 0.5, p.cy + p.sy * 0.5)
	bv.walk_axis = BuildingArt.WALK_AXES[p.along]
	for pt in info.get("parts", []):
		var n := Node2D.new()
		n.position = Vector2(0, sort_y + Iso.to_screen(pt.at.x * 1000.0, pt.at.y * 1000.0).y)
		bv.parts.append({"node": n, "front": null, "at": pt.at})
	return bv


func _free_view(bv: BuildingArt) -> void:
	for pt in bv.parts:
		pt.node.free()
	bv.parts.clear()
	bv.free()


func _perch_sort(p: Dictionary, piece_y: float, sim: Vector2, unit_y: float) -> float:
	var bv := _view(p, piece_y)
	var y: float = bv.perch_sort_at(sim, unit_y)
	_free_view(bv)
	return y


## How high a unit stands on piece p at sim point `sim` in the 3D truth: its type's walkway, or on a
## gatehouse past its towers' start, the towers' floor.
func _walk_h(p: Dictionary, sim: Vector2) -> float:
	if p.type == "stone_gate":
		var span := 3.0 * (sqrt(2.0) if p.along >= 2 else 1.0)
		var d := absf((sim - Vector2(p.cx + p.sx * 0.5, p.cy + p.sy * 0.5)).dot(BuildingArt.WALK_AXES[p.along]))
		if d >= Models.gate_tower_from(span):
			return Models.WALK_H.wall_tower
	return Models.WALK_H[p.type]


func _links(p: Dictionary, at: Dictionary) -> int:
	var me: Vector2i = p.cells[0]
	return BuildingArt.links_of(func(d: Vector2i) -> bool: return at.has(me + d) and at[me + d] != at[me])


func _name(p: Dictionary) -> String:
	return "%s:%s%s" % [arch, p.type, ArtKit.ALONG[p.along] if p.type == "stone_gate" else ""]


## The game's sprite(s) for a piece: {img, origin, front_img?, front_origin?} (art pixels).
func _look(p: Dictionary, at: Dictionary) -> Dictionary:
	var name := _name(p)
	var info: Dictionary = kit.buildings[name]
	var out := {}
	if info.has("arms"):
		var look: Dictionary = kit.wall_look(name, _links(p, at))
		out = {"img": (look.tex as Texture2D).get_image(), "origin": look.origin}
		if look.has("front_tex"):
			out.front_img = (look.front_tex as Texture2D).get_image()
			out.front_origin = look.front_origin
	else:
		out = {"img": kit.bakes[info.body].img, "origin": kit.bakes[info.body].origin}
		if info.has("front"):
			out.front_img = kit.bakes[info.front].img
			out.front_origin = kit.bakes[info.front].origin
	for key in ["img", "front_img"]:
		if out.has(key):
			out[key] = (out[key] as Image).duplicate()
			out[key].convert(Image.FORMAT_RGBA8)
	out.parts = []
	for pt in info.get("parts", []):
		var a: Image = (kit.bakes[pt.body].img as Image).duplicate()
		var b: Image = (kit.bakes[pt.front].img as Image).duplicate()
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		out.parts.append({"img": a, "origin": kit.bakes[pt.body].origin, "front_img": b, "front_origin": kit.bakes[pt.front].origin, "at": pt.at})
	return out


func _paint(node: Node, c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	for mi in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		(mi as MeshInstance3D).material_override = m


func _unit_box(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = UNIT_BOX
	mi.mesh = b
	_paint(mi, c)
	return mi


## Flat colours for the id bake: no tone mapping, no occlusion.
var _saved := []
func _flat_env(on: bool) -> void:
	var env: Environment = baker.env
	if on:
		_saved = [env.tonemap_mode, env.tonemap_exposure, env.ssao_enabled]
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
		env.ssao_enabled = false
	else:
		env.tonemap_mode = _saved[0]
		env.tonemap_exposure = _saved[1]
		env.ssao_enabled = _saved[2]
