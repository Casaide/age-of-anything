# Age of Anything

A classic-style 2D RTS where your civilisation is whatever you can describe. Type "centaur romans" or "sewer rats
with cheese hammers": the game builds the race from a parts kit, prices every unit fairly, and you play a match with it.

Written in [Lobster](https://github.com/aardappel/lobster). With Lobster built at `~/Dev/lobster`:

- Play: `./play.sh` (the title screen: battle the AI, play on the network, load a game, the Race Lab)
- Tests: `./tests/batch.sh --quick` (the whole batch without `--quick`)
- How it's made and where things are: `CLAUDE.md`, then `docs/`

## Try the mods

Mods are folders in `mods/` (how to make one: `docs/modding.md`). Each loads only when asked for:

- **Big battle** (`big_battle`): 2,000 units in formation march on each other across an open field framed by a river,
  groves and a ruin, zoomed out. The first run bakes for about 45 s.
  `./play.sh lobby mods:big_battle`
