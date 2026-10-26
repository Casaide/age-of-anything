// The races the Lobster generator makes, one line of sorted JSON each (compared with race_dump.gd).
// Run: lobster races.lobster -- rules "prompt" ...  (prints them)
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

let args = command_line_arguments()
lib_load("../../data")
id_load("../../data")
let rules = load_rules(args[0])
for(args.slice(1, -1)) p: print stringify(generate(p, rules, 0))
