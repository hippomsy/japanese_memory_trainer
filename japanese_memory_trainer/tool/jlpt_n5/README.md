# JLPT N5 청해 데이터 생성 (2026-10-08)

「JLPT 완전정복 한 권으로 N5」 MP3(TRACK 01~10)로 만든 청해 96문제입니다.

| 트랙 | 내용 |
|---|---|
| TRACK 01~04 | 第1回 問題1~4 |
| TRACK 05~08 | 第2回 問題1~4 |
| TRACK 09 | 模擬テスト1 (問題1~4, 例 제외) |
| TRACK 10 | 模擬テスト2 (問題1~4, 例 제외) |

- `asr/TNN.json`: 음성 구간(VAD)과 ReazonSpeech 인식 결과. Whisper(turbo)로 교차 확인했습니다.
- `spec/tNN.txt`: 사람이 다듬은 스크립트·문제·보기·해설(형식은 `build_jlpt_n5.py` 맨 위 설명).
- 問題1·2는 문제지 그림이 압축 파일에 없어서, 대화에 맞춰 그림문자(이모지) 보기를 새로 만들었습니다. 정답 위치는 빌드 때 섞입니다(숫자 보기는 순서 유지).
- 問題3·4 보기는 녹음에 나오는 실제 보기이며, 앱에서는 답하기 전까지 내용을 가립니다.
- `NOTE`가 붙은 문제는 그림 없이 음성만으로 정답을 고른 문제입니다.

## 다시 만들기
```
pip install sudachipy sudachidict_core
python tool/jlpt_n5/build_jlpt_n5.py                          # JSON만
python tool/jlpt_n5/build_jlpt_n5.py --audio <TRACK mp3 폴더>   # 문제별 오디오까지(ffmpeg, 모노 40kbps)
```
