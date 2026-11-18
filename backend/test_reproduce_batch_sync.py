from fastapi.testclient import TestClient
from app.main import app
from test_sync_integrity import _register_and_login, _db_session, _post_events, _uid
from app.models.business_data import ProductModel, BatchModel, ProductStockModel
from app.models.outbox import OutboxEvent

client = TestClient(app)

biz_id, user_id, branch_id, tok = _register_and_login(client)
db = _db_session()

# Device A creates product and batch
prod_id = _uid("prod-")
batch_id = _uid("batch-")
dev_a = "device-A"
dev_b = "device-B"

# Simulate Device A uploading product and batch (exactly as Flutter database_service does)
events = [
    {
        "id": _uid("ev-prod-"),
        "shopId": biz_id,
        "deviceId": dev_a,
        "userId": user_id,
        "branchId": branch_id,
        "eventType": "upsert",
        "entityType": "products",
        "entityId": prod_id,
        "payload": {
            "id": prod_id,
            "shopId": biz_id,
            "branchId": branch_id,
            "name": "Amoxicillin 500mg",
            "quantity": 100,
            "buyingPrice": 5.0,
            "sellingPrice": 10.0,
            "barcode": "AMOX-001",
            "expiryDate": "2027-12-31T00:00:00Z",
        }
    },
    {
        "id": _uid("ev-batch-"),
        "shopId": biz_id,
        "deviceId": dev_a,
        "userId": user_id,
        "branchId": branch_id,
        "eventType": "upsert",
        "entityType": "batches",
        "entityId": batch_id,
        "payload": {
            "id": batch_id,
            "shopId": biz_id,
            "branchId": branch_id,
            "itemId": prod_id,
            "quantity": 100,
            "buyingPrice": 5.0,
            "sellingPrice": 10.0,
            "expiry": "2027-12-31T00:00:00.000Z",
            "expiryDate": "2027-12-31T00:00:00.000Z",
            "batchNumber": "BN-101",
            "type": "initial",
        }
    }
]

resp = client.post("/sync/events", json={
    "shopId": biz_id,
    "deviceId": dev_a,
    "events": events
}, headers={"Authorization": f"Bearer {tok}"})

print("Upload status:", resp.status_code)
print("Upload response:", resp.json())

# Check backend DB
p = db.query(ProductModel).filter(ProductModel.id == prod_id).first()
b = db.query(BatchModel).filter(BatchModel.id == batch_id).first()
print("Postgres Product:", p.id if p else None, p.name if p else None, p.stock_quantity if p else None)
print("Postgres Batch:", b.id if b else None, b.item_id if b else None, b.quantity if b else None)

# Check Device B pull
pull_resp = client.get("/sync/pull", params={
    "shopId": biz_id,
    "deviceId": dev_b,
    "cursor": "0"
}, headers={"Authorization": f"Bearer {tok}"})

print("Pull status:", pull_resp.status_code)
changes = pull_resp.json().get("changes", [])
print(f"Device B pulled {len(changes)} changes:")
for c in changes:
    print(f"  Table: {c.get('table')}, Op: {c.get('op')}, RecordId: {c.get('recordId')}, Payload: {c.get('payload')}")

db.close()

