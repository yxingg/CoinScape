import os
import base64
import hashlib
import hmac
import secrets
from typing import Tuple

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_DATA_DIR = os.path.join(_SCRIPT_DIR, 'data')
_SECRET_FILE = os.path.join(_DATA_DIR, 'secret.key')


def _ensure_data_dir():
    os.makedirs(_DATA_DIR, exist_ok=True)


def _load_env_key() -> bytes:
    v = os.environ.get('COINSCAPE_SECRET_KEY')
    if not v:
        return None
    # try base64 decode
    try:
        b = base64.b64decode(v)
        if len(b) >= 16:
            return b
    except Exception:
        pass
    # try hex
    try:
        b = bytes.fromhex(v)
        if len(b) >= 16:
            return b
    except Exception:
        pass
    # fallback: sha256 of string
    return hashlib.sha256(v.encode('utf-8')).digest()


def get_or_create_master_key() -> bytes:
    """Return master key bytes. Prefer env var; otherwise create/load secret.key."""
    _ensure_data_dir()
    env_key = _load_env_key()
    if env_key:
        return env_key

    # try load file
    if os.path.isfile(_SECRET_FILE):
        try:
            with open(_SECRET_FILE, 'rb') as f:
                data = f.read()
            return base64.b64decode(data)
        except Exception:
            pass

    # generate and persist
    key = secrets.token_bytes(32)
    try:
        with open(_SECRET_FILE, 'wb') as f:
            f.write(base64.b64encode(key))
        try:
            os.chmod(_SECRET_FILE, 0o600)
        except Exception:
            pass
    except Exception:
        pass
    return key


def _derive_key(master_key: bytes, salt: bytes, iterations: int = 100000) -> bytes:
    return hashlib.pbkdf2_hmac('sha256', master_key, salt, iterations, dklen=32)


def encrypt_string(plaintext: str) -> str:
    master = get_or_create_master_key()
    salt = secrets.token_bytes(16)
    key = _derive_key(master, salt)
    aesgcm = AESGCM(key)
    nonce = secrets.token_bytes(12)
    ct = aesgcm.encrypt(nonce, plaintext.encode('utf-8'), None)
    return f"enc:{base64.b64encode(salt).decode('ascii')}:{base64.b64encode(nonce).decode('ascii')}:{base64.b64encode(ct).decode('ascii')}"


def decrypt_string(enc_str: str) -> str:
    if not isinstance(enc_str, str) or not enc_str.startswith('enc:'):
        return enc_str
    try:
        parts = enc_str.split(':', 3)
        if len(parts) != 4:
            return enc_str
        _, salt_b64, nonce_b64, ct_b64 = parts
        salt = base64.b64decode(salt_b64)
        nonce = base64.b64decode(nonce_b64)
        ct = base64.b64decode(ct_b64)
        master = get_or_create_master_key()
        key = _derive_key(master, salt)
        aesgcm = AESGCM(key)
        pt = aesgcm.decrypt(nonce, ct, None)
        return pt.decode('utf-8')
    except Exception:
        return enc_str


def hash_password(password: str, iterations: int = 200000) -> str:
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)
    return f"{base64.b64encode(salt).decode('ascii')}:{dk.hex()}"


def verify_password(password: str, stored: str, iterations: int = 200000) -> bool:
    try:
        salt_b64, hash_hex = stored.split(':', 1)
        salt = base64.b64decode(salt_b64)
        dk = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)
        return hmac.compare_digest(dk.hex(), hash_hex)
    except Exception:
        return False
