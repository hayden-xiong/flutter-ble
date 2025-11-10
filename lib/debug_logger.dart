import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 真机调试日志工具类
/// 在 Release/Profile 模式下也能查看日志
class DebugLogger {
  static const String _tag = 'BLE_APP';
  
  /// 普通信息日志
  static void info(String message, {String? tag}) {
    final logTag = tag ?? _tag;
    developer.log(
      message,
      name: logTag,
      time: DateTime.now(),
    );
    
    // 在开发模式下也打印到控制台
    if (kDebugMode) {
      debugPrint('[$logTag] $message');
    }
  }
  
  /// 错误日志
  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    final logTag = tag ?? _tag;
    developer.log(
      message,
      name: logTag,
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
      level: 1000, // 错误级别
    );
    
    if (kDebugMode) {
      debugPrint('❌ [$logTag] $message');
      if (error != null) debugPrint('Error: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }
  }
  
  /// 警告日志
  static void warning(String message, {String? tag}) {
    final logTag = tag ?? _tag;
    developer.log(
      message,
      name: logTag,
      time: DateTime.now(),
      level: 900, // 警告级别
    );
    
    if (kDebugMode) {
      debugPrint('⚠️  [$logTag] $message');
    }
  }
  
  /// 蓝牙相关日志
  static void ble(String message) {
    info(message, tag: 'BLE');
  }
  
  /// 性能追踪
  static void performance(String operation, int milliseconds) {
    info('⏱️  $operation 耗时: ${milliseconds}ms', tag: 'PERFORMANCE');
  }
  
  /// 开始性能追踪
  static Stopwatch startTrace(String operation) {
    info('🚀 开始: $operation', tag: 'TRACE');
    return Stopwatch()..start();
  }
  
  /// 结束性能追踪
  static void endTrace(String operation, Stopwatch stopwatch) {
    stopwatch.stop();
    performance(operation, stopwatch.elapsedMilliseconds);
  }
}

/// 使用示例：
/// 
/// // 普通日志
/// DebugLogger.info('应用启动');
/// 
/// // 蓝牙日志
/// DebugLogger.ble('开始扫描设备');
/// 
/// // 错误日志
/// try {
///   // some code
/// } catch (e, stack) {
///   DebugLogger.error('连接失败', error: e, stackTrace: stack);
/// }
/// 
/// // 性能追踪
/// final trace = DebugLogger.startTrace('扫描蓝牙');
/// // ... do something
/// DebugLogger.endTrace('扫描蓝牙', trace);

