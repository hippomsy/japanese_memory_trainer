# JLPT N4 모의고사 (언어지식·독해) 2회분

- `spec/mock1.txt`, `spec/mock2.txt` : 문제 원본(형식은 build_jlpt_n4_mock.py 맨 위 설명 참고)
- `python tool/jlpt_n4_mock/build_jlpt_n4_mock.py` → `assets/jlpt_n4_mock/mock.json`
  - 問題별 문항 수(문자·어휘 7/5/8/4/4, 문법·독해 13/4/4/3/3/2)와 정답 1개·보기 4개 중복 없음을 검사
  - 보기 순서는 고정 난수로 섞음(다시 빌드해도 같은 순서)
- `spec/mockN_ko.txt` : 연습 모드 해석(정답 문장 해석, 보기 뜻, 지문 해석). 빌드 때 정답 문장·보기·지문에 후리가나·단어 뜻 조각을 붙임(sudachipy, news_feed/news_build.py 필요)
