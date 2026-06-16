"""
CoinScape Backend - SQLite Database Layer
==========================================
Handles all SQLite operations for the CoinScape app.
Data is stored in SAVE_PATH directory on the local filesystem.
"""

import sqlite3
import json
import os
import copy
try:
    from . import crypto
except Exception:
    import crypto
import shutil
from datetime import datetime
from typing import Optional, Dict, Any

# ============================================================
# CONFIG: config.json support for save_path
# ============================================================
_script_dir = os.path.dirname(os.path.abspath(__file__))
# No config.json support any more; respect env var or default path
SAVE_PATH = os.environ.get("COINSCAPE_SAVE_PATH") or os.path.join(_script_dir, "data")
# ============================================================

DB_DIR = os.path.join(SAVE_PATH, "db")
IMAGES_DIR = os.path.join(SAVE_PATH, "images")
FONTS_DIR = os.path.join(SAVE_PATH, "fonts")
DB_PATH = os.path.join(DB_DIR, "coinscape.db")


def ensure_dirs():
    """Create all required directories if they don't exist."""
    for d in [DB_DIR, IMAGES_DIR, FONTS_DIR]:
        os.makedirs(d, exist_ok=True)


def get_connection() -> sqlite3.Connection:
    """Get a SQLite connection with row factory enabled."""
    ensure_dirs()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """Initialize database tables."""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS series (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL
        );
        
        CREATE TABLE IF NOT EXISTS coins (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            year INTEGER,
            face_value REAL,
            material TEXT,
            weight REAL,
            diameter REAL,
            mintage TEXT,
            mint TEXT,
            grade TEXT,
            unit_price REAL,
            quantity INTEGER,
            quantity_unit TEXT,
            collection_time TEXT,
            created_at TEXT NOT NULL,
            comments TEXT,
            first_image_path TEXT
        );
        
        CREATE TABLE IF NOT EXISTS coin_images (
            id TEXT PRIMARY KEY,
            coin_id TEXT NOT NULL REFERENCES coins(id) ON DELETE CASCADE,
            image_path TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0
        );
        
        CREATE TABLE IF NOT EXISTS series_images (
            id TEXT PRIMARY KEY,
            series_id TEXT NOT NULL REFERENCES series(id) ON DELETE CASCADE,
            image_path TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0
        );
        
        CREATE TABLE IF NOT EXISTS coin_series_link (
            coin_id TEXT NOT NULL REFERENCES coins(id),
            series_id TEXT NOT NULL REFERENCES series(id),
            PRIMARY KEY (coin_id, series_id)
        );
    """)
    
    conn.commit()
    conn.close()


# ============================================================
# Generic CRUD helpers
# ============================================================

def fetch_all(table: str, order_by: Optional[str] = None) -> list[dict]:
    conn = get_connection()
    query = f"SELECT * FROM {table}"
    if order_by:
        query += f" ORDER BY {order_by}"
    rows = conn.execute(query).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def fetch_by_id(table: str, id: str) -> Optional[dict]:
    conn = get_connection()
    row = conn.execute(f"SELECT * FROM {table} WHERE id = ?", (id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def fetch_where(table: str, column: str, value: str) -> list[dict]:
    conn = get_connection()
    rows = conn.execute(f"SELECT * FROM {table} WHERE {column} = ?", (value,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def insert_row(table: str, data: dict):
    conn = get_connection()
    columns = ", ".join(data.keys())
    placeholders = ", ".join(["?"] * len(data))
    query = f"INSERT OR REPLACE INTO {table} ({columns}) VALUES ({placeholders})"
    conn.execute(query, list(data.values()))
    conn.commit()
    conn.close()


def delete_row(table: str, id: str):
    conn = get_connection()
    conn.execute(f"DELETE FROM {table} WHERE id = ?", (id,))
    conn.commit()
    conn.close()


def delete_where(table: str, column: str, value: str):
    conn = get_connection()
    conn.execute(f"DELETE FROM {table} WHERE {column} = ?", (value,))
    conn.commit()
    conn.close()


def execute_raw(query: str, params: list = None):
    conn = get_connection()
    if params:
        conn.execute(query, params)
    else:
        conn.execute(query)
    conn.commit()
    conn.close()


# ============================================================
# Series operations
# ============================================================

def get_all_series() -> list[dict]:
    return fetch_all("series", "created_at DESC")


def get_series(id: str) -> Optional[dict]:
    return fetch_by_id("series", id)


def save_series(data: dict):
    insert_row("series", data)


def delete_series(id: str):
    conn = get_connection()
    # Collect image paths for this series so we can delete files if unreferenced
    try:
        rows = conn.execute("SELECT image_path FROM series_images WHERE series_id = ?", (id,)).fetchall()
        img_paths = [r[0] for r in rows if r and r[0]]
        for p in set(img_paths):
            try:
                _delete_image_if_unreferenced(conn, p, exclude_series_id=id)
            except Exception:
                # best-effort: don't let file-delete failures block DB cleanup
                pass

        conn.execute("DELETE FROM coin_series_link WHERE series_id = ?", (id,))
        conn.execute("DELETE FROM series_images WHERE series_id = ?", (id,))
        conn.execute("DELETE FROM series WHERE id = ?", (id,))
        conn.commit()
    finally:
        conn.close()


# ============================================================
# Coin operations
# ============================================================

def get_all_coins() -> list[dict]:
    return fetch_all("coins", "collection_time DESC, created_at DESC")


def get_coins_by_series(series_id: str) -> list[dict]:
    conn = get_connection()
    rows = conn.execute("""
        SELECT c.* FROM coins c
        INNER JOIN coin_series_link l ON c.id = l.coin_id
        WHERE l.series_id = ?
        ORDER BY c.collection_time DESC, c.created_at DESC
    """, (series_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_coin(id: str) -> Optional[dict]:
    return fetch_by_id("coins", id)


def save_coin(data: dict):
    insert_row("coins", data)


def delete_coin(id: str):
    conn = get_connection()
    # Collect image paths for this coin (including first_image_path) so we can delete files if unreferenced
    try:
        rows = conn.execute("SELECT image_path FROM coin_images WHERE coin_id = ?", (id,)).fetchall()
        img_paths = [r[0] for r in rows if r and r[0]]
        coin_row = conn.execute("SELECT first_image_path FROM coins WHERE id = ?", (id,)).fetchone()
        if coin_row and coin_row[0]:
            img_paths.append(coin_row[0])

        for p in set([x for x in img_paths if x]):
            try:
                _delete_image_if_unreferenced(conn, p, exclude_coin_id=id)
            except Exception:
                # best-effort
                pass

        conn.execute("DELETE FROM coin_images WHERE coin_id = ?", (id,))
        conn.execute("DELETE FROM coin_series_link WHERE coin_id = ?", (id,))
        conn.execute("DELETE FROM coins WHERE id = ?", (id,))
        conn.commit()
    finally:
        conn.close()


# ============================================================
# Link operations
# ============================================================

def get_series_ids_for_coin(coin_id: str) -> list[str]:
    conn = get_connection()
    rows = conn.execute("SELECT series_id FROM coin_series_link WHERE coin_id = ?", (coin_id,)).fetchall()
    conn.close()
    return [r["series_id"] for r in rows]


def link_coin_to_series(coin_id: str, series_id: str):
    conn = get_connection()
    conn.execute("INSERT OR IGNORE INTO coin_series_link (coin_id, series_id) VALUES (?, ?)", (coin_id, series_id))
    conn.commit()
    conn.close()


def unlink_coin_from_series(coin_id: str, series_id: str):
    conn = get_connection()
    conn.execute("DELETE FROM coin_series_link WHERE coin_id = ? AND series_id = ?", (coin_id, series_id))
    conn.commit()
    conn.close()


def set_coin_series_tags(coin_id: str, series_ids: list[str]):
    conn = get_connection()
    conn.execute("DELETE FROM coin_series_link WHERE coin_id = ?", (coin_id,))
    for sid in series_ids:
        conn.execute("INSERT OR IGNORE INTO coin_series_link (coin_id, series_id) VALUES (?, ?)", (coin_id, sid))
    conn.commit()
    conn.close()


def add_coins_to_series(coin_ids: list[str], series_ids: list[str]):
    conn = get_connection()
    for cid in coin_ids:
        for sid in series_ids:
            conn.execute("INSERT OR IGNORE INTO coin_series_link (coin_id, series_id) VALUES (?, ?)", (cid, sid))
    conn.commit()
    conn.close()


def remove_coins_from_all_series(coin_ids: list[str]):
    conn = get_connection()
    for cid in coin_ids:
        conn.execute("DELETE FROM coin_series_link WHERE coin_id = ?", (cid,))
    conn.commit()
    conn.close()


# ============================================================
# Image operations
# ============================================================

def _normalize_db_image_path(image_path: Optional[str]) -> Optional[str]:
    """Normalize a stored DB image path to a filesystem-relative filename.

    Returns None for paths that should not be handled (e.g. base64 data).
    """
    if not image_path or not isinstance(image_path, str):
        return None
    # ignore base64 inline data
    if image_path.startswith('base64:'):
        return None
    normalized = image_path.replace('\\', '/').lstrip('/')
    if normalized.startswith('images/'):
        normalized = normalized[len('images/'):]
    return normalized


def _fs_path_for_db_path(image_path: str) -> Optional[str]:
    n = _normalize_db_image_path(image_path)
    if not n:
        return None
    return os.path.join(IMAGES_DIR, n)


def _delete_image_if_unreferenced(conn: sqlite3.Connection, image_path: str, exclude_coin_id: str = None, exclude_series_id: str = None):
    """Attempt to delete an image file if no other DB records reference it.

    This is best-effort and will not raise on failure.
    """
    try:
        other = 0
        if exclude_coin_id:
            other += conn.execute("SELECT COUNT(*) FROM coin_images WHERE image_path = ? AND coin_id != ?", (image_path, exclude_coin_id)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM series_images WHERE image_path = ?", (image_path,)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM coins WHERE first_image_path = ? AND id != ?", (image_path, exclude_coin_id)).fetchone()[0]
        elif exclude_series_id:
            other += conn.execute("SELECT COUNT(*) FROM series_images WHERE image_path = ? AND series_id != ?", (image_path, exclude_series_id)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM coin_images WHERE image_path = ?", (image_path,)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM coins WHERE first_image_path = ?", (image_path,)).fetchone()[0]
        else:
            other += conn.execute("SELECT COUNT(*) FROM coin_images WHERE image_path = ?", (image_path,)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM series_images WHERE image_path = ?", (image_path,)).fetchone()[0]
            other += conn.execute("SELECT COUNT(*) FROM coins WHERE first_image_path = ?", (image_path,)).fetchone()[0]

        if other == 0:
            fs_path = _fs_path_for_db_path(image_path)
            if fs_path and os.path.isfile(fs_path):
                try:
                    os.remove(fs_path)
                except Exception:
                    pass

            # try removing thumbnail cache entries for this image
            try:
                cache_dir = os.path.join(IMAGES_DIR, ".thumb_cache")
                if os.path.isdir(cache_dir) and fs_path:
                    base = os.path.splitext(os.path.basename(fs_path))[0]
                    for fname in os.listdir(cache_dir):
                        if fname.startswith(base + "_") or fname.startswith(base):
                            try:
                                os.remove(os.path.join(cache_dir, fname))
                            except Exception:
                                pass
            except Exception:
                pass
    except Exception:
        # swallow all exceptions - deletion is best-effort
        pass

def cleanup_orphan_files() -> dict:
    """Scan IMAGES_DIR and delete files not referenced by any DB record.

    Also cleans orphan thumbnails from .thumb_cache.

    Returns a summary dict with counts.
    """
    conn = get_connection()
    try:
        # Collect all referenced image paths from the DB
        referenced = set()

        rows = conn.execute("SELECT image_path FROM coin_images").fetchall()
        for r in rows:
            if r[0]:
                referenced.add(r[0])

        rows = conn.execute("SELECT image_path FROM series_images").fetchall()
        for r in rows:
            if r[0]:
                referenced.add(r[0])

        rows = conn.execute("SELECT first_image_path FROM coins WHERE first_image_path IS NOT NULL AND first_image_path != ''").fetchall()
        for r in rows:
            if r[0]:
                referenced.add(r[0])

        # Normalize referenced set to bare filenames (strip images/ prefix)
        referenced_bare = set()
        for p in referenced:
            n = _normalize_db_image_path(p)
            if n:
                referenced_bare.add(n.lower())
    finally:
        conn.close()

    deleted_files = 0
    total_scanned = 0

    # Scan images directory
    if os.path.isdir(IMAGES_DIR):
        for fname in os.listdir(IMAGES_DIR):
            fpath = os.path.join(IMAGES_DIR, fname)
            if not os.path.isfile(fpath):
                continue
            if fname.startswith('.'):
                continue
            total_scanned += 1
            if fname.lower() not in referenced_bare:
                try:
                    os.remove(fpath)
                    deleted_files += 1
                except Exception:
                    pass

    # Clean orphan thumbnails
    deleted_thumbs = 0
    cache_dir = os.path.join(IMAGES_DIR, ".thumb_cache")
    if os.path.isdir(cache_dir):
        # Build set of base names that are still referenced
        referenced_bases = set()
        for bare in referenced_bare:
            referenced_bases.add(os.path.splitext(bare)[0].lower())

        for fname in os.listdir(cache_dir):
            fpath = os.path.join(cache_dir, fname)
            if not os.path.isfile(fpath):
                continue
            # thumbnail name is like <base>_<WxH>.<ext> or <base>.<ext>
            thumb_base = fname.split('_')[0].lower()
            thumb_base_no_ext = os.path.splitext(thumb_base)[0]
            if thumb_base_no_ext not in referenced_bases:
                try:
                    os.remove(fpath)
                    deleted_thumbs += 1
                except Exception:
                    pass

    return {
        'deleted_files': deleted_files,
        'deleted_thumbs': deleted_thumbs,
        'total_scanned': total_scanned,
        'referenced_count': len(referenced_bare),
    }


def get_coin_images(coin_id: str) -> list[dict]:
    return fetch_where("coin_images", "coin_id", coin_id)


def replace_coin_images(coin_id: str, image_paths: list[str]):
    conn = get_connection()
    conn.execute("DELETE FROM coin_images WHERE coin_id = ?", (coin_id,))
    for i, path in enumerate(image_paths):
        img_id = f"coin_img_{coin_id}_{i}"
        conn.execute(
            "INSERT OR REPLACE INTO coin_images (id, coin_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
            (img_id, coin_id, path, i)
        )
    conn.execute("UPDATE coins SET first_image_path = ? WHERE id = ?",
                 (image_paths[0] if image_paths else None, coin_id))
    conn.commit()
    conn.close()


def get_series_images(series_id: str) -> list[dict]:
    return fetch_where("series_images", "series_id", series_id)


def replace_series_images(series_id: str, image_paths: list[str]):
    conn = get_connection()
    conn.execute("DELETE FROM series_images WHERE series_id = ?", (series_id,))
    for i, path in enumerate(image_paths):
        img_id = f"series_img_{series_id}_{i}"
        conn.execute(
            "INSERT OR REPLACE INTO series_images (id, series_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
            (img_id, series_id, path, i)
        )
    conn.commit()
    conn.close()


# ============================================================
# Backup / Restore
# ============================================================

def export_all_data() -> dict:
    """Export all data as a JSON-serializable dict."""
    data = {
        "series": get_all_series(),
        "coins": get_all_coins(),
        "links": fetch_all("coin_series_link"),
        "coinImages": fetch_all("coin_images"),
        "seriesImages": fetch_all("series_images"),
    }

    # Include settings (mask sensitive fields)
    try:
        settings = load_app_settings()
        settings_copy = copy.deepcopy(settings)
        # Mask webdav password
        try:
            if isinstance(settings_copy.get('sync'), dict):
                webdav = settings_copy['sync'].get('webdav') if isinstance(settings_copy['sync'].get('webdav'), dict) else None
                if webdav is not None:
                    if 'password' in webdav:
                        webdav['password'] = ''
        except Exception:
            pass
        data['settings'] = settings_copy
    except Exception:
        data['settings'] = {}

    return data


def import_all_data(data: dict):
    """Import data from a dict (overwrites existing data)."""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Clear all tables
    cursor.execute("DELETE FROM coin_series_link")
    cursor.execute("DELETE FROM coin_images")
    cursor.execute("DELETE FROM series_images")
    cursor.execute("DELETE FROM coins")
    cursor.execute("DELETE FROM series")
    
    # Import series
    for s in data.get("series", []):
        cursor.execute(
            "INSERT INTO series (id, name, description, created_at) VALUES (?, ?, ?, ?)",
            (s["id"], s["name"], s.get("description"), s.get("created_at", datetime.now().isoformat()))
        )
    
    # Import coins
    for c in data.get("coins", []):
        cursor.execute("""
            INSERT INTO coins (id, name, year, face_value, material, weight, diameter,
                               mintage, mint, grade, unit_price, quantity, quantity_unit,
                               collection_time, created_at, comments, first_image_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            c["id"], c["name"], c.get("year"), c.get("face_value"),
            c.get("material"), c.get("weight"), c.get("diameter"),
            c.get("mintage"), c.get("mint"), c.get("grade"),
            c.get("unit_price"), c.get("quantity"), c.get("quantity_unit"),
            c.get("collection_time"), c.get("created_at", datetime.now().isoformat()),
            c.get("comments"), c.get("first_image_path")
        ))
    
    # Import links
    for l in data.get("links", []):
        cursor.execute(
            "INSERT OR IGNORE INTO coin_series_link (coin_id, series_id) VALUES (?, ?)",
            (l["coin_id"], l["series_id"])
        )
    
    # Import coin images
    for img in data.get("coinImages", []):
        cursor.execute(
            "INSERT OR REPLACE INTO coin_images (id, coin_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
            (img["id"], img["coin_id"], img["image_path"], img.get("sort_order", 0))
        )
    
    # Import series images
    for img in data.get("seriesImages", []):
        cursor.execute(
            "INSERT OR REPLACE INTO series_images (id, series_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
            (img["id"], img["series_id"], img["image_path"], img.get("sort_order", 0))
)
    
    conn.commit()
    conn.close()


def import_merge_data(data: dict, policy: str = 'prefer_local'):
    """Merge import from `data` into existing DB.

    policy:
      - 'prefer_local' (default): keep existing local rows, only insert missing rows from remote.
      - 'prefer_remote': overwrite local rows with remote values.
      - 'merge_fields': for each column, prefer local value unless empty/NULL, then use remote.
    This function never deletes local rows that are missing from the import; it only inserts or updates.
    """
    conn = get_connection()
    cur = conn.cursor()

    def _coalesce(a, b):
        return a if a not in (None, '') else b

    # Series
    for s in data.get('series', []):
        sid = s.get('id')
        if not sid:
            continue
        cur.execute("SELECT * FROM series WHERE id = ?", (sid,))
        existing = cur.fetchone()
        if not existing:
            cur.execute(
                "INSERT INTO series (id, name, description, created_at) VALUES (?, ?, ?, ?)",
                (sid, s.get('name'), s.get('description'), s.get('created_at') or datetime.now().isoformat())
            )
        else:
            if policy == 'prefer_remote':
                cur.execute(
                    "UPDATE series SET name = ?, description = ?, created_at = ? WHERE id = ?",
                    (s.get('name'), s.get('description'), s.get('created_at') or existing['created_at'], sid)
                )
            elif policy == 'merge_fields':
                name = _coalesce(existing['name'], s.get('name'))
                description = _coalesce(existing['description'], s.get('description'))
                created_at = _coalesce(existing['created_at'], s.get('created_at') or existing['created_at'])
                cur.execute(
                    "UPDATE series SET name = ?, description = ?, created_at = ? WHERE id = ?",
                    (name, description, created_at, sid)
                )
            # prefer_local -> do nothing

    # Coins
    coin_cols = [
        'id', 'name', 'year', 'face_value', 'material', 'weight', 'diameter', 'mintage', 'mint', 'grade',
        'unit_price', 'quantity', 'quantity_unit', 'collection_time', 'created_at', 'comments', 'first_image_path'
    ]
    for c in data.get('coins', []):
        cid = c.get('id')
        if not cid:
            continue
        cur.execute("SELECT * FROM coins WHERE id = ?", (cid,))
        existing = cur.fetchone()
        if not existing:
            values = [c.get(col) for col in coin_cols]
            # ensure created_at
            if not values[14]:
                values[14] = datetime.now().isoformat()
            placeholders = ','.join(['?'] * len(coin_cols))
            cur.execute(f"INSERT INTO coins ({','.join(coin_cols)}) VALUES ({placeholders})", tuple(values))
        else:
            if policy == 'prefer_remote':
                values = [c.get(col) for col in coin_cols[1:]]  # exclude id
                set_clause = ','.join([f"{col} = ?" for col in coin_cols[1:]])
                cur.execute(f"UPDATE coins SET {set_clause} WHERE id = ?", tuple(values + [cid]))
            elif policy == 'merge_fields':
                updates = []
                params = []
                for col in coin_cols[1:]:
                    local_val = existing[col]
                    remote_val = c.get(col)
                    chosen = local_val if local_val not in (None, '') else remote_val
                    updates.append(f"{col} = ?")
                    params.append(chosen)
                params.append(cid)
                cur.execute(f"UPDATE coins SET {', '.join(updates)} WHERE id = ?", tuple(params))
            # prefer_local -> do nothing

    # Links (coin_series_link) - insert remote links, do not delete local links
    for l in data.get('links', []):
        try:
            cur.execute("INSERT OR IGNORE INTO coin_series_link (coin_id, series_id) VALUES (?, ?)", (l.get('coin_id'), l.get('series_id')))
        except Exception:
            pass

    # Coin images
    for img in data.get('coinImages', []):
        iid = img.get('id')
        if not iid:
            continue
        cur.execute("SELECT * FROM coin_images WHERE id = ?", (iid,))
        existing = cur.fetchone()
        if not existing:
            cur.execute(
                "INSERT OR REPLACE INTO coin_images (id, coin_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
                (iid, img.get('coin_id'), img.get('image_path'), img.get('sort_order', 0))
            )
        else:
            if policy == 'prefer_remote':
                cur.execute(
                    "UPDATE coin_images SET coin_id = ?, image_path = ?, sort_order = ? WHERE id = ?",
                    (img.get('coin_id'), img.get('image_path'), img.get('sort_order', 0), iid)
                )
            elif policy == 'merge_fields':
                coin_id = _coalesce(existing['coin_id'], img.get('coin_id'))
                image_path = _coalesce(existing['image_path'], img.get('image_path'))
                sort_order = existing['sort_order'] if existing['sort_order'] not in (None, '') else img.get('sort_order', 0)
                cur.execute(
                    "UPDATE coin_images SET coin_id = ?, image_path = ?, sort_order = ? WHERE id = ?",
                    (coin_id, image_path, sort_order, iid)
                )

    # Series images
    for img in data.get('seriesImages', []):
        iid = img.get('id')
        if not iid:
            continue
        cur.execute("SELECT * FROM series_images WHERE id = ?", (iid,))
        existing = cur.fetchone()
        if not existing:
            cur.execute(
                "INSERT OR REPLACE INTO series_images (id, series_id, image_path, sort_order) VALUES (?, ?, ?, ?)",
                (iid, img.get('series_id'), img.get('image_path'), img.get('sort_order', 0))
            )
        else:
            if policy == 'prefer_remote':
                cur.execute(
                    "UPDATE series_images SET series_id = ?, image_path = ?, sort_order = ? WHERE id = ?",
                    (img.get('series_id'), img.get('image_path'), img.get('sort_order', 0), iid)
                )
            elif policy == 'merge_fields':
                series_id = _coalesce(existing['series_id'], img.get('series_id'))
                image_path = _coalesce(existing['image_path'], img.get('image_path'))
                sort_order = existing['sort_order'] if existing['sort_order'] not in (None, '') else img.get('sort_order', 0)
                cur.execute(
                    "UPDATE series_images SET series_id = ?, image_path = ?, sort_order = ? WHERE id = ?",
                    (series_id, image_path, sort_order, iid)
                )

    conn.commit()
    conn.close()


# ============================================================
# Settings management
# ============================================================

SETTINGS_FILE = os.path.join(SAVE_PATH, "app_settings.json")

def load_app_settings() -> Dict[str, Any]:
    """Load application settings from settings.json file."""
    if os.path.isfile(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                settings = json.load(f)

            # Migrate plaintext WebDAV password -> encrypted format if necessary
            try:
                sync_cfg = settings.get('sync', {})
                webdav = sync_cfg.get('webdav', {}) if isinstance(sync_cfg, dict) else {}
                pw = webdav.get('password') if isinstance(webdav, dict) else None
                changed = False
                if isinstance(pw, str) and pw and not pw.startswith('enc:'):
                    # encrypt and save
                    settings.setdefault('sync', {}).setdefault('webdav', {})
                    settings['sync']['webdav']['password'] = crypto.encrypt_string(pw)
                    changed = True

                # Ensure auth section exists
                auth = settings.get('auth')
                if not auth or not isinstance(auth, dict) or 'password_hash' not in auth:
                    settings.setdefault('auth', {})
                    if 'username' not in settings['auth']:
                        settings['auth']['username'] = 'admin'
                    if 'password_hash' not in settings['auth']:
                        settings['auth']['password_hash'] = crypto.hash_password('coinscape')
                    changed = True

                if changed:
                    save_app_settings(settings)

            except Exception:
                # migration should not break reading settings
                pass

            return settings
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading settings: {e}")
    
    # Return default settings
    return {
        "appearance": {
            "theme": "system",
            "font_family": "default",
            "font_size": 14,
            "density": "comfortable"
        },
        "behavior": {
            "auto_save": True,
            "confirm_deletions": True,
            "show_tutorial": True
        },
        "export": {
            "default_format": "pdf",
            "include_images": True,
            "compress_pdf": False
        },
        "sync": {
            "auto_sync": False,
            "sync_interval": 3600,
            "webdav": {
                "enabled": False,
                "url": "",
                "username": "",
                "password": "",
                "remote_path": ""
                },
                "merge_policy": "prefer_local"
        },
        "backend": {
            "save_path": None,
            "service_address": "http://localhost:9876",
            "log_level": "INFO",
            "proxy_enabled": False
        }
        ,
        "auth": {
            "username": "admin",
            "password_hash": crypto.hash_password('coinscape')
        }
    }

def save_app_settings(settings: Dict[str, Any]):
    """Save application settings to settings.json file."""
    ensure_dirs()
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)

def update_app_settings(updates: Dict[str, Any]) -> Dict[str, Any]:
    """Update specific settings and return the full updated settings."""
    current = load_app_settings()

    # Deep merge updates
    def deep_merge(target: Dict[str, Any], source: Dict[str, Any]) -> Dict[str, Any]:
        for key, value in source.items():
            if key in target and isinstance(target[key], dict) and isinstance(value, dict):
                target[key] = deep_merge(target[key], value)
            else:
                target[key] = value
        return target

    updated = deep_merge(current, updates)

    # Handle WebDAV password: if caller provided a (non-empty) plaintext password, encrypt it;
    # if provided but empty, preserve existing password; if not provided, keep as-is.
    try:
        if isinstance(updates, dict) and 'sync' in updates and isinstance(updates['sync'], dict):
            webdav_updates = updates['sync'].get('webdav') if isinstance(updates['sync'].get('webdav'), dict) else None
            if webdav_updates is not None and 'password' in webdav_updates:
                new_pw = webdav_updates.get('password')
                # preserve existing if empty or null
                if new_pw:
                    updated.setdefault('sync', {}).setdefault('webdav', {})
                    updated['sync']['webdav']['password'] = crypto.encrypt_string(new_pw)
                else:
                    # restore previous encrypted password if present
                    prev_pw = current.get('sync', {}).get('webdav', {}).get('password')
                    if prev_pw:
                        updated.setdefault('sync', {}).setdefault('webdav', {})
                        updated['sync']['webdav']['password'] = prev_pw
                    else:
                        # ensure absence
                        if 'password' in updated.get('sync', {}).get('webdav', {}):
                            updated['sync']['webdav'].pop('password', None)
    except Exception:
        pass

    # Handle auth password changes: accept plaintext 'auth.password' in updates and store hashed form
    try:
        if isinstance(updates, dict) and 'auth' in updates and isinstance(updates['auth'], dict):
            auth_updates = updates['auth']
            if 'password' in auth_updates:
                new_auth_pw = auth_updates.get('password')
                if new_auth_pw:
                    updated.setdefault('auth', {})
                    updated['auth']['password_hash'] = crypto.hash_password(new_auth_pw)
                # remove any plaintext password field before saving
                if 'password' in updated.get('auth', {}):
                    updated['auth'].pop('password', None)
            # allow username update
            if 'username' in auth_updates:
                updated.setdefault('auth', {})
                updated['auth']['username'] = auth_updates.get('username')
    except Exception:
        pass

    save_app_settings(updated)
    return updated


def get_timeline_metadata() -> dict:
    """返回按月分桶的时间线元数据：total, buckets(list), bucket_map(dict)

    每个 bucket 包含: key(YYYY-MM), year, month, count, start_index, start_ts, end_ts
    """
    conn = get_connection()
    try:
        query = """
            SELECT strftime('%Y-%m', coalesce(collection_time, created_at)) AS ym,
                   COUNT(*) AS cnt,
                   MIN(coalesce(collection_time, created_at)) AS start_ts,
                   MAX(coalesce(collection_time, created_at)) AS end_ts
            FROM coins
            GROUP BY ym
            ORDER BY ym DESC
        """
        rows = conn.execute(query).fetchall()
        buckets = []
        start_idx = 0
        bucket_map = {}
        total = 0
        for i, r in enumerate(rows):
            ym = r['ym'] if isinstance(r['ym'], str) else str(r[0])
            cnt = int(r['cnt'])
            start_ts_s = r['start_ts']
            end_ts_s = r['end_ts']

            def _to_ts(s):
                if not s:
                    return 0
                try:
                    dt = datetime.fromisoformat(s)
                    return int(dt.timestamp())
                except Exception:
                    try:
                        dt = datetime.strptime(s, '%Y-%m-%d %H:%M:%S')
                        return int(dt.timestamp())
                    except Exception:
                        return 0

            start_ts = _to_ts(start_ts_s)
            end_ts = _to_ts(end_ts_s)

            year = int(ym[:4]) if len(ym) >= 7 else 0
            month = int(ym[5:7]) if len(ym) >= 7 else 0
            bucket = {
                'key': ym,
                'year': year,
                'month': month,
                'count': cnt,
                'start_index': start_idx,
                'start_ts': start_ts,
                'end_ts': end_ts,
            }
            buckets.append(bucket)
            bucket_map[ym] = i
            start_idx += cnt
            total += cnt

        return {'total': total, 'buckets': buckets, 'bucket_map': bucket_map}
    finally:
        conn.close()
