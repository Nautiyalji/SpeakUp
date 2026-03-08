# 11 - Environment & DevOps

## 1. Development Environments
### Local Machine
- **Backend:** Python 3.11+ Venv.
- **Frontend:** Flutter SDK (Stable).
- **Mocking:** Local `.env` for development keys.

## 2. CI/CD Pipeline
- **Source Control:** GitHub (Gitflow: `main`, `develop`, `feature/*`).
- **Automation:** 
  - GitHub Actions for Linting (Python Black, Flutter Analyze).
  - Auto-deployment to Render.com on `main` branch merging.

## 3. Hosting & Infrastructure
| Service | Role | Tier |
|---|---|---|
| **Render.com** | Backend API (FastAPI) | Free |
| **Supabase** | DB, Auth, Realtime, Storage | Free (500MB) |
| **Vercel** | Flutter Web Hosting | Free |
| **GitHub** | Version Control & Actions | Free |

## 4. Monitoring & Pre-warming
- **UptimeRobot:** Pings the Render backend every 15 minutes to prevent instance sleep (minimizing cold starts).
- **Supabase Dashboard:** Monitoring table size and API invocation counts.

## 5. Deployment Checklist
1. Environment variables set on Render dashboard.
2. Supabase SQL migrations applied to production.
3. Flutter release build generated (APK/Web).
4. Verify cross-device login on prod URL.
