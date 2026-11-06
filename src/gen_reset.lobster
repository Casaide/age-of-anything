// Writes gen/reset.lobster:
//   reset_world() puts every global of the sim (lib/) and the match setup (gen/setup, gen/start) back
//   as declared, so one process can set up and play many worlds (the balance fights, a new match);
//   stash_world() / unstash_world() set the running world aside and bring it back exactly (each
//   global's value moved, not copied: reset_world makes new containers), so fights can run mid-match.
//   gen/save.lobster: save_world(path) / load_world(path) write and read every one of those globals (one
//   WorldSave record, a flexbuffer), for saving a match.
// Run after adding a global: ./gen_reset.sh (this, then the formatter over both files).
import std

def is_word(c:int) -> bool:
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_'

def word_end(s:string, start:int) -> int:
    var i = start
    while i < s.length and is_word(s[i]): i++
    return i

def is_int(s:string) -> bool:
    let t = if s.length > 0 and s[0] == '-': substring(s, 1, -1) else: s
    for(t) c:
        if c < '0' or c > '9': return false
    return t.length > 0

def strip_end(s:string) -> string:
    var n = s.length
    while n > 0 and (s[n - 1] == ' ' or s[n - 1] == '\t'): n--
    return substring(s, 0, n)

def starts(s:string, p:string) -> bool: return find_string(s, p) == 0

def ends(s:string, p:string) -> bool:
    return s.length >= p.length and substring(s, s.length - p.length, -1) == p

// `dictionary<k, v>` of a `dictionary<k, v>(64)`, or "" if it's not one.
def dictionary_of(init:string) -> string:
    guard starts(init, "dictionary<") and ends(init, ")"):
        return ""
    let open = find_string_reverse(init, "(")
    guard open > 0 and init[open - 1] == '>' and is_int(substring(init, open + 1, init.length - open - 2)):
        return ""
    return substring(init, 0, open)

def is_int_list(s:string) -> bool:
    guard starts(s, "[") and ends(s, "]"):
        return false
    let inner = substring(s, 1, s.length - 2)
    for(tokenize(inner, ",", " ")) t:
        if not is_int(t): return false
    return inner.length > 0

def type_of(ty:string, init:string) -> string:
    if ty.length > 0: return ty
    if is_int(init): return "int"
    if init == "true" or init == "false": return "bool"
    if init == "\"\"": return "string"
    if init == "jobj()": return "JV"
    if init == "new_rng(1)": return "Rng"
    if starts(init, "[]::"): return "[{substring(init, 4, -1)}]"
    if is_int_list(init): return "[int]"
    let d = dictionary_of(init)
    assert d.length > 0  // No type for this global: give it one where it's declared.
    return d

class Global:
    name:string
    ty:string  // as written: "" if it has none
    init:string

// `var name[:type] = init [// comment]` at the start of a line, or nil.
def parse_var(line:string) -> Global?:
    guard starts(line, "var "):
        return nil
    let e = word_end(line, 4)
    let eq = find_string(line, " = ", e)
    guard e > 4 and eq >= 0 and (eq == e or line[e] == ':'):
        return nil
    let comment = find_string(line, "//", eq + 3)
    let init = if comment >= 0: substring(line, eq + 3, comment - eq - 3) else: substring(line, eq + 3, -1)
    let ty = if eq > e: substring(line, e, eq - e) else: ""
    return Global { substring(line, 4, e - 4), ty, strip_end(init) }

// `let name = dictionary<...>(64)` at the start of a line: its name and type, or "", "".
def parse_let(line:string) -> string, string:
    guard starts(line, "let "):
        return "", ""
    let e = word_end(line, 4)
    guard find_string(line, " = dictionary<", e) == e:
        return "", ""
    let init = substring(line, e + 3, -1)
    let close = find_string(init, ">(")
    guard close > 0:
        return "", ""
    let shut = find_string(init, ")", close)
    guard shut > 0 and is_int(substring(init, close + 2, shut - close - 2)):
        return "", ""
    return substring(line, 4, e - 4), substring(init, 0, close + 1)

let libnames, libsizes, libtimes = scan_folder("lib", true)
let files = map(filter(assert libnames) n: ends(n, ".lobster")) n: "lib/{n}"
insertion_sort(files) a, b: a < b
for([ "gen/setup.lobster", "gen/start.lobster" ]) n: files.push(n)

var reset = "def reset_world():\n"
var decl = ""
var stash = "def stash_world():\n"
var unstash = "def unstash_world():\n"
var count = 0
let fields = []::string  // the globals' names
let fieldtypes = []::string
let lets = []::string  // let dictionaries: cleared on reset, refilled on load
let lettypes = []::string
for(files) f:
    var r = ""
    for(tokenize(assert read_file(f, 1), "\n", "\r")) line:
        let g = parse_var(line)
        if g:
            r += "    {g.name} = {g.init}\n"
            decl += "var stashed_{g.name}{g.ty} = {g.init}\n"
            stash += "    stashed_{g.name} = {g.name}\n"
            unstash += "    {g.name} = stashed_{g.name}\n"
            fields.push(g.name)
            fieldtypes.push(type_of(strip_end(substring(g.ty, min(1, g.ty.length), -1)), g.init))
            count++
        else:
            let name, ty = parse_let(line)
            if name.length > 0:
                r += "    {name}.clear()\n"
                lets.push(name)
                lettypes.push(ty)
    if r.length > 0: reset += "    // {f}\n{r}"

assert write_file("gen/reset.lobster", "// Generated by gen_reset.lobster: every global of lib/ and gen/setup, gen/start as declared.\n\n{decl}\n{reset}\n{stash}\n{unstash}", 1)
print "gen/reset.lobster: {count} globals"

var save = "// Generated by gen_reset.lobster: a match saved and loaded, every global of lib/ and gen/setup, gen/start.\n\nclass WorldSave:\n"
for(fields) v, i: save += "    {v}:{fieldtypes[i]}\n"
for(lets) v, i: save += "    {v}:{lettypes[i]}\n"
save += "    save_format:int\n    save_packs:[string]\n"
save += "    bots:[Bot]  // the bots (the game keeps them)\n\n"
save += "// The world and the bots as bytes (a save file, or the start of a network match).\n"
save += "def world_bytes(bots:[Bot]) -> string:\n    let w = WorldSave \{\n"
for(fields) v: save += "        {v},\n"
for(lets) v: save += "        {v},\n"
save += "        SAVE_FORMAT,\n        lib_mods,\n"
save += "        bots \}\n    return flexbuffers_value_to_binary(w, 1000)\n\n"
save += "def save_world(path:string, bots:[Bot]) -> bool: return write_file(path, world_bytes(bots))\n\n"
save += "def load_world(path:string) -> [Bot]:\n    let data = read_file(path, true)\n"
save += "    return if data: load_world_bytes(data) else: []\n\n"
save += "// The bots that came with it, or [] if these are not a saved world.\n"
save += "def load_world_bytes(data:string) -> [Bot]:\n"
save += "    let w, err = flexbuffers_binary_to_value(typeof WorldSave, data)\n    if err: return []\n"
save += "    let s = w\n    if not s: return []\n"
save += "    save_refused = save_refusal(s.save_format, s.save_packs)\n    if save_refused != \"\": return []\n    save_upgrade(s)\n"
for(fields) v: save += "    {v} = s.{v}\n"
for(lets) v: save += "    {v}.clear()\n"
for(lets) v: save += "    s.{v}.forkv() k, v: {v}.set(k, v)\n"
save += "    pad_saved_columns()  // (a save from an older build: its missing per-unit and per-building columns, D-141)\n"
save += "    roles_from_data()  // (... and its building types\' roles, D-192)\n"
save += "    staples_from_data()  // (... and its staple resources)\n"
save += "    spatial_clear()  // (... and its spatial buckets, which an older build filled over the whole map)\n"
save += "    return s.bots\n"
save += "\n// Brings a loaded save up to SAVE_FORMAT: each format change adds its step in gen_reset.lobster, oldest first. Format 1 needs none.\ndef save_upgrade(s:WorldSave):\n    assert s.save_format <= SAVE_FORMAT\n    if s.save_format < 2:  // (weapon mounts, #177, #211: no unit type had one)\n        for(s.t_slot):\n            s.t_mounts.push([]::Mount)\n        let old_shots = s.shots  // (a shot says which mount fired it, #179)\n        s.shots = []::int\n        for(old_shots) v, n:\n            s.shots.push(v)\n            if n % 11 == 10: s.shots.push(0)\n    if s.save_format < 3:  // (aircraft, #183: no unit type was one)\n        for(s.t_slot):\n            s.t_air.push(0)\n            s.t_hits_air.push(0)\n"
save += "\n// Why this save file can\'t load here, or \"\".\ndef save_refusal_of(path:string) -> string:\n    let data = read_file(path, true)\n    if not data: return \"No such save.\"\n    let w, err = flexbuffers_binary_to_value(typeof WorldSave, data)\n    if err: return \"That file is not a save.\"\n    let s = w\n    if not s: return \"That file is not a save.\"\n    return save_refusal(s.save_format, s.save_packs)\n"
assert write_file("gen/save.lobster", save, 1)
