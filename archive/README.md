# The Archive

A record of how Age of Anything grows: pictures, decisions, changes of direction, funny bugs,
and the ideas that didn't make it. Two reasons:

1. **For future AI sessions (and future us):** *why* things are the way they are. Code shows what;
   the archive shows how we got here and what we tried.
2. **For fun:** scroll back and watch frogs with sticks turn into a game.

**It is append-only history.** Don't rewrite old entries. If something changes, write a new
entry that says so and link back.

## Layout

```
archive/
  README.md          this file
  decisions.md       numbered decision log (D-001, D-002...), newest at the bottom
  timeline.md        one line per milestone/moment, for a quick scroll
  journal/
    YYYY-MM-DD-short-title.md   one entry per session or milestone
  images/
    YYYY-MM-DD/
      NN-short-description.png  screenshots, bugs, mockups, sketches
```

## Journal entry template

```markdown
# YYYY-MM-DD: Short title

**Milestone:** e.g. 0 (race generation)
**Who:** Dominic + Claude (Claude Code / claude.ai)

## What happened
Short narrative of the session.

## Decisions
- D-0NN: one line (full entry in decisions.md)

## Direction changes
What we thought before -> what we think now, and why.

## Pictures
![caption](../images/YYYY-MM-DD/NN-name.png)

## Funny moments and bugs worth remembering
- ...

## Ideas parked
- ... (also add to docs/backlog.md if worth keeping)
```

## Pictures

- Take screenshots with
  `godot --path . --script res://tests/screenshot.gd -- archive/images/<date>/NN-name.png "prompt A" "prompt B"`,
  or drop in your own.
- Name them `NN-short-description.png`, numbered in order within the day.
- Keep bug screenshots. They're the best part.
- Keep images reasonably small (PNG of a game window is fine; no videos in git for now).
