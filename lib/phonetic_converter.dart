/// 本地音素转换器
/// 基于 CMU 发音词典和 Espressif 音素映射
class PhoneticConverter {
  // Espressif MultiNet 音素映射表
  static const Map<String, String> _espressifAlphabet = {
    'AE1': 'a', 'AE0': 'a', 'AE2': 'a',
    'AH0': 'c', 'AH1': 'c', 'AH2': 'c',
    'OW1': 'b', 'OW0': 'b', 'OW2': 'b',
    'EY1': 'd', 'EY0': 'd', 'EY2': 'd',
    'IH0': 'g', 'IH1': 'g', 'IH2': 'g',
    'AY1': 'i', 'AY0': 'i', 'AY2': 'i',
    'ER0': 'k', 'ER1': 'k', 'ER2': 'k',
    'IY1': 'm', 'IY0': 'm', 'IY2': 'm',
    'AA1': 'n', 'AA0': 'n', 'AA2': 'n',
    'UW1': 'o', 'UW0': 'o', 'UW2': 'o',
    'AO1': 'e', 'AO0': 'e', 'AO2': 'e',
    'AW1': 't', 'AW0': 't', 'AW2': 't',
    'OY1': 'u', 'OY0': 'u', 'OY2': 'u',
    'UH1': 'w', 'UH0': 'w', 'UH2': 'w',
    'EH1': 'f', 'EH0': 'f', 'EH2': 'f',
    'N': 'N', 'V': 'V', 'L': 'L', 'F': 'F',
    'S': 'S', 'B': 'B', 'R': 'R', 'D': 'D',
    'G': 'G', 'HH': 'h', 'K': 'K', 'W': 'W',
    'T': 'T', 'M': 'M', 'Z': 'Z', 'DH': 'j',
    'P': 'P', 'NG': 'l', 'Y': 'Y', 'CH': 'p',
    'JH': 'q', 'ZH': 'r', 'SH': 's', 'TH': 'v',
  };

  // CMU 发音词典（精选常用唤醒词）
  static const Map<String, List<String>> _cmuDict = {
    // 常见唤醒词
    'hi': ['HH', 'AY1'],
    'hey': ['HH', 'EY1'],
    'hello': ['HH', 'AH0', 'L', 'OW1'],
    'ok': ['OW1', 'K', 'EY1'],
    'okay': ['OW1', 'K', 'EY1'],
    
    // 常见名字
    'alexa': ['AH0', 'L', 'EH1', 'K', 'S', 'AH0'],
    'siri': ['S', 'IH1', 'R', 'IY0'],
    'google': ['G', 'UW1', 'G', 'AH0', 'L'],
    'jarvis': ['JH', 'AA1', 'R', 'V', 'IH0', 'S'],
    'cortana': ['K', 'AO0', 'R', 'T', 'AA1', 'N', 'AH0'],
    'bixby': ['B', 'IH1', 'K', 'S', 'B', 'IY0'],
    
    // 项目特定
    'lexin': ['L', 'EH1', 'K', 'S', 'IH0', 'N'],
    'xiaole': ['SH', 'Y', 'AW1', 'L', 'AH0'],
    'xiaoai': ['SH', 'Y', 'AW1', 'AY1'],
    
    // 常用动词
    'turn': ['T', 'ER1', 'N'],
    'open': ['OW1', 'P', 'AH0', 'N'],
    'close': ['K', 'L', 'OW1', 'Z'],
    'start': ['S', 'T', 'AA1', 'R', 'T'],
    'stop': ['S', 'T', 'AA1', 'P'],
    'play': ['P', 'L', 'EY1'],
    'pause': ['P', 'AO1', 'Z'],
    
    // 方向词
    'on': ['AA1', 'N'],
    'off': ['AO1', 'F'],
    'up': ['AH1', 'P'],
    'down': ['D', 'AW1', 'N'],
    'left': ['L', 'EH1', 'F', 'T'],
    'right': ['R', 'AY1', 'T'],
    
    // 颜色
    'red': ['R', 'EH1', 'D'],
    'blue': ['B', 'L', 'UW1'],
    'green': ['G', 'R', 'IY1', 'N'],
    'white': ['W', 'AY1', 'T'],
    'black': ['B', 'L', 'AE1', 'K'],
    
    // 数字
    'one': ['W', 'AH1', 'N'],
    'two': ['T', 'UW1'],
    'three': ['TH', 'R', 'IY1'],
    'four': ['F', 'AO1', 'R'],
    'five': ['F', 'AY1', 'V'],
  };

  /// 将文本转换为 Espressif 音素字符串
  /// 
  /// 示例:
  /// ```dart
  /// final phonetic = PhoneticConverter.convert('hi alexa');
  /// print(phonetic); // 输出: hicLfKSc
  /// ```
  static String? convert(String text) {
    if (text.isEmpty) return null;

    // 清理和标准化输入
    final normalized = text.toLowerCase().trim();
    
    // 分割成单词
    final words = normalized.split(RegExp(r'[\s,;]+'));
    
    final buffer = StringBuffer();
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // 查找词典
      final phonemes = _cmuDict[word];
      
      if (phonemes == null) {
        // 词典中没有，尝试简单规则
        final guessed = _guessPhonemes(word);
        if (guessed != null) {
          buffer.write(guessed);
        } else {
          // 无法转换，返回 null
          return null;
        }
      } else {
        // 转换音素
        for (final phoneme in phonemes) {
          final espressif = _espressifAlphabet[phoneme];
          if (espressif != null) {
            buffer.write(espressif);
          }
        }
      }
    }
    
    return buffer.toString();
  }

  /// 检查词汇是否在词典中
  static bool isSupported(String text) {
    final normalized = text.toLowerCase().trim();
    final words = normalized.split(RegExp(r'[\s,;]+'));
    
    for (final word in words) {
      if (word.isEmpty) continue;
      if (!_cmuDict.containsKey(word)) {
        return false;
      }
    }
    
    return true;
  }

  /// 获取支持的词汇列表
  static List<String> getSupportedWords() {
    return _cmuDict.keys.toList()..sort();
  }

  /// 简单的音素猜测（基于英文发音规则）
  static String? _guessPhonemes(String word) {
    // 这是一个非常简化的实现
    // 实际的 G2P 转换需要复杂的规则或机器学习模型
    
    // 对于未知词，返回 null（更安全）
    return null;
    
    // 如果需要猜测，可以实现基本规则：
    // final buffer = StringBuffer();
    // for (int i = 0; i < word.length; i++) {
    //   final char = word[i];
    //   // 添加简单的字母到音素映射
    // }
    // return buffer.toString();
  }

  /// 批量转换（用于预设）
  static Map<String, String> convertBatch(List<String> words) {
    final result = <String, String>{};
    
    for (final word in words) {
      final phonetic = convert(word);
      if (phonetic != null) {
        result[word] = phonetic;
      }
    }
    
    return result;
  }

  /// 获取转换详情（用于调试）
  static Map<String, dynamic>? getDetails(String text) {
    final normalized = text.toLowerCase().trim();
    final words = normalized.split(RegExp(r'[\s,;]+'));
    
    final details = <Map<String, dynamic>>[];
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      final phonemes = _cmuDict[word];
      if (phonemes == null) {
        return null; // 不支持的词
      }
      
      final espressifPhonemes = phonemes
          .map((p) => _espressifAlphabet[p])
          .where((e) => e != null)
          .join('');
      
      details.add({
        'word': word,
        'arpabet': phonemes,
        'espressif': espressifPhonemes,
      });
    }
    
    return {
      'input': text,
      'normalized': normalized,
      'words': details,
      'result': convert(text),
    };
  }
}

