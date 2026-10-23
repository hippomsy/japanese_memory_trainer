# 기억 일본어 · 쉬운 뉴스 피드

2026-10-04부터 배포 앱은 구글 시트나 이 폴더의 피드 대신 NHK Easier RSS를 직접 읽고 기기에서 번역합니다.
`lib/config.dart`의 `newsFeedUrl`은 RSS 주소입니다. 아래 절차는 이전에 사용하던 기사 원고 제작 방식이며 현재 자동 실행 작업이 아닙니다.
창작 일기는 `assets/news/haru_diary.json`에 30편이 포함되어 있으며, `build_diary.py`로 후리가나를 붙입니다.

## 이전 피드의 원고 제작 순서 (참고)
1. 오늘의 일본 뉴스 1~2건을 조사한다(사실만 사용, 원문 문장은 복사하지 않음).
2. N4 수준의 쉬운 일본어로 새로 쓰고 문단마다 한국어 번역을 단 원고를 `specs/YYYY-MM-DD-N.json`으로 저장한다.
3. `pip install sudachipy sudachidict_core` 후
   `python3 news_build.py specs/YYYY-MM-DD-1.json specs/YYYY-MM-DD-2.json --feed news.json --keep 30`
4. `news.json`, `specs/`를 커밋하고 push 한다.

원고 형식은 `news_build.py` 맨 위 주석을 참고하세요. 단어 급수와 뜻은 `data/words_index.json`(앱 단어장)에서 가져옵니다.
