Japanese Memory Trainer - 미리보기 스타일 패치
기준일: 2026-09-26

적용 내용
1. 신규 단어 학습 화면에 단어별 로컬 이미지 표시
2. N4 seed 60개 모두 이미지 포함
3. 일본어→한국어 4지선다
4. 한국어→일본어 4지선다
5. 문장 빈칸 4지선다
6. 듣고 맞히기 4지선다
7. 신규 단어 하나당 위 4가지 퀴즈가 모두 출제됨
8. 정답 선택 시 초록색, 오답 선택 시 빨간색 표시
9. 미리보기처럼 분홍색 진행률/버튼/카드 스타일 적용
10. 직접 입력 TextField 제거

적용 방법
- 이 ZIP의 내용을 japanese_memory_trainer 프로젝트 루트에 그대로 덮어쓰기 합니다.
- android, ios 등 기존 플랫폼 폴더는 삭제하지 마세요.

적용 후 권장 명령
flutter clean
flutter pub get
flutter build apk --release

APK 위치
build\app\outputs\flutter-apk\app-release.apk

주의
- 이 패치는 ChatGPT가 앞서 생성한 Kioku Japanese 소스 구조를 기준으로 작성했습니다.
- 현재 실행 환경에는 Flutter SDK가 없어 실제 flutter analyze / flutter test / APK 빌드는 여기서 실행하지 못했습니다.
- 소스 구조 검사, pubspec YAML 검사, 60개 이미지 존재 여부는 확인했습니다.
