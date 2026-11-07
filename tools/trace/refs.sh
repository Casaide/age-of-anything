#!/bin/sh
# The drawings a traced body is carved from, public domain US War Department manuals: fetched into reference/ (gitignored), never
# committed. Each view is cut out, at the magnification the trace spec's pixel numbers are in (mods/ww2/trace/).
cd "$(dirname "$0")/../.."
set -e
fm=reference/fm3040.pdf
if [ ! -f "$fm" ]; then
	mkdir -p reference
	curl -sL -A 'Mozilla/5.0' -o "$fm" 'https://upload.wikimedia.org/wikipedia/commons/4/47/FM_30-40_Recognition_Pictorial_Manual_on_Armored_Vehicles_1943_%28IA_Fm30-401943%29.pdf'
fi
# view <pdf page> <name> <what> <crop> <zoom>: one view as a plain PBM (black is the tank) and a PNG to look at
view() {
	mkdir -p "reference/$2"
	pdfimages -f "$1" -l "$1" -png "$fm" "reference/$2/raw"
	magick "reference/$2/raw-000.png" -crop "$4" +repage -filter point -resize "$5" "reference/$2/$3.png"
	magick "reference/$2/$3.png" -threshold 50% -compress none "reference/$2/$3.pbm"
}
# FM 30-40, "Medium Tank, M4A3 (75-mm gun)"
view 55 m4a3_75w side 640x340+325+495 200%
view 55 m4a3_75w top 640x290+325+150 200%
view 55 m4a3_75w front 300x340+1110+500 300%
# AN 01-60-3 p30 (19 Sept 1945), the P-51D three-view, public domain: a line drawing, so its outlines are traced in the spec as polygons
p51="reference/p51/3v.png"
if [ ! -f "$p51" ]; then
	mkdir -p reference/p51
	curl -sL -A 'AgeOfAnythingTracer/1.0' -o "$p51" 'https://commons.wikimedia.org/wiki/Special:FilePath/North_American_P-51D_Mustang_3-view_line_drawing.png'
fi
p51view() {
	magick "$p51" -resize 1300x -crop "$2" +repage $3 -filter point -resize 200% "reference/p51/$1.png"
	magick "reference/p51/$1.png" -threshold 60% -compress none "reference/p51/$1.pbm"
}
p51view side 860x300+200+20 -flop
p51view top 1000x860+130+840 "-rotate -90"
p51view front 980x340+135+410 ""
