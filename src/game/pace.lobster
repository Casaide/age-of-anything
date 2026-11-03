// ------------------------------------------------------------------ frame pacing: how often the window draws
// A match at 60 frames a second, the lobby's pages at 30 (nothing there moves fast), and a minimised window not
// drawn at all (Lobster sleeps a tenth of a second a frame then; a match's sim and network go on).
// The laptop ran hot (2026-11-03): the idle title screen took 11% of a core, nearly what a match did.

let PACE_MATCH = 60.0
let PACE_MENU = 30.0

def pace(fps:float): gl.set_target_delta_time(1.0 / fps)

// Whether to draw this frame (a minimised window shows nothing).
def drawing() -> bool: return gl.visible()
