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
# The Mac's Dock icon (game_icon_mac.png, set by gl.window_icon): macOS doesn't shape or pad a window icon, so it gets
# Apple's app icon grid here: the tile at 824 of 1024, centred, rounded (radius 185) with the template's soft shadow.
inner = svg.replace(head, '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="100" y="100" width="824" height="824" viewBox="0 0 512 512">', 1)
mac = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><clipPath id="c"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
<filter id="s" x="-10%" y="-10%" width="120%" height="130%"><feGaussianBlur stdDeviation="10"/></filter></defs>
<rect x="100" y="112" width="824" height="824" rx="185" fill="#000000" fill-opacity="0.3" filter="url(#s)"/>
<g clip-path="url(#c)">{inner}</g></svg>'''
subprocess.run(['rsvg-convert', '-w', '1024', '-h', '1024', '-o', ROOT + '/src/icons/game_icon_mac.png'], input=mac.encode(), check=True)
