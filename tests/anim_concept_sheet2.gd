extends SceneTree
## Animation concepts, round two (2026-10-12): attacks and deaths, rendered through the real rig
## and bakes at 4x for Dominic to pick from (D-080). Sheets per race:
##   attack_<race>  T1 step-in: a lunge forward, the near leg stepping, the arm swinging through
##                     its baked holds (raise, reach) or a spear thrusting; T2 swing only: the
##                     holds and the weapon, feet still; T3 as now: the weapon twitches 6 px.
##                  Archers: R1 draw and loose: lean back, bow up, snap forward on the shot;
##                     R2 as now: nothing.
##   death_<race>   D1 topple (as now): the sprite tips 80 degrees about its feet and fades;
##                  D2 crumple: the legs fold, the body sinks to the ground, the head drops;
##                  D3 by shape: bipeds topple backwards with a bounce, hoppers flop on their
##                     back, four and six legs crumple, flyers drop first then topple.
## Attack rows: five frames across the blow. Death rows: 0, 0.12, 0.25, 0.4, 0.6 and 1.0 s.
## Run (needs a display): godot --path . --script res://tests/anim_concept_sheet2.gd -- out_dir

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const UnitView := preload("res://src/unit_view.gd")
const ArtKit := preload("res://src/view/art/art_kit.gd")
const PartBaker := preload("res://scenes/art_pixel/part_baker.gd")
const PartShape := preload("res://src/part_shape.gd")

const ZOOM := 4.0
const BG := Color("#56782e")
const DEATH_T := [0.0, 0.12, 0.25, 0.4, 0.6, 1.0]

var lib
var kit
var out_dir: String
var team: Color


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://concepts"
	DirAccess.make_dir_recursive_absolute(out_dir)
	lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	team = Color(lib.palettes.teams[0])
	kit = ArtKit.new()
	kit.lib = lib
	root.add_child(kit)
	await process_frame
	var races := {}
	for p in [["human", "tiny vikings"], ["frog", "angry swamp frogs with reed spears"], ["centaur", "centaur romans"],
			["beetle", "spooky beetle knights"], ["pegasus", "pegasus riding spartans"]]:
		races[p[0]] = gen.generate(p[1], rules)
	# The units on show: each race's spear line (melee), the humans' archer, the pegasus lancer.
	var picks := {}
	for k in races:
		picks[k] = {"melee": _unit(races[k], "spear")}
	picks.human.ranged = _unit(races.human, "archer")
	picks.pegasus.melee = _unit(races.pegasus, "large")
	var pb := PartBaker.new()
	pb.art_scale = ArtKit.ART_SCALE * ArtKit.UNIT_SCALE
	pb.bands = ArtKit.UNIT_BANDS
	root.add_child(pb)
	for k in picks:
		for role in picks[k]:
			var u: Dictionary = picks[k][role]
			var probe := UnitView.new()
			probe.build(u.recipe, lib, team, u.eval.speed)
			for ps in probe.find_children("*", "Node2D", true, false):
				if ps is PartShape and ps.part_id != "":
					await pb.bake(ps.part_id, ps.shapes, ps.colours)
			probe.free()
			var colours := UnitView.colours_for(lib, u.recipe.skin, u.recipe.family, team)
			if not u.recipe.has("mount") or u.recipe.mount.get("fused", false):
				for h in UnitView.WORK_HOLDS:
					await pb.bake(u.recipe.body + "@" + h, lib.part(u.recipe.body).shapes, colours)
		print("baked ", k)
	pb.queue_free()
	PartShape.bake_flat("unit_shadow", UnitView.SHADOW_SHAPES, UnitView.SHADOW_COLOURS, ArtKit.ART_SCALE * ArtKit.UNIT_SCALE)
	kit.rebuild_atlas()
	for k in ["human", "frog", "centaur", "beetle"]:
		var rows := [["T1  step-in: lunge, the near leg steps, the arm swings through its holds", _t1],
			["T2  swing only: the holds and the weapon, feet still", _t2], ["T3  as now: the weapon twitches", _t3]]
		if picks[k].has("ranged"):
			rows += [["R1  draw and loose: lean back, bow up, snap forward on the shot", _r1], ["R2  as now: nothing", _r2]]
		await _sheet("attack_" + k, races[k].name, picks[k], rows, 5)
	for k in ["human", "frog", "centaur", "beetle", "pegasus"]:
		await _sheet("death_" + k, races[k].name, picks[k], [["D1  topple (as now)", _d1], ["D2  crumple: legs fold, body sinks, head drops", _d2],
			["D3  by shape: bipeds topple back with a bounce, hoppers flop belly-up, legs fold, flyers drop first", _d3]], DEATH_T.size())
	quit()


static func _unit(race: Dictionary, slot: String) -> Dictionary:
	for u in race.units:
		if u.recipe.slot == slot:
			return u
	return race.units[1]


func _sheet(name: String, race_name: String, picks: Dictionary, rows: Array, frames: int) -> void:
	for n in root.get_children():
		if n != kit:
			n.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(world)
	var labels := Node2D.new()
	root.add_child(labels)
	var y := 70.0
	for row in rows:
		var ranged: bool = row[0].begins_with("R")
		var u: Dictionary = picks.ranged if ranged else picks.melee
		var l := Label.new()
		l.text = "%s   %s" % [race_name, row[0]]
		l.position = Vector2(20, y - 60)
		l.add_theme_font_size_override("font_size", 16)
		labels.add_child(l)
		for f in frames:
			var v := UnitView.new()
			v.build(u.recipe, lib, team, u.eval.speed)
			v.scale = Vector2.ONE * ArtKit.UNIT_SCALE
			v.pose_steps = 0
			var gap := 230.0 if u.recipe.has("mount") and not u.recipe.mount.get("fused", false) else 130.0
			v.position = Vector2(80 + f * gap, y + 110) / ZOOM
			v.idle_wait = 1000.0
			v.time = 0.3
			world.add_child(v)
			v._process(0.0)
			row[1].call(v, f, frames)
			v.set_process(false)
		y += 175
	for f in 12:
		await process_frame
	var path := out_dir.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


# ------------------------------------------------------------------ attacks (a: 0..1 across the blow)

static func _is_spear(v) -> bool:
	return v.weapon != null and (v.weapon.part_id.contains("spear") or v.weapon.part_id.contains("pike") or v.weapon.part_id.contains("dory") or v.weapon.part_id.contains("lance"))


func _t1(v, f: int, n: int) -> void:
	var a := float(f) / (n - 1)
	var k := sin(a * PI)
	v.bob.position.x += 4.0 * k
	v.bob.rotation += 0.14 * k
	if v.legs.size() == 2:
		v.legs[0].node.rotation = -0.5 * k
		v.legs[1].node.rotation = 0.3 * k
	elif v.legs.size() >= 4:
		for leg in v.legs:
			leg.node.rotation = (0.25 if leg.node.position.x > 0.0 else -0.2) * k
	if v.harnessed:
		if v.head_node:
			v.head_node.rotation = 0.6 * k   # a butt
		return
	_swing(v, a)


func _t2(v, f: int, n: int) -> void:
	var a := float(f) / (n - 1)
	if v.harnessed:
		if v.head_node:
			v.head_node.rotation = -0.4 * sin(a * PI) + 0.8 * maxf(0.0, a - 0.5) * 2.0 * (1.0 - a) * 2.0
		return
	_swing(v, a)


func _swing(v, a: float) -> void:
	if v.weapon == null:
		return
	if _is_spear(v):
		v.set_hold("reach" if 0.35 < a and a < 0.85 else "low")
		v.weapon.position = v.weapon_rest + Vector2(6.0, -0.5) * sin(a * PI)
		return
	if a < 0.35:
		v.set_hold("raise")
		v.weapon.rotation = v.weapon_rot - 1.1 * (a / 0.35)
	elif a < 0.8:
		v.set_hold("reach")
		v.weapon.rotation = v.weapon_rot + lerpf(-0.4, 0.9, (a - 0.35) / 0.45)
	else:
		v.set_hold("low")
		v.weapon.rotation = v.weapon_rot + lerpf(0.9, 0.0, (a - 0.8) / 0.2)


func _t3(v, f: int, n: int) -> void:
	var k := sin(float(f) / (n - 1) * PI)
	if v.weapon:
		v.weapon.position = v.weapon_rest + Vector2(6.0 * k, -2.0 * k)
		v.weapon.rotation = v.weapon_rot - 0.4 * k


func _r1(v, f: int, n: int) -> void:
	var a := float(f) / (n - 1)
	if a < 0.5:
		var q := a / 0.5
		v.bob.rotation -= 0.18 * q
		v.bob.position.x -= 3.0 * q
		if v.weapon:
			v.weapon.rotation = v.weapon_rot - 0.35 * q
			v.weapon.position = v.weapon_rest + Vector2(-2.0, -1.5) * q
		if v.legs.size() == 2:
			v.legs[1].node.rotation = 0.3 * q
	else:
		var q := (a - 0.5) / 0.5
		v.bob.rotation += 0.12 * (1.0 - q)
		v.bob.position.x += 3.0 * (1.0 - q)
		if v.weapon:
			v.weapon.rotation = v.weapon_rot + 0.2 * (1.0 - q)
			v.weapon.position = v.weapon_rest + Vector2(2.0, 0.0) * (1.0 - q)


func _r2(_v, _f: int, _n: int) -> void:
	pass


# ------------------------------------------------------------------ deaths (t in seconds)

static func _fade(v, t: float) -> void:
	var fade := clampf((t - 0.6) / 1.3, 0.0, 1.0)
	v.visual.modulate.a = 1.0 - fade * 0.8


static func _hip(v) -> float:
	var h := 6.0
	for leg in v.legs:
		h = maxf(h, -leg.rest.y)
	return h


func _d1(v, f: int, _n: int) -> void:
	var t: float = DEATH_T[f]
	var a := minf(t / 0.35, 1.0)
	v.visual.rotation = a * a * 1.45
	_fade(v, t)


func _d2(v, f: int, _n: int) -> void:
	var t: float = DEATH_T[f]
	_crumple(v, minf(t / 0.4, 1.0))
	_fade(v, t)


static func _crumple(v, a: float) -> void:
	var e := a * a * (3.0 - 2.0 * a)
	for leg in v.legs:
		leg.node.scale.y = 1.0 - 0.7 * e
	v.bob.position.y += _hip(v) * 0.7 * e
	v.bob.rotation += 0.3 * e
	if v.head_node:
		v.head_node.rotation = 0.6 * e
	if v.seat_node:
		v.seat_node.rotation = 0.7 * e   # the rider slumps forward over the neck


func _d3(v, f: int, _n: int) -> void:
	var t: float = DEATH_T[f]
	if v.gait.get("hop", false):
		# A hopper flops onto its back: a last little hop, over, and down.
		var a := minf(t / 0.45, 1.0)
		var h := _hip(v) + 8.0
		v.visual.rotation = -PI * a
		v.visual.position.y = -h * (1.0 - cos(PI * a)) * 0.5 - sin(a * PI) * 5.0
	elif v.flying:
		var drop := minf(t / 0.3, 1.0)
		v.bob.position.y = lerpf(v.bob.position.y, 0.0, drop)
		var a := clampf((t - 0.3) / 0.35, 0.0, 1.0)
		v.visual.rotation = a * a * 1.45
	elif v.legs.size() >= 4:
		_crumple(v, minf(t / 0.4, 1.0))
	else:
		# A biped topples backwards, away from the blow, and bounces once.
		var a := minf(t / 0.4, 1.0)
		var e := 1.0 - (1.0 - a) * (1.0 - a)
		v.visual.rotation = -1.45 * e + 0.12 * sin(clampf((t - 0.4) / 0.25, 0.0, 1.0) * PI)
		if v.legs.size() == 2:
			v.legs[0].node.rotation = -0.4 * e
			v.legs[1].node.rotation = 0.2 * e
	_fade(v, t)
