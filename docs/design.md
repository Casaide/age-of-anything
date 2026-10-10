# Age of Whatever: design

The source of truth for *what* the game is and *why*. For *how* and *when*, see `mvp-plan.md`.
For technical reference and sources, see `research.md`. For everything deliberately postponed,
see `backlog.md`.

## 1. Pitch

**A classic RTS, but your civ is whatever you can imagine, and the game prices it fairly.**

You type "centaur romans" or "sewer rats with cheese hammers". The game builds a race from a parts
kit, gives every unit stats and a cost that come from its parts, and you play a normal classic RTS
match with it. Silly is fine; broken is not.

- **Default matchup:** Frogs vs Rats (handmade launch races, ship with the game).
- **Second test:** centaur Romans vs winged Greeks (big feathered wings on their own backs, like
  the winged men in old pulp sci-fi, not pegasi).
- **Feel:** it should look and play like the classic 2D RTS games, so it feels like the genre you know,
  gone totally mad. It is our own game, not a copy: own art, names, rules and twists.

## 2. Core loop (the classic RTS loop)

Gather resources -> build buildings -> research -> advance ages -> train units -> fight.

- Economy and buildings are shared across races at first. Races differ through their units, one
  or two civ bonuses, and cost.
- Ages gate unit tiers (age 1 infantry/ranged, age 2 large/mounted, and so on).
- Win by destroying the enemy Town Center (MVP); more conditions later.

## 3. Races from parts (Borderlands-gun style)

Sprites are **composed from parts by tools, not generated as images**. That keeps them
deterministic, stylistically consistent, animatable and cheap to share.

### Recipe

A unit is a small JSON recipe: creature (body + head), skin palette, family (culture/style) for
cloth colours, parts on sockets, optional mount, scale. Recipes hold only strings and ints.
The recipe is what gets shared; everything else (stats, cost) is derived from it on each machine.

### Building blocks

- **Body plans:** biped, quadruped, multi-leg (spider 8 legs, beetle 6). Each has a rig with
  named sockets (`head`, `hand_r`, `hand_l`, `torso`, `back`, `seat`) and leg anchors.
- **Part slots:** primary (weapon/tool), off-hand (shield), head gear, torso armour, back (cape,
  banner, quiver, wings). Mounts carry their own parts too (pegasus wings).
- **Chimeras:** any part on any body that fits. A centaur is a human rider fused onto a pony
  (`fused_mount`). Frog heads on spider bodies, two heads, mounts on mounts are all fair game.
- **Parametric parts (planned):** stretch, bulge, length and taper; counts (legs, eyes, spikes)
  as numbers, not new art. A "twelve-eyed rat" is a parameter.
- **Material vs shape:** bronze, iron, bone, wood and chitin apply to any shape.
- **Pattern/decal layers (planned):** stripes, spots, scars, war paint, banners.
- **Colour:** palette channels (skin, skin2, cloth, cloth2, materials) plus a team colour region on a
  consistent place (shield, cape, crest, banner), so teams stay readable.
- **Families** (Borderlands "manufacturers"): style sets such as swamp, sewer, imperial and
  hellenic that give a race its identity, colours, preferred mounts and name parts.

### Stats follow looks

Parts carry stats, tags and points. Big means `large`; spears read as long lines and beat large;
wings mean flying. Players should be able to read a unit's strengths from its silhouette.

### Range

Body plans x parts x materials x palettes x parameters x mods. Even ~40 heads x 30 bodies x 50
weapons x 20 materials reaches millions of distinct units before mods. Most players will feel
unlimited. Where they won't is **specific requests** (see section 5).

## 4. Generation pipeline

```
prompt
  -> normalise (lowercase, strip punctuation)
  -> lexicon lookup (synonyms, plurals; data/lexicon.json)
  -> brief: creature, default creature, mounts, family, tags (weighted), size, notes, unknown words
  -> host rules: era bounds, point budget per tier, roster template
  -> per roster slot: mount/size decision, required primary part, optional gear by most-wanted first
  -> recipes -> pricing -> race (+ race key = hash of names + recipes)
```

- **Deterministic:** seeded by hash(normalised prompt | rules id | reroll). The same inputs give the
  same race everywhere. **Reroll** = same prompt, new roll.
- **No runtime AI in v1.** Simple NLP over a dictionary is fast, offline, works on any hardware and
  is deterministic.
- **Dev-time AI for breadth:** generate the parts library at scale within strict style
  constraints and curate by hand. Write the synonym dictionary, names, flavour text and codex
  entries. Test briefs.
- **Optional later:** a small on-device model (1-3B, e.g. via QVAC) turns a prompt into a
  **design brief** using a closed vocabulary and schema-constrained output. A harness (tool calls
  such as `search_parts`, `compose_unit`, `validate`, `preview`) maps it onto real parts. The brief
  format is the contract, so models are swappable and optional. A template/random fallback fills
  briefs on weak hardware.
- **Optional later:** tiny precomputed embeddings to catch phrases the dictionary misses (still no
  model at runtime).

### Example brief (target format for any future model)

```json
{
  "race": "Bogborn", "family": "swamp", "playstyle": ["mobile", "skirmish", "ambush"],
  "roster": [
    {"slot": "t1_infantry", "concept": "frog with reed spear", "size": "small"},
    {"slot": "t2_ranged", "concept": "blowgun frog", "size": "small"},
    {"slot": "t3_cavalry", "concept": "frog lancer on beetle", "size": "large"}
  ],
  "bonus": "fast_over_water"
}
```

## 5. Specific requests and misinterpretation

"WW2 Americans riding Mongolian ponies" needs recognisable details. There are several layers of defence:

1. **Iconic silhouettes first.** People recognise things by 2-3 features (rounded helmet + olive drab +
   rifle). Prioritise signature features of popular themes over breadth. Prompt logs show which.
2. **Primitives.** Dome, brim, crest, plume, strap and visor, plus parametric deformation, give a
   "close enough" result when the exact part is missing.
3. **Honest substitution.** When matching falls short, say so with a playful note ("No helmets in
   stock. Issued saucepans.") and offer a swap. A silent mismatch feels broken; a visible one is a joke.
4. **Era bounds.** In a Bronze-Medieval match, WW2 isn't allowed anyway; say so rather than fail.
5. **Community parts.** An in-game part editor on the same primitives; parts shared by key.
   Someone makes a good M1-style helmet once and everyone can use it. Popular community parts go
   into the official library.
6. **Runtime image generation as a last resort** fills only the one missing part (a "signature
   part" per faction, constrained), never a whole unit.

**Bad results are part of the fun** (Scribblenauts/Spore). A WW2 soldier in a saucepan helmet on
a slightly-too-round pony is a better clip than a perfect one.

- **Silliness setting for hosts:** Faithful (closest match) or Creative (looser on purpose).
- **Share cards:** one tap gives "I asked for X, got this" with the prompt, result and key.
- Fairness never depends on looks: stats and price come from parts, so silly is never broken.
- **Prompt logging (opt-in, anonymous):** unmatched words become the roadmap for parts and synonyms.

## 6. Host modes

1. **Host curates:** the host generates or picks races; players choose from the list. Best for
   tournaments.
2. **Bounded generation (default):** host rules (era, budget, allowed families, counter rules) are
   shared with the match; each player generates within them. You don't know what you'll fight,
   so scouting is a real first-contact moment. A **codex** fills in as you meet enemy units
   ("Mossback Pikeroach: tier 2, large, weak to fire").
3. **No limits:** Spartans vs Abrams, the "10 Abrams vs 1000 Spartans" YouTube fantasy. A later
   extension. Pricing still mostly balances it: 10 Abrams cost a fortune.

**Start strict:** Bronze Age to Medieval. This also caps the parts library to a manageable art kit
(spears, bows, bronze, iron, beasts, mounts). Gunpowder, vehicles, air units and sci-fi come later
as era packs.

## 7. Balance

- Every part has `points`. Unit cost = `base * (points / ref) ^ exponent`, with a superlinear
  exponent so concentrated power costs more. Build time and pop use the same curve, flatter;
  large units cost 2 pop.
- **Why superlinear:** concentration matters in RTS. One giant and twenty small units with the same
  total stats do not fight equally (focus fire and splash vs surround and soak).
- **Counter tags** from parts (the genre's standard web): spear > large/mounted, mounted > archers/skirmishers,
  archer > infantry, skirmisher > archer. Even
  absurd races have obvious weaknesses (big gets `large`, which is weak to spears).
- Costs split across resources by each part's `cost_mix`.
- Races fit a **shared roster template** (worker, spear, skirmisher, archer, tier-2 large; later
  siege, unique unit), so frogs still get an age-2 skirmisher (a frog with a reed blowgun).
- **Price by simulation (planned):** each new unit fights reference units in quick headless
  matches; win rate sets cost. Handmade Frogs and Rats are the reference set. This makes the
  economy self-correcting instead of formula-guessing.

## 8. Launch races

| Race | Identity | Mechanic |
|---|---|---|
| Frogs | Swamp mobility, ambush, skirmish | `amphibious` +25% speed on swamp; blowgun skirmishers; lancer on beetle |
| Rats | Cheap swarm, breeds fast | ~30% cheaper units, ~20% faster training, houses +6 pop; cheese brute |
| Beetles/Tortoises | Slow, armoured, defensive economy | (post-MVP) |
| Crows | Scouts and raiders, vision, fragile | (post-MVP) |

Each leans on a different part of the counter system so matchups play differently.

**Theme guards:** signature gear (a culture's kit, cheese hammers) only appears when the prompt,
family or creature asks for it. Humans and centaurs don't become giants unless asked; their large
unit is mounted or "Heavy". Wings on a ridden unit go on the mount (pegasus).

## 9. Multiplayer and sharing

- **Deterministic lockstep** (the classic RTS model): only commands travel, ~200 ms turns,
  commands scheduled 2 turns ahead, state hashes every 30 ticks.
- **Transport:** a Bare sidecar running Hyperswarm/HyperDHT + Protomux, bridged to Godot over a
  localhost WebSocket. NAT traversal and key-addressed matchmaking for free.
- **Sharing races:** the race (recipes + manifest) is a content-addressed bundle in Hyperblobs; the
  key is the share code. Peers fetch manifests and blobs before the match, then lockstep runs on
  identical data. **Share the key** = "play my exact frog war". **Share the prompt** = "roll your
  own"; comparing results is half the fun.
- **Remixes** are new manifests referencing a parent and swapping a few parts, which gives a
  family tree of creations.
- **Live generated events** (later): one peer generates an event ("a heron eats three frogs") and
  broadcasts it as data in the input stream, so every client applies it identically.
- Rule of thumb: **let generation be unpredictable, record what it produced, share the record.**
- Mods are **data-only** (JSON + images). No scripts in shared content.

## 10. Art direction

- **Target the classic 2D isometric RTS look:** small units, 3/4 view, painterly sprites, readable silhouettes, thick
  outlines so overlapping parts read, 3 shades per palette channel.
- Large units must *look* large (≥1.5x height). Spears read as long lines. Team colour sits on a
  consistent region.
- Two facings + mirroring for the MVP (not 8 directions).
- **Procedural animation** on part rigs: walk bob, leg swing (phase offsets for multi-leg),
  breathing, attack lunge, squash and stretch, hit flash, silly death poses, hover for flyers. No
  frame-by-frame animation.
- The current vector shapes are placeholders. The art pass swaps them for one atlas of mask
  textures (R = shade, G = palette channel, B = team mask) and one shared palette shader.
  Sockets, recipes and animation stay the same.

## 11. Tone

Charming, silly, honest. Notes from the generator are jokes, not error messages. Raccoons are
apparently the animal of 2026.

## 12. Non-goals (for now)

Photoreal graphics, 3D, live-service monetisation, battle passes, competitive esports balance,
runtime AI as a requirement, and official third-party IP in shipped content.
