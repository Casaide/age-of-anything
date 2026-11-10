// The OS cursors in a real window (#222): every kind makes a cursor and takes over, hiding it leaves the mouse free.
// Run from src: lobster cursor_check.lobster
import from "../creel/src"
import std
import vec
import color
import gl
import game.cursor_images

fatal(gl.window("cursor check", 200, 200, gl.window_init_no_vsync))
var failed = 0
def expect(ok:bool, what:string):
    if not ok:
        print "FAIL: {what}"
        failed++

for(CURSOR_KINDS) kind:
    let c = gl.cursor_image(cursor_image(kind, 1), cursor_image(kind, 2), cursor_hot(kind))
    expect(c != nil, "{kind} makes a cursor")
    if c:
        expect(gl.cursor_set(c), "{kind} is set")
        gl.frame()
expect(gl.cursor_image("icons/os_cursor/none.png", "", int2_0) == nil, "a missing image is nil")
expect(gl.cursor_set_default(), "back to the system arrow")
let before = gl.mouse_pos(0)
expect(gl.cursor_visible(false), "hidden")
gl.frame()
expect(gl.mouse_pos(0) == before, "hiding doesn\'t move the mouse or stop it reading")
expect(gl.cursor_visible(true), "shown")
gl.frame()
print "cursor check: {failed} failed"
if failed > 0: set_exit_code(1)
