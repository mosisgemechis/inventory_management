"""
Automated validation script for backend authentication hash guards, staff multi-device login, and shop hard-deletion.
"""
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.database.session import SessionLocal
from app.models.identity import BackendUser, Business, RefreshToken
from app.services import auth_service

client = TestClient(app)

def test_unknown_hash_handling():
    print("\n--- TEST 1: Unknown/Corrupted Hash Handling ---")
    db = SessionLocal()
    try:
        biz_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        email = f"corrupt_{uuid.uuid4().hex[:6]}@test.com"

        biz = Business(
            id=biz_id,
            name="Corrupt Hash Test Business",
            email=email,
            password_hash=auth_service.hash_password("ValidPassword1!"),
            is_active=True
        )
        db.add(biz)

        corrupt_user = BackendUser(
            id=user_id,
            business_id=biz_id,
            name="Corrupt User",
            email=email,
            username=f"corrupt_{user_id[:6]}",
            password_hash="9e1894539a7bc89d123456789abcdef0123456789abcdef0123456789abcdef0",
            role="staff",
            is_active=True
        )
        db.add(corrupt_user)
        db.commit()

        r = client.post("/auth/login", json={
            "email": email,
            "password": "Password123!",
            "device_uuid": "test-device-uuid"
        })

        assert r.status_code == 401, f"Expected 401 Unauthorized, got {r.status_code}: {r.text}"
        print("OK: Corrupted/Non-bcrypt hash login handled cleanly with 401 Unauthorized (No 500 crash)")

    finally:
        db.close()

def test_sync_staff_creation_and_remote_login():
    print("\n--- TEST 2: Sync Staff Creation & Remote Device Login by Username ---")
    db = SessionLocal()
    try:
        biz_id = str(uuid.uuid4())
        staff_id = str(uuid.uuid4())
        admin_email = f"admin_{uuid.uuid4().hex[:6]}@shop.com"
        staff_username = f"StaffUser_{uuid.uuid4().hex[:4]}"

        biz = Business(
            id=biz_id,
            name="Multi Device Shop",
            email=admin_email,
            password_hash=auth_service.hash_password("AdminPass1!"),
            is_active=True
        )
        db.add(biz)
        db.commit()

        # 1. Simulate USER_CREATED sync event from Admin Device A
        event_payload = {
            "shopId": biz_id,
            "deviceId": "admin-device-a",
            "events": [
                {
                    "id": str(uuid.uuid4()),
                    "business_id": biz_id,
                    "device_id": "admin-device-a",
                    "user_id": staff_id,
                    "event_type": "USER_CREATED",
                    "entity_type": "users",
                    "entity_id": staff_id,
                    "payload": {
                        "uid": staff_id,
                        "username": staff_username,
                        "email": "", # empty or missing email
                        "fullName": "Staff User",
                        "role": "inventoryStaff",
                        "password": "StaffSecret123!",
                        "shopId": biz_id,
                        "isActive": True
                    }
                }
            ]
        }

        r_sync = client.post("/sync/events", json=event_payload)
        assert r_sync.status_code == 200, f"Expected 200 OK for sync event, got {r_sync.status_code}: {r_sync.text}"

        # 2. Staff logs in on Remote Device B using ONLY username and staff password
        r_login = client.post("/auth/login", json={
            "email": staff_username,  # Staff enters username in login box
            "password": "StaffSecret123!",
            "device_uuid": "remote-device-b"
        })
        assert r_login.status_code == 200, f"Staff login from remote device failed: {r_login.text}"
        data = r_login.json()
        assert data["user"]["id"] == staff_id
        assert data["business"]["id"] == biz_id
        print(f"OK: Staff '{staff_username}' successfully logged in on Remote Device B!")

        return biz_id, data["access_token"], data["refresh_token"]

    finally:
        db.close()

def test_shop_hard_deletion_and_multi_device_invalidation(biz_id, access_token, refresh_token):
    print("\n--- TEST 3: Shop Hard Deletion & Multi-Device Invalidation ---")
    db = SessionLocal()
    try:
        # Simulate SHOP_DELETED sync event from Admin Device A
        event_payload = {
            "shopId": biz_id,
            "deviceId": "admin-device-a",
            "events": [
                {
                    "id": str(uuid.uuid4()),
                    "business_id": biz_id,
                    "device_id": "admin-device-a",
                    "user_id": biz_id,
                    "event_type": "SHOP_DELETED",
                    "entity_type": "shops",
                    "entity_id": biz_id,
                    "payload": {
                        "shopId": biz_id,
                        "business_id": biz_id,
                        "event_type": "SHOP_DELETED"
                    }
                }
            ]
        }

        r_del = client.post("/sync/events", json=event_payload)
        assert r_del.status_code == 200, f"Expected 200 OK for shop deletion event, got {r_del.status_code}: {r_del.text}"

        # Verify Business and Users are HARD DELETED from backend database
        db.expire_all()
        biz_check = db.query(Business).filter(Business.id == biz_id).first()
        users_check = db.query(BackendUser).filter(BackendUser.business_id == biz_id).all()
        assert biz_check is None, "Business was not hard-deleted from database"
        assert len(users_check) == 0, "Users were not hard-deleted from database"
        print("OK: Business & Users completely hard-deleted from PostgreSQL database!")

        # Verify Remote Device B is rejected when attempting token refresh
        r_ref = client.post("/auth/refresh", json={
            "refresh_token": refresh_token,
            "device_uuid": "remote-device-b"
        })
        assert r_ref.status_code == 401, f"Expected 401 Unauthorized for deleted business refresh, got {r_ref.status_code}"
        print("OK: Remote Device B refresh rejected with 401 Unauthorized (forcing local wipe and logout)")

        # Verify Remote Device B is rejected when attempting sync pull
        r_pull = client.get(f"/sync/pull?shopId={biz_id}", headers={"Authorization": f"Bearer {access_token}"})
        assert r_pull.status_code == 401, f"Expected 401 Unauthorized for deleted business sync pull, got {r_pull.status_code}"
        print("OK: Remote Device B sync pull rejected with 401 Unauthorized (forcing local wipe and logout)")

    finally:
        db.close()

if __name__ == "__main__":
    test_unknown_hash_handling()
    biz_id, access_token, refresh_token = test_sync_staff_creation_and_remote_login()
    test_shop_hard_deletion_and_multi_device_invalidation(biz_id, access_token, refresh_token)
    print("\nALL AUTH, MULTI-DEVICE & DELETION TESTS PASSED SUCCESSFULLY!")
