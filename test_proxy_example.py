#!/usr/bin/env python3
"""
测试WebDAV代理功能示例
"""

import asyncio
import httpx
from urllib.parse import quote

async def test_webdav_proxy():
    """测试WebDAV代理功能"""
    backend_url = "http://localhost:9876"
    webdav_url = "http://localhost:5244/dav/PC"
    
    # 构建代理URL
    proxy_url = f"{backend_url}/api/proxy/webdav?target={quote(webdav_url)}"
    
    print(f"后端地址: {backend_url}")
    print(f"WebDAV地址: {webdav_url}")
    print(f"代理URL: {proxy_url}")
    print()
    
    # 测试代理连接
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            # 测试OPTIONS预检请求
            print("测试OPTIONS请求...")
            options_response = await client.options(proxy_url)
            print(f"  OPTIONS状态码: {options_response.status_code}")
            print(f"  CORS头: {options_response.headers.get('access-control-allow-origin')}")
            print()
            
            # 测试GET请求
            print("测试GET请求...")
            get_response = await client.get(proxy_url)
            print(f"  GET状态码: {get_response.status_code}")
            print(f"  响应头: {{")
            for key, value in get_response.headers.items():
                if key.lower().startswith('access-control-'):
                    print(f"    {key}: {value}")
            print(f"  }}")
            
        except httpx.ConnectError:
            print("错误: 无法连接到后端服务器，请确保后端正在运行")
        except httpx.TimeoutException:
            print("错误: 请求超时")
        except Exception as e:
            print(f"错误: {type(e).__name__}: {e}")

def test_url_normalization():
    """测试URL规范化"""
    print("测试URL规范化:")
    print()
    
    test_cases = [
        # (输入, 期望输出)
        ("http://localhost:8000", "http://localhost:8000/"),
        ("http://localhost:8000/", "http://localhost:8000/"),
        ("http://localhost:8000//", "http://localhost:8000/"),
        
        ("proxy/webdav", "/proxy/webdav"),
        ("/proxy/webdav", "/proxy/webdav"),
        ("//proxy/webdav", "/proxy/webdav"),
        
        ("http://localhost:5244/dav/PC", "http://localhost:5244/dav/PC"),
        ("http://localhost:5244/dav/PC/", "http://localhost:5244/dav/PC"),
    ]
    
    for input_url, expected in test_cases:
        # 模拟Flutter中的URL规范化逻辑
        from urllib.parse import urlparse, urlunparse
        
        if input_url.startswith("http"):
            # 规范化基础URL
            url = input_url.rstrip('/')
            url = f"{url}/" if url else ""
            result = url
            
            # 规范化WebDAV URL
            if "/dav/" in input_url:
                url = input_url.rstrip('/')
                result = url
        else:
            # 规范化路径
            url = input_url.lstrip('/')
            url = f"/{url}"
            result = url
        
        match = "✓" if result == expected else "✗"
        print(f"  {match} '{input_url}' -> '{result}' (期望: '{expected}')")
    
    print()

def main():
    print("=" * 60)
    print("WebDAV代理功能测试")
    print("=" * 60)
    print()
    
    # 测试URL规范化
    test_url_normalization()
    
    # 测试代理连接（仅在用户确认后端运行时）
    print("运行代理连接测试...")
    try:
        asyncio.run(test_webdav_proxy())
    except KeyboardInterrupt:
        print("\n测试被用户中断")
    
    print()
    print("=" * 60)
    print("测试完成")
    print("=" * 60)

if __name__ == "__main__":
    main()