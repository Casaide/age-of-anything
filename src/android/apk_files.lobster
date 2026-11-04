// Writes apk_files.lobster: every folder in the APK's assets with its entries (names, and sizes: -1 for a folder), and
// apk_scan(dir), which the Android build calls in place of scan_folder for them (Lobster can't list an APK's folders).
//   lobster apk_files.lobster -- <assets dir> <out .lobster>
import std

let args = command_line_arguments()
let root = args[0]
let out = args[1]
let dirs = []::string
let names = []::string
let sizes = []::string

def quoted(xs:[string]) -> string: return concat_string(map(xs) x: "\"{x}\"", ", ")

def walk(rel:string) -> void:
    let nsq, zsq = scan_folder("{root}/{rel}", false)
    let ns = assert nsq
    let zs = assert zsq
    let order = map(ns) n, i: i
    insertion_sort(order) a, b: ns[a] < ns[b]
    let subs = filter(order) i: zs[i] < 0
    let files = filter(order) i: zs[i] >= 0
    let entries = append(subs, files)
    dirs.push(rel)
    names.push("[" + quoted(map(entries) i: ns[i]) + "]::string")
    sizes.push("[" + concat_string(map(entries) i: "{zs[i]}", ", ") + "]::int")
    for(subs) i: walk("{rel}/{ns[i]}")

let topnames, topsizes = scan_folder(root, false)
let topz = assert topsizes
let tops = filter(assert topnames) n, i: topz[i] < 0 and n != "baked"  // (the shipped bakes: read by name, never listed)
insertion_sort(tops) a, b: a < b
for(tops) t: walk(t)

let text = "// The APK\'s folders (written by src/android/apk_files.lobster for the Android build)\n\n" +
    "let apk_dirs = [" + quoted(dirs) + "]::string\n" +
    "let apk_names = [" + concat_string(names, ",\n    ") + "]\n" +
    "let apk_sizes = [" + concat_string(sizes, ",\n    ") + "]\n\n" +
    "def apk_scan(dir:string) -> [string]?, [int]?:\n" +
    "    for(apk_dirs) d, k:\n" +
    "        if d == dir: return apk_names[k], apk_sizes[k]\n" +
    "    let names, sizes, times = scan_folder(dir, true)\n" +
    "    return names, sizes\n"
assert write_file(out, text, 0, 1)
