extends SceneTree
## Art-quality study, direction 2 (docs/concepts/art-quality/): buildings broken up in stages, baked.
## Top row per building: its stages (tests/art_quality/ruin.gd) at game scale; under it, the fall
## played out with pixel dust (art-pixel puffs in three painted bands, lit from the upper left).
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/art_quality/ruin_sheet.gd -- out.png <zoom> model|type:arch ...   (e.g. stone_town_center villa_house barracks:stone)

const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const Ruin := preload("res://src/view/art/bake/ruin.gd")
const Rng := preload("res://src/rng.gd")

const BG := Color("#56782e")
const NAMES := ["whole", "battered", "breaking", "collapsed", "ruin"]
const FALL := ["it falls", "", "dust settles", "", "the ruin stays"]   # the fall row's labels
const DUST := [Color("#e2d6bc"), Color("#b9a98a"), Color("#857761")]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var zoom := float(args[1])
	var names: Array = args.slice(2)
	var kit := ArtKit.new()
	root.add_child(kit)
	await process_frame
	var baker = await kit._hifi_baker()
	var models = kit._models
	var team := Color(PartShape.TEAM_KEY)
	var rows := []
	var cell := Vector2.ZERO
	for n in names:
		var bakes := []
		for s in Ruin.STAGES.size():
			var spec: Dictionary = models.building(n.get_slice(":", 0), n.get_slice(":", 1), team) if n.contains(":") else models.call(n, team)
			if n.contains("house"):
				spec.body.scale = Vector3.ONE * ArtKit.HOUSE_SCALE
			for live in ["banner", "vane", "open", "icon"]:
				if spec.has(live) and spec[live] is Node:
					spec[live].free()
			Ruin.apply(spec.body, s, Rng.hash_string(n), models)
			baker.set_ground_shadow(true)
			var b: Dictionary = await baker.bake(spec.body, [Vector3.ZERO])
			bakes.append(b)
			cell = cell.max(Vector2(b.img.get_size()) / ArtKit.ART_SCALE)
		rows.append([n, bakes])
	cell *= Vector2(1.08, 1.1)
	var label_w := 170.0
	var head := 40.0
	var row_h := cell.y * zoom + 24.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + cell.x * zoom * Ruin.STAGES.size()) + 8, int(head + row_h * 2 * rows.size()) + 4)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	vp.add_child(_label("Direction 2: destruction in baked stages (study, not in the game)  |  zoom %s" % zoom, Vector2(8, 8), 16))
	var team_mat := ShaderMaterial.new()
	team_mat.shader = load("res://src/team_mask.gdshader")
	var y := head
	for r in rows:
		for pass_ in 2:
			vp.add_child(_label(r[0] + ("\nstages" if pass_ == 0 else "\nthe fall, with dust"), Vector2(8, y + row_h * 0.4), 14))
			for s in Ruin.STAGES.size():
				var b: Dictionary = r[1][s]
				var at := Vector2(label_w + (s + 0.5) * cell.x * zoom, y + row_h * 0.72)
				var shown: Dictionary = b
				if pass_ == 1:   # the fall: frames of it falling, dust over the bake
					shown = r[1][[1, 2, 3, 4, 4][s]]
				var sp := Sprite2D.new()
				sp.texture = shown.tex
				sp.centered = false
				sp.offset = -shown.points[0]
				sp.scale = Vector2.ONE / ArtKit.ART_SCALE * zoom
				sp.position = at
				sp.self_modulate = Color("#3a78d8")
				sp.material = team_mat
				vp.add_child(sp)
				if pass_ == 1 and s < 4:
					var d := _dust(shown, s, Rng.hash_string(r[0]))
					var ds := Sprite2D.new()
					ds.texture = d
					ds.centered = false
					ds.offset = -shown.points[0]
					ds.scale = sp.scale
					ds.position = at
					vp.add_child(ds)
				var txt: String = NAMES[s] if pass_ == 0 else ["falling in", "the roof goes", "dust over the heap", "dust settling", "the ruin stays"][s]
				vp.add_child(_label(txt, Vector2(at.x - 60, y + 4), 13))
			y += row_h
	for f in 20:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


## Pixel dust over a bake: puffs along the base and up the walls, banded in three tones and lit from
## the upper left; frame k of the fall (0 the first burst .. 3 thin and settling).
func _dust(b: Dictionary, k: int, seed_value: int) -> ImageTexture:
	var size: Vector2i = b.img.get_size()
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rng := Rng.new(seed_value + k)
	var o: Vector2 = b.points[0]
	var w := float(size.x) * 0.42
	var spread: float = [0.7, 0.95, 1.15, 1.25][k]
	var rise: float = [0.35, 0.6, 0.45, 0.25][k]
	var thin: float = [0.0, 0.1, 0.35, 0.6][k]
	var n: int = [50, 64, 56, 40][k]
	var puffs := []
	for i in n:
		var fx: float = (float(rng.next_u32() % 1000) / 1000.0 * 2.0 - 1.0) * spread
		var up: float = float(rng.next_u32() % 1000) / 1000.0 * rise * (1.0 - absf(fx) * 0.5)
		var c: Vector2 = o + Vector2(fx * w, -up * w * 0.9 + absf(fx) * w * 0.12 - w * 0.05)
		var rad: float = w * (0.06 + 0.08 * float(rng.next_u32() % 1000) / 1000.0) * (1.0 + 0.4 * k)
		puffs.append([c, rad])
	var best := PackedFloat32Array()
	best.resize(size.x * size.y)
	var lit := PackedFloat32Array()
	lit.resize(size.x * size.y)
	for p in puffs:
		var r: float = p[1]
		for py in range(maxi(0, int(p[0].y - r)), mini(size.y, int(p[0].y + r) + 1)):
			for px in range(maxi(0, int(p[0].x - r)), mini(size.x, int(p[0].x + r) + 1)):
				var d: Vector2 = Vector2(px, py) - p[0]
				var f: float = 1.0 - d.length() / r
				var i := py * size.x + px
				if f > best[i]:
					best[i] = f
					lit[i] = (-d.x - d.y) / r   # the upper left of each puff catches the light
	for i in best.size():
		if best[i] <= 0.0:
			continue
		var px := i % size.x
		var py := i / size.x
		var noise := float(((px * 73856093) ^ (py * 19349663) ^ (k * 83492791)) & 1023) / 1023.0
		if best[i] + noise * 0.25 < 0.15 + thin * 0.5:
			continue
		if best[i] < 0.22 and (px + py) % 2 == 0:   # a dithered edge, as the genre's dust
			continue
		var band := 2 if lit[i] < -0.2 else (0 if lit[i] > 0.35 else 1)
		var col: Color = DUST[band]
		col.a = 0.92 - thin * 0.55
		img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)


func _label(t: String, at: Vector2, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.position = at
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
