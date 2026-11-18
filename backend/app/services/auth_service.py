"""
Authentication service:
- Password hashing/verification with bcrypt via passlib
- JWT access token creation and verification
- Refresh token creation, lookup, and revocation
"""
from datetime import datetime, timedelta, timezone
from typing import Optional
import uuid

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.config.settings import settings
from app.models.identity import BackendUser, RefreshToken

# ─── Password hashing ─────────────────────────────────────────────────────────

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    if not hashed or not isinstance(hashed, str) or not plain:
        return False
    # 1. Try standard passlib (bcrypt)
    try:
        if _pwd_context.verify(plain, hashed):
            return True
    except Exception:
        pass
    # 2. Try SHA-256 hex string comparison (used by Flutter local storage & outbox sync)
    try:
        import hashlib
        sha256_hash = hashlib.sha256(plain.encode('utf-8')).hexdigest()
        if hashed.strip().lower() == sha256_hash.lower():
            return True
    except Exception:
        pass
    return False


# ─── JWT tokens ───────────────────────────────────────────────────────────────

def create_access_token(user_id: str, business_id: str, role: str, sec_rev: int = 1) -> str:
    now_utc = datetime.now(timezone.utc)
    expire = now_utc + timedelta(
        minutes=settings.JWT_ACCESS_EXPIRE_MINUTES
    )
    payload = {
        "sub": user_id,
        "business_id": business_id,
        "role": role,
        "sec_rev": sec_rev,
        "iat": int(now_utc.timestamp()),
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    """Returns payload dict or None if invalid/expired."""
    print(f"[JWT DEBUG] token present={bool(token)} length={len(token) if token else 0}")
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        t_type = payload.get("type")
        print(f"[JWT DEBUG] signature valid=True token type={t_type}")
        if t_type != "access":
            print(f"[JWT DEBUG] token rejected: invalid type '{t_type}'")
            return None
        print(f"[JWT DEBUG] token expiration valid=True sub={payload.get('sub')} sec_rev={payload.get('sec_rev')}")
        return payload
    except JWTError as e:
        print(f"[JWT DEBUG] signature valid=False or expired: {e}")
        return None


# ─── Refresh tokens ───────────────────────────────────────────────────────────

def create_refresh_token_record(
    db: Session,
    user_id: str,
    device_uuid: Optional[str] = None,
) -> RefreshToken:
    """Creates a new opaque refresh token record in the database."""
    token_value = str(uuid.uuid4())
    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.JWT_REFRESH_EXPIRE_DAYS
    )
    record = RefreshToken(
        user_id=user_id,
        token=token_value,
        expires_at=expires_at,
        device_uuid=device_uuid,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    print(f"[REFRESH DEBUG] Created refresh token for user {user_id}, length={len(token_value)}")
    return record


def validate_refresh_token(db: Session, token: str) -> Optional[RefreshToken]:
    """Returns the RefreshToken row if valid and not expired/revoked."""
    print(f"[REFRESH DEBUG] refresh token present={bool(token)} length={len(token) if token else 0}")
    record = (
        db.query(RefreshToken)
        .filter(RefreshToken.token == token)
        .first()
    )
    if record is None:
        print(f"[REFRESH DEBUG] session found=False session revoked=True refresh accepted=False")
        return None

    is_rev = bool(record.is_revoked)
    print(f"[REFRESH DEBUG] session found=True session revoked={is_rev}")
    if is_rev:
        print(f"[REFRESH DEBUG] refresh accepted=False (token is revoked)")
        return None

    exp = record.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)

    now = datetime.now(timezone.utc)
    is_valid_exp = exp >= now
    print(f"[REFRESH DEBUG] refresh expiry valid={is_valid_exp}")
    if not is_valid_exp:
        print(f"[REFRESH DEBUG] refresh accepted=False (token expired)")
        return None

    print(f"[REFRESH DEBUG] refresh accepted=True user_id={record.user_id}")
    return record


def revoke_refresh_token(db: Session, token: str) -> None:
    """Invalidates a single refresh token (logout)."""
    db.query(RefreshToken).filter(RefreshToken.token == token).update(
        {"is_revoked": True}
    )
    db.commit()


def revoke_all_user_tokens(db: Session, user_id: str) -> None:
    """Invalidates all refresh tokens for a user and bumps security_revision."""
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id,
        RefreshToken.is_revoked == False,
    ).update({"is_revoked": True})

    user = db.query(BackendUser).filter(BackendUser.id == user_id).first()
    if user:
        user.security_revision = (user.security_revision or 1) + 1
        user.password_changed_at = datetime.now(timezone.utc)
    db.commit()


def revoke_all_business_tokens(db: Session, business_id: str, reason: str = "password_change") -> dict:
    """
    Invalidates ALL sessions (access tokens and refresh tokens) for ALL users belonging to business_id.
    Operates authoritatively at the SHOP level across all users and devices.
    """
    users = db.query(BackendUser).filter(BackendUser.business_id == business_id).all()
    user_ids = [u.id for u in users]

    revoked_tokens_count = 0
    if user_ids:
        revoked_tokens_count = db.query(RefreshToken).filter(
            RefreshToken.user_id.in_(user_ids),
            RefreshToken.is_revoked == False
        ).update({"is_revoked": True}, synchronize_session=False)

        for u in users:
            u.security_revision = (u.security_revision or 1) + 1
            u.password_changed_at = datetime.now(timezone.utc)

    db.commit()

    print(f"[SHOP SESSION INVALIDATION]\nbusiness_id={business_id}\nreason={reason}\nsessions_found={revoked_tokens_count}\nsessions_revoked={revoked_tokens_count}")
    print(f"[GLOBAL LOGOUT]\nbusiness_id={business_id}\naffected_users={len(user_ids)}\naffected_sessions={revoked_tokens_count}")

    return {
        "affected_users": len(user_ids),
        "affected_sessions": revoked_tokens_count
    }

