# Milestone 16: Sieges (and the first game modes)

**Status:** planned (proposed 2026-10-12; after milestone 13's siege engines)
**Exit criterion:** a walled town can be held and taken: defenders on the walls, attackers with
rams, ladders or siege towers, sappers and catapults making breaches; it reads clearly on screen;
neither side's win is a foregone conclusion at equal cost; the bot defends and assaults walls;
a 300-unit siege runs within the agreed tick budget; Dominic plays "Romans besiege the rats".

Dominic (2026-10-12): "Right now [walls are] small... I always wished you could garrison walls and
have larger scale sieges. My gut says a large scale siege, Romans vs rats, will go down very well.
We need a milestone focusing on siege mechanics, while keeping it simple and enjoyable." And: "we
should consider the effect of the 3 ms sim budget, if we're tying our hands too much."

## The line with milestone 13 (agreed 2026-10-13)

Milestone 13 brings the engines as plain damage dealers (ram, catapult, bolt thrower, great
sling, sapper). This milestone owns breaches (a destroyed wall tile becomes rubble, walkable and
repairable), walkways, gatehouses, wall towers, ladders, the siege tower (moved here from 13),
the defenders' tools and the game modes; it turns 13's sapper and catapult hits on walls into
breaches.

## Game modes (Dominic, 2026-10-12: "sieges should be the first step into game modes")

Sieges open the game modes, built on milestone 18's match rules contract:
- **Fortress:** every side starts with a walled town already built (palisade or stone ring with
  gatehouses and towers by its culture, a few defenders on the walls), more resources to spend on
  siege; matches are about breaking in and holding out.
- **Siege (attack/defend):** one side starts walled and stocked, the other with an army and siege
  engines; win by taking the Town Center, or by holding until a timer runs out.
- Each mode is data (start buildings and walls per map, rules), offered in the lobby, with the
  bot able to play both roles.

## Mechanics (simple first)
1. **Walls you stand on.** Stone walls get a walkway: ranged units ordered onto a wall stand on it
   (a few per tile), get +1 range and can't be hit by melee from the ground. Palisades stay
   walkway-free (cheap, early). Units reach the walkway through gatehouses and towers.
2. **Gatehouses and wall towers** join the wall line (a gate with a walkway over it; a tower that
   shoots and holds a garrison), placed into a line like gates are.
3. **Ways in:** rams batter gates and walls; ladders (a worker or infantry carries one, a few
   seconds to climb, defenders can push it off); siege towers dock on a wall and unload onto the
   walkway; sappers and catapults make **breaches** (a destroyed wall tile becomes rubble you can
   walk over, repairable by workers).
4. **Defenders' tools:** something poured on whoever's at the gate (each culture's version: hot oil,
   boiling swamp water, scalding cheese), and the existing garrison arrows.
5. **High ground** (milestone 15) makes walls on hills stronger.
6. **Readability:** units behind tall walls show as outlines (or walls fade near the cursor);
   wall damage states (cracks, then rubble); a breach is obvious.

## The tick budget
The sim targets 3 ms average per tick at 20 Hz (budget set in milestone 1 for 200 units, leaving
room for rendering and lockstep on modest machines). A tick at 20 Hz may take up to 50 ms, so 3 ms
is a self-imposed comfort margin, not a wall. For sieges we decide, with measurements:
- the unit count a big siege needs (300-500 together, crowds at a breach, the worst case for
  separation and flow fields);
- a new budget per unit count (e.g. 5 ms at 400 units on Dominic's Mac, still checked on a weaker
  machine before release);
- what to optimise first if needed: flow-field caching per target, separation only near movers,
  fog at a lower rate, crowds through gaps (the pathing work in progress).
Decision written down before building the big pieces, so we're not designing around a number we
don't need.

## Plan
1. Measure: a scripted 400-unit siege on a walled test map; set the budget (decision).
2. Walkways and garrisoned walls; gatehouses and wall towers.
3. Rams on gates, breaches and rubble, repair.
4. Ladders and siege towers.
5. Defenders' tools; readability (outlines, damage states).
6. The AI: defend walls (man the walkway, sally against rams), assault (bring rams and ladders,
   pick the weak side).
7. Game modes: Fortress and Siege (attack/defend) in the lobby, prebuilt walls per culture and
   map; a siege showcase map; balance; exit check.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Measure and set the budget
- [ ] 2. Walkways, gatehouses, wall towers (Dominic, 2026-10-13: "full siege with walkable walls etc")
- [ ] 3. Rams, breaches, repair (walls and breaches; workers repairing siege engines too)
- [ ] 4. Ladders, siege towers
- [ ] 5. Defenders' tools, readability
- [ ] 6. AI
- [ ] 7. Game modes (Fortress, Siege), showcase map, balance, exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `m13-unit-lines.md` (rams, catapults, sappers; the siege tower is this milestone's), `m15-maps.md` (high ground),
  `m12-tech-tree.md` (walls, gates, towers, garrison)
