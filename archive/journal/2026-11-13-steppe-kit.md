# 2026-11-13: The Steppe kit

## What happened
- Claude built the fourth culture from the approved sheets (`human-redesign/steppe-base.png`, `steppe-foot.png`,
  `steppe-riders.png`) as the Royal kit was built (#465). The Steppe body (`steppe.vox`, from `tools/vox/steppe.lobster`) is
  on the Roman build: a shaved crown with hair at the back and a tuft, a braid behind each ear, a drooping moustache, a long
  deel in team colour crossed to the right with a trimmed edge and hem, a wide red sash, felt boots.
- Worn gear in `tools/vox/steppe_gear.lobster`: a quilted coat (armour.leather), lacquered and iron lamellar with broad
  shoulder guards, a spiked helmet with a red pennant and lamellar flaps, the fur hat with ear flaps, the archer's white felt
  hat, the skirmisher's sheepskin and the shaman's headdress.
- New parts, all `only_if: ["steppe"]`: armour.lamellar, armour.lamellar_iron, armour.sheepskin, helm.spike, hat.fur, hat.felt,
  hat.shaman (healers only). The existing helm.steppe_spike now draws as the spiked helmet. New materials: `sash`, `lacquer`.
- A funny one: the first shaman headdress was a solid ring of feathers and read as a guardsman's bearskin. Eight splayed
  feathers fixed it.

## Decisions
- The round wicker shield stays the shared round shield: shield.round is held by the Norse too, and a held model has no
  per-body fits.

## Pictures
- `archive/images/2026-11-13/14-steppe-kit-sheet.png`: fur hat, quilted spearman, lamellar swordsman, iron lamellar,
  archer, skirmisher, shaman.
- `archive/images/2026-11-13/15-steppe-in-match.png`: a Steppe army in a match.
