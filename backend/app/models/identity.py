"""
Identity models: Business, BackendUser, Device, RefreshToken, Branch.
These are the backend-side identity tables for the GM Inventory Everywhere sync system.
The Flutter client stores corresponding IDs in its app_settings key/value table.
"""
from datetime import datetime, timezone
import uuid
from sqlalchemy import (
    Column, String, Integer, Text, DateTime, ForeignKey, Boolean, Index
)
from app.database.session import Base


def _now():
    return datetime.now(timezone.utc)


def _uuid():
    return str(uuid.uuid4())


class Business(Base):
    __tablename__ = "businesses"

    id = Column(String(64), primary_key=True, default=_uuid)
    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=False, unique=True, index=True)
    phone = Column(String(50), nullable=True)
    password_hash = Column(String(255), nullable=False)  # Admin owner password
    subscription_plan = Column(String(50), nullable=False, default="free")
    currency = Column(String(10), nullable=True, default="USD")
    business_type = Column(String(50), nullable=True)
    country = Column(String(100), nullable=True)
    onboarding_completed = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=_now, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    __table_args__ = (
        Index("idx_business_email", "email"),
    )


class BackendUser(Base):
    """
    Backend representation of a user within a business.
    Separate from the Flutter-side Drift 'users' table which is offline-first.
    Sync between Drift users and this table is done via the Outbox.
    """
    __tablename__ = "backend_users"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), ForeignKey("businesses.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    username = Column(String(255), nullable=True, index=True)
    email = Column(String(255), nullable=False, index=True)
    password_hash = Column(String(255), nullable=True)
    oauth_provider = Column(String(50), nullable=True)  # google | apple
    oauth_id = Column(String(255), nullable=True, index=True)
    role = Column(String(50), nullable=False, default="staff")  # admin | manager | staff | cashier
    branch_id = Column(String(64), nullable=True, default="main")
    permissions = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    security_revision = Column(Integer, default=1, nullable=False)
    password_changed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_now, nullable=False)
    updated_at = Column(DateTime, default=_now, onupdate=_now, nullable=False)
    last_login_at = Column(DateTime, nullable=True)
    recovery_email = Column(String(255), nullable=True)
    recovery_email_verified = Column(Boolean, default=False, nullable=False)
    recovery_token_hash = Column(String(128), nullable=True)
    recovery_token_expires_at = Column(DateTime, nullable=True)
    password_set_at = Column(DateTime, nullable=True)
    deletion_token_hash = Column(String(128), nullable=True)
    deletion_token_expires_at = Column(DateTime, nullable=True)

    __table_args__ = (
        Index("idx_user_business_email", "business_id", "email"),
        Index("idx_user_oauth", "oauth_provider", "oauth_id"),
    )


class Device(Base):
    """
    Registered device per business. device_uuid is the stable UUID generated
    by the Flutter DeviceIdService and stored in SharedPreferences.
    """
    __tablename__ = "devices"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), ForeignKey("businesses.id"), nullable=False, index=True)
    user_id = Column(String(64), ForeignKey("backend_users.id"), nullable=True)  # null until first login
    device_uuid = Column(String(64), nullable=False, unique=True, index=True)
    device_name = Column(String(255), nullable=True)
    platform = Column(String(50), nullable=True)  # windows | android | ios | web
    created_at = Column(DateTime, default=_now, nullable=False)
    last_seen_at = Column(DateTime, default=_now, nullable=False)

    __table_args__ = (
        Index("idx_device_uuid", "device_uuid"),
        Index("idx_device_business", "business_id"),
    )


class RefreshToken(Base):
    """
    Stored refresh tokens. Invalidated on logout or token rotation.
    """
    __tablename__ = "refresh_tokens"

    id = Column(String(64), primary_key=True, default=_uuid)
    user_id = Column(String(64), ForeignKey("backend_users.id"), nullable=False, index=True)
    token = Column(String(512), nullable=False, unique=True, index=True)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=_now, nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    device_uuid = Column(String(64), nullable=True)  # ties token to device for audit

    __table_args__ = (
        Index("idx_refresh_token_user", "user_id", "is_revoked"),
    )


class BackendBranch(Base):
    """
    Backend branch records. Mirrored from Flutter via Outbox on creation.
    """
    __tablename__ = "branches"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), ForeignKey("businesses.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=_now, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    __table_args__ = (
        Index("idx_branch_business", "business_id"),
    )
