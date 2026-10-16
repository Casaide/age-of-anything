extends SceneTree
## Does a cold bake hold the screen up? Bakes as the game does, every bake rendering (the disk
## cache off: a first run on a new machine), and times every frame meanwhile: the longest, how
## many go over the budget, and what the kit was busy with in the worst ones. A loader is up the
## whole time (match: the match loader, as a match start shows it).
##   match  kit.prepare for two races (units, props, buildings, atlas, portraits), the match loader up
##   lobby  the lobby's stage bake for two races (bake_steps), then the warm-up behind it (kit.warm)
## Run (needs a display):
##   godot --audio-driver Dummy --always-on-top --path . --script res://tests/bake_frames.gd -- [match|lobby] [budget_ms] ["prompt A" "prompt B"]
##   ... dump:<file>  also writes a digest of everything baked (every sprite's pixels, origin, rig, every
##   building's info, every portrait) to <file>: two runs' files are the same when the art is.
## Exit 1 when a frame went over the budget (default 27 ms of slack for the draw).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const BakeClock := preload("res://src/view/art/bake/bake_clock.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const MatchLoader := preload("res://scenes/match_loader.gd")

var gaps := []      # [ms, what the kit was busy with]
var _last := 0
var _kit
var _on := false
var _tail


class Tail extends Node:
	var t := 0
	func _process(_d: float) -> void:
		t = Time.get_ticks_usec()


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var dump := ""
	for a in args:
		if String(a).begins_with("dump:"):
			dump = String(a).trim_prefix("dump:")
	args = args.filter(func(a): return not String(a).begins_with("dump:"))
	var mode: String = args[0] if args.size() > 0 else "match"
	var budget := float(args[1]) if args.size() > 1 else float(BakeClock.BUDGET_MS + 15)
	var prompts: Array = [args[2], args[3]] if args.size() > 3 else ["centaur romans", "sewer rats with cheese hammers"]
	BakeCache.enabled = false
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var races := [gen.generate(prompts[0], rules), gen.generate(prompts[1], rules)]
	var teams := [Color(lib.palettes.teams[0]), Color(lib.palettes.teams[1])]
	_kit = ArtKit.new()
	_kit.lib = lib
	root.add_child(_kit)
	process_frame.connect(_tick)
	_tail = Tail.new()
	_tail.process_priority = 100000
	root.add_child(_tail)
	for f in 10:
		await process_frame
	var t0 := Time.get_ticks_msec()
	_on = true
	_last = Time.get_ticks_usec()
	if mode == "lobby":
		for race in races:
			var picks: Array = race.units.slice(0, 6)
			await _kit.bake_steps(picks.map(func(u): return {"recipe": u.recipe, "eval": u.eval}))
		_kit.rebuild_atlas()
		_kit.warm(races, teams)
		while _kit._queue.values().any(func(q): return not q.is_empty()) or _kit._workers.values().any(func(n): return n > 0):
			await process_frame
	else:
		var loader := MatchLoader.new()
		root.add_child(loader)
		loader.start(_kit, lib, races, teams, "reed_meadow")
		await _kit.prepare(races, teams)
	_on = false
	var total := Time.get_ticks_msec() - t0
	var ms := gaps.map(func(g): return g[0])
	ms.sort()
	var over := gaps.filter(func(g): return g[0] > budget)
	print("\n%s, cold: %d ms, %d frames; frame ms: median %.1f, p95 %.1f, max %.1f; over %.0f ms: %d" % [
		mode, total, gaps.size(), ms[ms.size() / 2], ms[int(ms.size() * 0.95)], ms[-1], budget, over.size()])
	var worst := gaps.duplicate()
	worst.sort_custom(func(a, b): return a[0] > b[0])
	print("worst frames:")
	for g in worst.slice(0, 10):
		print("  %6.1f ms  %s" % g)
	if dump != "":
		_dump(dump)
	quit(1 if not over.is_empty() else 0)


## Everything baked, to compare runs (tests/bake_compare.gd): name -> [Image data, what goes with it].
func _dump(path: String) -> void:
	var PartShape = ArtKit.PartShape
	var out := {}
	for k in PartShape.baked:
		var b: Dictionary = PartShape.baked[k]
		out["part " + k] = [_raw(b.img), [b.origin, b.scale]]
	for k in PartShape.rigs:
		out["rig " + k] = [null, PartShape.rigs[k]]
	for k in _kit.bakes:
		out["bake " + k] = [_raw(_kit.bakes[k].img), [_kit.bakes[k].origin]]
	for k in _kit.buildings:
		var info: Dictionary = _kit.buildings[k].duplicate()
		var img = null
		if info.has("banner"):
			img = _raw(info.banner.tex.get_image())
			info.banner = info.banner.origin
		out["building " + k] = [img, info]
	for k in _kit.icons:
		out["icon " + k] = [_raw(_kit.icons[k].get_image()), []]
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var(out)
	f.close()
	print("dumped %d things to %s" % [out.size(), path])


static func _raw(img: Image) -> Array:
	var c: Image = img.duplicate()
	c.convert(Image.FORMAT_RGBA8)
	return [c.get_width(), c.get_height(), c.get_data()]


func _tick() -> void:
	if not _on:
		return
	var now := Time.get_ticks_usec()
	gaps.append([(now - _last) / 1000.0, _kit.busy_with() if not _kit.track.is_empty() else "warm-up/steps"])
	_last = now
