import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';
import 'wake_word_models.dart';
import 'wake_word_presets.dart';
import 'phonetic_converter.dart';

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
  bool _sendSuccess = false;  // 发送成功状态
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
          
          // 不自动选中设备上的唤醒词
          // 用户需要手动选择要配置的唤醒词
        });
      }
    };
    
    _bleService.onWakeWordResult = (result) {
      if (!mounted) return;
      
      setState(() {
        _isSending = false;
        _sendSuccess = result.success;  // 记录发送结果
      });
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // 刷新列表
        _loadWakeWords();
        
        // 3秒后重置成功状态
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _sendSuccess = false;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.getErrorDescription()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '了解',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    };
    
    _bleService.onError = (message) {
      if (mounted) {
        final formattedMessage = _formatErrorMessage(message);
        setState(() {
          _errorMessage = formattedMessage;
          _isLoading = false;
          _isSending = false;
        });
        
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formattedMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '知道了',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
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
  
  /// 格式化错误消息，使其更友好
  String _formatErrorMessage(String message) {
    if (message.contains('PlatformException')) {
      // 提取关键错误信息
      final match = RegExp(r'PlatformException\(([^,]+)').firstMatch(message);
      if (match != null) {
        return '蓝牙错误：${match.group(1)}\n\n请重试或重新连接设备';
      }
    }
    
    return message;
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
    
    // 限制最多5个唤醒词
    if (_selectedPresets.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('不支持设置超过 5 个唤醒词'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    setState(() {
      _isSending = true;
      _sendSuccess = false;  // 重置成功状态
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

  Future<void> _showCustomWakeWordDialog() async {
    final textController = TextEditingController();
    final phoneticController = TextEditingController();
    bool isSupported = false;
    String? convertedPhonetic;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('添加自定义唤醒词'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: '唤醒词文本',
                      hintText: '例如: hello world',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        isSupported = PhoneticConverter.isSupported(value);
                        convertedPhonetic = PhoneticConverter.convert(value);
                        if (convertedPhonetic != null) {
                          phoneticController.text = convertedPhonetic!;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (textController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSupported ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSupported ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSupported ? Icons.check_circle : Icons.warning,
                            color: isSupported ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSupported
                                  ? '✓ 支持本地转换'
                                  : '⚠️ 词典中无此词，请手动输入音素',
                              style: TextStyle(
                                color: isSupported ? Colors.green[700] : Colors.orange[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneticController,
                    decoration: InputDecoration(
                      labelText: '音素字符串',
                      hintText: '自动生成或手动输入',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () {
                          _showPhoneticHelp(context);
                        },
                      ),
                    ),
                    readOnly: isSupported,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持的词汇: ${PhoneticConverter.getSupportedWords().take(10).join(", ")}...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  final phonetic = phoneticController.text.trim();
                  
                  if (text.isEmpty || phonetic.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请填写完整信息')),
                    );
                    return;
                  }
                  
                  // 添加到预设（临时）
                  setState(() {
                    _selectedPresets.add(text);
                    _sendSuccess = false;  // 重置发送成功状态
                  });
                  
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已添加自定义唤醒词: $text'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPhoneticHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('音素格式说明'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '音素字符串是唤醒词的发音表示，由字母组成。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('示例:'),
              const SizedBox(height: 8),
              _buildExampleRow('hi', 'hi'),
              _buildExampleRow('hello', 'hcLb'),
              _buildExampleRow('alexa', 'cLfKSc'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '提示: 使用本工具支持的词汇可自动转换音素。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleRow(String word, String phonetic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              word,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 16),
          const SizedBox(width: 8),
          Text(
            phonetic,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCustomWakeWordDialog,
        icon: const Icon(Icons.add),
        label: const Text('自定义'),
        tooltip: '添加自定义唤醒词',
      ),
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
                const Expanded(
                  child: Text(
                    '设备上的唤醒词',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_currentWakeWords.length}/5',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '在下方选择新的唤醒词后点击"发送"按钮',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (_currentWakeWords.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedPresets.clear();
                        for (var word in _currentWakeWords) {
                          _selectedPresets.add(word.text);
                        }
                        _sendSuccess = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已将当前唤醒词添加到选择列表'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: const Text(
                      '重选',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentWakeWords.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无唤醒词，请在下方选择并发送',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  // 取消选中
                  _selectedPresets.remove(preset.text);
                  _sendSuccess = false;
                } else {
                  // 选中前检查数量限制
                  if (_selectedPresets.length >= 5) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('最多选择 5 个唤醒词'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  _selectedPresets.add(preset.text);
                  _sendSuccess = false;
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preset.display,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '已选',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSelected 
                              ? '点击可取消选择'
                              : (preset.description ?? '点击可选择此唤醒词'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.blue[700] : Colors.grey[600],
                            fontStyle: isSelected ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue[700] : Colors.grey[400],
                    size: 28,
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已选择 ${_selectedPresets.length} 个唤醒词',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedPresets.isNotEmpty)
                        Text(
                          '发送后将替换设备上的唤醒词',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedPresets.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPresets.clear();
                        _sendSuccess = false;
                      });
                    },
                    child: const Text('清空选择'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending || _selectedPresets.isEmpty || _sendSuccess
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
                    : Icon(_sendSuccess ? Icons.check_circle : Icons.send),
                label: Text(
                  _isSending 
                      ? '正在发送到设备...' 
                      : _sendSuccess 
                          ? '配置成功 ✓' 
                          : '发送到设备（将替换）'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sendSuccess ? Colors.green : null,
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

