extends SceneTree
## Where a cold unit bake's time goes: every unit-part job of a race baked one at a time, the disk
## cache off (nothing read, nothing written), timed per job and grouped by kind of part, with the
## part baker's phases (build, render, cut render, readback, cut loop, pixelize, tip) summed. Then
## the portraits. Run (needs a display):
##   godot --audio-driver Dummy --always-on-top --path . --script res://tests/bake_profile.gd -- ["prompt"] [workers]
## workers > 1 bakes as the game does (that many at once) and reports only the totals.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const BakeCache := preload("res://src/view/art/bake_cache.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const PartShape := preload("res://src/part_shape.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prompt: String = args[0] if args.size() > 0 else "centaur romans"
	var workers := int(args[1]) if args.size() > 1 else 1
	BakeCache.enabled = false
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var race: Dictionary = gen.generate(prompt, rules)
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var steps := 0
	for u in race.units:
		steps += u.get("line", [1]).size()
	var ids: Array = kit._unit_jobs([race])
	print("%s: %d lines, %d line steps, %d part jobs" % [race.name, race.units.size(), steps, ids.size()])
	var t0 := Time.get_ticks_msec()
	if workers > 1:
		kit.part_workers = workers
		await kit.bake_units([race])
	else:
		var baker := PartBaker.new()
		baker.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
		baker.bands = ArtKit.UNIT_BANDS
		kit.add_child(baker)
		var groups := {}   # kind -> [jobs, ms]
		var slow := []
		for id in ids:
			var j: Dictionary = kit._jobs[id]
			if j.done:
				continue
			var t := Time.get_ticks_usec()
			await j.make.call(baker)
			j.done = true
			var ms := (Time.get_ticks_usec() - t) / 1000.0
			var part: String = String(id).get_slice("|", 1).get_slice(":", 0)
			var kind := _kind(part)
			if not groups.has(kind):
				groups[kind] = [0, 0.0]
			groups[kind][0] += 1
			groups[kind][1] += ms
			slow.append([ms, part])
		var keys := groups.keys()
		keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
		print("\nby kind of part:   jobs   ms   ms/job")
		for k in keys:
			print("  %-26s %4d %7.0f %6.0f" % [k, groups[k][0], groups[k][1], groups[k][1] / groups[k][0]])
		slow.sort_custom(func(a, b): return a[0] > b[0])
		print("\nslowest jobs:")
		for s in slow.slice(0, 12):
			print("  %6.0f ms  %s" % s)
	var t1 := Time.get_ticks_msec()
	print("\nphases (part baker, summed):")
	var ph: Dictionary = PartBaker.prof
	var pk := ph.keys()
	pk.sort_custom(func(a, b): return ph[a] > ph[b])
	for k in pk:
		print("  %-12s %7.0f ms" % [k, ph[k] / 1000.0])
	print("  forced draws: %d, %.0f ms drawing" % [kit.BakeClock.draws, kit.BakeClock.draw_usec / 1000.0])
	kit.rebuild_atlas()
	var t2 := Time.get_ticks_msec()
	await kit.bake_icons([race], [Color(lib.palettes.teams[0])])
	var t3 := Time.get_ticks_msec()
	print("\nunits %d ms (%d sprites), atlas %d ms, icons %d ms (%d portraits)" % [t1 - t0, PartShape.baked.size(), t2 - t1, t3 - t2, kit.icons.size()])
	quit()


static func _kind(part: String) -> String:
	var base := part.get_slice("~", 0)
	var hold := base.get_slice("@", 1) if "@" in base else ""
	var slot := base.get_slice(".", 0)
	if slot == "siege":
		return "siege engine"
	if "~" in part and "^" in part:
		return "%s cut by its body%s" % [slot, " (posed)" if hold != "" else ""]
	if "~" in part:
		return "armour on its wearer"
	if hold.begins_with("w"):
		return "%s walk step" % slot
	if hold in ["reach", "raise", "thrust"]:
		return "body work/attack hold"
	if hold != "":
		return "%s idle pose" % slot
	return slot
