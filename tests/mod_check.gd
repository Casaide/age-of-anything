extends SceneTree
## Check a mod (milestone 21, docs/modding.md): load it (with the mods it depends on), print why it's
## refused if it is, then the 3D placement check on every unit of its manifest's "check" prompts that
## wears or holds one of its parts. Exit 1 on a refusal or a failure. Headless:
##   godot --headless --path . --script res://tests/mod_check.gd -- <mod id> [more ids]
## The 2D half and the look: the mod's sheet (tests/sheet.gd), and AOW_MODS=<id> placement_check.gd -- "mod <id>".

const DataLib := preload("res://src/data_lib.gd")
const Cases := preload("res://tests/placement/cases.gd")
const GeometryCheck := preload("res://tests/placement/geometry_check.gd")
const GeometryRun := preload("res://tests/geometry_check.gd")


func _initialize() -> void:
	var ids := Array(OS.get_cmdline_user_args())
	var found: Dictionary = DataLib.Mods.discover()
	var want := []
	for id in ids:   # the mods it depends on first (one level is enough for now)
		if found.has(id) and found[id].manifest is Dictionary:
			for dep in found[id].manifest.get("depends", []):
				if not dep in want:
					want.append(dep)
		if not id in want:
			want.append(id)
	var used: Array = DataLib.Mods.use(want)
	var bad := 0
	for id in want:
		if id in used:
			print("LOADED  %s (%s)" % [id, DataLib.Mods.signature()[used.find(id)]])
		else:
			bad += 1
			print("REFUSED %s: %s" % [id, DataLib.Mods.refused.get(id, "?")])
	if bad == 0:
		var lib = DataLib.new()
		var g = GeometryCheck.new(lib)
		g.metrics = true
		var cases: Array = Cases.mod_cases(lib).filter(func(c): return ids.any(func(id): return c[0].begins_with("mod %s:" % id)))
		GeometryRun.run(g, cases)
		bad += GeometryRun.report(g.results, g.order)
		print("mod_check: %d units of the mod checked in 3D, %d failed" % [cases.size(), bad])
	quit(1 if bad > 0 else 0)
