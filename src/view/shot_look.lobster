// ------------------------------------------------------------------ how fast a shot looks
// View only (#175): a shot is drawn over part of its flight, launched late, and lands on the sim's tick. When it lands, and
// so dodging and balance, is the sim's alone: the sim never reads this.

let SHOT_DRAWN_SHARE = 0.5  // of its flight a shot is seen flying
let SHOT_DRAWN_MIN = 0.2    // seconds, at least (a short shot isn't a flicker)

// Seconds a flight of that many seconds is seen for.
def shot_drawn_time(flight:float) -> float: return min(flight, max(flight * SHOT_DRAWN_SHARE, SHOT_DRAWN_MIN))

// How far along its way a shot is drawn, that many seconds into its flight (1: landed); below 0: not yet launched.
def shot_drawn_u(elapsed:float, flight:float) -> float:
    let drawn = shot_drawn_time(flight)
    if drawn <= 0.0: return 1.0
    return min(1.0, (elapsed - (flight - drawn)) / drawn)
