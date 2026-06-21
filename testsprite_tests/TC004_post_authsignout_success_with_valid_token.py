import requests

BASE_URL = "http://localhost:5001"

def test_post_auth_sign_out_success_with_valid_token():
    email = "testuser_signout@example.com"
    password = "TestPass123!"

    sign_up_url = f"{BASE_URL}/auth/signUpWithEmail"
    sign_in_url = f"{BASE_URL}/auth/signInWithEmail"
    sign_out_url = f"{BASE_URL}/auth/signOut"

    try:
        # Sign up the test user
        resp = requests.post(
            sign_up_url,
            json={"email": email, "password": password},
            timeout=30
        )
        assert resp.status_code == 200, f"Sign up failed: {resp.text}"

        # Sign in the test user to get auth token
        resp = requests.post(
            sign_in_url,
            json={"email": email, "password": password},
            timeout=30
        )
        assert resp.status_code == 200, f"Sign in failed: {resp.text}"
        data = resp.json()
        token = data.get("token")
        assert token, "Auth token not found in sign in response"

        headers = {
            "Authorization": f"Bearer {token}"
        }

        # Sign out with valid auth token
        sign_out_resp = requests.post(sign_out_url, headers=headers, timeout=30)
        assert sign_out_resp.status_code == 200, f"Sign out failed: {sign_out_resp.text}"
        # Response body is expected to be empty or void
        assert not sign_out_resp.content, "Expected empty response body on sign out"

    finally:
        # Cleanup: Sign in again to get token, then delete user account
        try:
            resp = requests.post(
                sign_in_url,
                json={"email": email, "password": password},
                timeout=30
            )
            if resp.status_code == 200:
                token = resp.json().get("token")
                if token:
                    delete_user_url = f"{BASE_URL}/auth/deleteUser"
                    headers = {"Authorization": f"Bearer {token}"}
                    del_resp = requests.delete(delete_user_url, headers=headers, timeout=30)
                    # If deletion requires recent login it might fail; ignore failures here
        except Exception:
            pass

test_post_auth_sign_out_success_with_valid_token()