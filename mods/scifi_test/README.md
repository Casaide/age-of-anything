# Future soldiers (test) (`scifi_test`)

The example mod for milestone 21 (`docs/milestones/m21-modability.md`; how to make one:
`docs/modding.md`). Original art. Not part of the game: it loads only when asked for
(`./play.sh lobby mods:scifi_test rules:anything`, or `AOW_MODS=scifi_test`), and builds leave `mods/` out.

- The `scifi` era (manifest `eras`), opened under Anything goes and the default rules (`data/rules/`).
- Words: future, futuristic, space, scifi, laser(s) (era words: elsewhere a note and a substitute),
  marine, trooper.
- Parts (`data/parts.json`, all `only_if: scifi`, `upgrade_within: scifi`): a sealed visor helmet
  (`face: sealed`), plated armour, a power pack, the pulse rifle (skirmishers; its heavy version at
  age 3), the arc blade (swordsmen and scouts), the arc buckler.
- Their looks are its own voxel gear (`data/voxel/`, #166, made from scratch): dark ceramite power armour over the arms
  and legs with big team-coloured pauldrons, a sealed helmet with a glowing visor slit and a crest, a reactor pack with
  tall exhaust stacks, boxy pulse rifles with glowing coils (the `aim` hold), a glowing arc blade, a hard-light buckler.
- `body.robot` (`bodies/robot.json`): a worker drone on reverse knees with one glowing optic. It wears nothing and works
  with a laser cutter (`sc_cutter`) that fires a beam on each blow. `scifi_short`'s rules make every future worker one.
- The `pulse` shot (`data/shots.json`): a bolt of light for weapons tagged `energy`.

```sh
src/mod_check.sh scifi_test                                              # loaded, who wears its parts, its prices
(cd src && ./play.sh lobby mods:scifi_test rules:anything "races:future soldiers|romans")
```
