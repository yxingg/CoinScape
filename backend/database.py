"""
CoinScape Backend - SQLite Database Layer
==========================================
Handles all SQLite operations for the CoinScape app.
Data is stored in SAVE_PATH directory on the local filesystem.
"""

import sqlite3
import json
import os
import shutil
from datetime import datetime
from typing import Optional

# ============================================================
# CONFIG: config.json support for save_path
# ============================================================
_script_dir = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(_script_dir, "config.json")


def load_config() -> dict:
    """Load config from config.json, return empty dict if not exists."""
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {}


def save_config(config: dict):
    """Save config to config.json."""
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)


def get_save_path() -> str:
    """Get save path: env var > config.json > default."""
    env_path = os.environ.get("COINSCAPE_SAVE_PATH")
    if env_path:
        return env_path
    cfg = load_config()
    cfg_path = cfg.get("save_path")
    if cfg_path:
        return cfg_path
    return os.path.join(_script_dir, "data")


SAVE_PATH = get_save_path()
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
    conn.execute("DELETE FROM coin_series_link WHERE series_id = ?", (id,))
    conn.execute("DELETE FROM series_images WHERE series_id = ?", (id,))
    conn.execute("DELETE FROM series WHERE id = ?", (id,))
    conn.commit()
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
    conn.execute("DELETE FROM coin_images WHERE coin_id = ?", (id,))
    conn.execute("DELETE FROM coin_series_link WHERE coin_id = ?", (id,))
    conn.execute("DELETE FROM coins WHERE id = ?", (id,))
    conn.commit()
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
    return {
        "series": get_all_series(),
        "coins": get_all_coins(),
        "links": fetch_all("coin_series_link"),
        "coinImages": fetch_all("coin_images"),
        "seriesImages": fetch_all("series_images"),
    }


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
