#!/bin/sh
# Renders the game's audio into assets/audio/: sfx/<name>_<take>.wav, voice/<creature>_<kind>_<take>.wav and
# music/<piece>_<stem>.ogg (via ffmpeg), 4 at once. Deterministic: the same files every time.
#   src/render_audio.sh [all|sfx|voices|music|<sound name>|<creature>|<piece>|<stem>...] [--out DIR]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
set -e
cd "$(dirname "$0")"
out=$PWD/../assets/audio
what=
while [ $# -gt 0 ]; do
	if [ "$1" = "--out" ]; then out=$2; shift; else what="$what $1"; fi
	shift
done
[ -n "$what" ] || what=all
mkdir -p "$out/sfx" "$out/voice" "$out/music"
out=$(cd "$out" && pwd)
wanted() {
	for w in $what; do
		case "$w" in
			all | "$1" | "$2") return 0 ;;
			sfx | music) [ "$w" != "$kind" ] || return 0 ;;
			voices) [ "$kind" != voice ] || return 0 ;;
		esac
	done
	return 1
}
"$LOBSTER" render_audio.lobster -- list | while read -r kind a b; do
	if wanted "$a" "$b"; then echo "$kind $a${b:+ $b}"; fi
done | xargs -P4 -L1 sh -c '
	"$0" render_audio.lobster -- "$1" "$2" "$3" "$4"
	if [ "$2" = music ]; then
		wav="$1/music/$3_$4.wav"
		ffmpeg -v error -y -i "$wav" -c:a vorbis -strict -2 -b:a 160k "${wav%.wav}.ogg"
		rm "$wav"
	fi
	echo "$2 $3 $4"
' "$LOBSTER" "$out"
