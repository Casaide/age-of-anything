extends SceneTree
## The placement check: one command that must pass before any unit, mount, gear or pose change is
## shown (docs/rendering.md, "Placement rules"). Numbers, not pictures:
##   1. 3D (tests/placement/geometry_check.gd): every unit put together from its models in every pose
##      the game draws (standing in each hold, swings, the walk at eight phases), measured on its
##      meshes: ground contact, attachment, interpenetration, stance.
##   2. 2D (tests/placement/projection_check.gd): every unit composed from its bakes in all 8 facings,
##      standing and walking: the layering rules, feet on their ground points, legs and head where
##      the 3D truth shows them, riders' legs on the near flank.
##   3. The regression fixtures (tests/placement/fixtures_3d.gd, fixtures_2d.gd): every placement bug
##      Dominic caught, put back, must fail its rule; as the unit is now, it must pass.
## PASS/FAIL lines, a summary, exit 1 on any failure or a fixture that no longer fails. Needs a window:
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_check.gd -- [filter] [3d|2d] [metrics] [debug] [nofixtures]
## filter: only cases whose label contains it (fixtures still run unless nofixtures). metrics: the
## measurement behind each 2D failure (3D failures always carry it). debug: the 3D truth beside the
## composed unit for each standing view (/tmp/placement_*.png).

const DataLib := preload("res://src/data_lib.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const ProjectionCheck := preload("res://tests/placement/projection_check.gd")
const Fixtures3D := preload("res://tests/placement/fixtures_3d.gd")
const Fixtures2D := preload("res://tests/placement/fixtures_2d.gd")
const GeometryRun := preload("res://tests/geometry_check.gd")
const ScriptErrors := preload("res://tests/placement/script_errors.gd")


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if not a in ["3d", "2d", "metrics", "debug", "nofixtures"]:
			filter = a
	var do3 := not "2d" in args
	var do2 := not "3d" in args
	var lib = DataLib.new()
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var failed := 0
	var checks := 0
	var fixtures_ok := true
	var t0 := Time.get_ticks_msec()
	var errors = ScriptErrors.new()   # a script error inside a check is a failure, never a pass
	OS.add_logger(errors)
	if do3:
		var g = GeometryCheck.new(lib)
		g.metrics = true
		var n: int = GeometryRun.run(g, cases)
		var f3: int = GeometryRun.report(g.results, g.order)
		failed += f3
		checks += g.order.size()
		print("3D: %d checks, %d failed (%d units, %d distinct, %.1f s)" % [g.order.size(), f3, cases.size(), n, (Time.get_ticks_msec() - t0) / 1000.0])
		if not "nofixtures" in args:
			var fx: Array = Fixtures3D.run(lib)
			fixtures_ok = fixtures_ok and fx[0]
			for line in fx[1]:
				print(line)
	if do2:
		var t1 := Time.get_ticks_msec()
		var pc = ProjectionCheck.new()
		pc.setup(lib)
		pc.metrics = "metrics" in args
		pc.debug = "debug" in args
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
		var t_bake := Time.get_ticks_msec()
		var holder := Node2D.new()
		holder.visible = false
		root.add_child(holder)
		for c in todo:
			await pc.check_case(holder, c[0], c[1])
		var f2 := 0
		for key in pc.order:
			var fails: Array = pc.results[key]
			if not fails.is_empty():
				f2 += 1
				var parts: PackedStringArray = key.split("|")
				print("FAIL %s: %s in %d of its views: %s" % [parts[0], parts[1], fails.size(), ", ".join(fails.slice(0, 6)) + (" ..." if fails.size() > 6 else "")])
		failed += f2
		checks += pc.order.size()
		print("2D: %d checks, %d failed (%d units, %d views; bakes %.1f s, checks %.1f s)" % [pc.order.size(), f2, todo.size(), todo.size() * 8 * ProjectionCheck.POSES.size(),
			(t_bake - t1) / 1000.0, (Time.get_ticks_msec() - t_bake) / 1000.0])
		if not "nofixtures" in args:
			var fx: Array = await Fixtures2D.run(pc, holder, lib, kit)
			fixtures_ok = fixtures_ok and fx[0]
			for line in fx[1]:
				print(line)
	OS.remove_logger(errors)
	if errors.count > 0:
		print("FAIL the checks hit %d script errors, the first: %s" % [errors.count, errors.first])
		failed += 1
	print("placement: %d checks, %d failed, fixtures %s (%.1f s)" % [checks, failed, "all caught" if fixtures_ok else "BROKEN", (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 or not fixtures_ok else 0)
