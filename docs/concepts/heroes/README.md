# Heroes, concept round HR1 (2026-10-13, Claude)

Milestone 14 phase 9. Each race gets one hero: a named, generated champion, the face of the race.
This round only asks **what a hero looks like**, built from parts we already have, so Dominic can
pick a direction before anything new is made (D-080). Nothing here is in play.

Sheet: `tests/sheets/heroes_h1.json` (run with `tests/sheet.gd`); `heroes_h1_facings_3x.png` (close)
and `heroes_h1_facings_1x.png` (game scale). Every row passes the placement checks.

| Look | What | Reads at game scale? |
|---|---|---|
| **A champion** | the race's age-3 swordsman, 1.25x, with a cape (cloth, or leaf for bugs and frogs) | bigger and caped: reads as "someone", but close to a giant line |
| **B standard bearer** | the same, 1.15x, the team banner on its back | the banner reads best of the three in a crowd; says "rally here" (an aura) |
| **C mounted** | the race's age-3 large line, 1.1x, with a cape where it fits | strongest where the race rides (imperial humans); rats with cheese hammers and Aztecs have no mount here, frogs go giant |

Things the round shows:
- A cape on a horse cuts through the horse's back (the placement check catches it: A3), so a mounted
  hero needs a cape cut for riders, or a banner on a pole instead.
- A mounted beetle reads small at game scale (rider and beetle both low and dark): a beetle hero
  needs the banner or a bigger mount to stand out.
- Size alone (A) reads as "a big unit", not "the hero". Something only heroes carry (a banner, a
  crest, a glow ring under them) would read better.

Claude's suggestion: **B's banner on A's size** (1.2x, the race's best kit, a banner pole on the back
in team colour, a cape only on foot), mounted only for races whose large line rides their own mount.
The aura shows as the banner. Revive: a fallen hero's banner stays where it fell until revived at
the Castle (a cost and a wait).

Waiting on Dominic: pick a look (A, B, C or a mix) before any hero is built. Name, aura and revive
rules are in `docs/milestones/m14-race-identity.md` ("Heroes").


---

# Heroes, concept round HR2 (2026-10-13, Claude)

Dominic on HR1 (D-127): "good start, but they don't look unique, they need real character to stand out.
Imagine a rat like 'Ratty the Gnawer' or 'Ratty the 10000th of his name'." So a hero is now a **named
champion with a personality**, and the look sells the name: an oversized or signature item, a pet, a
different silhouette, a colour of their own (gold, crimson) beyond the team colour. Nothing here is in play.

Sheets (8 facings and idle, each beside the race's own age-3 swordsman, at 3x and game scale; every row
passes the placement checks, 3D and 2D):
- `heroes_hr2_creatures_3x.png` / `_1x.png`: rats, frogs, forest beetles, spooky spiders (archive 480, 481)
- `heroes_hr2_humans_3x.png` / `_1x.png`: one per human culture (482, 483)
- `heroes_hr2_centaurs_bears_3x.png` / `_1x.png`: centaurs, and the bears staged from `data/later/bears.json` (484, 485)

Specs `tests/sheets/heroes_hr2_*.json`; gear `scenes/art_pixel/hero_concepts.gd`; data `data/later/heroes.json`.
The idle column shows the body's resting pose where it has one; none of these infantry bodies has one yet,
so they stand (a hero idle, a swagger or a yawn, would be new animation work).

## The characters (names as the generator gives them for that race and that look)

| Race (prompt) | Hero | Look | Temper |
|---|---|---|---|
| angry rats | **King Whiskerton the Gnawer** | an oversized gold crown with a bite out of it, a whole cheese wheel for a shield | Ate his own crown in a siege. Would do it again. |
| royal rats | **Gnawbert the 10000th of His Name** | a tiny crown on a velvet cushion, a team-velvet robe of state with ermine, dragging; a cheese sceptre | From a long line of rats with exactly the same name. Insists on all of it. |
| sewer rats with cheese hammers | **Drainsby Nine-Lives** | a battered tricorn over a bandage, a door-sized cleaver on his shoulder, Gerald the cockroach on the other | Killed four times and finds it insulting. |
| frogs with clubs | **Old Mossback** | big (x1.35), a mound of moss with toadstools and a fern on his back, a staff with a firefly lantern | Hadn't moved in forty years until today. |
| angry swamp frogs with reed spears | **Croaker Twice-Drowned** | a crown of waterweed and a fish bone, a weedy anchor over the shoulder | Drowned. Twice. Came back with an anchor. |
| swamp frogs | **Great Gloop Who Woke the Heron** | a pink water-lily hat with a bulrush plume, a conch war horn | Speaks only at full volume. The horn is for whispering. |
| woodland beetles | **Old Barkhide** | big (x1.35), a living sapling growing out of the moss on his back, a sprouting root club | Stood so long in a wood a tree took root on him. |
| forest beetles | **Bramblebeck "Sir Shiny"** | a gilded acorn helmet with a gold plume, a gilded leaf shield | Polishes his shell between blows. |
| spooky spiders | **Sir Vesper Eight-Eyes** | a tall top hat, a skull-topped cane (x1.4) | Apologises before every bite. Means it. |
| spooky spiders | **Madame Arachnea the Widow** | a tall lace hat, a cartwheel of web on a bone hoop on her back (x1.4) | Has buried three husbands. Kept the webs. |
| romans | **Lucius the Unbothered** | an enormous transverse crest, a long crimson cloak (his colour, not the team's), dragging | Has never once hurried. |
| greeks | **Thalia the Lion-Skinned** | the lion's scalp as a hood, its pelt down her back | Wrestled the lion. Kept the coat. Tells everyone. |
| noble humans | **Percival of the Many Feathers** | a bascinet under a tower of plumes, a quartered team-and-gold cape | Late to every battle: the plumes take an hour. |
| mongols | **Khan Temur the Far-Rider** | a wolf's head hat, a horsetail standard | Raised by wolves, or says so. |
| egyptians | **Pharaoh Sethi Beloved of Cats** | a tall double crown with gold plumes and a cobra, a temple cat on his shoulder | The cat is in charge. Everyone knows. |
| han chinese | **Champion Lin the Unmoved** | a guandao over the shoulder, four back flags | Has not changed expression since the last dynasty. |
| aztecs | **Xochitl Jaguar-Heart** | the face in a jaguar's jaws, a great fan of quetzal feathers | Subtle, never. |
| centaur romans | **Thunderhoof** | a gold laurel, a young tree trunk for a club | Pulled up a tree to win an argument. |
| centaur romans | **Gaius Hoof-of-the-Legion** | the transverse crest, a gold eagle standard | Won't trust the eagle to anyone with two legs. |
| bear greeks | **Old Honeypaw** | a crown of dripping honeycomb, a beehive on his back, bees | Brought the bees. The bees did not agree. |
| bear greeks | **Big Kleon Who Was Napping** | a long striped nightcap, a log for a club, his pillow strapped on for later | Fights entirely asleep. |

What I see at game scale: the crowns, the plumes, the transverse crest, the lily hat, the sapling, the
quetzal fan, the cheese wheel and the dragging robes and cloaks all read at once in a crowd; the heroes are
1.2-1.35x their soldiers, which with the big item makes "that one" obvious. Weaker: Gerald the cockroach and
the Nile cat only read at 3x; the anchor and the waterweed crown are thin; the spiders still read small (a
low body), even at 1.4x with a top hat.

## The naming data contract (proposal)

In `data/later/heroes.json`, read by `tests/hero_names.gd` (run it on any prompts; it prints the race's own
hero and the name each look it could have would carry):

- `hero_names.creatures.<creature>` and `hero_names.families.<culture>`: `names` (pooled together) and
  `titles` (kept neutral: Boss, Elder, General, Khan, Pharaoh).
- `hero_names.formats`: `named` "{name} {epithet}", `titled` "{title} {name} {epithet}", `regnal` "{name} the
  {ordinal} of His Name", `nickname` "{nickname}", `called` "{name} \"{nickname}\"".
- `hero_names.ordinals`: 10000th, Umpteenth, Forty-Second, Last, Second-Best...
- `hero_signatures.<id>`: `who` (creatures and/or cultures that may have it), `parts` (put on over the race's
  age-3 swordsman), `scale` (percent), `epithets` (follow a name: "the Gnawer"), `nicknames` (stand alone:
  "Old Mossback"), `titles` (its own, when the character needs them: Madame, Sir, King), `formats`, `temper`
  (the one line shown in the unit card).
- **Deterministic**: every pick by `src/rng.gd`, seeded with FNV-1a of the race key + "|hero"; signatures sorted
  by id, lists in file order. Same race key, same hero, on every machine; a reroll gives a new one.
- The look and the name agree because the epithet comes from the signature. A mod adds a hero by adding a
  signature, a creature or culture by adding its name lists.

Things the contract shows: titles had to lose their gender (HR2's first pass made "Lady Temur" and "Madame
Vesper the Gentleman"); a signature that needs a title brings its own. Names are still mixed (Sir Gwendolyn,
a bear called Kleon), which I think is fine, even funny.

## Recommendation (Claude)

Go with signatures: a few per creature and one or two per culture, picked from the race key, each a name +
a look + a temper. Build order: the naming (cheap, all data) and the unit card's name and temper line first;
then the signature gear as real parts. Keep HR1's banner idea for the aura (a hero is where the army rallies)
but let the signature carry the look. Revive as in HR1 (the banner where they fell, revived at the Castle).

## Questions for Dominic

1. Signatures as the way to do it (a fixed set of characters per creature and culture), or more mixing (any
   item with any epithet: more variety, less character)?
2. Favourites, and any that miss? (I'd drop or rework the anchor and the waterweed crown, which read thin.)
3. Should heroes get their own idle (a swagger, a yawn, the Gnawer nibbling his crown)? That's new animation.
4. Pets (Gerald, the temple cat) read only up close: make them bigger, or leave them as a close-up joke?
5. Spiders: their heroes read small; a bigger signature item (a whole web on poles, a carriage?) or accept it?
