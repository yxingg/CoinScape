import importlib.util
import sys
from pathlib import Path
import json

mod_path = Path(__file__).resolve().parents[1] / 'main.py'
# Ensure backend dir is on sys.path so relative/plain imports inside main.py work
sys.path.insert(0, str(mod_path.parent))
spec = importlib.util.spec_from_file_location('backend_main', str(mod_path))
mod = importlib.util.module_from_spec(spec)
sys.modules['backend_main'] = mod
spec.loader.exec_module(mod)
app = getattr(mod, 'app')

routes = []
for r in app.routes:
    path = getattr(r, 'path', None)
    methods = getattr(r, 'methods', None)
    routes.append({'path': path, 'methods': sorted(list(methods)) if methods else None})

print(json.dumps(routes, ensure_ascii=False, indent=2))
