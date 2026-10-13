extends SceneTree
## Mass battles at equal cost: about 30 against 30, mixed armies, both sides attack-moving on an
## open map, every match fought twice with the sides swapped (so where they start doesn't decide
## it). For each race of the balance prompts, in one age (unit lines upgraded to it): archers
## against cavalry (the large slot), skirmishers and spears; spears and skirmishers against
## cavalry; spears with archers against spears with cavalry; a mixed army and spears with
## archers against all archers; swordsmen (the infantry slot) against spears, skirmishers and cavalry,
## archers against them, swords with archers against spears with cavalry; mounted archers and scouts
## against what they beat and what beats them; in age 3 the unique unit against its race's lines. Prints win rates and the
## value each side has left.
## Deterministic. Massed archers should be strong but counterable.
## Run: godot --headless --path . --script res://tests/mass_battle.gd [-- age [budget] [combat_rule=value ...] [serial] [jobs=N] [beasts]]
## (each match in its own process, side by side, unless "serial")

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Tech := preload("res://src/sim/tech.gd")
const RoundRobin := preload("res://tests/round_robin.gd")
const Par := preload("res://tests/par.gd")

const RACES := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
	"greek hoplites", "spooky beetle knights"]
## [label, side A slots, side B slots]: the budget is split evenly over a side's slots.
const MATCHES := [
	["archers v cavalry", ["archer"], ["large"]],
	["archers v skirmishers", ["archer"], ["skirmisher"]],
	["archers v spears", ["archer"], ["spear"]],
	["spears v cavalry", ["spear"], ["large"]],
	["skirmishers v cavalry", ["skirmisher"], ["large"]],
	["spear+archer v spear+cavalry", ["spear", "archer"], ["spear", "large"]],
	["archers v mixed", ["archer"], ["spear", "skirmisher", "large"]],
	["archers v spear+archer", ["archer"], ["spear", "archer"]],
	["swords v spears", ["infantry"], ["spear"]],
	["swords v skirmishers", ["infantry"], ["skirmisher"]],
	["archers v swords", ["archer"], ["infantry"]],
	["swords v cavalry", ["infantry"], ["large"]],
	["sword+archer v spear+cavalry", ["infantry", "archer"], ["spear", "large"]],
	["horse archers v swords", ["mounted_archer"], ["infantry"]],
	["horse archers v spears", ["mounted_archer"], ["spear"]],
	["skirmishers v horse archers", ["skirmisher"], ["mounted_archer"]],
	["cavalry v horse archers", ["large"], ["mounted_archer"]],
	["horse archers v archers", ["mounted_archer"], ["archer"]],
	["scouts v skirmishers", ["scout"], ["skirmisher"]],
	["scouts v archers", ["scout"], ["archer"]],
	["spears v scouts", ["spear"], ["scout"]],
	["cavalry v scouts", ["large"], ["scout"]],
]
## The Castle's unique unit (age 3) against the lines of its own race, at equal cost.
const UNIQUE_MATCHES := [
	["unique v spears", ["unique"], ["spear"]],
	["unique v swords", ["unique"], ["infantry"]],
	["unique v archers", ["unique"], ["archer"]],
	["unique v cavalry", ["unique"], ["large"]],
	["unique v spear+archer", ["unique"], ["spear", "archer"]],
]
## Siege (milestone 13, age 3): engines behind a screen of spears against what they should beat
## (crowds of archers and foot) and what should beat them (cavalry).
const SIEGE_MATCHES := [
	["catapult+spear v archers", ["catapult", "spear"], ["archer"]],
	["catapult+spear v spear+archer", ["catapult", "spear"], ["spear", "archer"]],
	["bolt+spear v spears", ["bolt_thrower", "spear"], ["spear"]],
	["bolt+spear v spear+cavalry", ["bolt_thrower", "spear"], ["spear", "large"]],
	["catapults v cavalry", ["catapult"], ["large"]],
	["bolt throwers v cavalry", ["bolt_thrower"], ["large"]],
]
## War beasts (milestone 13 step 7, D-129, age 3): big, slow and tough; they should beat foot soldiers
## (swords, archers) and lose to spears, skirmishers and bolt throwers at equal cost.
const BEAST_MATCHES := [
	["beasts v swords", ["war_beast"], ["infantry"]],
	["beasts v archers", ["war_beast"], ["archer"]],
	["beasts v cavalry", ["war_beast"], ["large"]],
	["spears v beasts", ["spear"], ["war_beast"]],
	["skirmishers v beasts", ["skirmisher"], ["war_beast"]],
	["bolt+spear v beasts", ["bolt_thrower", "spear"], ["war_beast"]],
	["beast+archer v spear+archer", ["war_beast", "archer"], ["spear", "archer"]],
]
const LIMIT := 4000   # ticks (3:20)
const FRONT := [22000, 42000]   # x of each side's front line; the map is 64 tiles square
const MID_Y := 32000
const GAP := 900     # between bodies in the starting blocks


func _init() -> void:
	var all_args := Par.plain(OS.get_cmdline_user_args())
	var only := all_args.filter(func(a): return a.begins_with("match:"))   # match:<k>: just that match (a child)
	var serial := all_args.has("serial")
	var args := all_args.filter(func(a): return not a.begins_with("match:") and a != "serial")
	var age := int(args[0]) if args.size() > 0 else 2
	var budget := int(args[1]) if args.size() > 1 else 1500
	var matches: Array = MATCHES + (SIEGE_MATCHES + UNIQUE_MATCHES + BEAST_MATCHES if age >= 3 else [])
	var beasts := all_args.has("beasts")   # just the war beasts' matches (tuning their price_points)
	if beasts:
		matches = BEAST_MATCHES
		args = args.filter(func(a): return a != "beasts")
	var t0 := Time.get_ticks_msec()
	if only.is_empty():
		for arg in args.slice(2):
			print("trying combat.%s = %s" % [arg.get_slice("=", 0), arg.get_slice("=", 1)])
		print("Mass battles, age %d, budget %d a side, each fought both ways round" % [age, budget])
	if only.is_empty() and not serial:   # each match in its own process, side by side; printed in order
		var jobs := range(matches.size()).map(func(k): return Par.job("mass/%d" % k, "res://tests/mass_battle.gd", args + (["beasts"] if beasts else []) + ["match:%d" % k]))
		for r in Par.run(jobs, Par.jobs_wanted(OS.get_cmdline_user_args()), true):
			assert(r.code == 0, "mass_battle: %s failed, see %s" % [r.name, r.log])
			print("\n" + FileAccess.get_file_as_string(r.log).trim_prefix(FileAccess.get_file_as_string(r.log).get_slice("\n", 0)).strip_edges())
		print("\n(%d s)" % ((Time.get_ticks_msec() - t0) / 1000))
		quit()
		return
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	for arg in args.slice(2):
		rules.combat[arg.get_slice("=", 0)] = int(arg.get_slice("=", 1))
	var races := RACES.map(func(p): return gen.generate(p, rules))
	if not only.is_empty():
		matches = [matches[int(only[0].trim_prefix("match:"))]]
	for m in matches:
		var wins := 0
		var losses := 0
		var left_a := 0
		var left_b := 0
		var fights := 0
		var rows := []
		for r in races:
			if not (m[1] + m[2]).all(func(slot): return RoundRobin.has_line(r, slot)):
				continue   # (the race lacks a line: centaurs have no mounted archers)
			var rw := 0
			var counts := ""
			for swap in 2:
				var res := fight(rules, age, budget, r, m[1], m[2], swap == 1)
				fights += 1
				left_a += res.left_pct[0]
				left_b += res.left_pct[1]
				if res.result > 0:
					wins += 1
					rw += 1
				elif res.result < 0:
					losses += 1
				counts = "%d v %d" % [res.n[0], res.n[1]]
				rows.append("    %-26s %s  %s  left %3d%% v %3d%%  (%ds)  shots %d, %d%% missed" % [r.name.left(26), counts,
					"A" if res.result > 0 else ("B" if res.result < 0 else "="), res.left_pct[0], res.left_pct[1], res.ticks / 20,
					res.shots, res.missed * 100 / maxi(1, res.shots)])
		print("\n%-30s A wins %2d of %d (B %d)   value left: A %3d%%  B %3d%%" % [m[0], wins, fights, losses, left_a / maxi(1, fights), left_b / maxi(1, fights)])
		for row in rows:
			print(row)
	if only.is_empty():
		print("\n(%d s)" % ((Time.get_ticks_msec() - t0) / 1000))
	quit()


## One battle: side A (player 0, or player 1 when `swap`) fields `sa`, side B `sb`, each with
## `budget` split evenly over its slots. Returns {result: +1 A won, -1 B won, 0 draw (by value
## left), n: [units A, units B], left_pct: [value left A, B], ticks}.
static func fight(rules: Dictionary, age: int, budget: int, race: Dictionary, sa: Array, sb: Array, swap: bool) -> Dictionary:
	var bare: Dictionary = rules.duplicate(true)
	bare.economy.start.buildings = []
	bare.economy.start.workers = 0
	bare["animals"] = false
	var w := World.new(1, SimMap.load_id("flat_test"), [race, race], bare)
	for p in 2:
		RoundRobin.in_age(w, p, age)
	var sides := [sa, sb] if not swap else [sb, sa]
	var cost := {}   # type index -> cost
	var total := [0, 0]
	var n := [0, 0]
	for p in 2:
		var slots: Array = sides[p]
		var dir := 1 if p == 0 else -1
		var row := 0
		# Melee in front, shooters behind: the order the slots are listed in, the cheap blocks first.
		var order := slots.duplicate()
		order.sort_custom(func(x, y): return _rank(x) < _rank(y))
		for slot in order:
			var k: int = w.type_of(p, slot)
			var c := 0
			for v in w.types[k].cost:
				c += v
			cost[k] = c
			var count := maxi(1, (budget / slots.size() + c / 2) / c)
			for q in count:
				var x: int = FRONT[p] - dir * (row + q / 8) * GAP
				var y: int = MID_Y + (q % 8 - 4) * GAP + GAP / 2
				w.issue(p, Commands.SPAWN, {"slot": slot, "count": 1, "x": x, "y": y})
			row += (count + 7) / 8
			total[p] += count * c
			n[p] += count
	w.step()
	while w.units.count() < n[0] + n[1]:
		w.step()
	for p in 2:
		var ids := []
		for i in w.units.count():
			if w.units.owner[i] == p:
				ids.append(w.units.id[i])
		w.issue(p, Commands.ATTACK_MOVE, {"ids": ids, "x": FRONT[1 - p], "y": MID_Y})
	var left := [0, 0]
	var shots := 0
	var missed := 0
	while w.tick < LIMIT:
		w.step()
		for e in w.events:
			if e.type == "shot":
				shots += 1
			elif e.type == "miss":
				missed += 1
		left = [0, 0]
		for i in w.units.count():
			left[w.units.owner[i]] += cost[w.units.kind[i]]
		if left[0] == 0 or left[1] == 0:
			break
	var a := 1 if swap else 0
	var pct := [left[a] * 100 / total[a], left[1 - a] * 100 / total[1 - a]]
	return {"result": 1 if pct[0] > pct[1] else (-1 if pct[1] > pct[0] else 0), "n": [n[a], n[1 - a]], "left_pct": pct, "ticks": w.tick, "shots": shots, "missed": missed}


static func _rank(slot: String) -> int:
	return ["large", "ram", "unique", "scout", "infantry", "spear", "skirmisher", "mounted_archer", "archer", "bolt_thrower", "catapult"].find(slot)
