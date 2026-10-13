extends SceneTree
## Siege shots before and after (Dominic: "the rocks they throw look really bad"): for each look in
## data/siege_shots.json, the shot as drawn before (a flat circle or line, src/view/combat_fx.gd SHOTS) and as
## drawn now (the baked sprite tumbling along its arc, its shadow under it), then its impact at three
## moments (chunks, the bounce or the burst, the splash's dust). Frozen frames of the real CombatFx node.
## Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/shot_sheet.gd -- out.png [zoom]

const DataLib := preload("res://src/data_lib.gd")
const UnitView := preload("res://src/unit_view.gd")
const PartShape := preload("res://src/part_shape.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const CombatFx := preload("res://src/view/combat_fx.gd")

const ART := 1.5 * 0.85   # as the game bakes units (ArtKit.ART_SCALE * UNIT_SCALE)
const ROWS := [["boulder", "boulder", "catapult: timber"], ["cheese", "boulder", "catapult: rats' junk"], ["acorn", "boulder", "catapult: forest"],
	["bone", "boulder", "catapult: spooky"], ["clay", "boulder", "catapult: frogs (snail)"], ["boulder_big", "sling_stone", "great sling: timber"],
	["cheese_big", "sling_stone", "great sling: junk"], ["bolt", "siege_bolt", "bolt thrower"]]
const ROW_H := 72.0
const W := 560.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shots.png"
	var zoom := int(args[1]) if args.size() > 1 else 3
	var lib = DataLib.new()
	var baker := PartBaker.new()
	baker.art_scale = ART
	baker.bands = 4
	root.add_child(baker)
	var size := Vector2(W, 24 + ROW_H * ROWS.size())
	var vp := SubViewport.new()   # (off screen: a sheet taller than the display isn't cut)
	vp.size = Vector2i(size * zoom)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * zoom)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = size
	vp.add_child(bg)
	await process_frame
	var colours := UnitView.colours_for(lib, "human_1" if lib.palettes.skins.has("human_1") else lib.palettes.skins.keys()[0], "imperial", Color.RED)
	for r in ROWS:
		var id: String = CombatFx.look(r[0]).part
		await baker.bake(id, lib.part(id).shapes, colours)
	_label(vp, "before (flat shapes)", Vector2(70, 4))
	_label(vp, "now (baked, tumbling, shadow)", Vector2(205, 4))
	_label(vp, "impact: 0.15 s, 0.45 s, 1.1 s", Vector2(380, 4))
	for i in ROWS.size():
		var r: Array = ROWS[i]
		var y := 24.0 + i * ROW_H
		_label(vp, r[2], Vector2(4, y + 40))
		var before := _fx(lib, vp)
		var after := _fx(lib, vp)
		for t in [0.15, 0.5, 0.85]:
			before.shots.append({"from": Vector2(80, y + 64), "to": Vector2(180, y + 64), "t": t, "dur": 1.0, "kind": r[1], "look": "", "phase": 0.0})
			after.shots.append({"from": Vector2(215, y + 64), "to": Vector2(315, y + 64), "t": t, "dur": 1.0, "kind": r[1], "look": r[0], "phase": t * 13.0})
		for m in 3:
			var at := Vector2(380 + m * 62, y + 50)
			var fx := _fx(lib, vp)
			var shot := {"from": at - Vector2(60, 0), "to": at, "t": 1.0, "dur": 1.0, "kind": r[1], "look": r[0], "phase": 2.0}
			seed(7 + i)
			if CombatFx.look(r[0]).impact != "stick":
				fx._impact(shot)
				fx.splash(at, 9.0 if r[1] == "boulder" else 6.0)
			else:
				fx.stick(at, r[1])
			var steps: int = [3, 9, 22][m]
			for k in steps:
				fx._process(0.05)
	for f in 8:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _fx(lib, vp: Node) -> Node2D:
	var fx = CombatFx.new()
	fx.lib = lib
	vp.add_child(fx)
	fx.set_process(false)   # (frozen: after entering the tree, which turns processing on)
	fx.queue_redraw()
	return fx


func _label(vp: Node, text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 8)
	vp.add_child(l)
