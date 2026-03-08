"""
Whisper STT service.
Supports local faster-whisper and Groq Cloud Whisper API.
"""
import asyncio
import io
import os
import soundfile as sf
from groq import Groq

# Use faster-whisper locally, Groq in cloud
IS_CLOUD = os.getenv("DEPLOY_PLATFORM") == "cloud"

_model = None
_groq_client: Groq | None = None

WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")

def get_groq_client() -> Groq:
    global _groq_client
    if _groq_client is None:
        _groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    return _groq_client

def get_model():
    """Lazy-load and cache the Whisper model (singleton)."""
    global _model
    if IS_CLOUD:
        return None  # No local model needed for cloud
        
    if _model is None:
        from faster_whisper import WhisperModel
        print(f"[Whisper] Loading local model '{WHISPER_MODEL_SIZE}'...")
        _model = WhisperModel(WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")
        print("[Whisper] Local model ready.")
    return _model


async def transcribe_audio(audio_bytes: bytes, language: str = "en") -> dict:
    """Transcribe raw WAV audio bytes to text."""
    if IS_CLOUD:
        return await _transcribe_cloud(audio_bytes, language)
    
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _transcribe_sync, audio_bytes, language)


async def _transcribe_cloud(audio_bytes: bytes, language: str) -> dict:
    """Transcribe using Groq Cloud API."""
    client = get_groq_client()
    
    # Groq needs a file-like object with a name
    file_name = "audio.wav"
    audio_file = (file_name, audio_bytes, "audio/wav")
    
    try:
        response = client.audio.transcriptions.create(
            file=audio_file,
            model="whisper-large-v3",
            language=language,
            response_format="json",
        )
        return {
            "text": response.text,
            "segments": [], # API doesn't return detailed segments by default in simple mode
            "duration": 0.0,
            "language": language,
        }
    except Exception as e:
        print(f"[Whisper] Cloud transcription error: {e}")
        return {"text": "[Error during transcription]", "segments": [], "duration": 0.0, "language": language}


def _transcribe_sync(audio_bytes: bytes, language: str) -> dict:
    """Synchronous local transcription."""
    model = get_model()

    # Load bytes into soundfile buffer
    buffer = io.BytesIO(audio_bytes)
    audio_array, sample_rate = sf.read(buffer, dtype="float32")

    # Convert stereo → mono if needed
    if len(audio_array.shape) > 1:
        audio_array = audio_array.mean(axis=1)

    # Resample to 16kHz if needed
    if sample_rate != 16000:
        try:
            import librosa
            audio_array = librosa.resample(audio_array, orig_sr=sample_rate, target_sr=16000)
        except ImportError:
            print("[Whisper] librosa missing, skipping resampling (may affect accuracy)")

    # Save resampled audio to a temporary BytesIO buffer for faster_whisper
    out_buf = io.BytesIO()
    sf.write(out_buf, audio_array, 16000, format="WAV", subtype="PCM_16")
    out_buf.seek(0)

    segments_gen, info = model.transcribe(out_buf, language=language)
    segments = []
    full_text_parts = []
    for s in segments_gen:
        segments.append({"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()})
        full_text_parts.append(s.text.strip())

    duration = segments[-1]["end"] if segments else 0.0
    return {
        "text": " ".join(full_text_parts),
        "segments": segments,
        "duration": round(duration, 2),
        "language": info.language,
    }
