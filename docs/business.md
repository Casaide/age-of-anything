# Business: making money, and the website

How the game starts earning, and the website that leads people to it. A plan for Dominic to decide on, written
2026-10-18 by Claude. Nothing here is decided yet: the open questions are at the end. Market background is in
`market-context.md`; the non-goals in `design.md` §12 (no live-service monetisation, no battle passes) hold.

## 1. The model in one line

**A premium game, bought once, on Steam. Free demo, then Early Access, then 1.0. Paid era packs later. Never pay to win.**

Why this model:
- It's what the genre's players expect and like. Battle passes and loot boxes are what they're tired of
  (`market-context.md`), and our design already rules them out.
- "Cost is the balancer" is the game's promise. Selling power would break it, so nothing we sell changes stats in a way
  only buyers get.
- P2P lockstep means almost no server bill. A one-time price can keep the game playable for years, with no running
  costs that would push us towards a subscription.
- Discovery is the bottleneck, not price. A demo and wishlists do more than any monetisation trick.

## 2. Where the money comes from, in order

| # | Stream | When | Notes |
|---|---|---|---|
| 0 | **Wishlists** (no money, but they decide everything else) | from the day the Steam page goes up | Steam ranks launches by wishlists; this is the number to watch |
| 1 | **The base game** on Steam (Early Access) | after a Next Fest | suggested $14.99-19.99, rising at 1.0; Steam's regional prices; a 10-15% launch discount |
| 2 | **Supporter edition** (DLC bundle) | at Early Access | the soundtrack (we already render it: `src/audio/`), a digital art book from the concept sheets in `docs/concepts/`, name in the credits. Cheap to make, and it's what fans buy to say thanks |
| 3 | **Era packs** (paid DLC) | after 1.0 | gunpowder first, then steampunk, then sci-fi: they're already the plan (`CLAUDE.md` "Later", backlog). New parts, words, buildings, a theme. Priced ~$5-10 |
| 4 | **Free updates** (not money, but they sell the game again) | throughout Early Access | new creatures (the bears, beavers), maps, modes; each update is a reason to post and a news hit |
| 5 | Maybe: Ko-fi or Patreon for the devlog | any time | small, but it builds the core group early; only if Dominic wants to write for it |

Not doing: battle passes, loot boxes, paid currencies, ads, paid stat boosts, paid hero or race unlocks, a
subscription. Mods, the Workshop and race sharing stay free (they're how classic RTS games lived for decades).

### Era packs and multiplayer (needs a decision)

Lockstep needs every machine to have the same data. So every install ships every pack's data; owning a pack decides
whether **you can pick its races and words in a lobby you host or in your own race**. A friend without the pack can
still join and play against your musketeer frogs. This "the host owns it" rule keeps lobbies from splitting, and it
advertises the pack to everyone who plays against it. Cost to build: a check on Steam ownership in the lobby and the race
generator's era gate (which already exists: `rules.era`). Nothing in the sim changes.

## 3. Timeline

Today is 2026-10-18. The dates that matter (Valve's published 2027 calendar):

| Date | What |
|---|---|
| **now** | name check (below), company and bank details for Steamworks, $100 Steam Direct fee |
| **Nov 2026** | website up (one page), mailing list, Discord; **Steam page "Coming soon"** with a trailer and screenshots |
| Dec 2026 - Jan 2027 | the demo build: Frogs vs Rats, Reed Meadow, the race prompt with a limit (a fixed list of creatures, two ages), vs the bot; the export and Linux checks from the backlog |
| Feb 22 - Mar 1 2027 | **Next Fest (February)**, a stretch: the press preview is Feb 11, so the demo must be solid by then |
| Jun 14-21 2027 | **Next Fest (June)**, the realistic one: the press preview is June 3. Right before the Summer Sale (Jun 24) |
| summer/autumn 2027 | **Early Access** launch, once wishlists are healthy (the usual target is 7,000-10,000 before launch for a visible start) |
| ~12-18 months after | 1.0, then the first era pack |

The order matters more than the dates: **name, Steam page, website, demo, Next Fest, Early Access.** The Steam page
should be up as long as possible before Next Fest, because it collects wishlists the whole time.

An itch.io build (already in the backlog) is good for the early testers (`docs/playtest.md`), not as a store.

## 4. Before anything goes public

1. **The name.** "Age of Anything" is a working title (D-115) and a trademark check is still due. An "Age of …" name
   sits close to a well-known name in this very genre; that's a real risk of a takedown or a forced rename after the
   page has collected wishlists. **Claude's advice: do the check now, and pick the final name before the Steam page or
   the domain.** A rename after launch loses search history and press links. If the check is clear, keep it; if not,
   now is the cheapest moment. (Candidates from D-010: Ragtag, Kitbash, Bodge.)
2. **The domain** and social handles for the final name.
3. **A company** (or sole-trader setup) to sign the Steamworks agreement and take payments; tax forms in Steamworks.
4. **Licences:** Cinzel is OFL (fine to ship and to use on the site, credited); Godot is MIT (credit it). Check every
   asset in `assets/` has a known source.
5. **Steam's AI disclosure.** The art, models, textures and sounds were made with Claude, by code (models, SVG, the
   synth), so that's "pre-generated content" and gets disclosed in Steam's content survey. The race generator itself is
   not a generative model: it's a deterministic parts kit, nothing is generated by AI while you play. That's the honest
   message and a good one ("your race is built from a kit, the same on every machine"). We don't claim "no AI".
6. **Originality** (`CLAUDE.md`): the site, trailer and store text never name other games, and nothing looks like
   another game's art or logo.

## 5. The website

### What it's for

Until the Steam page exists (the name comes first, §4), the site sends people to **the Discord** (Dominic,
2026-10-19: no email sign-up; the invite link is still to be made). No wishlist button until there's a store page to point at; then the Steam button joins the sign-up.
Later it's also where press find the press kit and modders find the docs.

### Pages

Start with one page, grow later:

| Page | When | What |
|---|---|---|
| **Home** | at once | everything below, one scroll |
| Press kit | not needed for now (Dominic, 2026-10-19); with the Steam page at the earliest | fact sheet, logo, screenshots, the trailer, a short and a long description, contact |
| **News / devlog** | with the Steam page | update notes, the funny bugs from the archive (they're great posts) |
| **Modding** | at Early Access | `docs/modding.md` made into pages |
| **Race Forge** | later (a spike first) | type any prompt in the browser and see your race (see below) |
| Privacy | not needed for now: the site collects nothing (Dominic, 2026-10-19) | short: what the newsletter keeps; the game's analytics are opt-in (`mvp-plan.md` §10) |

### The home page (draft 6, 2026-10-19), top to bottom

Dominic's sections, in his order, each a row of text beside a picture (sides swap row by row):

1. **Hero:** the rat town at twenty minutes behind the name, "Describe a people. Then lead them to war.", and "A
   real-time strategy game in the classic mould: gather, build, advance through the ages and fight. Generate your army
   from a growing collection of cultures and peoples." (Dominic's line). "Follow development"; the platforms.
2. **Generate your army:** the kit, the race's name, lines, bonuses and hero; the prompt box types a prompt and shows
   the whole army, worker to war beast, catapult and hero. Ticks with the kit's size and its variety, measured
   2026-10-19: 290 parts (71 weapons and tools, 55 helmets and hats, 22 shields, 43 engines and beasts); 7 peoples (three
   kinds of bear) in 12 cultures with 6 mounts; 332 words; every creature with every culture at 20 rerolls gave 2,160
   races, 2,159 different armies (by their units' recipes, names left out), 15,902 different units, 2,000 different
   heroes. (The "174 races" in the milestone notes is only how many prompts the key-stability check re-generates.)
3. **Automatically balanced:** pricing by parts and counters, ending in a ticked list of the real balance tests and
   their numbers (46,661 checks on every change; every soldier line against every other at equal cost; mass battles
   both ways round; counters win about four in five; bot-vs-bot race matches).
   The picture: a staged age-3 clash, centaur Romans against viking frogs (`tests/sim_screenshot.gd` scene
   `showcase:590`, cropped to the fight).
4. **Build your city:** six building styles; the castle town and the frog town.
5. **Mount the walls:** walkable walls, gatehouses, siege engines crewed by their people; a walled Roman town with
   archers on the walkway (scene `ai-walkway`, cropped clear of the tip box and a doubled corner-tower roof).
6. **Led by heroes:** one named hero a race, auras, revival; six heroes with their names.
7. **Seven peoples, twelve cultures:** a soldier of each culture, labelled, and one of each creature.
8. **Play with friends:** home-network play, 1v1 or 2v2 with bots in empty seats, saves; "online play is next"; the lobby.
9. **Every game something new:** the dice, the battlefields, siege maps, the bots' three strengths, and mods (plain
   data: gear, creatures, cultures, words, an era; priced by the same rules); the map cards.
10. **Steam Deck and controllers:** the ring of orders on A, reticle and circle, mouse and pad mixed; the build ring.
11. **Made by one guy and his AI:** one guy working with Claude, the game he wanted as a child (Dominic's ask).
12. **Follow:** the devlog and the Discord (invite TBD).

**Unit pictures** are rendered by the sheet tool in facing 0 (three-quarter, turned right: the shield hand shows there;
head-on hid the gear, and facing 4 showed shields with no hand gripping them), one spec per prompt with slots worker, spear, archer, infantry, large,
war_beast, catapult, hero at age 3, blank labels, `nocheck`; each unit is trimmed to its own width and packed into a
strip, so a snail catapult and a frog sit side by side without empty grass. Names come from `tests/print_races.gd`.
Re-render when the art changes.

### How it's written (Dominic, 2026-10-18: the first draft "reads very very heavily as AI slop")

- **No feature lists.** Reciting what the game does reads as a brochure. Say less, show the game.
- **Honest about scope, never showing failure** (Dominic, 2026-10-19: showing something that doesn't work is "super
  basic marketing" gone wrong). Say plainly what's in the box ("So far": one of each creature) and that it grows; never
  show a prompt the game can't do, a fallback note, or a bug. Bugs belong in the devlog, not on the home page.
- **Let the game talk.** Its own notes, race names and hero names are better copy than anything written about it, and
  they're true. No invented jokes or flavour lines. Only notes that land as jokes; none that show a limit or read like debug text.
- **Show, don't describe the input** (2026-10-19). Don't talk about "words"; type a prompt and show its army. Headings
  short and concrete ("So far", "Three minutes in"), never apologetic or abstract (Dominic: "It knows some words" is
  "super weak").
- **Plain sentences, but say something** (Dominic, 2026-10-19: draft 3 was "extremely lazy", "so focused on short
  sharp sentences you aren't telling anyone anything about the game"). Each section explains one thing that makes the
  game special, in a full paragraph or two, beside a picture that shows it. No slogans, no "not just X but Y".
- **Show the best pictures, don't caption time.** Whole built towns, walls, battles; never "three minutes in" when a
  twenty-minute town exists.
- **Show the strange units at their best:** three-quarter views, not head-on close-ups; war beasts and engines in the
  armies (the snail catapult, the war heron).
- **Point to progress, don't confess it.** A devlog link, not a "Not finished" section.
- From a review of a dozen admired indie game pages (2026-10-19): the best hero lines are one plain sentence, genre plus
  one concrete hook; the most admired pages are the shortest, and some sell by admitting limits; "make anything" hooks
  work through specific examples, not claims; personality comes from one specific aside; images outnumber paragraphs;
  pre-release sites ask for one thing. Words to avoid: unleash, dive in, embark, journey, craft, forge, endless,
  limitless, unique, seamless, immersive, epic, "your imagination is the only limit", "welcome to". Structures to
  avoid: "not just X, it's Y", "whether you're A or B", a rhetorical opening question, exclamation marks, every section
  the same shape, restating a feature right after showing it.
- The name "Age of Anything" promises more than the box holds today. That's one more thing to weigh in the name check.

### The look

The site should feel like the game's menus: the approved **timber and bronze** UI look (`data/ui.json`, approved in milestone 19):
dark wood, bronze frames, gold titles in Cinzel, the culture crests (`assets/art/ui/crest_*.svg`) as section marks.
Real screenshots only, no mock art. The draft home page is `docs/concepts/website/home.html` (`.claude/launch.json` serves it: "site-concept").

### How it's built (2026-10-19)

Built in `~/Dev/casaide/age-of-anything-website` (not a git repo yet): SvelteKit 3 on a Cloudflare Worker, every page
prerendered, to Dominic's [web playbook](https://github.com/Drache93/web-playbook) (SEO, WCAG 2.2 AA, nothing cut off
from 320px, security headers). The game's Cinzel is self-hosted as a Latin WOFF2; screenshots go through
`@sveltejs/enhanced-img`; the devlog is markdown (mdsvex), one folder per post, pictures beside it. Its README has the
commands, the tests (49 end to end at five widths and two viewports, 24 unit) and what's still a placeholder (the
domain, the Discord invite, the icon). The draft in `docs/concepts/website/` stays as the record of how the page was
reached.

### Race Forge (later)

The generator is plain GDScript and deterministic, so a Godot web export could run it in the browser: type a prompt,
see the race card, share a link with the race key, "Wishlist to play it". It's the best possible ad for this game, but
the bake pipeline (3D SubViewports) may be too heavy for the web. Step one is a spike: export the Race Lab for the web
and measure it. Until then, the home page uses pre-rendered lineups of picked prompts.

## 6. What to measure

- Wishlists a week (Steamworks), and where they came from (UTM links on the site's Steam buttons).
- The newsletter list size; Discord joins.
- In the demo (opt-in): matches finished, prompts typed, unmatched words (the generator's to-do list).
- Demo-to-wishlist rate during Next Fest.

## 7. Open questions for Dominic

1. The name: run the trademark check now and pick the final name before anything public?
2. Price: $14.99 or $19.99 for Early Access?
3. Era packs as paid DLC with "the host owns it", or free updates paid for by the base price?
4. Which Next Fest: February (stretch) or June (realistic)?
5. A Supporter edition at Early Access: yes or no?
6. A devlog with Ko-fi or Patreon: worth the writing time?
7. The site's look: the timber draft, or try a second direction (parchment) first?
