import sys
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    print("✅ GET /health verified successfully!")

def test_sync_upload():
    payload = {
        "shopId": "test_shop_101",
        "deviceId": "dev_win_abc123",
        "events": [
            {
                "id": "evt_sale_999",
                "shopId": "test_shop_101",
                "branchId": "main",
                "deviceId": "dev_win_abc123",
                "userId": "user_admin_01",
                "eventType": "SALE",
                "entityType": "sale",
                "entityId": "sale_rec_001",
                "payload": {
                    "itemName": "Paracetamol 500mg",
                    "quantity": 5,
                    "totalPrice": 150.0,
                    "profit": 50.0
                },
                "createdAt": "2026-08-06T12:00:00Z"
            }
        ]
    }
    response = client.post("/sync/upload", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "evt_sale_999" in data["ackedEventIds"]
    print("✅ POST /sync/upload verified successfully!", data)

if __name__ == "__main__":
    import sys
    import warnings
    warnings.filterwarnings("ignore")
    test_health()
    test_sync_upload()
    print("ALL BACKEND & OUTBOX VERIFICATION TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
