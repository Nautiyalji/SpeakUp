"""
LLM Service — Gemini 2.0 Flash (primary) with Groq Llama 3.3 70B fallback.
Uses the new google-genai SDK (google.generativeai is deprecated).
Always returns structured JSON responses. Never crashes silently.
"""
import os
import json
import asyncio
from google import genai
from google.genai import types as genai_types
from groq import Groq

_gemini_client: genai.Client | None = None
_groq_client: Groq | None = None

GEMINI_MODEL = "gemini-2.0-flash"
GROQ_MODEL   = "llama-3.3-70b-versatile"


def _get_gemini() -> genai.Client:
    global _gemini_client
    if _gemini_client is None:
        _gemini_client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
    return _gemini_client


def _get_groq() -> Groq:
    global _groq_client
    if _groq_client is None:
        _groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    return _groq_client


async def generate(
    system_prompt: str,
    user_message: str,
    temperature: float = 0.7,
) -> str:
    """
    Generate a text response. Tries Gemini first, falls back to Groq.
    Implements exponential backoff on rate-limit errors.
    """
    for attempt in range(3):
        try:
            # ── Try Gemini ────────────────────────────────────────────────────
            client = _get_gemini()
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=user_message,
                config=genai_types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=temperature,
                ),
            )
            return response.text

        except Exception as gemini_error:
            error_str = str(gemini_error)
            if "429" in error_str or "503" in error_str or "quota" in error_str.lower():
                print(f"[LLM] Gemini rate-limited. Falling back to Groq. ({error_str[:80]})")
                try:
                    # ── Groq Fallback ─────────────────────────────────────────
                    groq = _get_groq()
                    completion = groq.chat.completions.create(
                        model=GROQ_MODEL,
                        messages=[
                            {"role": "system", "content": system_prompt},
                            {"role": "user",   "content": user_message},
                        ],
                        temperature=temperature,
                    )
                    return completion.choices[0].message.content

                except Exception as groq_error:
                    if attempt == 2:
                        raise RuntimeError(
                            f"Both LLMs failed. Gemini: {gemini_error} | Groq: {groq_error}"
                        )
            else:
                raise  # Re-raise non-rate-limit errors immediately

        await asyncio.sleep(2 ** attempt)  # Exponential backoff: 1s, 2s, 4s

    raise RuntimeError("Max LLM retries exceeded.")


async def generate_json(
    system_prompt: str,
    user_message: str,
    temperature: float = 0.7,
) -> dict:
    """
    Generate a structured JSON response.
    Appends a strict JSON-only instruction to the system prompt.
    Cleans and parses the raw output.
    """
    json_system = (
        system_prompt
        + "\n\nCRITICAL: Respond ONLY with valid JSON. "
        "No markdown code blocks. No explanation. No backticks. Just raw JSON."
    )
    raw = await generate(json_system, user_message, temperature)

    # Clean accidental markdown fences
    raw = raw.strip()
    if raw.startswith("```"):
        parts = raw.split("```")
        raw = parts[1] if len(parts) > 1 else raw
        if raw.lower().startswith("json"):
            raw = raw[4:]
    raw = raw.strip().strip("```").strip()

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"LLM returned invalid JSON: {e}\nRaw: {raw[:300]}")
