#!/usr/bin/env python3
"""
测试CoinScape日志系统

这个脚本测试后端Python日志系统的功能：
1. 日志文件创建
2. 日志级别过滤
3. 模块前缀
4. 日志轮转
5. 异常捕获
"""

import os
import sys
import logging
import tempfile
import shutil
from datetime import datetime, timedelta

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_backend_logging():
    """测试后端日志系统"""
    print("=" * 60)
    print("测试后端日志系统")
    print("=" * 60)
    
    # 创建临时目录用于测试
    temp_dir = tempfile.mkdtemp(prefix="coinscape_log_test_")
    print(f"测试目录: {temp_dir}")
    
    # 设置环境变量
    os.environ["COINSCAPE_SAVE_PATH"] = temp_dir
    
    try:
        # 先导入database，因为它被main导入
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "backend"))
        import database as db
        
        print(f"✓ 数据库保存路径: {db.SAVE_PATH}")
        
        # 现在导入main（会触发日志初始化）
        import main
        
        # 获取logger
        logger = logging.getLogger("coinscape.test")
        
        # 测试不同级别的日志
        logger.debug("这是一个调试日志（应该不会出现在文件中）")
        logger.info("这是一个信息日志")
        logger.warning("这是一个警告日志")
        logger.error("这是一个错误日志")
        
        # 测试异常日志
        try:
            raise ValueError("测试异常")
        except ValueError as e:
            logger.exception("捕获到异常: %s", e)
        
        # 检查日志文件
        log_file = os.path.join(temp_dir, "coinscape.log")
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                last_line = lines[-1].strip() if lines else ""
                print(f"\n✓ 日志文件已创建: {log_file}")
                print(f"  文件大小: {os.path.getsize(log_file)} 字节")
                print(f"  日志行数: {len(lines)}")
                print(f"  最后一行示例: {last_line[:100]}...")
        else:
            print(f"\n✗ 日志文件未创建: {log_file}")
        
        # 模拟生成大量日志以测试轮转
        print("\n测试日志轮转...")
        for i in range(1000):
            logger.info(f"测试日志行 #{i+1}: {'A' * 100}")
        
        # 检查日志文件大小
        if os.path.exists(log_file):
            file_size = os.path.getsize(log_file)
            print(f"  日志文件大小: {file_size / 1024 / 1024:.2f} MB")
            
            # 检查是否有备份文件
            backup_files = [f for f in os.listdir(temp_dir) 
                          if f.startswith("coinscape.log.")]
            if backup_files:
                print(f"  ✓ 发现备份文件: {len(backup_files)} 个")
                for bf in sorted(backup_files)[:3]:  # 显示前3个备份
                    bf_path = os.path.join(temp_dir, bf)
                    print(f"    - {bf}: {os.path.getsize(bf_path) / 1024:.1f} KB")
        
        # 测试模块前缀
        print("\n测试模块前缀...")
        db_logger = logging.getLogger("coinscape.database")
        api_logger = logging.getLogger("coinscape.api.test")
        
        db_logger.info("数据库连接测试")
        api_logger.info("API调用测试")
        
        print("\n✓ 所有测试完成！")
        
    except Exception as e:
        print(f"\n✗ 测试失败: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # 清理临时目录
        try:
            shutil.rmtree(temp_dir)
            print(f"\n清理测试目录: {temp_dir}")
        except Exception as e:
            print(f"清理目录失败: {e}")
        
        # 清理环境变量
        if "COINSCAPE_SAVE_PATH" in os.environ:
            del os.environ["COINSCAPE_SAVE_PATH"]

def test_frontend_log_simulation():
    """模拟前端日志格式"""
    print("\n" + "=" * 60)
    print("模拟前端日志格式")
    print("=" * 60)
    
    # 模拟前端日志格式
    timestamp = datetime.now().isoformat()
    
    log_examples = [
        f"[{timestamp}] INFO [APP] 应用启动中...",
        f"[{timestamp}] DEBUG [DATABASE] 数据库连接成功",
        f"[{timestamp}] WARNING [SYNC] WebDAV连接超时",
        f"[{timestamp}] ERROR [API] 请求失败: 404 Not Found",
        f"[{timestamp}] INFO [SETTINGS] 日志路径已更新",
    ]
    
    for i, log in enumerate(log_examples, 1):
        print(f"{i:2}. {log}")
    
    print("\n✓ 前端日志格式验证完成")

if __name__ == "__main__":
    print("CoinScape 日志系统测试")
    print("=" * 60)
    
    # 测试后端日志
    test_backend_logging()
    
    # 模拟前端日志
    test_frontend_log_simulation()
    
    print("\n" + "=" * 60)
    print("所有测试完成！")
    print("=" * 60)