# 2026-10-20: the website on a phone

## What happened
Dominic went through the test site on a phone and a 14-inch Mac and asked whether we were missing a review or a lint
for mobile. We were: the playbook's check only catches things cut off or scrolling sideways, not a layout that reads
wrong. What he caught, all fixed on the test site:
- The army box blanked between races (the name vanished, the picture went to plain grass) and changed height as the
  name wrapped: "terrible". Now every army and name sits stacked in one place and fades into the next, the old one
  staying up while the next prompt types itself in; the prompt line is held at the longest prompt's height; the Pause
  button keeps its place once gone.
- On phones each row showed its picture above its heading; now heading, text, then the picture.
- "Follow development" sat left on a phone; it now spans the column, centred, the line under it centred too.
- The ticks sat high against their text; the mark is now centred on the item's first line.
- Mods: after a separate panel, "same section fine, just needs more focus, like the ticks but a different icon". In
  "Every game something new": his paragraph as a pull quote, then "Mods can add today" (+) and "Still to come" (a
  hollow circle): the lobby's mod list, mod buildings, research, sounds and new bodies, the Steam Workshop, and the
  tools we mod with released for players.

## Decisions
- `e2e/mobile.e2e.ts` in the website: at 320, 390 and 430 px every row reads heading before picture, the hero's
  button spans the column and is at least 44 px tall; at 320, 390 and 1280 px the army box keeps its height through a
  whole cycle and always shows one army and one name. Each rule is one Dominic caught by eye.

## Ideas parked
- The playbook's `mobile.md` could take these rules (reading order, no layout shift, centred primary action) so the
  next site starts with them.

## Later: the devlog filled in
Dominic: fill in the rest of the posts, one per day, "very clean and friendly and human. My voice". Claude read all 38
journal entries and wrote one post a day from 10-11 to 10-19, in Dominic's first person, with the funny bugs kept in
(the bulldozer frogs, "the hairline was a hat", legionaries at attention on a dead elephant, "starts really fast"),
and rewrote day one in the same voice with the evening's simulation added. Pictures were picked from the archive and
looked at one by one; red and white spiders were captured fresh (01). Today's post waits for the day to end. The
whole post card is a link now (one link per card, stretched over it), covers share one frame, and a post title too
long for "| Age of Anything" stands on its own.

## Later: the rest of the SEO list
Dominic: "lets finish the still to build now then". The devlog got an RSS feed, tags with a page each, related posts
and links between days, breadcrumbs and an updated date in its structured data, and today's post (frog falls and the
site on a phone). The security policy now lets Cloudflare Web Analytics' beacon in, for when it's switched on for the
domain. The website became a git repo (first commit, local) with the playbook's CI and Lighthouse budgets. Lighthouse
found a bug in the playbook's template: its "perf" preset runs only the performance category, so the accessibility,
SEO and best-practice budgets could never pass. Without it: 100 on all three, performance 0.97-0.99, the largest paint
at 2.0-2.3 s on a simulated phone, so this site's budget is 2.5 s for now. Inlining the stylesheets to win that back
made it worse and came out again.
