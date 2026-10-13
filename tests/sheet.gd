extends SceneTree
## The concept sheet tool (2026-10-13; Dominic: "start the creature kit and concept sheet tool"): one
## tool for every art round instead of a script per round. A small spec (tests/sheets/<name>.json)
## lists the rows, the columns, size references, zooms and labels; the tool bakes everything through
## the normal pipeline (ArtKit, the bake cache), lays out a labelled sheet per spec sheet and zoom,
## and runs the placement checks (tests/placement: the 3D geometry and the 2D projection checks) on
## every unit it shows, printing PASS/FAIL per row; a failing row is framed red on the sheet with the
## rules it broke. Exit 1 if any row fails. Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/<spec>.json out_dir [sheet,...] [zoom,...] [nocheck]
## Writes <out_dir>/<spec name>_<sheet>_<zoom>x.png (zoom 1 is the game's scale, 3 a close-up).
##
## The spec (JSON; every key but rows and sheets optional):
##   name, title          the file stem and the sheet's heading
##   stage                data files staged into the lib first (CreatureKit.stage): kits, later/ creatures
##   zooms                [3, 1]: times the game's scale
##   cell                 [w, h] world units per cell at the game's scale (a row may set "h": a multiplier)
##   rules                "default" (data/rules/<id>.json) for every prompt
##   size                 size references, drawn standing (facing 0) at the left of every row: unit refs
##   rows                 [{label, unit, other?, h?}] or {each: {prompt: [...], slot: [...]}, age?, label?}
##   sheets               [{name, title?, columns}]: columns is a list of column objects or a shorthand:
##                          "facings" (8, standing), "idle" (8, in the row's last idle pose),
##                          "idle:<pose>" (8, in that pose), "walk:<k>,<k>" (4 steps per facing),
##                          "cycle:<k>" (8 steps in one facing), "holds:<h>,<h>" (2 facings per hold)
##                        a column object: {facing, pose: stand|walk|hold|<idle pose>, step, steps, hold, other, label}
## A unit ref: {prompt, slot, age?, set?: recipe fields, mount?: {creature, skin, parts?}, rules?}
##   or {creature, skin?, mount_body?: true, set?} (the bare creature, no gear)
##   or {kit, params, creature, skin?, mount_body?} (a creature-kit creature with its kit's parameters changed)
##   or {part, skin?, family?} (one baked part alone; no placement check).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const ProjectionCheck := preload("res://tests/placement/projection_check.gd")

const BG := Color("#56782e")
const FACING_NAMES := ["f0 right", "f1", "f2 towards", "f3", "f4 left", "f5", "f6 away", "f7"]

var lib
var gen
var spec: Dictionary
var team: Color
var _races := {}
var _variants := {}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var spec_path: String = args[0]
	if not spec_path.begins_with("res://") and not spec_path.begins_with("/"):
		spec_path = "res://" + spec_path
	spec = DataLib.load_json(spec_path)
	var out_dir: String = args[1] if args.size() > 1 else "/tmp"
	var only: Array = Array(args[2].split(",")) if args.size() > 2 and args[2] != "all" else []
	var zooms: Array = Array(args[3].split(",")).map(func(z): return float(z)) if args.size() > 3 and args[3] != "all" else spec.get("zooms", [3, 1])
	var check: bool = not "nocheck" in args
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	for f in spec.get("stage", []):
		CreatureKit.stage(lib, f)
	gen = Generator.new(lib)
	team = Color(lib.palettes.teams[0])
	# Rows: [label, unit, other unit or null, height multiplier]; parts: [label, part id, colours].
	var rows := _rows()
	var size_units: Array = spec.get("size", []).map(func(r): return _unit(r))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var units := []
	for r in rows:
		for u in [r[1], r[2]]:
			if u != null and not u.has("part"):
				units.append(u)
	units += size_units.filter(func(u): return not u.has("part"))
	for u in units.duplicate():
		if u.recipe.has("crew"):   # a siege engine's crew are its race's workers: bake them too
			var cr: Dictionary = u.recipe.crew.duplicate(true)
			cr.merge({"creature": u.recipe.creature, "family": u.recipe.family, "slot": "worker", "role": "worker", "tier": 1, "name": ""})
			units.append({"recipe": cr, "eval": {"speed": 10}})
	await kit.prepare_units([{"units": units}], [team])
	for r in rows:
		for u in [r[1], r[2]]:
			if u != null and u.has("part"):
				await _bake_part(u)
	kit.rebuild_atlas()
	var verdicts := {}
	if check:
		verdicts = await _check(rows, kit)
	var bad := 0
	for r in rows:
		var v: Array = verdicts.get(r[0], [])
		if not check or r[1].has("part"):
			print("  -   %s" % r[0].replace("\n", " "))
		elif v.is_empty():
			print("PASS  %s" % r[0].replace("\n", " "))
		else:
			bad += 1
			print("FAIL  %s: %s" % [r[0].replace("\n", " "), "; ".join(v)])
	for sh in spec.sheets:
		if not only.is_empty() and not sh.name in only:
			continue
		for z in zooms:
			var path := out_dir.path_join("%s_%s_%sx.png" % [spec.get("name", spec_path.get_file().get_basename()), sh.name, str(z).trim_suffix(".0")])
			await _sheet(sh, rows, size_units, float(z) * ArtKit.ART_SCALE, verdicts, path)
	print("sheet: %d rows, %d failed placement" % [rows.size(), bad])
	quit(1 if bad > 0 else 0)


# ------------------------------------------------------------------ rows and units

func _rows() -> Array:
	var out := []
	for r in spec.rows:
		if r.has("each"):
			for p in r.each.prompt:
				for s in r.each.slot:
					var ref := {"prompt": p, "slot": s, "age": r.get("age", 1)}
					if not _has_slot(ref):
						print("  (no %s line for %s)" % [s, p])
						continue
					var u := _unit(ref)
					out.append([r.get("label", "{prompt}\n{name}").format({"prompt": p, "slot": s, "name": u.recipe.get("name", "")}), u, null, float(r.get("h", 1.0))])
			continue
		var u := _unit(r.unit)
		out.append([r.label, u, _unit(r.other) if r.has("other") else null, float(r.get("h", 1.0))])
	return out


func _race(prompt: String, rules_id: String) -> Dictionary:
	var key := prompt + "|" + rules_id
	if not _races.has(key):
		_races[key] = gen.generate(prompt, DataLib.load_json("res://data/rules/%s.json" % rules_id))
	return _races[key]


func _has_slot(ref: Dictionary) -> bool:
	return _race(ref.prompt, ref.get("rules", spec.get("rules", "default"))).units.any(func(u): return u.recipe.slot == ref.slot)


## A unit ref -> {recipe, eval} (or {part, colours} for a lone part).
func _unit(ref: Dictionary) -> Dictionary:
	if ref.has("part"):
		var fam: String = ref.get("family", "hellenic")
		var colours := UnitView.colours_for(lib, ref.get("skin", "human_tan"), fam, team)
		return {"part": ref.part, "colours": colours}
	var u: Dictionary
	if ref.has("prompt"):
		var race := _race(ref.prompt, ref.get("rules", spec.get("rules", "default")))
		var found: Array = race.units.filter(func(x): return x.recipe.slot == ref.slot)
		assert(not found.is_empty(), "%s has no %s line" % [ref.prompt, ref.slot])
		var step: Dictionary = found[0].line[0]
		for l in found[0].line:
			if int(l.age) <= int(ref.get("age", 1)):
				step = l
		u = {"recipe": step.recipe.duplicate(true), "eval": step.eval}
	else:
		var cid: String = ref.creature
		if ref.has("kit"):
			cid = _variant(ref)
		var c: Dictionary = lib.creatures[cid]
		var body: String = c.get("mount_body", c.body) if ref.get("mount_body", false) else c.body
		u = {"recipe": {"slot": "beast", "role": "beast", "tier": 1, "creature": cid, "family": c.families[0], "skin": ref.get("skin", c.skins[0]),
			"body": body, "head": c.head, "parts": {}, "scale": 100, "name": c.noun}, "eval": {"speed": 10}}
	if ref.has("set"):
		u.recipe.merge(ref.set, true)
	if ref.has("mount"):
		var m: Dictionary = ref.mount
		var mc: Dictionary = lib.creatures[m.creature]
		u.recipe.mount = {"creature": m.creature, "fused": false, "parts": m.get("parts", {}), "skin": m.get("skin", mc.skins[0])}
	return u


## A creature-kit creature with some of its kit's parameters changed: a kit of its own (new part ids),
## its body part completed from it, a creature copy wearing it.
func _variant(ref: Dictionary) -> String:
	var sig := JSON.stringify([ref.kit, ref.params, ref.get("creature", "")], "", true)
	if _variants.has(sig):
		return _variants[sig]
	var tag := "_v" + sig.md5_text().substr(0, 6)
	var base: Dictionary = CreatureKit.kits[ref.kit]
	var k: Dictionary = CreatureKit._merge(base, ref.params)
	for role in k.parts:
		k.parts[role] = base.parts[role] + tag
	var name: String = ref.kit + tag
	CreatureKit.register(name, k)
	var body: Dictionary = lib.part(base.parts.body).duplicate(true)
	body.id = k.parts.body
	body.kit = name
	for extra in CreatureKit.complete(body):
		lib.parts[extra.id] = extra
	lib.parts[body.id] = body
	var c: Dictionary = lib.creatures[ref.creature].duplicate(true)
	c[("mount_body" if ref.get("mount_body", false) else "body")] = body.id
	if k.has("head") and base.has("head"):
		c.head = k.parts.head
	lib.creatures[ref.creature + tag] = c
	_variants[sig] = ref.creature + tag
	return ref.creature + tag


func _bake_part(u: Dictionary) -> void:
	var pb := PartBaker.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	await pb.bake(u.part, lib.part(u.part).shapes, u.colours)
	pb.queue_free()


# ------------------------------------------------------------------ placement

## Every row's units through the placement checks (3D and 2D), each distinct unit once:
## label -> [what failed].
func _check(rows: Array, kit) -> Dictionary:
	var g = GeometryCheck.new(lib)
	g.metrics = true
	var pc = ProjectionCheck.new()
	pc.setup(lib)
	root.add_child(pc)
	var holder := Node2D.new()
	holder.visible = false
	root.add_child(holder)
	var seen := {}
	var owner := {}   # check label -> row label
	for r in rows:
		var i := 0
		for u in [r[1], r[2]]:
			if u == null or u.has("part"):
				continue
			var sig := JSON.stringify(u.recipe, "", true)
			var lab: String = "%s#%d" % [r[0], i]
			i += 1
			owner[lab] = r[0]
			if seen.has(sig):
				owner[lab] = ""
				continue
			seen[sig] = lab
			g.check(lab, u)
			await pc.check_case(holder, lab, u)
	var out := {}
	for res in [[g.results, g.order], [pc.results, pc.order]]:
		for key in res[1]:
			var fails: Array = res[0][key]
			if fails.is_empty():
				continue
			var parts: PackedStringArray = key.split("|")
			var row: String = owner.get(parts[1], "")
			if row == "":
				continue
			if not out.has(row):
				out[row] = []
			out[row].append("%s (%d views: %s)" % [parts[0], fails.size(), ", ".join(fails.slice(0, 2))])
	# A unit shown on several rows (the same recipe) carries its verdict to each.
	for r in rows:
		for i in 2:
			var lab: String = "%s#%d" % [r[0], i]
			if owner.get(lab, "x") == "":
				var u: Variant = r[1 + i]
				var first: String = seen.get(JSON.stringify(u.recipe, "", true), "")
				if out.has(owner.get(first, "")):
					out[r[0]] = out.get(r[0], []) + out[owner[first]]
	pc.queue_free()
	holder.queue_free()
	return out


# ------------------------------------------------------------------ layout

## A sheet's columns: [facing, pose ("stand", "walk", "hold", or an idle pose), step, steps, hold, other, label].
func _columns(sh: Dictionary) -> Array:
	var c: Variant = sh.columns
	if c is Array:
		return c.map(func(o): return [int(o.get("facing", 0)), o.get("pose", "stand"), int(o.get("step", 0)), int(o.get("steps", 8)),
			o.get("hold", ""), o.get("other", false), o.get("label", "")])
	var s: String = c
	var out := []
	var head := s.get_slice(":", 0)
	var tail := s.get_slice(":", 1) if ":" in s else ""
	match head:
		"facings":
			for k in 8:
				out.append([k, "stand", 0, 8, "", false, FACING_NAMES[k]])
		"idle":
			for k in 8:
				out.append([k, "idle" if tail == "" else tail, 0, 8, "", false, FACING_NAMES[k]])
		"walk":
			for k in tail.split(","):
				for st in 4:
					out.append([int(k), "walk", st * 2, 8, "", false, "f%s step %d" % [k, st * 2]])
		"cycle":
			for st in 8:
				out.append([int(tail), "walk", st, 8, "", false, "step %d" % st])
		"holds":
			for h in tail.split(","):
				for k in [0, 1]:
					out.append([k, "hold", 0, 8, h, false, "f%d %s" % [k, h]])
	return out


func _sheet(sh: Dictionary, rows: Array, size_units: Array, zoom: float, verdicts: Dictionary, path: String) -> void:
	var cols := _columns(sh)
	var cell := Vector2(spec.get("cell", [66, 64])[0], spec.get("cell", [66, 64])[1])
	var size_w := cell.x * 0.75 * size_units.size()
	var big := zoom > 2.0
	var label_w := 230.0 if big else 140.0
	var head_h := 56.0 if big else 44.0
	var fs := 14 if big else 10
	var heights := rows.map(func(r): return cell.y * float(r[3]) * zoom)
	var total_h := head_h
	for h in heights:
		total_h += h
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + (size_w + cell.x * cols.size()) * zoom) + 8, int(total_h) + 4)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	if size_w > 0.0:
		var band := ColorRect.new()
		band.color = Color(0, 0, 0, 0.07)
		band.position = Vector2(label_w, 0)
		band.size = Vector2(size_w * zoom, vp.size.y)
		vp.add_child(band)
		vp.add_child(_label("for size", Vector2(label_w + 6, head_h - fs - 8), fs))
	var title: String = spec.get("title", "") + ("  |  " if spec.has("title") and sh.has("title") else "") + sh.get("title", "")
	vp.add_child(_label(title, Vector2(8, 6), fs + 2))
	var x0 := label_w + size_w * zoom
	for c in cols.size():
		vp.add_child(_label(cols[c][6], Vector2(x0 + c * cell.x * zoom + 4, head_h - fs - 8), fs - 2 if big else fs - 1))
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.position = Vector2(label_w, 0)
	vp.add_child(world)
	var y := head_h
	for r in rows.size():
		var row: Array = rows[r]
		var h: float = heights[r]
		var fails: Array = verdicts.get(row[0], [])
		if not fails.is_empty():
			var frame := ReferenceRect.new()
			frame.border_color = Color("#ff3030")
			frame.border_width = 3.0
			frame.editor_only = false
			frame.position = Vector2(2, y + 2)
			frame.size = Vector2(vp.size.x - 4, h - 4)
			vp.add_child(frame)
		vp.add_child(_label(row[0], Vector2(8, y + h * 0.3), fs))
		if not verdicts.is_empty() and not row[1].has("part"):
			var verdict := "placement: PASS" if fails.is_empty() else "placement: FAIL\n" + "\n".join(fails.map(func(f): return f.get_slice(" (", 0)))
			var vl := _label(verdict, Vector2(8, y + h * 0.3 + (fs + 4) * (row[0].count("\n") + 1.2)), fs - 3 if big else fs - 2)
			vl.add_theme_color_override("font_color", Color("#c8f0a0") if fails.is_empty() else Color("#ffb0a0"))
			vp.add_child(vl)
		var base_y := (y + h * 0.82) / zoom
		for i in size_units.size():
			_draw(world, size_units[i], Vector2(cell.x * 0.75 * (i + 0.5), base_y), [0, "stand", 0, 8, "", false, ""])
		for c in cols.size():
			var u: Dictionary = row[2] if cols[c][5] and row[2] != null else row[1]
			_draw(world, u, Vector2(size_w + (c + 0.5) * cell.x, base_y), cols[c])
		y += h
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


## One unit (or lone part) in a column's facing and pose.
func _draw(world: Node2D, u: Dictionary, at: Vector2, col: Array) -> void:
	if u.has("part"):
		var ps := PartShape.new()
		ps.part_id = u.part
		ps.facing = col[0]
		ps.setup(lib.part(u.part).shapes, u.colours)
		ps.position = at + Vector2(0, -12)
		ps.scale = Vector2.ONE * ArtKit.UNIT_SCALE * 1.5
		world.add_child(ps)
		return
	var v := UnitView.new()
	v.facing_k = col[0]
	var pose: String = col[1]
	var idle: Array = _idle_poses(u.recipe)
	if pose == "idle":
		pose = idle[-1] if not idle.is_empty() else "stand"
	if pose in idle:
		v.body_pose = pose
	v.build(u.recipe, lib, team, u.eval.get("speed", 10))
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.position = at
	v.idle_wait = 1000.0
	world.add_child(v)
	v.walking = pose == "walk"
	v.phase = TAU * float(col[2]) / float(col[3]) if pose == "walk" else 0.0
	v._process(0.0)
	if pose == "hold" and col[4] != "":
		v.set_hold(col[4])
	v.set_process(false)


func _idle_poses(r: Dictionary) -> Array:
	if r.has("crew"):
		return []
	var body: String = r.body
	if r.has("mount"):
		var mc: Dictionary = lib.creatures[r.mount.creature]
		body = mc.get("fused_body", mc.body) if r.mount.fused else mc.get("mount_body", mc.body)
	return lib.part(body).get("idle_poses", [])


func _label(text: String, at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#f4f1e8"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	return l
