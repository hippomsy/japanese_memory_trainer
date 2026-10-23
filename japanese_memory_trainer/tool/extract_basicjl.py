import io,json,zipfile,re
from pathlib import Path
import pdfplumber
root=Path(__file__).resolve().parents[1]
out=root/'tmp/basicjl'
out.mkdir(parents=True,exist_ok=True)
source=Path('G:/일본어/시원스쿨/테마별로배우는기초일본어청취/강의노트/BasicJL (3).zip')
items=[]
with zipfile.ZipFile(source) as z:
 for i in range(1,26):
  with pdfplumber.open(io.BytesIO(z.read(f'BasicJL_{i}.pdf'))) as doc:
   texts=[p.extract_text() or '' for p in doc.pages]
   title=re.search(r'-\s*(.+?)\s*-',texts[0])
   item={'number':i,'title':title[1] if title else f'{i}강','texts':texts,'pages':len(doc.pages)}
   items.append(item)
   for j in [0,2]:
    doc.pages[j].to_image(resolution=150).save(str(out/f'{i:02}_{j}.png'))
(out/'source.json').write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf8')
print([(i['number'],i['title'],i['pages']) for i in items])
