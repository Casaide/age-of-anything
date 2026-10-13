# TC1: trade carts (2026-10-13)

Milestone 13 step 6. The trade cart is built and in play (src/sim/trade.gd); it wore a **placeholder**,
B below (a plain handcart pushed by the race's worker), until this round.

**Picked (D-127, Dominic):** A, the race's own beast pulls a cart; for frogs a snail pulls it. The rats'
scrap barrow and handcart become what rat workers push when they carry stone and gold home. In play
since 2026-10-13: `siege_models.gd trade_cart` (pony, cat, beetle, spider in draught harness on the cart's
shafts; the frogs' snail baked in with its cart, a frog leading), sheet `tests/sheets/trade_carts_play.json`;
the rats' barrows `tests/sheets/rat_push_home.json`. Archive `archive/images/2026-10-13/505-` to `508-`; the fixed TC1 round `500-` to `504-`.

Sheets: `tc1_3x.png` (close up), `tc1_1x.png` (game scale); archive `archive/images/2026-10-13/420-`, `421-`
(as first shown), and the fixed round below. Spec `tests/sheets/trade_carts_tc1.json`, models
`scenes/art_pixel/cart_concepts.gd`, staged from `data/later/trade_carts.json` (nothing there is in play).

**A was broken, and the checks passed it (fixed 2026-10-13).** Dominic, on A for rats: "this is bugged,
did the tests not catch it?" The rat stood inside the cat, the traces were loose lines, the cart floated
behind. Why it passed: the sheet tool did run the placement check on the row, but on an engine the check
only measured the cart itself, how much of each member sat inside the cart, and (in 2D) whether each
member was over or under the cart. The cat was never checked as a unit, the members never against each
other, nothing walking, the traces and the cart's attachment not at all; and UnitView drew the hauler
over every crew member on its side, so the rat beside the cat drew under it in every facing. The traces
ran from a swingletree to points in the air by the cat's chest, with no harness, the cart 20 units behind.
Now:
- every A beast wears a **draught harness** (`harness.draught`, fitted on its body: a breast band, two
  back bands, a trace down each flank past the rump), and the cart's **shafts end where the traces end**
  (the cart's `hitch0_near/_far` sockets);
- the handler walks at the beast's head, out past its legs, layered by depth with the beast;
- the covered wagon's ponies wear it too, on a pole and an evener bar; the spiders' silk sledge has a bone
  across its runners for the drag line (it began in the air);
- the placement check covers composites whole (docs/rendering.md, "Composites": members apart walking too,
  harness on the shafts, no loose ends, the 3D depth order, each member as a unit, no silent passes), and
  fixtures put the old A for rats back and must fail it.

Every row passes the stronger check.

| | Humans (timber) | Frogs | Rats (junk, D-116 human scale) | Forest beetles | Spooky spiders |
|---|---|---|---|---|---|
| **A** the race's mount pulls | pony | giant newt | alley cat | cavalry beetle | spider |
| **B** handcart (in play) | worker pushes | frog pushes | rat pushes | beetle pushes | spider pushes |
| **C** each family's own | covered wagon, two ponies | giant snail with panniers, a frog riding | scrap barrow (pipe frame, crate, oil barrel, cheese) | a ball of goods packed in earth, rolled dung-beetle style | silk-wrapped bundle on a bone sledge, dragged |

A is drawn the new way: the cart is one baked part, and its beast is the race's real mount in its draught
harness, composed and walking on the cart's `haul0` socket (UnitView, recipe `haul`), like the siege crews. So the pony's legs
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
