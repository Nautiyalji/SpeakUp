"""
Pydantic schemas for User / Auth models.
"""
from pydantic import BaseModel, EmailStr
from typing import Literal
from datetime import datetime


class ProfileCreate(BaseModel):
    user_id: str
    full_name: str
    target_accent: Literal["Indian English", "British English"] = "Indian English"
    level: Literal["beginner", "intermediate", "advanced"] = "beginner"


class ProfileUpdate(BaseModel):
    full_name: str | None = None
    target_accent: Literal["Indian English", "British English"] | None = None
    level: Literal["beginner", "intermediate", "advanced"] | None = None


class ProfileResponse(BaseModel):
    id: str
    full_name: str
    target_accent: str
    current_level: str
    daily_streak: int
    total_sessions: int
    created_at: datetime | None = None
