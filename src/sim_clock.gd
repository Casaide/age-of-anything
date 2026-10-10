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
var alpha := 0.0
var tick_usec := 0             # cost of the last tick
var tick_usec_avg := 0.0
var tick_usec_max := 0
var _acc := 0.0


func _process(delta: float) -> void:
	if world == null or paused:
		return
	_acc += delta * speed
	var n := 0
	var cap := MAX_CATCH_UP * maxi(1, int(speed))
	while _acc >= STEP and n < cap and world.tick != stop_at:
		var t := Time.get_ticks_usec()
		world.step()
		tick_usec = Time.get_ticks_usec() - t
		tick_usec_avg = lerpf(tick_usec_avg, tick_usec, 0.05)
		tick_usec_max = maxi(tick_usec_max, tick_usec)
		_acc -= STEP
		n += 1
	if n == cap:
		_acc = minf(_acc, STEP)
	alpha = clampf(_acc / STEP, 0.0, 1.0)


func reset(w: World, end_tick := -1) -> void:
	world = w
	stop_at = end_tick
	_acc = 0.0
	alpha = 0.0
	tick_usec_avg = 0.0
	tick_usec_max = 0
