# SW1: siege engines (2026-10-13), waiting on Dominic

Milestone 13's siege concept round. Each engine is shown in five family takes and two directions,
baked like unit parts (8-facing pipeline, three facings shown), with the race's worker beside it
for size. `*_3x.png` is the close-up; `*_1x.png` is the game's scale (one art pixel per screen
pixel). Models: `scenes/art_pixel/siege_concepts.gd` (nothing in play). Sheet:

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet.gd -- out_dir 1.5   # game scale
```

**Direction A, the engine alone:** one baked sprite; the crew is hidden (ram) or implied. Moves
and dies as one thing, like the genre's engines. Cheap to draw.
**Direction B, the crew shows:** the race's own units push, pull or aim it, composed by the view
on the engine's sockets (two beside a ram, two pulling a flinger, one aiming a bolt thrower).

| Engine | A | B |
|---|---|---|
| Ram | covered shed, eaves nearly to the ground, the head out in front | open ram hung from two A-frames, crew walking alongside; forest: a rhinoceros beetle pushes the log |
| Catapult | arm-and-cup engine on wheels, arm up against a padded crossbar, cup loaded | tall pole flinger, the sling on the ground behind, two crew pulling the ropes |
| Bolt thrower | big crossbow on a two-wheeled carriage with a trail, like a field gun | lighter crossbow on a tripod, a crew member behind it aiming |

**Family takes** (the same in both directions where they apply):
- **Humans (timber, every culture):** timber and iron, spoked wheels, a hide roof with battens;
  culture trim is a hem in the culture's cloth along the eaves (imperial red shown). Iron ram cap,
  a stone in the cup, an iron-headed bolt.
- **Frogs (swamp):** lily-pad sledges on reed runners instead of wheels; the ram's shed is three
  lily pads like scales, the log a reed bundle with a river stone lashed on; a reed arm with a snail
  shell cup and a mud ball; a reed bow with a thorn bolt.
- **Rats (sewer):** bottle-cap wheels; the shed an upturned sardine tin with its key-rolled lid
  and printed label; the ram a sharpened pencil; a spoon catapult throwing cheese; a bottle-cap
  sling pouch; a wire bow shooting a knitting needle.
- **Beetles (forest):** log-slice wheels; a mossy shed with a leaf fringe and acorn caps; a
  beetle-horn ram head; a bent twig arm with an acorn cup; a thorn bolt.
- **Spiders (spooky):** dark wood, bone spokes and bone ribs over dark hide, a skull ram head, a
  femur arm with a skull cup throwing a ball of web, a rib bow strung with silk.

**Team colour:** a small cloth on each engine: a drape over the ram's ridge (a rag on the tin,
a leaf banner), the catapult's crossbar pad, a cloth on the bolt thrower's trail, pennants on the
frogs' engines. In B the crew's own kerchiefs carry it too.

**What reads at game scale (Claude's look):**
- The open ram (B) reads as a ram at 1x better than the shed (A): the log is the silhouette. The
  shed reads as "a covered wagon with a point" for humans; the frogs' pads and the rats' pencil
  read at once.
- The arm-and-cup catapult (A) reads as a catapult in every facing. The pole flinger (B) reads as
  siege but is wide, and its crew cover the base.
- The bolt thrower on wheels (A) is small and busy at 1x; the tripod (B) needs its gunner to read.
- Frog crews are big (the crouched frog): in B they cover their engine.
- The rats' sardine tin bakes very pale on top; if picked it wants a darker tin.

**Claude's recommendation:** ram **B** (open, crew alongside; the forest's beetle-pushed ram is
the showpiece), catapult **A** (arm-and-cup, one sprite), bolt thrower **A** (wheeled carriage, made
a touch bigger). That is: crews where they make the silhouette (a ram is a log carried by
people), one sprite where the machine makes it. Every family take as shown, with the timber
engines shared by the human cultures and trimmed in their cloth.

**For Dominic to pick:**
1. Per engine, A or B (or B everywhere, if the crews are the charm).
2. The forest ram: beetle-pushed for beetles (and other forest races), or crew like the rest?
3. Any family take to redo (the rats' tin shed, the frogs' reed bundle...).
4. Size: the engines are about 1.3x (ram) to 1.6x (catapult) a soldier's length. Bigger?

## Round 2 (2026-10-13), waiting on Dominic

Dominic on round 1: "Rats using pencils? I think we need to accept them as human sized rats"
(D-116); the forest ram "better as a giant beetle?" (yes, D-117); "I like crews very much" (D-118:
every engine shows its crew). `siege_r2_<engine>_3x.png` and `_1x.png`; a "for size" column (the
race's worker; for the beetles also a cavalry beetle), then three facings.

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r2.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r2.gd -- out_dir 1.5   # game scale
```

**Size:** the engines are grown to their crew, the race's ordinary worker at true scale: the open
ram's log at chest height (1.5x round 1), the catapult's frame at the shoulder (1.8x of the
soldier-scale build), the bolt thrower's stock at the chest (2.1x). The frog worker really is that
big (as tall as a human, twice as wide), so frog engines are 1.25x more, not the frogs smaller.

**Crews:** sockets on the engine name how each crew member stands: `crew<n>_f<k>[_reach|_raise][_in|_top]`
(turned k facings from the engine, the arm hold, drawn inside the frame or riding on top). The ram's
crew swing the log from inside the frame (the frame and log draw over them), a third shoves at the back;
the catapult is wound from behind and loaded from the side, with an ammunition pile; the bolt thrower
is aimed from the trail and loaded beside it. Crews stand behind the machine, so arm, cup and bow
keep their silhouette; in the facing where the rear is towards the camera they stand in front of the
frame, but the arm still stands above them.

**Rats, from the sewer's own junk at human scale:** grimy, patched, mismatched, riveted. Scrap
timber in three tints, grey iron pipe, rusted plate, chains, barrel hoops, cart wheels that don't
match (spoked at the back, a plank disc at the front).
- Covered ram: a roof like half a barrel (staves under three iron hoops, rusted plates riveted over
  the gaps), a sewer grate standing in front as a shield, the head poking out under it, two rats
  shoving at poles out the back.
- Open ram: iron pipe A-frames with elbow joints, the log on chains, a scrap beam in barrel hoops
  with a plank nailed on and a flanged pipe-end for a head; a rag tied on the top pipe.
- Catapult: plank and timber rails, pipe uprights braced with iron strip, a rope-and-chain skein, an
  iron-banded scrap arm, an iron bucket for the cup with a wedge of cheese, a hand-wheel winch.
- Bolt thrower: a spoked wheel and a smaller plank one, a pipe trail, leaf-spring arms (three
  strips each), an iron-rod bolt with tin fins, a sewer grate as the gun shield under the bow.

**Forest: a giant rhinoceros beetle** (D-117). Glossy mahogany wing cases (darker than the purple
beetle crew, so beast and riders part at 1x), a bark-plate cap with an iron rim and studs on its
pronotum, a long head horn reaching forward with an iron cap and band, and a thoracic horn curving
over it like pincers; low on thick, splayed legs. About 2.5 times a cavalry beetle's length.
- Ridden: a howdah on its back, two beetle riders (the front one driving), team cloth down the sides
  and a pennant at the back.
- Led: a team saddle cloth over its back, a lead rope from the horn to a handler walking ahead, a
  second handler behind with a goad.

**Humans and frogs, for comparison:** round 1's picks, crewed and grown: the open ram (B), the
arm-and-cup catapult and the carriage bolt thrower (A).

**What reads at game scale (Claude's look):** every ram reads; the giant beetle most of all, a beast
first with its team colour only in the cloth. The rats' engines are clearly theirs (grey pipe and
rust against the humans' clean timber and iron) without any tiny objects. The catapult reads in
every facing. The bolt thrower is still the weakest at 1x; its crew help.

**Claude's recommendation:** rats: the open ram (pipes and chains), like every other family's ram
and with its crew showing; the barrel shed is the better object and could be a later covered-ram
upgrade. Forest: the **ridden** beetle (riders make it a war beast, not a wild one, in every
facing). Catapult and bolt thrower crewed as shown, frog engines grown rather than frogs shrunk.

**For Dominic to pick:**
1. Rats: open ram or barrel shed (or the shed as an upgrade).
2. Giant beetle: ridden or led.
3. Size: the engines now stand to their crew (the ram is about two workers long). Right?
4. Anything to redo before building (the bolt thrower at 1x?).

## Round 3: the frogs (2026-10-13), picked: B's turtle ram and toad bolt thrower (D-121)

Dominic on round 2's frog engines: "I think frogs for all are the weakpoint, overusing lilypads and
stuff, I think need to rethink direction" (D-119). Three new directions, each with a ram, a catapult
and a bolt thrower, all crewed by the frog worker at true scale (as tall as a human, twice as wide;
the engines are built at their full size around that crew). No lily pads anywhere. The humans' picked
engines head every sheet for size. `siege_r3_directions_*` puts every engine of every direction side
by side in one facing; `siege_r3_<engine>_*` shows three facings. `_3x` close-up, `_1x` game scale.

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r3.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r3.gd -- out_dir 1.5   # game scale
```

**A, reed and clay engineers:** the frogs' own building culture (their reed towns: dark stilt timber,
golden thatch, wicker walls, daub). Every engine sits on a heavy timber sledge with curled runners.
- Ram: A-frames of lashed golden reed bundles under a small gabled thatch roof, the log a fat reed
  bundle tied with dark lashing, its head a fired-clay weight studded with river stones; team cloths
  hang from the ridge. Two frogs swing it from inside, one shoves at the back.
- Catapult: reed-bundle uprights and braces, a skein of twisted reed rope between two daub blocks, a
  tapered reed arm with a wicker cup holding a fired-clay ball; team pad on the crossbar.
- Bolt thrower: a heavy stock on a lashed timber trestle, bow arms of bent reed bundles, a sharpened
  reed spear with a fire-hardened point, and a woven wicker mantlet in front with a team cloth on it.

**B, living swamp beasts** (as the forest has its giant beetle):
- Ram: a giant snapping turtle, high ridged shell with three keels of knobs and a saw-toothed rim, a
  long neck, a hooked beak under a stone brow plate, a spiked tail. One frog drives from a wicker
  basket on its back, one walks behind; team cloths drape over the shell.
- Catapult: a giant newt (black, an orange belly, yellow spots) with a deck strapped to its back
  carrying a reed-armed catapult; one frog rides behind the arm, one loads from beside it.
- Bolt thrower: a giant warty toad, gold-eyed, wide-mouthed, a team saddle cloth and a reed-bow bolt
  thrower on a post on its back; one frog aims from its rump, one loads from beside it.

**C, river engines:** amphibious, so their engines are boats dragged through the shallows, with
fishing gear for technology.
- Ram: a planked boat, the log hung from two pairs of crossed punt poles, its head a river stone in a
  net; eel traps in the stern, a net with cork floats over the side. The crew haul from inside the
  boat (only their heads show), one shoves at the stern.
- Catapult: a swing beam on a post in a boat: a wicker basket of river stones raised on the short
  end, a net of stones lying in the stern on the long end, ready to sling.
- Bolt thrower: a harpoon thrower on a post at the bow, a barbed bone harpoon, its line coiled in a
  basket; eel traps and a net.

**What reads at game scale (Claude's look):**
- A reads best of the three: golden reed against the red (or any) frog skin, so crew and engine part
  at once; the thatch roof, the stone-headed log, the tall arm with its clay ball and the wicker
  mantlet each say ram, catapult, bolt thrower in every facing. It looks like it came out of their
  town, and it sits beside the human engines as the same kind of thing.
- B: the turtle reads as a turtle and is a strong beast (grey-green and round, nothing like the
  mahogany, long-horned beetle). The newt reads, the catapult arm stands clear of it. The toad is
  the weakest: a big brown frog carrying small frogs, and its bow is small against the body.
- C: the boats read as boats, and the harpoon is the clearest bolt thrower of all three. The swing
  beam catapult reads as a crane more than a catapult in some facings; boats on dry land are a
  stretch away from water.

**Claude's recommendation:** **A** for all three engines: it is the frogs' own building culture, the
most readable at 1x, and matches the crewed timber engines the other families got. Keep the **turtle**
(B) in mind as a later showpiece, e.g. an age-4 heavy ram or a unique unit, the way the forest has
its beetle; the newt and toad are not needed. C's harpoon boat could come back if water maps arrive.

**For Dominic to pick:**
1. A direction (or a mix per engine: e.g. A's catapult and bolt thrower with the turtle as the ram).
2. The thatch roof over the reed ram: keep it, or open like the others?
3. Size: the frog engines are about 1.2 to 1.3 times the human ones, to fit their crew. Right?

## Round 4: the newt as cavalry, other frog catapults (2026-10-13), waiting on Dominic

Dominic picked round 3's B for the frogs ("swamp beasts, looks great": the snapping turtle ram and
the toad-borne bolt thrower, D-121) but: "Salamander I'm not 100% sure, I wonder if better for
cavalry?", and then: "catapult on snail maybe?". Two questions, concepts only.

### 1. The giant newt as the frogs' cavalry mount

`newt_cavalry_facings_*` shows each mount in all eight facings with a worker for size;
`newt_cavalry_walk_*` a walk cycle (four steps in two facings). Rows: a human on a pony, today's
frog on a beetle, then the frog lancer on the newt in three colourings. `_3x` close-up, `_1x` game scale.

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/newt_cavalry_sheet.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/newt_cavalry_sheet.gd -- out_dir 1.5   # game scale
```

The newt is a real mount in the real pipeline: a body, a head and four legs baked apart in eight
facings and composed by UnitView like the beetle (the seat, the rider's near leg down its flank, the
legs walking on their anchors). Its parts are in `scenes/art_pixel/newt_concepts.gd`; the sheet puts
them into the loaded data for the run only (the beetle's entries under the newt's ids), so nothing in
`data/` changes and nothing is in play.
- A long, low trunk in three lobes, a pale belly, a long tail flattened side to side like a newt's
  paddle and curving a little, short sprawling legs (elbows out, a splayed four-toed hand), a broad
  flat head with small gold-ringed eyes high on its sides and a long closed mouth. Wet and glossy.
- Built a fifth bigger than first sketched and low, so the big frog sits on it rather than over it:
  its saddle is at about a beetle's height, the trunk about a pony's length, the tail as long again.
- Tack: a team saddle cloth hanging down both flanks, a reed-bundle saddle roll behind the seat, the
  harness every unarmed mount has (girth, lance holder, shield pad), a team browband and a noseband.
- Colourings: **fire** (black, an orange belly, yellow spots: round 3's), **red eft** (orange-red,
  red spots ringed in black), **crested** (dark olive-brown, black spots, an orange belly and a
  jagged crest down the tail).

What reads at game scale (Claude's look): a rider on a lizard-like beast in every facing; it walks
with the legs the view already animates. The fire newt reads best: black and yellow stand apart from
every frog skin and from the green field. The eft reads too, but a red frog on it would merge (the
sheet's frogs are brown). The crested one is muddy at 1x. The tail makes it the longest cavalry
(about twice the beetle's length, nose to tail); a shorter tail would be easy if that's a problem.

### 2. Other catapults for the frogs (to replace the newt-borne one)

`siege_r4_catapult_*`: the humans' catapult and round 3's newt for comparison, then four options,
three facings each, crewed. `siege_r4_bolt_*`: round 3's toad bolt thrower (picked) and the turtle
carrying it instead (the other half of a swap). `siege_r4_sets_*`: the whole frog siege per proposal
in one facing, beside the humans'. Models in the round-4 section of `scenes/art_pixel/siege_concepts.gd`.

```sh
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r4.gd -- out_dir 4.5   # 3x
godot --audio-driver Dummy --always-on-top --path . --script res://tests/siege_concept_sheet_r4.gd -- out_dir 1.5   # game scale
```

1. **Snail** (Dominic's idea): a giant swamp snail: a long wet foot with a frilled pale edge, its head
   raised on a neck with two long eye stalks (glossy black eyes with a glint) and two short feelers,
   a big shell coiled flat like a ram's horn so its spiral shows from the side (amber, each turn
   darker towards the middle, dark growth bands, a dark seam along the coil, a pale lip at the mouth).
   A timber deck sits on the shell's top, roped down to the foot, with the team cloth along its
   edges and round 3's reed catapult on it. One frog rides behind the arm winding, one loads from
   the far side with a basket of clay shot.
2. **Toad** (a swap): round 3's giant toad carrying the catapult on a deck, the turtle then carrying
   the bolt thrower (`siege_r4_bolt_*`).
3. **A bigger snapping turtle** (a quarter larger than the ram's) with the catapult on a deck.
4. **Hauled**: round 3's reed and clay catapult on its sledge, pulled on two traces by the snapping
   turtle with a driver riding it, the catapult's own crew behind.

Not tried: a giant heron. A wading bird on stilt legs makes a tall thin silhouette that doesn't read
as something carrying a load, and herons eat frogs.

What reads at game scale (Claude's look):
- The snail reads as a snail first (the coil and the eye stalks) and a catapult second (the arm and
  the clay ball over the deck) in all three facings. It is nothing like the turtle ram: tan, wet and
  legless with an amber coil against a grey-green dome on four thick legs. Slow and heavy suits a
  catapult. Weak points: seen from straight ahead or behind the shell is edge-on and looks more like
  a jar; it's the tallest engine (the arm's top about 1.4 times the human catapult's).
- The toad catapult reads, but it's still the round-3 problem: a big frog carrying frogs. The turtle
  bolt thrower reads well, but the turtle would then be the ram and the bolt thrower both.
- The bigger turtle reads as a catapult, but two turtles of two sizes blur ram and catapult.
- The hauled catapult reads as a catapult and a turtle, but it's a cart, not a beast engine; it's
  the longest thing on the sheet (two engines' length) and the turtle hides the crew in some facings.

**Claude's recommendation:**
1. Yes to the newt as the frogs' cavalry, in the **fire** colouring (the swamp family's mount instead
   of the beetle, which stays the forest's). As a later design note, it could be amphibious like the
   frogs (movement classes exist), which would give it a reason beyond looks.
2. The **snail** for the catapult, with the turtle ram and the toad bolt thrower as picked: three
   different beasts, each one readable, and the slowest one throws the rocks. If the height bothers,
   the arm can come down a little.

**For Dominic to pick:**
1. The newt as cavalry: yes or no; which colouring; the tail as is or shorter.
2. The catapult: snail, toad (with the turtle taking the bolt thrower), the big turtle, or the hauled
   reed catapult.
