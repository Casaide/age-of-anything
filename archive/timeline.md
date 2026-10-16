# Timeline

One line per moment worth remembering. Newest at the bottom.

- **2026-10-10:** Started as a chat about the state of game dev (indie up, AAA struggling, RAM
  prices, Godot rising). Ended up designing an RTS.
- **2026-10-10:** The idea: a classic RTS, but players make their own races, maybe with AI.
- **2026-10-10:** Pivot: parts kit + deterministic NLP instead of runtime AI. Frogs vs Rats is born.
- **2026-10-10:** Named **Age of Whatever**.
- **2026-10-10:** Milestone 0: Race Lab runs. First render of Frogs vs Rats.
  ([image](images/2026-10-10/01-frogs-vs-rats-first-render.png))
- **2026-10-10:** Centaur Romans vs winged Greeks works.
  ([image](images/2026-10-10/02-centaur-romans-vs-winged-greeks.png))
- **2026-10-10:** First great bug: a giant Roman with a cheese hammer.
  ([image](images/2026-10-10/03-bug-giant-cheesehammer-roman.png))
- **2026-10-10:** Fixed: Heavy centaurs, pegasus lancers, archers added, full classic RTS roster mapped.
  ([image](images/2026-10-10/04-heavy-centaurs-and-pegasus.png))
- **2026-10-10:** Milestone 1, sim core: integer 20 Hz sim, command queue, replays, state hashes.
  A 10-minute 200-unit match hashes identically every time; tick 0.9 ms. Frogs and rats meet by the pond.
  ([image](images/2026-10-10/05-sim-core-frogs-meet-rats.png))
- **2026-10-10:** Milestones get their own files (`docs/milestones/`).
- **2026-10-11:** Milestone 2, map + movement: flow fields, move groups, the first isometric view.
  50 units cross a chokepoint with nobody stuck.
  ([image](images/2026-10-11/01-isometric-frogs-meet-rats.png))
- **2026-10-11:** Milestone 3, economy: frogs gather bugs and cut reeds, houses go up, rats
  out-breed everyone. Press F6 and the bots play the opening.
  ([image](images/2026-10-11/07-opening-minute-3.png))
- **2026-10-11:** Art pass, step 1: one scene, five styles (storybook, paper, painterly, toy 3D,
  pixel). The 3D shadows were hiding behind their owners.
  ([image](images/2026-10-11/08-style-sampler-all.png))
- **2026-10-11:** "You're testing rendering, not art direction." A sixth style, high-fidelity
  pre-rendered: detailed 3D baked to sprites, with waving banners and smoking chimneys.
  ([image](images/2026-10-11/15-style-hifi-prerendered.png))
- **2026-10-11:** Back to pixels: the original frogs and rats, baked from auto-3D parts into
  pixel sprites, beside a round pond with no grid in sight.
  ([image](images/2026-10-11/16-pixel-hifi-2x.png))
- **2026-10-11:** Frogs get two legs, toe pads and amber eyes; rats get whiskers and bottle-cap
  shields: hand-modelled parts with hand-drawn textures. A frog stops standing on a hut roof.
  ([image](images/2026-10-11/21-pixel-modelled-units-2x.png))
- **2026-10-11:** Cultures pave their own way: frog boardwalks, rat cobbles, Roman roads,
  all generated. Arms get outlines; a rat rides a spider.
  ([image](images/2026-10-11/26-roman-roads.png))
- **2026-10-11:** Rats move into tin cans and a scrap-built Town Center; boardwalk boards finally
  lie across the walk; one 256-colour palette for the whole frame.
  ([image](images/2026-10-11/29-rat-junk-town-and-fixed-boardwalk.png))
- **2026-10-11:** Groundwork: one atlas, one material, team colour from a shader. 211 units in
  20 draw calls. ([image](images/2026-10-11/30-one-atlas-19-draw-calls.png))
- **2026-10-11:** Landscape pass: rolling grass, a deeper pond with wavelets and lilies, cattail
  reeds, leafy bug bushes, thatch in courses, contact shadows.
  ([image](images/2026-10-11/32-landscape-pass-2x.png))
- **2026-10-11:** Every race modelled: people, ponies, centaurs, beetles, wings and metal-age
  gear. Romans build columned halls and villas, the steppe pitches felt tents.
  ([image](images/2026-10-11/40-stone-culture-temple-hall-and-villas.png))
- **2026-10-11:** An independent art review; every unit now shows its team, building materials
  are authored, houses grow and fly pennants.
  ([image](images/2026-10-11/45-authored-building-textures-and-house-pennants.png))
- **2026-10-11:** Vertical slice: the playable debug match runs in the pixel art, with culture
  buildings, paths and props built from the sim's map.
  ([image](images/2026-10-11/48-vertical-slice-centaurs-vs-steppe-riders.png))
- **2026-10-11:** Combat: armour classes, attack-move that spreads into duels, projectiles and
  toppling dead. ([image](images/2026-10-11/51-first-battle-frogs-vs-centaur-romans.png))
- **2026-10-11:** Milestone 6, foundations: resources from data (stone), flyers and amphibians,
  teams, farms and paddies, shift-queues, and unit lines that change kit as you age up.
  ([image](images/2026-10-11/56-centaur-romans-age-3-galea-scutum-lorica.png))
- **2026-10-11:** Milestone 7, progression: Barracks, Stables and Watchtowers in every culture's
  style; the bot ages up at 4-6 minutes. ([image](images/2026-10-11/57-rat-town-barracks-stable-watchtower.png))
- **2026-10-11:** Units get real textures: mapped in world space, big-marked and generated.
  ([image](images/2026-10-11/89-unit-textures-frogs-and-beetles.png))
- **2026-10-11:** Frogs build reed domes on stilts, bugs dig earth mounds: architecture by
  creature. ([image](images/2026-10-11/96-beetle-mound-town.png))
- **2026-10-11:** Unit art goes concept-first: a concept sheet tool and the first round (age-1
  head gear), waiting on Dominic's picks.
- **2026-10-11:** Milestone 8 built: an AI that builds, counter-picks and attacks in waves; a
  match setup screen; victory and defeat. ([image](images/2026-10-11/101-ai-rats-raid-the-frog-town.png))
- **2026-10-11:** Milestone 9 done: fog of war, minimap, placeholder sounds; bot matches run
  about 11 minutes. ([image](images/2026-10-11/102-fog-of-war-edge.png))
- **2026-10-11:** Milestone 10 prepared: balance tool and pass 1 (counters 91%), workers at one
  price, playtest kit; waiting on testers.
- **2026-10-11:** Playtest fixes: clickable train buttons, whole-figure unit picking, smooth
  foraging; farms are one walkable, reseedable thing; rally flags.
- **2026-10-11:** The slim rat confirmed (D-083); its armour refitted to the chest. Concept rounds
  RB1 (large rat) and BG1 (beetle posture) waiting on picks.
- **2026-10-11:** Rat junk kit in the game (D-084). Dominic closed milestones 8 and 10 "for now"
  (their open items moved to the backlog) and added milestone 11, cleanup.
- **2026-10-11:** Human shoulders narrower; SG1 spider postures sent for a pick; the Fable second pass's open polish done (cost icons, tips, Becomes, boar, mills, cursors, swamp, quarry).
- **2026-10-11:** Faces lose the stubble band; culture skins; riders' legs; centaur chest; Blender human leg and fitted leather and bronze armour; GC1 gear concepts for Nile, Han, Aztec.
- **2026-10-11:** Dominic's picks in: reared spiders (D-099), Nile/Han/Aztec kits from age 1 (D-098). Milestone 11 done.
- **2026-10-11:** Dominic's match notes: per-line upgrades (D-100), age-2 buildings (D-101), queued foundations, camp gathering, sheep home, age badge, path planning off the main thread.
- **2026-10-11:** Sound from the ground up (D-103): our own offline synth renders every effect, creature voices and the theme "Whatever" in stems by age, with a battle layer; `docs/audio.md`.
- **2026-10-11:** Milestone 12 planned: the full land tech tree as data and a tech tree page (D-106); build menu in civilian and military pages, stone walls to age 2, sheep stolen not killed, small bushes and a farming bot (D-107).
- **2026-10-11:** Pathing pass (D-104): stuck is net progress; no teleports; body-wide line checks; the choke map out of the lobby; `tests/path_audit.gd`.
- **2026-10-12:** Animation review (work invisible, cardboard deaths, weapon-twitch attacks) and concept sheets: workers' baked arm poses, the centaur kneel, head-digging for armless creatures. Dominic's pick pending.
- **2026-10-12:** Dominic picked W1, C1, A1 (D-105): baked work holds for the arm, the centaur kneel, head-digging for armless creatures; built.
- **2026-10-12:** Concept round two: attacks (step-in, swing, as now; draw and loose) and deaths (topple, crumple, by shape). Pick pending.
- **2026-10-12:** Dominic picked T1, R1, D3 (D-106): the lunge, the release snap, deaths by body shape; built.
- **2026-10-12:** Playtest fixes by parallel agents (stances, towers, drop-off, hunting bot, UI scale, research queue, order routes, fog memory, one farmer per farm; D-108); walls and 3-tile gates (D-109); three ages, a healer, age 4 and the Temple parked (D-110); research effects and icons (D-111); Reed Meadow 64 and 88 (D-112); milestones 13-19 planned (D-113); the lobby's dice (D-114); renamed "Age of Anything" (D-115).
- **2026-10-13:** Playtest fixes (riders' legs, the panel in one row, the pilum, the bell, no chasing into the fog, faces with brows, double-click building groups, the stone gate, the AI breaking walls); arrows fly and can miss; healers slower and still; milestones 12 and 15 closed for now, 17 done, the UI's timber look approved; milestone 13 starts with siege: two concept rounds, crews on every engine, rats human-sized, the forest ram a giant beetle (D-116 to D-119).
- **2026-10-14:** Placement and group checks for unit art; tests in parallel and faster bakes; swordsmen, scouts, horse archers, unique units, trade carts, war beasts and the great sling; rats on cats, the frog hop; six bonuses per race and race balance; walls you stand on, tall walls, siege modes; Old Forest opened up; modding milestone planned (D-116 to D-131). Heroes paused on a branch.
- **2026-10-15:** The pad: a reticle, the selection circle, one button per order, the RB wheel of the panel's own buttons, pad focus in every menu, a fake-pad check that plays it (D-132). Next: the Steam Deck build.  First run on the Deck: UI fitted to 1280 x 800, art and sound packed into exports, the wheel on a tap of A (D-133).
- **2026-10-16:** The war beasts walk: legs baked per hip and heads at the neck, a gait, a blow and a fall of their own for the elephant, boar, tarantula, heron and mantis; riders thrown clear; the placement check walks each beast (D-136). Then bent knees: jointed legs baked per walk step (D-137, Dominic).
- **2026-10-16:** Heroes resumed and finished (D-138): every race gets all of its heroes (3 or 4), one of each out at a time; Town Center buttons, a crown, the tech tree and lobby, their own sounds; every hero look fits every body (drape sockets, low-slung hats); priced as a share of their swordsman.
