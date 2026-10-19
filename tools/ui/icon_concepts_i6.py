"""Writes the game icon concepts, round I6 (2026-10-19), into docs/concepts/icon/: a new direction, still flat.
Dominic on I5 (the flat die and helm): "I think new direction." The flat look from I5 stays (the genre's icons are
flat: one emblem, one or two colours, a flat field); the ideas are new, each from a kind of icon the genre uses
(an object, a figure, a painted bust) turned into ours:
Run: python3 tools/ui/icon_concepts_i6.py

  L1 frog standard   a legion-style war standard with a frog sitting where the eagle would be: gold on black
  L2 rat on a bear   cavalry as a silhouette, a rat with a spear riding a bear: bone on red
  L3 pixel bust      the genre's painted bust, done with the game's own pixel art: the cheese-hammer rat in his beret
  L4 cheese hammer   one weapon as the emblem: a war hammer whose head is a wedge of cheese, on red
"""
import base64
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402
import icon_concepts_i2b as i2b   # noqa: E402

BLACK, BONE, GOLD, GOLD2, RED, TEAL = "#15110d", "#f1e6cc", "#f2c94c", "#c8902a", "#a3311b", "#1d4a52"


def flat(field, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="512" height="512" '
            f'viewBox="0 0 512 512"><defs>{defs}</defs><rect width="512" height="512" fill="{field}"/>{body}</svg>\n')


def option_l1():
    """The frog standard: the frog on a plinth, a crossbar, a hanging cloth, the pole."""
    frog = (f'<ellipse cx="180" cy="214" rx="34" ry="24" fill="{GOLD}"/><ellipse cx="332" cy="214" rx="34" ry="24" fill="{GOLD}"/>'
            f'<path d="M188,206 C188,150 222,128 256,128 C290,128 324,150 324,206 C324,232 296,240 256,240 C216,240 188,232 188,206 Z" fill="{GOLD}"/>'
            f'<circle cx="222" cy="124" r="26" fill="{GOLD}"/><circle cx="290" cy="124" r="26" fill="{GOLD}"/>'
            f'<circle cx="222" cy="122" r="11" fill="{BLACK}"/><circle cx="290" cy="122" r="11" fill="{BLACK}"/>'
            f'<path d="M218,172 Q256,192 294,172" fill="none" stroke="{BLACK}" stroke-width="7" stroke-linecap="round"/>'
            f'<path d="M226,240 L216,252 M286,240 L296,252" stroke="{GOLD}" stroke-width="12" stroke-linecap="round"/>')
    standard = (f'<rect x="196" y="250" width="120" height="20" fill="{GOLD}"/>'
                f'<rect x="246" y="270" width="20" height="230" fill="{GOLD}"/>'
                f'<rect x="150" y="290" width="212" height="16" fill="{GOLD}"/>'
                f'<circle cx="150" cy="298" r="13" fill="{GOLD}"/><circle cx="362" cy="298" r="13" fill="{GOLD}"/>'
                f'<path d="M170,314 H342 V420 L256,390 L170,420 Z" fill="{RED}"/>'
                f'<path d="M246,314 H266 V394 L256,391 L246,394 Z" fill="{GOLD}" opacity="0"/>'
                f'<circle cx="256" cy="350" r="20" fill="{GOLD}"/>')
    return flat(BLACK, standard + frog)


def option_l2():
    """A rat with a spear riding a bear, one bone colour; the rat is cut from the bear by a field-coloured gap."""
    gap = f'stroke="{RED}" stroke-width="12" stroke-linejoin="round"'
    bear = (f'<path d="M136,330 C136,272 192,252 268,252 C340,254 404,272 414,326 C418,352 406,374 392,382 L392,440 L360,440 L354,392 '
            f'L312,394 L306,440 L276,440 L270,396 L206,394 L200,440 L170,440 L164,384 C146,372 136,354 136,330 Z" fill="{BONE}"/>'
            f'<path d="M168,296 C170,262 146,248 118,252 C96,256 80,272 76,290 L44,304 C40,318 52,328 70,326 C92,336 120,340 140,334 Z" fill="{BONE}"/>'
            f'<path d="M150,300 C150,206 236,196 296,258 Z" fill="{BONE}"/>'
            f'<circle cx="122" cy="248" r="20" fill="{BONE}"/><circle cx="122" cy="248" r="8" fill="{RED}"/>'
            f'<circle cx="104" cy="282" r="6" fill="{RED}"/>')
    rat = (f'<path d="M318,262 C350,256 380,244 392,222 C400,206 394,192 382,190" fill="none" stroke="{BONE}" stroke-width="7" stroke-linecap="round"/>'
           f'<path d="M248,262 C246,214 262,188 290,186 C322,184 334,214 330,262 Z" fill="{BONE}" {gap}/>'
           f'<path d="M298,186 C302,152 284,134 262,134 C246,134 232,142 222,154 L188,166 C184,174 192,180 202,178 C220,190 248,196 270,194 Z" fill="{BONE}" {gap}/>'
           f'<circle cx="276" cy="124" r="22" fill="{BONE}" {gap}/>'
           f'<circle cx="236" cy="158" r="5" fill="{RED}"/>')
    spear = (f'<path d="M324,250 L176,138" stroke="{RED}" stroke-width="15" stroke-linecap="round"/>'
             f'<path d="M324,250 L176,138" stroke="{BONE}" stroke-width="7" stroke-linecap="round"/>'
             f'<path d="M180,141 L150,124 L172,150 Z" fill="{BONE}"/>'
             f'<path d="M200,156 L236,148 L212,182 Z" fill="{GOLD}"/>')
    return flat(RED, bear + f'<g transform="translate(290,262) scale(1.5) translate(-290,-262)">{rat}{spear}</g>')


def option_l3():
    """The rat's bust from the baked rat-on-a-bear (docs/concepts/icon/units/), 16x pixels, on teal."""
    src = os.path.join(ic.OUT, "units", "rat_on_bear_f3.png")
    tmp = os.path.join(ic.OUT, "units", ".rat_bust.png")
    subprocess.run(["magick", src, "-crop", "28x28+12+0", "+repage", "-background", "none", "-gravity", "south",
                    "-extent", "30x30", "-filter", "point", "-resize", "1600%", tmp], check=True)
    with open(tmp, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    os.remove(tmp)
    return flat(TEAL, f'<image x="16" y="32" width="480" height="480" style="image-rendering:pixelated" '
                      f'xlink:href="data:image/png;base64,{data}"/>')


def option_l4():
    """The cheese hammer, on the diagonal: a strapped haft and a wedge of cheese for a head, holes and a rind."""
    head = (f'<path d="M150,96 L330,96 L330,232 L150,232 Z" fill="{GOLD}"/>'
            f'<path d="M150,96 L330,96 L330,116 L150,116 Z" fill="{GOLD2}"/>'
            f'<circle cx="196" cy="160" r="18" fill="{RED}"/><circle cx="272" cy="190" r="13" fill="{RED}"/>'
            f'<circle cx="292" cy="146" r="9" fill="{RED}"/><circle cx="178" cy="210" r="8" fill="{RED}"/>'
            f'<path d="M330,96 L360,124 L360,212 L330,232 Z" fill="{GOLD2}"/>')
    haft = (f'<rect x="226" y="228" width="30" height="236" fill="{BONE}"/>'
            + "".join(f'<rect x="222" y="{y}" width="38" height="12" fill="{RED}" opacity="0.0"/>' for y in ())
            + "".join(f'<path d="M226,{y} L256,{y + 14}" stroke="{RED}" stroke-width="5"/>' for y in (300, 324, 348))
            + f'<rect x="218" y="452" width="46" height="22" rx="4" fill="{BONE}"/>')
    return flat(RED, f'<g transform="rotate(-30 256 282)">{haft}{head}</g>')


OPTIONS = {
    "l1_frog_standard": (option_l1, "L1  Frog standard|a war standard with|a frog for its eagle"),
    "l2_rat_on_bear": (option_l2, "L2  Rat on a bear|cavalry in silhouette:|a rat with a spear|riding a bear"),
    "l3_pixel_bust": (option_l3, "L3  Pixel bust|the genre's bust in|our own pixel art:|the cheese-hammer rat"),
    "l4_cheese_hammer": (option_l4, "L4  Cheese hammer|a war hammer whose|head is a cheese"),
}


def main():
    for key, (fn, _) in OPTIONS.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(fn())
        print("wrote", key)
    sizes = os.path.join(ic.OUT, ".sheet_i6_sizes.png")
    ctx = os.path.join(ic.OUT, ".sheet_i6_ctx.png")
    ic.sheet([(key, title) for key, (_, title) in OPTIONS.items()], os.path.basename(sizes),
             "Game icon, concept round I6: a new direction, flat")
    i2b.context(list(OPTIONS), ctx)
    subprocess.run(["magick", sizes, ctx, "-background", "#2b2420", "-gravity", "west", "-append",
                    os.path.join(ic.OUT, "sheet_i6.png")], check=True)
    os.remove(sizes)
    os.remove(ctx)
    print("wrote sheet_i6.png")


if __name__ == "__main__":
    main()
