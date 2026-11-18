"""
Update the bcrypt password hash for a backend_users record.

Usage:
  python update_password.py shemsu <new_password>
"""
import sys
import sqlite3
from datetime import datetime, timezone
from passlib.context import CryptContext

DB_PATH = "inventory_backend.db"
_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

if len(sys.argv) < 3:
    print("Usage: python update_password.py <username_or_email> <new_password>")
    sys.exit(1)

identifier = sys.argv[1]
plain = sys.argv[2]
hashed = _pwd.hash(plain)
now = datetime.now(timezone.utc).isoformat()

conn = sqlite3.connect(DB_PATH)
cursor = conn.execute(
    "UPDATE backend_users SET password_hash=?, updated_at=? WHERE username=? OR email=?",
    (hashed, now, identifier, identifier)
)
conn.commit()
print(f"[UPDATE] Rows updated: {cursor.rowcount}")
conn.close()
