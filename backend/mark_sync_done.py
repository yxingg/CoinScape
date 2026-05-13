#!/usr/bin/env python3
"""Mark pending/in-progress sync_queue entries as done if the remote resource exists.

Usage:
  python -m backend.mark_sync_done --ids 3 15
  python -m backend.mark_sync_done

If --ids is omitted, the script checks all non-done entries.
"""
import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime
from urllib.parse import urlparse, urlunparse, quote

try:
    import httpx
except Exception:
    print('Please `pip install httpx`')
    raise

import backend.crypto as crypto
import backend.database as db
import backend.file_sync as fs


def build_remote_url(base_url: str, remote_root: str, rel_path: str) -> str:
    # reuse FileSyncManager logic via instance if available
    try:
        return fs.manager._build_remote_url(base_url, remote_root, rel_path)
    except Exception:
        parsed = urlparse(base_url)
        base_segments = [s for s in parsed.path.split('/') if s]
        root_segments = [s for s in (remote_root or '').split('/') if s]
        rel_segments = [s for s in rel_path.split('/') if s]
        all_segments = base_segments + root_segments + rel_segments
        quoted_path = '/' + '/'.join(quote(s, safe='') for s in all_segments)
        return urlunparse((parsed.scheme, parsed.netloc, quoted_path, '', '', ''))


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--ids', '-i', nargs='*', type=int, help='Specific sync_queue ids to check')
    args = ap.parse_args(argv)

    settings_path = os.path.join(os.path.dirname(__file__), 'data', 'app_settings.json')
    if not os.path.isfile(settings_path):
        print('settings not found:', settings_path)
        return 2

    with open(settings_path, 'r', encoding='utf-8') as f:
        settings = json.load(f)

    webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
    base_url = webdav.get('url') or ''
    user = webdav.get('username') or ''
    enc_pw = webdav.get('password') or ''
    pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
    remote_root = webdav.get('remote_path') or ''

    if not base_url:
        print('WebDAV base URL not configured in settings')
        return 3

    auth = (user, pw) if (user or pw) else None

    DB = os.path.join(os.path.dirname(__file__), 'data', 'file_sync.db')
    if not os.path.isfile(DB):
        print('DB not found:', DB)
        return 4

    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    if args.ids:
        q = f"SELECT * FROM sync_queue WHERE id IN ({','.join(['?']*len(args.ids))})"
        rows = cur.execute(q, args.ids).fetchall()
    else:
        rows = cur.execute("SELECT * FROM sync_queue WHERE status != 'done' ORDER BY id DESC").fetchall()

    if not rows:
        print('No non-done queue entries found')
        conn.close()
        return 0

    now = datetime.utcnow().isoformat()
    with httpx.Client() as client:
        for r in rows:
            task_id = r['id']
            rel_path = r['path']
            print('Checking', task_id, rel_path)
            target_url = build_remote_url(base_url, remote_root, rel_path)
            try:
                head = client.head(target_url, auth=auth, timeout=30.0)
                status = head.status_code
                print('  HEAD', status)
                if status in (200, 201, 204):
                    etag = head.headers.get('ETag') or head.headers.get('etag')
                    # update or insert file_index
                    cur.execute("SELECT COUNT(*) as c FROM file_index WHERE path = ?", (rel_path,))
                    if cur.fetchone()['c']:
                        cur.execute("UPDATE file_index SET last_synced_at = ?, remote_path = ?, remote_etag = ? WHERE path = ?", (now, target_url, etag, rel_path))
                    else:
                        cur.execute("INSERT INTO file_index(path, hash, size, mtime, last_seen_at, last_synced_at, remote_path, remote_etag) VALUES(?,?,?,?,?,?,?,?)", (rel_path, '', 0, 0.0, now, now, target_url, etag))
                    cur.execute("UPDATE sync_queue SET status = 'done', error = NULL WHERE id = ?", (task_id,))
                    conn.commit()
                    print('  Marked done')
                else:
                    print('  Not present remotely (HEAD != 200/201/204)')
            except Exception as e:
                print('  HEAD exception', e)

    conn.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
