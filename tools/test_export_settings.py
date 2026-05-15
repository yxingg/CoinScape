import os, sys, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
try:
    from backend import database as db
except Exception:
    import database as db

exp = db.export_all_data()
print('export keys:', list(exp.keys()))
print('settings present:', 'settings' in exp)
if 'settings' in exp:
    s = exp['settings']
    sync = s.get('sync', {})
    print('sync keys:', list(sync.keys()))
    print('merge_policy:', sync.get('merge_policy'))
    print('webdav password present:', 'webdav' in sync and 'password' in (sync.get('webdav') or {}), 'value:', (sync.get('webdav') or {}).get('password'))
else:
    print('no settings')
