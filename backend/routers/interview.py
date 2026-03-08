"""
Interview router — Phase 2: Mock Interview Simulation
POST /interview/setup   → Upload JD, configure panel, get interview_id + panel
POST /interview/start   → Start a round, get first panelist question
POST /interview/turn    → Submit audio answer → transcribe → score → panelist response
POST /interview/end     → Generate full interview report
"""
import uuid
from fastapi import APIRouter, HTTPException, Header, BackgroundTasks

from models.interview_models import (
    InterviewSetupRequest, InterviewSetupResponse, PanelistConfig,
    InterviewStartRequest, InterviewStartResponse,
    InterviewTurnRequest, InterviewTurnResponse, PanelistEvaluation,
    InterviewEndRequest, InterviewReportResponse,
    CompetencyScores, PanelistSummary,
)
from utils.supabase_client import get_supabase, verify_jwt
from utils.audio_utils import base64_to_bytes, bytes_to_base64
from services import whisper_service, tts_service
from services.analysis_service import analyse_audio_and_text
from services.grammar_service import check_grammar
from services.rag_service import index_jd
from services.interview_llm_service import (
    generate_panel, generate_question, evaluate_answer, generate_report
)

router = APIRouter()
QUESTIONS_PER_ROUND = 4


def _auth(authorization: str) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header.")
    token = authorization.split("Bearer ")[1]
    try:
        return verify_jwt(token)["id"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


# ── POST /interview/setup ──────────────────────────────────────────────────────

@router.post("/setup", response_model=InterviewSetupResponse)
async def setup_interview(
    body: InterviewSetupRequest,
    authorization: str = Header(...),
):
    """
    1. Generate AI panelists based on round types.
    2. Index the JD into ChromaDB for RAG retrieval.
    3. Store interview config in Supabase.
    """
    uid = _auth(authorization)
    if uid != body.user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    interview_id = str(uuid.uuid4())

    # Generate panelists
    panel_raw = await generate_panel(
        company=body.company,
        role=body.role,
        panelist_count=body.panelist_count,
        round_types=body.round_types,
    )

    # Index JD asynchronously (non-blocking if no JD provided)
    jd_chunks = 0
    if body.jd_text and body.jd_text.strip():
        try:
            jd_chunks = await index_jd(body.jd_text, interview_id)
        except Exception as e:
            print(f"[Interview] JD indexing error (non-fatal): {e}")

    panel_config = {
        "panelists": panel_raw,
        "round_types": body.round_types,
        "panelist_count": body.panelist_count,
    }

    # Persist to Supabase
    db = get_supabase()
    db.table("interview_sessions").insert({
        "id": interview_id,
        "user_id": body.user_id,
        "company": body.company,
        "role": body.role,
        "panel_config": panel_config,
        "jd_chunk_count": jd_chunks,
        "status": "setup",
    }).execute()

    panelists = [PanelistConfig(**p) for p in panel_raw]
    return InterviewSetupResponse(
        interview_id=interview_id,
        company=body.company,
        role=body.role,
        panel=panelists,
        round_types=body.round_types,
        total_rounds=len(body.round_types),
    )


# ── POST /interview/start ──────────────────────────────────────────────────────

@router.post("/start", response_model=InterviewStartResponse)
async def start_interview_round(
    body: InterviewStartRequest,
    authorization: str = Header(...),
):
    """
    Start a round and generate the first question from the active panelist.
    """
    uid = _auth(authorization)
    db = get_supabase()

    interview = db.table("interview_sessions").select("*").eq(
        "id", body.interview_id
    ).single().execute()

    if not interview.data:
        raise HTTPException(status_code=404, detail="Interview not found.")

    iv = interview.data
    if iv["user_id"] != uid:
        raise HTTPException(status_code=403, detail="Forbidden.")

    panel_config = iv["panel_config"]
    panelists = panel_config["panelists"]
    round_types = panel_config["round_types"]

    round_index = body.round_number - 1
    if round_index >= len(round_types):
        raise HTTPException(status_code=400, detail="Round number exceeds configured rounds.")

    # Round-robin assignment: each round gets a different panelist
    panelist_index = round_index % len(panelists)
    active_panelist = panelists[panelist_index]
    round_type = round_types[round_index]

    # Generate opening question
    opening_q = await generate_question(
        panelist=active_panelist,
        company=iv["company"],
        role=iv["role"],
        round_type=round_type,
        interview_id=body.interview_id,
        question_number=1,
    )

    # Synthesize question to audio
    try:
        audio_bytes = await tts_service.synthesize(opening_q, voice="coach_male")
        audio_b64 = bytes_to_base64(audio_bytes)
    except Exception:
        audio_b64 = None

    # Update session status
    db.table("interview_sessions").update({
        "status": f"round_{body.round_number}_active",
        "current_round": body.round_number,
    }).eq("id", body.interview_id).execute()

    return InterviewStartResponse(
        interview_id=body.interview_id,
        round_number=body.round_number,
        round_type=round_type,
        active_panelist=PanelistConfig(**active_panelist),
        opening_question=opening_q,
        opening_audio_base64=audio_b64,
        questions_per_round=QUESTIONS_PER_ROUND,
    )


# ── POST /interview/turn ───────────────────────────────────────────────────────

@router.post("/turn", response_model=InterviewTurnResponse)
async def interview_turn(
    body: InterviewTurnRequest,
    background_tasks: BackgroundTasks,
    authorization: str = Header(...),
):
    """
    Full pipeline for one interview turn:
    Audio → Whisper → Analysis → Grammar → Panelist Evaluation → Next Question → TTS
    """
    uid = _auth(authorization)
    db = get_supabase()

    interview = db.table("interview_sessions").select("*").eq(
        "id", body.interview_id
    ).single().execute()

    if not interview.data:
        raise HTTPException(status_code=404, detail="Interview not found.")

    iv = interview.data
    if iv["user_id"] != uid:
        raise HTTPException(status_code=403, detail="Forbidden.")

    panel_config = iv["panel_config"]
    panelists = panel_config["panelists"]
    round_types = panel_config["round_types"]
    round_index = body.round_number - 1
    round_type = round_types[min(round_index, len(round_types) - 1)]
    panelist_index = round_index % len(panelists)

    # Find active panelist
    active_panelist = None
    for p in panelists:
        if p["id"] == body.panelist_id:
            active_panelist = p
            break
    if not active_panelist:
        active_panelist = panelists[panelist_index]

    # 1. Decode audio
    try:
        audio_bytes = base64_to_bytes(body.audio_base64)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Base64 audio.")

    # 2. Transcribe
    whisper_result = await whisper_service.transcribe_audio(audio_bytes)
    transcript = whisper_result["text"].strip()
    if not transcript:
        raise HTTPException(status_code=422, detail="No speech detected.")

    # 3. Acoustic + Text Analysis
    try:
        analysis = analyse_audio_and_text(audio_bytes, transcript)
    except Exception as e:
        print(f"[Interview] Analysis error: {e}")
        analysis = {
            "wpm": 0, "filler_count": 0, "pause_count": 0,
            "confidence_score": 50.0, "fluency_score": 50.0, "vocabulary_score": 50.0,
        }

    # 4. Grammar
    grammar_result = check_grammar(transcript)

    # 5. Panelist evaluates the answer
    # We need the question that was asked — retrieve last turn from DB
    last_turn = db.table("interview_turns").select("question").eq(
        "interview_id", body.interview_id
    ).eq("round_number", body.round_number).order(
        "question_number", desc=True
    ).limit(1).execute()

    previous_question = last_turn.data[0]["question"] if last_turn.data else ""

    evaluation = await evaluate_answer(
        question=previous_question,
        answer=transcript,
        panelist=active_panelist,
        company=iv["company"],
        role=iv["role"],
        round_type=round_type,
        interview_id=body.interview_id,
    )

    # 6. Determine if round is complete
    round_complete = body.question_number >= QUESTIONS_PER_ROUND

    # 7. Generate next question (or closing remark)
    if not round_complete:
        follow_up = evaluation.get("follow_up", "")
        if follow_up:
            next_q = follow_up
        else:
            next_q = await generate_question(
                panelist=active_panelist,
                company=iv["company"],
                role=iv["role"],
                round_type=round_type,
                interview_id=body.interview_id,
                question_number=body.question_number + 1,
                previous_answer=transcript,
            )
    else:
        panelist_name = active_panelist.get("name", "Interviewer")
        next_q = (
            f"Thank you for your responses in this round. "
            f"That's all from me, {panelist_name}. "
            "You've done well. Best of luck with the rest of the interview!"
        )

    # 8. Synthesize next question/closing to audio
    try:
        next_audio_bytes = await tts_service.synthesize(next_q, voice="coach_male")
        next_audio_b64 = bytes_to_base64(next_audio_bytes)
    except Exception:
        next_audio_b64 = None

    # 9. Save turn in background
    background_tasks.add_task(
        _save_interview_turn,
        interview_id=body.interview_id,
        round_number=body.round_number,
        question_number=body.question_number,
        panelist_id=body.panelist_id,
        question=previous_question,
        transcript=transcript,
        evaluation=evaluation,
        scores={
            "grammar": grammar_result["grammar_score"],
            "vocabulary": analysis["vocabulary_score"],
            "confidence": analysis["confidence_score"],
            "fluency": analysis["fluency_score"],
        },
    )

    return InterviewTurnResponse(
        transcript=transcript,
        grammar_score=grammar_result["grammar_score"],
        vocabulary_score=analysis["vocabulary_score"],
        fluency_score=analysis["fluency_score"],
        confidence_score=analysis["confidence_score"],
        wpm=analysis.get("wpm", 0),
        panelist_evaluation=PanelistEvaluation(
            relevance_score=evaluation.get("relevance_score", 70),
            depth_score=evaluation.get("depth_score", 70),
            clarity_score=evaluation.get("clarity_score", 70),
            star_coverage=evaluation.get("star_coverage", "partial"),
            reaction=evaluation.get("reaction", ""),
            follow_up=evaluation.get("follow_up", ""),
            internal_note=evaluation.get("internal_note", ""),
        ),
        next_question=next_q,
        next_audio_base64=next_audio_b64,
        round_complete=round_complete,
    )


def _save_interview_turn(
    interview_id: str, round_number: int, question_number: int,
    panelist_id: str, question: str, transcript: str,
    evaluation: dict, scores: dict,
):
    try:
        db = get_supabase()
        db.table("interview_turns").insert({
            "interview_id": interview_id,
            "round_number": round_number,
            "question_number": question_number,
            "panelist_id": panelist_id,
            "question": question,
            "transcript": transcript,
            "relevance_score": scores.get("grammar"),
            "depth_score": evaluation.get("depth_score"),
            "clarity_score": evaluation.get("clarity_score"),
            "star_coverage": evaluation.get("star_coverage"),
            "grammar_score": scores.get("grammar"),
            "fluency_score": scores.get("fluency"),
            "confidence_score": scores.get("confidence"),
            "internal_note": evaluation.get("internal_note", ""),
        }).execute()
    except Exception as e:
        print(f"[Interview] Turn save error: {e}")


# ── POST /interview/end ────────────────────────────────────────────────────────

@router.post("/end", response_model=InterviewReportResponse)
async def end_interview(
    body: InterviewEndRequest,
    authorization: str = Header(...),
):
    """
    Generate the full interview report from all turns.
    """
    uid = _auth(authorization)
    db = get_supabase()

    interview = db.table("interview_sessions").select("*").eq(
        "id", body.interview_id
    ).single().execute()

    if not interview.data:
        raise HTTPException(status_code=404, detail="Interview not found.")

    iv = interview.data
    if iv["user_id"] != uid:
        raise HTTPException(status_code=403, detail="Forbidden.")

    # Fetch all turns
    turns = db.table("interview_turns").select("*").eq(
        "interview_id", body.interview_id
    ).order("round_number, question_number").execute()

    panel_config = iv["panel_config"]

    # Generate AI report
    report = await generate_report(
        company=iv["company"],
        role=iv["role"],
        panel=panel_config["panelists"],
        turns=turns.data or [],
    )

    # Save report
    db.table("interview_sessions").update({
        "status": "completed",
        "report": report,
    }).eq("id", body.interview_id).execute()

    competency = report.get("competency_scores", {})
    panelist_summaries = [
        PanelistSummary(
            panelist_name=ps.get("panelist_name", ""),
            score=ps.get("score", 70),
            note=ps.get("note", ""),
        )
        for ps in report.get("panelist_summaries", [])
    ]

    return InterviewReportResponse(
        interview_id=body.interview_id,
        company=iv["company"],
        role=iv["role"],
        overall_score=report.get("overall_score", 70),
        recommendation=report.get("recommendation", "Maybe"),
        recommendation_reason=report.get("recommendation_reason", ""),
        strengths=report.get("strengths", []),
        gaps=report.get("gaps", []),
        competency_scores=CompetencyScores(
            communication=competency.get("communication", 70),
            technical=competency.get("technical", 70),
            culture_fit=competency.get("culture_fit", 70),
            leadership=competency.get("leadership", 70),
        ),
        panelist_summaries=panelist_summaries,
    )
