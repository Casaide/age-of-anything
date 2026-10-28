extends SceneTree
## The hop, by numbers (2026-10-13; Dominic: the frogs "glide along the ground too much"). A hopping
## frog is walked at its sim speed the way the game moves it (each facing, smooth and stepped poses,
## a turn half way, then a stop), and its drawn feet are measured every frame:
##   planted   on the ground (crouching, landing) each foot stays within 1 art pixel of where it was
##   tracks    over whole hops the drawn frog averages out on its sim position (within 1 art pixel)
##   hops      it really leaves the ground and covers the ground in the air
##   settles   stopped, it ends standing on its node with no jump (smooth poses: under 1.5 art px a frame)
## Also: every hopping unit of a frog race uses the hop (its spear, worker, giant, bullfrog, its siege
## crew), and riders don't. Prints "N checks, M failed"; exit 1 on a failure. Run (needs a display for
## the bakes):
##   godot --path . --audio-driver Dummy --always-on-top --script res://tests/hop_check.gd

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartShape := preload("res://src/part_shape.gd")
const Iso := preload("res://src/view/iso.gd")

const DT := 1.0 / 60.0
static var PX := 1.0 / ArtKit.ART_SCALE   # an art pixel in canvas units

var lib
var team: Color
var checks := 0
var failed := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", what)


func _initialize() -> void:
	await process_frame
	lib = DataLib.new()
	team = Color(lib.palettes.teams[0])
	var gen = Generator.new(lib)
	var race: Dictionary = gen.generate("swamp frogs", DataLib.load_json("res://data/rules/default.json"), 0)
	var kit := ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	await kit.prepare_units([race], [team])

	var spear := _unit(race, func(r): return r.slot == "spear" and int(r.tier) == 1)
	var giant := _unit(race, func(r): return r.slot == "large" and not r.has("mount"))
	for u in [spear, giant]:
		for stepped in [false, true]:
			for k in 8:
				_walk(u, k, stepped)

	# Every frog that walks hops; riders and engines don't (their mounts and wheels move them).
	for u in race.units:
		var v := _view(u, 0, false)
		var r: Dictionary = u.recipe
		var want: bool = not r.has("mount") and not r.has("crew")
		check(v.gait.get("hop", false) == want, "%s: hops %s" % [r.name, want])
		for c in v.crew:
			check(c.view.gait.get("hop", false) == not c.view.recipe.has("mount"), "%s crew %s hops" % [r.name, c.socket])
		v.free()
	print("hop: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)


func _unit(race: Dictionary, pick: Callable) -> Dictionary:
	for u in race.units:
		if pick.call(u.recipe):
			return u
	assert(false, "no such unit")
	return {}


func _view(u: Dictionary, k: int, stepped: bool) -> Node2D:
	var v := UnitView.new()
	v.facing_k = k
	v.build(u.recipe, lib, team, u.eval.speed)
	v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
	if stepped:
		v.pose_steps = 8
		v.art_px = ArtKit.ART_SCALE
	v.idle_wait = 1000.0
	v.set_process(false)
	return v


## The screen velocity of walking the way facing k looks, at the sim speed (speed 10: a tile a second).
func _velocity(v, speed: int, k: int) -> Vector2:
	var rig: Dictionary = PartShape.rigs.get(v._facing_body + PartShape.facing_suffix(k), {})
	var d: Vector2 = (rig.dir as Vector2).normalized() if rig.has("dir") else Vector2(1, 0.35).normalized()
	var a := d.x / (Iso.TILE_W * 0.5)
	var b := d.y / (Iso.TILE_H * 0.5)
	var sim := Vector2((a + b) * 0.5, (b - a) * 0.5).normalized() * float(speed) * 100.0
	return Iso.to_screen(sim.x, sim.y)


## Each leg's lowest sole, in canvas units, as drawn now.
func _feet(v) -> Array:
	var out := []
	for leg in v.legs:
		var n: PartShape = leg.node
		var b: Variant = n.bake_of()
		assert(b != null, "leg not baked: " + n.part_id)
		var t: Transform2D = n.get_global_transform()
		var low := Vector2(0, -INF)
		for p in PartShape.soles(b):
			var g: Vector2 = t * p
			if g.y > low.y:
				low = g
		out.append(low)
	return out


func _walk(u: Dictionary, k: int, stepped: bool) -> void:
	var label := "%s f%d %s" % [u.recipe.name, k, "stepped" if stepped else "smooth"]
	var v := _view(u, k, stepped)
	root.add_child(v)
	var vel := _velocity(v, int(u.eval.speed), k)
	v.walking = true
	var slide := 0.0
	var prev_feet := []
	var prev_ground := false
	var prev_p := 0.0
	var sum := Vector2.ZERO
	var n := 0
	var wraps := 0
	var hop_sum := Vector2.ZERO   # this hop's frames so far (committed when the next begins)
	var hop_n := 0
	var top := 0.0
	var start := v.position
	var air_move := 0.0
	var ground_move := 0.0
	var prev_drawn := Vector2.ZERO
	# Walk 8 s (turning 60 degrees at 4 s: still planted), then stop and settle for up to 3 s.
	var frames := int(8.0 / DT)
	for i in frames + int(3.0 / DT):
		if i == frames:
			v.walking = false
		if i == frames / 2:
			vel = vel.rotated(PI / 3.0)
		if v.walking:
			v.position += vel * DT
		v._process(DT)
		var p: float = fposmod(v.phase / TAU, 1.0)
		var feet := _feet(v)
		var ground: bool = v.hop_grounded()
		var drawn: Vector2 = v.visual.global_position + Vector2(0, v.lift)   # (no lift here: 0)
		if v.walking and ground and prev_ground and p >= prev_p and not prev_feet.is_empty():
			for j in feet.size():
				slide = maxf(slide, feet[j].distance_to(prev_feet[j]))
			ground_move += drawn.distance_to(prev_drawn)
		elif i > 0 and v.walking:
			air_move += drawn.distance_to(prev_drawn)
		if v.walking:
			top = maxf(top, -v.bob.position.y)
			# Whole hops between the first and the last time it starts a new one.
			if p < prev_p:
				wraps += 1
				if wraps >= 2 and i < frames / 2:
					sum += hop_sum
					n += hop_n
				hop_sum = Vector2.ZERO
				hop_n = 0
			hop_sum += drawn - v.position
			hop_n += 1
		elif i > frames and not stepped:
			check(drawn.distance_to(prev_drawn) < 1.5 * PX, "%s settles without a jump (%.2f px)" % [label, drawn.distance_to(prev_drawn) / PX])
		prev_feet = feet
		prev_ground = ground
		prev_p = p
		prev_drawn = drawn
	check(slide <= 1.0 * PX + 0.001, "%s: a planted foot slides %.2f art px" % [label, slide / PX])
	# (over the whole hops before the turn, from the first new hop on)
	check(n > 0 and (sum / n).length() <= PX, "%s: drawn %.2f art px off its sim position on average" % [label, (sum / maxf(n, 1)).length() / PX])
	check(top > 4.0, "%s: leaves the ground (%.1f)" % [label, top])
	check(air_move > ground_move * 3.0, "%s: covers the ground in the air (%.0f) not on it (%.0f)" % [label, air_move, ground_move])
	check(v._hop_off == Vector2.ZERO and v.phase == 0.0, "%s: stopped, stands on its node (off %s, phase %.2f)" % [label, v._hop_off, v.phase])
	v.queue_free()
