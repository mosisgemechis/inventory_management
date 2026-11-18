import json
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:8000"

def test_register():
    payload = json.dumps({
        "business_name": "Test Shop Kebede",
        "email": "kebede_active@test.com",
        "password": "Password123!",
        "device_uuid": "device-uuid-active-001",
        "username": "kebede_active",
        "full_name": "Kebede Active User"
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/auth/register",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"[TEST REGISTER] status {resp.status}: {data}")
            return data
    except urllib.error.HTTPError as e:
        print(f"[TEST REGISTER] HTTPError {e.code}: {e.read().decode()}")
    except Exception as e:
        print(f"[TEST REGISTER] Error: {e}")
    return None

def test_login(email, password):
    payload = json.dumps({
        "email": email,
        "password": password,
        "device_uuid": "device-uuid-active-001"
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"[TEST LOGIN] status {resp.status}: SUCCESS access_token len={len(data['access_token'])}, refresh_token len={len(data['refresh_token'])}")
            return data
    except urllib.error.HTTPError as e:
        print(f"[TEST LOGIN] HTTPError {e.code}: {e.read().decode()}")
    except Exception as e:
        print(f"[TEST LOGIN] Error: {e}")
    return None

def test_refresh(refresh_token):
    payload = json.dumps({
        "refresh_token": refresh_token,
        "device_uuid": "device-uuid-active-001"
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/auth/refresh",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"[TEST REFRESH] status {resp.status}: SUCCESS new_access_token len={len(data['access_token'])}")
            return data
    except urllib.error.HTTPError as e:
        print(f"[TEST REFRESH] HTTPError {e.code}: {e.read().decode()}")
    except Exception as e:
        print(f"[TEST REFRESH] Error: {e}")
    return None

if __name__ == "__main__":
    reg = test_register()
    login_res = test_login("kebede_active", "Password123!")
    if login_res:
        test_refresh(login_res["refresh_token"])
