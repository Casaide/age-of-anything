# 2026-10-18: A website, and how the game earns

**Milestone:** none (business planning)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic: "we need to design a website, and plan how we start monetising". Claude read the pitch, the market notes, the
platform plan and the non-goals, and wrote `docs/business.md`: a premium game on Steam (demo, Next Fest, Early Access,
1.0), a supporter edition, paid era packs later with "the host owns it" so lobbies never split, and never pay-to-win.
Valve's 2027 calendar puts Next Fest on Feb 22 and Jun 14; June looks realistic, February a stretch.

The website's one job is wishlists. A first draft of the home page (`docs/concepts/website/home.html`) uses the game's
timber-and-bronze look, real screenshots with the debug text cropped off, and a "race forge" strip: pick a prompt,
see a unit it makes (pre-rendered; a real in-browser forge needs a web-export spike first).

## Second draft
Dominic: the draft "reads very very heavily as AI slop"; the wording needs care, reciting the features one by one sounds
terrible, and the site must admit you can't play anything you describe, only what's in a growing kit. Claude rewrote it:
plain sentences, no feature grid or slogans, a line on what's in the box today, and the generator's real output for
each prompt (race name, notes, hero) in place of invented jokes. "dragons" is one of the prompts: the game answers "No
idea what 'dragons' means, so we ignored it." and the bears volunteer. A real bug (an elephant's crew standing on air
after it fell) is the devlog teaser. The writing rules went into `docs/business.md` §5.

## Decisions
None yet: seven open questions for Dominic at the end of `docs/business.md`. Claude's strongest advice: the trademark
check and the final name come before the Steam page or a domain (D-115 left it open).

## Pictures
- `05-website-concept-hero.jpg`: the hero, the Norse and Romans at the ford behind the title.
- `06-website-concept-race-forge.jpg`: "viking frogs" typed, the Broad Axeman Frog shown (first draft).
- `07-website-draft2-dragons-unknown.jpg`: the second draft, "dragons" typed and the game saying it has no idea.

## Funny moments
The first draft's made-up unit jokes ("The cheese is load-bearing.") went in the second; the game's own notes are funnier.

## Ideas parked
- Race Forge as a Godot web export of the Race Lab, with a shareable race key link.
- A clean capture mode (no debug lines) for trailer and store shots.
