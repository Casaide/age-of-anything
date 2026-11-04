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
- **2026-10-16:** Forest rats in the placement checks: armour centred on rats (every armour sat forward), a rat's banner carried higher, the war boar's riders apart, a sitting cat's seat raised for archers.
- **2026-10-16:** The pad: hold RB opens the selection's wheel as well as tapping A on it (D-139); a worker's wheel opens at the top of its build pages. A new Deck build with heroes and war beasts.
- **2026-10-16:** Save and load (D-140): Save game and Load game in the pause menu, Load game in the lobby, a saves page that works with a pad; a save is a snapshot of the world and the bots (loads in ~0.1 s) with the replay to fall back on; a loaded match plays on hash-identical to one never stopped.
- **2026-10-16:** White boxes on a second match (Deck): the part atlas held every race ever baked and outgrew the GPU's 16384 px; a match now keeps only its own parts, and the atlas is 4096 wide.
- **2026-10-16:** Saves survive game updates without replaying (D-141, Dominic): data merged, new variables padded or fixed by `after_load`; every save kept (~0.4-0.6 MB each).
- **2026-10-16:** A loaded save plays on with this build's stats, units keeping their share of health; one whose buildings or research changed loads on its own (D-142, Dominic).
- **2026-10-16:** The bake stops freezing the screen (D-143): budgeted per frame, image work on threads, async readbacks; a cold match bake's median frame 75 ms -> 8 ms.
- **2026-10-16:** A wall running along y had its near merlons drawn on its far edge (a centred sprite); fixed, and a man's shadow up on a wall shrinks to the walk.
- **2026-10-16:** Unit costs follow their gear's material (D-144): spears food and wood, swords food and gold; portrait concepts (bust, badge) for Dominic.
- **2026-10-16:** Unit portraits are busts with a role glyph; a line upgrade's button shows the unit it gives, in a gold frame (D-145).
- **2026-10-17:** Milestones 5, 13, 14, 16, 19 and 21 closed, their leftovers in the backlog (D-146); the sapper off the tech tree.
- **2026-10-17:** Network play, phase 1: lockstep over ENet, Host and Join on the home network; two windows on the Mac play in step (D-147).
- **2026-10-17:** A saved match on the network: the other player takes over an AI seat (D-148); Dominic's 2v2 save plays in step.
- **2026-10-17:** A prompt can name its hero ("spider widow"): just that one, else all of them (D-149).
- **2026-10-17:** Unit costs: each line has one mix of resources, the same for every race; the parts set only the total (D-150).
- **2026-10-17:** Vikings get their own Norse culture (D-151): bonuses, Berserkergang, the Berserker, the Raven-Feeder, bearded and broad axes, fur, conical and spectacle helms, a longship crest.
- **2026-10-17:** Frogs, rearing beetles and spiders carry their shields slung on their backs; every shield and back piece checked on every body (D-152).
- **2026-10-17:** The centaur's kneel to forage works in all 8 facings (it was side-on only: Dominic saw it from behind); workers are checked at work (D-153).
- **2026-10-17:** Reed Meadow's rivers go shallow, deep, shallow: nobody crosses the deep middle but at fords and bridges (frogs and flyers neither); wood lines reach the map edge; trees block flyers; walls run straight over hills; hill edges bevelled (D-154).
- **2026-10-17:** Milestone 22 starts: formations by role (riders on the flanks), units go for the foes they counter, attack lines for the selection, the Norse shield wall (D-155).
- **2026-10-17:** The network lobby is the battle setup, shared: players join into open sides, pick their team, edit their own race, everyone Ready; 2v2 with AIs on the network; both machines load together (D-156).
- **2026-10-17:** A network match can be saved; the other players' sides go in as AIs (D-157).
- **2026-10-17:** Stone walls stop flyers (palisades don't); flyers are drawn over the buildings they cross instead of through them (D-158).
- **2026-10-18:** One hero a race, not three: the one the prompt names, else the race key's pick (D-159).
- **2026-10-18:** Colour words: "red spiders" are red; spiders come in red, white, yellow and blue too (D-160).
- **2026-10-17:** Bears in play (D-161): brown, black and polar bear races, the bear mount for others ("romans riding bears"), a bear voice; broad bodies fitted through data (D-162), every piece checked on every bear (D-163).
- **2026-10-18:** Towers take garrisons by right-click on their body; feet stay inside wall-tower hoardings; tree shadows lie on the ground, not over roofs.
- **2026-10-18:** Business plan and a website draft: premium on Steam (demo, Next Fest, Early Access), era packs later, never pay-to-win; the home page in the timber look (`docs/business.md`).
- **2026-10-19:** Website draft 3: no Steam button (mailing list only), the prompt is the hero and each prompt shows its whole army; copy reviewed against admired indie pages.
- **2026-10-19:** Website draft 4: alternating text-and-picture rows on what makes the game special, a built rat town behind the title, devlog and email instead of a Steam button.
- **2026-10-19:** Website draft 5: Dominic's sections (army, balance, city, walls, heroes, peoples and twelve cultures, friends, variety, Steam Deck); units re-rendered three-quarter with war beasts and snail catapults.
- **2026-10-19:** Website draft 6: a staged age-3 battle (new `showcase` capture scene), real walls, units facing right, a ticked list of the balance tests, "made by one person and his AI".
- **2026-10-19:** The website built for real (SvelteKit 3 on Cloudflare, `~/Dev/casaide/age-of-anything-website`): home page, markdown devlog, web-playbook SEO and WCAG 2.2 AA, 49 end-to-end and 24 unit tests passing.
- **2026-10-19:** Game icon concepts, round I1 (`docs/concepts/icon/`): a frog crest, the game's own units on a shield, a quill banner, the helm of anything; sheet 16-512 px; Dominic: fun race ones, make them stickers; round I2 (many peoples, kit helm, stitched beast, write it in) and the Discord sticker set; "doesn't stand out", so I2b: bold ink-on-gold marks shown among Discord servers and library tiles; Dominic liked I1's odd helm ("showing the weird generated stuff"), so I3: eight helms worn by a spider, a frog, a rat, a bear, a winged one, the lot, and on gold; "something totally different", so I4: app tiles (a die with creature pips, a frog-headed game piece, a hatching egg, a frog on a rat on a bear); "gradients look dated, look at the genre", so I5: flat icons like the genre's (die on black and gold, helm on red, frog helm); "new direction", so I6: a frog standard, a rat on a bear, a pixel bust, a cheese hammer; then a fresh start from research (80 genre Steam icons: flat, bright fields stand out, faces hold at 16), round N1-N5 in `docs/concepts/icon/fresh/`: selection corners, a flip-book face, a shield wall of odd heads, a parts kit, a pixel frog legionary; Claude recommends the flip book; Dominic to pick.
- **2026-10-19:** The game icon picked (D-164): N4, the parts kit, ink on gold; the website favicon and the Discord server icon.
- **2026-10-19:** A test site on Cloudflare, hidden from search engines; the battle retaken side-on at first contact (no upside-down fallen frogs), wider text columns.
- **2026-10-19:** Frog falls, concept round HF1 (Dominic: dying frogs "look upside down"): A today's flip onto its back, B a topple onto its side, C a belly flop, D the side fall with a kick; Dominic to pick.
- **2026-10-20:** The website on a phone: the army box crossfades at a fixed size, headings before pictures, a centred button, mods highlighted with today and still-to-come lists; mobile layout tests added.
- **2026-10-20:** Frog falls round HF2 (Dominic on HF1: "Just rotating or squishing the image"): the dead frog posed in 3D and baked (`scenes/art_pixel/fall_concepts.gd`): belly up, on its side, face-down sprawl, gear dropped beside it; Dominic to pick.
- **2026-10-20:** The devlog filled in: one post a day from 10-10 to 10-19, in Dominic's voice; whole cards clickable.
- **2026-10-20:** HF2b: the sprawl in its own baked footprint shadow, and lying on its belly for real (limp arms, a slumped body; it had been propped on one hand).
- **2026-10-20:** Link previews: a 1200×630 card per devlog post from its cover (npm run og), the full tag set on every page, checked by a test; the test site's previews work (preview bots allowed, search crawlers not).
- **2026-10-20:** D-165: the frogs die laid down in 3D (the sprawl, baked per recipe with its own shadow); placement rules D1/D2 for corpses; rig3d and geom moved into the game.
- **2026-10-20:** The devlog's RSS feed, tags and topic pages, related posts, breadcrumbs; the website in git with CI and Lighthouse budgets.
- **2026-10-20:** D-166: the dead frog lies turned per facing (round HF3), so no view sees its sprawl end on from behind.
- **2026-10-25:** The Lobster sim spike (branch `worktree-lobster-sim-spike`): the movement path of `src/sim` ported to Lobster matches GDScript on every tick (200 to 2,000 units) and runs about 20-40x faster with `--mir`; found that Godot shares packed arrays, so `World._move`'s tick-start copies are live.
- **2026-10-25:** The Lobster port grows to the whole match: combat, hills, the economy, ages and research, towers, garrisons, healers, heroes and the full bot. A 15-minute bot-vs-bot match runs in Lobster with its own bots, identical to GDScript on every tick, about 15x faster under `--mir` (a Lobster `--mir` miscompile found and worked round).
- **2026-10-26:** "Port it all": every sim system and bot behaviour in Lobster, hash-checked against GDScript (walls, gates, siege, animals, trade, Wonders, the Siege mode, webs...), and a playable Lobster game: Godot bakes the art into a match pack, Lobster draws it, plays it and takes your orders, with sound, a minimap and the bot on the other side.
- **2026-10-26:** Races from prompts and the match start move to Lobster: the generator, pricing, identity, heroes and World setup give GDScript's races and start exactly (69 races, four matches token for token), in a few milliseconds; the Lobster game makes its own races and start, Godot only bakes the art.
- **2026-10-26:** Lobster composes units from baked parts (UnitView ported, Godot's draw lists matched), any race draws from a part library (90,000 bakes), the lobby takes typed races and balances them by fights before the match (about 5 s), and a race can become another mid-match; the ground shader ported.
- **2026-10-26:** The Lobster game grows the rest of the game around the port: paths, combat effects, the living town, save and load, network play over TCP, pad play, game modes, mods, the tech tree, the Race Lab with rerolls, and a UI layer in the timber look for the lobby, the panel and the menus.
- **2026-10-26:** The Lobster game no longer needs Godot to play: every model built and baked in Lobster (each held to Godot's triangles), the pack's tables from data, the UI and controls after Godot's, mods' code parts in Lobster too.
- **2026-10-27:** The Lobster game reads nothing Godot made (textures by rsvg-convert, maps from data); a new army mid-match works with no pack (bears completed as Godot does); the tech tree says what research does; LB on the pad as in Godot.
- **2026-10-26:** Art-quality study AQ1 (concepts, not in the game): higher resolution (1.5x/2x behind `AOW_ART_SCALE`), buildings breaking up in baked stages with pixel dust, deaths laid down in 3D and a follow-through hold, sci-fi energy shots four ways; Dominic to pick (`docs/concepts/art-quality/`).
- **2026-10-26:** Dominic on AQ1: fidelity of units and buildings is a key goal; "Destruction looks great" (D-171, building waits on his go-ahead); the study's energy shots now leave the rifle's muzzle (the game still launches every shot from the body).
- **2026-10-26:** D-172: go-ahead on destruction; a ruin is decoration only, can be built over and fades away (Dominic: "Destruction is for looking cool not game mechanic").
- **2026-10-26:** Destruction built (D-171/D-172): buildings show broken-up baked stages as they lose hp, fall under pixel dust, and leave a ruin that fades or is built over.
- **2026-10-26:** Fidelity round F1: rendering alone (smooth, 2x) does not make units less cartoony, the models do; a realistic legionary modelled in Blender (7 and 5.5 heads) baked beside today's; Dominic to pick.
- **2026-10-27:** Milestone 23 step 2b: wool tunics, team colour on sash/hem/shield (D-175), Blender galea and scutum, banners only when asked (D-174), the walled howdah (D-176); round F2 (rats and frogs) for Dominic to pick.
- **2026-10-27:** Rat B picked (D-177); animation study A2: today's pendulum walks vs rat B keyed in 3D (walk, thrust); options A/B/C, B recommended.
- **2026-10-27:** D-178: frog B picked (the frogs rebuilt as frogs).
- **2026-10-27:** D-178 frog B, D-179 animation by keyed limbs; the rat as a rat is built (Blender trunk and head, legs baked in 8 knee-bent walk steps).
- **2026-10-27:** Rat armour RA1: all seven armours modelled for the rat's own trunk (no more scaled human jerkin as a band round its middle).
- **2026-10-27:** D-180: capes only when asked (or the royal culture's); units baked at the size they're drawn (no more blocky sheep and giants).
- **2026-10-28:** Frog B built: Blender trunk and head, legs keyed in 8 hop phases, fitted armour; the rat's head nods and blows wind up and hold (D-179, D-181).
- **2026-10-28:** The heroic humans walk on keyed legs, bent at knee and ankle; three placement fixtures that no longer caught their bugs fixed (D-179).
- **2026-10-28:** D-184: Godot retired. The art study ported to Lobster and held to Godot's, the lobby and front end ported, the Godot tests ported to Lobster, then the GDScript game deleted and the Lobster game moved to `src/` (`./play.sh`, `./tests/batch.sh`).
- **2026-10-29:** The Android build (`src/android/build.sh`): the game compiled to C++ into Lobster's SDL template, an APK that runs title, setup and a match on the emulator. D-185: buildings and props baked once and shipped (`src/prebake.sh`), unit parts baked on the GPU (67 s -> 9 s for two races).
- **2026-10-29 (afternoon):** What the port lost, back: WASD panning, order lines, Music and Sound volumes, the HUD's size, Start's loader at once; the unit views' leaks fixed (0 at exit).
- **2026-10-29 (evening):** Match starts bake only the starting age (D-186) behind one loader; hills under the fog; walls dragged in lines again; touch places with a tap; the Android fixes offered to Lobster as one PR.
- **2026-10-30:** The game's icon is the parts kit (D-187): on Android, the Mac's Dock (`gl.window_icon` in the Lobster fork) and the Deck; the boot screen shows it in gold on the wood.
- **2026-10-31:** The walk no longer skips (each foot on its own line), the chop quicker with the axe in the hand, the match start no longer drawn at a bake's scale
- **2026-10-31 (night):** A performance check in the real window (D-188): it found the HUD making 1,500 GPU buffers a frame; `gl.draw_mesh` draws from pooled buffers, and a frame takes 3.3 ms of work instead of 13.7.
- **2026-10-31:** The bears are one shaped body, not balls (D-189, B4 option A), and the lump behind their necks is gone.
- **2026-11-03:** The laptop still ran hot: sprites drawn from atlas pages, the HUD's fills batched, the lobby at 30 frames a second (D-194); a match's frame 1.9 -> 1.1 ms of work, the idle title 9% -> 3.5% of a core.
- **2026-11-03:** Prices are fixed per unit, calibrated offline by fights (D-195): a match loads without balance fights (7 to 38 s before), and held-out lines more than 10 points off the mean went from 57% to 24%.
- **2026-11-03 (later):** Text drawn from atlas pages (0.24 -> 0.03 ms a frame), the idle title at 15 frames a second, a window in the background at 10 (`gl.window_focused`, 13-19% -> 4.7% CPU), Lobster's frame cap in one sleep (D-197).
- **2026-11-03:** Bots press home a clear lead (D-198): they mass, push at the Town Centers with rams and reinforce; bot against bot ends at 20:56 instead of no winner at 30:00, and test_ai asks a clear leader to win within 12 minutes.
- **2026-11-03:** The tech tree page ported from the Godot one: the race panel with its army, the age rail, building columns with portraits and icons joined by lines, the hover card, the match's progress; its pictures painted once into one page and drawn in one mesh.
- **2026-11-03:** Counters keep their edge (D-199): prices fitted against the counter chain, swords +6 against spears, the heavy line +6 against ranged; every counter pair wins at least 70% of its equal-cost fights.
- **2026-11-03:** Prices fitted with the armoury on and a lean calibration (D-200): 19,800 fights in 67 s, every fight kept so a change of rule refits in 0.2 s; each upgrade's effect measured.
- **2026-11-03:** Voxel units are the default (D-201): the start age's looks baked in 2 s, the rest in play a slice of a frame at a time, deaths that fall and lie, deer, boar and sheep, voxel portraits; engines with a crew still composed; `composed` brings the old units back.
- **2026-11-03:** Two more songs: "Hearth" (calm, in three, G Mixolydian) for building and "March" (tense, E Phrygian) for long fights, in the theme's stems; the game rotates the calm pieces and brings the march in after 25 s of fighting.
- **2026-11-03:** The composed units removed (D-202): voxel engines and war beasts with their crews, the lobby voxel, then the composer, part baker, unit models, placement check, sheet tool and mods' Lobster models out (about 27,000 lines); the quick batch 100 s -> 25 s.
- **2026-11-03:** Voxel buildings decided (D-203): the models voxelized for coverage, voxel data culture by culture after; milestone 24.
- **2026-11-03:** The lobby and HUD checked against the Godot game: the lobby back at Godot's size (76% of the window) and type (spaced captions, bold buttons), the match loader and pause menu redrawn as Godot's (the menu sized to its contents, its danger group set apart), the UI's materials at Godot's finer grain with metal's scratches the right way round, the opening tips back.
- **2026-11-03:** Milestone 24: every building, stage, wall, gate and prop voxelized, the old baker removed (D-208); walls baked whole per tile, gates sorted piece by piece and opening at last; perf 1.0 ms median.
- **2026-11-04:** The still ground is drawn once into a picture and redrawn at 15 Hz for the water: GPU power cut by more than half in a match (D-209).
- 2026-11-04: Clean Lobster fork (`game` branch), issues first, the backlog in GitHub issues; Android runs a match on it again.
