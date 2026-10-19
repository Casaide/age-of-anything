# 2026-10-19: Website drafts 3 and 4

**Milestone:** none (business planning; follows `2026-10-18-website-and-money.md`)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic on draft 2: it can't go out with a Steam wishlist button (there's no Steam page yet), and "It knows some
words" is "super weak": less talk about the words, more showing them. He asked for an agent to review the text against
other games' pages. The review (a dozen admired indie pages) said: one plain hero line, the shortest pages win, show
specific examples instead of claims, one action before launch, and cut every line that restates what's shown.

Draft 3 makes the prompt the hero: it types "rats riding bears" and the Bramblefolk army appears on a strip of grass,
worker to hero (Nibbles Rootfoot). Each army is the game's own bake, drawn by the sheet tool from a spec per prompt
and sliced into a strip. "So far" is a row of one spearman per creature with one-word labels. The Steam button is
gone; the one action is the mailing list. The writing rules in `docs/business.md` §5 grew with the review's points.

## Decisions
None new; the open questions in `docs/business.md` §7 stand.

## Pictures
- `01-website-draft3-rats-riding-bears.jpg`: the hero, the prompt typed and its army.
- `02-website-draft3-dragons.jpg`: "dragons": the game doesn't know it, and the bears volunteer.

## Funny moments
The sheet tool's placement check said "no rule ran" on every row of a one-facing spec (it ran fine with nocheck);
not looked into, since these units are already in the game.

## Ideas parked
- A short looping clip of the town for "Three minutes in".

## Later the same day: draft 4
Dominic: the line "You type who your people are." is "super dull and obvious"; the "dragons" example is "quite
terrible", because showing something that doesn't work is "super basic marketing" gone wrong. "Not finished" should
just be a link to a devlog of progress, and "three minutes in" made no sense when there are pictures of whole built
towns: "JUST SHOW A PICTURE". Above all, the page was "extremely lazy": so focused on short sharp sentences it told
nobody anything about the game. He asked for text on one side, a picture on the other, reversing each row, each about
what makes the game special.

Draft 4 does that: the rat town at twenty minutes behind the title, a headline ("Describe a people. Then lead them to
war.") and a paragraph on what the game is; then rows for the generator (with the prompt box), towns by race, fair
pricing, walls and sieges, and the peoples so far; then the devlog and the email side by side. Every claim was checked
against the game (chimneys smoke, the frogs' Snail Catapult and Snapper ram, six building styles with their own
wonders). The headline is still Claude's pick; Dominic hasn't chosen one.

Pictures: `03-website-draft4-hero-rat-town.jpg`, `04-website-draft4-your-words-your-army.jpg`.

## Draft 5
Dominic set the sections: generate your army, build your city, mount the walls, led by heroes, play with friends (LAN
for now), every game something new, Steam Deck and controller support; "silly, but fair" becomes "automatically
balanced"; the peoples need their cultures shown too. The intro became his line: "Generate your army from a growing
collection of cultures and peoples." He also found the head-on close-ups poor: you couldn't see a viking frog's shield
or the snails. Claude re-rendered every unit in facing 4 (three-quarter, turned left) at a smaller scale, armies now
include their war beast and catapult, trimmed to each unit's width; a soldier for each of the twelve cultures; the six
heroes with their names. Pictures for the new rows: the 2v2 lobby, the battlefield cards, the pad's build ring, a castle
town from a network match. He asked whether there's a game icon or logo yet: there isn't (Godot's default icon).

## Draft 6
Dominic: the ford battle isn't our best; the walls picture was a wall-test fixture showing bugs; the culture soldiers
in facing 4 hold shields with no hand on them (a bug at that angle); "Automatically balanced" should end with ticks and
real numbers from the balance tests; and the page should say honestly that it's made with love by one man and his AI,
the game he wanted as a child. Claude added a `showcase:<tick>` scene to `tests/sim_screenshot.gd` (both sides in age
3, big mixed armies with war beasts and heroes, the UI hidden) and took the battle from it: centaur Romans against
viking frogs, a fallen elephant, newts, the war heron. The walls came from the real `ai-walkway` scene, cropped clear
of a doubled corner-tower roof. Every unit picture went to facing 0, where the shield hand shows. The checklist's
numbers: 46,661 checks in run_tests, the equal-cost round robin, mass battles both ways, counters winning about four
in five, race matches, 174 race keys. The facing-4 shield grip is left for its own session.

## Variety in numbers
Dominic asked whether "174 races" meant only 174 combinations. It doesn't: that's the number of prompts the
key-stability check re-generates after a price change. Claude measured the real variety instead: every creature word
with every culture word (108 prompts) at 20 rerolls gave 2,160 races, of which 2,159 were different armies by their units'
recipes (names left out), with 15,902 different units and 2,000 different heroes. Those numbers, and the kit's size
(290 parts, 332 words, 12 cultures, 6 mounts), went into ticks under "Generate your army"; the 174 tick left the balance list.

## The last tweaks of the day
"Made by one guy and his AI" came down to Dominic's own two lines ("First prototype in 24 hours went from ideas to
gameplay, and hasn't stopped growing since"), beside the very first Race Lab picture from 2026-10-10 (frogs with reed
spears against rats with cheese hammers, in flat shapes). The email sign-up went: the site sends people to the Discord
instead (invite link still to be made).

## The real site
Dominic: "build it here now" in `~/Dev/casaide/age-of-anything-website` (a fresh SvelteKit 3 project for Cloudflare,
with mdsvex and enhanced-img already in), with full testing of mobile and desktop, the blog in markdown, and his web
playbook (github.com/Drache93/web-playbook) for SEO and accessibility. Claude built the home page from the approved
draft, a devlog with a day-one post from this archive, the Seo component, sitemap, robots, a branded 404, security
headers and a CSP, and the playbook's tests: axe WCAG 2.2 AA at 1280 and 390px, "nothing cut off" at 320 to 1280px,
an SEO crawl of the sitemap, plus the army box, images and the devlog. Dominic said yes to installing
@axe-core/playwright and to a WOFF2 of the game's Cinzel.

Things that bit: the enhanced-image plugin reads the raw `.md` before mdsvex, so markdown pictures are rewritten into
`<figure><enhanced:img>` blocks by a small Vite plugin that runs first (inline, mdsvex made their quotes curly);
`wrangler types` imports the built worker, which dragged compiled JS into `npm run check` (checkJs off); the strips that
scroll sideways on a phone needed keyboard focus (axe); hero names wrapped onto a third line that was clipped (a test
now catches it); and one e2e run passed against a stale preview server, so Playwright now always builds fresh.
Next: pulling the archive into daily devlog posts.

## The icon
After many rounds (in `docs/concepts/icon/`), Dominic picked N4, the parts kit, and asked whether its navy should
match the site. Recoloured three ways in the site's own colours, he chose ink on gold (D-164). It's now the website's
favicon set (with an e2e check that every icon is served) and a 1024 px Discord server icon.

## The Discord server
Dominic made the server and the invite (https://discord.gg/TvNmm7pEd, now on the site). Claude wrote the setup in
`docs/community/discord.md` (description, rules, channels, topics, forum tags, roles, onboarding, welcome screen,
AutoMod), then, at Dominic's "cant you do it directly?", set it up in his Chrome: Community on, channels in four
categories with the read-only ones checked, roles in the creature colours, onboarding with the "which people would you
lead?" question, AutoMod blocking invite links, topics, and the three forums with their post guidelines and tags (the
"fixed", "can't reproduce", "planned" and "added" tags are for moderators only). At Dominic's yes, Claude posted the rules in
#rules and the welcome message in #welcome (pasted in one go, with real channel links, after typed "#"s kept opening
the channel picker); the website line was left out until the domain is bought. Lessons from driving Discord: check the field has focus before
typing (a "#" opens the channel picker and eats words, Escape closes the whole dialog, and one stray keypress navigated
away and lost an unsaved AutoMod rule). Then the stickers and emoji went in: eight emoji (:frogcrest: :vikingfrog: :ratbear: :bear: :spider: :centaur:
:quill: :oddhelm:) and the five free sticker slots (Viking frog, Rat on a bear, Odd helm, Spider, Frog crest), each with
a short description for screen readers.
