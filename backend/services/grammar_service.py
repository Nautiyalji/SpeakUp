"""
Grammar Analysis Service using LanguageTool.
The tool is loaded once at startup and cached (takes ~5s first time).
"""
from functools import lru_cache
import language_tool_python


@lru_cache(maxsize=1)
def _get_tool() -> language_tool_python.LanguageTool:
    """Load LanguageTool once and keep it in memory."""
    print("[Grammar] Loading LanguageTool...")
    tool = language_tool_python.LanguageTool("en-US")
    print("[Grammar] LanguageTool loaded.")
    return tool


def check_grammar(text: str) -> dict:
    """
    Analyse a transcript for grammar errors.
    Short texts (< 10 words) receive a benefit-of-the-doubt score of 85.

    Returns:
    {
        "error_count": int,
        "errors": [{"message", "bad_text", "suggestion", "category"}, ...],
        "grammar_score": float (0-100),
        "corrected_text": str,
        "error_categories": {"GRAMMAR": 2, "TYPOS": 1}
    }
    """
    tool = _get_tool()
    word_count = len(text.split())

    if word_count < 10:
        return {
            "error_count": 0,
            "errors": [],
            "grammar_score": 85.0,
            "corrected_text": text,
            "error_categories": {},
        }

    matches = tool.check(text)
    errors = []
    categories: dict[str, int] = {}

    for match in matches:
        raw_category = match.ruleId.split("_")[0] if "_" in match.ruleId else "GRAMMAR"
        suggestion = match.replacements[0] if match.replacements else ""
        errors.append({
            "message": match.message,
            "bad_text": text[match.offset: match.offset + match.errorLength],
            "suggestion": suggestion,
            "category": raw_category,
            "offset": match.offset,
        })
        categories[raw_category] = categories.get(raw_category, 0) + 1

    corrected = language_tool_python.utils.correct(text, matches)

    # Score: 100 - (errors × penalty). More lenient for longer speech.
    penalty = max(3, 5 - (word_count // 30))
    grammar_score = max(0.0, min(100.0, 100.0 - len(errors) * penalty))

    return {
        "error_count": len(errors),
        "errors": errors[:5],    # Show max 5 errors in UI
        "grammar_score": round(grammar_score, 2),
        "corrected_text": corrected,
        "error_categories": categories,
    }
