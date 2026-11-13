# 2026-11-13: The Bulgars

## What happened
- The ninth approved sheet (`human-redesign/bulgar-base.png`, `bulgar-foot.png`, `bulgar-riders.png`) had no culture in the
  game to dress. Claude asked; Dominic chose to add the Bulgars as a new playable culture (#477).
- The family (`data/families.json`, `bulgar`), drafted by Claude: Boyar horse (cavalry +1 melee armour), Hill forts (Castles
  25% cheaper), Mountain shepherds (food 5% faster, allies' too), each with an alt; the Cheta research (foot melee +1 pierce
  armour), no Fortified Walls, thatch, trails, a felt and iron UI with the stitch crest. Words: bulgar, bulgarian, slav,
  hajduk. The unique unit is the Haidut (fleece, chains, long axe; +2 attack, +15 HP). The hero is a new signature,
  Redcloak, with the Voivode title, topped up from Steppe and Royal heroes.
- No creature lists the family, so only prompts that ask for it get it: every other race stays as it was.
- The body (`tools/vox/bulgar.lobster`): short dark hair, a drooping moustache, a white shirt with red stitching and cuffs, a
  sleeveless coat with a red braid, a red sash over a studded belt, white breeches, black wraps crossed with cords, opanci.
- The sheet has the coat black and the sash as the team region. Drawn that way, a Bulgar in a fight showed almost no team
  colour, and voxel_check's "does the creature still show" counted only 4%. The coat is in team colour now (21%), and the
  body takes the plain human body's limit for that check (20%): like it, it is mostly its clothes.
- Gear (`tools/vox/bulgar_gear.lobster`) rides existing parts with new `bulgar` fits: hat.fur (the kalpak), hat.felt (the
  archer's red-crowned kalpak), helm.spike (tall, with a gilt band and a mail drop), lamellar and gilt lamellar, the
  sheepskin (the hooded yamurluk), the fur cape (the haidut's fleece and chains). One new part, hat.kamilavka, for the priest.
- The Cheta research goes at the end of tech.json's list, so the research table only grows; every match start's hash moves
  with it (golden starts updated), and old saves keep their own table.

## Pictures
- `archive/images/2026-11-13/24-bulgar-kit-sheet.png`: base dress, spearman, swordsman, archer, skirmisher, priest, haidut.
- `archive/images/2026-11-13/25-bulgars-in-match.png`: two Bulgar armies meeting at a ford.

## Ideas parked
- The Voivode's own look (tall kalpak with a white feather, gilt lamellar, red cloak) as hero parts; Redcloak wears the kalpak
  and a long cloak for now.
