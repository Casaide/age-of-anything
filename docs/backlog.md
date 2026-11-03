# Backlog: after the MVP

Everything discussed and deliberately postponed, roughly in priority order. When something moves
into active work, move it into `mvp-plan.md` (or a new plan) with an exit criterion.

## 00. Next after voxel units are the default (Dominic, 2026-11-03: "wait for voxel completion")

- **Moddable buildings, tech, AI and sound.** A mod can't touch `buildings.json`, `tech.json`, `ai.json` or `audio.json`
  today (`MOD_DATA_FILES` in `src/gen/mods.lobster`), so a mod can't trim the game to infantry only or bring its own
  sounds. Make them mergeable like parts (remove or disable entries, a mod's own `audio/` WAVs), with the bots
  reading what exists instead of a fixed building list. Test case: the sci-fi mod as Dominic described it: "disable
  most units and buildings and focus on reduced tree, like just infantry fighting... easily make some aliens, and
  add custom SFX and lasers". Toward the game's own content being a base data pack loaded like any mod.
- **Effects as voxels.** Small voxel pieces (a rock chunk, a dirt clod, a spark, a dust puff; data or `.vox`), baked
  once, and effects as data recipes that scatter them with random sizes, angles and speeds (view-side randomness
  only): catapult impacts, arrow hits, a laser as a stretched glowing beam piece plus a spark burst. Replaces the
  destruction pixel dust (D-171) with one system. A whole-animation voxel flipbook only for one-off set pieces.
- **Toward an engine with the game as content (D-190):** our own content as a base pack loaded like any mod; then
  small deterministic script hooks for rules and free client-side UI extras; multiplayer refusing mismatched packs.
- **Mod scripts, first form (D-190's hooks):** Lobster files compiled in at start, as models are today, but only
  through a small hook API (on-hit, on-death, ability kinds, building behaviours). Rule hooks run in the sim and must
  be deterministic (integers, the sim's rng, no clocks); UI hooks are client-side and free. `mod_check` is the
  sandbox: it refuses file, network and clock builtins and applies test_sim's determinism lint to rule hooks. Code
  mods need a build with the compiler (Mac, Deck, a desktop release); Android takes data-only mods.
- **Later, a Lua-like runtime script (Dominic, 2026-11-03: "something we can consider in the future"; all three
  interesting):** (1) our own interpreter for a Lobster subset, a true sandbox, everywhere, slower; (2) a restricted
  Lobster VM, compiled once and called repeatedly with an allowed list of builtins (an upstream feature; spike first:
  repeated calls into a kept VM, and the compiler in a `--cpp` build); (3) real Lua embedded, integers only for rule
  scripts. Claude leans to (2).
- **`.vox` import and export.** Read MagicaVoxel files as parts or whole creatures on the voxel skeleton and
  sockets, and write any generated unit out as `.vox` to tweak and drop back in. After the voxel data format settles.

## 0. Left open when milestones 8 and 10 closed (2026-10-11, Dominic: "close 8 and 10 for now")

- **AI playtest:** Dominic plays a match against the AI and wins as a decent player (milestone 8's
  second half; the AI already beats a passive player in `tests/test_ai.gd`). First try, 2026-10-11:
  the AI beat Dominic.
- **Testers:** 5-10 testers with `playtest.md`; the metrics in `mvp-plan.md` §4.
- **Export build:** a Mac and a Windows build of the Lobster game (the Deck's Linux one exists: `src/deck/build.sh`), and an itch account.
- **Determinism across macOS and Linux:** run `tests/test_sim.gd` in a Linux container and compare hashes.
- **Cost sanity:** 8 of 20 units still more than 20% off the mean at equal cost; big bodies are worth
  more with spears than with bows. Needs per-unit price-by-simulation (see "Later" in CLAUDE.md).

## 0b. Carried forward when milestones 5, 13, 14, 16, 19 and 21 closed (2026-10-17, Dominic: "anything requiring my checks can close, anything else we move forward")

What only waited on Dominic's look or pick closed with its milestone (the placeholders in play stay: the wall tower,
the rubble, the siege tower and ladder, the trade cart, the unique units' themes). The work left:

- **Bugs riding newts** (milestone 13): check swamp beetles and spiders riding newts; "frogs riding beetles" gives
  newts now.
- **Structural balance outliers** (milestone 13, step 9): a design change, not more price tuning (the proposal is in
  `milestones/m13-unit-lines.md` Results). Also watch the draws since costs by material (D-144): 19 of 30 race matches
  went the distance, against 14 before.
- **The unique units' new parts** (milestone 13, step 4): a concept round for the parts each theme wants (the list is
  in `milestones/m13-unit-lines.md` Results); the themes play on existing parts now.
- **Race mechanics** (milestone 14, step 6): leap, shell, swarm/scavenge, shoot on the move (the web is the only one
  in play), and a concept round for the web's look.
- **Race balance** (milestone 14, step 8): frogs and rats at the edges (every race 33-68% over two maps).
- **Bears** (milestone 14): in play since 2026-10-17 (D-161 to D-163); what's left is below, "A Bear race".
- **The end screen's match story** (milestone 19, step 5) and the open-licence fonts (step 2, waiting on a download
  yes). The post-game stats are milestone 18's.
- ~~**Shields on spiders and beetles**~~ (done 2026-10-17, D-152): slung on the back, every shield and back piece
  checked on every body (`gear_cases`).
- **Norse, the rest** (D-151): a concept round for the Norse helmets (built from round 1's suggestion, which Dominic
  hadn't picked; the braids and beards came off, since they cut into frogs, rats and beetles), a Norse architecture
  (longhouses, today the thatch look), a Norse war beast for humans (the creature's elephant wins over the culture's
  boar), and the shield wall formation (milestone 22, step 4).
- **Mods, the rest** (milestone 21): the lobby's mod list (enable, disable, refusals, missing mods for a shared race);
  buildings, tech, audio and creature-kit creatures moddable; model scripts sandboxed or `.glb`-only for shared mods;
  installed from a zip on a second machine with the same race key and a match played; Steam Workshop.

### A placement rule for a body showing through its armour (Claude, 2026-10-31, bears B4)

Dominic caught the B4 bear's body through its cuirass in patches ("overlap"); the check lets armour and its body
share volume, so nothing caught it. A first try (patches of body inside the armour's outline, seen from each bake
camera, with arms, head and gear in front counted) caught it at 7 patches, but rats in leather and bears in sardine
or mail already reach 5 to 7 (collar openings, gaps between strips). Either look at those units to see whether they
really show through, or find a measure that tells them apart (patch size against the armour's area, depth under the
armour's surface), then add the rule with a fixture (B4 B with its armour fitted to the old chest ball).

### Android and the bake rework (Claude, 2026-10-29, D-185)

- **Touch, after Dominic's first go** (built 2026-10-29: `game/touch.lobster`, tap/hold/drag/pinch through the pad's
  controls): a way to deselect without the back button, attack-move, groups, the idle-worker and Town Center jumps,
  and whether the bottom panel should give way to the wheel on a small screen.
- **Android: layout** on a wide phone (2400x1080): the setup page's lowest line is cut off.
- **The building and prop bakes on the GPU path too** (they still shrink on the CPU: the prebake takes ~7 minutes).
- **pixelize_finish on the GPU** (the alpha cut and outline: 2.3 s of the 9 s for two races).
- **Texture memory:** all six architectures' sheets are 1.4 GB as textures; only what's drawn loads now, but nothing
  unloads, and phones may want compressed textures (ETC2).

### Left from the Lobster port when Godot was retired (Claude, 2026-10-28)

The Lobster game has everything the Godot one did that a player meets, but for these:
- **The shared network lobby:** in Godot a joiner saw the host's setup and took a side; Lobster's lockstep sends a
  finished world, so the host's setup decides every race. Hosting a saved game isn't ported either, and finding hosts
  is a 1.5 s scan when the page opens (Godot listened all the time).
- **Lobby polish:** the Race Lab's wandering extra copies, the dice tumbling, the forge veil while an army is made (a
  dimmed stage and "Forging the army..." now), Cmd +/- for the UI's size, tooltips in the side's culture look.
- **AI levels aren't saved:** a loaded save plays at the bots' config it was saved with.
- **The wall and gate join check** (wall_join_check.gd: composed wall sprites against one 3D bake per join) has no
  Lobster port; walls' models are held by the golden files.
- **AOW_ART_SCALE** (the art at another scale for a study) has no Lobster counterpart: `ART_SCALE` in
  `src/view/art.lobster` is a constant.
- **2D placement against Godot's:** at the end 60 of 19668 results differed, all pixel-edge cases where Godot's GPU
  and Lobster's renderer round apart (the sitting cat's hind paw, the bear mount's foreleg in facing 0, the great
  sling's file of crew), and the heroic humans' "legs not hidden" counts at the threshold; the composer's draw lists
  were the same as Godot's but for intended differences. Worth a look when those units change.
- **The example mod's future rat on a spider** fails A3 (its weapon hand into its visor: `src/mod_check.sh scifi_test`).

### Godot's saves in the Lobster game (Claude, 2026-10-27, from the Lobster port)

Saves made by the GDScript game don't load in the Lobster one (each has its own format). Godot's are zstd-compressed
`store_var` data; Lobster has no zstd. A way to do it: every Godot save also keeps its match as a replay (races as
prompt + rules + reroll, map, seed, teams, every command a person gave), and the Lobster sim and bots match Godot's
tick for tick, so Lobster could replay the save to its tick and check the save's hash. Needs a zstd reader and a
Godot Variant reader in Lobster. Only worth it if old saves need to carry over.

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

- **Open counter pairs (Claude, 2026-11-03, D-200; Dominic's call).** With the soldiers' research on, spears beat horse
  archers 5 of 8 in age 2 and 3 of 8 in age 3 (they stand off at range 6: no bonus reaches them), and the large line
  beats archers 8 of 12 in age 2 (crossbows against the Royal Humans' lancers, archers against giant beetle axemen on
  foot). Options: skirmishers as the horse archers' counter in the chain (they win 7 of 8 in age 2, 1 of 8 in age 3),
  a charge or speed for spears, or a lower range for horse archers. `gen/counters.lobster` RR_COUNTERS_OPEN.
- **Upgrades that do little in a fight (D-200, `calibrate.lobster upgrades`; proposals, not applied).** Effect on the
  lines they reach, win-rate points against the panel, one side upgraded: sharp sticks +10, bronze edges +8, ring mail
  +8, saddle blankets +8, barbed heads +7, good hay +7, quick draw +7, hoof wraps +6, padded coats +5, scale barding +5,
  hardened tips +4, quilted vests +3, leather jacks +3, fletching +3, marching drums +2, long shafts -1. The ranged
  armour (quilted vests, leather jacks: +1/+1) and padded coats are under the +10 a player would notice: +2 pierce
  armour each would be the first try. Range and speed (fletching, long shafts, marching drums, hoof wraps) matter
  for kiting and raids, not a brawl. Flips: hardened tips, quilted vests and saddle blankets each turn the Royal
  Humans' spears against their crossbow riders (an open pair already). Castle research: long spears +22, berserkergang
  +15, winter coat +9, shell polish +9, repeating bows +9, shield wall +8, chivalry +8; gnawing teeth, rust spikes
  (buildings), sticky silk, saddle bows, frog leap, gallop, jaguar pelts about 0 in a fight.
- **Counters at calibrated prices:** done (D-199): prices fitted against the counter chain, swords +6 vs spears,
  large +6 vs ranged; test_sim checks each pair. Left: the bow still fits near 0 price points (archers lose to most
  lines on attack-move, the kiting note below); the prices were fitted with large at +4 vs ranged, measured at +6.
- **Bot matches at calibrated prices (Claude, 2026-11-03, D-195, D-199).** At D-195's prices test_ai's frogs vs rats
  drew to 30:00 (and 45:00); with D-198 (a bot ahead presses home) and D-199's prices it ends at 22:07, but "hard
  beats normal" fails (normal wins at 13:51). Whole bot matches swing with any price set (points-only prices failed
  that check too); the fix belongs in the bot levels, not the test.
- **Calibration leftovers (D-195):** identity bonuses' `price_points` (groups, creatures, cultures) aren't fitted
  yet (centaur lines still run strong); age 1 and age 4 lines aren't sampled; wings and quivers price near 0 because
  open-field fights don't value flying or scouting.

- **Price by simulation** (done offline, D-195: `src/calibrate.lobster`): headless fights of each unit vs reference units (Frogs, Rats) at equal
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
  Decentralised distribution still needs a stance. (2026-10-13: mods and their IP stance are milestone 21,
  `docs/milestones/m21-modability.md`: official content original, franchise mods the players' own and
  private; a player-facing policy page before any public sharing.)

## 8. Game content

- **Asymmetric gameplay: small but key signature mechanics per race type (Dominic,
  2026-10-11).** Explore in a later milestone. One or two mechanics each, driven by tags in the
  data (a creature's or culture's tags unlock an ability), never special-cased in code. Examples:
  - **Amphibians (frogs, crocodiles):** build on swamp and shallow water, and swim across
    shallow water.
  - **Roman infantry:** throw a pilum volley before closing to melee.
  - **Vikings:** form a shield wall (stop, high pierce armour, slow). (2026-10-17: the Norse culture exists, D-151;
    the shield wall is milestone 22's step 4.)
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

### A big-winged castle unit that soars over trees (Dominic, 2026-10-17)
Flyers no longer cross trees or the deep river (D-154): flying over the woods "feels again too imbalanced". Dominic:
"If their castle unit had extra big wings and could go over trees that would be more unique." A winged race's castle
unit with oversized wings and a movement class of its own (say `soaring`: what flying was, trees included; the deep
river still stops it, or not: Dominic to say). New art, so concept-first (D-080): wing options on a sheet, Dominic
picks, then the placement check. Data: a movement class in `rules.movement.classes`, the tag from its wings part.

### A race perk: a line without gold (Dominic, 2026-10-17)
One race might lose the gold cost of a line as its special benefit (Dominic: "we could do that for rats or spiders or
something if it's balanced, but it has to be carefully balanced"). It would be an identity bonus (`src/identity.gd`)
that changes the line's mix, priced like any other bonus, then checked with the race round robin and the bots'
economies (D-150 set every line's mix).

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
Concept rounds B1-B3 (2026-10-13, `docs/concepts/bears/`); Dominic picked the heads (B2) and the mount (B3), D-126, D-127.
**In play since 2026-10-17** (D-161 to D-163): the brown, black ("moonbears") and polar bears as races, the bear mount
for others ("romans riding bears"), a bear voice. Still to do:
- Dominic's look at them in a match, and a listen to the bear voice (`assets/audio/voice/bear_*`).
- The polar bear as the brown bears' giant (B1's recommendation): the large line is the race's own bear at 1.5x for now.
- "black bears" as words (two-word phrases): the black bear is "moonbear(s)" / "blackbear(s)" for now.
- The bears' own culture and architecture (dignified, Greek-like halls; timber lodges): they borrow hellenic and forest.
- Their bonuses beyond the placeholders (folk research, thick fur, honey hunters) and their own research (Winter Coat)
  after a balance look (`tests/race_matches.gd` with bears in the round; 2026-10-17 on Reed Meadow: bears 33%, polar
  bears 0% of 6, level rats 33%, imperial humans 16%, 7 draws of 12).
- Carried loads (`load.*`, UnitView's carry hold) aren't in the 3D placement check for any creature; the bears' were left
  out with them.

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

- **More bodies laid down in 3D when they die** (D-165): only the frog has a `corpse` pose. Bipeds still topple
  as a turned sprite, and a turned sprite is what Dominic called terrible on the frogs; the rats, beetles and
  humans would gain the most. Each needs its limp models and the pose numbers, checked by D1/D2. Round HF2's
  other frog poses (belly up, on its side) are in `tests/sheets/frog_fall_hf2.json` if a race wants them.
- **The frog's kerchief under a corpse** (HF2b): the belly rests 2 units up on it, where cloth would
  flatten. (Seen from behind, the stretched legs read as legs standing: solved by turning the body per
  facing, HF3 / D-166.)

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
- The lobby's roster portrait tiles (`src/view/ui/roster_tiles.gd`, kept, unused) left the side
  panels on 2026-10-13: their portraits meant baking every unit and age before an army showed
  (Dominic: the cards only on the tech tree). The panel shows a line of the lines' names. If they
  come back, fill them from the background warm-up's portraits, never ahead of the stage.
- More creature architecture (2026-10-11): spiders' silk tents strung between stalks (they share
  the bugs' mounds for now); timber lodges for beavers and bears once they exist.

## 10. Platform

- itch.io demo, then Steam (disclose AI-generated content used in shipped assets, per Steam rules).
- Pear/P2P-native distribution.
- Anonymous, opt-in analytics: unmatched prompt words, match length, age-up times.
