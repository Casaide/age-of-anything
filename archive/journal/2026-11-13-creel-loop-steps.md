# 2026-11-13: the frame loop's engine steps go to Creel (#433)

**What happened.** The last piece of the Creel split. The loop in `game.lobster` (`play_match`) is this game's weave
of menus, the banner, music by age, saves and test options around a few engine steps, so it wasn't moved whole
(Dominic's line from 2026-11-10: UI and game logic stay in the game, Creel gets the tooling). The steps went to
Creel's `game/match_loop.lobster`: `sim_owe` and `sim_run` (the play time a frame owes and the ticks it pays for:
lockstep's turns, the bots, the step), `cam_follow_fight`, `draw_world_lit` (shake, world, atmosphere) and
`record_begin` / `record_frame`. `play_match` calls them and is about 60 lines shorter. Creel's example has a plain
loop built from the same calls, and its check now type-checks the world drawing for the first time, because
something finally calls it. (Claude)

**Decisions.** The game's Creel pin stays behind Creel's `main`: the loop steps sit on the commit the game already
used, so this change brings nothing else with it. Creel's `main` has 57 more commits of engine work for the next
game. With them our tests pass, but lint shows 5 warnings and the look may differ, so moving the pin there is a
separate piece of work for Dominic to ask for. (Claude)

**Not checked.** The game in a real window on the Mac. The quick batch plays the self-test through the real loop
under software rendering, which covers the sim steps and drawing calls but not frame time or how it looks.
