# 2026-10-01 쉬운 일본어 뉴스 빌더.
# 사람이(또는 Claude가) 쓴 기사 원고(specs/*.json)를 형태소 분석해서
# 후리가나·JLPT 급수·핵심 단어가 붙은 앱용 기사 JSON으로 바꾸고 news.json 피드에 합친다.
#
# 원고 형식(specs/2026-10-01-1.json):
# {"id": "2026-10-01-1", "date": "2026-10-01", "category": "사회",
#  "title": "最低賃金が上がります", "titleKo": "최저임금이 오릅니다",
#  "paragraphs": [{"ja": "...", "ko": "..."}, ...],
#  "ruby": {"1日": "ついたち"}}            # (선택) 읽기 고정
#
# 사용: python3 news_build.py specs/2026-10-01-1.json [specs/...] --feed news.json --keep 30
# 필요: pip install sudachipy sudachidict_core
import argparse
import json
import os
import re
import sys

from sudachipy import dictionary, tokenizer

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS = json.load(open(os.path.join(HERE, 'data', 'words_index.json'), encoding='utf-8'))
_tok = dictionary.Dictionary().tokenizer()
MODE_C = tokenizer.Tokenizer.SplitMode.C
MODE_A = tokenizer.Tokenizer.SplitMode.A

CONTENT_POS = {'名詞', '動詞', '形容詞', '副詞', '形状詞'}
SKIP_POS2 = {'数詞', '固有名詞', '代名詞'}
KANJI = re.compile(r'[㐀-鿿々〆ヶ]')
DEFAULT_RUBY = {'日本': 'にほん', '私': 'わたし', '私たち': 'わたしたち', '下': 'した', '雨': 'あめ',
                '明日': 'あした', '家': 'いえ', '言う': 'いう', '二十': 'にじゅう', '三十': 'さんじゅう',
                '四十': 'よんじゅう', '五十': 'ごじゅう', '六十': 'ろくじゅう', '七十': 'ななじゅう',
                '八十': 'はちじゅう', '九十': 'きゅうじゅう'}
DAYS = {1: 'ついたち', 2: 'ふつか', 3: 'みっか', 4: 'よっか', 5: 'いつか', 6: 'むいか', 7: 'なのか',
        8: 'ようか', 9: 'ここのか', 10: 'とおか', 14: 'じゅうよっか', 20: 'はつか', 24: 'にじゅうよっか'}


def hira(s):
    return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s)


def is_kana(c):
    return '぀' <= c <= 'ヿ' or c == 'ー'


def align(surface, reading):
    """표기와 읽기를 맞춰 [[글자, 후리가나], ...] 조각으로 나눈다. 한자 부분에만 후리가나."""
    if not KANJI.search(surface):
        return [[surface, '']]
    reading = hira(reading)
    # 표기를 한자 덩어리 / 가나 덩어리로 나눈다.
    runs = []
    for ch in surface:
        kind = 'k' if is_kana(ch) else 'x'
        if runs and runs[-1][0] == kind:
            runs[-1][1] += ch
        else:
            runs.append([kind, ch])
    pattern = ''.join('(' + re.escape(hira(t)) + ')' if k == 'k' else '(.+?)' for k, t in runs)
    m = re.fullmatch(pattern, reading)
    if not m:
        return [[surface, reading]]
    parts = []
    for (k, t), g in zip(runs, m.groups()):
        parts.append([t, '' if k == 'k' else g])
    return parts


def lookup(base, surface, reading):
    for key in (base, surface):
        if key in WORDS:
            return key, WORDS[key]
    r = hira(reading)
    if r in WORDS and not KANJI.search(base):
        return r, WORDS[r]
    return None, None


def tokens_of(text, ruby_fix):
    out = []
    for m in _tok.tokenize(text, MODE_C):
        pos = m.part_of_speech()
        subs = [m]
        key, info = lookup(m.dictionary_form(), m.surface(), m.reading_form())
        # 복합어(最低賃金 등)가 단어장에 없으면 더 잘게 나눠 본다.
        if info is None and pos[0] in CONTENT_POS and len(m.surface()) > 2:
            finer = list(m.split(MODE_A))
            if len(finer) > 1 and any(lookup(f.dictionary_form(), f.surface(), f.reading_form())[1] for f in finer):
                subs = finer
        for s in subs:
            p = s.part_of_speech()
            surf = s.surface()
            prev_num = bool(out) and out[-1].get('num')
            # 숫자 + 日 은 날짜 읽기(ついたち, ふつか …)로 한 덩어리로 만든다.
            if prev_num and surf == '日':
                n = int(out[-1]['num'])
                digits = out.pop()['p'][0][0]
                out.append({'p': [[digits + '日', DAYS.get(n, 'にち')]]})
                continue
            reading = ruby_fix.get(surf, DEFAULT_RUBY.get(surf, s.reading_form()))
            tok = {'p': align(surf, reading)}
            if p[1] == '数詞' and surf.isdigit():
                tok['num'] = surf
            # 숫자 바로 뒤의 조수사(月, 円, 号 …)는 급수·핵심 단어에서 뺀다.
            if prev_num:
                out.append(tok)
                continue
            if p[0] in CONTENT_POS and p[1] not in SKIP_POS2:
                key, info = lookup(s.dictionary_form(), surf, s.reading_form())
                if info:
                    tok['lv'] = info[0]
                    tok['w'] = key
            # 같은 글자인 조사·기호는 앞 조각에 붙이지 않고 그대로 둔다(줄바꿈 단위).
            out.append(tok)
    return out


def merge_plain(tokens):
    """급수가 없는 가나/기호 조각은 앞의 가나 조각과 합쳐 화면 조각 수를 줄인다."""
    merged = []
    for t in tokens:
        t.pop('num', None)
        plain = 'lv' not in t and all(r == '' for _, r in t['p'])
        if plain and merged and 'lv' not in merged[-1] and all(r == '' for _, r in merged[-1]['p']):
            merged[-1]['p'][-1][0] += ''.join(x for x, _ in t['p'])
        else:
            merged.append(t)
    return merged


def build(spec):
    fix = spec.get('ruby', {})
    title = merge_plain(tokens_of(spec['title'], fix))
    paras = [{'t': merge_plain(tokens_of(p['ja'], fix)), 'ko': p['ko']} for p in spec['paragraphs']]
    seen = {}
    for tok in title + [t for p in paras for t in p['t']]:
        if 'w' in tok and tok['w'] not in seen:
            seen[tok['w']] = tok['lv']
    dist = {f'N{n}': 0 for n in (5, 4, 3, 2, 1)}
    for lv in seen.values():
        dist[f'N{lv}'] += 1
    # 핵심 단어: 어려운 급수 먼저, 등장 순서대로 최대 8개.
    order = sorted(seen.items(), key=lambda kv: (kv[1], list(seen).index(kv[0])))
    words = []
    for w, lv in order[:8]:
        info = WORDS[w]
        words.append({'jp': w, 'reading': info[1], 'ko': info[2], 'lv': lv})
    return {
        'id': spec['id'], 'date': spec['date'], 'category': spec.get('category', ''),
        'title': title, 'titleKo': spec['titleKo'],
        'paragraphs': paras, 'dist': dist, 'words': words,
        'source': spec.get('source', ''),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('specs', nargs='+')
    ap.add_argument('--feed', default='news.json')
    ap.add_argument('--keep', type=int, default=30)
    a = ap.parse_args()
    feed = {'version': 1, 'articles': []}
    if os.path.exists(a.feed):
        feed = json.load(open(a.feed, encoding='utf-8'))
    byid = {x['id']: x for x in feed['articles']}
    for path in a.specs:
        art = build(json.load(open(path, encoding='utf-8')))
        byid[art['id']] = art
        print('built', art['id'], art['dist'], file=sys.stderr)
    arts = sorted(byid.values(), key=lambda x: x['id'], reverse=True)[:a.keep]
    feed['articles'] = arts
    with open(a.feed, 'w', encoding='utf-8') as f:
        json.dump(feed, f, ensure_ascii=False, separators=(',', ':'))


if __name__ == '__main__':
    main()
