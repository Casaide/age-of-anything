extends SceneTree
## A concept sheet: candidate designs (scenes/art_pixel/concepts.gd) worn by the same unit,
## in a row with their names, so variations can be compared and picked before one is built.
## Run it twice: close up to judge the design, at game scale to judge what survives.
## Run (needs a display):
##   godot --path . --script res://tests/concept_sheet.gd -- out.png <art px per unit> <zoom> "prompt" [az=<deg>] id id ...
## e.g. ... -- /tmp/c.png 4.0 2 "romans" concept.current_cap concept.roman_bare ...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const Concepts := preload("res://scenes/art_pixel/concepts.gd")

const W := 1600
const H := 900


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var art := float(args[1])
	var zoom := int(args[2])
	var prompt: String = args[3]
	var ids: Array = args.slice(4)
	var azimuth := PartBaker.AZIMUTH
	var settings := {}   # leading az=, el=, outline=, bands= arguments set up the bake
	while ids.size() > 0 and String(ids[0]).get_slice("=", 0) in ["az", "el", "outline", "bands", "unit"]:
		var key := String(ids[0]).get_slice("=", 0)
		var val := String(ids[0]).get_slice("=", 1)
		settings[key] = val if key == "unit" else float(val)
		ids = ids.slice(1)
	azimuth = settings.get("az", azimuth)
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate(prompt, DataLib.load_json("res://data/rules/default.json"))
	var base: Dictionary = race.units[1]   # the spear unit at its first age (unit=<slot> for another)
	for u in race.units:
		if u.recipe.slot == settings.get("unit", "spear"):
			base = u
	# A column is a head-gear concept id, or several slot swaps: "body=concept.x;legs=concept.y;
	# head=concept.z;gear=concept.w" (gear=none for a bare head). Concepts borrow a real part's
	# data entry; only the model differs.
	var cols := []
	for col in ids:
		var spec := {}
		if String(col).begins_with("png="):   # a drawn sprite (e.g. the R0 pixel test), placed as is
			cols.append({"png": String(col).trim_prefix("png=")})
			continue
		for kv in String(col).split(";"):
			if "=" in kv:
				spec[kv.get_slice("=", 0)] = kv.get_slice("=", 1)
			else:
				spec["gear"] = kv
		cols.append(spec)
		for slot in spec:
			var id: String = spec[slot]
			if id == "none" or lib.parts.has(id) or slot in ["skin", "scale", "headpng", "mountalpha"]:
				continue
			var borrow: String = {"body": base.recipe.body, "head": base.recipe.head, "legs": "leg.human",
				"torso": "armour.leather", "hand_l": "shield.round", "hand_r": "weapon.spear.wood", "back": "cape.cloth",
				"mount": "body.pony", "mounthead": "head.pony", "mountback": "wings.feather"}.get(slot, "helm.cap")
			var p: Dictionary = lib.part(borrow).duplicate(true)
			p.id = id
			if slot == "body" and spec.has("legs"):
				p.legs.part = spec.legs
			if slot == "mount" and not spec.has("legs"):
				p.erase("legs")   # a flying mount with no legs to walk on
			if slot == "mountback" and spec.has("mountalpha"):
				p.blur = int(spec.mountalpha)
			lib.parts[id] = p
	var baker := PartBaker.new()
	baker.art_scale = art
	baker.models = Concepts.new()
	baker.azimuth = azimuth
	baker.facings = 1   # concepts are judged in the classic view
	baker.bands = int(settings.get("bands", 4))   # as in the game by default (ArtKit.UNIT_BANDS)
	baker.elevation = settings.get("el", PartBaker.ELEVATION)
	baker.outlined = settings.get("outline", 1.0) > 0.5
	root.add_child(baker)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = zoom
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.size = Vector2(W, H)
	root.add_child(box)
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(W, H) / zoom
	vp.add_child(bg)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	var recipes := []
	for spec in cols:
		if spec.has("png"):
			recipes.append(spec)
			continue
		var r: Dictionary = base.recipe.duplicate(true)
		if spec.has("body"):
			r.body = spec.body
		if spec.has("head"):
			r.head = spec.head
		if spec.get("gear", "") == "none":
			r.parts.erase("head_gear")
		elif spec.has("gear"):
			r.parts.head_gear = spec.gear
		for key in spec:   # other swaps: skin=frog_green, scale=130, torso=none, hand_l=none ...
			if key == "skin":
				r.skin = spec.skin
			elif key == "scale":
				r.scale = int(spec.scale)
			elif key == "headpng":
				pass
			elif key in ["torso", "hand_l", "hand_r", "back"]:
				if spec[key] == "none":
					r.parts.erase(key)
				else:
					r.parts[key] = spec[key]
		if spec.has("mount"):   # a mount concept: mount=<body> [mounthead=<head>] [mountback=<wings>] [mountalpha=<0-100>]
			var mc := "concept_mount_%d" % recipes.size()
			lib.creatures[mc] = {"noun": "Mount", "body": spec.mount, "head": spec.get("mounthead", "head.pony"), "skins": ["pony_bay"], "mount": true}
			r.mount = {"creature": mc, "skin": "pony_bay", "fused": false, "parts": {}}
			if spec.has("mountback"):
				r.mount.parts.back = spec.mountback
		recipes.append(r)
		if r.has("png"):
			continue
		var probe := UnitView.new()
		probe.build(r, lib, team, base.eval.speed)
		for ps in probe.find_children("*", "Node2D", true, false):
			if ps is PartShape and ps.part_id != "":
				if ps.part_id == r.head and spec.has("headpng"):
					_stamp_head(ps, spec.headpng)   # the hybrid: a drawn pixel head on the baked body
				else:
					await baker.bake(ps.part_id, ps.shapes, ps.colours)
		probe.free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, art)
	PartShape.build_atlas()
	for k in recipes.size():
		if recipes[k].has("png"):
			var sp := Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(recipes[k].png)))
			sp.centered = false
			sp.offset = Vector2(-sp.texture.get_width() * 0.5, -sp.texture.get_height() + 2)   # feet on the line
			sp.position = Vector2((k + 0.5) * W / recipes.size(), H * 0.6) / zoom
			sp.scale = Vector2.ONE * art / 1.275   # drawn at game scale
			var shadow := Polygon2D.new()   # the same flat ground shadow the baked units stand on
			var pts := PackedVector2Array()
			for k2 in 24:
				pts.append(Vector2(cos(TAU * k2 / 24.0) * 12.0, sin(TAU * k2 / 24.0) * 4.5) * art / 1.275)
			shadow.polygon = pts
			shadow.color = Color(0, 0, 0, 0.35)
			shadow.position = sp.position
			vp.add_child(shadow)
			vp.add_child(sp)
			var pl := Label.new()
			pl.text = String(ids[k]).get_file().get_basename()
			pl.add_theme_font_size_override("font_size", 18)
			pl.position = Vector2((k + 0.5) * W / recipes.size() - 120, H * 0.8)
			pl.size = Vector2(240, 30)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root.add_child(pl)
			continue
		var v := UnitView.new()
		v.build(recipes[k], lib, team, base.eval.speed)
		v.scale = Vector2(art, art)
		v.position = Vector2((k + 0.5) * W / recipes.size(), H * 0.6) / zoom
		vp.add_child(v)
		var name := Label.new()
		name.text = String(ids[k]).replace("concept.", "").replace(";", "\n")
		name.add_theme_font_size_override("font_size", 18)
		name.position = Vector2((k + 0.5) * W / recipes.size() - 120, H * 0.8)
		name.size = Vector2(240, 30)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(name)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


## Put a drawn pixel head (docs/concepts/r0/head_*.png, drawn at game scale, with its neck
## point in the .json beside it) in place of a head part's bake.
func _stamp_head(ps, path: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path + ".png"))
	var neck: Array = JSON.parse_string(FileAccess.get_file_as_string(path + ".json")).neck
	var key: String = PartShape.bake_key(ps.part_id, ps.shapes, PartShape.team_neutral(ps.colours))
	PartShape.baked[key] = {"img": img, "tex": ImageTexture.create_from_image(img),
		"origin": Vector2(neck[0], neck[1]), "scale": 1.275}
