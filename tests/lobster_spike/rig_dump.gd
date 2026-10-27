extends SceneTree
## Units put together in 3D by rig3d.gd, for rig_check.lobster: every unit of each race asked for (and its spear
## unit on a pony and on a cat), standing, in a raised hold with its weapon turned, levelled, and at two walk
## phases; per piece its name, model, joint, transform and the vertices' lowest point.
##   godot --headless --path . --script res://tests/lobster_spike/rig_dump.gd -- <out.json> "<prompt>"...

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const Rig3D := preload("res://src/view/art/rig3d.gd")
const Geom := preload("res://src/view/art/geom.gd")

## [name, pose]: the poses rig_check.lobster asks for too (the walk in radians, the turn in radians as Godot's).
const POSES := [["stand", {}], ["raise", {"hold": "raise", "turn": 1.2}], ["level", {"hold": "thrust", "level": true}],
	["walk1", {"walk": TAU * 1 / 8}], ["walk5", {"walk": TAU * 5 / 8}]]


static func recipes(lib, prompts: Array) -> Array:
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var out := []
	for p in prompts:
		var race: Dictionary = gen.generate(p, rules, 0)
		for u in race.units:
			if not u.recipe.has("crew"):
				out.append(["%s %s" % [p, u.recipe.slot], u.recipe])
		for u in race.units:
			if u.recipe.slot == "spear":
				for m in ["pony", "cat"]:
					var r: Dictionary = u.recipe.duplicate(true)
					r.mount = {"creature": m, "skin": lib.creatures[m].skins[0], "parts": {}, "fused": false}
					out.append(["%s spear on %s" % [p, m], r])
	return out


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var lib = DataLib.new()
	var rig = Rig3D.new(lib)
	var out := []
	for c in recipes(lib, args.slice(1)):
		for po in POSES:
			var a: Dictionary = rig.unit(c[1], po[1])
			var ps := []
			for p in a.pieces:
				var lo := INF
				for v in Geom.vertices(p.node, p.xf):
					lo = minf(lo, v.y)
				var b: Basis = p.xf.basis
				ps.append({"name": p.name, "id": p.id, "parent": p.parent, "joint": [p.joint.x, p.joint.y, p.joint.z],
					"o": [p.xf.origin.x, p.xf.origin.y, p.xf.origin.z], "b": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z], "low": lo})
			out.append({"label": c[0], "pose": po[0], "walker": a.walker, "flying": a.flying, "seat": [a.get("seat", Vector3.ZERO).x, a.get("seat", Vector3.ZERO).y, a.get("seat", Vector3.ZERO).z], "pieces": ps})
		rig.clear()
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("%d views" % out.size())
	quit()
