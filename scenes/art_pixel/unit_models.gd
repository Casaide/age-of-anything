extends RefCounted
## Hand-built 3D models for unit parts, keyed by part id, using the 2D parts as
## design reference. Each model is in its part's frame (part units, about one 2D
## pixel each): x = the way the unit faces, y = up, z = towards the viewer's side.
## Bodies and heads also declare 3D sockets (and bodies their leg hips); the baker
## projects them into 2D so UnitView composes the baked parts as usual.
## Surfaces use authored, tileable textures (assets/art/textures/) mapped
## triplanar and tinted by the race's colours; features (eyes, mouths, leaves,
## lily pads) are authored decals.

const TEX_DIR := "res://assets/art/textures/"

static var tex_cache := {}   # shared by every baker (each used to rasterise the SVGs again)
var hold := "low"   # the body being built: how its near hand holds the weapon (see arm_pose)


## Part ids may carry a hold after "@" (a body posed for its weapon: "body.frog@throw"), and
## body armour its wearer after "~" ("armour.leather~body.rat": baked on that body).
func has(id: String) -> bool:
	if _is_engine(id):
		return _siege().has(id)
	var base := id.get_slice("~", 0).get_slice("@", 0)
	if CreatureKit.has_part(base):
		return true
	if Mods.glb_parts.has(base):
		return true
	var fn := "_" + base.replace(".", "_")
	return has_method(fn) or extra.any(func(e): return e.has_method(fn)) or (base.begins_with("leg.beast_") or base.begins_with("head.beast_")) and _siege().has_method(fn)


## Creature-kit parts (scenes/art_pixel/creature_kit.gd: a skeleton in data) and concept model files
## staged by tests and sheets (data/later/*.json "models": e.g. a bear's helmet) build here too.
const CreatureKit := preload("res://scenes/art_pixel/creature_kit.gd")
static var extra := []   # instances of unit_models subclasses with more parts (CreatureKit.stage adds them; so do mods)
const Mods := preload("res://src/mods.gd")   # (a mod's part may be a .glb: Mods.glb_parts)
var _kit = null


## Siege engines ("siege.<engine>.<take>") are modelled in siege_models.gd (which builds on this
## file's helpers), loaded when first asked for.
var _siege_models = null


func _siege():
	if _siege_models == null:
		_siege_models = load("res://scenes/art_pixel/siege_models.gd").new()
	return _siege_models


static func _is_engine(id: String) -> bool:
	return (id.begins_with("siege.") and id.count(".") == 2) or id.begins_with("shot.")   # (and what engines throw: siege_models.gd)


## Body armour modelled for one body in that body's space (tools/blender/human_armour.py:
## armour_<kind>_<creature>.glb), or {} to fit the generic model at bake time.
## A draught harness has no model off its wearer: it's always fitted on the beast (fitted below).
func _harness_draught(_c: Dictionary) -> Dictionary:
	return {"node": Node3D.new()}


func fitted(armour_id: String, body_id: String, colours: Dictionary) -> Dictionary:
	if armour_id.begins_with("harness."):   # a draught harness, fitted on its beast (siege_models.gd)
		return _siege().harness_fitted(armour_id, body_id, colours)
	var kind := armour_id.trim_prefix("armour.")
	var name := "armour_%s_%s" % [kind, body_id.trim_prefix("body.")]
	if not FileAccess.file_exists("res://assets/models/%s.glb" % name):
		return {}
	var main := surf(kind, Color.WHITE, 4.0) if kind != "leather" else surf("leather", Color.WHITE, 5.0)
	return {"node": glb(name, {kind: main, "trim": surf("leather", Color("#5a3a20"), 3.0)})}


## How a leg model sits at its hip (anchor [hip, phase, side, flip, hind]). Legs are modelled for
## the near side (+z) pointing forward: a leg on the far side (hip z < 0) is mirrored across the
## body (its sprawl goes out to its own side, not under the belly), and a flipped rear leg is
## mirrored fore and aft. Legs baked at each hip (parts.json "cut": ["legs"]) bake in this turn;
## uncut legs are one sprite, flipped in 2D, so only legs the same on both sides may be uncut
## (the placement check, A2 "one-sided legs baked at each hip").
static var mirror_legs := true   # the placement check's fixtures turn it off to show the newt as it was


static func leg_basis(a: Array, cut: bool) -> Basis:
	var flip := a.size() > 3 and int(a[3]) == 1
	if not mirror_legs:
		return Basis.IDENTITY
	if not cut:
		return Basis.from_scale(Vector3(-1, 1, 1)) if flip else Basis.IDENTITY
	var side := -1.0 if float(a[0].z) < 0.0 else 1.0
	var fan := Basis(Vector3.UP, deg_to_rad(float(a[5])) * -side) if a.size() > 5 else Basis.IDENTITY   # a[5]: turned out (degrees, + forward)
	return fan * Basis.from_scale(Vector3(-1.0 if flip else 1.0, 1.0, side))


## Where a body sits on a saddle: its "sit" socket, else the middle of its hips (a rider's hips go
## on its mount's seat: UnitView.build, the placement check).
static func hips(spec: Dictionary) -> Vector3:
	if spec.get("sockets", {}).has("sit"):
		return spec.sockets.sit
	var sum := Vector3.ZERO
	for a in spec.get("anchors", []):
		sum += a[0]
	return sum / maxf(1.0, spec.get("anchors", []).size())


## {node: Node3D, sockets: {name: Vector3}, anchors: [[Vector3 hip, phase, z]]}
func build(id: String, colours: Dictionary) -> Dictionary:
	if _is_engine(id):
		return _siege().build(id, colours)
	var own := id.get_slice("~", 0)   # (what follows "~" is the body it's baked on or cut by)
	hold = own.get_slice("@", 1) if "@" in own else "low"   # a cut leg keeps its pose: "leg.cat@w3_8~body.cat^1"
	var base := own.get_slice("@", 0)
	if CreatureKit.has_part(base):
		if _kit == null:
			_kit = CreatureKit.new()
		return _kit.build(self, base, colours)
	if Mods.glb_parts.has(base):
		return {"node": glb_file(Mods.glb_parts[base], mod_materials(Mods.glb_parts[base], colours))}
	var fn := "_" + base.replace(".", "_")
	if not has_method(fn) and (base.begins_with("leg.beast_") or base.begins_with("head.beast_")):
		return _siege().call(fn, colours)   # a war beast's legs and head (siege_models.gd: they share its builders)
	if not has_method(fn):
		for e in extra:
			if e.has_method(fn):
				e.hold = hold
				return e.call(fn, colours)
	return call(fn, colours)


## The near arm's elbow and hand for the body's hold, from its shoulder, its resting
## elbow and hand, and its head socket. The weapon is built around its grip at the
## hand, so the hand always holds it:
## low (spears, swords, tools), throw (a javelin raised over the shoulder), mouth (a
## blowgun at the lips), overhead (a sling whirled above), draw (a bow at arm's length),
## shoulder (a pike), aim (a crossbow or musket held forward).
const INK := Color("#2a1a12")
const REACH_FLOOR := 8.0   # a reaching hand comes no lower than this (part units, before a body's scale)


func arm_pose(sh: Vector3, elbow: Vector3, hand: Vector3, head: Vector3) -> Array:
	var z := sh.z
	match hold:
		"throw":   # (hands out to the side of the head: nearer, the arm and javelin went through it)
			return [sh + Vector3(1.0, 3.5, 2.2), sh + Vector3(-2.5, 9.0, 2.4)]
		"mouth":
			var at := Vector3(head.x + 6.0, head.y + 1.0, z * 0.45)
			return [Vector3(sh.x + 4.5, sh.y - 3.5, z + 1.2), at]
		"overhead":
			return [sh + Vector3(1.5, 4.5, 2.0), sh + Vector3(0.5, 9.0, 2.2)]
		"draw":
			return [sh + Vector3(4.5, 0.2, 1.0), sh + Vector3(9.5, 0.6, 0.8)]   # (at shoulder height: lower, a frog's bow went into the ground)
		"shoulder":
			return [sh + Vector3(2.0, -4.5, 2.2), sh + Vector3(3.5, -2.0, 2.4)]   # (out from the flank: nearer, the pike's butt went through a frog's body)
		"aim":
			return [sh + Vector3(3.0, -3.0, 1.4), sh + Vector3(7.5, -1.0, 0.6)]
		"reach":   # work poses (animation concepts, 2026-10-12): the hand out and down to the work...
			var to := sh + Vector3(6.5, -6.5, 1.8)   # (out from the hip: nearer, the tool's handle went through it)
			to.y = maxf(to.y, REACH_FLOOR)   # (a frog's low shoulders drove the tool into the ground)
			return [sh + Vector3(3.5, -3.0, 1.3), to]
		"raise":   # ...and wound up high behind the shoulder, the tool about to come down (out beside the head)
			return [sh + Vector3(-1.0, 3.5, 2.2), sh + Vector3(-2.5, 8.0, 2.6)]
		"thrust":  # a spear driven straight forward at chest height (D-106; Dominic: rats "just tap")
			return [sh + Vector3(4.0, -0.5, 1.4), sh + Vector3(9.0, -1.0, 0.9)]
	return [elbow, hand]


# ------------------------------------------------------------------ materials

## A texture by name (assets/art/textures/<name>.svg), or by its path without ".svg" (a mod's own:
## "res://mods/<id>/textures/<name>"; mod_tex() in a mod's model script makes the path).
func tex(name: String) -> Texture2D:
	if not tex_cache.has(name):
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string((name if "://" in name else TEX_DIR + name) + ".svg"), 1.0)
		img.generate_mipmaps()
		tex_cache[name] = ImageTexture.create_from_image(img)
	return tex_cache[name]


## A tileable texture wrapped over any shape (triplanar), tinted.
func surf(name: String, tint := Color.WHITE, units := 10.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true   # blobs are scaled unit spheres: in local space a whole body would get a sliver of texture
	m.uv1_triplanar_sharpness = 2.0
	m.uv1_scale = Vector3.ONE / units
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func plain(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.2
	return m


## A decal: an authored picture with crisp alpha on a quad.
func decal(name: String, w: float, h: float, pos: Vector3, facing: Vector3, lit := true, up := Vector3.UP, tint := Color.WHITE) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not lit:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.set_meta("decal", name)   # (the placement check finds eyes by it)
	mi.position = pos
	var f := facing.normalized()
	var u := up if absf(f.dot(up)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-f, u)   # a QuadMesh faces +z; point that along `facing`
	return mi


# ------------------------------------------------------------------ shapes

## The point on an ellipsoid's surface in direction `dir` from its centre, nudged out a little.
static func on_surface(centre: Vector3, radii: Vector3, dir: Vector3, out := 0.25) -> Vector3:
	var d := dir.normalized()
	var k := 1.0 / sqrt(pow(d.x / radii.x, 2) + pow(d.y / radii.y, 2) + pow(d.z / radii.z, 2))
	return centre + d * (k + out)

func blob(r: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 32
	s.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.scale = r
	mi.rotation_degrees = rot
	mi.position = pos
	return mi


## A rod from a to b (radius r1 at a, r2 at b), with rounded ends.
func rod(a: Vector3, b: Vector3, r1: float, r2: float, m: Material, caps := true) -> Node3D:
	var n := Node3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r1
	c.top_radius = r2
	c.height = a.distance_to(b)
	c.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, d)) if not d.is_equal_approx(Vector3.DOWN) else Basis(Vector3.RIGHT, PI)
	n.add_child(mi)
	if caps:
		n.add_child(blob(Vector3.ONE * r1, m, a))
		n.add_child(blob(Vector3.ONE * r2, m, b))
	return n


func ring(inner: float, outer: float, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	return mi


## A team-colour kerchief knotted at the neck, with a tail hanging in front. It goes in
## the front layer, so armour never hides it: every infantry body shows its team.
func kerchief(into: Node3D, c: Dictionary, neck: Vector3, r: float, lean := 0.0) -> void:
	var team := surf("cloth", c.team, 3.0)
	into.add_child(ring(r * 0.75, r * 1.3, team, neck, Vector3(0, 0, lean), Vector3(1, 1.6, 1)))
	var knot := neck + Vector3(r * 0.95, -r * 0.2, r * 0.35)
	into.add_child(blob(Vector3(1.1, 1.1, 1.0) * r * 0.32, team, knot))
	into.add_child(slab([Vector2(0, 0), Vector2(r * 0.45, -r * 0.2), Vector2(r * 0.25, -r * 1.3), Vector2(-r * 0.15, -r * 1.1)], 0.5, team, knot + Vector3(-r * 0.1, -r * 0.1, 0.3)))


# ------------------------------------------------------------------ frog

## Frog helpers (the crouched leaper, picked by Dominic 2026-10-11).
## The frog's skin, wetter and more saturated than today's: poison-dart colours.
const FROG_SCALE := 1.25   # the crouched frog is built small; infantry of every creature stand one height


## Scale a built part about its origin, with its sockets and anchors (front layer too).
func _scaled(spec: Dictionary, k: float) -> Dictionary:
	for key in ["node", "front"]:
		if spec.get(key) != null:
			var wrap := Node3D.new()
			wrap.scale = Vector3.ONE * k
			wrap.add_child(spec[key])
			spec[key] = wrap
	if spec.has("sockets"):
		for name in spec.sockets:
			spec.sockets[name] *= k
	if spec.has("anchors"):
		spec.anchors = spec.anchors.map(func(a): return [a[0] * k] + a.slice(1))
	return spec


func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.25 + 0.05), minf(1.0, c.v * 1.08 + 0.02))


func _frog_mats(c: Dictionary) -> Array:
	var skin := surf("frog_skin", _vivid(c.skin), 7.0)
	skin.roughness = 0.35   # wet
	skin.metallic_specular = 0.6
	var belly := surf("frog_belly", c.skin2.lightened(0.25), 6.0)
	return [skin, belly]


## Fingers: three long digits ending in round pads, spread from a hand.


func _frog_hand(into: Node3D, hand: Vector3, dir: Vector3, skin: Material, pad: Material) -> void:
	into.add_child(blob(Vector3(1.2, 0.9, 1.2), skin, hand))
	for f in 3:
		var tip := hand + dir * 2.6 + Vector3(0, 0, (f - 1) * 1.3)
		into.add_child(rod(hand, tip, 0.42, 0.38, skin, false))
		into.add_child(blob(Vector3(0.75, 0.6, 0.75), pad, tip))


## Eye domes on top of the head, each with an eye decal looking out and a little forward.


func _frog_eyes(n: Node3D, at: Vector3, spread: float, r: float, skin: Material) -> void:
	for side in [1, -1]:
		var dome := at + Vector3(0, 0, spread * side)
		n.add_child(blob(Vector3(r, r * 1.05, r), skin, dome))
		var look := Vector3(0.6, 0.35, 0.75 * side)
		n.add_child(decal("frog_eye", r * 1.45, r * 1.45, on_surface(dome, Vector3(r, r * 1.05, r), look, 0.1), look, false))


# --- A: the crouched leaper. Back sloping up from the rump to the head, front arms braced on the
# ground, hind legs folded high beside the body, ready to spring.


func _body_frog(c: Dictionary) -> Dictionary:
	return _scaled(_body_frog_built(c), FROG_SCALE)


func _body_frog_built(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(8.2, 5.6, 6.6), m[0], Vector3(-0.5, 9.5, 0), Vector3(0, 0, 32)))
	n.add_child(blob(Vector3(6.0, 3.8, 5.0), m[1], Vector3(1.6, 8.0, 0), Vector3(0, 0, 32)))
	var front := Node3D.new()
	var near_hand := Vector3.ZERO
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(4.2, 11.0, 4.6 * side)
		var elbow := Vector3(6.0, 6.5, 5.6 * side)
		var hand := Vector3(8.0, 1.2, 5.4) if side == 1 else Vector3(8.0, 4.5, -5.4)
		if side == 1:
			var pose := arm_pose(sh, elbow, Vector3(8.5, 8.5, 7.8), Vector3(8.4, 13.5, 0))   # (hand out from the flank: at z 5.4 a lance's butt ran through it)   # (the "head" a blowgun is held 6 in front of: the wide mouth's front; the head socket put it inside the head)
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 1.5, 1.3, m[0]))
		into.add_child(rod(elbow, hand, 1.3, 1.1, m[0]))
		_frog_hand(into, hand, Vector3(1, -0.15, 0) if side == -1 else Vector3(0.8, 0.5, 0), m[0], m[1])
	kerchief(front, c, Vector3(5.0, 12.2, 0), 3.2, 40)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(6.6, 13.5, 0), "hand_r": near_hand, "hand_l": Vector3(8.0, 4.5, -5.4),   # (head at 7, 14 sat a unit off the body; the far hand at 1.2 put a staff a unit into the ground)
		"torso": Vector3(1.0, 10.0, 0), "back": Vector3(-4.5, 13.0, 0), "sit": Vector3(-0.5, 3.6, 0)},
		"anchors": [[Vector3(-4.5, 6.0, -5.2), 0.0, -1], [Vector3(-4.5, 6.0, 5.2), PI, 1]],
		"torso_scale": Vector2(0.75, 0.6)}


## A long hind leg folded up beside the body: thigh forward and up, shin back down, a long foot.

func _head_frog(c: Dictionary) -> Dictionary:
	return _scaled(_head_frog_built(c), FROG_SCALE)


func _head_frog_built(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	n.add_child(blob(Vector3(5.8, 3.0, 5.4), m[0], Vector3(2.4, 2.4, 0)))
	n.add_child(blob(Vector3(4.6, 1.6, 4.4), m[1], Vector3(2.8, 0.9, 0)))           # the throat
	n.add_child(rod(Vector3(7.6, 1.9, -3.6), Vector3(7.9, 1.9, 0), 0.32, 0.32, plain(INK)))   # the mouth line, round the front
	n.add_child(rod(Vector3(7.9, 1.9, 0), Vector3(7.6, 1.9, 3.6), 0.32, 0.32, plain(INK)))
	_frog_eyes(n, Vector3(3.2, 5.2, 0), 3.0, 2.2, m[0])
	# The top sits behind the eyes, and gear is sized to this small head: it never covers them.
	return {"node": n, "sockets": {"top": Vector3(-0.6, 5.0, 0)}, "gear_scale": 0.62}


# --- B: the slim tree frog. Upright but lean, long limbs, big toe pads, eyes bulging at the sides.

func _leg_frog(c: Dictionary) -> Dictionary:
	return _scaled(_leg_frog_built(c), FROG_SCALE)


func _leg_frog_built(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _frog_mats(c)
	var knee := Vector3(5.5, 3.8, 1.6)
	var ankle := Vector3(-2.0, -3.2, 1.2)
	n.add_child(rod(Vector3.ZERO, knee, 2.6, 1.8, m[0]))
	n.add_child(rod(knee, ankle, 1.7, 1.1, m[0]))
	var heel := ankle + Vector3(0, -2.4, 0)
	n.add_child(rod(ankle, heel, 1.1, 0.9, m[0]))
	for t in 4:
		var toe := heel + Vector3(6.5, -0.4, (t - 1.5) * 1.6)
		n.add_child(rod(heel, toe, 0.5, 0.42, m[0], false))
		n.add_child(blob(Vector3(0.8, 0.55, 0.8), m[1], toe))
	return {"node": n}


## A wide, flat head: eyes high on top, a long mouth line, a pale throat.

func _tool_basket(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var weave := surf("wicker", Color.WHITE, 4.0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.6
	cyl.bottom_radius = 3.6
	cyl.height = 6.0
	cyl.radial_segments = 20
	var b := MeshInstance3D.new()
	b.mesh = cyl
	b.material_override = weave
	b.position = Vector3(1.0, -5.5, 0.5)
	n.add_child(b)
	n.add_child(ring(4.3, 5.1, surf("bark_plate", Color("#c8a070"), 6.0), Vector3(1.0, -2.5, 0.5)))
	n.add_child(ring(4.3, 4.9, surf("wicker", Color("#d8b880"), 3.0), Vector3(1.0, -2.0, 0.5), Vector3(90, 0, 0), Vector3(1, 1, 0.9)))
	for k in 6:
		n.add_child(blob(Vector3(1.1, 0.8, 1.1), plain(Color("#e0607f")), Vector3(-1.5 + k * 1.0, -2.2, -1.5 + (k % 3) * 1.4)))
	return {"node": n}


func _weapon_spear_reed(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)     # held upright: a spear stands tall
	var b := Vector3(6, 19, 0)
	n.add_child(rod(a, b, 1.05, 1.0, surf("reed_stalk", Color.WHITE, 5.0), false))
	var d := (b - a).normalized()
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 3.4   # a big, pale blade: it must read as a spear, not a blowgun
	head.height = 9.5
	head.radial_segments = 4
	var tip := MeshInstance3D.new()
	tip.mesh = head
	tip.material_override = surf("bone", Color.WHITE, 4.0)
	tip.position = b + d * 4.0
	tip.basis = Basis(Quaternion(Vector3.UP, d)).scaled(Vector3(1.0, 1.0, 0.45))
	n.add_child(tip)
	for k in 3:
		n.add_child(ring(0.7, 1.1, surf("leather", Color.WHITE, 3.0), b - d * (0.6 + k * 0.9), Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return {"node": n}


func _armour_bark(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(9.0, 8.4, 10.8), surf("bark_plate", Color.WHITE, 9.0), Vector3(2.0, 0.5, 0), Vector3(0, 0, -10)))
	for side in [1, -1]:
		n.add_child(ring(9.6, 10.6, surf("leather", Color.WHITE, 4.0), Vector3(1.5, 1.0, 0), Vector3(0, 0, 70 * side), Vector3(1, 1, 1.0)))
	n.add_child(blob(Vector3(1.2, 1.2, 0.6), plain(Color("#c08a3e")), Vector3(10.6, 2.0, 2.0)))
	return {"node": n}


func _shield_lilypad(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("lily_pad", 15.0, 15.0, Vector3(4.0, 0.5, 2.0), Vector3(1.0, 0.1, 0.45)))
	return {"node": n}


func _helm_acorn(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(6.6, 3.8, 6.6), surf("acorn_cap", Color.WHITE, 3.5), Vector3(0, 0.6, 0)))
	n.add_child(rod(Vector3(0, 3.8, 0), Vector3(0.8, 6.8, 0), 0.8, 0.55, surf("bark_plate", Color("#8a6a40"), 3.0)))
	return {"node": n}


func _hat_leaf(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("leaf", 10.0, 13.0, Vector3(0, 2.2, 0), Vector3(0.25, 1.0, 0.35), true, Vector3.RIGHT))
	n.add_child(rod(Vector3(-5.5, 1.5, -0.5), Vector3(-7.5, 3.0, -0.8), 0.35, 0.3, plain(Color("#6b4a2a"))))
	return {"node": n}


func _cape_leaf(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(decal("leaf", 13.0, 17.0, Vector3(-3.0, -6.0, 1.5), Vector3(-0.5, 0.2, 0.85), true, Vector3(0.4, 1, 0)))
	return {"node": n}


## An extruded outline (blades, spearheads): points in the xy plane, thickness along z.
func slab(points: Array, thick: float, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var pts := PackedVector2Array(points)
	var tris := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5
	for face in [1.0, -1.0]:
		for k in range(0, tris.size(), 3):
			var order := [tris[k], tris[k + 1], tris[k + 2]] if face > 0 else [tris[k], tris[k + 2], tris[k + 1]]
			for i in order:
				st.set_normal(Vector3(0, 0, face))
				st.add_vertex(Vector3(pts[i].x, pts[i].y, h * face))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var nrm := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		for v in [Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.position = pos
	return mi


# ------------------------------------------------------------------ rat

static var rat_hunch := 15.0   # degrees the rat's body leans forward (the placement check's fixtures set -15: as it was)
const RAT_HAND_L := Vector3(8.3, 18.5, -4.6)   # the shield hand, up at the chest (lower, a riding rat's shield went into its mount)


func _body_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 7.0)
	var pink := surf("frog_belly", c.skin2, 6.0)
	# Lean and hunched (Dominic: "less fat"): a narrow body tilted forward, the belly showing in front.
	# (Forward is -15 about z: until 2026-10-13 it was +15, leaning back, so the head on its socket
	# floated ahead of the shoulders with a gap at the neck and the body read as a lump behind it.)
	n.add_child(blob(Vector3(5.4, 10.4, 5.0), fur, Vector3(0.2, 15, 0), Vector3(0, 0, -rat_hunch)))
	n.add_child(blob(Vector3(3.4, 7.0, 3.6), pink, Vector3(2.6, 13.6, 0.4), Vector3(0, 0, -rat_hunch)))
	# A long tail curling behind, thinning to a point.
	var pts := [Vector3(-5, 7, 0), Vector3(-11, 4.5, 1.5), Vector3(-16.5, 5.5, 2.5), Vector3(-19.5, 9.5, 3.0), Vector3(-19, 14, 3.0), Vector3(-16.5, 16, 2.5)]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], 1.25 - k * 0.17, 1.25 - (k + 1) * 0.17, pink))
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(5.6, 19.5, 4.4 * side)   # at the hunched chest's front (on the leaning-back body they sat at 3.6)
		var elbow := Vector3(6.6, 16.5, 5.8 * side)
		var hand := Vector3(8.6, 15.5, 4.6 * side) if side == 1 else RAT_HAND_L
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(4, 24.5, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(rod(sh, elbow, 1.9, 1.7, fur))
		into.add_child(rod(elbow, hand, 1.7, 1.5, fur))
		into.add_child(blob(Vector3(1.7, 1.4, 1.7), pink, hand))
	kerchief(front, c, Vector3(3.2, 22.2, 0), 3.0, 15)   # a small scarf at the neck (a big one read as a bib)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(4, 24.5, 0), "hand_r": near_hand, "hand_l": RAT_HAND_L,
		"torso": Vector3(1.4, 17.5, 0), "back": Vector3(-5.2, 19.5, 0)},   # (the hunched back slopes out below: a cape at -3.6 hung into it)
		"anchors": [[Vector3(-0.5, 7.0, -3.2), 0.0, -1], [Vector3(-0.5, 7.0, 3.2), PI, 1]],   # (at 6 the hips hung under the belly, the feet a unit into the ground)
		"torso_scale": Vector2(0.58, 0.74), "torso_tilt": -rat_hunch,   # armour leans with the hunch
		"torso_fit": Vector3(0.7, 0.76, 0.6)}   # armour (built ~1.6x) a little bigger than the body all round, so it wraps it


func _head_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 6.0)
	var pink := surf("frog_belly", c.skin2, 5.0)
	var skull_c := Vector3(1, 4.5, 0)
	var skull_r := Vector3(5.2, 4.8, 4.6)
	n.add_child(blob(skull_r, fur, skull_c))
	n.add_child(rod(Vector3(3, 4, 0), Vector3(11, 2.6, 0), 3.4, 1.1, fur))   # the snout
	n.add_child(blob(Vector3(1.3, 1.1, 1.3), plain(Color("#e8909c")), Vector3(11.4, 2.7, 0)))
	n.add_child(blob(Vector3(0.6, 1.0, 1.4), plain(Color("#f4f0e0")), Vector3(9.6, 0.9, 0)))   # buck teeth
	for side in [1, -1]:
		var look := Vector3(0.5, 0.35, 0.8 * side)
		n.add_child(decal("rat_eye", 2.6, 2.6, on_surface(skull_c, skull_r, look, 0.1), look, false))
		n.add_child(blob(Vector3(0.8, 4.0, 3.6), fur, Vector3(-1.2, 9.0, 3.4 * side), Vector3(0, 20 * side, -10)))
		n.add_child(blob(Vector3(0.5, 3.0, 2.6), pink, Vector3(-0.7, 9.0, 3.6 * side), Vector3(0, 20 * side, -10)))
		for w in 3:
			n.add_child(rod(Vector3(9.5, 2.8, 1.2 * side), Vector3(12.5, 2.2 + w * 1.0, (3.5 + w * 0.4) * side), 0.12, 0.08, plain(Color("#3a3430")), false))
	return {"node": n, "sockets": {"top": Vector3(0, 9.5, 0)}}


func _leg_rat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 6.0)
	var pink := surf("frog_belly", c.skin2, 5.0)
	n.add_child(blob(Vector3(2.8, 3.4, 2.6), fur, Vector3(0.3, -1.8, 0)))
	n.add_child(rod(Vector3(0.5, -3.5, 0), Vector3(0.2, -6.0, 0), 1.0, 0.8, pink))
	n.add_child(blob(Vector3(3.0, 0.6, 1.3), pink, Vector3(2.4, -6.4, 0)))
	for t in 3:
		n.add_child(blob(Vector3(0.5, 0.4, 0.4), pink, Vector3(5.3, -6.5, (t - 1) * 0.8)))
	return {"node": n}


func _tool_axe(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(3, 9.5, 0), 0.75, 0.7, surf("wood_grain", Color.WHITE, 6.0)))
	n.add_child(slab([Vector2(2.2, 9.0), Vector2(7.5, 10.5), Vector2(7.0, 4.5), Vector2(3.0, 6.5)], 0.9, surf("bronze", Color.WHITE, 4.0)))
	n.add_child(ring(0.6, 1.1, surf("leather", Color.WHITE, 3.0), Vector3(2.6, 8.0, 0), Vector3(0, 0, -17)))
	return {"node": n}


func _weapon_spear_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)
	var b := Vector3(6, 18.5, 0)
	n.add_child(rod(a, b, 0.85, 0.8, surf("wood_grain", Color.WHITE, 8.0), false))
	var d := (b - a).normalized()
	var ang := atan2(d.y, d.x)
	var blade := slab([Vector2(0, -1.6), Vector2(6.5, 0), Vector2(0, 1.6), Vector2(-1.2, 0)], 0.8, surf("bronze", Color.WHITE, 3.0))
	blade.position = b
	blade.rotation.z = ang
	n.add_child(blade)
	n.add_child(ring(0.7, 1.15, surf("bronze", Color.WHITE, 3.0), b - d * 0.4, Vector3(0, 0, rad_to_deg(ang) - 90)))
	return {"node": n}


func _shield_bottlecap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var face := Vector3(1.0, 0.1, 0.45).normalized()
	var holder := Node3D.new()
	holder.position = Vector3(3.0, 0.5, 1.5)
	holder.basis = Basis.looking_at(-face, Vector3.UP)   # local +z points along `face`
	n.add_child(holder)
	var iron := surf("iron", Color.WHITE, 4.0)
	var cap := CylinderMesh.new()
	cap.top_radius = 6.0
	cap.bottom_radius = 6.4
	cap.height = 1.6
	cap.radial_segments = 24
	var body := MeshInstance3D.new()
	body.mesh = cap
	body.material_override = iron
	body.rotation_degrees = Vector3(90, 0, 0)
	holder.add_child(body)
	for k in 21:   # the crimped rim
		var a := TAU * k / 21.0
		holder.add_child(blob(Vector3(0.75, 0.75, 0.9), iron, Vector3(cos(a) * 6.3, sin(a) * 6.3, 0.1)))
	var disc := CylinderMesh.new()
	disc.top_radius = 4.3
	disc.bottom_radius = 4.3
	disc.height = 0.3
	disc.radial_segments = 24
	var centre := MeshInstance3D.new()
	centre.mesh = disc
	centre.material_override = plain(c.team)
	centre.rotation_degrees = Vector3(90, 0, 0)
	centre.position = Vector3(0, 0, 0.85)
	holder.add_child(centre)
	holder.add_child(ring(4.2, 4.6, plain(c.team.darkened(0.4)), Vector3(0, 0, 0.9), Vector3(90, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ spider (a mount)

## Reared up (SG1, Dominic's pick): the abdomen low behind, the front body raised, the front
## pair of legs used as arms to hold the weapon and shield, six legs to walk on. A saddle cloth
## on the abdomen for a rider when it's ridden.
const SPIDER_FAN := [45.0, -60.0, -30.0]   # degrees each pair of legs turns out from straight across (front, middle, back)


func _body_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin, 6.0)
	var front := surf("rat_fur", c.skin2, 5.0)
	n.add_child(blob(Vector3(7.5, 6.0, 6.5), hair, Vector3(-7.5, 9.5, 0), Vector3(0, 0, 10)))      # abdomen, low
	n.add_child(blob(Vector3(5.0, 1.0, 5.4), plain(c.team), Vector3(-8.0, 15.2, 0), Vector3(0, 0, 10)))   # team saddle cloth on its back
	n.add_child(blob(Vector3(4.2, 6.0, 4.6), front, Vector3(1.5, 14.5, 0), Vector3(0, 0, -30)))   # the front body, reared up
	var limb := surf("rat_fur", c.skin, 4.0)
	var hand_r := Vector3(7.0, 17.5, 5.2)   # (held up, clear of the first walking pair: at 13.5 a lance ran through its thigh)
	var hand_l := Vector3(7.0, 17.5, -5.2)
	for side in [1, -1]:   # the front legs, used as arms
		var elbow := Vector3(5.5, 19.0, 6.0 * side)
		n.add_child(rod(Vector3(2.5, 18.0, 3.5 * side), elbow, 1.0, 0.85, limb))
		n.add_child(rod(elbow, hand_r if side == 1 else hand_l, 0.85, 0.6, limb))
	var hips := []
	var xs := [0.5, -2.5, -6.5]   # (the back pair at -5.5 crossed the middle pair's thighs)
	for k in 3:
		# Fanned out round the body (a spider's legs radiate: side by side, the back ones crossed),
		# hips up in the body (at 9.5 the feet were a unit into the ground).
		hips.append([Vector3(xs[k], 10.5, 3.5), k * 1.0, 1, 1 if k >= 1 else 0, false, SPIDER_FAN[k]])
		hips.append([Vector3(xs[k], 10.5, -3.5), k * 1.0 + PI, -1, 1 if k >= 1 else 0, false, SPIDER_FAN[k]])
	return {"node": n, "sockets": {"head": Vector3(3.5, 20.0, 0), "hand_r": hand_r, "hand_l": hand_l,
		"torso": Vector3(1.5, 14.5, 0), "back": Vector3(-14.5, 14.5, 0), "seat": Vector3(-8.0, 16.5, 0), "wings": Vector3(-1.0, 17.0, 0),   # (back at the rump's end: at (-7, 14) a cape hung down through the abdomen)
		"sit": Vector3(-4.0, 4.5, 0)},
		"anchors": hips, "torso_scale": Vector2(0.5, 0.6)}


func _head_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin2, 4.0)
	var head_c := Vector3(3, 1, 0)
	var head_r := Vector3(4.2, 3.6, 4.0)
	n.add_child(blob(head_r, hair, head_c))
	# Eight eyes: two big ones in front, six small ones around them.
	var eyes := [[Vector3(1, 0.45, 0.3), 1.3], [Vector3(1, 0.45, -0.3), 1.3], [Vector3(0.8, 0.8, 0.6), 0.8], [Vector3(0.8, 0.8, -0.6), 0.8],
		[Vector3(0.6, 1, 0.25), 0.7], [Vector3(0.6, 1, -0.25), 0.7], [Vector3(0.9, 0.2, 0.75), 0.6], [Vector3(0.9, 0.2, -0.75), 0.6]]
	for e in eyes:
		n.add_child(decal("rat_eye", e[1] * 2.0, e[1] * 2.0, on_surface(head_c, head_r, e[0], 0.05), e[0], false))
	for side in [1, -1]:   # fangs
		n.add_child(rod(Vector3(6.2, -0.5, 1.2 * side), Vector3(7.4, -3.2, 0.8 * side), 0.9, 0.35, plain(Color("#1e1612"))))
	return {"node": n, "sockets": {"top": Vector3(2, 4.0, 0)}, "gear_scale": 0.62}   # caps sized to the small head (one covered it whole)


## A hairy jointed leg: up and out to the knee, then down to a dark tip.
func _leg_spider(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("rat_fur", c.skin, 4.0)
	var knee := Vector3(6, 7, 1.5)
	var tip := Vector3(11, -10, 2.5)
	n.add_child(rod(Vector3.ZERO, knee, 1.4, 1.2, hair))
	n.add_child(rod(knee, knee.lerp(tip, 0.6), 1.2, 0.9, hair))
	n.add_child(rod(knee.lerp(tip, 0.6), tip, 0.9, 0.5, plain(c.skin.darkened(0.5))))
	return {"node": n}


# ------------------------------------------------------------------ more gear

func _weapon_cheese_hammer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(3, 10, 0), 0.8, 0.75, surf("wood_grain", Color.WHITE, 6.0)))
	var wedge := slab([Vector2(-3, 9.5), Vector2(8, 13.5), Vector2(8.5, 7.5), Vector2(-0.5, 5.5)], 4.5, surf("cheese", Color.WHITE, 5.0))
	n.add_child(wedge)
	n.add_child(blob(Vector3(1.2, 1.2, 0.6), plain(Color("#b0841a")), Vector3(3.5, 9.5, 2.3)))
	return {"node": n}


func _armour_mail(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(8.6, 8.2, 10.4), surf("mail", Color.WHITE, 2.5), Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	n.add_child(ring(9.0, 10.2, surf("iron", Color.WHITE, 3.0), Vector3(1.5, 6.0, 0), Vector3(0, 0, -10), Vector3(0.95, 1, 1.1)))
	return {"node": n}


func _weapon_sling(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cord := surf("leather", c.cloth2, 2.0)
	# Whirled from the raised hand: two cords out to the pouch and its stone, swinging behind.
	n.add_child(rod(Vector3(0, 0, 0), Vector3(-6.5, 3.5, 0.6), 0.4, 0.4, cord))
	n.add_child(rod(Vector3(0.5, 0, 0), Vector3(-6.0, 4.5, -0.6), 0.4, 0.4, cord))
	n.add_child(blob(Vector3(1.9, 1.3, 1.5), cord, Vector3(-6.6, 4.3, 0)))
	n.add_child(blob(Vector3(1.5, 1.5, 1.5), surf("iron", Color("#b8b4a8"), 3.0), Vector3(-7.0, 5.0, 0)))
	return {"node": n}


func _weapon_crossbow(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(slab([Vector2(-5, -0.8), Vector2(10, 0.6), Vector2(10, 2.4), Vector2(-5, 1.4), Vector2(-6, -1.8)], 1.8, surf("wood_grain", Color.WHITE, 6.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(9, 1.5, 0), Vector3(7.5, 2.0, 7.0), 0.55, 0.4, iron))   # the bow arms
	n.add_child(rod(Vector3(9, 1.5, 0), Vector3(7.5, 2.0, -7.0), 0.55, 0.4, iron))
	n.add_child(rod(Vector3(7.5, 2.0, 7.0), Vector3(1.0, 1.6, 0), 0.12, 0.12, plain(Color("#e8e0c8")), false))
	n.add_child(rod(Vector3(7.5, 2.0, -7.0), Vector3(1.0, 1.6, 0), 0.12, 0.12, plain(Color("#e8e0c8")), false))
	n.add_child(rod(Vector3(1.0, 2.4, 0), Vector3(10.5, 2.6, 0), 0.25, 0.25, plain(Color("#6b4a2a")), false))   # a bolt
	return {"node": n}


## "Saucepan" helmet: an iron dome with a rolled brim (and the handle, of course).
func _helm_dome(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(blob(Vector3(6.4, 4.4, 6.4), iron, Vector3(0, 0.5, 0)))
	n.add_child(ring(6.2, 7.4, iron, Vector3(0, 0.6, 0)))
	# A cooking pot's two loop handles at the sides (a long pan handle read as a stray line).
	for side in [1, -1]:
		n.add_child(ring(0.7, 1.4, iron, Vector3(-1.0, 1.6, 6.9 * side), Vector3(90, 0, 0)))
	return {"node": n}


func _weapon_blowgun(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Held at the lips (the hand is at the mouth end), pointing ahead and a little up.
	n.add_child(rod(Vector3(-2.5, -0.6, 0), Vector3(15, 2.6, 0), 1.0, 0.9, surf("reed_stalk", Color.WHITE, 5.0), false))
	n.add_child(ring(0.9, 1.4, surf("leather", Color.WHITE, 3.0), Vector3(0.6, 0, 0), Vector3(0, 0, -77)))   # the grip wrap
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), plain(Color("#1a1a1a")), Vector3(15.2, 2.65, 0)))
	return {"node": n}


# ------------------------------------------------------------------ more shapes

## A truncated cone (r_top at the top), centred on `pos`.
func cone(r_top: float, r_bot: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 18) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## The top half of an ellipsoid (helmets), its flat side at `pos`.
func dome(r: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 1.0
	s.is_hemisphere = true
	s.radial_segments = 28
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.scale = r
	mi.position = pos
	return mi


## A node at `pos` whose local +z points along `face`: shields are built flat in its xy plane.
func facing(n: Node3D, pos: Vector3, face: Vector3) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.basis = Basis.looking_at(-face.normalized(), Vector3.UP)
	n.add_child(h)
	return h


## A disc (flat cylinder) in a facing node's xy plane.
func disc(r: float, thick: float, m: Material, z: float) -> MeshInstance3D:
	var mi := cone(r, r, thick, m, Vector3(0, 0, z), Vector3(90, 0, 0), 28)
	return mi


## A blade or head flat in the xy plane, set at `at` and turned to angle `ang` (radians).
func blade(points: Array, thick: float, m: Material, at: Vector3, ang: float) -> MeshInstance3D:
	var b := slab(points, thick, m)
	b.position = at
	b.rotation.z = ang
	return b


## A horsehair crest along the helmet's ridge, tinted (team key, crimson).
func crest(n: Node3D, tint: Color, pos: Vector3, length: float, height: float) -> void:
	n.add_child(decal("plume", length, height, pos + Vector3(0, height * 0.5, 0), Vector3(0, 0, 1), true, Vector3.UP, tint))


# ------------------------------------------------------------------ human

const HUMAN_HAND_L := Vector3(5.5, 20.5, -4.8)   # the shield hand, forearm up (at hip height, 17.2, a rider's shield went into its horse)


func _body_human(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# The tunic is the team colour, as the genre does; the culture shows in sleeves and trim.
	var tunic := surf("cloth", c.team, 6.0)
	var cloth := surf("cloth", c.cloth, 6.0)
	var skin := surf("skin", c.skin, 8.0)
	var belt := surf("leather", Color.WHITE, 3.0)
	# A belted tunic: chest and shoulders, a flared skirt over the hips. Modelled in Blender
	# (tools/blender/human_torso.py); the primitive version is the fallback.
	if FileAccess.file_exists("res://assets/models/torso_human.glb"):
		n.add_child(glb("torso_human", {"team": tunic, "cloth": cloth, "leather": belt, "skin": skin}))
	else:
		n.add_child(blob(Vector3(4.4, 5.8, 5.4), tunic, Vector3(0.3, 19.6, 0)))
		n.add_child(cone(4.3, 5.5, 4.6, tunic, Vector3(0, 12.9, 0)))
		n.add_child(ring(5.0, 5.7, cloth, Vector3(0, 10.75, 0)))   # hem trim in the culture's colour
		n.add_child(ring(4.2, 5.1, belt, Vector3(0, 15.0, 0)))
		n.add_child(rod(Vector3(0.3, 23.5, 0), Vector3(0.6, 27, 0), 1.8, 1.7, skin))
	n.add_child(blob(Vector3(1.0, 1.0, 0.5), surf("bronze", Color.WHITE, 2.0), Vector3(4.6, 15.2, 0.6)))   # the buckle
	var near_hand := Vector3.ZERO
	var front := Node3D.new()
	for side in [1, -1]:
		var into: Node3D = front if side == 1 else n
		var sh := Vector3(0.3, 22.9, 4.4 * side)   # shoulders in a little (Dominic: too big)
		var elbow := Vector3(1.4, 18.4, 5.8 * side)
		var hand := Vector3(6.0, 16.2, 5.6) if side == 1 else HUMAN_HAND_L
		if side == 1:
			var pose := arm_pose(sh, elbow, hand, Vector3(0.6, 27, 0))
			elbow = pose[0]
			hand = pose[1]
			near_hand = hand
		into.add_child(blob(Vector3(2.1, 2.1, 2.1), cloth, sh))
		into.add_child(rod(sh, elbow, 1.6, 1.45, cloth))
		into.add_child(rod(elbow, hand, 1.35, 1.15, skin))
		into.add_child(blob(Vector3(1.5, 1.6, 1.3), skin, hand))
	# (No scarf: the tunic is already the team colour, and a scarf ring hid the neck: Dominic.)
	return {"node": n, "front": front, "sockets": {
		"head": Vector3(0.6, 25.6, 0), "hand_r": near_hand, "hand_l": HUMAN_HAND_L,   # head low: a short neck (Dominic)
		"torso": Vector3(0.0, 19.4, 0), "back": Vector3(-4.2, 22, 0)},   # the chest's middle (lower, the jerkin bulged out of the belly from the front)
		"anchors": [[Vector3(-2.3, 11.0, -2.4), 0.0, -1], [Vector3(2.0, 11.0, 2.4), PI, 1]],
		"torso_scale": Vector2(0.66, 0.82),
		"torso_fit": Vector3(0.43, 0.74, 0.52),   # worn armour (built ~1.6x) just over the (Blender) chest, not an egg round it
		"legs_under": true}   # the tunic's skirt hangs over the thighs


func _head_human(c: Dictionary) -> Dictionary:
	# Modelled in Blender (tools/blender/human_head.py): a face with structure (brow, nose,
	# cheekbones, chin) rather than primitives; the primitive head is kept below as the fallback.
	if FileAccess.file_exists("res://assets/models/head_human.glb"):
		# Softer shading on the face: half its light is its own, so the jaw's shade stays within a
		# band of the cheek (with full shading it dropped a band and read as stubble: Dominic).
		var face := surf("skin", c.skin * 0.4, 6.0)
		face.emission_enabled = true
		face.emission = c.skin * 0.82
		return {"node": glb("head_human", {"skin": face, "hair": surf("mane", c.skin2.darkened(0.45), 3.0),
			"eye": plain(Color("#1a1210"))}), "sockets": {"top": Vector3(0.3, 10.3, 0)},
			"gear_scale": 0.86}   # a narrower skull than the old egg: caps and helmets sit on it, not flat on top
	return _head_human_primitive(c)


func _head_human_primitive(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var skin := surf("skin", c.skin, 6.0)
	var hair := surf("mane", c.skin2.darkened(0.45), 3.0)
	var skull_c := Vector3(0.5, 5.2, 0)
	var skull_r := Vector3(4.4, 5.0, 4.2)
	n.add_child(blob(skull_r, skin, skull_c))
	n.add_child(blob(Vector3(3.2, 2.6, 3.3), skin, Vector3(1.6, 2.6, 0)))   # jaw
	n.add_child(blob(Vector3(1.0, 1.3, 0.8), skin, on_surface(skull_c, skull_r, Vector3(1, -0.1, 0), -0.2)))   # nose
	n.add_child(rod(Vector3(4.2, 2.2, -0.9), Vector3(4.3, 2.3, 0.9), 0.3, 0.3, plain(c.skin2.darkened(0.5))))   # mouth
	for side in [1, -1]:
		var look := Vector3(0.78, 0.12, 0.45 * side)
		n.add_child(decal("human_eye", 1.9, 1.9, on_surface(skull_c, skull_r, look, 0.05), look, false))
		n.add_child(blob(Vector3(0.8, 1.4, 0.6), skin, Vector3(-0.4, 5.0, 4.2 * side)))   # ears
	n.add_child(blob(Vector3(4.6, 3.0, 4.5), hair, Vector3(-0.3, 8.1, 0)))
	n.add_child(blob(Vector3(3.2, 3.8, 4.2), hair, Vector3(-1.6, 6.0, 0)))
	return {"node": n, "sockets": {"top": Vector3(0.3, 11.0, 0)}}


func _leg_human(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cloth := surf("cloth", c.cloth2, 5.0)
	var boot := surf("leather", Color("#6a4a30"), 3.0)
	# Modelled in Blender (tools/blender/human_leg.py): a shaped thigh, knee and calf, a cuffed boot.
	if FileAccess.file_exists("res://assets/models/leg_human.glb"):
		n.add_child(glb("leg_human", {"cloth": cloth, "leather": boot}))
		return {"node": n}
	n.add_child(rod(Vector3(0, 0, 0), Vector3(0.7, -5.4, 0), 2.0, 1.6, cloth))
	n.add_child(rod(Vector3(0.7, -5.4, 0), Vector3(0.1, -9.4, 0), 1.5, 1.3, cloth))
	n.add_child(cone(1.35, 1.5, 1.8, boot, Vector3(0.2, -9.4, 0)))
	n.add_child(blob(Vector3(2.4, 1.1, 1.5), boot, Vector3(1.1, -10.3, 0)))
	return {"node": n}


# ------------------------------------------------------------------ pony (a mount; centaurs use the fused body)

const PONY_LIFT := 3.0   # longer legs than the 2D pony: ponies, not sheep


func _pony_barrel(n: Node3D, c: Dictionary) -> void:
	var hide := surf("hide", c.skin, 6.0)
	var mane := surf("mane", c.skin2.darkened(0.35), 3.0)
	n.add_child(blob(Vector3(10.5, 6.6, 6.0), hide, Vector3(0, 19, 0)))
	n.add_child(blob(Vector3(5.6, 6.6, 5.6), hide, Vector3(8.0, 19.6, 0)))    # chest
	n.add_child(blob(Vector3(6.4, 7.0, 6.0), hide, Vector3(-8.5, 20.2, 0)))   # rump
	var tail := [Vector3(-14, 23, 0), Vector3(-17, 19.5, 0.5), Vector3(-18.6, 14, 1.0), Vector3(-18.2, 9, 1.2)]
	var r := [2.2, 2.1, 1.7, 1.0]
	for k in range(1, tail.size()):
		n.add_child(rod(tail[k - 1], tail[k], r[k - 1], r[k], mane))


## Bodies with no arms carry their gear on a harness: a leather girth strap round the
## body, a holder sleeve on the near flank where the weapon is couched (UnitView lays
## it forward, like a lance in its rest), and a strap pad on the far flank for a shield.
## `ry`, `rz`: the girth's radii (up and across) around `centre`.
func harness(n: Node3D, centre: Vector3, ry: float, rz: float, hand_r: Vector3, hand_l: Vector3) -> void:
	var leather := surf("leather", Color.WHITE, 3.0)
	var dark := surf("leather", Color(0.55, 0.42, 0.32), 2.0)
	n.add_child(ring(0.86, 1.0, leather, centre, Vector3(0, 0, 90), Vector3(ry, 1.6, rz)))   # the girth, across the back and belly
	n.add_child(rod(hand_r + Vector3(-1.6, -0.6, 0.6), hand_r + Vector3(1.6, 0.6, 0.6), 1.15, 1.15, dark))   # the holder
	n.add_child(blob(Vector3(0.7, 0.7, 0.5), surf("bronze", Color.WHITE, 2.0), hand_r + Vector3(0, 0, 1.6)))   # its buckle
	n.add_child(blob(Vector3(2.2, 2.6, 0.8), dark, hand_l))   # the shield pad


func _pony_anchors() -> Array:
	var y := 14.0 + PONY_LIFT
	# (Hips a little in from the flanks: at z 4 they hung a unit under the chest and rump.)
	return [[Vector3(8.5, y, 3.4), 0.0, 1, 0], [Vector3(-9.5, y, 3.4), PI, 1, 0],
		[Vector3(7.0, y, -3.4), PI, -1, 0], [Vector3(-10.0, y, -3.4), 0.0, -1, 0]]


## The pony's look (2026-10-13, Dominic: "horses heads need a real re-work"; tests/sheets/horse_h1.json
## shows them side by side): classic (a round-ended rod of a face on a straight neck), h1 (a built
## horse head: broad round jowl, a long wedge of a face narrowing to the muzzle, nostrils, small
## upright ears, the eye high on the side, on an arched, maned neck that runs into the head) and h2
## (the same neck and tack, the head sculpted in Blender: tools/blender/horse.py).
const PONY_LOOKS := ["classic", "h1", "h2"]
static var pony_look := "h2"   # (Claude, round H1: the sculpted head reads best; "classic" puts the old one back)


func _body_pony(c: Dictionary) -> Dictionary:
	return _body_pony_classic(c) if pony_look == "classic" else _horse_body(c, "head.pony")


func _head_pony(c: Dictionary) -> Dictionary:
	return call("_head_pony_" + pony_look, c)


func _body_pony_classic(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var lift := Node3D.new()
	lift.position.y = PONY_LIFT
	n.add_child(lift)
	_pony_barrel(lift, c)
	var hide := surf("hide", c.skin, 6.0)
	lift.add_child(rod(Vector3(8.0, 21.5, 0), Vector3(14.4, 31.5, 0), 5.4, 4.0, hide))   # neck, arched up: deep, so the head doesn't read as a snout (Dominic)
	lift.add_child(rod(Vector3(6.4, 24.0, 0), Vector3(12.4, 33.4, 0), 2.1, 1.7, surf("mane", c.skin2.darkened(0.35), 3.0)))
	harness(lift, Vector3(4, 19, 0), 7.0, 6.3, Vector3(3, 18, 6.4), Vector3(3, 18, -6.4))
	return {"node": n, "sockets": _lifted({
		"head": Vector3(15.0, 32.5, 0), "hand_r": Vector3(3, 18, 6.9), "hand_l": Vector3(3, 18, -6.9),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(-1, 25.8, 0),
		"wings": Vector3(7.5, 25.5, 0)}),
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0), "carry": "harness"}


func _lifted(sockets: Dictionary) -> Dictionary:
	for k in sockets:
		sockets[k] += Vector3(0, PONY_LIFT, 0)
	return sockets


## A centaur's horse half: no neck; the horse's chest rises at the front into the human waist
## (the tunic's hem covers the join), so the man grows out of the horse, not sits on its back.
func _body_pony_fused(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var lift := Node3D.new()
	lift.position.y = PONY_LIFT
	n.add_child(lift)
	_pony_barrel(lift, c)
	var hide := surf("hide", c.skin, 6.0)
	lift.add_child(blob(Vector3(5.4, 7.4, 5.4), hide, Vector3(9.0, 24.0, 0), Vector3(0, 0, -12)))   # the risen chest
	lift.add_child(blob(Vector3(4.4, 3.0, 4.6), hide, Vector3(10.5, 28.6, 0)))   # into the waist, under the hem
	return {"node": n, "sockets": _lifted({
		"head": Vector3(14.6, 31.5, 0), "hand_r": Vector3(10, 18, 4), "hand_l": Vector3(8, 18, -4),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(10.0, 16.5, 0)}),
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0)}


func _head_pony_classic(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := Node3D.new()
	n.scale = Vector3.ONE * 1.25
	root.add_child(n)
	var hide := surf("hide", c.skin, 5.0)
	var a := Vector3(0.5, 0.5, 0)
	var b := Vector3(6.6, -4.0, 0)   # a shorter, deeper face
	n.add_child(rod(a, b, 3.3, 2.6, hide))
	n.add_child(blob(Vector3(3.6, 3.4, 2.8), hide, Vector3(1.6, -0.6, 0)))   # cheek, broad
	n.add_child(blob(Vector3(2.6, 2.3, 2.2), surf("hide", c.skin.darkened(0.15), 4.0), Vector3(6.8, -4.1, 0)))   # the muzzle
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.5, 0.45, 0.4), plain(Color("#1a1210")), Vector3(8.6, -3.8, 1.1 * side)))
		n.add_child(decal("rat_eye", 1.7, 1.7, Vector3(2.3, 0.9, 2.45 * side), Vector3(0.3, 0.3, side), false))
		n.add_child(cone(0.0, 0.85, 2.8, hide, Vector3(-0.2, 2.8, 1.2 * side), Vector3(-12 * side, 0, 8)))
	n.add_child(blob(Vector3(1.3, 1.7, 1.4), surf("mane", c.skin2, 3.0), Vector3(1.4, 1.8, 0)))   # forelock
	var ang := rad_to_deg(atan2(b.y - a.y, b.x - a.x)) - 90.0
	n.add_child(ring(2.5, 3.0, surf("leather", Color.WHITE, 3.0), Vector3(5.4, -3.2, 0), Vector3(0, 0, ang)))
	n.add_child(ring(2.5, 3.0, plain(c.team), Vector3(1.4, 0.4, 0), Vector3(0, 0, ang)))   # browband
	return {"node": root, "sockets": {"top": Vector3(0.5, 2.6, 0) * 1.25}}


# The reworked horse (h1, h2). The neck: deep at the base (withers to the point of the chest),
# arched along the crest, narrowing to the throat latch where the head sets on; flat-sided (deeper
# than it is wide); a mane along the crest from the poll into the withers. Built as cross-sections
# between its top line and its throat line, running into the back of the head (the head held out of
# the body's bake, so they join without a line, as the creature kit's neck.into).
const HORSE_TOP := [Vector3(5.6, 25.4, 0), Vector3(9.8, 33.4, 0), Vector3(15.0, 35.6, 0)]   # withers, crest, poll (a bezier)
const HORSE_THROAT := [Vector3(12.4, 17.0, 0), Vector3(15.6, 24.0, 0), Vector3(17.0, 30.6, 0)]   # chest point, throat, latch
const HORSE_HEAD := Vector3(16.2, 33.0, 0)   # the head socket: between the poll and the throat latch (before the lift)
const HORSE_TILT := -52.0                    # the head's pitch: nose down and forward
const HORSE_HEAD_K := 1.2                    # the head's size (its frame is about 13 long before this)


static func _bez(p: Array, t: float) -> Vector3:
	return p[0].lerp(p[1], t).lerp(p[1].lerp(p[2], t), t)


func _horse_body(c: Dictionary, head_id: String) -> Dictionary:
	var n := Node3D.new()
	var lift := Node3D.new()
	lift.position.y = PONY_LIFT
	n.add_child(lift)
	_pony_barrel(lift, c)
	var hide := surf("hide", c.skin, 6.0)
	var mane := surf("mane", c.skin2.darkened(0.35), 3.0)
	for i in 9:
		var t := i / 8.0
		var top := _bez(HORSE_TOP, t)
		var low := _bez(HORSE_THROAT, t)
		var across := top - low
		var r := Vector3(2.8, across.length() * 0.5 + 0.2, lerpf(4.4, 2.5, t))
		lift.add_child(blob(r, hide, (top + low) * 0.5, Vector3(0, 0, rad_to_deg(atan2(across.y, across.x)) - 90.0)))
	for i in 12:   # the mane: along the crest, lying a little to the near side, into the withers
		var t := 0.04 + i / 11.0 * 0.96
		var a := _bez(HORSE_TOP, t)
		var b := _bez(HORSE_TOP, minf(t + 0.1, 1.0))
		var d := (b - a).normalized()
		var up := Vector3(-d.y, d.x, 0)
		lift.add_child(blob(Vector3(1.6, 1.3, 1.0), mane, a + up * 0.6 + Vector3(0, 0, 0.4), Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)))))
	harness(lift, Vector3(4, 19, 0), 7.0, 6.3, Vector3(3, 18, 6.4), Vector3(3, 18, -6.4))
	return {"node": n, "sockets": _lifted({
		"head": HORSE_HEAD, "hand_r": Vector3(3, 18, 6.9), "hand_l": Vector3(3, 18, -6.9),
		"torso": Vector3(0, 19, 0), "back": Vector3(-8, 24, 0), "seat": Vector3(-1, 25.8, 0),
		"wings": Vector3(7.5, 25.5, 0), "join": HORSE_HEAD}),
		"anchors": _pony_anchors(), "torso_scale": Vector2(1.3, 1.0), "carry": "harness", "seam_head": head_id, "seam_r": 4.5}


## The reworked heads' top line: the forehead and the nose one straight line (head frame).
static func _horse_top(x: float) -> float:
	return 3.0 - 0.17 * (x - 1.0)


## H1: a horse head built from shapes, along +x from the socket, then pitched by HORSE_TILT: the
## broad flat forehead and the round jowl at the back, a long wedge of a face whose top runs straight
## from the forehead down the nose, narrowing to a soft muzzle with nostrils and a chin; the jaw's
## edge; the eye high on the side under a brow; small upright pointed ears; the forelock; the tack.
func _head_pony_h1(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := Node3D.new()
	n.rotation_degrees.z = HORSE_TILT
	n.scale = Vector3.ONE * HORSE_HEAD_K
	root.add_child(n)
	var hide := surf("hide", c.skin, 5.0)
	var muzzle := surf("hide", c.skin.darkened(0.25), 4.0)
	var ink := plain(Color("#1a1210"))
	n.add_child(blob(Vector3(2.4, 2.1, 2.2), hide, Vector3(1.0, 0.9, 0)))   # the cranium, the forehead broad
	n.add_child(blob(Vector3(2.7, 2.4, 2.15), hide, Vector3(1.3, -1.0, 0)))   # the jowl: big, round, flat-sided
	for f in [[4.4, 2.2, 1.95, 1.75], [6.6, 2.0, 1.7, 1.5], [8.6, 1.7, 1.5, 1.35]]:   # the face, narrowing
		n.add_child(blob(Vector3(f[1], f[2], f[3]), hide, Vector3(f[0], _horse_top(f[0]) - f[2], 0)))
	n.add_child(blob(Vector3(1.55, 1.55, 1.45), muzzle, Vector3(10.0, _horse_top(10.0) - 1.5, 0)))   # the muzzle, soft, a little flared
	n.add_child(blob(Vector3(1.2, 0.7, 1.0), muzzle, Vector3(9.5, _horse_top(9.5) - 3.0, 0)))   # the chin
	n.add_child(rod(Vector3(1.4, -3.0, 0), Vector3(8.6, _horse_top(8.6) - 3.0, 0), 1.0, 0.75, hide))   # the jaw's lower edge
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.32, 0.5, 0.28), ink, Vector3(11.3, _horse_top(11.3) - 1.2, 0.85 * side)))   # a nostril
		var eye: MeshInstance3D = blob(Vector3(0.5, 0.45, 0.4), ink, Vector3(3.1, 1.6, 1.95 * side))
		eye.mesh.resource_name = "eye"
		n.add_child(eye)
		var brow: MeshInstance3D = blob(Vector3(0.8, 0.35, 0.6), hide, Vector3(3.1, 2.15, 1.85 * side))
		brow.mesh.resource_name = "brow"
		n.add_child(brow)
	n.add_child(rod(Vector3(10.4, _horse_top(10.4) - 2.4, 0), Vector3(11.4, _horse_top(11.4) - 2.3, 0), 0.15, 0.12, ink, false))   # the mouth
	_horse_ears(n, c)
	return {"node": root, "sockets": {"top": Basis(Vector3(0, 0, 1), deg_to_rad(HORSE_TILT)) * Vector3(1.0, 3.2, 0) * HORSE_HEAD_K}}


## What both reworked heads share (head frame): small pointed ears, upright in the world (turned back
## against the head's pitch), a little apart; the forelock; the bridle (a noseband round the face, a
## team browband under the ears, a cheek strap between them).
func _horse_ears(n: Node3D, c: Dictionary) -> void:
	var hide := surf("hide", c.skin, 5.0)
	var leather := surf("leather", Color.WHITE, 3.0)
	for side in [1, -1]:
		n.add_child(cone(0.0, 0.7, 2.5, hide, Vector3(0.0, 3.4, 1.05 * side), Vector3(-10 * side, 0, -HORSE_TILT - 8.0)))
		n.add_child(cone(0.0, 0.4, 1.8, plain(c.skin.darkened(0.45)), Vector3(0.12, 3.35, 1.15 * side), Vector3(-10 * side, 0, -HORSE_TILT - 8.0)))
		n.add_child(rod(Vector3(1.0, 0.6, 2.25 * side), Vector3(7.4, _horse_top(7.4) - 1.8, 1.75 * side), 0.2, 0.2, leather))   # the cheek strap
	n.add_child(blob(Vector3(1.5, 0.75, 1.0), surf("mane", c.skin2.darkened(0.35), 3.0), Vector3(1.8, 3.1, 0), Vector3(0, 0, -15)))   # the forelock
	n.add_child(ring(1.9, 2.3, leather, Vector3(7.6, _horse_top(7.6) - 1.65, 0), Vector3(0, 0, 90), Vector3(1, 1, 0.92)))   # the noseband
	n.add_child(ring(2.2, 2.6, plain(c.team), Vector3(0.6, 1.0, 0), Vector3(0, 0, 80), Vector3(1, 1.05, 1.02)))   # the browband


## H2: the head sculpted in Blender (tools/blender/horse.py: one lofted surface, jowl to muzzle, with
## the nostrils, the chin and the jaw's edge in it), the ears, forelock and tack as H1's.
func _head_pony_h2(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := Node3D.new()
	n.rotation_degrees.z = HORSE_TILT
	n.scale = Vector3.ONE * HORSE_HEAD_K
	root.add_child(n)
	var ink := plain(Color("#1a1210"))
	n.add_child(glb("head_horse", {"hide": surf("hide", c.skin, 5.0), "muzzle": surf("hide", c.skin.darkened(0.25), 4.0), "nostril": ink, "eye": ink}))
	_horse_ears(n, c)
	return {"node": root, "sockets": {"top": Basis(Vector3(0, 0, 1), deg_to_rad(HORSE_TILT)) * Vector3(1.0, 3.2, 0) * HORSE_HEAD_K}}


## The concept ids (data/later/horses.json): each look's body beside the game's pony.
func _body_pony_h1(c: Dictionary) -> Dictionary:
	return _horse_body(c, "head.pony_h1")


func _body_pony_h2(c: Dictionary) -> Dictionary:
	return _horse_body(c, "head.pony_h2")


func _leg_hoof(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(3.0, 5.8, 2.6), hide, Vector3(0, -1.6, 0)))   # the thigh, starting up inside the barrel (not an egg under it)
	n.add_child(rod(Vector3(0, -6.0, 0), Vector3(0.2, -13.6, 0), 1.3, 0.95, hide))
	n.add_child(blob(Vector3(1.3, 1.2, 1.2), hide, Vector3(0.3, -13.8, 0)))
	n.add_child(rod(Vector3(0.3, -13.8, 0), Vector3(0.8, -14.8, 0), 1.0, 1.0, hide))
	n.add_child(cone(1.1, 1.6, 1.4, plain(Color("#2a2420")), Vector3(1.0, -15.4, 0)))
	return {"node": n}


# ------------------------------------------------------------------ capybara (the rats' mount, RB1)
# The rats' "big cousin" (Dominic's pick): a barrel of a body on short legs, a blunt
# head with tiny ears, a tea towel for a saddle with the team's stripe across it.
# Its looks (CP1, "very cubey face": Dominic; tests/capybara_sheet.gd shows them side by side):
# box (RB1's primitives), soft (rounded primitives: a deep muzzle, a heavy cheek, a sloping
# barrel), sculpt (the head modelled in Blender, tools/blender/capybara.py, on the soft body),
# full (Blender head and body). Pushed further (RM1, "bigger head, need to avoid it looking like
# a bear": Dominic; tests/rat_mount_sheet.gd): long (a brick of a head a third of the animal, flat
# on top, eyes and ears high, the whole blunt front a dark nose; the rump well above the
# shoulders) and long_tan (longer still, carried level, a tan face); tools/blender/capybara.py
# variants. capybara_look picks the one in the game.

const CAPYBARA_LOOKS := ["box", "soft", "sculpt", "full", "long", "long_tan"]
static var capybara_look := "long"   # the recommendation (RM1, over CP1's full); Dominic to confirm
const CAPYBARA_LONG_HEAD := 1.35
const CAPYBARA_NECK := [Vector3(4.0, 14.5, 0), Vector3(-2.0, 1.4, 0), 3.5, 3.0]   # the long bodies' neck: from, end (from the head socket), radii
const CAPYBARA_HEAD := 1.25   # the reworked heads' scale: a capybara's head is a third of its length


func _body_capybara(c: Dictionary) -> Dictionary:
	return call("_body_capybara_" + capybara_look, c)


func _head_capybara(c: Dictionary) -> Dictionary:
	return call("_head_capybara_" + capybara_look, c)


func _leg_capybara(c: Dictionary) -> Dictionary:
	return call("_leg_capybara_" + capybara_look, c)


func _body_capybara_box(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(blob(Vector3(13.0, 8.0, 8.5), fur, Vector3(0, 13, 0)))
	n.add_child(blob(Vector3(6.0, 4.0, 6.4), surf("rat_fur", c.skin.lightened(0.12), 4.0), Vector3(3, 9.5, 0)))   # a paler belly
	n.add_child(blob(Vector3(4.6, 5.0, 4.8), fur, Vector3(-11.0, 13.5, 0)))   # the round rump
	n.add_child(_box(Vector3(9.0, 0.9, 13.0), plain(Color("#e8e0d0")), Vector3(-1, 20.9, 0)))   # the tea-towel saddle
	n.add_child(_box(Vector3(9.2, 1.0, 2.4), plain(c.team), Vector3(-1, 21.0, 0)))              # its team stripe
	for side in [1, -1]:
		n.add_child(_box(Vector3(9.0, 4.0, 0.5), plain(Color("#e8e0d0")), Vector3(-1, 18.6, 6.6 * side), Vector3(10 * side, 0, 0)))   # hanging down the flanks
	return {"node": n, "sockets": {
		"head": Vector3(12.5, 17.5, 0), "hand_r": Vector3(4, 16, 7.6), "hand_l": Vector3(3, 16, -7.6),
		"torso": Vector3(0, 14, 0), "back": Vector3(-8, 20, 0), "seat": Vector3(-1, 22.5, 0), "wings": Vector3(6, 20, 0)},
		"anchors": [[Vector3(8.0, 7.5, 5.0), 0.0, 1, 0], [Vector3(-8.0, 7.5, 5.2), PI, 1, 0],
			[Vector3(7.0, 7.5, -5.0), PI, -1, 0], [Vector3(-9.0, 7.5, -5.2), 0.0, -1, 0]],
		"torso_scale": Vector2(1.4, 0.9), "carry": "harness"}


func _head_capybara_box(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(_box(Vector3(8.5, 6.0, 6.0), fur, Vector3(3.5, 0, 0), Vector3(0, 0, -14)))   # the blunt square head
	n.add_child(_box(Vector3(2.0, 3.6, 5.0), surf("rat_fur", c.skin.darkened(0.4), 4.0), Vector3(7.6, -1.4, 0), Vector3(0, 0, -14)))   # its flat nose
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.9, 1.0, 0.7), fur, Vector3(-0.4, 3.4, 2.5 * side)))   # tiny ears
		n.add_child(blob(Vector3(0.5, 0.5, 0.45), plain(INK), Vector3(3.4, 1.8, 3.0 * side)))
	return {"node": n, "sockets": {"top": Vector3(1, 3.2, 0)}}


func _leg_capybara_box(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(rod(Vector3.ZERO, Vector3(0.4, -6.4, 0), 2.4, 1.9, fur))
	n.add_child(blob(Vector3(2.4, 0.9, 1.8), surf("rat_fur", c.skin.darkened(0.45), 3.0), Vector3(1.0, -7.0, 0)))   # a broad dark foot
	return {"node": n}


## The tea-towel saddle over the back at height y, its team stripe across, hanging down the flanks.
func _capybara_towel(n: Node3D, c: Dictionary, y: float, half: float) -> void:
	var towel := plain(Color("#e8e0d0"))
	n.add_child(_box(Vector3(9.0, 0.9, half * 1.6), towel, Vector3(-1, y, 0)))
	n.add_child(_box(Vector3(9.2, 1.0, 2.4), plain(c.team), Vector3(-1, y + 0.1, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(9.0, 4.0, 0.5), towel, Vector3(-1, y - 2.4, (half * 0.8 - 0.2) * side), Vector3(12 * side, 0, 0)))


## The capybara's rig but the body's mesh: sockets, leg hips, the saddle's seat.
func _capybara_rig(head: Vector3, seat_y: float) -> Dictionary:
	return {"sockets": {
		"head": head, "hand_r": Vector3(4, 16, 7.6), "hand_l": Vector3(3, 16, -7.6),
		"torso": Vector3(0, 14, 0), "back": Vector3(-8, seat_y - 2.5, 0), "seat": Vector3(-1, seat_y, 0), "wings": Vector3(6, seat_y - 2.5, 0)},
		"anchors": [[Vector3(8.0, 6.5, 4.6), 0.0, 1, 0], [Vector3(-8.5, 7.0, 5.0), PI, 1, 0],
			[Vector3(7.0, 6.5, -4.6), PI, -1, 0], [Vector3(-9.5, 7.0, -5.0), 0.0, -1, 0]],
		"torso_scale": Vector2(1.4, 0.9), "carry": "harness"}


## Soft: rounded primitives, the back sloping up to a heavy tailless rump, a thick short neck.
func _body_capybara_soft(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(blob(Vector3(12.5, 7.4, 8.2), fur, Vector3(0, 11.8, 0), Vector3(0, 0, -4)))
	n.add_child(blob(Vector3(6.8, 7.2, 7.8), fur, Vector3(-7.5, 12.4, 0)))   # the heavy rump, no tail
	n.add_child(blob(Vector3(5.6, 4.8, 5.4), fur, Vector3(9.5, 13.0, 0), Vector3(0, 0, 28)))   # a thick neck up to the head
	n.add_child(blob(Vector3(7.0, 3.2, 6.2), surf("rat_fur", c.skin.lightened(0.08), 4.0), Vector3(1.5, 7.0, 0)))   # the belly
	_capybara_towel(n, c, 19.4, 8.0)
	var r := _capybara_rig(Vector3(11.5, 15.4, 0), 20.8)
	r["node"] = n
	return r


## Full: the body modelled in Blender (tools/blender/capybara.py).
func _body_capybara_full(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(glb("body_capybara", {"fur": surf("rat_fur", c.skin, 5.0)}))
	_capybara_towel(n, c, 19.8, 8.4)
	var r := _capybara_rig(Vector3(12.0, 14.6, 0), 21.2)
	r["node"] = n
	return r


func _body_capybara_sculpt(c: Dictionary) -> Dictionary:
	return _body_capybara_soft(c)


## Soft: a head of rounded parts: a crown, a heavy cheek, a deep blunt muzzle with the bare
## nose on top of its front, eyes high and back, small round ears on the crown.
func _head_capybara_soft(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := Node3D.new()
	n.rotation_degrees.z = -10
	n.scale = Vector3.ONE * CAPYBARA_HEAD
	root.add_child(n)
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(blob(Vector3(3.6, 2.5, 2.2), fur, Vector3(1.6, 0.5, 0)))   # the crown
	n.add_child(blob(Vector3(3.2, 2.8, 2.5), fur, Vector3(2.8, -1.0, 0)))   # the cheeks and jaw
	n.add_child(blob(Vector3(3.4, 1.7, 1.9), fur, Vector3(5.0, 0.9, 0)))   # the bridge of the nose
	n.add_child(blob(Vector3(2.3, 2.8, 1.9), fur, Vector3(6.4, -0.5, 0)))   # the deep, blunt muzzle
	var dark := surf("rat_fur", c.skin.darkened(0.5), 3.0)
	n.add_child(blob(Vector3(0.9, 0.8, 1.4), dark, Vector3(8.0, 1.0, 0)))   # the bare nose
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.3, 0.2, 0.22), plain(INK), Vector3(8.4, 1.6, 0.6 * side)))   # nostrils, on top
		n.add_child(blob(Vector3(0.48, 0.42, 0.3), plain(INK), Vector3(2.9, 1.6, 2.05 * side)))   # eyes, high and back
		n.add_child(blob(Vector3(0.55, 0.6, 0.3), surf("rat_fur", c.skin.darkened(0.3), 3.0), Vector3(-0.3, 2.7, 1.5 * side), Vector3(20 * side, 0, 0)))
	return {"node": root, "sockets": {"top": Vector3(1, 3.0, 0) * CAPYBARA_HEAD}}


## Sculpt and full: the head modelled in Blender (tools/blender/capybara.py).
func _head_capybara_sculpt(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := glb("head_capybara", {"fur": surf("rat_fur", c.skin, 5.0), "nose": surf("rat_fur", c.skin.darkened(0.55), 3.0),
		"eye": plain(INK), "ear": surf("rat_fur", c.skin.darkened(0.3), 3.0)})
	n.rotation_degrees.z = -10
	n.scale = Vector3.ONE * CAPYBARA_HEAD
	root.add_child(n)
	return {"node": root, "sockets": {"top": Vector3(1, 3.0, 0) * CAPYBARA_HEAD}}


func _head_capybara_full(c: Dictionary) -> Dictionary:
	return _head_capybara_sculpt(c)


## Short thick legs: a thigh that starts up inside the barrel, a stout shank, a broad dark foot.
func _leg_capybara_soft(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	n.add_child(blob(Vector3(3.2, 3.8, 2.9), fur, Vector3(0, -0.4, 0)))
	n.add_child(rod(Vector3(0.2, -3.0, 0), Vector3(0.5, -5.6, 0), 2.2, 1.9, fur))
	n.add_child(blob(Vector3(2.4, 0.9, 1.9), surf("rat_fur", c.skin.darkened(0.45), 3.0), Vector3(1.2, -6.0, 0)))
	return {"node": n}


func _leg_capybara_sculpt(c: Dictionary) -> Dictionary:
	return _leg_capybara_soft(c)


func _leg_capybara_full(c: Dictionary) -> Dictionary:
	return _leg_capybara_soft(c)


## Long and long_tan (RM1): the pushed Blender head and body, on short legs with webbed feet.
func _capybara_long_mats(c: Dictionary) -> Dictionary:
	return {"fur": surf("rat_fur", c.skin, 5.0), "nose": surf("rat_fur", Color("#3a2a22"), 3.0),
		"eye": plain(INK), "ear": surf("rat_fur", c.skin.darkened(0.5), 3.0),
		"face": surf("rat_fur", c.skin.lerp(Color("#d8b888"), 0.6), 4.0)}


func _capybara_long_body(kind: String, c: Dictionary, head: Vector3, seat_y: float) -> Dictionary:
	var n := Node3D.new()
	var mats := _capybara_long_mats(c)
	n.add_child(glb("body_capybara_" + kind, mats))
	# The neck (2026-10-13, the head-join rule: the top line dipped 2 units between the shoulders and the
	# big head, so the head sat on the body like a separate brick): one thick mass from the shoulders
	# into the back of the skull, the head held out of the body's bake so they join without a line.
	n.add_child(rod(CAPYBARA_NECK[0], head + CAPYBARA_NECK[1], CAPYBARA_NECK[2], CAPYBARA_NECK[3], mats.fur))
	_capybara_towel(n, c, seat_y - 1.4, 8.0)
	var r := _capybara_rig(head, seat_y)
	r["node"] = n
	r["seam_head"] = "head.capybara"
	r["seam_r"] = 4.0
	r.sockets["join"] = head + CAPYBARA_NECK[1]
	return r


func _capybara_long_head(kind: String, c: Dictionary, tilt: float) -> Dictionary:
	var root := Node3D.new()
	var n := glb("head_capybara_" + kind, _capybara_long_mats(c))
	n.rotation_degrees.z = tilt
	n.scale = Vector3.ONE * CAPYBARA_LONG_HEAD
	root.add_child(n)
	return {"node": root, "sockets": {"top": Vector3(1, 2.6, 0) * CAPYBARA_LONG_HEAD}}


func _body_capybara_long(c: Dictionary) -> Dictionary:
	return _capybara_long_body("long", c, Vector3(11.0, 14.4, 0), 20.6)


func _head_capybara_long(c: Dictionary) -> Dictionary:
	return _capybara_long_head("long", c, -3)


func _body_capybara_long_tan(c: Dictionary) -> Dictionary:
	return _capybara_long_body("long_tan", c, Vector3(11.0, 14.2, 0), 20.8)


func _head_capybara_long_tan(c: Dictionary) -> Dictionary:
	return _capybara_long_head("long_tan", c, 0)


## Short thick legs on broad, webbed, dark-toed feet.
func _leg_capybara_long(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var fur := surf("rat_fur", c.skin, 5.0)
	var dark := surf("rat_fur", c.skin.darkened(0.5), 3.0)
	n.add_child(blob(Vector3(3.2, 3.8, 2.9), fur, Vector3(0, -0.4, 0)))
	n.add_child(rod(Vector3(0.2, -3.0, 0), Vector3(0.5, -5.6, 0), 2.1, 1.8, fur))
	n.add_child(blob(Vector3(2.6, 0.8, 2.2), dark, Vector3(1.3, -6.0, 0)))   # the webbed foot, broad and flat
	for k in [-1, 0, 1]:
		n.add_child(blob(Vector3(0.9, 0.55, 0.5), dark, Vector3(3.3, -6.2, 0.9 * k), Vector3(0, 20 * k, 0)))   # splayed toes
	return {"node": n}


func _leg_capybara_long_tan(c: Dictionary) -> Dictionary:
	return _leg_capybara_long(c)


# ------------------------------------------------------------------ cat (the rats' mount, C2, D-124)
# The alley cat again (Dominic on RM1's C: "tail is good, just legs and body a bit unclear. I think
# you've almost tried to force it to horse skeleton. Needs to be more naturally a cat, including
# sitting when idle."). A long, low body (tools/blender/big_cat.py "lean"), the head low and
# forward, and a cat's legs: the hind leg in three bones with the hock high above the paw, the
# foreleg straight from elbow to wrist with the shoulder blade riding over the back. The legs
# can't bend on one sprite, so each leg is baked posed: "leg.cat@w<i>_<n>" is step i of an n-step
# walk (a cat's four-beat walk; UnitView picks the step, parts.json body.cat `legs.poses`),
# "@sit1", "@sit2" and "@sit" (and the body "body.cat@sit1", ...) the cat sitting down when idle
# (`idle_poses`). The coat is the skin palette: skin (fur), skin2 (stripes), skin3 (chest, belly,
# muzzle and paws), so a ginger tabby and a black-and-white cat are palette entries.
# The rats ride it (D-124; Dominic: "just hind looks a little too big", so the rump, haunches and
# thighs were made leaner, the hips narrower than the chest).

const CAT_K := 1.25            # the whole cat, after modelling (pony length, lower)
const CAT_HEAD_K := 1.3        # its head, inside that
const CAT_DROP := 1.0          # the modelled body (big_cat.py "lean") sits this much lower: low-slung
const CAT_HIP := Vector3(-8.0, 13.5 - CAT_DROP, 0)
const CAT_SHOULDER := Vector3(8.5, 12.5 - CAT_DROP, 0)
const CAT_LEG_Z := 3.0
const CAT_HEAD_AT := Vector3(15.2, 15.2 - CAT_DROP, 0)
const CAT_SEAT := Vector3(-2.0, 19.3 - CAT_DROP, 0)   # behind the shoulders, on a small saddle
const CAT_SIT := {"sit": [34.0, 3.8], "sit2": [25.0, 6.4], "sit1": [13.0, 9.4]}   # body pitch (degrees, nose up), hip height: sitting down in three steps
const CAT_SIT_OUT := 1.6         # sitting, the folded hind foot lies this far out beside the haunch
const CAT_HIND := [5.4, 5.9, 4.3]   # femur, tibia, metatarsus (the hock is the joint above the paw)
const CAT_FORE := [5.0, 5.5, 1.4]   # humerus, forearm, the short pastern to the paw
const CAT_PAD := 0.75              # the paw's centre above the ground
const CAT_STRIDE := 7.5
const CAT_STANCE := 0.62           # a walk: each paw is down most of the time
const CAT_SCAPULA := Vector2(-1.4, 5.6)   # the shoulder blade's top, from the shoulder joint
const CAT_EYE := Color("#c8c23a")
const CAT_NOSE := Color("#c88080")


## How the body is placed for a pose: pitched up about the hips and lowered (sitting), or as built.
static func _cat_xf(pose: String) -> Transform3D:
	if not CAT_SIT.has(pose):
		return Transform3D.IDENTITY
	var s: Array = CAT_SIT[pose]
	var hip := Vector3(CAT_HIP.x, float(s[1]), 0)
	return Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(float(s[0]))), hip) * Transform3D(Basis.IDENTITY, -CAT_HIP)


func _cat_coat(c: Dictionary) -> Dictionary:
	var pale: Color = c.get("skin3", Color("#e8e2d6"))
	return {"fur": surf("hide", c.skin, 4.0), "stripe": surf("hide", c.skin2, 4.0), "pale": surf("hide", pale, 4.0),
		"nose": plain(CAT_NOSE), "eye": plain(INK), "iris": plain(CAT_EYE), "ear_in": plain(CAT_NOSE.lightened(0.2))}


## The body in a pose ("" standing, "sit1" and "sit2" sitting down, "sit"); sockets and hips follow it.
func _body_cat(c: Dictionary) -> Dictionary:
	var pose := "" if hold == "low" else hold
	var xf := _cat_xf(pose)
	var n := Node3D.new()
	var inner := Node3D.new()
	inner.transform = xf
	n.add_child(inner)
	var low := Node3D.new()   # the body as modelled, lowered onto the legs
	low.position.y = -CAT_DROP
	inner.add_child(low)
	var m := _cat_coat(c)
	low.add_child(glb("body_cat_lean", m))
	_cat_saddle(low, c, CAT_SEAT.x, CAT_SEAT.y + CAT_DROP - 1.4, 4.1, Vector3(2.6, 13.2, 0), 4.9, 4.9, 6.0, 2.6)
	if pose == "sit":
		# Sitting: the tail down behind and round the near side, its tip over the forepaws.
		var b := xf * Vector3(-12.0, 14.0 - CAT_DROP, 0)
		var paw := (xf * CAT_SHOULDER).x + 0.9
		# (It used to go back and under the ground behind the rump first, which baked as a lump
		# poking out there: now it drops straight to the ground and comes forward along the side.)
		_cat_tail(n, [b, Vector3(b.x + 0.5, 1.1, 1.8), Vector3(b.x + 1.6, 1.0, 3.4), Vector3(b.x + 3.4, 1.0, 4.8),
			Vector3(paw - 6.5, 1.0, 5.2), Vector3(paw - 3.0, 1.1, 4.9), Vector3(paw - 1.2, 2.0, 4.3)],
			1.35, 0.95, m.fur, m.stripe)
	elif pose == "sit1" or pose == "sit2":
		# On the way down: the tail out behind and down to the ground, its tip resting on it (built in
		# the ground's frame, so the lowered rump never pushes it under the ground).
		var b := xf * Vector3(-12.0, 14.4 - CAT_DROP, 0)
		_cat_tail(n, [b, b + Vector3(-2.8, -0.9, 0.2), Vector3(b.x - 4.8, maxf(2.6, b.y - 3.6), 0.5),
			Vector3(b.x - 5.6, 1.2, 0.9), Vector3(b.x - 4.6, 1.0, 1.6)], 1.6, 1.1, m.fur, m.stripe)
	else:
		# The hook: up from the rump and over at the tip (RM1's tail, kept: Dominic).
		_cat_tail(low, [Vector3(-12.0, 14.6, 0), Vector3(-15.2, 18.8, 0), Vector3(-16.6, 23.4, 0.3), Vector3(-16.2, 27.6, 0.5),
			Vector3(-14.5, 30.0, 0.6), Vector3(-12.6, 30.2, 0.6)], 1.6, 1.1, m.fur, m.stripe)
	var seat := CAT_SEAT
	var sockets := {"head": CAT_HEAD_AT, "hand_r": seat + Vector3(5, -6, 5.0), "hand_l": seat + Vector3(4, -6, -5.0),
		"torso": Vector3(0, seat.y - 5, 0), "back": seat + Vector3(-7, -1.5, 0), "seat": seat, "wings": seat + Vector3(7, -1.5, 0),
		"girth": Vector3(seat.x, 11.5, 0)}   # the belly under the seat, carried round as it sits (not the lowest thing under a pitched seat)
	for k in sockets:
		sockets[k] = xf * sockets[k]
	# A cat walks in four beats, one paw at a time (near hind, near fore, far hind, far fore).
	var z := Vector3(0, 0, CAT_LEG_Z)
	var anchors := [[xf * (CAT_SHOULDER + z), PI * 1.5, 1, 0, false], [xf * (CAT_HIP + z), 0.0, 1, 0, true],
		[xf * (CAT_SHOULDER - z), PI * 0.5, -1, 0, false], [xf * (CAT_HIP - z), PI, -1, 0, true]]
	return _scaled({"node": n, "sockets": sockets, "anchors": anchors, "torso_scale": Vector2(1.3, 1.0), "carry": "harness"}, CAT_K)


## A round head with big ears (the near one notched), a short muzzle in a leather muzzle strap.
func _head_cat(c: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var n := glb("head_cat_lean", _cat_coat(c))
	n.rotation_degrees.z = -4
	n.scale = Vector3.ONE * CAT_HEAD_K
	root.add_child(n)
	_cat_bridle(root, c, Vector3(4.6, -0.4, 0) * CAT_HEAD_K, 1.8 * CAT_HEAD_K, Vector3(-0.3, 1.2, 0) * CAT_HEAD_K, 3.35 * CAT_HEAD_K, -4)
	var white := plain(Color(c.get("skin3", Color("#e8e2d6"))).lightened(0.3))
	var q := Basis(Vector3(0, 0, 1), deg_to_rad(-4))
	for s in [1, -1]:   # whiskers, out from the muzzle pads
		for w in [-0.5, 0.0, 0.5]:
			var a := Vector3(4.9, -0.7 + w * 0.5, 1.2 * s)
			root.add_child(rod(q * a * CAT_HEAD_K, q * (a + Vector3(1.2, w, 2.4 * s)) * CAT_HEAD_K, 0.09, 0.06, white, false))
	return _scaled({"node": root, "sockets": {"top": Vector3(1.6, 4.2, 0) * CAT_HEAD_K}}, CAT_K)


func _leg_cat(c: Dictionary) -> Dictionary:
	return _cat_leg(c, false)


func _leg_cat_hind(c: Dictionary) -> Dictionary:
	return _cat_leg(c, true)


## One leg in the pose `hold` names, from its hip (or shoulder) joint at the origin.
func _cat_leg(c: Dictionary, hind: bool) -> Dictionary:
	var j := cat_joints(hind, "" if hold == "low" else hold)
	var n := Node3D.new()
	var fur := surf("hide", c.skin, 4.0)   # (no tabby bars on the legs: they cut them into pieces)
	var pale := surf("hide", c.get("skin3", Color("#e8e2d6")), 4.0)
	var sock := surf("hide", c.get("skin4", c.skin), 4.0)   # a fourth coat colour: stockings (a black-and-white cat)
	if hind:
		# A big thigh from inside the haunch to the knee, the shin back to the high hock, the
		# long thin metatarsus down to a small round paw. Sitting, the folded foot lies out beside
		# the haunch (+z is out to the leg's own side), so it shows and isn't tucked under the belly.
		var out := Vector3(0, 0, float(j.get("out", 0.0)))
		n.add_child(rod(Vector3(0.3, 1.6, 0), _v3(j.knee) + out * 0.5, 2.8, 1.8, fur))   # (leaner: D-124, "hind looks a little too big")
		n.add_child(rod(_v3(j.knee) + out * 0.5, _v3(j.hock) + out, 1.7, 1.0, fur))
		n.add_child(rod(_v3(j.hock) + out, _v3(j.paw) + out, 1.05, 0.9, sock))
	else:
		# The shoulder blade (it rides up over the back as the leg takes the weight), the upper
		# arm back to the elbow, the forearm straight down to the wrist, a short pastern.
		n.add_child(rod(Vector3.ZERO, _v3(j.scapula), 2.4, 1.4, fur))
		n.add_child(rod(Vector3.ZERO, _v3(j.elbow), 2.6, 1.7, sock))
		n.add_child(rod(_v3(j.elbow), _v3(j.wrist), 1.55, 1.1, sock))
		n.add_child(rod(_v3(j.wrist), _v3(j.paw), 1.0, 0.95, pale))
	var toe: Vector2 = j.toe
	var paw_out := Vector3(0, 0, float(j.get("out", 0.0))) if hind else Vector3.ZERO
	n.add_child(blob(Vector3(1.5, 0.75, 1.3), pale, _v3(j.paw + toe * 0.45) + paw_out, Vector3(0, 0, rad_to_deg(toe.angle()))))
	return _scaled({"node": n}, CAT_K)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, p.y, 0)


## Where a leg's joints are in a pose (part units, up is +y, the hip or shoulder at the origin):
## "" standing, "w<i>_<n>" step i of an n-step walk, "sit1", "sit2", "sit". The walk moves the paw back
## along the ground while it's down (CAT_STANCE of the cycle) and lifts it forward, curled, the
## rest; the bones follow by two-bone IK (the knee bends forward, the elbow back).
static func cat_joints(hind: bool, pose: String) -> Dictionary:
	var h: float = CAT_HIP.y if hind else CAT_SHOULDER.y
	var lift := 0.0
	var x := -0.5 if hind else 0.6
	var tilt := 18.0 if hind else 4.0   # degrees: the hock behind the paw / the wrist over it
	var down := 0.0   # stance progress (the shoulder blade rises mid-stance)
	if pose.begins_with("w"):
		var nums := pose.substr(1).split("_")
		var p := float(nums[0]) / float(nums[1])
		var x0 := x
		if p < CAT_STANCE:
			var s := p / CAT_STANCE
			x = x0 + CAT_STRIDE * (0.5 - s)
			tilt = lerpf(8.0, 38.0, s) if hind else lerpf(-4.0, 22.0, s)
			down = sin(s * PI)
		else:
			var q := (p - CAT_STANCE) / (1.0 - CAT_STANCE)
			x = x0 + CAT_STRIDE * (smoothstep(0.0, 1.0, q) - 0.5)
			lift = 2.4 * sin(q * PI)
			tilt = (lerpf(38.0, 8.0, q) + 22.0 * sin(q * PI)) if hind else (lerpf(22.0, -4.0, q) + 60.0 * sin(q * PI))
	elif CAT_SIT.has(pose):
		var xf := _cat_xf(pose)
		h = float(CAT_SIT[pose][1]) if hind else (xf * CAT_SHOULDER).y
		if hind:
			if pose == "sit":   # folded flat: the hock on the ground, the paw forward under the knee
				var hk := Vector2(-0.8, -h + 0.9)
				var pw := Vector2(3.6, -h + CAT_PAD)
				return {"hock": hk, "paw": pw, "knee": _ik(Vector2.ZERO, hk, CAT_HIND[0], CAT_HIND[1], 1.0), "toe": Vector2.RIGHT, "out": CAT_SIT_OUT}
			x = 1.2 if pose == "sit1" else 2.4   # on the way down the hock leans back further each step
			tilt = 44.0 if pose == "sit1" else 66.0
		else:
			x = 0.9
			tilt = 2.0
	var paw := Vector2(x, -h + CAT_PAD + lift)
	var r := deg_to_rad(tilt)
	if hind:
		var hock := paw + Vector2(-sin(r), cos(r)) * float(CAT_HIND[2])
		var reach: float = CAT_HIND[0] + CAT_HIND[1] - 0.05
		if hock.length() > reach:   # out of reach: the paw comes up off the ground a little
			var fix := hock.normalized() * reach - hock
			hock += fix
			paw += fix
		return {"hock": hock, "paw": paw, "knee": _ik(Vector2.ZERO, hock, CAT_HIND[0], CAT_HIND[1], 1.0),
			"toe": Vector2(cos(r * 0.5), -sin(r * 0.5)) if lift > 0.0 else Vector2.RIGHT}
	var wrist := paw + Vector2(sin(r), cos(r)) * float(CAT_FORE[2])
	var reach2: float = CAT_FORE[0] + CAT_FORE[1] - 0.05
	if wrist.length() > reach2:
		var fix2 := wrist.normalized() * reach2 - wrist
		wrist += fix2
		paw += fix2
	var scap := CAT_SCAPULA + Vector2(-0.25 * (x - 0.6), 0.9 * down)
	if CAT_SIT.has(pose):
		scap = (CAT_SCAPULA * 0.8).rotated(deg_to_rad(float(CAT_SIT[pose][0])) * 0.6)   # settled, not up by the rider's hands
	var toe := Vector2.RIGHT
	if lift > 0.0:   # a lifted paw curls back under the wrist
		toe = (paw - wrist).normalized().rotated(PI * 0.5)
		if toe.x < -0.2:
			toe = Vector2.RIGHT
	return {"wrist": wrist, "paw": paw, "elbow": _ik(Vector2.ZERO, wrist, CAT_FORE[0], CAT_FORE[1], -1.0), "scapula": scap, "toe": toe}


## Two-bone IK in a plane: the middle joint for bones l1, l2 from a to b, bending to `side`
## (+1: forward of the line from a to b when it points down; -1: behind it).
static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, side: float) -> Vector2:
	var d := b - a
	var l := clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var u := d.normalized()
	var along := (l1 * l1 - l2 * l2 + l * l) / (2.0 * l)
	var h := sqrt(maxf(0.0, l1 * l1 - along * along))
	return a + u * along + Vector2(-u.y, u.x) * h * side


## The cats' tack (RM1's cat in rat_mount_concepts.gd, and C2's): a saddle cloth in the team's colour with a pale border, a leather saddle on it, a girth.
func _cat_saddle(n: Node3D, c: Dictionary, x: float, y: float, half: float, girth_c: Vector3, ry: float, rz: float, length := 9.0, drop := 4.4) -> void:
	var cloth := plain(c.team)
	var trim := surf("cloth", Color("#e8e0d0"), 3.0)
	n.add_child(_box(Vector3(length, 0.7, half * 1.7), cloth, Vector3(x, y, 0)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(length, drop, 0.5), cloth, Vector3(x, y - drop * 0.5 - 0.2, (half * 0.85) * side), Vector3(10 * side, 0, 0)))
		n.add_child(_box(Vector3(length + 0.2, 0.7, 0.6), trim, Vector3(x, y - drop - 0.1, (half * 0.85 + 0.35) * side), Vector3(10 * side, 0, 0)))
	n.add_child(_box(Vector3(minf(5.5, length - 1.5), 1.2, half * 1.2), surf("leather", Color(0.7, 0.5, 0.35), 3.0), Vector3(x, y + 0.8, 0)))   # the saddle
	harness(n, girth_c, ry, rz, girth_c + Vector3(-1, -1, rz + 0.4), girth_c + Vector3(-1, -1, -rz - 0.4))


## A tail as a chain of rods along `pts`, ringed dark every other segment.
func _cat_tail(n: Node3D, pts: Array, r0: float, r1: float, fur: Material, dark: Material, tip_dark := true) -> void:
	var count := pts.size() - 1
	for k in count:
		var ra := lerpf(r0, r1, float(k) / count)
		var rb := lerpf(r0, r1, float(k + 1) / count)
		var m := dark if (k % 2 == 1 or (tip_dark and k == count - 1)) else fur
		n.add_child(rod(pts[k], pts[k + 1], ra, rb, m))


## A muzzle strap round the snout, a headstall behind the eyes, its brow band in team colour.
func _cat_bridle(n: Node3D, c: Dictionary, snout: Vector3, sr: float, crown: Vector3, cr: float, tilt: float) -> void:
	var leather := surf("leather", Color(0.55, 0.4, 0.28), 2.0)
	var q := Basis(Vector3(0, 0, 1), deg_to_rad(tilt))
	n.add_child(ring(sr * 0.92, sr * 1.08, leather, q * snout, Vector3(0, 0, 90 + tilt), Vector3(1, 1.4, 1)))
	n.add_child(ring(cr * 0.9, cr * 1.04, leather, q * crown, Vector3(0, 0, 70 + tilt), Vector3(1, 1.6, 1)))
	n.add_child(rod(q * (snout + Vector3(-0.6, sr * 0.6, 0)), q * (crown + Vector3(1.6, cr * 0.7, 0)), 0.3, 0.3, leather))
	n.add_child(blob(Vector3(0.5, 0.5, 0.5), surf("bronze", Color.WHITE, 2.0), q * (snout + Vector3(-0.8, 0, sr * 1.02))))   # the ring the rein ties to



# ------------------------------------------------------------------ hummingbird (forest cavalry, HB1)
# A big hummingbird ridden like a horse (Dominic, 2026-10-13): it hovers (the view bobs it and
# keeps it off the ground), nose up, slim, a forked tail, iridescent plumage (skin) with a
# bright throat (skin2), and a long beak capped in bronze with a team pennant: the bird's own
# lance. Its wings are a blur: pale ghost exposures fanned through the stroke, a part of their
# own (wings.hummingbird) that the view draws see-through and flickers (parts.json "blur").

const HB_BELLY := Color("#e6e2d2")
const HB_BEAK := Color("#1c1816")
const HB_BLUR := Color("#e2f6e8")


## Iridescent plumage: glossy, with a bright rim where it turns from the light.
func _hb_gloss(col: Color, rim := 0.6) -> StandardMaterial3D:
	var m := plain(col)
	m.metallic = 0.5
	m.roughness = 0.3
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = rim
	m.rim_tint = 0.1
	return m


## A blur's paint: unlit, so its pale reads the same from every side.
func _hb_blur_mat(col: Color) -> StandardMaterial3D:
	var m := plain(col)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## A wing as a narrow scimitar (hummingbird wings are long and thin), root at the shoulder,
## swept out to `tip`, `w` wide at its widest, its flat face turned by `up`.
func _hb_wing(m: Material, root: Vector3, tip: Vector3, w: float, up: Vector3) -> MeshInstance3D:
	var d := tip - root
	var L := d.length()
	var pts := [Vector2(0, -w * 0.2), Vector2(L * 0.3, w), Vector2(L * 0.75, w * 0.85), Vector2(L, w * 0.2), Vector2(L * 0.95, -w * 0.2), Vector2(L * 0.5, -w * 0.3)]
	var mi := slab(pts, 0.4, m, Vector3.ZERO)
	var x := d.normalized()
	var z := x.cross(up).normalized()
	var y := z.cross(x)
	mi.basis = Basis(x, y, z)
	mi.position = root
	return mi


## Ghost wings fanned through the stroke: `count` wings per side from low-and-out to high,
## each a pale exposure.
func _hb_ghosts(count: int, spread: float, tones: Array) -> Node3D:
	var n := Node3D.new()
	for side in [1, -1]:
		for k in count:
			var a := deg_to_rad(8 + k * spread)
			var tip := Vector3(-2.0 - k * 1.5, 3.0 + 21.0 * cos(a), (2.0 + 19.0 * sin(a)) * side)
			n.add_child(_hb_wing(_hb_blur_mat(tones[k % tones.size()]), Vector3(0, 0, 1.6 * side), tip, 4.2, Vector3(1, 0, 0)))
	return n


func _body_hummingbird(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var green := _hb_gloss(c.skin)
	var dark := _hb_gloss(c.skin.darkened(0.45), 0.4)
	n.add_child(blob(Vector3(9.5, 5.4, 5.4), green, Vector3(0, 14, 0), Vector3(0, 0, 24)))                 # the body, nose up
	n.add_child(blob(Vector3(6.5, 3.2, 4.4), plain(HB_BELLY), Vector3(1.5, 11.0, 0), Vector3(0, 0, 24)))   # a pale belly
	n.add_child(blob(Vector3(5.4, 6.0, 5.4), green, Vector3(5.5, 17.5, 0)))                                # the chest
	n.add_child(blob(Vector3(3.8, 3.6, 4.4), _hb_gloss(c.skin2, 0.8), Vector3(8.6, 20.0, 0)))              # the bright throat
	n.add_child(blob(Vector3(3.2, 3.6, 3.4), green, Vector3(9.4, 22.6, 0)))                                # up into the head
	for f in 5:   # the tail: a narrow forked fan, dark, white-tipped, down and back
		var base := Vector3(-7.5, 10.5, 0)
		var end := base + Vector3(-9.0 + absf(f - 2) * 1.2, -4.5, sin(deg_to_rad(-30 + f * 15)) * 4.5)
		n.add_child(rod(base, end, 0.9, 1.3, dark))
		n.add_child(blob(Vector3(1.1, 0.5, 1.0), plain(HB_BELLY), end + Vector3(-0.6, -0.2, 0)))
	for side in [1, -1]:   # tiny feet tucked under (it never lands to fight)
		n.add_child(blob(Vector3(1.3, 0.7, 0.7), plain(INK), Vector3(1.5, 7.6, 1.8 * side)))
	# A team saddle cloth and a girth, the weapon couched at the near flank, a shield pad far.
	var seat := Vector3(-2.5, 19.6, 0)
	n.add_child(blob(Vector3(4.8, 1.2, 5.6), plain(c.team), seat + Vector3(0, -0.5, 0), Vector3(0, 0, 20)))
	harness(n, Vector3(-1.0, 14.0, 0), 5.8, 5.9, Vector3(0, 13, 5.9), Vector3(0, 13, -5.9))
	return {"node": n, "sockets": {"head": Vector3(10.5, 25.0, 0), "hand_r": Vector3(0, 13, 6.4), "hand_l": Vector3(0, 13, -6.4),
		"torso": Vector3(0, 14, 0), "back": Vector3(5.5, 20.5, 0), "seat": seat + Vector3(0, 0.8, 0)},
		"anchors": [], "torso_scale": Vector2(1.1, 0.85), "carry": "harness"}


func _head_hummingbird(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var green := _hb_gloss(c.skin)
	n.add_child(blob(Vector3(4.5, 4.2, 4.0), green, Vector3.ZERO))
	n.add_child(blob(Vector3(3.2, 1.6, 3.1), _hb_gloss(c.skin.darkened(0.45), 0.4), Vector3(-0.7, 2.9, 0)))   # a darker crown
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.1, 1.1, 0.7), plain(INK), Vector3(1.9, 0.9, 3.1 * side)))
		n.add_child(blob(Vector3(0.4, 0.4, 0.3), plain(Color.WHITE), Vector3(2.4, 1.4, 3.5 * side)))
		n.add_child(blob(Vector3(1.0, 0.5, 0.4), plain(Color.WHITE), Vector3(-0.1, 1.8, 3.4 * side)))   # the white spot behind the eye
	var tip := Vector3(20.5, -1.4, 0)
	n.add_child(rod(Vector3(4.0, 0.2, 0), tip, 0.95, 0.3, plain(HB_BEAK)))   # the long beak
	var bronze := surf("bronze", Color.WHITE, 2.0)
	n.add_child(cone(0.0, 0.9, 4.0, bronze, tip + Vector3(-1.2, 0.1, 0), Vector3(0, 0, -95)))   # capped like a lance
	n.add_child(ring(0.8, 1.15, bronze, Vector3(12.5, -0.6, 0), Vector3(0, 0, 90)))
	n.add_child(slab([Vector2(0, 0), Vector2(-6, 1.0), Vector2(-4.5, -1.6), Vector2(-6.5, -3.8), Vector2(0, -2.4)], 0.3, plain(c.team), Vector3(13.0, -0.8, 0)))   # its pennant
	return {"node": n, "sockets": {"top": Vector3(-0.5, 4.0, 0)}}


func _wings_hummingbird(c: Dictionary) -> Dictionary:
	return {"node": _hb_ghosts(3, 36, [HB_BLUR, c.skin.lightened(0.55), HB_BLUR.darkened(0.08)])}


# ------------------------------------------------------------------ animals (milestone 11)
# Wild and herded animals: deer to hunt (they bolt), boar (they fight back), sheep to herd.
# skin = coat, skin2 = the darker parts (muzzle, hooves, a deer's white tail).

func _four_legs(front: float, back: float, y: float, z: float) -> Array:
	return [[Vector3(front, y, z), 0.0, 1, 0], [Vector3(back, y, z), PI, 1, 0],
		[Vector3(front - 1.0, y, -z), PI, -1, 0], [Vector3(back - 1.0, y, -z), 0.0, -1, 0]]


func _body_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(9.0, 5.2, 4.4), coat, Vector3(0, 17, 0)))
	n.add_child(blob(Vector3(4.5, 2.4, 3.6), surf("hide", c.skin.lightened(0.35), 4.0), Vector3(1, 13.6, 0)))   # pale belly
	n.add_child(rod(Vector3(6.5, 18.5, 0), Vector3(10.5, 25, 0), 2.4, 1.7, coat))   # the neck, up
	n.add_child(blob(Vector3(1.6, 1.9, 1.2), plain(Color("#f2ece0")), Vector3(-9.0, 18.6, 0)))   # a white tail
	return {"node": n, "sockets": {"head": Vector3(10.8, 25.5, 0), "torso": Vector3(0, 17, 0), "back": Vector3(-5, 21, 0)},
		"anchors": _four_legs(5.5, -5.5, 14.2, 2.2), "carry": "harness"}   # (at x -7.5, z 2.6 the far hind hip was outside the body)


func _head_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(2.4, 2.1, 1.9), coat, Vector3(0.6, 0.5, 0)))
	n.add_child(rod(Vector3(1.5, 0.3, 0), Vector3(5.2, -1.6, 0), 1.5, 0.8, coat))   # the long face
	n.add_child(blob(Vector3(0.7, 0.6, 0.7), plain(INK), Vector3(5.3, -1.6, 0)))
	var antler := plain(Color("#d8c8a4"))
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.5, 1.3, 0.7), coat, Vector3(-0.6, 2.4, 1.6 * side), Vector3(0, 0, -20)))   # ears
		n.add_child(blob(Vector3(0.45, 0.45, 0.4), plain(INK), Vector3(2.0, 1.2, 1.5 * side)))
		var base := Vector3(0.2, 2.2, 0.8 * side)
		var tip := base + Vector3(-1.0, 5.5, 2.2 * side)
		n.add_child(rod(base, tip, 0.35, 0.18, antler))
		n.add_child(rod(base.lerp(tip, 0.45), base.lerp(tip, 0.45) + Vector3(1.8, 1.6, 0.4 * side), 0.25, 0.12, antler))
		n.add_child(rod(base.lerp(tip, 0.75), base.lerp(tip, 0.75) + Vector3(1.5, 1.4, 0.2 * side), 0.22, 0.1, antler))
	return {"node": n, "sockets": {"top": Vector3(0, 2.5, 0)}}


func _leg_deer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var coat := surf("hide", c.skin, 4.0)
	n.add_child(rod(Vector3.ZERO, Vector3(0.3, -7.0, 0), 1.2, 0.6, coat))
	n.add_child(rod(Vector3(0.3, -7.0, 0), Vector3(0.6, -13.0, 0), 0.55, 0.45, coat))
	n.add_child(blob(Vector3(0.7, 0.6, 0.6), plain(c.skin2), Vector3(0.8, -13.3, 0)))
	return {"node": n}


func _body_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(blob(Vector3(9.5, 6.4, 5.6), hide, Vector3(0, 11, 0)))
	n.add_child(blob(Vector3(5.5, 5.0, 4.6), hide, Vector3(5.5, 12.5, 0)))   # the heavy shoulders
	var bristle := plain(c.skin2)
	for k in 8:   # a crest of bristles down the back
		var x := 7.0 - k * 1.9
		n.add_child(rod(Vector3(x, 16.5 - absf(x - 3.0) * 0.18, 0), Vector3(x - 0.9, 19.0 - absf(x - 3.0) * 0.2, 0), 0.5, 0.15, bristle, false))
	n.add_child(rod(Vector3(-9, 12, 0), Vector3(-11, 9, 0), 0.4, 0.2, hide))   # the tail
	return {"node": n, "sockets": {"head": Vector3(10.5, 11.5, 0), "torso": Vector3(0, 11, 0), "back": Vector3(-4, 16, 0)},
		"anchors": _four_legs(5.5, -6.0, 7.5, 3.4), "carry": "harness"}


func _head_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hide := surf("hide", c.skin, 5.0)
	n.add_child(rod(Vector3(-0.5, 0.5, 0), Vector3(5.5, -1.5, 0), 3.0, 1.6, hide))   # the long head, low
	n.add_child(rod(Vector3(3.0, -1.2, 0), Vector3(5.6, -2.0, 0), 1.9, 1.5, plain(Color("#9a6e58"))))   # a paler muzzle
	n.add_child(blob(Vector3(1.0, 1.9, 2.0), plain(Color("#e0a898")), Vector3(6.1, -1.9, 0)))   # the big pink snout disc (reads in every facing)
	var tusk := plain(Color("#f8f2e2"))
	for side in [1, -1]:
		n.add_child(rod(Vector3(4.4, -2.6, 1.5 * side), Vector3(5.6, 0.4, 2.6 * side), 0.6, 0.2, tusk))   # thick, curving up and out
		n.add_child(blob(Vector3(0.4, 0.4, 0.4), plain(INK), Vector3(2.6, 1.0, 1.9 * side)))
		n.add_child(blob(Vector3(0.6, 1.2, 0.5), hide, Vector3(0.4, 2.6, 1.8 * side), Vector3(0, 0, -25)))
	return {"node": n, "sockets": {"top": Vector3(0, 2.5, 0)}}


func _leg_boar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3.ZERO, Vector3(0.3, -6.6, 0), 1.6, 0.9, surf("hide", c.skin, 4.0)))
	n.add_child(blob(Vector3(0.9, 0.6, 0.8), plain(c.skin2), Vector3(0.5, -7.0, 0)))
	return {"node": n}


func _body_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wool := plain(c.skin)
	var shade := plain(c.skin.darkened(0.22))   # curls in shadow, so the fleece has texture
	# One smooth oval of fleece, deep and round, with soft curls on its surface (not a heap of
	# lumps), sitting low on short dark legs; a small tail tuft.
	n.add_child(blob(Vector3(7.5, 5.0, 4.6), wool, Vector3(-0.5, 10.5, 0)))
	n.add_child(blob(Vector3(4.2, 3.6, 4.0), wool, Vector3(4.0, 11.0, 0)))   # the chest, full
	var rng := RandomNumberGenerator.new()   # seeded: the same fleece every bake
	rng.seed = 31
	for k in 22:
		var a := rng.randf() * TAU
		var up := rng.randf_range(-0.2, 1.0)
		var p := Vector3(rng.randf_range(-7.0, 6.0), 10.5 + up * 4.3, cos(a) * 4.2 * sqrt(1.0 - up * up * 0.5))
		n.add_child(blob(Vector3(1.4, 1.1, 1.3), wool if k % 3 else shade, p))
	n.add_child(blob(Vector3(1.4, 1.6, 1.3), wool, Vector3(-8.0, 11.5, 0)))   # the tail tuft
	# A collar in the team key at the neck, the one quiet mark of whose sheep it is (Dominic:
	# a claimed sheep should show some team colour); nobody's sheep wear it in plain leather.
	n.add_child(ring(2.1, 3.1, plain(c.team), Vector3(7.9, 12.6, 0), Vector3(0, 0, 65), Vector3(1.0, 1.8, 1.0)))
	return {"node": n, "sockets": {"head": Vector3(8.0, 12.5, 0), "torso": Vector3(0, 10.5, 0), "back": Vector3(-3, 14, 0)},
		"anchors": _four_legs(4.5, -4.5, 7.0, 2.4), "carry": "harness"}


func _head_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var face := surf("hide", c.skin2, 4.0)
	n.add_child(blob(Vector3(1.8, 1.4, 1.6), plain(c.skin), Vector3(-0.4, 1.2, 0)))   # the poll of wool
	n.add_child(blob(Vector3(2.6, 1.7, 1.5), face, Vector3(1.6, -0.6, 0), Vector3(0, 0, -25)))   # the long dark face, nose down
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 0.4, 0.7), face, Vector3(0.0, 0.4, 1.9 * side), Vector3(0, 25 * side, -10)))   # ears out sideways
		n.add_child(blob(Vector3(0.3, 0.3, 0.3), plain(Color("#d8c8a0")), Vector3(1.2, 0.0, 1.1 * side)))   # pale eyes on the dark face
	return {"node": n, "sockets": {"top": Vector3(0, 2, 0)}}


func _leg_sheep(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3.ZERO, Vector3(0.2, -6.6, 0), 0.8, 0.6, surf("hide", c.skin2, 4.0)))
	n.add_child(blob(Vector3(0.7, 0.45, 0.6), plain(c.skin2.darkened(0.3)), Vector3(0.4, -6.8, 0)))   # a hoof
	return {"node": n}


# ------------------------------------------------------------------ beetle soldier (rearing, BG1)
# Dominic's pick: wing cases low behind on four legs, the pronotum up like a chest, the front
# pair as arms that hold the weapon. Stag beetles rear like this to fight. Ridden beetles keep
# the horizontal mount body below.

func _body_beetle_rear(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var limb := surf("chitin", c.skin.darkened(0.45), 3.0)
	for side in [1, -1]:   # the wing cases, low and behind, meeting at a seam
		n.add_child(blob(Vector3(8.0, 4.6, 3.4), shell, Vector3(-4.5, 9.5, 2.3 * side), Vector3(0, 0, 12)))
	n.add_child(rod(Vector3(-11.5, 8.0, 0), Vector3(1.5, 12.5, 0), 0.35, 0.35, plain(c.skin.darkened(0.6)), false))
	n.add_child(blob(Vector3(4.2, 7.0, 5.4), plate, Vector3(2.5, 16, 0), Vector3(0, 0, -18)))   # pronotum, up like a chest
	n.add_child(blob(Vector3(4.0, 1.0, 5.6), plain(c.team), Vector3(-4.5, 14.0, 0), Vector3(0, 0, 12)))   # a team band across the wing cases
	var front := Node3D.new()
	var hand_r := Vector3(7.5, 13.5, 7.0)   # (out by the near legs: at 5.6 a spear's butt struck the front knee)
	var pose := arm_pose(Vector3(3.5, 18, 4), Vector3(6, 15.5, 6), hand_r, Vector3(4, 22.5, 0))
	front.add_child(rod(Vector3(3.5, 18, 4), pose[0], 0.95, 0.8, limb))
	front.add_child(rod(pose[0], pose[1], 0.8, 0.6, limb))
	n.add_child(rod(Vector3(3.5, 18, -4), Vector3(6.5, 14.5, -6), 0.95, 0.75, limb))   # the far arm
	return {"node": n, "front": front, "sockets": {"head": Vector3(4, 22.5, 0), "hand_r": pose[1], "hand_l": Vector3(6.5, 14.5, -6),
		"torso": Vector3(2.5, 16, 0), "back": Vector3(-6, 14, 0)},
		"anchors": [[Vector3(0.5, 8.0, 3.2), 0.0, 1, 0], [Vector3(-6.0, 8.0, 3.2), PI, 1, 1],
			[Vector3(0.5, 8.0, -3.2), PI, -1, 0], [Vector3(-6.0, 8.0, -3.2), 0.0, -1, 1]],
		"torso_scale": Vector2(0.55, 0.65)}


# ------------------------------------------------------------------ beetle (a mount)

func _body_beetle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 5.0)
	var plate := surf("chitin", c.skin2, 4.0)
	var under := plain(c.skin.darkened(0.55))
	n.add_child(blob(Vector3(13.5, 4.0, 7.6), under, Vector3(0, 9.6, 0)))
	for side in [1, -1]:   # the two wing cases, meeting at a seam
		n.add_child(blob(Vector3(14.0, 6.8, 4.6), shell, Vector3(-2.5, 13.5, 3.0 * side)))
	n.add_child(rod(Vector3(-15.5, 14.5, 0), Vector3(10, 19.4, 0), 0.45, 0.45, plain(c.skin.darkened(0.6)), false))
	n.add_child(blob(Vector3(5.6, 5.4, 7.4), plate, Vector3(11.0, 13.0, 0)))   # pronotum
	# A team-colour cloth over the back (a saddle blanket when ridden).
	n.add_child(blob(Vector3(5.0, 1.2, 6.6), plain(c.team), Vector3(-1.5, 20.0, 0), Vector3(0, 0, -6)))
	var hips := [[Vector3(10, 9.5, 6.0), 0.0, 1, 0], [Vector3(2, 9.5, 6.5), 2.1, 1, 0], [Vector3(-7, 9.5, 6.0), 4.2, 1, 1],
		[Vector3(11, 9.5, -6.0), 3.14, -1, 0], [Vector3(3, 9.5, -6.5), 5.2, -1, 0], [Vector3(-6, 9.5, -6.0), 1.0, -1, 1]]
	harness(n, Vector3(4, 13.5, 0), 7.2, 8.0, Vector3(4, 13.5, 8.0), Vector3(3, 13.5, -8.0))
	return {"node": n, "sockets": {
		"head": Vector3(16, 12.5, 0), "hand_r": Vector3(4, 13.5, 8.6), "hand_l": Vector3(3, 13.5, -8.6),
		"torso": Vector3(11, 14, 0), "back": Vector3(-8, 19, 0), "seat": Vector3(-1.5, 21.5, 0),
		"wings": Vector3(6, 19.5, 0)},
		"anchors": hips, "torso_scale": Vector2(0.65, 0.6), "carry": "harness"}


func _head_beetle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin, 4.0)
	var horn := surf("chitin", c.skin2, 3.0)
	n.add_child(blob(Vector3(4.6, 3.6, 4.4), shell, Vector3(2.5, 0, 0)))
	var pts := [Vector3(5.5, 1.0, 0), Vector3(9.5, 3.5, 0), Vector3(12, 8, 0), Vector3(12.6, 12, 0)]
	var r := [2.0, 1.5, 1.0, 0.4]
	for k in range(1, pts.size()):
		n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], horn))
	n.add_child(rod(Vector3(10.6, 5.5, 0), Vector3(13.4, 6.5, 0), 0.6, 0.3, horn))   # a tine
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.1, 1.1, 0.8), plain(Color("#141018")), Vector3(4.6, 0.8, 3.3 * side)))
		n.add_child(blob(Vector3(0.4, 0.4, 0.3), plain(Color("#c8c0d8")), Vector3(5.0, 1.2, 3.8 * side)))
		n.add_child(rod(Vector3(6.2, -1.0, 2.0 * side), Vector3(9.0, -0.5, 4.2 * side), 0.25, 0.2, plain(c.skin.darkened(0.5))))
		n.add_child(blob(Vector3(0.7, 0.45, 0.7), plain(c.skin.darkened(0.5)), Vector3(9.2, -0.5, 4.3 * side)))
	return {"node": n, "sockets": {"top": Vector3(2, 3.6, 0)}}


func _leg_insect(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var shell := surf("chitin", c.skin.darkened(0.45), 3.0)
	var knee := Vector3(4, -1.8, 2.0)
	var foot := Vector3(6.2, -8.2, 3.0)
	n.add_child(rod(Vector3.ZERO, knee, 1.3, 1.0, shell))
	n.add_child(rod(knee, foot, 0.9, 0.6, shell))
	n.add_child(rod(foot, foot + Vector3(1.8, -0.4, 0.3), 0.45, 0.3, shell))
	return {"node": n}


# ------------------------------------------------------------------ giant newt (a mount, D-122)
# The frogs' cavalry (concept SW1 round 4, Dominic: "the newts look amazing"). Composed like the
# beetle: a body with a seat, a head on its "head" socket, four sprawling legs on its anchors.
# Its skin palette (palettes.json, newt_*) has more than two colours: skin the back, skin2 the
# belly, skin3 the spots, skin4 a ring round each spot (none when it is the back's colour), and a
# fifth colour (skin5) means a jagged crest in it: fire, red eft and crested newts.

const NEWT_SEAT := 17.2   # the saddle cloth's top, before NEWT_SCALE (a rider's hips go here; at 19 they floated over it)
const NEWT_SCALE := 1.2   # grown so a big frog sits on it, not over it


func _body_newt(c: Dictionary) -> Dictionary:
	return _scaled(_newt_body(c), NEWT_SCALE)


func _head_newt(c: Dictionary) -> Dictionary:
	return _scaled(_newt_head(c), NEWT_SCALE)


func _leg_newt(c: Dictionary) -> Dictionary:
	return _scaled(_newt_leg(c), NEWT_SCALE)


func _newt_mats(c: Dictionary) -> Dictionary:
	var skin := surf("frog_skin", c.skin, 7.0)
	skin.roughness = 0.3   # wet and glossy
	skin.metallic_specular = 0.6
	var belly := surf("frog_belly", c.skin2, 5.0)
	belly.roughness = 0.4
	var ring: Color = c.get("skin4", c.skin)
	return {"skin": skin, "belly": belly, "spot": plain(c.get("skin3", c.skin2)), "ring": plain(ring),
		"ringed": ring != c.skin, "crest": surf("frog_skin", c.skin5, 7.0) if c.has("skin5") else null}


## Spots along the flanks and back, placed on the body's ellipsoids (a fixed list, not random).
func _newt_spots(n: Node3D, m: Dictionary, centres: Array, big := 1.0) -> void:
	var dirs := [Vector3(0.2, 0.8, 0.55), Vector3(-0.3, 0.7, -0.6), Vector3(0.1, 0.35, 0.95), Vector3(-0.25, 0.4, -0.9),
		Vector3(0.35, 0.9, 0.1)]
	var i := 0
	for c in centres:
		for d in [dirs[i % dirs.size()], dirs[(i + 2) % dirs.size()]]:
			var at := on_surface(c[0], c[1], d, -0.15)
			var r := (1.6 + 0.5 * float(i % 3)) * big
			if m.ringed:
				n.add_child(blob(Vector3(r * 1.35, r * 0.6, r * 1.35), m.ring, at + d.normalized() * -0.1))
			n.add_child(blob(Vector3(r, r * 0.55, r), m.spot, at + d.normalized() * 0.25))
			i += 1


## The body: a long, low trunk in three overlapping lobes, a pale belly under it, a long tail
## flattened side to side; a team saddle cloth and a reed-bundle saddle.
func _newt_body(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(c)
	var lobes := [[Vector3(9.0, 9.8, 0), Vector3(9.0, 5.4, 7.6)], [Vector3(-1.0, 10.2, 0), Vector3(10.0, 5.8, 8.4)],
		[Vector3(-11.0, 9.8, 0), Vector3(8.5, 5.4, 7.6)]]
	for l in lobes:
		n.add_child(blob(l[1], m.skin, l[0]))
	n.add_child(blob(Vector3(19.0, 3.0, 7.2), m.belly, Vector3(-1.0, 6.4, 0)))
	n.add_child(blob(Vector3(5.0, 4.2, 6.2), m.skin, Vector3(16.0, 9.8, 0)))   # the neck, into the head
	# The tail: tapering, flattened side to side (a newt's paddle), curving a little to the near side.
	var tail := [Vector3(-18, 9.8, 0), Vector3(-27, 8.4, 1.5), Vector3(-35, 6.4, 3.5), Vector3(-43, 4.2, 4.0), Vector3(-49, 2.4, 2.5)]
	var r := [4.8, 3.9, 2.8, 1.7, 0.5]
	for k in range(1, tail.size()):
		var seg := rod(tail[k - 1], tail[k], r[k - 1], r[k], m.skin)
		seg.scale = Vector3(1, 1.0, 0.62)   # flattened
		seg.position = tail[k - 1] * Vector3(0, 0, 0.38)   # keep the path where it was
		n.add_child(seg)
		n.add_child(blob(Vector3((tail[k] - tail[k - 1]).length() * 0.5, r[k] * 0.45, r[k] * 0.5), m.belly,
			(tail[k - 1] + tail[k]) * 0.5 + Vector3(0, -r[k] * 0.55, 0)))
	if m.crest != null:   # a jagged crest down the tail (the back's is under the saddle)
		for k in 9:
			var at: Vector3 = tail[0].lerp(tail[3], k / 8.0)
			var h := 3.6 - k * 0.3
			n.add_child(cone(0.1, 1.3, h, m.crest, at + Vector3(0, lerpf(r[0], r[3], k / 8.0) * 0.92 + h * 0.4, 0), Vector3(0, 0, 18), 6))
		for k in 3:
			n.add_child(cone(0.1, 1.1, 2.8, m.crest, Vector3(13.0 - k * 3.0, 15.4, 0), Vector3(0, 0, 18), 6))
	var spot_on := [[lobes[0][0], lobes[0][1]], [lobes[1][0], lobes[1][1]], [lobes[2][0], lobes[2][1]],
		[Vector3(-26, 9, 1), Vector3(8, 3.9, 2.6)], [Vector3(-36, 6.2, 3), Vector3(7, 2.8, 1.9)]]
	_newt_spots(n, m, spot_on)
	# The saddle: a team cloth over the middle lobe hanging down both flanks, a reed-bundle roll
	# behind the seat, a girth under the belly.
	n.add_child(blob(Vector3(7.5, 1.4, 8.8), plain(c.team), Vector3(-1.5, 15.8, 0), Vector3(0, 0, -4)))
	for side in [1, -1]:
		n.add_child(_box(Vector3(10.0, 6.0, 0.5), plain(c.team), Vector3(-1.5, 12.4, 8.6 * side), Vector3(12 * side, 0, 0)))
	var reed := surf("thatch", Color(1.0, 0.95, 0.82), 7.0)
	n.add_child(rod(Vector3(-7.6, 16.8, -5.5), Vector3(-7.6, 16.8, 5.5), 1.9, 1.9, reed))
	n.add_child(rod(Vector3(4.6, 16.2, -4.0), Vector3(4.6, 16.2, 4.0), 1.2, 1.2, reed))
	harness(n, Vector3(2.5, 10.2, 0), 6.2, 9.0, Vector3(3.5, 10.5, 9.2), Vector3(2.5, 10.5, -9.2))
	var hips := [[Vector3(10.0, 7.6, 6.4), 0.0, 1, 0], [Vector3(-10.0, 7.6, 6.4), PI, 1, 0],
		[Vector3(11.0, 7.6, -6.4), PI, -1, 0], [Vector3(-9.0, 7.6, -6.4), 0.0, -1, 0]]
	return {"node": n, "sockets": {
		"head": Vector3(19.0, 9.8, 0), "hand_r": Vector3(3.5, 10.5, 9.8), "hand_l": Vector3(2.5, 10.5, -9.8),
		"torso": Vector3(0, 10.2, 0), "back": Vector3(-9, 15.5, 0), "seat": Vector3(-1.0, NEWT_SEAT, 0),
		"wings": Vector3(6, 15.5, 0)},
		"anchors": hips, "torso_scale": Vector2(0.8, 0.6), "carry": "harness"}


## The head: broad and flat with a rounded snout, small gold-ringed eyes high on the sides, a
## long closed mouth line, the pale throat; a team browband and a leather noseband.
func _newt_head(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(c)
	n.add_child(blob(Vector3(8.0, 3.6, 6.4), m.skin, Vector3(5.0, 0.6, 0)))
	n.add_child(blob(Vector3(6.6, 1.8, 5.6), m.belly, Vector3(4.6, -1.6, 0)))   # the throat
	n.add_child(rod(Vector3(11.8, -0.5, -4.4), Vector3(13.0, -0.4, 0), 0.32, 0.32, plain(INK)))   # the mouth line
	n.add_child(rod(Vector3(13.0, -0.4, 0), Vector3(11.8, -0.5, 4.4), 0.32, 0.32, plain(INK)))
	n.add_child(rod(Vector3(11.8, -0.5, 4.4), Vector3(4.0, -0.2, 6.2), 0.3, 0.3, plain(INK)))
	n.add_child(rod(Vector3(11.8, -0.5, -4.4), Vector3(4.0, -0.2, -6.2), 0.3, 0.3, plain(INK)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.9, 1.7, 1.6), m.skin, Vector3(7.6, 3.0, 3.6 * side)))
		n.add_child(blob(Vector3(1.1, 1.1, 0.9), plain(Color("#c8a030")), Vector3(8.4, 3.4, 4.3 * side)))
		n.add_child(blob(Vector3(0.45, 0.8, 0.4), plain(Color("#100c08")), Vector3(9.0, 3.5, 4.8 * side)))
		n.add_child(blob(Vector3(0.4, 0.3, 0.3), plain(INK), Vector3(12.6, 1.2, 1.4 * side)))   # nostrils
	_newt_spots(n, m, [[Vector3(5.0, 0.6, 0), Vector3(8.0, 3.6, 6.4)]], 0.7)
	if m.crest != null:
		n.add_child(cone(0.1, 1.0, 2.4, m.crest, Vector3(1.0, 4.4, 0), Vector3(0, 0, 18), 6))
	n.add_child(ring(5.2, 5.9, plain(c.team), Vector3(3.6, 0.8, 0), Vector3(0, 0, 90), Vector3(1, 0.62, 1.15)))   # browband
	n.add_child(ring(3.0, 3.5, surf("leather", Color.WHITE, 3.0), Vector3(9.8, 0.2, 0), Vector3(0, 0, 90), Vector3(1, 0.75, 1.4)))   # noseband
	return {"node": n, "sockets": {"top": Vector3(3.0, 3.6, 0)}}


## A sprawling leg: the upper limb out to the side and up, the forearm down, a splayed hand.
func _newt_leg(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var m := _newt_mats(c)
	var elbow := Vector3(1.8, 1.4, 6.0)
	var wrist := Vector3(3.4, -5.6, 8.0)
	n.add_child(rod(Vector3.ZERO, elbow, 3.0, 2.4, m.skin))
	n.add_child(rod(elbow, wrist, 2.3, 1.7, m.skin))
	for t in 4:
		var toe := wrist + Vector3(3.2, -1.2, (t - 1.5) * 1.5)
		n.add_child(rod(wrist + Vector3(0, -0.6, 0), toe, 0.75, 0.55, m.skin))
		n.add_child(blob(Vector3.ONE * 0.6, m.belly, toe))
	return {"node": n}


# ------------------------------------------------------------------ weapons

## A pole arm: shaft from a to b, and a flat head past b.
func _pole(n: Node3D, a: Vector3, b: Vector3, r: float, head: Array, head_mat: Material) -> Vector3:
	n.add_child(rod(a, b, r, r * 0.95, surf("wood_grain", Color.WHITE, 8.0), false))
	var d := (b - a).normalized()
	n.add_child(blade(head, 0.8, head_mat, b, atan2(d.y, d.x)))
	n.add_child(ring(r * 0.8, r * 1.4, head_mat, b - d * 0.4, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return d


func _weapon_pike_iron(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	_pole(n, Vector3(5, -5, 0), Vector3(-13, 27, 0), 0.85, [Vector2(0, -1.3), Vector2(8, 0), Vector2(0, 1.3), Vector2(-1, 0)], surf("iron", Color.WHITE, 3.0))
	return {"node": n}


func _weapon_dory(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var d := _pole(n, Vector3(-8, -5, 0), Vector3(20, 11, 0), 0.85, [Vector2(0, -1.8), Vector2(3, -1.6), Vector2(7, 0), Vector2(3, 1.6), Vector2(0, 1.8), Vector2(-1.2, 0)], bronze)
	n.add_child(rod(Vector3(-8, -5, 0), Vector3(-8, -5, 0) - d * 3.0, 0.9, 0.3, bronze))   # the butt spike
	return {"node": n}


func _weapon_pilum(c: Dictionary) -> Dictionary:
	# Raised steeply over the shoulder, a slim shaft and a long bare iron shank with a small
	# point: held level and thick, with a lump at the grip, it read as a rifle (Dominic).
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var d := Vector3(0.62, 0.78, 0)   # gripped at its balance, tip up and forward, ready to throw
	var a := -d * 4.0   # little behind the hand, so the shank and point clear the helmet
	var b := d * 10.0
	n.add_child(rod(a, b, 0.55, 0.55, surf("wood_grain", Color.WHITE, 6.0), false))
	var tip := b + d * 10.0
	n.add_child(rod(b, tip, 0.35, 0.3, iron, false))
	n.add_child(ring(0.45, 0.7, iron, b, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))   # the binding
	n.add_child(blade([Vector2(0, -0.9), Vector2(2.6, 0), Vector2(0, 0.9)], 0.8, iron, tip, atan2(d.y, d.x)))
	return {"node": n}


func _weapon_lance(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-10, -2, 0)
	var b := Vector3(26, 4, 0)
	var d := (b - a).normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(rod(a, b, 1.3, 0.7, surf("wood_grain", Color.WHITE, 8.0), false))
	n.add_child(cone(0.9, 3.0, 2.4, surf("iron", Color.WHITE, 3.0), a + d * 12.0, Vector3(0, 0, rad_to_deg(ang) + 90)))   # vamplate
	n.add_child(blade([Vector2(0, -0.9), Vector2(5, 0), Vector2(0, 0.9)], 1.0, surf("iron", Color.WHITE, 3.0), b, ang))
	n.add_child(blade([Vector2(0, 0), Vector2(-6.5, -0.6), Vector2(-4.5, -2.0), Vector2(-6.5, -3.6), Vector2(-0.5, -3.4)], 0.3, surf("cloth", c.team, 4.0), b - d * 2.5, ang))   # pennon
	return {"node": n}


func _weapon_club_bone(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bone := surf("bone", Color.WHITE, 4.0)
	n.add_child(rod(Vector3(-2, -2, 0), Vector3(6, 8.5, 0), 1.2, 1.8, bone))
	n.add_child(blob(Vector3(3.0, 3.2, 2.8), bone, Vector3(6.6, 10, 0)))
	for k in 3:
		n.add_child(blob(Vector3(1.0, 1.0, 1.0), bone, Vector3(6.6, 10, 0) + Vector3(cos(k * 2.1), sin(k * 2.1), 0.6) * 2.8))
	n.add_child(ring(1.2, 1.8, surf("leather", Color.WHITE, 3.0), Vector3(-0.8, -0.4, 0), Vector3(0, 0, -36)))
	return {"node": n}


## A sword: blade outline along +x before turning, a guard across it, grip and pommel.
func _sword(blade_pts: Array, tip: Vector3, metal: Material, fittings: Material) -> Node3D:
	var n := Node3D.new()
	var d := tip.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(blade_pts, 0.6, metal, Vector3.ZERO, ang))
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(-across * 3.0 + Vector3(0, 0, 0.6), across * 3.0 - Vector3(0, 0, 0.6), 0.55, 0.55, fittings))
	n.add_child(rod(Vector3.ZERO, -d * 3.0, 0.6, 0.6, surf("leather", Color.WHITE, 2.0), false))
	n.add_child(blob(Vector3(0.9, 0.9, 0.9), fittings, -d * 3.6))
	return n


func _weapon_sword_bronze(c: Dictionary) -> Dictionary:
	var bronze := surf("bronze", Color.WHITE, 3.0)
	return {"node": _sword([Vector2(0, -1.0), Vector2(8, -1.5), Vector2(14.4, 0), Vector2(8, 1.5), Vector2(0, 1.0)], Vector3(3, 14, 0), bronze, surf("wood_grain", Color.WHITE, 3.0))}


func _weapon_sword_iron(c: Dictionary) -> Dictionary:
	var iron := surf("iron", Color.WHITE, 3.0)
	return {"node": _sword([Vector2(0, -1.1), Vector2(13.5, -0.9), Vector2(15.4, 0), Vector2(13.5, 0.9), Vector2(0, 1.1)], Vector3(3, 15, 0), iron, iron)}


func _weapon_gladius(c: Dictionary) -> Dictionary:
	return {"node": _sword([Vector2(0, -1.4), Vector2(5, -1.2), Vector2(8.5, -1.4), Vector2(11.2, 0), Vector2(8.5, 1.4), Vector2(5, 1.2), Vector2(0, 1.4)],
		Vector3(2, 11, 0), surf("iron", Color.WHITE, 3.0), surf("bronze", Color.WHITE, 2.0))}


# ------------------------------------------------------------------ the swordsman's age-3 kit (S3, D-125)
# Dominic's picks from concept round S3 (docs/concepts/sword3/README.md): one weapon per culture
# (and a helmet for hellenic and steppe), held in the swordsman's "low" hold like every sword: the
# origin is the grip, the blade runs along SWORD3_TIP. Each is longer, brighter or heavier than
# the age-2 bronze sword (14.4 long, 1.5 wide, dull bronze), so the step reads at game scale.

const SWORD3_TIP := Vector3(3, 14, 0)   # the bronze sword's line (the hold is the same)


## A blade outline bent along a curve: `length` along +x, the centre line rising `sag` (towards
## the back of the hand: a sabre's curve) at the tip, half-width w(t) from `widths` sampled at
## t = 0..1. `edge` 0 = both edges round the centre line; 1 = the spine stays on the centre line
## (a single-edged blade, the edge on -y).
func curved(length: float, sag: float, widths: Array, edge := 0.0, steps := 14) -> Array:
	var top := []
	var bottom := []
	for i in steps + 1:
		var t := float(i) / steps
		var w: float = _sample(widths, t)
		var cy := sag * t * t
		var x := length * t
		top.append(Vector2(x, cy + w * (1.0 - edge)))
		bottom.append(Vector2(x, cy - w * (1.0 + edge)))
	bottom.reverse()
	if top[-1].distance_to(bottom[0]) < 0.05:
		bottom.pop_front()
	return top + bottom


func _sample(ws: Array, t: float) -> float:
	var f := t * (ws.size() - 1)
	var i := mini(int(f), ws.size() - 2)
	return lerpf(ws[i], ws[i + 1], f - i)


## The grip end the age-3 weapons share: a wrapped grip down the line from the hand and a pommel.
func grip(n: Node3D, d: Vector3, wrap: Material, pommel: Material, length := 3.0) -> void:
	n.add_child(rod(Vector3.ZERO, -d * length, 0.6, 0.6, wrap, false))
	n.add_child(blob(Vector3(0.95, 0.95, 0.95), pommel, -d * (length + 0.6)))


## A tassel hanging from the pommel (team cloth): it swings out behind the hand.
func tassel(n: Node3D, d: Vector3, m: Material, length := 3.0) -> void:
	var at := -d * 3.8
	n.add_child(rod(at, at + Vector3(-1.2, -length, 0.4), 0.45, 0.8, m))
	n.add_child(blob(Vector3(0.7, 1.2, 0.7), m, at + Vector3(-1.3, -length - 0.6, 0.4)))


## Polished steel: the iron texture's grain over a pale tint, a little sheen (the plain iron
## tint bakes dark grey at game scale, as dark as the bronze it should outshine).
func _bright_iron(units := 3.0) -> StandardMaterial3D:
	var m := surf("iron", Color(2.2, 2.25, 2.4), units)
	m.metallic_specular = 0.7
	m.roughness = 0.55
	return m


## The fallback: the iron sword's blade in polished steel, iron fittings (no royal kit).
func _weapon_sword_iron_plain(c: Dictionary) -> Dictionary:
	return {"node": _sword([Vector2(0, -1.1), Vector2(13.5, -0.9), Vector2(15.4, 0), Vector2(13.5, 0.9), Vector2(0, 1.1)],
		Vector3(3, 15, 0), _bright_iron(), surf("iron", Color.WHITE, 3.0))}


## Hellenic: a long leaf-bladed iron xiphos (worn with the Attic helmet).
func _weapon_sword_xiphos(c: Dictionary) -> Dictionary:
	var pts := [Vector2(0, -0.9), Vector2(5, -1.0), Vector2(11.5, -1.9), Vector2(15.5, -1.2), Vector2(18.2, 0),
		Vector2(15.5, 1.2), Vector2(11.5, 1.9), Vector2(5, 1.0), Vector2(0, 0.9)]
	return {"node": _sword(pts, SWORD3_TIP, _bright_iron(), surf("bronze", Color(1.2, 1.1, 0.85), 2.0))}


## The Attic helmet: polished bronze, an open face with a brow peak, cheek pieces, and a tall
## crest held high on a stand in the team colour, so the age-3 Greek stands a head taller.
func _helm_attic(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color(1.2, 1.1, 0.85), 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.5, surf("bronze", Color(1.35, 1.25, 1.0), 2.0), Vector3(0, -3.5, 0)))
	n.add_child(blob(Vector3(2.0, 0.5, 4.0), bronze, Vector3(4.4, -2.6, 0), Vector3(0, 0, -12)))   # the brow peak
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.0, 2.8, 0.6), bronze, Vector3(2.0, -6.0, 4.4 * side), Vector3(0, 0, 10)))
	n.add_child(blob(Vector3(2.8, 3.0, 4.4), bronze, Vector3(-2.8, -5.8, 0)))
	n.add_child(rod(Vector3(0, 1.0, 0), Vector3(-0.4, 4.2, 0), 0.55, 0.55, bronze))   # the crest stand
	crest(n, c.team, Vector3(-1.4, 4.6, 0), 14.0, 8.0)
	_lift(n, 0.8)   # the brow peak clear of a human's brows (placement A2): the concept sat it too low
	return {"node": n}


## Raise a built piece of head gear by `dy` (every child: the parts and their crest).
func _lift(n: Node3D, dy: float) -> void:
	for ch in n.get_children():
		ch.position.y += dy


## Steppe: a heavier curved sword that flares wide before the point (a back-edge at the tip),
## a brass cross-guard (worn with the spiked helmet).
func _weapon_sword_flared_sabre(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := SWORD3_TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(17.0, 3.2, [1.1, 1.1, 1.2, 1.9, 2.0, 0.0], 0.3), 0.6, _bright_iron(), Vector3.ZERO, ang))
	var across := Vector3(-d.y, d.x, 0)
	var brass := surf("bronze", Color(1.2, 1.1, 0.8), 2.0)
	n.add_child(rod(-across * 2.8, across * 2.8, 0.6, 0.6, brass))
	grip(n, d, surf("leather", Color.WHITE, 2.0), brass)
	return {"node": n}


## The steppe helmet: a tall iron cone with a spike and a team tuft, a mail curtain round the neck.
func _helm_steppe_spike(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color(0.85, 0.85, 0.9), 3.0)   # brighter baked as a white blob
	n.add_child(cone(0.7, 5.1, 6.0, iron, Vector3(0, 0.1, 0)))
	n.add_child(ring(4.9, 5.6, surf("bronze", Color.WHITE, 2.0), Vector3(0, -2.8, 0)))
	n.add_child(rod(Vector3(0, 2.9, 0), Vector3(0, 6.0, 0), 0.7, 0.25, surf("bronze", Color(1.2, 1.1, 0.85), 2.0)))   # the spike
	# The tuft streams back from the spike's foot (standing up beside it, it ran into a banner's flag).
	n.add_child(blob(Vector3(1.1, 2.8, 1.1), plain(c.team), Vector3(-2.0, 3.0, 0), Vector3(0, 0, 60)))
	var mail := surf("mail", Color(0.7, 0.7, 0.75), 2.0)
	# The mail neck guard at the sides and back quarters (the concept's all-round curtain hung over
	# the brows; one straight behind ran into a banner's pole).
	for a in [PI * 0.55, PI * 0.78, PI * 1.22, PI * 1.45]:
		n.add_child(blob(Vector3(1.9, 2.6, 0.45), mail, Vector3(cos(a) * 5.0 - 0.6, -4.4, sin(a) * 5.0), Vector3(0, -rad_to_deg(a), 0)))
	return {"node": n}


## Swamp: a heavy river-stone mace: a pale driftwood haft and a big smooth grey stone lashed on.
func _weapon_mace_river_stone(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := SWORD3_TIP.normalized()
	var deg := rad_to_deg(atan2(d.y, d.x))
	n.add_child(rod(-d * 2.5, d * 12.5, 0.7, 0.9, surf("wood_grain", Color(1.15, 1.05, 0.9), 3.0)))
	n.add_child(blob(Vector3(3.0, 2.3, 2.4), surf("rock", Color(0.95, 0.95, 0.92), 2.5), d * 13.0 + Vector3(0.6, 0, 0), Vector3(0, 0, deg)))
	var cord := surf("cloth", Color("#8a7a4a"), 2.0)
	for k in 2:   # the lashings round stone and haft
		n.add_child(ring(2.1, 2.5, cord, d * (11.6 + k * 2.6) + Vector3(0.4, 0, 0), Vector3(90, 0, deg - 90), Vector3(1.0, 1.0, 1.1)))
	n.add_child(ring(0.8, 1.2, cord, -d * 0.4, Vector3(0, 0, deg - 90)))
	return {"node": n}


## Forest: a chitin-edged blade: a dark heartwood blade with overlapping shards of bright
## green-blue beetle shell along both edges, a shell guard.
func _weapon_sword_chitin(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := SWORD3_TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(16.5, 0.0, [1.0, 1.3, 1.3, 1.0, 0.0]), 0.8, surf("wood_grain", Color(0.6, 0.45, 0.32), 3.0), Vector3.ZERO, ang))
	var shell := surf("chitin", Color("#4fd0a0"), 2.0)
	var across := Vector3(-d.y, d.x, 0)
	for k in 6:
		var t := 2.0 + k * 2.4
		var w := 1.3 if k < 4 else 1.3 - (k - 3) * 0.4
		for side in [1, -1]:
			n.add_child(blade([Vector2(-1.4, 0), Vector2(0, -0.8), Vector2(1.6, 0), Vector2(0, 0.8)], 0.5, shell,
				d * t + across * side * w, ang + 0.25 * side))
	n.add_child(blade([Vector2(0, -1.0), Vector2(3.0, 0), Vector2(0, 1.0)], 0.6, shell, d * 16.0, ang))   # the point
	n.add_child(blob(Vector3(1.2, 3.2, 1.6), shell, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang))))   # the guard
	grip(n, d, surf("leather", Color.WHITE, 2.0), shell)
	return {"node": n}


## Spooky: a hooked sickle blade: pale silvered iron, straight for most of its length, then a big
## hook curling forward; the grip wound in white web silk.
func _weapon_sword_hook(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := SWORD3_TIP.normalized()
	var ang := atan2(d.y, d.x)
	var steel := _bright_iron(2.5)
	var pts := [Vector2(0, -0.9), Vector2(11, -1.1), Vector2(14, -1.6), Vector2(16.4, -0.6), Vector2(17.4, 1.6), Vector2(16.4, 3.8),
		Vector2(14.2, 4.8), Vector2(13.4, 3.8), Vector2(15.0, 2.6), Vector2(15.2, 1.0), Vector2(13.6, 0.4), Vector2(11, 0.9), Vector2(0, 0.9)]
	for i in pts.size():   # the hook forward (the blade's -y is the front)
		pts[i] = Vector2(pts[i].x, -pts[i].y)
	pts.reverse()
	n.add_child(blade(pts, 0.6, steel, Vector3.ZERO, ang))
	var silk := surf("cloth", Color("#f2f0ea"), 2.0)
	for k in 4:
		n.add_child(ring(0.55, 0.95, silk, -d * (0.4 + k * 0.7), Vector3(0, 0, rad_to_deg(ang) - 90)))
	n.add_child(blob(Vector3(1.0, 1.0, 1.0), steel, -d * 3.4))
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(-across * 2.2, across * 2.2, 0.5, 0.5, steel))
	return {"node": n}


## Han: the dao: a broad single-edged sabre, curving gently and widest near the tip, a disc
## guard, a ring pommel with a crimson cloth.
func _weapon_sword_dao(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var d := SWORD3_TIP.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade(curved(16.5, 1.8, [1.1, 1.3, 1.6, 2.0, 1.6, 0.0], 0.5), 0.6, _bright_iron(), Vector3.ZERO, ang))
	var bronze := surf("bronze", Color(1.2, 1.1, 0.85), 2.0)
	n.add_child(cone(1.8, 1.8, 0.5, bronze, Vector3.ZERO, Vector3(0, 0, rad_to_deg(ang) - 90)))
	n.add_child(rod(Vector3.ZERO, -d * 3.4, 0.6, 0.6, surf("cloth", Color("#3a2a20"), 2.0), false))
	n.add_child(ring(0.7, 1.2, bronze, -d * 4.4, Vector3(90, 0, rad_to_deg(ang) - 90)))   # the ring pommel
	var red := surf("cloth", c.crimson, 2.0)
	n.add_child(rod(-d * 4.6, -d * 4.6 + Vector3(-1.4, -3.2, 0.4), 0.4, 1.0, red))
	return {"node": n}


func _weapon_bow_short(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Pale wood, thick limbs and a bright string: it has to stand out against dark armour
	# (a dark bow vanished, and testers called the archer a spearman).
	var wood := surf("wood_grain", Color("#e8c48a"), 4.0)
	# Held out at its leather grip (the origin), the string drawn back towards the face.
	var g := Vector3(5.7, 0, 0)
	var pts := [Vector3(3.8, -13.6, 0), Vector3(2, -12, 0), Vector3(5.5, -6, 0), Vector3(6.6, 0, 0), Vector3(5.5, 6, 0), Vector3(2, 12, 0), Vector3(3.8, 13.6, 0)]
	for k in range(1, pts.size()):
		var r := 1.15 if k in [3, 4] else 0.85
		n.add_child(rod(pts[k - 1] - g, pts[k] - g, r, r, wood))
	var nock := Vector3(-3.5, 0, 0) - g
	n.add_child(rod(Vector3(2, -12, 0) - g, nock, 0.25, 0.25, plain(Color("#f8f2e0")), false))
	n.add_child(rod(nock, Vector3(2, 12, 0) - g, 0.25, 0.25, plain(Color("#f8f2e0")), false))
	n.add_child(rod(nock, Vector3(9, 0, 0) - g, 0.3, 0.3, surf("wood_grain", Color.WHITE, 2.0), false))   # the arrow
	n.add_child(cone(1.05, 1.05, 2.4, surf("leather", Color.WHITE, 2.0), Vector3.ZERO, Vector3(0, 0, 8)))
	return {"node": n}


func _weapon_musket(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(slab([Vector2(-5, -2.2), Vector2(-4, 0.6), Vector2(14, 3.6), Vector2(14, 2.0), Vector2(-1, -0.6), Vector2(-2, -2.6)], 1.6, surf("wood_grain", Color.WHITE, 5.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(5, 2.4, 0), Vector3(19.5, 5.3, 0), 0.75, 0.7, iron, false))
	n.add_child(ring(0.7, 1.0, iron, Vector3(18.6, 5.1, 0), Vector3(0, 0, -79)))
	n.add_child(blob(Vector3(1.2, 0.8, 0.9), iron, Vector3(3.5, 2.0, 0.6)))   # the lock
	return {"node": n}


func _tool_sack(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var sack := surf("cloth", c.cloth2.lerp(Color("#c8b48a"), 0.55), 3.0)
	n.add_child(blob(Vector3(3.8, 4.6, 3.4), sack, Vector3(0, -2.6, 0)))
	n.add_child(cone(0.9, 2.0, 1.8, sack, Vector3(0, 2.0, 0)))
	n.add_child(ring(0.8, 1.3, surf("leather", Color.WHITE, 2.0), Vector3(0, 2.2, 0)))
	n.add_child(blob(Vector3(1.4, 0.9, 1.3), sack, Vector3(0, 3.3, 0)))
	return {"node": n}


## The sapper's charge: a PLACEHOLDER, the worker's sack, until Dominic picks from concept round SP1
## (docs/concepts/sapper/; options in scenes/art_pixel/m13_concepts.gd).
func _tool_charge(c: Dictionary) -> Dictionary:
	return _scaled(_tool_sack(c), 0.5)   # (smaller: at full size it cut through a beetle's head and a spider's legs in the blow)


# ------------------------------------------------------------------ shields

const SHIELD_FACE := Vector3(1.0, 0.1, 0.45)


func _shield_round(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var iron := surf("iron", Color.WHITE, 3.0)
	h.add_child(disc(6.0, 1.0, surf("wood_grain", Color.WHITE, 4.0), 0))
	h.add_child(disc(3.4, 0.3, plain(c.team), 0.55))
	h.add_child(ring(5.6, 6.5, iron, Vector3.ZERO, Vector3(90, 0, 0)))
	h.add_child(blob(Vector3(1.6, 1.6, 1.1), iron, Vector3(0, 0, 0.7)))
	return {"node": n}


func _shield_kite(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var outline := [Vector2(-1, 8), Vector2(5, 6), Vector2(4, -4), Vector2(0, -9), Vector2(-4, -4), Vector2(-4, 6)]
	var body := slab(outline, 0.8, plain(c.team))
	body.position.x = -0.5
	h.add_child(body)
	var iron := surf("iron", Color.WHITE, 3.0)
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		h.add_child(rod(Vector3(a.x - 0.5, a.y, 0.3), Vector3(b.x - 0.5, b.y, 0.3), 0.35, 0.35, iron))
	h.add_child(rod(Vector3(0, 7, 0.5), Vector3(-0.5, -7.5, 0.5), 0.35, 0.35, iron))
	h.add_child(rod(Vector3(-3.5, 3, 0.5), Vector3(4, 3, 0.5), 0.35, 0.35, iron))
	return {"node": n}


func _shield_scutum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var bronze := surf("bronze", Color.WHITE, 3.0)
	var team := plain(c.team)
	var R := 6.0
	for i in 5:   # curved: five strips round a vertical axis behind the shield
		var a := deg_to_rad((i - 2) * 17.0)
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.85, 17, 0.6)
		strip.mesh = bm
		strip.material_override = team
		strip.position = Vector3(sin(a) * R, 0, cos(a) * R - R)
		strip.rotation.y = a
		h.add_child(strip)
	for y in [8.5, -8.5]:
		for i in 5:
			var a := deg_to_rad((i - 2) * 17.0)
			h.add_child(rod(Vector3(sin(a - 0.15) * R, y, cos(a - 0.15) * R - R + 0.2), Vector3(sin(a + 0.15) * R, y, cos(a + 0.15) * R - R + 0.2), 0.35, 0.35, bronze))
	h.add_child(blob(Vector3(1.7, 1.7, 1.1), bronze, Vector3(0, 0, 0.5)))
	h.add_child(rod(Vector3(0, 7.8, 0.4), Vector3(0, 1.7, 0.4), 0.3, 0.3, bronze))
	h.add_child(rod(Vector3(0, -1.7, 0.4), Vector3(0, -7.8, 0.4), 0.3, 0.3, bronze))
	return {"node": n}


func _shield_hoplon(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	var bronze := surf("bronze", Color.WHITE, 3.0)
	h.add_child(disc(6.8, 1.4, bronze, 0))
	h.add_child(disc(4.6, 0.3, plain(c.team), 0.75))
	h.add_child(ring(6.3, 7.5, bronze, Vector3(0, 0, 0.3), Vector3(90, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ helmets (around the head's top socket)

func _helm_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.7, 5.5, bronze, Vector3(0, -3.6, 0)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.5, 2.4, 0.5), bronze, Vector3(2.0, -5.4, 4.3 * side)))
	n.add_child(rod(Vector3(0, 0.8, 0), Vector3(0, 2.0, 0), 0.5, 0.5, bronze))
	crest(n, c.team, Vector3(-0.3, 1.6, 0), 8.0, 4.0)
	_lift(n, 1.05)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


func _helm_iron(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(cone(0.5, 5.2, 6.2, iron, Vector3(0, -0.9, 0)))
	n.add_child(blob(Vector3(0.8, 0.6, 0.8), iron, Vector3(0, 2.3, 0)))
	n.add_child(ring(5.0, 5.7, iron, Vector3(0, -3.9, 0)))
	n.add_child(rod(Vector3(5.4, -3.6, 0), Vector3(5.6, -7.6, 0), 0.55, 0.45, iron))   # nose guard
	return {"node": n}


func _helm_horned(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bone := surf("bone", Color.WHITE, 3.0)
	n.add_child(dome(Vector3(5.0, 5.2, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.7, 5.5, iron, Vector3(0, -3.6, 0)))
	n.add_child(rod(Vector3(-5, -1.0, 0), Vector3(5, -1.0, 0), 0.5, 0.5, iron))
	for side in [1, -1]:
		var pts := [Vector3(0.5, -1.5, 4.4 * side), Vector3(0.5, 0.5, 7.2 * side), Vector3(0.2, 3.8, 8.4 * side), Vector3(-0.4, 6.4, 8.0 * side)]
		var r := [1.4, 1.1, 0.7, 0.3]
		for k in range(1, pts.size()):
			n.add_child(rod(pts[k - 1], pts[k], r[k - 1], r[k], bone))
	_lift(n, 1.05)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


func _helm_galea(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 3.0)
	var bronze := surf("bronze", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), iron, Vector3(0, -3.8, 0)))
	n.add_child(ring(4.8, 5.4, bronze, Vector3(0.3, -2.8, 0)))   # brow band
	n.add_child(blob(Vector3(3.0, 0.6, 5.0), iron, Vector3(-4.0, -4.2, 0), Vector3(0, 0, -25)))   # neck guard
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.6, 2.6, 0.5), iron, Vector3(2.0, -5.6, 4.3 * side)))
	crest(n, c.crimson, Vector3(-0.2, 1.0, 0), 9.0, 4.5)
	return {"node": n}


func _helm_corinthian(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color(0.82, 0.74, 0.62), 3.0)
	var bright := surf("bronze", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(5.0, 5.0, 4.8), bronze, Vector3(0, -3.6, 0)))
	n.add_child(ring(4.8, 5.4, bright, Vector3(0, -3.5, 0)))
	# Cheek guards sweep down each side, leaving the T-shaped opening: eyes, nose, mouth show.
	for side in [1, -1]:
		n.add_child(blob(Vector3(2.4, 3.6, 0.7), bronze, Vector3(2.4, -6.6, 4.2 * side), Vector3(0, 0, 8)))
	n.add_child(rod(Vector3(4.9, -3.4, 0), Vector3(5.2, -6.8, 0), 0.7, 0.55, bronze))   # nose guard
	n.add_child(blob(Vector3(3.0, 3.6, 4.4), bronze, Vector3(-2.6, -6.2, 0)))   # the back of the neck
	n.add_child(rod(Vector3(0, 1.0, 0), Vector3(0, 2.0, 0), 0.5, 0.5, bright))
	crest(n, c.team, Vector3(-0.4, 1.6, 0), 9.0, 4.5)
	return {"node": n}


# ------------------------------------------------------------------ armour (frog-sized; bodies scale it)

func _armour_leather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color.WHITE, 5.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), leather, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	# The belt hugs the jerkin where it is at that height (a wider ring floated off the body as a
	# dark hoop round the belly; so did the old shoulder straps).
	n.add_child(ring(0.97, 1.1, surf("leather", Color("#5a3a20"), 3.0), Vector3(1.4, -5.0, 0), Vector3(0, 0, -10), Vector3(6.6, 1.0, 7.8)))
	return {"node": n}


func _armour_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color.WHITE, 4.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), bronze, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	for side in [1, -1]:   # the muscled chest
		n.add_child(blob(Vector3(3.2, 2.6, 3.8), bronze, Vector3(7.6, 2.6, 3.6 * side)))
	n.add_child(blob(Vector3(2.4, 3.6, 2.4), bronze, Vector3(8.4, -2.8, 0)))
	var flaps := surf("leather", Color.WHITE, 3.0)
	for k in 7:   # leather strips below
		var a := deg_to_rad(-75 + k * 25)
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 4.0, 2.6)
		strip.mesh = bm
		strip.material_override = flaps
		strip.position = Vector3(cos(a) * 8.2 + 1.0, -8.5, sin(a) * 9.6)
		strip.rotation.y = -a
		n.add_child(strip)
	return {"node": n}


func _armour_lorica(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 4.0)
	var dark := surf("iron", Color(0.62, 0.64, 0.68), 3.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), iron, Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))
	for y in [-5.0, -2.0, 1.0, 4.0]:   # overlapping bands
		var k := sqrt(1.0 - pow(y / 8.6, 2))
		n.add_child(ring(8.3 * k, 9.4 * k, dark, Vector3(1.5, y + 0.5, 0), Vector3(0, 0, -10), Vector3(1, 1, 10.4 / 8.8)))
	for side in [1, -1]:
		n.add_child(blob(Vector3(4.2, 2.0, 4.0), iron, Vector3(0.5, 7.0, 6.6 * side), Vector3(20 * side, 0, 0)))
	return {"node": n}


# ------------------------------------------------------------------ backs

func _cape_cloth(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	# Two panels hanging close down the back from the shoulders: a cape, not a flag (wide panels
	# fanned out behind and read as a board stuck to the unit).
	var cloth := surf("cloth", c.team, 4.0)
	for side in [1, -1]:
		var panel := slab([Vector2(2, 1), Vector2(3, -1), Vector2(0.5, -14), Vector2(-2.5, -14.5), Vector2(-4, -10.5), Vector2(-1.5, 0.5)], 0.6, cloth)
		panel.position = Vector3(0, 0, 3.0 * side)
		panel.rotation_degrees = Vector3(0, -10 * side, 0)
		n.add_child(panel)
	n.add_child(blob(Vector3(1.0, 1.0, 0.6), surf("bronze", Color.WHITE, 2.0), Vector3(1.5, 0, 1.2)))   # clasp
	return {"node": n}


func _banner_team(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(0, -4, 0), Vector3(0, 22, 0), 0.5, 0.45, surf("wood_grain", Color.WHITE, 5.0), false))
	n.add_child(blob(Vector3(0.9, 1.2, 0.9), surf("bronze", Color.WHITE, 2.0), Vector3(0, 22.8, 0)))
	n.add_child(rod(Vector3(-0.3, 21.2, 0), Vector3(9.6, 21.2, 0), 0.3, 0.3, surf("wood_grain", Color.WHITE, 3.0)))
	n.add_child(slab([Vector2(0.3, 21), Vector2(9.3, 21), Vector2(9.3, 13.2), Vector2(7.0, 15.4), Vector2(4.8, 13.2), Vector2(0.3, 14.4)], 0.4, surf("cloth", c.team, 4.0)))
	n.add_child(blob(Vector3(1.6, 1.6, 0.5), plain(Color("#e8e4d8")), Vector3(4.8, 17.6, 0.3)))
	return {"node": n}


func _quiver(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color.WHITE, 3.0)
	n.add_child(cone(2.0, 1.6, 12.0, leather, Vector3(0, 2, 0)))
	n.add_child(ring(1.8, 2.4, surf("leather", Color("#5a3a20"), 2.0), Vector3(0, 7.8, 0)))
	n.add_child(ring(1.6, 2.1, surf("leather", Color("#5a3a20"), 2.0), Vector3(0, -2.5, 0)))
	var fletch := plain(Color("#e8e2d0"))
	for k in 4:
		var off := Vector3(cos(k * 1.7) * 0.8, 0, sin(k * 1.7) * 0.8)
		var top := Vector3(0, 11.5 + (k % 2) * 0.8, 0) + off
		n.add_child(rod(Vector3(0, 7, 0) + off, top, 0.2, 0.2, surf("wood_grain", Color.WHITE, 2.0), false))
		n.add_child(blob(Vector3(0.3, 1.4, 0.7), fletch, top - Vector3(0, 0.9, 0)))
	return {"node": n}


## Wings at the back: the near one fanned towards the viewer, the far one raised
## steeper behind it. Both are rooted at the shoulders and sweep back and up (the
## texture's root is its lower right, its tip the upper left). The far one used to sit
## with its root over the head, so it read as pointing forward.
func _wings(texture: String, tint: Color) -> Dictionary:
	var n := Node3D.new()
	n.scale = Vector3.ONE * 0.8   # full size, they hid the unit wearing them
	var x := Vector3(1, -0.3, -0.3).normalized()   # the far wing's picture axes: right...
	var y := Vector3(0.3, 1, 0).normalized()       # ...and up, so its tip goes back and steeply up
	var root := Vector3(0.5, 3.0, -4.0)
	n.add_child(decal(texture, 24, 24, root - x * 9.0 + y * 8.2, x.cross(y), true, y, tint.darkened(0.3)))
	n.add_child(decal(texture, 26, 26, Vector3(-10.7, 8.8, 2.0), Vector3(-0.15, 0.15, 1), true, Vector3.UP, tint))
	return {"node": n}


func _wings_feather(c: Dictionary) -> Dictionary:
	return _wings("wing_feather", Color.WHITE)


func _wings_bat(c: Dictionary) -> Dictionary:
	return _wings("wing_bat", Color.WHITE)


# ------------------------------------------------------------------ job tools and carried loads
# Shown on workers by the view: the tool for the job at hand, and what they carry home.

func _tool_hammer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(2.5, 8.5, 0), 0.7, 0.65, surf("wood_grain", Color.WHITE, 6.0)))
	var head := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.6, 2.2, 2.2)
	head.mesh = bm
	head.material_override = surf("iron", Color.WHITE, 3.0)
	head.position = Vector3(2.8, 9.2, 0)
	head.rotation.z = -0.28
	n.add_child(head)
	return {"node": n}


func _tool_pick(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(2.5, 9.5, 0), 0.7, 0.65, surf("wood_grain", Color.WHITE, 6.0)))
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(Vector3(2.6, 9.6, 0), Vector3(-2.2, 7.4, 0), 0.75, 0.3, iron))   # the point
	n.add_child(rod(Vector3(2.6, 9.6, 0), Vector3(7.4, 8.4, 0), 0.75, 0.35, iron))   # the blade
	return {"node": n}


## A bundle of cut reeds carried over the shoulder: the hand up at the shoulder holds its front
## end and the bundle lies back and down across the back, thick (many stems, two ties, the
## leafy tops fanning out behind), so it reads as a load and not a blade (Dominic: the first
## one, held out in the hand, was a green sword). Worn with the body's "raise" hold.
func _load_reeds(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var reed := surf("reed_stalk", Color(1.0, 0.92, 0.7), 5.0)
	var front := Vector3(3.0, 2.0, 0)
	var back := Vector3(-9.0, -10.0, 0)
	var axis := (back - front).normalized()
	var side := axis.cross(Vector3(0, 0, 1)).normalized()
	for k in 13:
		var a := k * TAU / 13.0
		var r := 1.0 + 1.1 * float(k % 3) / 2.0
		var off := side * cos(a) * r + Vector3(0, 0, 1) * sin(a) * r
		var fan := off * 0.35   # the stems spread a little towards the tops
		n.add_child(rod(front + off * 0.8 - axis * 0.8, back + off + fan, 0.45, 0.35, reed, false))
	var tie := surf("leather", Color.WHITE, 2.0)
	for f in [0.22, 0.6]:
		var at := front.lerp(back, f)
		n.add_child(ring(1.9, 2.7, tie, at, Vector3(0, 0, rad_to_deg(atan2(axis.y, axis.x)) + 90.0)))
	for k in 5:   # the leafy tops
		var a := k * TAU / 5.0
		var off := side * cos(a) * 2.0 + Vector3(0, 0, 1) * sin(a) * 2.0
		n.add_child(decal("reed_leaf", 1.2, 4.5, back + axis * 1.5 + off, Vector3(0.2, 0.3, 1), true, axis + off.normalized() * 0.5))
	return {"node": n}


## A rough block of stone carried on the shoulder, steadied by the hand up beside it (the
## body's "raise" hold), sitting behind the head: big enough to read at game size.
func _load_stone(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, 4.2, 4.6)
	mi.mesh = bm
	mi.material_override = surf("rock", Color(0.85, 0.82, 0.76), 3.0)
	mi.position = Vector3(-2.4, -2.0, 0)
	mi.rotation = Vector3(0.15, 0.4, 0.25)
	n.add_child(mi)
	return {"node": n}


## Gold carried home in a sack over the shoulder (the "raise" hold), its neck in the fist and
## the ore showing at the mouth.
func _load_gold(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var sack := surf("cloth", Color("#c8b48a"), 3.0)
	n.add_child(blob(Vector3(3.0, 3.6, 2.8), sack, Vector3(-2.6, -3.6, 0), Vector3(0, 0, -30)))
	n.add_child(rod(Vector3(0.2, 0.4, 0), Vector3(-1.2, -1.0, 0), 0.8, 1.1, sack))   # the neck, in the hand
	var gold := plain(Color("#f2c440"))
	for p in [Vector3(-1.0, -1.6, 1.4), Vector3(-2.2, -1.2, 1.2), Vector3(-3.4, -2.2, 1.6), Vector3(-1.8, -2.6, 2.2)]:
		n.add_child(blob(Vector3(0.75, 0.6, 0.7), gold, p))
	return {"node": n}


## Meat from a hunt carried home: a haunch slung over the shoulder, hanging down the back from
## the hand up at the shoulder, the bone end in the fist. Worn with the body's "raise" hold.
func _load_meat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var meat := plain(Color("#a8443a"))
	n.add_child(blob(Vector3(2.4, 3.8, 2.6), meat, Vector3(-2.2, -4.0, 0), Vector3(0, 0, -25)))
	n.add_child(blob(Vector3(1.4, 2.6, 2.0), plain(Color("#e8c8b0")), Vector3(-3.2, -4.6, 0.6), Vector3(0, 0, -25)))   # the fat
	var bone := plain(Color("#f0e8d8"))
	n.add_child(rod(Vector3(-0.8, -0.8, 0), Vector3(0.6, 1.2, 0), 0.55, 0.5, bone))
	n.add_child(blob(Vector3(0.9, 0.8, 0.9), bone, Vector3(0.7, 1.4, 0)))
	return {"node": n}


## A broom for sweeping round the house (idle chores): a long handle, a bundle of twigs at the foot.
func _tool_broom(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("wood_grain", Color.WHITE, 6.0)
	n.add_child(rod(Vector3(-1.5, 8.0, 0), Vector3(2.0, -3.5, 0), 0.55, 0.55, wood))
	var twig := surf("reed_stalk", Color(0.85, 0.75, 0.5), 5.0)
	for k in 7:
		var z := (k - 3) * 0.55
		n.add_child(rod(Vector3(2.0, -3.5, z * 0.4), Vector3(3.0 + (k - 3) * 0.35, -7.5, z), 0.4, 0.3, twig, false))
	n.add_child(ring(0.7, 1.2, surf("leather", Color.WHITE, 2.0), Vector3(1.9, -3.1, 0), Vector3(0, 0, -14)))
	return {"node": n}


## A hoe for tending the rows: a long handle with a flat iron blade turned down at the end.
func _tool_hoe(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(rod(Vector3(-1, -3.5, 0), Vector3(2.5, 10.5, 0), 0.6, 0.55, surf("wood_grain", Color.WHITE, 6.0)))
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.6, 0.4, 2.6)
	blade.mesh = bm
	blade.material_override = surf("iron", Color.WHITE, 3.0)
	blade.position = Vector3(4.0, 9.8, 0)
	blade.rotation.z = -0.5
	n.add_child(blade)
	return {"node": n}


# ------------------------------------------------------------------ first-age kit for everyone

## A fire-hardened wooden spear: a plain shaft, the point charred dark.
func _weapon_spear_wood(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-4, -8, 0)
	var b := Vector3(6, 19, 0)
	n.add_child(rod(a, b, 0.95, 0.85, surf("wood_grain", Color.WHITE, 6.0), false))
	var d := (b - a).normalized()
	n.add_child(rod(b, b + d * 4.0, 0.85, 0.1, surf("wood_grain", Color("#3a2a1e"), 3.0), false))
	n.add_child(ring(0.7, 1.15, surf("leather", Color.WHITE, 3.0), a + d * 9.0, Vector3(0, 0, rad_to_deg(atan2(d.y, d.x)) - 90)))
	return {"node": n}


## A padded leather cap with a rolled brim.
func _helm_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(0.9, 0.82, 0.72), 3.0)
	# Sits a little high with a brim of the cap's own leather: a low, darker brim ran across the
	# brows like a headband (Dominic: "the hairline").
	n.add_child(dome(Vector3(4.9, 3.6, 4.7), leather, Vector3(0, -2.5, 0)))
	n.add_child(ring(4.6, 5.1, surf("leather", Color(0.84, 0.76, 0.66), 2.0), Vector3(0, -2.5, 0)))
	n.add_child(blob(Vector3(0.6, 0.6, 0.6), leather, Vector3(0, 1.2, 0)))
	return {"node": n}


# ------------------------------------------------------------------ the rats' junk kit, by age (RB2)
# Never human bronze; head gear sits on the crown between the ears, which always show.
# Age 1 a thimble, age 2 tin, age 3 cutlery steel copying the Romans.

func _helm_thimble(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var brass := surf("bronze", Color(1.1, 1.0, 0.75), 1.2)
	n.add_child(cone(1.7, 2.2, 3.0, brass, Vector3(0.6, -0.4, 0), Vector3(0, 0, -12)))
	n.add_child(blob(Vector3(1.7, 0.6, 1.7), brass, Vector3(0.9, 1.1, 0)))
	n.add_child(ring(2.1, 2.5, brass, Vector3(0.4, -1.8, 0), Vector3(0, 0, -12)))
	return {"node": n}


func _helm_tin_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	n.add_child(dome(Vector3(4.0, 2.6, 2.5), tin, Vector3(0.6, -1.6, 0)))   # narrow: the ears stay out
	n.add_child(ring(0.97, 1.08, plain(Color("#6a6c66")), Vector3(0.6, -1.5, 0), Vector3.ZERO, Vector3(4.0, 1.0, 2.5)))
	n.add_child(blob(Vector3(0.7, 0.5, 0.7), tin, Vector3(0.6, 1.1, 0)))   # a rivet knob
	return {"node": n}


## Age 3 pride: a spoon's bowl as the helmet, its handle down the neck as a guard, and a
## toothbrush along the top as the crest (copying the Romans' crested helmet).
func _helm_spoon(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var steel := surf("iron", Color.WHITE, 2.0)
	n.add_child(dome(Vector3(4.4, 2.8, 2.6), steel, Vector3(0.8, -1.6, 0)))
	n.add_child(rod(Vector3(-3.2, -1.4, 0), Vector3(-6.2, -5.2, 0), 0.55, 0.45, steel))   # the handle as a neck guard
	n.add_child(rod(Vector3(-1.6, 1.5, 0), Vector3(3.6, 1.5, 0), 0.35, 0.35, plain(Color("#e8e0d0"))))   # toothbrush handle
	n.add_child(_box(Vector3(4.0, 1.6, 0.9), plain(c.crimson), Vector3(0.6, 2.6, 0)))   # bristles, in the crest's red
	return {"node": n}


## Sardine-tin bands as a segmented cuirass (age 3), fitted to the lean rat.
func _armour_sardine(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tin := surf("iron", Color(0.95, 0.97, 1.0), 2.0)
	var label := plain(Color("#c8a040"))
	var tilt := Node3D.new()   # follow the rat's forward hunch; torso armour is built ~1.6x and scaled down by the body
	tilt.scale = Vector3.ONE * 1.45   # the wearer's lean comes from its body now (torso_tilt)
	n.add_child(tilt)
	for k in 4:
		var y := 4.0 - k * 2.4
		tilt.add_child(cone(6.6 - k * 0.35, 6.9 - k * 0.35, 2.0, tin if k % 2 == 0 else label, Vector3(0.6, y, 0), Vector3.ZERO, 20))
	tilt.add_child(_box(Vector3(1.2, 0.5, 3.2), plain(Color("#6a6c66")), Vector3(7.0, 4.6, 0), Vector3(0, 0, -20)))   # the key, rolled
	return {"node": n}


## A shield cut from a can: a curved tall rectangle (copying the Roman scutum), a bottle-cap boss.
func _shield_can_scutum(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var tin := surf("iron", Color(0.95, 0.95, 1.0), 2.0)
	var R := 5.5
	for i in 5:   # a can cut open and curved, like the scutum; its label band in the team colour
		var a := deg_to_rad((i - 2) * 17.0)
		for part in [[tin, 6.0, 4.2], [plain(c.team), 4.4, -1.0], [tin, 4.2, -5.3]]:
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.75, part[1], 0.5)
			strip.mesh = bm
			strip.material_override = part[0]
			strip.position = Vector3(sin(a) * R, part[2], cos(a) * R - R)
			strip.rotation.y = a
			h.add_child(strip)
	h.add_child(cone(1.2, 1.4, 0.6, surf("bronze", Color.WHITE, 1.0), Vector3(0, 0.5, 0.4), Vector3(90, 0, 0), 14))   # a bottle-cap boss
	return {"node": n}


func _box(size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


## Age 2: the leather jerkin with bottle caps sewn on as scales.
func _armour_bottlecap(c: Dictionary) -> Dictionary:
	var spec := _armour_leather(c)
	var n: Node3D = spec.node
	var cap := surf("iron", Color(1.0, 0.92, 0.75), 1.0)
	var centre := Vector3(1.5, 0.5, 0)
	var radii := Vector3(8.8, 8.2, 10.4)
	for row in 3:
		for k in 5:
			var look := Vector3(1.0, 0.45 - row * 0.4, (k - 2) * 0.45).normalized()
			var p: Vector3 = on_surface(centre, radii, look, 0.2)
			var disc := cone(1.5, 1.7, 0.5, cap, p, Vector3.ZERO, 12)
			disc.look_at_from_position(p, p + look, Vector3.UP)
			disc.rotate_object_local(Vector3.RIGHT, PI / 2)
			n.add_child(disc)
	return spec


# ------------------------------------------------------------------ models from Blender
# Parts modelled by script in Blender (tools/blender/*.py, exported .glb) load at bake time;
# their materials are swapped by name for ours, so palettes and team colours still apply.

static var _glb_cache := {}


## A .glb from assets/models as a fresh Node3D, each material named in `mats` replaced.
func glb(name: String, mats: Dictionary) -> Node3D:
	return glb_file("res://assets/models/%s.glb" % name, mats)


## A modelled part from any .glb (a mod's: res://mods/<id>/models/..., user://mods/...), its named
## materials swapped for ours (mats: material name -> Material).
func glb_file(path: String, mats: Dictionary) -> Node3D:
	var name := path
	if not _glb_cache.has(name):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		assert(err == OK, "Can't load %s" % path)
		# Cached packed, not as a live node: a node outside the tree is never freed, so its meshes,
		# materials and render instances leaked at exit (Dominic: a wall of leak warnings on quit).
		var scene: Node = doc.generate_scene(state)
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK, "Can't pack %s" % path)
		scene.free()
		_glb_cache[name] = packed
	var n: Node3D = (_glb_cache[name] as PackedScene).instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for k in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(k)
			var key := src.resource_name if src != null else ""
			if mats.has(key):
				m.set_surface_override_material(k, mats[key])
	return n


## The game's materials for a mod's .glb, by the names of its materials: team, skin, skin2, cloth, cloth2
## (the unit's colours), glow_<hex> (lit, unshaded), or a texture's name (assets/art/textures:
## iron, bronze, leather, wood_grain, cloth...); any other keeps the .glb's own.
func mod_materials(path: String, c: Dictionary) -> Dictionary:
	var out := {}
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	assert(err == OK, "Can't load %s" % path)
	for m in state.get_materials():
		var n: String = m.resource_name
		if n in ["team", "skin", "skin2", "cloth", "cloth2"]:
			out[n] = surf("cloth", c[n], 3.0) if n.begins_with("cloth") else plain(c[n])
		elif n.begins_with("glow_"):
			out[n] = glow(Color(n.trim_prefix("glow_")))
		elif FileAccess.file_exists(TEX_DIR + n + ".svg"):
			out[n] = surf(n, Color.WHITE, 3.0)
	return out


# ------------------------------------------------------------------ the Nile, Han and Aztec kits (GC1, Dominic's pick)
# Head gear for ages 1-3 and a signature weapon and shield per culture, so each reads as itself
# from the first age (they wore the shared kit). Fitted to the Blender human head (crown at y 0,
# about 5 across). Head gear by age; shields from age 1; the Han halberd arms the spear
# line, the sword and the club the Heavy unit (Dominic).

const LINEN := Color("#ece4d0")


## Nile age 1: a linen head bag (khat), gathered behind.
func _helm_nile_khat(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var linen := surf("cloth", LINEN, 3.0)
	n.add_child(dome(Vector3(5.1, 3.6, 5.0), linen, Vector3(-0.2, -3.0, 0)))
	n.add_child(blob(Vector3(2.2, 2.6, 2.4), linen, Vector3(-4.6, -3.6, 0), Vector3(0, 0, 25)))   # the gathered tail
	n.add_child(ring(4.9, 5.3, surf("cloth", Color("#c8b890"), 2.0), Vector3(0.1, -3.0, 0)))
	_lift(n, 0.20)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Nile age 2: a striped headcloth (team and linen), lappets falling in front of the shoulders.
func _helm_nile_headcloth(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var linen := surf("cloth", LINEN, 3.0)
	var team := plain(c.team)
	n.add_child(dome(Vector3(5.3, 3.8, 5.2), linen, Vector3(-0.2, -3.0, 0)))
	for k in 4:   # stripes round the crown, on the cloth's surface
		var y := 0.4 + k * 0.85
		var r := 5.25 * sqrt(1.0 - pow(y / 3.8, 2.0))
		n.add_child(ring(r - 0.3, r + 0.15, team, Vector3(-0.2, -3.0 + y, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.98)))
	for side in [1, -1]:   # the lappets
		n.add_child(blob(Vector3(1.6, 4.6, 1.1), linen, Vector3(0.6, -6.6, 4.6 * side), Vector3(15 * side, 0, 0)))
		n.add_child(blob(Vector3(1.65, 0.6, 1.15), team, Vector3(0.6, -7.6, 4.7 * side), Vector3(15 * side, 0, 0)))
	n.add_child(blob(Vector3(2.0, 4.0, 3.6), linen, Vector3(-3.9, -5.2, 0)))   # the cloth behind (close in: a banner's pole cut through it)
	return {"node": n}


## Nile age 3: a bronze helmet with a forward ridge and cheek guards over a linen cap.
func _helm_nile_bronze(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bronze := surf("bronze", Color(0.95, 0.88, 0.66), 2.0)
	n.add_child(dome(Vector3(5.2, 4.4, 5.1), bronze, Vector3(-0.2, -3.0, 0)))
	n.add_child(rod(Vector3(-4.2, -1.0, 0), Vector3(3.6, 1.0, 0), 0.6, 0.4, bronze))   # the ridge
	for side in [1, -1]:
		n.add_child(blob(Vector3(1.8, 2.6, 0.5), bronze, Vector3(1.6, -4.6, 4.6 * side)))
	n.add_child(blob(Vector3(2.0, 2.4, 3.6), surf("cloth", LINEN, 3.0), Vector3(-4.2, -4.6, 0)))
	n.add_child(ring(5.0, 5.5, plain(c.team), Vector3(-0.2, -3.0, 0)))
	_lift(n, 0.20)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Nile weapon: the sickle sword (khopesh).
func _weapon_khopesh(c: Dictionary) -> Dictionary:
	var bronze := surf("bronze", Color(1.15, 1.05, 0.8), 3.0)
	var pts := [Vector2(0, -0.8), Vector2(5.5, -0.8), Vector2(8.5, -2.8), Vector2(12.5, -3.0), Vector2(15.0, -0.8),
		Vector2(15.2, 2.2), Vector2(13.6, 3.6), Vector2(13.0, 1.4), Vector2(11.6, -0.4), Vector2(9.0, -0.2), Vector2(5.5, 0.9), Vector2(0, 0.9)]   # a deep hook
	return {"node": _sword(pts, Vector3(3, 14, 0), bronze, bronze)}


## Nile shield: tall, round-topped, cowhide (pale with brown patches) on a team rim.
func _shield_cowhide(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var outline := [Vector2(-4, -8), Vector2(4, -8), Vector2(4, 4)]
	for k in 9:
		var a := PI * k / 8.0
		outline.append(Vector2(cos(a) * 4.0, 4.0 + sin(a) * 4.2))
	outline.append(Vector2(-4, 4))
	h.add_child(slab(outline, 0.9, plain(Color("#e8cc98"))))   # tan hide (pale went grey in shade)
	var spot := plain(Color("#9a5a32"))   # a few broad red-brown patches (small dark spots read as holes)
	for p in [Vector2(-1.4, 3.0), Vector2(1.6, -3.4)]:
		h.add_child(blob(Vector3(2.2, 2.6, 0.3), spot, Vector3(p.x, p.y, 0.45)))
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		h.add_child(rod(Vector3(a.x, a.y, 0.3), Vector3(b.x, b.y, 0.3), 0.4, 0.4, plain(c.team)))
	return {"node": n}


## Han age 1: the hair in a topknot, tied with a team band.
func _helm_han_topknot(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var hair := surf("mane", Color("#3a2e26"), 3.0)
	n.add_child(dome(Vector3(4.9, 2.8, 4.8), hair, Vector3(-0.3, -2.6, 0)))
	n.add_child(blob(Vector3(1.7, 1.9, 1.7), hair, Vector3(-0.8, 1.0, 0)))   # the knot
	n.add_child(ring(1.3, 1.9, plain(c.team), Vector3(-0.8, 0.0, 0)))
	return {"node": n}


## Han age 2: a soft black cap with two tails hanging behind.
func _helm_han_cap(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var black := plain(Color("#16141a"))
	n.add_child(dome(Vector3(5.1, 3.4, 5.0), black, Vector3(-0.2, -2.8, 0)))
	n.add_child(blob(Vector3(2.6, 3.0, 2.6), black, Vector3(-1.2, 1.4, 0)))   # the tall crown over the knot
	for side in [1, -1]:   # stiff tails out to the sides behind: nothing else has this silhouette
		n.add_child(rod(Vector3(-3.6, -0.4, 1.2 * side), Vector3(-4.6, 0.2, 7.0 * side), 0.45, 0.35, black))
	n.add_child(ring(4.8, 5.2, plain(c.team), Vector3(-0.2, -2.8, 0)))
	return {"node": n}


## Han age 3: an iron lamellar helmet, a red tassel on top, a flared neck guard.
func _helm_han_lamellar(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var iron := surf("iron", Color.WHITE, 2.0)
	iron = surf("iron", Color(0.62, 0.62, 0.66), 2.0)
	n.add_child(cone(1.2, 5.2, 4.6, iron, Vector3(-0.2, -0.8, 0)))   # a tall, pointed bowl
	for k in 12:   # the lames: vertical bands
		var a := TAU * k / 12.0
		n.add_child(rod(Vector3(cos(a) * 5.25 - 0.2, -3.0, sin(a) * 5.25), Vector3(cos(a) * 1.4 - 0.2, 1.4, sin(a) * 1.4), 0.22, 0.15, plain(Color("#3a3a40"))))
	for k in 5:   # the neck guard: lames hanging behind and at the sides only
		var a := PI * 0.55 + PI * 0.9 * k / 4.0
		n.add_child(blob(Vector3(1.6, 2.4, 0.4), iron, Vector3(cos(a) * 4.7 - 0.4, -4.8, sin(a) * 4.7), Vector3(0, -rad_to_deg(a), 0)))   # (close in: a banner's pole behind cut through them)
	n.add_child(rod(Vector3(-0.2, 1.4, 0), Vector3(-0.2, 3.0, 0), 0.3, 0.3, iron))
	n.add_child(blob(Vector3(1.4, 2.0, 1.4), plain(Color("#c8302a")), Vector3(-0.6, 3.6, 0)))   # the red tassel
	_lift(n, 0.25)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Han weapon: the halberd (ji), a spear with a crescent side blade.
func _weapon_ji(c: Dictionary) -> Dictionary:
	var n: Node3D = _weapon_spear_wood(c).node
	var a := Vector3(-4, -8, 0)
	var b := Vector3(6, 19, 0)
	var d := (b - a).normalized()
	var iron := surf("iron", Color.WHITE, 3.0)
	n.add_child(rod(b, b + d * 4.6, 0.9, 0.1, iron, false))   # the iron point over the wood
	n.add_child(blade([Vector2(0, -0.6), Vector2(3.8, -1.4), Vector2(5.0, 0.6), Vector2(3.6, 0.4), Vector2(0, 0.6)], 0.5, iron,
		b - d * 1.2, atan2(d.y, d.x) + PI * 0.5))
	n.add_child(blob(Vector3(0.9, 1.2, 0.9), plain(c.team), b - d * 2.6))   # a team tassel
	return {"node": n}


func _weapon_ji_bronze(c: Dictionary) -> Dictionary:
	return _weapon_ji(c)


func _weapon_ji_iron(c: Dictionary) -> Dictionary:
	return _weapon_ji(c)


## Han shield: a lacquered rectangle with a pointed top, red with a black border.
func _shield_lacquer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.0, 1.5), SHIELD_FACE)
	var outline := [Vector2(-3.8, -7.5), Vector2(3.8, -7.5), Vector2(3.8, 5.5), Vector2(0, 8.0), Vector2(-3.8, 5.5)]
	h.add_child(slab(outline, 0.9, plain(Color("#c8402a"))))   # bright lacquer red (the leather texture baked it near black)
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		h.add_child(rod(Vector3(a.x, a.y, 0.35), Vector3(b.x, b.y, 0.35), 0.45, 0.45, plain(Color("#1a1612"))))
	h.add_child(blob(Vector3(1.6, 1.6, 0.5), plain(c.team), Vector3(0, 0.5, 0.5)))
	return {"node": n}


## Aztec age 1: a headband with one feather upright behind.
func _helm_aztec_band(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(dome(Vector3(4.9, 2.8, 4.8), surf("mane", Color("#2a2420"), 3.0), Vector3(-0.3, -2.6, 0)))   # a bowl of black hair
	n.add_child(ring(4.5, 5.0, plain(c.team), Vector3(-0.3, -2.6, 0)))   # the band on its edge (alone, a ring floated like a halo)
	n.add_child(blob(Vector3(0.6, 3.6, 1.0), plain(Color("#2a9a6a")), Vector3(-4.0, 0.0, 0), Vector3(0, 0, 12)))   # a green feather
	return {"node": n}


## Aztec age 2: a quilted cotton cap with a crest of feathers.
func _helm_aztec_quilted(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var cotton := surf("cloth", Color("#f0ead8"), 3.0)
	n.add_child(dome(Vector3(5.2, 3.6, 5.1), cotton, Vector3(-0.2, -3.0, 0)))
	for k in 3:   # quilting
		n.add_child(ring(4.9 - k * 1.2, 5.15 - k * 1.2, surf("cloth", Color("#c8bea4"), 2.0), Vector3(-0.2, -2.4 + k * 1.1, 0)))
	var greens := [Color("#2a9a6a"), Color("#e8c040"), Color("#2a9a6a"), Color("#c83a2a"), Color("#2a9a6a")]
	for k in 5:
		var z := -2.0 + k * 1.0
		n.add_child(blob(Vector3(0.5, 3.0, 0.7), plain(greens[k]), Vector3(-3.2, 1.6, z), Vector3(z * 6.0, 0, 20)))
	n.add_child(ring(4.9, 5.4, plain(c.team), Vector3(-0.2, -3.0, 0)))
	_lift(n, 0.10)   # its rim clear of the brow (placement check, A2)
	return {"node": n}


## Aztec age 3: an eagle helmet: brown feathered dome, the yellow beak over the brow, a white crest.
func _helm_aztec_eagle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var feathers := surf("cloth", Color("#6a4a2a"), 3.0)
	n.add_child(dome(Vector3(5.4, 4.6, 5.3), feathers, Vector3(-0.4, -3.2, 0)))
	var beak := plain(Color("#e8b030"))
	n.add_child(cone(0.4, 2.4, 4.6, beak, Vector3(4.8, -1.0, 0), Vector3(0, 0, -100)))   # upper beak, over the face
	for side in [1, -1]:
		n.add_child(blob(Vector3(0.7, 0.7, 0.4), plain(INK), Vector3(3.0, 0.4, 2.6 * side)))   # the eagle's eyes
		n.add_child(blob(Vector3(1.0, 2.6, 0.6), feathers, Vector3(1.2, -4.8, 4.8 * side)))   # cheek feathers
	for k in 4:
		n.add_child(blob(Vector3(0.6, 3.2, 0.8), plain(Color("#f4f0e4")), Vector3(-3.6 + k * 0.2, 1.4, -1.5 + k * 1.0), Vector3(0, 0, 30)))
	n.add_child(ring(5.2, 5.6, plain(c.team), Vector3(-0.4, -3.2, 0)))
	return {"node": n}


## Aztec weapon: the obsidian-edged wooden club (macuahuitl).
func _weapon_macuahuitl(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tip := Vector3(3, 14, 0)
	var d := tip.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade([Vector2(0, -1.0), Vector2(12.5, -1.7), Vector2(14.0, 0), Vector2(12.5, 1.7), Vector2(0, 1.0)], 0.8,
		surf("wood_grain", Color("#c89a60"), 3.0), Vector3.ZERO, ang))
	var glass := surf("iron", Color("#3a3640"), 1.5)
	var across := Vector3(-d.y, d.x, 0)
	for k in 6:   # the obsidian teeth along both edges
		var at := d * (3.0 + k * 1.8)
		var w := 1.1 + k * 0.1
		for side in [1, -1]:
			n.add_child(blob(Vector3(0.55, 0.7, 0.3), glass, at + across * side * (w + 0.5)))
	n.add_child(rod(Vector3.ZERO, -d * 3.0, 0.6, 0.6, surf("leather", Color.WHITE, 2.0), false))
	return {"node": n}


## Aztec shield: a round team-coloured shield with a white ring and a fringe of feathers below.
func _shield_chimalli(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var h := facing(n, Vector3(3.0, 0.5, 1.5), SHIELD_FACE)
	h.add_child(disc(5.6, 0.8, plain(c.team), 0))
	h.add_child(ring(2.6, 3.4, plain(Color("#f4f0e4")), Vector3(0, 0, 0.45), Vector3(90, 0, 0)))
	h.add_child(disc(1.2, 0.3, plain(Color("#e8c040")), 0.5))
	var cols := [Color("#2a9a6a"), Color("#e8c040"), Color("#c83a2a")]
	for k in 9:   # the hanging feathers
		var x := -4.0 + k * 1.0
		h.add_child(blob(Vector3(0.45, 2.0, 0.3), plain(cols[k % 3]), Vector3(x, -6.0 - absf(x) * -0.25, 0.1)))
	return {"node": n}


# ------------------------------------------------------------------ the healer's kit (HL1, look A)
# A tall staff with a healing token tied at the top (herbs; cheese for rats; a water lily for
# frogs) and a bag in the off hand. Held low, like a spear: built around the grip at the hand.
# No red cross (a protected emblem): healing reads from herbs, bags and bandages.

const HERB := Color("#8cc850")
const LINEN_PALE := Color("#efe8d6")


## A: the herbalist. A tall crooked staff with a bundle of herbs tied under the crook.
func _tool_staff_herbs(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("bone", Color("#e2cc9c"), 6.0)   # peeled pale wood: it reads on dark fur and skin
	var a := Vector3(-2, -9, 0)
	var b := Vector3(6, 31, 0)   # taller than its bearer: the herbs ride above the head
	n.add_child(rod(a, b, 1.0, 0.9, wood, false))
	n.add_child(rod(b, b + Vector3(3.0, 2.0, 0), 0.9, 0.7, wood))   # the crook
	n.add_child(rod(b + Vector3(3.0, 2.0, 0), b + Vector3(4.2, 0.2, 0), 0.6, 0.5, wood))
	var herb := surf("leaf", HERB, 2.0)
	for k in 5:
		var ang := -0.9 + k * 0.45
		n.add_child(blob(Vector3(0.8, 2.6, 0.8), herb, b + Vector3(-0.6 + sin(ang) * 1.6, -2.4, cos(ang) * 0.8), Vector3(0, 0, rad_to_deg(ang) * 0.6)))
	n.add_child(ring(0.7, 1.15, plain(c.team), b + Vector3(0, -0.6, 0), Vector3(0, 0, -14)))   # the tie
	return {"node": n}


## A's satchel: a leather bag, a linen bandage roll under the flap.
func _tool_satchel(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var leather := surf("leather", Color(1.0, 0.92, 0.8), 3.0)
	n.add_child(_box(Vector3(2.6, 4.4, 5.0), leather, Vector3(2.4, -2.6, 1.6)))
	n.add_child(_box(Vector3(2.8, 2.0, 5.2), surf("leather", Color(0.7, 0.55, 0.42), 3.0), Vector3(2.6, -0.8, 1.6)))   # the flap
	n.add_child(cone(1.0, 1.0, 3.2, plain(LINEN_PALE), Vector3(3.2, 0.6, 1.6), Vector3(90, 0, 0)))
	return {"node": n}


## D (rats): a crooked stick with a wedge of cheese bound to its top (cheese cures everything).
func _tool_staff_cheese(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("bone", Color("#e2cc9c"), 5.0)   # a peeled stick: it reads on brown fur
	var a := Vector3(-3, -9, 0)
	var b := Vector3(2, 12, 0)
	var t := Vector3(5, 29, 0)
	n.add_child(rod(a, b, 1.0, 0.9, wood))
	n.add_child(rod(b, t, 0.9, 0.75, wood))
	n.add_child(slab([Vector2(-2.6, -1.6), Vector2(3.0, -1.6), Vector2(-2.6, 2.6)], 2.6, surf("cheese", Color.WHITE, 3.0), t + Vector3(0.4, 1.2, 0)))
	n.add_child(ring(0.7, 1.1, plain(c.team), t + Vector3(-0.2, -0.6, 0), Vector3(0, 0, -16)))
	return {"node": n}


## D's poultice sack: a stained cloth sack, knotted, a cheese rind poking out.
func _tool_satchel_cheese(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var sack := surf("cloth", Color("#cdbb92"), 3.0)
	n.add_child(blob(Vector3(2.8, 3.4, 2.8), sack, Vector3(2.6, -2.4, 1.6)))
	n.add_child(cone(0.7, 1.5, 1.4, sack, Vector3(2.6, 1.0, 1.6)))
	n.add_child(ring(0.6, 1.0, plain(c.team), Vector3(2.6, 1.2, 1.6)))
	n.add_child(slab([Vector2(0, 0), Vector2(2.2, 0.6), Vector2(0.2, 1.8)], 1.2, surf("cheese", Color.WHITE, 2.0), Vector3(3.6, -0.6, 3.6)))
	return {"node": n}


## E (frogs): a reed staff crowned with a water-lily flower.
func _tool_staff_lily(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(5, 25, 0)
	n.add_child(rod(a, b, 1.1, 1.0, surf("reed_stalk", Color.WHITE, 5.0), false))
	n.add_child(decal("water_lily", 7.0, 7.0, b + Vector3(0, 1.8, 0.4), Vector3(0.3, 0.6, 1.0)))
	n.add_child(blob(Vector3(2.4, 0.6, 2.4), plain(c.lily), b + Vector3(0, -0.2, 0)))
	return {"node": n}


## E's moss pouch: a lily pad folded over a wad of wet moss, tied with a team cord.
func _tool_satchel_moss(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(blob(Vector3(2.8, 2.4, 3.0), surf("lily_pad", Color.WHITE, 4.0), Vector3(2.6, -2.0, 1.6)))
	n.add_child(blob(Vector3(1.8, 1.0, 2.0), plain(Color("#6f8f3a")), Vector3(3.0, -0.2, 1.6)))
	n.add_child(_box(Vector3(5.8, 0.6, 0.6), plain(c.team), Vector3(2.6, -2.0, 4.5)))   # a team cord
	return {"node": n}


# Every culture its own staff (Dominic, 2026-10-12: "staffs look good; different staffs for
# each"). Same grip and height as the herb staff, so the hold and the bake stay the same; each
# top is chunky enough to read at game scale, with a team tie.

## A glow (a lantern pane, a candle flame): unshaded, so it reads lit in every facing.
func glow(col: Color) -> StandardMaterial3D:
	var m := plain(col)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## The angle (degrees about z) that stands a ring or cone along a staff from a to b.
func tilt_of(a: Vector3, b: Vector3) -> float:
	var d := (b - a).normalized()
	return rad_to_deg(atan2(d.y, d.x)) - 90.0


## Leaves set along a stretch of a staff, alternating sides (laurel, olive).
func _leaves(n: Node3D, a: Vector3, b: Vector3, count: int, size: Vector3, m: Material, spread := 1.3) -> void:
	for k in count:
		var t := float(k) / maxf(1.0, count - 1.0)
		var side := 1.0 if k % 2 == 0 else -1.0
		var ang := t * 5.5
		var p := a.lerp(b, t) + Vector3(cos(ang) * spread * side, 0.3, sin(ang) * spread)
		n.add_child(blob(size, m, p, Vector3(sin(ang) * 30.0, 0, side * 50.0)))


## Imperial: a straight dark rod with bronze fittings, wound with laurel, a laurel wreath
## under a bronze knob.
func _tool_staff_laurel(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(5, 29, 0)
	var d := (b - a).normalized()
	var tilt := tilt_of(a, b)
	var bronze := surf("bronze", Color.WHITE, 3.0)
	n.add_child(rod(a, b, 0.95, 0.9, surf("bone", Color("#b48a5c"), 6.0)))
	n.add_child(cone(0.6, 1.2, 2.2, bronze, a + d * 1.0, Vector3(0, 0, tilt)))   # the ferrule
	n.add_child(blob(Vector3(1.9, 1.9, 1.9), bronze, b + d * 1.6))   # the knob
	n.add_child(ring(0.8, 1.3, bronze, b - d * 0.4, Vector3(0, 0, tilt)))
	var laurel := surf("leaf", Color("#78b040"), 2.0)
	n.add_child(ring(1.4, 2.9, laurel, b - d * 1.6, Vector3(0, 0, tilt), Vector3(1, 1.8, 1)))   # the wreath
	_leaves(n, a.lerp(b, 0.45), b - d * 3.0, 7, Vector3(0.9, 2.0, 0.8), laurel, 1.4)
	n.add_child(ring(0.7, 1.15, plain(c.team), a.lerp(b, 0.42), Vector3(0, 0, tilt)))
	return {"node": n}


## Hellenic: a gnarled olive staff, a sprig of silvery olive leaves and a few olives at the top.
func _tool_staff_olive(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var wood := surf("bone", Color("#c4b494"), 5.0)   # pale grey olive wood
	var pts := [Vector3(-2, -9, 0), Vector3(1.2, 6, 0.4), Vector3(2.6, 18, -0.4), Vector3(5.4, 29, 0)]
	for k in 3:
		n.add_child(rod(pts[k], pts[k + 1], 1.05 - k * 0.08, 0.95 - k * 0.08, wood))
	n.add_child(blob(Vector3(1.4, 1.1, 1.3), wood, pts[1]))   # knots
	n.add_child(blob(Vector3(1.3, 1.0, 1.2), wood, pts[2]))
	var top: Vector3 = pts[3]
	n.add_child(rod(top, top + Vector3(-2.2, 3.4, 0.3), 0.6, 0.45, wood))   # the fork
	n.add_child(rod(top, top + Vector3(2.4, 3.0, -0.3), 0.6, 0.45, wood))
	var olive := surf("leaf", Color("#b4c896"), 2.0)
	_leaves(n, top + Vector3(-2.2, 2.8, 0), top + Vector3(2.4, 3.6, 0), 10, Vector3(0.75, 2.1, 0.75), olive, 1.6)
	for k in 3:
		n.add_child(blob(Vector3(0.75, 0.9, 0.75), plain(Color("#3a3a2a")), top + Vector3(-0.8 + k * 0.9, 1.4 - k * 0.2, 1.0 - k * 0.6)))
	n.add_child(ring(0.7, 1.15, plain(c.team), top + Vector3(-0.3, -1.4, 0), Vector3(0, 0, -14)))
	return {"node": n}


## Hellenic bag: a round clay flask with a black band and a stopper, on a team cord.
func _tool_satchel_flask(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var clay := surf("bld_brick", Color("#e09a62"), 4.0)
	var at := Vector3(2.6, -2.6, 1.6)
	n.add_child(blob(Vector3(2.5, 2.4, 2.5), clay, at))
	n.add_child(ring(2.1, 2.6, plain(Color("#2a1e18")), at + Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 1.6, 1)))
	n.add_child(cone(0.8, 1.0, 1.8, clay, at + Vector3(0, 2.6, 0)))   # the neck
	n.add_child(cone(0.7, 0.7, 0.9, plain(Color("#7a5a3a")), at + Vector3(0, 3.8, 0)))   # the stopper
	n.add_child(rod(at + Vector3(-1.2, 2.4, 0), Vector3(0, 1.2, 0), 0.35, 0.35, plain(c.team)))   # the cord to the hand
	return {"node": n}


## Steppe: a plain staff under an iron finial with a long tuft of horsehair hanging from it.
func _tool_staff_horsehair(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(5, 28, 0)
	var d := (b - a).normalized()
	var tilt := tilt_of(a, b)
	n.add_child(rod(a, b, 0.95, 0.85, surf("bone", Color("#c8a070"), 6.0), false))
	var bronze := surf("bronze", Color.WHITE, 3.0)
	n.add_child(blob(Vector3(1.4, 1.4, 1.4), bronze, b + d * 1.4))   # a round knob, no point: a healer's, not a spear
	n.add_child(cone(1.6, 1.3, 1.0, bronze, b + d * 0.1, Vector3(0, 0, tilt), 20))   # the collar the hair hangs from
	var hair := plain(Color("#3e2a1e"))
	var tips := plain(Color("#6a4a32"))
	for k in 10:   # the tassel: long dark strands spilling out of the collar and falling past it
		var ang := k * TAU / 10.0
		var out := Vector3(cos(ang), 0, sin(ang))
		var root := b + out * 1.1
		var tip := b + out * (2.6 + (k % 3) * 0.5) + Vector3(0, -8.0 - (k % 2) * 1.5, 0)
		n.add_child(rod(root, tip, 0.55, 0.35, hair, false))
		n.add_child(blob(Vector3(0.45, 0.8, 0.45), tips, tip))
	n.add_child(blob(Vector3(1.9, 1.3, 1.9), hair, b + Vector3(0, -0.7, 0)))
	n.add_child(ring(0.7, 1.15, plain(c.team), b - d * 12.0, Vector3(0, 0, tilt)))
	return {"node": n}


## Steppe bag: a felt pouch with a team-coloured stitched band and a bone toggle.
func _tool_satchel_felt(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var felt := surf("bld_felt", Color("#e8dcc0"), 3.0)
	n.add_child(blob(Vector3(2.7, 3.0, 2.6), felt, Vector3(2.6, -2.6, 1.6)))
	n.add_child(cone(0.9, 1.5, 1.2, felt, Vector3(2.6, 0.4, 1.6)))
	n.add_child(ring(1.9, 2.75, plain(c.team), Vector3(2.6, -2.0, 1.6), Vector3.ZERO, Vector3(1, 1.4, 1)))
	n.add_child(blob(Vector3(0.5, 0.9, 0.5), surf("bone", Color.WHITE, 2.0), Vector3(2.6, 1.2, 3.0)))   # the toggle
	return {"node": n}


## Nile: a green papyrus reed crowned with its umbel, a spray of fine stalks.
func _tool_staff_papyrus(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(4, 25, 0)
	n.add_child(rod(a, b, 1.05, 0.8, surf("reed_stalk", Color("#9cc46a"), 5.0), false))
	n.add_child(cone(0.8, 1.6, 2.4, surf("reed_leaf", Color("#c8b070"), 3.0), b + Vector3(0, 0.6, 0)))   # the bract
	var spray := plain(Color("#6aa040"))
	var tips := plain(Color("#c8d070"))
	for k in 11:   # the umbel: fine stalks fanning out and drooping a little
		var ang := k * TAU / 11.0
		var tip := b + Vector3(cos(ang) * 4.6, 4.4 - absf(sin(ang * 0.5)) * 0.8, sin(ang) * 4.6)
		n.add_child(rod(b + Vector3(0, 1.6, 0), tip, 0.32, 0.32, spray, false))
		n.add_child(blob(Vector3(0.75, 0.6, 0.75), tips, tip))
	n.add_child(ring(0.7, 1.15, plain(c.team), b + Vector3(-0.9, -5.0, 0), Vector3(0, 0, -10)))
	return {"node": n}


## Nile bag: a pale linen bag with a blue band, drawn shut with a team cord.
func _tool_satchel_linen(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var linen := surf("cloth", Color("#f2ecd8"), 3.0)
	n.add_child(blob(Vector3(2.6, 3.2, 2.6), linen, Vector3(2.6, -2.6, 1.6)))
	n.add_child(cone(0.6, 1.4, 1.6, linen, Vector3(2.6, 0.8, 1.6)))
	n.add_child(ring(2.1, 2.7, plain(Color("#2a5a9a")), Vector3(2.6, -3.4, 1.6), Vector3.ZERO, Vector3(1, 1.5, 1)))
	n.add_child(ring(0.6, 1.0, plain(c.team), Vector3(2.6, 0.4, 1.6)))
	return {"node": n}


## Han: a jointed bamboo staff with a medicine gourd tied at the top, a red tassel below it.
func _tool_staff_gourd(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(4.5, 25, 0)
	var d := (b - a).normalized()
	var tilt := tilt_of(a, b)
	n.add_child(rod(a, b, 1.0, 0.9, surf("reed_stalk", Color("#d8c878"), 5.0)))
	for k in 5:   # the joints
		n.add_child(ring(0.8, 1.25, surf("reed_stalk", Color("#a89848"), 3.0), a.lerp(b, 0.15 + k * 0.19), Vector3(0, 0, tilt)))
	var gourd := surf("bone", Color("#f2b84a"), 4.0)
	var g := b + d * 1.2 + Vector3(0.4, 0, 0)
	n.add_child(blob(Vector3(2.6, 2.6, 2.6), gourd, g + Vector3(0, 1.6, 0)))   # the belly
	n.add_child(blob(Vector3(1.8, 1.8, 1.8), gourd, g + Vector3(0, 4.9, 0)))   # the head
	n.add_child(ring(0.7, 1.2, plain(Color("#c02a20")), g + Vector3(0, 3.5, 0)))   # the waist cord
	n.add_child(cone(0.5, 0.6, 1.2, plain(Color("#5a3a20")), g + Vector3(0, 7.0, 0)))   # the stopper
	n.add_child(blob(Vector3(0.7, 2.4, 0.7), plain(Color("#c02a20")), b - d * 2.5 + Vector3(1.1, -2.0, 0.4)))   # the tassel
	n.add_child(ring(0.7, 1.15, plain(c.team), b - d * 1.2, Vector3(0, 0, tilt)))
	return {"node": n}


## Han bag: a small black lacquered medicine box, red-edged, on a team cord.
func _tool_satchel_lacquer(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(_box(Vector3(3.6, 3.8, 4.2), plain(Color("#221816")), Vector3(2.6, -2.6, 1.6)))
	n.add_child(_box(Vector3(3.8, 0.7, 4.4), plain(Color("#b82a20")), Vector3(2.6, -1.0, 1.6)))   # the lid's red edge
	n.add_child(_box(Vector3(1.0, 1.0, 0.5), surf("bronze", Color.WHITE, 2.0), Vector3(2.6, -2.2, 3.9)))   # the clasp
	n.add_child(rod(Vector3(2.6, -0.6, 1.6), Vector3(0, 1.2, 0), 0.35, 0.35, plain(c.team)))
	return {"node": n}


## Aztec: a staff painted in bands, crowned with a fan of long green, red and yellow feathers.
func _tool_staff_feather(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(4.5, 25, 0)
	var d := (b - a).normalized()
	var tilt := tilt_of(a, b)
	n.add_child(rod(a, b, 0.95, 0.9, surf("bone", Color("#c08a58"), 6.0)))
	var bands := [Color("#2a7a6a"), Color("#e8c040"), Color("#c83a2a")]
	for k in 3:
		n.add_child(ring(0.75, 1.15, plain(bands[k]), b - d * (2.0 + k * 1.3), Vector3(0, 0, tilt)))
	n.add_child(blob(Vector3(1.5, 1.2, 1.5), plain(Color("#e8c040")), b + d * 0.6))   # the socket
	var cols := [Color("#1f9a5a"), Color("#c83a2a"), Color("#1f9a5a"), Color("#e8c040"), Color("#1f9a5a"), Color("#c83a2a"), Color("#1f9a5a")]
	for k in 7:   # long plumes, the green quetzal ones in the middle
		var ang := (k - 3) * 0.32
		var length := 5.8 - absf(k - 3) * 0.6
		var p := b + d * 1.0 + Vector3(sin(ang) * length * 0.75, cos(ang) * length, sin(ang) * length * 0.45)   # a fan with some depth: it reads side-on too
		n.add_child(blob(Vector3(0.75, length * 0.62, 0.75), plain(cols[k]), p, Vector3(rad_to_deg(ang) * 0.6, 0, -rad_to_deg(ang))))
	n.add_child(ring(0.7, 1.15, plain(c.team), a.lerp(b, 0.5), Vector3(0, 0, tilt)))
	return {"node": n}


## Aztec bag: a woven pouch in bright stripes, a feather tucked in its knot.
func _tool_satchel_woven(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.add_child(_box(Vector3(3.0, 4.2, 4.6), surf("wicker", Color("#e0c080"), 2.5), Vector3(2.6, -2.6, 1.6)))
	n.add_child(_box(Vector3(3.1, 0.8, 4.7), plain(Color("#2a7a6a")), Vector3(2.6, -1.9, 1.6)))
	n.add_child(_box(Vector3(3.1, 0.8, 4.7), plain(Color("#c83a2a")), Vector3(2.6, -3.4, 1.6)))
	n.add_child(ring(0.5, 0.9, plain(c.team), Vector3(2.6, -0.1, 1.6)))
	n.add_child(blob(Vector3(0.5, 2.0, 0.35), plain(Color("#1f9a5a")), Vector3(3.2, 1.2, 2.4), Vector3(0, 0, -20)))
	return {"node": n}


## Royal: a tall staff with an iron hook at the top, a glowing lantern hanging from it.
func _tool_staff_lantern(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var a := Vector3(-2, -9, 0)
	var b := Vector3(4, 28, 0)
	n.add_child(rod(a, b, 0.95, 0.85, surf("wood_grain", Color(0.55, 0.38, 0.26), 6.0)))
	var iron := surf("iron", Color(0.55, 0.55, 0.6), 3.0)
	n.add_child(rod(b, b + Vector3(2.4, 2.4, 0), 0.6, 0.55, iron))   # the hook arm
	n.add_child(rod(b + Vector3(2.4, 2.4, 0), b + Vector3(4.6, 1.6, 0), 0.55, 0.5, iron))
	var lt := b + Vector3(4.6, -3.4, 0)   # the lantern's centre, hanging under the hook's tip
	n.add_child(rod(b + Vector3(4.6, 1.6, 0), lt + Vector3(0, 2.8, 0), 0.3, 0.3, iron))   # the bail
	n.add_child(_box(Vector3(2.6, 3.2, 2.6), glow(Color("#ffd060")), lt))   # the lit panes
	for x in [-1.3, 1.3]:   # the frame's corner posts
		for z in [-1.3, 1.3]:
			n.add_child(_box(Vector3(0.45, 3.4, 0.45), iron, lt + Vector3(x, 0, z)))
	n.add_child(cone(0.4, 2.1, 1.6, iron, lt + Vector3(0, 2.3, 0)))   # the cap
	n.add_child(_box(Vector3(2.9, 0.5, 2.9), iron, lt + Vector3(0, -1.8, 0)))   # the base
	n.add_child(ring(0.7, 1.15, plain(c.team), b + Vector3(-0.6, -3.5, 0), Vector3(0, 0, -10)))
	return {"node": n}


## Spooky: a crooked staff of lashed bones, a bone cup on top holding a lit candle.
func _tool_staff_candle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bone := surf("bone", Color("#ece4cc"), 4.0)
	var pts := [Vector3(-2, -9, 0), Vector3(1.8, 4, 0.5), Vector3(0.8, 13, -0.4), Vector3(4.2, 22, 0.3), Vector3(3.6, 26, 0)]
	for k in 4:
		n.add_child(rod(pts[k], pts[k + 1], 0.95, 0.85, bone))
		n.add_child(blob(Vector3(1.45, 1.2, 1.35), bone, pts[k + 1]))   # the knuckles
	var top: Vector3 = pts[4]
	n.add_child(cone(2.6, 1.2, 2.0, bone, top + Vector3(0, 1.2, 0)))   # the cup
	var wax := plain(Color("#f8f2e0"))
	n.add_child(cone(1.3, 1.3, 3.6, wax, top + Vector3(0, 3.8, 0)))   # the candle
	n.add_child(blob(Vector3(0.6, 1.3, 0.6), wax, top + Vector3(1.3, 3.0, 0.4)))   # drips
	n.add_child(blob(Vector3(0.5, 1.0, 0.5), wax, top + Vector3(-1.2, 3.4, 0.6)))
	n.add_child(blob(Vector3(1.2, 2.1, 1.2), glow(Color("#ff9a30")), top + Vector3(0, 7.4, 0)))   # the flame
	n.add_child(blob(Vector3(0.6, 1.1, 0.6), glow(Color("#fff2b0")), top + Vector3(0, 7.0, 0.7)))
	n.add_child(ring(0.7, 1.15, plain(c.team), pts[3] + Vector3(-0.6, -2.0, 0), Vector3(0, 0, -20)))
	return {"node": n}


## Spooky bag: a dark stoppered bottle, a glint of green brew, a team band round it.
func _tool_satchel_bottle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var at := Vector3(2.6, -2.8, 1.6)
	var glass := plain(Color("#4a2a6a"))
	n.add_child(blob(Vector3(2.3, 2.6, 2.3), glass, at))
	n.add_child(cone(0.7, 0.9, 2.2, glass, at + Vector3(0, 2.8, 0)))
	n.add_child(cone(0.75, 0.6, 1.0, plain(Color("#8a6a40")), at + Vector3(0, 4.2, 0)))   # the cork
	n.add_child(blob(Vector3(0.8, 0.9, 0.4), glow(Color("#9ae070")), at + Vector3(0.9, 0.4, 2.0)))   # a glint of the brew
	n.add_child(ring(2.0, 2.5, plain(c.team), at + Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1, 1.3, 1)))
	return {"node": n}


## Forest: a living branch, still in leaf, a twig or two sprouting from it.
func _tool_staff_branch(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var bark := surf("bark_plate", Color("#b08a60"), 4.0)
	var pts := [Vector3(-2, -9, 0), Vector3(0.8, 5, -0.4), Vector3(3.4, 17, 0.4), Vector3(5, 26, 0)]
	for k in 3:
		n.add_child(rod(pts[k], pts[k + 1], 1.15 - k * 0.12, 1.0 - k * 0.12, bark))
	var top: Vector3 = pts[3]
	var leaf := surf("leaf", Color("#80c850"), 2.0)
	var twigs := [[pts[2], pts[2] + Vector3(-3.4, 3.2, 0.6)], [top, top + Vector3(-2.0, 3.6, -0.4)], [top, top + Vector3(2.6, 3.0, 0.5)]]
	for t in twigs:
		n.add_child(rod(t[0], t[1], 0.5, 0.35, bark))
		n.add_child(blob(Vector3(1.4, 1.0, 1.2), leaf, t[1] + Vector3(0, 0.6, 0)))
	for k in 6:   # the crown of leaves
		var ang := k * TAU / 6.0
		n.add_child(blob(Vector3(1.0, 2.0, 0.6), leaf, top + Vector3(cos(ang) * 1.8, 2.0 + sin(ang * 2.0) * 0.6, sin(ang) * 1.8), Vector3(sin(ang) * 40.0, 0, cos(ang) * 40.0)))
	n.add_child(blob(Vector3(1.8, 1.6, 1.8), leaf, top + Vector3(0, 3.6, 0)))
	n.add_child(ring(0.7, 1.15, plain(c.team), pts[1] + Vector3(0.9, 3.5, 0), Vector3(0, 0, -14)))
	return {"node": n}


## Forest bag: a bundle wrapped in big leaves, tied with a team cord.
func _tool_satchel_leaf(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var at := Vector3(2.6, -2.4, 1.6)
	n.add_child(blob(Vector3(2.6, 2.9, 2.6), surf("leaf", Color("#6aa848"), 3.0), at))
	for k in 3:   # the wrapping leaves' tips
		var ang := k * TAU / 3.0
		n.add_child(blob(Vector3(1.0, 1.8, 0.5), surf("leaf", Color("#4a8a38"), 2.0), at + Vector3(cos(ang) * 1.2, 2.6, sin(ang) * 1.2), Vector3(sin(ang) * 30.0, 0, cos(ang) * 30.0)))
	n.add_child(ring(2.0, 2.7, plain(c.team), at + Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1, 1.3, 1)))
	return {"node": n}

