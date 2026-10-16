# 2026-10-16: The war beasts walk

**Milestone:** 13 (unit lines), step 7: war beasts
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic spotted that the war elephant has no walk animation and that some views looked missing. First a look at all
five beasts in all eight facings (a new sheet, `tests/sheets/war_beasts_anim.json`): every facing was there, none
blank or magenta. But each beast was one rigid baked sprite moved like a siege engine, so it slid with its legs frozen.
It rocked 1% like a cart, lunged as one block to attack and tipped over like a cart to die. That stiffness is probably
what read as "wrong".

- **Legs and heads apart.** Each beast in play is now its body alone (siege_models.gd, `play`), with a leg part per kind
  baked at each hip, cut by the body as the mounts' legs are. The tarantula and mantis use one straight-out leg fanned
  forward or back by the hip's anchor. A head part (the elephant's head with trunk, ears and tusks; the boar's; the
  tarantula's jaws and palps; the heron's whole S of a neck; the mantis's fore body with its raptorial arms) is baked
  at its neck. The concept rounds keep their whole models.
- **Walking.** UnitView composes the beast like any creature under its riders: legs swing from the hips, the body
  rides on its planted foot, the riders ride with it. Each has its own gait in data: the elephant slow and heavy, the
  boar quicker, the tarantula's legs in a wave down each flank, the heron striding, the mantis picking along.
- **The blow** (data `beast.attack`): the elephant rears with its forefeet up and trunk high, then stamps down and
  sweeps its tusks through. The boar drops its head and steps back, then charges and tosses its tusks. The tarantula
  rears its front legs and drops onto the target jaws first. The heron draws its neck back and stabs. The mantis cocks
  its arms and snaps them out. The riders thrust with it.
- **The fall** (data `beast.fall`): the elephant and boar buckle at the knees and go over on their side, heavily. The
  tarantula drops onto its belly and its legs curl up and twitch. The heron folds and topples, its neck going down.
  The mantis's legs give way and its arms droop. The riders are thrown clear and fall in their own way.
- **The checks** caught the real problems as soon as they ran on the legs: joints buried inside the body (the boar's
  fore hips, the tarantula's middle hips, the heron's neck), the tarantula's back legs crossing through each other
  when they stepped in opposite phase, ears and jaws coming off as separate pieces, the boar's thighs inside its head.
  The placement check now also walks each beast on its own (`UnitView.beast_recipe`), and the composite's depth truth
  and crew-overlap checks include its legs and head.

## Decisions
- D-134 (Claude): war beasts are creatures, not carts: legs per hip, a head at the neck, a blow and a fall of their own.

## Pictures
- `01-war-beasts-before-facings.png`: all eight facings as they were (all present).
- `02-war-beasts-before-walk-sliding.png`: walking before: the same frozen legs in every step.
- `03-bug-engine-front-layer-white-squares.png`: the first composed beasts, a white square under each. An engine's
  "front" in its rig is a list of which crew draw in front, and the creature code read it as "has a front arm layer"
  and drew one that was never baked.
- `04-bug-heron-mantis-heads-fly-off.png`: the first strikes; the heron's neck and the mantis's arms leave the body
  entirely at the stab.
- `05-bug-riders-upright-on-fallen-elephant.png`: the elephant lies on its side and its two legionaries stand bolt
  upright on it: they toppled backwards just as far as it rolled forwards.
- `06-` to `10-`: the result (facings, walk cycle, strikes in facings 0 and 3, falls side on and going away); `11-` in a match (the elephants and boars walking in).

## Funny moments
- The legionaries standing to attention on a dead elephant (`05-`).
- The heron's first stab threw its whole neck a body length ahead, beak first, like a javelin.

## Ideas parked
- Bent legs while walking (`legs.poses`: an elephant's knee, a heron's backward heel) instead of stiff legs swinging.
- An elephant's trumpet with the tusk swing; ears flapping when it stands.
