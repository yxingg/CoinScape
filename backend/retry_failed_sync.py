#!/usr/bin/env python3
"""Retry failed sync_queue entries by marking them pending and triggering backend push.

Usage:
  python backend/retry_failed_sync.py [BASE_URL]

BASE_URL defaults to http://127.0.0.1:9877
"""
import os
import sqlite3
import sys
import time

try:
    import httpx
except Exception:
    print('Please install httpx: pip install httpx')
    sys.exit(1)

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:9877'
DB = os.path.join(os.path.dirname(__file__), 'data', 'file_sync.db')

if not os.path.isfile(DB):
    print('DB not found:', DB)
    sys.exit(1)

conn = sqlite3.connect(DB)
cur = conn.cursor()
cur.execute("SELECT id, path, error FROM sync_queue WHERE status = 'failed' ORDER BY id")
failed = cur.fetchall()
if not failed:
    print('No failed rows to retry')
    conn.close()
    sys.exit(0)

print('Failed rows:')
for r in failed:
    print(' -', r)

cur.execute("UPDATE sync_queue SET status = 'pending', error = NULL WHERE status = 'failed'")
conn.commit()
conn.close()

print('Marked failed rows as pending. Triggering push at', BASE)
try:
    with httpx.Client(timeout=300.0) as cli:
        r = cli.post(BASE.rstrip('/') + '/api/sync/files/push')
        print('push response:', r.status_code)
        try:
            print(r.json())
        except Exception:
            print(r.text)
except Exception as e:
    print('Failed to call push endpoint:', e)
    sys.exit(2)

# Poll status
start = time.time()
while True:
    try:
        with httpx.Client(timeout=30.0) as cli:
            r = cli.get(BASE.rstrip('/') + '/api/sync/files/status')
            j = r.json()
            print(j)
            if j.get('success'):
                st = j.get('status', {})
                pending = int(st.get('pending', 0))
                inprog = int(st.get('in_progress', 0))
                if pending == 0 and inprog == 0:
                    print('Queue empty — retry finished.')
                    sys.exit(0)
    except Exception as e:
        print('Status check failed:', e)

    if time.time() - start > 180:
        print('Timeout waiting for retry to complete')
        sys.exit(3)
    time.sleep(2)
