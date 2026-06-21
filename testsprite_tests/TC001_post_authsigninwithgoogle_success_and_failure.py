import requests

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_post_authsigninwithgoogle_success():
    url = f"{BASE_URL}/auth/signInWithGoogle"
    headers = {"Content-Type": "application/json"}

    # Success case: no request body as per PRD
    try:
        response = requests.post(url, headers=headers, timeout=TIMEOUT)
    except requests.RequestException as e:
        assert False, f"Request failed unexpectedly for success case: {e}"

    assert response.status_code == 200, f"Expected 200 OK for success case, got {response.status_code}"
    try:
        json_data = response.json()
    except ValueError:
        assert False, "Response is not valid JSON for success case"

    assert "userId" in json_data or "uid" in json_data or "token" in json_data, (
        "Response JSON missing expected UserCredential fields"
    )

test_post_authsigninwithgoogle_success()
