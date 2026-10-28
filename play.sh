#!/bin/sh
# Play the game: ./play.sh [lobby] [races:A|B] [watch] [mute] ... (src/play.sh says every option). With no arguments, the
# title screen.
here="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 0 ] && set -- lobby
exec "$here/src/play.sh" none "$@"
