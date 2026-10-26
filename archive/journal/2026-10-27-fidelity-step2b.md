# 2026-10-27: fidelity, step 2b (clothes, gear, the howdah) and round F2

## What happened

Milestone 23's 2x art and heroic humans went in yesterday (D-173). Dominic, looking: "feel like we're almost there,
but not 100%. The design (clothes etc) of the humans feels cheap still. And the rats and frogs dont feel same
quality". On round F1's figure: "this is good. conceptually we've gone from [one classic RTS] style to [another]"
(from a settlers-like look to the later, more realistic classics). "rats etc should follow". Then: "horse looks
great, but the elephant with units standing makes no sense now", and "also remove the banners".

- **Clothes:** a new trunk (`tools/blender/human_torso_heroic.py`): a ribcage, the chest forward, a wool tunic with
  folds to mid-thigh, the team colour on a sash and the hem (D-175); the arms in code now a short sleeve and a shaped
  bare arm instead of puffy balls. The worn armour refitted to the new chest.
- **Gear:** a Blender galea and scutum (`tools/blender/gear_roman.py`).
- **Banners:** only when asked for (D-174).
- **The howdah:** walled, its riders from the hips up (D-176).
- **Round F2:** rats and frogs, two takes each (`tools/blender/concept_creatures.py`); Dominic to pick.

## Bugs on the way

- The culture's red wool made the Romans read as the red team in a battle: the cloth is now mixed into undyed wool.
- Capes made "drapes" (to size them for the long legs) jumped to the rats' and spiders' hero-cape point and sank
  into their bodies; capes went back, and a body's own cape point (bears had one) now sizes the cape too.
- The new scutum's board is thicker than the old strips and pressed into frogs, beetles and spiders holding it.
- Moving the banner out of every unit's candidates shifted the generator's draws: the "rats ride cats" test's prompt
  drew a beetle (cats are 85%, not certain); the test uses a prompt that draws the cat.
- Rat B's team scarf floated off its chest: it leaned about its own ring, not the hips.

## Pictures

`archive/images/2026-10-27/01-f2-rats-frogs.png`, `02-howdah-walled.png`, `03-heroic-legionary-clothes-gear.png`.
