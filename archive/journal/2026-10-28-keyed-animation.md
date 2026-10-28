# 2026-10-28: keyed animation for every creature, frog B, the art study closed out

## What happened

Dominic, through the Lobster session: "continue the art", then "finish up the art". In order:

- **Crewed engines (2D draw order):** 12 failing units down to 4. A member nowhere against the engine now goes over it
  with the member in front of it; crew stand back from their place by their lean (`crew_back`) on the ground only.
  Several tries (sampling the engine's mesh faces, a depth buffer, a member's front instead of its middle) each fixed
  one case and broke others, and were dropped.
- **The full 3D check:** it never hung. One process took 11 minutes; the batch cut it off. It now runs in shards
  side by side (~2 minutes) and passes: 25650 checks, every fixture caught.
- **The rat's head and the blow:** the head nods a beat behind the stride; blows take 0.5 s, winding up, holding at the
  top, driving in, holding at contact.
- **Frog B (D-178):** modelled in Blender, squat, the trunk leaning 55 degrees; its legs keyed in 8 phases of the hop;
  armour fitted to its own trunk (the rat's armour script made general); no quiver (D-181).
- **Humans:** the heroic leg in pieces, bent at knee and ankle per walk step.
- **Horses and centaurs**, then **everything else with legs** on one shared keyed leg.
- **Three fixtures** that had stopped catching their bugs fixed (a fixture that can't fail checks nothing).

## Decisions

- D-181: the frog as built (no quiver, heel near the ground, cut head, `slung_lean`, crew stand-back).

## Funny moments

- The hummingbird fixture had been "checking" a hummingbird with no wings: the test built its mounts without the parts
  a hummingbird always has.
- A Python edit matched a `]]` a hundred lines further on and nearly ate a quarter of parts.json; the file had not been
  written yet.
- Frog crews kept poking their heads round the corner of the siege tower; they now stand seven units back.

## Pictures

- `archive/images/2026-10-28/01-frog-b-hop.gif`, `02-frog-b-facings.png`, `03-human-walk-keyed.gif`,
  `04-pony-walk-keyed.gif`, `05-creatures-walk-keyed.gif`.

## Ideas parked

- Arm swing walking for humans (the rat has it: `body_steps`).
- The per-member silhouette depth for crewed engines (C4's last cases).
- The howdah riders' weapons: Dominic's pick.
