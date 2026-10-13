extends RefCounted
## Runs test pieces side by side, each in its own Godot process (used by test_ai, test_sim,
## test_2v2, balance, mass_battle and batch). A job is {name, script, args, weight, timeout,
## windowed, slots}: `script` runs with `args` after `--`; heavier jobs start first; at most one
## windowed job runs at a time (one Godot window at a time); `slots` (default 1) is how many of the
## `n` a job takes (a suite that runs its own pieces side by side). Each job's output goes to a log; the result
## adds {code, secs, log, checks, failed, stats}: `checks`/`failed` from its "N checks, M failed"
## line (-1 if it printed none), `stats` from its "@@ key json" lines.
## Pieces are independent sims with their own seeds, so the results match a serial run's.
## How many at once: "jobs=N" among a test's arguments, else AOA_JOBS, else performance cores - 1.

const GODOT_ARGS := ["--audio-driver", "Dummy"]


static func jobs_wanted(args: Array) -> int:
	for a in args:
		if String(a).begins_with("jobs="):
			return maxi(1, int(String(a).trim_prefix("jobs=")))
	if OS.get_environment("AOA_JOBS") != "":
		return maxi(1, int(OS.get_environment("AOA_JOBS")))
	var out := []
	if OS.get_name() == "macOS" and OS.execute("sysctl", ["-n", "hw.perflevel0.physicalcpu"], out) == 0 and int(out[0]) > 0:
		return maxi(1, int(out[0]) - 1)
	return maxi(1, OS.get_processor_count() - 1)


## The arguments without the runner's own ("jobs=N").
static func plain(args: Array) -> Array:
	return args.filter(func(a): return not String(a).begins_with("jobs="))


static func job(name: String, script: String, args: Array, weight := 1, timeout := 3600) -> Dictionary:
	return {"name": name, "script": script, "args": args, "weight": weight, "timeout": timeout, "windowed": false}


## Runs every job, `n` at a time; prints a line as each one finishes (to stderr if `quiet`).
static func run(jobs: Array, n: int, quiet := false) -> Array:
	var logs := ProjectSettings.globalize_path("user://test_logs")
	for old in DirAccess.get_directories_at(logs):   # runs from more than a day ago
		var files := DirAccess.get_files_at(logs + "/" + old)
		if not files.is_empty() and Time.get_unix_time_from_system() - FileAccess.get_modified_time("%s/%s/%s" % [logs, old, files[0]]) > 86400:
			for f in files:
				DirAccess.remove_absolute("%s/%s/%s" % [logs, old, f])
			DirAccess.remove_absolute(logs + "/" + old)
	var dir := "%s/%d" % [logs, OS.get_process_id()]
	DirAccess.make_dir_recursive_absolute(dir)
	var todo := jobs.duplicate()
	todo.sort_custom(func(x, y): return int(x.weight) > int(y.weight))
	var running := []   # [job, pid, started msec]
	var done := {}
	var t0 := Time.get_ticks_msec()
	while not todo.is_empty() or not running.is_empty():
		while not todo.is_empty():
			var used := 0
			for r in running:
				used += int(r[0].get("slots", 1))
			var k := 0
			var windowed := running.any(func(r): return r[0].windowed)
			while k < todo.size() and ((windowed and todo[k].windowed) or (not running.is_empty() and used + int(todo[k].get("slots", 1)) > n)):
				k += 1
			if k >= todo.size():
				break
			var j: Dictionary = todo.pop_at(k)
			j.log = "%s/%s.log" % [dir, j.name.replace("/", "_").replace(":", "_").replace(" ", "_")]
			running.append([j, _spawn(j), Time.get_ticks_msec()])
		OS.delay_msec(100)
		for r in running.duplicate():
			var j: Dictionary = r[0]
			var secs: float = (Time.get_ticks_msec() - int(r[2])) / 1000.0
			if OS.is_process_running(r[1]):
				if secs > float(j.timeout):
					OS.kill(r[1])
					j.timed_out = true
				continue
			running.erase(r)
			var res := j.duplicate()
			res.code = OS.get_process_exit_code(r[1]) if not j.get("timed_out", false) else -9
			res.secs = secs
			res.merge(parse(FileAccess.get_file_as_string(j.log)))
			done[j.name] = res
			var line := "  [%6.1fs] %-28s %s" % [(Time.get_ticks_msec() - t0) / 1000.0, j.name, summary(res)]
			if quiet:
				printerr(line)   # (progress on stderr: the report on stdout stays as a serial run prints it)
			else:
				print(line)
	return jobs.map(func(j): return done[j.name])


static func _spawn(j: Dictionary) -> int:
	var words := [OS.get_executable_path()]
	if not j.windowed:
		words.append("--headless")
	words.append_array(GODOT_ARGS)
	if j.windowed:
		words.append("--always-on-top")
	words.append_array(["--path", ProjectSettings.globalize_path("res://"), "--script", j.script, "--"])
	words.append_array(j.args)
	var line := "exec " + " ".join(words.map(_quote)) + " > %s 2>&1" % _quote(j.log)
	return OS.create_process("/bin/sh", ["-c", line])


static func _quote(s) -> String:
	return "'" + String(s).replace("'", "'\\''") + "'"


static func parse(text: String) -> Dictionary:
	var out := {"checks": -1, "failed": -1, "stats": {}, "fails": []}
	for line in text.split("\n"):
		if line.begins_with("@@ "):
			var parts := line.split(" ", false, 2)
			out.stats[parts[1]] = JSON.parse_string(parts[2]) if parts.size() > 2 else null
		elif line.begins_with("FAIL"):
			out.fails.append(line)
		elif line.contains(" failed"):   # the last "N checks, M failed" (or "<suite>: N checks, M failed") counts
			var m := RegEx.create_from_string("^(?:\\w+: )?(\\d+) checks, (\\d+) failed").search(line)
			if m:
				out.checks = int(m.get_string(1))
				out.failed = int(m.get_string(2))
	return out


static func ok(res: Dictionary) -> bool:
	return res.code == 0 and res.failed <= 0


static func summary(res: Dictionary) -> String:
	if res.get("timed_out", false):
		return "TIMED OUT after %ds" % int(res.secs)
	var s := "%d checks, %d failed" % [res.checks, res.failed] if res.checks >= 0 else "done"
	if res.code != 0:
		s += ", exit %d" % res.code
	return s


## Prints each job's log in the jobs' order (as a serial run would have), then its fails again.
static func print_logs(results: Array) -> void:
	for r in results:
		print("\n######## %s (%.1fs)" % [r.name, r.secs])
		for line in FileAccess.get_file_as_string(r.log).split("\n"):
			if not line.begins_with("@@ ") and not line.begins_with("Godot Engine v"):
				print(line)
