#!/bin/sh
# The app's icon and splash: the game's icon (assets/art/ui/game_icon.svg: the parts kit on yellow) as an adaptive
# icon (the yellow behind, the ink in front inside the launcher's safe zone) and as plain ic_launcher PNGs for older
# launchers, at every Android density; and the themes that show it while the game starts.
#   icon.sh <repo root> <res dir>
set -e
root=$1
res=$2
YELLOW='#f2c94c'
DARK='#120f0c'
svg=$(cat "$root/assets/art/ui/game_icon.svg")
head="${svg%%>*}>"
body=${svg#"$head"}
body=${body%</svg>}
ink=$(printf '%s' "$body" | sed "s|<rect width=\"512\" height=\"512\" fill=\"$YELLOW\"/>||")
[ "$ink" != "$body" ]
# (the foreground: 108dp, the frame with its stroke (76..436 of 512) in the middle 52dp, its corners inside the
# 66dp circle every launcher mask keeps)
fore="<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"108\" height=\"108\" viewBox=\"0 0 108 108\">
<svg x=\"28\" y=\"28\" width=\"52\" height=\"52\" viewBox=\"76 76 360 360\">$ink</svg>
</svg>"

for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
	d=${pair%:*}
	px=${pair#*:}
	mkdir -p "$res/mipmap-$d"
	printf '%s' "$svg" | rsvg-convert -w "$px" -h "$px" -o "$res/mipmap-$d/ic_launcher.png"
	big=$((px * 108 / 48))
	printf '%s' "$fore" | rsvg-convert -w "$big" -h "$big" -o "$res/mipmap-$d/ic_launcher_foreground.png"
done
mkdir -p "$res/mipmap-anydpi-v26" "$res/values-v31"
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/icon_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$res/values/icon_colors.xml" <<XML
<resources>
    <color name="icon_background">$YELLOW</color>
</resources>
XML
cat > "$res/values/styles.xml" <<XML
<resources>
    <style name="GameTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">$DARK</item>
    </style>
</resources>
XML
cat > "$res/values-v31/styles.xml" <<XML
<resources>
    <style name="GameTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">$DARK</item>
        <item name="android:windowSplashScreenBackground">$DARK</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/icon_background</item>
    </style>
</resources>
XML
