extends RefCounted
## The combat half of the sim: armour classes, targets, chasing, hitscan damage and
## deaths. Static functions over the World `w`, like economy.gd. Integers only,
## ascending ids, no Nodes.
##
## Damage uses armour classes (the genre's model): an attack has a base type (melee or
## pierce) plus bonus classes; a target has armour per class and belongs to melee,
## pierce, `building` (if it is one) and every one of its tags. Damage =
## max(min_damage, sum over the attack's classes the target belongs to of
## max(0, attack - armour)). Hits within a tick land together, so ids don't decide
## who strikes first.
##
## Shots fly (shots.gd): a ranged attack is loosed at the spot its target stands on (led by its
## pace, rules shot_lead_pct), its damage worked out then, and lands a flight later (distance over
## the weapon's shot speed: rules shot_speed, or shot_speeds by weapon tag). It hits the target if
## its body still covers the spot (within shot_slack), else it falls in the ground (or, with rules
## shot_strays on, on the nearest other foe of the shooter whose body does: never a friend, never
## an animal it wasn't meant for). Buildings never dodge. Shooters fighting on their own leave a foe that the shots
## already on their way will kill, so a volley doesn't all go into one dying unit.

const Fixed := preload("res://src/sim/fixed.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Economy := preload("res://src/sim/economy.gd")
const Flow := preload("res://src/sim/flow.gd")
const Animals := preload("res://src/sim/animals.gd")
const Bridges := preload("res://src/sim/bridges.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const Fog := preload("res://src/sim/fog.gd")
const Shots := preload("res://src/sim/shots.gd")

## units.stance, what a unit is doing: nothing, an ordered target, a fight it found
## itself, an attack-move, or walking back to where it stood (defensive units).
enum { NONE, ORDERED, AUTO, ATTACK_MOVE, RETURN }
## units.posture, the player's stance (the genre's four), set by Commands.STANCE. It only
## changes what a unit does on its own; ordered attacks and attack-moves work under all.
##   AGGRESSIVE: goes for anything in sight and keeps chasing (the default).
##   DEFENSIVE:  goes for foes that come near (rules defend_sight), chases no further
##               than rules leash from where it stood, then walks back.
##   STAND:      never moves to fight: hits only what is already in its reach.
##   PASSIVE:    never fights on its own, not even back.
enum { AGGRESSIVE, DEFENSIVE, STAND, PASSIVE }
const POSTURES := ["aggressive", "defensive", "stand", "passive"]   # Commands.STANCE args.stance, by index

const BASE := ["melee", "pierce", "building"]   # the first classes, always at these indexes
## Spreading out: a foe already fought by others looks this much further away per
## attacker (milli-tiles), so a 10-vs-10 clash becomes ten duels, not a pile-on.
const SPREAD := 1500
## A unit whose foe has more than this many attackers looks for a free foe close by.
const CROWDED := 2
## A standing shooter keeps shooting until its foe is this far (milli-tiles) beyond its reach:
## a shove from a neighbour no longer reads as "out of range" and walks it a step closer. Melee
## units standing at their place round a building get the same slack (a big body, a ram, at a
## place near a corner stood just out of reach).
const HOLD := 120


## Build the class table and give every unit and building type its combat vectors.
static func setup(w) -> void:
	var names := {}
	for t in w.types:
		for l in t.line:   # every age's kit, so an age-up never meets a new class
			var e: Dictionary = l.eval
			for k in e.armour:
				names[k] = true
			for k in e.bonus:
				names[k] = true
			for k in e.tags:
				names[k] = true
	for b in w.btypes:
		for k in b.armour:
			names[k] = true
	for k in BASE:
		names.erase(k)
	var rest := names.keys()
	rest.sort()
	w.classes = BASE + rest
	for t in w.types:
		type_vectors(w, t)
	for b in w.btypes:
		b.arm = _vector(w, b.armour)
		if not b.attack.is_empty():   # towers shoot
			b.atk = _vector(w, {b.attack.damage: int(b.attack.attack)})
			b.reach = int(b.attack.range) * SimMap.TILE
			b.reload = int(b.attack.reload)
			b.shot_speed = int(w.combat.shot_speed)
		var cls := PackedByteArray()
		cls.resize(w.classes.size())
		cls[0] = 1
		cls[1] = 1
		cls[2] = 1
		b.cls = cls


## A unit type's attack and armour vectors, classes, reach and reload, from its eval.
static func type_vectors(w, t: Dictionary) -> void:
	var c: Dictionary = w.combat
	if true:
		var e: Dictionary = t.eval
		var atk := _vector(w, {e.damage: int(e.attack)})
		var bonus := _vector(w, e.bonus)
		for k in atk.size():
			atk[k] += bonus[k]
		t.atk = atk
		t.arm = _vector(w, e.armour)
		var cls := PackedByteArray()
		cls.resize(w.classes.size())
		cls[0] = 1
		cls[1] = 1
		for k in e.tags:
			cls[w.classes.find(k)] = 1
		t.cls = cls
		var ranged: bool = int(e["range"]) > 1
		t.reach = int(e["range"]) * SimMap.TILE if ranged else int(c.melee_reach)
		t.reload = int(c.ranged_reload) if ranged else int(c.melee_reload)
		t.ranged = ranged
		t.shot_speed = int(c.shot_speed)
		for k in e.tags:   # the weapon's own pace (a javelin is slower than an arrow), first tag that has one
			if c.shot_speeds.has(k):
				t.shot_speed = int(c.shot_speeds[k])
				break
		# Siege weapons (milestone 13): their own reload, a minimum range, splash, pass-through,
		# and rams go for buildings only. Machines aren't healed (rules heal_not).
		if int(e.get("reload", 0)) > 0:
			t.reload = int(e.reload)
		t.min_range = int(e.get("min_range", 0)) * SimMap.TILE
		t.splash = int(e.get("splash", 0))
		t.pass_len = int(e.get("pass", 0))
		t.buildings_only = e.get("targets", "") == "buildings"
		t.no_heal = e.tags.any(func(k): return k in c.get("heal_not", []))


static func _vector(w, d: Dictionary) -> PackedInt32Array:
	var v := PackedInt32Array()
	v.resize(w.classes.size())
	for k in d:
		v[w.classes.find(k)] = int(d[k])
	return v


## The damage formula, on class vectors.
static func damage(atk: PackedInt32Array, arm: PackedInt32Array, cls: PackedByteArray, min_damage: int) -> int:
	var d := 0
	for k in atk.size():
		if atk[k] > 0 and cls[k] == 1:
			d += maxi(0, atk[k] - arm[k])
	return maxi(min_damage, d)


# ------------------------------------------------------------------ orders

## Forget any combat order (a new move, gather or build order does this).
static func clear(w, i: int) -> void:
	w.units.foe[i] = 0
	w.units.stance[i] = NONE
	w.units.patient[i] = 0


static func cmd_attack(w, player: int, a: Dictionary) -> void:
	if not _is_target(w, a.target, player):
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player and not w.types[w.units.kind[i]].healer and not w.types[w.units.kind[i]].get("harmless", false) \
				and not (w.types[w.units.kind[i]].get("buildings_only", false) and w.units.index_of(a.target) >= 0):   # healers and sheep never fight; rams hit buildings only
			Economy.clear_task(w, i)
			w.units.foe[i] = a.target
			w.units.stance[i] = ORDERED
			w.units.moving[i] = 0


static func cmd_attack_move(w, player: int, a: Dictionary) -> void:
	var slots := []
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player:
			slots.append(i)
	if slots.is_empty():
		return
	# Each to its own slot of the group's formation (World._formation), and back to it after a fight.
	var centre: int = w.map.cell_of(int(a.fx), int(a.fy))
	for i in slots:
		var s: Vector2i = w.slot_of(a, w.units.id[i])
		if w.types[w.units.kind[i]].get("harmless", false):
			clear(w, i)   # a sheep along with the army just walks to its place
			w.order_move(i, s.x, s.y, w.SLOT_ARRIVE, a.group, a.fx, a.fy, a.pace)
			continue
		Economy.clear_task(w, i)
		w.units.foe[i] = 0
		w.units.patient[i] = 0
		w.units.stance[i] = ATTACK_MOVE
		w.units.amx[i] = s.x
		w.units.amy[i] = s.y
		w.units.amc[i] = centre
		w.order_move(i, s.x, s.y, w.SLOT_ARRIVE, a.group, a.fx, a.fy, a.pace)


## Set the stance of a player's units. A unit fighting on its own that the new stance
## wouldn't let it start (passive, or out of reach for stand ground) lets go now.
static func cmd_stance(w, player: int, a: Dictionary) -> void:
	var p := POSTURES.find(a.stance)
	assert(p >= 0, "Unknown stance %s" % a.stance)
	var u = w.units
	for uid in a.ids:
		var i: int = u.index_of(uid)
		if i < 0 or u.owner[i] != player or w.types[u.kind[i]].has("animal"):
			continue   # animals have no stance
		u.posture[i] = p
		if u.stance[i] == AUTO and p == PASSIVE:
			u.foe[i] = 0
			u.stance[i] = NONE
			u.moving[i] = 0


## Starting a fight on its own: remember where it stood, for defensive units to walk back to.
static func _engage(w, i: int, foe: int) -> void:
	var u = w.units
	if u.stance[i] != RETURN:
		u.gx[i] = u.x[i]
		u.gy[i] = u.y[i]
	u.foe[i] = foe
	u.stance[i] = AUTO


## How far a unit with this stance looks for a fight on its own (centre to centre).
static func _look(w, i: int, t: Dictionary) -> int:
	var c: Dictionary = w.combat
	match w.units.posture[i]:
		DEFENSIVE:
			return maxi(int(c.defend_sight), t.reach + w.units.radius[i] + SimMap.TILE / 2)
		STAND:
			return t.reach + w.units.radius[i] + SimMap.TILE / 2
	return _sight(w, i, t)


## How far a unit looks for a fight at most: rules sight, or as far as it can shoot
## (centre to centre), whichever is further; a shooter shouldn't walk up to a foe it could hit.
static func _sight(w, i: int, t: Dictionary) -> int:
	return maxi(int(w.combat.sight), t.reach + w.units.radius[i] + SimMap.TILE / 2)


## How near (centre to centre) a foe may be for a unit with a minimum range to still hit it; 0 for
## everyone else.
static func _near(w, i: int, t: Dictionary) -> int:
	return t.min_range + w.units.radius[i] + BASE_RADIUS if t.min_range > 0 else 0


const BASE_RADIUS := 300   # a foot soldier's body (World.BASE_RADIUS), for minimum-range looks
const BACK_OFF := 1500     # how far beyond its minimum range an engine steps back from a foe under its nose


## Engine i's foe (unit j or building b) is inside its minimum range: another foe it can hit from
## where it stands, if there is one (not for an ordered target); else it steps back out of range,
## straight away from the foe, re-aimed on its re-plan beat.
static func _too_close(w, i: int, j: int, b: int, t: Dictionary, engaged: PackedInt32Array) -> void:
	var u = w.units
	if u.stance[i] != ORDERED:
		var f := _nearest_foe(w, i, t.reach + u.radius[i] + SimMap.TILE / 2, b >= 0, engaged, SPREAD, PackedInt32Array(), _near(w, i, t))
		if f != 0 and f != u.foe[i]:
			var fj: int = u.index_of(f)
			if j >= 0:
				engaged[j] -= 1
			if fj >= 0:
				engaged[fj] += 1
			u.foe[i] = f
			return
	if u.moving[i] == 1 and (w.tick + u.id[i]) % w.REPLAN_EVERY != 0:
		return
	var fx: int
	var fy: int
	if j >= 0:
		fx = u.x[j]
		fy = u.y[j]
	else:
		var bs = w.buildings
		fx = clampi(u.x[i], bs.cx[b] * SimMap.TILE, (bs.cx[b] + bs.sx[b]) * SimMap.TILE)
		fy = clampi(u.y[i], bs.cy[b] * SimMap.TILE, (bs.cy[b] + bs.sy[b]) * SimMap.TILE)
	var dx: int = u.x[i] - fx
	var dy: int = u.y[i] - fy
	var len := Fixed.isqrt(dx * dx + dy * dy)
	if len == 0:
		dx = 1
		len = 1
	var away: int = t.min_range + BACK_OFF
	var x: int = clampi(fx + dx * away / len, 0, w.map.width * SimMap.TILE - 1)
	var y: int = clampi(fy + dy * away / len, 0, w.map.height * SimMap.TILE - 1)
	w.order_move(i, x, y, 0, 0)


## Done with a fight it found itself: a defensive unit walks back to where it stood.
static func _go_back(w, i: int) -> void:
	var u = w.units
	u.foe[i] = 0
	if Fixed.dist2(u.x[i], u.y[i], u.gx[i], u.gy[i]) > SimMap.TILE * SimMap.TILE / 4:
		u.stance[i] = RETURN
		w.order_move(i, u.gx[i], u.gy[i], 0, 0)
	else:
		u.stance[i] = NONE
		u.moving[i] = 0


## An enemy unit or building of `player`, or an animal to hunt (wild, or its own sheep)?
static func _is_target(w, id: int, player: int) -> bool:
	var i: int = w.units.index_of(id)
	if i >= 0:
		return w.is_enemy(w.units.owner[i], player) or (w.units.owner[i] == player and w.types[w.units.kind[i]].has("animal"))
	var b: int = w.buildings.index_of(id)
	if b < 0:
		return Bridges.is_target(w, id)   # a map bridge: anyone may break it
	return w.is_enemy(w.buildings.owner[b], player)


# ------------------------------------------------------------------ tick

## One tick of fighting. Runs after worker jobs and before movement; w.spatial must
## have been built from the current positions.
static func tick(w) -> void:
	var u = w.units
	var bs = w.buildings
	var c: Dictionary = w.combat
	var n: int = u.count()
	var chasers := {}   # building slot -> melee units closing in on it (ascending slots)
	var hitters := {}   # building slot -> units in reach of it
	var hurt := PackedInt32Array()
	hurt.resize(n)
	var hurt_by := PackedInt32Array()
	hurt_by.resize(n)
	var bhurt := PackedInt32Array()
	bhurt.resize(bs.count())
	var brhurt := PackedInt32Array()   # per map bridge (bridges.gd)
	brhurt.resize(w.bridge_id.size())
	# How many attackers each unit already has (by slot), kept up to date as foes are
	# picked this tick, so picks spread over the enemy line.
	var engaged := PackedInt32Array()
	engaged.resize(n)
	for i in n:
		if u.foe[i] != 0:
			var j: int = u.index_of(u.foe[i])
			if j >= 0:
				engaged[j] += 1
	# Cooldowns tick down in one pass on a local copy (writing a packed array through
	# the object copies it every time; see units.gd).
	var cd: PackedInt32Array = u.cooldown
	for i in n:
		if cd[i] > 0:
			cd[i] -= 1
	u.cooldown = cd
	_land(w, hurt, hurt_by, bhurt)
	var inbound: PackedInt32Array = w.shots.inbound(u)   # damage still in the air, per unit
	for i in n:
		var t: Dictionary = w.types[u.kind[i]]
		if u.stance[i] == RETURN and u.moving[i] == 0:
			u.stance[i] = NONE   # back where it stood
		if t.healer or t.get("harmless", false):
			continue   # healers never fight (heal.gd), nor do sheep and deer; an attack-move walks them along with the army
		var stance: int = u.stance[i]
		var posture: int = u.posture[i]
		# Look for a fight: idle soldiers (not workers, not passive) and attack-movers, on their own beat.
		# Units fighting on their own (not an explicit target) also leave a crowded foe
		# for a free one nearby, so winners go and help where the fight is still on.
		if (w.tick + u.id[i]) % int(c.acquire_every) == 0:
			var idle: bool = stance == NONE and u.moving[i] == 0 and u.task[i] == Economy.NONE and not t.worker and posture != PASSIVE
			var free: bool = stance == AUTO or stance == ATTACK_MOVE
			var crowded := false
			if u.foe[i] != 0 and free:
				var cur: int = u.index_of(u.foe[i])
				crowded = cur >= 0 and engaged[cur] > CROWDED
			if (u.foe[i] == 0 and (idle or stance == ATTACK_MOVE)) or crowded:
				var am: bool = stance == ATTACK_MOVE
				# Stand ground takes the nearest foe, not the least fought: the nearest is the one in reach.
				# Rams look for buildings only; engines with a minimum range for foes beyond it.
				var f := _nearest_foe(w, i, _sight(w, i, t) if am else _look(w, i, t), am or t.buildings_only, engaged, 0 if posture == STAND and not am else SPREAD,
					PackedInt32Array(), _near(w, i, t), not t.buildings_only)
				# A shooter in reach of its crowded foe has no crowd to get round: it only swaps to
				# another foe it can hit from where it stands, never walks off to a free one.
				if crowded and t.ranged and f != 0 and _gap(w, i, u.index_of(u.foe[i]), -1) <= t.reach:
					var fj: int = u.index_of(f)
					if fj < 0 or _gap(w, i, fj, -1) > t.reach:
						f = 0
				if f != 0 and f != u.foe[i]:
					var old: int = u.index_of(u.foe[i]) if u.foe[i] != 0 else -1
					if old >= 0:
						engaged[old] -= 1
					u.foe[i] = f
					var nj: int = u.index_of(f)
					if nj >= 0:
						engaged[nj] += 1
					if idle:
						_engage(w, i, f)
		if u.foe[i] == 0:
			continue
		var j: int = u.index_of(u.foe[i])
		var b: int = -1 if j >= 0 else bs.index_of(u.foe[i])
		var br: int = Bridges.index_of(w, u.foe[i]) if j < 0 and b < 0 and w.bridge_id.size() > 0 else -1
		if br >= 0 and w.bridge_up[br] == 1:   # breaking a bridge: walk up to it and hack away
			if Bridges.gap(w, i, br) <= t.reach:
				u.moving[i] = 0
				if u.cooldown[i] == 0:
					u.cooldown[i] = t.reload
					var d := Bridges.damage_from(w, br, t.atk, int(c.min_damage))
					brhurt[br] += d
					w.events.append({"type": "hit", "by": u.id[i], "to": u.foe[i], "damage": d, "ranged": t.ranged})
			elif Bridges.gap(w, i, br) <= Economy.REACH + SimMap.TILE:
				var r: Rect2i = w.bridge_rect[br]   # close: step straight onto the deck's edge
				w.order_direct(i, clampi(u.x[i], r.position.x, r.end.x), clampi(u.y[i], r.position.y, r.end.y))
			else:
				var key: int = w.building_field(u.foe[i], false, w.lane(i))
				if u.moving[i] == 0 or u.fkey[i] != key:
					w.order_reach(i, w.bridge_rect[br], key)
			continue
		if j < 0 and b < 0:
			# An attack-mover whose foe fell takes the next one at once: walking on until its
			# acquire beat stepped a whole line of shooters forward after every kill.
			var next := _nearest_foe(w, i, _sight(w, i, t), true, engaged, SPREAD, PackedInt32Array(), _near(w, i, t), not t.buildings_only) if u.stance[i] == ATTACK_MOVE else 0
			if next != 0:
				u.foe[i] = next
				var nj: int = u.index_of(next)
				if nj >= 0:
					engaged[nj] += 1
			else:
				_lost(w, i)
			continue
		var gap := _gap(w, i, j, b)
		var up := _height_step(w, i, j, b) if t.ranged else 0   # high ground: shooters reach further down, less far up
		if t.min_range > 0 and gap < t.min_range:
			_too_close(w, i, j, b, t, engaged)   # an engine can't hit what's under its nose
			continue
		if gap <= t.reach + up * int(w.high.reach) + (HOLD if (t.ranged or b >= 0) and u.moving[i] == 0 else 0):
			u.moving[i] = 0
			if b >= 0:
				hitters[b] = hitters.get(b, []) + [i]
			if u.cooldown[i] == 0 and j >= 0 and t.ranged and inbound[j] >= u.hp[j] and u.stance[i] != ORDERED:
				# Enough already flying at it to kill it: another foe in reach, or hold this shot.
				var f := _nearest_foe(w, i, t.reach + u.radius[i] + SimMap.TILE / 2, false, engaged, SPREAD, inbound, _near(w, i, t))
				var fj: int = u.index_of(f) if f != 0 else -1
				if fj < 0 or _gap(w, i, fj, -1) > t.reach + _height_step(w, i, fj, -1) * int(w.high.reach):
					continue
				engaged[j] -= 1
				engaged[fj] += 1
				u.foe[i] = f
				j = fj
				up = _height_step(w, i, j, -1)
			if u.cooldown[i] == 0:
				u.cooldown[i] = t.reload
				if j >= 0:
					var tt: Dictionary = w.types[u.kind[j]]
					var d := damage(t.atk, tt.arm, tt.cls, maxi(int(c.min_damage), tt.get("min_damage", 0)))   # a sheep goes down in a few blows
					if up < 0:
						d = uphill(w, d)
					if t.ranged:
						inbound[j] += d
						_loose(w, u.id[i], u.owner[i], u.x[i], u.y[i], j, -1, d, u.kind[i], up, t.shot_speed)
					else:
						hurt[j] += d
						hurt_by[j] = u.id[i]
						w.events.append({"type": "hit", "by": u.id[i], "to": u.id[j], "damage": d, "ranged": false})
				else:
					var bt: Dictionary = w.btypes[bs.kind[b]]
					var d := damage(t.atk, w.bmods[bs.owner[b]][bs.kind[b]].arm, bt.cls, int(c.min_damage))   # armour with research
					if up < 0:
						d = uphill(w, d)
					if t.ranged:
						_loose(w, u.id[i], u.owner[i], u.x[i], u.y[i], -1, b, d, u.kind[i], up, t.shot_speed)
					else:
						bhurt[b] += d
						w.events.append({"type": "hit", "by": u.id[i], "to": bs.id[b], "damage": d, "ranged": false})
		elif u.stance[i] == AUTO and posture == STAND:
			u.foe[i] = 0   # stand ground: out of reach, let it go
			u.stance[i] = NONE
			u.moving[i] = 0
		elif u.stance[i] == AUTO and posture == DEFENSIVE and Fixed.dist2(u.x[i], u.y[i], u.gx[i], u.gy[i]) > int(c.leash) * int(c.leash):
			_go_back(w, i)   # chased far enough
		elif u.stance[i] == AUTO and (gap > int(c.sight) + 2 * SimMap.TILE or (j >= 0 and u.owner[i] != w.gaia and not Fog.visible(w, u.owner[i], u.x[j], u.y[j]))):
			_lost(w, i)   # it got away, or out of its side's sight
		elif b >= 0 and not t.ranged:
			chasers[b] = chasers.get(b, []) + [i]   # dealt a place round it below
		else:
			_chase(w, i, j, b)
	var besieged: Array = chasers.keys()
	besieged.sort()
	for b in besieged:
		_surround(w, b, chasers[b], hitters.get(b, []))
	_towers(w)
	_apply(w, hurt, hurt_by, bhurt)
	for k in brhurt.size():
		if brhurt[k] > 0:
			Bridges.hurt(w, k, brhurt[k])


## Finished buildings that attack (towers, castles, a Town Center with people inside) shoot the
## nearest enemy units in reach: a volley of the type's arrows (data: the attack block's `arrows`,
## default 1) plus one for each unit sheltering inside, one at each of the nearest foes in turn
## (round again when there are fewer foes than arrows). Research adds reach (Slit Windows).
static func _towers(w) -> void:
	var bs = w.buildings
	var u = w.units
	var c: Dictionary = w.combat
	for b in bs.count():
		var bt: Dictionary = w.btypes[bs.kind[b]]
		if bt.attack.is_empty() or bs.done[b] == 0:
			continue
		var arrows: int = bt.arrows + bs.inside[b].size()
		if arrows <= 0:
			continue
		if bs.cooldown[b] > 0:
			bs.cooldown[b] -= 1
			continue
		var s: int = maxi(bs.sx[b], bs.sy[b]) * SimMap.TILE
		var mx: int = bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2
		var my: int = bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2
		var reach: int = bt.reach + int(w.bmods[bs.owner[b]][bs.kind[b]].add.get("range", 0)) * SimMap.TILE
		var hills: bool = w.map.has_heights
		var far: int = reach + s / 2 + (int(w.high.reach) if hills else 0)
		var limit: int = far * far + 1
		var lv: int = w.map.level[bs.cy[b] * w.map.width + bs.cx[b]]
		var near := []   # [distance squared, unit index, up], the nearest first (ties by index: stable)
		var sp = w.spatial   # only the tiles within reach (not every unit on the map, every tick a tower is loaded)
		var tr: int = far / SimMap.TILE + 1
		var tx: int = mx / SimMap.TILE
		var ty: int = my / SimMap.TILE
		for yy in range(maxi(ty - tr, 0), mini(ty + tr + 1, sp.height)):
			for xx in range(maxi(tx - tr, 0), mini(tx + tr + 1, sp.width)):
				var cell: int = yy * sp.width + xx
				for q in range(sp.start[cell], sp.start[cell + 1]):
					var j: int = sp.items[q]
					if not w.is_foe(u.owner[j], bs.owner[b]):
						continue
					var d := Fixed.dist2(mx, my, u.x[j], u.y[j])
					var up := 0
					if hills:   # high ground: a tower on a hill reaches further down, less far up
						up = signi(lv - w.map.level_at(u.x[j], u.y[j]))
						var r: int = reach + s / 2 + up * int(w.high.reach)
						if d > r * r:
							continue
					if d < limit:
						near.append([d, j, up])
		if near.is_empty():
			continue
		near.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
		for k in arrows:   # one event an arrow, so the view draws the volley
			var e: Array = near[k % near.size()]
			var best: int = e[1]
			var tt: Dictionary = w.types[u.kind[best]]
			var dmg := damage(bt.atk, tt.arm, tt.cls, int(c.min_damage))
			if e[2] < 0:
				dmg = uphill(w, dmg)
			_loose(w, bs.id[b], bs.owner[b], mx, my, best, -1, dmg, -1 - bs.kind[b], e[2], bt.shot_speed, k)
		bs.cooldown[b] = bt.reload


## Loose a shot from (sx, sy) at unit j (or building b): it flies at the spot the unit stands on,
## led by rules shot_lead_pct of the way it is walking, and lands a flight later (shots.gd). A
## "shot" event tells the view where and when; "hit" or "miss" follows on landing.
static func _loose(w, by: int, owner: int, sx: int, sy: int, j: int, b: int, d: int, src: int, up: int, speed: int, arrow := -1) -> void:
	var u = w.units
	var to: int
	var ax: int
	var ay: int
	if j >= 0:
		to = u.id[j]
		ax = u.x[j]
		ay = u.y[j]
		var lead: int = int(w.combat.shot_lead_pct)
		if u.moving[j] == 1 and lead > 0:
			var vx: int = u.wx[j] - ax
			var vy: int = u.wy[j] - ay
			var len := Fixed.isqrt(vx * vx + vy * vy)
			if len > 0:
				var pace: int = u.pace[j] if u.pace[j] > 0 else u.speed[j]
				var ahead: int = mini(len, pace * _flight(sx, sy, ax, ay, speed) * lead / 100)
				ax += vx * ahead / len
				ay += vy * ahead / len
	else:
		var bs = w.buildings
		to = bs.id[b]
		ax = bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2
		ay = bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2
	var f := _flight(sx, sy, ax, ay, speed)
	w.shots.add(w.tick + f, to, by, owner, d, src, up, ax, ay, sx, sy)
	var e := {"type": "shot", "by": by, "to": to, "x0": sx, "y0": sy, "x": ax, "y": ay, "ticks": f}
	if arrow >= 0:
		e["arrow"] = arrow
	w.events.append(e)


## Ticks a shot takes from one spot to another (at least one).
static func _flight(x0: int, y0: int, x1: int, y1: int, speed: int) -> int:
	return maxi(1, (Fixed.isqrt(Fixed.dist2(x0, y0, x1, y1)) + speed - 1) / speed)


## The shots landing this tick: on the target if its body still covers the spot (buildings always),
## else on the nearest other foe whose body does (its own damage against that one's armour), else
## in the ground. In loosing order; damage goes into this tick's hurt like a blow.
static func _land(w, hurt: PackedInt32Array, hurt_by: PackedInt32Array, bhurt: PackedInt32Array) -> void:
	if w.shots.count() == 0:
		return
	var recs: PackedInt32Array = w.shots.take(w.tick)
	var u = w.units
	var slack: int = int(w.combat.shot_slack)
	for o in range(0, recs.size(), Shots.STRIDE):
		var to: int = recs[o + Shots.TO]
		var by: int = recs[o + Shots.BY]
		var ax: int = recs[o + Shots.X]
		var ay: int = recs[o + Shots.Y]
		var d: int = recs[o + Shots.DAMAGE]
		var j: int = u.index_of(to)
		var b: int = w.buildings.index_of(to) if j < 0 else -1
		var src: int = recs[o + Shots.SRC]
		if src >= 0 and w.types[src].get("splash", 0) > 0:
			_splash(w, recs, o, b, hurt, hurt_by, bhurt)   # a stone lands on its spot, whoever is there
			continue
		if src >= 0 and w.types[src].get("pass_len", 0) > 0:
			_pass_through(w, recs, o, j, hurt, hurt_by)   # a bolt goes through those in its way, then on as a shot
		if b >= 0:   # buildings never dodge
			bhurt[b] += d
			w.events.append({"type": "hit", "by": by, "to": to, "damage": d, "ranged": true, "x": ax, "y": ay})
			continue
		if j >= 0:
			var r: int = u.radius[j] + slack
			if Fixed.dist2(ax, ay, u.x[j], u.y[j]) > r * r:
				j = -1   # it stepped off the spot
		if j < 0:   # missed, or its target fell (or went inside) before it landed: anyone else there?
			j = _stray(w, recs[o + Shots.OWNER], ax, ay, slack) if w.combat.shot_strays == 1 else -1
			if j >= 0:
				d = _shot_damage(w, recs[o + Shots.SRC], recs[o + Shots.UP], j)
		if j >= 0:
			hurt[j] += d
			hurt_by[j] = by
			w.events.append({"type": "hit", "by": by, "to": u.id[j], "damage": d, "ranged": true, "x": ax, "y": ay})
		else:
			w.events.append({"type": "miss", "by": by, "to": to, "x": ax, "y": ay})


## A stone lands (a weapon with `splash`, milli-tiles): every unit whose body is within the splash of
## the spot takes the shooter's damage against its own armour, scaled down by how far its edge is
## from the spot (x (splash - gap) / splash: full on the spot, nothing at the rim); friends in it
## take rules splash_friend_pct of that (the genre's stone throwers hurt their own side too), the
## shooter itself and animals nothing. The building it was thrown at takes it in full; other enemy
## buildings in the splash by the same falloff. One "splash" event for the view, a "hit" per victim.
static func _splash(w, recs: PackedInt32Array, o: int, b: int, hurt: PackedInt32Array, hurt_by: PackedInt32Array, bhurt: PackedInt32Array) -> void:
	var u = w.units
	var sp = w.spatial
	var t: Dictionary = w.types[recs[o + Shots.SRC]]
	var by: int = recs[o + Shots.BY]
	var owner: int = recs[o + Shots.OWNER]
	var x: int = recs[o + Shots.X]
	var y: int = recs[o + Shots.Y]
	var up: int = recs[o + Shots.UP]
	var r: int = t.splash
	var friend_pct := int(w.combat.get("splash_friend_pct", 100))
	w.events.append({"type": "splash", "by": by, "x": x, "y": y, "r": r})
	var reach: int = (r + MAX_BODY) / SimMap.TILE + 1
	var cx: int = x / SimMap.TILE
	var cy: int = y / SimMap.TILE
	for yy in range(maxi(cy - reach, 0), mini(cy + reach + 1, sp.height)):
		for xx in range(maxi(cx - reach, 0), mini(cx + reach + 1, sp.width)):
			var cell: int = yy * sp.width + xx
			for q in range(sp.start[cell], sp.start[cell + 1]):
				var k: int = sp.items[q]
				if u.id[k] == by or u.owner[k] == w.gaia or w.types[u.kind[k]].has("animal"):
					continue
				var gap: int = maxi(0, Fixed.isqrt(Fixed.dist2(x, y, u.x[k], u.y[k])) - u.radius[k])
				if gap >= r:
					continue
				var tt: Dictionary = w.types[u.kind[k]]
				var d := damage(t.atk, tt.arm, tt.cls, maxi(int(w.combat.min_damage), tt.get("min_damage", 0)))
				if up < 0:
					d = uphill(w, d)
				d = d * (r - gap) / r
				if not w.is_enemy(owner, u.owner[k]):
					d = d * friend_pct / 100
				if d <= 0:
					continue
				hurt[k] += d
				hurt_by[k] = by
				w.events.append({"type": "hit", "by": by, "to": u.id[k], "damage": d, "ranged": true, "x": x, "y": y})
	var bs = w.buildings
	for k in bs.count():
		if k != b and not w.is_enemy(owner, bs.owner[k]):
			continue
		var gx: int = maxi(maxi(bs.cx[k] * SimMap.TILE - x, 0), x - (bs.cx[k] + bs.sx[k]) * SimMap.TILE)
		var gy: int = maxi(maxi(bs.cy[k] * SimMap.TILE - y, 0), y - (bs.cy[k] + bs.sy[k]) * SimMap.TILE)
		var gap := Fixed.isqrt(gx * gx + gy * gy)
		if k != b and gap >= r:
			continue
		var d := damage(t.atk, w.bmods[bs.owner[k]][bs.kind[k]].arm, w.btypes[bs.kind[k]].cls, int(w.combat.min_damage))
		if up < 0:
			d = uphill(w, d)
		if k != b:
			d = d * (r - gap) / r
		if d <= 0:
			continue
		bhurt[k] += d
		w.events.append({"type": "hit", "by": by, "to": bs.id[k], "damage": d, "ranged": true, "x": x, "y": y})


const MAX_BODY := 500   # the biggest body's radius (World.MAX_RADIUS): how far round a spot to look


## A bolt (a weapon with `pass`, milli-tiles) goes through what's in its way: every foe of the
## shooter (not the one it was aimed at, whose hit or miss is the usual one; not animals) whose
## body is on the last `pass` of its flight, from where it was loosed to the spot it lands on,
## takes the shooter's damage against its own armour.
static func _pass_through(w, recs: PackedInt32Array, o: int, aimed: int, hurt: PackedInt32Array, hurt_by: PackedInt32Array) -> void:
	var u = w.units
	var sp = w.spatial
	var t: Dictionary = w.types[recs[o + Shots.SRC]]
	var by: int = recs[o + Shots.BY]
	var owner: int = recs[o + Shots.OWNER]
	var x1: int = recs[o + Shots.X]
	var y1: int = recs[o + Shots.Y]
	var dx: int = x1 - recs[o + Shots.X0]
	var dy: int = y1 - recs[o + Shots.Y0]
	var len := Fixed.isqrt(dx * dx + dy * dy)
	if len == 0:
		return
	var run: int = mini(t.pass_len, len)
	var x0: int = x1 - dx * run / len
	var y0: int = y1 - dy * run / len
	var slack: int = int(w.combat.shot_slack)
	var lo := Vector2i(mini(x0, x1) - MAX_BODY - slack, mini(y0, y1) - MAX_BODY - slack) / SimMap.TILE
	var hi := Vector2i(maxi(x0, x1) + MAX_BODY + slack, maxi(y0, y1) + MAX_BODY + slack) / SimMap.TILE
	for yy in range(maxi(lo.y, 0), mini(hi.y + 1, sp.height)):
		for xx in range(maxi(lo.x, 0), mini(hi.x + 1, sp.width)):
			var cell: int = yy * sp.width + xx
			for q in range(sp.start[cell], sp.start[cell + 1]):
				var k: int = sp.items[q]
				if k == aimed or u.id[k] == recs[o + Shots.TO] or not w.is_foe(u.owner[k], owner) or w.types[u.kind[k]].has("animal"):
					continue
				# The nearest point of the bolt's run to its centre, in integers.
				var px: int = u.x[k] - x0
				var py: int = u.y[k] - y0
				var along: int = clampi((px * (x1 - x0) + py * (y1 - y0)) / maxi(1, run), 0, run)
				var nx: int = x0 + (x1 - x0) * along / maxi(1, run)
				var ny: int = y0 + (y1 - y0) * along / maxi(1, run)
				var rr: int = u.radius[k] + slack
				if Fixed.dist2(nx, ny, u.x[k], u.y[k]) > rr * rr:
					continue
				var tt: Dictionary = w.types[u.kind[k]]
				var d := damage(t.atk, tt.arm, tt.cls, maxi(int(w.combat.min_damage), tt.get("min_damage", 0)))
				hurt[k] += d
				hurt_by[k] = by
				w.events.append({"type": "hit", "by": by, "to": u.id[k], "damage": d, "ranged": true, "x": u.x[k], "y": u.y[k]})


## The foe of `owner` whose body covers (x, y), nearest its centre (lowest slot on ties), not an
## animal; -1 if none.
static func _stray(w, owner: int, x: int, y: int, slack: int) -> int:
	var u = w.units
	var sp = w.spatial
	var cx: int = x / SimMap.TILE
	var cy: int = y / SimMap.TILE
	var best := -1
	var best_d := 1 << 40
	for yy in range(maxi(cy - 1, 0), mini(cy + 2, sp.height)):
		for xx in range(maxi(cx - 1, 0), mini(cx + 2, sp.width)):
			var cell: int = yy * sp.width + xx
			for q in range(sp.start[cell], sp.start[cell + 1]):
				var k: int = sp.items[q]
				if not w.is_foe(u.owner[k], owner) or w.types[u.kind[k]].has("animal"):
					continue
				var r: int = u.radius[k] + slack
				var d := Fixed.dist2(x, y, u.x[k], u.y[k])
				if d <= r * r and (d < best_d or (d == best_d and k < best)):
					best_d = d
					best = k
	return best


## A stray's damage against unit j: the shooter type's attack (src >= 0) or a tower's (-1 - type).
static func _shot_damage(w, src: int, up: int, j: int) -> int:
	var atk: PackedInt32Array = w.types[src].atk if src >= 0 else w.btypes[-1 - src].atk
	var tt: Dictionary = w.types[w.units.kind[j]]
	var d := damage(atk, tt.arm, tt.cls, maxi(int(w.combat.min_damage), tt.get("min_damage", 0)))
	return uphill(w, d) if up < 0 else d


## High ground (milestone 15): 1 if unit i stands a level above its target (unit j or building
## b), -1 if below, 0 on the level or on a flat map. A ramp counts as its foot.
static func _height_step(w, i: int, j: int, b: int) -> int:
	var m = w.map
	if not m.has_heights:
		return 0
	var u = w.units
	var at: int = m.level_at(u.x[i], u.y[i])
	var to: int = m.level_at(u.x[j], u.y[j]) if j >= 0 else m.level[w.buildings.cy[b] * m.width + w.buildings.cx[b]]
	return signi(at - to)


## A shot up a hill: part of it falls short (rules.high_ground.uphill_damage_pct; at least 1).
static func uphill(w, d: int) -> int:
	return maxi(1, d * int(w.high.uphill_damage_pct) / 100)


## The edge-to-edge gap from unit i to unit j or building b, in milli-tiles.
static func _gap(w, i: int, j: int, b: int) -> int:
	var u = w.units
	if j >= 0:
		var d := Fixed.isqrt(Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j]))
		return d - u.radius[i] - u.radius[j]
	var bs = w.buildings
	var x0: int = bs.cx[b] * SimMap.TILE
	var y0: int = bs.cy[b] * SimMap.TILE
	var dx: int = maxi(maxi(x0 - u.x[i], 0), u.x[i] - (x0 + bs.sx[b] * SimMap.TILE))
	var dy: int = maxi(maxi(y0 - u.y[i], 0), u.y[i] - (y0 + bs.sy[b] * SimMap.TILE))
	return Fixed.isqrt(dx * dx + dy * dy) - u.radius[i]


## Close in: re-aim at a moving target on re-plan beats (straight at it when the way
## is clear, which is most fights; a flow field to its tile otherwise), or head for a
## building once.
static func _chase(w, i: int, j: int, b: int) -> void:
	var u = w.units
	if j >= 0:
		if u.moving[i] == 0 or (w.tick + u.id[i]) % w.REPLAN_EVERY == 0:
			if Flow.clear_line(w.map, u.x[i], u.y[i], u.x[j], u.y[j], w.lane(i)):
				w.order_direct(i, u.x[j], u.y[j])
			else:
				w.order_move(i, u.x[j], u.y[j], 0, 0)
	else:
		var key: int = w.building_field(w.buildings.id[b], false, w.lane(i))
		if u.moving[i] == 0 or u.fkey[i] != key:
			w.order_reach(i, Economy._building_rect(w, b), key)


## Melee units closing in on building b each get a place of their own round it, so a crowd
## spreads round the walls instead of piling up at the nearest one and shoving its own hitters
## out of reach. Places are a body's width apart in rings round the footprint: the first ring
## in reach (no corners), the outer ones to wait in for a gap. Nearest first, the nearest free
## place; the first ring weighs RING_COST less than the next; a unit keeps its place unless
## another is clearly better. Dealt afresh on the building's re-plan beat, or when someone new
## comes; in between, a unit shoved off its place walks back.
const RINGS := 3
const RING_COST := 20000         # walking right round the walls beats waiting a row back
const KEEP_PLACE := 1000

static func _surround(w, b: int, chasers: Array, hitters: Array) -> void:
	var u = w.units
	var bid: int = w.buildings.id[b]
	var rect: Rect2i = Economy._building_rect(w, b)
	var fresh: bool = (w.tick + bid) % w.REPLAN_EVERY == 0
	for i in chasers:
		if u.reach[i] != 2 or u.fkey[i] != w.building_field(bid, false, w.lane(i)):
			fresh = true
	if not fresh:
		var slack: int = w.SLOT_ARRIVE * w.SETTLE_FACTOR
		for i in chasers:
			if u.moving[i] == 0 and Fixed.dist2(u.x[i], u.y[i], u.tx[i], u.ty[i]) > slack * slack:
				w.order_beside(i, u.tx[i], u.ty[i], rect, u.fkey[i])
		return
	var rmin := 1 << 20
	var rmax := 0
	for i in chasers + hitters:
		rmin = mini(rmin, u.radius[i])
		rmax = maxi(rmax, u.radius[i])
	var reach: int = int(w.combat.melee_reach)
	var space: int = 2 * rmax + w.FORM_GAP
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x + 1
	var y1 := rect.end.y + 1
	var px := PackedInt32Array()
	var py := PackedInt32Array()
	var ring := PackedInt32Array()
	for k in RINGS:
		var o: int = rmin + reach / 2 + k * space
		var wd := x1 - x0 + 2 * o
		var ht := y1 - y0 + 2 * o
		var perim := 2 * (wd + ht)
		var count := maxi(perim / space, 4)
		for m in count:
			var along := m * perim / count + space / 2
			along %= perim
			var p: Vector2i
			if along < wd:
				p = Vector2i(x0 - o + along, y0 - o)
			elif along < wd + ht:
				p = Vector2i(x1 + o, y0 - o + along - wd)
			elif along < 2 * wd + ht:
				p = Vector2i(x1 + o - (along - wd - ht), y1 + o)
			else:
				p = Vector2i(x0 - o, y1 + o - (along - 2 * wd - ht))
			if k == 0:
				var dx := maxi(maxi(x0 - p.x, 0), p.x - x1)
				var dy := maxi(maxi(y0 - p.y, 0), p.y - y1)
				if Fixed.isqrt(dx * dx + dy * dy) - rmin > reach:
					continue   # round a corner: out of reach
			var taken := false
			for h in hitters:
				var rr: int = rmax + u.radius[h]
				if Fixed.dist2(p.x, p.y, u.x[h], u.y[h]) < rr * rr * 3 / 4:
					taken = true
					break
			if not taken:
				px.append(p.x)
				py.append(p.y)
				ring.append(k)
	var gaps := {}
	for i in chasers:
		gaps[i] = _gap(w, i, -1, b)
	var order: Array = chasers.duplicate()
	order.sort_custom(func(p, q): return gaps[p] < gaps[q] or (gaps[p] == gaps[q] and p < q))
	var claimed := PackedByteArray()
	claimed.resize(px.size())
	for i in order:
		var ln: int = w.lane(i)
		var key: int = w.building_field(bid, false, ln)
		var mine: bool = u.reach[i] == 2 and u.fkey[i] == key
		var best := -1
		var best_d := 1 << 62
		for k in px.size():
			if claimed[k] == 1 or not w.map.walkable(px[k], py[k], ln):
				continue
			var d := Fixed.isqrt(Fixed.dist2(u.x[i], u.y[i], px[k], py[k])) + ring[k] * RING_COST
			if mine and px[k] == u.tx[i] and py[k] == u.ty[i]:
				d -= KEEP_PLACE
			if d < best_d:
				best_d = d
				best = k
		if best < 0:
			_chase(w, i, -1, b)   # no place left: the old way, straight at the nearest wall
			continue
		claimed[best] = 1
		if not mine or px[best] != u.tx[i] or py[best] != u.ty[i] \
				or (u.moving[i] == 0 and Fixed.dist2(u.x[i], u.y[i], px[best], py[best]) > w.SLOT_ARRIVE * w.SLOT_ARRIVE * 16):
			w.order_beside(i, px[best], py[best], rect, key)


## The target is gone (or out of reach for good): attack-movers carry on, defensive
## units walk back, others stop.
static func _lost(w, i: int) -> void:
	var u = w.units
	u.foe[i] = 0
	if u.stance[i] == AUTO and u.posture[i] == DEFENSIVE:
		_go_back(w, i)
	elif u.stance[i] == ATTACK_MOVE:
		w.resume_attack_move(i)
	else:
		u.stance[i] = NONE
		u.moving[i] = 0


## The best enemy unit within `sight` (centre to centre): nearest, counting each of
## its current attackers as `spread` further away, lowest id on ties (skipping those the shots
## in `inbound` will kill, if given); then, for attack-movers, the nearest enemy building.
## Returns an id or 0.
static func _nearest_foe(w, i: int, sight: int, buildings_too: bool, engaged: PackedInt32Array, spread := SPREAD, inbound := PackedInt32Array(),
		near := 0, units_too := true) -> int:
	var u = w.units
	var sp = w.spatial
	var me: int = u.owner[i]
	if me == w.gaia:
		return 0   # animals don't go looking for a fight
	var best := 0
	var best_d := 1 << 40
	var r := sight / SimMap.TILE + 1
	var cx: int = u.x[i] / SimMap.TILE
	var cy: int = u.y[i] / SimMap.TILE
	for yy in (range(maxi(cy - r, 0), mini(cy + r + 1, sp.height)) if units_too else []):
		for xx in range(maxi(cx - r, 0), mini(cx + r + 1, sp.width)):
			var cell: int = yy * sp.width + xx
			for k in range(sp.start[cell], sp.start[cell + 1]):
				var j: int = sp.items[k]
				if not w.is_foe(u.owner[j], me) or w.types[u.kind[j]].has("animal"):
					continue   # a rival's sheep is stolen by walking up to it, not killed (Dominic)
				if not inbound.is_empty() and inbound[j] >= u.hp[j]:
					continue   # as good as dead already: shots on their way will kill it
				var d2 := Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])
				if d2 > sight * sight or d2 < near * near or not Fog.visible(w, me, u.x[j], u.y[j]):
					continue   # only what its side can see: no going for foes in the fog (Dominic); none under an engine's nose
				var d := Fixed.isqrt(d2) + engaged[j] * spread
				if d < best_d or (d == best_d and u.id[j] < best):
					best_d = d
					best = u.id[j]
	if best != 0 or not buildings_too:
		return best
	best_d = sight * sight + 1
	var bs = w.buildings
	for b in bs.count():
		if not w.is_enemy(bs.owner[b], me) or not Fog.sees_area(w, me, bs.cx[b], bs.cy[b], bs.sx[b], bs.sy[b]):
			continue
		if near > 0 and _gap(w, i, -1, b) < near - u.radius[i]:
			continue
		var mx: int = bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2
		var my: int = bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2
		var d := Fixed.dist2(u.x[i], u.y[i], mx, my)
		if d < best_d:
			best_d = d
			best = bs.id[b]
	return best


## Land this tick's hits together, then remove the dead (units by descending slot,
## so slots stay valid while removing). Units hit while idle (or walking back) turn on
## the attacker, unless passive.
static func _apply(w, hurt: PackedInt32Array, hurt_by: PackedInt32Array, bhurt: PackedInt32Array) -> void:
	var u = w.units
	for j in hurt.size():
		if hurt[j] == 0:
			continue
		u.hp[j] -= hurt[j]
		var t: Dictionary = w.types[u.kind[j]]
		if t.has("animal"):
			Animals.hurt(w, j, hurt_by[j])   # a deer bolts, a sheep stands for the knife
		if u.foe[j] == 0 and (u.stance[j] == NONE or u.stance[j] == RETURN) and u.task[j] == Economy.NONE and not t.worker \
				and not t.get("harmless", false) and not t.get("healer", false) and not t.get("buildings_only", false) and u.posture[j] != PASSIVE:
			_engage(w, j, hurt_by[j])
	for j in range(hurt.size() - 1, -1, -1):
		if u.hp[j] <= 0:
			w.events.append({"type": "die", "id": u.id[j], "x": u.x[j], "y": u.y[j], "owner": u.owner[j], "kind": u.kind[j], "building": false})
			if w.types[u.kind[j]].has("animal"):
				Animals.died(w, j)   # a carcass to gather, and the hunters gather it (food, not a unit lost)
			else:
				w.lost[u.owner[j]] += 1
			u.remove_at(j)
	var bs = w.buildings
	for b in range(bhurt.size() - 1, -1, -1):
		if bhurt[b] == 0:
			continue
		bs.hp[b] -= bhurt[b]
		if bs.hp[b] <= 0:
			w.events.append({"type": "die", "id": bs.id[b], "x": bs.cx[b] * SimMap.TILE + bs.sx[b] * SimMap.TILE / 2, "y": bs.cy[b] * SimMap.TILE + bs.sy[b] * SimMap.TILE / 2,
				"owner": bs.owner[b], "kind": bs.kind[b], "building": true})
			Economy.clear_farm(w, b)
			Economy.Pens.gone(w, b)   # a pen's animals spill out
			Garrison.spill(w, b)      # and so do the people sheltering inside
			w.map.occupy(bs.footprint(b, w.map.width), 0)
			bs.remove_at(b)
