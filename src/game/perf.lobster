// ------------------------------------------------------------------ perf:<seconds>: the drawing's cost, in the real window
// A watched match in the window, vsync on and the frame cap as the player has them, measured for that many seconds of
// play after a warm-up: each frame's work (from gl.frame's return to the next call: everything but the swap's wait and
// the cap's sleep), the frames a second, and the GPU buffers each frame made. Above a budget it fails (exit code 1).
// The laptop ran hot (2026-10-31): every gl.text made and deleted a buffer, macOS waited on each delete, and the game
// drew 120 frames a second on a ProMotion display. Headless runs never saw it.

let PERF_WARM = 4.0  // seconds of play first (the armies bake, the first frames build their buffers)
// Measured 2026-10-31 on the MacBook (ProMotion, 3024x1834): 3.3 ms median, 4.6 ms 95th, 0 buffers, 60 a second.
// Before the UI's meshes were drawn from the pool: 13.7 ms, 18.4 ms and 1500 buffers a frame (81% of the main thread).
let PERF_WORK_MEDIAN = 0.006  // seconds of work a frame, the median
let PERF_WORK_P95 = 0.009     // and the 95th percentile
let PERF_FPS_MAX = 66.0       // frames a second (the cap is 60: a 120 Hz display uncapped draws twice as often)
let PERF_BUFFERS_P95 = 0      // GPU buffers made a frame, the 95th percentile (pooled: none once the pool is full)

var perf_for = 0.0  // perf:<seconds> (0: off)
var perf_work = []::float
var perf_made = []::int
var perf_t = -1.0  // the frame's start (after gl.frame)
var perf_b = 0
var perf_wall0 = -1.0  // the measure's start
// Where a frame's work goes: seconds in each phase over the measure (perf_lap(k) at the end of phase k).
let PERF_PHASES = [ "input and sim", "ground", "collect", "sort", "sprites", "over the world", "panel", "hud", "groups", "rest" ]
let perf_phase = map(PERF_PHASES): 0.0
var perf_last = 0.0

def perf_sorted_at(xs, q:float):
    let s = copy(xs)
    qsort_in_place(s) a, b: a < b
    return s[min(s.length - 1, int(float(s.length) * q))]

// At the top of a frame: its start.
def perf_begin():
    perf_t = seconds_elapsed()
    perf_last = perf_t
    perf_b = gl.buffers_made()

// The end of phase k of a frame's work.
def perf_lap(k:int):
    if perf_for <= 0.0 or perf_wall0 < 0.0: return
    let t = seconds_elapsed()
    perf_phase[k] += t - perf_last
    perf_last = t

// At the end of a frame (clock: seconds of play): its work kept; true once the measure is done (then quit).
def perf_end(clock:float) -> bool:
    if clock < PERF_WARM or perf_t < 0.0: return false
    if perf_wall0 < 0.0: perf_wall0 = perf_t
    perf_work.push(seconds_elapsed() - perf_t)
    perf_made.push(gl.buffers_made() - perf_b)
    if clock < PERF_WARM + perf_for: return false
    let wall = seconds_elapsed() - perf_wall0
    let fps = float(perf_work.length) / wall
    let med = perf_sorted_at(perf_work, 0.5)
    let p95 = perf_sorted_at(perf_work, 0.95)
    let bmed = perf_sorted_at(perf_made, 0.5)
    let b95 = perf_sorted_at(perf_made, 0.95)
    let busy = sum(perf_work) / wall
    def tenths(x:float): return float(int(x * 10.0 + 0.5)) / 10.0
    let stats = "{tenths(fps)} fps, work {tenths(med * 1000.0)} ms median, {tenths(p95 * 1000.0)} ms 95th, buffers {bmed} / {b95}, busy {int(busy * 100.0)}%; {perf_work.length} frames, {sum(perf_made)} buffers in all"
    var bad = []::string
    if med > PERF_WORK_MEDIAN: bad.push("work median over {PERF_WORK_MEDIAN * 1000.0} ms")
    if p95 > PERF_WORK_P95: bad.push("work 95th over {PERF_WORK_P95 * 1000.0} ms")
    if fps > PERF_FPS_MAX: bad.push("{fps} frames a second, over {PERF_FPS_MAX} (the frame cap?)")
    if b95 > PERF_BUFFERS_P95: bad.push("{b95} GPU buffers a frame (95th), over {PERF_BUFFERS_P95}")
    if bad.length:
        print "perf FAIL: {concat_string(bad, "; ")}"
        set_exit_code(1)
    print "perf: {stats}"
    print "perf phases (ms a frame): {concat_string(map(PERF_PHASES) n, k: "{n} {tenths(perf_phase[k] * 1000.0 / float(perf_work.length) * 10.0) / 10.0}", ", ")}"
    return true
