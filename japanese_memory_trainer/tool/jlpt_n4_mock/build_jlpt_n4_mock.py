"""2026-10-10 JLPT N4 모의고사(언어지식·독해) 데이터 생성.

spec/mockN.txt → assets/jlpt_n4_mock/mock.json

spec 형식 (칸은 ' | ' 로 구분)
  @set 번호 | 일본어 제목 | 한국어 제목
  @section id | 일본어 이름 | 제한 시간(분)
  @mondai 번호 | 일본어 지시문 | 한국어 지시문
  @passage … @end           ← 다음 Q 들이 공유하는 지문. '| ' 로 시작하는 줄은 표의 행
  Q 문제 | *정답 / 보기 / 보기 / 보기 | 한국어 해설
     문제 속 【말】 은 밑줄, （　） 은 빈칸, ★ 은 별표 칸
보기 순서는 (회차·섹션·번호) 로 고정된 난수로 섞어 정답 위치가 고르게 퍼지게 한다.

spec/mockN_ko.txt (2026-10-10 연습 모드용 해석)
  v1 | 정답 문장 해석 | 보기 뜻 4개(spec 순서, '-' 는 숨김) | (선택) 정답 문장 일본어
  @pko grammar 3 0 … @end   ← 섹션·問題·지문 번호별 지문 해석
정답 문장(빈칸에 정답을 넣은 문장)·보기·지문은 sudachi 로 나눠 후리가나와 단어 뜻(tokens)을 붙인다.
"""
import json, os, random, sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'jlpt_n4_mock', 'mock.json')
sys.path.insert(0, os.path.join(ROOT, 'news_feed'))
sys.path.insert(0, os.path.join(ROOT, 'tool', 'jlpt_n5'))
from news_build import tokens_of, merge_plain, WORDS  # noqa: E402
from build_jlpt_n5 import RUBY_FIX  # noqa: E402
import re  # noqa: E402

EXPECT = {'vocab': [7, 5, 8, 4, 4], 'grammar': [13, 4, 4, 3, 3, 2]}


def parse(path):
    data, sec, mon, passage, buf = None, None, None, None, None
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if buf is not None:
            if line.strip() == '@end':
                passage = parse_passage(buf)
                mon['passages'].append(passage)
                buf = None
            else:
                buf.append(line)
            continue
        if not line.strip() or line.startswith('#'):
            continue
        head, _, rest = line.partition(' ')
        cols = [c.strip() for c in rest.split(' | ')]
        if head == '@set':
            data = {'no': int(cols[0]), 'title': cols[1], 'titleKo': cols[2], 'sections': []}
        elif head == '@section':
            sec = {'id': cols[0], 'title': cols[1], 'minutes': int(cols[2]), 'mondai': []}
            data['sections'].append(sec)
        elif head == '@mondai':
            mon = {'no': int(cols[0]), 'ja': cols[1], 'ko': cols[2], 'passages': [], 'questions': []}
            sec['mondai'].append(mon)
            passage = None
        elif head == '@passage':
            buf = []
        elif head == 'Q':
            assert len(cols) == 3, line
            opts = [o.strip() for o in cols[1].split(' / ')]
            assert len(opts) == 4, line
            stars = [o for o in opts if o.startswith('*')]
            assert len(stars) == 1, line
            q = {'stem': cols[0], 'options': [o.lstrip('*') for o in opts],
                 'answer': [o.lstrip('*') for o in opts].index(stars[0].lstrip('*')),
                 'exp': cols[2], 'passage': len(mon['passages']) - 1 if mon['passages'] else None}
            assert len(set(q['options'])) == 4, line
            mon['questions'].append(q)
        else:
            raise ValueError(line)
    return data


def parse_passage(lines):
    blocks, table = [], None
    for ln in lines:
        if ln.startswith('| '):
            row = [c.strip() for c in ln[2:].split(' | ')]
            if table is None:
                table = {'table': [row]}
                blocks.append(table)
            else:
                table['table'].append(row)
        else:
            table = None
            if ln.strip():
                blocks.append({'p': ln.strip()})
    return blocks


def annotate(text):
    toks = merge_plain(tokens_of(text, RUBY_FIX))
    for t in toks:
        if 'w' in t:
            info = WORDS[t['w']]
            t['reading'], t['meaning'] = info[1], info[2]
    assert ''.join(p[0] for t in toks for p in t['p']) == text, text
    return toks


def answer_sentence(sec, mondai, q):
    """빈칸·밑줄에 정답을 넣은 완성 문장."""
    stem, right = q['stem'], q['options'][q['answer']]
    if '（　）' in stem:
        return stem.replace('（　）', right)
    if '★' in stem:
        m = re.search(r'바른 순서: (.+?)\. \(', q['exp'])
        body = m.group(1).replace('(★)', '').replace(' ', '')
        prefix = stem.split('＿')[0].strip().replace('\u3000', '')
        if not body.startswith(prefix):
            body = prefix + body
        return body + '。'
    if '【' in stem:
        if sec == 'vocab' and mondai == 5:
            return right
        if sec == 'vocab' and mondai == 2:
            return re.sub(r'【[^】]*】', right, stem)
        return stem.replace('【', '').replace('】', '')
    return stem


def parse_ko(path):
    qs, pko, buf = {}, {}, None
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if buf is not None:
            if line.strip() == '@end':
                buf = None
            elif line.strip():
                buf.append(line.strip())
            continue
        if not line.strip() or line.startswith('#'):
            continue
        if line.startswith('@pko'):
            _, sec, mon, idx = line.split()
            buf = pko[(sec, int(mon), int(idx))] = []
            continue
        cols = [c.strip() for c in line.split(' | ')]
        opts = [o.strip() for o in cols[2].split(' / ')]
        assert len(opts) == 4, line
        qs[cols[0]] = {'ko': cols[1], 'optKo': ['' if o == '-' else o for o in opts],
                       'ja': cols[3] if len(cols) > 3 else None}
    return qs, pko


def attach_ko(data, path):
    qs, pko = parse_ko(path)
    used = set()
    for sec in data['sections']:
        n = 0
        for m in sec['mondai']:
            for i, p in enumerate(m['passages']):
                ko = pko.get((sec['id'], m['no'], i))
                assert ko, (data['no'], sec['id'], m['no'], i)
                m['passages'][i] = {'blocks': p, 'ko': ko}
                for b in p:
                    if 'p' in b:
                        b['t'] = annotate(b['p'])
            for q in m['questions']:
                n += 1
                k = f"{sec['id'][0]}{n}"
                assert k in qs, (data['no'], k)
                used.add(k)
                info = qs[k]
                q['ko'], q['optKo'] = info['ko'], info['optKo']
                q['ja'] = info['ja'] or answer_sentence(sec['id'], m['no'], q)
                q['jaT'] = annotate(q['ja'])
                q['optT'] = [annotate(o) for o in q['options']]
    assert used == set(qs), set(qs) - used


def finalize(data):
    for sec in data['sections']:
        counts = [len(m['questions']) for m in sec['mondai']]
        assert counts == EXPECT[sec['id']], (data['no'], sec['id'], counts)
        n = 0
        pos = Counter()
        for m in sec['mondai']:
            for q in m['questions']:
                n += 1
                q['no'] = n
                rnd = random.Random(f"n4mock-{data['no']}-{sec['id']}-{n}")
                order = list(range(4))
                rnd.shuffle(order)
                right = q['options'][q['answer']]
                q['options'] = [q['options'][i] for i in order]
                q['optKo'] = [q['optKo'][i] for i in order]
                q['optT'] = [q['optT'][i] for i in order]
                q['answer'] = q['options'].index(right)
                pos[q['answer']] += 1
        print(f"  {data['no']}회 {sec['id']}: {n}문항, 정답 위치 {dict(sorted(pos.items()))}")
    return data


def main():
    sets = []
    for fn in sorted(os.listdir(os.path.join(HERE, 'spec'))):
        if fn.endswith('.txt') and not fn.endswith('_ko.txt'):
            data = parse(os.path.join(HERE, 'spec', fn))
            attach_ko(data, os.path.join(HERE, 'spec', fn.replace('.txt', '_ko.txt')))
            sets.append(finalize(data))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'title': 'JLPT N4 모의고사', 'sets': sets}, f, ensure_ascii=False, separators=(',', ':'))
    print('wrote', OUT, os.path.getsize(OUT))


if __name__ == '__main__':
    sys.exit(main())
