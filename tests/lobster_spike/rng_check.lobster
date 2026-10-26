// model/grng.lobster against Godot's RandomNumberGenerator (rng_dump.gd's numbers).
//   godot --headless --path . --script res://tests/lobster_spike/rng_dump.gd -- /tmp/rng.txt
//   lobster rng_check.lobster -- /tmp/rng.txt

import std
import vec
import dictionary
import .gen.json
import .view.node
import .model.grng

let text = read_file(command_line_arguments()[0])
assert text
var failed = 0
for(tokenize(text, "\n", "")) line:
    let w = tokenize(line, " ", "")
    if w.length < 2: continue
    let r = grng(string_to_int(w[1]))
    var k = 2
    var bad = 0
    while k + 4 < w.length:
        let mine = [float(randi(r)), randf(r), randf_range(r, -7.0, 6.0), float(randi_range(r, -3, 11)), randfn(r, 1.5, 0.4)]
        for(5) j:
            let theirs = string_to_float(w[k + j])
            if abs(mine[j] - theirs) > 0.0000005:
                if bad < 5: print "  seed {w[1]} value {k + j - 2}: ours {mine[j]}, Godot {theirs}"
                bad++
        k += 5
    if bad: failed++
    print "{if bad: "FAIL" else: "PASS"} seed {w[1]}"
print "{failed} failed"
