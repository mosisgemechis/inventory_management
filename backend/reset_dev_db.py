import sys
import os
from sqlalchemy import text

# Ensure backend package can be imported
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database.session import engine, SessionLocal
from app.config.settings import settings

def reset_development_data():
    """
    SAFE DEVELOPMENT RESET
    Clears all development test business data from backend tables.
    Preserves table structures, schemas, and migrations.
    """
    if settings.ENVIRONMENT.lower() == "production":
        print("[RESET SAFETY ERROR] Cannot reset data in production environment!")
        sys.exit(1)

    print("[RESET] Starting safe development database reset...")
    db = SessionLocal()
    try:
        tables = [
            "refresh_tokens",
            "devices",
            "sync_outbox",
            "products",
            "categories",
            "customers",
            "suppliers",
            "batches",
            "sales",
            "purchases",
            "transfers",
            "refunds",
            "branches",
            "backend_users",
            "businesses",
        ]
        
        # Turn off foreign key constraints during deletion for SQLite
        if settings.DATABASE_URL.startswith("sqlite"):
            db.execute(text("PRAGMA foreign_keys = OFF;"))
        
        for table in tables:
            try:
                result = db.execute(text(f"DELETE FROM {table};"))
                print(f"[RESET] Cleared table: {table} (rows deleted: {result.rowcount})")
            except Exception as e:
                print(f"[RESET] Table {table} warning: {e}")
        
        if settings.DATABASE_URL.startswith("sqlite"):
            db.execute(text("PRAGMA foreign_keys = ON;"))

        db.commit()
        print("[RESET SUCCESS] Development database reset complete. State is now 0 users, 0 businesses.")
    except Exception as err:
        db.rollback()
        print(f"[RESET ERROR] Failed to reset database: {err}")
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    reset_development_data()
