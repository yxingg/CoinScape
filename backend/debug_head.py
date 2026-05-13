#!/usr/bin/env python3
"""Debug tool: show built remote URL and perform HEAD/GET for a relative path.

Usage:
  python -m backend.debug_head --path db/coinscape.db --method HEAD
"""
import argparse
import json
import os
import sys

try:
    import httpx
except Exception:
    print('Please `pip install httpx`')
    raise

import backend.crypto as crypto
import backend.file_sync as fs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--path', '-p', required=True, help='Relative path to check')
    ap.add_argument('--method', '-m', choices=['HEAD', 'GET'], default='HEAD')
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

    target_url = fs.manager._build_remote_url(base_url, remote_root, args.path)
    print('Target URL:', target_url)
    auth = (user, pw) if (user or pw) else None

    with httpx.Client() as client:
        try:
            if args.method == 'HEAD':
                r = client.head(target_url, auth=auth, timeout=30.0)
                print('HEAD', r.status_code)
                print('Headers:', dict(r.headers))
            else:
                r = client.get(target_url, auth=auth, timeout=120.0)
                print('GET', r.status_code)
                print('Headers:', dict(r.headers))
                print('Body (first 400 chars):')
                print(r.text[:400])
        except Exception as e:
            print('Request exception:', e)

    return 0


if __name__ == '__main__':
    sys.exit(main())
