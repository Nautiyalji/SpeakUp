"""
Interview LLM Service — Panelist persona management and question generation.
Five archetypes with distinct system-prompt personalities.
JD context is injected via RAG retrieval before every turn.
"""
import json
from services.llm_service import generate_json, generate
from services.rag_service import retrieve_context

# ── Panelist Archetypes ────────────────────────────────────────────────────────
ARCHETYPES = {
    "hr_generalist": {
        "title": "HR Generalist",
        "emoji": "🤝",
        "personality": "warm, empathetic, focuses on culture fit and soft skills",
        "system": (
            "You are {name}, an HR Generalist interviewer at {company}. "
            "You are warm, empathetic, and focused on culture fit, teamwork, and soft skills. "
            "Ask behavioural questions (STAR format). Keep questions concise (1-2 sentences). "
            "Be encouraging but professional."
        ),
    },
    "technical_lead": {
        "title": "Technical Lead",
        "emoji": "💻",
        "personality": "precise, analytical, digs into technical depth",
        "system": (
            "You are {name}, a Technical Lead at {company} hiring for a {role} position. "
            "You are precise, analytical, and you dig deep into technical knowledge. "
            "Ask technical questions relevant to the JD. Follow up on vague answers. "
            "Do not accept hand-wavy responses."
        ),
    },
    "senior_engineer": {
        "title": "Senior Engineer",
        "emoji": "🔧",
        "personality": "practical, hands-on, asks scenario-based questions",
        "system": (
            "You are {name}, a Senior Engineer at {company}. "
            "You are practical, hands-on, and ask scenario-based and system design questions. "
            "Focus on how the candidate would actually solve real problems on the job."
        ),
    },
    "culture_fit": {
        "title": "Culture & Values Lead",
        "emoji": "🌱",
        "personality": "curious, open-ended, explores motivation and values",
        "system": (
            "You are {name}, responsible for culture and values alignment at {company}. "
            "You are curious and exploratory. Ask open-ended questions about motivation, "
            "growth mindset, failure handling, and long-term career vision."
        ),
    },
    "director": {
        "title": "Director",
        "emoji": "📊",
        "personality": "strategic, high-level, assesses leadership potential",
        "system": (
            "You are {name}, a Director at {company}. "
            "You assess leadership potential, strategic thinking, and business impact. "
            "Ask high-level questions about decision-making, trade-offs, and impact. "
            "Be direct and slightly challenging."
        ),
    },
}

ROUND_FOCUS = {
    "hr": "Culture fit, soft skills, and motivation.",
    "technical": "Technical knowledge, problem solving, and domain expertise.",
    "case_study": "Analytical thinking, structured problem breakdown, and recommendations.",
}


async def generate_panel(
    company: str,
    role: str,
    panelist_count: int,
    round_types: list[str],
) -> list[dict]:
    """
    AI-generate a named panel of panelists based on round types.
    Returns a list of panelist dicts with name, archetype, title, personality.
    """
    archetype_keys = _select_archetypes(round_types, panelist_count)

    system = (
        "You are a creative HR director. Generate realistic interviewer personas for a tech company. "
        "Return ONLY a JSON array of objects, one per panelist."
    )
    prompt = (
        f"Generate {panelist_count} interviewers for a {role} role at {company}. "
        f"Archetypes needed: {', '.join(archetype_keys)}. "
        "For each, provide: name (realistic full name), archetype (exact key from list), "
        "fun_fact (one short sentence about their background). "
        "JSON array only, no extra text."
    )
    try:
        raw = await generate_json(system, prompt, temperature=0.9)
        panelists = raw if isinstance(raw, list) else raw.get("panelists", [])
    except Exception:
        # Fallback: generate generic names
        panelists = [
            {"name": f"Interviewer {i+1}", "archetype": archetype_keys[i], "fun_fact": ""}
            for i in range(len(archetype_keys))
        ]

    # Enrich with archetype metadata
    result = []
    for i, p in enumerate(panelists[:panelist_count]):
        key = p.get("archetype", archetype_keys[i % len(archetype_keys)])
        archetype = ARCHETYPES.get(key, ARCHETYPES["hr_generalist"])
        result.append({
            "id": f"panelist_{i}",
            "name": p.get("name", f"Interviewer {i+1}"),
            "archetype": key,
            "title": archetype["title"],
            "emoji": archetype["emoji"],
            "personality": archetype["personality"],
            "fun_fact": p.get("fun_fact", ""),
        })
    return result


async def generate_question(
    panelist: dict,
    company: str,
    role: str,
    round_type: str,
    interview_id: str,
    question_number: int,
    previous_answer: str = "",
) -> str:
    """
    Generate a contextual interview question from a panelist's perspective.
    Injects JD context from RAG if available.
    """
    archetype = ARCHETYPES.get(panelist["archetype"], ARCHETYPES["hr_generalist"])
    system = archetype["system"].format(
        name=panelist["name"], company=company, role=role
    )

    # Retrieve JD context relevant to this round
    jd_context = await retrieve_context(
        query=f"{role} {ROUND_FOCUS.get(round_type, '')}",
        interview_id=interview_id,
    )

    context_block = f"\n\nJOB DESCRIPTION CONTEXT:\n{jd_context}" if jd_context else ""
    previous_block = (
        f"\n\nCANDIDATE'S LAST ANSWER: {previous_answer[:500]}"
        if previous_answer else ""
    )

    prompt = (
        f"This is question {question_number} of a {round_type.upper()} round "
        f"for a {role} position at {company}.{context_block}{previous_block}\n\n"
        "Ask ONE focused interview question. Be concise (1-3 sentences max). "
        "Do not refer to yourself in third person. Just ask the question naturally."
    )

    return await generate(system, prompt, temperature=0.8)


async def evaluate_answer(
    question: str,
    answer: str,
    panelist: dict,
    company: str,
    role: str,
    round_type: str,
    interview_id: str,
) -> dict:
    """
    Panelist evaluates the candidate's answer.
    Returns scores, follow_up question, and feedback.
    """
    archetype = ARCHETYPES.get(panelist["archetype"], ARCHETYPES["hr_generalist"])
    system = archetype["system"].format(
        name=panelist["name"], company=company, role=role
    )

    jd_context = await retrieve_context(
        query=answer[:200], interview_id=interview_id
    )
    context_block = f"\n\nJD CONTEXT:\n{jd_context}" if jd_context else ""

    prompt = (
        f"You asked: \"{question}\"\n"
        f"Candidate answered: \"{answer}\"{context_block}\n\n"
        "Evaluate the answer and return ONLY JSON:\n"
        "{\n"
        '  "relevance_score": 0-100,\n'
        '  "depth_score": 0-100,\n'
        '  "clarity_score": 0-100,\n'
        '  "star_coverage": "none|partial|complete",\n'
        '  "reaction": "your in-character brief reaction (1-2 sentences)",\n'
        '  "follow_up": "a follow-up question or empty string if satisfied",\n'
        '  "internal_note": "private assessment for the report (1 sentence)"\n'
        "}"
    )
    system_json = system + "\nCRITICAL: Respond ONLY with valid JSON. No extra text."

    try:
        return await generate_json(system_json, prompt, temperature=0.5)
    except Exception:
        return {
            "relevance_score": 70,
            "depth_score": 70,
            "clarity_score": 70,
            "star_coverage": "partial",
            "reaction": "Thank you for your response.",
            "follow_up": "",
            "internal_note": "Answer evaluated but scoring service encountered an error.",
        }


async def generate_report(
    company: str,
    role: str,
    panel: list[dict],
    turns: list[dict],
) -> dict:
    """
    Generate the final interview report from all turns.
    Returns hiring recommendation, per-panelist scores, strengths, gaps.
    """
    summary = json.dumps(turns[:20], indent=2)  # Cap to avoid token overflow
    system = (
        "You are a senior talent acquisition lead. Summarise an interview and produce "
        "a hiring recommendation based on panelist evaluations."
    )
    prompt = (
        f"Company: {company}\nRole: {role}\n"
        f"Interview turns and scores:\n{summary}\n\n"
        "Generate a comprehensive report as ONLY JSON:\n"
        "{\n"
        '  "overall_score": 0-100,\n'
        '  "recommendation": "Strong Yes|Yes|Maybe|No",\n'
        '  "recommendation_reason": "2-3 sentence justification",\n'
        '  "strengths": ["strength 1", "strength 2", "strength 3"],\n'
        '  "gaps": ["gap 1", "gap 2"],\n'
        '  "competency_scores": {"communication": 0-100, "technical": 0-100, "culture_fit": 0-100, "leadership": 0-100},\n'
        '  "panelist_summaries": [{"panelist_name": "...", "score": 0-100, "note": "..."}]\n'
        "}"
    )
    try:
        return await generate_json(system, prompt, temperature=0.4)
    except Exception:
        return {
            "overall_score": 70,
            "recommendation": "Maybe",
            "recommendation_reason": "Report generation encountered an error. Please review manually.",
            "strengths": [],
            "gaps": [],
            "competency_scores": {"communication": 70, "technical": 70, "culture_fit": 70, "leadership": 70},
            "panelist_summaries": [],
        }


def _select_archetypes(round_types: list[str], count: int) -> list[str]:
    """Map round types to appropriate panelist archetypes."""
    mapping = {
        "hr": "hr_generalist",
        "technical": "technical_lead",
        "case_study": "senior_engineer",
        "culture": "culture_fit",
        "director": "director",
    }
    keys = [mapping.get(r, "hr_generalist") for r in round_types]
    # Pad or trim to match count
    while len(keys) < count:
        keys.append("senior_engineer")
    return keys[:count]
