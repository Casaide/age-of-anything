#!/usr/bin/env python3
# The culture crests (assets/art/ui/crest_<ornament>.svg) cast in each look's metal, as theme.gd's crest_texture
# does (light = metal lightened 0.55, dark = darkened 0.6), rasterised at twice their size into the Lobster
# port's icons/ (crest_<ornament>.png).
import json, os, subprocess
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ui = json.load(open(ROOT + '/data/ui.json'))
base = ui['directions'][ui['direction']]
looks = {base['ornament']: base['metal']}
for fam in json.load(open(ROOT + '/data/families.json')).values():
    if isinstance(fam, dict) and 'ui' in fam and 'ornament' in fam['ui']:
        looks[fam['ui']['ornament']] = fam['ui'].get('metal', base['metal'])

def rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]

def hexc(c):
    return '#' + ''.join('%02x' % round(max(0.0, min(1.0, v)) * 255) for v in c)

for orn, metal in sorted(looks.items()):
    m = rgb(metal)
    light = [v + (1 - v) * 0.55 for v in m]
    dark = [v * 0.4 for v in m]
    svg = open(ROOT + '/assets/art/ui/crest_%s.svg' % orn).read()
    svg = svg.replace('{L}', hexc(light)).replace('{M}', hexc(m)).replace('{D}', hexc(dark))
    out = ROOT + '/tests/lobster_spike/icons/crest_%s.png' % orn
    subprocess.run(['rsvg-convert', '-z', '2', '-o', out], input=svg.encode(), check=True)
    print(orn, metal)
