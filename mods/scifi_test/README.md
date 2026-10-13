# Future soldiers (test) (`scifi_test`)

The example mod for milestone 21 (`docs/milestones/m21-modability.md`; how to make one:
`docs/modding.md`). Original art. Not part of the game: it loads only when asked for
(`AOW_MODS=scifi_test`, or `user://mods.json`), and exports leave `mods/` out.

- The `scifi` era (manifest `eras`), opened under Anything goes and the default rules (`data/rules/`).
- Words: future, futuristic, space, scifi, laser(s) (era words: elsewhere a note and a substitute),
  marine, trooper.
- Parts (`data/parts.json`, all `only_if: scifi`, `upgrade_within: scifi`): a sealed visor helmet
  (`face: sealed`), plated armour, a power pack, the pulse rifle (skirmishers; its heavy version at
  age 3), the arc blade (swordsmen and scouts), the arc buckler (a `.glb` made by `tools/buckler.py`).
- Models: `models/scifi_parts.gd` (the game's helpers), `textures/plate.svg`.
- The `pulse` shot (`data/shots.json`): a bolt of light for weapons tagged `energy`.

```sh
godot --headless --path . --script res://tests/mod_check.gd -- scifi_test
godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- mods/scifi_test/sheets/scifi_test.json /tmp/scifi
blender -b --python mods/scifi_test/tools/buckler.py -- mods/scifi_test/models/buckler.glb
```
