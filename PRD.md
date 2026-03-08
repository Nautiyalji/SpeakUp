# SpeakUp — Product Requirements Document (PRD)
**Version:** 1.0  
**Product:** SpeakUp — AI Communication Coach & Interview Trainer  
**Author:** Student Developer  
**Status:** Ready for Development  
**Last Updated:** February 2026

---

## 1. Product Vision

### 1.1 Problem Statement

Millions of students in India struggle with English communication, public speaking, and interview preparation — not because they lack intelligence, but because they lack access to a patient, affordable, personalised coach. Traditional coaching is expensive. Language apps like Duolingo don't train spoken confidence. Mock interview platforms are either overly expensive or not tailored to individual company contexts.

**The core problem:** A student who lacks confidence in speaking has no safe, affordable space to practise daily, get honest feedback, and track real improvement.

### 1.2 Product Vision Statement

> SpeakUp is the AI communication coach that every student deserves — patient, personalised, always available, and completely free. It trains you to speak clearly, confidently, and professionally in both Indian English and British English accents, and prepares you for interviews at the exact companies you are targeting.

### 1.3 Success Metrics (Long-Term)

| Metric | Target (6 months post-launch) |
|---|---|
| Daily Active Users (personal use) | 1 (the developer) → grow to study group |
| Session completion rate | > 80% of started sessions are completed |
| 30-day retention | > 60% of users still practising after 30 days |
| Average overall score improvement | > 15 points over first 30 days of use |
| Interview simulation usage | > 40% of users try interview mode within 2 weeks |

---

## 2. Target Users

### 2.1 Primary User — Beginner Student

**Profile:**
- Age: 18–25
- Background: Engineering, BCA, BBA, or any degree student
- English level: Intermediate at reading/writing, poor at speaking
- Confidence: Very low. Afraid of speaking in groups or interviews
- Budget: Zero — cannot afford any paid tools
- Motivation: Wants to crack campus placements or improve communication for daily life

**Key Pain Points:**
- Feels embarrassed when they mispronounce words
- Doesn't know what specifically is wrong with their English
- Has never had access to a personal communication coach
- Nervous even in mock interviews with friends — let alone real ones
- Doesn't know how interviews at big companies like TCS, Infosys, or Google actually work

**How SpeakUp Helps:**
- Gives them a completely private, judgement-free space to practise
- Tells them exactly what is wrong (grammar error here, filler word there) without shame
- Trains them from the very basics with beginner-mode simplicity
- Simulates real company interview environments they couldn't otherwise access

### 2.2 Secondary User — Placement-Season Student

**Profile:**
- 3rd or 4th year engineering student
- Actively applying for jobs
- English communication is okay but interview performance needs work
- Wants company-specific, role-specific interview practice

**Key Pain Points:**
- Doesn't know what Amazon/Google/TCS specifically looks for
- Has no one to conduct realistic multi-round mock interviews
- Gets nervous because they have never experienced a full interview panel
- Cannot afford paid platforms like Interviewing.io or Pramp sessions

---

## 3. User Stories

### 3.1 Authentication & Onboarding

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| US-001 | New user | Register with email and password | I can create my account |
| US-002 | New user | Set my name, target accent, and current level during signup | The app can personalise my experience from day one |
| US-003 | Returning user | Log in and see my dashboard immediately | I can jump straight into my session |
| US-004 | User with multiple devices | Log in on my phone and see the same history I have on my PC | My data follows me everywhere |

### 3.2 Daily Communication Sessions

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| US-010 | Beginner user | Start a session and have the AI speak first, in simple language | I am not overwhelmed and know what to do |
| US-011 | User | Speak freely for up to 60 seconds per turn | I am not rushed while answering |
| US-012 | User | See my words appear on screen as I speak | I know the app is hearing me correctly |
| US-013 | User | Hear the AI coach respond in a warm, natural voice | The session feels like a real conversation |
| US-014 | User | Choose whether the AI judges my accent as Indian English or British English | I can focus on improving the accent that matters to me |
| US-015 | Beginner user | Get very simple exercises like "describe your room in 3 sentences" | I am not overwhelmed with complex tasks |
| US-016 | User | See my grammar score, vocabulary score, confidence score, and fluency score after each turn | I know where I am improving and where I need to work more |
| US-017 | User | End the session at any time | I can stop when I am tired or short on time |
| US-018 | User | See a feedback report after every session | I know exactly what to focus on next time |
| US-019 | User | Use the app even when my internet is off | I never miss a session because of connectivity issues |

### 3.3 Interview Simulation

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| US-030 | User | Upload a job description and company about page | The AI asks me questions specific to that company and role |
| US-031 | User | Configure which interview rounds I want (Introduction, Technical, HR, etc.) | My practice matches the actual interview format |
| US-032 | User | Set 1 to 5 interviewers on the panel | I experience pressure similar to a real panel interview |
| US-033 | User | Hear the AI switch voices between interviewers when there are multiple people | The simulation feels like talking to different real people |
| US-034 | User | See each interviewer's name and designation on screen | I know who is asking the question and can respond appropriately |
| US-035 | User | Upload my own Q&A bank | The AI can test me on specific questions I want to prepare |
| US-036 | User | Get scored on each round | I know which interview rounds I perform well in and which need work |
| US-037 | User | Get a full interview report after completing all rounds | I have a detailed record of how the entire interview went |
| US-038 | User | Adjust interview difficulty (Easy / Medium / Hard) | I can start easy and gradually take on harder challenges |

### 3.4 Progress & Reports

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| US-050 | User | See a chart of my scores over the last 7 days on my dashboard | I can see my improvement at a glance |
| US-051 | User | See a detailed progress chart showing all 4 skill scores over time | I can understand which specific skill is growing the slowest |
| US-052 | User | See my total sessions count and current streak | I feel motivated to keep going every day |
| US-053 | User | View my complete session history with dates and scores | I can look back at how far I have come |
| US-054 | User | Receive an automatically generated weekly summary | I do not have to manually track what happened this week |
| US-055 | User | Download my monthly report as a PDF | I can share my progress with a mentor or keep it for records |

### 3.5 Learning Hub

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| US-060 | User | Access lessons on Indian vs British English accent differences | I understand exactly what I need to change about my pronunciation |
| US-061 | User | Learn 5 new words every day with pronunciation | My vocabulary grows systematically |
| US-062 | User | Ask the AI to explain any communication concept in simple language | I am never stuck on something I do not understand |
| US-063 | User | Read simple grammar guides written for beginners | I can understand the rules without needing complex terminology |

---

## 4. Functional Requirements

### 4.1 FR-AUTH: Authentication

| ID | Requirement | Priority |
|---|---|---|
| FR-AUTH-01 | System SHALL support email + password registration via Supabase Auth | MUST |
| FR-AUTH-02 | System SHALL persist user session (JWT) across app restarts | MUST |
| FR-AUTH-03 | System SHALL create a user profile row on first login with default values | MUST |
| FR-AUTH-04 | System SHALL allow users to update their name, target accent, and level at any time | MUST |
| FR-AUTH-05 | System SHALL provide same data across all logged-in devices within 30 seconds of sync | MUST |

### 4.2 FR-SESSION: Daily Communication Sessions

| ID | Requirement | Priority |
|---|---|---|
| FR-SES-01 | System SHALL record audio from device microphone at 16kHz, mono, WAV format | MUST |
| FR-SES-02 | System SHALL transcribe audio using Whisper within 10 seconds for a 30-second audio clip | MUST |
| FR-SES-03 | System SHALL compute grammar score using language_tool_python | MUST |
| FR-SES-04 | System SHALL compute vocabulary richness score using NLTK type-token ratio | MUST |
| FR-SES-05 | System SHALL compute confidence score based on WPM, filler word count, and pause count | MUST |
| FR-SES-06 | System SHALL compute fluency score based on sentence completion rate and speaking pace | MUST |
| FR-SES-07 | System SHALL generate an AI coaching response using Gemini 1.5 Flash as primary LLM | MUST |
| FR-SES-08 | System SHALL fall back to Groq (Llama 3.1 70B) if Gemini returns an error or rate limit | MUST |
| FR-SES-09 | System SHALL synthesise AI response to audio using Coqui TTS | MUST |
| FR-SES-10 | System SHALL use simplified language in all AI responses when user level is "beginner" | MUST |
| FR-SES-11 | System SHALL save completed session data to Supabase with all scores | MUST |
| FR-SES-12 | System SHALL generate a post-session feedback report with strengths, improvements, and daily exercises | MUST |
| FR-SES-13 | System SHALL update the user's daily streak on session completion | MUST |
| FR-SES-14 | System SHALL upsert today's progress snapshot with session scores | MUST |
| FR-SES-15 | System SHALL function in offline mode using local Whisper + Coqui with cached exercises | SHOULD |

### 4.3 FR-INTERVIEW: Interview Simulation

| ID | Requirement | Priority |
|---|---|---|
| FR-INT-01 | System SHALL allow users to configure interview rounds (add, remove, reorder) | MUST |
| FR-INT-02 | System SHALL allow users to set panel size from 1 to 5 interviewers | MUST |
| FR-INT-03 | System SHALL auto-generate panelist names, designations, and personalities using LLM based on company and role context | MUST |
| FR-INT-04 | System SHALL assign a unique TTS voice to each panelist | MUST |
| FR-INT-05 | System SHALL automatically switch TTS voice when the active panelist changes | MUST |
| FR-INT-06 | System SHALL accept document uploads (PDF, DOCX, TXT) for JD and company context | MUST |
| FR-INT-07 | System SHALL embed uploaded documents using sentence-transformers and store in ChromaDB | MUST |
| FR-INT-08 | System SHALL retrieve relevant context chunks before generating each interview question | MUST |
| FR-INT-09 | System SHALL evaluate user answers on: relevance, depth, communication quality, and completeness | MUST |
| FR-INT-10 | System SHALL generate a per-round scorecard and an overall interview report | MUST |
| FR-INT-11 | System SHALL support preset round types: Introduction, Technical, Managerial, HR, Final | MUST |
| FR-INT-12 | System SHALL allow users to create custom round types with custom names | SHOULD |
| FR-INT-13 | System SHALL support difficulty levels: Easy, Medium, Hard | MUST |

### 4.4 FR-PROGRESS: Progress Tracking

| ID | Requirement | Priority |
|---|---|---|
| FR-PRO-01 | System SHALL display last 7 days of daily scores as a line chart | MUST |
| FR-PRO-02 | System SHALL display a list of past sessions with date and overall score | MUST |
| FR-PRO-03 | System SHALL display current daily streak count | MUST |
| FR-PRO-04 | System SHALL generate weekly progress summary text via LLM | SHOULD |
| FR-PRO-05 | System SHALL generate monthly PDF report using ReportLab | SHOULD |
| FR-PRO-06 | System SHALL allow users to download reports as PDF | SHOULD |

### 4.5 FR-LEARNING: Learning Hub

| ID | Requirement | Priority |
|---|---|---|
| FR-LEARN-01 | System SHALL provide accent comparison lessons (Indian English vs British English) | SHOULD |
| FR-LEARN-02 | System SHALL provide a daily word of the day with definition, example, and pronunciation | SHOULD |
| FR-LEARN-03 | System SHALL allow users to ask AI to explain any concept in simple terms | COULD |
| FR-LEARN-04 | System SHALL allow users to bookmark lessons for later review | COULD |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement | Target |
|---|---|---|
| NFR-PERF-01 | Session turn response time (audio → scores + AI voice) | < 15 seconds |
| NFR-PERF-02 | App startup time to dashboard | < 4 seconds |
| NFR-PERF-03 | Progress chart load time | < 3 seconds |
| NFR-PERF-04 | Document embedding time (after upload) | < 30 seconds in background |
| NFR-PERF-05 | Cross-device sync latency | < 30 seconds |

### 5.2 Reliability

| ID | Requirement |
|---|---|
| NFR-REL-01 | LLM fallback system (Gemini → Groq) must activate within 5 seconds of primary failure |
| NFR-REL-02 | App must not crash if Supabase is temporarily unreachable — show error, allow retry |
| NFR-REL-03 | Audio recording must request microphone permission before first session, not mid-session |
| NFR-REL-04 | All API errors must be caught and shown to user as friendly error messages (no raw error codes) |

### 5.3 Usability

| ID | Requirement |
|---|---|
| NFR-USE-01 | All text in the app must be understandable by a 16-year-old with basic English knowledge |
| NFR-USE-02 | The recording button must be the largest, most prominent element on the session screen |
| NFR-USE-03 | Every score displayed must have a brief label explaining what it means |
| NFR-USE-04 | The app must support both dark mode and light mode |
| NFR-USE-05 | App must work without a tutorial — the first session should be self-explanatory |

### 5.4 Security

| ID | Requirement |
|---|---|
| NFR-SEC-01 | API keys (Gemini, Groq) must be stored only in backend environment variables, never in frontend code |
| NFR-SEC-02 | All FastAPI endpoints must validate Supabase JWT before processing any request |
| NFR-SEC-03 | Supabase Row Level Security must prevent any user from reading another user's data |
| NFR-SEC-04 | Audio bytes must be processed in-memory and never written to backend disk |
| NFR-SEC-05 | User transcripts must not be logged to console in production |

### 5.5 Compatibility

| ID | Requirement |
|---|---|
| NFR-COM-01 | Mobile: Android 8.0+ |
| NFR-COM-02 | Web: Chrome 100+, Firefox 100+, Edge 100+ |
| NFR-COM-03 | Desktop: Windows 10+ |
| NFR-COM-04 | Backend: Python 3.11+ on Linux (Render.com) |

### 5.6 Cost

| ID | Requirement |
|---|---|
| NFR-COST-01 | Total monthly operating cost for single-user personal use: $0 |
| NFR-COST-02 | All AI, STT, and TTS must function on free tiers or local open-source models |
| NFR-COST-03 | Database, auth, and storage must use Supabase free tier |
| NFR-COST-04 | Hosting must use Render.com or Railway.app free tier |

---

## 6. Feature Prioritisation (MoSCoW)

### MUST HAVE (MVP — Build First)
- Email auth + cross-device login
- Profile setup (name, accent, level)
- Daily voice session with AI coach
- Whisper STT
- Coqui TTS (AI voice response)
- Grammar scoring
- Vocabulary scoring
- Confidence scoring
- Fluency scoring
- Post-session feedback report
- Progress dashboard (7-day chart)
- Session history list
- Daily streak counter
- Beginner mode (simplified AI language)
- Offline mode (local STT/TTS + cached exercises)

### SHOULD HAVE (Phase 2 — After MVP)
- Interview simulation (single panelist)
- Multi-round interview (custom rounds)
- Document upload + RAG context
- Multi-panelist interview with voice switching
- Accent scoring (SpeechBrain-based)
- Weekly progress summary
- Streak calendar heatmap

### COULD HAVE (Phase 3 — Nice to Have)
- Monthly PDF report download
- Annual report
- Learning Hub (accent lessons + grammar guides)
- Daily vocabulary word + quiz
- AI Explain Mode (explain anything simply)
- Achievement badges and milestones
- Share progress on WhatsApp/email

### WON'T HAVE (Out of Scope)
- Social features (leaderboards, friend comparison)
- Live video interview simulation
- Real-time AI lip sync / avatar
- Integration with LinkedIn or job portals
- Paid coaching marketplace
- Group session / classroom mode

---

## 7. User Interface Requirements

### 7.1 Design Principles

- **Simplicity First:** Every screen has ONE primary action. The user never needs to think about what to do next.
- **Encouraging Tone:** All text is positive, warm, and motivating. Never alarming or critical in a harsh way.
- **Progress Visibility:** The user's score trajectory should be visible within 2 taps from any screen.
- **Beginner-Friendly:** Icons + labels everywhere. No icon-only navigation.

### 7.2 Key Screen Requirements

**Login / Signup Screen:**
- Clean, single-column form
- Google sign-in option (Supabase supports this out of the box)
- "New to SpeakUp? Sign up" toggle
- No complex onboarding flow — get to dashboard fast

**Home Dashboard:**
- User's first name in greeting ("Good morning, Rahul!")
- Streak prominently displayed with fire emoji
- Last session's 4 scores as circular progress indicators
- Two large action buttons: "Start Session" and "Start Interview Prep"
- Bottom navigation bar with 5 tabs: Home, Session, Interview, Progress, Learn

**Daily Session Screen:**
- Current prompt/exercise from AI displayed at top in a bubble
- Centre: Large circular microphone button (64dp minimum)
- Microphone animates (pulse/glow) when recording
- Live transcript appears below recording button, updating in real-time
- 4 small score badges update after each turn
- "Play Again" button next to AI response (re-plays AI audio)
- "End Session" button at bottom, with confirmation dialog

**Session Feedback Screen:**
- Green headline: "[Encouraging sentence]"
- Two sections: "What you did well" and "What to work on"
- 3 daily exercises listed clearly
- Motivational message
- "View Progress" and "Start Another Session" buttons

**Interview Setup Screen:**
- Step-by-step wizard (5 steps, progress bar at top)
- Step indicators are labelled (not just numbered dots)
- Document upload area: drag and drop or tap to upload
- Panel size: interactive slider with live preview of panelist count
- Preview screen before starting: shows panelist cards generated by AI

**Progress Screen:**
- Period selector pill: 7 Days | 30 Days | 12 Months
- fl_chart line chart, colour-coded per skill (4 lines)
- Skill cards below chart: score + trend arrow + delta
- Scrollable session history at bottom

### 7.3 Colour Palette

```
Primary Blue:    #1A56A0   (brand colour, main CTA buttons)
Accent Blue:     #2563EB   (links, highlights, chart accent line)
Dark BG:         #0F172A   (dark mode background)
Dark Surface:    #1E293B   (dark mode card/panel background)
Light BG:        #F8FAFC   (light mode background)
Light Surface:   #FFFFFF   (light mode cards)
Success Green:   #16A34A   (positive scores, streaks, "Good" badges)
Warning Orange:  #D97706   (medium scores, "Needs Work" badges)
Error Red:       #DC2626   (very low scores, grammar errors highlighted)
Text Primary:    #0F172A   (dark mode: #F8FAFC)
Text Secondary:  #64748B   (labels, subtitles)
```

### 7.4 Typography

```
Font Family: Nunito (Google Fonts)
  — Warm, rounded, highly legible — perfect for an educational / coaching app
  — Available on all Flutter platforms via google_fonts package

Heading Large:  Nunito Bold 28sp     — Screen titles
Heading Medium: Nunito Bold 22sp     — Section titles
Body Large:     Nunito Regular 16sp  — Main content text
Body Small:     Nunito Regular 14sp  — Labels, subtitles
Score Number:   Nunito Bold 36sp     — Score displays (big, prominent)
Caption:        Nunito Regular 12sp  — Timestamps, footnotes
```

---

## 8. Out of Scope (Confirmed Exclusions)

The following are confirmed NOT to be built in this version and should not appear in any sprint planning:

- Video recording or video analysis
- Real-time facial expression analysis
- WhatsApp integration
- School/college institution accounts
- Teacher/mentor dashboard to monitor students
- In-app purchase or subscription features
- Advertising or monetisation of any kind
- Account deletion with data export (can be added later)
- Multi-language support beyond English

---

## 9. Dependencies & Risks

### 9.1 External Dependencies

| Dependency | Type | Risk | Mitigation |
|---|---|---|---|
| Google Gemini API free tier | Critical | Rate limit changes or quota reduction | Groq fallback always active |
| Supabase free tier (500MB) | Critical | Storage limit hit over time | Archive old session data to Supabase Storage as JSON files |
| Render.com free tier | High | Cold start 50-second delay | Pre-warm endpoint via scheduled ping |
| OpenAI Whisper (open-source) | Medium | Model may update/change | Pin to specific release: `openai-whisper==20231117` |
| Coqui TTS (open-source) | Medium | Project maintenance risk | Pin version. Self-host model files if needed |
| Groq API free tier | Low | Secondary LLM — only used as fallback | Acceptable if occasionally unavailable |

### 9.2 Technical Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Whisper STT accuracy is too low for heavy Indian accents | Medium | High | Upgrade to 'small' model if accuracy < 70% in testing |
| Coqui TTS voice quality is too robotic | Medium | Medium | Test XTTS-v2 model as alternative after MVP |
| Render.com free tier is too slow | High | Medium | Pre-warm with UptimeRobot free ping. Accept cold start as known limitation |
| Supabase 500MB limit hit | Low (personal use) | High | Monitor usage. Archive old transcripts (largest data) to storage bucket |
| Language_tool_python is too slow on first load | Medium | Low | Load at startup. Accept 5-8 second startup penalty |

---

## 10. Definition of Done

A feature is considered DONE when:

1. The code is committed to the main branch
2. The feature works end-to-end on at least one Android device and the web browser
3. All error states are handled (no unhandled exceptions in the logs)
4. The feature works the same way after a fresh login (no state corruption)
5. Data written during the feature is visible in the Supabase dashboard
6. The feature is manually tested by the developer in both dark and light mode

---

## 11. Glossary

| Term | Definition |
|---|---|
| STT | Speech-to-Text. Converting voice audio to a text transcript |
| TTS | Text-to-Speech. Converting text to synthesised audio |
| LLM | Large Language Model. The AI model (Gemini/Groq) that generates coaching and interview responses |
| RAG | Retrieval-Augmented Generation. Using uploaded documents to give the AI relevant company context when generating questions |
| WPM | Words Per Minute. A measure of speaking speed |
| TTR | Type-Token Ratio. A vocabulary richness metric: unique words / total words |
| Filler Words | Words like "um", "uh", "like" that are spoken unconsciously and reduce speech clarity |
| RLS | Row Level Security. A Supabase/PostgreSQL feature ensuring users only access their own data |
| JWT | JSON Web Token. The auth token used to verify user identity in API calls |
| Cold Start | When a server (Render.com free tier) wakes up from sleep — causes a one-time delay of ~50 seconds |
| Panelist | A simulated interviewer in the interview simulation module |
| ChromaDB | A local vector database used to store document embeddings for semantic search |
| Embedding | A numerical representation of text that allows semantic similarity comparison |

---

*Product Requirements Document — SpeakUp v1.0*
