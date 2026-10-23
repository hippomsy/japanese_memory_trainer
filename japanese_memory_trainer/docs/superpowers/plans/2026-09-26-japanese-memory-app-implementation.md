# 일본어 장기기억 학습 앱 1차 버전 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter에서 `홈 → 오늘의 퀘스트 → 신규 5단어 → 복습 → 위험단어 → 통계`가 끝까지 동작하고, 앱 재실행 후에도 단어별 기억 상태와 다음 복습 일정이 유지되는 1차 버전을 만든다.

**Architecture:** 화면(UI), 기억 알고리즘, 로컬 저장소를 분리한다. 단어 원본은 앱 내 seed 데이터로 제공하고, 사용자별 기억 상태는 JSON 직렬화 후 로컬 저장소에 유지한다. 학습/복습 화면은 공통 퀴즈 세션 모델을 사용하며, `ReviewScheduler`와 `MemoryEvaluator`가 기억 단계와 위험 점수를 계산한다.

**Tech Stack:** Flutter / Dart, `shared_preferences`(로컬 상태 저장), `flutter_tts`(발음), Flutter `material` UI, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-26-japanese-memory-app-design.md`

## Global Constraints

- 모든 새 소스의 주요 클래스/함수 주석에는 `2026-09-26` 날짜를 붙인다.
- 1차 버전 신규 단어 기본 학습량은 하루 `5개`다.
- 기억 단계는 `0..7` 범위만 허용한다.
- 기본 복습 간격은 Stage 1=10분, 2=1일, 3=3일, 4=7일, 5=14일, 6=30일, 7=60일이다.
- 한국어→일본어 회상 성공은 일본어→한국어 인식 성공보다 높은 기억 점수를 준다.
- 5초 이상 걸린 정답은 `힘들게 기억`에 준하는 감점/위험 가중치를 적용한다.
- 앱 종료 후 `MemoryState`와 일별 학습 진행이 유지되어야 한다.
- 1차 버전에는 AI 회화, 계정, 클라우드 동기화, 광고, 결제를 넣지 않는다.
- UI 코드에서 복습 날짜 계산이나 위험 점수 계산을 직접 하지 않는다.
- 사용자에게 가장 크게 보여줄 통계는 `장기기억 단어 수`다.

## Review Focus

1. 저장된 `stage`가 -1 또는 99처럼 깨져 있어도 로드 시 0..7로 보정되고 앱이 시작되어야 한다. → Task 2 테스트에 포함.
2. `nextReviewAt`이 누락/파싱 실패한 레코드도 안전한 기본 복습일로 복구되어야 한다. → Task 2/3 테스트에 포함.
3. 오늘 학습할 seed 단어가 5개보다 적게 남았을 때 중복 없이 남은 단어만 제공되어야 한다. → Task 4 테스트에 포함.
4. 일본어→한국어는 맞지만 한국어→일본어를 반복 실패한 단어의 `dangerScore`가 올라가야 한다. → Task 3 테스트에 포함.
5. 로컬 저장 실패가 발생해도 화면 세션의 현재 답변/점수가 즉시 사라지지 않고 오류 메시지를 표시할 수 있어야 한다. → Task 5 테스트에 포함.

---

### Task 1: Flutter 앱 골격과 핵심 도메인 모델

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/models/vocabulary.dart`
- Create: `lib/models/memory_state.dart`
- Create: `lib/models/review_result.dart`
- Test: `test/models/memory_state_test.dart`

**Interfaces:**
- Produces: `Vocabulary`, `MemoryState`, `ReviewResult`, `QuizDirection`, `MemoryFeeling`.
- `MemoryState.copyWith(...) -> MemoryState`
- `MemoryState.toJson() -> Map<String, dynamic>`
- `MemoryState.fromJson(Map<String, dynamic>) -> MemoryState`
- `MemoryState.longTermReachedAt` is nullable and is set only on the first transition into Stage 6 or 7.

- [ ] **Step 1: Write failing model tests**

Test names/assertions:
- `MemoryState clamps stage below zero to 0`
- `MemoryState clamps stage above seven to 7`
- `MemoryState JSON round trip preserves counts, scores and longTermReachedAt`
- `ReviewResult records direction, correctness, responseMs and feeling`

- [ ] **Step 2: Run model tests and verify failure**

Run: `flutter test test/models/memory_state_test.dart`
Expected: FAIL because model classes do not exist.

- [ ] **Step 3: Implement domain models and app entry points**

Required signatures:

```dart
class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.japanese,
    required this.reading,
    required this.korean,
    required this.exampleJapanese,
    required this.exampleKorean,
    required this.jlptLevel,
    required this.wordType,
    required this.frequencyRank,
  });
}
```

```dart
class MemoryState {
  const MemoryState({ ... });
  MemoryState copyWith({ ... });
  Map<String, dynamic> toJson();
  factory MemoryState.fromJson(Map<String, dynamic> json);
}
```

```dart
enum QuizDirection { japaneseToKorean, koreanToJapanese, sentenceBlank, listening }
enum MemoryFeeling { didNotKnow, hardRecall, remembered, instantRecall }

class ReviewResult {
  const ReviewResult({
    required this.wordId,
    required this.direction,
    required this.isCorrect,
    required this.responseMs,
    required this.feeling,
    required this.reviewedAt,
  });
}
```

- [ ] **Step 4: Run model tests**

Run: `flutter test test/models/memory_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/main.dart lib/app.dart lib/models test/models
git commit -m "feat: add japanese memory app domain models"
```

---

### Task 2: Seed 단어와 로컬 저장소

**Files:**
- Create: `lib/data/seed_words.dart`
- Create: `lib/data/local_database.dart`
- Test: `test/data/local_database_test.dart`

**Interfaces:**
- Consumes: `Vocabulary`, `MemoryState` from Task 1.
- Produces: `seedWords`, `LocalDatabase`.
- `LocalDatabase.loadMemoryStates() -> Future<Map<String, MemoryState>>`
- `LocalDatabase.saveMemoryStates(Map<String, MemoryState>) -> Future<void>`
- `LocalDatabase.loadDailyLearnedWordIds(DateTime day) -> Future<Set<String>>`
- `LocalDatabase.saveDailyLearnedWordIds(DateTime day, Set<String> ids) -> Future<void>`
- `LocalDatabase.loadLearningDays() -> Future<Set<String>>` where each value is `YYYY-MM-DD`.
- `LocalDatabase.recordLearningDay(DateTime day) -> Future<void>`

- [ ] **Step 1: Write failing persistence tests**

Test names/assertions:
- `save and load memory states preserves values`
- `corrupted stage is clamped while loading`
- `invalid nextReviewAt falls back to a safe date`
- `daily learned ids survive reload`
- `recordLearningDay stores a date only once and supports streak reconstruction`

Use `SharedPreferences.setMockInitialValues({})`.

- [ ] **Step 2: Run persistence tests and verify failure**

Run: `flutter test test/data/local_database_test.dart`
Expected: FAIL because data layer does not exist.

- [ ] **Step 3: Add seed words and LocalDatabase**

`seed_words.dart` must start with at least 60 N4-oriented entries so a new user has more than one week of 5-word sessions. Each entry includes all `Vocabulary` fields. Include the earlier learning examples `到着`, `荷物`, `必要`, `覚える`, `忘れる`, `届く`, `届ける`, `増える`, `増やす`.

`LocalDatabase` stores JSON under fixed keys:
- `memory_states_v1`
- `daily_learned_ids_v1_YYYY-MM-DD`
- `learning_days_v1`

Safe-date rule for missing/broken `nextReviewAt`: `DateTime.now()` so the item becomes reviewable instead of disappearing permanently.

- [ ] **Step 4: Run persistence tests**

Run: `flutter test test/data/local_database_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data
git commit -m "feat: add seed vocabulary and local persistence"
```

---

### Task 3: 기억 평가와 복습 스케줄 엔진

**Files:**
- Create: `lib/services/review_scheduler.dart`
- Create: `lib/services/memory_evaluator.dart`
- Test: `test/services/review_scheduler_test.dart`
- Test: `test/services/memory_evaluator_test.dart`

**Interfaces:**
- Consumes: `MemoryState`, `ReviewResult`.
- Produces: `ReviewScheduler`, `MemoryEvaluator`.
- `ReviewScheduler.nextReviewAt({required int stage, required DateTime from}) -> DateTime`
- `ReviewScheduler.isDue(MemoryState state, DateTime now) -> bool`
- `MemoryEvaluator.applyResult(MemoryState current, ReviewResult result) -> MemoryState`

- [ ] **Step 1: Write failing scheduler tests**

Assertions for a fixed `from = DateTime(2026, 9, 26, 8, 0)`:
- Stage 1 → +10 minutes
- Stage 2 → +1 day
- Stage 3 → +3 days
- Stage 4 → +7 days
- Stage 5 → +14 days
- Stage 6 → +30 days
- Stage 7 → +60 days
- Out-of-range stages are clamped before calculation.

- [ ] **Step 2: Run scheduler test and verify failure**

Run: `flutter test test/services/review_scheduler_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `ReviewScheduler`**

Stage 0 has no future retention interval; after a successful first review it is evaluated into Stage 1 and scheduled from there.

- [ ] **Step 4: Write failing evaluator tests**

Test names/assertions:
- `correct instant recall increases stage`
- `wrong answer lowers stage and raises dangerScore`
- `correct answer taking more than 5000ms raises danger relative to fast answer`
- `koreanToJapanese correct recall improves recallScore more than japaneseToKorean improves it`
- `recognition success plus repeated recall failure raises dangerScore`
- `stage never leaves 0 through 7`

- [ ] **Step 5: Implement `MemoryEvaluator`**

Pinned rules for v1:
- Correct + instantRecall: stage +1.
- Correct + remembered: stage +1.
- Correct + hardRecall or `responseMs >= 5000`: keep stage if stage >= 1, otherwise move 0→1; add small danger weight.
- Wrong: stage -1, minimum 0; add stronger danger weight.
- Korean→Japanese correct: `recallScore +10`.
- Japanese→Korean correct: `recognitionScore +6`.
- Wrong Korean→Japanese: `recallScore -8` and danger +12.
- Wrong Japanese→Korean: `recognitionScore -5` and danger +8.
- Clamp recognition/recall scores to 0..100 and dangerScore to 0..100.
- `nextReviewAt` always comes from `ReviewScheduler` after updated stage is known.
- When a word first moves from Stage 0..5 into Stage 6 or 7, set `longTermReachedAt = result.reviewedAt`; do not overwrite it on later Stage 6/7 successes.
- Update `correctCount`, `wrongCount`, `consecutiveCorrect`, `lastReviewedAt` and rolling `averageResponseMs` on every result.

- [ ] **Step 6: Run service tests**

Run: `flutter test test/services`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/services test/services
git commit -m "feat: add spaced review and memory evaluation engine"
```

---

### Task 4: 오늘의 학습 선택과 퀴즈 생성

**Files:**
- Create: `lib/services/learning_repository.dart`
- Create: `lib/services/quiz_generator.dart`
- Create: `lib/models/quiz_question.dart`
- Test: `test/services/learning_repository_test.dart`
- Test: `test/services/quiz_generator_test.dart`

**Interfaces:**
- Consumes: `seedWords`, `MemoryState`, `LocalDatabase`.
- Produces: `LearningRepository`, `QuizQuestion`, `QuizGenerator`.
- `LearningRepository.getNewWordsForDay(DateTime day, {int limit = 5}) -> Future<List<Vocabulary>>`
- `LearningRepository.getDueWords(DateTime now) -> Future<List<Vocabulary>>`
- `LearningRepository.getDangerWords({int limit = 20}) -> Future<List<Vocabulary>>`
- `LearningRepository.getBossWords({int limit = 10}) -> Future<List<Vocabulary>>`
- `QuizGenerator.buildQuestion(Vocabulary word, QuizDirection direction) -> QuizQuestion`

- [ ] **Step 1: Write failing repository tests**

Assertions:
- New day returns at most 5 unseen words.
- Repeated call same day returns the same learned set without adding duplicates.
- Fewer than 5 unseen words returns only remaining words.
- Due words include only `nextReviewAt <= now`.
- Danger words are sorted descending by `dangerScore`.
- Boss words prefer dangerous words reviewed/failed recently.

- [ ] **Step 2: Run repository tests and verify failure**

Run: `flutter test test/services/learning_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `LearningRepository`**

Use constructor injection for seed list, database and clock-sensitive `now` inputs so tests stay deterministic.

- [ ] **Step 4: Write failing quiz generator tests**

Assertions:
- Japanese→Korean question hides the Korean answer until answered.
- Korean→Japanese question uses Korean as prompt and Japanese as answer.
- Sentence blank replaces the target word in `exampleJapanese` with `____` when present.
- Listening question carries Japanese text for TTS but does not render it as the visible prompt.

- [ ] **Step 5: Implement `QuizQuestion` and `QuizGenerator`**

Required `QuizQuestion` fields: `wordId`, `direction`, `prompt`, `correctAnswer`, `choices`, `ttsText`, `exampleJapanese`, `exampleKorean`.

- [ ] **Step 6: Run Task 4 tests**

Run: `flutter test test/services/learning_repository_test.dart test/services/quiz_generator_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/models/quiz_question.dart lib/services/learning_repository.dart lib/services/quiz_generator.dart test/services
git commit -m "feat: add daily learning selection and quiz generation"
```

---

### Task 5: 학습 세션 상태관리와 저장 실패 처리

**Files:**
- Create: `lib/services/learning_session_controller.dart`
- Create: `lib/models/learning_session_state.dart`
- Test: `test/services/learning_session_controller_test.dart`

**Interfaces:**
- Consumes: `LearningRepository`, `MemoryEvaluator`, `LocalDatabase`, `QuizGenerator`.
- Produces: `LearningSessionController`, `LearningSessionState`.
- `startTodayQuest(DateTime now) -> Future<void>`
- `submitAnswer({required String answer, required MemoryFeeling feeling, required int responseMs, required DateTime now}) -> Future<void>`
- `moveNext() -> void`
- Exposes current immutable `LearningSessionState state` and `String? persistenceError`.

- [ ] **Step 1: Write failing controller tests**

Assertions:
- Starting quest loads new words first and then due review words.
- Submitting an answer updates in-memory state before persistence completes.
- Persistence exception sets `persistenceError` but keeps the answered question/result in session state.
- Completing the last question marks session complete.

- [ ] **Step 2: Run controller tests and verify failure**

Run: `flutter test test/services/learning_session_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement session state and controller**

Do not put widget/navigation code in the controller. Persistence errors are surfaced as data so UI decides how to display a SnackBar/dialog.

- [ ] **Step 4: Run controller tests**

Run: `flutter test test/services/learning_session_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/learning_session_state.dart lib/services/learning_session_controller.dart test/services/learning_session_controller_test.dart
git commit -m "feat: add resilient learning session controller"
```

---

### Task 6: 공통 UI 컴포넌트와 홈 대시보드

**Files:**
- Create: `lib/widgets/word_card.dart`
- Create: `lib/widgets/memory_answer_buttons.dart`
- Create: `lib/widgets/progress_card.dart`
- Create: `lib/pages/home_page.dart`
- Create: `lib/services/statistics_service.dart`
- Test: `test/services/statistics_service_test.dart`
- Test: `test/pages/home_page_test.dart`

**Interfaces:**
- Consumes: repositories and memory states.
- Produces: `StatisticsService`, `HomePage`.
- `StatisticsService.buildSnapshot(DateTime now) -> Future<StatisticsSnapshot>`
- Snapshot fields: `streakDays`, `longTermWordCount`, `newLongTermThisWeek`, `dangerWordCount`, `dueReviewCount`, `todayNewWordCount`, `retentionRate`, `n4Progress`, `n3Progress`, `n2Progress`.

- [ ] **Step 1: Write failing statistics tests**

Pinned long-term definition for v1: `stage >= 6`.
Danger definition for dashboard count: `dangerScore >= 50`.
Retention rate: correct reviews / all reviews represented by accumulated correct/wrong counts, returning 0 when denominator is zero.
Streak: count consecutive calendar dates ending today if today has activity, otherwise ending yesterday.
`newLongTermThisWeek`: words currently at Stage 6 or 7 whose `longTermReachedAt` is within the current Monday-Sunday week.

- [ ] **Step 2: Implement `StatisticsService` and snapshot model**

- [ ] **Step 3: Write failing HomePage widget test**

Assert visible text includes:
- `장기기억 단어`
- `위험 단어`
- `오늘 복습`
- `오늘의 퀘스트 시작`
- `연속 학습`
- `N4`, `N3`, `N2`

- [ ] **Step 4: Implement reusable cards and HomePage**

The largest/highest-priority metric card is `장기기억 단어`. Home page routes are injected as callbacks for widget-test isolation.

- [ ] **Step 5: Run Task 6 tests**

Run: `flutter test test/services/statistics_service_test.dart test/pages/home_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets lib/pages/home_page.dart lib/services/statistics_service.dart test/services/statistics_service_test.dart test/pages/home_page_test.dart
git commit -m "feat: add japanese memory dashboard"
```

---

### Task 7: 신규 학습/복습 화면과 TTS

**Files:**
- Create: `lib/services/tts_service.dart`
- Create: `lib/pages/learn_page.dart`
- Create: `lib/pages/review_page.dart`
- Test: `test/pages/learn_page_test.dart`
- Test: `test/pages/review_page_test.dart`

**Interfaces:**
- Consumes: `LearningSessionController`, `QuizQuestion`.
- Produces: `TtsService`, `LearnPage`, `ReviewPage`.
- `TtsService.speakJapanese(String text) -> Future<void>`

- [ ] **Step 1: Write failing LearnPage test**

Assert initial study card can show Japanese, reading, Korean meaning, Japanese example, Korean example and `다음` button. Assert speaker callback receives the Japanese word.

- [ ] **Step 2: Implement `TtsService` and LearnPage**

Set Japanese locale to `ja-JP` when supported. TTS failure must not terminate the learning session.

- [ ] **Step 3: Write failing ReviewPage tests**

Assertions:
- Answer is hidden before submission.
- Four memory feeling buttons exist: `몰랐음`, `힘들게 기억`, `기억함`, `바로 기억`.
- Wrong answer renders correction feedback.
- Persistence error from controller renders a user-visible warning while allowing `다음`.

- [ ] **Step 4: Implement ReviewPage**

Measure response time from question presentation to answer submission. Pass elapsed milliseconds to controller; do not calculate memory scores in widget code.

- [ ] **Step 5: Run Task 7 tests**

Run: `flutter test test/pages/learn_page_test.dart test/pages/review_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/tts_service.dart lib/pages/learn_page.dart lib/pages/review_page.dart test/pages
git commit -m "feat: add study and spaced review screens"
```

---

### Task 8: 위험 단어, 보스전, 통계 화면

**Files:**
- Create: `lib/pages/danger_words_page.dart`
- Create: `lib/pages/boss_page.dart`
- Create: `lib/pages/statistics_page.dart`
- Test: `test/pages/danger_words_page_test.dart`
- Test: `test/pages/boss_page_test.dart`
- Test: `test/pages/statistics_page_test.dart`

**Interfaces:**
- Consumes: `LearningRepository`, `StatisticsService`, quiz/session services.
- Produces: three navigable pages.

- [ ] **Step 1: Write failing DangerWordsPage test**

Assert words are shown in descending danger order and each row shows danger score plus wrong count.

- [ ] **Step 2: Implement DangerWordsPage**

Empty state text: `현재 위험 단어가 없습니다.`

- [ ] **Step 3: Write failing BossPage test**

Assert up to 10 boss words are loaded from repository and completion screen reports conquered/needs-practice counts.

- [ ] **Step 4: Implement BossPage**

Reuse existing quiz generation/evaluation code; do not implement a second memory algorithm.

- [ ] **Step 5: Write failing StatisticsPage test**

Assert page shows `장기기억 단어`, `이번 주 새로 정착`, `기억률`, `위험 단어`, and N4/N3/N2 progress.

- [ ] **Step 6: Implement StatisticsPage**

- [ ] **Step 7: Run Task 8 tests**

Run: `flutter test test/pages/danger_words_page_test.dart test/pages/boss_page_test.dart test/pages/statistics_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/pages/danger_words_page.dart lib/pages/boss_page.dart lib/pages/statistics_page.dart test/pages
git commit -m "feat: add danger words boss battle and statistics"
```

---

### Task 9: 앱 조립, 네비게이션, 재실행 통합 검증

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Create: `test/app_flow_test.dart`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: runnable `KiokuJapaneseApp`.

- [ ] **Step 1: Write failing end-to-end widget test**

Using mock preferences and deterministic seed data, verify:
1. App opens on HomePage.
2. Tap `오늘의 퀘스트 시작`.
3. Complete a 5-word new-learning set.
4. Submit review result.
5. Return home and open danger words/statistics.
6. Recreate repository/app with the same mock persisted values.
7. Previously updated `MemoryState.stage` and `nextReviewAt` remain loaded.

- [ ] **Step 2: Run flow test and verify failure**

Run: `flutter test test/app_flow_test.dart`
Expected: FAIL until app wiring/navigation is complete.

- [ ] **Step 3: Wire app dependencies and named routes**

Required routes:
- `/` → HomePage
- `/learn` → LearnPage
- `/review` → ReviewPage
- `/danger` → DangerWordsPage
- `/boss` → BossPage
- `/statistics` → StatisticsPage

Construct repository/services once at app composition root and inject them downward. Avoid service creation inside individual page build methods.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 5: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Build Android debug APK**

Run: `flutter build apk --debug`
Expected: successful build and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat: complete japanese long-term memory learning MVP"
```

---

## Final Acceptance Checklist

- [ ] 앱 첫 실행에서 N4 중심 seed 단어를 읽을 수 있다.
- [ ] 신규 단어가 하루 최대 5개만 선택된다.
- [ ] 일본어→한국어, 한국어→일본어, 문장 빈칸, 듣기형 구조가 존재한다.
- [ ] 정답/오답/반응시간/기억감각이 평가 엔진에 전달된다.
- [ ] 기억 단계가 0..7을 벗어나지 않는다.
- [ ] Stage별 다음 복습 날짜가 요구사항과 일치한다.
- [ ] 위험 단어가 오답/느린 회상/회상 실패에 따라 우선된다.
- [ ] 장기기억 단어 수가 홈과 통계에서 핵심 지표로 보인다.
- [ ] 앱 재실행 후 기억 단계와 복습 일정이 유지된다.
- [ ] 저장 실패가 세션 자체를 즉시 잃게 만들지 않는다.
- [ ] 모든 주요 새 클래스/함수 주석에 `2026-09-26` 날짜가 있다.
- [ ] `flutter test`, `flutter analyze`, `flutter build apk --debug`가 성공한다.
