extends SceneTree
## The 3D placement check alone, headless (tests/placement/geometry_check.gd): every unit, mount,
## rider, animal and siege crew in every pose, measured on its meshes, then the regression fixtures
## (tests/placement/fixtures_3d.gd). FAIL lines per rule and unit, exit 1 on any failure or a
## fixture that no longer fails. tests/placement_check.gd runs it with the projection checks.
##   godot --headless --path . --script res://tests/geometry_check.gd -- [filter] [all] [time]
## filter: only cases whose label contains it (and no fixtures). all: every failing view. time: per case.

const DataLib := preload("res://src/data_lib.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const Fixtures3D := preload("res://tests/placement/fixtures_3d.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := ""
	for a in args:
		if not a in ["all", "time"]:
			filter = a
	var lib = DataLib.new()
	var t0 := Time.get_ticks_msec()
	var g = GeometryCheck.new(lib)
	g.metrics = true
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var n := run(g, cases, "time" in args)
	var failed := report(g.results, g.order, "all" in args)
	print("3D: %d checks, %d failed (%d units, %d distinct, %.1f s)" % [g.order.size(), failed, cases.size(), n, (Time.get_ticks_msec() - t0) / 1000.0])
	var fixtures_ok := true
	if filter == "":
		var f: Array = Fixtures3D.run(lib)
		fixtures_ok = f[0]
		for line in f[1]:
			print(line)
	quit(1 if failed > 0 or not fixtures_ok else 0)


## Checks each case; units the same in 3D (an age step with the same parts, a race's colours) once.
static func run(g, cases: Array, timed := false) -> int:
	var seen := {}
	for c in cases:
		var r: Dictionary = c[1].recipe
		var sig := JSON.stringify([r.body, r.get("head", ""), r.parts, r.get("mount", {}), r.get("crew", {}), r.get("haul", {}), r.get("slot", ""), r.skin], "", true)
		if seen.has(sig):
			continue
		seen[sig] = true
		var t := Time.get_ticks_msec()
		g.check(c[0], c[1])
		if timed:
			print("%s: %d ms" % [c[0], Time.get_ticks_msec() - t])
	return seen.size()


static func report(results: Dictionary, order: Array, every := false) -> int:
	var failed := 0
	for key in order:
		var fails: Array = results[key]
		var parts: PackedStringArray = key.split("|")
		if fails.is_empty():
			continue
		failed += 1
		print("FAIL %s: %s in %d views: %s" % [parts[0], parts[1], fails.size(), "; ".join(fails if every else fails.slice(0, 6)) + (" ..." if fails.size() > 6 and not every else "")])
	return failed
