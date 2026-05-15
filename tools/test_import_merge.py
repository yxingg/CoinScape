import os
import sys
import json
from datetime import datetime

# ensure repo root on path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from backend import database as db
except Exception:
    import database as db

print('DB path:', db.DB_PATH)
# init DB (safe if exists)
db.init_db()

# create a local series entry
conn = db.get_connection()
cur = conn.cursor()
cur.execute("INSERT OR REPLACE INTO series (id, name, description, created_at) VALUES (?, ?, ?, ?)",
            ('s1', 'Local Series', 'local desc', '2020-01-01T00:00:00'))
conn.commit()
conn.close()

print('Before merge:', db.fetch_by_id('series', 's1'))

# remote backup data
backup = {
    'series': [
        {'id': 's1', 'name': 'Remote Series', 'description': 'remote desc', 'created_at': '2026-05-15T00:00:00'},
        {'id': 's2', 'name': 'Remote New', 'description': 'new', 'created_at': '2026-05-15T01:00:00'},
    ],
    'coins': [],
    'links': [],
    'coinImages': [],
    'seriesImages': []
}

# run merge with prefer_local
print('\nMerging with policy=prefer_local')
db.import_merge_data(backup, policy='prefer_local')
print('After merge (prefer_local): s1=', db.fetch_by_id('series', 's1'))
print('After merge (prefer_local): s2=', db.fetch_by_id('series', 's2'))

# now merge with prefer_remote for s1 (simulate remote wins)
print('\nMerging with policy=prefer_remote (s1 -> replace)')
backup2 = {'series': [{'id': 's1', 'name': 'Remote Series Updated', 'description': 'remote updated', 'created_at': '2026-05-15T02:00:00'}]}
db.import_merge_data(backup2, policy='prefer_remote')
print('After merge (prefer_remote): s1=', db.fetch_by_id('series', 's1'))

# now reset DB for merge_fields test
print('\nTesting merge_fields: reset s1 to local value')
conn = db.get_connection()
cur = conn.cursor()
cur.execute("UPDATE series SET name=?, description=? WHERE id=?", ('Local Series', 'local desc', 's1'))
conn.commit()
conn.close()

print('Before merge_fields:', db.fetch_by_id('series', 's1'))
print('Merging with policy=merge_fields (remote provides only description)')
backup3 = {'series': [{'id': 's1', 'description': 'remote only description'}]}
db.import_merge_data(backup3, policy='merge_fields')
print('After merge_fields:', db.fetch_by_id('series', 's1'))

print('\nDone')
