extends SceneTree
## Milestone 8 checks for the AI opponent (src/ai/bot.gd) and match flow (src/sim/match.gd):
## - the bot beats a passive player (one that only runs an economy) before time runs out;
## - two bots play a whole match, deterministically (same seed, same winner and hashes);
## - surrendering ends the match.
## Prints a minute-by-minute timeline of each match.
## Run: godot --headless --path . --script res://tests/test_ai.gd [-- [map_id] [quick|slow|serial|piece:<name>|levels|age3|reach|walls|rams|pick|land|hills] [jobs=N]]
## (flat_test by default; the pieces run side by side, one Godot process each; levels: each level left alone 30 minutes)

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
const Fixed := preload("res://src/sim/fixed.gd")
const Par := preload("res://tests/par.gd")
const Fortify := preload("res://src/sim/fortify.gd")
const Walls := preload("res://src/sim/walls.gd")
const WallsAi := preload("res://src/ai/walls_ai.gd")
const Tech := preload("res://src/sim/tech.gd")

const SEED := 7
const LIMIT := 20 * 60 * 30    # 30 minutes: a match must end, however slowly (pacing is a tester metric)

## The pieces, each one process when run side by side: name -> [tier, rough seconds alone].
## Quick: scenario checks (a few minutes of sim each). Slow: whole bot-vs-bot matches.
const PIECES := {
	"pick": ["quick", 1], "wonder": ["quick", 5], "respond": ["quick", 5], "shelter": ["quick", 5],
	"walled_fords": ["quick", 5], "rams": ["quick", 10], "hills": ["quick", 5], "guard": ["quick", 30],
	"age3": ["quick", 40], "surrender": ["quick", 1], "easy": ["quick", 40], "siege_bot": ["quick", 60], "trade_bot": ["quick", 20], "walls_bot": ["quick", 20],
	"passive_frogs": ["slow", 120], "passive_rats": ["slow", 120], "bvb": ["slow", 200], "bvb_again": ["slow", 200],
	"centaurs_frogs": ["slow", 200], "rats_centaurs": ["slow", 200], "hard": ["slow", 200],
	"walled_palisade": ["slow", 200], "walled_wall": ["slow", 200], "walled_gap": ["slow", 200], "land": ["slow", 200], "siege_mode": ["slow", 120],
}
## The older single-purpose modes, as pieces.
const MODES := {
	"age3": ["age3"], "levels": ["levels_easy", "levels_normal", "levels_hard"], "rams": ["rams", "siege_bot"],
	"walls": ["rams", "walled_palisade", "walled_wall", "walled_gap", "walls_bot"], "pick": ["pick"], "hills": ["hills", "guard"],
	"land": ["land", "guard", "hills"], "reach": ["respond", "shelter", "walled_fords"],
}

var failures := 0
var checks := 0
var map_id := "flat_test"
var piece := ""
var stats := {}   # piece -> {key: value}, what the combined checks need (printed as "@@ key json")


## Run: test_ai.gd [-- [map_id] [mode] [jobs=N]]. Modes: none (every piece, side by side), quick,
## slow, serial (every piece in this process, one after another), piece:<name> (one piece), or
## one of MODES. Side by side, each piece's log is printed in order, then the combined checks.
func _init() -> void:
	var args := Par.plain(OS.get_cmdline_user_args())
	if args.size() > 0 and FileAccess.file_exists("res://data/maps/%s.json" % args[0]):
		map_id = args.pop_front()
	var mode: String = args[0] if args.size() > 0 else ""
	print("map: ", map_id)
	if mode.begins_with("piece:") or mode == "serial":
		var names: Array = [mode.trim_prefix("piece:")] if mode != "serial" else PIECES.keys()
		var t0 := Time.get_ticks_msec()
		_setup()
		for name in names:
			_run_piece(name)
		if mode == "serial":
			_combine(stats)
		print("\n(%d s)" % ((Time.get_ticks_msec() - t0) / 1000))
		print("\n%d checks, %d failed" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return
	var results := Par.run(jobs(mode, map_id), Par.jobs_wanted(OS.get_cmdline_user_args()))
	Par.print_logs(results)
	var all := {}
	for r in results:
		checks += maxi(0, r.checks)
		failures += maxi(0, r.failed) + (0 if Par.ok(r) or r.failed > 0 else 1)
		all[r.name.trim_prefix("ai/")] = r.stats
	_combine(all)
	print("\n== pieces")
	for r in results:
		print("  %-20s %6.1fs  %s" % [r.name, r.secs, Par.summary(r)])
		for f in r.fails:
			print("    ", f)
	print("\n%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The jobs for a mode ("" for every piece; quick; slow; one of MODES) on a map.
static func jobs(mode: String, map: String) -> Array:
	var names: Array
	if mode == "":
		names = PIECES.keys()
	elif mode == "quick" or mode == "slow":
		names = PIECES.keys().filter(func(k): return PIECES[k][0] == mode)
	else:
		assert(MODES.has(mode), "test_ai: unknown mode %s" % mode)
		names = MODES[mode]
	return names.map(func(k): return Par.job("ai/" + k, "res://tests/test_ai.gd", [map, "piece:" + k], PIECES.get(k, ["", 300])[1]))


var gen
var rules: Dictionary
var frogs: Dictionary
var rats: Dictionary


func _setup() -> void:
	gen = Generator.new(DataLib.new())
	rules = DataLib.load_json("res://data/rules/default.json")
	frogs = gen.generate("angry swamp frogs with reed spears", rules)
	rats = gen.generate("sewer rats with cheese hammers", rules)


func _run_piece(name: String) -> void:
	piece = name
	match name:
		"pick": _test_pick(rules, gen)
		"wonder": _test_wonder(rules, rats, frogs)
		"passive_frogs", "passive_rats":
			var pair := [frogs, rats] if name == "passive_frogs" else [rats, frogs]
			var r := _play(rules, pair, [Bot.new(0), EcoBot.new(1)], "bot %s vs passive %s" % [pair[0].name, pair[1].name])
			check(r.winner == 0, "the bot beats a passive %s (winner %d at %s)" % [pair[1].name, r.winner, _clock(r.tick)])
		"bvb":
			var a := _play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot")
			check(a.winner >= 0, "bot vs bot ends with a winner (%d at %s)" % [a.winner, _clock(a.tick)])
			# Healers (Dominic, 2026-10-12): a couple from age 2, kept behind the army, and they heal.
			var m: Dictionary = a.medics
			check(m.most.max() >= 1 and m.most.max() <= 3, "the bots train a couple of healers (most %s)" % [m.most])
			check(m.samples == 0 or m.behind * 100 >= m.samples * 70, "healers keep behind the army (%d of %d looks)" % [m.behind, m.samples])
			# Heroes (D-136): a bot with an economy fields more than one of its heroes (the side ground down
			# early may never afford one).
			var hs: Dictionary = a.heroes
			check(maxi(hs.kinds[0].size(), hs.kinds[1].size()) >= 2, "the bots field several of their heroes (%d, %d kinds; fell %s, revived %s)" % [hs.kinds[0].size(), hs.kinds[1].size(), hs.fell, hs.revived])
			_match_stats(a)
		"bvb_again":   # the same match again (in its own process when side by side): same hashes, same winner
			_match_stats(_play(rules, [frogs, rats], [Bot.new(0), Bot.new(1)], "bot vs bot, again", true))
		"centaurs_frogs", "rats_centaurs":
			# Whole matches end: no stalemates between bots, whatever the races.
			var centaurs: Dictionary = gen.generate("centaur romans", rules)
			var pair := [centaurs, frogs] if name == "centaurs_frogs" else [rats, centaurs]
			var r := _play(rules, pair, [Bot.new(0), Bot.new(1)], "bot %s vs bot %s" % [pair[0].name, pair[1].name])
			check(r.winner >= 0, "%s vs %s ends with a winner" % [pair[0].name, pair[1].name])
			_match_stats(r)
		"easy": _test_easy(rules, rats, frogs)
		"hard":
			var hard := _play(rules, [rats, frogs], [Bot.new(0, {}, "hard"), Bot.new(1)], "hard bot %s vs normal bot %s" % [rats.name, frogs.name])
			check(hard.winner == 0, "hard beats normal (winner %d at %s)" % [hard.winner, _clock(hard.tick)])
		"respond": _test_respond(rules, rats, frogs)
		"shelter": _test_shelter(rules, rats, frogs)
		"walled_fords": _test_walled_fords(rules, frogs, rats)
		"rams": _test_rams(rules, frogs)
		"siege_bot": _test_siege_bot(rules, rats, frogs)
		"trade_bot": _test_trade_bot(rules, frogs, rats)
		"walls_bot": _test_walls_bot(rules, rats, frogs)
		"siege_mode": _test_siege_mode(rules, frogs, rats)
		"walled_palisade": _test_walled_base(rules, frogs, rats, "palisade", false)
		"walled_wall": _test_walled_base(rules, frogs, rats, "wall", false)
		"walled_gap": _test_walled_base(rules, frogs, rats, "wall", true)
		"age3": _test_age_three(rules, frogs, rats)
		"land": _test_land(rules, frogs, rats)
		"guard": _test_guard(rules, frogs, rats)
		"hills": _test_hills(rules, frogs, rats)
		"levels_easy", "levels_normal", "levels_hard": _test_levels(rules, frogs, rats, [name.trim_prefix("levels_")])
		"surrender":
			var w := World.new(SEED, SimMap.load_id(map_id), [frogs, rats], rules)
			w.issue(1, Commands.SURRENDER, {})
			for k in 40:
				w.step()
			check(w.defeated[1] > 0 and w.winner == 0, "surrendering ends the match")
		_: assert(false, "test_ai: no piece %s" % name)


## What the combined checks need from a bot-vs-bot match.
func _match_stats(r: Dictionary) -> void:
	stat("winner", r.winner)
	stat("tick", r.tick)
	stat("hashes", [r.hashes.size(), str(r.hashes).hash()])
	stat("heals", r.medics.heals[0] + r.medics.heals[1])


func stat(key: String, value) -> void:
	if not stats.has(piece):
		stats[piece] = {}
	stats[piece][key] = value
	print("@@ %s %s" % [key, JSON.stringify(value)])


## The checks across pieces: the same match twice is the same; the bots' healers heal someone
## over their matches; the match lengths (reported).
func _combine(all: Dictionary) -> void:
	if all.has("bvb") and all.has("bvb_again"):
		var a: Dictionary = all.bvb
		var b: Dictionary = all.bvb_again
		check(a.hashes == b.hashes and a.winner == b.winner, "bot vs bot is deterministic")
	var matches := ["bvb", "centaurs_frogs", "rats_centaurs"]
	if matches.all(func(k): return all.has(k)):
		var heals := 0
		var lengths := []
		for k in matches:
			heals += int(all[k].heals)
			lengths.append(int(all[k].tick))
		check(heals > 0, "the bots' healers heal someone in their matches (%d heals)" % heals)
		lengths.sort()
		# Pacing is a tester metric (milestone 10); bot vs bot is a guide, so it's reported, not
		# enforced. It was 10:50 before workers got one price, about 12 minutes after.
		print("\nbot match lengths %s, median %s (target for players: 9-12 minutes)" % [lengths.map(_clock), _clock(lengths[1])])


func _play(rules: Dictionary, races: Array, bots: Array, title: String, quiet := false) -> Dictionary:
	var w := World.new(SEED, SimMap.load_id(map_id), races, rules)
	if not quiet:
		print("\n== ", title)
	var aged := [-1, -1]   # when each side reached age 2 (the bots aim for 4-6 minutes)
	var bought := [[], []]   # the research each side finished, with the time
	var medics := {"most": [0, 0], "heals": [0, 0], "behind": 0, "samples": 0}   # healers: how many, heals, kept behind the army
	var heroes := {"up": [0, 0], "revived": [0, 0], "fell": [0, 0], "kinds": [{}, {}]}   # heroes (D-136): trained, revived, fallen, which
	while w.tick < LIMIT and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "research" and e.player < 2:
				bought[e.player].append("%s %s" % [e.id, _clock(w.tick)])
			elif e.type == "hero_up" and e.player < 2:
				heroes["revived" if e.revived else "up"][e.player] += 1
				heroes.kinds[e.player][e.kind] = true
			elif e.type == "hero_fell" and e.player < 2:
				heroes.fell[e.player] += 1
			elif e.type == "heal":
				var hi: int = w.units.index_of(e.by)
				if hi >= 0:
					medics.heals[w.units.owner[hi]] += 1
		if w.tick % 100 == 0:
			_watch_healers(w, medics, bots)
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
		print("heroes: trained %s, fell %s, revived %s" % [heroes.up, heroes.fell, heroes.revived])
	return {"winner": w.winner, "tick": w.tick, "hashes": w.hashes, "medics": medics, "heroes": heroes}


## Healers: the most each side had, and whether they keep behind their army: when soldiers are
## out (3 or more over 10 tiles from home), the healers' middle is nearer home than theirs.
## Soldiers posted with far gatherers (a bot's escorts) aren't the army the healers follow.
func _watch_healers(w: World, medics: Dictionary, bots: Array) -> void:
	for p in 2:
		var home: Array = w.map.starts[p]
		var n := [0, 0]
		var d := [0, 0]
		for i in w.units.count():
			var t: Dictionary = w.types[w.units.kind[i]]
			if w.units.owner[i] != p or t.worker or t.has("animal"):
				continue
			if "expand" in bots[p] and bots[p].expand.escorts.has(w.units.id[i]):
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
	var home := Vector2i(int(w.map.starts[0][0]), int(w.map.starts[0][1]))
	var theirs := Vector2i(int(w.map.starts[1][0]), int(w.map.starts[1][1]))
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
		for e in w.events:   # a loss to the bot (one of its units close by), not to a boar the passive side hunted,
			# and on the passive side's half of the map: its food gatherers walk to the bushes by the
			# bot's Town Center once theirs run out (from about 5:00 on flat_test, new ones all the way
			# to 8:00) and the bot's home guard picks them off on its own side; that's defence, not a strike
			if first_loss < 0 and e.type == "die" and e.owner == 1 and not e.building and Fixed.dist2(e.x, e.y, theirs.x, theirs.y) < Fixed.dist2(e.x, e.y, home.x, home.y):
				for i in w.units.count():
					if w.units.owner[i] == 0 and absi(w.units.x[i] - e.x) + absi(w.units.y[i] - e.y) < 8000:
						first_loss = w.tick
						break
	print("\n== easy: most soldiers in the first 10 minutes %d (pop), first loss %s" % [most, _clock(first_loss) if first_loss >= 0 else "none"])
	check(most <= 25, "easy keeps a modest army for the first ten minutes (%d pop)" % most)
	check(first_loss < 0 or first_loss >= 20 * 60 * 8, "easy doesn't strike before 8 minutes (%s)" % _clock(first_loss))


## In age 3 the bot raises a University and a Castle and buys some of their research (milestone
## 12 phases 4-5). Bots rarely reach age 3 in a match yet (phase 8), so this one starts there
## with a full stock against a passive side, topped up each minute, for fifteen minutes.
func _test_age_three(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var cfg: Dictionary = Bot.load_config()
	for wv in cfg.military.waves:
		wv.at = 1 << 20   # building up: its waves would end the match first
	var bots := [Bot.new(0, cfg), EcoBot.new(1)]
	w.ages[0] = 3
	var done := {}
	var bought := []
	while w.tick < 20 * 900:
		if w.tick % 1200 == 0:
			for r in w.resources.size():
				w.stock[r][0] = maxi(w.stock[r][0], 3000)
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "research" and e.player == 0:
				bought.append(e.id)
	for k in w.buildings.count():
		if w.buildings.owner[k] == 0 and w.buildings.done[k] == 1:
			done[w.btypes[w.buildings.kind[k]].id] = true
	var theirs := bought.filter(func(id): return id in ["stonecutting", "lifting_frames", "slit_windows", "thick_walls", "siege_wrights", "war_drums", "creature_research", "culture_research"])
	var workers := 0
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].worker:
			workers += 1
	print("\n== age 3: %d workers, buildings %s; University/Castle research %s" % [workers, done.keys(), theirs])
	check(done.has("university") and done.has("castle"), "age 3: the bot builds a University and a Castle")
	check(theirs.size() >= 2, "age 3: ...and buys at least two of their research (%s)" % [theirs])


## Siege (milestone 13, step 8): a bot already in age 3 with resources to spare, against a passive
## side: once it has a Siege Workshop it keeps a few engines (data: military.siege.max), and its
## engines strike buildings (rams at gates, walls and towers; catapults at towers).
func _test_siege_bot(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var cfg: Dictionary = Bot.load_config()
	for wv in cfg.military.waves:
		wv.at = int(wv.at) + 600   # ten minutes to build up first (its first waves would otherwise end it)
	cfg.wonder = {}   # no Wonder: topped up to 2000 of everything it builds one and wins by it at 16:19 on Old Forest, before its first wave (16:00) has marched; it passed there only while a ram could be posted as an escort and wander out
	cfg.military.erase("hero")   # no heroes (D-136): its first top-ups went on three heroes and the engines came after its first wave had won
	var bots := [Bot.new(0, cfg), EcoBot.new(1)]
	var most: Dictionary = cfg.military.siege.max
	w.ages[0] = 3
	var peak := {}
	var blows := {}
	var engine_kinds := {}
	var rams_out := 0
	for slot in most:
		engine_kinds[w.type_of(0, slot)] = slot
	while w.tick < 20 * 1500 and w.winner < 0:
		if w.tick % 1200 == 0:
			for r in w.resources.size():
				w.stock[r][0] = maxi(w.stock[r][0], 2000)
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "hit" and w.buildings.index_of(e.to) >= 0:
				var i: int = w.units.index_of(e.by)
				if i >= 0 and engine_kinds.has(w.units.kind[i]):
					blows[engine_kinds[w.units.kind[i]]] = int(blows.get(engine_kinds[w.units.kind[i]], 0)) + 1
		if w.tick % 100 == 0:
			var n := {}
			for i in w.units.count():
				if engine_kinds.has(w.units.kind[i]):
					n[engine_kinds[w.units.kind[i]]] = int(n.get(engine_kinds[w.units.kind[i]], 0)) + 1
			for s in n:
				if not peak.has(s):
					print("  first %s at %s" % [s, _clock(w.tick)])
				peak[s] = maxi(int(peak.get(s, 0)), n[s])
	for i in w.units.count():
		if engine_kinds.has(w.units.kind[i]):
			print("  %s at %d,%d foe %d stance %d moving %d" % [engine_kinds[w.units.kind[i]], w.units.x[i] / 1000, w.units.y[i] / 1000, w.units.foe[i], w.units.stance[i], w.units.moving[i]])
			if engine_kinds[w.units.kind[i]] == "ram" and Fixed.dist2(w.units.x[i], w.units.y[i], w.map.starts[0][0], w.map.starts[0][1]) > 15000 * 15000:
				rams_out += 1
	var shop := -1
	for k in w.buildings.count():
		if w.buildings.owner[k] == 0 and w.btypes[w.buildings.kind[k]].id == "siege_workshop":
			shop = k
	print("\n== siege bot: winner %d at %s; workshop %s; most engines at once %s; blows on buildings by engines %s" % [w.winner, _clock(w.tick), shop >= 0, peak, blows])
	check(peak.size() >= 2, "siege: the bot fields engines once it has a workshop (%s)" % [peak])
	check(peak.keys().all(func(s): return peak[s] <= int(most[s])), "siege: ...a few, never more than its caps (%s of %s)" % [peak, most])
	check(int(blows.get("ram", 0)) > 0 or rams_out > 0, "siege: its rams go out to the enemy or strike buildings (%d out, blows %s)" % [rams_out, blows])


## Trade (milestone 13 step 8): a bot in age 2 with two markets of its own far enough apart trains
## a few trade carts (data: economy.carts) and keeps them on the route, and they bring gold home;
## they never join its army.
func _test_trade_bot(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var cfg: Dictionary = Bot.load_config()
	for wv in cfg.military.waves:
		wv.at = 1 << 20   # no attacks: trading alone
	var bots := [Bot.new(0, cfg), EcoBot.new(1)]
	w.ages[0] = 2
	var mk := Economy.btype_of(w, "market")
	var s: Array = w.map.starts[0]
	var placed := []
	for want in [Vector2i(s[0] / 1000 + 4, s[1] / 1000 - 2), Vector2i(s[0] / 1000 + 4, s[1] / 1000 + 24), Vector2i(s[0] / 1000 + 24, s[1] / 1000)]:
		if placed.size() == 2:
			break
		for r in 8:
			var at := Vector2i(-1, -1)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if at.x < 0 and Economy.can_place(w, 0, mk, want.x + dx, want.y + dy):
						at = want + Vector2i(dx, dy)
			if at.x >= 0:
				var mb := Economy.place(w, 0, mk, at.x, at.y)
				w.buildings.done[mb] = 1
				w.buildings.hp[mb] = w.btypes[mk].hp
				placed.append(mb)
				break
	var k: int = w.type_of(0, "trader")
	var paid := 0
	var most := 0
	var in_army := false
	while w.tick < 20 * 300:
		if w.tick % 600 == 0:
			for r in w.resources.size():
				w.stock[r][0] = maxi(w.stock[r][0], 1500)
		for bot in bots:
			bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "trade" and e.has("paid"):
				paid += int(e.paid)
		if w.tick % 100 == 0:
			var n := 0
			for i in w.units.count():
				if w.units.owner[i] == 0 and w.units.kind[i] == k:
					n += 1
					in_army = in_army or w.units.stance[i] == load("res://src/sim/combat.gd").ATTACK_MOVE
			most = maxi(most, n)
	var Trade = load("res://src/sim/trade.gd")
	var apart: int = Trade.tiles(w, placed[0], placed[1]) if placed.size() == 2 else 0
	print("\n== trade bot: markets %d tiles apart; most carts at once %d; gold brought home in 5 minutes %d" % [apart, most, paid])
	check(placed.size() == 2 and apart >= int(rules.economy.trade.min_tiles), "trade bot: two markets far enough apart (%d tiles)" % apart)
	check(most >= 3 and most <= int(cfg.economy.carts.max), "trade bot: it trains a few carts, no more than its cap (%d)" % most)
	check(paid > 0 and not in_army, "trade bot: its carts bring gold home (%d) and never march with the army" % paid)


## Each level left to build up (milestone 12 phase 8): the bot with its attack waves switched
## off, against a passive side, for 30 minutes. Reports when it reaches each age, what it has
## built and researched by 20 minutes, and its army; checks the targets: age 2 by 8 minutes
## (Normal, Hard), age 3 by 16 minutes (Easy, Normal), and by 20 minutes a University, a Castle
## and a tower (Easy, Normal) and some research; by 30 minutes Normal has an army still growing.
func _test_levels(rules: Dictionary, a: Dictionary, b: Dictionary, levels := ["easy", "normal", "hard"]) -> void:
	for level in levels:
		var cfg: Dictionary = Bot.load_config()
		for wv in cfg.military.waves:
			wv.at = 1 << 20   # no attacks: building up alone
		var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
		var bots := [Bot.new(0, cfg, level), EcoBot.new(1)]
		var aged := {}
		var bought := []
		var built20 := {}
		var army := {}   # minute -> soldiers' population
		while w.tick < 20 * 60 * 30 and w.winner < 0:
			for bot in bots:
				bot.think(w)
			w.step()
			for e in w.events:
				if e.type == "age" and e.player == 0:
					aged[e.age] = w.tick
				elif e.type == "research" and e.player == 0 and w.tick <= 20 * 60 * 20:
					bought.append(e.id)
			if w.tick % 1200 == 0:
				var pop := 0
				var workers := 0
				for i in w.units.count():
					var t: Dictionary = w.types[w.units.kind[i]]
					if w.units.owner[i] == 0 and not t.worker and not t.healer and not t.has("animal"):
						pop += int(t.pop)
					elif w.units.owner[i] == 0 and t.worker:
						workers += 1
				army[w.tick / 1200] = pop
				if w.tick % 6000 == 0:
					print("  %s %s: age %d, %d workers, %d soldier pop, stock %s" % [level, _clock(w.tick), w.ages[0], workers, pop, range(w.resources.size()).map(func(r): return w.stock[r][0])])
			if w.tick == 20 * 60 * 20:
				for k in w.buildings.count():
					if w.buildings.owner[k] == 0 and w.buildings.done[k] == 1:
						var id: String = w.btypes[w.buildings.kind[k]].id
						built20[id] = int(built20.get(id, 0)) + 1
		var a2: int = aged.get(2, -1)
		var a3: int = aged.get(3, -1)
		var towers: int = built20.get("watchtower", 0) + built20.get("bastion", 0)
		print("\n== %s, left alone: age 2 at %s, age 3 at %s; by 20:00 built %s; research by 20:00 (%d) %s; army pop at 10/20/30 min %s/%s/%s" % [
			level, _clock(a2) if a2 >= 0 else "-", _clock(a3) if a3 >= 0 else "-", built20, bought.size(), bought, army.get(10, 0), army.get(20, 0), army.get(30, 0)])
		if level != "easy":
			check(a2 >= 0 and a2 <= 20 * 60 * 8, "%s: age 2 by 8:00 (%s)" % [level, _clock(a2)])   # 8, not 6: workers at 50 food, soldiers at 1.7x and an early scout put age 2 at 6:45-7:30 for a 15-20 minute match (Dominic, 2026-10-13)
		if level != "hard":
			check(a3 >= 0 and a3 <= 20 * 60 * 16, "%s: age 3 by 16:00 (%s)" % [level, _clock(a3)])
			check(built20.has("university") and built20.has("castle"), "%s: a University and a Castle by 20:00" % level)
			check(towers >= 1, "%s: a tower by 20:00" % level)
			check(bought.size() >= 10, "%s: ten or more research by 20:00 (%d)" % [level, bought.size()])
		if level == "normal":
			check(army.get(30, 0) > army.get(20, 0), "normal: its army keeps growing (%d at 20:00, %d at 30:00)" % [army.get(20, 0), army.get(30, 0)])


## Raids anywhere get an answer (Dominic, 2026-10-13: "attacking any enemy builds doesn't
## trigger a response"). The bot's lone lumber camp far from home, a worker beside it, and a
## few enemy soldiers hacking at both: within seconds the bot sends soldiers there, pulls the
## worker away, and its soldiers come to blows with the raiders.
## The Barracks' counter-pick (milestone 13, the swordsman line): spears with nothing seen, and
## against cavalry; swords against spears and skirmishers, and (with military.building_foes on)
## while the army goes for a wall. The Range's: mounted archers against swordsmen only.
func _test_pick(rules: Dictionary, gen) -> void:
	for prompt in ["greeks", "swamp frogs", "sewer rats", "egyptians"]:
		var race: Dictionary = gen.generate(prompt, rules)
		var w := World.new(SEED, SimMap.load_id(map_id), [race, race], rules)
		for age in [1, 2]:
			w.ages[0] = age
			var bot := Bot.new(0)
			var barracks := ["spear", "infantry"]
			var seen := {}
			for slot in ["spear", "skirmisher", "large", "infantry"]:   # the foes' tags, as _enemy_tags counts them, for 4 of one line
				var e: Dictionary = w.types[w.type_of(1, slot)].eval
				var tags := {}
				for t in e.tags:
					tags[t] = 4
				for c in e.bonus:
					tags["bonus:" + c] = 4 * int(e.bonus[c])
				seen[slot] = tags
			check(bot.pick(w, barracks, {}) == "spear", "pick %s age %d: spears with nothing seen" % [prompt, age])
			check(bot.pick(w, barracks, seen.large) == "spear", "pick %s age %d: spears against cavalry" % [prompt, age])
			check(bot.pick(w, barracks, seen.spear) == "infantry", "pick %s age %d: swords against spears" % [prompt, age])
			check(bot.pick(w, barracks, seen.skirmisher) == "infantry", "pick %s age %d: swords against skirmishers" % [prompt, age])
			if age == 2:   # the Range and the Stable (milestone 13): mounted archers against swordsmen, not spears; no scouts by default
				var range_lines := ["skirmisher", "archer", "mounted_archer"]
				check(bot.pick(w, range_lines, {}) != "mounted_archer", "pick %s: archers, not mounted archers, with nothing seen" % prompt)
				check(bot.pick(w, range_lines, seen.infantry) == "mounted_archer", "pick %s: mounted archers against swordsmen" % prompt)
				check(bot.pick(w, range_lines, seen.spear) != "mounted_archer", "pick %s: no mounted archers against spears" % prompt)
				check(bot.pick(w, ["large", "scout"], {}) == "large", "pick %s: the Stable's cavalry with nothing seen" % prompt)
			if age == 2:   # the Castle (milestone 13 step 4): a sapper and a great sling before more unique units; the Market's carts aren't soldiers
				w.ages[0] = 3
				var castle := ["unique", "great_sling"]   # (the sapper parked, D-128)
				check(bot.pick(w, castle, {}) == "great_sling", "pick %s: the Castle's great sling first (%s)" % [prompt, bot.pick(w, castle, {})])
				check(bot.pick(w, ["trader"], {}) == "", "pick %s: trade carts aren't picked as soldiers" % prompt)
				w.ages[0] = 2
			if int(bot.cfg.military.building_foes) > 0:   # (off for now: data/ai.json _doc_building_foes)
				bot._aim = 1
				check(bot.pick(w, barracks, bot._enemy_tags(w)) == "infantry", "pick %s age %d: swords for a wall in the way" % [prompt, age])


## The Wonder and the bot (data/ai.json "wonder"): an enemy Wonder, finished, is the first thing
## its soldiers go for (before the Town Center, without waiting for a wave); and a bot rich in
## age 3 builds one of its own.
func _test_wonder(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bot := Bot.new(0)
	var k := Economy.btype_of(w, "wonder")
	var tc1: int = -1
	for i in w.buildings.count():
		if w.buildings.owner[i] == 1:
			tc1 = w.buildings.id[i]
	var s: Array = w.map.starts[1]
	var spot := Vector2i(-1, -1)   # 5-12 tiles from their Town Center
	for r in range(5, 13):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if spot.x < 0 and maxi(absi(dx), absi(dy)) == r and Economy.can_place(w, 1, k, s[0] / 1000 + dx, s[1] / 1000 + dy):
					spot = Vector2i(s[0] / 1000 + dx, s[1] / 1000 + dy)
	check(spot.x >= 0, "wonder bot: room for their Wonder")
	var wb := Economy.place(w, 1, k, spot.x, spot.y)
	w.buildings.done[wb] = 1
	w.buildings.hp[wb] = w.bmods[1][k].hp
	var wid: int = w.buildings.id[wb]
	var s0: Array = w.map.starts[0]
	w.issue(0, Commands.SPAWN, {"slot": "large", "count": 6, "x": s0[0], "y": s0[1] + 3500})
	var first := 0
	var tc_hit := 0
	while w.tick < 20 * 240 and first == 0:
		bot.think(w)
		w.step()
		for e in w.events:
			if e.type == "hit" and e.to == wid and first == 0:
				first = w.tick
			elif e.type == "hit" and e.to == tc1 and tc_hit == 0:
				tc_hit = w.tick
	check(first > 0 and first < 20 * 200, "wonder bot: its soldiers go for a finished enemy Wonder at once (first blow at %s, waves start at %d s)" % [_clock(first), int(bot.cfg.military.waves[0].at)])
	check(tc_hit == 0, "wonder bot: the Wonder before the Town Center (Town Center hit at %s)" % (_clock(tc_hit) if tc_hit > 0 else "never"))
	# Rich in age 3: it builds its own.
	w = World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	bot = Bot.new(0)
	while w.tick < 20 * 60:
		bot.think(w)
		w.step()
	w.ages[0] = 3
	for r in w.resources.size():
		w.stock[r][0] = 3000
	var laid := 0
	while w.tick < 20 * 120 and laid == 0:
		bot.think(w)
		w.step()
		for i in w.buildings.count():
			if w.buildings.owner[i] == 0 and w.buildings.kind[i] == k:
				laid = w.tick
	check(laid > 0, "wonder bot: rich in age 3, it lays a Wonder (at %s)" % _clock(laid))


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


## A big raid by the Town Center (milestone 12 phase 8): the bot calls its workers to arms
## within seconds, and sends them back to work (when it's quiet, or after shelter.seconds).
func _test_shelter(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bot := Bot.new(1)
	while w.tick < 1200:
		bot.think(w)
		w.step()
	var tc: int = bot.eco._town_center(w)
	var tx: int = w.buildings.cx[tc] * 1000 + 1500
	var ty: int = w.buildings.cy[tc] * 1000 + 1500
	w.issue(0, Commands.SPAWN, {"slot": "spear", "count": 6, "x": tx + 4500, "y": ty})
	for t in 12:
		bot.think(w)
		w.step()
	var raiders := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and not w.types[w.units.kind[i]].worker and absi(w.units.x[i] - tx) < 8000 and absi(w.units.y[i] - ty) < 8000:
			raiders.append(w.units.id[i])
	w.issue(0, Commands.ATTACK_MOVE, {"ids": raiders, "x": tx, "y": ty + 2500})
	var start := w.tick
	var called := -1
	var back := -1
	var inside := 0
	var seen := w.history.size()
	while w.tick < start + 20 * 90 and back < 0:
		bot.think(w)
		w.step()
		for n in range(seen, w.history.size()):
			var cmd: Dictionary = w.history[n]
			if cmd.player == 1 and cmd.type == Commands.CALL_TO_ARMS and called < 0:
				called = w.tick
			elif cmd.player == 1 and cmd.type == Commands.BACK_TO_WORK and called >= 0:
				back = w.tick
		seen = w.history.size()
		inside = maxi(inside, bot.eco.sheltered(w))
	print("\n== shelter: %d raiders; call to arms %s, most inside %d, back to work %s" % [raiders.size(), _clock(called) if called >= 0 else "never", inside, _clock(back) if back >= 0 else "never"])
	check(called >= 0 and called - start <= 20 * 10, "shelter: a raid on the Town Center calls the workers to arms within 10 s")
	check(inside >= 3, "shelter: ...and they go inside (%d)" % inside)
	check(back >= 0, "shelter: ...and back to work afterwards")


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
	var mended := -1
	while w.tick < 20 * 60 * 12 and w.winner < 0:
		bot.think(w)
		passive.think(w)
		w.step()
		for e in w.events:
			if e.type == "hit":
				var tb: int = w.buildings.index_of(e.to)
				if tb >= 0 and w.buildings.kind[tb] == wk and w.buildings.owner[tb] == 0:
					wall_hits += 1
		if mended < 0 and w.bridge_up.has(1):
			mended = w.tick
		if w.tick % 100 != 0 or w.tick < 1200:
			continue
		var home: int = reach.area_at(w, ln, s1[0], s1[1])
		for i in w.units.count():
			if w.units.owner[i] != 1 or not w.types[w.units.kind[i]].worker:
				continue
			var id: int = w.units.id[i]
			looks += 1
			var idle: bool = w.units.task[i] == 0 and w.units.moving[i] == 0 and w.units.foe[i] == 0
			if w.units.task[i] == 3 and w.units.target[i] == far_id and mended < 0:
				stranded += 1   # (once the bridge is mended, the far side is in reach again)
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
	print("\n== walled fords (%s): at %s the bot has %d workers, %d buildings, age %d; idle %d of %d worker looks, longest idle %d s; workers sent to the cut-off foundation %d looks; barracks built %d; new foundations it can't reach %d; blows on the walls %d; a bridge mended %s" % [
		map_id, _clock(w.tick), workers, blds, w.ages[1], idle_looks, looks, worst * 5, stranded, barracks, cut_off, wall_hits, _clock(mended) if mended >= 0 else "never"])
	check(cut_off == 0, "walled fords: the bot lays no foundation it can't reach")
	check(stranded == 0, "walled fords: nobody is sent to the foundation over the river (%d looks)" % stranded)
	check(barracks >= 1, "walled fords: it builds a barracks on its own side instead")
	check(idle_looks * 100 <= looks * 5, "walled fords: its workers keep working (idle %d of %d looks)" % [idle_looks, looks])
	check(worst <= 4, "walled fords: no worker stands idle for long (longest %d s)" % (worst * 5))
	check(w.ages[1] >= 2 and (workers >= 20 or w.winner == w.teams[1]), "walled fords: the bot grows on its own side (age %d, %d workers; or wins first)" % [w.ages[1], workers])
	check(wall_hits > 0 or mended >= 0, "walled fords: its army goes for the walls (or over a bridge it mended)")
	if map_id == "reed_meadow" and Economy.builder_class(w, 1) == 0:   # (its bridge is the only other way over; on the delta one bridge alone leads to walled islands)
		check(mended >= 0, "walled fords: it mends a broken bridge, its only way over (milestone 15 phase 7)")


## The land (milestone 15 phase 7): an early scout tours and sees round the enemy's start; then a
## Normal bot match (frogs against rats) to the end, reporting what each bot did with the land:
## scout tours, roads felled, camps by far gatherers, escorts, the key crossing guarded, bridges
## mended and broken, hills taken, flanks and detours, raids. Checks what the map calls for.
func _test_land(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [b, a], rules)
	var bot := Bot.new(0)
	var passive := EcoBot.new(1)
	while w.tick < 20 * 60 * 4:
		bot.think(w)
		passive.think(w)
		w.step()
	var s1: Array = w.map.starts[1]
	var seen := 0
	var cells := 0
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var x: int = s1[0] / 1000 + dx
			var y: int = s1[1] / 1000 + dy
			if x >= 0 and y >= 0 and x < w.map.width and y < w.map.height:
				cells += 1
				if w.fog[0][y * w.map.width + x] != 0:
					seen += 1
	print("\n== land (%s): scout tours %d by 4:00, ground round the enemy start seen %d of %d cells" % [map_id, bot.scout.tours, seen, cells])
	check(bot.scout.tours >= 1, "land: a scout tours early")
	check(seen * 100 >= cells * 25, "land: ...and sees round the enemy's start (%d of %d cells)" % [seen, cells])
	# A whole Normal match: what the bots did with the land.
	w = World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bots := [Bot.new(0), Bot.new(1)]
	while w.tick < LIMIT and w.winner < 0:
		for bt in bots:
			bt.think(w)
		w.step()
	var did := {}
	for p in 2:
		var bt = bots[p]
		var line := {"tours": bt.scout.tours, "roads": bt.land.roads, "key": bt.land.key}
		line.merge(bt.land.stats)
		line.merge(bt.expand.stats)
		print("   P%d %s: %s" % [p, [a, b][p].name, line])
		for k in line:
			if typeof(line[k]) == TYPE_INT and k != "key":
				did[k] = int(did.get(k, 0)) + line[k]
	print("   match: winner %d at %s" % [w.winner, _clock(w.tick)])
	var camps: int = did.get("lumber_camp", 0) + did.get("mining_camp", 0) + did.get("mill", 0)
	check(camps >= 1, "land: camps go up by far gatherers (%d)" % camps)
	if map_id == "old_forest":
		check(did.get("roads", 0) >= 1, "land: a road is felled through the thin woods (%d trees)" % did.get("road_trees", 0))
	check(w.winner >= 0, "land: the match ends (%s)" % _clock(w.tick))


## A level that guards (Normal), on the back foot (set: here the placement is the point), left to
## build up against a passive side (its stock topped up from 6:00), puts a Watchtower on the key
## crossing (the one the enemy's way to it uses) by 16 minutes.
func _test_guard(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var cfg: Dictionary = Bot.load_config()
	for wv in cfg.military.waves:
		wv.at = 1 << 20
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var bot := Bot.new(0, cfg)
	bot._on_back_foot = true   # (it guards its crossing when it's on the back foot: here, from the start)
	var passive := EcoBot.new(1)
	while w.tick < 20 * 60 * 16:
		if w.tick % 1200 == 0 and w.tick >= 20 * 60 * 6:   # (its placement is the point, not the economy: topped up from 6:00)
			for r in w.resources.size():
				w.stock[r][0] = maxi(w.stock[r][0], 1000)
		bot.think(w)
		passive.think(w)
		w.step()
	var side: int = bot.land.key_side
	var s0: Array = w.map.starts[0]
	if bot.land.key < 0 or maxi(absi(side % w.map.width - s0[0] / 1000), absi(side / w.map.width - s0[1] / 1000)) > int(cfg.land.guard_range):
		print("\n== guard: no key crossing near home on the enemy's way here (%s), skipped" % map_id)
		return
	var near := 99
	for k in w.buildings.count():
		var id: String = w.btypes[w.buildings.kind[k]].id
		if w.buildings.owner[k] == 0 and (id == "watchtower" or id == "bastion"):
			near = mini(near, maxi(absi(w.buildings.cx[k] - side % w.map.width), absi(w.buildings.cy[k] - side / w.map.width)))
	print("\n== guard (%s): key crossing %s, our side at (%d, %d); nearest tower of ours %d tiles from it" % [map_id, bot.land.crossings(w)[bot.land.key][0], side % w.map.width, side / w.map.width, near])
	check(near <= int(cfg.land.guard_tiles), "guard: a Watchtower stands on the key crossing (%d tiles)" % near)


## High ground: four of our archers a few steps from a ramp up a hill, enemy soldiers coming at
## them: the bot sends the archers up (they end above the ground they stood on).
func _test_hills(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var m = w.map
	if not m.has_heights:
		return
	var bot := Bot.new(0)
	# By a ramp up from level 0: the archers 3 steps from its foot, the enemy 8 (walkers' ground,
	# in sight); the enemy stands 6 s, then comes on.
	var walk: PackedByteArray = m.walks[0]
	var foot := -1
	var far := -1
	for c in m.width * m.height:
		if foot >= 0 or m.ramp[c] == 0 or m.level[c] != 0:
			continue
		var steps := {c: 0}
		var queue := [c]
		var head := 0
		var f := -1
		var e := -1
		while head < queue.size():
			var at: int = queue[head]
			head += 1
			if steps[at] == 3 and f < 0:
				f = at
			if steps[at] == 8 and e < 0:
				e = at
			for d in [1, -1, m.width, -m.width]:
				var n: int = at + d
				if n >= 0 and n < walk.size() and walk[n] == 1 and m.level[n] == 0 and m.ramp[n] == 0 and not steps.has(n) and absi(n % m.width - at % m.width) <= 1:
					steps[n] = steps[at] + 1
					queue.append(n)
		if f >= 0 and e >= 0:
			foot = f
			far = e
	if foot < 0:
		print("\n== hills: no ramp with open ground before it on %s, skipped" % map_id)
		return
	var fx: int = foot % m.width * 1000 + 500
	var fy: int = foot / m.width * 1000 + 500
	var ex: int = far % m.width * 1000 + 500
	var ey: int = far / m.width * 1000 + 500
	w.issue(0, Commands.SPAWN, {"slot": "archer", "count": 4, "x": fx, "y": fy})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 4, "x": ex, "y": ey})
	for t in 12:
		bot.think(w)
		w.step()
	var ours := []
	var theirs := []
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.types[w.units.kind[i]].slot == "archer":
			ours.append(w.units.id[i])
		elif w.units.owner[i] == 1 and w.types[w.units.kind[i]].slot == "spear":
			theirs.append(w.units.id[i])
	w.issue(1, Commands.STANCE, {"ids": theirs, "stance": "stand"})   # (they wait, then come on)
	var below := ours.filter(func(id): return m.level_at(w.units.x[w.units.index_of(id)], w.units.y[w.units.index_of(id)]) == 0).size()
	var up := 0
	while w.tick < 20 * 25:
		if w.tick == 20 * 6:
			w.issue(1, Commands.ATTACK_MOVE, {"ids": theirs, "x": fx, "y": fy})
		bot.think(w)
		w.step()
		up = 0
		for id in ours:
			var i: int = w.units.index_of(id)
			if i >= 0 and m.level_at(w.units.x[i], w.units.y[i]) >= 1:
				up += 1
		if up >= 2:
			break
	print("\n== hills (%s): archers at (%d, %d) by a hill; %d of 4 up on it at %s; hill orders %d" % [map_id, foot % m.width, foot / m.width, up, _clock(w.tick), bot.land.stats.get("hill", 0)])
	check(below == 4 and up >= 2, "hills: archers meeting an army climb the hill beside them (%d of 4 below, %d up)" % [below, up])


## A walled-in base (Dominic, 2026-10-13: "if walls blocking the AI everywhere, will it try to
## break them? or just pathfinder gets confused and they stop coming?"). On flat_test the passive
## side's Town Center is ringed by a wall line of `wall` with two of its gates in it (shut to the
## bot), put up finished at the start. The bot must break a way in and win, its soldiers out at
## the wall busy (fighting or walking), not standing about. With `gap`, the ring has a three-tile
## gap on the side facing the bot instead of the south gate: the bot walks in through it and
## barely touches the wall.
func _test_walled_base(rules: Dictionary, a: Dictionary, b: Dictionary, wall: String, gap: bool) -> void:
	var title := "walled base (%s%s)" % [wall, ", gap" if gap else ""]
	if map_id != "flat_test":
		print("\n== %s: laid out for flat_test, skipped on %s" % [title, map_id])
		return
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], rules)
	var lo := Vector2i(5, 3)   # the ring: every cell on its edge is grass or rock
	var hi := Vector2i(24, 21)
	var wk := Economy.btype_of(w, wall)
	var gk := Economy.btype_of(w, "palisade_gate" if wall == "palisade" else "stone_gate")
	var south := range(12, 15)   # the south side's gate (or gap) cells, x
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if (x != lo.x and x != hi.x and y != lo.y and y != hi.y) or w.map.occupied[y * w.map.width + x] != 0 or not w.map.can_build(x, y, 1):
				continue
			if gap and y == hi.y and x in south:
				continue
			var bi := Economy.place(w, 0, wk, x, y)
			w.buildings.done[bi] = 1
			w.buildings.hp[bi] = w.bmods[0][wk].hp
	for g in ([[hi.x, 11, 1]] if gap else [[hi.x, 11, 1], [12, hi.y, 0]]):   # east (along y), south (along x)
		for c in Economy._footprint(w, g[0], g[1], Economy.dims(w.btypes[gk], g[2])):
			Economy.demolish(w, w.buildings.index_of(w.map.occupied[c]))
		var bi := Economy.place(w, 0, gk, g[0], g[1], g[2])
		w.buildings.done[bi] = 1
		w.buildings.hp[bi] = w.bmods[0][gk].hp
	var cfg: Dictionary = Bot.load_config()
	cfg.military.erase("hero")   # no heroes (D-136): with them the battle's timing shifts and its archers nick a second piece (palisade: 70 of 162 blows on one)
	var bot := Bot.new(1, cfg)
	var passive := EcoBot.new(0)
	var reach := Reach.new()
	var ln: int = w.lane_base[1]   # the bot's foot soldiers' lane (ground)
	var s0: Array = w.map.starts[0]
	var s1: Array = w.map.starts[1]
	var inside := func(x: int, y: int) -> bool: return x > lo.x * 1000 + 999 and x < hi.x * 1000 and y > lo.y * 1000 + 999 and y < hi.y * 1000
	check(gap == (reach.area_at(w, ln, s0[0], s0[1]) == reach.area_at(w, ln, s1[0], s1[1])),
		"%s: the ring %s" % [title, "has its gap" if gap else "shuts the bot out"])
	var struck := {}       # ring piece id -> blows on it
	var dealt := 0
	var ring_hits := 0     # blows on the ring (walls and gates) ...
	var hits_before_in := -1   # ... up to the first bot soldier inside
	var first_hit := -1
	var breach := -1       # when the Town Center came into reach
	var first_in := -1     # when a bot soldier first stood inside the ring
	var looks := 0         # 5 s looks at bot soldiers out by the ring (assault on)
	var idle := 0
	var stuck := {}        # bot soldier id -> looks in a row standing idle out by the ring
	var worst := 0
	while w.tick < 20 * 60 * 30 and w.winner < 0:
		bot.think(w)
		passive.think(w)
		w.step()
		for e in w.events:
			if e.type == "hit":
				var tb: int = w.buildings.index_of(e.to)
				if tb >= 0 and w.buildings.owner[tb] == 0 and w.buildings.kind[tb] in [wk, gk]:
					ring_hits += 1
					struck[e.to] = int(struck.get(e.to, 0)) + 1
					dealt += int(e.damage)
					if first_hit < 0:
						first_hit = w.tick
		if w.tick % 100 != 0:
			continue
		if breach < 0 and not gap and reach.area_at(w, ln, s0[0], s0[1]) == reach.area_at(w, ln, s1[0], s1[1]):
			breach = w.tick
		for i in w.units.count():
			if w.units.owner[i] != 1 or w.types[w.units.kind[i]].worker or w.types[w.units.kind[i]].healer:
				continue
			var x: int = w.units.x[i]
			var y: int = w.units.y[i]
			if first_in < 0 and inside.call(x, y):
				first_in = w.tick
				hits_before_in = ring_hits
			# Out by the ring (within 6 tiles of its outside), the Town Center not yet in reach.
			var near: bool = x > (lo.x - 6) * 1000 and x < (hi.x + 7) * 1000 and y > (lo.y - 6) * 1000 and y < (hi.y + 7) * 1000 and not inside.call(x, y)
			if not near or not bot.assault or (breach >= 0 and not gap):
				continue
			var id: int = w.units.id[i]
			looks += 1
			var still: bool = w.units.foe[i] == 0 and w.units.moving[i] == 0
			if still:
				idle += 1
			stuck[id] = int(stuck.get(id, 0)) + 1 if still else 0
			worst = maxi(worst, stuck[id])
	var hp_left := []
	for bi in w.buildings.count():
		if w.buildings.owner[bi] == 0 and w.buildings.kind[bi] == gk:
			hp_left.append(w.buildings.hp[bi])
	var spread: Array = struck.values()
	spread.sort()
	spread.reverse()
	print("  blows per ring piece hit (most first) %s, damage dealt %d" % [spread.slice(0, 12), dealt])
	print("\n== %s: winner %d at %s; first blow on the ring %s, %d blows in all%s; first bot soldier inside %s (%d blows on the ring by then); gates' hp left %s; soldiers out by the ring idle %d of %d looks, longest %d s" % [
		title, w.winner, _clock(w.tick), _clock(first_hit) if first_hit >= 0 else "never", ring_hits,
		"" if gap else ", the Town Center in reach from %s" % (_clock(breach) if breach >= 0 else "never"),
		_clock(first_in) if first_in >= 0 else "never", hits_before_in, hp_left, idle, looks, worst * 5])
	check(w.winner == 1, "%s: the bot wins (winner %d at %s)" % [title, w.winner, _clock(w.tick)])
	check(first_in >= 0, "%s: the bot's soldiers get inside the ring" % title)
	check(looks == 0 or idle * 100 <= looks * 20, "%s: soldiers out by the ring keep at it (idle %d of %d looks)" % [title, idle, looks])
	check(worst <= 6, "%s: none of them stands about long (longest %d s)" % [title, worst * 5])
	if gap:
		check(hits_before_in >= 0 and hits_before_in <= 20, "%s: it walks in through the gap rather than smash the wall (%d blows first)" % [title, hits_before_in])
	else:
		check(breach >= 0, "%s: it breaks a way through the ring" % title)
		check(not spread.is_empty() and spread[0] * 2 >= ring_hits, "%s: the blows go on one piece, not nicks on a dozen (%s of %d)" % [title, spread.slice(0, 3), ring_hits])


## Rams break walls (milestone 13): three rams against a stone gate and a stone wall piece, then
## the same cost in each of the race's foot soldiers (spears, swordsmen if it has them): the rams
## break through several times faster.
func _test_rams(rules: Dictionary, race: Dictionary) -> void:
	var times := {}
	var spent := 0
	for slot in ["ram", "spear", "large", "great_sling"]:   # (the Castle's sling too, milestone 13 step 4; the sapper parked)
		for target in ["stone_gate", "wall"]:
			var r := rules.duplicate(true)
			r.economy.start.buildings = []
			r.economy.start.workers = 0
			r.animals = false
			var w := World.new(SEED, SimMap.load_id(map_id), [race, race], r)
			var k: int = w.type_of(0, slot)
			var cost := 0
			for c in w.types[k].cost:
				cost += c
			if slot == "ram":
				spent = cost * 3
			var n := 3 if slot == "ram" else maxi(1, (spent + cost / 2) / cost)
			var bk := Economy.btype_of(w, target)
			var bi := Economy.place(w, 1, bk, 20, 20, 0)
			w.buildings.done[bi] = 1
			w.buildings.hp[bi] = w.bmods[1][bk].hp
			var bid: int = w.buildings.id[bi]
			w.issue(0, Commands.SPAWN, {"slot": slot, "count": n, "x": 15000, "y": 20500})
			while w.units.count() < n:
				w.step()
			w.issue(0, Commands.ATTACK, {"ids": Array(w.units.id), "target": bid})
			while w.buildings.index_of(bid) >= 0 and w.tick < 20 * 600:
				w.step()
			times["%s:%s" % [slot, target]] = w.tick
			print("  %d %s (%d resources each) break a %s in %s" % [n, w.types[k].name, cost, target, _clock(w.tick)])
	for target in ["stone_gate", "wall"]:
		var ram: int = times["ram:" + target]
		for slot in ["spear", "large"]:
			check(ram * 3 <= times["%s:%s" % [slot, target]], "rams break a %s at least 3 times faster than the same cost in %s (%s vs %s)" % [
				target, slot, _clock(ram), _clock(times["%s:%s" % [slot, target]])])
		check(times["great_sling:" + target] < 20 * 600, "great slings break a %s from afar (%s)" % [target, _clock(times["great_sling:" + target])])


func _clock(tick: int) -> String:
	return "%d:%02d" % [tick / 1200, tick / 20 % 60]


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


## Walls you stand on and the bot (milestone 16, src/ai/walls_ai.gd). Manning: the bot (player 0)
## in a stone ring with shooters at home sends most of them up onto the wall facing enemy spears
## standing outside. Storming: a bot attacking a walled town pushes its siege tower to the wall
## and, once docked, its swordsmen go up through it and down the defenders' stairs inside.
func _test_walls_bot(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	if map_id != "flat_test":
		print("\n== walls bot: laid out for flat_test, skipped on %s" % map_id)
		return
	var r := rules.duplicate(true)
	r.animals = false
	var w := World.new(SEED, SimMap.load_id(map_id), [a, b], r)
	for p in 2:
		w.ages[p] = 3
		Tech.retype(w, p)
		Tech.refresh(w, p)
	var s0: Array = w.map.starts[0]
	Fortify.ring(w, 0, s0[0] / 1000, s0[1] / 1000, 7, {"wall": "wall", "gate": "stone_gate", "tower": "", "gates": ["n", "e", "s", "w"]})
	var before: int = w.next_id
	w.issue(0, Commands.SPAWN, {"slot": "archer", "count": 10, "x": s0[0] + 2000, "y": s0[1] + 2000})
	w.issue(1, Commands.SPAWN, {"slot": "spear", "count": 6, "x": s0[0] + 13000, "y": s0[1] + 13000})
	var bot := Bot.new(0)
	var up := 0
	while w.tick < 20 * 60:
		bot.think(w)
		w.step()
	for i in w.units.count():
		if w.units.owner[i] == 0 and w.units.perch[i] != 0:
			up += 1
	print("\n== walls bot: %d of 10 shooters up on the wall after a minute" % up)
	check(up >= 4, "walls bot: the bot mans its wall facing the enemy (%d of 10 up)" % up)
	# Storming: player 1's swordsmen and a siege tower by the ring's south-east, attacking.
	var w2 := World.new(SEED, SimMap.load_id(map_id), [a, b], r)
	for p in 2:
		w2.ages[p] = 3
		Tech.retype(w2, p)
		Tech.refresh(w2, p)
	Fortify.ring(w2, 0, s0[0] / 1000, s0[1] / 1000, 7, {"wall": "wall", "gate": "stone_gate", "tower": "", "gates": ["n", "w"]})
	var first: int = w2.next_id
	w2.issue(1, Commands.SPAWN, {"slot": "infantry", "count": 8, "x": s0[0] + 11000, "y": s0[1] + 4000})
	w2.issue(1, Commands.SPAWN, {"slot": "siege_tower", "count": 1, "x": s0[0] + 11000, "y": s0[1] + 2000})
	for t in 12:
		w2.step()
	var attacker := Bot.new(1)
	attacker.assault = true
	var target := Vector2i(s0[0], s0[1] + 3500)
	var docked := -1
	var most_up := 0
	var inside := 0
	while w2.tick < 20 * 150:
		var army := []
		for i in w2.units.count():
			if w2.units.owner[i] == 1:
				army.append(i)
		WallsAi.storm(w2, attacker, army, target)
		w2.step()
		var n := 0
		var ins := 0
		for i in w2.units.count():
			if w2.units.owner[i] != 1:
				continue
			if w2.units.perch[i] != 0:
				n += 1
			elif absi(w2.units.x[i] - s0[0]) < 6500 and absi(w2.units.y[i] - s0[1]) < 6500:
				ins += 1
			if docked < 0 and w2.types[w2.units.kind[i]].get("docks", false) and Walls.docked_at(w2, i) >= 0:
				docked = w2.tick
		most_up = maxi(most_up, n)
		inside = maxi(inside, ins)
	print("== walls bot: the tower docked at %s; at most %d swordsmen up at once, %d inside" % [_clock(docked) if docked >= 0 else "never", most_up, inside])
	check(docked >= 0, "walls bot: its siege tower docks on the enemy wall")
	check(most_up >= 3 and inside >= 3, "walls bot: swordsmen go over the wall by the tower and into the town (%d up, %d inside)" % [most_up, inside])


## The Siege mode (milestone 16) bot against bot on Siege Vale: player 0 holds the walled town,
## player 1 attacks with its army and engines. The match ends (a winner inside the hold time, or the
## defenders when it runs out), the defenders man their walls, the attackers make breaches.
func _test_siege_mode(rules: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var r := rules.duplicate(true)
	r.mode = "siege"
	var w := World.new(SEED, SimMap.load_id("siege_vale"), [a, b], r)
	var bots := [Bot.new(0), Bot.new(1)]
	var most_up := 0
	while w.tick < 20 * 60 * 21 and w.winner < 0:
		for bot in bots:
			bot.think(w)
		w.step()
		if w.tick % 100 == 0:
			var up := 0
			for i in w.units.count():
				if w.units.owner[i] == 0 and w.units.perch[i] != 0:
					up += 1
			most_up = maxi(most_up, up)
	print("\n== siege mode (%s holds, %s attacks): winner %d at %s; at most %d defenders up, %d breach cells" % [a.name, b.name, w.winner, _clock(w.tick), most_up, w.rubble.size()])
	check(w.winner >= 0, "siege mode: the match ends")
	check(most_up >= 6, "siege mode: the defenders man their walls (%d up)" % most_up)
	check(w.rubble.size() > 0, "siege mode: the attackers make breaches")
