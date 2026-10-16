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
## work and budget left this frame. The budget is short while the game is drawn smoothly (a loader
## keeps animating) and long while the frames come slowly (hidden, throttled: nobody's looking,
## so it bakes in big blocks at full speed).
##
## A frame's bake work is budgeted, not just its draws (Dominic: the UI froze on the Steam Deck
## while the army baked). The image work between renders (pixelize, shadows, cuts) runs on worker
## threads (off_thread), and a bake's main-thread steps (building a model, reading a render back)
## wait for the next frame once this frame's bake work is over BUDGET_MS (breathe).

const BUDGET_MS := 8          # ms of bake work on the main thread (draws, readbacks, keeping results) per frame while the window draws smoothly
const BUDGET_HIDDEN_MS := 500 # ... while frames come slowly or the window can't draw (nobody's looking)
const DRAW_PIXELS := 2048 * 2048   # bake pixels drawn per frame while the window draws smoothly: a building's frame
const SLOW_RUN := 3           # ... this many frames running
const SLOW_FRAME := 0.1       # a gap this long between frames (not counting the bake's own work) means we're hidden or throttled

signal drawn

static var on_demand := true  # false: the old way, wait for the engine's next frame (tests compare the two)
static var draws := 0         # forced draws so far, and the time they took (bake timing reports)
static var draw_usec := 0
static var _clock: Node = null
static var _hidden := false   # frames are coming slowly: the big budget
static var _quitting := false # the game is shutting down: no bake goes on (_next_frame)
static var _halt := Halt.new()
static var _made := []        # nodes built (build) that may not be in the tree yet: freed if the game quits first
static var _tasks := {}       # worker tasks under way (off_thread): the game waits for them when it quits
static var _slow := 0         # slow frames running (SLOW_RUN)
static var _frame_t := 0      # when this frame started (usec): bake work is counted from here
var _queue: Array = []        # viewports waiting for a draw
var _last := 0                # when the clock's work last frame ended


static func _ensure() -> void:
	if _clock == null or not is_instance_valid(_clock):
		_clock = new()
		_clock.name = "BakeClock"
		_frame_t = Time.get_ticks_usec()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_clock)


## Render this viewport once, now-ish, and return when its texture holds the result.
static func render(vp: SubViewport) -> void:
	if not on_demand:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		return
	_ensure()
	_clock._queue.append(vp)
	while _clock._queue.has(vp):   # (a draw may leave it for the next frame: DRAW_PIXELS)
		await _clock.drawn


## A viewport's render as an Image, read back without holding a frame up: the GPU copies it out
## while the frames go on (a 2048 px building frame read straight back held one up for 25 to 75
## ms: get_image waits for the GPU). Hidden, or with no RenderingDevice (the compatibility
## renderer), it's read straight back; the pixels are the same either way.
static func read(vp: SubViewport) -> Image:
	var rd := RenderingServer.get_rendering_device()
	if rd == null or _hidden:
		return vp.get_texture().get_image()
	var tex := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid())
	var fmt := rd.texture_get_format(tex)
	if fmt.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM:
		return vp.get_texture().get_image()
	var out := []
	if rd.texture_get_data_async(tex, 0, func(data: PackedByteArray): out.append(data)) != OK:
		return vp.get_texture().get_image()
	while out.is_empty():
		await _next_frame()
	return Image.create_from_data(fmt.width, fmt.height, false, Image.FORMAT_RGBA8, out[0])


## The next frame, for a bake waiting on one. Once the game is quitting it never comes: a bake
## woken mid-shutdown went on building with what had been freed (signal 11 on quitting mid-bake).
static func _next_frame() -> void:
	await Engine.get_main_loop().process_frame
	if _quitting:
		await _halt.never


class Halt extends RefCounted:
	signal never


## Bake work done this frame so far, in usec.
static func spent() -> int:
	_ensure()
	return Time.get_ticks_usec() - _frame_t


static func budget_usec() -> int:
	return (BUDGET_HIDDEN_MS if _hidden else BUDGET_MS) * 1000


## Wait for the next frame if this one's bake work is over budget (call between main-thread steps).
static func breathe() -> void:
	if spent() > budget_usec():
		await _next_frame()


## Run f on a worker thread and return what it returns, the frames going on meanwhile. Only for
## work on Images and arrays (no nodes in the tree, no textures, nothing another bake changes).
## The result is the same either way: hidden, it just runs here.
static func off_thread(f: Callable) -> Variant:
	if _hidden:
		return f.call()   # nobody's looking: no frame to keep free, and a hidden frame comes slowly
	return await _on_thread(f)


static func _on_thread(f: Callable) -> Variant:
	_ensure()
	var out := []
	var task := WorkerThreadPool.add_task(func(): out.append(f.call()))
	_tasks[task] = true
	while not WorkerThreadPool.is_task_completed(task):
		await _next_frame()
	if _tasks.has(task):
		WorkerThreadPool.wait_for_task_completion(task)
		_tasks.erase(task)
	return out[0]


## Build a model (nodes, meshes, materials) here on the main thread, in a frame with budget left.
## (Built on a worker thread, a build and the game's own frame now and then waited on each other
## for good: the game hung. Only Images and arrays go to threads: off_thread.)
static func build(f: Callable) -> Variant:
	await breathe()
	_ensure()
	_made = _made.filter(func(n): return is_instance_valid(n) and not n.is_inside_tree())
	var made = f.call()
	_track(made)
	return made


## Every node in a build's result (itself, or in its Dictionary or Array), in _made.
static func _track(v) -> void:
	if typeof(v) == TYPE_OBJECT:
		if is_instance_valid(v) and v is Node:   # (a build may free some of what it made: a stage's banner)
			_made.append(v)
	elif v is Dictionary:
		for x in v.values():
			_track(x)
	elif v is Array:
		for x in v:
			_track(x)


## Quitting mid-bake: the worker tasks under way finish first (a cache write still compressing as
## the engine shut down crashed it, signal 11 on the Deck).
## And models built but not yet put in the tree (a bake waits a frame or more for budget between
## the two) are freed: left over, they crashed the engine as it shut down (signal 11, Deck).
func _exit_tree() -> void:
	_quitting = true
	for task in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()
	for n in _made:
		if is_instance_valid(n) and not n.is_inside_tree():
			n.free()
	_made.clear()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last = Time.get_ticks_usec()
	get_tree().process_frame.connect(_frame_start)   # (connected first: before any bake that waits on a frame)


## A frame starts: bake work counts from here. Hidden when the time since the clock's work last
## frame ended has been long SLOW_RUN frames running, judged only after frames that kept to the
## small budget: a big frame's work spills into that time (its frees, the GPU catching up on its
## draws), so it looks hidden and would stay hidden (it did, twice); and one slow frame is a hiccup
## (the GPU), not a hidden window (taken for one, it made the next frame half a second long).
## After a big frame comes a small one, to look again.
func _frame_start() -> void:
	var now := Time.get_ticks_usec()
	if _last - _frame_t <= BUDGET_MS * 2000:   # the bake's work last frame was small: the gap is the window's
		_slow = _slow + 1 if (now - _last) / 1e6 > SLOW_FRAME else 0
		_hidden = not DisplayServer.window_can_draw() or _slow >= SLOW_RUN
	else:
		_hidden = not DisplayServer.window_can_draw()
	_frame_t = now


func _process(_delta: float) -> void:
	var first := true   # at least one draw a frame, whatever else used the budget
	var pixels := 0     # drawn this frame: the GPU's share of the bake (it held the game's frame up after big ones)
	while not _queue.is_empty() and (first or (spent() < budget_usec() and (_hidden or pixels < DRAW_PIXELS))):
		first = false
		var batch := []
		var later := []
		for vp in _queue:
			var n: int = vp.size.x * vp.size.y if is_instance_valid(vp) else 0
			if batch.is_empty() or _hidden or pixels + n <= DRAW_PIXELS:
				batch.append(vp)
				pixels += n
			else:
				later.append(vp)
		_queue = later
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
