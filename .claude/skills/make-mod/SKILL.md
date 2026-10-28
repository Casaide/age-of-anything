---
name: make-mod
description: Make an Age of Anything mod (new parts, creatures, cultures, words, an era) with the game's own tooling, checked and packed. Use when asked to make, extend or package a mod, or to try a new style/era/race as a mod.
---

# Make a mod

A mod is a folder of more data plus the models its parts are built from. The full walkthrough is
`docs/modding.md` (read it first); the format and rules are in `docs/milestones/m21-modability.md`;
the example is `mods/scifi_test/`. The game is Lobster (`src/`; Lobster is `~/Dev/lobster/bin/lobster`, run from
`src/`); runs that open a window take `mute`; always put a timeout on runs.

## Before building: pin down what's wanted

Ask (or confirm from the request) and write it into the mod's README before any model:
- **A new race or new kit for existing races?** "Something new" means a creature and culture of its own
  (body, head, look, words), not the game's humans in new clothes.
- **The roster's rules.** If the theme says "lasers only" or "no melee", every line the generator can make
  must obey it: check each roster slot (worker, spear, swords, skirmisher, archer, heavy, scout, mounted
  archer, healer, siege, unique) and make sure era bounds/`only_if`/`upgrade_within` keep out every
  weapon that breaks the theme. Print the full roster with `src/mod_check.sh <id>` (or `races.lobster -- mods:<id> anything "<prompt>"`) and read every line.
- **Public or private.** Anything based on someone else's franchise is `--private`: it lives in
  `mods_private/` (gitignored, never exported, never packed, never in `archive/`), with generic names in
  every file. Original work can be public.

## Steps

1. Scaffold: `python3 tools/mods/new_mod.py <id> ["Name"] [--era <tag>] [--private]`, then check it
   green straight away (step 4).
2. Concept first (the game's rule for new art): sketch 2-3 directions as a sheet spec
   (`mods/<id>/sheets/*.json`, `src/sheet.sh`) beside game units for scale; the person picks before you
   build the rest. New creatures go through the creature kit (`data/creature_kit.json`) where possible.
3. Write the parts (data) and their models (Lobster builders in `models/<id>_parts.lobster`, or Blender `.glb`),
   words, rules and any creature/culture (`"extends"` a game one where it fits). Price every part against
   a game part doing the same job; never free, never special-cased.
4. Check:
   - `src/mod_check.sh <id>` (loads, refuses with a reason, lists the check prompts' rosters and who wears the mod's
     parts, runs 3D placement): must be 0 failed. Read every unit line against the mod's rules.
   - A plain prompt without the mod's words gets none of its parts.
5. Look: `src/sheet.sh mods/<id>/sheets/<id>.json <out_dir>`;
   every row must PASS (both placement halves, composites included); look at every picture at 3x and at
   game size before showing anyone. A squad in a match: `./play.sh lobby mods:<id> rules:anything "races:<prompt>|romans" watch mute shot:<png> at:<s>`.
6. Pack (public only): `python3 tools/mods/pack.py <id>`.

## Report

What the mod adds, the roster it produces for each check prompt, the checks' results, picture paths
(private renders stay in `mods_private/<id>/renders/`), and anything that needs the person's pick.
Run through the checklist at the end of `docs/modding.md`.
