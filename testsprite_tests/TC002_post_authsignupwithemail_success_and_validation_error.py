import requests
import uuid

BASE_URL = "http://localhost:5001"
TIMEOUT = 30
HEADERS = {"Content-Type": "application/json"}


def test_post_auth_signup_with_email_success_and_validation_error():
    url = f"{BASE_URL}/auth/signUpWithEmail"

    # Successful registration test
    unique_email = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
    valid_payload = {
        "email": unique_email,
        "password": "ValidPass123!"
    }

    try:
        response = requests.post(url, json=valid_payload, headers=HEADERS, timeout=TIMEOUT)
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        json_data = response.json()
        assert isinstance(json_data, dict), "Response should be a JSON object"
        # Basic checks for UserCredential presence (typically contains user info and token)
        assert "user" in json_data or "token" in json_data or "idToken" in json_data, "Response missing expected UserCredential fields"

        # Validation error tests
        invalid_payloads = [
            # Missing email
            {"password": "somepassword"},
            # Missing password
            {"email": "user@example.com"},
            # Empty email
            {"email": "", "password": "somepassword"},
            # Empty password
            {"email": "user@example.com", "password": ""},
            # Invalid email format
            {"email": "invalid-email-format", "password": "somepassword"},
            # Password too short
            {"email": "user2@example.com", "password": "123"},
        ]

        for payload in invalid_payloads:
            resp = requests.post(url, json=payload, headers=HEADERS, timeout=TIMEOUT)
            assert resp.status_code == 400, f"Expected 400 for payload {payload}, got {resp.status_code}"
            # Optionally check error message structure for validation errors
            try:
                err_json = resp.json()
                assert "error" in err_json or "message" in err_json or "validation" in err_json, "Validation error detail missing"
            except Exception:
                # response might not be json; considered failure
                assert False, f"Validation error response not JSON for payload {payload}"

    finally:
        # Attempt to clean up user if created (delete not specified in test but good hygiene)
        # Need to login to get token and delete user - but no recent login mechanism is defined here
        # Safe to skip deletion or add if tokens and deletion possible.
        pass


test_post_auth_signup_with_email_success_and_validation_error()