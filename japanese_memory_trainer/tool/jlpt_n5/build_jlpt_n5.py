"""2026-10-08 JLPT N5 청해(완전정복 한 권으로 N5 MP3) 데이터 생성.

spec/tNN.txt(사람이 다듬은 스크립트·문제) + asr/TNN.json(음성 구간) → assets/jlpt_n5/listening.json
--audio <TRACK 01.mp3 … 가 있는 폴더> 를 붙이면 문제별 오디오(assets/jlpt_n5_audio/)도 다시 자른다.

spec 형식 (한 줄 = 한 항목, 칸은 ' | ' 로 구분)
  @track 01 | 회차 | 문제유형(1~4)
  Q 번호 | 시작초                       ← 녹음 속 「N番」 안내가 시작되는 시각
  ASK 질문(일본어) | 한국어              ← 問題1·2 의 질문
  PIC 그림문자 | 상황(일본어) | 한국어    ← 장면 카드(선택)
  L 시작초 | 화자 | 일본어 | 한국어       ← 스크립트 한 줄(ナ = 내레이션)
  O | 그림문자 | 보기 | 한국어            ← 問題1·2 보기(그림 대신 그림문자 카드)
  O 시작초 | | 1. 보기 | 한국어           ← 問題3·4 보기(음성으로 나오는 보기)
  O* …                                  ← 정답
  EXP 해설 / NOTE 주의 문구
"""
import json, os, random, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'news_feed'))
from news_build import tokens_of, merge_plain, WORDS  # noqa: E402

RUBY_FIX = {'今晩': 'こんばん', '何時': 'なんじ', '何時間': 'なんじかん', '何曜日': 'なんようび', '何回': 'なんかい',
            '何日': 'なんにち', '何': 'なに', '一人': 'ひとり', '二人': 'ふたり', '一緒': 'いっしょ', '上手': 'じょうず',
            '大人': 'おとな', '今日': 'きょう', '昨日': 'きのう', '明日': 'あした', '一つ': 'ひとつ', '二つ': 'ふたつ',
            '三つ': 'みっつ', '一匹': 'いっぴき', '後': 'あと', '方': 'ほう', '間': 'あいだ', '辛い': 'からい',
            '本田': 'ほんだ', '斉藤': 'さいとう', '中原': 'なかはら', '山本': 'やまもと', '高木': 'たかぎ',
            '白田': 'しろた', '青山': 'あおやま', '河村': 'かわむら', '島田': 'しまだ', '中野': 'なかの',
            '木村': 'きむら', '林': 'はやし', '中山': 'なかやま', '坂本': 'さかもと', '中田': 'なかた', '田中': 'たなか',
            '吉田': 'よしだ', '太田': 'おおた', '山田': 'やまだ', '鈴木': 'すずき', '下': 'した', '上': 'うえ'}
MONDAI = {1: '課題理解', 2: 'ポイント理解', 3: '発話表現', 4: '即時応答'}
MONDAI_KO = {1: '과제 이해', 2: '포인트 이해', 3: '발화 표현', 4: '즉시 응답'}
TESTS = {1: ('第1回', '실전 문제 1회'), 2: ('第2回', '실전 문제 2회'),
         3: ('模擬テスト1', '모의고사 1회'), 4: ('模擬テスト2', '모의고사 2회')}
PAD_BEFORE, TAIL = 0.4, 1.2


def annotate(text):
    toks = tokens_of(text, RUBY_FIX)
    for i, t in enumerate(toks):  # 何と言いますか → なん
        if ''.join(p[0] for p in t['p']) == '何' and i + 1 < len(toks) \
                and toks[i + 1]['p'][0][0].startswith(('と', 'の', 'て')):
            t['p'] = [['何', 'なん']]
    toks = merge_plain(toks)
    for t in toks:
        if 'w' in t:
            info = WORDS[t['w']]
            t['reading'], t['meaning'] = info[1], info[2]
    return toks


def parse(path):
    tracks, cur = [], None
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        head, _, rest = line.partition(' ')
        cols = [c.strip() for c in rest.split(' | ')]
        if head == '@track':
            tracks.append({'track': cols[0], 'test': int(cols[1]), 'mondai': int(cols[2]),
                           'questions': [], 'skip': []})
        elif head == 'Q':
            cur = {'no': int(cols[0]), 'start': float(cols[1]), 'end': float(cols[2]) if len(cols) > 2 else None, 'lines': [], 'options': [],
                   'ask': None, 'pic': None, 'exp': '', 'note': ''}
            tracks[-1]['questions'].append(cur)
        elif head == 'ASK':
            cur['ask'] = {'ja': cols[0], 'ko': cols[1]}
        elif head == 'PIC':
            cur['pic'] = {'emoji': cols[0], 'ja': cols[1], 'ko': cols[2]}
        elif head == 'L':
            cur['lines'].append({'t': float(cols[0]), 'sp': cols[1], 'ja': cols[2], 'ko': cols[3]})
        elif head in ('O', 'O*'):
            parts = [c.strip() for c in line.split('|')]
            hp = parts[0].split()
            cur['options'].append({'t': float(hp[1]) if len(hp) > 1 else None, 'emoji': parts[1],
                                   'ja': parts[2], 'ko': parts[3], 'ok': hp[0] == 'O*'})
        elif head == 'EXP':
            cur['exp'] = rest.strip()
        elif head == 'NOTE':
            cur['note'] = rest.strip()
        else:
            raise ValueError(f'{path}: {line}')
    return tracks


def last_end(segs, a, b):
    """[a, b) 사이에서 시작하는 음성 구간의 마지막 끝 시각."""
    ends = [s['end'] for s in segs if a - 0.05 <= s['start'] < b]
    return max(ends) if ends else a + 2


def main():
    audio_dir = None
    if '--audio' in sys.argv:
        audio_dir = sys.argv[sys.argv.index('--audio') + 1]
    out_audio = os.path.join(ROOT, 'assets', 'jlpt_n5_audio')
    os.makedirs(out_audio, exist_ok=True)
    questions, problems = [], []
    for name in sorted(os.listdir(os.path.join(HERE, 'spec'))):
        for tr in parse(os.path.join(HERE, 'spec', name)):
            segs = json.load(open(os.path.join(HERE, 'asr', f"T{tr['track']}.json"), encoding='utf-8'))
            track_end = segs[-1]['end'] + 3
            qs = tr['questions']
            for i, q in enumerate(qs):
                nxt = qs[i + 1]['start'] if i + 1 < len(qs) else (tr.get('end') or track_end)
                if i + 1 == len(qs):  # 마지막 문제 뒤의 안내(「ちょっと休みましょう」 등)는 빼고 끝낸다.
                    marks = [x['t'] for x in q['lines'] + q['options'] if x['t'] is not None]
                    nxt = min(nxt, max(marks) + 25)
                if q['end']:
                    nxt = q['end']
                c0 = max(0.0, q['start'] - PAD_BEFORE)
                c1 = last_end(segs, q['start'], nxt) + TAIL
                points = [l['t'] for l in q['lines']] + [o['t'] for o in q['options'] if o['t'] is not None]
                if points != sorted(points):
                    problems.append(f"{tr['track']}-{q['no']}: 시각 순서가 이상함")
                timed = sorted(points) + [c1 - TAIL + 0.01]

                def span(t):
                    later = [p for p in timed if p > t + 0.01]
                    e = last_end(segs, t, later[0]) if later else c1
                    return [round(t - c0 - 0.15, 2), round(min(e + 0.25, c1) - c0, 2)]
                lines = [{'sp': l['sp'], 'ja': l['ja'], 'ko': l['ko'], 'r': annotate(l['ja']),
                          'span': span(l['t'])} for l in q['lines']]
                options = []
                for o in q['options']:
                    item = {'ja': o['ja'], 'ko': o['ko']}
                    if o['emoji']:
                        item['emoji'] = o['emoji']
                    if o['t'] is not None:
                        item['span'] = span(o['t'])
                    options.append(item)
                # 問題1·2 그림 보기는 정답 위치가 고르게 섞이도록 섞는다(숫자 보기는 순서 유지).
                if tr['mondai'] <= 2 and not all(o['ja'][:1].isdigit() for o in q['options']):
                    order = list(range(len(options)))
                    random.Random(f"jlpt-n5-{tr['test']}-{tr['mondai']}-{q['no']}").shuffle(order)
                    options = [options[k] for k in order]
                    q['options'] = [q['options'][k] for k in order]
                answers = [k for k, o in enumerate(q['options']) if o['ok']]
                if len(answers) != 1:
                    problems.append(f"{tr['track']}-{q['no']}: 정답이 {len(answers)}개")
                if tr['mondai'] <= 2 and not q['ask']:
                    problems.append(f"{tr['track']}-{q['no']}: 질문(ASK) 없음")
                qid = f"{tr['test']}-{tr['mondai']}-{q['no']}"
                audio = f"assets/jlpt_n5_audio/n5_{tr['test']}_{tr['mondai']}_{q['no']:02d}.mp3"
                questions.append({
                    'id': qid, 'test': tr['test'], 'mondai': tr['mondai'], 'no': q['no'],
                    'audio': audio, 'duration': round(c1 - c0, 2),
                    **({'ask': {**q['ask'], 'r': annotate(q['ask']['ja'])}} if q['ask'] else {}),
                    **({'pic': q['pic']} if q['pic'] else {}),
                    'lines': lines, 'options': options, 'answer': answers[0] if answers else 0,
                    'exp': q['exp'], **({'note': q['note']} if q['note'] else {}),
                    'source': {'track': f"TRACK {tr['track']}.mp3", 'start': round(c0, 2), 'end': round(c1, 2)},
                })
                if audio_dir:
                    src = os.path.join(audio_dir, f"TRACK {tr['track']}.mp3")
                    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{c0:.2f}', '-t', f'{c1 - c0:.2f}',
                                    '-i', src, '-ac', '1', '-ar', '24000', '-b:a', '40k', '-map_metadata', '-1',
                                    os.path.join(ROOT, audio)], check=True)
    tests = [{'id': k, 'title': v[0], 'ko': v[1]} for k, v in TESTS.items()
             if any(q['test'] == k for q in questions)]
    data = {'tests': tests,
            'mondai': [{'id': k, 'ja': MONDAI[k], 'ko': MONDAI_KO[k]} for k in MONDAI],
            'questions': questions}
    out = os.path.join(ROOT, 'assets', 'jlpt_n5', 'listening.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{len(questions)} questions → {out}')
    for p in problems:
        print('WARN', p)


if __name__ == '__main__':
    main()
