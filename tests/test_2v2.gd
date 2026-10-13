extends SceneTree
## A 2v2 between four bots on a four-start map (milestone 15): the teams come from the map
## (`teams`: starts 0 and 2 against 1 and 3). Checks that it runs, that teammates never hit
## each other while the teams fight, and that the match ends; reports how long it took.
## Run: godot --headless --path . --script res://tests/test_2v2.gd [-- <map_id> [minutes]]   (a few minutes)

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const World := preload("res://src/sim/world.gd")
const Bot := preload("res://src/ai/bot.gd")

const SEED := 2026
const PROMPTS := ["angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans", "greek hoplites"]

var failures := 0
var checks := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "reed_meadow_2v2"
	var minutes := int(args[1]) if args.size() > 1 else 45
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_json("res://data/rules/default.json")
	var races := PROMPTS.map(func(p): return gen.generate(p, rules))
	var map: SimMap = SimMap.load_id(map_id)
	check(map.starts.size() == 4 and map.start_teams == [0, 1, 0, 1], "%s has four starts in two teams (%s)" % [map_id, map.start_teams])
	var w := World.new(SEED, map, races, rules, map.start_teams)
	var bots := []
	for p in 4:
		bots.append(Bot.new(p))
	var friendly := 0
	var splashed := 0
	var across := 0
	var kills := [0, 0]   # units each team killed
	var us := 0
	var worst := 0
	print("2v2 on %s: %s" % [map_id, ", ".join(range(4).map(func(p): return "P%d %s (team %d)" % [p, races[p].name, w.teams[p]]))])
	while w.tick < minutes * 1200 and w.winner < 0:
		for b in bots:
			b.think(w)
		var t0 := Time.get_ticks_usec()
		w.step()
		var dt := Time.get_ticks_usec() - t0
		us += dt
		worst = maxi(worst, dt)
		for e in w.events:
			if e.type == "hit":
				var a := _team_of(w, e.by)
				var b := _team_of(w, e.to)
				if a >= 0 and b >= 0:
					if a == b and e.get("splash", false):
						splashed += 1   # a catapult's stone hurts its own side too (rules splash_friend_pct)
					elif a == b:
						friendly += 1
					else:
						across += 1
			elif e.type == "die" and not e.building and e.owner >= 0 and e.owner < 4:
				kills[1 - w.teams[e.owner]] += 1
		if w.tick % (1200 * 5) == 0:
			var line := "  %s" % _clock(w.tick)
			for p in 4:
				var army := 0
				var workers := 0
				for i in w.units.count():
					if w.units.owner[i] == p:
						if w.types[w.units.kind[i]].worker:
							workers += 1
						else:
							army += 1
				line += "  | P%d age %d %dw %ds lost %d%s" % [p, w.ages[p], workers, army, w.lost[p], " OUT" if w.defeated[p] > 0 else ""]
			print(line)
	print("ended at %s, winner team %d; units killed by team 0: %d, by team 1: %d; hits across teams %d, between teammates %d; tick %.2f ms avg, %.1f worst" % [
		_clock(w.tick), w.winner, kills[0], kills[1], across, friendly, us / 1000.0 / maxi(1, w.tick), worst / 1000.0])
	check(friendly == 0, "teammates never strike each other, splash aside (%d blows; %d splashed)" % [friendly, splashed])
	check(across > 0 and kills[0] > 0 and kills[1] > 0, "the teams fight each other (%d hits)" % across)
	check(w.winner >= 0, "the 2v2 ends with a winner (team %d at %s)" % [w.winner, _clock(w.tick)])
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The team of a unit or building id (-1 for animals, bridges or the gone).
func _team_of(w, id: int) -> int:
	var i: int = w.units.index_of(id)
	if i >= 0:
		if w.units.owner[i] >= 4 or w.types[w.units.kind[i]].has("animal"):
			return -1   # wild, or a herd animal (slaughtering your own sheep is no fight)
		return w.teams[w.units.owner[i]]
	var b: int = w.buildings.index_of(id)
	return w.teams[w.buildings.owner[b]] if b >= 0 else -1


func _clock(tick: int) -> String:
	return "%d:%02d" % [tick / 1200, tick / 20 % 60]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)
