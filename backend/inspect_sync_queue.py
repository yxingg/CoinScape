#!/usr/bin/env python3
import sqlite3
import json
import os
import sys

DB = os.path.join(os.path.dirname(__file__), 'data', 'file_sync.db')

if not os.path.isfile(DB):
    print('DB not found:', DB)
    sys.exit(1)

conn = sqlite3.connect(DB)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
rows = cur.execute("SELECT * FROM sync_queue WHERE status != 'done' ORDER BY id DESC").fetchall()
print(json.dumps([dict(r) for r in rows], ensure_ascii=False, indent=2))
conn.close()
