# Age of Anything

A classic-style 2D RTS where your civilisation is whatever you can describe. Type "centaur romans" or "sewer rats
with cheese hammers": the game builds the race from a parts kit, prices every unit fairly, and you play a match with it.

Written in [Lobster](https://github.com/aardappel/lobster). With Lobster built at `~/Dev/lobster`:

- Play: `./play.sh` (the title screen: battle the AI, play on the network, load a game, the Race Lab)
- Tests: `./tests/batch.sh --quick` (the whole batch without `--quick`)
- How it's made and where things are: `CLAUDE.md`, then `docs/`

## Building

`make` lists the targets. Each one runs that platform's own script (it says what it needs at its top):

- `make mac`: `build/mac/Age of Anything.app`, a dev build that runs this checkout (macOS Game Mode, Dock icon)
- `make deck`: the Steam Deck build in `build/lobster_linux` (Linux x86_64, built in podman or docker)
- `make mobile`: the Android APK, `build/android/age-of-anything.apk`
- `make all`: all three
- `make serve`: serves what is built on the local network (port 8080, `PORT=` to change) and prints the line to run on
  the Deck, in Desktop mode's Konsole: `curl -fsSL http://<your-mac>:8080/deck.sh | sh`. That downloads the build,
  installs it to `~/Games/age_of_anything_lobster` and adds the launcher ("Add to Steam" from Desktop mode's menu).
  The APK is served too, if built. `make deck serve` builds and serves in one go.

## Try the mods

Mods are folders in `mods/` (how to make one: `docs/modding.md`). Each loads only when asked for:

- **Big battle** (`big_battle`): 2,000 units in formation march on each other across an open field framed by a river,
  groves and a ruin, zoomed out. The first run bakes for about 45 s.
  `./play.sh lobby mods:big_battle`
- **Space** (`scifi_test` + `scifi_short`): two future races, each with one unit, a power-armoured pulse trooper, plus
  robot workers that cut wood and stone with lasers, in domed command hubs and drop hangars.
  `./play.sh lobby mods:scifi_test,scifi_short rules:short "races:future soldiers|space marines"`
- **WW2** (`ww2`): Shermans against Panzer IVs, with turrets that turn on their own, tracks that run, fighter planes and flak
  gunners. To play it by hand, with your own army by your town:
  `./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" army:6`
  To watch both sides' tanks fight:
  `./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" skirmish army:6 watch`
- **Haiduts** (`vox_example`): 18th-century Bulgarian haiduts drawn in MagicaVoxel, the example of a unit made as a `.vox`
  model (`mods/vox_example/tools/haidut.lobster` writes them). Type "haiduts" or "bulgarians":
  `./play.sh lobby mods:vox_example "races:haiduts|romans" skirmish army:6`
