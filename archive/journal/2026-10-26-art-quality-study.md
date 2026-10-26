# 2026-10-26: how far can the art go? (study AQ1)

## What happened

Dominic: "I want to explore how far we can go with art quality ... higher res, better destruction, better
animations ... sci fi mods ... lasers firing ... while maintaining nostalgia above all else." Claude ran a
concept round (D-080) in its own session: four directions, each captured in the game's own pipeline beside
today's look, with costs. Write-up and pictures: `docs/concepts/art-quality/README.md`. Nothing is in the game.

1. **Higher resolution.** A flag, `AOW_ART_SCALE`, makes the whole game bake finer (units, buildings, props,
   ground). Same match, same camera: today, 1.5x and 2x. At play zoom the gain is modest (faces, shield
   bosses, the howdah's fringe, corrugated roofs); close up 2x is clearly sharper. Cold bake 21.7 s, 40.8 s,
   43.3 s; video memory ~0.5 GB to 1.2 GB at 2x; frame time unchanged on the Mac.
2. **Destruction.** Buildings broken up in 3D before they bake (`tests/art_quality/ruin.gd`): pieces fall
   from the top, others tilt and scorch, rubble heaps up from the building's own materials, walls become
   ragged stumps with breaches; five stages, then the fall with pixel dust, and a ruin that stays.
3. **Animation.** A follow-through arm hold (`follow`, behind `AOW_STUDY_HOLDS`), and every death laid down in
   3D through the frog's corpse pipeline: the legionary on its back with its helmet rolling off, the rat on
   its side. Placement check PASS on every row.
4. **Sci-fi effects.** A real volley of the `scifi_test` mod's pulse troopers, frozen, drawn four ways: today,
   pixel bolts on the art grid with starburst hits and light pools, full laser beams, plasma balls.

## Dominic's feedback (later the same day)

"The art is looking very interesting. To clarify unit and building fidelity is a key goal, units being more
detailed and higher quality. Destruction looks great. FYI those laser effects weren't coming from their barrel".

- Destruction picked (D-171); building waits on his go-ahead and the ruin's sim questions (block? build on it?
  how long?).
- Fidelity is a key goal: the next round raises unit and building detail; "not a global 2x" is withdrawn.
- The barrel: he was right, and it goes deeper than the study. The game launches every shot from the
  shooter's body (`_body(a) - (0, 2)` in sim_debug), arrows included; the pulse bolts just made it obvious. The
  concepts now start at each rifle's muzzle (the weapon's baked tip through its sprite's transform, read at draw
  time: the first try read it once and the troopers had stepped on before the picture, so half the beams still
  came out of their chests). Re-captured: `archive/images/2026-10-26/14-` and `15-art-quality-scifi-fx-muzzles*.png`.

Then his answer on the ruin: "Destroyed buildings should probably able to be built over? Same as [a classic RTS].
Destruction is for looking cool not game mechanic. Destruction staying until built over is cool but can get
frustrating and ugly. I think wrong game for that". That's the go-ahead (D-172): a ruin is decoration only, you can
build over it, and it fades after a while.

## Destruction built (evening)

Dominic: "yes. But then please focus on fidelity". Destruction went in: `Ruin` moved into the game
(`src/view/art/bake/ruin.gd`), every building look bakes four broken-up stages, BuildingArt swaps them in as hp
falls (keeping the fire), and CombatFx leaves the ruin under pixel dust, fading after 45 s or cleared when a
foundation is laid on it. Picture: `archive/images/2026-10-26/16-destruction-in-game.png` (a rat house).

- The first try knocked down the rats' only Town Center: the fall played under a big gold "Victory!" banner
  and the match ended. The check now knocks down a house.
- The first dust was polka dots: every puff a lit ball of its own. Now all puffs draw in shade, then mid tone
  up-left, then a small highlight further up-left: the classic pixel-art cloud, lit as one billow.
- A fading ruin can't just lower its alpha: the team-colour shader reads modulate alpha as shade (lowering it would
  darken it, not fade it). The ruin moves into a CanvasGroup when it falls, and the group fades.
- Cost: ~+8 s on a cold start; four-to-a-render only helps the smaller buildings.

## Fidelity round F1 (night)

Dominic: "I want to see if we can get our units looking much better and more realistic. They are simple and
cartoony atm". Round F1 (`docs/concepts/fidelity/`) first asked where the cartoon comes from. Five units baked
four ways (today, smooth pre-rendered shading, 2x painted, 2x smooth): the smooth bakes looked *more* like vinyl
toys, not less; the painted bands and outline were hiding how blobby the models are. 2x adds detail but keeps
the 3.4-heads-tall toy soldier. So it's the models: proportions, primitive shapes, flat saturated colour.

Stretching today's legs and shrinking the head failed the placement check at once (feet 5-8 units under the
ground): new proportions mean a new body. So Claude modelled a whole legionary by Blender script
(`tools/blender/concept_soldier.py`: an anatomical body, segmented plate, galea, scutum, gladius) at 7 heads and
at a broad 5.5, and baked it through the game's own unit baker beside today's (`tests/art_quality/fidelity_sheet.gd`).
They read as soldiers. At today's resolution a 7-head figure's head is ~5 pixels: realism needs 2x. Claude
recommends the heroic 5.5 build at 2x with the painted bands kept; Dominic to pick.

Pictures: `archive/images/2026-10-26/17-` to `21-fidelity-*.png`.

## Decisions

D-171 (destruction picked), D-172 (go-ahead; ruins are decoration, can be built over, fade). Before the feedback, Dominic was to pick. Claude's recommendations: destruction in stages next; deaths in 3D for every body;
pixel bolts and plasma as `shots.json` styles for the sci-fi mod; no global 2x (maybe buildings-only 2x,
and a Deck build with the flag to see it on the real screen).

## Bugs and surprises on the way

- **2x broke the atlas**: 23178 px tall at 4096 wide, over the GPU's 16384 (the game's assert caught it). The
  study widens the atlas to 8192 under the flag; a real 2x needs atlas pages.
- **1.5x has uneven pixels**: an art pixel is 1.33 screen pixels at play zoom, so some draw one pixel wide and
  some two. Only 2x lands on whole pixels.
- The first collapse squashed each wall box down whole: clean white blocks standing in the rubble, like a
  ruin made of sugar cubes. Walls now break into ragged stumps along their sides, with gaps.
- The first sci-fi capture froze a volley after the rats had all died: twelve troopers solemnly lasering
  a few deer.
- The fallen legionary lay end on in facings 0-3, boots to the camera; turned per facing (as the frog, D-166)
  every view reads.

## Pictures

`archive/images/2026-10-26/01-13-art-quality-*.png` (the same as `docs/concepts/art-quality/`).

## Ideas parked

- Buildings and props at 2x, units as today (where the gain shows most, a third of the memory).
- A weapon smear frame (an arc of pixels behind a heavy blow) with the follow-through hold.
- A ruin's sim rules (blocks? buildable? how long it stays?) if destruction is picked.
