# 02 - User Stories & Acceptance Criteria

## 1. Authentication & Profile
### US-001: User Registration
**As a** new user, **I want to** register with my email and password **so that** I can create a persistent account.
- **AC 1:** System accepts valid email formats.
- **AC 2:** Password requires standard security complexity.
- **AC 3:** Profile record is automatically created in Supabase upon successful sign-up.

### US-002: Personalization
**As a** user, **I want to** set my target accent and level **so that** the coaching is tailored to my needs.
- **AC 1:** User can select between 'Indian English' and 'British English'.
- **AC 2:** System adjusts AI prompt complexity based on 'Beginner', 'Intermediate', or 'Advanced' level.

## 2. Daily Communication Sessions
### US-010: AI-Led Coaching
**As a** beginner, **I want** the AI to speak first in simple language **so that** I feel comfortable starting.
- **AC 1:** AI uses simplified vocabulary for beginner level.
- **AC 2:** Audio playback starts automatically on AI turn.

### US-016: Real-time Feedback
**As a** user, **I want to** see my scores (Grammar, Vocab, etc.) after each turn **so that** I can monitor my performance.
- **AC 1:** Scores update within 15 seconds of speaking.
- **AC 2:** Each score badge reflects the turn-specific analysis.

## 3. Interview Simulation (Phase 2)
### US-030: Company Context
**As a** candidate, **I want to** upload a JD **so that** the interview questions are relevant.
- **AC 1:** System extracts text from PDF/DOCX.
- **AC 2:** AI generates questions based on retrieved JD context (RAG).

## 4. Progress Tracking
### US-050: Visual Dashboard
**As a** user, **I want to** see a line chart of my progress **so that** I can track my growth over time.
- **AC 1:** Dashboard shows last 7 days of scores.
- **AC 2:** Different skills (Grammar, Fluency, etc.) have distinct line colors.
