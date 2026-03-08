# SpeakUp 🎙️ — AI Communication & Interview Coach

[![Vercel Deployment](https://img.shields.io/badge/Frontend-Vercel-black?style=for-the-badge&logo=vercel)](https://speak-up-ochre.vercel.app)
[![Render Deployment](https://img.shields.io/badge/Backend-Render-46E3B7?style=for-the-badge&logo=render&logoColor=white)](https://speakup-api-jd2e.onrender.com/health)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)

**SpeakUp** is a state-of-the-art AI-powered communication coach designed to help individuals master English fluency, build confidence, and ace high-stakes interviews. Using a blend of LLMs, Voice-to-Text, and Acoustic Analysis, SpeakUp provides real-time, actionable feedback.

---

## ✨ Features

*   **🗣️ Real-time Voice Interaction**: Engage in natural conversations with an AI coach.
*   **🧠 Intelligent Analysis**: Feedback on grammar, vocabulary, and pronunciation.
*   **📊 Progress Dashboard**: Track your fluency improvements over time with detailed charts.
*   **🎯 Accent Selection**: Choose between Indian and British English targets to align with your goals.
*   **🏢 Interview Mastery**: (Phase 2) Roleplay mock interviews with domain-specific AI panelists.

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: [Flutter](https://flutter.dev) (Web & Mobile)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Networking**: [Dio](https://pub.dev/packages/dio)
- **Auth & DB**: [Supabase Flutter SDK](https://supabase.com/docs/reference/dart/initializing)

### Backend
- **Framework**: [FastAPI](https://fastapi.tiangolo.com) (Python)
- **STT**: [OpenAI Whisper](https://github.com/openai/whisper)
- **LLMs**: Google Gemini (Pro) & Groq (Llama-3)
- **Audio Processing**: [Librosa](https://librosa.org/) & Scipy
- **DB Client**: [Supabase Python](https://supabase.com/docs/reference/python/introduction)

---

## 🏗️ Project Structure

```bash
SpeakUp/
├── apps/mobile_web_app/      # Flutter Web & Mobile Client
│   ├── lib/
│   │   ├── core/             # Design System & Routing
│   │   ├── providers/        # State Management (Auth, Session)
│   │   ├── screens/          # UI Layers
│   │   └── services/         # API & Audio Logic
│   └── vercel_build.sh       # Custom Vercel Build Script
├── backend/                  # FastAPI Python Server
│   ├── routers/              # API Endpoints
│   ├── services/             # ML & AI Service Logic
│   ├── models/               # Data Schemas
│   └── utils/                # Database & Audio Utils
├── infrastructure/           # Supabase Schema & SQL
└── render.yaml               # Infrastructure as Code (Render)
```

---

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/Nautiyalji/SpeakUp.git
cd SpeakUp
```

### 2. Backend Setup
```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate | Mac/Linux: source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Add your API keys here
uvicorn main:app --reload
```

### 3. Frontend Setup
```bash
cd apps/mobile_web_app
flutter pub get
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8000
```

---

## ☁️ Deployment

- **Frontend**: Automatically deployed to **Vercel** on every push to `main`.
- **Backend**: Hosted on **Render** (Free tier) with automatic zero-downtime deployments.

---

## 📅 Roadmap

- [x] **Phase 1**: MVP with Voice Coaching & Progress Tracking.
- [ ] **Phase 2**: Interview Intelligence (RAG + JD Analysis).
- [ ] **Phase 3**: Gamified Learning Hub & Social Sharing.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Developed with ❤️ by the **SpeakUp Team**.
