extends SceneTree
## The 2D placement check's results as Godot has them (tests/placement/projection_check.gd), for
## placement_check.lobster's 2D parity: {results: {rule|label: [failing views]}}. Needs a window.
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/lobster_spike/placement_dump2d.gd -- <out.json> [filter]

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Cases := preload("res://tests/placement/cases.gd")
const ProjectionCheck := preload("res://tests/placement/projection_check.gd")


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var filter: String = args[1] if args.size() > 1 else ""
	var lib = DataLib.new()
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var pc = ProjectionCheck.new()
	pc.setup(lib)
	pc.metrics = true
	root.add_child(pc)
	var kit := ArtKit.new()
	kit.lib = lib
	pc.add_child(kit)
	await process_frame
	var seen := {}
	var todo := []
	for c in cases:
		var sig := JSON.stringify(c[1].recipe, "", true)
		if not seen.has(sig):
			seen[sig] = true
			todo.append(c)
	await pc.bake(kit, todo.map(func(c): return c[1]))
	var holder := Node2D.new()
	holder.visible = false
	root.add_child(holder)
	for c in todo:
		await pc.check_case(holder, c[0], c[1])
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify({"results": pc.results, "order": pc.order}))
	f.close()
	print("%d units, %d results" % [todo.size(), pc.order.size()])
	quit()
