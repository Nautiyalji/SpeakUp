"""
Auth router — Profile creation and retrieval.
All endpoints require a valid Supabase JWT.
"""
from fastapi import APIRouter, HTTPException, Header
from models.user_models import ProfileCreate, ProfileUpdate, ProfileResponse
from utils.supabase_client import get_supabase, verify_jwt

router = APIRouter()


def _require_auth(authorization: str) -> str:
    """Extract and verify Bearer JWT. Returns user_id."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header.")
    token = authorization.split("Bearer ")[1]
    try:
        payload = verify_jwt(token)
        return payload["id"]
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"JWT validation failed: {str(e)}")


@router.post("/profile", response_model=ProfileResponse)
async def upsert_profile(
    body: ProfileCreate,
    authorization: str = Header(...),
):
    """Create or update user profile. Called after signup or profile update."""
    authenticated_user_id = _require_auth(authorization)

    # Ensure the JWT owner matches the profile being written
    if authenticated_user_id != body.user_id:
        raise HTTPException(status_code=403, detail="Cannot modify another user's profile.")

    db = get_supabase()
    upsert_data = {
        "id": body.user_id,
        "full_name": body.full_name,
        "target_accent": body.target_accent,
        "current_level": body.level,
    }

    response = db.table("profiles").upsert(upsert_data).execute()
    if not response.data:
        raise HTTPException(status_code=500, detail="Failed to upsert profile.")

    return ProfileResponse(**response.data[0])


@router.get("/profile/{user_id}", response_model=ProfileResponse)
async def get_profile(
    user_id: str,
    authorization: str = Header(...),
):
    """Fetch a user's profile. Only the owner can fetch their profile."""
    authenticated_user_id = _require_auth(authorization)
    if authenticated_user_id != user_id:
        raise HTTPException(status_code=403, detail="Access denied.")

    db = get_supabase()
    response = db.table("profiles").select("*").eq("id", user_id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Profile not found. Please complete your profile setup.")

    # Since we used execute() without single(), data is a list
    profile_data = response.data[0]
    return ProfileResponse(**profile_data)


@router.patch("/profile/{user_id}", response_model=ProfileResponse)
async def update_profile(
    user_id: str,
    body: ProfileUpdate,
    authorization: str = Header(...),
):
    """Partially update profile fields (name, accent, level)."""
    authenticated_user_id = _require_auth(authorization)
    if authenticated_user_id != user_id:
        raise HTTPException(status_code=403, detail="Access denied.")

    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided to update.")

    db = get_supabase()
    response = db.table("profiles").update(updates).eq("id", user_id).execute()
    if not response.data:
        raise HTTPException(status_code=500, detail="Update failed.")

    return ProfileResponse(**response.data[0])
