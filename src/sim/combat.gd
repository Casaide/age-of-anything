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

const Fixed := preload("res://src/sim/fixed.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Economy := preload("res://src/sim/economy.gd")
const Flow := preload("res://src/sim/flow.gd")

enum { NONE, ORDERED, AUTO, ATTACK_MOVE }   # units.stance

const BASE := ["melee", "pierce", "building"]   # the first classes, always at these indexes
## Spreading out: a foe already fought by others looks this much further away per
## attacker (milli-tiles), so a 10-vs-10 clash becomes ten duels, not a pile-on.
const SPREAD := 1500
## A unit whose foe has more than this many attackers looks for a free foe close by.
const CROWDED := 2


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


static func cmd_attack(w, player: int, a: Dictionary) -> void:
	if not _is_target(w, a.target, player):
		return
	for uid in a.ids:
		var i: int = w.units.index_of(uid)
		if i >= 0 and w.units.owner[i] == player:
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
	var arrive: int = w.ARRIVE_STEP * Fixed.isqrt(slots.size()) - w.ARRIVE_BASE
	for i in slots:
		Economy.clear_task(w, i)
		w.units.foe[i] = 0
		w.units.stance[i] = ATTACK_MOVE
		w.units.amx[i] = a.x
		w.units.amy[i] = a.y
		w.order_move(i, a.x, a.y, arrive, w.next_group)
	w.next_group += 1


## An enemy unit or building of `player`?
static func _is_target(w, id: int, player: int) -> bool:
	var i: int = w.units.index_of(id)
	if i >= 0:
		return w.is_enemy(w.units.owner[i], player)
	var b: int = w.buildings.index_of(id)
	return b >= 0 and w.is_enemy(w.buildings.owner[b], player)


# ------------------------------------------------------------------ tick

## One tick of fighting. Runs after worker jobs and before movement; w.spatial must
## have been built from the current positions.
static func tick(w) -> void:
	var u = w.units
	var bs = w.buildings
	var c: Dictionary = w.combat
	var n: int = u.count()
	var hurt := PackedInt32Array()
	hurt.resize(n)
	var hurt_by := PackedInt32Array()
	hurt_by.resize(n)
	var bhurt := PackedInt32Array()
	bhurt.resize(bs.count())
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
	for i in n:
		var t: Dictionary = w.types[u.kind[i]]
		var stance: int = u.stance[i]
		# Look for a fight: idle soldiers (not workers) and attack-movers, on their own beat.
		# Units fighting on their own (not an explicit target) also leave a crowded foe
		# for a free one nearby, so winners go and help where the fight is still on.
		if (w.tick + u.id[i]) % int(c.acquire_every) == 0:
			var idle: bool = stance == NONE and u.moving[i] == 0 and u.task[i] == Economy.NONE and not t.worker
			var free: bool = stance == AUTO or stance == ATTACK_MOVE
			var crowded := false
			if u.foe[i] != 0 and free:
				var cur: int = u.index_of(u.foe[i])
				crowded = cur >= 0 and engaged[cur] > CROWDED
			if (u.foe[i] == 0 and (idle or stance == ATTACK_MOVE)) or crowded:
				var f := _nearest_foe(w, i, int(c.sight), stance == ATTACK_MOVE, engaged)
				if f != 0 and f != u.foe[i]:
					var old: int = u.index_of(u.foe[i]) if u.foe[i] != 0 else -1
					if old >= 0:
						engaged[old] -= 1
					u.foe[i] = f
					var nj: int = u.index_of(f)
					if nj >= 0:
						engaged[nj] += 1
					if idle:
						u.stance[i] = AUTO
		if u.foe[i] == 0:
			continue
		var j: int = u.index_of(u.foe[i])
		var b: int = -1 if j >= 0 else bs.index_of(u.foe[i])
		if j < 0 and b < 0:
			_lost(w, i)
			continue
		var gap := _gap(w, i, j, b)
		if gap <= t.reach and _kite(w, i, j, t, gap):
			continue
		if gap <= t.reach:
			u.moving[i] = 0
			if u.cooldown[i] == 0:
				u.cooldown[i] = t.reload
				if j >= 0:
					var tt: Dictionary = w.types[u.kind[j]]
					var d := damage(t.atk, tt.arm, tt.cls, int(c.min_damage))
					hurt[j] += d
					hurt_by[j] = u.id[i]
					w.events.append({"type": "hit", "by": u.id[i], "to": u.id[j], "damage": d, "ranged": t.ranged})
				else:
					var bt: Dictionary = w.btypes[bs.kind[b]]
					var d := damage(t.atk, bt.arm, bt.cls, int(c.min_damage))
					bhurt[b] += d
					w.events.append({"type": "hit", "by": u.id[i], "to": bs.id[b], "damage": d, "ranged": t.ranged})
		elif u.stance[i] == AUTO and gap > int(c.sight) + 2 * SimMap.TILE:
			_lost(w, i)   # it got away
		else:
			_chase(w, i, j, b)
	_towers(w, hurt, hurt_by)
	_apply(w, hurt, hurt_by, bhurt)


## Ranged units keep their distance (rules.combat.kite_gap, milli-tiles; 0 = off): having just
## fired, with a melee foe closer than the gap, step straight back (onto walkable ground) and
## shoot again from there. Returns true while stepping back.
static func _kite(w, i: int, j: int, t: Dictionary, gap: int) -> bool:
	var kite: int = int(w.combat.get("kite_gap", 0))
	if kite <= 0 or not t.ranged or j < 0 or w.types[w.units.kind[j]].ranged or gap >= kite:
		return false
	var u = w.units
	if u.moving[i] != 0:
		# Already stepping back (heading somewhere farther from the foe than here): carry on.
		return Fixed.dist2(u.tx[i], u.ty[i], u.x[j], u.y[j]) > Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])
	if u.cooldown[i] == 0:
		return false   # shoot first
	var dx: int = u.x[i] - u.x[j]
	var dy: int = u.y[i] - u.y[j]
	var len: int = maxi(1, Fixed.isqrt(dx * dx + dy * dy))
	var step: int = int(w.combat.get("kite_step", 2 * SimMap.TILE))
	var tx: int = clampi(u.x[i] + dx * step / len, 0, w.map.width * SimMap.TILE - 1)
	var ty: int = clampi(u.y[i] + dy * step / len, 0, w.map.height * SimMap.TILE - 1)
	if not w.map.walkable(tx, ty, u.mclass[i]):
		return false   # cornered: stand and shoot
	w.order_direct(i, tx, ty)
	return true


## Finished buildings that attack (watchtowers) shoot the nearest enemy unit in reach.
static func _towers(w, hurt: PackedInt32Array, hurt_by: PackedInt32Array) -> void:
	var bs = w.buildings
	var u = w.units
	var c: Dictionary = w.combat
	for b in bs.count():
		var bt: Dictionary = w.btypes[bs.kind[b]]
		if bt.attack.is_empty() or bs.done[b] == 0:
			continue
		if bs.cooldown[b] > 0:
			bs.cooldown[b] -= 1
			continue
		var s: int = bs.size[b] * SimMap.TILE
		var mx: int = bs.cx[b] * SimMap.TILE + s / 2
		var my: int = bs.cy[b] * SimMap.TILE + s / 2
		var best := -1
		var best_d: int = (bt.reach + s / 2) * (bt.reach + s / 2) + 1
		for j in u.count():
			if not w.is_enemy(u.owner[j], bs.owner[b]):
				continue
			var d := Fixed.dist2(mx, my, u.x[j], u.y[j])
			if d < best_d:
				best_d = d
				best = j
		if best < 0:
			continue
		var tt: Dictionary = w.types[u.kind[best]]
		var dmg := damage(bt.atk, tt.arm, tt.cls, int(c.min_damage))
		hurt[best] += dmg
		hurt_by[best] = bs.id[b]
		bs.cooldown[b] = bt.reload
		w.events.append({"type": "hit", "by": bs.id[b], "to": u.id[best], "damage": dmg, "ranged": true})


## The edge-to-edge gap from unit i to unit j or building b, in milli-tiles.
static func _gap(w, i: int, j: int, b: int) -> int:
	var u = w.units
	if j >= 0:
		var d := Fixed.isqrt(Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j]))
		return d - u.radius[i] - u.radius[j]
	var bs = w.buildings
	var s: int = bs.size[b] * SimMap.TILE
	var x0: int = bs.cx[b] * SimMap.TILE
	var y0: int = bs.cy[b] * SimMap.TILE
	var dx: int = maxi(maxi(x0 - u.x[i], 0), u.x[i] - (x0 + s))
	var dy: int = maxi(maxi(y0 - u.y[i], 0), u.y[i] - (y0 + s))
	return Fixed.isqrt(dx * dx + dy * dy) - u.radius[i]


## Close in: re-aim at a moving target on re-plan beats (straight at it when the way
## is clear, which is most fights; a flow field to its tile otherwise), or head for a
## building once.
static func _chase(w, i: int, j: int, b: int) -> void:
	var u = w.units
	if j >= 0:
		if u.moving[i] == 0 or (w.tick + u.id[i]) % w.REPLAN_EVERY == 0:
			if Flow.clear_line(w.map, u.x[i], u.y[i], u.x[j], u.y[j], u.mclass[i]):
				w.order_direct(i, u.x[j], u.y[j])
			else:
				w.order_move(i, u.x[j], u.y[j], 0, 0)
	else:
		var key: int = w.building_field(w.buildings.id[b], false, u.mclass[i])
		if u.moving[i] == 0 or u.fkey[i] != key:
			w.order_reach(i, Economy._building_rect(w, b), key)


## The target is gone (or out of reach for good): attack-movers carry on, others stop.
static func _lost(w, i: int) -> void:
	var u = w.units
	u.foe[i] = 0
	if u.stance[i] == ATTACK_MOVE:
		w.order_move(i, u.amx[i], u.amy[i], w.ARRIVE_STEP - w.ARRIVE_BASE, 0)
	else:
		u.stance[i] = NONE
		u.moving[i] = 0


## The best enemy unit within `sight` (centre to centre): nearest, counting each of
## its current attackers as SPREAD further away, lowest id on ties; then, for
## attack-movers, the nearest enemy building. Returns an id or 0.
static func _nearest_foe(w, i: int, sight: int, buildings_too: bool, engaged: PackedInt32Array) -> int:
	var u = w.units
	var sp = w.spatial
	var me: int = u.owner[i]
	var best := 0
	var best_d := 1 << 40
	var r := sight / SimMap.TILE + 1
	var cx: int = u.x[i] / SimMap.TILE
	var cy: int = u.y[i] / SimMap.TILE
	for yy in range(maxi(cy - r, 0), mini(cy + r + 1, sp.height)):
		for xx in range(maxi(cx - r, 0), mini(cx + r + 1, sp.width)):
			var cell: int = yy * sp.width + xx
			for k in range(sp.start[cell], sp.start[cell + 1]):
				var j: int = sp.items[k]
				if not w.is_enemy(u.owner[j], me):
					continue
				var d2 := Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])
				if d2 > sight * sight:
					continue
				var d := Fixed.isqrt(d2) + engaged[j] * SPREAD
				if d < best_d or (d == best_d and u.id[j] < best):
					best_d = d
					best = u.id[j]
	if best != 0 or not buildings_too:
		return best
	best_d = sight * sight + 1
	var bs = w.buildings
	for b in bs.count():
		if not w.is_enemy(bs.owner[b], me):
			continue
		var s: int = bs.size[b] * SimMap.TILE
		var mx: int = bs.cx[b] * SimMap.TILE + s / 2
		var my: int = bs.cy[b] * SimMap.TILE + s / 2
		var d := Fixed.dist2(u.x[i], u.y[i], mx, my)
		if d < best_d:
			best_d = d
			best = bs.id[b]
	return best


## Land this tick's hits together, then remove the dead (units by descending slot,
## so slots stay valid while removing). Units hit while idle turn on the attacker.
static func _apply(w, hurt: PackedInt32Array, hurt_by: PackedInt32Array, bhurt: PackedInt32Array) -> void:
	var u = w.units
	for j in hurt.size():
		if hurt[j] == 0:
			continue
		u.hp[j] -= hurt[j]
		var t: Dictionary = w.types[u.kind[j]]
		if u.foe[j] == 0 and u.stance[j] == NONE and u.task[j] == Economy.NONE and not t.worker:
			u.foe[j] = hurt_by[j]
			u.stance[j] = AUTO
	for j in range(hurt.size() - 1, -1, -1):
		if u.hp[j] <= 0:
			w.events.append({"type": "die", "id": u.id[j], "x": u.x[j], "y": u.y[j], "owner": u.owner[j], "kind": u.kind[j], "building": false})
			w.lost[u.owner[j]] += 1
			u.remove_at(j)
	var bs = w.buildings
	for b in range(bhurt.size() - 1, -1, -1):
		if bhurt[b] == 0:
			continue
		bs.hp[b] -= bhurt[b]
		if bs.hp[b] <= 0:
			var s: int = bs.size[b] * SimMap.TILE
			w.events.append({"type": "die", "id": bs.id[b], "x": bs.cx[b] * SimMap.TILE + s / 2, "y": bs.cy[b] * SimMap.TILE + s / 2,
				"owner": bs.owner[b], "kind": bs.kind[b], "building": true})
			Economy.clear_farm(w, b)
			w.map.occupy(bs.footprint(b, w.map.width), 0)
			bs.remove_at(b)
