# 2026-11-03: the tech tree page, ported from the Godot one at last

## What happened
Dominic: "tech tree looks terrible? it's not been ported at all from godot, see our old pictures of it". He was
right: the port (2026-10-26) had brought over the tree's model, but drew it as plain coloured boxes with names and
a text panel underneath (picture 10). The Godot page (`scenes/tech_tree.gd`, read from git: `22be3d36^`) and its
pictures (`2026-10-13/604-...`, `2026-10-11/197-...`) were the target.

Claude ported the page whole, in `src/game/techtree_page.lobster` (the model stays in `game/techtree.lobster`):
- the title bar: "Tech tree: <race>" in the display face, the key (can get, planned, race's own; in a match also
  have it, under way, not yet), Close (Esc);
- the race panel in its culture's look, with its crest: the name, creature and culture, the army idling on grass,
  Bonuses, Own research, Lacks and Moves under gold rules with diamonds, and the count of what's in the game;
- the tree: the ages down a rail (numeral, name, what each needs, with the stand-in for a lacked building), a
  column per building from its age down, its picture on top with a bus line branching to its lanes, units'
  portraits and research icons in their rows, solid joins along a line or track and dashed ones between strangers,
  lacked things crossed out, the race's own marked with a gold diamond, planned things as dashed blank frames;
- scrolling sideways (wheel, drag, arrows, Home/End, the bar, the sticks), the race panel by the wheel over it;
- the hover card (picture 12): the name and its line, the cost in each resource's colour, the description, the
  unit's numbers or a research's effects in green, where and when;
- in a match, the player's progress as Godot showed it (picture 13): built and researched lit gold, under way with
  a bar, not yet dimmed, the current age marked on the rail and an age-up's bar under the next.

The model gained what Godot's had and Lobster's lacked: each age's needs, a node's line, first step, early kit,
the unit's numbers, the research's icon and "only for", a building's hotkey, the race's moves (groups.json's
movement words), and the cost as data. `race_lacks` now takes the rules it's asked about (the lobby passed the
match's).

## How it draws (Dominic: performance matters)
Every picture (a building's bake in the race's architecture, a unit's bust from the panel, a research icon) is
painted once, at its size on the screen, into one 2048 page; the tree draws them all from it in one mesh. Fills
and lines go through `ui_batch`, text through the text cache. The lane lists and joins are worked out once per
layout, not per frame. In the lobby, where no buildings are baked yet, the race's architecture is read from the
shipped bakes when the page opens; portraits wait for their parts (baked between frames) behind Godot's loader,
"Painting the portraits..." with a bar (picture 15).

## Pad and touch
B, Start or the phone's back button close it (Start no longer also opens the pause menu under it). The left stick
scrolls the tree, the right one the race panel; the d-pad walks the nodes, showing each one's card, the tree
following (new: Godot's pad only scrolled). A drag scrolls, a tap shows a card.

## Pictures
- `archive/images/2026-11-03/10-tech-tree-before-the-port.png`: before (the lobby, bog frogs).
- `11-tech-tree-ported-from-godot.png`: after, the same page; compare `2026-10-13/604-...`.
- `12-tech-tree-hover-card.png`: the card, as `2026-10-11/197-...`.
- `13-tech-tree-in-a-match.png`: in a match, the Town Center and the workers lit, the age marked.
- `14-tech-tree-scrolled-to-the-castle.png`: scrolled to the end, the race's own research marked.
- `15-tech-tree-painting-the-portraits.png`: the loader while the portraits are painted.

## Left
- With `voxels`, the portraits are still the composed busts the panel uses (the voxel frames are per unit type, the
  tree's line steps aren't all types).
- The army stage shows every unit of the race, siege engines included, as Godot did; the tower stands over the rest.
- The captures came out at 2582 x 1834 (the window this session), not 3024 x 1834 as 604 was.
