# 2026-11-04: the ground drawn once, not sixty times a second

**What happened.** Dominic's MacBook runs hot in a match. The suspect was the terrain shader, recomputed for every pixel at 60 fps though only water moves. The ground now goes through a window-sized picture while the camera holds still, redrawn at 15 Hz for the water and when a texture it reads changes. GPU power fell from 2.1-3.1 W to about 1.0-1.3 W. Claude.

**Decisions.** D-209.

**Funny moments.** GPU% barely moved (25 to 22) and nearly talked me out of it. It scales with the clock; the energy counters showed the saving.

**Ideas parked.** Skip the 15 Hz when no water is in view (down to about 0.6 W). The bake's 5 W of CPU on a new race is the bigger burst.
