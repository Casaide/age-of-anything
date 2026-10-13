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


---

# WB2: war beasts, round 2 (2026-10-13)

Dominic on WB1 (D-127): "we're focusing on capybara too much, doesn't really fit. Boar is better but maybe
too small. Spider riding a spider seems pointless, better just a tarantula." The elephant (humans A) stays.

Sheets: `wb2_3x.png`, `wb2_1x.png`; archive `archive/images/2026-10-13/486-`, `487-`. Spec
`tests/sheets/war_beasts_wb2.json` (size references: a worker, a pony rider, a spider rider), models
`scenes/art_pixel/m13_concepts.gd` (WB2), staged from `data/later/m13_concepts.json`. All rows pass the
placement check. Built as before: one baked body, its people on the deck (shown as workers; in play the
race's soldiers).

| Family | A | B |
|---|---|---|
| Humans | the war elephant with a howdah (WB1 A, kept) | |
| Rats | a **war boar** about twice the pony's height at the shoulder: a front-heavy hump, thin legs, a long wedge of a head, big tusks, a grizzled crest of bristles, rusted scrap riveted on its flanks; a pallet howdah chained on, two rats | the same boar barded in scrap: a plate cover, a face plate with a pipe spike, one rider, a scrap standard |
| Spiders | a **giant tarantula, alone**: legs across about 80 (the spider mount's about 30), furred, orange-banded knees, fangs, a glinting eye cluster; a silk-and-bone harness, a team banner with a skull finial; nobody rides it | the same with a small crew of two in a basket on its back |
| Frogs | a **giant crayfish**: red-brown plates, two great claws up and open, long feelers; a howdah, two frogs | a **giant grey heron** (the frogs' oldest enemy, broken to the saddle): stilt legs, an S of a neck, a dagger beak; one frog |
| Forest beetles | a **giant praying mantis**: leaf-green, spiked arms folded, the long neck up; one beetle | a **giant centipede**: long and low, yellow legs down its length, a long deck, two beetles |

None of the frogs' or beetles' new beasts repeats their siege beasts (turtle, snail, toad; the rhinoceros beetle).

What I see at game scale:
- The boar now reads as big (much bigger than the pony, close to the elephant's body) and as a boar from the
  side (tusks, hump, wedge head). From behind it's a brown barrel; the bristle crest could be bolder.
- The tarantula is the strongest new read: the legs make it the widest thing on the sheet, the orange knees
  carry at 1x. A (banner) is cleaner; B's crew is small on it and brings back the spider-on-spider look.
- The crayfish reads by its claws in every facing; the frogs on top cover its back (as on the toad).
- The heron is the tallest beast and unmistakable, and the joke lands; it's thin, so it looks fragile for a
  tank unit.
- The mantis is a striking silhouette but slight; the centipede reads as "long", and from the front it's a
  stack of riders.

**Claude's recommendation:** humans the elephant (kept); rats A (boar with the howdah); spiders A (tarantula
alone with its banner); frogs A (crayfish: armoured and clawed, reads as a tank); beetles B (centipede: the
clearest "big and unlike anything else" of the two; the mantis if you'd rather have the silhouette).

**Questions for Dominic:**
1. The picks per family (A or B), or another beast?
2. The boar: howdah (two riders) or barded with one?
3. Still one baked body (like the siege beasts), or walking beasts (each a creature-kit mount: more work)?
