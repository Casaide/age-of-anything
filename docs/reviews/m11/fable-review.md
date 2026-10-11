# Milestone 11 exit review: UI, UX and art (Fable, 2026-10-11)

Judged against what a player of a classic isometric RTS expects, and against `docs/concepts/direction.md`
("gone mad, played straight": played straight; structure, not stickers; silhouette first; one scale ladder; one
step per age). Material: `docs/reviews/m11/01-14`, plus captures of my own (worker build menu, farm, palisade,
a centaur-roman town at 6:00, a match at 10:00, a human-culture lobby) and the HUD code.

## 1. Verdict

**Not yet.** The art and the shell are close: the lobby is a real screen, the world is handsome, tooltips carry
the right facts, units read in eight facings. What fails the "a playtester would accept it" bar is the match
itself: a new player gets no warning when the AI raids (and it does, at 5-6 minutes, and wins at 10:00 against
a passive economy), can't tell the build buttons apart because the icons are identical, can't attack-move or
make a control group the way the genre taught them, and can restart or reveal the map by brushing a debug key.
Fix the six controls-and-feedback items at the top of the list below and this passes.

## 2. What works

- Lobby (`01`, `02`): clear hierarchy, team-coloured banners, live army preview, prices on the roster, honest
  generator notes, one obvious Start button. Pause and end-of-match menus exist.
- Tooltip cards (`04`, worker build menu): cost in resource colours, what it does, trains/researches, red
  "Needs", green "Unlocks". The right content, well set.
- World art: the painted pond and shoreline (`05`), rock outcrops (`06`), bushes, farms, the stone-culture
  temple with lit windows, the palisade line. The frog village on stilts over boardwalks is a real place.
- Units: eight facings read cleanly for rats, beetles and animals (`07`-`09`); shields and gear swap sides
  correctly; team colour is a consistent region.
- Resources show "N left" on click and visibly shrink; stone, gold and blocking rock are now three props.

## 3. Findings, ranked by harm to the first ten minutes

### UX (controls, feedback, clarity)

1. **No "under attack" signal.** `14-midgame` (6:00) and my 10:00 capture: rats are inside the frog base, no
   banner, no minimap ping, no sound unless the fight is on screen (`_play_events` plays "hit" only when
   `_on_screen`). The AI then wins. Fix: on the first enemy hit on your unit or building outside the view,
   play a horn, flash a red dot on the minimap at the spot for 4 s, show "Under attack!" top-centre for 3 s,
   and bind a key (Space, since it isn't pause in the genre) to jump the camera there. Throttle to one per 15 s.
2. **Debug keys live in a real match.** `_unhandled_input` only guards Tab behind `vs_ai`. R restarts the match,
   M swaps map, G regenerates your race, F7 spawns test armies, V reveals the fog, F6 hands you to the bot,
   `[ ]` change speed. Fix: when `vs_ai`, drop everything except Esc, Space, Q, U, the building hotkeys and
   (new) control groups; keep the rest behind F1 debug mode only.
3. **Attack-move and control groups are missing.** Attack-move is Ctrl+right-click and nothing in the vs-AI
   HUD says so (the hint lives in the hidden debug lines). `1`/`2` select whole armies. There is no Stop. Fix:
   when soldiers are selected the panel gets Attack-move (A) and Stop (S) buttons; A arms the attack cursor,
   then left-click; Ctrl+1..9 stores a group, 1..9 recalls it, double-tap centres; move camera panning to
   the arrow keys (keep WASD as an option) so A is free.
4. **No idle-worker button.** The info line says "Idle" only once you've found the frog. Fix: a button on the
   left of the bottom panel with an idle count, hotkey `.`, cycling through idle workers.
5. **No first-minute guidance.** The opening panel says "Select units or a building." (`03`). Fix: three
   one-time hints that dismiss themselves: "Click your Town Center, press Q to train a Gatherer", "Right-click
   a bush to gather", "Select a worker, press H for a house when population is near the cap".
6. **Age-up tooltip "Unlocks" lists units you already own** (`04`: "Unlocks: ... Gatherer Frog, Spearbearer
   Frog ..."). Reads as a lie. Fix: in `_age_tip`, list buildings and *new names* under "Unlocks", and the
   rest as "Upgrades: all unit lines get age-2 gear".
7. **Enter in the lobby prompt starts the battle** (`field.text_submitted -> _play()`). You type "centaur
   romans", hit Enter to see it, and you're in a match. Fix: Enter regenerates; only the Start button starts.
8. **No difficulty choice**, and the bot beats a new player (Dominic lost; a passive economy dies at 10:00).
   Fix: an Easy/Normal toggle on the AI banner; Easy delays the first attack wave to 10 minutes and halves
   its size.
9. **Mining shows the axe cursor** (`_update_cursor` maps stone and gold to "chop"). Fix: a pick cursor.
10. **No confirmation on Surrender / Back to the menu** (`13`). Fix: a second click, "Give up this match?".

### UI

1. **Build buttons are indistinguishable** (my worker capture: H, L, K, N, B, Y for the reed culture are all
   the same dome; for stone, archery range, armoury and mill are the same house). A player must hover ten
   buttons to find the Barracks. Fix: a 20 px function glyph in the button's bottom-right (bow, anvil, logs,
   sack, pick, horse, spear, tower, scales, wall), the same across cultures, and an icon bake at 2x so the
   props show. The hotkeys are not mnemonic (K mill, N mining camp, Y armoury, Z stable, J market, E archery
   range); if WASD moves to arrows, use A armoury, M mill, R range, S stable, K market, W wall.
2. **Minimap is too small and too dark.** 220x110 px for 64x64 tiles (3 px per tile); unexplored is
   `#0a0a0f` on a black fog edge, so it reads as a hole (`03`, `14`). Fix: 300x150 minimum, in the same framed
   card as the panel (`#2e2820` fill, `#6a5a40` edge), unexplored as dark brown `#1a1510`, explored at 70 %
   not 55 %, buildings as 3 px blocks, the camera box 2 px white.
3. **The end-of-match banner and the menu collide.** My 10:00 capture: "Defeat / Scurry Clan win" at 72 px
   sits on top of "Match over" and the button. Fix: hide the banner when the menu opens and make the result the
   menu's title ("Defeat: Scurry Clan win").
4. **Debug suffixes in player text:** "Town Center (P1)", "Bog Frogs (P1)". Fix: your own things get no
   suffix; enemy things get the race name ("Rot Horde Town Center"); the border colour already says whose.
5. **Age naming is inconsistent:** top bar "the First Age", tooltip "Stick Age", "Stone Age". Fix: name age
   1 in `tech.json` ("Mud Age") and use the data name everywhere.
6. **Bottom HUD is two floating cards with dead space between** (`03`). Acceptable, but the panel's 4 px
   team-coloured top edge is the only tie to the world. Fix: one bottom strip 1600 wide, panel left, alert
   and group tray centre, minimap right; or at least frame the minimap like the panel.
7. **Costs under buttons as "15F 10W"** in 11 px. Fix: two small resource icons with numbers; red number
   only for the resource you're short of.
8. **Worker portrait** fills a quarter of its 96 px frame (my worker capture). Fix: bake portraits at 2x
   and crop to the head and shoulders.
9. **Lobby:** 14 preset chips (7 per side) is noise; "Folk, Hellenic" (the creature word for humans) and the
   preset "greek hoplites" producing "No idea what 'hoplites' means" is embarrassing on the game's own
   presets. Fix: one preset row per side as a dropdown; "Humans, Hellenic"; add `hoplite` to the lexicon or
   change the preset to "greek spearmen". The roster list has an empty lower half; show unit portraits with
   role words (spear, skirmisher, archer, large) there.

### Art

1. **Buildings differ by stickers, not structure** (`10`, `11`). Direction rule two, in Dominic's own words
   about the lily pad. Reed: archery range, armoury, mill and mining camp are one dome with props beside it
   and the green leaf cap on every roof. Stone: three identical houses. Fix per type, same silhouette rule in
   every culture: archery range an open long shed with a butt lane; armoury a squat forge with a chimney and
   smoke; mill a platform of drying racks; mining camp a lean-to over a dug pit; drop the leaf cap except on
   the Town Center.
2. **Town Center lacks a landmark silhouette for frogs** (`14`: five domes, the TC only reads by its flag).
   Fix: a taller two-tier roof or a longhouse on the same footprint; houses to a 2x2 footprint and 70 % height.
3. **Market awnings use team colours** (`10`: blue and red cloth). Fix: cream, ochre and olive.
4. **Swamp mud pools** (`05` right) read as oil puddles: many small navy shapes on brown. Fix: fewer, larger
   pools with the pond's painted water and a lighter mud tone.
5. **Selection marks are too thin:** a 1 px white diamond on buildings, a 1.5 px ring on units. Fix: 2 px
   white with a 1 px dark edge, or the team colour at 80 %.
6. **Cursors** (`12`) are clean but the icon cursors have no pointer tip, so the hotspot is a guess. Fix: keep
   the arrow and badge it bottom-right at 16 px; add pick and "no" cursors.
7. **Boar silhouette** (`09`) is a dark lump; add a pale snout and tusks and a back ridge.
8. **Mineable stone** (pale cut blocks) versus blocking rock (grey outcrop) is distinguishable but
   counter-intuitive; a chipped face and a hovering name fix the read.

## 4. Top 10 fixes, in order

1. Under-attack alert: horn, minimap ping, banner, jump key.
2. Gate the debug keys behind F1 in vs-AI matches.
3. Attack-move (A) and Stop (S) buttons; Ctrl+1..9 control groups; panning on arrows.
4. Distinct build-button icons with function glyphs; mnemonic hotkeys.
5. Idle-worker button.
6. Minimap 300x150, framed, with readable fog colours.
7. Three one-time opening hints, and Easy/Normal on the AI banner.
8. Age-up tooltip: "Unlocks" only what's new; fix the result/menu overlap; drop "(P1)".
9. Buildings by structure: the four look-alike types per culture, and a landmark frog Town Center.
10. Lobby: Enter regenerates instead of starting; presets tidied; "hoplite" in the lexicon.
