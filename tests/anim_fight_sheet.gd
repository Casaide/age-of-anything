extends SceneTree
## A contact sheet of the live attack and death animation (D-106), through the game's own
## paths: for each race's melee unit, five frames of flourish() (the lunge), for an archer
## five of loose() (the release), and six of die() at 0, 0.12, 0.25, 0.4, 0.6 and 1.0 s.
## Run (needs a display): godot --path . --script res://tests/anim_fight_sheet.gd -- out.png

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")

const ZOOM := 4.0
const DEATH_T := [0.0, 0.12, 0.25, 0.4, 0.6, 1.0]
const PROMPTS := ["tiny vikings", "angry swamp frogs with reed spears", "centaur romans", "spooky beetle knights", "pegasus riding spartans"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://fight.png"
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races: Array = PROMPTS.map(func(p): return gen.generate(p, rules))
	var team := Color(lib.palettes.teams[0])
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units(races, races.map(func(_r): return team))
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(1600, 1700)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var y := 50.0
	for k in races.size():
		var r: Dictionary = races[k]
		var melee := _unit(r, "large" if k == 4 else "spear")   # the pegasus race: its flying lancer
		var row := [[melee, "blow"]]
		var archer := _unit(r, "archer")
		if not archer.is_empty() and k == 0:
			row.append([archer, "loose"])
		row.append([melee, "die"])
		for entry in row:
			var u: Dictionary = entry[0]
			var kind: String = entry[1]
			var frames := DEATH_T.size() if kind == "die" else 5
			var big: bool = u.recipe.has("mount")
			var gap := 230.0 if big and not u.recipe.mount.get("fused", false) else 120.0
			for f in frames:
				var v := UnitView.new()
				v.build(u.recipe, lib, team, u.eval.speed)
				v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
				v.pose_steps = 0
				v.position = Vector2(60 + f * gap, y + (120 if big else 90)) / ZOOM
				v.idle_wait = 1000.0
				v.time = 0.3
				world.add_child(v)
				v._process(0.0)
				var until: float = DEATH_T[f] if kind == "die" else 0.35 * f / 4.0
				match kind:
					"blow": v.flourish()
					"loose": v.loose()
					"die": v.die(1.0)
				var t := 0.0
				while t < until - 0.0001:
					var dt := minf(0.02, until - t)
					v._process(dt)
					t += dt
				v.set_process(false)
			y += 175 if big else 125
	for f in 12:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


static func _unit(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	return {}
