extends SceneTree
## Unit portrait concepts (2026-10-16; Dominic: "unit icons are too zoomed out, hard to tell what's
## what", and the line upgrade's button looks just like the Train button beside it). For a few races,
## every unit's portrait as the panel shows it (80 px), framed three ways:
##   today  ArtKit.frame_icon: the whole body, a margin round it
##   A      a bust: head, chest and the weapon in hand fill the square (a rider: the rider and the
##          mount's head)
##   D      the bust with a drawn role glyph in the corner (assets/art/icons/glyph/role_*.svg: spear,
##          sword, bow, sling, horse, staff; round 1's badge of the unit's own weapon read as a line)
## and its military lines' upgrade buttons: today (the line's current portrait, as the Train button)
## beside three proposals (round 1's arrow on the bust was "a bit bland": Dominic):
##   U1  a gold frame, a big arrow, pips for the age it brings
##   U2  before and after: the step it leaves small and faded in a corner, an arrow to the new bust
##   U3  a gold glow behind the new bust, rank chevrons for the age
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/icon_concepts.gd -- out.png ["prompt" ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")

const SHOW := 80            # the panel's button, in screen pixels
const GAP := 10
const LABEL_W := 120
const GLYPH := 30           # a role glyph's size on a portrait
const GOLD := Color("#e8b84a")
const DARK := Color("#2a2018")
const SLOTS := ["worker", "spear", "infantry", "skirmisher", "archer", "large", "scout", "mounted_archer", "healer"]
const BUST := 0.62          # the share of the body's height a bust frames (from the top)

var font: Font


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out: String = args.pop_front()
	var prompts: Array = args if not args.is_empty() else ["angry swamp frogs with reed spears", "centaur romans", "sewer rats with cheese hammers", "medieval knights"]
	font = ThemeDB.fallback_font
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var races := prompts.map(func(p): return gen.generate(p, rules))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.bake_units(races)
	kit.rebuild_atlas()
	var team := Color(lib.palettes.teams[0])
	var blocks := []   # [race name, [[slot, cells: {today, A, D}]], upgrade pairs]
	for race in races:
		var units := []
		for slot in SLOTS:
			for u in race.units:
				if u.recipe.get("role", "") == slot or u.recipe.get("slot", "") == slot:
					units.append(u)
					break
		var cells: Array = await _paint(kit, lib, units.map(func(u): return u.recipe), team)
		var row := []
		for k in units.size():
			var cell: Image = cells[k]
			var glyph := _glyph(_role_glyph(lib, units[k].recipe))
			row.append([str(units[k].recipe.get("role", units[k].recipe.get("slot", "?"))),
				{"today": ArtKit.frame_icon(cell), "A": bust(cell), "D": _badged(bust(cell), glyph)}])
		# Line upgrades: a military line's first step after its first, today and three proposals.
		var ups := []
		for u in units:
			var line: Array = u.get("line", [])
			if line.size() < 2 or str(u.recipe.get("role", "")) in ["worker", "healer"]:
				continue
			var pair: Array = await _paint(kit, lib, [line[0].recipe, line[1].recipe], team)
			var age := int(line[1].age)
			var old := ArtKit.frame_icon(pair[0])
			var new := bust(pair[1])
			ups.append([str(u.recipe.get("role", "?")), old, _u1(new, age), _u2(new, old), _u3(new, age)])
			if ups.size() >= 2:
				break
		blocks.append([race.name, row, ups])
	await _sheet(blocks, out)
	quit()


## Every recipe's portrait cell, rendered as ArtKit._paint_icons does (before framing).
func _paint(kit, lib, recipes: Array, team: Color) -> Array:
	var cols := 8
	var cellpx: int = ArtKit.ICON_CELL
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(cols, ceili(recipes.size() / float(cols))) * cellpx
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var zoom := ArtKit.ART_SCALE * 2.0
	for k in recipes.size():
		var view := UnitView.new()
		view.build(recipes[k], lib, team, 10)
		view.scale = Vector2.ONE * ArtKit.UNIT_SCALE * zoom
		view.position = Vector2(0.5, 0.8) * cellpx
		view.get_child(0).visible = false
		var hold := Control.new()
		hold.clip_contents = true
		hold.position = Vector2(k % cols, k / cols) * cellpx
		hold.size = Vector2.ONE * cellpx
		hold.add_child(view)
		vp.add_child(hold)
		view.set_process(false)
		view._process(0.0)
	await process_frame
	await BakeClock.render(vp)
	var img: Image = await BakeClock.read(vp)
	var out := []
	for k in recipes.size():
		out.append(img.get_region(Rect2i(Vector2i(k % cols, k / cols) * cellpx, Vector2i.ONE * cellpx)))
	vp.queue_free()
	return out


## A bust: the body (thin poles and tails trimmed, as frame_icon does) framed on its top BUST share,
## square, centred across on that part's weight.
static func bust(cell: Image) -> Image:
	var used := cell.get_used_rect()
	if used.size.x == 0:
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var rows := PackedInt32Array()
	rows.resize(cell.get_height())
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if cell.get_pixel(x, y).a > 0.1:
				rows[y] += 1
	var y0 := used.position.y
	while y0 < used.end.y - 1 and rows[y0] < ArtKit.ICON_THIN:
		y0 += 1
	var y1 := used.end.y - 1
	while y1 > y0 and rows[y1] < ArtKit.ICON_THIN:
		y1 -= 1
	var side := maxi(roundi((y1 - y0 + 1) * BUST * 1.1), ArtKit.ICON_MIN)
	var top := y0 - roundi(side * 0.06)
	var sum := 0
	var mass := 0
	for y in range(y0, mini(y0 + side, cell.get_height())):
		for x in range(used.position.x, used.end.x):
			if cell.get_pixel(x, y).a > 0.1:
				sum += x
				mass += 1
	var mid: int = sum / maxi(mass, 1)
	var src := Rect2i(mid - side / 2, top, side, side)
	var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var clip := src.intersection(Rect2i(Vector2i.ZERO, cell.get_size()))
	sq.blit_rect(cell, clip, clip.position - src.position)
	return sq


## Which role glyph a unit wears: by its weapon's tags; a rider with a lance or a blade, the horse.
func _role_glyph(lib, recipe: Dictionary) -> String:
	var id: String = recipe.get("parts", {}).get("hand_r", "")
	var tags: Array = lib.part(id).get("tags", []) if id != "" else []
	var rides: bool = recipe.has("mount") and not recipe.mount.get("fused", false)   # (a centaur is its own horse: it goes by its weapon)
	if recipe.get("role", "") == "worker":
		return ""
	if "heal" in tags or "staff" in tags:
		return "staff"
	if "bow" in tags:
		return "bow"
	if "ranged" in tags:
		return "sling"
	if rides and ("lance" in tags or not "spear" in tags):
		return "horse"
	if "spear" in tags or "reach" in tags:
		return "spear"
	if "melee" in tags:
		return "sword"
	return ""


static func _glyph(name: String) -> Image:
	if name == "":
		return null
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://assets/art/icons/glyph/role_%s.svg" % name), GLYPH / 32.0)
	img.convert(Image.FORMAT_RGBA8)
	return img


## A portrait at SHOW px with this glyph in its lower right.
static func _badged(icon: Image, glyph: Image) -> Image:
	var out := _sized(icon)
	if glyph != null:
		out.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), Vector2i(SHOW - GLYPH - 2, SHOW - GLYPH - 2))
	return out


## U1: a gold frame, a big arrow at the top left, a pip per age at the top right.
static func _u1(icon: Image, age: int) -> Image:
	var out := _sized(icon)
	for t in 4:
		var c := GOLD.darkened(0.25) if t == 0 or t == 3 else GOLD
		for x in range(t, SHOW - t):
			out.set_pixel(x, t, c)
			out.set_pixel(x, SHOW - 1 - t, c)
		for y in range(t, SHOW - t):
			out.set_pixel(t, y, c)
			out.set_pixel(SHOW - 1 - t, y, c)
	_arrow(out, Vector2i(6, 6), 1.2)
	for k in age:
		_diamond(out, Vector2i(SHOW - 12 - k * 11, 11), 5)
	return out


## U2: the step it leaves small and faded in the lower left, an arrow up to the new bust.
static func _u2(icon: Image, old: Image) -> Image:
	var out := _sized(icon)
	var s := 34
	var small: Image = old.duplicate()
	small.convert(Image.FORMAT_RGBA8)
	small.resize(s, s, Image.INTERPOLATE_NEAREST)
	for y in s:
		for x in s:
			var c := small.get_pixel(x, y)
			var g := c.get_luminance()
			small.set_pixel(x, y, Color(g, g, g, c.a * 0.85))
	var at := Vector2i(2, SHOW - s - 2)
	for y in range(-2, s + 2):   # a dark box under it, a gold rim
		for x in range(-2, s + 2):
			var rim := x < 0 or y < 0 or x >= s or y >= s
			out.set_pixel(at.x + x, at.y + y, GOLD if rim else DARK)
	out.blend_rect(small, Rect2i(0, 0, s, s), at)
	_arrow(out, Vector2i(s - 2, SHOW - s - 26), 0.9)
	return out


## U3: a gold glow behind the new bust, a chevron per age in the lower right.
static func _u3(icon: Image, age: int) -> Image:
	var out := Image.create(SHOW, SHOW, false, Image.FORMAT_RGBA8)
	var c := Vector2(SHOW * 0.5, SHOW * 0.45)
	for y in SHOW:
		for x in SHOW:
			var d := Vector2(x, y).distance_to(c) / (SHOW * 0.6)
			var a := clampf(1.0 - d, 0.0, 1.0)
			out.set_pixel(x, y, Color(GOLD.r, GOLD.g * 0.9, GOLD.b * 0.5, a * a * 0.85))
	var b := _sized(icon)
	out.blend_rect(b, Rect2i(0, 0, SHOW, SHOW), Vector2i.ZERO)
	for k in age:   # chevrons stacked upward
		_chevron(out, Vector2i(SHOW - 18, SHOW - 10 - k * 8))
	return out


## A gold up-arrow, dark-edged, its top left at `at`, scaled.
static func _arrow(img: Image, at: Vector2i, k: float) -> void:
	var w := roundi(26 * k)
	var h := roundi(22 * k)
	for pass_ in 2:
		var grow := 2 if pass_ == 0 else 0
		for y in h:
			for x in w:
				var mid := w / 2
				var head := y < h * 0.6 and absi(x - mid) <= y + grow - (0 if pass_ == 0 else 2)
				var shaft := y >= h * 0.6 and absi(x - mid) <= roundi(w * 0.2) + (grow / 2) and y < h - (0 if pass_ == 0 else 1)
				if head or shaft:
					img.set_pixel(at.x + x, at.y + y, DARK if pass_ == 0 else GOLD)


static func _diamond(img: Image, c: Vector2i, r: int) -> void:
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := absi(x) + absi(y)
			if d <= r + 1:
				img.set_pixel(c.x + x, c.y + y, DARK if d > r - 1 else GOLD)


static func _chevron(img: Image, at: Vector2i) -> void:
	for x in range(-9, 10):
		var y := 6 - absi(x) * 6 / 9
		for t in range(-2, 3):
			img.set_pixel(at.x + x, at.y + y + t, DARK if absi(t) == 2 else GOLD)


static func _sized(icon: Image) -> Image:
	var out := icon.duplicate()
	out.convert(Image.FORMAT_RGBA8)
	out.resize(SHOW, SHOW, Image.INTERPOLATE_NEAREST)
	return out


static func _disc(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				img.set_pixel(c.x + x, c.y + y, col)


## The sheet: per race, a row per option (labels on the left), a column per unit; then the upgrades.
func _sheet(blocks: Array, out: String) -> void:
	var cols := 0
	for b in blocks:
		cols = maxi(cols, b[1].size())
	var w := LABEL_W + cols * (SHOW + GAP) + GAP
	var h := 60
	for b in blocks:
		h += 40 + 3 * (SHOW + GAP) + 30 + (SHOW + GAP + 24) + 20
	h += 120   # the glyphs, large
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var page := Control.new()
	page.size = vp.size
	vp.add_child(page)
	var bg := ColorRect.new()
	bg.color = Color("#1d1813")
	bg.size = vp.size
	page.add_child(bg)
	_label(page, "Unit portraits, round 2: today, A bust, D bust + role glyph; upgrade buttons U1-U3 (80 px, the panel's size)", Vector2(GAP, 14), 18)
	var y := 60
	_label(page, "role glyphs", Vector2(GAP, y + 30), 16)
	var gx := LABEL_W
	for g in ["spear", "sword", "bow", "sling", "horse", "staff"]:
		var big := Image.new()
		big.load_svg_from_string(FileAccess.get_file_as_string("res://assets/art/icons/glyph/role_%s.svg" % g), 2.5)
		var t := TextureRect.new()
		t.texture = ImageTexture.create_from_image(big)
		t.position = Vector2(gx, y)
		page.add_child(t)
		_label(page, g, Vector2(gx + 18, y + 84), 12, Color(1, 1, 1, 0.6))
		gx += 110
	y += 120
	for b in blocks:
		_label(page, b[0], Vector2(GAP, y), 20, Color("#e8b84a"))
		y += 40
		for opt in ["today", "A", "D"]:
			_label(page, {"today": "today", "A": "A  bust", "D": "D  bust + glyph"}[opt], Vector2(GAP, y + SHOW / 2 - 10), 16)
			for k in b[1].size():
				var x: int = LABEL_W + k * (SHOW + GAP)
				_cell(page, b[1][k][1][opt], Vector2(x, y))
				if opt == "today":
					_label(page, b[1][k][0], Vector2(x, y - 18), 12, Color(1, 1, 1, 0.6))
			y += SHOW + GAP
		y += 30
		_label(page, "upgrades", Vector2(GAP, y + SHOW / 2 - 10), 16)
		for k in b[2].size():
			var x: int = LABEL_W + k * 4 * (SHOW + GAP) + k * 30
			_label(page, "%s:  today | U1 frame | U2 before-after | U3 glow" % b[2][k][0], Vector2(x, y - 18), 12, Color(1, 1, 1, 0.6))
			for v in 4:
				_cell(page, b[2][k][1 + v], Vector2(x + v * (SHOW + GAP), y))
		y += SHOW + GAP + 24 + 20
	await process_frame
	await BakeClock.render(vp)
	var img: Image = await BakeClock.read(vp)
	img.save_png(out)
	print("saved ", out)


## A cell: the panel's button look (a dark slot, a lighter rim) with the portrait in it.
func _cell(page: Control, icon: Image, at: Vector2) -> void:
	var rim := ColorRect.new()
	rim.color = Color("#5a4a36")
	rim.position = at - Vector2(2, 2)
	rim.size = Vector2(SHOW + 4, SHOW + 4)
	page.add_child(rim)
	var slot := ColorRect.new()
	slot.color = Color("#3a3024")
	slot.position = at
	slot.size = Vector2(SHOW, SHOW)
	page.add_child(slot)
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(_sized(icon))
	t.position = at
	t.size = Vector2(SHOW, SHOW)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	page.add_child(t)


func _label(page: Control, text: String, at: Vector2, size: int, col := Color(1, 1, 1, 0.9)) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	page.add_child(l)
