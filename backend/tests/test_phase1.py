"""
Backend tests for Phase 1 MVP.
Run with: pytest tests/ -v

Prerequisites:
- A test Supabase project OR mock the client
- Set TEST_* env vars in .env.test if needed
"""
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

# ── Setup ──────────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def client():
    """Create a TestClient with ML models mocked out."""
    with patch("services.whisper_service.get_model") as mock_whisper, \
         patch("services.tts_service.get_tts_model") as mock_tts, \
         patch("services.grammar_service._get_tool") as mock_grammar:

        mock_whisper.return_value = MagicMock()
        mock_tts.return_value = MagicMock()
        mock_grammar.return_value = MagicMock()

        import main
        from fastapi.testclient import TestClient
        yield TestClient(main.app)


# ── Health check ───────────────────────────────────────────────────────────────

def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


# ── Auth ───────────────────────────────────────────────────────────────────────

@patch("routers.auth.verify_jwt")
@patch("routers.auth.get_supabase")
def test_get_profile_unauthorized(mock_supabase, mock_verify, client):
    """Should return 401 without Authorization header."""
    res = client.get("/auth/profile/some-user-id")
    assert res.status_code == 422  # Missing required header


@patch("routers.auth.verify_jwt")
@patch("routers.auth.get_supabase")
def test_get_profile_forbidden(mock_supabase, mock_verify, client):
    """Should return 403 when accessing another user's profile."""
    mock_verify.return_value = {"id": "user-A", "email": "a@test.com"}
    res = client.get("/auth/profile/user-B",
                     headers={"Authorization": "Bearer fake-token"})
    assert res.status_code == 403


@patch("routers.auth.verify_jwt")
@patch("routers.auth.get_supabase")
def test_get_profile_success(mock_supabase, mock_verify, client):
    """Should return profile when valid JWT matches user_id."""
    mock_verify.return_value = {"id": "user-123", "email": "test@test.com"}
    mock_db = MagicMock()
    mock_db.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
        "id": "user-123",
        "full_name": "Test Student",
        "target_accent": "Indian English",
        "current_level": "beginner",
        "daily_streak": 5,
        "total_sessions": 10,
        "created_at": "2025-01-01T00:00:00Z",
    }
    mock_supabase.return_value = mock_db
    res = client.get("/auth/profile/user-123",
                     headers={"Authorization": "Bearer valid-token"})
    assert res.status_code == 200
    assert res.json()["id"] == "user-123"
    assert res.json()["daily_streak"] == 5


# ── Sessions ───────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
@patch("routers.sessions.verify_jwt")
@patch("routers.sessions.get_supabase")
@patch("routers.sessions.llm_service.generate_json")
@patch("routers.sessions.tts_service.synthesize")
async def test_start_session(mock_tts, mock_llm, mock_supabase, mock_verify, client):
    """Should create a session and return greeting."""
    mock_verify.return_value = {"id": "user-123", "email": "test@test.com"}
    mock_llm.return_value = {
        "greeting_text": "Welcome! Let's practise.",
        "first_exercise": "Tell me your favourite subject."
    }
    mock_tts.return_value = b"fake_wav_bytes"
    mock_db = MagicMock()
    mock_db.table.return_value.insert.return_value.execute.return_value.data = [{
        "id": "session-uuid-1234"
    }]
    mock_supabase.return_value = mock_db

    res = client.post("/sessions/start",
                      json={"user_id": "user-123", "target_accent": "Indian English", "level": "beginner"},
                      headers={"Authorization": "Bearer valid-token"})
    assert res.status_code == 200
    assert "session_id" in res.json()
    assert "greeting_audio" in res.json()


# ── Progress ───────────────────────────────────────────────────────────────────

@patch("routers.progress.verify_jwt")
@patch("routers.progress.get_supabase")
def test_get_progress(mock_supabase, mock_verify, client):
    """Should return list of daily snapshots."""
    mock_verify.return_value = {"id": "user-123", "email": "test@test.com"}
    mock_db = MagicMock()
    mock_db.table.return_value.select.return_value.eq.return_value.gte.return_value.order.return_value.execute.return_value.data = [
        {"snapshot_date": "2025-01-01", "avg_overall": 72.5}
    ]
    mock_supabase.return_value = mock_db

    res = client.get("/progress/user-123?days=7",
                     headers={"Authorization": "Bearer valid-token"})
    assert res.status_code == 200
    assert isinstance(res.json(), list)
