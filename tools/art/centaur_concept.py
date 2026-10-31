"""2D concept sheet for the centaur (round C1, 2026-10-31): side views drawn as SVG, each option also shrunk to the
size it plays at, before any model is built (Dominic: "start creating 2D concept art first, and iterating, before
making the model").

    python3 tools/art/centaur_concept.py docs/concepts/centaur/

Every option is one horse half and one man, drawn facing right on a ground line, a bay coat and a legionary's kit.
An option only moves and scales the two (`OPTIONS`): the drawing is shared, so the sheet compares proportions.
"""
import os, subprocess, sys

COAT, COAT_DARK, COAT_LIGHT = "#8a5530", "#5e3820", "#b07445"
POINTS, HOOF, MANE = "#4a2e1c", "#1c1512", "#24180f"
SKIN, SKIN_DARK = "#d9a679", "#a8774f"
TUNIC, TUNIC_DARK = "#a33328", "#6e211a"
STEEL, STEEL_DARK = "#c9ccd0", "#7d8288"
INK = "#2a1c14"


def legs(dx, coat, points):
    """The two legs of one side: the hind (the gaskin back to the hock, the cannon straight down) and the fore (the
    forearm to the knee); slim cannons, the fetlock's knob, the pastern sloping forward into the hoof."""
    return f"""
  <g transform="translate({dx} 0)">
    <path d="M104 290 L146 298 C142 344 124 368 114 386 C113 392 111 396 108 398 L98 392 C98 366 100 336 104 304 Z" fill="{coat}"/>
    <path d="M100 388 L112 390 L110 440 C113 444 113 449 110 451 L101 451 C99 446 99 442 101 440 Z" fill="{points}"/>
    <path d="M102 449 L110 449 L117 456 L121 461 L104 461 Z" fill="{points}"/>
    <path d="M104 456 L121 456 L123 461 L103 461 Z" fill="{HOOF}"/>
    <path d="M260 300 L296 300 C294 346 290 370 287 386 C289 392 288 398 286 401 L272 401 C270 397 270 391 272 386 C268 368 264 346 260 316 Z" fill="{coat}"/>
    <path d="M274 398 L285 398 L284 440 C287 444 287 449 284 451 L275 451 C273 446 273 442 275 440 Z" fill="{points}"/>
    <path d="M276 449 L284 449 L291 456 L295 461 L278 461 Z" fill="{points}"/>
    <path d="M278 456 L295 456 L297 461 L277 461 Z" fill="{HOOF}"/>
  </g>"""


def horse(far):
    """The horse half facing right in the drawing's own units (ground at y 460). far: the far legs only."""
    if far:
        return legs(-16, COAT_DARK, "#3a2416")
    return f"""
  <path d="M84 254 C64 262 58 300 62 330 C64 350 68 362 72 372 C78 352 78 318 86 286 Z" fill="{MANE}"/>
  <path d="M306 214 C318 240 320 300 300 334 C272 350 232 344 202 342 C168 340 144 336 124 326
           C104 334 88 324 80 302 C72 282 72 262 84 250 C102 236 132 240 152 246 C192 252 230 250 252 246
           C266 244 280 232 288 214 Z" fill="url(#coat)" stroke="{INK}" stroke-width="2"/>
  <path d="M84 266 C96 252 124 252 140 262 C150 282 146 306 126 322" fill="none" stroke="{COAT_DARK}" stroke-width="3" opacity="0.6"/>
  <path d="M258 262 C276 276 282 300 274 326" fill="none" stroke="{COAT_DARK}" stroke-width="3" opacity="0.55"/>
  <path d="M130 250 C170 254 220 254 250 249" fill="none" stroke="{COAT_LIGHT}" stroke-width="3" opacity="0.6"/>
{legs(0, 'url(#coatU)', POINTS)}"""


def man():
    """The man standing out of the horse's withers, his waist at (282, 250) (the drawing's own units)."""
    return f"""
  <path d="M300 168 C312 184 314 206 310 222" fill="none" stroke="{SKIN_DARK}" stroke-width="12" stroke-linecap="round"/>
  <rect x="298" y="176" width="34" height="62" rx="8" fill="url(#shield)" stroke="{INK}" stroke-width="2"/>
  <path d="M260 262 C258 240 260 226 264 214 L304 214 C308 226 310 240 304 262 Z" fill="{TUNIC}" stroke="{INK}" stroke-width="2"/>
  <path d="M266 260 L268 238 M278 262 L279 238 M290 262 L290 238" stroke="{TUNIC_DARK}" stroke-width="2.5"/>
  <path d="M262 222 C258 196 262 176 270 164 C282 156 296 158 304 166 C310 184 310 204 306 222 Z" fill="url(#steel)" stroke="{INK}" stroke-width="2"/>
  <path d="M264 186 h42 M263 200 h44 M263 212 h44" stroke="{STEEL_DARK}" stroke-width="2"/>
  <rect x="260" y="216" width="50" height="7" fill="#5a3a22" stroke="{INK}" stroke-width="1.5"/>
  <path d="M272 166 C262 176 256 196 262 214" fill="none" stroke="{SKIN}" stroke-width="12" stroke-linecap="round"/>
  <path d="M262 214 L268 228" stroke="{SKIN}" stroke-width="10" stroke-linecap="round"/>
  <path d="M266 226 L270 150" stroke="#6b4a2b" stroke-width="4"/>
  <path d="M270 150 l-5 -14 l10 0 z" fill="{STEEL}" stroke="{INK}" stroke-width="1"/>
  <rect x="279" y="148" width="12" height="12" fill="{SKIN_DARK}"/>
  <circle cx="286" cy="134" r="15" fill="{SKIN}" stroke="{INK}" stroke-width="2"/>
  <path d="M270 134 C270 112 302 112 302 134 L302 138 L296 138 L294 128 L274 128 L272 142 Z" fill="url(#steel)" stroke="{INK}" stroke-width="2"/>
  <path d="M275 116 C282 100 296 102 300 112 L294 116 C290 110 282 110 279 118 Z" fill="#c4362a" stroke="{INK}" stroke-width="1.5"/>
  <circle cx="295" cy="136" r="2" fill="{INK}"/>"""


DEFS = f"""
  <defs>
    <linearGradient id="coat" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{COAT_LIGHT}"/><stop offset="0.45" stop-color="{COAT}"/><stop offset="1" stop-color="{COAT_DARK}"/>
    </linearGradient>
    <linearGradient id="coatU" gradientUnits="userSpaceOnUse" x1="0" y1="236" x2="0" y2="346">
      <stop offset="0" stop-color="{COAT_LIGHT}"/><stop offset="0.45" stop-color="{COAT}"/><stop offset="1" stop-color="{COAT_DARK}"/>
    </linearGradient>
    <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#eef0f2"/><stop offset="0.6" stop-color="{STEEL}"/><stop offset="1" stop-color="{STEEL_DARK}"/>
    </linearGradient>
    <linearGradient id="shield" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#3d7fd6"/><stop offset="1" stop-color="#1f4f99"/>
    </linearGradient>
  </defs>"""

# name: (title, notes, horse transform, man transform). The horse's chest front is at x 300, its hooves on y 460;
# the man's waist sits on the withers at (282, 250).
OPTIONS = [
    ("A", "classic", "a riding horse; the man where its neck would be",
     "", ""),
    ("B", "compact hero", "short, deep, shorter legs; the man a size up",
     "translate(300 460) scale(0.86 0.92) translate(-300 -460)", "translate(282 270) scale(1.18) translate(-282 -250)"),
    ("C", "long and low", "longer and lower; more animal, less hero",
     "translate(300 460) scale(1.1 0.88) translate(-300 -460)", "translate(282 236) scale(0.95) translate(-282 -250)"),
]


def option_svg(o, w=420, h=500):
    _, _, _, ht, mt = o
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="20 90 {w} {h}">{DEFS}'
            f'<rect x="0" y="0" width="1000" height="1000" fill="#4f7a31"/>'
            f'<ellipse cx="196" cy="461" rx="130" ry="10" fill="#000" opacity="0.25"/>'
            f'<g transform="{ht}">{horse(True)}</g><g transform="{ht}">{horse(False)}</g>'
            f'<g transform="{mt}">{man()}</g></svg>')


def main(out):
    os.makedirs(out, exist_ok=True)
    tiles = []
    for o in OPTIONS:
        svg = os.path.join(out, "c1_%s.svg" % o[0].lower())
        open(svg, "w").write(option_svg(o))
        big, small = svg[:-4] + ".png", svg[:-4] + "_play.png"
        subprocess.run(["rsvg-convert", "-w", "420", "-o", big, svg], check=True)
        # As it plays: about 64 px tall, then blown up 4x with hard pixels to look at
        subprocess.run(["rsvg-convert", "-w", "54", "-o", small, svg], check=True)
        subprocess.run(["magick", small, "-filter", "point", "-resize", "400%", small], check=True)
        tiles.append((o, big, small))
    sheet = os.path.join(out, "c1_sheet.png")
    cols = []
    for o, big, small in tiles:
        cols.append(["(", big, small, "-background", "#4f7a31", "-gravity", "center", "-append",
                     "-gravity", "north", "-splice", "0x40", "-font", "Helvetica", "-pointsize", "20", "-fill", "white",
                     "-annotate", "+0+8", "%s: %s" % (o[0], o[1]), "-gravity", "south", "-splice", "0x30", "-pointsize", "14",
                     "-annotate", "+0+8", o[2], ")"])
    cmd = ["magick"] + [a for c in cols for a in c] + ["-background", "#4f7a31", "+append", sheet]
    subprocess.run(cmd, check=True)
    print("wrote", sheet)


main(sys.argv[1] if len(sys.argv) > 1 else "docs/concepts/centaur/")
