# TC1: trade carts (2026-10-13)

Milestone 13 step 6. The trade cart is built and in play (src/sim/trade.gd), wearing a **placeholder**:
B below, a plain handcart pushed by the race's worker, for every family. This round is for the real look.

Sheets: `tc1_3x.png` (close up), `tc1_1x.png` (game scale); archive `archive/images/2026-10-13/420-`, `421-`.
Spec `tests/sheets/trade_carts_tc1.json`, models `scenes/art_pixel/cart_concepts.gd`, staged from
`data/later/trade_carts.json` (nothing there is in play). Every row passes the placement check.

| | Humans (timber) | Frogs | Rats (junk, D-116 human scale) | Forest beetles | Spooky spiders |
|---|---|---|---|---|---|
| **A** the race's mount pulls | pony | giant newt | alley cat | cavalry beetle | spider |
| **B** handcart (in play) | worker pushes | frog pushes | rat pushes | beetle pushes | spider pushes |
| **C** each family's own | covered wagon, two ponies | giant snail with panniers, a frog riding | scrap barrow (pipe frame, crate, oil barrel, cheese) | a ball of goods packed in earth, rolled dung-beetle style | silk-wrapped bundle on a bone sledge, dragged |

A is drawn the new way: the cart is one baked part, and its beast is the race's real mount, composed and
walking on the cart's `haul0` socket (UnitView, recipe `haul`), like the siege crews. So the pony's legs
move, and any race that rides something pulls with it, no new beast art.

What I see at game scale:
- A reads as "a trade cart" best in every facing: the beast in front says it's going somewhere. The
  newt is long, so the frogs' cart is the longest thing on the sheet; the cat pulling for the rats is
  funny and reads.
- B (the placeholder) is small; the load and the team cloth read, the handcart less so.
- C: the covered wagon is the classic trader's look (big, two ponies); the snail is lovely but big; the
  beetles' ball of goods is the most "this game" option and reads at once; the spiders' silk bundle is
  clear; the rats' barrow is small, like B.

**Claude's recommendation:** A for humans, rats, beetles and spiders (each pulls with its own mount), and
the snail (C) for frogs (the newt cart is very long and the snail matches their siege, D-122); the
beetles' ball of goods (C) as an alternative if you like it more than their beetle cart.

**Questions for Dominic:**
1. A, B or C per family (or one direction for everyone)?
2. The beetles' ball of goods: keep the joke?
3. For A: a handler walking beside (as shown) or nobody?
4. Size: carts are the size of a cavalry unit in the sim (radius 420); fine?

Mechanics (built, for reference): Market, age 2, 95 wood 55 gold, 1 pop, speed 10 (Pack Animals +25%,
age 3 at the Market). Right-click a market of yours or an ally's at least 20 tiles away: goods loaded
there, gold paid at home, `d*d/50 + d/2` a round trip (30 tiles: 33 gold in about 55 s; 50 tiles: 75
gold). A cart killed on the way home loses its load. The bot keeps up to 6 on its farthest market pair.
