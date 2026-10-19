# The game icon: concept rounds I1 to I6 (2026-10-19), I6 waiting on Dominic

The game had no icon (project.godot used Godot's default, no logo file anywhere). It needs one square mark for the
favicon (16-32 px), the Discord server icon, the Godot app icon and the Steam Deck / library tile (128-512 px), and it
mustn't depend on the name: "Age of Anything" is a working title until the trademark check.
A wordmark comes later, once the name is settled. Nothing is wired into the game until Dominic picks (D-080).

**The sheet:** `sheet_i1.png`: every option at 16, 32, 64, 128 and 512 px on dark and on light, the 16 and 32 again at
6x (nearest neighbour, to see their real pixels), and the Discord circle crop at 128.
**Made by:** `python3 tools/ui/icon_concepts.py` (SVG at 512, rendered with rsvg-convert). The units in B are baked by
`tests/sheets/icon_i1.json` (sheet tool, zoom 6, placement PASS) and cut out by `tools/ui/icon_cut.py`.
Colours are the timber direction's (`data/ui.json`): bronze rim, lacquer red, the dark well, gold.

| Option | What | Holds at 16 px? |
|---|---|---|
| **A  Frog crest** (`a_frog_crest.svg`) | a viking frog's head (horned helm, gold eyes, a long grin) on a lacquer-red heater shield with a bronze rim | **yes**: red shield, green face, two white horns |
| **B1 / B2  Unit shield** (`b1_*`, `b2_*`) | the game's own baked unit (the viking frog; the rat on a bear) on its meadow in a round bronze ring | **no**: a green dot under 64 px. Lovely at 128-512 (Deck tile, Discord), needs another mark for the favicon |
| **C  Quill banner** (`c_quill_banner.svg`) | the swallowtail banner (the timber look's cut) on a bronze rod, a quill crossed over a sword: you write your race, then you fight with it | **mostly**: the banner reads, the cross is a blur at 16, clear at 32 |
| **D  Odd helm** (`d_odd_helm.svg`) | one helm worn by anything: a viking horn on one side, a rat's ear poking through the other, gold eyes in the dark inside, on a dark roundel | **yes**: the helm and its lopsided top read; already round, so the Discord crop costs nothing |

Claude's read: **A** is the most charming and reads at every size; **D** says "anything" best without naming a
creature, and is the most logo-like. B is the game's real art and could be the big tile beside A or D as the small
mark. A pick can mix (D's idea with A's frog, B's frog in A's shield).

What the pick still needs before it ships: a hand-tuned 16 px favicon (thinner rim, bigger subject: the 512 drawing
scaled down loses a third of its pixels to the rim), the Godot icon (`project.godot` `config/icon`) and the macOS
/ Windows export icons, the Discord 512 with a background for the circle crop, and a Steam library set later.

Originality: shields, banners, helms and creature heads are common heraldry; nothing here follows another game's
logo, and there is no lettering.

**Dominic on I1:** "Those are great. But not really game specific, those are fun race ones, we could even add as
stickers." So I1 became the sticker set, and I2 looks for the game's own mark.

## The sticker set (from I1)

`stickers/`: every I1 mark, plus three more race marks (a brown bear, a spooky spider, a centaur greek, baked by
`tests/sheets/icon_i1.json` like B1 and B2), as Discord stickers (`sticker_*.png`, 320x320, ~30-55 KB) and emoji
(`emoji_*.png`, 128x128, ~10-17 KB), transparent, die-cut with a cream border and a dark edge so they sit on
Discord's dark and light themes. Made by `python3 tools/ui/stickers.py` (asserts Discord's 512 KB / 256 KB limits).
`stickers/preview_discord_sizes.png` shows each as Discord does: the sticker at 160, the emoji at 48 (jumbo) and
22 (inline), on dark and on light. As stickers all of them read; as 22 px inline emoji only A, C and D do: the
unit shields are a green disc with a speck.

## Round I2: the game's own mark

What the game is: an army built from a kit of parts, any people in any culture, then a classic RTS war.
**The sheet:** `sheet_i2.png` (same format as I1). **Made by:** `python3 tools/ui/icon_concepts_i2.py`.

| Option | What | Holds at 16 px? |
|---|---|---|
| **E  Many peoples** (`e_many_peoples.svg`) | a heater shield quartered by a bronze cross: a viking horn on red, a rat's ear on dark timber, a frog's eye on green, a wing on blue. Many peoples, one crest | **yes, as four colours**: the quartering reads, the parts in it don't until 32 |
| **F  Kit helm** (`f_kit_helm.svg`) | a helm riveted together from parts that don't match: an iron half and a bronze half, a timber brim, one bone cheek and one iron, a horn on one side and an insect's antenna on the other, on a red roundel | **weakly**: a grey blob on red at 16, clear at 32. Round, so the Discord crop is free |
| **G  Stitched beast** (`g_stitched_beast.svg`) | a war banner whose beast is two creatures sewn down the middle: half bear, half frog, stitches on the seam | **yes**: brown and green halves on a blue banner; the joke lands at 32 |
| **H  Write it in** (`h_write_it_in.svg`) | a crest with an empty parchment field (the dashed line is where your race goes) and a prompt: a chevron and the cursor bar. The race is what you write | **best of the four**: cream shield, two dark strokes, sharp at every size |

Claude's read: **G** is the most this-game: anything, from parts, sewn together, ready for war, and funny; it
needs a background for the circle crop (a banner is tall). **H** is the cleanest logo and says "you type it" with no
creature at all, but the chevron and bar can read as a media "skip" button or a command line, which is less
medieval than the rest of the look. **E** is the safest heraldry. **F** is the kit idea most literally, and loses
the most at 16 px. Mixes worth trying: G's stitched beast in E's or H's shield; H's cursor on G's banner.

Originality: quartered shields, helms and banners are common heraldry; no lettering. H's chevron and bar are
symbols, not letters.

## Round I2b: bold marks that stand out (supersedes I2)

Dominic: "quill banner looks nice, but doesn't stand out". The new bar for every option: it stands out at a glance
in a Discord server list or a Steam library row: one dominant shape you'd know from its outline alone, high contrast
between subject and field, and a colour that pops on dark and light (the gold accent), not lacquer red and bronze
with thin crossing shapes. Each mark is a single ink silhouette on gold (or gold on ink) inside a thick dark edge,
in a shield or roundel small enough that the Discord circle doesn't clip it. I2's files stay as the record.
**The sheet:** `sheet_i2b.png`: the I1/I2 size rows, then a strip of each option among made-up Discord servers
(48 px circles, dark and light theme) and in a dark library (128 px tiles, a 32 px list row). The neighbours are
flat circles with initials or a shape, like community servers; nothing real. **Made by:** `python3 tools/ui/icon_concepts_i2b.py`.

| Option | What | Stands out? | At 16 px |
|---|---|---|---|
| **C2  Quill sword** (`c2_quill_sword.svg`) | I1's C, the one mark about the game (write it, then fight it), as one shape: an upright sword whose blade is a quill, nicks in its vane, ink on a gold shield | yes: gold shield, one dark sword | reads as a sword; the feather shows from 32 |
| **F2  Kit helm** (`f2_kit_helm.svg`) | the riveted helm as one dark silhouette on a gold roundel: a horn and an antenna breaking out over the rim, gold seams and rivets, eye slits | **the most**: a full gold disc with a horned head | a helm with horns |
| **G2  Stitched beast** (`g2_stitched_beast.svg`) | one head, two creatures: a round bear's ear and a frog's bulging eye on top, gold stitches down the middle, one grin running across both | **the most**: same gold disc; the odd ears catch the eye | a dark blob in gold; the two ears show from 32 |
| **H2  Write it in** (`h2_write_it_in.svg`) | the prompt inverted: a gold chevron and cursor on a dark shield | on light, strongly; on Discord dark and in the dark library it sinks into the background | sharp |

Claude's read: **F2 and G2** stand out most (a full gold disc is the brightest thing in both the server list and
the library, and the roundel is made for the circle crop). **G2** is the one only this game could have, the
creature made from parts, and the joke is there at 32 px and up; **F2** is the more heroic and reads better at
16. **C2** is the cleanest "about the game" mark; as a shield it is smaller than the discs in a circle list.
**H2** is clean but disappears on dark UIs and still risks reading as a media "skip" key or a terminal.
Worth trying next if one is close: G2's head in C2's shield, or F2's helm with G2's stitch down its middle.

## Round I3: the odd helm, worn by anything

Dominic, pointing at I1's D: "getting weird. I think this was a good direction, showing the weird generated
stuff. Try some variations of that." So I3 keeps D's helm, roundel and bronze rim, and changes who's inside: what
pokes out of the helm and what looks out of the face slot. **The sheet:** `sheet_i3.png` (sizes on dark and light,
then each among made-up Discord servers and dark library tiles). **Made by:** `python3 tools/ui/icon_concepts_i3.py`
(the parts are pieces you can mix: horn, ear, antenna, bear ear, wing, frog eye, tongue, whiskers, tail, snout;
eyes gold, red spider eyes, beady).

| Option | Who's inside | At 16 px |
|---|---|---|
| **D** (`d_odd_helm_i3ref.svg`) | I1's: a horn, a rat's ear, gold eyes (for reference) | the helm and its lopsided top |
| **D2 Spider** (`d2_spider_helm.svg`) | a horn and a beetle's antenna, six red eyes in the slot | the red eyes show at 32 |
| **D3 Frog** (`d3_frog_helm.svg`) | two frog's eyes bulging up through the crown, a pink tongue out from under it | **stands out most of the dark ones**: the green-gold eyes and the pink tongue carry at 16 |
| **D4 Rat** (`d4_rat_helm.svg`) | two ears, whiskers out of the slot, beady red eyes, a tail curling round the rim | the two pink ears; whiskers from 32 |
| **D5 Bear** (`d5_bear_helm.svg`) | round bear ears, a snout and nose under the nasal | the quietest: brown on dark |
| **D6 Winged** (`d6_winged_helm.svg`) | a feathered wing breaking over the rim, a horn on the other side | the white wing reads |
| **D7 The lot** (`d7_the_lot_helm.svg`) | a horn, a rat's ear, an antenna, a frog's eye on top, spider eyes, a tongue | busy at 16, the most "generated" at 128+ |
| **D8 Gold** (`d8_gold_helm.svg`) | D on a gold field | **stands out most**: the brightest thing in the Discord list and the library |

Claude's read: the helm is the mark; who wears it can change. **D3** (frog) is the funniest and stands out of the
dark ones best; **D8**'s gold field is what makes any of them pop in a list, so the pick could be D3's or D's wearer
on D8's gold. And because the helm stays the same, the variations work as a family: the Discord icon or the
devlog's header could wear a different race's helm from time to time, the way the generator does, while the outline
stays recognisable.

## Round I4: something totally different

Dominic after I3: "I think we need to try something totally different, something that really clicks and shows
what we're about." No shields, crests or coins: four ideas about what the game *does*, each a bold full-bleed app
tile (a rounded square in a bright colour, the subject inside the Discord circle), drawn fuller and friendlier.
**The sheet:** `sheet_i4.png` (sizes, then among made-up Discord servers and library tiles).
**Made by:** `python3 tools/ui/icon_concepts_i4.py`.

| Option | The idea | At a glance |
|---|---|---|
| **J1  Race die** (`j1_race_die.svg`) | an isometric die whose pips are creatures: a frog's face, a rat's face, a spider. Roll a race (the generator's reroll) | **the strongest outline**: a bone cube on red reads at 16 as "a die"; the faces show from 32. The isometric cube also says "isometric RTS" |
| **J2  Odd pawn** (`j2_odd_pawn.svg`) | a strategy game's piece built from parts: a frog's head, viking horns, a rat's tail. Your piece, made of anything | a piece with horns on blue; says "strategy game" and "silly" at once |
| **J3  Hatching** (`j3_hatching.svg`) | an egg cracking open, a horn and a rat's ear pushing the lid up, gold eyes in the dark. Something's being made | the cracked egg reads at every size; the horn and ear from 32 |
| **J4  Stack** (`j4_stack.svg`) | a frog in a viking helm on a rat on a bear, faces stacked like a totem: "rats riding bears", and up | the loudest and funniest at 128+; a brown-grey-green blob at 16 |

Claude's read: **J1** clicks best: a die is "random, generated, roll again", its pips being creatures is the joke,
and the cube is the one outline you'd know at 16 px. **J3** is the warmest (something new is being born) and
**J4** the funniest for Discord and the store. J2 sits between. Mixes worth trying: J3's egg with the die's
creature pips on the shell, or J1 rolled mid-air with a horn poking out.

## Round I5: flat, the genre's way

Dominic on I4: "gradient makes them look super dated. dice is a nice idea maybe. But please look at icons from
other games in the genre." Claude looked at the Steam icons of the forty top-selling strategy games (2026-10-19).
What they share: **flat**. One emblem in one or two colours (bone, white or gold) on a flat full-bleed field, mostly
near-black, otherwise one strong colour (red, blue, gold); no gradients, bevels, glossy rims or thick cartoon
outlines; shapes are split by thin gaps of the field, not by ink lines. Many are a monogram or a series numeral (we
have no name yet, so no letters); the rest are an object (a helmet, a shield, a banner, a cog, a building) or a
painted character bust. The I1-I4 marks, with their gradients and outlines, read as older mobile-game icons.

So I5 redraws the two ideas Dominic liked that way: the die (I4 J1) and the odd helm (I1 D, I3). Square full-bleed
fields (the platforms round the corners themselves), two colours plus at most one accent.
**The sheet:** `sheet_i5.png`. **Made by:** `python3 tools/ui/icon_concepts_i5.py`.

| Option | What | At 16 px |
|---|---|---|
| **K1  Die on black** (`k1_die_bone_on_black.svg`) | the race die in three flat bone tones, creature pips in black: a frog, a rat, a spider | a bone cube; the pips are noise until 32 |
| **K2  Die on gold** (`k2_die_black_on_gold.svg`) | the same die inverted: black faces, gold pips, on the gold accent | **stands out most** in the lists; a dark cube on gold |
| **K3  Helm on red** (`k3_helm_bone_on_red.svg`) | the odd helm in one bone colour on lacquer red: a horn, a rat's ear, gold eyes in the slot | **the clearest at 16**: a horned head you'd know from its outline |
| **K4  Frog helm** (`k4_frog_helm_on_black.svg`) | the I3 frog helm flat: frog's eyes bulging up through the crown, bone and gold on black | a bone head with two gold eyes; funny, a little owl-like |

Claude's read: flat suits both ideas far better. **K3** is the strongest icon (one shape, two colours, the lopsided
horn-and-ear outline is the "anything" joke and holds at 16). The die is the better idea for "roll a race" but busy
small: if it wins, its favicon should carry one creature (the top face) rather than three. K2's gold is what pops in
a list. Possible next step: K3's helm on K2's gold, or the die with a single creature face.

## Round I6: a new direction, still flat

Dominic on I5: "I think new direction." The flat look stays; the ideas are new, each taken from a kind of icon the
genre uses (an object, a figure, a painted bust) and made ours. **The sheet:** `sheet_i6.png`.
**Made by:** `python3 tools/ui/icon_concepts_i6.py`.

| Option | What | At 16 px |
|---|---|---|
| **L1  Frog standard** (`l1_frog_standard.svg`) | a legion-style war standard (crossbar, hanging cloth, a disc) with a frog sitting where the eagle would be; gold and red on black | a gold standard; the frog shows from 32 |
| **L2  Rat on a bear** (`l2_rat_on_bear.svg`) | cavalry as one bone silhouette on red: a rat with a pennoned lance riding a bear | a pale beast and rider; the bear still reads a bit like a pig |
| **L3  Pixel bust** (`l3_pixel_bust.svg`) | the genre's painted character bust, done in the game's own pixel art: the cheese-hammer rat in his beret, cut from the baked rat-on-a-bear, on flat teal | **the best at 16**: pixel art is made for small sizes, and at 32 px it is the game's own pixels one to one |
| **L4  Cheese hammer** (`l4_cheese_hammer.svg`) | one weapon as the emblem: a war hammer whose head is a block of cheese with holes, gold on red | a gold head on a stick; the cheese reads from 32 |

Claude's read: **L3** is the most "us": no other game in the list has pixel art for an icon, it is real game art,
and it is the only option that is sharper at 16 and 32 than at 128 (the favicon and the 32 px Steam icon could be
hand-placed sprite pixels). The rat is one race, but the bust can rotate between races like the I3 helms; its
weakness is that a single rat doesn't say "anything" on its own. **L4** is the funniest single object and a
natural sticker. L1 says "army of something odd" at Discord size. L2 needs another pass.

## A fresh round: N1 to N5

Dominic asked for a fresh start from research; that round is in `fresh/` (its README has the research on the genre's
icons, the options and the recommendation).
