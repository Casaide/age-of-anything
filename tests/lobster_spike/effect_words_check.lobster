// Research effects in words (gen/effect_words.lobster) against Godot's for every research in data/tech.json:
//   godot --headless --path . --script res://tests/lobster_spike/effect_words_dump.gd > /tmp/effects.tsv
//   lobster effect_words_check.lobster -- /tmp/effects.tsv
import std
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.effect_words

let want = dictionary<string, string>(256)
for(tokenize(assert read_file(command_line_arguments()[0]), "\n", "")) l:
    let tab = find_string(l, "\t")
    if tab > 0: want.set(substring(l, 0, tab), substring(l, tab + 1, l.length - tab - 1))
var ok = 0
var bad = 0
for(glist(load_json("../../data/tech.json"), "research")) r:
    let id = gstr(r, "id", "")
    let got = if has(r, "effect"): gstr(r, "effect", "") else: effect_text(glist(r, "effects"))
    let w = want.get(id, "<missing>")
    if got == w: ok++
    else:
        bad++
        print("DIFF {id}\n  godot:   {w}\n  lobster: {got}")
print("{ok} of {ok + bad} the same")
