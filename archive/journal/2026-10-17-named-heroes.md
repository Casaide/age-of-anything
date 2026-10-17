# 2026-10-17: Name your hero

**Milestone:** 14 (race identity and heroes), after its close
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic asked whether a race should get one hero picked from its description, so you could get the same one every
time. Heroes were already deterministic (same prompt and reroll, same heroes and names), so the real question was one
hero or several. We'd gone one (D-131) then all (D-138). Claude suggested letting the prompt choose: name a hero and
you get just that one; name none and you get the lot. Dominic: "Do it".

Hero words went into the lexicon (widow, silkmother, crown, sceptre, sleepy, lionheart, golden, shiny...), the
generator collects them like creatures and cultures, and `src/heroes.gd` keeps only the named ones among the race's
own. run_tests checks each word names a hero, the named prompts get exactly theirs on every reroll, the key holds the
ask, and a stray name gets a note.

## Decisions
- D-149: a prompt can name its hero; otherwise every hero, as before.

## Pictures
None: nothing on screen changes beyond which heroes the Town Center offers.

## Funny moments
- "roman widow": "Nobody called 'widow' leads humans, so their own heroes came instead." The Romans sent a tribune
  who yawned at elephants.
- "sewer rats with a crown" crowned Ratty the 10000th of His Name.

## Ideas parked
- A named hero from another race (a widow for the Romans) would need its look checked on every body first.
