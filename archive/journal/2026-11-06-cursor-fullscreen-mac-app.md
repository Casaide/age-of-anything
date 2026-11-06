# 2026-11-06: The OS's cursor, fullscreen, and a Mac app

## What happened
Dominic found the drawn cursor from #116 getting in the way: the Mac's cursor gone, screenshots awkward, more bugs. He asked what's normal for games, and said windowed play isn't. So three changes, in a stack:

- **#222:** the OS draws the cursor. The fork got `gl.cursor_image`, `gl.cursor_set`, `gl.cursor_set_default` and `gl.cursor_visible`, and the virtual cursor is deleted.
- **#223:** the game starts in desktop fullscreen, with `windowed`, a Settings row and Cmd/Alt+Enter. No fork change: `gl.fullscreen` was already there.
- **#224:** `tools/mac/make_app.sh` builds a bundle marked as a game, and `play.sh` runs through it. macOS now reports "Age of Anything" and its bundle id.

## Decisions
D-222, D-223, D-224.

## Direction changes
Claude's session had no Screen Recording or Accessibility permission, and Dominic left it that way. He chose to merge first and test after. So nobody has yet seen the cursor over a match, pressed Cmd+Enter or seen the Game Mode icon. The game's captures can't see an OS cursor. A composite picture made early on was dropped from the branch: it looked like proof and wasn't.

## Pictures
`archive/images/2026-11-06/`: 90 (the cursors), 92 to 95 (setup page and match, fullscreen and after switching).

## Funny moments
`lint.sh --fix`, running in the background, wrote back a file it had read earlier and quietly ate a fresh edit. The edit was only noticed when reading the PR's diff. Also, `log` in zsh is a builtin, so a whole round of "Game Mode logs are empty" was zsh complaining.

## Ideas parked
- If the camera keeps scrolling when the mouse leaves a window slowly, a fork builtin for SDL's mouse focus fixes it. Not added until it's proven needed.
- `gamepolicyd`'s one decision line reads "Ignoring <private>", so logs can't answer whether Game Mode is on. The menu bar icon does.
