import requests
import uuid

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_post_usersuserid_partner_toggle_partner_relationship():
    session = requests.Session()

    # Helper: Sign up a user with email
    def sign_up(email, password):
        url = f"{BASE_URL}/auth/signUpWithEmail"
        payload = {"email": email, "password": password}
        resp = session.post(url, json=payload, timeout=TIMEOUT)
        resp.raise_for_status()
        return resp.json()

    # Helper: Sign in a user with email
    def sign_in(email, password):
        url = f"{BASE_URL}/auth/signInWithEmail"
        payload = {"email": email, "password": password}
        resp = session.post(url, json=payload, timeout=TIMEOUT)
        resp.raise_for_status()
        return resp.json()

    # Helper: Delete user account for cleanup
    def delete_user(auth_token):
        url = f"{BASE_URL}/auth/deleteUser"
        headers = {"Authorization": f"Bearer {auth_token}"}
        resp = session.delete(url, headers=headers, timeout=TIMEOUT)
        # If recent login required, fail silently here, but test user is new so should work
        if resp.status_code not in (200, 400):
            resp.raise_for_status()

    # Create two users to toggle partner relationship
    email1 = f"testuser1_{uuid.uuid4().hex[:8]}@example.com"
    password1 = "TestPass123!"
    email2 = f"testuser2_{uuid.uuid4().hex[:8]}@example.com"
    password2 = "TestPass123!"

    user1 = None
    token1 = None
    user2 = None
    token2 = None

    try:
        # Sign up user1
        user1_cred = sign_up(email1, password1)
        token1 = user1_cred.get("token") or user1_cred.get("authToken")
        # If token not directly in response, sign in to get it
        if not token1:
            signin_resp = sign_in(email1, password1)
            token1 = signin_resp.get("token") or signin_resp.get("authToken")
        user1 = user1_cred.get("user") or signin_resp.get("user")
        user1_id = user1.get("uid") if user1 else None
        assert user1_id, "Failed to get user1 ID"

        # Sign up user2
        user2_cred = sign_up(email2, password2)
        token2 = user2_cred.get("token") or user2_cred.get("authToken")
        if not token2:
            signin_resp = sign_in(email2, password2)
            token2 = signin_resp.get("token") or signin_resp.get("authToken")
        user2 = user2_cred.get("user") or signin_resp.get("user")
        user2_id = user2.get("uid") if user2 else None
        assert user2_id, "Failed to get user2 ID"

        # Use user1 token to toggle partner relationship with user2 via POST /users/{userId}/partner
        url = f"{BASE_URL}/users/{user2_id}/partner"
        headers = {"Authorization": f"Bearer {token1}"}
        resp = session.post(url, headers=headers, timeout=TIMEOUT)

        assert resp.status_code == 200, f"Expected 200 OK, got {resp.status_code}"
        # Since response is void, no content expected
        assert not resp.content or resp.content == b''

        # Toggle back (optional) to verify toggle works again
        resp2 = session.post(url, headers=headers, timeout=TIMEOUT)
        assert resp2.status_code == 200
        assert not resp2.content or resp2.content == b''

    finally:
        # Cleanup both users
        if token1:
            try:
                delete_user(token1)
            except Exception:
                pass
        if token2:
            try:
                delete_user(token2)
            except Exception:
                pass

test_post_usersuserid_partner_toggle_partner_relationship()