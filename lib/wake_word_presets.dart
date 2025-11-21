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
    text: 'hi plaud',
    display: 'Hi Plaud',
    phonemes: [
      'hi PLAA1D',
      'hi PLaD',
      'hi PLeD',
      'HH AY1 P L AA1 D',
      'HH AY P L AA D',
    ],
    category: 'robot',
    description: '官方推荐唤醒词',
  ),
  'hey plaud': PresetWakeWord(
    text: 'hey plaud',
    display: 'Hey Plaud',
    phonemes: [
      'HH EY1 PLAA1D',
      'HH EY PLAA1D',
      'hey PLaD',
      'HH EY1 P L AA1 D',
    ],
    category: 'robot',
    description: '官方推荐唤醒词',
  ),

  // ========================================
  // 通用助手系列
  // ========================================
  'hi assistant': PresetWakeWord(
    text: 'hi assistant',
    display: 'Hi Assistant',
    phonemes: [
      'hi assistant',
      'HH AY1 AH0 S IH1 S T AH0 N T',
      'HH AY AH S IH S T AH N T',
    ],
    category: 'general',
    description: '通用语音助手',
  ),
  'hey assistant': PresetWakeWord(
    text: 'hey assistant',
    display: 'Hey Assistant',
    phonemes: [
      'hey assistant',
      'HH EY1 AH0 S IH1 S T AH0 N T',
      'HH EY AH S IH S T AH N T',
    ],
    category: 'general',
    description: '通用语音助手',
  ),
  'ok robot': PresetWakeWord(
    text: 'ok robot',
    display: 'OK Robot',
    phonemes: [
      'ok robot',
      'OW1 K EY1 R OW1 B AA1 T',
      'OW K EY R OW B AA T',
    ],
    category: 'general',
    description: '机器人助手',
  ),
  'hey siri': PresetWakeWord(
    text: 'hey siri',
    display: 'Hey Siri',
    phonemes: [
      'hey siri',
      'HH EY1 S IH1 R IY0',
      'HH EY S IH R IY',
    ],
    category: 'general',
    description: 'Siri风格（仅供参考）',
  ),
  'ok google': PresetWakeWord(
    text: 'ok google',
    display: 'OK Google',
    phonemes: [
      'ok google',
      'OW1 K EY1 G UW1 G AH0 L',
      'OW K EY G UW G AH L',
    ],
    category: 'general',
    description: 'Google风格（仅供参考）',
  ),

  'hi buddy': PresetWakeWord(
    text: 'hi buddy',
    display: 'Hi Buddy',
    phonemes: [
      'hi buddy',
      'HH AY1 B AH1 D IY0',
      'HH AY B AH D IY',
    ],
    category: 'general',
    description: '友好的伙伴',
  ),
  'hey friend': PresetWakeWord(
    text: 'hey friend',
    display: 'Hey Friend',
    phonemes: [
      'hey friend',
      'HH EY1 F R EH1 N D',
      'HH EY F R EH N D',
    ],
    category: 'general',
    description: '友好的朋友',
  ),
  'hi there': PresetWakeWord(
    text: 'hi there',
    display: 'Hi There',
    phonemes: [
      'hi there',
      'HH AY1 DH EH1 R',
      'HH AY DH EH R',
    ],
    category: 'general',
    description: '打招呼',
  ),
  'hello friend': PresetWakeWord(
    text: 'hello friend',
    display: 'Hello Friend',
    phonemes: [
      'hello friend',
      'HH AH0 L OW1 F R EH1 N D',
      'HH AH L OW F R EH N D',
    ],
    category: 'general',
    description: '问候朋友',
  ),
  'hey jarvis': PresetWakeWord(
    text: 'hey jarvis',
    display: 'Hey Jarvis',
    phonemes: [
      'hey jarvis',
      'HH EY1 JH AA1R V IH0 S',
      'HH EY JH AAR V IH S',
    ],
    category: 'robot',
    description: '钢铁侠的AI助手',
  ),
  'ok computer': PresetWakeWord(
    text: 'ok computer',
    display: 'OK Computer',
    phonemes: [
      'ok computer',
      'OW1 K EY1 K AH0 M P Y UW1 T ER0',
      'OW K EY K AH M P Y UW T ER',
    ],
    category: 'robot',
    description: '电脑助手',
  ),
  'hey cortana': PresetWakeWord(
    text: 'hey cortana',
    display: 'Hey Cortana',
    phonemes: [
      'hey cortana',
      'HH EY1 K AO0 R T AE1 N AH0',
      'HH EY K AO R T AE N AH',
    ],
    category: 'robot',
    description: '微软助手风格',
  ),
  'alexa': PresetWakeWord(
    text: 'alexa',
    display: 'Alexa',
    phonemes: [
      'alexa',
      'AH0 L EH1 K S AH0',
      'AH L EH K S AH',
    ],
    category: 'robot',
    description: 'Amazon助手风格',
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

