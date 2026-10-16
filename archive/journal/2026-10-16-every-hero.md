# 2026-10-16: Every hero

**Milestone:** 14 (race identity), step 9: heroes
**Who:** Dominic + Claude (Claude Code, a session started by another session)

## What happened
Heroes had been paused on 2026-10-14 on a WIP branch (all 21 HR2 characters as a pool, one per race). Dominic resumed
them with a change: "heroes i thought we'd do all of them, so each race has some variety." The WIP came onto a fresh
branch (`heroes-all`) from main without a conflict, and step 9 was finished there.

- **All of them** (D-136): a race gets every hero its creature and culture name; humans (whose heroes come only from
  their culture), spooky spiders and forest beetles are topped up from kindred cultures to three. Each hero is its
  own unit type on the hero line; trained once at the Town Center, one of each out at a time, all of them together if
  you can pay. Auras take the strongest of each stat, so three heroes don't make +3.
- **In the game:** a Heroes group on the Town Center (Train, Revive, or why not), a small gold crown over each hero,
  its name while selected, the tech tree's node per hero, the lobby's Heroes group, a horn call when one takes the
  field and a sagging horn when one falls (the synth, tools/audio/sfx.py).
- **Every look on every body:** the placement checks now dress every playable body in every hero it can get. 65
  failures at first: lion pelts under the ground on beetles, capes through frogs' haunches, wolf pelts into beetle
  shells, hats over spiders' eyes, the cleaver into spider legs. Fixed with data, not special cases: a body's `drape`
  socket and `drape_scale` for hanging capes, low-slung hat variants, and a per-creature `fit` (or "keep your own
  weapon") in heroes.json. The full placement check passes.
- **Balance:** the first mass battles had heroes winning 60 of 60. Two causes: flat +120 hp is five times a rat's
  swordsman but only twice a centaur's, and armour stacked with the other heroes' armour auras until enemy blows did
  the minimum. Now a hero is a share of its swordsman (3x hit points, 1.3x attack, no armour bonus) for 30 points.
- **The bot** saves for its next hero; a bot with an economy fields two or three.

## Decisions
- D-136 (Dominic's call, Claude's rules for how they play): all of a race's heroes, one of each out, auras don't add up.

## Pictures
- `archive/images/2026-10-16/01-heroes-lineup-creatures.png`, `02-heroes-lineup-humans.png`: every race's heroes, age 3
- `03-heroes-in-match.png`: swamp frogs' three heroes by their Town Center, Hopsworth the Damp selected
- `04-heroes-town-center-buttons.png`: the Town Center's Heroes group, one waiting to be revived

## Funny moments
- The mass battle's heroes cost more than the whole enemy army and still won: their auras gave each other armour.
- Two centaur heroes were both called Stampedes. Now a race's heroes never share a name (a kindred hero borrows one
  from home), and the tempers lost their "he"s: Cornelia the Unbothered no longer drags "his" cloak.

## Ideas parked
- The forest rats' bark and bronze armour sits 1.5 off the torso's middle on their ordinary units too (found while
  dressing rats; not a hero bug).
- The walled-base bot check: with heroes in the army the battle's timing shifts and its archers nick a second piece of
  wall; the piece runs without heroes for now.
- "hard beats normal" in test_ai slow fails on main too (a 30-minute draw).
