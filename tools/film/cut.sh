#!/bin/zsh
# The demo video from its takes: tools/film/cut.sh <takes dir> <out.mp4> [shots file]
# Every shot in the shots file (demo.shots) is cut to whole beats of the theme, the cards are drawn over darkened
# frames of the game in EB Garamond, the mod shots get a ribbon in the corner, and the score is the game's own stems
# faded in one by one, mastered to -14 LUFS. Missing takes are skipped (WW2 until its units are done).
# Output: 1920x1080 at 60 fps, libx264 crf 16, AAC 192k. The segments are kept in <takes dir>/cut/ for a look.
set -e
takes=${1:A} out=$2 shots=${3:-${0:A:h}/demo.shots}
root=${0:A:h:h:h}
font=${0:A:h}/fonts/EBGaramond.ttf
music=$root/assets/audio/music
W=1920 H=1080 FPS=60
BEAT=0.6522          # 92 to the minute
XFADE=0.25           # the cut between two shots, a few frames of dissolve
CARD_XFADE=0.5       # into and out of a card
PARCH=0xf4e9cf GOLD=0xf2c94c DIM=0xc4b493
seg=$takes/cut; rm -rf $seg; mkdir -p $seg
V="scale=${W}:${H}:flags=lanczos,fps=$FPS,format=yuv420p"
dark="gblur=sigma=14,colorchannelmixer=rr=0.2:gg=0.2:bb=0.2"
ff() { ffmpeg -nostdin -y -loglevel error "$@"; }
enc=(-c:v libx264 -preset fast -crf 12 -pix_fmt yuv420p -an)

# opt <options> <key> <default>: one key=value out of a shot's options
opt() { local v; for o in ${=1}; do [[ $o == $2=* ]] && v=${o#*=}; done; print -r -- ${v:-$3}; }

# A ribbon: a dark band with gold edges and the mod's name, turned 45 degrees for the bottom-right corner.
ribbon() {  # <text> <out.png>
    ff -f lavfi -i "color=c=0x17110b@0.85:s=520x54:d=1,format=rgba" -frames:v 1 \
        -vf "drawbox=y=1:h=2:color=${GOLD}:t=fill,drawbox=y=51:h=2:color=${GOLD}:t=fill,drawtext=fontfile=${font}:text='$1':fontsize=30:fontcolor=${PARCH}:x=(w-text_w)/2:y=(h-text_h)/2-2,rotate=-PI/4:ow=406:oh=406:c=none" $2
}

# A card: text centred over the first frame of a take, darkened and softened, a short gold rule underneath.
card() {  # <bg take> <in> <seconds> <text with \n> <out.mp4>
    local bg=$1 in=$2 len=$3 text=$4 o=$5 lines
    print -r -- "${text//\\n/
}" > $o.txt
    lines=$(wc -l < $o.txt)
    local rule=$((H / 2 + 48 * lines + 30))
    ff -ss $in -i $bg -frames:v 1 -vf "$V,$dark" $o.png
    ff -loop 1 -framerate $FPS -t $len -i $o.png -vf "drawtext=fontfile=${font}:textfile=$o.txt:fontsize=84:fontcolor=${PARCH}:line_spacing=12:x=(w-text_w)/2:y=(h-text_h)/2-24,drawbox=x=$((W / 2 - 60)):y=${rule}:w=120:h=2:color=${GOLD}:t=fill,format=yuv420p" $enc $o
}

# The end card: the title, the address, and what it's built on.
endcard() {  # <bg take> <seconds> <title> <out.mp4>
    local o=$4
    ff -i $1 -frames:v 1 -vf "$V,gblur=sigma=20,colorchannelmixer=rr=0.12:gg=0.12:bb=0.12" $o.png
    ff -loop 1 -framerate $FPS -t $2 -i $o.png -vf "drawtext=fontfile=${font}:text='$3':fontsize=150:fontcolor=${PARCH}:x=(w-text_w)/2:y=h/2-190,drawbox=x=$((W / 2 - 80)):y=$((H / 2 + 20)):w=160:h=2:color=${GOLD}:t=fill,drawtext=fontfile=${font}:text='age-of-anything.com':fontsize=40:fontcolor=${DIM}:x=(w-text_w)/2:y=h/2+50,drawtext=fontfile=${font}:text='Built on Creel and Lobster':fontsize=34:fontcolor=${DIM}:x=(w-text_w)/2:y=h-130,format=yuv420p" $enc $o
}

# ---- the segments
typeset -a files durs xfades
n=0
while IFS='|' read -r kind name beats opts text; do
    [[ -z $kind || $kind == \#* ]] && continue
    len=$(printf %.3f $((beats * BEAT)))
    o=$seg/$(printf %02d $n)-$name.mp4
    case $kind in
        shot)
            take=$takes/$name.mp4
            if [[ ! -f $take ]]; then print "no take $name.mp4: skipped"; continue; fi
            in=$(opt "$opts" in 0)
            if [[ -n $text ]]; then  # (a mod's name on the ribbon)
                ribbon "$text" $o.png
                ff -ss $in -t $len -i $take -loop 1 -framerate $FPS -t $len -i $o.png -filter_complex "[0:v]${V}[a];[1:v]fade=in:st=0.3:d=0.4:alpha=1[r];[a][r]overlay=x=$((W - 373)):y=$((H - 373))" $enc $o
            else
                ff -ss $in -t $len -i $take -vf $V $enc $o
            fi
            xf=$(opt "$opts" xfade $XFADE) ;;
        card)
            bg=$takes/$(opt "$opts" bg "").mp4
            card $bg 0 $len "$text" $o
            xf=$CARD_XFADE; (( n > 0 )) && xfades[$n]=$CARD_XFADE ;;   # (into the card as softly as out of it)
        end)
            endcard $takes/$(opt "$opts" bg "").mp4 $len "$text" $o
            xf=0; xfades[$n]=$CARD_XFADE ;;
    esac
    files+=($o); durs+=($len); xfades+=($xf)
    n=$((n + 1))
done < $shots

# ---- the picture: one xfade chain
inputs=(); graph=""; total=0; prev="[0:v]"
for ((i = 1; i <= $#files; i++)); do inputs+=(-i $files[$i]); done
for ((i = 1; i < $#files; i++)); do
    total=$(printf %.3f $((total + durs[$i] - (i > 1 ? xfades[$((i - 1))] : 0))))
    off=$(printf %.3f $((total - xfades[$i])))
    nxt="[v$i]"; (( i == $#files - 1 )) && nxt="[v]"
    graph+="${prev}[${i}:v]xfade=transition=fade:duration=${xfades[$i]}:offset=$off$nxt;"
    prev=$nxt
done
length=$(printf %.3f $((total + durs[$#files] - xfades[$(($#files - 1))])))
print "picture: $#files segments, $length s"
ff $inputs -filter_complex "${graph%;}" -map "[v]" -c:v libx264 -preset fast -crf 12 -pix_fmt yuv420p $seg/picture.mp4

# ---- the score: the theme's stems, in one by one, out together; then mastered
# stem: when it comes in (s) and how long its fade is
stems=(pluck:0:0.5 drone:0:2 flute:8:2 horns:18:2 drums:26:1 battle:36:2)
ain=(); amix=""; k=0
for s in $stems; do
    IFS=: read -r name at fade <<< "${s// /}"
    ain+=(-i $music/theme_$name.ogg)
    amix+="[${k}:a]afade=t=in:st=${at}:d=$fade,afade=t=out:st=$((length - 3)):d=3[a$k];"
    k=$((k + 1))
done
mixin=""; for ((j = 0; j < k; j++)); do mixin+="[a$j]"; done
ff $ain -filter_complex "$amix${mixin}amix=inputs=${k}:normalize=0,atrim=0:$length" -c:a pcm_s16le $seg/score.wav
m=$(ffmpeg -i $seg/score.wav -af loudnorm=I=-14:TP=-1:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
j() { print -r -- "$m" | sed -n "s/.*\"$1\" : \"\([^\"]*\)\".*/\1/p"; }
ff -i $seg/score.wav -af "loudnorm=I=-14:TP=-1:LRA=11:measured_I=$(j input_i):measured_TP=$(j input_tp):measured_LRA=$(j input_lra):measured_thresh=$(j input_thresh):offset=$(j target_offset):linear=true" -ar 48000 $seg/master.wav

# ---- the delivery
ff -i $seg/picture.mp4 -i $seg/master.wav -map 0:v -map 1:a -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart -shortest $out
ffprobe -v error -show_entries format=duration,bit_rate -of default=nw=1 $out
