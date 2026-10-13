extends SceneTree
## The 2D half of the placement check alone (tests/placement/projection_check.gd): the layering rules
## and the feet, truth and rider-leg checks on every unit's bakes in all 8 facings. Kept for its old
## command; tests/placement_check.gd runs it with the 3D checks and the fixtures, and is the one to run
## before showing a unit change. Needs a window:
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/layer_check.gd -- [filter] [metrics] [debug]

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Cases := preload("res://tests/placement/cases.gd")
const ProjectionCheck := preload("res://tests/placement/projection_check.gd")


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if not a in ["metrics", "debug"]:
			filter = a
	var lib = DataLib.new()
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var pc = ProjectionCheck.new()
	pc.setup(lib)
	pc.metrics = "metrics" in args
	pc.debug = "debug" in args
	root.add_child(pc)
	var kit := ArtKit.new()
	kit.lib = lib
	pc.add_child(kit)
	await process_frame
	await pc.bake(kit, cases.map(func(c): return c[1]))
	var holder := Node2D.new()
	holder.visible = false
	root.add_child(holder)
	for c in cases:
		await pc.check_case(holder, c[0], c[1])
	var failed := 0
	for key in pc.order:
		var fails: Array = pc.results[key]
		var parts: PackedStringArray = key.split("|")
		if fails.is_empty():
			print("PASS %s: %s" % [parts[0], parts[1]])
		else:
			failed += 1
			print("FAIL %s: %s in %d of its views: %s" % [parts[0], parts[1], fails.size(), ", ".join(fails.slice(0, 6)) + (" ..." if fails.size() > 6 else "")])
	print("%d checks, %d failed (%d units)" % [pc.order.size(), failed, cases.size()])
	quit(1 if failed > 0 else 0)
