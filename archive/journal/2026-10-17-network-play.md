# 2026-10-17: Two windows, one match

**Milestone:** networking (phase 1: the home network)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic asked for the fastest way to multiplayer: no server, no NAT trouble, our P2P stack (Bare, HyperDHT) as an
option. We compared ENet, WebRTC, Steam networking and a HyperDHT sidecar (D-147), and agreed: ENet on the home
network first, with local tests, because the hard part of lockstep is two machines staying in step, not the
transport; HyperDHT after.

The sim was built for this (milestone 1): commands are stamped with their turn and run two turns later. The new
`src/net/` is small: a transport (a loopback pair for tests, Godot's ENet), the lockstep (each turn's commands sent
with a done mark and the state hashes; a turn starts when every player's turn two before it is in), a LAN beacon
and finder, a version from the data's hash. The lobby has Play on the network: Host (the usual battle setup, then a
wait) or Join (the games heard on the network, or an address), the joiner naming their own race.

Checks, all passing:
- `tests/net_check.gd`: two worlds in one process over the loopback at four link speeds hash the same as each other
  and as one world with both bots; a tampered command shows as a desync; two processes over ENet on localhost play
  3000 ticks in step.
- `tests/net_game_check.gd`: two game windows on the Mac, through the real lobby page and match view: the joiner
  finds the host by its beacon, joins with the rats, and both reach tick 1200 with the same hashes.

## Bugs on the way
- macOS won't send a UDP broadcast to 255.255.255.255 (error 1): the beacon also sends to the subnet's own broadcast
  address (x.y.z.255).
- The page polled only while visible, and it never became visible in the test: no beacon, no handshake.

## A saved match, a person in an AI's seat
Dominic's next idea, with his 2v2 save to test: load a saved match on the network, the other player taking over an
AI (D-148). It needed little: the save travels in the setup, both machines load it, the bots of the people's seats
go and the others play on both machines alike. The test found three bugs worth their keep: the join page swallowed
the host's first turns (they came in the same batch as the setup, since a saved match starts fast), the lockstep let a
turn run over that gap instead of stopping, and a bot saved in the middle of a route search had lost the search.
Then the joiner took the Jaguar Lords, 26 minutes in, and both windows ran 600 ticks in step.

## Pictures
- `01-network-match-host-window.png`, `02-network-match-joiner-window.png`: the two windows at the end of the check,
  the joiner commanding the rats.
- `03-network-saved-2v2-joiner-takes-the-ally.png`, `04-network-saved-2v2-host.png`: Dominic's 2v2 save on the
  network, the joiner playing the ally's Jaguar Lords.

## Next
Dominic's Mac vs Deck match on the home network (phase 1's exit), then the HyperDHT sidecar.

## The first Mac vs Deck join, and the shared lobby
Dominic hosted on the Mac and joined from the Deck: the Deck saw the game, clicked Join, the Mac went straight into
loading, and the Deck sat in the menu with "the host isn't answering". The host had queued its setup and gone into
the load; ENet only sends when it's serviced, and nothing serviced it until the match's first turn, so the Deck timed
out. Second try worked (the art was cached, the load short), but the Deck only started loading once the Mac had
finished. Then, in a match, the Deck said "waiting for the other player" while the Mac said "the other player left":
the same thing the other way round (the Deck's long bake). Fixed by flushing every send, servicing the link while
loading and waiting longer for a quiet peer.

Then the lobby (D-156): the battle setup itself, shared, with seats. Dominic asked for 2v2 and choosing a side
before the 1v1 version had even run, so it went straight to seats. Written while Dominic played a match on the same
Mac: the lobby test needs the port his game was using, so it waits (its first run had failed with "can't listen").

Bugs on the way:
- Two game windows on one Mac baking the same parts at once wrote the same temporary cache file: a corrupt entry
  ("bake cache: unreadable entry"). The temporary file is per process now.
- The 2v2 loading screen showed two names and put every army after the first on the right: it lays out by team now.
- Selecting a repairing worker spammed errors: the panel's task names stopped at "Going inside" (three short).
