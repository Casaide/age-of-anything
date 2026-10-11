# 2026-10-11: Five ways to draw a frog

**Milestone:** art pass, step 1 (style sampler)
**Who:** Dominic + Claude (Claude Code)

## What happened

Dominic found the placeholder style "surprisingly cute" and wanted to start the art milestone.
Claude laid out five directions (storybook vector, paper puppets, painterly, pre-rendered toy
diorama, pixel art) and suggested sampling three. Dominic asked for samples of all five.

So the composer gained a drawing `style` (in `part_shape.gd`, the art pass's swap point), and
`scenes/style_sampler.tscn` shows one little scene five ways: grass, swamp, reeds, bug bushes, a
Town Center, a house, and a frog worker, a frog spear, a rat spear and a rat on a pony milling
about.
- **Storybook:** our shapes with a shade base, a lit top-left, highlights, ink lines and glinting
  eyes.
- **Paper:** rough-cut pieces with white borders and drop shadows, brass pins at the joints,
  paper grain; the ground as sheets with torn white edges where the terrain changes.
- **Painterly:** unlined shapes under a Kuwahara filter, labelled as faked.
- **Toy diorama:** real 3D. Frogs and rats built from spheres and cylinders, plastic materials,
  sun and soft shadows, SSAO, an orthographic camera at our exact 2:1 angle.
- **Pixel:** the scene rendered at a third of the size, fewer colours, nearest scaling.

All panels sit at the same in-game scale (one 2D pixel at zoom 1 matched to 3D world units),
with keys 1-5 for a 4x close-up.

### Then: detail, and a sixth direction

Dominic pointed out the important miss: the five panels varied the *rendering* of one
placeholder frog, not the art direction or the level of detail. He placed the classic RTS look
"somewhere between toy and pixel", said we hadn't tried higher fidelity, said buildings can
carry a lot because they're static, and then corrected himself: "more or less static, I'd
rather aim for a little bit of life to them".

So Claude built a sixth panel as a real pipeline prototype, not a mock-up: procedural PBR
materials, detailed 3D models (a frog Town Center with stone footing, timber frame, stepped
thatch, chimney, barrels, crate and woodpile; a stilt hut with a ladder; reeds, bug bushes and
tiles; a frog worker in six parts), and a baker that renders them at 4x into mipmapped
sprites. The 2D scene is built only from baked sprites. Buildings get life from live parts:
a banner waving through a shader, chimney smoke, flickering windows and a lantern, and a
dragonfly weathervane. Frog parts are baked with their pivots and walk with our 2D animation.

### Then: back to pixels, keeping the frogs

Dominic's verdict on the high-fidelity panel: we'd lost something the original and the pixel
art had. The 3D frog was a *different character*, so the frog people lost their whole feel. The
physically-based light went "a level too far, into uncanny valley": in the classic games you
never think about the lighting, because they're pixel games. He asked for high-fidelity *pixel
art* instead, with the presentation done properly: no grid, round water, the classic genre
in mind.

So Claude kept the characters exactly and changed only how they're made. Every 2D part becomes
simple lit 3D automatically (ellipses inflate, polygons get a bevel-ish tilt, lines become
rods), drawn in the original 2D order, baked at 4x and pixelized with a darker inner outline.
`UnitView` draws those sprites through a new "baked" `PartShape` style, so sockets, animation
and mounts didn't change at all. The step 1b buildings came back matte and pixelized with
baked ground shadows. The ground is one shader driven by blurred terrain masks (rounded
shorelines, a mud bank, foam, sparkles), and the whole frame goes through one palette with a
light ordered dither, at 2x nearest.

### Then: real units, with real textures

Dominic: "I don't mean keep the designs exactly, use them as reference". He wanted more detail;
units shouldn't feel made from a bunch of shapes (and they all had one leg). Then: "shapes will
need some actual textures", and he chose to have Claude author every texture rather than
download any. So Claude drew a texture set as SVG files: frog skin (spots, a few warts), belly,
an amber frog eye with a horizontal pupil, a smug mouth, leaf, lily pad, bark plates, stitched
leather, wicker, acorn scales, reed stalk, bone, rat fur, a bead eye, hammered bronze, worn iron
and wood grain. Each part id now has a hand-built 3D model (two legs, arms, hands, gear) that
uses them. The models' sockets are projected into 2D, so UnitView composes and animates them
like any other parts.

Dominic also spotted a frog standing on a hut roof and asked for the shadows to be fixed.

### Then: the plan's next steps, plus two notes from Dominic

Dominic asked for a full art-asset review after the next milestone (it's in the combat
milestone file) and to carry on with the next steps. The rat on a spider got modelled (a hairy
eight-legged mount, a team saddle cloth, fangs) along with the rest of the roster gear,
including a saucepan helmet with its handle. A new `tests/unit_lineup.gd` shows both rosters
at 4x for review.

Two notes came in while the terrain was being polished:
- **"Hard to see arms."** The near arm was part of the body sprite, the same colour as the
  torso, and armour drew over it. It's now its own baked layer with its own outline, drawn
  above the torso armour and below what the hands hold.
- **"Paths should be auto generated, and part of the race. Romans should get nice roads."**
  So `families.json` now carries a path style. A generator routes each side's paths (A* where
  existing paths are cheap, so branches merge into trunks; Chaikin smoothing) from the main
  building to its other buildings, resources and the shore. The shader draws trails,
  boardwalks, cobbles and roads with kerbs.

Steps 3 and 4 followed. **Stepped animation**: 8 walk poses, a one-pixel breathing bob instead
of stretched sprites, and whole-pixel positions (F toggles it). **Rat architecture**: families
now name their architecture, so sewer rats build a scrap Town Center (plank walls patched with
tin, a corrugated roof, a stove-pipe chimney, a cheese wheel, a sewer grate) and tin-can houses
with the lid propped on top. **Palette**: down to 256 colours by merging the nearest pairs.

Dominic caught the boardwalk twice. First "rotated wrong way?": planks used one fixed
diagonal, so on some paths they ran along the walk. Then "quite bugged there": shared
stretches were drawn twice, with different distances along the path, so the boards broke up.
Now boards are bands of arc length (always across the walk, even round bends), each stretch
belongs to one path, and where two cultures' paths meet, the locally stronger surface wins and
leaves a ragged seam.

Step 5 was the groundwork. Parts are baked once with a magenta team key; a shared shader
swaps key pixels for the team colour, which arrives in `self_modulate` (the far leg's shade
rides in its alpha). Every unit part, the unit shadows and every scene sprite (buildings, props,
doodads) go into one atlas with one material. Result: **20 draw calls for the whole frame at 211
units**, against 2,137 without the atlas. The batching risk in the MVP plan is retired.

Step 1e was the landscape. Dominic: "still a bit flat; bushes seem undone, water looks very
cheap, reeds look bad... getting there but not" the classic look. Then, from screenshots: the
reeds had "that big bottom placement thing", buildings had no shadow where they meet the
grass, the roof thatch was fuzz, and the bug bushes looked "like something clashing".
- The ground rolls now: soft height relief lit from the left in dithered bands, lush and dry
  grass, clover, a sandy bank and a wet edge round the water.
- Water has five depth bands, pebbles in the shallows, broken wavelet dashes that come and go,
  breathing foam, glints and lily pads (authored `water_lily` texture).
- Reeds are clumps of authored ribbon leaves with velvet cattails, without the base disc.
- Bug bushes are lumpy foliage masses with an authored foliage texture, a few edge leaves and
  red bugs. The first try was 95 leaf cards at random angles, which cut through each other.
- Thatch is an authored texture of straw courses running down the slope, each with a ragged
  light tip and a shadow under it, instead of stretched noise with a heavy normal map.
- Contact shadows: every baked building and prop now gets a short dark band under its lowest
  pixels, plus an ambient-occlusion pass, so it sits on the ground.

Then every remaining race got real art. Humans, ponies, beetles and all the metal-age gear were
still the automatic fallback, flat blocks next to the modelled frogs and rats. Now they have
hand-built models with new authored textures (cloth, skin, hide, mane, chitin, a human eye, a
horsehair plume, feather and bat wings): people in belted tunics with faces and hair, ponies
with manes and tails, horned beetles on six legs, swords, pole arms, bows, four kinds of shield,
crested helmets, cuirasses, capes, banners and quivers. Centaurs had a horse neck behind the
rider's torso; a fused mount now uses its own neckless body (`fused_body` on the pony).

Buildings now follow the culture too. Imperial, hellenic and royal peoples build in stone: a
columned hall on a stepped podium with a team frieze, a pediment shield and a fire bowl, and
limewashed villas with tile roofs, team shutters and a cypress. Steppe peoples live in felt
tents. Swamp and forest folk keep thatch; rats keep their junk.

To finish the round, a separate agent reviewed all the art: every race, culture, texture,
building and the landscape, in lineups, scenes, close-ups and 211-unit crowds. Its sharpest
finding: most infantry showed no team colour at all, and culture colours clashed with team
colours (red-tunic Romans on the blue team). Fixes made straight away:
- A team-colour kerchief on every frog, rat and human, drawn in the front layer so armour never
  hides it; human tunics are the team colour, with the culture in sleeves, trim and trousers.
- Beetles and spiders hold their gear at their flanks instead of in their faces, and their
  armour sits on the front of the body, clear of the team mark.
- A silhouette per weapon: spears stand upright, pikes slope over the shoulder, blowguns go to
  the mouth, slings whirl overhead, javelins are raised to throw.
- A Corinthian helmet with cheek guards and an open face; frogs show both eyes; rats get
  thicker arms; wings spread; ponies stand taller with bigger heads and darker manes; the
  unit light now matches the buildings' warm sun and cool shade.
- Building materials are authored textures now (planks, cut stone, daub, corrugated tin, brick,
  limewash, roof tiles, felt) instead of noise. Houses are 30% bigger and all fly a team pennant.
  The sun swung round a little, so the two visible roof faces differ.
- Field stones sit lower and darker; flowers have real heads; bugs on bushes are bigger.
The rest went to the backlog (section 9).

Then the vertical slice. Dominic asked why the debug match still used the old placeholder art.
The answer: the new art only lived in its candidate scene. Now the game view uses it. A new art
kit bakes both races' units, each culture's buildings and the props when a match starts (a few
seconds). The ground is the terrain shader, built from the sim's map, with rock outcrops added,
and culture paths re-planned whenever a building is finished. Resources are reed clumps and bug
bushes that vanish when used up. Buildings under construction brighten as they're built. The
camera zooms in whole art pixels, and the palette pass is a toggle (P). The old tile, building
and resource views are deleted.

## Decisions
- D-040: the art direction is open again; choose from the sampler.
- D-041: a sixth direction, high-fidelity pre-rendered, built as a real bake pipeline.
- D-042: the leading candidate is high-fidelity pixel art that keeps the original characters.
- D-043: units are hand-modelled per part id with authored textures; parts layer by child order.
- D-044: paths are generated and styled by the race's culture (families.json).
- D-045: buildings follow the race's culture too (families.json `architecture`).
- D-046: one atlas, one shared material, team colour via a baked key and self_modulate.
- D-047: landscape props and building materials use authored textures too; contact shadows are drawn.
- D-048: every part is modelled; fused mounts have their own body; stone and tent architecture.
- D-049: team colour on every unit (kerchief, team tunics); all building materials authored.
- D-050: woodland kit is signature gear; optional gear never goes off theme.
- D-051: the game view uses the pixel art (vertical slice); the placeholder views are gone.

## Pictures
![All five styles, same scene, same scale](../images/2026-10-11/08-style-sampler-all.png)
![Storybook close-up](../images/2026-10-11/09-style-storybook.png)
![Paper close-up](../images/2026-10-11/10-style-paper.png)
![Painterly (faked) close-up](../images/2026-10-11/11-style-painterly.png)
![Toy diorama close-up](../images/2026-10-11/12-style-toy.png)
![Pixel close-up](../images/2026-10-11/13-style-pixel.png)
![Six directions, now with high-fidelity pre-rendered](../images/2026-10-11/14-style-sampler-six.png)
![High-fidelity pre-rendered close-up: baked thatch, timber, glow, frogs in leaf hats](../images/2026-10-11/15-style-hifi-prerendered.png)
![High-fidelity pixel art at 2x: the original frogs and rats, a rounded pond, no grid](../images/2026-10-11/16-pixel-hifi-2x.png)
![The pixel-art map at 1x](../images/2026-10-11/17-pixel-hifi-overview.png)
![3x close-up, before units were scaled down: frogs as big as the Town Center](../images/2026-10-11/18-pixel-hifi-3x.png)
![Bug (Dominic's screenshot): a frog standing on the hut's roof](../images/2026-10-11/19-bug-frog-on-the-roof.png)
![The modelled, textured frog and rat rosters](../images/2026-10-11/20-modelled-units-lineup.png)
![Pixel scene with modelled units, shadows and correct overlap](../images/2026-10-11/21-pixel-modelled-units-2x.png)
![The rosters with the rat on a spider](../images/2026-10-11/23-lineup-with-spider-rider.png)
![Near arms as their own outlined layer](../images/2026-10-11/24-lineup-arms-as-own-layer.png)
![Generated paths: frog boardwalks, rat cobbles, plus stones, flowers and shore reeds](../images/2026-10-11/25-culture-paths-boardwalk-and-cobbles.png)
![Centaur Romans get paved roads (the centaurs are still unmodelled)](../images/2026-10-11/26-roman-roads.png)
![Bug: boardwalk stretches drawn twice, boards breaking up](../images/2026-10-11/27-bug-boardwalk-drawn-twice.png)
![256-colour palette, frogs vs rats](../images/2026-10-11/28-palette-256-frogs-vs-rats.png)
![Rat junk town; the boardwalk fixed and meeting the cobbles](../images/2026-10-11/29-rat-junk-town-and-fixed-boardwalk.png)
![One atlas, one material: 19 draw calls](../images/2026-10-11/30-one-atlas-19-draw-calls.png)
![Team colours from the shader: one bake serves every team](../images/2026-10-11/31-team-colour-from-the-shader.png)
![Landscape pass: rolling grass, bushes, thatch courses, pond](../images/2026-10-11/32-landscape-pass-2x.png)
![Pond close-up: depth bands, wavelets, lilies, cattail reeds](../images/2026-10-11/33-landscape-pond-and-reeds.png)
![Bug bushes and the new thatch, contact shadow under the Town Center](../images/2026-10-11/34-landscape-bushes-and-thatch.png)
![Bug bushes as leafy clumps (Dominic: "quite out of place still")](../images/2026-10-11/46-bug-bushes-leafy-clumps.png)
![Vertical slice: a frog opening in the real game view](../images/2026-10-11/47-vertical-slice-frog-opening-in-the-game.png)
![Vertical slice: centaur Romans vs steppe riders, rock outcrop, swamp and lake](../images/2026-10-11/48-vertical-slice-centaurs-vs-steppe-riders.png)
![Before: humans and centaurs still the automatic fallback](../images/2026-10-11/35-before-humans-centaurs-still-placeholder.png)
![Modelled centaur Romans and Greeks (first pass)](../images/2026-10-11/36-modelled-centaur-romans-and-greeks.png)
![Modelled beetles and royal knights](../images/2026-10-11/37-modelled-beetles-and-knights.png)
![Feather and bat wings](../images/2026-10-11/38-feather-and-bat-wings.png)
![Centaurs vs beetles in the scene](../images/2026-10-11/39-centaurs-vs-beetles-in-the-scene.png)
![Stone culture: a columned hall and villas](../images/2026-10-11/40-stone-culture-temple-hall-and-villas.png)
![Steppe felt tents across the road from a Roman villa](../images/2026-10-11/41-steppe-felt-tents-vs-roman-villa.png)
![After the review: team kerchiefs on frogs and rats](../images/2026-10-11/42-team-kerchiefs-frogs-and-rats.png)
![Beetles and spiders carry gear at their flanks](../images/2026-10-11/43-beetles-and-spiders-gear-off-their-faces.png)
![Team tunics, the sloped pike, spread wings, the new Corinthian helmet](../images/2026-10-11/44-team-tunics-pike-wings-corinthian.png)
![Authored building textures and team pennants on houses](../images/2026-10-11/45-authored-building-textures-and-house-pennants.png)

## Funny moments and bugs worth remembering
- **The frog on the roof.** Units are built from parts layered with `z_index`, and z_index is
  global in Godot. So any frog's head or spear outranked every building's y-sort, and a frog
  behind a hut appeared to stand on its thatch. Parts are now ordered by child order.
- **Shadows that stopped at the camera.** Buildings had no ground shadow because the shadow
  range (30) ended exactly where the bake camera sat (30 units out). Once that was fixed, the
  shadows were still too faint to survive pixelizing, so they're now baked in their own pass.
- **"Frogs look a little more like toads."** They were squat, warty and toad-brown. Now they
  have smoother spotted skin, an upright body, long folded legs, toe pads and bigger, higher eyes.
  The brown is the race's roll, so it stays.
- **The faces were inside the heads.** The first eye and mouth decals sat just under the skin and
  never showed. They now snap to the ellipsoid's surface.
- **Giant frogs, rats on the roof.** The first pixel bake had frogs nearly as tall as the Town
  Center walls, and the rat spearmen had wandered onto the stilt hut's thatch. Units now sit at
  70% scale, baked at that size, with their wander areas on open grass.
- **Uncanny valley, in a frog game.** Lesson from Dominic: fidelity isn't realism. The classic
  look is detailed *pixels*, not physically-based light.
- **The first bake was overexposed.** A key, a fill, a rim light and generous ambient light
  turned the grass mint and the thatch nearly white. The swamp read as speckled stone until it
  became dark, wet and nearly flat. The stilt-hut ladder leaned the wrong way twice (a sign error).
- **The shadows were there all along.** The toy diorama had no visible shadows through three
  rounds of tweaks to shadow modes and biases. The sun was shining *away* from the camera, so
  every shadow fell neatly behind the thing casting it. Turning the sun around fixed it at once.
- **Rats with three spears.** The first 3D rat tails were straight sticks at 70 degrees and read
  as extra weapons. They're now four chained segments curling along the ground.
- **Everything on one tile edge.** The first paper ground drew a white border round every tile,
  which looked like graph paper. Paper is sheets, so edges only go where the terrain changes.
- The first framing put the 3D panel at about half the scale of the 2D ones. It's now derived
  from the projection: a tile diagonal is 32 px, and in 3D that's sqrt(2) * sin(30 degrees) units.
- **The lettuce bushes.** Ninety-five flat leaf cards at random angles made each bug bush look
  like a salad with interference. Three lumps of foliage texture look more like a bush.
- **The centaur's spare neck.** The 2D centaur had always drawn the pony's neck, hidden behind
  the rider. Once modelled, the neck stuck out behind the human torso like a second head.
- **Everyone stands on one leg.** The first modelled humans had both legs lined up exactly
  behind each other from the camera's angle, so every person read as a "1". Staggering them
  front and back gave them two again.
- **Horse-tail tassels as barcode.** Dark tassels hanging over the steppe pennant turned into
  stripes once the banner wave shader moved them. They're gone.
- **Pumpkin heads and disco balls.** The reviewer's words: the Corinthian helmet made Greeks
  "pumpkin heads", mail on a spider read as a disco ball, and bark armour as a walnut.
- **The bush that wouldn't fit.** Three tries at the bug bushes: leaf cards (a salad), a fine
  foliage texture (green cushions), clumps of the same (still "out of place"). Dominic named the
  real problem: each try was a style nothing else in the game uses. They're now built like the
  units: smooth matte masses, the frogs' own leaf decals, clear bugs. Lesson: match the
  construction, not just the colours.

## Ideas parked
- Mixes: storybook units on painterly ground; toy-rendered parts with ink outlines; paper ground
  with storybook units.
