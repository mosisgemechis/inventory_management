"""
One-time migration script for GM Inventory backend SQLite DB:
1. Adds any missing columns to backend_users (oauth_provider, oauth_id, username, updated_at).
2. Adds is_active column to branches if missing.
3. Ensures 'shemsu' exists as a cloud user in the backend.

Run from: c:\projects\inventory_management\backend
  python migrate_and_seed.py

To update shemsu's password after seeding:
  python update_password.py shemsu <actual_password>
"""
import sqlite3
import uuid
from datetime import datetime, timezone
from passlib.context import CryptContext

DB_PATH = "inventory_backend.db"
_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _now():
    return datetime.now(timezone.utc).isoformat()


def add_col_if_missing(conn, table, col, col_def):
    cols = [c[1] for c in conn.execute(f"PRAGMA table_info({table})").fetchall()]
    if col not in cols:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {col} {col_def}")
        print(f"[MIGRATE] Added column: {table}.{col}")
    else:
        print(f"[MIGRATE] Column already exists: {table}.{col}")


def migrate(conn):
    now = _now()
    add_col_if_missing(conn, "backend_users", "username",  "TEXT")
    add_col_if_missing(conn, "backend_users", "updated_at", f"TEXT DEFAULT '{now}'")
    add_col_if_missing(conn, "backend_users", "oauth_provider", "TEXT")
    add_col_if_missing(conn, "backend_users", "oauth_id", "TEXT")
    add_col_if_missing(conn, "backend_users", "branch_id", "TEXT DEFAULT 'main'")
    add_col_if_missing(conn, "backend_users", "permissions", "TEXT")
    add_col_if_missing(conn, "backend_users", "security_revision", "INTEGER DEFAULT 1")
    add_col_if_missing(conn, "backend_users", "password_changed_at", "TEXT")
    add_col_if_missing(conn, "branches", "is_active", "INTEGER DEFAULT 1")
    conn.commit()
    print("[MIGRATE] Done.")


def seed_shemsu(conn):
    """Ensure 'shemsu' user exists linked to first business."""
    biz = conn.execute("SELECT id, name, email FROM businesses LIMIT 1").fetchone()
    if not biz:
        print("[SEED] ERROR: No business found. Register first via POST /auth/register.")
        return

    biz_id, biz_name, biz_email = biz
    print(f"[SEED] Using business: id={biz_id}  name={biz_name}  email={biz_email}")

    # Check by username first, then by email prefix
    cols = [c[1] for c in conn.execute("PRAGMA table_info(backend_users)").fetchall()]
    existing = None
    if "username" in cols:
        existing = conn.execute(
            "SELECT id, name, email, username FROM backend_users WHERE username='shemsu' LIMIT 1"
        ).fetchone()
    if not existing:
        existing = conn.execute(
            "SELECT id, name, email FROM backend_users WHERE email LIKE 'shemsu@%' LIMIT 1"
        ).fetchone()

    if existing:
        print(f"[SEED] 'shemsu' already exists: {existing}")
        return

    # Default test password matches what the desktop user likely set.
    # IMPORTANT: If the actual password differs, run: python update_password.py shemsu <actual_password>
    plain_password = "shemsu"
    hashed = _pwd.hash(plain_password)
    uid = str(uuid.uuid4())
    now = _now()
    domain = biz_email.split('@')[-1] if '@' in biz_email else 'synctest.com'
    email = f"shemsu@{domain}"

    conn.execute(
        """INSERT INTO backend_users
           (id, business_id, name, username, email, password_hash,
            oauth_provider, oauth_id, role, is_active, created_at, updated_at, last_login_at)
           VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, 'admin', 1, ?, ?, NULL)""",
        (uid, biz_id, "Shemsu", "shemsu", email, hashed, now, now),
    )
    conn.commit()
    print(f"[SEED] Created user: id={uid}")
    print(f"[SEED]   username = shemsu")
    print(f"[SEED]   email    = {email}")
    print(f"[SEED]   password = {plain_password}  (test default — update if needed)")


def list_users(conn):
    cols = [c[1] for c in conn.execute("PRAGMA table_info(backend_users)").fetchall()]
    rows = conn.execute("SELECT * FROM backend_users").fetchall()
    print(f"\n[INFO] backend_users columns: {cols}")
    for r in rows:
        d = dict(zip(cols, r))
        # Never print full hash
        if "password_hash" in d and d["password_hash"]:
            d["password_hash"] = d["password_hash"][:20] + "..."
        print(f"  USER: {d}")


if __name__ == "__main__":
    conn = sqlite3.connect(DB_PATH)
    print("=== MIGRATE ===")
    migrate(conn)
    print("\n=== SEED 'shemsu' ===")
    seed_shemsu(conn)
    print("\n=== CURRENT USERS ===")
    list_users(conn)
    conn.close()
    print("\nDone.")
