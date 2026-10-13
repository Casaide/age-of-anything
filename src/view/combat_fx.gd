extends Node2D
## Combat effects for the game view, played from the sim's events: projectiles
## (flying as long as the sim's shots do; shots that miss stick in the ground), impact sparks, a white hit flash, and units dying
## (the body topples over about its feet, darkens where it lies, then goes in a puff
## of dust; the ground shadow stays flat and fades). Buildings that fall leave a dust cloud. A
## healed unit warms for a moment and a few pale motes drift up off it. View side only; nothing
## here feeds back into the sim.

## How each ranged weapon's shot looks: speed (canvas px a second), arc (height as
## a share of the distance), length and width of the drawn shot, colour.
const SHOTS := {
	"arrow": {"speed": 520.0, "arc": 0.22, "len": 7.0, "w": 1.0, "col": Color("#e8dcc0")},
	"bolt": {"speed": 700.0, "arc": 0.08, "len": 6.0, "w": 1.4, "col": Color("#c8c0a8")},
	"javelin": {"speed": 330.0, "arc": 0.3, "len": 11.0, "w": 1.3, "col": Color("#b08a5a")},
	"stone": {"speed": 380.0, "arc": 0.18, "len": 0.0, "w": 2.4, "col": Color("#8a8a80")},
	"dart": {"speed": 650.0, "arc": 0.04, "len": 4.0, "w": 0.8, "col": Color("#2a2a20")},
	"ball": {"speed": 900.0, "arc": 0.02, "len": 0.0, "w": 1.8, "col": Color("#303030")},
	# Siege (milestone 13): a catapult's stone, lobbed high and heavy; a bolt thrower's long bolt.
	# Their own sounds (tools/audio/sfx.py): the arm slamming its crossbar, the bow arms' snap.
	"boulder": {"speed": 260.0, "arc": 0.42, "len": 0.0, "w": 4.2, "col": Color("#8f8a7c"), "sound": "catapult_release"},
	"siege_bolt": {"speed": 420.0, "arc": 0.1, "len": 13.0, "w": 1.9, "col": Color("#a89a7c"), "sound": "bolt_release"},
	# The great sling's stone: bigger, higher, from much further off.
	"sling_stone": {"speed": 240.0, "arc": 0.5, "len": 0.0, "w": 5.0, "col": Color("#8f8a7c"), "sound": "sling_release"},
}
const DIE_TIME := 2.2
const FLASH_TIME := 0.12
const FLASH := 1.8     # extra brightness at the flash's peak (the baked art reads modulate alpha as shade)

var shots: Array = []    # {from, to, t, dur, kind}
var stuck: Array = []    # shots in the ground: {pos, t, kind, tilt}
const STUCK_TIME := 3.0
var sparks: Array = []   # {pos, t, col}
var ghosts: Array = []   # {node, t, tip}
var dusts: Array = []    # {pos, t, size}
var flashes: Array = []  # {node, t} (t < 0: the shot is still flying)
var heals: Array = []    # {node, t, motes: [[Vector2 offset, rise speed, delay]]}
const HEAL_TIME := 1.0
const HEAL_GLOW := 0.35   # a soft brightening, well under a hit's flash
const HEAL_MOTE := Color("#e4f4c0")


## The shot a weapon's tags call for.
static func shot_kind(tags: Array) -> String:
	if "great_sling" in tags:
		return "sling_stone"
	if "catapult" in tags:
		return "boulder"
	if "bolt_thrower" in tags:
		return "siege_bolt"
	if "javelin" in tags:
		return "javelin"
	if "sling" in tags:
		return "stone"
	if "poison" in tags:
		return "dart"
	if "gun" in tags:
		return "ball"
	if "heavy" in tags and "bow" in tags:
		return "bolt"
	return "arrow"


## The sound a shot of this kind makes as it leaves (its own "shoot_<kind>", or one it shares).
static func shot_sound(kind: String) -> String:
	return SHOTS[kind].get("sound", "shoot_" + kind)


## A catapult's stone lands: a burst of dirt over the area it hurts (radius in canvas px), a
## heavy spark where it struck.
func splash(at: Vector2, r: float) -> void:
	spark(at, true)
	dusts.append({"pos": at, "t": 0.0, "size": r * 0.45})
	for k in 7:
		var a := TAU * k / 7.0 + randf_range(-0.3, 0.3)
		var d := r * randf_range(0.4, 0.9)
		dusts.append({"pos": at + Vector2(cos(a) * d, sin(a) * d * 0.5), "t": -randf() * 0.12, "size": randf_range(2.5, 4.5)})


## A shot flies, for `dur` seconds (the sim's flight) or, without one, at the weapon's own pace;
## returns how long it takes to land.
func shoot(from: Vector2, to: Vector2, kind: String, dur := -1.0) -> float:
	var s: Dictionary = SHOTS[kind]
	if dur <= 0.0:
		dur = maxf(0.08, from.distance_to(to) / s.speed)
	shots.append({"from": from, "to": to, "t": 0.0, "dur": dur, "kind": kind})
	return dur


## A shot came down in the ground at `at`: a shaft stands in it at a slant for a while (a stone
## or a ball just kicks up a little dirt).
func stick(at: Vector2, kind: String) -> void:
	dusts.append({"pos": at, "t": 0.0, "size": 1.5})
	if SHOTS[kind].len > 0.0:
		stuck.append({"pos": at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)), "t": 0.0, "kind": kind, "tilt": randf_range(-0.6, 0.6)})


## A unit is hit: it flashes white for a moment, after `delay` (a shot's flight).
func flash(view: Node2D, delay := 0.0) -> void:
	flashes.append({"node": view, "t": -delay})


## A unit is healed: it warms up softly and three pale motes rise off its body and fade.
func heal(view: Node2D) -> void:
	if heals.any(func(h): return h.node == view and h.t < HEAL_TIME * 0.5):
		return   # one glow at a time: two healers on one patient don't double it
	var motes := []
	for k in 3:
		motes.append([Vector2(randf_range(-4.0, 4.0), randf_range(-14.0, -6.0)), randf_range(9.0, 14.0), randf_range(0.0, 0.25)])
	heals.append({"node": view, "t": 0.0, "motes": motes})


func spark(at: Vector2, heavy := false) -> void:
	sparks.append({"pos": at + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "t": 0.0, "big": heavy})


## A unit has died: its view stays a moment and plays its fall (UnitView.die: by body shape,
## D-106), darkening and sinking; this node times the fade and the dust.
func kill(view: Node2D) -> void:
	view.die(1.0 if randf() < 0.5 else -1.0)
	ghosts.append({"node": view, "t": 0.0, "puffed": false})


## A building has fallen.
func collapse(node: Node2D, at: Vector2, size: int) -> void:
	node.queue_free()
	for k in 6 + size * 3:
		dusts.append({"pos": at + Vector2(randf_range(-20, 20), randf_range(-10, 10)) * size * 0.6, "t": -randf() * 0.4, "size": randf_range(8, 16) * size * 0.5})


## Drop everything (a new match).
func clear() -> void:
	for g in ghosts:
		g.node.queue_free()
	ghosts.clear()
	shots.clear()
	stuck.clear()
	flashes.clear()
	heals.clear()
	sparks.clear()
	dusts.clear()


func _process(delta: float) -> void:
	for s in shots:
		s.t += delta
	shots = shots.filter(func(s): return s.t < s.dur)
	for s in stuck:
		s.t += delta
	stuck = stuck.filter(func(s): return s.t < STUCK_TIME)
	for f in flashes:
		f.t += delta
		var n = f.node   # untyped: a freed view can't be assigned to a typed Node2D
		if not is_instance_valid(n) or ghosts.any(func(g): return g.node == n):
			f.t = FLASH_TIME   # gone or dying: the death owns its look now
		elif f.t >= 0.0:
			n.visual.modulate.a = 1.0 + FLASH * maxf(0.0, 1.0 - f.t / FLASH_TIME)
	flashes = flashes.filter(func(f): return f.t < FLASH_TIME)
	for h in heals:
		h.t += delta
		var n = h.node
		if not is_instance_valid(n) or ghosts.any(func(g): return g.node == n):
			h.t = HEAL_TIME
		elif not flashes.any(func(f): return f.node == n and f.t >= 0.0):   # a hit's flash wins
			var k: float = h.t / HEAL_TIME
			n.visual.modulate.a = 1.0 + HEAL_GLOW * sin(PI * k * 2.0) if k < 0.5 else 1.0
	heals = heals.filter(func(h): return h.t < HEAL_TIME)
	for s in sparks:
		s.t += delta
	sparks = sparks.filter(func(s): return s.t < 0.25)
	for d in dusts:
		d.t += delta
	dusts = dusts.filter(func(d): return d.t < 1.6)
	for g in ghosts:
		g.t += delta
		var n: Node2D = g.node
		var fade := clampf((g.t - 0.6) / (DIE_TIME - 0.9), 0.0, 1.0)
		n.visual.modulate.a = 1.0 - fade * 0.8      # baked art reads modulate alpha as shade: darkens
		(n.get_child(0) as CanvasItem).modulate.a = 1.0 - fade   # the shadow (UnitView adds it first)
		if g.t >= DIE_TIME - 0.3 and not g.puffed:
			g.puffed = true
			for k in 4:
				dusts.append({"pos": n.ground() + Vector2(n.die_tip * 8.0 + randf_range(-5, 5), randf_range(-3, 2)), "t": 0.0, "size": randf_range(3, 5)})
		if g.t >= DIE_TIME:
			n.queue_free()
	ghosts = ghosts.filter(func(g): return g.t < DIE_TIME)
	queue_redraw()


func _draw() -> void:
	for s in stuck:   # half buried, leaning, fading at the end
		var st: Dictionary = SHOTS[s.kind]
		var a: float = clampf((STUCK_TIME - s.t) / 0.6, 0.0, 1.0)
		# Longer, darker and outlined than in flight: small pale shafts vanished into the grass (Dominic).
		var up: Vector2 = Vector2(sin(s.tilt), -cos(s.tilt)) * float(st.len) * 0.9
		var w: float = maxf(st.w, 1.4)
		draw_line(s.pos + Vector2(0.6, 0.3), s.pos + Vector2(0.6, 0.3) + Vector2(up.x * 1.4, -up.y * 0.35), Color(0, 0, 0, 0.3 * a), w)   # its shadow
		draw_line(s.pos, s.pos + up, Color(0.1, 0.07, 0.04, 0.8 * a), w + 1.2)   # a dark edge
		draw_line(s.pos, s.pos + up, Color(Color(st.col).darkened(0.35), a), w)
		draw_circle(s.pos + up, w * 0.9, Color(0.92, 0.9, 0.84, a))   # the fletching
	for s in shots:
		var st: Dictionary = SHOTS[s.kind]
		var k: float = s.t / s.dur
		var from: Vector2 = s.from
		var to: Vector2 = s.to
		var h: float = from.distance_to(to) * st.arc
		var p := from.lerp(to, k) - Vector2(0, h * 4.0 * k * (1.0 - k))
		var k2 := minf(k + 0.03, 1.0)
		var ahead := from.lerp(to, k2) - Vector2(0, h * 4.0 * k2 * (1.0 - k2))
		var dir := (ahead - p).normalized()
		if st.len > 0.0:
			draw_line(p - dir * st.len * 0.5, p + dir * st.len * 0.5, st.col, st.w)
		else:
			draw_circle(p, st.w, st.col)
		draw_circle(p + Vector2(0, h * 4.0 * k * (1.0 - k) + 1.0), 0.8, Color(0, 0, 0, 0.25))   # its shadow on the ground
	for h in heals:
		var n = h.node
		if not is_instance_valid(n) or not n.visible:
			continue
		for m in h.motes:
			var t: float = h.t - float(m[2])
			if t <= 0.0:
				continue
			var a := sin(PI * clampf(t / (HEAL_TIME - 0.25), 0.0, 1.0))
			var p: Vector2 = n.ground() + m[0] + Vector2(sin(t * 5.0 + float(m[2]) * 20.0) * 1.2, -float(m[1]) * t)
			draw_circle(p, 1.6, Color(HEAL_MOTE, 0.25 * a))   # a soft halo...
			draw_circle(p, 0.7, Color(HEAL_MOTE, 0.85 * a))   # ...round a bright core
	for s in sparks:
		var f: float = 1.0 - s.t / 0.25
		var r: float = (4.0 if s.big else 2.5) * (0.5 + f)
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5 + 0.4)
			draw_line(s.pos, s.pos + d * r, Color(1.0, 0.92, 0.7, f), 1.0)
	for d in dusts:
		if d.t < 0.0:
			continue
		var f: float = d.t / 1.6
		draw_circle(d.pos - Vector2(0, f * 10.0), d.size * (0.6 + f), Color(0.62, 0.56, 0.46, 0.5 * (1.0 - f)))
