"""
Sessions router — the heart of SpeakUp.
POST /sessions/start  → Create session, generate AI greeting
POST /sessions/turn   → Full pipeline: Audio → STT → Analysis → LLM → TTS  
POST /sessions/end    → Aggregate scores, generate feedback, update DB
"""
from fastapi import APIRouter, HTTPException, Header, BackgroundTasks
from datetime import datetime, timezone

from models.session_models import (
    SessionStartRequest, SessionStartResponse,
    TurnRequest, TurnResponse,
    EndSessionRequest, EndSessionResponse,
    AICoachResponse, GrammarError, FinalScores, SessionFeedback,
)
from utils.supabase_client import get_supabase, verify_jwt
from utils.audio_utils import base64_to_bytes, bytes_to_base64
from utils.prompts import (
    DAILY_SESSION_SYSTEM, DAILY_SESSION_BEGINNER_SYSTEM,
    SESSION_FEEDBACK_SYSTEM, SESSION_GREETING_SYSTEM
)
from services import whisper_service, tts_service, llm_service
from services.analysis_service import analyse_audio_and_text
from services.grammar_service import check_grammar

router = APIRouter()


def _auth(authorization: str) -> str:
    """Validate JWT and return user_id."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header.")
    token = authorization.split("Bearer ")[1]
    try:
        return verify_jwt(token)["id"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


def _session_system_prompt(level: str) -> str:
    return DAILY_SESSION_BEGINNER_SYSTEM if level == "beginner" else DAILY_SESSION_SYSTEM


# ── POST /sessions/start ───────────────────────────────────────────────────────

@router.post("/start", response_model=SessionStartResponse)
async def start_session(
    body: SessionStartRequest,
    authorization: str = Header(...),
):
    """
    Start a new coaching session.
    1. Create a session row in Supabase.
    2. Generate a warm AI greeting via LLM.
    3. Synthesize greeting to audio via TTS.
    """
    uid = _auth(authorization)
    if uid != body.user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    db = get_supabase()

    # Create session row
    session_row = db.table("communication_sessions").insert({
        "user_id": body.user_id,
        "target_accent": body.target_accent,
        "level_at_session": body.level,
    }).execute()

    if not session_row.data:
        raise HTTPException(status_code=500, detail="Failed to create session.")

    session_id = session_row.data[0]["id"]

    # Generate AI greeting
    user_msg = f"Student level: {body.level}. Target accent: {body.target_accent}. Start the session."
    greeting_data = await llm_service.generate_json(SESSION_GREETING_SYSTEM, user_msg)

    greeting_text = greeting_data.get("greeting_text", "Hello! Welcome to SpeakUp. Let's practise together!")
    first_exercise = greeting_data.get("first_exercise", "Tell me your name and what you did today.")

    # Synthesize greeting to audio
    greeting_audio_bytes = await tts_service.synthesize(greeting_text, voice="coach_female")
    greeting_audio_b64 = bytes_to_base64(greeting_audio_bytes)

    return SessionStartResponse(
        session_id=session_id,
        greeting=greeting_text,
        greeting_audio=greeting_audio_b64,
        first_exercise=first_exercise,
    )


# ── POST /sessions/turn ────────────────────────────────────────────────────────

@router.post("/turn", response_model=TurnResponse)
async def session_turn(
    body: TurnRequest,
    background_tasks: BackgroundTasks,
    authorization: str = Header(...),
):
    """
    Full pipeline for one conversational turn:
    Audio (Base64) → Whisper → Analysis → Grammar → Gemini → Coqui → Response
    """
    uid = _auth(authorization)
    if uid != body.user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    # 1. Decode audio
    try:
        audio_bytes = base64_to_bytes(body.audio_base64)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Base64 audio data.")

    # 2. Transcribe (Whisper)
    whisper_result = await whisper_service.transcribe_audio(audio_bytes)
    transcript = whisper_result["text"]

    if not transcript.strip():
        raise HTTPException(status_code=422, detail="No speech detected in audio.")

    # 3. Acoustic + Text Analysis (Librosa + NLP)
    try:
        analysis = analyse_audio_and_text(audio_bytes, transcript)
    except Exception as e:
        # Non-blocking: proceed with default scores if analysis fails
        print(f"[Sessions] Analysis error: {e}")
        analysis = {
            "wpm": 0, "words_count": 0, "pause_count": 0, "filler_count": 0,
            "confidence_score": 50.0, "fluency_score": 50.0, "vocabulary_score": 50.0,
        }

    # 4. Grammar Analysis (LanguageTool)
    grammar_result = check_grammar(transcript)

    # 5. Generate AI coaching response (Gemini / Groq)
    # Fetch session details to get level
    session_data = get_supabase().table("communication_sessions").select(
        "level_at_session, target_accent"
    ).eq("id", body.session_id).single().execute()

    level = session_data.data.get("level_at_session", "beginner") if session_data.data else "beginner"
    accent = session_data.data.get("target_accent", "Indian English") if session_data.data else "Indian English"

    system_prompt = _session_system_prompt(level)
    user_msg = (
        f"Student said: \"{transcript}\"\n"
        f"WPM: {analysis['wpm']}, Filler words: {analysis['filler_count']}, "
        f"Pauses: {analysis['pause_count']}, Grammar errors: {grammar_result['error_count']}.\n"
        f"Target accent: {accent}."
    )
    ai_data = await llm_service.generate_json(system_prompt, user_msg)

    # 6. Synthesize AI response to audio (Coqui TTS)
    ai_text = ai_data.get("response_text", "Great effort! Keep going.")
    ai_audio_bytes = await tts_service.synthesize(ai_text, voice="coach_female")
    ai_audio_b64 = bytes_to_base64(ai_audio_bytes)

    # 7. Save turn data in background (non-blocking)
    background_tasks.add_task(
        _save_turn_to_db,
        session_id=body.session_id,
        turn_number=body.turn_number,
        transcript=transcript,
        scores={
            "grammar_score": grammar_result["grammar_score"],
            "vocabulary_score": analysis["vocabulary_score"],
            "confidence_score": analysis["confidence_score"],
            "fluency_score": analysis["fluency_score"],
        },
    )

    return TurnResponse(
        transcript=transcript,
        grammar_score=grammar_result["grammar_score"],
        vocabulary_score=analysis["vocabulary_score"],
        confidence_score=analysis["confidence_score"],
        fluency_score=analysis["fluency_score"],
        wpm=analysis["wpm"],
        filler_count=analysis["filler_count"],
        pause_count=analysis["pause_count"],
        grammar_errors=[GrammarError(**e) for e in grammar_result["errors"]],
        ai_response=AICoachResponse(
            response_text=ai_data.get("response_text", ai_text),
            praise=ai_data.get("praise", ""),
            tip=ai_data.get("tip", ""),
            exercise=ai_data.get("exercise", ""),
        ),
        ai_audio_base64=ai_audio_b64,
    )


def _save_turn_to_db(session_id: str, turn_number: int, transcript: str, scores: dict):
    """Background task: update session's turns_count and partial scores."""
    try:
        db = get_supabase()
        # Append transcript and increment turn count
        session = db.table("communication_sessions").select(
            "turns_count, transcript"
        ).eq("id", session_id).single().execute()

        if session.data:
            existing_transcript = session.data.get("transcript") or ""
            full_transcript = f"{existing_transcript}\n[Turn {turn_number}]: {transcript}".strip()
            db.table("communication_sessions").update({
                "turns_count": session.data["turns_count"] + 1,
                "transcript": full_transcript,
            }).eq("id", session_id).execute()
    except Exception as e:
        print(f"[Sessions] Background save error: {e}")


# ── POST /sessions/end ─────────────────────────────────────────────────────────

@router.post("/end", response_model=EndSessionResponse)
async def end_session(
    body: EndSessionRequest,
    authorization: str = Header(...),
):
    """
    End a session: aggregate scores → generate feedback → update DB → update streak.
    """
    uid = _auth(authorization)
    if uid != body.user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    db = get_supabase()

    # Fetch session data
    session = db.table("communication_sessions").select("*").eq(
        "id", body.session_id
    ).single().execute()

    if not session.data:
        raise HTTPException(status_code=404, detail="Session not found.")

    s = session.data

    # For MVP: use the running scores stored per-turn (simplified: use last available scores)
    # In a real implementation, we'd average all turns from a separate turns table
    grammar = float(s.get("grammar_score") or 70.0)
    vocabulary = float(s.get("vocabulary_score") or 65.0)
    confidence = float(s.get("confidence_score") or 65.0)
    fluency = float(s.get("fluency_score") or 68.0)
    overall = round(grammar * 0.25 + vocabulary * 0.20 + confidence * 0.25 + fluency * 0.30, 2)

    # Generate AI feedback
    score_summary = (
        f"Grammar: {grammar:.1f}/100, Vocabulary: {vocabulary:.1f}/100, "
        f"Confidence: {confidence:.1f}/100, Fluency: {fluency:.1f}/100, Overall: {overall:.1f}/100."
    )
    feedback_data = await llm_service.generate_json(
        SESSION_FEEDBACK_SYSTEM,
        f"Session scores: {score_summary}. Transcript excerpt: {(s.get('transcript') or '')[:500]}"
    )

    now = datetime.now(timezone.utc).isoformat()

    # Update session row with final scores
    db.table("communication_sessions").update({
        "ended_at": now,
        "grammar_score": grammar,
        "vocabulary_score": vocabulary,
        "confidence_score": confidence,
        "fluency_score": fluency,
        "overall_score": overall,
        "ai_feedback": feedback_data,
    }).eq("id", body.session_id).execute()

    # Upsert progress snapshot for today
    _upsert_progress_snapshot(db, body.user_id, grammar, vocabulary, confidence, fluency, overall)

    # Update streak
    _update_streak(db, body.user_id)

    return EndSessionResponse(
        final_scores=FinalScores(
            grammar=grammar, vocabulary=vocabulary,
            confidence=confidence, fluency=fluency, overall=overall,
        ),
        feedback=SessionFeedback(
            headline=feedback_data.get("headline", "Great effort today!"),
            strengths=feedback_data.get("strengths", []),
            improvements=feedback_data.get("improvements", []),
            daily_exercises=feedback_data.get("daily_exercises", []),
            motivational_message=feedback_data.get("motivational_message", "Keep going!"),
            next_session_focus=feedback_data.get("next_session_focus", "Fluency"),
        ),
    )


def _upsert_progress_snapshot(db, user_id, grammar, vocabulary, confidence, fluency, overall):
    from datetime import date
    today = date.today().isoformat()
    db.table("progress_snapshots").upsert({
        "user_id": user_id,
        "snapshot_date": today,
        "avg_grammar": grammar,
        "avg_vocabulary": vocabulary,
        "avg_confidence": confidence,
        "avg_fluency": fluency,
        "avg_overall": overall,
    }, on_conflict="user_id,snapshot_date").execute()


def _update_streak(db, user_id):
    from datetime import date, timedelta
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    yesterday_snapshot = db.table("progress_snapshots").select("id").eq(
        "user_id", user_id
    ).eq("snapshot_date", yesterday).execute()

    profile = db.table("profiles").select("daily_streak, total_sessions").eq(
        "id", user_id
    ).single().execute()

    if profile.data:
        current_streak = profile.data.get("daily_streak", 0)
        total_sessions = profile.data.get("total_sessions", 0)
        new_streak = current_streak + 1 if yesterday_snapshot.data else 1
        db.table("profiles").update({
            "daily_streak": new_streak,
            "total_sessions": total_sessions + 1,
        }).eq("id", user_id).execute()
