"""Writes the game icon concepts, round I3 (2026-10-19), into docs/concepts/icon/: variations on I1's D, the odd helm.
Dominic, pointing at D: "getting weird. I think this was a good direction, showing the weird generated stuff. Try
some variations of that." One helm, worn by whatever the generator made: each variation changes what pokes out of
it (horns, ears, antennae, eyes through the crown, a tongue, whiskers, a tail) and what looks out of the face slot.
Same sheet as I2b (sizes, then among made-up Discord servers and library tiles). Run: python3 tools/ui/icon_concepts_i3.py

  D   the I1 original: a horn and a rat's ear, gold eyes            (for reference)
  D2  spider: a horn and a beetle's antenna, six red eyes in the slot
  D3  frog: two frog's eyes bulging up through the crown, a tongue out from under it
  D4  rat: two ears, whiskers out of the slot, beady eyes, a tail round the rim
  D5  bear: round ears, a snout and nose under the nasal
  D6  winged: a feathered wing and a horn
  D7  the lot: a horn, a rat's ear, an antenna, a frog's eye on top, spider eyes, a tongue
  D8  D on a gold field: the original, made to stand out
"""
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402
import icon_concepts_i2b as i2b   # noqa: E402

INK = "#1a1006"
OUT_LINE = f'stroke="{INK}" stroke-width="8" stroke-linejoin="round"'
GOLD_DEFS = ('<radialGradient id="goldfield" cx="0.5" cy="0.4" r="0.65"><stop offset="0" stop-color="#ffe07a"/>'
             '<stop offset="1" stop-color="#d89a22"/></radialGradient>')


def mirror(svg):
    return f'<g transform="translate(512,0) scale(-1,1)">{svg}</g>'


# parts that poke out of the helm (drawn for the left side; mirror() for the right)
HORN = f'<path d="M188,206 C130,200 82,160 78,64 C108,118 146,140 196,158 Z" fill="url(#horn)" {OUT_LINE}/>'
EAR = (f'<path d="M318,190 C330,108 400,72 440,104 C470,130 446,206 368,234 Z" fill="#a8a29a" {OUT_LINE}/>'
             f'<path d="M336,190 C350,132 398,108 424,126 C442,142 424,192 368,214 Z" fill="#e6a0a0"/>')   # the right ear; mirror() for the left
ANTENNA = (f'<path d="M206,160 C186,110 150,84 106,72" fill="none" stroke="{INK}" stroke-width="18" stroke-linecap="round"/>'
           f'<path d="M206,160 C186,110 150,84 106,72" fill="none" stroke="#4a3a24" stroke-width="9" stroke-linecap="round"/>'
           f'<ellipse cx="98" cy="70" rx="22" ry="16" transform="rotate(-20 98 70)" fill="#4a3a24" {OUT_LINE}/>')
BEAR_EAR = (f'<circle cx="170" cy="156" r="48" fill="#7a4e2a" {OUT_LINE}/>'
            f'<circle cx="170" cy="156" r="24" fill="#c09a6a"/>')
WING = "".join(f'<g transform="rotate({k * 17 + 14} 204 196) translate(204,196) scale(1.25) translate(-204,-196)"><path d="M200,214 C150,226 92,214 52,186 C70,170 110,160 150,166 '
               f'C176,170 192,182 202,190 Z" fill="#f4ead2" {OUT_LINE}/><path d="M196,200 C150,196 100,188 66,182" fill="none" '
               f'stroke="#b8a67e" stroke-width="4"/></g>' for k in range(3, -1, -1))


def frog_eye(cx, cy=150, r=50):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#frog)" {OUT_LINE}/>'
            f'<circle cx="{cx}" cy="{cy - 2}" r="{r * 0.62:.0f}" fill="{ic.GOLD}" stroke="{INK}" stroke-width="4"/>'
            f'<ellipse cx="{cx}" cy="{cy}" rx="{r * 0.38:.0f}" ry="{r * 0.16:.0f}" fill="#140c04"/>'
            f'<circle cx="{cx - r * 0.25:.0f}" cy="{cy - r * 0.28:.0f}" r="{r * 0.12:.0f}" fill="#fff8e0"/>')


TONGUE = (f'<path d="M256,404 C262,440 300,456 336,448 C352,444 360,456 350,466 C336,480 300,476 280,462" fill="none" '
          f'stroke="{INK}" stroke-width="30" stroke-linecap="round"/>'
          f'<path d="M256,404 C262,440 300,456 336,448 C352,444 360,456 350,466 C336,480 300,476 280,462" fill="none" '
          f'stroke="#e07a8a" stroke-width="18" stroke-linecap="round"/>')
WHISKERS = "".join(
    f'<path d="M188,{y0} L{x1},{y1}" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>'
    f'<path d="M188,{y0} L{x1},{y1}" stroke="#e8e2d4" stroke-width="4" stroke-linecap="round"/>'
    for y0, x1, y1 in ((306, 92, 282), (316, 86, 322), (326, 96, 362)))


def tail():
    """A rat's tail curling round the rim from the bottom right, tapering to a point."""
    out = []
    for k in range(8):
        a0, a1 = math.radians(100 - k * 11), math.radians(100 - (k + 1) * 11)
        r = 222
        w = 22 - k * 2.2
        out.append((r * math.cos(a0) + 256, r * math.sin(a0) + 256, r * math.cos(a1) + 256, r * math.sin(a1) + 256, w))
    under = "".join(f'<path d="M{x0:.1f},{y0:.1f} A222,222 0 0,0 {x1:.1f},{y1:.1f}" fill="none" stroke="{INK}" stroke-width="{w + 8:.1f}" stroke-linecap="round"/>'
                    for x0, y0, x1, y1, w in out)
    over = "".join(f'<path d="M{x0:.1f},{y0:.1f} A222,222 0 0,0 {x1:.1f},{y1:.1f}" fill="none" stroke="#e6a0a0" stroke-width="{w:.1f}" stroke-linecap="round"/>'
                   for x0, y0, x1, y1, w in out)
    return under + over


# what looks out of the face slot
EYES_GOLD = (f'<ellipse cx="214" cy="306" rx="13" ry="9" fill="{ic.GOLD}"/><ellipse cx="298" cy="306" rx="13" ry="9" fill="{ic.GOLD}"/>'
             f'<circle cx="210" cy="303" r="4" fill="#fff8e0"/><circle cx="294" cy="303" r="4" fill="#fff8e0"/>')
EYES_SPIDER = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#ff4a3a"/><circle cx="{x - 2}" cy="{y - 2}" r="2" fill="#ffd0c0"/>'
                      for x, y, r in ((200, 300, 8), (226, 296, 10), (198, 320, 6), (312, 300, 8), (286, 296, 10), (314, 320, 6)))
EYES_BEADY = '<circle cx="220" cy="306" r="8" fill="#e83030"/><circle cx="292" cy="306" r="8" fill="#e83030"/>'
SNOUT = (f'<path d="M196,334 C190,448 322,448 316,334 Z" fill="#7a4e2a" {OUT_LINE}/>'
         f'<path d="M214,356 C210,436 302,436 298,356 Z" fill="#c09a6a"/>')
NOSE = (f'<ellipse cx="256" cy="414" rx="26" ry="17" fill="#140c04"/><ellipse cx="248" cy="408" rx="8" ry="4" fill="#fff" opacity="0.4"/>'
        f'<path d="M256,430 V444 M240,446 Q256,452 272,446" fill="none" stroke="#140c04" stroke-width="5" stroke-linecap="round"/>')


def helm(behind="", inside=EYES_GOLD, front="", field="url(#well)", over_slot=""):
    """The odd helm on its roundel: parts behind it, the shell, what looks out of the slot, nasal and brim, parts in front."""
    shell = (f'<path d="M150,330 C142,190 196,130 256,130 C316,130 370,190 362,330 C362,382 330,412 300,420 L292,330 '
             f'L220,330 L212,420 C182,412 150,382 150,330 Z" fill="url(#iron)" stroke="{INK}" stroke-width="9" stroke-linejoin="round"/>'
             f'<path d="M180,300 C190,268 224,262 248,270 L248,330 L264,330 L264,270 C288,262 322,268 332,300 L326,332 L186,332 Z" fill="#0e0904"/>')
    trim = (f'<path d="M246,262 H266 V392 L256,404 L246,392 Z" fill="url(#bronze)" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
            f'<path d="M154,286 C210,262 302,262 358,286" fill="none" stroke="url(#bronze)" stroke-width="20"/>'
            f'<path d="M154,286 C210,262 302,262 358,286" fill="none" stroke="{INK}" stroke-width="5" opacity="0.6" transform="translate(0,12)"/>'
            f'<path d="M256,134 V264" stroke="{ic.BRONZE}" stroke-width="18"/>'
            f'<path d="M196,190 C214,160 236,150 252,148" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity="0.5"/>')
    body = (f'<circle cx="256" cy="256" r="236" fill="{field}"/>' + ic.rim("M256,24 A232,232 0 1,1 255.9,24 Z", 22)
            + behind + shell + inside + over_slot + trim + front)
    return ic.svg(body, GOLD_DEFS)


OPTIONS = {
    "d_odd_helm_i3ref": (helm(HORN + EAR), "D  Odd helm (I1)|a horn, a rat's ear,|gold eyes: the one|Dominic liked"),
    "d2_spider_helm": (helm(HORN + mirror(ANTENNA), EYES_SPIDER), "D2  Spider|a horn, an antenna,|six red eyes"),
    "d3_frog_helm": (helm(TONGUE, EYES_GOLD.replace(ic.GOLD, "#0e0904"), frog_eye(190, 168, 58) + frog_eye(322, 168, 58)),
                     "D3  Frog|eyes bulging up|through the crown,|a tongue out"),
    "d4_rat_helm": (helm(EAR + mirror(EAR), EYES_BEADY, WHISKERS + mirror(WHISKERS) + tail()),
                    "D4  Rat|two ears, whiskers,|beady eyes, a tail|round the rim"),
    "d5_bear_helm": (helm(BEAR_EAR + mirror(BEAR_EAR), EYES_GOLD.replace(ic.GOLD, "#f0a030"), NOSE, over_slot=SNOUT),
                     "D5  Bear|round ears, a snout|under the nasal"),
    "d6_winged_helm": (helm(WING + mirror(HORN)), "D6  Winged|a feathered wing|and a horn"),
    "d7_the_lot_helm": (helm(HORN + EAR + ANTENNA.replace("106,72", "150,40").replace('cx="98" cy="70"', 'cx="148" cy="36"')
                             .replace("rotate(-20 98 70)", "rotate(-40 148 36)") + TONGUE, EYES_SPIDER,
                             frog_eye(256, 124, 44)),
                        "D7  The lot|horn, ear, antenna,|a frog's eye, spider|eyes, a tongue"),
    "d8_gold_helm": (helm(HORN + EAR, field="url(#goldfield)"), "D8  Gold|the I1 helm on gold,|to stand out"),
}


def main():
    for key, (text, _) in OPTIONS.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(text)
        print("wrote", key)
    rows = [(key, title) for key, (_, title) in OPTIONS.items()]
    sizes = os.path.join(ic.OUT, ".sheet_i3_sizes.png")
    ctx = os.path.join(ic.OUT, ".sheet_i3_ctx.png")
    ic.sheet(rows, os.path.basename(sizes), "Game icon, concept round I3: the odd helm, worn by anything")
    keys = list(OPTIONS)
    ctx2 = ctx.replace(".png", "_2.png")
    i2b.context(keys[:4], ctx)
    i2b.context(keys[4:], ctx2)
    subprocess.run(["magick", sizes, ctx, ctx2, "-background", "#2b2420", "-gravity", "west", "-append",
                    os.path.join(ic.OUT, "sheet_i3.png")], check=True)
    os.remove(sizes)
    os.remove(ctx)
    os.remove(ctx2)
    print("wrote sheet_i3.png")


if __name__ == "__main__":
    main()
