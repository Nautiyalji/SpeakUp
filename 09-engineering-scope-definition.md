# 09 - Engineering Scope Definition

## 1. MoSCoW Prioritization

### MUST HAVE (MVP)
- **Auth:** Email login & cross-device persistence.
- **Voice Loop:** Whisper STT, Gemini LLM, Coqui TTS.
- **Scoring:** Grammar, Vocab, Confidence, Fluency.
- **UI:** Basic Dashboard & Session screen (Light/Dark mode).
- **Backend:** FastAPI on Render.com with Supabase.

### SHOULD HAVE (Phase 2)
- **Interview:** Single/Multi-panelist simulations.
- **Context:** JD Upload and RAG integration.
- **Scoring:** Accent phoneme scoring (SpeechBrain).

### COULD HAVE (Phase 3)
- **Learning:** Daily grammar guides and vocab puzzles.
- **Reporting:** Weekly/Monthly PDF report generation.

### WON'T HAVE (Confirmed Out of Scope)
- Video analysis or live avatars.
- Social leaderboards or friend comparison.
- Teacher/Mentor dashboards.

## 2. Technical Dependencies
- **External APIs:** Google Gemini (Primary), Groq (Fallback), Supabase (BaaS).
- **Open Source:** OpenAI Whisper, Coqui TTS, LanguageTool, Librosa, ChromaDB.

## 3. Risk Assessment
- **Cold Starts:** Render.com free tier delay (~50s). *Mitigation: Scheduled ping script.*
- **Storage Limits:** Supabase 500DB cap. *Mitigation: Archival of old session logs to JSON files in Storage.*
- **Model Latency:** Local TTS/STT processing time. *Mitigation: Lightweight model selection (Whisper-base).*
