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
  final bool connected; // 是否为当前连接的WiFi

  WiFiNetwork({
    required this.ssid,
    required this.rssi,
    required this.channel,
    required this.authMode,
    this.bssid,
    this.connected = false,
  });

  factory WiFiNetwork.fromJson(Map<String, dynamic> json) {
    return WiFiNetwork(
      ssid: json['ssid'] as String? ?? '',
      rssi: json['rssi'] as int? ?? -100,
      channel: json['channel'] as int? ?? 0,
      authMode: json['auth_mode'] as int? ?? 0,
      bssid: json['bssid'] as String?,
      connected: json['connected'] as bool? ?? false,
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

/// WiFi 扫描结果（包含当前连接信息）
class WiFiScanResult {
  final List<WiFiNetwork> networks;
  final String? connectedSsid;
  final int? connectedRssi;
  final String? connectedIp;

  WiFiScanResult({
    required this.networks,
    this.connectedSsid,
    this.connectedRssi,
    this.connectedIp,
  });

  /// 是否已连接到WiFi
  bool get isConnected => connectedSsid != null && connectedSsid!.isNotEmpty;
}

/// 已保存的 WiFi 信息
class SavedWiFi {
  final String ssid;
  final String password; // 通常是 ******** 

  SavedWiFi({
    required this.ssid,
    required this.password,
  });

  factory SavedWiFi.fromJson(Map<String, dynamic> json) {
    return SavedWiFi(
      ssid: json['ssid'] as String? ?? '',
      password: json['password'] as String? ?? '********',
    );
  }
}

/// 设备信息
class DeviceInfo {
  final String deviceName;
  final String macAddress;
  final String firmwareVersion;
  final String chipModel;
  final String chipId;
  final int freeHeap;
  final int minFreeHeap;

  DeviceInfo({
    required this.deviceName,
    required this.macAddress,
    required this.firmwareVersion,
    required this.chipModel,
    required this.chipId,
    required this.freeHeap,
    required this.minFreeHeap,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceName: json['device_name'] as String? ?? 'Unknown',
      macAddress: json['mac_address'] as String? ?? 'Unknown',
      firmwareVersion: json['firmware_version'] as String? ?? 'Unknown',
      chipModel: json['chip_model'] as String? ?? 'Unknown',
      chipId: json['chip_id'] as String? ?? '0x00000000',
      freeHeap: json['free_heap'] as int? ?? 0,
      minFreeHeap: json['min_free_heap'] as int? ?? 0,
    );
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
  Function(WiFiScanResult)? onWiFiScanResult;
  Function(WiFiConfigResult)? onConfigResult;
  Function(List<SavedWiFi>)? onSavedWiFiReceived;
  Function(DeviceInfo)? onDeviceInfoReceived;
  Function(String, String)? onDisconnectResult; // (status, message)
  Function(String)? onDeleteResult; // message
  Function(String)? onClearResult; // message
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

  /// 断开 WiFi 连接
  Future<bool> disconnectWiFi() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送断开连接命令');
      
      final command = {'cmd': 'disconnect_wifi'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 断开连接失败: $e');
      onError?.call('断开连接失败: $e');
      return false;
    }
  }

  /// 清除所有 WiFi 配置
  Future<bool> clearWiFi() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送清除配置命令');
      
      final command = {'cmd': 'clear_wifi'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 清除配置失败: $e');
      onError?.call('清除配置失败: $e');
      return false;
    }
  }

  /// 获取已保存的 WiFi 列表
  Future<bool> getSavedWiFi() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送获取已保存WiFi命令');
      
      final command = {'cmd': 'get_saved_wifi'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 获取已保存WiFi失败: $e');
      onError?.call('获取已保存WiFi失败: $e');
      return false;
    }
  }

  /// 删除已保存的 WiFi
  Future<bool> deleteWiFi(String ssid) async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送删除WiFi命令: $ssid');
      
      final command = {
        'cmd': 'delete_wifi',
        'data': {'ssid': ssid},
      };
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 删除WiFi失败: $e');
      onError?.call('删除WiFi失败: $e');
      return false;
    }
  }

  /// 获取设备信息
  Future<bool> getDeviceInfo() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE WiFi] 发送获取设备信息命令');
      
      final command = {'cmd': 'get_device_info'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE WiFi] 获取设备信息失败: $e');
      onError?.call('获取设备信息失败: $e');
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
        case 'disconnect_wifi':
          _handleDisconnectResult(json);
          break;
        case 'clear_wifi':
          _handleClearResult(json);
          break;
        case 'get_saved_wifi':
          _handleSavedWiFiResult(json);
          break;
        case 'delete_wifi':
          _handleDeleteResult(json);
          break;
        case 'get_device_info':
          _handleDeviceInfoResult(json);
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
      onWiFiScanResult?.call(WiFiScanResult(networks: []));
      return;
    }
    
    // 获取当前连接的WiFi信息
    final connectedSsid = data['connected_ssid'] as String?;
    final connectedRssi = data['connected_rssi'] as int?;
    final connectedIp = data['connected_ip'] as String?;
    
    final networks = data['networks'] as List<dynamic>?;
    if (networks == null) {
      debugPrint('[BLE WiFi] WiFi 扫描结果无网络列表');
      onWiFiScanResult?.call(WiFiScanResult(
        networks: [],
        connectedSsid: connectedSsid,
        connectedRssi: connectedRssi,
        connectedIp: connectedIp,
      ));
      return;
    }
    
    final wifiList = networks
        .map((item) => WiFiNetwork.fromJson(item as Map<String, dynamic>))
        .toList();
    
    // 按信号强度排序
    wifiList.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    debugPrint('[BLE WiFi] 收到 ${wifiList.length} 个 WiFi 网络');
    if (connectedSsid != null) {
      debugPrint('[BLE WiFi] 当前已连接: $connectedSsid ($connectedIp)');
    }
    
    onWiFiScanResult?.call(WiFiScanResult(
      networks: wifiList,
      connectedSsid: connectedSsid,
      connectedRssi: connectedRssi,
      connectedIp: connectedIp,
    ));
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

  /// 处理断开WiFi结果
  void _handleDisconnectResult(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';
    final message = json['message'] as String? ?? '断开连接失败';
    
    debugPrint('[BLE WiFi] 断开WiFi: $message');
    onDisconnectResult?.call(status, message);
  }

  /// 处理清除WiFi结果
  void _handleClearResult(Map<String, dynamic> json) {
    final message = json['message'] as String? ?? 'WiFi配置已清除';
    
    debugPrint('[BLE WiFi] 清除WiFi配置: $message');
    onClearResult?.call(message);
  }

  /// 处理已保存WiFi列表
  void _handleSavedWiFiResult(Map<String, dynamic> json) {
    final status = json['status'] as String;
    
    if (status != 'success') {
      final message = json['message'] as String? ?? '获取已保存WiFi失败';
      debugPrint('[BLE WiFi] 获取已保存WiFi失败: $message');
      onError?.call(message);
      return;
    }
    
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('[BLE WiFi] 已保存WiFi结果无数据');
      onSavedWiFiReceived?.call([]);
      return;
    }
    
    final ssids = data['ssids'] as List<dynamic>?;
    if (ssids == null) {
      debugPrint('[BLE WiFi] 已保存WiFi结果无列表');
      onSavedWiFiReceived?.call([]);
      return;
    }
    
    final savedList = ssids
        .map((item) => SavedWiFi.fromJson(item as Map<String, dynamic>))
        .toList();
    
    debugPrint('[BLE WiFi] 收到 ${savedList.length} 个已保存WiFi');
    onSavedWiFiReceived?.call(savedList);
  }

  /// 处理删除WiFi结果
  void _handleDeleteResult(Map<String, dynamic> json) {
    final message = json['message'] as String? ?? 'WiFi配置已删除';
    
    debugPrint('[BLE WiFi] 删除WiFi: $message');
    onDeleteResult?.call(message);
  }

  /// 处理设备信息结果
  void _handleDeviceInfoResult(Map<String, dynamic> json) {
    final status = json['status'] as String;
    
    if (status != 'success') {
      final message = json['message'] as String? ?? '获取设备信息失败';
      debugPrint('[BLE WiFi] 获取设备信息失败: $message');
      onError?.call(message);
      return;
    }
    
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('[BLE WiFi] 设备信息结果无数据');
      onError?.call('设备信息结果无数据');
      return;
    }
    
    final deviceInfo = DeviceInfo.fromJson(data);
    
    debugPrint('[BLE WiFi] 收到设备信息: ${deviceInfo.deviceName} (${deviceInfo.firmwareVersion})');
    onDeviceInfoReceived?.call(deviceInfo);
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('[BLE WiFi] 释放资源');
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _characteristic = null;
  }
}

