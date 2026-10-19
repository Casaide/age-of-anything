"""Writes the game icon concepts, round I2 (2026-10-19), into docs/concepts/icon/: the game's own mark, not one race's.
Dominic on I1: "great, but not really game specific, those are fun race ones" (they became the sticker set,
tools/ui/stickers.py). I2 tries to say what the game is: an army built from a kit of parts, any people in any
culture, then a classic RTS war. Same look and the same sheet as I1 (tools/ui/icon_concepts.py).
Run: python3 tools/ui/icon_concepts_i2.py

  E  many peoples    a shield quartered: a horn, a rat's ear, a frog's eye, a wing: many peoples, one crest
  F  kit helm        a helm riveted together from mismatched plates (iron, bronze, timber, bone), a horn and an antenna
  G  stitched beast  a war banner whose beast is two creatures sewn down the middle: half bear, half frog
  H  write it in     a crest with an empty parchment field and a text caret: the race is what you write
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402

INK = "#1a1006"
SHIELD = ic.SHIELD
RIVET = lambda x, y, r=6: f'<circle cx="{x}" cy="{y}" r="{r}" fill="#f3d58a" stroke="{INK}" stroke-width="3"/>'


def option_e():
    clip = f'<clipPath id="sh"><path d="{SHIELD}"/></clipPath>'
    quarters = (f'<rect x="0" y="0" width="256" height="250" fill="url(#lacquer)"/>'
                f'<rect x="256" y="0" width="256" height="250" fill="#3a2818"/>'
                f'<rect x="0" y="250" width="256" height="262" fill="#4e7a26"/>'
                f'<rect x="256" y="250" width="256" height="262" fill="#25427a"/>')
    # Q1 a viking horn
    horn = (f'<path d="M118,206 C108,150 140,104 206,92 C170,118 158,150 166,204 Z" fill="url(#horn)" stroke="{INK}" '
            f'stroke-width="8" stroke-linejoin="round"/>'
            f'<path d="M112,206 H174 V222 H112 Z" fill="url(#bronze)" stroke="{INK}" stroke-width="6"/>')
    # Q2 a rat's ear: round, pink inside, a nick out of the rim
    ear = (f'<path d="M298,214 C276,170 290,104 350,96 C410,90 432,150 410,190 C396,214 352,226 298,214 Z" fill="#a8a29a" '
           f'stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
           f'<path d="M318,198 C304,166 314,124 352,120 C390,118 402,156 388,180 C378,196 350,204 318,198 Z" fill="#e6a0a0"/>'
           f'')
    # Q3 a frog's eye
    eye = (f'<path d="M98,380 C98,316 134,284 170,284 C206,284 236,316 236,380 Z" fill="url(#frog)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
           f'<circle cx="168" cy="338" r="36" fill="{ic.GOLD}" stroke="{INK}" stroke-width="5"/>'
           f'<ellipse cx="168" cy="340" rx="24" ry="11" fill="#140c04"/><circle cx="154" cy="326" r="7" fill="#fff8e0"/>')
    # Q4 a wing: long feathers fanned from a shoulder
    wing = "".join(
        f'<path d="M300,296 C{318 + k * 6},{300 + k * 4} {372 - k * 4},{318 + k * 22} {414 - k * 22},{316 + k * 34} '
        f'C{362 - k * 10},{344 + k * 22} {318},{330 + k * 14} 300,{318 + k * 6} Z" fill="#f4ead2" stroke="{INK}" '
        f'stroke-width="6" stroke-linejoin="round"/>' for k in range(3, -1, -1))
    wing += f'<path d="M282,286 C312,270 352,276 384,300 C350,312 316,318 290,320 Z" fill="#d8ccb0" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>'
    cross = (f'<rect x="244" y="40" width="24" height="460" fill="url(#bronze)" stroke="{INK}" stroke-width="5"/>'
             f'<rect x="40" y="238" width="432" height="24" fill="url(#bronze)" stroke="{INK}" stroke-width="5"/>'
             + RIVET(256, 250, 10))
    body = (f'<g clip-path="url(#sh)">{quarters}{horn}{ear}{eye}{wing}{cross}</g>' + ic.rim(SHIELD))
    return ic.svg(body, clip)


def option_f():
    clip = '<clipPath id="dome"><path d="M150,330 C142,190 196,124 256,124 C316,124 370,190 362,330 Z"/></clipPath>'
    defs = clip + ('<linearGradient id="timber" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8a5a30"/>'
                   '<stop offset="1" stop-color="#5a3a1e"/></linearGradient>'
                   '<linearGradient id="bone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4ead2"/>'
                   '<stop offset="1" stop-color="#b8a67e"/></linearGradient>')
    antenna = (f'<path d="M300,150 C318,110 350,84 392,74" fill="none" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
               f'<path d="M300,150 C318,110 350,84 392,74" fill="none" stroke="#3a3020" stroke-width="8" stroke-linecap="round"/>'
               f'<circle cx="398" cy="72" r="16" fill="#3a3020" stroke="{INK}" stroke-width="6"/>')
    horn = (f'<path d="M190,200 C132,194 86,154 82,62 C112,116 150,138 200,152 Z" fill="url(#horn)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>')
    plates = (f'<g clip-path="url(#dome)">'
              f'<rect x="100" y="100" width="156" height="240" fill="url(#iron)"/>'
              f'<rect x="256" y="100" width="156" height="240" fill="url(#bronze)"/>'
              f'<path d="M200,150 C218,140 236,134 250,132" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" opacity="0.5"/></g>'
              f'<path d="M150,330 C142,190 196,124 256,124 C316,124 370,190 362,330 Z" fill="none" stroke="{INK}" stroke-width="9"/>'
              f'<path d="M256,126 V270" stroke="{INK}" stroke-width="6"/>'
              + "".join(RIVET(256 + dx, y) for y in (160, 200, 240) for dx in (-12, 12)))
    brim = (f'<path d="M140,262 C200,244 312,244 372,262 L372,296 C312,280 200,280 140,296 Z" fill="url(#timber)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
            f'<path d="M160,270 C220,258 292,258 352,270" fill="none" stroke="#3a2412" stroke-width="3"/>'
            + "".join(RIVET(x, 276 - (6 if 190 < x < 322 else 0)) for x in (160, 208, 304, 352)))
    cheeks = (f'<path d="M150,290 L212,284 L214,404 C186,398 160,376 152,344 Z" fill="url(#bone)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
              f'<path d="M362,290 L300,284 L298,404 C326,398 352,376 360,344 Z" fill="url(#iron)" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
              f'<path d="M168,320 H196 M168,348 H196" stroke="#b8a67e" stroke-width="4"/>'
              + RIVET(198, 300) + RIVET(314, 300) + RIVET(314, 380) + RIVET(198, 380)
              + f'<path d="M212,292 H300 V340 L256,356 L212,340 Z" fill="#0e0904"/>'
              f'<path d="M246,286 H266 V384 L256,396 L246,384 Z" fill="url(#bronze)" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')
    body = (f'<circle cx="256" cy="256" r="236" fill="url(#lacquer)"/>'
            + ic.rim("M256,24 A232,232 0 1,1 255.9,24 Z", 22) + horn + antenna + plates + brim + cheeks)
    return ic.svg(body, defs)


def option_g():
    cloth = "M118,86 H394 V468 L256,372 L118,468 Z"
    clipL = '<clipPath id="lh"><rect x="0" y="0" width="256" height="512"/></clipPath><clipPath id="rh"><rect x="256" y="0" width="256" height="512"/></clipPath>'
    head = "M150,262 C150,192 198,158 256,158 C314,158 362,192 362,262 C362,320 316,350 256,350 C196,350 150,320 150,262 Z"
    bear = (f'<g clip-path="url(#lh)">'
            f'<circle cx="172" cy="170" r="30" fill="#7a4e2a" stroke="{INK}" stroke-width="8"/><circle cx="172" cy="170" r="14" fill="#4a2c16"/>'
            f'<path d="{head}" fill="#7a4e2a" stroke="{INK}" stroke-width="8"/>'
            f'<path d="M256,262 C222,262 206,284 206,304 C206,326 230,336 256,336 Z" fill="#c09a6a" stroke="{INK}" stroke-width="6"/>'
            f'<ellipse cx="256" cy="282" rx="22" ry="14" fill="#1a0e06"/>'
            f'<circle cx="208" cy="236" r="10" fill="#140c04"/><circle cx="205" cy="232" r="3" fill="#fff8e0"/></g>')
    frog = (f'<g clip-path="url(#rh)">'
            f'<path d="{head}" fill="url(#frog)" stroke="{INK}" stroke-width="8"/>'
            f'<circle cx="318" cy="196" r="34" fill="url(#frog)" stroke="{INK}" stroke-width="8"/>'
            f'<circle cx="318" cy="194" r="22" fill="{ic.GOLD}" stroke="{INK}" stroke-width="4"/>'
            f'<ellipse cx="318" cy="196" rx="13" ry="7" fill="#140c04"/><circle cx="310" cy="188" r="5" fill="#fff8e0"/>'
            f'<path d="M256,316 Q306,330 346,290" fill="none" stroke="#1c2e0c" stroke-width="8" stroke-linecap="round"/></g>')
    seam = (f'<path d="M256,154 V354" stroke="{INK}" stroke-width="5"/>'
            + "".join(f'<path d="M244,{y} L268,{y + 10}" stroke="#f4ead2" stroke-width="5" stroke-linecap="round"/>' for y in range(170, 345, 26)))
    body = (f'<path d="{cloth}" fill="#2a1a0a" transform="translate(6,8)" opacity="0.5"/>'
            f'<path d="{cloth}" fill="#25427a" stroke="#2a1a0a" stroke-width="10" stroke-linejoin="round"/>'
            f'<path d="M140,86 V420 M372,86 V420" stroke="{ic.GOLD}" stroke-width="6" opacity="0.75"/>'
            + bear + frog + seam +
            f'<rect x="74" y="62" width="364" height="28" rx="14" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>'
            f'<circle cx="74" cy="76" r="24" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>'
            f'<circle cx="438" cy="76" r="24" fill="url(#bronze)" stroke="#2a1a0a" stroke-width="8"/>')
    return ic.svg(body, clipL)


def option_h():
    defs = ('<linearGradient id="parch" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#f4e6c0"/>'
            '<stop offset="1" stop-color="#c8ad78"/></linearGradient>')
    # a prompt: a chevron, then the bar where your words go (no letters)
    caret = (f'<path d="M150,190 L222,256 L150,322" fill="none" stroke="#2a1a0a" stroke-width="44" stroke-linecap="round" stroke-linejoin="round"/>'
             f'<path d="M150,190 L222,256 L150,322" fill="none" stroke="#9a7438" stroke-width="26" stroke-linecap="round" stroke-linejoin="round"/>'
             f'<rect x="290" y="150" width="46" height="212" rx="10" fill="#2a1a0a"/>'
             f'<rect x="298" y="158" width="30" height="196" rx="6" fill="#7a2a18"/>')
    body = (f'<path d="{SHIELD}" fill="url(#parch)"/>'
            f'<path d="M110,100 H402 V250 C402,342 340,398 256,432 C172,398 110,342 110,250 Z" fill="none" stroke="#a88c58" stroke-width="5" stroke-dasharray="14 12"/>'
            + caret + ic.rim(SHIELD))
    return ic.svg(body, defs)


def main():
    options = {"e_many_peoples": option_e(), "f_kit_helm": option_f(), "g_stitched_beast": option_g(), "h_write_it_in": option_h()}
    for key, text in options.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(text)
        print("wrote", key)
    ic.sheet([("e_many_peoples", "E  Many peoples|a shield quartered:|horn, rat's ear,|frog's eye, wing"),
              ("f_kit_helm", "F  Kit helm|riveted from odd|plates: iron, bronze,|timber, bone"),
              ("g_stitched_beast", "G  Stitched beast|a war banner: half|bear, half frog,|sewn together"),
              ("h_write_it_in", "H  Write it in|an empty field and|a caret: the race|is what you write")],
             "sheet_i2.png", "Game icon, concept round I2: the game's own mark")
    print("wrote sheet_i2.png")


if __name__ == "__main__":
    main()
