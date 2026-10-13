extends RefCounted
## Race abilities (milestone 14): one signature ability per race, a kind from a small shared
## vocabulary with its numbers in data (creatures.json `ability`, read through src/identity.gd),
## so any creature, culture or mod can use it. Static functions over the World `w`; integers only,
## ids in order, no Nodes. Each kind has a counter.
##
## The ability: {kind, name, desc, tag (who can use it: a unit tag, "and"/"not" like research
## effects), range (milli-tiles from the user to the spot), cooldown (ticks, per user), ...}.
## The ABILITY command {ids, x, y}: the first of those units (in id order) that has it, is ready
## and is within range of the spot uses it there; the others wait. Cooldowns are per unit id
## (w.ability_ready: id -> the tick it may act again).
##
## Kinds:
##   web: a slowing patch at the spot (radius, lasts ticks, slow_pct: enemies in it move at that
##        share of their speed) that wears off. Counter: shooters (they shoot from outside it) and
##        going round. (Land-shaping only as race abilities, and it wears off: m14.)
##
## Slowing: a unit in an enemy web, or hit by a sticky shot (research `slow_on_hit`: ticks; moves
## at SLOW_PCT), moves slower; w.slow_now (id -> pct) is worked out each tick before moves.

const Identity := preload("res://src/identity.gd")
const Fixed := preload("res://src/sim/fixed.gd")

const SLOW_PCT := 60   # a sticky hit (Sticky Silk): the target moves at 60% for its ticks
const KINDS := ["web"]
const WEB := 6         # w.webs, flat: [owner, x, y, radius, ends (tick), slow_pct] each


static func setup(w) -> void:
	for p in w.races.size():
		var ab: Dictionary = w.ident[p].ability
		assert(ab.is_empty() or ab.kind in KINDS, "Unknown ability kind %s" % ab.get("kind", ""))


## This player's ability ({} if none).
static func of(w, player: int) -> Dictionary:
	return w.ident[player].ability


## Can units of type k use their race's ability?
static func can_use(w, k: int) -> bool:
	var t: Dictionary = w.types[k]
	if t.has("animal"):
		return false
	var ab := of(w, t.player)
	return not ab.is_empty() and Identity.reaches(ab, t.eval.tags)


## Ticks until unit i may use its ability again (0: ready).
static func wait(w, i: int) -> int:
	return maxi(0, int(w.ability_ready.get(w.units.id[i], 0)) - w.tick)


static func cmd_ability(w, player: int, a: Dictionary) -> void:
	var ab := of(w, player)
	if ab.is_empty():
		return
	var ids: Array = a.ids.duplicate()
	ids.sort()
	var u = w.units
	for uid in ids:
		var i: int = u.index_of(uid)
		if i < 0 or u.owner[i] != player or not can_use(w, u.kind[i]) or wait(w, i) > 0:
			continue
		var dx: int = int(a.x) - u.x[i]
		var dy: int = int(a.y) - u.y[i]
		if dx * dx + dy * dy > int(ab.range) * int(ab.range):
			continue
		match ab.kind:
			"web":
				w.webs.append_array([player, int(a.x), int(a.y), int(ab.radius), w.tick + int(ab.lasts), int(ab.slow_pct)])
		w.ability_ready[uid] = w.tick + int(ab.cooldown)
		w.events.append({"type": "ability", "kind": ab.kind, "id": uid, "player": player, "x": int(a.x), "y": int(a.y)})
		return


## One tick: webs wear off; who is slowed this tick (webs, then sticky hits); the dead's cooldowns go.
static func tick(w) -> void:
	var webs: PackedInt32Array = w.webs
	var kept := PackedInt32Array()
	for n in range(0, webs.size(), WEB):
		if webs[n + 4] > w.tick:
			kept.append_array(webs.slice(n, n + WEB))
	w.webs = kept
	var slow := {}
	var u = w.units
	if not kept.is_empty():
		for i in u.count():
			for n in range(0, kept.size(), WEB):
				if not w.is_foe(kept[n], u.owner[i]):
					continue
				var dx: int = u.x[i] - kept[n + 1]
				var dy: int = u.y[i] - kept[n + 2]
				var r: int = kept[n + 3] + u.radius[i]
				if dx * dx + dy * dy <= r * r:
					slow[u.id[i]] = mini(int(slow.get(u.id[i], 100)), kept[n + 5])
	var gone := []
	for uid in w.slowed:
		if int(w.slowed[uid]) <= w.tick:
			gone.append(uid)
		else:
			slow[uid] = mini(int(slow.get(uid, 100)), SLOW_PCT)
	for uid in gone:
		w.slowed.erase(uid)
	w.slow_now = slow
	if w.tick % 200 == 0:   # forget the cooldowns of the dead now and then
		for uid in w.ability_ready.keys():
			if u.index_of(uid) < 0 or int(w.ability_ready[uid]) <= w.tick:
				w.ability_ready.erase(uid)


## A sticky hit: unit j slowed for `ticks` from now (the longer of two).
static func stick(w, j: int, ticks: int) -> void:
	var uid: int = w.units.id[j]
	w.slowed[uid] = maxi(int(w.slowed.get(uid, 0)), w.tick + ticks)


## Into the state hash: webs, cooldowns and sticky hits, by id.
static func hash_into(w, h: int) -> int:
	for v in w.webs:
		h = Fixed.mix(h, v)
	for d in [w.ability_ready, w.slowed]:
		var ids: Array = d.keys()
		ids.sort()
		for uid in ids:
			h = Fixed.mix(Fixed.mix(h, uid), int(d[uid]))
	return h
