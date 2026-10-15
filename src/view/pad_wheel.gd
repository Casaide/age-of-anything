extends Control
## The pad's wheel (milestone 20): a ring of buttons around the screen's middle, picked by
## pointing a stick. It shows the command panel's own buttons (the same pictures, costs, enabled
## state and tooltip cards; the panel makes them) or a list it's given (the global wheel). Many
## buttons split into pages by their group (Train, Research, Orders...), turned with LB; the
## pointed one's card shows in the middle. Lives in the HUD's scaled root, sized to it.

const PadGlyph := preload("res://src/view/pad_glyph.gd")
const UiTheme := preload("res://src/view/ui/theme.gd")
const Audio := preload("res://src/view/audio.gd")

const PAGE_MAX := 10      # more than this and the groups get a page each
const POINT := 0.45       # stick travel that points at a button
const RING_MIN := 150.0
const GAP := 34.0         # between buttons on the ring (they crowded at 18)
const BIG := 1.35         # the ring's buttons, over the panel's (read at arm's length on a 7" screen)

var panel: Control        # the command panel: makes the buttons
var look := {}            # the HUD's look, for the card
var pages: Array = []     # [[caption, [button dicts]]]
var page := 0
var hot := -1             # the button pointed at on this page, or -1
var _sig := ""
var _ring: Control
var _card_slot: Control
var _tabs: HBoxContainer
var _items: Array = []    # the Buttons on the ring, in page order
var _ring_r := RING_MIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var shade := ColorRect.new()   # the battle dims a little under the wheel
	shade.color = Color(0, 0, 0, 0.28)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_card_slot = Control.new()
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_slot)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 14)
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tabs)


## Show these buttons (panel-style dicts); keeps the page and pointer while the list is the same.
func show_buttons(buttons: Array) -> void:
	var sig := str(buttons.map(func(b): return "%s:%s:%s:%s" % [b.get("group", ""), b.text, b.enabled, b.get("cost", "")]))
	visible = true
	if sig == _sig:
		_place()
		return
	var same_kind := _sig != "" and pages.size() > 0 and _page_names(buttons) == pages.map(func(p): return p[0])
	_sig = sig
	pages = []
	if buttons.size() <= PAGE_MAX:
		pages.append(["", buttons])
	else:
		for b in buttons:
			var g: String = b.get("group", "")
			if pages.is_empty() or pages[-1][0] != g:
				pages.append([g, []])
			pages[-1][1].append(b)
	if not same_kind:
		page = 0
		hot = -1
	page = clampi(page, 0, pages.size() - 1)
	_build()


func close() -> void:
	visible = false
	_sig = ""
	hot = -1


func turn_page(by := 1) -> void:
	if pages.size() > 1:
		page = posmod(page + by, pages.size())
		hot = -1
		_build()


## Point with a stick (the strongest of the two).
func point(v: Vector2) -> void:
	if v.length() < POINT or _items.is_empty():
		return
	var n := _items.size()
	var a := fposmod(v.angle() + PI * 0.5 + PI / n, TAU)   # 0 at the top, clockwise
	var k := int(a / TAU * n) % n
	if k != hot:
		hot = k
		Audio.of(get_tree()).play("ui_hover")
		_light()


## Press the pointed button. True when one was pressed.
func choose() -> bool:
	if hot < 0 or hot >= _items.size():
		return false
	var b: Dictionary = pages[page][1][hot]
	if not b.enabled:
		Audio.of(get_tree()).play("ui_nope")
		return false
	_items[hot].scale = Vector2.ONE * BIG * 0.94
	b.action.call()
	Audio.of(get_tree()).play("ui_click")   # (the panel's buttons click on press; these aren't pressed)
	return true


func _page_names(buttons: Array) -> Array:
	if buttons.size() <= PAGE_MAX:
		return [""]
	var out := []
	for b in buttons:
		if out.is_empty() or out[-1] != b.get("group", ""):
			out.append(b.get("group", ""))
	return out


func _build() -> void:
	for c in _ring.get_children():
		_ring.remove_child(c)
		c.queue_free()
	_items = []
	for b in pages[page][1]:
		var btn: Button = panel.make_button(b)
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.tooltip_text = ""
		_ring.add_child(btn)
		_items.append(btn)
	for c in _tabs.get_children():
		c.queue_free()
	if pages.size() > 1:
		_tabs.add_child(PadGlyph.make("LB", 30))
		for k in pages.size():
			var l := UiTheme.label(str(pages[k][0]).strip_edges().to_upper() if str(pages[k][0]).strip_edges() != "" else "MORE", "Caption")
			l.add_theme_font_size_override("font_size", 18)
			l.modulate = Color.WHITE if k == page else Color(1, 1, 1, 0.45)
			_tabs.add_child(l)
	_place()
	_light()


func _place() -> void:
	var mid := size * 0.5
	var n := _items.size()
	var bw: float = panel.BUTTON * BIG
	var r := maxf(RING_MIN, n * (bw + GAP) / TAU)
	for k in n:
		var a := -PI * 0.5 + TAU * k / n
		var btn: Button = _items[k]
		btn.size = Vector2(panel.BUTTON, panel.BUTTON)
		btn.pivot_offset = btn.size * 0.5
		btn.position = mid + Vector2.from_angle(a) * r - btn.size * 0.5
	_tabs.reset_size()
	_tabs.position = Vector2(mid.x - _tabs.size.x * 0.5, mid.y - r - bw * 0.5 - 52)
	_card_slot.position = mid + Vector2(r + bw * 0.5 + 36.0, 0.0)   # beside the ring, clear of its buttons
	_ring_r = r


## The pointed button lifts and glows; its card shows in the middle.
func _light() -> void:
	for k in _items.size():
		var btn: Button = _items[k]
		btn.scale = Vector2.ONE * BIG * (1.18 if k == hot else 1.0)
		btn.modulate = Color(1.15, 1.1, 1.0) if k == hot else Color(0.9, 0.9, 0.9)
		btn.z_index = 1 if k == hot else 0
	for c in _card_slot.get_children():
		c.queue_free()
	if hot < 0:
		var help := PadGlyph.hint("RS", "point, A to choose" if pages.size() < 2 else "point, A to choose, LB: next page")
		_card_slot.add_child(help)
		help.reset_size()
		help.position = Vector2(0, -help.size.y * 0.5)
		return
	var b: Dictionary = pages[page][1][hot]
	var card := UiTheme.tip_card(b.get("tip", b.text), look if not look.is_empty() else UiTheme.look(""), 0.85)
	_card_slot.add_child(card)
	card.reset_size()
	card.position = Vector2(0, -card.size.y * 0.5)
	if _card_slot.position.x + card.size.x > size.x - 12:   # no room on the right: under the ring
		card.position = Vector2(-_ring_r - panel.BUTTON * BIG * 0.5 - 36.0 - card.size.x * 0.5, _ring_r + panel.BUTTON * BIG * 0.5 + 20.0)
