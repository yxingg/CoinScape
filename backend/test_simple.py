#!/usr/bin/env python3
"""
简单的代理功能测试
"""

import asyncio
import httpx
from urllib.parse import quote

async def test_proxy():
    """测试代理功能"""
    backend_url = "http://localhost:9876"
    
    # 测试用的target URL - 使用httpbin来测试
    test_target = "http://httpbin.org/anything"
    
    # 构建代理URL - 注意格式
    proxy_url = f"{backend_url}/api/proxy/webdav?target={quote(test_target)}&user=test&password=test123"
    
    print(f"测试代理URL: {proxy_url}")
    print("-" * 80)
    
    # 测试各种方法
    test_methods = ["OPTIONS", "GET", "PROPFIND"]
    
    for method in test_methods:
        print(f"\n测试 {method} 请求:")
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.request(method, proxy_url)
                print(f"  状态码: {response.status_code}")
                print(f"  响应头: {{")
                for key, value in response.headers.items():
                    if key.lower().startswith('access-control-') or key.lower() == 'content-type':
                        print(f"    {key}: {value}")
                print(f"  }}")
                
                # 对于非200响应，显示部分响应体
                if response.status_code != 200:
                    print(f"  响应体 (前500字符): {response.text[:500]}")
        except httpx.HTTPStatusError as e:
            print(f"  HTTP错误: {e.response.status_code} - {e}")
        except Exception as e:
            print(f"  错误: {type(e).__name__}: {e}")

def main():
    print("开始测试WebDAV代理功能")
    print("=" * 80)
    
    try:
        asyncio.run(test_proxy())
    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"\n测试失败: {type(e).__name__}: {e}")
    
    print("\n" + "=" * 80)
    print("测试完成")

if __name__ == "__main__":
    main()