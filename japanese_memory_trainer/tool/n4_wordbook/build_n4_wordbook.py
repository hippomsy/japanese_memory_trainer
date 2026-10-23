"""2026-10-09 「딱! 한권 JLPT 단어장 N4」(DAY01~30 MP3) 단어장 데이터 생성.

spec/dayNN.txt + asr/DNN.json(음성 구간) → assets/n4_wordbook/words.json
--audio <DAY01.mp3 … 가 있는 폴더> 를 붙이면 assets/n4_wordbook_audio/dayNN.mp3 도 다시 만든다.

spec 형식 (칸은 ' | ')
  @day 1 | 人間関係 | 인간관계
  W 일본어구간 | 한국어구간 | 표기 | 읽기 | 뜻
     구간 = asr/DNN.json 의 음성 구간 번호(여러 개면 3-4) 또는 '@70.45-71.25'(초). 한국어 음성이 없으면 비워 둔다.
예문은 앱의 JLPT 단어 데이터(assets/data/jlpt_n*_part*.json)에 같은 단어가 있으면 가져온다.
"""
import glob, json, os, random, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'news_feed'))
from news_build import tokens_of, merge_plain, WORDS  # noqa: E402

# 2026-10-09 한자 풀이: 앱의 한자 사전(assets/kanji) + 사전에 없는 글자 보충
KANJI = {}
for name in ('elementary_pdf_kanji.json', 'kanji_info.json'):
    path = os.path.join(ROOT, 'assets', 'kanji', name)
    if os.path.exists(path):
        KANJI.update(json.load(open(path, encoding='utf-8')))
KANJI_FIX = {'伺': ('엿볼 사', 'シ', 'うかが(う)'), '喧': ('지껄일 훤', 'ケン', 'かまびす(しい)'),
             '嘩': ('시끄러울 화', 'カ', 'かまびす(しい)'), '馳': ('달릴 치', 'チ', 'は(せる)'),
             '髭': ('코밑수염 자', 'シ', 'ひげ')}
IS_KANJI = re.compile(r'[\u4e00-\u9fff々]')


def kanji_of(word):
    out = []
    for c in dict.fromkeys(ch for ch in word if IS_KANJI.match(ch) and ch != '々'):
        if c in KANJI_FIX:
            he, on, kun = KANJI_FIX[c]
        elif c in KANJI:
            k = KANJI[c]
            h, e = k.get('h', ''), k.get('e', '')
            he = h if not e else f'{h} {e}'
            on, kun = '・'.join(k.get('on', [])), '・'.join(k.get('kun', []))
        else:
            continue
        out.append([c, he, on, kun])
    return out


RUBY_FIX = {'今朝': 'けさ', '今年': 'ことし', '今度': 'こんど', '一人': 'ひとり', '二人': 'ふたり', '大勢': 'おおぜい',
            '二倍': 'にばい', '何度': 'なんど', '二度と': 'にどと', '下手': 'へた', '上手': 'じょうず', '今夜': 'こんや',
            '昨日': 'きのう', '明日': 'あした', '今日': 'きょう', '一日中': 'いちにちじゅう', '十分': 'じゅっぷん',
            '一時間': 'いちじかん', '三日間': 'みっかかん', '六年間': 'ろくねんかん', '一週間': 'いっしゅうかん'}


def stems(word):
    """본문에서 단어를 찾을 때 쓸 표기(활용형 대비 어간 포함)."""
    out = set()
    for w in word.replace('～', '').split('・'):
        w = w.strip()
        if not w:
            continue
        out.add(w)
        if w.endswith('な') and len(w) > 2:
            out.add(w[:-1])
        if w[-1] in 'うくぐすつぬぶむるい' and len(w) >= 2:
            st = w[:-1]
            if IS_KANJI.search(st) or len(st) >= 3:
                out.add(st)
        if w.endswith('する'):
            out.add(w[:-2])
    return sorted(out, key=len, reverse=True)


def text_of(t):
    return ''.join(p[0] for p in t['p'])


def annotate_reading(text, day_words):
    toks = tokens_of(text, RUBY_FIX)
    # 문장 안 글자 위치 → 단어 id (표기 그대로 먼저, 그다음 활용 어간)
    owner = [None] * len(text)

    def claim(st, w, check=None):
        for m in re.finditer(re.escape(st), text):
            if check and not check(text[:m.start()][-1:], text[m.end():m.end() + 2]):
                continue
            if all(o is None for o in owner[m.start():m.end()]):
                for i in range(m.start(), m.end()):
                    owner[i] = w['id']

    def noun_ok(prev, nxt):
        """한자 명사는 더 긴 한자어의 일부(店員의 店)나 동사 활용(歌って의 歌)이면 건너뛴다."""
        if IS_KANJI.match(prev or ' ') or IS_KANJI.match(nxt[:1] or ' '):
            return False
        return not ('\u3041' <= nxt[:1] <= '\u3096') or nxt[:1] in 'のがをにはでともやへかしすさせだじな'

    words = sorted(day_words, key=lambda x: -len(x['ja']))
    for w in words:
        for full in w['ja'].replace('～', '').split('・'):
            if full.endswith('な') and len(full) > 2:
                full = full[:-1]
            if not full:
                continue
            claim(full, w, noun_ok if all(IS_KANJI.match(c) for c in full) else None)
    cands = sorted(((st, w) for w in words for st in stems(w['ja'])),
                   key=lambda x: (-len(x[0]), 0 if x[1]['ja'].endswith('い') else 1))
    for st, w in cands:
        base = w['ja'].replace('～', '').split('・')[0]
        if st in w['ja'].split('・') and all(IS_KANJI.match(c) for c in st):
            continue  # 한자 명사는 위에서 앞뒤를 확인해 이미 처리했다
        if base.endswith('い') and not base.endswith('じい'):
            claim(st, w, lambda prev, nxt: nxt[:1] in 'くかけさい' or nxt[:2] == 'かっ')
        else:
            claim(st, w)
    pos, used = 0, set()
    by_id = {w['id']: w for w in day_words}
    for t in toks:
        n = len(text_of(t))
        ids = [o for o in owner[pos:pos + n] if o]
        pos += n
        t.pop('lv', None)
        if 'w' in t:
            info = WORDS[t['w']]
            t['reading'], t['meaning'] = info[1], info[2]
        if ids:
            w = by_id[ids[0]]
            t['n'] = w['id']
            t['lv'] = 4
            t['reading'], t['meaning'] = w['r'], w['ko']
            used.add(w['id'])
    return merge_plain(toks), used


def parse_reading():
    days = {}
    for path in sorted(glob.glob(os.path.join(HERE, 'reading', '*.txt'))):
        cur = None
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            head, _, rest = line.partition(' ')
            cols = [c.strip() for c in rest.split(' | ')]
            if head == '@day':
                cur = days[int(cols[0])] = {'title': cols[1], 'titleKo': cols[2], 'sentences': [], 'questions': []}
            elif head == 'S':
                cur['sentences'].append({'ja': cols[0], 'ko': cols[1]})
            elif head == 'Q':
                opts = [o.strip() for o in cols[2].split(' / ')]
                right = [o for o in opts if o.startswith('*')]
                assert len(right) == 1, line
                opts = [o.lstrip('*') for o in opts]
                cur['questions'].append({'ja': cols[0], 'ko': cols[1], 'options': opts,
                                         'right': right[0].lstrip('*'), 'exp': cols[3] if len(cols) > 3 else ''})
            else:
                raise ValueError(f'{path}: {line}')
    return days
PAD_S, PAD_E = 0.3, 0.25

EXAMPLES = {}
for f in sorted(glob.glob(os.path.join(ROOT, 'assets', 'data', 'jlpt_n*_part*.json'))):
    for w in json.load(open(f, encoding='utf-8')):
        if w.get('exampleJapanese'):
            EXAMPLES.setdefault((w['japanese'], w['reading']), w)


def rng(text):
    a, _, b = text.partition('-')
    return int(a), int(b or a)


def span(segs, text):
    if not text:
        return None
    if text.startswith('@'):  # 음성 구간 검출이 놓친 곳은 '@시작-끝'(초)으로 직접 적는다.
        a, _, b = text[1:].partition('-')
        return [float(a), float(b)]
    a, b = rng(text)
    s, e = segs[a]['start'] - PAD_S, segs[b]['end'] + PAD_E
    if a > 0:
        s = max(s, (segs[a - 1]['end'] + segs[a]['start']) / 2)
    if b + 1 < len(segs):
        e = min(e, (segs[b]['end'] + segs[b + 1]['start']) / 2)
    return [round(max(0, s), 2), round(e, 2)]


def main():
    audio_dir = sys.argv[sys.argv.index('--audio') + 1] if '--audio' in sys.argv else None
    days, problems = [], []
    for path in sorted(glob.glob(os.path.join(HERE, 'spec', 'day*.txt'))):
        day = None
        for raw in open(path, encoding='utf-8'):
            line = raw.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            head, _, rest = line.partition(' ')
            cols = [c.strip() for c in rest.split('|')]
            if head == '@day':
                n = int(cols[0])
                segs = json.load(open(os.path.join(HERE, 'asr', f'D{n:02d}.json'), encoding='utf-8'))
                day = {'day': n, 'title': cols[1], 'titleKo': cols[2],
                       'audio': f'assets/n4_wordbook_audio/day{n:02d}.mp3', 'words': [], '_segs': segs}
                days.append(day)
            elif head == 'W':
                segs = day['_segs']
                ja, ko, word, reading, meaning = cols[:5]
                item = {'id': f"d{day['day']:02d}_{len(day['words']) + 1:02d}", 'ja': word,
                        'r': reading, 'ko': meaning, 'js': span(segs, ja)}
                if ko:
                    item['ks'] = span(segs, ko)
                ex = EXAMPLES.get((word, reading))  # 읽기까지 같은 단어만(동형이의어 예문 방지)
                if ex:
                    item['exJa'], item['exKo'] = ex['exampleJapanese'], ex.get('exampleKorean', '')
                kj = kanji_of(word)
                if kj:
                    item['k'] = kj
                if item['js'][1] <= item['js'][0]:
                    problems.append(f"{item['id']} 구간 이상")
                day['words'].append(item)
            else:
                raise ValueError(f'{path}: {line}')
    readings = parse_reading()
    for d in days:
        d.pop('_segs')
        rd = readings.get(d['day'])
        if rd:
            used = set()
            for snt in rd['sentences']:
                snt['t'], u = annotate_reading(snt['ja'], d['words'])
                used |= u
            for qi, q in enumerate(rd['questions']):
                rnd = random.Random(f"n4-reading-{d['day']}-{qi}")
                rnd.shuffle(q['options'])
                q['answer'] = q['options'].index(q.pop('right'))
            rd['used'] = sorted(used)
            d['reading'] = rd
            print(f"DAY {d['day']:02d} 독해: 문장 {len(rd['sentences'])}, 사용 단어 {len(used)}/{len(d['words'])}")
        if audio_dir:
            os.makedirs(os.path.join(ROOT, 'assets', 'n4_wordbook_audio'), exist_ok=True)
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(audio_dir, f"DAY{d['day']:02d}.mp3"),
                            '-vn', '-ac', '1', '-ar', '22050', '-b:a', '32k', '-map_metadata', '-1',
                            os.path.join(ROOT, d['audio'])], check=True)
    out = os.path.join(ROOT, 'assets', 'n4_wordbook', 'words.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump({'days': days}, f, ensure_ascii=False, separators=(',', ':'))
    n = sum(len(d['words']) for d in days)
    print(f'{len(days)} days, {n} words, examples {sum(1 for d in days for w in d["words"] if "exJa" in w)} → {out}')
    for p in problems:
        print('WARN', p)


if __name__ == '__main__':
    main()
