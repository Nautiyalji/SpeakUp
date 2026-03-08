"""
SpeakUp — FastAPI Backend Entry Point
"""
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

load_dotenv()

IS_CLOUD = os.getenv("DEPLOY_PLATFORM") == "cloud"

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: pre-load ML models (skipped in cloud mode)."""
    if IS_CLOUD:
        print("[SpeakUp] Running in Cloud Mode — skipping heavy model pre-load.")
        yield
        return

    print("[SpeakUp] Starting up — pre-loading local ML models...")
    loop = asyncio.get_event_loop()
    # ... (existing loading logic for local development)

    print("[SpeakUp] Server is accepting requests.")
    yield
    print("[SpeakUp] Shutting down.")


app = FastAPI(
    title="SpeakUp API",
    description="AI Communication Coach & Interview Trainer Backend",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────────────────────
origins = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "http://localhost:3000",
    "https://speak-up-ochre.vercel.app",  # Production Vercel URL
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Optional: Also allow everything without credentials if the above fails for some reason
# (Many developers use "*" during prototyping, but browser security is getting stricter)
# app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── Routers ───────────────────────────────────────────────────────────────────
from routers import auth, sessions, progress, interview
app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(sessions.router, prefix="/sessions", tags=["Sessions"])
app.include_router(progress.router, prefix="/progress", tags=["Progress"])
app.include_router(interview.router, prefix="/interview", tags=["Interview"])


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "SpeakUp API v1.0"}
