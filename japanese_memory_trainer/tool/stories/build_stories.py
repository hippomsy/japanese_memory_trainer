"""2026-10-14 N4 이야기 극장 데이터 생성: tool/stories/sNN.py 원고 → assets/stories/n4_stories.json.
사용법: python tool/stories/build_stories.py   (필요: pip install sudachipy sudachidict_core)"""
import importlib.util, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'news_feed'))
from news_build import tokens_of, merge_plain, WORDS, _tok, MODE_C

# 문맥상 Sudachi 읽기를 고쳐야 하는 표기
RUBY_FIX = {'方': 'ほう', '何': 'なに', '一杯': 'いっぱい', '辺り': 'あたり', '上手': 'じょうず',
            '大輝': 'だいき', '健太': 'けんた', '美咲': 'みさき', '翔太': 'しょうた', '山田': 'やまだ',
            '既読': 'きどく', '箱': 'はこ', '間': 'ま'}

# 숫자+조수사 읽기(촉음·탁음) 바로잡기: 이어지는 조각 표기 → 한 덩어리 읽기
COMBOS = {('一', 'か月'): 'いっかげつ', ('一', '週間'): 'いっしゅうかん', ('一', '匹'): 'いっぴき',
          ('二十', '匹'): 'にじゅっぴき', ('七', '本'): 'ななほん', ('三', '階'): 'さんがい',
          ('百', '個'): 'ひゃっこ', ('二十', '個'): 'にじゅっこ', ('百五十', '個'): 'ひゃくごじゅっこ',
          ('一', '日', '中'): 'いちにちじゅう'}

# 핵심 단어가 본문에서 다른 꼴로 나올 때의 표기(여러 조각을 한 단어로 묶는다)
ALIAS = {'気がつく': ['気がつき'], '眠る': ['眠れ'], '申し訳ない': ['申し訳'], '実は': ['実は'],
         '撮る': ['撮れる'], '授業料': ['授業料'], '気をつける': ['気をつけ'], '問題用紙': ['問題用紙'],
         '背が高い': ['背の高い'], 'いつの間にか': ['いつの間にか'], '洗濯物': ['洗濯物'],
         '思い切って': ['思い切って'], 'もしかして': ['もしかして'], 'ごほうび': ['ごほうび']}


# 문맥에 맞지 않는 단어장 뜻 바로잡기: 표기 → None(연결 해제) 또는 (표제어, 읽기, 뜻)
WORD_FIX = {'間': None, '年': None, '気': None, 'タイム': None, '実': None,
            'ホット': ('ホット', 'ホット', '뜨거운(음료), 핫'),
            '違い': ('違いない', 'ちがいない', '틀림없다'),
            '方': ('方', 'ほう', '쪽, 편'),
            'かけ': ('かける', 'かける', '(안경을) 쓰다, 걸다'),
            '立て': ('立てる', 'たてる', '(소리를) 내다, 세우다'),
            '取っ': ('取る', 'とる', '집다, 가져가다, 벗다')}


def _text(t):
    return ''.join(x for x, _ in t['p'])


def fix_counters(out):
    res, i = [], 0
    while i < len(out):
        for key, reading in COMBOS.items():
            n = len(key)
            if tuple(_text(t) for t in out[i:i + n]) == key:
                res.append({'p': [[''.join(key), reading]]}); i += n
                break
        else:
            res.append(out[i]); i += 1
    return res


def apply_alias(out, vocab):
    for word, forms in ALIAS.items():
        if word not in vocab:
            continue
        for form in forms:
            starts, pos = [], 0
            for t in out:
                starts.append(pos); pos += len(_text(t))
            text = ''.join(_text(t) for t in out)
            k = text.find(form)
            if k < 0 or k not in starts:
                continue
            a = starts.index(k)
            end = k + len(form)
            b = a
            while b < len(out) and starts[b] + len(_text(out[b])) < end:
                b += 1
            if b >= len(out) or starts[b] + len(_text(out[b])) != end:
                continue
            parts = [p for t in out[a:b + 1] for p in t['p']]
            v = vocab[word]
            out[a:b + 1] = [{'p': parts, 'lv': v[3], 'w': word, 'reading': v[1], 'meaning': v[2], 'alias': 1}]
    return out


def load(path):
    spec = importlib.util.spec_from_file_location('s', path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.S


def toks(text, vocab):
    out = apply_alias(fix_counters(tokens_of(text, RUBY_FIX)), vocab)
    bases = {}
    for m in _tok.tokenize(text, MODE_C):
        bases.setdefault(m.surface(), m.dictionary_form())
    for t in out:
        if t.pop('alias', None):
            continue
        surf = ''.join(x for x, _ in t['p'])
        base = bases.get(surf, surf)
        hit = vocab.get(t.get('w')) or vocab.get(base) or vocab.get(surf)
        if hit:
            t['lv'] = hit[3]; t['w'] = hit[0]; t['reading'] = hit[1]; t['meaning'] = hit[2]
        elif surf in WORD_FIX and 'lv' in t:
            fix = WORD_FIX[surf]
            if fix is None:
                for k in ('lv', 'w'):
                    t.pop(k, None)
            else:
                t['w'], t['reading'], t['meaning'] = fix
        elif 'lv' in t:
            info = WORDS[t['w']]
            t['reading'] = info[1]; t['meaning'] = info[2]
    return merge_plain(out)


stories = []
for n in range(1, 11):
    s = load(os.path.join(HERE, f's{n:02d}.py'))
    vocab = {}
    for w, r, m in s['words']:
        vocab[w] = [w, r, m, WORDS[w][0] if w in WORDS else 3]
    sentences = []
    for ja, ko in s['sentences']:
        p = ja.startswith('¶'); ja = ja.lstrip('¶')
        d = {'ja': ja, 'ko': ko, 't': toks(ja, vocab)}
        if p: d['p'] = True
        sentences.append(d)
    stories.append({
        'number': s['no'], 'title': s['title'], 'titleKo': s['titleKo'], 'scene': s['scene'],
        'summary': s['summary'], 'titleTokens': toks(s['title'], vocab), 'sentences': sentences,
        'words': list(vocab.values()),
        'grammar': [{'pattern': g[0], 'meaning': g[1], 'note': g[2], 'ja': g[3], 'ko': g[4]} for g in s['grammar']],
        'questions': [{'ja': q[0], 'ko': q[1], 'options': q[2], 'answer': q[3], 'explanation': q[4]} for q in s['questions']],
    })
os.makedirs(os.path.join(ROOT, 'assets', 'stories'), exist_ok=True)
json.dump(stories, open(os.path.join(ROOT, 'assets', 'stories', 'n4_stories.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, separators=(',', ':'))
with open(os.path.join(HERE, 'review.txt'), 'w', encoding='utf-8') as f:
    for st in stories:
        f.write(f"== {st['number']} {st['title']}\n")
        for se in st['sentences']:
            f.write('|'.join(''.join(x + (f'({r})' if r else '') for x, r in t['p']) + ('*' if 'w' in t else '') for t in se['t']) + '\n')
        missing = [w[0] for w in st['words'] if not any(t.get('w') == w[0] for se in st['sentences'] for t in se['t'])]
        if missing: f.write(f'  !! 본문에서 못 찾은 단어: {missing}\n')
print('stories', len(stories), 'sentences', sum(len(s['sentences']) for s in stories))
