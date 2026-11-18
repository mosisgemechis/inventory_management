import os
import sqlite3

def reset_flutter_client_db():
    docs_path = os.path.expanduser("~/Documents")
    db_file = os.path.join(docs_path, "inventory_db.sqlite")
    print(f"[FLUTTER RESET] Checking for local Flutter database at: {db_file}")
    
    if os.path.exists(db_file):
        try:
            conn = sqlite3.connect(db_file)
            cursor = conn.cursor()
            tables = [row[0] for row in cursor.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
            
            cursor.execute("PRAGMA foreign_keys = OFF;")
            for table in tables:
                if not table.startswith("sqlite_"):
                    try:
                        cursor.execute(f"DELETE FROM {table};")
                        print(f"[FLUTTER RESET] Cleared table: {table}")
                    except Exception as e:
                        print(f"[FLUTTER RESET] Table {table} notice: {e}")
            cursor.execute("PRAGMA foreign_keys = ON;")
            conn.commit()
            conn.close()
            print("[FLUTTER RESET SUCCESS] All tables cleared in local Flutter Drift SQLite database!")
        except Exception as err:
            print(f"[FLUTTER RESET ERROR] Could not clear database (file may be locked by running app): {err}")
    else:
        print("[FLUTTER RESET] No local inventory_db.sqlite found in Documents folder.")

if __name__ == "__main__":
    reset_flutter_client_db()
