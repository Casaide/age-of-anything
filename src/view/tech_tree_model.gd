extends RefCounted
## What the tech tree page shows, from data alone (no Nodes, so a headless test can check it):
## the ages (data/tech.json), the buildings as columns (data/buildings.json, in its "tree"
## order), and under each building its unit lines (roster slots in the host rules: one node per
## age step) and its research (tech.json), packed into lanes so a line or a research track runs
## straight down through the ages. Items marked "status": "planned" come too: the page draws
## them as blank frames. With a race, line steps carry its own unit names, research only some
## races get is marked (or crossed out for the others), and the race's bonuses are put in words
## with where each came from (milestone 14, src/identity.gd: its group, creature and culture).
## Other races' own research (tech.json `own`) is left off a race's page; what the race lacks
## (research, buildings, lines, a line's step) is crossed out. See docs/milestones/m12-tech-tree.md,
## "The tech tree page", and m14-race-identity.md.

const DataLib := preload("res://src/data_lib.gd")
const Identity := preload("res://src/identity.gd")

const PLANNED := "planned"


## {ages, columns, nodes, joins, race}. `race` may be {} (the plain tree, no names).
static func build(race: Dictionary, rules: Dictionary, lib) -> Dictionary:
	var bdata: Dictionary = DataLib.load_json("res://data/buildings.json")
	var tdata: Dictionary = DataLib.load_json("res://data/tech.json")
	var full_tree := bool(rules.get("full_tech_tree", false))
	var ident: Dictionary = {} if race.is_empty() else Identity.of(race.creature, race.family)
	var owners := Identity.owners()
	var ages := []
	for a in tdata.ages:
		ages.append({"age": int(a.age), "name": a.name, "desc": a.get("desc", ""), "status": a.get("status", "built"),
			"cost": a.get("cost", {}), "building": a.building,
			"requires": a.get("requires", []).map(func(id): return a.requires_else[id] if not ident.is_empty() and Identity.lacks(ident, id, rules) else id),   # (no Stable: its stand-in)
			"requires_text": a.get("requires_text", "")})
	var last_age: int = ages[-1].age

	# Columns: the "tree" order, then any building it doesn't name (by age, then id).
	var ids: Array = bdata.get("tree", []).filter(func(id): return bdata.buildings.has(id))
	var rest: Array = bdata.buildings.keys().filter(func(id): return not id in ids)
	rest.sort_custom(func(x, y): return [int(bdata.buildings[x].age), x] < [int(bdata.buildings[y].age), y])
	ids += rest

	var nodes := []
	var joins := []   # [from key, to key]: lines on the page (a line's steps, a research track)
	var columns := []
	for id in ids:
		var b: Dictionary = bdata.buildings[id]
		var col := columns.size()
		var bnode := {"key": "b:" + id, "kind": "building", "id": id, "name": b.name, "desc": b.get("desc", ""),
			"age": int(b.age), "status": b.get("status", "built"), "col": col, "lane": -1, "cost": b.get("cost", {}),
			"building": id, "hotkey": b.get("hotkey", ""), "lacks": not ident.is_empty() and Identity.lacks(ident, id, rules)}
		nodes.append(bnode)
		var groups := []   # each a list of nodes that must share a lane (top to bottom)
		# Unit lines this building trains (rules roster), one node per age step.
		for sd in rules.roster:
			if sd.get("building", "") != id:
				continue
			var group := []
			var unit: Dictionary = _race_unit(race, sd.slot)
			var line_planned: bool = sd.get("status", "") == PLANNED
			# From the age the line can first be trained: its slot's age, or its building's if later
			# (the ranged lines are generated from age 1 but the Archery Range opens in age 2).
			var from := maxi(int(sd.tier), int(b.age))
			var lacked: bool = not ident.is_empty() and Identity.lacks(ident, sd.slot, rules)   # its creature or culture lacks it (beetles' mounted archers)
			if not line_planned and (sd.slot in race.get("lacks", []) or lacked):   # this race has no such line (centaurs' archers already ride): one crossed-out node
				groups.append([{"key": "u:%s@%d" % [sd.slot, from], "kind": "unit", "id": sd.slot, "slot": sd.slot,
					"name": sd.get("name", String(sd.slot).capitalize()), "line_name": sd.get("name", ""), "desc": sd.get("desc", ""), "age": from,
					"status": "built", "lacks": true, "col": col, "building": id, "first": true, "tier": int(sd.tier),
					"early_kit": "", "step": {}, "cost": {}}])
				continue
			if sd.get("role", "") == "hero" and not unit.is_empty():   # the race's heroes (D-138): one node each, where they're first trained
				for u in race.units.filter(func(x): return x.recipe.slot == sd.slot):
					var hs: Dictionary = lib.heroes.hero_signatures[u.recipe.hero]
					var st: Dictionary = _step(u, from)
					groups.append([{"key": "u:%s.%s@%d" % [sd.slot, u.recipe.hero, from], "kind": "unit", "id": sd.slot, "slot": sd.slot, "hero": u.recipe.hero,
						"name": u.recipe.name, "line_name": sd.get("name", ""), "desc": "%s\nAura: %s" % [hs.temper, hs.aura.text], "age": from,
						"status": "built", "lacks": false, "col": col, "building": id, "first": true, "tier": int(sd.tier),
						"early_kit": "", "step": st, "cost": st.eval.cost}])
				continue
			var prev_recipe = null
			for age in range(from, int(sd.get("last_age", last_age)) + 1):
				var step: Dictionary = _step(unit, age)
				var planned: bool = line_planned or step.is_empty() or _age_planned(ages, age)
				if not planned and step.recipe == prev_recipe:
					continue   # the same unit as the age before: no node (Dominic: "if unit doesn't change, shouldn't show every age")
				if not planned:
					prev_recipe = step.recipe
				var name: String = sd.get("name", String(sd.slot).capitalize())
				var desc: String = sd.get("desc", "")
				if not step.is_empty():
					name = step.recipe.get("name", name)
					if step.recipe.has("unique"):   # the race's unique unit says what its theme does (data/uniques.json)
						desc = lib.uniques[step.recipe.unique].desc
				group.append({"key": "u:%s@%d" % [sd.slot, age], "kind": "unit", "id": sd.slot, "slot": sd.slot,
					"name": name, "line_name": sd.get("name", name), "desc": desc, "age": age,
					"status": PLANNED if planned else "built", "col": col, "building": id, "first": age == from, "tier": int(sd.tier),
					"early_kit": _step(unit, int(sd.tier)).get("recipe", {}).get("name", "") if age == from and from > int(sd.tier) else "",
					"step": step, "cost": step.get("eval", {}).get("cost", {}) if not planned else {},
					"lacks": not ident.is_empty() and age > from and Identity.lacks(ident, "line.%s.%d" % [sd.slot, age], rules)})   # (royals' skirmishers stop at age 2)
			for k in range(1, group.size()):
				joins.append([group[k - 1].key, group[k].key])
			groups.append(group)
		# Research here: tracks (joined by `after`) in one lane, the rest one node each.
		var here: Array = tdata.research.filter(func(r): return r.building == id and _shown(r, race, ident, full_tree))
		var by_id := {}
		for r in here:
			by_id[r.id] = r
		var done := {}
		for r in here:
			if done.has(r.id) or by_id.has(r.get("after", "")):
				continue   # not the head of its track
			var group := []
			var cur = r
			while cur != null:
				done[cur.id] = true
				group.append(_research_node(cur, col, race, full_tree, ident, owners.get(cur.id, []), rules))
				var nxt = null
				for r2 in here:
					if r2.get("after", "") == cur.id:
						nxt = r2
				cur = nxt
			for k in range(1, group.size()):
				joins.append([group[k - 1].key, group[k].key])
			groups.append(group)
		# Pack: each group in the first lane free at all its ages (lines first, then tracks, then singles).
		var multi: Array = groups.filter(func(g): return g.size() > 1 or g[0].kind == "unit")
		var single: Array = groups.filter(func(g): return not (g.size() > 1 or g[0].kind == "unit"))
		var used := []   # per lane: {age: true}
		for g in multi + single:
			var lane := 0
			while lane < used.size() and g.any(func(n): return used[lane].has(n.age)):
				lane += 1
			if lane == used.size():
				used.append({})
			for n in g:
				used[lane][n.age] = true
				n.lane = lane
				nodes.append(n)
		columns.append({"id": id, "name": b.name, "age": int(b.age), "status": bnode.status, "lanes": maxi(1, used.size())})
	return {"ages": ages, "columns": columns, "nodes": nodes, "joins": joins, "race": _race_panel(race, rules, lib, tdata)}


## Is this research on the page? Another race's own research isn't on a race's page (the plain
## tree, and the full tech tree, show them all).
static func _shown(r: Dictionary, race: Dictionary, ident: Dictionary, full_tree: bool) -> bool:
	return not r.has("own") or race.is_empty() or full_tree or r.id in ident.research


static func _research_node(r: Dictionary, col: int, race: Dictionary, full_tree: bool, ident: Dictionary, owned: Array, rules: Dictionary) -> Dictionary:
	var only: Array = r.get("only", owned)   # (a creature's or culture's own research: those that name it)
	var lacks: bool = not only.is_empty() and not race.is_empty() and not full_tree \
		and not (race.creature in only or race.family in only)
	lacks = lacks or (not ident.is_empty() and Identity.lacks(ident, r.id, rules))   # what the race lacks (frogs: Ring Mail)
	return {"key": "r:" + r.id, "kind": "research", "id": r.id, "name": r.name, "desc": r.get("desc", ""),
		"age": int(r.age), "status": r.get("status", "built"), "col": col, "building": r.building, "cost": r.get("cost", {}),
		"effect": r.get("effect", effect_text(r.get("effects", []))), "icon": r.get("icon", r.id),
		"only": only, "race_only": not only.is_empty() and not lacks, "lacks": lacks}


static func _age_planned(ages: Array, age: int) -> bool:
	for a in ages:
		if a.age == age:
			return a.status == PLANNED
	return true


## The race's unit for a roster slot, or {}.
static func _race_unit(race: Dictionary, slot: String) -> Dictionary:
	for u in race.get("units", []):
		if u.recipe.slot == slot:
			return u
	return {}


## The step of a unit line at an age ({age, recipe, eval}), or {} when the line has none then.
static func _step(unit: Dictionary, age: int) -> Dictionary:
	for l in unit.get("line", []):
		if int(l.age) == age:
			return l
	return {}


## Research effects in words ("Workers +15 HP, +1 melee armour", "Wood gathered 15% faster",
## "Buildings +3 sight"). Effects on the same units or buildings in a row share their subject.
static func effect_text(effects: Array) -> String:
	var out := []
	var last := ""
	for e in effects:
		if e.has("gather"):
			out.append("%s gathered %d%% faster" % [String(e.gather).capitalize(), int(e.pct)])
			last = ""
			continue
		if e.has("start"):
			out.append("%+d %s at the start" % [int(e.add), e.start])
			last = ""
			continue
		if e.has("becomes"):   # tower_upgrade
			out.append("%ss become %ss" % [String(e.building).capitalize(), String(e.becomes).capitalize()])
			last = ""
			continue
		var who := _subject(e)
		var what := _phrase(e.stat, int(e.pct if e.has("pct") else e.add), e.has("pct"))
		if who == last:
			out[-1] += ", " + what
		else:
			out.append("%s %s" % [who, what])
		last = who
	return "; ".join(out) if out.any(func(s): return "," in s) else ", ".join(out)


## Who an effect reaches, in words: "Workers", "Foot melee units", "Buildings", "Farms".
static func _subject(e: Dictionary) -> String:
	if e.has("building"):
		if e.building is Array:
			var names: Array = e.building.map(func(b): return String(b).capitalize() + "s")
			return names[0] if names.size() == 1 else ", ".join(names.slice(0, -1)) + " and " + names[-1]
		return "Buildings" if e.building == "all" else String(e.building).capitalize() + "s"
	var nots: Array = e.get("not", [])
	var who: String = {"worker": "Workers", "all": "Every unit"}.get(e.tag, "%s units" % String(e.tag).capitalize())
	if "mounted" in nots:
		who = "Foot " + who.to_lower()
	var rest := nots.filter(func(t): return t != "mounted")
	if not rest.is_empty():
		who += " (not %s)" % ", ".join(rest)
	return who


## One stat change in words: "+1 attack", "+10% speed", "reload 15% faster", "hold 50% more food".
static func _phrase(stat: String, n: int, pct: bool) -> String:
	var a := absi(n)
	if pct:
		match stat:
			"reload": return "reload %d%% %s" % [a, "faster" if n < 0 else "slower"]
			"train_time": return "train %d%% %s" % [a, "faster" if n < 0 else "slower"]
			"research_time": return "research %d%% %s" % [a, "faster" if n < 0 else "slower"]
			"age_time": return "advance ages %d%% %s" % [a, "faster" if n < 0 else "slower"]
			"build_speed": return "build %d%% %s" % [a, "faster" if n > 0 else "slower"]
			"cost": return "%d%% %s" % [a, "cheaper" if n < 0 else "dearer"]
			"food": return "hold %d%% %s food" % [a, "more" if n > 0 else "less"]
			"hp": return "%+d%% HP" % n
		return "%+d%% %s" % [n, stat.replace("_", " ")]
	match stat:
		"hp": return "%+d HP" % n
		"carry": return "carry %+d" % n
		"range": return "%+d range" % n
		"trade_fee": return "trade fee %d points %s (selling pays more)" % [a, "lower" if n < 0 else "higher"]
	if stat.begins_with("armour."):
		return "%+d %s armour" % [n, stat.trim_prefix("armour.")]
	return "%+d %s" % [n, stat.replace("_", " ")]


## The race panel: name, creature, culture, bonuses in words, its own research, what it
## lacks, and how its units move.
static func _race_panel(race: Dictionary, rules: Dictionary, lib, tdata: Dictionary) -> Dictionary:
	if race.is_empty():
		return {}
	var c: Dictionary = lib.creatures[race.creature]
	var words: Dictionary = DataLib.load_json("res://data/groups.json").movement
	var id_text := identity_text(race, rules, tdata)
	# Movement: the class each unit gets (rules.movement.classes, first tag that matches).
	var classes := {}   # class -> [unit names]
	for u in race.units:
		var cls := "ground"
		for entry in rules.get("movement", {}).get("classes", []):
			if entry.tag in u.eval.tags:
				cls = entry["class"]
				break
		if not classes.has(cls):
			classes[cls] = []
		classes[cls].append(u.recipe.get("name", u.recipe.slot))
	var moves := []
	var names: Array = classes.keys()
	names.sort()
	for cls in names:
		var text: String = words.get(cls, String(cls).capitalize())
		moves.append(text if names.size() == 1 else "%s (%s)" % [text, ", ".join(classes[cls])])
	return {"name": race.name, "creature": c.plural, "culture": String(race.family).capitalize(),
		"bonuses": id_text.bonuses, "own": id_text.own, "lacks": id_text.lacks, "moves": moves, "units": race.units}


## A race's identity in words (the tech tree page's panel and the lobby's card): {bonuses: ["Houses
## cost 30% less (they dig in) (Bugs)", ...], own: ["Shell Polish: ..."], lacks: ["Quick Draw", ...]}.
static func identity_text(race: Dictionary, rules: Dictionary, tdata := {}) -> Dictionary:
	if tdata.is_empty():
		tdata = DataLib.load_json("res://data/tech.json")
	var bdata: Dictionary = DataLib.load_json("res://data/buildings.json").buildings
	var ident := Identity.of(race.creature, race.family)
	var full_tree := bool(rules.get("full_tech_tree", false))
	var research := {}
	for r in tdata.research:
		research[r.id] = r
	var bonuses := []
	for b in ident.bonuses:
		bonuses.append("%s (%s)" % [b.text, b.from])
	var own := []
	for id in ident.research:
		var r: Dictionary = research[id]
		own.append("%s: %s%s" % [r.name, r.desc, " (planned)" if r.get("status", "") == PLANNED else ""])
	var lacks := []
	if not full_tree:
		for id in ident.lacks:
			if research.has(id):
				lacks.append(research[id].name)
			elif bdata.has(id):
				lacks.append(bdata[id].name + (" (and what it trains)" if not bdata[id].get("trains", []).is_empty() else ""))
			elif id == Identity.TRADE:
				lacks.append("Market trade (buying and selling)")
			elif id.begins_with("line."):
				var parts: PackedStringArray = id.split(".")
				lacks.append("%s's age-%s step" % [_slot_name(rules, parts[1]), parts[2]])
			else:
				lacks.append("%s line" % _slot_name(rules, id))
	for sd in rules.roster:   # unit lines it has none of (nothing carries it, or its archers already ride)
		if sd.slot in race.get("lacks", []) and not ("%s line" % sd.name) in lacks:
			lacks.append("%s line" % sd.name)
	return {"bonuses": bonuses, "own": own, "lacks": lacks}


static func _slot_name(rules: Dictionary, slot: String) -> String:
	for sd in rules.roster:
		if sd.slot == slot:
			return sd.get("name", slot.capitalize())
	return slot.capitalize()


