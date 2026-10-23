import json, os, sys
from PIL import Image, ImageDraw, ImageFont
exec(open('emap.py').read())
F = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf', 109, layout_engine=ImageFont.Layout.RAQM)
d = json.load(open('/mnt/user-data/uploads/japanese_memory_trainer/assets/n4_wordbook/words.json'))
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
def glyph(s):
    im = Image.new('RGBA', (400, 160), (0,0,0,0))
    ImageDraw.Draw(im).text((10, 10), s, font=F, embedded_color=True)
    bb = im.getbbox()
    im = im.crop(bb)
    return im
bad = []
S = 160
for day in d['days']:
    toks = E[day['day']].split()
    if len(toks) != len(day['words']): print('COUNT', day['day'], len(toks), len(day['words']))
    for w, t in zip(day['words'], toks):
        parts = t.split('+')
        g = glyph(parts[0])
        if g.width > 150: bad.append((w['id'], w['ja'], parts[0], g.width))
        canvas = Image.new('RGBA', (S, S), (0,0,0,0))
        main = 126 if len(parts) > 1 else 138
        sc = main / max(g.size); g2 = g.resize((round(g.width*sc), round(g.height*sc)), Image.LANCZOS)
        ox = (S - g2.width)//2 - (10 if len(parts)>1 else 0); oy = (S - g2.height)//2 - (10 if len(parts)>1 else 0)
        canvas.alpha_composite(g2, (max(0,ox), max(0,oy)))
        if len(parts) > 1:
            b = glyph(parts[1])
            if b.width > 150: bad.append((w['id'], w['ja'], parts[1], b.width))
            R = 70
            circ = Image.new('RGBA', (R, R), (0,0,0,0)); dr = ImageDraw.Draw(circ)
            dr.ellipse((0,0,R-1,R-1), fill=(255,255,255,255), outline=(225,220,210,255), width=3)
            bs = 48 / max(b.size); b2 = b.resize((round(b.width*bs), round(b.height*bs)), Image.LANCZOS)
            circ.alpha_composite(b2, ((R-b2.width)//2, (R-b2.height)//2))
            canvas.alpha_composite(circ, (S-R, S-R))
        canvas.save(f"{OUT}/{w['id']}.webp", 'WEBP', quality=82, method=4)
print('bad', bad)
