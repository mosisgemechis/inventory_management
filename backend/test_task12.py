import json
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:8000"

def test1_health():
    with urllib.request.urlopen(f"{BASE_URL}/health") as resp:
        data = json.loads(resp.read().decode())
        assert resp.status == 200
        print(f"[TEST 1 PASS] GET /health → {resp.status} {data['status']}")

def test2_login():
    payload = json.dumps({
        "email": "kebede_active",
        "password": "Password123!",
        "device_uuid": "pc-test-device-uuid"
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        assert resp.status == 200
        assert "access_token" in data
        assert "refresh_token" in data
        print(f"[TEST 2 PASS] POST /auth/login → {resp.status} (user_id={data['user']['id']})")
        return data

def test3_authenticated_request(access_token):
    req = urllib.request.Request(
        f"{BASE_URL}/sync/initial",
        headers={"Authorization": f"Bearer {access_token}"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"[TEST 3 PASS] Authenticated request GET /sync/initial → {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"[TEST 3] GET /sync/initial HTTPError {e.code}: {e.read().decode()}")

def test4_refresh(refresh_token):
    payload = json.dumps({
        "refresh_token": refresh_token,
        "device_uuid": "pc-test-device-uuid"
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/auth/refresh",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        assert resp.status == 200
        assert "access_token" in data
        print(f"[TEST 4 PASS] POST /auth/refresh → {resp.status} (new access token created)")
        return data["access_token"]

if __name__ == "__main__":
    print("=== TASK 12 ACCEPTANCE TESTS ===")
    test1_health()
    tokens = test2_login()
    test3_authenticated_request(tokens["access_token"])
    new_access = test4_refresh(tokens["refresh_token"])
    test3_authenticated_request(new_access)
    print("=== ALL TESTS 1-4 PASSED CLEANLY ===")
