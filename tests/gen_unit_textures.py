#!/usr/bin/env python3
"""Writes the unit surface textures (assets/art/textures/*.svg).

Units are drawn small: one texture tile covers roughly 10-20 art pixels, so marks
must be few, big and contrasty to survive the bake (a mark is 2-5 art px). Every
texture is greyscale-ish and tinted by the material (skin, team cloth), tileable
(marks near an edge are drawn again on the far side), and deterministic (seeded).

Run: python3 tests/gen_unit_textures.py
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "textures")
S = 256


def svg(body, bg):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<rect width="%d" height="%d" fill="%s"/>\n%s</svg>\n') % (S, S, S, S, S, S, bg, body)


def wrap(fn, x, y, r):
    """Draw fn at (x, y) and at its wrapped copies when it crosses an edge."""
    out = []
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            if -r <= x + dx <= S + r and -r <= y + dy <= S + r:
                out.append(fn(x + dx, y + dy))
    return "".join(out)


def blobs(rng, n, rmin, rmax, colours, opacity, squash=0.75):
    out = []
    for _ in range(n):
        x, y = rng.uniform(0, S), rng.uniform(0, S)
        rx = rng.uniform(rmin, rmax)
        ry = rx * rng.uniform(squash, 1.0)
        a = rng.uniform(0, 180)
        c = rng.choice(colours)
        out.append(wrap(lambda X, Y: '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.2f" transform="rotate(%.0f %.1f %.1f)"/>\n'
                        % (X, Y, rx, ry, c, opacity, a, X, Y), x, y, rx))
    return "".join(out)


def strokes(rng, n, length, width, colours, angle, spread, opacity=1.0):
    out = []
    for _ in range(n):
        x, y = rng.uniform(0, S), rng.uniform(0, S)
        a = math.radians(angle + rng.uniform(-spread, spread))
        l = length * rng.uniform(0.7, 1.3)
        dx, dy = math.cos(a) * l, math.sin(a) * l
        c = rng.choice(colours)
        out.append(wrap(lambda X, Y: '<path d="M%.1f,%.1f l%.1f,%.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round" opacity="%.2f"/>\n'
                        % (X, Y, dx, dy, c, width, opacity), x, y, l))
    return "".join(out)


def bands(n, width, colour, opacity, vertical=True, jitter=0.0, rng=None):
    out = []
    step = S / n
    for i in range(n):
        p = i * step + (rng.uniform(-jitter, jitter) if rng else 0.0)
        if vertical:
            out.append('<rect x="%.1f" y="0" width="%.1f" height="%d" fill="%s" opacity="%.2f"/>\n' % (p, width, S, colour, opacity))
        else:
            out.append('<rect x="0" y="%.1f" width="%d" height="%.1f" fill="%s" opacity="%.2f"/>\n' % (p, S, width, colour, opacity))
    return "".join(out)


def frog_skin(rng):
    # Big dark blotches (like a marsh frog's), a few pale warts on top.
    body = blobs(rng, 9, 22, 34, ["#62625a", "#727268"], 1.0, 0.6)
    body += blobs(rng, 14, 8, 12, ["#86867c"], 1.0)
    body += blobs(rng, 22, 5, 7, ["#ffffff"], 0.9, 0.9)
    return svg(body, "#ecece2")


def frog_belly(rng):
    return svg(blobs(rng, 18, 5, 9, ["#d6d2c2"], 0.8, 0.9), "#f6f4ea")


def hide(rng):
    # A horse's coat.
    # Short hair is smooth at this size: long soft runs and a few broad dapples, low contrast.
    body = strokes(rng, 14, 90, 14, ["#d0cec6"], 0, 4, 0.7)
    body += blobs(rng, 8, 18, 26, ["#f8f6f0"], 0.6)
    return svg(body, "#e4e2da")


def rat_fur(rng):
    # Fur in clumps: thick tufts flowing one way, dark roots and pale tips.
    body = strokes(rng, 70, 30, 10, ["#86867e", "#96968e"], 80, 18)
    body += strokes(rng, 50, 22, 7, ["#ffffff"], 80, 18)
    return svg(body, "#d6d6ce")


def mane(rng):
    body = strokes(rng, 60, 60, 7, ["#5e5a56", "#6e6a64"], 90, 6)
    body += strokes(rng, 30, 50, 3, ["#b4b0a8"], 90, 6)
    return svg(body, "#8a8680")


def cloth(rng):
    # Folds, not weave: broad soft darker runs hanging down, light ridges between.
    # (Never darker than ~0.7: the team key must stay recognisable under the tint.)
    body = ""
    for i in range(5):
        x = i * S / 5 + rng.uniform(-6, 6)
        body += '<rect x="%.1f" y="0" width="%.1f" height="%d" fill="#aaa69c" opacity="0.9"/>\n' % (x, rng.uniform(14, 22), S)
        body += '<rect x="%.1f" y="0" width="7" height="%d" fill="#ffffff" opacity="0.8"/>\n' % (x + 30, S)
    body += bands(32, 2, "#d2cec4", 0.6, vertical=False)
    return svg(body, "#ebe7de")


def skin(rng):
    return svg(blobs(rng, 14, 10, 18, ["#e2d2c8"], 0.6) + blobs(rng, 10, 6, 10, ["#ffffff"], 0.4), "#f2eee8")


def leather(rng):
    # Panels with dark seams and stitches, scuffed lighter in places.
    body = blobs(rng, 10, 14, 24, ["#8c6040"], 0.7, 0.5)
    for y in (0, 128):
        body += '<rect x="0" y="%d" width="%d" height="5" fill="#4a2e18"/>\n' % (y, S)
        for x in range(8, S, 20):
            body += '<rect x="%d" y="%d" width="8" height="3" fill="#a07850"/>\n' % (x, y + 10)
    body += blobs(rng, 8, 6, 10, ["#9a6e48"], 0.8)
    return svg(body, "#7a5230")


def chitin(rng):
    # Shell plates: hard dark seams and a bright sheen across each plate.
    body = ""
    for y in range(0, S, 64):
        body += '<rect x="0" y="%d" width="%d" height="7" fill="#6a6a70"/>\n' % (y, S)
        body += '<rect x="0" y="%d" width="%d" height="10" fill="#ffffff" opacity="0.55"/>\n' % (y + 16, S)
    body += blobs(rng, 10, 4, 7, ["#a8a8b0"], 0.7)
    return svg(body, "#c8c8d0")


TEXTURES = {"frog_skin": frog_skin, "frog_belly": frog_belly, "hide": hide, "rat_fur": rat_fur,
            "mane": mane, "cloth": cloth, "skin": skin, "leather": leather, "chitin": chitin}

if __name__ == "__main__":
    for i, (name, fn) in enumerate(sorted(TEXTURES.items())):
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(fn(random.Random(1000 + i)))
        print("wrote", name)
