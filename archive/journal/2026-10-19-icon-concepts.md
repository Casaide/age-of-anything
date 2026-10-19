# 2026-10-19: Game icon concepts, round I1

**Milestone:** none (business: the website and Discord need an icon; follows `2026-10-19-website-draft-3.md`)
**Who:** Dominic + Claude (Claude Code, a side session of the website work)

## What happened
Dominic asked whether there's a game icon or logo for Discord, the favicon and so on. There isn't: project.godot
still had Godot's own. The name isn't final, so the mark has to work without it. Concept-first (D-080): four
options, drawn as SVG by `tools/ui/icon_concepts.py`, one sheet of every option from 16 to 512 px on dark and light
(`docs/concepts/icon/sheet_i1.png`, notes in its README).

- A: a viking frog's head on a lacquer-red shield with a bronze rim.
- B: the game's own baked units (the viking frog, the rat on a bear), cut out of a zoom-6 concept sheet
  (`tests/sheets/icon_i1.json`) at their real pixel size and set on the meadow in a bronze ring.
- C: the swallowtail banner with a quill crossed over a sword: write it, then fight it.
- D: a helm with a horn on one side and a rat's ear through the other: the helm of anything.

Looked at close up: A and D hold at 16 px, C nearly, B is a green dot below 64 (fine for the Deck tile and
Discord, not a favicon).

## Decisions
None yet: Dominic picks. Nothing is wired into the game.

## Pictures
- `09-icon-concepts-i1-sheet.png`: the sheet, all five marks at every size on dark and light.
- `10-icon-concepts-i1-16-and-32-close.png`: the 16 and 32 px renders blown up, to see what survives.

## Funny moments
The first cut-out of the units keyed the meadow out with a loose colour match and took the bear's brown coat
and the frog's outlines with it: a bear made of confetti.
The infantry slot gave the viking frogs a team banner on their backs, so every frog in the icon is also a flag-bearer.

## Ideas parked
- A hand-tuned 16 px favicon once a mark is picked; a wordmark once the name is settled.

## Later the same day: stickers and round I2
Dominic on I1: "Those are great. But not really game specific, those are fun race ones, we could even add as
stickers." So the I1 marks became a Discord sticker and emoji set (`docs/concepts/icon/stickers/`, by
`tools/ui/stickers.py`): die-cut with a cream border, plus a bear, a spider and a centaur baked the same way as
the frog and the rat on a bear, checked at the sizes Discord shows them. The unit shields are lovely stickers
and useless 22 px emoji.

Round I2 is the game's own mark: what the game *is*, not one race. Four options (`tools/ui/icon_concepts_i2.py`,
`sheet_i2.png`): E a shield quartered with four peoples' parts; F a helm riveted from mismatched plates with a horn
and an antenna; G a banner with a beast sewn from half a bear and half a frog; H a crest with an empty field and a
prompt cursor. Claude's read: G is the most this-game, H the cleanest logo.

## Pictures (later)
- `11-sticker-set-at-discord-sizes.png`: every sticker at 160 and emoji at 48 and 22, on Discord's dark and light.
- `12-icon-concepts-i2-sheet.png`: round I2, every option 16-512 px on dark and light.
- `13-icon-concepts-i2-16-and-32-close.png`: I2 at 16 (on dark) and 32 (on light), blown up.

## Funny moments (later)
The first prompt cursor was an I-beam with serifs: a capital I. A mark with no lettering, spelling a letter.

## Later still: round I2b, standing out
Dominic: "quill banner looks nice, but doesn't stand out". The bar for every mark became standing out at a glance
in a Discord server list or a Steam library row: one dominant silhouette, high contrast, the gold accent. I2b
(`tools/ui/icon_concepts_i2b.py`, `sheet_i2b.png`) redraws the ideas as one ink shape on gold: C2 a sword whose blade
is a quill (the I1 quill banner made bold), F2 the riveted helm with a horn and an antenna breaking over the rim,
G2 the bear-and-frog head stitched down the middle, H2 the prompt in gold on a dark shield. The sheet now has a
strip of each among made-up Discord servers and dark library tiles, so standing out can be judged. The gold discs
(F2, G2) are the brightest thing in both; H2 vanishes on dark UIs.

## Pictures (I2b)
- `14-icon-concepts-i2b-bold-sheet.png`: I2b at every size, then among Discord servers and library tiles.
- `15-icon-concepts-i2b-16-and-32-close.png`: I2b at 16 on Discord dark and 32 on white, blown up.

## Funny moments (I2b)
The first bold kit helm had a gold face slot with a dark nasal down the middle: from across the room, a pair of
trousers on a gold coin.

## Round I3: the odd helm, worn by anything
Dominic, pointing at I1's D (the helm with a horn and a rat's ear): "getting weird. I think this was a good
direction, showing the weird generated stuff. Try some variations of that." I3 (`tools/ui/icon_concepts_i3.py`,
`sheet_i3.png`) keeps the helm and swaps who's inside: a spider (antenna, six red eyes), a frog (eyes bulging up
through the crown, tongue out), a rat (two ears, whiskers, a tail round the rim), a bear (ears, a snout under the
nasal), a winged one, "the lot", and D on gold. Claude's read: the frog is the funniest and stands out best of
the dark ones; gold is what pops in a list; the helm could stay the mark while its wearer changes, like the generator.

## Pictures (I3)
- `16-icon-concepts-i3-odd-helms-sheet.png`: I3 at every size, then among Discord servers and library tiles.
- `17-icon-concepts-i3-16-and-32-close.png`: the eight helms at 16 on Discord dark and 32 on white, blown up.
- `18-icon-concepts-i3-eight-helms.png`: the eight helms side by side at 256.

## Funny moments (I3)
Both rat's ears went on the left on the first try, so the reference helm lost its horn behind an ear: the mark that
was meant to show two creatures showed one. The first wing pointed down like a wilted feather duster.

## Round I4: something totally different
Dominic after the I3 helms: "I think we need to try something totally different, something that really clicks
and shows what we're about." I4 (`tools/ui/icon_concepts_i4.py`, `sheet_i4.png`) drops shields and coins for
bright full-bleed app tiles about what the game does: J1 a die whose pips are creatures (frog, rat, spider: roll a
race), J2 a game piece with a frog's head, horns and a rat's tail, J3 an egg hatching with a horn and an ear
pushing the lid up, J4 a frog in a helm on a rat on a bear. Claude's read: the die clicks best and has the
strongest outline at 16 px.

## Pictures (I4)
- `19-icon-concepts-i4-sheet.png`: I4 at every size, then among Discord servers and library tiles.
- `20-icon-concepts-i4-four-tiles.png`: the four tiles side by side.

## Funny moments (I4)
The die's first top face was a horned helm, and in ink on bone it came out a little devil's face. It became a spider.

## Round I5: flat, the genre's way
Dominic on I4: "gradient makes them look super dated. dice is a nice idea maybe. But please look at icons from
other games in the genre." Claude looked at the Steam icons of the forty top-selling strategy games: nearly all are
flat, one emblem in one or two colours on a flat field (mostly near-black), no gradients, rims or cartoon outlines,
shapes split by gaps. Our I1-I4 marks looked like older mobile-game icons next to them. I5
(`tools/ui/icon_concepts_i5.py`, `sheet_i5.png`) redraws the die and the odd helm flat: the die bone on black and
black on gold, the helm bone on red, the frog helm bone and gold on black. Claude's read: the helm on red is the
strongest icon; the die is the better idea but busy at 16 px.

## Decisions (I5)
None yet, but a direction change worth recording: the icon goes flat (Dominic: gradients look dated).

## Pictures (I5)
- `21-icon-concepts-i5-flat-sheet.png`: I5 at every size, then among Discord servers and library tiles.
- `22-icon-concepts-i5-16-and-32-close.png`: I5 at 16 and 32, blown up.

## Funny moments (I5)
In the first flat helm the rat's ear was a bone ring with a big red hole: the helm had grown a mug handle.
The flat frog helm, without its tongue, is an owl.

## Round I6: a new direction
Dominic on I5: "I think new direction." I6 (`tools/ui/icon_concepts_i6.py`, `sheet_i6.png`) keeps the flat look and
tries four new ideas from kinds of icon the genre uses: L1 a legion-style war standard with a frog for its eagle, L2
a rat with a lance riding a bear as one silhouette, L3 a pixel-art bust of the cheese-hammer rat cut from the
game's own bake (the genre's painted bust, in our pixels), L4 a war hammer whose head is a block of cheese.
Claude's read: the pixel bust is the most "us" and the only one that gets sharper as it gets smaller.

## Pictures (I6)
- `23-icon-concepts-i6-sheet.png`: I6 at every size, then among Discord servers and library tiles.
- `24-icon-concepts-i6-16-and-32-close.png`: I6 at 16 and 32, blown up.
- `25-icon-concepts-i6-four-tiles.png`: the four tiles side by side.

## Funny moments (I6)
The first rat on a bear was a mouse on a pig, its lance stuck out of the top of the picture, and its tail left by
the right-hand side.

## A fresh round, N1-N5: research first
Dominic asked for a fresh start, so this round (`docs/concepts/icon/fresh/`, `tools/ui/icon_concepts_fresh.py`,
`sheet_fresh.png`) began with research instead of the earlier marks. Claude pulled the 32 px Steam icons of 80 strategy
games (RTS, 4X and city-builder top sellers, big and indie) and 16 library capsules and laid them out at 1x and 4x. What
it showed: almost everything is flat; most are a pale emblem on near-black (so that's camouflage); the ten or so on one
bright flat colour are where the eye lands; a big front-on face holds at 16 px; painted scenes turn to mush; pixel art is
rare and the sharpest thing at 32. The findings are in the README (no game names in the repo; the named contact
sheets are in the session notes).

Five options, all flat on bright fields: N1 selection corners and a health bar round a rat soldier (blue); N2 a
flip book face, three strips from three creatures slid out of line (iron horned helm, frog's googly eyes, rat's snout,
on gold); N3 a shield wall of a rat, a frog and a bird (red); N4 a model kit's frame with the parts on it (navy);
N5 a frog legionary hand-pixelled on a 32 and a 16 grid (purple). The sheet now also shows a 32 px store list and an
app icon rounded by the platform. Close up: only N2 and N5 hold at 16 px. Claude's pick: N2 (holds at 16, the
brightest tile in every list, and it is "anyone, from parts" in one face); N5 second.

## Pictures (fresh round)
- `26-icon-fresh-sheet.png`: the sheet at half size.
- `27-icon-fresh-16-and-32-close.png`: the five at 16 (on Discord dark) and 32 (on light), blown up.
- `28-icon-fresh-five-tiles.png`: the five side by side.

## Funny moments (fresh round)
The shield wall's rat first came out as a chick: round head, short beak, a round ear. Then its snout reached the spear
and it looked like it was eating it. The pixel frog's selection ring, drawn as an ellipse on a 32 grid, came out as
lumps of grass at its feet, so it got a shadow instead.
