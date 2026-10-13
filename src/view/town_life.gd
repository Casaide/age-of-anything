extends Node2D
## Living towns (milestone 17): the town at work and at rest, read from the sim and never
## written back. Per frame, after the match view has synced its units and buildings:
## - drop-off piles at the Town Center and the camps grow with each load brought home and
##   empty slowly (baked piles, three stages per resource);
## - dust puffs where a builder's blow lands;
## - chimneys smoke while their building trains or researches (houses always);
## - idle workers near home do small chores (sweep, sit, chat), animals graze;
## - a house grows a yard and a garden as it gets older;
## - damaged buildings crack, then burn;
## - a stable keeps one of its race's mounts tethered by the door;
## - critters by culture: dragonflies round a reed town, pigeons round a junk town, small
##   birds elsewhere; sparse, drawn as a few art pixels each;
## - the town ambience, louder as your town grows and the camera is over it.
## Cosmetic randomness is fine here (view side); the sim is only read.

const Iso := preload("res://src/view/iso.gd")
const Economy := preload("res://src/sim/economy.gd")
const Fog := preload("res://src/sim/fog.gd")
const UnitView := preload("res://src/unit_view.gd")
const TownProps := preload("res://scenes/art_pixel/town_props.gd")

const LOAD_DECAY_S := 14.0            # a pile loses one load's worth this often (it's carried in)
const PILE_STAGE_AT := [0.5, 3.0, 7.0]   # loads in the pile for stages 1, 2, 3
const PILE_MAX := 10.0
const CHORE_AFTER_S := 3.0            # idle this long before a chore starts
const CHORE_NEAR_HOME := 6000         # milli-tiles from a house or Town Center
const CHORE_SPELL_S := 18.0           # one chore lasts about this long, then another
const CHAT_REACH := 1600              # milli-tiles: two idle workers this close may chat
const YARD_AT_S := [60.0, 150.0, 270.0, 420.0]   # a house's age (match seconds) for its yard and garden stages
const CRITTERS_PER_TOWN := 6

var host                     # the match view (scenes/sim_debug.gd)
var time := 0.0
var _last := {}              # unit id -> [task, carry, carry_kind, target] last frame
var _idle_since := {}        # unit id -> match seconds it went idle
var chores := {}             # unit id -> the chore an idle worker is doing ("sweep", "sit", "chat")
var piles := {}              # building id -> {kind: loads}
var _pile_sprites := {}      # "bid:kind" -> Sprite2D
var _born := {}              # house id -> match seconds it was first seen finished
var _growth := {}            # "bid:yard" / "bid:garden" -> Sprite2D
var _tethered := {}          # stable id -> [UnitView, post Sprite2D]
var puffs: Array = []        # [{p, t, v}] dust from builders' blows
var critters: Array = []     # [{kind, home, p, v, t, air, state}]
var _critter_towns := {}     # town centre id -> true once its critters are made
var _town_level := -1.0
var _queue_len := {}         # building id -> its queue's length last frame (a unit out: the door opens)
var _builders: Array = []   # unit slots building on the last tick read (their blows raise dust)
var _tick_seen := -1         # the world tick the sim was last read at
var spent_us := 0          # time spent in update (tests/town_bench.gd reads it)
var frames := 0
var enabled := true          # off: the town stands still (tests/town_bench.gd compares)


func setup(p_host) -> void:
	host = p_host
	z_index = 0


func reset() -> void:
	for d in [_pile_sprites, _growth]:
		for k in d:
			d[k].queue_free()
		d.clear()
	for k in _tethered:
		for n in _tethered[k]:
			n.queue_free()
	_tethered.clear()
	_last.clear()
	_idle_since.clear()
	piles.clear()
	_born.clear()
	_queue_len.clear()
	_tick_seen = -1
	_builders.clear()
	puffs.clear()
	critters.clear()
	_critter_towns.clear()


func update(delta: float) -> void:
	if not enabled:
		return
	time += delta
	var w = host.world
	var t0 := Time.get_ticks_usec()
	if w.tick != _tick_seen:   # what's read from the sim changes only on its ticks (20 a second)
		_tick_seen = w.tick
		_deliveries(w)
		_buildings(w)
		_workers(w)
	_dust(w)
	_decay(delta)
	_sync_piles(w)
	if frames % 15 == 0:   # houses age slowly: a few times a second is plenty
		_sync_growth(w)
		_sync_tethers(w)
	_critters_update(w, delta)
	spent_us += Time.get_ticks_usec() - t0
	frames += 1
	for p in puffs:
		p.t += delta
		p.p += p.v * delta
	puffs = puffs.filter(func(p): return p.t < 0.6)
	_ambience(w)
	queue_redraw()


func _now(w) -> float:
	return w.tick / 20.0


# ---------------------------------------------------------------- loads home and piles

## A load brought home: last frame it was carrying to a building, now its hands are empty.
func _deliveries(w) -> void:
	var u = w.units
	var seen := {}
	for i in u.count():
		var id: int = u.id[i]
		seen[id] = true
		var was = _last.get(id)
		if was != null and was[0] == Economy.RETURN and was[1] > 0 and u.carry[i] == 0:
			var b: int = w.buildings.index_of(was[3])
			if b >= 0:
				var kind: String = w.resources[was[2] - 1]
				var view = host.bviews.get(was[3])
				if view != null:
					view.door_pulse()   # in through the door with it
				var pile: Dictionary = piles.get(was[3], {})
				pile[kind] = minf(pile.get(kind, 0.0) + 1.0, PILE_MAX)
				piles[was[3]] = pile
		if was == null:
			_last[id] = [u.task[i], u.carry[i], u.carry_kind[i], u.target[i]]
		else:
			was[0] = u.task[i]
			was[1] = u.carry[i]
			was[2] = u.carry_kind[i]
			was[3] = u.target[i]
	for id in _last.keys():
		if not seen.has(id):
			_last.erase(id)
			_idle_since.erase(id)


func _decay(delta: float) -> void:
	for bid in piles:
		for kind in piles[bid]:
			piles[bid][kind] = maxf(0.0, piles[bid][kind] - delta / LOAD_DECAY_S)


static func pile_stage(loads: float) -> int:
	var st := 0
	for k in PILE_STAGE_AT.size():
		if loads >= PILE_STAGE_AT[k]:
			st = k + 1
	return st


## Where a building's pile of each resource goes: just outside its two front faces (the ones
## facing the camera), spread along them, skipping cells another building or a resource holds.
func _pile_spot(w, b: int, slot: int) -> Vector2:
	var bs = w.buildings
	var x0: int = bs.cx[b]
	var y0: int = bs.cy[b]
	var sx: int = bs.sx[b]
	var sy: int = bs.sy[b]
	var spots := []   # milli-tiles: along the lower-right face (x = x0 + sx), then the lower-left (y = y0 + sy)
	for f in [0.25, 0.75]:
		spots.append(Vector2((x0 + sx) * 1000 + 300, (y0 + sy * f) * 1000))
	for f in [0.75, 0.25]:
		spots.append(Vector2((x0 + sx * f) * 1000, (y0 + sy) * 1000 + 300))
	var m = w.map
	var k := 0
	for s in spots:
		var c: int = m.cell_of(int(s.x), int(s.y))
		var cx: int = int(s.x) / 1000
		var cy: int = int(s.y) / 1000
		if cx >= m.width or cy >= m.height or m.occupied[c] != 0 or m.resource_at(c) != "":
			continue
		if k == slot:
			return Iso.to_screen(s.x, s.y)
		k += 1
	return Vector2.INF


func _sync_piles(w) -> void:
	var bs = w.buildings
	var want := {}
	for bid in piles:
		var b: int = bs.index_of(bid)
		if b < 0:
			continue
		var view = host.bviews.get(bid)
		if view == null or not view.visible:
			continue
		var t: Dictionary = w.btypes[bs.kind[b]]
		var slot := 0
		for r in w.resources.size():   # in the resources' own order, so a kind keeps its place
			if t.drop[r] == 0:
				continue
			var kind: String = w.resources[r]
			var st := pile_stage(piles[bid].get(kind, 0.0))
			if st > 0 and host.kit.bakes.has("pile.%s.%d" % [kind, st]):
				var at := _pile_spot(w, b, slot)
				if at != Vector2.INF:
					want["%d:%s" % [bid, kind]] = [at, "pile.%s.%d" % [kind, st]]
			slot += 1
	_sync_sprites(_pile_sprites, want, host.layer)


## Make, move, re-skin or drop sprites to match `want` (key -> [position, bake name]).
func _sync_sprites(have: Dictionary, want: Dictionary, parent: Node) -> void:
	for k in have.keys():
		if not want.has(k):
			have[k].queue_free()
			have.erase(k)
	for k in want:
		var s: Sprite2D = have.get(k)
		if s != null and s.get_meta("bake") != want[k][1]:
			s.queue_free()
			s = null
		if s == null:
			s = host.kit.sprite(want[k][1])
			s.set_meta("bake", want[k][1])
			s.set_meta("offset_y", s.offset.y)
			parent.add_child(s)
			have[k] = s
		s.position = want[k][0]
		var m := Iso.to_milli(s.position)
		s.offset.y = s.get_meta("offset_y") - Iso.lift(m.x, m.y) / s.scale.y   # on a hill: raised, sorted on the base plane


# ---------------------------------------------------------------- workers and animals

## What a unit is seen doing, on top of the job the match view read from the sim: a farmer
## tends the rows with a hoe ("till"), an idle worker near home does a chore, an idle herd
## animal grazes. Called by the match view for every unit, every frame.
func job_for(i: int, job: String) -> String:
	if not enabled:
		return job
	var w = host.world
	var u = w.units
	if job == "forage" and _ground(w, i) in ["field", "paddy"]:
		return "till"
	if job == "" and u.moving[i] == 0 and w.types[u.kind[i]].get("behaviour", "") == "herd":
		return "graze"
	if job == "":
		return chores.get(u.id[i], "")
	return job


## What a worker holds, on top of the match view's pick: meat home from a hunt, a hoe in
## the fields, a broom for sweeping.
func tool_for(i: int, tool: String) -> String:
	if not enabled:
		return tool
	var w = host.world
	var u = w.units
	if u.task[i] == Economy.RETURN and u.carry[i] > 0 and _ground(w, i) == "carcass":
		return "load.meat"
	if u.task[i] == Economy.RETURN and u.carry[i] > 0 and u.carry_kind[i] > 0:
		# Some push their load home (D-127: the rats' scrap barrow with stone, the handcart with gold).
		var push: String = host.lib.creatures[w.types[u.kind[i]].recipe.creature].get("push_home", {}).get(w.resources[u.carry_kind[i] - 1], "")
		if push != "":
			return "push:" + push
	if u.task[i] == Economy.GATHER and _ground(w, i) in ["field", "paddy"]:
		return "tool.hoe"
	if chores.get(u.id[i], "") == "sweep":
		return "tool.broom"
	return tool


## The ground a worker works (its gathering cell), or "".
func _ground(w, i: int) -> String:
	var c: int = w.units.home[i]
	if c < 0:
		return ""
	return w.map.terrain_ids[w.map.terrain[c]]


## Builders' blows raise dust; idle workers near home (idle a few seconds, nothing queued)
## get a chore: pairs close together chat, the rest sweep or sit, a new pick every spell.
func _workers(w) -> void:
	var u = w.units
	var now := _now(w)
	var idle := []
	_builders.clear()
	for i in u.count():
		var id: int = u.id[i]
		var view = host.views.get(id)
		if view == null or not w.types[u.kind[i]].worker:
			continue
		if u.task[i] == Economy.BUILD:
			_builders.append(i)
		if u.task[i] == Economy.NONE and u.moving[i] == 0 and u.orders[i].is_empty():
			if not _idle_since.has(id):
				_idle_since[id] = now
			if now - _idle_since[id] >= CHORE_AFTER_S and _near_home(w, i):
				idle.append(i)
		else:
			_idle_since.erase(id)
	var talking := {}
	for a in idle.size():
		var i: int = idle[a]
		if talking.has(i):
			continue
		for b2 in range(a + 1, idle.size()):
			var j: int = idle[b2]
			if talking.has(j) or u.owner[j] != u.owner[i]:
				continue
			if absi(u.x[j] - u.x[i]) + absi(u.y[j] - u.y[i]) < CHAT_REACH:
				talking[i] = j
				talking[j] = i
				break
	chores.clear()
	for i in idle:
		var id: int = u.id[i]
		var spell := int((now - _idle_since[id]) / CHORE_SPELL_S) + id
		var chore: String = ["sweep", "sit", "sweep", "sit"][spell % 4]
		if talking.has(i) and spell % 3 != 0:
			chore = "chat"
			var other = host.views.get(u.id[talking[i]])
			if other != null:
				host.views[id].face_vec(other.position - host.views[id].position)
		chores[id] = chore


## Dust where a builder's blow lands: every frame, over the builders found on the last tick read
## (unit slots stay put between ticks).
func _dust(w) -> void:
	var u = w.units
	for i in _builders:
		if i >= u.count():
			continue
		var view = host.views.get(u.id[i])
		if view == null or not (view.job == "build" and view.struck and view.visible):
			continue
		var at: Vector2 = host._work_point(i)
		var d: Vector2 = at - view.position
		var hit: Vector2 = view.ground() + d.normalized() * minf(10.0, d.length())
		for k in 3:
			puffs.append({"p": hit + Vector2(randf_range(-2, 2), randf_range(-1, 1)), "t": 0.0,
				"v": Vector2(randf_range(-7, 7), randf_range(-6, -2))})


func _near_home(w, i: int) -> bool:
	var bs = w.buildings
	var u = w.units
	for b in bs.count():
		if bs.owner[b] != u.owner[i] or bs.done[b] == 0:
			continue
		var t: Dictionary = w.btypes[bs.kind[b]]
		if not t.house and t.id != "town_center":
			continue
		var cx: int = (bs.cx[b] * 2 + bs.sx[b]) * 500
		var cy: int = (bs.cy[b] * 2 + bs.sy[b]) * 500
		if absi(cx - u.x[i]) + absi(cy - u.y[i]) < CHORE_NEAR_HOME:
			return true
	return false


# ---------------------------------------------------------------- buildings

func _buildings(w) -> void:
	var bs = w.buildings
	for b in bs.count():
		var view = host.bviews.get(bs.id[b])
		if view == null:
			continue
		var t: Dictionary = w.btypes[bs.kind[b]]
		view.set_working(t.house or not bs.queue[b].is_empty())
		var n: int = bs.queue[b].size()
		if n < _queue_len.get(bs.id[b], 0):
			view.door_pulse()   # trained (or researched): out through the door
		_queue_len[bs.id[b]] = n
		if bs.done[b] == 1 and host._memory(b) == null:
			view.set_damage(1.0 - float(bs.hp[b]) / float(t.hp))
		if t.house and bs.done[b] == 1 and not _born.has(bs.id[b]):
			_born[bs.id[b]] = _now(w)


## A house's yard and garden: one on each side corner (left and right on screen), growing
## through three stages with the house's age. Not where a building or a resource stands.
func _sync_growth(w) -> void:
	var bs = w.buildings
	var want_up := {}
	var want_flat := {}
	var now := _now(w)
	for bid in _born.keys():
		var b: int = bs.index_of(bid)
		var view = host.bviews.get(bid)
		if b < 0 or view == null:
			_born.erase(bid)
			continue
		if not view.visible:
			continue
		var age: float = now - _born[bid]
		var st := 0
		for k in YARD_AT_S.size():
			if age >= YARD_AT_S[k]:
				st = k + 1
		if st == 0:
			continue
		var x0: int = bs.cx[b]
		var y0: int = bs.cy[b]
		var x1: int = x0 + bs.sx[b]
		var y1: int = y0 + bs.sy[b]
		var spots := [Vector2(x1 * 1000 + 250, y0 * 1000 + 350), Vector2(x0 * 1000 + 350, y1 * 1000 + 250),   # off the side corners
			Vector2(x1 * 1000 + 300, y1 * 1000 - 700), Vector2(x1 * 1000 - 700, y1 * 1000 + 300)]          # else along the front faces
		if bid % 2 == 1:
			spots = [spots[1], spots[0], spots[3], spots[2]]
		var free := spots.filter(func(p): return _free(w, p))
		if free.size() > 0:
			want_up["%d:yard" % bid] = [Iso.to_screen(free[0].x, free[0].y), "yard%d" % mini(st, 3)]
		if st >= 2 and free.size() > 1:   # the garden comes a stage behind the yard
			want_flat["%d:garden" % bid] = [Iso.to_screen(free[1].x, free[1].y), "garden%d" % (st - 1)]
	var up := {}
	var fl := {}
	for k in _growth:
		(fl if k.ends_with(":garden") else up)[k] = _growth[k]
	_sync_sprites(up, want_up, host.layer)
	_sync_sprites(fl, want_flat, host.flat)
	_growth = up
	_growth.merge(fl)


func _free(w, at: Vector2) -> bool:
	var m = w.map
	var cx := int(at.x) / 1000
	var cy := int(at.y) / 1000
	if cx < 0 or cy < 0 or cx >= m.width or cy >= m.height:
		return false
	var c: int = cy * m.width + cx
	return m.occupied[c] == 0 and m.resource_at(c) == "" and m.walk[c] == 1 and not host.ground.on_path(at / 1000.0)


## A stable with one of its race's mounts tethered by it (races whose large units ride a
## mount of their own, not a centaur's other half): the mount on its own, idling and grazing.
func _sync_tethers(w) -> void:
	var bs = w.buildings
	var keep := {}
	for b in bs.count():
		if w.btypes[bs.kind[b]].id != "stable" or bs.done[b] == 0:
			continue
		var bid: int = bs.id[b]
		var view = host.bviews.get(bid)
		if view == null:
			continue
		var recipe := _mount_recipe(w.races[bs.owner[b]])
		if recipe.is_empty():
			continue
		keep[bid] = true
		if not _tethered.has(bid):
			var at := Vector2((bs.cx[b] + bs.sx[b]) * 1000 + 350, (bs.cy[b] + bs.sy[b] * 0.5) * 1000)
			var post: Sprite2D = host.kit.sprite("tether_post")
			post.position = Iso.to_screen(at.x, at.y)
			post.offset.y -= Iso.lift(at.x, at.y) / post.scale.y
			host.layer.add_child(post)
			var mount := UnitView.new()
			mount.build(recipe, host.lib, Color(host.lib.palettes.teams[bs.owner[b]]), 6)
			mount.scale = Vector2.ONE * host.kit.UNIT_SCALE
			mount.position = Iso.to_screen(at.x + 300, at.y + 250)
			mount.lift = Iso.lift(at.x + 300, at.y + 250)
			mount.pose_steps = 4
			mount.art_px = host.camera.zoom.x * host.kit.UNIT_SCALE
			host.layer.add_child(mount)
			mount.face_vec(post.position - mount.position)
			_tethered[bid] = [mount, post]
		var pair: Array = _tethered[bid]
		for n in pair:
			n.visible = view.visible
		pair[0].job = "graze" if int(time / 7.0 + bid) % 3 == 0 else ""
	for bid in _tethered.keys():
		if not keep.has(bid):
			for n in _tethered[bid]:
				n.queue_free()
			_tethered.erase(bid)


## The mount a race's large unit rides, as a unit recipe of its own (no rider), or {} if the
## race doesn't ride one (giants, Heavy elites, centaurs).
func _mount_recipe(race: Dictionary) -> Dictionary:
	for u in race.units:
		var r: Dictionary = u.recipe
		if r.slot == "large" and r.has("mount") and not r.mount.get("fused", false):
			var mc: Dictionary = host.lib.creatures[r.mount.creature]
			return {"slot": "mount", "name": "", "body": mc.get("mount_body", mc.body), "head": mc.get("mount_head", mc.head), "parts": {},
				"scale": 100, "skin": r.mount.skin, "family": r.family, "creature": r.mount.creature}
	return {}


# ---------------------------------------------------------------- critters

## Each Town Center gets a few critters of its culture, living round it: they peck about on
## the ground (pigeons, small birds) and flutter off when someone comes close, or hover and
## dart about (dragonflies). Only drawn where the side you command can see.
func _critters_update(w, delta: float) -> void:
	var bs = w.buildings
	for b in bs.count():
		if w.btypes[bs.kind[b]].id != "town_center" or bs.done[b] == 0 or _critter_towns.has(bs.id[b]):
			continue
		_critter_towns[bs.id[b]] = true
		var arch: String = host.lib.architecture(w.races[bs.owner[b]])
		var kind: String = {"reed": "dragonfly", "junk": "pigeon"}.get(arch, "bird")
		var home := Iso.to_ground((bs.cx[b] * 2 + bs.sx[b]) * 500, (bs.cy[b] * 2 + bs.sy[b]) * 500)
		for k in CRITTERS_PER_TOWN:
			var a := k * TAU / CRITTERS_PER_TOWN + randf() * 0.6
			var r := randf_range(70.0, 130.0)
			var p := home + Vector2(cos(a) * r, sin(a) * r * 0.5)
			critters.append({"kind": kind, "home": home, "p": p, "v": Vector2.ZERO, "t": randf() * 5.0, "air": 0.0 if kind != "dragonfly" else 8.0,
				"goal": p, "face": 1.0})
	for c in critters:
		c.t += delta
		if c.kind == "dragonfly":
			_dragonfly(c, delta)
		else:
			_ground_bird(c, delta, w)


func _dragonfly(c: Dictionary, delta: float) -> void:
	# Hover in place, then a quick dart to a new spot near home; bob a little.
	if c.p.distance_to(c.goal) < 1.0:
		if randf() < delta * 0.8:
			var a := randf() * TAU
			c.goal = c.home + Vector2(cos(a), sin(a) * 0.5) * randf_range(40.0, 140.0)
	else:
		c.p = c.p.move_toward(c.goal, delta * 60.0)
		c.face = signf(c.goal.x - c.p.x) if absf(c.goal.x - c.p.x) > 0.5 else c.face
	c.air = 8.0 + sin(c.t * 3.0) * 1.5


func _ground_bird(c: Dictionary, delta: float, w) -> void:
	if c.air > 0.0 or c.get("flying", false):
		# Flying off (or back): up, across to a new spot, down.
		var d: Vector2 = c.goal - c.p
		var left := d.length()
		c.p = c.p.move_toward(c.goal, delta * 55.0)
		c.face = signf(d.x) if absf(d.x) > 0.5 else c.face
		c.air = minf(18.0, left * 0.25 + 2.0) if left > 1.0 else 0.0
		c.flying = left > 1.0
		return
	# On the ground: hop a step now and then, peck, and fly off when a unit comes close.
	if fmod(c.t, 0.5) < delta and randf() < 0.35:
		var step := Vector2(randf_range(-4, 4), randf_range(-2, 2))
		c.p += step
		if absf(step.x) > 0.5:
			c.face = signf(step.x)
	var scare := false
	for v in host.views.values():
		if v.walking and v.position.distance_squared_to(c.p) < 18.0 * 18.0:
			scare = true
			break
	if scare or c.p.distance_to(c.home) > 170.0:
		var a := randf() * TAU
		c.goal = c.home + Vector2(cos(a), sin(a) * 0.5) * randf_range(60.0, 130.0)
		c.flying = true


# ---------------------------------------------------------------- the town's sound

## The town ambience follows your town: its size (finished buildings and workers), and how
## close the camera is to your Town Center (half as loud a screen away, gone further out).
func _ambience(w) -> void:
	var bs = w.buildings
	var buildings := 0
	var centre := Vector2.INF
	for b in bs.count():
		if bs.owner[b] == host.active and bs.done[b] == 1:
			buildings += 1
			if centre == Vector2.INF and w.btypes[bs.kind[b]].id == "town_center":
				centre = Iso.to_screen((bs.cx[b] * 2 + bs.sx[b]) * 500, (bs.cy[b] * 2 + bs.sy[b]) * 500)
	var workers := 0
	var u = w.units
	for i in u.count():
		if u.owner[i] == host.active and w.types[u.kind[i]].worker:
			workers += 1
	var size := clampf((buildings - 1) / 14.0 * 0.6 + workers / 40.0 * 0.4, 0.0, 1.0)
	var near := 0.0
	if centre != Vector2.INF:
		var half: Vector2 = host.get_viewport_rect().size * 0.5 / host.camera.zoom
		var off: Vector2 = (centre - host.camera.get_screen_center_position()) / half
		near = clampf(1.6 - maxf(absf(off.x), absf(off.y)), 0.0, 1.0)
	var level := snappedf(size * near, 0.02)
	if level != _town_level:
		_town_level = level
		host.audio.town(level)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var px: float = 1.0 / host.kit.ART_SCALE
	for p in puffs:   # dust: soft brown dots growing and fading
		var k: float = p.t / 0.6
		draw_circle(p.p, (1.2 + 2.5 * k) * px * 1.5, Color(0.62, 0.52, 0.38, 0.55 * (1.0 - k)))
	var w = host.world
	for c in critters:
		var cell := Iso.to_milli(c.p)
		if not host.reveal and not (cell.x >= 0 and cell.y >= 0 and cell.x < w.map.width * 1000 and cell.y < w.map.height * 1000 and Fog.visible(w, host.active, cell.x, cell.y)):
			continue
		var at: Vector2 = (c.p / px).round() * px
		var up := Vector2(0, -roundf(c.air) * px)
		match c.kind:
			"dragonfly":
				draw_rect(Rect2(at + Vector2(-px, 0), Vector2(px * 2, px)), Color(0, 0, 0, 0.18))   # its shadow
				var b := at + up
				draw_rect(Rect2(b + Vector2(-2 * px, 0), Vector2(px * 4, px)), Color("#2e8a8a"))
				draw_rect(Rect2(b + Vector2(2 * px if c.face > 0 else -3 * px, -px * 0.5), Vector2(px, px)), Color("#1a5a5a"))   # its head
				var flick := int(c.t * 30.0) % 2 == 0
				var wc := Color(0.85, 0.95, 1.0, 0.75 if flick else 0.4)
				draw_rect(Rect2(b + Vector2(-px, -px), Vector2(px, px)), wc)
				draw_rect(Rect2(b + Vector2(px, -px), Vector2(px, px)), wc)
			_:
				var body := Color("#8a8e96") if c.kind == "pigeon" else Color("#7a5a3a")
				var head := Color("#5a6a70") if c.kind == "pigeon" else Color("#4a3a2a")
				var b := at + up
				if c.air > 0.5:
					draw_rect(Rect2(at + Vector2(-px, 0), Vector2(px * 2, px)), Color(0, 0, 0, 0.18))
					var flap := int(c.t * 14.0) % 2 == 0
					draw_rect(Rect2(b + Vector2(-px, 0), Vector2(px * 3, px)), body)
					draw_rect(Rect2(b + Vector2(-px * 2, -px if flap else px), Vector2(px * 2, px)), body.lightened(0.1))
					draw_rect(Rect2(b + Vector2(px, -px if flap else px), Vector2(px * 2, px)), body.lightened(0.1))
				else:
					var peck := fmod(c.t, 1.3) < 0.25
					draw_rect(Rect2(b + Vector2(-px, -px * 2), Vector2(px * 3, px * 2)), body)
					var hx: float = 2.0 * px if c.face > 0 else -2.0 * px
					draw_rect(Rect2(b + Vector2(hx, -px * (1 if peck else 3)), Vector2(px, px)), head)
					draw_rect(Rect2(b + Vector2(-px if c.face > 0 else px, 0), Vector2(px, px * 0.5)), Color(0, 0, 0, 0.25))
