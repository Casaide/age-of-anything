extends Control
## Race Lab: type a prompt per side, generate a race, see its army mill about.
## Proves the data contract, generator, pricing and composer before any
## gameplay exists. The UI is built in code to keep the scene file trivial.
## Units are drawn in the game's baked pixel art, on the game's ground with its
## doodads: each generated race is baked by the art kit (cached), so what you see
## here is what the match shows.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const TerrainView := preload("res://src/view/art/terrain_view.gd")
const Iso := preload("res://src/view/iso.gd")

const RULE_IDS := ["default", "bronze", "anything"]
const DEFAULT_PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers"]
const WORLD_ZOOM := ArtKit.BASE_SCALE * 2.0   # the size it always had (D-173: the art is finer, not bigger)
const GROUND_TILES := 30   # the ground is a square tile map big enough to fill the field
const LINEUP_Y := 78.0
const COPIES := {"worker": 2, "spear": 2, "skirmisher": 2, "archer": 2, "large": 1}
const BG := Color("#2b2620")
const PANEL := Color("#3a332b")
const TEXT_DIM := "#b8ad94"
const TEXT_FAINT := "#8a8070"
const NOTE := "#f2c94c"
const HELP := "Enter or Generate: new race · Reroll: same prompt, new roll · Save: writes the race JSON"

var lib
var gen
var rules_list: Array = []
var rules_pick: OptionButton
var status: Label
var field: Control
var world: Node2D
var layer: Node2D          # units and doodads, y-sorted
var kit: ArtKit
var kit_busy := false
var ground: TerrainView
var ground_at := Vector2.ZERO   # where the ground's map sits in world units
var doodads: Array = []
var labels: Control
var sides: Array = []


func _ready() -> void:
	lib = DataLib.new()
	gen = Generator.new(lib)
	for id in RULE_IDS:
		rules_list.append(DataLib.load_rules(id))
	_build_ui()
	kit = ArtKit.new()
	kit.lib = lib
	add_child(kit)
	field.resized.connect(_respawn_all)
	_generate.call_deferred(0, false)
	_generate.call_deferred(1, false)


func _rules() -> Dictionary:
	return rules_list[rules_pick.selected]


# ------------------------------------------------------------------ actions

func _generate(i: int, reroll: bool) -> void:
	var side: Dictionary = sides[i]
	side.reroll = side.reroll + 1 if reroll else 0
	var prompt: String = side.prompt.text.strip_edges()
	if prompt == "":
		prompt = "?"
	var race: Dictionary = gen.generate(prompt, _rules(), side.reroll)
	side.race = race
	side.card.text = _card_text(race)
	await _bake(i, race)


## Bake a race's units (the kit skips anything already baked), one bake at a time.
func _bake(i: int, race: Dictionary) -> void:
	while kit_busy:
		await get_tree().process_frame
	if sides[i].race != race:   # replaced while it waited
		return
	kit_busy = true
	status.text = "Baking %s..." % race.name
	var t0 := Time.get_ticks_msec()
	if ground == null:
		await kit.bake_props()
	await kit.prepare_units([race], [Color(lib.palettes.teams[i])])
	if ground == null:
		_build_ground()
	sides[i].baked = race.key
	status.text = "Baked %s in %d ms.   %s" % [race.name, Time.get_ticks_msec() - t0, HELP]
	kit_busy = false
	# The atlas was rebuilt and the old one freed: everything drawn from it is redrawn.
	_respawn_all()


func _regenerate_all(_index := 0) -> void:
	for i in sides.size():
		sides[i].reroll -= 1
		_generate(i, true)


func _save(i: int) -> void:
	var race: Dictionary = sides[i].race
	DirAccess.make_dir_recursive_absolute("user://races")
	var path := "user://races/%s.json" % race.key.substr(0, 12)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(race, "  ", true))
	status.text = "Saved %s" % ProjectSettings.globalize_path(path)


# ------------------------------------------------------------------ armies

func _respawn_all() -> void:
	if ground:
		_place_ground()
	for i in sides.size():
		if not sides[i].race.is_empty():
			_respawn(i)


func _respawn(i: int) -> void:
	var side: Dictionary = sides[i]
	for n in side.nodes:
		n.queue_free()
	side.nodes.clear()
	if side.race.is_empty() or side.baked != side.race.key or field.size.x < 10.0:
		return

	var team := Color(lib.palettes.teams[i])
	var half := field.size.x / WORLD_ZOOM / 2.0
	var height := field.size.y / WORLD_ZOOM
	var x0 := half * i
	var units: Array = side.race.units
	var face := 1.0 if i == 0 else -1.0

	for k in units.size():
		var u: Dictionary = units[k]
		var pos := Vector2(x0 + (k + 0.5) * half / units.size(), LINEUP_Y)
		var view := _spawn(u, team, pos, face)
		side.nodes.append(view)
		var label := Label.new()
		label.text = u.recipe.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 4)
		var slot_px := half * WORLD_ZOOM / units.size() - 6.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(slot_px, 0)
		label.position = pos * WORLD_ZOOM + Vector2(-slot_px / 2.0, 10)
		labels.add_child(label)
		side.nodes.append(label)

	var area := Rect2(x0 + 18.0, LINEUP_Y + 40.0, half - 36.0, height - LINEUP_Y - 52.0)
	for u in units:
		for c in COPIES.get(u.recipe.role, 1):
			var view := _spawn(u, team, Vector2.ZERO, face)
			view.position = Vector2(view.noise.randf_range(area.position.x, area.end.x), view.noise.randf_range(area.position.y, area.end.y))
			view.wander_in(area)
			side.nodes.append(view)


func _spawn(u: Dictionary, team: Color, pos: Vector2, face: float) -> Node2D:
	var view := UnitView.new()
	view.build(u.recipe, lib, team, u.eval.speed)
	view.scale = Vector2.ONE * ArtKit.UNIT_SCALE   # as in the match
	view.pose_steps = 8
	view.art_px = ArtKit.ART_SCALE / WORLD_ZOOM   # art pixels per screen pixel
	view.position = pos
	view.face(face)
	layer.add_child(view)
	return view


# ------------------------------------------------------------------ ground

## The match's ground (grass from the terrain shader) with seeded doodads.
func _build_ground() -> void:
	var n := GROUND_TILES
	var map := {"id": "race_lab", "width": n, "height": n, "terrain_ids": ["grass"],
		"terrain": PackedByteArray(), "walk": PackedByteArray()}
	map.terrain.resize(n * n)
	map.walk.resize(n * n)
	map.walk.fill(1)
	ground = TerrainView.new()
	ground.build(map)
	ground.set_art_px(WORLD_ZOOM / ArtKit.ART_SCALE)
	world.add_child(ground)
	world.move_child(ground, 0)
	_place_ground()


## Centre the ground's diamond on the field and re-scatter its doodads around the lineup.
func _place_ground() -> void:
	var view := field.size / WORLD_ZOOM
	ground_at = view * 0.5 - Iso.to_screen(GROUND_TILES * 500, GROUND_TILES * 500)
	ground.position = ground_at
	for d in doodads:
		d.queue_free()
	doodads = ground.scatter(kit, layer, func(t: Vector2) -> bool:
		var p := Iso.to_screen(t.x * 1000, t.y * 1000) + ground_at
		return p.x < 4 or p.y < LINEUP_Y + 24 or p.x > view.x - 4 or p.y > view.y - 4)
	for d in doodads:
		d.position += ground_at


# ------------------------------------------------------------------ race card

func _card_text(race: Dictionary) -> String:
	var c: Dictionary = lib.creatures[race.creature]
	var t := "[font_size=24][b]%s[/b][/font_size]\n" % _esc(race.name)
	t += "[i]\"%s\"[/i]\n" % _esc(race.prompt)
	t += "[color=%s]%s · %s · %s · reroll %d[/color]\n" % [TEXT_DIM, c.plural, race.family, _rules().name, race.reroll]
	t += "[color=%s]key %s…[/color]\n\n" % [TEXT_FAINT, race.key.substr(0, 16)]
	if race.notes.size() > 0:
		t += "[color=%s]" % NOTE
		for n in race.notes:
			t += "• %s\n" % _esc(n)
		t += "[/color]\n"
	for u in race.units:
		var r: Dictionary = u.recipe
		var e: Dictionary = u.eval
		t += "[b]%s[/b]  [color=%s](%s, tier %d)[/color]\n" % [_esc(r.name), TEXT_DIM, r.role, r.tier]
		t += "   %d food  %d wood · %ds · pop %d · %d pts\n" % [e.cost.food, e.cost.wood, e.train_time, e.pop, e.points]
		t += "   HP %d  ATK %d %s  ARM %d/%d  RNG %d  SPD %d\n" % [e.hp, e.attack, e.damage, e.armour.melee, e.armour.pierce, e["range"], e.speed]
		if not e.bonus.is_empty():
			var keys: Array = e.bonus.keys()
			keys.sort()
			t += "   %s\n" % ", ".join(keys.map(func(k): return "+%d vs %s" % [e.bonus[k], k]))
		t += "   [color=%s]%s[/color]\n\n" % [TEXT_FAINT, ", ".join(e.tags)]
	return t


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


# ------------------------------------------------------------------ layout

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side_name in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side_name, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	status = Label.new()
	status.add_theme_color_override("font_color", Color(TEXT_FAINT))
	status.text = HELP
	root.add_child(status)

	for i in 2:
		sides.append({"prompt": null, "card": null, "race": {}, "reroll": 0, "nodes": [], "baked": ""})

	_prompt_row(top, 0)
	var vs := Label.new()
	vs.text = "  vs  "
	top.add_child(vs)
	rules_pick = OptionButton.new()
	for r in rules_list:
		rules_pick.add_item(r.name)
	rules_pick.item_selected.connect(_regenerate_all)
	top.add_child(rules_pick)
	var vs2 := Label.new()
	vs2.text = "  vs  "
	top.add_child(vs2)
	_prompt_row(top, 1)

	body.add_child(_card(0))
	field = Control.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.clip_contents = true
	body.add_child(field)
	var grass := ColorRect.new()   # under the ground while it bakes
	grass.color = Color("#56782e")
	grass.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.add_child(grass)
	world = Node2D.new()
	world.scale = Vector2(WORLD_ZOOM, WORLD_ZOOM)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field.add_child(world)
	layer = Node2D.new()
	layer.y_sort_enabled = true
	world.add_child(layer)
	var divider := ColorRect.new()
	divider.color = Color(0.1, 0.08, 0.05, 0.35)
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_bottom = 1.0
	divider.offset_left = -1
	divider.offset_right = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(divider)
	labels = Control.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(labels)
	body.add_child(_card(1))


func _prompt_row(parent: Container, i: int) -> void:
	var edit := LineEdit.new()
	edit.text = DEFAULT_PROMPTS[i]
	edit.placeholder_text = "describe a race…"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(_t): _generate(i, false))
	parent.add_child(edit)
	sides[i].prompt = edit
	for b in [["Generate", func(): _generate(i, false)], ["Reroll", func(): _generate(i, true)], ["Save", func(): _save(i)]]:
		var button := Button.new()
		button.text = b[0]
		button.pressed.connect(b[1])
		parent.add_child(button)


func _card(i: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_content_margin_all(12)
	style.set_corner_radius_all(4)
	style.border_color = Color(lib.palettes.teams[i])
	style.border_width_top = 4
	panel.add_theme_stylebox_override("panel", style)
	var card := RichTextLabel.new()
	card.bbcode_enabled = true
	card.scroll_active = true
	card.add_theme_font_size_override("normal_font_size", 13)
	card.add_theme_font_size_override("bold_font_size", 14)
	panel.add_child(card)
	sides[i].card = card
	return panel
