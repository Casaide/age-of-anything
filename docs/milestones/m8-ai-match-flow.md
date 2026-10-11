# Milestone 8: AI + match flow

**Status:** closed (2026-10-11), Dominic: "close 8 and 10 for now". The AI beats a passive player (tested); the "loses to a decent player" playtest moves to `../backlog.md`
**Exit criterion:** AI beats a passive player and loses to a decent one.

## Scope
Data-driven build order, worker allocator (60/40 food/wood until age-up), two attack waves
(~min 5, ~min 8), counter-picks by reading enemy tags. The AI issues commands through the same
queue as the player. Race select screen (Frogs/Rats or a prompt), win/lose (destroy the TC or
surrender).

## Plan (2026-10-11, Claude)
1. **Match flow in the sim** (`src/sim/match.gd`): a player who started with a Town Center is out
   when none is left (finished or not) or when they surrender (`SURRENDER` command). When one
   team is left, it wins. Checked once a second, hashed, deterministic.
2. **The AI** (`src/ai/bot.gd`, data in `data/ai.json`): EcoBot runs the economy (60/40 food/wood,
   houses, age 2 at 16 workers); on top, a build order from data (Barracks at 11 workers; Stable
   and a second Barracks in age 2), soldiers from every military building, counter-picked by
   reading the enemy's army tags against our bonuses (minus theirs against our tags), defence
   near the Town Center, waves at 5:00 (5+ soldiers) and 8:00 (9+), then every 2 minutes, and
   units that run out of things to fight push on to the next enemy building. Age 3 at 24 workers.
3. **Tests** (`tests/test_ai.gd`): the bot beats a passive player with each race; bot vs bot is
   deterministic and ends; surrender ends a match.
4. **The view:** `vs_ai` mode (the AI plays side 2), F6 watches two AIs, F10 surrenders, a
   victory/defeat banner.
5. **Race select screen** (`scenes/match_setup.tscn`, now the main scene): a prompt and presets
   per side, a live preview of each race's name, roster and notes, a map pick, Play, and the way
   into the Race Lab.

## Checklist
- [x] Plan
- [x] Match flow: defeat, surrender, winner (sim, hashed)
- [x] AI: build order from data, soldiers, counter-picks, defence, waves, age 3
- [x] Tests: beats a passive player, bot vs bot deterministic, surrender
- [x] View: vs-AI mode, F10 surrender, victory/defeat banner
- [x] Race select screen
- [ ] Exit check: Dominic plays a match and wins as a decent player (moved to the backlog when Dominic closed the milestone)
- [x] Archive: pictures, journal, decisions, timeline

## Results
- **The bot beats a passive player** (it only runs an economy): frogs win at 14:01, rats at 10:29.
- **Bot vs bot** (frogs vs rats): rats win at 14:22; deterministic over two runs. The 8-12
  minute pacing target is milestone 10's to tune (wave sizes and timings are data).
- In the view, the rats' first wave reached an undefended frog town at 7:00
  (`archive/images/2026-10-11/101-ai-rats-raid-the-frog-town.png`).
