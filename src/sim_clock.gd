extends Node
## Steps a sim World at a fixed 20 Hz from _process. Not _physics_process, so
## physics settings can never touch the sim. Views read `alpha` (0..1, how far
## we are towards the next tick) to interpolate between prev and current positions.
## Wall time lives here, never inside the sim.

const World := preload("res://src/sim/world.gd")

const STEP := 1.0 / World.TICK_HZ
const MAX_CATCH_UP := 5        # ticks per frame before we drop time instead of spiralling

var world: World
var paused := false
var speed := 1.0               # playback multiplier for watching replays
var stop_at := -1              # stop stepping at this tick (end of a replay); -1 runs forever
var bots: Array = []           # players run by a bot: each thinks (issues commands) before every tick
## A network match (src/net/lockstep.gd): it says when a turn may start (every player's commands
## for it are in), sends this machine's, and the clock holds while it waits.
var lockstep = null
var waiting := false           # the last frame held for the lockstep
## Capture tools (tests/sim_screenshot.gd): > 0 steps exactly `speed` x this many ticks a frame,
## whatever the frame time (frame-locked, so as fast as frames come and the same every run);
## `hold` keeps the world still meanwhile (the loader fading out).
var frame_steps := 0
var hold := false
var alpha := 0.0
var events: Array = []         # the world's events from every tick since the view last took them
var tick_usec := 0             # cost of the last tick
var tick_usec_avg := 0.0
var tick_usec_max := 0
var _acc := 0.0


func _process(delta: float) -> void:
	if world == null or paused or hold:
		return
	_acc += delta * speed
	var n := 0
	var cap := MAX_CATCH_UP * maxi(1, int(speed))
	if frame_steps > 0:
		_acc = roundi(speed * frame_steps) * STEP + STEP * 0.5
		cap = roundi(speed * frame_steps)
	waiting = false
	if lockstep != null:
		lockstep.receive()
	while _acc >= STEP and n < cap and world.tick != stop_at:
		var t := Time.get_ticks_usec()
		if lockstep != null:
			if not lockstep.step(bots):
				waiting = true
				_acc = minf(_acc, STEP * 2.0)   # (no catching up a long wait in one spurt)
				break
		else:
			for bot in bots:
				bot.think(world)
			world.step()
		events.append_array(world.events)
		tick_usec = Time.get_ticks_usec() - t
		tick_usec_avg = lerpf(tick_usec_avg, tick_usec, 0.05)
		tick_usec_max = maxi(tick_usec_max, tick_usec)
		_acc -= STEP
		n += 1
	if n == cap:
		_acc = minf(_acc, STEP)
	alpha = clampf(_acc / STEP, 0.0, 1.0)


## Hand over the buffered events (the view plays them as effects).
func take_events() -> Array:
	var out := events
	events = []
	return out


func reset(w: World, end_tick := -1) -> void:
	world = w
	lockstep = null
	stop_at = end_tick
	_acc = 0.0
	alpha = 0.0
	events.clear()
	tick_usec_avg = 0.0
	tick_usec_max = 0
