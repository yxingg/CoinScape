import sqlite3
import os
import sys

DBPATH = r"c:\Users\yxg\Desktop\coinscape\backend\data\file_sync.db"
if not os.path.exists(DBPATH):
    print("DB NOT FOUND:", DBPATH)
    sys.exit(1)

conn = sqlite3.connect(DBPATH)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

cur.execute("SELECT COUNT(*) as c FROM sync_queue")
print("total_queue:", cur.fetchone()["c"])
for s in ['pending','in-progress','done','failed']:
    cur.execute("SELECT COUNT(*) as c FROM sync_queue WHERE status = ?", (s,))
    print(f"{s}:", cur.fetchone()["c"])

print("\nLATEST 50 queue rows:")
cur.execute("SELECT id, path, action, status, attempts, error FROM sync_queue ORDER BY id DESC LIMIT 50")
rows = cur.fetchall()
for r in rows:
    print(dict(r))

print("\nfile_index sample (first 100):")
cur.execute("SELECT path, hash, size, mtime, last_synced_at, remote_path FROM file_index ORDER BY path LIMIT 100")
rows = cur.fetchall()
print("count:", len(rows))
for r in rows:
    print(dict(r))

conn.close()
print("DONE")
