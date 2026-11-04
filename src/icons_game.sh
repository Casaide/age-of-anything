#!/bin/sh
# The game's icon (assets/art/ui/game_icon.svg: the parts kit, a frog, a horned helm, a shield and a sword on yellow)
# for the boot screen: game_icon.png, the tile as it is, and game_icon_ink.png, its ink alone in white with the yellow
# cut out (tinted when drawn).
set -e
cd "$(dirname "$0")/.."
INK='#17110b'
YELLOW='#f2c94c'
svg=$(cat assets/art/ui/game_icon.svg)
printf '%s' "$svg" | rsvg-convert -w 512 -h 512 -o src/icons/game_icon.png
head="${svg%%>*}>"
body=${svg#"$head"}
body=${body%</svg>}
body=$(printf '%s' "$body" | sed "s|<rect width=\"512\" height=\"512\" fill=\"$YELLOW\"/>||")
case "$body" in *"$YELLOW"*) ;; *) exit 1 ;; esac
case "$body" in *"$INK"*) ;; *) exit 1 ;; esac
mask=$(printf '%s' "$body" | sed -e "s/$INK/#ffffff/g" -e "s/$YELLOW/#000000/g")
printf '%s' "$head<defs><mask id=\"m\" maskUnits=\"userSpaceOnUse\" x=\"0\" y=\"0\" width=\"512\" height=\"512\">$mask</mask></defs>
<rect width=\"512\" height=\"512\" fill=\"#ffffff\" mask=\"url(#m)\"/></svg>" | rsvg-convert -w 512 -h 512 -o src/icons/game_icon_ink.png
# The Mac's Dock icon (game_icon_mac.png, set by gl.window_icon): macOS doesn't shape or pad a window icon, so it gets
# Apple's app icon grid here: the tile at 824 of 1024, centred, rounded (radius 185) with the template's soft shadow.
inner="<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" x=\"100\" y=\"100\" width=\"824\" height=\"824\" viewBox=\"0 0 512 512\">${svg#"$head"}"
printf '%s' "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\">
<defs><clipPath id=\"c\"><rect x=\"100\" y=\"100\" width=\"824\" height=\"824\" rx=\"185\"/></clipPath>
<filter id=\"s\" x=\"-10%\" y=\"-10%\" width=\"120%\" height=\"130%\"><feGaussianBlur stdDeviation=\"10\"/></filter></defs>
<rect x=\"100\" y=\"112\" width=\"824\" height=\"824\" rx=\"185\" fill=\"#000000\" fill-opacity=\"0.3\" filter=\"url(#s)\"/>
<g clip-path=\"url(#c)\">$inner</g></svg>" | rsvg-convert -w 1024 -h 1024 -o src/icons/game_icon_mac.png
