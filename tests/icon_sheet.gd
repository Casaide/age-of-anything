extends SceneTree
## The unit portraits as the command panel shows them: each race's roster as train buttons (the
## panel's size and picture inset), on the panel's dark ground, for checking how the icons are
## framed (Dominic: "why size difference?" between a frog spearman and its newt cavalry).
## Run (needs a display):
##   godot --path . --audio-driver Dummy --script res://tests/icon_sheet.gd -- out.png ["prompt A" "prompt B" ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const CommandPanel := preload("res://src/view/command_panel.gd")

const GAP := 10
const PER_ROW := 10


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://icons.png"
	var prompts: Array = args.slice(1) if args.size() > 1 else ["angry swamp frogs with reed spears"]
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var races := []
	var teams := []
	for k in prompts.size():
		races.append(gen.generate(prompts[k], rules))
		teams.append(Color(lib.palettes.teams[k]))
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, teams)
	await kit.bake_icons(races, teams)
	var bg := ColorRect.new()
	bg.color = Color("#2a2219")
	bg.size = root.size
	root.add_child(bg)
	var b := CommandPanel.BUTTON
	var row := 0
	for side in races.size():
		var units: Array = races[side].units
		for k in units.size():
			var slot: String = units[k].recipe.slot
			var x := GAP + k % PER_ROW * (b + GAP)
			var y := GAP + (row + k / PER_ROW) * (b + GAP + 18)
			var frame := ColorRect.new()
			frame.color = Color("#4a3c2c")
			frame.position = Vector2(x, y)
			frame.size = Vector2(b, b)
			root.add_child(frame)
			var pic := TextureRect.new()   # the panel's picture inset (command_panel.gd _button)
			pic.texture = kit.icons.get("%d:%s" % [side, slot])
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.position = Vector2(x + 6, y + 5)
			pic.size = Vector2(b - 12, b - 22)
			root.add_child(pic)
			var label := Label.new()
			label.text = slot
			label.add_theme_font_size_override("font_size", 11)
			label.position = Vector2(x, y + b)
			root.add_child(label)
		row += (units.size() + PER_ROW - 1) / PER_ROW
	for f in 10:
		await process_frame
	var img := root.get_texture().get_image()
	img = img.get_region(Rect2i(0, 0, mini(img.get_width(), GAP + PER_ROW * (b + GAP)), mini(img.get_height(), GAP + row * (b + GAP + 18))))
	img.save_png(out)
	print("saved ", out)
	quit()
