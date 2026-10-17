# 2026-10-17: Vikings get a culture of their own

## What happened
Dominic asked (2026-10-16) whether Vikings ever got a shield wall. They hadn't: "viking" only added horned helmets
and round shields to whatever culture a race drew (round 1's concept notes had already found "vikings" coming out
Greek). He wanted them to have their own culture; the tight formation stays milestone 22's. Claude built the Norse
culture as data (D-149):

- `norse` in data/families.json: sea-blue and madder-red cloth, ponies, thatch architecture, boardwalk paths (the
  plank streets of a trading town), an iron-framed wood UI with a new longship crest (tools/ui/crests.py), a
  scalloped banner, the boar as war beast (humans keep their elephant: the creature's wins).
- Bonuses: Plunder (kills bring in 3 gold; alt Raiders, +3 against buildings), Linden shields (shield-bearers +1
  pierce), Seafarers (no slowdown in shallows or fords, for allies too; alt Houses 25% cheaper). Own research
  Berserkergang (infantry +2 attack). Lacks the archers' age-3 step.
- The Berserker (fur cap, bearded axe, +3 attack, +10 HP, quick) is the culture's unique; "horned vikings" still get
  the old Horned Raider. The Raven-Feeder is its hero: a raven-winged helm, a raven on the shoulder, shield-brothers
  around it +1 melee armour. Kin: steppe, royal.
- New gear: bearded axe (age 2), broad axe (age 3 swordsman), fur cap, conical cap with a nasal, spectacle helmet,
  rune staff. All Norse-favoured and signature for everyone else.
- Words: viking(s), norse, norseman/men, northman/men, nordic, berserker; "horned" asks for horns; "raider" for
  light kit (so "norse raiders" has no unknown word).

## Decisions
- D-149. The helmets follow round 1's suggestion (Dominic never picked one). The braids and beards came off after
  the first placement run: they hung into frogs', rats' and beetles' chests (195 failures) and they vanish at game
  scale anyway.
- The first balance run had the Vikings at 0 of 12 (a 14-minute loss to the imperials: dearer age-1 soldiers, every
  one with a priced Raiders bonus and a shield). Plunder became the main bonus (unpriced) and the words stopped
  asking for shields on top of the culture's own: 1 win, 7 draws, 4 losses, level with imperial humans (8%) at the
  bottom of the range (8-41%). Humans as a whole are the weak creature (backlog §0b, race balance).

## Pictures
- 05, 06: the Norse lineup sheet (tests/sheets/norse_lineup.json), close up and at game scale; every row passes.
- 07: the lobby card: "Norse culture", the longship crest, the archers' missing step.
- 08: Norse against Romans at the bridge.
- 09: the bug found on the way: a round shield through a spider's head (no culture's shield was ever checked on a
  spider or a rearing beetle; backlog §0b).

## Funny moments
- The first rerun named a Norse frog hero "Jarl Sigrid the Shield-Breaker", and the generic hero check failed two
  older races because their titles ("General", "Sir") counted as first names.

## Ideas parked
- The shield wall formation (m22 step 4), a Norse concept round, longhouses, shields on spiders and beetles.
