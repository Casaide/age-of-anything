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

One theme ("Whatever"), D Dorian, 92 to the minute, 32 bars (A A B A'), about 84 seconds,
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

## Where things are

```
tools/audio/
  synth.py        the DSP: oscillators, noise, envelopes, one-pole and biquad filters, formants,
                  modal bodies, soft clip, a Schroeder room, WAV out, panning
  instruments.py  pluck (Karplus-Strong, tuned), flute, horn, war horn, drone, frame drum,
                  low drum, shaker, bell (wood / bronze), note_hz()
  sfx.py          every effect as a recipe; TABLE says takes and peak level
  voices.py       the creature voices (a glottal pulse through formants, plus animal noisemakers)
  music.py        the theme: notes as text, the stems, the seamless-loop render
  render.py       writes assets/audio/{sfx,voice,music}; music goes through ffmpeg to Ogg Vorbis
  check.py        numbers for a file: length, peak, RMS, a pitch guess (ears-free sanity check)
assets/audio/
  sfx/<name>_<take>.wav        44.1 kHz mono 16-bit
  voice/<voice>_<kind>_<take>.wav
  music/theme_<stem>.ogg       stereo loops, 160 kb/s
data/audio.json                buses, every sound's takes / bus / gap / voices, the music mixes
data/creatures.json            each creature's `voice` (the voice file set it uses)
src/view/audio.gd              the one audio node: play(), play_in(), say(), music(), battle(), ambience()
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
every creature's voice has its files, and every stem loads (`tests/run_tests.gd`,
`_test_audio`). Files load with `load_from_file`, so headless runs need no editor import.

## In the game

`src/view/audio.gd` is one node under the tree's root (`Audio.of(get_tree())`), so the theme
carries on from the lobby into the match. The match view (`scenes/sim_debug.gd`) plays:

- blows by the attacker's weapon tag (`blade`, `blunt`, else pierce), shots by the projectile
  kind (`CombatFx.shot_kind`), the arrow landing when the view's shot lands;
- a body's fall plus the creature's cry; a building's collapse;
- chop / mine / build / forage timed to the blow in the worker's animation, positional;
- the creature's `select` and `ack` for your own units; a token click for buildings and rally;
- trained, built, research, age-up, farm used up, under attack, victory, defeat;
- the theme by your age, the battle layer when your units fight on screen (or the alarm sounds),
  the meadow ambience under the match.

## Known gaps and next steps

- **Nobody has listened yet.** Every sound was checked by numbers and spectrograms, not ears.
  The creature voices are the experimental part: synthetic throats may read as cheap. Dominic
  listens first; recipes are small, so a bad one is a quick change.
- A second theme (or a second mode of this one) for variety over a long match; a night /
  swamp / sewer ambience chosen by the map or the race's architecture.
- Unit voices by **size and culture** (a giant frog croaks lower; a Roman says a word), and a
  "can't" bark when an order is impossible.
- Volume sliders in a settings screen; the buses are already there.
- The `vorbis` encoder in this ffmpeg is the built-in one (no `libvorbis`); it is fine at
  160 kb/s but a libvorbis build would be smaller for the same sound.
