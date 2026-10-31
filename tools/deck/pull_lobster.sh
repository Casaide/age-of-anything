#!/bin/bash
# Pull the Lobster port's Steam Deck build from the Mac's SMB share and run it.
# Run on the Deck (Desktop mode, Konsole):  ./pull_lobster.sh [--run]
#
# The Mac makes it with tests/lobster_spike/deck/build.sh into build/lobster_linux, shared like the
# Godot build (tools/deck/pull_build.sh): the share "linux" holds a folder lobster_linux. It's a whole
# folder (the language, the game's code, data, sounds and its part library, ~200 MB), so this copies it
# with smbclient's recursive get into a temp folder and swaps it in only once it all arrived.
#
# Settings (environment): AOA_HOST (192.168.0.10), AOA_SHARE (linux), AOA_USER (me),
# AOA_DIR (~/Games/age_of_anything_lobster).
set -euo pipefail

HOST="${AOA_HOST:-192.168.0.10}"
SHARE="${AOA_SHARE:-linux}"
SMB_USER="${AOA_USER:-me}"
DIR="${AOA_DIR:-$HOME/Games/age_of_anything_lobster}"
RUN=0
[[ "${1:-}" == "--run" ]] && RUN=1

command -v smbclient >/dev/null 2>&1 || { echo "Needs smbclient (or copy lobster_linux over in Dolphin to $DIR)"; exit 1; }
mkdir -p "$(dirname "$DIR")"
TMP="$(mktemp -d "$(dirname "$DIR")/.pull_lobster.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
echo "Copying //$HOST/$SHARE/lobster_linux (asks for the Mac's password)..."
smbclient "//$HOST/$SHARE" -U "$SMB_USER" -c "recurse ON; prompt OFF; lcd $TMP; mget lobster_linux"
[[ -x "$TMP/lobster_linux/run.sh" ]] || chmod +x "$TMP/lobster_linux/run.sh" "$TMP/lobster_linux/lobster/bin/lobster"
rm -rf "$DIR"
mv "$TMP/lobster_linux" "$DIR"
# A launcher with the game's icon (Desktop mode's menu; "Add to Steam" from there takes the icon with it).
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/age-of-anything.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Age of Anything
Exec=$DIR/run.sh
Icon=$DIR/icon.png
Categories=Game;StrategyGame;
EOF
echo "Ready: $DIR/run.sh"
if [[ $RUN -eq 1 ]]; then exec "$DIR/run.sh"; fi
