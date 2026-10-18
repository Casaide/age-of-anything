# 2026-10-18: Colour words ("red spiders")

## What happened
Dominic: asking for "red spiders" didn't work; spiders had few colours and a colour in the prompt was ignored
(it fell into the "no idea what 'red' means" note). Now colour words are lexicon entries (`"colour": "red"`), every
skin says which colours it answers to (palettes.json `skin_colours`), and the generator picks the race's skin from
the ones in a colour asked for, before its culture's preference. Spiders got four new skins: red (crimson), white
(with pink marks), yellow (pale) and blue (navy), each kept far enough from the team colours (the run_tests check).

## Decisions
- D-160: colour words pick the skin; a creature that doesn't come in that colour keeps its own, with a note.
- Human skin tones answer to no colour word on purpose (Claude): "black romans" or "white romans" never picks a
  person's skin. "Red romans" says humans don't come in red.

## Pictures
- `images/2026-10-18/01-red-and-blue-spiders.png`: red spiders (top, blue side) and blue spiders (bottom).
- `images/2026-10-18/02-white-and-yellow-spiders.png`: white and yellow spiders.

## Ideas parked
- "Red romans" could mean red cloth; colour words could reach a mount ("frogs on white ponies") once words can be
  tied to the noun they sit next to. Tests for the colour words wait for the bears (Dominic: test it all then).
