# 1944

A Sherman side against a Panzer side, all data, no code. Each side has its own tank, a fighter plane and flak gunners. The word
`sherman` or `panzer` picks the crew; `tank` and `plane` ask for the era too.

    ./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" skirmish army:4 watch

- **Tanks** (`data/voxel/bodies/siege.bolt.*`): a turret on a mount (`stats.mounts`, `parts`), a `muzzle` point, `tracks` and `wheels`.
- **Fighter** (`siege.beast.fighter`): a real aircraft (`stats.air`, the `flying` tag) with a propeller (`wheels` with `blades`). Only what can hit air touches it.
- **Flak gunners** (`weapon.flak`): the counter to aircraft, by a `bonus` on the `air` tag.
- **Shots** (`data/shots.json`): the 75 mm shell and the machine gun. **Sounds** (`data/audio.json`): engines, tracks, turret.

`data/rules/ww2_duel.json` leaves workers, gunners, tanks and fighters. Tanks and fighters are tier 3 lines, so in a normal match they come in the third age.
