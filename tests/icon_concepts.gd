extends SceneTree
## Unit portrait concepts (2026-10-16; Dominic: "unit icons are too zoomed out, hard to tell what's
## what", and the line upgrade's button looks just like the Train button beside it). For a few races,
## every unit's portrait as the panel shows it (80 px), framed four ways:
##   today  ArtKit.frame_icon: the whole body, a margin round it
##   A      a bust: head, chest and the weapon in hand fill the square (a rider: the rider and the
##          mount's head)
##   B      today's frame with a badge in the corner: the unit's own weapon (its baked sprite)
##   C      the bust and the badge
## and a row of line upgrades: today (the line's current portrait, as the Train button) beside the
## proposal (the next step's portrait, a gold up-arrow, the age it brings).
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
	var blocks := []   # [race name, [[slot, cells: {today, A, B, C}]], upgrade pairs]
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
			var badge := _weapon(lib, units[k].recipe, team)
			row.append([str(units[k].recipe.get("role", units[k].recipe.get("slot", "?"))),
				{"today": ArtKit.frame_icon(cell), "A": bust(cell), "B": _badged(ArtKit.frame_icon(cell), badge), "C": _badged(bust(cell), badge)}])
		# Line upgrades: the first step a line has after age 1 or 2, today and proposed.
		var ups := []
		for u in units:
			var line: Array = u.get("line", [])
			if line.size() < 2:
				continue
			var pair: Array = await _paint(kit, lib, [line[0].recipe, line[1].recipe], team)
			ups.append([str(u.recipe.get("role", "?")), ArtKit.frame_icon(pair[0]), _upgrade(bust(pair[1]), int(line[1].age))])
			if ups.size() >= 4:
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


## The unit's weapon as baked (facing 0), or null.
func _weapon(lib, recipe: Dictionary, team: Color) -> Image:
	var id: String = recipe.get("parts", {}).get("hand_r", "")
	if id == "":
		return null
	var view := UnitView.new()
	view.build(recipe, lib, team, 10)
	var img: Image = null
	for ps in view.find_children("*", "Node2D", true, false):
		if ps is PartShape and ps.part_id == id:
			var b = ps.bake_of()
			if b != null:
				img = (b.img as Image).duplicate()
			break
	view.free()
	return img


## A portrait at SHOW px with the weapon badge in its lower right: a dark disc, the weapon on it.
static func _badged(icon: Image, weapon: Image) -> Image:
	var out := _sized(icon)
	if weapon == null:
		return out
	var r := 15
	var c := Vector2i(SHOW - r - 3, SHOW - r - 3)
	_disc(out, c, r + 2, Color("#e2c47a"))
	_disc(out, c, r, Color("#2a2018"))
	var w: Image = weapon.duplicate()
	w.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = w.get_used_rect()
	w = w.get_region(used)
	var k := float(r * 2 - 6) / maxf(w.get_width(), w.get_height())
	w.resize(maxi(1, roundi(w.get_width() * k)), maxi(1, roundi(w.get_height() * k)), Image.INTERPOLATE_NEAREST)
	out.blend_rect(w, Rect2i(Vector2i.ZERO, w.get_size()), c - w.get_size() / 2)
	return out


## The proposed upgrade button: the next step's bust, a gold up-arrow, the age (II, III).
static func _upgrade(icon: Image, age: int) -> Image:
	var out := _sized(icon)
	var gold := Color("#e8b84a")
	var dark := Color("#2a2018")
	for y in 22:   # the arrow, top left: a dark edge, gold inside
		for x in 26:
			var head := y < 13 and absi(x - 13) <= y
			var shaft := y >= 13 and absi(x - 13) <= 5
			if head or shaft:
				out.set_pixel(x + 3, y + 3, dark)
	for y in range(1, 21):
		for x in range(1, 25):
			var head := y < 13 and absi(x - 13) <= y - 2
			var shaft := y >= 13 and y < 20 and absi(x - 13) <= 3
			if head or shaft:
				out.set_pixel(x + 3, y + 3, gold)
	return out


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
		h += 40 + 4 * (SHOW + GAP) + 30 + (SHOW + GAP + 24) + 20
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
	_label(page, "Unit portraits: today, A bust, B badge, C bust + badge; line upgrades today vs proposed (80 px, the panel's size)", Vector2(GAP, 14), 18)
	var y := 60
	for b in blocks:
		_label(page, b[0], Vector2(GAP, y), 20, Color("#e8b84a"))
		y += 40
		for opt in ["today", "A", "B", "C"]:
			_label(page, {"today": "today", "A": "A  bust", "B": "B  badge", "C": "C  both"}[opt], Vector2(GAP, y + SHOW / 2 - 10), 16)
			for k in b[1].size():
				var x: int = LABEL_W + k * (SHOW + GAP)
				_cell(page, b[1][k][1][opt], Vector2(x, y))
				if opt == "today":
					_label(page, b[1][k][0], Vector2(x, y - 18), 12, Color(1, 1, 1, 0.6))
			y += SHOW + GAP
		y += 30
		_label(page, "upgrades", Vector2(GAP, y + SHOW / 2 - 10), 16)
		for k in b[2].size():
			var x: int = LABEL_W + k * 2 * (SHOW + GAP)
			_label(page, "%s: today | proposed" % b[2][k][0], Vector2(x, y - 18), 12, Color(1, 1, 1, 0.6))
			_cell(page, b[2][k][1], Vector2(x, y))
			_cell(page, b[2][k][2], Vector2(x + SHOW + GAP, y))
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
