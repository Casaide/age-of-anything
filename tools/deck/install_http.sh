#!/bin/sh
# Installs and starts the Deck build that `make serve` serves from the Mac (#446, #492). make serve fills in its address and
# serves this as deck.sh, so on the Deck (Desktop mode, Konsole) the first time it's one line:
#   curl -fsSL http://<mac>:8080/deck.sh | sh -s -- --run
# It saves itself as ~/Games/age-of-anything.sh, and the desktop launcher ("Add to Steam" takes it from there) runs that with
# --run: each start asks the Mac for the served build's version (3 s at most) and, when it differs from what's installed,
# downloads it into a temp folder and swaps it in once it all arrived. Mac not serving: the installed game starts as is.
# Settings (environment): AOA_URL (the server), AOA_DIR (~/Games/age_of_anything_lobster).
set -eu
URL="${AOA_URL:-@URL@}"
DIR="${AOA_DIR:-$HOME/Games/age_of_anything_lobster}"
LAUNCH="$(dirname "$DIR")/age-of-anything.sh"
RUN=0
[ "${1:-}" = "--run" ] && RUN=1

mkdir -p "$(dirname "$DIR")"
served="$(curl -fsS -m 3 "$URL/version" 2>/dev/null || true)"
have="$(cat "$DIR/.served_version" 2>/dev/null || true)"
if [ -z "$served" ]; then
	[ -x "$DIR/run.sh" ] || { echo "Can't reach $URL (is make serve running, on the Deck's network?) and nothing is installed"; exit 1; }
	echo "$URL isn't serving: starting the installed build"
elif [ "$served" != "$have" ] || [ ! -x "$DIR/run.sh" ]; then
	TMP="$(mktemp -d "$(dirname "$DIR")/.install_http.XXXXXX")"
	trap 'rm -rf "$TMP"' EXIT
	echo "Downloading $URL/deck.tar.gz ..."
	curl -fL --progress-bar "$URL/deck.tar.gz" | tar -xzf - -C "$TMP"
	[ -x "$TMP/lobster_linux/run.sh" ] || { echo "The download has no run.sh: is make serve's Deck build complete?"; exit 1; }
	echo "$served" > "$TMP/lobster_linux/.served_version"
	rm -rf "$DIR"
	mv "$TMP/lobster_linux" "$DIR"
	echo "Updated: $DIR"
else
	echo "Up to date: $DIR"
fi
# (this script, kept to start the game through, with the address that worked: the next start checks for a new build again)
curl -fsS -m 3 "$URL/deck.sh" 2>/dev/null | sed "s#^URL=.*#URL=\"\${AOA_URL:-$URL}\"#" > "$LAUNCH.tmp" && [ -s "$LAUNCH.tmp" ] && mv "$LAUNCH.tmp" "$LAUNCH" && chmod +x "$LAUNCH" || rm -f "$LAUNCH.tmp"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/age-of-anything.desktop" <<EOD
[Desktop Entry]
Type=Application
Name=Age of Anything
Exec=sh $LAUNCH --run
Icon=$DIR/icon.png
Categories=Game;StrategyGame;
EOD
if [ $RUN -eq 1 ]; then exec "$DIR/run.sh"; fi
