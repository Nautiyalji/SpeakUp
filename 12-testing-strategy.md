# 12 - Testing Strategy

## 1. Unit Testing
- **Backend:** Use `Pytest` for scoring algorithms and utility functions.
- **Frontend:** Use `flutter_test` for profile model serialization and provider logic.

## 2. Integration Testing
- **API Tests:** Use `Httpx` or `Requests` to verify FastAPI endpoints (Auth, Session Turn).
- **DB Tests:** Verify Supabase RLS policies via SQL testing or restricted SDK calls.

## 3. End-to-End (E2E) Testing
- **Voice Loop:** Manual verification of:
  - Audio Record -> Transcription accuracy.
  - Scores generated -> UI update consistency.
  - AI Voice playback -> Audio quality and response time.
- **Cross-device Sync:** Login on Web and Android simultaneously to verify streak/history sync.

## 4. Performance & UX Testing
- **Latency Check:** Measure turn response time (Target: < 15s).
- **Cold Start Impact:** Measure impact of server wake-up on UX.
- **Accessibility:** Verify contrast ratios for Dark/Light modes.

## 5. Beta Testing
- **Solo Testing:** Internal developer dogfooding for 1 week.
- **Study Group:** 3-5 students testing the MVP for feedback on "Beginner Mode" simplicity.

## 6. Definition of Done (DoD)
- Feature works end-to-end.
- Code passed static analysis (Lints).
- Data persisted correctly in Supabase.
- No unhandled exceptions in logs.
- Dark/Light mode verified.
