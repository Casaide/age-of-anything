"""Writes the UI's crests: the small embossed ornament each culture's panels and banners wear
(assets/art/ui/crest_<motif>.svg). Each is drawn once in shapes without colour; the SVG then
stamps it as a shadow, in metal (a gradient from {L} light through {M} to {D} dark, filled in
by src/view/ui/theme.gd with the culture's metal) and with a fine dark edge, so it reads as
something cast or carved, not a flat sticker. Run: python3 tools/ui/crests.py
"""
import math
import os

W, H = 200, 60
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "ui")


def leaf(cx, cy, length, width, angle):
    """A pointed leaf (two arcs) centred at cx, cy, pointing along angle (degrees)."""
    a = math.radians(angle)
    dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
    nx, ny = -math.sin(a) * width, math.cos(a) * width
    x0, y0, x1, y1 = cx - dx, cy - dy, cx + dx, cy + dy
    return (f'<path d="M{x0:.1f},{y0:.1f} Q{cx + nx:.1f},{cy + ny:.1f} {x1:.1f},{y1:.1f} '
            f'Q{cx - nx:.1f},{cy - ny:.1f} {x0:.1f},{y0:.1f}Z"/>')


def branch(side):
    """A laurel branch from the bottom middle, curving out and up to one side (+1 right, -1 left)."""
    out = []
    pts = []
    for k in range(9):
        t = k / 8
        x = 100 + side * (10 + 70 * t)
        y = 50 - 34 * math.sin(t * math.pi * 0.62) + 6 * t
        pts.append((x, y))
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    out.append(f'<path d="{d}" fill="none" stroke-width="2.6" stroke-linecap="round" class="stem"/>')
    for k in range(1, 9):
        x0, y0 = pts[k - 1]
        x1, y1 = pts[k]
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        size = 15 - k * 0.8
        ox, oy = -math.sin(math.radians(ang)) * 5, math.cos(math.radians(ang)) * 5
        out.append(leaf(x1 + ox, y1 + oy, size, 3.4, ang + 35))
        out.append(leaf(x1 - ox, y1 - oy, size, 3.4, ang - 35))
    return "".join(out)


def bar(y=30, half=88, thick=5):
    """A tapered bar across the crest: the base most crests sit on."""
    return (f'<path d="M{100 - half},{y} Q{100 - half * 0.5},{y - thick} 100,{y - thick} '
            f'Q{100 + half * 0.5},{y - thick} {100 + half},{y} Q{100 + half * 0.5},{y + thick} 100,{y + thick} '
            f'Q{100 - half * 0.5},{y + thick} {100 - half},{y}Z"/>')


def disc(cx, cy, r):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'


def sun():
    rays = []
    for k in range(16):
        a = math.tau * k / 16
        r0, r1 = 13, 24 if k % 2 == 0 else 19
        w = 0.16
        rays.append(f'<path d="M{100 + math.cos(a - w) * r0:.1f},{30 + math.sin(a - w) * r0:.1f} '
                    f'L{100 + math.cos(a) * r1:.1f},{30 + math.sin(a) * r1:.1f} '
                    f'L{100 + math.cos(a + w) * r0:.1f},{30 + math.sin(a + w) * r0:.1f}Z"/>')
    return bar(30, 90, 4) + "".join(rays) + disc(100, 30, 12)


def laurel():
    return branch(1) + branch(-1) + disc(100, 47, 7)


def meander():
    """A key pattern band with a medallion."""
    parts = ['<rect x="14" y="20" width="172" height="3"/>', '<rect x="14" y="38" width="172" height="3"/>']
    x = 16
    while x + 16 <= 186:
        if abs(x + 8 - 100) > 18:
            parts.append(f'<path d="M{x},36 L{x},26 L{x + 12},26 L{x + 12},33 L{x + 6},33 L{x + 6},30 L{x + 9},30 '
                         f'L{x + 9},29 L{x + 3},29 L{x + 3},36Z"/>')
        x += 16
    parts.append(disc(100, 30, 15))
    return "".join(parts)


def reeds():
    parts = []
    for k, (x, h, lean) in enumerate([(84, 40, -6), (92, 50, -2), (100, 54, 0), (108, 48, 3), (116, 38, 7)]):
        top = 56 - h
        parts.append(f'<path d="M{x - 1.6},56 Q{x + lean * 0.3},{top + h * 0.5} {x + lean},{top} '
                     f'Q{x + lean * 0.3 + 2},{top + h * 0.5} {x + 1.6},56Z"/>')
        if k in (1, 2, 3):
            parts.append(f'<rect x="{x + lean * 0.75 - 2.4:.1f}" y="{top + 4}" width="4.8" height="13" rx="2.4"/>')
    for x, flip in [(60, 1), (140, -1)]:
        parts.append(f'<path d="M{x},50 m-22,0 a22,7 0 1,0 44,0 a22,7 0 1,0 -44,0 M{x},50 L{x + 20 * flip},47 L{x + 20 * flip},53Z" fill-rule="evenodd"/>')
    parts.append(f'<path d="M{100 - 70},56 L{100 + 70},56 L{100 + 64},58 L{100 - 64},58Z"/>')
    return "".join(parts)


def rivets():
    parts = ['<rect x="36" y="14" width="128" height="32" rx="4"/>']
    cap = []
    for k in range(21):
        a = math.tau * k / 21
        r = 15 if k % 2 == 0 else 13
        cap.append(f"{100 + math.cos(a) * r:.1f},{30 + math.sin(a) * r:.1f}")
    parts.append(f'<polygon points="{" ".join(cap)}" class="raise"/>')
    parts.append(f'<circle cx="100" cy="30" r="9" class="raise"/>')
    for x in (44, 66, 134, 156):
        parts.append(f'<circle cx="{x}" cy="30" r="4" class="raise"/>')
    return "".join(parts)


def stitch():
    parts = ['<path d="M100,6 L130,30 L100,54 L70,30Z"/>', '<path d="M100,16 L118,30 L100,44 L82,30Z" class="raise"/>']
    for x, flip in [(56, -1), (144, 1)]:
        parts.append(f'<path d="M{x - 14 * flip},28 L{x + 14 * flip},28 L{x + 14 * flip},32 L{x - 14 * flip},32Z"/>')
        for k in range(5):
            parts.append(f'<path d="M{x + flip * 14 - 1},31 Q{x + flip * (16 + k)},{42 + k * 2} {x + flip * (12 + k * 2)},{52 + k}" fill="none" stroke-width="1.8" class="stem"/>')
    return bar(30, 40, 2) + "".join(parts)


def leaves():
    parts = []
    for side in (1, -1):
        for k, (dx, dy, ang, ln) in enumerate([(20, -6, -20, 30), (36, 2, 10, 26), (16, 10, 40, 22)]):
            parts.append(oak(100 + side * dx, 30 + dy, ln, ang if side > 0 else 180 - ang))
    parts.append('<ellipse cx="100" cy="35" rx="8" ry="10"/>')
    parts.append('<path d="M90,30 Q100,18 110,30Z" class="raise"/>')
    return "".join(parts)


def oak(cx, cy, length, angle):
    """An oak leaf: a leaf with three bumps a side."""
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    pts = []
    for k in range(13):
        t = k / 12
        w = math.sin(t * math.pi) * (5.5 + 2.2 * math.sin(t * math.pi * 6)) * length / 28
        pts.append((cx + ux * (t - 0.5) * length + nx * w, cy + uy * (t - 0.5) * length + ny * w))
    for k in range(12, -1, -1):
        t = k / 12
        w = math.sin(t * math.pi) * (5.5 + 2.2 * math.sin(t * math.pi * 6)) * length / 28
        pts.append((cx + ux * (t - 0.5) * length - nx * w, cy + uy * (t - 0.5) * length - ny * w))
    return '<polygon points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts) + '"/>'


def crown():
    return (bar(48, 60, 3) + '<path d="M72,46 L68,18 L84,32 L100,10 L116,32 L132,18 L128,46Z"/>'
            + disc(68, 16, 4) + disc(100, 8, 4.5) + disc(132, 16, 4) + '<rect x="74" y="38" width="52" height="5" class="raise"/>')


def bones():
    parts = []
    for ang in (22, -22):
        a = math.radians(ang)
        ux, uy = math.cos(a) * 40, math.sin(a) * 40
        nx, ny = -math.sin(a) * 3.2, math.cos(a) * 3.2
        parts.append(f'<polygon points="{100 - ux + nx:.1f},{30 - uy + ny:.1f} {100 + ux + nx:.1f},{30 + uy + ny:.1f} {100 + ux - nx:.1f},{30 + uy - ny:.1f} {100 - ux - nx:.1f},{30 - uy - ny:.1f}"/>')
        for s in (1, -1):
            ex, ey = 100 + s * ux, 30 + s * uy
            parts.append(disc(round(ex - uy * 0.12, 1), round(ey + ux * 0.12, 1), 5.5))
            parts.append(disc(round(ex + uy * 0.12, 1), round(ey - ux * 0.12, 1), 5.5))
    return "".join(parts) + disc(100, 30, 9)


def lotus():
    parts = []
    for k, (ang, ln) in enumerate([(-90, 40), (-62, 36), (-118, 36), (-36, 30), (-144, 30)]):
        a = math.radians(ang)
        parts.append(leaf(100 + math.cos(a) * ln * 0.5, 50 + math.sin(a) * ln * 0.5, ln, 7 if k == 0 else 6, ang))
    return bar(52, 70, 3) + "".join(parts)


def cloud():
    parts = []
    for side in (1, -1):
        cx = 100 + side * 40
        parts.append(spiral(cx, 30, side))
        parts.append(spiral(cx + side * 30, 36, side, 0.6))
    return bar(40, 90, 3) + "".join(parts) + disc(100, 30, 10)


def spiral(cx, cy, side, s=1.0):
    pts = []
    for k in range(40):
        t = k / 39
        a = side * (t * math.tau * 1.6)
        r = (3 + 13 * t) * s
        pts.append(f"{cx + math.cos(a) * r:.1f},{cy + math.sin(a) * r:.1f}")
    return f'<polyline points="{" ".join(pts)}" fill="none" stroke-width="{4.5 * s:.1f}" stroke-linecap="round" class="stem"/>'


def step():
    """A stepped fret: blocks rising towards a temple door in the middle."""
    parts = []
    for side in (1, -1):
        pts = [(100 + side * 20, 52)]
        for k in range(5):
            x0 = 100 + side * (20 + k * 14)
            top = 18 + k * 7
            pts += [(x0, top), (x0 + side * 14, top)]
        pts.append((100 + side * 90, 52))
        parts.append('<polygon points="' + " ".join(f"{a},{b}" for a, b in pts) + '"/>')
    parts.append('<rect x="84" y="10" width="32" height="42"/><rect x="93" y="24" width="14" height="28" class="raise"/>')
    return "".join(parts)


MOTIFS = {"sun": sun, "laurel": laurel, "meander": meander, "reeds": reeds, "rivets": rivets, "stitch": stitch,
          "leaves": leaves, "crown": crown, "bones": bones, "lotus": lotus, "cloud": cloud, "step": step}

TEMPLATE = """<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
<linearGradient id="metal" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{{L}}"/><stop offset="0.5" stop-color="{{M}}"/><stop offset="1" stop-color="{{D}}"/>
</linearGradient>
</defs>
<g transform="translate(1.6,2.4)" fill="#000" stroke="#000" opacity="0.55">{shape}</g>
<g fill="url(#metal)" stroke="{{D}}" stroke-width="1.1" stroke-linejoin="round">{shape}</g>
<g fill="none" stroke="{{L}}" stroke-width="0.7" opacity="0.6" transform="translate(-0.5,-0.6)">{shape}</g>
</svg>
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in MOTIFS.items():
        shape = fn()
        with open(os.path.join(OUT, f"crest_{name}.svg"), "w") as f:
            f.write(TEMPLATE.format(w=W, h=H, shape=shape))
        print("wrote", name)


if __name__ == "__main__":
    main()
