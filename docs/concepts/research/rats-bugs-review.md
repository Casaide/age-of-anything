# Rats, beetles and spiders: design review (2026-10-11)

A review agent judged both races against the five rules (direction.md) and the psychology rule,
at every age. Renders were made in a scratch folder; nothing in the repo changed.

## The three big problems
1. **Bugs are mount bodies used as infantry.** `body.beetle` / `body.spider` are horizontal mount
   bodies (harness, seat socket) with human gear hung on: helmets on the heads, weapons sticking
   out of the harness with no hand, leaf hats on spiders. Breaks rule 1 (sloppy), rule 3 (gear
   covers horn and front eyes; every role looks the same) and rule 4 (a beetle "spearman" takes
   ~1.6-1.8x a rat's ground and reads as cavalry).
2. **Rats' ages 2-3 wear human bronze.** `helm.bronze`, `armour.bronze` (and `helm.dome` at
   age 1) cover the ears and swallow the snout; the age 2 -> 3 step barely shows (rule 5).
3. **Buildings have no ages and no culture structure.** Barracks, stable and watchtower are one
   human template with materials swapped (straw target, dummy, hay: stickers); `farm_plot` is
   shared; beetles and spiders share `mound`. Buildings are keyed `arch:type`, with no age.

## Rats
**Keep:** the head (snout = facing, ears, tail), the kerchief as the one team region, the
bottle-cap shield, the cheese hammer, the woodcutter, `junk_town_center_small`, the tin-can idea.

**Breaks:** `helm.dome` (a grey disc over both ears: a mushroom at 8 px), `helm.bronze` (an
orange bell over the skull, the snout poking out like a spout), `armour.bronze` (an orange egg
body), `armour.leather` (a cockroach shell with straps), ages 2-3 nearly identical, and the giant
is just a 1.5x rat.

**Unit ladder in junk:**

| Role | Age 1 (rags, string) | Age 2 (tin, bottle caps) | Age 3 (cutlery steel, emulating Rome) |
|---|---|---|---|
| Worker | sacking apron, thimble bucket | same | tin hard hat with ear slots (optional) |
| Spear | sharpened nail, cork shield, thimble cap between the ears | needle spear, bottle-cap shield, tin skullcap with ear slots | fork trident, a can cut into a scutum, spoon-bowl helmet with ear slots and a toothbrush crest, sardine-tin bands as a segmented cuirass |
| Skirmisher | shoelace sling, rag headband | bottle-cap ammo pouch, tin brow band | crestless cutlery helmet, tin greave |
| Archer / crossbow | short bow, rag hood, ears out | crossbow, tin skullcap | clothes-peg crossbow, feather plume in the spoon helmet |

**Large unit, five options:**
1. *Capybara "big cousin" cavalry* (a ridden mount: plugs into the mount-first rule): barrel body,
   blunt square head, tiny ears; tea-towel saddle with a team stripe, string reins, a colander
   helmet at age 3. At 8 px a horizontal brick under an upright rat.
2. *Porcupine pin-fortress* (giant/heavy): a quill fan breaking the outline in every facing;
   bottle-cap plates lashed into the quills; a tin howdah at age 3.
3. *Naked mole-rat rammer/sapper:* pink, wrinkled, low and long, huge cream incisors; bucket
   helmet, a spoon battering cap at age 3; the rats' engineer corps.
4. *Rat King swarm:* 5-7 rats knotted at the tails, snouts outward; a bottle-cap crown at age 3.
5. *Sewer brute:* the same rat, a different build: hunched, huge forearms, knuckle-walking.

**Buildings:** town centre kept; age 2 accretes (a can room on top, bottle-cap shingles); age 3
is the pride step: an oil-drum colonnade porch, a cracked-plate pediment, a crockery forecourt.
House too big (cut it down; can on its side half-buried -> upright stacked -> cotton-reel
columns). Barracks: sardine tin with its lid rolled back as the roof / crate fort / half-buried
drainpipe / mousetrap drill yard. Stable follows the large-unit pick. Watchtower: drainpipe with a
can lookout / broken umbrella frame / can stack / a bottle. Farm: a peelings-and-potato heap in a
ring of bricks.

## Beetles
**Keep:** head and horn (facing reads), dark chitin, six splayed legs, the beetle as a mount.

**Breaks:** infantry beetles are mount-sized and horizontal; no hands, so weapons float; roles
identical at game scale; human medieval kit; the team disc on the wing cases is a sticker; the
large unit is a beetle riding a spider or an upscaled beetle; ages are a colour swap.

**Posture round (blocks everything for bugs):** (a) rearing beetle, four legs down, the front
pair as arms, pronotum and horn up (stag beetles rear to fight; a "taur" build like centaurs) -
recommended; (b) upright bug knight; (c) horizontal but small.

**Roles in beetle stuff:** worker a dung beetle rolling a food ball; spear a thorn lance in the
forelegs; skirmisher a bombardier spray; archer a thorn bow; large a rhinoceros beetle with a
wing-case howdah (or a stag beetle "heavy", or a dung beetle pushing a siege ball).
**Ladder:** pigment bands on the wing cases (team region) -> bark and husk plates, a husk sheath
that extends the horn -> lacquered iridescent chitin, a crest on the horn sheath; at the top they
think they're knights.

**Buildings (split `mound` into `pellet`):** Ribbed Shells (earth domes whose relief ribs are the
footholds) for ages 1-2 rising into Cathedral Mound spires at age 3, copying a human temple
(fluted pellet columns, wing-case shingles laid like tiles). House a ribbed shell; barracks a row of
pellet blades round a thorn ring; stable a pen under wing-case shells; watchtower organ-pipe mud
tubes; farm a fungus-garden crater.

## Spiders
**Keep:** the abdomen and leg fan (splays well in a crowd), the skins.

**Breaks:** the same mount-as-infantry problem; the team colour is a huge saddle disc (black pots
with blue lids); head gear hides the front eyes; the large unit is a spider on a pony or an
upscaled spider; no material ladder.

**Posture:** a rearing jumping spider (cephalothorax up, front legs as arms, two big front eyes).
**Roles:** worker carries silk-wrapped bundles; spear a venom thorn javelin; skirmisher bolas or a
cast net; archer a silk-strung thorn bow or glue spit; large a ridden huntsman in a silk howdah, or a
wolf-spider mother covered in spiderlings.
**Ladder:** silk wraps -> stitched leaf and bark plates -> beetle wing cases as trophy armour.
**Buildings (a `silk` architecture, built in tension):** Funnel Lodge as the grammar; town centre
an orb-web gate, or an egg-sac tree; at age 3 the orb web becomes a rose window on a silk
"cathedral" with silk-wrapped twig columns. House a hanging case or a lidded burrow; barracks a
sheet canopy over a sparring pit; stable a tangle web; watchtower a mast with a purse web; farm a
field of small fly-net webs.

## Engine and data needs
1. Buildings per age (`arch:type:age`). 2. Farms per architecture. 3. Split `mound` into
`pellet` and `silk`. 4. Culture-tagged gear (rat kit, bug kit) and heads declaring which slots they
take, so human helmets can't land on a horn or spider eyes. 5. New rodent creatures as data
(capybara mount; porcupine, mole-rat, rat king as giant/heavy bodies).

## Concept rounds, in order
1. **RB1** rat large unit (the five above). 2. **RB2** rat head gear and kit ladder. 3. **BG1** bug
posture (blocks every bug round). 4. **RB3** rat buildings and the age-2/3 town centre. 5. **BB1 /
SB1** beetle and spider town centres. 6. **BG2 / SG2** bug roles, gear by age, large units.
7. **BB2 / SB2** full bug building sets and farms.
