"""2026-10-06 스크린 일본어 데이터 만들기.

tool/screen/spec/*.txt (영화 한 편당 파일 하나)를 읽어
assets/screen/screen_lessons.json 을 만든다.

스펙 형식 (한 줄에 한 항목, 칸은 ' | ' 로 나눈다)
  @id v1                      영화 id
  @volume 1                   권 번호
  @title 지금 만나러 갑니다      한국어 제목
  @ja_title いま、会いにゆきます   일본어 제목
  @year 2004
  @description 소개 한 줄
  # 01 | 기적의 시작            강의 시작 (번호 | 제목)
  > 줄거리 문장
  k 일본어 | 한국어 [| 표준어]   키워드 (체크포인트는 세 번째 칸에 표준어)
  s 화자 | 일본어 | 한국어       대사 (화자가 비어 있으면 내레이션)
  r 표현 | 뜻 | 예문 | 예문 해석   오늘의 복습
  q 한국어 문제 | 일본어 정답       퀴즈
  i 그림이름                     그림(assets/illustrations/그림이름.webp). 강의 첫 i는 강의 대표 그림,
                                 대사 사이의 i는 다음 대사 앞에 나오는 장면 그림
'#!' 로 시작하는 줄과 빈 줄은 무시한다.

실행: python tool/screen/build_screen.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = ROOT / 'tool' / 'screen' / 'spec'
OUT = ROOT / 'assets' / 'screen' / 'screen_lessons.json'


def cells(text, n):
    parts = [p.strip() for p in text.split(' | ')]
    parts += [''] * (n - len(parts))
    return parts[:n] if n else parts


def parse(path):
    movie = {'lessons': []}
    lesson = None
    pending_img = ''
    for no, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.rstrip()
        if not line.strip() or line.startswith('#!'):
            continue
        tag, _, rest = line.partition(' ')
        rest = rest.strip()
        try:
            if tag.startswith('@'):
                key = tag[1:]
                movie[key] = int(rest) if key in ('volume', 'year') else rest
            elif tag == '#':
                num, title = cells(rest, 2)
                lesson = {'no': int(num), 'title': title, 'summary': '', 'scene': '',
                          'keywords': [], 'script': [], 'review': [], 'quiz': []}
                movie['lessons'].append(lesson)
            elif tag == '>':
                lesson['summary'] = (lesson['summary'] + ' ' + rest).strip()
            elif tag == 'k':
                ja, ko, plain = cells(rest, 3)
                item = {'ja': ja, 'ko': ko}
                if plain:
                    item['plain'] = plain
                lesson['keywords'].append(item)
            elif tag == 's':
                sp, ja, ko = cells(' ' + rest if rest.startswith('|') else rest, 3)
                item = {'sp': sp, 'ja': ja, 'ko': ko}
                if pending_img:
                    item['img'] = pending_img
                    pending_img = ''
                lesson['script'].append(item)
            elif tag == 'r':
                pattern, meaning, ja, ko = cells(rest, 4)
                lesson['review'].append(
                    {'pattern': pattern, 'meaning': meaning, 'ja': ja, 'ko': ko})
            elif tag == 'i':
                if not (ROOT / 'assets' / 'illustrations' / f'{rest}.webp').exists():
                    raise ValueError('그림 파일이 없음: ' + rest)
                if not lesson['scene'] and not lesson['script']:
                    lesson['scene'] = rest
                else:
                    pending_img = rest
            elif tag == 'q':
                ko, ja = cells(rest, 2)
                lesson['quiz'].append({'ko': ko, 'ja': ja})
            else:
                raise ValueError('알 수 없는 줄 종류: ' + tag)
        except Exception as error:  # noqa: BLE001
            sys.exit(f'{path.name}:{no}: {error}\n  {raw}')
    return movie


def main():
    movies = [parse(p) for p in sorted(SPEC.glob('*.txt'))]
    movies.sort(key=lambda m: m.get('volume', 0))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'movies': movies}, ensure_ascii=False,
                              separators=(',', ':')), encoding='utf-8')
    for m in movies:
        lessons = m['lessons']
        print(f"{m.get('title')}: {len(lessons)}강, 대사 "
              f"{sum(len(l['script']) for l in lessons)}줄, 퀴즈 "
              f"{sum(len(l['quiz']) for l in lessons)}문제")
    print('저장:', OUT.relative_to(ROOT))


if __name__ == '__main__':
    main()
