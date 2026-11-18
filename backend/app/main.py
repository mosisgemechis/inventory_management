import os
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config.settings import settings
from app.database.session import engine, Base


class _SafeStream:
    """Keeps print()/logging from crashing requests when the console pipe that
    started the server has been closed (Windows raises WinError 233)."""

    def __init__(self, stream):
        self._stream = stream

    def write(self, data):
        try:
            return self._stream.write(data)
        except (OSError, ValueError):
            return len(data)

    def flush(self):
        try:
            self._stream.flush()
        except (OSError, ValueError):
            pass

    def __getattr__(self, name):
        return getattr(self._stream, name)


for _name in ("stdout", "stderr"):
    _stream = getattr(sys, _name, None)
    if _stream is not None and not isinstance(_stream, _SafeStream):
        setattr(sys, _name, _SafeStream(_stream))

# Import ALL models so SQLAlchemy creates their tables on startup
from app.models import outbox       # noqa: F401
from app.models import identity     # noqa: F401
from app.models import business_data # noqa: F401

from app.routes import sync, auth, devices

# Create all database tables automatically (idempotent)
Base.metadata.create_all(bind=engine)

# ── Idempotent column migrations ─────────────────────────────────────────────
# Add new columns to backend_users if they don't exist yet.
# Safe to run on every startup — uses IF NOT EXISTS guard via exception handling.
def _run_migrations():
    with engine.connect() as conn:
        migrations = [
            ("backend_users", "branch_id", "VARCHAR(64) DEFAULT 'main'"),
            ("backend_users", "permissions", "TEXT"),
            ("backend_users", "security_revision", "INTEGER DEFAULT 1"),
            ("backend_users", "password_changed_at", "DATETIME"),
            ("backend_users", "username", "VARCHAR(255)"),
            ("backend_users", "updated_at", "DATETIME"),
            ("backend_users", "oauth_provider", "VARCHAR(50)"),
            ("backend_users", "oauth_id", "VARCHAR(255)"),
            ("branches", "is_active", "BOOLEAN DEFAULT 1"),
            ("outbox_events", "canonical_entity_id", "VARCHAR(64)"),
            # Added: currency column for the Business table (backfill for existing DBs)
            ("businesses", "currency", "VARCHAR(10) DEFAULT 'USD'"),
            ("businesses", "business_type", "VARCHAR(50)"),
            ("businesses", "country", "VARCHAR(100)"),
            ("businesses", "onboarding_completed", "BOOLEAN DEFAULT 1"),
            ("backend_users", "recovery_email", "VARCHAR(255)"),
            ("backend_users", "recovery_email_verified", "BOOLEAN DEFAULT 0"),
            ("backend_users", "recovery_token_hash", "VARCHAR(128)"),
            ("backend_users", "recovery_token_expires_at", "DATETIME"),
            ("backend_users", "password_set_at", "DATETIME"),
            ("backend_users", "deletion_token_hash", "VARCHAR(128)"),
            ("backend_users", "deletion_token_expires_at", "DATETIME"),
            ("subscriptions", "pending_plan", "VARCHAR(32)"),
            ("subscriptions", "pending_effective_date", "DATETIME"),
            ("subscriptions", "pending_add_ons", "TEXT"),
            ("subscriptions", "pending_price", "FLOAT"),
        ]
        for table, col, col_type in migrations:
            try:
                conn.execute(__import__("sqlalchemy").text(f"ALTER TABLE {table} ADD COLUMN {col} {col_type}"))
                conn.commit()
                print(f"[MIGRATE] Ensured column {table}.{col}")
            except Exception:
                conn.rollback()  # Column already exists or table not created yet

_run_migrations()

def _run_sync_integrity_migrations():
    """Add the sync safety indexes for existing deployments without data loss."""
    with engine.connect() as conn:
        statements = [
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_outbox_event_id ON outbox_events (event_id)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_product_stock_business_product_branch ON product_stocks (business_id, product_id, branch_id)",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_product_business_barcode ON products (business_id, barcode) WHERE barcode IS NOT NULL AND barcode <> ''",
            "CREATE UNIQUE INDEX IF NOT EXISTS uq_product_business_sku ON products (business_id, sku) WHERE sku IS NOT NULL AND sku <> ''",
        ]
        for statement in statements:
            try:
                conn.execute(__import__("sqlalchemy").text(statement))
                conn.commit()
            except Exception:
                conn.rollback()

_run_sync_integrity_migrations()

print(f"[AUTH CONFIG] JWT secret configured={bool(settings.JWT_SECRET)}")
print(f"[AUTH CONFIG] JWT algorithm={settings.JWT_ALGORITHM}")
print(f"[AUTH CONFIG] Auth database configured=True")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend Sync & Identity API for GM Inventory Everywhere",
    version="2.0.0",
)

# Browser origins allowed to call the API. Mobile clients do not send an
# Origin header, so this only affects web builds.
_cors_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "").split(",")
    if origin.strip()
]
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

app.include_router(auth.router)
app.include_router(devices.router)
app.include_router(sync.router)


@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "environment": settings.ENVIRONMENT,
        "version": "2.0.0",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
