#!/usr/bin/env python3
"""Hand-authored pixel sprites for the R0 pipeline test (docs/concepts/r0/).

Each sprite is text: one character per pixel, a shared palette. Layers are stamped in order
(body, then head, then head gear, then the hand and weapon in front), so parts work like our
parts kit: stamps with an offset. Writes PNGs at 1x and a 6x close-up.

Run: python3 tests/pixel_sprite.py
"""
import os, struct, zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "concepts", "r0")

PAL = {
    "o": "24160e",                                  # outline: dark brown, never black
    "s": "c98a5c", "d": "93603a", "l": "e8b486",     # skin
    "e": "2a1a12",                                  # eye / brow row
    "h": "3a2416", "H": "5a3a22",                   # hair
    "t": "3a78d8", "T": "24509a", "u": "70a8f0",     # tunic (team colour)
    "r": "b03a2a",                                  # hem trim (culture colour)
    "b": "6b4423", "B": "45290f", "L": "9a6a3a",     # leather
    "w": "a06c36", "W": "6a4420",                   # wood
    "m": "e4e4dc", "M": "a8aaa4", "n": "6a6c66",     # iron
    "k": "c8904a", "K": "8a5e2a", "y": "f0c070",     # bronze
    "c": "c42a26", "C": "8a1a18",                   # crest
}


def png(path, rows, scale=1):
    h = len(rows) * scale
    w = len(rows[0]) * scale
    raw = b""
    for row in rows:
        line = b"\x00"
        for ch in row:
            if ch == ".":
                px = b"\x00\x00\x00\x00"
            else:
                c = PAL[ch]
                px = bytes.fromhex(c) + b"\xff"
            line += px * scale
        raw += line * scale
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)


def canvas(w, h):
    return [["."] * w for _ in range(h)]


def stamp(cv, art, x, y):
    for j, line in enumerate(art):
        for i, ch in enumerate(line):
            if ch != "." and 0 <= y + j < len(cv) and 0 <= x + i < len(cv[0]):
                cv[y + j][x + i] = ch


def rows(cv):
    return ["".join(r) for r in cv]


# ---------------------------------------------------------------- three-quarter (facing right, toward us)
BODY_SE = [
    "......odso......",   # neck
    "...ooottttoooo..",
    "..otutttttttTto.",
    ".otuutttttttTTso",
    ".otuttttttttTTsdo",
    ".otttttttttTTTodo",
    "..ottttttttTTo.so",
    "..obbbbbbbbbbo.so",
    "..otttttttttTTo.o",
    ".otuttttttttTTTo",
    ".otttttttttTTTTo",
    ".orrrrrrrrrrrrro",
    "..osdo....osdo..",
    "..osdo....osdo..",
    "..osdo....osdo..",
    "..osdo.....osdo.",
    "..obbo.....obbo.",
    "..osdo.....osdo.",
    ".obbbbo...obbbbo",
    ".oooooo...oooooo",
]
HEAD_SE = [   # the face only: the cranium comes from hair or head gear
    "..ossssso.",
    ".oslllsso.",
    ".oslsesso.",
    ".oslllssdo",
    ".osllsssdo",
    "..osssldo.",
    "...osdo...",
]
HAIR_SE = [
    "...ooooo..",
    "..ohhhhho.",
    ".ohhHHhhho",
    ".ohhhhhhho",
    ".ohhhh.ho.",
]
CAP_SE = [    # a leather cap in the Montefortino shape: knob, bowl, brim, cheek flap
    ".....oo....",
    "....oLbo...",
    "..ooobbooo.",
    ".obLLbbbbbo",
    "obLLbbbbbBo",
    "oBBBBBBBBBo",
    ".o..ob..obo",
    ".....ob.obo",
    "......o..o.",
]
GALEA_SE = [  # iron galea: crest, bowl, bronze brow band, deep neck guard, cheek guard
    "...ocCcCco...",
    "..ocCcccCCo..",
    "...oooooooo..",
    "..ommmmmMMo..",
    ".ommmmmmMMno.",
    "ommmmmmmMMnno",
    "okyyyyyyyykko",
    "onno...omMno.",
    ".oo.....omno.",
    "........onno.",
    ".........oo..",
]
ARM_SPEAR_SE = [   # the near arm and the spear, in front of everything
    ".....om",
    ".....mo",
    "....oMo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "..oolWo",
    ".oslllo",
    ".osdslo",
    "..oolWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    "....oWo",
    ".....o.",
]
SHIELD_SE = [  # a small round parma on the far arm, behind
    "..ooooo..",
    ".okkkkko.",
    "okttttttK",
    "oktttuttK",
    "okttyuttK",
    "okttttttK",
    "oKttttTKo",
    ".oKKKKKo.",
    "..ooooo..",
]

# ---------------------------------------------------------------- facing the camera
BODY_S = [
    ".......odso......",
    "...oootttttooo...",
    "..ottuttttttTTo..",
    ".osottttttttTTsdo",
    ".osottttttttTTsdo",
    ".osottttttttTTodo",
    ".oso.oottttTo.odo",
    ".ollo.obbbbbo.olo",
    "..oo.ottttttTo.o.",
    "....otutttttTTo..",
    "....otttttttTTo..",
    "....orrrrrrrrro..",
    ".....osdo.osdo...",
    ".....osdo.osdo...",
    ".....osdo.osdo...",
    ".....osdo.osdo...",
    ".....obbo.obbo...",
    ".....osdo.osdo...",
    "....obbbo.obbbo..",
    "....ooooo.ooooo..",
]
HEAD_S = [
    "..ossssso..",
    ".osllllsdo.",
    ".oeslslsedo",   # brow row with eyes
    ".osllllssdo",
    ".osllsllsdo",
    "..ossssdo..",
    "...osdo....",
]
HAIR_S = [
    "...ooooo...",
    "..ohhhhho..",
    ".ohhHHHhhho",
    ".ohhhhhhhho",
    ".oho...ohho",
]
CAP_S = [
    ".....oo.....",
    "....oLbo....",
    "..ooobbooo..",
    ".obLLbbbbbo.",
    "obLLLbbbbbBo",
    "oBBBBBBBBBBo",
    "obo......obo",
    "obo......obo",
    ".o........o.",
]
GALEA_S = [
    "....ocCco....",
    "...ocCcCCo...",
    "...ooooooo...",
    "..ommmmmMMo..",
    ".ommmmmmmMMo.",
    "ommmmmmmmMMno",
    "okyyyyyyyyyko",
    "omno.....omno",
    "omno.....omno",
    ".oo.......oo.",
]

# ---------------------------------------------------------------- walking away
BODY_N = [
    ".......oddo......",
    "...oootttttooo...",
    "..oTtttttttttTo..",
    ".odoTtttttttTToso",
    ".odoTtttttttTToso",
    ".odoTTtttttTTToso",
    ".odo.oTtttttTo.so",
    ".odo.obbbbbbbo.so",
    "..o..oTtttttTo.o.",
    "....oTtttttttTo..",
    "....oTTtttttTTo..",
    "....orrrrrrrrro..",
    ".....odso.odso...",
    ".....odso.odso...",
    ".....odso.odso...",
    ".....odso.odso...",
    ".....obbo.obbo...",
    ".....odso.odso...",
    "....obbbo.obbbo..",
    "....ooooo.ooooo..",
]
HEAD_N = [
    "..ohhhhho..",
    ".ohhhhhhho.",
    ".ohhhhhhho.",
    ".odhhhhhdo.",
    ".osdhhhdso.",
    "..oddddo...",
    "...odso....",
]
HAIR_N = [
    "...ooooo...",
    "..ohhhhho..",
    ".ohhHHHhhho",
    ".ohhhhhhhho",
]
CAP_N = [
    ".....oo.....",
    "....obBo....",
    "..ooobbooo..",
    ".obbbbbbbbo.",
    "obbbbbbbbbBo",
    "oBBBBBBBBBBo",
    "obBBBBBBBBbo",
    ".oooooooooo.",
]
GALEA_N = [
    "....ocCco....",
    "...ocCcCCo...",
    "...ooooooo...",
    "..ommmmmMMo..",
    ".ommmmmmmMMo.",
    "oMmmmmmmmMMno",
    "okyyyyyyyyyko",
    "oMMMMMMMMMMno",
    ".onnnnnnnnno.",
    "..ooooooooo..",
]


def figure(facing, gear):
    cv = canvas(30, 44)
    if facing == "se":
        stamp(cv, SHIELD_SE, 4, 20)
        stamp(cv, BODY_SE, 7, 22)
        stamp(cv, HEAD_SE, 9, 14)
        stamp(cv, {"hair": HAIR_SE, "cap": CAP_SE, "galea": GALEA_SE}[gear], {"hair": 8, "cap": 7, "galea": 6}[gear],
              {"hair": 11, "cap": 8, "galea": 6}[gear])
        stamp(cv, ARM_SPEAR_SE, 19, 11)
    elif facing == "s":
        stamp(cv, BODY_S, 6, 22)
        stamp(cv, HEAD_S, 9, 14)
        stamp(cv, {"hair": HAIR_S, "cap": CAP_S, "galea": GALEA_S}[gear], {"hair": 9, "cap": 8, "galea": 8}[gear],
              {"hair": 11, "cap": 8, "galea": 6}[gear])
        stamp(cv, [".om", ".mo", "oMo"] + ["oWo"] * 30 + [".o."], 2, 8)   # the spear held at its side
        stamp(cv, SHIELD_SE, 19, 25)
    else:
        stamp(cv, [".om", ".mo", "oMo"] + ["oWo"] * 30 + [".o."], 22, 8)
        stamp(cv, BODY_N, 6, 22)
        stamp(cv, HEAD_N, 9, 14)
        stamp(cv, {"hair": HAIR_N, "cap": CAP_N, "galea": GALEA_N}[gear], {"hair": 9, "cap": 8, "galea": 8}[gear],
              {"hair": 11, "cap": 8, "galea": 6}[gear])
        stamp(cv, SHIELD_SE, 2, 24)
    return rows(cv)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for facing in ["s", "se", "n"]:
        for gear in ["hair", "cap", "galea"]:
            r = figure(facing, gear)
            png(os.path.join(OUT, "b_%s_%s.png" % (gear, facing)), r, 1)
            png(os.path.join(OUT, "b_%s_%s_x6.png" % (gear, facing)), r, 6)
    print("wrote", OUT)
