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
      ssid: json['ssid'] as String,
      rssi: json['rssi'] as int,
      channel: json['channel'] as int,
      authMode: json['auth_mode'] as int,
      bssid: json['bssid'] as String?,
    );
  }

  /// 获取认证类型描述
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
        return 'WPA2-Enterprise';
      case 6:
        return 'WPA3';
      default:
        return '未知';
    }
  }

  /// 是否需要密码
  bool get requiresPassword => authMode != 0;

  /// 获取信号强度等级 (1-4)
  int get signalLevel {
    if (rssi >= -30) return 4; // 优秀
    if (rssi >= -50) return 3; // 良好
    if (rssi >= -70) return 2; // 一般
    if (rssi >= -90) return 1; // 较差
    return 1; // 很差
  }

  /// 获取信号强度描述
  String get signalDescription {
    if (rssi >= -30) return '优秀';
    if (rssi >= -50) return '良好';
    if (rssi >= -70) return '一般';
    if (rssi >= -90) return '较差';
    return '很差';
  }
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
    final status = json['status'] as String;
    final success = status == 'success';
    final message = json['message'] as String? ?? '';
    
    if (success) {
      final data = json['data'] as Map<String, dynamic>?;
      return WiFiConfigResult(
        success: true,
        message: message,
        ssid: data?['ssid'] as String?,
        ip: data?['ip'] as String?,
        rssi: data?['rssi'] as int?,
      );
    } else {
      return WiFiConfigResult(
        success: false,
        message: message,
        errorCode: json['error_code'] as int?,
      );
    }
  }

  /// 根据错误码获取友好的错误提示
  String get friendlyMessage {
    if (success) return message;
    
    switch (errorCode) {
      case 1000:
        return 'JSON 解析失败，请重试';
      case 1001:
        return '密码错误，请检查后重试';
      case 1002:
        return '未找到该 WiFi，请重新扫描';
      case 1003:
        return '连接超时，请检查 WiFi 信号强度';
      case 1004:
        return 'IP 地址获取失败，请检查路由器 DHCP 设置';
      case 1005:
        return 'WiFi 配置已满，请先删除不用的配置';
      case 2000:
        return '设备内存不足，设备需要重启';
      case 2001:
        return '存储写入失败，设备需要重启';
      case 3000:
        return '未知错误，请联系技术支持';
      default:
        return message.isNotEmpty ? message : '配置失败，请重试';
    }
  }
}

/// BLE WiFi 配网服务
class BLEWiFiProvisioner {
  // Service 和 Characteristic UUID
  static const String serviceUUID = "0000FFE0-0000-1000-8000-00805F9B34FB";
  static const String characteristicUUID = "0000FFE1-0000-1000-8000-00805F9B34FB";

  final BluetoothDevice device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _notificationSubscription;

  // 回调
  Function(List<WiFiNetwork>)? onWiFiListReceived;
  Function(WiFiConfigResult)? onConfigResult;
  Function(String)? onError;

  // 用于等待响应的 Completer
  Completer<Map<String, dynamic>>? _responseCompleter;
  Timer? _responseTimer;

  BLEWiFiProvisioner({required this.device});

  /// 初始化服务
  Future<bool> initialize() async {
    try {
      // 发现服务
      List<BluetoothService> services = await device.discoverServices();
      
      // 查找配网服务
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == serviceUUID.toUpperCase()) {
          // 查找配网特征
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == characteristicUUID.toUpperCase()) {
              _characteristic = characteristic;
              
              // 启用通知
              await characteristic.setNotifyValue(true);
              
              // 监听通知
              _notificationSubscription = characteristic.lastValueStream.listen(
                _handleNotification,
                onError: (error) {
                  debugPrint('通知错误: $error');
                  onError?.call('通知错误: $error');
                },
              );
              
              debugPrint('✅ WiFi 配网服务初始化成功');
              return true;
            }
          }
        }
      }
      
      debugPrint('❌ 未找到 WiFi 配网服务');
      return false;
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      return false;
    }
  }

  /// 处理通知数据
  void _handleNotification(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      debugPrint('📩 收到数据: $jsonString');
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final cmd = json['cmd'] as String?;
      
      if (cmd == null) return;
      
      // 取消超时定时器
      _responseTimer?.cancel();
      
      // 处理响应
      switch (cmd) {
        case 'scan_wifi':
          _handleWiFiScanResponse(json);
          break;
        case 'wifi_config':
          _handleConfigResponse(json);
          break;
        case 'get_device_info':
        case 'get_saved_wifi':
        case 'delete_wifi':
          // 完成 Future
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.complete(json);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ JSON 解析失败: $e');
      onError?.call('数据解析失败');
      
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.completeError(e);
      }
    }
  }

  /// 处理 WiFi 扫描响应
  void _handleWiFiScanResponse(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    
    if (status == 'success') {
      final data = json['data'] as Map<String, dynamic>?;
      final networksJson = data?['networks'] as List?;
      
      if (networksJson != null) {
        final networks = networksJson
            .map((n) => WiFiNetwork.fromJson(n as Map<String, dynamic>))
            .toList();
        
        // 按信号强度排序
        networks.sort((a, b) => b.rssi.compareTo(a.rssi));
        
        debugPrint('✅ 收到 ${networks.length} 个 WiFi');
        onWiFiListReceived?.call(networks);
      }
    } else {
      final message = json['message'] as String? ?? 'WiFi 扫描失败';
      debugPrint('❌ $message');
      onError?.call(message);
    }
  }

  /// 处理配置响应
  void _handleConfigResponse(Map<String, dynamic> json) {
    final result = WiFiConfigResult.fromJson(json);
    debugPrint(result.success ? '✅ 配置成功' : '❌ 配置失败: ${result.friendlyMessage}');
    onConfigResult?.call(result);
  }

  /// 发送命令
  Future<void> _sendCommand(Map<String, dynamic> command, {int timeoutSeconds = 30}) async {
    if (_characteristic == null) {
      throw Exception('服务未初始化');
    }

    try {
      final jsonString = jsonEncode(command);
      final data = utf8.encode(jsonString);
      
      debugPrint('📤 发送命令: $jsonString');
      
      await _characteristic!.write(data, withoutResponse: false);
      
      // 设置超时定时器
      _responseTimer = Timer(Duration(seconds: timeoutSeconds), () {
        if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
          _responseCompleter!.completeError(TimeoutException('命令超时'));
        }
        onError?.call('操作超时，请重试');
      });
    } catch (e) {
      debugPrint('❌ 发送命令失败: $e');
      rethrow;
    }
  }

  /// 扫描 WiFi
  Future<void> scanWiFi() async {
    await _sendCommand({'cmd': 'scan_wifi'}, timeoutSeconds: 15);
  }

  /// 配置 WiFi
  Future<void> configureWiFi({
    required String ssid,
    required String password,
    String? bssid,
    int? timeout,
  }) async {
    final data = <String, dynamic>{
      'ssid': ssid,
      'password': password,
    };
    
    if (bssid != null) {
      data['bssid'] = bssid;
    }
    
    if (timeout != null) {
      data['timeout'] = timeout;
    }

    await _sendCommand({
      'cmd': 'wifi_config',
      'data': data,
    }, timeoutSeconds: 45);
  }

  /// 获取设备信息
  Future<Map<String, dynamic>> getDeviceInfo() async {
    _responseCompleter = Completer<Map<String, dynamic>>();
    
    try {
      await _sendCommand({'cmd': 'get_device_info'});
      return await _responseCompleter!.future;
    } finally {
      _responseCompleter = null;
    }
  }

  /// 获取已保存的 WiFi 列表
  Future<Map<String, dynamic>> getSavedWiFi() async {
    _responseCompleter = Completer<Map<String, dynamic>>();
    
    try {
      await _sendCommand({'cmd': 'get_saved_wifi'});
      return await _responseCompleter!.future;
    } finally {
      _responseCompleter = null;
    }
  }

  /// 删除已保存的 WiFi
  Future<Map<String, dynamic>> deleteWiFi(String ssid) async {
    _responseCompleter = Completer<Map<String, dynamic>>();
    
    try {
      await _sendCommand({
        'cmd': 'delete_wifi',
        'data': {'ssid': ssid},
      });
      return await _responseCompleter!.future;
    } finally {
      _responseCompleter = null;
    }
  }

  /// 释放资源
  void dispose() {
    _responseTimer?.cancel();
    _notificationSubscription?.cancel();
    _characteristic = null;
  }
}

