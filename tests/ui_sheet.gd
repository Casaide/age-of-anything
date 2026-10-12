extends SceneTree
## A sheet of the UI's looks: for a direction (data/ui.json) the neutral look and each culture's,
## each as a framed panel with its crest, its banner, buttons in every state, Start, a field,
## a well and the type. For checking materials and culture looks close up.
## Run (needs a display): godot --path . --script res://tests/ui_sheet.gd -- out.png [direction] [culture,culture,...] [scale]

const UiTheme := preload("res://src/view/ui/theme.gd")

const CULTURES := ["", "imperial", "hellenic", "swamp", "sewer", "steppe", "forest"]
const TEAMS := [Color("#3a6ad8"), Color("#d84a3a")]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] != "":
		UiTheme.direction = args[1]
	var cultures: Array = Array(args[2].split(",")) if args.size() > 2 else CULTURES
	var k := float(args[3]) if args.size() > 3 else 1.0
	root.size = Vector2i(Vector2(380 * cultures.size() + 40, 860) * k)
	root.content_scale_factor = k
	var bg := ColorRect.new()
	bg.color = Color("#14100c")
	bg.size = Vector2(4000, 2000)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 40)
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for i in cultures.size():
		row.add_child(_column(cultures[i], TEAMS[i % 2]))
	for f in 12:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "/tmp/ui_sheet.png")
	print("saved ", args[0] if args.size() > 0 else "/tmp/ui_sheet.png")
	quit()


func _column(family: String, team: Color) -> Control:
	var lk := UiTheme.look(family)
	var panel := PanelContainer.new()
	panel.theme = UiTheme.theme(lk, 18)
	panel.theme_type_variation = "CrestFrame"
	panel.custom_minimum_size = Vector2(360, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	col.add_child(gap)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiTheme.banner_box(lk, team))
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 0)
	bcol.add_child(UiTheme.label(family.capitalize() if family != "" else "Neutral", "Title"))
	bcol.add_child(UiTheme.label("%s / %s / %s" % [lk.frame, lk.panel, lk.ornament], "Dim"))
	banner.add_child(bcol)
	col.add_child(banner)
	col.add_child(UiTheme.label("ROSTER", "Caption"))
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var cl := VBoxContainer.new()
	cl.add_child(UiTheme.label("Spearbearer Rat", "Name"))
	cl.add_child(UiTheme.label("15 food  20 wood  from age 2", "Dim"))
	card.add_child(cl)
	col.add_child(card)
	var states := HBoxContainer.new()
	for s in ["Normal", "Hover", "Pressed", "Off"]:
		var b := UiTheme.button(s)
		match s:
			"Hover":
				b.add_theme_stylebox_override("normal", UiTheme.button_box(lk, "hover"))
				b.add_theme_color_override("font_color", lk.text.lightened(0.3))
			"Pressed":
				b.add_theme_stylebox_override("normal", UiTheme.button_box(lk, "pressed"))
				b.add_theme_color_override("font_color", lk.accent)
			"Off":
				b.disabled = true
		states.add_child(b)
	col.add_child(states)
	var field := LineEdit.new()
	field.text = "sewer rats with cheese"
	col.add_child(field)
	var well := PanelContainer.new()
	well.theme_type_variation = "Well"
	well.custom_minimum_size.y = 70
	well.add_child(UiTheme.label("a well (the stage, the map)", "Dim"))
	col.add_child(well)
	var bar := ProgressBar.new()
	bar.value = 60
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	col.add_child(bar)
	var start := UiTheme.button("Start battle", true)
	start.custom_minimum_size.y = 76
	col.add_child(start)
	col.add_child(UiTheme.Rule.new(lk.metal))
	var tip := PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UiTheme.tip_box(lk))
	tip.add_child(UiTheme.label("A tooltip card: what it costs, what it does.", "", true))
	col.add_child(tip)
	return panel
