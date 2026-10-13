extends "res://scenes/art_pixel/unit_models.gd"
## The scifi_test mod's parts (mods/scifi_test/data/parts.json), built from the game's model helpers
## (blob, rod, slab, dome, ring, cone, surf, plain, glow...: scenes/art_pixel/unit_models.gd). A part id's
## builder is "_" + the id with dots as underscores. Each part is in its socket's frame, like the
## game's own: x the way the unit faces, y up, z towards the viewer's side; held items are built around
## their grip, head gear round the head's top socket (the crown at y 0, about 5 across), worn armour
## frog-sized (the body's torso_fit scales it), back gear from the back's surface outwards (-x).

const ENERGY := Color("#7fe6ff")    # the light of the emitters and the visor
const SUIT := Color("#2c3138")      # the dark undersuit and gun body
const PLATE := Color(0.72, 0.76, 0.8)


## A texture of this mod (textures/<name>.svg), for surf().
func mod_tex(name: String) -> String:
	return get_script().resource_path.get_base_dir().get_base_dir() + "/textures/" + name


func _plate(units := 3.0) -> StandardMaterial3D:
	return surf(mod_tex("plate"), PLATE, units)


func _gunmetal() -> StandardMaterial3D:
	return surf("iron", Color(0.42, 0.45, 0.5), 2.0)


# ------------------------------------------------------------------ weapons

## The pulse rifle: along the musket's line (stock under the arm, muzzle up and forward), so the aim
## hold fits it. A stock and receiver in one boxy outline, a shroud over the barrel, a top rail, a
## power cell on the near side and a ring of light at the emitter.
func _weapon_pulse_rifle(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var body := surf("iron", Color(0.3, 0.33, 0.37), 2.0)
	var plate := _plate(2.0)
	var line := Vector3(14.0, 3.6, 0).normalized()   # the musket's line
	var ang := rad_to_deg(atan2(line.y, line.x))
	var frame := Node3D.new()
	frame.rotation_degrees = Vector3(0, 0, ang)
	n.add_child(frame)
	# Stock, grip and receiver: one outline along +x (the grip at the origin), extruded.
	frame.add_child(slab([Vector2(-6, -1.8), Vector2(-6, 1.2), Vector2(-1, 1.6), Vector2(9, 1.8), Vector2(10, 0.6), Vector2(10, -1.0),
		Vector2(2, -1.2), Vector2(1, -3.2), Vector2(-0.6, -3.2), Vector2(-0.8, -1.2), Vector2(-3.5, -1.0)], 1.8, body))
	frame.add_child(_box(Vector3(9.0, 1.6, 2.2), plate, Vector3(5.5, 1.4, 0)))      # the receiver's upper plate
	frame.add_child(_box(Vector3(7.0, 0.5, 0.9), body, Vector3(5.0, 2.45, 0)))      # the top rail
	frame.add_child(_box(Vector3(1.0, 1.0, 1.0), plate, Vector3(2.5, 3.0, 0)))      # a sight
	frame.add_child(_box(Vector3(6.0, 1.7, 1.8), body, Vector3(13.0, 0.9, 0)))      # the barrel shroud
	frame.add_child(_box(Vector3(2.4, 0.5, 1.95), plain(c.team), Vector3(12.0, 1.8, 0)))   # a team stripe on the shroud
	frame.add_child(cone(0.9, 1.15, 1.0, body, Vector3(16.4, 0.9, 0), Vector3(0, 0, -90)))  # the emitter's housing
	frame.add_child(ring(0.45, 0.85, glow(ENERGY), Vector3(17.0, 0.9, 0), Vector3(0, 0, 90)))   # its ring of light
	frame.add_child(blob(Vector3(0.45, 0.45, 0.45), glow(Color.WHITE), Vector3(17.05, 0.9, 0)))
	frame.add_child(_box(Vector3(2.6, 1.3, 0.7), glow(ENERGY.darkened(0.15)), Vector3(4.5, -0.2, 1.1)))   # the power cell, glowing
	return {"node": n}


## Age 3's heavy pulse rifle: the same rifle with a longer shroud, a scope and a second cell.
func _weapon_pulse_rifle_heavy(c: Dictionary) -> Dictionary:
	var spec := _weapon_pulse_rifle(c)
	var frame: Node3D = spec.node.get_child(0)
	var body := surf("iron", Color(0.3, 0.33, 0.37), 2.0)
	frame.add_child(_box(Vector3(3.0, 1.5, 1.7), body, Vector3(17.4, 0.9, 0)))      # the shroud runs on...
	for k in frame.get_children():   # ...so the emitter moves to its end
		if k is MeshInstance3D and k.position.x > 16.0 and k.position.x < 17.2:
			k.position.x += 2.6
	frame.add_child(rod(Vector3(2.0, 3.4, 0), Vector3(7.0, 3.4, 0), 0.6, 0.6, body))   # the scope
	frame.add_child(ring(0.25, 0.55, glow(ENERGY), Vector3(7.05, 3.4, 0), Vector3(0, 0, 90)))
	frame.add_child(_box(Vector3(2.6, 1.3, 0.7), glow(ENERGY.darkened(0.15)), Vector3(4.5, -0.2, -1.1)))   # the second cell, far side
	return spec


## The arc blade:a blade of light on a dark hilt with a guard, held low like a sword (along the
## bronze sword's line).
func _weapon_arc_blade(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var tip := Vector3(3, 14, 0)
	var d := tip.normalized()
	var ang := atan2(d.y, d.x)
	n.add_child(blade([Vector2(1.5, -0.8), Vector2(13.0, -0.7), Vector2(14.8, 0), Vector2(13.0, 0.7), Vector2(1.5, 0.8)], 0.7, glow(ENERGY), Vector3.ZERO, ang))
	n.add_child(blade([Vector2(2.0, -0.35), Vector2(13.0, -0.3), Vector2(14.0, 0), Vector2(13.0, 0.3), Vector2(2.0, 0.35)], 0.9, glow(Color.WHITE), Vector3.ZERO, ang))   # its white core
	var dark := _gunmetal()
	var across := Vector3(-d.y, d.x, 0)
	n.add_child(rod(-across * 2.2 + d * 1.2, across * 2.2 + d * 1.2, 0.6, 0.6, dark))   # the guard
	n.add_child(rod(d * 1.2, -d * 3.0, 0.75, 0.7, surf("leather", Color(0.35, 0.35, 0.38), 2.0), false))   # the grip
	n.add_child(blob(Vector3(0.95, 0.95, 0.95), plain(c.team), -d * 3.5))   # a team pommel
	return {"node": n}


# ------------------------------------------------------------------ head gear

## The sealed helmet: a rounded shell over the whole head, a face plate with a visor slit of light,
## a team stripe over the crown, a short antenna. The face is covered (parts.json "face": "covered").
func _helm_visor_sealed(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var plate := _plate(3.0)
	var dark := surf("iron", SUIT, 2.0)
	n.add_child(blob(Vector3(5.3, 4.8, 5.1), plate, Vector3(-0.2, -4.0, 0)))          # the shell
	n.add_child(blob(Vector3(2.6, 3.0, 4.4), plate, Vector3(3.6, -6.0, 0)))           # the face plate's jaw
	n.add_child(ring(3.6, 4.4, dark, Vector3(0.2, -8.2, 0), Vector3(0, 0, -6), Vector3(1, 0.8, 1)))   # the neck seal (a collar, clear of the shoulders)
	n.add_child(blob(Vector3(1.6, 1.4, 4.4), dark, Vector3(4.4, -4.4, 0)))            # the visor's dark band...
	n.add_child(blob(Vector3(1.2, 0.75, 4.0), glow(ENERGY), Vector3(5.3, -4.3, 0)))   # ...and its slit of light
	n.add_child(ring(5.35, 5.75, plain(c.team), Vector3(-0.2, -4.4, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.35)))   # the team stripe over the crown
	n.add_child(rod(Vector3(-2.5, -1.2, -4.4), Vector3(-3.5, 3.0, -4.6), 0.25, 0.18, dark, false))   # the antenna, on the far side
	n.add_child(blob(Vector3(0.9, 1.4, 0.6), dark, Vector3(-0.5, -5.2, 5.2)))         # an ear housing
	n.add_child(blob(Vector3(0.9, 1.4, 0.6), dark, Vector3(-0.5, -5.2, -5.2)))
	return {"node": n}


# ------------------------------------------------------------------ armour (frog-sized: the body's torso_fit scales it)

## Plated armour: a moulded shell (chest and back) over the dark suit, a team band across the chest,
## a small glowing core at its middle.
func _armour_plate_composite(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var plate := _plate(4.0)
	n.add_child(blob(Vector3(8.8, 8.2, 10.4), surf("iron", SUIT, 3.0), Vector3(1.5, 0.5, 0), Vector3(0, 0, -10)))   # the suit
	n.add_child(blob(Vector3(5.2, 6.4, 9.0), plate, Vector3(5.2, 2.2, 0), Vector3(0, 0, -10)))    # the chest plate
	n.add_child(blob(Vector3(4.6, 6.8, 9.2), plate, Vector3(-2.6, 2.0, 0), Vector3(0, 0, -10)))   # the back plate
	n.add_child(ring(0.97, 1.06, plain(c.team), Vector3(1.6, -1.4, 0), Vector3(0, 0, -10), Vector3(8.9, 1.6, 10.5)))   # the team band
	n.add_child(blob(Vector3(0.9, 0.9, 0.9), glow(ENERGY), Vector3(10.0, 3.0, 0)))   # the core
	n.add_child(ring(0.97, 1.08, surf("iron", SUIT, 2.0), Vector3(1.4, -5.6, 0), Vector3(0, 0, -10), Vector3(7.2, 1.2, 8.6)))   # the belt
	return {"node": n}


# ------------------------------------------------------------------ back

## The power pack: a box against the back with a vented top and a glowing charge strip.
func _pack_power(c: Dictionary) -> Dictionary:
	var n := Node3D.new()
	var plate := _plate(2.0)
	var dark := surf("iron", SUIT, 2.0)
	n.add_child(_box(Vector3(3.0, 7.0, 5.4), plate, Vector3(-1.4, 0.5, 0)))
	n.add_child(_box(Vector3(2.6, 1.0, 4.8), dark, Vector3(-1.4, 4.4, 0)))          # the vented top
	for k in 3:
		n.add_child(_box(Vector3(2.7, 0.25, 0.5), plain(Color("#15181c")), Vector3(-1.4, 4.95, -1.6 + k * 1.6)))
	n.add_child(_box(Vector3(0.4, 4.4, 1.0), glow(ENERGY), Vector3(-2.95, 0.6, 0)))   # the charge strip
	n.add_child(_box(Vector3(3.1, 0.9, 5.5), plain(c.team), Vector3(-1.4, -2.4, 0)))   # a team band
	return {"node": n}
