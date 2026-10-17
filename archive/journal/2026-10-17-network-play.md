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

## Pictures
- `01-network-match-host-window.png`, `02-network-match-joiner-window.png`: the two windows at the end of the check,
  the joiner commanding the rats.

## Next
Dominic's Mac vs Deck match on the home network (phase 1's exit), then the HyperDHT sidecar.
