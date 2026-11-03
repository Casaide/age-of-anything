# How the sound is made (audio pipeline)

Everything you hear is a file in `assets/audio/`, rendered offline by our own synthesiser
(`tools/audio/`, pure Python, no dependencies) and committed like the `.glb` models. The game
only plays files. Nothing is downloaded, sampled or borrowed: every sound is ours, and a
re-render gives the same bytes (seeded noise, fixed recipes). This page is the map; the code
says the details.

## The brief

A classic 2D RTS sounds **hand-made and near**: wood, stone, hide, reed, bronze, breath. Small
things close to the ear, not cinema. The old placeholder set (sine blips at 22 kHz, one take
of each, synthesised at start-up) sounded like a 1980s computer; it had no bodies, no
variation, no mix and no music. The rework keeps its good ideas (positional work sounds timed
to the blow in the animation, rate limiting) and replaces everything else.

Rules the sounds follow:

1. **Physical, never electronic.** Every effect is a thing happening: an axe biting reed, a
   pick ringing stone, a mallet on a frame, a wooden token set on the table (the UI click), a
   page turning (a tip). No beeps, no chimes that aren't a bell someone could hold.
2. **Layered.** An impact is a transient (a filtered noise burst), a body (a falling pitch or a
   few modal partials) and a tail. Shots are a release (a short pluck) and a whoosh (a swept
   band of noise), and the arrow *lands* too, when the view says it has.
3. **Never the same twice.** Short sounds have 2-4 takes played round-robin, with a little
   pitch jitter in the game on top.
4. **The creatures talk.** A race's units answer with their creature's voice: frogs croak, rats
   squeak, humans grunt, beetles clack and buzz, spiders chitter, ponies whinny, centaurs grunt
   and stamp, capybaras chirrup. Three kinds: `select`, `ack` (an order heard), `die`. One
   voice at a time, only your own side. This is where the game's premise shows in sound.
5. **The stings are in the music's key.** Age-up, victory, defeat, alarm, trained, built and
   research use the music's own instruments (horn, lute, drums, a tongue drum, a bronze bell)
   in D, so they land inside the theme instead of on top of it.
6. **Mixed, not shouted.** Buses (`Music`, `Sfx`, `Voice`, `Ui`, `Ambience`) with their own
   levels; each sound has a gap (least time between two plays) and a voice count; work sounds
   are quieter away from the middle of the screen and silent off it.

## The music

The theme ("Whatever"; two more pieces below), D Dorian, 92 to the minute, 32 bars (A A B A'), about 84 seconds,
written in `tools/audio/music.py` as text notes. It is rendered as **stems**, one seamless
loop each (note tails and the room's tail wrap round), all the same length and in time, so
any mix of them is the same tune:

| Stem | What | Heard from |
|---|---|---|
| `pluck` | the tune on a plucked gut string (a lute); the chord's root and fifth under it from the second A | the lobby, age 1 |
| `drums` | a frame drum (dum / tek), a shaker from bar 9, the big drum in A' | the lobby (soft), age 1 |
| `flute` | a counter-line in the second A, the tune in B, a third above it in A' | age 2 |
| `drone` | two bowed strings a few cents apart on the chord's root | age 2 |
| `horns` | horn stabs in B, held chords in A' | age 3 |
| `battle` | war drums in eighths, tek rolls, a ragged war horn every eight bars | while there's fighting near the camera |

The game plays all six at once through one `AudioStreamSynchronized` and fades each stem's
volume (2.5 s) to the mix the moment asks for: `lobby`, `age1`..`age4`, `off`, plus the
battle layer on top. Ageing up therefore *adds instruments* without a cut; a fight near you
brings the drums in and lets them go eight seconds after the last blow. Victory and defeat
fade the theme out under their sting. The pause menu has `Music: on/off`. Mixes and stem
levels are data: `data/audio.json`.

## Two more pieces (2026-11-03)

The theme has two siblings, written the same way (text notes, the same six stems, seamless loops)
and in the same seven white-key notes, each round a different home note, so they belong to the game
and the stings in D sit in all three:

| Piece | Mood | Key, time | Length | What's in it |
|---|---|---|---|---|
| `theme` ("Whatever") | the game's tune, striding | D Dorian, 92, 4/4 | 83.5 s | as above |
| `hearth` | the town at work: calm, warm, a lilt | G Mixolydian, 72, 3/4 | 80 s | a wooden tongue drum on the tune over a lute rolling the chord, a hand drum barely there, a flute an octave down in B and a third under in A', a slow G/C drone, soft held horns |
| `march` | the war: tense, driven | E Phrygian, 112, 4/4 | 68.6 s | a lute ostinato that never leaves its root (the first 8 bars are only that and the drums), the tune on a bright lute, a frame-drum march with rolls, high held flute notes, horn stabs in B and the tune as a horn call in A'; its battle layer is sixteenths on the war drum |

Every piece has the same stems in the same roles (`pluck` carries the tune, `drums`, `flute`, `drone`,
`horns`, `battle`), so the mixes by age work on each unchanged. Files: `music/<piece>_<stem>.ogg`;
code: `tools/audio/music.py` (the theme and `PIECES`), `music_hearth.py`, `music_march.py`, `score.py`
(the clock and note text they share). `render.py music` renders all three, `render.py hearth` one.

How the game picks (`music_tick`, numbers in `data/audio.json` music): the lobby plays the rotation's
first piece (the theme). In a match the calm rotation (`theme`, `hearth`) turns over every `plays` (2)
loops, about every 2.7 minutes. Fighting on screen warms a heat counter (a second a second, cooling as
fast, capped at twice the threshold); at `tense_after_s` (25) the `march` comes in at once, and it
stays until the heat is gone and its loop has finished, then the rotation picks up where it was. A
change of piece starts the new stems silent and fades them up while the old ones fade down (`fade_s`)
and are halted, so at most two pieces play at once, briefly.

## Where things are

```
tools/audio/
  synth.py        the DSP: oscillators, noise, envelopes, one-pole and biquad filters, formants,
                  modal bodies, soft clip, a Schroeder room, WAV out, panning
  instruments.py  pluck (Karplus-Strong, tuned), flute, horn, war horn, drone, frame drum,
                  low drum, shaker, bell (wood / bronze), note_hz()
  sfx.py          every effect as a recipe; TABLE says takes and peak level
  voices.py       the creature voices (a glottal pulse through formants, plus animal noisemakers)
  music.py        the theme: notes as text, the stems, PIECES, the seamless-loop render
  music_hearth.py, music_march.py   the other two pieces; score.py what the three share
  render.py       writes assets/audio/{sfx,voice,music}; music goes through ffmpeg to Ogg Vorbis
  check.py        numbers for a file: length, peak, RMS, a pitch guess (ears-free sanity check)
assets/audio/
  sfx/<name>_<take>.wav        44.1 kHz mono 16-bit
  voice/<voice>_<kind>_<take>.wav
  music/<piece>_<stem>.ogg     stereo loops, 160 kb/s (theme, hearth, march)
data/audio.json                buses, every sound's takes / bus / gap / voices, the music mixes
data/creatures.json            each creature's `voice` (the voice file set it uses)
src/game/audio.lobster         the game's sound: play_sound(), say(), music_start()/music_tick(), ambience_start()/ambience_tick()
```

Rendering:

```sh
python3 tools/audio/render.py              # everything (about 15 s on this Mac, in parallel)
python3 tools/audio/render.py sfx voices   # or music, or single names: chop frog horns
python3 tools/audio/check.py assets/audio/sfx/chop_*.wav
afplay assets/audio/sfx/chop_1.wav         # listen (macOS)
```

Spectrograms to look at a sound (ffmpeg's `showspectrumpic`): see the pictures in
`archive/images/2026-10-11/100-*` for how the sheets were made.

The test suite checks that every sound in `data/audio.json` has its takes on disk and loads,
every creature's voice has its files, and every piece has every stem, a loop long (`src/run_tests.lobster`, the audio group: lengths read
from the WAV and OGG headers).

## In the game

`src/game/audio.lobster` keeps the music going from the lobby into the match. The game (`src/game.lobster`, from the
sim's events) plays:

- blows by the attacker's weapon tag (`blade`, `blunt`, else pierce), shots by the projectile
  kind (`CombatFx.shot_kind`), the arrow landing when the view's shot lands;
- siege engines their own (milestone 13, 2026-10-13): `ram_hit` (the frame creaks as the log swings
  back, a huge dull thud with a woody crack and grit, the frame settling), `catapult_release` (the
  skein's groan, the arm slamming its padded crossbar, the stone's air) and `catapult_impact` on its
  splash, `bolt_release` (the bow arms' double snap, the thick cord's twang, a heavy whoosh),
  `sling_release` (the great sling's whirl, the loop slipping free, the frame lurching), `blast` (the
  sapper's fire pot: a crack, a shaking thump, a roar of fire, debris, flames crackling down), and
  `trade_paid` (coins into a chest when a cart of yours comes home). A stone's or a blast's victims
  don't each play an arrow landing: the one impact covers them;
- a body's fall plus the creature's cry; a building's collapse;
- chop / mine / build / forage timed to the blow in the worker's animation, positional;
- the creature's `select` and `ack` for your own units; a token click for buildings and rally;
- trained, built, research, age-up, farm used up, under attack, victory, defeat;
- the music by your age (the piece by the rotation, the march in a long fight), the battle layer when your units fight on screen (or the alarm sounds),
  the meadow ambience under the match;
- the town's own sound on top (milestone 17): two 24-second loops, `town_quiet` and `town_busy`
  (far-off talk that never makes words, a mallet on a frame, a log split, a broom, a bucket set
  down, a door), faded by `ambience_tick(town_level)`. `src/game/town.lobster` sets the level from your
  town's size (finished buildings and workers) and how close the camera is to your Town Center:
  the quiet loop comes in first, the busy one joins past the middle.

## Known gaps and next steps

- An engine rolling has no sound of its own yet (a creak on a loop while it moves).
- **Nobody has listened yet.** Every sound was checked by numbers and spectrograms, not ears.
  The creature voices are the experimental part: synthetic throats may read as cheap. Dominic
  listens first; recipes are small, so a bad one is a quick change.
- A night / swamp / sewer ambience chosen by the map or the race's architecture.
- Unit voices by **size and culture** (a giant frog croaks lower; a Roman says a word), and a
  "can't" bark when an order is impossible.
- Volume sliders in a settings screen; the buses are already there.
- The `vorbis` encoder in this ffmpeg is the built-in one (no `libvorbis`); it is fine at
  160 kb/s but a libvorbis build would be smaller for the same sound.
