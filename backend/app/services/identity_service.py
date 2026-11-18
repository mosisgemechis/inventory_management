"""
Identity service: helpers for creating/looking up businesses, users, devices and branches.
"""
from datetime import datetime, timezone
from typing import Optional, Tuple
import uuid

from sqlalchemy.orm import Session

from app.models.identity import BackendBranch, BackendUser, Business, Device
from app.services.auth_service import hash_password


from sqlalchemy import func

def _now():
    return datetime.now(timezone.utc)


# ─── Business ─────────────────────────────────────────────────────────────────

def create_business(
    db: Session,
    name: str,
    email: str,
    plain_password: str,
    phone: Optional[str] = None,
    subscription_plan: str = "free",
    business_id: Optional[str] = None,
) -> Business:
    biz = Business(
        id=business_id or str(uuid.uuid4()),
        name=name,
        email=email.strip().lower(),
        phone=phone,
        password_hash=hash_password(plain_password),
        subscription_plan=subscription_plan,
        created_at=_now(),
    )
    db.add(biz)
    db.flush()  # get id without committing yet
    return biz


def check_email_exists(db: Session, email: str) -> dict:
    """
    Checks if an email or username exists in either businesses or backend_users tables.
    Includes active and inactive records to prevent database UNIQUE constraint crashes.
    """
    clean = email.strip().lower()
    biz = db.query(Business).filter(func.lower(Business.email) == clean).first()
    if biz:
        return {"exists": True, "business_id": biz.id, "is_active": biz.is_active, "type": "business"}

    user = db.query(BackendUser).filter(
        (func.lower(BackendUser.email) == clean) | (func.lower(BackendUser.username) == clean)
    ).first()
    if user:
        return {"exists": True, "business_id": user.business_id, "is_active": user.is_active, "type": "user"}

    return {"exists": False, "business_id": None, "is_active": None, "type": None}


def is_username_taken(db: Session, username: str, exclude_user_id: Optional[str] = None) -> bool:
    """
    Usernames are global identifiers: login resolves a user by username across
    businesses, so two accounts sharing one is ambiguous. Check every user
    (active or not) case-insensitively before creating a new one.
    """
    clean = username.strip().lower()
    if not clean:
        return False
    query = db.query(BackendUser).filter(
        func.lower(BackendUser.username) == clean,
        BackendUser.is_active == True,
    )
    if exclude_user_id:
        query = query.filter(BackendUser.id != exclude_user_id)
    return query.first() is not None


def get_business_by_email(db: Session, email: str, business_id: Optional[str] = None) -> Optional[Business]:
    clean = email.strip().lower()
    if business_id:
        biz = db.query(Business).filter(Business.id == business_id, Business.is_active == True).first()
        if biz:
            return biz
    # First search by exact business email
    biz = db.query(Business).filter(func.lower(Business.email) == clean, Business.is_active == True).first()
    if biz:
        return biz
    # Fallback: search by active user email or username to find business
    user = (
        db.query(BackendUser)
        .filter(
            BackendUser.is_active == True,
            (func.lower(BackendUser.email) == clean) | (func.lower(BackendUser.username) == clean)
        )
        .first()
    )
    if user:
        return db.query(Business).filter(Business.id == user.business_id, Business.is_active == True).first()
    return None


# ─── User ─────────────────────────────────────────────────────────────────────

def create_admin_user(
    db: Session,
    business_id: str,
    name: str,
    email: str,
    plain_password: str,
    user_id: Optional[str] = None,
    username: Optional[str] = None,
) -> BackendUser:
    user = BackendUser(
        id=user_id or str(uuid.uuid4()),
        business_id=business_id,
        name=name,
        email=email.strip().lower(),
        username=(username or email.strip().lower().split("@")[0]).strip().lower(),
        password_hash=hash_password(plain_password),
        role="admin",
        created_at=_now(),
    )
    db.add(user)
    db.flush()
    return user


def get_user_by_email(db: Session, business_id: str, email: str) -> Optional[BackendUser]:
    clean = email.strip().lower()
    return (
        db.query(BackendUser)
        .filter(
            BackendUser.business_id == business_id,
            (func.lower(BackendUser.email) == clean) | (func.lower(BackendUser.username) == clean),
            BackendUser.is_active == True,
        )
        .first()
    )


def get_or_create_oauth_user(
    db: Session,
    provider: str,
    oauth_id: str,
    email: str,
    name: Optional[str] = None,
) -> Tuple[Business, BackendUser]:
    """Finds or registers a user (and default business) via OAuth (Google/Apple)."""
    clean_email = email.strip().lower()
    
    # 1. Search by oauth_provider + oauth_id
    user = (
        db.query(BackendUser)
        .filter(
            BackendUser.oauth_provider == provider,
            BackendUser.oauth_id == oauth_id,
            BackendUser.is_active == True,
        )
        .first()
    )
    if user:
        biz = db.query(Business).filter(Business.id == user.business_id).first()
        return biz, user

    # 2. Search by email
    biz = get_business_by_email(db, clean_email)
    if biz:
        user = get_user_by_email(db, biz.id, clean_email)
        if user:
            # Link existing account
            user.oauth_provider = provider
            user.oauth_id = oauth_id
            db.flush()
            return biz, user

    # 3. Create new business and user if brand new email
    display_name = name.strip() if name and name.strip() else clean_email.split("@")[0]
    biz = create_business(
        db=db,
        name=f"{display_name}'s Shop",
        email=clean_email,
        plain_password=str(uuid.uuid4()),  # OAuth users have no raw password
    )
    create_default_branch(db, biz.id)
    
    user = BackendUser(
        id=str(uuid.uuid4()),
        business_id=biz.id,
        name=display_name,
        username=clean_email.split("@")[0],
        email=clean_email,
        password_hash=None,
        oauth_provider=provider,
        oauth_id=oauth_id,
        role="admin",
        created_at=_now(),
    )
    db.add(user)
    db.flush()
    return biz, user


def update_user_last_login(db: Session, user_id: str) -> None:
    db.query(BackendUser).filter(BackendUser.id == user_id).update(
        {"last_login_at": _now()}
    )


# ─── Device ───────────────────────────────────────────────────────────────────

def register_or_update_device(
    db: Session,
    business_id: str,
    device_uuid: str,
    user_id: Optional[str] = None,
    device_name: Optional[str] = None,
    platform: Optional[str] = None,
) -> Device:
    """Upserts a device record. device_uuid is the stable Flutter-side UUID."""
    existing = db.query(Device).filter(Device.device_uuid == device_uuid).first()
    if existing:
        existing.last_seen_at = _now()
        if user_id:
            existing.user_id = user_id
        if device_name:
            existing.device_name = device_name
        if platform:
            existing.platform = platform
        db.flush()
        return existing

    device = Device(
        id=str(uuid.uuid4()),
        business_id=business_id,
        user_id=user_id,
        device_uuid=device_uuid,
        device_name=device_name,
        platform=platform,
        created_at=_now(),
        last_seen_at=_now(),
    )
    db.add(device)
    db.flush()
    return device


def touch_device(db: Session, device_uuid: str) -> Optional[Device]:
    """Updates last_seen_at timestamp (heartbeat)."""
    device = db.query(Device).filter(Device.device_uuid == device_uuid).first()
    if device:
        device.last_seen_at = _now()
        db.commit()
    return device


# ─── Branch ───────────────────────────────────────────────────────────────────

def create_default_branch(db: Session, business_id: str) -> BackendBranch:
    """Creates the default 'Main Branch' when a business registers."""
    branch = BackendBranch(
        id=str(uuid.uuid4()),
        business_id=business_id,
        name="Main Branch",
        created_at=_now(),
    )
    db.add(branch)
    db.flush()
    return branch


def get_default_branch(db: Session, business_id: str) -> Optional[BackendBranch]:
    return (
        db.query(BackendBranch)
        .filter(BackendBranch.business_id == business_id)
        .first()
    )
