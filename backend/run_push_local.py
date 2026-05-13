#!/usr/bin/env python3
"""Run FileSyncManager.push_all() locally and print result.

Usage:
  python -m backend.run_push_local
"""
import sys
import asyncio
import json

import backend.file_sync as fs


def main():
    res = asyncio.run(fs.manager.push_all())
    print(json.dumps(res, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
