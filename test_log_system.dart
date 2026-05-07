import 'package:coinscape/main.dart' as app;
import 'package:coinscape/utils/logger.dart';

void main() async {
  print('=== 测试日志系统 ===');
  
  // 初始化日志系统
  await AppLogger.init();
  print('日志系统初始化完成');
  
  // 测试各种级别的日志
  print('测试DEBUG日志...');
  AppLogger.debug('TEST', '这是一个DEBUG测试');
  
  print('测试INFO日志...');
  AppLogger.info('TEST', '这是一个INFO测试');
  
  print('测试WARNING日志...');
  AppLogger.warning('TEST', '这是一个WARNING测试');
  
  print('测试ERROR日志...');
  AppLogger.error('TEST', '这是一个ERROR测试', StackTrace.current);
  
  print('测试模块化日志...');
  AppLogger.moduleInfo('database', '数据库连接测试');
  AppLogger.moduleError('api', 'API调用失败', StackTrace.current);
  
  print('=== 日志系统测试完成 ===');
  
  // 测试日志级别过滤
  print('\n=== 测试日志级别过滤 ===');
  
  print('设置日志级别为WARNING...');
  AppLogger.setLogLevel(LogLevel.warning);
  
  print('测试DEBUG日志（不应显示）...');
  AppLogger.debug('TEST', 'DEBUG日志 - 不应显示');
  
  print('测试INFO日志（不应显示）...');
  AppLogger.info('TEST', 'INFO日志 - 不应显示');
  
  print('测试WARNING日志（应显示）...');
  AppLogger.warning('TEST', 'WARNING日志 - 应显示');
  
  print('测试ERROR日志（应显示）...');
  AppLogger.error('TEST', 'ERROR日志 - 应显示', StackTrace.current);
  
  print('=== 日志级别过滤测试完成 ===');
}