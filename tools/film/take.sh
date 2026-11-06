#!/bin/zsh
# One take of the game as an MP4, at normal speed, from its own frames: the PNGs are deleted once encoded.
# tools/film/take.sh <out.mp4> <seconds of play to start at> <seconds long> <game options...>
#   tools/film/take.sh /tmp/rats.mp4 720 6 "races:sewer rats|romans" map:old_forest look:16,16
#   tools/film/take.sh /tmp/make.mp4 0 12 page:setup "typein:sewer rats|centaur romans"   (the lobby: length set by the typing)
out=$1 from=$2 len=$3; shift 3
root=${0:A:h:h:h}
frames=$(mktemp -d)
trap 'rm -rf $frames' EXIT
"$root/play.sh" lobby mute watch record:$frames from:$from for:$len "$@" | grep -a 'record:'
rm -f $frames/100000.png  # (the first frame is still on the fast-forward's HUD)
ffmpeg -y -loglevel error -framerate 30 -start_number 100001 -i $frames/%d.png -c:v libx264 -crf 16 -pix_fmt yuv420p $out
