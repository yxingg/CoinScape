#!/usr/bin/env python3
"""Reproduce PUT(tmp).part -> MOVE(tmp -> target) sequence for given relative paths.

Run from project root:
  python -m backend.reproduce_failed_put_move --paths db/coinscape.db images/.thumb_cache/xxx.png

The script reads `backend/data/app_settings.json` for WebDAV settings and uses
`backend.crypto.decrypt_string` to get plaintext password.
"""
import argparse
import json
import os
import sys
from urllib.parse import urlparse, urlunparse, quote

try:
    import httpx
except Exception:
    print('Please `pip install httpx` in your environment')
    raise

import backend.crypto as crypto
import backend.database as db


def build_remote_url(base_url: str, remote_root: str, rel_path: str) -> str:
    parsed = urlparse(base_url)
    base_segments = [s for s in parsed.path.split('/') if s]
    root_segments = [s for s in (remote_root or '').split('/') if s]
    rel_segments = [s for s in rel_path.split('/') if s]
    all_segments = base_segments + root_segments + rel_segments
    quoted_path = '/' + '/'.join(quote(s, safe='') for s in all_segments)
    return urlunparse((parsed.scheme, parsed.netloc, quoted_path, '', '', ''))


def ensure_remote_parents(client: httpx.Client, url: str, auth):
    parsed = urlparse(url)
    segments = [s for s in parsed.path.split('/') if s]
    prefixes = []
    for i in range(1, len(segments)):
        prefixes.append('/' + '/'.join(segments[:i]))
    for p in prefixes:
        u = urlunparse((parsed.scheme, parsed.netloc, p, '', '', ''))
        try:
            r = client.request('MKCOL', u, auth=auth, timeout=30.0)
            print(f'  MKCOL {u} -> {r.status_code}')
        except Exception as e:
            print(f'  MKCOL {u} -> EXC {e}')


def reproduce_for_path(client: httpx.Client, base_url: str, remote_root: str, auth, save_path_root: str, rel_path: str):
    print('===', rel_path)
    local = os.path.join(save_path_root, rel_path.replace('/', os.sep))
    if not os.path.isfile(local):
        print('Local file not found:', local)
        return

    target_url = build_remote_url(base_url, remote_root, rel_path)
    parsed = urlparse(target_url)
    tmp_path = parsed.path + '.part'
    tmp_url = urlunparse((parsed.scheme, parsed.netloc, tmp_path, '', '', ''))

    print('Local:', local)
    print('Target URL:', target_url)
    print('Tmp URL:', tmp_url)

    # ensure parents
    ensure_remote_parents(client, tmp_url, auth)

    # read file
    try:
        data = open(local, 'rb').read()
    except Exception as e:
        print('Failed to read local file:', e)
        return

    # PUT tmp
    try:
        r = client.put(tmp_url, content=data, auth=auth, timeout=120.0)
        print('PUT tmp ->', r.status_code)
        print('  headers:', dict(r.headers))
        print('  body:', (r.text[:400] if r.text else ''))
    except Exception as e:
        print('PUT tmp exception:', e)
        return

    # MOVE tmp -> target
    try:
        move_headers = {'Destination': target_url, 'Overwrite': 'T'}
        r2 = client.request('MOVE', tmp_url, headers=move_headers, auth=auth, timeout=60.0)
        print('MOVE ->', r2.status_code)
        print('  headers:', dict(r2.headers))
        print('  body:', (r2.text[:400] if r2.text else ''))
        if r2.status_code in (200, 201, 204):
            print('MOVE succeeded')
            return
        else:
            print('MOVE failed, attempting fallback PUT to target')
    except Exception as e:
        print('MOVE exception:', e)

    # fallback PUT
    try:
        r3 = client.put(target_url, content=data, auth=auth, timeout=120.0)
        print('PUT target ->', r3.status_code)
        print('  headers:', dict(r3.headers))
        print('  body:', (r3.text[:400] if r3.text else ''))
        # attempt to delete tmp if exists
        try:
            rd = client.delete(tmp_url, auth=auth, timeout=30.0)
            print('DELETE tmp ->', rd.status_code)
        except Exception as e:
            print('DELETE tmp exception:', e)
    except Exception as e:
        print('PUT target exception:', e)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--paths', '-p', nargs='+', help='Relative paths to test', required=False)
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

    save_root = db.SAVE_PATH

    paths = args.paths or [
        'db/coinscape.db',
        'images/.thumb_cache/670a5124-a259-4ae4-9f65-757abc22ca45_108x72.png',
    ]

    # Use httpx client (respects environment proxies)
    with httpx.Client() as client:
        for p in paths:
            reproduce_for_path(client, base_url, remote_root, auth, save_root, p)


if __name__ == '__main__':
    sys.exit(main())
