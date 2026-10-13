# Video 1: "I vibe coded an RTS in 24 hours, and you'll love it"

The first video on the channel. Its job: make people want the game (wishlists or a Discord join later),
and show off the hook in the first 10 seconds: **type any civ, get an army, play a real RTS with it.**

Target: 10-12 minutes. Landscape 16:9, plus 3-4 Shorts cut from it.

## Is "24 hours" true? (check before publishing)

From the git log and the archive:

| Clock | Time | What existed |
|---|---|---|
| 0h | 10-10 23:22 | First commit: the Race Lab ("centaur romans" makes an army) |
| ~15h | 10-11 13:38-14:00 | AI opponent, match setup, fog of war, minimap, sounds: a playable match |
| ~17.5h | 10-11 16:55 | Dominic's first proper match. **The AI beat him.** |
| 24h | 10-11 23:22 | Per-line upgrades, age-2 buildings, worker-thread pathing |
| ~72h | today | Siege, walls, three ages, the timber UI, audio, living towns: 380 commits, 640 pictures |

So the title is honest **if the video is the first 24 hours**. Days 2-3 go in a closing "and then I
couldn't stop" montage (or become video 2). Don't show day-2/3 footage as if it were hour 20.

The design chat before the first commit counts too; start the clock at the first message if you want
to be strict, and say "about 24 hours".

## The arc

The story is not "AI wrote my game". It's **a person with taste directing a very fast builder**:
Dominic picks, rejects and plays; Claude builds. The best beats are the ones where Dominic says no.

| Time | Section | Beat |
|---|---|---|
| 0:00 | **Cold open** | A dozen armies in 20 seconds: the lobby dice thrown again and again, a new army each time, ending on "ww2 americans on mongolian ponies" and its saucepan note (Dominic). No intro, no logo. Voice: "24 hours ago this didn't exist." |
| 0:20 | **The pitch** | "Every RTS gives you 8 civs. This one gives you any civ you can describe." Rapid prompt montage: centaur romans, flying greeks, frogs, beetles, spiders. |
| 0:50 | **The rules of the challenge** | 24 hours on the clock, Godot, Claude Code. "I don't write the code. I make the calls." Show the clock overlay that stays on screen for the whole video. |
| 1:20 | **Hour 0: the idea** | It started as a chat about the games industry. The pivot from "runtime AI makes races" to a parts kit + word lookup, so it's deterministic and fair. First render of frogs vs rats (`archive/images/2026-10-10/01`). |
| 2:30 | **The first great bug** | A giant Roman with a cheese hammer (`2026-10-10/03`). Explain the fix in one line: big units are mounts, giants only where it reads well. |
| 3:15 | **Not all vibes: the checks** | Determinism from minute 20, a lint that bans floats and randomness in the sim, 11,674 checks at hour 24 and 28,642 today, the balance round robin, 440 screenshots looked at, 124 decisions (Dominic: prove it isn't all vibes). Numbers in the talking points. |
| 4:00 | **Hours 6-10: map, workers, economy** | Isometric view first render (`2026-10-11/01`), frogs gathering bugs and cutting reeds, rats out-breeding everyone. |
| 5:00 | **Hours 10-13: what should it look like?** | The style sampler, five looks in one scene (`2026-10-11/08`). Dominic: "You're testing rendering, not art direction." The sixth style wins. This is the best "human taste" moment; give it room. |
| 6:30 | **Bug reel** | 6-8 bugs, 3 s each, with a caption: frog on the roof, legless spiders on ponies, pegasus wing from the rump, ghost army, dead units as slivers, golf flags. Music sting per bug. |
| 7:15 | **Hours 13-15: war** | Combat, counters (spear > cavalry > archers > infantry), the AI that builds and attacks in waves, fog of war. |
| 8:15 | **Hour 17.5: the AI beat me** | Told, not replayed: Dominic tells the story of the first real match over hour-15 footage, facecam on. Playing the AI on camera waits for a later video. |
| 9:30 | **Hour 24: the clock stops** | Freeze on the 24h build. Honest scorecard: what works, what's ugly, what's fake. |
| 10:00 | **"...and then I couldn't stop"** | The line lands over the 24h freeze frame, beat, then the clock unfreezes and spins past 24h, 48h, 72h. 30 s montage of days 2-3: timber UI, siege crews, rams at a stone gate, burning houses, the synth theme. Each clip gets a small "coming: video N" tag, so the montage is the series teaser. |
| 10:45 | **Ask** | "Type a civ in the comments; the top 5 get generated and fight in the next video." That comment prompt is the engagement hook and the next video's content. |

## What we already have (from the archive)

Stills for the timeline sections: `archive/images/2026-10-10/` (6) and the first ~100 of
`2026-10-11/`. Good picks:

- `2026-10-10/01-frogs-vs-rats-first-render.png`, `02-centaur-romans-vs-winged-greeks.png`,
  `03-bug-giant-cheesehammer-roman.png`
- `2026-10-11/01-isometric-frogs-meet-rats.png`, `07-opening-minute-3.png`,
  `08-style-sampler-all.png`, `15-style-hifi-prerendered.png`, `16-pixel-hifi-2x.png`,
  `51-first-battle-frogs-vs-centaur-romans.png`, `101-ai-rats-raid-the-frog-town.png`,
  `102-fog-of-war-edge.png`
- Bugs (`2026-10-11/`): `19-bug-frog-on-the-roof`, `50-bug-dead-units-as-dark-slivers`,
  `64-bug-ghost-army-...`, `78-bug-legless-spiders-sitting-on-ponies`, `87-bug-pegasus-wing-from-the-rump`,
  `113-golf-flags-bug`
- Day 2-3 montage: `2026-10-12/240-lobby-dice-tumbling-army-forging`, `401-burning-house...`,
  `212-ui-after-lobby`, `2026-10-13/273-rams-at-a-stone-gate`, `181-rats-storm-the-ramp`,
  `275-frog-siege-in-play-snapper-snail-and-toad`

The journals (`archive/journal/`) and `archive/decisions.md` hold the quotes and reasons; mine them
for narration lines instead of inventing them.

## What we need to record

Stills alone won't carry 10 minutes. Motion we can still get:

1. **Cold open and pitch footage** from today's build: lobby, typing a prompt, dice, army forming, a
   fight. Fine to use the current build here as long as the narration says "this is where it is now".
2. **Hour-accurate footage**: check out the commit at each beat and screen-record it running
   (`git worktree add /tmp/h15 <sha>` so this checkout isn't touched). Key commits:
   - first commit `10-10 23:22` (Race Lab)
   - economy (10-11 morning), first battle, `Milestone 8 built` (10-11 13:38), `Milestone 9 done` (14:00)
   - the last commit before 10-11 23:22 (the 24h freeze frame)
3. **The playtest**: if the first loss wasn't recorded, replay it. The sim has replays
   (F5/F9 in `sim_debug`) but they're tied to the build that made them, and the first match may not
   have been saved. Otherwise re-play against the hour-17 build and say so.
4. **Determinism visual**: two windows side by side, same replay, hash printed. `tests/test_sim.gd`
   prints the numbers; a quick overlay script could show them.
5. **Facecam / voice**: Dominic's reactions, especially the art-direction call and the loss.
6. **Claude Code screen captures**: a few real prompts and the agent working, sped up 10-20x.
   Blur paths and the email address.

The `app-demo` skill can capture and caption app footage, but the voice should be Dominic's.

## Thumbnail and title

- Thumbnail: a huge "24h" on the left, a cheese-hammer rat mid-swing on the right, a big
  prompt box in the middle reading `sewer rats with cheese hammers`. Our own art only.
- Title options (A/B test two):
  - I vibe coded an RTS in 24 hours, and you'll love it
  - I typed "sewer rats with cheese hammers" and got a whole army
  - I let AI build my dream RTS in 24 hours (it beat me)

## The series

Video 1 is the hook: a complete, playable game in 24 hours. Everything after hour 24 was polish
toward the finished vision, and each piece of it is a classic RTS topic people already search for.
Each follow-on goes deep on one feature, shows the 24h version next to the finished one, and opens with
a viewer-prompted civ from the comments.

| # | Video | What's in it (archive) |
|---|---|---|
| 2 | Your civs fight | Top 5 comment prompts generated and played in a free-for-all. Pure fun, proves the hook |
| 3 | How every unit gets a fair price | Points, cost curves, counters, the balance round robin; "silly is fine, broken is not" |
| 4 | Making the art | Style sampler, concept-first picks, 3D parts baked into 8 facings, the bug gallery |
| 5 | Walls, gates and siege | Diagonal gates, crewed engines, the giant-beetle ram, shots that miss |
| 6 | The AI that beat me | Build orders, counter-picking, attack waves, breaking walls |
| 7 | Sound from nothing | The offline synth, creature voices, the theme growing by age |
| 8 | Living towns and maps | Chores, burning houses, rivers, fords, bridges, worn trails |
| 9 | Lockstep multiplayer | Determinism pays off (once networking exists) |

Video 1's closing montage becomes a teaser for this list rather than a recap.

"...and then I couldn't stop" is said once, in video 1, and never again. Repeating it as a tagline would
turn it into a running excuse for feature creep (Dominic). Follow-ons open on a viewer's civ and the feature itself.

## Rules for the video (from CLAUDE.md, now in public)

- **Never name or show the commercial games that inspired us.** Say "classic RTS" or "the genre".
  No title cards, no "it's like X", no their footage, music, fonts or icons. Tags and description too.
- **The name.** "Age of Anything" is a working title and needs a trademark check before any public
  release; a YouTube video is public. Either do the check first, or keep the name off the thumbnail and
  title and call it "my RTS" until it's cleared.
- No third-party franchises in prompts shown on screen (no famous film or game factions as civs).
- Music: our own theme from `assets/audio/` (Dominic hasn't listened yet; do that first).

## Steps

- [ ] Dominic: decide "first 24 hours" framing vs a different title (see the table above)
- [ ] Dominic: trademark check on the name, or keep it off the video
- [ ] Listen to the theme stems; pick the music bed
- [x] Find the exact commits for each beat; set up worktrees (`video/builds/`, all import and run)
- [x] Stills by beat in `video/01-intro/stills/`; a dozen intro armies rendered
- [x] Talking points: `docs/video/01-intro-talking-points.md`
- [ ] Fix the sim tick-time failure, or say on camera that the tests caught it
- [ ] Record hour-accurate footage per beat
- [ ] Record today's build: cold open, pitch montage, day 2-3 montage
- [ ] The playtest loss: told over hour-15 footage, no replay for now (Dominic)
- [ ] Record the talk-through from the talking points (Dominic, unscripted)
- [ ] Rough cut, then trim to 10-12 minutes
- [ ] Thumbnail, two title variants, description, chapters
- [ ] Cut 3-4 Shorts: the cold open, the bug reel, the art-direction "no", the loss
- [ ] Archive: journal entry, decision for the framing and name, timeline line
