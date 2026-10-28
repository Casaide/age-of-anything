extends SceneTree
## The 3D placement check alone, headless (tests/placement/geometry_check.gd): every unit, mount,
## rider, animal and siege crew in every pose, measured on its meshes, then the regression fixtures
## (tests/placement/fixtures_3d.gd). FAIL lines per rule and unit, exit 1 on any failure or a
## fixture that no longer fails. tests/placement_check.gd runs it with the projection checks.
##   godot --headless --path . --script res://tests/geometry_check.gd -- [filter] [all] [time] [jobs=N]
## filter: only cases whose label contains it (and no fixtures). all: every failing view. time: per case.
## The whole roster runs in shards side by side (tests/par.gd: one process did it in 11 minutes and the
## batch's timeout ended it); "shard:i/n" is one of them (shard 0 also runs the fixtures).

const DataLib := preload("res://src/data_lib.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const Fixtures3D := preload("res://tests/placement/fixtures_3d.gd")
const Par := preload("res://tests/par.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var filter := ""
	var shard := [0, 1]
	for a in Par.plain(args):
		if a.begins_with("shard:"):
			shard = Array(a.trim_prefix("shard:").split("/")).map(func(x): return int(x))
		elif not a in ["all", "time"]:
			filter = a
	if filter == "" and shard[1] == 1 and Par.jobs_wanted(args) > 1:
		var res: Array = sharded(Par.jobs_wanted(args), "all" in args)
		quit(1 if res[1] > 0 or not res[2] else 0)
		return
	var lib = DataLib.new()
	var t0 := Time.get_ticks_msec()
	var g = GeometryCheck.new(lib)
	g.metrics = true
	var cases: Array = Cases.all(lib).filter(func(c): return filter == "" or filter in c[0])
	var n := run(g, cases, "time" in args, shard)
	var failed := report(g.results, g.order, "all" in args)
	print("3D: %d checks, %d failed (%d units, %d distinct, %.1f s)" % [g.order.size(), failed, cases.size(), n, (Time.get_ticks_msec() - t0) / 1000.0])
	var fixtures_ok := true
	if filter == "" and shard[0] == 0:
		var f: Array = Fixtures3D.run(lib)
		fixtures_ok = f[0]
		for line in f[1]:
			print(line)
	quit(1 if failed > 0 or not fixtures_ok else 0)


## The whole roster in n shards side by side: their checks and failures added up, their FAIL lines
## and fixture lines repeated. Returns [checks, failed, fixtures all caught and every shard exited cleanly].
static func sharded(n: int, every: bool) -> Array:
	var t0 := Time.get_ticks_msec()
	var jobs := []
	for i in n:
		jobs.append(Par.job("3d_%d" % i, "res://tests/geometry_check.gd", ["shard:%d/%d" % [i, n]] + (["all"] if every else []), 1, 3600))
	var results: Array = Par.run(jobs, n, true)
	var checks := 0
	var failed := 0
	var code := 0
	for res in results:
		checks += maxi(res.checks, 0)
		failed += maxi(res.failed, 0)
		code = maxi(code, res.code)
		for line in FileAccess.get_file_as_string(res.log).split("\n"):
			if line.begins_with("FAIL") or line.begins_with("BROKEN"):   # (a fixture no longer caught)
				print(line)
	print("3D: %d checks, %d failed (%d shards, %.1f s)" % [checks, failed, n, (Time.get_ticks_msec() - t0) / 1000.0])
	return [checks, failed, code == 0 or failed > 0]


## Checks each case; units the same in 3D (an age step with the same parts, a race's colours) once.
## shard [i, n]: only every n-th distinct unit from the i-th.
static func run(g, cases: Array, timed := false, shard := [0, 1]) -> int:
	var seen := {}
	for c in cases:
		var r: Dictionary = c[1].recipe
		var sig := JSON.stringify([r.body, r.get("head", ""), r.parts, r.get("mount", {}), r.get("crew", {}), r.get("haul", {}), r.get("slot", ""), r.skin], "", true)
		if seen.has(sig):
			continue
		seen[sig] = true
		if (seen.size() - 1) % int(shard[1]) != int(shard[0]):
			continue
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
