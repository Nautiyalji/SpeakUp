# 08 - Scoring Engine Specification

## 1. Speech-to-Text (Whisper)
- **Model:** OpenAI Whisper `base` (75MB) for MVP; `small` for Phase 2.
- **Input:** 16kHz Mono WAV (PCM).
- **Logic:** Performs transcription and segment/timestamp generation.

## 2. Acoustic Analysis (Librosa)
- **Pitch (F0):** Calculated via `pyin` algorithm. Measures intonation and energy.
- **Energy (dB):** RMS energy to detect speaking volume and emphasis.
- **Pause Detection:** Energy thresholds to detect gaps > 0.5s.

## 3. Linguistic Analysis
- **Grammar:** `language_tool_python` finds common errors and provides suggestions.
- **Vocabulary:** Ratio of unique words (Type-Token Ratio) and word length via `NLTK`.
- **Filler Word Detection:** Regex-based count of "um", "uh", "like", "basically", etc.

## 4. Scoring Algorithm (0-100)
| Metric | Computation Logic | Weight |
|---|---|---|
| **Grammar** | 100 - (error_count * 5). Lenient scaling for longer text. | 25% |
| **Vocabulary**| (TTR * 60) + (avg_word_length_scaled * 40). | 20% |
| **Confidence** | 100 - (fillers * 5) - (pauses * 2) + (WPM_bonus). | 25% |
| **Fluency** | (completion_rate * 50) + (sentence_depth * 30) + (pace * 20). | 30% |

## 5. Feedback Loop
1. **Raw Metrics:** `wpm`, `pause_count`, `filler_count`, `grammar_errors`.
2. **Contextual Coaching:** Gemini takes the transcript and counts to generate a tip (e.g., "Take a breath instead of saying 'um'").
3. **Session Rollup:** Weighted average of turns, favoring progress in later turns.
