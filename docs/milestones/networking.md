# Networking (multiplayer)

**Status:** in progress (started 2026-10-17, Dominic: "we can solve that next using enet like you said and we do
local tests")
**Exit criterion:** phase 1 (the MVP): a full 1v1 between the Mac and the Deck on the home network, from the lobby to
the end screen, with no desync. Phase 2: two machines on different networks finish a match, no server of ours.

## Scope

What the genre's games and Godot offer, and our choice (2026-10-17, discussed with Dominic):

| Option | No server | NAT handled | Notes |
|---|---|---|---|
| Godot's ENet (built in) | yes | no (LAN or a forwarded port) | the smallest step: proves lockstep between two machines |
| Godot's WebRTC (+ a desktop extension) | no: a signalling server, TURN for hard NATs | mostly | brings back the server we want to avoid |
| Steam networking (GodotSteam) | yes (Valve's relays) | yes | lobbies and invites, but a Steam app id and Steam running: a release option |
| HyperDHT over a Bare sidecar | yes (public DHT bootstrap only) | holepunching; two strict NATs need a relay | our stack: the host listens on a keypair, its public key is the join code |

**Phase 1 (the MVP): lockstep over ENet, 1v1, on the LAN.** The hard part isn't the transport, it's two machines
(macOS and Linux) staying in step; ENet proves that with no NAT in the way. **Phase 2: the HyperDHT sidecar** behind
the same transport interface (`../backlog.md` §1 has its design: `bare sidecar.js` on a localhost socket, the swarm
topic or the host's key as the join code, Protomux later).

Why it's small: the sim already runs on a command stream (`src/sim/commands.gd`: commands stamped with the turn they
were issued in, 4-tick turns, run two turns later in (turn, player, seq) order), and a race comes from its prompt
and reroll, so a match is its setup (prompts, rerolls, map, mode, teams, seed) and its commands. No art or race
data travels. Bots are deterministic, so a bot seat needs nothing sent (later; the MVP is two people).

Not in phase 1: more than two players, joining a match under way, reconnecting, spectators, pausing, saving,
relays, Steam, the joiner choosing their own race in a shared lobby (the host sets both sides).

## Plan

1. **Two sims in one process** (`tests/net_check.gd`): two Worlds, one per player, each with a bot issuing its own
   side's commands, joined by a loopback transport with delay and jitter; they must hash the same at every
   checkpoint. Proves the turn gate and the command exchange without sockets.
2. **The transport and the lockstep** (`src/net/`, view side: Nodes and sockets never enter the sim):
   - `transport.gd`: send and receive messages (Dictionaries of ints, Strings, Arrays) to one peer; `loopback.gd`
     for tests, `enet.gd` over Godot's ENet (reliable, ordered).
   - `lockstep.gd`: at the end of each turn it sends that turn's local commands with a "done" mark and its state
     hashes; it takes the peer's into the world's queue; the clock may run turn R only once both players' turn R-2
     is in. A hash that differs ends the match with a message (and both replays saved).
   - `SimClock` asks the lockstep before each turn starts; a late peer holds the world (a "waiting for player" note).
3. **The handshake:** the host sends the setup and a version (a hash of the rules and data); the joiner builds the
   same races and sends their keys back; both bake, say "loaded", and start together.
4. **The lobby:** a Multiplayer (LAN) page: Host (the usual race setup, then waits) and Join (games found on the
   network by a UDP broadcast, so the Deck needs no typing; an address field as the fallback). In a network match:
   no pause menu pause, no saving, no speed change, no debug keys; surrender ends it for both.
5. **Local tests:** `tests/net_check.gd` also runs two processes on one machine over ENet (localhost), bots on both
   seats, a few minutes of match, hashes compared; then Dominic's Mac vs Deck match (phase 1's exit).
6. **Phase 2:** the HyperDHT sidecar (`tools/net/sidecar.js`, Bare), the same transport interface, a join code.

## Checklist
- [x] Plan written (2026-10-17; Dominic agreed the approach: ENet first, local tests)
- [x] 1. Two sims in one process, loopback with delay (2026-10-17: four link speeds, the same hashes as the reference; a tampered command caught)
- [x] 2. Transport (loopback, ENet) and lockstep; the clock's turn gate (2026-10-17)
- [x] 3. Handshake: setup and version (2026-10-17; race keys and "loaded" weren't needed: the gate starts both together, the hashes catch any difference)
- [x] 4. Lobby: Host, Join (LAN discovery, an address field); the match's network rules (2026-10-17; the joiner names their own race)
- [x] 5a. Two processes over ENet on one machine, and two game windows through the lobby (2026-10-17)
- [ ] 5b. The Mac vs the Deck on the home network (Dominic)
- [x] 5c. A saved match on the network, a person taking over an AI seat (Dominic, 2026-10-17; D-148): tested with
  his 2v2 save, the joiner on the ally's seat, 600 ticks in step (archive `2026-10-17/03-`, `04-`)
- [x] 5d. The shared lobby with seats: players join into open sides, 2v2, AIs on the network, Ready (D-156; built
  2026-10-17, its two-window test not yet run)
- [ ] 6. Phase 2: HyperDHT sidecar, a join code, two networks (#44, #514; built and checked headless 2026-11-17, waiting on the Mac vs Deck try)
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

**Phase 1 built (2026-10-17, D-147).** `src/net/`: `transport.gd`, `loopback.gd`, `enet.gd`, `lockstep.gd`, `lan.gd`
(beacon, finder, version); the clock's gate (`src/sim_clock.gd`); `scenes/sim_debug.gd` `use_network` (one side, no
bots, no pause, saving, speed or testing keys; a note when waiting, out of sync, or the other player gone);
`src/view/ui/net_page.gd` and the lobby's Play on the network.
- `tests/net_check.gd -- loop`: 23 checks (four link speeds; a slow link stalls, never desyncs; tampering caught).
- `tests/net_check.gd -- enet`: two processes, 3000 ticks, the same hashes as each other and the reference.
- `tests/net_game_check.gd`: two windows, the beacon found, the handshake, 1200 ticks, the same hashes (archive
  `2026-10-17/01-`, `02-`).
**A saved match on the network (2026-10-17, D-148).** Play on the network, Host a saved game, pick the save, then the
AI seat the other player takes; the joiner sees it in the list as usual. `tests/net_game_check.gd -- out 600
save:<path>` plays one in two windows.
How to play it: on both machines (the same build) Play on the network; one Hosts (sets their race and the map,
then Host Battle), the other picks the game from the list (or types the host's address) after typing their race.

**The shared lobby (2026-10-17, D-156).** `src/view/net_lobby.gd` makes the battle setup the lobby: Host a game
listens at once; players take sides (up to four people, AIs in the rest), Ready, and everyone loads together. ENet
(`enet.gd`) hosts up to three players, tags who sent what, and relays turns in a match. `tests/net_game_check.gd`
now plays a 2v2 through it (the joiner moves to side 4, two AIs on both machines): written, not yet run.
How to play it: on both machines (the same build) Play on the network; one Hosts (the battle setup opens), the
other picks the game from the list, takes a side and types a race; both press Ready.

**Online by join code (2026-11-17, #44, #514, Casaide/creel#45).** A Bare sidecar (`creel/sidecar/sidecar.js`) finds
the other players over Hyperswarm and pipes bytes to the existing lockstep TCP link on localhost, so lockstep and
Lobster didn't change. Hosting starts it: the waiting screen shows a 10-character join code (`abcde-fghij`, 50 random
bits, hashed into the topic) and copies it. The network page's box takes a join code or an address, with a Paste
button. Creel's `net/swarm.lobster` starts the sidecar in the background (bash, with every fd past 2 closed, or
`launch_subprocess` never returns) and reads its status file. `src/swarm_check.sh` plays `net_check` host to joiner
by code on a local test DHT (needs node and `npm install` in `creel/sidecar`). Since #517 `make mac` and `make deck` pack the sidecar (`tools/sidecar_pack.sh`: bare and Hyperswarm for that
platform only, about 56 MB), so nothing is installed on the Deck. How to play it: one player Hosts, the other pastes the code
and Joins.

## Changes from the original plan

## Links
- `../backlog.md` §1 (the sidecar's design), `m1-sim-core.md` (commands, replays, hashes), `m20-steam-deck.md`
