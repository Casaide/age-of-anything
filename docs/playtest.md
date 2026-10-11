# Playtest kit (milestone 10)

For Dominic's testers. One session is about 30 minutes: a few minutes of the setup screen, one
match against the AI, a short chat.

## Running it
```sh
godot --path .        # opens the match setup screen
```
Pick a race for yourself and one for the AI (type anything, or press a preset), pick a map, Play.
Controls are listed at the top of the game view. F10 surrenders. Each finished match appends a
line to `matches.jsonl` in the Godot user folder (the path is printed at the end of a match):
races, winner, length, and when each side reached each age.

## What to watch (don't prompt; note what happens)
- Do they reach age 2 without being told? When? (target: 80% do, median 4-6 minutes)
- How long does the match run? (target: 8-12 minutes)
- Do they laugh at or screenshot their army? Write down every funny moment.
- Where do they get stuck or confused?

## Questions after the match
1. Show three units of the AI's army (pause, select). For each: "What do you think beats this?"
   (Readability target: 70% right, judged against the unit card's strong/weak lines.)
2. "Describe your army in a few words." (Do they use the intended tags: big, spear, fast...?)
3. "What was the funniest thing you saw?"
4. "What would you type next time?"
5. "Anything that looked broken?"

## Before testers (waiting on Dominic)
- Export templates for Godot 4.7.2 aren't installed on this Mac; an itch.io build needs them (a
  download from Godot's site, then an export preset). Uploading to itch is Dominic's call.
- Dominic's own runs first: the counter quiz, a match against the AI, the art sign-off.
