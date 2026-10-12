extends SceneTree
## The UI directions side by side (data/ui.json): for one direction, the lobby with two races
## mustered, then a mock of the match HUD (top bar, command panel, a tooltip card) in your race's
## culture over a picture of the battlefield.
## Run (needs a display):
##   godot --path . --script res://tests/ui_directions.gd -- out_prefix [direction] ["prompt A" "prompt B"]
## Writes <out_prefix>_lobby.png and <out_prefix>_hud.png.

const UiTheme := preload("res://src/view/ui/theme.gd")
const UiScale := preload("res://src/view/ui_scale.gd")
const TopBar := preload("res://src/view/top_bar.gd")
const CommandPanel := preload("res://src/view/command_panel.gd")
const Icons := preload("res://src/view/art/icons.gd")
const BACKDROP := "res://archive/images/2026-10-12/105-reed-meadow-large-start-close.png"   # its middle: the map without a HUD


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0]
	if args.size() > 1:
		UiTheme.direction = args[1]
	var lobby = load("res://scenes/match_setup.tscn").instantiate()
	root.add_child(lobby)
	for f in 5:
		await process_frame
	lobby.sides[0].field.text = args[2] if args.size() > 3 else "centaur romans"
	lobby.sides[1].field.text = args[3] if args.size() > 3 else "sewer rats with cheese hammers"
	lobby._open_setup()
	lobby._regenerate(0)
	lobby._regenerate(1)
	while lobby.sides[0].layer.get_child_count() == 0 or lobby.sides[1].layer.get_child_count() == 0 or lobby.baking:
		await process_frame
	for f in 30:
		await process_frame
	root.get_texture().get_image().save_png(prefix + "_lobby.png")
	print("saved ", prefix, "_lobby.png")
	var icons: Dictionary = lobby.kit.icons.duplicate()
	var race: Dictionary = lobby.sides[0].race
	var team: Color = lobby.sides[0].team
	lobby.queue_free()
	await process_frame
	await _hud(prefix + "_hud.png", race, team, icons)
	quit()


## The match HUD in your race's culture, at the default UI size, over the battlefield.
func _hud(out: String, race: Dictionary, team: Color, icons: Dictionary) -> void:
	root.content_scale_factor = 1.0
	var img := Image.load_from_file(ProjectSettings.globalize_path(BACKDROP)).get_region(Rect2i(300, 250, 1500, 844))
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(img)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(root.size)
	root.add_child(bg)
	var f := UiScale.screen() * UiScale.SIZE_DEFAULT / 100.0
	var lk := UiTheme.look(race.family)
	var hud := Control.new()
	hud.scale = Vector2(f, f)
	hud.size = Vector2(root.size) / f
	hud.theme = UiTheme.theme(lk, 16)
	root.add_child(hud)
	var bar := TopBar.new()
	bar.position = Vector2(10, 8)
	hud.add_child(bar)
	bar.setup(["food", "wood", "stone", "gold"])
	bar.show_state({"food": 245, "wood": 180, "stone": 40, "gold": 0}, 14, 20, race.name, 431)
	bar.show_age(2, "Stick Age", "", 0.0)
	bar.show_idle(2)
	var panel := CommandPanel.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -12
	hud.add_child(panel)
	for r in ["food", "wood", "stone", "gold"]:
		panel.res_icons[r.substr(0, 1).to_upper()] = Icons.texture("res_" + r)
	await process_frame
	var buttons := []
	for slot in ["worker", "spear"]:
		buttons.append({"icon": icons.get("0:" + slot), "text": slot, "key": "Q" if slot == "worker" else "W", "cost": "50F 25W", "enabled": true, "action": func(): pass, "group": "Train"})
	buttons.append({"icon": Icons.texture("age_up"), "text": "Age up", "key": "U", "cost": "500F 200G", "enabled": true, "action": func(): pass, "group": "Age up", "accent": true})
	for r in ["thick_skins", "big_pockets", "lookouts"]:
		buttons.append({"icon": Icons.texture(r), "text": r, "key": "", "cost": "75F", "enabled": r != "lookouts", "action": func(): pass, "group": "Research"})
	panel.show_content({"title": "Town Center", "info": "Training %s\nRight-click: rally point" % race.units[0].recipe.name, "team": team,
		"portrait": icons.get("0:worker"), "hp": [1450, 1600], "tray": [], "buttons": buttons,
		"queue": [{"icon": icons.get("0:worker"), "name": "Worker", "action": func(): pass}, {"icon": icons.get("0:worker"), "name": "Worker", "action": func(): pass}],
		"queue_max": 15, "progress": 0.6, "queue_title": "Training"})
	var card := UiTheme.tip_card("[b]Thick Skins[/b]\n[color=#e8a080]75 Food[/color]\nTougher hides for the people who do the work.\n[color=#a8d880]Workers +15 HP, +1 melee armour[/color]", lk, f)
	root.add_child(card)
	for k in 6:
		await process_frame
	var b: Control = panel.action_buttons()[3]
	card.position = Vector2(b.global_position.x, panel.global_position.y - card.size.y - 12 * f)
	for k in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
