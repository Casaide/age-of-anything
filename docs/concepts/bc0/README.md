# BC0: building scale (2026-10-11): picked

Rule (D-080): one footprint and one height envelope per building type for every culture; a
culture may sit lower and melded into its terrain, never taller or bulkier.

Measured (`tests/building_sizes.gd`): the rat and Roman Town Centres were already about the same
height and width (2.67 vs 2.48 tiles tall). The rat one *reads* bigger through mass: walls boxed
all the way up to a steep roof, on a brick plinth, where the Roman hall is broken up by its porch
and columns. So the fix is lower and settled, not smaller.

`rat-town-centre-scale.png`, made with `tests/building_sheet.gd`:

| Option | What changes |
|---|---|
| stone_town_center | the Roman hall, for reference |
| junk_town_center | the rat Town Centre today |
| junk_tc_low | walls 0.72 instead of 1.05, roof pitch 24 instead of 32 degrees |
| junk_tc_berm | as low, no plinth, a grassy earth bank up the walls with scrap half-buried in it |

If Dominic picks one, the same treatment goes to the rat house, barracks and stable, then to the
other creature cultures (frogs and bugs) as part of their town-centre rounds.

**Picked (Dominic):** the plinthless hall, made smaller than the Roman one in width, depth and
height, with scrap and weeds round its base (`rat-town-centre-small.png`): "that's great". Now in
play as `junk_town_center_small`. Human buildings always read biggest (D-081).
