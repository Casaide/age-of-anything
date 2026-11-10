#!/bin/zsh
# One take of the game as an MP4, at normal speed, from its own frames: the PNGs are deleted once encoded.
# tools/film/take.sh <out.mp4> <seconds of play to start at> <seconds long> <game options...>
#   tools/film/take.sh /tmp/rats.mp4 720 6 "races:sewer rats|romans" map:old_forest look:16,16
#   tools/film/take.sh /tmp/make.mp4 0 12 page:setup "typein:sewer rats|centaur romans"   (the lobby: length set by the typing)
#   tools/film/take.sh /tmp/clash.mp4 90 6 mods:big_battle fps:60 clean window:1280,720 push:1.15   (the video: 16:9 at 2560x1440, 60 fps, no UI, a slow push in)
# fps:<n> sets the frames a second (30), and the clip is a near-lossless master (crf 15): the cut is encoded from it.
out=$1 from=$2 len=$3; shift 3
root=${0:A:h:h:h}
fps=30
for a in "$@"; do [[ $a == fps:* ]] && fps=${a#fps:}; done
frames=$(mktemp -d)
trap 'rm -rf $frames' EXIT
"$root/play.sh" lobby mute watch record:$frames from:$from for:$len "$@" | grep -a 'record:'
rm -f $frames/100000.png  # (the first frame is still on the fast-forward's HUD)
ffmpeg -y -loglevel error -framerate $fps -start_number 100001 -i $frames/%d.png -c:v libx264 -preset medium -crf 15 -pix_fmt yuv420p $out
