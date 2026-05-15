from importlib import util
from pathlib import Path
import sys

mod_path = Path(__file__).resolve().parents[1] / 'main.py'
sys.path.insert(0, str(mod_path.parent))

spec = util.spec_from_file_location('backend_main', str(mod_path))
mod = util.module_from_spec(spec)
spec.loader.exec_module(mod)
app = getattr(mod, 'app')

from starlette.testclient import TestClient

client = TestClient(app)
resp = client.get('/api/proxy/webdav', params={'target': 'http://10.168.72.54:5244/dav/quark'})
print('status', resp.status_code)
print('headers', resp.headers)
print('body', resp.text[:1000])
