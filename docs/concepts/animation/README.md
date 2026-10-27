# Animation (study A2, 2026-10-27): B picked (D-179), the rat first

Dominic, watching a rat bot match in the Lobster game: "we reeeally need to improve animations. watching that rat
game was pretty lazy animations". The Lobster game composes units the way the Godot game does (its
`view/unit_view.lobster` is a port of `src/unit_view.gd`), so this study is of `UnitView`: what makes it read as lazy,
and the options. Nothing here is in the game. (An earlier round, the art-quality study's direction 3, added a
follow-through hold and 3D deaths: `docs/concepts/art-quality/`.)

## What it does today, and why it reads as lazy

A unit is a stack of baked part sprites (body with its arms, legs, head, gear) composed in 2D. Today:

| Action | What moves | What doesn't |
|---|---|---|
| Walk | each leg sprite swung like a pendulum (`sin`), the body riding on the lowest foot | knees (a leg is one stiff sprite; only cut legs with baked steps bend: the cat, war beasts), arms, head, tail, cape, weapon; the body leans by a hair |
| Blow | 0.35 s: the body lunges, the arm swaps through 2-3 baked holds (wound up, reaching), a spear thrusts | no anticipation (it starts already moving), no contact hold, no follow-through, no weight shift into the front foot |
| Work | the arm swaps between the raise and reach holds in a loop | the body and legs; the blow doesn't carry through |
| Idle | a one-pixel breath every 4 s | everything else |

![today: the rat walks (8 steps)](01-today-rat-walk.gif) ![today: the legionary walks](02-today-legionary-walk.gif)

![today's walk, frame by frame: rat, legionary, frog, rat on a cat](08-today-walk-frames.png)
![today's blow, frame by frame](09-today-blow-frames.png)

The rat's walk is the worst case: its legs are short and swing a few degrees, and its arms, head, tail and spear are
frozen, so it glides. The legionary's legs scissor with no knees. The frog's hop is the liveliest (it was keyed:
crouch, push, tuck, reach, land). The cat already shows the better way: its legs are baked in 8 walk steps with knees
bending, and it walks properly, but the rat on it sits frozen.

![today: the cat's legs baked in 8 walk steps](03-today-cat-walk-baked-steps.gif)

## Keyed in 3D: rat B walking and thrusting

The rat Dominic picked (round F2's B, D-177), posed in 3D frame by frame (`tools/blender/concept_creatures.py ...
anim`: two-bone legs placed by where each heel is, IK for the knee) and baked by the game's own unit baker
(`tests/art_quality/anim_frames.gd`):

- **Walk, 8 frames:** each heel planted and sliding back for half the cycle, lifted and swung forward for the other
  half, knees bending; the hips lowest as the feet pass; the trunk swaying; the free arm swinging against the legs;
  the tail following the hips a beat late; the head bobbing behind the body.
- **Thrust, 6 frames:** anticipation (it sits back, the spear drawn), wound back, the lunge with the front foot
  stepping, contact at full stretch, follow-through past it, the recovery. Timed in the GIF with a hold before the
  lunge and at the follow-through.

![keyed walk, side](04-keyed-rat-walk-side.gif) ![keyed walk, away](05-keyed-rat-walk-away.gif)
![keyed thrust, side](06-keyed-rat-thrust-side.gif) ![keyed thrust, away](07-keyed-rat-thrust-away.gif)

![the keyed frames in three facings](10-keyed-rat-frames.png)

## Options

| | What | Feel | Cost |
|---|---|---|---|
| **A. Composer polish** | no new bakes: a lean into the walk, the head bobbing a beat late, cape, tail and weapon swaying, anticipation and a contact hold in blows, a planted pause in work | a little livelier; the limbs are still stiff sprites. Squashing or turning whole sprites was already called "terrible" (round HF1), so A can't carry it alone | small, code only |
| **B. Keyed limbs, baked per body** (recommended) | every body's legs cut at the hip and baked in 8 walk steps with knees (as the cat's are now), its arms in more holds (walk swing, anticipation, contact, follow-through), its tail and head as their own cut parts in a few poses; the composer plays them as keyed cycles with A's timing on top | most of what the keyed rat shows; any creature, any gear still works (gear rides the baked hand) | per body type, shared by every unit of that creature: ~8 walk steps x legs + ~6 arm holds + tail/head poses, 8 facings each; an estimated few seconds a race on a cold start (not measured); every body's poses through the placement check |
| **C. Whole units pre-rendered** | each unit recipe posed in 3D and baked whole per frame (walk 8, blow 6, work 6, death 4...) in 8 facings: the classic pre-rendered sprite sheet | the best, every joint exact | per recipe, not per body: ~26 frames x 8 facings, ~5 s a recipe at the measured ~25 ms a render (D-165), about 3 minutes for a new race on a cold start: too slow when every prompt is a new race; gear can't swap between frames |

**Recommendation: B, with A's timing.** It follows the cat's and the war beasts' baked steps, which already work in
the game, keeps the parts kit (any creature, any gear), and costs per body type rather than per unit. C stays for
heroes or war beasts, where one recipe is seen a lot. Rat B (D-177) would be the first body built this way.


## Built: the rat (D-177, D-179)

The rat as a rat is, in the game: the trunk, tail and head modelled in Blender (`tools/blender/rat.py`), the legs in
code, digitigrade (thigh, shank, a long hind foot), baked in 8 walk steps with the knees bending (`UnitModels.rat_joints`,
two-bone IK; parts.json `legs.poses: 8`, as the cat's). Placement check: every rat unit, gear, mount and hero case in 3D;
the sheet's 2D and 3D checks on five rat rows (`tests/sheets/rat_b_play.json`).

![the rats in play, 8 facings](11-rat-b-in-play-facings.png)
![the keyed walk in play, side](12-rat-b-in-play-walk-side.gif) ![away](13-rat-b-in-play-walk-away.gif)

**Not passing yet (2026-10-27):** 3D: every rat case passes (26085 checks, 1 failed: the older spider-holding-a-scutum
fixture). 2D on the rats at 2x: 2119 checks, 10 failed: composite draw order (C4) on rat-crewed engines in one facing
each (ram, siege tower, great sling), a banner drawn in front of the body in facing 7, a scutum over a rat's face in
facing 0; and 4 regression fixtures no longer caught (a hummingbird's wings, the frog's hidden sword, the centaur's
kneel, TC1's rat and cat), some from the 2x switch rather than the rat. To fix before this is shown as done.

What the hunched build needed: the shield and sword hands out beside the trunk, a bow drawn higher, a rider sat back
on its saddle (its `sit` socket: its chest over its mount's back, not its neck), a ridden cat that only half sits; no
quiver, cloth or leaf cape (they hang straight and fall through a body leaning 42 degrees), and hero capes off rats
(heroes.json `fit.rat.back`); a wolf-hat hero wears the low-slung hat. Next for animation: the arm holds (walk swing,
anticipation, contact, follow-through) and the tail and head as moving parts, then A's timing in the composer.

## The rat's arms and tail walk too (2026-10-27)

Walking with what it holds low, the rat's body is baked in the same 8 steps as its legs (parts.json `body_steps`,
`body.rat@w<i>_<n>`): the near arm swings forward against the legs (rising a little) and back half as far (dipping:
rising, a held sword went up into the head, which the 3D check caught), the far shield arm a little the other way, and
the tail sweeps from side to side a beat behind the hips. The composer (`UnitView._walk_body`) switches the body's
sprite in time with the legs, and the weapon and shield follow the hands of that step. Archers holding a bow or
crossbow up, riders and crew in a box keep their bodies still. Placement: every rat case in 3D at every walk step
(2988 checks, 0 failed); the sheet's five rows in 2D.

![the cheesehammer rat walking](14-rat-b-arms-tail-walk.gif)
![the walk steps](15-rat-b-walk-steps.png)

Next: the head as its own posed part and A's timing in the composer (the head bobbing a beat late, anticipation and a
contact hold in the blow), then the other creatures one by one.

## The head and the blow's timing (2026-10-28)

The head is its own part in the composer: walking, it (and what it wears) bobs a beat behind the body's stride
(`UnitView.HEAD_NOD`, on whole pixels when stepped). A blow now takes 0.5 s (`BLOW_TIME`, was 0.35): the body sits back a
little as the weapon winds up and holds there a moment, drives into the blow, holds at contact, then settles
(`UnitView._blow_lunge`); the head dips into it a little after the body. A spear is drawn back, driven out, held at full
stretch, then carried again. Every creature gets this timing (A's timing on top of B, D-179). Placement: rats, romans,
frogs, bears, spiders, beetles and heroes in 2D, the rat sheet's rows.

![the cheesehammer rat's blow, facing the camera](16-rat-b-blow-timing.gif)
![the blow's frames: rest, wound up, driven, contact, contact, recovering](17-rat-b-blow-frames.png)
