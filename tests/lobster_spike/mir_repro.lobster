// Lobster --mir miscompile (2026-10-25): prints 400890532 on the default JIT; under --mir a VM error, a garbage
// index. A mutable global (Wd) read in an and-chain that returns from inside a for() block. Reading the index into
// a local first (let at = yy * Wd + xx) avoids it. Run: lobster mir_repro.lobster ; lobster --mir mir_repro.lobster
import std

var Wd = 0
var Hd = 0
Wd = 64
Hd = 64
var grid = map(64 * 64) c: if c % 7 == 0: c else: 0

def first_near(x:int, y:int) -> int:
    let cx = clamp(x / 1000, 0, Wd - 1)
    let cy = clamp(y / 1000, 0, Hd - 1)
    for(4) rr:
        var dy = -rr
        while dy <= rr:
            var dx = -rr
            while dx <= rr:
                if max(abs(dx), abs(dy)) == rr:
                    let xx = cx + dx
                    let yy = cy + dy
                    if xx >= 0 and yy >= 0 and xx < Wd and yy < Hd and grid[yy * Wd + xx] != 0: return grid[yy * Wd + xx]
                dx++
            dy++
    return 0

var sum = 0
for(200000) k:
    sum += first_near((k * 7919) % 64000, (k * 104729) % 64000)
print sum
