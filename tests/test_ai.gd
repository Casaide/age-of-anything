extends SceneTree
## Milestone 8 checks for the AI opponent (src/ai/bot.gd) and match flow (src/sim/match.gd):
## - the bot beats a passive player (one that only runs an economy) before time runs out;
## - two bots play a whole match, deterministically (same seed, same winner and hashes);
## - surrendering ends the match.
## Prints a minute-by-minute timeline of each match.
## Run: godot --headless --path . --script res://tests/test_ai.gd [-- <map_id>]   (a minute or two; flat_test by default)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Bot := preload("res://src/ai/bot.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")
const Economy := preload("res://src/sim/economy.gd")
const Bridges := preload("res://src/sim/bridges.gd")
const Reach := preload("res://src/ai/reach.gd")

const SEED := 7
const LIMIT := 20 * 60 * 30    # 30 minutes: a match must end, however slowly (pacing is a tester metric)

var failures := 0
var checks := 0
var map_id := "flat_test"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		map_id = args[0]
	print("map: ", map_id)
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var frogs: Dictionary = gen.generate("angry swamp frogs with reed spears", rules)
	var rats: Dictionary = gen.generate("sewer rats with cheese hammers", rules)
	if args.size() > 1 and args[1] == "reach":   # just the raid and walled-ford checks (a couple of minutes)
		_test_respond(rules, rats, frogs)
		_test_walled_fords(rules, frogs, rats)
		print("\n%d checks, %d failed" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return

	for pair in [[frogs, rats], [rats, frogs]]:
		var r := _play(rules, pair, [Bot.new(0), EcoBot.new(1)], "bot %s vs passive %s" % [pair[0].name, pair[1].name])
		check(r.winner == 0, "the bot beats a passive %s (winner %d at %s)" % [pair[1].name, r.winner, _clock(r.tick)])

	var a := _play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot")
	var b := _play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot, again", true)
	check(a.hashes == b.hashes and a.winner == b.winner, "bot vs bot is deterministic")
	check(a.winner >= 0, "bot vs bot ends with a winner (%d at %s)" % [a.winner, _clock(a.tick)])
	# Healers (Dominic, 2026-10-12): a couple from age 2, kept behind the army, and they heal.
	var m: Dictionary = a.medics
	check(m.most.max() >= 1 and m.most.max() <= 3, "the bots train a couple of healers (most %s)" % [m.most])
	check(m.samples == 0 or m.behind * 100 >= m.samples * 70, "healers keep behind the army (%d of %d looks)" % [m.behind, m.samples])

	# Whole matches end: no stalemates between bots, whatever the races.
	var centaurs: Dictionary = gen.generate("centaur romans", rules)
	var lengths := [a.tick]
	var heals: int = a.medics.heals[0] + a.medics.heals[1]
	for pair in [[centaurs, frogs], [rats, centaurs]]:
		var r := _play(rules, pair, [Bot.new(0), Bot.new(1)], "bot %s vs bot %s" % [pair[0].name, pair[1].name])
		check(r.winner >= 0, "%s vs %s ends with a winner" % [pair[0].name, pair[1].name])
		lengths.append(r.tick)
		heals += r.medics.heals[0] + r.medics.heals[1]
	check(heals > 0, "the bots' healers heal someone in their matches (%d heals)" % heals)
	lengths.sort()
	# Pacing is a tester metric (milestone 10); bot vs bot is a guide, so it's reported, not
	# enforced. It was 10:50 before workers got one price, about 12 minutes after.
	print("\nbot match lengths %s, median %s (target for players: 9-12 minutes)" % [lengths.map(_clock), _clock(lengths[1])])

	_test_easy(rules, rats, frogs)
	var hard := _play(rules, [rats, frogs], [Bot.new(0, {}, "hard"), Bot.new(1)], "hard bot %s vs normal bot %s" % [rats.name, frogs.name])
	check(hard.winner == 0, "hard beats normal (winner %d at %s)" % [hard.winner, _clock(hard.tick)])

	_test_respond(rules, rats, frogs)
	_test_walled_fords(rules, frogs, rats)

	var w := World.new(SEED, SimMap.load_id(map_id), [frogs, rats], rules)
	w.issue(1, Commands.SURRENDER, {})
	for k in 40:
		w.step()
	check(w.defeated[1] > 0 and w.winner == 0, "surrendering ends the match")

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _play(rules: Dictionary, races: Array, bots: Array, title: String, quiet := false) -> Dictionary:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	if not quiet:
		print("\n== ", title)
	var aged := [-1, -1]   # when each side reached age 2 (the bots aim for 4-6 minutes)
	var bought := [[], []]   # the research each side finished, with the time
	var medics := {"most": [0, 0], "heals": [0, 0], "behind": 0, "samples": 0}   # healers: how many, heals, kept behind the army
	while w.tick < LIMIT and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "research" and e.player < 2:
				bought[e.player].append("%s %s" % [e.id, _clock(w.tick)])
			elif e.type == "heal":
				var hi: int = w.units.index_of(e.by)
				if hi >= 0:
					medics.heals[w.units.owner[hi]] += 1
		if w.tick % 100 == 0:
			_watch_healers(w, medics)
		for p in 2:
			if aged[p] < 0 and w.ages[p] >= 2:
				aged[p] = w.tick
		if w.tick % 1200 == 0 and not quiet:
			var line := _clock(w.tick)
			for p in races.size():
				var army := 0
				var workers := 0
				var healers := 0
				for i in w.units.count():
					if w.units.owner[i] == p:
						if w.types[w.units.kind[i]].worker:
							workers += 1
						elif w.types[w.units.kind[i]].healer:
							healers += 1
						elif not w.types[w.units.kind[i]].has("animal"):
							army += 1
				var blds := 0
				for k in w.buildings.count():
					if w.buildings.owner[k] == p:
						blds += 1
				line += "   P%d age %d, %d workers, %d soldiers, %d healers, %d buildings, %d lost" % [p, w.ages[p], workers, army, healers, blds, w.lost[p]]
			print(line)
	if not quiet:
		print("winner: team %d at %s; age 2 at %s" % [w.winner, _clock(w.tick), aged.map(func(t): return _clock(t) if t >= 0 else "-")])
		for p in 2:
			print("research P%d: %s" % [p, ", ".join(bought[p])])
		print("healers: most %s, heals %s, behind their army in %d of %d looks" % [medics.most, medics.heals, medics.behind, medics.samples])
	return {"winner": w.winner, "tick": w.tick, "hashes": w.hashes, "medics": medics}


## Healers: the most each side had, and whether they keep behind their army: when soldiers are
## out (3 or more over 10 tiles from home), the healers' middle is nearer home than theirs.
func _watch_healers(w: World, medics: Dictionary) -> void:
	for p in 2:
		var home: Array = w.map.starts[p]
		var n := [0, 0]
		var d := [0, 0]
		for i in w.units.count():
			var t: Dictionary = w.types[w.units.kind[i]]
			if w.units.owner[i] != p or t.worker or t.has("animal"):
				continue
			var k := 1 if t.healer else 0
			var dist := isqrt_tiles(w.units.x[i] - int(home[0]), w.units.y[i] - int(home[1]))
			if k == 1 or dist > 10:
				n[k] += 1
				d[k] += dist
		medics.most[p] = maxi(medics.most[p], n[1])
		if n[0] >= 3 and n[1] > 0:
			medics.samples += 1
			if d[1] / n[1] < d[0] / n[0]:
				medics.behind += 1


static func isqrt_tiles(dx: int, dy: int) -> int:
	return int(sqrt(float(dx) * dx + float(dy) * dy)) / 1000


## Easy against a passive player: a small army (its cap and a training queue's worth), and the
## first loss no earlier than its first wave (Dominic: Easy wiped him out in age 2).
func _test_easy(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bot := Bot.new(0, {}, "easy")
	var passive := EcoBot.new(1)
	var most := 0
	var first_loss := -1
	while w.tick < 20 * 60 * 14 and w.winner < 0:
		bot.think(w)
		passive.think(w)
		w.step()
		var army := 0
		for i in w.units.count():
			if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker and not w.types[w.units.kind[i]].healer:   # healers never fight
				army += int(w.types[w.units.kind[i]].pop)
		if w.tick <= 20 * 60 * 10:   # the first ten minutes, where Easy used to overrun a player reaching age 2
			most = maxi(most, army)
		for e in w.events:   # a loss to the bot (one of its units close by), not to a boar the passive side hunted
			if first_loss < 0 and e.type == "die" and e.owner == 1 and not e.building:
				for i in w.units.count():
					if w.units.owner[i] == 0 and absi(w.units.x[i] - e.x) + absi(w.units.y[i] - e.y) < 8000:
						first_loss = w.tick
						break
	print("\n== easy: most soldiers in the first 10 minutes %d (pop), first loss %s" % [most, _clock(first_loss) if first_loss >= 0 else "none"])
	check(most <= 25, "easy keeps a modest army for the first ten minutes (%d pop)" % most)
	check(first_loss < 0 or first_loss >= 20 * 60 * 8, "easy doesn't strike before 8 minutes (%s)" % _clock(first_loss))


## Raids anywhere get an answer (Dominic, 2026-10-13: "attacking any enemy builds doesn't
## trigger a response"). The bot's lone lumber camp far from home, a worker beside it, and a
## few enemy soldiers hacking at both: within seconds the bot sends soldiers there, pulls the
## worker away, and its soldiers come to blows with the raiders.
func _test_respond(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bot := Bot.new(1)
	while w.tick < 1200:   # a minute of its economy
		bot.think(w)
		w.step()
	var tc: int = bot.eco._town_center(w)
	var tx: int = w.buildings.cx[tc] + 1
	var ty: int = w.buildings.cy[tc] + 1
	var k := Economy.btype_of(w, "lumber_camp")
	var spot := Vector2i(-1, -1)   # 16-22 tiles out, somewhere its workers can walk to
	var rc := Reach.new()
	var ln: int = w.lane_base[1] + Economy.builder_class(w, 1)
	var home: int = rc.area_at(w, ln, tx * 1000 + 500, ty * 1000 + 500)
	for r in range(16, 23):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if spot.x < 0 and maxi(absi(dx), absi(dy)) == r and Economy.can_place(w, 1, k, tx + dx, ty + dy) \
						and rc.touches(w, ln, home, tx + dx, ty + dy, 2, 2):
					spot = Vector2i(tx + dx, ty + dy)
	check(spot.x >= 0, "respond: room for a lone camp")
	var camp := Economy.place(w, 1, k, spot.x, spot.y)
	w.buildings.done[camp] = 1
	w.buildings.hp[camp] = w.bmods[1][k].hp
	var camp_id: int = w.buildings.id[camp]
	var cx := spot.x * 1000 + 1000
	var cy := spot.y * 1000 + 1000
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 4, "x": tx * 1000 + 500, "y": ty * 1000 + 3500})   # a home guard
	w.issue(1, Commands.SPAWN, {"slot": "worker", "count": 1, "x": cx + 2000, "y": cy})
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 3, "x": cx - 2500, "y": cy})
	for t in 12:
		bot.think(w)
		w.step()
	var raiders := []
	var worker := -1
	for i in w.units.count():
		if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker and absi(w.units.x[i] - cx) < 5000 and absi(w.units.y[i] - cy) < 5000:
			raiders.append(w.units.id[i])
		if w.units.owner[i] == 1 and w.types[w.units.kind[i]].worker and absi(w.units.x[i] - cx - 2000) < 1500 and absi(w.units.y[i] - cy) < 1500:
			worker = w.units.id[i]
	check(raiders.size() == 3 and worker > 0, "respond: three raiders by the camp, a worker beside it")
	w.issue(0, Commands.ATTACK, {"ids": raiders.slice(0, 2), "target": camp_id})
	w.issue(0, Commands.ATTACK, {"ids": raiders.slice(2), "target": worker})
	var first_hit := -1
	var sent := -1
	var pulled := -1
	var blows := 0
	var seen := w.history.size()
	while w.tick < 1200 + 20 * 60:
		bot.think(w)
		w.step()
		for e in w.events:
			if e.type != "hit":
				continue
			if first_hit < 0 and e.by in raiders:
				first_hit = w.tick
			if e.to in raiders:
				var bi: int = w.units.index_of(e.by)
				if bi >= 0 and w.units.owner[bi] == 1:
					blows += 1
		for n in range(seen, w.history.size()):
			var cmd: Dictionary = w.history[n]
			if cmd.player != 1:
				continue
			if sent < 0 and cmd.type == Commands.ATTACK_MOVE and absi(int(cmd.args.x) - cx) < 6000 and absi(int(cmd.args.y) - cy) < 6000:
				sent = w.tick
			if pulled < 0 and cmd.type == Commands.MOVE and worker in cmd.args.ids:
				pulled = w.tick
		seen = w.history.size()
		if blows > 0 and sent >= 0 and pulled >= 0:
			break
	print("\n== respond: first blow %s, soldiers sent %s, worker pulled back %s, blows on the raiders %d" % [
		_clock(first_hit), _clock(sent) if sent >= 0 else "never", _clock(pulled) if pulled >= 0 else "never", blows])
	check(first_hit >= 0 and sent >= 0 and sent - first_hit <= 100, "respond: soldiers are sent to a raided camp within 5 s (%d ticks)" % (sent - first_hit))
	check(pulled >= 0 and pulled - first_hit <= 100, "respond: the worker by it is pulled back within 5 s")
	check(blows > 0, "respond: the bot's soldiers fight the raiders")


## Walled-off fords (Dominic, 2026-10-13: "enemy had 10 builders just stuck waiting for nothing
## because I had blocked off the river fords"). On a river map, the passive side's walls on every
## ford and the bridge down: the bot's half is cut off. Its workers keep working (never
## queueing for spots they can't reach), it builds and ages on its own side, and its army goes
## for the walls (the only thing of the enemy's it can reach) rather than standing about.
func _test_walled_fords(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var m := SimMap.load_id(map_id)
	if m.terrain_ids.find("ford") < 0 or not m.terrain.has(m.terrain_ids.find("ford")):
		print("\n== walled fords: %s has no fords, skipped" % map_id)
		return
	var w := World.new(SEED, m, [a, b], rules)
	var ford: int = w.map.terrain_ids.find("ford")
	var wk := Economy.btype_of(w, "wall")
	var walls := 0
	for c in w.map.width * w.map.height:
		if w.map.terrain[c] == ford and w.map.occupied[c] == 0:
			var bi := Economy.place(w, 0, wk, c % w.map.width, c / w.map.width)
			w.buildings.done[bi] = 1
			w.buildings.hp[bi] = w.bmods[0][wk].hp
			walls += 1
	for k in w.bridge_id.size():
		Bridges.hurt(w, k, 1 << 20)
	var bot := Bot.new(1)
	var passive := EcoBot.new(0)
	var reach := Reach.new()
	var ln: int = w.lane_base[1] + Economy.builder_class(w, 1)
	var s0: Array = w.map.starts[0]
	var s1: Array = w.map.starts[1]
	var cut: bool = reach.area_at(w, ln, s0[0], s0[1]) != reach.area_at(w, ln, s1[0], s1[1])
	check(cut, "walled fords: %d walls and the bridge down cut the bot (%s, movement class %d) off" % [walls, b.name, Economy.builder_class(w, 1)])
	# A barracks foundation the bot laid over the river before the walls went up: cut off now.
	var bk := Economy.btype_of(w, "barracks")
	var far := -1
	for r in range(6, 14):
		for d in [Vector2i(r, 0), Vector2i(0, r), Vector2i(r, r)]:
			if far < 0 and Economy.can_place(w, 1, bk, s0[0] / 1000 + d.x, s0[1] / 1000 + d.y):
				far = Economy.place(w, 1, bk, s0[0] / 1000 + d.x, s0[1] / 1000 + d.y)
	var far_id: int = w.buildings.id[far]
	var stranded := 0   # 5 s looks at bot workers sent to that foundation
	var idle_for := {}   # bot worker id -> 5 s looks in a row it stood idle
	var worst := 0
	var idle_looks := 0
	var looks := 0
	var cut_off := 0
	var wall_hits := 0
	while w.tick < 20 * 60 * 12 and w.winner < 0:
		bot.think(w)
		passive.think(w)
		w.step()
		for e in w.events:
			if e.type == "hit":
				var tb: int = w.buildings.index_of(e.to)
				if tb >= 0 and w.buildings.kind[tb] == wk and w.buildings.owner[tb] == 0:
					wall_hits += 1
		if w.tick % 100 != 0 or w.tick < 1200:
			continue
		var home: int = reach.area_at(w, ln, s1[0], s1[1])
		for i in w.units.count():
			if w.units.owner[i] != 1 or not w.types[w.units.kind[i]].worker:
				continue
			var id: int = w.units.id[i]
			looks += 1
			var idle: bool = w.units.task[i] == 0 and w.units.moving[i] == 0 and w.units.foe[i] == 0
			if w.units.task[i] == 3 and w.units.target[i] == far_id:
				stranded += 1
			idle_for[id] = int(idle_for.get(id, 0)) + 1 if idle else 0
			worst = maxi(worst, idle_for[id])
			if idle:
				idle_looks += 1
		for bi in w.buildings.count():
			if w.buildings.id[bi] != far_id and w.buildings.owner[bi] == 1 and w.buildings.done[bi] == 0 and not reach.touches(w, ln, home, w.buildings.cx[bi], w.buildings.cy[bi], w.buildings.sx[bi], w.buildings.sy[bi]):
				cut_off += 1
	var workers := 0
	var blds := 0
	for i in w.units.count():
		if w.units.owner[i] == 1 and w.types[w.units.kind[i]].worker:
			workers += 1
	var barracks := 0
	for bi in w.buildings.count():
		if w.buildings.owner[bi] == 1:
			blds += 1
			if w.buildings.kind[bi] == bk and w.buildings.done[bi] == 1:
				barracks += 1
	print("\n== walled fords (%s): at %s the bot has %d workers, %d buildings, age %d; idle %d of %d worker looks, longest idle %d s; workers sent to the cut-off foundation %d looks; barracks built %d; new foundations it can't reach %d; blows on the walls %d" % [
		map_id, _clock(w.tick), workers, blds, w.ages[1], idle_looks, looks, worst * 5, stranded, barracks, cut_off, wall_hits])
	check(cut_off == 0, "walled fords: the bot lays no foundation it can't reach")
	check(stranded == 0, "walled fords: nobody is sent to the foundation over the river (%d looks)" % stranded)
	check(barracks >= 1, "walled fords: it builds a barracks on its own side instead")
	check(idle_looks * 100 <= looks * 5, "walled fords: its workers keep working (idle %d of %d looks)" % [idle_looks, looks])
	check(worst <= 4, "walled fords: no worker stands idle for long (longest %d s)" % (worst * 5))
	check(w.ages[1] >= 2 and workers >= 20, "walled fords: the bot grows on its own side (age %d, %d workers)" % [w.ages[1], workers])
	check(wall_hits > 0, "walled fords: its army goes for the walls")


func _clock(tick: int) -> String:
	return "%d:%02d" % [tick / 1200, tick / 20 % 60]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)
