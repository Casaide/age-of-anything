extends Control
## The tech tree page: one race's whole tree on one screen. Ages are rows (1 at the top),
## buildings are columns (data/buildings.json "tree"); under each building its unit lines (one
## node per age step, joined, with the race's own portrait and name for that step) and its
## research (icon from assets/art/icons, else the scroll), packed in lanes so a line or a
## research track runs straight down. Planned items (milestone 12/13) are empty frames with the
## name in grey. Research only some races get carries a small mark, or a cross for a race that
## lacks it. The race panel on the left: name, creature, culture, the army idling, bonuses,
## its own research, what it lacks, how it moves. Hover any node for its card.
## View only. In a match it also reads the player's state (researched lit, in progress with a
## bar, not yet dimmed) and the sim keeps running underneath; opened with F2 or the top bar's
## button, closed with Esc. From the lobby: a "Tech tree" button on each side's banner.
## What it shows comes from src/view/tech_tree_model.gd (checked headless in tests/run_tests.gd).
## It wears the race's culture (src/view/ui/theme.gd): the panels' frames and crest, the type.

const Model := preload("res://src/view/tech_tree_model.gd")
const Icons := preload("res://src/view/art/icons.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const Tech := preload("res://src/sim/tech.gd")
const Audio := preload("res://src/view/audio.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")
const Mat := preload("res://src/view/ui/ui_materials.gd")
const ForgeVeil := preload("res://src/view/loaders/forge_veil.gd")
const LoaderStyle := preload("res://src/view/loaders/loader_style.gd")

signal closed

const BG := Color("#1c1712")
const PANEL := Color("#2a231b")
const SLOT := Color("#1e1a14")
const EDGE := Color("#6a5a40")
const BRONZE := Color("#a08858")
const GOLD := Color("#f2c94c")
const TEXT := Color("#efe4c8")
const DIM := Color("#b8ad94")
const GREY := Color("#7a7166")
const NEED := Color("#e88a70")
const GOOD := Color("#a8d880")
const GRASS := Color("#4e6e2a")

const LANE := 80        # one lane of nodes under a building
const NODE := 50        # a unit or research frame
const BNODE := 58       # a building frame
const NAME_H := 28      # two lines of a node's name
const BNAME_H := 18     # one line of a building's name
const BUS := 14         # the gap under a building's name where its line branches to its lanes
const COL_PAD := 6
const COL_GAP := 12
const ROW_PAD := 8
const ROW_H := ROW_PAD + BNODE + BNAME_H + BUS + NODE + NAME_H + ROW_PAD
const RAIL := 150       # the age rail on the left of the tree
const SIDE := 300       # the race panel
const STAGE := Vector2(268, 118)
const STAGE_ZOOM := 2.0

var model: Dictionary
var race: Dictionary
var rules: Dictionary
var lib
var kit
var side := 0                 # the race's index in kit.icons ("side:slot@age")
var team := Color.WHITE
var world                     # in a match: the World, and whose tree this is
var player := -1

var _views := {}              # node key -> TreeNode
var _col_x: Array = []        # per column: [x, width]
var _canvas: Control
var _rail: Control
var _rail_inner: Control
var _scroll: ScrollContainer
var _race_box: VBoxContainer
var _title: Label
var _drag_from := Vector2.INF
var _since := 0.0
var _content: Control           # everything under the loader
var _veil: ForgeVeil            # the loader: the forge veil with words, and a bar
var _bar: Control
var _loading := false
var _shown := 0.0               # the bar's fill as drawn
var _opened := 0                # counts opens and closes: a bake that finishes after either is ignored


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()   # the dark table the lobby sits on
	bg.texture = Mat.texture("wood", Color("#2a1c12"))
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)   # room for the crests
	margin.add_child(col)
	col.add_child(_header())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left := _panel()
	left.theme_type_variation = "CrestFrame"
	left.custom_minimum_size.x = SIDE
	row.add_child(left)
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(lscroll)
	_race_box = VBoxContainer.new()
	_race_box.add_theme_constant_override("separation", 8)
	_race_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lscroll.add_child(_race_box)
	var right := _panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var tree := HBoxContainer.new()
	tree.add_theme_constant_override("separation", 0)
	right.add_child(tree)
	_rail = Control.new()   # the ages, fixed while the tree scrolls sideways
	_rail.custom_minimum_size.x = RAIL
	_rail.clip_contents = true
	tree.add_child(_rail)
	_rail_inner = Control.new()
	_rail_inner.draw.connect(_draw_rail)
	_rail.add_child(_rail_inner)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_child(_scroll)
	_canvas = Control.new()
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_scroll.add_child(_canvas)
	_content = margin
	# The loader (the game's forge veil and a bar), over the race panel and the tree while what
	# the page shows is baked.
	_veil = ForgeVeil.new()
	_veil.offset_top = 90   # (the title and the key stay clear)
	add_child(_veil)
	_bar = Control.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER)
	_bar.custom_minimum_size = Vector2(420, 16)
	_bar.position = Vector2(-210, 34)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_bar.visible = false
	_veil.add_child(_bar)
	visible = false


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_style_box(LoaderStyle.box(LoaderStyle.TROUGH, LoaderStyle.EDGE, 2, 8), r)
	var inner := r.grow(-3)
	if _shown > 0.0:
		_bar.draw_rect(Rect2(inner.position, Vector2(inner.size.x * _shown, inner.size.y)), LoaderStyle.GOLD.darkened(0.2))


func _header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_title = UiTheme.label("", "Title")
	_title.add_theme_font_size_override("font_size", 36)
	head.add_child(_title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	for item in [["done", "Have it"], ["progress", "Under way"], ["open", "Can get"], ["locked", "Not yet"], ["planned", "Planned"]]:
		var key := HBoxContainer.new()
		key.add_theme_constant_override("separation", 6)
		var swatch := TreeNode.new()
		swatch.data = {"kind": "key", "status": "planned" if item[0] == "planned" else "built", "name": ""}
		swatch.state = item[0]
		swatch.progress = 0.55
		swatch.frame_size = 18
		swatch.custom_minimum_size = Vector2(20, 20)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_child(swatch)
		key.add_child(_label(item[1], 16, DIM))
		key.set_meta("match_only", item[0] in ["done", "progress", "locked"])
		head.add_child(key)
	var mark := HBoxContainer.new()   # race-only research
	mark.add_theme_constant_override("separation", 6)
	var m := _label("◆", 16, GOLD)
	mark.add_child(m)
	mark.add_child(_label("Race's own", 16, DIM))
	head.add_child(mark)
	var close_b := UiTheme.button("Close (Esc)")
	close_b.custom_minimum_size = Vector2(150, 46)
	close_b.pressed.connect(close)
	head.add_child(close_b)
	return head


## Show a race's tree. `p_kit` holds the portraits (kit.icons "side:slot@age") and the
## buildings' bakes; `p_world` and `p_player` only in a match.
func open(p_race: Dictionary, p_rules: Dictionary, p_lib, p_kit, p_side: int, p_team: Color, p_world = null, p_player := -1) -> void:
	race = p_race
	rules = p_rules
	lib = p_lib
	kit = p_kit
	side = p_side
	team = p_team
	world = p_world
	player = p_player
	model = Model.build(race, rules, lib)
	var lk := UiTheme.look(race.family)
	theme = UiTheme.theme(lk, 17)
	TreeNode.look = lk
	_title.text = "Tech tree:  %s" % race.name
	for n in _title.get_parent().get_children():
		if n.has_meta("match_only"):
			n.visible = world != null or not n.get_meta("match_only")
	_opened += 1
	var me := _opened
	visible = true
	UiTheme.arrive(_content, 10.0)
	Audio.of(get_tree()).play("ui_tip")
	if kit != null and not kit.tree_ready(race, side):
		# Not all baked yet (the lobby bakes only its stages up front, the rest behind): the tree's
		# layout at once under the loader, then its portraits, the army and the buildings.
		for n in _race_box.get_children():
			n.queue_free()
		_fill_tree()
		_refresh()
		_loading = true
		_shown = 0.0
		_veil.show_veil("Painting the portraits...")
		_bar.visible = true
		await kit.bake_tree(race, side, team)
		if me != _opened:   # closed, or opened on another race, meanwhile
			return
		_loading = false
		_veil.hide_veil()
		_bar.visible = false
	_fill_race()
	_fill_tree()
	_refresh()


## The page is waiting on its bake (its loader is up).
func is_loading() -> bool:
	return _loading


func close() -> void:
	if not visible:
		return
	visible = false
	_opened += 1
	if _loading:   # (the bake goes on in the kit; reopened, the page waits for it again)
		_loading = false
		_veil.hide_veil()
		_bar.visible = false
	for n in _race_box.get_children():   # the idling army stops with the page
		n.queue_free()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE:
			if not event.echo:
				close()
		KEY_LEFT, KEY_RIGHT:   # sideways through the buildings
			_scroll.scroll_horizontal += LANE * 3 * (1 if event.keycode == KEY_RIGHT else -1)
		KEY_HOME:
			_scroll.scroll_horizontal = 0
		KEY_END:
			_scroll.scroll_horizontal = int(_canvas.size.x)
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if _loading:   # the loader's bar glides up to the bake's real progress, never past it
		var real: float = kit.tree_progress()
		_shown = minf(real, _shown + delta * 1.5) if real > _shown else real
		_veil.words.text = "Painting the portraits...  %d%%" % roundi(_shown * 100.0)
		_bar.queue_redraw()
	_rail_inner.position.y = -_scroll.scroll_vertical
	_since += delta
	if world != null and _since > 0.25:   # the match goes on: what's researched, under way, open
		_since = 0.0
		_refresh()


## Drag the tree sideways with the mouse (the wheel scrolls it too).
func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		_drag_from = event.position if event.pressed else Vector2.INF
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF:
		_scroll.scroll_horizontal -= int(event.relative.x)
		_scroll.scroll_vertical -= int(event.relative.y)


# ------------------------------------------------------------------ the race panel

func _fill_race() -> void:
	for n in _race_box.get_children():
		n.queue_free()
	var r: Dictionary = model.race
	_race_box.add_child(_gap(10))
	var name := UiTheme.label(r.name, "Title", true)
	name.add_theme_font_size_override("font_size", 32)
	_race_box.add_child(name)
	_race_box.add_child(_label("%s  ·  %s culture" % [r.creature, r.culture], 17, DIM, true))
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	well.add_child(_stage())
	_race_box.add_child(well)
	_section("Bonuses", r.bonuses, "Nothing beyond the usual")
	_section("Own research", r.own, "None")
	_section("Lacks", r.lacks, "Nothing")
	_section("Moves", r.moves, "")
	var built := 0
	var planned := 0
	for n in model.nodes:
		if n.status == Model.PLANNED:
			planned += 1
		else:
			built += 1
	var foot := _label("%d on this tree are in the game; %d more are planned (the blank frames)." % [built, planned], 15, GREY, true)
	_race_box.add_child(_gap(6))
	_race_box.add_child(foot)


func _section(title: String, lines: Array, empty: String) -> void:
	_race_box.add_child(_gap(4))
	var head := UiTheme.label(title.to_upper(), "Caption")
	head.add_theme_font_size_override("font_size", 14)
	_race_box.add_child(head)
	_race_box.add_child(UiTheme.Rule.new(TreeNode.look.get("metal", BRONZE)))
	if lines.is_empty():
		_race_box.add_child(_label(empty, 17, GREY, true))
	for l in lines:
		_race_box.add_child(_label("•  " + l, 17, TEXT, true))


## The army idling on a strip of grass, like the lobby's banner.
func _stage() -> Control:
	var stage := SubViewportContainer.new()
	stage.custom_minimum_size = STAGE
	stage.stretch = true
	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	stage.add_child(vp)
	var ground := ColorRect.new()
	ground.color = GRASS
	ground.size = STAGE * 2
	vp.add_child(ground)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.02, 0.35)
	shade.size = Vector2(STAGE.x * 2, STAGE.y * 0.35)
	vp.add_child(shade)
	var layer := Node2D.new()
	layer.y_sort_enabled = true
	layer.scale = Vector2.ONE * STAGE_ZOOM
	vp.add_child(layer)
	var units: Array = race.units
	var age: int = world.ages[player] if world != null else 1
	for k in units.size():
		var u: Dictionary = units[k]
		var step: Dictionary = u.line[0]
		for l in u.line:
			if int(l.age) <= age:
				step = l
		var view := UnitView.new()
		view.build(step.recipe, lib, team, step.eval.speed)
		view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
		view.pose_steps = 8
		view.art_px = ArtKit.ART_SCALE / STAGE_ZOOM
		var w := STAGE.x / STAGE_ZOOM
		view.position = Vector2(w * (k + 0.7) / (units.size() + 0.4), STAGE.y / STAGE_ZOOM * (0.66 if k % 2 == 0 else 0.86))
		view.face(1.0)
		layer.add_child(view)
	return stage


# ------------------------------------------------------------------ the tree

func _row_y(age: int) -> float:
	return (age - 1) * ROW_H


func _fill_tree() -> void:
	for n in _canvas.get_children():
		n.queue_free()
	for n in _rail_inner.get_children():
		n.queue_free()
	_views.clear()
	_col_x.clear()
	var x := COL_GAP * 0.5
	for c in model.columns:
		var w: float = c.lanes * LANE + COL_PAD * 2
		_col_x.append([x, w])
		x += w + COL_GAP
	var h: float = model.ages.size() * ROW_H
	_canvas.custom_minimum_size = Vector2(x, h)
	_rail_inner.size = Vector2(RAIL, h)
	for n in model.nodes:
		var v := TreeNode.new()
		v.data = n
		v.team = team
		var cx: float = _col_x[n.col][0]
		if n.kind == "building":
			v.frame_size = BNODE
			v.size = Vector2(maxf(_col_x[n.col][1], LANE), BNODE + BNAME_H)
			v.position = Vector2(cx + (_col_x[n.col][1] - v.size.x) * 0.5, _row_y(n.age) + ROW_PAD)
		else:
			v.frame_size = NODE
			v.size = Vector2(LANE, NODE + NAME_H)
			v.position = Vector2(cx + COL_PAD + n.lane * LANE, _item_y(n.age))
		v.icon = _icon(n)
		v.tooltip_text = _tip(n)
		_canvas.add_child(v)
		_views[n.key] = v
	for a in model.ages:   # the rail: each age's number, name and what it needs
		var y := _row_y(a.age)
		var planned: bool = a.status == Model.PLANNED
		var num := _label(_roman(a.age), 30, GREY if planned else GOLD)
		num.position = Vector2(14, y + 10)
		_rail_inner.add_child(num)
		var nm := _label(a.name, 17, GREY if planned else TEXT, true)
		nm.position = Vector2(14, y + 52)
		nm.custom_minimum_size.x = RAIL - 24
		_rail_inner.add_child(nm)
		var needs := "Where everyone starts"
		if a.requires_text != "":
			needs = "Needs " + a.requires_text
		elif not a.requires.is_empty():
			needs = "Needs a " + " and a ".join(a.requires.map(func(id): return _bname(id)))
		var nd := _label(needs + (" (planned)" if planned else ""), 12, GREY if planned else DIM, true)
		nd.position = Vector2(14, y + 76)
		nd.custom_minimum_size.x = RAIL - 24
		_rail_inner.add_child(nd)
		var bar := ProgressBar.new()   # an age-up under way
		bar.show_percentage = false
		bar.position = Vector2(14, y + ROW_H - 22)
		bar.size = Vector2(RAIL - 28, 6)
		bar.max_value = 1.0
		bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.5)))
		bar.add_theme_stylebox_override("fill", _flat(GOLD))
		bar.visible = false
		bar.name = "bar%d" % a.age
		_rail_inner.add_child(bar)
	_canvas.queue_redraw()
	_rail_inner.queue_redraw()


func _item_y(age: int) -> float:
	return _row_y(age) + ROW_PAD + BNODE + BNAME_H + BUS


func _icon(n: Dictionary) -> Texture2D:
	if n.status == Model.PLANNED:
		return null
	match n.kind:
		"building":
			var arch: String = lib.architecture(race)
			if kit != null and kit.buildings.has("%s:%s" % [arch, n.id]):
				return kit.building_icon(arch, n.id)
			return null
		"unit":
			if kit == null:
				return null
			return kit.icons.get("%d:%s@%d" % [side, n.slot, n.age], kit.icons.get("%d:%s" % [side, n.slot]))
		"research":
			return Icons.texture(n.icon)
	return null


## Backgrounds: age bands, each building's column from its age down, and the lines.
func _draw_canvas() -> void:
	var w := _canvas.size.x
	for a in model.ages:
		var y := _row_y(a.age)
		if a.age % 2 == 0:
			_canvas.draw_rect(Rect2(0, y, w, ROW_H), Color(1, 1, 1, 0.022))
		if a.age > 1:
			_canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(EDGE, 0.45), 1.0)
	for c in model.columns.size():
		var col: Dictionary = model.columns[c]
		var top := _row_y(col.age) + 3
		var r := Rect2(_col_x[c][0], top, _col_x[c][1], _canvas.size.y - top - 3)
		var planned: bool = col.status == Model.PLANNED
		var st := StyleBoxFlat.new()
		st.bg_color = Color(PANEL, 0.35 if planned else 0.75)
		st.border_color = Color(EDGE, 0.3 if planned else 0.65)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		_canvas.draw_style_box(st, r)
	# Lines: from each building down to its lanes; between the nodes in a lane.
	var joined := {}
	for j in model.joins:
		joined[j[0] + ">" + j[1]] = true
	var lanes := {}   # "col:lane" -> nodes, top to bottom
	for n in model.nodes:
		if n.kind != "building":
			var k := "%d:%d" % [n.col, n.lane]
			if not lanes.has(k):
				lanes[k] = []
			lanes[k].append(n)
	for n in model.nodes:
		if n.kind != "building":
			continue
		var v: TreeNode = _views[n.key]
		var bx := v.position.x + v.size.x * 0.5
		var bus_y := _row_y(n.age) + ROW_PAD + BNODE + BNAME_H + BUS * 0.5
		var mine: Array = lanes.keys().filter(func(k): return int(k.get_slice(":", 0)) == n.col)
		if mine.is_empty():
			continue
		var built: bool = n.status != Model.PLANNED
		var bus_c := _line_colour(built, _views[n.key].state == "done")
		_canvas.draw_line(Vector2(bx, v.position.y + BNODE + BNAME_H - 2), Vector2(bx, bus_y), bus_c, 2.0)
		var xs := []
		for k in mine:
			var ns: Array = lanes[k]
			ns.sort_custom(func(p, q): return p.age < q.age)
			var first: TreeNode = _views[ns[0].key]
			var lx := first.position.x + LANE * 0.5
			xs.append(lx)
			var on: bool = built and ns[0].status != Model.PLANNED and not ns[0].get("lacks", false)
			_canvas.draw_line(Vector2(lx, bus_y), Vector2(lx, first.position.y + 1), _line_colour(on, first.state == "done"), 2.0)
			for i in range(1, ns.size()):
				var a: TreeNode = _views[ns[i - 1].key]
				var b: TreeNode = _views[ns[i].key]
				var from := Vector2(lx, a.position.y + NODE + 1)
				var to := Vector2(lx, b.position.y + 1)
				if joined.has(ns[i - 1].key + ">" + ns[i].key):
					var lit: bool = b.state == "done"
					_canvas.draw_line(from, to, _line_colour(ns[i].status != Model.PLANNED, lit), 2.0)
				else:
					_canvas.draw_dashed_line(from, to, Color(EDGE, 0.45), 1.0, 3.0)
		xs.append(bx)
		_canvas.draw_line(Vector2(xs.min(), bus_y), Vector2(xs.max(), bus_y), bus_c, 2.0)


func _line_colour(built: bool, lit: bool) -> Color:
	if not built:
		return Color(GREY, 0.45)
	return GOLD if lit else Color(BRONZE, 0.85)


func _draw_rail() -> void:
	for a in model.ages:
		var y := _row_y(a.age)
		if a.age % 2 == 0:
			_rail_inner.draw_rect(Rect2(0, y, RAIL, ROW_H), Color(1, 1, 1, 0.022))
		if a.age > 1:
			_rail_inner.draw_line(Vector2(0, y), Vector2(RAIL, y), Color(EDGE, 0.45), 1.0)
		if world != null and world.ages[player] == a.age:   # where you are
			_rail_inner.draw_rect(Rect2(0, y + 6, 4, ROW_H - 12), GOLD)
	_rail_inner.draw_line(Vector2(RAIL - 1, 0), Vector2(RAIL - 1, _rail_inner.size.y), Color(EDGE, 0.6), 1.0)


## Each node's state: in a match from the player's progress; in the lobby, open or planned.
func _refresh() -> void:
	for key in _views:
		var v: TreeNode = _views[key]
		var n: Dictionary = v.data
		var st := ["open", 0.0]
		if n.status == Model.PLANNED:
			st = ["planned", 0.0]
		elif n.get("lacks", false):
			st = ["locked", 0.0]
		elif world != null:
			st = _state(n)
		if v.state != st[0] or not is_equal_approx(v.progress, st[1]):
			v.state = st[0]
			v.progress = st[1]
			v.queue_redraw()
			v.tooltip_text = _tip(n)
	if world != null:
		for a in model.ages:
			var bar: ProgressBar = _rail_inner.get_node_or_null("bar%d" % a.age)
			if bar == null:
				continue
			bar.visible = false
			for b in world.buildings.count():
				if world.buildings.owner[b] == player and Tech.entry(Tech.AGE_UP) in world.buildings.queue[b] and a.age == world.ages[player] + 1:
					bar.visible = true
					bar.value = float(world.buildings.train[b]) / float(Tech.head_ticks(world, b)) if Tech.head(world, b) == Tech.AGE_UP else 0.0   # 0 while it waits its turn
	_canvas.queue_redraw()
	_rail_inner.queue_redraw()


## [state, progress] of a built node for the match's player.
func _state(n: Dictionary) -> Array:
	var age: int = world.ages[player]
	var bs = world.buildings
	match n.kind:
		"building":
			var best := -1.0
			for b in bs.count():
				if bs.owner[b] == player and world.btypes[bs.kind[b]].id == n.id:
					if bs.done[b] == 1:
						return ["done", 0.0]
					best = maxf(best, float(bs.progress[b]) / float(maxi(1, world.btypes[bs.kind[b]].build_ticks)))
			if best >= 0.0:
				return ["progress", best]
		"research":
			var r := Tech.research_index(world, n.id)
			if r >= 0:
				if world.researched[player][r] == 1:
					return ["done", 0.0]
				for b in bs.count():
					if bs.owner[b] == player and Tech.entry(r) in bs.queue[b]:
						return ["progress", float(world.buildings.train[b]) / float(Tech.head_ticks(world, b)) if Tech.head(world, b) == r else 0.0]
		"unit":
			if n.first or n.slot == "worker":   # a line's first step: the age and a building to train it; workers follow the age
				if age >= n.age and (n.slot == "worker" or Tech.has_building(world, player, n.building)):
					return ["done", 0.0]
			else:
				var r := Tech.research_index(world, "line.%s.%d" % [n.slot, n.age])
				if r >= 0:
					if world.researched[player][r] == 1:
						return ["done", 0.0]
					for b in bs.count():
						if bs.owner[b] == player and Tech.entry(r) in bs.queue[b]:
							return ["progress", float(world.buildings.train[b]) / float(Tech.head_ticks(world, b)) if Tech.head(world, b) == r else 0.0]
	return ["open", 0.0] if age >= int(n.age) else ["locked", 0.0]


# ------------------------------------------------------------------ hover cards

func _tip(n: Dictionary) -> String:
	var out := "[b]%s[/b]" % n.name
	if n.kind == "unit" and n.name != n.line_name:
		out += "  [color=#%s]%s line[/color]" % [DIM.to_html(false), n.line_name]
	var planned: bool = n.status == Model.PLANNED
	var cost := _cost_text(n.get("cost", {}))
	if cost != "" and not planned:
		out += "\n" + cost
	var lines := []
	match n.kind:
		"building":
			lines.append(n.desc)
			var trains := []
			var research := []
			for m in model.nodes:
				if m.col == n.col and m.kind == "unit" and m.first:
					trains.append(m.name)
				if m.col == n.col and m.kind == "research":
					research.append(m.name)
			if not trains.is_empty():
				lines.append("Trains: " + ", ".join(trains))
			if not research.is_empty():
				lines.append("Research: " + ", ".join(research))
			lines.append(_dim("Age %d%s" % [n.age, ("   Hotkey " + n.hotkey) if n.get("hotkey", "") != "" and not planned else ""]))
		"unit":
			lines.append(n.desc)
			if not n.step.is_empty():
				var e: Dictionary = n.step.eval
				lines.append("HP %d  Attack %d  Armour %d/%d  Range %d  Speed %d" % [int(e.hp), int(e.attack),
					int(e.armour.get("melee", 0)), int(e.armour.get("pierce", 0)), int(e.range), int(e.speed)])
			var where := _bname(n.building)
			if n.get("lacks", false):
				lines.append("[color=#%s]Not in this race's tree (see its notes)[/color]" % NEED.to_html(false))
			elif n.first:
				lines.append(_dim("Trained at the %s from age %d" % [where, n.age]))
				if n.early_kit != "":   # generated from an earlier age than its building opens
					lines.append(_dim("Trains first in its age-%d kit (%s); the line upgrade here gives this one" % [n.tier, n.early_kit]))
			elif n.slot == "worker":
				lines.append(_dim("Workers take this kit on reaching age %d" % n.age))
			else:
				lines.append(_dim("Line upgrade at the %s in age %d" % [where, n.age]))
		"research":
			lines.append(n.desc)
			if n.effect != "":
				lines.append("[color=#%s]%s[/color]" % [GOOD.to_html(false), n.effect])
			lines.append(_dim("At the %s, age %d" % [_bname(n.building), n.age]))
			if not n.only.is_empty():
				var who := ", ".join(n.only.map(func(o): return String(o).capitalize()))
				if n.lacks:
					lines.append("[color=#%s]Only for %s: not in this race's tree[/color]" % [NEED.to_html(false), who])
				else:
					lines.append("[color=#%s]Only for %s[/color]" % [GOLD.to_html(false), who])
	for l in lines:
		if l != "":
			out += "\n" + l
	if planned:
		out += "\n[color=#%s]Planned: not in the game yet[/color]" % GREY.lightened(0.25).to_html(false)
	elif world != null and _views.has(n.key):
		var v: TreeNode = _views[n.key]
		match v.state:
			"done":
				out += "\n[color=#%s]%s[/color]" % [GOLD.to_html(false), {"building": "Built", "research": "Researched", "unit": "Yours"}[n.kind]]
			"progress":
				out += "\n[color=#%s]Under way: %d%%[/color]" % [GOLD.to_html(false), int(v.progress * 100.0)]
			"locked":
				if not n.get("lacks", false):
					out += "\n[color=#%s]Needs age %d[/color]" % [NEED.to_html(false), n.age]
	return out


func _dim(text: String) -> String:
	return "[color=#%s]%s[/color]" % [DIM.to_html(false), text]


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for info in lib.resource_info:
		var v := int(cost.get(info.id, 0))
		if v > 0:
			parts.append("[color=#%s]%d %s[/color]" % [Color(info.colour).lightened(0.3).to_html(false), v, info.name])
	return "    ".join(parts)


func _bname(id: String) -> String:
	for c in model.columns:
		if c.id == id:
			return c.name
	return id


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI"][n] if n < 7 else str(n)


# ------------------------------------------------------------------ the look

func _label(text: String, size: int, colour: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _gap(h: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	return g


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(2)
	return s


func _box(fill: Color, edge: Color, width: int, radius := 4) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Frame"
	return p


## One node: a framed picture (or an empty frame for planned items) with its name under it.
## Its look follows `state`: done (lit gold), progress (a bar), open, locked (dimmed), planned.
class TreeNode extends Control:
	static var look := {}   # the page's look (the race's culture)
	var data: Dictionary
	var icon: Texture2D
	var team := Color.WHITE
	var state := "open"
	var progress := 0.0
	var frame_size := 50
	var _hover := false
	var _pic: TextureRect
	var _name: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
		var f := _frame()
		if icon != null:
			_pic = TextureRect.new()
			_pic.texture = icon
			_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if not icon is ImageTexture or data.kind == "unit" else CanvasItem.TEXTURE_FILTER_LINEAR
			_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var inset := 3 if data.kind == "unit" else 5
			_pic.position = f.position + Vector2(inset, inset)
			_pic.size = f.size - Vector2(inset, inset) * 2
			_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if icon is AtlasTexture:   # a building's bake, in the team key: recolour it
				_pic.material = PartShape.team_material
				_pic.self_modulate = Color(team.r, team.g, team.b, 1.0)
			add_child(_pic)
		if data.get("name", "") != "":
			_name = Label.new()
			_name.text = data.name
			_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_name.autowrap_mode = TextServer.AUTOWRAP_WORD   # whole words; a name too long ends in "..."
			_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_name.max_lines_visible = 2 if data.kind != "building" else 1
			_name.add_theme_font_size_override("font_size", 14 if data.kind == "building" else 12)
			_name.add_theme_constant_override("line_spacing", -3)
			_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			_name.add_theme_constant_override("outline_size", 3)
			_name.position = Vector2(0, frame_size + 1)
			_name.size = Vector2(size.x, 40)   # room for two lines; max_lines_visible keeps it to them
			_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_name)

	func _frame() -> Rect2:
		return Rect2(Vector2((size.x - frame_size) * 0.5, 0), Vector2.ONE * frame_size)

	func _draw() -> void:
		var f := _frame()
		var planned: bool = state == "planned"
		var edge: Color = look.get("frame_colour", Color("#6a5a40")).darkened(0.1)
		var fill := Color("#1a140e")
		var alpha := 1.0
		match state:
			"done":
				edge = Color("#f2c94c")
				fill = Color("#3a2e18")
				draw_rect(f.grow(3), Color(1.0, 0.8, 0.3, 0.16))   # a soft glow
			"progress":
				edge = Color("#d8b050")
			"locked":
				edge = Color("#4a4030")
				alpha = 0.38
			"planned":
				fill = Color(0.1, 0.09, 0.07, 0.6)
		if _hover and not planned:
			edge = edge.lightened(0.3)
		if planned:
			draw_rect(f, fill)
			var c := Color("#7a7166", 0.9 if _hover else 0.65)
			for side in [[f.position, f.position + Vector2(f.size.x, 0)], [f.position + Vector2(f.size.x, 0), f.end],
					[f.end, f.position + Vector2(0, f.size.y)], [f.position + Vector2(0, f.size.y), f.position]]:
				draw_dashed_line(side[0], side[1], c, 1.5, 4.0)
		else:
			var st := StyleBoxFlat.new()   # a sunk slot with a metal rim, lit on top
			st.bg_color = fill
			st.border_color = edge
			st.set_border_width_all(2 if state in ["done", "progress"] or _hover else 1)
			st.border_width_top += 1
			st.set_corner_radius_all(3)
			st.shadow_color = Color(0, 0, 0, 0.45)
			st.shadow_size = 3
			st.shadow_offset = Vector2(0, 2)
			draw_style_box(st, f)
			draw_line(f.position + Vector2(3, 2), Vector2(f.end.x - 3, f.position.y + 2), Color(0, 0, 0, 0.5), 2.0)
		if _pic != null:
			_pic.modulate = Color(1, 1, 1, alpha)
		if _name != null:
			var nc := Color("#efe4c8")
			if planned:
				nc = Color("#8a8174")
			elif state == "locked":
				nc = Color("#b8ad94", 0.6)
			elif state == "done":
				nc = Color("#f6dc8a")
			_name.add_theme_color_override("font_color", nc)
		if state == "progress":   # a bar along the frame's foot
			var bar := Rect2(f.position + Vector2(3, f.size.y - 8), Vector2(f.size.x - 6, 5))
			draw_rect(bar, Color(0, 0, 0, 0.7))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), Color("#f2c94c"))
		if data.get("lacks", false):   # not in this race's tree: crossed out
			var c := Color("#e88a70", 0.85)
			draw_line(f.position + Vector2(6, 6), f.end - Vector2(6, 6), c, 2.5)
			draw_line(f.position + Vector2(f.size.x - 6, 6), f.position + Vector2(6, f.size.y - 6), c, 2.5)
		elif data.get("race_only", false):   # the race's own: a small gold mark
			var p := f.position + Vector2(f.size.x - 7, 7)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Color("#f2c94c"))

	func _make_custom_tooltip(for_text: String) -> Object:
		var k: float = get_global_transform_with_canvas().get_scale().x   # tooltips are popups outside any scaled root
		return UiTheme.tip_card(for_text, look if not look.is_empty() else UiTheme.look(""), k)
