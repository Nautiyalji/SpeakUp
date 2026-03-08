"""
Audio utility helpers — Base64 encoding/decoding and validation.
All audio is processed fully in-memory (never written to disk).
"""
import base64
import io
import wave


def bytes_to_base64(audio_bytes: bytes) -> str:
    """Encode raw bytes to a Base64 string for JSON transport."""
    return base64.b64encode(audio_bytes).decode("utf-8")


def base64_to_bytes(b64_string: str) -> bytes:
    """Decode a Base64 string back to raw bytes."""
    return base64.b64decode(b64_string)


def validate_wav(audio_bytes: bytes) -> bool:
    """
    Check that the provided bytes represent a valid WAV file.
    Returns True if valid, False otherwise.
    """
    try:
        buffer = io.BytesIO(audio_bytes)
        with wave.open(buffer, "rb") as wav_file:
            channels = wav_file.getnchannels()
            framerate = wav_file.getframerate()
            return channels >= 1 and framerate > 0
    except Exception:
        return False


def ensure_mono_wav(audio_bytes: bytes) -> bytes:
    """
    If the WAV has multiple channels, convert to mono by averaging.
    Returns mono WAV bytes.
    """
    import soundfile as sf
    import numpy as np

    buffer = io.BytesIO(audio_bytes)
    data, samplerate = sf.read(buffer, dtype="float32")

    if len(data.shape) > 1:
        data = data.mean(axis=1)  # Average channels → mono

    out_buffer = io.BytesIO()
    sf.write(out_buffer, data, samplerate, format="WAV", subtype="PCM_16")
    out_buffer.seek(0)
    return out_buffer.read()
