# SpeakUp — Architecture Document
**Version:** 1.0  
**App Name:** SpeakUp — AI Communication Coach & Interview Trainer  
**Last Updated:** February 2026

---

## 1. Architecture Overview

SpeakUp follows a **three-tier client-server architecture** with a clear separation between the presentation layer (Flutter), business logic layer (FastAPI/Python), and data layer (Supabase/PostgreSQL). The design prioritises offline capability, real-time cross-device sync, and modular service isolation.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER (Flutter)                        │
│   Android │ iOS │ Web (Chrome/Firefox) │ Windows Desktop             │
│   ─────────────────────────────────────────────────────────          │
│   Screens │ Providers (Riverpod) │ Widgets │ Local Audio Engine       │
│   flutter_sound (record) │ just_audio (playback) │ fl_chart           │
└───────────────────────┬─────────────────────────────────────────────┘
                        │ HTTPS REST + Base64 Audio
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER (FastAPI)                      │
│   Hosted: Render.com (Free Tier)                                     │
│   ─────────────────────────────────────────────────────────          │
│   Routers: /sessions │ /interview │ /reports │ /uploads              │
│                                                                       │
│   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│   │WhisperService│ │  LLM Service │ │  TTS Service  │               │
│   │(local STT)   │ │Gemini+Groq   │ │  Coqui TTS   │               │
│   └──────────────┘ └──────────────┘ └──────────────┘                │
│   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│   │AnalysisService│ │GrammarService│ │  RAG Service  │              │
│   │Librosa+Speech │ │lang_tool_py  │ │Sent-Transform │              │
│   │Brain          │ │              │ │+ChromaDB      │              │
│   └──────────────┘ └──────────────┘ └──────────────┘                │
└───────────────────────┬─────────────────────────────────────────────┘
                        │ Supabase SDK + HTTP
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       DATA LAYER (Supabase)                          │
│   Cloud: Supabase Free Tier (US-East region)                         │
│   ─────────────────────────────────────────────────────────          │
│   PostgreSQL DB │ Auth (JWT) │ Storage │ Realtime Subscriptions       │
│                                                                       │
│   Tables: profiles │ communication_sessions │ interview_setups         │
│           interview_sessions │ vocabulary_log │ progress_snapshots    │
│           uploaded_documents                                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Architecture

### 2.1 Frontend Architecture (Flutter)

```
lib/
├── core/                          # App-wide infrastructure
│   ├── theme.dart                 # Material3 theming (dark + light)
│   ├── router.dart                # GoRouter declarative navigation
│   ├── constants.dart             # Colors, strings, endpoint URLs
│   └── supabase_config.dart       # Supabase client singleton
│
├── providers/                     # Riverpod state management
│   ├── auth_provider.dart         # Auth state (login/logout/user)
│   ├── session_provider.dart      # Daily session state machine
│   ├── interview_provider.dart    # Interview flow state machine
│   └── progress_provider.dart    # Progress charts + report data
│
├── screens/                       # Full-page UI components
│   ├── auth/                      # Login + Signup
│   ├── home/                      # Dashboard
│   ├── session/                   # Daily session + feedback
│   ├── interview/                 # Setup + session + report
│   ├── progress/                  # Charts + reports
│   ├── learning/                  # Learning hub
│   └── profile/                   # User settings
│
├── widgets/                       # Reusable UI components
│   ├── voice_recorder_widget.dart
│   ├── score_card_widget.dart
│   ├── progress_chart_widget.dart
│   ├── panelist_avatar_widget.dart
│   └── session_timer_widget.dart
│
└── services/
    ├── api_service.dart           # All FastAPI calls via Dio
    └── audio_service.dart         # Recording + playback logic
```

**State Management Pattern:**
- `AsyncNotifierProvider` for all async server data
- `StateNotifierProvider` for local session state machines
- `FutureProvider` for one-time fetches (profile, history)
- No `setState` outside of purely local widget state

**Navigation Pattern (GoRouter):**
```
/                     → redirect based on auth state
/login                → LoginScreen
/signup               → SignupScreen
/home                 → HomeScreen (shell with bottom nav)
  /home/session       → DailySessionScreen
  /home/session/feedback → SessionFeedbackScreen
  /home/interview     → InterviewSetupScreen
  /home/interview/:id → InterviewSessionScreen
  /home/interview/:id/report → InterviewReportScreen
  /home/progress      → ProgressScreen
  /home/learn         → LearningHubScreen
  /home/profile       → ProfileScreen
```

### 2.2 Backend Architecture (FastAPI)

```
backend/
├── main.py                        # FastAPI app, CORS, router registration
│
├── routers/                       # HTTP layer (validation, routing)
│   ├── sessions.py                # /sessions/*
│   ├── interview.py               # /interview/*
│   ├── reports.py                 # /reports/*
│   ├── uploads.py                 # /uploads/*
│   └── auth.py                    # /auth/* (Supabase proxy)
│
├── services/                      # Business logic (pure functions)
│   ├── whisper_service.py         # Audio → text (Whisper local)
│   ├── tts_service.py             # Text → audio (Coqui local)
│   ├── llm_service.py             # Text → AI response (Gemini/Groq)
│   ├── analysis_service.py        # Audio + text → speech metrics
│   ├── grammar_service.py         # Text → grammar analysis
│   ├── rag_service.py             # Documents → vector search
│   └── report_service.py          # Data → PDF bytes
│
├── models/                        # Pydantic schemas
│   ├── session_models.py
│   ├── interview_models.py
│   └── user_models.py
│
└── utils/
    ├── supabase_client.py         # Supabase admin client
    ├── prompts.py                 # All LLM prompt templates
    └── audio_utils.py             # Audio conversion helpers
```

**Request Lifecycle — Daily Session Turn:**
```
1. Flutter records audio (WAV, 16kHz, mono)
2. Audio base64-encoded → POST /sessions/turn
3. FastAPI decodes base64 → bytes
4. WhisperService.transcribe() → {text, duration, segments}
5. AnalysisService.analyse() → {wpm, pauses, filler_count, pitch...}
6. GrammarService.check() → {errors, grammar_score, corrected_text}
7. LLMService.generate_json(DAILY_SESSION_SYSTEM, transcript) → coaching response
8. TTSService.synthesize(response_text, voice="coach_female") → WAV bytes
9. Package all results → JSON response (with audio as base64)
10. Flutter decodes audio → plays via just_audio
11. Flutter displays scores + feedback text
12. Supabase updated with turn data (background task)
```

---

## 3. Data Architecture

### 3.1 Entity Relationship Diagram

```
auth.users (Supabase managed)
    │ 1:1
    ▼
profiles ─────────────────────────────────────────────┐
    │ 1:N                                              │
    ├──────────────────────────────────────────────    │
    │                                                  │
    ▼                                                  │
communication_sessions ─────────────────────────────  │
    (accent/grammar/vocab/confidence/fluency scores)   │
                                                       │
    ├──────────────────── 1:N                          │
    ▼                                                  │
interview_setups ──────────────────────────────────── │
    │ 1:N                                              │
    ├── uploaded_documents                             │
    │   (JD, company info, embedded → ChromaDB)        │
    │                                                  │
    └── interview_sessions                             │
            (rounds_data JSONB, per-round scores)      │
                                                       │
progress_snapshots (daily rollup) ─────────────────── ┘
    (one row per user per day, averaged scores)

vocabulary_log (per word learned)
```

### 3.2 Key Data Models

**Session Score Object (stored in JSONB):**
```json
{
  "accent_score": 67.5,
  "grammar_score": 82.0,
  "vocabulary_score": 55.3,
  "confidence_score": 71.0,
  "fluency_score": 68.4,
  "overall_score": 68.8,
  "wpm": 142,
  "filler_count": 4,
  "pause_count": 3,
  "grammar_errors": 2
}
```

**Interview Rounds Config (JSONB):**
```json
[
  {"id": 1, "type": "introduction", "name": "Introduction Round", "enabled": true, "panelist_index": 0},
  {"id": 2, "type": "technical", "name": "Technical Round", "enabled": true, "panelist_index": 1},
  {"id": 3, "type": "managerial", "name": "Manager Round", "enabled": true, "panelist_index": 2},
  {"id": 4, "type": "hr", "name": "HR Round", "enabled": true, "panelist_index": 0},
  {"id": 5, "type": "final", "name": "Final Round", "enabled": false, "panelist_index": 2}
]
```

**Panel Config (JSONB):**
```json
[
  {
    "index": 0,
    "name": "Priya Sharma",
    "designation": "Senior HR Manager",
    "department": "Human Resources",
    "personality": "warm, systematic, process-oriented",
    "voice": "interviewer_hr_female",
    "focus_areas": ["culture fit", "behavioural", "expectations"]
  },
  {
    "index": 1,
    "name": "Rohan Mehta",
    "designation": "Lead Software Engineer",
    "department": "Engineering",
    "personality": "direct, technical, detail-focused",
    "voice": "interviewer_tech_male",
    "focus_areas": ["DSA", "system design", "past projects"]
  }
]
```

---

## 4. Service Architecture

### 4.1 LLM Service — Fallback Chain

```
Request → Gemini 1.5 Flash
              │
              ├── Success → return response
              │
              └── 429/503 Error
                      │
                      ▼
              Groq (Llama 3.1 70B)
                      │
                      ├── Success → return response
                      │
                      └── Error → return cached/default response
                                  (show "Offline Mode" indicator)
```

### 4.2 Audio Processing Pipeline

```
Raw Mic Audio (Flutter)
    │
    │ flutter_sound records at 16kHz, mono, 16-bit PCM WAV
    ▼
WAV Bytes → Base64 String
    │
    │ POST to /sessions/turn
    ▼
FastAPI: decode base64 → bytes
    │
    ├──→ Whisper: bytes → text transcript
    │
    ├──→ Librosa: bytes → pitch, energy, speaking rate, pauses
    │
    └──→ SpeechBrain: bytes → accent features, phoneme distribution
```

### 4.3 RAG Pipeline (Interview Context)

```
User uploads JD PDF or DOCX
    │
    │ POST /uploads/document
    ▼
Backend extracts text (PyMuPDF / python-docx)
    │
    ▼
Chunk text (500 chars, 50 char overlap)
    │
    ▼
sentence-transformers: chunks → 384-dim embeddings
    │
    ▼
ChromaDB: store embeddings with metadata {setup_id, chunk_index, source}
    │
    │ Later, during interview...
    ▼
Interview question generation trigger
    │
    ▼
Query: "questions about Python for Senior Dev at {company}"
    │
    ▼
ChromaDB: semantic search → top 5 relevant chunks
    │
    ▼
LLM receives: question_prompt + retrieved_context
    │
    ▼
Highly relevant, company-specific interview question generated
```

---

## 5. Security Architecture

### 5.1 Authentication Flow

```
Flutter App ←──── JWT Token ────── Supabase Auth
    │                                     │
    │ JWT in Authorization header          │
    ▼                                     │
FastAPI Backend                           │
    │                                     │
    │ Verify JWT via Supabase service key  │
    └─────────────────────────────────────┘
```

- All FastAPI endpoints require a valid Supabase JWT
- Supabase Row Level Security (RLS) ensures users can only query their own data even if the JWT is used directly
- No credentials stored in the Flutter app beyond the Supabase JWT (auto-managed by Supabase Flutter SDK)
- API keys (Gemini, Groq) stored only in backend `.env` — never exposed to frontend

### 5.2 Data Privacy
- User audio is processed in-memory and never persisted to disk
- Transcripts stored in Supabase under the user's own RLS-protected rows
- ChromaDB vector store is per-user (collection namespaced by user/setup ID)
- Uploaded documents stored in Supabase Storage with private access (signed URLs only)

---

## 6. Cross-Device Sync Architecture

```
Mobile App ──┐
              │ Write session data → Supabase PostgreSQL
PC App ──────┤
              │ Supabase Realtime subscription on:
              │   - progress_snapshots (update dashboard live)
              │   - profiles (streak updates)
Web App ──────┘
```

- Supabase Realtime pushes `INSERT` and `UPDATE` events to all connected clients
- Flutter Supabase SDK `supabase.from('table').stream()` keeps UI in sync automatically
- Offline: session data buffered in device `SharedPreferences`, bulk-synced on reconnect

---

## 7. Deployment Architecture

```
┌───────────────────────────────────────────────────────────┐
│  GitHub Repository (source of truth)                       │
│  main branch → auto-deploy triggers                        │
└──────┬────────────────────────────────┬────────────────────┘
       │                                │
       ▼                                ▼
┌─────────────┐               ┌──────────────────┐
│ Render.com  │               │ Vercel / Netlify  │
│ Free Tier   │               │ Free Tier         │
│             │               │                   │
│ FastAPI     │               │ Flutter Web build │
│ Python 3.11 │               │ (web/index.html)  │
│ 512MB RAM   │               │                   │
└─────────────┘               └──────────────────┘
       │                                │
       └───────────────┬────────────────┘
                       │
                       ▼
             ┌───────────────────┐
             │  Supabase Cloud   │
             │  (US-East)        │
             │  PostgreSQL 15    │
             │  Free Tier 500MB  │
             └───────────────────┘

Mobile: Flutter build APK → sideload on Android
        Flutter build iOS → TestFlight or direct install
Desktop: Flutter build windows → .exe installer
```

---

## 8. Scalability Considerations

> Note: This is a personal-use student app. Scalability is not a primary concern, but the architecture is designed to grow naturally.

| Concern | Current Solution | If Scaling Needed |
|---|---|---|
| Whisper STT speed | base model, ~5s/sentence | Switch to faster-whisper on GPU |
| Coqui TTS speed | CPU inference, ~3s/sentence | Pre-cache common phrases, or use cloud TTS |
| LLM rate limits | Gemini free (1500 req/day) | Add Redis-based request queue |
| Database storage | Supabase free 500MB | Archive old sessions to Supabase Storage as JSON |
| Concurrent users | Single Render free instance | Scale to paid Render tier or containerise with Docker |

---

*Architecture Document — SpeakUp v1.0*
