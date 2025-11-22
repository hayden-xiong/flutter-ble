import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';

/// WiFi 配置页面 - 统一管理 WiFi 配网和已保存的 WiFi
class WiFiConfigPage extends StatefulWidget {
  final BluetoothDevice device;

  const WiFiConfigPage({
    super.key,
    required this.device,
  });

  @override
  State<WiFiConfigPage> createState() => _WiFiConfigPageState();
}

class _WiFiConfigPageState extends State<WiFiConfigPage> with SingleTickerProviderStateMixin {
  late BLEWiFiService _wifiService;
  late TabController _tabController;
  
  bool _isInitializing = true;
  bool _isScanning = false;
  bool _isConfiguring = false;
  bool _isLoadingSaved = false;
  
  List<WiFiNetwork> _wifiList = [];
  List<SavedWiFi> _savedList = [];
  String? _errorMessage;
  
  // 当前连接的WiFi信息
  String? _connectedSsid;
  String? _connectedIp;
  
  // 密码显示控制
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initService();
  }

  Future<void> _initService() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    _wifiService = BLEWiFiService(widget.device);
    
    // 设置扫描结果回调
    _wifiService.onWiFiScanResult = (result) {
      if (mounted) {
        setState(() {
          _wifiList = result.networks;
          _connectedSsid = result.connectedSsid;
          _connectedIp = result.connectedIp;
          _isScanning = false;
        });
      }
    };
    
    // 设置配置结果回调
    _wifiService.onConfigResult = (result) {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
        
        if (result.success) {
          _showSuccessDialog(result);
        } else {
          _showErrorDialog(result.getErrorDescription());
        }
      }
    };
    
    // 设置已保存WiFi回调
    _wifiService.onSavedWiFiReceived = (savedList) {
      if (mounted) {
        setState(() {
          _savedList = savedList;
          _isLoadingSaved = false;
        });
      }
    };
    
    // 设置删除结果回调
    _wifiService.onDeleteResult = (message) {
      if (mounted) {
        setState(() {
          _isLoadingSaved = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        
        // 重新加载列表
        _loadSavedWiFi();
      }
    };
    
    // 设置清除结果回调
    _wifiService.onClearResult = (message) {
      if (mounted) {
        setState(() {
          _isLoadingSaved = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
        
        // 等待设备重启
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // 返回设备详情页
          }
        });
      }
    };
    
    // 设置断开结果回调
    _wifiService.onDisconnectResult = (status, message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: status == 'success' ? Colors.green : Colors.red,
          ),
        );
        
        if (status == 'success') {
          // 重新扫描WiFi列表
          _startWiFiScan();
        }
      }
    };
    
    // 设置错误回调
    _wifiService.onError = (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isScanning = false;
          _isConfiguring = false;
          _isLoadingSaved = false;
        });
      }
    };

    // 初始化服务
    final success = await _wifiService.initialize();
    
    if (!mounted) return;
    
    setState(() {
      _isInitializing = false;
    });

    if (success) {
      // 自动开始扫描
      _startWiFiScan();
      // 加载已保存的WiFi
      _loadSavedWiFi();
    } else {
      setState(() {
        _errorMessage = '设备不支持 WiFi 配置功能';
      });
    }
  }

  Future<void> _startWiFiScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _wifiList.clear();
    });

    await _wifiService.scanWiFi();
    
    // 设置超时
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isScanning) {
        setState(() {
          _isScanning = false;
          if (_wifiList.isEmpty) {
            _errorMessage = 'WiFi 扫描超时，请重试';
          }
        });
      }
    });
  }

  Future<void> _loadSavedWiFi() async {
    setState(() {
      _isLoadingSaved = true;
    });

    await _wifiService.getSavedWiFi();
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoadingSaved) {
        setState(() {
          _isLoadingSaved = false;
        });
      }
    });
  }

  Future<void> _configureWiFi(WiFiNetwork network, String password) async {
    setState(() {
      _isConfiguring = true;
      _errorMessage = null;
    });

    await _wifiService.configureWiFi(
      ssid: network.ssid,
      password: password,
      bssid: network.bssid,
    );

    // 设置超时
    Future.delayed(const Duration(seconds: 40), () {
      if (mounted && _isConfiguring) {
        setState(() {
          _isConfiguring = false;
        });
        _showErrorDialog('配置超时，请检查密码是否正确并重试');
      }
    });
  }

  Future<void> _reconnectWiFi(SavedWiFi savedWiFi) async {
    // 从WiFi列表中找到对应的网络
    WiFiNetwork? network;
    for (var wifi in _wifiList) {
      if (wifi.ssid == savedWiFi.ssid) {
        network = wifi;
        break;
      }
    }
    
    // 如果列表中没有，创建一个临时的网络对象
    network ??= WiFiNetwork(
      ssid: savedWiFi.ssid,
      rssi: -50,
      channel: 1,
      authMode: 3, // 假设是 WPA2
      bssid: '',
    );
    
    // 使用保存的密码重新连接
    await _configureWiFi(network, savedWiFi.password);
  }

  Future<void> _deleteWiFi(String ssid) async {
    setState(() {
      _isLoadingSaved = true;
    });

    await _wifiService.deleteWiFi(ssid);
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoadingSaved) {
        setState(() {
          _isLoadingSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除超时，请重试')),
        );
      }
    });
  }

  Future<void> _clearAllWiFi() async {
    setState(() {
      _isLoadingSaved = true;
    });

    await _wifiService.clearWiFi();
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoadingSaved) {
        setState(() {
          _isLoadingSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作超时，请重试')),
        );
      }
    });
  }

  void _showPasswordDialog(WiFiNetwork network, {bool isReconnect = false}) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.wifi, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isReconnect ? '重新连接 WiFi' : '输入 WiFi 密码',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WiFi 信息卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.network_wifi, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            network.ssid,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${network.signalDescription} · ${network.authModeDescription}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 密码输入框
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'WiFi 密码',
                  hintText: '请输入 WiFi 密码',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '密码长度为 8-63 个字符',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入密码')),
                  );
                  return;
                }
                if (password.length < 8 || password.length > 63) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密码长度必须为 8-63 个字符')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _configureWiFi(network, password);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(WiFiConfigResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Text('配置成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: const TextStyle(fontSize: 16),
            ),
            if (result.ip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.ssid != null)
                      _buildInfoRow('WiFi', result.ssid!),
                    if (result.ip != null)
                      _buildInfoRow('IP 地址', result.ip!),
                    if (result.rssi != null)
                      _buildInfoRow('信号强度', '${result.rssi} dBm'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '设备即将重启并连接到 WiFi\n约需 5-10 秒',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              // 刷新列表
              _startWiFiScan();
              _loadSavedWiFi();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 32),
            const SizedBox(width: 12),
            const Text('配置失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 20, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '请检查密码是否正确\n或尝试重新扫描 WiFi',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startWiFiScan();
            },
            child: const Text('重新扫描'),
          ),
        ],
      ),
    );
  }

  void _showSwitchWiFiDialog(WiFiNetwork network) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('切换 WiFi'),
        content: Text(
          '当前已连接到 $_connectedSsid\n\n是否切换到 ${network.ssid}？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (network.needsPassword) {
                _showPasswordDialog(network);
              } else {
                _configureWiFi(network, '');
              }
            },
            child: const Text('切换'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.link_off, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('断开 WiFi'),
          ],
        ),
        content: Text('确定要断开当前WiFi连接吗？\n\n当前连接：$_connectedSsid'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              
              // 显示加载状态
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
                          Text('正在断开连接...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              
              await _wifiService.disconnectWiFi();
              
              if (mounted) {
                navigator.pop(); // 关闭加载对话框
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            child: const Text('断开'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String ssid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 WiFi'),
        content: Text('确定要删除 $ssid 的配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteWiFi(ssid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('清除所有 WiFi 配置'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '此操作将：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 删除所有已保存的 WiFi 配置'),
            Text('• 断开当前 WiFi 连接'),
            Text('• 设备将自动重启'),
            SizedBox(height: 12),
            Text(
              '此操作不可恢复！',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllWiFi();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
            ),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  void _showReconnectDialog(SavedWiFi savedWiFi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新连接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('是否使用保存的密码重新连接到 ${savedWiFi.ssid}？'),
            if (_connectedSsid != null && _connectedSsid != savedWiFi.ssid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前已连接到 $_connectedSsid',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reconnectWiFi(savedWiFi);
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _wifiService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('WiFi 配置'),
        elevation: 0,
        bottom: _isInitializing ? null : TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.wifi_find),
              text: '可用网络',
            ),
            Tab(
              icon: Icon(Icons.bookmark),
              text: '已保存网络',
            ),
          ],
        ),
        actions: [
          if (!_isInitializing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (_tabController.index == 0) {
                  _startWiFiScan();
                } else {
                  _loadSavedWiFi();
                }
              },
              tooltip: '刷新',
            ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在初始化 WiFi 配置服务...'),
                ],
              ),
            )
          : _isConfiguring
              ? _buildConfiguringView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailableNetworksTab(),
                    _buildSavedNetworksTab(),
                  ],
                ),
    );
  }

  Widget _buildConfiguringView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 5),
          ),
          const SizedBox(height: 24),
          const Text(
            '正在配置 WiFi...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '请稍候，最多需要 30 秒',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '设备正在连接 WiFi\n请保持蓝牙连接',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableNetworksTab() {
    // 错误信息
    if (_errorMessage != null && _wifiList.isEmpty && !_isScanning) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startWiFiScan,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 扫描中
    if (_isScanning && _wifiList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描 WiFi 网络...'),
            SizedBox(height: 8),
            Text(
              '约需 5-10 秒',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // WiFi 列表为空
    if (_wifiList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '未发现 WiFi 网络',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startWiFiScan,
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      );
    }

    // WiFi 列表
    return RefreshIndicator(
      onRefresh: _startWiFiScan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _wifiList.length + (_connectedSsid != null ? 1 : 0),
        itemBuilder: (context, index) {
          // 第一项显示已连接的WiFi
          if (_connectedSsid != null && index == 0) {
            return _buildConnectedWiFiBar();
          }
          
          // WiFi列表
          final wifiIndex = _connectedSsid != null ? index - 1 : index;
          return _buildWiFiCard(_wifiList[wifiIndex]);
        },
      ),
    );
  }

  Widget _buildSavedNetworksTab() {
    // 加载中
    if (_isLoadingSaved && _savedList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载已保存的 WiFi...'),
          ],
        ),
      );
    }

    // WiFi 列表为空
    if (_savedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '没有已保存的 WiFi',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '配置 WiFi 后会自动保存',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadSavedWiFi,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    // WiFi 列表
    return Column(
      children: [
        // 顶部提示和密码显示切换
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已保存 ${_savedList.length} 个 WiFi 配置',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ),
              // 密码显示切换按钮
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPasswords = !_showPasswords;
                  });
                },
                icon: Icon(
                  _showPasswords ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                label: Text(_showPasswords ? '隐藏密码' : '显示密码'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        // WiFi 列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _savedList.length,
            itemBuilder: (context, index) {
              return _buildSavedWiFiCard(_savedList[index]);
            },
          ),
        ),
        // 底部清除按钮
        if (_savedList.isNotEmpty)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoadingSaved ? null : _showClearAllDialog,
                icon: const Icon(Icons.delete_forever),
                label: const Text('清除所有 WiFi 配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectedWiFiBar() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // WiFi 图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.wifi, color: Colors.green[700], size: 32),
            ),
            const SizedBox(width: 16),
            // WiFi 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _connectedSsid!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_connectedIp != null)
                    Text(
                      'IP: $_connectedIp',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 断开按钮
            TextButton(
              onPressed: _showDisconnectDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(50, 32),
              ),
              child: Text('断开', style: TextStyle(color: Colors.red[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiCard(WiFiNetwork network) {
    final isConnected = network.connected;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 如果是已连接的WiFi，提示用户
          if (isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已连接到 ${network.ssid}'),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          
          // 如果当前已连接其他WiFi，询问是否切换
          if (_connectedSsid != null && _connectedSsid != network.ssid) {
            _showSwitchWiFiDialog(network);
            return;
          }
          
          if (network.needsPassword) {
            _showPasswordDialog(network);
          } else {
            // 开放网络，直接连接
            _configureWiFi(network, '');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // WiFi 图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.wifi,
                  size: 32,
                  color: isConnected ? Colors.green[700] : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              // WiFi 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            network.ssid,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConnected)
                          Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                        if (!isConnected && network.needsPassword)
                          Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${network.signalDescription} · ${network.authModeDescription} · ${network.rssi} dBm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedWiFiCard(SavedWiFi wifi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReconnectDialog(wifi),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // WiFi 图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bookmark,
                  size: 32,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              // WiFi 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wifi.ssid,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          _showPasswords ? wifi.password : '••••••••',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 删除按钮
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red[600]),
                onPressed: _isLoadingSaved ? null : () => _showDeleteDialog(wifi.ssid),
                tooltip: '删除',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

