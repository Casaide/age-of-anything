# WB1: war beasts (2026-10-13)

Milestone 13 step 7: "elephants for humans, giant toads for frogs, capybara-scale beasts for rats, a
rhino beetle, a tarantula; tanky vs buildings and infantry, weak to spears" (Stable, age 3). Nothing is
built yet: the `war_beast` slot stays `planned` in `data/rules/*.json` until you pick.

Sheets: `wb1_3x.png`, `wb1_1x.png`; archive `archive/images/2026-10-13/422-`, `423-`. Spec
`tests/sheets/war_beasts_wb1.json`, models `scenes/art_pixel/m13_concepts.gd`, staged from
`data/later/m13_concepts.json`. Drawn like the siege beasts (one baked body, its people on top on
sockets); the riders on the sheet are workers, in play they'd be the race's soldiers. All rows pass the
placement check. (2026-10-13, under the stronger composite check: the two riders in a howdah stood in
each other on every beast; they now sit corner to corner, and the frogs' toad and the spiders' tarantula
carry one rider in the middle, as two frogs or two spiders don't fit. Sheets re-rendered.)

| Family | A | B |
|---|---|---|
| Humans | war elephant with a howdah, two riders | armoured elephant: a caparison in the culture's cloth, bronze brow plate, one rider on its neck |
| Frogs | the giant toad (the bolt thrower's) with a howdah, one rider | the giant toad in thorned bark plates, one rider |
| Rats | a giant capybara with a howdah | a war boar, one rider |
| Forest beetles | a giant stag beetle (great jaws), a howdah | the ram's rhinoceros beetle (for comparison) |
| Spooky spiders | a tarantula with a howdah, one rider | a black widow (red hourglass), one rider |

What I see at game scale:
- The elephant is the strongest read on the sheet in every facing; the howdah version reads as "a lot
  of unit" at once. The armoured one is a little less clear (the caparison flattens its shape).
- The toad is a big frog again (as in SW1 round 3); with frogs on it, it's a frog pile. It works, but
  it's the weakest family read.
- The capybara with a howdah reads and is nothing like the cat the rats ride; the boar is dark and small
  for a war beast.
- The stag beetle and the rhino beetle look almost alike at 1x: the jaws don't carry. Since the rhino
  beetle is already the forest ram (D-117), the war beast needs something else to tell it apart.
- The tarantula and the black widow both read as giant spiders; the widow's hourglass is the clearest
  mark.

**Claude's recommendation:** humans A (howdah elephant), rats A (capybara), spiders B (black widow), and a
second look for frogs and beetles: for frogs a different beast from their siege (a giant salamander or
a heron-legged wader?), for beetles a different silhouette from the ram (a long-bodied stag with jaws
twice as big, or a giant ground beetle).

**Mechanics proposal (not built):** rider on a giant beast, priced through points as usual: lots of hp,
+3 pierce armour (the giant rule), a trample bonus vs infantry and buildings in data, and the `large`
tag so spears beat it; 3 pop.

**Questions for Dominic:**
1. A or B per family, or another beast (frogs, beetles)?
2. Riders: two (howdah: an archer and a spear?) or one?
3. Should they move (walking legs, as mounts do) or stay one baked body like the siege beasts? Walking
   means each beast becomes a mount body (creature-kit work, like the bears); static is how the turtle,
   snail and giant beetle engines work now.
