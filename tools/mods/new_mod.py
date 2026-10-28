#!/usr/bin/env python3
"""Scaffold a mod (milestone 21, docs/modding.md): a folder with its manifest, data overlays, a model
script with one example part, a sheet spec and a README, ready to fill in and check.

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
    for d in ["data/rules", "models", "textures", "sheets", "tools"]:
        os.makedirs(os.path.join(root, d))
    tag = era or mod_id
    part_id = "helm.%s_example" % mod_id
    manifest = {
        "id": mod_id, "name": name, "version": "0.1.0", "game_version": GAME_VERSION,
        "authors": [], "description": "", "license": "",
        "load_order": 100, "depends": [], "eras": [era] if era else [],
        "data": "data", "models": ["models/%s_parts.lobster" % mod_id],
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
    with open(os.path.join(root, "models", "%s_parts.lobster" % mod_id), "w") as f:
        f.write(MODEL.format(mod_id=mod_id, part_id=part_id, fn=part_id.replace(".", "_")))
    write(root, "sheets/%s.json" % mod_id, {
        "name": mod_id, "title": "Mod %s" % mod_id, "mods": [mod_id], "rules": "anything", "zooms": [3, 1],
        "cell": [70, 60], "size": [{"prompt": "romans", "slot": "spear"}],
        "rows": [{"each": {"prompt": ["%s soldiers" % tag], "slot": ["spear", "skirmisher", "infantry"]}, "age": 2}],
        "sheets": [{"name": "facings", "title": "8 facings", "columns": "facings"},
                   {"name": "walk", "title": "walking", "columns": "walk:1,3"}],
    })
    with open(os.path.join(root, "README.md"), "w") as f:
        f.write(README.format(name=name, mod_id=mod_id, root=root,
                              private=PRIVATE if private else ""))
    print("made %s: fill in data/parts.json and models/%s_parts.lobster, then see docs/modding.md" % (root, mod_id))


def write(root, rel, data):
    with open(os.path.join(root, rel), "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


MODEL = '''// The {mod_id} mod's parts (data/parts.json), built from the game's model kit (src/model/base.lobster: blob, rod,
// slab, dome, ring, cone, box; surf(texture, tint, units), plain(colour), glow(colour)). build_mod_{mod_id} returns a
// part's model by its id (nil for the rest): mod.json's "models" names this file, and the game joins it in when the
// mod is on (src/mods_gen.lobster). Frames: x the way the unit faces, y up, z towards the viewer's side; head gear
// round the head's top socket (the crown at y 0, about 5 across), held items round the grip, worn armour frog-sized.
// c holds the unit's colours: col(c, "team"), col(c, "skin"), col(c, "cloth")...

def {fn}(c:Colours) -> Spec:
    let n = mnode()
    let iron = surf("iron", float3_1, 3.0)
    add_child(n, dome(float3 {{ 5.2, 5.0, 5.0 }}, iron, float3 {{ 0.0, -3.8, 0.0 }}))
    add_child(n, ring(4.9, 5.5, plain(col(c, "team")), float3 {{ 0.0, -3.6, 0.0 }}))
    lift_kids(n, 1.05)   // its rim clear of the brow (the placement check, A2)
    return spec_of(n)

def build_mod_{mod_id}(base:string, c:Colours) -> Spec?:
    switch base:
        case "{part_id}": return {fn}(c)
        default: return nil
'''

README = '''# {name} (`{mod_id}`)
{private}
A mod for the game: more data (`data/`), models for its parts (`models/`), textures (`textures/`),
a sheet spec (`sheets/`). How to make it: `docs/modding.md`.

```sh
src/mod_check.sh {mod_id}
src/sheet.sh {root}/sheets/{mod_id}.json /tmp/{mod_id}
python3 tools/mods/pack.py {mod_id}
```
'''

PRIVATE = '''
**PRIVATE:** this mod lives in `mods_private/` (gitignored, excluded from exports). Never commit it,
ship it or put its pictures in `archive/`.
'''

if __name__ == "__main__":
    main(sys.argv[1:])
