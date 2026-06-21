import requests
import uuid

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_get_users_userid_success_user_not_found_unauthorized():
    # Setup - create a new user via signUpWithEmail and signInWithEmail to get userId and auth token
    email = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
    password = "TestPass123!"

    signup_url = f"{BASE_URL}/auth/signUpWithEmail"
    signin_url = f"{BASE_URL}/auth/signInWithEmail"

    signup_payload = {"email": email, "password": password}
    signin_payload = {"email": email, "password": password}

    headers = {"Content-Type": "application/json"}

    user_id = None
    token = None

    try:
        # Sign up the user
        r_signup = requests.post(signup_url, json=signup_payload, headers=headers, timeout=TIMEOUT)
        assert r_signup.status_code == 200, f"Signup failed: {r_signup.status_code} {r_signup.text}"

        # Sign in the user to get auth token and userId
        r_signin = requests.post(signin_url, json=signin_payload, headers=headers, timeout=TIMEOUT)
        assert r_signin.status_code == 200, f"Signin failed: {r_signin.status_code} {r_signin.text}"

        signin_data = r_signin.json()
        token = signin_data.get("token") or signin_data.get("authToken") or signin_data.get("idToken")
        user_cred = signin_data.get("user") or signin_data.get("userCredential") or {}
        user_id = user_cred.get("uid") or user_cred.get("userId") or user_cred.get("id")

        # Fallback if userId is not in userCredential, try alternative keys in the JSON
        if not user_id:
            for key in signin_data.keys():
                if isinstance(signin_data[key], dict):
                    user_id = signin_data[key].get("uid") or signin_data[key].get("userId") or user_cred.get("id")
                    if user_id:
                        break

        assert user_id, "Failed to obtain userId from signin response"
        assert token, "Failed to obtain auth token from signin response"

        auth_headers = {"Authorization": f"Bearer {token}"}

        # 1) GET /users/{userId} with valid token - expect 200 with UserModel
        user_url = f"{BASE_URL}/users/{user_id}"
        r_user = requests.get(user_url, headers=auth_headers, timeout=TIMEOUT)
        assert r_user.status_code == 200, f"Expected 200 for existing user, got {r_user.status_code} - {r_user.text}"
        user_data = r_user.json()
        assert isinstance(user_data, dict), "User response is not a JSON object"
        assert user_data.get("id") == user_id or user_data.get("uid") == user_id or user_data.get("userId") == user_id, "Returned userId does not match"

        # 2) GET /users/{nonExistentUserId} with valid token - expect 404
        fake_user_id = str(uuid.uuid4())
        fake_user_url = f"{BASE_URL}/users/{fake_user_id}"
        r_fake_user = requests.get(fake_user_url, headers=auth_headers, timeout=TIMEOUT)
        assert r_fake_user.status_code == 404, f"Expected 404 for non-existent user, got {r_fake_user.status_code} - {r_fake_user.text}"

        # 3) GET /users/{userId} without auth token - expect 401
        r_unauth = requests.get(user_url, timeout=TIMEOUT)
        assert r_unauth.status_code == 401, f"Expected 401 when no auth token provided, got {r_unauth.status_code} - {r_unauth.text}"

    finally:
        # Cleanup: delete the created user if possible via authenticated API
        if token:
            delete_url = f"{BASE_URL}/auth/deleteUser"
            delete_headers = {"Authorization": f"Bearer {token}"}
            try:
                r_delete = requests.delete(delete_url, headers=delete_headers, timeout=TIMEOUT)
                # 200 or 400 (requires recent login) are valid. Ignore error here.
            except Exception:
                pass


test_get_users_userid_success_user_not_found_unauthorized()