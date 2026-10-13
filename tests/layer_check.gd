extends SceneTree
## The layering check (docs/rendering.md, "Layering rules"): composes every body, every mount with
## and without riders, the animals and the siege crews, in all 8 facings, standing and at three walk
## phases, and asserts the rules on the drawn pixels: each part's baked sprite is laid onto a grid
## in the unit's own space, in draw order, so "A draws over B" is a count of pixels. Legs and heads
## are held to the 3D truth: the body's model rendered with its legs and head in place, in flat
## colours, from the same camera (see _check_model). Prints a PASS or FAIL line per rule and unit
## (failures list their facings and poses), a count, and exits 1 on any failure. Needs a window:
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/layer_check.gd -- [filter] [metrics] [looks] [debug]
## filter: only cases whose label contains it. metrics: also print each failing measurement.
## looks: also every capybara look (unit_models.CAPYBARA_LOOKS; rebaked, the disk cache off).
## debug: write the 3D truth beside the composed unit for each standing view (/tmp/layer_check_*.png).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")

## Races whose every unit is checked (between them: every playable body, every hold, back parts,
## wings, a fused centaur, siege crews).
const PROMPTS := ["romans", "swamp frogs", "sewer rats", "forest beetles", "spooky spiders",
	"flying greeks with wings", "centaur romans", "winged frogs"]
## Riders (a race's spear unit, put on each mount) and the mounts.
const RIDERS := ["romans", "swamp frogs", "sewer rats", "spooky spiders", "forest beetles"]
const MOUNTS := ["pony", "beetle", "spider", "capybara", "newt", "hummingbird"]
## Poses: [name, walking, phase].
const POSES := [["stand", false, 0.0], ["walk0", true, 0.0], ["walk1", true, 2.1], ["walk2", true, 4.2]]

## Thresholds (art pixels). Tolerant of a pixel or two of outline, strict enough for a leg on a back.
const MODEL_SLACK := 6         # pixels a leg or head may differ from the 3D model by (the outline, rounding)...
const MODEL_SHARE := 0.08      # ...or this share of the part's pixels
const HIDDEN_MIN := 3          # a weapon or shield shows at least this many pixels in every facing
const ARMOUR_SHARE := 0.8      # worn armour covers at most this share of its body (a whole copy of the body is 1)
const FACE_TEAM_SHARE := 0.3   # team cloth over at most this share of a head facing the camera

var lib
var metrics := false
var results := {}   # "rule|case" -> [fails...]
var order := []
var _opaque := {}   # bake key -> PackedVector2Array of opaque pixels (relative to the origin, in part units)


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var filter := ""
	var looks := false
	for a in args:
		if a == "metrics":
			metrics = true
		elif a == "looks":
			looks = true
		elif a != "debug":
			filter = a
	lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var cases := []   # [label, unit]
	var races := []
	for p in PROMPTS:
		var race: Dictionary = gen.generate(p, rules)
		races.append(race)
		for u in race.units:
			cases.append(["%s %s" % [p, u.recipe.slot], u])
	for p in RIDERS:
		var spear: Dictionary = _slot(gen.generate(p, rules), "spear")
		for m in MOUNTS:
			cases.append(["%s on %s" % [spear.recipe.creature, m], _ride(spear, m, lib.creatures[m].skins[0], {})])
	var human: Dictionary = _slot(gen.generate("romans", rules), "spear")
	for m in ["pony", "beetle", "spider"]:   # winged mounts (a "pegasus": the mount's wings at its withers)
		cases.append(["human on winged %s" % m, _ride(human, m, lib.creatures[m].skins[0], {"back": "wings.feather"})])
	var frog: Dictionary = _slot(gen.generate("swamp frogs", rules), "spear")
	for skin in lib.creatures.newt.skins:   # every newt (the crested ones carry a crest)
		cases.append(["frog on %s" % skin, _ride(frog, "newt", skin, {})])
	var animals: Dictionary = ArtKit.animal_race()
	for u in animals.units:
		cases.append(["animal %s" % u.recipe.body, u])
	cases = cases.filter(func(c): return filter == "" or filter in c[0])
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	var bake := [{"units": cases.map(func(c): return c[1])}]
	await kit.prepare_units(bake, [team])
	var holder := Node2D.new()
	holder.visible = false
	root.add_child(holder)
	for c in cases:
		await _check_case(holder, c[0], c[1], team)
	if looks:
		BakeCache.enabled = false
		var capy := cases.filter(func(c): return "capybara" in c[0])
		for look in UnitModels.CAPYBARA_LOOKS:
			if look == UnitModels.capybara_look:
				continue
			UnitModels.capybara_look = look
			for k in PartShape.baked.keys():
				if "capybara" in k:
					PartShape.baked.erase(k)
			_opaque.clear()
			_gt_cache.clear()
			kit.queue_free()
			kit = ArtKit.new()   # (a kit bakes a job once: a new one for the new look)
			kit.lib = lib
			root.add_child(kit)
			await process_frame
			await kit.prepare_units([{"units": capy.map(func(c): return c[1])}], [team])
			for c in capy:
				await _check_case(holder, "%s (%s)" % [c[0], look], c[1], team)
	var failed := 0
	for key in order:
		var fails: Array = results[key]
		var parts: PackedStringArray = key.split("|")
		if fails.is_empty():
			print("PASS %s: %s" % [parts[0], parts[1]])
		else:
			failed += 1
			print("FAIL %s: %s in %d of its views: %s" % [parts[0], parts[1], fails.size(), ", ".join(fails.slice(0, 6)) + (" ..." if fails.size() > 6 else "")])
	print("%d checks, %d failed (%d units, %d views)" % [order.size(), failed, cases.size(), cases.size() * 8 * POSES.size()])
	quit(1 if failed > 0 else 0)


func _slot(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	assert(false, "no %s unit" % slot)
	return {}


## A unit put on a mount (only its own recipe: a unit's age line would bake instead of it).
func _ride(unit: Dictionary, mount: String, skin: String, parts: Dictionary) -> Dictionary:
	var r: Dictionary = unit.recipe.duplicate(true)
	r.mount = {"creature": mount, "fused": false, "parts": parts, "skin": skin}
	return {"recipe": r, "eval": unit.eval}


func _note(rule: String, label: String, view: String, bad: bool, detail := "") -> void:
	var key := rule + "|" + label
	if not results.has(key):
		results[key] = []
		order.append(key)
	if bad:
		results[key].append(view + (" (" + detail + ")" if metrics and detail != "" else ""))


func _check_case(holder: Node2D, label: String, u: Dictionary, team: Color) -> void:
	for k in 8:
		for pose in POSES:
			if pose[1] and u.recipe.has("crew"):
				continue   # an engine rolls; its crew's walk is a worker's, checked with the workers
			var v = UnitView.new()
			v.facing_k = k
			v.build(u.recipe, lib, team, u.eval.speed)
			v.idle_wait = 1000.0
			holder.add_child(v)
			v.walking = pose[1]
			v.phase = pose[2]
			v._process(0.0)
			v.walking = false
			if u.recipe.has("crew"):
				_check_crew(v, label, "f%d" % k)
			else:
				await _check_view(v, label, "f%d %s" % [k, pose[0]], k)
			holder.remove_child(v)
			v.free()


## Every PartShape the unit draws, in draw order, with its role and its pixels.
func _parts(v) -> Array:
	var out := []
	_collect(v, v, Transform2D.IDENTITY, out)
	return out


func _collect(v, n: Node, t: Transform2D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node2D or not c.visible:
			continue
		var ct: Transform2D = t * (c as Node2D).transform
		if c is PartShape:
			out.append(_part(v, c, ct))
		_collect(v, c, ct, out)


func _part(v, ps: PartShape, t: Transform2D) -> Dictionary:
	var p := {"node": ps, "id": ps.part_id, "kind": "", "rig": "main", "near": true, "team": 0, "cells": {}}
	if ps == v._shadow:
		p.kind = "shadow"
	else:
		var base: String = ps.part_id.get_slice("~", 0).get_slice("@", 0)
		p.kind = "arm" if ps.front else lib.part(base).slot
		var a: Node = ps.get_parent()
		while a != null and a.get_parent() != v.bob and a.get_parent() != v.seat_node:
			a = a.get_parent()
		if a != null and a.get_parent() == v.seat_node:
			p.rig = "rider"
		elif v.recipe.has("mount"):
			p.rig = "mount"
	var key := PartShape.bake_key(ps.part_id, ps.shapes, PartShape.team_neutral(ps.colours))
	if ps.facing != 0 and PartShape.baked.has(key + PartShape.facing_suffix(ps.facing)):
		key += PartShape.facing_suffix(ps.facing)
	if ps.front:
		key = PartShape.front_key(key)
	if not PartShape.baked.has(key):
		return p
	var px: Array = _pixels(key)
	var s: float = PartShape.baked[key].scale
	for i in px[0].size():
		var q: Vector2 = t * px[0][i]
		var cell := Vector2i(floori(q.x * s), floori(q.y * s))
		p.cells[cell] = true
		if px[1][i]:
			p.team += 1
			p.cells[cell] = false   # false: a team-colour pixel
	return p


## A bake's opaque pixels as points in part units (pixel centres), and which are team colour.
func _pixels(key: String) -> Array:
	if not _opaque.has(key):
		var b: Dictionary = PartShape.baked[key]
		var img: Image = b.img
		var pts := PackedVector2Array()
		var team := []
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.1:
					pts.append((Vector2(x, y) + Vector2(0.5, 0.5) - b.origin) / b.scale)
					team.append(minf(c.r, c.b) - c.g > 0.22 and absf(c.r - c.b) < 0.3)
		_opaque[key] = [pts, team]
	return _opaque[key]


## Pixels of a drawn over pixels of b (0 when a draws first).
func _over(parts: Array, a: int, b: int) -> int:
	if a < b:
		return 0
	var n := 0
	for c in parts[a].cells:
		if parts[b].cells.has(c):
			n += 1
	return n


## Pixels of part i that no later part covers.
func _visible(parts: Array, i: int) -> int:
	var n := 0
	for c in parts[i].cells:
		var hidden := false
		for j in range(i + 1, parts.size()):
			if parts[j].kind != "shadow" and parts[j].node.modulate.a > 0.9 and parts[j].cells.has(c):
				hidden = true
				break
		if not hidden:
			n += 1
	return n


func _find(parts: Array, rig: String, kind: String) -> Array:
	var out := []
	for i in parts.size():
		if parts[i].rig == rig and parts[i].kind == kind:
			out.append(i)
	return out


func _check_view(v, label: String, view: String, k: int) -> void:
	var parts := _parts(v)
	# Which legs are near (on the camera's side of the body), from the bake's anchors (3D truth).
	for leg in v.legs:
		for i in parts.size():
			if parts[i].node == leg.node:
				parts[i].near = _anchor_near(parts, i, leg.rest, k)
	# Shadows under everything.
	var shadow := _find(parts, "main", "shadow")
	_note("shadow first", label, view, shadow.is_empty() or shadow[0] != 0)
	for rig in ["main", "mount", "rider"]:
		var bodies := _find(parts, rig, "body")
		if bodies.is_empty():
			continue
		var body: int = bodies[0]
		var body_rig: Dictionary = PartShape.rigs.get(parts[body].id + PartShape.facing_suffix(k), {})
		var depth: Dictionary = body_rig.get("depth", {})
		var under: bool = body_rig.get("legs_under", false)
		for i in _find(parts, rig, "leg"):
			if not parts[i].near and not "~" in parts[i].id:   # (a leg cut by its body may draw over it: it holds only what shows)
				_note("far legs behind the body", label, view, _over(parts, i, body) > 0, "%d px" % _over(parts, i, body))
				continue
			if under:
				_note("legs under a skirt", label, view, i > body)
		var heads := _find(parts, rig, "head")
		# Legs and head show where the 3D model shows them (the body's own bake of them together).
		if rig != "rider" and view.ends_with("stand"):
			await _check_model(parts, rig, body, label, view, k)
		# Back parts: behind the body when the back faces away from the camera, over it when it faces it.
		for i in _find(parts, rig, "back"):
			var d := float(depth.get("wings" if rig == "mount" and depth.has("wings") else "back", 0.0))
			if rig == "mount":
				# A mount's wings rise from its withers: over its back, unless the withers are turned
				# away (then the rump hides their roots); under the rider always.
				_note("a mount's wings over its back, behind it turned away", label, view, (i > body) != (k == 0 or d >= -0.5))
				var rider := _find(parts, "rider", "body")
				_note("a mount's wings under the rider", label, view, not rider.is_empty() and i > rider[0])
			elif k != 0 and d < -0.5:
				_note("back parts behind the body facing the camera", label, view, _over(parts, i, body) > 0, "%d px" % _over(parts, i, body))
			elif k != 0 and d > 0.5:
				_note("back parts over the body facing away", label, view, _over(parts, body, i) > 0, "%d px" % _over(parts, body, i))
		# What the near hand holds draws over the body; a weapon or shield never vanishes.
		for slot in ["hand_r", "hand_l"]:
			for i in _find(parts, rig, slot):
				if k != 0 and float(depth.get(slot, 0.0)) >= 0.5:
					_note("near hand over the body", label, view, _over(parts, body, i) > 0, "%d px" % _over(parts, body, i))
				if k != 0 and float(depth.get(slot, 0.0)) < -0.5:
					continue   # in the far hand: the body may hide it
				var seen := _visible(parts, i)
				_note("weapons and shields show", label, view, seen < mini(HIDDEN_MIN, parts[i].cells.size()), "%s %d px seen" % [parts[i].id, seen])
		# Worn armour is baked on its body with the body cut away: it never carries a copy of the body.
		for i in _find(parts, rig, "torso"):
			if "~" in parts[i].id:
				var share := float(_over(parts, i, body)) / maxf(1.0, parts[body].cells.size())
				_note("worn armour holds no body", label, view, share > ARMOUR_SHARE, "%.2f of the body" % share)
		# Team cloth never covers a face turned to the camera.
		var dir: Vector2 = body_rig.get("dir", Vector2.RIGHT)
		if not heads.is_empty() and (k == 0 or dir.y > 0.2) and rig != "mount":
			var h: int = heads[0]
			var team := 0
			for j in range(h + 1, parts.size()):
				if parts[j].kind in ["head_gear", "shadow"] or parts[j].rig != rig:
					continue
				for c in parts[j].cells:
					if parts[j].cells[c] == false and parts[h].cells.has(c):
						team += 1
			var share := float(team) / maxf(1.0, parts[h].cells.size())
			_note("team cloth never over the face", label, view, share > FACE_TEAM_SHARE, "%.2f of the head" % share)
	# A rider sits over its mount: no mount part over the rider, its near leg down the flank shows.
	var mb := _find(parts, "mount", "body")
	if not mb.is_empty() and not _find(parts, "rider", "body").is_empty():
		var bad := 0
		for i in parts.size():
			if parts[i].rig != "mount" or parts[i].kind == "shadow":
				continue
			for j in parts.size():
				if parts[j].rig == "rider":
					bad += _over(parts, i, j)
		_note("rider over the mount", label, view, bad > 0, "%d px" % bad)
		for i in _find(parts, "rider", "leg"):
			_note("rider's near leg over the mount's flank", label, view, i < mb[0])


## A leg's side from its body's anchors in this facing: the anchor at the leg's rest position.
func _anchor_near(parts: Array, leg: int, rest: Vector2, k: int) -> bool:
	var root: Node = parts[leg].node.get_parent()
	for c in root.get_children():
		if c is PartShape and not c.front and lib.part(c.part_id.get_slice("@", 0)).slot == "body":
			var rig: Dictionary = PartShape.rigs.get(c.part_id + PartShape.facing_suffix(k), PartShape.rigs.get(c.part_id, {}))
			var anchors: Array = rig.get("anchors", lib.part(c.part_id.get_slice("@", 0)).get("legs", {}).get("anchors", []))
			for a in anchors:
				if Vector2(float(a[0]), float(a[1])).distance_to(rest) < 0.01:
					return float(a[3]) > 0.0
	return parts[leg].node.get_meta("z", 0) > 0


## The 3D truth for a body's legs and head: the body's model with its legs at their hips and its head
## on its socket, rendered from the bake camera of facing k in flat colours (body red, legs green,
## head blue), at one pixel per art pixel with the body's origin where the bake puts it. Then every
## pixel the composed unit draws is compared: a leg or head drawn over the body where the model's
## body is in front of it ("over"), or the body drawn over a leg or head the model shows ("under").
## Only pixels inside the model's regions count (not their edges), so the outline doesn't.
const ID_BODY := Color(1, 0, 0)
const ID_LEG := Color(0, 1, 0)
const ID_HEAD := Color(0, 0, 1)
var _gt_cache := {}
var _gt_baker = null


func _check_model(parts: Array, rig: String, body: int, label: String, view: String, k: int) -> void:
	var legs := _find(parts, rig, "leg")
	var heads := _find(parts, rig, "head")
	var body_id: String = parts[body].id
	if legs.is_empty() or not UnitView.UnitModelsCheck.has(body_id):
		return
	var gt: Dictionary = await _truth(parts[body].node, parts[legs[0]].node, parts[heads[0]].node if not heads.is_empty() else null, k)
	if gt.flipped:
		return
	# The composed unit in the rig's own space, at stand: each cell's topmost of body, legs, head.
	var top := {}   # cell -> [kind, part index]
	var order := [body] + legs + heads
	order.sort()
	for i in order:
		var n: PartShape = parts[i].node
		var kind := "body" if i == body else ("leg" if i in legs else "head")
		for c in _cells_in_rig(n):
			top[c] = [kind, i]
	if ("debug" in OS.get_cmdline_user_args() and view == "f%d stand" % k):
		_debug_image(gt.cells, top, "/tmp/layer_check_%s_%s_f%d.png" % [label.replace(" ", "_"), rig, k])
	var over := {}    # part index -> pixels drawn over the body where the model hides them
	var under := {}   # part index -> pixels of it the body covers where the model shows them
	for c in gt.cells:
		var want: String = gt.cells[c]
		if not _interior(gt.cells, c, want) or not top.has(c):
			continue
		var got: Array = top[c]
		if want == "body" and got[0] != "body":
			over[got[1]] = over.get(got[1], 0) + 1
		elif want != "body" and got[0] == "body":
			for i in (legs if want == "leg" else heads):
				if _cells_in_rig(parts[i].node).has(c):
					under[i] = under.get(i, 0) + 1
					break
	for i in legs + heads:
		var allowed := maxi(MODEL_SLACK, int(MODEL_SHARE * parts[i].cells.size()))
		var what := "%s %s%s" % [rig, parts[i].kind, "" if parts[i].kind == "head" else (" near" if parts[i].near else " far")]
		_note("legs and head over the body only where the model shows them", label, view, over.get(i, 0) > allowed,
			"%s %d px over the body, %d allowed" % [what, over.get(i, 0), allowed])
		_note("legs and head not hidden where the model shows them", label, view, under.get(i, 0) > allowed,
			"%s %d px hidden, %d allowed" % [what, under.get(i, 0), allowed])


## A part's opaque cells in its rig's space (its own transform only: legs, head, body are the rig root's children).
func _cells_in_rig(n: PartShape) -> Dictionary:
	if n.has_meta("rig_cells"):
		return n.get_meta("rig_cells")
	var cells := {}
	var key := PartShape.bake_key(n.part_id, n.shapes, PartShape.team_neutral(n.colours))
	if n.facing != 0 and PartShape.baked.has(key + PartShape.facing_suffix(n.facing)):
		key += PartShape.facing_suffix(n.facing)
	if n.front:
		key = PartShape.front_key(key)
	if PartShape.baked.has(key):
		var px: Array = _pixels(key)
		var s: float = PartShape.baked[key].scale
		for q in px[0]:
			var p: Vector2 = n.transform * q
			cells[Vector2i(floori(p.x * s), floori(p.y * s))] = true
	n.set_meta("rig_cells", cells)
	return cells


func _debug_image(gt: Dictionary, top: Dictionary, path: String) -> void:
	var img := Image.create(240, 120, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var cols := {"body": Color.RED, "leg": Color.GREEN, "head": Color.BLUE}
	for c in gt:
		if c.x > -60 and c.x < 60 and c.y > -100 and c.y < 20:
			img.set_pixel(c.x + 60, c.y + 100, cols[gt[c]])
	for c in top:
		if c.x > -60 and c.x < 60 and c.y > -100 and c.y < 20:
			img.set_pixel(c.x + 180, c.y + 100, cols[top[c][0]])
	img.resize(960, 480, Image.INTERPOLATE_NEAREST)
	img.save_png(path)


func _interior(cells: Dictionary, c: Vector2i, want: String) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cells.get(c + d, "") != want:
			return false
	return true


func _truth(body: PartShape, leg: PartShape, head: PartShape, k: int) -> Dictionary:
	var key := "%s|%s|%s|%d" % [PartShape.bake_key(body.part_id, body.shapes, PartShape.team_neutral(body.colours)), leg.part_id, head.part_id if head else "", k]
	if _gt_cache.has(key):
		return _gt_cache[key]
	if _gt_baker == null:
		_gt_baker = PartBaker.new()
		_gt_baker.msaa_3d = Viewport.MSAA_DISABLED
		root.add_child(_gt_baker)
	var pb = _gt_baker
	var colours := PartShape.team_neutral(body.colours)
	var spec: Dictionary = pb.models.build(body.part_id, colours)
	var model := Node3D.new()
	_paint(spec.node, ID_BODY)
	model.add_child(spec.node)
	if spec.get("front") != null:
		spec.front.free()   # the near arm is its own layer, left out on both sides (a raised arm before the face is a known limit)
	var flipped := false
	for a in spec.get("anchors", []):
		flipped = flipped or (a.size() > 3 and int(a[3]) == 1)
		var l: Node3D = pb.models.build(leg.part_id, colours).node
		_paint(l, ID_LEG)
		l.position = a[0]
		model.add_child(l)
	if head:
		var h: Node3D = pb.models.build(head.part_id, colours).node
		_paint(h, ID_HEAD)
		h.position = spec.sockets.head
		model.add_child(h)
	pb.holder.add_child(model)
	var box: AABB = pb._aabb(model)
	var r := box.size.length() * 0.5 + 2.0
	var s: float = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.size = Vector2i.ONE * ceili(2.0 * r * s)
	pb.cam.keep_aspect = Camera3D.KEEP_HEIGHT
	pb.cam.size = 2.0 * r
	var az := deg_to_rad(PartBaker.AZIMUTH + PartBaker.FACING_STEP * k)
	var el := deg_to_rad(PartBaker.ELEVATION)
	var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	pb.cam.basis = Basis.looking_at(-dir, Vector3.UP)
	pb.cam.position = box.get_center() + dir * 150.0
	await pb._render()
	var img: Image = pb.get_texture().get_image()
	var origin: Vector2 = pb.cam.unproject_position(Vector3.ZERO)
	pb.holder.remove_child(model)
	model.queue_free()
	var cells := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var id := "body" if c.r > maxf(c.g, c.b) else ("leg" if c.g > c.b else "head")
			cells[Vector2i(floori(x + 0.5 - origin.x), floori(y + 0.5 - origin.y))] = id
	_gt_cache[key] = {"cells": cells, "flipped": flipped}
	return _gt_cache[key]


func _paint(n: Node, colour: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		if (mi as MeshInstance3D).material_override != null:
			(mi as MeshInstance3D).material_override = m
		else:   # (a modelled .glb: per surface, as the bake does it; an override there logs errors)
			for surface in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(surface, m)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Siege crews by socket: "_in" behind the engine, "_top" over it, the rest by the socket's depth.
func _check_crew(v, label: String, view: String) -> void:
	var engine: Node = null
	for c in v.bob.get_children():
		if c is PartShape:
			engine = c
	var rig: Dictionary = PartShape.rigs.get(v.recipe.body + PartShape.facing_suffix(v.facing_k), {})
	for c in v.crew:
		var name := ""
		for s in rig.get("sockets", {}):
			if s.begins_with("crew") and rig.sockets[s].distance_to(c.view.position) < 0.01:
				name = s
		var over: bool = c.view.get_index() > engine.get_index()
		var want: bool = float(rig.depth[name]) > 0.0
		if name.ends_with("_in"):
			want = false
		elif name.ends_with("_top"):
			want = true
		_note("siege crew by socket", label, view, over != want, name)
