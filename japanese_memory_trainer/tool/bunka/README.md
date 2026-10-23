# 문화 독해 데이터 생성 (2026-10-05)

`bunka.zip`(Track_001~100)의 원어민 낭독으로 만든 「문화 독해」 40강 데이터입니다.

- 1~60번: PART 1 20강 × (문제 트랙 · 낭독 트랙 · 받아쓰기 트랙)
- 61~100번: PART 2 20강 × (문제 트랙 · 낭독 트랙)
- 앱에는 낭독 트랙 전체(`bunka_NN.mp3`)와 문제 트랙의 문제 부분(`bunka_NN_q.mp3`)만 넣었습니다(모노 48kbps). 받아쓰기 트랙은 낭독과 같은 녹음이라 뺐습니다.

## 파일
- `asr/Track_NNN.json`: 음성 구간(VAD)별 시작·끝 시각과 ReazonSpeech 인식 결과
- `spec/LNN.txt`: 다듬은 스크립트. 한 줄이 한 문장입니다.
  - `T 2 | 제목 | 한국어 제목` (숫자 = 낭독 트랙의 구간 번호)
  - `S 3-5 | 일본어 | 한국어` (구간 3~5가 이 문장, `S+`는 새 문단)
  - `Q 32-33 | 문제 | 한국어 | *정답 / 오답 / 오답 / 오답 | 해설` (문제 트랙의 구간 번호, 보기는 빌드 때 섞임)
- `build_bunka.py`: spec → `assets/reading/bunka_lessons.json`(후리가나·JLPT 단어 포함)

## 다시 만들기
```
pip install sudachipy sudachidict_core
python tool/bunka/build_bunka.py                       # JSON만
python tool/bunka/build_bunka.py <bunka 압축 푼 폴더> --audio   # 오디오까지 (ffmpeg 필요)
```
스크립트 문장을 고치려면 spec 파일을 수정하고 다시 빌드하면 됩니다. 문장의 구간 번호를 바꾸면 문장별 듣기 위치도 함께 바뀝니다.
