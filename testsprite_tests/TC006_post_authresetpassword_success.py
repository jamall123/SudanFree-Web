import requests

BASE_URL = "http://localhost:5001"
TIMEOUT = 30

def test_post_authresetpassword_success():
    url = f"{BASE_URL}/auth/resetPassword"
    headers = {
        "Content-Type": "application/json"
    }
    # Use a valid email for password reset test
    payload = {
        "email": "validuser@example.com"
    }

    try:
        response = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        assert False, f"Request failed: {e}"

    # Assert status code is 200 and response body is empty (void)
    assert response.status_code == 200, f"Expected status code 200, got {response.status_code}"
    assert not response.content or response.content == b'' or response.text == '', "Expected empty response body"

test_post_authresetpassword_success()