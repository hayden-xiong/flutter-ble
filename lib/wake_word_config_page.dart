import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';
import 'wake_word_models.dart';
import 'wake_word_presets.dart';

/// 唤醒词配置页面
class WakeWordConfigPage extends StatefulWidget {
  final BluetoothDevice device;

  const WakeWordConfigPage({
    super.key,
    required this.device,
  });

  @override
  State<WakeWordConfigPage> createState() => _WakeWordConfigPageState();
}

class _WakeWordConfigPageState extends State<WakeWordConfigPage> {
  late BLEWiFiService _bleService;
  
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  
  // 当前唤醒词列表
  List<WakeWord> _currentWakeWords = [];
  double _threshold = 0.15;
  
  // 已选择的预置唤醒词
  final Set<String> _selectedPresets = {};
  
  // 当前显示的分类
  String _selectedCategory = 'xiaozhi';

  @override
  void initState() {
    super.initState();
    _initBleService();
  }

  Future<void> _initBleService() async {
    _bleService = BLEWiFiService(widget.device);
    
    // 设置回调
    _bleService.onWakeWordsReceived = (words, threshold) {
      if (mounted) {
        setState(() {
          _currentWakeWords = words;
          _threshold = threshold;
          _isLoading = false;
          
          // 更新选中状态
          _selectedPresets.clear();
          for (var word in words) {
            _selectedPresets.add(word.text);
          }
        });
      }
    };
    
    _bleService.onWakeWordResult = (result) {
      if (!mounted) return;
      
      setState(() {
        _isSending = false;
      });
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        // 刷新列表
        _loadWakeWords();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.getErrorDescription()),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
    
    _bleService.onError = (message) {
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
          _isSending = false;
        });
      }
    };
    
    // 初始化服务
    final success = await _bleService.initialize();
    if (!success) {
      if (mounted) {
        setState(() {
          _errorMessage = '服务初始化失败';
          _isLoading = false;
        });
      }
      return;
    }
    
    // 加载当前唤醒词
    await _loadWakeWords();
  }

  Future<void> _loadWakeWords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    await _bleService.getWakeWords();
  }

  Future<void> _sendWakeWords() async {
    if (_selectedPresets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个唤醒词')),
      );
      return;
    }
    
    if (_selectedPresets.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多支持10个唤醒词')),
      );
      return;
    }
    
    setState(() {
      _isSending = true;
    });
    
    // 构建唤醒词列表
    final words = <WakeWord>[];
    for (var text in _selectedPresets) {
      final preset = presetWakeWords[text];
      if (preset != null) {
        words.add(preset.toWakeWord());
      }
    }
    
    await _bleService.setWakeWords(
      words: words,
      threshold: _threshold,
      replace: true,
    );
  }

  Future<void> _resetWakeWords() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置唤醒词'),
        content: const Text('确定要恢复为默认唤醒词吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isSending = true;
      });
      await _bleService.resetWakeWords();
    }
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('唤醒词配置'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadWakeWords,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _isSending ? null : _resetWakeWords,
            tooltip: '重置为默认',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
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
            Text('正在加载唤醒词...'),
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
                onPressed: _loadWakeWords,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        _buildCurrentWakeWordsCard(),
        _buildThresholdCard(),
        _buildCategoryTabs(),
        Expanded(child: _buildPresetList()),
      ],
    );
  }

  Widget _buildCurrentWakeWordsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '当前唤醒词',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_currentWakeWords.length}/10',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentWakeWords.isEmpty)
              Text(
                '暂无唤醒词',
                style: TextStyle(color: Colors.grey[500]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentWakeWords.map((word) {
                  return Chip(
                    label: Text(word.display),
                    avatar: const Icon(Icons.check_circle, size: 16),
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(color: Colors.green[700]),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '检测阈值',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _threshold.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _threshold,
              min: 0.05,
              max: 0.30,
              divisions: 50,
              label: _threshold.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _threshold = value;
                });
              },
            ),
            Text(
              '阈值越小越灵敏，但可能误触发。推荐值：0.10-0.20',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: presetCategories.entries.map((entry) {
          final isSelected = _selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value.icon),
                  const SizedBox(width: 6),
                  Text(entry.value.name),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = entry.key;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPresetList() {
    final categoryWords = getWakeWordsByCategory(_selectedCategory);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryWords.length,
      itemBuilder: (context, index) {
        final preset = categoryWords[index];
        final isSelected = _selectedPresets.contains(preset.text);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: Colors.blue[700]!, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedPresets.remove(preset.text);
                } else {
                  if (_selectedPresets.length >= 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('最多选择10个唤醒词')),
                    );
                    return;
                  }
                  _selectedPresets.add(preset.text);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[700] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.mic,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.display,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description ?? '${preset.phonemes.length}个音素变体',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Colors.blue[700]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
          boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选择 ${_selectedPresets.length} 个唤醒词',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (_selectedPresets.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPresets.clear();
                      });
                    },
                    child: const Text('清空'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending || _selectedPresets.isEmpty
                    ? null
                    : _sendWakeWords,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? '发送中...' : '发送到设备'),
                style: ElevatedButton.styleFrom(
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
}

