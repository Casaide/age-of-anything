#!/bin/sh
# Installs the Deck build that `make serve` serves from the Mac (#446). make serve fills in its address and serves this as
# deck.sh, so on the Deck (Desktop mode, Konsole) it's one line:   curl -fsSL http://<mac>:8080/deck.sh | sh
# (`| sh -s -- --run` starts the game after). Downloads deck.tar.gz, unpacks it in a temp folder beside the game and swaps it
# in only once it all arrived, then writes the launcher (Desktop mode's menu; "Add to Steam" from there takes the icon).
# Settings (environment): AOA_URL (the server), AOA_DIR (~/Games/age_of_anything_lobster).
set -eu
URL="${AOA_URL:-@URL@}"
DIR="${AOA_DIR:-$HOME/Games/age_of_anything_lobster}"
RUN=0
[ "${1:-}" = "--run" ] && RUN=1

mkdir -p "$(dirname "$DIR")"
TMP="$(mktemp -d "$(dirname "$DIR")/.install_http.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $URL/deck.tar.gz ..."
curl -fL --progress-bar "$URL/deck.tar.gz" | tar -xzf - -C "$TMP"
[ -x "$TMP/lobster_linux/run.sh" ] || { echo "The download has no run.sh: is make serve's Deck build complete?"; exit 1; }
rm -rf "$DIR"
mv "$TMP/lobster_linux" "$DIR"
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
if [ $RUN -eq 1 ]; then exec "$DIR/run.sh"; fi
