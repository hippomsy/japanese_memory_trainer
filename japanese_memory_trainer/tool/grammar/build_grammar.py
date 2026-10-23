"""2026-10-07 일본어 고급 문법 데이터 만들기.

tool/grammar/spec/grammar.txt 를 읽어 assets/grammar/grammar_lessons.json 을 만든다.

형식 (한 줄에 한 항목, 칸은 ' | ' 로 나눈다. 빈칸 정답은 [대괄호] 안에 쓴다)
  # 01 | 동사 ます형 관련 표현1           강의 시작 (번호 | 제목)
  i spring_park                         강의 그림 (assets/illustrations/이름.webp)
  p はじめる | 동사ます형+はじめる | -을/를 시작하다     문법 포인트(표현 | 접속 | 뜻)
  n 동작, 작용의 시작                    바로 위 포인트의 설명 한 줄
  d 降る | [降り]はじめる | (비가) 오기 시작하다       활용 연습(기본형 | 빈칸 문장 | 뜻)
  e 降る | 今朝、6時から雨が[降り]はじめました。 | 오늘 아침 …   예문(기본형 | 문장 | 해석)
  x 食べる | [食べ]ます | -습니다           연습1 활용표(기본형 | 빈칸 | 뜻)
  c 小さい字を[書き]つづけて、手がつかれました。 | 해석 | 書いて / 書き   고르기 문제
  o 3年前に買った古い[スマホ][を][ずっと][使い]つづけています。 | 해석   순서 맞추기(대괄호 = 조각, 정답 순서)
  w 降る | ふる | (비가) 내리다          단어 정리(단어 | 읽기 | 뜻)
'#!' 로 시작하는 줄과 빈 줄은 무시한다.

실행: python tool/grammar/build_grammar.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = ROOT / 'tool' / 'grammar' / 'spec' / 'grammar.txt'
OUT = ROOT / 'assets' / 'grammar' / 'grammar_lessons.json'


def cells(text, n):
    parts = [p.strip() for p in text.split(' | ')]
    return (parts + [''] * n)[:n]


def main():
    lessons, lesson, point = [], None, None
    for no, raw in enumerate(SPEC.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.rstrip()
        if not line.strip() or line.startswith('#!'):
            continue
        tag, _, rest = line.partition(' ')
        rest = rest.strip()
        try:
            if tag == '#':
                num, title = cells(rest, 2)
                lesson = {'no': int(num), 'title': title, 'scene': '', 'points': [],
                          'table': [], 'choice': [], 'order': [], 'words': []}
                lessons.append(lesson)
                point = None
            elif tag == 'i':
                if not (ROOT / 'assets' / 'illustrations' / f'{rest}.webp').exists():
                    raise ValueError('그림 파일이 없음: ' + rest)
                lesson['scene'] = rest
            elif tag == 'p':
                head, form, meaning = cells(rest, 3)
                point = {'head': head, 'form': form, 'meaning': meaning,
                         'notes': [], 'drills': [], 'examples': []}
                lesson['points'].append(point)
            elif tag == 'n':
                point['notes'].append(rest)
            elif tag == 'd':
                base, ja, ko = cells(rest, 3)
                point['drills'].append({'base': base, 'ja': ja, 'ko': ko})
            elif tag == 'e':
                base, ja, ko = cells(rest, 3)
                point['examples'].append({'base': base, 'ja': ja, 'ko': ko})
            elif tag == 'x':
                base, ja, ko = cells(rest, 3)
                lesson['table'].append({'base': base, 'ja': ja, 'ko': ko})
            elif tag == 'c':
                ja, ko, options = cells(rest, 3)
                opts = [o.strip() for o in options.split(' / ') if o.strip()]
                answer = re.search(r'\[(.+?)\]', ja).group(1)
                if answer not in opts:
                    raise ValueError(f'정답 {answer} 가 보기에 없음')
                lesson['choice'].append(
                    {'ja': ja, 'ko': ko, 'options': opts, 'answer': opts.index(answer)})
            elif tag == 'o':
                ja, ko = cells(rest, 2)
                chunks = re.findall(r'\[(.+?)\]', ja)
                if len(chunks) < 2:
                    raise ValueError('조각이 2개 이상 필요')
                lesson['order'].append({'ja': ja, 'ko': ko, 'chunks': chunks})
            elif tag == 'w':
                word, reading, meaning = cells(rest, 3)
                lesson['words'].append({'w': word, 'r': reading, 'm': meaning})
            else:
                raise ValueError('알 수 없는 줄 종류: ' + tag)
        except Exception as error:  # noqa: BLE001
            sys.exit(f'grammar.txt:{no}: {error}\n  {raw}')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'lessons': lessons}, ensure_ascii=False,
                              separators=(',', ':')), encoding='utf-8')
    print(f"{len(lessons)}강 · 문법 포인트 {sum(len(l['points']) for l in lessons)}개 · "
          f"예문 {sum(len(p['examples']) for l in lessons for p in l['points'])}개 · "
          f"고르기 {sum(len(l['choice']) for l in lessons)} · 순서 {sum(len(l['order']) for l in lessons)} · "
          f"단어 {sum(len(l['words']) for l in lessons)}")
    print('저장:', OUT.relative_to(ROOT))


if __name__ == '__main__':
    main()
