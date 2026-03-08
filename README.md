# SpeakUp — AI Communication Coach

> An AI-powered voice coaching app for English communication, confidence, and interview skills.

---

## ⚡ Quick Start — Backend

**Prerequisites:** Python 3.11+, FFmpeg installed

```bash
cd backend
python -m venv venv
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

pip install -r requirements.txt

# Copy and fill in your API keys
cp .env.example .env

# Run (development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**API docs:** [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 📱 Quick Start — Flutter App

**Prerequisites:** Flutter SDK 3.22+ (stable channel)

```bash
cd apps/mobile_web_app
flutter pub get

# Run on Android (with emulator running)
flutter run

# Run on Web
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8000
```

---

## 🗄️ Database Setup (Supabase)

1. Create a free project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** in the Supabase dashboard
3. Paste and run `infrastructure/supabase/schema.sql`
4. Copy your **Project URL**, **Anon Key**, and **Service Key** into `backend/.env`

---

## 🔑 Environment Variables (`backend/.env`)

| Variable | Description |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase public anon key |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (backend only) |
| `GEMINI_API_KEY` | Google Gemini API key (get from [AI Studio](https://aistudio.google.com)) |
| `GROQ_API_KEY` | Groq API key (fallback LLM) |
| `WHISPER_MODEL_SIZE` | `base` (default) — try `small` for better accuracy |

---

## 🏗️ Architecture

```
speak_up/
├── backend/                  # FastAPI Python Backend
│   ├── main.py               # App entry + startup model loading
│   ├── routers/              # auth.py, sessions.py, progress.py
│   ├── services/             # whisper, tts, llm, analysis, grammar
│   ├── models/               # Pydantic schemas
│   └── utils/                # supabase_client, audio_utils, prompts
├── apps/mobile_web_app/      # Flutter Frontend
│   └── lib/
│       ├── core/             # theme, router, constants, supabase_config
│       ├── screens/          # auth, home, session, progress, profile
│       ├── providers/        # auth, session, progress (Riverpod)
│       └── services/         # api_service, audio_service
└── infrastructure/
    └── supabase/schema.sql   # Full DB setup with RLS
```

---

## 📋 Phase Roadmap

| Phase | Status | Description |
|---|---|---|
| **Phase 1 — MVP** | ✅ Complete | Voice coaching loop, Auth, Progress tracking |
| **Phase 2 — Interview** | 🔜 Planned | Multi-panelist mock interviews, RAG with JD upload |
| **Phase 3 — Polish** | 🔜 Planned | Gamification, Learning hub, PDF reports |

---

## 🧪 Running Backend Tests

```bash
cd backend
pytest tests/ -v
```
