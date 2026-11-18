from typing import List, Tuple, Dict, Any
from sqlalchemy.orm import Session
from app.schemas.sync import SyncUploadRequest
from app.sync.processor import process_sync_batch

def process_upload_events(db: Session, request: SyncUploadRequest) -> Tuple[List[str], List[Dict[str, Any]]]:
    """
    Delegates processing of client uploaded outbox events to the sync processor.
    """
    return process_sync_batch(db, request)
