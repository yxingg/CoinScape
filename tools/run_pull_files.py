import asyncio
import json
import os
import sys

# ensure repo root is on sys.path so 'backend' package can be imported when running from tools/
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from backend import file_sync
except Exception:
    import file_sync

async def main():
    print('Starting file-level pull...')
    policy = 'prefer_local'
    if len(sys.argv) > 1:
        policy = sys.argv[1]
    res = await file_sync.manager.pull_all(policy=policy)
    print('Result:')
    print(json.dumps(res, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    asyncio.run(main())
