"""Writes the game icon concepts (round I1, 2026-10-19) into docs/concepts/icon/: four marks that don't need the
name, drawn at 512 in the timber-and-bronze look (data/ui.json), then a sheet of every option at 16, 32, 64,
128 and 512 px on dark and light, with the Discord circle crop. Nothing is wired into the game until Dominic
picks (D-080). Needs rsvg-convert and ImageMagick (Homebrew). Run: python3 tools/ui/icon_concepts.py

  A  frog crest      a viking frog's head, helm and horns, on a lacquer-red heater shield with a bronze rim
  B  unit shield     the game's own baked unit (docs/concepts/icon/units/, cut from tests/sheets/icon_i1.json by
                     tools/ui/icon_cut.py) on its meadow in a bronze ring; B1 the viking frog, B2 the rat on a bear
  C  quill banner    a swallowtail banner with a quill crossed over a sword: you write it, then you fight it
  D  odd helm        one helm worn by anything: a horn on one side, a rat's ear through the other, eyes inside
"""
import base64
import sys
import os
import subprocess

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "docs", "concepts", "icon")

# the timber direction's colours (data/ui.json)
BRONZE, METAL, GOLD, TITLE = "#9a7438", "#c09048", "#f2c94c", "#f6d77a"
WOOD, BUTTON, LACQUER, WELL, TEXT = "#4a3220", "#6a4a2c", "#7a2a18", "#17110b", "#f4e9cf"

DEFS = f"""<defs>
<linearGradient id="bronze" x1="0" y1="0" x2="0.3" y2="1">
 <stop offset="0" stop-color="#f3d58a"/><stop offset="0.35" stop-color="{METAL}"/><stop offset="0.7" stop-color="{BRONZE}"/><stop offset="1" stop-color="#5a3e18"/>
</linearGradient>
<linearGradient id="lacquer" x1="0" y1="0" x2="0" y2="1">
 <stop offset="0" stop-color="#a23a20"/><stop offset="1" stop-color="#561a0e"/>
</linearGradient>
<linearGradient id="cloth" x1="0" y1="0" x2="1" y2="0">
 <stop offset="0" stop-color="#6a2010"/><stop offset="0.45" stop-color="#9c3620"/><stop offset="1" stop-color="#5e1c0e"/>
</linearGradient>
<linearGradient id="iron" x1="0" y1="0" x2="0" y2="1">
 <stop offset="0" stop-color="#e4e2dc"/><stop offset="0.5" stop-color="#9a978f"/><stop offset="1" stop-color="#55524c"/>
</linearGradient>
<linearGradient id="horn" x1="0" y1="1" x2="0" y2="0">
 <stop offset="0" stop-color="#b8a67e"/><stop offset="1" stop-color="#f4ead2"/>
</linearGradient>
<linearGradient id="frog" x1="0" y1="0" x2="0" y2="1">
 <stop offset="0" stop-color="#8cc04a"/><stop offset="1" stop-color="#3e6a1e"/>
</linearGradient>
<radialGradient id="meadow" cx="0.5" cy="0.62" r="0.62">
 <stop offset="0" stop-color="#7a9a3e"/><stop offset="0.75" stop-color="#56782e"/><stop offset="1" stop-color="#34501a"/>
</radialGradient>
<radialGradient id="well" cx="0.5" cy="0.4" r="0.65">
 <stop offset="0" stop-color="#3a2818"/><stop offset="1" stop-color="{WELL}"/>
</radialGradient>
</defs>"""

SHIELD = "M70,58 H442 V248 C442,366 360,432 256,474 C152,432 70,366 70,248 Z"


def svg(body, extra_defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" '
            f'height="512" viewBox="0 0 512 512">{DEFS}{extra_defs}{body}</svg>\n')


def rim(path, width=26):
    """A bronze rim on a shape: a dark outer edge, the metal band, a fine light line inside."""
    return (f'<path d="{path}" fill="none" stroke="#2a1a0a" stroke-width="{width + 12}" stroke-linejoin="round"/>'
            f'<path d="{path}" fill="none" stroke="url(#bronze)" stroke-width="{width}" stroke-linejoin="round"/>'
            f'<path d="{path}" fill="none" stroke="#fff2c8" stroke-width="2" stroke-linejoin="round" opacity="0.35" '
            f'transform="translate(256,256) scale(0.955) translate(-256,-256)"/>')


def horn(side):
    """A curved horn from the helm's side (+1 right, -1 left), sweeping out and up."""
    def x(v):
        return 256 + side * (v - 256)
    return (f'<path d="M{x(206)},222 C{x(150)},214 {x(108)},176 {x(104)},90 C{x(134)},132 {x(166)},152 {x(214)},164 Z" '
            f'fill="url(#horn)" stroke="#2a1a0a" stroke-width="7" stroke-linejoin="round"/>')


def option_a():
    """The frog crest."""
    eye = lambda cx: (f'<circle cx="{cx}" cy="250" r="44" fill="url(#frog)" stroke="#1c2e0c" stroke-width="7"/>'
                      f'<circle cx="{cx}" cy="248" r="31" fill="{GOLD}" stroke="#1c2e0c" stroke-width="4"/>'
                      f'<ellipse cx="{cx}" cy="250" rx="15" ry="11" fill="#140c04"/>'
                      f'<circle cx="{cx - 11}" cy="237" r="7" fill="#fff8e0"/>')
    body = (f'<path d="{SHIELD}" fill="url(#lacquer)"/>'
            f'<path d="M70,58 H442 V100 H70Z" fill="#000" opacity="0.12"/>'
            + horn(-1) + horn(1) +
            # the head: wide and low, the mouth a long grin
            f'<path d="M126,322 C126,252 186,220 256,220 C326,220 386,252 386,322 C386,382 330,410 256,410 '
            f'C182,410 126,382 126,322Z" fill="url(#frog)" stroke="#1c2e0c" stroke-width="8"/>'
            f'<path d="M160,334 Q256,384 352,334" fill="none" stroke="#1c2e0c" stroke-width="9" stroke-linecap="round"/>'
            f'<circle cx="236" cy="300" r="5" fill="#1c2e0c"/><circle cx="276" cy="300" r="5" fill="#1c2e0c"/>'
            # the helm: a dome with a riveted brim, sitting between the eyes
            f'<path d="M176,240 C176,124 336,124 336,240 Z" fill="url(#iron)" stroke="#2a1a0a" stroke-width="8" stroke-linejoin="round"/>'
            f'<path d="M256,128 V236" stroke="{BRONZE}" stroke-width="16"/>'
            f'<path d="M206,170 C220,150 236,142 248,140" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity="0.5"/>'
            f'<rect x="166" y="226" width="180" height="28" rx="7" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="7"/>'
            + "".join(f'<circle cx="{x}" cy="240" r="5" fill="#fff2c8" opacity="0.85"/>' for x in (226, 256, 286))
            + eye(172) + eye(340) + rim(SHIELD))
    return svg(body)


def png_b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def option_b(unit, scale, oy=0):
    """A unit on the game's meadow in a round bronze-rimmed shield. The sprite is scaled up whole pixels first (no smoothing at 512)."""
    src = os.path.join(OUT, "units", unit + ".png")
    big = os.path.join(OUT, "units", f".{unit}_x{scale}.png")
    subprocess.run(["magick", src, "-filter", "point", "-resize", f"{scale * 100}%", big], check=True)
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", big],
                                   capture_output=True, text=True, check=True).stdout.split())
    data = png_b64(big)
    os.remove(big)
    clip = '<clipPath id="face"><circle cx="256" cy="256" r="206"/></clipPath>'
    x, y = 256 - w // 2, 256 + 150 - h + oy
    body = (f'<circle cx="256" cy="256" r="206" fill="url(#meadow)"/>'
            f'<g clip-path="url(#face)">'
            f'<ellipse cx="256" cy="{256 + 150 + oy - 8}" rx="{w * 0.42:.0f}" ry="22" fill="#000" opacity="0.4"/>'
            f'<image x="{x}" y="{y}" width="{w}" height="{h}" style="image-rendering:pixelated" '
            f'xlink:href="data:image/png;base64,{data}"/></g>'
            + rim("M256,50 A206,206 0 1,1 255.9,50 Z", 30)
            + "".join(f'<circle cx="{256 + 206 * c:.1f}" cy="{256 + 206 * s:.1f}" r="7" fill="#fff2c8" stroke="#2a1a0a" stroke-width="3"/>'
                      for c, s in ((0, -1), (1, 0), (0, 1), (-1, 0), (0.7071, 0.7071), (-0.7071, 0.7071), (0.7071, -0.7071), (-0.7071, -0.7071))))
    return svg(body, clip)


def option_c():
    """The quill banner: a swallowtail cloth on a bronze rod, a quill crossed over a sword."""
    cloth = "M118,86 H394 V468 L256,372 L118,468 Z"
    sword = (f'<g transform="rotate(38 256 236)">'
             f'<path d="M256,64 L276,96 V300 H236 V96 Z" fill="url(#iron)" stroke="#1a1006" stroke-width="7" stroke-linejoin="round"/>'
             f'<path d="M256,92 V292" stroke="#fff" stroke-width="4" opacity="0.5"/>'
             f'<rect x="196" y="298" width="120" height="22" rx="8" fill="url(#bronze)" stroke="#1a1006" stroke-width="7"/>'
             f'<rect x="242" y="318" width="28" height="56" fill="#4a3220" stroke="#1a1006" stroke-width="7"/>'
             f'<circle cx="256" cy="386" r="18" fill="url(#bronze)" stroke="#1a1006" stroke-width="7"/></g>')
    quill = (f'<g transform="rotate(-38 256 236)">'
             f'<path d="M256,384 L262,330 C306,270 312,170 268,70 C262,62 252,62 246,70 C204,170 210,270 250,330 Z" '
             f'fill="#f4ead2" stroke="#1a1006" stroke-width="7" stroke-linejoin="round"/>'
             + "".join(f'<path d="M256,{y} L{x},{y - 34}" stroke="#b8a67e" stroke-width="4"/>' for x, y in
                       ((226, 160), (286, 160), (222, 210), (290, 210), (228, 260), (284, 260)))
             + f'<path d="M256,96 V396" stroke="#8a7a58" stroke-width="5"/>'
             f'<path d="M250,380 L256,412 L262,380 Z" fill="#2a1a0a"/></g>')
    body = (f'<path d="M108,86 V96" stroke="none"/>'
            f'<path d="{cloth}" fill="#2a1a0a" transform="translate(6,8)" opacity="0.5"/>'
            f'<path d="{cloth}" fill="url(#cloth)" stroke="#2a1a0a" stroke-width="10" stroke-linejoin="round"/>'
            f'<path d="M140,86 V420 M372,86 V420" stroke="{GOLD}" stroke-width="6" opacity="0.75"/>'
            + quill + sword +
            f'<rect x="74" y="62" width="364" height="28" rx="14" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>'
            f'<circle cx="74" cy="76" r="24" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>'
            f'<circle cx="438" cy="76" r="24" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>')
    return svg(body)


def option_d():
    """The odd helm: a horn left, a rat's ear right, eyes in the dark inside, on a wooden roundel."""
    ear = (f'<path d="M318,190 C330,108 400,72 440,104 C470,130 446,206 368,234 Z" fill="#a8a29a" stroke="#1a1006" stroke-width="8" stroke-linejoin="round"/>'
           f'<path d="M336,190 C350,132 398,108 424,126 C442,142 424,192 368,214 Z" fill="#e6a0a0"/>')
    left = (f'<path d="M188,206 C130,200 82,160 78,64 C108,118 146,140 196,158 Z" fill="url(#horn)" stroke="#1a1006" stroke-width="8" stroke-linejoin="round"/>')
    helm = (f'<path d="M150,330 C142,190 196,130 256,130 C316,130 370,190 362,330 C362,382 330,412 300,420 L292,330 '
            f'L220,330 L212,420 C182,412 150,382 150,330 Z" fill="url(#iron)" stroke="#1a1006" stroke-width="9" stroke-linejoin="round"/>'
            f'<path d="M180,300 C190,268 224,262 248,270 L248,330 L264,330 L264,270 C288,262 322,268 332,300 L326,332 L186,332 Z" fill="#0e0904"/>'
            f'<path d="M246,262 H266 V392 L256,404 L246,392 Z" fill="url(#bronze)" stroke="#1a1006" stroke-width="7" stroke-linejoin="round"/>'
            f'<path d="M154,286 C210,262 302,262 358,286" fill="none" stroke="url(#bronze)" stroke-width="20"/>'
            f'<path d="M154,286 C210,262 302,262 358,286" fill="none" stroke="#1a1006" stroke-width="5" opacity="0.6" transform="translate(0,12)"/>'
            f'<path d="M256,134 V264" stroke="{BRONZE}" stroke-width="18"/>'
            f'<ellipse cx="214" cy="306" rx="13" ry="9" fill="{GOLD}"/><ellipse cx="298" cy="306" rx="13" ry="9" fill="{GOLD}"/>'
            f'<circle cx="210" cy="303" r="4" fill="#fff8e0"/><circle cx="294" cy="303" r="4" fill="#fff8e0"/>'
            f'<path d="M196,190 C214,160 236,150 252,148" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity="0.5"/>')
    body = (f'<circle cx="256" cy="256" r="236" fill="url(#well)"/>'
            + rim("M256,24 A232,232 0 1,1 255.9,24 Z", 22) + left + ear + helm)
    return svg(body)


def render(svg_path, png_path, px):
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", png_path, svg_path], check=True)


def sheet(names, out_name, heading):
    """Every option at 16-512 on dark and light, the 16 and 32 also blown up 6x (nearest) to see their pixels,
    and the Discord circle crop at 128 on the dark well."""
    sizes = [16, 32, 64, 128, 512]
    tmp = os.path.join(OUT, ".sheet")
    os.makedirs(tmp, exist_ok=True)
    rows = []
    for key, title in names:
        svg_path = os.path.join(OUT, f"{key}.svg")
        for px in sizes:
            render(svg_path, os.path.join(tmp, f"{key}_{px}.png"), px)
        render(svg_path, os.path.join(OUT, f"{key}.png"), 512)
        rows.append((key, title))
    row_h, label_w, pad = 560, 300, 24
    W = label_w + 2 * (16 + 32 + 64 + 128 + 512 + 5 * pad + 2 * (96 + 192 + pad)) + 128 + 3 * pad
    H = 70 + len(rows) * row_h
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}">',
             f'<rect width="{W}" height="{H}" fill="#2b2420"/>',
             f'<text x="20" y="42" font-family="Georgia, serif" font-size="28" fill="{TITLE}">{heading}. 16, 32, 64, 128, 512 px on dark and on light; '
             f'16 and 32 again at 6x (nearest) to see the pixels; the Discord circle at 128</text>']
    for r, (key, title) in enumerate(rows):
        y0 = 70 + r * row_h
        parts.append(f'<text x="20" y="{y0 + 60}" font-family="Georgia, serif" font-size="30" font-weight="bold" fill="{TEXT}">{title.split("|")[0]}</text>')
        for k, line in enumerate(title.split("|")[1:]):
            parts.append(f'<text x="20" y="{y0 + 100 + k * 30}" font-family="Georgia, serif" font-size="21" fill="#c4b493">{line}</text>')
        x = label_w
        for bg in ("#17110b", "#f4e9cf"):
            w = 16 + 32 + 64 + 128 + 512 + 5 * pad + 2 * (96 + 192 + pad)
            parts.append(f'<rect x="{x}" y="{y0}" width="{w}" height="{row_h - 20}" fill="{bg}"/>')
            cx = x + pad // 2
            for px in sizes:
                parts.append(f'<image x="{cx}" y="{y0 + (row_h - 20 - px) // 2}" width="{px}" height="{px}" '
                             f'xlink:href="{os.path.join(tmp, f"{key}_{px}.png")}"/>')
                cx += px + pad
            for px in (16, 32):
                big = os.path.join(tmp, f"{key}_{px}_x6.png")
                subprocess.run(["magick", os.path.join(tmp, f"{key}_{px}.png"), "-filter", "point", "-resize", "600%", big], check=True)
                parts.append(f'<image x="{cx}" y="{y0 + (row_h - 20 - px * 6) // 2}" width="{px * 6}" height="{px * 6}" xlink:href="{big}"/>')
                cx += px * 6 + pad
            x += w + pad
        circ = os.path.join(tmp, f"{key}_disc.png")
        subprocess.run(["magick", "-size", "128x128", f"xc:{WELL}", os.path.join(tmp, f"{key}_128.png"), "-composite",
                        "(", "-size", "128x128", "xc:black", "-fill", "white", "-draw", "circle 64,64 64,0", ")",
                        "-alpha", "off", "-compose", "CopyOpacity", "-composite", circ], check=True)
        parts.append(f'<image x="{x}" y="{y0 + (row_h - 20 - 128) // 2}" width="128" height="128" xlink:href="{circ}"/>')
    parts.append("</svg>")
    sheet_svg = os.path.join(tmp, "sheet.svg")
    with open(sheet_svg, "w") as f:
        f.write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", os.path.join(OUT, out_name), sheet_svg], check=True)
    subprocess.run(["rm", "-rf", tmp], check=True)


def round_i1():
    options = {
        "a_frog_crest": option_a(),
        "b1_unit_shield_frog": option_b("viking_frog_f3", 6, 6),
        "b2_unit_shield_rat_bear": option_b("rat_on_bear_f3", 5),
        "c_quill_banner": option_c(),
        "d_odd_helm": option_d(),
        # more race marks for the sticker set (stickers.py), not on the I1 sheet
        "b3_unit_shield_bear": option_b("brown_bear_f2", 5),
        "b4_unit_shield_spider": option_b("spider_f2", 6),
        "b5_unit_shield_centaur": option_b("centaur_f2", 5),
    }
    for key, text in options.items():
        with open(os.path.join(OUT, f"{key}.svg"), "w") as f:
            f.write(text)
        print("wrote", key)
    sheet([("a_frog_crest", "A  Frog crest|a viking frog's head on|a lacquer-red shield"),
           ("b1_unit_shield_frog", "B1  Unit shield|the game's own baked|viking frog (facing 3)"),
           ("b2_unit_shield_rat_bear", "B2  Unit shield|the rat on a bear|(facing 3)"),
           ("c_quill_banner", "C  Quill banner|a quill crossed over|a sword: write it,|then fight it"),
           ("d_odd_helm", "D  Odd helm|one helm worn by|anything: a horn,|a rat's ear")],
          "sheet_i1.png", "Game icon, concept round I1: four marks without the name")
    print("wrote sheet_i1.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["i1"]
    if "i1" in which:
        round_i1()


if __name__ == "__main__":
    main()
