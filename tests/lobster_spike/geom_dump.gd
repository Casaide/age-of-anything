extends SceneTree
## Every modelled part a race's units wear, voxelized by geom.gd (placed as built and turned, scaled and moved),
## for geom_check.lobster: per part, its voxel keys sorted, its vertex count and its eyes' and brows' boxes.
##   godot --headless --path . --script res://tests/lobster_spike/geom_dump.gd -- <out.json> "<prompt>" [part id ...]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitModels := preload("res://scenes/art_pixel/unit_models.gd")
const UnitView := preload("res://src/unit_view.gd")
const Geom := preload("res://src/view/art/geom.gd")

## The second placing: turned 30 degrees about y and 10 about x, scaled 0.8, moved (as a rider or gear is).
static func moved() -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(30.0)) * Basis(Vector3.RIGHT, deg_to_rad(10.0))
	return Transform3D(b.scaled(Vector3.ONE * 0.8), Vector3(3.25, 7.5, -1.75))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lib = DataLib.new()
	var race: Dictionary = Generator.new(lib).generate(args[1], DataLib.load_rules("default"), 0)
	var models = UnitModels.new()
	var ids := []
	if args.size() > 2:
		ids = args.slice(2)
	else:
		for u in race.units:
			var r: Dictionary = u.recipe
			for id in [r.body, r.get("head", "")] + r.parts.values():
				if id is String and id != "" and not id in ids:
					ids.append(id)
	var r1: Dictionary = race.units[1].recipe
	var colours := UnitView.colours_for(lib, r1.skin, race.family, Color.MAGENTA)
	var out := {}
	for id in ids:
		if not models.has(id):
			continue
		var s: Dictionary = models.build(id, colours)
		var rec := {}
		for k in 2:
			var xf := Transform3D.IDENTITY if k == 0 else moved()
			var keys: Array = Geom.voxels(s.node, xf).keys()
			keys.sort()
			rec["vox%d" % k] = keys
		rec.verts = Geom.vertices(s.node).size()
		for w in ["eye", "brow"]:
			rec[w] = Geom.features(s.node, w, Transform3D.IDENTITY).map(func(b: AABB): return [b.position.x, b.position.y, b.position.z, b.size.x, b.size.y, b.size.z])
		out[id] = rec
		s.node.free()
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("%d parts" % out.size())
	quit()
