extends RefCounted
## Ages and research, from data/tech.json. Static functions over the World `w`, like
## economy.gd. Integers only, no Nodes.
##
## An age-up moves the player's unit types to the next step of their unit lines (each
## line was written by the generator through the ages: new kit, re-priced), and the
## player's units follow, keeping their share of health. Research adds to stats of
## units with a tag, re-applied whenever a type changes. A building does one thing at a
## time: while it ages up or researches, its training waits.

const Economy := preload("res://src/sim/economy.gd")
const Combat := preload("res://src/sim/combat.gd")

const AGE_UP := -2   # buildings.research: researching this means ageing up


static func load_tech(resources: Array) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/tech.json"))
	assert(d != null, "Bad or missing data/tech.json")
	var ages := []
	for a in d.ages:
		ages.append({"age": int(a.age), "name": a.name, "cost": Economy.cost_vector(resources, a.cost),
			"ticks": int(a.time) * 20, "building": a.building, "requires": a.get("requires", []).duplicate()})
	var research := []
	for r in d.research:
		research.append({"id": r.id, "name": r.name, "cost": Economy.cost_vector(resources, r.cost),
			"ticks": int(r.time) * 20, "building": r.building, "age": int(r.age), "effects": r.effects.duplicate(true)})
	return {"ages": ages, "research": research}


static func setup(w) -> void:
	for p in w.races.size():
		w.ages.append(1)
		var done := PackedByteArray()
		done.resize(w.tech.research.size())
		w.researched.append(done)


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


## Why this building can't start that (age-up: id ""), or "" if it can.
static func why_not(w, player: int, b: int, id: String) -> String:
	var bs = w.buildings
	if b < 0 or bs.owner[b] != player or bs.done[b] == 0:
		return "not yours or not built"
	if bs.research[b] != -1:
		return "busy"
	var bt: String = w.btypes[bs.kind[b]].id
	var item: Dictionary
	if id == "":
		item = next_age(w, player)
		if item.is_empty():
			return "already at the last age"
		for k in bs.count():
			if bs.owner[k] == player and bs.research[k] == AGE_UP:
				return "already ageing up"
		for need in item.requires:   # the genre's pacing: an age-up needs a building of this age first
			if not has_building(w, player, need):
				return "needs a %s" % need
	else:
		var r := research_index(w, id)
		if r < 0:
			return "unknown research"
		item = w.tech.research[r]
		if w.researched[player][r] == 1:
			return "already researched"
		if w.ages[player] < item.age:
			return "needs a later age"
		for k in bs.count():
			if bs.owner[k] == player and bs.research[k] == r:
				return "already being researched"
	if item.building != bt:
		return "not here"
	if not w.can_afford(player, item.cost):
		return "can't afford it"
	return ""


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
	w.buildings.research[b] = AGE_UP
	w.buildings.research_t[b] = 0


static func cmd_research(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(a.building)
	if why_not(w, player, b, a.id) != "":
		return
	var r := research_index(w, a.id)
	w.pay(player, w.tech.research[r].cost)
	w.buildings.research[b] = r
	w.buildings.research_t[b] = 0


## One tick of every age-up and research in progress.
static func tick(w) -> void:
	var bs = w.buildings
	for b in bs.count():
		var r: int = bs.research[b]
		if r == -1:
			continue
		var p: int = bs.owner[b]
		var item: Dictionary = next_age(w, p) if r == AGE_UP else w.tech.research[r]
		bs.research_t[b] += 1
		if bs.research_t[b] < item.ticks:
			continue
		bs.research[b] = -1
		bs.research_t[b] = 0
		if r == AGE_UP:
			w.ages[p] += 1
		else:
			w.researched[p][r] = 1
		retype(w, p)
		w.events.append({"type": "age" if r == AGE_UP else "research", "player": p, "age": w.ages[p], "id": "" if r == AGE_UP else item.id})


## Bring every one of a player's unit types up to date: the line step for its age, then
## every research it has. Its units follow (health keeps its share of the maximum).
static func retype(w, player: int) -> void:
	for k in w.types.size():
		var t: Dictionary = w.types[k]
		if t.player != player:
			continue
		var step: Dictionary = t.line[0]
		for l in t.line:
			if l.age <= w.ages[player]:
				step = l
		var old_hp: int = t.hp
		var e: Dictionary = step.eval.duplicate(true)
		for r in w.tech.research.size():
			if w.researched[player][r] == 0:
				continue
			for fx in w.tech.research[r].effects:
				if fx.tag in e.tags:
					e[fx.stat] = int(e[fx.stat]) + int(fx.add)
		w.set_type(k, step.recipe, e)
		var u = w.units
		for i in u.count():
			if u.kind[i] == k:
				u.hp[i] = maxi(1, u.hp[i] * t.hp / maxi(1, old_hp))
				u.speed[i] = t.speed
