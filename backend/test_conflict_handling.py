"""
Comprehensive test suite for Deterministic Conflict Handling in GM Inventory Sync Processor.
Tests:
1. Product identity reconciliation (barcode/SKU deduplication across offline devices).
2. Field-level competing edit merging and version tracking.
3. Tombstone safety (preventing stale edits from resurrecting soft-deleted products).
4. Additive stock calculation and oversell flooring with conflict logging.
5. Additive customer debt and payment reconciliation.
6. Refund capping and additive stock restoration.
7. Out-of-order dependency handling (stub creation for missing products).
"""
import warnings
warnings.filterwarnings("ignore")

import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.database.session import SessionLocal
from app.models.business_data import ProductModel, CustomerModel, SaleModel, AuditLogModel

client = TestClient(app)

def _setup_test_business(name_prefix: str):
    device_id = f"dev-{uuid.uuid4().hex[:6]}"
    email = f"{name_prefix}_{uuid.uuid4().hex[:6]}@store.com"

    r = client.post("/auth/register", json={
        "business_name": f"{name_prefix} Store",
        "email": email,
        "password": "Password123!",
        "device_uuid": device_id,
        "device_name": "Test Device",
        "platform": "windows"
    })
    assert r.status_code == 201, r.text
    reg = r.json()

    r = client.post("/auth/login", json={
        "email": email,
        "password": "Password123!",
        "device_uuid": device_id
    })
    assert r.status_code == 200, r.text
    access_token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}
    return reg["business_id"], reg["user_id"], device_id, headers


def test_product_identity_reconciliation():
    biz_id, user_id, dev_a, headers = _setup_test_business("identity")
    dev_b = f"dev-b-{uuid.uuid4().hex[:6]}"
    barcode = f"BC-{uuid.uuid4().hex[:8]}"

    p1_id = f"prod-1-{uuid.uuid4().hex[:6]}"
    p2_id = f"prod-2-{uuid.uuid4().hex[:6]}"

    # Device A creates Product 1
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-1-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": p1_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {
                "name": "Panadol Extra",
                "barcode": barcode,
                "sellingPrice": 15.0,
                "quantity": 100.0
            }
        }]
    })

    # Device B creates Product 2 with same barcode while offline
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_b,
        "events": [{
            "id": f"evt-2-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_b,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": p2_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {
                "name": "Panadol Extra Dupe",
                "barcode": barcode,
                "sellingPrice": 18.0,
                "quantity": 50.0
            }
        }]
    })

    db = SessionLocal()
    try:
        active_prods = db.query(ProductModel).filter(
            ProductModel.business_id == biz_id,
            ProductModel.barcode == barcode,
            ProductModel.is_deleted == False
        ).all()
        assert len(active_prods) == 1, f"Expected 1 reconciled product, found {len(active_prods)}"
        assert active_prods[0].id == p1_id

        audits = db.query(AuditLogModel).filter(
            AuditLogModel.business_id == biz_id,
            AuditLogModel.action == "CONFLICT_RESOLUTION"
        ).all()
        assert any("[CONFLICT RECONCILED]" in a.details for a in audits), "Expected conflict audit log for identity reconciliation"
    finally:
        db.close()
    print("[TEST PASSED] Product identity reconciliation verified!")


def test_tombstone_safety():
    biz_id, user_id, dev_a, headers = _setup_test_business("tombstone")
    dev_b = f"dev-b-{uuid.uuid4().hex[:6]}"
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"

    # Device A creates product
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-create-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {"name": "Juice", "sellingPrice": 5.0}
        }]
    })

    # Device A deletes product (tombstone)
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-del-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_DELETED",
            "payload": {"operation": "delete"}
        }]
    })

    # Device B sends a stale edit
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_b,
        "events": [{
            "id": f"evt-stale-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_b,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_UPDATED",
            "payload": {"name": "Juice Stale Edit", "sellingPrice": 6.0}
        }]
    })

    db = SessionLocal()
    try:
        p = db.query(ProductModel).filter(ProductModel.id == prod_id, ProductModel.business_id == biz_id).first()
        assert p is not None
        assert p.is_deleted is True, "Tombstoned product must remain soft-deleted"

        audits = db.query(AuditLogModel).filter(
            AuditLogModel.business_id == biz_id,
            AuditLogModel.action == "CONFLICT_RESOLUTION"
        ).all()
        assert any("[CONFLICT IGNORED]" in a.details for a in audits), "Expected conflict audit for ignored tombstone edit"
    finally:
        db.close()
    print("[TEST PASSED] Tombstone safety verified!")


def test_field_level_competing_edits():
    biz_id, user_id, dev_a, headers = _setup_test_business("field_merge")
    dev_b = f"dev-b-{uuid.uuid4().hex[:6]}"
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"

    # Initial product
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-init-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {"name": "Original Name", "sellingPrice": 10.0, "lowStockThreshold": 5}
        }]
    })

    # Device A updates price
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-price-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_UPDATED",
            "payload": {"sellingPrice": 12.5}
        }]
    })

    # Device B updates min stock threshold
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_b,
        "events": [{
            "id": f"evt-thresh-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_b,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_UPDATED",
            "payload": {"lowStockThreshold": 15}
        }]
    })

    db = SessionLocal()
    try:
        p = db.query(ProductModel).filter(ProductModel.id == prod_id, ProductModel.business_id == biz_id).first()
        assert p is not None
        assert p.price == 12.5
        assert p.min_stock_threshold == 15.0
        assert p.version >= 3
    finally:
        db.close()
    print("[TEST PASSED] Field-level competing edit merge verified!")


def test_additive_stock_and_oversell_floor():
    biz_id, user_id, dev_a, headers = _setup_test_business("oversell")
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"

    # Product created with stock = 10
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-p-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {"name": "Limited Item", "quantity": 10.0}
        }]
    })

    # Sale of 15 units (oversell by 5)
    sale_id = f"sale-{uuid.uuid4().hex[:6]}"
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-s-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "sale",
            "entity_id": sale_id,
            "event_type": "SALE_CREATED",
            "payload": {
                "itemId": prod_id,
                "itemName": "Limited Item",
                "quantity": 15.0,
                "totalPrice": 150.0
            }
        }]
    })

    db = SessionLocal()
    try:
        p = db.query(ProductModel).filter(ProductModel.id == prod_id, ProductModel.business_id == biz_id).first()
        assert p is not None
        assert p.stock_quantity == 0.0, "Stock quantity must be floored at 0.0"

        s = db.query(SaleModel).filter(SaleModel.id == sale_id, SaleModel.business_id == biz_id).first()
        assert s is not None
        assert s.quantity == 15.0, "Sale record must be preserved intact"

        audits = db.query(AuditLogModel).filter(AuditLogModel.business_id == biz_id, AuditLogModel.action == "CONFLICT_RESOLUTION").all()
        assert any("[STOCK OVERSELL CONFLICT]" in a.details for a in audits), "Expected audit log for oversell floor"
    finally:
        db.close()
    print("[TEST PASSED] Additive stock and oversell floor verified!")


def test_customer_debt_and_payment():
    biz_id, user_id, dev_a, headers = _setup_test_business("financial")
    cust_id = f"cust-{uuid.uuid4().hex[:6]}"

    # Customer created with 100 debt
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-c-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "customer",
            "entity_id": cust_id,
            "event_type": "CUSTOMER_CREATED",
            "payload": {"name": "Alice Debt", "balance": 100.0}
        }]
    })

    # Payment of 40 sent
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-pay-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "customer",
            "entity_id": cust_id,
            "event_type": "CUSTOMER_PAYMENT",
            "payload": {"amount": 40.0, "action": "PAYMENT"}
        }]
    })

    db = SessionLocal()
    try:
        c = db.query(CustomerModel).filter(CustomerModel.id == cust_id, CustomerModel.business_id == biz_id).first()
        assert c is not None
        assert c.balance == 60.0, f"Expected 60.0 balance, got {c.balance}"

        audits = db.query(AuditLogModel).filter(AuditLogModel.business_id == biz_id, AuditLogModel.action == "CONFLICT_RESOLUTION").all()
        assert any("[FINANCIAL EVENT]" in a.details for a in audits), "Expected audit log for customer payment"
    finally:
        db.close()
    print("[TEST PASSED] Customer debt & additive payment verified!")


def test_refund_capping_and_stock_restoration():
    biz_id, user_id, dev_a, headers = _setup_test_business("refund")
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"
    sale_id = f"sale-{uuid.uuid4().hex[:6]}"

    # Product stock 20
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-p-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "product",
            "entity_id": prod_id,
            "event_type": "PRODUCT_CREATED",
            "payload": {"name": "Shirt", "quantity": 20.0}
        }]
    })

    # Sale of 5 units (stock becomes 15)
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-s-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "sale",
            "entity_id": sale_id,
            "event_type": "SALE_CREATED",
            "payload": {"itemId": prod_id, "itemName": "Shirt", "quantity": 5.0}
        }]
    })

    # Refund request of 10 units (attempts double refund)
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-r-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "sale",
            "entity_id": sale_id,
            "event_type": "REFUND_CREATED",
            "payload": {"refundQuantity": 10.0, "action": "REFUND"}
        }]
    })

    db = SessionLocal()
    try:
        s = db.query(SaleModel).filter(SaleModel.id == sale_id, SaleModel.business_id == biz_id).first()
        assert s is not None
        assert s.refunded_quantity == 5.0, f"Refund must cap at 5.0, got {s.refunded_quantity}"

        p = db.query(ProductModel).filter(ProductModel.id == prod_id, ProductModel.business_id == biz_id).first()
        assert p is not None
        assert p.stock_quantity == 20.0, f"Stock must restore additively to 20.0, got {p.stock_quantity}"

        audits = db.query(AuditLogModel).filter(AuditLogModel.business_id == biz_id, AuditLogModel.action == "CONFLICT_RESOLUTION").all()
        assert any("[REFUND CONFLICT]" in a.details for a in audits), "Expected audit log for capped refund"
    finally:
        db.close()
    print("[TEST PASSED] Refund capping & stock restoration verified!")


def test_out_of_order_sales_stub_creation():
    biz_id, user_id, dev_a, headers = _setup_test_business("out_of_order")
    prod_id = f"prod-{uuid.uuid4().hex[:6]}"
    sale_id = f"sale-{uuid.uuid4().hex[:6]}"

    # Sale arrives before product creation event
    client.post("/sync/events", headers=headers, json={
        "shopId": biz_id,
        "deviceId": dev_a,
        "events": [{
            "id": f"evt-s-{uuid.uuid4().hex[:6]}",
            "business_id": biz_id,
            "device_id": dev_a,
            "user_id": user_id,
            "entity_type": "sale",
            "entity_id": sale_id,
            "event_type": "SALE_CREATED",
            "payload": {"itemId": prod_id, "itemName": "Unsynced Product", "quantity": 2.0}
        }]
    })

    db = SessionLocal()
    try:
        p = db.query(ProductModel).filter(ProductModel.id == prod_id, ProductModel.business_id == biz_id).first()
        assert p is not None
        assert p.name == "Unsynced Product"

        audits = db.query(AuditLogModel).filter(AuditLogModel.business_id == biz_id, AuditLogModel.action == "CONFLICT_RESOLUTION").all()
        assert any("[DEPENDENCY CONFLICT]" in a.details for a in audits), "Expected audit log for stub product creation"
    finally:
        db.close()
    print("[TEST PASSED] Out-of-order dependency stub creation verified!")
