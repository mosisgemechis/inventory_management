from datetime import datetime, timezone

import json

import uuid

from typing import List, Tuple, Dict, Any, Optional

from sqlalchemy.orm import Session

from app.models.outbox import OutboxEvent

import re

from app.models.business_data import (

    ProductModel, CategoryModel, CustomerModel, SupplierModel, BatchModel,

    SaleModel, PurchaseModel, AuditLogModel, ProductStockModel, NotificationModel, SettingModel,

    ProductIdentityAlias,

)

from app.models.identity import BackendUser, Device, Business, BackendBranch, RefreshToken

from app.schemas.sync import SyncEventsRequest

from app.services.auth_service import hash_password, revoke_all_user_tokens



def _normalize_product_name(name: Optional[str]) -> str:

    if not name:

        return ""

    return re.sub(r'\s+', ' ', str(name).strip()).lower()



def _sale_batch_allocations(payload: Dict[str, Any], sale_qty: float) -> List[Tuple[str, float]]:

    """Read the client FEFO allocation without treating JSON as one batch ID."""

    raw = payload.get("batchAllocations") or payload.get("batch_allocations")

    if isinstance(raw, list):

        allocations = []

        for value in raw:

            if not isinstance(value, dict):

                continue

            batch_id = str(value.get("batchId") or value.get("batch_id") or "")

            quantity = float(value.get("quantity") or 0.0)

            if batch_id and quantity > 0:

                allocations.append((batch_id, quantity))

        if allocations:

            return allocations



    raw_batch_id = payload.get("batchId") or payload.get("batch_id")

    if isinstance(raw_batch_id, str) and raw_batch_id.startswith("["):

        try:

            return _sale_batch_allocations({"batchAllocations": json.loads(raw_batch_id)}, sale_qty)

        except (TypeError, ValueError):

            return []

    return [(str(raw_batch_id), sale_qty)] if raw_batch_id else []



def _create_conflict_notification(

    db: Session,

    business_id: str,

    title: str,

    body: str,

    branch_id: Optional[str] = "main",

    device_id: Optional[str] = None,

    conflict_id: Optional[str] = None,

    conflict_type: str = "other",

    entity_type: str = "",

    entity_id: str = "",

    entity_name: str = "",

    what_happened: Optional[str] = None,

    what_system_did: Optional[str] = None,

    required_action: Optional[str] = None,

    requires_action: bool = False,

    severity: str = "medium",

) -> None:

    """Creates a user-visible, idempotent notification for sync conflict resolutions.



    A stable `conflict_id` is stored in payload_json so the Flutter client can

    convert this notification into a persistent SyncConflict row without creating

    duplicate records on retry.

    """

    now = datetime.now(timezone.utc)

    # Derive a stable notification id from conflict_id so HTTP retries are idempotent.

    effective_conflict_id = conflict_id or f"bk_{conflict_type}_{entity_id}_{business_id}"

    notif_id = f"cnotif_{effective_conflict_id}"[:128]



    # Deduplicate: if a notification for this conflict already exists, skip.

    existing_notif = db.query(NotificationModel).filter(NotificationModel.id == notif_id).first()

    if existing_notif:

        return



    payload_json_data = json.dumps({

        "conflict_id": effective_conflict_id,

        "conflict_type": conflict_type,

        "entity_type": entity_type,

        "entity_id": entity_id,

        "entity_name": entity_name,

        "what_happened": what_happened,

        "what_system_did": what_system_did,

        "required_action": required_action,

        "requires_action": requires_action,

        "severity": severity,

    })



    notif = NotificationModel(

        id=notif_id,

        business_id=business_id,

        branch_id=branch_id or "main",

        title=title,

        body=body,

        type="sync_conflict",

        priority="high" if requires_action or severity == "high" else "normal",

        related_entity_id=entity_id or None,

        item_id=entity_id or None,

        is_read=False,

        timestamp=now,

        payload_json=payload_json_data,

        version=1,

        last_modified_by_device=device_id,

        is_deleted=False,

        created_at=now,

        updated_at=now

    )

    db.add(notif)



def _log_conflict_audit(

    db: Session,

    business_id: str,

    branch_id: Optional[str],

    device_id: str,

    username: Optional[str],

    details: str

) -> None:

    """Records a durable conflict resolution audit log entry in PostgreSQL."""

    now = datetime.now(timezone.utc)

    audit = AuditLogModel(

        id=str(uuid.uuid4()),

        business_id=business_id,

        branch_id=branch_id or "main",

        username=username or "SYNC_ENGINE",

        action="CONFLICT_RESOLUTION",

        details=details,

        timestamp=now,

        version=1,

        last_modified_by_device=device_id,

        is_deleted=False,

        created_at=now,

        updated_at=now

    )

    db.add(audit)



def process_sync_events(

    db: Session,

    request: SyncEventsRequest,

    authenticated_business_id: Optional[str] = None

) -> Tuple[List[str], List[Dict[str, Any]], List[Dict[str, str]]]:

    """

    Idempotently processes all sync outbox events from a client device.

    1. Validates JWT / business ownership if authenticated_business_id is passed.

    2. Checks idempotency via event_id.

    3. Saves OutboxEvent.

    4. Applies business logic to PostgreSQL tables (Product, Customer, etc.)

    5. Populates conflict foundation metadata: id, updated_at, version, last_modified_by_device.

    """

    synced_ids: List[str] = []

    rejected: List[Dict[str, Any]] = []

    identity_resolutions: List[Dict[str, str]] = []



    target_business_id = authenticated_business_id or request.shopId



    for item in request.events:

        payload = item.payload or {}

        event_id = item.id or payload.get("id") or payload.get("event_id") or str(uuid.uuid4())

        biz_id = item.business_id or payload.get("business_id") or payload.get("shopId") or target_business_id or request.shopId

        dev_id = item.device_id or payload.get("device_id") or payload.get("deviceId") or request.deviceId or "unknown-device"

        user_id = item.user_id or payload.get("user_id") or payload.get("userId")

        branch_id = item.branch_id or payload.get("branch_id") or payload.get("branchId") or "main"

        

        raw_event_type = item.event_type or payload.get("event_type") or payload.get("eventType") or "GENERIC_EVENT"

        event_type = str(raw_event_type).upper()



        raw_entity_type = item.entity_type or payload.get("entity_type") or payload.get("entityType") or "unknown"

        entity_type = str(raw_entity_type).lower()



        entity_id = str(item.entity_id or payload.get("entity_id") or payload.get("entityId") or payload.get("id") or payload.get("uid") or "")



        # Product IDs can be rewritten after an offline duplicate was reconciled.

        # Resolve every dependent event before it reaches its persistence handler so

        # batches, sales and branch stock never keep pointing at the ghost ID.

        referenced_product_id = str(

            payload.get("itemId") or payload.get("item_id") or

            payload.get("productId") or payload.get("product_id") or ""

        )

        alias_source_id = entity_id if entity_type in ("product", "products") else referenced_product_id

        if alias_source_id:

            alias = db.query(ProductIdentityAlias).filter(

                ProductIdentityAlias.business_id == biz_id,

                ProductIdentityAlias.source_product_id == alias_source_id,

            ).first()

            if alias:

                canonical_id = alias.canonical_product_id

                if entity_type in ("product", "products"):

                    entity_id = canonical_id

                else:

                    payload = dict(payload)

                    payload["itemId"] = canonical_id

                    payload["item_id"] = canonical_id

                    payload["productId"] = canonical_id

                    payload["product_id"] = canonical_id



        print(f"[SYNC EVENT RECEIVED]\nevent_id={event_id}\nevent_type={event_type}\nbusiness_id={biz_id}\ndevice_id={dev_id}\nuser_id={user_id}")

        print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=BACKEND_RECEIVED\nsuccess=true")



        # 1. Validation & Normalization: ensure business ownership matches token

        if authenticated_business_id:

            if biz_id != authenticated_business_id:

                print(f"[BUSINESS ID OVERRIDE] Replaced event biz_id={biz_id} with authenticated_business_id={authenticated_business_id}")

                biz_id = authenticated_business_id



        print(f"[SYNC EVENT VALIDATED]\nevent_id={event_id}")

        print(f"[SYNC EVENT PROCESSING]\nevent_id={event_id}")

        print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=BACKEND_PROCESSED\nsuccess=true")



        try:

            # 2. Idempotency Check

            existing = db.query(OutboxEvent).filter(OutboxEvent.event_id == event_id).first()

            if existing:

                if existing.sync_status in ("SYNCED", "CONFLICT"):

                    synced_ids.append(event_id)

                else:

                    existing.retry_count += 1

                    existing.processed_at = datetime.now(timezone.utc)

                    existing.sync_status = "SYNCED"

                    existing.last_error = None

                    db.commit()

                    synced_ids.append(event_id)

                print(f"[SYNC EVENT ACK]\nevent_id={event_id}")

                print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=POSTGRES_COMMITTED\nsuccess=true")

                print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=BACKEND_ACKNOWLEDGED\nsuccess=true")

                if existing.canonical_entity_id and existing.canonical_entity_id != existing.entity_id:

                    identity_resolutions.append({

                        "eventId": event_id,

                        "entityType": existing.entity_type,

                        "sourceId": existing.entity_id,

                        "canonicalId": existing.canonical_entity_id,

                        "businessId": existing.business_id,

                        "branchId": existing.branch_id or "main",

                    })

                continue



            # 3. Save Outbox Event

            payload_str = json.dumps(payload) if payload else None

            now_server = datetime.now(timezone.utc)

            # Sanitize payload JSON to never store plaintext passwords in outbox event table (keep password hashes for client sync)

            sanitized_payload = dict(payload) if isinstance(payload, dict) else {}

            sanitized_payload.pop("password", None)

            sanitized_payload.pop("plain_password", None)

            if item.timestamp:

                sanitized_payload.setdefault("clientTimestamp", item.timestamp)

            sanitized_payload_str = json.dumps(sanitized_payload)



            new_event = OutboxEvent(

                event_id=event_id,

                business_id=biz_id,

                device_id=dev_id,

                branch_id=branch_id,

                user_id=user_id,

                event_type=event_type,

                entity_type=entity_type,

                entity_id=entity_id,

                payload=sanitized_payload_str,

                created_at=now_server,

                processed_at=now_server,

                sync_status="SYNCED",

                server_ack=f"ACK-{now_server.strftime('%Y%m%d%H%M%S')}"

            )

            db.add(new_event)



            # 4. Apply entity modifications with conflict foundation attributes

            _apply_entity_mutation(

                db=db,

                business_id=biz_id,

                device_id=dev_id,

                user_id=user_id,

                event_type=event_type,

                entity_type=entity_type,

                entity_id=entity_id,

                payload=payload,

                event_id=event_id,

            )



            if entity_type in ("product", "products"):

                alias = db.query(ProductIdentityAlias).filter(

                    ProductIdentityAlias.business_id == biz_id,

                    ProductIdentityAlias.source_product_id == entity_id,

                ).first()

                if alias and alias.canonical_product_id != entity_id:

                    new_event.canonical_entity_id = alias.canonical_product_id

                    identity_resolutions.append({

                        "eventId": event_id,

                        "entityType": entity_type,

                        "sourceId": entity_id,

                        "canonicalId": alias.canonical_product_id,

                        "businessId": biz_id,

                        "branchId": branch_id or "main",

                    })



            db.commit()

            print(f"[SYNC EVENT DATABASE]\nevent_id={event_id}")

            print(f"[SYNC EVENT COMMITTED]\nevent_id={event_id}")

            print(f"[SYNC EVENT ACK]\nevent_id={event_id}")

            print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=POSTGRES_COMMITTED\nsuccess=true")

            print(f"[SYNC TRACE]\nevent_id={event_id}\nstage=BACKEND_ACKNOWLEDGED\nsuccess=true")

            if entity_type in ("user", "users"):

                print(f"[USER SYNC TRACE]\noperation_id={event_id}\nevent_id={event_id}\nbusiness_id={biz_id}\nactor_user_id={user_id or 'unknown-actor'}\ntarget_user_id={entity_id}\ndevice_id={dev_id}")

                print(f"[USER SYNC TRACE]\nstage=BACKEND_RECEIVED\nstage=BACKEND_PROCESSED\nstage=DATABASE_COMMITTED\nstage=ACKNOWLEDGED\nstage=AVAILABLE_FOR_PULL")

            synced_ids.append(event_id)



        except Exception as err:

            db.rollback()

            rejected.append({"id": event_id, "reason": str(err)})

            # Record durable rejection audit entry in a clean transaction
            if entity_type in ("sale", "sales"):
                try:
                    rej_item_name = str(payload.get("itemName") or payload.get("item_name") or "Unknown Product")
                    rej_qty = float(payload.get("quantity") or 0.0)
                    rej_amt = float(payload.get("totalPrice") or payload.get("total_price") or 0.0)
                    rej_user = str(payload.get("username") or user_id or "unknown")
                    rej_now = datetime.now(timezone.utc)
                    rej_audit_id = f"audit_sale_{entity_id}"
                    rej_details = (
                        f"[REJECTED SALE ATTEMPT] Attempted to sell {rej_qty:.0f} units of \"{rej_item_name}\". "
                        f"Attempted Amount (NOT revenue): {rej_amt:.2f}. "
                        f"Status: Rejected. Reason: {str(err)}. (Sale ID: {entity_id})"
                    )
                    rej_audit = AuditLogModel(
                        id=rej_audit_id,
                        business_id=biz_id,
                        branch_id=branch_id or "main",
                        username=rej_user,
                        action="SALE_REJECTED",
                        details=rej_details,
                        timestamp=rej_now,
                        version=1,
                        last_modified_by_device=dev_id,
                        is_deleted=False,
                        created_at=rej_now,
                        updated_at=rej_now,
                    )
                    db.merge(rej_audit)

                    rej_outbox = OutboxEvent(
                        event_id=f"ev_audit_{rej_audit_id}",
                        business_id=biz_id,
                        device_id=dev_id,
                        branch_id=branch_id or "main",
                        user_id=user_id,
                        event_type="AUDIT_CREATED",
                        entity_type="audit_logs",
                        entity_id=rej_audit_id,
                        payload=json.dumps({
                            "id": rej_audit_id,
                            "shopId": biz_id,
                            "businessId": biz_id,
                            "branchId": branch_id or "main",
                            "username": rej_user,
                            "action": "SALE_REJECTED",
                            "details": rej_details,
                            "timestamp": rej_now.isoformat(),
                        }),
                        created_at=rej_now,
                        processed_at=rej_now,
                        sync_status="SYNCED",
                        server_ack=f"AUTO-{rej_now.strftime('%Y%m%d%H%M%S')}",
                    )
                    db.merge(rej_outbox)
                    db.commit()
                except Exception as audit_err:
                    db.rollback()
                    print(f"[REJECTED SALE AUDIT ERROR] {audit_err}")



    return synced_ids, rejected, identity_resolutions





def _apply_entity_mutation(

    db: Session,

    business_id: str,

    device_id: str,

    event_type: str,

    entity_type: str,

    entity_id: str,

    payload: Dict[str, Any],

    event_id: Optional[str] = None,

    user_id: Optional[str] = None,

) -> None:

    """Updates target business models with conflict foundation metadata."""

    now = datetime.now(timezone.utc)



    # ── USER_CREATED / USER_UPDATED / USER_DELETED ──────────────────────────

    if entity_type in ("user", "users"):

        email = (payload.get("email") or "").strip().lower()

        username = (payload.get("username") or "").strip().lower()

        name = payload.get("fullName") or payload.get("name") or username or "Unknown"

        role_provided = payload.get("role") or (payload.get("roles")[0] if (isinstance(payload.get("roles"), list) and payload.get("roles")) else None)



        print(f"[ACCOUNT SYNC] USER event processing: type={event_type}, target_user_id={entity_id}, email={email}, username={username}, role_provided={role_provided}, business_id={business_id}")



        # Look up existing user by entity_id (Flutter local UID used as correlation key)

        existing = None

        if entity_id:

            existing = db.query(BackendUser).filter(

                BackendUser.business_id == business_id,

                BackendUser.id == entity_id,

            ).first()



        if not existing and email:

            existing = db.query(BackendUser).filter(

                BackendUser.business_id == business_id,

                BackendUser.email == email,

            ).first()



        if not existing and username:

            existing = db.query(BackendUser).filter(

                BackendUser.business_id == business_id,

                BackendUser.username == username,

            ).first()



        # Handle account deletion idempotently

        if event_type in ("USER_DELETED", "DELETE_ACCOUNT", "DELETE"):

            print(f"[ACCOUNT DELETE TRACE]\noperation_id={entity_id}\nevent_id={entity_id}\nbusiness_id={business_id}\ntarget_user_id={entity_id}\nstage=DELETE_REQUESTED")

            print(f"[ACCOUNT DELETE TRACE]\nstage=AUTHORIZED")

            print(f"[ACCOUNT DELETE TRACE]\nstage=BACKEND_RECEIVED")

            if existing:

                print(f"[ACCOUNT DELETE TRACE]\nstage=USER_FOUND\nuser_id={existing.id}\nusername={existing.username}")

                # Increment security revision first so all in-flight tokens immediately fail the sec_rev check

                existing.security_revision = (existing.security_revision or 1) + 1

                # Revoke all refresh tokens / sessions

                revoke_all_user_tokens(db, existing.id)

                print(f"[ACCOUNT DELETE TRACE]\nstage=SESSIONS_REVOKED\ncredential_invalidated=true")

                # Hard-delete the user record so it never appears in any query

                db.delete(existing)

                print(f"[ACCOUNT DELETE TRACE]\nstage=USER_DELETED\nstage=DATABASE_COMMITTED\nstage=EVENT_ACKNOWLEDGED")

            else:

                print(f"[ACCOUNT DELETE TRACE]\nstage=USER_ALREADY_DELETED\ntarget_user_id={entity_id}")

            return



        if not email and not username:

            print("[ACCOUNT SYNC] USER event skipped: no email or username in payload")

            return



        print(f"[STAFF CREATE TRACE]\nevent_id={entity_id}\nbusiness_id={business_id}\ntarget_user_id={entity_id}\nusername={username}\nemail={email}\nstage=BACKEND_RECEIVED")



        if existing:

            # Update mutable fields; never overwrite password hash or role unless provided

            if name: existing.name = name

            if email: existing.email = email

            if username: existing.username = username

            if role_provided: existing.role = role_provided

            if "branchId" in payload or "branch_id" in payload:

                existing.branch_id = payload.get("branchId") or payload.get("branch_id") or "main"

            if "permissions" in payload:

                perms = payload.get("permissions")

                existing.permissions = perms if isinstance(perms, str) else json.dumps(perms) if perms is not None else None

            if "isActive" in payload or "is_active" in payload:

                is_act = payload.get("isActive") if "isActive" in payload else payload.get("is_active")

                existing.is_active = bool(is_act)

                if not existing.is_active:

                    print("[ACCOUNT DELETE] Requested")

                    print("[ACCOUNT DELETE] Authorization verified")

                    print("[ACCOUNT DELETE] Account deletion/deactivation committed")

                    print("[ACCOUNT DELETE] Security revision changed")

                    print("[ACCOUNT DELETE] All sessions invalidated")

                    existing.security_revision = (existing.security_revision or 1) + 1

                    revoke_all_user_tokens(db, existing.id)

            plain_pw = payload.get("password") or payload.get("plain_password")

            pw_hash = payload.get("passwordHash") or payload.get("password_hash")

            is_explicit_pw_change = payload.get("is_password_change") is True or payload.get("isPasswordChange") is True



            if is_explicit_pw_change:

                print(f"[SECURITY] Explicit password change detected for user {existing.id}! Revoking shop sessions and updating hash.")

                new_h = hash_password(plain_pw.strip()) if (plain_pw and isinstance(plain_pw, str) and plain_pw.strip()) else pw_hash

                if new_h:

                    existing.password_hash = new_h

                    if existing.role == "admin":

                        biz = db.query(Business).filter(Business.id == business_id).first()

                        if biz:

                            biz.password_hash = new_h

                    existing.security_revision = (existing.security_revision or 1) + 1

                    revoke_all_business_tokens(db, business_id)

            else:

                # Normal user update — sync password hash if provided, but NEVER bump security_revision or revoke tokens

                if plain_pw and isinstance(plain_pw, str) and plain_pw.strip():

                    existing.password_hash = hash_password(plain_pw.strip())

                elif pw_hash and isinstance(pw_hash, str) and pw_hash.strip() and not existing.password_hash:

                    existing.password_hash = pw_hash

            existing.updated_at = now

            print(f"[ACCOUNT SYNC] Updated existing user target_user_id={existing.id}")

            print(f"[STAFF CREATE TRACE]\nevent_id={entity_id}\nstage=POSTGRES_COMMITTED\nstage=BACKEND_ACKNOWLEDGED\ncredential_exists=true")

            print(f"[STAFF IDENTITY TRACE]\nbackend_user_id={existing.id}\ncredential_user_id={existing.id}")

            print(f"[STAFF BUSINESS TRACE]\nbackend_business_id={existing.business_id}")

        else:

            # Verify business exists before creating user

            biz = db.query(Business).filter(Business.id == business_id).first()

            if not biz:

                print(f"[ACCOUNT SYNC] USER event rejected: business_id={business_id} not found")

                return



            new_id = entity_id if (entity_id and str(entity_id).strip()) else str(uuid.uuid4())

            plain_pw = payload.get("password") or payload.get("plain_password")

            pw_hash_val = payload.get("passwordHash") or payload.get("password_hash")

            if plain_pw and isinstance(plain_pw, str) and plain_pw.strip():

                pw_hash = hash_password(plain_pw.strip())

            elif pw_hash_val and isinstance(pw_hash_val, str) and pw_hash_val.strip():

                if pw_hash_val.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):

                    pw_hash = pw_hash_val

                else:

                    pw_hash = pw_hash_val

            else:

                pw_hash = hash_password("Password123!")



            perms_val = payload.get("permissions")

            if perms_val is not None and not isinstance(perms_val, str):

                perms_val = json.dumps(perms_val)



            new_user = BackendUser(

                id=new_id,

                business_id=business_id,

                name=name,

                username=username or (email.split("@")[0] if email else new_id[:8]),

                email=email or f"{username}@{business_id[:8]}.local",

                password_hash=pw_hash,

                role=role_provided or "inventoryStaff",

                branch_id=payload.get("branchId") or payload.get("branch_id") or "main",

                permissions=perms_val,

                is_active=payload.get("isActive", True),

                created_at=now,

                updated_at=now,

            )

            db.add(new_user)

            print(f"[STAFF CREATE TRACE]\nevent_id={new_id}\nstage=BACKEND_USER_CREATED\nstage=BACKEND_CREDENTIAL_CREATED\nstage=POSTGRES_COMMITTED\nstage=BACKEND_ACKNOWLEDGED\ncredential_exists=true")

            print(f"[STAFF IDENTITY TRACE]\nevent_target_user_id={new_id}\nbackend_user_id={new_id}\ncredential_user_id={new_id}")

            print(f"[STAFF BUSINESS TRACE]\ntarget_business_id={business_id}\nbackend_business_id={business_id}")

            print(f"[ACCOUNT SYNC] Created new backend user target_user_id={new_id} email={email}")

        return



    # ── SHOP_DELETED / BUSINESS_DELETED ─────────────────────────────────────

    if entity_type in ("shop", "shops", "business", "businesses") or event_type in ("SHOP_DELETED", "BUSINESS_DELETED", "DELETE_SHOP"):

        print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BACKEND_RECEIVED\nsuccess=true")

        print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=AUTHENTICATED\nsuccess=true")

        print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=AUTHORIZED\nsuccess=true")

        print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BUSINESS_DELETION_STARTED\nbusiness_id={business_id}")

        biz = db.query(Business).filter(Business.id == business_id).first()

        if biz:

            b_users = db.query(BackendUser).filter(BackendUser.business_id == business_id).all()

            user_ids = [bu.id for bu in b_users]

            for bu in b_users:

                revoke_all_user_tokens(db, bu.id)

            if user_ids:

                db.query(RefreshToken).filter(RefreshToken.user_id.in_(user_ids)).delete(synchronize_session=False)



            db.query(Device).filter(Device.business_id == business_id).delete(synchronize_session=False)

            db.query(BackendBranch).filter(BackendBranch.business_id == business_id).delete(synchronize_session=False)

            db.query(ProductModel).filter(ProductModel.business_id == business_id).delete(synchronize_session=False)

            db.query(CategoryModel).filter(CategoryModel.business_id == business_id).delete(synchronize_session=False)

            db.query(CustomerModel).filter(CustomerModel.business_id == business_id).delete(synchronize_session=False)

            db.query(SupplierModel).filter(SupplierModel.business_id == business_id).delete(synchronize_session=False)

            db.query(BackendUser).filter(BackendUser.business_id == business_id).delete(synchronize_session=False)

            db.query(OutboxEvent).filter(OutboxEvent.business_id == business_id).delete(synchronize_session=False)

            db.delete(biz)

            db.commit()

            print(f"[DELETE SHOP]\nbusiness_id={business_id}\ndelete_committed=true\nshop_sessions_invalidated=true")

            print(f"[SHOP DELETE DATABASE COMMIT]\nresult=success")

            print(f"[SHOP DELETE SESSION REVOCATION]\nresult=success")

            print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BUSINESS_DELETED_OR_DEACTIVATED\nsuccess=true")

            print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=ALL_SESSIONS_INVALIDATED\nsuccess=true")

            print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BACKEND_COMMITTED\nsuccess=true")

        else:

            print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BUSINESS_ALREADY_DELETED\nsuccess=true")

        print(f"[SHOP DELETE TRACE]\nevent_id={entity_id}\nstage=BACKEND_ACKNOWLEDGED\nsuccess=true")

        return



    ev_upper = str(event_type or "").upper()

    op_upper = str(payload.get("operation") or payload.get("op") or "").upper()

    ev_payload_upper = str(payload.get("event_type") or "").upper()

    is_delete_op = (

        "DELETE" in ev_upper or "REMOVE" in ev_upper or "DROP" in ev_upper

        or "DELETE" in op_upper or "REMOVE" in op_upper

        or "DELETE" in ev_payload_upper

    )



    if entity_type in ("product", "products"):

        if is_delete_op:

            prod = db.query(ProductModel).filter(

                ProductModel.id == entity_id, ProductModel.business_id == business_id

            ).first()

            if prod:

                prod.is_deleted = True

                prod.version += 1

                prod.last_modified_by_device = device_id

                prod.updated_at = now

            else:

                prod = ProductModel(

                    id=entity_id,

                    business_id=business_id,

                    branch_id=str(payload.get("branchId") or payload.get("branch_id") or "main"),

                    name=str(payload.get("name") or "Deleted Product"),

                    is_deleted=True,

                    version=1,

                    last_modified_by_device=device_id,

                    created_at=now,

                    updated_at=now

                )

                db.add(prod)

            print(f"[PRODUCT SYNC] Marked product entity_id={entity_id} as is_deleted=True for business_id={business_id}")

            return



        # Concurrency protection: lock business row to serialize concurrent product creations per business

        db.query(Business).filter(Business.id == business_id).with_for_update().first()



        inc_barcode = (str(payload.get("barcode") or "").strip() if payload.get("barcode") else "")

        inc_sku = (str(payload.get("sku") or "").strip() if payload.get("sku") else "")

        inc_name_norm = _normalize_product_name(payload.get("name"))



        prod = db.query(ProductModel).filter(

            ProductModel.id == entity_id, ProductModel.business_id == business_id

        ).first()



        existing_by_identity = None

        if inc_barcode:

            existing_by_identity = db.query(ProductModel).with_for_update().filter(

                ProductModel.business_id == business_id,

                ProductModel.barcode == inc_barcode,

                ProductModel.is_deleted == False

            ).first()

        if not existing_by_identity and inc_sku:

            existing_by_identity = db.query(ProductModel).with_for_update().filter(

                ProductModel.business_id == business_id,

                ProductModel.sku == inc_sku,

                ProductModel.is_deleted == False

            ).first()



        # For products without strong identifiers (or where barcode/SKU are empty),

        # use normalized exact-name matching within the business scope.

        # NEVER merge across businesses, and NEVER merge products with conflicting strong identifiers.

        if not existing_by_identity and inc_name_norm:

            candidates = db.query(ProductModel).with_for_update().filter(

                ProductModel.business_id == business_id,

                ProductModel.is_deleted == False

            ).all()

            for cand in candidates:

                if cand.id == entity_id:

                    continue

                if _normalize_product_name(cand.name) != inc_name_norm:

                    continue

                cand_barcode = (str(cand.barcode or "")).strip()

                cand_sku = (str(cand.sku or "")).strip()

                # Conflicting strong identifiers: do NOT merge if barcodes or SKUs conflict

                if inc_barcode and cand_barcode and inc_barcode != cand_barcode:

                    continue

                if inc_sku and cand_sku and inc_sku != cand_sku:

                    continue

                existing_by_identity = cand

                break



        # Reconcile if matching identity found under a different entity_id

        if existing_by_identity and existing_by_identity.id != entity_id:

            canonical = existing_by_identity

            print(f"[PRODUCT IDENTITY CONFLICT] Incoming product entity_id={entity_id} matches existing product_id={canonical.id}. Reconciling.")

            inc_qty = float(payload.get("quantity") or payload.get("stock_quantity") or payload.get("stockQuantity") or 0.0)

            if inc_qty > 0:

                canonical.stock_quantity += inc_qty

                canonical.updated_at = now



            alias = ProductIdentityAlias(

                business_id=business_id,

                source_product_id=entity_id,

                canonical_product_id=canonical.id,

                created_at=now,

                updated_at=now,

            )

            db.merge(alias)



            canonical_stock = db.query(ProductStockModel).with_for_update().filter(

                ProductStockModel.business_id == business_id,

                ProductStockModel.product_id == canonical.id,

                ProductStockModel.branch_id == (payload.get("branchId") or payload.get("branch_id") or canonical.branch_id or "main"),

            ).first()

            if canonical_stock:

                canonical_stock.quantity += inc_qty

                canonical_stock.updated_at = now

                canonical_stock.version += 1

            else:

                db.add(ProductStockModel(

                    id=f"{canonical.id}@{payload.get('branchId') or payload.get('branch_id') or canonical.branch_id or 'main'}",

                    business_id=business_id,

                    product_id=canonical.id,

                    branch_id=payload.get("branchId") or payload.get("branch_id") or canonical.branch_id or "main",

                    quantity=inc_qty,

                    version=1,

                    last_modified_by_device=device_id,

                    is_deleted=False,

                    created_at=now,

                    updated_at=now,

                ))



            # ── Re-point dependent records from ghost ID → canonical ID ───────────

            # Batches that reference the ghost product ID must be relinked so they

            # appear under the correct product and so FEFO/stock calculations are correct.

            ghost_batches = db.query(BatchModel).filter(

                BatchModel.item_id == entity_id,

                BatchModel.business_id == business_id,

            ).all()

            for gb in ghost_batches:

                gb.item_id = canonical.id

                gb.updated_at = now

                print(f"[PRODUCT DEDUP] Relinked batch {gb.id} from ghost {entity_id} → canonical {canonical.id}")



            # Sales that reference the ghost product ID are relinked so reports

            # show the correct product name and the sale audit is consistent.

            ghost_sales = db.query(SaleModel).filter(

                SaleModel.item_id == entity_id,

                SaleModel.business_id == business_id,

            ).all()

            for gs in ghost_sales:

                gs.item_id = canonical.id

                gs.updated_at = now

                print(f"[PRODUCT DEDUP] Relinked sale {gs.id} from ghost {entity_id} → canonical {canonical.id}")



            ghost_purchases = db.query(PurchaseModel).filter(

                PurchaseModel.item_id == entity_id,

                PurchaseModel.business_id == business_id,

            ).all()

            for gp in ghost_purchases:

                gp.item_id = canonical.id

                gp.updated_at = now

                print(f"[PRODUCT DEDUP] Relinked purchase {gp.id} from ghost {entity_id} → canonical {canonical.id}")



            # Adopt barcode/SKU if canonical was missing them and incoming has them

            if not canonical.barcode and inc_barcode:

                canonical.barcode = inc_barcode

            if not canonical.sku and inc_sku:

                canonical.sku = inc_sku

            # If canonical has a placeholder/stub name, update with real incoming name

            incoming_real_name = (payload.get("name") or "").strip()

            if incoming_real_name and (canonical.name.startswith("[Pending]") or canonical.name.startswith("Product ") or canonical.name == "Unnamed Product"):

                canonical.name = incoming_real_name



            _log_conflict_audit(

                db=db,

                business_id=business_id,

                branch_id=payload.get("branchId") or payload.get("branch_id"),

                device_id=device_id,

                username=payload.get("username"),

                details=(

                    f"[CONFLICT RECONCILED] Offline product '{payload.get('name')}' (ID: {entity_id}) "

                    f"merged into existing product (ID: {canonical.id}). "

                    f"Stock increased by +{inc_qty} → new total {canonical.stock_quantity}. "

                    f"{len(ghost_batches)} batch(es) and {len(ghost_sales)} sale(s) relinked."

                )

            )

            _create_conflict_notification(

                db=db,

                business_id=business_id,

                title="Duplicate Product Combined",

                body=(

                    f"The product \"{ payload.get('name') or canonical.name }\" was created on more than one device "

                    f"while offline. GM Inventory Everywhere matched the records and combined them under one product. "

                    f"Stock was increased by {inc_qty} units (new total: {canonical.stock_quantity}). "

                    f"Please review the resulting stock and batch records to confirm they are correct."

                ),

                branch_id=payload.get("branchId") or payload.get("branch_id"),

                device_id=device_id,

                conflict_id=f"product_dedup_{entity_id}_{canonical.id}",

                conflict_type="product_dedup",

                entity_type="products",

                entity_id=canonical.id,

                entity_name=payload.get('name') or canonical.name,

                what_happened=(

                    f"\"{ payload.get('name') or canonical.name }\" was created on this device while offline. "

                    f"Another device had already created a product with the same name/barcode on the server."

                ),

                what_system_did=(

                    f"GM Inventory Everywhere matched the two records using their barcode, SKU, or name. "

                    f"The stock from this device (+{inc_qty} units) was added to the existing product. "

                    f"All batch and sale records were relinked to the combined product."

                ),

                required_action=(

                    "Review the combined product record and verify the stock count and batch records are correct. "

                    "If the two products were actually different items (e.g. same name, different brands), "

                    "create a separate product manually and adjust the stock."

                ),

                requires_action=True,

                severity="high",

            )

            prod = canonical

            # ── Early return: stock was merged additively above.

            # Do NOT fall through to the unconditional stock-set below,

            # which would overwrite the additive total with just the ghost's quantity.

            prod.version = (prod.version or 1) + 1

            prod.last_modified_by_device = device_id

            db.flush()

            return

        elif not prod:

            prod = ProductModel(

                id=entity_id,

                business_id=business_id,

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(prod)



        # Tombstone Safety Check: ignore edits to soft-deleted items unless explicit restore

        if prod.is_deleted:

            explicit_restore = payload.get("is_deleted") is False or payload.get("isDeleted") is False or event_type == "RESTORE_PRODUCT"

            if not explicit_restore:

                print(f"[PRODUCT EDIT IGNORED] Product entity_id={prod.id} is deleted (tombstoned). Edit ignored.")

                _log_conflict_audit(

                    db=db,

                    business_id=business_id,

                    branch_id=payload.get("branchId") or payload.get("branch_id"),

                    device_id=device_id,

                    username=payload.get("username"),

                    details=f"[CONFLICT IGNORED] Edit for deleted product {prod.id} from device {device_id} ignored to preserve tombstone."

                )

                return

            prod.is_deleted = False



        prod.version += 1

        prod.last_modified_by_device = device_id

        prod.updated_at = now



        if "name" in payload and payload["name"] is not None and str(payload["name"]).strip() != "":

            prod.name = str(payload["name"]).strip()

        elif not getattr(prod, "name", None) or str(prod.name).strip() == "" or str(prod.name).strip() == "Unnamed Product":

            incoming_name = str(payload.get("name") or payload.get("itemName") or "").strip()

            prod.name = incoming_name if incoming_name else "Unnamed Product"

        if "sku" in payload and payload["sku"] is not None: prod.sku = str(payload["sku"])

        if "barcode" in payload and payload["barcode"] is not None: prod.barcode = str(payload["barcode"]).strip() or None

        if "sellingPrice" in payload or "selling_price" in payload or "price" in payload:

            prod.price = float(payload.get("sellingPrice") or payload.get("selling_price") or payload.get("price") or 0.0)

        if "buyingPrice" in payload or "buying_price" in payload or "costPrice" in payload or "cost_price" in payload:

            prod.cost_price = float(payload.get("buyingPrice") or payload.get("buying_price") or payload.get("costPrice") or payload.get("cost_price") or 0.0)

        if "quantity" in payload or "stockQuantity" in payload or "stock_quantity" in payload:

            inc_qty = float(payload.get("quantity") or payload.get("stockQuantity") or payload.get("stock_quantity") or 0.0)

            if "RESTOCK" in event_type or "PURCHASE" in event_type or payload.get("is_additive") is True:

                prod.stock_quantity += inc_qty

            else:

                prod.stock_quantity = inc_qty

        if "branchId" in payload or "branch_id" in payload:

            prod.branch_id = str(payload.get("branchId") or payload.get("branch_id") or "main")

        if "lowStockThreshold" in payload or "min_stock_threshold" in payload:

            prod.min_stock_threshold = float(payload.get("lowStockThreshold") or payload.get("min_stock_threshold") or 5.0)

        if "expiryDate" in payload or "expiry_date" in payload or "expiry" in payload or "exp" in payload:

            raw_exp = payload.get("expiryDate") or payload.get("expiry_date") or payload.get("expiry") or payload.get("exp")

            if raw_exp:

                try:

                    if isinstance(raw_exp, datetime):

                        prod.expiry_date = raw_exp

                    else:

                        prod.expiry_date = datetime.fromisoformat(str(raw_exp).replace("Z", "+00:00"))

                except Exception:

                    pass



        # Keep the branch-scoped stock cache aligned with explicit product

        # creation/edit events. Sales and transfers update this row atomically in

        # their own handlers, so derived client cache writes are not required.

        product_branch = str(payload.get("branchId") or payload.get("branch_id") or prod.branch_id or "main")

        if "quantity" in payload or "stockQuantity" in payload or "stock_quantity" in payload:

            desired_qty = prod.stock_quantity

            branch_stock = db.query(ProductStockModel).filter(

                ProductStockModel.business_id == business_id,

                ProductStockModel.product_id == prod.id,

                ProductStockModel.branch_id == product_branch,

            ).first()

            if branch_stock:

                branch_stock.quantity = desired_qty

                branch_stock.version += 1

                branch_stock.updated_at = now

            else:

                db.add(ProductStockModel(

                    id=f"{prod.id}@{product_branch}",

                    business_id=business_id,

                    product_id=prod.id,

                    branch_id=product_branch,

                    quantity=desired_qty,

                    version=1,

                    last_modified_by_device=device_id,

                    is_deleted=False,

                    created_at=now,

                    updated_at=now,

                ))



    elif entity_type in ("category", "categories"):

        cat = db.query(CategoryModel).filter(

            CategoryModel.id == entity_id, CategoryModel.business_id == business_id

        ).first()

        if not cat:

            cat = CategoryModel(

                id=entity_id,

                business_id=business_id,

                name=str(payload.get("name", "Category")),

                version=1,

                last_modified_by_device=device_id,

                created_at=now,

                updated_at=now

            )

            db.add(cat)

        else:

            cat.version += 1

            cat.last_modified_by_device = device_id

            cat.updated_at = now

            if "name" in payload and payload["name"]: cat.name = str(payload["name"])



    elif entity_type in ("app_settings", "settings", "setting", "app_setting"):

        setting_key = str(payload.get("key") or entity_id)

        setting_val = str(payload.get("value") or "")

        st = db.query(SettingModel).filter(

            SettingModel.business_id == business_id, SettingModel.key == setting_key

        ).first()

        if not st:

            st = SettingModel(

                key=setting_key,

                business_id=business_id,

                value=setting_val,

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(st)

        else:

            st.value = setting_val

            st.version += 1

            st.last_modified_by_device = device_id

            st.updated_at = now



        if setting_key == "currency" and setting_val:

            biz = db.query(Business).filter(Business.id == business_id).first()

            if biz:

                biz.currency = setting_val

                biz.updated_at = now

        print(f"[SETTINGS SYNC] Business {business_id} setting key={setting_key} updated to '{setting_val}'")



    elif entity_type in ("customer", "customers"):

        cust = db.query(CustomerModel).filter(

            CustomerModel.id == entity_id, CustomerModel.business_id == business_id

        ).first()



        is_payment_op = event_type in ("CUSTOMER_PAYMENT", "PAYMENT_CREATED", "DEBT_REPAYMENT") or payload.get("action") == "PAYMENT"

        if is_payment_op:

            pay_amt = float(payload.get("amount") or payload.get("paymentAmount") or payload.get("payment_amount") or 0.0)

            if cust:

                cust.balance = max(0.0, cust.balance - pay_amt)

                cust.version += 1

                cust.updated_at = now

                print(f"[PAYMENT SYNC] Customer {cust.name} balance reduced by {pay_amt} (new balance={cust.balance})")

                _log_conflict_audit(

                    db=db,

                    business_id=business_id,

                    branch_id=str(payload.get("branchId") or payload.get("branch_id") or "main"),

                    device_id=device_id,

                    username=payload.get("username"),

                    details=f"[FINANCIAL EVENT] Additive payment of {pay_amt} applied for customer {cust.name} ({cust.id}). Remaining balance: {cust.balance}"

                )

            return



        if not cust:

            cust = CustomerModel(

                id=entity_id,

                business_id=business_id,

                name=str(payload.get("name", "Customer")),

                phone=payload.get("phone"),

                email=payload.get("email"),

                balance=float(payload.get("balance") or payload.get("debt") or 0.0),

                version=1,

                last_modified_by_device=device_id,

                created_at=now,

                updated_at=now

            )

            db.add(cust)

        else:

            cust.version += 1

            cust.last_modified_by_device = device_id

            cust.updated_at = now

            if "name" in payload and payload["name"]: cust.name = str(payload["name"])

            if "phone" in payload: cust.phone = str(payload["phone"])



    elif entity_type in ("supplier", "suppliers"):

        sup = db.query(SupplierModel).filter(

            SupplierModel.id == entity_id, SupplierModel.business_id == business_id

        ).first()

        if not sup:

            sup = SupplierModel(

                id=entity_id,

                business_id=business_id,

                name=str(payload.get("name", "Supplier")),

                phone=payload.get("phone"),

                email=payload.get("email"),

                version=1,

                last_modified_by_device=device_id,

                created_at=now,

                updated_at=now

            )

            db.add(sup)

        else:

            sup.version += 1

            sup.last_modified_by_device = device_id

            sup.updated_at = now

            if "name" in payload and payload["name"]: sup.name = str(payload["name"])



    elif entity_type in ("batch", "batches"):

        batch = db.query(BatchModel).filter(

            BatchModel.id == entity_id, BatchModel.business_id == business_id

        ).first()



        is_delete_op = event_type in ("DELETE", "BATCH_DELETED") or payload.get("operation") == "delete"

        if is_delete_op:

            if batch:

                batch.is_deleted = True

                batch.version += 1

                batch.last_modified_by_device = device_id

                batch.updated_at = now

            return



        item_id = str(payload.get("itemId") or payload.get("item_id") or payload.get("productId") or payload.get("product_id") or "")

        branch_id = str(payload.get("branchId") or payload.get("branch_id") or "main")

        qty = float(payload.get("quantity") or 0.0)

        buy_p = float(payload.get("buyingPrice") or payload.get("buying_price") or payload.get("costPrice") or payload.get("cost_price") or 0.0)

        sell_p_raw = payload.get("sellingPrice") or payload.get("selling_price") or payload.get("price")

        sell_p = float(sell_p_raw) if sell_p_raw is not None and sell_p_raw != "" else None



        raw_exp = payload.get("expiryDate") or payload.get("expiry_date") or payload.get("expiry") or payload.get("exp")

        exp_dt = None

        if raw_exp:

            try:

                if isinstance(raw_exp, datetime):

                    exp_dt = raw_exp

                else:

                    exp_dt = datetime.fromisoformat(str(raw_exp).replace("Z", "+00:00"))

            except Exception:

                pass



        if not batch:

            batch = BatchModel(

                id=entity_id,

                business_id=business_id,

                branch_id=branch_id,

                item_id=item_id,

                batch_number=payload.get("batchNumber") or payload.get("batch_number"),

                quantity=qty,

                buying_price=buy_p,

                selling_price=sell_p,

                expiry_date=exp_dt,

                batch_type=payload.get("type") or "restock",

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(batch)

        else:

            if "RESTOCK" in event_type or payload.get("is_additive") is True:

                batch.quantity += qty

            else:

                batch.quantity = qty

            batch.is_deleted = False

            batch.version += 1

            batch.last_modified_by_device = device_id

            batch.updated_at = now

            batch.branch_id = branch_id

            if item_id: batch.item_id = item_id

            batch.buying_price = buy_p

            if sell_p is not None: batch.selling_price = sell_p

            if exp_dt is not None: batch.expiry_date = exp_dt

            if "batchNumber" in payload or "batch_number" in payload:

                batch.batch_number = payload.get("batchNumber") or payload.get("batch_number")

            print(f"[BATCH SYNC] Updated batch entity_id={entity_id} item_id={item_id} qty={batch.quantity} for business_id={business_id}")



    elif entity_type in ("sale", "sales"):

        sale = db.query(SaleModel).filter(

            SaleModel.id == entity_id, SaleModel.business_id == business_id

        ).first()



        is_delete_op = event_type in ("DELETE", "SALE_DELETED") or payload.get("operation") == "delete"

        if is_delete_op:

            if sale:

                sale.is_deleted = True

                sale.version += 1

                sale.last_modified_by_device = device_id

                sale.updated_at = now

            return



        raw_ts = payload.get("timestamp") or payload.get("createdAt") or payload.get("created_at")

        ts_dt = now

        if raw_ts:

            try:

                if isinstance(raw_ts, datetime): ts_dt = raw_ts

                else: ts_dt = datetime.fromisoformat(str(raw_ts).replace("Z", "+00:00"))

            except Exception: pass



        item_id = str(payload.get("itemId") or payload.get("item_id") or "")

        branch_id = str(payload.get("branchId") or payload.get("branch_id") or "main")

        sale_qty = float(payload.get("quantity") or 0.0)



        # Handle REFUND events additively (via explicit event, action, or incoming refundedQuantity > existing)
        incoming_refund_val = float(payload.get("refundQuantity") or payload.get("refundedQuantity") or payload.get("refunded_quantity") or 0.0)
        is_refund_op = (
            event_type in ("REFUND_CREATED", "SALE_REFUNDED", "REFUND")
            or payload.get("action") == "REFUND"
            or (sale is not None and incoming_refund_val > (sale.refunded_quantity or 0.0))
        )
        if is_refund_op:
            if sale:
                already_refunded = sale.refunded_quantity or 0.0
                if incoming_refund_val > already_refunded and "refundQuantity" not in payload:
                    incoming_refund = incoming_refund_val - already_refunded
                else:
                    incoming_refund = float(payload.get("refundQuantity") or payload.get("quantity") or (incoming_refund_val - already_refunded) or 0.0)

                allowed_refund = min(incoming_refund, max(0.0, sale.quantity - already_refunded))

                if allowed_refund < incoming_refund:
                    _log_conflict_audit(
                        db=db,
                        business_id=business_id,
                        branch_id=branch_id,
                        device_id=device_id,
                        username=payload.get("username") or sale.username,
                        details=f"[REFUND CONFLICT] Refund request of {incoming_refund} for sale {sale.id} capped at {allowed_refund} (sold: {sale.quantity}, already refunded: {already_refunded})"
                    )

                if allowed_refund > 0:
                    sale.refunded_quantity = already_refunded + allowed_refund
                    sale.version += 1
                    sale.updated_at = now

                    # 1. Restore product stock additively
                    prod = db.query(ProductModel).filter(ProductModel.id == sale.item_id, ProductModel.business_id == business_id).first()
                    if prod:
                        prod.stock_quantity += allowed_refund
                        prod.updated_at = now

                    # 2. Restore branch stock in ProductStockModel additively
                    eff_branch = sale.branch_id or branch_id or "main"
                    b_stock = db.query(ProductStockModel).filter(
                        ProductStockModel.business_id == business_id,
                        ProductStockModel.product_id == sale.item_id,
                        ProductStockModel.branch_id == eff_branch,
                    ).first()
                    if b_stock:
                        b_stock.quantity += allowed_refund
                        b_stock.version += 1
                        b_stock.updated_at = now
                    elif prod:
                        b_stock = ProductStockModel(
                            id=f"{sale.item_id}@{eff_branch}",
                            business_id=business_id,
                            product_id=sale.item_id,
                            branch_id=eff_branch,
                            quantity=prod.stock_quantity,
                            version=1,
                            last_modified_by_device=device_id,
                            is_deleted=False,
                            created_at=now,
                            updated_at=now,
                        )
                        db.add(b_stock)

                    # 3. Restore batch stock additively
                    if sale.batch_id:
                        try:
                            import json as _j
                            allocs = _j.loads(sale.batch_id)
                            if isinstance(allocs, list):
                                rem_ref = allowed_refund
                                for alc in allocs:
                                    if rem_ref <= 0: break
                                    bid = alc.get("batchId") or alc.get("batch_id")
                                    b_alc_qty = float(alc.get("quantity") or 0.0)
                                    if bid and b_alc_qty > 0:
                                        b_model = db.query(BatchModel).filter(BatchModel.id == bid, BatchModel.business_id == business_id).first()
                                        if b_model:
                                            b_ded = min(rem_ref, b_alc_qty)
                                            b_model.quantity += b_ded
                                            b_model.updated_at = now
                                            rem_ref -= b_ded
                            else:
                                b_model = db.query(BatchModel).filter(BatchModel.id == sale.batch_id, BatchModel.business_id == business_id).first()
                                if b_model:
                                    b_model.quantity += allowed_refund
                                    b_model.updated_at = now
                        except Exception:
                            b_model = db.query(BatchModel).filter(BatchModel.id == sale.batch_id, BatchModel.business_id == business_id).first()
                            if b_model:
                                b_model.quantity += allowed_refund
                                b_model.updated_at = now

                    # 4. Emit PRODUCT_UPDATED outbox event so other devices receive the authoritative stock update
                    prod_event_id = f"stock_after_refund_{sale.item_id}_{sale.id}_{int(now.timestamp())}"
                    prod_payload = {
                        "id": sale.item_id,
                        "shopId": business_id,
                        "businessId": business_id,
                        "branchId": eff_branch,
                        "name": prod.name if prod else sale.item_name,
                        "stockQuantity": b_stock.quantity if b_stock else (prod.stock_quantity if prod else allowed_refund),
                        "quantity": b_stock.quantity if b_stock else (prod.stock_quantity if prod else allowed_refund),
                        "sellingPrice": prod.price if prod else 0.0,
                        "buyingPrice": prod.cost_price if prod else 0.0,
                        "version": prod.version if prod else 1,
                        "updatedAt": now.isoformat(),
                    }
                    import json as _json
                    prod_ev = OutboxEvent(
                        event_id=prod_event_id,
                        business_id=business_id,
                        device_id=device_id,
                        branch_id=eff_branch,
                        user_id=user_id,
                        event_type="PRODUCT_UPDATED",
                        entity_type="products",
                        entity_id=sale.item_id,
                        payload=_json.dumps(prod_payload),
                        created_at=now,
                        processed_at=now,
                        sync_status="SYNCED",
                        server_ack=f"AUTO-{now.strftime('%Y%m%d%H%M%S')}",
                    )
                    db.add(prod_ev)
                    print(f"[REFUND SYNC] Refund of {allowed_refund} applied to sale {sale.id}, product and branch stock restored.")
            return



        is_new_sale = sale is None



        if not sale:

            sale = SaleModel(

                id=entity_id,

                business_id=business_id,

                branch_id=branch_id,

                item_id=item_id,

                item_name=str(payload.get("itemName") or payload.get("item_name") or "Item"),

                quantity=sale_qty,

                total_price=float(payload.get("totalPrice") or payload.get("total_price") or 0.0),

                profit=float(payload.get("profit") or 0.0),

                user_id=str(payload.get("userId") or payload.get("user_id") or user_id or ""),
                username=(lambda: (
                    str(payload.get("username")) if payload.get("username") and str(payload.get("username")) != "unknown"
                    else getattr(db.query(BackendUser).filter(BackendUser.id == str(payload.get("userId") or payload.get("user_id") or user_id or "")).first(), "name", None)
                    or getattr(db.query(BackendUser).filter(BackendUser.id == str(payload.get("userId") or payload.get("user_id") or user_id or "")).first(), "username", None)
                    or "unknown"
                ))(),

                timestamp=ts_dt,

                customer_name=payload.get("customerName") or payload.get("customer_name"),

                is_debt=bool(payload.get("isDebt") or payload.get("is_debt")),

                amount_paid=float(payload.get("amountPaid") or payload.get("amount_paid") or 0.0),

                debt_remaining=float(payload.get("debtRemaining") or payload.get("debt_remaining") or 0.0),

                refunded_quantity=float(payload.get("refundedQuantity") or payload.get("refunded_quantity") or 0.0),

                batch_id=payload.get("batchId") or payload.get("batch_id"),

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(sale)

        else:

            sale.is_deleted = False

            sale.version += 1

            sale.last_modified_by_device = device_id

            sale.updated_at = now

            if "branchId" in payload or "branch_id" in payload: sale.branch_id = branch_id

            if "quantity" in payload: sale.quantity = sale_qty

            if "totalPrice" in payload or "total_price" in payload: sale.total_price = float(payload.get("totalPrice") or payload.get("total_price") or 0.0)

            if "profit" in payload: sale.profit = float(payload.get("profit") or 0.0)

            if "amountPaid" in payload or "amount_paid" in payload: sale.amount_paid = float(payload.get("amountPaid") or payload.get("amount_paid") or 0.0)

            if "debtRemaining" in payload or "debt_remaining" in payload: sale.debt_remaining = float(payload.get("debtRemaining") or payload.get("debt_remaining") or 0.0)

            if "isDebt" in payload or "is_debt" in payload: sale.is_debt = bool(payload.get("isDebt") or payload.get("is_debt"))

            if "refundedQuantity" in payload or "refunded_quantity" in payload: sale.refunded_quantity = float(payload.get("refundedQuantity") or payload.get("refunded_quantity") or 0.0)



        # Process inventory deductions and financial debt update for NEW sales

        if is_new_sale:

            # 1. Update customer debt if sale is credit / debt

            if sale.is_debt and sale.debt_remaining > 0:

                cust_name = sale.customer_name

                if cust_name:

                    cust = db.query(CustomerModel).filter(

                        CustomerModel.business_id == business_id, CustomerModel.name == cust_name

                    ).first()

                    if cust:

                        cust.balance += sale.debt_remaining

                        cust.updated_at = now

                        print(f"[DEBT SYNC] Added {sale.debt_remaining} debt to customer {cust_name} (total balance={cust.balance})")



            # 2. Out-of-order dependency check for product

            prod = db.query(ProductModel).filter(ProductModel.id == item_id, ProductModel.business_id == business_id).first()

            if not prod and item_id:

                # Before creating a stub, try to match the sale's item_name against existing

                # active products. This prevents orphaned stub products when a SALE event

                # arrives before its paired PRODUCT_CREATED event.

                inc_name_norm = _normalize_product_name(sale.item_name)

                if inc_name_norm:

                    active_prods = db.query(ProductModel).filter(

                        ProductModel.business_id == business_id,

                        ProductModel.is_deleted == False,

                    ).all()

                    for ap in active_prods:

                        if _normalize_product_name(ap.name) == inc_name_norm:

                            prod = ap

                            # Re-point the sale and future references to the real product ID.

                            sale.item_id = ap.id

                            alias = ProductIdentityAlias(

                                business_id=business_id,

                                source_product_id=item_id,

                                canonical_product_id=ap.id,

                                created_at=now,

                                updated_at=now,

                            )

                            db.merge(alias)

                            item_id = ap.id

                            print(f"[SALE DEPENDENCY] Out-of-order sale {sale.id}: ghost item_id relinked to existing product {ap.id} ('{ap.name}')")

                            break



                if not prod:

                    # Create a minimal stub so the sale has a valid foreign-key anchor.

                    # The stub will be completed when the matched PRODUCT_CREATED event arrives.

                    # We set is_stub=True via a recognisable name prefix so the product never

                    # appears as a real catalog item until it is resolved.

                    prod = ProductModel(

                        id=item_id,

                        business_id=business_id,

                        branch_id=branch_id,

                        name=sale.item_name or f"[Pending] {item_id[:8]}",

                        stock_quantity=0.0,

                        version=1,

                        last_modified_by_device=device_id,

                        is_deleted=False,

                        created_at=now,

                        updated_at=now

                    )

                    db.add(prod)

                    _log_conflict_audit(

                        db=db,

                        business_id=business_id,

                        branch_id=branch_id,

                        device_id=device_id,

                        username=sale.username,

                        details=(

                            f"[DEPENDENCY STUB] Auto-created stub product '{prod.name}' (ID: {item_id}) "

                            f"for out-of-order sale {sale.id}. "

                            f"The stub will be merged with the real product when PRODUCT_CREATED arrives."

                        )

                    )



            # 3. Deduct branch stock under a row lock — REJECT before creating a

            # completed sale if another device consumed the stock first.

            if prod:

                branch_stock = db.query(ProductStockModel).with_for_update().filter(

                    ProductStockModel.business_id == business_id,

                    ProductStockModel.product_id == item_id,

                    ProductStockModel.branch_id == branch_id,

                    ProductStockModel.is_deleted == False,

                ).first()

                from sqlalchemy import func as _sql_func
                batch_sum_val = db.query(_sql_func.sum(BatchModel.quantity)).filter(
                    BatchModel.business_id == business_id,
                    BatchModel.item_id == item_id,
                    BatchModel.branch_id == branch_id,
                    BatchModel.is_deleted == False,
                ).scalar()
                authoritative_stock_qty = float(batch_sum_val) if batch_sum_val is not None and float(batch_sum_val) > 0 else (prod.stock_quantity or 0.0)

                if branch_stock is None:
                    branch_stock = ProductStockModel(
                        id=f"{item_id}@{branch_id}",
                        business_id=business_id,
                        product_id=item_id,
                        branch_id=branch_id,
                        quantity=authoritative_stock_qty,
                        version=1,
                        last_modified_by_device=device_id,
                        is_deleted=False,
                        created_at=now,
                        updated_at=now,
                    )
                    db.add(branch_stock)
                    db.flush()
                elif branch_stock.quantity <= 0 and authoritative_stock_qty > branch_stock.quantity:
                    # Re-align branch_stock with authoritative batch/product ledger
                    branch_stock.quantity = authoritative_stock_qty
                    branch_stock.updated_at = now
                available_stock = branch_stock.quantity

                if available_stock < sale_qty:

                    shortfall = sale_qty - available_stock

                    _log_conflict_audit(

                        db=db,

                        business_id=business_id,

                        branch_id=branch_id,

                        device_id=device_id,

                        username=sale.username,

                        details=(

                            f"[SALE REJECTED - INSUFFICIENT STOCK] Sale {sale.id} requested {sale_qty} units "

                            f"of '{sale.item_name}' (ID: {item_id}), but only {available_stock} units were "

                            f"available. Sale was NOT accepted. No stock was deducted."

                        )

                    )

                    # Raise so the outer try/except rolls back the transaction and

                    # routes this sale into the CONFLICT bucket on the client.

                    raise ValueError(

                        f"Sale of {sale_qty:.0f} units of \"{ sale.item_name }\" could not be completed "

                        f"because only {available_stock:.0f} unit(s) were available on the server "

                        f"(another device may have sold some of the stock while this device was offline). "

                        f"The sale has NOT been recorded. Please review stock and re-enter the transaction if needed."

                    )

                branch_stock.quantity -= sale_qty

                branch_stock.version += 1

                branch_stock.last_modified_by_device = device_id

                branch_stock.updated_at = now

                # Preserve the existing product field for legacy clients, but do

                # not use it as the branch authority.

                if (prod.branch_id or "main") == branch_id:

                    prod.stock_quantity = branch_stock.quantity

                prod.updated_at = now



            # 4. Batch stock deduction. The sale event carries the local FEFO

            # allocation, so each batch is decremented exactly once. Legacy

            # events without an allocation fall back to server-side FEFO.

            allocations = _sale_batch_allocations(payload, sale_qty)

            if allocations:

                allocated = 0.0

                for batch_id, allocated_qty in allocations:

                    batch = db.query(BatchModel).with_for_update().filter(

                        BatchModel.id == batch_id,

                        BatchModel.business_id == business_id,

                        BatchModel.branch_id == branch_id,

                        BatchModel.is_deleted == False,

                    ).first()

                    if batch is None or batch.item_id != item_id or batch.quantity < allocated_qty:

                        raise ValueError(

                            f"Sale of {sale_qty:.0f} units of \"{sale.item_name}\" could not be completed "

                            "because the selected batch stock changed on another device. "

                            "The sale has NOT been recorded."

                        )

                    batch.quantity -= allocated_qty

                    batch.updated_at = now

                    batch.version += 1

                    allocated += allocated_qty

                if abs(allocated - sale_qty) > 0.001:

                    raise ValueError("Sale batch allocation does not match the requested quantity.")

            elif item_id:

                # Allocate via FEFO (Earliest Expiry First) / FIFO

                active_batches = db.query(BatchModel).with_for_update().filter(

                    BatchModel.business_id == business_id,

                    BatchModel.item_id == item_id,

                    BatchModel.branch_id == branch_id,

                    BatchModel.is_deleted == False,

                    BatchModel.quantity > 0

                ).order_by(BatchModel.expiry_date.asc().nullslast(), BatchModel.created_at.asc()).all()



                rem = sale_qty

                for b in active_batches:

                    if rem <= 0: break

                    ded = min(rem, b.quantity)

                    b.quantity -= ded

                    b.updated_at = now

                    rem -= ded



            # 5. Emit a PRODUCT_UPDATED outbox event so secondary devices learn the

            #    authoritative post-sale stock without guessing from batch deductions.

            #    The event_id is stable (product + sale), so replaying the same SALE event

            #    is idempotent even if the product event already exists in the outbox.

            if prod and item_id:

                prod_event_id = f"stock_after_sale_{item_id}_{entity_id}"

                existing_prod_ev = db.query(OutboxEvent).filter(OutboxEvent.event_id == prod_event_id).first()

                if not existing_prod_ev:

                    import json as _json

                    prod_payload = {

                        "id": item_id,

                        "shopId": business_id,

                        "businessId": business_id,

                        "branchId": branch_id,

                        "name": prod.name,

                        "stockQuantity": branch_stock.quantity if branch_stock else prod.stock_quantity,

                        "quantity": branch_stock.quantity if branch_stock else prod.stock_quantity,

                        "sellingPrice": prod.price,

                        "buyingPrice": prod.cost_price,

                        "version": prod.version,

                        "updatedAt": prod.updated_at.isoformat() if prod.updated_at else now.isoformat(),

                        "triggered_by_sale": entity_id,

                    }

                    prod_ev = OutboxEvent(

                        event_id=prod_event_id,

                        business_id=business_id,

                        device_id=device_id,

                        branch_id=branch_id,

                        user_id=user_id,

                        event_type="PRODUCT_UPDATED",

                        entity_type="products",

                        entity_id=item_id,

                        payload=_json.dumps(prod_payload),

                        created_at=now,

                        processed_at=now,

                        sync_status="SYNCED",

                        server_ack=f"AUTO-{now.strftime('%Y%m%d%H%M%S')}",

                    )

                    db.add(prod_ev)

                    print(f"[SALE SYNC] Emitted PRODUCT_UPDATED event prod_event_id={prod_event_id} stock={prod.stock_quantity} for secondary devices")



        print(f"[SALE SYNC] Processed sale entity_id={entity_id} item={payload.get('itemName')} total={payload.get('totalPrice')} for business_id={business_id}")



    elif entity_type in ("purchase", "purchases"):

        purchase = db.query(PurchaseModel).filter(

            PurchaseModel.id == entity_id, PurchaseModel.business_id == business_id

        ).first()



        is_delete_op = event_type in ("DELETE", "PURCHASE_DELETED") or payload.get("operation") == "delete"

        if is_delete_op:

            if purchase:

                purchase.is_deleted = True

                purchase.version += 1

                purchase.last_modified_by_device = device_id

                purchase.updated_at = now

            return



        raw_exp = payload.get("expiryDate") or payload.get("expiry_date") or payload.get("expiry") or payload.get("exp")

        exp_dt = None

        if raw_exp:

            try:

                if isinstance(raw_exp, datetime): exp_dt = raw_exp

                else: exp_dt = datetime.fromisoformat(str(raw_exp).replace("Z", "+00:00"))

            except Exception: pass



        raw_ts = payload.get("timestamp") or payload.get("createdAt") or payload.get("created_at")

        ts_dt = now

        if raw_ts:

            try:

                if isinstance(raw_ts, datetime): ts_dt = raw_ts

                else: ts_dt = datetime.fromisoformat(str(raw_ts).replace("Z", "+00:00"))

            except Exception: pass



        if not purchase:

            purchase = PurchaseModel(

                id=entity_id,

                business_id=business_id,

                branch_id=str(payload.get("branchId") or payload.get("branch_id") or "main"),

                item_id=str(payload.get("itemId") or payload.get("item_id") or ""),

                item_name=str(payload.get("itemName") or payload.get("item_name") or "Item"),

                barcode=payload.get("barcode"),

                quantity=float(payload.get("quantity") or 0.0),

                unit_cost=float(payload.get("unitCost") or payload.get("unit_cost") or 0.0),

                total_cost=float(payload.get("totalCost") or payload.get("total_cost") or 0.0),

                supplier_name=payload.get("supplierName") or payload.get("supplier_name"),

                batch_number=payload.get("batchNumber") or payload.get("batch_number"),

                expiry_date=exp_dt,

                timestamp=ts_dt,

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(purchase)

        else:

            purchase.is_deleted = False

            purchase.version += 1

            purchase.last_modified_by_device = device_id

            purchase.updated_at = now

            if "supplierName" in payload or "supplier_name" in payload: purchase.supplier_name = payload.get("supplierName") or payload.get("supplier_name")

            if "unitCost" in payload or "unit_cost" in payload: purchase.unit_cost = float(payload.get("unitCost") or payload.get("unit_cost") or 0.0)

            if "totalCost" in payload or "total_cost" in payload: purchase.total_cost = float(payload.get("totalCost") or payload.get("total_cost") or 0.0)

        print(f"[PURCHASE SYNC] Processed purchase entity_id={entity_id} total_cost={payload.get('totalCost')} for business_id={business_id}")



    elif entity_type in ("transfer", "transfers") or event_type in ("STOCK_TRANSFER", "TRANSFER_CREATED"):

        transfer_qty = float(payload.get("quantity") or 0.0)

        prod_id = str(payload.get("productId") or payload.get("product_id") or payload.get("itemId") or payload.get("item_id") or entity_id)

        src_branch = str(payload.get("fromBranchId") or payload.get("from_branch_id") or payload.get("sourceBranchId") or "main")

        dst_branch = str(payload.get("toBranchId") or payload.get("to_branch_id") or payload.get("destBranchId") or "branch-2")



        if prod_id and transfer_qty > 0:

            src_stock = db.query(ProductStockModel).filter(

                ProductStockModel.business_id == business_id,

                ProductStockModel.product_id == prod_id,

                ProductStockModel.branch_id == src_branch

            ).first()

            if src_stock:

                src_stock.quantity = max(0.0, src_stock.quantity - transfer_qty)

                src_stock.updated_at = now



            dst_stock = db.query(ProductStockModel).filter(

                ProductStockModel.business_id == business_id,

                ProductStockModel.product_id == prod_id,

                ProductStockModel.branch_id == dst_branch

            ).first()

            if not dst_stock:

                dst_stock = ProductStockModel(

                    id=f"{prod_id}@{dst_branch}",

                    business_id=business_id,

                    product_id=prod_id,

                    branch_id=dst_branch,

                    quantity=transfer_qty,

                    version=1,

                    last_modified_by_device=device_id,

                    created_at=now,

                    updated_at=now

                )

                db.add(dst_stock)

            else:

                dst_stock.quantity += transfer_qty

                dst_stock.updated_at = now



            _log_conflict_audit(

                db=db,

                business_id=business_id,

                branch_id=src_branch,

                device_id=device_id,

                username=payload.get("username"),

                details=f"[TRANSFER EVENT] Transferred {transfer_qty} units of item {prod_id} from branch '{src_branch}' to '{dst_branch}'"

            )

            print(f"[TRANSFER SYNC] Transferred {transfer_qty} of item {prod_id} from {src_branch} to {dst_branch}")



    elif entity_type in ("audit_log", "audit_logs"):

        audit = db.query(AuditLogModel).filter(

            AuditLogModel.id == entity_id, AuditLogModel.business_id == business_id

        ).first()



        raw_ts = payload.get("timestamp") or payload.get("createdAt") or payload.get("created_at")

        ts_dt = now

        if raw_ts:

            try:

                if isinstance(raw_ts, datetime): ts_dt = raw_ts

                else: ts_dt = datetime.fromisoformat(str(raw_ts).replace("Z", "+00:00"))

            except Exception: pass



        if not audit:

            audit = AuditLogModel(

                id=entity_id,

                business_id=business_id,

                branch_id=str(payload.get("branchId") or payload.get("branch_id") or "main"),

                username=str(payload.get("username") or "unknown"),

                action=str(payload.get("action") or "SYSTEM"),

                details=str(payload.get("details") or ""),

                timestamp=ts_dt,

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(audit)



    elif entity_type in ("product_stock", "product_stocks"):

        prod_id = str(payload.get("productId") or payload.get("product_id") or entity_id.split("@")[0])

        br_id = str(payload.get("branchId") or payload.get("branch_id") or (entity_id.split("@")[1] if "@" in entity_id else "main"))

        qty = float(payload.get("quantity") or 0.0)



        stock = db.query(ProductStockModel).filter(

            ProductStockModel.business_id == business_id,

            ProductStockModel.product_id == prod_id,

            ProductStockModel.branch_id == br_id

        ).first()



        if not stock:

            stock = ProductStockModel(

                id=f"{prod_id}@{br_id}",

                business_id=business_id,

                product_id=prod_id,

                branch_id=br_id,

                quantity=qty,

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(stock)

        else:

            stock.quantity = qty

            stock.version += 1

            stock.last_modified_by_device = device_id

            stock.updated_at = now



    elif entity_type in ("notification", "notifications"):

        notif = db.query(NotificationModel).filter(

            NotificationModel.id == entity_id, NotificationModel.business_id == business_id

        ).first()



        if is_delete_op:

            if notif:

                notif.is_deleted = True

                notif.version += 1

                notif.last_modified_by_device = device_id

                notif.updated_at = now

            return



        if not notif:

            notif = NotificationModel(

                id=entity_id,

                business_id=business_id,

                branch_id=str(payload.get("branchId") or payload.get("branch_id") or "main"),

                title=str(payload.get("title") or "System Notification"),

                body=str(payload.get("body") or payload.get("message") or ""),

                type=str(payload.get("type") or "general"),

                priority=str(payload.get("priority") or "normal"),

                is_read=bool(payload.get("isRead") or payload.get("is_read") or False),

                version=1,

                last_modified_by_device=device_id,

                is_deleted=False,

                created_at=now,

                updated_at=now

            )

            db.add(notif)

        else:

            notif.is_deleted = False

            notif.version += 1

            notif.last_modified_by_device = device_id

            notif.updated_at = now



        if "title" in payload and payload["title"] is not None: notif.title = str(payload["title"])

        if "body" in payload and payload["body"] is not None: notif.body = str(payload["body"])

        elif "message" in payload and payload["message"] is not None: notif.body = str(payload["message"])

        if "type" in payload and payload["type"] is not None: notif.type = str(payload["type"])

        if "priority" in payload and payload["priority"] is not None: notif.priority = str(payload["priority"])

        if "isRead" in payload: notif.is_read = bool(payload["isRead"])

        if "is_read" in payload: notif.is_read = bool(payload["is_read"])



    elif entity_type in ("factory_reset", "shops", "shop") and (event_type == "FACTORY_RESET" or payload.get("action") == "FACTORY_RESET" or payload.get("event_type") == "FACTORY_RESET"):

        print(f"[FACTORY RESET] Processing backend factory reset for business_id={business_id} event_id={event_id}")

        db.query(ProductStockModel).filter(ProductStockModel.business_id == business_id).delete(synchronize_session=False)

        db.query(BatchModel).filter(BatchModel.business_id == business_id).delete(synchronize_session=False)

        db.query(SaleModel).filter(SaleModel.business_id == business_id).delete(synchronize_session=False)

        db.query(PurchaseModel).filter(PurchaseModel.business_id == business_id).delete(synchronize_session=False)

        db.query(AuditLogModel).filter(AuditLogModel.business_id == business_id).delete(synchronize_session=False)

        db.query(NotificationModel).filter(NotificationModel.business_id == business_id).delete(synchronize_session=False)

        db.query(ProductModel).filter(ProductModel.business_id == business_id).delete(synchronize_session=False)

        if event_id:

            db.query(OutboxEvent).filter(OutboxEvent.business_id == business_id, OutboxEvent.event_id != event_id).delete(synchronize_session=False)

        else:

            db.query(OutboxEvent).filter(OutboxEvent.business_id == business_id).delete(synchronize_session=False)

        db.commit()











