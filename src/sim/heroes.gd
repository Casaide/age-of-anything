extends RefCounted
## Heroes in the sim (milestone 14 step 9): one per player, trained at the Town Center from its line's
## age (rules roster role "hero", src/heroes.gd), never two at once; an aura on its friends; healing
## slowly while hurt; and when it falls, revived at the Town Center (the same TRAIN) after
## rules.revive_ticks, for rules.revive_pct of its cost. Static functions over the World `w`; integers
## only, players and units in order, no Nodes.
##
## State (hashed, World.state_hash): w.hero_id per player (the living hero's unit id, sheltering in a
## building too; 0 with none) and w.hero_fell (the tick + 1 it last fell, 0 if it never has).
## The aura (data/heroes.json signature `aura.effects`, research effects: attack, armour.melee,
## armour.pierce) is worked out each tick before the fighting (w.aura_now, derived): friends of the
## hero's team within rules.aura_tiles, not the hero itself, not animals. Attack adds to the damage
## a unit deals with its own blows and shots; armour takes off damage from blows, shots and tower
## arrows (splash and pass-through keep the plain formula). A Regicide rule (milestone 18) can read
## w.hero_id / w.hero_fell later.

const Identity := preload("res://src/identity.gd")
const Fixed := preload("res://src/sim/fixed.gd")

const DATA := "res://data/heroes.json"
const REC_ID := 0     # a sheltering unit's record: its id first (garrison.gd REC_ID; not preloaded: it preloads the economy)
const AURA := 3       # w.aura_now per unit slot: [attack, melee armour, pierce armour]
const STATS := ["attack", "armour.melee", "armour.pierce"]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		assert(_data != null, "Bad or missing %s" % DATA)
	return _data


static func setup(w) -> void:
	var r: Dictionary = data().rules
	w.hero_cfg = {"aura": int(r.aura_tiles) * 1000, "regen": int(r.regen_every), "revive": int(r.revive_ticks), "revive_pct": int(r.revive_pct)}
	w.hero_id.resize(w.races.size())
	w.hero_fell.resize(w.races.size())
	for t in w.types:
		if not t.get("hero", false):
			continue
		var fx: Array = data().hero_signatures[t.recipe.hero].aura.effects
		for e in fx:
			assert(e.stat in STATS and e.has("add"), "A hero's aura is attack or armour, added: %s" % e)
		t.aura = fx


## The player's hero type, or -1.
static func type_of(w, player: int) -> int:
	return w.type_of(player, "hero")


## Why the player can't train (or revive) its hero now, or "".
static func why_not(w, player: int) -> String:
	var k := type_of(w, player)
	if k < 0:
		return "no hero"
	if w.hero_id[player] != 0:
		return "the hero is out already"
	for b in w.buildings.count():
		if w.buildings.owner[b] == player and k in w.buildings.queue[b]:
			return "the hero is on the way"
	var left := revive_left(w, player)
	if left > 0:
		return "revives in %d s" % ((left + 19) / 20)
	return ""


## Ticks until a fallen hero may be revived (0: now, or it never fell).
static func revive_left(w, player: int) -> int:
	if w.hero_fell[player] == 0:
		return 0
	return maxi(0, w.hero_fell[player] - 1 + int(w.hero_cfg.revive) - w.tick)


## What training type k costs this player: a hero that has fallen before costs revive_pct of its price.
static func cost(w, player: int, k: int) -> PackedInt32Array:
	var c: PackedInt32Array = w.types[k].cost
	if not w.types[k].get("hero", false) or w.hero_fell[player] == 0:
		return c
	var out := PackedInt32Array(c)
	for r in out.size():
		out[r] = out[r] * int(w.hero_cfg.revive_pct) / 100
	return out


## A hero came out of the Town Center (Economy.train).
static func spawned(w, i: int) -> void:
	var p: int = w.units.owner[i]
	w.hero_id[p] = w.units.id[i]
	w.events.append({"type": "hero_up", "id": w.units.id[i], "player": p, "revived": w.hero_fell[p] != 0, "x": w.units.x[i], "y": w.units.y[i]})


## Is unit id `uid` sheltering in one of the player's buildings?
static func _inside(w, player: int, uid: int) -> bool:
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == player:
			for rec in bs.inside[b]:
				if rec[REC_ID] == uid:
					return true
	return false


## One tick (after the fighting): a hero gone from the map and from every shelter has fallen; a hurt
## one heals a hit point every regen ticks.
static func tick(w) -> void:
	var u = w.units
	for p in w.races.size():
		var uid: int = w.hero_id[p]
		if uid == 0:
			continue
		var i: int = u.index_of(uid)
		if i < 0:
			if not _inside(w, p, uid):
				w.hero_id[p] = 0
				w.hero_fell[p] = w.tick + 1
				w.events.append({"type": "hero_fell", "id": uid, "player": p})
			continue
		if w.tick % int(w.hero_cfg.regen) == 0 and u.hp[i] < int(w.types[u.kind[i]].hp):
			u.hp[i] += 1


## Each unit's aura this tick (per slot: AURA ints), from every living hero on the map; empty if none.
static func auras(w) -> PackedInt32Array:
	var u = w.units
	var out := PackedInt32Array()
	var r2: int = int(w.hero_cfg.aura) * int(w.hero_cfg.aura)
	for p in w.races.size():
		var h: int = u.index_of(w.hero_id[p]) if w.hero_id[p] != 0 else -1
		if h < 0:
			continue
		if out.is_empty():
			out.resize(u.count() * AURA)
		var fx: Array = w.types[u.kind[h]].aura
		var team: int = w.teams[p]
		var hx: int = u.x[h]
		var hy: int = u.y[h]
		for j in u.count():
			if j == h or u.owner[j] == w.gaia or w.teams[u.owner[j]] != team or Fixed.dist2(hx, hy, u.x[j], u.y[j]) > r2:
				continue
			var tags: Array = w.types[u.kind[j]].eval.tags
			for e in fx:
				if Identity.reaches(e, tags):
					out[j * AURA + STATS.find(e.stat)] += int(e.add)
	w.aura_now = out
	return out


## Damage d from attacker slot i (-1: a building) to target slot j (-1: a building), of damage type
## `kind` ("melee" or "pierce"), with the auras on both; never under `floor`.
static func boost(aura: PackedInt32Array, i: int, j: int, kind: String, d: int, floor: int) -> int:
	if aura.is_empty():
		return d
	var add: int = aura[i * AURA] if i >= 0 else 0
	var arm: int = aura[j * AURA + (1 if kind == "melee" else 2)] if j >= 0 else 0
	if add == arm:
		return d
	return maxi(floor, d + add - arm)


static func hash_into(w, h: int) -> int:
	for p in w.races.size():
		h = Fixed.mix(Fixed.mix(h, w.hero_id[p]), w.hero_fell[p])
	return h
