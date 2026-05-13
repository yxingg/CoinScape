import os
import sqlite3
import hashlib
import logging
import threading
import asyncio
from datetime import datetime
from typing import Optional, Dict, Any, List
from urllib.parse import urlparse, urlunparse, quote

import httpx

from . import database as db
from . import crypto

logger = logging.getLogger("coinscape.file_sync")


DB_FILENAME = "file_sync.db"


class FileSyncManager:
    def __init__(self, db_path: Optional[str] = None):
        self.save_path = db.SAVE_PATH
        self.images_dir = db.IMAGES_DIR
        self.db_path = db_path or os.path.join(db.SAVE_PATH, DB_FILENAME)
        self._ensure_db()
        self._lock = threading.Lock()

    def _get_conn(self):
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = sqlite3.connect(self.db_path, timeout=30)
        conn.row_factory = sqlite3.Row
        return conn

    def _ensure_db(self):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.executescript(
            """
            CREATE TABLE IF NOT EXISTS file_index (
                path TEXT PRIMARY KEY,
                hash TEXT,
                size INTEGER,
                mtime REAL,
                last_seen_at TEXT,
                last_synced_at TEXT,
                remote_path TEXT,
                remote_etag TEXT
            );

            CREATE TABLE IF NOT EXISTS sync_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT,
                action TEXT CHECK(action IN('upload','delete')),
                status TEXT CHECK(status IN('pending','in-progress','done','failed')) DEFAULT 'pending',
                attempts INTEGER DEFAULT 0,
                last_attempt_at TEXT,
                error TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_queue_status ON sync_queue(status);
            """
        )
        conn.commit()
        conn.close()

    def compute_sha256(self, path: str) -> str:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()

    def _get_index_entry(self, rel_path: str) -> Optional[Dict[str, Any]]:
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT * FROM file_index WHERE path = ?", (rel_path,))
        row = cur.fetchone()
        conn.close()
        return dict(row) if row else None

    def _upsert_index(self, rel_path: str, sha: str, size: int, mtime: float, last_seen_at: str,
                      last_synced_at: Optional[str] = None, remote_path: Optional[str] = None,
                      remote_etag: Optional[str] = None):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute(
            "INSERT OR REPLACE INTO file_index(path, hash, size, mtime, last_seen_at, last_synced_at, remote_path, remote_etag) VALUES(?,?,?,?,?,?,?,?)",
            (rel_path, sha, size, mtime, last_seen_at, last_synced_at, remote_path, remote_etag),
        )
        conn.commit()
        conn.close()

    def _update_index_seen(self, rel_path: str, last_seen_at: str):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE file_index SET last_seen_at = ? WHERE path = ?", (last_seen_at, rel_path))
        conn.commit()
        conn.close()

    def _remove_index(self, rel_path: str):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("DELETE FROM file_index WHERE path = ?", (rel_path,))
        conn.commit()
        conn.close()

    def _enqueue(self, rel_path: str, action: str):
        # avoid duplicate pending task
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id FROM sync_queue WHERE path = ? AND action = ? AND status IN ('pending','in-progress')",
                    (rel_path, action))
        if cur.fetchone():
            conn.close()
            return
        cur.execute("INSERT INTO sync_queue(path, action, status, attempts) VALUES(?,?, 'pending', 0)", (rel_path, action))
        conn.commit()
        conn.close()

    def scan_and_queue(self) -> Dict[str, int]:
        """
        Scan `SAVE_PATH` recursively and enqueue upload/delete tasks.
        Returns simple summary.
        """
        start_ts = datetime.utcnow().isoformat()
        seen = set()

        for root, dirs, files in os.walk(self.save_path):
            for fn in files:
                # skip our own sync DB and the coinscape log
                rel = os.path.relpath(os.path.join(root, fn), self.save_path).replace('\\', '/')
                if rel == DB_FILENAME:
                    continue
                if rel.endswith('coinscape.log') or fn == 'coinscape.log':
                    continue

                full = os.path.join(root, fn)
                try:
                    st = os.stat(full)
                except Exception:
                    continue

                size = st.st_size
                mtime = st.st_mtime

                entry = self._get_index_entry(rel)

                # quick check by size+mtime
                if entry and entry.get('size') == size and float(entry.get('mtime') or 0) == mtime:
                    self._update_index_seen(rel, start_ts)
                    seen.add(rel)
                    continue

                # compute hash when changed or new
                try:
                    sha = self.compute_sha256(full)
                except Exception:
                    sha = ''

                if not entry or sha != (entry.get('hash') if entry else None):
                    # mark for upload
                    self._upsert_index(rel, sha, size, mtime, start_ts)
                    self._enqueue(rel, 'upload')
                else:
                    # update seen/time
                    self._upsert_index(rel, sha, size, mtime, start_ts,
                                       last_synced_at=entry.get('last_synced_at'),
                                       remote_path=entry.get('remote_path'),
                                       remote_etag=entry.get('remote_etag'))

                seen.add(rel)

        # detect deletions: any indexed path not seen in this scan -> enqueue delete
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT path, last_synced_at FROM file_index")
        rows = cur.fetchall()
        deleted_count = 0
        for r in rows:
            p = r['path']
            if p not in seen:
                # only delete remotely if it was synced before
                if r['last_synced_at']:
                    self._enqueue(p, 'delete')
                    deleted_count += 1

        conn.close()

        # summary
        return {
            'scanned': len(seen),
            'deletions_enqueued': deleted_count,
        }

    def _build_remote_url(self, base_url: str, remote_root: str, rel_path: str) -> str:
        # base_url may contain path; combine and quote path segments
        parsed = urlparse(base_url)
        base_segments = [s for s in parsed.path.split('/') if s]
        root_segments = [s for s in remote_root.split('/') if s] if remote_root else []
        rel_segments = [s for s in rel_path.split('/') if s]
        all_segments = base_segments + root_segments + rel_segments
        quoted_path = '/' + '/'.join(quote(s, safe='') for s in all_segments)
        return urlunparse((parsed.scheme, parsed.netloc, quoted_path, '', '', ''))

    async def _ensure_remote_parent_dirs_async(self, client: httpx.AsyncClient, url: str, auth: Optional[tuple]):
        # attempt to create parent collections via MKCOL for each prefix
        parsed = urlparse(url)
        segments = [s for s in parsed.path.split('/') if s]
        if not segments:
            return

        # build incremental prefixes under same scheme/netloc
        prefixes = []
        for i in range(1, len(segments)):
            prefixes.append('/' + '/'.join(segments[:i]))

        for p in prefixes:
            u = urlunparse((parsed.scheme, parsed.netloc, p, '', '', ''))
            try:
                # MKCOL may return 201 (created) or 405 (already exists) or 409 (conflict)
                resp = await client.request('MKCOL', u, auth=auth, timeout=30.0)
                if resp.status_code in (201, 405, 200, 204):
                    continue
            except Exception:
                # best-effort: ignore and continue
                continue

    async def process_queue(self, webdav_cfg: Dict[str, Any], max_attempts: int = 3) -> Dict[str, int]:
        """
        Process pending queue tasks (uploads and deletes) synchronously.
        webdav_cfg: {'url':..., 'username':..., 'password':..., 'remote_path':...}
        """
        url = webdav_cfg.get('url', '')
        if not url:
            raise ValueError('WebDAV url not configured')

        user = webdav_cfg.get('username') or ''
        enc_pw = webdav_cfg.get('password') or ''
        pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
        remote_root = webdav_cfg.get('remote_path') or ''

        auth = (user, pw) if user or pw else None

        conn = self._get_conn()
        cur = conn.cursor()

        processed = 0
        succeeded = 0
        failed = 0

        async with httpx.AsyncClient(timeout=60.0) as client:
            while True:
                cur.execute("SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY id LIMIT 1")
                row = cur.fetchone()
                if not row:
                    break

                task_id = row['id']
                rel_path = row['path']
                action = row['action']

                # mark in-progress
                cur.execute("UPDATE sync_queue SET status = 'in-progress', attempts = attempts + 1, last_attempt_at = ? WHERE id = ?", (datetime.utcnow().isoformat(), task_id))
                conn.commit()

                try:
                    if action == 'upload':
                        local = os.path.join(self.save_path, rel_path)
                        if not os.path.isfile(local):
                            # file missing locally, mark failed
                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", ('local_missing', task_id))
                            conn.commit()
                            failed += 1
                            continue
                        target_url = self._build_remote_url(url, remote_root, rel_path)

                        # construct temporary upload URL by appending .part suffix to the path
                        parsed = urlparse(target_url)
                        tmp_path = parsed.path + '.part'
                        tmp_url = urlunparse((parsed.scheme, parsed.netloc, tmp_path, '', '', ''))

                        # ensure parent dirs for tmp (and target) exist
                        try:
                            await self._ensure_remote_parent_dirs_async(client, tmp_url, auth)
                        except Exception:
                            pass

                        # read file in thread to avoid blocking
                        try:
                            data = await asyncio.to_thread(lambda: open(local, 'rb').read())
                        except Exception as e:
                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (str(e), task_id))
                            conn.commit()
                            failed += 1
                            continue

                        # upload to temporary path first
                        try:
                            put_tmp = await client.put(tmp_url, content=data, auth=auth)
                        except Exception as e:
                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (f'put_tmp_error:{e}', task_id))
                            conn.commit()
                            failed += 1
                            continue

                        if put_tmp.status_code in (200, 201, 204):
                            # attempt atomic MOVE from tmp -> target
                            move_headers = {'Destination': target_url, 'Overwrite': 'T'}
                            try:
                                move_resp = await client.request('MOVE', tmp_url, headers=move_headers, auth=auth)
                                if move_resp.status_code in (200, 201, 204):
                                    # try to fetch ETag from target via HEAD, fallback to put_tmp's ETag
                                    etag = None
                                    try:
                                        head_resp = await client.head(target_url, auth=auth)
                                        if head_resp.status_code in (200, 201):
                                            etag = head_resp.headers.get('ETag') or head_resp.headers.get('etag')
                                    except Exception:
                                        pass
                                    if not etag:
                                        etag = put_tmp.headers.get('ETag') or put_tmp.headers.get('etag')

                                    now = datetime.utcnow().isoformat()
                                    cur.execute("UPDATE file_index SET last_synced_at = ?, remote_path = ?, remote_etag = ? WHERE path = ?",
                                                (now, target_url, etag, rel_path))
                                    cur.execute("UPDATE sync_queue SET status = 'done', error = NULL WHERE id = ?", (task_id,))
                                    conn.commit()
                                    succeeded += 1
                                else:
                                    # MOVE failed -> try fallback: PUT directly to target, then cleanup tmp
                                    try:
                                        put_final = await client.put(target_url, content=data, auth=auth)
                                        if put_final.status_code in (200, 201, 204):
                                            # attempt to delete tmp
                                            try:
                                                await client.delete(tmp_url, auth=auth)
                                            except Exception:
                                                pass
                                            etag = put_final.headers.get('ETag') or put_final.headers.get('etag')
                                            now = datetime.utcnow().isoformat()
                                            cur.execute("UPDATE file_index SET last_synced_at = ?, remote_path = ?, remote_etag = ? WHERE path = ?",
                                                        (now, target_url, etag, rel_path))
                                            cur.execute("UPDATE sync_queue SET status = 'done', error = NULL WHERE id = ?", (task_id,))
                                            conn.commit()
                                            succeeded += 1
                                        else:
                                            # cleanup tmp and mark failed
                                            try:
                                                await client.delete(tmp_url, auth=auth)
                                            except Exception:
                                                pass
                                            err = f'move_failed:{move_resp.status_code}, put_target:{put_final.status_code}'
                                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (err, task_id))
                                            conn.commit()
                                            failed += 1
                                    except Exception as e:
                                        try:
                                            await client.delete(tmp_url, auth=auth)
                                        except Exception:
                                            pass
                                        cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (f'fallback_put_error:{e}', task_id))
                                        conn.commit()
                                        failed += 1
                            except Exception as e:
                                # MOVE request failed entirely; try to cleanup tmp and mark failed
                                try:
                                    await client.delete(tmp_url, auth=auth)
                                except Exception:
                                    pass
                                cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (f'move_error:{e}', task_id))
                                conn.commit()
                                failed += 1
                        else:
                            err = f'put_tmp_failed:{put_tmp.status_code}'
                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (err, task_id))
                            conn.commit()
                            failed += 1

                    elif action == 'delete':
                        target_url = self._build_remote_url(url, remote_root, rel_path)
                        try:
                            resp = await client.delete(target_url, auth=auth)
                            # treat 200/204/404 as success (404 means already removed)
                            if resp.status_code in (200, 204, 404):
                                # remove index entry
                                cur.execute("DELETE FROM file_index WHERE path = ?", (rel_path,))
                                cur.execute("UPDATE sync_queue SET status = 'done', error = NULL WHERE id = ?", (task_id,))
                                conn.commit()
                                succeeded += 1
                            else:
                                err = f'delete_failed:{resp.status_code}'
                                cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (err, task_id))
                                conn.commit()
                                failed += 1
                        except Exception as e:
                            cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (str(e), task_id))
                            conn.commit()
                            failed += 1

                except Exception as e:
                    cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (str(e), task_id))
                    conn.commit()
                    failed += 1

                processed += 1

        conn.close()

        return {'processed': processed, 'succeeded': succeeded, 'failed': failed}

    def get_status(self) -> Dict[str, int]:
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) as c FROM sync_queue WHERE status = 'pending'")
        pending = cur.fetchone()['c']
        cur.execute("SELECT COUNT(*) as c FROM sync_queue WHERE status = 'in-progress'")
        inprog = cur.fetchone()['c']
        cur.execute("SELECT COUNT(*) as c FROM sync_queue WHERE status = 'failed'")
        failed = cur.fetchone()['c']
        cur.execute("SELECT COUNT(*) as c FROM sync_queue WHERE status = 'done'")
        done = cur.fetchone()['c']
        conn.close()
        return {'pending': pending, 'in_progress': inprog, 'failed': failed, 'done': done}

    async def push_all(self) -> Dict[str, Any]:
        # single-run guard
        if not self._lock.acquire(blocking=False):
            return {'started': False, 'reason': 'already_running'}
        try:
            logger.info('Starting file sync scan')
            scan_summary = self.scan_and_queue()
            # load webdav settings
            try:
                settings = db.load_app_settings()
                webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
            except Exception:
                webdav = {}

            proc = await self.process_queue(webdav)
            return {'started': True, 'scan': scan_summary, 'process': proc}
        finally:
            self._lock.release()


# module-level manager
manager = FileSyncManager()
