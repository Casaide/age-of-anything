# 2026-10-16: Forest rats' armour

**Milestone:** placement fixes (art), found while finishing heroes (milestone 14 step 9)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dressing every playable body in every hero turned up a bug that wasn't the heroes': forest rats ("rats" makes
rat/forest) failed "worn armour centred on the torso" on their ordinary units. No placement case used forest rats,
so it had never been caught. Dominic said to fix it here.

- **Measured, not guessed:** all seven armours on a rat sat 1.1 to 1.5 units forward of the body's middle; the
  sewer rats' bottle caps and sardine tins were just inside the limit, forest rats' bark and bronze just over.
  The rat's torso socket moved back (1.4 to 0.8), so every armour now sits 0.6 to 1.1 off. From behind the bronze
  now wraps the back instead of riding on the chest. The old "rat leaning out of its armour" fixture puts the old
  value back with the old lean (`UnitModels.rat_torso_x`, like `rat_hunch`).
- **"rats" added to the placement PROMPTS** brought three more forest-rat problems:
  - the team banner's flag flew through the acorn cap (a rat's back is low): a `banner` socket on the rat, higher
    and in on the hunch, used for back parts tagged `banner`;
  - a horse archer's bow cut into its cat when the cat sat down (the cat pitches up, the rider stays upright): the
    seat sits 0.8 higher on a sitting cat;
  - with the armour moved back, the war boar's two armoured riders touched: 11.5 apart instead of 10.5.

## Pictures
- `archive/images/2026-10-16/05-forest-rat-armour-before.png`, `06-...-after.png`: the bronze spearman, 8 facings
- `07-forest-rat-banner-through-acorn.png`, `08-forest-rat-banner-after.png`: the swordsman's flag

## Funny moments
- Every rat's armour had been leaning forward all along; the sewer rats just had thinner armour.
