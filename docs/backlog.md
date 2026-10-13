# Backlog: after the MVP

Everything discussed and deliberately postponed, roughly in priority order. When something moves
into active work, move it into `mvp-plan.md` (or a new plan) with an exit criterion.

## 0. Left open when milestones 8 and 10 closed (2026-10-11, Dominic: "close 8 and 10 for now")

- **AI playtest:** Dominic plays a match against the AI and wins as a decent player (milestone 8's
  second half; the AI already beats a passive player in `tests/test_ai.gd`). First try, 2026-10-11:
  the AI beat Dominic.
- **Testers:** 5-10 testers with `playtest.md`; the metrics in `mvp-plan.md` §4.
- **Export build:** needs the Godot export templates (about 1 GB) and an itch account.
- **Determinism across macOS and Linux:** run `tests/test_sim.gd` in a Linux container and compare hashes.
- **Cost sanity:** 8 of 20 units still more than 20% off the mean at equal cost; big bodies are worth
  more with spears than with bows. Needs per-unit price-by-simulation (see "Later" in CLAUDE.md).

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
  `tests/balance.gd` (milestone 10) is the measuring half: an equal-cost round robin. The next step
  is a tuner that nudges part points until no unit is more than 20% off the mean (11 of 20 were
  after hand-tuning). `tests/tune_points.gd` is that tuner, one step at a time; it needs the
  counter matrix as a constraint (unconstrained, it made bows nearly free and counters fell to 67%).
- Price-by-simulation is needed for the last cost-sanity outliers: part prices add up regardless
  of combination, but a big body is worth more under a spear than behind a bow (milestone 10).
- Archers without micro lose to spearmen that close the gap: consider simple kiting for ranged
  units on attack-move, or a range/accuracy rule, before pricing them down further.
- Replace `pow()` in pricing with a fixed-point table (done in milestone 1).
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

- **Asymmetric gameplay: small but key signature mechanics per race type (Dominic,
  2026-10-11).** Explore in a later milestone. One or two mechanics each, driven by tags in the
  data (a creature's or culture's tags unlock an ability), never special-cased in code. Examples:
  - **Amphibians (frogs, crocodiles):** build on swamp and shallow water, and swim across
    shallow water.
  - **Roman infantry:** throw a pilum volley before closing to melee.
  - **Vikings:** form a shield wall (stop, high pierce armour, slow).
  - Candidates to weigh up:
    - Beavers dam water into new ground or swamp.
    - Bears hibernate to heal, or maul (splash).
    - Elephants trample.
    - Egyptians farm the flood plain.
    - Greeks form a phalanx (reach plus a frontal armour bonus).
    - Steppe riders shoot on the move.
    - Rats burrow.
  - Needs: an ability slot in the data contract, sim support for terrain changes (dams, building
    on water), and a check that each ability has a counter.

- **Starter roster: what to launch with (Dominic, 2026-10-11).** Pick the races people will be
  most excited about. **Non-European animals and cultures are an absolute priority**, not an
  afterthought. Two pillars:
  - **Animals:** a wide spread to show off asymmetric play and the art. Bears and beavers are
    on the table if their gameplay earns it ("bears vs Romans is epic"). Starting ideas, not yet
    chosen:
    - Africa: elephants, hippos, meerkats.
    - Asia: pandas, tigers, macaques, red pandas.
    - Australia: kangaroos, wombats.
    - The Americas: capybaras, llamas, armadillos.
    - Crocodiles, camels.
    - Frogs and rats, which we have.
  - **Bronze and iron age cultures:** vikings, Romans, Egyptians, Greeks, plus a few that stand
    out, chosen with the same non-European priority. Candidates:
    - Han Chinese (crossbows, terracotta);
    - Persians (immortals, chariots);
    - Kush/Nubia (famed archers);
    - Mauryan India (war elephants);
    - Carthage;
    - Celts and Scythians;
    - the Yayoi or Kofun era in Japan;
    - Mesoamerican cultures (obsidian weapons, an era stretch worth a playful note).
  - Before choosing, research what players are excited about and check every culture is drawn
    respectfully (signature kit, names and architecture), not as a costume.

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
  - **Fantasy pack (Dominic, 2026-10-11): a stretch goal alongside WW2 and sci-fi.**
    - Wizards and casters (a new ranged class with spells), dragons and other big beasts, enchanted
      gear, castles and towers.
    - It needs ability support (the asymmetric-mechanics note above) and magic damage as an armour
      class, both of which the combat model already allows for.
  - **Forest folk / sky pack (Dominic, 2026-10-11):** people riding big birds, tree people,
    flying mounts. Could join the fantasy pack or be its own.
  - Sci-fi "space federation" pack. A space-fleet sci-fi mod is Dominic's personal dream; keep
    official names and likenesses out of shipped content.

### The sapper (parked 2026-10-13, Dominic: "remove the sapper unit, not needed")
Built in milestone 13 (Castle, age 3: walks up to a building and blows up with it; a wall tile or house in one blast,
a Town Center in three). Parked: its roster slot is `"status": "planned"`, the Castle doesn't train it, the bot doesn't
want it; the blast code (`combat.gd _blast`), its model and its sim test stay for later.

### A Bear race (Dominic, 2026-10-13: next to plan once milestone 13 is done; "it'll just be really cool to see")
A new creature: bears. Not in the data yet. To plan, concept-first: how big a bear soldier is next to a human
(standing bears are bigger; workers too, so buildings, crews and gear need sizing), body (two legs standing, or
four with a rider; a bear cavalry mount for other races), head and fur skins, a culture or favoured families
(forest? northern?), lexicon words (bear, bears, grizzly, panda?, polar?), `giant_ok`, gear fit, its siege
take and architecture, and pricing (big hp through points, no special case).
Dominic's direction (2026-10-13): two legs, armoured, more like the Greeks: dignified and intelligent,
the smarter counterpart to the rats. Bears also rideable as a mount for some races.
Some bears bigger still, on two legs and much larger: polar bears, or older bears (Dominic) — a natural large/giant line.
Concept round B1 is up (2026-10-13, `docs/concepts/bears/`, data in `data/later/bears.json`), waiting on Dominic's pick.

### Eras and themes as a layer (Dominic, 2026-10-13: later; "we're not ready for later ages like that yet")

"Rats with guns" showed that a gun is really an era ask, not just a weapon: under Anything
goes, the soldiers get muskets but the healer still carries a herb staff and the town is thatch.
The idea: the era becomes its own layer, from the prompt's words within the host's bounds, and
it sets the technology level of every role. Culture sets the style within it, and the creature
adds the flavour:
- Era (guns, muskets, tanks, steam, cogs...): a field medic with a satchel and bandages instead of
  a staff; sappers and engineers for workers; bayonets, dragoons, cannon crews or steam walkers.
- Culture (sewer, imperial...): the style within that era (scrappy and junk-built for sewer).
- Creature (rats): the signature on top (the cheese sack fits a GI or a Napoleonic medic).
Steampunk is a theme the host allows, like the fantasy pack, triggered by "cogs", "brass", "steam".
Needs: an `era` per race (in the race key), era-tagged parts per role, the generator picking
era, then culture, then creature, and buildings by era (the biggest art cost). The era packs
below plug into it: gunpowder first (Napoleonic-ish), steampunk as the first theme. After
milestone 13 at the earliest.

### Sieges, left after milestone 16's first pass (2026-10-13, Claude)
- The bot's assault on a full ring (Fortress bot vs bot stalls: no breach in 22 minutes); the bot raising ladders.
- Infantry carrying ladders (workers raise them now); the siege tower carrying units inside.
- Readability: outlines behind tall walls, wall damage states, the pour's name on screen, its own effect.
- Ladders and the siege tower in the bot's counter-reading and the balance round robin.
- The rest of milestone 18's match rules on the `mode` contract.

### Battle mode (Dominic, 2026-10-12: "not just yet, but write it down")

A custom battle: no economy, set armies by points, fight ("10 frog knights vs 100 sewer rats").
The most shareable thing a prompt-made-race game can offer, and it reuses the generator, pricing,
combat and the lobby. Mostly menus; also a good balance sandbox.

### Age 4 and the Temple (postponed 2026-10-12, Dominic: "we may come back to age 4 later")

Cut from milestone 12 to keep three ages; kept whole in `data/later/age4_and_temple.json` (the
exact data entries) and listed in `docs/milestones/m12-tech-tree.md` ("Postponed: age 4 and the
Temple"): the Shiny Age and fourth line steps, the fourth steps of the research tracks, the
Temple with mystics (conversion) and their six research. Bring back by moving the entries home.

### A generic Raider line (cut 2026-10-13, Dominic: "Raider isn't really a thing, sounds race specific like a castle unit")

The planned Barracks line (fast light infantry, age 3) is kept in `data/later/raider_line.json`.
Raiders live on as unique-unit themes at the Castle (`data/uniques.json`: the steppe raider, the
gutter raider for rats, the horned raider for vikings, the gloom stalker). Bring the line back by
moving the entry home, if a race-neutral raider is ever wanted.

### Gates (moved from milestone 11, 2026-10-11; moved into milestone 12 phase 4, 2026-10-11)

Walls block everyone today; leave a gap. A gate lets its own team through and nobody else, which
needs passability per team: SimMap's walk grids per movement class *and* team, flow fields keyed by
both, and every walkability check (movement, separation, placement) asking with the unit's team.
Also: the bot doesn't use walls or the market yet.

### Race-specific resources (Dominic, 2026-10-11, a future thought)

Some races need a special resource that others don't (cheese for rats, say, or silk for spiders).
The races that don't need it can still hold the ground it's on, to deny it or to trade it: a
reason to fight over the map, and a reason to trade. Data first: a resource that a creature or
family declares it needs (`data/resources.json` plus a field on the creature), deposits on the
map like gold, and the market (milestone 11) buying and selling it. Open questions: what a race
gets from it (units, ages, upkeep), and how the AI values a resource it doesn't use.

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
- **From the independent art review (2026-10-11), not yet done** (captures in the journal):
  - Redraw `rat_fur`, `hide`, `mane`, `cloth` with fewer, larger marks (they dither at 1x);
    give `thatch` clumped, angled straw (it aliases into a barcode).
  - A test that every baked unit shows at least N team-key pixels; a hue-distance test keeping
    skins (`frog_blue`, `poison_red`) and culture cloth away from the team colours.
  - Armour per body: a declared armour shape and socket (rats in bronze read as a peanut).
  - Mirrored bakes (or more facings) so left-facing units are lit from the same side as buildings.
  - Mounts get a wing socket ahead of the seat (wings on a ridden spider land on the rider);
    a data flag forbidding creature-on-mount combinations the art can't show (beetle on a pony).
  - Swamp detail (puddles, mud, sedge); reeds and paths kept out of building footprints, paths
    ending at doors; boardwalk posts and edge shadow, planks kept square at turns; road slabs
    jittered and worn; water reflection gradient and ripples by the shore.
  - Spooky and forest architecture (they share the swamp stilt hut).
  - Small things: the junk Town Center's hard dirt slab, the log pile off the plinth, reeds past
    the map edge, unit shadows offset like building shadows, a lighter vignette.
- **Pathing** (2026-10-11, after D-104): flow fields don't know about units, so a worker whose
  bush is ringed by planted workers gives up after 4 s and takes another tile (or goes idle);
  the bot then often sends it straight back. Next steps: the bot caps gatherers per tile; a
  gatherer waits its turn when the clump has no other tile; unit-aware steering (a local
  avoidance step) for queues at gaps. `tests/path_audit.gd` measures it (flat map, 8 minutes:
  snaps 2, jitter 62, treading 473, give-ups 113 after the fixes; 164 / 233 / 839 / 1 before).
- The choke map (`choke_test`) is a movement test map with no food or wood; it left the lobby
  (D-104). A real second battlefield is wanted.
- **Audio** (the ground-up set is in, 2026-10-11, `docs/audio.md`): a second theme or mode for
  long matches; night / swamp / sewer ambience by map or architecture; voices by size and
  culture (a giant croaks lower, a Roman says a word); a "can't" bark; volume sliders.
- **Tutorial and campaign:** a scenario editor (the classic RTS longevity lever), then a campaign.
- More creature architecture (2026-10-11): spiders' silk tents strung between stalks (they share
  the bugs' mounds for now); timber lodges for beavers and bears once they exist.

## 10. Platform

- itch.io demo, then Steam (disclose AI-generated content used in shipped assets, per Steam rules).
- Pear/P2P-native distribution.
- Anonymous, opt-in analytics: unmatched prompt words, match length, age-up times.
