#!/usr/bin/env python3
"""Scaffold a mod (milestone 21, docs/modding.md): a folder with its manifest, data overlays, one example part with its
voxel look (data/voxel/gear.json: the gear and the rule that gives the part it), and a README, ready to fill in and
check.

    python3 tools/mods/new_mod.py <id> ["Name"] [--private] [--era <tag>]

<id>: lower_case letters, digits and underscores. --private puts it in mods_private/ (gitignored,
never exported: for fan pieces that must not be shared). --era adds an era tag of the mod's own, so its
parts only appear where a host's rules allow it (the manifest's "eras"; the rules overlay opens it
under Anything goes).
"""
import json
import os
import re
import sys

GAME_VERSION = "0.21"


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    private = "--private" in argv
    era = argv[argv.index("--era") + 1] if "--era" in argv else ""
    if era in args:
        args.remove(era)
    if not args or not re.fullmatch(r"[a-z][a-z0-9_]*", args[0]):
        sys.exit(__doc__)
    mod_id = args[0]
    name = args[1] if len(args) > 1 else mod_id.replace("_", " ").title()
    root = os.path.join("mods_private" if private else "mods", mod_id)
    if os.path.exists(root):
        sys.exit("%s already exists" % root)
    for d in ["data/rules", "data/voxel"]:
        os.makedirs(os.path.join(root, d))
    tag = era or mod_id
    part_id = "helm.%s_example" % mod_id
    manifest = {
        "id": mod_id, "name": name, "version": "0.1.0", "game_version": GAME_VERSION,
        "authors": [], "description": "", "license": "",
        "load_order": 100, "depends": [], "eras": [era] if era else [],
        "data": "data",
        "check": {"rules": "anything", "prompts": ["%s soldiers" % tag]},
    }
    if private:
        manifest["private"] = True
    write(root, "mod.json", manifest)
    part = {
        "id": part_id, "slot": "head_gear", "_doc": "An example helmet: replace it with your parts.",
        "tags": ["helmet", tag], "only_if": [tag], "stats": {"armour": {"melee": 1, "pierce": 0}},
        "points": 1, "tier": 1, "shapes": [{"t": "poly", "p": [[-5, 2], [-5, -4], [0, -6], [5, -4], [5, 2]], "ch": "iron"}],
    }
    if era:
        part["era"] = [era]
        part["upgrade_within"] = tag
    write(root, "data/parts.json", [part])
    word = {"tags": {tag: 5}}
    if era:
        word = {"era": era, "tags": {tag: 5}, "substitute": {"helmet": 1}, "note": "Not in this era. (Write a playful note.)"}
        write(root, "data/rules/anything.json", {"_doc": "Anything goes allows this mod's era.", "+era": [era]})
    write(root, "data/lexicon.json", {"words": {tag: word}})
    gear_id = "%s_helm" % mod_id
    write(root, "data/voxel/gear.json", {
        "_doc": "The mod's voxel gear (docs/rendering.md, \"Voxel units\"): a helmet on any body's helmet spot, and the rule that gives the example part it.",
        "gear": {gear_id: {"flags": ["helm"], "fits": {"*": [{"helm": 0.4, "mat": "metal"}]}}},
        "parts": [{"part": part_id, "gear": gear_id}],
    })
    with open(os.path.join(root, "README.md"), "w") as f:
        f.write(README.format(name=name, mod_id=mod_id, root=root,
                              private=PRIVATE if private else ""))
    print("made %s: fill in data/parts.json and data/voxel/, then see docs/modding.md" % root)


def write(root, rel, data):
    with open(os.path.join(root, rel), "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


README = '''# {name} (`{mod_id}`)
{private}
A mod for the game: more data (`data/`), its parts' voxel looks (`data/voxel/`). How to make it: `docs/modding.md`.

```sh
src/mod_check.sh {mod_id}
python3 tools/mods/pack.py {mod_id}
```
'''

PRIVATE = '''
**PRIVATE:** this mod lives in `mods_private/` (gitignored, excluded from exports). Never commit it,
ship it or put its pictures in `archive/`.
'''

if __name__ == "__main__":
    main(sys.argv[1:])
