# 2026-10-27: the Lobster port's last gaps

## What happened

- **A new army mid-match with no pack.** Swapping in "moonbears with axes" crashed when no pack was used. Bears come
  from the creature kit, and Godot finishes the kit's bodies when it loads them (sockets, legs, idle poses); Lobster
  didn't. Ported that step (`kit_complete`, 12 of 12 the same as Godot). Then the rats became Hellenic moonbears at
  1:00, were balanced in 598 fights, and played on to 5:00 with their Greek town baked on the spot (`01-...`).
- **No file made by Godot.** The game was still reading two things a Godot tool had written: the textures (SVG to
  PNG) and the list of maps. The textures now come from rsvg-convert (`textures.sh`, within 1.5 levels of Godot's
  on average), and the maps are listed from `data/maps`.
- **The tech tree page:** research effects in words (all 56 the same as Godot's wording) and the race's hero (`02-...`).
- **The pad:** LB as Godot's pad has it. Held, X and Y queue and A adds to the selection; tapped, the next kind of
  what's selected. A or X gives an armed order. The pad self-test is 10 of 10, the mouse self-test 9 of 9.
- **The milestone file** says plainly what Godot is still for: the parity checks, optional packs, and the GDScript
  game itself, which stays until Dominic has played the Lobster one.

## Funny moments

- The pad self-test's new step "passed" by testing three workers for being more than one kind of unit.

## Left

- Dominic's first Lobster match (the exit criterion) and the Deck play-test.
- Steam Input's layout; Godot's saves can't load in Lobster.
