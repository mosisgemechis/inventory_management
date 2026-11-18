import sqlite3
import os

db_path = os.path.join(os.path.dirname(__file__), 'inventory_backend.db')
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    tables = [row[0] for row in cursor.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
    counts = {}
    for t in tables:
        if not t.startswith('sqlite_'):
            cnt = cursor.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            counts[t] = cnt
    print("Backend DB table row counts:", counts)
    conn.close()
else:
    print("Database file not found at", db_path)
