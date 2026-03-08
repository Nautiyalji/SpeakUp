"""
Progress router — chart data and session history.
"""
from fastapi import APIRouter, HTTPException, Header, Query
from utils.supabase_client import get_supabase, verify_jwt

router = APIRouter()


def _auth(authorization: str) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header.")
    token = authorization.split("Bearer ")[1]
    try:
        return verify_jwt(token)["id"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.get("/{user_id}")
async def get_progress(
    user_id: str,
    days: int = Query(default=7, ge=1, le=365),
    authorization: str = Header(...),
):
    """
    Returns daily average scores for the last N days.
    Used to render the fl_chart line chart on the Progress screen.
    """
    uid = _auth(authorization)
    if uid != user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    db = get_supabase()
    from datetime import date, timedelta
    start_date = (date.today() - timedelta(days=days)).isoformat()

    response = db.table("progress_snapshots").select(
        "snapshot_date, avg_grammar, avg_vocabulary, avg_confidence, avg_fluency, avg_overall, sessions_count"
    ).eq("user_id", user_id).gte(
        "snapshot_date", start_date
    ).order("snapshot_date", desc=False).execute()

    return response.data or []


@router.get("/history/{user_id}")
async def get_session_history(
    user_id: str,
    limit: int = Query(default=10, ge=1, le=50),
    authorization: str = Header(...),
):
    """
    Returns a list of past sessions (date, score, duration).
    Used to render the session history list.
    """
    uid = _auth(authorization)
    if uid != user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    db = get_supabase()
    response = db.table("communication_sessions").select(
        "id, started_at, ended_at, overall_score, duration_seconds, turns_count, level_at_session"
    ).eq("user_id", user_id).not_.is_(
        "ended_at", "null"   # Only completed sessions
    ).order("started_at", desc=True).limit(limit).execute()

    return response.data or []
