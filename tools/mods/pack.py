#!/usr/bin/env python3
"""Pack a mod for sharing (milestone 21, docs/modding.md): build/mods/<id>-<version>.zip, holding the
mod's folder as <id>/... (unzip it into the game's user://mods folder to install it).

    python3 tools/mods/pack.py <id>

Refuses a mod marked "private" in its manifest (fan pieces stay private), and leaves out renders/,
.import and .uid files. Steam Workshop upload is later (docs/milestones/m21-modability.md).
"""
import json
import os
import sys
import zipfile

SKIP_DIRS = {"renders", "__pycache__"}
SKIP_ENDS = (".import", ".uid", ".DS_Store")


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__)
    mod_id = argv[0]
    root = next((os.path.join(r, mod_id) for r in ["mods", "mods_private"] if os.path.isdir(os.path.join(r, mod_id))), None)
    if root is None:
        sys.exit("no mod %s in mods/ or mods_private/" % mod_id)
    manifest = json.load(open(os.path.join(root, "mod.json")))
    if manifest.get("private") or root.startswith("mods_private"):
        sys.exit("%s is private: it is never packed or shared" % mod_id)
    os.makedirs("build/mods", exist_ok=True)
    out = "build/mods/%s-%s.zip" % (mod_id, manifest["version"])
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for d, dirs, files in os.walk(root):
            dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
            for f in sorted(files):
                if not f.endswith(SKIP_ENDS):
                    path = os.path.join(d, f)
                    z.write(path, os.path.join(mod_id, os.path.relpath(path, root)))
    print("packed", out)


if __name__ == "__main__":
    main(sys.argv[1:])
