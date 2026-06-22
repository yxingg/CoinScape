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
import hashlib
import logging
import logging.handlers
import base64  # 添加base64导入
from datetime import datetime
from typing import Optional, Dict, List
from urllib.parse import urlparse, quote

import httpx
import asyncio
import random
import socket
import sys
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Body, Request
from fastapi.responses import FileResponse, JSONResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

# Support running `python main.py` (script) and `python -m backend.main` (module)
try:
    from . import database as db
    from . import crypto
    from . import file_sync
except Exception:
    # Fallback to plain imports when executed as a script (no package context)
    import database as db
    import crypto
    import file_sync

_script_dir = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# Logging setup
# ============================================================

LOG_DIR = os.path.join(_script_dir, "data")
LOG_FILE_PATH = os.path.join(LOG_DIR, "coinscape.log")


def setup_logging() -> None:
    """
    设置Python日志系统，包含异常捕获和日志轮转
    """
    os.makedirs(LOG_DIR, exist_ok=True)

    root_logger = logging.getLogger()
    # 从应用设置读取日志级别（默认 INFO）
    try:
        app_settings = db.load_app_settings()
        lvl = app_settings.get("backend", {}).get("log_level", "INFO")
    except Exception:
        lvl = "INFO"
    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR,
        "CRITICAL": logging.CRITICAL,
    }
    chosen_level = level_map.get(str(lvl).upper(), logging.INFO)
    root_logger.setLevel(chosen_level)

    # 自定义Formatter，包含模块前缀
    class CoinScapeFormatter(logging.Formatter):
        def format(self, record: logging.LogRecord) -> str:
            # 从logger名称中提取模块名
            logger_name = record.name
            if logger_name == "coinscape":
                module = "[MAIN]"
            elif "." in logger_name:
                module_parts = logger_name.split(".")
                if len(module_parts) > 1:
                    module = f"[{module_parts[-1].upper()}]"
                else:
                    module = f"[{module_parts[0].upper()}]"
            else:
                module = f"[{logger_name.upper()}]"
            
            # 格式化日志消息
            record.message = record.getMessage()
            record.asctime = self.formatTime(record, self.datefmt)
            
            # 构建最终的日志行
            level_str = record.levelname
            if hasattr(record, 'exc_info') and record.exc_info:
                exc_type, exc_value, exc_traceback = record.exc_info
                if exc_type and exc_value:
                    record.exc_text = f"Exception: {exc_type.__name__}: {exc_value}"
            
            return f"{record.asctime} {level_str:<8} {module} {record.message}"

    formatter = CoinScapeFormatter("%(asctime)s", datefmt="%Y-%m-%d %H:%M:%S")

    # 文件处理器 - 使用RotatingFileHandler实现日志轮转
    try:
        # 最大10MB，最多保留5个备份文件
        file_handler = logging.handlers.RotatingFileHandler(
            LOG_FILE_PATH, 
            encoding="utf-8",
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5
        )
        file_handler.setLevel(chosen_level)
        file_handler.setFormatter(formatter)
    except Exception as e:
        # 如果文件日志失败，只使用控制台
        print(f"无法初始化文件日志: {e}")
        file_handler = None

    # 控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setLevel(chosen_level)
    console_handler.setFormatter(formatter)

    # 清除现有处理器，添加新的
    root_logger.handlers.clear()
    
    if file_handler:
        root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)

    # 为coinscape日志器设置额外配置
    app_logger = logging.getLogger("coinscape")
    app_logger.setLevel(chosen_level)
    
    # 设置全局异常钩子
    import sys
    sys.excepthook = _handle_uncaught_exception
    
    app_logger.info("日志系统初始化完成 (level=%s)", logging.getLevelName(chosen_level))
    if file_handler:
        app_logger.info("日志文件路径: %s", os.path.abspath(LOG_FILE_PATH))
    else:
        app_logger.warning("日志文件未启用，仅输出到控制台")


def _handle_uncaught_exception(exc_type, exc_value, exc_traceback):
    """
    处理未捕获的异常，记录到日志中
    """
    if issubclass(exc_type, KeyboardInterrupt):
        # 如果是KeyboardInterrupt，使用默认处理
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return
    
    logger = logging.getLogger("coinscape.exception")
    logger.error(
        f"未捕获的异常: {exc_type.__name__}: {exc_value}",
        exc_info=(exc_type, exc_value, exc_traceback)
    )
    
    # 仍然打印到stderr
    sys.__excepthook__(exc_type, exc_value, exc_traceback)


# ============================================================
# FastAPI全局异常处理器
# ============================================================

def add_exception_handlers_to_app(app):
    """
    为FastAPI应用添加全局异常处理器
    """
    import traceback
    
    @app.exception_handler(Exception)
    async def general_exception_handler(request, exc):
        """
        处理所有未捕获的异常
        """
        logger = logging.getLogger("coinscape.api.exception")
        exc_type = type(exc).__name__
        exc_message = str(exc)
        exc_traceback = traceback.format_exc()
        
        logger.error(
            f"API异常 - {exc_type}: {exc_message}\n请求: {request.method} {request.url}\n{traceback.format_exc()}",
            extra={'exc_info': False}  # 不重复记录堆栈
        )
        
        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "message": f"服务器内部错误: {exc_message}",
                "error_type": exc_type,
                "detail": "查看服务器日志获取详细信息"
            }
        )


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

# 为应用添加全局异常处理器
# 注意: add_exception_handlers_to_app函数需要在app创建后调用

# ============================================================
# Health check (must be before static file routes)
# ============================================================

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "save_path": db.SAVE_PATH}




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
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True, "id": data["id"]}


@app.put("/api/series/{series_id}")
async def update_series(series_id: str, data: dict = Body(...)):
    data["id"] = series_id
    db.save_series(data)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.delete("/api/series/{series_id}")
async def delete_series(series_id: str):
    db.delete_series(series_id)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/series/batch-delete")
async def delete_series_batch(data: dict = Body(...)):
    ids = data.get("ids", [])
    for sid in ids:
        db.delete_series(sid)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}
# ============================================================
# Timeline metadata (用于前端 Skeleton-first 的按月元数据接口)
@app.get("/api/timeline/metadata")
async def timeline_metadata():
    try:
        return db.get_timeline_metadata()
    except Exception as e:
        logger.exception("Failed to build timeline metadata: %s", e)
        raise HTTPException(status_code=500, detail="Failed to build timeline metadata")


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
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True, "id": data["id"]}


@app.put("/api/coins/{coin_id}")
async def update_coin(coin_id: str, data: dict = Body(...)):
    data["id"] = coin_id
    db.save_coin(data)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.delete("/api/coins/{coin_id}")
async def delete_coin(coin_id: str):
    db.delete_coin(coin_id)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/coins/batch-delete")
async def delete_coins_batch(data: dict = Body(...)):
    ids = data.get("ids", [])
    for cid in ids:
        db.delete_coin(cid)
    try:
        _mark_local_change()
    except Exception:
        pass
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
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.delete("/api/links")
async def unlink_coin_from_series(coin_id: str, series_id: str):
    db.unlink_coin_from_series(coin_id, series_id)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/links/set-tags")
async def set_coin_series_tags(data: dict = Body(...)):
    db.set_coin_series_tags(data["coin_id"], data["series_ids"])
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/links/batch-add")
async def add_coins_to_series(data: dict = Body(...)):
    db.add_coins_to_series(data["coin_ids"], data["series_ids"])
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/links/batch-remove")
async def remove_coins_from_all_series(data: dict = Body(...)):
    db.remove_coins_from_all_series(data["coin_ids"])
    try:
        _mark_local_change()
    except Exception:
        pass
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
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.get("/api/images/series/{series_id}")
async def get_series_images(series_id: str):
    return db.get_series_images(series_id)


@app.post("/api/images/series/{series_id}")
async def replace_series_images(series_id: str, data: dict = Body(...)):
    db.replace_series_images(series_id, data.get("image_paths", []))
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


@app.post("/api/images/upload")
async def upload_image(file: UploadFile = File(...)):
    """Upload an image file and return its path. Uses MD5-based filename for dedup."""
    db.ensure_dirs()
    ext = os.path.splitext(file.filename or "image.jpg")[1] or ".jpg"
    content = await file.read()

    md5_hex = hashlib.md5(content).hexdigest()
    filename = f"{md5_hex}{ext}"
    filepath = os.path.join(db.IMAGES_DIR, filename)

    if not os.path.isfile(filepath):
        with open(filepath, "wb") as f:
            f.write(content)

    try:
        _mark_local_change()
    except Exception:
        pass

    return {"path": f"images/{filename}"}


@app.get("/api/images/file/{filename:path}")
async def get_image_file(filename: str, width: Optional[int] = None, height: Optional[int] = None):
    """Serve an uploaded image file with optional resize for thumbnails.

    Query params:
        width:  Target width in pixels (optional)
        height: Target height in pixels (optional)
    When width/height are provided, the server returns a resized image
    (aspect-ratio preserved) with aggressive cache headers.
    """
    normalized = filename.replace('\\', '/').lstrip('/')
    if normalized.startswith('images/'):
        normalized = normalized[len('images/'):]
    filepath = os.path.join(db.IMAGES_DIR, normalized)
    if not os.path.isfile(filepath):
        raise HTTPException(status_code=404, detail="Image not found")

    if width is not None or height is not None:
        try:
            from PIL import Image as PILImage
            import io

            cache_dir = os.path.join(db.IMAGES_DIR, ".thumb_cache")
            os.makedirs(cache_dir, exist_ok=True)

            w = width or 0
            h = height or 0
            cache_key = f"{os.path.splitext(normalized)[0]}_{w}x{h}{os.path.splitext(normalized)[1]}"
            cache_path = os.path.join(cache_dir, cache_key)

            if not os.path.isfile(cache_path):
                with PILImage.open(filepath) as img:
                    orig_w, orig_h = img.size
                    if width and height:
                        target_w, target_h = width, height
                    elif width:
                        ratio = width / orig_w
                        target_w, target_h = width, int(orig_h * ratio)
                    else:
                        ratio = height / orig_h
                        target_w, target_h = int(orig_w * ratio), height

                    resized = img.resize((target_w, target_h), PILImage.LANCZOS)
                    buf = io.BytesIO()
                    fmt = img.format or "JPEG"
                    if fmt.upper() == "JPG":
                        fmt = "JPEG"
                    resized.save(buf, format=fmt, quality=85)
                    buf.seek(0)
                    with open(cache_path, "wb") as f:
                        f.write(buf.getvalue())

            return FileResponse(
                cache_path,
                headers={
                    "Cache-Control": "public, max-age=86400, immutable",
                },
            )
        except ImportError:
            pass
        except Exception:
            pass

    return FileResponse(
        filepath,
        headers={
            "Cache-Control": "public, max-age=3600",
        },
    )


@app.post("/api/cleanup/orphan-files")
async def cleanup_orphan_files():
    """Scan images directory and delete files not referenced by any DB record."""
    try:
        result = await asyncio.to_thread(db.cleanup_orphan_files)
        try:
            _mark_local_change()
        except Exception:
            pass
        return JSONResponse({"success": True, "result": result})
    except Exception as e:
        logger = logging.getLogger("coinscape.cleanup")
        logger.exception("cleanup_orphan_files failed")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Fonts API
# ============================================================

@app.get("/api/fonts/")
async def list_fonts():
    """List all available font files."""
    db.ensure_dirs()
    fonts = []
    if os.path.exists(db.FONTS_DIR):
        for filename in os.listdir(db.FONTS_DIR):
            if filename.lower().endswith(('.ttf', '.otf')):
                filepath = os.path.join(db.FONTS_DIR, filename)
                stat = os.stat(filepath)
                font_id = os.path.splitext(filename)[0]
                fonts.append({
                    "id": font_id,
                    "filename": filename,
                    "size": stat.st_size,
                    "modified_at": stat.st_mtime,
                    "filepath": f"/api/fonts/{font_id}"
                })
    return {"fonts": sorted(fonts, key=lambda x: x["modified_at"], reverse=True)}


@app.get("/api/fonts/{font_id}")
async def get_font(font_id: str):
    """Get a font file by its ID."""
    # 尝试不同扩展名
    for ext in ['.ttf', '.otf']:
        filepath = os.path.join(db.FONTS_DIR, f"{font_id}{ext}")
        if os.path.isfile(filepath):
            return FileResponse(filepath, media_type="font/ttf" if ext == '.ttf' else "font/otf")
    raise HTTPException(status_code=404, detail="Font not found")


@app.post("/api/fonts/upload")
async def upload_font(file: UploadFile = File(...)):
    """Upload a font file and return its ID."""
    db.ensure_dirs()
    
    # 获取原始文件名并安全化
    original_name = file.filename or "font"
    safe_name = "".join(c for c in original_name if c.isalnum() or c in ('-', '_', '.')).rstrip()
    
    # 提取文件名（不含扩展名）和扩展名
    name_without_ext = os.path.splitext(safe_name)[0]
    ext = os.path.splitext(safe_name)[1].lower()
    if ext not in ['.ttf', '.otf']:
        ext = '.ttf'  # 默认使用.ttf
    
    # 使用原始文件名（不含扩展名）作为字体ID
    font_id = name_without_ext
    
    # 如果已存在同名字体，添加序号后缀避免覆盖
    filepath = os.path.join(db.FONTS_DIR, f"{font_id}{ext}")
    counter = 1
    while os.path.isfile(filepath):
        font_id = f"{name_without_ext}_{counter}"
        filepath = os.path.join(db.FONTS_DIR, f"{font_id}{ext}")
        counter += 1
    
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)
    # record local change for sync marker
    try:
        _mark_local_change()
    except Exception:
        pass

    return {"font_id": font_id, "filename": f"{font_id}{ext}", "original_name": original_name}


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
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True}


# ============================================================
# Application Settings API
# ============================================================

@app.get("/api/settings")
async def get_settings():
    """Get all application settings."""
    settings = await asyncio.to_thread(db.load_app_settings)
    # 计算本地/云端最近修改来源（非持久化、仅用于前端显示）
    try:
        sync = settings.get('sync') if isinstance(settings.get('sync'), dict) else {}
        last_local = sync.get('last_local_change')

        # 尝试从 WebDAV 读取远端备份标记文件
        last_cloud = None
        try:
            webdav_cfg = sync.get('webdav') if isinstance(sync.get('webdav'), dict) else {}
            if webdav_cfg.get('enabled') and webdav_cfg.get('url'):
                user = webdav_cfg.get('username') or ''
                enc_pw = webdav_cfg.get('password') or ''
                try:
                    pw = crypto.decrypt_string(enc_pw) if enc_pw else ''
                except Exception:
                    pw = enc_pw or ''
                auth = (user, pw) if user or pw else None
                remote_root = webdav_cfg.get('remote_path') or ''
                meta_rel = '.coinscape/last_cloud_backup.txt'
                try:
                    target_url = file_sync.manager._build_remote_url(webdav_cfg.get('url'), remote_root, meta_rel)
                    client_kwargs = {'timeout': 10.0, 'trust_env': False}
                    try:
                        client = httpx.AsyncClient(**{**client_kwargs, 'follow_redirects': True})
                    except TypeError:
                        try:
                            client = httpx.AsyncClient(**{**client_kwargs, 'allow_redirects': True})
                        except TypeError:
                            client = httpx.AsyncClient(**client_kwargs)
                    async with client as client:
                        resp = await client.get(target_url, auth=auth)
                        if resp.status_code in (200, 201):
                            # try parse JSON metadata; fall back to plain ISO text for backward compatibility
                            try:
                                j = resp.json()
                                if isinstance(j, dict) and 'timestamp' in j:
                                    last_cloud = j.get('timestamp')
                                elif isinstance(j, dict) and 'timestamp' not in j and 'time' in j:
                                    last_cloud = j.get('time')
                                else:
                                    # fallback to plain text
                                    text = (resp.text or '').strip()
                                    if text:
                                        last_cloud = text
                            except Exception:
                                text = (resp.text or '').strip()
                                if text:
                                    last_cloud = text
                except Exception:
                    logging.getLogger('coinscape.sync').exception('Failed to fetch remote backup marker')

        except Exception:
            last_cloud = None

        def _parse_iso(s: str):
            try:
                return datetime.fromisoformat(s) if s else None
            except Exception:
                return None

        local_dt = _parse_iso(last_local)
        cloud_dt = _parse_iso(last_cloud)

        latest_source = None
        latest_time = None
        if local_dt and cloud_dt:
            if local_dt > cloud_dt:
                latest_source = 'local'
                latest_time = last_local
            elif cloud_dt > local_dt:
                latest_source = 'cloud'
                latest_time = last_cloud
            else:
                latest_source = 'equal'
                latest_time = last_local
        elif local_dt:
            latest_source = 'local'
            latest_time = last_local
        elif cloud_dt:
            latest_source = 'cloud'
            latest_time = last_cloud

        settings.setdefault('sync', {})
        settings['sync']['latest_change_source'] = latest_source
        settings['sync']['latest_change_time'] = latest_time
    except Exception:
        # 不应阻塞设置读取
        pass

    return settings


def _mark_local_change():
    """记录本地最后一次更改时间到 settings.sync.last_local_change（UTC isoformat）。"""
    try:
        now = datetime.utcnow().isoformat()
        try:
            loop = asyncio.get_running_loop()
            # schedule update in thread pool to avoid blocking
            loop.create_task(asyncio.to_thread(db.update_app_settings, {'sync': {'last_local_change': now}}))
        except RuntimeError:
            # no running loop; fallback to synchronous update
            db.update_app_settings({'sync': {'last_local_change': now}})
    except Exception:
        logging.getLogger("coinscape.sync").exception("Failed to record last_local_change")


@app.post("/api/auth/login")
async def auth_login(data: dict = Body(...)):
    """Simple authentication endpoint: verify username/password against stored hash."""
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        raise HTTPException(status_code=400, detail="username and password required")

    settings = await asyncio.to_thread(db.load_app_settings)
    auth = settings.get('auth', {}) if isinstance(settings, dict) else {}
    stored_user = auth.get('username')
    stored_hash = auth.get('password_hash')
    if not stored_user or not stored_hash:
        raise HTTPException(status_code=500, detail="Authentication not configured")

    if username == stored_user and crypto.verify_password(password, stored_hash):
        return {"success": True}
    raise HTTPException(status_code=401, detail="Invalid credentials")


@app.put("/api/settings")
async def update_settings(data: dict = Body(...)):
    """Update application settings."""
    updated = await asyncio.to_thread(db.update_app_settings, data)
    try:
        _mark_local_change()
    except Exception:
        pass
    return {"success": True, "settings": updated}


@app.patch("/api/settings/{category}")
async def update_settings_category(category: str, data: dict = Body(...)):
    """Update settings for a specific category."""
    # 确保类别是有效的
    valid_categories = ["appearance", "behavior", "export", "sync"]
    if category not in valid_categories:
        raise HTTPException(status_code=400, detail=f"Invalid category. Must be one of: {valid_categories}")
    
    current = await asyncio.to_thread(db.load_app_settings)
    if category not in current:
        current[category] = {}
    
    # 合并更新
    for key, value in data.items():
        current[category][key] = value

    # 记录本地更改时间
    try:
        current.setdefault('sync', {})
        current['sync']['last_local_change'] = datetime.utcnow().isoformat()
    except Exception:
        pass

    await asyncio.to_thread(db.save_app_settings, current)
    return {"success": True, "settings": current}


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


@app.post("/api/backup/import_local_db")
async def import_local_db():
    """Scan local data directory for coinscape.db files and import the first valid one found."""
    try:
        settings = await asyncio.to_thread(db.load_app_settings)
        save_path = settings.get('backend', {}).get('save_path') or db.SAVE_PATH
        imported = False
        source = ''
        for candidate_rel in ('coinscape.db', 'db/coinscape.db'):
            candidate_path = os.path.join(save_path, candidate_rel.replace('/', os.sep))
            if os.path.isfile(candidate_path):
                try:
                    data = await asyncio.to_thread(file_sync.manager._extract_data_from_sqlite_file, candidate_path)
                    if data and (data.get('series') or data.get('coins')):
                        await asyncio.to_thread(db.import_all_data, data)
                        imported = True
                        source = candidate_rel
                        # Clean up staging copy (not the working DB)
                        if candidate_rel != 'db/coinscape.db':
                            try:
                                os.remove(candidate_path)
                            except Exception:
                                pass
                        break
                except Exception:
                    continue
        # Also check .ccm files
        if not imported:
            try:
                for fname in os.listdir(save_path):
                    if fname.endswith('.ccm'):
                        ccm_path = os.path.join(save_path, fname)
                        data = await asyncio.to_thread(file_sync.manager._extract_data_from_ccm, ccm_path)
                        if data and (data.get('series') or data.get('coins')):
                            await asyncio.to_thread(db.import_all_data, data)
                            imported = True
                            source = fname
                            try:
                                os.remove(ccm_path)
                            except Exception:
                                pass
                            break
            except Exception:
                pass
        return JSONResponse({"success": imported, "source": source})
    except Exception as e:
        logger = logging.getLogger("coinscape.backup")
        logger.exception("import_local_db failed")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# File sync (incremental images and data files) API
# ============================================================


@app.post("/api/sync/files/push")
async def api_push_files(data: dict = Body(None)):
    """Trigger scanning and incremental push to WebDAV. Accepts optional JSON body `{"force": true}` to force full upload of all files."""
    try:
        force = False
        if isinstance(data, dict):
            force = bool(data.get('force', False))
        res = await file_sync.manager.push_all(force=force)
        return JSONResponse({"success": True, "result": res})
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("push failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/sync/files/status")
async def api_sync_status():
    try:
        # Return a detailed structure (counts + lists) so frontend can render queues
        if hasattr(file_sync.manager, 'get_detailed_status'):
            st = await asyncio.to_thread(file_sync.manager.get_detailed_status)
        else:
            st = await asyncio.to_thread(file_sync.manager.get_status)
        return JSONResponse({"success": True, "status": st})
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("status check failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/sync/files/retry_failed")
async def api_retry_failed(data: dict = Body(None)):
    """Retry or clear failed sync queue entries.
    POST body `{ "clear": true }` will delete failed rows; default behaviour will mark failed rows pending and trigger a push.
    """
    try:
        clear = False
        if isinstance(data, dict):
            clear = bool(data.get('clear', False))

        if clear:
            await asyncio.to_thread(file_sync.manager._db_clear_failed)
            return JSONResponse({"success": True, "cleared": True})
        else:
            await asyncio.to_thread(file_sync.manager._db_retry_failed)
            res = await file_sync.manager.push_all()
            return JSONResponse({"success": True, "result": res})
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("retry_failed failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/sync/files/pull")
async def api_pull_files(data: dict = Body(None)):
    """Trigger server-side file-level pull from WebDAV and import.
    This will download remote files into backend save_path and import DB if present.
    """
    try:
        res = await file_sync.manager.pull_all()
        return JSONResponse({"success": True, "result": res})
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("pull failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/sync/files/preview_pull")
async def api_preview_pull():
    """Return a preview/diff of remote files vs local index without applying changes."""
    try:
        res = await file_sync.manager.preview_pull()
        return JSONResponse({"success": True, "preview": res})
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("preview_pull failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/sync/files/pull_one")
async def api_pull_one(data: dict = Body(...)):
    """Pull a single file from remote into backend save_path. POST body: {"path":"db/coinscape.db"} """
    try:
        if not isinstance(data, dict) or 'path' not in data:
            raise HTTPException(status_code=400, detail='path required')
        path = data.get('path')
        res = await file_sync.manager.pull_one(path)
        return JSONResponse({"success": True, "result": res})
    except HTTPException:
        raise
    except Exception as e:
        logger = logging.getLogger("coinscape.file_sync.api")
        logger.exception("pull_one failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/upload/chunk")
async def upload_chunk(file: UploadFile = File(...), fileId: str = Form(...), index: int = Form(...)):
    """接收单个分块（multipart/form-data），保存到后端临时分块目录。"""
    try:
        settings = await asyncio.to_thread(db.load_app_settings)
        save_path = settings.get('backend', {}).get('save_path') or db.SAVE_PATH
        tmp_dir = os.path.join(save_path, 'uploads', fileId)
        os.makedirs(tmp_dir, exist_ok=True)

        # 保持分块按序排序，使用固定宽度序号文件名
        part_name = f"{int(index):06d}.part"
        part_path = os.path.join(tmp_dir, part_name)
        content = await file.read()
        with open(part_path, 'wb') as f:
            f.write(content)

        return JSONResponse({"success": True, "index": index})
    except Exception as e:
        logger = logging.getLogger("coinscape.upload")
        logger.exception("upload chunk failed")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/upload/complete")
async def complete_upload(fileId: str = Form(...), filename: str = Form(...), overwrite: bool = Form(False)):
    """合并分块并将最终文件写入后端 `backend.save_path` 下的 files 目录（原子替换）。"""
    try:
        settings = await asyncio.to_thread(db.load_app_settings)
        save_path = settings.get('backend', {}).get('save_path') or db.SAVE_PATH
        tmp_dir = os.path.join(save_path, 'uploads', fileId)
        if not os.path.isdir(tmp_dir):
            raise HTTPException(status_code=404, detail="upload id not found")

        safe_name = os.path.basename(filename) or f"{fileId}"
        dest_dir = os.path.join(save_path, 'files')
        os.makedirs(dest_dir, exist_ok=True)
        dest_path = os.path.join(dest_dir, safe_name)

        if os.path.exists(dest_path) and not overwrite:
            raise HTTPException(status_code=409, detail="file exists")

        parts = sorted([p for p in os.listdir(tmp_dir) if p.endswith('.part')])
        if not parts:
            raise HTTPException(status_code=400, detail="no parts uploaded")

        tmp_final = os.path.join(tmp_dir, 'final.tmp')
        with open(tmp_final, 'wb') as out_f:
            for p in parts:
                ppath = os.path.join(tmp_dir, p)
                with open(ppath, 'rb') as pf:
                    shutil.copyfileobj(pf, out_f)

        # 原子移动到目标路径
        shutil.move(tmp_final, dest_path)

        # 清理临时目录
        try:
            shutil.rmtree(tmp_dir)
        except Exception:
            pass

        rel_path = os.path.relpath(dest_path, save_path)
        # mark local change (successful file now present in save_path)
        try:
            _mark_local_change()
        except Exception:
            pass
        return JSONResponse({"success": True, "path": rel_path})
    except HTTPException:
        raise
    except Exception as e:
        logger = logging.getLogger("coinscape.upload")
        logger.exception("complete upload failed")
        raise HTTPException(status_code=500, detail=str(e))
    



# ============================================================
# WebDAV Proxy API (解决Flutter Web跨域问题)
# ============================================================



# 使用app.add_route来支持任意HTTP方法
# FastAPI的api_route可能对非标准方法支持有限
async def proxy_webdav_handler(request: Request):
    # Check whether proxy is enabled in settings
    try:
        settings = await asyncio.to_thread(db.load_app_settings)
        backend_cfg = settings.get('backend', {}) if isinstance(settings, dict) else {}
        proxy_enabled = backend_cfg.get('proxy_enabled') if isinstance(backend_cfg, dict) else None
        if proxy_enabled in (False, None):
            # Also fallback to sync.webdav.enabled
            sync_cfg = settings.get('sync', {}) if isinstance(settings, dict) else {}
            webdav = sync_cfg.get('webdav', {}) if isinstance(sync_cfg, dict) else {}
            proxy_enabled = webdav.get('enabled', False)
    except Exception:
        proxy_enabled = False

    # If proxy is disabled, log and continue to proxy the request
    if not proxy_enabled:
        logger = logging.getLogger("coinscape.proxy")
        logger.info("Proxy is disabled in settings, but forwarding request to target to avoid client errors.")

    return await proxy_webdav_impl(request)

# 为每个WebDAV方法注册路由
# 使用路径参数来捕获WebDAV路径：/api/proxy/webdav/{webdav_path:path}
webdav_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PROPFIND", "PROPPATCH", "MKCOL", "COPY", "MOVE", "LOCK", "UNLOCK"]

# 根据设置决定是否在启动时注册代理路由（禁用时不注册，需重启生效）
try:
    settings_for_routes = db.load_app_settings()
    backend_cfg_for_routes = settings_for_routes.get('backend', {}) if isinstance(settings_for_routes, dict) else {}
    register_proxy = backend_cfg_for_routes.get('proxy_enabled', False) or settings_for_routes.get('sync', {}).get('webdav', {}).get('enabled', False)
except Exception:
    register_proxy = False

if register_proxy:
    for method in webdav_methods:
        app.add_route("/api/proxy/webdav/{webdav_path:path}", proxy_webdav_handler, methods=[method])
        app.add_route("/api/proxy/webdav", proxy_webdav_handler, methods=[method])
else:
    logger = logging.getLogger("coinscape.proxy")
    logger.info("WebDAV proxy routes not registered (disabled in settings). Restart required to change this.)")

# 实际的代理实现函数
async def proxy_webdav_impl(request: Request):
    """
    代理WebDAV请求，解决Flutter Web跨域问题。
    前端将真正的WebDAV地址作为query参数target传递。
    """
    logger = logging.getLogger("coinscape.proxy")
    
    # 记录调试信息
    logger.debug(f"Proxy request: method={request.method}, url={request.url}")
    logger.debug(f"Path: {request.url.path}, query: {request.url.query}")
    
    # 获取目标地址和认证信息
    target_url = request.query_params.get("target")
    username = request.query_params.get("user")
    password = request.query_params.get("password")
    
    # 如果客户端没有提供认证信息，尝试从后端设置中读取已保存的 WebDAV 凭据并解密
    if not username or not password:
        try:
            cfg = await asyncio.to_thread(db.load_app_settings)
            sync_cfg = cfg.get('sync', {}) if isinstance(cfg, dict) else {}
            webdav_cfg = sync_cfg.get('webdav', {}) if isinstance(sync_cfg, dict) else {}
            stored_user = webdav_cfg.get('username')
            stored_pw = webdav_cfg.get('password')
            if (not username) and stored_user:
                username = stored_user
            if (not password) and stored_pw:
                try:
                    password = crypto.decrypt_string(stored_pw)
                except Exception:
                    # 如果解密失败，退回使用原始存储值（可能是明文）
                    password = stored_pw
            if username or password:
                logger = logging.getLogger("coinscape.proxy")
                logger.debug(f"Proxy using stored backend credentials: user_set={bool(username)}, pw_set={bool(password)}")
        except Exception:
            # ignore failures here; we will proceed without credentials
            pass
    if not target_url:
        raise HTTPException(status_code=400, detail="Missing 'target' query parameter")
    
    logger.debug(f"Target: {target_url}, user: {username}, password length: {len(password) if password else 0}")
    
    # 获取WebDAV路径参数（如果提供）
    webdav_path = request.path_params.get("webdav_path", "")
    if webdav_path:
        logger.debug(f"WebDAV path from URL: {webdav_path}")
    
    try:
        # 解析目标URL
        parsed_target = urlparse(target_url)
        if not parsed_target.scheme or not parsed_target.netloc:
            raise HTTPException(status_code=400, detail="Invalid target URL")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid target URL: {e}")
    
    # 如果提供了WebDAV路径，追加到目标URL
    if webdav_path:
        # 将WebDAV路径追加到目标URL
        target_url = target_url.rstrip('/') + '/' + webdav_path.lstrip('/')
        logger.debug(f"Final target URL with path from URL: {target_url}")
    else:
        # 尝试从password参数中提取路径（处理客户端错误格式）
        if password and '/' in password:
            # password可能包含路径，如 "password/path/to/file"
            # 检查是否是这种情况
            password_parts = password.split('/')
            if len(password_parts) > 1:
                # 第一部分是真正的密码，其余部分是路径
                real_password = password_parts[0]
                extra_path = '/'.join(password_parts[1:])
                # 更新password和target_url
                password = real_password
                target_url = target_url.rstrip('/') + '/' + extra_path.lstrip('/')
                logger.debug(f"Extracted path from password parameter: {extra_path}")
                logger.debug(f"Updated target URL: {target_url}, password: {password}")
    
    # 对于OPTIONS方法（预检请求），直接返回CORS头，不转发
    if request.method == "OPTIONS":
        # 返回CORS预检响应
        return Response(
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Max-Age": "86400",  # 24小时缓存
            }
        )
    
    # 准备代理请求头
    headers = dict(request.headers)
    # 移除可能引起跨域冲突的头
    forbidden_headers = [
        "host", "origin", "referer", "content-length", 
        "content-encoding", "transfer-encoding", "connection",
        "upgrade", "accept-encoding", "accept-language",
        "accept-charset"  # 浏览器拒绝的不安全头
    ]
    for header in forbidden_headers:
        if header in headers:
            del headers[header]
    
    # 添加必要头
    headers["Host"] = parsed_target.netloc
    
    # 为WebDAV请求添加额外头部
    if request.method in ["PROPFIND", "PROPPATCH", "MKCOL", "COPY", "MOVE", "LOCK", "UNLOCK"]:
        # 确保有Depth头，WebDAV常用
        if "depth" not in headers:
            if request.method == "PROPFIND":
                headers["Depth"] = "1"  # PROPFIND通常需要Depth头
        
        # 确保有Content-Type头对于某些WebDAV方法
        if request.method in ["PROPPATCH", "LOCK"]:
            if "content-type" not in headers:
                headers["Content-Type"] = "application/xml; charset=utf-8"
        
        # 添加Accept头用于WebDAV响应
        if "accept" not in headers:
            headers["Accept"] = "*/*"
        
        # 添加DAV头
        headers["DAV"] = "1"
    
    # 如果提供了用户名和密码，添加Basic Auth头
    if username and password:
        try:
            auth_string = f"{username}:{password}"
            auth_bytes = auth_string.encode('utf-8')
            auth_b64 = base64.b64encode(auth_bytes).decode('utf-8')
            headers["Authorization"] = f"Basic {auth_b64}"
            logger.debug(f"Added Basic Auth header for user: {username}")
        except Exception as e:
            logger.error(f"Failed to create Basic Auth header: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create authentication header: {e}")
    
    # 准备请求体 - 始终读取请求体，但对于没有体的一些方法，可能是空的
    try:
        body_content = await request.body()
    except:
        body_content = b""
    
    logger.info(f"Proxying {request.method} request to {target_url}")
    logger.debug(f"Request headers: {headers}")
    logger.debug(f"Request method: {request.method}")
    logger.debug(f"Request body size: {len(body_content) if body_content else 0}")
    
    # 使用httpx异步客户端转发请求
    client_kwargs = {'timeout': httpx.Timeout(30.0), 'trust_env': False}
    try:
        client = httpx.AsyncClient(**{**client_kwargs, 'follow_redirects': True})
    except TypeError:
        try:
            client = httpx.AsyncClient(**{**client_kwargs, 'allow_redirects': True})
        except TypeError:
            client = httpx.AsyncClient(**client_kwargs)
    async with client as client:
        try:
            # 构造请求
            logger.debug(f"Forwarding request: {request.method} {target_url}, headers: {headers.keys()}, body size: {len(body_content)}")

            # Implement exponential backoff retries for 429 responses
            max_attempts = 4
            proxy_response = None
            for attempt in range(1, max_attempts + 1):
                proxy_response = await client.request(
                    method=request.method,
                    url=target_url,
                    headers=headers,
                    content=body_content,  # 可能是空字节b""
                    follow_redirects=True
                )
                status = proxy_response.status_code
                if status != 429:
                    break
                # status == 429
                if attempt < max_attempts:
                    # honor Retry-After if present and numeric
                    sleep_t = None
                    try:
                        ra = proxy_response.headers.get('Retry-After')
                        if ra:
                            try:
                                sleep_t = float(int(ra))
                            except Exception:
                                sleep_t = None
                    except Exception:
                        sleep_t = None
                    if sleep_t is None:
                        sleep_t = 2 * (2 ** (attempt - 1)) + random.uniform(0, 1)
                    logger.info(f"Received 429 from target, attempt {attempt}/{max_attempts}, sleeping {sleep_t}s before retry")
                    await asyncio.sleep(sleep_t)
                    continue
            
            # 准备响应头
            response_headers = dict(proxy_response.headers)
            # 移除WebDAV可能返回的跨域头，避免冲突
            cors_headers_to_remove = [
                "access-control-allow-origin",
                "access-control-allow-methods", 
                "access-control-allow-headers",
                "access-control-allow-credentials",
                "access-control-expose-headers",
                "access-control-max-age"
            ]
            for cors_header in cors_headers_to_remove:
                if cors_header in response_headers:
                    del response_headers[cors_header]
            
            # 添加必要的CORS头以允许Flutter Web访问
            response_headers["Access-Control-Allow-Origin"] = "*"
            response_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK"
            response_headers["Access-Control-Allow-Headers"] = "*"
            
            # 返回代理响应
            return Response(
                content=proxy_response.content,
                status_code=proxy_response.status_code,
                headers=response_headers,
                media_type=proxy_response.headers.get("content-type")
            )
            
        except httpx.TimeoutException:
            logger.error(f"Timeout while proxying to {target_url}")
            raise HTTPException(status_code=504, detail="Gateway timeout")
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error while proxying to {target_url}: {e.response.status_code}")
            logger.error(f"Response body: {e.response.text[:500]}")
            # 透传目标服务器的HTTP错误状态码
            raise HTTPException(status_code=e.response.status_code, detail=f"Target server error: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error(f"Request error while proxying to {target_url}: {e}")
            logger.exception("Request error details:")
            raise HTTPException(status_code=502, detail=f"Bad gateway: {str(e)[:200]}")
        except Exception as e:
            logger.error(f"Unexpected error while proxying: {e}")
            logger.exception("Full exception traceback:")
            raise HTTPException(status_code=500, detail=f"Internal proxy error: {str(e)[:200]}")


# ============================================================
    # Font files static serving
    # ============================================================
    
    @app.get("/fonts/{filename:path}")
    async def serve_font(filename: str):
        """Serve font files directly."""
        normalized = filename.replace('\\', '/').lstrip('/')
        filepath = os.path.join(db.FONTS_DIR, normalized)
        if not os.path.isfile(filepath):
            raise HTTPException(status_code=404, detail="Font file not found")
        
        # 根据文件扩展名设置正确的媒体类型
        if filename.lower().endswith('.ttf'):
            media_type = "font/ttf"
        elif filename.lower().endswith('.otf'):
            media_type = "font/otf"
        else:
            media_type = "application/octet-stream"
            
        return FileResponse(filepath, media_type=media_type)
    
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
            ext = os.path.splitext(file_path)[1].lower()
            if ext in ('.html', '.js', '.json'):
                headers = {"Cache-Control": "no-cache, must-revalidate"}
            else:
                headers = {"Cache-Control": "public, max-age=604800"}
            return FileResponse(file_path, headers=headers)
        
        # SPA fallback
        index_path = os.path.join(_web_build_dir, "index.html")
        if os.path.isfile(index_path):
            return FileResponse(index_path, headers={"Cache-Control": "no-cache, must-revalidate"})
        
        raise HTTPException(status_code=404, detail="Not found")
    
    @app.get("/")
    async def serve_root():
        index_path = os.path.join(_web_build_dir, "index.html")
        if os.path.isfile(index_path):
            return FileResponse(index_path, headers={"Cache-Control": "no-cache, must-revalidate"})
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
    try:
        settings = db.load_app_settings()
        backend_cfg = settings.get("backend", {})
        svc = backend_cfg.get("service_address")
        lvl = backend_cfg.get("log_level")
        proxy_enabled = backend_cfg.get("proxy_enabled")
        if svc:
            print(f"  Backend service address: {svc}")
        if lvl:
            print(f"  Backend log level: {lvl}")
        if proxy_enabled is not None:
            print(f"  Backend proxy enabled: {proxy_enabled}")
    except Exception:
        pass


# ============================================================
# Entry point
# ============================================================

# 添加全局异常处理器到FastAPI应用
add_exception_handlers_to_app(app)

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("COINSCAPE_PORT", "9876"))
    host = os.environ.get("COINSCAPE_HOST", "0.0.0.0")
    
    print(f"Starting CoinScape server at http://{host}:{port}")
    print(f"Set COINSCAPE_SAVE_PATH env var to change data directory")
    print(f"  Current SAVE_PATH: {db.SAVE_PATH}")
    print()
    # Check if port is already in use to avoid confusing bind errors.
    try:
        check_host = host
        if check_host == '0.0.0.0' or check_host == '':
            check_host = '127.0.0.1'
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.5)
            res = sock.connect_ex((check_host, port))
            if res == 0:
                msg = f"Port {port} appears to be already in use on {check_host}.\n" \
                      f"Please stop the other process using this port or set COINSCAPE_PORT to a different port."
                logger.error(msg)
                print(msg)
                sys.exit(1)
    except Exception as e:
        # If the check itself fails, log but attempt to continue — uvicorn will surface binding errors if any.
        logger.debug('Port check failed: %s', e)

    try:
        uvicorn.run(app, host=host, port=port)
    except OSError as e:
        logger.error('Failed to start server on %s:%s - %s', host, port, e, exc_info=True)
        print(f"Failed to bind to {host}:{port}: {e}")
        sys.exit(1)
    except Exception:
        logger.exception('Unexpected error while running server')
        raise
