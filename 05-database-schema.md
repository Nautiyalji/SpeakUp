# 05 - Database Schema

## 1. Core Tables

### `profiles`
Stores user settings and gamification metrics.
- `id`: UUID (Primary Key, references `auth.users`)
- `full_name`: Text
- `target_accent`: Text ('Indian English' | 'British English')
- `current_level`: Text ('beginner' | 'intermediate' | 'advanced')
- `daily_streak`: Integer
- `total_sessions`: Integer
- `created_at`: Timestamptz

### `communication_sessions`
Tracks overall coaching sessions.
- `id`: UUID (Primary Key)
- `user_id`: UUID (References `profiles`)
- `target_accent`: Text
- `level_at_session`: Text
- `started_at`: Timestamptz
- `ended_at`: Timestamptz
- `grammar_score`: Numeric(5,2)
- `vocabulary_score`: Numeric(5,2)
- `confidence_score`: Numeric(5,2)
- `fluency_score`: Numeric(5,2)
- `overall_score`: Numeric(5,2)
- `transcript`: Text
- `ai_feedback`: JSONB
- `turns_count`: Integer

### `progress_snapshots`
Daily aggregated scores for trend analysis.
- `user_id`: UUID (Unique with `snapshot_date`)
- `snapshot_date`: Date
- `avg_grammar`: Numeric(5,2)
- `avg_vocabulary`: Numeric(5,2)
- `avg_confidence`: Numeric(5,2)
- `avg_fluency`: Numeric(5,2)
- `avg_overall`: Numeric(5,2)
- `sessions_count`: Integer

## 2. Interview Simulation (Phase 2 Additions)

### `interview_setups`
Configuration for mock interviews.
- `id`: UUID
- `user_id`: UUID
- `company_name`: Text
- `role_name`: Text
- `panel_config`: JSONB (Aarav, Meera, etc.)
- `rounds_config`: JSONB

### `interview_sessions`
Tracking the actual mock interview runs.
- `id`: UUID
- `setup_id`: UUID
- `status`: Text ('active' | 'completed')
- `rounds_data`: JSONB (Per-round scores and transcripts)

## 3. Row Level Security (RLS)
Every table implements RLS:
- **Policy:** `auth.uid() = user_id` (or `id` for profiles).
- **Effect:** Users cannot read, update, or delete data belonging to other users.

## 4. Performance Indexes
- `idx_sessions_user_date` on `communication_sessions(user_id, started_at DESC)`.
- `idx_snapshots_user` on `progress_snapshots(user_id, snapshot_date)`.
