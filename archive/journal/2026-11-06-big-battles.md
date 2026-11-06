# 2026-11-06: big battles, for the trailer

**What happened.** Dominic played a 231-unit battle: laggy, and health bars floating over empty grass. Claude measured it: the lag was the voxel bakes on the main thread, the invisible units were types whose first look belongs to a later age. Dominic raised the target to 2,000 units zoomed out, for the trailer, then said it can't be shown without formation movement, and that attack-move should keep the formation too.

**Direction changes.** After several rounds of checking screenshots, Dominic: "TDD, nothing else", "prove it, fix it", "THEN play the game". `test_formations.lobster` was written and committed red (drift p99 53,624 milli-tiles at 1,000 a side), then the sim fixed until it passed (86).

**What the test found.** The first cut of blocks looked nearly right and was badly wrong: rows wider than the map, a march at exactly walking speed so nobody could ever catch up, slots on trees sending units on to the final target, and units unable to cross their own army because the crowd shoved them back.

**Pictures.** `archive/images/2026-11-06/`: armies funnelling at a ford (the bug), 2,000 marching in blocks, the contact.

**Funny.** Up to 62 of every type meant a forest of siege towers wading through a river.

**Parked.** Arrow speed (#175, Dominic's call). Bakes off the main thread.
