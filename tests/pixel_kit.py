#!/usr/bin/env python3
"""The 2D pixel parts kit (milestone 5, the 2D slice): parts drawn as text grids, one character per
pixel, in *semantic* colours, so one drawing serves every race palette and team.

Letters (anything else is an error):
  .  transparent
  o  outline / ink (drawn by hand for inner lines; the outer outline is added automatically)
  F f g    skin or fur: light, mid, dark      (from the race's skin colour)
  P p      second skin (ears, nose, hands, tail, belly): light, dark   (race skin2)
  e        eye (near-black) ; W  a one-pixel glint
  U t T    team colour: light, mid, dark      (written as the shader's magenta team key)
  C c      culture cloth: light, dark         (the race family's cloth colour)
  L l      leather: light, dark
  M m n    metal: light, mid, dark
  H h      wood: light, dark
  K k      bronze: light, dark
  B        bone / pale tip

A part is {"facing": [rows]} plus points (sockets) in its own pixel frame. Parts are composed by
stamping in order at socket positions. `outline()` rings the opaque pixels with ink.
"""
import os, struct, zlib

TEAM_KEY = (0.75, 0.0, 0.75)   # matches PartShape.TEAM_KEY's hue: the shader swaps it for the team


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def shade(rgb, k):
    """Lighten (k > 0) or darken (k < 0) a colour."""
    if k >= 0:
        return tuple(c + (1 - c) * k for c in rgb)
    return tuple(c * (1 + k) for c in rgb)


def palette(skin, skin2, cloth, team=TEAM_KEY):
    s, s2, cl = hexc(skin), hexc(skin2), hexc(cloth)
    return {
        "o": hexc("#241a16"), "e": hexc("#140e0c"), "W": hexc("#f4f0e8"),
        "F": shade(s, 0.28), "f": s, "g": shade(s, -0.32),
        "P": shade(s2, 0.15), "p": shade(s2, -0.22),
        "U": shade(team, 0.25), "t": team, "T": shade(team, -0.3),
        "C": cl, "c": shade(cl, -0.3),
        "L": hexc("#9a6a3a"), "l": hexc("#5e3c1e"),
        "M": hexc("#e6e6de"), "m": hexc("#a8aaa4"), "n": hexc("#5e605a"),
        "H": hexc("#c8945a"), "h": hexc("#7a5230"),
        "K": hexc("#e0b060"), "k": hexc("#9a6a28"),
        "B": hexc("#f2ead6"),
    }


def canvas(w, h):
    return [["."] * w for _ in range(h)]


def stamp(cv, art, x, y):
    for j, line in enumerate(art):
        for i, ch in enumerate(line):
            if ch != "." and 0 <= y + j < len(cv) and 0 <= x + i < len(cv[0]):
                cv[y + j][x + i] = ch


def outline(cv):
    """Ring every opaque pixel's transparent 4-neighbours with ink: the units' dark edge."""
    h, w = len(cv), len(cv[0])
    out = [row[:] for row in cv]
    for y in range(h):
        for x in range(w):
            if cv[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and cv[ny][nx] not in (".", "o"):
                    out[y][x] = "o"
                    break
    return out


def mirror(rows):
    """A drawn facing flipped left-right (SW from SE, W from E, NW from NE)."""
    width = max(len(r) for r in rows)
    return [r.ljust(width, ".")[::-1] for r in rows]


def png(path, cv, pal, scale=1, bg=None):
    h = len(cv) * scale
    w = len(cv[0]) * scale
    raw = b""
    for row in cv:
        line = b"\x00"
        for ch in row:
            if ch == ".":
                px = (bytes(int(c * 255) for c in bg) + b"\xff") if bg else b"\x00\x00\x00\x00"
            else:
                assert ch in pal, "unknown pixel letter %r" % ch
                px = bytes(int(max(0, min(1, c)) * 255) for c in pal[ch]) + b"\xff"
            line += px * scale
        raw += line * scale

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def sheet(cells, cell_w, cell_h, cols, gap=4):
    """Lay several canvases out in a grid (for previews)."""
    rows_n = (len(cells) + cols - 1) // cols
    cv = canvas(cols * (cell_w + gap) + gap, rows_n * (cell_h + gap) + gap)
    for k, c in enumerate(cells):
        x = gap + (k % cols) * (cell_w + gap)
        y = gap + (k // cols) * (cell_h + gap)
        stamp(cv, ["".join(r) for r in c], x, y)
    return cv
