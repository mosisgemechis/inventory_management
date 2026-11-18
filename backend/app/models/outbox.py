from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, String, Integer, Text, DateTime, Index, UniqueConstraint
from app.database.session import Base

class OutboxEvent(Base):
    __tablename__ = "outbox_events"

    id = Column(String(64), primary_key=True, default=lambda: str(uuid.uuid4()))
    event_id = Column(String(64), nullable=False, index=True)
    business_id = Column(String(64), nullable=False, index=True)
    device_id = Column(String(64), nullable=False, index=True)
    branch_id = Column(String(64), nullable=True)
    user_id = Column(String(64), nullable=True)
    
    event_type = Column(String(32), nullable=False, index=True)  # SALE, PURCHASE, REFUND, TRANSFER, ADJUSTMENT
    entity_type = Column(String(32), nullable=False, index=True)
    entity_id = Column(String(64), nullable=False, index=True)
    
    payload = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    processed_at = Column(DateTime, nullable=True)
    
    sync_status = Column(String(20), default="PENDING", index=True)  # PENDING, UPLOADING, SYNCED, FAILED
    retry_count = Column(Integer, default=0)
    last_error = Column(Text, nullable=True)
    server_ack = Column(Text, nullable=True)
    canonical_entity_id = Column(String(64), nullable=True)

    __table_args__ = (
        UniqueConstraint("event_id", name="uq_outbox_event_id"),
        Index("idx_outbox_business_status", "business_id", "sync_status"),
        Index("idx_outbox_event_type", "event_type"),
    )
