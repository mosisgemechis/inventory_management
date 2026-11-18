from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

class SyncEventItem(BaseModel):
    id: str = Field(..., description="Unique event ID")
    business_id: Optional[str] = Field(None, alias="shopId")
    device_id: Optional[str] = Field(None, alias="deviceId")
    user_id: Optional[str] = Field(None, alias="userId")
    branch_id: Optional[str] = Field("main", alias="branchId")
    event_type: Optional[str] = Field(None, alias="eventType")
    entity_type: Optional[str] = Field(None, alias="entityType")
    entity_id: Optional[str] = Field(None, alias="entityId")
    payload: Optional[Dict[str, Any]] = None
    timestamp: Optional[str] = Field(None, alias="createdAt")

    class Config:
        allow_population_by_field_name = True
        populate_by_name = True

class SyncEventsRequest(BaseModel):
    shopId: Optional[str] = None
    deviceId: Optional[str] = None
    events: List[SyncEventItem]

class SyncEventsResponse(BaseModel):
    status: str = "success"
    synced: List[str]
    ackedEventIds: List[str] = []
    rejectedEvents: List[Dict[str, Any]] = []
    identityResolutions: List[Dict[str, str]] = []
    message: str = "Events processed successfully."

class InitialSyncResponse(BaseModel):
    products: List[Dict[str, Any]] = []
    batches: List[Dict[str, Any]] = []
    categories: List[Dict[str, Any]] = []
    customers: List[Dict[str, Any]] = []
    suppliers: List[Dict[str, Any]] = []
    settings: List[Dict[str, Any]] = []
    users: List[Dict[str, Any]] = []
    branches: List[Dict[str, Any]] = []
    sales: List[Dict[str, Any]] = []
    purchases: List[Dict[str, Any]] = []
    auditLogs: List[Dict[str, Any]] = []
    productStocks: List[Dict[str, Any]] = []
    notifications: List[Dict[str, Any]] = []



