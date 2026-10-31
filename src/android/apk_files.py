# Writes apk_files.lobster: every folder in the APK's assets with its entries (names, and sizes: -1 for a folder), and
# apk_scan(dir), which the Android build calls in place of scan_folder for them (Lobster can't list an APK's folders).
#   python3 apk_files.py <assets dir> <out .lobster>
import os, sys, json
root, out = sys.argv[1], sys.argv[2]
dirs, names, sizes = [], [], []
for here, subs, files in sorted(os.walk(root)):
    subs[:] = sorted(d for d in subs if not (here == root and d == 'baked'))   # (the shipped bakes: read by name, never listed)
    rel = os.path.relpath(here, root)
    if rel == '.': continue
    entries = [(s, -1) for s in subs] + [(f, os.path.getsize(os.path.join(here, f))) for f in sorted(files)]
    dirs.append(rel)
    names.append('[' + ', '.join(json.dumps(n) for n, _ in entries) + ']::string')
    sizes.append('[' + ', '.join(str(z) for _, z in entries) + ']::int')
with open(out, 'w') as f:
    f.write('// The APK\'s folders (written by src/android/apk_files.py for the Android build)\n\n')
    f.write('let apk_dirs = [' + ', '.join(json.dumps(d) for d in dirs) + ']::string\n')
    f.write('let apk_names = [' + ',\n    '.join(names) + ']\n')
    f.write('let apk_sizes = [' + ',\n    '.join(sizes) + ']\n\n')
    f.write('def apk_scan(dir:string) -> [string]?, [int]?:\n')
    f.write('    for(apk_dirs) d, k:\n')
    f.write('        if d == dir: return apk_names[k], apk_sizes[k]\n')
    f.write('    let names, sizes, times = scan_folder(dir, true)\n')
    f.write('    return names, sizes\n')
