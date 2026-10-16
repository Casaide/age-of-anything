extends Node
## The controller layer every screen shares (milestone 20): which input was used last (a pad
## press or stick shows the pad HUD and hides the mouse; moving the mouse or a key brings the
## mouse game back), the pad's buttons as one merged state over every connected pad (the Deck's
## controls are one Steam virtual pad; a desk may have two), the pad's A and B added to the UI's
## accept and cancel, focus put into the menu that's up, the Steam keyboard for text boxes, rumble.
## One node at the tree's root, made on first use: PadMode.of(get_tree()).

signal changed(on: bool)   # pad mode turned on or off

const STICK_DEAD := 0.22     # stick travel ignored (pads rest a little off centre)
const WAKE := 0.5            # stick travel that counts as using the pad
const MOUSE_WAKE_PX := 80.0  # mouse travel, within MOUSE_WAKE_S, that brings the mouse back (the Deck's trackpad is a
const MOUSE_WAKE_S := 0.4    # mouse): a brush of the pad or the cursor moved by the system doesn't (Dominic: the stick's
                             # focus kept jumping back to the top button)
const BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const LT := 100   # the triggers, read as buttons past half travel
const RT := 101

const PadGlyph := preload("res://src/view/pad_glyph.gd")

static var instance: Node = null

var on := false
var menus: Array = []        # Controls that take focus when up (the last visible one wins)
var _down := {}              # button -> held this frame
var _was := {}               # button -> held last frame
var _since := {}             # button -> seconds since it went down
var _travel := 0.0           # mouse travel lately (MOUSE_WAKE_PX)
var _travel_at := 0.0
var _prompt: Control         # the A badge beside the focused button, so it's clear what's picked and how to press it
var fake = null              # tests (tests/pad_check.gd): {buttons: {button: true}, left, right: Vector2}; real pads ignored


static func of(tree: SceneTree) -> Node:
	if instance == null:
		instance = load("res://src/view/pad_mode.gd").new()
		instance.name = "PadMode"
		tree.root.add_child.call_deferred(instance)
	return instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var top := CanvasLayer.new()
	top.layer = 120   # over every menu and page
	add_child(top)
	_prompt = PadGlyph.make("A", 30)
	_prompt.visible = false
	top.add_child(_prompt)
	process_priority = -100   # buttons are read before any screen looks at them
	# The menus' accept and cancel on the pad (Godot's defaults give the pad only the arrows).
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var e := InputEventJoypadButton.new()
		e.button_index = pair[1]
		e.device = -1
		InputMap.action_add_event(pair[0], e)
	# Which pads the game sees, in the log (on the Deck: is Steam sending a pad, or keys and a mouse?).
	Input.joy_connection_changed.connect(_on_joy)
	print("pads at start: ", Input.get_connected_joypads().map(func(d): return "%d %s" % [d, Input.get_joy_name(d)]))


func _on_joy(dev: int, connected: bool) -> void:
	print("pad %d %s: %s" % [dev, "connected" if connected else "gone", Input.get_joy_name(dev)])


## Unhooked on the way out: the pads report gone as the app quits, after this node (a lambda
## left on the signal crashed the quit on macOS).
func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy):
		Input.joy_connection_changed.disconnect(_on_joy)


func _input(event: InputEvent) -> void:
	if fake != null:
		return   # a test is playing: the real mouse and keys don't switch modes under it
	if event is InputEventJoypadButton and event.pressed:
		_set_on(true)
		_maybe_keyboard(event)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > WAKE:
		_set_on(true)
	elif event is InputEventMouseMotion:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _travel_at > MOUSE_WAKE_S:
			_travel = 0.0
		_travel_at = now
		_travel += event.relative.length()
		if _travel > MOUSE_WAKE_PX:
			_set_on(false)
	elif (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		_set_on(false)
	# Arrows, Enter or a pad in a menu with nothing focused: focus its first button, so the menus
	# also work for a pad that Steam turned into keys (a keyboard layout on the Deck).
	if not on and event is InputEventKey and event.pressed and get_viewport().gui_get_focus_owner() == null:
		for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
			if event.is_action(a) and _focus_menu():
				get_viewport().set_input_as_handled()
				return


func set_on(v: bool) -> void:
	_set_on(v)


func _set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	_travel = 0.0
	changed.emit(on)


func _process(delta: float) -> void:
	_was = _down.duplicate()
	_down = {}
	for b in BUTTONS:
		_down[b] = false
	_down[LT] = false
	_down[RT] = false
	if fake != null:
		for b in fake.buttons:
			_down[b] = fake.buttons[b]
	for dev in ([] if fake != null else Input.get_connected_joypads()):
		for b in BUTTONS:
			_down[b] = _down[b] or Input.is_joy_button_pressed(dev, b)
		_down[LT] = _down[LT] or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5
		_down[RT] = _down[RT] or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	for b in _down:
		_since[b] = 0.0 if pressed(b) else _since.get(b, 0.0) + delta
	if on:
		_focus_menu()
	_place_prompt()


## The console way: the focused button gets the A badge on its right (inside a wide button's right
## end; beside a small one, or on its left at the screen's edge), sized to the button. Only in pad mode, only for things A presses.
func _place_prompt() -> void:
	var f := get_viewport().gui_get_focus_owner()
	_prompt.visible = on and f != null and f.is_visible_in_tree() and (f is BaseButton or f is LineEdit) \
		and not (f is BaseButton and f.disabled)
	if not _prompt.visible:
		return
	var r := f.get_global_rect()
	var h := clampf(r.size.y * 0.55, 22.0, 40.0)
	_prompt.size = Vector2(h, h)
	var x := r.end.x + 10.0   # a small button (<, >, the dice): beside it, on the right (Dominic)
	if r.size.x >= 4.0 * h:
		x = r.end.x - h * 1.45   # a wide one: inside its right end (its words are centred), clear of its neighbours
	elif x + h > get_viewport().get_visible_rect().size.x - 4.0:
		x = r.position.x - h - 10.0   # at the screen's right edge: on its left
	_prompt.position = Vector2(x, r.get_center().y - h * 0.5)
	_prompt.queue_redraw()


## Held now.
func held(b: int) -> bool:
	return _down.get(b, false)


## Went down this frame.
func pressed(b: int) -> bool:
	return _down.get(b, false) and not _was.get(b, false)


## Came up this frame.
func released(b: int) -> bool:
	return _was.get(b, false) and not _down.get(b, false)


## Seconds since it last went down (how long it has been held, while held).
func held_for(b: int) -> float:
	return _since.get(b, 0.0)


## A stick, merged over the pads, with the dead zone taken out (0..1 beyond it).
func stick(right: bool) -> Vector2:
	var v: Vector2 = Vector2.ZERO if fake == null else fake.get("right" if right else "left", Vector2.ZERO)
	for dev in ([] if fake != null else Input.get_connected_joypads()):
		var s := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X),
			Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y if right else JOY_AXIS_LEFT_Y))
		if s.length() > v.length():
			v = s
	var l := v.length()
	if l < STICK_DEAD:
		return Vector2.ZERO
	return v / l * minf(1.0, (l - STICK_DEAD) / (1.0 - STICK_DEAD))


## A short buzz on every pad (only in pad mode): an order heard, an alarm.
func rumble(weak: float, strong: float, secs: float) -> void:
	if not on:
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak, strong, secs)


## Focus the first thing a pad can press in a menu that's up, when nothing has focus (a menu
## just opened, or the pad was just picked up). Menus register here. True when it focused one.
func _focus_menu() -> bool:
	var vp := get_viewport()
	if vp.gui_get_focus_owner() != null and vp.gui_get_focus_owner().is_visible_in_tree():
		return false
	menus = menus.filter(func(m): return is_instance_valid(m))
	for k in range(menus.size() - 1, -1, -1):
		if menus[k].is_visible_in_tree():
			var first = menus[k].get_meta("pad_first", null)   # a menu may say where to start (Start Battle)
			if first is Control and is_instance_valid(first) and first.is_visible_in_tree():
				first.grab_focus()
				return true
			return focus_first(menus[k])
	return false


static func focus_first(root: Control) -> bool:
	for c in root.get_children():
		if not (c is Control) or not c.visible:
			continue
		if (c is BaseButton or c is LineEdit) and c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and c.disabled):
			c.grab_focus()
			return true
		if focus_first(c):
			return true
	return false


## A in a text box on Linux (the Deck): Steam's on-screen keyboard (in Game Mode it opens over
## the game; elsewhere the URL does nothing).
func _maybe_keyboard(event: InputEventJoypadButton) -> void:
	if event.button_index == JOY_BUTTON_A and OS.get_name() == "Linux" and get_viewport().gui_get_focus_owner() is LineEdit:
		OS.shell_open("steam://open/keyboard")
