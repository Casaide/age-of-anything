# The game icon: a fresh round, N1 to N5 (2026-10-19). Dominic picked N4, ink on gold (D-164)

Dominic asked for a fresh start: research first, then options, not built on rounds I1-I6 (`../README.md` keeps those
and his reactions, which this round avoids repeating: no race crests, no quill banner, no gradients or glossy bevels,
not the die or the odd helm again).

**The sheet:** `sheet_fresh.png`. One row per option: the 512; 128, 64, 32 and 16 on dark and on light; the 16 at x8
and the 32 at x4 (the real pixels); the Discord circle crop on dark and light; the option fourth in a made-up Discord
server list (48 px circles, dark and light theme); in a dark library (128 px tiles and the 16 px list row); in a
32 px store list; and as an app icon rounded by the platform. The neighbours are plain made-up glyphs, nothing real.
**Made by:** `python3 tools/ui/icon_concepts_fresh.py` (SVG at 512, rsvg-convert, ImageMagick). Small sizes are the 512
scaled down the way the platforms do it, except N5, whose 16 and 32 are hand-placed pixel grids.

## Research: the genre's icons (2026-10-19)

Claude looked at the Steam app icons (the 32 px `.apphub_AppIcon`, the icon in every Steam list) of 80 strategy games:
the top sellers under the RTS, 4X and city-builder tags, big series and small indies, side by side at 1x and 4x on
Steam's own blue-black. Also 16 library capsules (the 600x900 art the library and the Deck show). Names stay out of
the repo; the contact sheets with names are in the session notes, outside the repo.

What they do:
- **Nearly all are flat.** One emblem, one or two colours, no gradients, rims or outlines. The few with painted
  scenes (a town, a map, a landscape) turn into mush at 32 px: the worst icons in the list.
- **The usual shape is a light emblem on near-black.** About 50 of the 80 sit on black or very dark navy; about 15 of
  those are a numeral or letters (a series mark). Because it's the usual, it's camouflage: in a dark Steam or Discord
  list, a dark tile with a pale emblem is one of fifty.
- **What stands out is a bright field.** The ten or so icons on one strong flat colour (a royal blue, a teal, an
  orange, a cream, a red, a cyan) are the ones the eye lands on first, at every size. That is the single biggest lever.
- **A face fills the tile and holds.** The character icons that work are one big simple face, front on, filling the
  square (a beaver, a cat, a bearded fighter, a king): two eyes read at 16 px when they are big. Small full figures and
  busts in a scene don't.
- **The indies with a sense of humour lead with a creature** (a beaver, a cat, a mouse, a pawn-like figure on cream)
  and the big series with a numeral or a crest. Ours is a funny game about creatures, so the creature route fits.
- **Pixel art is rare and sharp.** One icon in the 80 is pixel art, and it is one of the crispest at 32 px: a sprite
  drawn for its size beats any big drawing scaled down.
- **Detail costs.** At 32 px you get one silhouette and maybe two features; at 16 px one silhouette and one colour
  contrast. Thin lines vanish (Lanczos turns a 12 px line at 512 into a ghost at 16).
- **Library capsules** (Deck tiles) are key art plus the logo; most are dark and painted. The ones that pop are flat
  and bright (a pale green, a pink, hazard yellow). The icon isn't the capsule, but a bright square mark makes a
  natural capsule base later.
- **Discord** crops to a circle and shows 48 px; anything in the square's corners is lost, so the subject sits inside
  the circle.

So the bar for this round: flat, a bright field (not near-black), one subject that fills the circle, and either a big
face or a silhouette you'd know at 16 px. And it has to say this game: any people you can imagine, built from parts,
fighting a classic RTS war, silly but fair.

## The options

| Option | What it says | 16 px | 32 px | Stands out? |
|---|---|---|---|---|
| **N1 Selected** (`n1_selected.svg`) | the genre's own sign for "your unit": lime selection corners and a health bar round a rat soldier with a spear and a round shield, bone on royal blue. "It's an RTS, and your unit is a rat" | **no**: blue with a lime frame, the rat is mush | the corners and bar read; the rat just | yes, the blue and lime |
| **N2 Flip book** (`n2_flip_book.svg`) | one face in three strips from three creatures, slid out of line like a mix-and-match flip book: an iron horned helm, a frog's googly eyes, a beaver-ish rat's snout and teeth, on gold. "Make anyone from parts" | **yes**: a face with two eyes on gold | yes, and funny | **the most**: gold is the brightest tile in every list |
| **N3 Odd squad** (`n3_odd_squad.svg`) | a shield wall of three, spears up, every head a different creature: a rat, a frog, a bird; one bone silhouette on red. "An army of anyone" | **no**: red with pale noise | the shields and heads read; the joke from 64 | yes, on dark; red is common on light |
| **N4 Parts kit** (`n4_parts_kit.svg`) | a model kit's frame with the parts still on it: a frog's head, a horned helm, a round shield, a sword. "Built from a kit of parts" | **no**: a window icon | a frame with bits | no: bone on navy is the genre's usual |
| **N5 Pixel recruit** (`n5_pixel_recruit.svg`, `_16.png`, `_32.png`) | a frog legionary in the game's pixel look, a red-crested helm squashed between its eyes, a shield and a spear, on purple; hand-placed on a 32 grid and again on a 16 grid | **yes, the sharpest**: crest, helm, eyes, shield | **yes, the sharpest** | yes: purple and green are rare in the genre |

Claude's recommendation: **N2, the flip book.** It's the only vector option that holds at 16 px (a face on gold is
the one thing that survives that size), it is the brightest tile in the Discord list and in the dark library, and it
says the game in one picture: a person made of three creatures' parts, slid together like a children's flip book,
silly but whole. The strips can also change, the way the generator does: a devlog header or a Discord event icon can
flip one strip to a different creature while the gold square, the three strips and the offsets stay the mark.

**N5** is the close second and the better pick if the game's pixel art should be the brand: the only option sharper
at 16 and 32 than anything scaled down, and a strong sticker. Its weakness is the one earlier rounds hit: one frog in
one helm reads as a race, not as "anyone". **N3** is the best "army" read at Discord size and the funniest at 128+, but
not a favicon. N1 is the clearest "this is an RTS"; N4 is the most literal and the weakest in a list.

Mixes worth trying if one is close: N2 drawn as pixel art on N5's grids (the flip-book face, sharp at 16); N3's three
heads as N2's strips.

What the pick still needs before it ships: a hand-tuned 16 px favicon (for N2: thicker strips, the snout's whiskers
dropped), the Godot icon (`project.godot` `config/icon`) and the macOS / Windows export icons, a 512 Discord upload,
and the Steam set later (the 32 px app icon, the 184 px community icon, capsules).

Originality: a flip book of mix-and-match faces, a shield wall, a model-kit frame, selection corners and a health bar
are common forms and genre language; nothing here follows another game's icon or logo, and there is no lettering.


## The pick (D-164)

Dominic: "lets go with N4 for now", then, asked whether it should match the website: ink on gold
(`n4_site_ink_on_gold.svg`; the other colourways and the comparison, `n4_site_colours.png`, stay beside it). The
final files are in `../chosen/`.
