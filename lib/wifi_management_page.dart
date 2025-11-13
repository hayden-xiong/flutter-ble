import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';

/// WiFi 管理页面 - 管理已保存的WiFi
class WiFiManagementPage extends StatefulWidget {
  final BluetoothDevice device;

  const WiFiManagementPage({
    super.key,
    required this.device,
  });

  @override
  State<WiFiManagementPage> createState() => _WiFiManagementPageState();
}

class _WiFiManagementPageState extends State<WiFiManagementPage> {
  late BLEWiFiService _wifiService;
  
  bool _isInitializing = true;
  bool _isLoading = false;
  
  List<SavedWiFi> _savedList = [];
  String? _errorMessage;

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
    _wifiService.onSavedWiFiReceived = (savedList) {
      if (mounted) {
        setState(() {
          _savedList = savedList;
          _isLoading = false;
        });
      }
    };
    
    _wifiService.onDeleteResult = (message) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    
    _wifiService.onClearResult = (message) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    
    _wifiService.onError = (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
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
      // 自动加载已保存的WiFi列表
      _loadSavedWiFi();
    } else {
      setState(() {
        _errorMessage = '设备不支持 WiFi 管理功能';
      });
    }
  }

  Future<void> _loadSavedWiFi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _wifiService.getSavedWiFi();
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载超时，请重试';
        });
      }
    });
  }

  Future<void> _deleteWiFi(String ssid) async {
    setState(() {
      _isLoading = true;
    });

    await _wifiService.deleteWiFi(ssid);
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除超时，请重试')),
        );
      }
    });
  }

  Future<void> _clearAllWiFi() async {
    setState(() {
      _isLoading = true;
    });

    await _wifiService.clearWiFi();
    
    // 设置超时
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作超时，请重试')),
        );
      }
    });
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
        title: const Text('WiFi 管理'),
        elevation: 0,
        actions: [
          if (!_isLoading && !_isInitializing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSavedWiFi,
              tooltip: '刷新',
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _savedList.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showClearAllDialog,
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
            )
          : null,
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
            Text('正在初始化...'),
          ],
        ),
      );
    }

    // 加载中
    if (_isLoading && _savedList.isEmpty) {
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

    // 错误信息
    if (_errorMessage != null && _savedList.isEmpty) {
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
                onPressed: _loadSavedWiFi,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // WiFi 列表为空
    if (_savedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
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
                  '已保存 ${_savedList.length} 个 WiFi 配置',
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
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _savedList.length,
            itemBuilder: (context, index) {
              return _buildSavedWiFiCard(_savedList[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedWiFiCard(SavedWiFi wifi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Icons.wifi,
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
                        wifi.password,
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
              onPressed: _isLoading ? null : () => _showDeleteDialog(wifi.ssid),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}

