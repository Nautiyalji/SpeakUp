"""
Supabase admin client singleton.
Uses the SERVICE_KEY (backend only) for elevated access to bypass RLS when needed.
NEVER expose this key to the frontend.
"""
import os
from supabase import create_client, Client

_client: Client | None = None


def get_supabase() -> Client:
    """Returns a cached Supabase admin client."""
    global _client
    if _client is None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_SERVICE_KEY")
        if not url or not key:
            raise RuntimeError(
                "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env"
            )
        _client = create_client(url, key)
    return _client


def verify_jwt(token: str) -> dict:
    """
    Verify a Supabase JWT and return the decoded user payload.
    Raises an exception if the token is invalid.
    """
    client = get_supabase()
    response = client.auth.get_user(token)
    if not response or not response.user:
        raise ValueError("Invalid or expired JWT token.")
    return {"id": response.user.id, "email": response.user.email}
