#!/usr/bin/env python3
# The game's icon (assets/art/ui/game_icon.svg: the parts kit, a frog, a horned helm, a shield and a sword on yellow)
# for the boot screen: game_icon.png, the tile as it is, and game_icon_ink.png, its ink alone in white with the yellow
# cut out (tinted when drawn).
import os, re, subprocess
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
INK, YELLOW = '#17110b', '#f2c94c'
svg = open(ROOT + '/assets/art/ui/game_icon.svg').read()
subprocess.run(['rsvg-convert', '-w', '512', '-h', '512', '-o', ROOT + '/src/icons/game_icon.png'], input=svg.encode(), check=True)
head = re.match(r'<svg[^>]*>', svg).group(0)
body = svg[len(head):].rsplit('</svg>', 1)[0]
body = body.replace('<rect width="512" height="512" fill="%s"/>' % YELLOW, '', 1)
assert YELLOW in body and INK in body
mask = body.replace(INK, '#ffffff').replace(YELLOW, '#000000')
ink = f'''{head}<defs><mask id="m" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512">{mask}</mask></defs>
<rect width="512" height="512" fill="#ffffff" mask="url(#m)"/></svg>'''
subprocess.run(['rsvg-convert', '-w', '512', '-h', '512', '-o', ROOT + '/src/icons/game_icon_ink.png'], input=ink.encode(), check=True)
