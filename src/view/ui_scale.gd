extends RefCounted
## How big the HUD and the menus draw. A window counts physical pixels, so on a dense screen
## (a Retina MacBook: scale 2) everything laid out in pixels came out half size (Dominic: "all a
## bit too small on macbook"). The UI scales by the screen's density, held down so the layout
## still fits the window it's in. Only the UI: the game world keeps its own zoom steps.
## The lobby scales the whole window (Window.content_scale_factor); the match scales its HUD
## layer only, so the map stays in whole art pixels.

const DESIGN := Vector2(1600, 900)   # project.godot's window size: the layout's home, in UI pixels
const HUD_NEEDS := Vector2(1480, 760)   # the smallest view the match HUD is laid out for: the widest panel (a range training, with research) beside the minimap
const MENU_NEEDS := Vector2(1440, 910)  # the lobby's banners and rosters


## The screen's density: its own scale where the OS gives one (macOS, Wayland), else from its DPI
## (a 27" 4K monitor is ~163 dpi: 1.5; an ordinary 24" is ~92: 1).
static func screen() -> float:
	var s := DisplayServer.screen_get_scale()
	if s > 1.0:
		return s
	return clampf(snappedf(DisplayServer.screen_get_dpi() / 110.0, 0.25), 1.0, 2.0)


## The UI scale for a window: the screen's density, but no bigger than lets `needs` fit, never below 1.
static func factor(win: Window, needs: Vector2) -> float:
	var px := Vector2(win.size)
	return maxf(1.0, minf(screen(), minf(px.x / needs.x, px.y / needs.y)))


## Once per run: a window opened at the design size on a dense screen is a quarter of the size
## it should be (1600 x 900 physical pixels is half a MacBook's width). Grow it to the design
## size in UI pixels, within the screen, centred.
static func fit_window(win: Window) -> void:
	if win.has_meta("ui_fitted") or win.mode != Window.MODE_WINDOWED or win.size != Vector2i(DESIGN):
		return
	win.set_meta("ui_fitted", true)
	var s := screen()
	if s <= 1.0:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var want := DESIGN * s
	var fit := minf(1.0, minf(usable.size.x * 0.96 / want.x, usable.size.y * 0.96 / want.y))
	win.size = Vector2i(want * fit)
	win.position = usable.position + (usable.size - win.size) / 2
