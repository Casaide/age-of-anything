extends VBoxContainer
## A race's roster as small portrait tiles grouped by the building that trains them (Town
## Center, Barracks, Archery Range, Stable, Siege Workshop, Castle), each group under a small
## caption: the early buildings on one row, the late ones (age 3 and on: siege, castle) on the
## next, each row flowing on if the panel is too narrow. A tile is the portrait in a well, its
## role under it and its age in the corner; hover for the unit's card (name, role, age, where
## it's trained, cost, stats, what it's for). Compact (team games): smaller tiles in one flow,
## no captions or role line (the groups stand apart; the card names the building). The
## portraits come later (set_portraits), once the army is baked; while a new army is forging
## the old portraits stay, dimmed (Dominic: "every card portrait is blank").
## Used by the lobby (scenes/match_setup.gd).

const UiTheme := preload("res://src/view/ui/theme.gd")
const DataLib := preload("res://src/data_lib.gd")

var compact := false
var look := {}                 # the side's culture look (its tooltips wear it)
var _tiles := {}               # slot -> Tile
static var _bdata := {}
const LATE_AGE := 3            # buildings from this age start the second row


func _init(is_compact := false) -> void:
	compact = is_compact
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS


## The tiles for a race's lines, grouped by building in the tech tree's column order.
func show_race(race: Dictionary, rules: Dictionary) -> void:
	if _bdata.is_empty():
		_bdata = DataLib.load_json("res://data/buildings.json")
	for n in get_children():
		remove_child(n)
		n.queue_free()
	var old := _tiles
	_tiles = {}
	var roles := {}
	for r in rules.roster:
		roles[r.slot] = r
	var groups := {}   # building -> [unit]
	for u in race.units:
		var b: String = roles[u.recipe.slot].building
		if not groups.has(b):
			groups[b] = []
		groups[b].append(u)
	var order: Array = _bdata.tree.filter(func(id): return groups.has(id))
	for b in groups:
		if not b in order:
			order.append(b)
	var flow: HFlowContainer = null
	for b in order:
		if flow == null or (not compact and int(_bdata.buildings[b].age) >= LATE_AGE and int(_bdata.buildings[flow.get_meta("first")].age) < LATE_AGE):
			flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 12 if compact else 14)
			flow.add_theme_constant_override("v_separation", 4 if compact else 6)
			flow.mouse_filter = Control.MOUSE_FILTER_PASS
			flow.set_meta("first", b)
			add_child(flow)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1 if compact else 2)
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		if not compact:   # (compact: the groups apart, the building on each unit's card: two panels a column leave no room)
			var cap := UiTheme.label(String(_bdata.buildings[b].name).to_upper(), "Caption")
			cap.add_theme_font_size_override("font_size", 12)
			col.add_child(cap)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(row)
		for u in groups[b]:
			var t := Tile.new()
			t.compact = compact
			t.look = look
			t.setup(u, roles[u.recipe.slot], String(_bdata.buildings[b].name))
			if old.has(u.recipe.slot) and old[u.recipe.slot].pic.texture != null:   # the old army's portrait, dimmed, until the new one is baked
				t.pic.texture = old[u.recipe.slot].pic.texture
			t.pic.modulate.a = 0.35
			_tiles[u.recipe.slot] = t
			row.add_child(t)
		flow.add_child(col)


## The baked portraits: portrait(slot) -> Texture2D (null leaves the tile's as it is).
func set_portraits(portrait: Callable) -> void:
	for slot in _tiles:
		var tex: Texture2D = portrait.call(slot)
		if tex != null:
			_tiles[slot].pic.texture = tex
			_tiles[slot].pic.modulate.a = 1.0


## One unit: the portrait in a well, its age in the corner, its role underneath (not compact).
class Tile extends VBoxContainer:
	const Icons := preload("res://src/view/art/icons.gd")
	var compact := false
	var look := {}
	var pic: TextureRect
	var _card := {}

	func setup(u: Dictionary, role: Dictionary, building: String) -> void:
		add_theme_constant_override("separation", 0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var side := 38 if compact else 56
		custom_minimum_size.x = side if compact else 64
		var well := PanelContainer.new()
		well.theme_type_variation = "Well"
		var wb: StyleBox = UiTheme.well_box(look)
		for m in ["left", "right", "top", "bottom"]:
			wb.set("content_margin_" + m, 2)
		well.add_theme_stylebox_override("panel", wb)
		well.custom_minimum_size = Vector2(side, side)
		well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(well)
		pic = TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(pic)
		var tier := int(u.recipe.tier)
		var age := UiTheme.label(["", "I", "II", "III", "IV"][clampi(tier, 0, 4)], "Caption")   # the age it arrives in, a quiet numeral
		age.add_theme_font_size_override("font_size", 10 if compact else 12)
		age.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		age.add_theme_constant_override("outline_size", 3)
		age.size_flags_horizontal = Control.SIZE_SHRINK_END
		age.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		age.mouse_filter = Control.MOUSE_FILTER_IGNORE
		age.visible = tier > 1
		well.add_child(age)
		var what := String(role.get("name", String(u.recipe.slot).capitalize()))
		if not compact:
			var name := UiTheme.label(String(role.get("short", what)), "Dim")
			name.add_theme_font_size_override("font_size", 12)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name.clip_text = true
			name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			name.custom_minimum_size.x = 10
			name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(name)
		_card = {"u": u, "what": what, "role": role, "building": building}
		tooltip_text = u.recipe.name   # (the card itself is drawn by _make_custom_tooltip)

	## The unit card: name, role, age and building, the cost with resource icons, stats, its job.
	func _make_custom_tooltip(_for_text: String) -> Object:
		var k: float = get_global_transform_with_canvas().get_scale().x   # tooltips are popups outside any scaled root
		var card: Control = UiTheme.tip_card("", look, k)
		var rt: RichTextLabel = card.get_child(0)
		var u: Dictionary = _card.u
		var e: Dictionary = u.eval
		rt.append_text("[b]%s[/b]\n[color=#d8b878]%s  ·  age %d  ·  %s[/color]\n" % [u.recipe.name, _card.what, int(u.recipe.tier), _card.building])
		for r in ["food", "wood", "stone", "gold"]:
			if int(e.cost.get(r, 0)) > 0:
				rt.append_text("%d " % int(e.cost[r]))
				rt.add_image(Icons.texture("res_" + r), roundi(18 * k), roundi(18 * k), Color.WHITE, INLINE_ALIGNMENT_CENTER)
				rt.append_text("    ")
		rt.append_text("\nHP %d   Attack %d   Armour %d/%d\nRange %d   Speed %d" % [int(e.hp), int(e.attack),
			int(e.armour.get("melee", 0)), int(e.armour.get("pierce", 0)), int(e.range), int(e.speed)])
		if _card.role.get("desc", "") != "":
			rt.append_text("\n[color=#c8bca0]%s[/color]" % _card.role.desc)
		return card
