#!/bin/bash
# Pull the latest Steam Deck build from the Mac's SMB share and make it runnable.
# Run on the Deck (Desktop mode, Konsole):  ./pull_build.sh [--run]
#
# The Mac shares build/linux as "linux" (System Settings > Sharing > File Sharing). The export
# (docs/milestones/m20-steam-deck.md) writes age_of_anything.x86_64, .pck and .sh there.
# Copies go through KDE's KIO (what Dolphin uses, so the password Dolphin saved is used), else
# smbclient (asks for the password). Files land in a temp folder first and replace the old build
# only when all of them arrived, so a failed copy never leaves half a build.
#
# Settings (environment): AOA_HOST (192.168.0.2), AOA_SHARE (linux), AOA_USER (odinsson),
# AOA_DIR (~/Games/age_of_anything).
set -euo pipefail

HOST="${AOA_HOST:-192.168.0.2}"
SHARE="${AOA_SHARE:-linux}"
SMB_USER="${AOA_USER:-odinsson}"
DIR="${AOA_DIR:-$HOME/Games/age_of_anything}"
NAME="age_of_anything"
FILES=("$NAME.x86_64" "$NAME.pck" "$NAME.sh")
RUN=0
[[ "${1:-}" == "--run" ]] && RUN=1

mkdir -p "$DIR"
TMP="$(mktemp -d "$DIR/.pull.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

KIO=""
for k in kioclient kioclient5; do
	command -v "$k" >/dev/null 2>&1 && KIO="$k" && break
done

if [[ -n "$KIO" ]]; then
	echo "Copying from smb://$HOST/$SHARE with $KIO..."
	for f in "${FILES[@]}"; do
		echo "  $f"
		"$KIO" --overwrite --noninteractive copy "smb://$SMB_USER@$HOST/$SHARE/$f" "file://$TMP/$f"
	done
elif command -v smbclient >/dev/null 2>&1; then
	echo "Copying from //$HOST/$SHARE with smbclient..."
	cmds="lcd \"$TMP\";"
	for f in "${FILES[@]}"; do
		cmds+=" get \"$f\";"
	done
	smbclient "//$HOST/$SHARE" -U "$SMB_USER" -c "$cmds"
else
	echo "Neither kioclient nor smbclient found: run this in Desktop mode (KDE), or copy the build with Dolphin." >&2
	exit 1
fi

for f in "${FILES[@]}"; do
	[[ -s "$TMP/$f" ]] || { echo "Missing or empty after the copy: $f (old build left as it was)" >&2; exit 1; }
done

chmod +x "$TMP/$NAME.x86_64" "$TMP/$NAME.sh"
for f in "${FILES[@]}"; do
	mv -f "$TMP/$f" "$DIR/$f"
done

echo "Build in $DIR ($(date -r "$DIR/$NAME.pck" '+%Y-%m-%d %H:%M'), pck $(du -h "$DIR/$NAME.pck" | cut -f1))."
echo "Run it: $DIR/$NAME.sh   (or add that file to Steam as a non-Steam game, once)"

if [[ $RUN -eq 1 ]]; then
	exec "$DIR/$NAME.sh"
fi
