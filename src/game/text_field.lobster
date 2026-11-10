// ------------------------------------------------------------------ typing into a box (#431)
// Lobster's text input only adds what SDL types; taking a character off (backspace) is the game's. The edit, a held
// key's repeat and the caret's timing, pure (no window), so run_tests checks them; the lobby's boxes
// (game/lobby.lobster, fe_box) use them.

let TF_REPEAT_DELAY = 0.45  // a held key repeats after this long...
let TF_REPEAT_EVERY = 0.04  // ...this often
let TF_CARET_SOLID = 0.6    // the caret stays lit this long after a click or a key, then blinks
let TF_CARET_BLINK = 0.5    // on and off, each this long

// The text with its last character gone: a whole UTF-8 character, not one byte of it.
def tf_drop_last(s:string) -> string:
    if s.length == 0: return s
    var n = s.length - 1
    while n > 0 and (s[n] & 0xC0) == 0x80: n--  // (continuation bytes: 10xxxxxx)
    return s.substring(0, n)

// How often a key held for `t` seconds has fired: once when pressed, then repeating.
def tf_fires_by(t:float) -> int:
    if t < 0.0: return 0
    if t < TF_REPEAT_DELAY: return 1
    return 2 + int((t - TF_REPEAT_DELAY) / TF_REPEAT_EVERY)

// How often a held key fires this frame: it had been down `was` seconds (-1 if it was up), and now `now`.
def tf_repeats(was:float, now:float) -> int: return tf_fires_by(now) - tf_fires_by(was)

// Whether the caret is lit, `since` seconds after the last click or key in the box.
def tf_caret_on(since:float) -> bool:
    if since < TF_CARET_SOLID: return true
    return int((since - TF_CARET_SOLID) / TF_CARET_BLINK) % 2 == 1
