"""
Backend tests for Phase 2 Interview Intelligence endpoints.
Run with: pytest tests/test_phase2.py -v

All ML models, Supabase, and external LLM calls are mocked.
"""
import pytest
from unittest.mock import patch, MagicMock, AsyncMock


# ── Shared client fixture ─────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def client():
    """TestClient with all heavy dependencies mocked."""
    with patch("services.whisper_service.get_model") as mw, \
         patch("services.tts_service.get_tts_model") as mt, \
         patch("services.grammar_service._get_tool") as mg:

        mw.return_value = MagicMock()
        mt.return_value = MagicMock()
        mg.return_value = MagicMock()

        import main
        from fastapi.testclient import TestClient
        yield TestClient(main.app)


# ── Helpers / constants ────────────────────────────────────────────────────────

FAKE_TOKEN = "Bearer fake-token"
USER_ID    = "user-test-001"
ITV_ID     = "interview-uuid-1234"

# Matches all fields required by PanelistConfig Pydantic model
FAKE_PANELIST = {
    "id": "panelist-1",
    "name": "Dr. Sharma",
    "archetype": "technologist",
    "title": "Senior Engineer",
    "emoji": "🧑‍💻",
    "personality": "analytical",
    "fun_fact": "Likes distributed systems.",
}

FAKE_PANEL = [FAKE_PANELIST]

FAKE_PANEL_CONFIG = {
    "panelists": FAKE_PANEL,
    "round_types": ["technical", "behavioural"],
    "panelist_count": 1,
}


# ── /interview/setup ──────────────────────────────────────────────────────────

class TestInterviewSetup:

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_panel", new_callable=AsyncMock)
    @patch("routers.interview.index_jd", new_callable=AsyncMock)
    def test_setup_success(self, mock_index_jd, mock_gen_panel, mock_supabase, mock_verify, client):
        """Happy-path: setup a 2-round interview with a JD."""
        mock_verify.return_value = {"id": USER_ID, "email": "test@test.com"}
        mock_gen_panel.return_value = FAKE_PANEL
        mock_index_jd.return_value = 5

        mock_db = MagicMock()
        mock_db.table.return_value.insert.return_value.execute.return_value = MagicMock()
        mock_supabase.return_value = mock_db

        res = client.post(
            "/interview/setup",
            json={
                "user_id": USER_ID,
                "company": "Acme Corp",
                "role": "Software Engineer",
                "round_types": ["technical", "behavioural"],
                "panelist_count": 1,
                "jd_text": "We are looking for a software engineer with 3+ years experience.",
            },
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["company"] == "Acme Corp"
        assert data["role"] == "Software Engineer"
        assert data["total_rounds"] == 2
        assert "interview_id" in data
        assert "panel" in data
        assert len(data["panel"]) == 1
        assert data["panel"][0]["name"] == "Dr. Sharma"

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_panel", new_callable=AsyncMock)
    @patch("routers.interview.index_jd", new_callable=AsyncMock)
    def test_setup_forbidden(self, mock_index_jd, mock_gen_panel, mock_supabase, mock_verify, client):
        """Should return 403 when user_id in body doesn't match JWT."""
        mock_verify.return_value = {"id": "different-user", "email": "other@test.com"}
        mock_gen_panel.return_value = FAKE_PANEL
        mock_index_jd.return_value = 0
        mock_supabase.return_value = MagicMock()

        res = client.post(
            "/interview/setup",
            json={
                "user_id": USER_ID,
                "company": "Acme Corp",
                "role": "PM",
                "round_types": ["hr"],
                "panelist_count": 1,
            },
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 403

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_panel", new_callable=AsyncMock)
    @patch("routers.interview.index_jd", new_callable=AsyncMock)
    def test_setup_without_jd(self, mock_index_jd, mock_gen_panel, mock_supabase, mock_verify, client):
        """Should succeed even when jd_text is not provided."""
        mock_verify.return_value = {"id": USER_ID, "email": "test@test.com"}
        mock_gen_panel.return_value = FAKE_PANEL
        mock_index_jd.return_value = 0

        mock_db = MagicMock()
        mock_db.table.return_value.insert.return_value.execute.return_value = MagicMock()
        mock_supabase.return_value = mock_db

        res = client.post(
            "/interview/setup",
            json={
                "user_id": USER_ID,
                "company": "StartupX",
                "role": "Data Analyst",
                "round_types": ["behavioural"],
                "panelist_count": 1,
            },
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["total_rounds"] == 1
        # index_jd should NOT be called since no JD text was provided
        mock_index_jd.assert_not_called()


# ── /interview/start ──────────────────────────────────────────────────────────

class TestInterviewStart:

    def _mock_db(self, found=True):
        mock_db = MagicMock()
        data = None
        if found:
            data = {
                "id": ITV_ID,
                "user_id": USER_ID,
                "company": "Acme Corp",
                "role": "Engineer",
                "panel_config": FAKE_PANEL_CONFIG,
                "status": "setup",
            }
        mock_db.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = data
        mock_db.table.return_value.update.return_value.eq.return_value.execute.return_value = MagicMock()
        return mock_db

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_question", new_callable=AsyncMock)
    @patch("routers.interview.tts_service.synthesize", new_callable=AsyncMock)
    def test_start_round1(self, mock_tts, mock_gen_q, mock_supabase, mock_verify, client):
        """Starting round 1 should return first question and audio."""
        mock_verify.return_value = {"id": USER_ID}
        mock_gen_q.return_value = "Tell me about a challenging project you worked on."
        mock_tts.return_value = b"fake_audio_bytes"
        mock_supabase.return_value = self._mock_db()

        res = client.post(
            "/interview/start",
            json={"interview_id": ITV_ID, "user_id": USER_ID, "round_number": 1},
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["interview_id"] == ITV_ID
        assert data["round_number"] == 1
        assert data["round_type"] == "technical"
        assert "Tell me about" in data["opening_question"]
        assert data["opening_audio_base64"] is not None
        assert data["questions_per_round"] == 4

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_question", new_callable=AsyncMock)
    @patch("routers.interview.tts_service.synthesize", new_callable=AsyncMock)
    def test_start_invalid_round(self, mock_tts, mock_gen_q, mock_supabase, mock_verify, client):
        """Should return 400 when round number exceeds configured rounds."""
        mock_verify.return_value = {"id": USER_ID}
        mock_gen_q.return_value = "Question text"
        mock_tts.return_value = b"audio"
        mock_supabase.return_value = self._mock_db()

        res = client.post(
            "/interview/start",
            json={"interview_id": ITV_ID, "user_id": USER_ID, "round_number": 99},
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 400
        assert "Round number exceeds" in res.json()["detail"]

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_question", new_callable=AsyncMock)
    @patch("routers.interview.tts_service.synthesize", new_callable=AsyncMock)
    def test_start_not_found(self, mock_tts, mock_gen_q, mock_supabase, mock_verify, client):
        """Should return 404 when interview doesn't exist."""
        mock_verify.return_value = {"id": USER_ID}
        mock_supabase.return_value = self._mock_db(found=False)

        res = client.post(
            "/interview/start",
            json={"interview_id": "nonexistent-id", "user_id": USER_ID, "round_number": 1},
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 404


# ── /interview/end ────────────────────────────────────────────────────────────

class TestInterviewEnd:

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_report", new_callable=AsyncMock)
    def test_end_success(self, mock_gen_report, mock_supabase, mock_verify, client):
        """Should generate and return a full interview report."""
        mock_verify.return_value = {"id": USER_ID}
        mock_gen_report.return_value = {
            "overall_score": 82,
            "recommendation": "Hire",
            "recommendation_reason": "Strong technical skills.",
            "strengths": ["Clear communication", "Problem-solving"],
            "gaps": ["Could improve on system design"],
            "competency_scores": {
                "communication": 85,
                "technical": 80,
                "culture_fit": 78,
                "leadership": 75,
            },
            "panelist_summaries": [
                {"panelist_name": "Dr. Sharma", "score": 82, "note": "Great answers."}
            ],
        }

        mock_db = MagicMock()
        mock_db.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
            "id": ITV_ID,
            "user_id": USER_ID,
            "company": "Acme Corp",
            "role": "Engineer",
            "panel_config": FAKE_PANEL_CONFIG,
            "status": "round_2_active",
        }
        turns_mock = MagicMock()
        turns_mock.data = [
            {"round_number": 1, "question_number": 1, "question": "Q1", "transcript": "A1",
             "grammar_score": 90, "fluency_score": 85, "confidence_score": 80},
        ]
        mock_db.table.return_value.select.return_value.eq.return_value.order.return_value.execute.return_value = turns_mock
        mock_db.table.return_value.update.return_value.eq.return_value.execute.return_value = MagicMock()
        mock_supabase.return_value = mock_db

        res = client.post(
            "/interview/end",
            json={"interview_id": ITV_ID, "user_id": USER_ID},
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["overall_score"] == 82
        assert data["recommendation"] == "Hire"
        assert len(data["strengths"]) == 2
        assert data["competency_scores"]["communication"] == 85
        assert len(data["panelist_summaries"]) == 1
        assert data["panelist_summaries"][0]["panelist_name"] == "Dr. Sharma"

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.generate_report", new_callable=AsyncMock)
    def test_end_forbidden(self, mock_gen_report, mock_supabase, mock_verify, client):
        """Should return 403 when JWT user doesn't own the interview."""
        mock_verify.return_value = {"id": "other-user"}
        mock_db = MagicMock()
        mock_db.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
            "id": ITV_ID,
            "user_id": USER_ID,
            "company": "Acme",
            "role": "Engineer",
            "panel_config": FAKE_PANEL_CONFIG,
        }
        mock_supabase.return_value = mock_db

        res = client.post(
            "/interview/end",
            json={"interview_id": ITV_ID, "user_id": USER_ID},
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 403


# ── /interview/turn ────────────────────────────────────────────────────────────

class TestInterviewTurn:

    def _base64_audio(self):
        """Minimal base64-encoded bytes for testing."""
        import base64
        return base64.b64encode(b"\x00" * 64).decode()

    def _mock_db(self):
        mock_db = MagicMock()
        mock_db.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
            "id": ITV_ID,
            "user_id": USER_ID,
            "company": "Acme",
            "role": "Engineer",
            "panel_config": {
                "panelists": FAKE_PANEL,
                "round_types": ["technical"],
                "panelist_count": 1,
            },
        }
        last_turn_mock = MagicMock()
        last_turn_mock.data = [{"question": "Describe your experience with distributed systems."}]
        mock_db.table.return_value.select.return_value.eq.return_value.eq.return_value.order.return_value.limit.return_value.execute.return_value = last_turn_mock
        return mock_db

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.whisper_service.transcribe_audio", new_callable=AsyncMock)
    @patch("routers.interview.analyse_audio_and_text")
    @patch("routers.interview.check_grammar")
    @patch("routers.interview.evaluate_answer", new_callable=AsyncMock)
    @patch("routers.interview.generate_question", new_callable=AsyncMock)
    @patch("routers.interview.tts_service.synthesize", new_callable=AsyncMock)
    def test_turn_mid_round(
        self, mock_tts, mock_gen_q, mock_eval, mock_grammar, mock_analysis,
        mock_whisper, mock_supabase, mock_verify, client
    ):
        """Q1 of round 1: should transcribe, score, and return next question."""
        mock_verify.return_value = {"id": USER_ID}
        mock_whisper.return_value = {"text": "I built a distributed cache using Redis."}
        mock_analysis.return_value = {
            "wpm": 130, "filler_count": 2, "pause_count": 1,
            "confidence_score": 78.0, "fluency_score": 82.0, "vocabulary_score": 75.0,
        }
        mock_grammar.return_value = {"grammar_score": 88.0, "errors": []}
        mock_eval.return_value = {
            "relevance_score": 80, "depth_score": 75, "clarity_score": 85,
            "star_coverage": "full", "reaction": "Good answer.",
            "follow_up": "", "internal_note": "Solid response.",
        }
        mock_gen_q.return_value = "How would you handle cache invalidation at scale?"
        mock_tts.return_value = b"audio_bytes"
        mock_supabase.return_value = self._mock_db()

        res = client.post(
            "/interview/turn",
            json={
                "interview_id": ITV_ID,
                "user_id": USER_ID,
                "round_number": 1,
                "question_number": 1,
                "panelist_id": "panelist-1",
                "audio_base64": self._base64_audio(),
            },
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["transcript"] == "I built a distributed cache using Redis."
        assert data["grammar_score"] == 88.0
        assert data["fluency_score"] == 82.0
        assert data["confidence_score"] == 78.0
        assert data["wpm"] == 130
        assert "cache invalidation" in data["next_question"]
        assert data["round_complete"] is False

    @patch("routers.interview.verify_jwt")
    @patch("routers.interview.get_supabase")
    @patch("routers.interview.whisper_service.transcribe_audio", new_callable=AsyncMock)
    @patch("routers.interview.analyse_audio_and_text")
    @patch("routers.interview.check_grammar")
    @patch("routers.interview.evaluate_answer", new_callable=AsyncMock)
    @patch("routers.interview.generate_question", new_callable=AsyncMock)
    @patch("routers.interview.tts_service.synthesize", new_callable=AsyncMock)
    def test_turn_last_question(
        self, mock_tts, mock_gen_q, mock_eval, mock_grammar, mock_analysis,
        mock_whisper, mock_supabase, mock_verify, client
    ):
        """Q4 (last question of 4) — round_complete should be True."""
        mock_verify.return_value = {"id": USER_ID}
        mock_whisper.return_value = {"text": "I would use consistent hashing."}
        mock_analysis.return_value = {
            "wpm": 120, "filler_count": 0, "pause_count": 0,
            "confidence_score": 90.0, "fluency_score": 88.0, "vocabulary_score": 80.0,
        }
        mock_grammar.return_value = {"grammar_score": 95.0, "errors": []}
        mock_eval.return_value = {
            "relevance_score": 90, "depth_score": 88, "clarity_score": 92,
            "star_coverage": "full", "reaction": "Excellent!",
            "follow_up": "", "internal_note": "Very thorough.",
        }
        mock_gen_q.return_value = "Closing question"
        mock_tts.return_value = b"audio"
        mock_supabase.return_value = self._mock_db()

        res = client.post(
            "/interview/turn",
            json={
                "interview_id": ITV_ID,
                "user_id": USER_ID,
                "round_number": 1,
                "question_number": 4,   # Last question (QUESTIONS_PER_ROUND = 4)
                "panelist_id": "panelist-1",
                "audio_base64": self._base64_audio(),
            },
            headers={"Authorization": FAKE_TOKEN},
        )
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["round_complete"] is True
        assert "Thank you" in data["next_question"]
