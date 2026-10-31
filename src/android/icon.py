# The app's icon and splash: the game's icon (assets/art/ui/game_icon.svg: the parts kit on yellow) as an adaptive
# icon (the yellow behind, the ink in front inside the launcher's safe zone) and as plain ic_launcher PNGs for older
# launchers, at every Android density; and the themes that show it while the game starts.
#   python3 icon.py <repo root> <res dir>
import os, re, subprocess, sys
root, res = sys.argv[1], sys.argv[2]
YELLOW, DARK = '#f2c94c', '#120f0c'
svg = open(os.path.join(root, 'assets/art/ui/game_icon.svg')).read()
head = re.match(r'<svg[^>]*>', svg).group(0)
body = svg[len(head):].rsplit('</svg>', 1)[0]
ink = body.replace('<rect width="512" height="512" fill="%s"/>' % YELLOW, '', 1)
assert ink != body
# (the foreground: 108dp, the frame with its stroke (76..436 of 512) in the middle 52dp, its corners inside the
# 66dp circle every launcher mask keeps)
fore = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="108" height="108" viewBox="0 0 108 108">
<svg x="28" y="28" width="52" height="52" viewBox="76 76 360 360">{ink}</svg>
</svg>'''

def render(text, px, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(['rsvg-convert', '-w', str(px), '-h', str(px), '-o', out], input=text.encode(), check=True)

for d, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    render(svg, px, os.path.join(res, f'mipmap-{d}', 'ic_launcher.png'))
    render(fore, px * 108 // 48, os.path.join(res, f'mipmap-{d}', 'ic_launcher_foreground.png'))
os.makedirs(os.path.join(res, 'mipmap-anydpi-v26'), exist_ok=True)
open(os.path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/icon_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
open(os.path.join(res, 'values', 'icon_colors.xml'), 'w').write(f'''<resources>
    <color name="icon_background">{YELLOW}</color>
</resources>
''')
os.makedirs(os.path.join(res, 'values-v31'), exist_ok=True)
open(os.path.join(res, 'values', 'styles.xml'), 'w').write(f'''<resources>
    <style name="GameTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">{DARK}</item>
    </style>
</resources>
''')
open(os.path.join(res, 'values-v31', 'styles.xml'), 'w').write(f'''<resources>
    <style name="GameTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
        <item name="android:windowBackground">{DARK}</item>
        <item name="android:windowSplashScreenBackground">{DARK}</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/icon_background</item>
    </style>
</resources>
''')
