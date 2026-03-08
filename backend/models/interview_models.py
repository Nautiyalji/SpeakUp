"""
Pydantic models for Interview (Phase 2) API endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional


# ── Setup ──────────────────────────────────────────────────────────────────────

class InterviewSetupRequest(BaseModel):
    user_id: str
    company: str = Field(..., min_length=1, max_length=100)
    role: str = Field(..., min_length=1, max_length=100)
    jd_text: Optional[str] = Field(None, description="Raw job description text")
    panelist_count: int = Field(default=2, ge=1, le=3)
    round_types: list[str] = Field(
        default=["hr", "technical"],
        description="Ordered list of round types: hr | technical | case_study",
    )


class PanelistConfig(BaseModel):
    id: str
    name: str
    archetype: str
    title: str
    emoji: str
    personality: str
    fun_fact: str


class InterviewSetupResponse(BaseModel):
    interview_id: str
    company: str
    role: str
    panel: list[PanelistConfig]
    round_types: list[str]
    total_rounds: int


# ── Start Round ────────────────────────────────────────────────────────────────

class InterviewStartRequest(BaseModel):
    interview_id: str
    user_id: str
    round_number: int = Field(default=1, ge=1)


class InterviewStartResponse(BaseModel):
    interview_id: str
    round_number: int
    round_type: str
    active_panelist: PanelistConfig
    opening_question: str
    opening_audio_base64: Optional[str] = None
    questions_per_round: int = 4


# ── Turn ───────────────────────────────────────────────────────────────────────

class InterviewTurnRequest(BaseModel):
    interview_id: str
    user_id: str
    round_number: int
    question_number: int
    panelist_id: str
    audio_base64: str


class PanelistEvaluation(BaseModel):
    relevance_score: float
    depth_score: float
    clarity_score: float
    star_coverage: str  # none | partial | complete
    reaction: str
    follow_up: str
    internal_note: str


class InterviewTurnResponse(BaseModel):
    transcript: str
    grammar_score: float
    vocabulary_score: float
    fluency_score: float
    confidence_score: float
    wpm: int
    panelist_evaluation: PanelistEvaluation
    next_question: str
    next_audio_base64: Optional[str] = None
    round_complete: bool = False


# ── End / Report ───────────────────────────────────────────────────────────────

class InterviewEndRequest(BaseModel):
    interview_id: str
    user_id: str


class CompetencyScores(BaseModel):
    communication: float
    technical: float
    culture_fit: float
    leadership: float


class PanelistSummary(BaseModel):
    panelist_name: str
    score: float
    note: str


class InterviewReportResponse(BaseModel):
    interview_id: str
    company: str
    role: str
    overall_score: float
    recommendation: str   # Strong Yes | Yes | Maybe | No
    recommendation_reason: str
    strengths: list[str]
    gaps: list[str]
    competency_scores: CompetencyScores
    panelist_summaries: list[PanelistSummary]
