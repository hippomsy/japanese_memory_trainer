"""Export generated master at platform-required sizes; preserve the source."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'assets/branding/haru_icon_master.png').convert('RGB')
store = root / 'store_assets'
source.resize((512, 512), Image.Resampling.LANCZOS).save(store / 'app_icon_512.png')
for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    folder = root / f'android/app/src/main/res/mipmap-{density}'
    side = int(48 * scale)
    source.resize((side, side), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png')
    # Mechanical safe-area padding for adaptive launcher masks.
    adaptive_side = int(108 * scale)
    content_side = round(adaptive_side * .8)
    foreground = Image.new('RGBA', (adaptive_side, adaptive_side), (31, 42, 68, 255))
    foreground.paste(source.resize((content_side, content_side), Image.Resampling.LANCZOS), ((adaptive_side-content_side)//2, (adaptive_side-content_side)//2))
    foreground.save(folder / 'ic_launcher_foreground.png')
ios = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((ios / 'Contents.json').read_text())['images']:
    if 'filename' not in item:
        continue
    size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
    source.resize((size, size), Image.Resampling.LANCZOS).save(ios / item['filename'])
print('Exported 512px store icon, Android legacy/adaptive and iOS icons.')
