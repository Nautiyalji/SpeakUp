# 03 - Information Architecture

## 1. System Navigation Map (Site Map)
The app structure is designed for "One Action per Screen" simplicity.

- **Root (Auth Guard)**
  - `/login`: Email Login / Google Sign-in toggle
  - `/signup`: Email Registration
- **Shell (Main Navigation)**
  - `/home`: Dashboard (Greeting, Streak, Quick Actions)
  - `/session`: Daily Voice Coach
    - `/session/active`: Recording UI
    - `/session/feedback`: Reporting & Scoring Dashboard
  - `/interview`: Interview Launcher (Phase 2)
    - `/interview/setup`: Wizard for JD Upload/Panel Settings
    - `/interview/active`: Multi-panelist session
    - `/interview/report`: Detailed interview analysis
  - `/progress`: Historical Charts (7d, 30d, 12m)
  - `/profile`: User Settings (Accent, Level, Display Name)

## 2. Information Flow
### User Onboarding Flow
`Splash -> Login/Signup -> Dashboard (Home)`
### Core Coaching Loop
`Home -> Start Session -> Record Audio -> Receive AI Feedback -> View Session Report -> Return Home`

## 3. Data Entities
- **Profile:** User metadata (identity, preferences, streak).
- **Communication Session:** A single instance of a coaching conversation.
- **Turn:** A single exchange (User Audio/Text -> AI Analysis -> AI Response).
- **Score Snapshot:** Daily aggregated performance metrics for charting.
- **Interview Setup:** Configuration for simulation (Company, Role, JD).

## 4. UI/UX Hierarchy
- **Primary Action (CTA):** Prominent circular recording button.
- **Feedback Layer:** Micro-interactions (glow/pulse) during audio processing.
- **Visual Evidence:** Cards and circular progress bars for score transparency.
