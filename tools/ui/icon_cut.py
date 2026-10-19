"""Cuts one unit out of a concept sheet (tests/sheet.gd, zoom 6) as a transparent sprite at the game's own pixel size:
keys out the sheet's meadow and the unit's shadow, takes one pixel per 6x6 block, and clears the meadow-tinted edge
pixels the bake leaves on the outline. Used for the icon concepts (docs/concepts/icon/units/).
Run: python3 tools/ui/icon_cut.py <sheet.png> <crop WxH+X+Y around the unit> <out.png>
"""
import sys, subprocess
src, geo, out = sys.argv[1:4]
# exact key at 6x, trim, then read raw
subprocess.run(["magick", src, "-crop", geo, "+repage", "-transparent", "#56782E", "-transparent", "#384B1E", "-trim", "+repage", out + ".6x.png"], check=True)
w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", out + ".6x.png"], capture_output=True, text=True).stdout.split())
raw = subprocess.run(["magick", out + ".6x.png", "rgba:-"], capture_output=True).stdout
W, H = w // 6, h // 6
px = [[tuple(raw[((y * 6 + 3) * w + x * 6 + 3) * 4:][:4]) for x in range(W)] for y in range(H)]
def olive(p):
    r, g, b, a = p
    return a > 0 and g > r + 8 and g > b + 30 and g < 150 and r < 120
for _ in range(2):
    kill = []
    for y in range(H):
        for x in range(W):
            if olive(px[y][x]):
                nb = [px[yy][xx] for yy, xx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)) if 0 <= yy < H and 0 <= xx < W]
                if len(nb) < 4 or any(n[3] == 0 for n in nb):
                    kill.append((y, x))
    for y, x in kill: px[y][x] = (0, 0, 0, 0)
data = bytes(c for row in px for p in row for c in p)
subprocess.run(["magick", "-size", f"{W}x{H}", "-depth", "8", "rgba:-", "-trim", "+repage", out], input=data, check=True)
