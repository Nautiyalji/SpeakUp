# 07 - Monorepo Structure

## 1. Project Root Directory
```text
speak_up/
├── apps/                        # Frontend Clients
│   └── mobile_web_app/          # Flutter Project
├── backend/                     # API & AI Services
│   ├── app/                     # Main logic
│   │   ├── routers/             # API Endpoints
│   │   ├── services/            # ML/Core logic
│   │   ├── models/              # Pydantic Schemas
│   │   └── utils/               # Audio/Auth helpers
│   ├── data/                    # Local storage (models, chroma)
│   ├── tests/                   # Pytest suite
│   ├── main.py                  # Entry Point
│   └── requirements.txt         # Dependencies
├── infrastructure/              # DevOps & Config
│   ├── scripts/                 # Pre-warm & ping scripts
│   └── supabase/                # SQL Migrations
├── docs/                        # Project Documentation
└── README.md
```

## 2. Flutter Internal Hierarchy
```text
lib/
├── core/                        # Routing, Theme, Config
├── providers/                   # Riverpod State Management
├── screens/                     # Feature-specific pages
├── widgets/                     # UI components (atoms/molecules)
├── services/                    # API & Local Audio Logic
└── main.dart
```

## 3. Backend Details
- **Environment:** Dedicated `.env` for API Keys (Gemini, Groq, Supabase).
- **In-Memory:** Audio processing is entirely in-memory (io.BytesIO).
- **Model Caching:** Whisper and Coqui models cached in a persistent volume on Render / local disk.
