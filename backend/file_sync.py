import os
import sqlite3
import hashlib
import json
import uuid
import logging
import threading
import asyncio
import zipfile
from datetime import datetime
from typing import Optional, Dict, Any, List
from urllib.parse import urlparse, urlunparse, quote, unquote
import xml.etree.ElementTree as ET

import httpx
import random

try:
    from . import database as db
    from . import crypto
except Exception:
    import database as db
    import crypto

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

    def scan_and_queue(self, force: bool = False) -> Dict[str, int]:
        """
        Scan `SAVE_PATH` recursively and enqueue upload/delete tasks.
        Returns simple summary.
        """
        start_ts = datetime.utcnow().isoformat()
        logger.debug('scan_and_queue start: save_path=%s force=%s', self.save_path, force)
        seen = set()

        for root, dirs, files in os.walk(self.save_path):
            # Skip staging/temp directories entirely
            dirs[:] = [d for d in dirs if d not in ('.imported_dbs', '.thumb_cache', 'uploads')]
            for fn in files:
                rel = os.path.relpath(os.path.join(root, fn), self.save_path).replace('\\', '/')
                
                # Skip internal sync DB and journals
                if rel == DB_FILENAME or fn in ('file_sync.db-wal', 'file_sync.db-shm'):
                    continue
                
                # Skip log files and rotated backups
                if fn == 'coinscape.log' or fn.startswith('coinscape.log.'):
                    continue
                
                # Skip config files (contain credentials)
                if fn in ('app_config.json', 'app_settings.json'):
                    continue
                
                # Skip temp/staging files
                if fn.endswith('.tmp') or fn.endswith('.tmp.tmp'):
                    continue
                if fn.endswith('-wal') or fn.endswith('-shm'):
                    continue
                
                # Skip .ccm backup archives (transient staging)
                if fn.endswith('.ccm'):
                    continue

                full = os.path.join(root, fn)
                try:
                    st = os.stat(full)
                except Exception:
                    continue

                size = st.st_size
                mtime = st.st_mtime

                entry = self._get_index_entry(rel)

                # quick check by size+mtime; if not forcing a full push then skip unchanged files
                if entry and entry.get('size') == size and float(entry.get('mtime') or 0) == mtime and not force:
                    logger.debug('Skipping unchanged file by size/mtime: %s', rel)
                    self._update_index_seen(rel, start_ts)
                    seen.add(rel)
                    continue

                # compute hash when changed or new (or when forcing)
                try:
                    sha = self.compute_sha256(full)
                    logger.debug('Computed sha for %s: %s', rel, sha)
                except Exception:
                    sha = ''

                # If force is requested, always enqueue uploads (even if hash unchanged)
                if force:
                    self._upsert_index(rel, sha, size, mtime, start_ts,
                                       last_synced_at=(entry.get('last_synced_at') if entry else None),
                                       remote_path=(entry.get('remote_path') if entry else None),
                                       remote_etag=(entry.get('remote_etag') if entry else None))
                    self._enqueue(rel, 'upload')
                    logger.info('Enqueued upload (force): %s', rel)
                else:
                    if not entry or sha != (entry.get('hash') if entry else None):
                        # mark for upload
                        self._upsert_index(rel, sha, size, mtime, start_ts)
                        self._enqueue(rel, 'upload')
                        logger.info('Enqueued upload: %s', rel)
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
                    logger.info('Enqueued remote delete: %s', p)
                    deleted_count += 1

        conn.close()

        # summary
        logger.info('scan_and_queue summary: scanned=%d deletions_enqueued=%d', len(seen), deleted_count)
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

    def _create_async_client(self, timeout):
        """Create an httpx.AsyncClient with redirect option compatible across httpx versions.
        Tries `follow_redirects`, falls back to `allow_redirects`, otherwise returns client without explicit redirect arg.
        """
        kwargs = {'timeout': timeout, 'trust_env': False}
        try:
            return httpx.AsyncClient(**{**kwargs, 'follow_redirects': True})
        except TypeError:
            try:
                return httpx.AsyncClient(**{**kwargs, 'allow_redirects': True})
            except TypeError:
                return httpx.AsyncClient(**kwargs)

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

        # lazy init verified dirs cache and lock to avoid concurrent MKCOL storms
        if not hasattr(self, '_verified_dirs'):
            self._verified_dirs = set()
        if not hasattr(self, '_verified_dirs_lock') or self._verified_dirs_lock is None:
            try:
                self._verified_dirs_lock = asyncio.Lock()
            except Exception:
                self._verified_dirs_lock = None

        for p in prefixes:
            # fast-path: if directory already verified, skip
            if p in self._verified_dirs:
                continue

            u = urlunparse((parsed.scheme, parsed.netloc, p, '', '', ''))

            # Use lock to ensure only one coroutine attempts MKCOL for this prefix at a time
            if self._verified_dirs_lock is not None:
                async with self._verified_dirs_lock:
                    if p in self._verified_dirs:
                        continue
                    try:
                        resp = await self._request_with_retry(client, 'MKCOL', u, auth=auth, timeout=30.0, max_attempts=2)
                    except Exception as e:
                        logger.error('MKCOL request exception for %s: %s', u, e, exc_info=True)
                        continue

                    if resp is None:
                        continue
                    # Treat common success codes (including redirects) as success so MKCOL on servers like AList won't break
                    if resp.status_code in (201, 405, 200, 204, 301, 307, 308):
                        self._verified_dirs.add(p)
                        continue
                    else:
                        logger.debug('MKCOL returned status %s for %s', resp.status_code, u)
                        continue
            else:
                try:
                    resp = await self._request_with_retry(client, 'MKCOL', u, auth=auth, timeout=30.0, max_attempts=2)
                except Exception as e:
                    logger.error('MKCOL request exception for %s: %s', u, e, exc_info=True)
                    continue
                if resp is None:
                    continue
                if resp.status_code in (201, 405, 200, 204, 301, 307, 308):
                    self._verified_dirs.add(p)
                    continue

    async def _write_remote_backup_marker(self, webdav_cfg: Dict[str, Any], iso_ts: Optional[str] = None, rel_meta: str = '.coinscape/last_cloud_backup.txt') -> bool:
        """Write a small marker file containing iso timestamp to remote WebDAV under rel_meta.
        Returns True on success.
        """
        url = webdav_cfg.get('url') if isinstance(webdav_cfg, dict) else ''
        if not url:
            return False

        user = webdav_cfg.get('username') or ''
        enc_pw = webdav_cfg.get('password') or ''
        try:
            pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
        except Exception:
            pw = enc_pw or ''
        remote_root = webdav_cfg.get('remote_path') or ''
        auth = (user, pw) if user or pw else None

        if not iso_ts:
            iso_ts = datetime.utcnow().isoformat()

        # fetch/generate device id and user info from settings (offload to thread)
        try:
            settings = await asyncio.to_thread(db.load_app_settings)
            sync_conf = settings.get('sync') if isinstance(settings.get('sync'), dict) else settings.get('sync', {})
            device_id = sync_conf.get('device_id') if isinstance(sync_conf, dict) else None
            if not device_id:
                device_id = uuid.uuid4().hex
                try:
                    await asyncio.to_thread(db.update_app_settings, {'sync': {'device_id': device_id}})
                except Exception:
                    pass
            user_info = settings.get('auth', {}).get('username') if isinstance(settings.get('auth'), dict) else None
        except Exception:
            device_id = uuid.uuid4().hex
            user_info = None

        payload = {'timestamp': iso_ts, 'device_id': device_id, 'user': user_info}
        # checksum over sorted JSON to ensure stable checksum
        try:
            payload_bytes = json.dumps(payload, sort_keys=True, ensure_ascii=False).encode('utf-8')
            checksum = hashlib.sha256(payload_bytes).hexdigest()
            payload['checksum'] = checksum
            data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        except Exception:
            data = iso_ts.encode('utf-8')

        target_url = self._build_remote_url(url, remote_root, rel_meta)
        parsed = urlparse(target_url)
        tmp_path = parsed.path + '.part'
        tmp_url = urlunparse((parsed.scheme, parsed.netloc, tmp_path, '', '', ''))

        client = self._create_async_client(60.0)
        async with client as client:
            try:
                await self._ensure_remote_parent_dirs_async(client, tmp_url, auth)
            except Exception:
                pass

            try:
                put_tmp = await client.put(tmp_url, content=data, auth=auth)
            except Exception as e:
                logger.exception('put tmp for remote marker failed: %s', e)
                return False

            if put_tmp.status_code in (200, 201, 204):
                move_headers = {'Destination': target_url, 'Overwrite': 'T'}
                try:
                    move_resp = await client.request('MOVE', tmp_url, headers=move_headers, auth=auth)
                    if move_resp.status_code in (200, 201, 204):
                        return True
                    else:
                        # fallback to direct PUT
                        try:
                            put_final = await client.put(target_url, content=data, auth=auth)
                            return put_final.status_code in (200, 201, 204)
                        except Exception:
                            return False
                except Exception:
                    try:
                        await client.delete(tmp_url, auth=auth)
                    except Exception:
                        pass
                    return False
            else:
                # try direct put
                try:
                    put_final = await client.put(target_url, content=data, auth=auth)
                    return put_final.status_code in (200, 201, 204)
                except Exception:
                    return False

    async def _list_remote_files(self, client: httpx.AsyncClient, base_url: str, remote_root: str, auth: Optional[tuple]) -> List[Dict[str, Any]]:
        """Return list of remote files under the remote_root. Each item: {'href': href_url, 'size': int or None}
        Uses PROPFIND recursion (Depth:1) to enumerate children.
        """
        start_url = self._build_remote_url(base_url, remote_root, '')
        if not start_url.endswith('/'):
            start_url = start_url + '/'

        to_visit = [start_url]
        seen = set()
        files = []

        logger.debug('Listing remote files under %s (start_url=%s)', remote_root, start_url)

        propfind_body = '<?xml version="1.0" encoding="utf-8"?>\n<d:propfind xmlns:d="DAV:">\n  <d:prop>\n    <d:getcontentlength/>\n    <d:getlastmodified/>\n    <d:resourcetype/>\n  </d:prop>\n</d:propfind>'

        while to_visit:
            url = to_visit.pop(0)
            if url in seen:
                continue
            seen.add(url)
            headers = {'Depth': '1', 'Content-Type': 'text/xml'}
            try:
                resp = await self._request_with_retry(client, 'PROPFIND', url, auth=auth, headers=headers, content=propfind_body, timeout=30.0, max_attempts=2)
            except Exception:
                # cannot list this url; skip
                continue

            try:
                root = ET.fromstring(resp.text)
            except Exception:
                continue

            for resp_el in root.findall('.//{DAV:}response'):
                href_el = resp_el.find('{DAV:}href')
                if href_el is None or not href_el.text:
                    continue
                href = href_el.text
                parsed_href = urlparse(href)
                href_url = urlunparse((parsed_href.scheme or urlparse(url).scheme, parsed_href.netloc or urlparse(url).netloc, parsed_href.path, '', '', ''))

                # try to inspect prop (only consider propstat with 200)
                is_dir = False
                size = None
                # ensure these are always defined even if absent in response
                last_modified = None
                etag = None
                for propstat in resp_el.findall('{DAV:}propstat'):
                    status_el = propstat.find('{DAV:}status')
                    if status_el is not None and '200' not in (status_el.text or ''):
                        continue
                    prop = propstat.find('{DAV:}prop')
                    if prop is not None:
                        rt = prop.find('{DAV:}resourcetype')
                        if rt is not None and rt.find('{DAV:}collection') is not None:
                            is_dir = True
                        gl = prop.find('{DAV:}getcontentlength')
                        if gl is not None and gl.text:
                            try:
                                size = int(gl.text)
                            except Exception:
                                size = None
                        gm = prop.find('{DAV:}getlastmodified')
                        if gm is not None and gm.text:
                            last_modified = gm.text
                        ge = prop.find('{DAV:}getetag')
                        if ge is not None and ge.text:
                            etag = ge.text
                    break

                if is_dir:
                    if not href_url.endswith('/'):
                        href_url = href_url + '/'
                    if href_url not in seen:
                        to_visit.append(href_url)
                else:
                    files.append({'href': href_url, 'size': size, 'last_modified': last_modified, 'etag': etag})

        return files

    def _relpath_from_remote_href(self, base_url: str, remote_root: str, href_url: str) -> Optional[str]:
        """Compute relative path under save_path for a given remote href URL."""
        try:
            parsed_base = urlparse(base_url)
            base_segments = [s for s in parsed_base.path.split('/') if s]
            root_segments = [s for s in (remote_root or '').split('/') if s]
            prefix_len = len(base_segments) + len(root_segments)

            parsed_href = urlparse(href_url)
            href_segments = [unquote(s) for s in parsed_href.path.split('/') if s]
            if len(href_segments) <= prefix_len:
                return None
            rel_segments = href_segments[prefix_len:]
            return '/'.join(rel_segments)
        except Exception:
            return None

    def _extract_data_from_sqlite_file(self, path: str) -> Dict[str, Any]:
        """Read a sqlite DB file at `path` and return exportable dict (series, coins, links, coinImages, seriesImages)."""
        try:
            conn = sqlite3.connect(path)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            def rows(q):
                cur.execute(q)
                return [dict(r) for r in cur.fetchall()]

            series = rows("SELECT id, name, description, created_at FROM series")
            coins = rows("SELECT id, name, year, face_value, material, weight, diameter, mintage, mint, grade, unit_price, quantity, quantity_unit, collection_time, created_at, comments, first_image_path FROM coins")
            links = rows("SELECT coin_id, series_id FROM coin_series_link")
            coinImages = rows("SELECT id, coin_id, image_path, sort_order FROM coin_images")
            seriesImages = rows("SELECT id, series_id, image_path, sort_order FROM series_images")
            conn.close()
            return {
                'series': series,
                'coins': coins,
                'links': links,
                'coinImages': coinImages,
                'seriesImages': seriesImages,
            }
        except Exception:
            return {}

    def _extract_data_from_ccm(self, path: str) -> Dict[str, Any]:
        """Extract data from a .ccm ZIP backup (contains db.json + images/*).
        Returns importable dict or empty dict on failure.
        Also extracts images to the images directory.
        """
        try:
            with zipfile.ZipFile(path, 'r') as zf:
                names = zf.namelist()
                # Extract db.json
                data = {}
                if 'db.json' in names:
                    raw = zf.read('db.json')
                    data = json.loads(raw.decode('utf-8'))
                
                # Extract images to images directory
                images_dir = os.path.join(self.save_path, 'images')
                os.makedirs(images_dir, exist_ok=True)
                for name in names:
                    if name.startswith('images/') and not name.endswith('/'):
                        img_data = zf.read(name)
                        img_filename = os.path.basename(name)
                        img_path = os.path.join(images_dir, img_filename)
                        with open(img_path, 'wb') as f:
                            f.write(img_data)
                
                return data
        except Exception as e:
            logger.warning('_extract_data_from_ccm failed for %s: %s', path, e)
            return {}

    async def pull_all(self) -> Dict[str, Any]:
        """Download files from remote WebDAV into local save_path (file-level pull + DB import when DB found).
        Returns summary.
        """
        settings = await asyncio.to_thread(db.load_app_settings)
        webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
        url = webdav.get('url') if isinstance(webdav, dict) else ''
        if not url:
            raise ValueError('WebDAV url not configured')

        user = webdav.get('username') or ''
        enc_pw = webdav.get('password') or ''
        try:
            pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
        except Exception:
            pw = enc_pw or ''
        auth = (user, pw) if user or pw else None
        remote_root = webdav.get('remote_path') or ''

        # fetch remote marker timestamp if available
        meta_rel = '.coinscape/last_cloud_backup.txt'
        remote_ts = None
        try:
            meta_url = self._build_remote_url(url, remote_root, meta_rel)
            client = self._create_async_client(20.0)
            async with client as client:
                try:
                    resp = await self._request_with_retry(client, 'GET', meta_url, auth=auth, timeout=20.0, max_attempts=2)
                    if resp is not None and resp.status_code in (200, 201):
                        try:
                            j = resp.json()
                            if isinstance(j, dict) and 'timestamp' in j:
                                remote_ts = j.get('timestamp')
                            else:
                                text = (resp.text or '').strip()
                                if text:
                                    remote_ts = text
                        except Exception:
                            text = (resp.text or '').strip()
                            if text:
                                remote_ts = text
                except Exception:
                    pass
        except Exception:
            remote_ts = None

        downloaded = 0
        failed = 0
        imported_db = False

        client = self._create_async_client(60.0)
        async with client as client:
            files = await self._list_remote_files(client, url, remote_root, auth)
            for f in files:
                href = f.get('href')
                rel = self._relpath_from_remote_href(url, remote_root, href)
                if not rel:
                    continue
                # skip marker file
                if rel.startswith('.coinscape'):
                    continue
                # skip coinscape.log
                if rel.endswith('coinscape.log') or rel.split('/')[-1] == 'coinscape.log':
                    continue

                target_local = os.path.join(self.save_path, rel.replace('/', os.sep))
                os.makedirs(os.path.dirname(target_local), exist_ok=True)

                try:
                    get_resp = await self._request_with_retry(client, 'GET', href, auth=auth, timeout=120.0, max_attempts=3)
                except Exception as e:
                    await asyncio.to_thread(self._db_mark_queue_failed, -1, f'pull_get_error:{rel}:{e}')
                    failed += 1
                    continue

                if get_resp is None or get_resp.status_code not in (200, 201):
                    await asyncio.to_thread(self._db_mark_queue_failed, -1, f'pull_get_status:{rel}:{get_resp.status_code if get_resp is not None else "none"}')
                    failed += 1
                    continue

                # write file
                try:
                    with open(target_local + '.tmp', 'wb') as fh:
                        fh.write(get_resp.content)
                    os.replace(target_local + '.tmp', target_local)
                except Exception as e:
                    # Clean up orphaned .tmp file
                    try:
                        tmp_path = target_local + '.tmp'
                        if os.path.exists(tmp_path):
                            os.remove(tmp_path)
                    except Exception:
                        pass
                    await asyncio.to_thread(self._db_mark_queue_failed, -1, f'pull_write_error:{rel}:{e}')
                    failed += 1
                    continue

                # update file_index
                etag = get_resp.headers.get('ETag') or get_resp.headers.get('etag')
                last_synced_at = remote_ts or datetime.utcnow().isoformat()
                await asyncio.to_thread(self._db_update_file_index_after_upload, rel, last_synced_at, href, etag)
                downloaded += 1

                # if this is the sqlite DB file, extract and import
                # Prioritize root-level coinscape.db (Android data) over db/coinscape.db (backend's own old data).
                # Once we've imported from one source, skip the other to avoid overwriting.
                if rel == 'coinscape.db' and not imported_db:
                    try:
                        temp_db_path = target_local
                        data = await asyncio.to_thread(self._extract_data_from_sqlite_file, temp_db_path)
                        if data:
                            await asyncio.to_thread(db.import_all_data, data)
                            imported_db = True
                            # Clean up staging copy
                            try:
                                os.remove(target_local)
                                logger.info('Cleaned up staging file: %s', rel)
                            except Exception:
                                pass
                    except Exception as e:
                        await asyncio.to_thread(self._db_mark_queue_failed, -1, f'db_import_error:{e}')
                        failed += 1
                elif rel == 'db/coinscape.db' and not imported_db:
                    try:
                        temp_db_path = target_local
                        data = await asyncio.to_thread(self._extract_data_from_sqlite_file, temp_db_path)
                        if data:
                            await asyncio.to_thread(db.import_all_data, data)
                            imported_db = True
                    except Exception as e:
                        await asyncio.to_thread(self._db_mark_queue_failed, -1, f'db_import_error:{e}')
                        failed += 1

                # if this is a .ccm backup (ZIP), extract db.json and import
                if rel.endswith('.ccm') and not imported_db:
                    try:
                        data = await asyncio.to_thread(self._extract_data_from_ccm, target_local)
                        if data:
                            await asyncio.to_thread(db.import_all_data, data)
                            imported_db = True
                            logger.info('Imported data from .ccm backup: %s', rel)
                            # Clean up .ccm staging file
                            try:
                                os.remove(target_local)
                                logger.info('Cleaned up .ccm file: %s', rel)
                            except Exception:
                                pass
                    except Exception as e:
                        logger.warning('Failed to import .ccm backup %s: %s', rel, e)

        # Fallback: if no DB was imported during download, check if a local coinscape.db exists
        # (may have been downloaded in a previous pull or placed manually) and import it.
        # Prioritize root-level coinscape.db (Android data) over db/coinscape.db (backend's own old data).
        if not imported_db:
            for candidate_rel in ('coinscape.db', 'db/coinscape.db'):
                candidate_path = os.path.join(self.save_path, candidate_rel.replace('/', os.sep))
                if os.path.isfile(candidate_path):
                    try:
                        data = await asyncio.to_thread(self._extract_data_from_sqlite_file, candidate_path)
                        if data and (data.get('series') or data.get('coins')):
                            await asyncio.to_thread(db.import_all_data, data)
                            imported_db = True
                            logger.info('Fallback: imported existing DB from %s', candidate_rel)
                            # Clean up: delete the staging copy if it's not the working DB
                            if candidate_rel != 'db/coinscape.db':
                                try:
                                    os.remove(candidate_path)
                                    logger.info('Cleaned up staging file: %s', candidate_rel)
                                except Exception:
                                    pass
                            break
                    except Exception as e:
                        logger.warning('Fallback DB import failed for %s: %s', candidate_rel, e)

        # Fallback: check for .ccm files
        if not imported_db:
            try:
                for fname in os.listdir(self.save_path):
                    if fname.endswith('.ccm'):
                        ccm_path = os.path.join(self.save_path, fname)
                        data = await asyncio.to_thread(self._extract_data_from_ccm, ccm_path)
                        if data and (data.get('series') or data.get('coins')):
                            await asyncio.to_thread(db.import_all_data, data)
                            imported_db = True
                            logger.info('Fallback: imported from .ccm backup %s', fname)
                            # Clean up the .ccm staging file
                            try:
                                os.remove(ccm_path)
                                logger.info('Cleaned up .ccm file: %s', fname)
                            except Exception:
                                pass
                            break
            except Exception as e:
                logger.warning('Fallback .ccm scan failed: %s', e)

        # After pull, sync local timestamp with remote so status shows "已同步"
        # Use remote marker time if available, otherwise use current time
        sync_ts = remote_ts or datetime.utcnow().isoformat()
        try:
            await asyncio.to_thread(db.update_app_settings, {'sync': {'last_local_change': sync_ts}})
        except Exception:
            pass

        return {'downloaded': downloaded, 'failed': failed, 'imported_db': imported_db, 'remote_marker': remote_ts}

    async def preview_pull(self) -> Dict[str, Any]:
        """Return a preview/diff of remote files vs local index without making changes.
        Returns: { counts: {...}, entries: [ {path, status, remote:{href,size,last_modified,etag}, local:{hash,size,last_synced_at,remote_etag}} ] }
        Status values: 'new_remote', 'modified_remote', 'unchanged', 'deleted_remote', 'local_only'
        """
        settings = await asyncio.to_thread(db.load_app_settings)
        webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
        url = webdav.get('url') if isinstance(webdav, dict) else ''
        if not url:
            raise ValueError('WebDAV url not configured')

        user = webdav.get('username') or ''
        enc_pw = webdav.get('password') or ''
        try:
            pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
        except Exception:
            pw = enc_pw or ''
        auth = (user, pw) if user or pw else None
        remote_root = webdav.get('remote_path') or ''

        client = self._create_async_client(30.0)
        async with client as client:
            remote_files = await self._list_remote_files(client, url, remote_root, auth)

        # build remote map
        remote_map: Dict[str, Dict[str, Any]] = {}
        for f in remote_files:
            href = f.get('href')
            rel = self._relpath_from_remote_href(url, remote_root, href)
            if not rel:
                continue
            # skip metadata and logs
            if rel.startswith('.coinscape'):
                continue
            if rel.endswith('coinscape.log') or rel.split('/')[-1] == 'coinscape.log':
                continue
            remote_map[rel] = {
                'href': href,
                'size': f.get('size'),
                'last_modified': f.get('last_modified'),
                'etag': f.get('etag'),
            }

        # read local index entries
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT path, hash, size, last_seen_at, last_synced_at, remote_path, remote_etag FROM file_index")
        rows = cur.fetchall()
        conn.close()

        local_map: Dict[str, Dict[str, Any]] = {r['path']: dict(r) for r in rows}

        all_paths = sorted(set(list(remote_map.keys()) + list(local_map.keys())))
        entries: List[Dict[str, Any]] = []
        counts = {'new_remote': 0, 'modified_remote': 0, 'deleted_remote': 0, 'local_only': 0, 'unchanged': 0}

        for path in all_paths:
            r = remote_map.get(path)
            l = local_map.get(path)
            if r and not l:
                status = 'new_remote'
                counts['new_remote'] += 1
            elif r and l:
                # compare using etag when available, otherwise size
                if r.get('etag') and l.get('remote_etag') and str(r.get('etag')) != str(l.get('remote_etag')):
                    status = 'modified_remote'
                    counts['modified_remote'] += 1
                elif r.get('size') is not None and l.get('size') is not None and int(r.get('size') or 0) != int(l.get('size') or 0):
                    status = 'modified_remote'
                    counts['modified_remote'] += 1
                else:
                    status = 'unchanged'
                    counts['unchanged'] += 1
            else:
                # not remote but present locally
                if l and l.get('last_synced_at'):
                    status = 'deleted_remote'
                    counts['deleted_remote'] += 1
                else:
                    status = 'local_only'
                    counts['local_only'] += 1

            entries.append({'path': path, 'status': status, 'remote': r, 'local': l})

        return {'counts': counts, 'entries': entries}

    async def pull_one(self, rel_path: str) -> Dict[str, Any]:
        """Pull a single remote file identified by rel_path into local save_path.
        Returns {'success': True, 'imported_db': bool} or {'success': False, 'error': str}
        """
        settings = await asyncio.to_thread(db.load_app_settings)
        webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
        url = webdav.get('url') if isinstance(webdav, dict) else ''
        if not url:
            return {'success': False, 'error': 'WebDAV url not configured'}

        user = webdav.get('username') or ''
        enc_pw = webdav.get('password') or ''
        try:
            pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
        except Exception:
            pw = enc_pw or ''
        auth = (user, pw) if user or pw else None
        remote_root = webdav.get('remote_path') or ''

        target_url = self._build_remote_url(url, remote_root, rel_path)

        client = self._create_async_client(60.0)
        async with client as client:
            try:
                resp = await self._request_with_retry(client, 'GET', target_url, auth=auth, timeout=120.0, max_attempts=3)
            except Exception as e:
                logger.exception('pull_one GET failed for %s: %s', rel_path, e)
                return {'success': False, 'error': f'get_error:{e}'}

            if resp is None or resp.status_code not in (200, 201):
                return {'success': False, 'error': f'get_status:{resp.status_code if resp is not None else "none"}'}

            # write to local path
            target_local = os.path.join(self.save_path, rel_path.replace('/', os.sep))
            os.makedirs(os.path.dirname(target_local), exist_ok=True)
            try:
                with open(target_local + '.tmp', 'wb') as fh:
                    fh.write(resp.content)
                os.replace(target_local + '.tmp', target_local)
            except Exception as e:
                logger.exception('pull_one write failed for %s: %s', rel_path, e)
                return {'success': False, 'error': f'write_error:{e}'}

            etag = resp.headers.get('ETag') or resp.headers.get('etag')
            now = datetime.utcnow().isoformat()
            await asyncio.to_thread(self._db_update_file_index_after_upload, rel_path, now, target_url, etag)

            imported_db = False
            if rel_path in ('db/coinscape.db', 'coinscape.db'):
                try:
                    data = await asyncio.to_thread(self._extract_data_from_sqlite_file, target_local)
                    if data:
                        await asyncio.to_thread(db.import_all_data, data)
                        imported_db = True
                except Exception as e:
                    logger.exception('pull_one db import failed: %s', e)
                    return {'success': False, 'error': f'db_import_error:{e}'}

            return {'success': True, 'imported_db': imported_db}

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

        # Use thread-safe DB helpers via asyncio.to_thread to avoid blocking event loop
        processed = 0
        succeeded = 0
        failed = 0

        client = self._create_async_client(60.0)
        async with client as client:
            while True:
                row = await asyncio.to_thread(self._db_fetch_pending_task)
                if not row:
                    break

                task_id = row['id']
                prev_attempts = int(row.get('attempts') or 0)
                if prev_attempts >= max_attempts:
                    # give up and mark as permanently failed
                    await asyncio.to_thread(self._db_mark_queue_failed, task_id, f'max_attempts_exceeded:{prev_attempts}')
                    failed += 1
                    processed += 1
                    continue

                rel_path = row['path']
                action = row['action']

                # mark in-progress (increments attempts)
                await asyncio.to_thread(self._db_mark_in_progress, task_id)

                try:
                    logger.debug('Processing task id=%s path=%s action=%s', task_id, rel_path, action)
                    if action == 'upload':
                        local = os.path.join(self.save_path, rel_path)
                        if not os.path.isfile(local):
                            # file missing locally, mark failed
                            await asyncio.to_thread(self._db_mark_queue_failed, task_id, 'local_missing')
                            failed += 1
                            processed += 1
                            continue

                        target_url = self._build_remote_url(url, remote_root, rel_path)

                        # construct temporary upload URL by appending .part suffix to the path
                        parsed = urlparse(target_url)
                        tmp_path = parsed.path + '.part'
                        tmp_url = urlunparse((parsed.scheme, parsed.netloc, tmp_path, '', '', ''))

                        # ensure parent dirs for tmp (and target) exist
                        try:
                            await self._ensure_remote_parent_dirs_async(client, tmp_url, auth)
                        except Exception as e:
                            logger.error('ensure_remote_parent_dirs failed for %s: %s', tmp_url, e, exc_info=True)

                        # read file in thread to avoid blocking
                        try:
                            data = await asyncio.to_thread(lambda: open(local, 'rb').read())
                        except Exception as e:
                            logger.error('Failed to read local file %s: %s', local, e, exc_info=True)
                            await asyncio.to_thread(self._db_mark_queue_failed, task_id, str(e))
                            failed += 1
                            processed += 1
                            continue

                        # upload to temporary path first (with retries)
                        try:
                            put_tmp = await self._request_with_retry(client, 'PUT', tmp_url, auth=auth, content=data, timeout=60.0, max_attempts=3)
                            logger.debug('PUT tmp response for %s: %s', rel_path, put_tmp.status_code if put_tmp is not None else 'none')
                        except Exception as e:
                            logger.exception('put_tmp failed for %s: %s', rel_path, e)
                            await asyncio.to_thread(self._db_mark_queue_failed, task_id, f'put_tmp_error:{e}')
                            failed += 1
                            processed += 1
                            continue

                        if put_tmp is not None and put_tmp.status_code in (200, 201, 204):
                            # attempt atomic MOVE from tmp -> target
                            move_headers = {'Destination': target_url, 'Overwrite': 'T'}
                            try:
                                try:
                                    move_resp = await self._request_with_retry(client, 'MOVE', tmp_url, headers=move_headers, auth=auth, timeout=60.0, max_attempts=3)
                                except Exception as e:
                                    move_resp = None
                                if move_resp is not None and move_resp.status_code in (200, 201, 204):
                                    # try to fetch ETag from target via HEAD, fallback to put_tmp's ETag
                                    etag = None
                                    try:
                                        head_resp = await self._request_with_retry(client, 'HEAD', target_url, auth=auth, timeout=30.0, max_attempts=2)
                                        if head_resp is not None and head_resp.status_code in (200, 201):
                                            etag = head_resp.headers.get('ETag') or head_resp.headers.get('etag')
                                    except Exception:
                                        pass
                                    if not etag:
                                        etag = put_tmp.headers.get('ETag') or put_tmp.headers.get('etag')

                                    now = datetime.utcnow().isoformat()
                                    await asyncio.to_thread(self._db_update_file_index_after_upload, rel_path, now, target_url, etag)
                                    await asyncio.to_thread(self._db_mark_queue_done, task_id)
                                    logger.info('Upload succeeded: %s (etag=%s)', rel_path, etag)
                                    succeeded += 1
                                else:
                                    # MOVE failed -> try fallback: PUT directly to target, then cleanup tmp
                                    try:
                                        try:
                                            put_final = await self._request_with_retry(client, 'PUT', target_url, auth=auth, content=data, timeout=60.0, max_attempts=3)
                                        except Exception as e:
                                            put_final = None
                                        if put_final is not None and put_final.status_code in (200, 201, 204):
                                            # attempt to delete tmp
                                            try:
                                                await self._request_with_retry(client, 'DELETE', tmp_url, auth=auth, timeout=30.0, max_attempts=2)
                                            except Exception:
                                                pass
                                            etag = put_final.headers.get('ETag') or put_final.headers.get('etag')
                                            now = datetime.utcnow().isoformat()
                                            await asyncio.to_thread(self._db_update_file_index_after_upload, rel_path, now, target_url, etag)
                                            await asyncio.to_thread(self._db_mark_queue_done, task_id)
                                            logger.info('Upload succeeded via fallback PUT: %s (etag=%s)', rel_path, etag)
                                            succeeded += 1
                                        else:
                                            # cleanup tmp and mark failed
                                            try:
                                                await self._request_with_retry(client, 'DELETE', tmp_url, auth=auth, timeout=30.0, max_attempts=2)
                                            except Exception:
                                                pass
                                            put_final_status = put_final.status_code if put_final is not None else 'none'
                                            err = f'move_failed:{move_resp.status_code}, put_target:{put_final_status}'
                                            await asyncio.to_thread(self._db_mark_queue_failed, task_id, err)
                                            logger.warning('Upload failed for %s: %s', rel_path, err)
                                            failed += 1
                                    except Exception as e:
                                        try:
                                            await self._request_with_retry(client, 'DELETE', tmp_url, auth=auth, timeout=30.0, max_attempts=2)
                                        except Exception:
                                            pass
                                        await asyncio.to_thread(self._db_mark_queue_failed, task_id, f'fallback_put_error:{e}')
                                        logger.exception('Fallback put failed for %s: %s', rel_path, e)
                                        failed += 1
                            except Exception as e:
                                # MOVE request failed entirely; try to cleanup tmp and mark failed
                                try:
                                    await self._request_with_retry(client, 'DELETE', tmp_url, auth=auth, timeout=30.0, max_attempts=2)
                                except Exception:
                                    pass
                                await asyncio.to_thread(self._db_mark_queue_failed, task_id, f'move_error:{e}')
                                logger.exception('MOVE error for %s: %s', rel_path, e)
                                failed += 1
                        else:
                            # tmp PUT failed -- try direct PUT to target as a fallback (with retry)
                            try:
                                try:
                                    put_final = await self._request_with_retry(client, 'PUT', target_url, auth=auth, content=data, timeout=60.0, max_attempts=3)
                                except Exception as e:
                                    put_final = None
                                if put_final is not None and put_final.status_code in (200, 201, 204):
                                    try:
                                        await self._request_with_retry(client, 'DELETE', tmp_url, auth=auth, timeout=30.0, max_attempts=2)
                                    except Exception:
                                        pass
                                    etag = put_final.headers.get('ETag') or put_final.headers.get('etag')
                                    now = datetime.utcnow().isoformat()
                                    await asyncio.to_thread(self._db_update_file_index_after_upload, rel_path, now, target_url, etag)
                                    await asyncio.to_thread(self._db_mark_queue_done, task_id)
                                    logger.info('Upload succeeded via direct PUT: %s (etag=%s)', rel_path, etag)
                                    succeeded += 1
                                else:
                                    put_final_status = put_final.status_code if put_final is not None else 'none'
                                    err = f'put_tmp_failed:{put_tmp.status_code}, put_target:{put_final_status}'
                                    await asyncio.to_thread(self._db_mark_queue_failed, task_id, err)
                                    logger.warning('Upload failed for %s: %s', rel_path, err)
                                    failed += 1
                            except Exception as e:
                                logger.exception('put_tmp failed and fallback put raised exception for %s: %s', rel_path, e)
                                await asyncio.to_thread(self._db_mark_queue_failed, task_id, f'put_tmp_error_and_fallback_failed:{e}')
                                failed += 1

                    elif action == 'delete':
                        target_url = self._build_remote_url(url, remote_root, rel_path)
                        try:
                            try:
                                resp = await self._request_with_retry(client, 'DELETE', target_url, auth=auth, timeout=60.0, max_attempts=3)
                            except Exception as e:
                                resp = None
                            # treat 200/204/404 as success (404 means already removed)
                            if resp is not None and resp.status_code in (200, 204, 404):
                                # remove index entry
                                await asyncio.to_thread(self._db_delete_index_entry, rel_path)
                                await asyncio.to_thread(self._db_mark_queue_done, task_id)
                                succeeded += 1
                            else:
                                status = resp.status_code if resp is not None else 'none'
                                err = f'delete_failed:{status}'
                                await asyncio.to_thread(self._db_mark_queue_failed, task_id, err)
                                failed += 1
                        except Exception as e:
                            logger.error('Error processing task id=%s path=%s: %s', task_id, rel_path, e, exc_info=True)
                            await asyncio.to_thread(self._db_mark_queue_failed, task_id, str(e))
                            failed += 1

                except Exception as e:
                    logger.error('Error processing task id=%s path=%s: %s', task_id, rel_path, e, exc_info=True)
                    await asyncio.to_thread(self._db_mark_queue_failed, task_id, str(e))
                    failed += 1

                processed += 1

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

    # --- Thread-safe DB helpers (synchronous, intended to be called via asyncio.to_thread) ---
    def _db_fetch_pending_task(self) -> Optional[Dict[str, Any]]:
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY id LIMIT 1")
        row = cur.fetchone()
        conn.close()
        return dict(row) if row else None

    def _db_mark_in_progress(self, task_id: int):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE sync_queue SET status = 'in-progress', attempts = attempts + 1, last_attempt_at = ? WHERE id = ?",
                    (datetime.utcnow().isoformat(), task_id))
        conn.commit()
        conn.close()

    def _db_mark_queue_done(self, task_id: int):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE sync_queue SET status = 'done', error = NULL WHERE id = ?", (task_id,))
        conn.commit()
        conn.close()

    def _db_mark_queue_failed(self, task_id: int, error: str):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE sync_queue SET status = 'failed', error = ? WHERE id = ?", (error, task_id))
        conn.commit()
        conn.close()

    def _db_update_file_index_after_upload(self, rel_path: str, last_synced_at: str, remote_path: str, remote_etag: Optional[str]):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE file_index SET last_synced_at = ?, remote_path = ?, remote_etag = ? WHERE path = ?",
                    (last_synced_at, remote_path, remote_etag, rel_path))
        conn.commit()
        conn.close()

    def _db_delete_index_entry(self, rel_path: str):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("DELETE FROM file_index WHERE path = ?", (rel_path,))
        conn.commit()
        conn.close()

    def _db_retry_failed(self):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("UPDATE sync_queue SET status = 'pending', error = NULL WHERE status = 'failed'")
        conn.commit()
        conn.close()

    def _db_clear_failed(self):
        conn = self._get_conn()
        cur = conn.cursor()
        cur.execute("DELETE FROM sync_queue WHERE status = 'failed'")
        conn.commit()
        conn.close()

    async def _request_with_retry(self, client: httpx.AsyncClient, method: str, url: str, *,
                                  auth: Optional[tuple] = None, headers: Optional[dict] = None,
                                  content: Optional[bytes] = None, timeout: Optional[float] = None,
                                  max_attempts: int = 3, backoff_factor: float = 0.5) -> httpx.Response:
        """Perform an HTTP request with simple exponential backoff retry for 5xx/429 errors and exceptions.
        Returns the final httpx.Response or raises the last exception if all attempts fail.
        """
        attempt = 1
        last_exc = None
        while attempt <= max_attempts:
            try:
                resp = await client.request(method, url, auth=auth, headers=headers, content=content, timeout=timeout)
                status = resp.status_code
                # Retry on server errors or 429 (rate limit)
                if status >= 500 or status == 429:
                    if attempt < max_attempts:
                        # If server provided Retry-After header and it's numeric, honor it
                        retry_after = None
                        try:
                            ra = resp.headers.get('Retry-After')
                            if ra:
                                # try parse integer seconds
                                try:
                                    retry_after = int(ra)
                                except Exception:
                                    # ignore non-integer Retry-After (could be HTTP date); fall back to backoff
                                    retry_after = None
                        except Exception:
                            retry_after = None

                        if retry_after is not None:
                            sleep_t = float(retry_after) + random.uniform(0, backoff_factor)
                        else:
                            sleep_t = backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, backoff_factor)

                        await asyncio.sleep(sleep_t)
                        attempt += 1
                        continue
                return resp
            except Exception as e:
                last_exc = e
                if attempt < max_attempts:
                    sleep_t = backoff_factor * (2 ** (attempt - 1)) + random.uniform(0, backoff_factor)
                    await asyncio.sleep(sleep_t)
                    attempt += 1
                    continue
                raise
        if last_exc:
            raise last_exc
        # Fallback: raise generic
        raise RuntimeError('Request failed without exception')

    def get_detailed_status(self, limit: int = 100) -> Dict[str, Any]:
        """Return a detailed status structure compatible with frontend expectations.
        Structure example:
        {
            'counts': {'pending': int, 'in_progress': int, 'failed': int, 'done': int},
            'in_progress': [ {id, path, action, attempts, error}, ... ],
            'failed': [ {id, path, action, attempts, error}, ... ],
            'pending_preview': [ {id, path, action}, ... ]
        }
        """
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

        # fetch rows
        cur.execute("SELECT id, path, action, attempts, error FROM sync_queue WHERE status = 'in-progress'")
        inprog_rows = [dict(r) for r in cur.fetchall()]
        cur.execute("SELECT id, path, action, attempts, error FROM sync_queue WHERE status = 'failed'")
        failed_rows = [dict(r) for r in cur.fetchall()]
        # pending preview (limit)
        cur.execute("SELECT id, path, action FROM sync_queue WHERE status = 'pending' ORDER BY id LIMIT ?", (limit,))
        pending_rows = [dict(r) for r in cur.fetchall()]

        conn.close()

        return {
            'counts': {'pending': pending, 'in_progress': inprog, 'failed': failed, 'done': done},
            'in_progress': inprog_rows,
            'failed': failed_rows,
            'pending_preview': pending_rows,
        }

    async def push_all(self, force: bool = False) -> Dict[str, Any]:
        # single-run guard
        if not self._lock.acquire(blocking=False):
            return {'started': False, 'reason': 'already_running'}
        try:
            logger.info('Starting file sync scan')
            # run scan in thread pool to avoid blocking event loop
            scan_summary = await asyncio.to_thread(self.scan_and_queue, force)
            # load webdav settings (offload to thread to avoid blocking)
            try:
                settings = await asyncio.to_thread(db.load_app_settings)
                webdav = settings.get('sync', {}).get('webdav', {}) if isinstance(settings.get('sync', {}), dict) else {}
            except Exception:
                webdav = {}

            proc = await self.process_queue(webdav)

            # Attempt to write a remote backup marker (timestamp) into WebDAV so other devices can see latest backup
            remote_marker_set = False
            last_cloud_backup = None
            try:
                # prefer using local last_local_change timestamp when available
                local_ts = None
                try:
                    local_ts = settings.get('sync', {}).get('last_local_change') if isinstance(settings.get('sync', {}), dict) else None
                except Exception:
                    local_ts = None

                iso_to_write = local_ts or datetime.utcnow().isoformat()
                try:
                    remote_marker_set = await self._write_remote_backup_marker(webdav, iso_to_write)
                except Exception:
                    remote_marker_set = False
                if remote_marker_set:
                    last_cloud_backup = iso_to_write
            except Exception:
                logger.exception('Failed to set remote backup marker')

            return {
                'started': True,
                'scan': scan_summary,
                'process': proc,
                'remote_marker_set': remote_marker_set,
                'last_cloud_backup': last_cloud_backup,
            }
        finally:
            self._lock.release()


# module-level manager
manager = FileSyncManager()
