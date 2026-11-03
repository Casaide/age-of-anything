# Future soldiers (test) (`scifi_test`)

The example mod for milestone 21 (`docs/milestones/m21-modability.md`; how to make one:
`docs/modding.md`). Original art. Not part of the game: it loads only when asked for
(`./play.sh lobby mods:scifi_test rules:anything`, or `AOW_MODS=scifi_test`), and builds leave `mods/` out.

- The `scifi` era (manifest `eras`), opened under Anything goes and the default rules (`data/rules/`).
- Words: future, futuristic, space, scifi, laser(s) (era words: elsewhere a note and a substitute),
  marine, trooper.
- Parts (`data/parts.json`, all `only_if: scifi`, `upgrade_within: scifi`): a sealed visor helmet
  (`face: sealed`), plated armour, a power pack, the pulse rifle (skirmishers; its heavy version at
  age 3), the arc blade (swordsmen and scouts), the arc buckler (a `.glb` made by `tools/buckler.py`).
- Models: `models/scifi_parts.lobster` (built from the game's model kit, `src/model/base.lobster`), `textures/plate.svg`.
- The `pulse` shot (`data/shots.json`): a bolt of light for weapons tagged `energy`.

```sh
src/mod_check.sh scifi_test                                              # loaded, who wears its parts, 3D placement
(cd src && ./sheet.sh ../mods/scifi_test/sheets/scifi_test.json /tmp/scifi)   # the sheet (mods: in the spec)
(cd src && ./play.sh lobby mods:scifi_test rules:anything "races:future soldiers|romans")
blender -b --python mods/scifi_test/tools/buckler.py -- mods/scifi_test/models/buckler.glb
```
