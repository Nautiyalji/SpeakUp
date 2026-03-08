# 10 - Development Phases

## Phase 1: MVP Core (6-8 Weeks)
*Goal: Working end-to-end voice coaching loop.*
- **Weeks 1-2:** Backend Env Set-up, Supabase DB Schema, Auth Integration.
- **Weeks 3-4:** Whisper (STT) & Coqui (TTS) local pipeline.
- **Weeks 5-6:** Scoring Engine (Grammar, Vocab, Confidence) Logic.
- **Weeks 7-8:** Flutter UI Construction & End-to-End Testing.

## Phase 2: Interview Intelligence (4-5 Weeks)
*Goal: Mock interview simulation with context.*
- **Weeks 1-2:** RAG Service (PDF Parsing, ChromaDB Embedding).
- **Week 3:** Interview Setup Wizard (JD upload, Panel config).
- **Week 4:** Multi-voice Panelist Simulation & Round-based Scoring.
- **Week 5:** Interview Report Screen.

## Phase 3: Learning & Polish (3 Weeks)
*Goal: Gamification and educational content.*
- **Week 1:** Accent Phoneme Analysis (SpeechBrain integration).
- **Week 2:** Learning Hub (Grammar guides, Vocab of the day).
- **Week 3:** Weekly/Monthly PDF Report Generation.

## Phase 4: Deployment & Scaling
- Production deployments to Render/Vercel.
- Performance optimization for cold starts.
- Sideloading APK testing for Android.
