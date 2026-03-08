"""
Speech + Text Analysis Service.
Extracts acoustic metrics (Librosa) and computes Confidence, Fluency, Vocabulary scores.
"""
import io
import re
import asyncio
import numpy as np
try:
    import librosa
    import soundfile as sf
    LIBROSA_AVAILABLE = True
except ImportError:
    print("[Analysis] WARNING: librosa or soundfile missing. Acoustic analysis disabled.")
    LIBROSA_AVAILABLE = False

FILLER_WORDS = {
    "um", "uh", "like", "you know", "basically", "actually",
    "sort of", "kind of", "i mean", "right", "okay so", "so like"
}


def analyse_audio_and_text(audio_bytes: bytes, transcript: str) -> dict:
    """
    Full analysis pipeline for one turn of a coaching session.
    Returns a dict of raw metrics + computed scores (all 0-100).
    """
    if not LIBROSA_AVAILABLE:
        # Fallback for cloud environments without system audio libraries
        words = transcript.lower().split()
        words_count = len(words)
        return {
            "duration": 0.0,
            "wpm": 0,
            "words_count": words_count,
            "pause_count": 0,
            "filler_count": 0,
            "avg_pitch": 0.0,
            "pitch_variance": 0.0,
            "energy_db": 0.0,
            "energy_variance": 0.0,
            "type_token_ratio": 0.0,
            "completion_rate": 0.0,
            "confidence_score": 70.0,
            "fluency_score": 70.0,
            "vocabulary_score": 70.0,
            "notice": "Acoustic analysis disabled (cloud mode)"
        }

    # ── Load Audio ────────────────────────────────────────────────────────────
    try:
        # Try soundfile first (faster)
        buffer = io.BytesIO(audio_bytes)
        y, sr = sf.read(buffer, dtype="float32")
    except Exception:
        # Fallback to librosa.load which uses audioread/ffmpeg (handles WebM/Opus)
        try:
            buffer = io.BytesIO(audio_bytes)
            y, sr = librosa.load(buffer, sr=None)
        except Exception as e:
            print(f"[Analysis] Audio loading failed: {e}")
            return {
                "duration": 0.0,
                "wpm": 0,
                "words_count": len(transcript.split()),
                "pause_count": 0,
                "filler_count": 0,
                "avg_pitch": 0.0,
                "pitch_variance": 0.0,
                "energy_db": 0.0,
                "energy_variance": 0.0,
                "type_token_ratio": 0.0,
                "completion_rate": 0.0,
                "confidence_score": 50.0,
                "fluency_score": 50.0,
                "vocabulary_score": 50.0,
                "notice": "Acoustic analysis failed: format error"
            }

    if len(y.shape) > 1:
        y = y.mean(axis=1)  # Stereo → mono
    if sr != 22050:
        y = librosa.resample(y, orig_sr=sr, target_sr=22050)
        sr = 22050

    duration = librosa.get_duration(y=y, sr=sr)

    # ── Pitch (F0) ────────────────────────────────────────────────────────────
    f0, voiced_flag, _ = librosa.pyin(y, fmin=80, fmax=400, sr=sr)
    voiced_f0 = f0[voiced_flag & ~np.isnan(f0)] if f0 is not None else np.array([])
    avg_pitch = float(np.mean(voiced_f0)) if len(voiced_f0) > 0 else 0.0
    pitch_variance = float(np.std(voiced_f0)) if len(voiced_f0) > 0 else 0.0

    # ── Energy ────────────────────────────────────────────────────────────────
    rms = librosa.feature.rms(y=y)[0]
    energy_db = float(librosa.amplitude_to_db(np.mean(rms)))
    energy_variance = float(np.std(librosa.amplitude_to_db(rms)))

    # ── Pause Detection ───────────────────────────────────────────────────────
    frame_len = int(0.5 * sr)
    hop_len = frame_len // 2
    rms_frames = librosa.feature.rms(y=y, frame_length=frame_len, hop_length=hop_len)[0]
    silence_threshold = np.percentile(rms_frames, 15)
    silent_frames = rms_frames < silence_threshold
    pause_count = int(np.sum(np.diff(silent_frames.astype(int)) == 1))

    # ── Text Metrics ──────────────────────────────────────────────────────────
    words = transcript.lower().split()
    words_count = len(words)
    wpm = int((words_count / duration) * 60) if duration > 0 else 0

    text_lower = transcript.lower()
    filler_count = sum(text_lower.count(f) for f in FILLER_WORDS)

    # ── Score: Confidence ─────────────────────────────────────────────────────
    confidence_raw = 100.0 - (filler_count * 5) - (pause_count * 2)
    if 110 <= wpm <= 160:
        confidence_raw += 10   # Ideal speaking pace bonus
    elif wpm < 80:
        confidence_raw -= 10   # Very slow speaker penalty
    confidence_score = max(0.0, min(100.0, confidence_raw))

    # ── Score: Fluency ────────────────────────────────────────────────────────
    sentences = re.split(r"[.!?]+", transcript)
    complete = [s.strip() for s in sentences if len(s.strip().split()) >= 4]
    completion_rate = len(complete) / max(len(sentences), 1)
    avg_words_per_sentence = words_count / max(len(sentences), 1)
    fluency_raw = (
        (completion_rate * 50)
        + (min(avg_words_per_sentence / 15, 1.0) * 30)
        + (min(wpm / 150, 1.0) * 20)
    )
    fluency_score = max(0.0, min(100.0, fluency_raw * 100))

    # ── Score: Vocabulary ─────────────────────────────────────────────────────
    clean_words = re.sub(r"[^\w\s]", "", transcript.lower()).split()
    unique_words = set(clean_words)
    type_token_ratio = len(unique_words) / max(len(clean_words), 1)
    avg_word_length = float(np.mean([len(w) for w in unique_words])) if unique_words else 0.0
    vocabulary_score = max(0.0, min(100.0,
        (type_token_ratio * 60) + (min(avg_word_length / 7.0, 1.0) * 40)
    ))

    return {
        # Raw metrics
        "duration": round(duration, 2),
        "wpm": wpm,
        "words_count": words_count,
        "pause_count": pause_count,
        "filler_count": filler_count,
        "avg_pitch": round(avg_pitch, 2),
        "pitch_variance": round(pitch_variance, 2),
        "energy_db": round(energy_db, 2),
        "energy_variance": round(energy_variance, 2),
        "type_token_ratio": round(type_token_ratio, 3),
        "completion_rate": round(completion_rate, 3),
        # Computed scores (all 0-100)
        "confidence_score": round(confidence_score, 2),
        "fluency_score": round(fluency_score, 2),
        "vocabulary_score": round(vocabulary_score, 2),
    }
