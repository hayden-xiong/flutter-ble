import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// WiFi 网络信息
class WiFiNetwork {
  final String ssid;
  final int rssi;
  final int channel;
  final int authMode;
  final String? bssid;

  WiFiNetwork({
    required this.ssid,
    required this.rssi,
    required this.channel,
    required this.authMode,
    this.bssid,
  });

  factory WiFiNetwork.fromJson(Map<String, dynamic> json) {
    return WiFiNetwork(
      ssid: json['ssid'] as String? ?? '',
      rssi: json['rssi'] as int? ?? -100,
      channel: json['channel'] as int? ?? 0,
      authMode: json['auth_mode'] as int? ?? 0,
      bssid: json['bssid'] as String?,
    );
  }

  /// 获取信号强度等级 (0-4)
  int get signalLevel {
    if (rssi >= -30) return 4; // 优秀
    if (rssi >= -50) return 3; // 良好
    if (rssi >= -70) return 2; // 一般
    if (rssi >= -90) return 1; // 较差
    return 0; // 很差
  }

  /// 获取信号强度描述
  String get signalDescription {
    switch (signalLevel) {
      case 4:
        return '优秀';
      case 3:
        return '良好';
      case 2:
        return '一般';
      case 1:
        return '较差';
      default:
        return '很差';
    }
  }

  /// 获取加密类型描述
  String get authModeDescription {
    switch (authMode) {
      case 0:
        return '开放';
      case 1:
        return 'WEP';
      case 2:
        return 'WPA';
      case 3:
        return 'WPA2';
      case 4:
        return 'WPA/WPA2';
      case 5:
        return 'WPA2企业级';
      case 6:
        return 'WPA3';
      default:
        return '未知';
    }
  }

  /// 是否需要密码
  bool get needsPassword => authMode != 0;
}

/// WiFi 配置结果
class WiFiConfigResult {
  final bool success;
  final String message;
  final String? ssid;
  final String? ip;
  final int? rssi;
  final int? errorCode;

  WiFiConfigResult({
    required this.success,
    required this.message,
    this.ssid,
    this.ip,
    this.rssi,
    this.errorCode,
  });

  factory WiFiConfigResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';
    final success = status == 'success';
    final message = json['message'] as String? ?? (success ? '配置成功' : '配置失败');
    
    final data = json['data'] as Map<String, dynamic>?;
    
    return WiFiConfigResult(
      success: success,
      message: message,
      ssid: data?['ssid'] as String?,
      ip: data?['ip'] as String?,
      rssi: data?['rssi'] as int?,
      errorCode: json['error_code'] as int?,
    );
  }

  /// 获取错误描述
  String getErrorDescription() {
    if (success) return message;
    
    switch (errorCode) {
      case 1000:
        return 'JSON 解析失败，请重试';
      case 1001:
        return '密码错误，请检查后重试';
      case 1002:
        return '未找到该 WiFi，请重新扫描';
      case 1003:
        return '连接超时，请检查信号强度';
      case 1004:
        return 'IP 地址获取失败，请检查路由器设置';
      case 1005:
        return 'WiFi 配置已满，请先删除不用的配置';
      case 2000:
        return '设备内存不足，请重启设备';
      case 2001:
        return '存储写入失败，请重启设备';
      case 3000:
        return '未知错误，请联系技术支持';
      default:
        return message;
    }
  }
}

/// BLE WiFi 配网服务
class BLEWiFiService {
  // UUID 定义（根据规范）
  static const String serviceUUID = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String characteristicUUID = '0000FFE1-0000-1000-8000-00805F9B34FB';

  final BluetoothDevice device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _notifySubscription;

  // 回调函数
  Function(List<WiFiNetwork>)? onWiFiListReceived;
  Function(WiFiConfigResult)? onConfigResult;
  Function(String)? onError;

  BLEWiFiService(this.device);

  /// 初始化服务（发现特征并启用通知）
  Future<bool> initialize() async {
    try {
      debugPrint('[BLE WiFi] 开始初始化...');
      
      // 发现服务
      List<BluetoothService> services = await device.discoverServices();
      
      // 查找目标服务和特征
      for (var service in services) {
        debugPrint('[BLE WiFi] 发现服务: ${service.uuid}');
        
        if (service.uuid.toString().toUpperCase().contains('FFE0')) {
          for (var characteristic in service.characteristics) {
            debugPrint('[BLE WiFi] 发现特征: ${characteristic.uuid}');
            
            if (characteristic.uuid.toString().toUpperCase().contains('FFE1')) {
              _characteristic = characteristic;
              
              // 启用通知
              await characteristic.setNotifyValue(true);
              debugPrint('[BLE WiFi] 已启用通知');
              
              // 监听通知
              _notifySubscription = characteristic.onValueReceived.listen(
                _handleNotification,
                onError: (error) {
                  debugPrint('[BLE WiFi] 通知错误: $error');
                  onError?.call('通知接收失败: $error');
                },
              );
              
              debugPrint('[BLE WiFi] 初始化成功');
              return true;
            }
          }
        }
      }
      
      debugPrint('[BLE WiFi] 未找到目标服务或特征');
      onError?.call('设备不支持 WiFi 配网功能');
      return false;
    } catch (e) {
      debugPrint('[BLE WiFi] 初始化失败: $e');
      onError?.call('初始化失败: $e');
      return false;
    }
  }

  /// 扫描 WiFi 网络
  Future<bool> scanWiFi() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送扫描命令');
      
      final command = {
        'cmd': 'scan_wifi',
      };
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 扫描失败: $e');
      onError?.call('扫描失败: $e');
      return false;
    }
  }

  /// 配置 WiFi
  Future<bool> configureWiFi({
    required String ssid,
    required String password,
    String? bssid,
  }) async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送配置命令: $ssid');
      
      final data = <String, dynamic>{
        'ssid': ssid,
        'password': password,
      };
      
      if (bssid != null && bssid.isNotEmpty) {
        data['bssid'] = bssid;
      }
      
      final command = {
        'cmd': 'wifi_config',
        'data': data,
      };
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 配置失败: $e');
      onError?.call('配置失败: $e');
      return false;
    }
  }

  /// 发送命令
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_characteristic == null) {
      throw Exception('特征未找到');
    }

    final jsonString = jsonEncode(command);
    final data = utf8.encode(jsonString);
    
    debugPrint('[BLE WiFi] 发送数据: $jsonString');
    
    // 检查数据大小（建议 < 256 字节）
    if (data.length > 256) {
      debugPrint('[BLE WiFi] 警告: 数据大小超过建议值 (${data.length} 字节)');
    }
    
    await _characteristic!.write(data, withoutResponse: false);
  }

  /// 处理通知数据
  void _handleNotification(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      debugPrint('[BLE WiFi] 收到数据: $jsonString');
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final cmd = json['cmd'] as String?;
      final status = json['status'] as String?;
      
      if (cmd == null || status == null) {
        debugPrint('[BLE WiFi] 数据格式错误: 缺少 cmd 或 status');
        return;
      }
      
      switch (cmd) {
        case 'scan_wifi':
          _handleWiFiScanResult(json);
          break;
        case 'wifi_config':
          _handleWiFiConfigResult(json);
          break;
        default:
          debugPrint('[BLE WiFi] 未知命令: $cmd');
      }
    } catch (e) {
      debugPrint('[BLE WiFi] 数据解析失败: $e');
      onError?.call('数据解析失败: $e');
    }
  }

  /// 处理 WiFi 扫描结果
  void _handleWiFiScanResult(Map<String, dynamic> json) {
    final status = json['status'] as String;
    
    if (status != 'success') {
      final message = json['message'] as String? ?? 'WiFi 扫描失败';
      debugPrint('[BLE WiFi] WiFi 扫描失败: $message');
      onError?.call(message);
      return;
    }
    
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('[BLE WiFi] WiFi 扫描结果无数据');
      onWiFiListReceived?.call([]);
      return;
    }
    
    final networks = data['networks'] as List<dynamic>?;
    if (networks == null) {
      debugPrint('[BLE WiFi] WiFi 扫描结果无网络列表');
      onWiFiListReceived?.call([]);
      return;
    }
    
    final wifiList = networks
        .map((item) => WiFiNetwork.fromJson(item as Map<String, dynamic>))
        .toList();
    
    // 按信号强度排序
    wifiList.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    debugPrint('[BLE WiFi] 收到 ${wifiList.length} 个 WiFi 网络');
    onWiFiListReceived?.call(wifiList);
  }

  /// 处理 WiFi 配置结果
  void _handleWiFiConfigResult(Map<String, dynamic> json) {
    final result = WiFiConfigResult.fromJson(json);
    
    if (result.success) {
      debugPrint('[BLE WiFi] WiFi 配置成功: ${result.message}');
    } else {
      debugPrint('[BLE WiFi] WiFi 配置失败: ${result.message} (错误码: ${result.errorCode})');
    }
    
    onConfigResult?.call(result);
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('[BLE WiFi] 释放资源');
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _characteristic = null;
  }
}

