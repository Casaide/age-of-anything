"""Writes the game icon concepts, round I5 (2026-10-19), into docs/concepts/icon/: flat, the genre's way.
Dominic on I4: "gradient makes them look super dated. dice is a nice idea maybe. But please look at icons from
other games in the genre." The genre's icons (the top-selling strategy games' Steam icons, looked at 2026-10-19)
are flat: one emblem in one or two colours on a flat full-bleed field (mostly near-black, else one strong colour),
no gradients, bevels, rims or cartoon outlines; shapes are split by gaps of the field, not ink lines. So I5 redraws
the two ideas Dominic liked, the die (I4 J1) and the odd helm (I1 D / I3), that way: flat fills, square full-bleed
field (the platforms round the corners), two colours and at most one accent.
Run: python3 tools/ui/icon_concepts_i5.py

  K1 die, bone on black     the race die: faces in three flat tones, creature pips (frog, rat, spider) in black
  K2 die, black on gold     the same die inverted onto the gold accent
  K3 helm, bone on red      the odd helm: horn and rat's ear, one bone colour on lacquer red, gold eyes
  K4 frog helm, on black    the I3 frog helm flat: frog's eyes up through the crown, gold, bone on black
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import icon_concepts as ic   # noqa: E402
import icon_concepts_i2b as i2b   # noqa: E402

BLACK, BONE, BONE2, BONE3 = "#15110d", "#f1e6cc", "#d2c19b", "#a8946a"
GOLD, RED = "#f2c94c", "#a3311b"


def flat(field, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'<rect width="512" height="512" fill="{field}"/>{body}</svg>\n')


# --- the die ----------------------------------------------------------------------------------------------------
def pips(ink, face):
    """Creature pips drawn in -60..60: frog, rat, spider (ink on the face colour)."""
    frog = (f'<circle cx="-30" cy="-22" r="22" fill="{ink}"/><circle cx="30" cy="-22" r="22" fill="{ink}"/>'
            f'<path d="M-56,6 C-56,-14 56,-14 56,6 C56,40 30,52 0,52 C-30,52 -56,40 -56,6 Z" fill="{ink}"/>'
            f'<circle cx="-30" cy="-24" r="9" fill="{face}"/><circle cx="30" cy="-24" r="9" fill="{face}"/>'
            f'<path d="M-36,22 Q0,40 36,22" fill="none" stroke="{face}" stroke-width="6" stroke-linecap="round"/>')
    rat = (f'<circle cx="-34" cy="-30" r="24" fill="{ink}"/><circle cx="34" cy="-30" r="24" fill="{ink}"/>'
           f'<path d="M-34,-6 C-34,-24 34,-24 34,-6 C34,16 12,46 0,54 C-12,46 -34,16 -34,-6 Z" fill="{ink}"/>'
           f'<circle cx="-14" cy="0" r="5" fill="{face}"/><circle cx="14" cy="0" r="5" fill="{face}"/>'
           f'<path d="M-20,30 L-58,22 M-20,36 L-58,42 M20,30 L58,22 M20,36 L58,42" stroke="{ink}" stroke-width="4" stroke-linecap="round"/>')
    spider = (f'<ellipse cx="0" cy="12" rx="24" ry="28" fill="{ink}"/><circle cx="0" cy="-22" r="16" fill="{ink}"/>'
              + "".join(f'<path d="M{8 * sx},{y0} Q{40 * sx},{y0 - 26 + k * 4} {58 * sx},{y0 + 10 + k * 6}" fill="none" stroke="{ink}" '
                        f'stroke-width="8" stroke-linecap="round"/>' for k, y0 in enumerate((-8, 4, 16, 28)) for sx in (-1, 1)))
    return frog, rat, spider


def die(field, tones, ink):
    """An isometric die, faces inset so the field shows between them; pips mapped onto each face."""
    top, left, right = tones
    shrink = lambda path, cx, cy: f'<path d="{path}" transform="translate({cx},{cy}) scale(0.94) translate({-cx},{-cy})"'
    faces = (shrink("M256,70 L426,168 L256,266 L86,168 Z", 256, 168) + f' fill="{top}"/>'
             + shrink("M86,168 L256,266 L256,462 L86,364 Z", 171, 315) + f' fill="{left}"/>'
             + shrink("M256,266 L426,168 L426,364 L256,462 Z", 341, 315) + f' fill="{right}"/>')
    frog_t, rat_t, spider_t = pips(ink, top)
    frog_l, _, _ = pips(ink, left)
    _, rat_r, _ = pips(ink, right)
    marks = (f'<g transform="matrix(1.2,-0.69,1.2,0.69,256,168)">{spider_t}</g>'
             f'<g transform="matrix(1.2,0.69,0,1.38,171,315)">{frog_l}</g>'
             f'<g transform="matrix(1.2,-0.69,0,1.38,341,315)">{rat_r}</g>')
    return flat(field, faces + marks)


# --- the odd helm -----------------------------------------------------------------------------------------------
SHELL = ("M150,330 C142,190 196,130 256,130 C316,130 370,190 362,330 C362,382 330,412 300,420 L292,330 "
         "L220,330 L212,420 C182,412 150,382 150,330 Z")
SLOT = "M180,300 C190,268 224,262 248,270 L248,330 L264,330 L264,270 C288,262 322,268 332,300 L326,332 L186,332 Z"
HORN = "M188,206 C130,200 82,160 78,64 C108,118 146,140 196,158 Z"
EAR = "M318,190 C330,108 400,72 440,104 C470,130 446,206 368,234 Z"
EAR_IN = "M336,190 C350,132 398,108 424,126 C442,142 424,192 368,214 Z"


def helm(field, bone, eyes, extra_behind="", extra_front=""):
    """One bone colour on the field: parts behind, the shell outlined in the field colour (the gap that splits
    shapes), the slot and the brim and crest cut as field-coloured gaps, eyes in the slot."""
    gap = f'stroke="{field}" stroke-width="14" stroke-linejoin="round"'
    body = (extra_behind
            + f'<path d="{SHELL}" fill="{bone}" {gap}/>'
            + f'<path d="{SLOT}" fill="{field}"/>'
            + f'<path d="M248,262 H264 V392 L256,404 L248,392 Z" fill="{bone}"/>'
            + f'<path d="M154,286 C210,262 302,262 358,286" fill="none" stroke="{field}" stroke-width="10"/>'
            + f'<path d="M226,134 C232,180 234,230 236,262 M286,134 C280,180 278,230 276,262" fill="none" stroke="{field}" stroke-width="8"/>'
            + eyes + extra_front)
    return flat(field, body)


def option_k3():
    behind = (f'<path d="{HORN}" fill="{BONE}"/>'
              f'<path d="{EAR}" fill="{BONE}"/><path d="{EAR_IN}" fill="{RED}" transform="translate(392,160) scale(0.62) translate(-392,-160)"/>')
    eyes = f'<ellipse cx="214" cy="306" rx="14" ry="9" fill="{GOLD}"/><ellipse cx="298" cy="306" rx="14" ry="9" fill="{GOLD}"/>'
    return helm(RED, BONE, eyes, behind)


def option_k4():
    def eye(cx):
        return (f'<circle cx="{cx}" cy="168" r="60" fill="{BLACK}"/><circle cx="{cx}" cy="168" r="52" fill="{BONE}"/>'
                f'<circle cx="{cx}" cy="166" r="32" fill="{GOLD}"/><ellipse cx="{cx}" cy="168" rx="20" ry="8" fill="{BLACK}"/>')
    eyes = f'<circle cx="214" cy="306" r="5" fill="{BONE}"/><circle cx="298" cy="306" r="5" fill="{BONE}"/>'
    return helm(BLACK, BONE, eyes, "", eye(190) + eye(322))


OPTIONS = {
    "k1_die_bone_on_black": (lambda: die(BLACK, (BONE, BONE2, BONE3), BLACK), "K1  Die on black|bone faces, creature|pips: frog, rat, spider"),
    "k2_die_black_on_gold": (lambda: die(GOLD, ("#2a221a", "#1c1610", BLACK), GOLD), "K2  Die on gold|the same, inverted|onto the gold accent"),
    "k3_helm_bone_on_red": (option_k3, "K3  Helm on red|horn and rat's ear,|bone, gold eyes"),
    "k4_frog_helm_on_black": (option_k4, "K4  Frog helm|frog's eyes up through|the crown, bone and|gold on black"),
}


def main():
    for key, (fn, _) in OPTIONS.items():
        with open(os.path.join(ic.OUT, f"{key}.svg"), "w") as f:
            f.write(fn())
        print("wrote", key)
    sizes = os.path.join(ic.OUT, ".sheet_i5_sizes.png")
    ctx = os.path.join(ic.OUT, ".sheet_i5_ctx.png")
    ic.sheet([(key, title) for key, (_, title) in OPTIONS.items()], os.path.basename(sizes),
             "Game icon, concept round I5: flat, the genre's way")
    i2b.context(list(OPTIONS), ctx)
    subprocess.run(["magick", sizes, ctx, "-background", "#2b2420", "-gravity", "west", "-append",
                    os.path.join(ic.OUT, "sheet_i5.png")], check=True)
    os.remove(sizes)
    os.remove(ctx)
    print("wrote sheet_i5.png")


if __name__ == "__main__":
    main()
