import requests
import uuid

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_put_usersuserid_update_profile_success():
    # Test data for signing up and signing in
    random_suffix = uuid.uuid4().hex[:8]
    email = f"testuser_{random_suffix}@example.com"
    password = "TestPassword123!"
    signup_url = f"{BASE_URL}/auth/signUpWithEmail"
    signin_url = f"{BASE_URL}/auth/signInWithEmail"

    headers = {"Content-Type": "application/json"}

    # Sign up new user
    signup_payload = {"email": email, "password": password}
    signup_resp = requests.post(signup_url, json=signup_payload, headers=headers, timeout=TIMEOUT)
    assert signup_resp.status_code == 200, f"SignUp failed: {signup_resp.text}"
    # No specific field check because structure is not defined

    # Sign in to get auth token and userId
    signin_payload = {"email": email, "password": password}
    signin_resp = requests.post(signin_url, json=signin_payload, headers=headers, timeout=TIMEOUT)
    assert signin_resp.status_code == 200, f"SignIn failed: {signin_resp.text}"
    signin_data = signin_resp.json()
    token = signin_data.get("token") or signin_data.get("authToken") or signin_data.get("accessToken")
    user_id = signin_data.get("userId") or signin_data.get("uid")

    assert token, "Auth token missing in sign in response"
    assert user_id, "User ID missing in sign in response"

    auth_headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    # Prepare update profile payload
    update_payload = {
        "name": "Test User Updated",
        "bio": "Updated bio for test user",
        "skills": ["python", "firebase", "flutter"],
        "location": "Khartoum, Sudan"
    }

    user_url = f"{BASE_URL}/users/{user_id}"

    try:
        # Update user profile
        update_resp = requests.put(user_url, json=update_payload, headers=auth_headers, timeout=TIMEOUT)
        assert update_resp.status_code == 200, f"Update profile failed: {update_resp.text}"
        # Response body is expected to be void/empty, so no json parse needed, but ensure empty or no content
        assert not update_resp.content or update_resp.content == b"" or update_resp.text == "", "Expected empty response body on update"

    finally:
        # Clean up: delete the created user account
        delete_url = f"{BASE_URL}/auth/deleteUser"
        # Deletion requires auth token and recent login assumed from sign in (the token)
        del_resp = requests.delete(delete_url, headers=auth_headers, timeout=TIMEOUT)
        # Accept 200 void for successful delete
        assert del_resp.status_code == 200, f"User deletion failed: {del_resp.text}"

test_put_usersuserid_update_profile_success()
