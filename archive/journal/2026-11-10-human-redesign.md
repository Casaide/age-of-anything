# 2026-11-10: Human units, sheets first, then the Romans in .vox

## What happened
- Dominic: rats great, frogs mostly okay, humans still worse; design every human unit in 2D first, like the Bulgarian man.
  Claude drew concept sheets for eight cultures and, at Dominic's ask, a ninth: Bulgars in the haidut's cut. Each has a
  base dress (front, side, back on 7.5-head lines, colour chips), a foot lineup and riders. Dominic approved them.
- Dominic on the first healer: "im not sure what the healer is supposed to look like... something generally more roman
  and mystical?" Every healer became its culture's priest or mystic (a veiled Roman priest with a snake staff, a Norse
  seer, an Orthodox priest, a Daoist, a priest painted black).
- Dominic's idea: a mostly human bear in the culture's armour, just larger. A test sheet showed a Roman bear-man in the
  legionary's kit unchanged at 1.3x, and a sitting frog reading as Roman in helmet, chest plate, shield and sword only.
- Asked how it works across three ages: the body is the base dress and never changes; each line upgrade swaps the gear
  (light, bronze and mail, iron and plate), and each unit keeps its one marker.
- Then the Romans in .vox: `families.json` `bodies` gives a culture its own body (#418), `roman.vox` is the base dress,
  and the worn kit is .vox gear fitted to it.

## Decisions
- D-246: culture bodies in the view only; kit stays gear so the ages show.

## Pictures
- `images/2026-11-10/91-romans-concept-base.png`: the approved base dress sheet.
- `images/2026-11-10/92-roman-vox-body-and-kit.png`: the body alone, then in leather and montefortino, mail and galea,
  and the segmentata, at 3x.

## Funny moments
- The first berserker sheet: his bear pelt was drawn in front of him, a brown slab with an axe sticking out.
- The first Roman helmets on the new body were the old generic dome, sized for a kalpak: grey buckets over the face.

## Ideas parked
- Age strips per culture (spear, sword, archer in ages 1 to 3), the Roman scutum curved with its wings, the other eight
  cultures, the bear-man.
