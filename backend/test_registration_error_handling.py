import json
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:8000"

def test_short_business_name():
    print("\n--- Test 1: Short Business Name ('g') ---> HTTP 422 expected ---")
    payload = json.dumps({
        "business_name": "g",
        "email": "reg_validation_test@example.com",
        "password": "Password123!",
        "device_uuid": "dev-reg-val-001",
        "username": "reg_val_user",
        "full_name": "Validation Tester"
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/auth/register",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"FAILED: Expected 422, but got status {resp.status}")
            return False
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"SUCCESS: Received expected HTTP {e.code}: {body}")
        assert e.code == 422, f"Expected status code 422, got {e.code}"
        assert "business_name" in body or "string_too_short" in body, "Expected business_name validation error detail"
        return True

def test_valid_business_registration():
    print("\n--- Test 2: Valid Business Registration ('GM Hardware') ---> HTTP 200 expected ---")
    payload = json.dumps({
        "business_name": "GM Hardware",
        "email": "gm_valid_owner@example.com",
        "password": "Password123!",
        "device_uuid": "dev-reg-val-002",
        "username": "gm_valid_owner",
        "full_name": "GM Owner"
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{BASE_URL}/auth/register",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"SUCCESS: HTTP {resp.status}: {data}")
            assert "business_id" in data and "user_id" in data, "Response missing business_id or user_id"
            return data
    except urllib.error.HTTPError as e:
        print(f"FAILED: HTTPError {e.code}: {e.read().decode()}")
        return None

if __name__ == "__main__":
    t1 = test_short_business_name()
    t2 = test_valid_business_registration()
    if t1 and t2:
        print("\nAll Backend Registration Error Handling Tests PASSED!")
    else:
        print("\nBackend Registration Error Handling Tests FAILED!")
