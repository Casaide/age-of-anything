# 2026-10-30: the icon and the boot screen

## What happened
- Dominic picked the parts-kit icon for the Discord server (a frog, a horned helm, a shield and a sword on a sprue,
  ink on yellow) and wanted it as the game's icon. It moved to `assets/art/ui/game_icon.svg`; `src/icons_game.py`
  (run by `icons.sh`) rasterises it for the game: the tile, and its ink alone in white with the yellow cut out, to tint.
- Android: `src/android/icon.py` makes an adaptive icon from it now (yellow background, the ink foreground at 52 of
  108 dp so the frame's corners stay inside the circle every launcher keeps), the old square PNGs for older launchers,
  and the Android 12 splash shows it in its yellow circle on the dark brown the game starts on.
- The Mac: Lobster had no way to set a window icon. Dominic said to add one to his fork: `gl.window_icon(file)`
  (dev/src/graphics.cpp, sdlsystem.cpp: SDL_SetWindowIcon, which on macOS is the Dock's icon). Left uncommitted in the fork.
- The Deck: the build ships `icon.png`, and `tools/deck/pull_lobster.sh` writes a desktop launcher with it, so "Add
  to Steam" from Desktop mode carries the icon.
- The boot screen was the name and "Loading the sounds..." in plain text. Three concepts, drawn with nothing baked
  (the UI's painted wood, the icon textures, the title face): A the yellow tile on the wood, B a yellow card, C the
  ink as gold inlay. Dominic picked C. A bar fills over the start's four steps. `page:boot shot:<png>` captures it.

## Decisions
- D-187: the parts kit is the game's icon everywhere; the boot screen is the gold inlay (Dominic).

## Pictures
- `archive/images/2026-10-30/01-03`: the three boot concepts; `04`: the boot screen as built; `05`: the Android
  icon under a launcher's circle mask; `06`: on the emulator (the phone wasn't plugged in): the app drawer,
  the Android 12 splash, the boot screen.

## Funny moments
- The first adaptive icon cut the frame's corners off: the sprue fitted the 108 dp layer, not the 72 dp a phone shows.

## Ideas parked
- The Android build's maps patch had gone stale (`scan_folder` now returns names only in game.lobster); fixed in
  `src/android/build.sh` on the way.
