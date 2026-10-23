import io,json,zipfile,re
from pathlib import Path
import pdfplumber
from PIL import Image
root=Path(__file__).resolve().parents[1]
out=root/'tmp/basicjl'
source=Path('G:/일본어/시원스쿨/테마별로배우는기초일본어청취/강의노트/BasicJL (3).zip')
with zipfile.ZipFile(source) as z:
 for i in range(1,26):
  p=pdfplumber.open(io.BytesIO(z.read(f'BasicJL_{i}.pdf'))).pages[0]
  rows=[]
  for side, bounds in [('left',(180,300)),('right',(410,550))]:
   ww=[w for w in p.extract_words() if bounds[0]<=w['x0']<bounds[1] and 240<w['top']<540 and 11<w['height']<13]
   grouped=[]
   for w in sorted(ww,key=lambda w:(w['top'],w['x0'])):
    if not grouped or abs(w['top']-grouped[-1][0]['top'])>3: grouped.append([])
    grouped[-1].append(w)
   for group in grouped:
    meaning=' '.join(w['text'] for w in sorted(group,key=lambda w:w['x0']))
    if re.search('[가-힣]',meaning): rows.append({'ko':meaning,'side':side,'top':group[0]['top']})
  canvas=Image.new('RGB',(700,220*len(rows)), 'white')
  full=p.to_image(resolution=400).original
  scale=400/72
  for j,r in enumerate(rows):
   x1,x2=(70,180) if r['side']=='left' else (300,415)
   pic=full.crop(tuple(int(v*scale) for v in (x1,r['top']-12,x2,r['top']+18)))
   canvas.paste(pic,(20,j*220))
  canvas.save(out/f'{i:02}_words_v2.png')
  (out/f'{i:02}_words_v2.meta.json').write_text(json.dumps(rows,ensure_ascii=False),encoding='utf8')
