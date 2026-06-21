import requests
import uuid

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_get_users_freelancers_list_with_skill_filter():
    # Step 1: Sign in a user with email and password to get auth token
    signin_url = f"{BASE_URL}/auth/signInWithEmail"
    test_email = f"tester_{uuid.uuid4().hex[:8]}@example.com"
    test_password = "TestPass123!"
    # First, create user to ensure valid login
    signup_url = f"{BASE_URL}/auth/signUpWithEmail"
    signup_payload = {"email": test_email, "password": test_password}
    signup_resp = requests.post(signup_url, json=signup_payload, timeout=TIMEOUT)
    assert signup_resp.status_code == 200, f"Signup failed: {signup_resp.text}"

    signin_payload = {"email": test_email, "password": test_password}
    signin_resp = requests.post(signin_url, json=signin_payload, timeout=TIMEOUT)
    assert signin_resp.status_code == 200, f"Signin failed: {signin_resp.text}"
    signin_data = signin_resp.json()
    token = signin_data.get("token")
    user_id = signin_data.get("userId")
    assert token, "Auth token missing in signin response"
    assert user_id, "User ID missing in signin response"

    headers = {"Authorization": f"Bearer {token}"}

    # Step 2: Update user profile with a skill to test filter properly
    update_url = f"{BASE_URL}/users/{user_id}"
    skills = ["plumbing", "painting"]
    update_payload = {
        "name": "Test User",
        "bio": "Bio for test user",
        "skills": skills,
        "location": "Khartoum"
    }
    update_resp = requests.put(update_url, json=update_payload, headers=headers, timeout=TIMEOUT)
    assert update_resp.status_code == 200, f"Failed to update user profile: {update_resp.text}"

    try:
        # Step 3: Call GET /users/freelancers with skill filter query q=skill:plumbing
        freelancers_url = f"{BASE_URL}/users/freelancers"
        params = {"q": "skill:plumbing"}
        freelancers_resp = requests.get(freelancers_url, headers=headers, params=params, timeout=TIMEOUT)
        assert freelancers_resp.status_code == 200, f"Failed to list freelancers: {freelancers_resp.text}"

        freelancers_data = freelancers_resp.json()
        assert isinstance(freelancers_data, list), "Response is not a list"
        # Assert at least one user returned has the plumbing skill
        plumbing_found = False
        for user in freelancers_data:
            user_skills = user.get("skills", [])
            if "plumbing" in user_skills:
                plumbing_found = True
                break
        assert plumbing_found, "No freelancer with plumbing skill found in response"

    finally:
        # Cleanup: Delete the created user
        delete_url = f"{BASE_URL}/auth/deleteUser"
        delete_resp = requests.delete(delete_url, headers=headers, timeout=TIMEOUT)
        # Deletion might require recent login, ignore failure for clean up
        if delete_resp.status_code not in [200, 400]:
            raise AssertionError(f"Unexpected response on user deletion: {delete_resp.status_code} {delete_resp.text}")

test_get_users_freelancers_list_with_skill_filter()