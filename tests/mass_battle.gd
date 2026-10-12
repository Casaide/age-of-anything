extends SceneTree
## Mass battles at equal cost: about 30 against 30, mixed armies, both sides attack-moving on an
## open map, every match fought twice with the sides swapped (so where they start doesn't decide
## it). For each race of the balance prompts, in one age (unit lines upgraded to it): archers
## against cavalry (the large slot), skirmishers and spears; spears and skirmishers against
## cavalry; spears with archers against spears with cavalry; a mixed army and spears with
## archers against all archers. Prints win rates and the value each side has left.
## Deterministic. Massed archers should be strong but counterable.
## Run: godot --headless --path . --script res://tests/mass_battle.gd [-- age [budget] [combat_rule=value ...]]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Tech := preload("res://src/sim/tech.gd")
const RoundRobin := preload("res://tests/round_robin.gd")

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
]
const LIMIT := 4000   # ticks (3:20)
const FRONT := [22000, 42000]   # x of each side's front line; the map is 64 tiles square
const MID_Y := 32000
const GAP := 900     # between bodies in the starting blocks


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var age := int(args[0]) if args.size() > 0 else 2
	var budget := int(args[1]) if args.size() > 1 else 1500
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	for arg in args.slice(2):
		rules.combat[arg.get_slice("=", 0)] = int(arg.get_slice("=", 1))
		print("trying combat.%s = %s" % [arg.get_slice("=", 0), arg.get_slice("=", 1)])
	var races := RACES.map(func(p): return gen.generate(p, rules))
	var t0 := Time.get_ticks_msec()
	print("Mass battles, age %d, budget %d a side, each fought both ways round" % [age, budget])
	for m in MATCHES:
		var wins := 0
		var losses := 0
		var left_a := 0
		var left_b := 0
		var fights := 0
		var rows := []
		for r in races:
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
		print("\n%-30s A wins %2d of %d (B %d)   value left: A %3d%%  B %3d%%" % [m[0], wins, fights, losses, left_a / fights, left_b / fights])
		for row in rows:
			print(row)
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
	return ["large", "spear", "skirmisher", "archer"].find(slot)
