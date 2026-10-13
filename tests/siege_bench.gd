extends SceneTree
## The siege tick budget (milestone 16, step 1): a scripted big siege on flat_test, no bots. The
## rats sit in a stone ring (gates and wall towers) round their Town Center with an army inside
## (archers and skirmishers on the walkways when there are walkways), the Romans march on it with
## rams, catapults, a siege tower or two and a big army, attack-moving on the Town Center every
## 20 s while the rams go for the gates. Prints per system the average and worst, the tick's
## average, p99 and worst, how many units were alive (most, and at the end) and the final hash.
## Run: godot --headless --path . --script res://tests/siege_bench.gd -- [units per side] [minutes]
## (default 200 a side, 4 minutes: the 400-unit siege the milestone measures).

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const Tech := preload("res://src/sim/tech.gd")
const Animals := preload("res://src/sim/animals.gd")
const Combat := preload("res://src/sim/combat.gd")
const Heal := preload("res://src/sim/heal.gd")
const Garrison := preload("res://src/sim/garrison.gd")
const Match := preload("res://src/sim/match.gd")
const Fog := preload("res://src/sim/fog.gd")
const Trails := preload("res://src/sim/trails.gd")
const Fortify := preload("res://src/sim/fortify.gd")
const Walls := preload("res://src/sim/walls.gd")
const Repair := preload("res://src/sim/repair.gd")
const Trade := preload("res://src/sim/trade.gd")
const Abilities := preload("res://src/sim/abilities.gd")
const Fixed := preload("res://src/sim/fixed.gd")

const SEED := 20261016
const NAMES := ["commands", "train+tech", "work", "garrison", "walls", "animals", "spatial", "heal", "combat",
	"match", "fog", "trails", "next_orders", "sync_map", "solve", "move", "separate", "hash"]
## The defenders' mix (rats) and the attackers' (Romans), as parts of the side's count. Engines
## count 2 each against the side's count (they're pop 2).
const DEFEND := {"archer": 30, "skirmisher": 20, "spear": 20, "infantry": 15, "large": 10, "healer": 5}
const ATTACK := {"infantry": 25, "spear": 20, "archer": 20, "skirmisher": 10, "large": 15, "ram": 4, "catapult": 3, "siege_tower": 3}

var w: World


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var per_side := int(args[0]) if args.size() > 0 else 200
	var minutes := int(args[1]) if args.size() > 1 else 4
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules: Dictionary = DataLib.load_json("res://data/rules/default.json")
	rules.animals = false
	var races := [gen.generate("sewer rats with cheese hammers", rules), gen.generate("roman legion", rules)]
	var m: SimMap = SimMap.load_id("flat_test")
	w = World.new(SEED, m, races, rules)
	for p in 2:   # both in age 3: the engines and the walls are there
		w.ages[p] = 3
		Tech.retype(w, p)
		Tech.refresh(w, p)
	var home: Array = m.starts[0]
	var cx: int = home[0] / SimMap.TILE
	var cy: int = home[1] / SimMap.TILE
	var spec := {"wall": "wall", "gate": "stone_gate", "tower": "wall_tower" if Economy.btype_of(w, "wall_tower") >= 0 else "",
		"tower_every": 6, "gates": ["n", "e", "s", "w"]}
	var ring := Fortify.ring(w, 0, cx, cy, 9, spec)
	print("ring: %d pieces round (%d, %d)" % [ring.size(), cx, cy])
	var seq := [0, 0]
	var cmd := func(turn: int, p: int, type: String, a: Dictionary) -> void:
		w.commands.add({"turn": turn, "player": p, "seq": seq[p], "type": type, "args": a})
		seq[p] += 1
	_spawn(cmd, 0, DEFEND, per_side, home[0], home[1])
	var far: Array = m.starts[1]
	var camp := [far[0] - 18000, far[1] - 18000]   # the Romans' camp, out beyond the ring's south-east
	_spawn(cmd, 1, ATTACK, per_side, camp[0], camp[1])
	var t := PackedInt64Array()
	t.resize(NAMES.size())
	var worst := PackedInt64Array()
	worst.resize(NAMES.size())
	var ticks := PackedInt64Array()
	var max_units := 0
	var heavy_sum := 0   # ticks with 300 or more units about: the budget's own average
	var heavy_n := 0
	while w.tick < minutes * 1200 and w.winner < 0:
		if w.tick == 40:
			_man_walls(cmd)
		if w.tick >= 60 and w.tick % 400 == 0:
			_assault(cmd, home)
		var marks := PackedInt64Array()
		marks.append(Time.get_ticks_usec())
		w.units.save_prev()
		w.events.clear()
		if w.tick % Commands.TICKS_PER_TURN == 0:
			for c in w.commands.take(w.turn()):
				w._run(c)
				w.history.append(c)
		marks.append(Time.get_ticks_usec())
		Economy.train(w)
		Tech.tick(w)
		marks.append(Time.get_ticks_usec())
		Economy.work(w)
		Trade.tick(w)
		w._pack()
		Repair.tick(w)
		marks.append(Time.get_ticks_usec())
		Garrison.tick(w)
		marks.append(Time.get_ticks_usec())
		Walls.tick(w)
		marks.append(Time.get_ticks_usec())
		Animals.tick(w)
		marks.append(Time.get_ticks_usec())
		w.spatial.build(w.units.x, w.units.y)
		var alive: int = w.units.changes
		marks.append(Time.get_ticks_usec())
		Heal.tick(w)
		marks.append(Time.get_ticks_usec())
		Combat.tick(w)
		marks.append(Time.get_ticks_usec())
		Match.tick(w)
		marks.append(Time.get_ticks_usec())
		Fog.tick(w)
		marks.append(Time.get_ticks_usec())
		Trails.tick(w)
		Abilities.tick(w)
		if w.units.changes != alive:
			w.spatial.build(w.units.x, w.units.y)
		marks.append(Time.get_ticks_usec())
		w._next_orders()
		marks.append(Time.get_ticks_usec())
		w._sync_map()
		marks.append(Time.get_ticks_usec())
		w._solve_queued()
		marks.append(Time.get_ticks_usec())
		w._move()
		marks.append(Time.get_ticks_usec())
		w.spatial.build(w.units.x, w.units.y)
		w._separate()
		marks.append(Time.get_ticks_usec())
		w.tick += 1
		if w.tick % World.HASH_EVERY == 0:
			w.hashes.append([w.tick, w.state_hash()])
		marks.append(Time.get_ticks_usec())
		for k in NAMES.size():
			var d: int = marks[k + 1] - marks[k]
			t[k] += d
			worst[k] = maxi(worst[k], d)
		ticks.append(marks[NAMES.size()] - marks[0])
		if w.units.count() >= 300:
			heavy_sum += ticks[-1]
			heavy_n += 1
		max_units = maxi(max_units, w.units.count() + _inside())
		if w.tick % 1200 == 0:
			var up := 0
			for i in w.units.count():
				if w.units.perch[i] != 0:
					up += 1
			print("  on the walls: %d" % up)
			var hits := 0
			var ax := 0
			var ay := 0
			var na := 0
			for i in w.units.count():
				if w.units.owner[i] == 1:
					ax += w.units.x[i] / 1000
					ay += w.units.y[i] / 1000
					na += 1
			print("  attackers %d about (%d, %d); hp of the ring %d" % [na, ax / maxi(1, na), ay / maxi(1, na), _ring_hp(ring)])
			print("  %d:00  units %d (+%d sheltering), ring pieces standing %d" % [w.tick / 1200, w.units.count(), _inside(), _standing(ring)])
	var sum := 0
	for k in NAMES.size():
		sum += t[k]
		print("%-12s avg %.3f ms  worst %5.1f ms" % [NAMES[k], t[k] / 1000.0 / w.tick, worst[k] / 1000.0])
	var sorted := ticks.duplicate()
	sorted.sort()
	print("siege %d a side, %d ticks (%d:%02d), most units %d, at the end %d, winner %d" % [per_side, w.tick, w.tick / 1200, w.tick / 20 % 60, max_units, w.units.count(), w.winner])
	print("tick: avg %.3f ms  p99 %.2f ms  worst %.1f ms; final hash %d" % [sum / 1000.0 / w.tick, sorted[sorted.size() * 99 / 100] / 1000.0, sorted[-1] / 1000.0, w.state_hash()])
	print("ticks with 300+ units: %d, avg %.3f ms" % [heavy_n, heavy_sum / 1000.0 / maxi(1, heavy_n)])
	quit(0)


## The side's army: each slot's share of `count`, engines counting their pop.
func _spawn(cmd: Callable, p: int, mix: Dictionary, count: int, x: int, y: int) -> void:
	var total := 0
	for k in mix:
		total += mix[k]
	for slot in mix:
		var k: int = w.type_of(p, slot)
		if k < 0:
			continue
		var n: int = count * mix[slot] / total / maxi(1, int(w.types[k].pop))
		var lo := 0
		while lo < n:   # in batches of 20 (spawns jitter round their point)
			cmd.call(0, p, Commands.SPAWN, {"slot": slot, "count": mini(20, n - lo), "x": x + (lo % 60) * 40, "y": y + (lo % 60) * 30})
			lo += 20


## The defenders' shooters onto the walls round the east and south gates.
func _man_walls(cmd: Callable) -> void:
	var ids := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].slot in ["archer", "skirmisher"]:
			ids.append(w.units.id[i])
	var home: Array = w.map.starts[0]
	var spots := [[9, -4], [9, 4], [-4, 9], [4, 9], [9, 0]]   # the east and south walls, either side of their gates
	for k in spots.size():
		var part := ids.filter(func(id): return id % spots.size() == k)
		var x: int = home[0] + spots[k][0] * 1000
		var y: int = home[1] + spots[k][1] * 1000
		if not part.is_empty():
			cmd.call(w.turn(), 0, Commands.MOVE, {"ids": part, "x": x, "y": y})


## Every 20 s: the rams go for the east gate (once it's down, the ring piece nearest the gap);
## the army attack-moves up to the gate, and once it's open, on the Town Center.
func _assault(cmd: Callable, home: Array) -> void:
	var army := []
	var rams := []
	for i in w.units.count():
		if w.units.owner[i] != 1:
			continue
		if w.types[w.units.kind[i]].slot == "ram":
			rams.append(w.units.id[i])
		else:
			army.append(w.units.id[i])
	var turn: int = w.turn() + 1
	var east: int = w.map.occupied[(home[1] / 1000) * w.map.width + home[0] / 1000 + 9]
	var open: bool = east == 0 or w.buildings.index_of(east) < 0
	var target := 0
	if not open:
		target = east
	else:   # the nearest piece of the ring still standing, to widen the way in
		var best := 1 << 62
		var bs = w.buildings
		for b in bs.count():
			if bs.owner[b] == 0 and bs.sx[b] * bs.sy[b] <= 3:
				var d: int = Fixed.dist2(bs.cx[b] * 1000, bs.cy[b] * 1000, home[0] + 9000, home[1])
				if d < best:
					best = d
					target = bs.id[b]
	if not rams.is_empty() and target != 0:
		cmd.call(turn, 1, Commands.ATTACK, {"ids": rams, "target": target})
	if not army.is_empty():   # up to the east gate, and once it's open, on the Town Center
		cmd.call(turn, 1, Commands.ATTACK_MOVE, {"ids": army, "x": home[0] + (0 if open else 12000), "y": home[1]})


func _inside() -> int:
	var n := 0
	for b in w.buildings.count():
		n += w.buildings.inside[b].size()
	return n


func _standing(ids: Array) -> int:
	var n := 0
	for id in ids:
		if w.buildings.index_of(id) >= 0:
			n += 1
	return n


func _ring_hp(ids: Array) -> int:
	var n := 0
	for id in ids:
		var b: int = w.buildings.index_of(id)
		if b >= 0:
			n += w.buildings.hp[b]
	return n
