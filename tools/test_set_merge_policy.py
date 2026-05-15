import os, sys, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
try:
    from backend import database as db
except Exception:
    import database as db

print('Before update:', db.load_app_settings().get('sync', {}).get('merge_policy'))
db.update_app_settings({'sync': {'merge_policy': 'prefer_remote'}})
print('After update (from settings file):', db.load_app_settings().get('sync', {}).get('merge_policy'))
exp = db.export_all_data()
print('Exported merge_policy:', exp.get('settings', {}).get('sync', {}).get('merge_policy'))
