extends RefCounted
## Healers (the Town Center's healer line): each heals the most wounded unit of its own team
## nearby, a few hit points at a time, and walks up to it when it has nothing else to do.
## It never fights: combat.gd skips healers, and they spawn with the passive stance.
## Static functions over the World `w`, like combat.gd. Integers only, slot order.
##
## Data (rules combat): heal_amount hp per heal (times the unit's heal stat), heal_reload
## ticks between heals (a healer stands still that long before each one: none on the move), heal_range (edge to edge, milli-tiles) to heal from, heal_sight
## (centre to centre) to look for the wounded in. Not itself, not animals, not buildings.

const Fixed := preload("res://src/sim/fixed.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Flow := preload("res://src/sim/flow.gd")
const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")


## One tick of healing. Runs just before combat (w.spatial is fresh; combat then ticks the
## cooldowns down, so a heal comes every heal_reload ticks like a blow every reload).
static func tick(w) -> void:
	var u = w.units
	var c: Dictionary = w.combat
	var n: int = u.count()
	var heals := PackedInt32Array()
	heals.resize(n)
	var tending := PackedInt32Array()   # healers already on each unit (by slot): picks spread out
	tending.resize(n)
	var any := false
	for i in n:
		if u.patient[i] != 0:
			var j: int = u.index_of(u.patient[i])
			if j >= 0:
				tending[j] += 1
		any = any or w.types[u.kind[i]].healer
	if not any:
		return
	for i in n:
		var t: Dictionary = w.types[u.kind[i]]
		if not t.healer:
			continue
		var j: int = u.index_of(u.patient[i]) if u.patient[i] != 0 else -1
		if u.patient[i] != 0 and (j < 0 or not _wounded(w, i, j)):
			if j >= 0:
				tending[j] -= 1
			_done(w, i)
			j = -1
		# Look for someone to heal on its own beat: idle, or on an attack-move (a healer marching
		# with the army stops for the wounded on the way), never while walking where it was sent.
		var free: bool = u.moving[i] == 0 or u.stance[i] == Combat.AUTO or u.stance[i] == Combat.ATTACK_MOVE
		if j < 0 and (w.tick + u.id[i]) % int(c.acquire_every) == 0 and u.task[i] == Economy.NONE and free:
			var reach: int = int(c.heal_range) + u.radius[i] + SimMap.TILE / 2
			j = _most_wounded(w, i, reach if u.posture[i] == Combat.STAND else int(c.heal_sight), tending)
			if j >= 0:
				u.patient[i] = u.id[j]
				tending[j] += 1
		if j < 0:
			continue
		var gap: int = Fixed.isqrt(Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])) - u.radius[i] - u.radius[j]
		if gap <= int(c.heal_range):
			if u.stance[i] == Combat.AUTO or u.stance[i] == Combat.ATTACK_MOVE:
				u.moving[i] = 0
			if u.stance[i] == Combat.AUTO:
				u.stance[i] = Combat.NONE
			if u.moving[i] != 0:
				# Walking where it was sent: no healing on the move (Dominic: they seemed to walk
				# and heal); it has to stand a whole heal_reload first.
				u.cooldown[i] = maxi(u.cooldown[i], int(c.heal_reload))
			elif u.cooldown[i] == 0:
				u.cooldown[i] = int(c.heal_reload)
				var amount: int = int(c.heal_amount) * int(t.eval.heal) * (100 + int(t.heal_pct)) / 100   # (Bog Poultice: Tech.retype)
				heals[j] += amount
				w.events.append({"type": "heal", "by": u.id[i], "to": u.id[j], "amount": amount})
		elif u.posture[i] == Combat.STAND or gap > int(c.heal_sight) + 2 * SimMap.TILE:
			tending[j] -= 1
			_done(w, i)   # stand ground heals only who it can reach; or the patient got away
		elif free:
			# Walk up to the patient (re-aimed on re-plan beats, like a chase); arriving, it
			# stops and tends for a whole heal_reload before the first heal lands.
			u.cooldown[i] = maxi(u.cooldown[i], int(c.heal_reload))
			if u.moving[i] == 0 or (w.tick + u.id[i]) % w.REPLAN_EVERY == 0:
				if Flow.clear_line(w.map, u.x[i], u.y[i], u.x[j], u.y[j], w.lane(i)):
					w.order_direct(i, u.x[j], u.y[j])
				else:
					w.order_move(i, u.x[j], u.y[j], 0, 0)
				if u.stance[i] != Combat.ATTACK_MOVE:
					u.stance[i] = Combat.AUTO
	# Heals land together, capped at full health, so slot order never decides anything.
	for j in n:
		if heals[j] > 0:
			u.hp[j] = mini(u.hp[j] + heals[j], int(w.types[u.kind[j]].hp))


## Can healer i heal unit j: someone else on its team, not an animal nor a machine (rules heal_not:
## a timber ram is mended by carpenters, not herbs), and hurt?
static func _wounded(w, i: int, j: int) -> bool:
	var u = w.units
	var tj: Dictionary = w.types[u.kind[j]]
	return j != i and not tj.has("animal") and not tj.get("no_heal", false) and u.owner[j] != w.gaia and not w.is_enemy(u.owner[i], u.owner[j]) \
			and u.hp[j] < int(tj.hp)


## The most wounded friend within `sight` (centre to centre): the most hit points missing,
## less what the healers already on it will give, then the nearest, then the lowest id.
static func _most_wounded(w, i: int, sight: int, tending: PackedInt32Array) -> int:
	var u = w.units
	var sp = w.spatial
	var per: int = int(w.combat.heal_amount)
	var best := -1
	var best_need := 0
	var best_d := 0
	var r := sight / SimMap.TILE + 1
	var cx: int = u.x[i] / SimMap.TILE
	var cy: int = u.y[i] / SimMap.TILE
	for yy in range(maxi(cy - r, 0), mini(cy + r + 1, sp.height)):
		for xx in range(maxi(cx - r, 0), mini(cx + r + 1, sp.width)):
			var cell: int = yy * sp.width + xx
			for k in range(sp.start[cell], sp.end[cell]):
				var j: int = sp.items[k]
				if not _wounded(w, i, j):
					continue
				var d := Fixed.dist2(u.x[i], u.y[i], u.x[j], u.y[j])
				if d > sight * sight:
					continue
				var need: int = int(w.types[u.kind[j]].hp) - u.hp[j] - tending[j] * per
				if best < 0 or need > best_need or (need == best_need and (d < best_d or (d == best_d and u.id[j] < u.id[best]))):
					best = j
					best_need = need
					best_d = d
	return best


## Done with a patient: stop walking to it if that's what it was doing, or march on (attack-move).
static func _done(w, i: int) -> void:
	var u = w.units
	u.patient[i] = 0
	if u.stance[i] == Combat.AUTO:
		u.stance[i] = Combat.NONE
		u.moving[i] = 0
	elif u.stance[i] == Combat.ATTACK_MOVE:
		w.resume_attack_move(i)
