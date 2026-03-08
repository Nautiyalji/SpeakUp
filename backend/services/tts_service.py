"""
TTS service.
Supports local pyttsx3 and cloud-ready edge-tts.
"""
import asyncio
import io
import os
import tempfile
import pyttsx3
import edge_tts

# Use edge-tts in cloud, pyttsx3 locally
IS_CLOUD = os.getenv("DEPLOY_PLATFORM") == "cloud"

_engine = None

VOICE_MAP = {
    "coach_female": "en-US-AvaNeural",
    "coach_male": "en-US-AndrewNeural",
    "interviewer": "en-GB-RyanNeural",
}

# Local pyttsx3 index mapping
PYTTSX3_VOICE_MAP = {
    "coach_female": 1,
    "coach_male": 0,
    "interviewer": 0,
}

def get_tts_engine() -> pyttsx3.Engine:
    """Lazy-load and cache the pyttsx3 engine."""
    global _engine
    if IS_CLOUD:
        return None
    if _engine is None:
        print("[TTS] Initialising local pyttsx3 engine...")
        _engine = pyttsx3.init()
        _engine.setProperty("rate", 165)
        _engine.setProperty("volume", 0.95)
    return _engine


async def synthesize(text: str, voice: str = "coach_female") -> bytes:
    """Convert text to WAV audio bytes."""
    if IS_CLOUD:
        return await _synthesize_cloud(text, voice)
    
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _synthesize_sync, text, voice)


async def _synthesize_cloud(text: str, voice_key: str) -> bytes:
    """High-quality cloud TTS using edge-tts."""
    voice = VOICE_MAP.get(voice_key, "en-US-AvaNeural")
    communicate = edge_tts.Communicate(text, voice)
    
    # edge-tts returns mp3 content by default, but let's just use it as transparently as possible
    # Most modern web apps handle mp3 fine. If needed we can convert, but keeping it simple.
    data = b""
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            data += chunk["data"]
    return data


def _synthesize_sync(text: str, voice: str) -> bytes:
    """Synchronous local TTS."""
    engine = get_tts_engine()
    voices = engine.getProperty("voices")
    voice_index = PYTTSX3_VOICE_MAP.get(voice, 1)
    
    if voices and voice_index < len(voices):
        engine.setProperty("voice", voices[voice_index].id)

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name

    engine.save_to_file(text, tmp_path)
    engine.runAndWait()

    with open(tmp_path, "rb") as f:
        wav_bytes = f.read()

    os.unlink(tmp_path)
    return wav_bytes

get_tts_model = get_tts_engine
