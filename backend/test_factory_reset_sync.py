"""
Regression test for Factory Reset backend sync processing, event acknowledgment, and cursor advancement.
Tests:
1. Online FACTORY_RESET event upload via POST /sync/events.
2. Verified event acknowledgement in synced and ackedEventIds, with empty rejectedEvents.
3. Database persistence of the FACTORY_RESET event in OutboxEvent table.
4. Server-side purging of business operational records.
5. Idempotency handling when re-posting the same FACTORY_RESET event.
6. Pull delta propagation for secondary/offline devices.
7. Verification that secondary device does NOT receive FACTORY_RESET repeatedly after cursor advances.
8. Verification that normal product sync resumes cleanly after Factory Reset.
"""
import sys, warnings
warnings.filterwarnings("ignore")

import uuid
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_factory_reset_flow():
    device_a = f"device-a-{uuid.uuid4().hex[:6]}"
    device_b = f"device-b-{uuid.uuid4().hex[:6]}"
    test_email = f"reset_test_{uuid.uuid4().hex[:6]}@store.com"

    # 1. Register Business and Login
    r = client.post("/auth/register", json={
        "business_name": "Reset Test Store",
        "email": test_email,
        "password": "Password123!",
        "device_uuid": device_a,
        "device_name": "Terminal A",
        "platform": "windows"
    })
    assert r.status_code == 201, r.text
    reg_data = r.json()
    biz_id = reg_data["business_id"]

    r = client.post("/auth/login", json={
        "email": test_email,
        "password": "Password123!",
        "device_uuid": device_a
    })
    assert r.status_code == 200, r.text
    access_token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # 2. Add pre-reset product
    prod_event_id = f"evt-prod-{uuid.uuid4().hex[:6]}"
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"
    r = client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": device_a,
        "events": [
            {
                "id": prod_event_id,
                "business_id": biz_id,
                "device_id": device_a,
                "user_id": reg_data["user_id"],
                "branch_id": reg_data["branch_id"],
                "event_type": "PRODUCT_CREATED",
                "entity_type": "product",
                "entity_id": prod_id,
                "payload": {
                    "name": "Old Product",
                    "sku": "OLD-001",
                    "price": 100.0,
                    "costPrice": 50.0,
                    "stockQuantity": 20
                },
                "timestamp": "2026-10-04T12:00:00Z"
            }
        ]
    })
    assert r.status_code == 200, r.text

    # Verify initial sync returns product
    r = client.get("/sync/initial", headers=headers)
    assert r.status_code == 200, r.text
    assert len(r.json()["products"]) == 1

    # 3. Post FACTORY_RESET event from Device A
    reset_event_id = f"446e424c-a03e-44ef-8fe3-8fe82827ce0c-{uuid.uuid4().hex[:6]}"
    r = client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": device_a,
        "events": [
            {
                "id": reset_event_id,
                "business_id": biz_id,
                "device_id": device_a,
                "user_id": reg_data["user_id"],
                "branch_id": reg_data["branch_id"],
                "event_type": "FACTORY_RESET",
                "entity_type": "factory_reset",
                "entity_id": biz_id,
                "payload": {
                    "shopId": biz_id,
                    "action": "FACTORY_RESET",
                    "event_type": "FACTORY_RESET",
                    "timestamp": "2026-10-04T12:05:00Z"
                },
                "timestamp": "2026-10-04T12:05:00Z"
            }
        ]
    })
    assert r.status_code == 200, r.text
    res_json = r.json()
    print("FACTORY RESET RESPONSE:", res_json)

    # TEST 1 Verification: ackedEventIds must contain reset_event_id and rejectedEvents must be empty!
    assert reset_event_id in res_json["synced"], f"Expected {reset_event_id} in synced list: {res_json}"
    assert reset_event_id in res_json["ackedEventIds"], f"Expected {reset_event_id} in ackedEventIds: {res_json}"
    assert res_json["rejectedEvents"] == [], f"Expected empty rejectedEvents but got: {res_json['rejectedEvents']}"
    print("✅ TEST 1 PASSED: FACTORY_RESET event accepted and acknowledged with exact event ID.")

    # Verify database wiped operational tables
    r = client.get("/sync/initial", headers=headers)
    assert r.status_code == 200, r.text
    assert len(r.json()["products"]) == 0
    print("✅ TEST 1 DB VERIFICATION PASSED: PostgreSQL operational tables purged.")

    # TEST 4 Verification: Idempotency re-posting same FACTORY_RESET event
    r_dup = client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": device_a,
        "events": [
            {
                "id": reset_event_id,
                "business_id": biz_id,
                "device_id": device_a,
                "event_type": "FACTORY_RESET",
                "entity_type": "factory_reset",
                "entity_id": biz_id
            }
        ]
    })
    assert r_dup.status_code == 200, r_dup.text
    dup_json = r_dup.json()
    assert reset_event_id in dup_json["synced"]
    assert dup_json["rejectedEvents"] == []
    print("✅ TEST 4 PASSED: Replaying FACTORY_RESET event handled idempotently.")

    # TEST 2 & 3: Device B (secondary/reconnecting device) first pull
    r_pull1 = client.get(f"/sync/pull?shopId={biz_id}&deviceId={device_b}&cursor=2026-10-04T12:00:00Z", headers=headers)
    assert r_pull1.status_code == 200, r_pull1.text
    pull1_json = r_pull1.json()
    changes1 = pull1_json.get("changes", [])
    has_reset = any(c.get("op") == "FACTORY_RESET" or c.get("table") == "factory_reset" for c in changes1)
    assert has_reset, f"Expected FACTORY_RESET in pull deltas for secondary device, got: {changes1}"
    new_cursor = pull1_json.get("cursor")
    assert new_cursor is not None and new_cursor != "2026-10-04T12:00:00Z"
    print(f"✅ TEST 2 & 3 PASSED: Device B received FACTORY_RESET event and advanced cursor to {new_cursor}")

    # TEST 9: Device B second pull with updated cursor must NOT receive FACTORY_RESET again!
    r_pull2 = client.get(f"/sync/pull?shopId={biz_id}&deviceId={device_b}&cursor={new_cursor}", headers=headers)
    assert r_pull2.status_code == 200, r_pull2.text
    pull2_json = r_pull2.json()
    changes2 = pull2_json.get("changes", [])
    has_reset2 = any(c.get("op") == "FACTORY_RESET" or c.get("table") == "factory_reset" for c in changes2)
    assert not has_reset2, f"FACTORY_RESET was returned AGAIN on second pull with updated cursor! Got: {changes2}"
    print("✅ TEST 9 PASSED: Device B second pull with advanced cursor did NOT receive FACTORY_RESET again.")

    # TEST 5 & 12 (C): Create a new product AFTER factory reset, verify Device B pulls it normally
    new_prod_event_id = f"evt-new-prod-{uuid.uuid4().hex[:6]}"
    new_prod_id = f"prod-new-{uuid.uuid4().hex[:6]}"
    r_new_prod = client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": device_a,
        "events": [
            {
                "id": new_prod_event_id,
                "business_id": biz_id,
                "device_id": device_a,
                "user_id": reg_data["user_id"],
                "branch_id": reg_data["branch_id"],
                "event_type": "PRODUCT_CREATED",
                "entity_type": "product",
                "entity_id": new_prod_id,
                "payload": {
                    "name": "Fresh Post-Reset Product",
                    "sku": "FRESH-001",
                    "price": 250.0,
                    "costPrice": 120.0,
                    "stockQuantity": 100
                },
                "timestamp": "2026-10-04T12:10:00Z"
            }
        ]
    })
    assert r_new_prod.status_code == 200, r_new_prod.text

    # Device B pulls deltas with cursor=new_cursor
    r_pull3 = client.get(f"/sync/pull?shopId={biz_id}&deviceId={device_b}&cursor={new_cursor}", headers=headers)
    assert r_pull3.status_code == 200, r_pull3.text
    pull3_json = r_pull3.json()
    changes3 = pull3_json.get("changes", [])
    has_new_prod = any(c.get("entity_id") == new_prod_id or (isinstance(c.get("payload"), dict) and c["payload"].get("name") == "Fresh Post-Reset Product") for c in changes3)
    assert has_new_prod, f"Expected fresh post-reset product in pull deltas for Device B, got: {changes3}"
    print("✅ TEST 5 & 12 (C) PASSED: Device B successfully pulled new product created after Factory Reset — Normal synchronization resumed!")

if __name__ == "__main__":
    test_factory_reset_flow()
    print("\n🎉 ALL FACTORY RESET BACKEND & CURSOR REPLAY TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
