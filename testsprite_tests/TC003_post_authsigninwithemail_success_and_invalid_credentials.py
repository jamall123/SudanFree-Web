import requests

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_post_authsigninwithemail_success_and_invalid_credentials():
    signin_url = f"{BASE_URL}/auth/signInWithEmail"
    
    # Test valid credentials
    valid_email = "testuser@example.com"
    valid_password = "TestPassword123!"
    
    try:
        # Attempt successful login with valid credentials
        valid_payload = {
            "email": valid_email,
            "password": valid_password
        }
        resp_valid = requests.post(signin_url, json=valid_payload, timeout=TIMEOUT)
        assert resp_valid.status_code == 200, f"Expected 200 for valid credentials but got {resp_valid.status_code}"
        json_valid = resp_valid.json()
        # Validate that UserCredential and auth token exist in response
        assert isinstance(json_valid, dict), "Response is not a JSON object"
        # Typical UserCredential might contain user info and token keys; we check for token presence
        assert ("token" in json_valid) or ("authToken" in json_valid) or ("accessToken" in json_valid) or ("idToken" in json_valid), \
            "Auth token not found in successful login response"
        # We expect some user-related info, e.g., uid, email etc.
        assert "user" in json_valid or "uid" in json_valid or "email" in json_valid, "User info not found in response"

    except requests.exceptions.RequestException as e:
        assert False, f"Exception during valid signin request: {e}"
    
    # Test invalid credentials
    invalid_email = "invaliduser@example.com"
    invalid_password = "InvalidPassword!"
    try:
        invalid_payload = {
            "email": invalid_email,
            "password": invalid_password
        }
        resp_invalid = requests.post(signin_url, json=invalid_payload, timeout=TIMEOUT)
        assert resp_invalid.status_code == 401, f"Expected 401 for invalid credentials but got {resp_invalid.status_code}"
        # Optionally check response content for error message
        try:
            err_json = resp_invalid.json()
            if isinstance(err_json, dict):
                # Typical error message key check
                if "error" in err_json:
                    assert "invalid" in str(err_json["error"]).lower() or "unauthorized" in str(err_json["error"]).lower(), \
                        "Error message does not indicate invalid credentials"
                elif "message" in err_json:
                    assert "invalid" in str(err_json["message"]).lower() or "unauthorized" in str(err_json["message"]).lower(), \
                        "Error message does not indicate invalid credentials"
        except Exception:
            # If response is not JSON, ignore
            pass
    except requests.exceptions.RequestException as e:
        assert False, f"Exception during invalid signin request: {e}"

test_post_authsigninwithemail_success_and_invalid_credentials()