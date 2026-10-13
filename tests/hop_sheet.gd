extends SceneTree
## The frogs' hop, frame by frame (2026-10-13; Dominic: "frog walking animation needs to improve, it
## glides along the ground too much"). Each row is a facing, each cell one moment of a hopping frog
## moving at its sim speed as the game moves it (stepped poses, whole art pixels, the game's camera
## scale times the zoom); every cell shows the same patch of ground (a dot grid), so a planted foot
## stays on its dots and a glide shows. The red tick is the sim position. Run (needs a display):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/hop_sheet.gd -- out.png [frames] [seconds] [facings] [slot] [zoom] [title]
## frames: cells per row (12); seconds: the time they span (1.2; 0: one hop, after a hop to settle in); facings: "0,1,2"; slot: spear,
## worker, large, unique (the race's unique unit), bolt (the toad bolt thrower); zoom: 3.

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const Iso := preload("res://src/view/iso.gd")

const CELL := Vector2(96, 72)   # world units per cell
const DT := 1.0 / 60.0

var lib
var team: Color


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var frames := int(args[1]) if args.size() > 1 else 12
	var span := float(args[2]) if args.size() > 2 else 1.2
	var facings: Array = Array((args[3] if args.size() > 3 else "0,1,2").split(",")).map(func(s): return int(s))
	var slot: String = args[4] if args.size() > 4 else "spear"
	var zoom := float(args[5]) if args.size() > 5 else 3.0
	var title: String = args[6] if args.size() > 6 else "hop"
	lib = DataLib.new()
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate("swamp frogs", DataLib.load_json("res://data/rules/default.json"), 0)
	var unit := _unit_for(race, slot)
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units([race], [team])

	var label_w := 70.0
	var head_h := 34.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(label_w + CELL.x * zoom * frames), int(head_h + CELL.y * zoom * facings.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#56782e")
	bg.size = Vector2(vp.size)
	var back := CanvasLayer.new()
	back.layer = -1
	vp.add_child(back)
	back.add_child(bg)
	var front := CanvasLayer.new()
	vp.add_child(front)
	front.add_child(_label("%s: %s, %d frames over %s, %sx" % [title, unit.recipe.name if unit.recipe.get("name", "") != "" else slot, frames, "%.2f s" % span if span > 0.0 else "one hop", str(zoom)], Vector2(8, 8), 14))
	# The world: one cell per frame, laid out in world units and drawn at the game's art scale x zoom
	# by a camera (the view snaps to whole art pixels in global space, as in the game).
	var world := Node2D.new()
	vp.add_child(world)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.zoom = Vector2.ONE * zoom
	cam.position = Vector2(-label_w, -head_h) / zoom
	world.add_child(cam)
	cam.make_current()
	var pixel := 1.0 / ArtKit.ART_SCALE
	for r in facings.size():
		var k: int = facings[r]
		front.add_child(_label("f%d" % k, Vector2(8, head_h + (r + 0.45) * CELL.y * zoom), 14))
		var probe := _view(unit, k)
		var vel := _velocity(probe, unit, k)
		var warm := 0.0
		var length := span
		if span <= 0.0:
			# One hop: a hop's ground over the ground speed (a tile is 45.25 canvas units of ground).
			var period: float = float(probe.get_script().get_script_constant_map().get("HOP_LENGTH", 40.0)) * sqrt(probe.unit_scale) * ArtKit.UNIT_SCALE / (float(unit.eval.speed) / 10.0 * 45.25)
			warm = period
			length = period * (frames - 1) / frames
		probe.free()
		var start := Vector2(CELL.x * 0.5, CELL.y * 0.62) - vel * (warm + length * 0.5)
		for c in frames:
			var at := Vector2(c * CELL.x, r * CELL.y)
			# The ground: a dot every 3 art pixels, the same in every cell of the row.
			var dots := _Dots.new()
			dots.size = CELL
			dots.step = pixel * 3.0
			dots.position = at
			world.add_child(dots)
			var v := _view(unit, k)
			world.add_child(v)
			v.position = at + start
			var t := warm + length * c / maxf(frames - 1, 1)
			var n := int(roundf(t / DT))
			v.walking = true
			for i in n:
				v.position += vel * DT
				v._process(DT)
			var tick := ColorRect.new()
			tick.color = Color(0.9, 0.15, 0.1)
			tick.size = Vector2(pixel, pixel * 3.0)
			tick.position = v.position + Vector2(-pixel * 0.5, pixel * 2.0)
			world.add_child(tick)
			var sep := ColorRect.new()
			sep.color = Color(0, 0, 0, 0.18)
			sep.size = Vector2(pixel, CELL.y)
			sep.position = at
			world.add_child(sep)
	for f in 12:
		await process_frame
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


func _unit_for(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		var r: Dictionary = u.recipe
		var ok: bool = r.slot == slot and int(r.get("tier", 1)) == 1 if slot in ["spear", "worker"] else false
		if slot == "large" and r.slot == "large" and not r.has("mount"):
			ok = true
		if slot == "unique" and r.has("unique"):
			ok = true
		if slot == "bolt" and r.has("crew") and r.body.find("bolt") >= 0:
			ok = true
		if ok:
			return u
	assert(false, "no %s unit" % slot)
	return {}


func _view(unit: Dictionary, k: int) -> Node2D:
	var v := UnitView.new()
	v.facing_k = k
	v.build(unit.recipe, lib, team, unit.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	v.pose_steps = 8
	v.art_px = ArtKit.ART_SCALE
	v.idle_wait = 1000.0
	v.set_process(false)
	return v


## The screen velocity of a unit walking the way facing k looks, at its sim speed (speed 10: a tile a
## second), as the sim's interpolated positions move it.
func _velocity(v, unit: Dictionary, k: int) -> Vector2:
	var rig: Dictionary = PartShape.rigs.get(v._facing_body + PartShape.facing_suffix(k), {})
	var d: Vector2 = (rig.dir as Vector2).normalized() if rig.has("dir") else Vector2(1, 0.35).normalized()
	var a := d.x / (Iso.TILE_W * 0.5)
	var b := d.y / (Iso.TILE_H * 0.5)
	var sim := Vector2((a + b) * 0.5, (b - a) * 0.5).normalized() * float(unit.eval.speed) * 100.0
	return Iso.to_screen(sim.x, sim.y)


func _label(text: String, at: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#f4f1e8"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	return l


class _Dots extends Node2D:
	var size := Vector2.ZERO
	var step := 2.0

	func _draw() -> void:
		var y := step
		while y < size.y:
			var x := step
			while x < size.x:
				draw_rect(Rect2(x, y, step / 3.0, step / 3.0), Color(0.2, 0.32, 0.1, 0.55))
				x += step
			y += step
