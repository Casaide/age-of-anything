# Human motion, 2026-11-05

**What happened.** Dominic: the realistic humans are good, their animations uncanny. Reading the code found the best bug of the day: every human walked with the arm and leg of the same side going forward together. It had been there since the voxel units began, and shorter figures hid it. Planted feet also slid, and bodies hopped every other frame because the bob ran at twice the rate the eight steps could show.

**Decisions.** D-215. Dominic also asked to solve berry picking (it had no motion at all) and loads at the same time ("previously wed added wheelbarrows for rats, stuff like that generally a good idea").

**Pictures.** `archive/images/2026-11-05/08` to `11`.

**Ideas parked.** Rat, frog and bear still swing same-side arms: a `gait` on each once Dominic has judged the humans.
