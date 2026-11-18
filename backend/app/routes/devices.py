"""
Device routes:
  POST /devices/register   → Register or update a device record
  POST /devices/heartbeat  → Update last_seen_at (called on app resume)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.schemas.auth import DeviceHeartbeatRequest, DeviceRegisterRequest, DeviceInfo
from app.services import identity_service

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post("/register", response_model=DeviceInfo, status_code=status.HTTP_200_OK)
def register_device(payload: DeviceRegisterRequest, db: Session = Depends(get_db)):
    """Called after login to ensure the device is registered with the backend."""
    device = identity_service.register_or_update_device(
        db,
        business_id=payload.business_id,
        device_uuid=payload.device_uuid,
        user_id=payload.user_id,
        device_name=payload.device_name,
        platform=payload.platform,
    )
    db.commit()
    return DeviceInfo(
        id=device.id,
        device_uuid=device.device_uuid,
        device_name=device.device_name,
        platform=device.platform,
    )


@router.post("/heartbeat", status_code=status.HTTP_204_NO_CONTENT)
def device_heartbeat(payload: DeviceHeartbeatRequest, db: Session = Depends(get_db)):
    """Touch last_seen_at. Called on app resume or periodic sync tick."""
    identity_service.touch_device(db, payload.device_uuid)
