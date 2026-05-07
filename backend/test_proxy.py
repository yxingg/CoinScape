#!/usr/bin/env python3
"""
测试WebDAV代理功能
"""

import asyncio
import httpx
from urllib.parse import quote

async def test_proxy_methods():
    """测试代理支持的各种HTTP方法"""
    backend_url = "http://localhost:9876"
    test_target = "http://httpbin.org/anything"  # 使用httpbin作为测试目标
    
    methods_to_test = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    webdav_methods = ["PROPFIND", "PROPPATCH", "MKCOL", "COPY", "MOVE", "LOCK", "UNLOCK"]
    
    print("测试标准HTTP方法:")
    print("-" * 50)
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        for method in methods_to_test:
            proxy_url = f"{backend_url}/api/proxy/webdav?target={quote(test_target)}"
            print(f"测试 {method} 请求...")
            
            try:
                response = await client.request(method, proxy_url)
                print(f"  {method}: 状态码={response.status_code}")
                if response.status_code != 200:
                    print(f"    响应体: {response.text[:200]}")
            except Exception as e:
                print(f"  {method}: 错误 - {type(e).__name__}: {e}")
    
    print("\n测试WebDAV方法（可能失败）:")
    print("-" * 50)
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        for method in webdav_methods:
            proxy_url = f"{backend_url}/api/proxy/webdav?target={quote(test_target)}"
            print(f"测试 {method} 请求...")
            
            try:
                # 对于非标准方法，可能需要特殊处理
                response = await client.request(method, proxy_url)
                print(f"  {method}: 状态码={response.status_code}")
                if response.status_code == 405:
                    print(f"    !!! 方法不支持 (405 Method Not Allowed)")
            except httpx.HTTPStatusError as e:
                print(f"  {method}: HTTP错误 - {e.response.status_code}")
            except Exception as e:
                print(f"  {method}: 错误 - {type(e).__name__}: {e}")

async def test_cors_preflight():
    """测试CORS预检请求"""
    backend_url = "http://localhost:9876"
    test_target = "http://httpbin.org/anything"
    proxy_url = f"{backend_url}/api/proxy/webdav?target={quote(test_target)}"
    
    print("\n测试CORS OPTIONS预检请求:")
    print("-" * 50)
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            # 发送OPTIONS请求
            response = await client.options(proxy_url)
            print(f"OPTIONS请求状态码: {response.status_code}")
            print(f"响应头:")
            for key, value in response.headers.items():
                if key.lower().startswith('access-control-'):
                    print(f"  {key}: {value}")
            
            if response.status_code == 200:
                print("✓ CORS预检请求成功")
            else:
                print(f"✗ CORS预检请求失败: {response.status_code}")
                
        except Exception as e:
            print(f"OPTIONS请求错误: {type(e).__name__}: {e}")

def main():
    print("=" * 60)
    print("WebDAV代理功能测试")
    print("=" * 60)
    
    try:
        asyncio.run(test_proxy_methods())
        asyncio.run(test_cors_preflight())
    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"\n测试失败: {type(e).__name__}: {e}")
    
    print("\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)

if __name__ == "__main__":
    main()