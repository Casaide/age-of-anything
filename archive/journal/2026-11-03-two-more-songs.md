# 2026-11-03: two more songs

## What happened
Dominic asked for two more songs beside the theme. Claude wrote them in the offline synth the same way the theme
is made (notes as text, six stems, seamless loops) and gave the game a small rotation:

- **Hearth**: the town at work. G Mixolydian, 72 to the minute, in three (the theme strides in four; this one
  lilts), 80 s. The tune is on the wooden tongue drum, the first time that instrument carries a melody; a lute rolls
  the chord under it. Meant for the long building stretches.
- **March**: the war. E Phrygian, 112, 68.6 s. A lute ostinato that never leaves its root, the half step F over E
  for the tension, a frame-drum march; the horns take the tune in the last section. Comes in during a long fight.

All three pieces use the same seven white-key notes round a different home note (D, G, E), so they sound like one
game, and the stings in D sit in all of them. Every piece has the same stems in the same roles, so the mixes by age
needed no change.

## Decisions
- Pieces are data (`data/audio.json` music: `pieces`, `rotation`, `plays`, `tense`, `tense_after_s`). The lobby
  plays the theme; a match turns theme and hearth over every 2 loops; 25 s of fighting on screen brings the march
  in at once, and it stays till the fighting has cooled off and its loop is done (Claude).
- A piece's stems only play while it's on: a change starts the new piece silent and fades the old one down and
  halts it, so the Deck never decodes 18 streams at once.
- `tools/audio/score.py` holds the clock and note text the three share; the theme renders the same samples as
  before (decoded and compared; only the Ogg container bytes differ, so its files weren't recommitted).

## Funny moments
- The first test of the rotation used 4-second "loops": the game flipped between theme and hearth like a radio
  being tuned.

## Ideas parked
- Nobody has listened yet: checked by numbers (length, peaks, loop seams) and spectrograms only.
- A piece by the race's family or the map (a sewer piece for rats) once there are more.
