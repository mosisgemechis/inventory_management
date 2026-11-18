"""
Auth routes:
  POST /auth/register → Register a business + admin user + first device
  POST /auth/login    → Login, returns JWT access + opaque refresh token
  POST /auth/google   → Google OAuth authentication
  POST /auth/apple    → Apple OAuth authentication
  POST /auth/refresh  → Rotate access token using refresh token
  POST /auth/logout   → Revoke refresh token
"""
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
import hashlib
import re
import secrets
import time
import uuid
from datetime import datetime, timedelta, timezone

from app.database.session import get_db
from app.models.identity import BackendUser, Business
from app.schemas.auth import (
    BusinessRegisterRequest, BusinessRegisterResponse,
    LoginRequest, LoginResponse, OAuthGoogleRequest, OAuthAppleRequest,
    UserIdentity, BusinessInfo, DeviceInfo,
    LogoutRequest, ChangePasswordRequest,
    TokenRefreshRequest, TokenRefreshResponse,
    CompleteProfileRequest,
    SetPasswordRequest, SecurityMethodsResponse,
    RecoveryEmailRequest, RecoveryEmailVerifyRequest,
    RecoveryRequest, RecoveryConfirmRequest,
    DeletionVerifyRequest, DeletionConfirmRequest, UsernameUpdateRequest,
    TransferOwnerRequest, CreateAdminRequest,
)
from app.services import auth_service, email_service, google_token, identity_service
from app.services.google_token import GoogleTokenError, verify_google_id_token
from app.config.settings import settings

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.get("/check-email")
def check_email(email: str, db: Session = Depends(get_db)):
    """
    Check if a business or user account with this email already exists on the backend.
    Checks ALL businesses and backend_users regardless of active status.
    Returns: {"exists": True/False, "business_id": str|None, "is_active": bool|None, "type": str|None}
    """
    clean_email = email.strip().lower()
    result = identity_service.check_email_exists(db, clean_email)
    print(f"[AUTH TRACE] email={clean_email} lookup_started=true lookup_status=200 lookup_response={result} account_found={result['exists']}")
    return result


# ─── Register ─────────────────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=BusinessRegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_business(payload: BusinessRegisterRequest, db: Session = Depends(get_db)):
    """
    Register a new business, create the admin user, first device, and default branch.
    Returns the identity IDs the Flutter client should persist locally.
    """
    clean_email = payload.email.strip().lower()
    if _rate_limited(f"register:{clean_email}"):
        raise HTTPException(
            status_code=429,
            detail="Too many registration attempts. Please try again later.",
        )
    op_id = str(uuid.uuid4())
    print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nemail={clean_email}\nbusiness_id={payload.business_id}\nuser_id={payload.user_id}\nstage=REGISTRATION_STARTED")

    _release_inactive_business_email(db, clean_email)
    check_res = identity_service.check_email_exists(db, clean_email)
    if check_res["exists"]:
        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=REGISTRATION_CONFLICT\nreason=email_exists")
        print(f"[AUTH CLOUD REGISTER DEBUG] Registration conflict: email {clean_email} already exists.")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A business with this email already exists.",
        )

    # Usernames are global (login accepts a username), so a taken one must be
    # rejected before the business/user rows are created.
    requested_username = (payload.username or "").strip().lower() or clean_email.split("@")[0]
    if identity_service.is_username_taken(db, requested_username):
        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=REGISTRATION_CONFLICT\nreason=username_exists username={requested_username}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken. Please choose another.",
        )

    try:
        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=BUSINESS_INSERT_STARTED")
        biz = identity_service.create_business(
            db,
            name=payload.business_name,
            email=clean_email,
            plain_password=payload.password,
            phone=payload.phone,
            subscription_plan=payload.subscription_plan,
            business_id=payload.business_id,
        )

        user = identity_service.create_admin_user(
            db,
            business_id=biz.id,
            name=payload.full_name or payload.business_name,
            email=clean_email,
            plain_password=payload.password,
            user_id=payload.user_id,
            username=payload.username,
        )

        device = identity_service.register_or_update_device(
            db,
            business_id=biz.id,
            device_uuid=payload.device_uuid,
            user_id=user.id,
            device_name=payload.device_name,
            platform=payload.platform,
        )

        branch = identity_service.create_default_branch(db, biz.id)
        db.commit()

        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=BUSINESS_INSERT_COMMITTED\nstage=REGISTRATION_COMPLETED")
        print(f"[AUTH CLOUD REGISTER DEBUG] Registration succeeded: business_id={biz.id} user_id={user.id} device_id={device.id} branch_id={branch.id}")

        return BusinessRegisterResponse(
            business_id=biz.id,
            user_id=user.id,
            device_id=device.id,
            branch_id=branch.id,
        )

    except IntegrityError as ie:
        db.rollback()
        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=REGISTRATION_CONFLICT\nreason=integrity_error_{str(ie)}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A business with this email already exists.",
        )
    except Exception as e:
        db.rollback()
        print(f"[REGISTRATION TRACE]\noperation_id={op_id}\nstage=REGISTRATION_FAILED\nreason={str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}",
        )


def _release_inactive_business_email(db: Session, email: str) -> None:
    """Frees an email still held by a deactivated business record."""
    if not email:
        return
    stale = db.query(Business).filter(Business.email == email).all()
    for biz in stale:
        if not getattr(biz, "is_active", True):
            biz.email = f"deleted+{biz.id}@deleted.local"
    if stale:
        db.flush()


# ─── Login ────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate user credentials.
    Returns JWT access token + opaque refresh token + full identity payload
    for the Flutter client to persist locally.
    """
    clean_identifier = payload.email.strip().lower()
    if _rate_limited(f"login:{clean_identifier}"):
        raise HTTPException(
            status_code=429,
            detail="Too many sign-in attempts. Please try again in a few minutes.",
        )
    print(f"[STAFF LOGIN TRACE]\nusername={clean_identifier}\nbusiness_context={payload.business_id or 'auto'}\nbackend_reachable=true\nstage=LOGIN_REQUEST")

    biz = identity_service.get_business_by_email(db, clean_identifier, business_id=payload.business_id)
    
    print(f"[AUTH CLOUD DEBUG] identifier = {clean_identifier}")
    print(f"[AUTH CLOUD DEBUG] business found = {biz is not None} (id={biz.id if biz else 'none'})")

    if biz is None or not getattr(biz, 'is_active', True):
        print(f"[STAFF LOGIN TRACE]\nstage=BUSINESS_NOT_FOUND_OR_INACTIVE")
        print(f"[AUTH CLOUD DEBUG] Login rejected: business is deactivated or deleted (biz={biz.id if biz else 'none'})")
        raise HTTPException(status_code=401, detail="Business or shop account is deactivated or deleted.")

    print(f"[STAFF LOGIN TRACE]\nstage=BUSINESS_FOUND\nbusiness_id={biz.id}")
    user = identity_service.get_user_by_email(db, biz.id, clean_identifier)
    user_found = user is not None
    password_hash_exists = bool(user and user.password_hash)
    
    hash_str = (user.password_hash or "") if user else ""
    hash_scheme = "none"
    hash_valid_format = False
    if hash_str:
        if hash_str.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):
            hash_scheme = "bcrypt"
            hash_valid_format = True
        elif len(hash_str) == 64 and all(c in "0123456789abcdefABCDEF" for c in hash_str):
            hash_scheme = "sha256_drift"
            hash_valid_format = False
        else:
            hash_scheme = "unknown"
            hash_valid_format = False

    print("[AUTH HASH DEBUG]")
    print(f"user_id={user.id if user else 'none'}")
    print(f"credential_exists={user_found}")
    print(f"hash_present={password_hash_exists}")
    print(f"hash_scheme_detected={hash_scheme}")
    print(f"hash_valid_format={str(hash_valid_format).lower()}")

    password_verification = bool(user and auth_service.verify_password(payload.password, user.password_hash or ""))

    print(f"[AUTH CLOUD DEBUG] user found = {user_found}")
    print(f"[AUTH CLOUD DEBUG] user id = {user.id if user else 'none'}")
    print(f"[AUTH CLOUD DEBUG] business id = {biz.id}")
    print(f"[AUTH CLOUD DEBUG] is active = {user.is_active if user else False}")
    print(f"[AUTH CLOUD DEBUG] password hash exists = {password_hash_exists}")
    print(f"[AUTH CLOUD DEBUG] password verification = {password_verification}")

    if user is not None and not (user.password_hash or "").strip() and user.oauth_provider:
        raise HTTPException(
            status_code=401,
            detail="This account uses Google sign-in. Choose Continue with Google.",
        )

    if user is not None and not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="This account has been deactivated and can no longer sign in.",
        )

    if user is None or not password_verification:
        print(f"[STAFF LOGIN TRACE]\nstage=LOGIN_FAILURE\nreason=invalid_credentials_or_inactive")
        print(f"[AUTH CLOUD DEBUG] Login rejected: user not found, deactivated, or invalid password")
        raise HTTPException(status_code=401, detail="Invalid email or password, or user account is deactivated.")

    print(f"[STAFF LOGIN TRACE]\nstage=USER_FOUND\nuser_id={user.id}")
    print(f"[STAFF LOGIN TRACE]\nstage=USER_ACTIVE\nactive=true")
    print(f"[STAFF LOGIN TRACE]\nstage=CREDENTIAL_FOUND\ncredential_exists=true")
    print(f"[STAFF LOGIN TRACE]\nstage=PASSWORD_VALID\nvalid=true")

    # Auto-upgrade SHA-256 / legacy hashes to bcrypt upon successful authentication
    if not user.password_hash or not user.password_hash.startswith(("$2a$", "$2b$", "$2y$", "$2x$")):
        new_bcrypt = auth_service.hash_password(payload.password)
        user.password_hash = new_bcrypt
        if user.role == "admin" and biz:
            biz.password_hash = new_bcrypt
        print(f"[SECURITY] Auto-upgraded user {user.id} password hash to bcrypt")

    device = identity_service.register_or_update_device(
        db,
        business_id=biz.id,
        device_uuid=payload.device_uuid,
        user_id=user.id,
        device_name=payload.device_name,
        platform=payload.platform,
    )

    sec_rev = user.security_revision or 1
    access_token = auth_service.create_access_token(user.id, biz.id, user.role, sec_rev=sec_rev)
    refresh_record = auth_service.create_refresh_token_record(
        db, user_id=user.id, device_uuid=payload.device_uuid
    )

    print(f"[STAFF LOGIN TRACE]\nstage=SESSION_CREATED\nstage=JWT_CREATED\nstage=LOGIN_SUCCESS")
    print(f"[STAFF IDENTITY TRACE]\nlogin_user_id={user.id}\nbackend_user_id={user.id}\ncredential_user_id={user.id}")
    print(f"[STAFF BUSINESS TRACE]\nlogin_business_id={biz.id}\nbackend_business_id={biz.id}")

    identity_service.update_user_last_login(db, user.id)
    db.commit()

    username_str = user.username or (user.email.split('@')[0] if user.email else user.name)

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_record.token,
        user=UserIdentity(
            id=user.id,
            business_id=biz.id,
            name=user.name,
            username=username_str,
            email=user.email,
            role=user.role,
            branch_id=user.branch_id or "main",
            permissions=user.permissions,
            oauth_provider=user.oauth_provider,
            oauth_id=user.oauth_id,
        ),
        business=BusinessInfo(
            id=biz.id,
            name=biz.name,
            email=biz.email,
            subscription_plan=biz.subscription_plan,
        ),
        device=DeviceInfo(
            id=device.id,
            device_uuid=device.device_uuid,
            device_name=device.device_name,
            platform=device.platform,
        ),
    )


# ─── OAuth Google ─────────────────────────────────────────────────────────────

@router.post("/google", response_model=LoginResponse)
def login_google(payload: OAuthGoogleRequest, db: Session = Depends(get_db)):
    if _rate_limited("google-login:global"):
        raise HTTPException(
            status_code=429,
            detail="Too many sign-in attempts. Please try again in a few minutes.",
        )
    """Authenticate via Google OAuth.

    The ID token is verified against Google's signing keys; the client-provided
    email/name/google_id are never trusted. New identities get an *incomplete*
    account and must finish onboarding before using the app.
    """
    configured_audiences = ",".join(
        [settings.GOOGLE_CLIENT_IDS, settings.GOOGLE_CLIENT_ID]
    )
    audiences = [c.strip() for c in configured_audiences.split(",") if c.strip()]
    if not audiences:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google sign-in is not configured on the server.",
        )

    try:
        claims = verify_google_id_token(payload.id_token, audiences)
    except GoogleTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc))

    email = str(claims.get("email", "")).strip().lower()
    google_id = str(claims.get("sub", ""))
    display_name = (claims.get("name") or payload.name or email.split("@")[0]).strip()

    try:
        user = (
            db.query(BackendUser)
            .filter(
                BackendUser.oauth_provider == "google",
                BackendUser.oauth_id == google_id,
                BackendUser.is_active == True,
            )
            .first()
        )

        if user is None:
            # Never silently link or duplicate an existing password account.
            existing_biz = identity_service.get_business_by_email(db, email)
            existing_user = (
                identity_service.get_user_by_email(db, existing_biz.id, email)
                if existing_biz
                else None
            )
            if existing_user is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=(
                        "An account with this email already exists. Sign in with your "
                        "password, then connect Google from Account Security."
                    ),
                )

            _release_inactive_business_email(db, email)

            # Create an incomplete account: no password, no guessed business name.
            biz = identity_service.create_business(
                db,
                name="",
                email=email,
                plain_password=str(uuid.uuid4()),
            )
            biz.onboarding_completed = False
            identity_service.create_default_branch(db, biz.id)

            user = BackendUser(
                id=str(uuid.uuid4()),
                business_id=biz.id,
                name=display_name,
                username=f"{email.split('@')[0]}-{uuid.uuid4().hex[:6]}",
                email=email,
                password_hash=None,
                oauth_provider="google",
                oauth_id=google_id,
                role="admin",
                created_at=datetime.now(timezone.utc),
            )
            db.add(user)
            db.flush()
        else:
            biz = db.query(Business).filter(Business.id == user.business_id).first()

        if biz is None or not getattr(biz, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="This business account is deactivated or deleted.",
            )
        if not getattr(user, "is_active", True):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="This user account is suspended or disabled.",
            )

        device = identity_service.register_or_update_device(
            db,
            business_id=biz.id,
            device_uuid=payload.device_uuid,
            user_id=user.id,
            device_name=payload.device_name,
            platform=payload.platform,
        )

        access_token = auth_service.create_access_token(user.id, biz.id, user.role)
        refresh_record = auth_service.create_refresh_token_record(
            db, user_id=user.id, device_uuid=payload.device_uuid
        )
        identity_service.update_user_last_login(db, user.id)
        db.commit()

        onboarding_completed = bool(getattr(biz, "onboarding_completed", True))
        username_str = user.username or (user.email.split("@")[0] if user.email else user.name)

        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_record.token,
            is_new_account=not onboarding_completed,
            onboarding_completed=onboarding_completed,
            user=UserIdentity(
                id=user.id,
                business_id=biz.id,
                name=user.name,
                username=username_str,
                email=user.email,
                role=user.role,
                oauth_provider="google",
                oauth_id=google_id,
            ),
            business=BusinessInfo(
                id=biz.id,
                name=biz.name,
                email=biz.email,
                subscription_plan=biz.subscription_plan,
                currency=biz.currency,
                country=getattr(biz, "country", None),
                business_type=getattr(biz, "business_type", None),
                onboarding_completed=onboarding_completed,
            ),
            device=DeviceInfo(
                id=device.id,
                device_uuid=device.device_uuid,
                device_name=device.device_name,
                platform=device.platform,
            ),
        )
    except HTTPException:
        db.rollback()
        raise
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email already belongs to an account. Sign in with your "
            "password or use a different Google account.",
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google sign-in could not be completed. Please try again.",
        )


@router.post("/complete-profile", response_model=BusinessInfo)
def complete_profile(
    payload: CompleteProfileRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Completes onboarding for an account created through Google sign-in."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header is required.",
        )
    claims = auth_service.decode_access_token(authorization.split(" ")[1])
    if not claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your session expired. Please sign in again.",
        )

    user = db.query(BackendUser).filter(BackendUser.id == claims.get("sub")).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found.",
        )

    biz = db.query(Business).filter(Business.id == user.business_id).first()
    if biz is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found.",
        )

    biz.name = payload.business_name.strip()
    biz.business_type = payload.business_type.strip()
    biz.currency = payload.currency.strip().upper()[:10]
    biz.country = payload.country.strip()
    biz.onboarding_completed = True
    if payload.display_name and payload.display_name.strip():
        user.name = payload.display_name.strip()
    db.commit()

    return BusinessInfo(
        id=biz.id,
        name=biz.name,
        email=biz.email,
        subscription_plan=biz.subscription_plan,
        currency=biz.currency,
        country=biz.country,
        business_type=biz.business_type,
        onboarding_completed=True,
    )


# ─── OAuth Apple ──────────────────────────────────────────────────────────────

@router.post("/apple", response_model=LoginResponse)
def login_apple(payload: OAuthAppleRequest, db: Session = Depends(get_db)):
    """Authenticate via Apple OAuth."""
    try:
        biz, user = identity_service.get_or_create_oauth_user(
            db=db,
            provider="apple",
            oauth_id=payload.apple_id,
            email=payload.email,
            name=payload.name,
        )

        device = identity_service.register_or_update_device(
            db,
            business_id=biz.id,
            device_uuid=payload.device_uuid,
            user_id=user.id,
            device_name=payload.device_name,
            platform=payload.platform,
        )

        access_token = auth_service.create_access_token(user.id, biz.id, user.role)
        refresh_record = auth_service.create_refresh_token_record(
            db, user_id=user.id, device_uuid=payload.device_uuid
        )

        identity_service.update_user_last_login(db, user.id)
        db.commit()

        username_str = user.username or (user.email.split('@')[0] if user.email else user.name)

        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_record.token,
            user=UserIdentity(
                id=user.id,
                business_id=biz.id,
                name=user.name,
                username=username_str,
                email=user.email,
                role=user.role,
                oauth_provider="apple",
                oauth_id=payload.apple_id,
            ),
            business=BusinessInfo(
                id=biz.id,
                name=biz.name,
                email=biz.email,
                subscription_plan=biz.subscription_plan,
            ),
            device=DeviceInfo(
                id=device.id,
                device_uuid=device.device_uuid,
                device_name=device.device_name,
                platform=device.platform,
            ),
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Apple OAuth authentication failed: {str(e)}",
        )


# ─── Refresh Token ────────────────────────────────────────────────────────────

@router.post("/refresh", response_model=TokenRefreshResponse)
def refresh_access_token(payload: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Exchange a valid refresh token for a new access token."""
    record = auth_service.validate_refresh_token(db, payload.refresh_token)
    if record is None:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token.")

    user = db.query(BackendUser).filter_by(id=record.user_id).first()
    if user is None or not user.is_active:
        raise HTTPException(status_code=401, detail="User account not found or inactive.")

    from app.models.identity import Business
    biz = db.query(Business).filter_by(id=user.business_id).first()
    if biz is None or not biz.is_active:
        raise HTTPException(status_code=401, detail="Business or shop account is deactivated or deleted.")

    sec_rev = user.security_revision or 1
    new_access = auth_service.create_access_token(user.id, user.business_id, user.role, sec_rev=sec_rev)
    return TokenRefreshResponse(access_token=new_access)


# ─── Logout ───────────────────────────────────────────────────────────────────

@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: LogoutRequest, db: Session = Depends(get_db)):
    """Invalidates the supplied refresh token."""
    auth_service.revoke_refresh_token(db, payload.refresh_token)


# ─── Change Password ─────────────────────────────────────────────────────────

@router.post("/change-password", status_code=status.HTTP_200_OK)
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None)
):
    """Securely updates user password in cloud PostgreSQL database."""
    print("[SECURITY] Password change requested")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header is required."
        )
    token = authorization.split(" ")[1]
    claims = auth_service.decode_access_token(token)
    if not claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token."
        )

    user_id = claims.get("sub")
    user = db.query(BackendUser).filter(BackendUser.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found."
        )

    if user.password_hash and not auth_service.verify_password(payload.old_password, user.password_hash):
        print("[SECURITY] Current password verification result=false")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect."
        )

    print("[SECURITY] Current password verification result=true")
    new_hash = auth_service.hash_password(payload.new_password)
    user.password_hash = new_hash
    user.updated_at = datetime.now(timezone.utc)
    user.password_changed_at = datetime.now(timezone.utc)

    if user.role == "admin":
        from app.models.identity import Business
        biz = db.query(Business).filter(Business.id == user.business_id).first()
        if biz:
            biz.password_hash = new_hash

    # Invalidate ALL active sessions for the entire SHOP (all users, all devices)
    auth_service.revoke_all_business_tokens(db, user.business_id, reason="password_change")

    print(f"[PASSWORD CHANGE]\nbusiness_id={user.business_id}\nuser_id={user.id}\npassword_change_success=true\nshop_sessions_invalidated=true")
    print("[SECURITY] Password updated")
    print("[SECURITY] Security revision changed")
    print("[SECURITY] All sessions invalidated")
    print("[SECURITY] Initiating session invalidated")
    return {"message": "Password changed successfully."}


# ─── Account security: additional login & recovery email ─────────────────────

# Small in-memory rate limiter (per process) for recovery-related requests.
_security_attempts: dict[str, list[float]] = {}
_RATE_WINDOW = 3600
_RATE_LIMIT = 5


def _rate_limited(key: str) -> bool:
    now = time.time()
    attempts = [t for t in _security_attempts.get(key, []) if now - t < _RATE_WINDOW]
    if len(attempts) >= _RATE_LIMIT:
        _security_attempts[key] = attempts
        return True
    attempts.append(now)
    _security_attempts[key] = attempts
    return False


def _current_user(db: Session, authorization: Optional[str]) -> BackendUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Please sign in again.")
    claims = auth_service.decode_access_token(authorization.split(" ")[1])
    if not claims:
        raise HTTPException(status_code=401, detail="Your session expired. Please sign in again.")
    user = db.query(BackendUser).filter(BackendUser.id == claims.get("sub")).first()
    if user is None or not user.is_active:
        raise HTTPException(status_code=404, detail="Account not found.")
    return user


def _password_error(password: str) -> Optional[str]:
    if len(password) < 8:
        return "Password must be at least 8 characters long."
    if not re.search(r"[A-Z]", password):
        return "Password must contain an uppercase letter."
    if not re.search(r"[0-9]", password):
        return "Password must contain a number."
    if not re.search(r"[^A-Za-z0-9]", password):
        return "Password must contain a special character."
    return None


def _hash_token(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _security_payload(user: BackendUser) -> SecurityMethodsResponse:
    return SecurityMethodsResponse(
        google_connected=bool(user.oauth_provider),
        google_email=user.email if user.oauth_provider else None,
        account_email=user.email,
        username=user.username,
        password_configured=bool((user.password_hash or "").strip()),
        recovery_email=user.recovery_email,
        recovery_email_verified=bool(user.recovery_email_verified),
    )


@router.get("/security/methods", response_model=SecurityMethodsResponse)
def security_methods(
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user = _current_user(db, authorization)
    return _security_payload(user)


@router.post("/security/password", response_model=SecurityMethodsResponse)
def set_password(
    payload: SetPasswordRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Adds an optional GM Inventory Everywhere username/password to the account.

    Google sign-in stays enabled; this only adds another login method.
    """
    user = _current_user(db, authorization)

    username = payload.username.strip().lower()
    if not re.fullmatch(r"[a-z0-9._-]{3,64}", username):
        raise HTTPException(
            status_code=400,
            detail="Username may use letters, numbers, dot, dash and underscore (3-64 characters).",
        )
    if identity_service.is_username_taken(db, username, exclude_user_id=user.id):
        raise HTTPException(status_code=409, detail="This username is already taken.")
    if _rate_limited(f"set-password:{user.id}") and not (user.password_hash or "").strip():
        raise HTTPException(status_code=429, detail="Too many attempts. Please try again later.")

    error = _password_error(payload.password)
    if error:
        raise HTTPException(status_code=400, detail=error)

    user.username = username
    user.password_hash = auth_service.hash_password(payload.password)
    user.password_set_at = datetime.now(timezone.utc)
    user.security_revision = (user.security_revision or 1) + 1
    db.commit()
    return _security_payload(user)


@router.post("/security/recovery-email")
def set_recovery_email(
    payload: RecoveryEmailRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Stores an unverified recovery email and creates a short-lived code.

    Email delivery is not configured in this deployment, so the code is returned
    only outside production to allow manual verification.
    """
    user = _current_user(db, authorization)
    email = payload.email.strip().lower()
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=400, detail="Enter a valid email address.")
    if email == (user.email or "").strip().lower():
        raise HTTPException(
            status_code=400,
            detail="Use a different address from your Google login email.",
        )
    taken = (
        db.query(BackendUser)
        .filter(
            BackendUser.recovery_email == email,
            BackendUser.recovery_email_verified == True,
            BackendUser.id != user.id,
        )
        .first()
    )
    if taken is not None:
        raise HTTPException(
            status_code=409, detail="This recovery email is already in use."
        )
    if _rate_limited(f"recovery-email:{user.id}"):
        raise HTTPException(status_code=429, detail="Too many requests. Please try again later.")

    code = f"{secrets.randbelow(1000000):06d}"
    user.recovery_email = email
    user.recovery_email_verified = False
    user.recovery_token_hash = _hash_token(f"{user.id}:{code}")
    user.recovery_token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
    db.commit()

    delivered = email_service.send_verification_code(email, code)
    # The code is only ever delivered by email; it is never returned by the API.
    return {
        "sent": True,
        "email": email,
        "delivered": delivered,
        "reason": "domain_not_verified"
        if not delivered and email_service.last_delivery_blocked_by_test_mode()
        else None,
    }


@router.post("/security/recovery-email/verify", response_model=SecurityMethodsResponse)
def verify_recovery_email(
    payload: RecoveryEmailVerifyRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user = _current_user(db, authorization)
    code_hash = _hash_token(f"{user.id}:{payload.code.strip()}")
    expires = user.recovery_token_expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if (
        not user.recovery_token_hash
        or user.recovery_token_hash != code_hash
        or expires is None
        or expires < datetime.now(timezone.utc)
    ):
        if _rate_limited(f"verify-recovery:{user.id}"):
            raise HTTPException(status_code=429, detail="Too many attempts. Please try again later.")
        raise HTTPException(
            status_code=400, detail="That code is invalid or has expired. Request a new one."
        )

    user.recovery_email_verified = True
    user.recovery_token_hash = None
    user.recovery_token_expires_at = None
    db.commit()
    return _security_payload(user)


@router.post("/recovery/request")
def request_recovery(payload: RecoveryRequest, db: Session = Depends(get_db)):
    """Issues a single-use reset token when a verified recovery email exists."""
    identifier = payload.identifier.strip().lower()
    if _rate_limited(f"recovery-request:{identifier}"):
        raise HTTPException(status_code=429, detail="Too many requests. Please try again later.")

    user = (
        db.query(BackendUser)
        .filter(
            (BackendUser.email == identifier)
            | (BackendUser.recovery_email == identifier)
            | (BackendUser.username == identifier)
        )
        .filter(BackendUser.is_active == True)
        .first()
    )

    response = {
        "accepted": True,
        "message": "If this account has a verified recovery email, a reset code is on its way.",
    }
    if user is not None:
        target = (
            user.recovery_email
            if user.recovery_email_verified and user.recovery_email
            else (user.email or "").strip()
        )
        if target:
            token = f"{secrets.randbelow(10**8):08d}"
            user.recovery_token_hash = _hash_token(token)
            user.recovery_token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
            db.commit()
            response["delivered"] = email_service.send_recovery_token(target, token)
            if not response["delivered"] and email_service.last_delivery_blocked_by_test_mode():
                response["reason"] = "domain_not_verified"
    return response


@router.post("/recovery/confirm")
def confirm_recovery(payload: RecoveryConfirmRequest, db: Session = Depends(get_db)):
    """Sets a new GM Inventory Everywhere password using a single-use recovery token."""
    token_hash = _hash_token(payload.token)
    user = (
        db.query(BackendUser)
        .filter(BackendUser.recovery_token_hash == token_hash)
        .first()
    )
    expires = user.recovery_token_expires_at if user else None
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if (
        user is None
        or not user.is_active
        or expires is None
        or expires < datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=400, detail="That reset code is invalid or has expired. Request a new one."
        )

    error = _password_error(payload.new_password)
    if error:
        raise HTTPException(status_code=400, detail=error)

    user.password_hash = auth_service.hash_password(payload.new_password)
    user.password_set_at = datetime.now(timezone.utc)
    user.security_revision = (user.security_revision or 1) + 1
    user.recovery_token_hash = None
    user.recovery_token_expires_at = None
    auth_service.revoke_all_business_tokens(db, user.business_id, reason="recovery")
    db.commit()
    return {"recovered": True, "message": "Your password was updated. Please sign in."}


# ─── Delete account ──────────────────────────────────────────────────────────

@router.post("/account/delete/verify")
def verify_account_deletion(
    payload: DeletionVerifyRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Proves the caller still controls the account, without deleting anything."""
    user = _current_user(db, authorization)
    if _rate_limited(f"delete-verify:{user.id}"):
        raise HTTPException(status_code=429, detail="Too many attempts. Please try again later.")

    has_password = bool((user.password_hash or "").strip())

    if payload.google_id_token:
        if not user.oauth_provider:
            raise HTTPException(status_code=400, detail="This account is not linked to Google.")
        try:
            audiences = [
                c for c in (settings.GOOGLE_CLIENT_IDS or "").split(",") if c.strip()
            ]
            if settings.GOOGLE_CLIENT_ID:
                audiences.append(settings.GOOGLE_CLIENT_ID)
            claims = google_token.verify_google_id_token(
                payload.google_id_token, audiences
            )
        except google_token.GoogleTokenError:
            raise HTTPException(status_code=401, detail="Google verification failed. Please try again.")
        if not user.oauth_id or claims.get("sub") != user.oauth_id:
            raise HTTPException(status_code=401, detail="That Google account does not match this account.")
    elif payload.password:
        if not has_password or not auth_service.verify_password(payload.password, user.password_hash or ""):
            raise HTTPException(status_code=400, detail="The password is incorrect.")
    else:
        raise HTTPException(status_code=400, detail="Verify with Google or your password.")

    token = secrets.token_urlsafe(24)
    user.deletion_token_hash = _hash_token(token)
    user.deletion_token_expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
    db.commit()
    return {"deletion_token": token, "expires_in": 600}


@router.post("/account/delete")
def delete_account(
    payload: DeletionConfirmRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Deactivates the account after explicit confirmation. Business data is kept."""
    user = _current_user(db, authorization)

    if payload.confirmation.strip().upper() != "DELETE":
        raise HTTPException(status_code=400, detail="Type DELETE to confirm.")

    token_hash = _hash_token(payload.deletion_token.strip())
    expires = user.deletion_token_expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if (
        not user.deletion_token_hash
        or user.deletion_token_hash != token_hash
        or expires is None
        or expires < datetime.now(timezone.utc)
    ):
        raise HTTPException(status_code=400, detail="Your verification expired. Verify again.")

    others = (
        db.query(BackendUser)
        .filter(
            BackendUser.business_id == user.business_id,
            BackendUser.id != user.id,
            BackendUser.is_active == True,
        )
        .count()
    )
    if (user.role or "").lower() in ("admin", "owner") and others > 0:
        raise HTTPException(
            status_code=409,
            detail="You are the business owner. Transfer ownership to another member, "
            "or remove the other members, before deleting your account.",
        )

    # Free the identifiers: a permanent deletion means the person can sign up
    # again as a brand-new account with the same Google/email/username.
    user.email = f"deleted+{user.id}@deleted.local"
    user.username = f"deleted-{user.id}"
    user.oauth_id = None
    user.is_active = False
    user.deletion_token_hash = None
    user.deletion_token_expires_at = None
    user.security_revision = (user.security_revision or 1) + 1
    remaining = (
        db.query(BackendUser)
        .filter(
            BackendUser.business_id == user.business_id,
            BackendUser.id != user.id,
            BackendUser.is_active == True,
        )
        .count()
    )
    if remaining == 0:
        biz = db.query(Business).filter(Business.id == user.business_id).first()
        if biz is not None:
            biz.is_active = False
            if (biz.email or "").strip().lower() != "":
                biz.email = f"deleted+{biz.id}@deleted.local"
    auth_service.revoke_all_business_tokens(db, user.business_id, reason="account_deleted")
    db.commit()
    return {"deleted": True, "message": "Your account has been deactivated."}


@router.post("/security/username", response_model=SecurityMethodsResponse)
def update_username(
    payload: UsernameUpdateRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Lets the signed-in user change their username (password field unused)."""
    user = _current_user(db, authorization)
    username = payload.username.strip().lower()
    if not re.fullmatch(r"[a-z0-9._-]{3,64}", username):
        raise HTTPException(
            status_code=400,
            detail="Username may use letters, numbers, dot, dash and underscore (3-64 characters).",
        )
    if identity_service.is_username_taken(db, username, exclude_user_id=user.id):
        raise HTTPException(status_code=409, detail="This username is already taken.")
    user.username = username
    db.commit()
    return _security_payload(user)


@router.post("/business/delete")
def delete_business(
    payload: DeletionConfirmRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Deletes the shop for everyone: every member account is deactivated."""
    user = _current_user(db, authorization)
    if (user.role or "").lower() not in ("admin", "owner"):
        raise HTTPException(status_code=403, detail="Only an admin can delete the shop.")
    if payload.confirmation.strip().upper() != "DELETE":
        raise HTTPException(status_code=400, detail="Confirmation is required.")

    expires = user.deletion_token_expires_at
    if expires is not None and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if (
        not user.deletion_token_hash
        or user.deletion_token_hash != _hash_token(payload.deletion_token.strip())
        or expires is None
        or expires < datetime.now(timezone.utc)
    ):
        raise HTTPException(status_code=400, detail="Your verification expired. Verify again.")

    users = (
        db.query(BackendUser)
        .filter(BackendUser.business_id == user.business_id)
        .all()
    )
    for member in users:
        member.email = f"deleted+{member.id}@deleted.local"
        member.username = f"deleted-{member.id}"
        member.oauth_id = None
        member.is_active = False
        member.deletion_token_hash = None
        member.deletion_token_expires_at = None
    biz = db.query(Business).filter(Business.id == user.business_id).first()
    if biz is not None:
        biz.is_active = False
        biz.email = f"deleted+{biz.id}@deleted.local"
    auth_service.revoke_all_business_tokens(db, user.business_id, reason="business_deleted")
    db.commit()
    return {"deleted": True, "members": len(users)}


@router.get("/business/members")
def business_members(
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user = _current_user(db, authorization)
    if (user.role or "").lower() not in ("admin", "owner"):
        raise HTTPException(status_code=403, detail="Only an admin can see members.")
    members = (
        db.query(BackendUser)
        .filter(
            BackendUser.business_id == user.business_id,
            BackendUser.is_active == True,
            BackendUser.id != user.id,
        )
        .all()
    )
    return {
        "members": [
            {
                "id": m.id,
                "name": m.name,
                "username": m.username,
                "email": m.email,
                "role": m.role,
            }
            for m in members
        ]
    }


@router.post("/business/transfer-owner")
def transfer_owner(
    payload: TransferOwnerRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Makes another member the owner so the current admin can delete their account."""
    user = _current_user(db, authorization)
    if (user.role or "").lower() not in ("admin", "owner"):
        raise HTTPException(status_code=403, detail="Only an admin can transfer ownership.")
    target = (
        db.query(BackendUser)
        .filter(
            BackendUser.id == payload.new_owner_id,
            BackendUser.business_id == user.business_id,
            BackendUser.is_active == True,
        )
        .first()
    )
    if target is None or target.id == user.id:
        raise HTTPException(status_code=400, detail="Choose an active member of this shop.")
    target.role = "admin"
    user.role = "staff"
    db.commit()
    return {"transferred": True, "new_owner": target.username}


@router.post("/business/create-admin")
def create_admin(
    payload: CreateAdminRequest,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    """Creates another admin in the same shop (no new business)."""
    user = _current_user(db, authorization)
    if (user.role or "").lower() not in ("admin", "owner"):
        raise HTTPException(status_code=403, detail="Only an admin can add an admin.")

    username = payload.username.strip().lower()
    email = (payload.email or "").strip().lower()
    if not re.fullmatch(r"[a-z0-9._-]{3,64}", username):
        raise HTTPException(status_code=400, detail="Username may use letters, numbers, dot and underscore.")
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=400, detail="Enter a valid email address.")
    if identity_service.is_username_taken(db, username):
        raise HTTPException(status_code=409, detail="This username is already taken.")
    if identity_service.check_email_exists(db, email).get("exists"):
        raise HTTPException(status_code=409, detail="This email is already in use.")
    error = _password_error(payload.password)
    if error:
        raise HTTPException(status_code=400, detail=error)

    admin = BackendUser(
        id=str(uuid.uuid4()),
        business_id=user.business_id,
        name=payload.name.strip(),
        username=username,
        email=email,
        password_hash=auth_service.hash_password(payload.password),
        role="admin",
        is_active=True,
        created_at=datetime.now(timezone.utc),
    )
    db.add(admin)
    db.commit()
    return {"id": admin.id, "username": admin.username, "role": "admin"}
