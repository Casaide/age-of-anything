extends Control
## The match loader: what you see while a match's art is made. Both armies stand on a stage
## facing each other (straight away when the lobby baked them; as soon as their parts are baked
## otherwise), the two race names with "vs", the map's name and its little picture, a bar fed by
## the art kit's real bake jobs (ArtKit.progress(): estimated renders done of those asked for,
## cache loads counting little), what it's busy with, and a tip. finish() fades it into the match.
##
## sim_debug makes one in _bake: start(kit, lib, races, teams, map_id), then finish() once the
## world is attached. Self-contained (its look is in src/view/loaders/loader_style.gd).

const Style := preload("res://src/view/loaders/loader_style.gd")
const ForgeVeil := preload("res://src/view/loaders/forge_veil.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const DataLib := preload("res://src/data_lib.gd")
const UiScale := preload("res://src/view/ui_scale.gd")

const NEEDS := Vector2(1400, 860)   # the layout's home size, in UI pixels
const TIP_EVERY := 7.0              # seconds between tips

var kit
var lib
var races: Array = []
var teams: Array = []
var root: Control         # everything, scaled to the window
var margin: MarginContainer
var holder: Control       # the stage's box (its height follows the window)
var shade: TextureRect
var zoom: float = Style.STAGE_ZOOM   # screen pixels per canvas unit on the stage (bigger on a tall window)
var stage: SubViewportContainer
var layer: Node2D         # the armies, y-sorted, on the stage
var veil: ForgeVeil
var bar: Control          # drawn: trough, fill, sheen
var busy: Label
var pct: Label
var tip: Label
var tips: Array = []
var shown := 0.0          # the bar's fill as drawn (eases towards the real value, never past it)
var _tip_at := 0.0
var _t := 0.0
var _finishing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing reaches the match underneath while loading


## Show the loader for this match; it follows kit's bake from here.
func start(p_kit, p_lib, p_races: Array, p_teams: Array, map_id: String) -> void:
	kit = p_kit
	lib = p_lib
	races = p_races
	teams = p_teams
	tips = DataLib.load_json("res://data/tips.json").tips
	var bg := ColorRect.new()
	bg.color = Style.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build(map_id)
	get_window().size_changed.connect(_fit)
	_fit()
	kit.units_ready.connect(_muster)
	kit.atlas_rebuilt.connect(_redraw)
	if _units_baked():
		_muster()
	else:
		veil.show_veil("Mustering the armies...")


## Scale to the window; the content keeps to a readable width, the stage takes the height
## there is (a taller stage stands the armies bigger, in whole steps).
func _fit() -> void:
	var f := UiScale.factor(get_window(), NEEDS)
	root.scale = Vector2(f, f)
	root.size = get_viewport_rect().size / f
	var side := maxf(56.0, (root.size.x - Style.MAX_W) * 0.5)
	margin.add_theme_constant_override("margin_left", roundi(side))
	margin.add_theme_constant_override("margin_right", roundi(side))
	var h := clampf(root.size.y * 0.46, Style.STAGE_H, Style.STAGE_H * 1.8)
	holder.custom_minimum_size.y = h
	shade.size = Vector2(3000, h)
	zoom = Style.STAGE_ZOOM * (1.6 if h >= Style.STAGE_H * 1.6 else (1.3 if h >= Style.STAGE_H * 1.2 else 1.0))
	layer.scale = Vector2.ONE * zoom


func _build(map_id: String) -> void:
	margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	var head := Style.label("PREPARING FOR BATTLE", Style.HEAD, Style.BRONZE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	# The names: left and right of the seal, each over its team's colour.
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 28)
	for k in 2:
		if k == 1:
			var vs := Style.label("vs", Style.VS, Style.BRONZE, 8)
			vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			names.add_child(vs)
		names.add_child(_name_block(k))
	col.add_child(names)
	# The stage: grass, both armies facing the middle.
	holder = Control.new()
	holder.custom_minimum_size.y = Style.STAGE_H
	col.add_child(holder)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -3
	frame.offset_top = -3
	frame.offset_right = 3
	frame.offset_bottom = 3
	frame.add_theme_stylebox_override("panel", Style.box(Color.TRANSPARENT, Style.EDGE, 3, 6))
	stage = SubViewportContainer.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.stretch = true
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	stage.add_child(vp)
	var ground := ColorRect.new()
	ground.color = Style.GRASS
	ground.size = Vector2(3000, 1000)
	vp.add_child(ground)
	shade = TextureRect.new()
	shade.texture = Style.ground_shade()
	shade.size = Vector2(3000, Style.STAGE_H)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(shade)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	layer.scale = Vector2.ONE * Style.STAGE_ZOOM
	vp.add_child(layer)
	holder.add_child(stage)
	holder.add_child(frame)
	veil = ForgeVeil.new()
	holder.add_child(veil)
	stage.resized.connect(_muster_if_shown)
	# Below: the map card, then the bar with what's being made, and a tip.
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 28)
	col.add_child(low)
	low.add_child(_map_card(map_id))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	low.add_child(right)
	var line := HBoxContainer.new()
	busy = Style.label("", Style.BODY, Style.TEXT)
	busy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(busy)
	pct = Style.label("", Style.BODY, Style.GOLD)
	line.add_child(pct)
	right.add_child(line)
	bar = Control.new()
	bar.custom_minimum_size.y = 18
	bar.draw.connect(_draw_bar)
	right.add_child(bar)
	tip = Style.label("", Style.TIP, Style.DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.y = 48
	right.add_child(tip)
	_next_tip()


func _name_block(k: int) -> Control:
	var b := VBoxContainer.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override("separation", 4)
	var race: Dictionary = races[k] if k < races.size() else {}
	var align := HORIZONTAL_ALIGNMENT_RIGHT if k == 0 else HORIZONTAL_ALIGNMENT_LEFT
	var n := Style.label(race.get("name", "?"), Style.TITLE, Style.TEXT, 6)
	n.horizontal_alignment = align
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(n)
	if not race.is_empty():
		var who := Style.label("%s, %s" % [lib.creatures[race.creature].plural, String(race.family).capitalize()], Style.BODY, Style.DIM)
		who.horizontal_alignment = align
		b.add_child(who)
	var stripe := ColorRect.new()   # the side's colour under its name
	stripe.color = (teams[k] as Color).darkened(0.1) if k < teams.size() else Style.EDGE
	stripe.custom_minimum_size = Vector2(0, 5)
	b.add_child(stripe)
	return b


func _map_card(map_id: String) -> Control:
	var m: Dictionary = DataLib.load_json("res://data/maps/%s.json" % map_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Color(Style.PANEL, 0.96), Style.EDGE, 2, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var pic := TextureRect.new()
	pic.texture = ImageTexture.create_from_image(map_image(m, teams))
	pic.custom_minimum_size = Vector2(190, 104)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Style.label("BATTLEFIELD", Style.HEAD - 2, Style.BRONZE))
	words.add_child(Style.label(m.name, Style.BODY + 5, Style.TEXT))
	words.add_child(Style.label("%d x %d tiles" % [int(m.width), int(m.height)], Style.BODY - 2, Style.DIM))
	row.add_child(words)
	return card


## A map as a small isometric diamond, coloured from data/terrain.json, each start in its
## side's colour (gold where there's no side).
static func map_image(m: Dictionary, team_colours := []) -> Image:
	var terr: Dictionary = DataLib.load_json("res://data/terrain.json").terrain
	var w := int(m.width)
	var h := int(m.height)
	var px := 2
	var img := Image.create((w + h) * px, (w + h) * px / 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = m.rows[y]
		for x in w:
			var c := Color(terr[m.legend.get(row[x], "grass")].colour)
			img.fill_rect(Rect2i((x - y + h) * px, (x + y) * px / 2, px * 2, px), c)
	for k in m.starts.size():
		var s: Array = m.starts[k]
		var sx := (int(s[0]) - int(s[1]) + h) * px
		var sy := (int(s[0]) + int(s[1])) * px / 2
		img.fill_rect(Rect2i(sx - 5, sy - 4, 12, 8), Color.BLACK)
		img.fill_rect(Rect2i(sx - 4, sy - 3, 10, 6), team_colours[k] if k < team_colours.size() else Style.GOLD)
	return img


func _units_baked() -> bool:
	if PartShape.atlas == null:
		return false
	for race in races:
		for u in race.units:
			var probe := UnitView.new()
			probe.build(u.recipe, lib, Color.WHITE, u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "" and not PartShape.baked.has(PartShape.bake_key(ps.part_id, ps.shapes, PartShape.team_neutral(ps.colours))):
					probe.free()
					return false
			probe.free()
	return true


func _muster_if_shown() -> void:
	if layer.get_child_count() > 0:
		_muster()


## A few that show each army off, facing the other side, one rank each (the whole roster twice, siege
## and all, in two ranks was too busy: Dominic).
const STAGE_ROLES := ["spear", "infantry", "archer", "large", "catapult"]


static func _pick(units: Array) -> Array:
	var out := []
	for role in STAGE_ROLES:
		for u in units:
			if u.recipe.get("role", "") == role:
				out.append(u)
				break
	return out


func _muster() -> void:
	for n in layer.get_children():
		n.queue_free()
	var w: float = stage.size.x / zoom
	var h: float = holder.custom_minimum_size.y / zoom
	for k in races.size():
		var units := _pick(races[k].units)
		var n := units.size()
		for i in n:
			var u: Dictionary = units[i]
			var view := UnitView.new()
			view.build(u.recipe, lib, teams[k], u.eval.speed)
			view.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			view.pose_steps = 8
			view.art_px = ArtKit.ART_SCALE / zoom
			# In order from the far edge to the middle: the big ones nearest the foe.
			var along := (i + 0.5) / float(n)   # 0 far edge .. 1 the middle
			var x := w * (0.07 + 0.36 * along)
			view.position = Vector2(x if k == 0 else w - x, h * (0.6 + 0.12 * (i % 2)))
			view.face(1.0 if k == 0 else -1.0)
			view.modulate.a = 0.0
			layer.add_child(view)
			view.create_tween().tween_property(view, "modulate:a", 1.0, 0.35).set_delay(0.06 * i)
	veil.hide_veil()


## The atlas was rebuilt: the parts on the stage redraw from the new one.
func _redraw() -> void:
	for ps in layer.find_children("*", "Node2D", true, false):
		if ps is PartShape:
			ps.queue_redraw()


func _next_tip() -> void:
	if tips.is_empty():
		return
	tip.text = "Tip: " + String(tips[randi() % tips.size()])   # view-side: any tip will do
	_tip_at = _t


func _process(delta: float) -> void:
	_t += delta
	if kit == null:
		return
	if _t - _tip_at > TIP_EVERY:
		_next_tip()
	var p: Vector2 = kit.progress()
	var real := 1.0 if _finishing or p.y <= 0.0 else p.x / p.y
	shown = minf(real, shown + delta * 1.5) if real > shown else real   # glides up to the truth, never past it
	busy.text = "Ready" if _finishing else kit.busy_with() + "..."
	pct.text = "%d%%" % roundi(shown * 100.0)
	bar.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_style_box(Style.box(Style.TROUGH, Style.EDGE, 2, 9), r)
	var inner := r.grow(-4)
	var fill := Rect2(inner.position, Vector2(inner.size.x * shown, inner.size.y))
	if fill.size.x > 1.0:
		bar.draw_rect(fill, Style.GOLD.darkened(0.25))
		bar.draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Style.GOLD.lightened(0.1))
		var sx := fmod(_t * 220.0, inner.size.x + 120.0) - 60.0   # a glint running along the fill
		if sx < fill.size.x:
			bar.draw_rect(Rect2(inner.position + Vector2(maxf(sx - 30.0, 0.0), 0), Vector2(minf(60.0, fill.size.x - maxf(sx - 30.0, 0.0)), inner.size.y)), Color(1, 1, 1, 0.18))


## Fade into the match, then go.
func finish() -> void:
	_finishing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(self, "modulate:a", 0.0, Style.FADE)
	tw.tween_callback(func(): (get_parent() if get_parent() is CanvasLayer else self).queue_free())
