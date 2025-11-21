import 'wake_word_models.dart';

/// 预置唤醒词词典
/// 
/// 包含经过验证的常用唤醒词及其音素映射
/// 音素格式：ARPABET（类似 CMU 发音词典）

/// 唤醒词分类
final Map<String, WakeWordCategory> presetCategories = {
  'general': WakeWordCategory(
    id: 'general',
    name: '通用',
    icon: '',
  ),
  'robot': WakeWordCategory(
    id: 'robot',
    name: '手办',
    icon: '',
  ),
  'custom': WakeWordCategory(
    id: 'custom',
    name: '自定义',
    icon: '',
  ),
  'current': WakeWordCategory(
    id: 'current',
    name: '现有',
    icon: '',
  ),
};

/// 预置唤醒词列表
final Map<String, PresetWakeWord> presetWakeWords = {
  // ========================================
  // 手办系列
  // ========================================
  'hi plaud': PresetWakeWord(
    text: 'HI PLAUD',
    display: 'Hi Plaud',
    phonemes: [
      'HI PLAA1D',
      'HI PLAD',
      'HI PLED',
    ],
    category: 'robot',
    description: '官方推荐',
  ),
  'hi pikachu': PresetWakeWord(
    text: 'HI PIKACHU',
    display: 'Hi Pikachu',
    phonemes: [],
    category: 'robot',
    description: '皮卡丘',
  ),

  'hi doraemon': PresetWakeWord(
    text: 'HI DORAEMON',
    display: 'Hi Doraemon',
    phonemes: [],
    category: 'robot',
    description: '哆啦A梦',
  ),
  'hey gundam': PresetWakeWord(
    text: 'HEY GUNDAM',
    display: 'Hey Gundam',
    phonemes: [],
    category: 'robot',
    description: '高达',
  ),
  'hi kitty': PresetWakeWord(
    text: 'HI KITTY',
    display: 'Hi Kitty',
    phonemes: [],
    category: 'robot',
    description: 'Hello Kitty',
  ),
  'hey mario': PresetWakeWord(
    text: 'HEY MARIO',
    display: 'Hey Mario',
    phonemes: [],
    category: 'robot',
    description: '马里奥',
  ),
  'hi sonic': PresetWakeWord(
    text: 'HI SONIC',
    display: 'Hi Sonic',
    phonemes: [],
    category: 'robot',
    description: '索尼克',
  ),
  'hey iron man': PresetWakeWord(
    text: 'HEY IRON MAN',
    display: 'Hey Iron Man',
    phonemes: [],
    category: 'robot',
    description: '钢铁侠',
  ),

  // ========================================
  // 通用助手系列
  // ========================================
  'hi assistant': PresetWakeWord(
    text: 'HI ASSISTANT',
    display: 'Hi Assistant',
    phonemes: [],
    category: 'general',
    description: '语音助手',
  ),
  'hey assistant': PresetWakeWord(
    text: 'HEY ASSISTANT',
    display: 'Hey Assistant',
    phonemes: [],
    category: 'general',
    description: '语音助手',
  ),
  'ok robot': PresetWakeWord(
    text: 'OK ROBOT',
    display: 'OK Robot',
    phonemes: [],
    category: 'general',
    description: '机器人',
  ),

  'hi buddy': PresetWakeWord(
    text: 'HI BUDDY',
    display: 'Hi Buddy',
    phonemes: [],
    category: 'general',
    description: '伙伴',
  ),
  'hey friend': PresetWakeWord(
    text: 'HEY FRIEND',
    display: 'Hey Friend',
    phonemes: [],
    category: 'general',
    description: '朋友',
  ),
};

/// 根据分类获取唤醒词列表
List<PresetWakeWord> getWakeWordsByCategory(String categoryId) {
  return presetWakeWords.values
      .where((word) => word.category == categoryId)
      .toList();
}

/// 获取所有唤醒词列表
List<PresetWakeWord> getAllPresetWakeWords() {
  return presetWakeWords.values.toList();
}

/// 根据文本获取预置音素
List<String>? getPresetPhonemes(String text) {
  final normalized = text.toLowerCase().trim();
  return presetWakeWords[normalized]?.phonemes;
}

/// 搜索唤醒词（支持模糊搜索）
List<PresetWakeWord> searchWakeWords(String query) {
  if (query.isEmpty) {
    return getAllPresetWakeWords();
  }

  final lowerQuery = query.toLowerCase();
  return presetWakeWords.values.where((word) {
    return word.text.toLowerCase().contains(lowerQuery) ||
        word.display.toLowerCase().contains(lowerQuery) ||
        (word.description?.toLowerCase().contains(lowerQuery) ?? false);
  }).toList();
}

/// 生成音素变体（为提高识别率）
List<String> generatePhonemeVariants(String basePhoneme) {
  final variants = <String>{};

  // 策略 1：原始音素
  variants.add(basePhoneme);

  // 策略 2：去除重音标记 (0, 1, 2)
  final noStress = basePhoneme.replaceAll(RegExp(r'[012]'), '');
  if (noStress != basePhoneme) {
    variants.add(noStress);
  }

  // 策略 3：简化连读（合并空格）
  final words = basePhoneme.split(RegExp(r'\s+'));
  if (words.length > 1) {
    // 首单词保持，其余单词合并
    final simplified = '${words[0]} ${words.sublist(1).join('')}';
    variants.add(simplified);
  }

  return variants.toList();
}

/// 文本转音素（优先使用预置词典，支持降级）
Future<List<String>> textToPhonemes(String text) async {
  final normalized = text.toLowerCase().trim();

  // 1. 先查本地预置词典
  final preset = getPresetPhonemes(normalized);
  if (preset != null && preset.isNotEmpty) {
    return preset;
  }

  // 2. TODO: 可以在这里添加在线API调用
  // try {
  //   final online = await fetchPhonemesFromAPI(normalized);
  //   if (online != null && online.isNotEmpty) {
  //     return online;
  //   }
  // } catch (e) {
  //   print('在线音素转换失败: $e');
  // }

  // 3. 降级方案：使用文本本身
  // MultiNet 可能支持直接文本匹配
  return [normalized];
}

