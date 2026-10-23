"""Extract the supplied study PDF by table row, preserving readings and meanings."""
import json, re
from pathlib import Path
import pdfplumber

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('G:/일본어/일본어_일본초등학교한자1066개.pdf')
words, kanji, audit = [], {}, []
seen = set()
grade = 1
with pdfplumber.open(SOURCE) as doc:
    for number, page in enumerate(doc.pages, 1):
        text = page.extract_text() or ''
        heading = re.search(r'([1-6])학년\s*한자', text)
        if heading:
            grade = int(heading[1])
        for table in page.find_tables():
            for row in table.rows:
                cell = next((c for c in row.cells if c), None)
                if not cell or cell[0] > 92 or cell[2] > 100 or cell[1] < 0:
                    continue
                left = page.crop(cell).extract_text() or ''
                match = re.match(r'\s*([\u3400-\u9fff])\s*\n(.+)', left, re.S)
                if not match:
                    continue
                character, meaning = match[1], ' '.join(match[2].split())
                body = page.crop((92, cell[1], page.width - 20, cell[3])).extract_text() or ''
                readings = {}
                for label, key in [('음', 'on'), ('훈', 'kun')]:
                    m = re.search(label + r'\s*([^|\n]+)', body)
                    readings[key] = re.split('[・·]', m[1].strip()) if m and m[1].strip() != 'ー' else []
                kanji[character] = {'h': meaning, 'e': '', **readings,
                    'n': f'제공 PDF {number}쪽 · 초등 {grade}학년'}
                matches = list(re.finditer(r'([\u3400-\u9fff\u3040-\u30ff々ー]+)\[([^\]]+)\]', body))
                for i, m in enumerate(matches):
                    tail = body[m.end():matches[i+1].start() if i+1 < len(matches) else len(body)]
                    tail = re.split(r'\n\s*[음훈]\s', tail)[0]
                    korean = ' '.join(tail.replace('|', '').split()).strip()
                    if korean == '/' and i + 1 < len(matches):
                        end = matches[i+2].start() if i+2 < len(matches) else len(body)
                        shared = body[matches[i+1].end():end]
                        korean = ' '.join(re.split(r'\n\s*[음훈]\s', shared)[0].replace('|', '').split()).strip()
                    japanese, reading = m[1], re.sub(r'\s+', '', m[2])
                    if not korean or not re.search('[가-힣0-9]', korean):
                        audit.append({'page': number, 'text': m[0], 'tail': tail})
                        continue
                    identity = (japanese, reading)
                    if identity in seen:
                        continue
                    seen.add(identity)
                    words.append({'id': f'pdf_{len(words)+1:04}', 'japanese': japanese,
                        'reading': reading, 'korean': korean, 'exampleJapanese': '',
                        'exampleKorean': '', 'jlptLevel': f'{grade}학년', 'wordType': '한자 어휘',
                        'frequencyRank': len(words)+1, 'sourcePage': number, 'sourceKanji': character})
output = ROOT / 'assets/data/elementary_pdf_words.json'
output.write_text(json.dumps(words, ensure_ascii=False, indent=2), encoding='utf-8')
(ROOT / 'assets/kanji/elementary_pdf_kanji.json').write_text(json.dumps(kanji, ensure_ascii=False, indent=2), encoding='utf-8')
(ROOT / 'store_assets/pdf_import_audit.json').write_text(json.dumps({'words': len(words), 'kanji': len(kanji), 'skipped': audit}, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'words': len(words), 'kanji': len(kanji), 'skipped': len(audit), 'grades': {str(g): sum(w['jlptLevel']==f'{g}학년' for w in words) for g in range(1,7)}}, ensure_ascii=False))
