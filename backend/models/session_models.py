"""
Pydantic schemas for Session endpoints.
"""
from pydantic import BaseModel
from typing import Literal
from datetime import datetime


# ── Request Models ─────────────────────────────────────────────────────────────

class SessionStartRequest(BaseModel):
    user_id: str
    target_accent: Literal["Indian English", "British English"] = "Indian English"
    level: Literal["beginner", "intermediate", "advanced"] = "beginner"


class TurnRequest(BaseModel):
    session_id: str
    user_id: str
    audio_base64: str       # WAV bytes encoded as Base64
    turn_number: int = 1


class EndSessionRequest(BaseModel):
    session_id: str
    user_id: str


# ── Response Models ────────────────────────────────────────────────────────────

class GrammarError(BaseModel):
    message: str
    bad_text: str
    suggestion: str
    category: str


class AICoachResponse(BaseModel):
    response_text: str
    praise: str
    tip: str
    exercise: str


class TurnResponse(BaseModel):
    transcript: str
    grammar_score: float
    vocabulary_score: float
    confidence_score: float
    fluency_score: float
    wpm: int
    filler_count: int
    pause_count: int
    grammar_errors: list[GrammarError]
    ai_response: AICoachResponse
    ai_audio_base64: str    # Coqui TTS audio as Base64


class SessionFeedback(BaseModel):
    headline: str
    strengths: list[str]
    improvements: list[str]
    daily_exercises: list[str]
    motivational_message: str
    next_session_focus: str


class FinalScores(BaseModel):
    grammar: float
    vocabulary: float
    confidence: float
    fluency: float
    overall: float


class EndSessionResponse(BaseModel):
    final_scores: FinalScores
    feedback: SessionFeedback


class SessionStartResponse(BaseModel):
    session_id: str
    greeting: str
    greeting_audio: str     # Base64 WAV
    first_exercise: str
