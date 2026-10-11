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
const LIMIT := 20 * 60 * 18    # 18 minutes

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

	# Milestone 9 exit check: whole matches run 9-12 minutes (median over a few pairings).
	var centaurs: Dictionary = gen.generate("centaur romans", rules)
	var lengths := [a.tick]
	for pair in [[centaurs, frogs], [rats, centaurs]]:
		var r := _play(rules, pair, [Bot.new(0), Bot.new(1)], "bot %s vs bot %s" % [pair[0].name, pair[1].name])
		check(r.winner >= 0, "%s vs %s ends with a winner" % [pair[0].name, pair[1].name])
		lengths.append(r.tick)
	lengths.sort()
	check(lengths[1] >= 9 * 1200 and lengths[1] <= 12 * 1200, "bot matches run 9-12 minutes (median %s; %s)" % [_clock(lengths[1]), lengths.map(_clock)])

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
	while w.tick < LIMIT and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		if w.tick % 1200 == 0 and not quiet:
			var line := _clock(w.tick)
			for p in races.size():
				var army := 0
				var workers := 0
				for i in w.units.count():
					if w.units.owner[i] == p:
						if w.types[w.units.kind[i]].worker:
							workers += 1
						else:
							army += 1
				var blds := 0
				for k in w.buildings.count():
					if w.buildings.owner[k] == p:
						blds += 1
				line += "   P%d age %d, %d workers, %d soldiers, %d buildings, %d lost" % [p, w.ages[p], workers, army, blds, w.lost[p]]
			print(line)
	if not quiet:
		print("winner: team %d at %s" % [w.winner, _clock(w.tick)])
	return {"winner": w.winner, "tick": w.tick, "hashes": w.hashes}


func _clock(tick: int) -> String:
	return "%d:%02d" % [tick / 1200, tick / 20 % 60]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)
