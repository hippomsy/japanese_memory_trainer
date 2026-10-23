"""2026-10-05 문화 독해 데이터 생성: 음성 인식 구간(spec) + 다듬은 스크립트 → JSON·오디오."""
import json, os, random, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'news_feed'))
from news_build import tokens_of, merge_plain, WORDS, align

# 사용법: python tool/bunka/build_bunka.py <bunka.zip을 푼 폴더>
#   (오디오는 --audio 를 붙였을 때만 다시 만든다)
SRC = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else None
OUT = ROOT
L = json.load(open(os.path.join(HERE, 'lessons.json')))
PAD_S, PAD_E = 0.35, 0.15

def segs(t): return json.load(open(os.path.join(HERE, 'asr', f'Track_{t:03d}.json')))

def clip_bounds(sg, a, b):
    s, e = sg[a]['start'], sg[b]['end']
    if a > 0:
        prev_raw_end = sg[a-1]['end'] - PAD_E
        raw_start = s + PAD_S
        if prev_raw_end > s:
            s = max(s, (prev_raw_end + raw_start) / 2)
    if b + 1 < len(sg):
        next_raw_start = sg[b+1]['start'] + PAD_S
        raw_end = e - PAD_E
        if next_raw_start < e:
            e = min(e, (raw_end + next_raw_start) / 2)
    return round(s, 2), round(e, 2)

# Sudachi 읽기 보정(표면형 단위)
RUBY_FIX = {'帯刀': 'たいとう', '七五三': 'しちごさん', '二浪': 'にろう', '三浪': 'さんろう',
            '右前': 'みぎまえ', '左前': 'ひだりまえ', '呉': 'ご', '後払い': 'あとばらい', '後払': 'あとばら',
            '数百': 'すうひゃく', '餃子': 'ぎょうざ', '牽牛': 'けんぎゅう', '熟す': 'じゅくす', '実': 'み',
            '寒気': 'かんき', '科': 'か', '局': 'きょく', '市': 'いち', '30万': 'さんじゅうまん'}
# 여러 조각에 걸친 단어 보정
MULTI_FIX = {'黴雨': 'ばいう', '梅雨前線': 'ばいうぜんせん', '一泊': 'いっぱく', '御祝': 'おいわい',
             '俗世間': 'ぞくせけん', '吉鳥': 'きっちょう', '一年中': 'いちねんじゅう', '夏日': 'なつび'}

def text_of(t): return ''.join(p[0] for p in t['p'])

def merge_multi(toks):
    out, i = [], 0
    while i < len(toks):
        hit = None
        acc = ''
        for j in range(i, min(len(toks), i + 4)):
            acc += text_of(toks[j])
            if acc in MULTI_FIX: hit = (j, acc); break
            if not any(k.startswith(acc) for k in MULTI_FIX): break
        if hit:
            j, key = hit
            out.append({'p': align(key, MULTI_FIX[key])}); i = j + 1
        else:
            out.append(toks[i]); i += 1
    return out

def fix_kazu(toks):
    # 「の数」「数も」처럼 단독 명사로 쓰인 数는 かず
    for i, t in enumerate(toks):
        if text_of(t) == '数' and t['p'][0][1] == 'すう':
            prev = text_of(toks[i-1]) if i > 0 else ''
            nxt = text_of(toks[i+1]) if i + 1 < len(toks) else ''
            if prev[-1:] in ('の', 'る', 'い') or nxt.startswith('も'):
                t['p'] = [['数', 'かず']]
    return toks

def annotate(text):
    toks = merge_plain(fix_kazu(merge_multi(tokens_of(text, RUBY_FIX))))
    for t in toks:
        if 'w' in t:
            info = WORDS[t['w']]
            t['reading'] = info[1]
            t['meaning'] = info[2]
    return toks

def parse(path):
    spec = {'S': [], 'Q': []}
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'): continue
        head, *rest = [x.strip() for x in line.split(' | ')]
        kind, rng = head.split(' ', 1)
        a, _, b = rng.partition('-')
        a = int(a); b = int(b) if b else a
        if kind == 'T':
            spec['T'] = (a, rest[0], rest[1])
        elif kind in ('S', 'S+'):
            spec['S'].append((a, b, kind == 'S+', rest[0], rest[1]))
        elif kind == 'Q':
            spec['Q'].append((a, b, rest[0], rest[1], rest[2], rest[3] if len(rest) > 3 else ''))
        else:
            raise ValueError(line)
    return spec

def encode(src, dst, start=None):
    cmd = ['ffmpeg', '-v', 'error', '-y']
    if start is not None: cmd += ['-ss', f'{start:.2f}']
    cmd += ['-i', src, '-ac', '1', '-ar', '24000', '-b:a', '48k', '-map_metadata', '-1', dst]
    subprocess.run(cmd, check=True)

lessons = []
problems = []
for l in L:
    n = l['n']; path = os.path.join(HERE, 'spec', f'L{n:02d}.txt')
    if not os.path.exists(path): continue
    sp = parse(path); r = segs(l['r']); q = segs(l['q'])
    ta, title, title_ko = sp['T']
    ts, te = clip_bounds(r, ta, ta)
    sentences = []
    last = -1
    for a, b, para, ja, ko in sp['S']:
        if a <= last or b < a or b >= len(r): problems.append(f'L{n} bad range {a}-{b}')
        last = b
        s, e = clip_bounds(r, a, b)
        sentences.append({'ja': ja, 'ko': ko, 't': annotate(ja), 's': s, 'e': e, **({'p': True} if para else {})})
    qstart = None
    questions = []
    for qi, (a, b, ja, ko, opts, expl) in enumerate(sp['Q']):
        if b >= len(q): problems.append(f'L{n} bad q range {a}-{b}')
        s, e = clip_bounds(q, a, b)
        if qstart is None: qstart = max(0, s - 0.2)
        options = [o.strip() for o in opts.split(' / ')]
        correct = [o for o in options if o.startswith('*')]
        assert len(correct) == 1, (n, ja)
        options = [o.lstrip('*') for o in options]
        right = correct[0].lstrip('*')
        rnd = random.Random(f'bunka-{n}-{qi}'); rnd.shuffle(options)
        questions.append({'ja': ja, 'ko': ko, 'options': options, 'answer': options.index(right),
                          'explanation': expl, 's': s, 'e': e})
    for qq in questions:
        qq['s'] = round(qq['s'] - qstart, 2); qq['e'] = round(qq['e'] - qstart, 2)
    # 핵심 단어: 본문에 나온 순서대로 N1~N3 단어(부족하면 N4까지)
    seen, words = set(), []
    for limit in (3, 4):
        for s in sentences:
            for t in s['t']:
                if 'w' in t and t['lv'] <= limit and t['w'] not in seen:
                    seen.add(t['w']); words.append([t['w'], t['reading'], t['meaning'], t['lv']])
        if len(words) >= 6: break
    words = words[:16]
    audio = f'assets/reading_audio/bunka_{n:02d}.mp3'
    qaudio = f'assets/reading_audio/bunka_{n:02d}_q.mp3'
    if SRC and '--audio' in sys.argv:
        os.makedirs(f'{OUT}/assets/reading_audio', exist_ok=True)
        encode(os.path.join(SRC, f'Track_{l["r"]:03d}.mp3'), f'{OUT}/{audio}')
        encode(os.path.join(SRC, f'Track_{l["q"]:03d}.mp3'), f'{OUT}/{qaudio}', qstart)
    lessons.append({'number': n, 'part': l['part'], 'chapter': n if n <= 20 else n - 20,
                    'title': title, 'titleKo': title_ko, 'titleTokens': annotate(title),
                    'audio': audio, 'qaudio': qaudio, 'ts': ts, 'te': te,
                    'sentences': sentences, 'questions': questions, 'words': words})
os.makedirs(f'{OUT}/assets/reading', exist_ok=True)
json.dump(lessons, open(f'{OUT}/assets/reading/bunka_lessons.json', 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(len(lessons), 'lessons', sum(len(x['sentences']) for x in lessons), 'sentences')
print('\n'.join(problems) or 'no problems')
