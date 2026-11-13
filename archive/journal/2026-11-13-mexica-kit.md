# 2026-11-13: The Mexica kit

## What happened
- Claude built the seventh culture from the approved sheets (`human-redesign/mexica-base.png`, `mexica-foot.png`) as the
  cultures before it (#471). The Mexica (the aztec family) have no mounts; every line walks. The body (`mexica.vox`, from
  `tools/vox/mexica.lobster`) is on the Roman build: long black hair with a straight fringe, a bare chest, a team cloak
  knotted on the right shoulder and hanging to the knee behind, a white loincloth with a team flap, sandals with ankle guards.
- Gear in `tools/vox/mexica_gear.lobster`: a red headband with a green feather, the tall pointed cap in team colour, the eagle
  helmet with the face in its beak, quilted cotton armour (armour.leather on this body), the feather suit, the priest's
  matted hair and black fringed tunic, the round chimalli with its red feather fringe, and the obsidian-edged macuahuitl.
- The Mexica helmets, shield.chimalli and weapon.macuahuitl already existed as aztec-tagged parts and now have their own gear.
  New parts, `only_if: ["aztec"]`: armour.feather_suit, hat.priest_black. New materials: `teal`, `obsidian`.
- Golden: the aztec races changed, and so did one match start with aztecs in it (reed_meadow_2v2), as it should.

## Pictures
- `archive/images/2026-11-13/20-mexica-kit-sheet.png`: the base dress, the quilted spearman, the capped clubman, the eagle,
  the archer, the priest.
- `archive/images/2026-11-13/21-mexica-in-match.png`: a Mexica army in a match.
