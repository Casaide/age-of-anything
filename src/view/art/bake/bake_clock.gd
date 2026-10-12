extends Node
## Renders bake viewports on demand, whether or not the game's window is being drawn.
##
## A bake used to set its viewport to render once and wait for the engine's next frame
## (frame_post_draw). On macOS the engine stops drawing frames while its window is hidden,
## covered or on another Space, so a bake started there never finished (Dominic: "baking never
## finishes"). Now a bake asks this clock: render(vp) queues the viewport and waits; the clock,
## each process frame, flushes the queued viewports' transforms (Node3D moves reach the renderer
## at frame end otherwise: the reason a forced draw once "came back empty"), forces one draw of
## all of them together (several bakers share a draw), wakes them, and goes again while there's
## work and time in its slice. The slice is short while the game is drawn smoothly (a loader
## keeps animating) and long while the frames come slowly (hidden, throttled: nobody's looking,
## so it bakes in big blocks at full speed).

const SLICE := 0.04           # seconds of bake rendering per frame while the window draws smoothly (a loader stays smooth)
const SLICE_HIDDEN := 0.5     # ... while frames come slowly or the window can't draw
const SLOW_FRAME := 0.1       # a frame gap this long means we're hidden or throttled

signal drawn

static var on_demand := true  # false: the old way, wait for the engine's next frame (tests compare the two)
static var draws := 0         # forced draws so far, and the time they took (bake timing reports)
static var draw_usec := 0
static var _clock: Node = null
var _queue: Array = []        # viewports waiting for a draw
var _last := 0


## Render this viewport once, now-ish, and return when its texture holds the result.
static func render(vp: SubViewport) -> void:
	if not on_demand:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		return
	if _clock == null or not is_instance_valid(_clock):
		_clock = new()
		_clock.name = "BakeClock"
		vp.get_tree().root.add_child.call_deferred(_clock)
	_clock._queue.append(vp)
	await _clock.drawn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var gap := (now - _last) / 1e6
	_last = now
	var slice := SLICE_HIDDEN if gap > SLOW_FRAME or not DisplayServer.window_can_draw() else SLICE
	while not _queue.is_empty() and (Time.get_ticks_usec() - now) / 1e6 < slice:
		var batch := _queue
		_queue = []
		for vp in batch:
			if not is_instance_valid(vp):
				continue
			for n in vp.find_children("*", "Node3D", true, false):
				(n as Node3D).force_update_transform()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var t := Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		draws += 1
		draw_usec += Time.get_ticks_usec() - t
		drawn.emit()   # the waiting bakes resume here, and may queue their next render
	_last = Time.get_ticks_usec()
