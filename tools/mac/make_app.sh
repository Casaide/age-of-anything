#!/bin/sh
# Builds build/mac/Age of Anything.app (#224), so macOS knows this is a game: Game Mode turns on when it goes fullscreen, and
# the Dock and Cmd-Tab show its name and icon. A dev build: the fork's lobster inside the bundle, running src/game.lobster
# from this repo, and Lobster's data and modules linked. Quick when nothing changed: play.sh runs it every time. Not for shipping.
set -e
here="$(cd "$(dirname "$0")/../.." && pwd)"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
lobster_root="$(cd "$(dirname "$LOBSTER")/.." && pwd)"
app="$here/build/mac/Age of Anything.app"
macos="$app/Contents/MacOS"
res="$app/Contents/Resources"
mkdir -p "$macos" "$res"

cmp -s "$LOBSTER" "$macos/lobster" || cp -f "$LOBSTER" "$macos/lobster"
ln -sfn "$lobster_root/data" "$macos/data"  # (Lobster looks beside its binary)
ln -sfn "$lobster_root/modules" "$macos/modules"

# (the launcher, for Finder and `open`: play.sh runs the lobster inside with its own options)
cat > "$macos/launcher.tmp" <<'EOF'
#!/bin/sh
macos="$(cd "$(dirname "$0")" && pwd)"
cd "$macos/../../../../../src"
. ./bake_cache.sh
exec "$macos/lobster" game.lobster -- none lobby lobby
EOF
chmod +x "$macos/launcher.tmp"
mv -f "$macos/launcher.tmp" "$macos/age-of-anything"

cat > "$app/Contents/Info.plist.tmp" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>age-of-anything</string>
	<key>CFBundleIdentifier</key><string>com.casaide.ageofanything</string>
	<key>CFBundleName</key><string>Age of Anything</string>
	<key>CFBundleDisplayName</key><string>Age of Anything</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
	<key>GCSupportsGameMode</key><true/>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
if cmp -s "$app/Contents/Info.plist.tmp" "$app/Contents/Info.plist"; then
	rm -f "$app/Contents/Info.plist.tmp"
else
	mv -f "$app/Contents/Info.plist.tmp" "$app/Contents/Info.plist"
	changed=1
fi

icon="$here/src/icons/game_icon_mac.png"
if [ ! "$res/AppIcon.icns" -nt "$icon" ]; then
	set_dir="$(mktemp -d)/AppIcon.iconset"
	mkdir -p "$set_dir"
	for s in 16 32 128 256 512; do
		sips -z $s $s "$icon" --out "$set_dir/icon_${s}x$s.png" > /dev/null
		d=$((s * 2))
		sips -z $d $d "$icon" --out "$set_dir/icon_${s}x$s@2x.png" > /dev/null
	done
	iconutil -c icns "$set_dir" -o "$res/AppIcon.icns"
	rm -rf "$(dirname "$set_dir")"
	changed=1
fi

# (LaunchServices reads the category from here)
[ -z "$changed" ] || /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
echo "$app"
