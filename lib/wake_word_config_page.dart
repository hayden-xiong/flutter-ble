import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_wifi_service.dart';
import 'wake_word_models.dart';
import 'wake_word_presets.dart';
import 'phonetic_converter.dart';

/// 敏感度枚举
enum Sensitivity { low, medium, high }

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
  
  // 已选择的预置唤醒词
  final Set<String> _selectedPresets = {};
  
  // 当前显示的分类
  String _selectedCategory = 'general';
  
  // 重选后的现有唤醒词列表
  List<WakeWord> _reselectedWakeWords = [];
  
  // 自定义唤醒词列表
  final List<WakeWord> _customWakeWords = [];
  
  // 敏感度
  Sensitivity _sensitivity = Sensitivity.medium;

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
          _isLoading = false;
          // 根据设备返回的阈值设置敏感度
          _sensitivity = _thresholdToSensitivity(threshold);
          
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

  // 将敏感度转换为阈值
  double _sensitivityToThreshold(Sensitivity sensitivity) {
    switch (sensitivity) {
      case Sensitivity.low:
        return 0.30;
      case Sensitivity.medium:
        return 0.20;
      case Sensitivity.high:
        return 0.15;
    }
  }
  
  // 将阈值转换为敏感度
  Sensitivity _thresholdToSensitivity(double threshold) {
    if (threshold <= 0.17) {
      return Sensitivity.high;
    } else if (threshold <= 0.25) {
      return Sensitivity.medium;
    } else {
      return Sensitivity.low;
    }
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
      // 先从预置词典中查找
      final preset = presetWakeWords[text];
      if (preset != null) {
        words.add(preset.toWakeWord());
        continue;
      }
      
      // 从重选列表中查找
      final reselectedIndex = _reselectedWakeWords.indexWhere((w) => w.text == text);
      if (reselectedIndex != -1) {
        words.add(_reselectedWakeWords[reselectedIndex]);
        continue;
      }
      
      // 从自定义列表中查找
      final customIndex = _customWakeWords.indexWhere((w) => w.text == text);
      if (customIndex != -1) {
        words.add(_customWakeWords[customIndex]);
        continue;
      }
      
      // 如果都找不到，使用文本本身
      words.add(WakeWord(
        text: text,
        display: text,
        phonemes: [text],
      ));
    }
    
    // 使用敏感度对应的阈值
    final threshold = _sensitivityToThreshold(_sensitivity);
    
    await _bleService.setWakeWords(
      words: words,
      threshold: threshold,
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
    bool showAdvanced = false;
    String? convertedPhonetic;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              '自定义唤醒词',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 唤醒词输入框
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: '唤醒词',
                      hintText: '输入您的唤醒词',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.mic),
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
                  
                  // 自动转换提示（仅在支持时显示）
                  if (textController.text.isNotEmpty && isSupported)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已自动转换音素',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 高级选项展开按钮
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        showAdvanced = !showAdvanced;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          showAdvanced ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '高级选项',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 高级选项内容
                  if (showAdvanced) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneticController,
                      decoration: InputDecoration(
                        labelText: '音素字符串',
                        hintText: '自动生成或手动输入',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.help_outline, size: 20),
                          onPressed: () {
                            _showPhoneticHelp(context);
                          },
                        ),
                      ),
                      readOnly: isSupported,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '音素是唤醒词的发音表示，通常会自动生成',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim().toUpperCase();
                  final phonetic = phoneticController.text.trim();
                  
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入唤醒词')),
                    );
                    return;
                  }
                  
                  // 检查是否已存在
                  final exists = _customWakeWords.any((w) => w.text.toUpperCase() == text);
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('该唤醒词已存在'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  // 音素不是必填项，如果为空则传空数组
                  final List<String> phonemesList;
                  if (phonetic.isEmpty) {
                    phonemesList = []; // 音素为空时传空数组
                  } else {
                    phonemesList = [phonetic.toUpperCase()];
                  }
                  
                  // 创建自定义唤醒词对象
                  final customWord = WakeWord(
                    text: text,
                    display: textController.text.trim(), // 保留原始输入作为显示名称
                    phonemes: phonemesList,
                  );
                  
                  // 添加到自定义列表
                  setState(() {
                    _customWakeWords.add(customWord);
                    _sendSuccess = false;
                  });
                  
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '唤醒词配置',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _isLoading ? null : _loadWakeWords,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedCategory == 'custom' && _customWakeWords.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCustomWakeWordDialog,
              backgroundColor: Colors.grey[900],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Colors.grey[800], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '设备上的唤醒词',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${_currentWakeWords.length}/5',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '在下方选择新的唤醒词后点击"设置"按钮',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (_currentWakeWords.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        // 将当前设备上的唤醒词加入重选列表
                        _reselectedWakeWords = List.from(_currentWakeWords);
                        // 清空选择列表，让用户重新选择
                        _selectedPresets.clear();
                        _sendSuccess = false;
                        // 切换到"现有"分类
                        _selectedCategory = 'current';
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '重选',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[900],
                        fontWeight: FontWeight.w500,
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
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无唤醒词，请在下方选择并设置',
                        style: TextStyle(
                          color: Colors.grey[600],
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
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          word.display,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.grey[800], size: 20),
                const SizedBox(width: 8),
                const Text(
                  '唤醒词敏感度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSensitivityOption(
                    Sensitivity.low,
                    '低',
                    '不易误触',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSensitivityOption(
                    Sensitivity.medium,
                    '中等',
                    '推荐',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSensitivityOption(
                    Sensitivity.high,
                    '高',
                    '更灵敏',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSensitivityOption(Sensitivity sensitivity, String label, String hint) {
    final isSelected = _sensitivity == sensitivity;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sensitivity = sensitivity;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.grey[900]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.grey[900] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.grey[700] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    // 动态构建分类列表，按顺序：现有（如果有）、通用、手办、自定义
    final List<MapEntry<String, WakeWordCategory>> categories = [];
    
    // 如果有重选内容，"现有"放第一位
    if (_reselectedWakeWords.isNotEmpty) {
      final currentEntry = presetCategories.entries.firstWhere((e) => e.key == 'current');
      categories.add(currentEntry);
    }
    
    // 添加其他分类（包括自定义）
    categories.addAll(
      presetCategories.entries.where((entry) => 
        entry.key != 'current'
      ).toList()
    );
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final entry = categories[index];
          final isSelected = _selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (mounted && _selectedCategory != entry.key) {
                  setState(() {
                    _selectedCategory = entry.key;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.grey[900]! : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    entry.value.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetList() {
    // 如果是"自定义"分类
    if (_selectedCategory == 'custom') {
      // 如果没有自定义唤醒词，显示空状态和添加按钮
      if (_customWakeWords.isEmpty) {
        return Center(
          key: const ValueKey('custom_empty'),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '自定义唤醒词',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '创建您专属的唤醒词',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showCustomWakeWordDialog,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    '添加自定义唤醒词',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // 如果有自定义唤醒词，显示列表和添加按钮
      return Column(
        key: const ValueKey('custom_list'),
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              physics: const BouncingScrollPhysics(),
              itemCount: _customWakeWords.length,
              itemBuilder: (context, index) {
                final word = _customWakeWords[index];
                final isSelected = _selectedPresets.contains(word.text);
                
                return _buildWakeWordItem(
                  display: word.display,
                  text: word.text,
                  description: '自定义',
                  isSelected: isSelected,
                  showDelete: true,
                  onDelete: () {
                    setState(() {
                      _customWakeWords.removeAt(index);
                      _selectedPresets.remove(word.text);
                      _sendSuccess = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已删除: ${word.display}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }
    
    // 如果是"现有"分类，显示重选的唤醒词
    if (_selectedCategory == 'current') {
      return ListView.builder(
        key: const ValueKey('current'),
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: _reselectedWakeWords.length,
        itemBuilder: (context, index) {
          final word = _reselectedWakeWords[index];
          final isSelected = _selectedPresets.contains(word.text);
          
          return _buildWakeWordItem(
            display: word.display,
            text: word.text,
            description: '设备上的唤醒词',
            isSelected: isSelected,
          );
        },
      );
    }
    
    // 其他分类显示预设唤醒词
    final categoryWords = getWakeWordsByCategory(_selectedCategory);
    
    return ListView.builder(
      key: ValueKey(_selectedCategory),
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: categoryWords.length,
      itemBuilder: (context, index) {
        final preset = categoryWords[index];
        final isSelected = _selectedPresets.contains(preset.text);
        
        return _buildWakeWordItem(
          display: preset.display,
          text: preset.text,
          description: preset.description,
          isSelected: isSelected,
        );
      },
    );
  }
  
  Widget _buildWakeWordItem({
    required String display,
    required String text,
    String? description,
    required bool isSelected,
    bool showDelete = false,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.grey[900]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isSelected) {
              // 取消选中
              _selectedPresets.remove(text);
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
              _selectedPresets.add(text);
              _sendSuccess = false;
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.grey[900] : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.grey[900]! : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showDelete && onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                  onPressed: () {
                    // 显示确认对话框
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除唤醒词'),
                        content: Text('确定要删除"$display"吗？'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              '取消',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDelete();
                            },
                            child: const Text(
                              '删除',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedPresets.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选择 ${_selectedPresets.length} 个唤醒词',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPresets.clear();
                        _sendSuccess = false;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '清空',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSending || _selectedPresets.isEmpty || _sendSuccess
                    ? null
                    : _sendWakeWords,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sendSuccess ? Colors.green : Colors.grey[900],
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSending 
                            ? '正在设置...' 
                            : _sendSuccess 
                                ? '已设置' 
                                : '设置到设备',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

