# 3D-baked vs pixel-drawn, for buildings especially (research, 2026-10-11)

Dominic: "That's why I wonder if pixel drawing would give more freedom." The unit side of this
question is in `../direction.md` (the R0 bake-off, which Claude is running separately). This file
is about buildings: organic, irregular, culture-rich forms (woven reed, packed earth, silk) and
what each pipeline does for them. Game references are codes; see [README.md](README.md).

## 1. What the genre and its neighbours do

| Approach | Examples | What it gives | What it costs |
|---|---|---|---|
| **Pre-rendered 3D, then cleaned up in 2D** | The classic RTSs of the late 1990s [G1][G4][G13], settlement games [G38]. Their units and buildings were modelled and rendered in 3D, then sprites were fixed by hand in a paint program. The remaster of the medieval classic re-rendered new 3D models to 4K sprites [G34] | Consistent light and perspective across hundreds of sprites; cheap facings and animation; buildings with real volume | Looks "CG" if left raw; organic forms need real modelling |
| **Hand-drawn pixel art** | A pixel-art animal RTS [G17], a pixel side-scrolling kingdom game [G35], a pixel strategy game with heroes and armies [G32] | Every pixel chosen: clean silhouettes, painterly material, total freedom of form | Every view, age, construction stage and team mask drawn by hand; consistency of light is the artist's job |
| **Hybrids** | A roguelike that renders 3D models to pixel art with no anti-aliasing and toon light [G33]; the pixel strategy game above, which lights flat sprites with normal maps in a 3D-lit world [G32]; 2D sprites in a 3D diorama world [G40]; a fighting game that bends 3D to look hand-drawn [G40]; a papercraft RPG of 2D drawings in 3D [G23] | Most of pixel art's crispness with most of 3D's cheap variation | Tooling; a style that must be tuned once |

## 2. The real limit isn't 3D; it's building from primitives in code

`src/view/art/bake/models.gd` builds everything from `box`, `cyl`, `ball`, `dome` and `ring`.
That's why the reed dome is a hemisphere and the mound is a lump: those are the shapes the
toolbox has. A pixel artist with the same brief ("a dome with a lily pad") would draw the same lazy
hut, just prettier. **The brief fixes the laziness; the pipeline sets cost and finish.**

3D can make organic forms if the code builds them **the way they're really built**. Each culture's
construction logic (in `creature-cultures.md`) maps to a small generator:

| Culture grammar | Generator (3D, in Godot with `SurfaceTool`/`ArrayMesh`) |
|---|---|
| Reed bundles bent into arches (frogs) | A tube swept along a parabola, with a slight twist and taper, plus binding rings at intervals; an arch row along a ground line |
| Lattice end screens, reed mats | A grid of thin swept strips over and under (geometry, not texture, so it reads at 1x) |
| Pad shingles, wing-case shingles, bottle-cap shingles | Instanced scatter of one small mesh over a surface, overlapping in rows, each slightly rotated |
| Pellet walls, fluted spires (beetles) | A lathe profile with vertical flutes and noise; or instanced pellets on a shell; chimney holes boolean-cut or as dark discs |
| Musgum ribs, thorn bristles | Ribs as swept tubes on the shell surface; thorns as instanced cones along normals |
| Silk sheets and funnels (spiders) | A grid membrane hung between mast points with catenary sag (simple maths), slightly translucent; guy-lines as thin tubes to ground pegs |
| Stitched cases, junk stacks (spiders, rats) | Instanced recognisable objects (can, cap, crate, twig) placed by a stacking rule, lashed with string tubes |

These are a few hundred lines of code, reused by every building of a culture, and they make the
age growth trivial (more arches, taller spire, more stacked boxes).

## 3. What each pipeline does for organic buildings

| | 3D primitives (now) | 3D with construction generators | Hand-pixel | Hybrid: generator bake + pixel post |
|---|---|---|---|---|
| Woven reed | flat texture on a dome: muddy at 1x | real ribs and bindings: reads at 1x | best: drawn rhythm | ribs from 3D, bindings as pixel stamps |
| Packed earth, pellets | smooth lump | flutes, chimneys, noise: good | best: painterly clods | good |
| Silk membrane | not possible | possible (sag, translucency); bakes need care | very good: a few light lines and a sheen | good |
| Junk (cans, caps) | good (they're primitives!) | good | good | good |
| Consistent light with units and other buildings | yes | yes | artist's job | yes |
| Ages x construction stages x team mask | free (re-bake) | free | drawn: ~6 types x 3 ages x 4 stages = ~72 drawings per culture, plus masks | free bake; post pass automatic; stamps reused |
| Who can make it now | Claude | Claude | an artist; Claude can author pixel art in code, but large organic sprites are its weak spot | Claude |

**Why buildings differ from units:** a building needs **one view** (no facings), few animation
frames (a flag, smoke), and a fixed set per architecture (about 12 architectures, not one per
prompt). So hand-pixel costs far less for buildings than for units (8 facings x every part x
animation). If we ever hire a pixel artist, buildings and portraits are where to spend it first;
units stay in a 3D or hybrid pipeline because of the facings.

**Claude's view:** go hybrid. Build each culture's construction generators in 3D, bake with the
banded toon light being tuned for units (contender A+ in `../direction.md`), then a pixel post
pass: quantise to the culture palette, a 1 px outline in dark local colour, and a small library of
hand-authored pixel stamps at native resolution (a binding band, a door, a motif) placed by the
model's anchors. Keep a hand paint-over as an option for town centres only. Decide with the test
below rather than on opinion.

## 4. The building half of the bake-off

Run it alongside R0 (units), with the same judging spirit: the same design in every contender, so
the test compares pipelines, not designs.

**Subject:** the frog **age-2 house** in the F1 grammar (`creature-cultures.md`): a 5-arch
bundled-reed hall on a round reed island, one lattice end with a low wide door, pad shingles on
the weather side, team-colour bindings. It's the hardest common case (woven, organic, small).
Stretch subject: the spider S1 **funnel lodge** (a silk membrane: the hardest material).

| | Contender | What it is | Claude time (rough) |
|---|---|---|---|
| A | Control | today's `reed_house`, unchanged | 0 |
| A+ | 3D generators | bundle-arch, lattice and shingle generators; toon light; no texture on small details | ~0.5-1 day (the generators are reused afterwards) |
| B | Pixel-drawn | drawn at native resolution by Claude in one view, with a separate team-mask layer and one construction stage | ~1 day |
| C | Hybrid | A+ bake, plus palette quantise, local-colour outline and 2-3 pixel stamps (bindings, door, lattice) | ~0.5 day on top of A+ |

**Shown:** each contender at 1x and 3x, on swamp ground, beside today's Roman villa and a frog
infantry unit, and in a row with an age-1 and age-3 version where the contender can make them.

**Judged on (in order):**
1. **Who lives here?** A blind pick from frog, beetle, rat, Roman with flags and lily pads hidden.
2. **How was it built?** Can Dominic say "bundles of reed bent into arches" from the picture alone?
3. Sits with the Roman and steppe buildings and the units at 1x (light, outline, palette).
4. Obeys the scale ladder (`buildings.md` section 3).
5. Hours to make the age-1 and age-3 versions and the construction stages.
6. Team mask: one region, readable.
7. Holds up at zoom 1x, 2x and 3x.

**Rule:** take the cheapest pipeline that passes 1-3, same as for units.
