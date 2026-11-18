"""
End-to-end smoke test for the Identity Layer (Phase 2).
Uses FastAPI TestClient so no running server is needed.
"""
import sys, warnings
warnings.filterwarnings("ignore")

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

DEVICE_UUID = "test-device-uuid-001"

def test_health():
    r = client.get("/health")
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "healthy"
    print("OK: GET /health")

import uuid
TEST_EMAIL = f"owner_{uuid.uuid4().hex[:6]}@acme.test"

def test_check_email():
    # 1. Check unused email -> exists=False
    r = client.get(f"/auth/check-email?email={TEST_EMAIL}")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["exists"] == False
    print("OK: GET /auth/check-email (unused) -> exists=False")

def test_register():
    r = client.post("/auth/register", json={
        "business_name": "Acme Store",
        "email": TEST_EMAIL,
        "password": "SecurePass1!",
        "phone": "+251911000000",
        "device_uuid": DEVICE_UUID,
        "device_name": "Office PC",
        "platform": "windows",
    })
    assert r.status_code == 201, r.text
    data = r.json()
    assert "business_id" in data
    assert "user_id" in data
    assert "device_id" in data
    assert "branch_id" in data
    print(f"OK: POST /auth/register — business_id={data['business_id'][:8]}")

    # Verify check-email now returns exists=True
    r_check = client.get(f"/auth/check-email?email={TEST_EMAIL}")
    assert r_check.status_code == 200, r_check.text
    assert r_check.json()["exists"] == True
    print("OK: GET /auth/check-email (registered) -> exists=True")
    return data

def test_duplicate_register():
    r = client.post("/auth/register", json={
        "business_name": "Acme Store Dupe",
        "email": TEST_EMAIL,
        "password": "SecurePass1!",
        "device_uuid": "dupe-device",
    })
    assert r.status_code == 409, r.text
    assert "already exists" in r.json()["detail"]
    print("OK: Duplicate register -> 409 Conflict")

def test_login(identity):
    r = client.post("/auth/login", json={
        "email": TEST_EMAIL,
        "password": "SecurePass1!",
        "device_uuid": DEVICE_UUID,
        "device_name": "Office PC",
        "platform": "windows",
    })
    assert r.status_code == 200, r.text
    data = r.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["role"] == "admin"
    assert data["business"]["id"] == identity["business_id"]
    print(f"OK: POST /auth/login — token starts: {data['access_token'][:20]}")
    return data

def test_invalid_login():
    r = client.post("/auth/login", json={
        "email": TEST_EMAIL,
        "password": "WRONG_PASSWORD",
        "device_uuid": DEVICE_UUID,
    })
    assert r.status_code == 401, r.text
    print("OK: Invalid login -> 401")

def test_refresh(tokens):
    r = client.post("/auth/refresh", json={
        "refresh_token": tokens["refresh_token"],
        "device_uuid": DEVICE_UUID,
    })
    assert r.status_code == 200, r.text
    data = r.json()
    assert "access_token" in data
    print(f"OK: POST /auth/refresh — new token starts: {data['access_token'][:20]}")

def test_device_register(identity, tokens):
    r = client.post("/devices/register", json={
        "business_id": identity["business_id"],
        "user_id": tokens["user"]["id"],
        "device_uuid": DEVICE_UUID,
        "device_name": "Office PC",
        "platform": "windows",
    })
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["device_uuid"] == DEVICE_UUID
    print(f"OK: POST /devices/register — device_id={data['id'][:8]}")

def test_device_heartbeat():
    r = client.post("/devices/heartbeat", json={"device_uuid": DEVICE_UUID})
    assert r.status_code == 204, r.text
    print("OK: POST /devices/heartbeat")

def test_logout(tokens):
    r = client.post("/auth/logout", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 204, r.text
    print("OK: POST /auth/logout")

def test_refresh_after_logout(tokens):
    r = client.post("/auth/refresh", json={
        "refresh_token": tokens["refresh_token"],
        "device_uuid": DEVICE_UUID,
    })
    assert r.status_code == 401, r.text
    print("OK: Refresh after logout -> 401")

if __name__ == "__main__":
    test_health()
    test_check_email()
    identity = test_register()
    test_duplicate_register()
    tokens = test_login(identity)
    test_invalid_login()
    test_refresh(tokens)
    test_device_register(identity, tokens)
    test_device_heartbeat()
    test_logout(tokens)
    test_refresh_after_logout(tokens)
    print("\nALL IDENTITY LAYER TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
