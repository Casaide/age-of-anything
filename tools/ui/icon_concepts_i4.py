"""Writes the game icon concepts, round I4 (2026-10-19), into docs/concepts/icon/: something totally different.
Dominic after I3: "I think we need to try something totally different, something that really clicks and shows
what we're about." No shields, crests or helms-on-coins: four ideas about what the game does, each a bold
full-bleed app tile (rounded square, the subject inside the Discord circle), in the timber colours turned up.
Same sheet as I2b/I3. Run: python3 tools/ui/icon_concepts_i4.py

  J1 race die     an isometric die whose pips are creatures: a frog's face, a rat's face, a spider. Roll a race.
  J2 odd pawn     a game piece made of parts: a frog's head, viking horns, a rat's tail. Your piece, your rules.
  J3 hatching     an egg cracking open: a horn and a rat's ear push the lid up, gold eyes in the dark. Something's coming.
  J4 stack        a frog in a viking helm on a rat on a bear, faces stacked like a totem. Rats riding bears, and up.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402
import icon_concepts_i2b as i2b   # noqa: E402

INK = "#1a1006"
LINE = f'stroke="{INK}" stroke-width="9" stroke-linejoin="round"'
DEFS = ('<linearGradient id="tile_red" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#c8442a"/><stop offset="1" stop-color="#6a1c0e"/></linearGradient>'
        '<linearGradient id="tile_gold" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#ffe07a"/><stop offset="1" stop-color="#d8901c"/></linearGradient>'
        '<linearGradient id="tile_blue" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#3a6ab8"/><stop offset="1" stop-color="#16285a"/></linearGradient>'
        '<linearGradient id="tile_green" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#7aae3a"/><stop offset="1" stop-color="#2e5014"/></linearGradient>'
        '<radialGradient id="glow" cx="0.5" cy="0.45" r="0.5"><stop offset="0" stop-color="#fff6c0" stop-opacity="0.55"/><stop offset="1" stop-color="#fff6c0" stop-opacity="0"/></radialGradient>'
        '<linearGradient id="shell" x1="0" y1="0" x2="0.5" y2="1"><stop offset="0" stop-color="#fffaf0"/><stop offset="1" stop-color="#d8c49a"/></linearGradient>'
        '<linearGradient id="fur" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#946038"/><stop offset="1" stop-color="#5a3418"/></linearGradient>'
        '<linearGradient id="ratfur" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c8c2b8"/><stop offset="1" stop-color="#8a847a"/></linearGradient>')


def tile(fill, body):
    """A full-bleed rounded tile with a soft glow behind the subject and a dark inner edge."""
    return ic.svg(f'<rect x="0" y="0" width="512" height="512" rx="104" fill="{fill}"/>'
                  f'<circle cx="256" cy="246" r="230" fill="url(#glow)"/>'
                  f'<rect x="6" y="6" width="500" height="500" rx="100" fill="none" stroke="#000" stroke-width="12" opacity="0.25"/>'
                  + body, DEFS)


# --- J1: the race die -----------------------------------------------------------------------------------------
# glyphs drawn in -60..60, then mapped onto a face of the isometric cube; ink on bone, like pips
FROG_PIP = (f'<circle cx="-30" cy="-22" r="22" fill="{INK}"/><circle cx="30" cy="-22" r="22" fill="{INK}"/>'
            f'<path d="M-56,6 C-56,-14 56,-14 56,6 C56,40 30,52 0,52 C-30,52 -56,40 -56,6 Z" fill="{INK}"/>'
            f'<circle cx="-30" cy="-24" r="9" fill="#f4ead2"/><circle cx="30" cy="-24" r="9" fill="#f4ead2"/>'
            f'<path d="M-36,22 Q0,40 36,22" fill="none" stroke="#f4ead2" stroke-width="6" stroke-linecap="round"/>')
RAT_PIP = (f'<circle cx="-34" cy="-30" r="24" fill="{INK}"/><circle cx="34" cy="-30" r="24" fill="{INK}"/>'
           f'<path d="M-34,-6 C-34,-24 34,-24 34,-6 C34,16 12,46 0,54 C-12,46 -34,16 -34,-6 Z" fill="{INK}"/>'
           f'<circle cx="-14" cy="0" r="5" fill="#f4ead2"/><circle cx="14" cy="0" r="5" fill="#f4ead2"/>'
           f'<path d="M-20,30 L-58,22 M-20,36 L-58,42 M20,30 L58,22 M20,36 L58,42" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>')
SPIDER_PIP = (f'<ellipse cx="0" cy="12" rx="24" ry="28" fill="{INK}"/><circle cx="0" cy="-22" r="16" fill="{INK}"/>'
              + "".join(f'<path d="M{8 * sx},{y0} Q{40 * sx},{y0 - 26 + k * 4} {58 * sx},{y0 + 10 + k * 6}" fill="none" stroke="{INK}" '
                        f'stroke-width="8" stroke-linecap="round"/>' for k, y0 in enumerate((-8, 4, 16, 28)) for sx in (-1, 1))
              + '<circle cx="-6" cy="-24" r="4" fill="#ff4a3a"/><circle cx="6" cy="-24" r="4" fill="#ff4a3a"/>')


def option_j1():
    top = "M256,82 L420,176 L256,270 L92,176 Z"
    left = "M92,176 L256,270 L256,458 L92,364 Z"
    right = "M256,270 L420,176 L420,364 L256,458 Z"
    face = lambda path, fill: f'<path d="{path}" fill="{fill}" {LINE}/>'
    cube = (f'<path d="M256,82 L420,176 L420,364 L256,458 L92,364 L92,176 Z" fill="{INK}" stroke="{INK}" stroke-width="36" stroke-linejoin="round"/>'
            + face(top, "#fbf3e0") + face(left, "#e2cfa4") + face(right, "#c4a874")
            + f'<g transform="matrix(1.17,-0.675,1.17,0.675,256,176)">{SPIDER_PIP}</g>'
            f'<g transform="matrix(1.17,0.675,0,1.35,174,317)">{FROG_PIP}</g>'
            f'<g transform="matrix(1.17,-0.675,0,1.35,338,317)">{RAT_PIP}</g>')
    shadow = '<ellipse cx="256" cy="470" rx="150" ry="20" fill="#000" opacity="0.35"/>'
    return tile("url(#tile_red)", shadow + cube)


# --- J2: the odd pawn -----------------------------------------------------------------------------------------
def option_j2():
    tail = (f'<path d="M372,420 C430,420 452,372 430,336 C414,310 384,318 390,342" fill="none" stroke="{INK}" stroke-width="24" stroke-linecap="round"/>'
            f'<path d="M372,420 C430,420 452,372 430,336 C414,310 384,318 390,342" fill="none" stroke="#e6a0a0" stroke-width="12" stroke-linecap="round"/>')
    horns = (f'<path d="M190,206 C132,198 96,156 96,84 C120,126 150,146 196,160 Z" fill="url(#horn)" {LINE}/>'
             f'<path d="M322,206 C380,198 416,156 416,84 C392,126 362,146 316,160 Z" fill="url(#horn)" {LINE}/>')
    piece = (f'<path d="M130,446 C130,416 160,404 196,400 L316,400 C352,404 382,416 382,446 Z" fill="url(#bronze)" {LINE}/>'
             f'<path d="M190,404 C196,366 210,320 226,284 L286,284 C302,320 316,366 322,404 Z" fill="url(#bronze)" {LINE}/>'
             f'<rect x="184" y="270" width="144" height="26" rx="13" fill="url(#bronze)" {LINE}/>'
             f'<path d="M232,300 C226,340 214,374 206,400" fill="none" stroke="#fff6d0" stroke-width="8" stroke-linecap="round" opacity="0.5"/>')
    head = (f'<path d="M168,226 C168,180 206,160 256,160 C306,160 344,180 344,226 C344,266 304,282 256,282 C208,282 168,266 168,226 Z" fill="url(#frog)" {LINE}/>'
            f'<circle cx="212" cy="164" r="32" fill="url(#frog)" {LINE}/><circle cx="300" cy="164" r="32" fill="url(#frog)" {LINE}/>'
            f'<circle cx="212" cy="162" r="20" fill="{ic.GOLD}" stroke="{INK}" stroke-width="4"/><circle cx="300" cy="162" r="20" fill="{ic.GOLD}" stroke="{INK}" stroke-width="4"/>'
            f'<ellipse cx="212" cy="163" rx="12" ry="6" fill="#140c04"/><ellipse cx="300" cy="163" rx="12" ry="6" fill="#140c04"/>'
            f'<path d="M196,238 Q256,268 316,238" fill="none" stroke="#1c2e0c" stroke-width="8" stroke-linecap="round"/>')
    shadow = '<ellipse cx="256" cy="452" rx="150" ry="18" fill="#000" opacity="0.3"/>'
    return tile("url(#tile_blue)", shadow + tail + piece + horns + head)


# --- J3: hatching -----------------------------------------------------------------------------------------------
EGG = "M256,92 C356,92 404,236 404,322 C404,414 338,462 256,462 C174,462 108,414 108,322 C108,236 156,92 256,92 Z"
CRACK = [(122, 246), (160, 274), (196, 240), (228, 276), (262, 238), (296, 276), (330, 240), (360, 272), (392, 246)]


def option_j3():
    pts = lambda seq: " ".join(f"L{x},{y}" for x, y in seq)
    clips = (f'<clipPath id="lower"><path d="M0,512 L0,246 {pts(CRACK)} L512,246 L512,512 Z"/></clipPath>'
             f'<clipPath id="upper"><path d="M0,0 L512,0 L512,246 {pts(reversed(CRACK))} L0,246 Z"/></clipPath>')
    crack = f'<path d="M122,246 {pts(CRACK[1:])}" fill="none" {LINE}/>'
    inside = (f'<path d="M126,252 C140,196 372,196 386,252 L392,300 L120,300 Z" fill="#0e0904"/>'
              f'<ellipse cx="220" cy="262" rx="16" ry="11" fill="{ic.GOLD}"/><ellipse cx="292" cy="262" rx="16" ry="11" fill="{ic.GOLD}"/>'
              f'<circle cx="215" cy="258" r="5" fill="#fff8e0"/><circle cx="287" cy="258" r="5" fill="#fff8e0"/>')
    horn = f'<path d="M176,250 C116,236 78,184 78,104 C100,156 136,184 196,200 Z" fill="url(#horn)" {LINE}/>'
    ear = (f'<path d="M318,214 C318,140 372,108 410,128 C446,150 430,212 376,232 Z" fill="#a8a29a" {LINE}/>'
           f'<path d="M334,206 C336,154 372,134 396,146 C418,160 408,200 372,214 Z" fill="#e6a0a0"/>')
    lower = (f'<g clip-path="url(#lower)"><path d="{EGG}" fill="url(#shell)" {LINE}/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#b89a6a" opacity="0.6"/>'
                       for x, y, r in ((170, 330, 10), (312, 370, 13), (230, 410, 8), (350, 312, 7), (200, 380, 6)))
             + '</g>' + crack)
    lid = (f'<g transform="translate(30,-96) rotate(-20 256 246)"><g clip-path="url(#upper)">'
           f'<path d="{EGG}" fill="url(#shell)" {LINE}/>'
           + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#b89a6a" opacity="0.6"/>' for x, y, r in ((220, 150, 9), (300, 190, 11)))
           + '</g>' + crack + '</g>')
    shadow = '<ellipse cx="256" cy="466" rx="140" ry="18" fill="#000" opacity="0.35"/>'
    return tile("url(#tile_green)", shadow + inside + lower + horn + ear + lid).replace(DEFS, DEFS + clips, 1)


# --- J4: the stack ----------------------------------------------------------------------------------------------
def option_j4():
    bear = (f'<circle cx="150" cy="318" r="40" fill="url(#fur)" {LINE}/><circle cx="362" cy="318" r="40" fill="url(#fur)" {LINE}/>'
            f'<circle cx="150" cy="318" r="18" fill="#c09a6a"/><circle cx="362" cy="318" r="18" fill="#c09a6a"/>'
            f'<path d="M126,392 C126,320 184,292 256,292 C328,292 386,320 386,392 C386,452 330,476 256,476 C182,476 126,452 126,392 Z" fill="url(#fur)" {LINE}/>'
            f'<ellipse cx="256" cy="420" rx="62" ry="44" fill="#c09a6a" {LINE}/>'
            f'<ellipse cx="256" cy="398" rx="26" ry="16" fill="#140c04"/>'
            f'<circle cx="196" cy="370" r="10" fill="#140c04"/><circle cx="316" cy="370" r="10" fill="#140c04"/>')
    rat = (f'<circle cx="166" cy="206" r="42" fill="url(#ratfur)" {LINE}/><circle cx="346" cy="206" r="42" fill="url(#ratfur)" {LINE}/>'
           f'<circle cx="166" cy="206" r="25" fill="#e6a0a0"/><circle cx="346" cy="206" r="25" fill="#e6a0a0"/>'
           f'<path d="M190,240 C190,206 222,192 256,192 C290,192 322,206 322,240 C322,272 280,318 256,326 C232,318 190,272 190,240 Z" fill="url(#ratfur)" {LINE}/>'
           f'<circle cx="230" cy="244" r="8" fill="#140c04"/><circle cx="282" cy="244" r="8" fill="#140c04"/>'
           f'<circle cx="256" cy="316" r="10" fill="#e07a8a" stroke="{INK}" stroke-width="4"/>')
    frog = (f'<path d="M108,150 C80,126 70,96 76,56 C92,90 114,104 140,112 Z" fill="url(#horn)" {LINE}/>'
            f'<path d="M404,150 C432,126 442,96 436,56 C420,90 398,104 372,112 Z" fill="url(#horn)" {LINE}/>'
            f'<path d="M136,140 C136,100 190,82 256,82 C322,82 376,100 376,140 C376,176 322,194 256,194 C190,194 136,176 136,140 Z" fill="url(#frog)" {LINE}/>'
            f'<path d="M150,124 C150,64 362,64 362,124 Z" fill="url(#iron)" {LINE}/>'
            f'<rect x="138" y="114" width="236" height="22" rx="8" fill="url(#bronze)" {LINE}/>'
            f'<circle cx="198" cy="140" r="22" fill="{ic.GOLD}" stroke="{INK}" stroke-width="5"/><circle cx="314" cy="140" r="22" fill="{ic.GOLD}" stroke="{INK}" stroke-width="5"/>'
            f'<ellipse cx="198" cy="142" rx="13" ry="6" fill="#140c04"/><ellipse cx="314" cy="142" rx="13" ry="6" fill="#140c04"/>'
            f'<path d="M206,172 Q256,188 306,172" fill="none" stroke="#1c2e0c" stroke-width="7" stroke-linecap="round"/>')
    return tile("url(#tile_gold)", bear + rat + f'<g transform="translate(256,40) scale(0.84) translate(-256,-40)">{frog}</g>')


OPTIONS = {
    "j1_race_die": (option_j1, "J1  Race die|a die whose pips are|creatures: roll a race"),
    "j2_odd_pawn": (option_j2, "J2  Odd pawn|a game piece made|of parts: frog head,|horns, rat's tail"),
    "j3_hatching": (option_j3, "J3  Hatching|an egg cracks open:|a horn, an ear,|eyes in the dark"),
    "j4_stack": (option_j4, "J4  Stack|a frog in a helm on|a rat on a bear"),
}


def main():
    for key, (fn, _) in OPTIONS.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(fn())
        print("wrote", key)
    sizes = os.path.join(ic.OUT, ".sheet_i4_sizes.png")
    ctx = os.path.join(ic.OUT, ".sheet_i4_ctx.png")
    ic.sheet([(key, title) for key, (_, title) in OPTIONS.items()], os.path.basename(sizes),
             "Game icon, concept round I4: something totally different")
    i2b.context(list(OPTIONS), ctx)
    subprocess.run(["magick", sizes, ctx, "-background", "#2b2420", "-gravity", "west", "-append",
                    os.path.join(ic.OUT, "sheet_i4.png")], check=True)
    os.remove(sizes)
    os.remove(ctx)
    print("wrote sheet_i4.png")


if __name__ == "__main__":
    main()
