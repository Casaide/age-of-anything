extends SceneTree
## Network lockstep checks (networking milestone). Headless.
##   loop   two Worlds in one process, one per player, each with its own player's bot only, joined
##          by a loopback link with delay and jitter (src/net/loopback.gd): they must hash the same at
##          every checkpoint, and the same as one World where both bots play (the reference); a late
##          link stalls a world, never desyncs it; a changed command is caught as a desync.
##   enet   two processes on this machine over ENet (src/net/enet.gd, localhost): this one hosts
##          player 0 and starts another that joins as player 1, each with its own bot; they must end
##          with the same hashes, and the same as the reference.
## Run: godot --headless --path . --script res://tests/net_check.gd -- [loop|enet] [ticks]

const DataLib := preload("res://src/data_lib.gd")
const Generator := preload("res://src/race_generator.gd")
const World := preload("res://src/sim/world.gd")
const SimMap := preload("res://src/sim/sim_map.gd")
const Bot := preload("res://src/ai/bot.gd")
const Loopback := preload("res://src/net/loopback.gd")
const Lockstep := preload("res://src/net/lockstep.gd")
const Enet := preload("res://src/net/enet.gd")
const TEST_PORT := 47871

const SEED := 1
const MAP := "reed_meadow"

var failures := 0
var checks := 0


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var ticks := 6000   # five minutes of match
	for a in args:
		if String(a).is_valid_int():
			ticks = int(a)
	var lib = DataLib.new()
	var gen = Generator.new(lib)
	var rules = DataLib.load_rules("default")
	var races := [gen.generate("angry swamp frogs with reed spears", rules), gen.generate("sewer rats with cheese hammers", rules)]
	if "enet-join" in args:   # the second process: player 1
		await _enet_seat(Enet.join("127.0.0.1", TEST_PORT), 1, races, rules, ticks, {})
		quit()
		return
	var t0 := Time.get_ticks_msec()
	# The reference: one World, both bots.
	var ref = World.new(SEED, SimMap.load_id(MAP), races, rules)
	var ref_bots := [Bot.new(0), Bot.new(1)]
	while ref.tick < ticks:
		for b in ref_bots:
			b.think(ref)
		ref.step()
	print("reference: %d ticks, %d commands, %d hashes (%d ms)" % [ref.tick, ref.history.size(), ref.hashes.size(), Time.get_ticks_msec() - t0])
	if not "enet" in args:
		for link in [[0, 0], [3, 0], [2, 6], [12, 20]]:   # delay and jitter, in polls (a poll a frame, ~3 ticks a frame)
			_loop(races, rules, ticks, ref, link[0], link[1])
		_tampered(races, rules)
	if not "loop" in args:
		var host = Enet.host(TEST_PORT)
		_check(host.error == "", "enet: listening (%s)" % host.error)
		var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/net_check.gd", "--", "enet-join", str(ticks)])
		_check(pid > 0, "enet: the second process started")
		await _enet_seat(host, 0, races, rules, ticks, ref)
	print("\nnet check: %d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Two worlds over a loopback link with this delay and jitter, run to `ticks`, against the reference.
func _loop(races: Array, rules: Dictionary, ticks: int, ref, delay: int, jitter: int) -> void:
	var t0 := Time.get_ticks_msec()
	var ends: Array = Loopback.pair(delay, jitter)
	var worlds := [World.new(SEED, SimMap.load_id(MAP), races, rules), World.new(SEED, SimMap.load_id(MAP), races, rules)]
	var locks := [Lockstep.new(worlds[0], 0, [0, 1], ends[0]), Lockstep.new(worlds[1], 1, [0, 1], ends[1])]
	var bots := [[Bot.new(0)], [Bot.new(1)]]
	var frames := 0
	var stalls := 0
	while (worlds[0].tick < ticks or worlds[1].tick < ticks) and frames < ticks * 10:
		frames += 1
		for k in 2:   # each machine's frame: up to three ticks, as SimClock at 60 fps catching up
			for n in 3:
				if worlds[k].tick >= ticks:
					locks[k].receive()
					break
				if not locks[k].step(bots[k]):
					stalls += 1
					break
	var name := "loopback delay %d jitter %d" % [delay, jitter]
	_check(worlds[0].tick >= ticks and worlds[1].tick >= ticks, "%s: both worlds reach tick %d (%d, %d; %d frames)" % [name, ticks, worlds[0].tick, worlds[1].tick, frames])
	_check(locks[0].desync == "" and locks[1].desync == "", "%s: no desync (%s%s)" % [name, locks[0].desync, locks[1].desync])
	_check(worlds[0].hashes == worlds[1].hashes, "%s: the two worlds hash the same (%d checkpoints)" % [name, worlds[0].hashes.size()])
	_check(worlds[0].hashes == ref.hashes.slice(0, worlds[0].hashes.size()), "%s: and the same as the reference" % name)
	var mine: int = worlds[0].history.filter(func(c): return int(c.player) == 0).size()
	var theirs: int = worlds[0].history.filter(func(c): return int(c.player) == 1).size()
	_check(mine > 0 and theirs > 0, "%s: both players' commands ran on world 0 (%d, %d)" % [name, mine, theirs])
	if delay >= 6:   # (a few polls fit in the two turns a command waits anyway: no stall)
		_check(stalls > 0, "%s: a slow link stalls a world (%d stalls)" % [name, stalls])
	print("  %s: %d frames, %d stalls (%d ms)" % [name, frames, stalls, Time.get_ticks_msec() - t0])


## One machine's seat over ENet: wait for the other, play to `ticks` with this player's bot, then
## the joiner sends its hashes and the host compares (both with the reference, given).
func _enet_seat(link, me: int, races: Array, rules: Dictionary, ticks: int, ref) -> void:
	var t0 := Time.get_ticks_msec()
	var who := "enet %s" % ("host" if me == 0 else "joiner")
	while not link.connected and not link.closed and Time.get_ticks_msec() - t0 < 15000:
		link.poll()
		await process_frame
	_check(link.connected, "%s: connected (%d ms%s)" % [who, Time.get_ticks_msec() - t0, ", " + link.error if link.error != "" else ""])
	if not link.connected:
		return
	var w = World.new(SEED, SimMap.load_id(MAP), races, rules)
	var lock := Lockstep.new(w, me, [0, 1], link)
	var bots := [Bot.new(me)]
	var stalls := 0
	while w.tick < ticks and lock.desync == "" and not lock.peer_left and Time.get_ticks_msec() - t0 < 300000:
		for n in 3:
			if w.tick >= ticks or not lock.step(bots):
				stalls += 1
				break
		await process_frame
	_check(w.tick >= ticks, "%s: reached tick %d (%d, %d stalls, %d ms)" % [who, ticks, w.tick, stalls, Time.get_ticks_msec() - t0])
	_check(lock.desync == "", "%s: no desync (%s)" % [who, lock.desync])
	if me == 1:
		link.send({"t": "final", "hashes": w.hashes})
		for f in 30:   # let it go out before the process ends
			link.poll()
			await process_frame
		return
	var theirs = null
	var t1 := Time.get_ticks_msec()
	while theirs == null and Time.get_ticks_msec() - t1 < 30000:
		lock.receive()
		for m in lock.others:
			if m.get("t", "") == "final":
				theirs = m.hashes
		await process_frame
	_check(theirs != null, "enet: the joiner's hashes came back")
	if theirs != null:
		_check(theirs == w.hashes, "enet: both processes hash the same (%d checkpoints)" % w.hashes.size())
		_check(w.hashes == ref.hashes.slice(0, w.hashes.size()), "enet: and the same as the reference")


## A command changed on its way: the worlds part and the hashes say so.
func _tampered(races: Array, rules: Dictionary) -> void:
	var ends: Array = Loopback.pair(0, 0)
	var w0 = World.new(SEED, SimMap.load_id(MAP), races, rules)
	var w1 = World.new(SEED, SimMap.load_id(MAP), races, rules)
	var l0 := Lockstep.new(w0, 0, [0, 1], ends[0])
	var l1 := Lockstep.new(w1, 1, [0, 1], ends[1])
	var b0 := [Bot.new(0)]
	var b1 := [Bot.new(1)]
	var cheat := true
	for f in 3000:
		if not l0.step(b0) and l0.desync != "":
			break
		if not l1.step(b1) and l1.desync != "":
			break
		if cheat and not w0.commands.pending.is_empty():   # one of player 0's queued commands changed, on world 0 only
			for run in w0.commands.pending:
				for c in w0.commands.pending[run]:
					if int(c.player) == 0 and c.type == "train" and int(c.turn) < w0.turn():
						c.type = "stop"
						c.args = {"ids": []}
						cheat = false
						break
				if not cheat:
					break
	_check(not cheat, "tamper: a command was changed")
	_check(l0.desync != "" or l1.desync != "", "tamper: the desync is caught (%s%s)" % [l0.desync, l1.desync])


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
