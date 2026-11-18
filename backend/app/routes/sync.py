from datetime import datetime, timezone
import json
from typing import Optional
from fastapi import APIRouter, Body, Depends, HTTPException, Header, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.schemas.sync import SyncEventsRequest, SyncEventsResponse, InitialSyncResponse
from app.sync.processor import process_sync_events
from app.services import auth_service
from app.models.business_data import (
    ProductModel, CategoryModel, CustomerModel, SupplierModel, BatchModel,
    SaleModel, PurchaseModel, AuditLogModel, ProductStockModel, NotificationModel, SettingModel,
    SubscriptionModel
)
from app.models.identity import BackendUser, BackendBranch
from app.models.outbox import OutboxEvent

router = APIRouter(prefix="/sync", tags=["Synchronization"])

def get_auth_business_id(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
) -> Optional[str]:
    """Helper to extract business_id from Bearer JWT token if present and verify active status & security revision."""
    if not authorization:
        print("[SYNC AUTH DEBUG] Authorization header is missing.")
        return None
    if not authorization.startswith("Bearer "):
        print(f"[SYNC AUTH DEBUG] Authorization header format invalid (does not start with Bearer): len={len(authorization)}")
        return None
    token = authorization.split(" ")[1]
    claims = auth_service.decode_access_token(token)
    if not claims:
        print(f"[SYNC AUTH DEBUG] [SECURITY] JWT validation failed: token is expired, secret mismatch, or signature invalid.")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token."
        )
    user_id = claims.get("sub")
    business_id = claims.get("business_id")
    token_sec_rev = claims.get("sec_rev")

    if user_id:
        user = db.query(BackendUser).filter(BackendUser.id == user_id).first()
        if not user or not user.is_active:
            print(f"[SECURITY] Session validation failed: user {user_id} is inactive or deleted.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is deactivated or deleted."
            )
        if token_sec_rev is not None and getattr(user, 'security_revision', None) is not None:
            if token_sec_rev != user.security_revision:
                print(f"[SECURITY] Session validation failed: token sec_rev {token_sec_rev} != user sec_rev {user.security_revision}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Session invalidated due to password change or security update."
                )

    if business_id:
        from app.models.identity import Business
        biz = db.query(Business).filter(Business.id == business_id).first()
        if not biz or not biz.is_active:
            print(f"[SECURITY] Session validation failed: business {business_id} is deactivated or deleted.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Business/Shop has been deactivated or deleted."
            )

    print(f"[SYNC AUTH DEBUG] JWT validation succeeded: business_id={business_id} user_id={user_id}")
    return business_id

@router.post("/events", response_model=SyncEventsResponse, status_code=status.HTTP_200_OK)
def sync_events(
    payload: SyncEventsRequest,
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id)
):
    """
    POST /sync/events
    Primary synchronization endpoint for outbox events.
    Validates JWT authentication, business ownership, processes events idempotently,
    and returns synced event IDs.
    """
    try:
        synced_ids, rejected, identity_resolutions = process_sync_events(db, payload, authenticated_business_id=auth_business_id)
        return SyncEventsResponse(
            status="success",
            synced=synced_ids,
            ackedEventIds=synced_ids,
            rejectedEvents=rejected,
            identityResolutions=identity_resolutions,
            message=f"Synced {len(synced_ids)} outbox events."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync processing error: {str(e)}"
        )

@router.post("/upload", response_model=SyncEventsResponse, status_code=status.HTTP_200_OK)
def upload_sync_events(
    payload: SyncEventsRequest,
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id)
):
    """Alias for POST /sync/events for backwards compatibility."""
    return sync_events(payload=payload, db=db, auth_business_id=auth_business_id)

@router.get("/initial", response_model=InitialSyncResponse, status_code=status.HTTP_200_OK)
def initial_data_sync(
    business_id: Optional[str] = None,
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id)
):
    """
    GET /sync/initial
    Initial data sync endpoint for downloading business master data to new devices.
    Returns: Products, Batches, Categories, Customers, Suppliers, Settings, Users, Branches, Sales, Purchases, AuditLogs, ProductStocks.
    """
    target_biz_id = auth_business_id or business_id
    if not target_biz_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="business_id query parameter or Authorization Bearer header is required."
        )

    from app.models.identity import Business
    biz = db.query(Business).filter(Business.id == target_biz_id).first()
    if not biz or not biz.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Business/Shop has been deactivated or deleted."
        )

    products = db.query(ProductModel).filter(ProductModel.business_id == target_biz_id, ProductModel.is_deleted == False).all()
    batches = db.query(BatchModel).filter(BatchModel.business_id == target_biz_id, BatchModel.is_deleted == False).all()
    categories = db.query(CategoryModel).filter(CategoryModel.business_id == target_biz_id, CategoryModel.is_deleted == False).all()
    customers = db.query(CustomerModel).filter(CustomerModel.business_id == target_biz_id, CustomerModel.is_deleted == False).all()
    suppliers = db.query(SupplierModel).filter(SupplierModel.business_id == target_biz_id, SupplierModel.is_deleted == False).all()
    users = db.query(BackendUser).filter(BackendUser.business_id == target_biz_id, BackendUser.is_active == True).all()
    branches = db.query(BackendBranch).filter(BackendBranch.business_id == target_biz_id, BackendBranch.is_active == True).all()
    sales = db.query(SaleModel).filter(SaleModel.business_id == target_biz_id, SaleModel.is_deleted == False).all()
    purchases = db.query(PurchaseModel).filter(PurchaseModel.business_id == target_biz_id, PurchaseModel.is_deleted == False).all()
    audit_logs = db.query(AuditLogModel).filter(AuditLogModel.business_id == target_biz_id, AuditLogModel.is_deleted == False).all()
    product_stocks = db.query(ProductStockModel).filter(ProductStockModel.business_id == target_biz_id, ProductStockModel.is_deleted == False).all()
    notifications = db.query(NotificationModel).filter(NotificationModel.business_id == target_biz_id, NotificationModel.is_deleted == False).all()
    settings_db = db.query(SettingModel).filter(SettingModel.business_id == target_biz_id, SettingModel.is_deleted == False).all()
    settings_list = [{"key": st.key, "value": st.value, "shopId": st.business_id} for st in settings_db]
    curr = getattr(biz, "currency", None)
    if not any(s["key"] == "currency" for s in settings_list) and curr:
        settings_list.append({"key": "currency", "value": curr, "shopId": target_biz_id})
        settings_list.append({"key": "app_currency_symbol", "value": f"{curr} ", "shopId": target_biz_id})


    print(f"[INITIAL SYNC TRACE] device requesting initial sync: target_biz_id={target_biz_id}")
    print(f"[INITIAL SYNC TRACE] users_returned={len(users)} businesses_returned=1 branches_returned={len(branches)} batches_returned={len(batches)} sales_returned={len(sales)} purchases_returned={len(purchases)}")
    for u in users:
        print(f"[INITIAL SYNC USER] user_id={u.id} username={u.username} business_id={u.business_id} branch_id={u.branch_id} role={u.role} is_active={u.is_active}")
        print(f"[USER SYNC TRACE] operation_id=initial_sync event_type=USER_CREATED business_id={u.business_id} target_user_id={u.id}")
        print(f"[USER SYNC TRACE] stage=AVAILABLE_FOR_PULL")

    return InitialSyncResponse(
        products=[{
            "id": p.id,
            "shopId": p.business_id,
            "businessId": p.business_id,
            "branchId": p.branch_id or "main",
            "name": p.name,
            "sku": p.sku,
            "barcode": p.barcode or "",
            "price": p.price,
            "sellingPrice": p.price,
            "costPrice": p.cost_price,
            "buyingPrice": p.cost_price,
            "stockQuantity": p.stock_quantity,
            "quantity": p.stock_quantity,
            "lowStockThreshold": int(p.min_stock_threshold or 5),
            "expiryDate": p.expiry_date.isoformat() if p.expiry_date else None,
            "version": p.version,
            "lastModifiedByDevice": p.last_modified_by_device,
            "updatedAt": p.updated_at.isoformat() if p.updated_at else None
        } for p in products],
        batches=[{
            "id": b.id,
            "shopId": b.business_id,
            "businessId": b.business_id,
            "branchId": b.branch_id or "main",
            "itemId": b.item_id,
            "productId": b.item_id,
            "batchNumber": b.batch_number,
            "quantity": b.quantity,
            "buyingPrice": b.buying_price,
            "costPrice": b.buying_price,
            "sellingPrice": b.selling_price,
            "price": b.selling_price,
            "expiryDate": b.expiry_date.isoformat() if b.expiry_date else None,
            "type": b.batch_type or "restock",
            "version": b.version,
            "updatedAt": b.updated_at.isoformat() if b.updated_at else None
        } for b in batches],
        categories=[{
            "id": c.id, "name": c.name, "version": c.version,
            "updatedAt": c.updated_at.isoformat() if c.updated_at else None
        } for c in categories],
        customers=[{
            "id": cu.id, "name": cu.name, "phone": cu.phone, "email": cu.email,
            "balance": cu.balance, "version": cu.version,
            "updatedAt": cu.updated_at.isoformat() if cu.updated_at else None
        } for cu in customers],
        suppliers=[{
            "id": s.id, "name": s.name, "phone": s.phone, "email": s.email,
            "version": s.version, "updatedAt": s.updated_at.isoformat() if s.updated_at else None
        } for s in suppliers],
        settings=settings_list,
        users=[{
            "id": u.id,
            "uid": u.id,
            "name": u.name,
            "fullName": u.name,
            "username": u.username or (u.email.split("@")[0] if u.email else ""),
            "email": u.email,
            "role": u.role,
            "roles": [u.role],
            "permissions": u.permissions if hasattr(u, "permissions") else None,
            "branchId": (u.branch_id if hasattr(u, "branch_id") else None) or "main",
            "branchName": "Main Branch",
            "shopId": u.business_id,
            "businessId": u.business_id,
            "isActive": u.is_active,
            "password_hash": u.password_hash,
            "passwordHash": u.password_hash,
        } for u in users],
        branches=[{
            "id": b.id, "name": b.name
        } for b in branches],
        sales=[{
            "id": s.id,
            "shopId": s.business_id,
            "businessId": s.business_id,
            "branchId": s.branch_id or "main",
            "itemId": s.item_id,
            "itemName": s.item_name,
            "quantity": s.quantity,
            "totalPrice": s.total_price,
            "profit": s.profit,
            "userId": s.user_id,
            "username": s.username,
            "timestamp": s.timestamp.isoformat() if s.timestamp else None,
            "customerName": s.customer_name,
            "isDebt": s.is_debt,
            "amountPaid": s.amount_paid,
            "debtRemaining": s.debt_remaining,
            "refundedQuantity": s.refunded_quantity,
            "batchId": s.batch_id,
            "version": s.version,
            "updatedAt": s.updated_at.isoformat() if s.updated_at else None
        } for s in sales],
        purchases=[{
            "id": pu.id,
            "shopId": pu.business_id,
            "businessId": pu.business_id,
            "branchId": pu.branch_id or "main",
            "itemId": pu.item_id,
            "itemName": pu.item_name,
            "barcode": pu.barcode,
            "quantity": pu.quantity,
            "unitCost": pu.unit_cost,
            "totalCost": pu.total_cost,
            "supplierName": pu.supplier_name,
            "batchNumber": pu.batch_number,
            "expiryDate": pu.expiry_date.isoformat() if pu.expiry_date else None,
            "timestamp": pu.timestamp.isoformat() if pu.timestamp else None,
            "version": pu.version,
            "updatedAt": pu.updated_at.isoformat() if pu.updated_at else None
        } for pu in purchases],
        auditLogs=[{
            "id": a.id,
            "shopId": a.business_id,
            "businessId": a.business_id,
            "branchId": a.branch_id or "main",
            "username": a.username,
            "action": a.action,
            "details": a.details,
            "timestamp": a.timestamp.isoformat() if a.timestamp else None,
            "version": a.version,
            "updatedAt": a.updated_at.isoformat() if a.updated_at else None
        } for a in audit_logs],
        productStocks=[{
            "id": ps.id,
            "shopId": ps.business_id,
            "businessId": ps.business_id,
            "productId": ps.product_id,
            "branchId": ps.branch_id,
            "quantity": ps.quantity,
            "version": ps.version,
            "updatedAt": ps.updated_at.isoformat() if ps.updated_at else None
        } for ps in product_stocks],
        notifications=[{
            "id": n.id,
            "shopId": n.business_id,
            "businessId": n.business_id,
            "branchId": n.branch_id or "main",
            "title": n.title,
            "body": n.body,
            "message": n.body,
            "type": n.type,
            "priority": n.priority,
            "isRead": n.is_read,
            "timestamp": n.timestamp.isoformat() if n.timestamp else None,
            "version": n.version,
            "updatedAt": n.updated_at.isoformat() if n.updated_at else None
        } for n in notifications]
    )



@router.get("/pull", status_code=status.HTTP_200_OK)
def pull_sync_deltas(
    shopId: Optional[str] = None,
    deviceId: Optional[str] = None,
    cursor: Optional[str] = None,
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id)
):
    """
    GET /sync/pull
    Incremental sync endpoint for fetching changes since a given cursor.
    """
    target_biz_id = auth_business_id or shopId
    if not target_biz_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="shopId query parameter or Authorization Bearer header is required."
        )

    from app.models.identity import Business
    biz = db.query(Business).filter(Business.id == target_biz_id).first()
    if not biz or not biz.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Business/Shop has been deactivated or deleted."
        )

    query = db.query(OutboxEvent).filter(OutboxEvent.business_id == target_biz_id)

    if cursor and cursor != "0":
        try:
            cursor_dt = datetime.fromisoformat(cursor.replace("Z", "+00:00"))
            if deviceId:
                query = query.filter(
                    OutboxEvent.created_at > cursor_dt,
                    OutboxEvent.device_id != deviceId
                )
            else:
                query = query.filter(OutboxEvent.created_at > cursor_dt)
        except Exception:
            pass
    elif deviceId:
        query = query.filter(OutboxEvent.device_id != deviceId)


    events = query.order_by(OutboxEvent.created_at.asc()).limit(100).all()

    print(f"[INCREMENTAL SYNC TRACE] device={deviceId} business_id={target_biz_id} cursor={cursor} events_found={len(events)}")

    changes = []
    latest_cursor = cursor or "0"
    for ev in events:
        payload_data = {}
        if ev.payload:
            try:
                payload_data = json.loads(ev.payload)
            except Exception:
                pass

        # For USER_DELETED events: if the user no longer exists (already hard-deleted),
        # still propagate the delete event so all devices can remove their local copy.
        # For USER_CREATED/USER_UPDATED: skip events for users that are now inactive/deleted
        # so stale events cannot resurrect a deleted account.
        if ev.entity_type in ("user", "users") and ev.event_type in ("USER_CREATED", "USER_UPDATED"):
            target_username = (payload_data.get("username") or "").strip().lower() if isinstance(payload_data, dict) else ""
            target_email = (payload_data.get("email") or "").strip().lower() if isinstance(payload_data, dict) else ""
            
            user_filters = [BackendUser.id == ev.entity_id]
            if target_username:
                user_filters.append(func.lower(BackendUser.username) == target_username)
            if target_email:
                user_filters.append(func.lower(BackendUser.email) == target_email)

            from sqlalchemy import or_
            live_user = db.query(BackendUser).filter(
                BackendUser.business_id == ev.business_id,
                BackendUser.is_active == True,
                or_(*user_filters)
            ).first()
            if live_user is None:
                print(f"[INCREMENTAL SYNC TRACE] Skipping USER event for deleted/inactive user entity_id={ev.entity_id} event_type={ev.event_type}")
                # Emit a synthetic USER_DELETED instead so devices discard stale data
                changes.append({
                    "id": ev.event_id + "_del",
                    "table": ev.entity_type,
                    "op": "USER_DELETED",
                    "recordId": ev.entity_id,
                    "shopId": ev.business_id,
                    "payload": {"uid": ev.entity_id, "id": ev.entity_id},
                    "timestamp": ev.created_at.isoformat() if ev.created_at else None,
                })
                if ev.created_at:
                    latest_cursor = ev.created_at.isoformat()
                continue

        if isinstance(payload_data, dict):
            if "shopId" not in payload_data or not payload_data["shopId"]:
                payload_data["shopId"] = ev.business_id
            if "businessId" not in payload_data or not payload_data["businessId"]:
                payload_data["businessId"] = ev.business_id

        changes.append({
            "id": ev.event_id,
            "table": ev.entity_type,
            "op": ev.event_type,
            "recordId": ev.entity_id,
            "shopId": ev.business_id,
            "payload": payload_data,
            "timestamp": ev.created_at.isoformat() if ev.created_at else None,
        })
        if ev.entity_type in ("user", "users"):
            print(f"[USER SYNC TRACE] event_id={ev.event_id} business_id={ev.business_id} target_user_id={ev.entity_id} event_type={ev.event_type}")
            print(f"[USER SYNC TRACE] stage=DEVICE_REQUESTED stage=DEVICE_RECEIVED")
        if ev.created_at:
            latest_cursor = ev.created_at.isoformat()

    return {
        "status": "success",
        "cursor": latest_cursor,
        "changes": changes,
    }


@router.post("/conflicts/{conflict_id}/acknowledge", status_code=status.HTTP_200_OK)
def acknowledge_conflict(
    conflict_id: str,
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id),
    authorization: Optional[str] = Header(None),
):
    """
    POST /sync/conflicts/{conflict_id}/acknowledge
    Marks a sync conflict as acknowledged by the calling user on the backend.
    Records the user + timestamp on the notification; this propagates to other
    devices on their next /sync/pull so they can update local SyncConflict rows.
    """
    from app.services.auth_service import decode_access_token

    # Resolve who is acknowledging
    acknowledged_by = "unknown"
    acknowledged_username = "unknown"
    if authorization and authorization.startswith("Bearer "):
        claims = decode_access_token(authorization.split(" ")[1]) or {}
        acknowledged_by = claims.get("sub", "unknown")
        acknowledged_username = claims.get("username", claims.get("sub", "unknown"))

    # The stable notification id is prefixed with "cnotif_" — look for both forms.
    notif_id = f"cnotif_{conflict_id}"[:128]
    notif = db.query(NotificationModel).filter(NotificationModel.id == notif_id).first()
    if not notif:
        # Also try the raw conflict_id as id (for legacy records)
        notif = db.query(NotificationModel).filter(NotificationModel.id == conflict_id).first()

    if notif:
        now = datetime.now(timezone.utc)
        # Persist acknowledgement metadata into payload_json
        existing_payload: dict = {}
        if notif.payload_json:
            try:
                existing_payload = json.loads(notif.payload_json)
            except Exception:
                pass
        existing_payload["acknowledged_by"] = acknowledged_by
        existing_payload["acknowledged_username"] = acknowledged_username
        existing_payload["acknowledged_at"] = now.isoformat()
        notif.payload_json = json.dumps(existing_payload)
        notif.is_read = True
        notif.updated_at = now
        notif.version = (notif.version or 1) + 1

        # Emit an outbox event so other devices learn this conflict was acknowledged
        ack_event_id = f"ack_{conflict_id}"[:128]
        existing_ack = db.query(OutboxEvent).filter(OutboxEvent.event_id == ack_event_id).first()
        if not existing_ack:
            ack_ev = OutboxEvent(
                event_id=ack_event_id,
                business_id=notif.business_id,
                device_id="server",
                branch_id=notif.branch_id or "main",
                user_id=acknowledged_by,
                event_type="CONFLICT_ACKNOWLEDGED",
                entity_type="notifications",
                entity_id=notif.id,
                payload=json.dumps({
                    "conflict_id": conflict_id,
                    "notification_id": notif.id,
                    "acknowledged_by": acknowledged_by,
                    "acknowledged_username": acknowledged_username,
                    "acknowledged_at": now.isoformat(),
                    "shopId": notif.business_id,
                }),
                created_at=now,
                processed_at=now,
                sync_status="SYNCED",
                server_ack=f"ACK-{now.strftime('%Y%m%d%H%M%S')}",
            )
            db.add(ack_ev)

        db.commit()
        print(f"[CONFLICT ACK] conflict_id={conflict_id} acknowledged_by={acknowledged_username}")
        return {
            "status": "acknowledged",
            "conflict_id": conflict_id,
            "acknowledged_by": acknowledged_username,
        }

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"No conflict notification found for conflict_id={conflict_id}",
    )


_ALLOWED_PLANS = {"trial", "starter", "business", "enterprise", "free"}


def _parse_dt(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None


def _subscription_json(sub: SubscriptionModel) -> dict:
    return {
        "shopId": sub.business_id,
        "plan": sub.plan,
        "activationDate": sub.activation_date.isoformat() if sub.activation_date else None,
        "expiryDate": sub.expiry_date.isoformat() if sub.expiry_date else None,
        "addOns": sub.add_ons or "[]",
        "isTrial": bool(sub.is_trial),
        "userLimit": sub.user_limit,
        "branchLimit": sub.branch_limit,
        "pendingPlan": sub.pending_plan,
        "pendingAddOns": sub.pending_add_ons,
        "pendingEffectiveDate": (
            sub.pending_effective_date.isoformat()
            if sub.pending_effective_date
            else None
        ),
        "pendingPrice": sub.pending_price,
        "updatedAt": sub.updated_at.isoformat() if sub.updated_at else None,
    }


@router.get("/subscription", status_code=status.HTTP_200_OK)
def get_business_subscription(
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id),
):
    """Return the stored subscription for the authenticated business."""
    if not auth_business_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")
    sub = db.query(SubscriptionModel).filter(SubscriptionModel.business_id == auth_business_id).first()
    if not sub:
        return {"subscription": None}
    return {"subscription": _subscription_json(sub)}


@router.post("/subscription", status_code=status.HTTP_200_OK)
def upsert_business_subscription(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id),
):
    """Store the subscription pushed by a device (last-expiry-wins).

    The business id always comes from the token, never from the body.
    """
    if not auth_business_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")

    plan = str(payload.get("plan") or "").strip().lower()
    if plan not in _ALLOWED_PLANS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unknown subscription plan.")

    expiry = _parse_dt(payload.get("expiryDate") or payload.get("expiry_date"))
    activation = _parse_dt(payload.get("activationDate") or payload.get("activation_date"))
    if expiry is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="expiryDate is required.")

    def _clamp(value, default):
        try:
            return max(0, min(1000, int(value)))
        except (TypeError, ValueError):
            return default

    addons = payload.get("addOns", payload.get("add_ons", "[]"))
    if isinstance(addons, list):
        addons = json.dumps(addons)
    addons = str(addons)[:4000]

    pending_plan = payload.get("pendingPlan") or payload.get("pending_plan")
    pending_effective = _parse_dt(
        payload.get("pendingEffectiveDate") or payload.get("pending_effective_date")
    )
    if pending_plan:
        pending_plan = str(pending_plan).strip().lower()
        if pending_plan not in _ALLOWED_PLANS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unknown pending subscription plan.",
            )
        if pending_effective is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="pendingEffectiveDate is required with pendingPlan.",
            )

    existing = db.query(SubscriptionModel).filter(SubscriptionModel.business_id == auth_business_id).first()
    existing_expiry = existing.expiry_date if existing else None
    if existing_expiry is not None:
        if existing_expiry.tzinfo is None:
            existing_expiry = existing_expiry.replace(tzinfo=timezone.utc)
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if existing_expiry >= expiry:
            return {"subscription": _subscription_json(existing), "applied": False}

    sub = existing or SubscriptionModel(business_id=auth_business_id)
    sub.plan = plan
    sub.activation_date = activation
    sub.expiry_date = expiry
    sub.add_ons = addons
    sub.is_trial = bool(payload.get("isTrial", payload.get("is_trial", plan == "trial")))
    sub.user_limit = _clamp(payload.get("userLimit", payload.get("user_limit")), 3)
    sub.branch_limit = _clamp(payload.get("branchLimit", payload.get("branch_limit")), 1)
    if pending_plan:
        sub.pending_plan = pending_plan
        sub.pending_effective_date = pending_effective
        pending_addons = payload.get(
            "pendingAddOns", payload.get("pending_add_ons", "[]")
        )
        if isinstance(pending_addons, list):
            pending_addons = json.dumps(pending_addons)
        sub.pending_add_ons = str(pending_addons)[:4000]
        try:
            sub.pending_price = float(
                payload.get("pendingPrice", payload.get("pending_price")) or 0
            )
        except (TypeError, ValueError):
            sub.pending_price = 0
    else:
        sub.pending_plan = None
        sub.pending_effective_date = None
        sub.pending_add_ons = None
        sub.pending_price = None

    sub.updated_at = datetime.now(timezone.utc)
    if existing is None:
        db.add(sub)
    db.commit()
    db.refresh(sub)
    return {"subscription": _subscription_json(sub), "applied": True}


@router.post("/subscription/cancel", status_code=status.HTTP_200_OK)
def cancel_business_subscription(
    db: Session = Depends(get_db),
    auth_business_id: Optional[str] = Depends(get_auth_business_id),
):
    """Remove the stored subscription so every device drops back to a trial."""
    if not auth_business_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")
    sub = db.query(SubscriptionModel).filter(SubscriptionModel.business_id == auth_business_id).first()
    if sub:
        db.delete(sub)
        db.commit()
    return {"cancelled": True}
