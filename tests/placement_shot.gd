extends SceneTree
## Units from the placement check's cases (tests/placement/cases.gd) by label, in all 8 facings,
## one row per label, standing (or "walk:<phase>"), at a zoom: to look at a case the check flags.
## Needs a display:
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_shot.gd -- out.png zoom "label" ["label" ...] [walk:2.1]

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const UnitView := preload("res://src/unit_view.gd")
const Cases := preload("res://tests/placement/cases.gd")

const W := 1800


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var zoom := float(args[1])
	var walk := -1.0
	var labels := []
	for a in args.slice(2):
		if a.begins_with("walk:"):
			walk = float(a.trim_prefix("walk:"))
		else:
			labels.append(a)
	var lib = DataLib.new()
	var all := {}
	for c in Cases.all(lib):
		all[c[0]] = c[1]
	var units := labels.map(func(l): assert(all.has(l), "no case " + l); return all[l])
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var team := Color(lib.palettes.teams[0])
	await kit.prepare_units([{"units": units}], [team])
	var row_h := 70.0 * zoom
	var h := int(row_h * units.size() + 20)
	root.size = Vector2i(W, h)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(W, h)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	for row in units.size():
		var lab := Label.new()
		lab.text = labels[row]
		lab.position = Vector2(4, row * row_h + 2)
		root.add_child(lab)
		for k in 8:
			var v := UnitView.new()
			v.facing_k = k
			v.build(units[row].recipe, lib, team, units[row].eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.idle_wait = 1000.0
			v.position = Vector2((k + 0.55) * W / 8.0, (row + 0.78) * row_h) / zoom
			world.add_child(v)
			if walk >= 0.0:
				v.walking = true
				v.phase = walk
				v._process(0.0)
				v.walking = false
				v.set_process(false)
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	print("saved ", args[0])
	quit()
