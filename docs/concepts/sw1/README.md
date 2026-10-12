# SW1: siege engines (2026-10-13), waiting on Dominic

Milestone 13's siege concept round. Each engine is shown in five family takes and two directions,
baked like unit parts (8-facing pipeline, three facings shown), with the race's worker beside it
for size. `*_3x.png` is the close-up; `*_1x.png` is the game's scale (one art pixel per screen
pixel). Models: `scenes/art_pixel/siege_concepts.gd` (nothing in play). Sheet:

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet.gd -- out_dir 1.5   # game scale
```

**Direction A, the engine alone:** one baked sprite; the crew is hidden (ram) or implied. Moves
and dies as one thing, like the genre's engines. Cheap to draw.
**Direction B, the crew shows:** the race's own units push, pull or aim it, composed by the view
on the engine's sockets (two beside a ram, two pulling a flinger, one aiming a bolt thrower).

| Engine | A | B |
|---|---|---|
| Ram | covered shed, eaves nearly to the ground, the head out in front | open ram hung from two A-frames, crew walking alongside; forest: a rhinoceros beetle pushes the log |
| Catapult | arm-and-cup engine on wheels, arm up against a padded crossbar, cup loaded | tall pole flinger, the sling on the ground behind, two crew pulling the ropes |
| Bolt thrower | big crossbow on a two-wheeled carriage with a trail, like a field gun | lighter crossbow on a tripod, a crew member behind it aiming |

**Family takes** (the same in both directions where they apply):
- **Humans (timber, every culture):** timber and iron, spoked wheels, a hide roof with battens;
  culture trim is a hem in the culture's cloth along the eaves (imperial red shown). Iron ram cap,
  a stone in the cup, an iron-headed bolt.
- **Frogs (swamp):** lily-pad sledges on reed runners instead of wheels; the ram's shed is three
  lily pads like scales, the log a reed bundle with a river stone lashed on; a reed arm with a snail
  shell cup and a mud ball; a reed bow with a thorn bolt.
- **Rats (sewer):** bottle-cap wheels; the shed an upturned sardine tin with its key-rolled lid
  and printed label; the ram a sharpened pencil; a spoon catapult throwing cheese; a bottle-cap
  sling pouch; a wire bow shooting a knitting needle.
- **Beetles (forest):** log-slice wheels; a mossy shed with a leaf fringe and acorn caps; a
  beetle-horn ram head; a bent twig arm with an acorn cup; a thorn bolt.
- **Spiders (spooky):** dark wood, bone spokes and bone ribs over dark hide, a skull ram head, a
  femur arm with a skull cup throwing a ball of web, a rib bow strung with silk.

**Team colour:** a small cloth on each engine: a drape over the ram's ridge (a rag on the tin,
a leaf banner), the catapult's crossbar pad, a cloth on the bolt thrower's trail, pennants on the
frogs' engines. In B the crew's own kerchiefs carry it too.

**What reads at game scale (Claude's look):**
- The open ram (B) reads as a ram at 1x better than the shed (A): the log is the silhouette. The
  shed reads as "a covered wagon with a point" for humans; the frogs' pads and the rats' pencil
  read at once.
- The arm-and-cup catapult (A) reads as a catapult in every facing. The pole flinger (B) reads as
  siege but is wide, and its crew cover the base.
- The bolt thrower on wheels (A) is small and busy at 1x; the tripod (B) needs its gunner to read.
- Frog crews are big (the crouched frog): in B they cover their engine.
- The rats' sardine tin bakes very pale on top; if picked it wants a darker tin.

**Claude's recommendation:** ram **B** (open, crew alongside; the forest's beetle-pushed ram is
the showpiece), catapult **A** (arm-and-cup, one sprite), bolt thrower **A** (wheeled carriage, made
a touch bigger). That is: crews where they make the silhouette (a ram is a log carried by
people), one sprite where the machine makes it. Every family take as shown, with the timber
engines shared by the human cultures and trimmed in their cloth.

**For Dominic to pick:**
1. Per engine, A or B (or B everywhere, if the crews are the charm).
2. The forest ram: beetle-pushed for beetles (and other forest races), or crew like the rest?
3. Any family take to redo (the rats' tin shed, the frogs' reed bundle...).
4. Size: the engines are about 1.3x (ram) to 1.6x (catapult) a soldier's length. Bigger?
