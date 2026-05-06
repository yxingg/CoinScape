"""
CoinScape Backend - FastAPI Server
===================================
Provides REST API for the CoinScape Flutter Web app.
Also serves the built Flutter web static files.

Usage:
    python main.py
    # Or: uvicorn main:app --host 0.0.0.0 --port 8080
    
To change data directory, set environment variable:
    set COINSCAPE_SAVE_PATH=D:/my_coinscape_data
    python main.py
"""

import os
import json
import shutil
import uuid
import logging
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Body
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

import database as db

_script_dir = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# Logging setup
# ============================================================

LOG_DIR = os.path.join(_script_dir, "data")
LOG_FILE_PATH = os.path.join(LOG_DIR, "coinscape.log")


def setup_logging() -> None:
    os.makedirs(LOG_DIR, exist_ok=True)

    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)

    formatter = logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")

    file_handler = logging.FileHandler(LOG_FILE_PATH, encoding="utf-8")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)

    root_logger.handlers.clear()
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)

    logging.getLogger("coinscape").info("日志文件路径: %s", os.path.abspath(LOG_FILE_PATH))


setup_logging()
logger = logging.getLogger("coinscape")

# ============================================================
# App setup
# ============================================================

app = FastAPI(title="CoinScape Backend", version="1.0.0")

# CORS - allow Flutter web dev server
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Health check (must be before static file routes)
# ============================================================

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "save_path": db.SAVE_PATH}


@app.get("/api/config")
async def get_config():
    return {
        "save_path": db.SAVE_PATH,
        "config_file": db.CONFIG_PATH,
    }


@app.put("/api/config")
async def update_config(data: dict = Body(...)):
    """Update backend config (save_path, etc.). Requires restart to take effect."""
    cfg = db.load_config()
    if "save_path" in data:
        cfg["save_path"] = data["save_path"]
    db.save_config(cfg)
    return {
        "success": True,
        "message": "配置已保存，重启服务器后生效",
        "save_path": cfg.get("save_path", db.SAVE_PATH),
    }


# ============================================================
# Series API
# ============================================================

@app.get("/api/series")
async def list_series():
    return db.get_all_series()


@app.get("/api/series/{series_id}")
async def get_series(series_id: str):
    s = db.get_series(series_id)
    if not s:
        raise HTTPException(status_code=404, detail="Series not found")
    return s


@app.post("/api/series")
async def create_series(data: dict = Body(...)):
    if "id" not in data:
        data["id"] = str(uuid.uuid4())
    if "created_at" not in data:
        data["created_at"] = datetime.now().isoformat()
    db.save_series(data)
    return {"success": True, "id": data["id"]}


@app.put("/api/series/{series_id}")
async def update_series(series_id: str, data: dict = Body(...)):
    data["id"] = series_id
    db.save_series(data)
    return {"success": True}


@app.delete("/api/series/{series_id}")
async def delete_series(series_id: str):
    db.delete_series(series_id)
    return {"success": True}


@app.post("/api/series/batch-delete")
async def delete_series_batch(data: dict = Body(...)):
    ids = data.get("ids", [])
    for sid in ids:
        db.delete_series(sid)
    return {"success": True}


# ============================================================
# Coins API
# ============================================================

@app.get("/api/coins")
async def list_coins(series_id: Optional[str] = None):
    if series_id:
        return db.get_coins_by_series(series_id)
    return db.get_all_coins()


@app.get("/api/coins/{coin_id}")
async def get_coin(coin_id: str):
    c = db.get_coin(coin_id)
    if not c:
        raise HTTPException(status_code=404, detail="Coin not found")
    return c


@app.post("/api/coins")
async def create_coin(data: dict = Body(...)):
    if "id" not in data:
        data["id"] = str(uuid.uuid4())
    if "created_at" not in data:
        data["created_at"] = datetime.now().isoformat()
    db.save_coin(data)
    return {"success": True, "id": data["id"]}


@app.put("/api/coins/{coin_id}")
async def update_coin(coin_id: str, data: dict = Body(...)):
    data["id"] = coin_id
    db.save_coin(data)
    return {"success": True}


@app.delete("/api/coins/{coin_id}")
async def delete_coin(coin_id: str):
    db.delete_coin(coin_id)
    return {"success": True}


@app.post("/api/coins/batch-delete")
async def delete_coins_batch(data: dict = Body(...)):
    ids = data.get("ids", [])
    for cid in ids:
        db.delete_coin(cid)
    return {"success": True}


# ============================================================
# Coin-Series Link API
# ============================================================

@app.get("/api/links/{coin_id}")
async def get_coin_series_ids(coin_id: str):
    return {"series_ids": db.get_series_ids_for_coin(coin_id)}


@app.post("/api/links")
async def link_coin_to_series(data: dict = Body(...)):
    db.link_coin_to_series(data["coin_id"], data["series_id"])
    return {"success": True}


@app.delete("/api/links")
async def unlink_coin_from_series(coin_id: str, series_id: str):
    db.unlink_coin_from_series(coin_id, series_id)
    return {"success": True}


@app.post("/api/links/set-tags")
async def set_coin_series_tags(data: dict = Body(...)):
    db.set_coin_series_tags(data["coin_id"], data["series_ids"])
    return {"success": True}


@app.post("/api/links/batch-add")
async def add_coins_to_series(data: dict = Body(...)):
    db.add_coins_to_series(data["coin_ids"], data["series_ids"])
    return {"success": True}


@app.post("/api/links/batch-remove")
async def remove_coins_from_all_series(data: dict = Body(...)):
    db.remove_coins_from_all_series(data["coin_ids"])
    return {"success": True}


# ============================================================
# Images API
# ============================================================

@app.get("/api/images/coin/{coin_id}")
async def get_coin_images(coin_id: str):
    return db.get_coin_images(coin_id)


@app.post("/api/images/coin/{coin_id}")
async def replace_coin_images(coin_id: str, data: dict = Body(...)):
    db.replace_coin_images(coin_id, data.get("image_paths", []))
    return {"success": True}


@app.get("/api/images/series/{series_id}")
async def get_series_images(series_id: str):
    return db.get_series_images(series_id)


@app.post("/api/images/series/{series_id}")
async def replace_series_images(series_id: str, data: dict = Body(...)):
    db.replace_series_images(series_id, data.get("image_paths", []))
    return {"success": True}


@app.post("/api/images/upload")
async def upload_image(file: UploadFile = File(...)):
    """Upload an image file and return its path."""
    db.ensure_dirs()
    ext = os.path.splitext(file.filename or "image.jpg")[1] or ".jpg"
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(db.IMAGES_DIR, filename)
    
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)
    
    return {"path": f"images/{filename}"}


@app.get("/api/images/file/{filename:path}")
async def get_image_file(filename: str):
    """Serve an uploaded image file."""
    normalized = filename.replace('\\', '/').lstrip('/')
    if normalized.startswith('images/'):
        normalized = normalized[len('images/'):]
    filepath = os.path.join(db.IMAGES_DIR, normalized)
    if not os.path.isfile(filepath):
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(filepath)


# ============================================================
# Fonts API
# ============================================================

@app.get("/api/fonts/{font_id}")
async def get_font(font_id: str):
    """Get a font file by its ID."""
    filepath = os.path.join(db.FONTS_DIR, f"{font_id}.ttf")
    if not os.path.isfile(filepath):
        raise HTTPException(status_code=404, detail="Font not found")
    return FileResponse(filepath, media_type="font/ttf")


@app.post("/api/fonts/upload")
async def upload_font(file: UploadFile = File(...)):
    """Upload a font file and return its ID."""
    db.ensure_dirs()
    font_id = f"custom_{datetime.now().timestamp()}"
    filepath = os.path.join(db.FONTS_DIR, f"{font_id}.ttf")
    
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)
    
    return {"font_id": font_id}


@app.get("/api/fonts/check/{font_id}")
async def check_font(font_id: str):
    """Check if a font exists."""
    filepath = os.path.join(db.FONTS_DIR, f"{font_id}.ttf")
    return {"exists": os.path.isfile(filepath)}


@app.delete("/api/fonts/{font_id}")
async def delete_font(font_id: str):
    """Delete a font file."""
    filepath = os.path.join(db.FONTS_DIR, f"{font_id}.ttf")
    if os.path.isfile(filepath):
        os.remove(filepath)
    return {"success": True}


# ============================================================
# Backup / Restore API
# ============================================================

@app.get("/api/backup/export")
async def export_data():
    """Export all data as JSON."""
    return db.export_all_data()


@app.post("/api/backup/import")
async def import_data(data: dict = Body(...)):
    """Import all data from JSON."""
    db.import_all_data(data)
    return {"success": True}


# ============================================================
# Static files (Flutter Web build output) - mounted AFTER API routes
# ============================================================

_script_dir = os.path.dirname(os.path.abspath(__file__))
_web_build_dir = os.path.join(_script_dir, "..", "build", "web")
_web_build_dir = os.path.normpath(_web_build_dir)

if os.path.isdir(_web_build_dir):
    @app.get("/{full_path:path}")
    async def serve_static(full_path: str):
        """Serve static files, fallback to index.html for SPA routing."""
        # Don't intercept API routes
        if full_path.startswith("api/"):
            raise HTTPException(status_code=404, detail="API route not found")
        
        file_path = os.path.join(_web_build_dir, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        
        # SPA fallback
        index_path = os.path.join(_web_build_dir, "index.html")
        if os.path.isfile(index_path):
            return FileResponse(index_path)
        
        raise HTTPException(status_code=404, detail="Not found")
    
    @app.get("/")
    async def serve_root():
        index_path = os.path.join(_web_build_dir, "index.html")
        if os.path.isfile(index_path):
            return FileResponse(index_path)
        return JSONResponse({"error": "Web build not found. Run 'flutter build web --web-renderer canvaskit' first."})
else:
    print(f"WARNING: Web build directory not found at {_web_build_dir}")
    print("Please run 'flutter build web --web-renderer canvaskit' first.")


# ============================================================
# Startup
# ============================================================

@app.on_event("startup")
async def startup():
    db.init_db()
    print(f"CoinScape Backend started")
    print(f"  Data directory: {db.SAVE_PATH}")
    print(f"  Database: {db.DB_PATH}")
    print(f"  Images: {db.IMAGES_DIR}")
    print(f"  Fonts: {db.FONTS_DIR}")
    if os.path.isdir(_web_build_dir):
        print(f"  Web static: {_web_build_dir}")


# ============================================================
# Entry point
# ============================================================

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("COINSCAPE_PORT", "9876"))
    host = os.environ.get("COINSCAPE_HOST", "0.0.0.0")
    
    print(f"Starting CoinScape server at http://{host}:{port}")
    print(f"Set COINSCAPE_SAVE_PATH env var to change data directory")
    print(f"  Current SAVE_PATH: {db.SAVE_PATH}")
    print()
    
    uvicorn.run(app, host=host, port=port)
