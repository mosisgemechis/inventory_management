"""
Business data models for backend storage and initial sync downloads.
Every entity includes conflict tracking attributes:
 - id
 - updated_at
 - version
 - last_modified_by_device
"""
from datetime import datetime, timezone
import uuid
from sqlalchemy import (
    Column, String, Float, Integer, Text, DateTime, ForeignKey, Boolean, Index,
    UniqueConstraint
)
from app.database.session import Base

def _now():
    return datetime.now(timezone.utc)

def _uuid():
    return str(uuid.uuid4())

class ProductModel(Base):
    __tablename__ = "products"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True, default="main")
    name = Column(String(255), nullable=False)
    sku = Column(String(100), nullable=True)
    barcode = Column(String(100), nullable=True)
    price = Column(Float, default=0.0)
    cost_price = Column(Float, default=0.0)
    stock_quantity = Column(Float, default=0.0)
    category_name = Column(String(100), nullable=True)
    unit = Column(String(50), nullable=True)
    min_stock_threshold = Column(Float, default=0.0)
    expiry_date = Column(DateTime, nullable=True)
    
    # Conflict metadata fields
    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_product_business", "business_id"),
        Index("idx_product_sku", "business_id", "sku"),
        UniqueConstraint("business_id", "barcode", name="uq_product_business_barcode"),
        UniqueConstraint("business_id", "sku", name="uq_product_business_sku"),
    )

class CategoryModel(Base):
    __tablename__ = "categories"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    
    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

class CustomerModel(Base):
    __tablename__ = "customers"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=True)
    email = Column(String(255), nullable=True)
    balance = Column(Float, default=0.0)
    
    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

class SupplierModel(Base):
    __tablename__ = "suppliers"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=True)
    email = Column(String(255), nullable=True)
    
    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

class BatchModel(Base):
    __tablename__ = "batches"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True, default="main")
    item_id = Column(String(64), nullable=False, index=True)
    batch_number = Column(String(100), nullable=True)
    quantity = Column(Float, default=0.0)
    buying_price = Column(Float, default=0.0)
    selling_price = Column(Float, nullable=True)
    expiry_date = Column(DateTime, nullable=True)
    batch_type = Column(String(50), nullable=True)
    
    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_batch_business", "business_id"),
        Index("idx_batch_item", "business_id", "item_id"),
    )

class SaleModel(Base):
    __tablename__ = "sales"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True, default="main")
    item_id = Column(String(64), nullable=False, index=True)
    item_name = Column(String(255), nullable=False)
    quantity = Column(Float, default=0.0)
    total_price = Column(Float, default=0.0)
    profit = Column(Float, default=0.0)
    user_id = Column(String(64), nullable=True)
    username = Column(String(100), nullable=True)
    timestamp = Column(DateTime, default=_now)
    customer_name = Column(String(255), nullable=True)
    is_debt = Column(Boolean, default=False)
    amount_paid = Column(Float, default=0.0)
    debt_remaining = Column(Float, default=0.0)
    refunded_quantity = Column(Float, default=0.0)
    batch_id = Column(String(64), nullable=True)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_sale_business", "business_id"),
        Index("idx_sale_branch", "business_id", "branch_id"),
    )

class PurchaseModel(Base):
    __tablename__ = "purchases"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True, default="main")
    item_id = Column(String(64), nullable=False, index=True)
    item_name = Column(String(255), nullable=False)
    barcode = Column(String(100), nullable=True)
    quantity = Column(Float, default=0.0)
    unit_cost = Column(Float, default=0.0)
    total_cost = Column(Float, default=0.0)
    supplier_name = Column(String(255), nullable=True)
    batch_number = Column(String(100), nullable=True)
    expiry_date = Column(DateTime, nullable=True)
    timestamp = Column(DateTime, default=_now)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_purchase_business", "business_id"),
        Index("idx_purchase_branch", "business_id", "branch_id"),
    )

class AuditLogModel(Base):
    __tablename__ = "audit_logs"

    id = Column(String(64), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True, default="main")
    username = Column(String(100), nullable=False)
    action = Column(String(100), nullable=False)
    details = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=_now)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_audit_business", "business_id"),
    )

class ProductStockModel(Base):
    __tablename__ = "product_stocks"

    id = Column(String(128), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    product_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=False, default="main")
    quantity = Column(Float, default=0.0)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        UniqueConstraint("business_id", "product_id", "branch_id", name="uq_product_stock_business_product_branch"),
    )


class ProductIdentityAlias(Base):
    """Maps a device-local duplicate product ID to the server canonical ID."""
    __tablename__ = "product_identity_aliases"

    business_id = Column(String(64), primary_key=True)
    source_product_id = Column(String(64), primary_key=True)
    canonical_product_id = Column(String(64), nullable=False, index=True)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)


class NotificationModel(Base):
    __tablename__ = "notifications"

    id = Column(String(128), primary_key=True, default=_uuid)
    business_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    type = Column(String(64), nullable=False, default="general")
    priority = Column(String(32), nullable=False, default="normal")
    related_entity_id = Column(String(128), nullable=True)
    created_by = Column(String(128), nullable=True)
    target_role = Column(String(64), nullable=True)
    item_id = Column(String(128), nullable=True)
    is_read = Column(Boolean, default=False)
    timestamp = Column(DateTime, default=_now)
    route = Column(String(255), nullable=True)
    payload_json = Column(Text, nullable=True)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_notifications_biz_branch", "business_id", "branch_id"),
    )


class SettingModel(Base):
    __tablename__ = "app_settings"

    key = Column(String(128), primary_key=True)
    business_id = Column(String(64), primary_key=True, index=True)
    value = Column(Text, nullable=False)

    version = Column(Integer, default=1, nullable=False)
    last_modified_by_device = Column(String(64), nullable=True)
    is_deleted = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now, onupdate=_now)

    __table_args__ = (
        Index("idx_settings_biz_key", "business_id", "key"),
    )






class SubscriptionModel(Base):
    """Per-business subscription/plan state, synced from devices."""
    __tablename__ = "subscriptions"

    business_id = Column(String(64), primary_key=True)
    plan = Column(String(32), nullable=False, default="trial")
    activation_date = Column(DateTime, nullable=True)
    expiry_date = Column(DateTime, nullable=True)
    add_ons = Column(Text, default="[]")
    is_trial = Column(Boolean, default=True)
    user_limit = Column(Integer, default=3)
    branch_limit = Column(Integer, default=1)
    pending_plan = Column(String(32), nullable=True)
    pending_effective_date = Column(DateTime, nullable=True)
    pending_add_ons = Column(Text, nullable=True)
    pending_price = Column(Float, nullable=True)
    last_modified_by_device = Column(String(64), nullable=True)
    updated_at = Column(DateTime, default=_now, onupdate=_now)
