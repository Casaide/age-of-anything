# Milestone 19 UI review: what makes the genre's screens exciting, and what ours lack (Claude, 2026-10-12)

Dominic (2026-10-12): "text is all too small on the lobby too. Actually, let's do the UI review now: look at all
the other games in the genre; we agree race-specific UI, but it also just needs to be generally more exciting.
Please do the full review and fix now."

Captures are in `archive/images/2026-10-12/` (200-204 before, 205-210 the three directions, 211 onwards after).
All were taken on Dominic's MacBook screen (a 2902 x 1632 window) at his saved UI size (50%), so they show what
he sees.

## 1. What the genre does (references studied in words only)

Sources read (named here only generically, per the originality rules): a studio's public write-up on
redesigning the icons of a recent WW2-era RTS, [UI strategy game design dos and don'ts](https://www.gamedeveloper.com/design/ui-strategy-game-design-dos-and-don-ts),
a players' forum thread on a classic historical RTS's UI refresh, the changelog of a fan-made per-culture UI
mod for a historical strategy game, a pre-alpha UI discussion for a historical 4X, notes on how fantasy games
pair a display face with a text face, and notes on UI feedback and transition timing
([screen transitions](https://bugnet.io/blog/how-to-implement-screen-transitions-that-feel-good),
[Godot button feedback](https://forum.godotengine.org/t/button-feedback-provide-audiovisual-feedback-to-players-when-they-interact-with-buttons/125117)).
What follows is what we take from them, in our own words; no layout, art or type is copied.

**Materials and depth.** The screens that feel like a game, not a tool, are made of *things*: carved and inlaid
wood, beaten metal, dressed stone, parchment, cloth. Every panel has an edge that catches light (a lit top lip,
a shadowed foot), sits on the world with a soft shadow, and has wells cut into it for what's "inside" (the
minimap, the queue, portraits). Flat translucent rectangles read as modern and cheap; players of a historical
4X said exactly that about its early translucent, borderless widgets.

**Framing.** The HUD frames the battle like a picture: a heavy beam along the top, a weighty panel along the
bottom, the minimap set into its own frame. Corners are where ornament lives (studs, rivets, cast pieces);
long runs stay quiet so the eye goes to the content.

**Typography.** One display face for titles and names (classical, carved or engraved capitals; a serif with
presence), one plain readable face for everything that's read in a hurry (numbers, costs, tooltips). Small
spaced capitals for captions. The display face is kept to big sizes; at small sizes it turns to mush. Sizes
are generous: numbers in the top bar are read in a glance, mid-fight.

**Hierarchy.** What you can *do* is biggest (command buttons), what you *have* is a glance away (resources,
pop), what's *happening* is in wells (queue, progress). One primary action per screen gets the most weight
(Start, Resume); everything else steps down. Player feedback on that icon redesign: hard borders and painted
icons read faster than translucent or rendered ones; identity comes from shape and contrast, not detail.

**Motion and sound.** Buttons answer the pointer: a tick and a small lift on hover, a click and a sink on
press. Screens arrive in about 0.15-0.3 s (a fade and a short rise); a pause menu comes up almost at once.
Stingers mark moments (an age reached, the battle starting). It's the sum of small answers that makes a UI
feel alive.

**Faction identity.** The proven approach is to keep one layout and swap the *dressing*: background texture
(wood, stone, marble, relief), ornament set, accent colour. Grouping cultures by style (a marble frieze for
the Mediterranean ones, reliefs for the river ones) works; motifs that belong to one culture look wrong on
another (players objected to one culture's dragons on everyone's loading bar). So: a neutral look for menus,
the race's look on its own panels.

**Lobbies and menus build anticipation.** The title screen shows the game, not a void: armies, a battlefield,
a banner. The setup screen is a war table: the two sides face each other, each under its banner with its
army on show, the map in the middle, and a call to arms you can't miss. Nothing jumps when you change things.

## 2. Our screens, before (Claude's findings)

| Screen | Capture | What's wrong | The fix |
|---|---|---|---|
| Title menu | 200 | A void: one flat brown gradient, title in the default sans, three flat boxes. Nothing of the game on it. | Display-face title with a cast crest, a framed plaque of buttons with Battle as the primary, the two rolled armies facing each other on a lit hill below. |
| Lobby | 201 | Text 13-16 px at 1.2x: tiny on a MacBook ("text is all too small"). Panels are flat rectangles with a thin line; banners have no weight; the roster is a list; half of each banner is empty; Start is a plain box. Team colour is a loud top border. | Whole lobby rebuilt on the theme: body type 20 px, names 42 px in the display face, the window filled (scaled to the screen); each side in its race's culture (frame, crest, a cloth banner in the culture's cut with a team-coloured hem); the army on a lit stage sunk in the panel; roster as cards (portrait, role, name, cost with icons); notes under it; a cast "vs" medallion; the map in a well; the AI's level as three buttons; Start as a big breathing primary button with its own horn-and-drum sound. Fixed sizes: nothing moves. |
| Loader ("Baking the art") | (another agent) | A text line on black. | Owned by the loader agent; it can use the same theme (`src/view/ui/theme.gd`). |
| HUD top bar | 202 | A flat strip in one corner, small type, items floating with no grouping. | A beam in the race's frame material; each resource sunk in a plaque with a 28 px icon and 20 px bold number; race name in the display face; the age badge as a plaque; idle and tech tree as themed buttons; the clock in a plaque. |
| Command panel | 202 | Flat dark panel with a team-coloured top border (loud); 11-13 px captions and costs; buttons are flat boxes. | Framed in the race's material with its crest on the top edge; buttons are lit, raised material buttons that sink when pressed, with the accent rim on the age-up; the queue and portrait in wells; captions in spaced capitals; title in the display face; HP as a lit bar. |
| Unit card | 202, card | The card text is 13 px grey in the panel's info line. | Now 15 px in the theme's dim colour beside a display-face title; still a text block (see open issues). |
| Tooltips | 202 | Flat grey-brown card, 14 px. | A card in the race's panel material with a metal rim and soft shadow; title in the display face at 20 px, text at 15 px, all scaled with the HUD. |
| Minimap | 202 | A flat brown diamond with a thin line; floats in the corner. | A diamond frame in the race's frame material, lit on its upper edges, shaded below, a stud at each point, a dark well inside, a shadow under it. |
| Pause | 203 | A gold word and five flat boxes floating over the map. | A framed card in the race's culture (crest, display title, a rule, Resume as the primary, the rest as material buttons), arriving with a fade and rise and a page sound. |
| End screen | (pause) | The pause menu with a "Victory" line. | The same card as a result: Victory or Defeat at 72 px in gold or red, who won, how long, the age you reached, the next level's nudge. |
| Tech tree page | 204 | Flat panels, 11-15 px type, a lot of empty canvas. | The page wears the race: wood backdrop, framed panels (the race panel with its crest), display-face titles, captions and rules, slots with metal rims and inner shadow, themed tooltip cards; type a size or two up. The empty canvas under the tree is still there (see open issues). |

## 3. Three directions (mock renders: the real lobby and a HUD mock, `tests/ui_directions.gd`)

All three are the same theme with different data (`data/ui.json` "directions"); each race's identity (frame,
accent, crest, banner) is laid over whichever is picked.

- **A. Carved timber and bronze** (205, 206). Dark walnut faces, bronze frames with domed studs, gold display
  type. In this one each culture also brings its own face material (porphyry marble for imperial, blue-grey
  marble under white marble for hellenic, bog wood under a reed frame for swamp, rusted iron for sewer, red
  felt with a stitched leather frame for steppe, green-stained wood for forest). Warm, matches the buildings'
  timber and thatch, keeps the old palette's warmth, reads well over a bright map.
- **B. Parchment and tooled leather** (207, 208). Light parchment faces, leather frames, dark ink type. The
  most "almanac" of the three and the most distinctive, but pale panels fight the bright meadow, every piece of
  type needs inverting (the title over the dark table and the tooltip both failed in the mock), and the
  cultures can't bring their own faces without losing the parchment.
- **C. Chiselled stone and iron** (209, 210). Grey dressed-stone faces in courses, iron frames, forge-orange
  accent. Solid and readable, but cold and samey; the block joints behind text are busy, and it suits a
  castle culture more than frogs in a bog.

**Recommended and built: A.** It's the warmest, it lets every culture bring its own material (the race-specific
UI Dominic asked for goes furthest in it), and it sits best with the art. Switching is one line in
`data/ui.json` (`"direction"`), so Dominic can try B or C in the real game.

## 4. What was built (the shared theme)

- `src/view/ui/theme.gd`: looks (direction + culture), the Theme (labels, buttons, primary, icon and accent
  buttons, fields, option lists, panels, frames with crests, cards, wells, plaques, slots, tooltips, bars,
  scroll bars), type, `juice()` (hover tick and lift, click and sink), `arrive()` (a screen's fade and rise),
  a rule and a medallion. One file every screen uses; the loader agent can use it too.
- `src/view/ui/ui_materials.gd`: the materials, painted in code as seamless tiles at twice the UI's pixel size.
- `src/view/ui/ui_box.gd`: a StyleBox of a frame round a face, lit, raised or sunk, studs/rivets/bindings/
  stitching at the corners, a crest on the top edge.
- `src/view/ui/ui_banner.gd`: the cloth banner (eight cuts) on a metal rod, folds, the team-coloured hem.
- `assets/art/ui/crest_*.svg` (by `tools/ui/crests.py`): twelve cast crests: sun (menus), laurel, meander,
  reeds, rivets and bottle cap, stitched lozenge with tassels, oak leaves and acorn, crown, crossed bones,
  lotus, cloud scrolls, stepped fret.
- `data/families.json`: a `ui` block per culture (all eleven; imperial, hellenic, swamp, sewer, steppe and
  forest tuned, royal, spooky, nile, han and aztec given their own sensible ones).
- Sounds: `ui_hover` (a fingertip on wood) and `ui_start` (war horn over two drum strokes) in the synth.
- Type: the display face is the system's classical serif for now (Palatino on a Mac) and the text face is
  Godot's own. Fonts dropped into `assets/fonts/` win (see open issues).

## 5. Open issues (not fixed here)

- **Fonts.** An open-licence display face (an engraved-capitals face such as Cinzel, OFL) and a text face
  would make the type ours on every machine; that needs a download, which needs Dominic's yes. The theme
  already loads `assets/fonts/display.ttf`, `text.ttf`, `text_bold.ttf` if present.
- **Unit card** is still a text block; it wants stat icons (attack, armour, speed) and strong/weak as
  portraits.
- **Tech tree** canvas leaves its lower half empty on a tall window; the tree could scale to fill.
- **End screen** has no match story yet (armies, losses, a timeline); the sim doesn't keep those counts.
- **Race Lab and the counter quiz** still use their old flat styles.
- The lobby's banners show the race's bonuses and hero only in the tech tree page (milestone 14 data).
