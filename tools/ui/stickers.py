"""Writes the Discord sticker and emoji set (2026-10-19; Dominic on icon round I1: "fun race ones, we could even add
as stickers") into docs/concepts/icon/stickers/: every I1 mark as a die-cut sticker (a cream border with a dark
edge, so it reads on Discord's dark and light themes) at 320x320 and as an emoji at 128x128, transparent, plus a
preview of each at the sizes Discord shows them (sticker 160, emoji 22 inline and 48 jumbo) on both themes.
Run after tools/ui/icon_concepts.py (it writes the SVGs). Discord limits: sticker 320 PNG under 512 KB, emoji under
256 KB; asserted here.
"""
import os
import subprocess

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
ICON = os.path.join(ROOT, "docs", "concepts", "icon")
OUT = os.path.join(ICON, "stickers")
MARKS = ["a_frog_crest", "b1_unit_shield_frog", "b2_unit_shield_rat_bear", "b3_unit_shield_bear",
         "b4_unit_shield_spider", "b5_unit_shield_centaur", "c_quill_banner", "d_odd_helm"]
CREAM, EDGE = "#f4e9cf", "#2a1a0a"
DARK, LIGHT = "#313338", "#ffffff"   # Discord's chat backgrounds


def die_cut(svg, out, size, border):
    """The mark rendered inside the canvas, a cream border grown round its outline, a dark edge round that."""
    inner = size - 4 * border
    tmp = out + ".tmp.png"
    subprocess.run(["rsvg-convert", "-w", str(inner), "-h", str(inner), "-o", tmp, svg], check=True)
    pad = ["-background", "none", "-gravity", "center", "-extent", f"{size}x{size}"]
    grow = lambda r, colour: ["(", tmp, *pad, "-alpha", "extract", "-morphology", "Dilate", f"Disk:{r}",
                              "-background", colour, "-alpha", "shape", ")"]
    subprocess.run(["magick", *grow(border + border // 3 + 1, EDGE), *grow(border, CREAM), "-composite",
                    "(", tmp, *pad, ")", "-composite", "-strip", out], check=True)
    os.remove(tmp)


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for name in MARKS:
        svg = os.path.join(ICON, name + ".svg")
        sticker, emoji = os.path.join(OUT, f"sticker_{name}.png"), os.path.join(OUT, f"emoji_{name}.png")
        die_cut(svg, sticker, 320, 9)
        die_cut(svg, emoji, 128, 3)
        assert os.path.getsize(sticker) < 512 * 1024, sticker
        assert os.path.getsize(emoji) < 256 * 1024, emoji
        print(f"{name}: sticker {os.path.getsize(sticker) // 1024} KB, emoji {os.path.getsize(emoji) // 1024} KB")
        for bg in (DARK, LIGHT):
            tile = os.path.join(OUT, f".tile_{name}_{bg[1:]}.png")
            subprocess.run(["magick", "-size", "300x200", f"xc:{bg}",
                            "(", sticker, "-resize", "160x160", ")", "-geometry", "+10+20", "-composite",
                            "(", emoji, "-resize", "48x48", ")", "-geometry", "+190+40", "-composite",
                            "(", emoji, "-resize", "22x22", ")", "-geometry", "+250+53", "-composite",
                            "(", emoji, "-resize", "22x22", ")", "-geometry", "+190+130", "-composite", tile], check=True)
            tiles.append(tile)
    # rows: one per mark, dark then light
    rows = []
    for k in range(0, len(tiles), 2):
        row = os.path.join(OUT, f".row_{k}.png")
        subprocess.run(["magick", tiles[k], tiles[k + 1], "+append", row], check=True)
        rows.append(row)
    half = (len(rows) + 1) // 2
    cols = []
    for part in (rows[:half], rows[half:]):
        col = os.path.join(OUT, f".col_{len(cols)}.png")
        subprocess.run(["magick", *part, "-append", col], check=True)
        cols.append(col)
    subprocess.run(["magick", *cols, "-background", "#1e1f22", "-splice", "8x0", "+append",
                    os.path.join(OUT, "preview_discord_sizes.png")], check=True)
    for f in tiles + rows + cols:
        os.remove(f)
    print("wrote preview_discord_sizes.png")


if __name__ == "__main__":
    main()
