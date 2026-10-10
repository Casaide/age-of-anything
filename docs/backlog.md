# Backlog: after the MVP

Everything discussed and deliberately postponed, roughly in priority order. When something moves
into active work, move it into `mvp-plan.md` (or a new plan) with an exit criterion.

## 1. Networking (next after the demo)

1. **Two-sim test:** two sim instances in one process, fed the same commands with artificial
   latency. Proves lockstep without sockets.
2. **Sidecar:** Godot spawns `bare sidecar.js --port <random> --token <random>` and connects
   with `WebSocketPeer` to `ws://127.0.0.1:<port>`. The sidecar listens on localhost only and requires
   the token in the first message. Messages are JSON while prototyping, compact binary after.
   - Kill the sidecar on window close; the sidecar exits when its socket drops.
3. **Swarm:** the host creates a 32-byte topic shown as a join code, and both peers join it.
   Connections are Noise-encrypted, so you get peer identity (`remotePublicKey`) for free.
4. **Protomux channel `aow/lockstep/1`:**
   - Handshake: `{protocol_version, sim_build_hash, map_hash, race_keys, seed}`.
   - `turn {turn_no, cmds[]}` every turn, even when empty (it's also the heartbeat). Cork/uncork per turn.
   - `hash {tick, state_hash}` every 30 ticks.
   - `ping`/`pong` for RTT, and `chat`.
5. **Turn timing:** start at 200 ms with commands at N+2. Adapt the length from measured RTT, since
   relays exist and aren't flagged. Show a "waiting for player" banner when inputs are late.
6. **Desync:** on a hash mismatch, dump both replays plus per-system sub-hashes, then end the match
   gracefully.
7. **Later:** a GDExtension embedding Bare (bare-kit), but only if the sidecar is painful to ship.

## 2. Sharing and remixing races

- A race is a Hyperblobs bundle: a manifest (JSON or a Hyperbee entry) plus any custom part blobs.
  Its key is the race key.
- **Two ways to share:**
  - **Share key:** "play my exact army".
  - **Share prompt:** "roll your own".
- **Remixes** reference a parent manifest and swap parts, giving a family tree of creations.
- Peers fetch manifests and blobs before the match; lockstep then runs on identical data.
- **Share cards:** "I asked for X, got this", with the prompt, a picture and the key.
- **Replays that outlive the generator:** replays (milestone 1) store each race as prompt + rules +
  reroll + key and regenerate it on load, so any generator or data change breaks old replays
  (loudly: the key check fails). Once races are bundles, store the race key and load the recipes
  from the bundle instead; also stamp replays with a sim build hash.

## 3. Balance tooling

- **Price by simulation:** headless fights of each unit vs reference units (Frogs, Rats) at equal
  cost; win rate sets cost. Run it on generation and when parts change.
- Replace `pow()` in pricing with a fixed-point table (do this in MVP milestone 5).
- Counter-tag matrix as data (`data/counters.json`).

## 4. Generator and content

- **Parts:**
  - Parametric parts: stretch, bulge, length, taper, counts (legs, eyes, spikes).
  - Free sockets: any part on any fitting socket; multi-heads; mounts on mounts.
  - Pattern and decal layers (spots, stripes, scars, war paint).
  - More body plans: serpent, blob, flyer, insectoid biped.
  - Signature part per race: one constrained, generated or primitive-built part for the
    "pirate jellyfish" case.
- **Lexicon:** grow it with dev-time AI, then curate. Grow iconic-theme coverage from opt-in,
  anonymous logs of unmatched words.
- **Players:**
  - A manual editor after generation (swap parts, recolour, rename), plus Reroll.
  - A silliness setting: Faithful / Creative.
- **Civ bonuses and race economy modifiers** generated from tags (e.g. `swarm` -> cheaper,
  faster training).
- **More roster slots:** siege, a unique unit, a hero.
- **Codex:** fills in as you meet enemy units.
- **Live events:** generated as data and broadcast as inputs (the heron eats three frogs).

## 5. LLM brief expansion (post-MVP, high value)

The dictionary knows words, not cultures. "Romans" should mean legionaries with gladius and scutum,
pila throwers, auxiliary cavalry, an eagle standard, testudo. "Mongols" should mean horse archers
first. That knowledge is what an LLM adds: it **fleshes out the request** into a detailed brief
(per-role concepts, signature gear, playstyle, colours, names), and the deterministic generator
still maps the brief onto parts within host rules.

- **Run it once at generation time, never in the sim.** Store its output (the brief) in the
  race, so the race stays reproducible and shareable by key even if the model changes.
- **Bridge step (cheap, earlier):** dev-time AI writes `data/cultures/*.json` templates (per-role
  concepts and gear tags for popular cultures, e.g. romans -> spear slot "Legionary": gladius +
  scutum). The generator uses a template when the prompt names that culture. That gives most of
  the "knowledge" win with no runtime model.

## 6. Optional on-device model

- A small model (1-3B, e.g. via QVAC, on-device) writes the design brief with a closed vocabulary
  and schema-constrained output. A harness maps the brief onto parts with tool calls. The brief
  format stays the contract.
- Fallback: a template/random brief filled from the same vocabulary when no model is available.
- Show the brief to the player as a reveal while the units build ("The Bogborn: swamp ambushers").
- Optional embeddings, precomputed, to catch phrases the dictionary misses.

## 7. Community parts

- An in-game part editor built on the same primitives (dome, brim, crest, plume, strap, visor...).
- Parts shared by key, with popular ones promoted into the official library.
- Moderation and IP policy for shared content (people will immediately make famous film franchise civs).
  Decentralised distribution still needs a stance.

## 8. Game content

- **Races:** Beetles/Tortoises (armoured, defensive) and Crows (scouts, raiders).
- **Economy and buildings:** gold and stone, farms, walls and gates, markets.
- **Ages and tech:** more ages, full tech trees, formations, garrisons.
- **Maps:** random map scripts, more maps, and a small in-editor painting tool that writes the
  map JSON (maps are JSON since milestone 2; the TileMapLayer is generated from them).
- **Modes:** teams and diplomacy.
- **Host modes:**
  - Host curates: race list chosen by the host.
  - No limits: cross-era, e.g. "10 Abrams vs 1000 Spartans".
- **Era packs:**
  - Gunpowder: frog musketeers, the "Renaissance pack".
  - Industrial/modern: vehicles.
  - Air units.
  - Sci-fi "space federation" pack. A space-fleet sci-fi mod is Dominic's personal dream; keep
    official names and likenesses out of shipped content.

## 9. Art and presentation

- **Full classic-RTS-style art pass:** atlas of mask textures, palette shader, buildings, terrain.
- 8 facings if 2 + mirror isn't enough.
- **UI themed by your race** (Dominic, 2026-10-11): the HUD adapts to the generated race:
  panel colours and borders from the family/palette, fonts, emblems and little extra bits and
  bobs (frog lily-pad buttons, rat cheese-rind frames). Data-driven from families.json, like
  everything else.
- Raised-looking blocked terrain (rocks, reed beds) instead of flat diamonds; match sprite
  footprints to the sim's collision radii so crowds don't overlap visually.
- **Faster flow-field solves** if the ~2.4 ms one-tick spike ever shows: spread a solve over
  ticks, or move the solver to a GDExtension.
- **Animation:** baked atlases for far zoom and portraits; procedural hit flash and death poses.
- **Audio:** unit barks in silly voices, music.
- **Tutorial and campaign:** a scenario editor (the classic RTS longevity lever), then a campaign.

## 10. Platform

- itch.io demo, then Steam (disclose AI-generated content used in shipped assets, per Steam rules).
- Pear/P2P-native distribution.
- Anonymous, opt-in analytics: unmatched prompt words, match length, age-up times.
