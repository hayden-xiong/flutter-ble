import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';

/// WiFi 配网页面
class WiFiProvisioningPage extends StatefulWidget {
  final BluetoothDevice device;

  const WiFiProvisioningPage({
    super.key,
    required this.device,
  });

  @override
  State<WiFiProvisioningPage> createState() => _WiFiProvisioningPageState();
}

class _WiFiProvisioningPageState extends State<WiFiProvisioningPage> {
  late BLEWiFiService _wifiService;
  
  bool _isInitializing = true;
  bool _isScanning = false;
  bool _isConfiguring = false;
  
  List<WiFiNetwork> _wifiList = [];
  String? _errorMessage;
  
  // 当前连接的WiFi信息
  String? _connectedSsid;
  int? _connectedRssi;
  String? _connectedIp;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    _wifiService = BLEWiFiService(widget.device);
    
    // 设置回调
    _wifiService.onWiFiScanResult = (result) {
      if (mounted) {
        setState(() {
          _wifiList = result.networks;
          _connectedSsid = result.connectedSsid;
          _connectedRssi = result.connectedRssi;
          _connectedIp = result.connectedIp;
          _isScanning = false;
        });
      }
    };
    
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
    
    _wifiService.onError = (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isScanning = false;
          _isConfiguring = false;
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
    } else {
      setState(() {
        _errorMessage = '设备不支持 WiFi 配网功能';
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

  void _showPasswordDialog(WiFiNetwork network) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Expanded(child: Text('输入 WiFi 密码')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WiFi 信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.network_wifi, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            network.ssid,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSignalIcon(network.signalLevel),
                        const SizedBox(width: 6),
                        Text(
                          network.signalDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.lock, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          network.authModeDescription,
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
              const SizedBox(height: 16),
              // 密码输入框
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'WiFi 密码',
                  hintText: '请输入 WiFi 密码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
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
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Text(
                '密码长度需为 8-63 个字符',
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
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.length < 8 || password.length > 63) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密码长度需为 8-63 个字符')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _configureWiFi(network, password);
              },
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
              Navigator.of(context).pop(); // 返回设备详情页
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('WiFi 配置'),
        elevation: 0,
        actions: [
          if (!_isScanning && !_isInitializing && !_isConfiguring)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startWiFiScan,
              tooltip: '重新扫描',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 初始化中
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在初始化 WiFi 配网服务...'),
          ],
        ),
      );
    }

    // 配置中
    if (_isConfiguring) {
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

    // 错误信息
    if (_errorMessage != null) {
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
    if (_isScanning) {
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
    return Column(
      children: [
        // 当前连接的WiFi（如果有）
        if (_connectedSsid != null) _buildConnectedWiFiBar(),
        // 顶部提示
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
                  '找到 ${_wifiList.length} 个 WiFi 网络，选择一个进行配置',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        // WiFi 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: _startWiFiScan,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _wifiList.length,
              itemBuilder: (context, index) {
                return _buildWiFiCard(_wifiList[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedWiFiBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.green[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.wifi, color: Colors.green[700], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '已连接: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _connectedSsid!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_connectedIp != null)
                  Text(
                    'IP: $_connectedIp',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _showDisconnectDialog,
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('断开'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiCard(WiFiNetwork network) {
    final isConnected = network.connected;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isConnected ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isConnected
            ? BorderSide(color: Colors.green[300]!, width: 2)
            : BorderSide.none,
      ),
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
              // WiFi 图标和信号强度
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.withValues(alpha: 0.15)
                      : _getSignalColor(network.signalLevel).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildSignalIcon(network.signalLevel, size: 32),
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
                              fontWeight: FontWeight.bold,
                              color: isConnected ? Colors.green[900] : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 12, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '已连接',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isConnected && network.needsPassword)
                          Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getSignalColor(network.signalLevel).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            network.signalDescription,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getSignalColor(network.signalLevel),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          network.authModeDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${network.rssi} dBm',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isConnected)
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
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
              Navigator.of(context).pop();
              
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
              
              // 设置断开结果回调
              _wifiService.onDisconnectResult = (status, message) {
                if (mounted) {
                  Navigator.of(context).pop(); // 关闭加载对话框
                  
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
              
              await _wifiService.disconnectWiFi();
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

  Widget _buildSignalIcon(int level, {double size = 20}) {
    IconData icon;
    Color color;
    
    switch (level) {
      case 4:
        icon = Icons.signal_wifi_4_bar;
        color = Colors.green;
        break;
      case 3:
        icon = Icons.signal_wifi_4_bar;
        color = Colors.lightGreen;
        break;
      case 2:
        icon = Icons.signal_wifi_4_bar;
        color = Colors.orange;
        break;
      case 1:
        icon = Icons.signal_wifi_4_bar;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.signal_wifi_0_bar;
        color = Colors.red;
    }
    
    return Icon(icon, size: size, color: color);
  }

  Color _getSignalColor(int level) {
    switch (level) {
      case 4:
        return Colors.green;
      case 3:
        return Colors.lightGreen;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }
}
