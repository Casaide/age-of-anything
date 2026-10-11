extends SceneTree
## Every mouse cursor at 1x and 3x on the game's grass colour, with its hotspot marked.
## Run (needs a display): godot --path . --script res://tests/art_cursors.gd -- out.png

const Cursors := preload("res://src/view/art/cursors.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://cursors.png"
	var c := Cursors.new(1.0)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var x := 40.0
	for name in Cursors.HOTSPOT:
		var tex := ImageTexture.create_from_image(c.images[name])
		for z in [1.0, 3.0]:
			var r := TextureRect.new()
			r.texture = tex
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.size = Vector2(32, 32) * z
			r.position = Vector2(x, 60.0 if z == 1.0 else 140.0)
			root.add_child(r)
			var dot := ColorRect.new()
			dot.color = Color.MAGENTA
			dot.size = Vector2(3, 3)
			dot.position = r.position + Cursors.HOTSPOT[name] * z - Vector2(1, 1)
			root.add_child(dot)
		var l := Label.new()
		l.text = name
		l.position = Vector2(x, 250)
		root.add_child(l)
		x += 120.0
	for f in 5:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
