"""Writes the fresh round of game icon concepts (2026-10-19) into docs/concepts/icon/fresh/, starting from research on
the genre's Steam icons rather than from rounds I1-I6 (docs/concepts/icon/fresh/README.md has the findings).
Every option is flat (one field, one or two shape colours, at most one accent), full-bleed square (the platforms
round the corners), with its subject inside the circle Discord crops to, and no lettering.
Run: python3 tools/ui/icon_concepts_fresh.py   (needs rsvg-convert and ImageMagick)

  N1 selected     the genre's own sign for "this is your unit": selection corners and a health bar round an odd soldier
  N2 flip book    a face in three strips from three creatures, slid out of line like a mix-and-match flip book
  N3 odd squad    a shield wall of three soldiers, every head a different creature: an army of anyone
  N4 parts kit    a model kit's frame with the parts still on it: a frog's head, a horned helm, a shield, a sword
  N5 pixel recruit  a frog legionary hand-placed on a 32 px grid: sharp at 16 and 32, the game's pixel look at 512
"""
import base64
import os
import subprocess

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "docs", "concepts", "icon", "fresh")
TMP = os.path.join(OUT, ".tmp")

INK, BONE, GOLD, RED, BLUE, LIME, NAVY, TEAL = ("#17120e", "#f3e8cf", "#f2c94c", "#b8321f", "#2346a0", "#9be35a",
                                                "#14213d", "#1e6e6a")


def flat(field, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" '
            f'viewBox="0 0 512 512"><rect width="512" height="512" fill="{field}"/>{body}</svg>\n')


def spear(x, top, bottom, fill, w=12):
    return (f'<rect x="{x - w / 2}" y="{top + 30}" width="{w}" height="{bottom - top - 30}" fill="{fill}"/>'
            f'<path d="M{x},{top} C{x + 16},{top + 18} {x + 14},{top + 34} {x},{top + 48} C{x - 14},{top + 34} {x - 16},{top + 18} {x},{top} Z" fill="{fill}"/>')


# N1: a rat soldier in profile, round shield and spear, inside lime selection corners with a health bar above.
def option_n1():
    gap = f'stroke="{BLUE}" stroke-width="12" stroke-linejoin="round"'
    rat = (f'<path d="M304,410 C340,420 372,404 380,376 C386,354 372,338 352,344" fill="none" stroke="{BONE}" stroke-width="12" stroke-linecap="round"/>'
           f'<path d="M206,420 C196,350 210,286 262,268 C306,254 330,300 326,360 C324,394 318,412 310,420 Z" fill="{BONE}"/>'
           f'<path d="M214,268 C206,226 228,196 262,196 C286,196 306,206 324,222 L366,236 C372,244 366,252 356,252 '
           f'C330,264 300,282 262,286 C236,288 218,284 214,268 Z" fill="{BONE}" {gap}/>'
           f'<ellipse cx="236" cy="190" rx="28" ry="34" fill="{BONE}" {gap}/>'
           f'<circle cx="300" cy="226" r="8" fill="{BLUE}"/>')
    weapon = spear(352, 132, 430, BONE, 11)
    shield = (f'<circle cx="214" cy="356" r="72" fill="{BONE}" {gap}/>'
              f'<circle cx="214" cy="356" r="50" fill="none" stroke="{BLUE}" stroke-width="8"/>'
              f'<circle cx="214" cy="356" r="16" fill="{BLUE}"/>')
    hand = f'<circle cx="340" cy="312" r="16" fill="{BONE}" {gap}/>'
    x0, x1, y0, y1, L, w = 92, 420, 116, 444, 64, 18   # the selection square, arm length, line width
    corners = "".join(
        f'<path d="M{x + sx * L},{y} H{x} V{y + sy * L}" fill="none" stroke="{LIME}" stroke-width="{w}" stroke-linecap="square"/>'
        for x, y, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)))
    bar = (f'<rect x="146" y="70" width="220" height="26" fill="{NAVY}"/>'
           f'<rect x="146" y="70" width="160" height="26" fill="{LIME}"/>')
    unit = f'<g transform="translate(256,292) scale(1.04) translate(-262,-290)">{weapon + rat + hand + shield}</g>'
    return flat(BLUE, unit + corners + bar)


# N2: three strips of three creatures (an iron horned helm, a frog's eyes, a rat's snout), slid out of line.
def option_n2():
    def strip(x, y, w, h, fill, body, cut="mid"):
        shape = {"mid": f'<rect width="{w}" height="{h}" rx="26" fill="{fill}"/>',
                 "top": f'<path d="M0,{h} V56 C0,14 60,0 {w / 2},0 C{w - 60},0 {w},14 {w},56 V{h} Z" fill="{fill}"/>',
                 "chin": f'<path d="M0,0 H{w} V36 C{w},86 {w - 60},{h} {w / 2},{h} C60,{h} 0,86 0,36 Z" fill="{fill}"/>'}[cut]
        return f'<g transform="translate({x},{y})">{shape}{body}</g>'
    iron, horn, frog, fur, pink = "#3d4048", BONE, "#4f9a3a", "#7a4a2c", "#e89aa0"
    helm = (f'<path d="M-36,96 C-70,70 -78,26 -56,-10 C-46,30 -20,52 20,62 Z" fill="{horn}"/>'
            f'<path d="M316,96 C350,70 358,26 336,-10 C326,30 300,52 260,62 Z" fill="{horn}"/>'
            f'<rect x="132" y="0" width="16" height="100" fill="{INK}" opacity="0.35"/>'
            + "".join(f'<circle cx="{cx}" cy="78" r="7" fill="{INK}" opacity="0.4"/>' for cx in (40, 90, 190, 240)))
    eyes = "".join(f'<circle cx="{cx}" cy="52" r="42" fill="{BONE}"/><circle cx="{cx + 14}" cy="60" r="20" fill="{INK}"/>'
                   for cx in (78, 202))
    snout = (f'<path d="M110,18 Q140,0 170,18 Q160,40 140,42 Q120,40 110,18 Z" fill="{pink}"/>'
             f'<rect x="122" y="58" width="16" height="30" rx="3" fill="{BONE}"/><rect x="142" y="58" width="16" height="30" rx="3" fill="{BONE}"/>'
             f'<path d="M140,42 V56 M96,58 Q140,64 184,58" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
             + "".join(f'<path d="M{x0},{y0} L{x1},{y1}" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>'
                       for x0, y0, x1, y1 in ((88, 30, 18, 18), (88, 44, 16, 52), (192, 30, 262, 18), (192, 44, 264, 52))))
    return flat(GOLD, strip(116, 96, 280, 100, iron, helm, "top") + strip(88, 212, 280, 104, frog, eyes)
                + strip(136, 332, 280, 104, fur, snout, "chin"))


# N3: a shield wall of three, one bone silhouette on red: a rat (snout left), a frog (eye bumps), a bird (beak right).
def option_n3():
    gap = f'stroke="{RED}" stroke-width="12" stroke-linejoin="round"'
    spears = spear(74, 124, 330, BONE) + spear(300, 70, 300, BONE) + spear(438, 124, 330, BONE)
    bodies = (f'<path d="M78,330 C78,276 100,256 136,256 C172,256 194,276 194,330 Z" fill="{BONE}"/>'
              f'<path d="M318,330 C318,276 340,256 376,256 C412,256 434,276 434,330 Z" fill="{BONE}"/>'
              f'<path d="M190,320 C190,262 216,240 256,240 C296,240 322,262 322,320 Z" fill="{BONE}" {gap}/>')
    rat = (f'<ellipse cx="156" cy="170" rx="24" ry="30" fill="{BONE}"/>'
           f'<path d="M178,212 C178,188 160,176 138,178 C118,180 106,192 98,206 L66,226 C62,232 66,238 74,238 L104,240 '
           f'C116,252 130,256 144,256 C164,256 178,238 178,212 Z" fill="{BONE}" {gap}/>'
           f'<circle cx="68" cy="230" r="9" fill="{BONE}"/>'
           f'<circle cx="126" cy="206" r="7" fill="{RED}"/>')
    bird = (f'<path d="M346,190 C326,170 322,146 336,124 C342,148 358,160 378,170 Z" fill="{BONE}"/>'
            f'<circle cx="372" cy="214" r="40" fill="{BONE}" {gap}/>'
            f'<path d="M404,200 L446,218 L404,234 Z" fill="{BONE}"/>'
            f'<circle cx="388" cy="208" r="7" fill="{RED}"/>')
    frog = (f'<path d="M196,226 C196,186 222,166 256,166 C290,166 316,186 316,226 C316,250 292,258 256,258 C220,258 196,250 196,226 Z" fill="{BONE}" {gap}/>'
            f'<circle cx="222" cy="166" r="26" fill="{BONE}"/><circle cx="290" cy="166" r="26" fill="{BONE}"/>'
            f'<circle cx="222" cy="164" r="10" fill="{RED}"/><circle cx="290" cy="164" r="10" fill="{RED}"/>'
            f'<path d="M222,222 Q256,240 290,222" fill="none" stroke="{RED}" stroke-width="8" stroke-linecap="round"/>')

    def shield(cx, cy, r):
        return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{BONE}" {gap}/>'
                f'<circle cx="{cx}" cy="{cy}" r="{r - 20}" fill="none" stroke="{RED}" stroke-width="7"/>'
                f'<circle cx="{cx}" cy="{cy}" r="15" fill="{RED}"/>')
    def big(body, cx):
        return f'<g transform="translate({cx},256) scale(1.12) translate({-cx},-256)">{body}</g>'
    return flat(RED, spears + bodies + big(rat, 136) + big(bird, 376) + big(frog, 256) + shield(128, 370, 74) + shield(384, 370, 74) + shield(256, 360, 80))


# N4: a model kit's frame (a ring runner and a cross), parts hanging on little gates.
def option_n4():
    p = BONE
    frame = (f'<rect x="88" y="88" width="336" height="336" rx="54" fill="none" stroke="{p}" stroke-width="20"/>'
             f'<path d="M256,98 V414 M98,256 H414" stroke="{p}" stroke-width="14"/>')

    def gate(x0, y0, x1, y1):
        return f'<path d="M{x0},{y0} L{x1},{y1}" stroke="{p}" stroke-width="7"/>'
    frog = (f'<g transform="translate(172,182)"><path d="M-56,22 C-56,-14 -30,-30 0,-30 C30,-30 56,-14 56,22 C56,42 30,48 0,48 C-30,48 -56,42 -56,22 Z" fill="{p}"/>'
            f'<circle cx="-28" cy="-30" r="22" fill="{p}"/><circle cx="28" cy="-30" r="22" fill="{p}"/>'
            f'<circle cx="-28" cy="-31" r="9" fill="{NAVY}"/><circle cx="28" cy="-31" r="9" fill="{NAVY}"/>'
            f'<path d="M-28,16 Q0,32 28,16" fill="none" stroke="{NAVY}" stroke-width="7" stroke-linecap="round"/></g>'
            + gate(228, 190, 250, 190) + gate(172, 230, 172, 250))
    helm = (f'<g transform="translate(340,186)"><path d="M-44,30 C-44,-12 -24,-34 0,-34 C24,-34 44,-12 44,30 Z" fill="{p}"/>'
            f'<path d="M-40,8 C-70,-4 -78,-30 -66,-56 C-60,-34 -50,-20 -32,-14 Z" fill="{p}"/>'
            f'<path d="M40,8 C70,-4 78,-30 66,-56 C60,-34 50,-20 32,-14 Z" fill="{p}"/>'
            f'<rect x="-6" y="-2" width="12" height="44" fill="{p}"/><rect x="-44" y="22" width="88" height="12" fill="{NAVY}"/></g>'
            + gate(296, 200, 262, 200) + gate(340, 228, 340, 250))
    shield = (f'<circle cx="172" cy="340" r="54" fill="{p}"/><circle cx="172" cy="340" r="36" fill="none" stroke="{NAVY}" stroke-width="7"/>'
              f'<circle cx="172" cy="340" r="12" fill="{NAVY}"/>' + gate(226, 340, 250, 340) + gate(172, 286, 172, 262))
    sword = (f'<g transform="translate(340,340) rotate(45)"><path d="M-9,-66 L0,-80 L9,-66 V30 H-9 Z" fill="{p}"/>'
             f'<rect x="-30" y="30" width="60" height="12" rx="4" fill="{p}"/><rect x="-6" y="42" width="12" height="26" fill="{p}"/>'
             f'<circle cx="0" cy="74" r="9" fill="{p}"/></g>' + gate(300, 300, 262, 262) + gate(372, 372, 400, 400))
    return flat(NAVY, frame + frog + helm + shield + sword)


# N5: a frog legionary on a 32 px grid (helm with a red crest, eyes under the brim, red shield, spear, a shadow).
PX = {"k": "#1a1410", "G": "#62b046", "g": "#3a7a2c", "W": "#f6f1e2", "B": "#1a1410", "H": "#aab4bd", "h": "#6b7680",
      "R": "#d83a2a", "r": "#9a2418", "S": "#c8321f", "s": "#86200f", "Y": "#f2c94c", "T": "#8a5a32", "P": "#e8e2d2",
      "D": "#2e1a52"}
GRID = [
    "................................",
    "................................",
    ".........................P......",
    "............RRRRRR......PPP.....",
    "...........RRRRRRRR.....PPP.....",
    "...........rRRRRRRr......T......",
    "............HHHHHH.......T......",
    "...........HHHHHHHH......T......",
    ".....GGG..HHHHHHHHHH..GGGT......",
    "....GWWWG.hhhhhhhhhh.GWWWG......",
    "....GWBBGGGGGGGGGGGGGGBBWG......",
    "....GWBBGGGGGGGGGGGGGGBBWG......",
    "....GGWWGGGGGGGGGGGGGGWWGG......",
    "....GGGGGGGGGGGGGGGGGGGGGG......",
    ".....GGgggggggggggggggggG.......",
    "......GGGGGGGGGGGGGGGGGG..T.....",
    "........GGGGGGGGGGGGGG..GGT.....",
    "....SSSSSS.GGGGGGGGGGGGGGGT.....",
    "...SSSSSSSS.GGGGGGGGGG..GGT.....",
    "..SSsSSSSsSS.GGGGGGGGG...T......",
    "..SSSSYYSSSS.GGGGGGGGG...T......",
    "..SSSYYYYSSS.GGGGGGGGG...T......",
    "..SSSSYYSSSS.GGGGGGGGG...T......",
    "..SSsSSSSsSS.GGGGGGGGG...T......",
    "...SSSSSSSS.GGGGGGGGGG...T......",
    "....SSSSSS...gg....gg....T......",
    ".............gg....gg....T......",
    ".............gg....gg....T......",
    "............GGGG..GGGG..........",
    "................................",
    "................................",
    "................................",
]


GRID16 = [   # the same frog drawn again for 16 px, pixel by pixel (scaling the 32 down blurs it)
    "................",
    ".......RRRR...P.",
    "......RRRRRR..P.",
    ".......HHHH...T.",
    "...GGGhhhhhhGGT.",
    "...GWBGGGGGGBWT.",
    "...GGGGGGGGGGGT.",
    "....GgggggggGGT.",
    ".....GGGGGGG.GT.",
    "..SSS.GGGGGGGGT.",
    ".SSYSS.GGGGG..T.",
    ".SYYYS.GGGGG..T.",
    ".SSYSS.GGGGG..T.",
    "..SSS.gg..gg..T.",
    "...DDDggDDggDD..",
    "................",
]


def pixel_png(path, field, grid):
    """A grid with a dark outline round the figure, as a PNG; the 32 gets its shadow drawn here."""
    n = len(grid)
    rows = [list(r) for r in grid]
    solid = {c for c in PX if c != "D"}
    if n == 32:
        for y in range(n):   # the selection ring round the feet, behind the figure
            for x in range(n):
                d = ((x + 0.5 - 16) / 11) ** 2 + ((y + 0.5 - 28.5) / 2.2) ** 2
                if d < 1 and rows[y][x] == ".":
                    rows[y][x] = "D"
    out = [r[:] for r in rows]
    for y in range(n):
        for x in range(n):
            if rows[y][x] in ".D":
                near = any(0 <= y + dy < n and 0 <= x + dx < n and rows[y + dy][x + dx] in solid
                           for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)))
                if near and rows[y][x] == ".":
                    out[y][x] = "k"
    ppm = f"P3 {n} {n} 255\n" + "\n".join(" ".join(
        " ".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5)) for h in (PX.get(c, field) for c in row)) for row in out)
    with open(path + ".ppm", "w") as f:
        f.write(ppm + "\n")
    subprocess.run(["magick", path + ".ppm", path], check=True)


def option_n5():
    path = os.path.join(TMP, "n5_32.png")
    pixel_png(path, "#4a2c7a", GRID)
    pixel_png(os.path.join(TMP, "n5_16.png"), "#4a2c7a", GRID16)
    big = os.path.join(TMP, "n5_512.png")
    subprocess.run(["magick", path, "-filter", "point", "-resize", "512x512", big], check=True)
    with open(big, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    return flat("#4a2c7a", f'<image x="0" y="0" width="512" height="512" style="image-rendering:pixelated" '
                           f'xlink:href="data:image/png;base64,{data}"/>')


OPTIONS = {
    "n1_selected": (option_n1, "N1 Selected"),
    "n2_flip_book": (option_n2, "N2 Flip book"),
    "n3_odd_squad": (option_n3, "N3 Odd squad"),
    "n4_parts_kit": (option_n4, "N4 Parts kit"),
    "n5_pixel_recruit": (option_n5, "N5 Pixel recruit"),
}


def render(key, px):
    """The option at px: drawn at 512 and scaled down the way the platforms do (Lanczos); N5's 16 and 32 are its grid."""
    big = os.path.join(TMP, f"{key}_512.png")
    if not os.path.exists(big):
        subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", "-o", big, os.path.join(OUT, f"{key}.svg")], check=True)
    out = os.path.join(TMP, f"{key}_{px}.png")
    if key == "n5_pixel_recruit" and px <= 32:
        out = os.path.join(TMP, f"n5_{px}.png")
    elif px != 512:
        subprocess.run(["magick", big, "-filter", "Lanczos", "-resize", f"{px}x{px}", out], check=True)
    else:
        out = big
    return out


def blow(src, scale):
    out = src.replace(".png", f"_x{scale}.png")
    subprocess.run(["magick", src, "-filter", "point", "-resize", f"{scale * 100}%", out], check=True)
    return out


def img(x, y, path, w, clip=None):
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    c = f' clip-path="url(#{clip})"' if clip else ""
    return f'<image x="{x}" y="{y}" width="{w}" height="{w}" xlink:href="data:image/png;base64,{data}"{c}/>'


FONT = 'font-family="Helvetica, Arial, sans-serif"'
NEIGHBOURS = [("#5865f2", "dot"), ("#2b2d31", "tri"), ("#3ba55d", "sq"), ("#2b2d31", "ring"), ("#ed4245", "tri"),
              ("#1f2a44", "sq"), ("#4e5058", "dot"), ("#9b59b6", "ring"), ("#2b2d31", "sq"), ("#e67e22", "dot")]
LIB = [("#20262e", "#c9b98a", "tower"), ("#101418", "#d8d8d8", "ring"), ("#2a1612", "#d9a441", "sun"),
       ("#0f1a24", "#7fb6d9", "tri"), ("#151515", "#e0d2b0", "bars"), ("#1c2a1e", "#b8c9a0", "leaf"),
       ("#241d2e", "#c8b3e0", "dot"), ("#121820", "#d0c090", "tower")]


def glyph(kind, x, y, s, fill):
    """A plain made-up emblem for a neighbouring icon (s = its size): nothing from a real game."""
    c, r = (x + s / 2, y + s / 2), s * 0.28
    return {
        "dot": f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="{fill}"/>',
        "ring": f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="none" stroke="{fill}" stroke-width="{s * 0.09}"/>',
        "tri": f'<path d="M{c[0]},{c[1] - r} L{c[0] + r},{c[1] + r * 0.8} L{c[0] - r},{c[1] + r * 0.8} Z" fill="{fill}"/>',
        "sq": f'<rect x="{c[0] - r * 0.8}" y="{c[1] - r * 0.8}" width="{r * 1.6}" height="{r * 1.6}" rx="{s * 0.05}" fill="{fill}"/>',
        "tower": f'<path d="M{c[0] - r * 0.6},{c[1] + r} V{c[1] - r * 0.6} H{c[0] - r * 0.9} V{c[1] - r} H{c[0] + r * 0.9} '
                 f'V{c[1] - r * 0.6} H{c[0] + r * 0.6} V{c[1] + r} Z" fill="{fill}"/>',
        "sun": f'<circle cx="{c[0]}" cy="{c[1]}" r="{r * 0.6}" fill="{fill}"/>' + "".join(
            f'<rect x="{c[0] - s * 0.025}" y="{c[1] - r * 1.15}" width="{s * 0.05}" height="{r * 0.35}" fill="{fill}" '
            f'transform="rotate({a} {c[0]} {c[1]})"/>' for a in range(0, 360, 45)),
        "bars": "".join(f'<rect x="{c[0] - r + i * r * 0.75}" y="{c[1] - r}" width="{r * 0.45}" height="{r * 2}" fill="{fill}"/>'
                        for i in range(3)),
        "leaf": f'<path d="M{c[0]},{c[1] - r} C{c[0] + r},{c[1] - r * 0.3} {c[0] + r * 0.6},{c[1] + r} {c[0]},{c[1] + r} '
                f'C{c[0] - r * 0.6},{c[1] + r} {c[0] - r},{c[1] - r * 0.3} {c[0]},{c[1] - r} Z" fill="{fill}"/>',
    }[kind]


def sheet(path):
    """One row per option: 512, then 128/64/32/16 on dark and on light, the 16 and 32 blown up, the Discord circle,
    the option fourth in made-up Discord server lists (dark, light), and in a dark library (128 tiles, a 16 px list)."""
    W, rowh, top = 2900, 600, 110
    keys = list(OPTIONS)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{top + rowh * len(keys)}">'
         f'<defs><clipPath id="disc"><circle cx="64" cy="64" r="64"/></clipPath></defs>'
         f'<rect width="100%" height="100%" fill="#202124"/>'
         f'<text x="30" y="50" {FONT} font-size="30" font-weight="bold" fill="#f3e8cf">Game icon, fresh round (N1-N5)</text>'
         f'<text x="30" y="84" {FONT} font-size="18" fill="#b8b2a4">512 | 128, 64, 32, 16 on dark and light | 16 x8 and 32 x4, pixels as shown | '
         f'Discord circle | 4th in Discord server lists, dark and light | dark library: 128 tiles, 16 px list row</text>']
    for i, key in enumerate(keys):
        y0 = top + i * rowh
        r = {px: render(key, px) for px in (16, 32, 48, 64, 128, 512)}
        s.append(f'<text x="30" y="{y0 + 30}" {FONT} font-size="24" font-weight="bold" fill="#f3e8cf">{OPTIONS[key][1]}</text>')
        s.append(img(30, y0 + 50, r[512], 512))
        for b, bg in enumerate(("#121212", "#f4f4f2")):
            x = 570 + b * 300
            s.append(f'<rect x="{x}" y="{y0 + 50}" width="280" height="290" fill="{bg}"/>')
            s.append(img(x + 12, y0 + 62, r[128], 128))
            s.append(img(x + 152, y0 + 62, r[64], 64))
            s.append(img(x + 152, y0 + 140, r[32], 32))
            s.append(img(x + 196, y0 + 148, r[16], 16))
            s.append(img(x + 12, y0 + 212, r[32], 32) + img(x + 56, y0 + 220, r[16], 16))
            s.append(f'<text x="{x + 12}" y="{y0 + 326}" {FONT} font-size="13" fill="#888">128 . 64 . 32 . 16</text>')
        s.append(img(570, y0 + 360, blow(r[16], 8), 128) + img(718, y0 + 360, blow(r[32], 4), 128))
        s.append(f'<text x="570" y="{y0 + 512}" {FONT} font-size="13" fill="#888">16 at x8 . 32 at x4 . Discord circle, dark and light</text>')
        s.append(f'<rect x="870" y="{y0 + 352}" width="280" height="144" fill="#313338"/>'
                 f'<g transform="translate(878,{y0 + 360})">{img(0, 0, r[128], 128, "disc")}</g>'
                 f'<g transform="translate(1014,{y0 + 360})"><circle cx="64" cy="64" r="64" fill="#fff"/>{img(0, 0, r[128], 128, "disc")}</g>')
        # Discord server lists, dark and light, 48 px circles with the option 4th
        for b, (bg, pill) in enumerate((("#1e1f22", "#f2f3f5"), ("#e3e5e8", "#060607"))):
            x = 1190 + b * 90
            s.append(f'<rect x="{x}" y="{y0 + 50}" width="72" height="530" fill="{bg}"/>')
            for k in range(9):
                yy = y0 + 62 + k * 57
                if k == 3:
                    s.append(f'<rect x="{x}" y="{yy + 4}" width="4" height="40" rx="2" fill="{pill}"/>'
                             f'<g transform="translate({x + 12},{yy}) scale(0.375)">{img(0, 0, r[128], 128, "disc")}</g>')
                else:
                    col, kind = NEIGHBOURS[(k + i * 2 + b * 3) % len(NEIGHBOURS)]
                    s.append(f'<circle cx="{x + 36}" cy="{yy + 24}" r="24" fill="{col}"/>' + glyph(kind, x + 12, yy, 48, "#fff"))
        # a dark library: a 3x2 of 128 tiles with the option in the middle of the top row, then a list row at 16 px
        lx = 1380
        s.append(f'<rect x="{lx}" y="{y0 + 50}" width="470" height="530" fill="#171d25"/>')
        for k in range(6):
            tx, ty = lx + 14 + (k % 3) * 152, y0 + 64 + (k // 3) * 152
            if k == 1:
                s.append(img(tx, ty, r[128], 128))
            else:
                bgc, fg, kind = LIB[(k + i) % len(LIB)]
                s.append(f'<rect x="{tx}" y="{ty}" width="128" height="128" fill="{bgc}"/>' + glyph(kind, tx, ty, 128, fg))
        for k in range(6):
            ry = y0 + 380 + k * 32
            if k == 2:
                s.append(f'<rect x="{lx + 8}" y="{ry - 6}" width="454" height="28" fill="#3d4450"/>' + img(lx + 16, ry, r[16], 16))
            else:
                bgc, fg, kind = LIB[(k + i + 3) % len(LIB)]
                s.append(f'<rect x="{lx + 16}" y="{ry}" width="16" height="16" fill="{bgc}"/>' + glyph(kind, lx + 16, ry, 16, fg))
            s.append(f'<rect x="{lx + 44}" y="{ry + 5}" width="{120 + (k * 53) % 140}" height="7" rx="3" fill="#8f98a0" opacity="0.6"/>')
        # the 32 px list size too (Steam's store list and search), among the library glyphs
        s.append(f'<rect x="1870" y="{y0 + 50}" width="240" height="530" fill="#1b2838"/>')
        for k in range(10):
            ry = y0 + 62 + k * 51
            if k == 4:
                s.append(f'<rect x="1870" y="{ry - 6}" width="240" height="44" fill="#2a475e"/>' + img(1882, ry, r[32], 32))
            else:
                bgc, fg, kind = LIB[(k * 3 + i) % len(LIB)]
                s.append(f'<rect x="1882" y="{ry}" width="32" height="32" fill="{bgc}"/>' + glyph(kind, 1882, ry, 32, fg))
            s.append(f'<rect x="1926" y="{ry + 12}" width="{90 + (k * 41) % 80}" height="8" rx="3" fill="#8f98a0" opacity="0.6"/>')
        # an app icon on a dock / home screen: rounded square at 128 and 64
        s.append(f'<rect x="2130" y="{y0 + 50}" width="740" height="290" fill="#3a3f4a"/>'
                 f'<defs><clipPath id="sq{i}"><rect width="128" height="128" rx="28"/></clipPath></defs>'
                 f'<g transform="translate(2150,{y0 + 70})">{img(0, 0, r[128], 128, f"sq{i}")}</g>')
        for k in range(4):
            bgc, fg, kind = LIB[(k + i + 1) % len(LIB)]
            s.append(f'<rect x="{2300 + k * 140}" y="{y0 + 70}" width="128" height="128" rx="28" fill="{bgc}"/>'
                     + glyph(kind, 2300 + k * 140, y0 + 70, 128, fg))
        s.append(f'<text x="2150" y="{y0 + 240}" {FONT} font-size="16" fill="#cfd3da">app icon, rounded by the platform</text>')
    s.append("</svg>")
    tmp = os.path.join(TMP, "sheet.svg")
    with open(tmp, "w") as f:
        f.write("".join(s))
    subprocess.run(["rsvg-convert", "-o", path, tmp], check=True)


def main():
    os.makedirs(TMP, exist_ok=True)
    for key, (fn, _) in OPTIONS.items():
        with open(os.path.join(OUT, f"{key}.svg"), "w") as f:
            f.write(fn())
        subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", "-o", os.path.join(OUT, f"{key}.png"),
                        os.path.join(OUT, f"{key}.svg")], check=True)
        print("wrote", key)
    for px in (16, 32):
        subprocess.run(["magick", os.path.join(TMP, f"n5_{px}.png"), os.path.join(OUT, f"n5_pixel_recruit_{px}.png")], check=True)
    sheet(os.path.join(OUT, "sheet_fresh.png"))
    subprocess.run(["rm", "-rf", TMP], check=True)
    print("wrote sheet_fresh.png")


if __name__ == "__main__":
    main()
