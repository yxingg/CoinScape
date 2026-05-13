#!/usr/bin/env python3
"""
backend/test_sync_push.py

Trigger the backend file sync (uses backend's saved WebDAV config) and poll status.

Usage (from project root):
  python -m backend.test_sync_push --base http://127.0.0.1:9876 --wait

If your backend is not started, start it first (from project root):
  python -m backend.main

The script posts to `/api/sync/files/push` then polls `/api/sync/files/status` until
the queue reports no pending/in-progress items or a timeout is reached.
"""

import argparse
import time
import sys
import json

import httpx


def do_push(base_url: str, timeout: float = 120.0):
    url = base_url.rstrip('/') + '/api/sync/files/push'
    print(f'POST {url}')
    try:
        with httpx.Client(timeout=timeout) as cli:
            r = cli.post(url)
    except Exception as e:
        print('Error: failed to call push endpoint:', e, file=sys.stderr)
        return None

    try:
        return r.json()
    except Exception:
        print('Non-JSON response:', r.text)
        return None


def get_status(base_url: str):
    url = base_url.rstrip('/') + '/api/sync/files/status'
    try:
        with httpx.Client(timeout=30.0) as cli:
            r = cli.get(url)
            return r.json()
    except Exception as e:
        print('Error fetching status:', e, file=sys.stderr)
        return None


def poll_status(base_url: str, poll_interval: float, timeout: int):
    start = time.monotonic()
    while True:
        st = get_status(base_url)
        if st is None:
            print('Status API unavailable; retrying...')
        else:
            # backend returns {"success": True, "status": {...}}
            if st.get('success'):
                counts = st.get('status', {})
                print(json.dumps(counts, indent=2, ensure_ascii=False))
                pending = int(counts.get('pending', 0))
                inprog = int(counts.get('in_progress', 0))
                if pending == 0 and inprog == 0:
                    print('Queue empty — sync appears finished.')
                    return 0
                else:
                    print(f"Pending={pending} InProgress={inprog} — waiting {poll_interval}s...")
            else:
                print('Status API returned:', st)

        if time.monotonic() - start > timeout:
            print('Timeout waiting for sync to complete', file=sys.stderr)
            return 2
        time.sleep(poll_interval)


def main(argv=None):
    p = argparse.ArgumentParser(description='Trigger backend file sync and poll status')
    p.add_argument('--base', '-b', default='http://localhost:9876', help='Backend base URL')
    p.add_argument('--wait', action='store_true', help='Poll /api/sync/files/status until queue drains')
    p.add_argument('--poll-interval', type=float, default=1.0, help='Seconds between status polls')
    p.add_argument('--timeout', type=int, default=300, help='Max seconds to wait when --wait is used')
    args = p.parse_args(argv)

    print('Triggering push on backend...')
    res = do_push(args.base)
    print('push response:')
    print(json.dumps(res, indent=2, ensure_ascii=False))

    if not args.wait:
        return 0

    return poll_status(args.base, args.poll_interval, args.timeout)


if __name__ == '__main__':
    sys.exit(main())
