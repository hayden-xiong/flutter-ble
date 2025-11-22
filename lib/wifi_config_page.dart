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
    setState(() {
      _isConfiguring = true;
      _errorMessage = null;
    });

    // 🚀 设备端支持：只需发送 ssid，设备会使用已保存的密码
    await _wifiService.configureWiFi(
      ssid: savedWiFi.ssid,
      password: '', // 空密码表示使用设备已保存的密码
    );

    // 设置超时
    Future.delayed(const Duration(seconds: 40), () {
      if (mounted && _isConfiguring) {
        setState(() {
          _isConfiguring = false;
        });
        _showErrorDialog('重连超时，请重试');
      }
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi, color: Colors.blue[700], size: 24),
            const SizedBox(width: 12),
            const Text('快速重连'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '要重新连接到 ${savedWiFi.ssid} 吗？',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '将使用已保存的密码自动连接',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
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
                    Icon(Icons.swap_horiz, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前已连接到 $_connectedSsid，将切换网络',
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
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reconnectWiFi(savedWiFi);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'WiFi 配置',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: _isInitializing ? null : PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF1976D2),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.wifi_find),
                  text: '可用网络',
                ),
                Tab(
                  icon: Icon(Icons.bookmark_outline),
                  text: '已保存网络',
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!_isInitializing)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
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
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '正在初始化 WiFi 配置服务...',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF757575),
                    ),
                  ),
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
          
          // WiFi列表 - 过滤掉已连接的WiFi（避免重复显示）
          final wifiIndex = _connectedSsid != null ? index - 1 : index;
          final network = _wifiList[wifiIndex];
          
          // 如果这个WiFi已经在顶部显示了，跳过
          if (_connectedSsid != null && network.ssid == _connectedSsid) {
            return const SizedBox.shrink(); // 返回空widget
          }
          
          return _buildWiFiCard(network);
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
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '已保存 ${_savedList.length} 个 WiFi 配置',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
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
                  _showPasswords ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: const Color(0xFF1976D2),
                ),
                label: Text(
                  _showPasswords ? '隐藏' : '显示',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1976D2),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
        // 底部清除按钮（类似参考设计的底部按钮）
        if (_savedList.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoadingSaved ? null : _showClearAllDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '清除所有 WiFi 配置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectedWiFiBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // 淡绿色背景
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // WiFi 图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.wifi, color: Color(0xFF4CAF50), size: 32),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.check_circle, size: 20, color: Color(0xFF4CAF50)),
                  ],
                ),
                if (_connectedIp != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'IP: $_connectedIp',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 断开按钮
          TextButton(
            onPressed: _showDisconnectDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '断开',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiCard(WiFiNetwork network) {
    final isConnected = network.connected;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? const Color(0xFF4CAF50).withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // 如果是已连接的WiFi，提示用户
            if (isConnected) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已连接到 ${network.ssid}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // WiFi 图标
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.wifi,
                    size: 28,
                    color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFF757575),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFF212121),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isConnected)
                            const Icon(Icons.check_circle, size: 20, color: Color(0xFF4CAF50)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // 信号强度标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getSignalColor(network.signalLevel).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              network.signalDescription,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getSignalColor(network.signalLevel),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 加密类型标签
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (network.needsPassword) ...[
                                  Icon(Icons.lock, size: 10, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  network.authModeDescription,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getSignalColor(int level) {
    switch (level) {
      case 4:
      case 3:
        return const Color(0xFF4CAF50); // 绿色
      case 2:
        return const Color(0xFFFFA726); // 橙色
      default:
        return const Color(0xFFEF5350); // 红色
    }
  }

  Widget _buildSavedWiFiCard(SavedWiFi wifi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showReconnectDialog(wifi),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // 播放/重连图标（类似参考设计）
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 28,
                    color: Color(0xFF1976D2),
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
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // 密码显示（类似参考设计的标签）
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(
                                  _showPasswords ? wifi.password : '••••••••',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
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
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFEF5350),
                  onPressed: _isLoadingSaved ? null : () => _showDeleteDialog(wifi.ssid),
                  tooltip: '删除',
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

