# Order lines on hills (2026-11-06)

## What happened
Dominic reported (#221) that order lines cut straight through hills. Every mark was placed with the flat `iso`, at sea
level. Lifting the points wasn't enough, which only showed up in real captures:
- The hill's back-edge tops (occluders) are painted after the marks, so lines and rings vanished there. Orders and hill
  rings now draw after the last occluder.
- With that, low ground behind a hill showed its line over the hill's top, as a Z. Points the hill hides are now dropped
  (`ground_hidden`, the same "which ground is drawn at this pixel" as picking), so a line goes behind a hill and comes
  out on top.

## Decisions
Claude: legs stay in sim coordinates and go on the ground only when drawn (`game/relief.lobster`, which the unit tests can
import). A flag or ring behind a hill stays drawn: you want to see where you sent them.

## Pictures
`images/2026-11-06/08` and `09` (lines, before and after), `10` and `11` (rings, before and after).

## Ideas parked
HP bars still draw at sea level on a hill: its own issue.
