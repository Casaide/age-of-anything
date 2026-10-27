extends SceneTree
## The test batch: every suite side by side (tests/par.gd), then a table (suite, checks, failed,
## time) and exit 1 if any suite failed. Suites that run their own pieces side by side get a share
## of the processes (`slots`). Each suite's whole output is kept in a log (its path is printed).
## Run: tests/batch.sh [--quick] [jobs=N]   (or godot --headless --path . --script res://tests/batch.gd -- [quick] [jobs=N])
## Quick: the fast subset to run while working (no whole bot matches, no 2v2, no reports, no window).

const Par := preload("res://tests/par.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var quick := args.has("quick") or args.has("--quick")
	var n := Par.jobs_wanted(args)
	var share := maxi(1, n / 2)   # a self-parallel suite's processes
	var suites := [
		_suite("run_tests", "res://tests/run_tests.gd", [], 5),
		_suite("test_sim", "res://tests/test_sim.gd", ["jobs=%d" % mini(share, 5)], 60, mini(share, 5)),
		_suite("test_ai quick", "res://tests/test_ai.gd", ["quick", "jobs=%d" % share], 40, share),
		_suite("placement 3d", "res://tests/geometry_check.gd", ["jobs=%d" % share], 120, share),   # (in shards: one process took 11 minutes)
		_suite("test_heroes", "res://tests/test_heroes.gd", [], 3),
	]
	if not quick:
		suites += [
			_suite("test_ai slow", "res://tests/test_ai.gd", ["slow", "jobs=%d" % share], 120, share),
			_suite("test_2v2", "res://tests/test_2v2.gd", [], 150),
			_suite("placement 2d", "res://tests/placement_check.gd", ["2d"], 60, 1, true),
			_suite("hop", "res://tests/hop_check.gd", [], 15, 1, true),
			_suite("balance age 2", "res://tests/balance.gd", ["2", "jobs=%d" % share], 30, share),
			_suite("balance age 3", "res://tests/balance.gd", ["3", "jobs=%d" % share], 30, share),
			_suite("mass_battle", "res://tests/mass_battle.gd", ["2", "jobs=%d" % share], 30, share),
		]
	print("batch%s: %d suites, up to %d processes" % [" (quick)" if quick else "", suites.size(), n + 2])
	var t0 := Time.get_ticks_msec()
	var results := Par.run(suites, n + 2)   # (+2: the windowed and the 2v2 matches are single processes)
	var bad := 0
	print("\n%-16s %7s %7s %8s  %s" % ["suite", "checks", "failed", "time", "note"])
	for r in results:
		var failed: int = maxi(0, r.failed)
		var note := ""
		if r.get("timed_out", false):
			note = "TIMED OUT"
		elif r.code != 0:
			note = "exit %d" % r.code
		var outliers := RegEx.create_from_string("(\\d+ of \\d+ units more than \\d+% off the mean)").search(FileAccess.get_file_as_string(r.log))
		if outliers:
			note = (note + "; " if note != "" else "") + outliers.get_string(1)
		if not Par.ok(r):
			bad += 1
		print("%-16s %7s %7s %7.1fs  %s" % [r.name, str(r.checks) if r.checks >= 0 else "-", str(failed) if r.checks >= 0 else "-", r.secs, note])
	var fails := {}
	for r in results:
		for f in r.fails:
			if not fails.has(f):
				fails[f] = r.name
	for f in fails:
		print("  %s: %s" % [fails[f], f])
	print("\nlogs: %s\nbatch %s in %.0f s" % [results[0].log.get_base_dir(), "FAILED (%d suites)" % bad if bad > 0 else "passed", (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if bad > 0 else 0)


func _suite(name: String, script: String, args: Array, weight: int, slots := 1, windowed := false) -> Dictionary:
	var j := Par.job(name.replace(" ", "_"), script, args, weight, 3600)
	j.name = name
	j.slots = slots
	j.windowed = windowed
	return j
