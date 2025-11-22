import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'wake_word_models.dart';

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
  
  // 唤醒词回调函数
  Function(WakeWordResult)? onWakeWordResult; // 设置/删除/重置结果
  Function(List<WakeWord>, double)? onWakeWordsReceived; // (words, threshold)

  BLEWiFiService(this.device);

  // 用于拼接分包数据
  String _dataBuffer = '';
  Timer? _dataTimeoutTimer;

  /// 初始化服务（发现特征并启用通知）
  Future<bool> initialize() async {
    try {
      debugPrint('[BLE WiFi] 开始初始化...');
      
      // 请求更大的 MTU（最大 512 字节）
      try {
        final mtu = await device.mtu.first;
        debugPrint('[BLE WiFi] 当前 MTU: $mtu');
        
        if (mtu < 512) {
          await device.requestMtu(512);
          final newMtu = await device.mtu.first;
          debugPrint('[BLE WiFi] 协商后 MTU: $newMtu');
        }
      } catch (e) {
        debugPrint('[BLE WiFi] MTU 协商失败: $e (继续使用默认值)');
      }
      
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
                _handleNotificationPacket,
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
      };
      
      // 🚀 只有当 password 不为空时才发送密码
      // 空密码表示使用设备已保存的密码（快速重连）
      if (password.isNotEmpty) {
        data['password'] = password;
        debugPrint('[BLE WiFi] 使用新密码配置');
      } else {
        debugPrint('[BLE WiFi] 使用已保存的密码重连');
      }
      
      if (bssid != null && bssid.isNotEmpty) {
        data['bssid'] = bssid;
      }
      
      final command = {
        'cmd': 'wifi_config',
        'data': data,
      };
      
      debugPrint('[BLE WiFi] 发送命令: $command');
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

  // ========================================
  // 唤醒词相关方法
  // ========================================

  /// 设置唤醒词
  /// 
  /// [words] 唤醒词列表
  /// [threshold] 检测阈值 (0.0-1.0)，默认 0.15
  /// [replace] 是否替换现有唤醒词，默认 true
  Future<bool> setWakeWords({
    required List<WakeWord> words,
    double threshold = 0.15,
    bool replace = true,
  }) async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    if (words.isEmpty) {
      onError?.call('唤醒词列表不能为空');
      return false;
    }

    if (words.length > 5) {
      onError?.call('最多支持5个唤醒词');
      return false;
    }

    try {
      debugPrint('[BLE Wake] 发送设置唤醒词命令: ${words.length}个');
      
      // 优化数据格式：精简 JSON 结构，减少数据大小
      final command = {
        'cmd': 'set_wake_words',
        'data': {
          'words': words.map((w) => _optimizeWakeWordData(w)).toList(),
          'threshold': threshold,
          'replace': replace,
        },
      };
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE Wake] 设置唤醒词失败: $e');
      onError?.call('设置唤醒词失败: $e');
      return false;
    }
  }

  /// 优化唤醒词数据格式，减少传输大小
  Map<String, dynamic> _optimizeWakeWordData(WakeWord word) {
    // 按设备端要求：text 全大写，display 全小写
    final textUpper = word.text.toUpperCase();
    final displayLower = word.text.toLowerCase(); // 使用原始文本的小写形式
    
    // 如果音素不为空，发送音素；否则发送空数组
    final phonemesToSend = word.phonemes.isNotEmpty ? word.phonemes : [];
    
    if (word.phonemes.isNotEmpty) {
      debugPrint('[BLE Wake] 发送唤醒词 "$textUpper" / "$displayLower" (音素: ${word.phonemes.length}个)');
    } else {
      debugPrint('[BLE Wake] 发送唤醒词 "$textUpper" / "$displayLower" (音素为空)');
    }
    
    return {
      'text': textUpper,        // 全大写：HI PLAUD
      'display': displayLower,  // 全小写：hi plaud
      'phonemes': phonemesToSend, // 根据实际情况发送音素或空数组
    };
  }

  /// 获取唤醒词列表
  Future<bool> getWakeWords() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE Wake] 发送获取唤醒词命令');
      
      final command = {'cmd': 'get_wake_words'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE Wake] 获取唤醒词失败: $e');
      onError?.call('获取唤醒词失败: $e');
      return false;
    }
  }

  /// 删除唤醒词
  /// 
  /// [text] 唤醒词文本（如："hi plaud"）
  Future<bool> deleteWakeWord(String text) async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    if (text.isEmpty) {
      onError?.call('唤醒词文本不能为空');
      return false;
    }

    try {
      debugPrint('[BLE Wake] 发送删除唤醒词命令: $text');
      
      final command = {
        'cmd': 'delete_wake_word',
        'data': {'text': text},
      };
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE Wake] 删除唤醒词失败: $e');
      onError?.call('删除唤醒词失败: $e');
      return false;
    }
  }

  /// 重置为默认唤醒词
  Future<bool> resetWakeWords() async {
    if (_characteristic == null) {
      onError?.call('服务未初始化');
      return false;
    }

    try {
      debugPrint('[BLE Wake] 发送重置唤醒词命令');
      
      final command = {'cmd': 'reset_wake_words'};
      
      await _sendCommand(command);
      return true;
    } catch (e) {
      debugPrint('[BLE Wake] 重置唤醒词失败: $e');
      onError?.call('重置唤醒词失败: $e');
      return false;
    }
  }

  /// 发送命令
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_characteristic == null) {
      throw Exception('特征未找到');
    }

    final jsonString = jsonEncode(command);
    // 添加换行符作为消息结束标记（与设备端协议保持一致）
    final jsonWithEnd = '$jsonString\n';
    final data = utf8.encode(jsonWithEnd);
    
    debugPrint('[BLE WiFi] 发送数据长度: ${data.length} 字节（含结束符）');
    debugPrint('[BLE WiFi] JSON内容: $jsonString');
    
    try {
      // BLE 特征值最大写入限制（保守值）
      const int maxChunkSize = 240;
      
      if (data.length <= maxChunkSize) {
        // 数据小于限制，直接发送
        debugPrint('[BLE WiFi] 直接发送: ${data.length} 字节');
        await _characteristic!.write(data, withoutResponse: false);
        debugPrint('[BLE WiFi] 数据发送成功');
      } else {
        // 数据过大，使用分包发送
        debugPrint('[BLE WiFi] 数据过大，启用分包传输: ${data.length} 字节');
        await _sendChunked(data);
      }
    } catch (e) {
      debugPrint('[BLE WiFi] 发送命令失败: $e');
      // 检查是否是设备断开连接的错误
      if (e.toString().contains('disconnected') || e.toString().contains('fbp-code: 6')) {
        debugPrint('[BLE WiFi] 检测到设备已断开，清理资源');
        _characteristic = null;
      }
      rethrow; // 重新抛出异常，让调用方处理
    }
  }

  /// 分片发送大数据（简单分片，无头部协议）
  /// 
  /// 将大数据分成多个小片段逐个发送
  /// 设备端会自动累积重组（通过查找 \n 或完整 JSON）
  Future<void> _sendChunked(List<int> data) async {
    if (_characteristic == null) {
      throw Exception('特征未找到');
    }

    const int maxChunkSize = 240; // 每片最大数据大小
    final int totalChunks = (data.length / maxChunkSize).ceil();
    
    if (totalChunks > 100) {
      throw Exception('数据包过大，需要 $totalChunks 个分片（最多支持100个）');
    }
    
    debugPrint('[BLE WiFi] ┌─ 分片传输开始 ─────────────');
    debugPrint('[BLE WiFi] │ 总大小: ${data.length} 字节');
    debugPrint('[BLE WiFi] │ 分片数: $totalChunks');
    debugPrint('[BLE WiFi] │ 每片大小: 最大 $maxChunkSize 字节');

    for (int i = 0; i < totalChunks; i++) {
      final start = i * maxChunkSize;
      final end = (start + maxChunkSize > data.length) 
          ? data.length 
          : start + maxChunkSize;
      
      final chunk = data.sublist(start, end);
      
      debugPrint('[BLE WiFi] │ 发送第 ${i + 1}/$totalChunks 片: ${chunk.length} 字节');
      
      try {
        // 直接发送数据片段（无头部）
        await _characteristic!.write(chunk, withoutResponse: false);
        
        // 片段之间稍微延迟，给设备时间处理
        if (i < totalChunks - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (e) {
        debugPrint('[BLE WiFi] │ ✗ 第 ${i + 1} 片发送失败: $e');
        throw Exception('第 ${i + 1}/$totalChunks 片发送失败: $e');
      }
    }
    
    debugPrint('[BLE WiFi] └─ 分片传输完成 ─────────────');
    debugPrint('[BLE WiFi] ✓ 成功发送 $totalChunks 个分片');
  }

  /// 处理通知数据包（可能分包）
  void _handleNotificationPacket(List<int> value) {
    try {
      final chunk = utf8.decode(value);
      
      // 累加数据到缓冲区
      _dataBuffer += chunk;
      
      // 取消之前的超时定时器（因为收到新数据了）
      _dataTimeoutTimer?.cancel();
      
      // 检查是否有完整消息（以 \n 结尾）
      while (_dataBuffer.contains('\n')) {
        final newlineIndex = _dataBuffer.indexOf('\n');
        final message = _dataBuffer.substring(0, newlineIndex);
        
        // 移除已处理的消息（包括 \n）
        _dataBuffer = _dataBuffer.substring(newlineIndex + 1);
        
        // 处理完整消息
        if (message.isNotEmpty) {
          debugPrint('[BLE WiFi] 收到完整消息 (${message.length} 字节)');
          _handleCompleteMessage(message);
        }
      }
      
      // 如果还有剩余数据（未以 \n 结尾），设置超时
      if (_dataBuffer.isNotEmpty) {
        if (_dataBuffer.length > 10000) {
          // 防止缓冲区无限增长
          debugPrint('[BLE WiFi] 缓冲区过大，清空: ${_dataBuffer.length} 字节');
          _dataBuffer = '';
          onError?.call('数据接收异常：缓冲区溢出');
        } else {
          debugPrint('[BLE WiFi] 等待更多数据... (当前: ${_dataBuffer.length} 字节)');
          
          // 设置 3 秒超时（防止设备端没有发送 \n）
          _dataTimeoutTimer = Timer(const Duration(seconds: 3), () {
            debugPrint('[BLE WiFi] 数据接收超时 (${_dataBuffer.length} 字节)');
            debugPrint('[BLE WiFi] 不完整的数据: $_dataBuffer');
            
            // 尝试修复并解析（兼容旧版设备）
            _tryRecoverData();
          });
        }
      }
    } catch (e) {
      debugPrint('[BLE WiFi] 数据包处理失败: $e');
      _dataBuffer = '';
      _dataTimeoutTimer?.cancel();
      _dataTimeoutTimer = null;
      onError?.call('数据处理失败: $e');
    }
  }

  /// 处理完整消息（以 \n 结尾的消息）
  void _handleCompleteMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      _handleCompleteData(json);
    } catch (e) {
      debugPrint('[BLE WiFi] JSON 解析失败: $e');
      debugPrint('[BLE WiFi] 消息内容: $message');
      onError?.call('JSON 解析失败: $e');
    }
  }

  /// 尝试修复不完整的数据
  void _tryRecoverData() {
    if (_dataBuffer.isEmpty) {
      return;
    }

    debugPrint('[BLE WiFi] 尝试修复数据...');
    
    // 尝试补全 JSON（简单修复）
    String fixedData = _dataBuffer;
    
    // 如果缺少结尾的 }
    int openBraces = fixedData.split('{').length - 1;
    int closeBraces = fixedData.split('}').length - 1;
    
    if (openBraces > closeBraces) {
      // 补全缺失的 }
      for (int i = 0; i < (openBraces - closeBraces); i++) {
        fixedData += '}';
      }
      debugPrint('[BLE WiFi] 补全了 ${openBraces - closeBraces} 个右括号');
    }
    
    // 尝试解析修复后的数据
    try {
      final json = jsonDecode(fixedData) as Map<String, dynamic>;
      debugPrint('[BLE WiFi] 数据修复成功！');
      _handleCompleteData(json);
      _dataBuffer = '';
    } catch (e) {
      debugPrint('[BLE WiFi] 数据修复失败: $e');
      debugPrint('[BLE WiFi] 原始数据: $_dataBuffer');
      _dataBuffer = '';
      onError?.call('数据接收不完整且无法修复');
    }
  }

  /// 处理完整的 JSON 数据
  void _handleCompleteData(Map<String, dynamic> json) {
    try {
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
        // 唤醒词相关命令
        case 'set_wake_words':
        case 'delete_wake_word':
        case 'reset_wake_words':
          _handleWakeWordResult(json);
          break;
        case 'get_wake_words':
          _handleGetWakeWordsResult(json);
          break;
        default:
          debugPrint('[BLE WiFi] 未知命令: $cmd');
      }
    } catch (e) {
      debugPrint('[BLE WiFi] 数据处理失败: $e');
      onError?.call('数据处理失败: $e');
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
    
    // 去重：同一个 SSID 只保留信号最强的
    final Map<String, WiFiNetwork> uniqueNetworks = {};
    for (var network in wifiList) {
      if (!uniqueNetworks.containsKey(network.ssid) ||
          network.rssi > uniqueNetworks[network.ssid]!.rssi) {
        uniqueNetworks[network.ssid] = network;
      }
    }
    
    final deduplicatedList = uniqueNetworks.values.toList();
    
    // 按信号强度排序
    deduplicatedList.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    debugPrint('[BLE WiFi] 收到 ${wifiList.length} 个 WiFi 网络（去重后 ${deduplicatedList.length} 个）');
    if (connectedSsid != null) {
      debugPrint('[BLE WiFi] 当前已连接: $connectedSsid ($connectedIp)');
    }
    
    onWiFiScanResult?.call(WiFiScanResult(
      networks: deduplicatedList,
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
    // 🔍 调试：打印完整的返回数据
    debugPrint('[BLE WiFi] 📦 收到已保存WiFi原始数据: $json');
    
    final status = json['status'] as String;
    debugPrint('[BLE WiFi] 📊 状态: $status');
    
    if (status != 'success') {
      final message = json['message'] as String? ?? '获取已保存WiFi失败';
      debugPrint('[BLE WiFi] ❌ 获取已保存WiFi失败: $message');
      onError?.call(message);
      return;
    }
    
    final data = json['data'] as Map<String, dynamic>?;
    debugPrint('[BLE WiFi] 📋 data字段: $data');
    
    if (data == null) {
      debugPrint('[BLE WiFi] ⚠️ 已保存WiFi结果无数据（data为null）');
      onSavedWiFiReceived?.call([]);
      return;
    }
    
    // 🔧 修复：设备返回的字段是 'networks' 而不是 'ssids'
    final networks = data['networks'] as List<dynamic>?;
    debugPrint('[BLE WiFi] 📃 networks列表: $networks');
    
    if (networks == null) {
      debugPrint('[BLE WiFi] ⚠️ 已保存WiFi结果无列表（networks为null）');
      onSavedWiFiReceived?.call([]);
      return;
    }
    
    if (networks.isEmpty) {
      debugPrint('[BLE WiFi] ℹ️ networks列表为空');
      onSavedWiFiReceived?.call([]);
      return;
    }
    
    try {
      final savedList = networks
          .map((item) {
            debugPrint('[BLE WiFi] 🔄 解析项: $item');
            final networkData = item as Map<String, dynamic>;
            // 设备返回的数据格式：{ssid: xxx, is_default: xxx, last_connected: xxx}
            // 转换为 SavedWiFi 需要的格式：{ssid: xxx, password: xxx}
            return SavedWiFi(
              ssid: networkData['ssid'] as String? ?? '',
              password: '********', // 设备不返回密码，显示占位符
            );
          })
          .toList();
      
      debugPrint('[BLE WiFi] ✅ 收到 ${savedList.length} 个已保存WiFi');
      for (var saved in savedList) {
        debugPrint('[BLE WiFi]   - ${saved.ssid}');
      }
      onSavedWiFiReceived?.call(savedList);
    } catch (e, stackTrace) {
      debugPrint('[BLE WiFi] ❌ 解析已保存WiFi失败: $e');
      debugPrint('[BLE WiFi] 堆栈: $stackTrace');
      onError?.call('解析已保存WiFi失败: $e');
      onSavedWiFiReceived?.call([]);
    }
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

  /// 处理唤醒词操作结果（设置/删除/重置）
  void _handleWakeWordResult(Map<String, dynamic> json) {
    final result = WakeWordResult.fromJson(json);
    final cmd = json['cmd'] as String?;
    
    if (result.success) {
      debugPrint('[BLE Wake] $cmd 成功: ${result.message}');
    } else {
      debugPrint('[BLE Wake] $cmd 失败: ${result.message} (错误码: ${result.errorCode})');
      // 输出原始 JSON 以便调试
      debugPrint('[BLE Wake] 设备返回的原始数据: ${jsonEncode(json)}');
    }
    
    onWakeWordResult?.call(result);
  }

  /// 处理获取唤醒词列表结果
  void _handleGetWakeWordsResult(Map<String, dynamic> json) {
    final status = json['status'] as String;
    
    if (status != 'success') {
      final message = json['message'] as String? ?? '获取唤醒词列表失败';
      debugPrint('[BLE Wake] 获取唤醒词列表失败: $message');
      onError?.call(message);
      return;
    }
    
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('[BLE Wake] 唤醒词列表结果无数据');
      onWakeWordsReceived?.call([], 0.15);
      return;
    }
    
    final words = data['words'] as List<dynamic>?;
    final threshold = (data['threshold'] as num?)?.toDouble() ?? 0.15;
    
    if (words == null) {
      debugPrint('[BLE Wake] 唤醒词列表为空');
      onWakeWordsReceived?.call([], threshold);
      return;
    }
    
    final wakeWordList = words
        .map((item) {
          final itemMap = item as Map<String, dynamic>;
          
          // 🔍 打印设备返回的原始数据
          debugPrint('[BLE Wake] 设备返回原始数据: text="${itemMap['text']}", phonemes=${itemMap['phonemes']}');
          
          final word = WakeWord.fromJson(itemMap);
          
          // 防御性处理：清理设备自动填充的无效音素
          // 场景1：音素只有1个且等于唤醒词本身
          // 场景2：音素只有1个且等于唤醒词本身去除空格后
          // 场景3：音素只有1个且包含唤醒词的所有字母（没有实际音素信息）
          if (word.phonemes.length == 1) {
            final phoneme = word.phonemes[0].toUpperCase().trim();
            final textClean = word.text.toUpperCase().trim();
            final textNoSpace = textClean.replaceAll(' ', '');
            
            // 检查是否是自动填充的（相同或只是去掉空格）
            if (phoneme == textClean || phoneme == textNoSpace || phoneme.replaceAll(' ', '') == textNoSpace) {
              debugPrint('[BLE Wake] ✂️ 检测到设备自动填充的音素: "${word.text}" -> "${word.phonemes[0]}"，已清空');
              return WakeWord(
                text: word.text,
                display: word.display,
                phonemes: [], // 清空自动填充的音素
              );
            }
          }
          
          return word;
        })
        .toList();
    
    debugPrint('[BLE Wake] 收到 ${wakeWordList.length} 个唤醒词，阈值: $threshold');
    onWakeWordsReceived?.call(wakeWordList, threshold);
  }

  /// 释放资源
  Future<void> dispose() async {
    debugPrint('[BLE WiFi] 释放资源');
    _dataTimeoutTimer?.cancel();
    _dataTimeoutTimer = null;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    _characteristic = null;
    _dataBuffer = ''; // 清空缓冲区
  }
}

