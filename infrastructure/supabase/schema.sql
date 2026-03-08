"""
SpeakUp — Supabase SQL Schema (MVP)
Run this in the Supabase SQL Editor to set up the complete MVP database.
"""

-- ── Extensions ─────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── PROFILES ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name     TEXT NOT NULL,
  target_accent TEXT NOT NULL DEFAULT 'Indian English'
                    CHECK (target_accent IN ('Indian English', 'British English')),
  current_level TEXT NOT NULL DEFAULT 'beginner'
                    CHECK (current_level IN ('beginner', 'intermediate', 'advanced')),
  daily_streak  INTEGER DEFAULT 0,
  total_sessions INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile row when a new user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Student')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- ── COMMUNICATION SESSIONS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS communication_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  target_accent    TEXT NOT NULL,
  level_at_session TEXT NOT NULL,
  started_at       TIMESTAMPTZ DEFAULT now(),
  ended_at         TIMESTAMPTZ,
  duration_seconds INTEGER,
  grammar_score    NUMERIC(5,2),
  vocabulary_score NUMERIC(5,2),
  confidence_score NUMERIC(5,2),
  fluency_score    NUMERIC(5,2),
  overall_score    NUMERIC(5,2),
  transcript       TEXT,            -- Concatenated transcript of all turns
  ai_feedback      JSONB,           -- Full feedback JSON from session end
  turns_count      INTEGER DEFAULT 0
);

-- Index for fast per-user session queries ordered by date
CREATE INDEX IF NOT EXISTS idx_sessions_user_date
  ON communication_sessions(user_id, started_at DESC);

-- ── PROGRESS SNAPSHOTS ─────────────────────────────────────────────────────────
-- One row per user per day — averaged scores for fast chart queries
CREATE TABLE IF NOT EXISTS progress_snapshots (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  snapshot_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  avg_grammar    NUMERIC(5,2),
  avg_vocabulary NUMERIC(5,2),
  avg_confidence NUMERIC(5,2),
  avg_fluency    NUMERIC(5,2),
  avg_overall    NUMERIC(5,2),
  sessions_count INTEGER DEFAULT 1,
  UNIQUE(user_id, snapshot_date)    -- Enforce one row per user per day
);

CREATE INDEX IF NOT EXISTS idx_snapshots_user
  ON progress_snapshots(user_id, snapshot_date);

-- ── ROW LEVEL SECURITY ─────────────────────────────────────────────────────────
ALTER TABLE profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_snapshots     ENABLE ROW LEVEL SECURITY;

-- Users can only access their own data
CREATE POLICY "profiles: owners only"
  ON profiles FOR ALL USING (auth.uid() = id);

CREATE POLICY "sessions: owners only"
  ON communication_sessions FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "snapshots: owners only"
  ON progress_snapshots FOR ALL USING (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 2: INTERVIEW INTELLIGENCE
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── INTERVIEW SESSIONS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS interview_sessions (
  id               UUID PRIMARY KEY,
  user_id          UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  company          TEXT NOT NULL,
  role             TEXT NOT NULL,
  panel_config     JSONB NOT NULL DEFAULT '{}',  -- panelists + round_types
  jd_chunk_count   INTEGER DEFAULT 0,
  status           TEXT NOT NULL DEFAULT 'setup'
                       CHECK (status IN ('setup','round_1_active','round_2_active',
                                         'round_3_active','completed')),
  current_round    INTEGER DEFAULT 0,
  report           JSONB,                         -- Final AI report JSON
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interview_sessions_user
  ON interview_sessions(user_id, created_at DESC);

-- ── INTERVIEW TURNS ────────────────────────────────────────────────────────────
-- One row per answer per panelist per round
CREATE TABLE IF NOT EXISTS interview_turns (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_id     UUID REFERENCES interview_sessions(id) ON DELETE CASCADE NOT NULL,
  round_number     INTEGER NOT NULL,
  question_number  INTEGER NOT NULL,
  panelist_id      TEXT NOT NULL,
  question         TEXT,
  transcript       TEXT,
  relevance_score  NUMERIC(5,2),
  depth_score      NUMERIC(5,2),
  clarity_score    NUMERIC(5,2),
  star_coverage    TEXT,
  grammar_score    NUMERIC(5,2),
  fluency_score    NUMERIC(5,2),
  confidence_score NUMERIC(5,2),
  internal_note    TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interview_turns_interview
  ON interview_turns(interview_id, round_number, question_number);

-- ── RLS for Interview Tables ───────────────────────────────────────────────────
ALTER TABLE interview_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE interview_turns    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "interview_sessions: owners only"
  ON interview_sessions FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "interview_turns: owners only"
  ON interview_turns FOR ALL
  USING (
    auth.uid() = (
      SELECT user_id FROM interview_sessions WHERE id = interview_turns.interview_id
    )
  );
