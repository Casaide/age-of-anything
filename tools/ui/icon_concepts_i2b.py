"""Writes the game icon concepts, round I2b (2026-10-19), into docs/concepts/icon/: the I2 ideas held to a new bar.
Dominic: "quill banner looks nice, but doesn't stand out". So every mark here has to stand out at a glance in a
Discord server list or a Steam library row: one dominant shape you'd know from its outline alone, high contrast
between subject and field, and a colour that pops on dark and light (the gold accent, not only lacquer and bronze).
Each sits in a circle-safe shield or roundel. The sheet adds a context strip: every option among made-up Discord
server icons (dark and light) and a row of dark library tiles, so standing out can be judged, not just legibility.
Run: python3 tools/ui/icon_concepts_i2b.py   (after tools/ui/icon_concepts.py; it reuses its look and sheet)

  C2 quill sword    I1's "write it, then fight it" as one shape: a sword whose blade is a quill, ink on gold
  F2 kit helm       the riveted helm as a dark silhouette on gold: horn one side, antenna the other, gold seams
  G2 stitched beast one head, two creatures: a bear's ear on one side, a frog's eye on the other, stitched down the middle
  H2 write it in    a dark crest with a gold prompt: the race is what you write (inverted: dark field, gold sign)
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402

INK, GOLD_HI, GOLD_LO = "#1f140b", "#ffe07a", "#e0a82a"
DEFS = (f'<linearGradient id="gold" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="{GOLD_HI}"/>'
        f'<stop offset="1" stop-color="{GOLD_LO}"/></linearGradient>'
        '<linearGradient id="night" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#3a2614"/>'
        f'<stop offset="1" stop-color="{INK}"/></linearGradient>')
# the heater shield, a little smaller than I1's so the Discord circle doesn't clip its corners
SHIELD = "M96,72 H416 V250 C416,356 344,418 256,456 C168,418 96,356 96,250 Z"
DISC = "M256,30 A226,226 0 1,1 255.9,30 Z"


def edge(path, fill):
    """A field with a thick dark edge and a fine bronze line inside it: the outline that carries at 16 px."""
    return (f'<path d="{path}" fill="{fill}" stroke="{INK}" stroke-width="30" stroke-linejoin="round"/>'
            f'<path d="{path}" fill="none" stroke="{ic.METAL}" stroke-width="5" stroke-linejoin="round" '
            f'transform="translate(256,256) scale(0.93) translate(-256,-256)"/>')


def option_c2():
    """The quill sword, upright: a feather for a blade (two nicks in its vane), crossguard, grip, pommel."""
    vane = ("M256,68 C312,108 334,176 326,236 L304,232 L322,260 C316,286 302,302 288,310 L224,310 "
            "C206,294 194,266 190,236 L212,226 L188,206 C188,150 214,104 256,68 Z")
    body = (edge(SHIELD, "url(#gold)")
            + f'<g transform="translate(256,262) scale(0.86) translate(-256,-238)"><path d="{vane}" fill="{INK}"/>'
            f'<path d="M256,96 C254,170 252,250 256,312" fill="none" stroke="url(#gold)" stroke-width="8" stroke-linecap="round"/>'
            f'<rect x="146" y="306" width="220" height="40" rx="20" fill="{INK}"/>'
            f'<rect x="234" y="340" width="44" height="52" fill="{INK}"/>'
            f'<circle cx="256" cy="404" r="28" fill="{INK}"/><circle cx="256" cy="404" r="10" fill="url(#gold)"/></g>')
    return ic.svg(body, DEFS)


def option_f2():
    dome = ("M150,290 C142,166 198,112 256,112 C314,112 370,166 362,290 C362,350 336,392 296,404 L284,330 L228,330 "
            "L216,404 C176,392 150,350 150,290 Z")
    body = (edge(DISC, "url(#gold)")
            + f'<path d="M184,190 C120,182 92,140 90,70 C118,114 150,130 196,140 Z" fill="{INK}"/>'
            f'<path d="M318,150 C336,112 364,90 400,82" fill="none" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
            f'<circle cx="404" cy="80" r="20" fill="{INK}"/>'
            f'<path d="{dome}" fill="{INK}"/>'
            # the seams and rivets in gold: halves of different metal, a brim, the face slot
            f'<path d="M256,124 V256" stroke="url(#gold)" stroke-width="8"/>'
            f'<path d="M156,262 C210,246 302,246 356,262" fill="none" stroke="url(#gold)" stroke-width="8"/>'
            + "".join(f'<circle cx="{x}" cy="{y}" r="7" fill="url(#gold)"/>' for x, y in
                      ((236, 160), (276, 160), (236, 205), (276, 205), (180, 352), (332, 352)))
            + f'<path d="M176,300 C196,284 226,282 244,292 L240,316 C218,312 196,314 180,322 Z" fill="url(#gold)"/>'
            f'<path d="M336,300 C316,284 286,282 268,292 L272,316 C294,312 316,314 332,322 Z" fill="url(#gold)"/>')
    return ic.svg(body, DEFS)


def option_g2():
    silhouette = (f'<circle cx="170" cy="166" r="50" fill="{INK}"/>'
                  f'<circle cx="300" cy="150" r="56" fill="{INK}"/>'
                  f'<path d="M128,290 C128,206 186,170 256,170 C326,170 384,206 384,290 C384,372 324,408 256,408 C188,408 128,372 128,290 Z" fill="{INK}"/>')
    detail = (f'<circle cx="166" cy="162" r="18" fill="url(#gold)"/>'        # the bear's inner ear
              f'<circle cx="300" cy="148" r="32" fill="url(#gold)"/>'                      # the frog's eye
              f'<ellipse cx="300" cy="150" rx="18" ry="9" fill="{INK}"/>'
              f'<circle cx="196" cy="266" r="12" fill="url(#gold)"/>'                       # the bear's eye
              f'<path d="M184,324 C200,340 230,342 248,334" fill="none" stroke="url(#gold)" stroke-width="10" stroke-linecap="round"/>'
              f'<path d="M264,332 Q316,350 356,306" fill="none" stroke="url(#gold)" stroke-width="10" stroke-linecap="round"/>'
              + "".join(f'<path d="M242,{y} L270,{y + 12}" stroke="url(#gold)" stroke-width="9" stroke-linecap="round"/>'
                        for y in range(196, 392, 30)))
    body = edge(DISC, "url(#gold)") + silhouette + detail
    return ic.svg(body, DEFS)


def option_h2():
    body = (edge(SHIELD, "url(#night)")
            + f'<path d="M150,190 L230,260 L150,330" fill="none" stroke="url(#gold)" stroke-width="44" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<rect x="282" y="160" width="52" height="200" rx="8" fill="url(#gold)"/>')
    return ic.svg(body, DEFS)


# Made-up neighbours for the context strip: flat circles with initials or a simple shape, the way community
# servers look; no real server's or game's icon.
NEIGHBOURS = [("#5865f2", "GN"), ("#3ba55c", "tri"), ("#ed4245", "LP"), ("#f0b232", "dot"), ("#2b2d31", "MS"),
              ("#9b59b6", "sq"), ("#1abc9c", "RV"), ("#e67e22", "tri")]


def neighbour(colour, mark, size):
    s = size / 48
    inner = {"tri": f'<path d="M{24 * s},{12 * s} L{36 * s},{34 * s} L{12 * s},{34 * s} Z" fill="#fff"/>',
             "dot": f'<circle cx="{24 * s}" cy="{24 * s}" r="{10 * s}" fill="#fff"/>',
             "sq": f'<rect x="{15 * s}" y="{15 * s}" width="{18 * s}" height="{18 * s}" rx="{3 * s}" fill="#fff"/>'}
    body = inner.get(mark, f'<text x="{24 * s}" y="{29 * s}" font-family="Helvetica, Arial, sans-serif" font-size="{14 * s}" '
                           f'font-weight="bold" fill="#fff" text-anchor="middle">{mark}</text>')
    return f'<circle cx="{size / 2}" cy="{size / 2}" r="{size / 2}" fill="{colour}"/>{body}'


def context(keys, out):
    """Discord's server list (48 px circles, dark #1e1f22 and light #e3e5e8) with the option fourth from the top, and a
    dark library row of 128 px tiles (muted made-up art) with the option among them, plus the library list at 32."""
    tmp = os.path.join(ic.OUT, ".ctx")
    os.makedirs(tmp, exist_ok=True)
    col_w, H = 760, 620
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{300 + col_w * len(keys)}" height="{H}">',
             f'<rect width="100%" height="100%" fill="#2b2420"/>',
             f'<text x="20" y="44" font-family="Georgia, serif" font-size="28" fill="{ic.TITLE}">Standing out: among made-up Discord servers '
             f'(48 px, dark and light) and a dark library (128 px tiles, 32 px list)</text>']
    tiles = [("#2a3440", "#141a20"), ("#3a2a2a", "#181010"), ("#22302a", "#0e1612"), ("#30303c", "#121218"), ("#3a3226", "#16120c")]
    for c, key in enumerate(keys):
        x0 = 300 + c * col_w
        svg = os.path.join(ic.OUT, f"{key}.svg")
        for px in (32, 48, 128):
            ic.render(svg, os.path.join(tmp, f"{key}_{px}.png"), px)
        parts.append(f'<text x="{x0}" y="92" font-family="Georgia, serif" font-size="26" font-weight="bold" fill="{ic.TEXT}">{key.split("_")[0].upper()}</text>')
        for b, (bg, x) in enumerate((("#1e1f22", x0), ("#e3e5e8", x0 + 84))):
            parts.append(f'<rect x="{x}" y="110" width="72" height="490" fill="{bg}"/>')
            for k in range(8):
                y = 122 + k * 58
                if k == 3:
                    parts.append(f'<image x="{x + 12}" y="{y}" width="48" height="48" xlink:href="{os.path.join(tmp, f"{key}_48.png")}"/>')
                else:
                    colour, mark = NEIGHBOURS[(k + c * 3 + b) % len(NEIGHBOURS)]
                    parts.append(f'<g transform="translate({x + 12},{y})">{neighbour(colour, mark, 48)}</g>')
        # the dark library: a 2x2 of tiles with the option at the top right, and a list row at 32 px
        lx = x0 + 190
        parts.append(f'<rect x="{lx}" y="110" width="540" height="490" fill="#171d25"/>')
        for k in range(4):
            tx, ty = lx + 20 + (k % 2) * 148, 130 + (k // 2) * 148
            if k == 1:
                parts.append(f'<rect x="{tx}" y="{ty}" width="128" height="128" fill="{ic.WELL}"/>'
                             f'<image x="{tx}" y="{ty}" width="128" height="128" xlink:href="{os.path.join(tmp, f"{key}_128.png")}"/>')
            else:
                a, z = tiles[(k + c) % len(tiles)]
                parts.append(f'<defs><linearGradient id="t{c}{k}" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="{a}"/>'
                             f'<stop offset="1" stop-color="{z}"/></linearGradient></defs>'
                             f'<rect x="{tx}" y="{ty}" width="128" height="128" fill="url(#t{c}{k})"/>'
                             f'<path d="M{tx},{ty + 96} L{tx + 40},{ty + 60} L{tx + 70},{ty + 84} L{tx + 100},{ty + 50} L{tx + 128},{ty + 80} V{ty + 128} H{tx} Z" fill="#000" opacity="0.35"/>')
        for k in range(4):
            ry = 440 + k * 40
            if k == 2:
                parts.append(f'<rect x="{lx + 10}" y="{ry - 4}" width="300" height="40" fill="#2a3a50"/>'
                             f'<image x="{lx + 16}" y="{ry}" width="32" height="32" xlink:href="{os.path.join(tmp, f"{key}_32.png")}"/>')
            else:
                a, _ = tiles[(k + c + 2) % len(tiles)]
                parts.append(f'<rect x="{lx + 16}" y="{ry}" width="32" height="32" fill="{a}"/>')
            parts.append(f'<rect x="{lx + 60}" y="{ry + 12}" width="{150 + (k * 37) % 90}" height="9" rx="4" fill="#8f98a0" opacity="0.6"/>')
    parts.append("</svg>")
    path = os.path.join(tmp, "ctx.svg")
    with open(path, "w") as f:
        f.write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", out, path], check=True)
    subprocess.run(["rm", "-rf", tmp], check=True)


def main():
    options = {"c2_quill_sword": option_c2(), "f2_kit_helm": option_f2(), "g2_stitched_beast": option_g2(), "h2_write_it_in": option_h2()}
    for key, text in options.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(text)
        print("wrote", key)
    ic.sheet([("c2_quill_sword", "C2  Quill sword|write it, then fight|it: one shape, ink|on gold"),
              ("f2_kit_helm", "F2  Kit helm|a riveted helm of odd|parts, dark on gold"),
              ("g2_stitched_beast", "G2  Stitched beast|bear's ear, frog's eye,|one head sewn down|the middle"),
              ("h2_write_it_in", "H2  Write it in|a gold prompt on a|dark crest")],
             ".sheet_i2b_sizes.png", "Game icon, concept round I2b: bold marks that stand out")
    sizes = os.path.join(ic.OUT, ".sheet_i2b_sizes.png")
    ctx = os.path.join(ic.OUT, ".sheet_i2b_ctx.png")
    context(list(options), ctx)
    subprocess.run(["magick", sizes, ctx, "-background", "#2b2420", "-gravity", "west", "-append",
                    os.path.join(ic.OUT, "sheet_i2b.png")], check=True)
    os.remove(sizes)
    os.remove(ctx)
    print("wrote sheet_i2b.png")


if __name__ == "__main__":
    main()
