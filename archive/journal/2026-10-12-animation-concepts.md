# 2026-10-12: Animation review and concepts

**Milestone:** after 11 (animation was never its own milestone)
**Who:** Dominic (the ask: "centaurs when gathering should kneel with front legs, but I'm sure
there's lots more; list findings before doing anything") + Claude (Claude Code)

## What happened
A review of how units move, from the code and four contact sheets (`tests/art_anim.gd`). The
rig is simple: rigid legs pivoting at the hip, the body with its arm baked in one fixed hold
pose, only the tool turning in the hand. So work is almost invisible for every race (a few
degrees of lean, the tool rotating), the animal half of centaurs and mounts does nothing,
armless creatures barely work at all, attacks are a weapon twitch, deaths a cardboard topple,
and walking a stiff rock. Idle fidgets, the frog hop, flyers' flapping and the 8-facing
snapping are fine.

Then concepts (D-080: options at game scale, Dominic picks, then build). Three questions,
three options each, rendered through the real rig and bakes by `tests/anim_concept_sheet.gd`:

- **Workers' arms:** W1 three baked arm poses (raise, low, reach) swapped through the work
  cycle; W2 two (raise, low); W3 as now. The poses are two new holds in `unit_models.arm_pose`
  ("reach", "raise") that the game never asks for yet; `UnitView.set_hold()` swaps the body's
  bake and moves the tool to the new hand.
- **Centaurs (and mounts) at work:** C1 kneel (front legs fold short, chest dips about the
  feet, the rider half leans in); C2 bow (the whole body pitches); C3 as now. The first kneel
  swung the front legs 77 degrees back under the belly and read as broken legs; folding them
  short with a small forward knee reads right.
- **Armless creatures (beetles, spiders):** A1 head-dig (head and body drive into the work);
  A2 pounce (the body rocks back and lunges); A3 as now.

Attack step-ins and deaths per body shape wait for the next round. Nothing here is in play:
the concept hooks (`UnitView.concept`, `set_hold`) only run when a sheet sets them.

## Decisions
- D-105: Dominic picked W1, C1 and A1 ("go ahead"); built the same day.

## Built (later the same day)
Workers' bodies are baked in the two work holds alongside their own (`bake_units`, workers only),
`UnitView.set_hold()` swaps them through the work cycle and keeps the hold across a facing
change, the fused mount kneels to forage with an eased fold, and harnessed bodies dig with the
head and body. The concept hooks stay for the next sheets. Live sheets: pictures 06 and 07.

## Pictures
![workers: humans, W1 three poses / W2 two / W3 as now](../images/2026-10-12/01-anim-concepts-workers-humans.png)
![workers: frogs](../images/2026-10-12/02-anim-concepts-workers-frogs.png)
![centaur: kneel, bow, as now](../images/2026-10-12/03-anim-concepts-centaur-kneel.png)
![beetle: head-dig, pounce, as now](../images/2026-10-12/04-anim-concepts-beetle-dig.png)
![spider: head-dig, pounce, as now](../images/2026-10-12/05-anim-concepts-spider-dig.png)
![built: humans and frogs at work through the game's own animation (walk, forage, chop, build)](../images/2026-10-12/06-work-poses-live-humans-frogs.png)
![built: centaurs kneeling to forage, beetles digging with the head](../images/2026-10-12/07-work-poses-live-centaur-beetle.png)

Dominic on the first live kneel: "deep isn't the issue. The knees aren't bent, and the body isn't
leaning back to maintain balance." So the front legs got a knee: the leg's own sprite shortens to
the knee and a second copy, the shin, folds back from it along the ground; the chest comes down
about the planted hind hooves and the human half leans back over the hindquarters.

![the kneel close up: knees bent, shins along the ground, the rider leaning back](../images/2026-10-12/08-centaur-kneel-close-up.png)

## Funny moments and bugs worth remembering
- Four Godot windows baking at once starved Dominic's running game of the GPU ("running game
  stopped btw"). One capture at a time from now on, headless where possible.
- The first concept sheet "hung": it was baking every age of every unit line of five races,
  which takes minutes. Workers only, and it takes one.

## Ideas parked
- Attack: a step-in and body lean, a draw-to-release swap for archers. Deaths: quadrupeds
  collapse down, bipeds topple, flyers drop first. Dust at building sites. (Next concept round.)

## Round two: attacks and deaths (concepts, pick pending)
`tests/anim_concept_sheet2.gd`, pictures 09-17. Attacks: T1 step-in (a lunge forward, the near
leg stepping, the arm swinging through its baked holds, or a spear thrusting; armless creatures
butt with the head), T2 swing only (holds and weapon, feet still), T3 as now (the weapon twitches
six pixels). Archers: R1 draw and loose (lean back, bow up, snap forward on the shot), R2 as now
(nothing). Deaths: D1 topple as now (the sprite tips 80 degrees about its feet), D2 crumple (legs
fold, the body sinks, the head drops, a rider slumps), D3 by shape (bipeds topple backwards with
a bounce, hoppers flop belly-up after a last little hop, four and six legs crumple, flyers drop
to the ground first and then topple).
