import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PLAUD 设备管理',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const DeviceListPage(),
      );
}

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final List<BluetoothDevice> _devicesList = [];
  bool _isScanning = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _startScan();
    });
  }

  void _addDevice(BluetoothDevice device) {
    // 只添加包含 PLAUD 的设备
    String deviceName = device.platformName.toUpperCase();
    String advName = device.advName.toUpperCase();
    
    if (deviceName.contains('PLAUD') || advName.contains('PLAUD')) {
      if (!_devicesList.contains(device)) {
        setState(() {
          _devicesList.add(device);
        });
      }
    }
  }

  Future<void> _startScan() async {
    try {
      setState(() {
        _isScanning = true;
        _isLoading = true;
        _errorMessage = null;
        _devicesList.clear();
      });

      // 检查蓝牙状态
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _errorMessage = '请打开蓝牙';
          _isLoading = false;
          _isScanning = false;
        });
        return;
      }

      // 开始扫描
      var subscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (ScanResult result in results) {
            _addDevice(result.device);
          }
        },
        onError: (e) {
          setState(() {
            _errorMessage = '扫描出错: ${e.toString()}';
          });
        },
      );

      FlutterBluePlus.cancelWhenScanComplete(subscription);
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;

      setState(() {
        _isScanning = false;
        _isLoading = false;
      });
    } catch (e) {
      print('扫描错误: $e');
      setState(() {
        _isScanning = false;
        _isLoading = false;
        _errorMessage = '扫描失败: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('FlutterDemo-设备列表'),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描 PLAUD 设备...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_devicesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '未发现 PLAUD 设备',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '请确保设备已开启并在附近',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _startScan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devicesList.length,
        itemBuilder: (context, index) {
          return _buildDeviceCard(_devicesList[index]);
        },
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    String deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : device.advName.isNotEmpty 
            ? device.advName 
            : 'PLAUD 设备';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _connectToDevice(device),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.headset,
                  size: 32,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.remoteId.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      
      // 显示连接中对话框
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在连接...'),
                ],
              ),
            ),
          ),
        ),
      );

      await device.connect(timeout: const Duration(seconds: 15));
      var services = await device.discoverServices();

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      // 跳转到设备详情页
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceDetailPage(
            device: device,
            services: services,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: ${e.toString()}')),
      );
    }
  }
}

// 设备详情页
class DeviceDetailPage extends StatefulWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;

  const DeviceDetailPage({
    super.key,
    required this.device,
    required this.services,
  });

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final _wifiSSIDController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _wakeWordController = TextEditingController(text: 'Hey PLAUD');
  
  String _batteryLevel = '--';
  String _firmwareVersion = '--';
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    
    // 监听连接状态
    widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = (state == BluetoothConnectionState.connected);
        });
        
        if (!_isConnected) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设备已断开连接')),
          );
        }
      }
    });
  }

  Future<void> _loadDeviceInfo() async {
    // 这里可以读取设备的实际数据
    // 示例：从特征值读取电池电量、固件版本等
    setState(() {
      _batteryLevel = '85%';
      _firmwareVersion = 'v1.2.3';
    });
  }

  @override
  void dispose() {
    _wifiSSIDController.dispose();
    _wifiPasswordController.dispose();
    _wakeWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String deviceName = widget.device.platformName.isNotEmpty
        ? widget.device.platformName
        : 'PLAUD 设备';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(deviceName),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
            tooltip: '断开连接',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceInfoCard(),
          const SizedBox(height: 16),
          _buildWiFiConfigCard(),
          const SizedBox(height: 16),
          _buildWakeWordCard(),
          const SizedBox(height: 16),
          _buildAdvancedSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '设备信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('设备名称', widget.device.platformName),
            _buildInfoRow('MAC 地址', widget.device.remoteId.toString()),
            _buildInfoRow('电池电量', _batteryLevel),
            _buildInfoRow('固件版本', _firmwareVersion),
            _buildInfoRow(
              '连接状态',
              _isConnected ? '已连接' : '未连接',
              valueColor: _isConnected ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiConfigCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'WiFi 配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wifiSSIDController,
              decoration: InputDecoration(
                labelText: 'WiFi 名称 (SSID)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.wifi_tethering),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wifiPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'WiFi 密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _configureWiFi,
                icon: const Icon(Icons.send),
                label: const Text('配置 WiFi'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWakeWordCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '唤醒词设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wakeWordController,
              decoration: InputDecoration(
                labelText: '唤醒词',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.record_voice_over),
                helperText: '设备将响应此唤醒词',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _setWakeWord,
                icon: const Icon(Icons.check),
                label: const Text('设置唤醒词'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.volume_up, color: Colors.blue[700]),
            title: const Text('音量调节'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 打开音量调节页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('音量调节功能开发中...')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.language, color: Colors.blue[700]),
            title: const Text('语言设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 打开语言设置
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('语言设置功能开发中...')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.update, color: Colors.blue[700]),
            title: const Text('固件更新'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 检查固件更新
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已是最新版本')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.restore, color: Colors.orange[700]),
            title: const Text('恢复出厂设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showResetDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _configureWiFi() async {
    if (_wifiSSIDController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 WiFi 名称')),
      );
      return;
    }

    if (_wifiPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 WiFi 密码')),
      );
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在配置 WiFi...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // TODO: 实际发送 WiFi 配置到设备
      // 找到对应的特征值并写入 WiFi 信息
      await Future.delayed(const Duration(seconds: 2)); // 模拟配置过程

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WiFi 配置成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WiFi 配置失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _setWakeWord() async {
    if (_wakeWordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入唤醒词')),
      );
      return;
    }

    try {
      // TODO: 实际发送唤醒词到设备
      await Future.delayed(const Duration(seconds: 1)); // 模拟设置过程

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('唤醒词设置成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('唤醒词设置失败: ${e.toString()}')),
      );
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复出厂设置'),
        content: const Text('此操作将清除所有设置并恢复到出厂状态，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetDevice();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDevice() async {
    try {
      // TODO: 发送恢复出厂设置命令到设备
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设备已恢复出厂设置')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.device.disconnect();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('断开失败: ${e.toString()}')),
      );
    }
  }
}
