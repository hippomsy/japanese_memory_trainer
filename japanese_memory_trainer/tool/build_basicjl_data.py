import json,re,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
tmp=root/'tmp/basicjl'
assets=root/'assets/basicjl'
assets.mkdir(parents=True,exist_ok=True)
sources=json.loads((tmp/'source.json').read_text(encoding='utf8'))
reviewed=json.loads((root/'tool/basicjl_reviewed_words.json').read_text(encoding='utf8'))
reading_map={}
for path in (root/'assets/data').glob('*.json'):
 try:
  data=json.loads(path.read_text(encoding='utf8'))
  if isinstance(data,list):
   for item in data:
    if isinstance(item,dict) and 'reading' in item: reading_map.setdefault(item['japanese'],item['reading'])
 except Exception: pass
def normalized(s):
 return re.sub(r'\s+','',s).replace(':','：')
def main_lines(path, lower=220, upper=1500):
 lines=json.loads(path.read_text(encoding='utf8'))
 rows=[]
 for line in lines:
  ww=line['words']
  if max(w['height'] for w in ww)<20: continue
  y=min(w['y'] for w in ww if w['height']>=20)
  if not lower<y<upper: continue
  if rows and abs(rows[-1]['y']-y)<12: rows[-1]['pieces'].append(line)
  else: rows.append({'y':y,'pieces':[line]})
 # OCR line order is not necessarily the visual order.
 rows.sort(key=lambda r:r['y'])
 merged=[]
 for r in rows:
  if merged and abs(merged[-1]['y']-r['y'])<12: merged[-1]['pieces']+=r['pieces']
  else: merged.append(r)
 return [normalized(''.join(l['text'] for l in sorted(r['pieces'],key=lambda l:min(w['x'] for w in l['words'])))) for r in merged]
def category(n):
 if n in [1,2,3,15]: return '교통 · 길찾기'
 if n in [4,5,6,25]: return '쇼핑 · 편의점'
 if n in [7,8,9]: return '숙박'
 if n in [10,11,12,22]: return '음식 · 주문'
 if n in [18,19,20]: return '건강 · 긴급상황'
 if n in [23,24]: return '우체국 · 은행'
 return '생활 · 문화'
lessons=[]
audit=[]
for source in sources:
 n=source['number']
 meta=json.loads((tmp/f'{n:02}_words_v2.meta.json').read_text(encoding='utf8'))
 ocr=json.loads((tmp/f'{n:02}_words_v2.ocr.json').read_text(encoding='utf8'))
 words=[]
 for j,row in enumerate(meta):
  candidates=[l for l in ocr if j*220<=min(w['y'] for w in l['words'])<(j+1)*220]
  main=[l for l in candidates if max(w['height'] for w in l['words'])>=45]
  japanese=normalized(''.join(l['text'] for l in sorted(main,key=lambda l:min(w['x'] for w in l['words']))))
  if not japanese:
   audit.append({'lesson':n,'row':j,'korean':row['ko']}); continue
  kana=reading_map.get(japanese)
  if not kana:
   small=[l for l in candidates if max(w['height'] for w in l['words'])<45]
   furi=normalized(''.join(l['text'] for l in sorted(small,key=lambda l:min(w['x'] for w in l['words']))))
   kana=furi if re.fullmatch('[ぁ-ゖァ-ヶー・]+',furi) else japanese
  words.append({'japanese':japanese,'reading':kana,'korean':row['ko']})
 checked=[item.split('|') for item in reviewed[str(n)].split(',')]
 assert len(checked)==len(meta),(n,len(checked),len(meta))
 words=[{'japanese':ja,'reading':kana,'korean':row['ko']} for (ja,kana),row in zip(checked,meta)]
 if n==7:
  words[5]['korean']='조식 포함, 아침 제공'
  words.pop(6)
 lines=main_lines(tmp/f'{n:02}_2.ocr.json')
 script=[]
 for line in lines:
  if '：' in line:
   script.append(line.split('：',1)[1])
  elif script: script[-1]+=line
 if n==1:
  script[0]='あの、すみません。ここから渋谷駅までどうやって行きますか。'
 replacements={'タクシ-':'タクシー','カ-ド':'カード','-番':'一番','-つ':'一つ','-本':'一本','くたさい':'ください','ワンピ-ス':'ワンピース','スニ-カ-':'スニーカー','-緒':'一緒','ル-ム':'ルーム','お各様':'お客様','とりあえす':'とりあえず','ビ-ル':'ビール','メニュ-':'メニュー','コ-ス':'コース','工スプレッソ':'エスプレッソ','-度':'一度','アメリカ-ノ':'アメリカーノ','ケ-キ':'ケーキ','チ-ズ':'チーズ','北海は':'北海道は','でしよう':'でしょう','レンタカ-':'レンタカー','なけれは':'なければ','ロ寂しい':'口寂しい','ニ人':'二人','ゲ-ムはかり':'ゲームばかり','呼はれる':'呼ばれる','行けは':'行けば','そう。たから':'そう。だから','びつくり':'びっくり'}
 for old,new in replacements.items(): script=[s.replace(old,new) for s in script]
 if n==11:
  script[0]='いらっしゃいませ。ご注文はお決まりですか。'
  script[-1]=script[-1].replace('日も飲みたい','今日も飲みたい')
 if n==20: script[2]='強盗にバッグを盗まれてしまいました。'
 if n==21: script[0]='聞きましたか。上野さんが結婚するらしいですよ。'
 if n==22: script[0]='ユキちゃん、一緒に来てくれてありがとう。私、本当に日本の料理が作ってみたくて…。'
 if n==25: script[4]='本当に？じゃ、銀行まで行かなくてもいいの？'
 # Scene directions are visible in the source, but are not spoken dialogue.
 script=[re.sub(r'\([^)]*\)','',s) for s in script]
 korean=source['texts'][3]
 korean='\n'.join(l for l in korean.splitlines() if not any(t in l for t in ['Copyrights','저작권법','기초 일본어 청취_']))
 lessons.append({'number':n,'title':source['title'],'category':category(n),'words':words,'script':script,'koreanScript':korean,'extraction':'OCR; original pages available for verification'})
 for page in [0,2]: shutil.copyfile(tmp/f'{n:02}_{page}.png',assets/f'{n:02}_{page}.png')
(root/'assets/data/basicjl_lessons.json').write_text(json.dumps(lessons,ensure_ascii=False,indent=2),encoding='utf8')
(root/'store_assets/basicjl_import_audit.json').write_text(json.dumps({'lessons':25,'words':sum(len(l['words']) for l in lessons),'vocabulary':'manually transcribed Japanese and kana; Korean from source','script':'OCR with corrections; original page included'},ensure_ascii=False,indent=2),encoding='utf8')
print('lessons',len(lessons),'words',sum(len(l['words']) for l in lessons))
print(lessons[0]['words']);print(lessons[0]['script'])
