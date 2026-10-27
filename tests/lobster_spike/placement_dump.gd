extends SceneTree
## The placement check's cases and its 3D results as Godot has them (tests/placement/cases.gd, geometry_check.gd),
## for placement_check.lobster's parity mode: {cases: [[label, recipe]], results: {rule|label: [failing views]}}.
##   godot --headless --path . --script res://tests/lobster_spike/placement_dump.gd -- <out.json> [filter] [cases]
## cases: the case list only (no 3D run).

const DataLib := preload("res://src/data_lib.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const GeometryRun := preload("res://tests/geometry_check.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var filter: String = args[1] if args.size() > 1 and args[1] != "cases" else ""
	var lib = DataLib.new()
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var out := {"cases": cases.map(func(c): return [c[0], c[1].recipe]), "results": {}}
	if not "cases" in args:
		var g = GeometryCheck.new(lib)
		g.metrics = true
		GeometryRun.run(g, cases)
		out.results = g.results
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("%d cases, %d results" % [cases.size(), out.results.size()])
	quit()
