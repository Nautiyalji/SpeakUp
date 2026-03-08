import httpx
import asyncio

async def test_auth_flow():
    base_url = "http://localhost:8000"
    client = httpx.AsyncClient(timeout=30.0)
    
    test_user = {
        "email": "testuser_automated@example.com",
        "password": "Password123!",
        "full_name": "Automated Tester",
        "target_accent": "Indian English",
        "level": "beginner"
    }

    print(f"Testing Sign Up for {test_user['email']}...")
    try:
        # Note: In a real scenario, this would go through Supabase. 
        # Here we are testing the backend profile upsert if the user already exists in Supabase 
        # or if we mock the auth. For a true E2E, we need the frontend to handle Supabase.
        # But we can test the /auth/profile endpoint which is part of our Phase 1.
        
        # 1. Upsert Profile
        response = await client.post(f"{base_url}/auth/profile", json={
            "user_id": "test-uuid-1234",
            "full_name": test_user["full_name"],
            "target_accent": test_user["target_accent"],
            "level": test_user["level"]
        })
        print(f"Upsert Profile Status: {response.status_code}")
        print(f"Upsert Profile Response: {response.json()}")

        # 2. Get Profile
        response = await client.get(f"{base_url}/auth/profile/test-uuid-1234")
        print(f"Get Profile Status: {response.status_code}")
        print(f"Get Profile Response: {response.json()}")

        # 3. Test Session Start
        response = await client.post(f"{base_url}/sessions/start", json={
            "user_id": "test-uuid-1234",
            "target_accent": "Indian English",
            "level": "beginner"
        })
        print(f"Start Session Status: {response.status_code}")
        # Note: This might trigger ML models, so it could be slow or fail if models aren't ready.
        
    except Exception as e:
        print(f"Error during test: {e}")
    finally:
        await client.aclose()

if __name__ == "__main__":
    asyncio.run(test_auth_flow())
