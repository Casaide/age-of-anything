#!/bin/sh
# Scaffold a mod (milestone 21, docs/modding.md): a folder with its manifest, data overlays, one example part with its
# voxel look (data/voxel/gear.json: the gear and the rule that gives the part it), and a README, ready to fill in and
# check.
#
#     tools/mods/new_mod.sh <id> ["Name"] [--private] [--era <tag>]
#
# <id>: lower_case letters, digits and underscores. --private puts it in mods_private/ (gitignored, never exported: for
# fan pieces that must not be shared). --era adds an era tag of the mod's own, so its parts only appear where a host's
# rules allow it (the manifest's "eras"; the rules overlay opens it under Anything goes).
set -e
GAME_VERSION=$(sed -n 's/^ *"version": *"\([0-9]*\.[0-9]*\).*/\1/p' data/pack.json)
usage() { sed -n '2,10s/^# \{0,1\}//p' "$0"; exit 1; }
mod_id=
name=
private=
era=
while [ $# -gt 0 ]; do
	case "$1" in
		--private) private=1 ;;
		--era) era=$2; shift ;;
		--*) ;;
		*) if [ -z "$mod_id" ]; then mod_id=$1; elif [ -z "$name" ]; then name=$1; fi ;;
	esac
	shift
done
case "$mod_id" in
	[a-z]*) ;;
	*) usage ;;
esac
case "$mod_id" in
	*[!a-z0-9_]*) usage ;;
esac
[ -n "$name" ] || name=$(printf '%s' "$mod_id" | tr _ ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1')
root=mods/$mod_id
[ -z "$private" ] || root=mods_private/$mod_id
if [ -e "$root" ]; then echo "$root already exists"; exit 1; fi
mkdir -p "$root/data/rules" "$root/data/voxel"
tag=${era:-$mod_id}
part_id=helm.${mod_id}_example

eras='[]'
if [ -n "$era" ]; then eras="[
  \"$era\"
 ]"; fi
private_line=
if [ -n "$private" ]; then private_line=',
 "private": true'; fi
cat > "$root/pack.json" <<EOF
{
 "id": "$mod_id",
 "name": "$name",
 "version": "0.1.0",
 "authors": [],
 "description": "",
 "license": "",
 "load_order": 100,
 "depends": ["age_of_anything@$GAME_VERSION"],
 "eras": $eras,
 "data": "data",
 "check": {
  "rules": "anything",
  "prompts": [
   "$tag soldiers"
  ]
 }$private_line
}
EOF

era_lines=
if [ -n "$era" ]; then era_lines=",
  \"era\": [
   \"$era\"
  ],
  \"upgrade_within\": \"$tag\""; fi
cat > "$root/data/parts.json" <<EOF
[
 {
  "id": "$part_id",
  "slot": "head_gear",
  "_doc": "An example helmet: replace it with your parts.",
  "tags": [
   "helmet",
   "$tag"
  ],
  "only_if": [
   "$tag"
  ],
  "stats": {
   "armour": {
    "melee": 1,
    "pierce": 0
   }
  },
  "points": 1,
  "tier": 1,
  "shapes": [
   {
    "t": "poly",
    "p": [
     [
      -5,
      2
     ],
     [
      -5,
      -4
     ],
     [
      0,
      -6
     ],
     [
      5,
      -4
     ],
     [
      5,
      2
     ]
    ],
    "ch": "iron"
   }
  ]$era_lines
 }
]
EOF

if [ -n "$era" ]; then
	cat > "$root/data/lexicon.json" <<EOF
{
 "words": {
  "$tag": {
   "era": "$era",
   "tags": {
    "$tag": 5
   },
   "substitute": {
    "helmet": 1
   },
   "note": "Not in this era. (Write a playful note.)"
  }
 }
}
EOF
	cat > "$root/data/rules/anything.json" <<EOF
{
 "_doc": "Anything goes allows this mod's era.",
 "+era": [
  "$era"
 ]
}
EOF
else
	cat > "$root/data/lexicon.json" <<EOF
{
 "words": {
  "$tag": {
   "tags": {
    "$tag": 5
   }
  }
 }
}
EOF
fi

cat > "$root/data/voxel/gear.json" <<EOF
{
 "_doc": "The mod's voxel gear (docs/rendering.md, \"Voxel units\"): a helmet on any body's helmet spot, and the rule that gives the example part it.",
 "gear": {
  "${mod_id}_helm": {
   "flags": [
    "helm"
   ],
   "fits": {
    "*": [
     {
      "helm": 0.4,
      "mat": "metal"
     }
    ]
   }
  }
 },
 "parts": [
  {
   "part": "$part_id",
   "gear": "${mod_id}_helm"
  }
 ]
}
EOF

private_note=
if [ -n "$private" ]; then private_note='
**PRIVATE:** this mod lives in `mods_private/` (gitignored, excluded from exports). Never commit it,
ship it or put its pictures in `archive/`.
'; fi
cat > "$root/README.md" <<EOF
# $name (\`$mod_id\`)
$private_note
A mod for the game: more data (\`data/\`), its parts' voxel looks (\`data/voxel/\`). How to make it: \`docs/modding.md\`.

\`\`\`sh
src/mod_check.sh $mod_id
tools/mods/pack.sh $mod_id
\`\`\`
EOF
echo "made $root: fill in data/parts.json and data/voxel/, then see docs/modding.md"
