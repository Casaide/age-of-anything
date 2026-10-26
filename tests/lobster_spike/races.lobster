// The races the Lobster generator makes, one line of sorted JSON each (compared with race_dump.gd).
// Run: lobster races.lobster -- [mods:a,b] rules "prompt" ...  (prints them)
import std
import dictionary
import gen.json
import gen.sha256
import gen.rng
import gen.datalib
import gen.identity
import gen.pricing
import gen.heroes
import gen.generator
import gen.mods

var args = command_line_arguments()
lib_load("../../data")
id_load("../../data")
if args.length and starts_with(args[0], "mods:"):
    mods_use(tokenize(substring(args[0], 5, args[0].length - 5), ",", " "))
    args = args.slice(1, -1)
var reroll = 0
if args.length and starts_with(args[0], "reroll:"):
    reroll = string_to_int(substring(args[0], 7, args[0].length - 7))
    args = args.slice(1, -1)
let rules = load_rules(args[0])
for(args.slice(1, -1)) p: print stringify(generate(p, rules, reroll))
