extends RefCounted
## Ages and research, from data/tech.json. Static functions over the World `w`, like
## economy.gd. Integers only, no Nodes.
##
## A unit line (written by the generator through the ages: new kit, re-priced) moves to an
## age's step when its line upgrade ("line.<slot>.<age>", data: tech.json line_upgrades) is
## researched at the building that trains it, in that age or later, after the line's earlier
## upgrade (workers just follow the age); the player's units follow, keeping their share of health. Research adds to stats of
## units with a tag, re-applied whenever a type changes. A building does one thing at a
## time, from one queue, the genre's way: trained units, research and the age-up wait in it in
## the order clicked, each paid when queued (a cancel refunds it). A research queued anywhere
## can't be queued again, nor a second age-up.
##
## Research effects (data/tech.json) all take one shape: a scope, a stat, and an `add` or a
## `pct` (the change to that number in percent: cost -10 is 10% cheaper, reload -15 reloads 15%
## sooner, build_speed 20 builds 20% faster). Each sums over everything the player researched.
##   {"tag": "melee", "not": ["mounted"], "stat": "attack", "add": 1}
##       unit types with the tag ("all": every unit) and none of the `not` tags, re-applied
##       whenever a type changes, so units already out and units trained later both have it.
##       add: any eval stat (attack, hp, range, speed, armour.melee, armour.pierce, ...), plus
##       UNIT_EXTRA (sight in tiles, carry); pct: UNIT_PCT.
##   {"building": "all", "stat": "sight", "add": 3}   building types ("all", one id, or a list of
##       ids): add: BUILDING_ADD; pct: BUILDING_PCT. Kept per player in w.bmods (see refresh).
##       range: a shooting building's reach in tiles (Slit Windows).
##   {"gather": "wood", "pct": 15}   gathers wood 15% faster (cuts the ticks per unit).
##   {"building": "watchtower", "becomes": "bastion"}   tower_upgrade: every building of the first
##       type turns into the second where it stands, keeping its share of health (and of the work
##       on a foundation); ordering the first builds the second from then on (Economy.upgraded).

##
## A race's bonuses (milestone 14, src/identity.gd) that pricing doesn't put in its units' evals
## work like research it was born with: they come first in every sum (_effects), from setup on.
## Its own research (a creature's or culture's, tech.json `own`) is open only to the creatures and
## cultures that name it; what it lacks (research, buildings, lines, "trade") stays shut, unless
## the host's full_tech_tree rule.

const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")
const Identity := preload("res://src/identity.gd")

const AGE_UP := -2     # a queue entry (and tech index) meaning: age up
const RESEARCH := -3   # queue entry for research r is RESEARCH - r; unit types are >= 0
const NOT_IN_TREE := "not in this race's tech tree"

## Unit adds outside the eval: sight (tiles), carry, kill_gold (gold to the owner for each kill),
## wade (1: no terrain slows it), reach (milli-tiles on a melee reach), slow_on_hit (ticks its hits slow
## the target: Abilities.SLOW_PCT).
const UNIT_EXTRA := ["sight", "carry", "kill_gold", "wade", "reach", "slow_on_hit"]
const UNIT_PCT := ["speed", "reload", "cost", "train_time", "build_speed", "carry", "heal"]   # carry: of the rules' carry
const BUILDING_ADD := ["sight", "armour.melee", "armour.pierce", "trade_fee", "range", "pop"]   # trade_fee: points of the market's fee
const BUILDING_PCT := ["hp", "food", "research_time", "cost", "research_cost"]   # food: a farm's pool, sown or reseeded; research_cost: research there


static func load_tech(resources: Array, btypes: Array) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/tech.json"))
	assert(d != null, "Bad or missing data/tech.json")
	var ages := []
	for a in d.ages.filter(_built):   # planned ages and research are only on the tech tree page
		ages.append({"age": int(a.age), "name": a.name, "desc": a.get("desc", ""), "cost": Economy.cost_vector(resources, a.cost),
			"ticks": int(a.time) * 20, "building": a.building, "requires": a.get("requires", []).duplicate(),
			"requires_else": a.get("requires_else", {}).duplicate()})
	var research := []
	var owners := Identity.owners()   # a creature's or culture's own research: only theirs
	for r in d.research.filter(_built):
		for fx in r.effects:
			_check(fx, r.id)
		assert(not r.has("own") or owners.has(r.id), "%s is somebody's own research, but no creature or culture names it" % r.id)
		research.append({"id": r.id, "name": r.name, "desc": r.get("desc", ""), "cost": Economy.cost_vector(resources, r.cost),
			"ticks": int(r.time) * 20, "building": r.building, "age": int(r.age), "effects": r.effects.duplicate(true),
			"only": r.get("only", owners.get(r.id, [])).duplicate(), "after": r.get("after", ""), "own": r.get("own", "")})
	# Line upgrades: one per trained line (not workers) per later age, where the line trains.
	var ups: Dictionary = d.get("line_upgrades", {})
	for bt in btypes:
		for slot in bt.trains:
			if slot == "worker":
				continue
			for age in [2, 3]:
				var up: Dictionary = ups.get(str(age), {})
				if up.is_empty():
					continue
				research.append({"id": "line.%s.%d" % [slot, age], "name": "%s upgrade" % String(slot).capitalize(),
					"desc": "This line's age %d kit for every one of them, and the ones you train." % age,
					"cost": Economy.cost_vector(resources, up.cost), "ticks": int(up.time) * 20, "building": bt.id,
					"age": age, "effects": [], "only": [], "after": "", "line": slot, "line_age": age})
	for r in research:   # a line upgrade's earlier ones (research indices, latest first), for line_before
		if r.has("line"):
			r.earlier = []
			for age in range(int(r.line_age) - 1, 1, -1):
				var k := research.find_custom(func(o): return o.id == "line.%s.%d" % [r.line, age])
				if k >= 0:
					r.earlier.append(k)
	for r in research:
		assert(r.after == "" or research.any(func(o): return o.id == r.after), "%s comes after unknown research %s" % [r.id, r.after])
	return {"ages": ages, "research": research}


## Assert an effect has the one shape (see the top of this file).
static func _check(fx: Dictionary, id: String) -> void:
	if fx.has("gather"):
		assert(fx.has("pct"), "%s: a gather effect needs pct" % id)
		return
	if fx.has("becomes"):
		assert(fx.has("building") and fx.building != "all", "%s: an upgrade names the building it turns" % id)
		return
	assert(fx.has("stat") and (fx.has("add") != fx.has("pct")), "%s: an effect needs a stat and an add or a pct" % id)
	if fx.has("tag"):
		assert(not fx.has("pct") or fx.stat in UNIT_PCT, "%s: no unit pct for %s" % [id, fx.stat])
	else:
		assert(fx.has("building"), "%s: an effect needs a tag, a building or gather" % id)
		assert(fx.stat in (BUILDING_PCT if fx.has("pct") else BUILDING_ADD), "%s: no building effect on %s" % [id, fx.stat])


## Not marked "status": "planned" (milestone 12: drawn on the tech tree page, not in the game yet).
static func _built(item: Dictionary) -> bool:
	return item.get("status", "") != "planned"


static func setup(w) -> void:
	for p in w.races.size():
		w.ages.append(1)
		var done := PackedByteArray()
		done.resize(w.tech.research.size())
		w.researched.append(done)
		w.gather_ticks.append(PackedInt32Array())
		w.bmods.append([])
		var ident: Dictionary = Identity.of(w.races[p].creature, w.races[p].family).duplicate()
		ident.fx = Identity.sim_effects(ident)
		w.ident.append(ident)
		refresh(w, p)
		retype(w, p)   # the race's bonuses on its units (sight, carry, ...) from the start


## Does this player's race lack that (a research, building, line or "trade")? (Identity.lacks)
static func lacks(w, player: int, id: String) -> bool:
	return Identity.lacks(w.ident[player], id, w.rules)


## The buildings an age (an item of w.tech.ages) needs first, for this player: one its race lacks
## gives way to the age's `requires_else` for it (no Stable: an Archery Range).
static func requires(w, player: int, age: Dictionary) -> Array:
	var out := []
	for need in age.requires:
		if Economy.lacks(w, player, need):
			assert(age.requires_else.has(need), "Age %d needs a %s some races lack, and names nothing else" % [age.age, need])
			out.append(age.requires_else[need])
		else:
			out.append(need)
	return out


## What research (an item of w.tech.research) costs this player at a building type (research_cost).
static func cost_of(w, player: int, item: Dictionary) -> PackedInt32Array:
	var k := Economy.btype_of(w, item.building)
	var pct := bpct(w, player, k, "research_cost") if k >= 0 else 0
	if pct == 0:
		return item.cost
	var cost: PackedInt32Array = item.cost.duplicate()
	for c in cost.size():
		cost[c] = cost[c] * (100 + pct) / 100
	return cost


## The next age's entry for a player, or {} at the last age.
static func next_age(w, player: int) -> Dictionary:
	for a in w.tech.ages:
		if a.age == w.ages[player] + 1:
			return a
	return {}


static func research_index(w, id: String) -> int:
	for k in w.tech.research.size():
		if w.tech.research[k].id == id:
			return k
	return -1


## The queue entry for a tech (a research index or AGE_UP).
static func entry(t: int) -> int:
	return AGE_UP if t == AGE_UP else RESEARCH - t


## The tech a queue entry holds (a research index or AGE_UP), or -1 for a unit.
static func tech_of(e: int) -> int:
	if e >= 0:
		return -1
	return AGE_UP if e == AGE_UP else RESEARCH - e


## The tech at the head of building b's queue (being worked on), or -1.
static func head(w, b: int) -> int:
	var q: Array = w.buildings.queue[b]
	return -1 if q.is_empty() else tech_of(q[0])


## Is that tech (a research index or AGE_UP) in any of this player's queues?
static func queued(w, player: int, t: int) -> bool:
	var bs = w.buildings
	for k in bs.count():
		if bs.owner[k] == player and entry(t) in bs.queue[k]:
			return true
	return false


## The age or research entry a tech stands for, for this player.
static func item_of(w, player: int, t: int) -> Dictionary:
	return next_age(w, player) if t == AGE_UP else w.tech.research[t]


## What a queue entry cost (a cancel refunds it).
static func entry_cost(w, player: int, e: int) -> PackedInt32Array:
	if e >= 0:
		return w.types[e].cost
	return next_age(w, player).cost if tech_of(e) == AGE_UP else cost_of(w, player, w.tech.research[tech_of(e)])


## How long building b's head-of-queue tech takes, in ticks (its train[b] counts up to it), or 0
## with no tech at the head. Research (not the age-up) follows the building's research_time.
static func head_ticks(w, b: int) -> int:
	var t := head(w, b)
	if t == -1:
		return 0
	var p: int = w.buildings.owner[b]
	var ticks := int(item_of(w, p, t).ticks)
	if t != AGE_UP:
		ticks = ticks * (100 + bpct(w, p, w.buildings.kind[b], "research_time")) / 100
	return maxi(1, ticks)


## Why this building can't queue that (age-up: id ""), or "" if it can.
static func why_not(w, player: int, b: int, id: String) -> String:
	var bs = w.buildings
	if b < 0 or bs.owner[b] != player or bs.done[b] == 0:
		return "not yours or not built"
	var bt: String = w.btypes[bs.kind[b]].id
	var item: Dictionary
	if id == "":
		item = next_age(w, player)
		if item.is_empty():
			return "already at the last age"
		if item.building != bt:
			return "not here"   # first: a missing requirement made every building offer the age-up
		if queued(w, player, AGE_UP):
			return "already ageing up"
		for need in requires(w, player, item):   # the genre's pacing: an age-up needs a building of this age first
			if not has_building(w, player, need):
				return "needs a %s" % need
	else:
		var r := research_index(w, id)
		if r < 0:
			return "unknown research"
		item = w.tech.research[r]
		if item.building != bt:
			return "not here"
		if w.researched[player][r] == 1:
			return "already researched"
		if item.after != "" and w.researched[player][research_index(w, item.after)] == 0:
			return "needs %s first" % w.tech.research[research_index(w, item.after)].name   # a track's steps go in order
		if item.has("line") and not _line_has(w, player, item.line, item.line_age):
			return "nothing to upgrade"   # no step at that age (it starts there, or later), or the age brought no new kit
		if item.has("line"):
			var before := line_before(w, player, item)
			if before >= 0 and w.researched[player][before] == 0:
				return "needs %s first" % w.tech.research[before].name   # a line's upgrades go in order, like a track
		if w.ages[player] < item.age:
			return "needs a later age"
		# The tech-tree layer (D-070): some research belongs to some creatures or cultures,
		# unless the host's rules give everyone the full tech tree.
		var race: Dictionary = w.races[player]
		if not item.only.is_empty() and not bool(w.rules.get("full_tech_tree", false)) \
				and not (race.creature in item.only or race.family in item.only):
			return NOT_IN_TREE
		if lacks(w, player, id):
			return NOT_IN_TREE   # milestone 14: what the race lacks (beetles have no Quick Draw)
		if queued(w, player, r):
			return "already being researched"
	if item.building != bt:
		return "not here"
	if bs.queue[b].size() >= int(w.econ.queue_max):
		return "queue full"
	if not w.can_afford(player, item.cost if id == "" else cost_of(w, player, item)):
		return "can't afford it"
	return ""


## Does this player's line have a step after its first at that age, with new kit? (An
## age with nothing better in the culture's kit leaves the line as it was: no upgrade to sell.)
static func _line_has(w, player: int, slot: String, age: int) -> bool:
	var k: int = w.type_of(player, slot)
	if k < 0:
		return false
	var line: Array = w.types[k].line
	for l in line.size():
		if l > 0 and int(line[l].age) == age:
			return line[l].recipe.parts != line[l - 1].recipe.parts
	return false


## The line upgrade that must come before this one (the line's latest earlier age with new kit
## for this player), as a research index, or -1 if it's the line's first.
static func line_before(w, player: int, item: Dictionary) -> int:
	for r in item.earlier:
		if _line_has(w, player, item.line, w.tech.research[r].line_age):
			return r
	return -1


## A research's track: the first research of its chain (`after` steps, or a line's upgrades),
## so the panel can show a chain's steps one at a time in one slot.
static func track_of(w, r: int) -> String:
	var item: Dictionary = w.tech.research[r]
	if item.has("line"):
		return "line." + item.line
	while item.after != "":
		item = w.tech.research[research_index(w, item.after)]
	return item.id


static func has_building(w, player: int, id: String) -> bool:
	var bs = w.buildings
	for k in bs.count():
		if bs.owner[k] == player and bs.done[k] == 1 and w.btypes[bs.kind[k]].id == id:
			return true
	return false


static func cmd_age_up(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if why_not(w, player, b, "") != "":
		return
	w.pay(player, next_age(w, player).cost)
	w.buildings.queue[b].append(AGE_UP)


static func cmd_research(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if why_not(w, player, b, a.id) != "":
		return
	var r := research_index(w, a.id)
	w.pay(player, cost_of(w, player, w.tech.research[r]))
	w.buildings.queue[b].append(entry(r))


## One tick of every age-up and research at the head of a queue (units: Economy.train).
static func tick(w) -> void:
	var bs = w.buildings
	for b in bs.count():
		if bs.done[b] == 0:
			continue
		var r := head(w, b)
		if r == -1:
			continue
		var p: int = bs.owner[b]
		var item: Dictionary = item_of(w, p, r)
		bs.train[b] += 1
		if bs.train[b] < head_ticks(w, b):
			continue
		bs.queue[b].pop_front()
		bs.train[b] = 0
		if r == AGE_UP:
			w.ages[p] += 1
		else:
			w.researched[p][r] = 1
		retype(w, p)
		refresh(w, p)
		w.events.append({"type": "age" if r == AGE_UP else "research", "player": p, "age": w.ages[p], "id": "" if r == AGE_UP else item.id})


## A player's research outside its unit types: gathering speed per resource (the rules' ticks
## per unit, cut by every {"gather": "wood", "pct": 15}), and per building type the sums of the
## building effects (w.bmods[p][k]: {add: {stat: n}, pct: {stat: n}, hp: its max, arm: its armour
## vector}). Buildings already standing keep their share of health when their max changes.
static func refresh(w, player: int) -> void:
	var fxs := _effects(w, player)
	var out := PackedInt32Array()
	for res in w.resources:
		var pct := 0
		for fx in fxs:
			if fx.get("gather", "") == res:
				pct += int(fx.pct)
		out.append(maxi(1, int(w.econ.gather_ticks[res]) * (100 - pct) / 100))
	w.gather_ticks[player] = out
	var old: Array = w.bmods[player]
	var mods := []
	for k in w.btypes.size():
		var bt: Dictionary = w.btypes[k]
		var m := {"add": {}, "pct": {}}
		for fx in fxs:
			if fx.has("building") and not fx.has("becomes") and covers(fx, bt.id):
				var how := "pct" if fx.has("pct") else "add"
				m[how][fx.stat] = int(m[how].get(fx.stat, 0)) + int(fx[how])
		m.hp = maxi(1, int(bt.hp) * (100 + int(m.pct.get("hp", 0))) / 100)
		var arm: PackedInt32Array = bt.arm.duplicate()
		for cls in ["melee", "pierce"]:
			arm[w.classes.find(cls)] += int(m.add.get("armour." + cls, 0))
		m.arm = arm
		mods.append(m)
	w.bmods[player] = mods
	if old.is_empty():
		return
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] == player and old[bs.kind[b]].hp != mods[bs.kind[b]].hp:
			bs.hp[b] = maxi(1, bs.hp[b] * mods[bs.kind[b]].hp / old[bs.kind[b]].hp)
	_upgrade_buildings(w, player)


## tower_upgrade: the player's buildings of an upgraded type become the new type where they
## stand (the same id, footprint, queue and people inside): health keeps its share of the
## maximum, a foundation its share of the work, a shooter its cooldown.
static func _upgrade_buildings(w, player: int) -> void:
	var bs = w.buildings
	for b in bs.count():
		if bs.owner[b] != player:
			continue
		var k: int = bs.kind[b]
		var to := Economy.upgraded(w, player, k)
		if to == k:
			continue
		var old_max: int = w.bmods[player][k].hp
		bs.hp[b] = maxi(1, bs.hp[b] * w.bmods[player][to].hp / old_max)
		bs.progress[b] = bs.progress[b] * w.btypes[to].build_ticks / maxi(1, w.btypes[k].build_ticks)
		bs.kind[b] = to
		w.events.append({"type": "upgraded", "player": player, "building": bs.id[b], "from": k, "to": to})


## Does a building effect reach building type `id`? ("all", that id, or a list holding it.)
static func covers(fx: Dictionary, id: String) -> bool:
	if fx.building is Array:
		return id in fx.building
	return fx.building == "all" or fx.building == id


## The sum of a building effect's adds (or pcts) for a player's building type k.
static func badd(w, player: int, k: int, stat: String) -> int:
	return int(w.bmods[player][k].add.get(stat, 0))


static func bpct(w, player: int, k: int, stat: String) -> int:
	return int(w.bmods[player][k].pct.get(stat, 0))


## Every effect of the race's bonuses the sim applies, then of every research this player has, in
## research order.
static func _effects(w, player: int) -> Array:
	var out: Array = w.ident[player].fx.duplicate()
	for r in w.tech.research.size():
		if w.researched[player][r] == 1:
			out.append_array(w.tech.research[r].effects)
	return out


## Does a unit effect reach a type with these tags?
static func reaches(fx: Dictionary, tags: Array) -> bool:
	return Identity.reaches(fx, tags)


static func _upgraded(w, player: int, slot: String, age: int) -> bool:
	var r := research_index(w, "line.%s.%d" % [slot, age])
	return r >= 0 and w.researched[player][r] == 1


## Bring every one of a player's unit types up to date: the line step for its age, then
## every research it has. Its units follow (health keeps its share of the maximum).
static func retype(w, player: int) -> void:
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		if t.player != player:
			continue
		var step: Dictionary = t.line[0]
		for l in t.line:
			if l.age <= w.ages[player] and (l.age == t.line[0].age or t.worker or _upgraded(w, player, t.slot, l.age)):
				step = l
		var old_hp: int = t.hp
		var e: Dictionary = step.eval.duplicate(true)
		var add := {}   # sight, carry: outside the eval
		var pct := {}
		for fx in _effects(w, player):
			if not reaches(fx, e.tags):
				continue
			if fx.has("pct"):
				pct[fx.stat] = int(pct.get(fx.stat, 0)) + int(fx.pct)
			elif fx.stat in UNIT_EXTRA:
				add[fx.stat] = int(add.get(fx.stat, 0)) + int(fx.add)
			elif "." in fx.stat:   # armour.melee: a class inside a stat
				var parts: PackedStringArray = fx.stat.split(".")
				e[parts[0]][parts[1]] = int(e[parts[0]].get(parts[1], 0)) + int(fx.add)
			else:
				e[fx.stat] = int(e[fx.stat]) + int(fx.add)
		w.set_type(k, step.recipe, e)
		t.speed = maxi(1, t.speed * (100 + int(pct.get("speed", 0))) / 100)
		t.reload = maxi(1, t.reload * (100 + int(pct.get("reload", 0))) / 100)
		t.train_ticks = maxi(1, t.train_ticks * (100 + int(pct.get("train_time", 0))) / 100)
		var cost: PackedInt32Array = t.cost
		for c in cost.size():
			cost[c] = cost[c] * (100 + int(pct.get("cost", 0))) / 100
		t.cost = cost
		t.build_pct = int(pct.get("build_speed", 0))
		t.sight_add = int(add.get("sight", 0))
		t.carry_add = int(add.get("carry", 0)) + int(w.econ.carry) * int(pct.get("carry", 0)) / 100
		t.heal_pct = int(pct.get("heal", 0))
		t.kill_gold = int(add.get("kill_gold", 0))
		t.wade = int(add.get("wade", 0))
		t.slow_on_hit = int(add.get("slow_on_hit", 0))
		if not t.ranged:
			t.reach += int(add.get("reach", 0))
		var u = w.units
		for i in u.count():
			if u.kind[i] == k:
				u.hp[i] = maxi(1, u.hp[i] * t.hp / maxi(1, old_hp))
				u.speed[i] = t.speed
		var bs = w.buildings
		for b in bs.count():   # those sheltering inside keep their share too (garrison.gd records: [id, kind, hp, ...])
			var recs: Array = bs.inside[b]
			for n in recs.size():
				var rec: PackedInt32Array = recs[n]
				if rec[1] == k:
					rec[2] = maxi(1, rec[2] * t.hp / maxi(1, old_hp))
					recs[n] = rec
