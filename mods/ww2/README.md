# 1944 (`ww2`)

A Sherman side against a Panzer side, all data, no code. Not part of the game: it loads only when asked for, and builds leave
`mods/` out. Play it by hand, with your own army by your town (the enemy starts as a normal base, without tanks):

    ./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" army:6

Or watch both sides' tanks fight:

    ./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" skirmish army:6 watch

- The `ww2` era, opened under Anything goes and `ww2_duel` (`data/rules/`). `ww2_duel` leaves workers, gunners, tanks and fighters.
  Tanks and fighters are tier 3 lines, so without `army:` or `skirmish` they come in the third age.
- Words: sherman(s) and panzer(s) pick the crew, tank(s) and plane(s) ask for the era (elsewhere a note and a substitute).
- **Tanks** (`data/voxel/bodies/siege.bolt.*`): the bolt thrower line, a crew's own (`families.json` `siege`). A turret on a mount
  (`engine.tank_gun`'s `stats.mounts`, the body's `parts`), a `muzzle` point, `tracks` and `wheels`. The same gun at the same price:
  the Sherman is quicker, the Panzer tougher.
- **Fighter** (`siege.beast.fighter`): the war beast line, a real aircraft (`stats.air`, the `flying` tag) with a propeller (`wheels` with
  `blades`). Only what can hit air touches it. Its `flies` is a promise, not a lift: its points are set at that height.
- **Flak gunners** (`weapon.flak`): the archer line, the counter to aircraft by a `bonus` on the `air` tag.
- **People** (`crew_1944`): the game's human at 60%, a body of its own, so a person doesn't stand taller than a tank.
- **Shots** (`data/shots.json`): the 75 mm shell, the machine gun, the flak. **Sounds** (`data/audio.json`): engines, tracks, turret.
