extends Node
## The battlefield on a pad (milestone 20; the button table is in docs/milestones/m20-steam-deck.md).
## A reticle near the screen's middle stands in for the mouse: the left stick moves the camera
## and the reticle with it, the right stick nudges the reticle off centre, and it snaps to a unit
## near it. Selection is by area (hold A: a circle grows and sweeps up your units), orders are one
## button each, commands are on a wheel (tap A on what's selected, or hold RB). Everything here goes through the match's own
## functions (select_at, smart_order, place_at...), as the mouse does: no second way to play.

const PadMode := preload("res://src/view/pad_mode.gd")
const PadWheel := preload("res://src/view/pad_wheel.gd")
const PadGlyph := preload("res://src/view/pad_glyph.gd")
const Iso := preload("res://src/view/iso.gd")
const Commands := preload("res://src/sim/commands.gd")
const Economy := preload("res://src/sim/economy.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")
const HeroLine := preload("res://src/heroes.gd")

const PAN := 1300.0         # screen px a second at full tilt
const NUDGE := 900.0        # the reticle's own speed, screen px a second
const NUDGE_MAX := 0.42     # how far off centre it goes, of half the screen
const SNAP_PX := 22.0       # screen px: the reticle catches a unit this close
const TAP := 0.22           # seconds: a press shorter than this is a tap
const DOUBLE := 0.35        # seconds between two taps that make a double tap
const CIRCLE_START := 34.0  # screen px: the selection circle when it appears...
const CIRCLE_GROW := 300.0  # ...and how fast it grows, px a second...
const CIRCLE_MAX := 0.42    # ...up to this much of the screen's smaller side
const GROUP_HOLD := 0.5     # seconds on the d-pad to store a group
const RB_HOLD := 0.3        # seconds on RB to open the selection's wheel (a shorter press: your soldiers)
const RING := Color("#f2e9c9")

var game: Node              # the match (scenes/sim_debug.gd)
var pad: Node               # PadMode
var wheel: PadWheel
var hints: VBoxContainer    # what the buttons do now, over the minimap
var offset := Vector2.ZERO  # the reticle off the screen's middle, screen px
var circle := 0.0           # the selection circle's radius, screen px (0: none)
var sweep := {}             # unit id -> true: taken by the circle so far
var _tap_at := {}           # button -> when it was last tapped (msec), for double taps
var _lb_used := false       # LB was held as a modifier this press (so its release isn't a tap)
var _rb_wheel := false      # this RB press opened the wheel (so its release isn't a tap)
var _cycle_all := []        # the selection before LB started cycling its kinds
var _cycle_k := -1
var _hint_sig := ""
var _tc_k := -1


func setup(g: Node) -> void:
	game = g
	pad = PadMode.of(g.get_tree())
	wheel = PadWheel.new()
	wheel.panel = g.panel
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.hud_root.add_child(wheel)
	hints = VBoxContainer.new()
	hints.add_theme_constant_override("separation", 5)
	hints.anchor_left = 1.0
	hints.anchor_right = 1.0
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.hud_root.add_child(hints)
	pad.changed.connect(_on_mode)
	_on_mode(pad.on)


func _on_mode(on: bool) -> void:
	game.panel.compact = on
	game.camera.edge_scroll = not on   # the hidden mouse may rest on an edge
	hints.visible = on
	if not on:
		_end_circle(false)
		wheel.close()


## Where the reticle points, in canvas coordinates (snapped to a unit near it).
func pointer() -> Vector2:
	var at := _raw()
	var best: float = SNAP_PX / game.camera.zoom.x
	var out := at
	for id in game.views:
		var v: Node2D = game.views[id]
		if not v.visible:
			continue
		var d: float = game._body(v).distance_to(at)
		if d < best:
			best = d
			out = game._body(v)
	return out


func _raw() -> Vector2:
	return game.camera.get_screen_center_position() + offset / game.camera.zoom.x


## True while the pad is playing the battlefield (not in a menu or page).
func live() -> bool:
	return pad.on and not game.baking and game.world != null and not game.tech_tree.visible \
		and not (game.pause_menu != null and game.pause_menu.visible)


func _process(delta: float) -> void:
	hints.visible = live()   # (not over a menu or page)
	if not pad.on or game.world == null or game.baking:
		return
	if game.tech_tree.visible or game.tech_tree.closed_frame == Engine.get_process_frames():
		return   # (the page reads the pad itself: scenes/tech_tree.gd)
	if game.pause_menu != null and game.pause_menu.visible:
		if game.saves_page != null and (game.saves_page.visible or game.saves_page.closed_frame == Engine.get_process_frames()):
			return   # (B on the saves page goes back to the menu: src/view/ui/saves_page.gd)
		if (pad.pressed(JOY_BUTTON_START) or pad.pressed(JOY_BUTTON_B)) and game.world.winner < 0:
			game._show_pause_menu(false)
		return
	if pad.pressed(JOY_BUTTON_START):
		_end_circle(false)
		wheel.close()
		if game.vs_ai:
			game._toggle_pause_menu()
		else:
			game.clock.paused = not game.clock.paused
		return
	if _wheel():   # (the camera holds still under it)
		_hints()
		return
	_camera(delta)
	_select(delta)
	_orders()
	_quick(delta)
	_hints()


func _camera(delta: float) -> void:
	var cam: Camera2D = game.camera
	var vp: Vector2 = game.get_viewport_rect().size
	var l: Vector2 = pad.stick(false)
	var pan := l * PAN
	var r: Vector2 = pad.stick(true)
	if true:
		var lim := vp * 0.5 * NUDGE_MAX
		offset += r * NUDGE * delta
		var over := offset - offset.clamp(-lim, lim)   # past the rim: the camera follows
		offset = offset.clamp(-lim, lim)
		pan += over / maxf(delta, 0.001)
	if pan != Vector2.ZERO:
		cam.look_at_point(cam.position + pan * delta / cam.zoom.x)
	if pad.pressed(JOY_BUTTON_RIGHT_STICK):
		offset = Vector2.ZERO
	if pad.pressed(JOY_BUTTON_LEFT_STICK):
		var mine: Array = game._selected_by_owner()[game.active]
		if not mine.is_empty() and game.views.has(mine[0]):
			var c := Vector2.ZERO
			var n := 0
			for id in mine:
				if game.views.has(id):
					c += game.views[id].position
					n += 1
			cam.look_at_point(c / n)
		elif game.selected_building != 0:
			cam.look_at_point(game.bviews[game.selected_building].position if game.bviews.has(game.selected_building) else cam.position)
		offset = Vector2.ZERO
	if pad.pressed(PadMode.RT):
		cam.zoom_at(1.1, _raw())
	if pad.pressed(PadMode.LT):
		cam.zoom_at(1.0 / 1.1, _raw())


## The wheel, while it's up (tap A on your building, or on a unit you have selected, opens it):
## either stick points, A chooses, LB turns pages, B closes. The camera holds still under it
## (Dominic: the stick that picked also moved the camera). True while it's up.
func _wheel() -> bool:
	if not wheel.visible:
		return false
	var items := _wheel_items()
	if items.is_empty():
		wheel.close()
		return false
	wheel.show_buttons(items)
	var l: Vector2 = pad.stick(false)
	var r: Vector2 = pad.stick(true)
	wheel.point(r if r.length() >= l.length() else l)
	if pad.pressed(JOY_BUTTON_LEFT_SHOULDER):
		wheel.turn_page()
		_lb_used = true
	if pad.pressed(JOY_BUTTON_B):
		wheel.close()
	elif pad.pressed(JOY_BUTTON_A):
		_pick()
		circle = -1.0   # this A is the wheel's: its release selects nothing
	return true


## Open the selection's wheel (if it has any buttons), a worker's at the top of its build pages
## (Dominic: closed on Civilian without choosing, the next open was stuck on Civilian).
func open_wheel() -> void:
	game.build_page = ""
	game._update_panel()
	if _wheel_items().is_empty():
		return
	wheel.look = UiTheme.look(game.hud_family if game.hud_family != "?" else "")
	wheel.show_buttons(_wheel_items())
	game.audio.play("ui_tip")


## Press the pointed button. The wheel stays up for more of the same (train five: A five times;
## a build page opened: pick from it) and closes once there's something to aim on the map or an
## order was given (stop, a stance).
func _pick() -> void:
	var hot: int = wheel.hot
	var group := ""
	if hot >= 0:
		group = str(wheel.pages[wheel.page][1][hot].get("group", ""))
	if not wheel.choose():
		return

	if game.placing != "" or game.arming_attack or game.arming_ability or group in ["Orders", "Stance"]:
		wheel.close()
		return
	game._update_panel()
	if _wheel_items().is_empty():
		wheel.close()


## The wheel's buttons: the panel's, for what you have selected (nothing for a foe's); for units,
## first "all of these on screen" (the mouse's double-click; on the pad a double tap of A kept
## catching the tap-tap that opens the wheel).
func _wheel_items() -> Array:
	var mine: Array = game._selected_by_owner()[game.active]
	var own_building: bool = game.selected_building != 0 and game.world.buildings.index_of(game.selected_building) >= 0 \
		and game.world.buildings.owner[game.world.buildings.index_of(game.selected_building)] == game.active
	if not mine.is_empty():
		var w = game.world
		var t: Dictionary = w.types[w.units.kind[w.units.index_of(mine[0])]]
		var all := {"icon": game.kit.icons.get("%d:%s" % [t.player, HeroLine.line_key(t.recipe)]), "text": "All on screen", "key": "", "cost": "",
			"enabled": true, "group": "Orders", "tip": "[b]All on screen[/b]\nEvery unit of yours on screen of the kinds selected.",
			"action": _all_kinds_on_screen}
		return [all] + game.panel.content.get("buttons", [])
	if own_building:
		return game.panel.content.get("buttons", [])
	return []


## Every unit of yours on screen of the kinds now selected.
func _all_kinds_on_screen() -> void:
	var w = game.world
	var kinds := {}
	for id in game._selected_by_owner()[game.active]:
		kinds[w.units.kind[w.units.index_of(id)]] = true
	var view := Rect2(game.camera.get_screen_center_position() - game.get_viewport_rect().size * 0.5 / game.camera.zoom,
		game.get_viewport_rect().size / game.camera.zoom)
	for i in w.units.count():
		var id: int = w.units.id[i]
		if w.units.owner[i] == game.active and kinds.has(w.units.kind[i]) and game.views.has(id) and game.views[id].visible \
				and view.has_point(game.views[id].position):
			game.selected[id] = true
	game._say("select", game.active)


## A: tap to select, double-tap for all of that kind on screen, hold for the circle. While
## placing, A places (walls: hold at one end, release at the other); after an armed order
## (attack-move, the race's ability), A gives it there.
func _select(delta: float) -> void:
	var a := JOY_BUTTON_A
	var add: bool = pad.held(JOY_BUTTON_LEFT_SHOULDER)
	if add and (pad.pressed(a) or pad.pressed(JOY_BUTTON_X) or pad.pressed(JOY_BUTTON_Y)):
		_lb_used = true
	if game.arming_attack or game.arming_ability:
		if pad.pressed(a):
			_give_armed()
		return
	if game.placing != "":
		_place(a, add)
		return
	if pad.pressed(a):   # (no double tap: tap, then tap again, is how a selection's wheel opens; Dominic)
		sweep = {}
		circle = 0.0
	if pad.held(a) and circle >= 0.0 and pad.held_for(a) >= TAP:
		var vp: Vector2 = game.get_viewport_rect().size
		circle = minf(CIRCLE_START + (pad.held_for(a) - TAP) * CIRCLE_GROW, minf(vp.x, vp.y) * CIRCLE_MAX)
		_sweep()
	if pad.released(a):
		if circle > 0.0:
			_end_circle(true, add)
		elif circle == 0.0:
			_tap(add)
		circle = 0.0


## Tap A: select what's under the reticle; tap again on what's already selected (a unit of the
## selection, or the selected building of yours) for its wheel. The first tap only selects, so
## a building's progress can be looked at without its commands coming up (Dominic).
func _tap(add: bool) -> void:
	var p := pointer()
	var u: int = game.unit_at(p)
	var w = game.world
	if u != 0 and not add and game.selected.has(u) and w.units.owner[w.units.index_of(u)] == game.active:
		open_wheel()
		return
	var before: int = game.selected_building
	game.select_at(p, add)
	var b: int = w.buildings.index_of(game.selected_building)
	if u == 0 and not add and before != 0 and game.selected_building == before and b >= 0 \
			and w.buildings.owner[b] == game.active and game.selected.is_empty():
		open_wheel()


## Every unit of yours inside the circle (on the ground: an ellipse) joins the sweep.
func _sweep() -> void:
	var c := _raw()
	var r: float = circle / game.camera.zoom.x
	var u = game.world.units
	for id in game.views:
		var i: int = u.index_of(id)
		if i < 0 or u.owner[i] != game.active or not game.views[id].visible:
			continue
		var d: Vector2 = game.views[id].ground() - c
		if Vector2(d.x, d.y * 2.0).length() <= r:
			sweep[id] = true


func _end_circle(take: bool, add := false) -> void:
	if take:
		if sweep.is_empty():
			game.select_at(pointer(), add)   # nothing of yours: a building or a foe under it, as a tap
		else:
			if not add:
				game._clear_selection()
			for id in sweep:
				if game.world.units.index_of(id) >= 0:
					game.selected[id] = true
			game._say("select", game.active)
	circle = 0.0
	sweep = {}


func _place(a: int, keep: bool) -> void:
	if game._line(game.placing):   # walls and gates: hold A at one end, release at the other
		if pad.pressed(a):
			game.wall_from = game._ghost_cell(pointer())
		elif pad.released(a) and game.wall_from.x >= 0:
			game.place_wall(game.wall_from, game._ghost_cell(pointer()), keep)
			game.wall_from = Vector2i(-1, -1)
	elif pad.pressed(a):
		game.place_at(pointer(), keep)
	if pad.released(JOY_BUTTON_LEFT_SHOULDER) and not _lb_used and game.placing != "" \
			and game.world.btypes[Economy.btype_of(game.world, game.placing)].gate:
		game.gate_along = (game.gate_along + 1) % 4


func _give_armed() -> void:
	if game.arming_attack:
		game.attack_move = true
		game.smart_order(pointer())
		game.attack_move = false
		game.arming_attack = false
	else:
		var m := Iso.pick(pointer())
		game.world.issue(game.active, Commands.ABILITY, {"ids": game.selected.duplicate(), "x": m.x, "y": m.y})
		game.arming_ability = false
	pad.rumble(0.2, 0.0, 0.06)


## X: the smart order; Y: attack-move; B: back. A held LB queues them.
func _orders() -> void:
	var queue: bool = pad.held(JOY_BUTTON_LEFT_SHOULDER)
	if pad.pressed(JOY_BUTTON_B):
		if game.arming_attack or game.arming_ability:
			game.arming_attack = false
			game.arming_ability = false
		elif game.placing != "":
			game.placing = ""
			game.wall_from = Vector2i(-1, -1)
		elif game.build_page != "":
			game.build_page = ""
		else:
			game._clear_selection()
		return
	if game.placing != "":
		return
	if pad.pressed(JOY_BUTTON_X):
		if game.arming_attack or game.arming_ability:
			_give_armed()
			return
		game.queueing = queue
		game.smart_order(pointer())
		game.queueing = false
		pad.rumble(0.15, 0.0, 0.05)
	if pad.pressed(JOY_BUTTON_Y) and _has_soldiers():
		game.attack_move = true
		game.queueing = queue
		game.smart_order(pointer())
		game.attack_move = false
		game.queueing = false
		pad.rumble(0.25, 0.0, 0.06)


func _has_soldiers() -> bool:
	return game._selected_by_owner()[game.active].any(func(id):
		return not game._is_animal(id) and not game.world.types[game.world.units.kind[game.world.units.index_of(id)]].worker)


## RB tapped: soldiers on screen (twice: all of them); RB held: the selection's wheel, which stays
## up after it's let go (Dominic: a walking unit is hard to tap with A; both ways open it); LB
## tapped: the next kind in the selection; the d-pad: idle worker, Town Centers, groups 1 and 2;
## View: the last alert.
func _quick(_delta: float) -> void:
	var rb := JOY_BUTTON_RIGHT_SHOULDER
	if pad.pressed(rb):
		_rb_wheel = false
	if pad.held(rb) and not _rb_wheel and pad.held_for(rb) >= RB_HOLD and not _wheel_items().is_empty():
		_rb_wheel = true
		open_wheel()
	if pad.released(rb) and not _rb_wheel and pad.held_for(rb) < RB_HOLD:
		var twice := Time.get_ticks_msec() - int(_tap_at.get(rb, -100000)) < DOUBLE * 1000.0
		_all_soldiers(not twice)
		_tap_at[rb] = -100000 if twice else Time.get_ticks_msec()
	var lb := JOY_BUTTON_LEFT_SHOULDER
	if pad.pressed(lb):
		_lb_used = false
	if pad.released(lb) and not _lb_used and pad.held_for(lb) < 0.4 and game.placing == "":
		_cycle_kinds()
	if pad.pressed(JOY_BUTTON_DPAD_DOWN):
		game._next_idle_worker()
	if pad.pressed(JOY_BUTTON_DPAD_UP):
		_next_town_center()
	for pair in [[JOY_BUTTON_DPAD_LEFT, 1], [JOY_BUTTON_DPAD_RIGHT, 2]]:
		var b: int = pair[0]
		if pad.held(b) and pad.held_for(b) >= GROUP_HOLD and not _tap_at.has(-b):
			_tap_at[-b] = true   # stored once per hold
			if not game._selected_by_owner()[game.active].is_empty():
				game._control_group(pair[1], true)
				game._show_line("Group %d set" % pair[1], RING)
				pad.rumble(0.3, 0.1, 0.1)
		if pad.released(b):
			if not _tap_at.has(-b):
				game._control_group(pair[1], false)
			_tap_at.erase(-b)
	if pad.pressed(JOY_BUTTON_BACK):
		game._jump_to_alert()


## Your soldiers: on screen, or every one.
func _all_soldiers(on_screen: bool) -> void:
	var w = game.world
	var view := Rect2(game.camera.get_screen_center_position() - game.get_viewport_rect().size * 0.5 / game.camera.zoom,
		game.get_viewport_rect().size / game.camera.zoom)
	var ids := []
	for i in w.units.count():
		var id: int = w.units.id[i]
		var t: Dictionary = w.types[w.units.kind[i]]
		if w.units.owner[i] != game.active or t.worker or t.has("animal") or game.sheltered.has(id):
			continue
		if on_screen and not (game.views.has(id) and view.has_point(game.views[id].position)):
			continue
		ids.append(id)
	if ids.is_empty():
		return
	game._clear_selection()
	for id in ids:
		game.selected[id] = true
	game._say("select", game.active)


## LB: only the next kind among what's selected (spears, then archers...), then all again.
func _cycle_kinds() -> void:
	var mine: Array = game._selected_by_owner()[game.active]
	if mine.is_empty():
		return
	if not _cycle_all.has(mine[0]) or mine.any(func(id): return not _cycle_all.has(id)):
		_cycle_all = mine.duplicate()
		_cycle_k = -1
	var u = game.world.units
	var kinds := []
	for id in _cycle_all:
		if u.index_of(id) >= 0 and not u.kind[u.index_of(id)] in kinds:
			kinds.append(u.kind[u.index_of(id)])
	kinds.sort()
	if kinds.size() < 2:
		return
	_cycle_k = (_cycle_k + 1) % (kinds.size() + 1)
	game._clear_selection()
	for id in _cycle_all:
		if u.index_of(id) >= 0 and (_cycle_k == kinds.size() or u.kind[u.index_of(id)] == kinds[_cycle_k]):
			game.selected[id] = true
	audio_tick()


func audio_tick() -> void:
	game.audio.play("ui_hover")


func _next_town_center() -> void:
	var bs = game.world.buildings
	var tcs := []
	for b in bs.count():
		if bs.owner[b] == game.active and game.world.btypes[bs.kind[b]].id == "town_center":
			tcs.append(bs.id[b])
	if tcs.is_empty():
		return
	_tc_k = (_tc_k + 1) % tcs.size()
	game._clear_selection()
	game.selected_building = tcs[_tc_k]
	game.selected_buildings = {tcs[_tc_k]: true}
	if game.bviews.has(tcs[_tc_k]):
		game.camera.look_at_point(game.bviews[tcs[_tc_k]].position)
	offset = Vector2.ZERO


## What the buttons do right now, over the minimap: a short list that follows the situation.
func _hints() -> void:
	var rows := []
	var mine: Array = game._selected_by_owner()[game.active]
	if wheel.visible:
		rows = [["RS", "point"], ["A", "choose"], ["B", "close"]]
		if wheel.pages.size() > 1:
			rows.append(["LB", "next page"])
	elif game.placing != "":
		rows = [["A", "hold, drag, release" if game._line(game.placing) else "place"], ["LB", "hold: keep placing"], ["B", "cancel"]]
		if game.world.btypes[Economy.btype_of(game.world, game.placing)].gate:
			rows.append(["LB", "tap: turn"])
	elif game.arming_attack or game.arming_ability:
		rows = [["A", "here"], ["B", "cancel"]]
	elif mine.is_empty() and game.selected_building == 0:
		rows = [["A", "select · hold: circle"], ["RB", "soldiers"], ["down", "idle worker"], ["up", "Town Center"]]
	else:
		rows = [["X", "order"], ["A", "on it: commands · hold: circle"], ["RB", "hold: commands"]]
		if _has_soldiers():
			rows.insert(1, ["Y", "attack-move"])
		if mine.size() > 1:
			rows.append(["LB", "tap: one kind · hold: queue"])
		rows.append(["B", "deselect"])
	var sig := str(rows)
	if sig == _hint_sig:
		return
	_hint_sig = sig
	for c in hints.get_children():
		c.queue_free()
	for r in rows:
		hints.add_child(PadGlyph.hint(r[0], r[1], 28))
	hints.offset_right = -24
	hints.offset_bottom = -(game.minimap.size.y if game.minimap.size.y > 0 else 200) - 40
	hints.offset_left = hints.offset_right
	hints.offset_top = hints.offset_bottom


## The reticle and the selection circle, drawn into the match's overlay (canvas space).
func draw(o: Node2D) -> void:
	if not live():
		return
	var z: float = game.camera.zoom.x
	var c := _raw()
	if circle > 0.0:
		o.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
		o.draw_circle(Vector2.ZERO, circle / z, Color(RING, 0.1))
		o.draw_arc(Vector2.ZERO, circle / z, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 4.0 / z)
		o.draw_arc(Vector2.ZERO, circle / z, 0.0, TAU, 64, RING, 2.0 / z)
		o.draw_set_transform(Vector2.ZERO)
		for id in sweep:   # who it has taken so far
			if game.views.has(id):
				o.draw_set_transform(game.views[id].ground(), 0.0, Vector2(1.0, 0.5))
				o.draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(RING, 0.8), 1.5 / z)
				o.draw_set_transform(Vector2.ZERO)
	var p := pointer()
	var snapped := p != c
	var kind: String = game._cursor_kind(p)
	var col := Color("#e8604c") if kind == "attack" else RING
	var r := (9.0 if snapped else 12.0) / z
	for k in 4:   # four ticks round an open ring: reads on any ground
		var a := PI * 0.25 + k * PI * 0.5
		var d := Vector2.from_angle(a)
		o.draw_line(p + d * r * 0.55, p + d * r * 1.35, Color(0, 0, 0, 0.7), 4.0 / z)
		o.draw_line(p + d * r * 0.55, p + d * r * 1.35, col, 2.0 / z)
	o.draw_arc(p, r, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 3.5 / z)
	o.draw_arc(p, r, 0.0, TAU, 24, col, 1.6 / z)
	var tex: Texture2D = game.cursors.texture(kind) if kind != "pointer" and kind != "move" else null
	if tex != null:   # what X would do here: the mouse game's cursor art, beside the reticle
		var s := tex.get_size() / z
		o.draw_texture_rect(tex, Rect2(p + Vector2(r * 1.2, r * 0.6), s), false)
