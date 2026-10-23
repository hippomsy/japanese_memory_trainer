# N4 단어장 데이터 생성 (2026-10-09)

「딱! 한권 JLPT 단어장 N4」(시사일본어사) MP3 DAY01~30으로 만든 30일 단어장(1,035단어)입니다.
녹음은 「일본어 단어 → 한국어 뜻」 순서이며, 단어마다 일본어 발음 구간(js)과 한국어 뜻 구간(ks)을 저장합니다.

- `asr/DNN.json`: 음성 구간(Silero VAD) 목록. spec의 구간 번호가 이 순서를 가리킵니다.
- `spec/dayNN.txt`: 사람이 정리한 단어 목록(형식은 `build_n4_wordbook.py` 맨 위 설명).
  단어·뜻은 ReazonSpeech·Whisper 인식 결과를 JLPT N4 어휘와 대조해 정했습니다. 인식이 어려운 몇 개 구간은 넣지 않았습니다.
- 예문은 앱의 JLPT 단어 데이터(`assets/data/jlpt_n*_part*.json`)에 표기·읽기가 같은 단어가 있을 때만 붙입니다(TTS로 읽음).

## 다시 만들기
```
python tool/n4_wordbook/build_n4_wordbook.py                          # JSON만
python tool/n4_wordbook/build_n4_wordbook.py --audio <DAY mp3 폴더>    # DAY별 오디오(모노 32kbps, 표지 그림 제거)까지
```

## 2026-10-10 추가: 한자 풀이 · 독해 · 간격 반복
- 한자 풀이: 단어의 한자마다 한국 훈음(예: 挨 밀칠 애)과 음독·훈독을 `assets/kanji/`(앱 한자 사전)에서 가져와 `k`에 넣습니다. 사전에 없는 5자(伺·喧·嘩·馳·髭)는 빌드 스크립트의 `KANJI_FIX`에 있습니다.
- 독해: `reading/reading_*.txt`에 DAY마다 지문(7~8문장)과 내용 확인 문제 2개가 있습니다.
  - `@day N | 제목 | 한국어 제목`, `S 일본어 | 한국어`, `Q 질문 | 한국어 | *정답 / 오답 / 오답 / 오답 | 해설`
  - 빌드 때 문장 속 DAY 단어(활용형 포함)를 찾아 토큰에 단어 id(`n`)를 붙이고, 앱에서는 초록 밑줄로 보여 줍니다.
- 간격 반복(암기 카드·오늘의 복습)은 앱의 FSRS 스케줄러(`lib/services/review_scheduler.dart`)를 그대로 씁니다.
