# SpeakUp — System Design Document
**Version:** 1.0  
**Type:** Low-level system design for all major subsystems

---

## 1. High-Level System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          SPEAKUP SYSTEM                         │
│                                                                  │
│  ┌──────────────┐    REST/JSON    ┌───────────────────────────┐ │
│  │   Flutter    │ ◄────────────► │   FastAPI Backend          │ │
│  │   Client     │                │   Python 3.11              │ │
│  │              │   Supabase     │                            │ │
│  │  Android     │ ◄──Realtime──► │  ┌───────┐  ┌──────────┐  │ │
│  │  iOS         │                │  │Whisper│  │Coqui TTS │  │ │
│  │  Web         │   JWT Auth     │  │ STT   │  │          │  │ │
│  │  Windows     │ ◄────────────► │  └───────┘  └──────────┘  │ │
│  └──────────────┘                │                            │ │
│                                  │  ┌───────┐  ┌──────────┐  │ │
│                                  │  │Gemini │  │Librosa   │  │ │
│                                  │  │ LLM   │  │Analysis  │  │ │
│                                  │  └───────┘  └──────────┘  │ │
│                                  └───────────────────────────┘ │
│                                              │                  │
│                                   ┌──────────▼─────────┐       │
│                                   │     Supabase       │       │
│                                   │  PostgreSQL + Auth  │       │
│                                   │  + Storage + RT     │       │
│                                   └────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Subsystem Design

### 2.1 Speech-to-Text Subsystem (Whisper)

**Design Goal:** Convert user's spoken audio to accurate text transcript with segment timing data, running entirely locally with no API cost.

**Implementation:**

```python
# whisper_service.py

import whisper
import numpy as np
import io
import soundfile as sf
from functools import lru_cache

# Singleton model loader
_model = None

def get_model(model_size: str = "base") -> whisper.Whisper:
    """
    Load and cache the Whisper model.
    Called once at startup. 'base' model = ~75MB, ~80% accuracy.
    'small' model = ~150MB, ~88% accuracy (recommended after MVP).
    """
    global _model
    if _model is None:
        _model = whisper.load_model(model_size)
    return _model

async def transcribe_audio(audio_bytes: bytes, language: str = "en") -> dict:
    """
    Transcribe raw audio bytes to text.
    
    Input:  WAV bytes (16kHz, mono, 16-bit PCM — Whisper's optimal format)
    Output: {
        "text": full transcript string,
        "segments": [{start, end, text}, ...],
        "duration": float (seconds),
        "language": detected language code
    }
    
    Pipeline:
    1. Load bytes into soundfile buffer
    2. Convert to float32 numpy array (Whisper requires this)
    3. Resample to 16kHz if needed (librosa.resample)
    4. Run whisper.transcribe()
    5. Extract segments for timing data
    """
    model = get_model()
    
    # Read bytes into numpy array
    audio_buffer = io.BytesIO(audio_bytes)
    audio_array, sample_rate = sf.read(audio_buffer, dtype='float32')
    
    # Convert stereo to mono if needed
    if len(audio_array.shape) > 1:
        audio_array = audio_array.mean(axis=1)
    
    # Resample to 16kHz if needed
    if sample_rate != 16000:
        import librosa
        audio_array = librosa.resample(audio_array, orig_sr=sample_rate, target_sr=16000)
    
    # Transcribe
    result = model.transcribe(audio_array, language=language, fp16=False)
    
    return {
        "text": result["text"].strip(),
        "segments": [{"start": s["start"], "end": s["end"], "text": s["text"]} for s in result["segments"]],
        "duration": result["segments"][-1]["end"] if result["segments"] else 0.0,
        "language": result.get("language", "en")
    }
```

**Whisper Model Selection:**

| Model | Size | Speed (CPU) | Accuracy | Recommendation |
|---|---|---|---|---|
| tiny | 39MB | ~2s/sentence | ~70% | Only if very slow PC |
| base | 74MB | ~5s/sentence | ~80% | **MVP default** |
| small | 150MB | ~10s/sentence | ~88% | Phase 2 upgrade |
| medium | 466MB | ~25s/sentence | ~93% | Only with GPU |

---

### 2.2 Text-to-Speech Subsystem (Coqui TTS)

**Design Goal:** Generate natural, varied AI voices locally — different voice characters for daily coach vs interview panelists.

**Implementation:**

```python
# tts_service.py

from TTS.api import TTS
import io

_tts_model = None

# Map voice character names to Coqui VCTK speaker IDs
# VCTK has 108 speakers (p225-p376)
VOICE_MAP = {
    "coach_female":              "p225",  # Clear, warm female voice
    "coach_male":                "p226",  # Steady, encouraging male voice
    "interviewer_hr_female":     "p228",  # Professional female (HR)
    "interviewer_tech_male":     "p229",  # Direct male (Technical)
    "interviewer_manager_female":"p230",  # Authoritative female (Manager)
    "interviewer_senior_male":   "p231",  # Senior, gravelly male voice
    "interviewer_ceo_male":      "p232",  # Commanding male (CEO/Director)
}

def get_tts_model() -> TTS:
    """Load and cache TTS model. Takes ~8 seconds first time."""
    global _tts_model
    if _tts_model is None:
        _tts_model = TTS(model_name="tts_models/en/vctk/vits", progress_bar=False)
    return _tts_model

async def synthesize(text: str, voice: str = "coach_female") -> bytes:
    """
    Convert text to WAV audio bytes.
    
    Input:  text string, voice character name
    Output: WAV bytes (22050Hz, mono)
    
    Pipeline:
    1. Get speaker ID from VOICE_MAP
    2. Run TTS model with speaker_id
    3. Write output to in-memory WAV buffer
    4. Return bytes
    
    Note: For interview multi-panelist mode, the router
    passes the panelist's assigned voice key from panel_config.
    """
    model = get_tts_model()
    speaker_id = VOICE_MAP.get(voice, "p225")
    
    # Synthesize to in-memory buffer
    wav_buffer = io.BytesIO()
    model.tts_to_file(
        text=text,
        speaker=speaker_id,
        file_path=wav_buffer,
        pipe_out=True
    )
    wav_buffer.seek(0)
    return wav_buffer.read()
```

**Voice Assignment Logic for Interview Panels:**

```python
# In prompts.py — PANEL_SETUP_SYSTEM instructs the LLM to assign voices
# The LLM maps each panelist to a voice key based on their role:
#
# HR roles → "interviewer_hr_female"
# Technical roles → "interviewer_tech_male"  
# Manager roles → "interviewer_manager_female"
# Senior/Director → "interviewer_senior_male"
# CEO/VP → "interviewer_ceo_male"
#
# If panel_size = 1 → always "coach_male" or "coach_female"
# If panel_size = 2 → mix of two different voice characters
# If panel_size = 3-5 → all five interviewer voices used, no repeats
```

---

### 2.3 LLM Service — Gemini + Groq Fallback

**Design Goal:** Generate high-quality, structured JSON responses from the AI. Never crash if one provider fails.

```python
# llm_service.py

import google.generativeai as genai
from groq import Groq
import json
import asyncio
import os

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
_groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

GEMINI_MODEL = "gemini-1.5-flash"
GROQ_MODEL = "llama-3.1-70b-versatile"

async def generate(system_prompt: str, user_message: str, temperature: float = 0.7) -> str:
    """Try Gemini first, fall back to Groq on any error."""
    
    for attempt in range(3):
        try:
            # Try Gemini
            model = genai.GenerativeModel(
                GEMINI_MODEL,
                system_instruction=system_prompt
            )
            response = model.generate_content(
                user_message,
                generation_config=genai.types.GenerationConfig(temperature=temperature)
            )
            return response.text
            
        except Exception as gemini_error:
            if "429" in str(gemini_error) or "503" in str(gemini_error):
                # Rate limited or unavailable — try Groq
                try:
                    completion = _groq_client.chat.completions.create(
                        model=GROQ_MODEL,
                        messages=[
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_message}
                        ],
                        temperature=temperature
                    )
                    return completion.choices[0].message.content
                except Exception as groq_error:
                    if attempt == 2:
                        raise RuntimeError(f"Both LLMs failed. Gemini: {gemini_error}, Groq: {groq_error}")
            
            await asyncio.sleep(2 ** attempt)  # Exponential backoff
    
    raise RuntimeError("Max retries exceeded")


async def generate_json(system_prompt: str, user_message: str) -> dict:
    """
    Generate a structured JSON response.
    Always appends JSON-only instruction to system prompt.
    """
    json_system = system_prompt + "\n\nCRITICAL: Respond ONLY with valid JSON. No markdown. No explanation. No backticks. Just the raw JSON object."
    
    raw = await generate(json_system, user_message, temperature=0.7)
    
    # Clean response (remove any accidental backticks or 'json' prefix)
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip().strip("```")
    
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"LLM did not return valid JSON: {e}\nRaw: {raw[:200]}")
```

**Rate Limit Budget (Daily Free Tier):**

| Provider | Model | Free Limit | Expected Usage (1 user/day) |
|---|---|---|---|
| Google Gemini | gemini-1.5-flash | 1,500 req/day, 1M tokens/day | ~20-30 req/day |
| Groq | llama-3.1-70b | ~14,400 req/day | Fallback only |

---

### 2.4 Speech Analysis Subsystem

**Design Goal:** Extract 10 measurable metrics from every audio turn to produce meaningful, trainable scores.

```python
# analysis_service.py

import librosa
import numpy as np
import re
from typing import Optional

FILLER_WORDS = {"um", "uh", "like", "you know", "basically", "actually", "sort of", "kind of", "i mean", "right"}

def analyse_audio_and_text(audio_bytes: bytes, transcript: str) -> dict:
    """
    Full analysis pipeline. Returns dict of all computed metrics.
    
    AUDIO METRICS (from librosa):
    ─────────────────────────────
    - duration: total audio length in seconds
    - avg_pitch: mean fundamental frequency (F0) in Hz
    - pitch_variance: standard deviation of F0 (measures intonation variety)
    - energy_db: RMS energy in decibels (speaking volume)
    - energy_variance: std dev of energy (measures dynamic range)
    
    TEXT + AUDIO COMBINED METRICS:
    ───────────────────────────────
    - words_per_minute (wpm): word count / (duration / 60)
    - pause_count: number of silent gaps > 0.5 seconds
    - filler_count: occurrences of filler words/phrases
    - words_count: total word count
    
    COMPUTED SCORES (all 0-100):
    ────────────────────────────
    - confidence_score
    - fluency_score
    - vocabulary_score (requires NLTK — see below)
    """
    
    # Load audio from bytes
    import io, soundfile as sf
    audio_buffer = io.BytesIO(audio_bytes)
    y, sr = sf.read(audio_buffer, dtype='float32')
    if len(y.shape) > 1:
        y = y.mean(axis=1)
    
    # Resample to 22050Hz for librosa
    if sr != 22050:
        y = librosa.resample(y, orig_sr=sr, target_sr=22050)
    sr = 22050
    
    duration = librosa.get_duration(y=y, sr=sr)
    
    # ── Pitch (F0) ──────────────────────────────────────────────
    f0, voiced_flag, _ = librosa.pyin(y, fmin=80, fmax=400, sr=sr)
    voiced_f0 = f0[voiced_flag & ~np.isnan(f0)]
    avg_pitch = float(np.mean(voiced_f0)) if len(voiced_f0) > 0 else 0.0
    pitch_variance = float(np.std(voiced_f0)) if len(voiced_f0) > 0 else 0.0
    
    # ── Energy ──────────────────────────────────────────────────
    rms = librosa.feature.rms(y=y)[0]
    energy_db = float(librosa.amplitude_to_db(np.mean(rms)))
    energy_variance = float(np.std(librosa.amplitude_to_db(rms)))
    
    # ── Pause Detection ─────────────────────────────────────────
    # Use energy threshold to find silent frames
    frame_length = int(0.5 * sr)  # 0.5 second frames
    hop_length = frame_length // 2
    rms_frames = librosa.feature.rms(y=y, frame_length=frame_length, hop_length=hop_length)[0]
    silence_threshold = np.percentile(rms_frames, 15)  # Bottom 15% = silence
    silent_frames = rms_frames < silence_threshold
    
    # Count transitions from non-silent to silent (pause starts)
    pause_count = int(np.sum(np.diff(silent_frames.astype(int)) == 1))
    
    # ── Text Metrics ────────────────────────────────────────────
    words = transcript.lower().split()
    words_count = len(words)
    wpm = int((words_count / duration) * 60) if duration > 0 else 0
    
    # Count filler words/phrases
    text_lower = transcript.lower()
    filler_count = sum(text_lower.count(f) for f in FILLER_WORDS)
    
    # ── Score Computation ────────────────────────────────────────
    
    # Confidence Score
    # Deduct for fillers and excessive pauses; bonus for good pace
    confidence_raw = 100 - (filler_count * 5) - (pause_count * 2)
    if 110 <= wpm <= 160:
        confidence_raw += 10  # Good speaking pace bonus
    elif wpm < 80:
        confidence_raw -= 10  # Very slow speaker penalty
    confidence_score = max(0.0, min(100.0, float(confidence_raw)))
    
    # Fluency Score
    # Based on pace consistency and sentence structure
    sentences = re.split(r'[.!?]+', transcript)
    complete_sentences = [s.strip() for s in sentences if len(s.strip().split()) >= 4]
    completion_rate = len(complete_sentences) / max(len(sentences), 1)
    avg_words_per_sentence = words_count / max(len(sentences), 1)
    
    fluency_raw = (completion_rate * 50) + (min(avg_words_per_sentence / 15, 1) * 30) + (min(wpm / 150, 1) * 20)
    fluency_score = max(0.0, min(100.0, float(fluency_raw * 100)))
    
    # Vocabulary Score (basic — NLTK vocab analysis in grammar_service)
    unique_words = set(re.sub(r'[^\w\s]', '', transcript.lower()).split())
    type_token_ratio = len(unique_words) / max(words_count, 1)
    avg_word_length = np.mean([len(w) for w in unique_words]) if unique_words else 0
    
    vocabulary_score = max(0.0, min(100.0, float(
        (type_token_ratio * 60) + (min(avg_word_length / 7, 1) * 40)
    )))
    
    return {
        # Raw metrics
        "duration": round(duration, 2),
        "wpm": wpm,
        "words_count": words_count,
        "pause_count": pause_count,
        "filler_count": filler_count,
        "avg_pitch": round(avg_pitch, 2),
        "pitch_variance": round(pitch_variance, 2),
        "energy_db": round(energy_db, 2),
        "energy_variance": round(energy_variance, 2),
        "type_token_ratio": round(type_token_ratio, 3),
        "completion_rate": round(completion_rate, 3),
        # Computed scores (0-100)
        "confidence_score": round(confidence_score, 2),
        "fluency_score": round(fluency_score, 2),
        "vocabulary_score": round(vocabulary_score, 2),
    }
```

---

### 2.5 Grammar Analysis Subsystem

```python
# grammar_service.py

import language_tool_python
from functools import lru_cache

@lru_cache(maxsize=1)
def _get_tool():
    """Load LanguageTool once and cache it. Takes ~5 seconds first time."""
    return language_tool_python.LanguageTool('en-US')

def check_grammar(text: str) -> dict:
    """
    Check grammar and return structured analysis.
    
    Skips very short texts (< 10 words) — not enough context for grammar analysis.
    
    Returns:
    {
        "error_count": int,
        "errors": [
            {
                "message": "This is a grammar error description",
                "bad_text": "the wrong text",
                "suggestion": "the correct text",
                "category": "GRAMMAR|PUNCTUATION|STYLE|TYPOS"
            }
        ],
        "grammar_score": float (0-100),
        "corrected_text": str,
        "error_categories": {"GRAMMAR": 2, "TYPOS": 1}
    }
    """
    tool = _get_tool()
    word_count = len(text.split())
    
    if word_count < 10:
        return {
            "error_count": 0,
            "errors": [],
            "grammar_score": 85.0,  # Give benefit of doubt for short responses
            "corrected_text": text,
            "error_categories": {}
        }
    
    matches = tool.check(text)
    
    errors = []
    corrected = text
    categories = {}
    
    for match in matches:
        category = match.ruleId.split('_')[0] if '_' in match.ruleId else 'GRAMMAR'
        suggestion = match.replacements[0] if match.replacements else ""
        
        errors.append({
            "message": match.message,
            "bad_text": text[match.offset:match.offset + match.errorLength],
            "suggestion": suggestion,
            "category": category,
            "offset": match.offset
        })
        categories[category] = categories.get(category, 0) + 1
    
    # Auto-correct using first suggestion for each match
    corrected = language_tool_python.utils.correct(text, matches)
    
    # Score: start at 100, deduct 5 per error (min 0, max 100)
    # Scale penalty by text length (longer text gets more lenient)
    penalty_per_error = max(3, 5 - (word_count // 30))  # More lenient for longer speech
    grammar_score = max(0.0, min(100.0, 100.0 - (len(errors) * penalty_per_error)))
    
    return {
        "error_count": len(errors),
        "errors": errors[:5],  # Return max 5 errors to avoid overwhelming the user
        "grammar_score": round(grammar_score, 2),
        "corrected_text": corrected,
        "error_categories": categories
    }
```

---

### 2.6 RAG System Design (Document-Aware Interview Questions)

**Design Goal:** When a user uploads a job description or company info, the interview questions should be specifically tailored to that company's context, values, and technical requirements.

```
Document Upload Flow:
─────────────────────

User uploads JD.pdf
        │
        ▼
uploads.py router
        │
        ├── Save raw file to Supabase Storage
        │   Path: {user_id}/interview/{setup_id}/jd.pdf
        │
        ├── Extract text:
        │   PDF → PyMuPDF (fitz)
        │   DOCX → python-docx
        │   TXT → direct read
        │
        ├── Save extracted text to uploaded_documents table
        │
        └── Background task: embed_and_store(setup_id, text)


Embedding + Chunking:
─────────────────────

raw_text (e.g., 2000 char JD)
        │
        ▼
Chunk into pieces of 500 chars with 50-char overlap:
  ["We are hiring a Senior Python...", 
   "...Python Developer. You will...",
   "...will work on our ML pipeline..."]
        │
        ▼
sentence-transformers: "all-MiniLM-L6-v2"
  → 384-dimensional embedding per chunk
        │
        ▼
ChromaDB collection: "setup_{setup_id}"
  Store: embedding + chunk text + metadata
         {source: "jd", chunk_index: 0, setup_id: "..."}


Retrieval Flow (during interview):
───────────────────────────────────

Interview question needed for:
  "Technical round, Python, {company_name}"
        │
        ▼
Generate query embedding:
  sentence-transformers.encode("technical Python questions {company}")
        │
        ▼
ChromaDB: cosine similarity search
  → top 5 most relevant document chunks
        │
        ▼
Concatenate chunks → context_string (max 1000 chars)
        │
        ▼
Gemini prompt: INTERVIEW_QUESTION_SYSTEM + context_string
        │
        ▼
Question perfectly tailored to company + role + JD
```

```python
# rag_service.py — Core implementation

import chromadb
from sentence_transformers import SentenceTransformer
import os

CHROMA_DIR = os.getenv("CHROMA_PERSIST_DIR", "./chroma_data")
EMBED_MODEL = "all-MiniLM-L6-v2"

_embed_model = None
_chroma_client = None

def get_embed_model():
    global _embed_model
    if _embed_model is None:
        _embed_model = SentenceTransformer(EMBED_MODEL)
    return _embed_model

def get_chroma():
    global _chroma_client
    if _chroma_client is None:
        _chroma_client = chromadb.PersistentClient(path=CHROMA_DIR)
    return _chroma_client

def _chunk_text(text: str, chunk_size: int = 500, overlap: int = 50) -> list[str]:
    """Split text into overlapping chunks."""
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))
        chunks.append(text[start:end])
        start = end - overlap
    return chunks

def embed_document(setup_id: str, text: str, source: str = "document") -> bool:
    """Chunk, embed, and store a document for a given setup."""
    model = get_embed_model()
    client = get_chroma()
    
    collection = client.get_or_create_collection(f"setup_{setup_id}")
    chunks = _chunk_text(text)
    embeddings = model.encode(chunks).tolist()
    
    collection.add(
        ids=[f"{source}_{i}" for i in range(len(chunks))],
        embeddings=embeddings,
        documents=chunks,
        metadatas=[{"source": source, "chunk_index": i, "setup_id": setup_id} for i in range(len(chunks))]
    )
    return True

def query_context(setup_id: str, query: str, n_results: int = 5) -> str:
    """Retrieve top relevant chunks as a single context string."""
    model = get_embed_model()
    client = get_chroma()
    
    try:
        collection = client.get_collection(f"setup_{setup_id}")
    except Exception:
        return ""  # No documents uploaded for this setup
    
    query_embedding = model.encode([query]).tolist()
    results = collection.query(query_embeddings=query_embedding, n_results=n_results)
    
    chunks = results["documents"][0] if results["documents"] else []
    return "\n\n".join(chunks)
```

---

### 2.7 Score Computation System

**Design Goal:** All scores are normalised to 0-100. Overall score is a weighted average. Weights reflect importance to communication coaching.

```
Score Weights:
──────────────

For Daily Communication Session:
┌────────────────┬────────┬──────────────────────────────────────┐
│ Score          │ Weight │ Why This Weight                      │
├────────────────┼────────┼──────────────────────────────────────┤
│ Grammar        │  25%   │ Foundation of correct communication  │
│ Vocabulary     │  20%   │ Expression range matters             │
│ Confidence     │  25%   │ Core goal of the app                 │
│ Fluency        │  30%   │ How naturally you speak = most felt  │
└────────────────┴────────┴──────────────────────────────────────┘

overall = (grammar * 0.25) + (vocabulary * 0.20) + 
          (confidence * 0.25) + (fluency * 0.30)

For Interview Session (per round):
┌────────────────┬────────┬──────────────────────────────────────┐
│ Score          │ Weight │ Notes                                │
├────────────────┼────────┼──────────────────────────────────────┤
│ Answer Quality │  40%   │ Relevance + depth of answer          │
│ Communication  │  30%   │ Grammar + vocabulary + fluency       │
│ Confidence     │  20%   │ From speech analysis                 │
│ Completeness   │  10%   │ Did they answer what was asked?      │
└────────────────┴────────┴──────────────────────────────────────┘
```

**Score Storage and Aggregation:**

```python
# In sessions.py router — end session handler

async def aggregate_session_scores(session_turns: list[dict]) -> dict:
    """
    Average all per-turn scores to produce session-level scores.
    Weights recent turns more heavily (learning improves during session).
    """
    if not session_turns:
        return {"grammar": 0, "vocabulary": 0, "confidence": 0, "fluency": 0, "overall": 0}
    
    n = len(session_turns)
    # Linear weights: last turn has highest weight
    weights = [i + 1 for i in range(n)]
    total_weight = sum(weights)
    
    def weighted_avg(key: str) -> float:
        values = [t.get(key, 0) for t in session_turns]
        return sum(v * w for v, w in zip(values, weights)) / total_weight
    
    grammar = weighted_avg("grammar_score")
    vocabulary = weighted_avg("vocabulary_score")
    confidence = weighted_avg("confidence_score")
    fluency = weighted_avg("fluency_score")
    overall = (grammar * 0.25) + (vocabulary * 0.20) + (confidence * 0.25) + (fluency * 0.30)
    
    return {
        "grammar_score": round(grammar, 2),
        "vocabulary_score": round(vocabulary, 2),
        "confidence_score": round(confidence, 2),
        "fluency_score": round(fluency, 2),
        "overall_score": round(overall, 2)
    }
```

---

### 2.8 Progress Tracking System

**Design Goal:** Maintain a daily rollup snapshot per user so charts are always fast to query (no aggregation at query time).

```
Daily Snapshot Creation:
─────────────────────────

At session end (POST /sessions/end):
  1. Query all sessions for user on today's date
  2. Average their scores
  3. UPSERT into progress_snapshots for (user_id, today)

Progress Query:
───────────────

GET /progress/{user_id}?days=30
  → SELECT * FROM progress_snapshots 
    WHERE user_id = $1 
    AND snapshot_date >= now() - INTERVAL '$2 days'
    ORDER BY snapshot_date ASC
  → Fills missing days with null (frontend shows gaps)

Streak Logic:
─────────────
  On session end:
  1. Check if yesterday's snapshot exists for user
  2. If yes: streak += 1
  3. If no (missed a day): streak = 1
  4. Update profiles.daily_streak
```

---

### 2.9 Multi-Panelist Interview System

**Design Goal:** When a user sets panel_size > 1, each "interviewer" should feel like a distinct human being — different voice, different focus, different personality.

```
Panel Generation Flow:
──────────────────────

User sets company="Google", role="SDE-2", panel_size=3
        │
        ▼
POST /interview/setup
        │
        ├── LLM call with PANEL_SETUP_SYSTEM prompt
        │   Context: company="Google", role="SDE-2", panel_size=3
        │
        ├── LLM returns (example):
        │   [
        │     {name:"Aarav Shah", designation:"L5 Software Engineer",
        │      personality:"methodical, data-driven", voice:"interviewer_tech_male",
        │      focus_areas:["coding", "system design", "DSA"]},
        │     {name:"Meera Patel", designation:"Engineering Manager",
        │      personality:"strategic, people-focused", voice:"interviewer_manager_female",
        │      focus_areas:["leadership", "project impact", "collaboration"]},
        │     {name:"Sunita Roy", designation:"HR Business Partner",
        │      personality:"empathetic, structured", voice:"interviewer_hr_female",
        │      focus_areas:["culture fit", "career goals", "compensation"]}
        │   ]
        │
        └── Save panel_config as JSONB in interview_setups


Question Rotation During Session:
──────────────────────────────────

interview_session state:
  {current_round: "technical", current_panelist_index: 0, questions_asked: 3}

Each answer received:
  1. Evaluate answer (using current panelist's voice in evaluation)
  2. Decide next_action: "follow_up" | "next_question" | "next_panelist" | "next_round"
  3. If next_panelist: current_panelist_index = (current_panelist_index + 1) % panel_size
  4. Generate next question with new panelist's context

Voice Switching in Flutter:
───────────────────────────

Each API response includes:
  {
    "panelist_index": 1,
    "panelist_name": "Meera Patel",
    "panelist_designation": "Engineering Manager",
    "question_text": "Tell me about a time you influenced without authority.",
    "audio_base64": "..."   ← synthesized with interviewer_manager_female voice
  }

Flutter InterviewSessionScreen:
  - Shows panelist avatar (initials circle, color-coded by index)
  - Shows panelist name + designation
  - Updates avatar when panelist_index changes
  - Plays audio with panelist's voice
```

---

### 2.10 Offline Mode Design

```
Connectivity States:
────────────────────

ONLINE:
  - Full pipeline: Whisper → Analysis → Gemini → Coqui → Supabase
  - Real-time sync with Supabase

OFFLINE:
  - STT: Whisper still works (local model)
  - TTS: Coqui still works (local model)
  - LLM: Cannot reach Gemini/Groq → use cached exercises
  - Supabase: Cannot write → buffer in SharedPreferences
  
  Offline UI:
  - Banner: "Offline Mode — your data will sync when you reconnect"
  - Session proceeds with cached exercises and local analysis
  - Scores still computed (grammar, vocabulary, confidence, fluency)
  - Session data saved locally (SharedPreferences as JSON)

RECONNECT:
  - Detect via ConnectivityPlus stream
  - Flush offline queue: POST all buffered sessions to backend
  - Backend saves to Supabase
  - Show: "Synced X sessions from offline mode"

Offline Cache Structure (SharedPreferences):
  "offline_sessions": [
    {
      "temp_id": "local_1234567890",
      "started_at": "ISO timestamp",
      "scores": {...},
      "transcript": "...",
      "synced": false
    }
  ]
  "last_exercises": ["Exercise 1 text", "Exercise 2 text", "Exercise 3 text"]
  "last_feedback_tips": ["Tip 1", "Tip 2"]
```

---

## 3. Error Handling Strategy

| Layer | Error Type | Handling |
|---|---|---|
| Flutter | Network timeout | Show SnackBar, allow retry |
| Flutter | Auth expiry | Redirect to login, show message |
| Flutter | Mic permission denied | Show settings dialog |
| FastAPI | Whisper failure | Return `{"transcript": "", "error": "stt_failed"}` |
| FastAPI | LLM rate limit | Auto-fallback to Groq, no user impact |
| FastAPI | Both LLMs down | Return cached response + log error |
| FastAPI | Coqui failure | Return text-only response, Flutter shows text |
| FastAPI | Supabase down | Return scores, queue DB write for retry |
| Supabase | RLS violation | 403 → Flutter shows "Permission denied" |

---

## 4. API Rate Limiting Strategy

```
Gemini Free Tier: 15 req/min, 1,500 req/day
Groq Free Tier: 30 req/min, ~14,400 req/day

Per-session LLM calls:
  - Session start: 1 call (greeting)
  - Each turn: 1 call (coaching response) + 1 call (feedback generation at end)
  - A 10-turn session: ~12 LLM calls
  - 3 sessions per day: ~36 calls
  - Well within both free tier limits for single user
  
If expanding to multiple users:
  - Add Redis-based rate limiter (per user_id)
  - Queue requests with exponential backoff
  - Implement request deduplication for identical prompts
```

---

*System Design Document — SpeakUp v1.0*
