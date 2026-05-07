#!/usr/bin/env python3
"""
测试httpx是否支持WebDAV方法
"""

import asyncio
import httpx

async def test_httpx_methods():
    """测试httpx是否支持非标准HTTP方法"""
    test_url = "http://httpbin.org/anything"
    methods = ["GET", "POST", "PROPFIND", "MKCOL", "COPY"]
    
    print("测试httpx对各种HTTP方法的支持:")
    print("-" * 80)
    
    for method in methods:
        print(f"\n测试方法: {method}")
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.request(method, test_url)
                print(f"  状态码: {response.status_code}")
                print(f"  方法透传: {response.json().get('method', 'N/A')}")
        except httpx.HTTPStatusError as e:
            print(f"  HTTP状态错误: {e.response.status_code}")
        except Exception as e:
            print(f"  错误: {type(e).__name__}: {e}")

async def test_basic_auth():
    """测试Basic认证头构建"""
    import base64
    
    test_cases = [
        ("user1", "pass1"),
        ("user2", "pass/with/slash"),  # 包含斜杠的密码
        ("user3", "pass@with#special"),  # 包含特殊字符
        ("user4", ""),  # 空密码
        ("", "password"),  # 空用户名
    ]
    
    print("\n\n测试Basic Auth头构建:")
    print("-" * 80)
    
    for username, password in test_cases:
        try:
            auth_string = f"{username}:{password}"
            auth_bytes = auth_string.encode('utf-8')
            auth_b64 = base64.b64encode(auth_bytes).decode('utf-8')
            auth_header = f"Basic {auth_b64}"
            print(f"  '{username}':'{password}' -> {auth_header[:50]}...")
        except Exception as e:
            print(f"  '{username}':'{password}' -> 错误: {e}")

def main():
    print("开始测试")
    print("=" * 80)
    
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(test_httpx_methods())
        loop.run_until_complete(test_basic_auth())
    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"\n测试失败: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 80)
    print("测试完成")

if __name__ == "__main__":
    main()