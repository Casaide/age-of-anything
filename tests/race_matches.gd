extends SceneTree
## Milestone 14's balance check: a round robin of whole bot-vs-bot matches between races, each
## with its bonuses, own research, lacks and ability on; both seatings of every pair. Prints each
## race's wins, how long the matches ran, and what the bots did with their identity (webs thrown,
## own research bought). Each match is one process, side by side (tests/par.gd).
## Run: godot --headless --path . --script res://tests/race_matches.gd [-- map_id [prompt ...]] [jobs=N]
##   (one match: ... -- match <map_id> "<prompt A>" "<prompt B>")

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")
const Tech := preload("res://src/sim/tech.gd")
const Par := preload("res://tests/par.gd")

const SEED := 11
const LIMIT := 20 * 60 * 35   # 35 minutes, then a draw
const RACES := ["swamp frogs", "sewer rats", "imperial humans", "spooky spiders", "forest beetles", "steppe centaurs"]


func _init() -> void:
	var args := Par.plain(OS.get_cmdline_user_args())
	if not args.is_empty() and args[0] == "match":
		_one(args[1], args[2], args[3])
		quit()
		return
	var map_id: String = args[0] if not args.is_empty() else "reed_meadow"
	var races: Array = args.slice(1) if args.size() > 1 else RACES
	var jobs := []
	for a in races.size():
		for b in races.size():
			if a != b:
				jobs.append(Par.job("%s vs %s" % [races[a], races[b]], "res://tests/race_matches.gd", ["match", map_id, races[a], races[b]], 1, 1800))
	var results := Par.run(jobs, Par.jobs_wanted(OS.get_cmdline_user_args()))
	var wins := {}
	var played := {}
	var draws := 0
	var minutes := []
	print("\n== matches (%s)" % map_id)
	for r in results:
		var s: Dictionary = r.stats.get("match", {})
		if s.is_empty():
			print("  %-40s  no result (%s)" % [r.name, Par.summary(r)])
			continue
		for p in s.races:
			played[p] = int(played.get(p, 0)) + 1
		if int(s.winner) >= 0:
			wins[s.races[int(s.winner)]] = int(wins.get(s.races[int(s.winner)], 0)) + 1
		else:
			draws += 1
		minutes.append(int(s.tick) / 1200)
		print("  %-40s  %s at %d:%02d   webs %s   own research %s" % [r.name, "draw" if int(s.winner) < 0 else s.races[int(s.winner)] + " wins",
			int(s.tick) / 1200, int(s.tick) / 20 % 60, s.webs, s.own])
	print("\n== win rates")
	for p in races:
		var n: int = played.get(p, 0)
		print("  %-20s %2d / %2d  (%d%%)" % [p, wins.get(p, 0), n, 100 * int(wins.get(p, 0)) / maxi(1, n)])
	minutes.sort()
	print("draws %d; minutes %s" % [draws, minutes])
	quit()


func _one(map_id: String, pa: String, pb: String) -> void:
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := [gen.generate(pa, rules), gen.generate(pb, rules)]
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	var bots := [Bot.new(0), Bot.new(1)]
	var webs := [0, 0]
	var own := [[], []]
	while w.tick < LIMIT and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "ability":
				webs[e.player] += 1
			elif e.type == "research" and e.player < 2 and e.id in w.ident[e.player].research:
				own[e.player].append("%s %d:%02d" % [e.id, w.tick / 1200, w.tick / 20 % 60])
	print("@@ match %s" % JSON.stringify({"races": [pa, pb], "winner": w.winner, "tick": w.tick, "webs": webs, "own": own}))
