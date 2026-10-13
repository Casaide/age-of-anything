# Video 1: talking points

Notes for Dominic to talk from, not a script. Each beat has the facts, what's on screen, and a line or
two worth saying out loud. Footage for each beat is in `video/01-intro/` (local, not in git): stills
in `stills/<beat>/`, and the old builds to record in `video/builds/`.

Clock: hour 0 is the first commit, 2026-10-10 23:22. Times below are hours after that.

## 0. Cold open: a dozen armies (0:00-0:20)

- On screen: the lobby, dice thrown over and over, a new army every second. Record it live
  (`godot --path .`), typing these or just rolling. Stills backup: `stills/00-intro-armies/`.
- Prompts that read well, checked: sewer rats with cheese hammers · centaur romans · flying greeks
  with wings · angry swamp frogs · viking beetles · spiders riding ponies · aztec frogs · han dynasty
  rats · egyptian centaurs · ww2 americans on mongolian ponies · pegasus knights · steppe spiders
- End on "ww2 americans on mongolian ponies" and read its note out: *"No world wars yet. Issued
  saucepans for helmets."*
- Line: "24 hours ago, none of this existed."

## 1. The pitch (0:20-0:50)

- Every RTS gives you a handful of civs. This one gives you any civ you can describe.
- Silly is fine; broken is not. A ten-foot spider is allowed, it's just expensive.

## 2. The rules (0:50-1:20)

- 24 hours, Godot, Claude Code. "I don't write the code. I make the calls."
- I slept. Two gaps in the commit log, about 01:45-05:00 and 05:30-09:40. The clock kept running.

## 3. Hour 0: the idea (1:20-2:30)

- It started as a chat about the games industry, then: people love classic RTS games and love making
  their own stuff. What if you could make your own civ?
- First idea: AI generates races live. Then the turn: no AI at runtime at all. A parts kit and a word
  list, so the same words give the same army on every machine. That's what makes multiplayer and
  sharing races possible.
- "Bad results are the fun." Type "flying greeks" and the word "greeks" didn't mean people, so
  **the spiders volunteered**. Hellenic spiders with hoplite spears.
- Stills: `01-hour0-idea/`. Footage: `builds/h00-race-lab` (Race Lab, flat 2D shapes).
- Don't name the game that inspired the "parts like loot guns" idea (journal says it; the video can't).

## 4. The first great bug (2:30-3:15)

- Prompt "romans", Bronze Age only: a giant Roman with a cheese hammer. Cheese won on "heavy" and "charge".
- Fix: big units are mounts; giants only where it reads well; everyone else goes Heavy.
- Still: `02-first-bug/`.

## 5. Not all vibes: the checks (3:15-4:00)

The beat that answers "it's just AI slop". Show a terminal running the test suite, numbers scrolling.

- **20 minutes in**, the sim was already deterministic: a scripted 10-minute, 200-unit match replays
  to the identical state hash every time. That's what lockstep multiplayer needs.
- A lint test bans floats, `randf`, the clock and Nodes from the sim code. The AI can't cheat its way past it.
- **At hour 24:** 11,674 checks passing in the main suite, plus 197 in the sim test. 28 test and tool
  scripts. ~17,800 lines of game code, ~3,500 lines of tests.
- **Today (hour ~57):** 28,642 checks, plus 626 in the sim test. 57 test and tool scripts.
  ~35,900 lines of game code, ~13,000 lines of tests.
- Plus the checks that aren't asserts: a balance round robin (every unit vs every unit at equal cost),
  a counter quiz, a pathing audit, a draw-order check, an AI-beats-a-passive-player test, bot vs bot.
- And every visual change gets a screenshot that's looked at before it's kept: 440 in the archive.
- Every design call is written down with who made it: 124 numbered decisions.
- Line: "Vibe coding is the speed. The tests are why it still works the next morning."
- **Honest note:** today's sim test has one failure, the tick-time budget (3.3 ms against 3 ms after
  siege and towns landed). Fix it before recording, or say it: "the tests caught this one".
- Footage: run `godot --headless --path . --script res://tests/run_tests.gd` and the same in
  `video/builds/h24-freeze`, side by side.

## 6. Hours 0.5-1.5: map, workers, economy (4:00-5:00)

- An hour in: flow-field pathing, the isometric view, workers gathering bugs and cutting reeds, houses.
  Rats out-breed everyone.
- Stills: `04-map-economy/`. Footage: `builds/h01-iso`, `builds/h01-economy`.

## 7. Hours 1.5-2: what should it look like? (5:00-6:30)

- Five styles in one scene: storybook, paper, painterly, toy 3D, pixel.
- Me: "You're testing rendering, not art direction." A sixth: detailed 3D baked to pixel sprites.
- Then units modelled in 3D parts and baked to sprites, one atlas: 211 units in 20 draw calls.
- This is the "human taste" moment. Say what you didn't like and why.
- Stills: `05-art-direction/`. Footage: `builds/h02-style-sampler`, `builds/h02-pixel`.

## 8. Bug reel (6:30-7:15)

- Frog standing on a hut roof · dead units as dark slivers · a ghost army · legless spiders sitting
  on ponies · a pegasus wing growing from the rump · pegasus wings on the rider instead · a centaur
  swallowed by the podium · a floating pilum · frog huts that "look like golf" (your words).
- 3 seconds each, a sting per bug. Stills: `06-bug-reel/`.

## 9. Hours 10-15: war (7:15-8:15)

- Combat, armour, counters (spears beat cavalry, cavalry beats archers, archers beat infantry),
  an AI that builds, counter-picks and attacks in waves. Fog of war and a minimap.
- **Hour 15:** a complete playable match against the AI.
- Stills: `07-war/`. Footage: `builds/h11-combat`, `builds/h15-playable`.

## 10. Hour 17.5: the AI beat me (8:15-9:30)

- The payoff, told not replayed (Dominic, for now). Tell the story of the first real match over the
  hour-15 footage (`builds/h15-playable`) and `07-war/` stills, facecam on, and react to it.
- Commit at 16:55: "the AI beat him". Back then the AI had one level: raids from minute 4 with its whole army.
- Playing the AI on camera waits for video 2 or the AI video.

## 11. Hour 24: the clock stops (9:30-10:00)

- Freeze on the hour-24 build. By then it also had a lobby, 8 facings for every unit, animals to hunt,
  a market, Easy/Normal/Hard AI, and sounds from our own synth.
- Honest scorecard: what works, what's ugly. Still: `09-hour24-vs-hour0/` (hour 0 vs 15 vs 24 side by side).

## 12. "...and then I couldn't stop" (10:00-10:45)

- Said once, never again. Clock spins past 48h, 72h.
- Montage with "coming: video N" tags: the timber UI, burning houses, rivers and bridges, rams at a
  stone gate, rats storming a ramp, frog siege engines. Stills: `10-after-the-clock/`.

## 13. The ask (10:45-11:00)

- "Type a civ in the comments. The top 5 get generated and fight in the next video."
