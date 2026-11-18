from typing import Any, Dict, List, Optional
from pydantic import BaseModel, EmailStr, Field


# ─── Business Registration ────────────────────────────────────────────────────

class BusinessRegisterRequest(BaseModel):
    business_name: str = Field(..., min_length=2, max_length=255)
    email: str = Field(..., description="Admin owner email")
    password: str = Field(..., min_length=8, description="Admin owner password")
    phone: Optional[str] = None
    subscription_plan: str = "free"
    business_id: Optional[str] = None
    user_id: Optional[str] = None
    username: Optional[str] = None
    full_name: Optional[str] = None

    # Device identifies the first device registering this business
    device_uuid: str = Field(..., description="Stable device UUID from DeviceIdService")
    device_name: Optional[str] = None
    platform: Optional[str] = None  # windows | android | ios | web


class BusinessRegisterResponse(BaseModel):
    business_id: str
    user_id: str
    device_id: str
    branch_id: str
    message: str = "Business registered successfully."


# ─── Auth Login ───────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email: str
    password: str
    device_uuid: str = Field(..., description="Stable device UUID from DeviceIdService")
    device_name: Optional[str] = None
    platform: Optional[str] = None
    business_id: Optional[str] = None


class OAuthGoogleRequest(BaseModel):
    id_token: str = Field(..., description="Google OAuth ID Token or Access Token")
    email: str
    name: Optional[str] = None
    google_id: str
    device_uuid: str
    device_name: Optional[str] = None
    platform: Optional[str] = None


class OAuthAppleRequest(BaseModel):
    id_token: str = Field(..., description="Apple OAuth ID Token")
    email: str
    name: Optional[str] = None
    apple_id: str
    device_uuid: str
    device_name: Optional[str] = None
    platform: Optional[str] = None


class UserIdentity(BaseModel):
    id: str
    business_id: str
    name: str
    username: str
    email: str
    role: str
    branch_id: Optional[str] = "main"
    permissions: Optional[Any] = None
    oauth_provider: Optional[str] = None
    oauth_id: Optional[str] = None


class BusinessInfo(BaseModel):
    id: str
    name: str
    email: str
    subscription_plan: str
    currency: Optional[str] = None
    country: Optional[str] = None
    business_type: Optional[str] = None
    onboarding_completed: bool = True


class DeviceInfo(BaseModel):
    id: str
    device_uuid: str
    device_name: Optional[str]
    platform: Optional[str]


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserIdentity
    business: BusinessInfo
    device: DeviceInfo
    is_new_account: bool = False
    onboarding_completed: bool = True


class CompleteProfileRequest(BaseModel):
    business_name: str = Field(..., min_length=2, max_length=255)
    business_type: str = Field(..., min_length=2, max_length=50)
    currency: str = Field(..., min_length=2, max_length=10)
    country: str = Field(..., min_length=2, max_length=100)
    display_name: Optional[str] = Field(None, max_length=255)


# ─── Token Refresh ────────────────────────────────────────────────────────────

class TokenRefreshRequest(BaseModel):
    refresh_token: str
    device_uuid: Optional[str] = None


class TokenRefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ─── Logout ───────────────────────────────────────────────────────────────────

class LogoutRequest(BaseModel):
    refresh_token: str


# ─── Device Registration ──────────────────────────────────────────────────────

class DeviceRegisterRequest(BaseModel):
    business_id: str
    user_id: str
    device_uuid: str
    device_name: Optional[str] = None
    platform: Optional[str] = None


class DeviceHeartbeatRequest(BaseModel):
    device_uuid: str


# ─── Password Change ──────────────────────────────────────────────────────────

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8)



class SetPasswordRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=8, max_length=128)


class SecurityMethodsResponse(BaseModel):
    google_connected: bool
    google_email: Optional[str] = None
    account_email: Optional[str] = None
    username: Optional[str] = None
    password_configured: bool = False
    recovery_email: Optional[str] = None
    recovery_email_verified: bool = False


class RecoveryEmailRequest(BaseModel):
    email: str


class RecoveryEmailVerifyRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6)


class RecoveryRequest(BaseModel):
    identifier: str


class RecoveryConfirmRequest(BaseModel):
    token: str
    new_password: str = Field(..., min_length=8, max_length=128)


class DeletionVerifyRequest(BaseModel):
    password: Optional[str] = None
    google_id_token: Optional[str] = None


class DeletionConfirmRequest(BaseModel):
    deletion_token: str
    confirmation: str


class UsernameUpdateRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)


class TransferOwnerRequest(BaseModel):
    new_owner_id: str


class CreateAdminRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    username: str = Field(..., min_length=3, max_length=64)
    email: str
    password: str
