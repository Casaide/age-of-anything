#!/bin/sh
# Play the game: ./play.sh [lobby] [races:A|B] [watch] [mute] ... (src/play.sh says every option). With no arguments, the
# title screen.
here="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 0 ] && set -- lobby
if [ "$(uname)" = Darwin ]; then
	# (through the Mac app, so macOS knows it's a game: Game Mode, the Dock's name and icon; #224. The script keeps Ctrl-C.)
	"$here/tools/mac/make_app.sh" > /dev/null
	LOBSTER="$here/build/mac/Age of Anything.app/Contents/MacOS/lobster"
	export LOBSTER
fi
exec "$here/src/play.sh" none "$@"
