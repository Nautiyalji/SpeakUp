# SpeakUp — MVP Technical Document
**Version:** 1.0  
**MVP Scope:** Core voice session + basic scoring + cross-device auth  
**Target Build Time:** 8–10 weeks (solo student, 3-5 hrs/day)

---

## 1. What the MVP Is

The MVP (Minimum Viable Product) for SpeakUp is the smallest working version of the app that delivers real, tangible value. It is NOT a demo. It is NOT a prototype. It is a fully functional, deployable application that a user can actually use daily.

**MVP Core Loop:**
```
User opens app → Logs in → Starts daily session →
Speaks to AI coach → Gets scored + coached → Session saved →
Views progress dashboard → Next day, repeat
```

**MVP does NOT include:**
- Interview simulation (Phase 2)
- Learning Hub (Phase 3)
- PDF report downloads (Phase 4)
- Vocabulary builder quizzes
- Annual reports
- Streak badges and achievements

These are all post-MVP features that can be added incrementally.

---

## 2. MVP Feature Scope

### ✅ INCLUDED IN MVP

| Feature | Description |
|---|---|
| User Registration | Email + password signup via Supabase Auth |
| User Login | Email + password login. JWT persisted across sessions |
| Profile Setup | Name, target accent (Indian/British), current level (beginner/intermediate/advanced) |
| Cross-device Auth | Same account logs in on mobile and PC. Same data visible on both |
| Start Daily Session | User taps button, session begins. AI coach greets the user |
| Voice Recording | User speaks for up to 60 seconds per turn |
| Speech-to-Text | Whisper transcribes the audio in near-real-time |
| AI Coaching Response | Gemini generates a coaching response (text + exercise + tip) |
| AI Voice Playback | Coqui TTS converts AI text to speech. User hears the coach |
| Grammar Analysis | language_tool_python analyses transcript → grammar score |
| Vocabulary Analysis | NLTK analyses transcript → vocabulary richness score |
| Confidence Score | Filler words + pauses + speaking rate → confidence score |
| Basic Fluency Score | Words per minute + sentence completion rate |
| Session End | User ends session. Overall score calculated and saved |
| Post-Session Feedback | Simple text feedback screen showing strengths and 2 improvement tips |
| Progress Dashboard | Shows last 7 days of session scores as a line chart |
| Session History | List of past sessions with date and overall score |
| Accent Selection | User picks Indian English or British English. AI adjusts coaching accordingly |
| Beginner Mode | Simplified AI language when level = beginner |
| Dark/Light Mode | System-default theme switching |
| Offline Fallback | If internet down, show cached exercises from last session |

### ❌ NOT IN MVP (Future Phases)

| Feature | Phase |
|---|---|
| Accent phoneme scoring (SpeechBrain) | Phase 2 |
| Interview simulation | Phase 2 |
| Weekly/Monthly PDF reports | Phase 3 |
| Learning Hub | Phase 3 |
| Vocabulary builder + quizzes | Phase 3 |
| Multi-panelist interview | Phase 2 |
| Document upload + RAG | Phase 2 |
| Achievement badges | Phase 4 |
| Annual report | Phase 4 |
| Notification reminders | Phase 3 |

---

## 3. MVP Technical Stack

Use only what is strictly needed. Do not install libraries you will not use in the MVP.

### Backend (Python + FastAPI)

```
fastapi==0.111.0
uvicorn[standard]==0.30.0
python-dotenv==1.0.1
supabase==2.4.0
google-generativeai==0.7.2        # Gemini API
groq==0.9.0                       # Fallback LLM
openai-whisper==20231117          # Local STT
TTS==0.22.0                       # Coqui TTS (local)
librosa==0.10.2                   # Audio feature extraction
language-tool-python==2.7.1       # Grammar check
nltk==3.8.1                       # Vocabulary analysis
httpx==0.27.0
python-multipart==0.0.9
pydantic==2.7.1
ffmpeg-python==0.2.0
```

**NOT needed for MVP (install later):**
```
speechbrain       ← only needed for accent scoring (Phase 2)
sentence-transformers ← only needed for RAG (Phase 2)
chromadb          ← only needed for RAG (Phase 2)
spacy             ← optional, NLTK sufficient for MVP
reportlab         ← PDF reports (Phase 3)
matplotlib        ← charts in PDF (Phase 3)
```

### Frontend (Flutter)

```yaml
# pubspec.yaml MVP dependencies only
dependencies:
  flutter_riverpod: ^2.5.1
  dio: ^5.4.3
  supabase_flutter: ^2.5.0
  flutter_sound: ^9.2.13          # Audio recording
  just_audio: ^0.9.38             # Audio playback
  fl_chart: ^0.68.0               # Progress line chart
  go_router: ^14.0.2
  google_fonts: ^6.2.1
  shared_preferences: ^2.2.3
  permission_handler: ^11.3.1
  connectivity_plus: ^6.0.3       # Offline detection
  intl: ^0.19.0
```

**NOT needed for MVP:**
```yaml
  file_picker       # only needed for document upload (Phase 2)
  lottie            # nice animations (add later)
  path_provider     # only needed for PDF download (Phase 3)
```

---

## 4. MVP Database Schema

Run this in your Supabase SQL editor. This is the MVP-only schema — no interview tables yet.

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── PROFILES ────────────────────────────────────────────────────────────────
CREATE TABLE profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name     TEXT NOT NULL,
  target_accent TEXT NOT NULL DEFAULT 'Indian English'
                  CHECK (target_accent IN ('Indian English', 'British English')),
  current_level TEXT NOT NULL DEFAULT 'beginner'
                  CHECK (current_level IN ('beginner', 'intermediate', 'advanced')),
  daily_streak  INTEGER DEFAULT 0,
  total_sessions INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile row when user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- ─── COMMUNICATION SESSIONS ───────────────────────────────────────────────────
CREATE TABLE communication_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  target_accent    TEXT NOT NULL,
  level_at_session TEXT NOT NULL,
  started_at       TIMESTAMPTZ DEFAULT now(),
  ended_at         TIMESTAMPTZ,
  duration_seconds INTEGER,
  grammar_score    NUMERIC(5,2),
  vocabulary_score NUMERIC(5,2),
  confidence_score NUMERIC(5,2),
  fluency_score    NUMERIC(5,2),
  overall_score    NUMERIC(5,2),
  transcript       TEXT,
  ai_feedback      JSONB,
  turns_count      INTEGER DEFAULT 0
);

-- Index for fast user history queries
CREATE INDEX idx_sessions_user_date
  ON communication_sessions(user_id, started_at DESC);

-- ─── PROGRESS SNAPSHOTS ───────────────────────────────────────────────────────
CREATE TABLE progress_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  avg_grammar     NUMERIC(5,2),
  avg_vocabulary  NUMERIC(5,2),
  avg_confidence  NUMERIC(5,2),
  avg_fluency     NUMERIC(5,2),
  avg_overall     NUMERIC(5,2),
  sessions_count  INTEGER DEFAULT 1,
  UNIQUE(user_id, snapshot_date)
);

-- ─── ROW LEVEL SECURITY ───────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: users own their row"
  ON profiles FOR ALL USING (auth.uid() = id);

CREATE POLICY "sessions: users own their sessions"
  ON communication_sessions FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "snapshots: users own their snapshots"
  ON progress_snapshots FOR ALL USING (auth.uid() = user_id);
```

---

## 5. MVP API Specification

Base URL: `https://your-app.onrender.com` (or `http://localhost:8000` during dev)

All requests require header: `Authorization: Bearer <supabase_jwt>`

### 5.1 Auth Endpoints

```
POST /auth/profile
  Body:    {"user_id": "uuid", "full_name": "string", "target_accent": "string", "level": "string"}
  Returns: {"success": true, "profile": {...}}
  Action:  Upsert profile row in Supabase

GET /auth/profile/{user_id}
  Returns: {"id": "uuid", "full_name": "...", "target_accent": "...", "current_level": "...", "daily_streak": 0, "total_sessions": 0}
```

### 5.2 Session Endpoints

```
POST /sessions/start
  Body:    {"user_id": "uuid", "target_accent": "Indian English", "level": "beginner"}
  Returns: {"session_id": "uuid", "greeting": "text", "greeting_audio": "base64_wav", "first_exercise": "text"}
  Action:  Create session row. Generate greeting via Gemini. Synthesize greeting with Coqui.

POST /sessions/turn
  Body:    {
             "session_id": "uuid",
             "user_id": "uuid",
             "audio_base64": "base64_encoded_wav_string",
             "turn_number": 1
           }
  Returns: {
             "transcript": "what the user said",
             "grammar_score": 75.0,
             "vocabulary_score": 60.0,
             "confidence_score": 65.0,
             "fluency_score": 70.0,
             "grammar_errors": [{"message": "...", "bad_text": "...", "suggestion": "..."}],
             "wpm": 132,
             "filler_count": 3,
             "ai_response": {
               "response_text": "Great effort! Let me...",
               "praise": "You spoke clearly!",
               "tip": "Try to avoid saying 'um' — take a breath instead.",
               "exercise": "Now tell me about your favourite food in 3 sentences."
             },
             "ai_audio_base64": "base64_encoded_wav_string"
           }
  Action:  Full pipeline: decode audio → Whisper → Analysis → Grammar → Gemini → Coqui → return

POST /sessions/end
  Body:    {"session_id": "uuid", "user_id": "uuid"}
  Returns: {
             "final_scores": {
               "grammar": 75.0,
               "vocabulary": 60.0,
               "confidence": 65.0,
               "fluency": 70.0,
               "overall": 67.5
             },
             "feedback": {
               "headline": "A good first session! You showed real effort.",
               "strengths": ["You spoke without long pauses", "Your vocabulary is growing"],
               "improvements": ["Reduce filler words like 'um'", "Try longer sentences"],
               "daily_exercises": [
                 "Record yourself saying 5 sentences about your day",
                 "Read one paragraph aloud from any book",
                 "Practice saying 'Hello, my name is [name] and I am a student' 10 times"
               ],
               "motivational_message": "Every session makes you better. See you tomorrow!",
               "next_session_focus": "Filler word reduction"
             }
           }
  Action:  Calculate aggregated scores. Generate feedback via Gemini. Update session row. Upsert progress_snapshots. Update user streak.
```

### 5.3 Progress Endpoints

```
GET /progress/{user_id}?days=7
  Returns: [
             {"date": "2026-02-17", "avg_grammar": 70.0, "avg_vocabulary": 55.0, "avg_confidence": 60.0, "avg_fluency": 65.0, "avg_overall": 62.5},
             ...
           ]
  Action:  Query progress_snapshots for last N days. Return array ordered by date ASC.

GET /progress/history/{user_id}?limit=10
  Returns: [
             {"id": "uuid", "started_at": "ISO date", "overall_score": 67.5, "duration_seconds": 840, "turns_count": 7},
             ...
           ]
  Action:  Return last N sessions (basic info only, for history list)
```

---

## 6. MVP Implementation — Step-by-Step

### Week 1: Environment + Database
```bash
# Day 1
- Create Supabase project at supabase.com (free)
- Run schema.sql in Supabase SQL editor
- Enable email auth in Supabase dashboard
- Create .env file with Supabase URL + anon key + service key

# Day 2
- Set up Python 3.11 virtual environment
- pip install fastapi uvicorn python-dotenv supabase pydantic
- Create main.py with /health endpoint
- Test: curl http://localhost:8000/health

# Day 3-4
- Implement auth.py router (profile create/get)
- Test profile creation with Supabase

# Day 5-7
- Set up Flutter project (flutter create speakup)
- Add MVP dependencies to pubspec.yaml
- Connect to Supabase (supabase_flutter)
- Build Login + Signup screens
- Test auth end-to-end on emulator
```

### Week 2-3: Voice Pipeline
```bash
# Day 8-10
- pip install openai-whisper
- Create whisper_service.py
- Test: load model, transcribe a sample WAV file
- Note: First run downloads model (~75MB for 'base')

# Day 11-13
- pip install TTS
- Create tts_service.py
- Test: synthesize "Hello, welcome to SpeakUp" → play WAV
- Note: First run downloads model (~100MB)

# Day 14-16
- Build /sessions/start endpoint
- Integrate Whisper + Coqui
- Test with curl sending a base64 WAV
- Build voice_recorder_widget.dart in Flutter
- Build audio_service.dart (record → base64 → send)

# Day 17-21
- Build /sessions/turn endpoint (full pipeline)
- Integrate language_tool_python for grammar
- Integrate NLTK for vocabulary
- Build analysis_service.py (speaking rate + filler words + pauses)
- Test the entire turn: record audio → transcribe → analyse → return scores
```

### Week 4-5: AI Coaching
```bash
# Day 22-24
- Get Gemini API key from aistudio.google.com (free)
- Get Groq API key from console.groq.com (free)
- Implement llm_service.py with fallback
- Test: generate coaching response from sample transcript

# Day 25-28
- Write all prompt templates in prompts.py
- Integrate LLM into /sessions/turn
- Implement /sessions/end with feedback generation
- Build session state machine in Riverpod (Flutter)

# Day 29-35
- Build DailySessionScreen Flutter UI
  - Recording button with pulse animation
  - Transcript display (updates as user speaks)
  - AI response text display
  - Score badges (grammar/vocab/confidence/fluency)
  - Audio playback of AI response
- Test full session flow on emulator
```

### Week 6-7: Dashboard + Progress
```bash
# Day 36-38
- Build progress_service (aggregate scores, update snapshots)
- Build /progress/{user_id} endpoint
- Build /progress/history/{user_id} endpoint

# Day 39-42
- Build HomeScreen (dashboard)
  - Greeting + streak display
  - 4 score circles (last session)
  - "Start Session" button
- Build ProgressScreen
  - fl_chart line chart (7 days)
  - Session history list

# Day 43-45
- Build ProfileScreen (name, accent, level settings)
- Wire up settings to update Supabase profile
- Test accent switching (Indian → British in a new session)
```

### Week 8: Polish + Deploy
```bash
# Day 46-48
- Implement offline fallback (cache last exercises in SharedPreferences)
- Implement ConnectivityPlus to detect offline state
- Add loading states to all async operations
- Add error SnackBars to all API calls

# Day 49-51
- Dark/Light mode (system default)
- Beginner mode adjustments in prompts
- UI polish pass (spacing, fonts, colours)

# Day 52-56
- Deploy FastAPI to Render.com (free)
  - Connect GitHub repo
  - Add env vars in Render dashboard
  - Test production endpoints
- Build Flutter web: flutter build web
- Deploy web to Vercel (drag + drop build/web folder)
- Build Android APK: flutter build apk --release
- Test APK on physical Android device
- Test web version in browser
- Test cross-device: log in on web + Android, verify same data
```

---

## 7. MVP Performance Targets

| Metric | Target | Notes |
|---|---|---|
| Session start time | < 5 seconds | Including greeting generation + TTS |
| Turn response time | < 12 seconds | Whisper (5s) + Analysis (2s) + Gemini (3s) + TTS (2s) |
| Grammar check time | < 2 seconds | language_tool_python is fast |
| App startup time | < 3 seconds | Flutter native, Supabase auth check |
| Progress chart load | < 2 seconds | Simple DB query, few rows |
| Audio quality | 16kHz, mono WAV | Whisper optimal input format |
| Offline detection | < 1 second | ConnectivityPlus stream |

---

## 8. MVP Testing Checklist

Before calling the MVP complete, verify every item below:

**Authentication:**
- [ ] New user can register with email + password
- [ ] Registered user can log in
- [ ] Logged-in user stays logged in after closing and reopening the app
- [ ] Same account shows same session history on web and mobile

**Voice Session:**
- [ ] Session starts and plays greeting audio
- [ ] Microphone records correctly (request permission on first use)
- [ ] Audio uploads to backend successfully
- [ ] Transcript appears on screen after turn
- [ ] All 4 scores update after each turn
- [ ] AI text response displays correctly
- [ ] AI audio plays back automatically
- [ ] Session can be ended at any time
- [ ] Post-session feedback screen shows correctly
- [ ] Session saved to Supabase (verify in Supabase dashboard)

**Accent + Level:**
- [ ] Changing accent in Profile updates next session's coaching language
- [ ] Beginner mode produces simpler AI responses (verify manually)

**Progress:**
- [ ] Dashboard shows last session scores
- [ ] Progress chart shows 7-day line graph correctly
- [ ] Session history list shows past sessions

**Offline:**
- [ ] Turn off internet during session — app shows "Offline Mode" message
- [ ] App still shows cached exercises when offline
- [ ] After reconnecting, session data syncs

**Cross-Device:**
- [ ] Log in on Android — do a session — log in on PC browser — session history visible

---

## 9. Known MVP Limitations

These are acceptable limitations for the MVP. Document them, do not fix them in MVP phase.

| Limitation | Impact | Fix in Phase |
|---|---|---|
| Whisper 'base' model: ~80% accuracy on heavy accents | Transcripts may have errors | 2 — try 'small' model |
| Coqui TTS: slight robotic quality | AI voice sounds slightly artificial | 2 — try XTTS-v2 model |
| No accent SCORING (only coaching for target accent) | Users don't see accent score yet | 2 — add SpeechBrain |
| Turn response time ~10-12 seconds | Feels slow on first few turns | 2 — parallelise pipeline |
| Render.com free tier: 50-second cold start | First API call after inactivity is slow | Post-MVP — ping the server periodically |
| TTS model cold start: ~8 seconds first synthesis | First AI voice response in a session is slow | 2 — pre-warm on session start |
| No push notifications | User may forget to practice | 3 — add local notifications |

---

*MVP Technical Document — SpeakUp v1.0*
