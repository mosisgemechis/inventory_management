import sqlite3

conn = sqlite3.connect("inventory_backend.db")
cols = [c[1] for c in conn.execute("PRAGMA table_info(backend_users)").fetchall()]
rows = conn.execute("SELECT * FROM backend_users").fetchall()
print(f"Total backend_users: {len(rows)}")
for r in rows:
    d = dict(zip(cols, r))
    if d.get('username') == 'kebede' or d.get('username') == 'shemsu' or 'kebede' in str(d.get('email')):
        print(f"MATCH: id={d['id']} username={d.get('username')} email={d.get('email')} is_active={d.get('is_active')}")

conn.close()
