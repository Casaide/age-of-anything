extends SceneTree
## Milestone 8 checks for the AI opponent (src/ai/bot.gd) and match flow (src/sim/match.gd):
## - the bot beats a passive player (one that only runs an economy) before time runs out;
## - two bots play a whole match, deterministically (same seed, same winner and hashes);
## - surrendering ends the match.
## Prints a minute-by-minute timeline of each match.
## Run: godot --headless --path . --script res://tests/test_ai.gd   (a minute or two)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Commands := preload("res://src/sim/commands.gd")
const Bot := preload("res://src/ai/bot.gd")
const EcoBot := preload("res://src/ai/eco_bot.gd")

const SEED := 7
const LIMIT := 20 * 60 * 30    # 30 minutes: a match must end, however slowly (pacing is a tester metric)

var failures := 0
var checks := 0


func _init() -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var frogs: Dictionary = gen.generate("angry swamp frogs with reed spears", rules)
	var rats: Dictionary = gen.generate("sewer rats with cheese hammers", rules)

	for pair in [[frogs, rats], [rats, frogs]]:
		var r := _play(rules, pair, [Bot.new(0), EcoBot.new(1)], "bot %s vs passive %s" % [pair[0].name, pair[1].name])
		check(r.winner == 0, "the bot beats a passive %s (winner %d at %s)" % [pair[1].name, r.winner, _clock(r.tick)])

	var a := _play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot")
	var b := _play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot, again", true)
	check(a.hashes == b.hashes and a.winner == b.winner, "bot vs bot is deterministic")
	check(a.winner >= 0, "bot vs bot ends with a winner (%d at %s)" % [a.winner, _clock(a.tick)])

	# Whole matches end: no stalemates between bots, whatever the races.
	var centaurs: Dictionary = gen.generate("centaur romans", rules)
	var lengths := [a.tick]
	for pair in [[centaurs, frogs], [rats, centaurs]]:
		var r := _play(rules, pair, [Bot.new(0), Bot.new(1)], "bot %s vs bot %s" % [pair[0].name, pair[1].name])
		check(r.winner >= 0, "%s vs %s ends with a winner" % [pair[0].name, pair[1].name])
		lengths.append(r.tick)
	lengths.sort()
	# Pacing is a tester metric (milestone 10); bot vs bot is a guide, so it's reported, not
	# enforced. It was 10:50 before workers got one price, about 12 minutes after.
	print("\nbot match lengths %s, median %s (target for players: 9-12 minutes)" % [lengths.map(_clock), _clock(lengths[1])])

	_test_easy(rules, rats, frogs)
	var hard := _play(rules, [rats, frogs], [Bot.new(0, {}, "hard"), Bot.new(1)], "hard bot %s vs normal bot %s" % [rats.name, frogs.name])
	check(hard.winner == 0, "hard beats normal (winner %d at %s)" % [hard.winner, _clock(hard.tick)])

	var w := World.new(SEED, SimMap.load_id("flat_test"), [frogs, rats], rules)
	w.issue(1, Commands.SURRENDER, {})
	for k in 40:
		w.step()
	check(w.defeated[1] > 0 and w.winner == 0, "surrendering ends the match")

	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _play(rules: Dictionary, races: Array, bots: Array, title: String, quiet := false) -> Dictionary:
	var w := World.new(SEED, SimMap.load_id("flat_test"), races, rules)
	if not quiet:
		print("\n== ", title)
	var aged := [-1, -1]   # when each side reached age 2 (the bots aim for 4-6 minutes)
	while w.tick < LIMIT and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		for p in 2:
			if aged[p] < 0 and w.ages[p] >= 2:
				aged[p] = w.tick
		if w.tick % 1200 == 0 and not quiet:
			var line := _clock(w.tick)
			for p in races.size():
				var army := 0
				var workers := 0
				for i in w.units.count():
					if w.units.owner[i] == p:
						if w.types[w.units.kind[i]].worker:
							workers += 1
						elif not w.types[w.units.kind[i]].has("animal"):
							army += 1
				var blds := 0
				for k in w.buildings.count():
					if w.buildings.owner[k] == p:
						blds += 1
				line += "   P%d age %d, %d workers, %d soldiers, %d buildings, %d lost" % [p, w.ages[p], workers, army, blds, w.lost[p]]
			print(line)
	if not quiet:
		print("winner: team %d at %s; age 2 at %s" % [w.winner, _clock(w.tick), aged.map(func(t): return _clock(t) if t >= 0 else "-")])
	return {"winner": w.winner, "tick": w.tick, "hashes": w.hashes}


## Easy against a passive player: a small army (its cap and a training queue's worth), and the
## first loss no earlier than its first wave (Dominic: Easy wiped him out in age 2).
func _test_easy(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id("flat_test"), [a, b], rules)
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
			if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker:
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


func _clock(tick: int) -> String:
	return "%d:%02d" % [tick / 1200, tick / 20 % 60]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)
