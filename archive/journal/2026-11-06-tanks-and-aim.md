# 2026-11-06: Tanks, and an aim in the sim

**What happened.** Dominic wanted WW2 tanks and planes for the trailer's mod beat. The tank took a while. Its first tracks were a slab with teeth, and he said so: "tanks look terrible, we need much much better tracks". The next one was a mixture of real tanks, a Patton's turret on a late Sherman's front with a far too long barrel: "just make a sherman". So the Sherman was built from its real measurements and a Panzer IV beside it, and they fought in a match (`mods/ww2`, a stopgap on branch `ww2-mockup-renders`).

Playing it showed what a tank needs that the game doesn't have: shots came from its middle, the turret couldn't aim, the tracks didn't run. Dominic asked for it done properly, in the engine, so #176 splits vehicles into pieces (#177 to #186) and aim in the sim came first.

**Decisions.** D-216.

**Direction changes.** Vehicles became an engine feature instead of a mod's tricks. Planes will be real air units with anti-air counters, not a skin.

**Funny moments.**
- A box whose normal points straight up has no idea which way is across, so a small camouflage patch became a slab as wide as the plane: brown wings, and a red deck panel the size of a garage door.
- A body with no soft shape at all renders nothing, silently. The first true Sherman was invisible (#184).
- Engines take their paint from `frame`, and `skin` means the crew's. The first battle was fought by rust-brown tanks in the workers' skin tones.
- Knocked-out tanks fall over sideways like a shot horse (#186).
- A tank told to drive on stopped dead the moment anything hit it, to fight back, with its gun already firing. Found by its test.

**Ideas parked.** A hull turn rate, for casemates and for hulls that really turn in the sim.
