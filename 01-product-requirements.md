# 01 - Product Requirements Document (PRD)

## 1. Vision & Strategy
SpeakUp is an AI-driven communication coach designed to help students, particularly in India, overcome barriers in English speaking, public communication, and interview readiness. It provides a judgment-free, personalized coaching experience at zero cost.

## 2. Target Audience
- **Primary:** Beginners (18-25) with low confidence and limited access to professional coaching.
- **Secondary:** Placement-seeking students needing company-specific interview simulation.

## 3. Core Features (MVP)
- **Daily Voice Sessions:** Conversational AI coach with warm, natural voice feedback.
- **Multimodal Scoring:** Grammar, Vocabulary, Confidence, and Fluency analysis.
- **Cross-Device Sync:** Seamless experience across Mobile (Android/iOS), Web, and Desktop via Supabase.
- **Personalization:** Level-based difficulty (Beginner/Intermediate/Advanced) and Accent selection (Indian/British English).

## 4. Functional Requirements (Summary)
| ID | Category | Requirement |
|---|---|---|
| FR-1 | Auth | Email registration and cross-device session persistence (Supabase). |
| FR-2 | Session | High-accuracy transcription (Whisper) and TTS (Coqui). |
| FR-3 | Analysis | Grammar check (LanguageTool) and vocabulary richness (NLTK). |
| FR-4 | Scoring | Real-time confidence (filler words/pauses) and fluency metrics. |
| FR-5 | Progress | Dashboard with 7-day scoring chart and session history. |

## 5. Non-Functional Requirements
- **Performance:** Session turn response < 15s; App startup < 4s.
- **Reliability:** Fallback mechanism (Gemini -> Groq) for LLM reliability.
- **Security:** RLS for data privacy; secure API key management in backend.
- **Usability:** Simple, M3-based UI; rounded, readable typography (Nunito).

## 6. Constraints & Limitations
- Operating on Free Tiers (Supabase, Render, Gemini/Groq).
- Initial model accuracy (~80%) for heavy accents in MVP.
- Offline mode limited to cached content in initial release.
