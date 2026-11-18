"""
Backend smoke test for Phase 3 Online Sync Engine & Initial Data Sync.
"""
import sys, warnings
warnings.filterwarnings("ignore")

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

import uuid

DEVICE_UUID = f"test-sync-device-{uuid.uuid4().hex[:6]}"
TEST_EMAIL = f"synctest_{uuid.uuid4().hex[:6]}@store.com"

def test_sync_flow():
    # 1. Register Business
    r = client.post("/auth/register", json={
        "business_name": "Sync Test Store",
        "email": TEST_EMAIL,
        "password": "Password123!",
        "device_uuid": DEVICE_UUID,
        "device_name": "Test Terminal",
        "platform": "windows"
    })
    assert r.status_code == 201, r.text
    reg_data = r.json()
    biz_id = reg_data["business_id"]

    # 2. Login to get JWT access token
    r = client.post("/auth/login", json={
        "email": TEST_EMAIL,
        "password": "Password123!",
        "device_uuid": DEVICE_UUID
    })
    assert r.status_code == 200, r.text
    token_data = r.json()
    access_token = token_data["access_token"]

    # 3. Post sync events to /sync/events with Bearer token
    event_id = f"event-uuid-{uuid.uuid4().hex[:6]}"
    batch_event_id = f"batch-event-{uuid.uuid4().hex[:6]}"
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"
    batch_id = f"batch-{uuid.uuid4().hex[:6]}"

    headers = {"Authorization": f"Bearer {access_token}"}
    r = client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": DEVICE_UUID,
        "events": [
            {
                "id": event_id,
                "business_id": biz_id,
                "device_id": DEVICE_UUID,
                "user_id": reg_data["user_id"],
                "branch_id": reg_data["branch_id"],
                "event_type": "PRODUCT_CREATED",
                "entity_type": "product",
                "entity_id": prod_id,
                "payload": {
                    "name": "Wireless Mouse",
                    "sku": "WM-001",
                    "price": 29.99,
                    "costPrice": 15.00,
                    "stockQuantity": 50
                },
                "timestamp": "2026-08-07T17:00:00Z"
            },
            {
                "id": batch_event_id,
                "business_id": biz_id,
                "device_id": DEVICE_UUID,
                "user_id": reg_data["user_id"],
                "branch_id": reg_data["branch_id"],
                "event_type": "BATCH_CREATED",
                "entity_type": "batch",
                "entity_id": batch_id,
                "payload": {
                    "itemId": prod_id,
                    "batchNumber": "BATCH-001",
                    "quantity": 50.0,
                    "buyingPrice": 15.00,
                    "sellingPrice": 29.99,
                    "expiryDate": "2027-04-15T00:00:00Z",
                    "type": "initial"
                },
                "timestamp": "2026-08-07T17:00:00Z"
            }
        ]
    })
    assert r.status_code == 200, r.text
    sync_resp = r.json()
    assert event_id in sync_resp["synced"]
    assert batch_event_id in sync_resp["synced"]
    print("✅ POST /sync/events with JWT auth OK — Event processed and entity updated.")

    # 4. Test Idempotency (re-sending same event)
    r = client.post("/sync/events", headers=headers, json={
        "events": [
            {
                "id": event_id,
                "business_id": biz_id,
                "device_id": DEVICE_UUID,
                "event_type": "PRODUCT_CREATED",
                "entity_type": "product",
                "entity_id": prod_id
            }
        ]
    })
    assert r.status_code == 200, r.text
    assert event_id in r.json()["synced"]
    print("✅ Event Idempotency test OK — Duplicate event safely acknowledged.")

    # 5. Test Initial Data Sync GET /sync/initial
    r = client.get("/sync/initial", headers=headers)
    assert r.status_code == 200, r.text
    initial_data = r.json()
    print("INITIAL DATA:", initial_data)
    assert len(initial_data["products"]) >= 1
    assert initial_data["products"][0]["name"] == "Wireless Mouse"
    assert len(initial_data["batches"]) >= 1
    assert initial_data["batches"][0]["batchNumber"] == "BATCH-001"
    assert initial_data["batches"][0]["expiryDate"].startswith("2027-04-15")
    print("✅ GET /sync/initial OK — Products, batches, and master data retrieved.")

if __name__ == "__main__":
    test_sync_flow()
    print("\n🎉 ALL BACKEND SYNC ENGINE TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
