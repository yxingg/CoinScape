import sqlite3
import json
import sys
p='backend/data/file_sync.db'
try:
    conn=sqlite3.connect(p)
    cur=conn.cursor()
    cur.execute("SELECT path, last_synced_at, remote_path, remote_etag FROM file_index ORDER BY last_synced_at DESC LIMIT 50")
    rows=cur.fetchall()
    out=[{"path":r[0], "last_synced_at":r[1], "remote_path":r[2], "remote_etag":r[3]} for r in rows]
    print(json.dumps(out, ensure_ascii=False, indent=2))
    conn.close()
except Exception as e:
    print('ERROR', e)
    sys.exit(1)
