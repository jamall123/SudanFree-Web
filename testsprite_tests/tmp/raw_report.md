
# TestSprite AI Testing Report(MCP)

---

## 1️⃣ Document Metadata
- **Project Name:** sudan_free
- **Date:** 2026-02-24
- **Prepared by:** TestSprite AI Team

---

## 2️⃣ Requirement Validation Summary

#### Test TC001 post authsigninwithgoogle success and failure
- **Test Code:** [TC001_post_authsigninwithgoogle_success_and_failure.py](./TC001_post_authsigninwithgoogle_success_and_failure.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 26, in <module>
  File "<string>", line 16, in test_post_authsigninwithgoogle_success
AssertionError: Expected 200 OK for success case, got 404

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/6bbb9182-63ab-4392-9c8d-c642399d8267
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC002 post authsignupwithemail success and validation error
- **Test Code:** [TC002_post_authsignupwithemail_success_and_validation_error.py](./TC002_post_authsignupwithemail_success_and_validation_error.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 61, in <module>
  File "<string>", line 21, in test_post_auth_signup_with_email_success_and_validation_error
AssertionError: Expected 200, got 404

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/68a9bfe6-cb63-4424-af23-2a8b8535af22
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC003 post authsigninwithemail success and invalid credentials
- **Test Code:** [TC003_post_authsigninwithemail_success_and_invalid_credentials.py](./TC003_post_authsigninwithemail_success_and_invalid_credentials.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 60, in <module>
  File "<string>", line 20, in test_post_authsigninwithemail_success_and_invalid_credentials
AssertionError: Expected 200 for valid credentials but got 404

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/106ed5a6-f033-45ac-923f-99adf7c43d77
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC004 post authsignout success with valid token
- **Test Code:** [TC004_post_authsignout_success_with_valid_token.py](./TC004_post_authsignout_success_with_valid_token.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 61, in <module>
  File "<string>", line 20, in test_post_auth_sign_out_success_with_valid_token
AssertionError: Sign up failed: Not Found

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/eaa3163b-7f9e-4f8f-be84-39909a0eb118
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC005 delete authdeleteuser success and requires recent login
- **Test Code:** [TC005_delete_authdeleteuser_success_and_requires_recent_login.py](./TC005_delete_authdeleteuser_success_and_requires_recent_login.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 95, in <module>
  File "<string>", line 17, in test_delete_authdeleteuser_success_and_requires_recent_login
AssertionError: Sign up failed: Not Found

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/df77bc3d-f01d-45d2-aec9-fa59facaed3d
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC006 post authresetpassword success
- **Test Code:** [TC006_post_authresetpassword_success.py](./TC006_post_authresetpassword_success.py)
- **Test Error:** Traceback (most recent call last):
  File "<string>", line 18, in test_post_authresetpassword_success
  File "/var/task/requests/models.py", line 1024, in raise_for_status
    raise HTTPError(http_error_msg, response=self)
requests.exceptions.HTTPError: 404 Client Error: Not Found for url: http://localhost:5001/auth/resetPassword

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 26, in <module>
  File "<string>", line 20, in test_post_authresetpassword_success
AssertionError: Request failed: 404 Client Error: Not Found for url: http://localhost:5001/auth/resetPassword

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/20e96cf4-5322-4d31-b13b-20c617832367
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC007 get usersuserid success user not found unauthorized
- **Test Code:** [TC007_get_usersuserid_success_user_not_found_unauthorized.py](./TC007_get_usersuserid_success_user_not_found_unauthorized.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 80, in <module>
  File "<string>", line 26, in test_get_users_userid_success_user_not_found_unauthorized
AssertionError: Signup failed: 404 Not Found

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/d0a3c86c-fb09-41e5-b418-92e328699a6e
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC008 put usersuserid update profile success
- **Test Code:** [TC008_put_usersuserid_update_profile_success.py](./TC008_put_usersuserid_update_profile_success.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/urllib3/connectionpool.py", line 787, in urlopen
    response = self._make_request(
               ^^^^^^^^^^^^^^^^^^^
  File "/var/task/urllib3/connectionpool.py", line 534, in _make_request
    response = conn.getresponse()
               ^^^^^^^^^^^^^^^^^^
  File "/var/task/urllib3/connection.py", line 565, in getresponse
    httplib_response = super().getresponse()
                       ^^^^^^^^^^^^^^^^^^^^^
  File "/var/lang/lib/python3.12/http/client.py", line 1430, in getresponse
    response.begin()
  File "/var/lang/lib/python3.12/http/client.py", line 331, in begin
    version, status, reason = self._read_status()
                              ^^^^^^^^^^^^^^^^^^^
  File "/var/lang/lib/python3.12/http/client.py", line 292, in _read_status
    line = str(self.fp.readline(_MAXLINE + 1), "iso-8859-1")
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/var/lang/lib/python3.12/socket.py", line 720, in readinto
    return self._sock.recv_into(b)
           ^^^^^^^^^^^^^^^^^^^^^^^
ConnectionResetError: [Errno 104] Connection reset by peer

The above exception was the direct cause of the following exception:

urllib3.exceptions.ProxyError: ('Unable to connect to proxy', ConnectionResetError(104, 'Connection reset by peer'))

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/var/task/requests/adapters.py", line 667, in send
    resp = conn.urlopen(
           ^^^^^^^^^^^^^
  File "/var/task/urllib3/connectionpool.py", line 841, in urlopen
    retries = retries.increment(
              ^^^^^^^^^^^^^^^^^^
  File "/var/task/urllib3/util/retry.py", line 519, in increment
    raise MaxRetryError(_pool, url, reason) from reason  # type: ignore[arg-type]
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
urllib3.exceptions.MaxRetryError: HTTPConnectionPool(host='tun.testsprite.com', port=8080): Max retries exceeded with url: http://localhost:5001/auth/signUpWithEmail (Caused by ProxyError('Unable to connect to proxy', ConnectionResetError(104, 'Connection reset by peer')))

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 64, in <module>
  File "<string>", line 19, in test_put_usersuserid_update_profile_success
  File "/var/task/requests/api.py", line 115, in post
    return request("post", url, data=data, json=json, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/var/task/requests/api.py", line 59, in request
    return session.request(method=method, url=url, **kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/var/task/requests/sessions.py", line 589, in request
    resp = self.send(prep, **send_kwargs)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/var/task/requests/sessions.py", line 703, in send
    r = adapter.send(request, **kwargs)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/var/task/requests/adapters.py", line 694, in send
    raise ProxyError(e, request=request)
requests.exceptions.ProxyError: HTTPConnectionPool(host='tun.testsprite.com', port=8080): Max retries exceeded with url: http://localhost:5001/auth/signUpWithEmail (Caused by ProxyError('Unable to connect to proxy', ConnectionResetError(104, 'Connection reset by peer')))

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/ebeb9a73-ad0f-4c15-a712-89a4f73fcdc1
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC009 get usersfreelancers list with skill filter
- **Test Code:** [TC009_get_usersfreelancers_list_with_skill_filter.py](./TC009_get_usersfreelancers_list_with_skill_filter.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 67, in <module>
  File "<string>", line 16, in test_get_users_freelancers_list_with_skill_filter
AssertionError: Signup failed: Not Found

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/7c7d7e21-8230-4b55-b487-ab820cb7d5f6
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---

#### Test TC010 post usersuseridpartner toggle partner relationship
- **Test Code:** [TC010_post_usersuseridpartner_toggle_partner_relationship.py](./TC010_post_usersuseridpartner_toggle_partner_relationship.py)
- **Test Error:** Traceback (most recent call last):
  File "/var/task/handler.py", line 258, in run_with_retry
    exec(code, exec_env)
  File "<string>", line 95, in <module>
  File "<string>", line 48, in test_post_usersuserid_partner_toggle_partner_relationship
  File "<string>", line 15, in sign_up
  File "/var/task/requests/models.py", line 1024, in raise_for_status
    raise HTTPError(http_error_msg, response=self)
requests.exceptions.HTTPError: 404 Client Error: Not Found for url: http://localhost:5001/auth/signUpWithEmail

- **Test Visualization and Result:** https://www.testsprite.com/dashboard/mcp/tests/c3dc9a3e-08fc-4a42-98b4-07bd87b9c15f/87002241-ab73-4949-b721-7c8af4c01287
- **Status:** ❌ Failed
- **Analysis / Findings:** {{TODO:AI_ANALYSIS}}.
---


## 3️⃣ Coverage & Matching Metrics

- **0.00** of tests passed

| Requirement        | Total Tests | ✅ Passed | ❌ Failed  |
|--------------------|-------------|-----------|------------|
| ...                | ...         | ...       | ...        |
---


## 4️⃣ Key Gaps / Risks
{AI_GNERATED_KET_GAPS_AND_RISKS}
---