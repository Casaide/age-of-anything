// Put calibrated price points into the data, keeping its formatting (D-195).
//   lobster write_prices.lobster -- [../build/calibrate/prices.json]
// prices.json is {part id or "slot:<slot>": price points}, from `lobster calibrate.lobster -- fit write`. A part's go in
// data/parts.json: one whose price is its points and has no price_points is left alone; otherwise its price_points is
// set (replaced in place, or added right after its points, with the same spacing). A slot's go on that line of the
// roster in every data/rules/*.json (added after its "slot"), "size:giant" and "size:tiny" in their cost as
// giant_price_points and tiny_price_points (what a tiny one takes off).
import from "../creel/src"
import std
import dictionary
import gen.json

class Key:
    name:string
    at:int
    start:int
    end:int

class Edit:
    a:int
    b:int
    text:string

// Each element's (start, end) of the array that starts at i.
def spans(text:string, first:int) -> [int2]:
    let out = []::int2
    var depth = 0
    var start = 0
    var instr = false
    var i = first
    while i < text.length:
        let c = text[i]
        if instr:
            if c == '\\': i++
            elif c == '\"': instr = false
        elif c == '\"':
            instr = true
        elif c == '[' or c == '{':
            depth++
            if depth == 2: start = i
        elif c == ']' or c == '}':
            if depth == 2: out.push(int2 { start, i + 1 })
            depth--
            if depth == 0: return out
        i++
    return out

def is_space(c:int) -> bool: return c == ' ' or c == '\t' or c == '\n'

def skip_space(s:string, first:int) -> int:
    var i = first
    while is_space(s[i]): i++
    return i

// Each depth-1 key of the object that starts at first: its name, where its key and value start, where its value ends.
def top_keys(obj:string, first:int) -> [Key]:
    let keys = []::Key
    var depth = 0
    var instr = false
    var keyat = -1
    var i = first
    while i < obj.length:
        let c = obj[i]
        if instr:
            if c == '\\':
                i++
            elif c == '\"':
                instr = false
                if depth == 1 and keyat >= 0:
                    let j = skip_space(obj, i + 1)
                    if obj[j] == ':':
                        let v = skip_space(obj, j + 1)
                        var e = v
                        while obj[e] != ',' and obj[e] != '}' and not is_space(obj[e]): e++
                        keys.push(Key { substring(obj, keyat + 1, i - keyat - 1), keyat, v, e })
                keyat = -1
        elif c == '\"':
            instr = true
            keyat = i
        elif c == '[' or c == '{':
            depth++
        elif c == ']' or c == '}':
            depth--
            if depth == 0: return keys
        i++
    return keys

def find_key(keys:[Key], name:string) -> Key?:
    let i = find(keys): _.name == name
    return if i >= 0: keys[i] else: nil

// The edit that sets a value to want, if it isn't: replaced where it is, or added after the `after` key, spaced the same.
def set_price(edits:[Edit], text:string, keys:[Key], key:string, after:string, want:int):
    let k = find_key(keys, key)
    if k:
        let have, ok = string_to_int(substring(text, k.start, k.end - k.start))
        assert ok
        if have != want: edits.push(Edit { k.start, k.end, "{want}" })
    else:
        let a = assert find_key(keys, after)
        var gap = a.at
        while is_space(text[gap - 1]): gap--
        edits.push(Edit { a.end, a.end, ",{substring(text, gap, a.at - gap)}\"{key}\": {want}" })

// The edits that set each element's price_points to wantf(element) (-1: leave it).
def price_edits(edits:[Edit], text:string, elements:[int2], after:string, wantf):
    for(elements) e:
        let want = wantf(parse_json(substring(text, e.x, e.y - e.x)))
        if want >= 0: set_price(edits, text, top_keys(text, e.x), "price_points", after, want)

def apply(path:string, original:string, edits:[Edit]):
    var text = original
    insertion_sort(edits) a, b: a.a > b.a
    for(edits) e: text = substring(text, 0, e.a) + e.text + substring(text, e.b, -1)
    parse_json(text)
    assert write_file(path, text)
    print "{edits.length} prices changed in {path}"

let args = command_line_arguments()
let prices = load_json(if args.length > 0: args[0] else: "../build/calibrate/prices.json")

let partspath = "../data/parts.json"
let partstext = assert read_file(partspath)
let partedits = []::Edit
price_edits(partedits, partstext, spans(partstext, 0), "points") p:
    let want = gint(prices, gstr(p, "id", ""), -1)
    if want == gint(p, "points", -1) and not has(p, "price_points"): -1 else: want
apply(partspath, partstext, partedits)

let rulenames, rulesizes = scan_folder("../data/rules", true)
let rules = filter(assert rulenames) n: find_string(n, ".json") == n.length - 5
insertion_sort(rules) a, b: a < b
for(rules) name:
    let path = "../data/rules/{name}"
    let text = assert read_file(path)
    let edits = []::Edit
    let roster = find_string(text, "\"roster\"")
    assert roster >= 0
    price_edits(edits, text, spans(text, find_string(text, "[", roster)), "slot") sd:
        let want = gint(prices, "slot:" + gstr(sd, "slot", ""), -1)
        if want == 0 and not has(sd, "price_points"): -1 else: want
    let keys = top_keys(text, find_string(text, "\{", find_string(text, "\"cost\"")))
    for([ "giant", "tiny" ]) size, i:
        let got = gint(prices, "size:" + size, -1000000)
        if got != -1000000:
            set_price(edits, text, keys, "{size}_price_points", "base", if i == 0: got else: -got)
    apply(path, text, edits)
